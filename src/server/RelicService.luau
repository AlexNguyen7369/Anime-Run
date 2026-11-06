--!nonstrict
-- Relics (design doc 4.38, docs/RELIC_SPEC.md): boss drops, the bag and per-character equip. The server decides everything;
-- nothing a client sends is trusted. Clients only read the player attributes RelicBag and RelicGear (JSON). Saved by
-- PlayerData (Snapshot/Apply) as Relics and RelicGear. Drops never touch GachaService.Roll, Luck or the roll counters.
-- Contract: Server/CarTest/RelicTests.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.RelicConfig)
local CharacterCatalog = require(Shared.CharacterCatalog)
local SidekickConfig = require(Shared.SidekickConfig)
local GachaService = require(script.Parent.GachaService)
local SidekickService = require(script.Parent.SidekickService)

local RelicService = {}
RelicService.REMOTE_COOLDOWN = 0.25

local state = setmetatable({}, { __mode = "k" })
local lastRequest = setmetatable({}, { __mode = "k" })

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

-- A defeat's pay (design doc 4.37): 1 Relic, then its own draw for the Big Raga Sidekick. That drop may overflow the bag.
-- Returns true, the Relic's row, whether the Sidekick came; or false, reason.
function RelicService.GrantDefeat(player, boss, rng)
	local row = RelicService.Roll(boss, rng)
	if not row then
		return false, "Unknown boss"
	end
	RelicService.Grant(player, row.Id)
	local won = rng:NextNumber() <= Config.RagaSidekickChance and SidekickService.GrantDrop(player, "side_raga")
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
		if not findEntry(current, entry) then
			return false, "Not in your bag"
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
	local remote = remotes:FindFirstChild("RelicEquip") or Instance.new("RemoteFunction")
	remote.Name = "RelicEquip"
	remote.Parent = remotes
	-- Before the save loads nothing may change: Load would replace it.
	remote.OnServerInvoke = function(player, characterId, entry)
		if player:GetAttribute("DataLoaded") ~= true then
			return false, "Data not loaded"
		end
		local at = os.clock()
		if lastRequest[player] and at - lastRequest[player] < RelicService.REMOTE_COOLDOWN then
			return false, "Please wait"
		end
		lastRequest[player] = at
		return RelicService.Equip(player, characterId, entry)
	end
end

return RelicService
