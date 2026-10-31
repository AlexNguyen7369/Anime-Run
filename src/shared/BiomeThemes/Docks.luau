--!nonstrict
-- Track 3: sandy island, plank docks, a moored caravel with a plain sail (no flag, no figurehead), palms,
-- a windmill, white houses with red and blue roofs
-- Data only (format in Kit). b1 stubs: Terrain, Atmosphere, Audio and Assets; b2 fills them in for this biome.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, part, post, prop, block, house, gate, patch, giants, SPARKLE, particles, SAND3, SEA3, WHITE3, ROOF3, DOCK3, PALM3 =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.BALL,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.house,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SPARKLE,
	Kit.particles,
	Kit.SAND3,
	Kit.SEA3,
	Kit.WHITE3,
	Kit.ROOF3,
	Kit.DOCK3,
	Kit.PALM3

return {
	DisplayName = "Pirate Harbor Isle",
	Ground = { Color = SAND3, Material = M.Sand },
	Sky = { Color = hex("7FD0F5") },
	Gate = gate(DOCK3, M.WoodPlanks),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = {
			prop("Palm", v(10, 17, 10), {
				post(8, 1, v(0, 4, 0), hex("8A6A44"), M.Wood),
				part(v(1, 8, 1), v(0.8, 11, 0), hex("8A6A44"), M.Wood, nil, CFrame.Angles(0, 0, -0.2)),
				part(v(10, 0.6, 3), v(1.6, 15.5, 0), PALM3, M.Grass, nil, CFrame.Angles(0, 0, -0.3)),
				part(v(3, 0.6, 10), v(1.6, 15.5, 0), PALM3, M.Grass, nil, CFrame.Angles(0.3, 0, 0)),
			}),
			prop("Barrel", v(3.2, 4, 3.2), {
				post(4, 3, v(0, 2, 0), DOCK3, M.Wood),
				post(0.4, 3.2, v(0, 1, 0), rgb(70, 70, 70), M.Metal),
				post(0.4, 3.2, v(0, 3, 0), rgb(70, 70, 70), M.Metal),
			}),
			block("CrateStack", v(4, 7, 4), hex("A9783F"), M.WoodPlanks, {
				part(v(3, 3, 3), v(0.3, 5.5, 0.2), hex("C29055"), M.WoodPlanks),
			}),
		},
	},
	Landmarks = {
		Offset = 40,
		Every = 22,
		Props = {
			prop("Caravel", v(40, 29, 18), {
				part(v(36, 6, 10), v(0, 3, 0), DOCK3, M.WoodPlanks),
				part(v(10, 3, 8), v(12, 7.5, 0), hex("6E4421"), M.WoodPlanks),
				part(v(38, 1, 12), v(0, 6.5, 0), hex("A7774A"), M.WoodPlanks),
				post(22, 1, v(-6, 17, 0), hex("6E4421"), M.Wood),
				post(18, 1, v(8, 15, 0), hex("6E4421"), M.Wood),
				part(v(0.4, 12, 10), v(-6, 20, 0), WHITE3, M.Fabric), -- plain sail
				part(v(0.4, 9, 8), v(8, 17, 0), WHITE3, M.Fabric),
				part(v(40, 0.3, 18), v(0, 0.15, 0), SEA3, M.Glass), -- the water it rests in
			}, { Tag = "BiomeBob", Glow = rgb(255, 210, 140) }),
			prop("Windmill", v(22, 24, 12), {
				part(v(9, 20, 9), v(0, 10, 0), WHITE3, M.Plaster),
				part(v(11, 4, 11), v(0, 22, 0), ROOF3, M.Slate),
				part(v(2, 22, 0.6), v(0, 12, -5.2), hex("B08A5A"), M.WoodPlanks),
				part(v(22, 2, 0.6), v(0, 12, -5.2), hex("B08A5A"), M.WoodPlanks),
			}, { Glow = rgb(255, 210, 140) }),
			house("HarborHouse", 16, 10, 14, WHITE3, ROOF3, { Trim = DOCK3, Window = SEA3, Glow = rgb(255, 210, 140) }),
			house("BlueRoofHouse", 14, 9, 12, WHITE3, hex("2E6FB0"), { Trim = DOCK3, Window = SEA3, Floors = 2 }),
			prop("Pier", v(14, 3, 38), {
				part(v(10, 1, 36), v(0, 2.5, 0), DOCK3, M.WoodPlanks),
				post(4, 1, v(-4.5, 1.5, -16), hex("6E4421"), M.Wood),
				post(4, 1, v(4.5, 1.5, -16), hex("6E4421"), M.Wood),
				post(4, 1, v(-4.5, 1.5, 16), hex("6E4421"), M.Wood),
				post(4, 1, v(4.5, 1.5, 16), hex("6E4421"), M.Wood),
				part(v(14, 0.3, 38), v(0, 0.15, 0), SEA3, M.Glass),
			}),
		},
	},
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
		Props = {
			prop("SeaIslet", v(80, 18, 22), {
				part(v(80, 0.4, 22), v(0, 0.2, 0), SEA3, M.Glass), -- open sea
				part(v(30, 6, 18), v(0, 0, 0), SAND3, M.Sand, BALL),
				post(14, 1.4, v(2, 9, 0), hex("8A6A44"), M.Wood),
				part(v(14, 1, 4), v(2, 16.5, 0), PALM3, M.Grass),
				part(v(4, 1, 14), v(2, 16.5, 0), PALM3, M.Grass),
			}),
			prop("Lighthouse", v(12, 47, 12), {
				part(v(12, 4, 12), v(0, 2, 0), hex("8C8C8C"), M.Rock),
				post(36, 8, v(0, 22, 0), WHITE3, M.Plaster),
				post(5, 8.4, v(0, 18, 0), ROOF3, M.Plaster),
				post(5, 8.4, v(0, 30, 0), ROOF3, M.Plaster),
				part(v(6, 5, 6), v(0, 42.5, 0), hex("FFE8A0"), M.Neon),
				part(v(8, 2, 8), v(0, 46, 0), ROOF3, M.Metal),
			}),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		Props = {
			"Palm",
			"Barrel",
			prop("Buoy", v(3.1, 3, 3.1), {
				part(v(3, 3, 3), v(0, 1.5, 0), ROOF3, M.SmoothPlastic, BALL),
				part(v(3.1, 1, 3.1), v(0, 1.5, 0), WHITE3, M.SmoothPlastic),
			}),
			prop("RopeCoil", v(3, 1, 3), { post(1, 3, v(0, 0.5, 0), hex("C9AE7C"), M.Fabric) }),
			block("FishingNet", v(8, 4, 1), hex("6B5A3E"), M.Fabric),
			"CrateStack",
		},
		Patches = {
			patch("TidePool", 22, 14, SEA3, M.Glass),
			patch("WetSand", 26, 16, hex("D9C48E"), M.Sand),
			patch("Shells", 12, 10, hex("F7F0E0"), M.Pebble),
		},
	},
	Blocks = giants({
		prop("GiantPalm", v(24, 46, 24), {
			post(24, 3, v(0, 12, 0), hex("8A6A44"), M.Wood),
			part(v(2.6, 20, 2.6), v(2, 33, 0), hex("8A6A44"), M.Wood, nil, CFrame.Angles(0, 0, -0.2)),
			part(v(24, 1.2, 6), v(4, 44, 0), PALM3, M.Grass, nil, CFrame.Angles(0, 0, -0.3)),
			part(v(6, 1.2, 24), v(4, 44, 0), PALM3, M.Grass, nil, CFrame.Angles(0.3, 0, 0)),
		}),
		house("Warehouse", 40, 18, 28, hex("D8CDB4"), ROOF3, { WallMaterial = M.WoodPlanks, Trim = DOCK3 }),
		prop("DockCrane", v(10, 36, 30), {
			post(34, 3, v(0, 17, 6), hex("6E4421"), M.Wood),
			part(v(2, 2, 28), v(0, 34, -6), hex("6E4421"), M.Wood),
			part(v(0.4, 12, 0.4), v(0, 28, -18), hex("C9AE7C"), M.Fabric),
			part(v(4, 4, 4), v(0, 20, -18), hex("A9783F"), M.WoodPlanks),
		}),
	}),
	Particles = particles(SPARKLE, rgb(230, 248, 255), {
		Size = 0.5,
		Lifetime = 3,
		Speed = 3,
		Acceleration = v(0, -2, 0),
		LightEmission = 0.4,
	}),
	Terrain = { Ridge = { Shape = "Hills", Height = 12 } }, -- stub (placeholder)
	Atmosphere = Kit.Atmosphere(), -- stub: the LightingConfig baseline
	Audio = { OneShots = {}, Volume = 0.3, Reverb = "NoReverb" }, -- stub: Loop = "<AssetKey>", OneShots = { "<AssetKey>" }
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used.
	Assets = {},
}
