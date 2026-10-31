--!nonstrict
-- BRIEF: docs/TEAM_AND_STAMINA_SPEC.md "Tests (to write first)", the c1 part (goal core): `team` and `stamina`.
-- Design doc sections 2, 4.2, 4.3, 7. Written by test-writer BEFORE the feature; never loosen a limit to make it pass.
-- Not here (c2): runner categories, the Stamina stat point, the potion, the team bonus (`team_bonus`). The drain
-- check therefore uses Balanced characters only, in a team of 1 (no bonus), with no stat points and no potion.
--
-- API the tests read (test seams marked "seam" are not named by the spec):
--   GachaService.SetTeam(player, ids) -> ok, reason       spec "Team": 1-3 distinct owned string ids, on foot only
--   GachaService.CruiseMultisFor(player, id) -> car, aura, trail   seam: CruiseMultis for that character (swap speed)
--   player attribute Team (comma-joined ids); "on foot" = player attribute AutoRacing ~= true (CarService state)
--   GachaService.Setup sets Team = STARTER_ID for a new player; PlayerData.Load / Save keep `Team = { ids }`
--   Remotes.SetTeam (RemoteFunction or RemoteEvent), Remotes.RunEvent (RemoteEvent)
--   Shared/StaminaConfig: BASE[rarity] (seconds), Base(spec) -> spec.Stamina or BASE[spec.Rarity]
--   RaceService.NewRun(car, route, player, options): the run reads the player's Team at start and holds
--     run.Slot (1-3) and run.Stamina[slot] (0-100); player attributes RunSlot, Stamina1..3.
--     options.StaminaSeconds = { s1, s2, s3 } (seam, like NpcSpeeds): effective stamina seconds per slot.
--     options.OnRunEvent(event) (seam, like OnRaceEvent): every RunEvent payload, called after the server applied
--       it (new slot and cruise speed already set, bank already paid).
--     Tests may set run.Stamina[slot] (as they may set Driver.Index); the next tick drains from that value.
--   Run bank (owner 2026-10-30, spec "Run end by exhaustion"): a win adds its payout to run.Unbanked (not paid);
--     exhaustion cashes it out once; a loss empties it. A loss reset is a new run: by the time the "Reset" race
--     event is emitted, run.Slot = 1, RunSlot = 1 and every slot's stamina is 100.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local FIXED_BASE = { Mythic = 36, Secret = 43 } -- owner 2026-10-30; the others are placeholders
local DRAIN_TOL = 0.01 -- spec: drain rate per rarity within 1%
local SPEED_TOL = 1e-3 -- swap cruise: the stat grows a hair between the swap and the read
local SLOW_NPC = 0.001 -- studs/s: the NPC never wins
local FAST_NPC = 1e7 -- studs/s: the NPC always wins
local OLD_VERSION = 12 -- the save VERSION before Team (PlayerData)
local UID = 991400000

local Tests = {}

local function near(a, b, rel)
	return type(a) == "number" and type(b) == "number" and a == a and math.abs(a - b) <= rel * math.max(1, math.abs(b))
end

local function fakePlayer(cleanup, mods, name)
	UID += 1
	local p = H.player(cleanup, UID)
	p.Name = "CarTestTeam_" .. name
	pcall(mods.money.Setup, p)
	pcall(mods.data.Setup, p)
	pcall(mods.gacha.Setup, p)
	return p, UID
end

local function rollableIds(catalog, count)
	local ids = {}
	for _, spec in catalog.Rollable() do
		if #ids < count then
			table.insert(ids, spec.Id)
		end
	end
	return ids
end

function Tests.team()
	local r, flag = H.report("team")
	local mods = {
		catalog = H.module(Shared, "CharacterCatalog"),
		gacha = H.module(Server, "GachaService"),
		data = H.module(Server, "PlayerData"),
		money = H.module(Server, "MoneyService"),
	}
	local api = mods.catalog
		and mods.gacha
		and mods.data
		and mods.money
		and type(mods.gacha.SetTeam) == "function"
		and type(mods.gacha.Grant) == "function"
		and type(mods.data.SetStore) == "function"
		and type(mods.data.Load) == "function"
		and type(mods.data.Save) == "function"
		and type(mods.data.KeyFor) == "function"
	flag("team_api_exists", api == true)
	if not api then
		return r
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("SetTeam")
	flag("team_remote_exists", remote ~= nil and (remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent")))

	local gacha, data, STARTER = mods.gacha, mods.data, mods.catalog.STARTER_ID
	local ids = rollableIds(mods.catalog, 5) -- ids[5] is never granted: unowned
	local cleanup = {}
	local ok, err = pcall(function()
		-- 1. SetTeam validation
		local p = fakePlayer(cleanup, mods, "Validate")
		flag("team_new_player_is_starter", p:GetAttribute("Team") == STARTER, tostring(p:GetAttribute("Team")), STARTER)
		for i = 1, 4 do
			gacha.Grant(p, ids[i])
		end
		flag("team_set_one_ok", gacha.SetTeam(p, { ids[1] }) == true and p:GetAttribute("Team") == ids[1])
		local three = table.concat({ ids[3], ids[1], ids[2] }, ",")
		flag(
			"team_set_three_keeps_order",
			gacha.SetTeam(p, { ids[3], ids[1], ids[2] }) == true and p:GetAttribute("Team") == three,
			tostring(p:GetAttribute("Team")),
			three
		)
		local rejects = {
			empty = {},
			four_ids = { ids[1], ids[2], ids[3], ids[4] },
			duplicate = { ids[1], ids[1] },
			unowned = { ids[1], ids[5] },
			unknown_id = { "cartest_no_such_character" },
			not_table = ids[1],
			not_string = { ids[1], 7 },
			not_array = { Lead = ids[1] },
		}
		for name, value in rejects do
			local okSet = gacha.SetTeam(p, value)
			flag(
				"team_reject_" .. name,
				okSet == false and p:GetAttribute("Team") == three,
				tostring(p:GetAttribute("Team")),
				three
			)
		end
		p:SetAttribute("AutoRacing", true)
		local okRun = gacha.SetTeam(p, { ids[4] })
		flag("team_reject_mid_run", okRun == false and p:GetAttribute("Team") == three)
		p:SetAttribute("AutoRacing", false)
		flag("team_set_on_foot_ok", gacha.SetTeam(p, { ids[4] }) == true and p:GetAttribute("Team") == ids[4])

		-- 2. Load: unowned ids removed, empty falls back to the starter, old single-Equipped saves become a Team
		local base = UID + 100
		local cases = {
			{ Name = "fresh", Record = nil, Want = STARTER },
			{
				Name = "unowned_removed",
				Record = { Version = OLD_VERSION + 1, Cars = { ids[1], ids[2] }, Team = { ids[1], ids[5], ids[2] } },
				Want = ids[1] .. "," .. ids[2],
			},
			{
				Name = "all_unowned_starter",
				Record = { Version = OLD_VERSION + 1, Cars = { ids[1] }, Team = { ids[5] } },
				Want = STARTER,
			},
			{
				Name = "old_equipped",
				Record = { Version = OLD_VERSION, Cars = { ids[1], ids[2] }, Equipped = ids[2] },
				Want = ids[2],
			},
			{
				Name = "old_equipped_unowned",
				Record = { Version = OLD_VERSION, Cars = { ids[1] }, Equipped = ids[5] },
				Want = STARTER,
			},
			{ Name = "round_trip", Record = nil, Want = STARTER },
		}
		local records = {}
		for i, case in cases do
			case.Uid = base + i
			if case.Record then
				case.Record.Money, case.Record.Speed, case.Record.WorkshopLevel = 10, 1000, 1
				records[data.KeyFor(case.Uid)] = case.Record
			end
		end
		local store = H.store(records)
		data.SetStore(store)
		local players = {}
		for _, case in cases do
			local lp = H.player(cleanup, case.Uid)
			lp.Name = "CarTestTeamLoad_" .. case.Name
			players[case.Name] = lp
			local loaded = data.Load(lp, case.Uid) == true
			flag(
				"team_load_" .. case.Name,
				loaded and lp:GetAttribute("Team") == case.Want,
				tostring(lp:GetAttribute("Team")),
				case.Want
			)
		end

		-- 3. Save round-trip (order kept, VERSION bumped, stamina never saved); old save migrates on save
		local rp, rid = players.round_trip, base + #cases
		for i = 1, 3 do
			gacha.Grant(rp, ids[i])
		end
		gacha.SetTeam(rp, { ids[2], ids[3], ids[1] })
		flag("team_save_ok", data.Save(rp, rid, true) == true)
		local rec = store.data[data.KeyFor(rid)]
		flag("team_saved_in_order", type(rec) == "table" and H.same(rec.Team, { ids[2], ids[3], ids[1] }))
		flag(
			"team_save_version_bumped",
			type(rec) == "table" and type(rec.Version) == "number" and rec.Version > OLD_VERSION,
			type(rec) == "table" and rec.Version or -1,
			OLD_VERSION + 1
		)
		local stamina = false
		for key in type(rec) == "table" and rec or {} do
			stamina = stamina or string.find(string.lower(tostring(key)), "stamina", 1, true) ~= nil
		end
		flag("team_stamina_never_saved", type(rec) == "table" and not stamina)
		local again = H.player(cleanup, rid)
		again.Name = "CarTestTeamReload"
		flag(
			"team_round_trip_loads_same",
			data.Load(again, rid) == true
				and again:GetAttribute("Team") == table.concat({ ids[2], ids[3], ids[1] }, ",")
		)
		local old = players.old_equipped
		data.Save(old, cases[4].Uid, true)
		local oldRec = store.data[data.KeyFor(cases[4].Uid)]
		flag("team_old_save_migrates_on_save", type(oldRec) == "table" and H.same(oldRec.Team, { ids[2] }))
	end)
	flag("team_no_error", ok)
	if not ok then
		r.metrics.error = tostring(err)
	end
	pcall(data.SetStore, nil)
	for _, x in cleanup do
		x:Destroy()
	end
	return r
end

function Tests.stamina()
	local r, flag = H.report("stamina")
	local m = r.metrics
	local mods = {
		catalog = H.module(Shared, "CharacterCatalog"),
		config = H.module(Shared, "StaminaConfig"),
		raceConfig = H.module(Shared, "RaceConfig"),
		factory = H.module(Shared, "RunnerFactory"),
		gacha = H.module(Server, "GachaService"),
		data = H.module(Server, "PlayerData"),
		money = H.module(Server, "MoneyService"),
		race = H.module(Server, "RaceService"),
	}
	local api = mods.catalog
		and mods.config
		and mods.raceConfig
		and mods.factory
		and mods.gacha
		and mods.data
		and mods.money
		and mods.race
		and type(mods.config.BASE) == "table"
		and type(mods.config.Base) == "function"
		and type(mods.gacha.SetTeam) == "function"
		and type(mods.gacha.CruiseMultisFor) == "function"
		and type(mods.race.NewRun) == "function"
		and type(mods.race.GetRoute) == "function"
		and type(mods.factory.build) == "function"
	flag("stamina_api_exists", api == true)
	if not api then
		return r
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local runEvent = remotes and remotes:FindFirstChild("RunEvent")
	flag("stamina_run_event_remote", runEvent ~= nil and runEvent:IsA("RemoteEvent"))
	local catalog, config, gacha, data, race = mods.catalog, mods.config, mods.gacha, mods.data, mods.race
	local STARTER = catalog.STARTER_ID

	-- 1. Base stamina from rarity (Mythic 36, Secret 43 fixed; the rest placeholders that rise with rarity)
	local prev, rising = 0, true
	for _, rarity in RARITIES do
		local b = config.BASE[rarity]
		rising = rising and type(b) == "number" and b > 0 and b >= prev
		prev = type(b) == "number" and b or math.huge
	end
	flag("stamina_base_rises_with_rarity", rising)
	flag(
		"stamina_base_mythic_36_secret_43",
		config.BASE.Mythic == FIXED_BASE.Mythic and config.BASE.Secret == FIXED_BASE.Secret
	)
	local fromRarity = true
	for _, spec in catalog.All() do
		if spec.Stamina == nil and config.Base(spec) ~= config.BASE[spec.Rarity] then
			fromRarity = false
		end
	end
	flag("stamina_base_from_rarity", fromRarity and config.Base(catalog.Get(STARTER)) == config.BASE.Common)
	flag("stamina_catalog_override", config.Base({ Id = "cartest", Rarity = "Common", Stamina = 50 }) == 50)

	local route = race.GetRoute()
	local routeOk = type(route) == "table" and type(route.Tracks) == "table" and #route.Tracks >= 2
	flag("stamina_live_route", routeOk)
	if not routeOk then
		return r
	end
	local track1, track2 = route.Tracks[1], route.Tracks[2]

	local cleanup, ctxs = {}, {}
	local function moneyOf(p)
		local stats = p:FindFirstChild("leaderstats")
		local money = stats and stats:FindFirstChild("Money")
		return money and money.Value or -1
	end
	-- Starts a solo NPC run for `team` (granted first); opts: Player (reuse), Seconds, NpcSpeeds { [number] = speed }
	local function start(name, team, opts)
		opts = opts or {}
		local p = opts.Player or fakePlayer(cleanup, mods, name)
		p.BaseSpeed.Value = 0
		for _, id in team do
			if id ~= STARTER then
				gacha.Grant(p, id)
			end
		end
		local ctx = { Name = name, Player = p, Team = team, Log = {}, Samples = {} }
		ctx.TeamOk = gacha.SetTeam(p, team) == true
		local car = mods.factory.build(team[1])
		car.Name = "CarTestStamina_" .. name
		car.Parent = Workspace
		table.insert(cleanup, car)
		ctx.Car = car
		local speeds = {}
		for _, t in route.Tracks do
			speeds[t.Number] = opts.NpcSpeeds and opts.NpcSpeeds[t.Number] or SLOW_NPC
		end
		local function log(kind, ev)
			if type(ev) == "table" then
				local run = ctx.Run
				table.insert(ctx.Log, {
					Kind = kind,
					Event = ev,
					T = os.clock(),
					Money = moneyOf(p),
					TargetSpeed = run and run.TargetSpeed,
					Stat = data.SpeedStat(p),
					Slot = run and run.Slot,
					Stamina = run and type(run.Stamina) == "table" and table.clone(run.Stamina) or nil,
					RunSlot = p:GetAttribute("RunSlot"),
				})
			end
		end
		local okRun, run = pcall(race.NewRun, car, route, p, {
			Loop = true,
			Npc = true,
			NpcSpeeds = speeds,
			StaminaSeconds = opts.Seconds,
			OnRaceEvent = function(ev)
				log("Race", ev)
			end,
			OnRunEvent = function(ev)
				log("Run", ev)
			end,
		})
		ctx.Run = okRun and type(run) == "table" and run or nil
		ctx.err = not okRun and tostring(run) or nil
		ctx.T0 = os.clock()
		table.insert(ctxs, ctx)
		-- stamina is 100% on every run start, slot 1 first
		local st = ctx.Run and ctx.Run.Stamina
		local full = type(st) == "table" and ctx.Run.Slot == 1 and p:GetAttribute("RunSlot") == 1
		for slot = 1, #team do
			full = full and st[slot] == 100 and p:GetAttribute("Stamina" .. slot) == 100
		end
		ctx.StartFull = full == true
		return ctx
	end
	local function runEvents(ctx, kind)
		local list = {}
		for _, e in ctx.Log do
			if e.Kind == "Run" and e.Event.Kind == kind then
				table.insert(list, e)
			end
		end
		return list
	end
	local function firstIndex(ctx, pred)
		for i, e in ctx.Log do
			if pred(e) then
				return i
			end
		end
		return nil
	end

	-- characters: one Balanced per rarity for the drain check (the starter for Common), 3 for the swap team
	local balanced = { Common = STARTER }
	for _, spec in catalog.All() do
		if spec.Category == "Balanced" and spec.Stamina == nil and balanced[spec.Rarity] == nil then
			balanced[spec.Rarity] = spec.Id
		end
	end
	local trio = rollableIds(catalog, 3)

	local ok, err = pcall(function()
		local drains = {}
		for _, rarity in RARITIES do
			if balanced[rarity] then
				drains[rarity] = start("Drain" .. rarity, { balanced[rarity] })
			end
		end
		local swap = start("Swap", trio, { Seconds = { 0.5, 0.5, 0.5 } })
		local duo = start("Duo", { trio[1], trio[2] }, { Seconds = { 0.4, 0.4 } })
		local solo = start("Solo", { trio[1] }, { Seconds = { 0.4 } })
		local tie = start("Tie", { trio[1] }, { Seconds = { 30 }, NpcSpeeds = { [track2.Number] = FAST_NPC } })
		local refill = start(
			"Refill",
			{ trio[1], trio[2] },
			{ Seconds = { 0.3, 30 }, NpcSpeeds = { [track1.Number] = FAST_NPC } }
		)

		-- drive: drain samples, a track-1 win for Swap (so a bank may exist), the same-tick loss for Tie
		local drainA, drainB = 0.3, 2.8
		local tieStep = 0
		local t0 = os.clock()
		while os.clock() - t0 < 3.2 do
			RunService.Heartbeat:Wait()
			local now = os.clock()
			for _, ctx in ctxs do
				local run = ctx.Run
				if run then
					local exhausted = #runEvents(ctx, "Exhausted") > 0
					if not exhausted then
						ctx.MoneyBefore, ctx.UnbankedBefore = moneyOf(ctx.Player), run.Unbanked
					elseif not ctx.ExhaustedDist then
						ctx.ExhaustedDist = ctx.Car:GetAttribute("RunDistance")
					end
					ctx.Slots = ctx.Slots or {}
					local slot = ctx.Player:GetAttribute("RunSlot")
					if slot ~= ctx.Slots[#ctx.Slots] then
						table.insert(ctx.Slots, slot)
					end
					ctx.MaxSlot = math.max(ctx.MaxSlot or 0, type(run.Slot) == "number" and run.Slot or 0)
				end
			end
			for _, ctx in drains do
				local st = ctx.Run and ctx.Run.Stamina
				if type(st) == "table" then
					if not ctx.A and now - ctx.T0 >= drainA then
						ctx.A = { T = now, S = st[1] }
					elseif ctx.A and not ctx.B and now - ctx.T0 >= drainB then
						ctx.B = { T = now, S = st[1] }
					end
				end
			end
			if swap.Run and not swap.Jumped and now - swap.T0 >= 0.15 then
				swap.Jumped = true
				swap.Run.Driver.Index = track1.FinishIndex
			end
			if refill.Run and not refill.Jumped and refill.Run.Slot == 2 then
				refill.Jumped = true
				refill.Run.Driver.Index = track1.FinishIndex -- fast NPC: a loss while slot 2 runs
			end
			local tr = tie.Run
			if tr then
				if tieStep == 0 and now - tie.T0 >= 0.15 then
					tieStep = 1
					tr.Driver.Index = track1.FinishIndex -- slow NPC: a win, then Track 2 against the fast NPC
				elseif tieStep == 1 and tr.RaceTrack == track2.Number then
					tieStep = 2
					tie.MoneyAtTie = moneyOf(tie.Player)
					tie.PotAtTie = tr.Unbanked
					tie.TieAt = #tie.Log
					tr.Stamina[1] = 1e-9 -- empties on the same tick the runner reaches Track 2's finish
					tr.Driver.Index = track2.FinishIndex
				end
			end
		end

		-- 2. Drain rate per rarity (Balanced, team of 1: Stamina = Base): 100 / Base percent per second
		local worst, measured = 0, {}
		for rarity, ctx in drains do
			local want = 100 / config.Base(catalog.Get(balanced[rarity]))
			local got = ctx.A and ctx.B and (ctx.A.S - ctx.B.S) / (ctx.B.T - ctx.A.T) or -1
			local e = got > 0 and math.abs(got - want) / want or math.huge
			worst = math.max(worst, e)
			table.insert(measured, ("%s=%.3f/%.3f"):format(rarity, got, want))
		end
		m.drain = table.concat(measured, " ")
		flag("stamina_drain_rate_per_rarity", next(drains) ~= nil and worst <= DRAIN_TOL, worst, DRAIN_TOL)

		-- 3. 100% on every run start (all fresh runs above, and a second run after an exhaustion)
		local allFull = true
		for _, ctx in ctxs do
			allFull = allFull and ctx.TeamOk and ctx.StartFull
		end
		flag("stamina_full_on_run_start", allFull)

		-- 4. Swap at 0 to the next slot, at the new runner's cruise speed, same race
		local swaps = runEvents(swap, "Swap")
		local order = #swaps == 2
			and swaps[1].Event.From == trio[1]
			and swaps[1].Event.To == trio[2]
			and swaps[1].Event.Slot == 2
			and swaps[2].Event.From == trio[2]
			and swaps[2].Event.To == trio[3]
			and swaps[2].Event.Slot == 3
		flag("stamina_swap_to_next_slot", order, #swaps, 2)
		flag(
			"stamina_run_slot_attribute",
			H.same(swap.Slots, { 1, 2, 3 }),
			table.concat(swap.Slots or {}, ","),
			"1,2,3"
		)
		local cruiseOk = #swaps == 2
		for _, e in swaps do
			local want = mods.raceConfig.SpeedFor(e.Stat, gacha.CruiseMultisFor(swap.Player, e.Event.To))
			cruiseOk = cruiseOk and near(e.TargetSpeed, want, SPEED_TOL)
		end
		flag("stamina_swap_cruise_at_once", cruiseOk)
		flag(
			"stamina_swap_keeps_race",
			swap.Run ~= nil and swap.Run.Losses == 0 and swap.Run.Resets == 0 and swap.Run.Wins >= 1
		)

		-- 5. Exhaustion: once, pays the bank (filled by the Track 1 win, so > 0) once, not a loss, the run stops
		local ex = runEvents(swap, "Exhausted")
		flag("stamina_exhausted_once", #ex == 1, #ex, 1)
		local banked = ex[1] and ex[1].Event.Banked
		local paid = moneyOf(swap.Player) - (swap.MoneyBefore or 0)
		flag(
			"stamina_exhaustion_cashes_out_bank_once",
			type(banked) == "number" and banked > 0 and banked == (swap.UnbankedBefore or 0) and paid == banked,
			paid,
			banked or -1
		)
		local lost = firstIndex(swap, function(e)
			return e.Kind == "Race" and e.Event.Type == "Result" and e.Event.Result == "Lose"
		end)
		flag("stamina_exhaustion_not_a_loss", #ex == 1 and lost == nil)
		local stopped = swap.Car.Parent == nil or swap.Car:GetAttribute("RunDistance") == swap.ExhaustedDist
		flag("stamina_exhaustion_stops_run", #ex == 1 and stopped)

		-- 6. Empty slots skipped: a team of 2 never reaches slot 3; a team of 1 never swaps
		local duoSwaps = runEvents(duo, "Swap")
		flag(
			"stamina_empty_slots_skipped",
			#duoSwaps == 1
				and duoSwaps[1].Event.Slot == 2
				and duo.MaxSlot == 2
				and #runEvents(duo, "Exhausted") == 1
				and #runEvents(solo, "Swap") == 0
				and #runEvents(solo, "Exhausted") == 1,
			#duoSwaps,
			1
		)

		-- 7. NPC finish and exhaustion on the same tick: the loss is decided first and the bank is emptied
		local lose = firstIndex(tie, function(e)
			return e.Kind == "Race"
				and e.Event.Type == "Result"
				and e.Event.Result == "Lose"
				and e.Event.Track == track2.Number
		end)
		local exTie = firstIndex(tie, function(e)
			return e.Kind == "Run" and e.Event.Kind == "Exhausted"
		end)
		flag(
			"stamina_same_tick_loss_wins",
			tieStep == 2 and lose ~= nil and lose > (tie.TieAt or 0) and (exTie == nil or exTie > lose)
		)
		local cashed = false
		for _, e in runEvents(tie, "Exhausted") do
			cashed = cashed or e.Event.Banked ~= 0
		end
		flag(
			"stamina_same_tick_loss_empties_bank",
			tieStep == 2
				and type(tie.PotAtTie) == "number"
				and tie.PotAtTie > 0
				and moneyOf(tie.Player) == tie.MoneyAtTie
				and not cashed
				and (tie.Run.Unbanked or 0) == 0,
			moneyOf(tie.Player) - (tie.MoneyAtTie or 0),
			0
		)

		-- 8. A loss reset starts a new run (owner 2026-10-30): slot 1, every slot back to 100
		local reset = nil
		for _, e in refill.Log do
			if not reset and e.Kind == "Race" and e.Event.Type == "Reset" then
				reset = e
			end
		end
		local refilled = refill.Jumped == true
			and reset ~= nil
			and reset.Slot == 1
			and reset.RunSlot == 1
			and type(reset.Stamina) == "table"
			and reset.Stamina[1] == 100
			and reset.Stamina[2] == 100
		flag("stamina_loss_reset_refills", refilled, reset and reset.Stamina and reset.Stamina[1] or -1, 100)

		-- 3b. A second run after the exhaustion starts full again
		if swap.Run then
			swap.Run:Destroy()
		end
		local again = start("SwapAgain", trio, { Player = swap.Player })
		flag("stamina_full_after_exhaustion", again.TeamOk and again.StartFull)
	end)
	flag("stamina_no_error", ok)
	if not ok then
		m.error = tostring(err)
	end
	for _, ctx in ctxs do
		if ctx.err then
			m.error = (m.error or "") .. " " .. ctx.Name .. ": " .. ctx.err
		end
		if ctx.Run then
			pcall(ctx.Run.Destroy, ctx.Run)
		end
	end
	for _, x in cleanup do
		x:Destroy()
	end
	return r
end

return Tests
