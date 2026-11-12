--!nonstrict
-- The Golden King's own arena (design doc 4.37 "The Golden King's own arena", "Rework approvals"; docs/BOSS_EVENT_SPEC.md
-- "Animation rework", bullet "The Golden King's arena"; owner 2026-11-12, replaces the vault re-dress of the colosseum): an open
-- sandstone stadium at sunset, built on the client from engine primitives through Client/BossArenaView's kit, 60 parts a frame. After
-- the approved draft tools/blender/arena/build_king_arena.py and its renders assets/arena_draft/KingArena_*.png (layout, heights and
-- palette): a paved floor with blue and gold bands, a podium wall of round arch bays holding gold, three tiers of stands (ramps) with
-- blue fronts and runners, a top arcade against the sky, a glazed gate between two crenellated towers flanked by two winged lions with
-- crowned heads, a stepped tower through the gate, 10 red banners with a gold winged sun between banded columns, 6 ruin groups inside
-- and 6 outside the lanes, and the centre mound of stone tiers buried in gold with treasure, where he hovers (BossArenaConfig
-- MoundTop, HoverY). Every part sits under a Folder "KingArena"; the mound's under its child "KingMound". About 1,190 parts
-- (target about 1,200, proposed; the folder's PartCount attribute holds the built number). Nothing stands on the lanes (the floor's
-- stacked discs stay under 0.3 over the deck), and inside the ring only the mound reaches above 12 studs. No images: the draft's
-- paving, masonry, glazed brick, meander and step textures are engine materials and parts here (their uploads would be the
-- per-boss late data BossKingArena). The arches are drawn with chamfered corners (two ramps each), not round. Sizes are proposed.
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local GATE = math.rad(90) -- the gate's angle on the ring (the draft's GATE_A)
local BAY = math.rad(9) -- podium and arcade bays: 40 round, the gate's two left open
local STAND = math.rad(18) -- stand pieces: 20 round, the gate's one left open
local POD_H = 20 -- the podium wall's top, its walk
local STAND_FROM, TIER_D, TIER_RISE, TIER_FRONT = 256, 22, 9.6, 6.4 -- each tier: a ramp, then a blue front under the next
local TOP_R, TOP_Z = 322, 68 -- the stands' top edge, where the arcade stands
local ARC_TOP = 106
local DISC_STEP = 0.018 -- the floor's stacked discs: 16 of them stay under 0.3 over the deck
local BANNER_DEG = { 27, 63, 99, 135, 171 } -- from the gate, both ways
local AISLE_DEG = { 45, 81, 117, 153, -45, -81, -117, -153, 180 }
local STAIR_DEG = { -17, 17, 163, 197 }
local LION_SCALE = 1.45

local BossKingArena = {}

-- kit: Client/BossArenaView's { addPart, ringFrame, pace, look }. Arena: BossArenaConfig.For("boss_king"). Returns false if the
-- build was cancelled.
function BossKingArena.Build(mine, kit, Arena)
	local addPart, ringFrame, pace, look = kit.addPart, kit.ringFrame, kit.pace, kit.look
	local Sandstone, Brick, Plastic, Metal =
		Enum.Material.Sandstone, Enum.Material.Brick, Enum.Material.SmoothPlastic, Enum.Material.Metal
	local Wood, Glass = Enum.Material.Wood, Enum.Material.Glass
	-- The draft's palette (build_king_arena.py PAL)
	local SAND, SAND2, SAND_LO, SAND_HI =
		look("D2A874", Sandstone), look("C49766", Sandstone), look("A87C52", Sandstone), look("E2BC88", Sandstone)
	local SAND_OUT, PAVE, MASONRY =
		look("C8955E", Sandstone), look("D9B88E", Enum.Material.Pavement), look("CFA170", Brick)
	local LANE_A, LANE_B, LINE = look("D8B88A", Sandstone), look("CBA97C", Sandstone), look("E9C35A", Plastic)
	local BLUE, GLAZED, RECESS = look("2C3C9C", Plastic), look("2C3C9C", Brick), look("3A2420", Plastic)
	local GOLD, GOLD_HI, GOLD_MOUND = look("E8B23C", Metal), look("FFD86A", Metal), look("FFC845", Metal)
	local BANNER, STEEL, RED = look("A41E2A", Enum.Material.Fabric), look("D4D6DC", Metal), look("C0141E", Plastic)
	local CHESTS = { look("7A3A1E", Wood), look("24307E", Wood), look("9A1E24", Wood) }
	local GEMS = { look("E0203A", Glass), look("2A62E8", Glass), look("22B05A", Glass) }
	local STATUE, STATUE_LO, ZIG, ZIG2 =
		look("D8A862", Sandstone), look("A8783C", Sandstone), look("D29A78", Sandstone), look("BA8466", Sandstone)

	local root = Instance.new("Folder")
	root.Name = "KingArena"
	root.Parent = mine
	local into, count = root, 0
	local function put(name, size, cf, style, shape)
		local part = addPart(name, size, cf, style, shape)
		part.Parent = into
		count += 1
		return part
	end

	local center = Arena.Center
	local rng = Random.new(31) -- the same ruins and treasure for everyone
	local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X: this turn stands it on end
	local OUT = CFrame.Angles(0, math.pi / 2, 0) -- a ramp's high side (local +Z) turned outward (ringFrame's X)
	-- ringFrame(a)'s axes: X outward, Y up from the deck, Z along the ring.
	local function at(a, x, y, z)
		return ringFrame(a) * CFrame.new(x, y, z or 0)
	end
	local function chord(r, angle)
		return 2 * r * math.sin(angle / 2)
	end
	-- A cylinder standing on base (its bottom centre).
	local function cyl(name, r, h, base, style)
		return put(
			name,
			Vector3.new(h, 2 * r, 2 * r),
			base * CFrame.new(0, h / 2, 0) * UPRIGHT,
			style,
			Enum.PartType.Cylinder
		)
	end
	local function ball(name, size, cf, style)
		local part = put(name, size, cf, style)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		return part
	end
	local function disc(name, r, top, style, thick)
		return cyl(name, r, thick, CFrame.new(center.X, center.Y + top - thick, center.Z), style)
	end
	-- A ramp rising outward from r1 to r2 at angle a: length along the ring.
	local function ramp(name, a, r1, r2, bottom, rise, length, style, z)
		return put(
			name,
			Vector3.new(length, rise, r2 - r1),
			at(a, (r1 + r2) / 2, bottom + rise / 2, z) * OUT,
			style,
			Enum.PartType.Wedge
		)
	end
	-- An opening's two upper corners, size d along the wall and h up, in a wall at cf (local X through the wall): the corner of
	-- the ramp's right angle is turned to the top outer corner, so the opening reads as an arch.
	local function haunches(name, cf, thick, h, d, half, top, style)
		put(
			name,
			Vector3.new(thick, h, d),
			cf * CFrame.new(0, top - h / 2, -half + d / 2) * CFrame.Angles(math.pi, 0, 0),
			style,
			Enum.PartType.Wedge
		)
		put(
			name,
			Vector3.new(thick, h, d),
			cf * CFrame.new(0, top - h / 2, half - d / 2) * CFrame.Angles(0, 0, math.pi),
			style,
			Enum.PartType.Wedge
		)
	end
	-- Flat chord pieces from r1 to r2 between two angles, each as long as the chord at r2 so the arc has no gaps.
	local function arc(name, r1, r2, top, thick, style, pieces, from, to)
		local step = (to - from) / pieces
		for k = 0, pieces - 1 do
			put(
				name,
				Vector3.new(r2 - r1, thick, chord(r2, step)),
				at(from + (k + 0.5) * step, (r1 + r2) / 2, top - thick / 2),
				style
			)
		end
	end

	-- Treasure, built at cf (a base centre, local Y up) ------------------------------------------------------------------------
	local function chest(cf, s, style) -- body, gold coin top, the lid tipped back: 3 parts
		put("Chest", Vector3.new(3.2, 1.8, 2.2) * s, cf * CFrame.new(0, 0.9 * s, 0), style)
		put("ChestGold", Vector3.new(2.9, 0.4, 1.9) * s, cf * CFrame.new(0, 1.85 * s, 0), GOLD_HI)
		put(
			"ChestLid",
			Vector3.new(3.3, 2.3, 0.5) * s,
			cf * CFrame.new(0, 2.85 * s, 1.35 * s) * CFrame.Angles(0.3, 0, 0),
			style
		)
	end
	local function gem(cf, s, k)
		put(
			"Gem",
			Vector3.one * 0.9 * s,
			cf * CFrame.new(0, 0.3 * s, 0) * CFrame.Angles(0.8, 0.6, 0),
			GEMS[(k - 1) % 3 + 1]
		)
	end
	local function shield(cf, r, tilt) -- standing on its rim, its face along local -X, leaning back: 2 parts
		local face = cf * CFrame.Angles(0, 0, tilt) * CFrame.new(0, r, 0)
		put("Shield", Vector3.new(0.6, 2 * r, 2 * r), face, GOLD, Enum.PartType.Cylinder)
		put(
			"ShieldFace",
			Vector3.new(0.2, 1.64 * r, 1.64 * r),
			face * CFrame.new(-0.35, 0, 0),
			BLUE,
			Enum.PartType.Cylinder
		)
	end
	local function crown(cf, s) -- 2 parts
		cyl("Crown", 1.8 * s, 1.2 * s, cf, GOLD)
		cyl("CrownCap", 1.55 * s, 1.3 * s, cf, RED)
	end
	local function goblet(cf, s) -- foot and stem, cup: 2 parts
		cyl("GobletStem", 0.6 * s, 1.6 * s, cf, GOLD)
		cyl("Goblet", 1.0 * s, 1.4 * s, cf * CFrame.new(0, 1.5 * s, 0), GOLD)
	end
	local function sword(cf, s, guard) -- a blade stuck point-down, leaning; with its guard: 2 parts
		local lean = cf
			* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
			* CFrame.Angles(0, 0, rng:NextNumber(0.2, 0.4))
		put("Sword", Vector3.new(1.3, 7, 0.35) * s, lean * CFrame.new(0, 2.5 * s, 0), STEEL)
		if guard then
			put("SwordGuard", Vector3.new(3, 0.5, 0.5) * s, lean * CFrame.new(0, 6 * s, 0), GOLD)
		end
	end
	local function trident(cf, s) -- shaft, crossbar, middle prong: 3 parts
		local lean = cf
			* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
			* CFrame.Angles(0, 0, rng:NextNumber(0.2, 0.35))
		put("Trident", Vector3.new(0.45, 13, 0.45) * s, lean * CFrame.new(0, 6.5 * s, 0), GOLD)
		put("TridentHead", Vector3.new(3.4, 0.5, 0.4) * s, lean * CFrame.new(0, 13.2 * s, 0), GOLD)
		put("TridentHead", Vector3.new(0.35, 3, 0.35) * s, lean * CFrame.new(0, 14.7 * s, 0), GOLD)
	end
	local function stump(cf, r, h) -- a broken column with a blue band: 3 parts
		put("StumpBase", Vector3.new(r * 2.4, 1.2, r * 2.4), cf * CFrame.new(0, 0.6, 0), SAND_LO)
		cyl("Stump", r, h, cf * CFrame.new(0, 1.2, 0), SAND)
		cyl("StumpBand", r + 0.2, 1.4, cf * CFrame.new(0, 1.2 + h * 0.62, 0), BLUE)
	end
	local function blocks(cf, n, small, big, spread)
		for _ = 1, n do
			local s = rng:NextNumber(small, big)
			local p = cf
				* CFrame.new(rng:NextNumber(-spread, spread), s * 0.38, rng:NextNumber(-spread, spread))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 2 * math.pi), 0)
			local style = ({ SAND, SAND2, SAND_LO })[rng:NextInteger(1, 3)]
			put("Block", Vector3.new(s * rng:NextNumber(0.9, 1.5), s, s * rng:NextNumber(0.6, 0.9)), p, style)
		end
	end

	-- The floor: the deck, the lanes as stacked discs (each lane line under the next lane in), the meander bands, the ground ------
	if not pace(mine) then
		return false
	end
	disc("Deck", Arena.WallRadius + 6, 0, PAVE, 4) -- the only solid part (BossArenaView's addPart)
	disc("Ground", 700, -0.5, SAND_OUT, 1) -- outside the stadium, seen through the gate
	local laneWidth = Arena.Width / Arena.Lanes
	local layer = 0
	for lane = Arena.Lanes, 0, -1 do
		local edge = Arena.InnerRadius + lane * laneWidth
		layer += 1
		disc("LaneLine", edge + 0.3, layer * DISC_STEP, LINE, 0.2)
		layer += 1
		disc(
			lane > 0 and "Lane" or "Paving",
			edge - 0.3,
			layer * DISC_STEP,
			lane == 0 and PAVE or lane % 2 == 1 and LANE_A or LANE_B,
			0.2
		)
	end
	arc("MeanderEdge", 92, 102, 0.36, 0.1, GOLD, 16, 0, 2 * math.pi)
	arc("Meander", 92.7, 101.3, 0.4, 0.1, BLUE, 16, 0, 2 * math.pi)
	for k = 0, 3 do -- four arcs outside the lanes, open at the gate, the stairs' sides and opposite
		local a0 = GATE - k * math.pi / 2
		arc("MeanderEdge", 176, 188, 0.08, 0.1, GOLD, 5, a0 + math.rad(22), a0 + math.rad(68))
		arc("Meander", 176.7, 187.3, 0.12, 0.1, BLUE, 5, a0 + math.rad(22), a0 + math.rad(68))
	end

	local function inGate(a, half)
		return math.abs((a - GATE + math.pi) % (2 * math.pi) - math.pi) < half - 1e-6
	end

	-- The podium wall: per 9 degree bay a masonry piece, a dark round arch with gold in it, a blue band -----------------------------
	-- And the top arcade: per bay a pier at its edge, an attic, the arch's two corners ---------------------------------------------
	local wall = Arena.WallRadius
	for k = 0, 39 do
		local a = GATE + (k + 0.5) * BAY
		if not inGate(a, BAY) then
			if not pace(mine) then
				return false
			end
			put(
				"PodiumWall",
				Vector3.new(4, POD_H - 4, chord(wall + 4, BAY)),
				at(a, wall + 2, (POD_H - 4) / 2),
				MASONRY
			)
			put("PodiumBand", Vector3.new(3.2, 3.4, chord(wall + 3.2, BAY)), at(a, wall + 1.6, POD_H - 2.3), BLUE)
			put("PodiumArch", Vector3.new(0.4, 20, 20), at(a, wall - 0.2, 5), RECESS, Enum.PartType.Cylinder)
			ball("PodiumGold", Vector3.new(10, 6, 12), at(a, wall - 3.5, 0), GOLD_MOUND)
			local front = TOP_R * math.cos(BAY / 2)
			local length = chord(front + 5, BAY)
			put("ArcadePier", Vector3.new(5, 33, 10), at(a - BAY / 2, front + 2.5, TOP_Z + 16.5), MASONRY)
			put("ArcadeAttic", Vector3.new(7, 9, length), at(a, front + 2.5, ARC_TOP - 4.5), SAND)
			haunches("ArcadeArch", at(a, front + 2.5, 0), 5, 12, 12, length / 2 - 5, ARC_TOP - 9, MASONRY)
		end
	end

	-- The stands: per 18 degree piece the podium's top walk, three tier ramps (steps as one slope), two blue fronts, the back -----
	for k = 1, 19 do
		if not pace(mine) then
			return false
		end
		local a = GATE + k * STAND
		put("StandWalk", Vector3.new(8, 0.6, chord(STAND_FROM + 1, STAND)), at(a, STAND_FROM - 3, POD_H - 0.3), SAND_HI)
		for tier = 0, 2 do
			local r1, bottom = STAND_FROM + tier * TIER_D, POD_H + tier * (TIER_RISE + TIER_FRONT)
			ramp("StandTier", a, r1, r1 + TIER_D, bottom, TIER_RISE, chord(r1 + TIER_D, STAND), SAND)
			if tier > 0 then
				local length = chord(r1 + TIER_D, STAND)
				put(
					"StandFront",
					Vector3.new(TIER_D, TIER_FRONT, length),
					at(a, r1 + TIER_D / 2, bottom - TIER_FRONT / 2),
					BLUE
				)
			end
		end
		put("StandBack", Vector3.new(8, 16.4, chord(TOP_R + 8, STAND)), at(a, TOP_R + 4, TOP_Z - 8.2), SAND)
	end
	-- Blue runners down the three tiers
	local slope = math.atan2(TIER_RISE, TIER_D)
	for _, deg in AISLE_DEG do
		if not pace(mine) then
			return false
		end
		for tier = 0, 2 do
			local r1, bottom = STAND_FROM + tier * TIER_D, POD_H + tier * (TIER_RISE + TIER_FRONT)
			local cf = at(GATE + math.rad(deg), r1 + TIER_D / 2, bottom + TIER_RISE / 2 + 0.4)
				* OUT
				* CFrame.Angles(-slope, 0, 0)
			put("Aisle", Vector3.new(5, 0.6, math.sqrt(TIER_D ^ 2 + TIER_RISE ^ 2)), cf, BLUE)
		end
	end
	-- Gold heaps and open chests on the first tier
	local tread = STAND_FROM + 7.5
	local treadY = POD_H + 7.5 / TIER_D * TIER_RISE
	for k = 0, 38, 2 do
		local a = (k + 0.5) * BAY
		if not inGate(a, BAY * 1.6) then
			if not pace(mine) then
				return false
			end
			ball("StandGold", Vector3.new(8.4, 4.2, 8.4), at(a, tread, treadY), GOLD_MOUND)
			if k % 4 == 0 then
				chest(at(a + 0.035, tread, treadY - 0.4) * CFrame.Angles(0, math.pi / 2, 0), 1.3, CHESTS[2])
			end
		end
	end

	-- Grand stairs up the podium: a flight, a blue runner, two side walls ------------------------------------------------------
	for _, deg in STAIR_DEG do
		if not pace(mine) then
			return false
		end
		local a = GATE + math.rad(deg)
		local x0, x1 = wall - 24, wall + 0.5
		ramp("Stair", a, x0, x1, 0, POD_H, 16, SAND_HI)
		local rise = math.atan2(POD_H, x1 - x0)
		local cf = at(a, (x0 + x1) / 2, POD_H / 2 + 0.3) * OUT * CFrame.Angles(-rise, 0, 0)
		put("StairRunner", Vector3.new(6, 0.4, math.sqrt(POD_H ^ 2 + (x1 - x0) ^ 2)), cf, BLUE)
		for _, side in { -1, 1 } do
			ramp("StairWall", a, x0 - 1, x1, 0, POD_H + 3, 2.5, MASONRY, side * 9.25)
		end
	end

	-- Banded columns in pairs on the podium's top walk, a red banner with our gold winged sun between each pair -------------------
	for _, deg in BANNER_DEG do
		for _, sign in { -1, 1 } do
			if not pace(mine) then
				return false
			end
			local a = GATE + sign * math.rad(deg)
			for _, side in { -1, 1 } do
				local base = at(a + side * math.rad(2.6), wall + 3.2, POD_H)
				put("ColumnBase", Vector3.new(5.4, 1.6, 5.4), base * CFrame.new(0, 0.8, 0), SAND_HI)
				cyl("Column", 2.1, 40, base * CFrame.new(0, 1.6, 0), SAND)
				cyl("ColumnBand", 2.4, 2.6, base * CFrame.new(0, 13, 0), BLUE)
				cyl("ColumnBand", 2.4, 2.6, base * CFrame.new(0, 30, 0), BLUE)
				put("ColumnCapital", Vector3.new(6.4, 3, 6.4), base * CFrame.new(0, 43.1, 0), GOLD)
			end
			put("BannerRod", Vector3.new(0.8, 0.8, chord(wall + 3, math.rad(5.2))), at(a, wall + 3, POD_H + 41.2), GOLD)
			put("Banner", Vector3.new(0.5, 30, 12), at(a, wall + 0.4, POD_H + 25), BANNER)
			put(
				"BannerFoot",
				Vector3.new(0.4, 8.5, 8.5),
				at(a, wall + 0.5, POD_H + 10) * CFrame.Angles(math.pi / 4, 0, 0),
				BANNER
			)
			put("BannerSun", Vector3.new(0.3, 3.4, 3.4), at(a, wall, POD_H + 27), GOLD, Enum.PartType.Cylinder)
			for _, side in { -1, 1 } do
				put(
					"BannerWing",
					Vector3.new(0.3, 1.6, 5),
					at(a, wall, POD_H + 27.6, side * 3.6) * CFrame.Angles(side * 0.35, 0, 0),
					GOLD
				)
			end
		end
	end

	-- The gate: two crenellated towers with glazed panels and bands, a glazed arch wall with gold jambs and a rayed fan -----------
	if not pace(mine) then
		return false
	end
	local towerTop = ARC_TOP + 8
	for _, side in { -1, 1 } do
		local z = side * 38
		put("GateTower", Vector3.new(90, towerTop, 28), at(GATE, 287, towerTop / 2, z), MASONRY)
		put("GatePanel", Vector3.new(0.6, 34, 25), at(GATE, 241.7, 52, z), GLAZED)
		for _, h in { 30, towerTop - 14 } do
			put("GateBand", Vector3.new(1, 3, 28.2), at(GATE, 241.5, h, z), BLUE)
		end
		for k = 0, 3 do
			put("Merlon", Vector3.new(4, 5, 5.4), at(GATE, 244, towerTop + 2.5, side * (24 + (k + 0.5) * 7)), SAND_HI)
		end
		for k = 0, 2 do
			put("Merlon", Vector3.new(6, 5, 3), at(GATE, 256 + k * 22, towerTop + 2.5, side * 25.5), SAND_HI)
		end
		put("GateWall", Vector3.new(16, 45, 13), at(GATE, 252, 22.5, side * 17.5), GLAZED)
		put("GateJamb", Vector3.new(0.6, 34, 1), at(GATE, 243.6, 17, side * 11.5), GOLD)
	end
	put("GateWall", Vector3.new(16, 53, 48), at(GATE, 252, 71.5), GLAZED)
	haunches("GateArch", at(GATE, 252, 0), 16, 11, 11, 11, 45, GLAZED)
	for k = 0, 6 do -- the fan over the opening: gold and blue rays round the arch's centre
		local phi = math.rad(15 + k * 25)
		local cf = at(GATE, 243.6, 34 + 17.5 * math.sin(phi), 17.5 * math.cos(phi)) * CFrame.Angles(-phi, 0, 0)
		put("GateRay", Vector3.new(0.4, 1.4, 11), cf, k % 2 == 0 and GOLD_HI or BLUE)
	end
	put("GateLintel", Vector3.new(1, 3, 48), at(GATE, 243.5, ARC_TOP - 14), GOLD)
	for k = 0, 4 do
		put("Merlon", Vector3.new(4, 5, 4.2), at(GATE, 246, ARC_TOP - 5.5, -20.4 + k * 10.2), SAND_HI)
	end
	-- The stepped tower out past the gate
	local floorY = 0
	for k, step in { { 110, 22 }, { 84, 20 }, { 60, 20 }, { 40, 18 }, { 24, 16 } } do
		put(
			"FarTower",
			Vector3.new(step[1], step[2], step[1]),
			at(GATE, 440, floorY + step[2] / 2),
			k % 2 == 1 and ZIG or ZIG2
		)
		floorY += step[2]
	end
	put("FarTowerTop", Vector3.new(14, 12, 14), at(GATE, 440, floorY + 6), BLUE)
	put("FarTowerTop", Vector3.new(15, 1, 15), at(GATE, 440, floorY + 12.5), GOLD)

	-- Two winged lions with crowned, bearded heads on banded plinths before the towers, side-on, walking away from the gate -----
	for _, side in { -1, 1 } do
		if not pace(mine) then
			return false
		end
		local z = side * 33
		put("Plinth", Vector3.new(15, 22, 32), at(GATE, 226, 11, z), MASONRY)
		put("PlinthTop", Vector3.new(16, 2, 33), at(GATE, 226, 23, z), SAND_HI)
		put("PlinthBand", Vector3.new(15.4, 2.6, 32.4), at(GATE, 226, 18.5, z), BLUE)
		-- The lion's own frame: front -X, along the wall away from the gate; its blocks at LION_SCALE
		local lion = at(GATE, 226, 24, z) * CFrame.Angles(0, side * math.pi / 2, 0)
		local function block(name, size, x, y, zz, style, turn)
			local s = LION_SCALE
			put(name, size * s, lion * CFrame.new(x * s, y * s, zz * s) * (turn or CFrame.identity), style)
		end
		for _, dx in { -5.2, 5.2 } do
			for _, dz in { -2.4, 2.4 } do
				block("LionLeg", Vector3.new(2.6, 6, 2.4), dx, 3, dz, STATUE)
			end
		end
		block("LionBody", Vector3.new(15, 7, 7), 0.5, 9.5, 0, STATUE)
		block("LionChest", Vector3.new(5, 10, 7.6), -6, 10.5, 0, STATUE)
		block("LionNeck", Vector3.new(3.6, 4, 4.4), -8, 16.5, 0, STATUE)
		block("LionHead", Vector3.new(4.8, 5.4, 4.8), -9.2, 20, 0, STATUE)
		block("LionBeard", Vector3.new(1.6, 4.6, 3.2), -11.5, 17.6, 0, STATUE_LO)
		block("LionBrow", Vector3.new(0.6, 0.7, 4.3), -11.7, 21, 0, STATUE_LO)
		block("LionTail", Vector3.new(1.2, 6, 1.2), 8.5, 9, 0, STATUE, CFrame.Angles(0, 0, 0.5))
		block("LionCrown", Vector3.new(5.8, 3.2, 5.8), -9.2, 24.3, 0, GOLD)
		for _, w in { -1, 1 } do
			for j, wing in { { 16, 0.6, 15.5, STATUE }, { 13, 0.4, 13, STATUE_LO } } do
				local length, lift = wing[1], wing[2]
				local root0 = CFrame.new(-5, wing[3], w * (3.9 + (j - 1) * 0.7))
				local local0 = root0 * CFrame.Angles(0, 0, lift) * CFrame.new(length / 2, 0, 0)
				local p = local0.Position
				block(
					"LionWing",
					Vector3.new(length, 3.8 - (j - 1) * 0.7, 0.9),
					p.X,
					p.Y,
					p.Z,
					wing[4],
					local0.Rotation
				)
			end
		end
	end

	-- Ruins: 6 low groups between the mound and the lanes (every top under 12), 6 between the lanes and the podium --------------
	for i = 0, 5 do
		if not pace(mine) then
			return false
		end
		local a = math.rad(30 + 60 * i)
		local function o(dr, dt, y)
			return at(a, 80 + dr, y or 0, -dt)
		end
		ball("RuinGold", Vector3.new(15, 6, 15), o(0, 0), GOLD_MOUND)
		stump(o(-4, -9), 2.6, rng:NextNumber(5, 8.5))
		put("RuinPier", Vector3.new(4.5, 7.5, 4.5), o(5, 9, 3.75), SAND)
		put("RuinSpringer", Vector3.new(7, 2.2, 4.4), o(5.5, 7.5, 8.9) * CFrame.Angles(0, 0, 0.28), SAND2)
		blocks(o(2, -4), 3, 1.8, 3.6, 5)
		chest(o(-2, 4) * CFrame.Angles(0, 1.4, 0), 1.1, CHESTS[i % 3 + 1])
		goblet(o(-5, 1), 1)
		shield(o(-6.5, -3) * CFrame.Angles(0, math.pi, 0), 3.2, 0.35)
		sword(o(1, 2, -1), 1, false)
		gem(o(-3, 6), 1, i)
		gem(o(-4, 7.5), 1, i + 1)
	end
	for i, deg in { 45, 135, 207, 243, 297, 333 } do
		if not pace(mine) then
			return false
		end
		local a = math.rad(deg)
		local function o(dr, dt, y)
			return at(a, 228 + dr, y or 0, -dt)
		end
		ball("RuinGold", Vector3.new(16, 7.2, 16), o(0, 2), GOLD_MOUND)
		if i % 2 == 1 then -- a broken arch: two piers with blue caps, one springer still leaning off the tall one
			for _, s in { -1, 1 } do
				local h = s < 0 and 15 or 10
				put("RuinPier", Vector3.new(4.5, h, 4.5), o(4, s * 8, h / 2), SAND)
				put("RuinCap", Vector3.new(5.2, 1.4, 5.2), o(4, s * 8, h - 4), BLUE)
			end
			put("RuinSpringer", Vector3.new(4.2, 4.2, 9), o(4, -4, 16.5) * CFrame.Angles(-0.35, 0, 0), SAND2)
		else -- a low broken wall
			for k = 0, 3 do
				local h = 7 - k * 1.3
				put("RuinWall", Vector3.new(4, h, 5.2), o(5, -8 + k * 5.4, h / 2), MASONRY)
			end
			put("RuinBand", Vector3.new(4.2, 1.2, 21.6), o(5, -1.6, 3), BLUE)
		end
		stump(o(-6, -10), 2.8, rng:NextNumber(6, 10))
		blocks(o(-2, 8), 3, 2, 4, 5)
		chest(o(-4, -3) * CFrame.Angles(0, 0.4, 0), 1.3, CHESTS[i % 2 + 2])
		shield(o(-7, 5) * CFrame.Angles(0, 0.3, 0), 3.6, 0.4)
		crown(o(-3, 4), 0.9)
		gem(o(-6, 0), 1.1, i)
		gem(o(-7, 1.5), 1.1, i + 1)
	end

	-- The centre mound (folder KingMound): 5 stepped stone tiers whose corners poke out of a gold hill, loose blocks, the gold cap
	-- at MoundTop he hovers over, big treasure sized for the lane distance, a warm glow and sparkles. All of it under MoundTop.
	if not pace(mine) then
		return false
	end
	local mound = Instance.new("Folder")
	mound.Name = "KingMound"
	mound.Parent = root
	into = mound
	local hub = CFrame.new(center)
	local tierTop = 0
	for k, tier in { { 34, 7 }, { 26, 7 }, { 19, 7 }, { 12, 7 }, { 7, 5 } } do
		local half, h = tier[1], tier[2]
		local turn = hub * CFrame.Angles(0, math.rad(45 * ((k - 1) % 2) + 8), 0)
		for _, qx in { -1, 1 } do
			for _, qz in { -1, 1 } do
				local hh = k < 5 and h + rng:NextNumber(-0.8, 0.8) or h
				local size = Vector3.new(half * rng:NextNumber(0.92, 1.04), hh, half * rng:NextNumber(0.92, 1.04))
				local style = ({ SAND, SAND2, SAND_LO, SAND })[(qx + qz + k) % 4 + 1]
				put("MoundStone", size, turn * CFrame.new(qx * half / 2, tierTop + hh / 2, qz * half / 2), style)
			end
		end
		tierTop += h
	end
	-- The gold hill: squashed spheres { radius, height } round the centre, half under the deck
	local HILL = { { 67, 5 }, { 56, 15 }, { 38, 21 }, { 22, 28 } }
	local hills = {}
	for _, hill in HILL do
		table.insert(hills, ball("MoundGold", Vector3.new(2 * hill[1], 2 * hill[2], 2 * hill[1]), hub, GOLD_MOUND))
	end
	local function hz(r) -- the hill's height at radius r
		local top = 0
		for _, hill in HILL do
			top = math.max(top, hill[2] * math.sqrt(math.max(0, 1 - (r / hill[1]) ^ 2)))
		end
		return top
	end
	local function spot(a, r, dy)
		return at(a, r, hz(r) + (dy or 0))
	end
	local cap = ball("MoundCap", Vector3.new(10, 5.5, 10), hub * CFrame.new(0, Arena.MoundTop - 2.75, 0), GOLD_HI)
	local glow = Instance.new("PointLight") -- warm light on the gold and up on him
	glow.Color, glow.Range, glow.Brightness, glow.Shadows = Color3.fromRGB(255, 200, 110), 60, 1.5, false
	glow.Parent = cap
	for k = 0, 5 do
		local a, r = k / 6 * 2 * math.pi + rng:NextNumber(-0.2, 0.2), rng:NextNumber(22, 50)
		local s = rng:NextNumber(5, 8)
		local cf = spot(a, r, s * 0.1) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 2 * math.pi), 0)
		put("MoundBlock", Vector3.new(s * 1.2, s, s * 0.8), cf, ({ SAND, SAND2, SAND_LO })[k % 3 + 1])
	end
	local f = math.rad(-100) -- the draft's lane renders' spot: the big shield faces it
	for k, row in { { f + 0.45, 30, 3.6, 2 }, { f + 2.5, 28, 3.4, 3 }, { f - 2.1, 32, 3.6, 2 } } do
		chest(spot(row[1], row[2], -1.2) * CFrame.Angles(0, k, 0), row[3], CHESTS[row[4]])
	end
	shield(spot(f - 0.12, 47, 1) * CFrame.Angles(0, math.pi, 0), 9, 0.3) -- faces out, to the lanes
	shield(spot(f + 3.4, 44, 1) * CFrame.Angles(0, math.pi, 0), 6.5, 0.35)
	crown(spot(f + 1.2, 38, -0.4), 2.6)
	crown(spot(f - 1.0, 22, -0.4), 2.4)
	for _, row in { { f - 0.55, 40, 3 }, { f + 1.9, 18, 2.8 }, { f + 3.9, 34, 3 } } do
		goblet(spot(row[1], row[2], -0.5), row[3])
	end
	for _, row in { { f + 0.9, 20 }, { f + 2.9, 19 }, { f - 2.6, 18 }, { f + 4.4, 25 } } do
		sword(spot(row[1], row[2], -1), 1.6, true)
	end
	for _, row in { { f + 1.6, 30 }, { f - 1.5, 27 } } do
		trident(spot(row[1], row[2], -1), 1.1)
	end
	for _, row in { { f + 0.95, 46 }, { f - 1.6, 44 }, { f + 3.0, 47 } } do
		stump(spot(row[1], row[2], -1.5), 3.2, 8.5)
	end
	for k = 1, 9 do
		gem(spot(k / 9 * 2 * math.pi + 0.4, rng:NextNumber(20, 50), 0.4), 2.8, k)
	end
	if not UiMotion.Reduced() then -- REDUCED EFFECTS: no sparkles
		local sparkle = Instance.new("ParticleEmitter") -- the engine's own sparkle texture, no upload
		sparkle.Shape = Enum.ParticleEmitterShape.Sphere
		sparkle.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(1.2, 0)
		sparkle.Lifetime = NumberRange.new(0.6, 1.2)
		sparkle.Speed = NumberRange.new(0)
		sparkle.Rate = 12
		sparkle.Parent = hills[2] -- its surface is the hill's middle slope
	end

	root:SetAttribute("PartCount", count) -- the measured number, for the Studio verify
	return true
end

return BossKingArena
