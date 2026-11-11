--!nonstrict
-- The boss event's preparation run and spawn cutscene (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Preparation run and cutscene").
-- Display only, drawn from replicated attributes and BossEventStart: nothing here touches a run, damage or stamina. The first on
-- each team is that player's own held runner, posed through RunnerView's HeldPose; the others are local rigs with Sidekicks, until
-- that player's line run has reached this client and Client/BossLineRun takes over in the same frame.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig"))
local BossCatalog = require(Shared:WaitForChild("BossCatalog"))
local Cfg = require(Shared:WaitForChild("BossEventConfig"))
local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
local PathDriver = require(Shared:WaitForChild("PathDriver"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))
local BossTeamRig = require(script.Parent:WaitForChild("BossTeamRig"))
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

-- Placeholders.
local RUN_SPEED = 60 -- studs/s
local JUMP_SECONDS = 0.4
local JUMP_HEIGHT = 6 -- studs
local MARK_UNTIL = 2.2 -- s after the spawn: the marks go
local HANDOVER_SECONDS = 2 -- past the intro: how long the line stands waiting for its run to replicate
local MARK_RED = Color3.fromRGB(235, 20, 30)

local teams = {} -- player -> { Key, Rigs = { [slot] = rig }, Marks = { [slot] = gui }, Phase }

local function clearHeld(who)
	local copy = BossTeamRig.HeldCopy(who)
	if copy and copy:GetAttribute("HeldPose") then
		copy:SetAttribute("HeldPose", nil)
		copy:SetAttribute("HeldPhase", nil)
		copy:SetAttribute("HeldAmount", nil)
	end
end

local function dropTeam(who)
	local team = teams[who]
	if not team then
		return
	end
	teams[who] = nil
	for _, rig in team.Rigs do
		rig:Destroy()
	end
	for _, mark in team.Marks do
		mark:Destroy()
	end
	clearHeld(who)
end

local function addMark(team, slot, model)
	local head = model:FindFirstChild("Head")
	if team.Marks[slot] or not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AlertMark"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(14, 28)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.Text = "!"
	text.TextColor3 = MARK_RED
	text.TextScaled = true
	text.TextStrokeTransparency = 0
	text.Parent = gui
	gui.Parent = BossTeamRig.Holder
	TweenService:Create(gui, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(40, 80) }):Play()
	team.Marks[slot] = gui
end

-- The body's pose at distance `dist` on the lane, `since` seconds after the spawn (negative: still running).
local function rootAt(route, dist, since, hint)
	local feet, k = PathDriver.PoseAt(route.Wps, route.Arc, dist % route.Length, hint, true)
	if since < 0 then
		return feet * CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0), k
	end
	local turned = math.clamp(since / JUMP_SECONDS, 0, 1)
	local position = feet.Position
	local arenaCenter = Arena.For(BossCatalog.Current().Id).Center
	local center = Vector3.new(arenaCenter.X, position.Y, arenaCenter.Z)
	local facing = feet.Rotation:Lerp(CFrame.lookAt(position, center).Rotation, turned)
	local jump = UiMotion.Reduced() and 0 or JUMP_HEIGHT * math.sin(math.pi * turned)
	return CFrame.new(position + Vector3.new(0, RunnerFactory.HIP_HEIGHT + jump, 0)) * facing, k
end

local routes = {} -- boss id -> lane -> route
local function routeOf(lane)
	local boss = BossCatalog.Current().Id
	routes[boss] = routes[boss] or {}
	local byLane = routes[boss]
	if not byLane[lane] then
		local wps = Arena.For(boss).LaneRoute(lane).WorldWaypoints
		local arc = PathDriver.Arc(wps)
		byLane[lane] = { Wps = wps, Arc = arc, Length = arc[#arc] }
	end
	return byLane[lane]
end

local function stepPlayer(who, since, dt)
	local lane, roster = who:GetAttribute("BossLane"), who:GetAttribute("BossTeam")
	local shows = who:GetAttribute("BossEvent") == true
		and type(lane) == "number"
		and type(roster) == "string"
		and roster ~= ""
		and since < Cfg.IntroSeconds + HANDOVER_SECONDS
		and (since >= 0 or who:GetAttribute("BossPrepRun") == true)
		and not BossTeamRig.RunOf(who)
	if not shows then
		dropTeam(who)
		return
	end
	local team = teams[who]
	if team and team.Key ~= roster then
		dropTeam(who)
		team = nil
	end
	if not team then
		team = {
			Key = roster,
			Ids = string.split(roster, ","),
			Rigs = {},
			Marks = {},
			Hints = {},
			Phase = 0,
		}
		teams[who] = team
		for slot = 2, #team.Ids do
			if CharacterCatalog.Get(team.Ids[slot]) then
				team.Rigs[slot] = BossTeamRig.New(who, slot, team.Ids[slot])
			end
		end
	end
	local route = routeOf(lane)
	team.Phase = RunnerVisual.Advance(team.Phase, RUN_SPEED, dt)
	local amount = since < 0 and 1 or 0
	local lead = since < 0 and RUN_SPEED * since or 0 -- reaches the lane's start exactly at the spawn
	local marked = since >= JUMP_SECONDS and since < MARK_UNTIL
	local copy = BossTeamRig.HeldCopy(who)
	if since >= MARK_UNTIL then
		for slot, mark in team.Marks do
			mark:Destroy()
			team.Marks[slot] = nil
		end
	end
	if copy then
		local root
		root, team.Hints[1] = rootAt(route, lead, since, team.Hints[1])
		copy:SetAttribute("HeldPose", root)
		copy:SetAttribute("HeldPhase", team.Phase)
		copy:SetAttribute("HeldAmount", amount)
		if marked then
			addMark(team, 1, copy)
		end
	end
	for slot, rig in team.Rigs do
		local root
		root, team.Hints[slot] = rootAt(route, lead - BossTeamRig.TEAM_GAP * (slot - 1), since, team.Hints[slot])
		RunnerVisual.Pose(rig, root, team.Phase, amount)
		if marked then
			addMark(team, slot, rig)
		end
	end
end

-- Before RunnerView's step (Camera - 1), so its held branch reads this frame's pose.
RunService:BindToRenderStep("BossPrepRun", Enum.RenderPriority.Camera.Value - 2, function(dt)
	local start = ReplicatedStorage:GetAttribute("BossEventStart")
	if not (start and player:GetAttribute("BossEvent") == true) then
		for who in teams do
			dropTeam(who)
		end
		return
	end
	local since = workspace:GetServerTimeNow() - start - Cfg.PrepSeconds
	for _, who in Players:GetPlayers() do
		stepPlayer(who, since, dt)
	end
end)
Players.PlayerRemoving:Connect(dropTeam)
