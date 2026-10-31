--!nonstrict
-- Track 7: cherry blossom avenue, rows and tunnels of red gates, stone stairs, a hilltop shrine; plaques carry
-- no text
-- Data only (format in Kit). b1 stubs: Terrain, Atmosphere, Audio and Assets; b2 fills them in for this biome.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, part, post, prop, block, roundTree, frameGate, stoneLantern, house, gate, patch, giants, SPARKLE, particles, BLOSSOM7, VERMILION7, STONE7, ROOF7, WOOD7, SKY7, gateTunnel, stoneStairs =
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
	Kit.SKY7,
	Kit.gateTunnel,
	Kit.stoneStairs

return {
	DisplayName = "Blossom Shrine Path",
	Ground = { Color = hex("A9C98E"), Material = M.Grass },
	Sky = { Color = SKY7 },
	Gate = gate(VERMILION7, M.Wood),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = {
			frameGate("RedGate", 10, 12, VERMILION7, M.Wood, rgb(40, 34, 32)),
			roundTree("CherryTree", 18, WOOD7, BLOSSOM7, M.Grass, hex("F2A9C4")),
			stoneLantern("StoneLantern", 7, STONE7, rgb(255, 220, 150)),
		},
	},
	Landmarks = {
		Offset = 40,
		Every = 20,
		Props = {
			house("ShrineHall", 20, 9, 16, WOOD7, ROOF7, {
				WallMaterial = M.WoodPlanks,
				Trim = VERMILION7,
				Window = hex("F2E6C8"),
				Glow = rgb(255, 210, 150),
			}),
			gateTunnel(),
			stoneStairs(),
			prop("StoneFox", v(4, 7.3, 5), { -- generic sitting fox on a plinth
				part(v(4, 2, 5), v(0, 1, 0), STONE7, M.Slate),
				part(v(2.4, 3, 2.4), v(0, 3.5, 0.4), hex("E8E8E4"), M.Marble),
				part(v(1.8, 1.6, 2), v(0, 5.6, -0.2), hex("E8E8E4"), M.Marble),
				part(v(0.5, 1, 0.5), v(-0.6, 6.8, 0), hex("E8E8E4"), M.Marble),
				part(v(0.5, 1, 0.5), v(0.6, 6.8, 0), hex("E8E8E4"), M.Marble),
				part(v(1.6, 0.8, 0.2), v(0, 4.6, -0.9), VERMILION7, M.Fabric), -- bib
			}),
			prop("WashBasin", v(8, 6.8, 5), {
				part(v(6, 2, 3), v(0, 1, 0), STONE7, M.Slate),
				part(v(5, 0.3, 2), v(0, 2.1, 0), hex("8CC8E8"), M.Glass),
				post(6, 0.5, v(-3.5, 3, 1.5), WOOD7, M.Wood),
				post(6, 0.5, v(3.5, 3, 1.5), WOOD7, M.Wood),
				part(v(8, 0.8, 5), v(0, 6.4, 0), ROOF7, M.Slate),
			}),
		},
	},
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
		Props = {
			prop("HilltopShrine", v(60, 37, 22), {
				part(v(60, 24, 22), v(0, 12, 0), hex("7FA36A"), M.Grass),
				part(v(20, 8, 12), v(0, 28, 0), WOOD7, M.WoodPlanks),
				part(v(26, 2, 16), v(0, 33, 0), ROOF7, M.Slate),
				part(v(16, 2, 12), v(0, 35, 0), ROOF7, M.Slate),
				part(v(14, 14, 14), v(-20, 30, 3), BLOSSOM7, M.Grass, BALL),
				part(v(14, 14, 14), v(20, 30, 3), BLOSSOM7, M.Grass, BALL),
			}),
			prop("Pagoda", v(20, 45.5, 20), {
				part(v(14, 10, 14), v(0, 5, 0), WOOD7, M.WoodPlanks),
				part(v(20, 1.5, 20), v(0, 10.75, 0), ROOF7, M.Slate),
				part(v(11, 9, 11), v(0, 16, 0), WOOD7, M.WoodPlanks),
				part(v(17, 1.5, 17), v(0, 21.25, 0), ROOF7, M.Slate),
				part(v(8, 8, 8), v(0, 26, 0), WOOD7, M.WoodPlanks),
				part(v(14, 1.5, 14), v(0, 30.75, 0), ROOF7, M.Slate),
				post(14, 0.8, v(0, 38.5, 0), hex("B8A060"), M.Metal),
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
			"StoneFox",
			block("Bush", v(6, 4, 6), hex("6E9A5A"), M.Grass),
			"RedGate",
		},
		Patches = {
			patch("PetalCarpet", 24, 16, BLOSSOM7, M.Grass),
			patch("StoneSlabs", 20, 8, hex("C2C2BE"), M.Slate),
			patch("Moss", 16, 12, hex("6E9A5A"), M.Grass),
		},
	},
	Blocks = giants({
		roundTree("GiantCherry", 50, WOOD7, BLOSSOM7, M.Grass, hex("F2A9C4")),
		frameGate("GiantGate", 30, 40, VERMILION7, M.Wood, rgb(40, 34, 32)),
		house("TempleHall", 30, 14, 24, WOOD7, ROOF7, { WallMaterial = M.WoodPlanks, Trim = VERMILION7, Floors = 2 }),
	}),
	Particles = particles(SPARKLE, BLOSSOM7, {
		Size = 0.8,
		Lifetime = 6,
		Speed = 1,
		Acceleration = v(0.6, -1, 0.2),
		LightEmission = 0.2,
	}),
	Terrain = { Ridge = { Shape = "Hills", Height = 12 } }, -- stub (placeholder)
	Atmosphere = Kit.Atmosphere(), -- stub: the LightingConfig baseline
	Audio = { OneShots = {}, Volume = 0.3, Reverb = "NoReverb" }, -- stub: Loop = "<AssetKey>", OneShots = { "<AssetKey>" }
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used.
	Assets = {},
}
