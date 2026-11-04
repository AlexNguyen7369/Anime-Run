--!nonstrict
-- The Dojo's small touches (design doc 4.24 Dojos), client display only: a petal burst when an owned Dojo levels up, idle
-- training on the squad rigs near the camera, lanterns in the owner's WorkshopStat colour and the YOUR DOJO marker on
-- first join. The server's rig positions are never read back for gameplay. All numbers are proposed placeholders.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local Workshop = require(Shared:WaitForChild("Workshop"))
local WorkshopConfig = require(Shared:WaitForChild("WorkshopConfig"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local BURST_COUNT = 60
local BURST_DISTANCE = 150 -- studs from the camera
local BURST_FRONT = 22 -- studs in front of the plot centre, by the upgrade pad
local BURST_HEIGHT = 6

local TRAIN_DISTANCE = 80 -- studs from the camera
local TRAIN_SCAN = 0.5 -- seconds between looks for rigs in range
local TRAIN_RATE = 2.2 -- radians per second
local TRAIN_GUARD = math.rad(35) -- arms held forward
local TRAIN_JAB = math.rad(50) -- added at the top of a jab
local TRAIN_DIP = 0.08 -- studs at scale 1

local LANTERN_COLORS = {
	Money = Color3.fromRGB(255, 200, 60),
	Luck = Color3.fromRGB(70, 220, 110),
	Speed = Color3.fromRGB(70, 200, 255),
	Stamina = Color3.fromRGB(255, 80, 80),
}

local MARKER_HEIGHT = 40 -- world Y, above level 1's roof and the owner's sign
local MARKER_DISTANCE = 400
local MARKER_HIDE_WITHIN = 30

local player = Players.LocalPlayer

-- Level-up burst ------------------------------------------------------------------------------------------------------

local function burst(plot)
	local base = plot:FindFirstChild("Base")
	local camera = Workspace.CurrentCamera
	if not (base and camera) or UiMotion.Reduced() then
		return
	end
	local position = base.Position + base.CFrame.LookVector * BURST_FRONT + Vector3.new(0, BURST_HEIGHT, 0)
	if (position - camera.CFrame.Position).Magnitude > BURST_DISTANCE then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.Name = "DojoLevelUp"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position
	local petals = Instance.new("ParticleEmitter")
	petals.Texture = "rbxassetid://130260166899982"
	petals.Enabled = false
	petals.EmissionDirection = Enum.NormalId.Top
	petals.SpreadAngle = Vector2.new(55, 55)
	petals.Speed = NumberRange.new(14, 30)
	petals.Drag = 0.6
	petals.Acceleration = Vector3.new(0, -16, 0)
	petals.Lifetime = NumberRange.new(1.6, 2.8)
	petals.Size = NumberSequence.new(1.4, 0.8)
	petals.Rotation = NumberRange.new(-180, 180)
	petals.RotSpeed = NumberRange.new(-160, 160)
	petals.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	petals.LightInfluence = 0.4
	petals.Parent = anchor
	petals:Emit(BURST_COUNT)
	task.delay(3, function()
		anchor:Destroy()
	end)
end

-- Lanterns ------------------------------------------------------------------------------------------------------------

local function paintLanterns(plot)
	local mesh = plot:FindFirstChild("DojoMesh")
	local lamp = mesh and mesh:FindFirstChild("Glow_lamp")
	local owner = lamp and Players:GetPlayerByUserId(plot:GetAttribute("Owner") or 0)
	if owner then
		lamp.Color = LANTERN_COLORS[Workshop.CleanStat(owner:GetAttribute("WorkshopStat"))]
	end
end

local function paintAll()
	for _, plot in CollectionService:GetTagged(WorkshopConfig.TAG) do
		paintLanterns(plot)
	end
end

local function watchPlayer(who)
	who:GetAttributeChangedSignal("WorkshopStat"):Connect(paintAll)
	paintAll() -- the plot's Owner can reach this client before the Player does
end
Players.PlayerAdded:Connect(watchPlayer)

-- Plots ---------------------------------------------------------------------------------------------------------------

local function watchPlot(plot)
	-- An upgrade swaps the Workshop model while the Owner stays; a join or a release changes the Owner first, so a
	-- rebuilt Workshop only sets the baseline.
	local lastLevel = nil
	local function onWorkshop(workshop)
		local level = workshop:GetAttribute("Level") or 1
		if lastLevel and level > lastLevel then
			burst(plot)
		end
		lastLevel = level
	end
	plot.ChildAdded:Connect(function(child)
		if child.Name == "Workshop" then
			onWorkshop(child)
		end
	end)
	plot:GetAttributeChangedSignal("Owner"):Connect(function()
		lastLevel = nil
		paintLanterns(plot)
	end)
	plot.DescendantAdded:Connect(function(d)
		if d.Name == "Glow_lamp" then -- a tier swap, or the mesh streaming back in, brings a freshly coloured part
			paintLanterns(plot)
		end
	end)
	local current = plot:FindFirstChild("Workshop")
	if current then
		onWorkshop(current)
	end
	paintLanterns(plot)
end

CollectionService:GetInstanceAddedSignal(WorkshopConfig.TAG):Connect(watchPlot)
for _, plot in CollectionService:GetTagged(WorkshopConfig.TAG) do
	watchPlot(plot)
end
for _, who in Players:GetPlayers() do
	watchPlayer(who)
end

-- Squad training ------------------------------------------------------------------------------------------------------

-- RunnerVisual.Pose places limbs at unscaled PARTS offsets, so a ScaleTo'd rig would come apart under it. This reads the
-- rest frame and the scale off the rig itself, before the first write. Legs are never written: they stay planted.
local ARM_SIDE = { LeftArm = 1, RightArm = -1 }
local UPPER = { Torso = true, Head = true, Trim = true }
local HEAD_OFFSET = 0
for _, row in RunnerFactory.PARTS do
	if row[1] == "Head" then
		HEAD_OFFSET = row[3].Magnitude
	end
end

-- `phase` nil = back to the server's rest pose.
local function poseTraining(rig, state, phase)
	local wave = phase and math.sin(phase) or 0
	local upper = state.Root * CFrame.new(0, -TRAIN_DIP * state.Scale * math.abs(wave), 0)
	for _, row in RunnerFactory.PARTS do
		local name = row[1]
		local side = ARM_SIDE[name]
		if side or UPPER[name] then
			local part = rig:FindFirstChild(name)
			local offset = row[3] * state.Scale
			if part and side then
				local angle = phase and TRAIN_GUARD + TRAIN_JAB * math.max(0, wave * side) or 0
				local hinge = Vector3.new(0, row[2].Y / 2 * state.Scale, 0) -- the shoulder, top of the arm
				part.CFrame = upper * CFrame.new(offset + hinge) * CFrame.Angles(angle, 0, 0) * CFrame.new(-hinge)
			elseif part then
				part.CFrame = upper * CFrame.new(offset)
			end
		end
	end
end

local training = {} -- rig -> { Root, Scale, Offset }
local nextScan = 0

local function scanSquads(camera)
	local inRange = {}
	if not UiMotion.Reduced() then
		for _, plot in CollectionService:GetTagged(WorkshopConfig.TAG) do
			local workshop = plot:FindFirstChild("Workshop")
			for i = 1, workshop and 3 or 0 do
				local pedestal = workshop:FindFirstChild("ShowcasePedestal_" .. i)
				local rig = pedestal and pedestal:FindFirstChild("Runner")
				local torso = rig and rig:FindFirstChild("Torso")
				if
					torso
					and rig:FindFirstChild("Head")
					and (torso.Position - camera.CFrame.Position).Magnitude <= TRAIN_DISTANCE
				then
					inRange[rig] = i
				end
			end
		end
	end
	for rig, state in training do
		if not inRange[rig] then
			poseTraining(rig, state, nil)
			training[rig] = nil
		end
	end
	for rig, i in inRange do
		if not training[rig] then
			local torso, head = rig.Torso, rig.Head
			training[rig] = {
				Root = torso.CFrame,
				Scale = (head.Position - torso.Position).Magnitude / HEAD_OFFSET,
				Offset = i * 1.3, -- the three squad members never jab in step
			}
		end
	end
end

RunService.Heartbeat:Connect(function()
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	if camera and now >= nextScan then
		nextScan = now + TRAIN_SCAN
		scanSquads(camera)
	end
	for rig, state in training do
		poseTraining(rig, state, now * TRAIN_RATE + state.Offset)
	end
end)

-- YOUR DOJO marker ----------------------------------------------------------------------------------------------------

local function showMarker()
	local index = player:GetAttribute("Plot") or 0
	while index <= 0 do
		task.wait(0.25)
		index = player:GetAttribute("Plot") or 0
	end
	local base = Workspace:WaitForChild("Workshops"):WaitForChild("Plot_" .. index):WaitForChild("Base")
	local home = base.Position

	local anchor = Instance.new("Attachment")
	anchor.Name = "YourDojoMarker"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = Vector3.new(home.X, MARKER_HEIGHT, home.Z)

	local color = Color3.fromRGB(226, 84, 38)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(190, 62)
	gui.MaxDistance = MARKER_DISTANCE -- AlwaysOnTop stays off: these billboards do not draw with it
	gui.LightInfluence = 0
	gui.Parent = anchor

	local pill = Instance.new("Frame")
	pill.Size = UDim2.new(1, 0, 0, 44)
	pill.BackgroundColor3 = color
	pill.BorderSizePixel = 0
	pill.Parent = gui
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 12)
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.new(1, 1, 1)
	rim.Thickness = 3
	rim.Parent = pill

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -12, 1, -6)
	text.Position = UDim2.fromOffset(6, 3)
	text.BackgroundTransparency = 1
	text.Font = UiTheme.Font
	text.Text = "YOUR DOJO"
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	UiTheme.Stroke(text, 2)
	text.Parent = pill

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(1, 0, 0, 18)
	arrow.Position = UDim2.fromOffset(0, 44)
	arrow.BackgroundTransparency = 1
	arrow.Font = UiTheme.Font
	arrow.Text = "▼"
	arrow.TextColor3 = color
	arrow.TextScaled = true
	UiTheme.Stroke(arrow, 2)
	arrow.Parent = gui

	-- Gone for good on arrival or at the first run's start, which also covers hidden while racing.
	while player:GetAttribute("AutoRacing") ~= true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and ((root.Position - home) * Vector3.new(1, 0, 1)).Magnitude <= MARKER_HIDE_WITHIN then
			break
		end
		task.wait(0.25)
	end
	anchor:Destroy()
end

-- The server sets NeedsStarter only on a brand new save, and the pick clears it, so the first true marks a new player.
if player:GetAttribute("NeedsStarter") == true then
	task.spawn(showMarker)
else
	local waiting
	waiting = player:GetAttributeChangedSignal("NeedsStarter"):Connect(function()
		if player:GetAttribute("NeedsStarter") == true then
			waiting:Disconnect()
			showMarker()
		end
	end)
end
