--!nonstrict
-- Track 10: green sky on local backdrops, blue-green grass, small islands over teal water, plain white dome
-- houses with round windows, tall thin ball-top trees, rock pillars, distant suns. No orb items.
-- Data only (format in Kit). b1 stubs: Terrain, Atmosphere, Audio and Assets; b2 fills them in for this biome.
local Kit = require(script.Parent.Kit)

local M, hex, v, BALL, CYL, UP, part, post, prop, block, gate, patch, giants, SPARKLE, particles, SKY10, GRASS10, WATER10, DOME10, ROCK10, HAZE10, domeHouse, ballTree =
	Kit.M,
	Kit.hex,
	Kit.v,
	Kit.BALL,
	Kit.CYL,
	Kit.UP,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SPARKLE,
	Kit.particles,
	Kit.SKY10,
	Kit.GRASS10,
	Kit.WATER10,
	Kit.DOME10,
	Kit.ROCK10,
	Kit.HAZE10,
	Kit.domeHouse,
	Kit.ballTree

return {
	DisplayName = "Green Alien Planet",
	Ground = { Color = GRASS10, Material = M.Grass },
	Sky = { Color = SKY10 },
	Gate = gate(DOME10, M.SmoothPlastic, HAZE10),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = {
			ballTree,
			block("Shrub", v(5, 3, 5), hex("4FC9A8"), M.Grass),
			prop("RockStack", v(4, 9, 4), {
				part(v(4, 4, 4), v(0, 2, 0), ROCK10, M.Rock),
				part(v(3, 3, 3), v(0.3, 5.5, 0), ROCK10, M.Rock),
				part(v(2, 2, 2), v(0, 8, 0.2), hex("7E8F68"), M.Rock),
			}),
		},
	},
	Landmarks = {
		Offset = 40,
		Every = 22,
		Props = {
			domeHouse("DomeHouse", 16),
			prop("DomeVillage", v(40, 8, 22), {
				part(v(16, 16, 16), v(-10, 0, 0), DOME10, M.SmoothPlastic, BALL),
				part(v(12, 12, 12), v(8, 0, 2), DOME10, M.SmoothPlastic, BALL),
				part(v(10, 10, 10), v(14, 0, -6), DOME10, M.SmoothPlastic, BALL),
				part(v(3, 4, 0.6), v(-10, 2, -7.6), hex("3F6E4F"), M.SmoothPlastic),
				part(v(2.5, 3, 0.6), v(8, 1.5, -4), hex("3F6E4F"), M.SmoothPlastic),
			}, { Glow = HAZE10 }),
			prop("RockPillar", v(10, 41.25, 10), {
				part(v(10, 26, 10), v(0, 13, 0), ROCK10, M.Rock),
				part(v(7, 14, 7), v(0, 33, 0), ROCK10, M.Rock),
				part(v(8, 1.5, 8), v(0, 40.5, 0), GRASS10, M.Grass),
			}),
			prop("CraterPool", v(24, 2, 24), {
				part(v(0.4, 20, 20), v(0, 0.4, 0), WATER10, M.Glass, CYL, UP),
				part(v(24, 2, 4), v(0, 1, -10), ROCK10, M.Rock),
				part(v(24, 2, 4), v(0, 1, 10), ROCK10, M.Rock),
				part(v(4, 2, 16), v(-10, 1, 0), ROCK10, M.Rock),
				part(v(4, 2, 16), v(10, 1, 0), ROCK10, M.Rock),
			}),
		},
	},
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
		Props = {
			prop("GreenSkyMesa", v(60, 95, 20), {
				part(v(60, 30, 18), v(0, 15, -1), ROCK10, M.Rock),
				part(v(40, 4, 14), v(0, 32, -1), GRASS10, M.Grass),
				part(v(60, 40, 1), v(0, 70, 9.5), SKY10, M.SmoothPlastic), -- local green sky backdrop
				part(v(10, 10, 10), v(-12, 80, 7), hex("FFF6C8"), M.Neon, BALL), -- distant suns
				part(v(6, 6, 6), v(14, 88, 7), hex("FFF6C8"), M.Neon, BALL),
			}),
			prop("TealIsland", v(70, 25, 22), {
				part(v(70, 0.4, 22), v(0, 0.2, 0), WATER10, M.Glass),
				part(v(30, 8, 18), v(0, 0, 0), GRASS10, M.Grass, BALL),
				post(18, 0.8, v(-4, 13, 0), hex("7B6A4E"), M.Wood),
				part(v(6, 6, 6), v(-4, 22, 0), GRASS10, M.Grass, BALL),
				part(v(10, 10, 10), v(6, 3, 2), DOME10, M.SmoothPlastic, BALL),
			}),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		Props = {
			"BallTree",
			"Shrub",
			"RockStack",
			block("Pebble", v(3, 1.5, 3), ROCK10, M.Rock),
			domeHouse("SmallDome", 8),
		},
		Patches = {
			patch("Pond", 22, 14, WATER10, M.Glass),
			patch("HazeGrass", 20, 14, HAZE10, M.Grass),
			patch("RockFlat", 14, 10, ROCK10, M.Slate),
		},
	},
	Blocks = giants({
		prop("GiantBallTree", v(24, 70, 24), {
			post(50, 3, v(0, 25, 0), hex("7B6A4E"), M.Wood),
			part(v(24, 24, 24), v(0, 58, 0), GRASS10, M.Grass, BALL),
			part(v(10, 10, 10), v(8, 40, 0), hex("4FC9A8"), M.Grass, BALL),
		}),
		prop("TallPillar", v(20, 92, 20), {
			part(v(20, 60, 20), v(0, 30, 0), ROCK10, M.Rock),
			part(v(14, 30, 14), v(0, 75, 0), ROCK10, M.Rock),
			part(v(16, 2, 16), v(0, 91, 0), GRASS10, M.Grass),
		}),
		domeHouse("BigDome", 40),
	}),
	Particles = particles(SPARKLE, HAZE10, { Size = 0.6, Lifetime = 5, Rate = 5, Speed = 1, LightEmission = 0.6 }),
	Terrain = { Ridge = { Shape = "Hills", Height = 12 } }, -- stub (placeholder)
	Atmosphere = Kit.Atmosphere(), -- stub: the LightingConfig baseline
	Audio = { OneShots = {}, Volume = 0.3, Reverb = "NoReverb" }, -- stub: Loop = "<AssetKey>", OneShots = { "<AssetKey>" }
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used.
	Assets = {},
}
