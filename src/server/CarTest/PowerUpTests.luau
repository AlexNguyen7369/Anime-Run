--!nonstrict
-- BRIEF: docs/POWERUP_SPEC.md "Tests" (design doc 4.44, owner 2026-11-11). Written before the feature.
-- API the tests read:
--   Shared/PowerUpConfig: SPEED_MULTI, SPEED_SECONDS, STAMINA_SECONDS, PER_STUDS, EDGE, MIN_GAP,
--     Roll(from, length, rng?) -> { { Id, Kind = "Speed" | "Stamina", Dist } } in Dist order
--   RaceService.NewRun options.PowerUps = true (NPC mode only) rolls each track's set at its start: run.PowerUps
--     (tests may replace it; a Dist already passed is taken on the next tick), run.SpeedLeft (seconds),
--     run.TargetSpeed, run.Stamina[slot]; RunEvent { Kind = "PowerUps", Track, Route, List } and
--     { Kind = "PowerUpTaken", Id, Type, Track }; player attribute PowerSpeedUntil while a boost runs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local SLOW_NPC = 0.001 -- studs/s: the NPC never wins
local UID = 991900000

local Tests = {}

function Tests.powerups()
	local r, flag = H.report("powerups")
	local mods = {
		config = H.module(Shared, "PowerUpConfig"),
		catalog = H.module(Shared, "CharacterCatalog"),
		factory = H.module(Shared, "RunnerFactory"),
		pathDriver = H.module(Shared, "PathDriver"),
		gacha = H.module(Server, "GachaService"),
		data = H.module(Server, "PlayerData"),
		money = H.module(Server, "MoneyService"),
		race = H.module(Server, "RaceService"),
	}
	local cfg = mods.config
	local api = cfg
		and type(cfg.Roll) == "function"
		and cfg.SPEED_MULTI == 1.5
		and cfg.SPEED_SECONDS == 3
		and cfg.STAMINA_SECONDS == 5
		and mods.race
		and type(mods.race.NewRun) == "function"
		and mods.catalog
		and mods.factory
		and mods.gacha
		and mods.data
		and mods.money ~= nil
	flag("powerups_api_exists", api == true)
	if not api then
		return r
	end

	-- 1. Placement on every track of the live route: count, span, gaps (pure roll, many tries)
	local route = mods.race.GetRoute()
	flag("powerups_live_route", type(route) == "table" and type(route.Tracks) == "table" and #route.Tracks >= 1)
	if not route then
		return r
	end
	local arc = mods.pathDriver.Arc(route.Path.WorldWaypoints)
	local countOk, spanOk, gapOk, kindsOk, worstGap = true, true, true, true, math.huge
	for _, t in route.Tracks do
		local from, to = arc[t.StartIndex], arc[t.FinishIndex]
		local length = to - from
		for _ = 1, 20 do
			local list = cfg.Roll(from, length)
			countOk = countOk and #list == math.ceil(length / cfg.PER_STUDS)
			for i, p in list do
				spanOk = spanOk
					and p.Dist >= from + length * cfg.EDGE - 1e-6
					and p.Dist <= to - length * cfg.EDGE + 1e-6
				kindsOk = kindsOk and (p.Kind == "Speed" or p.Kind == "Stamina")
				if i > 1 then
					local gap = p.Dist - list[i - 1].Dist
					worstGap = math.min(worstGap, gap)
					gapOk = gapOk and gap >= cfg.MIN_GAP - 1e-6
				end
			end
		end
	end
	flag("powerups_count_per_track", countOk)
	flag("powerups_inside_middle_span", spanOk)
	flag("powerups_min_gap", gapOk, worstGap, cfg.MIN_GAP)
	flag("powerups_kinds", kindsOk)

	local cleanup, runs = {}, {}
	local ok, err = pcall(function()
		local secret
		for _, spec in mods.catalog.All() do
			if spec.Rarity == "Secret" and (spec.Category or "Balanced") == "Balanced" and not secret then
				secret = spec.Id
			end
		end
		local function start(name, opts)
			UID += 1
			local p = H.player(cleanup, UID)
			p.Name = "CarTestPowerUp_" .. name
			pcall(mods.money.Setup, p)
			pcall(mods.data.Setup, p)
			pcall(mods.gacha.Setup, p)
			local id = opts.Id or mods.catalog.STARTER_ID
			if id ~= mods.catalog.STARTER_ID then
				mods.gacha.Grant(p, id)
			end
			mods.gacha.SetTeam(p, { id })
			local car = mods.factory.build(id)
			car.Name = p.Name
			car.Parent = Workspace
			table.insert(cleanup, car)
			local log = {}
			local speeds = {}
			for _, t in route.Tracks do
				speeds[t.Number] = SLOW_NPC
			end
			local options = {
				Npc = opts.Npc ~= false,
				PowerUps = opts.PowerUps,
				NpcSpeeds = speeds,
				StaminaSeconds = { 20, 20, 20 },
				Duel = opts.Duel,
				OnRunEvent = function(ev)
					table.insert(log, ev)
				end,
			}
			local run = mods.race.NewRun(car, route, p, options)
			table.insert(runs, run)
			return run, p, log
		end
		local function find(log, kind)
			for _, ev in log do
				if ev.Kind == kind then
					return ev
				end
			end
			return nil
		end

		-- 2. A run rolls its first track's set and tells the owner
		local run, p, log = start("Base", { PowerUps = true })
		local t1 = route.Tracks[1]
		local want = math.ceil((arc[t1.FinishIndex] - arc[t1.StartIndex]) / cfg.PER_STUDS)
		flag("powerups_rolled_at_track_start", #run.PowerUps == want, #run.PowerUps, want)
		local setEv = find(log, "PowerUps")
		flag("powerups_set_event", setEv ~= nil and setEv.Track == t1.Number and #setEv.List == want)
		local run2 = start("Other", { PowerUps = true })
		local same = #run2.PowerUps == #run.PowerUps
		for i, x in run.PowerUps do
			same = same and run2.PowerUps[i] and run2.PowerUps[i].Dist == x.Dist and run2.PowerUps[i].Kind == x.Kind
		end
		flag("powerups_per_player_sets_differ", not same)
		local off = start("Off", {})
		flag("powerups_off_without_option", #off.PowerUps == 0)
		local duel = start("Duel", { PowerUps = true, Npc = false, Duel = { Track = t1.Number } })
		flag("powerups_none_in_duel", #duel.PowerUps == 0)
		for _, x in { run2, off, duel } do
			x:Destroy()
		end

		-- 3. Speed: x1.5 for 3 s, then back
		task.wait(0.1)
		local base = run.TargetSpeed
		run.PowerUps = { { Id = 99, Kind = "Speed", Dist = 0 } }
		task.wait(0.15)
		flag("powerups_speed_x1_5", math.abs(run.TargetSpeed - base * 1.5) < 1e-6, run.TargetSpeed, base * 1.5)
		flag("powerups_speed_attribute", type(p:GetAttribute("PowerSpeedUntil")) == "number")
		local taken = find(log, "PowerUpTaken")
		flag("powerups_taken_event", taken ~= nil and taken.Id == 99 and taken.Type == "Speed")
		task.wait(1.5)
		run.PowerUps = { { Id = 98, Kind = "Speed", Dist = 0 } }
		task.wait(0.15)
		flag("powerups_speed_second_resets", run.SpeedLeft > cfg.SPEED_SECONDS - 0.4, run.SpeedLeft, cfg.SPEED_SECONDS)
		task.wait(cfg.SPEED_SECONDS + 0.2)
		flag("powerups_speed_reverts", math.abs(run.TargetSpeed - base) < 1e-6, run.TargetSpeed, base)
		flag("powerups_speed_attribute_cleared", p:GetAttribute("PowerSpeedUntil") == nil)

		-- 4. Stamina: +5 s on the running slot, past 100 (20 s seconds -> +25%)
		run.Stamina[1] = 100
		run.PowerUps = { { Id = 97, Kind = "Stamina", Dist = 0 } }
		task.wait(0.15)
		local added = 100 + cfg.STAMINA_SECONDS * 100 / 20
		flag(
			"powerups_stamina_overfills",
			run.Stamina[1] > added - 2 and run.Stamina[1] <= added,
			run.Stamina[1],
			added
		)
		task.wait(0.2)
		flag(
			"powerups_stamina_attribute_over_100",
			(p:GetAttribute("Stamina1") or 0) > 100,
			p:GetAttribute("Stamina1"),
			100
		)
		run:Destroy()

		-- 5. A Secret at the cap passes MAX_CRUISE during a boost
		if secret then
			local sRun = start("Secret", { PowerUps = true, Id = secret })
			task.wait(0.1)
			local sBase = sRun.TargetSpeed
			sRun.PowerUps = { { Id = 1, Kind = "Speed", Dist = 0 } }
			task.wait(0.15)
			local cap = require(Shared.RaceConfig).MAX_CRUISE
			flag("powerups_speed_passes_cap", sRun.TargetSpeed > cap or sBase * 1.5 <= cap, sRun.TargetSpeed, cap)
			flag("powerups_secret_x1_5", math.abs(sRun.TargetSpeed - sBase * 1.5) < 1e-6, sRun.TargetSpeed, sBase * 1.5)
		end
	end)
	flag("powerups_no_error", ok)
	if not ok then
		r.metrics.error = tostring(err)
	end
	for _, run in runs do
		pcall(function()
			run:Destroy()
		end)
	end
	for _, x in cleanup do
		x:Destroy()
	end
	return r
end

return Tests
