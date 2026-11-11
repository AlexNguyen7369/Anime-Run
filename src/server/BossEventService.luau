--!nonstrict
-- Boss events (design doc 4.37, docs/BOSS_EVENT_SPEC.md): one event per server, every 30 minutes on a fixed grid (the
-- WeatherService shape), or at once for a paid start. The server decides every hit; no remote reaches the damage. Contract:
-- Server/CarTest/BossEventTests.
-- Clients read ReplicatedStorage attributes BossEventPhase ("Prep" or "Fight", nil when idle), BossEventStart (server time),
-- BossEventHp, BossEventMaxHp, BossEventStage, BossEventEndsAt, BossScreamEndsAt (nil outside the scream) and BossScheduleStart
-- (Poses.Schedule's start), BossEventBoss (BossCatalog id, nil when idle), and the player attributes BossEvent (true while in
-- the event), BossTeamDamage (TeamDamage, nil outside the event), BossWaitEndsAt (server time the exhausted team revives, nil
-- otherwise) and BossStatus (JSON list of { Id, EndsAt in server time, Count }, Vulnerable with no EndsAt, nil when empty; each
-- player's own, since a dodge spares that player alone). They call the RemoteFunctions Remotes.BossEventTeleport(),
-- Remotes.BossEventSetTeam(ids), Remotes.BossEventLeave(), Remotes.BossDodge(index, stamp) and
-- Remotes.BossOsu(index, circle, stamp); each returns ok, reason.
-- Remotes.BossEventChat carries the server-wide spawn message and each member's move lines to Client/BossEventChat.
-- Remotes.BossHits carries each hit, batched, to the players in the event: { UserId, SidekickId, Damage, Slot, CharacterId }, for Client/SidekickAttackView.
-- Remotes.RunEvent carries Kind "BossRewards" (the summary below) to a player back at spawn.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.BossArenaConfig)
local BossCatalog = require(Shared.BossCatalog)
local BossDodge = require(Shared.BossDodge)
local BossOsu = require(Shared.BossOsu)
local CharacterCatalog = require(Shared.CharacterCatalog)
local Cfg = require(Shared.BossEventConfig)
local StaminaConfig = require(Shared.StaminaConfig)
local CarService = require(script.Parent.CarService)
local DuelService = require(script.Parent.DuelService)
local GachaService = require(script.Parent.GachaService)
local MoneyService = require(script.Parent.MoneyService)
local PlayerData = require(script.Parent.PlayerData)
local RaceService = require(script.Parent.RaceService)
local RelicService = require(script.Parent.RelicService)
local SidekickService = require(script.Parent.SidekickService)

local BossEventService = {}

local REMOTE_COOLDOWN = 0.25
local TICK_SECONDS = 0.25 -- a player's status icon appears this soon after the move that hit them
local HIT_BATCH_SECONDS = 0.25 -- at most 4 batches of hits a second to a player (docs/BOSS_EVENT_SPEC.md)
local DAMAGE_EPSILON = 1e-6 -- exactly the minimum share still earns the reward, whatever the float sum
local TIME_EPSILON = 1e-6 -- s: a clock a float's hair before a schedule moment is on it
local DODGE_STAMP_SLACK = 0.03 -- s: a press stamped on the spot's edge, on a client clock a hair off the server's
local DODGE_MAX_AGE = 0.5 -- s: a stamp older than this on arrival is refused

local clock = nil
-- { Boss (BossCatalog row), StartAt, Source, Phase, Stage, EndsAt, ScreamEndsAt, ScheduleStart, Hp, MaxHp, Phase1MaxHp, Spawned,
-- IntroDone, Members = { [player] = member } }
local event = nil
local nextAt = math.huge
local lastEnd = nil
local chatRemote = nil
local hitsRemote = nil
local started = false
local lastRequest = setmetatable({}, { __mode = "k" })
local rewardRng = Random.new()

local function now()
	return clock and clock() or workspace:GetServerTimeNow()
end

local function safely(fn, ...)
	local ok, result = pcall(fn, ...)
	if not ok then
		warn("BossEventService: " .. tostring(result))
	end
	return ok, result
end

local function publish()
	ReplicatedStorage:SetAttribute("BossEventPhase", event and event.Phase or nil)
	ReplicatedStorage:SetAttribute("BossEventStart", event and event.StartAt or nil)
	ReplicatedStorage:SetAttribute("BossEventHp", event and event.Hp or nil)
	ReplicatedStorage:SetAttribute("BossEventMaxHp", event and event.MaxHp or nil)
	ReplicatedStorage:SetAttribute("BossEventStage", event and event.Stage or nil)
	ReplicatedStorage:SetAttribute("BossEventEndsAt", event and event.EndsAt or nil)
	ReplicatedStorage:SetAttribute("BossScreamEndsAt", event and event.ScreamEndsAt or nil)
	ReplicatedStorage:SetAttribute("BossScheduleStart", event and event.ScheduleStart or nil)
	ReplicatedStorage:SetAttribute("BossEventNextAt", nextAt < math.huge and nextAt or nil)
	ReplicatedStorage:SetAttribute("BossEventBoss", event and event.Boss.Id or nil)
end

-- The running boss's arena, the sky arena when idle.
local function arenaNow()
	return Arena.For(event and event.Boss.Id)
end

-- The index of the last moment at or before t. Here and below t counts from the schedule's start: the spawn in stage 1, the
-- stage's own spawn (BossScheduleStart) in stage 2. boss: an id, nil for Big Raga.
local function indexAt(t, boss)
	return BossDodge.IndexAtOrBefore(t + TIME_EPSILON - Cfg.IntroSeconds, boss)
end

-- How many attack Impacts fall in fromT < t <= toT, in seconds since the spawn. Pure.
function BossEventService.AttackImpactsBetween(fromT, toT)
	local count = 0
	for index = indexAt(fromT) + 1, indexAt(toT) do
		count += select(2, BossDodge.Moment(index)) == "Impact" and 1 or 0
	end
	return count
end

-- How many stacks of a status run at t, and when the latest ends, read off the schedule: each moment not spared is a stack with
-- its own timer. `spared` is a member's moment index -> true, nil for a player every move hits.
local function stacksAt(status, t, spared, stage, boss)
	local seconds = Cfg.Stage(stage).StatusSeconds
	local count, latest = 0, nil
	for index = indexAt(t, boss), 1, -1 do
		local at, name = BossDodge.Moment(index, boss)
		local ends = Cfg.IntroSeconds + at + seconds
		if t + TIME_EPSILON >= ends then
			break
		elseif name == status.Event and not (spared and spared[index]) then
			count += 1
			latest = latest or ends
		end
	end
	return count, latest
end

local function statusJson(t, member)
	local rows = {}
	for _, status in event.Boss.Statuses do
		local count, ends = stacksAt(status, t, member.Spared, event.Stage, event.Boss.Id)
		if count > 0 then
			table.insert(rows, { Id = status.Id, EndsAt = event.ScheduleStart + ends, Count = count })
		end
	end
	if member.Vulnerable then
		table.insert(rows, { Id = "Vulnerable", Count = 1 })
	end
	return #rows > 0 and HttpService:JSONEncode(rows) or nil
end

BossEventService.Hooks = {
	-- What the running stacks leave of a hit, `spared` the member's dodged moments, boss nil for Big Raga. Pure.
	DamageMulti = function(t, spared, stage, boss)
		local multi = 1
		for _, status in BossCatalog.Get(boss).Statuses do
			multi *= (1 - status.Cut) ^ stacksAt(status, t, spared, stage, boss)
		end
		return multi
	end,
	-- The boss of an event started without one. Tests start theirs by name, so the default keeps them on Big Raga.
	PickBoss = function()
		if ReplicatedStorage:GetAttribute("CarTestRunning") == true then
			return BossCatalog.Default
		end
		return BossCatalog.Order[rewardRng:NextInteger(1, #BossCatalog.Order)]
	end,
	Arrive = function(player, lane)
		local cf = RaceService.RouteStartCFrame(arenaNow().LaneRoute(lane))
		assert(CarService.HoldAt(player, cf), "no living avatar")
		CarService.GetCharacter(player):FindFirstChildOfClass("Humanoid").Died:Once(function()
			BossEventService.Leave(player, "Death")
		end)
	end,
	StartRun = function(player, team, lane)
		local route = { Path = arenaNow().LaneRoute(lane), Pads = {}, Tracks = {} }
		return CarService.RunHeld(player, route, {
			Boss = true,
			Team = team,
			OnRunEvent = function(fired)
				if fired.Kind == "BossWait" then
					local member = event and event.Members[player]
					if event and event.ScreamEndsAt and member and member.Run then
						member.Run:ReviveAt(math.max(0, event.ScreamEndsAt - now())) -- the cutscene skips exhaustion
					else
						player:SetAttribute("BossWaitEndsAt", workspace:GetServerTimeNow() + Cfg.RefillWaitSeconds)
					end
				elseif fired.Kind == "BossRefill" then
					player:SetAttribute("BossWaitEndsAt", nil)
				end
			end,
		})
	end,
	Depart = function(player)
		CarService.SetAutoRace(player, false) -- back on foot at the walk spawn
	end,
	SwitchLane = function(run, lane)
		run:SwitchRoute(arenaNow().LaneRoute(lane))
	end,
	Chat = function(text)
		if chatRemote then
			chatRemote:FireAllClients(text)
		end
	end,
	MoveChat = function(player, text)
		if chatRemote and player:IsA("Player") then
			chatRemote:FireClient(player, text)
		end
	end,
	BossHits = function(player, entries)
		if hitsRemote and player:IsA("Player") then
			hitsRemote:FireClient(player, entries)
		end
	end,
	-- A defeated stage's chest and its Money or Gems. Returns whether all of it was paid.
	PayStage = function(player, stage)
		if not RelicService.GrantChest(player, stage == 1 and "relic_chest_raga" or "relic_chest_adapted") then
			return false
		elseif stage == 1 then
			return MoneyService.Award(player, Cfg.Phase1Money) ~= nil
		end
		return MoneyService.AddGems(player, Cfg.Phase2Gems) ~= nil
	end,
	RewardPopup = function(player, summary)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local toast = remotes and remotes:FindFirstChild("RunEvent")
		if toast and player:IsA("Player") then
			local message = table.clone(summary)
			message.Kind = "BossRewards"
			toast:FireClient(player, message)
		end
	end,
}

function BossEventService.SetClock(fn)
	clock = fn
end

function BossEventService.PhaseAt(elapsed)
	if elapsed == nil or elapsed < 0 then
		return "Idle"
	elseif elapsed < Cfg.PrepSeconds then
		return "Prep"
	elseif elapsed < Cfg.TotalSeconds then
		return "Fight"
	end
	return "End"
end

function BossEventService.State()
	local players = 0
	for _ in event and event.Members or {} do
		players += 1
	end
	return {
		Phase = event and event.Phase or "Idle",
		Stage = event and event.Stage or nil,
		EndsAt = event and event.EndsAt or nil,
		ScreamEndsAt = event and event.ScreamEndsAt or nil,
		Phase1MaxHp = event and event.Phase1MaxHp or nil,
		Elapsed = event and now() - event.StartAt or nil,
		Source = event and event.Source or nil,
		Hp = event and event.Hp or 0,
		MaxHp = event and event.MaxHp or 0,
		Players = players,
		NextAt = nextAt,
		LastEnd = lastEnd,
		Boss = event and event.Boss.Id or nil,
	}
end

function BossEventService.IsIn(player)
	return event ~= nil and event.Members[player] ~= nil
end

function BossEventService.LaneOf(player)
	local member = event and event.Members[player]
	return member and member.Lane or nil
end

function BossEventService.TeamOf(player)
	local member = event and event.Members[player]
	return member and member.Team or nil
end

function BossEventService.DamageOf(player)
	local member = event and event.Members[player]
	return member and member.Damage or 0
end

function BossEventService.StageDamageOf(player, stage)
	local member = event and event.Members[player]
	return member and member.StageDamage[stage] or 0
end

-- The characters with the hardest-hitting Sidekicks, ties by cruise (then id, so it is stable). Pure.
function BossEventService.AutoTeam(player)
	local rows = {}
	for _, id in SidekickService.GearedCharacters(player) do
		local damage = SidekickService.Worn(player, id).Damage
		table.insert(rows, { Id = id, Damage = damage, Cruise = GachaService.CruiseFor(player, id) })
	end
	table.sort(rows, function(a, b)
		if a.Damage ~= b.Damage then
			return a.Damage > b.Damage
		elseif a.Cruise ~= b.Cruise then
			return a.Cruise > b.Cruise
		end
		return a.Id < b.Id
	end)
	local team = {}
	for i = 1, math.min(#rows, StaminaConfig.TEAM_SIZE) do
		team[i] = rows[i].Id
	end
	return team
end

-- The minibar's event roster (design doc 4.37): the Team attribute is never touched. Display only, except EquippedCar: the first
-- on the team wears the held runner, for the preparation run. release() puts the player's own back.
local function publishTeam(player, team)
	player:SetAttribute("BossTeam", table.concat(team, ","))
	if team[1] and player:GetAttribute("EquippedCar") ~= team[1] then
		player:SetAttribute("EquippedCar", team[1])
	end
	local kind, series = GachaService.TeamBonus(player, team)
	player:SetAttribute("BossTeamBonus", kind and (kind .. ":" .. series.Id) or "")
	local staminaMulti = #team > 0 and GachaService.StaminaMulti(player, team)
	for slot = 1, StaminaConfig.TEAM_SIZE do
		local id = team[slot]
		local spec = id and CharacterCatalog.Get(id)
		player:SetAttribute("BossTeamCruise" .. slot, spec and GachaService.CruiseFor(player, id, slot, team) or nil)
		player:SetAttribute(
			"BossTeamStamina" .. slot,
			spec
					and math.round(
						StaminaConfig.Seconds(
							spec,
							staminaMulti
								* SidekickService.StaminaMulti(player, id)
								* RelicService.Multi(player, id, "Stamina")
						) * 10
					) / 10
				or nil
		)
	end
end

-- True for a non-empty list of owned characters, each once, each wearing a Sidekick. `ids` comes from a client.
local function validTeam(player, ids)
	if type(ids) ~= "table" or #ids < 1 or #ids > StaminaConfig.TEAM_SIZE then
		return false
	end
	local count, seen = 0, {}
	for _, id in ids do
		count += 1
		if type(id) ~= "string" or seen[id] or not CharacterCatalog.Get(id) then
			return false
		end
		if not (GachaService.Owns(player, id) and SidekickService.Worn(player, id)) then
			return false
		end
		seen[id] = true
	end
	return count == #ids -- no keys beside the list
end

-- The saved team's ids that can still fight (design doc 4.37), in order.
local function savedTeam(player)
	local team, seen = {}, {}
	for _, id in string.split(player:GetAttribute("LastBossTeam") or "", ",") do
		if
			not seen[id]
			and #team < StaminaConfig.TEAM_SIZE
			and GachaService.Owns(player, id)
			and SidekickService.Worn(player, id)
		then
			table.insert(team, id)
			seen[id] = true
		end
	end
	return team
end

-- The player closed the team HUD: their team starts its display-only run (design doc 4.37).
function BossEventService.StartPrepRun(player)
	if not (event and event.Members[player]) then
		return false, "Not in the event"
	end
	player:SetAttribute("BossPrepRun", true)
	return true
end

function BossEventService.SetTeam(player, ids)
	local member = event and event.Members[player]
	if not member then
		return false, "Not in the event"
	end
	if now() - event.StartAt >= Cfg.PrepSeconds then
		return false, "Preparation is over"
	end
	if not validTeam(player, ids) then
		return false, "Invalid team"
	end
	member.Team = table.clone(ids)
	player:SetAttribute("LastBossTeam", table.concat(ids, ","))
	publishTeam(player, member.Team)
	player:SetAttribute("BossTeamDamage", BossEventService.TeamDamage(player))
	return true
end

-- Slots still running: run.Line, or the whole team before a run exists (RelicTests' StartRun stub has no Line either).
local function lineOf(member, team)
	if member.Run and member.Run.Line then
		return member.Run.Line
	end
	local all = {}
	for slot in team do
		table.insert(all, slot)
	end
	return all
end

-- One hit from `slot` of `team` before statuses, and the Sidekick dealing it: 0 and nil for a character without one.
local function slotHit(player, team, slot)
	local id = team[slot]
	local spec = id and SidekickService.Worn(player, id)
	if not spec then
		return 0, nil
	end
	local cruise = GachaService.CruiseFor(player, id, slot, team)
	return spec.Damage * RelicService.Multi(player, id, "Damage") * Cfg.SpeedScale(cruise), spec
end

-- The live number: one hit from each character in the line, before statuses.
function BossEventService.TeamDamage(player)
	local member = event and event.Members[player]
	if not member then
		return 0
	end
	local team = member.Team or BossEventService.AutoTeam(player)
	local total = 0
	for _, slot in lineOf(member, team) do
		total += (slotHit(player, team, slot))
	end
	return total
end

local function userIdOf(player)
	return player:IsA("Player") and player.UserId or player:GetAttribute("UserId")
end

-- Sends what each member has waiting, at most every HIT_BATCH_SECONDS unless `final`: the last hits of an event are not held back.
local function sendHits(members, at, final)
	for player, member in members do
		if #member.Hits > 0 and (final or at - member.HitsSentAt >= HIT_BATCH_SECONDS) then
			local hits = member.Hits
			member.Hits, member.HitsSentAt = {}, at
			safely(BossEventService.Hooks.BossHits, player, hits)
		end
	end
end

-- Seconds between a character's hits: each acts on its own Relic's attack speed (design doc 4.37).
local function hitSpacing(player, id)
	return Cfg.HitEverySeconds / RelicService.Multi(player, id, "AttackSpeed")
end

-- Every slot's next hit, counted from `from` and spread over one beat so a team never fires on one frame.
local function armHits(player, member, from)
	for slot, id in member.Team do
		member.NextHits[slot] = from + hitSpacing(player, id) + (slot - 1) * Cfg.HitEverySeconds / #member.Team
	end
end

-- Pays a defeated stage to each member over the share of `maxHp`, from that stage's damage alone. Each stage comes here once, so
-- a chest and its money are never granted twice.
local function payStage(current, stage, maxHp)
	local need = Cfg.MinDamageShare * maxHp - DAMAGE_EPSILON
	for player, member in current.Members do
		local damage = member.StageDamage[stage]
		if damage >= need and damage > 0 then
			local ok, paid = safely(BossEventService.Hooks.PayStage, player, stage)
			member.Paid[stage] = ok and paid == true
		else
			member.Short = true
		end
	end
end

-- Share (owner 2026-11-10): of the phase this popup reports, that phase's damage over that phase's max HP, 0..1.
local function rewardPopup(player, member, outcome, stage, maxHp, boss)
	safely(BossEventService.Hooks.RewardPopup, player, {
		Outcome = outcome,
		Boss = boss,
		Damage = member.Damage,
		Share = maxHp > 0 and math.clamp(member.StageDamage[stage] / maxHp, 0, 1) or 0,
		Stage1 = member.Paid[1],
		Stage2 = member.Paid[2],
		Short = member.Short,
	})
end

-- The first HP 0: full HP again, the scream, and a schedule from its beginning. State moves before the pay, so nothing a hook does
-- can reach stage 1's defeat twice.
local function startStage2(current)
	current.Stage = 2
	current.Phase1MaxHp = current.MaxHp
	current.MaxHp += Cfg.Phase2ExtraHp
	current.Hp = current.MaxHp
	current.ScreamEndsAt = now() + Cfg.ScreamSeconds
	current.ScheduleStart = current.ScreamEndsAt - Cfg.IntroSeconds
	current.EndsAt += Cfg.ScreamSeconds + Cfg.Phase2ExtraSeconds
	for player, member in current.Members do
		member.Spared, member.Pressed, member.ChargedTo, member.Vulnerable = {}, {}, 0, false
		armHits(player, member, current.ScreamEndsAt) -- no hit is owed for the scream
		player:SetAttribute("BossStatus", nil)
		if member.Run and member.Run.Waiting then
			member.Run:ReviveAt(Cfg.ScreamSeconds) -- the cutscene skips exhaustion
			player:SetAttribute("BossWaitEndsAt", nil)
		end
	end
	publish()
	payStage(current, 1, current.Phase1MaxHp)
end

-- One hit from a slot, the front by default, of the server's own number: this reads nothing from a client.
function BossEventService.RecordHit(player, slot)
	local member = event and event.Members[player]
	if not (member and member.Run) or member.Run.Waiting then
		return 0
	end
	if event.ScreamEndsAt and now() < event.ScreamEndsAt then
		return 0
	end
	slot = slot or member.Run.Slot
	if not table.find(lineOf(member, member.Team), slot) then
		return 0
	end
	local hit, spec = slotHit(player, member.Team, slot)
	if not spec then
		return 0 -- design doc 4.36: the Sidekick deals the damage
	end
	local multi =
		BossEventService.Hooks.DamageMulti(now() - event.ScheduleStart, member.Spared, event.Stage, event.Boss.Id)
	local dealt = math.min(hit * multi, event.Hp)
	member.Damage += dealt
	member.StageDamage[event.Stage] += dealt
	event.Hp -= dealt
	local entry = {
		UserId = userIdOf(player),
		SidekickId = spec.Id,
		Damage = dealt,
		Slot = slot,
		CharacterId = member.Team[slot],
	}
	for _, other in event.Members do
		table.insert(other.Hits, entry)
	end
	if event.Hp <= 0 and event.Stage < event.Boss.Stages then
		startStage2(event)
	elseif event.Hp <= 0 then
		BossEventService.End("Defeated")
	else
		publish()
	end
	return dealt
end

-- Each move since this member's last charge that hit: the move's cost on every character in the line, Vulnerable and the move's
-- chat line. At 0 the run's own next frame takes the slot out of the line, exactly as for a drain to 0. A move during the wait is passed
-- over, never owed; a dodged one is already spared.
local function chargeMoves(player, member, t)
	local boss = event.Boss
	local from = indexAt(member.ChargedTo, boss.Id)
	member.ChargedTo = math.max(member.ChargedTo, t)
	local run = member.Run
	for index = from + 1, indexAt(t, boss.Id) do
		if run and run.Waiting then
			member.Spared[index] = true
		end
		if not member.Spared[index] then
			local _, name = BossDodge.Moment(index, boss.Id)
			local row = boss.Moves[name]
			local base = row.Cost or (row.StageCost and Cfg.Stage(event.Stage).AttackStaminaCost) or 0
			if base > 0 and run then
				local cost = base * (member.Vulnerable and Cfg.VulnerableMulti or 1)
				for _, slot in lineOf(member, member.Team) do
					if run.Team[slot] ~= CharacterCatalog.KAMI_ID then -- Kami never tires (owner 2026-11-09)
						run.Stamina[slot] = math.max(0, run.Stamina[slot] - cost)
					end
				end
			end
			member.Vulnerable = true
			safely(BossEventService.Hooks.MoveChat, player, row.Chat or Cfg.MoveChat(name, event.Stage))
		end
	end
end

local function startRun(player, member)
	local introEnd = event.StartAt + Cfg.PrepSeconds + Cfg.IntroSeconds
	armHits(player, member, math.max(introEnd, member.JoinedAt))
	local ok, run = safely(BossEventService.Hooks.StartRun, player, member.Team, member.Lane)
	member.Run = ok and run or nil
end

-- Takes a member, already out of the Members table, out of the game's event state. The run stops first; EquippedCar goes
-- back last so a failed return cannot keep the event's character.
local function release(player, member, depart)
	player:SetAttribute("BossEvent", nil)
	publishTeam(player, {})
	player:SetAttribute("BossTeam", nil)
	player:SetAttribute("BossTeamBonus", nil)
	player:SetAttribute("BossLane", nil)
	player:SetAttribute("BossPrepRun", nil)
	player:SetAttribute("BossTeamDamage", nil)
	player:SetAttribute("BossWaitEndsAt", nil)
	player:SetAttribute("BossStatus", nil)
	if member.Run then
		safely(member.Run.Destroy, member.Run)
	end
	if depart then
		safely(BossEventService.Hooks.Depart, player)
	end
	if player:GetAttribute("EquippedCar") ~= member.Equipped then
		player:SetAttribute("EquippedCar", member.Equipped)
	end
end

function BossEventService.Join(player)
	if not event then
		return false, "No event"
	end
	local joinedAt = now()
	local elapsed = joinedAt - event.StartAt
	if elapsed >= Cfg.JoinSeconds or event.Stage == 2 then
		return false, "Teleporting has closed"
	end
	if event.Members[player] then
		return false, "Already in the event"
	end
	local auto = BossEventService.AutoTeam(player)
	if #auto == 0 then
		return false, "Needs a Sidekick"
	end
	local lane = nil
	local taken = {}
	for _, other in event.Members do
		taken[other.Lane] = true
	end
	for candidate = 1, arenaNow().Lanes do
		if not taken[candidate] then
			lane = candidate
			break
		end
	end
	if not lane then
		return false, "The arena is full"
	end
	local duelState = DuelService.StateOf(player)
	if duelState == "Countdown" or duelState == "Racing" then
		DuelService.PlayerLeft(player) -- a forfeit, only once nothing above can refuse the join
	end
	local current = event
	local saved = savedTeam(player)
	local member = {
		Lane = lane,
		-- The saved team if it can fight; after preparation, with none, the team is chosen for the joiner.
		Team = #saved > 0 and saved or (elapsed >= Cfg.PrepSeconds and auto or nil),
		Damage = 0,
		StageDamage = { 0, 0 },
		Paid = { false, false }, -- actually paid, by stage
		Short = false, -- missed a defeated stage's pay for being under the share
		Vulnerable = false,
		Hits = {}, -- waiting for the next batch
		NextHits = {}, -- slot -> when it next fires
		HitsSentAt = -math.huge,
		JoinedAt = joinedAt,
		ChargedTo = elapsed - Cfg.PrepSeconds, -- nothing at or before the join is owed
		Spared = {}, -- moment index -> true: dodged, or passed in the wait
		Pressed = {}, -- moment index -> true: the one press a prompt allows was used
		Osu = {}, -- moment index -> { [circle] = on time }: the one stamp each rhythm circle allows
		Equipped = player:GetAttribute("EquippedCar"),
	}
	-- A move before the join never hit this player: no stack, as for the stamina through ChargedTo.
	for index = 1, indexAt(member.ChargedTo, current.Boss.Id) do
		member.Spared[index] = true
	end
	current.Members[player] = member
	player:SetAttribute("BossLane", lane)
	publishTeam(player, member.Team or auto) -- before BossEvent, so the minibar never reads a stale team
	player:SetAttribute("BossEvent", true)
	current.MaxHp += Cfg.HpPerPlayer
	current.Hp += Cfg.HpPerPlayer
	publish()
	if not safely(BossEventService.Hooks.Arrive, player, lane) then
		BossEventService.Leave(player, "Left")
		return false, "Could not teleport"
	end
	if event == current and current.IntroDone and current.Members[player] == member then
		startRun(player, member)
	end
	if BossEventService.IsIn(player) then
		player:SetAttribute("BossTeamDamage", BossEventService.TeamDamage(player))
	end
	return true
end

-- The neighbouring lane to dodge into: a free one, at random if both are; a taken one if neither is.
local function dodgeLane(player, lane)
	local free, near = {}, {}
	for _, candidate in { lane - 1, lane + 1 } do
		if candidate >= 1 and candidate <= arenaNow().Lanes then
			table.insert(near, candidate)
			local taken = false
			for other, member in event.Members do
				taken = taken or (other ~= player and member.Lane == candidate)
			end
			if not taken then
				table.insert(free, candidate)
			end
		end
	end
	local from = #free > 0 and free or near
	return from[rewardRng:NextInteger(1, #from)]
end

-- A dodged moment: it never hits, and the runner dashes into a neighbouring lane.
local function spare(player, member, index)
	member.Spared[index] = true
	member.Lane = dodgeLane(player, member.Lane)
	player:SetAttribute("BossLane", member.Lane)
	safely(BossEventService.Hooks.SwitchLane, member.Run, member.Lane)
end

-- One press of the Dodge bar. `index` and `stamp` (the press, in server time) come from a client: the window and the moment are
-- the server's. docs/BOSS_EVENT_SPEC.md "Dodge bar" covers why the stamp is trusted this far. Returns ok, reason.
function BossEventService.Dodge(player, index, stamp)
	local member = event and event.Members[player]
	if not member then
		return false, "Not in the event"
	end
	if not (member.Run and not member.Run.Waiting) then
		return false, "Not running"
	end
	if type(index) ~= "number" or index < 1 or index % 1 ~= 0 or index == math.huge then
		return false, "Invalid press"
	end
	if type(stamp) ~= "number" or stamp ~= stamp or math.abs(stamp) == math.huge then
		return false, "Invalid press"
	end
	local momentAt, name = BossDodge.Moment(index, event.Boss.Id)
	if event.Boss.Moves[name].Osu then
		return false, "No bar"
	end
	local at = now()
	local moment = event.ScheduleStart + Cfg.IntroSeconds + momentAt
	if at > moment or at < moment - BossDodge.SweepFor(event.Stage) - DODGE_STAMP_SLACK then
		return false, "No bar"
	end
	if member.Pressed[index] then
		return false, "Already pressed"
	end
	member.Pressed[index] = true
	local from, to =
		BossDodge.Window(BossDodge.Spot(userIdOf(player) or 0, event.StartAt, index, event.Stage), moment, event.Stage)
	if
		stamp < from - DODGE_STAMP_SLACK
		or stamp > to + DODGE_STAMP_SLACK
		or stamp > at + DODGE_STAMP_SLACK
		or at - stamp > DODGE_MAX_AGE
	then
		return false, "Missed"
	end
	spare(player, member, index)
	return true
end

-- One rhythm circle of a moment whose move has Osu (the golem's slam). `index`, `circle` and `stamp` come from a client; the beats
-- are the server's, the stamp is trusted as far as the Dodge bar's, and where the click landed is never checked. One stamp per
-- circle, so at most BossOsu.Count writes a moment. A circle off its beat is spent, so the move hits. Returns ok, reason: "Dodged"
-- on the last circle on time.
function BossEventService.Osu(player, index, circle, stamp)
	local member = event and event.Members[player]
	if not member then
		return false, "Not in the event"
	end
	if not (member.Run and not member.Run.Waiting) then
		return false, "Not running"
	end
	if type(index) ~= "number" or index < 1 or index % 1 ~= 0 or index == math.huge then
		return false, "Invalid press"
	end
	if type(stamp) ~= "number" or stamp ~= stamp or math.abs(stamp) == math.huge then
		return false, "Invalid press"
	end
	if type(circle) ~= "number" or circle < 1 or circle > BossOsu.Count or circle % 1 ~= 0 then
		return false, "Invalid press"
	end
	local at = now()
	local momentAt, name = BossDodge.Moment(index, event.Boss.Id)
	local moment = event.ScheduleStart + Cfg.IntroSeconds + momentAt
	if not event.Boss.Moves[name].Osu or at > moment or at < moment - BossOsu.OpenSeconds - DODGE_STAMP_SLACK then
		return false, "No circles"
	end
	local stamps = member.Osu[index] or {}
	member.Osu[index] = stamps
	if stamps[circle] ~= nil then
		return false, "Already pressed"
	end
	local lead = BossOsu.Circles(userIdOf(player) or 0, event.StartAt, index)[circle].Lead
	stamps[circle] = BossOsu.Judge(lead, moment, stamp, DODGE_STAMP_SLACK)
		and stamp <= at + DODGE_STAMP_SLACK
		and at - stamp <= DODGE_MAX_AGE
	if not stamps[circle] then
		return false, "Missed"
	end
	for k = 1, BossOsu.Count do
		if not stamps[k] then
			return true
		end
	end
	spare(player, member, index)
	return true, "Dodged"
end

-- A leave in stage 1 before 3:00 takes the player's HP back; it never defeats the boss. A death returns through the respawn. A
-- leaver keeps stage 1's pay, and that pay's popup comes now.
function BossEventService.Leave(player, reason)
	local member = event and event.Members[player]
	if not member then
		return
	end
	event.Members[player] = nil
	if event.Stage == 1 and now() - event.StartAt < Cfg.JoinSeconds then
		event.MaxHp -= Cfg.HpPerPlayer
		-- An emptied arena has MaxHp 0, so Hp is 0 too: the next joiner starts from exactly one player's HP.
		event.Hp = math.min(math.max(event.Hp - Cfg.HpPerPlayer, 1), event.MaxHp)
	end
	publish()
	release(player, member, reason ~= "Death")
	if member.Paid[1] then
		rewardPopup(player, member, "Left", 1, event.Phase1MaxHp or event.MaxHp, event.Boss.Id)
	end
end

local function begin(source, at, bossId)
	event = {
		Boss = BossCatalog.Get(bossId or BossEventService.Hooks.PickBoss()),
		StartAt = at,
		Source = source,
		Phase = "Prep",
		Stage = 1,
		EndsAt = at + Cfg.TotalSeconds,
		ScheduleStart = at + Cfg.PrepSeconds,
		Hp = 0,
		MaxHp = 0,
		Members = {},
	}
	local arena = arenaNow()
	for lane = 1, arena.Lanes do
		RaceService.PrepareRoute(arena.LaneRoute(lane)) -- a dodge never sends a client to a route it does not have yet
	end
	publish()
end

-- bossId: a BossCatalog id, nil for Hooks.PickBoss.
function BossEventService.Start(source, bossId)
	if event then
		return false, "An event is active"
	end
	if bossId ~= nil and BossCatalog.Get(bossId).Id ~= bossId then
		return false, "Unknown boss"
	end
	begin(source, now(), bossId)
	return true
end

function BossEventService.End(reason)
	local ending = event
	if not ending then
		return false
	end
	event = nil
	lastEnd = reason
	publish()
	sendHits(ending.Members, now(), true)
	for player, member in ending.Members do
		release(player, member, true)
	end
	-- The last stage's defeat pays it; a timeout there still sends the popup when an earlier stage paid.
	local last = ending.Boss.Stages
	if ending.Stage == last and (reason == "Defeated" or (reason == "Timeout" and last == 2)) then
		if reason == "Defeated" then
			payStage(ending, last, ending.MaxHp)
		end
		for player, member in ending.Members do
			local outcome = reason == "Defeated" and "Defeated" or "Survived"
			rewardPopup(player, member, outcome, last, ending.MaxHp, ending.Boss.Id)
		end
	end
	return true
end

function BossEventService.Reset(at)
	BossEventService.End("Reset")
	lastEnd = nil
	nextAt = (at or now()) + Cfg.IntervalSeconds
	publish()
end

-- One event's clock at `at`: the spawn, the end of the intro, every hit due, the ends.
local function tick(at)
	local current = event
	local elapsed = at - current.StartAt
	local phase = BossEventService.PhaseAt(elapsed)
	if phase == "Fight" and current.Phase ~= phase then
		current.Phase = phase
		publish()
	end
	if elapsed >= Cfg.PrepSeconds and not current.Spawned then
		current.Spawned = true
		for player, member in table.clone(current.Members) do
			member.Team = member.Team or BossEventService.AutoTeam(player)
			if #member.Team == 0 then -- took every Sidekick off during preparation
				BossEventService.Leave(player, "Left")
			else
				player:SetAttribute("LastBossTeam", table.concat(member.Team, ","))
				publishTeam(player, member.Team)
			end
		end
		safely(BossEventService.Hooks.Chat, current.Boss.ChatMessage)
	end
	if elapsed >= Cfg.PrepSeconds + Cfg.IntroSeconds and not current.IntroDone then
		current.IntroDone = true
		for player, member in table.clone(current.Members) do
			startRun(player, member)
		end
	end
	if current.ScreamEndsAt and at >= current.ScreamEndsAt then
		current.ScreamEndsAt = nil
		publish()
	end
	for player, member in table.clone(current.Members) do
		if event ~= current then -- a hit below defeated the boss
			return
		end
		local t = at - current.ScheduleStart -- for each member: a hit below can start stage 2 and move the schedule
		chargeMoves(player, member, t)
		player:SetAttribute("BossStatus", statusJson(t, member))
		if not player.Parent then
			BossEventService.Leave(player, "Left")
		elseif member.Run and member.Run.Waiting then
			-- The wait owes nothing afterward, nor does a scream it ran into.
			armHits(player, member, math.max(at, current.ScreamEndsAt or at))
		elseif member.Run then
			for slot, id in member.Team do
				while
					event == current
					and current.Members[player] == member
					and member.NextHits[slot] <= at + TIME_EPSILON
				do
					member.NextHits[slot] += hitSpacing(player, id) -- first: a hit that starts stage 2 rearms the timers itself
					-- A slot out of the line lets its beat pass: it keeps its place in the spread and owes nothing.
					if table.find(lineOf(member, member.Team), slot) then
						BossEventService.RecordHit(player, slot)
					end
				end
			end
		end
	end
	if event ~= current then
		return
	end
	sendHits(current.Members, at)
	for player in current.Members do
		player:SetAttribute("BossTeamDamage", BossEventService.TeamDamage(player)) -- the running character and refills change it
	end
	if (elapsed >= Cfg.JoinSeconds or current.Stage == 2) and next(current.Members) == nil then
		BossEventService.End("NoPlayers") -- nobody came, or nobody is left and nobody can come
	elseif at >= current.EndsAt then
		BossEventService.End("Timeout")
	end
end

-- The scheduler tick. An event moves first, so one ending on a mark does not skip that mark.
function BossEventService.Advance(at)
	at = at or now()
	if type(at) ~= "number" or at ~= at or math.abs(at) == math.huge then
		return
	end
	if event then
		tick(at)
	end
	if at >= nextAt then
		nextAt += Cfg.IntervalSeconds * (math.floor((at - nextAt) / Cfg.IntervalSeconds) + 1)
		if not event then
			begin("Timer", at)
		else
			publish()
		end
	end
end

-- noCooldown: the remote skips the shared cooldown (rhythm circles can come under REMOTE_COOLDOWN apart); its own checks bound it.
local function bind(remotes, name, fn, noCooldown)
	local remote = remotes:FindFirstChild(name) or Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotes
	remote.OnServerInvoke = function(player, ...)
		if player:GetAttribute("DataLoaded") ~= true then
			return false, "Data not loaded"
		end
		if not noCooldown then
			local at = os.clock()
			if lastRequest[player] and at - lastRequest[player] < REMOTE_COOLDOWN then
				return false, "Please wait"
			end
			lastRequest[player] = at
		end
		return fn(player, ...)
	end
end

function BossEventService.Init()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	chatRemote = remotes:FindFirstChild("BossEventChat") or Instance.new("RemoteEvent")
	chatRemote.Name = "BossEventChat"
	chatRemote.Parent = remotes
	hitsRemote = remotes:FindFirstChild("BossHits") or Instance.new("RemoteEvent")
	hitsRemote.Name = "BossHits"
	hitsRemote.Parent = remotes
	bind(remotes, "BossEventTeleport", function(player)
		return BossEventService.Join(player)
	end)
	bind(remotes, "BossEventSetTeam", BossEventService.SetTeam)
	bind(remotes, "BossEventPrepRun", BossEventService.StartPrepRun)
	bind(remotes, "BossDodge", BossEventService.Dodge)
	bind(remotes, "BossOsu", BossEventService.Osu, true)
	local function left(player)
		BossEventService.Leave(player, "Left")
	end
	bind(remotes, "BossEventLeave", function(player)
		left(player)
		return true
	end)
	PlayerData.OnLeaving(left) -- before the leave save: it must hold the player's own EquippedCar
	Players.PlayerRemoving:Connect(left)
	nextAt = now() + Cfg.IntervalSeconds
	publish()
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			if ReplicatedStorage:GetAttribute("CarTestRunning") ~= true then
				safely(BossEventService.Advance)
			end
		end
	end)
end

return BossEventService
