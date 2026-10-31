--!nonstrict
-- Track 9 (night): white dunes, dead white trees, a plain dome palace with a few towers on the horizon, a
-- crescent moon in a black sky, no mask designs. Tints only its own props and ground (never global Lighting).
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 9): Dunes 22 of Salt with Limestone
-- outcrop mesas and Basalt rock faces, a black night atmosphere, audio and the asset ledger. Mesh props keep their
-- part fallback (spec 4.2), scaled to the mesh's size.
-- IP (spec 7): the palace is a plain dome with a few square towers, never the real layout; no mask designs, no text.
local Kit = require(script.Parent.Kit)

local M, hex, v, BALL, part, post, prop, block, deadTree, gate, patch, giants, SPARKLE, particles, SAND9, TREE9, SKY9, MOON9, SHADOW9, ROCK9 =
	Kit.M,
	Kit.hex,
	Kit.v,
	Kit.BALL,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.deadTree,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SPARKLE,
	Kit.particles,
	Kit.SAND9,
	Kit.TREE9,
	Kit.SKY9,
	Kit.MOON9,
	Kit.SHADOW9,
	Kit.ROCK9

local WALL9 = hex("ECECE6") -- palace walls
local DOME9 = hex("F6F6F2")
local CRYSTAL9 = hex("EDEDF2")

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

-- `def`'s parts moved by `offset` (to combine Kit pieces into one prop)
local function moved(def, offset)
	local out = {}
	for i, p in def.Parts do
		local q = table.clone(p)
		q.Pos = p.Pos + offset
		out[i] = q
	end
	return out
end

-- Hero 1: the near palace tower. A plain square white tower on a plinth, a cornice and a small dome cap; dark slit
-- windows only. A building, so it gets a levelled pad (spec 3.2).
local function palaceTower()
	local parts = {
		part(v(12, 2, 12), v(0, 1, 0), WALL9, M.Marble),
		part(v(9, 30, 9), v(0, 17, 0), WALL9, M.Marble),
		part(v(10.5, 1, 10.5), v(0, 32.5, 0), DOME9, M.Marble),
		part(v(8, 8, 8), v(0, 33, 0), DOME9, M.Marble, BALL),
		post(3, 0.8, v(0, 38.5, 0), DOME9, M.Marble),
	}
	for _, y in { 14, 24 } do
		table.insert(parts, part(v(1.4, 4, 0.3), v(0, y, -4.6), SHADOW9, M.Slate))
	end
	return prop("PalaceTower", v(12, 40, 12), parts, { Glow = MOON9, Pad = true })
end

-- Hero 2: a grove of dead white crystal trees on a low sand mound
local function crystalGrove()
	local parts = { part(v(26, 1.5, 14), v(0, 0.75, 0), SAND9, M.Sand) }
	for _, t in { { 34, v(-3, 1, 1) }, { 24, v(7, 1, 2) }, { 18, v(-9, 1, -2) } } do
		for _, p in moved(deadTree("CrystalTree", t[1], CRYSTAL9, M.Glass), t[2]) do
			table.insert(parts, p)
		end
	end
	return prop("CrystalGrove", v(28, 35, 16), parts, { Glow = MOON9 })
end

-- Hero 3: bone-like arches. Two smooth ribbed legs lean in to a plain span; no skull or mask shapes.
local function boneArch()
	local parts = { part(v(13, 3, 3), v(0, 27, 0), TREE9, M.Marble) }
	for _, s in { -1, 1 } do
		table.insert(
			parts,
			part(v(3.5, 16, 3.5), v(-11 * s, 8, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0, -0.12 * s))
		)
		table.insert(parts, part(v(3, 12, 3), v(-8.5 * s, 21, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0, -0.45 * s)))
		table.insert(parts, part(v(4.4, 1.6, 4.4), v(-12 * s, 0.8, 0), MOON9, M.Marble)) -- knuckle at the foot
	end
	for _, x in { -4.5, -1.5, 1.5, 4.5 } do -- short ribs hanging from the span
		table.insert(parts, part(v(1.2, 5, 1.2), v(x, 23, 0), TREE9, M.Marble))
	end
	return prop("BoneArch", v(28, 28.5, 4.4), parts, { Glow = MOON9 })
end

-- Horizon: the far dome palace. A low wall, one wide plain dome on a drum and four square towers; no other detail.
local function domePalace()
	return prop("DomePalace", v(60, 30, 16), {
		part(v(60, 10, 14), v(0, 5, 0), WALL9, M.Marble),
		post(6, 16, v(0, 13, 0), WALL9, M.Marble),
		part(v(16, 16, 16), v(0, 16, 0), DOME9, M.Marble, BALL),
		part(v(5, 30, 5), v(-26, 15, 3), WALL9, M.Marble),
		part(v(4, 22, 4), v(-17, 11, 4), WALL9, M.Marble),
		part(v(5, 26, 5), v(25, 13, 3), WALL9, M.Marble),
		part(v(4, 18, 4), v(16, 9, 4), WALL9, M.Marble),
	}, { Pad = true })
end

local deadWhiteTree = deadTree("DeadWhiteTree", 14, TREE9, M.Marble)
local whiteRock = block("WhiteRock", v(5, 3, 4), hex("E4E4DE"), M.Rock)
local brokenPillar = prop("BrokenPillar", v(3, 8, 3), {
	part(v(3, 6, 3), v(0, 3, 0), TREE9, M.Marble),
	part(v(2.4, 2, 2.4), v(0.3, 7, 0), TREE9, M.Marble, nil, CFrame.Angles(0.2, 0, 0.3)),
})

-- Mesh props (Lane A). Sizes are the planned ones; phase 2 sets each to its mesh's own proportions.
local deadTreeMesh = meshed(deadWhiteTree, "DeadWhiteTreeMesh", v(8.4, 14, 8.4))
local whiteRockMesh = meshed(whiteRock, "WhiteOutcropMesh", v(5, 3, 4))
local pillarMesh = meshed(brokenPillar, "BrokenPillarMesh", v(3, 8, 3))
local crystalTreeMesh = meshed(deadTree("CrystalTree", 30, CRYSTAL9, M.Glass), "CrystalTreeMesh", v(18, 30, 18))

-- Mesh rows: generated in Studio (Lane A) with the stored prompt, at the planned Size and under MaxTris; each mesh's
-- own generated texture becomes a Texture row. Id is filled in phase 2. Reviewed is left for the rules auditor
-- (spec 4.1 step 3); close-ups go in assets/biomes/Volcano/review/.
local function meshRow(prompt, size, maxTris, notes)
	return {
		Kind = "Mesh",
		Lane = "A",
		Prompt = prompt,
		Size = size,
		MaxTris = maxTris,
		Notes = notes,
	}
end

return {
	DisplayName = "Spirit Realm Desert",
	Ground = { Color = SAND9, Material = M.Sand },
	Sky = { Color = SKY9 },
	Gate = gate(TREE9, M.Marble, MOON9),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = { deadTreeMesh, whiteRockMesh, pillarMesh },
	},
	-- Pinned heroes (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight. Fractions of the 17582-stud
	-- track: 0.25 = the first 850-stud straight pair (0.205-0.302), 0.755 = the 200-stud straight out of the dead-tree
	-- grove bends (0.752-0.763), 0.84 = the 746-stud straight toward the finish (0.817-0.860).
	Landmarks = {
		-- placeholder: x1.75 heroes are at most 28 deep, so they span about 48-76 studs from the centre line, outside
		-- the 44 corridor and inside this zone's half of the gap (orchestrator default 2026-10-31)
		Offset = 26,
		Every = 22,
		Props = {
			-- p 1: on the long straights, bone arches over the dunes
			meshed(boneArch(), "BoneArchMesh", v(28, 28.5, 4.4), { Hero = true, At = 0.25 }), -- x1.75: 49 x 50
			-- p 2: out of the grove bends
			meshed(crystalGrove(), "CrystalGroveMesh", v(28, 35, 16), { Hero = true, At = 0.755 }), -- 49 x 61
			-- p 3: the near palace tower on the straight toward the finish
			meshed(palaceTower(), "PalaceTowerMesh", v(12, 40, 12), { Hero = true, At = 0.84 }), -- 21 x 70
			crystalTreeMesh,
			block("ShadowOutcrop", v(20, 19, 14), ROCK9, M.Rock, {
				part(v(10, 8, 8), v(4, 15, 2), ROCK9, M.Rock),
			}),
			prop("PillarRuin", v(16, 16.5, 10), {
				part(v(16, 1, 10), v(0, 0.5, 0), TREE9, M.Marble),
				part(v(3, 14, 3), v(-5, 8, 0), TREE9, M.Marble),
				part(v(3, 9, 3), v(5, 5.5, 0), TREE9, M.Marble),
				part(v(12, 2, 3), v(-1, 15.5, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0, 0.1)),
			}),
		},
	},
	Horizon = {
		-- placeholder: 18 (was 55). The x2 pieces are at most 32 deep, so they span about 40-72 studs from the centre
		-- line and keep inside this zone's half of the gap.
		Offset = 18,
		Props = {
			-- the dome palace is also on the skybox horizon (SpiritSkybox); this piece repeats it nearer
			meshed(domePalace(), "DomePalaceMesh", v(60, 30, 16)),
			prop("PillarRow", v(56, 22, 10), {
				part(v(56, 2, 10), v(0, 1, 0), TREE9, M.Marble),
				part(v(4, 20, 4), v(-22, 12, 0), TREE9, M.Marble),
				part(v(4, 14, 4), v(-11, 9, 0), TREE9, M.Marble),
				part(v(4, 18, 4), v(0, 11, 0), TREE9, M.Marble),
				part(v(4, 8, 4), v(11, 6, 0), TREE9, M.Marble),
				part(v(4, 16, 4), v(22, 10, 0), TREE9, M.Marble),
				part(v(16, 2.4, 5), v(-16.5, 21, 0), TREE9, M.Marble), -- the one lintel left
			}),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		Props = {
			"DeadWhiteTree",
			"WhiteRock",
			"BrokenPillar",
			block("ShadowRock", v(6, 3, 5), ROCK9, M.Basalt),
			prop("BonePile", v(6, 1.7, 4), {
				part(v(6, 1, 1), v(0, 0.5, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0.4, 0)),
				part(v(5, 1, 1), v(0, 1.2, 0), TREE9, M.Marble, nil, CFrame.Angles(0, -0.6, 0)),
			}),
		},
		Patches = {
			patch("ShadowDune", 26, 16, SHADOW9, M.Sand),
			patch("BrightSand", 20, 14, hex("FAFAF8"), M.Sand),
			patch("DarkRock", 14, 10, ROCK9, M.Basalt),
		},
	},
	Blocks = giants({
		meshed(deadTree("GiantDeadTree", 60, TREE9, M.Marble), "DeadWhiteTreeMesh", v(36, 60, 36)),
		-- the palace stays rare (hero, horizon, skybox): the giant rows are crystal trees, not towers
		-- (orchestrator default 2026-10-31)
		meshed(deadTree("GiantCrystalTree", 60, CRYSTAL9, M.Glass), "CrystalTreeMesh", v(36, 60, 36)),
		block("WhiteMonolith", v(16, 70, 10), hex("E4E4DE"), M.Marble, {
			part(v(16.4, 2, 10.4), v(0, 50, 0), SHADOW9, M.Slate),
		}),
	}),
	Particles = particles(SPARKLE, MOON9, {
		Size = 0.5,
		Lifetime = 5,
		Rate = 5,
		Speed = 1,
		Acceleration = v(0, 0.5, 0),
		LightEmission = 0.8,
	}),
	-- Spec 3.3 / 7: Dunes 22 of Salt; two Limestone outcrop mesas (the first long straights outside, the third pair
	-- inside), whose step faces and the steepest dune flanks show Basalt rock. Every number is a placeholder.
	Terrain = {
		Ridge = { Shape = "Dunes", Height = 22, Noise = 0.03, Amp = 6 },
		Sections = {
			{
				From = 0.22,
				To = 0.29,
				Side = "Outer",
				Ridge = { Shape = "Mesa", Height = 26, Noise = 0.04, Amp = 6 },
				Material = M.Limestone,
			},
			{
				From = 0.44,
				To = 0.5,
				Side = "Inner",
				Ridge = { Shape = "Mesa", Height = 24, Noise = 0.04, Amp = 6 },
				Material = M.Limestone,
			},
		},
		Materials = { Corridor = M.Salt, Ridge = M.Salt, Cliff = M.Basalt, Bed = M.Salt },
		-- placeholder: above the 0.9 default so only the steepest dune crests at the shoulder turn to Basalt ("a few
		-- Basalt rocks"); mesa step faces are vertical and always do (orchestrator default 2026-10-31)
		CliffSlope = 1.1,
		Embank = true,
	},
	-- Spec 5.2 / 7: black night. Values are placeholders except where section 7 gives them. Hero 4, the crescent moon,
	-- is the engine moon at ClockTime 0 drawn with the in-house crescent texture (Sky.MoonTextureId); no Creator Store
	-- skybox (docs/BUGS.md creator-store-backdoor-skybox). SpiritSkybox is drawn in-house: a black sky, pale dunes and
	-- the plain dome palace on the horizon.
	Atmosphere = Kit.Atmosphere({
		Lighting = {
			ClockTime = 0,
			Brightness = 1.5,
			Ambient = hex("5A6074"), -- placeholder
			OutdoorAmbient = hex("8892A6"),
			ExposureCompensation = 0.3, -- placeholder
		},
		Atmosphere = {
			Density = 0.3,
			Offset = 0,
			Color = SKY9,
			Decay = SKY9,
			Glare = 0,
			Haze = 0,
		},
		Grade = { Saturation = -0.4, Contrast = 0.1, TintColor = hex("E9EEF5") },
		Bloom = { Intensity = 1 },
		SunRays = { Intensity = 0 },
		Sky = {
			Skybox = "SpiritSkybox",
			MoonTextureId = "CrescentMoonTex",
			SunAngularSize = 21,
			MoonAngularSize = 20, -- placeholder: a large crescent
			StarCount = 0,
			CelestialBodiesShown = true,
		},
		Clouds = { Cover = 0, Density = 0, Color = SKY9 }, -- a clear black sky
		Particles = {
			{
				Texture = "SandParticle", -- pale sand drift
				Color = SAND9,
				Size = 0.6,
				Rate = 18,
				Lifetime = 5,
				Speed = 2,
				SpreadAngle = 180,
				LightEmission = 0.3,
				Area = v(90, 8, 90),
			},
		},
	}),
	Audio = { Loop = "AmbDesertWind", OneShots = { "SfxFarHowl", "SfxSandHiss" }, Volume = 0.3, Reverb = "Arena" },
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Reviewed is left for the rules auditor (spec 4.1).
	-- Sound rows: Creator Store audio ids used directly (no insert, nothing to strip), checked on the Creator Store
	-- API 2026-10-31 (creator ProSoundEffects, free audio).
	Assets = {
		BoneArchMesh = meshRow(
			"tall smooth white arch made of two curved ribbed bone-like legs leaning together and joined by a plain span at the top, a few short ribs hanging below the span, pale ivory white, no skull, no face, no mask, stylized low poly cartoon style",
			v(28, 28.5, 4.4),
			10000,
			"hero 3: the arch opening faces -Z (the road)"
		),
		CrystalGroveMesh = meshRow(
			"small grove of three dead leafless trees made of pale white translucent crystal, thin twisted branching trunks of different heights standing on a low mound of white sand, stylized low poly cartoon style",
			v(28, 35, 16),
			15000,
			"hero 2"
		),
		PalaceTowerMesh = meshRow(
			"tall plain square white stone tower with smooth walls, a wide base plinth, a simple cornice and a small round white dome on top, a few narrow dark slit windows, no emblems and no writing, stylized low poly cartoon style",
			v(12, 40, 12),
			10000,
			"hero 1 (the near tower)"
		),
		DomePalaceMesh = meshRow(
			"distant plain white desert palace, one very large smooth white dome on a low round drum above a long low white wall, four plain square white towers of different heights around it, no emblems and no writing, stylized low poly cartoon style",
			v(60, 30, 16),
			15000,
			"horizon piece; IP: a plain dome with a few towers, never a real layout"
		),
		DeadWhiteTreeMesh = meshRow(
			"dead leafless tree with a pale bone white trunk and a few bare twisted branches, smooth surface, stylized low poly cartoon style",
			v(8.4, 14, 8.4),
			3000
		),
		CrystalTreeMesh = meshRow(
			"single dead leafless tree made of pale white translucent crystal, thin twisted trunk splitting into a few bare angular branches, stylized low poly cartoon style",
			v(18, 30, 18),
			3000
		),
		WhiteOutcropMesh = meshRow(
			"low weathered white limestone rock outcrop, smooth rounded pale grey white stone with a few cracks, stylized low poly cartoon style",
			v(5, 3, 4),
			2000
		),
		BrokenPillarMesh = meshRow(
			"broken plain white stone column, a short round smooth shaft snapped off at the top with a fallen chunk leaning on it, square base, no carvings, stylized low poly cartoon style",
			v(3, 8, 3),
			2000
		),
		SandParticle = {
			Kind = "Texture",
			Lane = "A",
			Prompt = "in-house 128 px cluster of fine soft grains with a faint haze, white on transparent, tinted sand white by the emitter",
			Notes = "drawn with python3 + numpy (assets/biomes/Volcano/sand_particle.png); uploaded in phase 2",
		},
		CrescentMoonTex = {
			Kind = "Texture",
			Lane = "A",
			Prompt = "in-house 512 px pale moon-white crescent (a disc minus an offset disc) with a soft rim glow, on transparent",
			Notes = "hero 4: Sky.MoonTextureId; drawn with python3 + numpy (assets/biomes/Volcano/crescent_moon.png)",
		},
		SpiritSkybox = {
			Kind = "Skybox",
			Lane = "A",
			Prompt = "in-house 1024 px faces: black night sky with no stars, pale dune silhouettes at the horizon, a plain dome palace silhouette (one dome, four square towers) on Ft and a smaller far one on Lf",
			-- Faces = { Bk, Dn, Ft, Lf, Rt, Up } ids are filled in phase 2, with Id = the first face
			Notes = "drawn with python3 + numpy (assets/biomes/Volcano/sky_<face>.png)",
		},
		AmbDesertWind = {
			Kind = "Sound",
			Id = "rbxassetid://9119392572",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9119392572: Space Presence 1, low airy steady wind-like ambience with a drone, loop, 41 s",
		},
		SfxFarHowl = {
			Kind = "Sound",
			Id = "rbxassetid://9113957077",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9113957077: Coyote Yowl 4, a distant howl, 6 s",
		},
		SfxSandHiss = {
			Kind = "Sound",
			Id = "rbxassetid://9118771237",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9118771237: Sand Slide 5, long hissing sand skid, 9 s",
		},
	},
}
