--!nonstrict
-- Runs the UI compatibility scenarios (UiScenarios) on the client and prints machine-readable results:
--   [UITEST] START
--   [UITEST] {"scenario":"ui_layout","pass":false,"checks":[{"name":...,"value":...,"limit":...,"pass":...}]}
--   [UITEST] END pass=N fail=N
-- Also mirrored into the LocalPlayer attribute "UiTestResult" (JSON) for execute_luau readers. Every result attribute
-- this harness sets (UiTestResult, UiTestScenarioResult, UiTestClickResult, UiTestClickTarget) is on the CLIENT's
-- LocalPlayer and does NOT replicate: read it in the client datamodel (or the console), never from the server.
-- Trigger: ReplicatedStorage attribute UiTestRun = true (set it to false first if it is already true).
-- Clicks: ReplicatedStorage attribute UiTestClick = <UiSpec.Clicks Id> (set it to nil between clicks, and clear
-- UiTestClickDone before each click); see the protocol in UiSpec.Clicks. Owned by ui-test-writer.
-- Screenshots of a held run: ReplicatedStorage attribute UiRunVisualCapture, set on the client (UiRunVisual, at Capture).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiRunVisual = require(script.Parent:WaitForChild("UiRunVisual"))

local player = Players.LocalPlayer
local busy = false

-- Normal play (no harness attribute set) runs no test code: UiScenarios loads and starts its observers on the first
-- harness request (a server fixture UiTestSetup, UiTestRun, UiTestClick, UiTestScenario or a capture), or at once
-- when one is already set on join.
local UiScenarios, starting = nil, false
local function start()
	if starting then
		while not UiScenarios do -- another trigger is loading it: Init runs once
			task.wait()
		end
		return
	end
	starting = true
	local scenarios = require(script.Parent:WaitForChild("UiScenarios"))
	scenarios.Init()
	UiScenarios = scenarios
end
local TRIGGERS = { "UiTestSetup", "UiTestRun", "UiTestClick", "UiTestScenario", UiRunVisual.CAPTURE_ATTR }
for _, name in TRIGGERS do
	if ReplicatedStorage:GetAttribute(name) ~= nil then
		start()
	end
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(start)
end

-- Design doc 4.24 "Harness saves": nothing runs until the server says this session writes to memory only
-- (ReplicatedStorage attribute SaveIsolated, set by Server/ServerTest/HarnessSave). A trigger set on the client
-- alone never reaches the server, so it is refused here.
local ISOLATE_WAIT = 10
local function isolated(what)
	local deadline = os.clock() + ISOLATE_WAIT
	while ReplicatedStorage:GetAttribute("SaveIsolated") ~= true do
		if os.clock() > deadline then
			warn(
				"[UITEST] REFUSED "
					.. what
					.. ": the save is not isolated. Set the trigger attribute from the Server datamodel."
			)
			return false
		end
		task.wait(0.1)
	end
	return true
end

local function refusal(scenario)
	return {
		scenario = scenario,
		pass = false,
		error = "save not isolated",
		checks = { { name = "save_isolated", value = false, limit = true, pass = false } },
	}
end

local function runAll()
	if busy then
		return
	end
	busy = true
	if not isolated("UiTestRun") then
		local res = refusal("save_isolated")
		print("[UITEST] START")
		print("[UITEST] " .. HttpService:JSONEncode(res))
		player:SetAttribute("UiTestResult", HttpService:JSONEncode({ pass = 0, fail = 1, results = { res } }))
		print("[UITEST] END pass=0 fail=1")
		busy = false
		return
	end
	start()
	print("[UITEST] START")
	pcall(UiScenarios.PlayWithoutPasses)
	pcall(UiScenarios.DismissWelcome)
	pcall(UiScenarios.DismissDaily) -- docs/BUGS.md ui-harness-daily-popup
	local results, pass, fail = {}, 0, 0
	for _, name in UiScenarios.Names do
		local ok, res = pcall(UiScenarios.Run, name)
		if not ok then
			res = {
				scenario = name,
				pass = false,
				error = tostring(res),
				checks = { { name = "scenario_ran", value = tostring(res), limit = "no error", pass = false } },
			}
		end
		table.insert(results, res)
		if res.pass then
			pass += 1
		else
			fail += 1
		end
		print("[UITEST] " .. HttpService:JSONEncode(res))
	end
	player:SetAttribute("UiTestResult", HttpService:JSONEncode({ pass = pass, fail = fail, results = results }))
	-- Checks only a person can do (UiSpec.Clicks Manual): listed so the report shows them as MANUAL, never as passes
	for _, click in UiScenarios.ManualClicks() do
		print(("[UITEST] MANUAL %s reason=%s"):format(click.Id, click.Manual))
	end
	-- Whole scenarios only a person can do (UiSpec.ManualScenarios), run by hand with UiTestScenario
	for _, scenario in UiScenarios.ManualScenarios() do
		print(("[UITEST] MANUAL %s reason=%s"):format(scenario.Name, scenario.Manual))
	end
	pcall(UiScenarios.RestoreSetups) -- the states UiScenarios.Needs asked for go back as they were
	print(("[UITEST] END pass=%d fail=%d"):format(pass, fail))
	pcall(UiScenarios.CloseFixturePanels)
	busy = false
end

local function runClick(id)
	while busy do
		task.wait(0.1)
	end
	busy = true
	local ok, res
	if isolated("UiTestClick") then
		start()
		pcall(UiScenarios.DismissWelcome) -- as before a run: a lone click must not press under World 2's welcome
		pcall(UiScenarios.DismissDaily)
		ok, res = pcall(UiScenarios.RunClick, id)
	else
		ok, res = true, refusal("click:" .. tostring(id))
	end
	if not ok then
		res = {
			scenario = "click:" .. tostring(id),
			pass = false,
			error = tostring(res),
			checks = { { name = "click_ran", value = tostring(res), limit = "no error", pass = false } },
		}
	end
	if UiScenarios then
		pcall(UiScenarios.CloseFixturePanels)
	end
	local json = HttpService:JSONEncode(res)
	print("[UITEST] " .. json)
	player:SetAttribute("UiTestClickResult", json)
	busy = false
end

ReplicatedStorage:GetAttributeChangedSignal("UiTestRun"):Connect(function()
	if ReplicatedStorage:GetAttribute("UiTestRun") == true then
		task.spawn(runAll)
	end
end)

ReplicatedStorage:GetAttributeChangedSignal("UiTestClick"):Connect(function()
	local id = ReplicatedStorage:GetAttribute("UiTestClick")
	if type(id) == "string" and id ~= "" then
		task.spawn(runClick, id)
	end
end)

-- Short fixture-driven checks for world-pad transitions and weather states.
ReplicatedStorage:GetAttributeChangedSignal("UiTestScenario"):Connect(function()
	local name = ReplicatedStorage:GetAttribute("UiTestScenario")
	if type(name) ~= "string" or name == "" then
		return
	end
	task.spawn(function()
		while busy do
			task.wait(0.1)
		end
		busy = true
		if not isolated("UiTestScenario") then
			local json = HttpService:JSONEncode(refusal(name))
			print("[UITEST] " .. json)
			player:SetAttribute("UiTestScenarioResult", json)
			busy = false
			return
		end
		start()
		pcall(UiScenarios.PlayWithoutPasses)
		pcall(UiScenarios.DismissWelcome)
		pcall(UiScenarios.DismissDaily) -- docs/BUGS.md ui-harness-daily-popup
		local ok, res = pcall(UiScenarios.Run, name)
		if not ok then
			res = {
				scenario = name,
				pass = false,
				checks = { { name = "scenario_ran", value = tostring(res), limit = "no error", pass = false } },
			}
		end
		pcall(UiScenarios.RestoreSetups)
		pcall(UiScenarios.CloseFixturePanels)
		local json = HttpService:JSONEncode(res)
		print("[UITEST] " .. json)
		player:SetAttribute("UiTestScenarioResult", json)
		busy = false
	end)
end)

ReplicatedStorage:GetAttributeChangedSignal(UiRunVisual.CAPTURE_ATTR):Connect(function()
	local command = ReplicatedStorage:GetAttribute(UiRunVisual.CAPTURE_ATTR)
	if type(command) == "string" and command ~= "" then
		task.spawn(UiRunVisual.Capture, command)
	end
end)

if ReplicatedStorage:GetAttribute("UiTestRun") == true then
	task.spawn(runAll)
end
