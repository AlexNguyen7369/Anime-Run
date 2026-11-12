--!nonstrict
-- Relics (design doc 4.38, docs/RELIC_SPEC.md): boss drops, the bag and per-character equip. The server decides everything;
-- nothing a client sends is trusted. Clients only read the player attributes RelicBag and RelicGear (JSON). Saved by
-- PlayerData (Snapshot/Apply) as Relics and RelicGear. Drops never touch GachaService.Roll, Luck or the roll counters.
-- Contract: Server/CarTest/RelicTests.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.RelicConfig)
local BagConfig = require(Shared.BagConfig)
local CharacterCatalog = require(Shared.CharacterCatalog)
local SidekickConfig = require(Shared.SidekickConfig)
local GachaService = require(script.Parent.GachaService)
local MoneyService = require(script.Parent.MoneyService)
local SidekickService = require(script.Parent.SidekickService)

local RelicService = {}
RelicService.REMOTE_COOLDOWN = 0.25

local state = setmetatable({}, { __mode = "k" })
local lastRequest = setmetatable({}, { __mode = "k" })
local openRng = Random.new()

local function ensure(player)
	local current = state[player]
	if not current then
		current = { Relics = {}, RelicGear = {} }
		state[player] = current
	end
	return current
end

local function publish(player)
	local current = ensure(player)
	player:SetAttribute("RelicBag", HttpService:JSONEncode(current.Relics))
	player:SetAttribute("RelicGear", HttpService:JSONEncode(current.RelicGear))
end

local function findEntry(current, entry)
	for _, row in current.Relics do
		if row.Entry == entry then
			return row
		end
	end
	return nil
end

-- The row of `boss`'s list that one draw lands on, nil for an unknown boss. Pure: no luck source can reach it.
function RelicService.Roll(boss, rng)
	local list = Config.Bosses[boss]
	return list and SidekickConfig.Roll(rng, list) or nil
end

-- One entry of a catalog id. The bag has no cap (no rule gives it one), so a defeat's Relic is never refused.
function RelicService.Grant(player, id)
	if not Config.Get(id) then
		return false, "Unknown Relic"
	end
	local entry = HttpService:GenerateGUID(false)
	table.insert(ensure(player).Relics, { Id = id, Entry = entry })
	publish(player)
	return true, entry
end

-- One sealed chest into the bag. Returns true, its entry; or false, reason.
function RelicService.GrantChest(player, id)
	if id == nil or not Config.Chests[id] then
		return false, "Not a chest"
	end
	return RelicService.Grant(player, id)
end

-- Removes a chest and rolls at its own table: draw 1 the Relic, draw 2 its boss's Sidekick, chest.SidekickId at chest.SidekickChance
-- (none for a chest without), which may overflow the bag. Returns true, the Relic's row, whether the Sidekick came; or false, reason.
function RelicService.OpenChest(player, entry, rng)
	local current = ensure(player)
	local index = nil
	for i, row in current.Relics do
		if row.Entry == entry then
			index = i
		end
	end
	local chest = index and Config.Chests[current.Relics[index].Id]
	if not chest then
		return false, "Not a chest"
	end
	local row = SidekickConfig.Roll(rng, chest.Table)
	table.remove(current.Relics, index)
	RelicService.Grant(player, row.Id)
	local won = chest.SidekickId ~= nil
		and chest.SidekickChance > 0
		and rng:NextNumber() <= chest.SidekickChance
		and SidekickService.GrantDrop(player, chest.SidekickId)
	return true, row, won == true
end

-- Puts `entry` on `characterId` (nil takes off whatever it wears). A character wears one entry, an entry sits on one character.
function RelicService.Equip(player, characterId, entry)
	if type(characterId) ~= "string" or not CharacterCatalog.Get(characterId) then
		return false, "Unknown character"
	end
	if not GachaService.Owns(player, characterId) then
		return false, "You do not own this character"
	end
	local current = ensure(player)
	if entry ~= nil then
		local row = findEntry(current, entry)
		if not row then
			return false, "Not in your bag"
		end
		if Config.Chests[row.Id] then
			return false, "Open it instead"
		end
		for character, worn in current.RelicGear do
			if worn == entry then
				current.RelicGear[character] = nil
			end
		end
	end
	current.RelicGear[characterId] = entry
	publish(player)
	GachaService.RefreshTeam(player)
	return true
end

function RelicService.Unequip(player, characterId)
	return RelicService.Equip(player, characterId, nil)
end

-- A hand sale for Money (design doc 4.38). Never a worn entry, never an id this version does not know (it may be worth something
-- after a rollback). The Money comes first: a refused payment keeps the Relic. Returns true, the Money paid.
function RelicService.Sell(player, entry)
	local current = ensure(player)
	local index = nil
	for i, row in current.Relics do
		if row.Entry == entry then
			index = i
		end
	end
	if not index then
		return false, "Not in your bag"
	end
	local spec = Config.Get(current.Relics[index].Id)
	local price = spec and not spec.Chest and BagConfig.SELL_PRICE[spec.Rarity]
	if not price then
		return false, "Cannot sell this Relic"
	end
	for _, worn in current.RelicGear do
		if worn == entry then
			return false, "Take it off first"
		end
	end
	if MoneyService.Award(player, price) == nil then
		return false, "Try again"
	end
	table.remove(current.Relics, index)
	publish(player)
	return true, price
end

-- 1 + the worn Relic's bonus in `stat`; 1 with none or an id this version does not know.
function RelicService.Multi(player, characterId, stat)
	local current = state[player]
	local entry = current and type(characterId) == "string" and current.RelicGear[characterId]
	local row = entry and findEntry(current, entry)
	local spec = row and Config.Get(row.Id)
	return 1 + (spec and spec.Bonuses[stat] or 0)
end

-- Replaces the state with a saved record. An unknown id stays, worn or not: a rollback destroys nothing.
function RelicService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	local rows, gear = SidekickService.CleanBag(saved.Relics, saved.RelicGear)
	state[player] = { Relics = rows, RelicGear = gear }
	publish(player)
	GachaService.RefreshTeam(player)
end

function RelicService.Snapshot(player)
	local current = ensure(player)
	local rows = {}
	for i, row in current.Relics do
		rows[i] = table.clone(row)
	end
	return { Relics = rows, RelicGear = table.clone(current.RelicGear) }
end

function RelicService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local function bind(name, fn)
		local remote = remotes:FindFirstChild(name) or Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = remotes
		-- Before the save loads nothing may change: Load would replace it.
		remote.OnServerInvoke = function(player, ...)
			if player:GetAttribute("DataLoaded") ~= true then
				return false, "Data not loaded"
			end
			local at = os.clock()
			if lastRequest[player] and at - lastRequest[player] < RelicService.REMOTE_COOLDOWN then
				return false, "Please wait"
			end
			lastRequest[player] = at
			return fn(player, ...)
		end
	end
	bind("RelicEquip", RelicService.Equip)
	bind("RelicSell", RelicService.Sell)
	bind("RelicOpenChest", function(player, entry)
		local ok, row, won = RelicService.OpenChest(player, entry, openRng)
		if not ok then
			return false, row
		end
		return true, { Relic = row.Id, Sidekick = won }
	end)
end

return RelicService
