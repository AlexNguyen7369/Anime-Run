--!nonstrict
-- Track power-ups (design doc 4.44, docs/POWERUP_SPEC.md "Client"): draws the owner's own set as run-through rings
-- across the player's lane. The server rolls and applies every pickup (RunEvent "PowerUps" / "PowerUpTaken" go to the
-- owner only), so nobody else sees these rings. Display only.
-- Idle (owner 2026-11-11): the dashed rim turns and the glow breathes; REDUCED EFFECTS keeps only the turn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PathDriver = require(Shared.PathDriver)
local PowerUpConfig = require(Shared.PowerUpConfig)
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))

local RADIUS = 6 -- studs, proposed (ring about 12 across)
local HEIGHT = 6 -- studs of the ring centre over the rail, proposed
local BITS = 16 -- rim pieces, alternating colour and white: the dashed pattern that turns
local TURN = math.pi * 2 / 4 -- rad/s: one turn per 4 s
local BREATH = 1.6 -- s per glow breath
local POP_SECONDS = 0.25
local POP_SCALE = 1.4
local SYMBOL = { Speed = "»", Stamina = "+5" } -- plain text symbol, no image asset

local folder = Instance.new("Folder")
folder.Name = "PowerUps"
folder.Parent = Workspace

local rings = {} -- Id -> { Model, Base (CFrame), Hub, Light, Label, Popped (clock) }
local clock = 0

local function reduced()
	return player:GetAttribute("ReduceEffects") == true
end

local pending -- the last PowerUps event whose route folder had not replicated yet

local function clear()
	pending = nil
	for _, ring in rings do
		ring.Model:Destroy()
	end
	table.clear(rings)
end

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		p[k] = v
	end
	p.Parent = model
	return p
end

-- One ring at `feet` (the rail's pose at its distance), facing along the lane.
local function build(entry, feet)
	local color = PowerUpConfig.COLORS[entry.Kind] or Color3.new(1, 1, 1)
	local model = Instance.new("Model")
	model.Name = "PowerUp" .. entry.Id
	local base = feet * CFrame.new(0, HEIGHT, 0)
	local hub = part(model, { Name = "Hub", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = base })
	model.PrimaryPart = hub
	local len = 2 * math.pi * RADIUS / BITS
	for i = 1, BITS do
		local a = (i - 0.5) / BITS * math.pi * 2
		part(model, {
			Name = "Rim",
			Size = Vector3.new(len * 1.05, 0.9, 0.9),
			Color = i % 2 == 0 and Color3.new(1, 1, 1) or color,
			CFrame = base * CFrame.Angles(0, 0, a) * CFrame.new(0, RADIUS, 0),
		})
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Parent = hub
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(RADIUS * 1.2, RADIUS * 1.2)
	board.LightInfluence = 0
	board.Parent = hub
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = SYMBOL[entry.Kind] or ""
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.Parent = board
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = label
	model.Parent = folder
	rings[entry.Id] = { Model = model, Base = base, Hub = hub, Light = light, Label = label }
end

local function show(ev)
	clear()
	if type(ev.List) ~= "table" then
		return
	end
	local route = RunnerVisual.RouteOf(ev.Route)
	if not route then
		-- RunRoutes can replicate after the event on a fresh server: retry until it lands or the next event replaces this one.
		pending = ev
		task.spawn(function()
			while pending == ev do
				task.wait(0.25)
				if pending == ev and RunnerVisual.RouteOf(ev.Route) then
					show(ev)
					return
				end
			end
		end)
		return
	end
	for _, entry in ev.List do
		if type(entry) == "table" and type(entry.Dist) == "number" and not entry.Taken then
			build(entry, (PathDriver.PoseAt(route.Wps, route.Arc, entry.Dist, nil, route.Closed)))
		end
	end
end

local function take(id)
	local ring = rings[id]
	if ring and not ring.Popped then
		ring.Popped = clock
	end
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RunEvent").OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then
		return
	end
	if ev.Kind == "PowerUps" then
		show(ev)
	elseif ev.Kind == "PowerUpTaken" then
		take(ev.Id)
	end
end)

-- Walking again (the run ended): no rings left on the track
player:GetAttributeChangedSignal("RunSlot"):Connect(function()
	if player:GetAttribute("RunSlot") == nil then
		clear()
	end
end)

RunService.RenderStepped:Connect(function(dt)
	clock += dt
	local calm = reduced()
	local breath = 0.5 + 0.5 * math.sin(clock * math.pi * 2 / BREATH)
	for id, ring in rings do
		local spin = CFrame.Angles(0, 0, clock * TURN)
		if ring.Popped then
			local t = (clock - ring.Popped) / POP_SECONDS
			if t >= 1 then
				ring.Model:Destroy()
				rings[id] = nil
				continue
			end
			ring.Model:ScaleTo(1 + (POP_SCALE - 1) * t)
			for _, d in ring.Model:GetDescendants() do
				if d:IsA("BasePart") and d ~= ring.Hub then
					d.LocalTransparencyModifier = t
				end
			end
			ring.Label.TextTransparency = t
		end
		ring.Model:PivotTo(ring.Base * spin)
		ring.Light.Enabled = not calm
		ring.Light.Brightness = 1 + 2 * breath
	end
end)
