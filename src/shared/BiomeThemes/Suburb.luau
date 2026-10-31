--!nonstrict
-- Track 4 (night): Taisho-style wooden street, wisteria groves and arches, lit stone lanterns, a full moon.
-- Tints only its own props and ground (never global Lighting).
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 4): Hills 36 rising to Slate
-- cliffs over a Mud forest floor, Cobblestone on the two stone-stair climbs, a night atmosphere, audio and the
-- asset ledger. Mesh props keep their part fallback (spec 4.2), scaled to the mesh's size.
-- IP (spec 7): no checkered haori pattern and no show kanji; signboards are blank.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, CYL, FACE, part, post, prop, block, pine, stoneLantern, house, gate, patch, giants, SPARKLE, particles, NIGHT4, WISTERIA4, BLOSSOM4, DARKWOOD4, LANTERN4, MOON4, wisteriaTree =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.BALL,
	Kit.CYL,
	Kit.FACE,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.pine,
	Kit.stoneLantern,
	Kit.house,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SPARKLE,
	Kit.particles,
	Kit.NIGHT4,
	Kit.WISTERIA4,
	Kit.BLOSSOM4,
	Kit.DARKWOOD4,
	Kit.LANTERN4,
	Kit.MOON4,
	Kit.wisteriaTree

local TILE = hex("2B2B3A") -- grey clay roof tile
local STONE = rgb(110, 108, 120)
local PLAIN_WOOD = hex("6B4A2E") -- unpainted shrine gate wood
local PAPER = hex("F2B66B")
local DARK_TRIM = hex("1E140C")

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

-- Hero 1: a huge wisteria tree arch. Two trunks lean together under one canopy with hanging flower clusters.
local function wisteriaArch()
	local parts = {
		part(v(3, 24, 3), v(-10, 11.5, 0), DARKWOOD4, M.Wood, nil, CFrame.Angles(0, 0, -0.3)),
		part(v(3, 24, 3), v(10, 11.5, 0), DARKWOOD4, M.Wood, nil, CFrame.Angles(0, 0, 0.3)),
		part(v(4, 1.6, 4), v(-12.5, 0.8, 0), hex("2A1E15"), M.Wood), -- roots
		part(v(4, 1.6, 4), v(12.5, 0.8, 0), hex("2A1E15"), M.Wood),
		part(v(26, 4, 11), v(0, 23, 0), WISTERIA4, M.Grass),
	}
	for i, x in { -9, 0, 9 } do
		table.insert(parts, part(v(12, 12, 12), v(x, 24 + (i == 2 and 1.5 or 0), 0), WISTERIA4, M.Grass, BALL))
	end
	for i = 0, 9 do -- hanging clusters along both faces, alternating light and dark
		local x, long = -13 + i * 2.9, 5 + (i % 3) * 1.5
		local color = i % 2 == 0 and BLOSSOM4 or WISTERIA4
		table.insert(parts, part(v(1.4, long, 1.4), v(x, 20 - long / 2, -5), color, M.Grass))
		table.insert(parts, part(v(1.4, long, 1.4), v(x + 1.4, 20.5 - long / 2, 5), color, M.Grass))
	end
	return prop("WisteriaArch", v(30, 31.5, 14), parts, { Glow = BLOSSOM4 })
end

-- Hero 2: a two-storey Taisho-style wooden street front: three shop bays with glowing sliding paper doors,
-- a balcony, grey tile roofs and a blank signboard.
local function taishoStreet()
	local parts = {
		part(v(30, 8, 10), v(0, 4, 0.5), DARKWOOD4, M.WoodPlanks),
		part(v(32, 1, 12.5), v(0, 8.5, -0.2), TILE, M.Slate, nil, CFrame.Angles(-0.12, 0, 0)), -- ground-floor eave
		part(v(28, 7, 8), v(0, 12.5, 1.5), DARKWOOD4, M.WoodPlanks),
		part(v(28, 1, 0.6), v(0, 10, -2.9), DARK_TRIM, M.Wood), -- balcony rail
		part(v(31, 1.2, 11), v(0, 16.6, 1), TILE, M.Slate, nil, CFrame.Angles(-0.1, 0, 0)),
		part(v(26, 1.6, 2), v(0, 17.8, 1.5), TILE, M.Slate), -- ridge
		part(v(8, 1.6, 0.4), v(0, 9.9, -6.4), hex("5A4030"), M.Wood), -- blank signboard
	}
	for _, x in { -15.2, -5, 5, 15.2 } do -- posts between the bays
		table.insert(parts, part(v(0.8, 8, 0.8), v(x, 4, -4.8), DARK_TRIM, M.Wood))
	end
	for _, x in { -10, 0, 10 } do
		table.insert(parts, part(v(7, 6, 0.4), v(x, 3, -4.6), LANTERN4, M.Neon)) -- glowing paper doors
		table.insert(parts, part(v(0.3, 6, 0.5), v(x, 3, -4.9), DARK_TRIM, M.Wood)) -- door lattice
		table.insert(parts, part(v(7, 0.3, 0.5), v(x, 3.5, -4.9), DARK_TRIM, M.Wood))
		table.insert(parts, part(v(5, 3, 0.4), v(x, 13, -2.6), hex("E8D8A8"), M.Neon)) -- upper paper window
		table.insert(parts, part(v(1.4, 1.8, 1.4), v(x - 4.5, 7, -6), PAPER, M.Neon, BALL)) -- eave lantern
	end
	return prop("TaishoStreet", v(32, 18.6, 12.5), parts, { Glow = LANTERN4 })
end

-- Hero 3: a plain wooden shrine gate (no plaque) on stone steps, two lit stone lanterns at its foot.
local function shrineGate()
	local parts = {
		part(v(18, 1.2, 14), v(0, 0.6, 0), STONE, M.Cobblestone),
		part(v(16, 1.2, 10), v(0, 1.8, 2), STONE, M.Cobblestone),
		part(v(14, 1.2, 6), v(0, 3, 4), STONE, M.Cobblestone),
		post(13, 1.4, v(-5.5, 10.1, 4), PLAIN_WOOD, M.Wood),
		post(13, 1.4, v(5.5, 10.1, 4), PLAIN_WOOD, M.Wood),
		part(v(13, 0.9, 1.1), v(0, 14, 4), PLAIN_WOOD, M.Wood), -- lower crossbeam
		part(v(14, 0.8, 1.4), v(0, 16.2, 4), PLAIN_WOOD, M.Wood),
		part(v(12, 1.2, 1.8), v(0, 17.2, 4), PLAIN_WOOD, M.Wood), -- top beam
		part(v(3.5, 1, 1.8), v(-7.3, 17.6, 4), PLAIN_WOOD, M.Wood, nil, CFrame.Angles(0, 0, -0.18)), -- upturned ends
		part(v(3.5, 1, 1.8), v(7.3, 17.6, 4), PLAIN_WOOD, M.Wood, nil, CFrame.Angles(0, 0, 0.18)),
	}
	local lantern = stoneLantern("ShrineLantern", 5, STONE, LANTERN4)
	for _, x in { -7.5, 7.5 } do
		for _, p in moved(lantern, v(x, 1.2, -4.5)) do
			table.insert(parts, p)
		end
	end
	return prop("ShrineGate", v(18, 18.6, 14), parts, { Glow = LANTERN4 })
end

local stoneLanternProp = stoneLantern("StoneLantern", 7, STONE, LANTERN4)
local hangingLantern = prop("HangingLantern", v(4, 8, 2.4), {
	post(8, 0.4, v(-1.4, 4, 0), DARKWOOD4, M.Wood),
	part(v(3, 0.3, 0.3), v(0, 7.6, 0), DARKWOOD4, M.Wood),
	part(v(0.1, 1, 0.1), v(1.2, 7, 0), hex("2A1E15"), M.Fabric),
	part(v(1.8, 2.4, 1.8), v(1.2, 5.4, 0), PAPER, M.Neon, BALL), -- plain paper, no writing
})
local fence = block("WoodFence", v(10, 3.4, 0.8), DARKWOOD4, M.WoodPlanks, {
	part(v(10, 0.4, 0.8), v(0, 3.2, 0), hex("2A1E15"), M.Wood),
	post(4, 0.6, v(-4.6, 2, 0), hex("2A1E15"), M.Wood),
	post(4, 0.6, v(4.6, 2, 0), hex("2A1E15"), M.Wood),
})
local floorLantern = prop("FloorLantern", v(2.4, 4.1, 2.4), {
	part(v(2.4, 0.4, 2.4), v(0, 0.2, 0), DARK_TRIM, M.Wood),
	part(v(2.4, 3.3, 2.4), v(0, 2, 0), PAPER, M.Neon, BALL), -- plain paper, no writing
	part(v(1.8, 0.4, 1.8), v(0, 3.9, 0), DARK_TRIM, M.Wood),
}, { Glow = LANTERN4 })

-- Mesh props (Lane A); sizes keep each mesh's own proportions
local wisteriaTreeMesh = meshed(wisteriaTree, "WisteriaTreeMesh", v(14, 17.8, 8.4))
local stoneLanternMesh = meshed(stoneLanternProp, "StoneLanternMesh", v(3.3, 7, 3.3))
local floorLanternMesh = meshed(floorLantern, "PaperLanternMesh", v(2.4, 4.1, 2.4))
local fenceMesh = meshed(fence, "WoodFenceMesh", v(6.6, 3.4, 0.7)) -- one panel, stretched x2 along the road
local cedarMesh = meshed(pine("DarkPine", 22, DARKWOOD4, hex("1F3A2E")), "CedarTreeMesh", v(11, 22, 11.2))
local shopMesh = meshed(
	house("TaishoShop", 18, 10, 14, DARKWOOD4, TILE, {
		WallMaterial = M.WoodPlanks,
		Trim = DARK_TRIM,
		Window = LANTERN4,
		WindowMaterial = M.Neon, -- glowing paper doors
		Floors = 2,
		Glow = LANTERN4,
	}),
	"TaishoShopMesh",
	v(20.4, 17.6, 17)
)

-- Mesh rows: generated in Studio (Lane A) with the stored prompt; each mesh's own generated texture is a Texture row.
-- Reviewed is left for the rules auditor (spec 4.1 step 3); close-ups are in assets/biomes/Suburb/review/.
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
	DisplayName = "Wisteria Night Mountain",
	Ground = { Color = NIGHT4, Material = M.Grass },
	Sky = { Color = hex("15142B") },
	Gate = gate(DARKWOOD4, M.Wood, LANTERN4),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = { stoneLanternMesh, wisteriaTreeMesh, fenceMesh, hangingLantern, wisteriaTreeMesh },
	},
	-- Pinned heroes (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight. Fractions of the 5760-stud
	-- track: 0.2 = exit of the first corner (0.191, into the wisteria grove), 0.55 = the second stone-stair climb
	-- (straight 0.513-0.614), 0.84 = the 420-stud town straight (0.805-0.878).
	Landmarks = {
		Offset = 30, -- placeholder: x1.75 heroes span about 48-73 studs from the centre line, outside the 44 corridor
		Every = 20,
		Props = {
			-- p 1: exit of the first corner, the way into the wisteria grove
			meshed(wisteriaArch(), "WisteriaArchMesh", v(29.6, 28, 17.4), { Hero = true, At = 0.2 }),
			-- p 2: on the second stone-stair climb
			meshed(shrineGate(), "ShrineGateMesh", v(17.3, 19, 10.75), { Hero = true, At = 0.55 }),
			-- p 3: the town straight
			meshed(taishoStreet(), "TaishoStreetMesh", v(20.2, 18.6, 13.9), { Hero = true, At = 0.84 }),
			shopMesh,
			prop("StoneStair", v(14, 8, 16), {
				part(v(14, 2, 16), v(0, 1, 0), STONE, M.Slate),
				part(v(14, 2, 12), v(0, 3, 2), STONE, M.Slate),
				part(v(14, 2, 8), v(0, 5, 4), STONE, M.Slate),
				part(v(14, 2, 4), v(0, 7, 6), STONE, M.Slate),
			}),
			wisteriaTreeMesh,
		},
	},
	Horizon = {
		-- placeholder: 18 (was 55). The x2 pieces are 40 deep, so they span about 36-76 studs from the centre line and
		-- keep inside this zone's half of the gap (midline about 77).
		Offset = 18,
		Props = {
			-- Hero 4 is the full moon in the sky (Atmosphere.Sky); this backdrop disk repeats it low over the ridge
			prop("MoonPeak", v(60, 105, 20), {
				part(v(60, 36, 20), v(0, 18, 0), hex("26243F"), M.Slate),
				part(v(34, 20, 14), v(0, 46, 0), WISTERIA4, M.Grass),
				part(v(1, 18, 18), v(0, 96, 8), MOON4, M.Neon, CYL, FACE), -- full moon disk
			}),
			prop("WisteriaHill", v(56, 40, 20), {
				part(v(56, 22, 20), v(0, 11, 0), hex("26243F"), M.Slate),
				part(v(40, 24, 20), v(0, 28, 0), WISTERIA4, M.Grass, BALL),
			}),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		Props = {
			"WisteriaTree",
			"StoneLantern",
			cedarMesh,
			"HangingLantern",
			floorLanternMesh,
			block("Bush", v(6, 4, 6), hex("2A2848"), M.Grass),
		},
		Patches = {
			patch("PetalCarpet", 22, 16, BLOSSOM4, M.Grass),
			patch("StonePath", 26, 6, rgb(80, 78, 92), M.Slate),
			patch("DarkMoss", 18, 14, hex("232E2A"), M.Grass),
		},
	},
	Blocks = giants({
		prop("GiantWisteria", v(40, 54, 40), {
			post(30, 4, v(0, 15, 0), DARKWOOD4, M.Wood),
			part(v(40, 24, 40), v(0, 42, 0), WISTERIA4, M.Grass, BALL),
			part(v(4, 16, 4), v(-12, 26, -10), BLOSSOM4, M.Grass),
			part(v(4, 14, 4), v(12, 27, 8), BLOSSOM4, M.Grass),
		}),
		meshed(pine("DarkGiantPine", 70, DARKWOOD4, hex("1F3A2E")), "CedarTreeMesh", v(35, 70, 35.5)),
		meshed(
			house("TaishoHall", 30, 14, 24, DARKWOOD4, TILE, {
				WallMaterial = M.WoodPlanks,
				Window = LANTERN4,
				WindowMaterial = M.Neon,
				Floors = 2,
			}),
			"TaishoShopMesh",
			v(30, 25.9, 25)
		),
	}),
	Particles = particles(SPARKLE, BLOSSOM4, {
		Size = 0.7,
		Lifetime = 6,
		Speed = 1,
		Acceleration = v(0.4, -1.2, 0),
		LightEmission = 0.5,
	}),
	-- Spec 3.3 / 7: Hills 36 rising to Slate cliffs over a Mud forest floor; Cobblestone and a higher ridge on the two
	-- stone-stair climbs (slopes 0.026-0.085 and 0.533-0.592). Every number is a placeholder.
	Terrain = {
		Ridge = { Shape = "Hills", Height = 36, Noise = 0.04, Amp = 8 },
		Sections = {
			{
				From = 0.01,
				To = 0.1,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = 46, Noise = 0.05, Amp = 10 },
				Material = M.Cobblestone,
			},
			{
				From = 0.52,
				To = 0.6,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = 46, Noise = 0.05, Amp = 10 },
				Material = M.Cobblestone,
			},
		},
		Materials = { Corridor = M.Mud, Ridge = M.Mud, Cliff = M.Slate, Bed = M.Mud },
		CliffSlope = 0.7, -- placeholder: lower than 0.9 so the steep hill flanks read as Slate cliffs
		Embank = true,
	},
	-- Spec 5.2 / 7: night. Values are placeholders except where section 7 gives them. Hero 4, the full moon, is the
	-- engine moon at ClockTime 0, drawn larger. No skybox row: the one Creator Store night sky tried (116693646927996)
	-- carried a hidden script backdoor and was deleted unused (2026-10-31).
	Atmosphere = Kit.Atmosphere({
		Lighting = {
			ClockTime = 0,
			-- placeholders, brighter than section 7 (Brightness 1, OutdoorAmbient 3A3560): those read near black in Play
			Brightness = 2.5,
			Ambient = hex("5A5088"),
			OutdoorAmbient = hex("6E64A8"),
			ExposureCompensation = 0.6,
		},
		Atmosphere = {
			Density = 0.32,
			Offset = 0.1,
			Color = hex("2B2550"),
			Decay = hex("1B1A33"),
			Glare = 0,
			Haze = 0.6,
		},
		Grade = { TintColor = hex("E6E0FF") },
		Bloom = { Intensity = 1.2 }, -- lanterns glow
		SunRays = { Intensity = 0 },
		Sky = {
			SunAngularSize = 21,
			MoonAngularSize = 24, -- placeholder: a large full moon
			StarCount = 3000,
			CelestialBodiesShown = true,
		},
		Clouds = { Cover = 0.3, Density = 0.3, Color = hex("3A3560") },
		Particles = {
			{
				Texture = "PetalParticle", -- falling purple petals
				Color = BLOSSOM4,
				Size = 0.35,
				Rate = 14,
				Lifetime = 6,
				Speed = 1.5,
				SpreadAngle = 180,
				LightEmission = 0.2,
				Area = v(90, 20, 90),
			},
			{
				Texture = "FireflyParticle",
				Color = LANTERN4,
				Size = 0.35,
				Rate = 8,
				Lifetime = 3,
				Speed = 0.3,
				SpreadAngle = 180,
				LightEmission = 1,
				Area = v(90, 10, 90),
			},
		},
	}),
	Audio = { Loop = "AmbNightCrickets", OneShots = { "SfxOwl", "SfxWoodClapper" }, Volume = 0.3, Reverb = "Forest" },
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Reviewed is left for the rules auditor (spec 4.1).
	-- Sound rows: Creator Store audio ids used directly (no insert, nothing to strip).
	Assets = {
		WisteriaArchMesh = meshRow(
			"rbxassetid://126046240061880",
			"WisteriaArchTex",
			"huge ancient wisteria tree forming a wide natural arch, two thick twisted dark brown trunks that lean together and meet overhead, dense canopy with long hanging clusters of purple and pale lavender wisteria flowers drooping down, stylized cartoon style",
			15000,
			"hero 1: arch opening faces -Z (the road)"
		),
		TaishoStreetMesh = meshRow(
			"rbxassetid://92658009705155",
			"TaishoStreetTex",
			"row of three two storey traditional Japanese wooden shops from the early 1900s, dark brown timber walls, grey clay tile roofs, a wooden upper balcony, sliding paper doors glowing warm yellow, plain blank wooden signboard with no writing, stylized cartoon style",
			15000,
			"hero 2: signboard is blank; front faces -Z"
		),
		ShrineGateMesh = meshRow(
			"rbxassetid://74726779794588",
			"ShrineGateTex",
			"plain unpainted natural wood shrine gate with two round pillars and two crossbeams, the top beam curving gently upward at the ends, no plaque and no writing, standing on top of a short flight of grey stone steps, stylized cartoon style",
			10000,
			"hero 3: no plaque, plain wood"
		),
		WisteriaTreeMesh = meshRow(
			"rbxassetid://123234582316843",
			"WisteriaTreeTex",
			"small wisteria tree, short gnarled dark brown trunk, rounded canopy with many long hanging clusters of purple and pale lavender wisteria flowers, stylized low poly cartoon style",
			3000
		),
		StoneLanternMesh = meshRow(
			"rbxassetid://128852448033944",
			"StoneLanternTex",
			"traditional Japanese stone lantern, grey carved granite with a square base, round pillar, square fire box with small openings glowing warm yellow light, wide curved pagoda cap with a small round finial, plain with no carvings or writing, stylized cartoon style",
			2000
		),
		PaperLanternMesh = meshRow(
			"rbxassetid://130612335939047",
			"PaperLanternTex",
			"round paper lantern hanging from the arm of a short dark wooden post, warm cream yellow paper with thin wooden ribs and black wooden top and bottom rims, plain paper with no writing or symbols, stylized cartoon style",
			1500,
			"came out as the lantern only (no post): used as a standing floor lantern"
		),
		WoodFenceMesh = meshRow(
			"rbxassetid://133152163991694",
			"WoodFenceTex",
			"low traditional Japanese wooden fence section, dark brown vertical wooden slats between two square posts with a top rail, bound with thin rope, stylized cartoon style",
			1500,
			"one short panel"
		),
		TaishoShopMesh = meshRow(
			"rbxassetid://78155129680524",
			"TaishoShopTex",
			"small two storey traditional Japanese wooden shop house, dark brown timber walls, grey clay tile roofs over each floor, sliding paper doors glowing warm yellow on the front, plain dark blue cloth door curtain with no pattern and no writing, stylized cartoon style",
			3000,
			"door curtain plain blue, no pattern"
		),
		CedarTreeMesh = meshRow(
			"rbxassetid://119866627185291",
			"CedarTreeTex",
			"tall dark Japanese cedar tree, straight reddish brown trunk, layered conical tiers of deep dark green needles, stylized low poly cartoon style",
			2000
		),
		WisteriaArchTex = textureRow("rbxassetid://94740651660197", "WisteriaArchMesh"),
		TaishoStreetTex = textureRow("rbxassetid://73226211684113", "TaishoStreetMesh"),
		ShrineGateTex = textureRow("rbxassetid://115340766286578", "ShrineGateMesh"),
		WisteriaTreeTex = textureRow("rbxassetid://119391717737549", "WisteriaTreeMesh"),
		StoneLanternTex = textureRow("rbxassetid://90222898148620", "StoneLanternMesh"),
		PaperLanternTex = textureRow("rbxassetid://93084890510175", "PaperLanternMesh"),
		WoodFenceTex = textureRow("rbxassetid://86484699609755", "WoodFenceMesh"),
		TaishoShopTex = textureRow("rbxassetid://125251661805243", "TaishoShopMesh"),
		CedarTreeTex = textureRow("rbxassetid://123822537911509", "CedarTreeMesh"),
		PetalParticle = {
			Kind = "Texture",
			Id = "rbxassetid://81642905665292",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "A",
			Prompt = "in-house 128 px teardrop petal with a faint centre crease, white on transparent, tinted purple by the emitter",
			Notes = "drawn with python3 (assets/biomes/Suburb/petal_particle.png), uploaded from Studio",
		},
		FireflyParticle = {
			Kind = "Texture",
			Id = "rbxassetid://114741774953380",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "A",
			Prompt = "in-house 128 px round glow: bright core and a soft halo, white on transparent, tinted lantern yellow by the emitter",
			Notes = "drawn with python3 (assets/biomes/Suburb/firefly_particle.png), uploaded from Studio",
		},
		AmbNightCrickets = {
			Kind = "Sound",
			Id = "rbxassetid://9112764040",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9112764040: Crickets Canyon 1, night chirping with a breeze, loop, 36 s",
		},
		SfxOwl = {
			Kind = "Sound",
			Id = "rbxassetid://9117181540",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9117181540: owl hooting, reverberant, 5.5 s",
		},
		SfxWoodClapper = {
			Kind = "Sound",
			Id = "rbxassetid://9125574134",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9125574134: wood mallet hits wood, triple impact, 1.3 s (stands in for a wooden clapper)",
		},
	},
}
