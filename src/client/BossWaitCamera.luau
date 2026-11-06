--!nonstrict
-- The exhaustion view's camera (docs/BOSS_EVENT_SPEC.md "Exhaustion view"), stepped by Client/RunnerView. It follows only the
-- local player's own BossWaitEndsAt while BossEvent is true, and holds the camera Scriptable until it has brought it back. The growth
-- cutscene ("Phase 2") takes the same view of the boss, back as the scream ends; REDUCED EFFECTS keeps the camera still through it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.BossArenaConfig)
local Cfg = require(Shared.BossEventConfig)
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local player = Players.LocalPlayer

-- Placeholders.
local PULL_SECONDS = 0.6
local RETURN_SECONDS = 0.5
local DRIFT_STUDS = 3
local DRIFT_RATE = 0.5 -- radians a second

local BossWaitCamera = {}

local held = nil -- { Type, Fov, View, SubjectAt, From, Age, Back, RunnerAt }: what comes back, and where this move started

local function subjectPosition(camera)
	local subject = camera.CameraSubject
	local part = subject and (subject:IsA("Humanoid") and subject.RootPart or subject:IsA("BasePart") and subject)
	return part and part.Position or nil
end

-- Where the camera was before the wait, carried along with what it follows.
local function homeFrame(camera)
	local at = subjectPosition(camera)
	return at and held.SubjectAt and held.View + (at - held.SubjectAt) or held.View
end

-- Caught once at the wait's start: the runner may be replaced during the wait, and the view must not jump.
local function runnerPosition()
	local runner = RunnerVisual.LocalRunner()
	return runner and runner.PrimaryPart and runner.PrimaryPart.Position or nil
end

local function smooth(alpha)
	alpha = math.min(alpha, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function release(camera)
	camera.CFrame = homeFrame(camera)
	camera.CameraType = held.Type
	camera.FieldOfView = held.Fov
	held = nil
end

function BossWaitCamera.Held()
	return held ~= nil
end

local function screamView()
	local ends = ReplicatedStorage:GetAttribute("BossScreamEndsAt")
	return type(ends) == "number" and not UiMotion.Reduced() and ends > workspace:GetServerTimeNow() -- holds to the wheel's stop
end

function BossWaitCamera.Step(camera, dt)
	local inEvent = player:GetAttribute("BossEvent") == true
	if inEvent and (type(player:GetAttribute("BossWaitEndsAt")) == "number" or screamView()) then
		if not held then
			held = {
				Type = camera.CameraType,
				Fov = camera.FieldOfView,
				View = camera.CFrame,
				SubjectAt = subjectPosition(camera),
				From = camera.CFrame,
				Age = 0,
				RunnerAt = runnerPosition(),
			}
		elseif held.Back then -- a new wait during the return
			held.Back, held.From, held.Age, held.RunnerAt = nil, camera.CFrame, 0, runnerPosition()
		end
		held.Age += dt
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Cfg.WaitCameraFov
		local view = Cfg.WaitCameraCFrame(Arena.Center, held.RunnerAt)
		if UiMotion.Reduced() then
			camera.CFrame = view
		else
			local drifted = view * CFrame.new(math.sin(held.Age * DRIFT_RATE) * DRIFT_STUDS, 0, 0)
			camera.CFrame = held.From:Lerp(drifted, smooth(held.Age / PULL_SECONDS))
		end
	elseif held then
		if not inEvent or UiMotion.Reduced() then
			release(camera) -- leaving or the event's end: the teleport moves the view anyway
			return
		end
		if not held.Back then
			held.Back, held.From = 0, camera.CFrame
		end
		held.Back += dt
		if held.Back >= RETURN_SECONDS then
			release(camera)
		else
			camera.CFrame = held.From:Lerp(homeFrame(camera), smooth(held.Back / RETURN_SECONDS))
		end
	end
end

return BossWaitCamera
