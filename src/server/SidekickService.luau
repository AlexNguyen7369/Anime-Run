--!nonstrict
-- Sidekicks (design doc 4.36, docs/SIDEKICK_SPEC.md): summons for Gems, the Bag, auto-sell, the free summon, per-character
-- equip and the run gain. The server decides everything; nothing a client sends is trusted. Clients only read the player
-- attributes SidekickBag, SidekickGear, SidekickAutoSell (JSON), SidekickFreeUsed, SidekickPity and SidekickLegendaryPity, and the ReplicatedStorage attribute
-- SidekickRotation (JSON of SidekickRotation.Public). Saved by PlayerData (Snapshot/Apply).
-- Summons never touch GachaService.Roll, Luck or the roll counters: odds are the listed ones for everyone, except pity (4.36).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SidekickConfig)
local CharacterCatalog = require(ReplicatedStorage.Shared.CharacterCatalog)
local GachaService = require(script.Parent.GachaService)
local MoneyService = require(script.Parent.MoneyService)
local Rotation = require(script.Parent.SidekickRotation)

local SidekickService = {}
SidekickService.REMOTE_COOLDOWN = 0.25

local state = setmetatable({}, { __mode = "k" })
local lastRequest = setmetatable({}, { __mode = "k" })
local rng = Random.new()
local clock = os.time

local RARITIES = {}
for _, row in Config.List do
	RARITIES[row.Rarity] = true
end

local function ensure(player)
	local current = state[player]
	if not current then
		current = {
			Sidekicks = {},
			CharacterGear = {},
			SidekickAutoSell = {},
			SidekickFreeUsed = false,
			SidekickPity = 0,
			SidekickLegendaryPity = 0,
		}
		state[player] = current
	end
	return current
end

local function publish(player)
	local current = ensure(player)
	player:SetAttribute("SidekickBag", HttpService:JSONEncode(current.Sidekicks))
	player:SetAttribute("SidekickGear", HttpService:JSONEncode(current.CharacterGear))
	player:SetAttribute("SidekickAutoSell", HttpService:JSONEncode(current.SidekickAutoSell))
	player:SetAttribute("SidekickFreeUsed", current.SidekickFreeUsed)
	player:SetAttribute("SidekickPity", current.SidekickPity)
	player:SetAttribute("SidekickLegendaryPity", current.SidekickLegendaryPity)
end

local function addEntry(current, id)
	local entry = HttpService:GenerateGUID(false)
	table.insert(current.Sidekicks, { Id = id, Entry = entry })
	return entry
end

local function findEntry(current, entry)
	for index, row in current.Sidekicks do
		if row.Entry == entry then
			return row, index
		end
	end
	return nil
end

local function wearerOf(current, entry)
	for character, worn in current.CharacterGear do
		if worn == entry then
			return character
		end
	end
	return nil
end

-- The current slot's rows, each with its odds for that slot.
local function slotRows()
	local odds = Rotation.Odds(Rotation.Slot(clock()))
	local rows = {}
	for _, row in Config.List do
		if odds[row.Id] then
			local inSlot = table.clone(row)
			inSlot.Odds = odds[row.Id]
			table.insert(rows, inSlot)
		end
	end
	return rows
end

local function publishRotation()
	ReplicatedStorage:SetAttribute("SidekickRotation", HttpService:JSONEncode(Rotation.Public(Rotation.Slot(clock()))))
end

-- A random row of that rarity in the slot; nil when the slot has none, so the count waits for a slot that does.
local function guaranteed(rows, rarity)
	local matches = {}
	for _, row in rows do
		if row.Rarity == rarity then
			table.insert(matches, row)
		end
	end
	return #matches > 0 and matches[rng:NextInteger(1, #matches)] or nil
end

-- count rolls: each one is sold (rarity on auto-sell) or kept. Refused, with nothing changed, when the bag cannot hold what
-- would be kept. `cost` is taken here so the check and the spend happen together; nothing yields.
local function summon(player, current, count, cost)
	local kept, soldValue, results = 0, 0, {}
	local rows = slotRows() -- one clock reading: the slot when the request arrives, for all of a 10x
	local mythicPity, legendaryPity = current.SidekickPity, current.SidekickLegendaryPity -- stored only once nothing can refuse
	for i = 1, count do
		-- A Mythic wins a tie; the Legendary count then stays over its threshold and pays on the next summon.
		local paid = mythicPity + 1 >= Config.PityCount and guaranteed(rows, "Mythic")
			or legendaryPity + 1 >= Config.LegendaryPityCount and guaranteed(rows, "Legendary")
			or nil
		local row = paid or Config.Roll(rng, rows)
		mythicPity = row.Rarity == "Mythic" and 0 or mythicPity + 1
		legendaryPity = row.Rarity == "Legendary" and 0 or legendaryPity + 1
		-- A free summon (cost 0) is always kept: it is what unlocks boss events (owner 2026-11-05).
		local sold = cost > 0 and current.SidekickAutoSell[row.Rarity] == true
		results[i] = { Id = row.Id, Sold = sold, Pity = paid and true or nil }
		if sold then
			soldValue += row.SellGems
		else
			kept += 1
		end
	end
	if #current.Sidekicks + kept > Config.BagSize then
		return false, "Bag is full: sell some Sidekicks first"
	end
	if cost > 0 and not MoneyService.SpendGems(player, cost) then
		return false, "Not enough Gems"
	end
	current.SidekickPity, current.SidekickLegendaryPity = mythicPity, legendaryPity
	for _, result in results do
		if not result.Sold then
			result.Entry = addEntry(current, result.Id)
		end
	end
	if soldValue > 0 then
		MoneyService.AddGems(player, soldValue)
	end
	publish(player)
	return true, results
end

local function unlocked(player)
	return (player:GetAttribute("RebirthLevel") or 0) >= Config.UnlockRebirth
end

-- One roll on the clock's slot; the row carries that slot's odds.
function SidekickService.Roll(random)
	return Config.Roll(random, slotRows())
end

-- Replaces os.time and publishes at once; no argument puts the real clock back.
function SidekickService.SetClock(fn)
	clock = fn or os.time
	publishRotation()
end

-- Summon 1x or 10x for Gems. Returns true, results ({ Id, Sold, Entry, Pity = true when guaranteed }, sold ones listed too) or false, reason.
-- VIP pays 10% fewer Gems (design doc 4.36, owner 2026-11-05).
-- shortcut: always false here, because the pass check lives in PassService on the unmerged feature/alex/monetization; point this at it in that merge.
function SidekickService.IsVip(_player)
	return false
end

function SidekickService.CostFor(player, count)
	local cost = count == 1 and Config.SummonCost or Config.TenCost
	return SidekickService.IsVip(player) and math.floor(cost * 0.9) or cost
end

function SidekickService.Summon(player, count)
	if count ~= 1 and count ~= 10 then
		return false, "Invalid summon"
	end
	if not unlocked(player) then
		return false, "Reach rebirth " .. Config.UnlockRebirth
	end
	local cost = SidekickService.CostFor(player, count)
	if (player:GetAttribute("Gems") or 0) < cost then
		return false, "Not enough Gems"
	end
	return summon(player, ensure(player), count, cost)
end

-- The tutorial's one free summon (design doc 4.36). A refusal does not use it up.
function SidekickService.GrantFreeSummon(player)
	local current = ensure(player)
	if current.SidekickFreeUsed then
		return false, "Free summon already used"
	end
	if not unlocked(player) then
		return false, "Reach rebirth " .. Config.UnlockRebirth
	end
	local ok, results = summon(player, current, 1, 0)
	if not ok then
		return false, results
	end
	current.SidekickFreeUsed = true
	publish(player)
	return true, results
end

-- Hand sell. Never an equipped entry, never an id this version does not know (it may be worth something after a rollback).
function SidekickService.Sell(player, entry)
	local current = ensure(player)
	local row, index = findEntry(current, entry)
	if not row then
		return false, "Not in your bag"
	end
	local spec = Config.Get(row.Id)
	if not spec then
		return false, "Cannot sell this Sidekick"
	end
	if wearerOf(current, entry) then
		return false, "Take it off first"
	end
	table.remove(current.Sidekicks, index)
	MoneyService.AddGems(player, spec.SellGems)
	publish(player)
	return true, spec.SellGems
end

function SidekickService.SetAutoSell(player, rarity, on)
	if type(rarity) ~= "string" or not RARITIES[rarity] or type(on) ~= "boolean" then
		return false, "Invalid setting"
	end
	ensure(player).SidekickAutoSell[rarity] = on or nil
	publish(player)
	return true
end

-- Puts `entry` on `characterId` (nil takes off whatever it wears). A character wears one entry, an entry sits on one character.
function SidekickService.Equip(player, characterId, entry)
	if type(characterId) ~= "string" or not CharacterCatalog.Get(characterId) then
		return false, "Unknown character"
	end
	if not GachaService.Owns(player, characterId) then
		return false, "You do not own this character"
	end
	local current = ensure(player)
	if entry == nil then
		current.CharacterGear[characterId] = nil
	else
		if not findEntry(current, entry) then
			return false, "Not in your bag"
		end
		local wearer = wearerOf(current, entry)
		if wearer then
			current.CharacterGear[wearer] = nil
		end
		current.CharacterGear[characterId] = entry
	end
	publish(player)
	GachaService.RefreshTeam(player)
	return true
end

-- Admin /sidekick: one entry of a catalog id, into a bag with room.
function SidekickService.Grant(player, id)
	local current = ensure(player)
	if not Config.Get(id) then
		return false, "Unknown Sidekick"
	end
	if #current.Sidekicks >= Config.BagSize then
		return false, "Bag is full"
	end
	local entry = addEntry(current, id)
	publish(player)
	return true, entry
end

-- The Big Raga drop may overflow the bag, for example 51/50 (owner 2026-11-05, design doc 4.37). No other id may.
function SidekickService.GrantDrop(player, id)
	if id ~= "side_raga" then
		return false, "Not a boss drop"
	end
	local current = ensure(player)
	local entry = addEntry(current, id)
	publish(player)
	return true, entry
end

local function worn(player, characterId)
	local current = state[player]
	local entry = current and type(characterId) == "string" and current.CharacterGear[characterId]
	local row = entry and findEntry(current, entry)
	return row and Config.Get(row.Id)
end

-- The catalog row of what the character wears; nil with none or an id this version does not know.
SidekickService.Worn = worn

-- The characters the player owns that wear a Sidekick this version knows (boss event teams, design doc 4.37).
function SidekickService.GearedCharacters(player)
	local list = {}
	for characterId in state[player] and state[player].CharacterGear or {} do
		if worn(player, characterId) and GachaService.Owns(player, characterId) then
			table.insert(list, characterId)
		end
	end
	return list
end

-- 1 + the worn Sidekick's gain for that character; 1 with none or an id this version does not know.
function SidekickService.CruiseMulti(player, characterId)
	local spec = worn(player, characterId)
	return 1 + (spec and spec.Cruise or 0)
end

function SidekickService.StaminaMulti(player, characterId)
	local spec = worn(player, characterId)
	return 1 + (spec and spec.Stamina or 0)
end

local function cleanRows(saved)
	local rows, seen = {}, {}
	if type(saved) ~= "table" then
		return rows
	end
	for _, row in saved do
		if
			type(row) == "table"
			and type(row.Id) == "string"
			and row.Id ~= ""
			and type(row.Entry) == "string"
			and row.Entry ~= ""
			and not seen[row.Entry]
		then
			seen[row.Entry] = true
			table.insert(rows, table.clone(row)) -- an unknown id stays: a rollback destroys nothing
		end
	end
	return rows, seen
end

-- A saved bag and its gear (also Server/RelicService): junk reads as empty; gear only points at bag entries, one character each.
function SidekickService.CleanBag(savedRows, savedGear)
	local rows, known = cleanRows(savedRows)
	local gear, characters = {}, {}
	if known and type(savedGear) == "table" then
		for character in savedGear do
			if type(character) == "string" then
				table.insert(characters, character)
			end
		end
		table.sort(characters) -- a doubled entry keeps the same holder every load
		for _, character in characters do
			local entry = savedGear[character]
			if type(entry) == "string" and known[entry] then
				known[entry] = nil
				gear[character] = entry
			end
		end
	end
	return rows, gear
end

-- A saved count: junk reads as 0, a fraction rounds down.
local function cleanCount(value)
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- Replaces the state with a saved record.
function SidekickService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	local rows, gear = SidekickService.CleanBag(saved.Sidekicks, saved.CharacterGear)
	local autoSell = {}
	if type(saved.SidekickAutoSell) == "table" then
		for rarity, on in saved.SidekickAutoSell do
			if type(rarity) == "string" and on == true then
				autoSell[rarity] = true
			end
		end
	end
	state[player] = {
		Sidekicks = rows,
		CharacterGear = gear,
		SidekickAutoSell = autoSell,
		SidekickFreeUsed = saved.SidekickFreeUsed == true,
		SidekickPity = cleanCount(saved.SidekickPity),
		SidekickLegendaryPity = cleanCount(saved.SidekickLegendaryPity),
	}
	publish(player)
	GachaService.RefreshTeam(player)
end

function SidekickService.Snapshot(player)
	local current = ensure(player)
	local rows = {}
	for i, row in current.Sidekicks do
		rows[i] = table.clone(row)
	end
	return {
		Sidekicks = rows,
		CharacterGear = table.clone(current.CharacterGear),
		SidekickAutoSell = table.clone(current.SidekickAutoSell),
		SidekickFreeUsed = current.SidekickFreeUsed,
		SidekickPity = current.SidekickPity,
		SidekickLegendaryPity = current.SidekickLegendaryPity,
	}
end

-- Client arguments go to the service unchanged; it validates them. Before the save loads nothing may change: Load would replace it.
local function bind(remotes, name, fn)
	local remote = remotes:FindFirstChild(name) or Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotes
	remote.OnServerInvoke = function(player, ...)
		if player:GetAttribute("DataLoaded") ~= true then
			return false, "Data not loaded"
		end
		local at = os.clock()
		if lastRequest[player] and at - lastRequest[player] < SidekickService.REMOTE_COOLDOWN then
			return false, "Please wait"
		end
		lastRequest[player] = at
		return fn(player, ...)
	end
end

function SidekickService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	bind(remotes, "SidekickSummon", SidekickService.Summon)
	bind(remotes, "SidekickFreeSummon", SidekickService.GrantFreeSummon)
	bind(remotes, "SidekickSell", SidekickService.Sell)
	bind(remotes, "SidekickAutoSell", SidekickService.SetAutoSell)
	bind(remotes, "SidekickEquip", SidekickService.Equip)
	publishRotation()
	task.spawn(function()
		while true do
			task.wait(1)
			publishRotation() -- an unchanged value replicates nothing
		end
	end)
end

return SidekickService
