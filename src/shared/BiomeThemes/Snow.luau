--!nonstrict
-- Track 8: floating grassy islands, waterfalls into clouds, vine bridges, generic stone columns and arches
-- Data only (format in Kit). b1 stubs: Terrain, Atmosphere, Audio and Assets; b2 fills them in for this biome.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, part, post, prop, block, ball, roundTree, gate, patch, giants, SMOKE, particles, DIRT1, GRASS8, ROCK8, RUIN8, CLOUD8, SKY8, FALL8 =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.BALL,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.ball,
	Kit.roundTree,
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

return {
	DisplayName = "Sky Islands",
	Ground = { Color = GRASS8, Material = M.Grass },
	Sky = { Color = SKY8 },
	Gate = gate(RUIN8, M.Rock),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = {
			prop("BrokenColumn", v(3.4, 10.4, 3.4), {
				part(v(3.4, 1, 3.4), v(0, 0.5, 0), RUIN8, M.Rock),
				post(8, 2.4, v(0, 5, 0), RUIN8, M.Rock),
				part(v(2.4, 1.6, 2.4), v(0.4, 9.6, 0), RUIN8, M.Rock, nil, CFrame.Angles(0.3, 0, 0.2)),
			}),
			roundTree("IslandTree", 14, ROCK8, hex("5FAE52")),
			block("MossRock", v(5, 3.6, 4), ROCK8, M.Rock, { part(v(4, 0.8, 3), v(0, 3.2, 0), GRASS8, M.Grass) }),
		},
	},
	Landmarks = {
		Offset = 40,
		Every = 22,
		Props = {
			prop("FloatingIsland", v(22, 40, 22), {
				part(v(20, 8, 20), v(0, 26, 0), ROCK8, M.Rock),
				part(v(12, 8, 12), v(0, 19, 0), ROCK8, M.Rock),
				part(v(5, 6, 5), v(0, 13, 0), ROCK8, M.Rock),
				part(v(22, 2, 22), v(0, 31, 0), GRASS8, M.Grass),
				part(v(8, 8, 8), v(4, 36, 2), hex("5FAE52"), M.Grass, BALL),
				part(v(0.6, 10, 0.6), v(-6, 16, -6), hex("5E7A3C"), M.Grass), -- hanging root
			}, { Tag = "BiomeBob" }),
			prop("Waterfall", v(24, 33, 18), {
				part(v(24, 30, 12), v(0, 15, 2), ROCK8, M.Rock),
				part(v(20, 3, 10), v(0, 31.5, 2), GRASS8, M.Grass),
				part(v(8, 28, 1), v(0, 16, -4.6), FALL8, M.Glass),
				part(v(14, 6, 10), v(0, 2, -6), CLOUD8, M.SmoothPlastic, BALL), -- cloud where it lands
			}, { Glow = rgb(180, 220, 255) }),
			prop("RuinArch", v(16, 16.9, 4.2), {
				post(14, 2.6, v(-6, 7, 0), RUIN8, M.Rock),
				post(14, 2.6, v(6, 7, 0), RUIN8, M.Rock),
				part(v(16, 2, 4), v(0, 15, 0), RUIN8, M.Rock),
				part(v(5, 1, 4.2), v(-3, 16.4, 0), GRASS8, M.Grass),
			}),
			prop("VineBridge", v(34, 7, 10), {
				part(v(30, 0.6, 6), v(0, 4, 0), DIRT1, M.WoodPlanks),
				part(v(30, 0.3, 0.3), v(0, 6.5, -3), hex("5E7A3C"), M.Fabric),
				part(v(30, 0.3, 0.3), v(0, 6.5, 3), hex("5E7A3C"), M.Fabric),
				post(7, 0.8, v(-14, 3.5, -3), hex("6B4A2E"), M.Wood),
				post(7, 0.8, v(14, 3.5, -3), hex("6B4A2E"), M.Wood),
				post(7, 0.8, v(-14, 3.5, 3), hex("6B4A2E"), M.Wood),
				post(7, 0.8, v(14, 3.5, 3), hex("6B4A2E"), M.Wood),
				part(v(34, 3, 10), v(0, 1.5, 0), CLOUD8, M.SmoothPlastic), -- clouds under it
			}),
		},
	},
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
		Props = {
			prop("CloudBank", v(70, 20, 22), {
				part(v(30, 16, 18), v(-18, 8, 0), CLOUD8, M.SmoothPlastic, BALL),
				part(v(36, 20, 22), v(6, 10, 0), CLOUD8, M.SmoothPlastic, BALL),
				part(v(24, 12, 16), v(26, 6, 0), hex("EEF6FF"), M.SmoothPlastic, BALL),
			}),
			prop("DistantIsland", v(40, 73, 22), {
				part(v(30, 12, 20), v(10, 6, 0), CLOUD8, M.SmoothPlastic, BALL),
				part(v(36, 12, 20), v(0, 50, 0), ROCK8, M.Rock),
				part(v(22, 12, 14), v(0, 40, 0), ROCK8, M.Rock),
				part(v(38, 3, 22), v(0, 57.5, 0), GRASS8, M.Grass),
				part(v(14, 14, 14), v(-6, 66, 2), hex("5FAE52"), M.Grass, BALL),
				part(v(6, 30, 1), v(16, 34, -8), FALL8, M.Glass),
			}, { Tag = "BiomeBob" }),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		Props = {
			"BrokenColumn",
			"IslandTree",
			ball("CloudPuff", 8, CLOUD8, M.SmoothPlastic),
			"MossRock",
			block("FallenColumn", v(10, 2.4, 2.4), RUIN8, M.Rock),
		},
		Patches = {
			patch("CloudPool", 24, 16, hex("F2F8FF"), M.SmoothPlastic),
			patch("Meadow", 20, 14, hex("9AD47F"), M.Grass),
			patch("StoneTiles", 16, 12, RUIN8, M.Slate),
		},
	},
	Blocks = giants({
		roundTree("GiantTree", 60, ROCK8, hex("4E9C46"), M.Grass, hex("5FAE52")),
		prop("StonePillar", v(24, 104, 22), {
			part(v(24, 60, 22), v(0, 30, 0), ROCK8, M.Rock),
			part(v(18, 30, 16), v(0, 75, 0), hex("7A6A58"), M.Rock),
			part(v(20, 4, 18), v(0, 92, 0), GRASS8, M.Grass),
			part(v(12, 12, 12), v(0, 98, 0), hex("5FAE52"), M.Grass, BALL),
		}),
		prop("SkyIsle", v(40, 61, 38), {
			part(v(40, 10, 34), v(0, 5, 0), CLOUD8, M.SmoothPlastic, BALL),
			part(v(36, 12, 36), v(0, 52, 0), ROCK8, M.Rock),
			part(v(20, 14, 20), v(0, 40, 0), ROCK8, M.Rock),
			part(v(38, 3, 38), v(0, 59.5, 0), GRASS8, M.Grass),
		}, { Tag = "BiomeBob" }),
	}),
	Particles = particles(SMOKE, CLOUD8, { Size = 4, Lifetime = 5, Rate = 3, Speed = 1, Transparency = 0.5 }),
	Terrain = { Ridge = { Shape = "Hills", Height = 12 } }, -- stub (placeholder)
	Atmosphere = Kit.Atmosphere(), -- stub: the LightingConfig baseline
	Audio = { OneShots = {}, Volume = 0.3, Reverb = "NoReverb" }, -- stub: Loop = "<AssetKey>", OneShots = { "<AssetKey>" }
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used.
	Assets = {},
}
