--!nonstrict
-- Track 2: rocky plateaus with layered strata, craters, a stone tiled ring, floating boulders, small domed huts
-- Data only (format in Kit). b1 stubs: Terrain, Atmosphere, Audio and Assets; b2 fills them in for this biome.
local Kit = require(script.Parent.Kit)

local M, hex, v, BALL, CYL, UP, part, prop, block, strata, deadTree, gate, patch, giants, SMOKE, particles, DIRT1, SAND2, ROCK2, STRATA2, SUNSET2, tileRing =
	Kit.M,
	Kit.hex,
	Kit.v,
	Kit.BALL,
	Kit.CYL,
	Kit.UP,
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

return {
	DisplayName = "Tournament Wasteland",
	Ground = { Color = SAND2, Material = M.Sandstone },
	Sky = { Color = hex("7FB8E0") },
	Gate = gate(ROCK2, M.Rock, SUNSET2),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = {
			strata("RockSpire", 4, 14, 4, ROCK2, STRATA2, 3),
			block("Boulder", v(6, 4, 5), ROCK2, M.Rock),
			deadTree("DeadShrub", 6, hex("7A5A3E"), M.Wood),
		},
	},
	Landmarks = {
		Offset = 40,
		Every = 22,
		Props = {
			tileRing(),
			strata("Mesa", 30, 34, 24, ROCK2, STRATA2, 5),
			prop("CapsuleHut", v(14, 7, 14), {
				part(v(14, 8, 14), v(0, 3, 0), hex("F2EFE6"), M.SmoothPlastic, BALL),
				part(v(4, 5, 0.6), v(0, 2.5, -6.6), hex("5A6878"), M.SmoothPlastic),
				part(v(14.4, 0.8, 14.4), v(0, 3, 0), SUNSET2, M.SmoothPlastic),
			}, { Glow = SUNSET2 }),
			prop("Crater", v(30, 3, 30), {
				part(v(0.4, 30, 30), v(0, 0.2, 0), STRATA2, M.Ground, CYL, UP),
				part(v(30, 2, 6), v(0, 1, -12), ROCK2, M.Rock),
				part(v(30, 2, 6), v(0, 1, 12), ROCK2, M.Rock),
				part(v(6, 2.5, 18), v(-12, 1.25, 0), ROCK2, M.Rock),
				part(v(6, 3, 18), v(12, 1.5, 0), ROCK2, M.Rock),
			}),
		},
	},
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
		Props = {
			strata("MesaPillar", 26, 70, 22, ROCK2, STRATA2, 6),
			prop("FloatingBoulder", v(20, 50, 18), {
				part(v(20, 24, 18), v(0, 12, 0), STRATA2, M.Rock),
				part(v(16, 12, 14), v(0, 40, 0), ROCK2, M.Rock, nil, CFrame.Angles(0.3, 0.4, 0.2)),
				part(v(10, 6, 9), v(4, 46, 3), STRATA2, M.Rock),
			}, { Tag = "BiomeBob" }),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 170,
		Props = {
			"Boulder",
			"DeadShrub",
			block("RockShard", v(3, 8, 3), STRATA2, M.Rock),
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
		strata("GiantMesa", 50, 80, 40, ROCK2, STRATA2, 6),
		prop("GiantSpire", v(16, 90, 16), {
			part(v(16, 40, 16), v(0, 20, 0), ROCK2, M.Rock),
			part(v(11, 30, 11), v(0, 55, 0), STRATA2, M.Rock),
			part(v(6, 20, 6), v(0, 80, 0), ROCK2, M.Rock),
		}),
		prop("HoveringRock", v(30, 70, 30), {
			part(v(30, 6, 30), v(0, 3, 0), STRATA2, M.Rock),
			part(v(26, 16, 22), v(0, 58, 0), ROCK2, M.Rock, nil, CFrame.Angles(0.2, 0.6, 0.1)),
		}, { Tag = "BiomeBob" }),
	}),
	Particles = particles(SMOKE, SAND2, { Size = 3, Lifetime = 4, Rate = 4, Speed = 2, Transparency = 0.5 }),
	Terrain = { Ridge = { Shape = "Hills", Height = 12 } }, -- stub (placeholder)
	Atmosphere = Kit.Atmosphere(), -- stub: the LightingConfig baseline
	Audio = { OneShots = {}, Volume = 0.3, Reverb = "NoReverb" }, -- stub: Loop = "<AssetKey>", OneShots = { "<AssetKey>" }
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used.
	Assets = {},
}
