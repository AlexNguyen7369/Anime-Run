--!nonstrict
-- The plaza's Legends and the runners lapping its sky loop (design doc 4.24): client display only, not players or NPC
-- rivals. The Legends stand on their pedestals; the runners are
-- removed while the camera is away from the plaza, so a race pays nothing for them. Numbers are placeholders.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("PlazaAssets"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local LEGEND_SCALE = 1.9 -- placeholder: about 9 studs tall (WORLD_REDESIGN_SPEC 7)
local LEGEND_LABEL_DISTANCE = 30
local SPEED = 70 -- studs/s; a lap takes about 5.6 s
local ACTIVE_DISTANCE = 450 -- studs from the plaza centre
local RUNNERS = {
	{ Id = "leaf_hero", Angle = 205, Color = Color3.fromRGB(57, 200, 255) },
	{ Id = "sea_captain", Angle = 20, Color = Color3.fromRGB(255, 138, 30) },
	{ Id = "db_hero", Angle = 95, Color = Color3.fromRGB(57, 200, 255) },
}

local radius, height = Layout.LoopRadius, Layout.LoopHeight + RunnerFactory.HIP_HEIGHT

local models = ReplicatedStorage:WaitForChild("CharacterModels")
if models:GetAttribute("Ready") ~= true then
	models:GetAttributeChangedSignal("Ready"):Wait()
end

local legends = Instance.new("Folder")
legends.Name = "PlazaLegends"
for _, row in Layout.Legends do
	local rig = RunnerFactory.build(row.Id)
	rig.Name = "Legend_" .. row.Id
	rig:ScaleTo(LEGEND_SCALE)
	rig:PivotTo(CFrame.lookAt(row.Pos, row.Pos + row.Face) * CFrame.new(0, RunnerFactory.HIP_HEIGHT * LEGEND_SCALE, 0))
	local label = rig:FindFirstChild("NameLabel")
	if label then
		label.MaxDistance = LEGEND_LABEL_DISTANCE
		label.Size = UDim2.fromOffset(120, 24)
	end
	rig.Parent = legends
end
legends.Parent = Workspace

local folder = Instance.new("Folder")
folder.Name = "PlazaRunners"

local active = {}
for _, spec in RUNNERS do
	local rig = RunnerFactory.build(spec.Id)
	local label = rig:FindFirstChild("NameLabel")
	if label then
		label:Destroy()
	end
	local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
	top.Position, bottom.Position = Vector3.new(0, 0.3, 0), Vector3.new(0, -0.3, 0)
	top.Parent, bottom.Parent = rig.Torso, rig.Torso
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = top, bottom
	trail.Color = ColorSequence.new(spec.Color)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Lifetime = 0.5
	trail.LightEmission = 0.4
	trail.FaceCamera = true
	trail.Parent = rig.Torso
	rig.Parent = folder
	table.insert(active, { Rig = rig, Trail = trail, Angle = math.rad(spec.Angle), Phase = 0 })
end

local lastReduced = nil
RunService.Heartbeat:Connect(function(dt)
	local camera = Workspace.CurrentCamera
	local near = camera ~= nil and camera.CFrame.Position.Magnitude <= ACTIVE_DISTANCE
	folder.Parent = near and Workspace or nil
	if not near then
		return
	end
	local reduced = UiMotion.Reduced()
	if reduced ~= lastReduced then
		lastReduced = reduced
		for _, r in active do
			r.Trail.Enabled = not reduced
		end
	end
	for _, r in active do
		r.Angle -= SPEED / radius * dt
		r.Phase = RunnerVisual.Advance(r.Phase, SPEED, dt)
		local position = Vector3.new(radius * math.cos(r.Angle), height, radius * math.sin(r.Angle))
		local tangent = Vector3.new(math.sin(r.Angle), 0, -math.cos(r.Angle))
		RunnerVisual.Pose(r.Rig, CFrame.lookAt(position, position + tangent), r.Phase, 1)
	end
end)
