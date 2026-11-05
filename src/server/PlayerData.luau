--!nonstrict
-- Saved player stats: Money, the car gacha (inventory, equipped car, rolls, stat allocation), the upgrade tree
-- (owned tiles, BestTrack, TurboCount) and the workshop level. There is no Speed stat (owner 2026-11-01, design doc
-- 4.13): an old save's Speed is kept in the record but never read. The server owns them: leaderstats replicate down to clients, nothing a client sends ever changes a value. Data is
-- kept in a DataStore; if the store cannot be read (Studio without API access, outage) the player is
-- flagged DataFailed and their stats are never written, so a failed load can not wipe a save.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared:WaitForChild("RebirthConfig"))
local Workshop = require(Shared:WaitForChild("Workshop"))
local MoneyService = require(script.Parent.MoneyService)
local GachaService = require(script.Parent.GachaService)
local UpgradeService = require(script.Parent.UpgradeService)
local MarketService = require(script.Parent.MarketService)
local RebirthService = require(script.Parent.RebirthService)
local BoostService = require(script.Parent.BoostService)
local DailyLoginService = require(script.Parent.DailyLoginService)
local QuestService = require(script.Parent.QuestService)
local ShopService = require(script.Parent.ShopService)
local GiftMailbox = require(script.Parent.GiftMailbox)
local RaceTimeService = require(script.Parent.RaceTimeService)
local SidekickService = require(script.Parent.SidekickService)
local RelicService = require(script.Parent.RelicService)

local PlayerData = {}

local STORE_NAME = "PlayerStats_v2" -- v2: test saves wiped for the Speed stat scale (owner 2026-10-30); v1 kept untouched
local VERSION = 16 -- 16: Relics, RelicGear (design doc 4.38); 15: Sidekicks, CharacterGear, SidekickAutoSell, SidekickFreeUsed (design doc 4.36); 14: Gems (design doc 4.35); 13: Team of up to 3 ids (docs/TEAM_AND_STAMINA_SPEC.md); 12: car Copies and the workshop Showcase (GachaService); 11: per-track NPC race personal bests
-- 8: session lock, MoneyEarned, DuelWins; 9: Receipts, Codes (docs/SAVE_SPEC.md)
local MAX_MONEY = 1e30 -- owner 2026-10-27: World 2 payouts reach about 1e20
local AUTOSAVE_SECONDS = 60
-- design doc 4.13 (owner 2026-11-01); EquippedAura / EquippedTrail: replaced by SlotItems (u4)
local RETIRED_KEYS = { "Speed", "EquippedAura", "EquippedTrail", "Level", "XP" }
local MAX_DUEL_WINS = 1e9

-- Session lock (docs/SAVE_SPEC.md): the saved record names the server that holds it, so two servers never
-- write the same save.
PlayerData.LOCK_TIMEOUT = 120 -- seconds: a lock this old is dead and may be taken
PlayerData.LOAD_RETRIES = 3 -- attempts in total
PlayerData.LOAD_RETRY_WAIT = 2 -- seconds between attempts

local store = nil
local clock = os.time
local saving = setmetatable({}, { __mode = "k" })
local giftReceipts = setmetatable({}, { __mode = "k" })

function PlayerData.SetClock(fn)
	clock = fn or os.time
end

local leaveHooks = {}

local defaultSession = nil
local sessionId = nil

-- This server's id in save locks: game.JobId, or a GUID made once when JobId is empty (Studio).
function PlayerData.SessionId()
	if sessionId then
		return sessionId
	end
	if not defaultSession then
		defaultSession = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)
	end
	return defaultSession
end

-- Tests: act as another server. nil restores the default.
function PlayerData.SetSessionId(id)
	sessionId = id
end

-- True when another server holds a lock that has not timed out.
local function lockedElsewhere(record, at)
	local lock = type(record) == "table" and record.Lock
	return type(lock) == "table"
		and lock.Id ~= PlayerData.SessionId()
		and type(lock.At) == "number"
		and at - lock.At < PlayerData.LOCK_TIMEOUT
end

function PlayerData.SetStore(newStore)
	store = newStore
end

local function getStore()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		end
	end
	return store
end

-- Studio only: ReplicatedStorage attribute TestSaveKey = "<name>", set in Edit, plays this server on a separate test save, so
-- a fresh-save check never reads or writes the tester's real save. A new name is a new save. Read once: changing it during
-- Play must not send test data to the real key. Leaderboards skip these sessions.
PlayerData.TestSave = RunService:IsStudio() and ReplicatedStorage:GetAttribute("TestSaveKey") or nil

function PlayerData.KeyFor(userId)
	if PlayerData.TestSave then
		return "Test_" .. tostring(PlayerData.TestSave) .. "_" .. tostring(userId)
	end
	return "Player_" .. tostring(userId)
end

-- Integer in [lo, hi]; anything that is not a real number becomes the default.
local function cleanInt(value, lo, hi, default)
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.floor(math.clamp(value, lo, hi))
end

-- Creates leaderstats with Money (idempotent). Works on any Instance.
function PlayerData.Setup(player)
	RaceTimeService.Setup(player)
	MoneyService.Setup(player)
	RebirthService.Setup(player)
	BoostService.Setup(player)
	DailyLoginService.Setup(player)
	QuestService.Setup(player)
	if player:GetAttribute("RebirthLevel") == nil then
		player:SetAttribute("RebirthLevel", RebirthConfig.DEFAULT_LEVEL)
	end
end

-- Returns true if the stats were loaded (or newly created). Yields.
function PlayerData.Load(player, userId)
	if player:GetAttribute("DataLoaded") then
		return true
	end
	userId = userId or player.UserId
	local money = MoneyService.Setup(player)
	local dataStore = getStore()
	if not dataStore then
		player:SetAttribute("DataFailed", true)
		return false
	end

	local function apply(data)
		money.Value = cleanInt(data.Money, 0, MAX_MONEY, 0)
		player:SetAttribute("Gems", cleanInt(data.Gems, 0, MAX_MONEY, 0))
		GachaService.Apply(player, data) -- older saves have no gacha fields: starter car, nothing allocated
		GachaService.CheckStarter(player) -- a brand new save picks a starter (design doc 4.21)
		UpgradeService.Apply(player, data) -- version 3 and older: no tiles, BestTrack 0, TurboCount from Rolls % 10
		MarketService.Apply(player, data)
		player:SetAttribute("WorkshopLevel", Workshop.CleanLevel(data.WorkshopLevel)) -- missing = the starter workshop
		player:SetAttribute("WorkshopStat", Workshop.CleanStat(data.WorkshopStat)) -- missing = Money (design doc 4.19)
		RebirthService.Apply(player, data)
		BoostService.Apply(player, data)
		DailyLoginService.Apply(player, data)
		QuestService.Apply(player, data)
		SidekickService.Apply(player, data) -- version 14 and older: an empty bag, free summon unused
		RelicService.Apply(player, data) -- version 15 and older: no Relics
		RaceTimeService.Apply(player, data)
		ShopService.Apply(player, data) -- version 8 and older: no receipts, no codes
		giftReceipts[player] = type(data.GiftReceipts) == "table" and table.clone(data.GiftReceipts) or {}
		player:SetAttribute("MoneyEarned", cleanInt(data.MoneyEarned, 0, MAX_MONEY, 0))
		player:SetAttribute("DuelWins", cleanInt(data.DuelWins, 0, MAX_DUEL_WINS, 0))
		player:SetAttribute("Checkpoint", cleanInt(data.Checkpoint, 1, MAX_DUEL_WINS, 1)) -- design doc 4.15
	end

	-- One UpdateAsync per attempt takes the lock. Nothing in the transform yields.
	local updated = nil
	for attempt = 1, PlayerData.LOAD_RETRIES do
		local refused = false
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(PlayerData.KeyFor(userId), function(current)
				local at = clock()
				refused = lockedElsewhere(current, at)
				if refused then
					return nil
				end
				local record = type(current) == "table" and table.clone(current) or {}
				record.Lock = { Id = PlayerData.SessionId(), At = at }
				return record
			end)
		end)
		if not ok then
			break -- store error: never guess a save
		end
		if not refused and type(result) == "table" then
			updated = result
			break
		end
		if attempt < PlayerData.LOAD_RETRIES then
			task.wait(PlayerData.LOAD_RETRY_WAIT) -- another server may be saving this player out right now
		end
	end
	if not updated then
		player:SetAttribute("DataFailed", true)
		return false
	end
	apply(updated)
	player:SetAttribute("DataFailed", nil)
	player:SetAttribute("DataLoaded", true)
	-- The mailbox was persisted even if the recipient was offline. Claim through the same
	-- atomic save path; a failed claim stays in the mailbox for the next autosave.
	if type(updated.GiftMailbox) == "table" and next(updated.GiftMailbox) then
		PlayerData.Save(player, userId)
	end
	return true
end

-- Server-only: enqueue without touching the recipient's session lock or other fields.
function PlayerData.EnqueueGift(userId, purchaseId, gift)
	if
		type(userId) ~= "number"
		or userId <= 0
		or userId % 1 ~= 0
		or type(purchaseId) ~= "string"
		or purchaseId == ""
		or #purchaseId > 200
		or not GiftMailbox.Valid(gift)
	then
		return false
	end
	local dataStore = getStore()
	if not dataStore then
		return false
	end
	local ok, result = pcall(function()
		return dataStore:UpdateAsync(PlayerData.KeyFor(userId), function(current)
			local record = type(current) == "table" and table.clone(current) or {}
			record.GiftMailbox = type(record.GiftMailbox) == "table" and table.clone(record.GiftMailbox) or {}
			if not record.GiftMailbox[purchaseId] then
				local entry = table.clone(gift)
				entry.Grants = table.clone(gift.Grants)
				record.GiftMailbox[purchaseId] = entry
			end
			return record
		end)
	end)
	return ok and type(result) == "table" and result.GiftMailbox[purchaseId] ~= nil
end

-- Returns true if the stats were written. Never writes for a player whose load failed or has not finished, or
-- when another server took the session lock. `release` (leave, shutdown) writes the record without a lock.
local function save(player, userId, release)
	userId = userId or player.UserId
	-- Never write before the load finished: a leaving player whose GetAsync is still pending would
	-- otherwise overwrite their real save with defaults.
	if player:GetAttribute("DataFailed") or not player:GetAttribute("DataLoaded") then
		return false
	end
	local dataStore = getStore()
	if not dataStore then
		return false
	end
	local money = MoneyService.Setup(player)
	local gacha = GachaService.Snapshot(player)
	local upgrades = UpgradeService.Snapshot(player)
	local market = MarketService.Snapshot(player)
	local boosts = BoostService.Snapshot(player)
	local daily = DailyLoginService.Snapshot(player)
	local quests = QuestService.Snapshot(player)
	local shop = ShopService.Snapshot(player)
	local sidekicks = SidekickService.Snapshot(player)
	local relics = RelicService.Snapshot(player)
	local payload = {
		Money = cleanInt(money.Value, 0, MAX_MONEY, 0),
		Gems = cleanInt(player:GetAttribute("Gems"), 0, MAX_MONEY, 0),
		Sidekicks = sidekicks.Sidekicks,
		CharacterGear = sidekicks.CharacterGear,
		SidekickAutoSell = sidekicks.SidekickAutoSell,
		SidekickFreeUsed = sidekicks.SidekickFreeUsed,
		Relics = relics.Relics,
		RelicGear = relics.RelicGear,
		Cars = gacha.Cars,
		Copies = gacha.Copies,
		Showcase = gacha.Showcase,
		Team = gacha.Team,
		Equipped = gacha.Equipped,
		Rolls = gacha.Rolls,
		StatAlloc = gacha.StatAlloc,
		Upgrades = upgrades.Upgrades,
		BestTrack = upgrades.BestTrack,
		TurboCount = upgrades.TurboCount,
		WorkshopLevel = Workshop.CleanLevel(player:GetAttribute("WorkshopLevel")),
		WorkshopStat = Workshop.CleanStat(player:GetAttribute("WorkshopStat")),
		RebirthLevel = RebirthConfig.CleanLevel(player:GetAttribute("RebirthLevel")),
		Boosts = boosts.Boosts,
		ActiveBoosts = boosts.ActiveBoosts,
		DailyStreak = daily.DailyStreak,
		DailyLast = daily.DailyLast,
		QuestDailyKey = quests.QuestDailyKey,
		QuestWeeklyKey = quests.QuestWeeklyKey,
		QuestDaily = quests.QuestDaily,
		QuestWeekly = quests.QuestWeekly,
		QuestDailyClaimed = quests.QuestDailyClaimed,
		QuestWeeklyClaimed = quests.QuestWeeklyClaimed,
		OwnedAuras = market.OwnedAuras,
		OwnedTrails = market.OwnedTrails,
		SlotItems = market.SlotItems, -- replaces EquippedAura / EquippedTrail (migrated to slot 1 on load)
		MoneyEarned = cleanInt(player:GetAttribute("MoneyEarned"), 0, MAX_MONEY, 0),
		DuelWins = cleanInt(player:GetAttribute("DuelWins"), 0, MAX_DUEL_WINS, 0),
		Receipts = shop.Receipts,
		Codes = shop.Codes,
		Checkpoint = cleanInt(player:GetAttribute("Checkpoint"), 1, MAX_DUEL_WINS, 1),
		RaceBestTimes = RaceTimeService.Snapshot(player),
		OfflineAt = clock(),
		Version = VERSION,
	}
	local refused = false
	local known = giftReceipts[player] or {}
	local ok, result = pcall(function()
		return dataStore:UpdateAsync(PlayerData.KeyFor(userId), function(current)
			local at = clock()
			refused = lockedElsewhere(current, at)
			if refused then
				return nil -- this server lost the session: never overwrite the other server's save
			end
			local merged = GiftMailbox.Merge(table.clone(payload), type(current) == "table" and current or {}, known)
			for _, key in RETIRED_KEYS do
				merged[key] = type(current) == "table" and current[key] or nil -- kept in old saves, never read
			end
			merged.Lock = if release then nil else { Id = PlayerData.SessionId(), At = at }
			return merged
		end)
	end)
	if ok and not refused and type(result) == "table" then
		-- Preserve any legitimate potion changes made while UpdateAsync yielded.
		for id, count in result.Boosts do
			local delta = count - (boosts.Boosts[id] or 0)
			local item = require(Shared.BoostConfig).Get(id)
			if item and item.Id == id and delta > 0 then
				BoostService.Add(player, id, delta)
			end
		end
		giftReceipts[player] = result.GiftReceipts
		return true
	end
	return false
end

function PlayerData.Save(player, userId, release)
	while saving[player] do
		task.wait()
	end
	saving[player] = true
	local ok, result = pcall(save, player, userId, release)
	saving[player] = nil
	if not ok then
		warn("PlayerData save failed: " .. tostring(result))
		return false
	end
	return result
end

-- Admin /newplayer: replaces the save with an empty record and stops this session's saves, so the next load is a brand
-- new save. Pending gifts and their receipts stay (paid for). No lock is left, so a rejoin need not wait. The caller
-- removes the player. Returns true if the save was reset. Yields.
function PlayerData.ResetToNew(player, userId)
	if player:GetAttribute("DataFailed") or not player:GetAttribute("DataLoaded") then
		return false
	end
	local dataStore = getStore()
	if not dataStore then
		return false
	end
	userId = userId or player.UserId
	while saving[player] do
		task.wait()
	end
	saving[player] = true
	local refused = false
	local ok, result = pcall(function()
		return dataStore:UpdateAsync(PlayerData.KeyFor(userId), function(current)
			refused = lockedElsewhere(current, clock())
			if refused then
				return nil
			end
			local record = type(current) == "table" and current or {}
			return { GiftMailbox = record.GiftMailbox, GiftReceipts = record.GiftReceipts }
		end)
	end)
	local reset = ok and not refused and type(result) == "table"
	if reset then
		player:SetAttribute("DataLoaded", nil) -- blocks every later save, the leave save included
	end
	saving[player] = nil
	return reset
end

-- Waits until the player's stats finished loading (or failed). Returns true if loaded.
function PlayerData.WaitLoaded(player, timeout)
	local deadline = os.clock() + (timeout or 10)
	while os.clock() < deadline do
		if player:GetAttribute("DataLoaded") then
			return true
		end
		if player:GetAttribute("DataFailed") or not player.Parent then
			return false
		end
		task.wait(0.1)
	end
	return false
end

-- Runs `fn(player)` when a player leaves, just before their stats are saved.
function PlayerData.OnLeaving(fn)
	table.insert(leaveHooks, fn)
end

function PlayerData.Start()
	local loading = {}
	local function onPlayer(player)
		if loading[player] then
			return -- joined between the PlayerAdded connect and the GetPlayers loop
		end
		loading[player] = true
		task.spawn(PlayerData.Load, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, hook in leaveHooks do
			pcall(hook, player) -- e.g. CarService stops the run
		end
		PlayerData.Save(player, nil, true)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(PlayerData.Save, player, nil, true)
		end
		-- Players kicked by the shutdown save from PlayerRemoving: wait for those too, inside Roblox's 30 s limit
		local deadline = os.clock() + 25
		while next(saving) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in Players:GetPlayers() do
				PlayerData.Save(player)
			end
		end
	end)
end

return PlayerData
