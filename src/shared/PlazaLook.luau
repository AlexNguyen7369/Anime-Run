--!nonstrict
-- The spawn plaza's per-world look (design doc 4.47 "Rift Shrine", WORLD_REDESIGN_SPEC 4 and 4.1). World 1 gets an empty
-- table and every builder keeps its own colours. World 2 keeps World 1's layout, footprint, spawn and services; only
-- these colours, lights and set pieces are added: Shared/BiomeEnvironment (the plaza zone's dusk profile),
-- Server/PlazaDressing (mesh glow colours, lit lanterns) and Server/PlazaAccents (cyber accents, the rift, the floating
-- islands). Every World 2 value is a placeholder (design doc 4.47: "Colours and light levels are placeholders"), from
-- variant B of tools/blender/world2/plaza_w2.py (renders in assets/world2_draft/plaza/B).
local WorldConfig = require(script.Parent.WorldConfig)

local hex = Color3.fromHex
local v = Vector3.new

-- The torii's view axis from the spawn (PlazaAssets HeroTorii at (-84, 78)), as plaza_w2.py's bp.along
local AXIS_LEN = math.sqrt(84 * 84 + 78 * 78)
local AXIS = v(-84, 0, 78) / AXIS_LEN

local WORLD2 = {
	-- Mesh glow parts by name (PlazaAssets Parts "Glow_*"): the sky loop, the spawn rim and the Market sign turn cyan
	-- (plaza_w2.py B neonb, neonw, neono). Glow_lamp keeps its warm amber.
	Glow = {
		Glow_neonb = "#3CE6FF",
		Glow_neonw = "#C8F8FF",
		Glow_neono = "#4A8CFF",
		-- the world gate's piece (draft_gate.py COLOURS cyan: the gate back to World 1)
		Glow_g1 = "#7FE4FF",
		Glow_g2 = "#22A8EE",
		Glow_g3 = "#1A5CC4",
		Glow_gdim1 = "#1C5A90",
		Glow_gdim2 = "#123F6E",
		Glow_gvoid = "#071A3C",
	},
	-- A PointLight in every Glow_lamp part: the 4 stone lanterns, the 3 stall eaves and the spawn moat ring (B shows them lit)
	LampLight = { Color = hex("FFB765"), Brightness = 1, Range = 18 },
	-- Server/PlazaAccents colours (plaza_w2.py B acc1 cyan, acc2 periwinkle, neonw, neono)
	Accent = { Gold = hex("3CE6FF"), Amber = hex("7A9CFF"), Paper = hex("C8F8FF"), Pink = hex("4A8CFF") },
	-- A generic dimensional rift (plaza_w2.py rift(): no show's gate design): a swirling blue-violet disc in a ring of
	-- floating stones, above and beyond the torii on its view axis, facing the spawn
	Rift = {
		Centre = v(AXIS.X * (AXIS_LEN + 95), 88, AXIS.Z * (AXIS_LEN + 95)),
		Face = -AXIS, -- toward the spawn
		Radius = 32, -- the stone ring
		Stones = 22,
		Rock = hex("868072"),
		Blue = hex("1E50FF"),
		Violet = hex("7A2BFF"),
		Rim = hex("9FE8FF"),
	},
	-- Five floating rock islands outside the plaza floor (x +-94, z +-110), clear of the ring, the sky loop and the
	-- return gate: { x, z, top y, radius }, a lantern on every second one
	Islands = {
		{ -124, -34, 50, 15 },
		{ 120, 46, 62, 12 },
		{ 26, 140, 56, 17 },
		{ -46, -136, 66, 13 },
		{ -150, 30, 78, 10 },
	},
	IslandColors = { Rock = hex("868072"), Slab = hex("94836A"), Grass = hex("6F9A4E"), Bloom = hex("FFB7D4") },
	-- The plaza zone's Atmosphere profile (BIOME_ENVIRONMENT_SPEC 5.2, Kit.Atmosphere overrides): dusk with a low warm
	-- sun (plaza_w2.py B sun 10 degrees up, #FFB08A; sky peach to violet), ambients kept up so runners and UI stay
	-- legible. No Skybox key: the place's own sky, coloured by the engine at dusk. No Particles: World 1's petals stay.
	Atmosphere = {
		Lighting = {
			ClockTime = 17.7,
			Brightness = 2.2,
			Ambient = hex("6A5A78"),
			OutdoorAmbient = hex("A88CB0"),
			ExposureCompensation = 0.1,
		},
		Atmosphere = {
			Density = 0.22,
			Offset = 0.05,
			Haze = 1.2,
			Glare = 0.3,
			Color = hex("E07A8A"),
			Decay = hex("7A5AA8"),
		},
		Grade = { Saturation = 0.15, Contrast = 0.08, Brightness = 0, TintColor = hex("FFE8E6") },
		SunRays = { Intensity = 0.1, Spread = 0.6 },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.4 },
		Sky = { SunAngularSize = 14, MoonAngularSize = 0, StarCount = 0, CelestialBodiesShown = true },
		Clouds = { Cover = 0.25, Density = 0.3, Color = hex("F0A8A0") },
	},
}

return WorldConfig.Id == 2 and WORLD2 or {}
