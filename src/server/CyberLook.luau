--!nonstrict
-- Slice 3 of the enclosed cyber dojo (design doc 4.24, owner 2026-11-10): steel and glass buildings with wall screens
-- over the economy wing's stalls (the stalls do not move: each building wraps its stand-in, whose prompt stays), drones
-- in place of the stone lanterns, a wireframe hologram tree on a solid pedestal in place of the Great Sakura, and a
-- steel spawn. Places come from Shared/PlazaAssets (Layout C). The city skyline is client-local (Client/CyberPlaza),
-- since it stands over the track chain. Sizes and colours are proposed.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CyberPlaza = require(Shared:WaitForChild("CyberPlaza"))
local Layout = require(Shared:WaitForChild("PlazaAssets"))

local C = CyberPlaza.Colors
local Part, Neon = CyberPlaza.Part, CyberPlaza.Neon
local TOP = CyberPlaza.TOP

-- Stand-in name, its PlazaAssets key, width, front and back of the building from the stand-in's origin (studs), screen
-- colour. Each front stays behind its flat sign (PlazaAssets Signs) and the Market's MarketSign mesh.
local BUILDINGS = {
	{ Name = "ShopStall", Key = "SHOPStall", Width = 14, Front = 4.5, Back = 6, Color = C.Cyan },
	{ Name = "PotionsStall", Key = "POTIONSStall", Width = 14, Front = 4.5, Back = 6, Color = C.Magenta },
	{ Name = "Marketplace", Key = "MarketStall", Width = 22, Front = 3, Back = 6, Color = C.Gold },
	{ Name = "IndexBoard", Key = "IndexBoard", Width = 22, Front = 0.2, Back = 8, Color = C.Lime },
}
local BUILDING_HEIGHT = 14
local DRONE_HEIGHT = 16 -- above the floor
local TREE_RINGS = 8
local TREE_SPOKES = 8

local CyberLook = {}

local function placed(key)
	local rows = {}
	for _, row in Layout.Placed do
		if row.Key == key then
			table.insert(rows, row)
		end
	end
	return rows
end

-- The stand-in turns unseen; only the part carrying its ProximityPrompt keeps colliding (the building collides instead).
local function hide(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CastShadow = false
			d.CanCollide = d:FindFirstChildOfClass("ProximityPrompt") ~= nil
		elseif d:IsA("SurfaceGui") then
			d.Enabled = false
		end
	end
end

local function building(parent, spawnArea, spec)
	local row = placed(spec.Key)[1]
	local standIn = spawnArea:FindFirstChild(spec.Name)
	if not (row and standIn) then
		return
	end
	hide(standIn)
	local here = Vector3.new(row.Pos.X, TOP, row.Pos.Z)
	local f = CFrame.lookAt(here, here + row.Face) -- -Z toward the path
	local w, front, back, h = spec.Width, spec.Front, spec.Back, BUILDING_HEIGHT
	local m = Instance.new("Model")
	m.Name = spec.Name
	Part(
		m,
		"Body",
		Vector3.new(w, h, front + back),
		f * CFrame.new(0, h / 2, (back - front) / 2),
		C.Steel,
		Enum.Material.Metal,
		true
	)
	local glass =
		Part(m, "Glass", Vector3.new(w - 2, 4, 0.3), f * CFrame.new(0, 3, -front - 0.15), C.Glass, Enum.Material.Glass)
	glass.Transparency = 0.35
	Neon(m, "Ledge", Vector3.new(w - 2, 0.3, 0.6), f * CFrame.new(0, 5.15, -front - 0.3), spec.Color)
	Neon(m, "ScreenGlow", Vector3.new(w - 2.4, 4.6, 0.1), f * CFrame.new(0, 12, -front - 0.05), spec.Color)
	Part(m, "Screen", Vector3.new(w - 3, 4, 0.1), f * CFrame.new(0, 12, -front - 0.15), C.Screen)
	Neon(
		m,
		"RoofRim",
		Vector3.new(w + 0.4, 0.5, front + back + 0.4),
		f * CFrame.new(0, h + 0.25, (back - front) / 2),
		C.Cyan
	)
	-- The prompt part, when it stands out of the building's front (the Market counter), gets a steel look
	for _, d in standIn:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and f:PointToObjectSpace(d.Position).Z - d.Size.Z / 2 < -front then
			Part(m, "Counter", d.Size, d.CFrame, C.Steel, Enum.Material.Metal)
			Neon(
				m,
				"CounterEdge",
				Vector3.new(d.Size.X, 0.2, 0.2),
				d.CFrame * CFrame.new(0, d.Size.Y / 2, -d.Size.Z / 2),
				spec.Color
			)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = spec.Color
	light.Brightness = 1.5
	light.Range = 18
	light.Shadows = false
	light.Parent = m.Ledge
	m.Parent = parent
end

-- Drones in place of the stone lanterns: a steel disc with a lime light under it, bobbing on near clients (BiomeBob)
local function drones(parent)
	for i, row in placed("Lantern") do
		local m = Instance.new("Model")
		m.Name = "Drone"
		local at = CFrame.new(row.Pos.X, TOP + DRONE_HEIGHT, row.Pos.Z)
		local body = Part(
			m,
			"Body",
			Vector3.new(0.8, 4.4, 4.4),
			at * CFrame.Angles(0, 0, math.pi / 2),
			C.Steel,
			Enum.Material.Metal
		)
		body.Shape = Enum.PartType.Cylinder
		local lamp = Neon(
			m,
			"Light",
			Vector3.new(0.4, 1.2, 1.2),
			at * CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
			C.Lime
		)
		lamp.Shape = Enum.PartType.Cylinder
		CyberPlaza.Ring(
			m,
			"Rim",
			at * CFrame.Angles(math.pi / 2, 0, 0),
			2.2,
			0.2,
			i % 2 == 0 and C.Cyan or C.Magenta,
			12
		)
		local light = Instance.new("PointLight")
		light.Color = C.Lime
		light.Brightness = 1.2
		light.Range = 20
		light.Shadows = false
		light.Parent = lamp
		m.WorldPivot = at
		m:SetAttribute("BasePivot", at)
		m.Parent = parent
		CollectionService:AddTag(m, "BiomeBob")
	end
end

-- The hologram tree on its solid pedestal where the Great Sakura stood: a neon trunk, stacked rings and spokes
local function tree(parent)
	local row = placed("GreatSakura")[1]
	if not row then
		return
	end
	local m = Instance.new("Model")
	m.Name = "HoloTree"
	local x, z = row.Pos.X, row.Pos.Z
	local pedestal = Part(
		m,
		"Pedestal",
		Vector3.new(3, 16, 16),
		CFrame.new(x, TOP + 1.5, z) * CFrame.Angles(0, 0, math.pi / 2),
		C.Steel,
		Enum.Material.Metal,
		true
	)
	pedestal.Shape = Enum.PartType.Cylinder
	CyberPlaza.Ring(m, "PedestalTrim", CFrame.new(x, TOP + 3, z) * CFrame.Angles(math.pi / 2, 0, 0), 8, 0.3, C.Cyan, 16)
	local trunk = Neon(m, "Trunk", Vector3.new(1.4, 36, 1.4), CFrame.new(x, TOP + 3 + 18, z), C.Cyan)
	trunk.CanCollide = true -- solid, like the old trunk
	local top = TOP + 3 + 36
	for k = 0, TREE_RINGS - 1 do
		local r = 22 - k * 2.4
		local y = TOP + 24 + k * 2.2
		CyberPlaza.Ring(
			m,
			"Ring",
			CFrame.new(x, y, z) * CFrame.Angles(math.pi / 2, 0, 0),
			r,
			0.35,
			k % 2 == 1 and C.Magenta or C.Cyan,
			20
		)
	end
	for k = 0, TREE_SPOKES - 1 do
		local a = k * 2 * math.pi / TREE_SPOKES
		local from, to = Vector3.new(x, top, z), Vector3.new(x + 22 * math.cos(a), TOP + 24, z + 22 * math.sin(a))
		Neon(m, "Spoke", Vector3.new(0.25, 0.25, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), C.Cyan)
	end
	local light = Instance.new("PointLight")
	light.Color = C.Cyan
	light.Brightness = 1.5
	light.Range = 30
	light.Shadows = false
	light.Parent = trunk
	m.Parent = parent
end

local function spawnPad(parent, spawnArea)
	local spawn = spawnArea:FindFirstChild("Spawn")
	if not spawn then
		return
	end
	spawn.Color = C.Steel
	spawn.Material = Enum.Material.Metal
	local s = spawn.Size.X / 2
	for k = 0, 3 do
		local side = CFrame.new(spawn.Position.X, TOP + 0.08, spawn.Position.Z) * CFrame.Angles(0, k * math.pi / 2, 0)
		Neon(parent, "SpawnEdge", Vector3.new(2 * s + 0.4, 0.1, 0.4), side * CFrame.new(0, 0, s), C.Cyan)
	end
end

function CyberLook.Build(parent, spawnArea)
	local folder = Instance.new("Folder")
	folder.Name = "Look"
	for _, spec in BUILDINGS do
		building(folder, spawnArea, spec)
	end
	drones(folder)
	task.wait()
	tree(folder)
	spawnPad(folder, spawnArea)
	folder.Parent = parent
end

return CyberLook
