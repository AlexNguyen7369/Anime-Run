--!nonstrict
-- Track 5 (night): neon avenue, a scramble crossing, an overpass, a temple school on a hill, purple fog.
-- Signs are abstract neon shapes with no text. Tints only its own props and ground.
-- Data only (format in Kit). b1 stubs: Terrain, Atmosphere, Audio and Assets; b2 fills them in for this biome.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, part, post, prop, block, gate, patch, giants, SMOKE, particles, NIGHT5, FOG5, PINK5, CYAN5, YELLOW5, CONCRETE5, signTower =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.BALL,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SMOKE,
	Kit.particles,
	Kit.NIGHT5,
	Kit.FOG5,
	Kit.PINK5,
	Kit.CYAN5,
	Kit.YELLOW5,
	Kit.CONCRETE5,
	Kit.signTower

return {
	DisplayName = "Neon Cursed City",
	Ground = { Color = NIGHT5, Material = M.Asphalt },
	Sky = { Color = FOG5 },
	Gate = gate(CONCRETE5, M.Concrete, PINK5),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = {
			prop("TrafficLight", v(2, 14, 2), {
				post(14, 0.6, v(0, 7, 0), rgb(40, 40, 48), M.Metal),
				part(v(1.4, 4, 1.4), v(0, 12, -0.6), rgb(30, 30, 36), M.Metal),
				part(v(1, 1, 0.3), v(0, 13, -1.4), hex("FF4040"), M.Neon),
				part(v(1, 1, 0.3), v(0, 11, -1.4), hex("40FF80"), M.Neon),
			}),
			prop("NeonSign", v(6, 12, 1), {
				post(12, 0.5, v(-2.5, 6, 0), CONCRETE5, M.Metal),
				part(v(6, 3, 0.6), v(0, 10, 0), PINK5, M.Neon),
				part(v(4, 1, 0.7), v(0, 7.5, 0), CYAN5, M.Neon),
			}),
			block("VendingMachine", v(3, 6, 2.4), hex("E8E8F0"), M.SmoothPlastic, {
				part(v(2.4, 3.4, 0.2), v(0, 3.8, -1.25), CYAN5, M.Neon),
			}),
		},
	},
	Landmarks = {
		Offset = 40,
		Every = 18,
		Props = {
			signTower(),
			prop("VideoScreen", v(24, 32, 16), {
				part(v(24, 30, 16), v(0, 15, 0), hex("2A2A34"), M.Concrete),
				part(v(18, 12, 0.6), v(0, 22, -8.3), hex("3C2A7A"), M.Neon),
				part(v(6, 6, 0.7), v(-4, 22, -8.4), PINK5, M.Neon),
				part(v(5, 8, 0.7), v(5, 21, -8.4), CYAN5, M.Neon),
				part(v(24.4, 2, 16.4), v(0, 31, 0), rgb(50, 50, 60), M.Concrete),
			}, { Glow = CYAN5 }),
			prop("Overpass", v(40, 18, 10), {
				part(v(4, 14, 4), v(-16, 7, 0), CONCRETE5, M.Concrete),
				part(v(4, 14, 4), v(16, 7, 0), CONCRETE5, M.Concrete),
				part(v(40, 3, 10), v(0, 15.5, 0), CONCRETE5, M.Concrete),
				part(v(40, 1, 0.6), v(0, 17.5, -4.7), YELLOW5, M.Neon),
			}, { Glow = YELLOW5 }),
			prop("TempleGate", v(20, 15, 9), {
				post(12, 1.4, v(-6, 6, 0), hex("4A2E22"), M.Wood),
				post(12, 1.4, v(6, 6, 0), hex("4A2E22"), M.Wood),
				part(v(18, 1.5, 8), v(0, 12.75, 0), hex("2A2A3A"), M.Slate),
				part(v(14, 1.5, 6), v(0, 14.25, 0), hex("2A2A3A"), M.Slate),
				part(v(20, 0.6, 9), v(0, 12, 0), hex("4A2E22"), M.Wood),
			}, { Glow = rgb(255, 180, 120) }),
		},
	},
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
		Props = {
			prop("TempleHill", v(60, 37, 22), {
				part(v(60, 22, 20), v(0, 11, 1), hex("1E1A2E"), M.Rock),
				part(v(24, 10, 12), v(0, 27, 1), hex("4A2E22"), M.WoodPlanks),
				part(v(30, 2, 18), v(0, 33, 1), hex("2A2A3A"), M.Slate),
				part(v(20, 3, 10), v(0, 35.5, 1), hex("2A2A3A"), M.Slate),
				part(v(10, 22, 1), v(0, 11, -9.5), rgb(70, 66, 80), M.Slate), -- stairs up the hill
			}),
			prop("NeonSkyline", v(60, 60.5, 21), {
				part(v(18, 60, 18), v(-20, 30, 0), hex("1E1C2A"), M.Concrete),
				part(v(16, 44, 16), v(0, 22, 0), hex("24222F"), M.Concrete),
				part(v(18, 52, 18), v(20, 26, 0), hex("1E1C2A"), M.Concrete),
				part(v(18.4, 1, 18.4), v(-20, 60, 0), PINK5, M.Neon),
				part(v(16.4, 1, 16.4), v(0, 44, 0), CYAN5, M.Neon),
				part(v(18.4, 1, 18.4), v(20, 52, 0), YELLOW5, M.Neon),
				part(v(60, 30, 1), v(0, 30, 10), FOG5, M.SmoothPlastic), -- local fog backdrop
			}),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 150,
		Props = {
			"VendingMachine",
			"NeonSign",
			block("Bollard", v(1.4, 3, 1.4), YELLOW5, M.Metal),
			prop("FogPuff", v(14, 7, 14), { part(v(14, 7, 14), v(0, 3.5, 0), FOG5, M.SmoothPlastic, BALL) }),
			"TrafficLight",
		},
		Patches = {
			patch("Crosswalk", 22, 6, hex("E8E8EE"), M.Concrete),
			patch("NeonPuddle", 14, 10, PINK5, M.Glass),
			patch("CyanPuddle", 12, 9, CYAN5, M.Glass),
		},
	},
	Blocks = giants({
		prop("GiantSignTower", v(30, 80.5, 30.6), {
			part(v(30, 80, 30), v(0, 40, 0), hex("2A2A34"), M.Concrete),
			part(v(24, 10, 0.6), v(0, 60, -15.3), PINK5, M.Neon),
			part(v(24, 10, 0.6), v(0, 40, -15.3), CYAN5, M.Neon),
			part(v(24, 10, 0.6), v(0, 20, -15.3), YELLOW5, M.Neon),
			part(v(30.4, 1, 30.4), v(0, 80, 0), PINK5, M.Neon),
		}),
		prop("ConcreteBlock", v(36, 50, 30), {
			part(v(36, 50, 30), v(0, 25, 0), CONCRETE5, M.Concrete),
			part(v(36.3, 4, 30.3), v(0, 30, 0), hex("3A3550"), M.Glass),
			part(v(36.3, 4, 30.3), v(0, 40, 0), hex("3A3550"), M.Glass),
		}),
		prop("RailPier", v(40, 33, 12), {
			part(v(6, 24, 6), v(-14, 12, 0), CONCRETE5, M.Concrete),
			part(v(6, 24, 6), v(14, 12, 0), CONCRETE5, M.Concrete),
			part(v(40, 5, 12), v(0, 26.5, 0), CONCRETE5, M.Concrete),
			part(v(12, 4, 6), v(0, 31, 0), hex("8A8AA0"), M.Metal),
		}),
	}),
	Particles = particles(
		SMOKE,
		FOG5,
		{ Size = 4, Lifetime = 5, Rate = 4, Speed = 1, Transparency = 0.4, LightEmission = 0.2 }
	),
	Terrain = { Ridge = { Shape = "Hills", Height = 12 } }, -- stub (placeholder)
	Atmosphere = Kit.Atmosphere(), -- stub: the LightingConfig baseline
	Audio = { OneShots = {}, Volume = 0.3, Reverb = "NoReverb" }, -- stub: Loop = "<AssetKey>", OneShots = { "<AssetKey>" }
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used.
	Assets = {},
}
