--!nonstrict
-- Pure part of the per-zone environment (docs/BIOME_ENVIRONMENT_SPEC.md sections 5 and 6): zone lookup from the
-- published polylines, the profile and audio of each zone, and ledger lookups. Client/BiomeEnvironment.client
-- does the blending; server tests require this module too.
--   ReplicatedStorage attributes (set by Main.server): BiomeZone_<n> = "x,z;x,z;..." (track n's centre line),
--   PlazaRadius (studs from the world origin; zone 0 inside).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Themes = require(script.Parent.BiomeThemes)
local Kit = require(script.Parent.BiomeThemes:WaitForChild("Kit"))
local TrackRegistry = require(script.Parent.TrackRegistry)

local BiomeEnvironment = {}
BiomeEnvironment.BLEND_SECONDS = 3 -- placeholder (spec 5.3): the longest blend, at walking / low speed
-- High speed (design doc 4.18): blend and hold are measured in studs of travel, so a fast runner switches sooner
BiomeEnvironment.BLEND_MIN = 0.4 -- placeholder: shortest blend in seconds (sky swaps at its midpoint)
BiomeEnvironment.BLEND_STUDS = 240 -- placeholder: studs of travel one blend spans, clamped to BLEND_MIN..BLEND_SECONDS
BiomeEnvironment.POLL = 0.1 -- placeholder: seconds between zone checks (5.1; was 0.25)
BiomeEnvironment.HOLD = 0.5 -- placeholder: a new zone holds this long before the blend starts (5.1)
BiomeEnvironment.HOLD_STUDS = 40 -- placeholder: or this many studs of travel, whichever is shorter
BiomeEnvironment.WEATHER_MIX = 0.5 -- placeholder: lerp(biome, weather, this) while a weather with a Sky runs (5.2)
BiomeEnvironment.HAZE_PEAK = 1.5 -- placeholder: Atmosphere Haze added at the blend midpoint (5.3)
BiomeEnvironment.DENSITY_PEAK = 0.15 -- placeholder: Atmosphere Density added at the blend midpoint
BiomeEnvironment.PARTICLE_AHEAD = 20 -- placeholder: studs the particle box sits ahead of the camera (5.2)
BiomeEnvironment.PARTICLE_EMITTERS = 2 -- most emitters per profile
BiomeEnvironment.PARTICLE_MAX_RATE = 40 -- placeholder: per emitter
BiomeEnvironment.LOOP_VOLUME = 0.3 -- placeholder (6); a profile's Audio.Volume overrides it (0.2-0.45)
BiomeEnvironment.ONESHOT_EVERY = NumberRange.new(10, 25) -- placeholder: seconds between one-shots
BiomeEnvironment.ONESHOT_DISTANCE = NumberRange.new(30, 80) -- placeholder: studs from the camera
BiomeEnvironment.ONESHOT_VOLUME = NumberRange.new(0.15, 0.25)
BiomeEnvironment.DETAIL_DISTANCE = 400 -- placeholder: REDUCED EFFECTS hides BiomeDetail past this (8)
BiomeEnvironment.ForcedZone = nil -- client tests: a zone number here overrides detection (no hold)
BiomeEnvironment.CurrentZone = nil -- set by the client: the zone it last blended to
BiomeEnvironment.ARENA_ZONE = -1 -- the boss arena (4.37): chosen by Client/BiomeEnvironment, since ZoneAt ignores height

local biomeOf = {} -- track number -> biome key
for _, spec in TrackRegistry.Chain() do
	biomeOf[spec.Number] = spec.Biome
end

local polys = {} -- n -> { x1, z1, x2, z2, ... }

local function poly(n)
	if not polys[n] then
		local text = ReplicatedStorage:GetAttribute("BiomeZone_" .. n)
		if type(text) ~= "string" then
			return nil
		end
		local flat = {}
		for x, z in string.gmatch(text, "([^,;]+),([^;]+)") do
			table.insert(flat, tonumber(x))
			table.insert(flat, tonumber(z))
		end
		polys[n] = flat
	end
	return polys[n]
end

function BiomeEnvironment.BiomeOf(n)
	return biomeOf[n]
end

-- Zone of world point p (Vector3): 0 inside PlazaRadius of the origin, else the track whose published centre line
-- has the nearest point (nil before the polylines are published)
function BiomeEnvironment.ZoneAt(p)
	local radius = ReplicatedStorage:GetAttribute("PlazaRadius") or 0
	if p.X * p.X + p.Z * p.Z <= radius * radius then
		return 0
	end
	local best, zone = math.huge, nil
	for n in biomeOf do
		local flat = poly(n)
		for i = 1, flat and #flat or 0, 2 do
			local dx, dz = flat[i] - p.X, flat[i + 1] - p.Z
			local d = dx * dx + dz * dz
			if d < best then
				best, zone = d, n
			end
		end
	end
	return zone
end

local baseline = Kit.Atmosphere()
-- Zone 0, the plaza: golden hour (owner 2026-11-03, design doc 4.24, spec 2.1). Values are placeholders.
local PLAZA = Kit.Atmosphere({
	Lighting = {
		ClockTime = 16.6,
		OutdoorAmbient = Kit.hex("B09A88"),
		Ambient = Kit.hex("4A3F3C"),
		ExposureCompensation = -0.25,
	},
	Atmosphere = { Density = 0.18, Haze = 0.7, Glare = 0.2, Color = Kit.hex("FFD9B0"), Decay = Kit.hex("D9A58F") },
	Grade = { Saturation = 0.24, TintColor = Kit.hex("FFF0DC") },
	SunRays = { Intensity = 0.1 },
	Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.6 },
	Sky = { Skybox = "SkyGolden", SunAngularSize = 8, MoonAngularSize = 0, StarCount = 0, CelestialBodiesShown = true },
	Clouds = { Cover = 0.32, Density = 0.35, Color = Kit.hex("FFE6D2") },
	Particles = {
		{
			Texture = "PlazaPetal",
			Color = Kit.hex("FFFFFF"),
			Size = 0.7,
			Rate = 10,
			Lifetime = 7,
			Speed = 2,
			SpreadAngle = 50,
			LightEmission = 0,
			Area = Kit.v(90, 35, 90),
		},
	},
})
-- Reuses Track 1's reviewed forest ambience, quieter (rows in BiomeThemes/Speedway)
local PLAZA_AUDIO = { Loop = "AmbForest", OneShots = { "SfxWindChime" }, Volume = 0.2 }
local PLAZA_PETAL = {
	Kind = "Texture",
	Id = "rbxassetid://130260166899982",
	Lane = "B",
	Reviewed = "2026-11-03 rules-auditor",
	Notes = "In-house numpy teardrop, tools/blender/plaza/plaza_petal.py",
}
-- Drawn in-house (tools/blender/plaza/plaza_sky.py, assets/biomes/Plaza/sky): a plain gradient, the same image on the 4 sides.
local PLAZA_SKY = {
	Kind = "Skybox",
	Id = "rbxassetid://103670338630976",
	Lane = "A",
	Reviewed = "2026-11-03 rules-auditor",
	Notes = "In-house numpy gradient, no prompt",
	Faces = {
		Bk = "rbxassetid://103670338630976",
		Ft = "rbxassetid://103670338630976",
		Lf = "rbxassetid://103670338630976",
		Rt = "rbxassetid://103670338630976",
		Up = "rbxassetid://75892213251440",
		Dn = "rbxassetid://137365666705594",
	},
}
-- The boss arena (docs/BOSS_EVENT_SPEC.md "Arena"): Track 8's clear noon and cloud wisps with no terrain clouds or haze.
-- Values are placeholders.
local ARENA = Kit.Atmosphere({
	Lighting = {
		ClockTime = 12,
		Brightness = 2.5,
		Ambient = Kit.hex("5A6878"),
		OutdoorAmbient = Kit.hex("A8BCD0"),
		ExposureCompensation = 0,
	},
	Atmosphere = {
		Density = 0.06, -- thin: Big Raga stands about 900 studs from the lanes and more haze drains his colour
		Offset = 0.1,
		Color = Kit.hex("EAF6FF"),
		Decay = Kit.hex("BFE4FA"),
		Glare = 0,
		Haze = 0,
	},
	Grade = { TintColor = Kit.hex("F6FBFF"), Saturation = 0.1, Contrast = 0.05, Brightness = 0 },
	Bloom = { Intensity = 0.3, Threshold = 1.8 },
	SunRays = { Intensity = 0.05 },
	Sky = { SunAngularSize = 21, MoonAngularSize = 0, StarCount = 0, CelestialBodiesShown = true },
	Clouds = { Cover = 0 },
	Particles = {
		Themes.Snow.Atmosphere.Particles[1],
		{
			Texture = "MoteParticle", -- small white motes floating through the clouds (owner 2026-11-06)
			Color = Kit.hex("FFFFFF"),
			Size = 0.8,
			Rate = 40,
			Lifetime = 8,
			Speed = 1.5,
			SpreadAngle = 180,
			LightEmission = 0.3,
		},
	},
})

-- Atmosphere profile (spec 5.2) of a zone; zone 0 has the plaza's, any other zone without one the LightingConfig baseline
function BiomeEnvironment.Profile(zone)
	if zone == 0 then
		return PLAZA
	elseif zone == BiomeEnvironment.ARENA_ZONE then
		return ARENA
	end
	local theme = Themes[biomeOf[zone]]
	return theme and theme.Atmosphere or baseline
end

function BiomeEnvironment.Audio(zone)
	if zone == 0 then
		return PLAZA_AUDIO
	elseif zone == BiomeEnvironment.ARENA_ZONE then
		return Themes.Snow.Audio
	end
	local theme = Themes[biomeOf[zone]]
	return theme and theme.Audio or {}
end

-- The usable ledger row (reviewed, with an Id, of `kind` when given) of `key` in a biome's Assets (spec 4.4), or nil
function BiomeEnvironment.Row(biome, key, kind)
	local theme = Themes[biome]
	local row = key and theme and theme.Assets and theme.Assets[key]
	if type(row) ~= "table" or type(row.Id) ~= "string" or row.Id == "" then
		return nil
	end
	if type(row.Reviewed) ~= "string" or row.Reviewed == "" or (kind and row.Kind ~= kind) then
		return nil
	end
	return row
end

function BiomeEnvironment.Asset(zone, key, kind)
	if zone == 0 then
		if key == "SkyGolden" then
			return PLAZA_SKY
		elseif key == "PlazaPetal" then
			return PLAZA_PETAL
		end
		return BiomeEnvironment.Row("Speedway", key, kind)
	elseif zone == BiomeEnvironment.ARENA_ZONE then
		return BiomeEnvironment.Row("Snow", key, kind)
	end
	return BiomeEnvironment.Row(biomeOf[zone], key, kind)
end

-- Sine ease, 0..1
function BiomeEnvironment.Ease(t)
	t = math.clamp(t, 0, 1)
	return (1 - math.cos(math.pi * t)) / 2
end

return BiomeEnvironment
