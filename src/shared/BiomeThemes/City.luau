--!nonstrict
-- Track 6 (day): bright modern city. Boulevards past campus gate walls, a mock-city training ground of concrete
-- blocks, toppled generic robots, and a single plain glass academy tower (not the real H shape).
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 6): flat Blocks terrain (Pavement
-- plazas, Concrete training ground, Grass park verges), Embank off, a bright morning atmosphere, audio and the asset
-- ledger. Mesh props keep their part fallback (spec 4.2), scaled to the mesh's size.
-- IP (spec 7): no H-shaped tower, no school emblem or crest on any gate, generic boxy robots only; billboards carry
-- abstract shapes, no text.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, part, post, prop, block, roundTree, lowrise, tower, gate, patch, GLASS6, CONCRETE6, RED6, YELLOW6, ASPHALT6, PARK6, trainingRobot =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.BALL,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.roundTree,
	Kit.lowrise,
	Kit.tower,
	Kit.gate,
	Kit.patch,
	Kit.GLASS6,
	Kit.CONCRETE6,
	Kit.RED6,
	Kit.YELLOW6,
	Kit.ASPHALT6,
	Kit.PARK6,
	Kit.trainingRobot

local TRIM = hex("B8C0CC") -- light grey window mullions and floor bands
local STEEL = hex("8A94A4") -- robot grey
local DARK_STEEL = hex("444C5A")
local MOCK = hex("C9CCD2") -- training-ground concrete
local SKY_GLOW = hex("CFE6FF")

-- A mesh prop (spec 4.2): `def`'s parts, scaled to `size`'s height, are the fallback when the ledger row is unusable.
-- `size` keeps the mesh's own proportions (the registry stretches the mesh to it).
local function meshed(def, key, size, extra)
	local k = size.Y / def.Size.Y
	local parts = {}
	for i, p in def.Parts do
		local q = table.clone(p)
		q.Size = p.Size * k
		q.Pos = p.Pos * k
		parts[i] = q
	end
	local out = prop(def.Name, size, parts, { Mesh = key, Glow = def.Glow, Tag = def.Tag, Pad = def.Pad })
	for name, value in extra or {} do
		out[name] = value
	end
	return out
end

-- Buildings get a levelled pad (spec 3.2, owner 2026-10-31)
local function padded(def)
	def.Pad = true
	return def
end

-- Hero 1: a single plain glass slab tower, 200 studs tall at landmark scale (x1.75). One rectangular slab on a
-- concrete podium: no wings, no bridge, no H shape, no emblem.
local function academyTower()
	local parts = {
		part(v(24, 6, 16), v(0, 3, 0), CONCRETE6, M.Concrete), -- podium
		part(v(12, 4, 0.4), v(0, 2.5, -8.1), GLASS6, M.Glass), -- lobby glass
		part(v(14, 0.8, 2), v(0, 5.2, -7.4), TRIM, M.Metal), -- entrance canopy
		part(v(20, 100, 12), v(0, 56, 0), GLASS6, M.Glass), -- glass curtain wall
		part(v(21, 2, 13), v(0, 107, 0), CONCRETE6, M.Concrete), -- crown
		part(v(8, 3, 6), v(-3, 109.5, 1), TRIM, M.Metal), -- rooftop plant
		post(3, 0.6, v(5, 109.5, 2), rgb(160, 160, 170), M.Metal), -- mast
		part(v(1.2, 1.2, 1.2), v(5, 111.6, 2), RED6, M.Neon, BALL), -- aircraft beacon
	}
	for i = 1, 10 do -- floor bands every 10 studs
		table.insert(parts, part(v(20.4, 0.6, 12.4), v(0, 6 + i * 10 - 0.3, 0), TRIM, M.Concrete))
	end
	for _, x in { -10.2, -3.4, 3.4, 10.2 } do -- vertical mullions on the road face
		table.insert(parts, part(v(0.6, 100, 0.6), v(x, 56, -6.2), TRIM, M.Metal))
	end
	return prop("AcademyTower", v(24, 112.2, 16.5), parts, { Glow = SKY_GLOW, Pad = true })
end

-- Hero 2: a giant generic boxy robot toppled on its back along the road, one arm raised (no real design).
local function toppledRobot()
	local parts = {
		part(v(6, 6, 6), v(-14, 3, 0), STEEL, M.Metal), -- head
		part(v(1.6, 0.4, 4.4), v(-14, 6.2, 0), YELLOW6, M.Neon), -- visor (faces up)
		part(v(12, 7, 10), v(-5, 3.5, 0), STEEL, M.Metal), -- torso
		part(v(12.2, 1, 10.2), v(-5, 5, 0), YELLOW6, M.SmoothPlastic), -- hazard band
		part(v(4, 1, 4), v(-5, 7.5, -2), DARK_STEEL, M.DiamondPlate), -- chest vent
		part(v(12, 4, 4), v(7, 2, -2.6), DARK_STEEL, M.Metal), -- legs
		part(v(12, 4, 4), v(7, 2, 2.6), DARK_STEEL, M.Metal),
		part(v(3, 6, 5), v(14.5, 3, -2.6), STEEL, M.Metal), -- feet (soles up)
		part(v(3, 6, 5), v(14.5, 3, 2.6), STEEL, M.Metal),
		part(v(10, 3, 3), v(-5, 1.5, -6.5), DARK_STEEL, M.Metal), -- arm flat on the road side
		part(v(3, 14, 3), v(-6, 14, 5.5), DARK_STEEL, M.Metal), -- raised arm
		part(v(3.4, 3.4, 3.4), v(-6, 7, 5.5), STEEL, M.Metal, BALL), -- shoulder joint
		part(v(3, 10, 3), v(-6, 26, 5.5), DARK_STEEL, M.Metal),
		part(v(4, 3.3, 4), v(-6, 32.65, 5.5), STEEL, M.Metal), -- hand
		part(v(1.4, 1.4, 1.4), v(2, 7.6, 3), RED6, M.Neon, BALL), -- warning light
		part(v(8, 1, 6), v(9, 0.6, -5.5), ASPHALT6, M.Concrete, nil, CFrame.Angles(0.15, 0.3, 0.1)), -- cracked slab
		part(v(4, 2, 3), v(-12, 1, -6), MOCK, M.Concrete, nil, CFrame.Angles(0, 0.6, 0.2)), -- rubble
	}
	return prop("ToppledRobot", v(34, 34.3, 16), parts, { Glow = YELLOW6 })
end

-- Hero 3: mock-city training block, three bare concrete towers of different heights with blank window grids, a
-- skybridge, a broken top and rubble at their feet. No signs or text.
local function trainingBlocks()
	local parts = {
		part(v(34, 1.5, 16), v(0, 0.75, 0), ASPHALT6, M.Concrete), -- plinth
		part(v(10, 58.5, 12), v(-11, 30.75, 0), MOCK, M.Concrete),
		part(v(10, 42.5, 14), v(0, 22.75, 0), hex("B8BCC4"), M.Concrete),
		part(v(10, 30.5, 12), v(11, 16.75, 0), MOCK, M.Concrete),
		part(v(6, 3, 4), v(-5.5, 36, 0), TRIM, M.Concrete), -- skybridge
		part(v(9, 1.2, 9), v(0.5, 45, 1), hex("B8BCC4"), M.Concrete, nil, CFrame.Angles(0.2, 0, 0.25)), -- broken top
		post(4, 4, v(11, 34, 2), STEEL, M.Metal), -- water tank
		part(v(3, 2, 3), v(-6, 2.5, -6.5), MOCK, M.Concrete, nil, CFrame.Angles(0, 0.5, 0.3)), -- rubble
		part(v(4, 1.5, 2), v(6, 2.25, -7), MOCK, M.Concrete, nil, CFrame.Angles(0.3, 0.2, 0)),
		part(v(1.2, 1.2, 1.2), v(-11, 60.6, 0), RED6, M.Neon, BALL), -- roof hazard lights
		part(v(1.2, 1.2, 1.2), v(11, 32.6, -3), RED6, M.Neon, BALL),
	}
	for _, t in { { -11, 58.5, 12 }, { 0, 42.5, 14 }, { 11, 30.5, 12 } } do -- dark window bands every 6 studs
		for y = 6, t[2] - 3, 6 do
			table.insert(parts, part(v(10.3, 2, t[3] + 0.3), v(t[1], y, 0), hex("3A4250"), M.Glass))
		end
	end
	return prop("TrainingBlocks", v(34, 61.2, 16), parts, { Glow = RED6, Pad = true })
end

-- Campus gate wall: a low clean wall with a plain open gateway and two pillars. No emblem, no name plate.
local campusGate = prop("CampusGate", v(30, 12, 6), {
	part(v(10, 6, 3), v(-10, 3, 0), CONCRETE6, M.Concrete),
	part(v(10, 6, 3), v(10, 3, 0), CONCRETE6, M.Concrete),
	part(v(10.4, 0.6, 3.4), v(-10, 6.3, 0), TRIM, M.Metal), -- coping
	part(v(10.4, 0.6, 3.4), v(10, 6.3, 0), TRIM, M.Metal),
	part(v(3, 12, 4), v(-5, 6, 0), GLASS6, M.Glass), -- gate pillars
	part(v(3, 12, 4), v(5, 6, 0), GLASS6, M.Glass),
	part(v(13, 1.2, 6), v(0, 11.4, 0), CONCRETE6, M.Concrete), -- plain lintel, no plate
	part(v(6.4, 0.3, 0.3), v(0, 1.5, -1.2), RED6, M.Metal), -- open sliding bar
})

local streetLamp = prop("StreetLamp", v(4, 16.5, 3), {
	post(16, 0.8, v(0, 8, 0), ASPHALT6, M.Metal),
	part(v(4, 0.6, 1), v(-1.5, 15.9, 0), ASPHALT6, M.Metal), -- arm over the road side
	part(v(2, 0.6, 1.4), v(-2.5, 15.5, 0), rgb(255, 250, 220), M.Neon),
})
local crashBarrier = block("CrashBarrier", v(10, 3, 1.5), CONCRETE6, M.Concrete, {
	part(v(10.2, 0.6, 1.6), v(0, 2.4, 0), RED6, M.SmoothPlastic),
})
local billboard = prop("Billboard", v(16, 16, 1.5), {
	post(9, 1, v(0, 4.5, 0), ASPHALT6, M.Metal),
	part(v(16, 7, 1.2), v(0, 12.5, 0.1), CONCRETE6, M.SmoothPlastic),
	part(v(6, 5, 1.3), v(-4, 12.5, 0), GLASS6, M.SmoothPlastic), -- abstract shapes, no text
	part(v(5, 5, 1.3), v(4, 12.5, 0), YELLOW6, M.SmoothPlastic, BALL),
	part(v(16, 0.6, 1.4), v(0, 9.3, 0), RED6, M.Neon),
})
local parkTree = roundTree("ParkTree", 14, hex("6B4A2E"), hex("5BA85B"))
local glassTower =
	padded(tower("GlassTower", 18, 64, 12, { Body = hex("D0D6DE"), Trim = TRIM, Glass = GLASS6, Neon = YELLOW6 }))
local office = padded(lowrise("Office", 30, 38, 26, { Glass = GLASS6, Neon = RED6, Body = hex("C8D0DA") }))
local shops = padded(lowrise("Shops", 30, 16, 24, { Glass = GLASS6, Neon = RED6, Body = hex("DDE2E8") }))

-- Mesh props (Lane A). Phase 1 sizes are the intended ones; step A resets each to its mesh's own proportions.
local streetLampMesh = meshed(streetLamp, "StreetLampMesh", v(4, 16.5, 3))
local crashBarrierMesh = meshed(crashBarrier, "CrashBarrierMesh", v(10, 3, 1.5))
local billboardMesh = meshed(billboard, "BillboardMesh", v(16, 16, 1.5))
local parkTreeMesh = meshed(parkTree, "ParkTreeMesh", parkTree.Size)
local robotMesh = meshed(trainingRobot(), "TrainingRobotMesh", v(20, 25, 8))
local campusGateMesh = meshed(campusGate, "CampusGateMesh", v(30, 12, 6))
local glassTowerMesh = meshed(glassTower, "GlassTowerMesh", glassTower.Size)
local officeMesh = meshed(office, "OfficeBlockMesh", office.Size)
local shopsMesh = meshed(shops, "ShopFrontMesh", shops.Size)

-- Mesh rows: generated in Studio (Lane A) with the stored prompt; each mesh's own generated texture is a Texture row.
-- Phase 1 skeleton: no Id yet (an id-less row is never used, the parts fallback builds). Reviewed is left for the
-- rules auditor (spec 4.1 step 3); close-ups go in assets/biomes/City/review/.
-- Notes give the generate_mesh call: size (studs) and segmentation; Tris is its maxTriangles.
local function meshRow(texture, prompt, tris, notes)
	return { Kind = "Mesh", Lane = "A", Prompt = prompt, Texture = texture, Tris = tris, Notes = notes }
end

return {
	DisplayName = "Hero Academy City",
	Ground = { Color = PARK6, Material = M.Grass },
	Sky = { Color = hex("D6E8FA") },
	Gate = gate(RED6, M.Metal, YELLOW6),
	-- The street walls need most of the budget (spec Layers 9); see BiomeDressing SHARE
	Shares = { Rhythm = 0.15, Blocks = 0.75 },
	Rhythm = {
		Every = 8,
		Offset = 10,
		Props = { streetLampMesh, crashBarrierMesh, robotMesh, parkTreeMesh },
	},
	-- Pinned heroes (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight. Fractions of the 8720-stud
	-- track: 0.27 = the 235-stud straight after the first toppled robots (0.262-0.289), 0.5 = the 244-stud straight
	-- out of the second training ground (0.491-0.519), 0.72 = the 616-stud straight past the third campus gates
	-- (0.686-0.757).
	Landmarks = {
		-- placeholder: 28. Heroes are <= 16.5 deep (x1.75 = 29), so they span about 48-77 studs from the centre line,
		-- outside the 44 corridor and inside this zone's half of the gap (midline about 77).
		Offset = 28,
		Every = 60,
		Props = {
			meshed(toppledRobot(), "ToppledRobotMesh", v(34, 34.3, 16), { Hero = true, At = 0.27 }),
			meshed(trainingBlocks(), "TrainingBlocksMesh", v(34, 61.2, 16), { Hero = true, At = 0.5 }),
			meshed(academyTower(), "AcademyTowerMesh", v(24.5, 114.3, 16.8), { Hero = true, At = 0.72 }),
			glassTowerMesh,
			campusGateMesh,
		},
	},
	Horizon = {
		-- placeholder: 18 (was 55). The x2 pieces are 40 deep, so they span about 38-78 studs from the centre line.
		Offset = 18,
		Props = {
			prop("Skyline", v(36, 60, 20), {
				part(v(14, 60, 18), v(-11, 30, 0), hex("C8D0DA"), M.Concrete),
				part(v(12, 44, 16), v(4, 22, 0), hex("D8DEE6"), M.Concrete),
				part(v(10, 52, 14), v(15, 26, 0), hex("C8D0DA"), M.Concrete),
				part(v(14.4, 30, 18.4), v(-11, 34, 0), GLASS6, M.Glass),
				part(v(10.4, 26, 14.4), v(15, 30, 0), GLASS6, M.Glass),
			}),
		},
	},
	-- The verge between the road and the street wall (Blocks row 1 starts 22 studs past the road edge)
	Scatter = {
		Every = 2,
		Near = 2,
		Far = 10,
		Props = {
			"ParkTree",
			billboardMesh,
			block("Bench", v(6, 2.5, 2), hex("6B4A2E"), M.WoodPlanks),
			block("Planter", v(5, 3, 5), TRIM, M.Concrete, { part(v(4, 2, 4), v(0, 3.5, 0), PARK6, M.Grass) }),
		},
		Patches = {
			patch("Crosswalk", 10, 4, hex("F4F4F4"), M.Concrete),
			patch("TrainingGround", 12, 8, hex("C8C2B4"), M.Concrete),
			patch("Lawn", 10, 8, hex("7CC47C"), M.Grass),
		},
	},
	-- orchestrator default 2026-10-31: one row (was 2). Row 1 spans about 42-72 studs from the centre line; a second
	-- row would cross the gap midline (about 77) and be slid or deleted by SnapToTerrain (spec 3.2).
	Blocks = {
		Spacing = 32, -- just over the widest building (30.3), so the street wall has no wide gaps
		Near = 22,
		Rows = 1,
		RowDepth = 34,
		Props = {
			shopsMesh,
			padded(lowrise("Apartments", 28, 30, 26, { Glass = GLASS6, Neon = YELLOW6, Body = hex("E6D8C4") })),
			officeMesh,
			padded(lowrise("Gym", 30, 14, 24, { Glass = GLASS6, Neon = YELLOW6, Body = TRIM })),
		},
	},
	-- No Particles (spec 7, Track 6: none, which keeps the city crisp), so the landmarks carry no emitter either.
	-- Spec 3.3 / 7: Blocks (flat) with Pavement plazas, Concrete on the three mock-city training grounds and Grass park
	-- verges along the campus-gate stretches. Embank off. Every number is a placeholder.
	Terrain = {
		Ridge = { Shape = "Blocks", Height = 0 },
		Sections = {
			{ From = 0.15, To = 0.22, Side = "Both", Material = M.Concrete }, -- training ground 1 (0.152-0.214)
			{ From = 0.425, To = 0.495, Side = "Both", Material = M.Concrete }, -- training ground 2 (0.429-0.491)
			{ From = 0.84, To = 0.91, Side = "Both", Material = M.Concrete }, -- training ground 3 (0.843-0.905)
			{ From = 0.015, To = 0.06, Side = "Both", Material = M.Grass }, -- campus gates 1 (0.021-0.053)
			{ From = 0.36, To = 0.405, Side = "Both", Material = M.Grass }, -- campus gates 2 (0.367-0.399)
			{ From = 0.65, To = 0.76, Side = "Both", Material = M.Grass }, -- campus gates 3 and the tower park
		},
		Materials = { Corridor = M.Pavement, Ridge = M.Pavement, Cliff = M.Concrete, Bed = M.Concrete },
		Embank = false,
	},
	-- Spec 5.2 / 7: bright morning. ClockTime 10, Haze 0.2, Color D6E8FA, Specular 1, Saturation +0.1 are from section
	-- 7; the rest are placeholders. orchestrator default 2026-10-31: no skybox row (engine sky and clouds); Creator
	-- Store skyboxes are off-limits after creator-store-backdoor-skybox.
	Atmosphere = Kit.Atmosphere({
		Lighting = { ClockTime = 10, EnvironmentSpecularScale = 1 },
		Atmosphere = { Density = 0.22, Haze = 0.2, Color = hex("D6E8FA"), Decay = hex("9FB8D6"), Glare = 0.15 },
		Grade = { Saturation = 0.28 }, -- baseline 0.18 + 0.1
		SunRays = { Intensity = 0.08 },
		Sky = { SunAngularSize = 21, MoonAngularSize = 11, StarCount = 3000, CelestialBodiesShown = true },
		Clouds = { Cover = 0.35, Density = 0.35, Color = hex("FFFFFF") },
	}),
	Audio = { Loop = "AmbCityPark", OneShots = { "SfxRobotServo", "SfxSchoolChime" }, Volume = 0.3, Reverb = "City" },
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Reviewed is left for the rules auditor (spec 4.1).
	-- Sound rows: Creator Store audio ids used directly (no insert, nothing to strip); creator and description checked
	-- on economy.roblox.com asset details 2026-10-31.
	Assets = {
		AcademyTowerMesh = meshRow(
			"AcademyTowerTex",
			"single tall plain modern glass skyscraper, one simple rectangular slab shape, blue reflective glass curtain walls with thin light grey horizontal floor bands and vertical mullions, flat roof with a small rooftop box and a thin mast, on a low white concrete podium with a glass lobby, no logo, no emblem, no text, clean stylized cartoon style",
			15000,
			"hero 1: generate_mesh size 24 x 114 x 16.5, segmentation none; one slab only (never an H shape); lobby faces -Z"
		),
		ToppledRobotMesh = meshRow(
			"ToppledRobotTex",
			"giant boxy generic robot lying fallen on its back on the ground, simple blocky grey metal body, square head with a glowing yellow visor slit, thick rectangular arms and legs, one arm raised straight up, yellow hazard stripe across the chest, dented panels, no logo, no numbers, no text, stylized cartoon style",
			15000,
			"hero 2: generate_mesh size 34 x 34 x 16, segmentation none; lies along X, raised arm up"
		),
		TrainingBlocksMesh = meshRow(
			"TrainingBlocksTex",
			"cluster of three plain grey concrete city buildings of different heights side by side, bare mock city training ground blocks, rows of dark empty windows, a small skybridge between two of them, one broken tilted roof slab, a rooftop water tank, concrete rubble at the base, no signs, no text, stylized cartoon style",
			15000,
			"hero 3: generate_mesh size 34 x 61 x 16, segmentation none; blank windows, no signs"
		),
		GlassTowerMesh = meshRow(
			"GlassTowerTex",
			"modern office tower with two stepped tiers, light grey concrete frame, blue glass window bands, corner fins, a thin yellow light ring at the top of each tier, rooftop unit and antenna, no logo, no text, stylized low poly cartoon style",
			3000,
			"mid: generate_mesh size 22 x 72 x 16, segmentation none"
		),
		CampusGateMesh = meshRow(
			"CampusGateTex",
			"low modern white concrete campus boundary wall with a wide plain open gateway in the middle, two tall blue glass gate pillars and a flat concrete lintel, light grey metal coping, a red sliding gate bar, no emblem, no crest, no name plate, no text, stylized low poly cartoon style",
			3000,
			"mid: generate_mesh size 30 x 12 x 6, segmentation none; no emblem"
		),
		BillboardMesh = meshRow(
			"BillboardTex",
			"roadside billboard on a single dark metal pole, white panel showing only abstract colourful shapes, a blue rectangle and a yellow circle, red light strip along the bottom edge, no letters, no words, no logo, stylized low poly cartoon style",
			1500,
			"mid: generate_mesh size 16 x 16 x 1.5, segmentation none; abstract shapes only (orchestrator default 2026-10-31: no made-up text, so no real word can appear)"
		),
		StreetLampMesh = meshRow(
			"StreetLampTex",
			"modern city street lamp, slim dark grey metal pole with a short horizontal arm and a flat rectangular light head glowing warm white, stylized low poly cartoon style",
			1000,
			"mid: generate_mesh size 4 x 16.5 x 3, segmentation none; arm points -X"
		),
		CrashBarrierMesh = meshRow(
			"CrashBarrierTex",
			"short concrete road crash barrier section, light grey jersey barrier shape with a red painted stripe along the top, stylized low poly cartoon style",
			800,
			"mid: generate_mesh size 10 x 3 x 1.5, segmentation none"
		),
		ParkTreeMesh = meshRow(
			"ParkTreeTex",
			"round leafy city park tree, straight brown trunk, full rounded bright green canopy, stylized low poly cartoon style",
			2000,
			"mid: generate_mesh size 10 x 14 x 10, segmentation none"
		),
		TrainingRobotMesh = meshRow(
			"TrainingRobotTex",
			"boxy generic training robot standing upright, simple blocky grey and dark grey metal body, square head with a glowing yellow visor slit, thick rectangular arms and legs, no logo, no numbers, no text, stylized low poly cartoon style",
			3000,
			"mid: generate_mesh size 20 x 25 x 8, segmentation none; front faces -Z"
		),
		OfficeBlockMesh = meshRow(
			"OfficeBlockTex",
			"mid rise modern office building, light grey concrete walls, a wide blue glass window band around the middle floors, a red light strip over the entrance, flat roof, no signs, no text, stylized low poly cartoon style",
			2500,
			"mid: generate_mesh size 30.3 x 38 x 26.4, segmentation none; street wall"
		),
		ShopFrontMesh = meshRow(
			"ShopFrontTex",
			"low modern two storey shop building, white walls, large blue glass shop windows along the front, a red light strip over the doors, flat roof, blank sign panel with no text, stylized low poly cartoon style",
			2500,
			"mid: generate_mesh size 30.3 x 16 x 24.4, segmentation none; street wall"
		),
		AmbCityPark = {
			Kind = "Sound",
			Id = "rbxassetid://9112841159",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9112841159: Parking Lot Ambience 1, distant freeway, light wind, birds and voices, loop, 36 s (orchestrator default 2026-10-31: birds plus far voices over a city bed)",
		},
		SfxRobotServo = {
			Kind = "Sound",
			Id = "rbxassetid://9118331528",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9118331528: Robot Servo 1, big low end clunks and switches, slow, strained, 6.5 s",
		},
		SfxSchoolChime = {
			Kind = "Sound",
			Id = "rbxassetid://9125491820",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9125491820: Door Chimes Various Tone Sequences Door Bell 12, tone sequence, 4.9 s (stands in for a school chime)",
		},
	},
}
