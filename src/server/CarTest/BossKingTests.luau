--!nonstrict
-- BRIEF: design doc 4.37 "Third boss" (owner 2026-11-11), docs/BOSS_EVENT_SPEC.md "The Golden King": the third boss, picked at
-- random per event over the 3 bosses, one stage, 3 moves (Gates of Babylon 20% of a full bar, Enuma Elish 40%, Shield Gates 0 with
-- no Dodge bar and the boss-side status Fortified: 40% less damage until his next move starts), the Elf Mage's colosseum shell with
-- a vault dressing, no miniboss. Red first: written before the code (task boss-king k7), from BossMageTests section by section.
--
-- Contract these tests assume beyond the brief (implementer: report a change, do not loosen):
--   Shared/BossCatalog: Order = { "boss_raga", "boss_mage", "boss_king" }; the boss_king row after boss_mage with Moves gates
--     (Cost 20), enuma (Cost 40), shields (Cost 0; costs are bar percent on a 0-100 bar, as the mage's 20 / 30), Statuses
--     { { Id = "Fortified", Self = true, Event = "shields", Cut = 0.4 } }, FortifiedText (the notice), no Minion, Chests
--     { "relic_chest_king" }, Relics = "boss_king", Poses = "BossKingPoses", DodgeIcon = BossKingArt.KeyIcon, Portrait =
--     BossKingArt.Portrait, Camera and WaitCamera as the mage's, ModelName "GoldenKing", TargetPart "Torso".
--   Shared/BossDodge: moments of boss_king named gates, enuma, shields (the cost events of BossKingPoses; the start events
--     gates_start and enuma_start are not moments); Slot("boss_king") = nil. Hit texts live in the catalog: Moves.gates.HitText and
--     Moves.enuma.HitText (what BossDodgeUi reads).
--   Shared/BossArenaConfig.For("boss_king"): the colosseum table's numbers, routes and MaxRunSpeed with Dressing = "vault" and no
--     hover (HoverY and BobStuds 0 or nil); For("boss_mage").Dressing is not "vault".
--   Server/BossEventService: at the shields moment event.Fortified is set (ReplicatedStorage attribute BossFortified true / false
--     in an event, nil idle; every member's BossStatus gains { Id = "Fortified", Count = 1 }, no EndsAt); it clears at the next
--     cycle's gates_start (1.6 s before the gates moment) and at the event's end. Hooks.DamageMulti multiplies by 0.6 while set.
--     Dodge on a costless move's moment -> false, "No bar"; shields charges nothing and sets no Vulnerable; its move chat is the
--     raise line.
--   ServerStorage.LateData.BossKingPoses (the 2026-11-11 bake; design doc 7 "Join size", see LateDataTests): Moves idle, gates (events gates_start 0, gates 1.6 = Volleys; Window { 1.6, 3.6 }),
--     enuma (enuma_start 0, enuma 3.0 = Beam; Window { 3, 5 }; EaShown { 0, 5.6 }), shields (one event shields at 2.2 =
--     Fortified), lead-ins gates_in, enuma_in, shields_in of 0.75 s; cycle idle, gates_in, gates, idle, idle, enuma_in, enuma,
--     idle, idle, shields_in, shields, idle = 38.85 s; Approved[move] rows { Time, Parts, RootOffset } (idle 3, gates 6, enuma 8,
--     shields 4), Sample, Schedule, CycleSeconds, RiseAt.
--   Server/AdminService.Commands.boss accepts "king" -> "boss_king".
-- Proposed values asserted literally (owner may retune): the texts in BOSS_EVENT_SPEC "The Golden King", camera as the mage's.
-- On demand: ReplicatedStorage attributes CarTestOnly = "boss_king_event,boss_king_arena,boss_king_anim", then CarTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local KING, MAGE, RAGA = "boss_king", "boss_mage", "boss_raga"
local UID = 990159000
local T0 = 1000000 -- the fake server clock's start
local COST = { gates = 20, enuma = 40 } -- owner 2026-11-11, % of a full bar (stamina is 0..100); shields costs 0
local FORTIFIED_CUT = 0.4 -- owner 2026-11-11
local GATES_START_LEAD = 1.6 -- gates_start sits 1.6 s before the gates moment: Fortified ends there
local CYCLE_SECONDS = 38.85 -- the 2026-11-11 bake (proposed)
local LEAD_IN_SECONDS = 0.75 -- <move>_in (proposed)
-- His moves' events { cost event, its time, event count, start event }: gates charged when the volleys start (1.6 s, the
-- approved gates_window key), enuma at the beam's start (3.0 s), shields at 2.2 s (its last approved key).
local MOVE_EVENTS = {
	gates = { "gates", 1.6, 2, "gates_start" },
	enuma = { "enuma", 3.0, 2, "enuma_start" },
	shields = { "shields", 2.2, 1 },
}
local FORTIFIED_NOTICE = "The Golden King has fortified his defenses"

local CHAT = "THE GOLDEN KING HAS ARRIVED, TAKE HIM DOWN FOR REWARDS"
local WARNING = "The Golden King has arrived, take him down!!!"
local MOVE_CHAT = {
	gates = "The Golden King opens his vault! -20% stamina",
	enuma = "The Golden King unleashes Enuma Elish! -40% stamina",
	shields = "The Golden King raises his shields! He takes 40% less damage until his next move",
}
local HIT_TEXT = { gates = "The King's treasures struck you", enuma = "Enuma Elish tore through you" }
local SCAN = 40 -- moments looked at
-- djb2 { length, hash } of the real source name (section 5 safeguard): a hash, so the name never sits in the game's files.
local REAL_NAMES = { { 9, 789293634 } }

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
	local function boss_king_event()
		local r, flag, section, eq, near = reporter("boss_king_event")
		local cleanup = {}
		local Cfg = H.module(Shared, "BossEventConfig")
		local S = H.module(Server, "BossEventService")
		local BossDodge = H.module(Shared, "BossDodge")
		local Catalog = H.module(Shared, "BossCatalog")
		flag("service_exists", S ~= nil)
		flag("catalog_exists", Catalog ~= nil)
		flag("dodge_exists", BossDodge ~= nil)
		if not (Cfg and S and BossDodge) then
			return r
		end
		local realHooks = table.clone(S.Hooks)

		local gacha = require(Server.GachaService)
		local sidekick = require(Server.SidekickService)
		local catalog = require(Shared.CharacterCatalog)
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestBossKingData", Server
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
		local function fortified()
			return ReplicatedStorage:GetAttribute("BossFortified")
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

		local moments = momentsOf(BossDodge, KING)
		local function momentT(row) -- on the event clock
			return FIGHT + row.At
		end
		local found = {}
		for _, name in { "gates", "enuma", "shields" } do
			found[name] = firstOf(moments, name)
			flag("moment_found_" .. name, found[name] ~= nil)
		end

		-- Which boss: named, refused, random over the 3 bosses (BOSS_EVENT_SPEC "The Golden King", Defaults).
		serviceSection("pick", function()
			eq("pick_named_king_starts", begin(KING), true)
			eq("pick_named_king", S.State().Boss, KING)
			eq("pick_named_king_attribute", ReplicatedStorage:GetAttribute("BossEventBoss"), KING)
			S.End("Timeout")
			eq("pick_attribute_cleared_king", ReplicatedStorage:GetAttribute("BossEventBoss"), nil)
			eq("pick_fortified_cleared_at_end", fortified(), nil)
			S.Reset(T0)
			install()
			local ok, why = S.Start("Test", "boss_nobody")
			eq("pick_unknown_refused", ok, false)
			eq("pick_unknown_reason", why, "Unknown boss")
		end)

		serviceSection("pick_random", function()
			eq("pick_hook_exists", type(realHooks.PickBoss), "function")
			local seen, unknown = {}, nil
			local was = ReplicatedStorage:GetAttribute("CarTestRunning")
			local okRun, err = pcall(function()
				ReplicatedStorage:SetAttribute("CarTestRunning", false)
				for _ = 1, 300 do
					local id = realHooks.PickBoss()
					seen[id] = true
					if id ~= RAGA and id ~= MAGE and id ~= KING then
						unknown = id
					end
				end
			end)
			ReplicatedStorage:SetAttribute("CarTestRunning", was)
			flag("pick_default_ran", okRun, okRun and 1 or tostring(err))
			for _, id in { RAGA, MAGE, KING } do
				flag("pick_random_reaches_" .. id, seen[id] == true)
			end
			eq("pick_random_only_known_ids", unknown, nil)
			-- The hook, stubbed: the king at a paid start too.
			S.Reset(T0)
			install()
			S.Hooks.PickBoss = function()
				return KING
			end
			S.Start("Paid")
			eq("pick_hook_paid_start_king", S.State().Boss, KING)
		end)

		-- Costs (owner 2026-11-11): every slot in run.Line, x VulnerableMulti once Vulnerable, Kami untouched.
		local function freshTrio(kamiSlot)
			begin(KING)
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
			serviceSection("cost_" .. name, function()
				local row = found[name]
				if not row then
					return
				end
				local _, run = freshTrio()
				spareUntil(run, momentT(row) - 0.3)
				to(momentT(row) + 0.05)
				for slot = 1, 3 do
					near(("cost_%s_%d_slot_%d"):format(name, cost, slot), run.Stamina[slot], 100 - cost)
				end
			end)
		end
		serviceSection("cost_rules", function()
			local first = found.gates
			local nextRow = first and firstOf(moments, "enuma", first.Index)
			if not (first and nextRow) then
				return
			end
			local p, run = freshTrio()
			spareUntil(run, momentT(first) - 0.3)
			to(momentT(first) + 0.05)
			flag("cost_sets_vulnerable", statusRow(p, "Vulnerable") ~= nil)
			to(momentT(nextRow) + 0.05)
			near("cost_vulnerable_x1_5", run.Stamina[1], 100 - COST.gates - COST.enuma * Cfg.VulnerableMulti)

			local _, kamiRun = freshTrio(2)
			spareUntil(kamiRun, momentT(first) - 0.3)
			to(momentT(first) + 0.05)
			near("cost_kami_slot_untouched", kamiRun.Stamina[2], 100)
			near("cost_kami_team_others_pay", kamiRun.Stamina[1], 100 - COST.gates)

			local waitP, waitRun = freshTrio()
			spareUntil(waitRun, momentT(first) + 0.05)
			near("cost_none_in_wait", waitRun.Stamina[1], 100)
			eq("cost_wait_sets_nothing", statusRow(waitP, "Vulnerable"), nil)
		end)

		-- Fortified (owner 2026-11-11): Shield Gates costs nothing, opens no Dodge bar, cuts his damage taken by 40% until his
		-- next move starts. The first boss-side status: on ReplicatedStorage, not on a player.
		serviceSection("fortified", function()
			local shields = found.shields
			local nextGates = shields and firstOf(moments, "gates", shields.Index)
			if not (shields and nextGates) then
				flag("fortified_shields_moment", false)
				return
			end
			local startAt = momentT(nextGates) - GATES_START_LEAD -- the next cycle's gates_start
			-- One character, one slot: TeamDamage is that slot's hit (as the mage's crushed_service).
			local p = fighter()
			begin(KING)
			local live = false
			S.Hooks.DamageMulti = function(...)
				return live and realHooks.DamageMulti(...) or 1
			end
			S.Join(p)
			to(FIGHT)
			local run = log.Runs[p]
			spareUntil(run, momentT(shields) - 0.6)
			flag("fortified_not_before_shields", fortified() ~= true, fortified())
			local ok, why = S.Dodge(p, shields.Index, clock)
			eq("fortified_shields_dodge_refused", ok, false)
			eq("fortified_shields_dodge_reason", why, "No bar")
			local base = S.TeamDamage(p)
			live = true
			local plain = S.RecordHit(p)
			live = false
			near("fortified_plain_hit_full", plain, base)
			table.clear(log.MoveChat)
			to(momentT(shields) + 0.05)
			eq("fortified_set_at_shields", fortified(), true)
			near("fortified_shields_costs_nothing", run.Stamina[1], 100)
			eq("fortified_shields_no_vulnerable", statusRow(p, "Vulnerable"), nil)
			local last = log.MoveChat[#log.MoveChat]
			eq("fortified_move_chat", last and last.Text, MOVE_CHAT.shields)
			local row = statusRow(p, "Fortified")
			flag("fortified_row_listed", row ~= nil)
			eq("fortified_row_count_1", row and row.Count, 1)
			eq("fortified_row_no_ends_at", row and row.EndsAt, nil)
			live = true
			local cut = S.RecordHit(p)
			live = false
			near("fortified_hit_0_6", cut, base * (1 - FORTIFIED_CUT))
			flag("fortified_hit_lower_than_plain", cut < plain, cut, plain)
			-- Holds through the idle until the next cycle's gates_start; gates then charges x1 (shields set no Vulnerable).
			to(startAt - 0.3)
			eq("fortified_holds_until_gates_start", fortified(), true)
			to(startAt + 0.05)
			eq("fortified_cleared_at_gates_start", fortified(), false)
			eq("fortified_row_gone", statusRow(p, "Fortified"), nil)
			to(momentT(nextGates) + 0.05)
			near("fortified_next_move_costs_x1", run.Stamina[1], 100 - COST.gates)
			live = true
			local after = S.RecordHit(p)
			live = false
			near("fortified_hit_full_after", after, base)

			-- The event's end clears it too.
			local q = fighter()
			begin(KING)
			S.Join(q)
			to(FIGHT)
			spareUntil(log.Runs[q], momentT(shields) - 0.3)
			to(momentT(shields) + 0.05)
			eq("fortified_set_again", fortified(), true)
			S.End("Timeout")
			eq("fortified_nil_after_end", fortified(), nil)
		end)

		-- The pure hook: his schedule alone cuts nothing (Fortified lives in the event's state); Raga's and the mage's untouched.
		section("fortified_pure", function()
			local multi = realHooks.DamageMulti
			eq("damage_multi_hook_exists", type(multi), "function")
			if type(multi) ~= "function" then
				return
			end
			local cut = nil
			for k = 0, 400 do
				local at = INTRO + k * 0.25
				if cut == nil and multi(at, {}, 1, KING) ~= 1 then
					cut = at
				end
			end
			eq("king_schedule_no_cut_outside_event", cut, nil)
			near("king_ignores_crushes", multi(INTRO + 1, {}, 1, KING, 2), multi(INTRO + 1, {}, 1, KING))
			local differ = nil
			for k = 0, 120 do
				local at = INTRO + k * 0.5
				if differ == nil and multi(at, {}, 1, RAGA) ~= multi(at, {}, 1) then
					differ = at
				end
			end
			eq("raga_multi_unchanged", differ, nil)
		end)

		-- The next timed event's boss is picked when it is scheduled (BOSS_EVENT_SPEC "Bosses cards").
		serviceSection("next_boss", function()
			local function nextBoss()
				return ReplicatedStorage:GetAttribute("BossEventNextBoss")
			end
			local queue = { KING, RAGA }
			S.Hooks.PickBoss = function()
				return table.remove(queue, 1) or RAGA
			end
			S.Reset(T0)
			eq("next_boss_picked_king", nextBoss(), KING)
			S.Advance(T0 + Cfg.IntervalSeconds)
			eq("next_boss_timer_starts_king", S.State().Boss, KING)
			eq("next_boss_repicked", nextBoss(), RAGA)
			S.Hooks.PickBoss = realHooks.PickBoss
		end)

		-- His defeat pays his own chest (RELIC_SPEC "The Golden King's drops"); the mage's and Raga's stay theirs.
		serviceSection("pay_king_chest", function()
			local Relic = require(Server.RelicService)
			local money = require(Server.MoneyService)
			for _, case in
				{
					{ "king", KING, "relic_chest_king" },
					{ "mage", MAGE, "relic_chest_mage" },
					{ "default", nil, "relic_chest_raga" },
				}
			do
				local tag, boss, chest = case[1], case[2], case[3]
				local p = newPlayer()
				local cash = money.Setup(p)
				local start = cash.Value
				eq("pay_" .. tag .. "_ok", realHooks.PayStage(p, 1, boss), true)
				local bag = Relic.Snapshot(p).Relics or {}
				eq("pay_" .. tag .. "_one_chest", #bag, 1)
				eq("pay_" .. tag .. "_chest", bag[1] and bag[1].Id, chest)
				eq("pay_" .. tag .. "_phase_1_money", cash.Value, start + Cfg.Phase1Money)
			end
		end)

		-- One stage only: his defeat ends the event and pays Phase 1 once; a timeout pays nothing.
		serviceSection("no_stage_2", function()
			local p = fighter()
			begin(KING)
			S.Join(p)
			to(FIGHT + 1)
			kill(p)
			eq("no_stage_2_defeated", S.State().LastEnd, "Defeated")
			eq("no_stage_2_idle", S.State().Phase, "Idle")
			flag("no_stage_2_never_stage_2", ReplicatedStorage:GetAttribute("BossEventStage") ~= 2)
			eq("no_stage_2_pays_stage_1_once", timesPaid(p, 1), 1)
			eq("no_stage_2_pays_no_stage_2", timesPaid(p, 2), 0)
			local popups = popupsOf(p)
			eq("no_stage_2_one_popup", #popups, 1)
			local summary = popups[1] or {}
			eq("no_stage_2_popup_outcome", summary.Outcome, "Defeated")
			eq("no_stage_2_popup_boss", summary.Boss, KING)
			eq("no_stage_2_popup_stage2", summary.Stage2, false)

			local q = fighter()
			begin(KING)
			S.Join(q)
			to(FIGHT)
			log.Runs[q].Waiting = true
			to(Cfg.TotalSeconds + 1)
			eq("timeout_ends", S.State().LastEnd, "Timeout")
			eq("timeout_pays_nothing", #log.Paid, 0)
			eq("timeout_no_popup", #log.Popups, 0)
		end)

		serviceSection("chat", function()
			local p = fighter()
			begin(KING)
			S.Join(p)
			to(PREP + 0.25)
			eq("chat_text_king", log.Chat[1], CHAT)
			for _, name in { "gates", "enuma" } do
				local row = found[name]
				if row then
					local q = fighter()
					begin(KING)
					S.Join(q)
					to(FIGHT)
					spareUntil(log.Runs[q], momentT(row) - 0.3)
					table.clear(log.MoveChat)
					to(momentT(row) + 0.05)
					local last = log.MoveChat[#log.MoveChat]
					eq("move_chat_" .. name, last and last.Text, MOVE_CHAT[name])
				end
			end
		end)

		-- `/boss king` (BOSS_EVENT_SPEC "The Golden King", Admin).
		section("admin", function()
			local Admin = require(Server.AdminService)
			local boss = Admin.Commands.boss
			eq("admin_boss_king_id", boss and boss.Check({ "king" }), KING)
			eq("admin_boss_mage_kept", boss and boss.Check({ "mage" }), MAGE)
			flag(
				"admin_boss_usage_names_king",
				boss and string.find(boss.Usage, "king", 1, true) ~= nil,
				boss and boss.Usage
			)
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

	-- The colosseum shell re-dressed as a vault (BOSS_EVENT_SPEC "The Golden King", Arena).
	local function boss_king_arena()
		local r, flag, section, eq, near = reporter("boss_king_arena")
		local Arena = H.module(Shared, "BossArenaConfig")
		local Catalog = H.module(Shared, "BossCatalog")
		flag("arena_for_exists", Arena ~= nil and type(Arena.For) == "function")
		if not (Arena and type(Arena.For) == "function") then
			return r
		end
		local K, M = Arena.For(KING), Arena.For(MAGE)
		flag("king_arena_is_a_table", type(K) == "table" and not rawequal(K, Arena))
		if type(K) ~= "table" or rawequal(K, Arena) then
			return r
		end

		section("numbers", function()
			eq("dressing_vault", K.Dressing, "vault")
			flag("mage_dressing_not_vault", type(M) == "table" and M.Dressing ~= "vault", M and M.Dressing)
			eq("inner_radius_70", K.InnerRadius, 70)
			eq("width_56", K.Width, 56)
			eq("lanes_7", K.Lanes, 7)
			eq("wall_height_70", K.WallHeight, 70)
			eq("wall_radius_164", K.WallRadius, 164)
			eq("y_1200", K.Y, 1200)
			eq("boss_height_44", K.BossHeight, 44)
			eq("max_run_speed_100", K.MaxRunSpeed, 100)
			-- He stands on his mound: no hover, no bob (design doc 4.37 "Third boss").
			eq("hover_none", K.HoverY or 0, 0)
			eq("bob_none", K.BobStuds or 0, 0)
			flag(
				"same_site_as_colosseum",
				typeof(K.Center) == "Vector3" and M and (K.Center - M.Center).Magnitude < 1e-3
			)
			-- Raga's and the mage's untouched.
			flag("raga_arena_unchanged", rawequal(Arena.For(RAGA), Arena))
			flag("nil_arena_is_raga", rawequal(Arena.For(nil), Arena))
			flag("mage_arena_kept", type(M) == "table" and M.HoverY ~= nil and M.HoverY > 0, M and M.HoverY)
		end)

		section("camera", function()
			local row = Catalog and Catalog.Get(KING)
			local cam = row and row.Camera or {}
			eq("camera_yaw_75", cam.Yaw, 75)
			eq("camera_pitch_14", cam.Pitch, 14)
			eq("camera_zoom_40", cam.Zoom, 40)
			local wait = row and row.WaitCamera
			flag("wait_camera_set", type(wait) == "table")
			if type(wait) ~= "table" then
				return
			end
			eq("wait_camera_out_28", wait.Out, 28)
			eq("wait_camera_up_40", wait.Up, 40)
			eq("wait_camera_down_22", wait.Down, 22)
		end)

		section("routes", function()
			for lane = 1, K.Lanes do
				local route = K.LaneRoute(lane)
				flag("route_cached_lane_" .. lane, rawequal(route, K.LaneRoute(lane)))
				flag("route_closed_lane_" .. lane, route.Closed == true)
				near("route_length_as_colosseum_lane_" .. lane, K.LaneLength(lane), M and M.LaneLength(lane), 0.01)
				near("lane_radius_as_colosseum_lane_" .. lane, K.LaneRadius(lane), M and M.LaneRadius(lane), 1e-6)
			end
		end)

		return r
	end

	local function boss_king_anim()
		local r, flag, section, eq, near = reporter("boss_king_anim")
		local Event = require(Shared.BossEventConfig)
		local Poses = H.lateData("BossKingPoses") -- design doc 7 "Join size"
		local BossDodge = H.module(Shared, "BossDodge")
		local Catalog = H.module(Shared, "BossCatalog")
		local Art = H.module(Shared, "BossKingArt")
		flag("poses_module_loads", Poses ~= nil)
		flag("dodge_module_loads", BossDodge ~= nil)
		flag("catalog_module_loads", Catalog ~= nil)
		flag("art_module_loads", Art ~= nil)

		if Poses then
			section("poses", function()
				eq("bind_is_table", type(Poses.Bind), "table")
				eq("sample_is_function", type(Poses.Sample), "function")
				eq("schedule_is_function", type(Poses.Schedule), "function")
				eq("cycle_is_number", type(Poses.CycleSeconds), "number")
				for _, name in { "idle", "gates", "enuma", "shields", "gates_in", "enuma_in", "shields_in" } do
					local move = Poses.Moves[name]
					flag(name .. "_exists", move ~= nil)
					flag(name .. "_has_duration", move ~= nil and type(move.Duration) == "number" and move.Duration > 0)
					if string.find(name, "_in", 1, true) then
						near(name .. "_duration_0_75", move and move.Duration, LEAD_IN_SECONDS, 0.01)
					end
				end
				local ea = Poses.Moves.enuma and Poses.Moves.enuma.EaShown
				flag("enuma_ea_shown_0_to_5_6", type(ea) == "table" and ea[1] == 0 and approx(ea[2], 5.6, 0.01))
				local windows = {}
				for name in Poses.Moves do
					if string.find(name, "_window", 1, true) then
						table.insert(windows, name)
					end
				end
				eq("window_moves_merged", table.concat(windows, ","), "")
				local gates = Poses.Moves.gates and Poses.Moves.gates.Window
				flag(
					"gates_window_1_6_to_3_6",
					type(gates) == "table" and approx(gates[1], 1.6) and approx(gates[2], 3.6)
				)
				local enuma = Poses.Moves.enuma and Poses.Moves.enuma.Window
				flag("enuma_window_3_to_5", type(enuma) == "table" and enuma[1] == 3 and enuma[2] == 5)
				for name, move in Poses.Moves do
					local want = MOVE_EVENTS[name]
					local count, at, startAt = 0, nil, nil
					for _, event in move.Events do
						count += 1
						at = event.Name == (want and want[1]) and event.Time or at
						startAt = event.Name == (want and want[4]) and event.Time or startAt
					end
					eq(name .. "_event_count", count, want and want[3] or 0)
					if want then
						near(name .. "_" .. want[1] .. "_time", at, want[2])
					end
					if want and want[4] then
						near(name .. "_" .. want[4] .. "_time_0", startAt, 0)
					end
				end
			end)

			-- Approved keys (owner gate): Sample at each approved time gives the approved pose. Counts proposed in the spec.
			section("approved", function()
				local counts = { idle = 3, gates = 6, enuma = 8, shields = 4 }
				for name, want in counts do
					local worst = 0
					local keys = Poses.Approved[name] or {}
					for _, key in keys do
						local parts = Poses.Sample(name, key.Time)
						for part, v in key.Parts do
							local got = parts[part]
							local d = got and (got - Vector3.new(v[1], v[2], v[3])) or Vector3.new(1e9, 0, 0)
							worst = math.max(worst, math.abs(d.X), math.abs(d.Y), math.abs(d.Z))
						end
					end
					flag(name .. "_approved_reproduced", worst <= 0.01, worst, 0.01)
					eq(name .. "_approved_count", #keys, want)
				end
			end)

			-- The cycle: idle, gates_in, gates, idle, idle, enuma_in, enuma, idle, idle, shields_in, shields, idle (38.85 s).
			section("schedule", function()
				local START = 5000
				local idle = true
				for t = 0, Event.IntroSeconds - 0.05, 0.1 do
					idle = idle and Poses.Schedule(START, START + t) == "idle"
				end
				flag("schedule_idle_during_intro", idle)
				local seen, order, last = {}, {}, nil
				for t = Event.IntroSeconds, Event.IntroSeconds + 2 * Poses.CycleSeconds, 0.01 do
					local move = Poses.Schedule(START, START + t)
					seen[move] = true
					if move ~= last then
						table.insert(order, move)
						last = move
					end
				end
				for _, name in { "gates", "enuma", "shields" } do
					flag("schedule_covers_" .. name, seen[name] == true)
				end
				local moves, leadIns = {}, true
				for i, name in order do
					if name == "gates" or name == "enuma" or name == "shields" then
						table.insert(moves, name)
						leadIns = leadIns and order[i - 1] == name .. "_in"
					end
				end
				eq("schedule_order_fixed", table.concat(moves, ","), "gates,enuma,shields,gates,enuma,shields")
				flag("schedule_lead_ins_before_moves", leadIns)
				near("cycle_38_85", Poses.CycleSeconds, CYCLE_SECONDS, 0.01)
				eq("rise_starts_at_0", Poses.RiseAt(0), 0)
				eq("rise_ends_at_1", Poses.RiseAt(Event.RiseSeconds), 1)
			end)
		end

		if BossDodge then
			section("dodge_timeline", function()
				local moments = momentsOf(BossDodge, KING)
				local ordered, names, last = true, {}, 0
				local onPose = true
				local minBar = math.huge
				for _, row in moments do
					ordered = ordered and type(row.At) == "number" and row.At > last
					names[tostring(row.Name)] = true
					if row.Name ~= "shields" then
						minBar = math.min(minBar, (row.At or 0) - last)
					end
					if Poses and type(row.At) == "number" then
						local move, localTime = Poses.Schedule(0, Event.IntroSeconds + row.At + 0.001)
						local want = MOVE_EVENTS[move]
						onPose = onPose and want ~= nil and want[1] == row.Name and approx(localTime, want[2], 0.01)
					end
					last = row.At or last
				end
				flag("king_moments_in_order", ordered)
				for _, name in { "gates", "enuma", "shields" } do
					flag("king_moments_have_" .. name, names[name] == true)
				end
				local stray = {}
				for name in names do
					if name ~= "gates" and name ~= "enuma" and name ~= "shields" then
						table.insert(stray, name)
					end
				end
				eq("king_moments_only_his_events", table.concat(stray, ","), "")
				flag("king_moments_on_pose_events", onPose)
				local sequence = {}
				for i = 1, 6 do
					table.insert(sequence, tostring(moments[i] and moments[i].Name))
				end
				eq("king_moments_cycle_order", table.concat(sequence, ","), "gates,enuma,shields,gates,enuma,shields")
				-- Room for the Dodge bar's 1.5 s and its 0.3 s pop before each bar moment.
				flag("gap_before_bar_moment", minBar >= 1.5 + 0.3, minBar, 1.8)
				local back = true
				for _, row in moments do
					back = back and BossDodge.IndexAtOrBefore(row.At + 0.01, KING) == row.Index
				end
				flag("index_at_or_before_king", back)
				local raga, mage = true, true
				for i = 1, 10 do
					local a1, n1 = BossDodge.Moment(i)
					local a2, n2 = BossDodge.Moment(i, RAGA)
					raga = raga and a1 == a2 and n1 == n2
					local m1 = select(2, BossDodge.Moment(i, MAGE))
					mage = mage and (m1 == "Lightning" or m1 == "Barrage")
				end
				flag("raga_moments_unchanged", raga)
				flag("mage_moments_unchanged", mage)
				local kingMoves = Catalog and Catalog.Get(KING).Moves or {}
				eq("hit_text_gates", kingMoves.gates and kingMoves.gates.HitText, HIT_TEXT.gates)
				eq("hit_text_enuma", kingMoves.enuma and kingMoves.enuma.HitText, HIT_TEXT.enuma)
				if type(BossDodge.Slot) == "function" then
					eq("slot_none_for_king", BossDodge.Slot(KING), nil) -- no miniboss
				end
			end)
		end

		if Catalog then
			section("catalog", function()
				flag("catalog_order", H.same(Catalog.Order, { RAGA, MAGE, KING }))
				local king, mage, raga = Catalog.Get(KING), Catalog.Get(MAGE), Catalog.Get(RAGA)
				flag("catalog_get_king_is_a_row", type(king) == "table" and not rawequal(king, raga))
				if type(king) ~= "table" then
					return
				end
				for _, field in
					{
						"Id",
						"Name",
						"Poses",
						"Stages",
						"Moves",
						"Statuses",
						"ChatMessage",
						"WarningText",
						"InviteTitle",
						"InviteHint",
						"DefeatedTitle",
						"Portrait",
						"ModelName",
						"TargetPart",
						"Camera",
						"Chests",
						"Relics",
						"DodgeIcon",
						"WaitCamera",
					}
				do
					flag("catalog_king_has_" .. field, king[field] ~= nil)
				end
				eq("king_id", king.Id, KING)
				eq("king_name", king.Name, "The Golden King")
				eq("king_poses", king.Poses, "BossKingPoses")
				eq("king_stages_1", king.Stages, 1)
				local moves = king.Moves or {}
				eq("king_gates_cost", moves.gates and moves.gates.Cost, COST.gates)
				eq("king_enuma_cost", moves.enuma and moves.enuma.Cost, COST.enuma)
				eq("king_shields_cost_0", moves.shields and moves.shields.Cost, 0)
				local count = 0
				for _ in moves do
					count += 1
				end
				eq("king_three_moves", count, 3)
				for name, text in MOVE_CHAT do
					eq("king_" .. name .. "_chat", moves[name] and moves[name].Chat, text)
				end
				local status = king.Statuses[1] or {}
				eq("king_one_status", #king.Statuses, 1)
				eq("king_status_fortified", status.Id, "Fortified")
				eq("king_status_self", status.Self, true)
				eq("king_status_not_minion", status.Minion, nil)
				eq("king_status_event_shields", status.Event, "shields")
				near("king_status_cut_0_4", status.Cut, FORTIFIED_CUT)
				eq("king_fortified_text", king.FortifiedText, FORTIFIED_NOTICE)
				eq("king_no_minion", king.Minion, nil)
				flag("king_chests", H.same(king.Chests, { "relic_chest_king" }))
				eq("king_relics", king.Relics, KING)
				eq("king_chat", king.ChatMessage, CHAT)
				eq("king_warning", king.WarningText, WARNING)
				if king.ActiveText ~= nil then
					eq("king_active", king.ActiveText, "The Golden King is judging you right now")
				end
				eq("king_invite_title", king.InviteTitle, "THE GOLDEN KING EVENT")
				eq("king_invite_hint", king.InviteHint, "Teleport to fight The Golden King before the timer ends")
				eq("king_defeated_title", king.DefeatedTitle, "The Golden King Defeated!")
				eq("king_model_name", king.ModelName, "GoldenKing")
				eq("king_target_part", king.TargetPart, "Torso")
				eq("king_portrait", king.Portrait, Art and Art.Portrait)
				eq("king_dodge_icon", king.DodgeIcon, Art and Art.KeyIcon)
				flag("mage_row_kept", type(mage) == "table" and mage.Moves.Lightning ~= nil and mage.Minion ~= nil)
				flag("mage_chests_kept", type(mage) == "table" and H.same(mage.Chests, { "relic_chest_mage" }))
				-- Section 5 safeguard: only the tweaked title reaches players.
				local leaks = {}
				for _, text in stringsIn(king, {}) do
					if realNameIn(text) then
						table.insert(leaks, text)
					end
				end
				eq("catalog_no_real_names", #leaks, 0)
				local was = ReplicatedStorage:GetAttribute("BossEventBoss")
				local okSet, current = pcall(function()
					ReplicatedStorage:SetAttribute("BossEventBoss", KING)
					local row = Catalog.Current()
					ReplicatedStorage:SetAttribute("BossEventBoss", nil)
					return row
				end)
				ReplicatedStorage:SetAttribute("BossEventBoss", was)
				flag("catalog_current_king", okSet and rawequal(current, king))
			end)
		end

		return r
	end

	return { boss_king_event = boss_king_event, boss_king_arena = boss_king_arena, boss_king_anim = boss_king_anim }
end

return Tests
