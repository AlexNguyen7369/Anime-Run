--!nonstrict
-- Track 2: rocky plateaus with layered strata, craters, a stone tiled ring, floating boulders, small domed huts.
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 2): Mesa terrain with craters,
-- a hot afternoon atmosphere, audio and the asset ledger. Mesh props keep their part fallback (spec 4.2), scaled to
-- the mesh's size. The w4 stacked strata towers and hovering cubes are gone: the terrain Mesa carries the plateaus.
local Kit = require(script.Parent.Kit)

local M, hex, v, part, prop, block, strata, deadTree, gate, patch, giants, SMOKE, particles, DIRT1, SAND2, ROCK2, STRATA2, SUNSET2, tileRing =
	Kit.M,
	Kit.hex,
	Kit.v,
	Kit.part,
	Kit.prop,
	Kit.block,
	Kit.strata,
	Kit.deadTree,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SMOKE,
	Kit.particles,
	Kit.DIRT1,
	Kit.SAND2,
	Kit.ROCK2,
	Kit.STRATA2,
	Kit.SUNSET2,
	Kit.tileRing

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

local HERO = { Hero = true }

-- Fallback shapes (the meshes replace them once reviewed)
local spire = strata("RockSpire", 6, 8, 6, ROCK2, STRATA2, 3)
local floating = prop("FloatingBoulders", v(36, 34, 36), {
	part(v(30, 3, 30), v(0, 1.5, 0), STRATA2, M.Rock),
	part(v(9, 12, 8), v(-9, 18, 2), ROCK2, M.Rock, nil, CFrame.Angles(0.2, 0.4, 0.1)),
	part(v(9, 11, 8), v(0, 27, -2), SAND2, M.Rock, nil, CFrame.Angles(-0.1, 0.8, 0.2)),
	part(v(8, 11, 7), v(9, 20, 3), ROCK2, M.Rock, nil, CFrame.Angles(0.1, -0.3, -0.2)),
}, { Tag = "BiomeBob" }) -- Client/BiomeAmbience bobs it from the server's BasePivot (mesh streams in late)
local hut = prop("CapsuleHut", v(14, 8, 14), {
	part(v(14, 8, 14), v(0, 3, 0), hex("F2EFE6"), M.SmoothPlastic, Kit.BALL),
	part(v(4, 5, 0.6), v(0, 2.5, -6.6), hex("5A6878"), M.SmoothPlastic),
	part(v(14.4, 0.8, 14.4), v(0, 1, 0), SUNSET2, M.SmoothPlastic),
}, { Glow = SUNSET2 })
local craterRim = prop("CraterRim", v(24, 6, 24), {
	part(v(24, 2, 5), v(0, 1, -9.5), ROCK2, M.Rock),
	part(v(24, 2.5, 5), v(0, 1.25, 9.5), STRATA2, M.Rock),
	part(v(5, 3, 14), v(-9.5, 1.5, 0), ROCK2, M.Rock),
	part(v(5, 6, 14), v(9.5, 3, 0), STRATA2, M.Rock),
})

local rockSpire = meshed(spire, "RockSpireMesh", v(6, 8, 6))
local boulder = meshed(block("Boulder", v(6, 5, 4.4), ROCK2, M.Rock), "BoulderMesh", v(6, 5, 4.4))
local deadShrub = meshed(deadTree("DeadShrub", 6, hex("7A5A3E"), M.Wood), "DeadShrubMesh", v(6, 4.8, 5.3))

-- Mesh rows: generated in Studio (Lane A) with the stored prompt; each mesh's own generated texture is a Texture row.
-- Reviewed is left for the rules auditor (spec 4.1 step 3); close-ups are in assets/biomes/Forest/review/.
local function meshRow(id, texture, prompt, tris, notes)
	return {
		Kind = "Mesh",
		Id = id,
		Lane = "A",
		Prompt = prompt,
		Texture = texture,
		Tris = tris,
		Reviewed = "2026-10-31 rules-auditor",
		Notes = notes,
	}
end
local function textureRow(id, mesh)
	return {
		Kind = "Texture",
		Id = id,
		Lane = "A",
		Prompt = "generated with " .. mesh .. " (same prompt)",
		Reviewed = "2026-10-31 rules-auditor",
	}
end

return {
	DisplayName = "Tournament Wasteland",
	Ground = { Color = SAND2, Material = M.Sandstone },
	Sky = { Color = hex("7FB8E0") },
	Gate = gate(ROCK2, M.Rock, SUNSET2),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = { rockSpire, boulder, deadShrub },
	},
	-- Pinned defs (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight.
	Landmarks = {
		Offset = 20, -- placeholder: landmarks stand on the corridor edge and shoulder, below the mesa steps
		Every = 22,
		Props = {
			-- hero 1, mid-track (TRACKS_AND_BIOMES_SPEC References: "pass the open stone ring at mid-track")
			meshed(tileRing(), "TileRingMesh", v(28, 7.5, 29.7), { Hero = true, At = 0.5 }), -- x1.75: 49 x 52
			meshed(hut, "DomeHutMesh", v(14, 8.1, 14.1)),
			meshed(craterRim, "CraterRimMesh", v(24, 15.2, 24)),
			meshed(hut, "DomeHutMesh", v(18, 10.4, 18.1)),
		},
	},
	-- Hero landmarks without a pin: x2 at the horizon scale, footprint at most 60 x 60 (placeholder)
	Horizon = {
		-- placeholder: 30, not 55. At 55 (and still at 40) the x2 pieces stood 80+ studs out, across the gap midline,
		-- on Track 1's houses; at 30 they stand about 72 out (36-40 wide after x2) and keep to this zone's band.
		Offset = 30,
		Props = {
			meshed(strata("BrokenSpire", 18, 36, 18, ROCK2, STRATA2, 6), "RockSpireMesh", v(18, 36, 18), HERO),
			meshed(floating, "FloatingBouldersMesh", v(20, 18.9, 20), HERO),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 170,
		Props = {
			"Boulder",
			"DeadShrub",
			"RockSpire",
			block("FlatRock", v(8, 2, 6), ROCK2, M.Rock),
		},
		Patches = {
			patch("Scorch", 18, 14, hex("4A3828"), M.Ground),
			patch("CrackedEarth", 26, 20, hex("C49E6C"), M.Sandstone),
			patch("Pebbles", 14, 10, DIRT1, M.Pebble),
		},
	},
	Blocks = giants({
		meshed(strata("GiantSpire", 30, 50, 30, ROCK2, STRATA2, 5), "RockSpireMesh", v(30, 50, 30)),
		meshed(floating, "FloatingBouldersMesh", v(30, 28.4, 30)),
		meshed(block("BoulderPile", v(24, 20, 17.6), ROCK2, M.Rock), "BoulderMesh", v(24, 20, 17.6)),
	}),
	Particles = particles(SMOKE, SAND2, { Size = 3, Lifetime = 4, Rate = 4, Speed = 2, Transparency = 0.5 }),
	-- Spec 3.3 / 7: Mesa 40 steps of Sandstone over a Ground floor, with crater pits in the ridge band.
	-- Every number is a placeholder.
	Terrain = {
		Ridge = { Shape = "Mesa", Height = 40, Noise = 0.03, Amp = 6 },
		Craters = { Count = 14, Radius = 30, Depth = 8 },
		Materials = { Corridor = M.Ground, Ridge = M.Sandstone, Cliff = M.Sandstone, Bed = M.Ground },
		CliffSlope = 0.9,
		-- placeholder: the corridor rises under the Hill ramps (to EMBANK_BELOW under the lowest road Y within
		-- TerrainShape.EMBANK_REACH, framework fix 2026-10-31)
		Embank = true,
	},
	-- Spec 5.2 / 7: hot afternoon. Values are placeholders except where section 7 gives them.
	Atmosphere = Kit.Atmosphere({
		Lighting = { ClockTime = 16.5 },
		Atmosphere = { Density = 0.3, Haze = 1.2, Glare = 0.4, Color = hex("E8C9A0"), Decay = hex("A8865E") },
		Grade = { Saturation = 0.2, TintColor = hex("FFF0DC") },
		SunRays = { Intensity = 0.12 },
		Sky = {
			Skybox = "SkyArid",
			SunAngularSize = 21,
			MoonAngularSize = 11,
			StarCount = 3000,
			CelestialBodiesShown = true,
		},
		Clouds = { Cover = 0.2, Density = 0.3, Color = hex("F2E6D0") },
		Particles = {
			{
				Texture = "DustParticle",
				Color = hex("BC9C74"), -- darker than the sand so bloom does not light the puffs like sparks
				Size = 4,
				Rate = 6,
				Lifetime = 5,
				Speed = 3,
				SpreadAngle = 40,
				LightEmission = 0,
				Area = v(90, 10, 90),
			},
		},
	}),
	Audio = {
		Loop = "AmbWastelandWind",
		OneShots = { "SfxRockCrack", "SfxPebbles" },
		Volume = 0.35,
		Reverb = "Mountains",
	},
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Tris is the generation cap.
	Assets = {
		TileRingMesh = meshRow(
			"rbxassetid://113733409367174",
			"TileRingTex",
			"large square stone fighting arena platform made of pale cream stone tiles in a grid, low stone walls along the edges with a gap for steps, short square stone corner posts, plain with no banners and no text, stylized low poly cartoon style",
			10000,
			"hero 1: generic tiled ring, no banner, no text"
		),
		RockSpireMesh = meshRow(
			"rbxassetid://132644964386591",
			"RockSpireTex",
			"very tall rough natural rock pillar standing in a desert, irregular craggy sides with ledges and cracks, horizontal tan and brown sandstone layers, top broken off at an angle with fallen rocks around the base, stylized cartoon style",
			8000,
			"hero 2 (horizon), also the giant and rhythm spires"
		),
		FloatingBouldersMesh = meshRow(
			"rbxassetid://102020389453181",
			"FloatingBouldersTex",
			"low cracked sandstone rock base on the ground with three separate jagged boulders hovering high in the air above it, clear empty gaps of air between the base and each boulder, boulders at different heights, tan and brown layered rock, stylized low poly cartoon style",
			10000,
			"hero 3: the base sits on the ground, so the boulders float without a lift offset"
		),
		DomeHutMesh = meshRow(
			"rbxassetid://89669846005590",
			"DomeHutTex",
			"small plain white rounded dome hut house, smooth white walls, one grey sliding door, two small round windows, an orange stripe around the base, plain with no logos, no letters and no symbols, stylized cartoon style",
			3000,
			"no brand mark (front and back checked)"
		),
		CraterRimMesh = meshRow(
			"rbxassetid://97604759257824",
			"CraterRimTex",
			"irregular ring of jagged tilted rock shards and cracked ground plates pushed up around a shallow blast hole, uneven heights, gaps between shards, scattered pebbles, tan and brown sandstone, stylized low poly cartoon style",
			3000
		),
		BoulderMesh = meshRow(
			"rbxassetid://124963758825167",
			"BoulderTex",
			"group of three rough tan sandstone boulders of different sizes resting together, cracked faceted rock with faint brown layers, stylized low poly cartoon style",
			1500
		),
		DeadShrubMesh = meshRow(
			"rbxassetid://138554857925563",
			"DeadShrubTex",
			"small dry dead desert shrub with bare twisted grey brown branches and no leaves, growing from a small clump of dry dirt, stylized low poly cartoon style",
			1500
		),
		TileRingTex = textureRow("rbxassetid://120289390238394", "TileRingMesh"),
		RockSpireTex = textureRow("rbxassetid://108596827652382", "RockSpireMesh"),
		FloatingBouldersTex = textureRow("rbxassetid://121695982945050", "FloatingBouldersMesh"),
		DomeHutTex = textureRow("rbxassetid://74804615742127", "DomeHutMesh"),
		CraterRimTex = textureRow("rbxassetid://118305360309275", "CraterRimMesh"),
		BoulderTex = textureRow("rbxassetid://121801363358935", "BoulderMesh"),
		DeadShrubTex = textureRow("rbxassetid://91582599301992", "DeadShrubMesh"),
		DustParticle = {
			Kind = "Texture",
			Id = "rbxassetid://100913182484759",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "A",
			Prompt = "in-house 128 px soft round dust puff, white-grey on transparent, tinted sand by the emitter",
			Notes = "drawn with python3 (assets/biomes/Forest/dust_particle.png), uploaded from Studio",
		},
		SkyArid = {
			Kind = "Skybox",
			Id = "rbxassetid://148345460",
			Faces = {
				Bk = "rbxassetid://148345460",
				Dn = "rbxassetid://148345469",
				Ft = "rbxassetid://148345455",
				Lf = "rbxassetid://148345446",
				Rt = "rbxassetid://148345440",
				Up = "rbxassetid://148345466",
			},
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "Tarbunlier",
			Notes = "Creator Store 11088930981 (Arid Sky: hazy pale sky, plain clouds); no scripts",
		},
		AmbWastelandWind = {
			Kind = "Sound",
			Id = "rbxassetid://102354126031648",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "Vibe Shift Studios",
			Notes = "Creator Store 102354126031648: desert_wind_loop, 10 s (verified creator)",
		},
		SfxRockCrack = {
			Kind = "Sound",
			Id = "rbxassetid://9125869504",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9125869504: rock cracks, rock-on-rock impact with debris, 1.3 s",
		},
		SfxPebbles = {
			Kind = "Sound",
			Id = "rbxassetid://9117270138",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9117270138: pebbles movement, small handfuls, 5.9 s",
		},
	},
}
