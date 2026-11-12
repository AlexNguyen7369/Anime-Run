--!nonstrict
-- The Elf Mage's colosseum (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"): an enclosed round room of ochre
-- stone, built on the client from engine primitives through Client/BossArenaView's kit, about 1,030 parts (hard cap 1,150), 60 a
-- frame. After the approved draft tools/blender/arena/build_colosseum.py (palette and heights), with its wall moved from 132 to
-- BossArenaConfig's WallRadius, 164, behind a walkway and low stands. The deck is the only solid part. Nothing between the lanes and
-- the wall stands higher than the running camera's eye (6 studs over the deck, out to radius 160) or nearer the centre than 160.5 at
-- that height, so the eye never sits inside a part. Wall pieces are flat chords: a piece's inner face is at 163.4 in its middle, so
-- the trims on it stand at 163.1 or nearer. ringFrame's local heights are from the deck. No images: the motif, frieze and inlay are pale parts. Sizes are placeholders.
-- Dressing "vault" (design doc 4.37 "Third boss", BOSS_EVENT_SPEC "The Golden King", owner-approved pass 2 of
-- tools/blender/arena/build_vault.py): the same shell in grey-brown brick with round blind arches in the motif's slots, wall torches,
-- banners, gold doors, chests, a gold layer over the stands (their tint), urns, 6 gold mounds and a stepped dais with a gold heap at
-- the centre. It drops the motif (48 parts), the rubble (30) and the medallion (12) and adds 196: 16 arches x 4, 10 torches x 2,
-- 12 banners x 3, 8 bay chests x 3, 4 urns x 2, 6 mounds x 6 and the dais's 8, about 1,136 parts (at most 1,141 with the dome's
-- seeded gaps; the folder's PartCount attribute holds the measured number). Lanes, ring, walkway, wall radius and boss spot unchanged.
local FLOOR_STEP, WALL_STEP = 6, 4 -- of Arena.Segments (144): 24 pieces a ring on the floor and stands, 36 on the wall
local DECK_THICK = 4
local LINE_WIDTH, LINE_THICK = 0.6, 0.1
local WALKWAY_WIDTH = 14
local STAND_TIERS, STAND_RISE = 3, 1.2 -- each tier's top over the deck: 1.2, 2.4, 3.6
local PILLAR_ANGLES = 8 -- at 22.5 + 45 k degrees, as the draft
local DOOR_ANGLES = { math.rad(90), math.rad(270) }
local DOME_BASE, DOME_RISE = 83, 60 -- the shell's spring and its height, over the deck
local TORCH_RANGE, TORCH_BRIGHTNESS = 24, 1.6
local ARCH_HALF, ARCH_SPRING, ARCH_FOOT = 7.5, 27, 12.5 -- the vault's blind arch: half its opening, its springing line, its sill
local MOUND_TOP = 13 -- the centre heap's top over the deck, where The Golden King stands (proposed)
local MOUND_RADIUS, MOUND_ANGLE0 = 44, 30 -- the 6 inner mounds, on the checker inside the ring

-- The draft palettes: the colosseum's ochre, and build_vault.py's VAULT_PAL.
local PLAIN = {
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
local VAULT = {
	ochre = "6E645A",
	ochre2 = "625850",
	ochreLo = "4E463E",
	pale = "9A9084",
	pale2 = "857B70",
	recess = "2A2420",
	frieze = "3E2A1C",
	floorA = "A49A8C",
	floorB = "6A6058",
	laneA = "8E8476",
	laneB = "80766A",
	laneLine = "C4BAAA",
	walk = "6E665C",
	bronze = "8A6A34",
	gold = "E2B347",
	iron = "A07E2A",
	iron2 = "C49A34",
	iron3 = "7A5C1C",
	dome = "201A16",
	dome2 = "2A2420",
	diamond = "E2B347",
	stand = "FFD25A",
	stand2 = "E2B347",
	gold2 = "B8862A",
	goldHi = "F6D878",
	goldMound = "FFD25A",
	banner = "5A3A22",
	torchIron = "2A2626",
	steel = "C9CCD2",
	hilt = "5A3A22",
	chest = "6A3A20",
	gemR = "D02838",
	gemB = "2A62D8",
}

local BossColosseum = {}
BossColosseum.VaultMoundTop = MOUND_TOP

-- kit: Client/BossArenaView's { addPart, addRing, ringFrame, pace, look }. Arena: the standing boss's BossArenaConfig.For row (the
-- colosseum's numbers), whose Dressing is "colosseum" (the ochre room) or "vault". Returns false if the build was cancelled.
function BossColosseum.Build(mine, kit, Arena)
	local addPart, addRing, ringFrame, pace, look = kit.addPart, kit.addRing, kit.ringFrame, kit.pace, kit.look
	local vault = Arena.Dressing == "vault"
	local H = vault and VAULT or PLAIN
	local Sand, Plastic, Slate, Metal =
		Enum.Material.Sandstone, Enum.Material.SmoothPlastic, Enum.Material.Slate, Enum.Material.Metal
	local OCHRE, OCHRE2, OCHRE_LO = look(H.ochre, Sand), look(H.ochre2, Sand), look(H.ochreLo, Sand)
	local PALE, PALE2, RECESS = look(H.pale, Plastic), look(H.pale2, Plastic), look(H.recess, Plastic)
	local FRIEZE = look(H.frieze, Plastic) -- the band behind the diamonds
	local DIAMOND = look(H.diamond, Plastic)
	local FLOOR_A, FLOOR_B = look(H.floorA, Sand), look(H.floorB, Sand)
	local LANE_A, LANE_B, LINE, WALK =
		look(H.laneA, Sand), look(H.laneB, Sand), look(H.laneLine, Plastic), look(H.walk, Sand)
	local STAND, STAND2 = look(H.stand, vault and Metal or Sand), look(H.stand2, vault and Metal or Sand)
	local BRONZE, GOLD = look(H.bronze, Metal), look(H.gold, Plastic)
	local IRON, IRON2, IRON3 = look(H.iron, Metal), look(H.iron2, Metal), look(H.iron3, Metal)
	local DOME, DOME2 = look(H.dome, Slate), look(H.dome2, Slate)
	local RUBBLE, RUBBLE2 = look("A07A55", Sand), look("7D6047", Sand)
	local FLAME = look("FFB060", Enum.Material.Neon)

	-- The vault's room is dark (BiomeEnvironment's VAULT profile): its torches carry the light, so they reach further and brighter.
	local torchRange, torchBrightness = vault and 70 or TORCH_RANGE, vault and 3.5 or TORCH_BRIGHTNESS
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

	-- The centre: a disc of pale stone and a rayed bronze and gold medallion under her (the vault's dais covers the medallion)
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
	if not vault then
		disc("Medallion", y + 0.15, 0.2, 20, BRONZE)
		disc("Medallion", y + 0.2, 0.2, 17.5, PALE2)
		disc("Medallion", y + 0.25, 0.2, 14, BRONZE)
		disc("Medallion", y + 0.4, 0.4, 4.5, GOLD)
		for k = 0, 7 do
			local a = k / 8 * 2 * math.pi
			local long = k % 2 == 0 and 14 or 10
			addPart(
				"MedallionRay",
				Vector3.new(long, 0.1, 1.6),
				ringFrame(a) * CFrame.new(4.5 + long / 2, 0.3, 0),
				GOLD
			)
		end
	end

	-- The vault's props: a squashed gold ball, an open chest, a gem, an urn, a leaning sword or spear ---------------------------
	local rng = Random.new(11) -- the same broken dome (and the same treasure) for everyone
	local function heap(name, at, r, height)
		local part = addPart(name, Vector3.new(2 * r, height, 2 * r), at, look(H.goldMound, Metal))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		return part
	end
	-- Only the vault palette has these keys; the plain colosseum never builds these props (look(nil) would throw).
	local function vlook(hex, material)
		return hex and look(hex, material) or nil
	end
	local CHEST, GOLD_HI, GOLD2 = vlook(H.chest, Enum.Material.Wood), vlook(H.goldHi, Metal), vlook(H.gold2, Metal)
	local STEEL, HILT = vlook(H.steel, Metal), vlook(H.hilt, Enum.Material.Wood)
	local GEMS = { vlook(H.gemR, Enum.Material.Glass), vlook(H.gemB, Enum.Material.Glass) }
	local TORCH_IRON, BANNER = vlook(H.torchIron, Metal), vlook(H.banner, Enum.Material.Fabric)
	-- at: the chest's base centre, local Z its width. The open lid leans back over the gold inside (the body's top face).
	local function chest(at, withGem)
		addPart("Chest", Vector3.new(2.2, 1.8, 3.2), at * CFrame.new(0, 0.9, 0), CHEST)
		addPart(
			"ChestLid",
			Vector3.new(2.3, 0.5, 3.3),
			at * CFrame.new(1.7, 2.8, 0) * CFrame.Angles(0, 0, 1.05),
			GOLD_HI
		)
		if withGem then
			addPart(
				"Gem",
				Vector3.new(0.9, 0.9, 0.9),
				at * CFrame.new(-1.8, 0.45, 0.8) * CFrame.Angles(0.8, 0.6, 0),
				GEMS[rng:NextInteger(1, 2)]
			)
		end
	end
	-- at: the urn's base centre. Narrow, so a door urn's inner face stays past 160.5 (the eye rule) half-sunk in the wall.
	local function urn(at, scale)
		addPart(
			"Urn",
			Vector3.new(3.8, 2.6, 2.6) * scale,
			at * CFrame.new(0, 1.9 * scale, 0) * upright,
			GOLD2,
			Enum.PartType.Cylinder
		)
		addPart(
			"UrnNeck",
			Vector3.new(1.3, 2.2, 2.2) * scale,
			at * CFrame.new(0, 4.45 * scale, 0) * upright,
			GOLD,
			Enum.PartType.Cylinder
		)
	end
	-- One part each: a sword's blade stuck point-down, or a spear's shaft, leaning tilt radians toward the frame's X.
	local function weapon(at, tilt, spear, scale)
		local long = (spear and 14 or 7) * scale
		local lean = at * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0) * CFrame.Angles(0, 0, tilt)
		addPart(
			spear and "Spear" or "Sword",
			Vector3.new(spear and 0.45 or 1.3, long, 0.35) * scale,
			lean * CFrame.new(0, long / 2 - 1, 0),
			spear and HILT or STEEL
		)
	end

	-- The wall's frieze diamonds and the motif (a stem, a crossbar and a diamond head), clear of the pillars and doors -----------
	-- In the vault the motif's slots take round blind arches: 2 short columns, a dark recess and a disc whose top half is the head.
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
	local free = {} -- piece index -> true where the motif or an arch stands
	for k = 0, pieces - 1 do
		local a = (k + 0.5) / pieces * 2 * math.pi
		free[k] = not near(a, pillars, math.rad(12)) and not near(a, DOOR_ANGLES, math.rad(20))
	end
	local arches = 0
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
			if vault then
				arches += 1
				local span = 2 * ARCH_HALF
				addPart(
					"ArchRecess",
					Vector3.new(0.3, ARCH_SPRING - ARCH_FOOT, span),
					at * CFrame.new(0, (ARCH_SPRING + ARCH_FOOT) / 2, 0),
					RECESS
				)
				addPart(
					"ArchHead",
					Vector3.new(0.3, span, span),
					at * CFrame.new(0, ARCH_SPRING, 0),
					RECESS,
					Enum.PartType.Cylinder
				)
				for _, side in { -1, 1 } do
					addPart(
						"ArchColumn",
						Vector3.new(ARCH_SPRING - ARCH_FOOT + 0.3, 2.8, 2.8),
						at * CFrame.new(-0.1, (ARCH_SPRING + ARCH_FOOT) / 2 - 0.15, side * (ARCH_HALF + 1.3)) * upright,
						PALE,
						Enum.PartType.Cylinder
					)
				end
				if arches % 2 == 0 then -- an open chest at the wall foot of every other bay, inner face past 160.5
					chest(ringFrame(a) * CFrame.new(wall - 1.7, STAND_RISE * STAND_TIERS, 0), true)
				end
			else
				addPart("Motif", Vector3.new(0.3, 22, 1.2), at * CFrame.new(0, 25, 0), PALE)
				addPart("Motif", Vector3.new(0.3, 1.2, 9), at * CFrame.new(0, 29, 0), PALE)
				addPart("Motif", Vector3.new(0.3, 8, 8), at * CFrame.new(0, 40, 0) * diamond, PALE)
			end
		end
	end

	-- Vault: torches on the boundaries between two arches, banners on the boundary where a run of arches ends -------------------
	if vault then
		for k = 0, pieces - 1 do
			if not pace(mine) then
				return false
			end
			local nextFree = free[(k + 1) % pieces]
			local boundary = (k + 1) / pieces * 2 * math.pi
			if free[k] and nextFree then
				local at = ringFrame(boundary)
				addPart("TorchBracket", Vector3.new(2.4, 3.6, 1), at * CFrame.new(wall - 1.9, 24.2, 0), TORCH_IRON)
				local torch =
					addPart("WallTorch", Vector3.new(1.2, 1.6, 1.2), at * CFrame.new(wall - 2.6, 26.6, 0), FLAME)
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 158, 64)
				light.Range = torchRange
				light.Brightness = torchBrightness
				light.Shadows = false
				light.Parent = torch
			elseif free[k] ~= nextFree then
				-- 1.5 degrees away from the arch, toward the pillar's or door's clear wall
				local at = ringFrame(boundary + (free[k] and 1 or -1) * math.rad(1.5))
				addPart("BannerBoard", Vector3.new(0.4, 26, 8.8), at * CFrame.new(wall - 0.5, 31, 0), GOLD2)
				addPart("Banner", Vector3.new(0.4, 24.6, 7.6), at * CFrame.new(wall - 0.8, 31.7, 0), BANNER)
				addPart("BannerEmblem", Vector3.new(0.4, 3.4, 3.4), at * CFrame.new(wall - 1.1, 33, 0) * diamond, GOLD)
			end
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
		light.Range = torchRange
		light.Brightness = torchBrightness
		light.Shadows = false
		light.Parent = torch
	end

	-- 2 great doors: pale jambs and lintel, dark metal leaves with square panels (gold in the vault): 10 parts each ------------
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
			if vault then -- a tall gold urn at each side of the door, on the stands
				urn(ringFrame(a + side * 24 / wall) * CFrame.new(wall - 1.3, STAND_RISE * STAND_TIERS, 0), 1.6)
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

	if vault then
		-- The vault's own props below are grouped in a Folder "Vault" once built (the shell's parts stay flat under the folder).
		local shell = {}
		for _, child in mine:GetChildren() do
			shell[child] = true
		end
		-- The centre: a round stepped stone dais with the gold heap he stands on, a chest and two swords in it ------------------
		if not pace(mine) then
			return false
		end
		disc("DaisStep", y + 2.4, 2.4, 27, PALE)
		disc("DaisStep", y + 4.8, 2.4, 22, PALE2)
		local goldHeap = heap("GoldHeap", CFrame.new(center.X, y + MOUND_TOP - 8, center.Z), 19, 16)
		local glow = Instance.new("PointLight") -- the heap's warm glow: he and the centre read in the dark room
		glow.Color, glow.Range, glow.Brightness, glow.Shadows = Color3.fromRGB(255, 200, 110), 80, 1.5, false
		glow.Parent = goldHeap
		chest(ringFrame(math.rad(30)) * CFrame.new(13, 10.5, 0), true)
		weapon(ringFrame(math.rad(195)) * CFrame.new(14, 9.5, 0), 0.35, false, 1.3)
		weapon(ringFrame(math.rad(320)) * CFrame.new(15.5, 8.5, 0), -0.3, false, 1.2)
		-- 6 gold mounds on the checker inside the ring: a heap, an urn, a sword, a spear and an open chest each ---------------
		for i = 0, 5 do
			if not pace(mine) then
				return false
			end
			local a = math.rad(MOUND_ANGLE0 + 60 * i)
			local at = ringFrame(a)
			heap("GoldMound", at * CFrame.new(MOUND_RADIUS, 0.5, 0), 8.5, 7.2)
			addPart(
				"Urn",
				Vector3.new(4.9, 4.2, 4.2),
				at * CFrame.new(MOUND_RADIUS + 3, 3.4, 4) * upright,
				GOLD2,
				Enum.PartType.Cylinder
			)
			weapon(
				at * CFrame.new(MOUND_RADIUS + 3, 1.2, -4),
				rng:NextNumber(0.15, 0.45),
				false,
				rng:NextNumber(0.9, 1.3)
			)
			weapon(
				at * CFrame.new(MOUND_RADIUS - 3, 1.2, 2),
				rng:NextNumber(0.15, 0.45),
				true,
				rng:NextNumber(0.9, 1.2)
			)
			chest(at * CFrame.new(MOUND_RADIUS - 2.5, 1.8, -9) * CFrame.Angles(0, a + 1.2, 0), false)
		end
		local group = Instance.new("Folder")
		group.Name = "Vault"
		local count = 0
		for _, child in mine:GetChildren() do
			if child:IsA("BasePart") then
				count += 1
				if not shell[child] then
					child.Parent = group
				end
			end
		end
		group.Parent = mine
		mine:SetAttribute("PartCount", count) -- the measured number, for the Studio verify
		return true
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
