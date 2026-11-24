--!nonstrict
-- The spawn plaza's per-world look (design doc 4.47 "Moonlit Dojo", WORLD_REDESIGN_SPEC 4 and 4.1). World 1 gets an empty
-- table and every builder keeps its own colours. World 2 keeps World 1's layout, footprint, spawn and services; only
-- these colours and lights change: Shared/BiomeEnvironment (the plaza zone's night profile and petals),
-- Server/PlazaDressing (mesh glow colours, lit lanterns, the Great Sakura's tint) and Server/PlazaAccents (cyber accents).
-- Every World 2 value is a placeholder (design doc 4.47: "Colours and light levels are placeholders"), from variant A
-- of tools/blender/world2/plaza_w2.py.
local WorldConfig = require(script.Parent.WorldConfig)

local hex = Color3.fromHex

local WORLD2 = {
	-- Mesh glow parts by name (PlazaAssets Parts "Glow_*"): the sky loop, the spawn rim and the Market sign turn
	-- violet / lilac / magenta (plaza_w2.py neonb, neonw, neono). Glow_lamp keeps its warm amber.
	Glow = { Glow_neonb = "#A64BFF", Glow_neonw = "#E8C8FF", Glow_neono = "#FF3FA4" },
	-- A PointLight in every Glow_lamp part: the 4 stone lanterns, the stall eaves and the spawn moat ring (placeholder)
	LampLight = { Color = hex("FFB765"), Brightness = 1.5, Range = 20 },
	-- Server/PlazaAccents colours (plaza_w2.py acc1 violet, acc2 magenta, neonw lilac)
	Accent = { Gold = hex("A64BFF"), Amber = hex("FF3FB4"), Paper = hex("E8C8FF"), Pink = hex("E8C8FF") },
	-- The Great Sakura's mesh has its blossoms baked in: a Highlight tints it crimson-violet (plaza_w2.py bloom
	-- #C8326E / #9A2E9E) and a light under the canopy gives the soft glow (placeholders)
	Sakura = {
		Fill = hex("B4308A"),
		FillTransparency = 0.55,
		Light = hex("C8326E"),
		Brightness = 2,
		Range = 40,
		LightHeight = 16, -- studs above the tree's base
	},
	-- The plaza zone's Atmosphere profile (BIOME_ENVIRONMENT_SPEC 5.2, Kit.Atmosphere overrides): a clear night with stars
	-- and the engine's pale moon, ambients raised so runners and UI stay legible. No Skybox key: the place's own sky,
	-- drawn dark by the engine at night. Petals crimson-violet (plaza_w2.py bloom3).
	Atmosphere = {
		Lighting = {
			ClockTime = 0,
			Brightness = 1.6,
			Ambient = hex("4E4A6E"),
			OutdoorAmbient = hex("8A86B8"),
			ExposureCompensation = 0.3,
		},
		Atmosphere = { Density = 0.25, Offset = 0, Haze = 0.4, Glare = 0, Color = hex("2B2C6E"), Decay = hex("1E1F55") },
		Grade = { Saturation = 0.1, Contrast = 0.08, Brightness = 0, TintColor = hex("ECE6FF") },
		SunRays = { Intensity = 0 },
		Bloom = { Intensity = 0.6, Size = 24, Threshold = 1.2 },
		Sky = { SunAngularSize = 8, MoonAngularSize = 24, StarCount = 3000, CelestialBodiesShown = true },
		Clouds = { Cover = 0.15, Density = 0.3, Color = hex("3A3A70") },
		Particles = {
			{
				Texture = "PlazaPetal",
				Color = hex("E070B8"),
				Size = 0.7,
				Rate = 10,
				Lifetime = 7,
				Speed = 2,
				SpreadAngle = 50,
				LightEmission = 0.4,
				Area = Vector3.new(90, 35, 90),
			},
		},
	},
}

return WorldConfig.Id == 2 and WORLD2 or {}
