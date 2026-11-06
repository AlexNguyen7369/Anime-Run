--!nonstrict
-- BRIEF: design doc 4.37 and the 2026-11-05 change-log line, docs/BOSS_EVENT_SPEC.md, docs/SIDEKICK_SPEC.md (task b5): the
-- event server. Owner values are asserted literally in "config"; the spec's placeholders are read from the config everywhere
-- else, so retuning one only touches that section.
--
-- Contract these tests assume beyond the brief:
--   Shared/BossEventConfig: IntervalSeconds, PrepSeconds, JoinSeconds, TotalSeconds, IntroSeconds, HpPerPlayer, HitEverySeconds,
--     RefillWaitSeconds, MinDamageShare, ChatMessage, SpeedScale(cruise), TeamDamage(damages, cruise). No rounding.
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
--     TeamDamage(player): the live number. RecordHit(player): one hit of that number, returns what it dealt (0 when it may
--       not hit). No extra argument is read and no remote reaches it. The hit that empties HP ends the event as "Defeated".
--     Hooks, a table of replaceable functions; the defaults are the real game:
--       Arrive(player, lane): stops a normal run through the normal stop, stands the player on the lane.
--       StartRun(player, team, lane): returns the run. Called at the intro's end, or at once for a joiner after it. The service
--         reads only run.TargetSpeed and run.Waiting, and calls run:Destroy().
--       Depart(player): back to spawn. Chat(text): to the whole server, default fires RemoteEvent Remotes.BossEventChat.
--       Rewards(players): on a defeat only, once. A stub until b8 (Relics).
--     Remotes.BossEventLeave: the client's leave option, no arguments, runs Leave(player, "Left") (owner 2026-11-05).
--     Join during a duel's Countdown or Racing: succeeds and ends the duel through DuelService.PlayerLeft (owner 2026-11-05).
--     Init(): boot. Makes the remote, starts the 1 s loop. Called by Main.server. Not `Start`, which starts an event here.
--     Hits: a member's first hit comes one HitEverySeconds after the intro's end, or after joining if later.
--   CarService.PadTouched refuses a player whose attribute BossEvent is true. GachaService.StartAutoRoll does not roll while it is.
--   RaceService.NewRun option Boss = true, with Team = { ids }, on { Path = BossArenaConfig.LaneRoute(n), Pads = {}, Tracks = {} }:
--     stamina without npcMode, distance wraps the closed route. At all empty: run.Waiting = true, RunSpeed 0, runner still,
--     OnRunEvent { Kind = "BossWait" }; after RefillWaitSeconds { Kind = "BossRefill" }, fired with stamina already 100, slot 1
--     and Waiting false. Never "Exhausted", never a cash-out. The run keeps options.Team; the Team attribute does not change.
--
-- READINGS the docs leave open, each pinned by a check and for the owner to confirm (names start with reading_):
--   leave before 3:00: "HP = 4,000 x players in the arena" holds, so max falls by 4,000; current never exceeds max or defeats.
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
		local oldInterval, oldRoll, oldWaitAfter = gacha.RollInterval, gacha.Roll, gacha.WaitAfter

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
				gacha.Roll = function(who, ...)
					if who == p then
						rolls += 1
						return chars[1], nil, nil, false
					end
					return oldRoll(who, ...)
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
				gacha.RollInterval, gacha.Roll, gacha.WaitAfter = oldInterval, oldRoll, oldWaitAfter
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
			local WAIT = 5 -- design doc 4.37, owner value

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
				run = startRun(p, 1, {
					Team = ids,
					StaminaSeconds = { 0.2, 0.2, 0.2 },
					OnRunEvent = function(event)
						table.insert(log, { Kind = event.Kind, T = os.clock() })
						if event.Kind == "BossRefill" then
							atRefill = { Stamina = table.clone(run.Stamina), Slot = run.Slot, Waiting = run.Waiting }
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
				eq("run_swapped_through_team", count("Swap"), 2)
				eq("run_waiting_flag", run.Waiting, true)
				near("run_stamina_empty", run.Stamina[3], 0)
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
				flag("run_wait_is_5_seconds", gap >= WAIT - 0.1 and gap <= WAIT + 0.6, gap, WAIT)
				atRefill = atRefill or { Stamina = {} }
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
				eq("refill_wait_5", Cfg.RefillWaitSeconds, 5)
				eq("chat_message_text", Cfg.ChatMessage, CHAT)
				-- Spec placeholders: the only literal checks of them, retune here
				eq("spec_intro_20", Cfg.IntroSeconds, 20)
				eq("spec_hp_per_player_4000", Cfg.HpPerPlayer, 4000)
				eq("spec_hit_every_1_5", Cfg.HitEverySeconds, 1.5)
				eq("spec_min_share_1_percent", Cfg.MinDamageShare, 0.01)
				eq("spec_hit_matches_sidekick_config", Cfg.HitEverySeconds, SidekickConfig.HitInterval)
				-- Formula: 1 + min(1, cruise / 800), at most +100%
				near("scale_at_0", Cfg.SpeedScale(0), 1)
				near("scale_at_200", Cfg.SpeedScale(200), 1.25)
				near("scale_at_400", Cfg.SpeedScale(400), 1.5)
				near("scale_at_800", Cfg.SpeedScale(800), 2)
				near("scale_capped_at_1600", Cfg.SpeedScale(1600), 2)
				near("team_damage_average_3", Cfg.TeamDamage({ 10, 14, 22 }, 400), 46 / 3 * 1.5)
				near("team_damage_average_2", Cfg.TeamDamage({ 10, 14 }, 0), 12)
				near("team_damage_one", Cfg.TeamDamage({ 10 }, 800), 20)
				near("team_damage_capped", Cfg.TeamDamage({ 22, 22, 22 }, 1600), 44)
				eq("team_damage_empty_is_0", Cfg.TeamDamage({}, 500), 0)
			end)
		end

		local function serviceSections(Cfg, S, realHooks)
			local clock = T0
			local PREP, INTRO, CLOSE, TOTAL = Cfg.PrepSeconds, Cfg.IntroSeconds, Cfg.JoinSeconds, Cfg.TotalSeconds
			local FIGHT = PREP + INTRO -- the intro's end
			local HP = Cfg.HpPerPlayer
			local EVERY = Cfg.HitEverySeconds

			local log
			local function install()
				log = { Arrive = {}, Depart = {}, Chat = {}, Rewards = {}, Started = {}, Runs = {} }
				S.Hooks.Arrive = function(p, lane)
					log.Arrive[p] = lane
				end
				S.Hooks.Depart = function(p)
					log.Depart[p] = (log.Depart[p] or 0) + 1
				end
				S.Hooks.Chat = function(text)
					table.insert(log.Chat, text)
				end
				S.Hooks.Rewards = function(players)
					table.insert(log.Rewards, players)
				end
				S.Hooks.StartRun = function(p, team, lane)
					local run = { TargetSpeed = 0, Waiting = false, Team = team, Lane = lane, Destroyed = 0 }
					function run:Destroy()
						self.Destroyed += 1
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
				eq("phase_intro_is_fight", S.PhaseAt(PREP + 1), "Fight")
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
				eq("timeout_pays_nothing", #log.Rewards, 0)
				eq("timeout_returns_player", log.Depart[p], 1)
			end)

			serviceSection("nobody_came", function()
				begin()
				to(PREP)
				eq("boss_waits_with_nobody", phase(), "Fight")
				eq("nobody_hp_0", S.State().MaxHp, 0)
				walk(CLOSE - STEP)
				eq("nobody_not_defeated_at_0_hp", phase(), "Fight")
				eq("nobody_no_rewards_yet", #log.Rewards, 0)
				to(CLOSE)
				eq("nobody_ends_at_3_00", phase(), "Idle")
				eq("nobody_reported", S.State().LastEnd, "NoPlayers")
				eq("nobody_pays_nothing", #log.Rewards, 0)

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
				eq("defeat_ends_early", phase(), "Idle")
				eq("defeat_reported", S.State().LastEnd, "Defeated")
				eq("defeat_rewards_once", #log.Rewards, 1)
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
				to(PREP + 10)
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
				-- The formula at several cruise values, from what the run reports.
				for _, cruise in { 0, 200, 400, 800, 1600 } do
					run.TargetSpeed = cruise
					near("team_damage_at_" .. cruise, S.TeamDamage(p), Cfg.TeamDamage(list, cruise))
				end
				-- Only the server's number counts.
				run.TargetSpeed = 400
				local expected = Cfg.TeamDamage(list, 400)
				local hp = S.State().Hp
				near("hit_is_server_number", S.RecordHit(p, 1e9, "cheat"), expected)
				near("hit_counts_to_player", S.DamageOf(p), expected)
				near("hit_takes_hp", S.State().Hp, hp - expected)
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local clientHit = false
				for _, item in remotes and remotes:GetChildren() or {} do
					local name = string.lower(item.Name)
					clientHit = clientHit
						or (
							string.find(name, "boss", 1, true)
							and (string.find(name, "hit", 1, true) or string.find(name, "damage", 1, true))
						)
				end
				flag("no_remote_deals_damage", not clientHit)
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
				to(PREP + 5)
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
				near("joiner_grows_current_by_4000_each", S.State().Hp, hurt + 3 * HP)
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

			serviceSection("rewards_list", function()
				begin()
				local big, exact, under, none = fighter(), newPlayer(), newPlayer(), newPlayer()
				-- A Sidekick whose damage divides the 4-player threshold, so "exactly 1 percent" is reachable in whole hits.
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
				for _, p in { big, exact, under, none } do
					log.Runs[p].TargetSpeed = 0
				end
				local need = Cfg.MinDamageShare * S.State().MaxHp
				local hit = S.TeamDamage(exact)
				local hits = math.ceil(need / hit - 1e-9)
				flag("test_threshold_is_whole_hits", approx(hits * hit, need), hits * hit, need)
				for _ = 1, hits do
					S.RecordHit(exact)
				end
				for _ = 1, hits - 1 do
					S.RecordHit(under)
				end
				log.Runs[big].TargetSpeed = 800
				for _ = 1, 1000 do
					if not S.IsIn(big) then
						break
					end
					S.RecordHit(big)
				end
				eq("rewards_on_defeat", S.State().LastEnd, "Defeated")
				eq("rewards_hook_once", #log.Rewards, 1)
				local list = log.Rewards[1] or {}
				flag("rewards_top_damage_listed", table.find(list, big) ~= nil)
				flag("rewards_exactly_1_percent_listed", table.find(list, exact) ~= nil)
				flag("rewards_below_1_percent_not_listed", table.find(list, under) == nil)
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
				eq("leave_before_3_00_lowers_max_4000", S.State().MaxHp, maxFull - HP)

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
				log.Runs[stay].TargetSpeed = 800
				for _ = 1, 10000 do
					if not S.IsIn(stay) then
						break
					end
					S.RecordHit(stay)
				end
				eq("leavers_test_defeat", S.State().LastEnd, "Defeated")
				eq("leavers_rewards_once", #log.Rewards, 1)
				local list = log.Rewards[1] or {}
				flag("stayer_rewarded", table.find(list, stay) ~= nil)
				flag("leaver_in_wait_no_reward", table.find(list, tired) == nil)
				flag("leaver_over_share_no_reward", table.find(list, rich) == nil)
				flag("leaver_after_3_00_no_reward", table.find(list, late) == nil)
				eq("leaver_not_returned_again", log.Depart[rich], 1)
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
				eq("leave_alone_no_rewards", #log.Rewards, 0)

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
				eq("death_no_reward_on_timeout", #log.Rewards, 0)
			end)

			serviceSection("non_participants", function()
				local outsider, rolls = newPlayer(), 0
				outsider:SetAttribute("AutoRoll", true)
				outsider:SetAttribute("NeedsStarter", false)
				gacha.RollInterval = function(who)
					return who == outsider and 0.02 or oldInterval(who)
				end
				gacha.Roll = function(who, ...)
					if who == outsider then
						rolls += 1
						return chars[1], nil, nil, false
					end
					return oldRoll(who, ...)
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
				gacha.RollInterval, gacha.Roll, gacha.WaitAfter = oldInterval, oldRoll, oldWaitAfter
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
				shows("after_join", Cfg.TeamDamage(both, gacha.CruiseFor(p, auto[1], 1)))
				S.SetTeam(p, { b })
				shows("after_pick_one", Cfg.TeamDamage({ damageOf("side_chain") }, gacha.CruiseFor(p, b, 1)))
				S.SetTeam(p, { a, b })
				shows("after_pick_two", Cfg.TeamDamage(both, gacha.CruiseFor(p, a, 1)))
				to(FIGHT)
				local run = log.Runs[p]
				for _, cruise in { 200, 800, 1600 } do
					run.TargetSpeed = cruise
					to(clock - T0 + STEP)
					shows("in_run_at_" .. cruise, Cfg.TeamDamage(both, cruise))
				end
				eq("attr_nil_for_outsider", outsider:GetAttribute("BossTeamDamage"), nil)
				local late = fighter()
				S.Join(late)
				near(
					"attr_late_joiner",
					late:GetAttribute("BossTeamDamage") or -1,
					Cfg.TeamDamage({ damageOf("side_knight") }, log.Runs[late].TargetSpeed) -- a joiner runs at once
				)
				S.Leave(p, "Left")
				eq("attr_nil_after_leave", p:GetAttribute("BossTeamDamage"), nil)
				S.End("Timeout")
				eq("attr_nil_after_end", late:GetAttribute("BossTeamDamage"), nil)
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
				S.Hooks.Rewards = function() end
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
				S.Hooks.Rewards = function() end
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
				S.Hooks.Rewards = function() end
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
				S.Hooks.Rewards = function() end
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
		gacha.RollInterval, gacha.Roll, gacha.WaitAfter = oldInterval, oldRoll, oldWaitAfter
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
