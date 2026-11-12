--!nonstrict
-- UI test setups, run INSIDE the real server (same module cache as Main), so the live GachaService / CarService /
-- RaceService state is the one being changed. execute_luau snippets get separate module copies and can't do this.
--
-- Studio only. Trigger: ReplicatedStorage attribute UiTestSetup = "<id>:<nonce>". The setup <id> runs for every
-- Player, then ReplicatedStorage UiTestSetupDone = the same string. On error UiTestSetupError =
-- "<id>:<nonce>:<message>" is set first, and Done is still set.
--
-- Ids: snapshot, restore, spy, team_states, team_states_clear, no_passes, sidekick_states, sidekick_big_reveal, sidekick_tutorial_ready, sidekick_tutorial:*, sidekick_follow_*, boss_ui_*, relic_states, relic_states_bare, index_states, daily_unclaimed, daily_claimed, checkpoint_locked, checkpoint_open, defeated_states, showdown_start, showdown_win, quest_incomplete, quest_complete, stat_points, no_stat_points, auto_racing, on_foot, lose_event, cash_out_notice, turbo_next,
-- emphasized_next, auto_roll_on, run_visual, rebirth_eligible, rebirth_not_eligible, duel_* (every id: UiSpec.ServerSetup), roll_odds_*, weather_* (rain, night, gold, aurora, clear, clear_event, rain_roll).
-- (Ported from the ServerSetup snippets in Client/UiTest/UiSpec.luau.)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end

local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local function live(name)
	return require(Server:WaitForChild(name))
end

local snapshots = {} -- [Player] = { gacha, money, autoRacing, autoRoll, upgrades }
local spied = {} -- [RemoteEvent] = connection (never connect twice)
local functionSpies = {} -- original RemoteFunction -> { name, proxy }; original callback is untouched.
local progressionSnapshots = {}
local weatherSnapshot = nil
local questSnapshots = {} -- [Player] = QuestService.Snapshot before a quest_* fixture

-- No Speed stat to snapshot: there is no leaderstats.Speed / BaseSpeed (design doc 4.13, owner 2026-11-01).
local function stat(player, name)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild(name)
end

local function removeSpy()
	for remote, entry in functionSpies do
		entry.proxy:Destroy()
		remote.Name = entry.name
	end
	table.clear(functionSpies)
	for _, conn in spied do
		conn:Disconnect()
	end
	table.clear(spied)
	local f = ReplicatedStorage:FindFirstChild("UiTestSpy")
	if f then
		f:Destroy()
	end
end

-- Every catalog car but the rarest (stays "???"), the first equipped, all stat points freed (>= 1).
local function indexStates(player)
	local G = live("GachaService")
	local C = require(Shared.CharacterCatalog)
	local GachaConfig = require(Shared.GachaConfig)
	local rarest = C.Rollable()[1].Id
	-- Reset the catalog portion first: a reused Studio player can already own every car,
	-- which would make this fixture unable to establish the required hidden rarest tile.
	local data = player:FindFirstChild("GachaData")
	if data then
		for _, entry in data:GetChildren() do
			if C.Get(entry.Name) and C.Get(entry.Name).Rollable then
				entry:Destroy()
			end
		end
	end
	for _, s in C.All() do
		if s.Id ~= rarest then
			G.Grant(player, s.Id)
		end
	end
	local all = C.All()
	G.Equip(player, all[1].Id ~= rarest and all[1].Id or all[2].Id)
	for _, st in GachaConfig.STATS do
		player:SetAttribute("Alloc_" .. st, 0)
	end
	player:SetAttribute("StatPoints", G.FreePoints(player))
end

-- AUTO toggle (docs/ROLL_ANIMATION_SPEC.md): through GachaService.SetAutoRoll when it exists, else the
-- AutoRoll attribute the auto-roll loop reads.
local function setAutoRoll(player, on)
	local G = live("GachaService")
	if type(G.SetAutoRoll) == "function" then
		G.SetAutoRoll(player, on)
	else
		player:SetAttribute("AutoRoll", on)
	end
end

local setups = {}

-- Team-of-3 stamina (design doc 4.3) ends an auto race by exhaustion in ~13.5 s (a Common team), which would end the
-- auto_racing fixture mid-run. From auto_racing until 'restore', this player's runs get untiring stamina through
-- RaceService's StaminaSeconds test seam (a run that passes its own keeps it). Real play is never affected.
local longStamina = {} -- [Player] = true
local wrappedNewRun = false
local function wrapNewRun()
	if wrappedNewRun then
		return
	end
	wrappedNewRun = true
	local RaceService = live("RaceService")
	local orig = RaceService.NewRun
	RaceService.NewRun = function(car, raceRoute, p, options)
		if longStamina[p] then
			options = table.clone(options or {})
			options.StaminaSeconds = options.StaminaSeconds or { 1e6, 1e6, 1e6 }
		end
		return orig(car, raceRoute, p, options)
	end
end

-- ui_run_visual (core c3, owner 2026-11-04; Client/UiTest/UiRunVisual): one rig at a time on a route of its own, drawn
-- by the real Client/RunnerView. It belongs to no Player: a Folder holds the slot attributes VehicleEffects.Apply reads,
-- Owner = 0 keeps the camera and stamina bar off it, and no save, Team, owned item or Money is read or written.
local RUN_VISUAL = {
	ROUTE = "UiRunVisualRoute", -- UiSpec.RunVisual.Route
	START = Vector3.new(0, 4000, 0), -- far above every track, so nothing there and the rig's effects never near the origin
	LENGTH = 12000, -- studs along +X: 15 s at RaceConfig.MAX_CRUISE, longer than any row's wait + window
	Current = nil, -- { Rig, Slots, Thread }
}

function RUN_VISUAL.clear()
	local current = RUN_VISUAL.Current
	if current then
		RUN_VISUAL.Current = nil
		task.cancel(current.Thread)
		current.Rig:Destroy()
		current.Slots:Destroy()
	end
end

function RUN_VISUAL.equip(slots, slot, aura, trail)
	local MarketConfig = require(Shared.MarketConfig)
	slots:SetAttribute(MarketConfig.SlotAttribute(slot, "Aura"), aura)
	slots:SetAttribute(MarketConfig.SlotAttribute(slot, "Trail"), trail)
end

-- Starts `name`'s run as the real spawnCar + RaceService publish do: RunRoute, RunSpeed, RunDistance every PUBLISH_INTERVAL.
function RUN_VISUAL.start(name, id, aura, trail, speed)
	RUN_VISUAL.clear()
	local PathDriver = require(Shared.PathDriver)
	local RunnerFactory = require(Shared.RunnerFactory)
	local VehicleEffects = require(Shared.VehicleEffects)
	local wps = { RUN_VISUAL.START, RUN_VISUAL.START + Vector3.new(RUN_VISUAL.LENGTH, 0, 0) }
	local arc = PathDriver.Arc(wps)
	local rig = RunnerFactory.build(id)
	rig.Name = name
	rig.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- whole on this client wherever the player stands
	local slots = Instance.new("Folder")
	RUN_VISUAL.equip(slots, 1, aura, trail)
	VehicleEffects.Apply(rig, slots, 1)
	rig:SetAttribute("Owner", 0)
	local function publish(dist)
		rig:PivotTo(PathDriver.PoseAt(wps, arc, dist) * CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0))
		rig:SetAttribute("RunRoute", RUN_VISUAL.ROUTE)
		rig:SetAttribute("RunSpeed", speed)
		rig:SetAttribute("RunDistance", dist)
	end
	publish(0)
	CollectionService:AddTag(rig, live("CarService").RUNNER_TAG)
	rig.Parent = Workspace
	local interval = live("RaceService").PUBLISH_INTERVAL
	local started = os.clock()
	RUN_VISUAL.Current = {
		Rig = rig,
		Slots = slots,
		Thread = task.spawn(function()
			while true do
				task.wait(interval)
				publish((os.clock() - started) * speed % RUN_VISUAL.LENGTH)
			end
		end),
	}
end

-- A slot swap in CarService.ApplyCharacter's order: re-skin, then the new slot's aura and trail. The run carries on.
function RUN_VISUAL.swap(id, aura, trail)
	local current = RUN_VISUAL.Current
	if not current then
		error("run_visual_swap: no rig")
	end
	RUN_VISUAL.equip(current.Slots, 2, aura, trail)
	require(Shared.RunnerFactory).Restyle(current.Rig, id)
	require(Shared.VehicleEffects).Apply(current.Rig, current.Slots, 2)
end

function setups.run_visual()
	local root = ReplicatedStorage:FindFirstChild("RunRoutes")
	if not root then
		root = Instance.new("Folder")
		root.Name = "RunRoutes"
		root.Parent = ReplicatedStorage
	end
	if root:FindFirstChild(RUN_VISUAL.ROUTE) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = RUN_VISUAL.ROUTE
	folder:SetAttribute("Count", 2)
	for i, position in { RUN_VISUAL.START, RUN_VISUAL.START + Vector3.new(RUN_VISUAL.LENGTH, 0, 0) } do
		local value = Instance.new("Vector3Value")
		value.Name = tostring(i)
		value.Value = position
		value.Parent = folder
	end
	folder.Parent = root
end

-- Global (not per player): logs every RemoteEvent call into ReplicatedStorage.UiTestSpy attributes,
-- one JSON array per remote name: [{ user = UserId, args = {...} }, ...]. The real handlers still run.
local function spy()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local f = ReplicatedStorage:FindFirstChild("UiTestSpy")
	if not f then
		f = Instance.new("Folder")
		f.Name = "UiTestSpy"
		f.Parent = ReplicatedStorage
	end
	for _, r in remotes:GetChildren() do
		if r:IsA("RemoteEvent") then
			f:SetAttribute(r.Name, "[]")
			if not spied[r] then
				spied[r] = r.OnServerEvent:Connect(function(p, ...)
					local folder = ReplicatedStorage:FindFirstChild("UiTestSpy")
					if not folder then
						return
					end
					local log = HttpService:JSONDecode(folder:GetAttribute(r.Name) or "[]")
					table.insert(log, { user = p.UserId, args = { ... } })
					folder:SetAttribute(r.Name, HttpService:JSONEncode(log))
				end)
			end
		end
	end
end

-- Run once per test session: the baseline is kept until 'restore' (a second snapshot must never overwrite it with
-- state the tests already changed, e.g. after emphasized_next or turbo_next).
function setups.snapshot(player)
	if snapshots[player] then
		return
	end
	local G = live("GachaService")
	local money = stat(player, "Money")
	snapshots[player] = {
		gacha = G.Snapshot(player),
		money = money and money.Value or nil,
		autoRacing = player:GetAttribute("AutoRacing"),
		autoRoll = player:GetAttribute("AutoRoll"),
		-- Upgrade tree state (owned upgrades, BestTrack, TurboCount): turbo_next and the progression fixtures change it
		upgrades = live("UpgradeService").Snapshot(player),
	}
end

-- Sidekick fixture (UiSpec.ServerSetup sidekick_states): what it replaced, until 'restore' or restore:sidekick_states.
local sidekickSnapshots = {}
local sidekickClockMoved = false
local sidekickRealRoll = nil -- SidekickConfig.Roll, while sidekick_big_reveal has it scripted
-- Moves the rotation clock by whole seconds (0 puts the real clock back), so ui_sidekicks sees a slot change.
-- Only the server can tell which later slot has another Secret: the client has the attribute alone. The Mythic stays the
-- featured Igriz (SIDEKICK_SPEC "Summon presentation"), so the Secret is what changes.
local function nextSecretOffset()
	local rotation = live("SidekickRotation")
	local slot = rotation.Slot(os.time())
	local steps = 1
	while steps < 200 and rotation.For(slot + steps).Secret == rotation.For(slot).Secret do
		steps += 1
	end
	return steps * rotation.SLOT_SECONDS
end
local function sidekickUiClock(offset)
	sidekickClockMoved = offset ~= 0
	live("SidekickService").SetClock(offset ~= 0 and function()
		return os.time() + offset
	end or nil)
end
local function unscriptSidekickRolls(player)
	if sidekickRealRoll then
		require(Shared.SidekickConfig).Roll = sidekickRealRoll
		sidekickRealRoll = nil
	end
	player:SetAttribute("UiTestRevealIds", nil)
end
local function restoreSidekicks(player)
	if sidekickClockMoved then
		sidekickUiClock(0)
	end
	unscriptSidekickRolls(player)
	local saved = sidekickSnapshots[player]
	if saved then
		live("SidekickService").Apply(player, saved.state)
		player:SetAttribute("Gems", saved.gems)
		player:SetAttribute("RebirthLevel", saved.rebirth)
		sidekickSnapshots[player] = nil
	end
end

function setups.sidekick_states(player)
	local service, config = live("SidekickService"), require(Shared.SidekickConfig)
	if not sidekickSnapshots[player] then
		sidekickSnapshots[player] = {
			state = service.Snapshot(player),
			gems = player:GetAttribute("Gems"),
			rebirth = player:GetAttribute("RebirthLevel"),
		}
	end
	service.Apply(player, { SidekickFreeUsed = true }) -- keeps Client/SidekickTutorial out of this fixture
	for _, rows in { config.List, config.BossDrops } do
		for _, row in rows do
			assert(service.Grant(player, row.Id), "could not grant " .. row.Id)
		end
	end
	player:SetAttribute("Gems", config.TenCost)
	player:SetAttribute("RebirthLevel", config.UnlockRebirth)
end

-- Real summon path and real reveal, only the rolls scripted: a Secret is too rare to wait for. Solo Studio: one player summons.
function setups.sidekick_big_reveal(player)
	setups.sidekick_states(player)
	local config, rotation = require(Shared.SidekickConfig), live("SidekickRotation")
	local slot = rotation.For(rotation.Slot(os.time()))
	local ids = table.create(10, slot.Common[1])
	ids[5], ids[9] = slot.Mythic[1], slot.Secret
	sidekickRealRoll = sidekickRealRoll or config.Roll
	local rolled = 0
	config.Roll = function()
		rolled += 1
		if rolled == #ids then
			config.Roll = sidekickRealRoll
			sidekickRealRoll = nil
		end
		return config.Get(ids[rolled])
	end
	player:SetAttribute("UiTestRevealIds", table.concat(ids, ","))
end

-- Boss event UI fixtures (UiSpec.ServerSetup boss_ui_*, Client/UiTest/UiBossEvent): the published attributes only, so
-- nobody really joins and the UI runs in seconds. The characters and Sidekicks they replace come back with restoreBossUi.
local bossUiSnapshots = {}
local BOSS_UI_ATTRIBUTES = {
	"BossEventPhase",
	"BossEventStart",
	"BossEventHp",
	"BossEventMaxHp",
	"BossEventStage",
	"BossEventEndsAt",
	"BossScreamEndsAt",
	"BossScheduleStart",
	"BossEventBoss", -- which boss (boss_ui_boss:<id>); nil reads as boss_raga
	"BossMinionHp", -- the Stone Golem (boss_ui_minion:<hp>,<max>)
	"BossMinionMaxHp",
	"BossMinionStart",
	"BossEventNextBoss", -- the next timed event's boss (boss_ui_next:<id>)
}
-- boss_ui_osu_spy (ui_boss_osu): a stand-in Remotes.BossOsu that logs { index, circle, stamp } into ReplicatedStorage attribute
-- UiTestBossOsuLog and answers true, or true, "Dodged" for circle 3 (the last of BossOsu.Count, owner 2026-11-11). restoreBossUi puts the real remote back.
local bossOsuSpy = nil
local function removeBossOsuSpy()
	if bossOsuSpy then
		bossOsuSpy.proxy:Destroy()
		if bossOsuSpy.original then
			bossOsuSpy.original.Name = bossOsuSpy.name
		end
		bossOsuSpy = nil
	end
	ReplicatedStorage:SetAttribute("UiTestBossOsuLog", nil)
end
local function installBossOsuSpy()
	ReplicatedStorage:SetAttribute("UiTestBossOsuLog", "[]")
	if bossOsuSpy then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local original = remotes:FindFirstChild("BossOsu")
	if original then
		original.Name = "UiTestOriginal_BossOsu"
	end
	local proxy = Instance.new("RemoteFunction")
	proxy.Name = "BossOsu"
	proxy:SetAttribute("UiTestIntercepted", true) -- progression_spy leaves it alone
	proxy.OnServerInvoke = function(_, index, circle, stamp)
		local log = HttpService:JSONDecode(ReplicatedStorage:GetAttribute("UiTestBossOsuLog") or "[]")
		table.insert(log, { index, circle, stamp })
		ReplicatedStorage:SetAttribute("UiTestBossOsuLog", HttpService:JSONEncode(log))
		if circle == 3 then
			return true, "Dodged"
		end
		return true
	end
	proxy.Parent = remotes
	bossOsuSpy = { original = original, proxy = proxy, name = "BossOsu" }
end
local function clearBossUi(player)
	for _, name in BOSS_UI_ATTRIBUTES do
		ReplicatedStorage:SetAttribute(name, nil)
	end
	player:SetAttribute("BossEvent", nil)
	player:SetAttribute("BossTeamDamage", nil)
	player:SetAttribute("BossWaitEndsAt", nil)
	player:SetAttribute("BossTeam", nil)
	player:SetAttribute("BossPrepRun", nil)
end
local function restoreBossUi(player)
	clearBossUi(player)
	removeBossOsuSpy()
	local saved = bossUiSnapshots[player]
	if saved then
		live("GachaService").Apply(player, saved.gacha)
		live("SidekickService").Apply(player, saved.sidekicks)
		player:SetAttribute("NeedsStarter", saved.needsStarter)
		player:SetAttribute("BossCredit", saved.bossCredit)
		player:SetAttribute("LastBossTeam", saved.lastBossTeam)
		player:SetAttribute("PaidRandomRestricted", nil)
		setAutoRoll(player, saved.autoRoll == true)
		bossUiSnapshots[player] = nil
	end
end

-- how: a count of characters each wearing a Sidekick, plus one owned without any; or "bag", one Sidekick worn by nobody.
local function bossUiGear(player, how)
	local G, service = live("GachaService"), live("SidekickService")
	if not bossUiSnapshots[player] then
		live("BossEventService").Reset() -- no real event, and no timed one due during the fixture
		bossUiSnapshots[player] = {
			gacha = G.Snapshot(player),
			sidekicks = service.Snapshot(player),
			autoRoll = player:GetAttribute("AutoRoll"),
			needsStarter = player:GetAttribute("NeedsStarter"),
			bossCredit = player:GetAttribute("BossCredit"),
			lastBossTeam = player:GetAttribute("LastBossTeam"),
		}
	end
	player:SetAttribute("LastBossTeam", "") -- a real saved team would fill the HUD's slots before the first pick
	-- Past the starter pick and the roll tutorial: Client/BossEventUi holds the Invite back during them.
	player:SetAttribute("NeedsStarter", nil)
	player:SetAttribute("Rolls", math.max(player:GetAttribute("Rolls") or 0, 1))
	service.Apply(player, { SidekickFreeUsed = true }) -- keeps Client/SidekickTutorial out of this fixture
	local rollable = require(Shared.CharacterCatalog).Rollable()
	if how == "bag" then
		assert(service.Grant(player, "side_knight"))
		return
	end
	for i = 1, how do
		G.Grant(player, rollable[i].Id)
		local _, entry = service.Grant(player, "side_knight")
		assert(service.Equip(player, rollable[i].Id, entry))
	end
	G.Grant(player, rollable[how + 1].Id)
end

-- The roll tutorial as a 0-roll save has it (on), or finished (off). Needs bossUiGear first; restoreBossUi undoes it.
local function bossUiTutorial(player, on)
	if on then
		setAutoRoll(player, false)
		player:SetAttribute("Rolls", 0)
	else
		player:SetAttribute("Rolls", 1)
		setAutoRoll(player, bossUiSnapshots[player].autoRoll == true)
	end
end

-- elapsed "keep" leaves BossEventStart as it is; phase "Idle" clears the event; inEvent and damage are the player's.
local function bossUiState(player, phase, elapsed, hp, max, inEvent, damage)
	if phase == "Idle" then
		clearBossUi(player)
		return
	end
	if tonumber(elapsed) then
		ReplicatedStorage:SetAttribute("BossEventStart", workspace:GetServerTimeNow() - tonumber(elapsed))
	end
	ReplicatedStorage:SetAttribute("BossEventHp", hp)
	ReplicatedStorage:SetAttribute("BossEventMaxHp", max)
	ReplicatedStorage:SetAttribute("BossEventPhase", phase)
	player:SetAttribute("BossTeamDamage", damage)
	player:SetAttribute("BossEvent", inEvent or nil)
end

local BOSS_UI_DAMAGE = 1234
function setups.boss_ui_idle(player)
	bossUiGear(player, 1)
	clearBossUi(player)
	player:SetAttribute("BossCredit", 0)
end
function setups.boss_ui_credit(player)
	setups.boss_ui_idle(player)
	player:SetAttribute("BossCredit", 1)
end
function setups.boss_ui_restricted(player)
	setups.boss_ui_idle(player)
	player:SetAttribute("PaidRandomRestricted", true)
end
function setups.boss_ui_invite(player)
	bossUiGear(player, 2)
	clearBossUi(player)
	bossUiState(player, "Prep", 5, 0, 0, false)
end
-- As boss_ui_invite, for The Elf Mage (boss_mage_button, design doc 4.37 "Second boss").
function setups.boss_ui_invite_mage(player)
	setups.boss_ui_invite(player)
	ReplicatedStorage:SetAttribute("BossEventBoss", "boss_mage")
end
-- As boss_ui_idle, The Elf Mage announced next (boss_cards_next_mage, BOSS_EVENT_SPEC "Bosses cards").
function setups.boss_ui_idle_next_mage(player)
	setups.boss_ui_idle(player)
	ReplicatedStorage:SetAttribute("BossEventNextBoss", "boss_mage")
end
-- As boss_ui_invite, for The Golden King (boss_king_button, design doc 4.37 "Third boss").
function setups.boss_ui_invite_king(player)
	setups.boss_ui_invite(player)
	ReplicatedStorage:SetAttribute("BossEventBoss", "boss_king")
end
-- As boss_ui_idle, The Golden King announced next (boss_cards_next_king, BOSS_EVENT_SPEC "Bosses cards").
function setups.boss_ui_idle_next_king(player)
	setups.boss_ui_idle(player)
	ReplicatedStorage:SetAttribute("BossEventNextBoss", "boss_king")
end
function setups.boss_ui_invite_locked(player)
	bossUiGear(player, 0)
	clearBossUi(player)
	bossUiState(player, "Prep", 5, 0, 0, false)
end
-- Past teleport close, the player outside: the Bosses popup's Go stays, disabled (BOSS_EVENT_SPEC "Paid spawn").
function setups.boss_ui_past_close(player)
	bossUiGear(player, 2)
	clearBossUi(player)
	local config = require(Shared.BossEventConfig)
	bossUiState(player, "Fight", config.JoinSeconds + 5, 4000, 4000, false)
end
function setups.boss_ui_prep_in(player)
	bossUiGear(player, 2)
	bossUiState(player, "Prep", 5, 4000, 4000, true, BOSS_UI_DAMAGE)
end
function setups.boss_ui_fight_in(player)
	bossUiGear(player, 2)
	local config = require(Shared.BossEventConfig)
	bossUiState(player, "Fight", config.PrepSeconds + config.IntroSeconds + 5, 4000, 4000, true, BOSS_UI_DAMAGE)
end

-- Relic fixture (UiSpec.ServerSetup relic_states, relic_states_bare): what they replaced, until 'restore' or restore:<id>.
local relicSnapshots = {}
local function restoreRelics(player)
	local saved = relicSnapshots[player]
	if saved then
		live("RelicService").Apply(player, saved)
		relicSnapshots[player] = nil
	end
end

-- One of every Big Raga Relic in the bag, nothing worn. New entries each time, so the Backpack picks the first again.
function setups.relic_states_bare(player)
	local service, config = live("RelicService"), require(Shared.RelicConfig)
	relicSnapshots[player] = relicSnapshots[player] or service.Snapshot(player)
	service.Apply(player, { SidekickFreeUsed = true }) -- keeps Client/SidekickTutorial out of this fixture
	for _, row in config.Bosses.big_raga do
		assert(service.Grant(player, row.Id), "could not grant " .. row.Id)
	end
end

function setups.relic_states(player)
	setups.relic_states_bare(player)
	local service = live("RelicService")
	local character = live("GachaService").TeamList(player)[1]
	assert(service.Equip(player, character, service.Snapshot(player).Relics[1].Entry), "could not equip a Relic")
end

-- One blocked auto-roll try, as the loop's fire to this client (docs/BAG_AND_AUTOSELL_SPEC.md).
function setups.bag_full_hit(player)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BagFullHit"):FireClient(player)
end

-- Spares on every owned character, for the Sell and Mass sell clicks. No sale runs in them; bag_spares_clear or 'restore' undoes it.
local sparesBefore = {}
function setups.bag_spares(player)
	local before = {}
	for _, entry in player:WaitForChild("GachaData"):GetChildren() do
		before[entry] = entry:GetAttribute("Copies") or 0
		entry:SetAttribute("Copies", 2)
	end
	sparesBefore[player] = before
	live("GachaService").RefreshBag(player)
end

-- A full bag and auto sell at a huge N: the real loop sells each roll and warns (ui_bag_full, owner 2026-11-06).
local autoSellBefore = {}
function setups.bag_full_sold(player)
	local G = live("GachaService")
	autoSellBefore[player] = { on = player:GetAttribute("AutoSell"), chance = player:GetAttribute("AutoSellChance") }
	assert(G.SetAutoSell(player, true, 1000000000000), "auto sell refused")
	local entry = player:WaitForChild("GachaData"):GetChildren()[1]
	sparesBefore[player] = { [entry] = entry:GetAttribute("Copies") or 0 }
	entry:SetAttribute("Copies", math.max(0, G.BagCap(player)))
	G.RefreshBag(player)
end

-- As Copies stood before bag_spares: a bag left full would stop every roll the later clicks wait for.
function setups.bag_spares_clear(player)
	for entry, copies in sparesBefore[player] or {} do
		entry:SetAttribute("Copies", copies)
	end
	sparesBefore[player] = nil
	local sale = autoSellBefore[player]
	if sale then
		player:SetAttribute("AutoSell", sale.on)
		player:SetAttribute("AutoSellChance", sale.chance)
		autoSellBefore[player] = nil
	end
	live("GachaService").RefreshBag(player)
end

-- A full bag stops every roll (design doc 4.41) and a full run's rolls fill it, so auto_racing and auto_roll_on empty the
-- spares from half full (placeholder: a scenario's rolls must fit). Not while a bag fixture holds the bag on purpose.
-- Still full: an error, which the run shows as setup_error and bag_has_room_*. restoreBagRoom gives the copies back.
local bagRoomBefore = {}
local function makeBagRoom(player)
	local G = live("GachaService")
	if sparesBefore[player] or G.BagUsed(player) * 2 < G.BagCap(player) then
		return
	end
	local before = bagRoomBefore[player] or {}
	bagRoomBefore[player] = before
	for _, entry in player:WaitForChild("GachaData"):GetChildren() do
		before[entry.Name] = before[entry.Name] or entry:GetAttribute("Copies") or 0
		entry:SetAttribute("Copies", 0)
	end
	G.RefreshBag(player)
	if G.BagFull(player) then
		error(("bag full with no spares: %d/%d"):format(G.BagUsed(player), G.BagCap(player)))
	end
end

local function restoreBagRoom(player)
	local before = bagRoomBefore[player]
	if not before then
		return
	end
	bagRoomBefore[player] = nil
	local data = player:FindFirstChild("GachaData")
	for name, copies in before do
		local entry = data and data:FindFirstChild(name)
		if entry then
			entry:SetAttribute("Copies", copies)
		end
	end
	live("GachaService").RefreshBag(player)
end

function setups.restore(player)
	setups.bag_spares_clear(player)
	restoreBossUi(player)
	setups.sidekick_tutorial_restore(player)
	restoreSidekicks(player)
	restoreRelics(player)
	longStamina[player] = nil
	local snap = snapshots[player]
	if not snap then
		error(
			"no snapshot for " .. player.Name .. " (restore consumes it: run 'snapshot' again before the next fixture)"
		)
	end
	live("GachaService").Apply(player, snap.gacha)
	restoreBagRoom(player) -- after Apply: a snapshot taken once the spares were gone would not hold them
	local progression = progressionSnapshots[player]
	if progression then
		live("UpgradeService").Apply(player, progression.upgrades)
		if progression.raceTimes then
			live("RaceTimeService").Apply(player, { RaceBestTimes = progression.raceTimes })
		end
		for name, entry in progression.attributes do
			player:SetAttribute(name, entry.value)
		end
		progressionSnapshots[player] = nil
		if progression.root and player.Character then
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = progression.root
			end
		end
	end
	if snap.upgrades then
		-- The baseline taken before any fixture (TurboCount after turbo_next included)
		live("UpgradeService").Apply(player, snap.upgrades)
	end
	if questSnapshots[player] then
		live("QuestService").Apply(player, questSnapshots[player])
		questSnapshots[player] = nil
	end
	if weatherSnapshot then
		for name, entry in weatherSnapshot do
			ReplicatedStorage:SetAttribute(name, entry.value)
		end
		weatherSnapshot = nil
	end
	local money = stat(player, "Money")
	if money and snap.money ~= nil then
		money.Value = snap.money
	end
	live("CarService").SetAutoRace(player, snap.autoRacing == true)
	if snap.autoRoll ~= nil then
		setAutoRoll(player, snap.autoRoll == true)
	end
	player:SetAttribute("UiTestRollOdds", nil) -- UiSpec.RollOdds.Attr
	snapshots[player] = nil
	removeSpy()
end

function setups.index_states(player)
	indexStates(player)
end

-- Team panel (UiSpec.Team, Client/UiTest/UiTeam; design doc 4.40): index_states, on foot, Team = A,B of three owned
-- rollable ids A,B,C that are off the Dojo squad, published as UiTestTeamIds = "A,B,C". team_states_clear puts it back.
local teamBefore = {} -- [Player] = the Team attribute before team_states
function setups.team_states(player)
	indexStates(player)
	local G, C, CarService = live("GachaService"), require(Shared.CharacterCatalog), live("CarService")
	CarService.SetAutoRace(player, false)
	local start = os.clock()
	while CarService.IsAutoRacing(player) or player:GetAttribute("AutoRacing") == true do
		if player.Parent ~= Players or os.clock() - start > 5 then
			error("team_states: still racing after 5 s")
		end
		RunService.Heartbeat:Wait()
	end
	if teamBefore[player] == nil then
		teamBefore[player] = player:GetAttribute("Team") or ""
	end
	-- No Dojo squad since design doc 4.43 (GachaService.ShowcaseIds removed): nothing is excluded.
	local data, squad, ids = player:FindFirstChild("GachaData"), {}, {}
	for _, spec in C.All() do
		if #ids < 3 and spec.Rollable and data and data:FindFirstChild(spec.Id) and not squad[spec.Id] then
			table.insert(ids, spec.Id)
		end
	end
	assert(#ids == 3, "team_states: fewer than 3 owned characters off the Dojo squad")
	local ok, why = G.SetTeam(player, { ids[1], ids[2] })
	assert(ok, "team_states: SetTeam refused: " .. tostring(why))
	player:SetAttribute("UiTestTeamIds", table.concat(ids, ","))
end

function setups.team_states_clear(player)
	local before = teamBefore[player]
	teamBefore[player] = nil
	player:SetAttribute("UiTestTeamIds", nil)
	if before and before ~= "" then
		live("GachaService").SetTeam(player, string.split(before, ","))
	end
end

-- ui_feedback: clients cannot read ServerStorage, so publish what its sound folder holds (docs/UI_FEEDBACK_SPEC.md 1).
function setups.impact_sounds_report()
	local report = {}
	local folder = game:GetService("ServerStorage"):FindFirstChild("ImpactSounds")
	for _, item in folder and folder:GetChildren() or {} do
		table.insert(report, { Name = item.Name, Class = item.ClassName, SoundId = item:IsA("Sound") and item.SoundId })
	end
	ReplicatedStorage:SetAttribute("UiTestImpactSounds", HttpService:JSONEncode(report))
end

function setups.stat_points(player)
	indexStates(player)
end

function setups.no_stat_points(player)
	local G = live("GachaService")
	player:SetAttribute("Alloc_Speed", (player:GetAttribute("Alloc_Speed") or 0) + G.FreePoints(player))
	player:SetAttribute("StatPoints", G.FreePoints(player))
end

local AUTO_RACING_TIMEOUT = 10 -- seconds for a stop / start to land
function setups.auto_racing(player)
	local CarService = live("CarService")
	wrapNewRun()
	local fresh = not longStamina[player]
	longStamina[player] = true
	-- a run started before the seam was on still tires: start a new one (stop, then start)
	if fresh and CarService.IsAutoRacing(player) == true then
		CarService.SetAutoRace(player, false)
	end
	local start = os.clock()
	while CarService.IsAutoRacing(player) ~= true do
		CarService.SetAutoRace(player, true)
		if player.Parent ~= Players or os.clock() - start > AUTO_RACING_TIMEOUT then
			error("auto_racing: not auto racing after " .. AUTO_RACING_TIMEOUT .. " s")
		end
		task.wait(0.25)
	end
	makeBagRoom(player)
end

-- UiSpec.ServerSetup on_foot (ui_speed_dial at rest): auto race stopped through the real Stop path, avatar on foot
-- with no car. Done is only set once that holds; 'restore' puts AutoRacing back (snap.autoRacing).
local ON_FOOT_TIMEOUT = 5 -- seconds
function setups.on_foot(player)
	assert(snapshots[player], "snapshot required before on_foot ('restore' consumes it: take a fresh 'snapshot')")
	local CarService = live("CarService")
	CarService.SetAutoRace(player, false)
	local start = os.clock()
	while
		CarService.IsAutoRacing(player)
		or player:GetAttribute("AutoRacing") == true
		or CarService.GetCar(player) ~= nil
	do
		if player.Parent ~= Players or os.clock() - start > ON_FOOT_TIMEOUT then
			error("on_foot: player still racing or still has a car after " .. ON_FOOT_TIMEOUT .. " s")
		end
		RunService.Heartbeat:Wait()
	end
end

-- ui_sidekick_follow (design doc 4.36; Client/UiTest/UiSidekickFollow): a rig of this player's, drawn by the real Client/RunnerView,
-- with Sidekicks worn per character through the real SidekickService. Crowd rigs have no Player, as a solo Studio run has no others:
-- attribute FollowerFixtureId says what they wear. Characters and Sidekicks come back with restoreBossUi, and a stopped run restarts.
local FOLLOW_FAKE_ID = -1000 -- the crowd's first Owner is one below this
local FOLLOW_CROWD_GAP = 12 -- studs along +X
local sidekickFollow = { Rig = nil, Crowd = {}, Thread = nil, Entries = {}, WasRacing = nil }

local function followRig(name, id, owner, along)
	local RunnerFactory = require(Shared.RunnerFactory)
	local rig = RunnerFactory.build(id)
	rig.Name = name
	rig.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	rig:PivotTo(CFrame.new(RUN_VISUAL.START + Vector3.new(along, RunnerFactory.HIP_HEIGHT, 0)))
	rig:SetAttribute("Owner", owner)
	return rig
end

local function followShow(rig)
	CollectionService:AddTag(rig, live("CarService").RUNNER_TAG)
	rig.Parent = Workspace
end

local function followStopRun()
	if sidekickFollow.Thread then
		task.cancel(sidekickFollow.Thread)
		sidekickFollow.Thread = nil
	end
end

local function followCrowd(count)
	for _, rig in sidekickFollow.Crowd do
		rig:Destroy()
	end
	sidekickFollow.Crowd = {}
	local id = require(Shared.CharacterCatalog).Rollable()[1].Id
	for i = 1, count do
		local rig = followRig("FollowCrowd" .. i, id, FOLLOW_FAKE_ID - i, i * FOLLOW_CROWD_GAP)
		rig:SetAttribute("FollowerFixtureId", "side_chain")
		followShow(rig)
		table.insert(sidekickFollow.Crowd, rig)
	end
end

local function restoreSidekickFollow(player)
	followStopRun()
	followCrowd(0)
	if sidekickFollow.Rig then
		sidekickFollow.Rig:Destroy()
		sidekickFollow.Rig = nil
	end
	local routes = ReplicatedStorage:FindFirstChild("RunRoutes")
	local route = routes and routes:FindFirstChild(RUN_VISUAL.ROUTE)
	if route then
		route:Destroy()
	end
	sidekickFollow.Entries = {}
	restoreBossUi(player)
	if sidekickFollow.WasRacing then
		live("CarService").SetAutoRace(player, true)
	end
	sidekickFollow.WasRacing = nil
end

local sidekickFollowSteps = {}

function sidekickFollowSteps.start(player)
	local CarService = live("CarService")
	RUN_VISUAL.clear()
	sidekickFollow.WasRacing = CarService.IsAutoRacing(player) == true
	CarService.SetAutoRace(player, false)
	local start = os.clock()
	while CarService.IsAutoRacing(player) or CarService.GetCar(player) ~= nil do
		if os.clock() - start > ON_FOOT_TIMEOUT then
			error("sidekick_follow_start: still racing after " .. ON_FOOT_TIMEOUT .. " s")
		end
		RunService.Heartbeat:Wait()
	end
	bossUiGear(player, 0) -- the snapshot; a save past the starter pick, nothing worn
	local rollable = require(Shared.CharacterCatalog).Rollable()
	for i = 2, 4 do
		live("GachaService").Grant(player, rollable[i].Id)
	end
	sidekickFollow.Rig = followRig("FollowRunner", rollable[1].Id, player.UserId, 0)
	followShow(sidekickFollow.Rig)
end

function sidekickFollowSteps.wear(player, arg)
	local character, id = string.match(arg, "^([^:]+):([^:]+)$")
	local service = live("SidekickService")
	if id == "none" then
		assert(service.Equip(player, character, nil))
		return
	end
	if not sidekickFollow.Entries[id] then
		local _, entry = service.Grant(player, id)
		sidekickFollow.Entries[id] = assert(entry, "could not grant " .. id)
	end
	assert(service.Equip(player, character, sidekickFollow.Entries[id]))
end

-- A slot swap's re-skin, as CarService.ApplyCharacter does it.
function sidekickFollowSteps.swap(_, arg)
	require(Shared.RunnerFactory).Restyle(sidekickFollow.Rig, arg)
end

-- A real run's published state, as RUN_VISUAL.start publishes it.
function sidekickFollowSteps.run(_, arg)
	setups.run_visual()
	local PathDriver = require(Shared.PathDriver)
	local RunnerFactory = require(Shared.RunnerFactory)
	local wps = { RUN_VISUAL.START, RUN_VISUAL.START + Vector3.new(RUN_VISUAL.LENGTH, 0, 0) }
	local arc = PathDriver.Arc(wps)
	local speed = tonumber(arg)
	local rig = sidekickFollow.Rig
	local started = os.clock()
	local interval = live("RaceService").PUBLISH_INTERVAL
	followStopRun()
	sidekickFollow.Thread = task.spawn(function()
		while true do
			local dist = (os.clock() - started) * speed % RUN_VISUAL.LENGTH
			rig:PivotTo(PathDriver.PoseAt(wps, arc, dist) * CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0))
			rig:SetAttribute("RunRoute", RUN_VISUAL.ROUTE)
			rig:SetAttribute("RunSpeed", speed)
			rig:SetAttribute("RunDistance", dist)
			task.wait(interval)
		end
	end)
end

function sidekickFollowSteps.stop()
	followStopRun()
	local rig = sidekickFollow.Rig
	rig:SetAttribute("RunRoute", nil)
	rig:SetAttribute("RunSpeed", nil)
	rig:SetAttribute("RunDistance", nil)
end

function sidekickFollowSteps.crowd(_, arg)
	followCrowd(tonumber(arg))
end

-- A batch as Remotes.BossHits carries it, to this client only (ui_sidekick_attack). No damage is dealt.
-- arg: <userId|me>:<sidekick id>:<damage>:<character id>:<slot>, comma separated.
function sidekickFollowSteps.hits(player, arg)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("BossHits")
	assert(remote, "Remotes.BossHits is missing")
	local entries = {}
	for _, text in string.split(arg, ",") do
		local user, id, damage, character, slot = table.unpack(string.split(text, ":"))
		table.insert(entries, {
			UserId = user == "me" and player.UserId or tonumber(user),
			SidekickId = id,
			Damage = tonumber(damage),
			Slot = tonumber(slot),
			CharacterId = character,
		})
	end
	remote:FireClient(player, entries)
end

-- The run ends: the runner goes, as CarService's removeCar does it.
sidekickFollowSteps["end"] = function()
	followCrowd(0)
	sidekickFollow.Rig:Destroy()
	sidekickFollow.Rig = nil
end

-- A fake loss sent to the client only (the real run's state is never touched): Result/Lose now, then after
-- NpcConfig.LOSE_SCREEN_SECONDS a Reset to Track 1 and a Start for Track 1, shaped like RaceService's events.
-- Done is set right after the Result is sent, so the loser screen can be checked while it shows.
function setups.lose_event(player)
	local NpcConfig = require(Shared.NpcConfig)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace")
	local run = live("CarService").GetRun(player)
	local track = type(run) == "table" and type(run.RaceTrack) == "number" and run.RaceTrack or 1
	remote:FireClient(player, {
		Type = "Result",
		Track = track,
		Result = "Lose",
		PlayerTime = 31.5,
		NpcTime = 30,
		Banked = 0, -- a loss pays nothing (earlier checkpoints stay paid, owner 2026-11-10)
	})
	task.delay(NpcConfig.LOSE_SCREEN_SECONDS, function()
		if player.Parent ~= Players then
			return
		end
		remote:FireClient(player, { Type = "Reset", Track = 1 })
		local cfg = NpcConfig.For(1)
		remote:FireClient(player, {
			Type = "Start",
			Track = 1,
			ServerStart = workspace:GetServerTimeNow(),
			Speed = cfg.Speed,
			Color = cfg.Color,
			Label = cfg.Label,
			Model = cfg.Model,
		})
	end)
end

-- A fake checkpoint payout notice to this client only (UiSpec ui_hud): shaped like RaceService's RunEvent CashOut;
-- Money is not touched. Amount: UiSpec.Hud.CashOutNotice.Amount.
function setups.cash_out_notice(player)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RunEvent"):FireClient(player, {
		Kind = "CashOut",
		Amount = 1234,
		Track = 1,
	})
end

-- Enemy showdown (UiSpec ui_showdown, design doc 4.28): fake events to this client only, shaped like RaceService's;
-- the real run's state is never touched. A real win fires Result and the next Start in the same frame.
local function fireShowdownStart(player, track)
	local cfg = require(Shared.NpcConfig).For(track)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace"):FireClient(player, {
		Type = "Start",
		Track = track,
		ServerStart = workspace:GetServerTimeNow(),
		Speed = cfg.Speed,
		Color = cfg.Color,
		Label = cfg.Label,
		Model = cfg.Model,
		BestTime = live("RaceTimeService").Best(player, track),
	})
end

function setups.showdown_start(player)
	local run = live("CarService").GetRun(player)
	local track = type(run) == "table" and type(run.RaceTrack) == "number" and run.RaceTrack or 1
	player:SetAttribute("UiTestShowdownTrack", track)
	fireShowdownStart(player, track)
end

function setups.showdown_win(player)
	local track = player:GetAttribute("UiTestShowdownTrack") or 1
	player:SetAttribute("UiTestShowdownTrack", nil)
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace"):FireClient(player, {
		Type = "Result",
		Track = track,
		Result = "Win",
		PlayerTime = 30,
		NpcTime = 31.5,
		Bonus = 1,
		Banked = 0,
		BestTime = live("RaceTimeService").Best(player, track),
		NewBest = false,
	})
	fireShowdownStart(player, track % #require(Shared.NpcConfig).Tracks + 1)
end

-- Turbo luck: the upgrade tree decides it (UpgradeService.AdvanceTurbo: turbo when TurboCount + 1 >= Every of
-- UpgradeService.Turbo(player)), so TurboCount = Every - 1 makes the next auto roll a turbo roll. Rolls alone no
-- longer does. 'restore' puts the snapshot's upgrade state (TurboCount included) back.
function setups.turbo_next(player)
	local U = live("UpgradeService")
	local turbo = U.Turbo(player)
	local every = type(turbo) == "table" and turbo.Every
	if type(every) ~= "number" or every < 1 then
		error("UpgradeService.Turbo(player).Every missing")
	end
	player:SetAttribute("TurboEvery", every)
	player:SetAttribute("TurboCount", every - 1)
end

-- Roll animation (docs/ROLL_ANIMATION_SPEC.md): the next auto roll is an emphasized roll. Owning no rollable car
-- makes any roll new, and EMPHASIS_MULTI 0 drops the bar for this one roll (GachaConfig.IsEmphasized). As soon as that roll
-- happened (Rolls changed) exactly the cars owned before are given back (the rolled one is not kept), with the new
-- roll count, so later rolls are not emphasized by accident and no car is gained.
function setups.emphasized_next(player)
	local G = live("GachaService")
	local before = G.Snapshot(player)
	local empty = table.clone(before)
	empty.Cars = {}
	G.Apply(player, empty)
	local GachaConfig = require(game:GetService("ReplicatedStorage").Shared.GachaConfig)
	local multi = GachaConfig.EMPHASIS_MULTI
	GachaConfig.EMPHASIS_MULTI = 0
	local rolls0 = player:GetAttribute("Rolls")
	task.spawn(function()
		local deadline = os.clock() + 60
		while player.Parent == Players and player:GetAttribute("Rolls") == rolls0 and os.clock() < deadline do
			task.wait(0.05)
		end
		GachaConfig.EMPHASIS_MULTI = multi
		if player.Parent ~= Players then
			return
		end
		before.Rolls = player:GetAttribute("Rolls")
		G.Apply(player, before)
	end)
end

function setups.auto_roll_on(player)
	setAutoRoll(player, true)
	makeBagRoom(player)
end

local function progressionSnapshot(player)
	if not snapshots[player] then
		error("snapshot required before progression fixtures ('restore' consumes it: take a fresh 'snapshot')")
	end
	if progressionSnapshots[player] then
		return
	end
	local attributes = {}
	for _, name in { "UiTestProgressionFixture" } do
		attributes[name] = { value = player:GetAttribute(name) }
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	progressionSnapshots[player] =
		{ upgrades = live("UpgradeService").Snapshot(player), attributes = attributes, root = root and root.CFrame }
end

-- The Rebirth panel's button state (UiSpec.ServerSetup rebirth_*): leaderstats.Money set to the rebirth Money
-- requirement (eligible) or one below it (not eligible). Money comes back on 'restore' (the 'snapshot' value).
-- Auto-roll goes off so no duplicate-car sale (MoneyService.Award) moves Money during the click
-- (rebirth_money_not_reset is exact); 'restore' turns it back to the 'snapshot' value (snap.autoRoll).
local function rebirthMoneyFixture(player, offset)
	setups.snapshot(player) -- no-op when taken already; it holds the Money 'restore' puts back
	progressionSnapshot(player)
	setAutoRoll(player, false)
	local RebirthConfig = require(Shared.RebirthConfig)
	local need = RebirthConfig.Requirements(player:GetAttribute("RebirthLevel") or 0).Money
	assert(stat(player, "Money"), "Money required").Value = need + offset
end

function setups.rebirth_eligible(player)
	rebirthMoneyFixture(player, 0)
end

function setups.rebirth_not_eligible(player)
	rebirthMoneyFixture(player, -1)
end

function setups.progression_buyable(player)
	progressionSnapshot(player)
	live("UpgradeService").Apply(player, { Upgrades = {}, BestTrack = 0, TurboCount = 0 })
	local money = assert(stat(player, "Money"), "Money required")
	money.Value = 100000
	live("UpgradeService").Refresh(player)
end

function setups.progression_no_money(player)
	setups.progression_buyable(player)
	stat(player, "Money").Value = 0
	live("UpgradeService").Refresh(player)
end

-- Daily reward fixtures (UiSpec.ServerSetup daily_*): unsaved DailyLast; 'restore' puts DailyLast / DailyStreak back.
local function dailyFixture(player, last)
	progressionSnapshot(player)
	local attributes = progressionSnapshots[player].attributes
	for _, name in { "DailyLast", "DailyStreak" } do
		if attributes[name] == nil then
			attributes[name] = { value = player:GetAttribute(name) }
		end
	end
	player:SetAttribute("DailyLast", last)
end

function setups.daily_unclaimed(player)
	dailyFixture(player, -1)
end

function setups.daily_claimed(player)
	dailyFixture(player, math.floor(os.time() / 86400)) -- DailyLoginService dayNumber
end

-- Checkpoint fixtures (UiSpec checkpoint_*, docs/CHECKPOINT_SPEC.md): racing and rolls paused (a finish would raise
-- BestTrack), unsaved Checkpoint = 1 and BestTrack. 'restore' puts Checkpoint, BestTrack (the upgrade snapshot),
-- AutoRacing and AutoRoll back.
local function checkpointFixture(player, best)
	progressionSnapshot(player)
	local attributes = progressionSnapshots[player].attributes
	if attributes.Checkpoint == nil then
		attributes.Checkpoint = { value = player:GetAttribute("Checkpoint") }
	end
	setups.on_foot(player)
	setAutoRoll(player, false)
	player:SetAttribute("Checkpoint", 1)
	player:SetAttribute("BestTrack", best)
end

function setups.checkpoint_locked(player)
	checkpointFixture(player, 0)
end

function setups.checkpoint_open(player)
	checkpointFixture(player, 2)
end

-- Defeated Enemies page (UiSpec ui_defeated, design doc 4.29): BestTrack 2, known bests for Tracks 1 and 2, the same
-- times on unsaved attributes for the client to compare with. 'restore' puts the bests and attributes back.
function setups.defeated_states(player)
	checkpointFixture(player, 2)
	local progression = progressionSnapshots[player]
	local times = { ["1"] = 41.25, ["2"] = 52.5 }
	progression.raceTimes = progression.raceTimes or live("RaceTimeService").Snapshot(player)
	live("RaceTimeService").Apply(player, { RaceBestTimes = times })
	for track, seconds in times do
		local name = "UiTestBestTime" .. track
		progression.attributes[name] = { value = nil }
		player:SetAttribute(name, seconds)
	end
end

-- Quest fixtures (UiSpec quest_claim_*, docs/QUESTS_SPEC.md): today's daily_races quest unclaimed with progress 0
-- (incomplete: Claim disabled) or at its Target (complete: Claim enabled). Unsaved; 'restore' applies the
-- QuestService snapshot taken before the first quest fixture.
local function questFixture(player, complete)
	assert(
		snapshots[player],
		"snapshot required before quest fixtures ('restore' consumes it: take a fresh 'snapshot')"
	)
	local QuestService = live("QuestService")
	local saved = QuestService.Snapshot(player)
	if not questSnapshots[player] then
		questSnapshots[player] = saved
	end
	local target
	for _, quest in require(Shared.QuestConfig).Daily do
		if quest.Id == "daily_races" then
			target = quest.Target
		end
	end
	assert(target, "QuestConfig.Daily has no daily_races")
	local fixture = table.clone(saved)
	fixture.QuestDaily = table.clone(saved.QuestDaily)
	fixture.QuestDailyClaimed = table.clone(saved.QuestDailyClaimed)
	fixture.QuestDaily.daily_races = complete and target or 0
	fixture.QuestDailyClaimed.daily_races = nil
	QuestService.Apply(player, fixture)
end

function setups.quest_incomplete(player)
	questFixture(player, false)
end

function setups.quest_complete(player)
	questFixture(player, true)
end

-- retired: offline_welcome / offline_zero fixtures, no offline credit or its welcome (design doc 4.19, owner 2026-11-03)

-- retired: world fixtures (moveTo, workshop E-prompt spots): Dojos removed, design doc 4.43 (owner 2026-11-11)

-- weather_clear = no weather (""); weather_clear_event = the weather id "clear", running like any other
for _, event in { "rain", "night", "gold", "aurora", "clear", "clear_event" } do
	local id = event == "clear" and "" or event == "clear_event" and "clear" or event
	setups["weather_" .. event] = function(player)
		progressionSnapshot(player)
		if not weatherSnapshot then
			weatherSnapshot = {}
			for _, name in { "WeatherEvent", "WeatherEndsAt" } do
				weatherSnapshot[name] = { value = ReplicatedStorage:GetAttribute(name) }
			end
		end
		ReplicatedStorage:SetAttribute("WeatherEvent", id)
		ReplicatedStorage:SetAttribute("WeatherEndsAt", id == "" and 0 or workspace:GetServerTimeNow() + 180)
	end
end

-- Duel UI fixtures (UiSpec.Duel.Fixture / FixtureChecks): fire Remotes.Duel at the test client only, DUEL_GAP
-- seconds between messages. DuelService is never called, so no real duel starts and no state needs a restore.
do
	local DuelConfig = require(Shared.DuelConfig)
	local DUEL_GAP = 0.6
	local OPPONENT, TRACKS, TRACK, SECOND_TRACKS = "UiTestRival", { 1, 2, 3 }, 2, { 2 } -- UiSpec.Duel.Fixture

	local function pick(tracks)
		return { Type = "PickTrack", Opponent = OPPONENT, Tracks = tracks or TRACKS }
	end
	local invite = { Type = "Invite", Opponent = OPPONENT, Track = TRACK }
	local function result(outcome, time, opponentTime, probe)
		return {
			Type = "Result",
			Result = outcome,
			Track = TRACK,
			Time = time,
			OpponentTime = opponentTime,
			UiTestPanelProbe = probe, -- UiSpec.Duel.ProbeField
		}
	end
	local function countdown()
		return { Type = "Countdown", Track = TRACK, ServerStart = workspace:GetServerTimeNow() + DuelConfig.COUNTDOWN }
	end

	-- A step is a message, a function that builds one when it is sent, or the PanelSwitch name the harness opens first
	local steps = {
		duel_pick = { pick() },
		duel_pick_replaced = { pick(), pick(SECOND_TRACKS) },
		duel_pick_over_index = { "Index", pick() },
		duel_invite = { invite },
		duel_invite_over_stats = { "Stats", invite },
		duel_invite_over_pick = { pick(), invite },
		duel_countdown = { invite, countdown },
		duel_result_win = { pick(), result("Win", 12.3, 13.1) },
		duel_result_lose = { pick(), result("Lose", 13.1, 12.3) },
		duel_result_draw = { pick(), result("Draw", 12.3, 12.3) },
		duel_toast_panel = { result("Win", 12.3, 13.1, "Index") },
		duel_cancel_unknown = { invite, { Type = "Cancelled", Reason = "UiTestUnknownReason" } },
	}
	-- UiSpec.Duel.CancelText
	for _, reason in
		{ "Declined", "InviteTimeout", "PickTimeout", "Left", "NotOnFoot", "Busy", "Cooldown", "NotLoaded" }
	do
		steps["duel_cancel_" .. string.lower(reason)] = { invite, { Type = "Cancelled", Reason = reason } }
	end

	for id, list in steps do
		setups[id] = function(player)
			local remote = ReplicatedStorage.Remotes:FindFirstChild("Duel")
			assert(remote and remote:IsA("RemoteEvent"), "Duel RemoteEvent required")
			for i, step in list do
				if i > 1 then
					task.wait(DUEL_GAP)
				end
				if type(step) == "string" then
					-- UiSpec.Duel.PrepAttr
					player:SetAttribute("UiTestDuelPrep", step .. ":" .. HttpService:GenerateGUID(false))
				else
					remote:FireClient(player, type(step) == "function" and step() or step)
				end
			end
		end
	end
end

-- Displayed-odds fixtures (UiSpec.RollOdds; docs/ROLL_ANIMATION_SPEC.md: RollResult's 6th argument is the roll's
-- luck). They only fire Remotes.RollResult at the test client: nothing is rolled, granted or paid. AutoRoll goes off
-- so no real roll covers the planted ones; 'restore' turns it back on and clears the attribute.
do
	local CharacterCatalog = require(Shared.CharacterCatalog)
	local RollAnimConfig = require(Shared.RollAnimConfig)
	local WeatherConfig = require(Shared.WeatherConfig)
	local GAP = 1 -- seconds between two animations

	-- The most common rollable car with a Chance >= 100 for `event` (nil = a car of no event), else any with a Chance
	local function carWithChance(event)
		local pick, fallback = nil, nil
		for _, spec in CharacterCatalog.Rollable() do -- rarest first
			if type(spec.Chance) == "number" and spec.Event == event then
				fallback = fallback or spec
				if spec.Chance >= 100 then
					pick = spec
				end
			end
		end
		return pick or fallback
	end

	local function catchAll()
		for _, spec in CharacterCatalog.Rollable() do
			if spec.Chance == 1 and spec.Event == nil then
				return spec
			end
		end
		return nil
	end

	-- A compact roll, then an emphasized one (it plays on the enlarged card), both with `luck` as the 6th argument
	local function plant(player, fixture, spec, luck)
		assert(snapshots[player], "snapshot required before " .. fixture .. " ('restore' turns AutoRoll back on)")
		assert(spec, "no catalog car for " .. fixture)
		local remote = ReplicatedStorage.Remotes:FindFirstChild("RollResult")
		assert(remote and remote:IsA("RemoteEvent"), "RollResult RemoteEvent required")
		setAutoRoll(player, false)
		player:SetAttribute(
			"UiTestRollOdds",
			HttpService:JSONEncode({
				fixture = fixture,
				id = spec.Id,
				luck = luck,
				nonce = HttpService:GenerateGUID(false),
			})
		)
		task.spawn(function()
			task.wait(RollAnimConfig.Duration("Secret", true) + GAP) -- a real roll may still be playing
			for _, emphasized in { false, true } do
				if player.Parent ~= Players then
					return
				end
				remote:FireClient(player, spec.Id, false, 1, emphasized, 0, luck)
				task.wait(RollAnimConfig.Duration(spec.Rarity, emphasized) + GAP)
			end
		end)
	end

	-- UiSpec.RollOdds.Fixtures
	local lucks = {
		roll_odds_luck2 = function()
			return 2
		end,
		roll_odds_round = function()
			return 3
		end,
		roll_odds_clamp = function(spec)
			return spec.Chance * 4
		end,
		roll_odds_luck1 = function()
			return 1
		end,
		roll_odds_no_luck = function()
			return nil
		end,
	}
	for id, luck in lucks do
		setups[id] = function(player)
			local spec = assert(carWithChance(nil), "no rollable car with a Chance")
			plant(player, id, spec, luck(spec))
		end
	end

	function setups.roll_odds_catchall(player)
		plant(player, "roll_odds_catchall", catchAll(), 2)
	end

	-- What the server sends for a roll during Rain: this player's luck with the Rain multi in it
	function setups.weather_rain_roll(player)
		setups.weather_rain(player)
		local luck = live("GachaService").Luck(player)
		if live("WeatherService").Current() ~= "rain" then
			luck *= WeatherConfig.Events.rain.Luck -- the fixture only replicates the event, WeatherService is not in it
		end
		plant(player, "weather_rain_roll", carWithChance("rain") or carWithChance(nil), luck)
	end
end

local function progressionSpy()
	local folder = assert(ReplicatedStorage:FindFirstChild("UiTestSpy"), "spy setup required first")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	-- Rebirth too: the rebirth_* clicks must never really reset Money (UiSpec rebirth clicks, Intercept)
	-- UiSpec.RemoteFunctions: the rest must never really buy, equip, use a potion, claim or redeem (market_action_buy and
	-- the other Intercept clicks). Missing ones are skipped here; the client's Intercept check then reports them.
	local required = { BuyUpgrade = true, Rebirth = true }
	for _, name in
		{
			"BuyUpgrade",
			"Rebirth",
			"MarketPurchase",
			"MarketEquip",
			"UseBoost",
			"DailyClaim",
			"QuestClaim",
			"RedeemCode",
			"SetCheckpoint",
			"PrepareGift",
			"BossEventTeleport",
			"BossEventSetTeam",
			"BossEventLeave",
			"BossEventPrepRun",
			"BossBuy",
			"BossUseCredit",
			"BossOsu",
		}
	do
		local target = remotes:FindFirstChild(name)
		if not required[name] and not (target and target:IsA("RemoteFunction")) then
			continue
		end
		assert(target and target:IsA("RemoteFunction"), name .. " RemoteFunction required")
		folder:SetAttribute(name, "[]")
		if target:GetAttribute("UiTestIntercepted") ~= true then
			-- ProgressionUi and RacerUiController resolve their targets with WaitForChild inside Activated, so a same-name proxy
			-- intercepts every argument while keeping the original callback and its cooldown closure intact.
			target.Name = "UiTestOriginal_" .. name
			local proxy = Instance.new("RemoteFunction")
			proxy.Name = name
			proxy:SetAttribute("UiTestIntercepted", true)
			functionSpies[target] = { name = name, proxy = proxy }
			proxy.OnServerInvoke = function(player, ...)
				local log = HttpService:JSONDecode(folder:GetAttribute(name) or "[]")
				table.insert(log, { user = player.UserId, args = { ... } })
				folder:SetAttribute(name, HttpService:JSONEncode(log))
				-- shop_redeem_invalid_code must see the server's real reply: a UiSpec.Shop.TestCode-style code (prefix
				-- "UITEST-", never a real code) goes to the real ShopService.Redeem, which answers and saves nothing.
				if name == "BossEventSetTeam" then
					return true -- boss_pick_character judges the slot it fills; the real handler knows no fixture member
				end
				if name == "BossOsu" then -- a circle press: accepted, the 4th dodges (ui_boss_osu)
					local _, circle = ...
					if circle == 4 then
						return true, "Dodged"
					end
					return true
				end
				local text = ...
				if name == "RedeemCode" and type(text) == "string" and string.sub(text, 1, 7) == "UITEST-" then
					return live("ShopService").Redeem(player, text)
				end
				return false, "money"
			end
			proxy.Parent = remotes
		end
	end
	folder:SetAttribute("ProgressionIntercepted", true)
end

local function runSetup(request)
	local id = string.match(request, "^([^:]+):")
	local arg = string.match(request, "^[^:]+:(.*):[^:]*$") -- "<id>:<args>:<nonce>"; nil for "<id>:<nonce>"
	ReplicatedStorage:SetAttribute("UiTestSetupError", nil)
	local ok, err = pcall(function()
		if id == "spy" then
			spy()
			return
		end
		if id == "progression_spy" then
			progressionSpy()
			return
		end
		local fn = id and setups[id]
		if not fn then
			error("unknown setup id " .. tostring(id))
		end
		for _, player in Players:GetPlayers() do
			fn(player, arg)
		end
	end)
	if not ok then
		ReplicatedStorage:SetAttribute("UiTestSetupError", request .. ":" .. tostring(err))
	end
	ReplicatedStorage:SetAttribute("UiTestSetupDone", request)
end

local queue, busy = {}, false
local function onRequest()
	local request = ReplicatedStorage:GetAttribute("UiTestSetup")
	if type(request) ~= "string" or request == "" then
		return
	end
	table.insert(queue, request)
	if busy then
		return
	end
	busy = true
	while #queue > 0 do
		runSetup(table.remove(queue, 1))
	end
	busy = false
end

ReplicatedStorage:GetAttributeChangedSignal("UiTestSetup"):Connect(onRequest)

-- Full UI run (UiTestRun): the client harness asks for the states its scenarios need (UiScenarios.Needs) through
-- this Studio-only RemoteFunction, for its own player only, and restores them after the run ("restore:<id>").
-- Only these ids; everything else stays driven from the server datamodel as before.
-- ui_sidekick_tutorial (design doc 4.36; Client/UiTest/UiSidekickTutorial): at the unlock with the free summon unused, on foot,
-- past the roll tutorial. Steps sidekick_tutorial:rebirth:<n> and sidekick_tutorial:block:<run|duel|showdown|boss|off>.
local sidekickTutorialBefore = {}

function setups.sidekick_tutorial_ready(player)
	local CarService, service = live("CarService"), live("SidekickService")
	if not sidekickTutorialBefore[player] then
		sidekickTutorialBefore[player] = {
			rolls = player:GetAttribute("Rolls"),
			racing = CarService.IsAutoRacing(player) == true,
		}
	end
	setups.sidekick_states(player)
	service.Apply(player, {})
	player:SetAttribute("Gems", 0)
	player:SetAttribute("Rolls", math.max(player:GetAttribute("Rolls") or 0, 1))
	CarService.SetAutoRace(player, false)
	local start = os.clock()
	while CarService.IsAutoRacing(player) or CarService.GetCar(player) ~= nil do
		if os.clock() - start > ON_FOOT_TIMEOUT then
			error("sidekick_tutorial_ready: still racing after " .. ON_FOOT_TIMEOUT .. " s")
		end
		RunService.Heartbeat:Wait()
	end
	player:SetAttribute("RaceEvent", "Off")
	player:SetAttribute("BossEvent", nil)
	player:SetAttribute("DuelActive", nil)
	player:SetAttribute("ShowdownActive", nil)
end

function setups.sidekick_tutorial_step(player, step, arg)
	if step == "rebirth" then
		player:SetAttribute("RebirthLevel", tonumber(arg))
	elseif step == "block" then
		-- A duel and a showdown run on a track too: only their own attribute may hold the tutorial back.
		player:SetAttribute("RaceEvent", arg == "off" and "Off" or "Racing")
		player:SetAttribute("BossEvent", arg == "boss" and true or nil)
		player:SetAttribute("DuelActive", arg == "duel" and true or nil)
		player:SetAttribute("ShowdownActive", arg == "showdown" and true or nil)
	else
		error("unknown step " .. step)
	end
end

function setups.sidekick_tutorial_restore(player)
	local saved = sidekickTutorialBefore[player]
	if saved then
		sidekickTutorialBefore[player] = nil
		player:SetAttribute("RaceEvent", "Off")
		player:SetAttribute("BossEvent", nil)
		player:SetAttribute("DuelActive", nil)
		player:SetAttribute("ShowdownActive", nil)
		restoreSidekicks(player)
		player:SetAttribute("Rolls", saved.rolls)
		if saved.racing then
			live("CarService").SetAutoRace(player, true)
		end
	end
end

-- UI specs describe a player with no gamepasses, and Studio's creator owns them all: a UI run takes every Pass_<id> off, so
-- the server's effects follow, and restore:no_passes puts them back. Ownership is never saved (PassService).
local passesBefore = {} -- [Player] = { Pass_<id> = value }

function setups.no_passes(player)
	-- shortcut: no pass for every player while on, make it per player if multi-client UI runs appear.
	live("PassService").SetOwnerCheck(function()
		return false
	end)
	local before = passesBefore[player] or {}
	passesBefore[player] = before
	for name, value in player:GetAttributes() do
		if string.sub(name, 1, 5) == "Pass_" then
			before[name] = value
			player:SetAttribute(name, nil)
		end
	end
	player:SetAttribute("UiTestNoPasses", true) -- last: once the client sees it, the passes are gone there too
end

local function restoreNoPasses(player)
	live("PassService").SetOwnerCheck(nil)
	for name, value in passesBefore[player] or {} do
		player:SetAttribute(name, value)
	end
	passesBefore[player] = nil
	player:SetAttribute("UiTestNoPasses", nil)
end

local CLIENT_SETUPS = {
	no_passes = true,
	sidekick_tutorial_ready = true,
	auto_racing = true,
	auto_roll_on = true,
	lose_event = true,
	cash_out_notice = true, -- ui_hud: fake CashOut RunEvent, no state to restore
	emphasized_next = true,
	showdown_start = true,
	showdown_win = true,
	run_visual = true,
	impact_sounds_report = true,
	sidekick_states = true,
	duel_countdown = true, -- ui_boss: the Invite stays through a real Duel message
	relic_states = true,
	bag_full_hit = true, -- ui_bag_full
	bag_full_sold = true,
	bag_spares_clear = true,
	team_states = true, -- ui_team
	team_states_clear = true,
}
local clientBefore = {} -- [Player] = { auto_racing = was racing, auto_roll_on = AutoRoll before }
local setupRequest = ReplicatedStorage:FindFirstChild("UiTestSetupRequest")
if not setupRequest then
	setupRequest = Instance.new("RemoteFunction")
	setupRequest.Name = "UiTestSetupRequest"
	setupRequest.Parent = ReplicatedStorage
end
setupRequest.OnServerInvoke = function(player, request)
	if type(request) ~= "string" then
		return false, "bad request"
	end
	local restoreId = string.match(request, "^restore:(.+)$")
	local ok, err = pcall(function()
		local rigName, rigId, rigAura, rigTrail, rigSpeed =
			string.match(request, "^run_visual_rig:([^:]+):([^:]+):([^:]+):([^:]+):([%d%.]+)$")
		local swapId, swapAura, swapTrail = string.match(request, "^run_visual_swap:([^:]+):([^:]+):([^:]+)$")
		if rigName then
			RUN_VISUAL.start(rigName, rigId, rigAura, rigTrail, tonumber(rigSpeed))
			return
		elseif swapId then
			RUN_VISUAL.swap(swapId, swapAura, swapTrail)
			return
		elseif request == "run_visual_clear" then
			RUN_VISUAL.clear()
			return
		end
		-- A faked boss state stands in for a real event, so it gets the late data a real one publishes (design doc 7 "Join size").
		local lateData = Shared:FindFirstChild("LateData")
		if lateData and (string.match(request, "^boss_ui_") or string.match(request, "^sidekick_follow_")) then
			require(lateData).Deliver("BossRagaPoses", "BossMagePoses", "BossKingPoses", "SidekickAttacks")
		end
		local tutorialStep, tutorialArg = string.match(request, "^sidekick_tutorial:(%a+):(%w+)$")
		if tutorialStep then
			setups.sidekick_tutorial_step(player, tutorialStep, tutorialArg)
			return
		end
		local followStep, followArg = string.match(request, "^sidekick_follow_(%a+):?(.*)$")
		if followStep then
			assert(sidekickFollowSteps[followStep], "unknown step " .. followStep)(player, followArg)
			return
		end
		local bossGear = string.match(request, "^boss_ui_gear:(%w+)$")
		if bossGear then
			bossUiGear(player, tonumber(bossGear) or bossGear)
			return
		end
		local bossId = string.match(request, "^boss_ui_boss:([%w_]+)$")
		if bossId then -- "none" clears it: the clients read nil as boss_raga
			ReplicatedStorage:SetAttribute("BossEventBoss", bossId ~= "none" and bossId or nil)
			return
		end
		local minionHp, minionMax = string.match(request, "^boss_ui_minion:(%d+),(%d+)$")
		if minionHp then -- the Stone Golem stands from now; boss_ui_minion:none clears it
			ReplicatedStorage:SetAttribute("BossMinionHp", tonumber(minionHp))
			ReplicatedStorage:SetAttribute("BossMinionMaxHp", tonumber(minionMax))
			ReplicatedStorage:SetAttribute("BossMinionStart", workspace:GetServerTimeNow())
			return
		end
		if request == "boss_ui_minion:none" then
			for _, name in { "BossMinionHp", "BossMinionMaxHp", "BossMinionStart" } do
				ReplicatedStorage:SetAttribute(name, nil)
			end
			return
		end
		local nextBoss = string.match(request, "^boss_ui_next:([%w_]+)$")
		if nextBoss then -- "none" clears it
			ReplicatedStorage:SetAttribute("BossEventNextBoss", nextBoss ~= "none" and nextBoss or nil)
			return
		end
		if request == "boss_ui_osu_spy" then
			installBossOsuSpy()
			return
		end
		local bossCredit = string.match(request, "^boss_ui_credit:(%d+)$")
		if bossCredit then
			player:SetAttribute("BossCredit", tonumber(bossCredit))
			return
		end
		local bossTutorial = string.match(request, "^boss_ui_tutorial:(%a+)$")
		if bossTutorial then
			bossUiTutorial(player, bossTutorial == "on")
			return
		end
		local bossWait = string.match(request, "^boss_ui_wait:([%w%.]+)$")
		if bossWait then -- seconds left in this player's wait, or "none"
			local seconds = tonumber(bossWait)
			player:SetAttribute("BossWaitEndsAt", seconds and workspace:GetServerTimeNow() + seconds or nil)
			return
		end
		local phase2Step, phase2Arg = string.match(request, "^boss_phase2_(%a+):(.*)$")
		if phase2Step then
			assert(setups["boss_phase2_" .. phase2Step], "unknown step " .. phase2Step)(player, phase2Arg)
			return
		end
		local pityMythic, pityLegendary = string.match(request, "^sidekick_ui_pity:(%d+):(%d+)$")
		if pityMythic then -- through the service, so the published attributes and the saved counts agree
			local service = live("SidekickService")
			local saved = service.Snapshot(player)
			saved.SidekickPity, saved.SidekickLegendaryPity = tonumber(pityMythic), tonumber(pityLegendary)
			service.Apply(player, saved)
			return
		end
		if request == "sidekick_ui_clock:next" then
			sidekickUiClock(nextSecretOffset())
			return
		elseif request == "sidekick_ui_clock:real" then
			sidekickUiClock(0)
			return
		end
		local phase, elapsed, hp, max, inEvent, damage =
			string.match(request, "^boss_ui_state:(%a+):([^:]+):([^:]+):([^:]+):(%a+):([^:]+)$")
		if phase then
			bossUiState(player, phase, elapsed, tonumber(hp), tonumber(max), inEvent == "true", tonumber(damage))
			return
		end
		local before = clientBefore[player] or {}
		clientBefore[player] = before
		if restoreId == "no_passes" then
			restoreNoPasses(player)
		elseif restoreId == "run_visual" then
			RUN_VISUAL.clear()
			local routes = ReplicatedStorage:FindFirstChild("RunRoutes")
			local route = routes and routes:FindFirstChild(RUN_VISUAL.ROUTE)
			if route then
				route:Destroy()
			end
		elseif restoreId == "auto_racing" then
			longStamina[player] = nil
			if before.auto_racing == false then
				live("CarService").SetAutoRace(player, false)
			end
			before.auto_racing = nil
			restoreBagRoom(player)
		elseif restoreId == "auto_roll_on" then
			if before.auto_roll_on ~= nil then
				setAutoRoll(player, before.auto_roll_on)
			end
			before.auto_roll_on = nil
			restoreBagRoom(player)
		elseif restoreId == "sidekick_states" then
			restoreSidekicks(player)
		elseif restoreId == "sidekick_tutorial" or restoreId == "sidekick_tutorial_ready" then
			setups.sidekick_tutorial_restore(player)
		elseif restoreId == "sidekick_follow" then
			restoreSidekickFollow(player)
		elseif restoreId == "boss_ui" then
			restoreBossUi(player)
		elseif restoreId == "relic_states" then
			restoreRelics(player)
		elseif restoreId == "team_states" then
			setups.team_states_clear(player)
		elseif restoreId == "bag_full_sold" then
			setups.bag_spares_clear(player)
		elseif restoreId then
			return -- lose_event and emphasized_next put themselves back
		elseif CLIENT_SETUPS[request] then
			if request == "auto_racing" and before.auto_racing == nil then
				before.auto_racing = live("CarService").IsAutoRacing(player) == true
			elseif request == "auto_roll_on" and before.auto_roll_on == nil then
				before.auto_roll_on = player:GetAttribute("AutoRoll") == true
			end
			setups[request](player)
		else
			error("not a client setup id: " .. request)
		end
	end)
	return ok, ok and nil or tostring(err)
end

-- Boss Phase 2 fixtures (Client/UiTest/UiBossPhase2, UiRelics; UiSpec.ServerSetup boss_phase2_*, boss_rewards_open,
-- relic_chest_states). Published attributes and one real-hook message only. Below the handler on purpose: it reads `setups` when called.
function setups.boss_phase2_stage(_, arg)
	local stage, endsIn, screamIn, scheduleAgo = table.unpack(string.split(arg, ":"))
	local now = workspace:GetServerTimeNow()
	ReplicatedStorage:SetAttribute("BossEventStage", tonumber(stage))
	ReplicatedStorage:SetAttribute("BossEventEndsAt", tonumber(endsIn) and now + tonumber(endsIn) or nil)
	ReplicatedStorage:SetAttribute("BossScreamEndsAt", tonumber(screamIn) and now + tonumber(screamIn) or nil)
	ReplicatedStorage:SetAttribute("BossScheduleStart", tonumber(scheduleAgo) and now - tonumber(scheduleAgo) or nil)
end

function setups.boss_phase2_rewards(player, arg)
	local outcome, damage, stage1, stage2, short, share, boss = table.unpack(string.split(arg, ":"))
	live("BossEventService").Hooks.RewardPopup(player, {
		Outcome = outcome,
		Damage = tonumber(damage),
		Share = tonumber(share), -- nil when the 6th part is missing: the popup hides its share bar
		Stage1 = stage1 == "true",
		Stage2 = stage2 == "true",
		Short = short == "true",
		Boss = boss ~= "" and boss or nil, -- 7th part: the boss id (ui_boss_mage_rewards); none = no Boss field
	})
end

function setups.boss_rewards_open(player)
	setups.boss_phase2_rewards(player, "Defeated:1234567:true:true:false:0.12")
end

function setups.relic_chest_states(player)
	setups.relic_states_bare(player)
	local service = live("RelicService")
	for _, id in { "relic_chest_raga", "relic_chest_raga", "relic_chest_adapted" } do
		assert(service.GrantChest(player, id), "could not grant " .. id)
	end
end

-- Real boss run, nothing faked past the gear; restore:boss_ui gives the characters and Sidekicks back.
function setups.boss_live(player)
	bossUiGear(player, 3)
	local service = live("BossEventService")
	if service.State().Phase == "Idle" then
		assert(service.Start("Admin"))
	end
	if not service.IsIn(player) then
		assert(service.Join(player))
	end
end

-- arg "stage1": hits until Stage 2. "stage2": hits until the event ends. Real RecordHit calls, so real pay.
function setups.boss_live_hits(player, arg)
	assert(arg == "stage1" or arg == "stage2", "boss_live_hits: stage1 or stage2")
	local service = live("BossEventService")
	local function reached()
		local state = service.State()
		if arg == "stage1" then
			return state.Stage == 2
		end
		return state.Phase == "Idle"
	end
	local calls = 0
	-- IsIn: out of the event no hit can land, so stop rather than wait out the cap.
	while calls < 200000 and not reached() and service.IsIn(player) do
		calls += 1
		if service.RecordHit(player) == 0 or calls % 200 == 0 then
			task.wait()
		end
	end
	assert(reached(), "boss_live_hits " .. arg .. " not reached after " .. calls .. " calls")
end
