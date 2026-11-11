--!nonstrict
-- The enclosed cyber dojo on the client (design doc 4.24 "Enclosed cyber dojo", owner 2026-11-10; Client/CyberPlaza,
-- Client/DojoExtras, Client/ArrivalFlow). Owned by ui-test-writer. Server-side wall, tiers and Zone 0: CarTest
-- CyberPlazaTests.
--   ui_cyber_door: the blast door opens when this player starts racing, by walking onto the StartPad on foot and by
--     Remotes.SetAutoRace(true), and shuts about 1 s after they are back on foot. It stops and starts real runs and puts
--     AutoRacing back as it was.
--   ui_cyber_dojo_glow: every Glow_lamp of this player's Dojo takes one colour per WorkshopStat, a different one for
--     each stat (Remotes.SetWorkshopStat), never the server's unpainted cyan. Puts the stat back.
--   ui_cyber_reveal (manual: needs a fresh save, TestSaveKey): every camera frame of the first-join reveal is inside
--     the wall's inner face and below its top, so no track shows. The frames are recorded from the moment this module
--     loads; run it with UiTestScenario after such a join.
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   Two leaf Models tagged CyberDoorLeaf (LeafL, LeafR), each with a part "Leaf" and a Vector3 attribute Slide (world
--   studs): shut = the server's pose, open = shut + Slide. Client/CyberPlaza: OPEN_TIME 1.2 s, CLOSE_DELAY 1 s.
--   While the reveal plays, PlayerGui holds the ScreenGui ArrivalReveal and the camera is Scriptable.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CyberPlaza = require(Shared:WaitForChild("CyberPlaza"))
local WorkshopConfig = require(Shared:WaitForChild("WorkshopConfig"))
local Spec = require(script.Parent.UiSpec)

local OPEN_TIME = 1.2 -- s: Client/CyberPlaza's tween
local CLOSE_DELAY = 1 -- s: back on foot before the door shuts (design doc 4.24 rule as built: "closes 1 s after")
local SLACK = 1 -- s on top of a tween before a pose is judged
local STILL_OPEN_AT = 0.5 -- s after AutoRacing turns false: the door has not started to shut
local STATE_WAIT = 10 -- s for AutoRacing to replicate
local PAD_COOLDOWN = 2.2 -- s: SpawnArea.START_COOLDOWN (2) after a stop before the pad starts a run again
local TOGGLE_COOLDOWN = 0.8 -- s: CarService.TOGGLE_COOLDOWN (0.75) between SetAutoRace requests
local STAT_COOLDOWN = 0.6 -- s: WorkshopConfig.REMOTE_COOLDOWN (0.5)
local POSE_TOL = 0.05 -- studs
local LAMP_WAIT = 10 -- s for the Dojo look to stream in and be painted
local UNPAINTED = CyberPlaza.Colors.Cyan

local Module = {}

-- First-join reveal frames, recorded from load (one table, so a late scenario reads what an early frame saw)
local reveal = { frames = 0, worstDistance = -math.huge, worstHeight = -math.huge, firstBad = nil }

local function startRevealWatch(playerGui)
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if
			not (
				camera
				and camera.CameraType == Enum.CameraType.Scriptable
				and playerGui:FindFirstChild("ArrivalReveal")
			)
		then
			return
		end
		local p = camera.CFrame.Position
		local d = CyberPlaza.Distance(p.X, p.Z)
		reveal.frames += 1
		reveal.worstDistance = math.max(reveal.worstDistance, d)
		reveal.worstHeight = math.max(reveal.worstHeight, p.Y)
		local inside = d < -CyberPlaza.WALL_THICKNESS / 2
		local below = p.Y < CyberPlaza.TOP + CyberPlaza.WALL_HEIGHT
		if not (inside and below) and not reveal.firstBad then
			reveal.firstBad = ("%.1f, %.1f, %.1f"):format(p.X, p.Y, p.Z)
		end
	end)
end

table.insert(Spec.ManualScenarios, {
	Name = "ui_cyber_reveal",
	Manual = "needs a first join on a fresh save (ReplicatedStorage attribute TestSaveKey set in Edit) so the reveal plays; "
		.. "then UiTestScenario = ui_cyber_reveal",
})

function Module.Build(h)
	local scenarios = {}
	local player = h.player
	startRevealWatch(h.playerGui)

	local function check(res, name, got, want, ok)
		h.check(res, name, got, want, ok)
	end
	local function waitUntil(seconds, fn)
		local deadline = os.clock() + seconds
		local value = fn()
		while not value and os.clock() < deadline do
			task.wait(0.05)
			value = fn()
		end
		return value and true or false
	end
	local function racing()
		return player:GetAttribute("AutoRacing") == true
	end
	local lastToggle = -math.huge
	-- Remotes.SetAutoRace(on), past the server's cooldown; true once AutoRacing shows it
	local function setRacing(on)
		local remote = ReplicatedStorage:FindFirstChild("Remotes")
			and ReplicatedStorage.Remotes:FindFirstChild("SetAutoRace")
		if not remote then
			return false
		end
		task.wait(math.max(0, lastToggle + TOGGLE_COOLDOWN - os.clock()))
		lastToggle = os.clock()
		remote:FireServer(on)
		return waitUntil(STATE_WAIT, function()
			return racing() == on
		end)
	end

	local function leaves()
		local list = {}
		for _, m in CollectionService:GetTagged(CyberPlaza.TAG) do
			if m:IsA("Model") and typeof(m:GetAttribute("Slide")) == "Vector3" then
				table.insert(list, m)
			end
		end
		return list
	end
	-- Largest distance of a leaf from shut + Slide x amount (0 shut, 1 open)
	local function poseError(list, shut, amount)
		local worst = 0
		for _, m in list do
			local want = shut[m].Position + m:GetAttribute("Slide") * amount
			worst = math.max(worst, (m:GetPivot().Position - want).Magnitude)
		end
		return worst
	end
	local function waitPose(list, shut, amount, seconds)
		waitUntil(seconds, function()
			return poseError(list, shut, amount) <= POSE_TOL
		end)
		return poseError(list, shut, amount)
	end
	-- The two Leaf parts' centres apart: W / 2 shut (they meet in the middle), W / 2 + W open
	local function leafGap(list)
		local a = list[1] and list[1]:FindFirstChild("Leaf")
		local b = list[2] and list[2]:FindFirstChild("Leaf")
		return a and b and (a.Position - b.Position).Magnitude or -1
	end

	function scenarios.ui_cyber_door(res)
		local wasRacing = racing()
		local ok, err = xpcall(function()
			local list = leaves()
			check(res, "door_two_leaves", #list, 2, #list == 2)
			if #list ~= 2 then
				return
			end
			local w = CyberPlaza.DOOR_WIDTH
			for _, m in list do
				local slide = m:GetAttribute("Slide")
				check(
					res,
					"door_slide_" .. m.Name,
					slide.Magnitude,
					w / 2,
					math.abs(slide.Magnitude - w / 2) <= POSE_TOL
				)
				check(res, "door_slide_flat_" .. m.Name, slide.Y, 0, math.abs(slide.Y) <= POSE_TOL)
			end
			local slides = list[1]:GetAttribute("Slide"):Dot(list[2]:GetAttribute("Slide"))
			check(res, "door_leaves_part", slides, "< 0", slides < 0)

			-- On foot, door shut
			check(res, "door_on_foot", not racing() or setRacing(false), true, not racing())
			task.wait(CLOSE_DELAY + OPEN_TIME + SLACK)
			local shut = {}
			for _, m in list do
				shut[m] = m:GetPivot()
			end
			local gap = leafGap(list)
			check(res, "door_shut_on_foot", gap, w / 2, math.abs(gap - w / 2) <= POSE_TOL)

			-- Walk onto the StartPad: the server starts the run, the door opens by Slide
			task.wait(PAD_COOLDOWN)
			local pad = CollectionService:GetTagged("StartPad")[1]
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			check(res, "door_pad_and_avatar", pad ~= nil and root ~= nil, true, pad ~= nil and root ~= nil)
			if not (pad and root) then
				return
			end
			character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, pad.Size.Y / 2 + 3.5, 0)))
			local started = waitUntil(STATE_WAIT, racing)
			check(res, "door_pad_starts_race", started, true, started)
			if started then
				local e = waitPose(list, shut, 1, OPEN_TIME + SLACK)
				check(res, "door_opens_on_pad", e, POSE_TOL, e <= POSE_TOL)
				gap = leafGap(list)
				check(res, "door_open_gap_pad", gap, w / 2 + w, math.abs(gap - (w / 2 + w)) <= POSE_TOL)
			end

			-- Back on foot: still open just after, shut after CLOSE_DELAY plus the tween
			local stopped = setRacing(false)
			check(res, "door_stop_race", stopped, true, stopped)
			if stopped then
				task.wait(STILL_OPEN_AT)
				local e = poseError(list, shut, 1)
				check(res, "door_still_open_after_stop", e, POSE_TOL, e <= POSE_TOL)
				e = waitPose(list, shut, 0, CLOSE_DELAY - STILL_OPEN_AT + OPEN_TIME + SLACK)
				check(res, "door_shuts_after_stop", e, POSE_TOL, e <= POSE_TOL)
			end

			-- Auto race on (Remotes.SetAutoRace): the door opens
			local auto = setRacing(true)
			check(res, "door_auto_race_on", auto, true, auto)
			if auto then
				local e = waitPose(list, shut, 1, OPEN_TIME + SLACK)
				check(res, "door_opens_on_auto_race", e, POSE_TOL, e <= POSE_TOL)
			end
		end, debug.traceback)
		check(res, "door_completed", ok and true or tostring(err), true, ok)
		if racing() ~= wasRacing then
			setRacing(wasRacing)
		end
	end

	function scenarios.ui_cyber_dojo_glow(res)
		local wasRacing = racing()
		local wasStat = player:GetAttribute("WorkshopStat")
		local remote = ReplicatedStorage:FindFirstChild("Remotes")
			and ReplicatedStorage.Remotes:FindFirstChild("SetWorkshopStat")
		local ok, err = xpcall(function()
			check(res, "glow_remote", remote ~= nil, true, remote ~= nil)
			if not remote then
				return
			end
			-- On foot at the plaza, so the Dojo streams in
			check(res, "glow_on_foot", not racing() or setRacing(false), true, not racing())
			local index = player:GetAttribute("Plot")
			local plot = Workspace:FindFirstChild("Workshops")
				and type(index) == "number"
				and Workspace.Workshops:FindFirstChild("Plot_" .. index)
			check(res, "glow_own_plot", plot ~= nil, true, plot ~= nil)
			if not plot then
				return
			end
			local function lamps()
				local mesh = plot:FindFirstChild("DojoMesh")
				local list = {}
				for _, d in mesh and mesh:GetChildren() or {} do
					if d.Name == "Glow_lamp" and d:IsA("BasePart") then
						table.insert(list, d)
					end
				end
				return list
			end
			-- One colour on every lamp, or nil
			local function uniform()
				local list = lamps()
				local colour = list[1] and list[1].Color
				for _, lamp in list do
					if lamp.Color ~= colour then
						return nil
					end
				end
				return colour
			end
			local found = waitUntil(LAMP_WAIT, function()
				return #lamps() >= 5
			end)
			check(res, "glow_lamps_present", #lamps(), ">= 5", found)
			if not found then
				return
			end
			local seen = {}
			for _, stat in WorkshopConfig.STATS do
				task.wait(STAT_COOLDOWN)
				local okCall, accepted = pcall(remote.InvokeServer, remote, stat)
				local set = okCall
					and accepted == true
					and waitUntil(STATE_WAIT, function()
						return player:GetAttribute("WorkshopStat") == stat
					end)
				check(res, "glow_stat_set_" .. stat, set, true, set)
				local colour
				local painted = waitUntil(2, function()
					colour = uniform()
					return colour ~= nil and colour ~= UNPAINTED
				end)
				check(
					res,
					"glow_one_colour_" .. stat,
					colour and colour:ToHex() or "mixed",
					"one colour, not cyan",
					painted
				)
				for other, c in seen do
					check(res, ("glow_%s_differs_from_%s"):format(stat, other), colour ~= c, true, colour ~= c)
				end
				seen[stat] = colour
			end
		end, debug.traceback)
		check(res, "glow_completed", ok and true or tostring(err), true, ok)
		if remote and type(wasStat) == "string" and player:GetAttribute("WorkshopStat") ~= wasStat then
			task.wait(STAT_COOLDOWN)
			pcall(remote.InvokeServer, remote, wasStat)
		end
		if racing() ~= wasRacing then
			setRacing(wasRacing)
		end
	end

	function scenarios.ui_cyber_reveal(res)
		check(res, "reveal_frames_seen", reveal.frames, "> 0", reveal.frames > 0)
		local inner = -CyberPlaza.WALL_THICKNESS / 2
		check(
			res,
			"reveal_inside_wall",
			reveal.worstDistance,
			inner,
			reveal.frames > 0 and reveal.worstDistance < inner
		)
		local wallTop = CyberPlaza.TOP + CyberPlaza.WALL_HEIGHT
		check(
			res,
			"reveal_below_wall_top",
			reveal.worstHeight,
			wallTop,
			reveal.frames > 0 and reveal.worstHeight < wallTop
		)
		check(res, "reveal_first_bad_frame", reveal.firstBad or "none", "none", reveal.firstBad == nil)
	end

	return { Scenarios = scenarios }
end

return Module
