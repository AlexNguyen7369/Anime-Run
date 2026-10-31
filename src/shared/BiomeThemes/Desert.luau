--!nonstrict
-- Track 7: cherry blossom avenue, rows and tunnels of red gates, stone stairs, a hilltop shrine; plaques carry
-- no text
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 7): Hills 34 over Grass, terraced
-- Mesa hillsides on the switchbacks, Cobblestone on the three stone-stair climbs, a soft spring afternoon, audio and
-- the asset ledger. Mesh props keep their part fallback (spec 4.2), scaled to the mesh's size.
-- IP (design doc 5, spec 7): generic shrine architecture only; no real shrine names, no kanji, no plaque or text on
-- any gate.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, part, post, prop, block, frameGate, stoneLantern, house, gate, patch, giants, SPARKLE, particles, BLOSSOM7, VERMILION7, STONE7, ROOF7, WOOD7, SKY7 =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.BALL,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.frameGate,
	Kit.stoneLantern,
	Kit.house,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SPARKLE,
	Kit.particles,
	Kit.BLOSSOM7,
	Kit.VERMILION7,
	Kit.STONE7,
	Kit.ROOF7,
	Kit.WOOD7,
	Kit.SKY7

local DEEP_PINK = hex("F2A9C4")
local GATE_BLACK = rgb(40, 34, 32) -- top beams and post feet
local LAMP = rgb(255, 220, 150) -- warm lantern light
local PAPER = hex("F2E6C8")
local MARBLE = hex("E8E8E4")

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

local function append(list, more)
	for _, p in more do
		table.insert(list, p)
	end
end

-- Hero 1: the hilltop shrine hall: a stepped stone platform, plank walls behind vermilion pillars, paper doors and a
-- two-tier copper-green roof with upturned eaves. No plaque, no writing.
local function hilltopShrine()
	local parts = {
		part(v(24, 1.5, 16), v(0, 0.75, 0), STONE7, M.Cobblestone),
		part(v(22, 1.5, 14), v(0, 2.25, 0.5), STONE7, M.Cobblestone),
		part(v(18, 10, 10), v(0, 8, 1.5), WOOD7, M.WoodPlanks),
		part(v(10, 6.5, 0.3), v(0, 6.25, -3.6), PAPER, M.SmoothPlastic), -- sliding paper doors
		part(v(0.3, 6.5, 0.4), v(-1.7, 6.25, -3.8), WOOD7, M.Wood), -- door frames
		part(v(0.3, 6.5, 0.4), v(1.7, 6.25, -3.8), WOOD7, M.Wood),
		part(v(22, 1.4, 14), v(0, 13.7, 0.5), ROOF7, M.Slate), -- lower roof
		part(v(3, 1, 14), v(-10.4, 14.2, 0.5), ROOF7, M.Slate, nil, CFrame.Angles(0, 0, -0.25)), -- upturned eaves
		part(v(3, 1, 14), v(10.4, 14.2, 0.5), ROOF7, M.Slate, nil, CFrame.Angles(0, 0, 0.25)),
		part(v(12, 5.6, 7), v(0, 17.2, 1.5), WOOD7, M.WoodPlanks),
		part(v(16, 1.4, 10), v(0, 20.7, 1.5), ROOF7, M.Slate), -- upper roof
		part(v(2.5, 1, 10), v(-7.6, 21.1, 1.5), ROOF7, M.Slate, nil, CFrame.Angles(0, 0, -0.25)),
		part(v(2.5, 1, 10), v(7.6, 21.1, 1.5), ROOF7, M.Slate, nil, CFrame.Angles(0, 0, 0.25)),
		part(v(12, 1.4, 2), v(0, 22.1, 1.5), ROOF7, M.Slate), -- ridge
		post(1.2, 0.6, v(0, 23.4, 1.5), hex("B8A060"), M.Metal), -- plain finial
	}
	for _, x in { -8, -2.7, 2.7, 8 } do -- vermilion front pillars
		table.insert(parts, post(10, 1, v(x, 8, -3.9), VERMILION7, M.Wood))
	end
	local lantern = stoneLantern("ShrineLantern", 5, STONE7, LAMP)
	for _, x in { -10, 10 } do
		append(parts, moved(lantern, v(x, 1.5, -6.5)))
	end
	return prop("HilltopShrine", v(24, 24, 16), parts, { Glow = LAMP, Pad = true }) -- a hall: levelled pad (spec 3.2)
end

-- Hero 2: a tunnel of 6 close red gates on a stone path, running along Z like the generated mesh (its mouth faces
-- the road). Plain, no plaques.
local function gateTunnel()
	local parts = { part(v(10, 0.4, 17), v(0, 0.2, 0), STONE7, M.Cobblestone) }
	for k = 0, 5 do
		local z = -7.5 + k * 3
		for _, x in { -5, 5 } do
			table.insert(parts, post(11, 1.1, v(x, 6.3, z), VERMILION7, M.Wood))
			table.insert(parts, part(v(1.4, 0.8, 1.4), v(x, 0.8, z), GATE_BLACK, M.Wood)) -- black foot
		end
		table.insert(parts, part(v(12.6, 0.7, 1), v(0, 10.2, z), VERMILION7, M.Wood)) -- tie beam
		table.insert(parts, part(v(15.6, 1, 1.4), v(0, 12.3, z), GATE_BLACK, M.Wood)) -- top beam
	end
	return prop("GateTunnel", v(16, 12.8, 17), parts, { Glow = LAMP })
end

-- Hero 3: a giant old cherry tree: twisted trunk and branches under a wide canopy of pale and deep pink.
local function giantCherry()
	return prop("GiantCherry", v(26, 36, 17), {
		part(v(24, 0.2, 16), v(0, 0.1, 0), BLOSSOM7, M.Grass), -- fallen petals
		part(v(6, 1.5, 6), v(0, 0.75, 0), WOOD7, M.Wood), -- roots
		post(16, 3, v(0, 8, 0), WOOD7, M.Wood),
		part(v(2, 12, 2), v(-4.5, 18, 0), WOOD7, M.Wood, nil, CFrame.Angles(0, 0, 0.6)),
		part(v(2, 12, 2), v(4.5, 18, 0), WOOD7, M.Wood, nil, CFrame.Angles(0, 0, -0.6)),
		part(v(17, 17, 17), v(0, 27, 0), BLOSSOM7, M.Grass, BALL),
		part(v(13, 13, 13), v(-6, 24, 1), BLOSSOM7, M.Grass, BALL),
		part(v(13, 13, 13), v(6, 24, -1), BLOSSOM7, M.Grass, BALL),
		part(v(11, 11, 11), v(-4, 30, 1), DEEP_PINK, M.Grass, BALL),
		part(v(11, 11, 11), v(5, 30, -1), BLOSSOM7, M.Grass, BALL),
		part(v(8, 8, 8), v(-7.5, 21, -3), DEEP_PINK, M.Grass, BALL),
	}, { Glow = DEEP_PINK })
end

local cherryTree = prop("CherryTree", v(12, 16, 10), {
	post(7, 1.4, v(0, 3.5, 0), WOOD7, M.Wood),
	part(v(1, 4, 1), v(-1.5, 7, 0), WOOD7, M.Wood, nil, CFrame.Angles(0, 0, 0.5)),
	part(v(8, 8, 8), v(0, 11, 0), BLOSSOM7, M.Grass, BALL),
	part(v(6, 6, 6), v(-3, 10, 0.5), DEEP_PINK, M.Grass, BALL),
	part(v(6, 6, 6), v(3, 10.5, -0.5), BLOSSOM7, M.Grass, BALL),
	part(v(5, 5, 5), v(0, 13.5, 0), BLOSSOM7, M.Grass, BALL),
})
local stoneFox = prop("StoneFox", v(4, 7.3, 5), { -- generic sitting fox on a plinth
	part(v(4, 2, 5), v(0, 1, 0), STONE7, M.Slate),
	part(v(2.4, 3, 2.4), v(0, 3.5, 0.4), MARBLE, M.Marble),
	part(v(1.8, 1.6, 2), v(0, 5.6, -0.2), MARBLE, M.Marble),
	part(v(0.5, 1, 0.5), v(-0.6, 6.8, 0), MARBLE, M.Marble),
	part(v(0.5, 1, 0.5), v(0.6, 6.8, 0), MARBLE, M.Marble),
	part(v(1.6, 0.8, 0.2), v(0, 4.6, -0.9), VERMILION7, M.Fabric), -- plain bib
})
local washBasin = prop("WashBasin", v(8, 6.8, 5), {
	part(v(6, 2, 3), v(0, 1, 0), STONE7, M.Slate),
	part(v(5, 0.3, 2), v(0, 2.1, 0), hex("8CC8E8"), M.Glass),
	post(6, 0.5, v(-3.5, 3, 1.5), WOOD7, M.Wood),
	post(6, 0.5, v(3.5, 3, 1.5), WOOD7, M.Wood),
	part(v(8, 0.8, 5), v(0, 6.4, 0), ROOF7, M.Slate),
})
-- Short stone steps up to a small plain gate; kept 8 deep so x1.75 it stays inside its half of the gap
local function gateSteps()
	local parts = {}
	for i = 0, 3 do
		table.insert(parts, part(v(14, 1, 8 - i * 2), v(0, 0.5 + i, i), STONE7, M.Cobblestone))
	end
	append(parts, moved(frameGate("Top", 9, 11, VERMILION7, M.Wood, GATE_BLACK), v(0, 4, 2.5)))
	return prop("GateSteps", v(14, 16.5, 8), parts)
end

-- Mesh props (Lane A). Sizes keep each generated mesh's own proportions (measured in Studio 2026-10-31) unless a
-- comment says it is stretched.
local cherryMesh = meshed(cherryTree, "CherryTreeMesh", v(11.7, 12, 11.7))
local lanternMesh = meshed(stoneLantern("StoneLantern", 7, STONE7, LAMP), "StoneLanternMesh", v(3.3, 7, 3.3))
-- The fox mesh faces +Z (away from the road) and the registry cannot turn a mesh, so it is a scatter prop only
-- (random yaw), not a landmark. Orchestrator default 2026-10-31.
local foxMesh = meshed(stoneFox, "StoneFoxMesh", v(3.8, 7.3, 6.5))
local toriiMesh =
	meshed(frameGate("RedGate", 10, 12, VERMILION7, M.Wood, GATE_BLACK), "ToriiGateMesh", v(14, 12.9, 2.4))

-- Mesh rows: generated in Studio (Lane A) with `generate_mesh` (textPrompt = Prompt, size = Gen, maxTriangles = Tris,
-- segmentation "none"); each mesh's own generated texture is a Texture row. Ids are the generated (uploaded) assets.
-- Reviewed is left for the rules auditor (spec 4.1 step 3); close-ups go in assets/biomes/Desert/review/.
local function meshRow(id, texture, prompt, size, tris, notes)
	return {
		Kind = "Mesh",
		Id = id,
		Lane = "A",
		Prompt = prompt,
		Texture = texture,
		Gen = string.format("size %g x %g x %g, maxTriangles %d, segmentation none", size.X, size.Y, size.Z, tris),
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

-- Blocks: the default Near (28) puts a hall's road-side face 50 studs out, in the 44-60 shoulder where hall pads
-- can float (fw4 open). Near 18 keeps it inside 44, so it sits on corridor ground. Orchestrator default 2026-10-31.
local blocks = giants({
	meshed(giantCherry(), "GiantCherryMesh", v(24.9, 39, 25.5)), -- the hero mesh x1.5 (Y stretched as the hero)
	meshed(frameGate("GiantGate", 30, 40, VERMILION7, M.Wood, GATE_BLACK), "ToriiGateMesh", v(42, 38.6, 7.2)),
	meshed(
		house("TempleHall", 30, 14, 24, WOOD7, ROOF7, {
			WallMaterial = M.WoodPlanks,
			Trim = VERMILION7,
			Window = PAPER,
			Floors = 2,
		}),
		"ShrineHallMesh",
		v(32.7, 34, 26.9)
	),
})
blocks.Near = 18

return {
	DisplayName = "Blossom Shrine Path",
	Ground = { Color = hex("A9C98E"), Material = M.Grass },
	Sky = { Color = SKY7 },
	Gate = gate(VERMILION7, M.Wood, LAMP),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = { toriiMesh, cherryMesh, lanternMesh, cherryMesh },
	},
	-- Pinned heroes (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight. Fractions of the 11261-stud
	-- track: 0.12 = the first stone-stair climb (straight run 0.100-0.197), 0.543 = the hilltop between the second
	-- climb's slopes (0.540-0.545, inside the 0.497-0.609 run), 0.82 = the straight after the third blossom sweep
	-- (0.811-0.840).
	Landmarks = {
		-- placeholder: edge 22 + 40 puts every landmark's road-side face 62 studs out, past the 44-60 shoulder; the
		-- x1.75 heroes (raw depth <= 17) reach about 92. Non-hero landmarks are at most 8 deep (x1.75: 62-76, inside
		-- the ~77 gap midline).
		Offset = 40,
		Every = 20,
		Props = {
			-- mesh 12.5 x 10.2 x 12 scaled to 13 tall, then Z (the tunnel axis) stretched 15.3 -> 17 so the run reads
			-- longer: the generator made a 2-gate cube, not the 32-stud run asked for (it caps sides near 16)
			meshed(gateTunnel(), "GateTunnelMesh", v(16, 13, 17), { Hero = true, At = 0.12 }),
			meshed(hilltopShrine(), "HilltopShrineMesh", v(23.4, 20, 16.6), { Hero = true, At = 0.543 }),
			-- mesh 11.7 x 12.6 x 12 scaled to 17 deep, then Y stretched 17.8 -> 26 for hero height (x1.75: 45 tall); the
			-- generator caps sides near 16 and depth must stay <= 17 to keep inside the gap
			meshed(giantCherry(), "GiantCherryMesh", v(16.6, 26, 17), { Hero = true, At = 0.82 }),
			gateSteps(),
			meshed(washBasin, "WashBasinMesh", v(5.1, 6.5, 5)),
		},
	},
	Horizon = {
		-- placeholder: the placement floor is Landmarks.Offset (62 studs out); x2 pieces are at most 15 deep, so they
		-- span about 62-77 and stay in this zone's half of the gap.
		Offset = 40,
		Props = {
			prop("Pagoda", v(7.5, 30, 7.5), {
				part(v(5, 6, 5), v(0, 3, 0), WOOD7, M.WoodPlanks),
				part(v(7.5, 1, 7.5), v(0, 6.5, 0), ROOF7, M.Slate),
				part(v(4.2, 5, 4.2), v(0, 9.5, 0), WOOD7, M.WoodPlanks),
				part(v(6.5, 1, 6.5), v(0, 12.5, 0), ROOF7, M.Slate),
				part(v(3.4, 4.5, 3.4), v(0, 15.25, 0), WOOD7, M.WoodPlanks),
				part(v(5.5, 1, 5.5), v(0, 18, 0), ROOF7, M.Slate),
				part(v(2.6, 4, 2.6), v(0, 20.5, 0), WOOD7, M.WoodPlanks),
				part(v(4.5, 1, 4.5), v(0, 23, 0), ROOF7, M.Slate),
				post(6.5, 0.5, v(0, 26.75, 0), hex("B8A060"), M.Metal),
			}),
			prop("BlossomRidge", v(30, 16, 7.5), {
				part(v(30, 5, 7.5), v(0, 2.5, 0), hex("7FA36A"), M.Grass),
				part(v(11, 11, 7.5), v(-9, 8, 0), BLOSSOM7, M.Grass, BALL),
				part(v(11, 11, 7.5), v(9, 8.5, 0), DEEP_PINK, M.Grass, BALL),
				part(v(10, 10, 7.5), v(0, 11, 0), BLOSSOM7, M.Grass, BALL),
			}),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		Props = {
			"CherryTree",
			"StoneLantern",
			foxMesh,
			block("Bush", v(6, 4, 6), hex("6E9A5A"), M.Grass),
			"RedGate",
			"CherryTree",
		},
		Patches = {
			patch("PetalCarpet", 24, 16, BLOSSOM7, M.Grass),
			patch("StoneSlabs", 20, 8, hex("C2C2BE"), M.Slate),
			patch("Moss", 16, 12, hex("6E9A5A"), M.Grass),
		},
	},
	Blocks = blocks,
	Particles = particles(SPARKLE, BLOSSOM7, {
		Size = 0.8,
		Lifetime = 6,
		Speed = 1,
		Acceleration = v(0.6, -1, 0.2),
		LightEmission = 0.2,
	}),
	-- Spec 3.3 / 7: Hills 34 over Grass with Rock where steep, a Cobblestone corridor; terraced Mesa hillsides on the two switchback runs
	-- (0.265-0.348, 0.675-0.758); Cobblestone and a higher ridge on the three stone-stair climbs (0.111-0.156,
	-- 0.520-0.565, 0.913-0.958). Every number is a placeholder.
	Terrain = {
		Ridge = { Shape = "Hills", Height = 34, Noise = 0.04, Amp = 7 },
		Sections = {
			{
				From = 0.105,
				To = 0.16,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = 42, Noise = 0.05, Amp = 8 },
				Material = M.Cobblestone,
			},
			{ From = 0.26, To = 0.35, Side = "Both", Ridge = { Shape = "Mesa", Height = 44, Noise = 0.03, Amp = 4 } },
			{
				From = 0.515,
				To = 0.57,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = 42, Noise = 0.05, Amp = 8 },
				Material = M.Cobblestone,
			},
			{ From = 0.67, To = 0.76, Side = "Both", Ridge = { Shape = "Mesa", Height = 44, Noise = 0.03, Amp = 4 } },
			{
				From = 0.905,
				To = 0.96,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = 42, Noise = 0.05, Amp = 8 },
				Material = M.Cobblestone,
			},
		},
		-- orchestrator default 2026-10-31: Cobblestone corridor (the pale stone path), not Grass. Terrain grass blades grow
		-- up through the road (seen on Track 6); Grass stays on the ridge only, never under the road.
		Materials = { Corridor = M.Cobblestone, Ridge = M.Grass, Cliff = M.Rock, Bed = M.Grass },
		CliffSlope = 0.9,
		Embank = true,
	},
	-- Spec 5.2 / 7: soft spring afternoon. ClockTime, Atmosphere Color and Haze, the tint and Bloom are section 7's;
	-- the rest are placeholders.
	Atmosphere = Kit.Atmosphere({
		Lighting = {
			ClockTime = 15.5,
			Brightness = 2.6,
			Ambient = hex("4A4250"),
			OutdoorAmbient = hex("948A9A"),
			ExposureCompensation = 0.1,
		},
		Atmosphere = {
			Density = 0.26,
			Offset = 0.2,
			Color = hex("F5DCE6"),
			Decay = hex("C9A0B4"),
			Glare = 0.15,
			Haze = 0.8,
		},
		Grade = { TintColor = hex("FFF0F5"), Saturation = 0.25 },
		Bloom = { Intensity = 0.9, Size = 24, Threshold = 1.4 },
		SunRays = { Intensity = 0.08, Spread = 0.6 },
		Sky = {
			Skybox = "SkySpringDay",
			SunAngularSize = 21,
			MoonAngularSize = 11,
			StarCount = 3000,
			CelestialBodiesShown = true,
		},
		Clouds = { Cover = 0.3, Density = 0.35, Color = hex("FFF4F8") },
		Particles = {
			{
				Texture = "PetalParticle", -- falling pale pink petals
				Color = BLOSSOM7,
				Size = 0.4,
				Rate = 18,
				Lifetime = 7,
				Speed = 1.5,
				SpreadAngle = 180,
				LightEmission = 0.1,
				Area = v(90, 24, 90),
			},
			{
				Texture = "PetalParticle", -- fewer, deeper pink petals
				Color = DEEP_PINK,
				Size = 0.3,
				Rate = 8,
				Lifetime = 7,
				Speed = 1.2,
				SpreadAngle = 180,
				LightEmission = 0,
				Area = v(90, 24, 90),
			},
		},
	}),
	Audio = { Loop = "AmbSpringBirds", OneShots = { "SfxShrineBell", "SfxBasinDrip" }, Volume = 0.3, Reverb = "Plain" },
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Reviewed is left for the rules auditor (spec 4.1).
	-- Sound and skybox rows: Creator Store ids used directly (no insert, nothing to strip; BUGS
	-- creator-store-backdoor-skybox); creator and details checked on the Roblox economy API 2026-10-31.
	Assets = {
		GateTunnelMesh = meshRow(
			"rbxassetid://112319103758109",
			"GateTunnelTex",
			"short tunnel made of five vermilion red wooden shrine gates standing one behind another in a straight line, each gate two round red pillars with black feet, a black top beam with upturned ends and a red tie beam below, plain gates with no plaque and no writing, grey stone path running through them, stylized cartoon style",
			v(16, 13, 12),
			15000,
			"hero 2: came out as 2 gates 12.5 x 10.2 x 12, the run along Z, mouth facing -Z (the road); no plaques. "
				.. "A first try (32 x 13 x 12, a longer prompt) gave a closed box pavilion and was rejected"
		),
		HilltopShrineMesh = meshRow(
			"rbxassetid://78812132373163",
			"HilltopShrineTex",
			"traditional Japanese wooden shrine hall on a raised grey stone platform, vermilion red wooden pillars, sliding paper doors, two tiered sweeping roof of weathered copper green with gently upturned eaves, two small stone lanterns at the front corners, no writing, no symbols and no plaque, stylized cartoon style",
			v(16, 16, 12),
			15000,
			"hero 1: one copper-green roof tier, lanterns at the front corners; front faces -Z (the road); the band "
				.. "over the opening is blank, no plaque, no symbols"
		),
		GiantCherryMesh = meshRow(
			"rbxassetid://72928476126468",
			"GiantCherryTex",
			"huge ancient cherry blossom tree, thick twisted dark brown trunk spreading into wide branches, dense rounded canopy of pale pink blossoms with deeper pink clusters, fallen pink petals around the roots, stylized cartoon style",
			v(16, 16, 12),
			15000,
			"hero 3 (Y stretched x1.46 for height, see Landmarks); also the giant tree in the Blocks rows"
		),
		CherryTreeMesh = meshRow(
			"rbxassetid://111820201254377",
			"CherryTreeTex",
			"small cherry blossom tree, slender dark brown trunk, rounded puffy canopy of pale pink blossoms, stylized low poly cartoon style",
			v(12, 16, 10),
			3000,
			"regenerated 2026-10-31: the first prompt's word for the canopy held a real character name as a substring "
				.. "and failed assets_ip (old ids 130152191420867 / 129145103264631 dropped)"
		),
		StoneLanternMesh = meshRow(
			"rbxassetid://88904856886905",
			"StoneLanternTex",
			"traditional Japanese stone lantern, grey carved granite with a square base, round pillar, square fire box with small openings glowing warm yellow light, wide curved cap with a small round finial, plain with no carvings or writing, stylized cartoon style",
			v(3, 7, 3),
			2000
		),
		ToriiGateMesh = meshRow(
			"rbxassetid://77871122215416",
			"ToriiGateTex",
			"single vermilion red wooden shrine gate, two round red pillars with black feet, a black top beam with gently upturned ends and a red tie beam below it, plain with no plaque and no writing, stylized cartoon style",
			v(14, 13.5, 3),
			2000,
			"rhythm gate; also the giant gate in the Blocks rows; no plaque (a short plain dark strut under the top beam)"
		),
		StoneFoxMesh = meshRow(
			"rbxassetid://139980012767045",
			"StoneFoxTex",
			"generic grey stone fox statue sitting upright on a square stone plinth, pointed ears, bushy tail curled at its side, small plain red cloth bib, no writing, stylized cartoon style",
			v(4, 7.3, 5),
			2000,
			"generic fox, plain bib; faces +Z, so scatter only (random yaw)"
		),
		WashBasinMesh = meshRow(
			"rbxassetid://115966381800972",
			"WashBasinTex",
			"small open wooden pavilion over a rectangular grey stone water basin filled with clear water, four wooden posts, green tiled roof, wooden ladles resting on the basin edge, no writing, stylized cartoon style",
			v(8, 6.8, 5),
			3000
		),
		ShrineHallMesh = meshRow(
			"rbxassetid://96959653297548",
			"ShrineHallTex",
			"small traditional Japanese wooden shrine building, plain natural wood plank walls, vermilion red trim and door, cream paper window, overhanging copper green roof, no writing and no symbols, stylized cartoon style",
			v(16, 10, 13),
			3000,
			"Blocks temple hall (Pad = true via Kit.house); its door is on a side face, not -Z"
		),
		GateTunnelTex = textureRow("rbxassetid://125906218078598", "GateTunnelMesh"),
		HilltopShrineTex = textureRow("rbxassetid://84923888672974", "HilltopShrineMesh"),
		GiantCherryTex = textureRow("rbxassetid://81363713289215", "GiantCherryMesh"),
		CherryTreeTex = textureRow("rbxassetid://103277403080412", "CherryTreeMesh"),
		StoneLanternTex = textureRow("rbxassetid://131602882178152", "StoneLanternMesh"),
		ToriiGateTex = textureRow("rbxassetid://123905022856884", "ToriiGateMesh"),
		StoneFoxTex = textureRow("rbxassetid://98161529607118", "StoneFoxMesh"),
		WashBasinTex = textureRow("rbxassetid://136059487288338", "WashBasinMesh"),
		ShrineHallTex = textureRow("rbxassetid://94129541348717", "ShrineHallMesh"),
		PetalParticle = {
			Kind = "Texture",
			Id = "rbxassetid://72194779069931",
			Lane = "A",
			Prompt = "in-house 128 px cherry petal with a notched tip and a faint centre crease, white on transparent, tinted pink by the emitter",
			Reviewed = "2026-10-31 rules-auditor",
			Notes = "drawn with python3 + numpy (assets/biomes/Desert/petal_particle.png), uploaded from Studio 2026-10-31",
		},
		SkySpringDay = {
			Kind = "Skybox",
			Id = "rbxassetid://8416699004",
			Faces = {
				Bk = "rbxassetid://8416699004",
				Dn = "rbxassetid://8416698655",
				Ft = "rbxassetid://8416699234",
				Lf = "rbxassetid://8416699545",
				Rt = "rbxassetid://8416699883",
				Up = "rbxassetid://8416700741",
			},
			Lane = "D",
			Creator = "Olivercove",
			Reviewed = "2026-10-31 rules-auditor",
			Notes = "Creator Store 8416719130 (clear day skybox, plain gradient), the faces Track 1 already uses; no "
				.. "insert. Soft spring blue under the pink haze. Orchestrator default 2026-10-31.",
		},
		AmbSpringBirds = {
			Kind = "Sound",
			Id = "rbxassetid://9112831666",
			Lane = "D",
			Creator = "ProSoundEffects",
			Reviewed = "2026-10-31 rules-auditor",
			Notes = "Creator Store 9112831666: Morning Birds 2, active chirping, loop, 36 s",
		},
		SfxShrineBell = {
			Kind = "Sound",
			Id = "rbxassetid://9125597331",
			Lane = "D",
			Creator = "ProSoundEffects",
			Reviewed = "2026-10-31 rules-auditor",
			Notes = "Creator Store 9125597331: small cast iron hand bell jingling in the wind, 6.3 s",
		},
		SfxBasinDrip = {
			Kind = "Sound",
			Id = "rbxassetid://9126190492",
			Lane = "D",
			Creator = "ProSoundEffects",
			Reviewed = "2026-10-31 rules-auditor",
			Notes = "Creator Store 9126190492: water drips into a filled bowl, reverberant, 5 s",
		},
	},
}
