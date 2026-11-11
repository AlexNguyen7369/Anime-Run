--!nonstrict
-- The enclosed dojo (design doc 4.24 "Enclosed cyber dojo" and "Hybrid look", owner 2026-11-10): the wall's shape, the
-- blast door's place, the palette and part helpers, shared by the server builders (Server/CyberWall, CyberGate, CyberLook,
-- CyberDojo), Client/CyberPlaza and BiomeEnvironment's zone 0. Drafted in tools/blender/plaza/build_cyber_plaza.py
-- (THEME=hybrid).
-- World studs; the spawn is the world origin. Sizes, colours and heights are proposed.
local UiTheme = require(script.Parent.UiTheme)

local CyberPlaza = {}

-- The wall is a rounded rectangle whose corners share their centres with Track 1's first-lap corners (radius 80), so
-- it runs 2 studs inside that lap's side walls all the way round. The draft's circle (radius 158 round (20, 0)) would
-- cut Track 1's start leg at x = -118.
CyberPlaza.CORNER_MIN = Vector2.new(-38, -120) -- world (x, z) of Track 1's corner centres
CyberPlaza.CORNER_MAX = Vector2.new(130, 130)
CyberPlaza.RADIUS = 55 -- wall centre line from a corner centre: 80 - 20 (half road) - 2 (side wall) - 2 clear - 1
CyberPlaza.WALL_HEIGHT = 60
CyberPlaza.WALL_THICKNESS = 2
CyberPlaza.TOP = 1 -- the floor top (SpawnArea.TOP_Y)
CyberPlaza.DOOR_WIDTH = 28 -- both leaves
CyberPlaza.DOOR_HEIGHT = 40
CyberPlaza.FRAME = 6 -- door frame post width either side
CyberPlaza.TAG = "CyberDoorLeaf" -- the door's two leaf Models (Client/CyberPlaza slides them)

-- Hybrid look (design doc 4.24 "Hybrid look", owner 2026-11-10): warm wood, red lacquer, warm stone and gold trim that
-- sit with the gold and navy HUD (4.40); neon only as accents, cyan and pink sparingly. Proposed.
CyberPlaza.Colors = {
	Wood = Color3.fromRGB(122, 74, 42),
	DarkWood = Color3.fromRGB(78, 46, 28),
	Lacquer = Color3.fromRGB(176, 40, 30),
	Steel = Color3.fromRGB(104, 96, 92), -- warm steel
	Stone = Color3.fromRGB(168, 142, 112),
	Paving = Color3.fromRGB(196, 168, 128),
	RoofTile = Color3.fromRGB(96, 54, 44),
	Grass = Color3.fromRGB(106, 150, 70),
	Leaf = Color3.fromRGB(70, 122, 56),
	Blossom = Color3.fromRGB(255, 176, 204),
	Screen = Color3.fromRGB(34, 26, 34),
	Paper = Color3.fromRGB(255, 212, 150), -- lit paper and screen glow
	Gold = Color3.fromRGB(255, 196, 70),
	Amber = Color3.fromRGB(255, 150, 56),
	Cyan = Color3.fromRGB(90, 228, 240), -- accent; also the unpainted Glow_lamp (UiTest/UiCyberPlaza reads it)
	Pink = Color3.fromRGB(255, 120, 180), -- accent
	Dusk = Color3.fromRGB(92, 64, 78), -- far silhouettes against the dusk sky
	Text = Color3.fromRGB(255, 240, 210),
}

-- Signed distance (studs) of world (x, z) from the wall's centre line: negative inside the compound.
function CyberPlaza.Distance(x, z)
	local lo, hi = CyberPlaza.CORNER_MIN, CyberPlaza.CORNER_MAX
	local dx = math.max(lo.X - x, 0, x - hi.X)
	local dz = math.max(lo.Y - z, 0, z - hi.Y)
	if dx > 0 or dz > 0 then
		return math.sqrt(dx * dx + dz * dz) - CyberPlaza.RADIUS
	end
	return -math.min(x - lo.X, hi.X - x, z - lo.Y, hi.Y - z) - CyberPlaza.RADIUS
end

function CyberPlaza.Inside(p)
	return CyberPlaza.Distance(p.X, p.Z) < 0
end

-- The blast door: where the spawn-to-pad path axis meets the west wall. Its frame sits on the floor top at the wall's
-- centre line, LookVector = into the compound, RightVector along the wall.
function CyberPlaza.DoorFrame(padPosition)
	local axis = Vector3.new(padPosition.X, 0, padPosition.Z).Unit
	local x = CyberPlaza.CORNER_MIN.X - CyberPlaza.RADIUS
	assert(axis.X < 0, "CyberPlaza: the start pad must be west of the spawn")
	local t = (x - padPosition.X) / axis.X
	local here = Vector3.new(x, CyberPlaza.TOP, padPosition.Z + axis.Z * t)
	return CFrame.lookAt(here, here + Vector3.new(1, 0, 0))
end

-- An anchored part. Decoration (collide not true) also skips touch and query; neon casts no shadow.
function CyberPlaza.Part(parent, name, size, cframe, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if collide ~= true then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end
	if p.Material == Enum.Material.Neon then
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end

function CyberPlaza.Neon(parent, name, size, cframe, color)
	return CyberPlaza.Part(parent, name, size, cframe, color, Enum.Material.Neon)
end

-- A ring of `segments` neon bars, radius r, in the XY plane of `frame` (turn the frame to lay it flat).
function CyberPlaza.Ring(parent, name, frame, r, thickness, color, segments)
	local length = 2 * r * math.tan(math.pi / segments) + 0.05
	for i = 0, segments - 1 do
		local a = i * 2 * math.pi / segments
		CyberPlaza.Neon(
			parent,
			name,
			Vector3.new(length, thickness, thickness),
			frame * CFrame.Angles(0, 0, a) * CFrame.new(0, r, 0),
			color
		)
	end
end

-- A tiled gable roof over a w x d footprint: two wedges meeting at a ridge along X, eaves at `eave` above `frame`
-- (frame on the footprint's centre, Y up), rising `rise`, with a thin trim line along each eave.
function CyberPlaza.Roof(parent, frame, w, d, eave, rise, trim)
	for _, side in { 1, -1 } do
		local half = frame * CFrame.Angles(0, side > 0 and 0 or math.pi, 0)
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanTouch = false
		wedge.CanQuery = false
		wedge.Size = Vector3.new(w, rise, d / 2)
		wedge.CFrame = half * CFrame.new(0, eave + rise / 2, -d / 4) -- high edge at the ridge, slope facing out
		wedge.Color = CyberPlaza.Colors.RoofTile
		wedge.Material = Enum.Material.Slate
		wedge.Parent = parent
		if trim then
			CyberPlaza.Neon(parent, "RoofTrim", Vector3.new(w, 0.25, 0.25), half * CFrame.new(0, eave, -d / 2), trim)
		end
	end
end

-- A warm light on `part` (local, shadow-free).
function CyberPlaza.Light(part, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
	return light
end

-- Bold text on a thin invisible board facing `face` (world direction).
function CyberPlaza.Sign(parent, text, position, face, size, color)
	local board = CyberPlaza.Part(
		parent,
		"Sign",
		Vector3.new(math.max(#text * size * 0.72, 2), size * 1.3, 0.1),
		CFrame.lookAt(position, position + face),
		Color3.new()
	)
	board.Transparency = 1
	board.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = UiTheme.Font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = gui
	return board
end

return CyberPlaza
