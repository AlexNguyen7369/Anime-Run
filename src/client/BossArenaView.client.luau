--!nonstrict
-- The boss sky arena (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Arena"). Client-only: the diameter exceeds the streaming
-- target. Marble and gold parts from BossArenaConfig, matching tools/blender/arena/build_arena.py's approved draft, over a
-- cloud deck; the sky is the arena zone of Client/BiomeEnvironment. Engine primitives only, no uploaded meshes. Built while
-- this player is in an event (player attribute BossEvent), or while the test attribute BossArenaPreview is on.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("BossArenaConfig"))
local SidekickArt = require(Shared:WaitForChild("SidekickArt"))

local ATTRIBUTE = "BossArenaPreview"
local PARTS_PER_FRAME = 60 -- about 1,650 parts, so about 28 frames
-- Every second ring point: 72 pieces of about 78 studs on each ring. The draft's 144 would be about 1,200 more parts.
local RING_STEP = 2
-- Placeholder sizes, all studs. Heights and radii not named here are the draft's.
local DECK_THICK = 8
local LINE_WIDTH, LINE_THICK = 1, 0.1
local BOSS_WIDTH, BOSS_DEPTH = 200, 120 -- a stand-in for the height only
local WHEEL_THICK = 30
local ARCH_COUNT, ARCH_START, SECTOR = 6, math.rad(15), math.rad(60) -- the draft's ARCH_START and SECTOR
local ARCH_PIECES = 8 -- the draft's 12, for phones
local BAY_OFFSETS = { math.rad(20), math.rad(40) } -- colonnade bays after each arch
local BAY_HALF, BAY_COLUMNS, BAY_HEIGHT = math.rad(8), 7, 62 -- the draft's 13 columns, for phones
local CLOUD_Y = Cfg.Y - 720 -- the draft's cloud sea
local TILE, TILES = 2040, 3 -- deck slabs: 2048 is the largest part; a 7 x 7 grid, the edge fades into the Atmosphere
local PUFFS, WISPS = 60, 12

local function look(hex, material, shadow)
	return { Color = Color3.fromHex(hex), Material = material, Shadow = shadow == true }
end
local Marble, Plastic = Enum.Material.Marble, Enum.Material.SmoothPlastic
-- The draft's palette
local MARBLE = look("F3EFE6", Marble, true)
local MARBLE2 = look("E6DFCF", Marble)
local MARBLE3 = look("DDD6C8", Marble)
local LANE_A, LANE_A2 = look("F7F3EA", Marble), look("EEE8DB", Marble)
local LANE_B, LANE_B2 = look("DCD5C6", Marble), look("D2CBBA", Marble)
local GOLD, GOLD2 = look("E8B23C", Plastic), look("C9922B", Plastic)
local CLOUD, CLOUD2 = look("FFFFFF", Plastic), look("EAF1FA", Plastic)
local GREY = look("969696", Plastic, true)

local folder = nil -- the built arena, nil when off
local added = 0

-- Call before each stretch of parts: yields every PARTS_PER_FRAME. False once the build was cancelled.
local function pace(mine)
	if added >= PARTS_PER_FRAME then
		added = 0
		task.wait()
	end
	return folder == mine
end

local function addPart(name, size, cframe, style, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanTouch = false
	-- Only the deck is solid, so that the camera stops at it and an arch passing never pops the camera in.
	part.CanCollide = name == "Deck"
	part.CanQuery = name == "Deck"
	part.CastShadow = style.Shadow
	part.Material = style.Material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = style.Color
	part.Parent = folder
	added += 1
	return part
end

-- A ring of straight pieces, each as long as the chord at the outer edge so the ring has no gaps. With style2 the pieces
-- alternate, as the draft's lanes do; those stand a hair higher because neighbours overlap at their inner corners.
-- Returns false if the build was cancelled.
local function addRing(mine, name, radius, width, height, top, style, style2)
	local length = (Cfg.RingPoint(radius + width / 2, 0) - Cfg.RingPoint(radius + width / 2, RING_STEP)).Magnitude
	for k = 0, Cfg.Segments / RING_STEP - 1 do
		if not pace(mine) then
			return false
		end
		local other = style2 ~= nil and k % 2 == 1
		local y = top - height / 2 + (other and 0.02 or 0)
		local a, b = Cfg.RingPoint(radius, k * RING_STEP, y), Cfg.RingPoint(radius, (k + 1) * RING_STEP, y)
		addPart(name, Vector3.new(width, height, length), CFrame.lookAt((a + b) / 2, b), other and style2 or style)
	end
	return true
end

-- Local axes around a ring angle: X outward, Y up, Z along the ring. Same turning sense as Cfg.RingPoint.
local function ringFrame(angle)
	return CFrame.new(Cfg.Center) * CFrame.Angles(0, angle, 0)
end

-- A triumphal arch over all 7 lanes: 23 parts.
local function addArch(angle)
	local frame = ringFrame(angle)
	local inner, outer = Cfg.InnerRadius - 8, Cfg.InnerRadius + Cfg.Width + 16
	local middle, span = (inner + outer) / 2, (outer - inner) / 2
	local spring = 70
	for _, r in { inner, outer } do
		addPart("ArchPylon", Vector3.new(16, 100, 26), frame * CFrame.new(r, 20, 0), MARBLE)
		addPart("ArchTrim", Vector3.new(20, 5, 30), frame * CFrame.new(r, 2.5, 0), GOLD)
		addPart("ArchTrim", Vector3.new(20, 5, 30), frame * CFrame.new(r, spring + 2.5, 0), GOLD)
	end
	local function point(k)
		local a = k / ARCH_PIECES * math.pi
		return Vector3.new(middle - span * math.cos(a), spring + 5 + span * math.sin(a) * 0.85, 0)
	end
	for k = 0, ARCH_PIECES - 1 do
		local p, q = point(k), point(k + 1)
		local length = (q - p).Magnitude
		addPart("ArchRib", Vector3.new(15, 15, length), frame * CFrame.lookAt((p + q) / 2, q), MARBLE2)
		local lift = Vector3.new(0, 8, 0)
		addPart("ArchTrim", Vector3.new(5, 5, length), frame * CFrame.lookAt((p + q) / 2 + lift, q + lift), GOLD)
	end
	addPart("ArchKey", Vector3.new(13, 22, 20), frame * CFrame.new(middle, point(ARCH_PIECES / 2).Y + 3, 0), GOLD)
end

-- A stretch of columns on the outer plinth with a marble and gold cornice: 13 parts.
local function addBay(angle)
	local radius = Cfg.InnerRadius + Cfg.Width + 18
	local base = 3
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X
	for k = 0, BAY_COLUMNS - 1 do
		local at = ringFrame(angle - BAY_HALF + 2 * BAY_HALF * k / (BAY_COLUMNS - 1))
		local column = Vector3.new(BAY_HEIGHT, 7, 7)
		addPart(
			"Column",
			column,
			at * CFrame.new(radius, base + BAY_HEIGHT / 2, 0) * upright,
			MARBLE,
			Enum.PartType.Cylinder
		)
	end
	local top = base + BAY_HEIGHT
	local third = BAY_HALF * 2 / 3
	local length = 2 * radius * math.tan(third / 2)
	for k = -1, 1 do
		local at = ringFrame(angle + k * third)
		addPart("Cornice", Vector3.new(14, 8, length), at * CFrame.new(radius, top + 4, 0), MARBLE2)
		addPart("CorniceTrim", Vector3.new(18, 3, length), at * CFrame.new(radius, top + 9.5, 0), GOLD)
	end
end

local function addDais()
	local y, center = Cfg.Y, Cfg.Center
	local radius = Cfg.DaisRadius
	local function drum(name, top, height, r, style)
		-- A cylinder's axis is its X: this turn stands it on end.
		local cf = CFrame.new(center.X, top - height / 2, center.Z) * CFrame.Angles(0, 0, math.pi / 2)
		addPart(name, Vector3.new(height, 2 * r, 2 * r), cf, style, Enum.PartType.Cylinder)
	end
	drum("Dais", y, 14, radius, MARBLE)
	drum("DaisTrim", y - 14, 6, radius + 15, GOLD)
	drum("DaisDrum", y - 20, 40, radius + 15, MARBLE2)
	drum("DaisStem", y - 60, 60, 40, GOLD2)
end

-- Placeholder for the boss's own pre-rendered frames, which replace this image when they exist. Parts this far off do not
-- draw at low graphics quality but a billboard does (spec "Low graphics"). The offset is along the view line, so it stays
-- behind the stand-in from every side, and the depth test (AlwaysOnTop off) lets the model hide it and keeps it off the
-- track and runners. Stretched to the stand-in's shape, since a wider image would show around the model at high quality.
local function addBillboard(standIn)
	local gui = Instance.new("BillboardGui")
	gui.Name = "LowGraphicsBoss"
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Size = UDim2.fromScale(BOSS_WIDTH, Cfg.BossHeight) -- a billboard's scale is in studs
	gui.StudsOffset = Vector3.new(0, 0, -(Vector2.new(BOSS_WIDTH, BOSS_DEPTH).Magnitude / 2 + 10))
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = SidekickArt.side_raga.Portrait
	image.ScaleType = Enum.ScaleType.Stretch
	image.Parent = gui
	gui.Parent = standIn
end

-- A flattened sphere, an engine primitive.
local function addPuff(x, y, z, radius, style)
	local part = addPart("Cloud", Vector3.new(2 * radius, 0.9 * radius, 2 * radius), CFrame.new(x, y, z), style)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

-- Slabs hide the terrain below, puffs break up their flat top, and wisps under the ring make it read as floating.
-- Returns false if the build was cancelled.
local function addClouds(mine)
	local center = Cfg.Center
	for ix = -TILES, TILES do
		for iz = -TILES, TILES do
			if not pace(mine) then
				return false
			end
			local at = CFrame.new(center.X + ix * TILE, CLOUD_Y - 10, center.Z + iz * TILE)
			addPart("CloudDeck", Vector3.new(2048, 20, 2048), at, CLOUD2)
		end
	end
	local rng = Random.new(7) -- the same sky for everyone
	local function polar(min, max)
		local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(min, max)
		return center.X + r * math.cos(a), center.Z + r * math.sin(a), r
	end
	for _ = 1, PUFFS do
		if not pace(mine) then
			return false
		end
		local x, z, r = polar(300, 6500)
		local size = rng:NextNumber(130, 340) * (1 + r / 8000)
		addPuff(x, CLOUD_Y + size * 0.1, z, size, CLOUD)
	end
	for _ = 1, WISPS do
		if not pace(mine) then
			return false
		end
		local x, z = polar(760, 1120)
		addPuff(x, Cfg.Y - rng:NextNumber(130, 260), z, rng:NextNumber(50, 110), CLOUD2)
	end
	return true
end

local function build(mine)
	local y, center = Cfg.Y, Cfg.Center
	local inner, width = Cfg.InnerRadius, Cfg.Width
	local outer = inner + width
	local laneWidth = width / Cfg.Lanes
	local rings = {
		{ "Deck", inner + width / 2, width, DECK_THICK, y, LANE_A, LANE_A2 },
		{ "RailInner", inner - 3, 6, 3, y + 2.5, MARBLE3 },
		{ "RailInnerTrim", inner - 1, 2, 0.2, y + 2.6, GOLD },
		{ "RailOuter", outer + 3, 6, 6, y + 5, MARBLE3 },
		{ "RailOuterTrim", outer + 1, 2, 0.2, y + 5.1, GOLD },
		{ "Plinth", outer + 18, 24, 7, y + 3, MARBLE2 },
		{ "Hull", inner + width / 2 + 12, width + 36, 40, y - 8, MARBLE2 },
		{ "HullTrim", inner + width / 2 + 12, width + 40, 4, y - 4, GOLD },
	}
	for lane = 2, Cfg.Lanes - 1, 2 do
		table.insert(rings, { "Lane" .. lane, Cfg.LaneRadius(lane), laneWidth, 0.05, y + 0.05, LANE_B, LANE_B2 })
	end
	for lane = 1, Cfg.Lanes - 1 do
		local radius = inner + lane * laneWidth - LINE_WIDTH / 2
		table.insert(rings, { "LaneLine" .. lane, radius, LINE_WIDTH, LINE_THICK, y + LINE_THICK, GOLD })
	end
	for _, ring in rings do
		if not addRing(mine, table.unpack(ring)) then
			return
		end
	end
	for k = 0, ARCH_COUNT - 1 do
		local angle = ARCH_START + SECTOR * k
		if not pace(mine) then
			return
		end
		addArch(angle)
		for _, offset in BAY_OFFSETS do
			if not pace(mine) then
				return
			end
			addBay(angle + offset)
		end
	end
	if not pace(mine) then
		return
	end
	addDais()
	if not addClouds(mine) then
		return
	end
	if not pace(mine) then
		return
	end
	local body = Vector3.new(BOSS_WIDTH, Cfg.BossHeight, BOSS_DEPTH)
	local standIn = addPart("BossStandIn", body, CFrame.new(center.X, y + Cfg.BossHeight / 2, center.Z), GREY)
	addBillboard(standIn)
	local wheelY = y + Cfg.BossHeight + Cfg.BossWheelHeight / 2
	local wheel = Vector3.new(WHEEL_THICK, Cfg.BossWheelHeight, Cfg.BossWheelHeight)
	-- A cylinder's axis is its X, so the wheel keeps its axis horizontal, like the boss's.
	addPart("WheelStandIn", wheel, CFrame.new(center.X, wheelY, center.Z), GREY, Enum.PartType.Cylinder)
end

local function refresh()
	local want = ReplicatedStorage:GetAttribute(ATTRIBUTE) == true
		or Players.LocalPlayer:GetAttribute("BossEvent") == true
	if want == (folder ~= nil) then
		return
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	if want then
		local mine = Instance.new("Folder")
		mine.Name = "BossArenaPreview"
		mine.Parent = Workspace
		folder = mine
		build(mine)
	end
end

ReplicatedStorage:GetAttributeChangedSignal(ATTRIBUTE):Connect(refresh)
Players.LocalPlayer:GetAttributeChangedSignal("BossEvent"):Connect(refresh)
refresh()
