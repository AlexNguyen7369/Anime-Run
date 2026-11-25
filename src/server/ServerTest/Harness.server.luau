--!nonstrict
-- Runs the physics scenarios and prints machine-readable results for the test agents.
--   [SERVERTEST] START
--   [SERVERTEST] {"scenario":"accel","pass":true,...}
--   [SERVERTEST] SKIP <scenario> reason=<why>   (a World 1 scenario in another world: missing coverage, not a pass)
--   [SERVERTEST] END pass=5 fail=0 skip=0
-- Also mirrored into ReplicatedStorage attribute "ServerTestResult" (JSON) for execute_luau readers.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestConfig = require(script.Parent.TestConfig)
-- Design doc 7 "Join size": what a joining client gets, read at load, before any boss event can publish (LateDataTests).
do
	local LateData = require(script.Parent.LateDataTests)
	local snapshot = {}
	for _, service in LateData.JOIN_CONTAINERS do
		for _, name in LateData.NAMES do
			snapshot[service .. "." .. name] = game:GetService(service):FindFirstChild(name, true) ~= nil
		end
	end
	require(script.Parent.AcceptanceSupport).JoinSnapshot = snapshot
end
local Scenarios = require(script.Parent.Scenarios)

local running = false

-- Harness stability fix, NOT a loosening: no limit or expectation changed. The first scenarios of a
-- cold start were disturbed by start-up frame hitches (tracks/money building right before the run),
-- so wait for the world to settle first.
local WARMUP_MIN_SECONDS = 3
local WARMUP_STABLE_FRAMES = 90
local WARMUP_MAX_DT = 0.03
local WARMUP_CAP_SECONDS = 20

local RunService = game:GetService("RunService")

local function warmUp()
	local start = os.clock()
	local frames, streak = 0, 0
	while true do
		local dt = RunService.Heartbeat:Wait()
		frames += 1
		if dt < WARMUP_MAX_DT then
			streak += 1
		else
			streak = 0
		end
		local waited = os.clock() - start
		local stable = waited >= WARMUP_MIN_SECONDS and streak >= WARMUP_STABLE_FRAMES
		if stable or waited >= WARMUP_CAP_SECONDS then
			print(("[SERVERTEST] WARMUP frames=%d waited=%.1f stable=%s"):format(frames, waited, tostring(stable)))
			return
		end
	end
end

local function runAll()
	if running then
		return
	end
	running = true
	-- Design doc 4.24 "Harness saves": scenarios that use the live player never reach the live save.
	local isolated, refusal = pcall(require(script.Parent.HarnessSave).Isolate)
	if not isolated then
		warn("[SERVERTEST] REFUSED " .. tostring(refusal))
		ReplicatedStorage:SetAttribute("ServerTestRun", false)
		running = false
		return
	end
	ReplicatedStorage:SetAttribute("ServerTestRunning", true)
	local weatherModule = script.Parent.Parent:FindFirstChild("WeatherService")
	local weather = weatherModule and require(weatherModule)
	if weather then
		weather.SetEvent("")
	end
	print("[SERVERTEST] START")
	warmUp()

	-- Track the worst frame time per scenario (reported as metrics.max_dt).
	local maxDt = 0
	local dtConn = RunService.Heartbeat:Connect(function(dt)
		if dt > maxDt then
			maxDt = dt
		end
	end)
	local results, pass, fail = {}, 0, 0

	local names = table.clone(TestConfig.Scenarios)
	local trackTests = script.Parent:FindFirstChild("TrackTests")
	-- on-demand subset (e.g. TestConfig.OnDemand's speed_probe): only the named scenarios, no track tests
	local only = ReplicatedStorage:GetAttribute("ServerTestOnly")
	if type(only) == "string" and only ~= "" then
		names = string.split((string.gsub(only, "%s", "")), ",")
		trackTests = nil
	end
	-- Written against World 1's tracks or biomes (TestConfig.World1Only, and every TrackTests file): in
	-- another world they are reported as SKIP, never as a pass or a fail.
	local world1 = require(ReplicatedStorage.Shared.WorldConfig).Id == 1
	local skipped = {}
	if not world1 then
		local kept = {}
		for _, name in names do
			if TestConfig.World1Only[name] then
				table.insert(skipped, { name, TestConfig.World1Only[name] })
			else
				table.insert(kept, name)
			end
		end
		names = kept
		if trackTests then
			for _, module in trackTests:GetChildren() do
				table.insert(skipped, { "track:" .. module.Name, TestConfig.World1TrackTests })
			end
			trackTests = nil
		end
	end
	for _, skip in skipped do
		print("[SERVERTEST] SKIP " .. skip[1] .. " reason=" .. skip[2])
	end
	if trackTests then
		local found = {}
		for _, module in trackTests:GetChildren() do
			if module:IsA("ModuleScript") then
				table.insert(found, "track:" .. module.Name)
			end
		end
		table.sort(found)
		table.move(found, 1, #found, #names + 1, names)
	end

	for _, name in names do
		maxDt = 0
		local ok, res = pcall(Scenarios.Run, name)
		if not ok then
			res = { scenario = name, pass = false, error = tostring(res), checks = {}, metrics = {} }
		end
		if type(res.metrics) == "table" then
			res.metrics.max_dt = math.floor(maxDt * 1000 + 0.5) / 1000
		end
		table.insert(results, res)
		if res.pass then
			pass += 1
		else
			fail += 1
		end
		print("[SERVERTEST] " .. HttpService:JSONEncode(res))
	end
	dtConn:Disconnect()
	ReplicatedStorage:SetAttribute(
		"ServerTestResult",
		HttpService:JSONEncode({ pass = pass, fail = fail, skip = #skipped, skipped = skipped, results = results })
	)
	print(("[SERVERTEST] END pass=%d fail=%d skip=%d"):format(pass, fail, #skipped))
	ReplicatedStorage:SetAttribute("ServerTestRun", false)
	ReplicatedStorage:SetAttribute("ServerTestRunning", false)
	running = false
end

ReplicatedStorage:GetAttributeChangedSignal("ServerTestRun"):Connect(function()
	if ReplicatedStorage:GetAttribute("ServerTestRun") == true then
		task.spawn(runAll)
	end
end)

if TestConfig.Enabled then
	task.delay(2, runAll)
end
