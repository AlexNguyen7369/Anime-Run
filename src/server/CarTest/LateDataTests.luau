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
local H = require(script.Parent.AcceptanceSupport)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = script.Parent.Parent
local Shared = ReplicatedStorage.Shared
local Tests = {}

local T0 = 3000000 -- the fake server clock's start
Tests.NAMES = { "BossRagaPoses", "SidekickAttacks" }
Tests.JOIN_CONTAINERS = { "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui" }

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
		S.Start("Test")
	end)
	flag("event_started", ok, ok and 1 or tostring(err))
	local folder = ReplicatedStorage:FindFirstChild("LateData")
	for _, name in Tests.NAMES do
		local copy = folder and folder:FindFirstChild(name)
		flag("after_start_" .. name .. "_in_ReplicatedStorage_LateData", copy ~= nil and copy:IsA("ModuleScript"))
		flag("after_start_" .. name .. "_loads", copy ~= nil and H.module(folder, name) ~= nil)
	end
	pcall(function()
		S.SetClock(nil)
		S.Reset(workspace:GetServerTimeNow())
	end)
	return r
end

return Tests
