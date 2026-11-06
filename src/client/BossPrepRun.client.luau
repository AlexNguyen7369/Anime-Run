--!nonstrict
-- The boss event's preparation run and spawn cutscene (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Preparation run and cutscene").
-- Display only, drawn from replicated attributes and BossEventStart: nothing here touches a run, damage or stamina. The first on
-- each team is that player's own held runner, posed through RunnerView's HeldPose; the others are local rigs with Sidekicks.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig"))
local Cfg = require(Shared:WaitForChild("BossEventConfig"))
local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
local Follow = require(Shared:WaitForChild("SidekickFollow"))
local PathDriver = require(Shared:WaitForChild("PathDriver"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

-- Placeholders.
local RUN_SPEED = 60 -- studs/s
local TEAM_GAP = 12 -- studs between runners in line
local JUMP_SECONDS = 0.4
local JUMP_HEIGHT = 6 -- studs
local MARK_UNTIL = 2.2 -- s after the spawn: the marks go and all but the first vanish
local MARK_RED = Color3.fromRGB(235, 20, 30)
local PUFFS, PUFFS_REDUCED = 7, 3
local PUFF_SECONDS = 0.7

local holder = Instance.new("Folder")
holder.Name = "BossPrepRun"
holder.Parent = workspace

local teams = {} -- player -> { Key, Rigs = { [slot] = rig }, Marks = { [slot] = gui }, Phase, Smoked }

local function heldCopy(who)
	for _, model in CollectionService:GetTagged(RunnerVisual.TAG) do
		if model:GetAttribute("Owner") == who.UserId then
			return model
		end
	end
	return nil
end

local function clearHeld(who)
	local copy = heldCopy(who)
	if copy and copy:GetAttribute("HeldPose") then
		copy:SetAttribute("HeldPose", nil)
		copy:SetAttribute("HeldPhase", nil)
		copy:SetAttribute("HeldAmount", nil)
	end
end

-- A rig for a place behind the first: a VisibleRunner, so it gets its Sidekick, with an Owner no real player has.
local function newRig(who, slot, id)
	local rig = RunnerFactory.build(id)
	rig.Name = "PrepRunner"
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	rig:SetAttribute("Owner", -(who.UserId * 10 + slot))
	rig:SetAttribute(
		"FollowerFixtureId",
		Follow.WornId(who:GetAttribute("SidekickGear"), who:GetAttribute("SidekickBag"), id)
	)
	rig.Parent = holder
	CollectionService:AddTag(rig, RunnerVisual.TAG)
	return rig
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

local function smoke(position)
	for i = 1, UiMotion.Reduced() and PUFFS_REDUCED or PUFFS do
		local puff = Instance.new("Part")
		puff.Shape = Enum.PartType.Ball
		puff.Material = Enum.Material.SmoothPlastic
		puff.Color = Color3.fromRGB(240, 240, 240)
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.CastShadow = false
		puff.Size = Vector3.one * 3
		puff.Position = position + Vector3.new(math.random(-3, 3), math.random(0, 4), math.random(-3, 3))
		puff.Parent = holder
		local info = TweenInfo.new(PUFF_SECONDS * (0.7 + i * 0.06), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(puff, info, {
			Size = Vector3.one * math.random(9, 13),
			Transparency = 1,
			Position = puff.Position + Vector3.new(0, 4, 0),
		}):Play()
		task.delay(info.Time, function()
			puff:Destroy()
		end)
	end
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
	gui.Parent = holder
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
	local center = Vector3.new(Arena.Center.X, position.Y, Arena.Center.Z)
	local facing = feet.Rotation:Lerp(CFrame.lookAt(position, center).Rotation, turned)
	local jump = UiMotion.Reduced() and 0 or JUMP_HEIGHT * math.sin(math.pi * turned)
	return CFrame.new(position + Vector3.new(0, RunnerFactory.HIP_HEIGHT + jump, 0)) * facing, k
end

local routes = {}
local function routeOf(lane)
	if not routes[lane] then
		local wps = Arena.LaneRoute(lane).WorldWaypoints
		local arc = PathDriver.Arc(wps)
		routes[lane] = { Wps = wps, Arc = arc, Length = arc[#arc] }
	end
	return routes[lane]
end

local function stepPlayer(who, since, dt)
	local lane, roster = who:GetAttribute("BossLane"), who:GetAttribute("BossTeam")
	local shows = who:GetAttribute("BossEvent") == true
		and type(lane) == "number"
		and type(roster) == "string"
		and roster ~= ""
		and since < Cfg.IntroSeconds
		and (since >= 0 or who:GetAttribute("BossPrepRun") == true)
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
			Smoked = false,
		}
		teams[who] = team
		for slot = 2, #team.Ids do
			if CharacterCatalog.Get(team.Ids[slot]) then
				team.Rigs[slot] = newRig(who, slot, team.Ids[slot])
			end
		end
	end
	local route = routeOf(lane)
	team.Phase = RunnerVisual.Advance(team.Phase, RUN_SPEED, dt)
	local amount = since < 0 and 1 or 0
	local lead = since < 0 and RUN_SPEED * since or 0 -- reaches the lane's start exactly at the spawn
	local vanish = since >= MARK_UNTIL
	local copy = heldCopy(who)
	if vanish and not team.Smoked then
		team.Smoked = true
		for slot, rig in team.Rigs do
			local torso = rig:FindFirstChild("Torso")
			if torso then
				smoke(torso.Position)
			end
			rig:Destroy()
			team.Rigs[slot] = nil
		end
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
		if since >= JUMP_SECONDS and not vanish then
			addMark(team, 1, copy)
		end
	end
	for slot, rig in team.Rigs do
		local root
		root, team.Hints[slot] = rootAt(route, lead - TEAM_GAP * (slot - 1), since, team.Hints[slot])
		RunnerVisual.Pose(rig, root, team.Phase, amount)
		if since >= JUMP_SECONDS then
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
