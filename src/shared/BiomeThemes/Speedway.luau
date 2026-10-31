--!nonstrict
-- Track 1: forest village, wooden rooftops with round water tanks, red bridges over a river, training posts,
-- a cliff of 4 generic stone faces. No biome gate: the plaza torii is Track 1's gate (owner 2026-10-30).
-- Data only (format in Kit). b1 stubs: Terrain, Atmosphere, Audio and Assets; b2 fills them in for this biome.
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

return {
	DisplayName = "Leafwind Village",
	Ground = { Color = LEAF_GREEN, Material = M.Grass },
	Sky = { Color = hex("87CEEB") },
	Gate = gate(WOOD1, M.Wood, nil, { Skip = true }),
	Rhythm = {
		Every = 4,
		Offset = 10,
		Props = {
			prop("TrainingPosts", v(8, 6, 3), {
				post(5, 1.2, v(-3, 2.5, 0), WOOD1, M.Wood),
				post(6, 1.2, v(0, 3, 0), WOOD1, M.Wood),
				post(4.5, 1.2, v(3, 2.25, 0), WOOD1, M.Wood),
				part(v(8, 0.4, 0.4), v(0, 3.6, -0.7), DIRT1, M.Fabric),
			}),
			paperLantern,
			block("WoodFence", v(10, 3.4, 0.8), WOOD1, M.WoodPlanks, {
				part(v(10, 0.4, 0.8), v(0, 3.2, 0), DIRT1, M.Wood),
			}),
			pine("TallPine", 24, hex("6B4A2E"), hex("2C5E2E")),
		},
	},
	Landmarks = {
		Offset = 40,
		Every = 22,
		Props = {
			house(
				"VillageHouse",
				20,
				12,
				16,
				PLASTER1,
				hex("2F6B3A"),
				{ Trim = WOOD1, Tank = WOOD1, Glow = rgb(255, 200, 140) }
			),
			prop("FoodStall", v(15, 11.8, 8), {
				part(v(14, 3.5, 6), v(0, 1.75, 0), WOOD1, M.WoodPlanks),
				post(6, 0.6, v(-6.5, 6, 2.5), WOOD1, M.Wood),
				post(6, 0.6, v(6.5, 6, 2.5), WOOD1, M.Wood),
				part(v(15, 0.8, 8), v(0, 9.4, 0.5), BRIDGE_RED, M.Fabric),
				part(v(13, 2, 0.2), v(0, 7.8, -3.4), PLASTER1, M.Fabric), -- curtain, no text
				part(v(5, 2, 0.4), v(0, 10.8, -3), hex("2E2E2E"), M.Wood), -- blank sign board
			}, { Glow = rgb(255, 190, 120) }),
			prop("RedBridge", v(34, 7, 12), {
				part(v(30, 1, 8), v(0, 3, 0), BRIDGE_RED, M.WoodPlanks),
				part(v(14, 1, 8), v(0, 4, 0), BRIDGE_RED, M.WoodPlanks),
				part(v(30, 0.6, 0.6), v(0, 6.5, -4), BRIDGE_RED, M.Wood),
				part(v(30, 0.6, 0.6), v(0, 6.5, 4), BRIDGE_RED, M.Wood),
				post(6, 1, v(-14, 3, -4), BRIDGE_RED, M.Wood),
				post(6, 1, v(14, 3, -4), BRIDGE_RED, M.Wood),
				post(6, 1, v(-14, 3, 4), BRIDGE_RED, M.Wood),
				post(6, 1, v(14, 3, 4), BRIDGE_RED, M.Wood),
				part(v(34, 0.3, 12), v(0, 0.15, 0), hex("4F8FBF"), M.Glass), -- the river under it
			}, { Glow = rgb(255, 170, 90) }),
			house(
				"TallHouse",
				18,
				10,
				16,
				PLASTER1,
				BRIDGE_RED,
				{ Trim = WOOD1, Floors = 2, Tank = WOOD1, Glow = rgb(255, 200, 140) }
			),
		},
	},
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
		Props = { faceCliff(), peak("ForestHill", v(70, 40, 20), hex("4A6E3E"), LEAF_GREEN) },
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
		pine("GiantPine", 70, hex("6B4A2E"), hex("2C5E2E")),
		house("ElderHouse", 30, 16, 26, PLASTER1, hex("2F6B3A"), { Trim = WOOD1, Floors = 2, Tank = WOOD1 }),
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
	Terrain = { Ridge = { Shape = "Hills", Height = 12 } }, -- stub (placeholder)
	Atmosphere = Kit.Atmosphere(), -- stub: the LightingConfig baseline
	Audio = { OneShots = {}, Volume = 0.3, Reverb = "NoReverb" }, -- stub: Loop = "<AssetKey>", OneShots = { "<AssetKey>" }
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used.
	Assets = {},
}
