--!nonstrict
-- BRIEF: docs/GAME_DESIGN_REQUIREMENTS.md section 7 "Join size" (owner 2026-11-10): large client-only data a player needs only in a
-- later phase is not required at join; it loads on the first boss event that needs it. A ModuleScript in a replicated container
-- reaches every client at join whether or not it is required, so the big modules must not sit in one at server start.
-- Contract these tests assume beyond the brief (implementer: report a change, do not loosen):
--   ServerStorage.LateData holds the generated ModuleScripts BossRagaPoses and SidekickAttacks; each requires there.
--   At server start neither name is anywhere under ReplicatedStorage, ReplicatedFirst, StarterPlayer or StarterGui. Read from the
--     harness's snapshot (AcceptanceSupport.JoinSnapshot), taken when the harness loads, before any event can publish.
--   The server's own reads (Schedule, the moves' Events, CycleSeconds, Bind) stay reachable: Shared/BossDodge and
--     Server/CharacterModelService load, and BossDodge's events are the full module's.
--   BossEventService.Start(source) leaves ModuleScripts ReplicatedStorage.LateData.BossRagaPoses and .SidekickAttacks, where the
--     client requires them. Shared/LateData.Deliver(...names) does the same; UiTestSetup's faked boss states call it.
-- Per boss (owner 2026-11-12, design doc 7 "Join size", docs/BOSS_EVENT_SPEC.md "The Elf Mage" Load line):
--   Every BossCatalog row names its late-data module in Poses (boss_raga "BossRagaPoses", boss_mage "BossMagePoses"), held in
--     ServerStorage.LateData. The server delivers only the pose module of the boss concerned, once, and a delivered one stays:
--     the next boss X from BossEventConfig.LateLeadSeconds (proposed 120, 30..300) before its timed start (BossEventNextAt), seen
--     by Advance(t) with SetClock at t, NOT when BossEventNextBoss is set; on Start(source, X) or Start("Paid") picking X; and on
--     BossArenaPreview turning on, for the previewed boss (ReplicatedStorage BossEventBoss, nil = boss_raga, as BossArenaView reads it).
--   The cases clear the boss pose copies from ReplicatedStorage.LateData (test side) and put back the ones there before.
-- Removal (owner 2026-11-12, design doc 7 "Join size", BOSS_EVENT_SPEC "The Elf Mage" Load line): when boss X's event ends (any
--   reason: End(reason) or the clock's timeout) X's pose copy leaves ReplicatedStorage.LateData, unless X is BossEventNextBoss and
--   the clock is inside LateLeadSeconds of BossEventNextAt; an arena preview that ends with no event removes the previewed boss's
--   copy; neither removes another boss's copy delivered for a preview. A later event of X delivers again. Judged on the folder's
--   children only (the implementer's contract: Shared/LateData.Remove(...names) beside Deliver, server only).
--   SidekickAttacks is shared by every boss and by summon reveals: its removal is not part of this rule, and no case here
--   asserts it either way.
local H = require(script.Parent.AcceptanceSupport)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Tests = {}

local T0 = 3000000 -- the fake server clock's start
Tests.NAMES = { "BossRagaPoses", "BossMagePoses", "BossKingPoses", "SidekickAttacks" }
Tests.JOIN_CONTAINERS = { "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui" }
local BOSS_POSES = { boss_raga = "BossRagaPoses", boss_mage = "BossMagePoses" }
local OTHER = { boss_raga = "boss_mage", boss_mage = "boss_raga" }

-- A ModuleScript copy in ReplicatedStorage.LateData, where a client requires it.
local function delivered(name)
	local folder = ReplicatedStorage:FindFirstChild("LateData")
	local copy = folder and folder:FindFirstChild(name)
	return copy ~= nil and copy:IsA("ModuleScript")
end

-- Test side: takes the boss pose copies out, so a case sees only its own delivery.
local function clearPoses()
	local folder = ReplicatedStorage:FindFirstChild("LateData")
	for _, name in BOSS_POSES do
		local copy = folder and folder:FindFirstChild(name)
		if copy then
			copy:Destroy()
		end
	end
end

function Tests.late_data()
	local r, flag = H.report("late_data")

	local snapshot = H.JoinSnapshot
	flag("join_snapshot_taken", snapshot ~= nil)
	for _, name in Tests.NAMES do
		for _, service in Tests.JOIN_CONTAINERS do
			local present = snapshot and snapshot[service .. "." .. name]
			flag(("join_has_no_%s_in_%s"):format(name, service), present == false, present and 1 or 0, 0)
		end
		flag(name .. "_in_ServerStorage_LateData", H.lateData(name) ~= nil)
	end

	local dodge = H.module(Shared, "BossDodge")
	flag("server_reads_boss_dodge", dodge ~= nil)
	local poses = H.lateData("BossRagaPoses")
	if dodge and poses then
		for move, data in poses.Moves do
			for _, event in data.Events do
				local times = dodge.Events[event.Name]
				flag(("server_event_%s_%s"):format(move, event.Name), type(times) == "table" and #times > 0)
			end
		end
		flag("server_moment_1", type((dodge.Moment(1))) == "number")
	end
	flag("server_reads_bind", H.module(Server, "CharacterModelService") ~= nil)

	local S = H.module(Server, "BossEventService")
	flag("service_exists", S ~= nil)
	if not S then
		return r
	end
	local ok, err = pcall(function()
		S.SetClock(function()
			return T0
		end)
		S.Reset(T0)
		clearPoses()
		S.Start("Test")
	end)
	flag("event_started", ok, ok and 1 or tostring(err))
	local folder = ReplicatedStorage:FindFirstChild("LateData")
	for _, name in { "BossRagaPoses", "SidekickAttacks" } do -- the default boss's event (CarTestRunning: boss_raga)
		local copy = folder and folder:FindFirstChild(name)
		flag("after_start_" .. name .. "_in_ReplicatedStorage_LateData", copy ~= nil and copy:IsA("ModuleScript"))
		flag("after_start_" .. name .. "_loads", copy ~= nil and H.module(folder, name) ~= nil)
	end

	-- Per boss: only the boss concerned loads (owner 2026-11-12).
	local Catalog = H.module(Shared, "BossCatalog")
	flag("catalog_loads", Catalog ~= nil)
	for id, name in BOSS_POSES do
		local row = Catalog and Catalog.Get(id)
		flag(
			id .. "_row_names_poses",
			row ~= nil and row.Id == id and row.Poses == name,
			row and tostring(row.Poses),
			name
		)
		flag(
			id .. "_poses_in_ServerStorage_LateData",
			row ~= nil and type(row.Poses) == "string" and H.lateData(row.Poses) ~= nil
		)
	end
	for _, id in Catalog and Catalog.Order or {} do
		flag(
			id .. "_in_order_has_poses",
			type(Catalog.Get(id).Poses) == "string" and H.lateData(Catalog.Get(id).Poses) ~= nil
		)
	end

	local Cfg = H.module(Shared, "BossEventConfig")
	local LEAD = Cfg and Cfg.LateLeadSeconds
	flag("late_lead_seconds_30_to_300", type(LEAD) == "number" and LEAD >= 30 and LEAD <= 300, LEAD, "30 to 300")
	local INSIDE = (type(LEAD) == "number" and LEAD or 120) - 1 -- seconds before the timed start, inside the lead
	local clockAt = T0
	local function at(t) -- the fake clock and the scheduler tick both at t
		clockAt = t
		S.Advance(t)
	end

	local before = {}
	for _, name in BOSS_POSES do
		before[name] = delivered(name)
	end
	local realPick = S.Hooks.PickBoss
	local savedPreview = ReplicatedStorage:GetAttribute("BossArenaPreview")
	local function pick(id)
		S.Hooks.PickBoss = function()
			return id
		end
	end
	local cases, caseErr = pcall(function()
		S.SetClock(function()
			return clockAt
		end)
		for id, name in BOSS_POSES do
			local other = BOSS_POSES[OTHER[id]]
			-- Announced as the next boss, more than the lead away: nothing loads yet. Inside the lead: X loads, the other does not.
			clearPoses()
			pick(id)
			clockAt = T0
			S.Reset(T0)
			local startAt = ReplicatedStorage:GetAttribute("BossEventNextAt")
			flag("announce_" .. id .. "_is_next", ReplicatedStorage:GetAttribute("BossEventNextBoss") == id)
			flag("announce_" .. id .. "_not_yet", not delivered(name))
			flag("announce_" .. id .. "_skips_other", not delivered(other))
			flag("announce_" .. id .. "_start_known", type(startAt) == "number" and startAt - T0 > INSIDE + 1, startAt)
			if type(startAt) == "number" then
				at(startAt - INSIDE - 2) -- still outside the lead
				flag("before_lead_" .. id .. "_not_yet", not delivered(name))
				at(startAt - INSIDE)
				flag("lead_" .. id .. "_no_event_yet", ReplicatedStorage:GetAttribute("BossEventBoss") == nil)
				flag("lead_" .. id .. "_delivers_own", delivered(name))
				flag("lead_" .. id .. "_skips_other", not delivered(other))
			end
			clockAt = T0

			-- An admin start and a paid spawn (no id: Hooks.PickBoss) of X, the next boss also X: the event's client copy is
			-- X's alone.
			for _, source in { "Admin", "Paid" } do
				clearPoses()
				pick(id)
				S.Reset(T0)
				local started = S.Start(source, source == "Admin" and id or nil)
				local tag = ("event_%s_%s"):format(string.lower(source), id)
				flag(tag .. "_started", started == true and ReplicatedStorage:GetAttribute("BossEventBoss") == id)
				flag(tag .. "_client_has_own", delivered(name))
				flag(tag .. "_client_lacks_other", not delivered(other))
				S.End("Reset")
			end

			-- The arena preview with no event: the previewed boss loads, the other does not; its end removes the copy.
			pick(OTHER[id])
			S.Reset(T0)
			ReplicatedStorage:SetAttribute("BossArenaPreview", nil)
			task.wait()
			clearPoses()
			ReplicatedStorage:SetAttribute("BossEventBoss", id)
			ReplicatedStorage:SetAttribute("BossArenaPreview", true)
			task.wait()
			flag("preview_" .. id .. "_delivers_own", delivered(name))
			flag("preview_" .. id .. "_skips_other", not delivered(other))
			ReplicatedStorage:SetAttribute("BossArenaPreview", nil)
			task.wait()
			flag("preview_end_" .. id .. "_removes_own", not delivered(name))
			ReplicatedStorage:SetAttribute("BossEventBoss", nil)
			task.wait()

			-- Removal after the event (owner 2026-11-12). The next boss is the other one, far outside its lead.
			-- An admin end, then a second event of X delivers again and ends on the clock (its timeout or nobody joining).
			clearPoses()
			pick(OTHER[id])
			clockAt = T0
			S.Reset(T0)
			S.Start("Admin", id)
			flag("end_" .. id .. "_had_own", delivered(name))
			S.End("Admin")
			flag("end_" .. id .. "_removes_own", not delivered(name))
			S.Start("Admin", id)
			flag("again_" .. id .. "_delivers_own", delivered(name))
			local endsAt = ReplicatedStorage:GetAttribute("BossEventEndsAt")
			if type(endsAt) == "number" then
				at(endsAt + 1)
			end
			flag("timeout_" .. id .. "_event_over", ReplicatedStorage:GetAttribute("BossEventBoss") == nil)
			flag("timeout_" .. id .. "_removes_own", not delivered(name))
			clockAt = T0
			S.Reset(T0)

			-- X is the next boss and the clock is inside its lead: ending X's (admin) event keeps the copy for the timed one.
			clearPoses()
			pick(id)
			clockAt = T0
			S.Reset(T0)
			local nextAt = ReplicatedStorage:GetAttribute("BossEventNextAt")
			if type(nextAt) == "number" then
				at(nextAt - INSIDE)
				S.Start("Admin", id)
				S.End("Admin")
			end
			flag("end_" .. id .. "_kept_inside_lead", delivered(name))
			clockAt = T0
			S.Reset(T0)

			-- The other boss Y is delivered for an arena preview while X's event runs: X's end leaves Y's copy.
			clearPoses()
			pick(OTHER[id])
			S.Reset(T0)
			ReplicatedStorage:SetAttribute("BossEventBoss", OTHER[id])
			ReplicatedStorage:SetAttribute("BossArenaPreview", true)
			task.wait()
			local previewed = delivered(other)
			S.Start("Admin", id)
			S.End("Admin")
			flag(
				"end_" .. id .. "_keeps_other_preview",
				previewed and delivered(other),
				previewed and 1 or "not staged"
			)
			ReplicatedStorage:SetAttribute("BossArenaPreview", nil)
			ReplicatedStorage:SetAttribute("BossEventBoss", nil)
			task.wait()
		end

		-- The timed cycle (owner 2026-11-12): The Elf Mage's lead delivers her, her timed event runs with Big Raga named next,
		-- its end removes her copy, and Big Raga's lead then delivers his.
		clearPoses()
		pick("boss_mage")
		clockAt = T0
		S.Reset(T0)
		local mageAt = ReplicatedStorage:GetAttribute("BossEventNextAt")
		if type(mageAt) == "number" then
			at(mageAt - INSIDE)
			flag("mage_lead_delivers_mage", delivered("BossMagePoses"))
			pick("boss_raga")
			at(mageAt)
			flag("mage_timed_event_started", ReplicatedStorage:GetAttribute("BossEventBoss") == "boss_mage")
			S.End("Timeout")
		end
		flag("delivered_mage_removed_after_event", not delivered("BossMagePoses"))
		local ragaAt = ReplicatedStorage:GetAttribute("BossEventNextAt")
		if type(ragaAt) == "number" then
			at(ragaAt - INSIDE)
		end
		flag("then_raga_delivered", delivered("BossRagaPoses"))
		flag("then_mage_not_back", not delivered("BossMagePoses"))
	end)
	flag("per_boss_cases_ran", cases, cases and 1 or tostring(caseErr))

	S.Hooks.PickBoss = realPick
	ReplicatedStorage:SetAttribute("BossArenaPreview", savedPreview)
	pcall(function()
		S.SetClock(nil)
		S.Reset(workspace:GetServerTimeNow())
	end)
	local LateData = H.module(Shared, "LateData")
	for name, was in before do
		if was and not delivered(name) and LateData then
			LateData.Deliver(name)
		end
	end
	return r
end

return Tests
