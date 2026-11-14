--!nonstrict
-- Blossom-shrine hybrid. The clean image is registered on SummonScreenAssets only after upload.
-- Geometry and camera use the approved Blender coordinate system (one unit = one stud).
local Hybrid = {}
local DESIGN = Vector2.new(1808, 870)
local ASPECT = DESIGN.X / DESIGN.Y
local ORIGIN = Vector3.new(-1.1, 9996.36, -7.1)
local CAMERA_X = ORIGIN.X + 0.90
local CAMERA_POSITION = Vector3.new(CAMERA_X, ORIGIN.Y + 4.394214, ORIGIN.Z - 21.345324)
local CAMERA_TARGET = Vector3.new(CAMERA_X, ORIGIN.Y + 3.406919, ORIGIN.Z + 5)
local BASE_CAMERA = CFrame.lookAt(CAMERA_POSITION, CAMERA_TARGET)
local TAN_HALF_VERTICAL = (18 / 40.073346) / ASPECT
local BACKDROP_DEPTH = 105
local STAGE_CENTER = Vector3.new(0, 8.1, 0)
local PALETTE = {
	Stone = Color3.fromRGB(70, 50, 46),
	Edge = Color3.fromRGB(105, 80, 67),
	Gold = Color3.fromRGB(255, 177, 75),
	Rose = Color3.fromRGB(255, 143, 121),
	Crystal = Color3.fromRGB(246, 106, 179),
	Bronze = Color3.fromRGB(123, 81, 33),
}
local function point(v)
	return ORIGIN + Vector3.new(-v.X, v.Z, v.Y)
end
local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function cylinder(parent, name, center, radius, height, color)
	local p = part(
		parent,
		name,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(point(center)) * CFrame.Angles(0, 0, math.pi / 2),
		color
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function segment(parent, name, a, b, width, color, neon)
	a, b = point(a), point(b)
	return part(
		parent,
		name,
		Vector3.new(width, width, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b),
		color,
		neon and Enum.Material.Neon or nil
	)
end
local function ring(parent, name, radius, z, color, width, count)
	local pieces = {}
	for i = 1, count do
		local a, b = (i - 1) * math.pi * 2 / count, i * math.pi * 2 / count
		table.insert(
			pieces,
			segment(
				parent,
				name,
				Vector3.new(radius * math.cos(a), STAGE_CENTER.Y + radius * math.sin(a), z),
				Vector3.new(radius * math.cos(b), STAGE_CENTER.Y + radius * math.sin(b), z),
				width,
				color,
				true
			)
		)
	end
	return pieces
end
-- Two thin wedges form one triangle, allowing script-free faceted foreground props.
local function triangle(parent, name, a, b, c, color)
	a, b, c = point(a), point(b), point(c)
	local ab, ac, bc = b - a, c - a, c - b
	if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then
		c, a = a, c
	elseif ac:Dot(ac) > bc:Dot(bc) then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up, back = bc:Cross(right).Unit, bc.Unit
	local height = math.abs(ab:Dot(up))
	for _, record in
		{
			{ (a + b) / 2, right, back, math.abs(ab:Dot(back)) },
			{ (a + c) / 2, -right, -back, math.abs(ac:Dot(back)) },
		}
	do
		if record[4] > 0.001 then
			local p = Instance.new("WedgePart")
			p.Name, p.Size = name, Vector3.new(0.012, height, record[4])
			p.CFrame = CFrame.fromMatrix(record[1], record[2], up, record[3])
			p.Color, p.Material = color, Enum.Material.SmoothPlastic
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
			p.Parent = parent
		end
	end
end
local function crystal(parent, center, width, height)
	local ringPoints = {}
	for i = 1, 4 do
		local a = (i - 1) * math.pi / 2
		ringPoints[i] = center + Vector3.new(math.cos(a) * width, math.sin(a) * width, height * 0.40)
	end
	for i = 1, 4 do
		local a, b = ringPoints[i], ringPoints[i % 4 + 1]
		local color = PALETTE.Crystal:Lerp(Color3.fromRGB(255, 211, 230), i % 2 == 0 and 0.16 or 0)
		triangle(parent, "CrystalUpperFacet", a, b, center + Vector3.new(width * 0.1, 0, height), color)
		triangle(parent, "CrystalLowerFacet", b, a, center, color)
	end
end
function Hybrid.Available(assets)
	local image = assets:GetAttribute("HybridBackdropImage")
	return type(image) == "string" and image:match("^rbxassetid://[1-9]%d*$") ~= nil
end
function Hybrid.Attach(stage, assets)
	if not Hybrid.Available(assets) then
		return nil
	end
	local root = Instance.new("Model")
	root.Name = "BlossomHybrid"
	root.Parent = stage
	local self = { Root = root, Rings = {}, Petals = {} }
	-- Set up the replacement before removing the old local galaxy environment.
	self.Backdrop = part(root, "ShrineBackdrop", Vector3.new(1, 1, 0.1), CFrame.new(), Color3.new(1, 1, 1))
	self.Backdrop.Transparency = 1
	local surface = Instance.new("SurfaceGui")
	surface.Name, surface.Face = "BackdropArt", Enum.NormalId.Front
	surface.LightInfluence, surface.AlwaysOnTop = 0, false
	surface.SizingMode, surface.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, DESIGN
	surface.Parent = self.Backdrop
	local image = Instance.new("ImageLabel")
	image.Name, image.BackgroundTransparency, image.Size = "Cleanplate", 1, UDim2.fromScale(1, 1)
	image.Image, image.ScaleType = assets:GetAttribute("HybridBackdropImage"), Enum.ScaleType.Stretch
	image.Parent = surface
	cylinder(root, "LowerStep", Vector3.new(0, 8.1, 0.055), 9.15, 0.11, PALETTE.Edge)
	cylinder(root, "UpperStep", Vector3.new(0, 8.1, 0.16), 8.78, 0.16, PALETTE.Edge)
	cylinder(root, "StoneStage", Vector3.new(0, 8.1, 0.31), 8.28, 0.26, PALETTE.Stone)
	for i = 1, 64 do
		local a = (i - 0.5) * math.pi * 2 / 64
		local center = Vector3.new(8.51 * math.cos(a), 8.1 + 8.51 * math.sin(a), 0.22)
		part(
			root,
			"StageBorderStone",
			Vector3.new(0.72, 0.16, 0.45),
			CFrame.new(point(center)) * CFrame.Angles(0, a - math.pi / 2, 0),
			PALETTE.Edge
		)
	end
	self.Rings = ring(root, "AmberPerimeter", 7.8, 0.47, PALETTE.Gold, 0.055, 72)
	ring(root, "EngravedInnerRing", 5.8, 0.455, PALETTE.Rose, 0.015, 64)
	for petal = 0, 4 do
		local angle = petal * math.pi * 2 / 5
		local points = {}
		for i = 0, 24 do
			local t = i / 24 * math.pi * 2
			local x = math.sin(t) * (0.68 + 0.22 * math.cos(t))
			local y = (1 - math.cos(t)) * 1.50
			table.insert(
				points,
				Vector3.new(
					x * math.cos(angle) - y * math.sin(angle),
					8.1 + x * math.sin(angle) + y * math.cos(angle),
					0.46
				)
			)
		end
		for i = 1, #points - 1 do
			segment(root, "BlossomInlay", points[i], points[i + 1], 0.018, PALETTE.Rose, true)
		end
	end
	for _, x in { -6.6, 6.6 } do
		local y = 2.3
		cylinder(root, "CrystalPlinth", Vector3.new(x, y, 0.25), 0.65, 0.5, PALETTE.Edge)
		crystal(root, Vector3.new(x - 0.25, y + 0.1, 0.50), 0.21, 0.95)
		crystal(root, Vector3.new(x, y, 0.50), 0.30, 1.35)
		crystal(root, Vector3.new(x + 0.25, y + 0.1, 0.50), 0.23, 1.02)
	end
	for _, x in { -7, 7 } do
		local y = 4.6
		part(root, "LanternFoot", Vector3.new(0.8, 0.34, 0.8), CFrame.new(point(Vector3.new(x, y, 0.17))), PALETTE.Edge)
		part(
			root,
			"LanternStem",
			Vector3.new(0.31, 1.02, 0.31),
			CFrame.new(point(Vector3.new(x, y, 0.83))),
			PALETTE.Edge
		)
		part(
			root,
			"LanternLight",
			Vector3.new(0.51, 0.48, 0.51),
			CFrame.new(point(Vector3.new(x, y, 1.69))),
			PALETTE.Gold,
			Enum.Material.Neon
		)
		part(
			root,
			"LanternCap",
			Vector3.new(0.78, 0.18, 0.78),
			CFrame.new(point(Vector3.new(x, y, 2.04))),
			PALETTE.Bronze
		)
		local rim = {
			Vector3.new(x - 0.43, y - 0.43, 2.10),
			Vector3.new(x + 0.43, y - 0.43, 2.10),
			Vector3.new(x + 0.43, y + 0.43, 2.10),
			Vector3.new(x - 0.43, y + 0.43, 2.10),
		}
		for i = 1, 4 do
			triangle(root, "LanternRoofFacet", rim[i], rim[i % 4 + 1], Vector3.new(x, y, 2.43), PALETTE.Bronze)
		end
	end
	-- Existing original petal image from tools/blender/plaza/plaza_assets.json.
	-- Deterministic world-space petals stay behind the character/aura zone (Z >= 4.5).
	for i = 1, 30 do
		local p = part(root, "BackgroundPetal", Vector3.new(0.22, 0.22, 0.01), CFrame.new(), PALETTE.Rose)
		p.Transparency = 1
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.AlwaysOnTop, gui.LightInfluence = UDim2.fromScale(0.24, 0.24), false, 0
		gui.Parent = p
		local art = Instance.new("ImageLabel")
		art.BackgroundTransparency, art.Size = 1, UDim2.fromScale(1, 1)
		art.Image, art.ImageColor3 = "rbxassetid://130260166899982", Color3.fromRGB(255, 170, 204)
		art.Parent = gui
		table.insert(self.Petals, { Part = p, Art = art, Index = i })
	end
	for _, name in { "Backdrop", "GalaxyVFX", "BackgroundStars", "Floor" } do
		local old = stage:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	self.FixedFloorParts = {}
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "ShrineBackdrop" and p.Name ~= "BackgroundPetal" then
			table.insert(self.FixedFloorParts, { Part = p, Base = p.CFrame })
		end
	end
	return setmetatable(self, { __index = Hybrid })
end
function Hybrid:Frame(view, drift, elapsed, reduced)
	local aspect = view.X / math.max(view.Y, 1)
	local tanHalf = TAN_HALF_VERTICAL * math.min(1, ASPECT / aspect)
	local fov = math.deg(2 * math.atan(tanHalf))
	local shift = reduced and Vector3.zero or Vector3.new(drift.X * 0.12, -drift.Y * 0.065, 0)
	local cf = BASE_CAMERA + shift
	local height = 2 * BACKDROP_DEPTH * TAN_HALF_VERTICAL * 1.035
	self.Backdrop.Size = Vector3.new(height * ASPECT, height, 0.1)
	self.Backdrop.CFrame = cf * CFrame.new(0, 0, -BACKDROP_DEPTH) * CFrame.Angles(0, math.pi, 0)
	-- Camera-relative translation keeps the real floor and the painted floor fixed in screen space.
	for _, entry in self.FixedFloorParts do
		entry.Part.CFrame = entry.Base + shift
	end
	local pulse = reduced and 0.10 or 0.10 + math.sin(elapsed * math.pi * 2 / 5) * 0.035
	for _, p in self.Rings do
		p.Transparency = pulse
	end
	for _, entry in self.Petals do
		local i = entry.Index
		local t = reduced and 0 or elapsed
		local x = ((i * 7.31) % 31) - 15.5 + math.sin(t * 0.34 + i) * 1.0
		local y = ORIGIN.Y + ((i * 1.71 - t * (0.38 + i % 4 * 0.05)) % 13) - 1
		entry.Part.CFrame = CFrame.new(ORIGIN.X + x, y, 4.5 + (i * 1.73) % 9)
		entry.Art.Rotation = reduced and i * 17 or i * 17 + t * (8 + i % 5)
	end
	return cf, fov
end
return Hybrid
