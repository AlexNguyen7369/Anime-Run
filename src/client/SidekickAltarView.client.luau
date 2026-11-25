--!nonstrict
-- The Sidekick summon altar's display (design doc 4.36, docs/SIDEKICK_SPEC.md "Summon altar"): inside the altar's halo,
-- the current rotation's Mythic as its actual 3D model, cloned from the models the summon page uses, turning slowly and
-- swapped when the pool rotates. Below rebirth 2 it shows a locked look and a "Rebirth 2" label (proposed). Client
-- display only: reads the published rotation (Client/SidekickView), no remote. Reduced Motion: no turning.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SidekickConfig"))
local UiTheme = require(ReplicatedStorage.Shared:WaitForChild("UiTheme"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local MODEL_SIZE = 7 -- placeholder: studs, the model's largest extent; fits inside the halo (radius 5)
local TURN_SPEED = math.rad(30) -- placeholder: radians per second
local TURN_DISTANCE = 250 -- placeholder: studs; farther away the model holds still
local LOCKED_COLOR = Color3.fromRGB(24, 22, 30) -- placeholder: the locked silhouette
local LOCKED_TRANSPARENCY = 0.25 -- placeholder

local player = Players.LocalPlayer
local area = Workspace:WaitForChild("SpawnArea")
-- The hub streams out during a race and back in as new instances: look the spot up again whenever it is gone
local function findSpot()
	local altar = area:FindFirstChild("SidekickAltar")
	return altar and altar:FindFirstChild("ModelSpot", true)
end
local spot = findSpot()
while not spot do
	area.DescendantAdded:Wait() -- streaming may deliver the top tier late
	spot = findSpot()
end
local models = ReplicatedStorage:WaitForChild("SidekickModels")

local shown, shownKey, rel = nil, nil, CFrame.identity
local angle = 0

local label = Instance.new("BillboardGui")
label.Name = "SidekickAltarLock"
label.Size = UDim2.new(8, 40, 2, 12)
label.StudsOffsetWorldSpace = Vector3.new(0, -MODEL_SIZE / 2 - 1, 0)
label.MaxDistance = 120
label.LightInfluence = 0
label.Adornee = spot
label.Enabled = false
label.ResetOnSpawn = false -- this script runs once; a respawn must not drop the label
local text = Instance.new("TextLabel")
text.BackgroundTransparency = 1
text.Size = UDim2.fromScale(1, 1)
text.Font = UiTheme.Font
text.TextScaled = true
text.TextColor3 = Color3.new(1, 1, 1)
text.Text = string.format("Rebirth %d", Config.UnlockRebirth)
UiTheme.Stroke(text, 2)
text.Parent = label
label.Parent = player:WaitForChild("PlayerGui")

local function mythicId()
	for _, id in SidekickView.Rotation().Ids or {} do
		local row = Config.Get(id)
		if row and row.Rarity == "Mythic" then
			return id
		end
	end
	return nil
end

local function locked()
	return (player:GetAttribute("RebirthLevel") or 0) < Config.UnlockRebirth
end

local function refresh()
	local id = models:GetAttribute("Ready") == true and mythicId() or nil
	local isLocked = locked()
	if not spot.Parent then
		spot = findSpot() or spot
		label.Adornee = spot
	end
	-- streamed out: show nothing until the altar is back (a parentless attachment reads its offset as world)
	local key = spot.Parent and id and (id .. (isLocked and ":locked" or "")) or nil
	label.Enabled = isLocked
	if key == shownKey then
		return
	end
	if shown then
		shown:Destroy()
		shown = nil
	end
	shownKey = key
	local source = id and models:FindFirstChild(id)
	if not source then
		return
	end
	local model = source:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			if isLocked then
				d.Color = LOCKED_COLOR
				d.Material = Enum.Material.SmoothPlastic
				d.Transparency = math.max(d.Transparency, LOCKED_TRANSPARENCY)
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			end
		elseif
			d:IsA("Script")
			or d:IsA("LocalScript")
			or (isLocked and (d:IsA("SurfaceAppearance") or d:IsA("Decal")))
		then
			d:Destroy()
		end
	end
	local _, extents = model:GetBoundingBox()
	local biggest = math.max(extents.X, extents.Y, extents.Z)
	if biggest > 0 then
		model:ScaleTo(model:GetScale() * MODEL_SIZE / biggest)
	end
	-- Centre the model's box on the spot, its front toward the path; rel keeps that while it turns
	model:PivotTo(spot.WorldCFrame) -- the model's pivot front (-Z) meets the spot's, which faces the path
	local box = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (spot.WorldPosition - box.Position))
	rel = spot.WorldCFrame:ToObjectSpace(model:GetPivot())
	model.Name = "SidekickAltarModel"
	model.Parent = Workspace
	shown = model
end

ReplicatedStorage:GetAttributeChangedSignal("SidekickRotation"):Connect(refresh)
player:GetAttributeChangedSignal("RebirthLevel"):Connect(refresh)
models:GetAttributeChangedSignal("Ready"):Connect(refresh)
models.ChildAdded:Connect(refresh)
area.DescendantAdded:Connect(function(d)
	if d.Name == "ModelSpot" then
		refresh()
	end
end)
refresh()

RunService.RenderStepped:Connect(function(dt)
	if not shown or not spot.Parent or UiMotion.Reduced() then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.Focus.Position - spot.WorldPosition).Magnitude > TURN_DISTANCE then
		return
	end
	angle = (angle + dt * TURN_SPEED) % (2 * math.pi)
	shown:PivotTo(spot.WorldCFrame * CFrame.Angles(0, angle, 0) * rel)
end)
