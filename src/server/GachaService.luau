--!nonstrict
-- Car gacha, index and stat allocation. The server owns all of it; clients only see:
--   player.GachaData: one StringValue per owned car Id (discovering a car = owning it); attribute Copies = the
--   duplicates rolled since (never sold, they fill the bag, design doc 4.41)
--   player attributes: Team (up to 3 character ids joined by ",", docs/TEAM_AND_STAMINA_SPEC.md), EquippedCar (the
--   active runner: Team[1] on foot, the runner in play during a run), Rolls, StatPoints (free points), Alloc_<Stat> for each GachaConfig.STATS,
--   AutoRoll (the AUTO toggle of the roll view, true on join, false on a save with no rolls yet, not saved),
--   LuckMulti (live permanent multiplier snapshot), Cruise (the equipped character's cruise, studs/s)
-- Every unique car in the index counts towards stat points (GachaConfig.EarnedPoints); earned points are
-- never stored, only what was allocated, so the two can not drift apart. Saved by PlayerData (Snapshot/Apply).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared.CharacterCatalog)
local BagConfig = require(Shared.BagConfig)
local GachaConfig = require(Shared.GachaConfig)
local MarketConfig = require(Shared.MarketConfig)
local RaceConfig = require(Shared.RaceConfig)
local RebirthConfig = require(Shared.RebirthConfig)
local RollAnimConfig = require(Shared.RollAnimConfig)
local SeriesCatalog = require(Shared.SeriesCatalog)
local StaminaConfig = require(Shared.StaminaConfig)
local UpgradeService = require(script.Parent.UpgradeService)
local PassService = require(script.Parent.PassService)

local GachaService = {}
local QuestService = require(script.Parent.QuestService)

GachaService.REMOTE_COOLDOWN = 0.15 -- seconds between accepted EquipCar / AllocateStat requests per player
GachaService.TEAM_COOLDOWN = 0.5 -- seconds between accepted SetTeam requests (TEAM_AND_STAMINA_SPEC "Team")

local MAX_COUNT = 1e9
local STARTER = CharacterCatalog.STARTER_ID
local TEAM_SIZE = 3
local EXCLUSIVE_PASS = "exclusive_runner"

local rng = Random.new()
local watched = setmetatable({}, { __mode = "k" }) -- players whose Cruise is kept current
local lastRequest = setmetatable({}, { __mode = "k" }) -- player -> os.clock()
local autoRolls = setmetatable({}, { __mode = "k" }) -- player -> handle
local rollRemote = nil -- Remotes.RollResult, made by Start(): tells the player what they rolled
local announceRemote = nil -- Remotes.RollAnnounce, made by Start(): an emphasized roll, to everyone in the server
local extraRollsRemote = nil -- Remotes.ExtraRolls, made by Start(): a tick's rolls that do not play the animation
local bagFullRemote = nil -- Remotes.BagFullHit, made by Start(): an auto-roll try the full bag blocked

local function cleanCount(n)
	if type(n) ~= "number" or n ~= n or n < 0 then
		return 0
	end
	return math.floor(math.min(n, MAX_COUNT))
end

local function addEntry(data, id)
	local entry = Instance.new("StringValue")
	entry.Name = id
	entry.Value = id
	entry.Parent = data
end

local function folder(player)
	local data = player:FindFirstChild("GachaData")
	if not data then
		data = Instance.new("Folder")
		data.Name = "GachaData"
		data.Parent = player
	end
	return data
end

-- Creates GachaData and the attributes (idempotent). Works on any Instance.
function GachaService.Setup(player)
	local data = folder(player)
	if player:GetAttribute("EquippedCar") == nil then
		player:SetAttribute("EquippedCar", STARTER)
	end
	if player:GetAttribute("Team") == nil then
		player:SetAttribute("Team", STARTER)
	end
	if player:GetAttribute("Rolls") == nil then
		player:SetAttribute("Rolls", 0)
	end
	if player:GetAttribute("AutoRoll") == nil then
		player:SetAttribute("AutoRoll", true)
	end
	for _, stat in GachaConfig.STATS do
		if player:GetAttribute("Alloc_" .. stat) == nil then
			player:SetAttribute("Alloc_" .. stat, 0)
		end
	end
	if player:GetAttribute("StatPoints") == nil then
		player:SetAttribute("StatPoints", 0)
	end
	if not watched[player] then
		watched[player] = true
		local function refresh()
			GachaService.RefreshTeam(player)
			player:SetAttribute("LuckMulti", RebirthConfig.LuckMulti(player:GetAttribute("RebirthLevel")))
			GachaService.RefreshBag(player)
		end
		player.AttributeChanged:Connect(function(name)
			if
				name == "EquippedCar"
				or name == "Team"
				or string.sub(name, 1, 18) == "BoostUntil_Stamina"
				or string.match(name, "^Slot%d+Aura$")
				or string.match(name, "^Slot%d+Trail$")
				or name == "RebirthLevel"
				or name == "AutoRacing"
				or string.sub(name, 1, 6) == "Alloc_"
				or string.sub(name, 1, 16) == "BoostUntil_Speed"
				or string.sub(name, 1, 5) == "Pass_"
				or name == "PaidRandomRestricted"
			then
				refresh()
			end
			if name == "Pass_" .. EXCLUSIVE_PASS then
				GachaService.GrantExclusive(player)
			end
			-- A potion ending changes no attribute: refresh once when it runs out (the team row shows these numbers)
			if string.sub(name, 1, 11) == "BoostUntil_" then
				local untilAt = player:GetAttribute(name)
				if type(untilAt) == "number" and untilAt > os.time() then
					task.delay(untilAt - os.time() + 1, function()
						if player.Parent then
							refresh()
						end
					end)
				end
			end
		end)
		data.ChildAdded:Connect(refresh)
		data.ChildRemoved:Connect(refresh)
		refresh()
	end
	return data
end

UpgradeService.OnChanged(function(player)
	if watched[player] then
		GachaService.RefreshTeam(player)
		GachaService.RefreshBag(player)
	end
end)

local function alloc(player)
	local a = {}
	for _, stat in GachaConfig.STATS do
		a[stat] = cleanCount(player:GetAttribute("Alloc_" .. stat))
	end
	return a
end

local function allocSum(a)
	local sum = 0
	for _, stat in GachaConfig.STATS do
		sum += a[stat]
	end
	return sum
end

-- Number of distinct catalog cars the player has discovered (unknown ids from old saves do not count).
function GachaService.UniqueCount(player)
	local data = player:FindFirstChild("GachaData")
	if not data then
		return 0
	end
	local n = 0
	for _, entry in data:GetChildren() do
		local spec = CharacterCatalog.Get(entry.Name)
		if spec and spec.Rollable then
			n += 1
		end
	end
	return n
end

function GachaService.EarnedPoints(player)
	return GachaConfig.EarnedPoints(GachaService.UniqueCount(player))
		+ RebirthConfig.Points(player:GetAttribute("RebirthLevel"))
end

function GachaService.FreePoints(player)
	return math.max(0, GachaService.EarnedPoints(player) - allocSum(alloc(player)))
end

local function refreshPoints(player)
	player:SetAttribute("StatPoints", GachaService.FreePoints(player))
end
GachaService.RefreshPoints = refreshPoints -- RebirthService calls it when RebirthLevel changes

local function cleanCopies(n)
	if type(n) ~= "number" or n ~= n or n < 0 then
		return 0
	end
	return math.floor(math.min(n, GachaConfig.MAX_SAVED_COPIES))
end

-- Duplicates of an owned car rolled after discovering it (0 when not owned).
function GachaService.Copies(player, id)
	local data = player:FindFirstChild("GachaData")
	local entry = data and type(id) == "string" and data:FindFirstChild(id)
	return entry and cleanCopies(entry:GetAttribute("Copies")) or 0
end

local function owns(player, id)
	if id == STARTER then
		return true
	end
	if id == CharacterCatalog.KAMI_ID then
		return player:GetAttribute("AdminKami") == true -- session-only, set by /kami (AdminService)
	end
	local data = player:FindFirstChild("GachaData")
	return data ~= nil and data:FindFirstChild(id) ~= nil
end

GachaService.Owns = owns
-- Bag spaces in use: every copy takes 1 (design doc 4.36). Copies counts the duplicates after the first.
function GachaService.BagUsed(player)
	local data = player:FindFirstChild("GachaData")
	if not data then
		return 0
	end
	local used = 0
	for _, entry in data:GetChildren() do
		used += 1 + cleanCopies(entry:GetAttribute("Copies"))
	end
	return used
end

function GachaService.BagCap(player)
	return BagConfig.Cap(PassService.Owns(player, "inventory"), UpgradeService.Bonuses(player).Inventory)
end

function GachaService.BagFull(player)
	return GachaService.BagUsed(player) >= GachaService.BagCap(player)
end

-- Display only: BagUsed, BagCap, BagFull. The auto-roll loop recounts.
function GachaService.RefreshBag(player)
	local used, cap = GachaService.BagUsed(player), GachaService.BagCap(player)
	player:SetAttribute("BagUsed", used)
	player:SetAttribute("BagCap", cap)
	player:SetAttribute("BagFull", used >= cap)
end

-- shortcut: a refunded pass ends its effects at the next join but the runner stays in the save; removing it would need
-- Team repair, upgrade if refunds become a real problem.
function GachaService.GrantExclusive(player)
	local data = folder(player)
	if PassService.Owns(player, EXCLUSIVE_PASS) and not data:FindFirstChild(CharacterCatalog.EXCLUSIVE_ID) then
		addEntry(data, CharacterCatalog.EXCLUSIVE_ID)
	end
end

-- Discovers a catalog car. Returns true if it is new to the index, false if already owned (nothing changes),
-- nil (and changes nothing) for anything that is not a rollable car Id.
function GachaService.Grant(player, id)
	if type(id) ~= "string" then
		return nil
	end
	local spec = CharacterCatalog.Get(id)
	if not spec or not spec.Rollable then
		return nil
	end
	local data = GachaService.Setup(player)
	local entry = data:FindFirstChild(id)
	if entry then
		entry:SetAttribute("Copies", cleanCopies(cleanCopies(entry:GetAttribute("Copies")) + 1))
		return false
	end
	addEntry(data, id)
	refreshPoints(player)
	return true
end

local function ownedIds(player)
	local ids = {}
	local data = player:FindFirstChild("GachaData")
	if data then
		for _, entry in data:GetChildren() do
			table.insert(ids, entry.Name)
		end
	end
	return ids
end

-- Tells everyone in the server about an emphasized roll (Client/RollAnnounce shows it in chat). `rolls` is the
-- player's Rolls after it. Does nothing for anything that is not a real Player (test fakes).
function GachaService.Announce(player, id, rolls)
	if announceRemote and typeof(player) == "Instance" and player:IsA("Player") then
		announceRemote:FireAllClients(player.UserId, player.DisplayName, id, rolls)
	end
end

-- One roll at the player's luck, times the Turbo tier's Multi on every turbo roll (UpgradeService.AdvanceTurbo: the
-- player's TurboCount reaches the tier's Every; x5 every 10th roll with no Turbo tier). Returns the car Id,
-- whether it was new, the turbo multi (1 on a normal roll), whether it is emphasized (GachaConfig.IsEmphasized:
-- played enlarged and announced to the whole server), 0 (duplicates used to pay scrap Money; they now add a copy,
-- owner 2026-10-22) and the roll's luck without
-- the turbo multi (the client divides the displayed odds by it, docs/WEATHER_EVENTS_SPEC.md).
-- `bagLimited` (auto roll): at a full bag only a roll auto sell takes happens (design doc 4.41); any other returns nil, with
-- Rolls and Turbo unmoved.
local function rollOnce(player, roller, bagLimited)
	GachaService.Setup(player)
	local full = bagLimited and GachaService.BagFull(player)
	if full and player:GetAttribute("AutoSell") ~= true then
		return nil
	end
	local turboBefore = player:GetAttribute("TurboCount")
	local rollNumber = math.min(cleanCount(player:GetAttribute("Rolls")) + 1, MAX_COUNT)
	local turboMulti = UpgradeService.AdvanceTurbo(player)
	local luck = GachaService.Luck(player)
	local id = GachaConfig.Roll(roller or rng, luck * turboMulti)
	local spec = CharacterCatalog.Get(id)
	-- Auto sell (design doc 4.41): everything at or under the player's N, a new discovery too; it adds no copy, so the
	-- copies already owned stay, and a sold new character stays undiscovered.
	local sell = BagConfig.ShouldSell(player:GetAttribute("AutoSell"), player:GetAttribute("AutoSellChance"), spec)
	if full and not sell then
		player:SetAttribute("TurboCount", turboBefore)
		return nil
	end
	local emphasized = GachaConfig.IsEmphasized(id, ownedIds(player))
	player:SetAttribute("Rolls", rollNumber)
	local soldFor = 0
	local isNew = false
	if sell then
		soldFor = BagConfig.SELL_PRICE[spec.Rarity]
		require(script.Parent.MoneyService).Award(player, soldFor)
	else
		isNew = GachaService.Grant(player, id)
	end
	GachaService.RefreshBag(player)
	QuestService.Progress(player, "Rolls")
	if isNew then
		QuestService.Progress(player, "Discoveries")
	end
	if emphasized then
		GachaService.Announce(player, id, rollNumber)
	end
	return {
		Id = id,
		IsNew = isNew,
		Turbo = turboMulti,
		Emphasized = emphasized,
		SoldFor = soldFor,
		Luck = luck,
		Chance = spec and spec.Chance or 0,
	}
end

local function playRoll(player, roll)
	if rollRemote and player:IsA("Player") then
		rollRemote:FireClient(
			player,
			roll.Id,
			roll.IsNew,
			roll.Turbo,
			roll.Emphasized,
			roll.SoldFor,
			roll.Luck,
			GachaService.RollInterval(player)
		)
	end
end

-- The fifth return value is what auto sell paid for this roll (0 when it was kept).
function GachaService.Roll(player, roller)
	local roll = rollOnce(player, roller)
	playRoll(player, roll)
	return roll.Id, roll.IsNew, roll.Turbo, roll.Emphasized, roll.SoldFor, roll.Luck
end

-- One auto-roll tick: 1 roll plus Extra Roll passes, stopping if the bag fills. The rarest plays the animation; the
-- others go to the small toast (docs/MONETIZATION_SPEC.md). Returns the roll that played, or nil if none was made.
function GachaService.RollTick(player, roller)
	local extras = (PassService.Owns(player, "extra_roll_1") and 1 or 0)
		+ (PassService.Owns(player, "extra_roll_2") and 1 or 0)
	local rolls = {}
	for _ = 1, 1 + extras do
		local roll = rollOnce(player, roller, true)
		if not roll then
			break
		end
		table.insert(rolls, roll)
	end
	if #rolls == 0 then
		return nil
	end
	local best = rolls[1]
	for _, roll in rolls do
		if roll.Chance > best.Chance then
			best = roll
		end
	end
	playRoll(player, best)
	if #rolls > 1 and extraRollsRemote and player:IsA("Player") then
		local others = {}
		for _, roll in rolls do
			if roll ~= best then
				table.insert(others, { Id = roll.Id, IsNew = roll.IsNew, SoldFor = roll.SoldFor })
			end
		end
		extraRollsRemote:FireClient(player, others)
	end
	return best
end

-- Sells every spare copy of one character (docs/BAG_AND_AUTOSELL_SPEC.md "Sell spares"): the last copy always stays.
-- `count` (from a client): a whole number from 1 to the spares; nil sells them all.
function GachaService.SellSpares(player, id, count)
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("DataFailed") then
		return false, "Data not loaded"
	end
	local spec = type(id) == "string" and CharacterCatalog.Get(id)
	local price = spec and BagConfig.SELL_PRICE[spec.Rarity]
	local data = player:FindFirstChild("GachaData")
	local entry = price and data and data:FindFirstChild(id)
	local copies = entry and cleanCopies(entry:GetAttribute("Copies")) or 0
	if copies < 1 then
		return false, "No spares to sell"
	end
	count = count == nil and copies or count
	if type(count) ~= "number" or count ~= math.floor(count) or count < 1 or count > copies then
		return false, "Invalid amount"
	end
	if require(script.Parent.MoneyService).Award(player, count * price) == nil then
		return false, "Try again"
	end
	entry:SetAttribute("Copies", copies - count)
	GachaService.RefreshBag(player)
	return true, "Sold " .. count
end

-- Mass sell (design doc 4.41): all spares of each listed character, in one payment. `ids` comes from a client: at most one row
-- per catalog character; a repeat counts once; a character with no spares is passed over.
function GachaService.SellSparesMany(player, ids)
	if player:GetAttribute("DataLoaded") ~= true or player:GetAttribute("DataFailed") then
		return false, "Data not loaded"
	end
	if type(ids) ~= "table" or #ids > #CharacterCatalog.All() then
		return false, "Invalid list"
	end
	local data = player:FindFirstChild("GachaData")
	local rows, total, sold, seen = {}, 0, 0, {}
	for _, id in ids do
		if type(id) ~= "string" then
			return false, "Invalid list"
		end
		local spec = not seen[id] and CharacterCatalog.Get(id)
		local price = spec and BagConfig.SELL_PRICE[spec.Rarity]
		local entry = price and data and data:FindFirstChild(id)
		local copies = entry and cleanCopies(entry:GetAttribute("Copies")) or 0
		seen[id] = true
		if copies >= 1 then
			table.insert(rows, entry)
			total += copies * price
			sold += copies
		end
	end
	if sold == 0 then
		return false, "No spares to sell"
	end
	if require(script.Parent.MoneyService).Award(player, total) == nil then
		return false, "Try again"
	end
	for _, entry in rows do
		entry:SetAttribute("Copies", 0)
	end
	GachaService.RefreshBag(player)
	return true, "Sold " .. sold
end

-- The auto sell setting (design doc 4.36). `chance` stays unchanged when off, so turning it back on keeps it.
function GachaService.SetAutoSell(player, on, chance)
	if type(on) ~= "boolean" then
		return false
	end
	if on then
		local clean = BagConfig.CleanChance(chance)
		if not clean then
			return false
		end
		player:SetAttribute("AutoSellChance", clean)
	end
	player:SetAttribute("AutoSell", on)
	return true
end

-- The AUTO toggle: while false the auto-roll loop makes no roll. Returns true if the value was applied.
function GachaService.SetAutoRoll(player, on)
	if type(on) ~= "boolean" then
		return false
	end
	GachaService.Setup(player)
	player:SetAttribute("AutoRoll", on)
	return true
end

-- Equips the starter or an owned car. Returns true if it is now equipped.
function GachaService.Equip(player, id)
	if type(id) ~= "string" or not CharacterCatalog.Get(id) or not owns(player, id) then
		return false
	end
	GachaService.Setup(player)
	if player:GetAttribute("AutoRacing") ~= true then
		-- the single equip on foot (Index, roll toast, /kami) puts the character on slot 1; if it was on another slot
		-- the two swap places
		local team = GachaService.TeamList(player)
		local from = table.find(team, id)
		if from then
			team[from] = team[1]
		end
		team[1] = id
		player:SetAttribute("Team", table.concat(team, ","))
	end
	player:SetAttribute("EquippedCar", id)
	return true
end

-- The Team ids in slot order, read from the Team attribute (never empty: the starter).
function GachaService.TeamList(player)
	local list = {}
	local value = player:GetAttribute("Team")
	if type(value) == "string" then
		for id in string.gmatch(value, "[^,]+") do
			table.insert(list, id)
		end
	end
	if #list == 0 then
		list[1] = STARTER
	end
	return list
end

-- A save with no rolls has auto-roll off until Client/AutoRollTutorial has the player turn it on; a brand new save also
-- opens the starter popup (design doc 4.21). Called once a real save has loaded.
function GachaService.CheckStarter(player)
	if cleanCount(player:GetAttribute("Rolls")) == 0 then
		player:SetAttribute("AutoRoll", false)
		if #folder(player):GetChildren() == 0 then
			player:SetAttribute("NeedsStarter", true)
		end
	end
end

-- The player's starter choice: accepted once, only from CharacterCatalog.STARTER_PICKS. Returns true if taken.
-- The first auto-roll waits for the pick's in-world reveal, so its result card does not cover it (design doc 4.24).
local STARTER_ROLL_HOLD = 5 -- seconds (proposed)
local rollHoldUntil = setmetatable({}, { __mode = "k" })

function GachaService.PickStarter(player, id)
	if player:GetAttribute("NeedsStarter") ~= true or not table.find(CharacterCatalog.STARTER_PICKS, id) then
		return false
	end
	addEntry(folder(player), id)
	rollHoldUntil[player] = os.clock() + STARTER_ROLL_HOLD
	player:SetAttribute("NeedsStarter", false)
	player:SetAttribute("Team", id)
	player:SetAttribute("EquippedCar", id)
	return true
end

-- Sets the Team (docs/TEAM_AND_STAMINA_SPEC.md "Team"): 1-3 distinct owned string ids, on foot only. Anything else changes nothing. Returns ok, reason.
function GachaService.SetTeam(player, ids)
	if player:GetAttribute("AutoRacing") == true then
		return false, "Stop running to change your Team"
	end
	if type(ids) ~= "table" or #ids < 1 or #ids > TEAM_SIZE then
		return false, "Pick 1 to " .. TEAM_SIZE .. " characters"
	end
	local seen, count = {}, 0
	for key, id in ids do
		count += 1
		if type(key) ~= "number" or type(id) ~= "string" or not CharacterCatalog.Get(id) or not owns(player, id) then
			return false, "Not a character you own"
		end
		if seen[id] then
			return false, "A character can only be in the Team once"
		end
		seen[id] = true
	end
	if count ~= #ids then
		return false, "Not a character you own"
	end
	GachaService.Setup(player)
	player:SetAttribute("Team", table.concat(ids, ","))
	player:SetAttribute("EquippedCar", ids[1])
	return true, "Team updated"
end

-- Spends one free stat point on a stat in GachaConfig.STATS. Returns true if spent.
function GachaService.Allocate(player, stat)
	if type(stat) ~= "string" or GachaConfig.PER_POINT[stat] == nil then
		return false
	end
	GachaService.Setup(player)
	if GachaService.FreePoints(player) < 1 then
		return false
	end
	player:SetAttribute("Alloc_" .. stat, cleanCount(player:GetAttribute("Alloc_" .. stat)) + 1)
	refreshPoints(player)
	return true
end

-- Team bonus of the player's Team (design doc 4.8): "Preset" / "Series" / nil, and the series.
-- `team` (optional): a list that is not the player's Team, an event's team. The bonus depends on the team alone.
function GachaService.TeamBonus(player, team)
	return SeriesCatalog.TeamBonus(team or GachaService.TeamList(player), function(id)
		local spec = CharacterCatalog.Get(id)
		return spec and spec.Series
	end)
end

-- The upgrade tree bonuses: they sit in the additive `1 + points + tree` part.
local function bonuses(player)
	local b = UpgradeService.Bonuses(player)
	-- Gamepasses (design doc 4.35). Restricted players get no paid Luck (design doc 6).
	if PassService.Owns(player, "vip") then
		b.Money = (b.Money or 0) + 0.10
	end
	if PassService.Owns(player, "deep_stamina") then
		b.Stamina = (b.Stamina or 0) + 0.25
	end
	if PassService.PaidLuckAllowed(player) then
		b.Luck = (b.Luck or 0)
			+ (PassService.Owns(player, "vip") and 0.10 or 0)
			+ (PassService.Owns(player, "luck_1") and 1 or 0)
			+ (PassService.Owns(player, "luck_2") and 2 or 0)
	end
	return b
end

-- `bonuses` plus the Money and Luck of the Relics on the Team's characters, added like the tree bonus (design doc 4.38).
local function bonusesWithRelics(player)
	local b = bonuses(player)
	local relics = require(script.Parent.RelicService) -- late: RelicService -> GachaService
	for _, id in GachaService.TeamList(player) do
		b.Money = (b.Money or 0) + relics.Multi(player, id, "Money") - 1
		b.Luck = (b.Luck or 0) + relics.Multi(player, id, "Luck") - 1
	end
	return b
end

-- Player stamina multi (design doc 4.6-4.8): Stamina points + upgrade tree Stamina tiers, active Stamina potion,
-- team bonus. Read once at run start (RaceService).
function GachaService.StaminaMulti(player, team)
	return StaminaConfig.Multi(
		alloc(player).Stamina,
		bonuses(player).Stamina,
		require(script.Parent.BoostService).Multiplier(player, "Stamina"),
		(GachaService.TeamBonus(player, team))
	)
end

-- Cruise of character `id` on team slot `slot` (default 1), studs/s (design doc 4.13): fixed by rarity x category,
-- times the speed multi (Speed points + upgrade tree Speed tiers + rebirth level, active Speed potion, preset team bonus, that slot's
-- damped aura and trail, that character's Sidekick and Relic), capped at MAX_CRUISE. The character's SpeedMulti never enters it. An id the player does
-- not own runs as the starter.
function GachaService.CruiseFor(player, id, slot, team)
	slot = slot or 1
	local spec = type(id) == "string" and owns(player, id) and CharacterCatalog.Get(id) or CharacterCatalog.Get(STARTER)
	local multi = RaceConfig.SpeedMulti(
		alloc(player).Speed,
		require(script.Parent.BoostService).Multiplier(player, "Speed"),
		GachaService.TeamBonus(player, team) == "Preset",
		MarketConfig.SpeedMulti(player, slot),
		MarketConfig.TrailMulti(player, slot),
		(bonuses(player).Speed or 0) + RebirthConfig.SpeedBonus(player:GetAttribute("RebirthLevel"))
	)
	-- late: SidekickService, RelicService -> GachaService
	local gear = require(script.Parent.SidekickService).CruiseMulti(player, spec.Id)
		* require(script.Parent.RelicService).Multi(player, spec.Id, "Speed")
	return RaceConfig.Cruise(spec, multi * gear)
end

-- Cruise of the equipped character (EquippedCar: RaceService sets it to the active Team slot's character).
function GachaService.Cruise(player, slot)
	return GachaService.CruiseFor(player, player:GetAttribute("EquippedCar"), slot)
end

-- Replicates what the team row shows (server numbers, display only): TeamBonus ("Preset:<id>", "Series:<id>" or
-- ""), TeamCruise1..3 (studs/s) and TeamStamina1..3 (seconds) per slot, and Cruise while on foot (a run sets its own).
function GachaService.RefreshTeam(player)
	local team = GachaService.TeamList(player)
	local kind, series = GachaService.TeamBonus(player)
	player:SetAttribute("TeamBonus", kind and (kind .. ":" .. series.Id) or "")
	local staminaMulti = GachaService.StaminaMulti(player)
	local gear = require(script.Parent.SidekickService) -- late: SidekickService -> GachaService
	local relics = require(script.Parent.RelicService) -- late, the same
	for slot = 1, TEAM_SIZE do
		local spec = team[slot] and CharacterCatalog.Get(team[slot])
		player:SetAttribute("TeamCruise" .. slot, spec and GachaService.CruiseFor(player, team[slot], slot) or nil)
		player:SetAttribute(
			"TeamStamina" .. slot,
			spec
					and math.round(
						StaminaConfig.Seconds(
							spec,
							staminaMulti
								* gear.StaminaMulti(player, team[slot])
								* relics.Multi(player, team[slot], "Stamina")
						) * 10
					) / 10
				or nil
		)
	end
	if player:GetAttribute("AutoRacing") ~= true then
		player:SetAttribute("Cruise", GachaService.Cruise(player))
	end
end

-- Refresh the replicated permanent multiplier snapshots immediately after a rebirth or allocation change.
-- Gameplay callers still calculate from source attributes, so these are observability/UI values rather than a cache.
function GachaService.RefreshMultipliers(player)
	player:SetAttribute("LuckMulti", RebirthConfig.LuckMulti(player:GetAttribute("RebirthLevel")))
end

function GachaService.MoneyMulti(player)
	return GachaConfig.Multis(alloc(player), bonusesWithRelics(player)).Money
		* RebirthConfig.MoneyMulti(player:GetAttribute("RebirthLevel"))
		* require(script.Parent.BoostService).Multiplier(player, "Money")
		* require(script.Parent.WeatherService).Multipliers().Money
		* (PassService.Owns(player, "money_2x") and 2 or 1)
end

function GachaService.Luck(player)
	local luck = GachaConfig.Multis(alloc(player), bonusesWithRelics(player)).Luck
		* RebirthConfig.LuckMulti(player:GetAttribute("RebirthLevel"))
		* require(script.Parent.BoostService).Multiplier(player, "Luck")
		* require(script.Parent.WeatherService).Multipliers().Luck
	local adminLuck = player:GetAttribute("AdminLuck")
	if type(adminLuck) == "number" and adminLuck >= 1 and adminLuck == adminLuck then
		luck *= adminLuck
	end
	return luck
end

-- The save format: { Cars = { id, ... } (sorted), Copies = { [id] = n }, Team = { id, ... },
-- Equipped = id (Team[1], kept for old readers),
-- Rolls = n, StatAlloc = { [stat] = n } }.
function GachaService.Snapshot(player)
	local cars = {}
	local data = player:FindFirstChild("GachaData")
	if data then
		for _, entry in data:GetChildren() do
			table.insert(cars, entry.Name)
		end
		table.sort(cars)
	end
	local copies = {}
	for _, id in cars do
		local n = GachaService.Copies(player, id)
		if n > 0 then
			copies[id] = n
		end
	end
	local team = {}
	for _, id in GachaService.TeamList(player) do
		if id ~= CharacterCatalog.KAMI_ID then -- Kami is session-only
			table.insert(team, id)
		end
	end
	if #team == 0 then
		team[1] = STARTER
	end
	return {
		Cars = cars,
		Copies = copies,
		Team = team,
		Equipped = team[1],
		Rolls = cleanCount(player:GetAttribute("Rolls")),
		StatAlloc = alloc(player),
		AutoSell = player:GetAttribute("AutoSell") == true,
		AutoSellChance = BagConfig.CleanChance(player:GetAttribute("AutoSellChance")),
	}
end

local TRIM_ORDER = { "Stamina", "Money", "Luck", "Speed" } -- over-allocation is removed in this order

-- Loads a saved table (anything else gives a fresh player). Unknown car ids are kept so a car taken out of
-- the catalog is not wiped from saves, but they never count for points or multis.
function GachaService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	local data = folder(player)
	data:ClearAllChildren()
	-- Cars is an array of ids; early saves used a map { [id] = count } (count > 0 or true = owned)
	if type(saved.Cars) == "table" then
		for key, value in saved.Cars do
			local id = nil
			if type(key) == "number" then
				id = value
			elseif value == true or (type(value) == "number" and value == value and value > 0) then
				id = key
			end
			if type(id) == "string" and id ~= "" and id ~= STARTER and #id <= 64 and not data:FindFirstChild(id) then
				addEntry(data, id)
			end
		end
	end
	if type(saved.Copies) == "table" then
		for id, n in saved.Copies do
			local entry = type(id) == "string" and data:FindFirstChild(id)
			if entry and cleanCopies(n) > 0 then
				entry:SetAttribute("Copies", cleanCopies(n))
			end
		end
	end
	-- Team: unowned or unknown ids removed, duplicates dropped, an empty Team is the starter; saves before VERSION 13
	-- had one Equipped id, which becomes a Team of one
	local team = {}
	local savedTeam = type(saved.Team) == "table" and saved.Team or { saved.Equipped }
	for _, id in savedTeam do
		if
			#team < TEAM_SIZE
			and type(id) == "string"
			and CharacterCatalog.Get(id)
			and owns(player, id)
			and not table.find(team, id)
		then
			table.insert(team, id)
		end
	end
	if #team == 0 then
		team[1] = STARTER
	end
	player:SetAttribute("Team", table.concat(team, ","))
	player:SetAttribute("EquippedCar", team[1])
	player:SetAttribute("Rolls", cleanCount(saved.Rolls))
	player:SetAttribute("AutoSellChance", BagConfig.CleanChance(saved.AutoSellChance))
	player:SetAttribute("AutoSell", saved.AutoSell == true and BagConfig.CleanChance(saved.AutoSellChance) ~= nil)

	local a = {}
	local savedAlloc = type(saved.StatAlloc) == "table" and saved.StatAlloc or {}
	for _, stat in GachaConfig.STATS do
		a[stat] = cleanCount(savedAlloc[stat])
	end
	-- RebirthService.Apply runs after this, so count the saved rebirths here or their allocations would be cut
	local over = allocSum(a)
		- GachaConfig.EarnedPoints(GachaService.UniqueCount(player))
		- RebirthConfig.Points(saved.RebirthLevel)
	for _, stat in TRIM_ORDER do
		if over <= 0 then
			break
		end
		local cut = math.min(a[stat], over)
		a[stat] -= cut
		over -= cut
	end
	for _, stat in GachaConfig.STATS do
		player:SetAttribute("Alloc_" .. stat, a[stat])
	end

	refreshPoints(player)
	GachaService.RefreshBag(player)
end

-- Seconds between rolls for a player: UpgradeService.RollInterval (3 s, down to 2 s with Roll Speed tiers), halved by
-- 2x Auto-Roll (design doc 4.35); GachaConfig.ROLL_INTERVAL when no player is given.
function GachaService.RollInterval(player)
	if typeof(player) == "Instance" then
		return UpgradeService.RollInterval(player) / (PassService.Owns(player, "auto_roll_2x") and 2 or 1)
	end
	return GachaConfig.ROLL_INTERVAL
end

-- Seconds to wait after a roll before the next one: the player's roll interval, longer when that roll's animation is
-- longer (RollAnimConfig.ExtraPause), so the next roll never covers one still playing.
function GachaService.WaitAfter(id, emphasized, player)
	local spec = CharacterCatalog.Get(id)
	local interval = GachaService.RollInterval(player)
	return interval + RollAnimConfig.ExtraPause(spec and spec.Rarity, emphasized == true, interval)
end

-- Rolls every GachaService.WaitAfter(last roll) seconds while the player's AutoRoll is on, until handle:Stop() (or
-- the player is gone). `roller` (optional) is the Random the rolls use (tests).
function GachaService.StartAutoRoll(player, roller)
	local handle = { Running = true, Rolls = 0, BlockedTries = 0 }
	function handle:Stop()
		self.Running = false
	end
	task.spawn(function()
		local wait = GachaService.RollInterval(player)
		while handle.Running and player.Parent do
			task.wait(wait)
			wait = GachaService.RollInterval(player) -- read every roll: a Roll Speed purchase applies at once
			if
				handle.Running
				and player.Parent
				and player:GetAttribute("AutoRoll") ~= false
				and player:GetAttribute("NeedsStarter") ~= true
				and player:GetAttribute("BossEvent") ~= true
				and os.clock() >= (rollHoldUntil[player] or 0)
			then
				local roll = GachaService.RollTick(player, roller)
				if roll then
					handle.Rolls += 1
					wait = GachaService.WaitAfter(roll.Id, roll.Emphasized, player)
				else
					handle.BlockedTries += 1
				end
				-- Design doc 4.41: AutoRoll stays on and the player keeps hearing it, even while auto sell keeps rolling.
				if not roll or GachaService.BagFull(player) then
					if bagFullRemote and player:IsA("Player") then
						bagFullRemote:FireClient(player)
					end
				end
			end
		end
	end)
	return handle
end

local function accept(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < GachaService.REMOTE_COOLDOWN then
		return false
	end
	lastRequest[player] = now
	return true
end

-- What Remotes.SetAutoRoll does: rate-limited like AllocateStat, booleans only. Returns true if applied.
function GachaService.RequestSetAutoRoll(player, on)
	return accept(player) and GachaService.SetAutoRoll(player, on)
end

local function remote(remotes, name)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end

function GachaService.Start()
	UpgradeService.OnChanged(function(player) -- a bought Speed tier changes cruise (design doc 4.13)
		if player:GetAttribute("AutoRacing") ~= true then
			player:SetAttribute("Cruise", GachaService.Cruise(player))
		end
	end)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	rollRemote = remote(remotes, "RollResult")
	announceRemote = remote(remotes, "RollAnnounce")
	extraRollsRemote = remote(remotes, "ExtraRolls")
	bagFullRemote = remote(remotes, "BagFullHit")
	remote(remotes, "SetAutoSell").OnServerEvent:Connect(function(player, on, chance)
		if accept(player) then
			GachaService.SetAutoSell(player, on, chance)
		end
	end)
	local sellRemote = remotes:FindFirstChild("SellSpares") or Instance.new("RemoteFunction")
	sellRemote.Name = "SellSpares"
	sellRemote.Parent = remotes
	sellRemote.OnServerInvoke = function(player, id, count)
		if not accept(player) then
			return false, "Please wait"
		end
		return GachaService.SellSpares(player, id, count)
	end
	local sellManyRemote = remotes:FindFirstChild("SellSparesMany") or Instance.new("RemoteFunction")
	sellManyRemote.Name = "SellSparesMany"
	sellManyRemote.Parent = remotes
	sellManyRemote.OnServerInvoke = function(player, ids)
		if not accept(player) then
			return false, "Please wait"
		end
		return GachaService.SellSparesMany(player, ids)
	end
	-- Read-only: what the Details list shows (design doc 6). The numbers are the same ones a roll uses.
	local luckRemote = remotes:FindFirstChild("GetRollLuck") or Instance.new("RemoteFunction")
	luckRemote.Name = "GetRollLuck"
	luckRemote.Parent = remotes
	luckRemote.OnServerInvoke = function(player)
		return GachaService.Luck(player), UpgradeService.Turbo(player).Multi
	end
	remote(remotes, "SetAutoRoll").OnServerEvent:Connect(GachaService.RequestSetAutoRoll)
	remote(remotes, "EquipCar").OnServerEvent:Connect(function(player, id)
		if accept(player) then
			GachaService.Equip(player, id)
		end
	end)
	remote(remotes, "AllocateStat").OnServerEvent:Connect(function(player, stat)
		if accept(player) then
			GachaService.Allocate(player, stat)
		end
	end)

	local pickRemote = remotes:FindFirstChild("PickStarter") or Instance.new("RemoteFunction")
	pickRemote.Name = "PickStarter"
	pickRemote.Parent = remotes
	pickRemote.OnServerInvoke = GachaService.PickStarter

	local teamRemote = remotes:FindFirstChild("SetTeam") or Instance.new("RemoteFunction")
	teamRemote.Name = "SetTeam"
	teamRemote.Parent = remotes
	local lastTeam = setmetatable({}, { __mode = "k" })
	teamRemote.OnServerInvoke = function(player, ids)
		local now = os.clock()
		if lastTeam[player] and now - lastTeam[player] < GachaService.TEAM_COOLDOWN then
			return false, "Please wait"
		end
		lastTeam[player] = now
		return GachaService.SetTeam(player, ids)
	end

	local function onPlayer(player)
		GachaService.Setup(player)
		UpgradeService.Setup(player)
		-- Rolling before the save is loaded would be overwritten by the load: wait for it (or for it to fail,
		-- then the player still rolls but nothing is saved).
		task.spawn(function()
			while player.Parent and not player:GetAttribute("DataLoaded") and not player:GetAttribute("DataFailed") do
				task.wait(0.2)
			end
			if player.Parent and not autoRolls[player] then
				autoRolls[player] = GachaService.StartAutoRoll(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local handle = autoRolls[player]
		if handle then
			handle:Stop()
			autoRolls[player] = nil
		end
	end)
end

return GachaService
