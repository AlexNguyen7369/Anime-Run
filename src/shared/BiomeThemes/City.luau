--!nonstrict
-- Track 6: bright modern city, a single plain glass academy tower (not the real H shape), training grounds,
-- boxy generic robots, billboards without text, no school emblem
-- Data only (format in Kit). b1 stubs: Terrain, Atmosphere, Audio and Assets; b2 fills them in for this biome.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, part, post, prop, block, roundTree, lowrise, tower, gate, patch, SPARKLE, particles, GLASS6, CONCRETE6, RED6, YELLOW6, ASPHALT6, PARK6, trainingRobot =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.roundTree,
	Kit.lowrise,
	Kit.tower,
	Kit.gate,
	Kit.patch,
	Kit.SPARKLE,
	Kit.particles,
	Kit.GLASS6,
	Kit.CONCRETE6,
	Kit.RED6,
	Kit.YELLOW6,
	Kit.ASPHALT6,
	Kit.PARK6,
	Kit.trainingRobot

return {
	DisplayName = "Hero Academy City",
	Ground = { Color = PARK6, Material = M.Grass },
	Sky = { Color = hex("A8D4F5") },
	Gate = gate(RED6, M.Metal, YELLOW6),
	-- The street walls need most of the budget (spec Layers 9); see BiomeDressing SHARE
	Shares = { Rhythm = 0.15, Blocks = 0.75 },
	Rhythm = {
		Every = 8,
		Offset = 10,
		Props = {
			prop("StreetLamp", v(3, 16.5, 3), {
				post(16, 0.8, v(0, 8, 0), ASPHALT6, M.Metal),
				part(v(3, 1, 3), v(0, 16, 0), rgb(255, 250, 220), M.Neon),
			}),
			block("CrashBarrier", v(10, 3, 1.5), CONCRETE6, M.Concrete, {
				part(v(10.2, 0.6, 1.5), v(0, 2.4, 0), RED6, M.SmoothPlastic),
			}),
			trainingRobot(),
			roundTree("ParkTree", 14, hex("6B4A2E"), hex("5BA85B")),
		},
	},
	Landmarks = {
		-- In the street wall: the Blocks rows leave room around each tower (spiral laps are ~110 studs apart)
		Offset = 18,
		Every = 60,
		Props = {
			tower(
				"AcademyTower",
				26,
				64,
				26,
				{ Body = CONCRETE6, Trim = hex("B8C0CC"), Glass = GLASS6, Neon = RED6, Floor = 5 }
			),
			tower(
				"GlassTower",
				22,
				70,
				22,
				{ Body = hex("D0D6DE"), Trim = hex("A8B0BC"), Glass = GLASS6, Neon = YELLOW6 }
			),
		},
	},
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
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
	Scatter = {
		Every = 2,
		Near = 78, -- behind the two Blocks rows (Near 18 + RowDepth 34 + depth <= 30)
		Far = 84,
		Props = {
			"ParkTree",
			prop("Billboard", v(16, 16, 1.5), {
				post(9, 1, v(0, 4.5, 0), ASPHALT6, M.Metal),
				part(v(16, 7, 1.4), v(0, 12.5, 0), YELLOW6, M.SmoothPlastic),
				part(v(12, 3, 1.5), v(0, 12.5, 0), RED6, M.Neon),
			}),
			block("Bench", v(6, 2.5, 2), hex("6B4A2E"), M.WoodPlanks),
			block("Planter", v(5, 3, 5), hex("B8C0CC"), M.Concrete, { part(v(4, 2, 4), v(0, 3.5, 0), PARK6, M.Grass) }),
		},
		Patches = {
			patch("Crosswalk", 10, 4, hex("F4F4F4"), M.Concrete),
			patch("TrainingGround", 12, 8, hex("C8C2B4"), M.Concrete),
			patch("Lawn", 10, 8, hex("7CC47C"), M.Grass),
		},
	},
	Blocks = {
		Spacing = 32, -- just over the widest building (30.3), so the street wall has no wide gaps
		Near = 18,
		Rows = 2,
		RowDepth = 34,
		Props = {
			lowrise("Shops", 30, 16, 26, { Glass = GLASS6, Neon = RED6, Body = hex("DDE2E8") }),
			lowrise("Apartments", 28, 30, 28, { Glass = GLASS6, Neon = YELLOW6, Body = hex("E6D8C4") }),
			lowrise("Office", 30, 38, 30, { Glass = GLASS6, Neon = RED6, Body = hex("C8D0DA") }),
			lowrise("Gym", 30, 14, 26, { Glass = GLASS6, Neon = YELLOW6, Body = hex("B8C0CC") }),
		},
	},
	Particles = particles(
		SPARKLE,
		ColorSequence.new(RED6, YELLOW6),
		{ Size = 0.6, Lifetime = 3, Rate = 5, Speed = 2, LightEmission = 0.6 }
	),
	Terrain = { Ridge = { Shape = "Hills", Height = 12 } }, -- stub (placeholder)
	Atmosphere = Kit.Atmosphere(), -- stub: the LightingConfig baseline
	Audio = { OneShots = {}, Volume = 0.3, Reverb = "NoReverb" }, -- stub: Loop = "<AssetKey>", OneShots = { "<AssetKey>" }
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used.
	Assets = {},
}
