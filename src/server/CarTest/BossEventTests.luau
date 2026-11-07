--!nonstrict
-- BRIEF: design doc 4.37 and the 2026-11-05 change-log line, docs/BOSS_EVENT_SPEC.md, docs/SIDEKICK_SPEC.md (task b5): the
-- event server. Owner values are asserted literally in "config"; the spec's placeholders are read from the config everywhere
-- else, so retuning one only touches that section.
--
-- Contract these tests assume beyond the brief:
--   Shared/BossEventConfig: IntervalSeconds, PrepSeconds, JoinSeconds, TotalSeconds, IntroSeconds, HpPerPlayer, HitEverySeconds,
--     RefillWaitSeconds, MinDamageShare, ChatMessage, SpeedScale(cruise). No rounding.
--   Server/BossEventService, one event per server, clock injected like DuelService:
--     SetClock(fn) (nil = workspace:GetServerTimeNow). Every call below reads it.
--     PhaseAt(elapsed): pure. nil or negative "Idle", then "Prep", "Fight" (the intro included), "End".
--     Reset(at): tests and admin. No event, nobody in it, attributes cleared, next timer mark = at + IntervalSeconds.
--     Advance(now): the scheduler tick (WeatherService.Tick shape). Starts a due event, moves the phases, deals every hit due
--       up to `now` at a fixed cadence, ends the event. Never yields. The boot loop skips it while CarTestRunning.
--     Start(source): true, or false + reason when an event is active. Source is a label: "Timer", "Paid", "Test".
--     End(reason): "Defeated", "Timeout" or "NoPlayers". Everyone leaves, and the state goes straight back to "Idle".
--     State(): { Phase, Elapsed, Source, Hp, MaxHp, Players, NextAt, LastEnd }.
--     Join(player): true or false + reason. Sets player attribute BossEvent = true and takes a free lane.
--     Leave(player, reason): reason "Left" or "Death". Clears BossEvent (to nil), stops the event run. Safe when not in.
--     IsIn(player) (a strict boolean), LaneOf(player) (1 to 7), TeamOf(player) (ids in slot order, or nil before one is set),
--     DamageOf(player) (this event's total, 0 when not in it).
--     SetTeam(player, ids): true or false + reason. AutoTeam(player): ids, pure, sets nothing.
--     Player attribute BossTeamDamage: TeamDamage(player) for the team HUD (b7c). Set at Join, SetTeam and each Advance while
--       the player is in the event; nil outside it.
--     TeamDamage(player): the HUD's number, the sum of one hit from each character in the line before statuses; the whole team
--       before a run. RecordHit(player, slot): one hit from that team slot (default run.Slot), returns what it dealt (0 when it may
--       not hit). Nothing past `slot` is read and no remote reaches it. See "Phase 2" below for what the hit that empties HP does.
--     Characters act individually (owner 2026-11-06; design doc 4.37, BOSS_EVENT_SPEC "Run rules"):
--       A hit = Worn(team[slot]).Damage x RelicService.Multi(player, id, "Damage") x Cfg.SpeedScale(GachaService.CruiseFor(player, id,
--       slot, team)) x DamageMulti. run.TargetSpeed is not read. RecordHit returns 0 for a slot not in run.Line, in the wait, in the
--       scream, or with no Sidekick.
--       Each slot has its own timer, Cfg.HitEverySeconds / RelicService.Multi(player, id, "AttackSpeed"). Slot n's first hit comes
--       (n - 1) x Cfg.HitEverySeconds / #team after slot 1's, so a team never fires on one frame, after a wait or the scream too.
--       A slot gone from the line owes nothing on return; the wait and the scream pile nothing up.
--       A killing hit ends the round: later slots do not fire, stage 2 starts once and the event ends once.
--     Hooks, a table of replaceable functions; the defaults are the real game:
--       Arrive(player, lane): stops a normal run through the normal stop, stands the player on the lane.
--       StartRun(player, team, lane): returns the run. Called at the intro's end, or at once for a joiner after it. The service
--         reads only run.Slot, run.Waiting, run.Line and run.Stamina, writes run.Stamina of slots in run.Line, and calls
--         run:Destroy().
--       Depart(player): back to spawn. Chat(text): to the whole server, default fires RemoteEvent Remotes.BossEventChat.
--       PayStage(player, stage) -> ok: the stage's chest plus Money or Gems. RewardPopup(player, summary). See "Phase 2" below.
--       MoveChat(player, text) (owner 2026-11-05): one Big Raga move, to one event player; default fires Remotes.BossEventChat
--         to that player only. Once per attack, shout and wheel_turn move of the shared schedule, inside that move, whatever
--         the Advance step. No move chat in the intro, and never to anyone outside the event.
--     Remotes.BossEventLeave: the client's leave option, no arguments, runs Leave(player, "Left") (owner 2026-11-05).
--     Join during a duel's Countdown or Racing: succeeds and ends the duel through DuelService.PlayerLeft (owner 2026-11-05).
--     Init(): boot. Makes the remotes, starts the loop. Called by Main.server. Not `Start`, which starts an event here.
--     Hits: a member's slot 1 first hits one HitEverySeconds after the intro's end, or after joining if later.
--     Hooks.DamageMulti(t): pure, t in seconds since the spawn; the default is the real Shouted x Adapted. RecordHit deals
--       its slot's hit x DamageMulti(now - spawn). TeamDamage and attribute BossTeamDamage stay uncut. Other sections stub it to 1
--       so their damage sums stay exact.
--     Player attribute BossStatus: JSON list of { Id = "Shouted"|"Adapted", EndsAt (server time, the latest stack's), Count } and
--       { Id = "Vulnerable", Count = 1 } with no EndsAt; nil outside an event. Each player's own: a dodged move leaves it out (design
--       doc 4.37). Hooks.DamageMulti(t, spared, stage) takes the member's dodged moments and multiplies once per live stack.
--     Dodge(player, index, stamp) (Remotes.BossDodge): one press of the Dodge bar for moment `index` of Shared/BossDodge. Returns ok,
--       reason. Hooks.SwitchLane(run, lane) moves the dodger's run to a neighbouring lane.
--     An effect starts on its moment and is over at EndsAt. A hit in a long frame's catch-up is not pinned to a moment.
--     AttackImpactsBetween(fromT, toT): pure. How many Big Raga attack Impacts fall in fromT < t <= toT, t in seconds since the
--       spawn (BossRagaPoses.Schedule's now - startTime), 0 for an empty or reversed span. Advance charges each running
--       member Stage(stage).AttackStaminaCost per impact (x VulnerableMulti when Vulnerable), floored at 0, on every slot in run.Line at
--       that frame. An impact in a member's wait, or at or before its joining, is never charged.
--     Hooks.BossHits(player, entries) (b7d): one batch to one event player; the default fires RemoteEvent Remotes.BossHits to that
--       player (a Folder test player makes FireClient throw: call it through `safely`). Every event player gets every entry; each
--       player's batches are at least 0.25 s apart by the injected clock, and never empty. An entry is one hit that dealt damage:
--       { UserId, SidekickId, Damage, Slot, CharacterId }, nothing else. UserId: Player.UserId, or attribute UserId on a Folder test
--       player. Slot: the team slot that hit. CharacterId: team[Slot]. SidekickId: what it wears. Damage: what RecordHit dealt.
--       A hit waiting for the gap goes out in a later batch. The hit that defeats the boss still reaches the members.
--       A character in the line whose Sidekick came off mid-event cannot hit: RecordHit returns 0, no entry, no damage (design doc 4.36).
--   Event roster (owner 2026-11-05): player attributes BossTeam (comma ids), BossTeamCruise<n>, BossTeamStamina<n> and BossLane from
--     Join; BossTeam follows SetTeam and the lock, then all clear on leaving, with EquippedCar back. Saved LastBossTeam follows each
--     accepted pick and the lock. Join starts from its ids still owned and wearing a Sidekick. StartPrepRun(player) sets BossPrepRun,
--     members only. ReplicatedStorage attribute BossEventNextAt mirrors State().NextAt.
--   Exhaustion view (owner 2026-11-05): player attribute BossWaitEndsAt, server time, set when the team starts its wait,
--     cleared at refill and on leaving. BossEventConfig.WaitCameraCFrame(center, runnerPosition), pure (owner 2026-11-05): the
--     eye about 120 outward of and 80 above the local runner, looking down on the arena. In a 907 px high view at WaitCameraFov the
--     runner shows at least 2.5 px tall with y at most 790, above the bottom HUD, the wheel top and feet show, and the boss is at least
--     225 px tall. The whole ring need not fit.
--     No runnerPosition: a fixed spot on the boss's front (-Z).
--   CarService.PadTouched refuses a player whose attribute BossEvent is true. GachaService.StartAutoRoll does not roll while it is.
--   RaceService.NewRun option Boss = true, with Team = { ids }, on { Path = BossArenaConfig.LaneRoute(n), Pads = {}, Tracks = {} }:
--     stamina without npcMode, distance wraps the closed route. At all empty: run.Waiting = true, RunSpeed 0, runner still,
--     OnRunEvent { Kind = "BossWait" }; after RefillWaitSeconds { Kind = "BossRefill" }, fired with stamina already 100, slot 1
--     and Waiting false. Never "Exhausted", never a cash-out. The run keeps options.Team; the Team attribute does not change.
--   Line run (owner 2026-11-06, task p3; design doc 4.37, BOSS_EVENT_SPEC "Line run"). A boss run has no Swap: every slot in the
--     line drains at once at 100 / seconds[slot], and { Kind = "BossGone", Slot = n } fires, with run state already moved, when
--     a slot reaches 0. run.Line: slots still in the line, in order. run.Slot = run.Line[1], and TargetSpeed, RunSlot and
--     EquippedCar follow it. Player attribute BossLine: comma list ("1,3"), "" in the wait. The wait starts only on an empty line.
--     TeamDamage: each character of the line at its own cruise; the whole team before a run exists.
--     NOT pinned, no rule found: run.Slot in the wait.
--
--   Phase 2 (owner 2026-11-06, task p2; design doc 4.37, BOSS_EVENT_SPEC "Phase 2", "Rewards"). "Stage" 1 and 2 are Phases 1 and 2.
--     State() adds Stage, EndsAt (server time), ScreamEndsAt (nil outside the scream), Phase1MaxHp. StageDamageOf(player, stage).
--     First HP 0: stage 1 pays at once, then MaxHp = Phase 1's max + Phase2ExtraHp at full Hp, ScreamSeconds of scream, EndsAt = old
--     end + ScreamSeconds + Phase2ExtraSeconds. ReplicatedStorage attributes BossEventStage, BossEventEndsAt, BossScreamEndsAt,
--     BossScheduleStart. BossScheduleStart is Poses.Schedule's start: moment i comes at scream end + BossDodge.Moment(i).
--     Summary = { Outcome = "Defeated"|"Survived"|"Left", Damage = total, Stage1, Stage2, Short }.
--     Exhausted teams (owner 2026-11-06, BOSS_EVENT_SPEC "Phase 2"): run:ReviveAt(seconds), seconds from now, ends a wait then: full stamina,
--     full line, BossRefill. The service calls it at the scream's start on a waiting run, and on a run that empties during the scream, each
--     with the time to the scream's end, and BossWaitEndsAt stays nil.
--     NOT pinned, no rule found: Short for a player paid one stage only, and the popup flags of a player whose PayStage failed.
--
-- READINGS the docs leave open, each pinned by a check and for the owner to confirm (names start with reading_):
--   a boss run clears BossLine on Destroy, with its other attributes.
--   leave before 3:00: "HP = 7,500 x players in the arena" holds, so max falls by 7,500; current never exceeds max or defeats.
--   DamageMulti's t counts from BossScheduleStart in both stages (the spawn in stage 1), so one schedule lookup serves both.
--   Spot's startAt stays the event's BossEventStart in stage 2; only `index` restarts.
--   bag only: a Sidekick in the Bag on no character gives no possible team, so that player cannot join.
--   8th player: 4.37 says lanes for up to 7, so an 8th is refused.
--   after the event: EquippedCar goes back to what it was at Join (a run moves it; only Team is ruled).
--   joined then left, nobody in at 3:00: same as nobody came.
-- NOT pinned, no rule found, implementer picks and reports: an arena empty after 3:00; a decliner's pad; changing gear mid-event;
--   a Dojo squad character on the event team; rejoining after leaving.
-- NOT reachable from here: a server test cannot fire a client remote, so only the existence of Remotes.BossEventLeave and
--   Remotes.SetAutoRace is checked, not their handlers (SetAutoRace stays ignored in the event, leave runs Leave).
--
-- Runs on Folder players and an isolated PlayerData clone, like SidekickTests. Real wall time well under 40 s.
-- On demand: ReplicatedStorage attributes CarTestOnly = "boss_event", then CarTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990137000
local WALL_LIMIT = 40
local STEP = 0.25 -- Advance step: every time in these tests is a multiple of it, so times compare exactly
local T0 = 1000000 -- the fake server clock's start
local CHAT = "BIG RAGA HAS SPAWNED, TAKE HIM DOWN FOR REWARDS" -- design doc 4.37, owner 2026-11-05

local function approx(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Waits at most `seconds` for `done()`. Returns whether it came true.
local function waitFor(seconds, done)
	local deadline = os.clock() + seconds
	while not done() and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	return done() == true
end

function Tests.make(deps)
	local function boss_event()
		local r, flag = H.report("boss_event")
		local started = os.clock()
		local cleanup, liveRuns, duelists = {}, {}, {}

		local function section(name, body)
			local ok, err = xpcall(body, debug.traceback)
			flag(name .. "_completed", ok, ok and 1 or tostring(err))
		end
		local function eq(name, actual, expected)
			flag(name, actual == expected, actual, expected)
		end
		local function near(name, actual, expected)
			flag(name, approx(actual, expected), actual, expected)
		end

		local gacha = require(Server.GachaService)
		local sidekick = require(Server.SidekickService)
		local catalog = require(Shared.CharacterCatalog)
		local SidekickConfig = require(Shared.SidekickConfig)
		local SpawnArea = require(Shared.SpawnArea)
		local oldCooldown = SpawnArea.START_COOLDOWN
		local oldInterval, oldRollTick, oldWaitAfter = gacha.RollInterval, gacha.RollTick, gacha.WaitAfter

		-- Clone only PlayerData so SetStore never redirects the live player's autosaves.
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestBossEventData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local store = H.store()
		data.SetStore(store)

		local nextId = UID
		local function newPlayer()
			nextId += 1
			local p = H.player(cleanup, nextId)
			data.Load(p, nextId)
			return p
		end
		-- `sideId` on `charId`, both new to the player.
		local function wear(p, charId, sideId)
			gacha.Grant(p, charId)
			local _, entry = sidekick.Grant(p, sideId)
			sidekick.Equip(p, charId, entry)
			return entry
		end

		local chars = {}
		for _, spec in catalog.All() do
			if spec.Rollable and spec.Id ~= catalog.STARTER_ID then
				table.insert(chars, spec.Id)
			end
		end
		flag("test_has_seven_characters", #chars >= 7, #chars, 7)
		local function fighter()
			local p = newPlayer()
			wear(p, chars[1], "side_knight")
			return p
		end
		local function damageOf(id)
			return SidekickConfig.Get(id).Damage
		end

		------------------------------------------------------------------------------------------------------------------------
		-- Sections that need neither new module: the gates in the existing services and the boss run mode.
		------------------------------------------------------------------------------------------------------------------------
		local function gateSections()
			section("autoroll_gate", function()
				local p, rolls = newPlayer(), 0
				p:SetAttribute("AutoRoll", true)
				p:SetAttribute("NeedsStarter", false)
				-- Only this player's rolls are stubbed: a live player in the session keeps rolling.
				gacha.RollInterval = function(who)
					return who == p and 0.02 or oldInterval(who)
				end
				gacha.RollTick = function(who, ...)
					if who == p then
						rolls += 1
						return { Id = chars[1], Emphasized = false }
					end
					return oldRollTick(who, ...)
				end
				gacha.WaitAfter = function(id, emphasized, who)
					return who == p and 0.02 or oldWaitAfter(id, emphasized, who)
				end
				local handle = gacha.StartAutoRoll(p)
				flag(
					"gate_rolls_before",
					waitFor(1, function()
						return rolls >= 1
					end)
				)
				p:SetAttribute("BossEvent", true)
				local held = rolls
				task.wait(0.3)
				eq("gate_no_rolls_during_event", rolls, held)
				eq("gate_autoroll_attribute_kept", p:GetAttribute("AutoRoll"), true)
				p:SetAttribute("BossEvent", nil)
				flag(
					"gate_rolls_resume_after",
					waitFor(1, function()
						return rolls > held
					end)
				)
				handle:Stop()
				gacha.RollInterval, gacha.RollTick, gacha.WaitAfter = oldInterval, oldRollTick, oldWaitAfter
			end)

			section("pad_gate", function()
				local CarService = require(Server.CarService)
				local p = newPlayer()
				local character = deps.newFakeCharacter(CarService.WalkSpawnCFrame())
				character.Parent = character.Parent or workspace
				table.insert(cleanup, character)
				CarService.OnCharacter(p, character)
				SpawnArea.START_COOLDOWN = 0 -- so only the gate can refuse this touch
				local leg = character:FindFirstChild("Left Leg")
				p:SetAttribute("BossEvent", true)
				local during = CarService.PadTouched(p, leg)
				flag("pad_refused_during_event", during ~= true and not CarService.IsAutoRacing(p))
				p:SetAttribute("BossEvent", nil)
				eq("pad_starts_after_event", CarService.PadTouched(p, leg), true)
				CarService.SetAutoRace(p, false)
				SpawnArea.START_COOLDOWN = oldCooldown
			end)
		end

		local function runModeSections()
			local race = require(Server.RaceService)
			local factory = require(Shared.RunnerFactory)
			local Arena = require(Shared.BossArenaConfig)
			local StaminaConfig = require(Shared.StaminaConfig)
			local WAIT = 8.5 -- design doc 4.37, owner 2026-11-06

			local function startRun(p, lane, options)
				local car = factory.build(chars[1])
				car.Name, car.Parent = "CarTestBossRunner", p
				options.Boss = true
				local run = race.NewRun(car, { Path = Arena.LaneRoute(lane), Pads = {}, Tracks = {} }, p, options)
				table.insert(liveRuns, run)
				return run, car
			end
			local function runner()
				local p = newPlayer()
				for i = 1, 3 do
					gacha.Grant(p, chars[i])
				end
				return p
			end

			section("run_mode_refill", function()
				local p = runner()
				local normalTeam = p:GetAttribute("Team")
				local ids = { chars[1], chars[2], chars[3] }
				local log, run = {}, nil
				local atRefill
				-- A team of 2 waits and refills alongside, so it costs no wall time of its own.
				local duoPlayer, duoRefill, duoRun = runner(), nil, nil
				duoRun = startRun(duoPlayer, 7, {
					Team = { chars[1], chars[2] },
					StaminaSeconds = { 0.2, 0.3 },
					OnRunEvent = function(event)
						if event.Kind == "BossRefill" then
							duoRefill = {
								Stamina = table.clone(duoRun.Stamina),
								Slot = duoRun.Slot,
								Line = table.clone(duoRun.Line or {}),
								Attr = duoPlayer:GetAttribute("BossLine"),
							}
						end
					end,
				})
				run = startRun(p, 1, {
					Team = ids,
					StaminaSeconds = { 0.2, 0.3, 0.4 },
					OnRunEvent = function(event)
						table.insert(log, { Kind = event.Kind, T = os.clock() })
						if event.Kind == "BossRefill" then
							atRefill = {
								Stamina = table.clone(run.Stamina),
								Slot = run.Slot,
								Waiting = run.Waiting,
								Line = table.clone(run.Line or {}),
								Attr = p:GetAttribute("BossLine"),
							}
						end
					end,
				})
				local car = run.Car
				local function count(kind)
					local n, last = 0, nil
					for _, event in log do
						if event.Kind == kind then
							n, last = n + 1, event.T
						end
					end
					return n, last
				end
				flag("run_keeps_event_team", H.same(run.Team, ids))
				eq("run_normal_team_kept", p:GetAttribute("Team"), normalTeam)
				eq("run_starts_slot_1", run.Slot, 1)

				local waited = waitFor(3, function()
					return count("BossWait") >= 1 or car.Parent == nil
				end)
				flag("run_waits_when_all_empty", waited and count("BossWait") == 1)
				if count("BossWait") < 1 then
					return -- red: no boss mode yet, the checks below would only repeat this one
				end
				-- Went through the whole team: by BossGone, with no Swap (owner 2026-11-06).
				eq("run_swapped_through_team", count("BossGone"), 3)
				eq("run_no_swap_event", (count("Swap")), 0)
				eq("run_waiting_flag", run.Waiting, true)
				near("run_stamina_empty", run.Stamina[3], 0)
				near("run_gone_slot_1_stays_0", run.Stamina[1], 0)
				near("run_gone_slot_2_stays_0", run.Stamina[2], 0)
				eq("run_wait_line_empty", #(run.Line or { 1 }), 0)
				eq("run_wait_line_attr_empty", p:GetAttribute("BossLine"), "")
				eq("run_speed_zero_in_wait", car:GetAttribute("RunSpeed"), 0)
				local before = car:GetPivot().Position
				task.wait(1)
				flag(
					"run_stands_still_in_wait",
					(car:GetPivot().Position - before).Magnitude < 0.01,
					(car:GetPivot().Position - before).Magnitude,
					0.01
				)
				flag("run_still_alive_in_wait", run.Connection ~= nil and car.Parent ~= nil)

				flag(
					"run_refills",
					waitFor(WAIT + 1, function()
						return count("BossRefill") >= 1
					end)
				)
				local _, waitAt = count("BossWait")
				local _, refillAt = count("BossRefill")
				local gap = refillAt and waitAt and refillAt - waitAt or 0
				flag("run_wait_is_8_5_seconds", gap >= WAIT - 0.1 and gap <= WAIT + 0.6, gap, WAIT)
				atRefill = atRefill or { Stamina = {}, Line = {} }
				flag("run_refill_full_line", H.same(atRefill.Line, { 1, 2, 3 }))
				eq("run_refill_line_attr", atRefill.Attr, "1,2,3")
				duoRefill = duoRefill or { Stamina = {}, Line = {} }
				near("run_duo_refill_slot_1_full", duoRefill.Stamina[1], 100)
				near("run_duo_refill_slot_2_full", duoRefill.Stamina[2], 100)
				eq("run_duo_refill_from_slot_1", duoRefill.Slot, 1)
				flag("run_duo_refill_full_line", H.same(duoRefill.Line, { 1, 2 }))
				eq("run_duo_refill_line_attr", duoRefill.Attr, "1,2")
				duoRun:Destroy()
				near("run_refill_slot_1_full", atRefill.Stamina[1], 100)
				near("run_refill_slot_2_full", atRefill.Stamina[2], 100)
				near("run_refill_slot_3_full", atRefill.Stamina[3], 100)
				eq("run_refill_from_slot_1", atRefill.Slot, 1)
				eq("run_refill_clears_waiting", atRefill.Waiting, false)
				local still = car:GetPivot().Position
				task.wait(0.15)
				flag("run_moves_after_refill", (car:GetPivot().Position - still).Magnitude > 0.1)
				flag(
					"run_waits_again",
					waitFor(3, function()
						return count("BossWait") >= 2
					end)
				)

				eq("run_never_exhausted", (count("Exhausted")), 0)
				flag("run_alive_after_exhaustions", run.Connection ~= nil and car.Parent ~= nil)
				eq("run_pays_nothing", run.PaidTotal, 0)
				eq("run_banks_nothing", run.BankedTotal, 0)
				run:Destroy()
				eq("run_destroy_clears_stamina", p:GetAttribute("Stamina1"), nil)
				eq("run_destroy_clears_slot", p:GetAttribute("RunSlot"), nil)
			end)

			section("run_mode_small_team", function()
				local p, swapped, waited = runner(), 0, false
				local run = startRun(p, 2, {
					Team = { chars[1] },
					StaminaSeconds = { 0.1 },
					OnRunEvent = function(event)
						swapped += event.Kind == "Swap" and 1 or 0
						waited = waited or event.Kind == "BossWait"
					end,
				})
				eq("run_team_of_one", #run.Team, 1)
				flag(
					"run_team_of_one_waits",
					waitFor(2, function()
						return waited
					end)
				)
				eq("run_team_of_one_no_swap", swapped, 0)
				run:Destroy()
			end)

			-- Line run (owner 2026-11-06). A row is the run as one event saw it, so the state an event fires with is what is checked.
			local function lineRun(p, lane, ids, seconds)
				local rows, run = {}, nil
				run = startRun(p, lane, {
					Team = ids,
					StaminaSeconds = seconds,
					OnRunEvent = function(event)
						table.insert(rows, {
							Kind = event.Kind,
							Gone = event.Slot,
							Slot = run.Slot,
							Line = table.clone(run.Line or {}),
							Attr = p:GetAttribute("BossLine"),
							Speed = run.TargetSpeed,
							RunSlot = p:GetAttribute("RunSlot"),
							Equipped = p:GetAttribute("EquippedCar"),
							Waiting = run.Waiting,
						})
					end,
				})
				return run, rows
			end
			local function ofKind(rows, kind)
				local list = {}
				for _, row in rows do
					if row.Kind == kind then
						table.insert(list, row)
					end
				end
				return list
			end
			local function untilWait(rows)
				return waitFor(3, function()
					return #ofKind(rows, "BossWait") >= 1
				end)
			end
			-- The wait's row, checked for every team size: one wait, last of all, on an empty line.
			local function checkWait(name, p, rows, goneCount)
				flag(name .. "_waits", untilWait(rows))
				local gone, waits = ofKind(rows, "BossGone"), ofKind(rows, "BossWait")
				eq(name .. "_gone_count", #gone, goneCount)
				eq(name .. "_one_wait", #waits, 1)
				eq(name .. "_no_swap", #ofKind(rows, "Swap"), 0)
				local row = waits[1] or { Line = { 0 } }
				eq(name .. "_wait_after_last_gone", rows[#rows] == row, true)
				eq(name .. "_wait_flag", row.Waiting, true)
				eq(name .. "_wait_line_empty", #row.Line, 0)
				eq(name .. "_wait_attr_empty", p:GetAttribute("BossLine"), "")
			end
			local function rowOf(list, i)
				return list[i] or { Line = {} }
			end

			section("run_line_drain", function()
				local p = runner()
				local ids = { chars[1], chars[2], chars[3] }
				local run = startRun(p, 5, { Team = ids, StaminaSeconds = { 1, 2, 4 } })
				local from = os.clock()
				RunService.Heartbeat:Wait()
				flag("line_starts_full", H.same(run.Line or {}, { 1, 2, 3 }))
				eq("line_attr_starts_full", p:GetAttribute("BossLine"), "1,2,3")
				eq("line_front_starts_slot_1", run.Slot, 1)
				task.wait(0.3)
				local took = os.clock() - from
				local a, b, c = 100 - run.Stamina[1], 100 - run.Stamina[2], 100 - run.Stamina[3]
				flag("line_all_drain_at_once", a > 0 and b > 0 and c > 0, c, "> 0")
				-- Read in one frame, so the ratios are exact whatever the frame times were.
				flag("line_drain_own_length_2", b > 0 and math.abs(a / b - 2) < 1e-3, b > 0 and a / b or 0, 2)
				flag("line_drain_own_length_4", c > 0 and math.abs(a / c - 4) < 1e-3, c > 0 and a / c or 0, 4)
				flag("line_drain_rate", math.abs(a - 100 * took) < 15, a, 100 * took)
				eq("line_attr_nobody_gone", p:GetAttribute("BossLine"), "1,2,3")
				near("line_speed_is_front", run.TargetSpeed, gacha.CruiseFor(p, chars[1], 1, ids))
				run:Destroy()
				eq("reading_line_attr_clears_on_destroy", p:GetAttribute("BossLine"), nil)
			end)

			section("run_line_middle_goes_first", function()
				local p = runner()
				local ids = { chars[1], chars[2], chars[3] }
				local run, rows = lineRun(p, 5, ids, { 0.6, 0.2, 0.4 })
				checkWait("line_middle", p, rows, 3)
				local gone = ofKind(rows, "BossGone")
				local first, second, third = rowOf(gone, 1), rowOf(gone, 2), rowOf(gone, 3)
				eq("line_middle_first_gone", first.Gone, 2)
				flag("line_middle_first_line", H.same(first.Line, { 1, 3 }))
				eq("line_middle_first_attr", first.Attr, "1,3")
				eq("line_middle_front_stays", first.Slot, 1)
				near("line_middle_speed_stays", first.Speed, gacha.CruiseFor(p, chars[1], 1, ids))
				eq("line_middle_not_waiting", first.Waiting, false)
				eq("line_middle_second_gone", second.Gone, 3)
				flag("line_middle_second_line", H.same(second.Line, { 1 }))
				eq("line_middle_second_attr", second.Attr, "1")
				eq("line_middle_second_not_waiting", second.Waiting, false)
				eq("line_middle_third_gone", third.Gone, 1)
				run:Destroy()
			end)

			section("run_line_front_goes_first", function()
				local p = runner()
				local ids = { chars[1], chars[2], chars[3] }
				local run, rows = lineRun(p, 6, ids, { 0.2, 0.6, 0.4 })
				checkWait("line_front", p, rows, 3)
				local gone = ofKind(rows, "BossGone")
				local first, second, third = rowOf(gone, 1), rowOf(gone, 2), rowOf(gone, 3)
				eq("line_front_first_gone", first.Gone, 1)
				flag("line_front_first_line", H.same(first.Line, { 2, 3 }))
				eq("line_front_first_attr", first.Attr, "2,3")
				eq("line_front_slot_moves", first.Slot, 2)
				eq("line_front_run_slot_moves", first.RunSlot, 2)
				eq("line_front_runner_wears_next", first.Equipped, chars[2])
				near("line_front_speed_follows", first.Speed, gacha.CruiseFor(p, chars[2], 2, ids))
				eq("line_front_second_gone", second.Gone, 3)
				flag("line_front_second_line", H.same(second.Line, { 2 }))
				eq("line_front_second_attr", second.Attr, "2")
				eq("line_front_slot_stays_2", second.Slot, 2)
				eq("line_front_third_gone", third.Gone, 2)
				near("line_front_slot_1_stays_0", run.Stamina[1], 0)
				run:Destroy()
			end)

			-- An attack can empty several slots in one frame (chargeMoves floors them all before the run's next tick).
			section("run_line_same_frame", function()
				local p = runner()
				local ids = { chars[1], chars[2], chars[3] }
				local run, rows = lineRun(p, 2, ids, { 1e6, 1e6, 1e6 })
				RunService.Heartbeat:Wait()
				run.Stamina[1], run.Stamina[2] = 0, 0
				flag(
					"line_two_gone_in_a_frame",
					waitFor(1, function()
						return #ofKind(rows, "BossGone") >= 2
					end)
				)
				flag("line_two_gone_line", H.same(run.Line or {}, { 3 }))
				eq("line_two_gone_attr", p:GetAttribute("BossLine"), "3")
				eq("line_two_gone_front", run.Slot, 3)
				near("line_two_gone_speed", run.TargetSpeed, gacha.CruiseFor(p, chars[3], 3, ids))
				eq("line_two_gone_not_waiting", run.Waiting, false)
				run:Destroy()

				local q = runner()
				local all, allRows = lineRun(q, 3, ids, { 1e6, 1e6, 1e6 })
				RunService.Heartbeat:Wait()
				for slot = 1, 3 do
					all.Stamina[slot] = 0
				end
				checkWait("line_all_gone_in_a_frame", q, allRows, 3)
				all:Destroy()
			end)

			section("run_line_small_teams", function()
				local p = runner()
				local duo, rows = lineRun(p, 4, { chars[1], chars[2] }, { 0.2, 0.4 })
				RunService.Heartbeat:Wait()
				eq("line_duo_attr_starts", p:GetAttribute("BossLine"), "1,2")
				checkWait("line_duo", p, rows, 2)
				local first = rowOf(ofKind(rows, "BossGone"), 1)
				eq("line_duo_first_gone", first.Gone, 1)
				flag("line_duo_first_line", H.same(first.Line, { 2 }))
				eq("line_duo_first_attr", first.Attr, "2")
				eq("line_duo_slot_moves", first.Slot, 2)
				duo:Destroy()

				local q = runner()
				local solo, soloRows = lineRun(q, 3, { chars[1] }, { 0.1 })
				RunService.Heartbeat:Wait()
				eq("line_solo_attr_starts", q:GetAttribute("BossLine"), "1")
				checkWait("line_solo", q, soloRows, 1)
				eq("line_solo_gone", rowOf(ofKind(soloRows, "BossGone"), 1).Gone, 1)
				solo:Destroy()
			end)

			section("run_mode_real_numbers", function()
				local p = runner()
				local run = startRun(p, 3, { Team = { chars[2], chars[3] } })
				local seconds = p:GetAttribute("RunSeconds1")
				local expected = StaminaConfig.Seconds(
					catalog.Get(chars[2]),
					gacha.StaminaMulti(p) * sidekick.StaminaMulti(p, chars[2])
				)
				near("run_real_stamina", seconds, expected)
				near("run_real_cruise", run.TargetSpeed, gacha.CruiseFor(p, chars[2], 1))
				eq("run_no_seam_means_not_waiting", run.Waiting, false)
				run:Destroy()
			end)

			section("run_mode_wraps", function()
				local p = runner()
				local lane = 4
				local run, car = startRun(p, lane, { Team = { chars[1] }, StaminaSeconds = { 1e6 } })
				run.TargetSpeed = 20000 -- several laps a second: an open route would pin the runner at its end
				task.wait(1)
				local a = car:GetPivot().Position
				RunService.Heartbeat:Wait()
				RunService.Heartbeat:Wait()
				local b = car:GetPivot().Position
				flag("run_still_moving_past_a_lap", (a - b).Magnitude > 1, (a - b).Magnitude, 1)
				eq("run_never_finishes", run.Finished, false)
				eq("run_driver_not_done", run.Driver.Done, false)
				local radius = flatDistance(b, Arena.Center)
				flag(
					"run_stays_in_its_lane",
					math.abs(radius - Arena.LaneRadius(lane)) < 3,
					radius,
					Arena.LaneRadius(lane)
				)
				run:Destroy()
			end)
		end

		------------------------------------------------------------------------------------------------------------------------
		-- Sections on the new config and service.
		------------------------------------------------------------------------------------------------------------------------
		local function configSection(Cfg)
			section("config", function()
				-- Owner values (design doc 4.37)
				eq("interval_30_minutes", Cfg.IntervalSeconds, 1800)
				eq("prep_1_minute", Cfg.PrepSeconds, 60)
				eq("join_closes_at_3_00", Cfg.JoinSeconds, 180)
				eq("total_8_minutes", Cfg.TotalSeconds, 480)
				eq("refill_wait_8_5", Cfg.RefillWaitSeconds, 8.5)
				eq("chat_message_text", Cfg.ChatMessage, CHAT)
				-- Spec placeholders: the only literal checks of them, retune here
				eq("owner_rise_1_5", Cfg.RiseSeconds, 1.5) -- owner 2026-11-05, replaces 2-3 s
				eq("owner_intro_3", Cfg.IntroSeconds, 3) -- owner 2026-11-05: the rise plus the cutscene
				-- Owner 2026-11-06: per stage, and the old flat numbers are gone.
				eq("owner_attack_cost_stage_1", Cfg.Stage(1).AttackStaminaCost, 15)
				eq("owner_attack_cost_stage_2", Cfg.Stage(2).AttackStaminaCost, 30)
				eq("owner_status_seconds_stage_1", Cfg.Stage(1).StatusSeconds, 15)
				eq("owner_status_seconds_stage_2", Cfg.Stage(2).StatusSeconds, 20)
				eq("old_attack_cost_removed", Cfg.AttackStaminaCost, nil)
				eq("old_shout_seconds_removed", Cfg.ShoutSeconds, nil)
				eq("old_adapted_seconds_removed", Cfg.AdaptedSeconds, nil)
				eq("owner_phase2_extra_hp", Cfg.Phase2ExtraHp, 50000)
				eq("owner_phase2_extra_seconds", Cfg.Phase2ExtraSeconds, 120)
				eq("owner_scream_seconds", Cfg.ScreamSeconds, 6)
				do -- VehicleEffects.Boost scales an effect about the body
					local Effects = require(Shared.VehicleEffects)
					local function boosted(kind, id)
						local car = Instance.new("Model")
						car.PrimaryPart = Instance.new("Part")
						car.PrimaryPart.Parent = car
						Effects.ApplyProfile(car, kind, id)
						return car
					end
					local aura = boosted("Aura", "ember_aura")
					local at = aura.PrimaryPart:FindFirstChildWhichIsA("Attachment")
					local emitter = aura.PrimaryPart:FindFirstChildWhichIsA("ParticleEmitter", true)
					local position, size = at.Position, emitter.Size.Keypoints[1].Value
					Effects.Boost(aura, 2)
					eq("boost_moves_attachment", (at.Position - position * 2).Magnitude < 1e-3, true)
					eq("boost_scales_emitter", math.abs(emitter.Size.Keypoints[1].Value - size * 2) < 1e-3, true)
					local wake = boosted("Trail", "void_trail")
					local trail = wake.MarketEffects:FindFirstChildWhichIsA("Trail")
					local life = trail.Lifetime
					Effects.Boost(wake, 2)
					eq("boost_longer_trail", trail.Lifetime > life, true)
					aura:Destroy()
					wake:Destroy()
				end
				eq("owner_phase1_money", Cfg.Phase1Money, 100000)
				eq("owner_phase2_gems", Cfg.Phase2Gems, 1000)
				eq("owner_vulnerable_multi", Cfg.VulnerableMulti, 1.5)
				eq("move_chat_is_a_function", type(Cfg.MoveChat), "function")
				eq("move_chat_attack_1", Cfg.MoveChat("Impact", 1), "Big Raga attacks! -15% stamina")
				eq("move_chat_attack_2", Cfg.MoveChat("Impact", 2), "Big Raga attacks! -30% stamina")
				eq("move_chat_shout_1", Cfg.MoveChat("Roar", 1), "Big Raga shouts! Damage down for 15 s")
				eq("move_chat_shout_2", Cfg.MoveChat("Roar", 2), "Big Raga shouts! Damage down for 20 s")
				eq(
					"move_chat_wheel_1",
					Cfg.MoveChat("WheelClick", 1),
					"Big Raga turns its wheel! It takes 10% less damage for 15 s"
				)
				eq(
					"move_chat_wheel_2",
					Cfg.MoveChat("WheelClick", 2),
					"Big Raga turns its wheel! It takes 10% less damage for 20 s"
				)
				eq("spec_camera_fov_100", Cfg.CameraFov, 100)
				eq("owner_hp_per_player_7500", Cfg.HpPerPlayer, 7500) -- owner 2026-11-06
				eq("spec_hit_every_1_5", Cfg.HitEverySeconds, 1.5)
				eq("owner_min_share_5_percent", Cfg.MinDamageShare, 0.05) -- owner 2026-11-06
				eq("spec_hit_matches_sidekick_config", Cfg.HitEverySeconds, SidekickConfig.HitInterval)
				-- Formula: 1 + min(1, cruise / 800), at most +100%
				near("scale_at_0", Cfg.SpeedScale(0), 1)
				near("scale_at_200", Cfg.SpeedScale(200), 1.25)
				near("scale_at_400", Cfg.SpeedScale(400), 1.5)
				near("scale_at_800", Cfg.SpeedScale(800), 2)
				near("scale_capped_at_1600", Cfg.SpeedScale(1600), 2)
				-- Owner 2026-11-06: no average; each character at its own scale. Service numbers: "damage", "individual_hits".
				near(
					"team_damage_sum_3",
					10 * Cfg.SpeedScale(400) + 14 * Cfg.SpeedScale(200) + 22 * Cfg.SpeedScale(800),
					76.5
				)
				near("team_damage_sum_2", 10 * Cfg.SpeedScale(0) + 14 * Cfg.SpeedScale(0), 24)
				near("team_damage_one", 10 * Cfg.SpeedScale(800), 20)
				near("team_damage_capped", 3 * 22 * Cfg.SpeedScale(1600), 132)
			end)
			-- BOSS_EVENT_SPEC "Phase 2", wheel: very fast through the scream, a dead stop, a hold, then a slow steady spin.
			section("wheel_spin", function()
				local spin, scream = Cfg.WheelSpinAt, Cfg.ScreamSeconds
				eq("wheel_0_at_start", spin(0), 0)
				eq("wheel_0_before_start", spin(-1), 0)
				local fast = spin(2) - spin(1)
				flag("wheel_fast_in_scream", fast >= math.rad(720), fast, math.rad(720))
				eq("wheel_dead_stop_0_5", spin(scream + 0.5), spin(scream))
				eq("wheel_dead_stop_0_99", spin(scream + 0.99), spin(scream))
				local slow = spin(scream + 5.5) - spin(scream + 5)
				flag("wheel_rises_after_hold", spin(scream + 5) > spin(scream), spin(scream + 5), spin(scream))
				flag("wheel_slow_positive", slow > 0, slow, 0)
				flag("wheel_slow_under_90_deg_s", slow / 0.5 < math.rad(90), slow / 0.5, math.rad(90))
				local worstDrop = 0
				for i = 1, 400 do
					worstDrop = math.max(worstDrop, spin((i - 1) * 0.05) - spin(i * 0.05))
				end
				eq("wheel_never_decreases", worstDrop, 0)
			end)
		end

		local function serviceSections(Cfg, S, realHooks)
			local clock = T0
			local PREP, INTRO, CLOSE, TOTAL = Cfg.PrepSeconds, Cfg.IntroSeconds, Cfg.JoinSeconds, Cfg.TotalSeconds
			local FIGHT = PREP + INTRO -- the intro's end
			local HP = Cfg.HpPerPlayer
			local EVERY = Cfg.HitEverySeconds
			local Relic = require(Server.RelicService)

			local log
			local function install()
				log = {
					Arrive = {},
					Depart = {},
					Chat = {},
					MoveChat = {},
					Paid = {},
					Popups = {},
					Started = {},
					Runs = {},
					BossHits = {},
				}
				S.Hooks.DamageMulti = function()
					return 1
				end
				S.Hooks.Arrive = function(p, lane)
					log.Arrive[p] = lane
				end
				S.Hooks.Depart = function(p)
					log.Depart[p] = (log.Depart[p] or 0) + 1
				end
				S.Hooks.Chat = function(text)
					table.insert(log.Chat, text)
				end
				S.Hooks.MoveChat = function(p, text)
					table.insert(log.MoveChat, { Player = p, Text = text, At = clock - T0 })
				end
				S.Hooks.PayStage = function(p, stage)
					table.insert(log.Paid, { Player = p, Stage = stage })
					return true
				end
				S.Hooks.RewardPopup = function(p, summary)
					table.insert(log.Popups, { Player = p, Summary = summary })
				end
				S.Hooks.BossHits = function(p, entries)
					table.insert(log.BossHits, { Player = p, Entries = table.clone(entries), At = clock - T0 })
				end
				S.Hooks.StartRun = function(p, team, lane)
					local line = {}
					for slot in team do
						table.insert(line, slot)
					end
					local run = {
						TargetSpeed = 0,
						Waiting = false,
						Team = team,
						Lane = lane,
						Destroyed = 0,
						Slot = 1,
						Line = line,
						Stamina = { 100, 100, 100 },
					}
					function run:Destroy()
						self.Destroyed += 1
					end
					run.Revives = {}
					function run:ReviveAt(seconds)
						table.insert(self.Revives, seconds)
					end
					log.Runs[p] = run
					table.insert(log.Started, { Player = p, Team = team, Lane = lane, At = clock - T0 })
					return run
				end
			end
			local function to(t)
				clock = T0 + t
				S.Advance(clock)
			end
			-- Every Advance on the way, as a live server would see them.
			local function walk(t)
				while clock < T0 + t do
					clock = math.min(clock + STEP, T0 + t)
					S.Advance(clock)
				end
			end
			-- A fresh server at T0 with a started event: time t in a test is then the event's own clock.
			local function begin()
				clock = T0
				S.Reset(T0)
				install()
				S.Start("Test")
			end
			local function phase()
				return S.State().Phase
			end
			-- Who PayStage was called for in `stage`.
			local function paidIn(stage)
				local list = {}
				for _, row in log.Paid do
					if row.Stage == stage then
						table.insert(list, row.Player)
					end
				end
				return list
			end
			local function timesPaid(p, stage)
				local n = 0
				for _, row in log.Paid do
					n += (row.Player == p and row.Stage == stage) and 1 or 0
				end
				return n
			end
			local function popupsOf(p)
				local list = {}
				for _, row in log.Popups do
					if row.Player == p then
						table.insert(list, row.Summary)
					end
				end
				return list
			end
			-- For the sections that run the real hooks: no chest, Money or popup on a Folder player.
			local function quietRewards()
				S.Hooks.PayStage = function()
					return true
				end
				S.Hooks.RewardPopup = function() end
			end
			-- One character's hit before statuses (design doc 4.37), worked out here and not read from the service.
			local function hitIn(p, team, slot)
				local id = team[slot]
				local worn = id and sidekick.Worn(p, id)
				if not worn then
					return 0
				end
				return worn.Damage * Relic.Multi(p, id, "Damage") * Cfg.SpeedScale(gacha.CruiseFor(p, id, slot, team))
			end
			-- `slot`'s hit in the player's event team, the front's by default.
			local function hitOf(p, slot)
				local run = log.Runs[p]
				return hitIn(p, S.TeamOf(p), slot or (run and run.Slot) or 1)
			end
			-- One hit from each of `slots` of `team`, all of them by default: TeamDamage's number.
			local function sumOf(p, team, slots)
				local total = 0
				if slots then
					for _, slot in slots do
						total += hitIn(p, team, slot)
					end
				else
					for slot in team do
						total += hitIn(p, team, slot)
					end
				end
				return total
			end
			-- Runs body with owner[key] replaced, and always puts it back.
			local function withStub(owner, key, fake, body)
				local old = owner[key]
				owner[key] = fake
				local ok, err = xpcall(body, debug.traceback)
				owner[key] = old
				if not ok then
					error(err, 0)
				end
			end
			-- Cruise of a character by id, or `byId` itself when a number.
			local function withCruise(byId, body)
				withStub(gacha, "CruiseFor", function(_, id)
					return type(byId) == "number" and byId or byId[id]
				end, body)
			end
			-- One hit of exactly `amount` from `p`, capped by the HP left. The run must be running and not in the scream.
			local function deal(p, amount)
				local old = S.Hooks.DamageMulti
				S.Hooks.DamageMulti = function()
					return amount / hitOf(p)
				end
				local dealt = S.RecordHit(p)
				S.Hooks.DamageMulti = old
				return dealt
			end
			-- The hit that empties HP: stage 1's starts stage 2, stage 2's ends the event.
			local function kill(p)
				return deal(p, 1e9)
			end
			-- To the scream's end with nobody hitting, so damage sums stay exact.
			local function pastScream(...)
				for _, p in { ... } do
					log.Runs[p].Waiting = true
				end
				to(S.State().ScreamEndsAt - T0)
				for _, p in { ... } do
					log.Runs[p].Waiting = false
				end
			end
			local function statusRow(p, id)
				for _, row in game:GetService("HttpService"):JSONDecode(p:GetAttribute("BossStatus") or "[]") do
					if row.Id == id then
						return row
					end
				end
				return nil
			end
			-- A press in the middle of `p`'s window for moment `index`. `base` is the event-clock time the stage's moments count from.
			local function press(p, index, stage, base)
				local BossDodge = require(Shared.BossDodge)
				local moment = T0 + base + BossDodge.Moment(index)
				local spot = BossDodge.Spot(p:GetAttribute("UserId"), T0, index, stage)
				local from, till = BossDodge.Window(spot, moment, stage)
				local stamp = (from + till) / 2
				to(stamp - T0)
				return S.Dodge(p, index, stamp)
			end
			local function serviceSection(name, body)
				section(name, function()
					S.SetClock(function()
						return clock
					end)
					clock = T0
					S.Reset(T0)
					install()
					body()
				end)
			end

			section("phase_pure", function()
				eq("phase_nil_idle", S.PhaseAt(nil), "Idle")
				eq("phase_negative_idle", S.PhaseAt(-1), "Idle")
				eq("phase_0_prep", S.PhaseAt(0), "Prep")
				eq("phase_before_spawn_prep", S.PhaseAt(PREP - 0.01), "Prep")
				eq("phase_spawn_fight", S.PhaseAt(PREP), "Fight")
				eq("phase_intro_is_fight", S.PhaseAt(PREP + INTRO / 2), "Fight")
				eq("phase_before_8_00_fight", S.PhaseAt(TOTAL - 0.01), "Fight")
				eq("phase_8_00_end", S.PhaseAt(TOTAL), "End")
				eq("phase_past_end", S.PhaseAt(TOTAL + 100), "End")
			end)

			serviceSection("timeline", function()
				eq("idle_before_start", phase(), "Idle")
				begin()
				local p = fighter()
				eq("start_is_prep", phase(), "Prep")
				eq("start_keeps_source", S.State().Source, "Test")
				eq("prep_join_ok", S.Join(p), true)
				walk(PREP - STEP)
				eq("still_prep_before_1_00", phase(), "Prep")
				eq("no_run_in_prep", log.Runs[p], nil)
				to(PREP)
				eq("fight_at_1_00", phase(), "Fight")
				eq("no_run_in_intro", log.Runs[p], nil)
				walk(FIGHT - STEP)
				eq("no_damage_in_intro", S.DamageOf(p), 0)
				eq("hp_full_in_intro", S.State().Hp, HP)
				eq("record_hit_refused_in_intro", S.RecordHit(p), 0)
				to(FIGHT)
				flag("run_starts_at_intro_end", log.Runs[p] ~= nil)
				near("elapsed_reported", S.State().Elapsed, FIGHT)
				local late = fighter()
				walk(CLOSE - STEP)
				eq("join_open_just_before_3_00", S.Join(late), true)
				to(CLOSE)
				local tooLate = fighter()
				flag("join_closed_at_3_00", S.Join(tooLate) == false and not S.IsIn(tooLate))
				eq("refused_no_gate_attribute", tooLate:GetAttribute("BossEvent"), nil)
				eq("event_runs_on_with_players", phase(), "Fight")
				flag("damage_dealt_by_3_00", S.DamageOf(p) > 0)
				-- Timeout: only 8:00 ends it, and it pays nothing. Both teams wait from here, so no hit can defeat the boss first.
				log.Runs[p].Waiting = true
				log.Runs[late].Waiting = true
				walk(TOTAL - STEP)
				eq("fight_until_8_00", phase(), "Fight")
				flag("not_defeated", S.State().Hp > 0)
				to(TOTAL)
				eq("idle_after_8_00", phase(), "Idle")
				eq("timeout_reported", S.State().LastEnd, "Timeout")
				eq("timeout_pays_nothing", #log.Paid, 0)
				eq("timeout_in_stage_1_no_popup", #log.Popups, 0)
				eq("timeout_returns_player", log.Depart[p], 1)
			end)

			serviceSection("nobody_came", function()
				begin()
				to(PREP)
				eq("boss_waits_with_nobody", phase(), "Fight")
				eq("nobody_hp_0", S.State().MaxHp, 0)
				walk(CLOSE - STEP)
				eq("nobody_not_defeated_at_0_hp", phase(), "Fight")
				eq("nobody_no_rewards_yet", #log.Paid, 0)
				to(CLOSE)
				eq("nobody_ends_at_3_00", phase(), "Idle")
				eq("nobody_reported", S.State().LastEnd, "NoPlayers")
				eq("nobody_pays_nothing", #log.Paid, 0)

				begin()
				local p = fighter()
				S.Join(p)
				to(100)
				S.Leave(p, "Left")
				eq("reading_all_left_keeps_waiting", phase(), "Fight")
				to(CLOSE)
				eq("reading_all_left_by_3_00_ends", S.State().LastEnd, "NoPlayers")
			end)

			serviceSection("defeat", function()
				begin()
				local a = fighter()
				S.Join(a)
				to(FIGHT)
				log.Runs[a].TargetSpeed = 800
				local hit = S.TeamDamage(a)
				flag("defeat_hit_positive", hit > 0, hit)
				for _ = 1, math.ceil(HP / hit) - 1 do
					S.RecordHit(a)
				end
				eq("defeat_not_before_empty", phase(), "Fight")
				S.RecordHit(a)
				-- Owner 2026-11-06: the first HP 0 pays Phase 1 and starts Phase 2; only the second ends the event.
				eq("first_zero_starts_stage_2", S.State().Stage, 2)
				eq("first_zero_keeps_fight", phase(), "Fight")
				eq("first_zero_pays_stage_1_once", #paidIn(1), 1)
				eq("first_zero_keeps_player", log.Depart[a], nil)
				eq("first_zero_keeps_run", log.Runs[a].Destroyed, 0)
				pastScream(a)
				kill(a)
				eq("defeat_ends_early", phase(), "Idle")
				eq("defeat_reported", S.State().LastEnd, "Defeated")
				eq("defeat_rewards_once", #paidIn(2), 1)
				eq("defeat_returns_player", log.Depart[a], 1)
				eq("defeat_stops_run", log.Runs[a].Destroyed, 1)
				eq("hit_after_end_is_0", S.RecordHit(a), 0)
				S.Advance(T0 + TOTAL)
				eq("timeout_after_defeat_changes_nothing", S.State().LastEnd, "Defeated")
				eq("start_again_after_end", S.Start("Test"), true)
			end)

			serviceSection("schedule", function()
				local INTERVAL = Cfg.IntervalSeconds
				-- Timer marks
				eq("next_mark_after_reset", S.State().NextAt, T0 + INTERVAL)
				to(INTERVAL - STEP)
				eq("idle_before_mark", phase(), "Idle")
				to(INTERVAL)
				eq("mark_starts_event", phase(), "Prep")
				eq("mark_source_timer", S.State().Source, "Timer")
				eq("next_mark_moves_on", S.State().NextAt, T0 + 2 * INTERVAL)
				to(INTERVAL + CLOSE)
				eq("timer_event_ended_empty", phase(), "Idle")
				to(2 * INTERVAL)
				eq("second_mark_starts_event", phase(), "Prep")
				-- A purchase does not move the timer, and a due time inside an event skips to the next mark.
				clock = T0
				S.Reset(T0)
				install()
				clock = T0 + INTERVAL - 100
				eq("paid_start_ok", S.Start("Paid"), true)
				eq("paid_keeps_mark", S.State().NextAt, T0 + INTERVAL)
				eq("cannot_start_while_active", S.Start("Paid"), false)
				local p = fighter()
				S.Join(p)
				to(INTERVAL)
				log.Runs[p].Waiting = true -- no hits: this event must reach its timeout
				eq("due_inside_event_no_restart", S.State().Source, "Paid")
				near("due_inside_event_clock_kept", S.State().Elapsed, 100)
				eq("due_inside_event_skips_mark", S.State().NextAt, T0 + 2 * INTERVAL)
				to(INTERVAL - 100 + TOTAL)
				eq("paid_event_timed_out", S.State().LastEnd, "Timeout")
				to(2 * INTERVAL - STEP)
				eq("no_makeup_event", phase(), "Idle")
				to(2 * INTERVAL)
				eq("next_mark_after_skip_starts", S.State().Source, "Timer")
				-- A server hitch over several marks: one event, and the next mark stays on the grid and ahead.
				clock = T0
				S.Reset(T0)
				install()
				to(3.5 * INTERVAL)
				eq("hitch_one_event", phase(), "Prep")
				eq("hitch_next_on_grid", S.State().NextAt, T0 + 4 * INTERVAL)
			end)

			serviceSection("lock_out", function()
				begin()
				local none = newPlayer()
				none:SetAttribute("RebirthLevel", 9)
				local ok, why = S.Join(none)
				eq("no_sidekick_refused_at_any_rebirth", ok, false)
				eq("refusal_has_reason", type(why), "string")
				eq("no_sidekick_not_in", S.IsIn(none), false)
				eq("no_sidekick_no_gate", none:GetAttribute("BossEvent"), nil)
				eq("no_sidekick_adds_no_hp", S.State().MaxHp, 0)
				local low = fighter()
				low:SetAttribute("RebirthLevel", 0)
				eq("rebirth_is_not_the_gate", S.Join(low), true)
				eq("second_join_refused", S.Join(low), false)
				eq("second_join_adds_no_hp", S.State().MaxHp, HP)
				local bagOnly = newPlayer()
				gacha.Grant(bagOnly, chars[1])
				sidekick.Grant(bagOnly, "side_chain")
				eq("reading_bag_only_refused", S.Join(bagOnly), false)
				local idle = fighter()
				clock = T0
				S.Reset(T0)
				install()
				eq("join_refused_when_idle", S.Join(idle), false)
			end)

			serviceSection("team_pick", function()
				begin()
				local a, b, c, d, bare, unowned = chars[1], chars[2], chars[3], chars[4], chars[5], chars[6]
				local p = newPlayer()
				for _, id in { a, b, c, d } do
					wear(p, id, "side_chain")
				end
				gacha.Grant(p, bare)
				local normal, equipped = p:GetAttribute("Team"), p:GetAttribute("EquippedCar")
				eq("set_team_needs_joining", S.SetTeam(p, { a }), false)
				S.Join(p)
				eq("set_team_three", S.SetTeam(p, { c, a, b }), true)
				local picked = { c, a, b }
				flag("team_kept_in_slot_order", H.same(S.TeamOf(p), picked))
				local refused = {
					["four"] = { a, b, c, d },
					["duplicate"] = { a, a },
					["no_sidekick"] = { a, bare },
					["unowned"] = { a, unowned },
					["empty"] = {},
					["not_a_list"] = "nope",
					["bad_id"] = { a, 5 },
					["unknown_id"] = { "no_such_character" },
					["with_keys"] = { a, extra = b },
				}
				for name, ids in refused do
					eq("refused_" .. name, S.SetTeam(p, ids), false)
					flag("refused_keeps_team_" .. name, H.same(S.TeamOf(p), picked))
				end
				eq("refused_nil", S.SetTeam(p, nil), false)
				eq("set_team_leaves_normal_team", p:GetAttribute("Team"), normal)

				local future = newPlayer() -- a Sidekick id this version does not know deals nothing and fills no slot
				gacha.Grant(future, a)
				sidekick.Apply(
					future,
					{ Sidekicks = { { Id = "side_future", Entry = "x" } }, CharacterGear = { [a] = "x" } }
				)
				eq("unknown_sidekick_not_eligible", S.Join(future), false)

				-- 1 or 2 such characters run 1 or 2; a partial pick is kept; no pick gets AutoTeam at 1:00.
				local one, two, partial, none = fighter(), newPlayer(), newPlayer(), newPlayer()
				wear(two, a, "side_chain")
				wear(two, b, "side_chain")
				for _, id in { a, b, c } do
					wear(partial, id, "side_chain")
					wear(none, id, "side_chain")
				end
				for _, joiner in { one, two, partial, none } do
					S.Join(joiner)
				end
				eq("partial_pick", S.SetTeam(partial, { b }), true)
				to(PREP)
				eq("team_of_one", #S.TeamOf(one), 1)
				eq("team_of_two", #S.TeamOf(two), 2)
				flag("partial_pick_kept", H.same(S.TeamOf(partial), { b }))
				flag("no_pick_gets_auto_team", H.same(S.TeamOf(none), S.AutoTeam(none)) and #S.TeamOf(none) == 3)
				flag("pick_survives_1_00", H.same(S.TeamOf(p), picked))
				eq("set_team_refused_after_1_00", S.SetTeam(p, { a }), false)
				flag("refused_after_1_00_keeps_team", H.same(S.TeamOf(p), picked))
				to(FIGHT)
				flag("run_gets_event_team", log.Runs[p] and H.same(log.Runs[p].Team, picked))
				eq("run_gets_lane", log.Runs[p] and log.Runs[p].Lane, S.LaneOf(p))
				eq("normal_team_kept_in_fight", p:GetAttribute("Team"), normal)
				p:SetAttribute("EquippedCar", c) -- what the real run does at its first slot
				S.End("Timeout")
				eq("normal_team_kept_after", p:GetAttribute("Team"), normal)
				eq("reading_equipped_restored_after", p:GetAttribute("EquippedCar"), equipped)
			end)

			-- Owner 2026-11-05 (design doc 4.37, BOSS_EVENT_SPEC "Team HUD"): the event's own roster, apart from the main Team.
			serviceSection("event_roster", function()
				begin()
				local a, b, c, bare = chars[1], chars[2], chars[3], chars[4]
				local p = newPlayer()
				for _, id in { a, b, c } do
					wear(p, id, "side_chain")
				end
				gacha.Grant(p, bare)
				local normal, equipped = p:GetAttribute("Team"), p:GetAttribute("EquippedCar")

				eq("prep_run_needs_membership", (S.StartPrepRun(p)), false)
				eq("prep_run_outside_sets_nothing", p:GetAttribute("BossPrepRun"), nil)
				eq("roster_join_ok", S.Join(p), true)
				local auto = S.AutoTeam(p)
				eq("roster_join_publishes_auto", p:GetAttribute("BossTeam"), table.concat(auto, ","))
				eq("roster_join_publishes_lane", p:GetAttribute("BossLane"), S.LaneOf(p))
				eq("roster_join_has_no_pick_yet", S.TeamOf(p), nil)
				eq("roster_join_runner_is_first", p:GetAttribute("EquippedCar"), auto[1])
				for slot, id in auto do
					near(
						"roster_cruise_" .. slot,
						p:GetAttribute("BossTeamCruise" .. slot),
						gacha.CruiseFor(p, id, slot)
					)
					local seconds = p:GetAttribute("BossTeamStamina" .. slot)
					flag("roster_stamina_" .. slot, type(seconds) == "number" and seconds > 0, seconds, "> 0")
				end
				eq("roster_join_keeps_main_team", p:GetAttribute("Team"), normal)
				eq("prep_run_for_a_member", S.StartPrepRun(p), true)
				eq("prep_run_published", p:GetAttribute("BossPrepRun"), true)

				eq("roster_set_team_ok", S.SetTeam(p, { c, a }), true)
				eq("roster_set_team_publishes", p:GetAttribute("BossTeam"), c .. "," .. a)
				eq("roster_set_team_saves", p:GetAttribute("LastBossTeam"), c .. "," .. a)
				near("roster_set_team_cruise", p:GetAttribute("BossTeamCruise1"), gacha.CruiseFor(p, c, 1))
				eq("roster_set_team_clears_third_cruise", p:GetAttribute("BossTeamCruise3"), nil)
				eq("roster_set_team_clears_third_stamina", p:GetAttribute("BossTeamStamina3"), nil)
				eq("roster_set_team_runner_is_first", p:GetAttribute("EquippedCar"), c)
				eq("roster_set_team_keeps_main_team", p:GetAttribute("Team"), normal)
				eq("roster_refused_pick", S.SetTeam(p, { bare }), false)
				eq("roster_refused_keeps_published", p:GetAttribute("BossTeam"), c .. "," .. a)
				eq("roster_refused_keeps_saved", p:GetAttribute("LastBossTeam"), c .. "," .. a)

				S.Leave(p, "Left")
				for _, name in { "BossTeam", "BossLane", "BossPrepRun", "BossTeamCruise1", "BossTeamStamina1" } do
					eq("roster_leave_clears_" .. name, p:GetAttribute(name), nil)
				end
				eq("roster_leave_restores_runner", p:GetAttribute("EquippedCar"), equipped)
				eq("roster_leave_keeps_main_team", p:GetAttribute("Team"), normal)
				eq("roster_leave_keeps_saved", p:GetAttribute("LastBossTeam"), c .. "," .. a)

				-- No pick by 1:00: the auto team is the locked one, published and saved.
				local none = fighter()
				S.Join(none)
				to(PREP)
				local locked = table.concat(S.TeamOf(none), ",")
				eq("roster_lock_publishes", none:GetAttribute("BossTeam"), locked)
				eq("roster_lock_saves", none:GetAttribute("LastBossTeam"), locked)
			end)

			serviceSection("saved_team", function()
				begin()
				local a, b, c = chars[1], chars[2], chars[3]
				local p = newPlayer()
				local entryB
				wear(p, a, "side_chain")
				entryB = wear(p, b, "side_chain")
				wear(p, c, "side_chain")
				p:SetAttribute("LastBossTeam", b .. "," .. a)
				eq("saved_join_ok", S.Join(p), true)
				flag("saved_team_used_by_join", H.same(S.TeamOf(p), { b, a }))
				eq("saved_team_published", p:GetAttribute("BossTeam"), b .. "," .. a)
				S.Leave(p, "Left")

				-- A Sidekick off, a repeat, an unknown and an unowned id all drop out, in order.
				sidekick.Equip(p, b, nil)
				flag("saved_fixture_b_bare", entryB ~= nil and not sidekick.Worn(p, b))
				p:SetAttribute("LastBossTeam", table.concat({ b, a, a, "no_such_character", chars[6], c }, ","))
				eq("saved_filtered_join_ok", S.Join(p), true)
				flag(
					"saved_team_filtered",
					H.same(S.TeamOf(p), { a, c }),
					table.concat(S.TeamOf(p) or {}, ","),
					a .. "," .. c
				)
				S.Leave(p, "Left")

				-- None left: as a player with no saved team.
				p:SetAttribute("LastBossTeam", b)
				eq("saved_empty_join_ok", S.Join(p), true)
				eq("saved_none_valid_no_team_yet", S.TeamOf(p), nil)
				S.Leave(p, "Left")

				-- Late joiners: no edits, the run starts at once, with the saved team or else the auto team.
				to(PREP)
				to(FIGHT + 1)
				local late = newPlayer()
				wear(late, a, "side_chain")
				wear(late, c, "side_chain")
				late:SetAttribute("LastBossTeam", c)
				eq("late_saved_join_ok", S.Join(late), true)
				flag("late_saved_team_used", H.same(S.TeamOf(late), { c }))
				flag("late_saved_runs_at_once", log.Runs[late] ~= nil and H.same(log.Runs[late].Team, { c }))
				eq("late_saved_refused_edits", S.SetTeam(late, { a }), false)
				flag("late_saved_keeps_team", H.same(S.TeamOf(late), { c }))
				local fresh = fighter()
				eq("late_fresh_join_ok", S.Join(fresh), true)
				flag("late_fresh_gets_auto", H.same(S.TeamOf(fresh), S.AutoTeam(fresh)))
				flag("late_fresh_runs_at_once", log.Runs[fresh] ~= nil)
				eq("late_fresh_refused_edits", S.SetTeam(fresh, { chars[1] }), false)

				-- Saved through PlayerData, additive; junk loads as nothing.
				nextId += 1
				local savedId = nextId
				local keeper = H.player(cleanup, savedId)
				data.Load(keeper, savedId)
				keeper:SetAttribute("LastBossTeam", a .. "," .. c)
				eq("saved_field_save_ok", data.Save(keeper, savedId, true), true)
				eq("saved_field_written", store.data[data.KeyFor(savedId)].LastBossTeam, a .. "," .. c)
				local record = H.copy(store.data[data.KeyFor(savedId)])
				record.LastBossTeam = a
				nextId += 1
				store.data[data.KeyFor(nextId)] = record
				local back = H.player(cleanup, nextId)
				data.Load(back, nextId)
				eq("saved_field_loaded", back:GetAttribute("LastBossTeam"), a)
				record = H.copy(record)
				record.LastBossTeam = 5
				nextId += 1
				store.data[data.KeyFor(nextId)] = record
				local junk = H.player(cleanup, nextId)
				data.Load(junk, nextId)
				eq("saved_field_junk_empty", junk:GetAttribute("LastBossTeam"), "")
			end)

			-- Owner 2026-11-06: the event team earns its own team bonus; the main Team's counts for nothing here.
			serviceSection("event_team_bonus", function()
				begin()
				local Stamina = require(Shared.StaminaConfig)
				local relic = require(Server.RelicService)
				local preset = { "leaf_hero", "leaf_avenger", "leaf_medic" } -- a preset trio (SeriesCatalog)
				local mixed = { "db_hero", "sea_captain", "ds_hero" } -- three series
				local p = newPlayer()
				for _, id in preset do
					wear(p, id, "side_chain")
				end
				for _, id in mixed do
					wear(p, id, "side_chain")
				end
				local function seconds(id, multi)
					return math.round(
						Stamina.Seconds(
							catalog.Get(id),
							multi * sidekick.StaminaMulti(p, id) * relic.Multi(p, id, "Stamina")
						) * 10
					) / 10
				end
				eq("bonus_fixture_preset", (gacha.TeamBonus(p, preset)), "Preset")
				eq("bonus_fixture_mixed", (gacha.TeamBonus(p, mixed)), nil)

				eq("bonus_main_mixed_set", gacha.SetTeam(p, mixed), true)
				eq("bonus_preset_join", S.Join(p), true)
				eq("bonus_preset_pick", S.SetTeam(p, preset), true)
				eq("bonus_preset_attribute", p:GetAttribute("BossTeamBonus"), "Preset:leaf")
				local want = seconds(preset[1], gacha.StaminaMulti(p, preset))
				near("bonus_preset_stamina", p:GetAttribute("BossTeamStamina1"), want)
				local bare = seconds(preset[1], gacha.StaminaMulti(p))
				flag("bonus_preset_stamina_raised", want > bare, want, "> " .. bare)
				local cruise = gacha.CruiseFor(p, preset[1], 1, preset)
				near("bonus_preset_cruise", p:GetAttribute("BossTeamCruise1"), cruise)
				local plain = gacha.CruiseFor(p, preset[1], 1)
				flag("bonus_preset_cruise_raised", cruise > plain, cruise, "> " .. plain)
				eq("bonus_preset_keeps_main_team", p:GetAttribute("Team"), table.concat(mixed, ","))
				S.Leave(p, "Left")
				eq("bonus_leave_clears", p:GetAttribute("BossTeamBonus"), nil)

				eq("bonus_main_preset_set", gacha.SetTeam(p, preset), true)
				eq("bonus_mixed_join", S.Join(p), true)
				eq("bonus_mixed_pick", S.SetTeam(p, mixed), true)
				eq("bonus_mixed_attribute_empty", p:GetAttribute("BossTeamBonus"), "")
				want = seconds(mixed[1], gacha.StaminaMulti(p, mixed))
				near("bonus_mixed_stamina", p:GetAttribute("BossTeamStamina1"), want)
				local boosted = seconds(mixed[1], gacha.StaminaMulti(p))
				flag("bonus_mixed_stamina_not_raised", want < boosted, want, "< " .. boosted)
				cruise = gacha.CruiseFor(p, mixed[1], 1, mixed)
				near("bonus_mixed_cruise", p:GetAttribute("BossTeamCruise1"), cruise)
				local mainCruise = gacha.CruiseFor(p, mixed[1], 1)
				flag("bonus_mixed_cruise_not_raised", cruise < mainCruise, cruise, "< " .. mainCruise)
				S.Leave(p, "Left")
			end)

			-- BOSS_EVENT_SPEC "Paid spawn": "Next event in m:ss" reads this attribute.
			serviceSection("next_at_published", function()
				local function published()
					return ReplicatedStorage:GetAttribute("BossEventNextAt")
				end
				eq("next_at_after_reset", published(), T0 + Cfg.IntervalSeconds)
				eq("next_at_matches_state", published(), S.State().NextAt)
				begin()
				eq("next_at_kept_in_event", published(), S.State().NextAt)
				S.End("Timeout")
				to(Cfg.IntervalSeconds)
				eq("next_at_moves_on", published(), T0 + 2 * Cfg.IntervalSeconds)
				eq("next_at_still_matches_state", published(), S.State().NextAt)
			end)

			serviceSection("auto_team", function()
				local p = newPlayer()
				for _, id in chars do
					gacha.Grant(p, id)
				end
				-- Two characters of different cruise, and three others.
				local low, high = chars[1], nil
				for _, id in chars do
					if gacha.CruiseFor(p, id) ~= gacha.CruiseFor(p, low) then
						high = id
						break
					end
				end
				flag("test_has_two_cruises", high ~= nil)
				if gacha.CruiseFor(p, low) > gacha.CruiseFor(p, high) then
					low, high = high, low
				end
				local others = {}
				for _, id in chars do
					if id ~= low and id ~= high then
						table.insert(others, id)
					end
				end
				local tieOnly = newPlayer()
				gacha.Grant(tieOnly, low)
				gacha.Grant(tieOnly, high)
				wear(tieOnly, low, "side_chain") -- the slower one first, so bag order cannot pass
				wear(tieOnly, high, "side_chain")
				flag("auto_ties_by_cruise", H.same(S.AutoTeam(tieOnly), { high, low }))

				wear(p, low, "side_chain")
				wear(p, others[1], "side_dogs")
				wear(p, high, "side_chain")
				wear(p, others[2], "side_knight")
				flag(
					"test_damage_ordered",
					damageOf("side_knight") > damageOf("side_dogs") and damageOf("side_dogs") > damageOf("side_chain")
				)
				local normal = p:GetAttribute("Team")
				flag("auto_by_damage_then_cruise_max_3", H.same(S.AutoTeam(p), { others[2], others[1], high }))
				eq("auto_team_sets_nothing", p:GetAttribute("Team"), normal)
				eq("auto_team_no_sidekick_empty", #S.AutoTeam(newPlayer()), 0)

				-- After 1:00 joiners get it, and a joiner cannot choose.
				begin()
				local first = fighter()
				S.Join(first)
				to(PREP + INTRO / 2)
				S.Join(p)
				flag("late_joiner_gets_auto_team", H.same(S.TeamOf(p), S.AutoTeam(p)))
				eq("late_joiner_cannot_choose", S.SetTeam(p, { low }), false)
				eq("intro_joiner_waits_for_run", log.Runs[p], nil)
				to(FIGHT)
				flag("intro_joiner_runs_at_intro_end", log.Runs[p] ~= nil)
				local after = newPlayer()
				wear(after, chars[1], "side_chain")
				to(FIGHT + 10)
				S.Join(after)
				flag("fight_joiner_runs_at_once", log.Runs[after] ~= nil)
				flag("fight_joiner_auto_team", H.same(S.TeamOf(after), { chars[1] }))
			end)

			serviceSection("damage", function()
				begin()
				local a, b = chars[1], chars[2]
				local p = newPlayer()
				wear(p, a, "side_knight")
				wear(p, b, "side_chain")
				local list = { damageOf("side_knight"), damageOf("side_chain") }
				local single = fighter()
				S.Join(p)
				S.Join(single)
				eq("record_hit_refused_in_prep", S.RecordHit(p), 0)
				eq("record_hit_refused_for_outsider", S.RecordHit(fighter()), 0)
				to(FIGHT)
				local run = log.Runs[p]
				-- The formula at several cruise values, from the characters' cruise and not what the run reports.
				run.TargetSpeed = 123
				for _, cruise in { 0, 200, 400, 800, 1600 } do
					withCruise(cruise, function()
						near("team_damage_at_" .. cruise, S.TeamDamage(p), (list[1] + list[2]) * Cfg.SpeedScale(cruise))
					end)
				end
				-- Only the server's number counts.
				run.TargetSpeed = 400
				local expected = hitOf(p, 1)
				local hp = S.State().Hp
				eq("hit_huge_slot_is_0", S.RecordHit(p, 1e9, "cheat"), 0)
				eq("hit_text_slot_is_0", S.RecordHit(p, "cheat"), 0)
				eq("hit_bad_slot_takes_no_hp", S.State().Hp, hp)
				near("hit_is_server_number", S.RecordHit(p, 1, 1e9, "cheat"), expected)
				near("hit_counts_to_player", S.DamageOf(p), expected)
				near("hit_takes_hp", S.State().Hp, hp - expected)
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local clientHit = false
				for _, item in remotes and remotes:GetChildren() or {} do
					local name = string.lower(item.Name)
					-- BossHits is exempt by exact name: server-to-client only, clients read it to draw (checked below).
					clientHit = clientHit
						or (
							item.Name ~= "BossHits"
							and string.find(name, "boss", 1, true)
							and (string.find(name, "hit", 1, true) or string.find(name, "damage", 1, true))
						)
				end
				flag("no_remote_deals_damage", not clientHit)
				local hitsRemote = remotes and remotes:FindFirstChild("BossHits")
				flag("boss_hits_is_remote_event", hitsRemote ~= nil and hitsRemote:IsA("RemoteEvent"))
				local hpBefore = S.State().Hp
				near("hit_after_boss_hits_is_server_number", S.RecordHit(p, 1, 1e9, "cheat"), expected)
				near("hit_after_boss_hits_takes_server_hp", S.State().Hp, hpBefore - expected)
				-- Source is not readable in every context; only checked where it is.
				local readable, source = pcall(function()
					return Server.BossEventService.Source
				end)
				if readable and type(source) == "string" and source ~= "" then
					flag("boss_hits_no_server_listener", not string.find(source, "OnServerEvent", 1, true))
				end
			end)

			serviceSection("hit_cadence", function()
				begin()
				local p = fighter()
				S.Join(p)
				walk(FIGHT)
				local run = log.Runs[p]
				local one = S.TeamDamage(p)
				walk(FIGHT + EVERY - STEP)
				eq("no_hit_before_first", S.DamageOf(p), 0)
				walk(FIGHT + EVERY)
				near("first_hit_one_interval_in", S.DamageOf(p), one)
				walk(FIGHT + 3 * EVERY)
				near("hits_at_cadence", S.DamageOf(p), 3 * one)
				-- Exhausted: no damage in the wait, nothing owed for it afterward.
				run.Waiting = true
				walk(FIGHT + 3 * EVERY + 5)
				near("no_damage_while_waiting", S.DamageOf(p), 3 * one)
				eq("record_hit_refused_while_waiting", S.RecordHit(p), 0)
				run.Waiting = false
				local afterWait = clock - T0
				walk(afterWait + EVERY)
				near("no_catch_up_after_wait", S.DamageOf(p), 4 * one)
				-- A large step deals the hits due, not one.
				local before = S.DamageOf(p)
				to(afterWait + 5 * EVERY)
				near("big_step_deals_all_due", S.DamageOf(p), before + 4 * one)
				-- A late joiner's clock is its own.
				local late = fighter()
				to(100)
				S.Join(late)
				walk(100 + EVERY - STEP)
				eq("late_no_hit_before_first", S.DamageOf(late), 0)
				walk(100 + EVERY)
				near("late_first_hit", S.DamageOf(late), S.TeamDamage(late))
			end)

			-- Owner 2026-11-05 (design doc 4.37, spec "Run rules"). Real runs from RaceService.NewRun; the 1e6 s seam makes the
			-- run's own drain too small to see, so every change below is the attack's. Times are seconds into the event.
			serviceSection("attack_stamina", function()
				local Poses = require(Shared.BossRagaPoses)
				local race = require(Server.RaceService)
				local factory = require(Shared.RunnerFactory)
				local Arena = require(Shared.BossArenaConfig)
				if type(S.AttackImpactsBetween) ~= "function" then
					flag("impacts_function_exists", false)
					return
				end
				local COST = Cfg.Stage(1).AttackStaminaCost
				-- Any undodged move leaves its player Vulnerable, so every impact but a run's first costs this.
				local HEAVY = COST * Cfg.VulnerableMulti
				local MARGIN = 0.01 -- s either side of an impact the scan found, which is rounded to 3 places

				-- Impact times, seconds since the spawn, read off the shared schedule and not from the service.
				local impactAt = Poses.Moves.attack.Events[1].Time
				eq("attack_event_is_impact", Poses.Moves.attack.Events[1].Name, "Impact")
				local CYCLE = Poses.CycleSeconds
				local impacts, gapMoves, perCycle = {}, {}, 0
				local lastName, lastLocal = nil, 0
				for k = 0, math.ceil(2 * CYCLE / 0.01) do
					local t = INTRO + k * 0.01
					local name, localTime = Poses.Schedule(0, t)
					if
						name == "attack"
						and localTime >= impactAt
						and (lastName ~= "attack" or lastLocal < impactAt)
					then
						table.insert(impacts, math.round((t - (localTime - impactAt)) * 1000) / 1000)
						perCycle += impacts[#impacts] < INTRO + CYCLE and 1 or 0
					end
					gapMoves[#impacts] = gapMoves[#impacts] or {}
					gapMoves[#impacts][name] = true
					lastName, lastLocal = name, localTime
				end
				flag("scan_finds_impacts", #impacts >= 6, #impacts, 6)
				local FIRST = impacts[1]
				local function at(i)
					return PREP + impacts[i]
				end

				-- The pure count: fromT < impact <= toT, in seconds since the spawn. No event is running here.
				local count = S.AttackImpactsBetween
				eq("impacts_none_in_the_rise", count(0, INTRO), 0)
				eq("impacts_none_before_the_spawn", count(-100, INTRO), 0)
				eq("impacts_first_counted_on_its_moment", count(INTRO, FIRST), 1)
				eq("impacts_first_not_counted_again", count(FIRST, FIRST + MARGIN), 0)
				eq("impacts_empty_span", count(FIRST, FIRST), 0)
				eq("impacts_reversed_span", count(FIRST + 1, FIRST - 1), 0)
				eq("impacts_one_cycle", count(INTRO, INTRO + CYCLE), perCycle)
				eq("impacts_ten_cycles", count(INTRO, INTRO + 10 * CYCLE), 10 * perCycle)
				eq("impacts_same_when_asked_again", count(INTRO, INTRO + CYCLE), perCycle)
				-- perCycle is one per attack: wheel turn and shout, which play in the gaps, add none.
				local quiet, wheel, shout = true, false, false
				for i = 1, #impacts - 1 do
					quiet = quiet and count(impacts[i] + MARGIN, impacts[i + 1] - MARGIN) == 0
					wheel = wheel or gapMoves[i].wheel_turn == true
					shout = shout or gapMoves[i].shout == true
				end
				flag("impacts_none_between_attacks", quiet)
				flag("scan_gaps_hold_wheel_and_shout", wheel and shout)

				local kinds = {}
				local function newRun(p, team, lane)
					local car = factory.build(team[1])
					car.Name, car.Parent = "CarTestBossRunner", p
					kinds[p] = {}
					local run = race.NewRun(car, { Path = Arena.LaneRoute(lane), Pads = {}, Tracks = {} }, p, {
						Boss = true,
						Team = team,
						StaminaSeconds = { 1e6, 1e6, 1e6 },
						OnRunEvent = function(event)
							table.insert(kinds[p], event.Kind)
						end,
					})
					table.insert(liveRuns, run)
					return run
				end
				local function beginReal()
					begin()
					-- Three characters hit every 0.5 s between them: muted, so a hit never shares a frame with an impact's checks.
					S.Hooks.DamageMulti = function()
						return 0
					end
					S.Hooks.StartRun = function(p, team, lane)
						local run = newRun(p, team, lane)
						log.Runs[p] = run
						return run
					end
				end
				local function teamOf(n)
					local p = newPlayer()
					for i = 1, n do
						wear(p, chars[i], "side_knight")
					end
					return p
				end
				local function close(name, actual, expected)
					flag(name, type(actual) == "number" and math.abs(actual - expected) < 0.05, actual, expected)
				end
				local function kindCount(p, kind)
					local n = 0
					for _, seen in kinds[p] do
						n += seen == kind and 1 or 0
					end
					return n
				end

				-- Each impact once, every slot in the line, and no damage to the boss.
				beginReal()
				local p = teamOf(3)
				eq("stamina_join_ok", S.Join(p), true)
				walk(FIGHT)
				local run = log.Runs[p]
				if not run then
					flag("stamina_run_started", false)
					return
				end
				walk(at(1) - STEP)
				close("full_before_first_impact", run.Stamina[1], 100)
				local hp, dealt = S.State().Hp, S.DamageOf(p)
				to(at(1))
				close("first_impact_costs_plain", run.Stamina[1], 100 - COST)
				close("line_slot_2_pays_too", run.Stamina[2], 100 - COST)
				close("line_slot_3_pays_too", run.Stamina[3], 100 - COST)
				eq("impact_no_boss_damage", S.State().Hp, hp)
				eq("impact_no_player_damage", S.DamageOf(p), dealt)
				eq("impact_keeps_slot", run.Slot, 1)
				eq("impact_no_wait", run.Waiting, false)
				S.Advance(clock)
				S.Advance(clock)
				close("advance_twice_no_double_hit", run.Stamina[1], 100 - COST)
				walk(at(2) - MARGIN)
				close("wheel_and_shout_cost_nothing", run.Stamina[1], 100 - COST)
				to(at(2) + MARGIN)
				close("second_impact_costs_heavy", run.Stamina[1], 100 - COST - HEAVY)
				to(at(4) + MARGIN)
				close("long_frame_counts_each_impact", run.Stamina[1], 100 - COST - 3 * HEAVY)
				run.Stamina[1] = 50
				to(at(5) + MARGIN)
				close("cost_is_of_a_full_bar", run.Stamina[1], 50 - HEAVY)

				-- One long first frame, from the preparation to past two impacts.
				beginReal()
				local caught = teamOf(1)
				S.Join(caught)
				to(at(2) + MARGIN)
				close("catch_up_from_prep_counts_each", log.Runs[caught].Stamina[1], 100 - COST - HEAVY)

				-- Under the cost goes to 0; that slot then leaves the line, by BossGone and not by Swap.
				beginReal()
				local low = teamOf(3)
				S.Join(low)
				to(FIGHT)
				local lowRun = log.Runs[low]
				lowRun.Stamina[1] = 3
				to(at(1))
				eq("under_cost_goes_to_0", lowRun.Stamina[1], 0)
				flag(
					"zero_front_moves_as_normal",
					waitFor(1, function()
						return lowRun.Slot == 2
					end)
				)
				eq("zero_one_gone", kindCount(low, "BossGone"), 1)
				eq("zero_no_swap", kindCount(low, "Swap"), 0)
				close("next_in_line_paid_the_same_impact", lowRun.Stamina[2], 100 - COST)
				to(at(2) + MARGIN)
				close("next_impact_costs_new_front", lowRun.Stamina[2], 100 - COST - HEAVY)
				close("next_impact_costs_rest_of_line", lowRun.Stamina[3], 100 - COST - HEAVY)
				eq("gone_slot_kept_at_0", lowRun.Stamina[1], 0)

				-- One impact that empties every slot: all gone in a frame, one wait.
				beginReal()
				local wiped = teamOf(3)
				S.Join(wiped)
				to(FIGHT)
				local wipedRun = log.Runs[wiped]
				for slot = 1, 3 do
					wipedRun.Stamina[slot] = 3
				end
				to(at(1))
				flag(
					"zero_all_wait_once_gone",
					waitFor(1, function()
						return wipedRun.Waiting == true
					end)
				)
				eq("zero_all_three_gone", kindCount(wiped, "BossGone"), 3)
				eq("zero_all_one_wait", kindCount(wiped, "BossWait"), 1)
				eq("zero_all_no_swap", kindCount(wiped, "Swap"), 0)

				-- reading_: two impacts in one frame fall on the line of that frame; a slot's spare cost moves on to nobody.
				beginReal()
				local over = teamOf(3)
				S.Join(over)
				to(FIGHT)
				log.Runs[over].Stamina[1] = 7
				to(at(2) + MARGIN)
				eq("reading_catch_up_floors_at_0", log.Runs[over].Stamina[1], 0)
				close("reading_catch_up_next_slot_pays_its_own", log.Runs[over].Stamina[2], 100 - COST - HEAVY)

				-- The last character at 0 means the wait, never a cash-out.
				beginReal()
				local solo = teamOf(1)
				S.Join(solo)
				to(FIGHT)
				local soloRun = log.Runs[solo]
				soloRun.Stamina[1] = 3
				to(at(1))
				flag(
					"zero_waits_as_normal",
					waitFor(1, function()
						return soloRun.Waiting == true
					end)
				)
				eq("zero_wait_once", kindCount(solo, "BossWait"), 1)
				eq("zero_never_exhausted", kindCount(solo, "Exhausted"), 0)
				flag("zero_run_alive", soloRun.Connection ~= nil and S.IsIn(solo))

				-- A team in the wait loses nothing, then or afterward. No yield while Waiting is set by hand: the run cannot see it.
				beginReal()
				local waiter = teamOf(1)
				S.Join(waiter)
				to(FIGHT)
				local waitRun = log.Runs[waiter]
				waitRun.Stamina[1] = 40
				waitRun.Waiting = true
				to(at(1))
				close("wait_loses_nothing", waitRun.Stamina[1], 40)
				waitRun.Waiting = false
				S.Advance(clock)
				close("wait_owes_nothing_afterward", waitRun.Stamina[1], 40)
				to(at(2) + MARGIN)
				close("after_wait_next_impact_costs", waitRun.Stamina[1], 40 - HEAVY) -- the moves after the wait hit

				-- Every running member, each on their own; outsiders and later joiners are apart from it.
				beginReal()
				local a, b = teamOf(1), teamOf(1)
				local outsider = teamOf(1)
				S.Join(a)
				S.Join(b)
				local outsiderRun = newRun(outsider, { chars[1] }, Arena.Lanes)
				to(at(1))
				close("every_member_a_pays", log.Runs[a].Stamina[1], 100 - COST)
				close("every_member_b_pays", log.Runs[b].Stamina[1], 100 - COST)
				local onImpact = teamOf(1)
				S.Join(onImpact)
				S.Advance(clock)
				close("joiner_on_the_impact_pays_nothing", log.Runs[onImpact].Stamina[1], 100)
				to(at(1) + STEP)
				local later = teamOf(1)
				S.Join(later)
				S.Advance(clock)
				close("late_joiner_skips_past_impacts", log.Runs[later].Stamina[1], 100)
				to(at(2) + MARGIN)
				close("member_pays_both", log.Runs[a].Stamina[1], 100 - COST - HEAVY)
				close("joiner_on_the_impact_pays_later_one", log.Runs[onImpact].Stamina[1], 100 - HEAVY)
				close("late_joiner_pays_later_one", log.Runs[later].Stamina[1], 100 - HEAVY)
				close("outsider_unaffected", outsiderRun.Stamina[1], 100)
				outsiderRun:Destroy()

				-- A Roar and a WheelClick just before a join leave the joiner no status; a move after the join hits as normal.
				local BossDodge = require(Shared.BossDodge)
				local HttpService = game:GetService("HttpService")
				local SECONDS = Cfg.Stage(1).StatusSeconds
				local lastRoar, lastClick, lastIndex, joinAt = nil, nil, nil, nil
				local index = 0
				while index < 200 and not joinAt do
					index += 1
					local momentAt, name = BossDodge.Moment(index)
					lastRoar = name == "Roar" and momentAt or lastRoar
					lastClick = name == "WheelClick" and momentAt or lastClick
					local candidate = momentAt + INTRO + STEP
					if
						lastRoar
						and lastClick
						and (name == "Roar" or name == "WheelClick")
						and candidate < math.min(lastRoar, lastClick) + INTRO + SECONDS
					then
						joinAt, lastIndex = candidate, index
					end
				end
				flag("late_joiner_status_window_found", joinAt ~= nil and PREP + joinAt < CLOSE, joinAt, CLOSE - PREP)
				if not joinAt then
					S.Reset(T0)
					return
				end
				local function nextMoment(eventName)
					for i = lastIndex + 1, lastIndex + 200 do
						local momentAt, name = BossDodge.Moment(i)
						if name == eventName then
							return momentAt + INTRO
						end
					end
					return nil
				end
				local function statusRow(p, id)
					local raw = p:GetAttribute("BossStatus")
					for _, row in raw and HttpService:JSONDecode(raw) or {} do
						if row.Id == id then
							return row
						end
					end
					return nil
				end
				-- A fresh event with a member from the start, then the joiner. Automatic hits stay muted; each check turns the real hook on.
				local function lateJoiner()
					beginReal()
					local seen, live = {}, false
					S.Hooks.DamageMulti = function(t, spared, stage)
						seen.T, seen.Spared = t, spared
						return live and realHooks.DamageMulti(t, spared, stage) or 0
					end
					local early = teamOf(1)
					S.Join(early)
					to(PREP + joinAt)
					local p = teamOf(1)
					S.Join(p)
					S.Advance(clock)
					return p,
						early,
						seen,
						function()
							live = true
							local dealt = S.RecordHit(p)
							live = false
							return dealt
						end
				end

				local joiner, early, seen, realHit = lateJoiner()
				flag("late_joiner_control_early_member_shouted", statusRow(early, "Shouted") ~= nil)
				flag("late_joiner_control_early_member_adapted", statusRow(early, "Adapted") ~= nil)
				eq("late_joiner_not_shouted", statusRow(joiner, "Shouted"), nil)
				eq("late_joiner_not_adapted", statusRow(joiner, "Adapted"), nil)
				eq("late_joiner_not_vulnerable", statusRow(joiner, "Vulnerable"), nil)
				near("late_joiner_full_damage", realHit(), S.TeamDamage(joiner))
				eq("late_joiner_multi_is_1", realHooks.DamageMulti(seen.T, seen.Spared, 1), 1)

				-- Fresh events, as the two later moves can fall in either order.
				for _, case in { { "Roar", "Shouted" }, { "WheelClick", "Adapted" } } do
					local tag = "late_joiner_later_" .. case[1] .. "_"
					local p, _, seenLater, hit = lateJoiner()
					local moveAt = nextMoment(case[1])
					to(PREP + moveAt + MARGIN)
					local row = statusRow(p, case[2])
					eq(tag .. "adds_one_stack", row and row.Count, 1)
					flag(tag .. "makes_vulnerable", statusRow(p, "Vulnerable") ~= nil)
					local dealt = hit()
					flag(tag .. "cuts_the_hit", dealt < S.TeamDamage(p), dealt, S.TeamDamage(p))
					flag(tag .. "multi_below_1", realHooks.DamageMulti(seenLater.T, seenLater.Spared, 1) < 1)
				end
				S.Reset(T0)
			end)

			-- Owner 2026-11-05 (spec "Run rules"): Shouted and Adapted, from the shared schedule. Times are seconds since the spawn.
			serviceSection("boss_status", function()
				local Poses = require(Shared.BossRagaPoses)
				local HttpService = game:GetService("HttpService")
				eq("status_shout_cut", Cfg.ShoutDamageCut, 0.25)
				eq("status_adapted_cut", Cfg.AdaptedCut, 0.1)
				local SECONDS = Cfg.Stage(1).StatusSeconds
				eq("status_seconds_stage_1", SECONDS, 15)
				if type(realHooks.DamageMulti) ~= "function" then
					flag("status_damage_hook_exists", false)
					return
				end
				-- Event moments off the schedule, not from the service.
				local function moments(moveName, eventName)
					local at, list, lastName, lastLocal = nil, {}, nil, 0
					for _, event in Poses.Moves[moveName].Events do
						if event.Name == eventName then
							at = event.Time
						end
					end
					for k = 0, math.ceil(3 * Poses.CycleSeconds / 0.01) do
						local t = INTRO + k * 0.01
						local name, localTime = Poses.Schedule(0, t)
						if name == moveName and localTime >= at and (lastName ~= moveName or lastLocal < at) then
							table.insert(list, math.round((t - (localTime - at)) * 1000) / 1000)
						end
						lastName, lastLocal = name, localTime
					end
					return list
				end
				local roars, clicks = moments("shout", "Roar"), moments("wheel_turn", "WheelClick")
				flag("status_scan_found", #roars >= 2 and #clicks >= 2, #roars, 2)
				local MARGIN = 0.02
				local function active(list, duration, t)
					for _, at in list do
						if at <= t and t < at + duration then
							return true
						end
					end
					return false
				end
				local function expected(t)
					return (active(roars, SECONDS, t) and 0.75 or 1) * (active(clicks, SECONDS, t) and 0.9 or 1)
				end
				-- A clear moment and a moment for each state, past the edges by MARGIN.
				local function findTime(wantShout, wantAdapted)
					for k = 0, math.ceil(3 * Poses.CycleSeconds / 0.05) do
						local t = INTRO + k * 0.05
						local same = true
						for _, probe in { t - MARGIN, t, t + MARGIN } do
							same = same
								and active(roars, SECONDS, probe) == wantShout
								and active(clicks, SECONDS, probe) == wantAdapted
						end
						if same then
							return t
						end
					end
					return nil
				end
				local both, shoutOnly, adaptedOnly = findTime(true, true), findTime(true, false), findTime(false, true)
				flag("status_scan_has_each_state", both ~= nil and shoutOnly ~= nil and adaptedOnly ~= nil)

				local holder = nil -- the member whose status is read
				local function beginHeld()
					begin()
					holder = fighter()
					S.Join(holder)
				end
				local function status()
					local raw = holder:GetAttribute("BossStatus")
					if raw == nil then
						return {}
					end
					local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
					return ok and decoded or { "bad json" }
				end
				local function statusOf(id)
					local found, n = nil, 0
					for _, row in status() do
						if row.Id == id then
							found, n = row, n + 1
						end
					end
					return found, n
				end

				-- Fresh event at each moment: the hit's number and the HP both take the cut.
				local function hitAt(tag, t, multi)
					begin()
					S.Hooks.DamageMulti = realHooks.DamageMulti
					local p = fighter()
					holder = p
					S.Join(p)
					to(t + PREP)
					local base, hp, before = S.TeamDamage(p), S.State().Hp, S.DamageOf(p)
					local dealt = S.RecordHit(p)
					near(tag .. "_dealt", dealt, base * multi)
					near(tag .. "_hp", hp - S.State().Hp, dealt)
					near(tag .. "_reward_share", S.DamageOf(p) - before, dealt)
					near(tag .. "_hud_number_not_cut", p:GetAttribute("BossTeamDamage"), base)
				end
				hitAt("status_none_at_intro_end", INTRO, 1)
				eq("status_list_empty_at_intro_end", #status(), 0)
				hitAt("status_shouted", shoutOnly, 0.75)
				eq("status_shouted_listed", (select(2, statusOf("Shouted"))), 1)
				eq("status_shouted_only", (select(2, statusOf("Adapted"))), 0)
				hitAt("status_adapted", adaptedOnly, 0.9)
				eq("status_adapted_listed", (select(2, statusOf("Adapted"))), 1)
				eq("status_adapted_only", (select(2, statusOf("Shouted"))), 0)
				hitAt("status_both", both, 0.75 * 0.9)
				-- Vulnerable has its own row beside these two.
				eq("status_both_listed", (select(2, statusOf("Shouted"))) + (select(2, statusOf("Adapted"))), 2)

				-- Edges and EndsAt, in server time, off the injected clock.
				beginHeld()
				S.Hooks.DamageMulti = realHooks.DamageMulti
				local spawnAt = T0 + PREP
				local roar, click = roars[1], clicks[1]
				to(PREP + roar - MARGIN)
				eq(
					"status_not_before_roar",
					(select(2, statusOf("Shouted"))),
					active(roars, SECONDS, roar - MARGIN) and 1 or 0
				)
				to(PREP + roar + MARGIN)
				local row = statusOf("Shouted")
				flag("status_roar_starts", row ~= nil)
				near(
					"status_shouted_ends_at",
					row and math.round(row.EndsAt * 100) / 100,
					math.round((spawnAt + roar + SECONDS) * 100) / 100
				)
				to(PREP + roar + SECONDS + MARGIN)
				eq(
					"status_shouted_expires",
					(select(2, statusOf("Shouted"))),
					active(roars, SECONDS, roar + SECONDS + MARGIN) and 1 or 0
				)
				beginHeld()
				S.Hooks.DamageMulti = realHooks.DamageMulti
				to(PREP + click + MARGIN)
				local adapted = statusOf("Adapted")
				near(
					"status_adapted_ends_at",
					adapted and math.round(adapted.EndsAt * 100) / 100,
					math.round((spawnAt + click + SECONDS) * 100) / 100
				)
				eq("status_row_counts_its_stack", adapted and adapted.Count, 1)
				S.Advance(clock)
				eq("status_one_row_a_status", (select(2, statusOf("Adapted"))), 1)
				adapted = statusOf("Adapted")
				eq("status_advance_adds_no_stack", adapted and adapted.Count, 1)
				to(PREP + click + SECONDS + MARGIN)
				eq(
					"status_adapted_expires",
					(select(2, statusOf("Adapted"))),
					active(clicks, SECONDS, click + SECONDS + MARGIN) and 1 or 0
				)

				-- The pure multiplier, every moment of the schedule, so a refresh (if the schedule ever gives one) is judged too.
				local worst = 0
				for k = 0, math.ceil(3 * Poses.CycleSeconds / 0.25) do
					local t = INTRO + k * 0.25 + 0.03
					if expected(t - MARGIN) == expected(t + MARGIN) then
						worst = math.max(worst, math.abs(realHooks.DamageMulti(t, nil, 1) - expected(t)))
					end
				end
				flag("status_multi_matches_schedule", worst < 1e-6, worst, 0)
				eq("status_multi_none_in_rise", realHooks.DamageMulti(INTRO / 2, nil, 1), 1)

				-- Nothing is left behind by the event's end.
				beginHeld()
				to(PREP + both)
				S.End("Timeout")
				eq("status_cleared_at_end", holder:GetAttribute("BossStatus"), nil)
			end)

			-- The Dodge bar (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Dodge bar"). Times are read off Shared/BossDodge.
			serviceSection("dodge", function()
				local BossDodge = require(Shared.BossDodge)
				local race = require(Server.RaceService)
				local factory = require(Shared.RunnerFactory)
				local Arena = require(Shared.BossArenaConfig)
				local HttpService = game:GetService("HttpService")

				-- Moments.
				local lastAt, shortest = 0, math.huge
				for index = 1, 24 do
					local at = BossDodge.Moment(index)
					eq("moment_index_round_trip_" .. index, BossDodge.IndexAtOrBefore(at + 1e-6), index) -- the service's own epsilon
					if index > 1 then
						shortest = math.min(shortest, at - lastAt)
					end
					lastAt = at
				end
				eq("moment_none_before_the_first", BossDodge.IndexAtOrBefore(BossDodge.Moment(1) - 0.01), 0)
				flag(
					"moments_leave_room_for_bar_and_text",
					shortest >= BossDodge.SweepSeconds + BossDodge.ResultSeconds,
					shortest
				)

				-- The spot: clear of the start, its window over well before the moment, different per moment and per player.
				local seen, lowest, latest = {}, 1, -math.huge
				for index = 1, 200 do
					local spot = BossDodge.Spot(1234, T0, index, 1)
					eq("spot_stable_" .. index, BossDodge.Spot(1234, T0, index, 1), spot)
					lowest = math.min(lowest, spot)
					seen[math.floor(spot * 20)] = true
					latest = math.max(latest, select(2, BossDodge.Window(spot, 0, 1)))
				end
				flag("spot_clear_of_start", lowest >= 0.2, lowest)
				flag("spot_window_ends_before_moment", latest <= -0.35, latest)
				local buckets = 0
				for _ in seen do
					buckets += 1
				end
				flag("spot_spread_over_the_bar", buckets >= 7, buckets)
				local differs = false
				for index = 1, 20 do
					differs = differs or BossDodge.Spot(1234, T0, index, 1) ~= BossDodge.Spot(5678, T0, index, 1)
				end
				flag("spot_differs_per_player", differs)

				-- Owner 2026-11-06: narrower spot, faster sweep in stage 2, centres bounded per stage.
				eq("spot_width", BossDodge.SpotWidth, 0.125)
				eq("sweep_stage_1", BossDodge.SweepFor(1), 1.5)
				eq("sweep_stage_2", BossDodge.SweepFor(2), 1.1)
				eq("sweep_seconds_is_stage_1", BossDodge.SweepSeconds, BossDodge.SweepFor(1))
				local spans =
					{ { Low = 0.25, High = 0.69, Latest = -0.35 }, { Low = 0.25, High = 0.62, Latest = -0.349 } }
				for stage, span in spans do
					local low, high, ends = 1, 0, -math.huge
					for index = 1, 200 do
						local spot = BossDodge.Spot(1234, T0, index, stage)
						low, high = math.min(low, spot), math.max(high, spot)
						ends = math.max(ends, select(2, BossDodge.Window(spot, 0, stage)))
					end
					flag("spot_range_low_stage_" .. stage, low >= span.Low, low, span.Low)
					flag("spot_range_high_stage_" .. stage, high <= span.High, high, span.High)
					-- 0.349 in stage 2: at the centre 0.62 the window ends 0.34925 s before the moment.
					flag("spot_window_clear_stage_" .. stage, ends <= span.Latest, ends, span.Latest)
					local from, till = BossDodge.Window(0.5, 0, stage)
					near("window_width_stage_" .. stage, till - from, BossDodge.SpotWidth * BossDodge.SweepFor(stage))
				end

				begin()
				local lanes = {}
				S.Hooks.SwitchLane = function(_, lane)
					table.insert(lanes, lane)
				end
				S.Hooks.DamageMulti = realHooks.DamageMulti
				local a, b = fighter(), fighter()
				S.Join(a)
				S.Join(b)
				eq("dodge_a_in_lane_1", S.LaneOf(a), 1)
				eq("dodge_b_in_lane_2", S.LaneOf(b), 2)
				local function momentT(index)
					return FIGHT + BossDodge.Moment(index) -- on the test's event clock
				end
				local function windowOf(p, index)
					local id = p:GetAttribute("UserId") or 0
					return BossDodge.Window(BossDodge.Spot(id, T0, index, 1), T0 + momentT(index), 1)
				end
				local function middle(p, index)
					local from, to = windowOf(p, index)
					return (from + to) / 2
				end
				-- Advance to the press's own time, then press with that stamp.
				local function pressAt(p, index, stamp, arrives)
					to((arrives or stamp) - T0)
					return S.Dodge(p, index, stamp)
				end
				local function statusIds(p)
					local ids = {}
					for _, row in HttpService:JSONDecode(p:GetAttribute("BossStatus") or "[]") do
						ids[row.Id] = true
					end
					return ids
				end
				local function linesTo(p)
					local n = 0
					for _, line in log.MoveChat do
						n += line.Player == p and 1 or 0
					end
					return n
				end
				walk(FIGHT)
				local runA, runB = log.Runs[a], log.Runs[b]

				-- Moment 1, the attack: a dodges. Neither its stamina nor its chat is touched; b pays. Lane 1's only neighbour is taken.
				eq("dodge_moment_1_is_impact", select(2, BossDodge.Moment(1)), "Impact")
				eq("dodge_before_the_bar_refused", S.Dodge(a, 1, clock), false)
				eq("dodge_on_spot_ok", pressAt(a, 1, middle(a, 1)), true)
				eq("dodge_lane_neighbour_shared_when_only_choice", S.LaneOf(a), 2)
				eq("dodge_switch_hook_called", lanes[1], 2)
				eq("dodge_second_press_refused", S.Dodge(a, 1, clock), false)
				to(momentT(1) + 0.05)
				eq("dodged_impact_costs_nothing", runA.Stamina[1], 100)
				eq("hit_impact_costs_stamina", runB.Stamina[1], 100 - Cfg.Stage(1).AttackStaminaCost)
				eq("dodged_move_no_chat", linesTo(a), 0)
				eq("hit_move_chat", linesTo(b), 1)

				-- Moment 2, the wheel turn: a presses early and is hit, and its one press is spent.
				eq("dodge_moment_2_is_wheel", select(2, BossDodge.Moment(2)), "WheelClick")
				local early = windowOf(a, 2) - 0.1
				eq("dodge_off_spot_refused", pressAt(a, 2, early), false)
				eq("dodge_off_spot_spends_the_press", pressAt(a, 2, middle(a, 2)), false)
				to(momentT(2) + 0.05)
				eq("off_spot_is_hit_adapted", statusIds(a).Adapted, true)
				eq("off_spot_lane_unchanged", S.LaneOf(a), 2)

				-- Moment 3, the shout: a dodges, b does not, so their statuses and their hits differ (owner 2026-11-05).
				eq("dodge_moment_3_is_roar", select(2, BossDodge.Moment(3)), "Roar")
				eq("dodge_roar_ok", pressAt(a, 3, middle(a, 3)), true)
				flag("dodge_lane_is_a_neighbour", math.abs(S.LaneOf(a) - 2) == 1, S.LaneOf(a))
				to(momentT(3) + 0.05)
				eq("dodged_shout_not_listed", statusIds(a).Shouted, nil)
				eq("hit_shout_listed", statusIds(b).Shouted, true)
				local baseA, baseB = S.TeamDamage(a), S.TeamDamage(b)
				near("dodger_hit_keeps_damage", S.RecordHit(a), baseA * (1 - Cfg.AdaptedCut))
				near("hit_player_damage_cut", S.RecordHit(b), baseB * (1 - Cfg.AdaptedCut) * (1 - Cfg.ShoutDamageCut))

				-- Moment 4: a stamp in the window, too old on arrival. Moment 5: arriving after the moment.
				local from4 = windowOf(a, 4)
				eq("dodge_stale_stamp_refused", pressAt(a, 4, from4, from4 + 0.52), false)
				local stamp5 = middle(a, 5)
				to(momentT(5) + 0.01)
				eq("dodge_after_the_moment_refused", S.Dodge(a, 5, stamp5), false)

				-- Bad input from a client.
				for _, bad in { "1", 0, -1, 1.5, math.huge, 0 / 0 } do
					eq("dodge_bad_index_" .. tostring(bad), S.Dodge(a, bad, clock), false)
				end
				eq("dodge_bad_stamp_text", S.Dodge(a, 6, "x"), false)
				eq("dodge_bad_stamp_nan", S.Dodge(a, 6, 0 / 0), false)
				eq("dodge_outsider_refused", S.Dodge(fighter(), 6, clock), false)

				-- Moment 6, the attack, in the wait: no press, no cost, no line.
				eq("dodge_moment_6_is_impact", select(2, BossDodge.Moment(6)), "Impact")
				local stamina, heard = runA.Stamina[runA.Slot], linesTo(a)
				runA.Waiting = true
				eq("dodge_in_wait_refused", pressAt(a, 6, middle(a, 6)), false)
				to(momentT(6) + 0.05)
				runA.Waiting = false
				eq("wait_move_costs_nothing", runA.Stamina[runA.Slot], stamina)
				eq("wait_move_no_chat", linesTo(a), heard)
				S.End("Timeout")
				eq("dodge_status_cleared_at_end", a:GetAttribute("BossStatus"), nil)

				-- The real run: the same lap angle on the new lane's route, published for clients.
				local player = newPlayer()
				wear(player, chars[1], "side_knight")
				local car = factory.build(chars[1])
				car.Name, car.Parent = "CarTestBossRunner", player
				local run = race.NewRun(
					car,
					{ Path = Arena.LaneRoute(2), Pads = {}, Tracks = {} },
					player,
					{ Boss = true, Team = { chars[1] }, StaminaSeconds = { 1e6, 1e6, 1e6 } }
				)
				table.insert(liveRuns, run)
				task.wait(0.3)
				local function radiusOf()
					return (car:GetPivot().Position - Arena.Center) * Vector3.new(1, 0, 1)
				end
				local before = radiusOf()
				local routeBefore = car:GetAttribute("RunRoute")
				local distBefore = car:GetAttribute("RunDistance")
				run:SwitchRoute(Arena.LaneRoute(3))
				local after = radiusOf()
				flag("switch_radius_new_lane", math.abs(after.Magnitude - Arena.LaneRadius(3)) < 3, after.Magnitude)
				flag("switch_same_lap_angle", before.Unit:Dot(after.Unit) > 0.999, before.Unit:Dot(after.Unit))
				flag("switch_publishes_route", car:GetAttribute("RunRoute") ~= routeBefore)
				flag("switch_distance_scaled", car:GetAttribute("RunDistance") >= distBefore)
				task.wait(0.2)
				flag(
					"switch_stays_on_new_lane",
					math.abs(radiusOf().Magnitude - Arena.LaneRadius(3)) < 3,
					radiusOf().Magnitude
				)
				run:Destroy()
			end)

			serviceSection("hp", function()
				begin()
				local players = {}
				for i = 1, 7 do
					players[i] = fighter()
				end
				for i = 1, 3 do
					S.Join(players[i])
					eq("prep_max_grows_" .. i, S.State().MaxHp, i * HP)
					eq("prep_current_grows_" .. i, S.State().Hp, i * HP)
				end
				to(PREP + INTRO / 2)
				S.Join(players[4])
				eq("intro_join_grows_max", S.State().MaxHp, 4 * HP)
				to(FIGHT)
				for i = 1, 4 do
					log.Runs[players[i]].TargetSpeed = 0
				end
				S.RecordHit(players[1])
				local dealt = S.DamageOf(players[1])
				flag("test_damage_dealt", dealt > 0, dealt)
				to(100)
				local hurt = S.State().Hp
				S.Join(players[5])
				S.Join(players[6])
				S.Join(players[7])
				eq("joiner_grows_max", S.State().MaxHp, 7 * HP)
				near("joiner_grows_current_by_hp_each", S.State().Hp, hurt + 3 * HP)
				eq("state_counts_players", S.State().Players, 7)
				-- 7 lanes, one each
				local lanes = {}
				for _, p in players do
					local lane = S.LaneOf(p)
					flag("lane_in_range_" .. tostring(lane), type(lane) == "number" and lane >= 1 and lane <= 7)
					flag("lane_not_shared_" .. tostring(lane), not lanes[lane])
					lanes[lane or 0] = true
				end
				eq("reading_8th_player_refused", S.Join(fighter()), false)
				eq("reading_8th_adds_no_hp", S.State().MaxHp, 7 * HP)
				-- Locked from 3:00
				to(CLOSE)
				local maxAt, hpAt = S.State().MaxHp, S.State().Hp
				S.Leave(players[7], "Left")
				eq("leaver_after_lock_keeps_max", S.State().MaxHp, maxAt)
				near("leaver_after_lock_keeps_current", S.State().Hp, hpAt)
				eq("rejoin_after_lock_refused", S.Join(players[7]), false)
				eq("joiner_after_lock_keeps_max", S.State().MaxHp, maxAt)
				S.Leave(players[6], "Death")
				eq("death_after_lock_keeps_max", S.State().MaxHp, maxAt)
			end)

			serviceSection("reading_leave_before_lock", function()
				begin()
				local a, b, c = fighter(), fighter(), fighter()
				S.Join(a)
				S.Join(b)
				S.Join(c)
				S.Leave(c, "Left")
				eq("reading_leave_before_lock_lowers_max", S.State().MaxHp, 2 * HP)
				flag("reading_leave_current_within_max", S.State().Hp <= S.State().MaxHp and S.State().Hp > 0)
				near("reading_leave_before_lock_lowers_current", S.State().Hp, 2 * HP)
				local d = fighter()
				S.Join(d)
				eq("reading_leave_frees_a_place", S.State().Players, 3)
				to(FIGHT)
				-- Under one player's HP left, then a leave: leaving must not defeat the boss.
				for _ = 1, 10000 do
					if S.State().Hp <= HP / 2 or not S.IsIn(a) then
						break
					end
					S.RecordHit(a)
				end
				flag("test_boss_hurt", S.State().Hp <= HP / 2 and S.IsIn(a), S.State().Hp, HP / 2)
				S.Leave(d, "Left")
				flag("reading_leave_never_defeats", phase() == "Fight" and S.State().Hp > 0, S.State().Hp)
			end)

			-- BOSS_EVENT_SPEC 1:00-3:00: a leaver before 3:00 removes 4,000 from both, never below 1 current HP.
			serviceSection("leave_never_heals", function()
				begin()
				local a, b = fighter(), fighter()
				S.Join(a)
				S.Join(b)
				to(FIGHT)
				flag("test_hurt_first_hit", S.RecordHit(a) > 0)
				local hurt, max = S.State().Hp, S.State().MaxHp
				flag("test_hurt_is_hurt", hurt < max and hurt > HP, hurt, max)
				local visitor = fighter()
				S.Join(visitor)
				S.Leave(visitor, "Left")
				near("join_leave_same_hp", S.State().Hp, hurt)
				eq("join_leave_same_max", S.State().MaxHp, max)
				S.Leave(b, "Left")
				near("leave_takes_hp_from_current", S.State().Hp, hurt - HP)
				eq("leave_takes_hp_from_max", S.State().MaxHp, max - HP)

				-- Under 4,000 left: the floor of 1, and a join then leave still changes nothing.
				begin()
				a, b = fighter(), fighter()
				S.Join(a)
				S.Join(b)
				to(FIGHT)
				for _ = 1, 10000 do
					if S.State().Hp <= HP / 2 or not S.IsIn(a) then
						break
					end
					S.RecordHit(a)
				end
				local low = S.State().Hp
				flag("test_low_boss", low <= HP / 2 and low > 1 and S.IsIn(a), low, HP / 2)
				visitor = fighter()
				S.Join(visitor)
				S.Leave(visitor, "Left")
				near("low_join_leave_same_hp", S.State().Hp, low)
				eq("low_join_leave_same_max", S.State().MaxHp, 2 * HP)
				S.Leave(b, "Left")
				eq("low_leave_floor_of_1", S.State().Hp, 1)
				eq("low_leave_lowers_max", S.State().MaxHp, HP)
				to(FIGHT + 1)
				eq("low_leave_never_defeats", phase(), "Fight")
				eq("low_leave_no_end", S.State().LastEnd, nil)
				visitor = fighter()
				S.Join(visitor)
				S.Leave(visitor, "Left")
				eq("floor_join_leave_same_hp", S.State().Hp, 1)
				eq("floor_join_leave_same_max", S.State().MaxHp, HP)

				-- An arena emptied in preparation holds no leftover: the next joiner has exactly one player's HP.
				begin()
				local solo = fighter()
				S.Join(solo)
				S.Leave(solo, "Left")
				local next = fighter()
				S.Join(next)
				eq("emptied_prep_rejoin_max", S.State().MaxHp, HP)
				near("emptied_prep_rejoin_hp", S.State().Hp, HP)

				-- Emptied mid-fight: the next joiner's bar is still valid.
				begin()
				solo = fighter()
				S.Join(solo)
				to(FIGHT)
				S.RecordHit(solo)
				S.Leave(solo, "Left")
				next = fighter()
				S.Join(next)
				eq("emptied_fight_rejoin_max", S.State().MaxHp, HP)
				flag("emptied_fight_rejoin_hp_valid", S.State().Hp > 0 and S.State().Hp <= HP, S.State().Hp, HP)
			end)

			serviceSection("rewards_list", function()
				begin()
				local big, exact, under, none = fighter(), newPlayer(), newPlayer(), newPlayer()
				-- A Sidekick whose damage divides the 4-player threshold, so "exactly the share" is reachable in whole hits.
				local wantNeed, evenSide = Cfg.MinDamageShare * 4 * HP, SidekickConfig.List[1]
				for _, row in SidekickConfig.List do
					if approx(wantNeed / row.Damage, math.round(wantNeed / row.Damage)) then
						evenSide = row
						break
					end
				end
				for _, p in { exact, under, none } do
					wear(p, chars[1], evenSide.Id)
				end
				for _, p in { big, exact, under, none } do
					S.Join(p)
				end
				to(FIGHT)
				-- The scale is the character's own now: statuses cancel it, so a hit is the Sidekick's whole number.
				local hit = evenSide.Damage
				local plainHit = hitOf(exact)
				S.Hooks.DamageMulti = function()
					return hit / plainHit
				end
				local need = Cfg.MinDamageShare * S.State().MaxHp
				local hits = math.ceil(need / hit - 1e-9)
				flag("test_threshold_is_whole_hits", approx(hits * hit, need), hits * hit, need)
				for _ = 1, hits do
					S.RecordHit(exact)
				end
				for _ = 1, hits - 1 do
					S.RecordHit(under)
				end
				kill(big)
				eq("rewards_on_defeat", S.State().Stage, 2)
				local list = paidIn(1)
				eq("rewards_hook_once", timesPaid(big, 1), 1)
				flag("rewards_top_damage_listed", table.find(list, big) ~= nil)
				flag("rewards_exactly_the_share_listed", table.find(list, exact) ~= nil)
				flag("rewards_below_the_share_not_listed", table.find(list, under) == nil)
				flag("rewards_no_damage_not_listed", table.find(list, none) == nil)
				eq("rewards_list_size", #list, 2)
				-- Damage is one event's: the next one starts at 0.
				begin()
				eq("damage_cleared_next_event", S.DamageOf(big), 0)
			end)

			serviceSection("autoroll_attribute", function()
				begin()
				local on, off = fighter(), fighter()
				on:SetAttribute("AutoRoll", true)
				off:SetAttribute("AutoRoll", false)
				eq("gate_clear_before", on:GetAttribute("BossEvent"), nil)
				S.Join(on)
				S.Join(off)
				eq("gate_set_on_join", on:GetAttribute("BossEvent"), true)
				eq("autoroll_on_kept_at_join", on:GetAttribute("AutoRoll"), true)
				eq("autoroll_off_kept_at_join", off:GetAttribute("AutoRoll"), false)
				walk(FIGHT + 3)
				eq("gate_set_in_fight", on:GetAttribute("BossEvent"), true)
				eq("autoroll_on_kept_in_fight", on:GetAttribute("AutoRoll"), true)
				eq("autoroll_off_kept_in_fight", off:GetAttribute("AutoRoll"), false)
				S.End("Timeout")
				eq("gate_cleared_after", on:GetAttribute("BossEvent"), nil)
				eq("gate_cleared_after_off", off:GetAttribute("BossEvent"), nil)
				eq("autoroll_on_kept_after", on:GetAttribute("AutoRoll"), true)
				eq("autoroll_off_kept_after", off:GetAttribute("AutoRoll"), false)
			end)

			serviceSection("return_paths", function()
				begin()
				local ender, leaver, dead, broken = fighter(), fighter(), fighter(), fighter()
				for _, p in { ender, leaver, dead, broken } do
					S.Join(p)
					flag("in_after_join", S.IsIn(p))
				end
				flag("arrive_got_lane", log.Arrive[ender] == S.LaneOf(ender))
				to(FIGHT)
				local leaverRun, deadRun, enderRun = log.Runs[leaver], log.Runs[dead], log.Runs[ender]

				S.Leave(leaver, "Left")
				eq("leave_out_of_event", S.IsIn(leaver), false)
				eq("leave_clears_gate", leaver:GetAttribute("BossEvent"), nil)
				eq("leave_stops_run", leaverRun.Destroyed, 1)
				eq("leave_no_more_damage", S.RecordHit(leaver), 0)
				local pcallOk = pcall(S.Leave, leaver, "Left")
				eq("leave_twice_safe", pcallOk, true)
				eq("leave_twice_stops_once", leaverRun.Destroyed, 1)

				S.Leave(dead, "Death")
				eq("death_out_of_event", S.IsIn(dead), false)
				eq("death_clears_gate", dead:GetAttribute("BossEvent"), nil)
				eq("death_stops_run", deadRun.Destroyed, 1)

				-- A return that throws must not strand the others, nor itself in the event.
				local realDepart = S.Hooks.Depart
				S.Hooks.Depart = function(p)
					realDepart(p)
					if p == broken then
						error("depart failed on purpose")
					end
				end
				-- A player who vanished without a Leave must not break the tick either.
				local gone = fighter()
				S.Join(gone)
				gone.Parent = nil
				clock = T0 + FIGHT + STEP
				eq("gone_player_tick_safe", (pcall(S.Advance, clock)), true)

				eq("end_safe_with_failing_return", (pcall(S.End, "Timeout")), true)
				eq("end_out_of_event", S.IsIn(ender), false)
				eq("end_clears_gate", ender:GetAttribute("BossEvent"), nil)
				eq("end_returns_once", log.Depart[ender], 1)
				eq("end_stops_run", enderRun.Destroyed, 1)
				eq("failing_return_out_of_event", S.IsIn(broken), false)
				eq("failing_return_clears_gate", broken:GetAttribute("BossEvent"), nil)
				eq("gone_player_out_after_end", S.IsIn(gone), false)
				flag("end_no_second_return_for_leaver", (log.Depart[leaver] or 0) <= 1, log.Depart[leaver] or 0, 1)
				flag("end_no_second_return_for_death", (log.Depart[dead] or 0) <= 1, log.Depart[dead] or 0, 1)
				eq("idle_after_end", phase(), "Idle")
			end)

			serviceSection("leave_option", function()
				begin()
				eq(
					"leave_works_in_prep",
					(function()
						local p = fighter()
						S.Join(p)
						S.Leave(p, "Left")
						return not S.IsIn(p) and p:GetAttribute("BossEvent") == nil and log.Depart[p] == 1
					end)(),
					true
				)
				eq("leave_in_prep_takes_hp_back", S.State().MaxHp, 0)

				-- Not in the event: harmless, in an event and with none.
				local stranger = fighter()
				local maxBefore, playersBefore = S.State().MaxHp, S.State().Players
				eq("leave_not_in_no_error", (pcall(S.Leave, stranger, "Left")), true)
				eq("leave_not_in_no_return", log.Depart[stranger], nil)
				eq("leave_not_in_no_gate", stranger:GetAttribute("BossEvent"), nil)
				eq("leave_not_in_keeps_max", S.State().MaxHp, maxBefore)
				eq("leave_not_in_keeps_players", S.State().Players, playersBefore)

				local stay, tired, rich, late = fighter(), fighter(), fighter(), fighter()
				for _, p in { stay, tired, rich, late } do
					S.Join(p)
				end
				to(FIGHT)

				-- Exhaustion only causes the wait: leaving in it works like any other time.
				local tiredRun = log.Runs[tired]
				tiredRun.Waiting = true
				local maxFull = S.State().MaxHp
				S.Leave(tired, "Left")
				eq("leave_in_wait_out", S.IsIn(tired), false)
				eq("leave_in_wait_returns", log.Depart[tired], 1)
				eq("leave_in_wait_stops_run", tiredRun.Destroyed, 1)
				eq("leave_before_3_00_lowers_max_hp", S.State().MaxHp, maxFull - HP)

				-- A leaver above the reward share still gets nothing.
				local need = Cfg.MinDamageShare * maxFull
				for _ = 1, 1000 do
					if S.DamageOf(rich) > need then
						break
					end
					S.RecordHit(rich)
				end
				flag("test_leaver_over_share", S.DamageOf(rich) > need, S.DamageOf(rich), need)
				S.Leave(rich, "Left")
				eq("leaver_damage_gone", S.DamageOf(rich), 0)
				eq("leaver_hits_nothing", S.RecordHit(rich), 0)

				-- After 3:00 the leave option still works and HP stays locked.
				log.Runs[stay].Waiting = true
				log.Runs[late].Waiting = true
				to(CLOSE)
				local maxLocked, lateRun = S.State().MaxHp, log.Runs[late]
				S.Leave(late, "Left")
				eq("leave_after_3_00_out", S.IsIn(late), false)
				eq("leave_after_3_00_returns", log.Depart[late], 1)
				eq("leave_after_3_00_stops_run", lateRun.Destroyed, 1)
				eq("leave_after_3_00_keeps_max", S.State().MaxHp, maxLocked)

				log.Runs[stay].Waiting = false
				kill(stay)
				eq("leavers_test_defeat", S.State().Stage, 2)
				local list = paidIn(1)
				eq("leavers_rewards_once", timesPaid(stay, 1), 1)
				flag("stayer_rewarded", table.find(list, stay) ~= nil)
				flag("leaver_in_wait_no_reward", table.find(list, tired) == nil)
				flag("leaver_over_share_no_reward", table.find(list, rich) == nil)
				flag("leaver_after_3_00_no_reward", table.find(list, late) == nil)
				eq("leaver_not_returned_again", log.Depart[rich], 1)
				eq("leaver_no_popup", #popupsOf(rich), 0)
				S.End("Timeout")
				eq("leave_no_event_no_error", (pcall(S.Leave, rich, "Left")), true)
				eq("leave_no_event_no_return", log.Depart[rich], 1)

				-- The last player leaving a hurt boss before 3:00 never defeats it.
				begin()
				local solo = fighter()
				S.Join(solo)
				to(FIGHT)
				flag("test_solo_hit", S.RecordHit(solo) > 0)
				S.Leave(solo, "Left")
				to(FIGHT + STEP)
				eq("leave_alone_keeps_fight", phase(), "Fight")
				eq("leave_alone_not_defeated", S.State().LastEnd, nil)
				eq("leave_alone_no_rewards", #log.Paid, 0)

				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local remote = remotes and remotes:FindFirstChild("BossEventLeave")
				flag(
					"leave_remote_exists",
					remote ~= nil and (remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent"))
				)
				local autoRace = remotes and remotes:FindFirstChild("SetAutoRace")
				flag("autorace_remote_exists", autoRace ~= nil and autoRace:IsA("RemoteEvent"))
			end)

			serviceSection("death_return", function()
				begin()
				local dead, other = fighter(), fighter()
				S.Join(dead)
				S.Join(other)
				to(FIGHT)
				local realDepart = S.Hooks.Depart
				S.Hooks.Depart = function(p)
					realDepart(p)
					if p == dead then
						error("no avatar to return on purpose")
					end
				end
				eq("death_no_error", (pcall(S.Leave, dead, "Death")), true)
				eq("death_out", S.IsIn(dead), false)
				local departs = log.Depart[dead]
				eq("leave_after_death_no_error", (pcall(S.Leave, dead, "Left")), true)
				eq("leave_after_death_no_second_return", log.Depart[dead], departs)
				eq("death_tick_safe", (pcall(S.Advance, clock + STEP)), true)
				eq("death_end_safe", (pcall(S.End, "Timeout")), true)
				eq("death_other_still_returned", log.Depart[other], 1)
				eq("death_no_reward_on_timeout", #log.Paid, 0)
			end)

			serviceSection("non_participants", function()
				local outsider, rolls = newPlayer(), 0
				outsider:SetAttribute("AutoRoll", true)
				outsider:SetAttribute("NeedsStarter", false)
				gacha.RollInterval = function(who)
					return who == outsider and 0.02 or oldInterval(who)
				end
				gacha.RollTick = function(who, ...)
					if who == outsider then
						rolls += 1
						return { Id = chars[1], Emphasized = false }
					end
					return oldRollTick(who, ...)
				end
				gacha.WaitAfter = function(id, emphasized, who)
					return who == outsider and 0.02 or oldWaitAfter(id, emphasized, who)
				end
				local handle = gacha.StartAutoRoll(outsider)
				local function rollsOn(name)
					local held = rolls
					flag(
						name,
						waitFor(1, function()
							return rolls > held
						end)
					)
				end
				begin()
				local member = fighter()
				S.Join(member)
				eq("outsider_no_gate_in_prep", outsider:GetAttribute("BossEvent"), nil)
				rollsOn("outsider_rolls_in_prep")
				to(FIGHT)
				eq("outsider_no_gate_in_fight", outsider:GetAttribute("BossEvent"), nil)
				eq("outsider_not_in", S.IsIn(outsider), false)
				rollsOn("outsider_rolls_in_fight")
				S.End("Timeout")
				eq("outsider_no_gate_after", outsider:GetAttribute("BossEvent"), nil)
				rollsOn("outsider_rolls_after")
				handle:Stop()
				gacha.RollInterval, gacha.RollTick, gacha.WaitAfter = oldInterval, oldRollTick, oldWaitAfter
			end)

			serviceSection("chat_notice", function()
				eq("chat_silent_when_idle", #log.Chat, 0)
				begin()
				walk(PREP - STEP)
				eq("chat_silent_in_prep", #log.Chat, 0)
				to(PREP)
				eq("chat_at_spawn_even_with_nobody", #log.Chat, 1)
				eq("chat_exact_text", log.Chat[1], CHAT)
				local p = fighter()
				S.Join(p)
				walk(FIGHT + 20)
				eq("chat_once_per_spawn", #log.Chat, 1)
				S.End("Timeout")
				-- begin() installs a fresh log: count the second spawn from there.
				begin()
				to(PREP)
				eq("chat_again_next_spawn", #log.Chat, 1)
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local remote = remotes and remotes:FindFirstChild("BossEventChat")
				flag("chat_remote_exists_for_all_players", remote ~= nil and remote:IsA("RemoteEvent"))
			end)

			-- Owner 2026-11-05. The moves are read off the shared schedule; a line may come anywhere inside its move.
			serviceSection("move_chat", function()
				flag("move_chat_default_hook_exists", type(realHooks.MoveChat) == "function")
				local Poses = require(Shared.BossRagaPoses)
				local WORDS = {
					attack = "Big Raga attacks! -15% stamina",
					shout = "Big Raga shouts! Damage down for 15 s",
					wheel_turn = "Big Raga turns its wheel! It takes 10% less damage for 15 s",
				}
				local SCAN = 0.01
				local SLACK = 2 * SCAN
				local SPAN_END = FIGHT + 2 * Poses.CycleSeconds + 1 -- 1 s into the next cycle's opening idle
				local moves, current = {}, nil
				for k = 0, math.floor((SPAN_END - FIGHT) / SCAN) do
					local t = FIGHT + k * SCAN
					local name = Poses.Schedule(PREP, t) -- t is on the event clock, where the spawn is at PREP
					if current and current.Move ~= name then
						current.End = t
						current = nil
					end
					if WORDS[name] and not current then
						current = { Move = name, Start = t }
						table.insert(moves, current)
					end
				end
				flag("move_chat_scan_finds_moves", #moves >= 6, #moves, 6)
				local function heard(p)
					local lines = {}
					for _, line in log.MoveChat do
						if line.Player == p then
							table.insert(lines, line)
						end
					end
					return lines
				end
				-- The player heard exactly moves[from] onward, each line inside its move. `tick` is the Advance step.
				local function heardMoves(tag, p, from, tick)
					local lines = heard(p)
					eq(tag .. "_exact_count", #lines, #moves - from + 1)
					for i = from, #moves do
						local line, move = lines[i - from + 1], moves[i]
						eq(tag .. "_text_" .. i, line and line.Text, WORDS[move.Move])
						flag(
							tag .. "_inside_move_" .. i,
							line ~= nil and line.At >= move.Start - SLACK and line.At <= (move.End or SPAN_END) + tick,
							line and line.At,
							move.Start
						)
					end
				end

				begin()
				S.Hooks.DamageMulti = function()
					return 0 -- nothing may defeat the boss in this span
				end
				local member, introJoiner, leaver, outsider = fighter(), fighter(), fighter(), fighter()
				S.Join(member)
				S.Join(leaver)
				walk(PREP - STEP)
				eq("move_chat_none_in_prep", #log.MoveChat, 0)
				walk(PREP + INTRO / 2)
				S.Join(introJoiner)
				walk(FIGHT)
				eq("move_chat_none_in_intro", #log.MoveChat, 0)
				-- A quiet moment in the idle after the second move, before the third.
				local gapAt = math.ceil((moves[2].End + STEP) / STEP) * STEP
				flag("move_chat_gap_is_idle", gapAt + STEP < moves[3].Start, gapAt, moves[3].Start)
				walk(gapAt)
				S.Leave(leaver, "Left")
				local late = fighter()
				S.Join(late)
				walk(SPAN_END)
				eq("move_chat_event_still_running", phase(), "Fight")
				heardMoves("move_chat_member", member, 1, STEP)
				heardMoves("move_chat_intro_joiner", introJoiner, 1, STEP)
				heardMoves("move_chat_late_joiner", late, 3, STEP)
				eq("move_chat_leaver_only_before", #heard(leaver), 2)
				eq("move_chat_outsider_none", #heard(outsider), 0)
				local wheels, wheelLines = 0, 0
				for _, move in moves do
					wheels += move.Move == "wheel_turn" and 1 or 0
				end
				for _, line in heard(member) do
					wheelLines += line.Text == WORDS.wheel_turn and 1 or 0
				end
				flag("move_chat_schedule_has_wheel_turns", wheels >= 2, wheels, 2)
				eq("move_chat_wheel_turn_once_per_move", wheelLines, wheels)
				eq("move_chat_spawn_chat_stays_single", #log.Chat, 1)
				eq("move_chat_spawn_chat_stays_server_wide", log.Chat[1], CHAT)
				local total = #log.MoveChat
				S.End("Timeout")
				walk(SPAN_END + Poses.CycleSeconds)
				eq("move_chat_none_after_end", #log.MoveChat, total)

				-- The live loop ticks once a second: still each move once.
				begin()
				S.Hooks.DamageMulti = function()
					return 0
				end
				local ticked = fighter()
				S.Join(ticked)
				for t = 1, math.ceil(SPAN_END) do
					to(t)
				end
				heardMoves("move_chat_one_second_ticks", ticked, 1, 1)
			end)

			-- Design doc 4.37: the server decides every hit; clients only draw it. Docs/BOSS_EVENT_SPEC.md: hits are batched (task b7d).
			serviceSection("hit_events", function()
				local HALF = EVERY / 2
				local GAP = 0.25 -- s: at most 4 batches a second
				local function idOf(p)
					return p:GetAttribute("UserId")
				end
				local function batchesTo(p)
					local list = {}
					for _, batch in log.BossHits do
						if batch.Player == p then
							table.insert(list, batch)
						end
					end
					return list
				end
				-- What `p` was sent, optionally only `from`'s hits.
				local function entriesTo(p, from)
					local list = {}
					for _, batch in batchesTo(p) do
						for _, entry in batch.Entries do
							if not from or entry.UserId == idOf(from) then
								table.insert(list, entry)
							end
						end
					end
					return list
				end
				local function sum(list)
					local total = 0
					for _, entry in list do
						total += entry.Damage
					end
					return total
				end
				local function dealt()
					return S.State().MaxHp - S.State().Hp
				end

				flag("hit_events_default_hook", type(realHooks.BossHits) == "function")
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local remote = remotes and remotes:FindFirstChild("BossHits")
				flag("hit_events_remote_exists", remote ~= nil and remote:IsA("RemoteEvent"))

				-- Two players: one entry per hit, the right ids, everyone in the event hears all of it, nobody else does.
				begin()
				local a, b, outsider = fighter(), newPlayer(), fighter()
				wear(b, chars[1], "side_chain")
				S.Join(a)
				S.Join(b)
				walk(PREP)
				eq("hit_events_none_in_prep", #log.BossHits, 0)
				walk(FIGHT + EVERY - STEP)
				eq("hit_events_none_before_first_hit", #log.BossHits, 0)
				walk(FIGHT + EVERY * 4 + HALF)
				eq("hit_events_a_hits_to_a", #entriesTo(a, a), 4)
				eq("hit_events_b_hits_to_a", #entriesTo(a, b), 4)
				eq("hit_events_a_hits_to_b", #entriesTo(b, a), 4)
				eq("hit_events_b_hits_to_b", #entriesTo(b, b), 4)
				eq("hit_events_outsider_hears_nothing", #batchesTo(outsider), 0)
				local shape, sameId, sameB = true, true, true
				for _, entry in entriesTo(a) do
					local keys = 0
					for _ in entry do
						keys += 1
					end
					shape = shape
						and keys == 5
						and type(entry.Damage) == "number"
						and entry.Slot == 1
						and entry.CharacterId == chars[1]
				end
				for _, entry in entriesTo(a, a) do
					sameId = sameId and entry.SidekickId == "side_knight"
					near("hit_events_a_damage", entry.Damage, S.TeamDamage(a))
				end
				for _, entry in entriesTo(a, b) do
					sameB = sameB and entry.SidekickId == "side_chain"
					near("hit_events_b_damage", entry.Damage, S.TeamDamage(b))
				end
				flag("hit_events_entry_has_only_five_fields", shape)
				flag("hit_events_a_sidekick_id", sameId)
				flag("hit_events_b_sidekick_id", sameB)
				-- The event adds no damage: entries, per-player totals and the HP drop all agree, at the hit cadence.
				near("hit_events_no_extra_damage_a", S.DamageOf(a), S.TeamDamage(a) * 4)
				near("hit_events_sum_is_damage_of", sum(entriesTo(a, a)), S.DamageOf(a))
				near("hit_events_sum_is_hp_drop", sum(entriesTo(a)), dealt())
				local empty = 0
				for _, batch in log.BossHits do
					empty += #batch.Entries == 0 and 1 or 0
				end
				eq("hit_events_no_empty_batch", empty, 0)

				-- Many hits on small steps: at most 4 batches a second, and nothing lost to the gap.
				begin()
				S.Hooks.DamageMulti = function()
					return 0.01 -- nothing may defeat the boss in this span
				end
				local busy = fighter()
				S.Join(busy)
				walk(FIGHT)
				for _ = 1, 60 do
					clock += 0.05
					eq("hit_events_direct_hit_deals", S.RecordHit(busy) > 0, true)
					S.Advance(clock)
				end
				walk(clock - T0 + STEP * 2)
				local batches = batchesTo(busy)
				flag("hit_events_batched", #batches >= 2 and #batches < 60, #batches)
				local tightest, biggest = math.huge, 0
				for i, batch in batches do
					biggest = math.max(biggest, #batch.Entries)
					if i > 1 then
						tightest = math.min(tightest, batch.At - batches[i - 1].At)
					end
				end
				flag(
					"hit_events_at_most_4_a_second",
					tightest >= GAP - 1e-6,
					tightest < math.huge and tightest or -1,
					GAP
				)
				flag("hit_events_batch_holds_several", biggest > 1, biggest, 2)
				eq(
					"hit_events_small_steps_one_entry_per_hit",
					#entriesTo(busy),
					math.round(S.DamageOf(busy) / (S.TeamDamage(busy) * 0.01))
				)
				near("hit_events_small_steps_sum", sum(entriesTo(busy)), S.DamageOf(busy))

				-- One long frame's catch-up is one batch of every hit.
				begin()
				local late = fighter()
				S.Join(late)
				walk(FIGHT)
				to(FIGHT + EVERY * 10)
				eq("hit_events_catch_up_one_batch", #batchesTo(late), 1)
				eq("hit_events_catch_up_all_hits", #entriesTo(late), 10)

				-- A Sidekick of the line is the one that fires, for its own damage.
				begin()
				local team = fighter()
				wear(team, chars[2], "side_chain")
				S.Join(team)
				eq("hit_events_team_set", S.SetTeam(team, { chars[1], chars[2] }), true)
				walk(FIGHT)
				local run = log.Runs[team]
				run.Line, run.Slot = { 2 }, 2
				walk(FIGHT + EVERY + HALF)
				local heard = entriesTo(team)
				eq("hit_events_slot_two_entry", #heard, 1)
				eq("hit_events_slot_two_id", heard[1] and heard[1].SidekickId, "side_chain")
				near("hit_events_slot_two_damage", heard[1] and heard[1].Damage, S.TeamDamage(team))
				run.Line, run.Slot = { 1 }, 1
				walk(FIGHT + EVERY * 2 + HALF)
				heard = entriesTo(team)
				eq("hit_events_slot_one_id", heard[2] and heard[2].SidekickId, "side_knight")

				-- No client number is read.
				local before = #entriesTo(team)
				near("hit_events_cheat_ignored", S.RecordHit(team, 1, 1e9, "side_fox"), S.TeamDamage(team))
				walk(clock - T0 + GAP)
				heard = entriesTo(team)
				eq("hit_events_cheat_one_entry", #heard, before + 1)
				eq("hit_events_cheat_id_is_server's", heard[#heard] and heard[#heard].SidekickId, "side_knight")
				near("hit_events_cheat_damage_is_server's", heard[#heard] and heard[#heard].Damage, S.TeamDamage(team))

				-- A wait deals nothing, so it sends nothing.
				before = #entriesTo(team)
				run.Waiting = true
				eq("hit_events_waiting_refused", S.RecordHit(team), 0)
				walk(clock - T0 + EVERY * 2)
				eq("hit_events_waiting_no_entry", #entriesTo(team), before)
				run.Waiting = false

				-- A character with no Sidekick cannot hit (design doc 4.36: the Sidekick deals the damage).
				before = #entriesTo(team)
				local hp = S.State().Hp
				local damage = S.DamageOf(team)
				sidekick.Equip(team, chars[2], nil)
				run.Line, run.Slot = { 2 }, 2
				eq("hit_events_no_sidekick_refused", S.RecordHit(team), 0)
				walk(clock - T0 + EVERY * 2)
				eq("hit_events_no_sidekick_no_entry", #entriesTo(team), before)
				eq("hit_events_no_sidekick_no_hp_lost", S.State().Hp, hp)
				eq("hit_events_no_sidekick_no_damage", S.DamageOf(team), damage)
				run.Line, run.Slot = { 1 }, 1
				walk(clock - T0 + EVERY * 2)
				flag("hit_events_worn_slot_hits_again", #entriesTo(team) > before, #entriesTo(team), before + 1)

				-- Characters act individually (owner 2026-11-06): each slot of the line on its own timer, 0.5 s apart in a team of 3.
				begin()
				local line = fighter()
				wear(line, chars[2], "side_chain")
				wear(line, chars[3], "side_fox")
				S.Join(line)
				eq("hit_line_team_set", S.SetTeam(line, { chars[1], chars[2], chars[3] }), true)
				walk(FIGHT)
				local lineRun = log.Runs[line]
				walk(FIGHT + EVERY * 5 / 3)
				heard = entriesTo(line)
				eq("hit_line_three_hits", #heard, 3)
				local drew = {}
				for _, entry in heard do
					drew[entry.SidekickId] = (drew[entry.SidekickId] or 0) + 1
				end
				eq("hit_line_knight_drew_once", drew.side_knight, 1)
				eq("hit_line_chain_drew_once", drew.side_chain, 1)
				eq("hit_line_fox_drew_once", drew.side_fox, 1)
				walk(FIGHT + EVERY * 8 / 3)
				heard = entriesTo(line)
				eq("hit_line_six_hits", #heard, 6)
				for i = 1, 3 do
					eq(
						"hit_line_cycle_repeats_" .. i,
						heard[i + 3] and heard[i + 3].SidekickId,
						heard[i] and heard[i].SidekickId
					)
				end
				-- A slot out of the line fires nothing; the two left keep their own timers.
				lineRun.Line, lineRun.Slot = { 1, 3 }, 1
				walk(FIGHT + EVERY * 11 / 3)
				heard = entriesTo(line)
				eq("hit_line_two_left_hits", #heard, 8)
				flag(
					"hit_line_two_left_alternate",
					heard[7] ~= nil and heard[8] ~= nil and heard[7].SidekickId ~= heard[8].SidekickId
				)
				flag(
					"hit_line_gone_slot_draws_nothing",
					heard[7] ~= nil
						and heard[8] ~= nil
						and heard[7].SidekickId ~= "side_chain"
						and heard[8].SidekickId ~= "side_chain"
				)
				near(
					"hit_line_damage_is_the_characters",
					heard[8] and heard[8].Damage,
					hitOf(line, heard[8] and heard[8].Slot)
				)
				lineRun.Line, lineRun.Slot = { 3 }, 3
				walk(FIGHT + EVERY * 14 / 3)
				heard = entriesTo(line)
				eq("hit_line_last_one_draws", heard[9] and heard[9].SidekickId, "side_fox")

				-- Not in the event: no hit and no batch; a leaver stops hearing.
				begin()
				local stays, leaver, never = fighter(), fighter(), fighter()
				S.Join(stays)
				S.Join(leaver)
				walk(FIGHT + EVERY + HALF)
				flag("hit_events_leaver_heard_while_in", #batchesTo(leaver) > 0)
				eq("hit_events_never_joined_refused", S.RecordHit(never), 0)
				local heardBefore, stayBefore = #batchesTo(leaver), #entriesTo(stays, stays)
				S.Leave(leaver, "Left")
				eq("hit_events_left_refused", S.RecordHit(leaver), 0)
				walk(FIGHT + EVERY * 3 + HALF)
				eq("hit_events_leaver_hears_no_more", #batchesTo(leaver), heardBefore)
				eq("hit_events_stayer_keeps_hitting", #entriesTo(stays, stays), stayBefore + 2)
				eq("hit_events_leaver_no_later_entry", #entriesTo(stays, leaver) <= 1, true)
				eq("hit_events_never_joined_hears_nothing", #batchesTo(never), 0)
				S.End("Timeout")
				local total = #log.BossHits
				eq("hit_events_refused_after_end", S.RecordHit(stays), 0)
				walk(clock - T0 + EVERY * 2)
				eq("hit_events_none_after_end", #log.BossHits, total)

				-- The hit that defeats the boss is drawn too, for no more than the HP it took.
				begin()
				S.Hooks.DamageMulti = function()
					return 1e9
				end
				local killer = fighter()
				S.Join(killer)
				walk(FIGHT)
				local maxHp = S.State().MaxHp
				walk(FIGHT + EVERY + HALF)
				eq("hit_events_defeat_ended", S.State().Stage, 2)
				eq("hit_events_defeat_one_entry", #entriesTo(killer), 1)
				near("hit_events_defeat_entry_is_hp_left", entriesTo(killer)[1] and entriesTo(killer)[1].Damage, maxHp)
				-- And stage 2's, whose hit ends the event.
				local secondMax = S.State().MaxHp
				walk(S.State().ScreamEndsAt - T0 + 2 * EVERY)
				eq("hit_events_final_defeat_ended", phase(), "Idle")
				eq("hit_events_final_defeat_reaches_members", #entriesTo(killer), 2)
				near(
					"hit_events_final_entry_is_hp_left",
					entriesTo(killer)[2] and entriesTo(killer)[2].Damage,
					secondMax
				)

				-- A failed send costs no hit.
				begin()
				S.Hooks.BossHits = function()
					error("send failed")
				end
				local unheard = fighter()
				S.Join(unheard)
				walk(FIGHT + EVERY * 2 + HALF)
				eq("hit_events_failed_send_keeps_fight", phase(), "Fight")
				near("hit_events_failed_send_keeps_damage", S.DamageOf(unheard), S.TeamDamage(unheard) * 2)
				S.End("Timeout")
			end)

			serviceSection("hud_attribute", function()
				begin()
				local a, b = chars[1], chars[2]
				local p = newPlayer()
				wear(p, a, "side_knight")
				wear(p, b, "side_chain")
				local outsider = fighter()
				local both = { damageOf("side_knight"), damageOf("side_chain") }
				local function shows(name, want)
					near("attr_" .. name, p:GetAttribute("BossTeamDamage") or -1, want)
					near(
						"attr_" .. name .. "_is_service_number",
						p:GetAttribute("BossTeamDamage") or -1,
						S.TeamDamage(p)
					)
				end
				eq("attr_nil_before_join", p:GetAttribute("BossTeamDamage"), nil)
				S.Join(p)
				-- No pick yet: the team that would run, the auto-chosen one.
				local auto = S.AutoTeam(p)
				shows("after_join", sumOf(p, auto))
				S.SetTeam(p, { b })
				shows("after_pick_one", sumOf(p, { b }))
				S.SetTeam(p, { a, b })
				shows("after_pick_two", sumOf(p, { a, b }))
				to(FIGHT)
				local run = log.Runs[p]
				run.TargetSpeed = 123 -- the characters' own cruise counts, not what the run reports
				for _, cruise in { 200, 800, 1600 } do
					withCruise(cruise, function()
						to(clock - T0 + STEP)
						shows("in_run_at_" .. cruise, (both[1] + both[2]) * Cfg.SpeedScale(cruise))
					end)
				end
				eq("attr_nil_for_outsider", outsider:GetAttribute("BossTeamDamage"), nil)
				local late = fighter()
				S.Join(late)
				near(
					"attr_late_joiner",
					late:GetAttribute("BossTeamDamage") or -1,
					sumOf(late, S.TeamOf(late)) -- a joiner runs at once
				)
				S.Leave(p, "Left")
				eq("attr_nil_after_leave", p:GetAttribute("BossTeamDamage"), nil)
				S.End("Timeout")
				eq("attr_nil_after_end", late:GetAttribute("BossTeamDamage"), nil)
			end)

			------------------------------------------------------------------------------------------------------------------------
			-- Phase 2 (owner 2026-11-06, design doc 4.37, BOSS_EVENT_SPEC "Phase 2" and "Rewards"). Stage 1 and 2 are Phases 1 and 2.
			------------------------------------------------------------------------------------------------------------------------
			serviceSection("stage2_start", function()
				local Poses = require(Shared.BossRagaPoses)
				local BossDodge = require(Shared.BossDodge)
				local function attr(name)
					return ReplicatedStorage:GetAttribute(name)
				end
				begin()
				local a, b = fighter(), fighter()
				S.Join(a)
				S.Join(b)
				eq("stage_1_in_prep", S.State().Stage, 1)
				to(FIGHT)
				eq("stage_1_in_the_fight", S.State().Stage, 1)
				eq("stage_1_ends_at_old_end", S.State().EndsAt, T0 + TOTAL)
				eq("stage_1_no_scream", S.State().ScreamEndsAt, nil)
				eq("stage_damage_starts_0", S.StageDamageOf(a, 1), 0)
				local firstMax = S.State().MaxHp
				local KILL = FIGHT + 5 -- moment 1 of stage 1 would fall inside the scream
				to(KILL)
				flag("stage_test_kill_before_moment_1", KILL < FIGHT + BossDodge.Moment(1))
				flag("stage_test_kill_inside_scream", FIGHT + BossDodge.Moment(1) < KILL + Cfg.ScreamSeconds)
				local before = S.DamageOf(b)
				local killed = kill(b)
				near("stage_1_damage_counts_to_stage_1", S.StageDamageOf(b, 1), before + killed)
				eq("stage_2_damage_starts_0", S.StageDamageOf(b, 2), 0)
				near("damage_of_is_the_total", S.DamageOf(b), before + killed)

				local state = S.State()
				local screamEnd = T0 + KILL + Cfg.ScreamSeconds
				local endsAt = T0 + TOTAL + Cfg.ScreamSeconds + Cfg.Phase2ExtraSeconds
				eq("stage_2_started", state.Stage, 2)
				eq("stage_2_still_fight", state.Phase, "Fight")
				eq("stage_2_no_last_end", state.LastEnd, nil)
				eq("stage_2_keeps_members", S.IsIn(a) and S.IsIn(b), true)
				eq("stage_2_no_return", log.Depart[a], nil)
				eq("stage_2_keeps_run", log.Runs[a].Destroyed, 0)
				eq("stage_2_max_hp", state.MaxHp, firstMax + Cfg.Phase2ExtraHp)
				eq("stage_2_hp_full", state.Hp, state.MaxHp)
				eq("stage_2_phase1_max", state.Phase1MaxHp, firstMax)
				eq("stage_2_ends_at", state.EndsAt, endsAt)
				eq("stage_2_scream_ends_at", state.ScreamEndsAt, screamEnd)
				eq("stage_2_attr_stage", attr("BossEventStage"), 2)
				eq("stage_2_attr_ends_at", attr("BossEventEndsAt"), endsAt)
				eq("stage_2_attr_scream_ends_at", attr("BossScreamEndsAt"), screamEnd)
				eq("stage_2_attr_max_hp", attr("BossEventMaxHp"), state.MaxHp)
				eq("stage_2_attr_hp", attr("BossEventHp"), state.MaxHp)
				eq("stage_2_phase_at_stays_pure", S.PhaseAt(TOTAL), "End")

				-- Poses.Schedule on the published start: moment 1 at the scream's end + Moment(1).
				local scheduleStart = attr("BossScheduleStart")
				local move, localTime = Poses.Schedule(scheduleStart, screamEnd + BossDodge.Moment(1))
				eq("stage_2_schedule_move", move, "attack")
				flag(
					"stage_2_schedule_on_the_impact",
					type(localTime) == "number" and math.abs(localTime - Poses.Moves.attack.Events[1].Time) < 0.01,
					localTime,
					Poses.Moves.attack.Events[1].Time
				)

				-- The scream: no damage, no moves, HP stays full, no one joins.
				local run = log.Runs[a]
				local stamina, lines = run.Stamina[1], #log.MoveChat
				eq("scream_record_hit_0", S.RecordHit(a), 0)
				walk(KILL + Cfg.ScreamSeconds - STEP)
				eq("scream_hp_stays_full", S.State().Hp, S.State().MaxHp)
				eq("scream_no_stage_2_damage", S.StageDamageOf(a, 2), 0)
				eq("scream_record_hit_0_near_its_end", S.RecordHit(a), 0)
				eq("scream_charges_no_move", run.Stamina[1], stamina)
				eq("scream_no_move_chat", #log.MoveChat, lines)
				eq("scream_still_listed", S.State().ScreamEndsAt, screamEnd)
				flag("join_test_before_3_00", clock - T0 < CLOSE, clock - T0, CLOSE)
				local late = fighter()
				local joined, why = S.Join(late)
				eq("stage_2_join_refused", joined, false)
				eq("stage_2_join_reason", why, "Teleporting has closed")
				eq("stage_2_join_adds_no_hp", S.State().MaxHp, firstMax + Cfg.Phase2ExtraHp)
				eq("stage_2_join_not_in", S.IsIn(late), false)

				to(KILL + Cfg.ScreamSeconds)
				eq("scream_over", S.State().ScreamEndsAt, nil)
				eq("stage_2_after_scream", S.State().Stage, 2)
				local soFar = S.StageDamageOf(a, 2)
				local dealt = S.RecordHit(a)
				flag("stage_2_hits_after_scream", dealt > 0, dealt, "> 0")
				near("stage_2_hit_counts_to_stage_2", S.StageDamageOf(a, 2), soFar + dealt)
				near("stage_2_hit_keeps_stage_1", S.StageDamageOf(a, 1), S.DamageOf(a) - S.StageDamageOf(a, 2))
				eq("stage_2_outsider_stage_damage", S.StageDamageOf(late, 2), 0)
				soFar = S.StageDamageOf(a, 2)
				walk(KILL + Cfg.ScreamSeconds + 2 * EVERY)
				flag("stage_2_cadence_resumes", S.StageDamageOf(a, 2) > soFar, S.StageDamageOf(a, 2), soFar)

				-- A leave takes no HP back, even before 3:00.
				local hp, max = S.State().Hp, S.State().MaxHp
				flag("leave_test_before_3_00", clock - T0 < CLOSE, clock - T0, CLOSE)
				S.Leave(b, "Left")
				eq("stage_2_leave_keeps_max", S.State().MaxHp, max)
				near("stage_2_leave_keeps_hp", S.State().Hp, hp)

				S.End("Timeout")
				for _, name in { "BossEventStage", "BossEventEndsAt", "BossScreamEndsAt", "BossScheduleStart" } do
					eq("stage_attr_cleared_" .. name, attr(name), nil)
				end

				-- Two hits due in one tick: the first HP 0 fires once, and the second hit lands in the scream.
				begin()
				local x, y = fighter(), fighter()
				S.Join(x)
				S.Join(y)
				to(FIGHT)
				S.Hooks.DamageMulti = function()
					return 1e9
				end
				local max1 = S.State().MaxHp
				to(FIGHT + EVERY)
				eq("once_stage_2", S.State().Stage, 2)
				eq("once_max", S.State().MaxHp, max1 + Cfg.Phase2ExtraHp)
				eq("once_hp_full", S.State().Hp, S.State().MaxHp)
				eq("once_pays_the_one_who_dealt_it", #paidIn(1), 1)
				to(clock - T0 + STEP)
				eq("once_next_tick_max", S.State().MaxHp, max1 + Cfg.Phase2ExtraHp)
				eq("once_next_tick_pays_no_more", #paidIn(1), 1)
				eq("once_next_tick_hp_full", S.State().Hp, S.State().MaxHp)
			end)

			-- The tick ends on State().EndsAt, not on TotalSeconds.
			serviceSection("stage2_end_time", function()
				local ENDS = TOTAL + Cfg.ScreamSeconds + Cfg.Phase2ExtraSeconds
				begin()
				local p = fighter()
				S.Join(p)
				to(FIGHT)
				local run = log.Runs[p]
				run.Waiting = true
				to(TOTAL - 10)
				run.Waiting = false
				kill(p)
				eq("late_kill_same_end", S.State().EndsAt, T0 + ENDS)
				run.Waiting = true
				to(TOTAL)
				eq("stage_2_passes_8_00", phase(), "Fight")
				eq("stage_2_passes_8_00_no_end", S.State().LastEnd, nil)
				to(ENDS - STEP)
				eq("stage_2_runs_to_its_end", phase(), "Fight")
				to(ENDS)
				eq("stage_2_ends_at_its_end", phase(), "Idle")
				eq("stage_2_end_reported", S.State().LastEnd, "Timeout")

				-- Killed on the very tick of 8:00: stage 2 starts, the timeout does not fire.
				begin()
				local q = fighter()
				S.Join(q)
				to(FIGHT)
				log.Runs[q].Waiting = true
				to(TOTAL - EVERY)
				log.Runs[q].Waiting = false
				S.Hooks.DamageMulti = function()
					return 1e9
				end
				to(TOTAL)
				eq("kill_on_8_00_starts_stage_2", S.State().Stage, 2)
				eq("kill_on_8_00_still_fight", phase(), "Fight")
				eq("kill_on_8_00_end", S.State().EndsAt, T0 + ENDS)
			end)

			serviceSection("stage2_moves", function()
				local BossDodge = require(Shared.BossDodge)
				local COST1 = Cfg.Stage(1).AttackStaminaCost
				local COST2 = Cfg.Stage(2).AttackStaminaCost
				local function lastLine()
					return log.MoveChat[#log.MoveChat] and log.MoveChat[#log.MoveChat].Text
				end
				begin()
				local p = fighter()
				S.Join(p)
				to(FIGHT)
				local run = log.Runs[p]
				-- Stage 1's moment 1 hits, so there is a Vulnerable to clear and a spent moment 1.
				to(FIGHT + BossDodge.Moment(1) + 0.05)
				near("stage_1_impact_plain", run.Stamina[1], 100 - COST1)
				flag("stage_1_impact_leaves_vulnerable", statusRow(p, "Vulnerable") ~= nil)
				eq("stage_1_chat_numbers", lastLine(), Cfg.MoveChat("Impact", 1))
				run.Stamina[1] = 100
				kill(p)
				to(clock - T0 + STEP)
				eq("stage_start_clears_statuses", p:GetAttribute("BossStatus"), nil)
				local lines = #log.MoveChat
				local base = S.State().ScreamEndsAt - T0
				local function moment(index)
					return base + BossDodge.Moment(index)
				end
				walk(moment(1) - STEP)
				near("moment_1_not_early", run.Stamina[1], 100)
				eq("moment_1_no_chat_early", #log.MoveChat, lines)
				to(moment(1))
				-- Plain, not heavy: stage 1's Vulnerable went at the stage start. Charged though moment 1 was already spent.
				near("stage_2_impact_plain", run.Stamina[1], 100 - COST2)
				eq("stage_2_chat_numbers", lastLine(), Cfg.MoveChat("Impact", 2))
				eq("stage_2_one_line", #log.MoveChat, lines + 1)
				flag("stage_2_impact_leaves_vulnerable", statusRow(p, "Vulnerable") ~= nil)
				eq("stage_2_moment_2_is_wheel", select(2, BossDodge.Moment(2)), "WheelClick")
				to(moment(2) + 0.05)
				eq("stage_2_wheel_chat", lastLine(), Cfg.MoveChat("WheelClick", 2))
				eq("stage_2_moment_3_is_roar", select(2, BossDodge.Moment(3)), "Roar")
				to(moment(3) + 0.05)
				eq("stage_2_roar_chat", lastLine(), Cfg.MoveChat("Roar", 2))
				near("stage_2_other_moves_cost_nothing", run.Stamina[1], 100 - COST2)
				eq("stage_2_moment_4_is_impact", select(2, BossDodge.Moment(4)), "Impact")
				to(moment(4) + 0.05)
				near("stage_2_impact_heavy", run.Stamina[1], 100 - COST2 - COST2 * Cfg.VulnerableMulti)
				eq("stage_2_moment_6_is_impact", select(2, BossDodge.Moment(6)), "Impact")
				to(moment(6) + 0.05)
				eq("stage_2_impact_floors_at_0", run.Stamina[1], 0)
			end)

			serviceSection("status_stacks", function()
				local Poses = require(Shared.BossRagaPoses)
				local BossDodge = require(Shared.BossDodge)
				local CUT_S, CUT_A = 1 - Cfg.ShoutDamageCut, 1 - Cfg.AdaptedCut
				local S2 = Cfg.Stage(2).StatusSeconds
				local real = realHooks.DamageMulti
				-- Each status's moments: { At, Index }, seconds after the intro's end.
				local found = { WheelClick = {}, Roar = {} }
				for index = 1, 14 do
					local at, name = BossDodge.Moment(index)
					if found[name] then
						table.insert(found[name], { At = at, Index = index })
					end
				end
				local clicks, roars = found.WheelClick, found.Roar
				local clickGap, roarGap = clicks[2].At - clicks[1].At, roars[3].At - roars[2].At
				flag("stack_gap_clicks_under_stage_2", clickGap < S2, clickGap, S2)
				flag("stack_gap_roars_under_stage_2", roarGap < S2, roarGap, S2)
				flag("stack_gap_clicks_over_stage_1", clickGap > Cfg.Stage(1).StatusSeconds, clickGap)
				flag("stack_gap_roars_over_stage_1", roarGap > Cfg.Stage(1).StatusSeconds, roarGap)

				-- Stage 1 on today's schedule: never more than one of a status.
				begin()
				S.Hooks.DamageMulti = real
				local one = fighter()
				S.Join(one)
				local most = 0
				for k = 0, math.ceil(2 * Poses.CycleSeconds / STEP) do
					to(FIGHT + k * STEP)
					for _, id in { "Shouted", "Adapted" } do
						local row = statusRow(one, id)
						most = math.max(most, row and row.Count or 0)
					end
				end
				eq("stage_1_at_most_one_stack", most, 1)

				-- Stage 2, nothing dodged.
				begin()
				local p = fighter()
				S.Join(p)
				to(FIGHT)
				local stageSeen
				S.Hooks.DamageMulti = function(t, spared, stage)
					stageSeen = stage
					return real(t, spared, stage)
				end
				S.RecordHit(p)
				eq("damage_multi_told_stage_1", stageSeen, 1)
				kill(p)
				local base = S.State().ScreamEndsAt - T0
				local run = log.Runs[p]
				to(base + clicks[2].At + 0.05)
				local adapted, shouted, vulnerable =
					statusRow(p, "Adapted"), statusRow(p, "Shouted"), statusRow(p, "Vulnerable")
				eq("adapted_x2_count", adapted and adapted.Count, 2)
				near("adapted_x2_ends_at_latest", adapted and adapted.EndsAt, T0 + base + clicks[2].At + S2)
				eq("shouted_x1_count", shouted and shouted.Count, 1)
				near("shouted_x1_ends_at", shouted and shouted.EndsAt, T0 + base + roars[1].At + S2)
				eq("vulnerable_row_count", vulnerable and vulnerable.Count, 1)
				eq("vulnerable_row_no_ends_at", vulnerable and vulnerable.EndsAt, nil)
				near("adapted_x2_cuts_twice", S.RecordHit(p), S.TeamDamage(p) * CUT_A * CUT_A * CUT_S)
				eq("damage_multi_told_stage_2", stageSeen, 2)
				near("adapted_x2_hud_number_not_cut", p:GetAttribute("BossTeamDamage"), S.TeamDamage(p))
				-- A stack has its own timer.
				to(base + clicks[1].At + S2 + 0.05)
				adapted = statusRow(p, "Adapted")
				eq("adapted_older_stack_expires", adapted and adapted.Count, 1)
				near("adapted_latest_end_kept", adapted and adapted.EndsAt, T0 + base + clicks[2].At + S2)
				to(base + roars[3].At + 0.05)
				shouted, adapted = statusRow(p, "Shouted"), statusRow(p, "Adapted")
				eq("shouted_x2_count", shouted and shouted.Count, 2)
				near("shouted_x2_ends_at_latest", shouted and shouted.EndsAt, T0 + base + roars[3].At + S2)
				eq("adapted_x1_beside_shouted_x2", adapted and adapted.Count, 1)
				near("shouted_x2_cuts_twice", S.RecordHit(p), S.TeamDamage(p) * CUT_S * CUT_S * CUT_A)
				eq("stacks_run_not_waiting", run.Waiting, false)

				-- The pure hook. t counts from BossScheduleStart, the stage's own spawn.
				local t = INTRO + clicks[2].At + 0.5
				near("pure_stage_2_x2", real(t, nil, 2), CUT_A * CUT_A * CUT_S)
				near("pure_stage_1_x1_at_same_time", real(t, nil, 1), CUT_A * CUT_S)
				near("pure_spared_stack_not_counted", real(t, { [clicks[1].Index] = true }, 2), CUT_A * CUT_S)
				eq("pure_none_in_intro", real(INTRO / 2, nil, 2), 1)

				-- A dodged move and a wait-spared move add no stack.
				begin()
				S.Hooks.SwitchLane = function() end
				local dodger = fighter()
				S.Join(dodger)
				to(FIGHT)
				S.Hooks.DamageMulti = real
				kill(dodger)
				base = S.State().ScreamEndsAt - T0
				to(base + clicks[1].At + 0.05)
				eq("dodge_case_one_stack", (statusRow(dodger, "Adapted") or {}).Count, 1)
				eq("dodge_case_press_ok", press(dodger, clicks[2].Index, 2, base), true)
				to(base + clicks[2].At + 0.05)
				eq("dodged_move_adds_no_stack", (statusRow(dodger, "Adapted") or {}).Count, 1)
				near(
					"dodged_stack_end_not_moved",
					(statusRow(dodger, "Adapted") or {}).EndsAt,
					T0 + base + clicks[1].At + S2
				)
				local dodgerRun = log.Runs[dodger]
				dodgerRun.Waiting = true
				to(base + roars[2].At + 0.05)
				dodgerRun.Waiting = false
				-- The first roar's stack ran out by here, so the wait's roar would be the only one.
				flag("wait_case_first_roar_gone", roars[1].At + S2 < roars[2].At, roars[1].At + S2, roars[2].At)
				eq("wait_spared_move_adds_no_stack", statusRow(dodger, "Shouted"), nil)
			end)

			serviceSection("vulnerable", function()
				local BossDodge = require(Shared.BossDodge)
				local COST = Cfg.Stage(1).AttackStaminaCost
				local HEAVY = COST * Cfg.VulnerableMulti
				for index, name in
					{ "Impact", "WheelClick", "Roar", "Impact", "WheelClick", "Impact", "Roar", "Impact" }
				do
					eq("vulnerable_moment_" .. index, select(2, BossDodge.Moment(index)), name)
				end
				local function moment(index)
					return FIGHT + BossDodge.Moment(index)
				end
				local function fresh()
					begin()
					S.Hooks.SwitchLane = function() end
					local p = fighter()
					S.Join(p)
					to(FIGHT)
					return p, log.Runs[p]
				end

				-- A dodged Impact neither spends nor sets it.
				local p, run = fresh()
				eq("vulnerable_none_at_start", statusRow(p, "Vulnerable"), nil)
				eq("vulnerable_press_1", press(p, 1, 1, FIGHT), true)
				to(moment(1) + 0.05)
				near("dodged_impact_costs_nothing", run.Stamina[1], 100)
				eq("dodged_impact_does_not_set", statusRow(p, "Vulnerable"), nil)
				to(moment(2) + 0.05)
				local row = statusRow(p, "Vulnerable")
				flag("undodged_wheel_sets", row ~= nil)
				eq("vulnerable_count_is_1", row and row.Count, 1)
				eq("vulnerable_has_no_end", row and row.EndsAt, nil)
				eq("vulnerable_press_3", press(p, 3, 1, FIGHT), true)
				eq("vulnerable_press_4", press(p, 4, 1, FIGHT), true)
				to(moment(4) + 0.05)
				near("dodged_impact_does_not_spend_cost", run.Stamina[1], 100)
				flag("dodged_impact_does_not_spend", statusRow(p, "Vulnerable") ~= nil)
				eq("vulnerable_press_5", press(p, 5, 1, FIGHT), true)
				to(moment(6) + 0.05)
				near("undodged_impact_costs_heavy", run.Stamina[1], 100 - HEAVY)
				flag("undodged_impact_sets_it_again", statusRow(p, "Vulnerable") ~= nil)
				eq("vulnerable_press_7", press(p, 7, 1, FIGHT), true)
				to(moment(8) + 0.05)
				near("impact_set_by_an_impact_is_heavy", run.Stamina[1], 100 - 2 * HEAVY)
				eq("no_stacking_count_stays_1", (statusRow(p, "Vulnerable") or {}).Count, 1)
				S.End("Timeout")
				eq("vulnerable_cleared_at_end", p:GetAttribute("BossStatus"), nil)

				-- The order: an Impact when not Vulnerable costs plain, then sets it. The moves between are dodged.
				p, run = fresh()
				to(moment(1))
				near("first_impact_plain", run.Stamina[1], 100 - COST)
				flag("first_impact_sets", statusRow(p, "Vulnerable") ~= nil)
				eq("order_press_2", press(p, 2, 1, FIGHT), true)
				eq("order_press_3", press(p, 3, 1, FIGHT), true)
				to(moment(4) + 0.05)
				near("second_impact_heavy_from_the_first", run.Stamina[1], 100 - COST - HEAVY)

				-- A move spared by the wait sets nothing.
				p, run = fresh()
				run.Waiting = true
				to(moment(1) + 0.05)
				run.Waiting = false
				near("wait_impact_costs_nothing", run.Stamina[1], 100)
				eq("wait_impact_does_not_set", statusRow(p, "Vulnerable"), nil)
				eq("wait_press_2", press(p, 2, 1, FIGHT), true)
				eq("wait_press_3", press(p, 3, 1, FIGHT), true)
				to(moment(4) + 0.05)
				near("impact_after_wait_plain", run.Stamina[1], 100 - COST)

				-- Floored at 0, and it leaves with the player.
				p, run = fresh()
				to(moment(1))
				run.Stamina[1] = 10
				to(moment(4) + 0.05)
				eq("heavy_floors_at_0", run.Stamina[1], 0)
				S.Leave(p, "Left")
				eq("vulnerable_cleared_on_leave", p:GetAttribute("BossStatus"), nil)
			end)

			-- Line run (owner 2026-11-06, spec "Run rules", "Line run"): the attack and the damage follow run.Line.
			serviceSection("line_run_service", function()
				local BossDodge = require(Shared.BossDodge)
				local COST = Cfg.Stage(1).AttackStaminaCost
				local HEAVY = COST * Cfg.VulnerableMulti
				local DK, DC, DF = damageOf("side_knight"), damageOf("side_chain"), damageOf("side_fox")
				local function moment(index)
					return FIGHT + BossDodge.Moment(index)
				end
				local function fresh(size)
					begin()
					S.Hooks.SwitchLane = function() end
					local p = newPlayer()
					local ids = {}
					for i, sideId in { "side_knight", "side_chain", "side_fox" } do
						if i <= size then
							wear(p, chars[i], sideId)
							table.insert(ids, chars[i])
						end
					end
					S.Join(p)
					S.SetTeam(p, ids)
					return p, ids
				end
				local function stamina(name, run, one, two, three)
					near(name .. "_slot_1", run.Stamina[1], one)
					near(name .. "_slot_2", run.Stamina[2], two)
					near(name .. "_slot_3", run.Stamina[3], three)
				end
				flag("line_test_damages_differ", DK ~= DC or DC ~= DF, DK, DC)

				-- TeamDamage: the line's characters, each at its own cruise; the whole team before a run.
				local p, ids = fresh(3)
				near("line_damage_before_run_is_whole_team", S.TeamDamage(p), sumOf(p, ids))
				to(FIGHT)
				local run = log.Runs[p]
				local KS, CS, FS = DK * Cfg.SpeedScale(200), DC * Cfg.SpeedScale(400), DF * Cfg.SpeedScale(800)
				withCruise({ [ids[1]] = 200, [ids[2]] = 400, [ids[3]] = 800 }, function()
					near("line_damage_whole_line", S.TeamDamage(p), KS + CS + FS)
					run.Line, run.Slot = { 2, 3 }, 2
					near("line_damage_two_left", S.TeamDamage(p), CS + FS)
					run.TargetSpeed = 1600
					near("line_damage_speed_own_cruise", S.TeamDamage(p), CS + FS)
					run.Line, run.Slot = { 1, 3 }, 1
					near("line_damage_middle_gone", S.TeamDamage(p), KS + FS)
					run.Line, run.Slot = { 3 }, 3
					near("line_damage_one_left", S.TeamDamage(p), FS)
					run.Line, run.Slot = {}, nil
					eq("team_damage_empty_is_0", S.TeamDamage(p), 0)
				end)

				-- An undodged Impact: every slot in the line, Vulnerable included, each floored; a slot in no line pays nothing.
				p = fresh(3)
				to(FIGHT)
				run = log.Runs[p]
				to(moment(1))
				stamina("line_impact_plain", run, 100 - COST, 100 - COST, 100 - COST)
				run.Line, run.Slot = { 2, 3 }, 2
				run.Stamina[1], run.Stamina[2], run.Stamina[3] = 100, 100, 1
				to(moment(4) + 0.05)
				stamina("line_impact_heavy", run, 100, 100 - HEAVY, 0)
				eq("line_impact_floors_at_exactly_0", run.Stamina[3], 0)

				-- Dodged, or in the wait: nobody pays.
				p = fresh(3)
				to(FIGHT)
				run = log.Runs[p]
				eq("line_press_1", press(p, 1, 1, FIGHT), true)
				to(moment(1) + 0.05)
				stamina("line_dodged", run, 100, 100, 100)
				p = fresh(3)
				to(FIGHT)
				run = log.Runs[p]
				run.Waiting = true
				to(moment(1) + 0.05)
				run.Waiting = false
				stamina("line_waiting", run, 100, 100, 100)

				-- A team of 2 works the same way; its absent third slot is in no line.
				p, ids = fresh(2)
				near("line_duo_damage_before_run", S.TeamDamage(p), sumOf(p, ids))
				to(FIGHT)
				run = log.Runs[p]
				to(moment(1))
				stamina("line_duo_impact", run, 100 - COST, 100 - COST, 100)
				near("line_duo_damage", S.TeamDamage(p), sumOf(p, ids))
				run.Line, run.Slot = { 2 }, 2
				near("line_duo_damage_one_left", S.TeamDamage(p), sumOf(p, ids, { 2 }))
			end)

			-- Owner 2026-11-06 (design doc 4.37, BOSS_EVENT_SPEC "Characters act individually").
			serviceSection("individual_hits", function()
				local DK, DC, DF = damageOf("side_knight"), damageOf("side_chain"), damageOf("side_fox")
				local function fresh(size)
					begin()
					local p = newPlayer()
					local ids = {}
					for i, sideId in { "side_knight", "side_chain", "side_fox" } do
						if i <= size then
							wear(p, chars[i], sideId)
							table.insert(ids, chars[i])
						end
					end
					S.Join(p)
					S.SetTeam(p, ids)
					return p, ids
				end
				-- `p`'s own hits as `p` heard them, each with its batch's time: every member hears every hit, so others' are left out.
				-- Steps of STEP send each frame's hits in that frame's batch.
				local function heardBy(p)
					local list = {}
					for _, batch in log.BossHits do
						if batch.Player == p then
							for _, entry in batch.Entries do
								if entry.UserId == p:GetAttribute("UserId") then
									table.insert(list, { Entry = entry, At = batch.At })
								end
							end
						end
					end
					return list
				end
				local function timesOf(p, slot)
					local list = {}
					for _, row in heardBy(p) do
						if row.Entry.Slot == slot then
							table.insert(list, row.At)
						end
					end
					return list
				end
				local function countSince(p, slot, since)
					local n = 0
					for _, at in timesOf(p, slot) do
						n += at > since and 1 or 0
					end
					return n
				end
				-- The most slots that fired on one frame after `since`.
				local function mostOnOneFrame(p, since)
					local frames, most = {}, 0
					for _, row in heardBy(p) do
						if row.At > since then
							frames[row.At] = (frames[row.At] or 0) + 1
							most = math.max(most, frames[row.At])
						end
					end
					return most
				end
				local function gapsAre(list, gap)
					for i = 2, #list do
						if not approx(list[i] - list[i - 1], gap) then
							return false
						end
					end
					return #list >= 2
				end

				-- Own damage: own Sidekick, own Relic, own cruise, then the player's statuses.
				local p, ids = fresh(3)
				to(FIGHT)
				local run = log.Runs[p]
				run.TargetSpeed = 1600
				local cruises = { [ids[1]] = 200, [ids[2]] = 400, [ids[3]] = 800 }
				local told = {}
				local KS, CS, FS = DK * Cfg.SpeedScale(200), DC * Cfg.SpeedScale(400), DF * Cfg.SpeedScale(800)
				withStub(gacha, "CruiseFor", function(_, id, slot, team)
					told[id] = { Slot = slot, Team = team }
					return cruises[id]
				end, function()
					withStub(Relic, "Multi", function(_, id, stat)
						return stat == "Damage" and id == ids[2] and 3 or 1
					end, function()
						local hp = S.State().Hp
						near("individual_slot_1_damage", S.RecordHit(p, 1), KS)
						near("individual_slot_2_own_relic_and_cruise", S.RecordHit(p, 2), CS * 3)
						near("individual_slot_3_damage", S.RecordHit(p, 3), FS)
						near("individual_hp_sums", S.State().Hp, hp - KS - CS * 3 - FS)
						near("individual_damage_of_sums", S.DamageOf(p), KS + CS * 3 + FS)
						near("individual_stage_damage_sums", S.StageDamageOf(p, 1), KS + CS * 3 + FS)
						near("individual_team_damage_sums", S.TeamDamage(p), KS + CS * 3 + FS)
						S.Hooks.DamageMulti = function()
							return 0.5
						end
						near("individual_status_cuts_the_hit", S.RecordHit(p, 2), CS * 3 * 0.5)
						near("individual_team_damage_not_cut", S.TeamDamage(p), KS + CS * 3 + FS)
						S.Hooks.DamageMulti = function()
							return 1
						end
						-- slot defaults to the front.
						run.Line, run.Slot = { 2, 3 }, 2
						near("individual_default_slot_is_front", S.RecordHit(p), CS * 3)
						local before = S.State().Hp
						eq("individual_slot_out_of_line_is_0", S.RecordHit(p, 1), 0)
						eq("individual_slot_not_on_team_is_0", S.RecordHit(p, 4), 0)
						eq("individual_refused_takes_no_hp", S.State().Hp, before)
						run.Waiting = true
						eq("individual_waiting_is_0", S.RecordHit(p, 2), 0)
						run.Waiting = false
					end)
				end)
				eq("individual_cruise_told_slot", told[ids[2]] and told[ids[2]].Slot, 2)
				flag("individual_cruise_told_team", told[ids[2]] ~= nil and H.same(told[ids[2]].Team, ids))
				walk(clock - T0 + STEP * 2)
				local shapes = {}
				for _, row in heardBy(p) do
					shapes[row.Entry.Slot] = row.Entry
				end
				for slot, sideId in { "side_knight", "side_chain", "side_fox" } do
					local entry = shapes[slot]
					eq("individual_entry_slot_" .. slot, entry and entry.Slot, slot)
					eq("individual_entry_character_" .. slot, entry and entry.CharacterId, ids[slot])
					eq("individual_entry_sidekick_" .. slot, entry and entry.SidekickId, sideId)
					eq("individual_entry_user_" .. slot, entry and entry.UserId, p:GetAttribute("UserId"))
					local keys = 0
					for _ in entry or {} do
						keys += 1
					end
					eq("individual_entry_fields_" .. slot, keys, 5)
				end
				-- No Sidekick: nothing from that slot, and the sum leaves it out.
				run.Line, run.Slot = { 1, 2, 3 }, 1
				sidekick.Equip(p, ids[3], nil)
				eq("individual_no_sidekick_is_0", S.RecordHit(p, 3), 0)
				near("individual_no_sidekick_not_summed", S.TeamDamage(p), hitOf(p, 1) + hitOf(p, 2))
				local quiet = clock - T0
				walk(quiet + EVERY * 2)
				eq("individual_no_sidekick_no_timer_hits", countSince(p, 3, quiet), 0)
				flag("individual_others_keep_hitting", countSince(p, 1, quiet) > 0 and countSince(p, 2, quiet) > 0)
				-- The scream refuses every slot.
				kill(p)
				eq("individual_scream_slot_1_is_0", S.RecordHit(p, 1), 0)
				eq("individual_scream_slot_2_is_0", S.RecordHit(p, 2), 0)

				-- Timers: 3 characters 0.5 s apart, each on its own beat, never two on a frame.
				p = fresh(3)
				walk(FIGHT + EVERY * 4)
				local one, two, three = timesOf(p, 1), timesOf(p, 2), timesOf(p, 3)
				near("individual_first_hit_slot_1", one[1], FIGHT + EVERY)
				near("individual_first_hit_slot_2", two[1], FIGHT + EVERY + EVERY / 3)
				near("individual_first_hit_slot_3", three[1], FIGHT + EVERY + EVERY * 2 / 3)
				flag("individual_slot_1_beat", gapsAre(one, EVERY), #one)
				flag("individual_slot_2_beat", gapsAre(two, EVERY), #two)
				flag("individual_slot_3_beat", gapsAre(three, EVERY), #three)
				eq("individual_never_two_on_a_frame", mostOnOneFrame(p, 0), 1)
				-- A team of 2 divides by 2; a team of 1 is as ever.
				p = fresh(2)
				walk(FIGHT + EVERY * 3)
				near("individual_duo_slot_1", timesOf(p, 1)[1], FIGHT + EVERY)
				near("individual_duo_slot_2", timesOf(p, 2)[1], FIGHT + EVERY + EVERY / 2)
				eq("individual_duo_never_two_on_a_frame", mostOnOneFrame(p, 0), 1)
				p = fresh(1)
				walk(FIGHT + EVERY * 3)
				near("individual_solo_slot_1", timesOf(p, 1)[1], FIGHT + EVERY)
				eq("individual_solo_hits", #timesOf(p, 1), 3)
				-- A late joiner's timers are its own.
				begin()
				local holder = fighter()
				S.Join(holder)
				local late = newPlayer()
				wear(late, chars[1], "side_knight")
				wear(late, chars[2], "side_chain")
				wear(late, chars[3], "side_fox")
				walk(100)
				S.Join(late)
				walk(100 + EVERY * 2)
				near("individual_late_slot_1", timesOf(late, 1)[1], 100 + EVERY)
				near("individual_late_slot_2", timesOf(late, 2)[1], 100 + EVERY + EVERY / 3)
				near("individual_late_slot_3", timesOf(late, 3)[1], 100 + EVERY + EVERY * 2 / 3)

				-- Attack speed is the character's own Relic's.
				p, ids = fresh(3)
				withStub(Relic, "Multi", function(_, id, stat)
					return stat == "AttackSpeed" and id == ids[2] and 2 or 1
				end, function()
					walk(FIGHT + EVERY * 5)
				end)
				flag("individual_attack_speed_own_slot", gapsAre(timesOf(p, 2), EVERY / 2), #timesOf(p, 2))
				flag("individual_attack_speed_not_shared", gapsAre(timesOf(p, 1), EVERY), #timesOf(p, 1))
				flag("individual_attack_speed_not_shared_3", gapsAre(timesOf(p, 3), EVERY), #timesOf(p, 3))

				-- A slot gone from the line fires nothing and owes nothing on return.
				p = fresh(3)
				walk(FIGHT + EVERY * 2)
				run = log.Runs[p]
				run.Line, run.Slot = { 1, 3 }, 1
				local goneAt = clock - T0
				walk(goneAt + 10)
				eq("individual_gone_slot_no_hits", countSince(p, 2, goneAt), 0)
				flag(
					"individual_others_hit_while_one_gone",
					countSince(p, 1, goneAt) > 0 and countSince(p, 3, goneAt) > 0
				)
				run.Line, run.Slot = { 1, 2, 3 }, 1
				local backAt = clock - T0
				to(backAt)
				eq("individual_return_no_hit_on_the_frame", countSince(p, 2, backAt - STEP), 0)
				walk(backAt + EVERY - STEP)
				flag("individual_return_owes_nothing", countSince(p, 2, backAt) <= 1, countSince(p, 2, backAt), 1)
				walk(backAt + EVERY * 3)
				flag("individual_return_hits_again", countSince(p, 2, backAt) >= 2, countSince(p, 2, backAt), 2)

				-- The wait: nothing from anyone, nothing piled up, and the team comes back spread out.
				p = fresh(3)
				walk(FIGHT + EVERY * 2)
				run = log.Runs[p]
				run.Waiting = true
				local waitAt = clock - T0
				walk(waitAt + 10)
				eq("individual_wait_no_hits", mostOnOneFrame(p, waitAt), 0)
				run.Waiting = false
				local resumed = clock - T0
				walk(resumed + EVERY * 2)
				for slot = 1, 3 do
					flag(
						"individual_wait_owes_nothing_" .. slot,
						countSince(p, slot, resumed) <= 2,
						countSince(p, slot, resumed),
						2
					)
					flag(
						"individual_wait_resumes_" .. slot,
						countSince(p, slot, resumed) >= 1,
						countSince(p, slot, resumed),
						1
					)
				end
				eq("individual_wait_resume_not_one_frame", mostOnOneFrame(p, resumed), 1)

				-- The scream: the same.
				p = fresh(3)
				walk(FIGHT + EVERY * 2)
				kill(p)
				local screamAt = clock - T0
				local screamEnd = S.State().ScreamEndsAt - T0
				walk(screamEnd - STEP)
				local inScream = 0
				for slot = 1, 3 do
					inScream += countSince(p, slot, screamAt)
				end
				flag("individual_scream_only_the_killing_hit", inScream <= 1, inScream, 1)
				eq("individual_scream_stage_2_clean", S.StageDamageOf(p, 2), 0)
				walk(screamEnd + EVERY * 2)
				for slot = 1, 3 do
					flag(
						"individual_scream_owes_nothing_" .. slot,
						countSince(p, slot, screamEnd) <= 2,
						countSince(p, slot, screamEnd),
						2
					)
				end
				eq("individual_scream_resume_not_one_frame", mostOnOneFrame(p, screamEnd), 1)

				-- A killing hit in a round with others due: stage 2 once, the event's end once, no later slot fires.
				p = fresh(3)
				to(FIGHT)
				S.Hooks.DamageMulti = function()
					return 1e9
				end
				local firstMax = S.State().MaxHp
				to(FIGHT + EVERY * 3)
				eq("individual_kill_starts_stage_2", S.State().Stage, 2)
				eq("individual_kill_max_once", S.State().MaxHp, firstMax + Cfg.Phase2ExtraHp)
				eq("individual_kill_hp_full", S.State().Hp, S.State().MaxHp)
				eq("individual_kill_paid_once", timesPaid(p, 1), 1)
				eq("individual_kill_no_stage_2_damage", S.StageDamageOf(p, 2), 0)
				near("individual_kill_damage_is_the_hp", S.DamageOf(p), firstMax)
				eq("individual_kill_one_entry", #heardBy(p), 1)
				to(S.State().ScreamEndsAt - T0 + EVERY * 3)
				eq("individual_final_kill_ends", phase(), "Idle")
				eq("individual_final_kill_paid_once", timesPaid(p, 2), 1)
				eq("individual_final_kill_one_popup", #popupsOf(p), 1)
				eq("individual_final_kill_two_entries", #heardBy(p), 2)
			end)

			serviceSection("stage2_dodge", function()
				local BossDodge = require(Shared.BossDodge)
				begin()
				S.Hooks.SwitchLane = function() end
				local p = fighter()
				S.Join(p)
				to(FIGHT)
				local run = log.Runs[p]
				-- Moment 1 pressed and spared in stage 1: both reset at the stage start.
				eq("stage_1_press_ok", press(p, 1, 1, FIGHT), true)
				to(FIGHT + BossDodge.Moment(1) + 0.05)
				kill(p)
				for index = 1, 3 do
					eq("scream_no_bar_" .. index, S.Dodge(p, index, clock), false)
				end
				local base = S.State().ScreamEndsAt - T0
				local function moment(index)
					return base + BossDodge.Moment(index)
				end
				-- Inside stage 1's sweep, before stage 2's: no bar yet, and the press is not spent.
				to(moment(1) - BossDodge.SweepFor(2) - 0.1)
				eq("stage_2_before_its_faster_bar", S.Dodge(p, 1, clock), false)
				local lines = #log.MoveChat
				eq("stage_2_press_same_index_ok", press(p, 1, 2, base), true)
				eq("stage_2_second_press_refused", S.Dodge(p, 1, clock), false)
				to(moment(1) + 0.05)
				near("stage_2_dodged_costs_nothing", run.Stamina[1], 100)
				eq("stage_2_dodged_no_chat", #log.MoveChat, lines)
				eq("stage_2_dodged_no_vulnerable", statusRow(p, "Vulnerable"), nil)

				-- Off the spot: the press is spent, and the move hits.
				local spot = BossDodge.Spot(p:GetAttribute("UserId"), T0, 2, 2)
				local from = BossDodge.Window(spot, T0 + moment(2), 2)
				local early = from - 0.1
				flag("stage_2_early_is_on_the_bar", early >= T0 + moment(2) - BossDodge.SweepFor(2), early)
				to(early - T0)
				eq("stage_2_off_spot_refused", S.Dodge(p, 2, early), false)
				eq("stage_2_off_spot_spends_press", press(p, 2, 2, base), false)
				to(moment(2) + 0.05)
				eq("stage_2_off_spot_is_hit", (statusRow(p, "Adapted") or {}).Count, 1)
				flag("stage_2_off_spot_vulnerable", statusRow(p, "Vulnerable") ~= nil)
				eq("stage_2_after_moment_refused", S.Dodge(p, 2, clock), false)
			end)

			serviceSection("stage2_rewards", function()
				local SHARE = Cfg.MinDamageShare
				local function popup(tag, p, outcome, stage1, stage2, short, damage)
					local list = popupsOf(p)
					eq(tag .. "_one_popup", #list, 1)
					local summary = list[1] or {}
					eq(tag .. "_outcome", summary.Outcome, outcome)
					eq(tag .. "_stage_1", summary.Stage1, stage1)
					eq(tag .. "_stage_2", summary.Stage2, stage2)
					if short ~= nil then
						eq(tag .. "_short", summary.Short, short)
					end
					near(tag .. "_damage", summary.Damage, damage)
				end
				local function has(list, p)
					return table.find(list, p) ~= nil
				end

				-- Both stages defeated, a player for each mix of shares.
				begin()
				local both, first, second, under, none = fighter(), fighter(), fighter(), fighter(), fighter()
				local all = { both, first, second, under, none }
				for _, p in all do
					S.Join(p)
				end
				to(FIGHT)
				local need1 = SHARE * S.State().MaxHp
				deal(both, need1)
				deal(first, need1) -- exactly the share
				deal(under, need1 * 0.99)
				kill(both)
				local paid1 = paidIn(1)
				eq("pay_1_at_the_defeat", #paid1, 2)
				flag("pay_1_top", has(paid1, both))
				flag("pay_1_exact_share", has(paid1, first))
				flag("pay_1_not_under", not has(paid1, under))
				flag("pay_1_not_no_damage", not has(paid1, none))
				eq("pay_1_no_popup_yet", #log.Popups, 0)
				eq("pay_1_nothing_of_stage_2", #paidIn(2), 0)
				eq("share_1_against_phase1_max", need1, SHARE * S.State().Phase1MaxHp)
				pastScream(table.unpack(all))
				local need2 = SHARE * S.State().MaxHp
				deal(both, need2)
				deal(second, need2) -- exactly the share of stage 2's own HP
				deal(first, need2 * 0.99)
				deal(under, need2 * 0.5)
				near("stage_damage_first_1", S.StageDamageOf(first, 1), need1)
				near("stage_damage_first_2", S.StageDamageOf(first, 2), need2 * 0.99)
				near("damage_of_first_total", S.DamageOf(first), need1 + need2 * 0.99)
				local totals = {}
				for _, p in all do
					totals[p] = S.DamageOf(p)
				end
				totals[both] += kill(both)
				eq("pay_2_event_over", phase(), "Idle")
				eq("pay_2_defeated", S.State().LastEnd, "Defeated")
				local paid2 = paidIn(2)
				eq("pay_2_list", #paid2, 2)
				flag("pay_2_top", has(paid2, both))
				flag("pay_2_exact_share", has(paid2, second))
				flag("pay_2_not_first", not has(paid2, first))
				flag("pay_2_not_under", not has(paid2, under))
				eq("pay_1_still_once", timesPaid(both, 1), 1)
				eq("pay_2_once", timesPaid(both, 2), 1)
				popup("popup_both", both, "Defeated", true, true, false, totals[both])
				popup("popup_first", first, "Defeated", true, false, nil, totals[first])
				popup("popup_second", second, "Defeated", false, true, nil, totals[second])
				popup("popup_under", under, "Defeated", false, false, true, totals[under])
				popup("popup_none", none, "Defeated", false, false, true, 0)

				-- A timeout in stage 1 pays nothing and shows nothing (the clock's timeout is in "timeline").
				begin()
				local timed = fighter()
				S.Join(timed)
				to(FIGHT)
				deal(timed, SHARE * S.State().MaxHp)
				S.End("Timeout")
				eq("timeout_1_end_no_pay", #log.Paid, 0)
				eq("timeout_1_end_no_popup", #log.Popups, 0)

				-- A timeout in stage 2: stage 1's pay stands, nothing more, popup "Survived".
				begin()
				local keeper, small = fighter(), fighter()
				S.Join(keeper)
				S.Join(small)
				to(FIGHT)
				deal(small, SHARE * S.State().MaxHp * 0.5)
				local smallTotal = S.DamageOf(small)
				local keeperTotal = kill(keeper)
				pastScream(keeper, small)
				keeperTotal += deal(keeper, SHARE * S.State().MaxHp) -- over stage 2's share, and a timeout still pays no more
				log.Runs[keeper].Waiting, log.Runs[small].Waiting = true, true
				to(S.State().EndsAt - T0)
				eq("timeout_2_reported", S.State().LastEnd, "Timeout")
				eq("timeout_2_stage_1_pay_stands", timesPaid(keeper, 1), 1)
				eq("timeout_2_pays_no_more", #paidIn(2), 0)
				popup("survived_keeper", keeper, "Survived", true, false, false, keeperTotal)
				popup("survived_small", small, "Survived", false, false, true, smallTotal)

				-- Leaves: stage 1's leaver gets nothing; stage 2's keeps stage 1's pay and gets "Left" if it was paid.
				begin()
				local stayer, paidLeaver, unpaidLeaver, earlyLeaver = fighter(), fighter(), fighter(), fighter()
				for _, p in { stayer, paidLeaver, unpaidLeaver, earlyLeaver } do
					S.Join(p)
				end
				to(FIGHT)
				deal(earlyLeaver, SHARE * S.State().MaxHp * 2)
				S.Leave(earlyLeaver, "Left")
				eq("stage_1_leaver_no_popup", #popupsOf(earlyLeaver), 0)
				local leaverTotal = deal(paidLeaver, SHARE * S.State().MaxHp)
				deal(unpaidLeaver, 1)
				local stayerTotal = kill(stayer)
				local paid = paidIn(1)
				flag("leave_stayer_paid", has(paid, stayer))
				flag("leave_paid_leaver_paid", has(paid, paidLeaver))
				flag("leave_unpaid_not_paid", not has(paid, unpaidLeaver))
				flag("leave_early_not_paid", not has(paid, earlyLeaver))
				pastScream(stayer, paidLeaver, unpaidLeaver)
				leaverTotal += deal(paidLeaver, SHARE * S.State().MaxHp) -- over stage 2's share too
				local hp, max = S.State().Hp, S.State().MaxHp
				flag("left_test_before_3_00", clock - T0 < CLOSE, clock - T0, CLOSE)
				S.Leave(paidLeaver, "Left")
				popup("left_paid", paidLeaver, "Left", true, false, nil, leaverTotal)
				eq("left_paid_returns", log.Depart[paidLeaver], 1)
				S.Leave(unpaidLeaver, "Left")
				eq("left_unpaid_no_popup", #popupsOf(unpaidLeaver), 0)
				eq("left_takes_no_max_back", S.State().MaxHp, max)
				near("left_takes_no_hp_back", S.State().Hp, hp)
				stayerTotal += kill(stayer)
				eq("left_defeat", S.State().LastEnd, "Defeated")
				eq("left_gets_no_stage_2_pay", timesPaid(paidLeaver, 2), 0)
				eq("stayer_gets_stage_2_pay", timesPaid(stayer, 2), 1)
				eq("left_no_second_popup", #popupsOf(paidLeaver), 1)
				popup("left_stayer", stayer, "Defeated", true, true, false, stayerTotal)

				-- One player's failure never costs another's, in either stage or at the popup.
				begin()
				local thrower, refused, fine = fighter(), fighter(), fighter()
				for _, p in { thrower, refused, fine } do
					S.Join(p)
				end
				S.Hooks.PayStage = function(p, stage)
					table.insert(log.Paid, { Player = p, Stage = stage })
					if p == thrower then
						error("pay failed on purpose")
					end
					return p ~= refused
				end
				S.Hooks.RewardPopup = function(p, summary)
					table.insert(log.Popups, { Player = p, Summary = summary })
					if p == thrower then
						error("popup failed on purpose")
					end
				end
				to(FIGHT)
				for _, p in { thrower, refused } do
					deal(p, SHARE * S.State().MaxHp)
				end
				kill(fine)
				eq("failure_stage_2_starts", S.State().Stage, 2)
				for tag, p in { thrower = thrower, refused = refused, fine = fine } do
					eq("failure_stage_1_each_once_" .. tag, timesPaid(p, 1), 1)
				end
				pastScream(thrower, refused, fine)
				for _, p in { thrower, refused } do
					deal(p, SHARE * S.State().MaxHp)
				end
				eq("failure_kill_no_error", (pcall(kill, fine)), true)
				eq("failure_event_over", phase(), "Idle")
				eq("failure_defeat_reported", S.State().LastEnd, "Defeated")
				for tag, p in { thrower = thrower, refused = refused, fine = fine } do
					eq("failure_stage_2_each_once_" .. tag, timesPaid(p, 2), 1)
					eq("failure_each_popup_" .. tag, #popupsOf(p), 1)
					eq("failure_each_released_" .. tag, p:GetAttribute("BossEvent"), nil)
				end
				local fineSummary = popupsOf(fine)[1] or {}
				eq("failure_fine_keeps_stage_1", fineSummary.Stage1, true)
				eq("failure_fine_keeps_stage_2", fineSummary.Stage2, true)
			end)

			section("default_hooks", function()
				local CarService = require(Server.CarService)
				local Arena = require(Shared.BossArenaConfig)
				local race = require(Server.RaceService)
				S.SetClock(function()
					return clock
				end)
				clock = T0
				S.Reset(T0)
				for name, fn in realHooks do
					S.Hooks[name] = fn
				end
				quietRewards()
				SpawnArea.START_COOLDOWN = 0
				flag("live_route_exists", race.GetRoute() ~= nil)

				local p = newPlayer()
				wear(p, chars[1], "side_knight")
				local normal = p:GetAttribute("Team")
				local character = deps.newFakeCharacter(CarService.WalkSpawnCFrame())
				character.Parent = character.Parent or workspace
				table.insert(cleanup, character)
				CarService.OnCharacter(p, character)
				CarService.SetAutoRace(p, true)
				flag(
					"normal_run_started",
					waitFor(1, function()
						return CarService.GetRun(p) ~= nil
					end)
				)
				local normalRun = CarService.GetRun(p)
				normalRun.Unbanked = 100

				-- A run in progress cashes out through the normal stop when the player teleports.
				S.Start("Test")
				eq("default_join_ok", S.Join(p), true)
				flag(
					"normal_run_stopped",
					waitFor(1, function()
						return CarService.GetRun(p) ~= normalRun
					end)
				)
				eq("normal_run_cashed_out", normalRun.PaidTotal, 100)
				eq("normal_bank_empty", normalRun.Unbanked, 0)
				eq("spec_no_warm_up_laps", CarService.GetRun(p), nil)
				task.wait(0.3) -- long enough for an unanchored avatar to fall: the deck builds on the client
				local lane = S.LaneOf(p)
				local function spot()
					local car = CarService.GetCar(p)
					return (car or character):GetPivot().Position
				end
				flag("stands_at_lane", math.abs(flatDistance(spot(), Arena.Center) - Arena.LaneRadius(lane)) < 6)
				flag("stands_on_track_height", math.abs(spot().Y - Arena.Y) < 20, spot().Y, Arena.Y)

				-- Big Raga's fight: a real boss run on the player's lane.
				to(FIGHT)
				flag(
					"boss_run_started",
					waitFor(1, function()
						return CarService.GetRun(p) ~= nil
					end)
				)
				local bossRun = CarService.GetRun(p)
				flag("boss_run_event_team", bossRun ~= nil and H.same(bossRun.Team, S.TeamOf(p)))
				eq("boss_run_not_waiting", bossRun and bossRun.Waiting, false)
				task.wait(0.2)
				local radius = flatDistance(spot(), Arena.Center)
				flag("boss_run_on_lane", math.abs(radius - Arena.LaneRadius(lane)) < 3, radius, Arena.LaneRadius(lane))
				flag("boss_damage_positive", S.TeamDamage(p) > 0)
				eq("boss_run_pad_refused", CarService.PadTouched(p, character:FindFirstChild("Left Leg")), false)

				S.End("Timeout")
				flag(
					"end_stops_boss_run",
					waitFor(1, function()
						return CarService.GetRun(p) == nil and not CarService.IsAutoRacing(p)
					end)
				)
				eq("end_clears_gate_real", p:GetAttribute("BossEvent"), nil)
				eq("end_team_kept_real", p:GetAttribute("Team"), normal)
				flag(
					"end_back_at_spawn",
					waitFor(1, function()
						return flatDistance(character:GetPivot().Position, CarService.WalkSpawnCFrame().Position) < 10
					end)
				)

				-- The leave option, for real: the run stops and the player is back at spawn.
				begin()
				for name, fn in realHooks do
					S.Hooks[name] = fn
				end
				quietRewards()
				S.Join(p)
				to(FIGHT)
				flag(
					"real_leave_boss_run_started",
					waitFor(1, function()
						return CarService.GetRun(p) ~= nil
					end)
				)
				S.Leave(p, "Left")
				eq("real_leave_clears_gate", p:GetAttribute("BossEvent"), nil)
				flag(
					"real_leave_stops_run",
					waitFor(1, function()
						return CarService.GetRun(p) == nil and not CarService.IsAutoRacing(p)
					end)
				)
				flag(
					"real_leave_back_at_spawn",
					waitFor(1, function()
						return flatDistance(character:GetPivot().Position, CarService.WalkSpawnCFrame().Position) < 10
					end)
				)
				eq("real_leave_team_kept", p:GetAttribute("Team"), normal)

				-- A death mid-event: out of the event, and the next tick is fine.
				begin()
				for name, fn in realHooks do
					S.Hooks[name] = fn
				end
				quietRewards()
				S.Join(p)
				to(FIGHT)
				waitFor(1, function()
					return CarService.GetRun(p) ~= nil
				end)
				character:FindFirstChildOfClass("Humanoid").Health = 0
				flag(
					"real_death_leaves_event",
					waitFor(1, function()
						return not S.IsIn(p)
					end)
				)
				eq("real_death_clears_gate", p:GetAttribute("BossEvent"), nil)
				clock = T0 + FIGHT + STEP
				eq("real_death_tick_safe", (pcall(S.Advance, clock)), true)
				flag(
					"real_death_stops_run",
					waitFor(1, function()
						return CarService.GetRun(p) == nil
					end)
				)
				eq("real_leave_after_death_safe", (pcall(S.Leave, p, "Left")), true)
				S.Reset(T0)
				SpawnArea.START_COOLDOWN = oldCooldown
			end)

			-- Owner 2026-11-05, BOSS_EVENT_SPEC "Exhaustion view": the framing, and the end time the client's view runs from.
			section("wait_view", function()
				local CarService = require(Server.CarService)
				local Arena = require(Shared.BossArenaConfig)
				local RunnerFactory = require(Shared.RunnerFactory)
				local makeFrame = Cfg.WaitCameraCFrame
				flag("wait_cframe_is_function", type(makeFrame) == "function")
				if type(makeFrame) == "function" then
					local VIEW_HEIGHT, VIEW_WIDTH = 907, 1920
					-- Placeholders set from the geometry (owner 2026-11-05).
					-- These floors are the old 450 by 320 view's (owner 2026-11-06 zoomed in a lot); the zoomed view only exceeds them.
					local MIN_RUNNER_PX, MIN_BOSS_PX, MAX_RUNNER_Y = 2.5, 225, 790
					local EYE_OUT, EYE_UP, EYE_SLACK = 120, 80, 20 -- studs from the runner: "about"
					local RIG_HEIGHT = 5 * RunnerFactory.SCALE -- feet to head top
					local halfTall = math.tan(math.rad(Cfg.WaitCameraFov / 2))
					local halfWide = halfTall * VIEW_WIDTH / VIEW_HEIGHT
					local function flat(point)
						return Vector3.new(point.X - Arena.Center.X, 0, point.Z - Arena.Center.Z)
					end
					-- Screen height in px from the view's middle, and whether the point shows.
					local function project(frame, point)
						local at = frame:PointToObjectSpace(point)
						local depth = -at.Z
						if depth <= 0 then
							return 0, false
						end
						local y, x = at.Y / depth, at.X / depth
						return y / halfTall * VIEW_HEIGHT / 2, math.abs(y) <= halfTall and math.abs(x) <= halfWide
					end
					local feetOfBoss = Vector3.new(Arena.Center.X, Arena.DaisY, Arena.Center.Z)
					local wheelTop = feetOfBoss + Vector3.yAxis * Arena.BossTotalHeight
					local bad = { side = {}, runner = {}, boss = {}, spot = {} }
					local smallestRunner, smallestBoss, lowestRunner = math.huge, math.huge, -math.huge
					for _, lane in { 1, Arena.Lanes } do
						for i = 0, Arena.Segments - 1, Arena.Segments / 8 do
							local tag = lane .. "@" .. i
							local feet = Arena.RingPoint(Arena.LaneRadius(lane), i)
							local root = feet + Vector3.yAxis * RunnerFactory.HIP_HEIGHT
							local frame = makeFrame(Arena.Center, root)
							local inward = -flat(frame.Position)
							if
								flat(frame.Position).Magnitude <= flat(root).Magnitude
								or frame.Position.Y <= root.Y
								or frame.LookVector:Dot(inward) <= 0
								or frame.LookVector.Y >= 0
							then
								table.insert(bad.side, tag)
							end
							local out = flat(frame.Position).Magnitude - flat(root).Magnitude
							local up = frame.Position.Y - root.Y
							if math.abs(out - EYE_OUT) > EYE_SLACK or math.abs(up - EYE_UP) > EYE_SLACK then
								table.insert(bad.spot, tag)
							end
							local feetY, feetShow = project(frame, feet)
							local headY, headShow = project(frame, feet + Vector3.yAxis * RIG_HEIGHT)
							if not (feetShow and headShow) then
								table.insert(bad.runner, tag)
							end
							smallestRunner = math.min(smallestRunner, headY - feetY)
							lowestRunner = math.max(lowestRunner, VIEW_HEIGHT / 2 - feetY) -- y from the top
							local bottomY, bottomShow = project(frame, feetOfBoss)
							local topY, topShow = project(frame, wheelTop)
							if not (bottomShow and topShow) then
								table.insert(bad.boss, tag)
							end
							smallestBoss = math.min(smallestBoss, topY - bottomY)
						end
					end
					flag("wait_camera_outer_above_looking_in", #bad.side == 0, table.concat(bad.side, " "), "none")
					flag("wait_camera_eye_spot", #bad.spot == 0, table.concat(bad.spot, " "), "none")
					flag("wait_runner_in_view", #bad.runner == 0, table.concat(bad.runner, " "), "none")
					flag("wait_runner_above_hud", lowestRunner <= MAX_RUNNER_Y, lowestRunner, MAX_RUNNER_Y)
					flag("wait_runner_tall_enough", smallestRunner >= MIN_RUNNER_PX, smallestRunner, MIN_RUNNER_PX)
					flag("wait_boss_in_view", #bad.boss == 0, table.concat(bad.boss, " "), "none")
					flag("wait_boss_tall_enough", smallestBoss >= MIN_BOSS_PX, smallestBoss, MIN_BOSS_PX)

					local root = Arena.RingPoint(Arena.LaneRadius(1), 12) + Vector3.yAxis * RunnerFactory.HIP_HEIGHT
					local moved = Vector3.new(100, 50, -300)
					local frame, shifted = makeFrame(Arena.Center, root), makeFrame(Arena.Center + moved, root + moved)
					flag(
						"wait_cframe_pure",
						(shifted.Position - frame.Position - moved).Magnitude < 0.01
							and shifted.LookVector:FuzzyEq(frame.LookVector, 0.001)
					)
					local fine, fallback = pcall(makeFrame, Arena.Center)
					flag(
						"wait_fallback_no_error",
						fine and typeof(fallback) == "CFrame",
						tostring(fallback),
						"a CFrame"
					)
					if fine and typeof(fallback) == "CFrame" then
						flag(
							"wait_fallback_in_front",
							fallback.Position.Z < Arena.Center.Z,
							fallback.Position.Z,
							"< centre"
						) -- Big Raga faces -Z (Client/BossRaga)
					end
				end

				S.SetClock(function()
					return clock
				end)
				SpawnArea.START_COOLDOWN = 0
				local function realEvent(...)
					begin()
					for name, fn in realHooks do
						S.Hooks[name] = fn
					end
					quietRewards()
					for _, p in { ... } do
						S.Join(p)
					end
					to(FIGHT)
				end
				local function arrive()
					local p = fighter()
					local character = deps.newFakeCharacter(CarService.WalkSpawnCFrame())
					character.Parent = character.Parent or workspace
					table.insert(cleanup, character)
					CarService.OnCharacter(p, character)
					return p
				end
				-- Empties the team of a running player, and waits for the wait to start.
				local function exhaust(p)
					waitFor(1, function()
						return CarService.GetRun(p) ~= nil
					end)
					local run = CarService.GetRun(p)
					if not run then
						return nil
					end
					waitFor(2, function()
						for i in run.Stamina do
							run.Stamina[i] = 0.01
						end
						return run.Waiting == true
					end)
					return run.Waiting == true and run or nil
				end
				local function ends(p)
					return p:GetAttribute("BossWaitEndsAt")
				end

				local tired, other = arrive(), arrive()
				realEvent(tired, other)
				eq("wait_attr_none_while_running", ends(tired), nil)
				local run = exhaust(tired)
				flag("wait_run_waits", run ~= nil)
				if not run then
					S.Reset(T0)
					SpawnArea.START_COOLDOWN = oldCooldown
					return
				end
				local endsAt = ends(tired)
				flag("wait_attr_published", type(endsAt) == "number", endsAt, "number")
				-- Either clock: the client reads GetServerTimeNow, and in this test the event's own clock is a fake.
				local left = type(endsAt) == "number"
						and math.min(
							math.abs(endsAt - workspace:GetServerTimeNow() - Cfg.RefillWaitSeconds),
							math.abs(endsAt - clock - Cfg.RefillWaitSeconds)
						)
					or math.huge
				flag("wait_attr_is_end_time", left < 0.5, left, "< 0.5 from now + wait")
				eq("wait_other_player_untouched", ends(other), nil)
				flag(
					"wait_attr_clears_at_refill",
					waitFor(Cfg.RefillWaitSeconds + 1, function()
						return ends(tired) == nil
					end)
				)
				flag(
					"wait_attr_lasts_to_refill",
					waitFor(0.2, function()
						return run.Waiting == false
					end),
					run.Waiting,
					false
				)

				-- Leaving mid-wait, and the event's end mid-wait: the attribute goes and stays gone.
				local left2 = exhaust(tired)
				flag("wait_second_wait_starts", left2 ~= nil)
				flag("wait_second_wait_publishes", type(ends(tired)) == "number")
				S.Leave(tired, "Left")
				flag(
					"wait_attr_clears_on_leave",
					waitFor(0.5, function()
						return ends(tired) == nil
					end)
				)
				task.wait(0.3)
				eq("wait_attr_stays_clear_after_leave", ends(tired), nil)

				realEvent(tired)
				flag("wait_end_case_waits", exhaust(tired) ~= nil)
				S.End("Timeout")
				flag(
					"wait_attr_clears_on_event_end",
					waitFor(0.5, function()
						return ends(tired) == nil
					end)
				)

				-- The cutscene skips exhaustion (owner 2026-11-06): the service asks a waiting run to revive at the scream's end.
				begin()
				local waiter, hitter = fighter(), fighter()
				S.Join(waiter)
				S.Join(hitter)
				to(FIGHT)
				log.Runs[waiter].Waiting = true
				kill(hitter)
				local asked = log.Runs[waiter].Revives
				eq("revive_asked_once_at_scream_start", #asked, 1)
				near("revive_asked_with_the_scream_left", asked[1] or -1, Cfg.ScreamSeconds)
				eq("revive_not_asked_of_a_runner", #log.Runs[hitter].Revives, 0)

				-- The same on real runs and real seconds: all in one scream, so it costs one scream's wall time.
				local longP, shortP, midP, killer = arrive(), arrive(), arrive(), arrive()
				realEvent(longP, shortP, midP, killer)
				local refill = Cfg.RefillWaitSeconds
				Cfg.RefillWaitSeconds = 0.9 -- about 0.5 s left by the kill, however long the rest takes
				local shortRun = exhaust(shortP)
				Cfg.RefillWaitSeconds = refill
				local longRun = exhaust(longP) -- 8 s and more left
				flag("revive_fixture_runs_wait", shortRun ~= nil and longRun ~= nil)
				flag("revive_fixture_short_still_waits", shortRun ~= nil and shortRun.Waiting == true)
				if not (shortRun and longRun) then
					S.Reset(T0)
					SpawnArea.START_COOLDOWN = oldCooldown
					return
				end
				flag("revive_at_exists", type(longRun.ReviveAt) == "function")
				kill(killer)
				local wallStart, clockStart = os.clock(), clock
				local function follow()
					clock = clockStart + (os.clock() - wallStart)
					S.Advance(clock)
				end
				eq("revive_long_end_time_nil_at_scream_start", ends(longP), nil)
				eq("revive_short_end_time_nil_at_scream_start", ends(shortP), nil)
				while os.clock() - wallStart < 1 do
					follow()
					task.wait()
				end
				local midRun = exhaust(midP) -- emptied during the scream, with 8.5 s of wait it must not serve
				flag("revive_mid_scream_run_waits", midRun ~= nil)
				eq("revive_mid_scream_no_end_time", ends(midP), nil)
				local runs = { long = longRun, short = shortRun, mid = midRun }
				local revivedAt = {}
				local scream = Cfg.ScreamSeconds
				while os.clock() - wallStart < scream + 0.5 do
					follow()
					for name, run in runs do
						if not revivedAt[name] and run.Waiting == false then
							revivedAt[name] = os.clock() - wallStart
						end
					end
					task.wait()
				end
				for name, run in runs do
					local at = revivedAt[name]
					flag("revive_" .. name .. "_at_scream_end", at ~= nil and math.abs(at - scream) <= 0.3, at, scream)
					eq("revive_" .. name .. "_stands_revived", run.Waiting, false)
					local full = true
					for slot in run.Team do
						full = full and math.abs((run.Stamina[slot] or 0) - 100) < 5 -- a little drained by the time this reads
					end
					flag("revive_" .. name .. "_full_stamina", full)
					eq("revive_" .. name .. "_full_line", #(run.Line or {}), #run.Team)
				end
				for name, p in { long = longP, short = shortP, mid = midP } do
					eq("revive_" .. name .. "_end_time_stays_nil", ends(p), nil)
				end
				S.Reset(T0)
				SpawnArea.START_COOLDOWN = oldCooldown
			end)

			-- Owner 2026-11-05: a player in a duel can teleport in, and leaves the duel through DuelService.PlayerLeft.
			section("duel_join", function()
				local CarService = require(Server.CarService)
				local Arena = require(Shared.BossArenaConfig)
				local Duel = require(Server.DuelService)
				local DuelConfig = require(Shared.DuelConfig)
				local duelNow, sent = 5000, {}
				S.SetClock(function()
					return clock
				end)
				clock = T0
				S.Reset(T0)
				for name, fn in realHooks do
					S.Hooks[name] = fn
				end
				quietRewards()
				Duel.SetClock(function()
					return duelNow
				end)
				Duel.SetNotify(function(who, message)
					table.insert(sent, { Player = who, Message = message })
				end)
				local function rival()
					local p = fighter()
					p:SetAttribute("DataLoaded", true)
					p:SetAttribute("RaceEvent", "Off")
					p:SetAttribute("AutoRacing", false)
					local character =
						deps.newFakeCharacter(CFrame.new(CarService.WalkSpawnCFrame().Position + Vector3.new(0, 3, 0)))
					character.Parent = character.Parent or workspace
					table.insert(cleanup, character)
					CarService.OnCharacter(p, character)
					table.insert(duelists, p)
					return p, character
				end
				local function told(who, kind)
					local found
					for _, item in sent do
						if item.Player == who and type(item.Message) == "table" and item.Message.Type == kind then
							found = item.Message
						end
					end
					return found
				end
				local function pair(name)
					local a, characterA = rival()
					local b = rival()
					local asked = Duel.Request(a, b) == true and Duel.Pick(a, 1) == true
					flag(name .. "_duel_requested", asked)
					task.spawn(pcall, Duel.Respond, b, true)
					flag(
						name .. "_duel_seated",
						waitFor(5, function()
							return told(a, "Countdown") ~= nil and told(b, "Countdown") ~= nil
						end)
					)
					return a, b, characterA
				end
				local function joinedOut(name, a, b, character)
					eq(name .. "_join_ok", S.Join(a), true)
					eq(name .. "_in_event", S.IsIn(a), true)
					eq(name .. "_gate_set", a:GetAttribute("BossEvent"), true)
					eq(name .. "_duel_state_ended", Duel.StateOf(a), "None")
					eq(name .. "_opponent_state_ended", Duel.StateOf(b), "None")
					eq(name .. "_joiner_result", (told(a, "Result") or {}).Result, "Lose")
					eq(name .. "_opponent_result", (told(b, "Result") or {}).Result, "Win")
					eq(name .. "_opponent_win_counted", b:GetAttribute("DuelWins"), 1)
					flag(
						name .. "_duel_run_gone",
						waitFor(1, function()
							return CarService.GetRun(a) == nil
						end)
					)
					flag(
						name .. "_opponent_off_run",
						waitFor(1, function()
							return not CarService.IsAutoRacing(b)
						end)
					)
					task.wait(0.3) -- the duel's own stop runs on its own thread: it must not undo the teleport
					eq(name .. "_still_in_event", S.IsIn(a), true)
					local spot = (CarService.GetCar(a) or character):GetPivot().Position
					local radius = flatDistance(spot, Arena.Center)
					local want = Arena.LaneRadius(S.LaneOf(a) or 1)
					flag(name .. "_stands_at_lane", math.abs(radius - want) < 6, radius, want)
				end

				local a, b, character = pair("countdown")
				eq("countdown_state", Duel.StateOf(a), "Countdown")
				eq("refused_join_no_event", S.Join(a), false)
				eq("refused_join_keeps_duel", Duel.StateOf(a), "Countdown")
				S.Start("Test")
				joinedOut("countdown", a, b, character)

				a, b, character = pair("racing")
				duelNow += DuelConfig.COUNTDOWN
				Duel.Tick()
				eq("racing_state", Duel.StateOf(a), "Racing")
				joinedOut("racing", a, b, character)

				S.Reset(T0)
			end)
		end

		------------------------------------------------------------------------------------------------------------------------
		local Cfg = H.module(Shared, "BossEventConfig")
		flag("config_exists", Cfg ~= nil)
		local S = H.module(Server, "BossEventService")
		flag("service_exists", S ~= nil)

		if Cfg then
			configSection(Cfg)
		end
		gateSections()
		section("run_mode", runModeSections)
		local oldHooks = S and type(S.Hooks) == "table" and table.clone(S.Hooks)
		if Cfg and S then
			serviceSections(Cfg, S, oldHooks)
		end

		-- Whatever failed above, nothing of this test stays in the live game.
		pcall(function()
			for name, fn in oldHooks or {} do
				S.Hooks[name] = fn
			end
			S.SetClock(nil)
			S.Reset(workspace:GetServerTimeNow())
		end)
		pcall(function()
			local Duel = require(Server.DuelService)
			for _, p in duelists do
				Duel.PlayerLeft(p)
			end
			Duel.SetClock(nil)
			Duel.SetNotify(nil)
		end)
		SpawnArea.START_COOLDOWN = oldCooldown
		gacha.RollInterval, gacha.RollTick, gacha.WaitAfter = oldInterval, oldRollTick, oldWaitAfter
		for _, run in liveRuns do
			pcall(function()
				run:Destroy()
			end)
		end
		for _, item in cleanup do
			pcall(function()
				item:Destroy()
			end)
		end
		local wall = os.clock() - started
		r.metrics.wall_seconds = math.round(wall * 10) / 10
		flag("wall_time_under_40", wall < WALL_LIMIT, wall, WALL_LIMIT)
		return r
	end

	return { boss_event = boss_event }
end

return Tests
