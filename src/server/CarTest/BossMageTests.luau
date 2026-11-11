--!nonstrict
-- BRIEF: design doc 4.37 "Second boss" (owner 2026-11-11), docs/BOSS_EVENT_SPEC.md "The Elf Mage": the second boss, picked at
-- random per event, one stage, 3 moves (lightning 20% of a full bar, golem slam 15% plus a 20% damage cut for 15 s, barrage
-- 30%), the slam dodged by 4 rhythm circles (+/- 0.18 s), an enclosed colosseum (inner 70, width 56, 7 lanes, wall 164 by the
-- orchestrator's 2026-11-11 default). Red first: written before the code (task boss-mage T1).
--
-- Contract these tests assume beyond the brief (boss-mage-code-plan.md sections 1-3 and 6; implementer: report a change, do not
-- loosen):
--   Shared/BossCatalog: Default, Order = { "boss_raga", "boss_mage" }, Get(id) (nil or unknown -> the boss_raga row), Current()
--     (Get of ReplicatedStorage attribute BossEventBoss). Row fields of plan section 1.
--   Shared/BossOsu: Count, ApproachSeconds, Tolerance, Diameter, DiameterPhone, OpenSeconds, Circles(userId, startAt, index) ->
--     4 rows { X, Y, Lead } in click order (named fields), Judge(lead, momentAt, stamp, slack).
--   Shared/BossArenaConfig.For(bossId): "boss_mage" -> the colosseum table (Raga's fields plus WallRadius, WallHeight, HoverY,
--     BobStuds, BobSeconds); anything else -> BossArenaConfig itself.
--   Shared/BossDodge: Moment(index, boss), IndexAtOrBefore(since, boss), EventsOf(boss); boss nil = Raga.
--   Shared/BossEventConfig.WaitCameraCFrame(center, runnerPosition, wait): wait = { Out, Up, Down }.
--   Server/BossEventService: Start(source, bossId) (unknown id: false, "Unknown boss"), State().Boss, ReplicatedStorage attribute
--     BossEventBoss, Hooks.PickBoss() (default "boss_raga" while CarTestRunning, uniform otherwise: decision D1 option A),
--     Hooks.DamageMulti(t, spared, stage, boss), Osu(player, index, circle, stamp) -> ok, reason, Dodge on a Slam moment ->
--     false, "No bar", RewardPopup summary field Boss. BossStatus JSON row { Id = "Crushed", EndsAt, Count }.
--   Shared/BossMagePoses (generated, landed 2026-11-11): Moves (idle, lightning, golem, barrage, plus lightning_in, golem_in,
--     barrage_in with no events), Approved, Bind, Scale (studs per unit), Sample(move, t) -> parts, root (studs), Schedule,
--     RiseAt, CycleSeconds, SampleGolem(t) -> scale (0 = hidden), parts, locs, root; GolemBind (15 blocks).
-- Proposed values the plan fixes and these tests assert literally (owner may retune): her move chat lines, camera pitch 14,
--   wall 164, HoverY 8, bob 1.5 studs / 3 s, WaitCamera { Out = 28, Up = 40, Down = 22 }.
-- NOT reachable from the schedule: two Crushed stacks. Her cycle (31.55 s) has one Slam, so no two fall within 15 s; the
--   stacking check runs only if a schedule ever has them (metric crushed_two_stacks_found).
-- On demand: ReplicatedStorage attributes CarTestOnly = "boss_mage_event,boss_mage_arena,boss_mage_anim", then CarTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local PathDriver = require(Shared.PathDriver)
local Tests = {}

local MAGE, RAGA = "boss_mage", "boss_raga"
local UID = 990158000
local T0 = 1000000 -- the fake server clock's start
local COST = { Lightning = 20, Barrage = 30, Slam = 15 } -- owner 2026-11-11, % of a full bar (stamina is 0..100)
local CRUSHED_CUT = 0.2 -- owner 2026-11-11
local STATUS_SECONDS = 15 -- proposed: the stage's status time
local SLAM_AT = 4.2 -- approved keys.json: golem's Slam
local MOVE_EVENTS = { lightning = { "Lightning", 1.6 }, golem = { "Slam", 4.2 }, barrage = { "Barrage", 2.0 } }
local CHAT = "THE ELF MAGE HAS AWAKENED, TAKE HER DOWN FOR REWARDS" -- design doc 4.37 (proposed)
local MOVE_CHAT = { -- plan section 1 (proposed)
	Lightning = "The Elf Mage calls lightning! -20% stamina",
	Barrage = "The Elf Mage fires a barrage! -30% stamina",
	Slam = "The Elf Mage's golem slams! -15% stamina, damage down for 15 s",
}
local MODEL_HEIGHT_UNITS = 6.2582 -- keys.json scale.model_height_units
local SCAN = 40 -- moments looked at
-- djb2 { length, hash } of the real source names (section 5 safeguard): kept as hashes so no real name sits in the game's files.
local REAL_NAMES = {
	{ 7, 1090972917 },
	{ 8, 963842139 },
	{ 7, 2081047238 },
	{ 6, 473633273 },
	{ 6, 35734055 },
	{ 6, 143515654 },
}

local function approx(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tolerance or 1e-6)
end

local function nameHash(s)
	local x = 5381
	for i = 1, #s do
		x = (x * 33 + string.byte(s, i)) % 2147483647
	end
	return x
end

local function realNameIn(text)
	text = string.lower(text)
	for _, entry in REAL_NAMES do
		for i = 1, #text - entry[1] + 1 do
			if nameHash(string.sub(text, i, i + entry[1] - 1)) == entry[2] then
				return entry[2]
			end
		end
	end
	return nil
end

local function stringsIn(value, out)
	if type(value) == "string" then
		table.insert(out, value)
	elseif type(value) == "table" then
		for _, item in value do
			stringsIn(item, out)
		end
	end
	return out
end

-- The first `count` moments of a boss: { Index, At, Name }, At in seconds since the intro's end.
local function momentsOf(BossDodge, boss, count)
	local list = {}
	for index = 1, count or SCAN do
		local at, name = BossDodge.Moment(index, boss)
		table.insert(list, { Index = index, At = at, Name = name })
	end
	return list
end

local function firstOf(list, name, after)
	for _, row in list do
		if row.Name == name and (after == nil or row.Index > after) then
			return row
		end
	end
	return nil
end

local function reporter(name)
	local r, flag = H.report(name)
	local function section(label, body)
		local ok, err = xpcall(body, debug.traceback)
		flag(label .. "_completed", ok, ok and 1 or tostring(err))
	end
	local function eq(label, actual, expected)
		flag(label, actual == expected, actual, expected)
	end
	local function near(label, actual, expected, tolerance)
		flag(label, approx(actual, expected, tolerance), actual, expected)
	end
	return r, flag, section, eq, near
end

function Tests.make()
	local function boss_mage_event()
		local r, flag, section, eq, near = reporter("boss_mage_event")
		local cleanup = {}
		local Cfg = H.module(Shared, "BossEventConfig")
		local S = H.module(Server, "BossEventService")
		local BossDodge = H.module(Shared, "BossDodge")
		local Catalog = H.module(Shared, "BossCatalog")
		local Osu = H.module(Shared, "BossOsu")
		flag("service_exists", S ~= nil)
		flag("catalog_exists", Catalog ~= nil)
		flag("osu_exists", Osu ~= nil)
		flag("dodge_exists", BossDodge ~= nil)
		if not (Cfg and S and BossDodge) then
			return r
		end
		local realHooks = table.clone(S.Hooks)

		local gacha = require(Server.GachaService)
		local sidekick = require(Server.SidekickService)
		local catalog = require(Shared.CharacterCatalog)
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestBossMageData", Server
		table.insert(cleanup, module)
		local data = require(module)
		data.SetStore(H.store())
		local nextId = UID
		local function newPlayer()
			nextId += 1
			local p = H.player(cleanup, nextId)
			data.Load(p, nextId)
			return p
		end
		local chars = {}
		for _, spec in catalog.All() do
			if spec.Rollable and spec.Id ~= catalog.STARTER_ID then
				table.insert(chars, spec.Id)
			end
		end
		local function wear(p, charId, sideId)
			gacha.Grant(p, charId)
			local _, entry = sidekick.Grant(p, sideId)
			sidekick.Equip(p, charId, entry)
		end
		local function fighter()
			local p = newPlayer()
			wear(p, chars[1], "side_knight")
			return p
		end
		-- Three characters, each with a Sidekick, set as the event team.
		local function trio()
			local p, ids = newPlayer(), {}
			for i, sideId in { "side_knight", "side_chain", "side_fox" } do
				wear(p, chars[i], sideId)
				table.insert(ids, chars[i])
			end
			return p, ids
		end

		local PREP, INTRO = Cfg.PrepSeconds, Cfg.IntroSeconds
		local FIGHT = PREP + INTRO
		local clock = T0
		local log
		local function install()
			log = { Chat = {}, MoveChat = {}, Paid = {}, Popups = {}, Runs = {}, Lanes = {} }
			S.Hooks.DamageMulti = function()
				return 1
			end
			S.Hooks.Arrive = function() end
			S.Hooks.Depart = function() end
			S.Hooks.BossHits = function() end
			S.Hooks.Chat = function(text)
				table.insert(log.Chat, text)
			end
			S.Hooks.MoveChat = function(p, text)
				table.insert(log.MoveChat, { Player = p, Text = text })
			end
			S.Hooks.PayStage = function(p, stage)
				table.insert(log.Paid, { Player = p, Stage = stage })
				return true
			end
			S.Hooks.RewardPopup = function(p, summary)
				table.insert(log.Popups, { Player = p, Summary = summary })
			end
			S.Hooks.SwitchLane = function(_, lane)
				table.insert(log.Lanes, lane)
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
					Slot = 1,
					Line = line,
					Stamina = { 100, 100, 100 },
					Revives = {},
				}
				function run:Destroy() end
				function run:ReviveAt(seconds)
					table.insert(self.Revives, seconds)
				end
				log.Runs[p] = run
				return run
			end
		end
		local function to(t)
			clock = T0 + t
			S.Advance(clock)
		end
		-- A fresh server at T0 with `boss`'s event started: time t in a test is the event's own clock.
		local function begin(boss)
			clock = T0
			S.Reset(T0)
			install()
			return S.Start("Test", boss)
		end
		local function statusRow(p, id)
			for _, row in HttpService:JSONDecode(p:GetAttribute("BossStatus") or "[]") do
				if row.Id == id then
					return row
				end
			end
			return nil
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
		-- Every moment before event-clock time t passes in the wait: spared, sets nothing.
		local function spareUntil(run, t)
			run.Waiting = true
			to(t)
			run.Waiting = false
		end
		-- One hit that empties HP.
		local function kill(p)
			local old = S.Hooks.DamageMulti
			S.Hooks.DamageMulti = function()
				return 1e9
			end
			local dealt = S.RecordHit(p)
			S.Hooks.DamageMulti = old
			return dealt
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

		local moments = momentsOf(BossDodge, MAGE)
		local function momentT(row) -- on the event clock
			return FIGHT + row.At
		end
		local found = {}
		for name in COST do
			found[name] = firstOf(moments, name)
			flag("moment_found_" .. string.lower(name), found[name] ~= nil)
		end

		-- Which boss: named, refused, random (decision D1 option A).
		serviceSection("pick", function()
			for _, id in { MAGE, RAGA } do
				local tag = id == MAGE and "mage" or "raga"
				eq("pick_named_" .. tag .. "_starts", begin(id), true)
				eq("pick_named_" .. tag, S.State().Boss, id)
				eq("pick_named_" .. tag .. "_attribute", ReplicatedStorage:GetAttribute("BossEventBoss"), id)
				S.End("Timeout")
				eq("pick_attribute_cleared_" .. tag, ReplicatedStorage:GetAttribute("BossEventBoss"), nil)
			end
			S.Reset(T0)
			install()
			local ok, why = S.Start("Test", "boss_nobody")
			eq("pick_unknown_refused", ok, false)
			eq("pick_unknown_reason", why, "Unknown boss")
			eq("pick_unknown_no_event", S.State().Phase, "Idle")
		end)

		serviceSection("pick_random", function()
			eq("pick_hook_exists", type(realHooks.PickBoss), "function")
			local calls = 0
			local function stub(id)
				calls = 0
				S.Hooks.PickBoss = function()
					calls += 1
					return id
				end
			end
			for _, id in { MAGE, RAGA } do
				local tag = id == MAGE and "mage" or "raga"
				S.Reset(T0)
				install()
				stub(id)
				S.Start("Test")
				eq("pick_hook_test_start_" .. tag, S.State().Boss, id)
				eq("pick_hook_called_once_" .. tag, calls, 1)
			end
			S.Reset(T0)
			stub(MAGE)
			S.Advance(T0 + Cfg.IntervalSeconds)
			eq("pick_timer_source", S.State().Source, "Timer")
			eq("pick_hook_timer_start", S.State().Boss, MAGE)
			eq("pick_hook_called_by_timer", calls, 1)
			S.Reset(T0)
			stub(MAGE)
			S.Start("Paid")
			eq("pick_hook_paid_start", S.State().Boss, MAGE)
			eq("pick_hook_called_by_paid", calls, 1)
			S.Reset(T0)

			-- The real hook: Raga in the test harness, both bosses otherwise. No yield while CarTestRunning is off.
			local inTests = {}
			for _ = 1, 50 do
				inTests[realHooks.PickBoss()] = true
			end
			flag("pick_default_in_tests_is_raga", inTests[RAGA] == true and next(inTests, next(inTests)) == nil)
			local seen, unknown = {}, nil
			local was = ReplicatedStorage:GetAttribute("CarTestRunning")
			local okRun, err = pcall(function()
				ReplicatedStorage:SetAttribute("CarTestRunning", false)
				for _ = 1, 200 do
					local id = realHooks.PickBoss()
					seen[id] = true
					if id ~= RAGA and id ~= MAGE then
						unknown = id
					end
				end
			end)
			ReplicatedStorage:SetAttribute("CarTestRunning", was)
			flag("pick_default_ran", okRun, okRun and 1 or tostring(err))
			flag("pick_random_both_raga", seen[RAGA] == true)
			flag("pick_random_both_mage", seen[MAGE] == true)
			eq("pick_random_only_known_ids", unknown, nil)
		end)

		-- Costs (owner 2026-11-11): every slot in run.Line, x VulnerableMulti once Vulnerable, Kami untouched.
		local function freshTrio(kamiSlot)
			begin(MAGE)
			local p, ids = trio()
			S.Join(p)
			S.SetTeam(p, ids)
			to(FIGHT)
			local run = log.Runs[p]
			if kamiSlot then
				run.Team = table.clone(run.Team)
				run.Team[kamiSlot] = catalog.KAMI_ID
			end
			return p, run
		end
		for name, cost in COST do
			serviceSection("cost_" .. string.lower(name), function()
				local row = found[name]
				if not row then
					return
				end
				local _, run = freshTrio()
				spareUntil(run, momentT(row) - 0.3)
				to(momentT(row) + 0.05)
				for slot = 1, 3 do
					near(("cost_%s_%d_slot_%d"):format(string.lower(name), cost, slot), run.Stamina[slot], 100 - cost)
				end
			end)
		end
		serviceSection("cost_rules", function()
			local first = found.Lightning
			if not first then
				return
			end
			local nextRow = moments[first.Index + 1]
			local p, run = freshTrio()
			spareUntil(run, momentT(first) - 0.3)
			to(momentT(first) + 0.05)
			flag("cost_sets_vulnerable", statusRow(p, "Vulnerable") ~= nil)
			to(momentT(nextRow) + 0.05)
			near(
				"cost_vulnerable_x1_5",
				run.Stamina[1],
				100 - COST.Lightning - COST[nextRow.Name] * Cfg.VulnerableMulti
			)
			eq("cost_vulnerable_multi_is_1_5", Cfg.VulnerableMulti, 1.5)

			local _, kamiRun = freshTrio(2)
			spareUntil(kamiRun, momentT(first) - 0.3)
			to(momentT(first) + 0.05)
			near("cost_kami_slot_untouched", kamiRun.Stamina[2], 100)
			near("cost_kami_team_others_pay", kamiRun.Stamina[1], 100 - COST.Lightning)

			local _, lineRun = freshTrio()
			spareUntil(lineRun, momentT(first) - 0.3)
			lineRun.Line = { 1, 3 }
			to(momentT(first) + 0.05)
			near("cost_skips_slot_out_of_line", lineRun.Stamina[2], 100)
			near("cost_line_slot_pays", lineRun.Stamina[3], 100 - COST.Lightning)

			local waitP, waitRun = freshTrio()
			spareUntil(waitRun, momentT(first) + 0.05)
			near("cost_none_in_wait", waitRun.Stamina[1], 100)
			eq("cost_wait_sets_nothing", statusRow(waitP, "Vulnerable"), nil)

			-- Joined after the moment: never charged for it.
			begin(MAGE)
			local early = fighter()
			S.Join(early)
			to(momentT(first) + 0.1)
			local late = fighter()
			S.Join(late)
			to(momentT(first) + 0.3)
			local lateRun = log.Runs[late]
			flag("cost_late_run_started", lateRun ~= nil)
			near("cost_none_before_join", lateRun and lateRun.Stamina[1], 100)
		end)

		-- Crushed (owner 2026-11-11): the slam's 20% damage cut for 15 s; lightning and barrage cut nothing.
		section("crushed_pure", function()
			local multi = realHooks.DamageMulti
			eq("damage_multi_hook_exists", type(multi), "function")
			if type(multi) ~= "function" then
				return
			end
			local slams = {}
			for _, row in moments do
				if row.Name == "Slam" then
					table.insert(slams, INTRO + row.At) -- seconds since the spawn
				end
			end
			flag("crushed_slams_found", #slams >= 1, #slams, 1)
			local function cutAt(t)
				return multi(t, {}, 1, MAGE)
			end
			local alone = nil
			for i, at in slams do
				if i == 1 or at - slams[i - 1] > STATUS_SECONDS then
					alone = alone or { At = at, Index = nil }
				end
			end
			if alone then
				for _, row in moments do
					if row.Name == "Slam" and INTRO + row.At == alone.At then
						alone.Index = row.Index
					end
				end
				near("crushed_cut_0_8", cutAt(alone.At + 1), 1 - CRUSHED_CUT)
				near("crushed_cut_until_15_s", cutAt(alone.At + STATUS_SECONDS - 0.05), 1 - CRUSHED_CUT)
				near("crushed_gone_at_ends", cutAt(alone.At + STATUS_SECONDS + 0.05), 1)
				near("crushed_dodged_not_cut", multi(alone.At + 1, { [alone.Index] = true }, 1, MAGE), 1)
			end
			local pairFound = nil
			for i = 2, #slams do
				if slams[i] - slams[i - 1] < STATUS_SECONDS then
					pairFound = slams[i]
					break
				end
			end
			r.metrics.crushed_two_stacks_found = pairFound ~= nil
			if pairFound then
				near("crushed_two_stacks_0_64", cutAt(pairFound + 0.05), (1 - CRUSHED_CUT) ^ 2)
			end
			for _, name in { "Lightning", "Barrage" } do
				local row = found[name]
				if row then
					local t = INTRO + row.At + 0.5
					local slamNear = false
					for _, at in slams do
						slamNear = slamNear or (at <= t and t < at + STATUS_SECONDS)
					end
					if not slamNear then
						near(string.lower(name) .. "_no_damage_cut", cutAt(t), 1)
					end
				end
			end
			-- Raga's statuses never apply to her, nor hers to Raga.
			local differ = nil
			for k = 0, 120 do
				local t = INTRO + k * 0.5
				if differ == nil and multi(t, {}, 1, RAGA) ~= multi(t, {}, 1) then
					differ = t
				end
			end
			eq("raga_multi_unchanged", differ, nil)
		end)

		serviceSection("crushed_service", function()
			local slam = found.Slam
			if not slam then
				return
			end
			local p = fighter()
			begin(MAGE)
			S.Hooks.DamageMulti = realHooks.DamageMulti
			S.Join(p)
			to(FIGHT)
			local run = log.Runs[p]
			spareUntil(run, momentT(slam) - 0.3)
			to(momentT(slam) + 0.05)
			local row = statusRow(p, "Crushed")
			flag("crushed_row_listed", row ~= nil)
			eq("crushed_row_count", row and row.Count, 1)
			near("crushed_row_ends_at", row and row.EndsAt, T0 + momentT(slam) + STATUS_SECONDS, 0.01)
			local base = S.TeamDamage(p)
			near("crushed_hit_dealt_0_8", S.RecordHit(p), base * (1 - CRUSHED_CUT))
			local ids = {}
			for _, item in HttpService:JSONDecode(p:GetAttribute("BossStatus") or "[]") do
				ids[item.Id] = true
			end
			flag("crushed_rows_only_mage", ids.Shouted == nil and ids.Adapted == nil)
			to(momentT(slam) + STATUS_SECONDS + 0.1)
			eq("crushed_row_gone_after_15_s", statusRow(p, "Crushed"), nil)

			for _, name in { "Lightning", "Barrage" } do
				local move = found[name]
				if move then
					local q = fighter()
					begin(MAGE)
					S.Join(q)
					to(FIGHT)
					spareUntil(log.Runs[q], momentT(move) - 0.3)
					to(momentT(move) + 0.05)
					local rows = HttpService:JSONDecode(q:GetAttribute("BossStatus") or "[]")
					local others = {}
					for _, item in rows do
						if item.Id ~= "Vulnerable" then
							table.insert(others, item.Id)
						end
					end
					eq(string.lower(name) .. "_only_vulnerable_row", table.concat(others, ","), "")
					flag(string.lower(name) .. "_sets_vulnerable", statusRow(q, "Vulnerable") ~= nil)
				end
			end
		end)

		-- Rhythm circles (owner 2026-11-11, proposed values): the server judges each circle's stamp.
		local function osuFresh()
			local slam = found.Slam
			local p = fighter()
			begin(MAGE)
			S.Join(p)
			to(FIGHT)
			local run = log.Runs[p]
			spareUntil(run, momentT(slam) - Osu.OpenSeconds - 0.2)
			local rows = Osu.Circles(p:GetAttribute("UserId"), T0, slam.Index)
			local M = T0 + momentT(slam)
			local function beat(k)
				return M - rows[k].Lead
			end
			local function pressAt(k, stamp, arrives, index)
				to((arrives or stamp) - T0)
				return S.Osu(p, index or slam.Index, k, stamp)
			end
			return p, run, M, beat, pressAt
		end
		-- Presses { k, stamp, arrives } in arrival order; returns the last ok, reason.
		local function pressAll(pressAt, list)
			table.sort(list, function(a, b)
				return (a[3] or a[2]) < (b[3] or b[2])
			end)
			local results = {}
			for _, press in list do
				local ok, why = pressAt(press[1], press[2], press[3])
				results[press[1]] = { ok, why }
			end
			return results
		end
		serviceSection("osu", function()
			if not (found.Slam and Osu) then
				flag("osu_ready", false)
				return
			end
			local p, run, M, beat, pressAt = osuFresh()
			local lane = S.LaneOf(p)
			local results = {}
			for k = 1, 4 do
				results[k] = { pressAt(k, beat(k)) }
			end
			for k = 1, 3 do
				eq("osu_all_four_press_" .. k .. "_ok", results[k][1], true)
			end
			eq("osu_all_four_spares", results[4][1], true)
			eq("osu_all_four_reason_dodged", results[4][2], "Dodged")
			eq("osu_duplicate_circle_refused", pressAt(1, clock), false)
			eq("osu_duplicate_circle_reason", select(2, S.Osu(p, found.Slam.Index, 2, clock)), "Already pressed")
			to(M - T0 + 0.05)
			for slot = 1, 3 do
				near("osu_spared_no_cost_slot_" .. slot, run.Stamina[slot], 100)
			end
			eq("osu_spared_no_crushed", statusRow(p, "Crushed"), nil)
			flag("osu_spared_lane_switch_hook", #log.Lanes >= 1)
			flag("osu_spared_lane_moved", S.LaneOf(p) ~= lane, S.LaneOf(p), lane)

			p, run, M, beat, pressAt = osuFresh()
			for k = 1, 3 do
				pressAt(k, beat(k))
			end
			to(M - T0 + 0.05)
			near("osu_three_of_four_hits", run.Stamina[1], 100 - COST.Slam)
			flag("osu_three_of_four_crushed", statusRow(p, "Crushed") ~= nil)

			p, run, M, beat, pressAt = osuFresh()
			results = pressAll(pressAt, {
				{ 1, beat(1) },
				{ 2, beat(2) - 0.45 },
				{ 3, beat(3) },
				{ 4, beat(4) },
			})
			eq("osu_one_miss_refused", results[2][1], false)
			eq("osu_one_miss_reason", results[2][2], "Missed")
			flag("osu_after_miss_not_dodged", results[4][2] ~= "Dodged", results[4][2])
			to(M - T0 + 0.05)
			near("osu_one_miss_hits", run.Stamina[1], 100 - COST.Slam)
			flag("osu_one_miss_crushed", statusRow(p, "Crushed") ~= nil)

			-- Each bad press: refused, and that circle is spent, so the slam hits.
			p, run, M, beat, pressAt = osuFresh()
			eq("osu_before_open_refused", pressAt(1, M - Osu.OpenSeconds - 0.1), false)
			eq("osu_before_open_reason", select(2, S.Osu(p, found.Slam.Index, 1, clock)), "No circles")
			eq("osu_future_stamp_refused", pressAt(1, beat(1), beat(1) - 0.1), false)
			p, run, M, beat, pressAt = osuFresh()
			eq("osu_late_stamp_refused", pressAt(1, beat(1), beat(1) + 0.52), false)
			eq("osu_late_stamp_spends_circle", pressAt(1, clock), false)
			for _, bad in { 0, 5, 1.5, 0 / 0, math.huge, "1" } do
				local ok, why = S.Osu(p, found.Slam.Index, bad, clock)
				eq("osu_bad_circle_refused_" .. tostring(bad), ok, false)
				eq("osu_bad_circle_reason_" .. tostring(bad), why, "Invalid press")
			end
			for _, bad in { "1", 0, -1, 1.5, math.huge, 0 / 0 } do
				eq("osu_bad_index_refused_" .. tostring(bad), S.Osu(p, bad, 2, clock), false)
			end
			eq("osu_bad_stamp_text", S.Osu(p, found.Slam.Index, 2, "x"), false)
			eq("osu_bad_stamp_nan", S.Osu(p, found.Slam.Index, 2, 0 / 0), false)
			eq("osu_outsider_reason", select(2, S.Osu(fighter(), found.Slam.Index, 2, clock)), "Not in the event")
			eq("dodge_bar_on_slam_refused", S.Dodge(p, found.Slam.Index, clock), false)
			eq("dodge_bar_on_slam_reason", select(2, S.Dodge(p, found.Slam.Index, clock)), "No bar")
			to(M - T0 + 0.01)
			eq("osu_after_moment_refused", S.Osu(p, found.Slam.Index, 4, beat(4)), false)
			eq("osu_after_moment_reason", select(2, S.Osu(p, found.Slam.Index, 3, M - 0.01)), "No circles")
			near("osu_bad_presses_hit", run.Stamina[1], 100 - COST.Slam)

			-- On a Dodge bar move: no circles.
			local bar = found.Lightning
			if bar then
				local q = fighter()
				begin(MAGE)
				S.Join(q)
				to(FIGHT)
				spareUntil(log.Runs[q], momentT(bar) - 1)
				local ok, why = S.Osu(q, bar.Index, 1, clock)
				eq("osu_on_bar_move_refused", ok, false)
				eq("osu_on_bar_move_reason", why, "No circles")
			end

			-- Stamps of one slam sent again for the next.
			local nextSlam = firstOf(moments, "Slam", found.Slam.Index)
			flag("osu_next_slam_found", nextSlam ~= nil)
			if nextSlam then
				p, run, M, beat, pressAt = osuFresh()
				local old = {}
				for k = 1, 4 do
					old[k] = beat(k)
					pressAt(k, old[k])
				end
				local nextM = T0 + momentT(nextSlam)
				spareUntil(run, nextM - Osu.OpenSeconds - T0 + 0.5)
				local replayed = 0
				for k = 1, 4 do
					replayed += S.Osu(p, nextSlam.Index, k, old[k]) == true and 1 or 0
				end
				eq("osu_replay_next_moment_refused", replayed, 0)
				to(nextM - T0 + 0.05)
				near("osu_replay_next_moment_hits", run.Stamina[1], 100 - COST.Slam)
			end

			-- In the wait: not running.
			p, run, M, beat, pressAt = osuFresh()
			run.Waiting = true
			local ok, why = pressAt(1, beat(1))
			eq("osu_in_wait_refused", ok, false)
			eq("osu_in_wait_reason", why, "Not running")
		end)

		-- One stage only (owner 2026-11-11): her defeat ends the event and pays Phase 1 once.
		serviceSection("no_stage_2", function()
			local p = fighter()
			begin(MAGE)
			S.Join(p)
			to(FIGHT + 1)
			kill(p)
			eq("no_stage_2_defeated", S.State().LastEnd, "Defeated")
			eq("no_stage_2_idle", S.State().Phase, "Idle")
			flag("no_stage_2_never_stage_2", ReplicatedStorage:GetAttribute("BossEventStage") ~= 2)
			eq("no_stage_2_no_scream", ReplicatedStorage:GetAttribute("BossScreamEndsAt"), nil)
			eq("no_stage_2_pays_stage_1_once", timesPaid(p, 1), 1)
			eq("no_stage_2_pays_no_stage_2", timesPaid(p, 2), 0)
			local popups = popupsOf(p)
			eq("no_stage_2_one_popup", #popups, 1)
			local summary = popups[1] or {}
			eq("no_stage_2_popup_outcome", summary.Outcome, "Defeated")
			eq("no_stage_2_popup_boss", summary.Boss, MAGE)
			eq("no_stage_2_popup_stage1", summary.Stage1, true)
			eq("no_stage_2_popup_stage2", summary.Stage2, false)

			local q = fighter()
			begin(MAGE)
			S.Join(q)
			to(FIGHT)
			log.Runs[q].Waiting = true -- no hits on the way: the timeout must not be a defeat
			to(Cfg.TotalSeconds + 1)
			eq("timeout_ends", S.State().LastEnd, "Timeout")
			eq("timeout_pays_nothing", #log.Paid, 0)
			eq("timeout_no_popup", #log.Popups, 0)
		end)

		serviceSection("chat", function()
			local p = fighter()
			begin(MAGE)
			S.Join(p)
			to(PREP + 0.25)
			eq("chat_text_mage", log.Chat[1], CHAT)
			to(FIGHT)
			for name, text in MOVE_CHAT do
				local row = found[name]
				if row then
					local q = fighter()
					begin(MAGE)
					S.Join(q)
					to(FIGHT)
					spareUntil(log.Runs[q], momentT(row) - 0.3)
					table.clear(log.MoveChat)
					to(momentT(row) + 0.05)
					local last = log.MoveChat[#log.MoveChat]
					eq("move_chat_" .. string.lower(name), last and last.Text, text)
				end
			end
		end)

		-- Big Raga stays as he was (design doc 4.37).
		serviceSection("raga_unchanged", function()
			local p = fighter()
			eq("raga_starts", begin(RAGA), true)
			eq("raga_named", S.State().Boss, RAGA)
			S.Join(p)
			to(FIGHT)
			local run = log.Runs[p]
			local ragaMoments = momentsOf(BossDodge, RAGA, 3)
			for i, want in { "Impact", "WheelClick", "Roar" } do
				eq("raga_moment_" .. i, ragaMoments[i].Name, want)
				eq("raga_moment_default_" .. i, (select(2, BossDodge.Moment(i))), want)
			end
			to(FIGHT + ragaMoments[1].At + 0.05)
			near("raga_impact_costs_15", run.Stamina[1], 100 - Cfg.Stage(1).AttackStaminaCost)
			eq("raga_attack_cost_is_15", Cfg.Stage(1).AttackStaminaCost, 15)
			to(FIGHT + ragaMoments[2].At + 0.05)
			near("raga_wheel_costs_nothing", run.Stamina[1], 100 - Cfg.Stage(1).AttackStaminaCost)
			to(FIGHT + ragaMoments[3].At + 0.05)
			flag("raga_shouted_listed", statusRow(p, "Shouted") ~= nil)
			flag("raga_adapted_listed", statusRow(p, "Adapted") ~= nil)
			eq("raga_no_crushed", statusRow(p, "Crushed"), nil)
			eq("raga_shout_cut", Cfg.ShoutDamageCut, 0.25)
			eq("raga_adapted_cut", Cfg.AdaptedCut, 0.1)
			kill(p)
			eq("raga_stage_2_starts", S.State().Stage, 2)
			eq("raga_pays_stage_1", timesPaid(p, 1), 1)
		end)

		pcall(function()
			for name in table.clone(S.Hooks) do
				S.Hooks[name] = realHooks[name]
			end
			for name, fn in realHooks do
				S.Hooks[name] = fn
			end
			S.SetClock(nil)
			S.Reset(workspace:GetServerTimeNow())
		end)
		for _, item in cleanup do
			pcall(function()
				item:Destroy()
			end)
		end
		return r
	end

	local function boss_mage_arena()
		local r, flag, section, eq, near = reporter("boss_mage_arena")
		local Arena = H.module(Shared, "BossArenaConfig")
		local Cfg = require(Shared.BossEventConfig)
		local Catalog = H.module(Shared, "BossCatalog")
		flag("arena_for_exists", Arena ~= nil and type(Arena.For) == "function")
		flag("catalog_exists", Catalog ~= nil)
		if not (Arena and type(Arena.For) == "function") then
			return r
		end
		flag("raga_arena_unchanged", rawequal(Arena.For(RAGA), Arena))
		flag("nil_arena_is_raga", rawequal(Arena.For(nil), Arena))
		local M = Arena.For(MAGE)
		flag("mage_arena_differs", type(M) == "table" and not rawequal(M, Arena))
		if type(M) ~= "table" or rawequal(M, Arena) then
			return r
		end

		section("numbers", function()
			eq("inner_radius_70", M.InnerRadius, 70)
			eq("width_56", M.Width, 56)
			eq("lanes_7", M.Lanes, 7)
			eq("wall_height_70", M.WallHeight, 70)
			eq("wall_radius_164", M.WallRadius, 164)
			eq("y_1200", M.Y, 1200)
			flag("center_at_y", typeof(M.Center) == "Vector3" and approx(M.Center.Y, M.Y, 0.01))
			eq("boss_height_44", M.BossHeight, 44)
			flag("hover_6_to_10", type(M.HoverY) == "number" and M.HoverY >= 6 and M.HoverY <= 10, M.HoverY)
			eq("bob_studs_1_5", M.BobStuds, 1.5)
			eq("bob_seconds_3", M.BobSeconds, 3)
			flag("wall_outside_ring", M.WallRadius > M.InnerRadius + M.Width, M.WallRadius, M.InnerRadius + M.Width)
		end)

		section("camera", function()
			local row = Catalog and Catalog.Get(MAGE)
			local cam = row and row.Camera or {}
			eq("camera_yaw_75", cam.Yaw, 75)
			eq("camera_pitch_14", cam.Pitch, 14)
			eq("camera_zoom_40", cam.Zoom, 40)
			if not (cam.Yaw and cam.Pitch and cam.Zoom) then
				return
			end
			-- The running eye, outward of lane 7, stays inside the wall with 3 studs to spare (decision R1).
			local need = M.LaneRadius(7) + cam.Zoom * math.cos(math.rad(cam.Pitch)) * math.sin(math.rad(cam.Yaw)) + 3
			flag("wall_clears_running_eye", M.WallRadius >= need, M.WallRadius, need)
			local wait = row.WaitCamera
			flag("wait_camera_set", type(wait) == "table")
			if type(wait) ~= "table" then
				return
			end
			eq("wait_camera_out_28", wait.Out, 28)
			eq("wait_camera_up_40", wait.Up, 40)
			eq("wait_camera_down_22", wait.Down, 22)
			local worstOut, worstUp = 0, -math.huge
			local function judge(eye)
				worstOut = math.max(worstOut, ((eye - M.Center) * Vector3.new(1, 0, 1)).Magnitude)
				worstUp = math.max(worstUp, eye.Y - M.Y)
			end
			for lane = 1, M.Lanes do
				for i = 0, 11 do
					local a = i * math.pi / 6
					local at = M.Center + Vector3.new(math.cos(a), 0, math.sin(a)) * M.LaneRadius(lane)
					judge(Cfg.WaitCameraCFrame(M.Center, at, wait).Position)
				end
			end
			judge(Cfg.WaitCameraCFrame(M.Center, nil, wait).Position)
			flag("wait_eye_inside_wall", worstOut < M.WallRadius, worstOut, M.WallRadius)
			flag("wait_eye_under_wall_top", worstUp < M.WallHeight, worstUp, M.WallHeight)
		end)

		section("site", function()
			local C = M.Center
			local ragaOuter = Arena.InnerRadius + Arena.Width
			local apart = ((C - Arena.Center) * Vector3.new(1, 0, 1)).Magnitude - ragaOuter - M.WallRadius
			flag("clear_of_raga_arena_1500", apart >= 1500, apart, 1500)
			local reach = math.max(math.abs(C.X), math.abs(C.Z)) + M.WallRadius
			flag("inside_8192", reach < 8192 and C.Y + M.WallHeight < 8192, reach, 8192)
			local skip = {}
			for _, name in { "BossArena", "BossArenaPreview" } do
				local folder = workspace:FindFirstChild(name)
				if folder then
					table.insert(skip, folder)
				end
			end
			local nearest, nearestName = math.huge, "none"
			for _, part in workspace:GetDescendants() do
				if part:IsA("BasePart") and not part:IsA("Terrain") then
					local skipped = false
					for _, folder in skip do
						skipped = skipped or part:IsDescendantOf(folder)
					end
					if not skipped then
						local d = ((part.Position - C) * Vector3.new(1, 0, 1)).Magnitude - part.Size.Magnitude / 2
						if d < nearest then
							nearest, nearestName = d, part:GetFullName()
						end
					end
				end
			end
			r.metrics.nearest_part = nearestName
			flag("clear_of_world_1500", nearest >= 1500, nearest, 1500)
		end)

		section("routes", function()
			local counts, ragaCount = {}, #Arena.LaneRoute(1).WorldWaypoints
			for lane = 1, M.Lanes do
				local tag = "_lane_" .. lane
				local route = M.LaneRoute(lane)
				local wps = route.WorldWaypoints
				local radius = M.LaneRadius(lane)
				flag("route_cached" .. tag, rawequal(route, M.LaneRoute(lane)))
				flag("route_closed" .. tag, route.Closed == true)
				flag("route_repeats_first" .. tag, (wps[#wps] - wps[1]).Magnitude < 1e-3)
				flag("lane_inside_ring" .. tag, radius > M.InnerRadius and radius < M.InnerRadius + M.Width, radius)
				local lap = PathDriver.Arc(wps)[#wps]
				local circle = 2 * math.pi * radius
				flag("route_length" .. tag, math.abs(lap - circle) <= 0.0025 * circle, lap, circle)
				near("route_length_api" .. tag, M.LaneLength(lane), lap, 0.01)
				local onCircle = true
				for _, p in wps do
					onCircle = onCircle
						and approx(((p - M.Center) * Vector3.new(1, 0, 1)).Magnitude, radius, 0.01)
						and approx(p.Y, M.Y, 0.01)
				end
				flag("route_on_circle" .. tag, onCircle)
				counts[lane] = #wps
			end
			local same = true
			for lane = 1, M.Lanes do
				same = same and counts[lane] == ragaCount
			end
			flag("waypoint_counts_match_raga", same, counts[1], ragaCount)
			flag("route_not_raga", not rawequal(M.LaneRoute(1), Arena.LaneRoute(1)))
		end)

		return r
	end

	local function boss_mage_anim()
		local r, flag, section, eq, near = reporter("boss_mage_anim")
		local Event = require(Shared.BossEventConfig)
		local Poses = H.module(Shared, "BossMagePoses")
		local BossDodge = H.module(Shared, "BossDodge")
		local Osu = H.module(Shared, "BossOsu")
		local Catalog = H.module(Shared, "BossCatalog")
		local Art = H.module(Shared, "BossMageArt")
		flag("poses_module_loads", Poses ~= nil)
		flag("dodge_module_loads", BossDodge ~= nil)
		flag("osu_module_loads", Osu ~= nil)
		flag("catalog_module_loads", Catalog ~= nil)
		flag("art_module_loads", Art ~= nil)

		if Poses then
			section("poses", function()
				eq("bind_is_table", type(Poses.Bind), "table")
				eq("sample_is_function", type(Poses.Sample), "function")
				eq("schedule_is_function", type(Poses.Schedule), "function")
				eq("cycle_is_number", type(Poses.CycleSeconds), "number")
				-- Scale is studs per model unit (as BossRagaPoses): about 44 studs tall, 8 x a character (owner 2026-11-11).
				local Arena = H.module(Shared, "BossArenaConfig")
				local scale = Arena and type(Arena.For) == "function" and Arena.For(MAGE).BossScale or 1
				near("scale_gives_about_44_studs", Poses.Scale * scale * MODEL_HEIGHT_UNITS, 44, 2)
				local ends = { idle = 3.0, lightning = 3.2, golem = 5.0, barrage = 3.4 } -- keys.json
				for name, duration in ends do
					local move = Poses.Moves[name]
					flag(name .. "_exists", move ~= nil)
					near(name .. "_duration", move and move.Duration, duration, 0.01)
				end
				for name, move in Poses.Moves do
					local want = MOVE_EVENTS[name]
					local count, at = 0, nil
					for _, event in move.Events do
						count += 1
						at = event.Name == (want and want[1]) and event.Time or at
					end
					eq(name .. "_event_count", count, want and 1 or 0)
					if want then
						near(name .. "_" .. want[1] .. "_time", at, want[2])
					end
				end
				eq("slam_time_4_2", Poses.Moves.golem and Poses.Moves.golem.Events[1].Time, SLAM_AT)
			end)

			-- Approved keys (owner 2026-11-11): Sample at each approved time gives the approved pose.
			section("approved", function()
				for _, name in { "idle", "lightning", "golem", "barrage" } do
					local worst = 0
					for _, key in Poses.Approved[name] do
						local parts = Poses.Sample(name, key.Time)
						for part, v in key.Parts do
							local got = parts[part]
							local d = got and (got - Vector3.new(v[1], v[2], v[3])) or Vector3.new(1e9, 0, 0)
							worst = math.max(worst, math.abs(d.X), math.abs(d.Y), math.abs(d.Z))
						end
					end
					flag(name .. "_approved_reproduced", worst <= 0.01, worst, 0.01)
					flag(name .. "_approved_count", #Poses.Approved[name] >= 4, #Poses.Approved[name], 4)
				end
				-- Copied by hand from assets/characters_avatar/boss_mage/keyframes/keys.json.
				for _, spot in
					{
						{ "lightning", 1.6, "RightArm", Vector3.new(-172.694, 0, 0) },
						{ "golem", 4.2, "RightArm", Vector3.new(75.964, 33.702, 26.611) },
						{ "barrage", 2.0, "RightArm", Vector3.new(-111.801, -15.565, 22.825) },
						{ "idle", 0.75, "Torso", Vector3.new(5, 0, 0) },
						{ "golem", 1.4, "Torso", Vector3.new(2, -4, -24) },
					}
				do
					local parts = Poses.Sample(spot[1], spot[2])
					local got = parts[spot[3]]
					local e = got
							and math.max(
								math.abs(got.X - spot[4].X),
								math.abs(got.Y - spot[4].Y),
								math.abs(got.Z - spot[4].Z)
							)
						or math.huge
					flag(("keys_json_%s_%s_%s"):format(spot[1], spot[2], spot[3]), e <= 0.01, e, 0.01)
				end
			end)

			section("golem", function()
				local count = 0
				for _ in Poses.GolemBind or {} do
					count += 1
				end
				eq("golem_bind_15_parts", count, 15)
				eq("golem_sampler_exists", type(Poses.SampleGolem), "function")
				-- The golem shows from the first circle (1.35 s, decision R3) through the slam.
				for _, t in { 1.35, 2.0, 3.0, SLAM_AT } do
					local scale = Poses.SampleGolem(t)
					flag("golem_visible_at_" .. t, type(scale) == "number" and scale > 0, scale, "> 0")
				end
			end)

			section("schedule", function()
				local START = 5000
				local idle = true
				for t = 0, Event.IntroSeconds - 0.05, 0.1 do
					idle = idle and Poses.Schedule(START, START + t) == "idle"
				end
				flag("schedule_idle_during_intro", idle)
				local seen = {}
				for t = Event.IntroSeconds, Event.IntroSeconds + 2 * Poses.CycleSeconds, 0.1 do
					seen[Poses.Schedule(START, START + t)] = true
				end
				for _, name in { "lightning", "golem", "barrage" } do
					flag("schedule_covers_" .. name, seen[name] == true)
				end
				eq("rise_starts_at_0", Poses.RiseAt(0), 0)
				eq("rise_ends_at_1", Poses.RiseAt(Event.RiseSeconds), 1)
			end)
		end

		if BossDodge then
			section("dodge_timeline", function()
				eq("events_of_exists", type(BossDodge.EventsOf), "function")
				local moments = momentsOf(BossDodge, MAGE)
				local ordered, names, last = true, {}, 0
				local onPose = true
				local minBar, minSlam = math.huge, math.huge
				for _, row in moments do
					ordered = ordered and type(row.At) == "number" and row.At > last
					names[tostring(row.Name)] = true
					local gap = (row.At or 0) - last
					if row.Name == "Slam" then
						minSlam = math.min(minSlam, gap)
					else
						minBar = math.min(minBar, gap)
					end
					if Poses and type(row.At) == "number" then
						local move, localTime = Poses.Schedule(0, Event.IntroSeconds + row.At + 0.001)
						local want = MOVE_EVENTS[move]
						onPose = onPose and want ~= nil and want[1] == row.Name and approx(localTime, want[2], 0.01)
					end
					last = row.At or last
				end
				flag("mage_moments_in_order", ordered)
				for _, name in { "Lightning", "Slam", "Barrage" } do
					flag("mage_moments_have_" .. string.lower(name), names[name] == true)
				end
				local stray = {}
				for name in names do
					if not COST[name] then
						table.insert(stray, name)
					end
				end
				eq("mage_moments_only_her_events", table.concat(stray, ","), "")
				flag("mage_moments_on_pose_events", onPose)
				-- Room for the Dodge bar's 1.5 s and its 0.3 s pop before each bar moment; for the circles before each Slam.
				flag("gap_before_bar_moment", minBar >= 1.5 + 0.3, minBar, 1.8)
				local open = Osu and Osu.OpenSeconds or math.huge
				flag("gap_before_slam", minSlam >= open + 0.3, minSlam, open + 0.3)
				local back = true
				for _, row in moments do
					back = back and BossDodge.IndexAtOrBefore(row.At + 0.01, MAGE) == row.Index
				end
				flag("index_at_or_before_mage", back)
				local raga = true
				for i = 1, 10 do
					local a1, n1 = BossDodge.Moment(i)
					local a2, n2 = BossDodge.Moment(i, RAGA)
					raga = raga and a1 == a2 and n1 == n2
				end
				flag("raga_moments_unchanged", raga)
				flag("raga_events_table_kept", rawequal(BossDodge.EventsOf(RAGA), BossDodge.Events))
				eq("hit_text_lightning", BossDodge.HitText.Lightning, "You were struck by her lightning")
				eq("hit_text_barrage", BossDodge.HitText.Barrage, "You were blasted by her barrage")
				eq("hit_text_slam", BossDodge.HitText.Slam, "The golem crushed you")
			end)
		end

		if Osu then
			section("osu", function()
				eq("osu_count_4", Osu.Count, 4)
				eq("osu_approach_1_0", Osu.ApproachSeconds, 1.0)
				eq("osu_tolerance_0_18", Osu.Tolerance, 0.18)
				eq("osu_diameter_0_12", Osu.Diameter, 0.12)
				eq("osu_diameter_phone_0_16", Osu.DiameterPhone, 0.16)
				near("osu_open_seconds", Osu.OpenSeconds, 2.875)
				local bad = {}
				local function note(label, ok)
					if not ok and #bad < 10 then
						table.insert(bad, label)
					end
				end
				local maxLead = 0
				for seed = 1, 500 do
					local user, start, index = 1000 + seed * 7, 1e6 + seed * 13.25, seed % 20 + 1
					local rows = Osu.Circles(user, start, index)
					local tag = "seed_" .. seed
					note(tag .. "_count", #rows == 4)
					for k, row in rows do
						note(tag .. "_x_" .. k, row.X >= 0.28 and row.X <= 0.72)
						note(tag .. "_y_" .. k, row.Y >= 0.28 and row.Y <= 0.72)
						-- Beats inside 2.0-4.0 s of the move (decision R3).
						note(tag .. "_beat_in_window_" .. k, SLAM_AT - row.Lead >= 2.0 and SLAM_AT - row.Lead <= 4.0)
						maxLead = math.max(maxLead, row.Lead)
						if k > 1 then
							note(tag .. "_lead_order_" .. k, rows[k - 1].Lead > row.Lead)
							note(tag .. "_gap_" .. k, rows[k - 1].Lead - row.Lead >= 0.35 - 1e-9)
						end
						for j = 1, k - 1 do
							local other = rows[j]
							local d = math.sqrt((row.X - other.X) ^ 2 + (row.Y - other.Y) ^ 2)
							note(tag .. "_apart_" .. j .. "_" .. k, d >= 0.17 - 1e-9)
						end
					end
					-- The last click stays 0.345 s before the slam: the Dodge bar's server margin.
					local lastLead = rows[4] and rows[4].Lead or 0
					note(tag .. "_last_lead", lastLead - Osu.Tolerance >= 0.345 - 1e-9)
					local again = Osu.Circles(user, start, index)
					note(tag .. "_deterministic", H.same(rows, again))
				end
				flag("osu_circles_all_seeds", #bad == 0, table.concat(bad, ","))
				flag("osu_open_covers_first_circle", maxLead + Osu.ApproachSeconds <= Osu.OpenSeconds + 1e-9, maxLead)
				flag("osu_differs_by_index", not H.same(Osu.Circles(5, 1e6, 1), Osu.Circles(5, 1e6, 2)))
				flag("osu_differs_by_user", not H.same(Osu.Circles(5, 1e6, 1), Osu.Circles(6, 1e6, 1)))
				eq("osu_judge_on_beat", Osu.Judge(1, 10, 9, 0), true)
				eq("osu_judge_inside_tolerance", Osu.Judge(1, 10, 9.17, 0), true)
				eq("osu_judge_early_inside", Osu.Judge(1, 10, 8.83, 0), true)
				eq("osu_judge_outside_tolerance", Osu.Judge(1, 10, 9.19, 0), false)
				eq("osu_judge_early_outside", Osu.Judge(1, 10, 8.81, 0), false)
				eq("osu_judge_slack_widens", Osu.Judge(1, 10, 9.19, 0.03), true)
			end)
		end

		if Catalog then
			section("catalog", function()
				eq("catalog_default_raga", Catalog.Default, RAGA)
				flag("catalog_order", H.same(Catalog.Order, { RAGA, MAGE }))
				local mage, raga = Catalog.Get(MAGE), Catalog.Get(RAGA)
				flag("catalog_get_nil_is_raga", rawequal(Catalog.Get(nil), raga))
				flag("catalog_get_unknown_is_raga", rawequal(Catalog.Get("boss_nobody"), raga))
				local fields = {
					"Id",
					"Name",
					"Poses",
					"Stages",
					"Moves",
					"Statuses",
					"ChatMessage",
					"WarningText",
					"ActiveText",
					"InviteTitle",
					"InviteHint",
					"DefeatedTitle",
					"Portrait",
					"ModelName",
					"TargetPart",
					"Camera",
				}
				for _, row in { mage, raga } do
					for _, field in fields do
						flag(("catalog_%s_has_%s"):format(row.Id, field), row[field] ~= nil)
					end
				end
				eq("mage_id", mage.Id, MAGE)
				eq("mage_name", mage.Name, "The Elf Mage")
				eq("mage_poses", mage.Poses, "BossMagePoses")
				eq("mage_stages_1", mage.Stages, 1)
				eq("mage_lightning_cost", mage.Moves.Lightning and mage.Moves.Lightning.Cost, 20)
				eq("mage_barrage_cost", mage.Moves.Barrage and mage.Moves.Barrage.Cost, 30)
				eq("mage_slam_cost", mage.Moves.Slam and mage.Moves.Slam.Cost, 15)
				eq("mage_slam_osu", mage.Moves.Slam and mage.Moves.Slam.Osu, true)
				local status = mage.Statuses[1] or {}
				eq("mage_one_status", #mage.Statuses, 1)
				eq("mage_status_crushed", status.Id, "Crushed")
				eq("mage_status_event_slam", status.Event, "Slam")
				near("mage_status_cut_0_2", status.Cut, CRUSHED_CUT)
				eq("mage_chat", mage.ChatMessage, CHAT)
				eq("mage_warning", mage.WarningText, "The Elf Mage has awakened, take her down!!!")
				eq("mage_active", mage.ActiveText, "The Elf Mage is casting right now")
				eq("mage_invite_title", mage.InviteTitle, "THE ELF MAGE EVENT")
				eq("mage_invite_hint", mage.InviteHint, "Teleport to fight The Elf Mage before the timer ends")
				eq("mage_defeated_title", mage.DefeatedTitle, "The Elf Mage Defeated!")
				eq("mage_model_name", mage.ModelName, "ElfMage")
				eq("mage_target_part", mage.TargetPart, "Torso")
				eq("mage_portrait", mage.Portrait, Art and Art.Portrait)
				eq("mage_dodge_icon", mage.DodgeIcon, Art and Art.StaffIcon)
				eq("raga_name", raga.Name, "Big Raga")
				eq("raga_poses", raga.Poses, "BossRagaPoses")
				eq("raga_stages_2", raga.Stages, 2)
				eq("raga_impact_stage_cost", raga.Moves.Impact and raga.Moves.Impact.StageCost, true)
				eq("raga_chat", raga.ChatMessage, Event.ChatMessage)
				eq("raga_model_name", raga.ModelName, "BigRaga")
				eq("raga_target_part", raga.TargetPart, "UpperTorso")
				eq("raga_dodge_icon_none", raga.DodgeIcon, nil)
				eq("raga_wait_camera_none", raga.WaitCamera, nil)
				eq("raga_defeated_title", raga.DefeatedTitle, "Raga Defeated!")
				eq("raga_active", raga.ActiveText, "Big Raga is raging right now")
				eq("raga_portrait", raga.Portrait, require(Shared.SidekickArt).side_raga.Portrait)
				local cam = raga.Camera or {}
				flag("raga_camera_kept", cam.Yaw == 75 and cam.Pitch == 26 and cam.Zoom == 40)
				local ids = {}
				for _, row in raga.Statuses do
					ids[row.Id] = row.Cut
				end
				eq("raga_shouted_cut", ids.Shouted, Event.ShoutDamageCut)
				eq("raga_adapted_cut", ids.Adapted, Event.AdaptedCut)
				-- Section 5 safeguard: only the tweaked names reach players.
				local leaks = {}
				for _, row in { mage, raga } do
					for _, text in stringsIn(row, {}) do
						if realNameIn(text) then
							table.insert(leaks, row.Id)
						end
					end
				end
				eq("catalog_no_real_names", table.concat(leaks, ","), "")
				-- Current reads the attribute; restored before any yield.
				local was = ReplicatedStorage:GetAttribute("BossEventBoss")
				local okSet, current = pcall(function()
					ReplicatedStorage:SetAttribute("BossEventBoss", MAGE)
					local row = Catalog.Current()
					ReplicatedStorage:SetAttribute("BossEventBoss", nil)
					return { row, Catalog.Current() }
				end)
				ReplicatedStorage:SetAttribute("BossEventBoss", was)
				flag("catalog_current_ran", okSet)
				flag("catalog_current_mage", okSet and rawequal(current[1], mage))
				flag("catalog_current_nil_is_raga", okSet and rawequal(current[2], raga))
			end)
		end

		return r
	end

	return { boss_mage_event = boss_mage_event, boss_mage_arena = boss_mage_arena, boss_mage_anim = boss_mage_anim }
end

return Tests
