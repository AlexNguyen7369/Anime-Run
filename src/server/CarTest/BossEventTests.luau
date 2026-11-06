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
--         reads only run.TargetSpeed, run.Waiting, run.Slot and run.Stamina, writes run.Stamina[run.Slot], and calls run:Destroy().
--       Depart(player): back to spawn. Chat(text): to the whole server, default fires RemoteEvent Remotes.BossEventChat.
--       Rewards(players): on a defeat only, once. A stub until b8 (Relics).
--       MoveChat(player, text) (owner 2026-11-05): one Big Raga move, to one event player; default fires Remotes.BossEventChat
--         to that player only. Once per attack, shout and wheel_turn move of the shared schedule, inside that move, whatever
--         the Advance step. No move chat in the intro, and never to anyone outside the event.
--     Remotes.BossEventLeave: the client's leave option, no arguments, runs Leave(player, "Left") (owner 2026-11-05).
--     Join during a duel's Countdown or Racing: succeeds and ends the duel through DuelService.PlayerLeft (owner 2026-11-05).
--     Init(): boot. Makes the remotes, starts the loop. Called by Main.server. Not `Start`, which starts an event here.
--     Hits: a member's first hit comes one HitEverySeconds after the intro's end, or after joining if later.
--     Hooks.DamageMulti(t): pure, t in seconds since the spawn; the default is the real Shouted x Adapted. RecordHit deals
--       TeamDamage x DamageMulti(now - spawn). TeamDamage and attribute BossTeamDamage stay uncut. Other sections stub it to 1
--       so their damage sums stay exact.
--     Player attribute BossStatus: JSON list of { Id = "Shouted"|"Adapted", EndsAt (server time) }; nil outside an event. Each
--       player's own: a dodged move leaves it out (design doc 4.37). Hooks.DamageMulti(t, spared) takes the member's dodged moments.
--     Dodge(player, index, stamp) (Remotes.BossDodge): one press of the Dodge bar for moment `index` of Shared/BossDodge. Returns ok,
--       reason. Hooks.SwitchLane(run, lane) moves the dodger's run to a neighbouring lane.
--     An effect starts on its moment and is over at EndsAt. A hit in a long frame's catch-up is not pinned to a moment.
--     AttackImpactsBetween(fromT, toT): pure. How many Big Raga attack Impacts fall in fromT < t <= toT, t in seconds since the
--       spawn (BossRagaPoses.Schedule's now - startTime), 0 for an empty or reversed span. Advance charges each running
--       member AttackStaminaCost per impact, floored at 0, on the slot running at that frame. An impact in a member's wait, or
--       at or before its joining, is never charged.
--     Hooks.BossHits(player, entries) (b7d): one batch to one event player; the default fires RemoteEvent Remotes.BossHits to that
--       player (a Folder test player makes FireClient throw: call it through `safely`). Every event player gets every entry; each
--       player's batches are at least 0.25 s apart by the injected clock, and never empty. An entry is one hit that dealt damage:
--       { UserId, SidekickId, Damage }, nothing else. UserId: Player.UserId, or attribute UserId on a Folder test player.
--       SidekickId: the Sidekick worn by the running character, member.Team[run.Slot] (design doc 4.37). Damage: what RecordHit dealt.
--       A hit waiting for the gap goes out in a later batch. The hit that defeats the boss still reaches the members.
--       A running character whose Sidekick came off mid-event cannot hit: RecordHit returns 0, no entry, no damage (design doc 4.36).
--   Exhaustion view (owner 2026-11-05): player attribute BossWaitEndsAt, server time, set when the team starts its wait,
--     cleared at refill and on leaving. BossEventConfig.WaitCameraCFrame(center, runnerPosition), pure (owner 2026-11-05): the
--     eye about 450 outward of and 320 above the local runner, looking down on the arena. In a 907 px high view at WaitCameraFov the
--     runner shows at least 5 px tall with y at most 790, above the bottom HUD, the wheel top and feet show, and the boss is at least
--     400 px tall. The whole ring need not fit.
--     No runnerPosition: a fixed spot on the boss's front (-Z).
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
				flag("owner_intro_2_to_3", Cfg.IntroSeconds >= 2 and Cfg.IntroSeconds <= 3, Cfg.IntroSeconds, "2 to 3")
				eq("owner_attack_cost_5", Cfg.AttackStaminaCost, 5)
				eq("spec_camera_fov_100", Cfg.CameraFov, 100)
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
				log = {
					Arrive = {},
					Depart = {},
					Chat = {},
					MoveChat = {},
					Rewards = {},
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
				S.Hooks.Rewards = function(players)
					table.insert(log.Rewards, players)
				end
				S.Hooks.BossHits = function(p, entries)
					table.insert(log.BossHits, { Player = p, Entries = table.clone(entries), At = clock - T0 })
				end
				S.Hooks.StartRun = function(p, team, lane)
					local run = {
						TargetSpeed = 0,
						Waiting = false,
						Team = team,
						Lane = lane,
						Destroyed = 0,
						Slot = 1,
						Stamina = { 100, 100, 100 },
					}
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
				near("hit_after_boss_hits_is_server_number", S.RecordHit(p, 1e9, "cheat"), expected)
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
				local COST = Cfg.AttackStaminaCost
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

				-- Each impact once, the running slot only, and no damage to the boss.
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
				close("first_impact_costs_5", run.Stamina[1], 100 - COST)
				close("other_slot_2_untouched", run.Stamina[2], 100)
				close("other_slot_3_untouched", run.Stamina[3], 100)
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
				close("second_impact_costs_5", run.Stamina[1], 100 - 2 * COST)
				to(at(4) + MARGIN)
				close("long_frame_counts_each_impact", run.Stamina[1], 100 - 4 * COST)
				run.Stamina[1] = 50
				to(at(5) + MARGIN)
				close("cost_is_of_a_full_bar", run.Stamina[1], 50 - COST)

				-- One long first frame, from the preparation to past two impacts.
				beginReal()
				local caught = teamOf(1)
				S.Join(caught)
				to(at(2) + MARGIN)
				close("catch_up_from_prep_counts_each", log.Runs[caught].Stamina[1], 100 - 2 * COST)

				-- Under 5% goes to 0; the run's own exhaustion then swaps.
				beginReal()
				local low = teamOf(3)
				S.Join(low)
				to(FIGHT)
				local lowRun = log.Runs[low]
				lowRun.Stamina[1] = 3
				to(at(1))
				eq("under_cost_goes_to_0", lowRun.Stamina[1], 0)
				flag(
					"zero_swaps_as_normal",
					waitFor(1, function()
						return lowRun.Slot == 2
					end)
				)
				eq("zero_one_swap", kindCount(low, "Swap"), 1)
				close("swap_target_untouched", lowRun.Stamina[2], 100)
				to(at(2) + MARGIN)
				close("next_impact_costs_new_runner", lowRun.Stamina[2], 100 - COST)
				eq("swapped_runner_kept_at_0", lowRun.Stamina[1], 0)

				-- reading_: two impacts in one frame fall on the slot running at that frame; the rest of the cost is not moved on.
				beginReal()
				local over = teamOf(3)
				S.Join(over)
				to(FIGHT)
				log.Runs[over].Stamina[1] = 7
				to(at(2) + MARGIN)
				eq("reading_catch_up_floors_at_0", log.Runs[over].Stamina[1], 0)
				close("reading_catch_up_next_slot_untouched", log.Runs[over].Stamina[2], 100)

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
				close("after_wait_next_impact_costs", waitRun.Stamina[1], 40 - COST)

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
				close("member_pays_both", log.Runs[a].Stamina[1], 100 - 2 * COST)
				close("joiner_on_the_impact_pays_later_one", log.Runs[onImpact].Stamina[1], 100 - COST)
				close("late_joiner_pays_later_one", log.Runs[later].Stamina[1], 100 - COST)
				close("outsider_unaffected", outsiderRun.Stamina[1], 100)
				outsiderRun:Destroy()
				S.Reset(T0)
			end)

			-- Owner 2026-11-05 (spec "Run rules"): Shouted and Adapted, from the shared schedule. Times are seconds since the spawn.
			serviceSection("boss_status", function()
				local Poses = require(Shared.BossRagaPoses)
				local HttpService = game:GetService("HttpService")
				eq("status_shout_cut", Cfg.ShoutDamageCut, 0.25)
				eq("status_shout_seconds", Cfg.ShoutSeconds, 5)
				eq("status_adapted_cut", Cfg.AdaptedCut, 0.1)
				eq("status_adapted_seconds", Cfg.AdaptedSeconds, 5)
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
					return (active(roars, Cfg.ShoutSeconds, t) and 0.75 or 1)
						* (active(clicks, Cfg.AdaptedSeconds, t) and 0.9 or 1)
				end
				-- A clear moment and a moment for each state, past the edges by MARGIN.
				local function findTime(wantShout, wantAdapted)
					for k = 0, math.ceil(3 * Poses.CycleSeconds / 0.05) do
						local t = INTRO + k * 0.05
						local same = true
						for _, probe in { t - MARGIN, t, t + MARGIN } do
							same = same
								and active(roars, Cfg.ShoutSeconds, probe) == wantShout
								and active(clicks, Cfg.AdaptedSeconds, probe) == wantAdapted
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
				eq("status_both_listed", #status(), 2)

				-- Edges and EndsAt, in server time, off the injected clock.
				beginHeld()
				S.Hooks.DamageMulti = realHooks.DamageMulti
				local spawnAt = T0 + PREP
				local roar, click = roars[1], clicks[1]
				to(PREP + roar - MARGIN)
				eq(
					"status_not_before_roar",
					(select(2, statusOf("Shouted"))),
					active(roars, Cfg.ShoutSeconds, roar - MARGIN) and 1 or 0
				)
				to(PREP + roar + MARGIN)
				local row = statusOf("Shouted")
				flag("status_roar_starts", row ~= nil)
				near(
					"status_shouted_ends_at",
					row and math.round(row.EndsAt * 100) / 100,
					math.round((spawnAt + roar + 5) * 100) / 100
				)
				to(PREP + roar + 5 + MARGIN)
				eq(
					"status_shouted_expires",
					(select(2, statusOf("Shouted"))),
					active(roars, 5, roar + 5 + MARGIN) and 1 or 0
				)
				beginHeld()
				S.Hooks.DamageMulti = realHooks.DamageMulti
				to(PREP + click + MARGIN)
				local adapted = statusOf("Adapted")
				near(
					"status_adapted_ends_at",
					adapted and math.round(adapted.EndsAt * 100) / 100,
					math.round((spawnAt + click + 5) * 100) / 100
				)
				S.Advance(clock)
				eq("status_no_stacking", (select(2, statusOf("Adapted"))), 1)
				to(PREP + click + 5 + MARGIN)
				eq(
					"status_adapted_expires",
					(select(2, statusOf("Adapted"))),
					active(clicks, 5, click + 5 + MARGIN) and 1 or 0
				)

				-- The pure multiplier, every moment of the schedule, so a refresh (if the schedule ever gives one) is judged too.
				local worst = 0
				for k = 0, math.ceil(3 * Poses.CycleSeconds / 0.25) do
					local t = INTRO + k * 0.25 + 0.03
					if expected(t - MARGIN) == expected(t + MARGIN) then
						worst = math.max(worst, math.abs(realHooks.DamageMulti(t) - expected(t)))
					end
				end
				flag("status_multi_matches_schedule", worst < 1e-6, worst, 0)
				eq("status_multi_none_in_rise", realHooks.DamageMulti(INTRO / 2), 1)

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
					local spot = BossDodge.Spot(1234, T0, index)
					eq("spot_stable_" .. index, BossDodge.Spot(1234, T0, index), spot)
					lowest = math.min(lowest, spot)
					seen[math.floor(spot * 20)] = true
					latest = math.max(latest, select(2, BossDodge.Window(spot, 0)))
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
					differs = differs or BossDodge.Spot(1234, T0, index) ~= BossDodge.Spot(5678, T0, index)
				end
				flag("spot_differs_per_player", differs)

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
					return BossDodge.Window(BossDodge.Spot(id, T0, index), T0 + momentT(index))
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
				eq("hit_impact_costs_stamina", runB.Stamina[1], 100 - Cfg.AttackStaminaCost)
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
				near("leave_takes_4000_from_current", S.State().Hp, hurt - HP)
				eq("leave_takes_4000_from_max", S.State().MaxHp, max - HP)

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

			-- Owner 2026-11-05. The moves are read off the shared schedule; a line may come anywhere inside its move.
			serviceSection("move_chat", function()
				flag("move_chat_default_hook_exists", type(realHooks.MoveChat) == "function")
				local Poses = require(Shared.BossRagaPoses)
				local WORDS = {
					attack = "Big Raga attacks! -5% stamina",
					shout = "Big Raga shouts! Damage down for 5 s",
					wheel_turn = "Big Raga turns its wheel! It takes 10% less damage for 5 s",
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
					shape = shape and keys == 3 and type(entry.Damage) == "number"
				end
				for _, entry in entriesTo(a, a) do
					sameId = sameId and entry.SidekickId == "side_knight"
					near("hit_events_a_damage", entry.Damage, S.TeamDamage(a))
				end
				for _, entry in entriesTo(a, b) do
					sameB = sameB and entry.SidekickId == "side_chain"
					near("hit_events_b_damage", entry.Damage, S.TeamDamage(b))
				end
				flag("hit_events_entry_has_only_three_fields", shape)
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

				-- The running character's Sidekick is the one that fires; the team's damage stays the team's.
				begin()
				local team = fighter()
				wear(team, chars[2], "side_chain")
				S.Join(team)
				eq("hit_events_team_set", S.SetTeam(team, { chars[1], chars[2] }), true)
				walk(FIGHT)
				local run = log.Runs[team]
				run.Slot = 2
				walk(FIGHT + EVERY + HALF)
				local heard = entriesTo(team)
				eq("hit_events_slot_two_entry", #heard, 1)
				eq("hit_events_slot_two_id", heard[1] and heard[1].SidekickId, "side_chain")
				near("hit_events_slot_two_damage", heard[1] and heard[1].Damage, S.TeamDamage(team))
				run.Slot = 1
				walk(FIGHT + EVERY * 2 + HALF)
				heard = entriesTo(team)
				eq("hit_events_slot_one_id", heard[2] and heard[2].SidekickId, "side_knight")

				-- No client number is read.
				local before = #entriesTo(team)
				near("hit_events_cheat_ignored", S.RecordHit(team, 1e9, "side_fox"), S.TeamDamage(team))
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
				run.Slot = 2
				eq("hit_events_no_sidekick_refused", S.RecordHit(team), 0)
				walk(clock - T0 + EVERY * 2)
				eq("hit_events_no_sidekick_no_entry", #entriesTo(team), before)
				eq("hit_events_no_sidekick_no_hp_lost", S.State().Hp, hp)
				eq("hit_events_no_sidekick_no_damage", S.DamageOf(team), damage)
				run.Slot = 1
				walk(clock - T0 + EVERY * 2)
				flag("hit_events_worn_slot_hits_again", #entriesTo(team) > before, #entriesTo(team), before + 1)

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
				eq("hit_events_defeat_ended", phase(), "Idle")
				eq("hit_events_defeat_one_entry", #entriesTo(killer), 1)
				near("hit_events_defeat_entry_is_hp_left", entriesTo(killer)[1] and entriesTo(killer)[1].Damage, maxHp)

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
					local MIN_RUNNER_PX, MIN_BOSS_PX, MAX_RUNNER_Y = 5, 400, 790
					local EYE_OUT, EYE_UP, EYE_SLACK = 450, 320, 50 -- studs from the runner: "about"
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
					local feetOfBoss, wheelTop = Arena.Center, Arena.Center + Vector3.yAxis * Arena.BossTotalHeight
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
					S.Hooks.Rewards = function() end
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
