--!nonstrict
-- Track 4 (night): Taisho-style wooden street, wisteria groves and arches, lit stone lanterns, a full moon.
-- Tints only its own props and ground (never global Lighting).
-- Data only (format in Kit). b1 stubs: Terrain, Atmosphere, Audio and Assets; b2 fills them in for this biome.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, CYL, FACE, part, post, prop, block, pine, frameGate, stoneLantern, house, gate, patch, giants, SPARKLE, particles, NIGHT4, WISTERIA4, BLOSSOM4, DARKWOOD4, LANTERN4, MOON4, wisteriaTree =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.BALL,
	Kit.CYL,
	Kit.FACE,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.pine,
	Kit.frameGate,
	Kit.stoneLantern,
	Kit.house,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SPARKLE,
	Kit.particles,
	Kit.NIGHT4,
	Kit.WISTERIA4,
	Kit.BLOSSOM4,
	Kit.DARKWOOD4,
	Kit.LANTERN4,
	Kit.MOON4,
	Kit.wisteriaTree

return {
	DisplayName = "Wisteria Night Mountain",
	Ground = { Color = NIGHT4, Material = M.Grass },
	Sky = { Color = hex("15142B") },
	Gate = gate(DARKWOOD4, M.Wood, LANTERN4),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = {
			stoneLantern("StoneLantern", 7, rgb(110, 108, 120), LANTERN4),
			wisteriaTree,
			block("WoodFence", v(10, 3.4, 0.8), DARKWOOD4, M.WoodPlanks, {
				part(v(10, 0.4, 0.8), v(0, 3.2, 0), hex("2A1E15"), M.Wood),
			}),
		},
	},
	Landmarks = {
		Offset = 40,
		Every = 20,
		Props = {
			house("TaishoShop", 18, 10, 14, DARKWOOD4, hex("2B2B3A"), {
				WallMaterial = M.WoodPlanks,
				Trim = hex("1E140C"),
				Window = LANTERN4,
				WindowMaterial = M.Neon, -- glowing paper doors
				Floors = 2,
				Glow = LANTERN4,
			}),
			prop("WisteriaArch", v(20, 16, 6), {
				post(14, 1.2, v(-8, 7, 0), DARKWOOD4, M.Wood),
				post(14, 1.2, v(8, 7, 0), DARKWOOD4, M.Wood),
				part(v(20, 3, 6), v(0, 14.5, 0), WISTERIA4, M.Grass),
				part(v(1.4, 6, 1.4), v(-5, 10, 0), BLOSSOM4, M.Grass),
				part(v(1.4, 7, 1.4), v(0, 9.5, 0), WISTERIA4, M.Grass),
				part(v(1.4, 6, 1.4), v(5, 10, 0), BLOSSOM4, M.Grass),
			}, { Glow = BLOSSOM4 }),
			frameGate("PlainShrineGate", 10, 12, hex("6B4A2E"), M.Wood),
			prop("StoneStair", v(14, 8, 16), {
				part(v(14, 2, 16), v(0, 1, 0), rgb(90, 88, 100), M.Slate),
				part(v(14, 2, 12), v(0, 3, 2), rgb(90, 88, 100), M.Slate),
				part(v(14, 2, 8), v(0, 5, 4), rgb(90, 88, 100), M.Slate),
				part(v(14, 2, 4), v(0, 7, 6), rgb(90, 88, 100), M.Slate),
			}),
		},
	},
	Horizon = {
		Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
		Props = {
			prop("MoonPeak", v(60, 105, 20), {
				part(v(60, 36, 20), v(0, 18, 0), hex("26243F"), M.Rock),
				part(v(34, 20, 14), v(0, 46, 0), WISTERIA4, M.Grass),
				part(v(1, 18, 18), v(0, 96, 8), MOON4, M.Neon, CYL, FACE), -- full moon disk
			}),
			prop("WisteriaHill", v(56, 40, 20), {
				part(v(56, 22, 20), v(0, 11, 0), hex("26243F"), M.Rock),
				part(v(40, 24, 20), v(0, 28, 0), WISTERIA4, M.Grass, BALL),
			}),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		Props = {
			"WisteriaTree",
			"StoneLantern",
			pine("DarkPine", 22, DARKWOOD4, hex("1F3A2E")),
			prop("HangingLantern", v(2.4, 8, 2.4), {
				post(6, 0.4, v(0, 3, 0), DARKWOOD4, M.Wood),
				part(v(2, 2.6, 2), v(0, 6.5, 0), hex("F2B66B"), M.Neon, BALL),
			}),
			block("Bush", v(6, 4, 6), hex("2A2848"), M.Grass),
		},
		Patches = {
			patch("PetalCarpet", 22, 16, BLOSSOM4, M.Grass),
			patch("StonePath", 26, 6, rgb(80, 78, 92), M.Slate),
			patch("DarkMoss", 18, 14, hex("232E2A"), M.Grass),
		},
	},
	Blocks = giants({
		prop("GiantWisteria", v(40, 54, 40), {
			post(30, 4, v(0, 15, 0), DARKWOOD4, M.Wood),
			part(v(40, 24, 40), v(0, 42, 0), WISTERIA4, M.Grass, BALL),
			part(v(4, 16, 4), v(-12, 26, -10), BLOSSOM4, M.Grass),
			part(v(4, 14, 4), v(12, 27, 8), BLOSSOM4, M.Grass),
		}),
		pine("DarkGiantPine", 70, DARKWOOD4, hex("1F3A2E")),
		house("TaishoHall", 30, 14, 24, DARKWOOD4, hex("2B2B3A"), {
			WallMaterial = M.WoodPlanks,
			Window = LANTERN4,
			WindowMaterial = M.Neon,
			Floors = 2,
		}),
	}),
	Particles = particles(SPARKLE, BLOSSOM4, {
		Size = 0.7,
		Lifetime = 6,
		Speed = 1,
		Acceleration = v(0.4, -1.2, 0),
		LightEmission = 0.5,
	}),
	Terrain = { Ridge = { Shape = "Hills", Height = 12 } }, -- stub (placeholder)
	Atmosphere = Kit.Atmosphere(), -- stub: the LightingConfig baseline
	Audio = { OneShots = {}, Volume = 0.3, Reverb = "NoReverb" }, -- stub: Loop = "<AssetKey>", OneShots = { "<AssetKey>" }
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used.
	Assets = {},
}
