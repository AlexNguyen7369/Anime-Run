--!nonstrict
-- Slice 3 of the enclosed dojo (design doc 4.24, owner 2026-11-10), in the hybrid look (4.24 "Hybrid look"): warm
-- wood and red lacquer buildings with tiled roofs, wired with neon trim and wall screens, over the economy wing's
-- stalls (the stalls do not move: each building wraps its stand-in, whose prompt stays); warm-lit drones over the
-- stone lanterns; the garden (grass beds and bushes at each Sakura spot: the Great Sakura's and more along the wall
-- and behind the wings, Server/PlazaDressing places the reviewed Sakura mesh on them); a stone spawn. Places come from
-- Shared/PlazaAssets (Layout C). The far silhouettes are client-local (Client/CyberPlaza). Sizes and colours are
-- proposed.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CyberPlaza = require(Shared:WaitForChild("CyberPlaza"))
local Layout = require(Shared:WaitForChild("PlazaAssets"))

local C = CyberPlaza.Colors
local Part, Neon, Light = CyberPlaza.Part, CyberPlaza.Neon, CyberPlaza.Light
local TOP = CyberPlaza.TOP

-- Stand-in name, its PlazaAssets key, width, front and back of the building from the stand-in's origin (studs), screen
-- trim colour (warm, one soft cyan and one soft pink accent). Each front stays behind its flat sign (PlazaAssets Signs)
-- and the Market's MarketSign mesh.
local BUILDINGS = {
	{ Name = "ShopStall", Key = "SHOPStall", Width = 14, Front = 4.5, Back = 6, Color = C.Cyan },
	{ Name = "PotionsStall", Key = "POTIONSStall", Width = 14, Front = 4.5, Back = 6, Color = C.Pink },
	{ Name = "Marketplace", Key = "MarketStall", Width = 22, Front = 3, Back = 6, Color = C.Gold },
	{ Name = "IndexBoard", Key = "IndexBoard", Width = 22, Front = 0.2, Back = 8, Color = C.Amber },
}
local BUILDING_HEIGHT = 14
local ROOF_RISE = 5
local DRONE_HEIGHT = 16 -- above the floor
-- Sakura spots: a canopy is about 41 across (PlazaAssets GreatSakura), so a spot keeps CANOPY clear of every Dojo plot,
-- plaza building, the path and the door, and SPACING from the next spot
local CANOPY = 21
local SPACING = 44
local WALL_BAND = NumberRange.new(-34, -27) -- signed distance from the wall's centre line: the canopy sits 3 off its trunk
local BEHIND_WING = 32 -- studs behind a wing building's front
local MAX_SPOTS = 10 -- besides the Great Sakura
local BED_RADIUS = 10

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
	local depth, cz = front + back, (back - front) / 2
	Part(m, "Body", Vector3.new(w, h, depth), f * CFrame.new(0, h / 2, cz), C.Wood, Enum.Material.WoodPlanks, true)
	-- Red lacquer pillars at the front corners and a lit paper window band
	for _, side in { -1, 1 } do
		Part(
			m,
			"Pillar",
			Vector3.new(1.2, h, 1.2),
			f * CFrame.new(side * (w / 2 - 0.3), h / 2, -front - 0.3),
			C.Lacquer,
			Enum.Material.SmoothPlastic
		)
	end
	local window = Neon(m, "Window", Vector3.new(w - 3, 3.6, 0.2), f * CFrame.new(0, 3.2, -front - 0.1), C.Paper)
	window.Transparency = 0.2
	Neon(m, "Ledge", Vector3.new(w - 2, 0.3, 0.6), f * CFrame.new(0, 5.15, -front - 0.3), spec.Color)
	-- The wall screen: a dark face in a gold frame, a soft glow of the stall's colour round it
	Part(
		m,
		"ScreenFrame",
		Vector3.new(w - 2, 5.4, 0.1),
		f * CFrame.new(0, 10.5, -front - 0.05),
		C.Gold,
		Enum.Material.Metal
	)
	Neon(m, "ScreenGlow", Vector3.new(w - 2.4, 4.6, 0.1), f * CFrame.new(0, 10.5, -front - 0.1), spec.Color)
	Part(m, "Screen", Vector3.new(w - 3, 4, 0.1), f * CFrame.new(0, 10.5, -front - 0.15), C.Screen)
	CyberPlaza.Roof(m, f * CFrame.new(0, 0, cz), w + 2, depth + 3, h, ROOF_RISE, spec.Color)
	-- The prompt part, when it stands out of the building's front (the Market counter), gets a wood look
	for _, d in standIn:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and f:PointToObjectSpace(d.Position).Z - d.Size.Z / 2 < -front then
			Part(m, "Counter", d.Size, d.CFrame, C.DarkWood, Enum.Material.WoodPlanks)
			Part(
				m,
				"CounterEdge",
				Vector3.new(d.Size.X, 0.2, 0.2),
				d.CFrame * CFrame.new(0, d.Size.Y / 2, -d.Size.Z / 2),
				C.Gold,
				Enum.Material.Metal
			)
		end
	end
	Light(m.Window, C.Amber, 1.5, 18)
	m.Parent = parent
end

-- Drones over the stone lanterns (Server/PlazaDressing places the reviewed lantern mesh below): a warm steel disc with
-- an amber light under it and a gold rim, bobbing on near clients (BiomeBob)
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
			C.Amber
		)
		lamp.Shape = Enum.PartType.Cylinder
		CyberPlaza.Ring(m, "Rim", at * CFrame.Angles(math.pi / 2, 0, 0), 2.2, 0.2, i % 4 == 0 and C.Pink or C.Gold, 12)
		Light(lamp, C.Amber, 1.2, 20)
		m.WorldPivot = at
		m:SetAttribute("BasePivot", at)
		m.Parent = parent
		CollectionService:AddTag(m, "BiomeBob")
	end
end

-- Plan distance from (x, z) to a part's or model's box, ignoring height.
local function boxDistance(x, z, cf, size)
	local p = cf:PointToObjectSpace(Vector3.new(x, cf.Position.Y, z))
	local dx, dz = math.max(math.abs(p.X) - size.X / 2, 0), math.max(math.abs(p.Z) - size.Z / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- The Sakura spots: the Great Sakura's row first, then spots behind the wings and along the wall, each kept clear
-- (CANOPY, SPACING) of everything that stands in the compound.
local function sakuraSpots(spawnArea)
	local boxes = {} -- { CFrame, Size }
	for _, child in spawnArea:GetChildren() do
		if child.Name ~= "Floor" then
			if child:IsA("Model") then
				table.insert(boxes, { child:GetBoundingBox() })
			elseif child:IsA("BasePart") then
				table.insert(boxes, { child.CFrame, child.Size })
			end
		end
	end
	local plots = Workspace:FindFirstChild("Workshops")
	for _, plot in plots and plots:GetChildren() or {} do
		local base = plot:FindFirstChild("Base")
		if base then
			table.insert(boxes, { base.CFrame, base.Size + Vector3.new(4, 0, 4) }) -- the Dojo's eaves
		end
	end
	for _, row in Layout.Placed do
		if row.Key ~= "SkyLoop" and row.Key ~= "MainPath" and row.Key ~= "SpawnMosaic" and row.Key ~= "GreatSakura" then
			table.insert(boxes, { CFrame.new(row.Pos), Vector3.new(8, 8, 8) })
		end
	end
	local pad = spawnArea:FindFirstChild("StartPad")
	local door = pad and CyberPlaza.DoorFrame(pad.Position)
	if door then
		table.insert(boxes, { door, Vector3.new(CyberPlaza.DOOR_WIDTH + 30, 1, 20) })
	end
	local axis = pad and Vector3.new(pad.Position.X, 0, pad.Position.Z)

	local spots = {}
	local function clear(x, z)
		if CyberPlaza.Distance(x, z) > WALL_BAND.Max then
			return false
		end
		for _, b in boxes do
			if boxDistance(x, z, b[1], b[2]) < CANOPY then
				return false
			end
		end
		if axis then -- the path (18 wide) from the spawn to the pad
			local t = math.clamp(Vector3.new(x, 0, z):Dot(axis.Unit), 0, axis.Magnitude)
			if (Vector3.new(x, 0, z) - axis.Unit * t).Magnitude < CANOPY + 9 then
				return false
			end
		end
		for _, s in spots do
			if (Vector2.new(x, z) - Vector2.new(s.X, s.Z)).Magnitude < SPACING then
				return false
			end
		end
		return true
	end
	local great = placed("GreatSakura")[1]
	if great then
		table.insert(spots, great.Pos)
	end
	local function try(x, z)
		if #spots < MAX_SPOTS + 1 and clear(x, z) then
			table.insert(spots, Vector3.new(x, great and great.Pos.Y or TOP, z))
		end
	end
	for _, key in { "SHOPStall", "IndexBoard", "MarketStall", "POTIONSStall" } do
		for _, row in placed(key) do
			local behind = row.Pos - row.Face * BEHIND_WING
			try(behind.X, behind.Z)
		end
	end
	-- Along the wall: a band of candidates, taken in turn round the compound's centre so they spread out
	local band = {}
	local lo, hi = CyberPlaza.CORNER_MIN, CyberPlaza.CORNER_MAX
	local centre = (lo + hi) / 2
	for x = lo.X - CyberPlaza.RADIUS, hi.X + CyberPlaza.RADIUS, 6 do
		for z = lo.Y - CyberPlaza.RADIUS, hi.Y + CyberPlaza.RADIUS, 6 do
			local d = CyberPlaza.Distance(x, z)
			if d >= WALL_BAND.Min and d <= WALL_BAND.Max then
				table.insert(band, { x, z, math.atan2(z - centre.Y, x - centre.X) })
			end
		end
	end
	table.sort(band, function(a, b)
		return a[3] < b[3]
	end)
	for _, c in band do
		try(c[1], c[2])
	end
	return spots
end

-- A grass bed (named SakuraBed, its centre the spot) ringed with dark wood, and bushes round it, one in flower.
local function garden(parent, spawnArea)
	local folder = Instance.new("Folder")
	folder.Name = "Garden"
	for i, spot in sakuraSpots(spawnArea) do
		local at = CFrame.new(spot.X, TOP, spot.Z)
		local rim = Part(
			folder,
			"BedRim",
			Vector3.new(0.3, 2 * BED_RADIUS + 1.2, 2 * BED_RADIUS + 1.2),
			at * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2),
			C.DarkWood,
			Enum.Material.Wood
		)
		rim.Shape = Enum.PartType.Cylinder
		local bed = Part(
			folder,
			"SakuraBed",
			Vector3.new(0.4, 2 * BED_RADIUS, 2 * BED_RADIUS),
			at * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			C.Grass,
			Enum.Material.Grass
		)
		bed.Shape = Enum.PartType.Cylinder
		for k = 0, 3 do
			local a = (k + i * 0.37) * math.pi / 2
			local r = 2.2 + (k % 2) * 0.8
			local bush = Part(
				folder,
				"Bush",
				Vector3.new(2 * r, 2 * r, 2 * r),
				at * CFrame.new(math.cos(a) * (BED_RADIUS - 3), r * 0.6, math.sin(a) * (BED_RADIUS - 3)),
				k == 0 and C.Blossom or C.Leaf,
				Enum.Material.Grass
			)
			bush.Shape = Enum.PartType.Ball
		end
	end
	folder.Parent = parent
end

local function spawnPad(parent, spawnArea)
	local spawn = spawnArea:FindFirstChild("Spawn")
	if not spawn then
		return
	end
	spawn.Color = C.Stone
	spawn.Material = Enum.Material.Cobblestone
	local s = spawn.Size.X / 2
	for k = 0, 3 do
		local side = CFrame.new(spawn.Position.X, TOP + 0.08, spawn.Position.Z) * CFrame.Angles(0, k * math.pi / 2, 0)
		Part(
			parent,
			"SpawnEdge",
			Vector3.new(2 * s + 0.4, 0.1, 0.4),
			side * CFrame.new(0, 0, s),
			C.Gold,
			Enum.Material.Metal
		)
	end
	-- The doorstep under the arch: warm wood, not the old red planks
	local pad = spawnArea:FindFirstChild("StartPad")
	if pad then
		pad.Color = C.Wood
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
	garden(folder, spawnArea)
	spawnPad(folder, spawnArea)
	folder.Parent = parent
end

return CyberLook
