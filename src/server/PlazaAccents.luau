--!nonstrict
-- Cyber accents on the plaza (design doc 4.24 "Dojo with cyber accents", owner 2026-11-10; WORLD_REDESIGN_SPEC 4.1
-- "Cyber accents"). The plaza keeps its look as built: these parts only sit on top of it and move or hide nothing.
-- Neon trim on the torii and the stall roofs, a small wall screen in each stall, a holo scanning ring in the RACE START
-- gate and 4 warm-lit drones over the stone lanterns. Places come from Shared/PlazaAssets (read only) and the
-- geometry of tools/blender/plaza/build_plaza.py (hero_torii, stall, market_stall). Every part is anchored, does not
-- collide, touch or query, and casts no shadow. The ring spins and the drones bob on near clients (Client/BiomeAmbience,
-- tags BiomeSpin and BiomeBob). Sizes, colours and amounts are proposed.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlazaAssets"))

local TOP = 1 -- SpawnArea.TOP_Y

-- Warm, in the HUD's gold and navy family (4.40); pink only as a small accent (proposed)
local GOLD = Color3.fromRGB(255, 196, 70)
local AMBER = Color3.fromRGB(255, 150, 56)
local PAPER = Color3.fromRGB(255, 212, 150)
local PINK = Color3.fromRGB(255, 120, 180)
local SCREEN = Color3.fromRGB(34, 26, 34)
local STEEL = Color3.fromRGB(104, 96, 92) -- warm steel

-- Stall keys: eave trim (the lower roof's front eave in Blender local y and z, its width) and the wall screen on the
-- back wall's inner face (Blender local x, y, z of its centre, width, height). From build_plaza.py stall/market_stall.
local STALLS = {
	SHOPStall = { Eave = Vector3.new(14.5, -6.75, 8.85), Screen = { 2.5, 4.3, 6.2, 4, 2.2 }, Color = GOLD },
	POTIONSStall = { Eave = Vector3.new(14.5, -6.75, 8.85), Screen = { -2.5, 4.3, 6.2, 4, 2.2 }, Color = PINK },
	MarketStall = { Eave = Vector3.new(20, -7.2, 8.75), Screen = { 0, 4.4, 6.8, 5, 1.6 }, Color = AMBER },
}
local SCAN_RADIUS = 7
local SCAN_HEIGHT = 8.5 -- ring centre above the floor
local SCAN_SEGMENTS = 14
local DRONE_HEIGHTS = { 15, 17, 16, 18 } -- above the floor, one per lantern

local PlazaAccents = {}

local function part(parent, name, size, cframe, color, neon)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function rows(key)
	local list = {}
	for _, row in Layout.Placed do
		if row.Key == key then
			table.insert(list, row)
		end
	end
	return list
end

-- The asset's frame as PlazaDressing places it: local +Z is its front (row.Face), X across, Y up.
local function frameOf(row)
	local here = Vector3.new(row.Pos.X, TOP, row.Pos.Z)
	return CFrame.lookAt(here, here - row.Face)
end

-- Blender local (x, y, z) of build_plaza.py, front -y, z up, to this frame.
local function at(frame, x, y, z)
	return frame * CFrame.new(x, z, -y)
end

-- Torii (hero_torii: posts at x = +-12 tapering from r 2.0 to 1.55 over 34, tie beam 28 wide, 1.6 deep, 2 tall at z 27): a neon
-- line on both faces of the tie beam and one up the inner side of each post, under the beam.
local function torii(parent, frame)
	for _, s in { -1, 1 } do
		part(parent, "TieBeamTrim", Vector3.new(26, 0.3, 0.1), at(frame, 0, s * 0.85, 27), GOLD, true)
		part(parent, "PostTrim", Vector3.new(0.2, 22, 0.4), at(frame, s * (12 - 1.9), 0, 14), AMBER, true)
	end
end

-- A vertical ring across the gate's opening, turning about its vertical axis on near clients.
local function scanRing(parent, frame)
	local ring = Instance.new("Model")
	ring.Name = "ScanRing"
	local centre = at(frame, 0, 0, SCAN_HEIGHT)
	local length = 2 * SCAN_RADIUS * math.tan(math.pi / SCAN_SEGMENTS) + 0.05
	for i = 0, SCAN_SEGMENTS - 1 do
		local bar = part(
			ring,
			"Scan",
			Vector3.new(length, 0.35, 0.35),
			centre * CFrame.Angles(0, 0, i * 2 * math.pi / SCAN_SEGMENTS) * CFrame.new(0, SCAN_RADIUS, 0),
			GOLD,
			true
		)
		bar.Transparency = 0.25
	end
	ring.WorldPivot = centre
	ring:SetAttribute("BasePivot", centre)
	ring.Parent = parent
	CollectionService:AddTag(ring, "BiomeSpin")
end

-- A neon line under the lower roof's front eave, and a lit screen in a neon frame on the back wall.
local function stall(parent, frame, spec)
	local e = spec.Eave
	part(parent, "EaveTrim", Vector3.new(e.X, 0.25, 0.25), at(frame, 0, e.Y, e.Z), spec.Color, true)
	local x, y, z, w, h = table.unpack(spec.Screen)
	part(parent, "ScreenFrame", Vector3.new(w + 0.4, h + 0.4, 0.1), at(frame, x, y - 0.05, z), spec.Color, true)
	local face = part(parent, "Screen", Vector3.new(w, h, 0.1), at(frame, x, y - 0.12, z), SCREEN, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the frame's +Z, toward the path
	gui.LightInfluence = 0
	gui.Parent = face
	local glow = Instance.new("Frame")
	glow.BorderSizePixel = 0
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.9, 0.8)
	glow.BackgroundColor3 = Color3.new(1, 1, 1)
	glow.BackgroundTransparency = 0.15
	glow.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(PAPER, AMBER)
	gradient.Rotation = 90
	gradient.Parent = glow
end

-- A warm steel disc with a gold rim and an amber lamp under it.
local function drone(parent, position, i)
	local m = Instance.new("Model")
	m.Name = "Drone"
	local flat = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X
	local body = part(m, "Body", Vector3.new(0.8, 4, 4), flat, STEEL, false)
	body.Shape = Enum.PartType.Cylinder
	body.Material = Enum.Material.Metal
	part(m, "Rim", Vector3.new(0.25, 4.4, 4.4), flat, i == 4 and PINK or GOLD, true).Shape = Enum.PartType.Cylinder
	local lamp = part(m, "Lamp", Vector3.new(0.4, 1.4, 1.4), flat + Vector3.new(0, -0.5, 0), AMBER, true)
	lamp.Shape = Enum.PartType.Cylinder
	local light = Instance.new("PointLight")
	light.Color = AMBER
	light.Brightness = 1.2
	light.Range = 18
	light.Shadows = false
	light.Parent = lamp
	local pivot = CFrame.new(position)
	m.WorldPivot = pivot
	m:SetAttribute("BasePivot", pivot)
	m.Parent = parent
	CollectionService:AddTag(m, "BiomeBob")
end

function PlazaAccents.Build()
	local folder = Instance.new("Folder")
	folder.Name = "PlazaAccents"
	local gate = rows("HeroTorii")[1]
	if gate then
		local frame = frameOf(gate)
		torii(folder, frame)
		scanRing(folder, frame)
	end
	for key, spec in STALLS do
		for _, row in rows(key) do
			stall(folder, frameOf(row), spec)
		end
	end
	for i, row in rows("Lantern") do
		if DRONE_HEIGHTS[i] then
			drone(folder, Vector3.new(row.Pos.X, TOP + DRONE_HEIGHTS[i], row.Pos.Z), i)
		end
	end
	folder.Parent = Workspace
	return folder
end

return PlazaAccents
