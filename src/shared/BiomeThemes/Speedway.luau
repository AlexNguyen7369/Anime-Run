--!nonstrict
-- Track 1: forest village, wooden rooftops with round water tanks, red bridges over a river, training posts,
-- a cliff of 4 generic stone faces. No biome gate: the plaza torii is Track 1's gate (owner 2026-10-30).
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 1): terrain profile, atmosphere,
-- audio and the asset ledger. Mesh props keep their part fallback (spec 4.2), scaled to the mesh's size.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, part, post, prop, block, roundTree, pine, house, peak, gate, patch, giants, SPARKLE, particles, LEAF_GREEN, WOOD1, PLASTER1, BRIDGE_RED, CLIFF1, DIRT1, faceCliff, paperLantern =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.roundTree,
	Kit.pine,
	Kit.house,
	Kit.peak,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SPARKLE,
	Kit.particles,
	Kit.LEAF_GREEN,
	Kit.WOOD1,
	Kit.PLASTER1,
	Kit.BRIDGE_RED,
	Kit.CLIFF1,
	Kit.DIRT1,
	Kit.faceCliff,
	Kit.paperLantern

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
	local out = prop(def.Name, size, parts, { Mesh = key, Glow = def.Glow })
	for name, value in extra or {} do
		out[name] = value
	end
	return out
end

local HERO = { Hero = true }
-- Spec 7's carved cliff (Cliff 60). The Cliff shape's face sits at 71-73 studs, on the fold of this ~150-stud gap,
-- where the seam and grid smoothing keep it under ~15 studs (measured 2026-10-31). Hills 60 instead makes the
-- shoulder (44-60) a steep Rock face rising to ~55 at the fold.
local CLIFF_RIDGE = { Shape = "Hills", Height = 60, Noise = 0.03, Amp = 3 }
local LEDGER_REVIEW = "2026-10-31 rules-auditor"

local trainingPosts = meshed(
	prop("TrainingPosts", v(8, 6, 3), {
		post(5, 1.2, v(-3, 2.5, 0), WOOD1, M.Wood),
		post(6, 1.2, v(0, 3, 0), WOOD1, M.Wood),
		post(4.5, 1.2, v(3, 2.25, 0), WOOD1, M.Wood),
		part(v(8, 0.4, 0.4), v(0, 3.6, -0.7), DIRT1, M.Fabric),
	}),
	"TrainingPostsMesh",
	v(7.2, 6, 6.6)
)
local lantern = meshed(paperLantern, "PaperLanternMesh", v(3.6, 8, 3.6))
local tallPine = meshed(pine("TallPine", 24, hex("6B4A2E"), hex("2C5E2E")), "TallPineMesh", v(16.6, 24, 16.6))
local giantPine = meshed(pine("GiantPine", 70, hex("6B4A2E"), hex("2C5E2E")), "TallPineMesh", v(48.4, 70, 48.4))

-- Red arched bridge pinned at `at` (fraction of the track) inside the river section. The mesh spans Z (away from
-- the road, across the river), so its fallback does too.
local function redBridge(at)
	return prop("RedBridge", v(11.8, 11.1, 24), {
		part(v(8, 1, 22), v(0, 3, 0), BRIDGE_RED, M.WoodPlanks),
		part(v(8, 1, 10), v(0, 4, 0), BRIDGE_RED, M.WoodPlanks),
		part(v(0.6, 0.6, 22), v(-4, 6.5, 0), BRIDGE_RED, M.Wood),
		part(v(0.6, 0.6, 22), v(4, 6.5, 0), BRIDGE_RED, M.Wood),
		post(6, 1, v(-4, 3, -10), BRIDGE_RED, M.Wood),
		post(6, 1, v(4, 3, -10), BRIDGE_RED, M.Wood),
		post(6, 1, v(-4, 3, 10), BRIDGE_RED, M.Wood),
		post(6, 1, v(4, 3, 10), BRIDGE_RED, M.Wood),
	}, { Mesh = "RedBridgeMesh", Glow = rgb(255, 170, 90), At = at })
end

-- Mesh rows: generated in Studio (Lane A) with the stored prompt; each mesh's own generated texture is a Texture row.
local function meshRow(id, texture, prompt, tris, notes)
	return {
		Kind = "Mesh",
		Id = id,
		Lane = "A",
		Prompt = prompt,
		Texture = texture,
		Tris = tris,
		Reviewed = LEDGER_REVIEW,
		Notes = notes,
	}
end
local function textureRow(id, mesh)
	return {
		Kind = "Texture",
		Id = id,
		Lane = "A",
		Prompt = "generated with " .. mesh .. " (same prompt)",
		Reviewed = LEDGER_REVIEW,
	}
end

return {
	DisplayName = "Leafwind Village",
	Ground = { Color = LEAF_GREEN, Material = M.Grass },
	Sky = { Color = hex("87CEEB") },
	Gate = gate(WOOD1, M.Wood, nil, { Skip = true }),
	Rhythm = {
		Every = 4,
		Offset = 10,
		Props = {
			trainingPosts,
			lantern,
			block("WoodFence", v(10, 3.4, 0.8), WOOD1, M.WoodPlanks, {
				part(v(10, 0.4, 0.8), v(0, 3.2, 0), DIRT1, M.Wood),
			}),
			tallPine,
		},
	},
	-- Pinned defs (At, spec 4.3) are placed in list order p = 1, 2, ...; on a straight the side is outer for odd p and
	-- inner (toward the plaza) for even p; at a corner exit it is the outside. The Oval's 200+ stud straights are
	-- 0-0.068, 0.21-0.295 (both face the plaza's flat clear area) and 0.872-1.0, so the pins share the last straight.
	Landmarks = {
		Offset = 20, -- placeholder: landmarks span 42-84 studs from the centre line, so pinned ones stand in the river
		-- (about 49-77) and at the cliff foot
		Every = 22,
		Props = {
			-- p 1, outer: the waterfall gorge pours into the late-route river
			meshed(
				peak("WaterfallGorge", v(24, 20.5, 24), CLIFF1, LEAF_GREEN),
				"WaterfallGorgeMesh",
				v(24, 20.5, 24),
				{ Hero = true, At = 0.92 }
			),
			-- p 2, inner: the carved faces stand at the foot of the cliff section's rock face. Flattened in Z (x1.75: 6
			-- deep, 42-48 studs out) so the snap keeps them on the foot, back set into the rock, front not floating.
			meshed(faceCliff(), "StoneFaceCliffMesh", v(30, 25.7, 3.4), { Hero = true, At = 0.935 }),
			redBridge(0.965), -- p 3, outer
			redBridge(0.876), -- p 4: snaps to the corner exit, whose side is the outside
			meshed(
				house(
					"VillageHouse",
					20,
					12,
					16,
					PLASTER1,
					hex("2F6B3A"),
					{ Trim = WOOD1, Tank = WOOD1, Glow = rgb(255, 200, 140) }
				),
				"HouseGreenMesh",
				v(14.3, 15.3, 14)
			),
			meshed(
				prop("FoodStall", v(15, 11.8, 8), {
					part(v(14, 3.5, 6), v(0, 1.75, 0), WOOD1, M.WoodPlanks),
					post(6, 0.6, v(-6.5, 6, 2.5), WOOD1, M.Wood),
					post(6, 0.6, v(6.5, 6, 2.5), WOOD1, M.Wood),
					part(v(15, 0.8, 8), v(0, 9.4, 0.5), BRIDGE_RED, M.Fabric),
					part(v(13, 2, 0.2), v(0, 7.8, -3.4), PLASTER1, M.Fabric), -- curtain, no text
					part(v(5, 2, 0.4), v(0, 10.8, -3), hex("2E2E2E"), M.Wood), -- blank sign board
				}, { Glow = rgb(255, 190, 120) }),
				"FoodStallMesh",
				v(11.4, 12, 7.1)
			),
			meshed(
				house(
					"TallHouse",
					18,
					10,
					16,
					PLASTER1,
					BRIDGE_RED,
					{ Trim = WOOD1, Floors = 2, Tank = WOOD1, Glow = rgb(255, 200, 140) }
				),
				"HouseRedMesh",
				v(19.5, 18.6, 18)
			),
		},
	},
	-- Hero landmarks (spec 7, Track 1) without a pin: x2 at the horizon scale, footprint at most 60 x 60 (placeholder)
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
		Props = {
			meshed(
				Kit.frameGate("VillageGate", 24, 26, WOOD1, M.Wood, hex("2F6B3A")),
				"VillageGateMesh",
				v(30, 29, 14.7),
				HERO
			),
			meshed(
				house("WaterTowers", 24, 14, 18, PLASTER1, BRIDGE_RED, { Trim = WOOD1, Floors = 2, Tank = WOOD1 }),
				"WaterTowersMesh",
				v(30, 26.2, 22.2),
				HERO
			),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		Props = {
			"TallPine",
			"TrainingPosts",
			roundTree("LeafTree", 16, hex("6B4A2E"), hex("4F9A44")),
			block("Bush", v(6, 4, 6), hex("356B32"), M.Grass),
			"PaperLantern",
			block("Rock", v(5, 3, 4), CLIFF1, M.Slate),
		},
		Patches = {
			patch("DirtPath", 30, 8, DIRT1, M.Ground),
			patch("Stream", 26, 6, hex("4F8FBF"), M.Glass),
			patch("Clover", 18, 14, hex("57A24C"), M.Grass),
		},
	},
	Blocks = giants({
		giantPine,
		meshed(
			house("ElderHouse", 30, 16, 26, PLASTER1, hex("2F6B3A"), { Trim = WOOD1, Floors = 2, Tank = WOOD1 }),
			"HouseRedMesh",
			v(31.2, 29.8, 28.8)
		),
		prop("WatchTower", v(16, 46, 16), {
			post(40, 1.6, v(-5, 20, -5), WOOD1, M.Wood),
			post(40, 1.6, v(5, 20, -5), WOOD1, M.Wood),
			post(40, 1.6, v(-5, 20, 5), WOOD1, M.Wood),
			post(40, 1.6, v(5, 20, 5), WOOD1, M.Wood),
			part(v(14, 1.5, 14), v(0, 40, 0), WOOD1, M.WoodPlanks),
			part(v(16, 2, 16), v(0, 45, 0), BRIDGE_RED, M.Slate),
		}),
	}),
	Particles = particles(
		SPARKLE,
		hex("8FCB5A"),
		{ Size = 0.7, Lifetime = 5, Speed = 1.5, Acceleration = v(0.5, -1, 0) }
	),
	-- Spec 3.3 / 7. Every number is a placeholder. Sections (From / To = fractions of the track length):
	-- a cobblestone village square, and on the last straight the carved cliff (inner side) facing the river (outer
	-- side), where the bridges and the waterfall gorge are pinned.
	Terrain = {
		Ridge = { Shape = "Hills", Height = 24, Noise = 0.03, Amp = 3 },
		Sections = {
			{ From = 0.48, To = 0.56, Side = "Both", Ridge = { Shape = "Blocks" }, Material = M.Cobblestone },
			-- The carved cliff: the last straight's inner side faces the 0.21-0.295 straight's outer side across one
			-- narrow gap, so both sides rise; one side alone is halved by the seam blend at the midline.
			{ From = 0.885, To = 0.985, Side = "Inner", Ridge = CLIFF_RIDGE },
			{ From = 0.2, To = 0.3, Side = "Outer", Ridge = CLIFF_RIDGE },
			{ From = 0.86, To = 0.99, Side = "Outer", Water = { Level = -3 } },
		},
		Materials = { Corridor = M.Ground, Ridge = M.Grass, Cliff = M.Rock, Bed = M.Ground },
		CliffSlope = 0.9,
		Embank = true,
	},
	-- Spec 5.2 / 7: clear day. Values are placeholders except where section 7 gives them.
	Atmosphere = Kit.Atmosphere({
		Lighting = { ClockTime = 14 },
		Atmosphere = { Density = 0.25, Haze = 0.4, Color = hex("BFD8F0") },
		Grade = { Saturation = 0.33 }, -- baseline 0.18 + 0.15
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.6 }, -- light bloom
		Sky = {
			Skybox = "SkyClearDay",
			SunAngularSize = 21,
			MoonAngularSize = 11,
			StarCount = 3000,
			CelestialBodiesShown = true,
		},
		Clouds = { Cover = 0.35, Density = 0.4, Color = hex("FFFFFF") },
		Water = { Color = hex("3F8FA8"), Transparency = 0.6, Reflectance = 0.2, WaveSize = 0.1, WaveSpeed = 8 },
		Particles = {
			{
				Texture = "LeafParticle",
				Color = hex("6FB04A"),
				Size = 0.6,
				Rate = 12,
				Lifetime = 6,
				Speed = 2,
				SpreadAngle = 60,
				LightEmission = 0,
				Area = v(80, 30, 80),
			},
		},
	}),
	Audio = { Loop = "AmbForest", OneShots = { "SfxWoodpecker", "SfxWindChime" }, Volume = 0.3, Reverb = "Forest" },
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Tris is the generation cap.
	Assets = {
		StoneFaceCliffMesh = meshRow(
			"rbxassetid://70721602625256",
			"StoneFaceCliffTex",
			"tall grey stone cliff wall with four large simple carved stone faces in a row, plain generic calm faces, grass and small bushes on top, stylized low poly cartoon style",
			12000,
			"hero 1: four identical generic blocky faces, no likeness"
		),
		VillageGateMesh = meshRow(
			"rbxassetid://97227022905292",
			"VillageGateTex",
			"tall wooden village gate, two thick wooden pillars, wide overhanging green tiled roof on top, blank wooden plaque board in the middle, low poly stylized anime style",
			8000,
			"hero 2: plaque is blank (no text, no symbol)"
		),
		WaterTowersMesh = meshRow(
			"rbxassetid://119507469494305",
			"WaterTowersTex",
			"cluster of three tall wooden village houses with red and green tiled roofs, large round cylindrical wooden water tanks on the rooftops, stylized cartoon style",
			12000,
			"hero 3"
		),
		WaterfallGorgeMesh = meshRow(
			"rbxassetid://90682322116970",
			"WaterfallGorgeTex",
			"tall rocky gorge cliff with a white waterfall pouring down into a small pool, green moss and pine shrubs on the ledges, stylized cartoon style",
			12000,
			"hero 4"
		),
		HouseGreenMesh = meshRow(
			"rbxassetid://79417200782896",
			"HouseGreenTex",
			"small wooden village house with cream plaster walls, dark wood beams and a green curved tiled roof, one door and one window, stylized cartoon style",
			3000
		),
		HouseRedMesh = meshRow(
			"rbxassetid://78015133291349",
			"HouseRedTex",
			"two storey wooden village house with cream plaster walls, dark wood beams and a red curved tiled roof, small round wooden water tank on the roof, stylized cartoon style",
			3000
		),
		TrainingPostsMesh = meshRow(
			"rbxassetid://108124494947022",
			"TrainingPostsTex",
			"three upright wooden training posts of different heights standing in a row on a small dirt base, tied with rope, stylized cartoon style",
			2000
		),
		FoodStallMesh = meshRow(
			"rbxassetid://105451479200564",
			"FoodStallTex",
			"small wooden street food stall with a red cloth awning, wooden counter with bowls, cream cloth curtain, blank wooden sign board with no text, stylized cartoon style",
			3000,
			"sign board is blank"
		),
		PaperLanternMesh = meshRow(
			"rbxassetid://133163382472416",
			"PaperLanternTex",
			"red paper lantern hanging from a short wooden post, round glowing red paper lantern with black rims, plain with no writing, stylized cartoon style",
			1500
		),
		TallPineMesh = meshRow(
			"rbxassetid://85065767092868",
			"TallPineTex",
			"tall dark green pine tree with layered branches and a brown trunk, stylized low poly cartoon style",
			2000
		),
		RedBridgeMesh = meshRow(
			"rbxassetid://94742736009068",
			"RedBridgeTex",
			"red arched wooden footbridge with red railings and posts, plank deck, simple and plain, stylized cartoon style",
			3000,
			"spans its Z axis"
		),
		StoneFaceCliffTex = textureRow("rbxassetid://122064498455722", "StoneFaceCliffMesh"),
		VillageGateTex = textureRow("rbxassetid://94548225306750", "VillageGateMesh"),
		WaterTowersTex = textureRow("rbxassetid://87104891427499", "WaterTowersMesh"),
		WaterfallGorgeTex = textureRow("rbxassetid://113037912876776", "WaterfallGorgeMesh"),
		HouseGreenTex = textureRow("rbxassetid://133737476849998", "HouseGreenMesh"),
		HouseRedTex = textureRow("rbxassetid://71507361592929", "HouseRedMesh"),
		TrainingPostsTex = textureRow("rbxassetid://112176123168334", "TrainingPostsMesh"),
		FoodStallTex = textureRow("rbxassetid://116979202769539", "FoodStallMesh"),
		PaperLanternTex = textureRow("rbxassetid://114932275164119", "PaperLanternMesh"),
		TallPineTex = textureRow("rbxassetid://74713385309221", "TallPineMesh"),
		RedBridgeTex = textureRow("rbxassetid://104781388589910", "RedBridgeMesh"),
		LeafParticle = {
			Kind = "Texture",
			Id = "rbxassetid://110633066126936",
			Lane = "A",
			Prompt = "in-house 128 px leaf silhouette, white-grey on transparent, tinted green by the emitter",
			Reviewed = LEDGER_REVIEW,
			Notes = "drawn with python3 (assets/biomes/Speedway/leaf_particle.png), uploaded from Studio",
		},
		SkyClearDay = {
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
			Reviewed = LEDGER_REVIEW,
			Notes = "Creator Store 8416719130 (clear day skybox, plain gradient); no scripts",
		},
		AmbForest = {
			Kind = "Sound",
			Id = "rbxassetid://9112806209",
			Lane = "D",
			Creator = "ProSoundEffects",
			Reviewed = LEDGER_REVIEW,
			Notes = "Creator Store 9112806209: dawn forest ambience loop (birds, leaves, wind), 46 s",
		},
		SfxWoodpecker = {
			Kind = "Sound",
			Id = "rbxassetid://1845384510",
			Lane = "D",
			Creator = "APMOfficial",
			Reviewed = LEDGER_REVIEW,
			Notes = "Creator Store 1845384510: woodpecker knock, 5.8 s",
		},
		SfxWindChime = {
			Kind = "Sound",
			Id = "rbxassetid://9120749869",
			Lane = "D",
			Creator = "ProSoundEffects",
			Reviewed = LEDGER_REVIEW,
			Notes = "Creator Store 9120749869: glass and ceramic wind chimes, 7.5 s",
		},
	},
}
