--!nonstrict
-- Track 10: green sky, blue-green grass, small islands over teal water, plain white dome houses with round windows,
-- tall thin ball-top trees, rock pillars, three pale suns in the sky. No orb items.
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 10): lakes with low islands in the
-- ridge band, the outer sea with scattered islands out to the skirt, land under the dome village and the tree grove,
-- an island hill at the start, a green day atmosphere, audio and the asset ledger. Mesh props keep their part
-- fallback (spec 4.2), scaled to the mesh's size.
-- IP (spec 7, TRACKS_AND_BIOMES_SPEC Track 10): no orb items with stars, no copy of a specific house design (houses
-- are plain domes), no character likenesses, no ship, no text.
local Kit = require(script.Parent.Kit)

local M, hex, v, BALL, CYL, UP, part, post, prop, block, gate, patch, giants, SPARKLE, particles, SKY10, GRASS10, WATER10, DOME10, ROCK10, HAZE10, ballTree =
	Kit.M,
	Kit.hex,
	Kit.v,
	Kit.BALL,
	Kit.CYL,
	Kit.UP,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SPARKLE,
	Kit.particles,
	Kit.SKY10,
	Kit.GRASS10,
	Kit.WATER10,
	Kit.DOME10,
	Kit.ROCK10,
	Kit.HAZE10,
	Kit.ballTree

local LEAF = hex("4FC9A8") -- lighter blue-green leaves
local TRUNK = hex("7B6A4E")
local WINDOW = hex("2E6B6B")
local DOOR = hex("3F6E4F")
local MOSS = hex("7E8F68")

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

-- `parts` moved by `offset` and appended to `list` (to combine pieces into one prop)
local function addMoved(list, parts, offset)
	for _, p in parts do
		local q = table.clone(p)
		q.Pos = p.Pos + offset
		table.insert(list, q)
	end
	return list
end

-- Plain dome house: a low round drum under a white dome, a door and three round windows on the road face (-Z).
-- Pad = true: a levelled pad on slopes (spec 3.2), like every house.
local function domeHome(name, d)
	return prop(name, v(d, d * 0.8, d), {
		post(d * 0.3, d, v(0, d * 0.15, 0), DOME10, M.SmoothPlastic),
		part(v(d, d, d), v(0, d * 0.3, 0), DOME10, M.SmoothPlastic, BALL),
		part(v(d * 0.22, d * 0.3, 0.6), v(0, d * 0.15, -d / 2), DOOR, M.SmoothPlastic),
		part(v(d * 0.12, d * 0.12, d * 0.12), v(-d * 0.26, d * 0.42, -d * 0.4), WINDOW, M.Glass, BALL),
		part(v(d * 0.12, d * 0.12, d * 0.12), v(d * 0.26, d * 0.42, -d * 0.4), WINDOW, M.Glass, BALL),
		part(v(d * 0.1, d * 0.1, d * 0.1), v(0, d * 0.62, -d * 0.36), WINDOW, M.Glass, BALL),
	}, { Pad = true })
end

-- Tall thin tree with a ball top (h studs)
local function tallTree(h)
	return {
		post(h * 0.75, h * 0.04, v(0, h * 0.375, 0), TRUNK, M.Wood),
		part(v(h * 0.32, h * 0.32, h * 0.32), v(0, h * 0.84, 0), GRASS10, M.Grass, BALL),
	}
end

-- Hero 1: a dome village cluster, three plain domes of different sizes and a tall ball-top tree behind them
local function domeVillage()
	local parts = {}
	addMoved(parts, domeHome("A", 14).Parts, v(-8, 0, 1))
	addMoved(parts, domeHome("B", 10).Parts, v(8, 0, -2))
	addMoved(parts, domeHome("C", 7).Parts, v(13, 0, 6))
	addMoved(parts, tallTree(30), v(2, 0, 7))
	return prop("DomeVillage", v(32, 30, 22), parts, { Pad = true, Glow = HAZE10 })
end

-- Hero 2: three tall rock pillars of different heights with grassy caps
local function rockPillars()
	return prop("RockPillars", v(22, 48, 18), {
		part(v(10, 44, 10), v(-5, 22, 0), ROCK10, M.Rock),
		part(v(11, 2, 11), v(-5, 45, 0), GRASS10, M.Grass),
		part(v(8, 32, 8), v(6, 16, 4), ROCK10, M.Rock),
		part(v(9, 2, 9), v(6, 33, 4), GRASS10, M.Grass),
		part(v(6, 22, 6), v(7, 11, -5), MOSS, M.Rock),
		part(v(7, 1.6, 7), v(7, 22.8, -5), GRASS10, M.Grass),
		part(v(4, 4, 4), v(-5, 46, 0), LEAF, M.Grass, BALL),
	})
end

-- Hero 3: a grove of tall thin ball-top trees on a low grassy mound
local function treeGrove()
	local parts = { part(v(24, 4, 18), v(0, 1, 0), GRASS10, M.Grass, BALL) }
	for _, t in { { -7, 36, -2 }, { 1, 30, 3 }, { 8, 26, -4 }, { -2, 22, -6 }, { 9, 18, 5 } } do
		addMoved(parts, tallTree(t[2]), v(t[1], 2, t[3]))
	end
	return prop("TreeGrove", v(24, 38, 18), parts)
end

-- Small grassy islet with a ball-top tree and a little dome: its base sits on the lake bed, its top above the water
local islet = prop("Islet", v(18, 26, 16), {
	part(v(18, 4, 16), v(0, 2, 0), ROCK10, M.Rock),
	part(v(16, 16, 14), v(0, 6, 0), GRASS10, M.Grass, BALL),
	post(10, 0.6, v(-3, 18, 1), TRUNK, M.Wood),
	part(v(5, 5, 5), v(-3, 23.5, 1), GRASS10, M.Grass, BALL),
	part(v(6, 6, 6), v(4, 13, -2), DOME10, M.SmoothPlastic, BALL),
	part(v(0.8, 0.8, 0.8), v(4, 14.5, -4.9), WINDOW, M.Glass, BALL),
})

-- Single tall rock spire with a grassy cap, rising from the water
local rockSpire = prop("RockSpire", v(8, 32, 8), {
	part(v(8, 20, 8), v(0, 10, 0), ROCK10, M.Rock),
	part(v(6, 10, 6), v(0.4, 25, 0), ROCK10, M.Rock),
	part(v(7, 1.4, 7), v(0.4, 30.7, 0), GRASS10, M.Grass),
})

local rockStack = prop("RockStack", v(4, 9, 4), {
	part(v(4, 4, 4), v(0, 2, 0), ROCK10, M.Rock),
	part(v(3, 3, 3), v(0.3, 5.5, 0), ROCK10, M.Rock),
	part(v(2, 2, 2), v(0, 8, 0.2), MOSS, M.Rock),
})

-- Small crater pool beside the road: a low rock ring round teal water
local craterPool = prop("CraterPool", v(14, 1.6, 14), {
	part(v(0.4, 11, 11), v(0, 0.5, 0), WATER10, M.Glass, CYL, UP),
	part(v(14, 1.6, 2.5), v(0, 0.8, -5.75), ROCK10, M.Rock),
	part(v(14, 1.6, 2.5), v(0, 0.8, 5.75), ROCK10, M.Rock),
	part(v(2.5, 1.6, 9), v(-5.75, 0.8, 0), ROCK10, M.Rock),
	part(v(2.5, 1.6, 9), v(5.75, 0.8, 0), ROCK10, M.Rock),
})

local HERO = { Hero = true }

-- Mesh props (Lane A). Phase 1 sizes are the generation targets; phase 2 sets each to its mesh's own proportions.
local ballTreeMesh = meshed(ballTree, "BallTreeMesh", v(7, 20.5, 7))
local shrubMesh = meshed(block("Shrub", v(5, 3, 5), LEAF, M.Grass), "ShrubMesh", v(5, 3, 5))
local rockStackMesh = meshed(rockStack, "RockStackMesh", v(4, 9, 4))
local craterPoolMesh = meshed(craterPool, "CraterPoolMesh", v(14, 1.6, 14))
local domeHouseMesh = meshed(domeHome("DomeHouse", 9), "DomeHouseMesh", v(9, 7.2, 9))
local isletMesh = meshed(islet, "IsletMesh", v(18, 26, 16))
local rockSpireMesh = meshed(rockSpire, "RockSpireMesh", v(8, 32, 8))

-- Mesh rows: generated in Studio (Lane A) with the stored prompt; each mesh's own generated texture is a Texture row.
-- Id is filled in phase 2. Reviewed is left for the rules auditor (spec 4.1 step 3); close-ups go in
-- assets/biomes/Space/review/. Tris is the generation cap (maxTriangles).
local function meshRow(id, texture, prompt, tris, notes)
	return {
		Kind = "Mesh",
		Id = id,
		Lane = "A",
		Prompt = prompt,
		Texture = texture,
		Tris = tris,
		Notes = notes,
	}
end
local function textureRow(id, mesh)
	return {
		Kind = "Texture",
		Id = id,
		Lane = "A",
		Prompt = "generated with " .. mesh .. " (same prompt)",
	}
end

return {
	DisplayName = "Green Alien Planet",
	Ground = { Color = GRASS10, Material = M.Grass },
	Sky = { Color = SKY10 },
	Gate = gate(DOME10, M.SmoothPlastic, HAZE10),
	-- Rhythm stands in the corridor (Offset 10: about 32-41 studs from the centre line; the domes' pads end by 44)
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = { ballTreeMesh, shrubMesh, domeHouseMesh, ballTreeMesh, rockStackMesh, craterPoolMesh },
	},
	-- Pinned heroes (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight. All three are corner exits,
	-- so they stand on the corner's outside: the outer side of the spiral (the open sea). Fractions of the
	-- ~21,980-stud track: the three long bends end at about 0.304, 0.617 and 0.930.
	Landmarks = {
		Offset = 40, -- placeholder: x1.75 pieces start about 60 studs from the centre line, past the 44-60 shoulder
		Every = 22,
		Props = {
			-- p 1: exit of the first long bend, the dome village bend (land section 0.29-0.325)
			meshed(domeVillage(), "DomeVillageMesh", v(32, 30, 22), { Hero = true, At = 0.305 }), -- x1.75: 56 x 38.5
			-- p 2: exit of the second bend, pillars rising from the outer sea
			meshed(rockPillars(), "RockPillarsMesh", v(22, 48, 18), { Hero = true, At = 0.618 }), -- x1.75: 38.5 x 31.5
			-- p 3: exit of the third bend, onto the finish straights (land section 0.918-0.95)
			meshed(treeGrove(), "TreeGroveMesh", v(24, 38, 18), { Hero = true, At = 0.931 }), -- x1.75: 42 x 31.5
			isletMesh,
			rockSpireMesh,
			isletMesh,
			ballTreeMesh,
		},
	},
	-- Hero landmarks without a pin, x2: pillars and groves out in the water. Hero 4 is the three suns (skybox).
	Horizon = {
		-- placeholder: 20 (as Track 3). The x2 pieces are 36 deep, so they span about 42-78 studs from the centre line
		-- and keep inside this zone's half of the gap on the inner side; on the outer side they stand in the sea.
		Offset = 20,
		Props = {
			meshed(rockPillars(), "RockPillarsMesh", v(22, 48, 18), HERO), -- x2: 44 x 96 x 36
			meshed(treeGrove(), "TreeGroveMesh", v(24, 38, 18), HERO), -- x2: 48 x 76 x 36
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		-- Water-friendly only (the ridge band is mostly lake): no shrubs, pebbles or houses, which would drown
		Props = { "BallTree", "RockStack", isletMesh, rockSpireMesh },
		-- Most patches land on the lake bed (harness: about 9 in 10), so they read as weed beds and sand bars
		Patches = {
			patch("WeedBed", 20, 14, hex("2F8F72"), M.Grass),
			patch("MossBed", 16, 12, LEAF, M.Grass),
			patch("SandBar", 14, 10, hex("D8E6B8"), M.Sand),
		},
	},
	-- Giant rows reach the outer sea: rock pillars up to 80 tall (spec 7) and big islets. No houses: their pads would
	-- level the lake bed. Spacing 120 (placeholder; default 70): scattered, not a wall of pillars.
	Blocks = giants({
		meshed(rockSpire, "RockSpireMesh", v(20, 80, 20)),
		meshed(islet, "IsletMesh", v(40, 58, 36)),
		meshed(rockPillars(), "RockPillarsMesh", v(36, 78, 29)),
	}, 120),
	-- Landmark emitters (BiomeDressing): pale and dim, so bloom does not light them into sparks
	Particles = particles(SPARKLE, HAZE10, { Size = 0.5, Lifetime = 4, Rate = 3, Speed = 1, LightEmission = 0 }),
	-- Spec 3.3 / 7: lakes in the ridge band (Hills dipping below the water; the noise lifts low islands out of it),
	-- the corridor is the land bridge, the outer sea (Far) with scattered islands out to the skirt. Every number is a
	-- placeholder. Sections (From / To = fractions of the track length): the island hill (slopes 0.005-0.027), land
	-- under the dome village (corner exit 0.304) and the tree grove (corner exit 0.930).
	Terrain = {
		Ridge = { Shape = "Hills", Height = -6, Noise = 0.03, Amp = 12 },
		Far = { Shape = "Water", Noise = 0.012, Amp = 55 },
		Water = { Level = -3, Where = "Ridge" },
		Sections = {
			{
				From = 0.002,
				To = 0.03,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = 24, Noise = 0.04, Amp = 4 },
			},
			{
				From = 0.29,
				To = 0.325,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = 8, Noise = 0.03, Amp = 3 },
			},
			{
				From = 0.918,
				To = 0.95,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = 8, Noise = 0.03, Amp = 3 },
			},
		},
		-- Corridor Ground, not grass: terrain grass grows blades up through the road (Track 6 Studio finding,
		-- orchestrator 2026-10-31). Sections set no Material, so the corridor stays Ground under them too.
		Materials = { Corridor = M.Ground, Ridge = M.LeafyGrass, Cliff = M.Rock, Bed = M.Sand },
		CliffSlope = 0.9,
		Embank = true,
	},
	-- Spec 5.2 / 7: green day. Values are placeholders except where section 7 gives them (ClockTime 13, Atmosphere
	-- Color / Decay / Haze, Tint, Water colour and transparency). The engine sun is hidden: the skybox paints three.
	Atmosphere = Kit.Atmosphere({
		Lighting = { ClockTime = 13, OutdoorAmbient = hex("7E9C88") },
		Atmosphere = {
			Density = 0.3,
			Offset = 0.15,
			Color = hex("9FD99A"),
			Decay = hex("6FB58A"),
			Glare = 0.2,
			Haze = 1,
		},
		Grade = { TintColor = hex("E8FFE8"), Saturation = 0.25 },
		SunRays = { Intensity = 0.08 },
		Sky = {
			Skybox = "SkyGreenSuns",
			SunAngularSize = 21,
			MoonAngularSize = 11,
			StarCount = 0,
			CelestialBodiesShown = false,
		},
		Clouds = { Cover = 0.35, Density = 0.3, Color = hex("E6F5DC") },
		Water = { Color = WATER10, Transparency = 0.3, Reflectance = 0.25, WaveSize = 0.2, WaveSpeed = 8 },
		Particles = {
			{
				Texture = "PollenParticle", -- light pollen
				Color = hex("EEF2C4"), -- below white so bloom does not flare them
				Size = 0.3,
				Rate = 10,
				Lifetime = 6,
				Speed = 0.4,
				SpreadAngle = 180,
				LightEmission = 0,
				Area = v(90, 16, 90),
			},
		},
	}),
	Audio = {
		Loop = "AmbAlienBreeze",
		OneShots = { "SfxPoolBubbles", "SfxFarWindTone" },
		Volume = 0.3,
		Reverb = "Plain",
	},
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Reviewed is left for the rules auditor (spec 4.1).
	-- Sound rows: Creator Store audio ids used directly (no insert, nothing to strip).
	Assets = {
		DomeVillageMesh = meshRow(
			nil,
			"DomeVillageTex",
			"small cluster of three plain round white dome houses of different sizes on a patch of blue-green grass, each a smooth white dome on a short round base with a simple dark doorway and a few small round windows, one tall thin tree with a bare straight trunk and a single round blue-green ball of leaves on top behind them, stylized cartoon style",
			15000,
			"hero 1: plain domes, no other details; doors face -Z (the road)"
		),
		RockPillarsMesh = meshRow(
			nil,
			"RockPillarsTex",
			"three tall narrow grey-green rock pillars of different heights standing close together, rough layered rock sides, flat tops covered with blue-green grass, stylized cartoon style",
			15000,
			"hero 2"
		),
		TreeGroveMesh = meshRow(
			nil,
			"TreeGroveTex",
			"grove of five very tall thin trees of different heights on a low round grassy mound, each with a bare straight thin brown trunk and a single round ball of blue-green leaves at the very top, stylized cartoon style",
			15000,
			"hero 3"
		),
		DomeHouseMesh = meshRow(
			nil,
			"DomeHouseTex",
			"small plain round white dome house, smooth white dome on a short round wall, simple dark doorway and three small round windows on the front, stylized cartoon style",
			3000,
			"plain dome, no other details; front faces -Z"
		),
		BallTreeMesh = meshRow(
			nil,
			"BallTreeTex",
			"very tall thin tree, bare straight thin brown trunk with one short side branch, single round ball of blue-green leaves at the very top and a small leaf ball on the branch, stylized low poly cartoon style",
			2000
		),
		IsletMesh = meshRow(
			nil,
			"IsletTex",
			"small round grassy island mound, rocky grey-green sides, blue-green grass on top with one tall thin tree with a round ball of leaves on top and one small plain round white dome house, stylized cartoon style",
			3000,
			"base sits on the lake bed; the top stands above the water"
		),
		RockSpireMesh = meshRow(
			nil,
			"RockSpireTex",
			"single tall narrow grey-green rock spire, rough layered rock sides, a small flat top covered with blue-green grass, stylized cartoon style",
			2000
		),
		ShrubMesh = meshRow(
			nil,
			"ShrubTex",
			"low round bush of blue-green leaves, a few round leaf clumps, stylized low poly cartoon style",
			1500
		),
		RockStackMesh = meshRow(
			nil,
			"RockStackTex",
			"small stack of three rounded grey-green rocks balanced on top of each other, the top one mossy, stylized cartoon style",
			1500
		),
		CraterPoolMesh = meshRow(
			nil,
			"CraterPoolTex",
			"small shallow round crater pool, a low ring of grey-green rocks round still teal blue-green water, flat and wide, stylized cartoon style",
			2000
		),
		DomeVillageTex = textureRow(nil, "DomeVillageMesh"),
		RockPillarsTex = textureRow(nil, "RockPillarsMesh"),
		TreeGroveTex = textureRow(nil, "TreeGroveMesh"),
		DomeHouseTex = textureRow(nil, "DomeHouseMesh"),
		BallTreeTex = textureRow(nil, "BallTreeMesh"),
		IsletTex = textureRow(nil, "IsletMesh"),
		RockSpireTex = textureRow(nil, "RockSpireMesh"),
		ShrubTex = textureRow(nil, "ShrubMesh"),
		RockStackTex = textureRow(nil, "RockStackMesh"),
		CraterPoolTex = textureRow(nil, "CraterPoolMesh"),
		PollenParticle = {
			Kind = "Texture",
			Lane = "A",
			Prompt = "in-house 128 px pollen grain: soft round body with a short spiky fuzz rim and a faint halo, white on transparent, tinted pale yellow-green by the emitter",
			Notes = "drawn with python3 + numpy (assets/biomes/Space/pollen_particle.png), uploaded from Studio",
		},
		-- Hero 4: the three suns. Faces = { Bk, Dn, Ft, Lf, Rt, Up } ids, Id = the first face (spec 4.4)
		SkyGreenSuns = {
			Kind = "Skybox",
			Lane = "A",
			Prompt = "in-house 6-face 1024 px green day sky: colour by elevation only (pale green horizon to deeper green zenith, teal below the horizon), three pale cream suns of different sizes (two on Ft, one on Rt), no clouds",
			Notes = "drawn with python3 + numpy (assets/biomes/Space/skybox/sky_<Face>.png), uploaded from Studio",
		},
		AmbAlienBreeze = {
			Kind = "Sound",
			Id = "rbxassetid://9119392572",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9119392572: Space Presence 1, low airy hollow wind-like ambience (breeze and low hum), 41 s",
		},
		SfxPoolBubbles = {
			Kind = "Sound",
			Id = "rbxassetid://9112752575",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9112752575: Bubbles Dribble Small Bloops 3, small bubbles in streams (a bubbling pool), 13.9 s",
		},
		SfxFarWindTone = {
			Kind = "Sound",
			Id = "rbxassetid://9125438342",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9125438342: Chimney Wind Airy Hiss Swirling Tone Humming, a far wind tone, 27 s",
		},
	},
}
