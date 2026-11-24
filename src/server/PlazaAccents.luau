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

-- World 2's colours and set pieces (design doc 4.47 "Rift Shrine", placeholders in Shared/PlazaLook); empty in World 1
local Look = require(ReplicatedStorage.Shared.PlazaLook)

-- Warm, in the HUD's gold and navy family (4.40); pink only as a small accent (proposed). World 2 swaps them for cyan.
local ACCENT = Look.Accent or {}
local GOLD = ACCENT.Gold or Color3.fromRGB(255, 196, 70)
local AMBER = ACCENT.Amber or Color3.fromRGB(255, 150, 56)
local PAPER = ACCENT.Paper or Color3.fromRGB(255, 212, 150)
local PINK = ACCENT.Pink or Color3.fromRGB(255, 120, 180)
local SCREEN = Color3.fromRGB(34, 26, 34)
local STEEL = Color3.fromRGB(104, 96, 92) -- warm steel
local AMBER_LAMP = Color3.fromHex("FFB765") -- the plaza lanterns' glow (PlazaAssets Glow_lamp)

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

-- World 2's rift (design doc 4.47, plaza_w2.py rift()): a blue disc with two violet spiral arms that turns slowly in its
-- own plane on near clients (BiomeSpin turns about the pivot's Y, here the disc's normal), a cyan rim and a ring of
-- floating stones. The glowing pieces are BiomeDetail (REDUCED EFFECTS hides them far away and stops the disc). 64 parts,
-- no lights.
local function bar(parent, name, a, b, width, normal, color)
	return part(
		parent,
		name,
		Vector3.new(width, 0.3, (b - a).Magnitude + 0.2),
		CFrame.lookAt((a + b) / 2, b, normal),
		color,
		true
	)
end

local function rift(parent, spec)
	local R = spec.Radius
	local pivot = CFrame.fromMatrix(spec.Centre, Vector3.yAxis, spec.Face) -- local Y faces the spawn
	local function onDisc(angle, r, off)
		return pivot:PointToWorldSpace(Vector3.new(r * math.cos(angle), off, r * math.sin(angle)))
	end
	local disc = Instance.new("Model")
	disc.Name = "RiftDisc"
	local d = 2 * (R - 4.5)
	part(disc, "Disc", Vector3.new(0.4, d, d), pivot * CFrame.Angles(0, 0, math.pi / 2), spec.Blue, true).Shape =
		Enum.PartType.Cylinder
	for arm = 0, 1 do
		for k = 1, 8 do
			local a0, a1 = arm * math.pi + (k - 1) * 0.55, arm * math.pi + k * 0.55
			local r0, r1 = (R - 5) * (k - 1) / 8, (R - 5) * k / 8
			bar(disc, "Arm", onDisc(a0, r0, 0.35), onDisc(a1, r1, 0.35), 1 + r1 * 0.12, spec.Face, spec.Violet)
		end
	end
	part(disc, "Eye", Vector3.new(5, 5, 5), CFrame.new(onDisc(0, 0, 0.5)), spec.Rim, true).Shape = Enum.PartType.Ball
	disc.WorldPivot = pivot
	disc:SetAttribute("BasePivot", pivot)
	disc.Parent = parent
	disc:SetAttribute("ReducedStill", true) -- Client/BiomeAmbience holds it at rest under REDUCED EFFECTS
	CollectionService:AddTag(disc, "BiomeSpin")
	CollectionService:AddTag(disc, "BiomeDetail")

	local rim = Instance.new("Model")
	rim.Name = "RiftRim"
	for k = 0, 23 do
		bar(
			rim,
			"Rim",
			onDisc(k / 24 * 2 * math.pi, R - 3.5, 0),
			onDisc((k + 1) / 24 * 2 * math.pi, R - 3.5, 0),
			1.6,
			spec.Face,
			spec.Rim
		)
	end
	rim.Parent = parent
	CollectionService:AddTag(rim, "BiomeDetail")

	local stones = Instance.new("Model")
	stones.Name = "RiftStones"
	local rng = Random.new(7)
	for k = 0, spec.Stones - 1 do
		local size = rng:NextNumber(4.4, 7.2)
		local stone = part(
			stones,
			"Stone",
			Vector3.new(size, size * rng:NextNumber(0.7, 1), size),
			CFrame.new(onDisc(k / spec.Stones * 2 * math.pi, R + rng:NextNumber(-1, 2), rng:NextNumber(-1.5, 1.5))),
			spec.Rock,
			false
		)
		stone.Shape = Enum.PartType.Ball
		stone.Material = Enum.Material.Slate
	end
	stones.Parent = parent
end

-- World 2's floating rock islands (plaza_w2.py islands()): a tapering rock under a slab and a grass top, a sakura bush,
-- a lantern on every second one. 6 or 8 parts each, no lights.
local function island(parent, row, i, colors)
	local x, z, y, r = table.unpack(row)
	local m = Instance.new("Model")
	m.Name = "Island"
	local up = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X
	local function disc(name, h, radius, cy, color, material)
		local p = part(m, name, Vector3.new(h, radius * 2, radius * 2), CFrame.new(x, cy, z) * up, color, false)
		p.Shape = Enum.PartType.Cylinder
		p.Material = material
	end
	for k, f in { 0.9, 0.6, 0.3 } do
		disc("Rock", r * 0.5, r * f, y - r * 0.25 - (k - 1) * r * 0.5, colors.Rock, Enum.Material.Slate)
	end
	disc("Slab", 0.4, r, y + 0.2, colors.Slab, Enum.Material.Slate)
	disc("Grass", 0.9, r * 0.96, y + 0.85, colors.Grass, Enum.Material.Grass)
	local bush = part(
		m,
		"Bloom",
		Vector3.new(r * 0.6, r * 0.5, r * 0.6),
		CFrame.new(x + r * 0.2, y + 1.3 + r * 0.2, z + r * 0.1),
		colors.Bloom,
		false
	)
	bush.Shape = Enum.PartType.Ball
	if i % 2 == 1 then
		local lx, lz = x - r * 0.45, z - r * 0.3
		part(m, "LanternPost", Vector3.new(0.6, 2, 0.6), CFrame.new(lx, y + 2.3, lz), colors.Slab, false)
		part(m, "LanternLamp", Vector3.new(0.9, 0.9, 0.9), CFrame.new(lx, y + 3.7, lz), AMBER_LAMP, true)
	end
	m.Parent = parent
	CollectionService:AddTag(m, "BiomeDetail")
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
	if Look.Rift then
		rift(folder, Look.Rift)
	end
	for i, row in Look.Islands or {} do
		island(folder, row, i, Look.IslandColors)
	end
	folder.Parent = Workspace
	return folder
end

return PlazaAccents
