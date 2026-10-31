--!nonstrict
-- Track 9 (night): white dunes, dead white trees, a plain dome palace with a few towers on the horizon, a
-- crescent moon on a local black backdrop, no mask designs. Tints only its own props and ground.
-- Data only (format in Kit). b1 stubs: Terrain, Atmosphere, Audio and Assets; b2 fills them in for this biome.
local Kit = require(script.Parent.Kit)

local M, hex, v, BALL, CYL, FACE, part, prop, block, deadTree, gate, patch, giants, SPARKLE, particles, SAND9, TREE9, SKY9, MOON9, SHADOW9, ROCK9 =
	Kit.M,
	Kit.hex,
	Kit.v,
	Kit.BALL,
	Kit.CYL,
	Kit.FACE,
	Kit.part,
	Kit.prop,
	Kit.block,
	Kit.deadTree,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SPARKLE,
	Kit.particles,
	Kit.SAND9,
	Kit.TREE9,
	Kit.SKY9,
	Kit.MOON9,
	Kit.SHADOW9,
	Kit.ROCK9

return {
	DisplayName = "Spirit Realm Desert",
	Ground = { Color = SAND9, Material = M.Sand },
	Sky = { Color = SKY9 },
	Gate = gate(TREE9, M.Marble, MOON9),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = {
			deadTree("DeadWhiteTree", 14, TREE9, M.Marble),
			block("WhiteRock", v(5, 3, 4), hex("E4E4DE"), M.Rock),
			prop("BrokenPillar", v(3, 8, 3), {
				part(v(3, 6, 3), v(0, 3, 0), TREE9, M.Marble),
				part(v(2.4, 2, 2.4), v(0.3, 7, 0), TREE9, M.Marble, nil, CFrame.Angles(0.2, 0, 0.3)),
			}),
		},
	},
	Landmarks = {
		Offset = 40,
		Every = 22,
		Props = {
			prop("BoneArch", v(22, 18, 4), {
				part(v(3, 14, 3), v(-8, 6.5, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0, -0.3)),
				part(v(3, 14, 3), v(8, 6.5, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0, 0.3)),
				part(v(14, 3, 3), v(0, 15, 0), TREE9, M.Marble),
				part(v(4, 3, 3.2), v(0, 16.5, 0), MOON9, M.Neon),
			}, { Glow = MOON9 }),
			deadTree("CrystalTree", 30, hex("EDEDF2"), M.Glass),
			block("ShadowOutcrop", v(20, 19, 14), ROCK9, M.Rock, {
				part(v(10, 8, 8), v(4, 15, 2), ROCK9, M.Rock),
			}),
			prop("PillarRuin", v(16, 16.5, 10), {
				part(v(16, 1, 10), v(0, 0.5, 0), TREE9, M.Marble),
				part(v(3, 14, 3), v(-5, 8, 0), TREE9, M.Marble),
				part(v(3, 9, 3), v(5, 5.5, 0), TREE9, M.Marble),
				part(v(12, 2, 3), v(-1, 15.5, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0, 0.1)),
			}),
		},
	},
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
		Props = {
			prop("DomePalace", v(70, 40, 22), {
				part(v(70, 10, 22), v(0, 5, 0), hex("ECECE6"), M.Marble),
				part(v(44, 44, 20), v(0, 10, 0), hex("F6F6F2"), M.Marble, BALL),
				part(v(6, 40, 6), v(-30, 20, -7), hex("ECECE6"), M.Marble),
				part(v(6, 32, 6), v(30, 16, -7), hex("ECECE6"), M.Marble),
				part(v(6, 36, 6), v(30, 18, 7), hex("ECECE6"), M.Marble),
			}),
			prop("CrescentMoon", v(50, 117, 5), {
				part(v(50, 50, 1), v(0, 92, 2), SKY9, M.SmoothPlastic), -- local black sky backdrop
				part(v(1, 22, 22), v(0, 92, 1), MOON9, M.Neon, CYL, FACE),
				part(v(1, 20, 20), v(5, 95, 0.4), SKY9, M.SmoothPlastic, CYL, FACE), -- bites out the crescent
				part(v(4, 66, 4), v(0, 33, 4), ROCK9, M.Rock), -- holds it up, behind the backdrop
			}),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		Props = {
			"DeadWhiteTree",
			"WhiteRock",
			"BrokenPillar",
			block("ShadowRock", v(6, 3, 5), ROCK9, M.Rock),
			prop("BonePile", v(6, 1.7, 4), {
				part(v(6, 1, 1), v(0, 0.5, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0.4, 0)),
				part(v(5, 1, 1), v(0, 1.2, 0), TREE9, M.Marble, nil, CFrame.Angles(0, -0.6, 0)),
			}),
		},
		Patches = {
			patch("ShadowDune", 26, 16, SHADOW9, M.Sand),
			patch("BrightSand", 20, 14, hex("FAFAF8"), M.Sand),
			patch("DarkRock", 14, 10, ROCK9, M.Slate),
		},
	},
	Blocks = giants({
		deadTree("GiantDeadTree", 60, TREE9, M.Marble),
		prop("DomeTower", v(30, 59, 30), {
			part(v(20, 44, 20), v(0, 22, 0), hex("ECECE6"), M.Marble),
			part(v(30, 30, 30), v(0, 44, 0), hex("F6F6F2"), M.Marble, BALL),
		}),
		block("WhiteMonolith", v(16, 70, 10), hex("E4E4DE"), M.Marble, {
			part(v(16.4, 2, 10.4), v(0, 50, 0), SHADOW9, M.Slate),
		}),
	}),
	Particles = particles(SPARKLE, MOON9, {
		Size = 0.5,
		Lifetime = 5,
		Rate = 5,
		Speed = 1,
		Acceleration = v(0, 0.5, 0),
		LightEmission = 0.8,
	}),
	Terrain = { Ridge = { Shape = "Hills", Height = 12 } }, -- stub (placeholder)
	Atmosphere = Kit.Atmosphere(), -- stub: the LightingConfig baseline
	Audio = { OneShots = {}, Volume = 0.3, Reverb = "NoReverb" }, -- stub: Loop = "<AssetKey>", OneShots = { "<AssetKey>" }
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used.
	Assets = {},
}
