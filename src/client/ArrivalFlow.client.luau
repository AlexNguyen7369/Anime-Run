--!nonstrict
-- First join (design doc 4.24, WORLD_REDESIGN_SPEC section 7): camera reveal, the starter's in-world reveal, the petal
-- trail to the gate and the gate burst. Client display only. Every value is a proposed placeholder.
-- Local attribute ArrivalRevealDone opens Client/StarterPick; StarterPick sets StarterPicked to the id it got.
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local ArrivalState = require(script.Parent:WaitForChild("ArrivalState"))
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local PETAL = "rbxassetid://130260166899982"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GOLD = Color3.fromRGB(255, 205, 90)
local SPAWN = Vector3.new(0, 1, 0)
local GATE = Vector3.new(-84, 1, 78)
local TO_GATE = (GATE - SPAWN).Unit

local RENDER_BIND = "ArrivalReveal"
local REVEAL_SECONDS = 5
local REVEAL_CAP_SECONDS = 8 -- whatever else happens, the camera is back by then
local CUT_SECONDS = 1.5 -- Reduced Motion: one still shot of the plaza, then a cut
local FIGURE_SECONDS = 4
local FIGURE_MODEL_WAIT = 3
local FIGURE_SCALE = 1.5
local FIGURE_FROM_SPAWN = 7 -- towards the gate, so it does not stand inside the player
local FIGURE_SIDE = 7 -- off the camera line, so the player's own avatar does not hide it
local TRAIL_DISCS = 12
local TRAIL_ACTIVE_DISTANCE = 400 -- studs from the spawn: no pulsing while away
local GATE_BURST_DISTANCE = 40 -- studs: the burst is for crossing the gate, not AUTO RACE or a duel from elsewhere
local TRAIL_FROM = 10 -- studs from the spawn along the path
local TRAIL_Y = 0.22 -- above the floor top in SPAWN's height, over the path mesh
local TRAIL_DISC_SIZE = 6
local TRAIL_COLOR = Color3.fromRGB(255, 60, 150)

-- Round the far side of the plaza, out past the gate, back through the torii opening and down the path to the spawn.
local FINAL_POS = Vector3.new(8.8, 8.5, -8.2)
local FINAL_FOCUS = Vector3.new(-84, 15, 78)
local KEYS = {
	{ Pos = Vector3.new(-30, 75, -80), Focus = Vector3.new(0, 5, 0) },
	{ Pos = Vector3.new(-135, 55, 20), Focus = Vector3.new(-20, 5, 20) },
	{ Pos = Vector3.new(-140, 28, 130), Focus = Vector3.new(-84, 16, 78) },
	{ Pos = Vector3.new(-84, 14, 78), Focus = Vector3.new(0, 4, 0) },
	{ Pos = Vector3.new(-40, 14, 37), Focus = Vector3.new(0, 4, 0) },
	{ Pos = Vector3.new(10, 14, -4), Focus = Vector3.new(-20, 6, 18) },
	{ Pos = FINAL_POS, Focus = FINAL_FOCUS }, -- behind the player, looking at the gate: what they walk toward
}
local KEY_DISTANCE = { 0 } -- studs along the path, so the speed stays even across unequal gaps
for i = 2, #KEYS do
	KEY_DISTANCE[i] = KEY_DISTANCE[i - 1] + (KEYS[i].Pos - KEYS[i - 1].Pos).Magnitude
end

local SKIP_INPUTS = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.Gamepad1] = true,
}
local GAMEPAD_AXES = {
	[Enum.KeyCode.Thumbstick1] = true,
	[Enum.KeyCode.Thumbstick2] = true,
}

local player = Players.LocalPlayer

local function catmullRom(a, b, c, d, t)
	return 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t)
end

-- The camera at `alpha` (0 to 1) along KEYS.
local function sweepAt(alpha)
	local distance = alpha * KEY_DISTANCE[#KEYS]
	local i = 1
	while i < #KEYS - 1 and KEY_DISTANCE[i + 1] < distance do
		i += 1
	end
	local t = (distance - KEY_DISTANCE[i]) / (KEY_DISTANCE[i + 1] - KEY_DISTANCE[i])
	local function at(field)
		local before, after = KEYS[math.max(i - 1, 1)], KEYS[math.min(i + 2, #KEYS)]
		return catmullRom(before[field], KEYS[i][field], KEYS[i + 1][field], after[field], t)
	end
	return CFrame.lookAt(at("Pos"), at("Focus"))
end

local function skipButton(onSkip)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ArrivalReveal"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60 -- above the starter popup's level; the popup is not open yet
	local button = Instance.new("TextButton")
	button.Name = "Skip"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -16, 1, -76) -- above the bottom-right HUD button
	button.Size = UDim2.fromOffset(96, 44)
	button.BackgroundColor3 = Color3.new(0, 0, 0)
	button.BackgroundTransparency = 0.4
	button.Font = UiTheme.Font
	button.Text = "SKIP"
	button.TextColor3 = UiTheme.Palette.White
	button.TextSize = 22
	button.Parent = gui
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
	-- Hover and press: Ui/RacerMotion attaches 1.035 / 0.97 to every PlayerGui button (design doc 4.20).
	button.Activated:Connect(onSkip)
	gui.Parent = player:WaitForChild("PlayerGui")
	UiMotion.SlideIn(button, Vector2.new(0, 14)) -- position only: the HoverScale UIScale stays alone on the button
	return gui
end

-- Returns when the sweep ended, was skipped or failed. The camera is always back on Custom after this.
local function playReveal()
	local finished = false
	local connections = {}
	local gui = nil
	local function stop()
		finished = true
	end
	local ok, failure = pcall(function()
		gui = skipButton(stop)
		table.insert(
			connections,
			UserInputService.InputBegan:Connect(function(input)
				if SKIP_INPUTS[input.UserInputType] and not GAMEPAD_AXES[input.KeyCode] then
					stop()
				end
			end)
		)
		table.insert(connections, player.CharacterAdded:Connect(stop))
		table.insert(
			connections,
			player:GetAttributeChangedSignal("AutoRacing"):Connect(function()
				if player:GetAttribute("AutoRacing") == true then
					stop()
				end
			end)
		)

		local reduced = UiMotion.Reduced()
		local seconds = reduced and CUT_SECONDS or REVEAL_SECONDS
		local started = os.clock()
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep(RENDER_BIND, Enum.RenderPriority.Camera.Value + 1, function()
			local elapsed = os.clock() - started
			local eased =
				TweenService:GetValue(math.min(elapsed / seconds, 1), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			Workspace.CurrentCamera.CFrame = sweepAt(reduced and 0 or eased)
			if elapsed >= seconds then
				stop()
			end
		end)
		repeat
			task.wait(0.05)
		until finished or os.clock() - started >= REVEAL_CAP_SECONDS
	end)
	RunService:UnbindFromRenderStep(RENDER_BIND)
	for _, connection in connections do
		connection:Disconnect()
	end
	if gui then
		gui:Destroy()
	end
	-- Skipped or not, the player ends up behind their character, looking at the gate
	Workspace.CurrentCamera.CFrame = CFrame.lookAt(FINAL_POS, FINAL_FOCUS)
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	if not ok then
		warn("[ArrivalFlow] reveal failed: " .. tostring(failure))
	end
end

-- One shot of particles at a world position (attachment in Terrain, so streaming cannot hide it). None while reduced.
local function burst(position, texture, count, color)
	if UiMotion.Reduced() then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.Name = "ArrivalBurst"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(color or Color3.new(1, 1, 1))
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(8, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -6, 0)
	emitter.Drag = 1
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Size = NumberSequence.new(1, 0.5)
	emitter.LightInfluence = 0
	emitter.Parent = anchor
	task.delay(0.03, emitter.Emit, emitter, count) -- a just-parented emitter can drop an Emit from the same frame
	Debris:AddItem(anchor, 3)
end

-- The chosen character's hero pose at the spawn, in a petal burst; gone after a few seconds.
local function pickReveal(id)
	local at = SPAWN + TO_GATE * FIGURE_FROM_SPAWN + TO_GATE:Cross(Vector3.yAxis) * FIGURE_SIDE
	burst(at + Vector3.new(0, 3, 0), PETAL, 70)
	local waited = os.clock()
	local models = ReplicatedStorage:FindFirstChild("CharacterModels")
	while not (models and models:GetAttribute("Ready") == true) and os.clock() - waited < FIGURE_MODEL_WAIT do
		task.wait(0.1) -- past this the placeholder rig stands in
		models = ReplicatedStorage:FindFirstChild("CharacterModels")
	end
	local rig = RunnerFactory.build(id)
	rig.Name = "ArrivalFigure"
	RunnerVisual.Hero(rig, CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0))
	rig:ScaleTo(FIGURE_SCALE)
	rig:PivotTo(CFrame.lookAt(at, at - TO_GATE) * CFrame.new(0, RunnerFactory.HIP_HEIGHT * FIGURE_SCALE, 0))
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	rig.Parent = Workspace
	task.delay(FIGURE_SECONDS, function()
		burst(at + Vector3.new(0, 3, 0), PETAL, 30)
		rig:Destroy()
	end)
end

local trail = nil

local function applyTrailMotion()
	if trail then
		for _, emitter in trail.Emitters do
			emitter.Enabled = not UiMotion.Reduced()
		end
	end
end

-- Glowing discs on the path, pulsing in a wave toward the gate, with petals drifting the same way. Flat parts, not a Beam:
-- from the spawn the camera looks along the path, where a ribbon collapses to a line.
local function showTrail()
	local folder = Instance.new("Folder")
	folder.Name = "ArrivalTrail"
	local start = SPAWN + TO_GATE * TRAIL_FROM
	local length = (GATE - SPAWN).Magnitude - TRAIL_FROM - 6
	local discs, emitters = {}, {}
	for i = 1, TRAIL_DISCS do
		local position = start + TO_GATE * (length * (i - 1) / (TRAIL_DISCS - 1)) + Vector3.new(0, TRAIL_Y, 0)
		local disc = Instance.new("Part")
		disc.Name = "Disc"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.08, TRAIL_DISC_SIZE, TRAIL_DISC_SIZE)
		disc.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		disc.Anchored = true
		disc.CanCollide = false
		disc.CanTouch = false
		disc.CanQuery = false
		disc.CastShadow = false
		disc.Material = Enum.Material.Neon
		disc.Color = TRAIL_COLOR
		disc.Parent = folder
		table.insert(discs, disc)
		if i % 2 == 0 then
			local spot = Instance.new("Attachment")
			spot.CFrame = CFrame.Angles(0, 0, math.rad(-90))
				* CFrame.lookAt(Vector3.new(0, 0.5, 0), Vector3.new(0, 0.5, 0) + TO_GATE)
			spot.Parent = disc
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = PETAL
			emitter.Rate = 8
			emitter.Lifetime = NumberRange.new(1.6, 2.4)
			emitter.Speed = NumberRange.new(8, 12)
			emitter.EmissionDirection = Enum.NormalId.Front
			emitter.SpreadAngle = Vector2.new(18, 18)
			emitter.Size = NumberSequence.new(0.9)
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.RotSpeed = NumberRange.new(-120, 120)
			emitter.Transparency = NumberSequence.new(0.1, 1)
			emitter.LightInfluence = 0
			emitter.Parent = spot
			table.insert(emitters, emitter)
		end
	end
	folder.Parent = Workspace
	local pulse = RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera and camera.CFrame.Position.Magnitude > TRAIL_ACTIVE_DISTANCE then
			return
		end
		local reduced = UiMotion.Reduced()
		for i, disc in discs do
			-- A wave running toward the gate; steady under Reduced Motion
			local wave = reduced and 1 or (math.sin(os.clock() * 4 - i * 0.7) + 1) / 2
			disc.Transparency = 0.35 - 0.35 * wave
		end
	end)
	trail = { Folder = folder, Pulse = pulse, Emitters = emitters }
	applyTrailMotion()
end

local wasNew = false -- sticky: MoneyEarned can rise during the first run
local startedRun = false

local function refreshTrail()
	wasNew = wasNew or ArrivalState.IsNew(player)
	if wasNew and not startedRun and not trail and player:GetAttribute("NeedsStarter") ~= true then
		showTrail()
	end
end

local revealing = false

local function onNeedsStarter()
	if player:GetAttribute("NeedsStarter") ~= true then
		player:SetAttribute("ArrivalRevealDone", nil)
	elseif not revealing then
		revealing = true
		task.spawn(function()
			ArrivalState.WaitForLoading()
			playReveal()
			revealing = false
			player:SetAttribute("ArrivalRevealDone", true)
		end)
	end
	refreshTrail()
end

local function onAutoRacing()
	if player:GetAttribute("AutoRacing") ~= true or startedRun then
		return
	end
	startedRun = true
	if trail then
		trail.Pulse:Disconnect()
		trail.Folder:Destroy()
		trail = nil
	end
	local character = player.Character
	local near = character and (character:GetPivot().Position - GATE).Magnitude <= GATE_BURST_DISTANCE
	if wasNew and near then
		burst(GATE + Vector3.new(0, 2, 0), PETAL, 45)
		burst(GATE + Vector3.new(0, 2, 0), SPARKLE, 30, GOLD)
	end
end

player:GetAttributeChangedSignal("NeedsStarter"):Connect(onNeedsStarter)
player:GetAttributeChangedSignal("DataLoaded"):Connect(refreshTrail)
player:GetAttributeChangedSignal("AutoRacing"):Connect(onAutoRacing)
player:GetAttributeChangedSignal("ReduceEffects"):Connect(applyTrailMotion)
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(applyTrailMotion)
player:GetAttributeChangedSignal("StarterPicked"):Connect(function()
	pickReveal(player:GetAttribute("StarterPicked"))
end)
onNeedsStarter()
onAutoRacing()
