--!nonstrict
-- Track 8: floating grassy islands, waterfalls into clouds, vine bridges, generic stone columns and arches
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 8): the road runs on grassy
-- islands with Rock sides; the ridge is a `Drop` to the Snow cloud deck at Y -40 under a bright, hazy high sky. Two
-- pools sit beside the waterfall bends. Mesh props keep their part fallback (spec 4.2), scaled to the mesh's size.
-- IP (spec 7): no copy of the film's castle or robot. Ruins stay low, generic columns and arches: no round tiered
-- castle, no towers, no domes, no tree-crowned citadel, no figures. No text anywhere.
--
-- Placement on a Drop biome (orchestrator default 2026-10-31):
-- - Only the corridor (0-44 studs from the centre line) is island ground. Past the 44-60 shoulder every prop snaps
--   down to the cloud deck at -40, so props there are tall or floating and rise out of the clouds.
-- - Small props (Rhythm, Scatter, the padded ruin hut) stay inside 44 so they stand on the island.
-- - Big props (Landmarks, Horizon, Blocks) start 60 studs out and are at most about 17 studs deep, so they stay inside
--   this zone's half of the gap (midline about 77) and none sits in the 44-60 band where padded footprints can float.
local Kit = require(script.Parent.Kit)

local M, hex, v, BALL, part, post, prop, block, ball, roundTree, house, gate, patch, giants, SMOKE, particles, DIRT1, GRASS8, ROCK8, RUIN8, CLOUD8, SKY8, FALL8 =
	Kit.M,
	Kit.hex,
	Kit.v,
	Kit.BALL,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.ball,
	Kit.roundTree,
	Kit.house,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SMOKE,
	Kit.particles,
	Kit.DIRT1,
	Kit.GRASS8,
	Kit.ROCK8,
	Kit.RUIN8,
	Kit.CLOUD8,
	Kit.SKY8,
	Kit.FALL8

local LEAF = hex("5FAE52")
local MOSS = hex("5E7A3C")
local ROOT = hex("6B5A3E")
local DARK_ROCK = hex("7A6A58")
local BARK = hex("6B4A2E")
local MIST = hex("E6F3FF")

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

-- An upside-down rock island under a grass top at `top`, `w` wide and `d` deep: tiers that narrow downward, roots
-- and a vine hanging below. Returns its parts (callers add what stands on top).
local function islandBody(top, w, d)
	return {
		part(v(w, 2, d), v(0, top - 1, 0), GRASS8, M.Grass),
		part(v(w * 0.92, 7, d * 0.92), v(0, top - 5.5, 0), ROCK8, M.Rock),
		part(v(w * 0.65, 6, d * 0.7), v(0, top - 12, 0), ROCK8, M.Rock),
		part(v(w * 0.4, 6, d * 0.45), v(0, top - 18, 0), DARK_ROCK, M.Rock),
		part(v(w * 0.18, 6, d * 0.22), v(0, top - 24, 0), DARK_ROCK, M.Rock),
		part(v(0.5, 12, 0.5), v(-w * 0.25, top - 15, -d * 0.2), ROOT, M.Wood), -- hanging roots
		part(v(0.5, 9, 0.5), v(w * 0.2, top - 13, d * 0.25), ROOT, M.Wood),
		part(v(0.4, 14, 0.4), v(w * 0.05, top - 19, -d * 0.3), MOSS, M.Grass), -- vine
	}
end

local function add(parts, more)
	for _, p in more do
		table.insert(parts, p)
	end
	return parts
end

-- Hero 1: a floating ruin island. Low generic ruins on its grass top: a short colonnade (one column whole, one
-- broken, one stump) and one plain arch; a thin waterfall spills off the road-facing edge into the clouds.
local function ruinIsland()
	local parts = islandBody(40, 20, 10)
	for i, x in { -8, -4.5, -1 } do
		local h = ({ 8, 5, 3 })[i]
		table.insert(parts, part(v(2.2, 0.6, 2.2), v(x, 40.3, 2), RUIN8, M.Rock)) -- plinth
		table.insert(parts, post(h, 1.5, v(x, 40.6 + h / 2, 2), RUIN8, M.Rock))
	end
	return prop(
		"RuinIsland",
		v(20, 50, 10),
		add(parts, {
			part(v(2.4, 0.8, 2.4), v(-8, 49, 2), RUIN8, M.Rock), -- capital on the whole column
			post(9, 1.6, v(3, 44.5, -1), RUIN8, M.Rock), -- arch legs
			post(9, 1.6, v(8.5, 44.5, -1), RUIN8, M.Rock),
			part(v(7.5, 1.4, 2), v(5.75, 49.3, -1), RUIN8, M.Rock), -- lintel
			part(v(3, 1.2, 2), v(5.75, 47.9, -1), RUIN8, M.Rock),
			part(v(4, 0.8, 2.4), v(-3, 40.4, -2.5), RUIN8, M.Slate), -- fallen block
			part(v(3, 26, 0.6), v(7.5, 26, -5.2), FALL8, M.Glass), -- waterfall off the edge
		}),
		{ Tag = "BiomeBob" }
	)
end

-- Hero 2: a large broad tree on a floating rock, roots hanging below
local function skyTree()
	local parts = add(islandBody(30, 16, 10), {
		post(16, 2.6, v(0, 37, 0), BARK, M.Wood),
		part(v(3.5, 1.4, 3.5), v(0, 29.7, 0), BARK, M.Wood), -- root flare
	})
	for _, c in { v(-4.5, 46, 0), v(4.5, 47, 0), v(0, 50.5, 0), v(0, 45, 0) } do
		table.insert(parts, part(v(10, 10, 10), c, LEAF, M.Grass, BALL))
	end
	return prop("SkyTree", v(18, 56, 10), parts, { Tag = "BiomeBob" })
end

-- Hero 3: a tall stone pillar rising out of the clouds, grass on top, a waterfall down its road face into the clouds
local function waterfallPillar()
	return prop("WaterfallPillar", v(12, 64.5, 10), {
		part(v(12, 30, 10), v(0, 15, 0), ROCK8, M.Rock),
		part(v(10, 22, 8.5), v(0, 41, 0.5), DARK_ROCK, M.Rock),
		part(v(11, 8, 9), v(0, 56, 0), ROCK8, M.Rock),
		part(v(12.2, 1.5, 10.2), v(0, 30, 0), MOSS, M.Grass), -- moss band
		part(v(12, 2, 10), v(0, 61, 0), GRASS8, M.Grass),
		part(v(5, 5, 5), v(-2, 62, 1), LEAF, M.Grass, BALL),
		part(v(4, 58, 0.6), v(2, 31, -5.3), FALL8, M.Glass), -- waterfall
		part(v(6, 6, 6), v(2, 3, -4.5), CLOUD8, M.SmoothPlastic, BALL), -- spray where it meets the clouds
	})
end

-- Mid props
local floatingRock = prop(
	"FloatingRock",
	v(10, 36, 8),
	add(islandBody(34, 10, 8), { part(v(4, 4, 4), v(-2, 35, 1), LEAF, M.Grass, BALL) }),
	{ Tag = "BiomeBob" }
)
local brokenColumn = prop("BrokenColumn", v(3.4, 10.4, 3.4), {
	part(v(3.4, 1, 3.4), v(0, 0.5, 0), RUIN8, M.Rock),
	post(8, 2.4, v(0, 5, 0), RUIN8, M.Rock),
	part(v(2.4, 1.6, 2.4), v(0.4, 9.6, 0), RUIN8, M.Rock, nil, CFrame.Angles(0.3, 0, 0.2)),
	part(v(2.5, 0.4, 2.5), v(0, 1.2, 0), MOSS, M.Grass), -- moss ring
})
local ruinArch = prop("RuinArch", v(12, 12.4, 3), {
	part(v(3, 1, 3), v(-4.5, 0.5, 0), RUIN8, M.Rock),
	part(v(3, 1, 3), v(4.5, 0.5, 0), RUIN8, M.Rock),
	post(10, 2, v(-4.5, 6, 0), RUIN8, M.Rock),
	post(10, 2, v(4.5, 6, 0), RUIN8, M.Rock),
	part(v(12, 1.4, 2.6), v(0, 11.7, 0), RUIN8, M.Rock),
	part(v(4, 1, 2.8), v(-3, 12.4, 0), GRASS8, M.Grass), -- grass grown on the lintel
	part(v(0.4, 5, 0.4), v(2, 9, -1.1), MOSS, M.Grass), -- hanging vine
})
local islandTree = roundTree("IslandTree", 14, BARK, LEAF, M.Grass, GRASS8)
-- A plank and vine bridge from the island edge out over the clouds (visual only). Its length runs along Z, away from
-- the road: at Rhythm Offset 10 it spans about 30-60 studs off the centre line.
local vineBridge = prop("VineBridge", v(7, 7, 30), {
	part(v(6, 0.6, 30), v(0, 3, 0), DIRT1, M.WoodPlanks),
	part(v(0.3, 0.3, 30), v(-3, 5.5, 0), MOSS, M.Fabric), -- vine hand ropes
	part(v(0.3, 0.3, 30), v(3, 5.5, 0), MOSS, M.Fabric),
	post(7, 0.8, v(-3, 3.5, -14), BARK, M.Wood),
	post(7, 0.8, v(3, 3.5, -14), BARK, M.Wood),
	post(5, 0.6, v(-3, 4.5, 14), BARK, M.Wood),
	post(5, 0.6, v(3, 4.5, 14), BARK, M.Wood),
	part(v(0.3, 4, 0.3), v(-3, 1.5, 6), MOSS, M.Grass), -- vines hanging under it
	part(v(0.3, 5, 0.3), v(3, 1, 10), MOSS, M.Grass),
})
-- A small ruined stone hut with a mossy roof: a building, so it gets a levelled pad (Kit.house sets Pad = true)
local ruinHut = house("RuinHut", 9, 7, 8, RUIN8, MOSS, {
	WallMaterial = M.Cobblestone,
	RoofMaterial = M.Grass,
	Trim = ROOT,
	Window = hex("3A3F3A"),
	WindowMaterial = M.Slate,
})

-- Mesh props (Lane A). Sizes are the generation boxes; phase 2 sets each to the generated mesh's own proportions.
local floatingRockMesh = meshed(floatingRock, "FloatingRockMesh", floatingRock.Size)
local brokenColumnMesh = meshed(brokenColumn, "BrokenColumnMesh", brokenColumn.Size)
local ruinArchMesh = meshed(ruinArch, "RuinArchMesh", ruinArch.Size)
local islandTreeMesh = meshed(islandTree, "IslandTreeMesh", islandTree.Size)
local vineBridgeMesh = meshed(vineBridge, "VineBridgeMesh", vineBridge.Size)
local ruinHutMesh = meshed(ruinHut, "RuinHutMesh", ruinHut.Size)

-- Mesh rows: generated in Studio (Lane A) with `generate_mesh` (textPrompt = Prompt, size = Gen, maxTriangles = Tris,
-- segmentation "none"); each mesh's own generated texture is a Texture row. Id comes with the phase 2 upload.
-- Reviewed is left for the rules auditor (spec 4.1 step 3); close-ups go in assets/biomes/Snow/review/.
local function meshRow(texture, prompt, size, tris, notes)
	return {
		Kind = "Mesh",
		Lane = "A",
		Prompt = prompt,
		Texture = texture,
		Gen = string.format("size %g x %g x %g, maxTriangles %d, segmentation none", size.X, size.Y, size.Z, tris),
		Tris = tris,
		Notes = notes,
	}
end
local function textureRow(mesh)
	return { Kind = "Texture", Lane = "A", Prompt = "generated with " .. mesh .. " (same prompt)" }
end

-- Blocks: one row of giants that rise out of the clouds. Near 40 puts each road-side face 60 studs out, past the
-- 44-60 shoulder; at most 13 deep, so they end inside the ~77 midline. Orchestrator default 2026-10-31.
local blocks = giants({
	prop("GiantPillar", v(14, 92, 12), {
		part(v(14, 50, 12), v(0, 25, 0), ROCK8, M.Rock),
		part(v(11, 30, 10), v(0, 65, 0), DARK_ROCK, M.Rock),
		part(v(12, 3, 11), v(0, 81.5, 0), GRASS8, M.Grass),
		part(v(10, 10, 10), v(-1, 87, 0), LEAF, M.Grass, BALL),
		part(v(0.5, 30, 0.5), v(4, 64, -5.1), MOSS, M.Grass), -- vine
	}),
	meshed(skyTree(), "SkyTreeMesh", v(23.4, 72.8, 13)), -- x1.3: its grass top sits at road height
	meshed(floatingRock, "FloatingRockMesh", v(16, 57.6, 12.8)), -- x1.6
}, 90)
blocks.Near = 40
blocks.Rows = 1 -- a second row would sit across the midline

return {
	DisplayName = "Sky Islands",
	Ground = { Color = GRASS8, Material = M.Grass },
	Sky = { Color = SKY8 },
	Gate = gate(RUIN8, M.Rock),
	-- Offset 10: road-side faces 30 studs out; every rhythm prop but the bridge ends inside 44 (on the island). The
	-- hut (Pad) spans 30-41.
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = { brokenColumnMesh, islandTreeMesh, ruinArchMesh, vineBridgeMesh, ruinHutMesh, islandTreeMesh },
	},
	-- Pinned heroes (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight. Fractions of the 14076-stud
	-- track: 0.21 = the 474-stud straight after the first vine bridge (0.199-0.232), 0.40 = the 583-stud straight
	-- after the first waterfall bends (0.385-0.426), 0.61 = the 611-stud straight after the second vine bridge
	-- (0.591-0.635).
	Landmarks = {
		-- placeholder: edge 20 + 40 puts every landmark's road-side face 60 studs out, over the cloud deck past the
		-- shoulder; x1.75 props at most 10 deep reach about 77 (the midline).
		Offset = 40,
		Every = 20,
		Props = {
			meshed(ruinIsland(), "RuinIslandMesh", v(20, 50, 10), { Hero = true, At = 0.21 }),
			meshed(waterfallPillar(), "WaterfallPillarMesh", v(12, 64.5, 10), { Hero = true, At = 0.4 }),
			meshed(skyTree(), "SkyTreeMesh", v(18, 56, 10), { Hero = true, At = 0.61 }),
			floatingRockMesh,
			prop("RockSpire", v(8, 52, 8), {
				part(v(8, 26, 8), v(0, 13, 0), ROCK8, M.Rock),
				part(v(6, 18, 6), v(0, 35, 0), DARK_ROCK, M.Rock),
				part(v(6.5, 1.5, 6.5), v(0, 44.75, 0), GRASS8, M.Grass),
				part(v(5, 5, 5), v(0, 48, 0), LEAF, M.Grass, BALL),
				part(v(0.4, 16, 0.4), v(2.5, 36, -3.2), MOSS, M.Grass),
			}),
		},
	},
	Horizon = {
		-- placeholder: the placement floor is Landmarks.Offset (60 studs out); x2 pieces at most 8 deep span about
		-- 60-76 and stay in this zone's half of the gap.
		Offset = 40,
		Props = {
			prop(
				"DistantIsland",
				v(18, 47, 8),
				add(islandBody(44, 18, 8), {
					part(v(6, 6, 6), v(-4, 44, 0), LEAF, M.Grass, BALL),
					part(v(2, 24, 0.4), v(6, 30, -4.2), FALL8, M.Glass), -- waterfall into the clouds
				}),
				{ Tag = "BiomeBob" }
			),
			prop("CloudColumn", v(16, 34, 8), {
				part(v(8, 8, 8), v(-4, 30, 0), CLOUD8, M.SmoothPlastic, BALL),
				part(v(8, 8, 8), v(3, 27, 0), CLOUD8, M.SmoothPlastic, BALL),
				part(v(7, 7, 7), v(-1, 23, 0), MIST, M.SmoothPlastic, BALL),
				part(v(6, 18, 6), v(0, 11, 0), ROCK8, M.Rock), -- a stone stack poking through the cloud
			}),
		},
	},
	-- Scatter on the island: x1.5 props start 28 studs out (the road's clearance) and mostly end inside 44
	Scatter = {
		Every = 2,
		Near = 8,
		Far = 16,
		Props = {
			"BrokenColumn",
			"IslandTree",
			ball("CloudPuff", 6, CLOUD8, M.SmoothPlastic),
			block("MossRock", v(5, 3.6, 4), ROCK8, M.Rock, { part(v(4, 0.8, 3), v(0, 3.2, 0), GRASS8, M.Grass) }),
			block("FallenColumn", v(8, 2.2, 2.2), RUIN8, M.Rock),
		},
		Patches = {
			patch("Meadow", 18, 12, hex("9AD47F"), M.Grass),
			patch("StoneTiles", 14, 10, RUIN8, M.Slate),
			patch("Wildflowers", 12, 8, hex("F2E6A0"), M.Grass),
		},
	},
	Blocks = blocks,
	-- Landmark particles (Kit format): spray mist drifting off every landmark (the waterfalls)
	Particles = particles(SMOKE, MIST, { Size = 4, Lifetime = 5, Rate = 4, Speed = 1, Transparency = 0.55 }),
	-- Spec 3.3 / 7: grassy islands (corridor) with Rock sides; the ridge is a Drop to the Snow cloud deck at -40. Two
	-- pools (Water sections: basin at -9, water at -3) beside the waterfall bends (0.314-0.385 and 0.715-0.785), one
	-- on each side. Every number is a placeholder.
	Terrain = {
		Ridge = { Shape = "Drop" },
		Sections = {
			{ From = 0.33, To = 0.36, Side = "Inner", Water = { Level = -3 } },
			{ From = 0.735, To = 0.765, Side = "Outer", Water = { Level = -3 } },
		},
		Materials = { Corridor = M.Grass, Ridge = M.Grass, Cliff = M.Rock, Bed = M.Snow },
		CliffSlope = 0.6, -- placeholder: the island flanks read as Rock all the way down
		Embank = true,
	},
	-- Spec 5.2 / 7: bright high sky. ClockTime, Atmosphere Density / Offset / Color, Clouds and Bloom are section 7's;
	-- the rest are placeholders. No skybox row: the engine sky and Terrain clouds over the cloud deck.
	Atmosphere = Kit.Atmosphere({
		Lighting = {
			ClockTime = 13,
			Brightness = 3,
			Ambient = hex("5A6878"),
			OutdoorAmbient = hex("A2B4C8"),
			ExposureCompensation = 0.1,
		},
		Atmosphere = {
			Density = 0.35,
			Offset = 0.5,
			Color = hex("E8F4FF"),
			Decay = hex("B8DCF5"),
			Glare = 0.2,
			Haze = 1.2, -- the far cloud sea fades to white
		},
		Grade = { TintColor = hex("F4FAFF"), Saturation = 0.12 },
		Bloom = { Intensity = 0.8 },
		SunRays = { Intensity = 0.1, Spread = 0.6 },
		Sky = {
			SunAngularSize = 21,
			MoonAngularSize = 11,
			StarCount = 3000,
			CelestialBodiesShown = true,
		},
		Clouds = { Cover = 0.6, Density = 0.5, Color = CLOUD8 },
		Water = { Color = FALL8, Transparency = 0.35, Reflectance = 0.2, WaveSize = 0.05, WaveSpeed = 6 },
		Particles = {
			{
				Texture = "CloudWispParticle", -- slow cloud wisps; the tall box puts many below the road
				Color = CLOUD8,
				Size = 9,
				Rate = 6,
				Lifetime = 10,
				Speed = 1.5,
				SpreadAngle = 40,
				LightEmission = 0.15,
				Area = v(160, 50, 160),
			},
			{
				Texture = "MistParticle", -- fine spray mist
				Color = MIST,
				Size = 0.8,
				Rate = 10,
				Lifetime = 5,
				Speed = 0.6,
				SpreadAngle = 180,
				LightEmission = 0.3,
				Area = v(160, 50, 160),
			},
		},
	}),
	-- One loop per biome (spec 6): high wind (the waterfall roar alternative is in its Notes). One-shots: a bird call
	-- and a wind gust.
	Audio = { Loop = "AmbHighWind", OneShots = { "SfxHawkCall", "SfxWindGust" }, Volume = 0.35, Reverb = "Mountains" },
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Reviewed is left for the rules auditor (spec 4.1).
	-- Sound rows: Creator Store ids used directly (no insert, nothing to strip; BUGS creator-store-backdoor-skybox);
	-- creator, type and length checked on the Roblox economy API 2026-10-31.
	Assets = {
		RuinIslandMesh = meshRow(
			"RuinIslandTex",
			"small floating island of rock in the sky, flat grassy top, rocky underside tapering to a point with hanging roots and vines, a few weathered pale stone columns on top with two of them broken, one simple stone arch, a thin waterfall pouring off one edge, no buildings and no towers, stylized cartoon style",
			v(20, 50, 10),
			15000,
			"hero 1 (BiomeBob): low generic ruins only, never a castle silhouette; waterfall faces -Z"
		),
		SkyTreeMesh = meshRow(
			"SkyTreeTex",
			"one large broad leafy green tree growing on a small floating rock island, thick brown trunk, round puffy canopy, grassy top, rocky underside tapering to a point with long roots hanging below, stylized cartoon style",
			v(18, 56, 10),
			15000,
			"hero 2 (BiomeBob); also a Blocks giant"
		),
		WaterfallPillarMesh = meshRow(
			"WaterfallPillarTex",
			"very tall narrow natural stone pillar of brown rock with mossy ledges, grass and a small bush on its flat top, a long thin blue waterfall pouring down one face from the top to the bottom, white spray at the base, stylized cartoon style",
			v(12, 64.5, 10),
			15000,
			"hero 3: waterfall face toward -Z (the road)"
		),
		FloatingRockMesh = meshRow(
			"FloatingRockTex",
			"small floating rock island, grassy top with one round bush, rocky brown underside tapering to a point, short roots and vines hanging below, stylized low poly cartoon style",
			floatingRock.Size,
			3000,
			"landmark and Blocks giant (BiomeBob)"
		),
		BrokenColumnMesh = meshRow(
			"BrokenColumnTex",
			"single weathered pale grey stone column, broken off with a jagged top, square base, a ring of moss near the bottom, plain with no carvings or writing, stylized low poly cartoon style",
			brokenColumn.Size,
			1500
		),
		RuinArchMesh = meshRow(
			"RuinArchTex",
			"simple ancient stone arch ruin, two plain round pale grey stone columns joined by a flat stone lintel, grass growing on top and one vine hanging down, plain with no carvings or writing, stylized low poly cartoon style",
			ruinArch.Size,
			2000
		),
		IslandTreeMesh = meshRow(
			"IslandTreeTex",
			"small round leafy green tree, short brown trunk, two puffy round canopies, stylized low poly cartoon style",
			islandTree.Size,
			1500
		),
		VineBridgeMesh = meshRow(
			"VineBridgeTex",
			"short straight wooden plank footbridge with green vine hand ropes on both sides and wooden posts at each end, vines hanging underneath, stylized low poly cartoon style",
			vineBridge.Size,
			2000,
			"rhythm: long axis along Z, away from the road"
		),
		RuinHutMesh = meshRow(
			"RuinHutTex",
			"small ruined pale grey stone hut, one storey, cracked stone block walls, a broken roof covered in green moss and grass, an empty doorway and one empty window, plain with no carvings or writing, stylized low poly cartoon style",
			ruinHut.Size,
			2500,
			"rhythm building (Pad = true), footprint inside 44"
		),
		RuinIslandTex = textureRow("RuinIslandMesh"),
		SkyTreeTex = textureRow("SkyTreeMesh"),
		WaterfallPillarTex = textureRow("WaterfallPillarMesh"),
		FloatingRockTex = textureRow("FloatingRockMesh"),
		BrokenColumnTex = textureRow("BrokenColumnMesh"),
		RuinArchTex = textureRow("RuinArchMesh"),
		IslandTreeTex = textureRow("IslandTreeMesh"),
		VineBridgeTex = textureRow("VineBridgeMesh"),
		RuinHutTex = textureRow("RuinHutMesh"),
		CloudWispParticle = {
			Kind = "Texture",
			Lane = "A",
			Prompt = "in-house 128 px soft stretched cloud puff with lumpy noise inside, white on transparent",
			Notes = "drawn with python3 + numpy (assets/biomes/Snow/cloud_wisp_particle.png); Id comes with the phase 2 upload",
		},
		MistParticle = {
			Kind = "Texture",
			Lane = "A",
			Prompt = "in-house 128 px round soft glow with faint grain, white on transparent, tinted pale blue by the emitter",
			Notes = "drawn with python3 + numpy (assets/biomes/Snow/mist_particle.png); Id comes with the phase 2 upload",
		},
		AmbHighWind = {
			Kind = "Sound",
			Id = "rbxassetid://9114057104",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9114057104: Desert Wind Whistley Light Gusts 1, whistling wind, loop, 37.4 s. "
				.. "Waterfall roar alternative: 9120549564 (Waterfall Background Water Roar 1, 56 s)",
		},
		SfxHawkCall = {
			Kind = "Sound",
			Id = "rbxassetid://9125598512",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9125598512: hawk screeching call, 2.4 s",
		},
		SfxWindGust = {
			Kind = "Sound",
			Id = "rbxassetid://9113840280",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9113840280: Cloth Whooshes Pass Bys Light And Air Wind 2, a passing air gust, 4.4 s",
		},
	},
}
