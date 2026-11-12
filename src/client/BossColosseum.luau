--!nonstrict
-- The Elf Mage's colosseum (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"): an enclosed round room of ochre
-- stone, built on the client from engine primitives through Client/BossArenaView's kit, about 1,030 parts (hard cap 1,150), 60 a
-- frame. After the approved draft tools/blender/arena/build_colosseum.py (palette and heights), with its wall moved from 132 to
-- BossArenaConfig's WallRadius, 164, behind a walkway and low stands. The deck is the only solid part. Nothing between the lanes and
-- the wall stands higher than the running camera's eye (6 studs over the deck, out to radius 160) or nearer the centre than 160.5 at
-- that height, so the eye never sits inside a part. Wall pieces are flat chords: a piece's inner face is at 163.4 in its middle, so
-- the trims on it stand at 163.1 or nearer. ringFrame's local heights are from the deck. No images: the motif, frieze and inlay are pale parts. Sizes are placeholders.
local FLOOR_STEP, WALL_STEP = 6, 4 -- of Arena.Segments (144): 24 pieces a ring on the floor and stands, 36 on the wall
local DECK_THICK = 4
local LINE_WIDTH, LINE_THICK = 0.6, 0.1
local WALKWAY_WIDTH = 14
local STAND_TIERS, STAND_RISE = 3, 1.2 -- each tier's top over the deck: 1.2, 2.4, 3.6
local PILLAR_ANGLES = 8 -- at 22.5 + 45 k degrees, as the draft
local DOOR_ANGLES = { math.rad(90), math.rad(270) }
local DOME_BASE, DOME_RISE = 83, 60 -- the shell's spring and its height, over the deck
local TORCH_RANGE, TORCH_BRIGHTNESS = 24, 1.6

-- The draft's palette.
local H = {
	ochre = "9A6A45",
	ochre2 = "8A5C3C",
	ochreLo = "6E4A33",
	pale = "D9BE96",
	pale2 = "C7A57C",
	recess = "3E4150",
	frieze = "7A6466",
	floorA = "CDBFA6",
	floorB = "8C7A68",
	laneA = "B89A78",
	laneB = "AA8C6C",
	laneLine = "E2CFAE",
	walk = "A88763",
	bronze = "6E5634",
	gold = "C99A4A",
	iron = "2F2F33",
	iron2 = "5E5D62",
	iron3 = "1E1E22",
	dome = "2E2C35",
	dome2 = "3A3742",
	diamond = "D9BE96",
	stand = "8A5C3C",
	stand2 = "9A6A45",
}
local BossColosseum = {}

-- kit: Client/BossArenaView's { addPart, addRing, ringFrame, pace, look }. Arena: BossArenaConfig.For("boss_mage"), the colosseum's
-- numbers. Returns false if the build was cancelled.
function BossColosseum.Build(mine, kit, Arena)
	local addPart, addRing, ringFrame, pace, look = kit.addPart, kit.addRing, kit.ringFrame, kit.pace, kit.look
	local Sand, Plastic, Slate, Metal =
		Enum.Material.Sandstone, Enum.Material.SmoothPlastic, Enum.Material.Slate, Enum.Material.Metal
	local OCHRE, OCHRE2, OCHRE_LO = look(H.ochre, Sand), look(H.ochre2, Sand), look(H.ochreLo, Sand)
	local PALE, PALE2, RECESS = look(H.pale, Plastic), look(H.pale2, Plastic), look(H.recess, Plastic)
	local FRIEZE = look(H.frieze, Plastic) -- the band behind the diamonds
	local DIAMOND = look(H.diamond, Plastic)
	local FLOOR_A, FLOOR_B = look(H.floorA, Sand), look(H.floorB, Sand)
	local LANE_A, LANE_B, LINE, WALK =
		look(H.laneA, Sand), look(H.laneB, Sand), look(H.laneLine, Plastic), look(H.walk, Sand)
	local STAND, STAND2 = look(H.stand, Sand), look(H.stand2, Sand)
	local BRONZE, GOLD = look(H.bronze, Metal), look(H.gold, Plastic)
	local IRON, IRON2, IRON3 = look(H.iron, Metal), look(H.iron2, Metal), look(H.iron3, Metal)
	local DOME, DOME2 = look(H.dome, Slate), look(H.dome2, Slate)
	local RUBBLE, RUBBLE2 = look("A07A55", Sand), look("7D6047", Sand)
	local FLAME = look("FFB060", Enum.Material.Neon)

	local y, center = Arena.Y, Arena.Center
	local inner, width = Arena.InnerRadius, Arena.Width
	local outer, wall, wallTop = inner + width, Arena.WallRadius, Arena.WallHeight
	local laneWidth = width / Arena.Lanes
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X: this turn stands it on end

	-- The floor, walkway and stands --------------------------------------------------------------------------------------------
	local rings = {
		{ "Deck", inner + width / 2, width, DECK_THICK, y, LANE_A, nil, FLOOR_STEP },
		{ "Checker", inner / 2 + 5, inner - 30, 0.1, y + 0.08, FLOOR_B, FLOOR_A, FLOOR_STEP },
		{ "LaneLine0", inner + LINE_WIDTH / 2, LINE_WIDTH, LINE_THICK, y + LINE_THICK, LINE, nil, FLOOR_STEP },
		{ "Kerb", outer + 0.5, 1, 0.5, y + 0.5, PALE2, nil, FLOOR_STEP },
		{ "Walkway", outer + 1 + WALKWAY_WIDTH / 2, WALKWAY_WIDTH, 0.5, y + 0.5, WALK, nil, WALL_STEP },
	}
	for lane = 2, Arena.Lanes - 1, 2 do
		table.insert(
			rings,
			{ "Lane" .. lane, Arena.LaneRadius(lane), laneWidth, 0.05, y + 0.05, LANE_B, nil, FLOOR_STEP }
		)
	end
	for lane = 1, Arena.Lanes - 1 do
		local radius = inner + lane * laneWidth - LINE_WIDTH / 2
		table.insert(
			rings,
			{ "LaneLine" .. lane, radius, LINE_WIDTH, LINE_THICK, y + LINE_THICK, LINE, nil, FLOOR_STEP }
		)
	end
	local standFrom = outer + 1 + WALKWAY_WIDTH
	local standWidth = (wall - standFrom) / STAND_TIERS
	for tier = 1, STAND_TIERS do
		local top = y + STAND_RISE * tier
		local radius = standFrom + standWidth * (tier - 0.5)
		table.insert(rings, { "Stand", radius, standWidth, STAND_RISE * tier, top, tier % 2 == 1 and STAND or STAND2 })
		rings[#rings][8] = FLOOR_STEP
	end
	-- The wall's tiers, inner face at WallRadius; trims stand proud of it (the deepest, the pale band, to 162.4)
	for _, row in
		{
			{ "WallStone", wall + 2, 4, wallTop, y + wallTop, OCHRE },
			{ "WallDado", wall - 0.1, 1.6, 10, y + 10, OCHRE_LO },
			{ "PaleBand", wall - 0.4, 2.4, 3, y + 12, PALE },
			{ "Ledge", wall - 0.2, 2, 2.5, y + 47.5, PALE },
			{ "Recess", wall, 0.6, 8.5, y + 56, RECESS },
			{ "Frieze", wall - 0.1, 0.8, 8, y + 66, FRIEZE },
			{ "Cornice", wall - 0.8, 3.6, 4, y + wallTop, PALE2 },
			{ "DomeStep", wall - 3, 8, 7, y + wallTop + 7, DOME2 },
			{ "DomeStep", wall - 9, 10, 6, y + DOME_BASE, DOME },
		}
	do
		row[7], row[8] = nil, row[1] == "DomeStep" and FLOOR_STEP or WALL_STEP
		table.insert(rings, row)
	end
	for _, ring in rings do
		if not addRing(mine, table.unpack(ring, 1, 8)) then
			return false
		end
	end

	-- The centre: a disc of pale stone and a rayed bronze and gold medallion under her
	if not pace(mine) then
		return false
	end
	local function disc(name, top, height, r, style)
		return addPart(
			name,
			Vector3.new(height, 2 * r, 2 * r),
			CFrame.new(center.X, top - height / 2, center.Z) * upright,
			style,
			Enum.PartType.Cylinder
		)
	end
	disc("CentreFloor", y, DECK_THICK, inner, FLOOR_A)
	disc("Medallion", y + 0.15, 0.2, 20, BRONZE)
	disc("Medallion", y + 0.2, 0.2, 17.5, PALE2)
	disc("Medallion", y + 0.25, 0.2, 14, BRONZE)
	disc("Medallion", y + 0.4, 0.4, 4.5, GOLD)
	for k = 0, 7 do
		local a = k / 8 * 2 * math.pi
		local long = k % 2 == 0 and 14 or 10
		addPart("MedallionRay", Vector3.new(long, 0.1, 1.6), ringFrame(a) * CFrame.new(4.5 + long / 2, 0.3, 0), GOLD)
	end

	local rng = Random.new(11) -- the same broken dome for everyone

	-- The wall's frieze diamonds and the motif (a stem, a crossbar and a diamond head), clear of the pillars and doors -----------
	local pieces = Arena.Segments / WALL_STEP
	local function near(a, list, gap)
		for _, b in list do
			if math.abs((a - b + math.pi) % (2 * math.pi) - math.pi) < gap then
				return true
			end
		end
		return false
	end
	local pillars = {}
	for k = 0, PILLAR_ANGLES - 1 do
		table.insert(pillars, math.rad(22.5 + 360 / PILLAR_ANGLES * k))
	end
	local diamond = CFrame.Angles(math.pi / 4, 0, 0) -- a square turned on the wall's face (local X is outward)
	local free = {} -- piece index -> true where the motif stands
	for k = 0, pieces - 1 do
		local a = (k + 0.5) / pieces * 2 * math.pi
		free[k] = not near(a, pillars, math.rad(12)) and not near(a, DOOR_ANGLES, math.rad(20))
	end
	for k = 0, pieces - 1 do
		local a = (k + 0.5) / pieces * 2 * math.pi
		for _, half in { -0.25, 0.25 } do
			if not pace(mine) then
				return false
			end
			local at = ringFrame(a + half / pieces * 2 * math.pi)
			addPart("FriezeDiamond", Vector3.new(0.3, 4.2, 4.2), at * CFrame.new(wall - 1.4, 62, 0) * diamond, DIAMOND)
		end
		if free[k] then
			if not pace(mine) then
				return false
			end
			local at = ringFrame(a) * CFrame.new(wall - 0.9, 0, 0)
			addPart("Motif", Vector3.new(0.3, 22, 1.2), at * CFrame.new(0, 25, 0), PALE)
			addPart("Motif", Vector3.new(0.3, 1.2, 9), at * CFrame.new(0, 29, 0), PALE)
			addPart("Motif", Vector3.new(0.3, 8, 8), at * CFrame.new(0, 40, 0) * diamond, PALE)
		end
	end

	-- 8 relief pillars on the wall's face, each with a warm torch: 6 parts and the room's only standing lights ---------------
	for _, a in pillars do
		if not pace(mine) then
			return false
		end
		local at = ringFrame(a)
		addPart("PillarShaft", Vector3.new(3, 56, 13), at * CFrame.new(wall - 1.5, 28, 0), OCHRE2)
		addPart("PillarPlinth", Vector3.new(3.5, 11, 17), at * CFrame.new(wall - 1.75, 5.5, 0), PALE2)
		addPart(
			"PillarDisc",
			Vector3.new(0.8, 9.2, 9.2),
			at * CFrame.new(wall - 3.4, 16.5, 0),
			GOLD,
			Enum.PartType.Cylinder
		)
		addPart("PillarRelief", Vector3.new(0.6, 17, 8.6), at * CFrame.new(wall - 3.3, 37.5, 0), PALE)
		addPart("PillarCapital", Vector3.new(4.5, 9, 19), at * CFrame.new(wall - 2.25, 60.5, 0), PALE2)
		local torch = addPart("Torch", Vector3.new(1, 1.6, 1), at * CFrame.new(wall - 3.6, 25, 0), FLAME)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 90)
		light.Range = TORCH_RANGE
		light.Brightness = TORCH_BRIGHTNESS
		light.Shadows = false
		light.Parent = torch
	end

	-- 2 great doors: pale jambs and lintel, dark metal leaves with square panels: 10 parts each --------------------------------
	for _, a in DOOR_ANGLES do
		if not pace(mine) then
			return false
		end
		local at = ringFrame(a)
		for _, side in { -1, 1 } do
			addPart("DoorJamb", Vector3.new(3, 63, 5), at * CFrame.new(wall - 1.5, 31.5, side * 18), PALE2)
			addPart("DoorLeaf", Vector3.new(1.2, 59, 14.8), at * CFrame.new(wall - 1.4, 29.5, side * 7.5), IRON2)
			for _, h in { 14, 42 } do
				addPart("DoorPanel", Vector3.new(0.4, 12, 9), at * CFrame.new(wall - 2.2, h, side * 7.5), IRON3)
			end
		end
		addPart("DoorLintel", Vector3.new(3.5, 6, 42), at * CFrame.new(wall - 1.75, 62, 0), PALE)
		addPart("DoorSeam", Vector3.new(0.6, 59, 0.5), at * CFrame.new(wall - 2.1, 29.5, 0), IRON)
	end

	-- The broken dome: 3 rows of slabs on a squashed half-ellipse, an open, ragged top for her entrance, 8 ribs -------------
	local domeRadius = wall - 15
	local function domePoint(phi) -- local X (out) and Y (up, from the deck) of the shell at this elevation
		return domeRadius * math.cos(phi), DOME_BASE + DOME_RISE * math.sin(phi)
	end
	local function slab(name, a, p1, p2, thick, tangential, style)
		local x1, y1 = domePoint(p1)
		local x2, y2 = domePoint(p2)
		local along = Vector2.new(x2 - x1, y2 - y1)
		local tilt = math.atan2(along.Y, along.X) - math.pi / 2 -- turns local X to the shell's outward normal
		addPart(
			name,
			Vector3.new(thick, along.Magnitude + 0.5, tangential),
			ringFrame(a) * CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, 0) * CFrame.Angles(0, 0, tilt),
			style
		)
	end
	local rows = { { 0, 22.5, 16 }, { 22.5, 45, 16 }, { 45, 67.5, 12 } }
	for i, row in rows do
		local p1, p2, count = math.rad(row[1]), math.rad(row[2]), row[3]
		local tangential = 2 * domeRadius * math.cos(p1) * math.sin(math.pi / count) * 1.04
		for k = 0, count - 1 do
			if not pace(mine) then
				return false
			end
			-- Broken away: patches of the top row, and a few slabs lower down
			local gone = (i == 3 and rng:NextNumber() < 0.3) or (i == 2 and rng:NextNumber() < 0.08)
			if not gone then
				slab(
					"DomeShell",
					(k + 0.5) / count * 2 * math.pi,
					p1,
					p2,
					2,
					tangential,
					(k + i) % 2 == 0 and DOME or DOME2
				)
			end
		end
	end
	for _, a in pillars do
		for s = 0, 4 do
			if not pace(mine) then
				return false
			end
			local p1, p2 = math.rad(s * 15), math.rad((s + 1) * 15)
			local frame = ringFrame(a) * CFrame.new(-1.5, 0, 0)
			local x1, y1 = domePoint(p1)
			local x2, y2 = domePoint(p2)
			local from, to = frame * Vector3.new(x1, y1, 0), frame * Vector3.new(x2, y2, 0)
			addPart(
				"DomeRib",
				Vector3.new(3, 3, (to - from).Magnitude + 1),
				CFrame.lookAt((from + to) / 2, to),
				s % 2 == 0 and PALE2 or OCHRE2
			)
		end
	end

	-- Rubble: piles at the wall foot (no higher than the stands) and on the centre floor, clear of the lanes -------------------
	local piles = {}
	for _, d in { 40, 200, 320 } do
		table.insert(piles, { standFrom + 4, math.rad(d), 2.2 })
	end
	for _, d in { 20, 140, 260 } do
		table.insert(piles, { (20 + inner) / 2 + 1, math.rad(d), 4.5 })
	end
	for _, pile in piles do
		for _ = 1, 5 do
			if not pace(mine) then
				return false
			end
			local s = rng:NextNumber(1.2, pile[3])
			local r = pile[1] + rng:NextNumber(-3, 3)
			local at = ringFrame(pile[2] + rng:NextNumber(-5, 5) / r)
				* CFrame.new(r, s * 0.35, 0)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 2 * math.pi), 0)
			addPart(
				"Rubble",
				Vector3.new(s * rng:NextNumber(0.8, 1.4), s, s * rng:NextNumber(0.6, 1)),
				at,
				rng:NextNumber() < 0.5 and RUBBLE or RUBBLE2
			)
		end
	end
	return true
end

return BossColosseum
