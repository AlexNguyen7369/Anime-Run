--!nonstrict
-- The enclosed cyber dojo (design doc 4.24 "Enclosed cyber dojo", owner 2026-11-10): the wall's shape, the blast door's
-- place, the palette and a part helper, shared by the server builders (Server/CyberWall, CyberGate, CyberLook,
-- CyberDojo), Client/CyberPlaza and BiomeEnvironment's zone 0. Drafted in tools/blender/plaza/build_cyber_plaza.py.
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

CyberPlaza.Colors = {
	Steel = Color3.fromRGB(44, 47, 62),
	Gunmetal = Color3.fromRGB(20, 22, 32),
	DoorSteel = Color3.fromRGB(92, 98, 116),
	Glass = Color3.fromRGB(40, 90, 140),
	Screen = Color3.fromRGB(14, 12, 30),
	Cyan = Color3.fromRGB(0, 240, 255),
	Magenta = Color3.fromRGB(255, 60, 210),
	Lime = Color3.fromRGB(180, 255, 90),
	Gold = Color3.fromRGB(255, 205, 80),
	Panel = Color3.fromRGB(60, 30, 130),
	City = Color3.fromRGB(26, 20, 42),
	Text = Color3.fromRGB(242, 251, 255),
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
