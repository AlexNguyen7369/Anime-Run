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
BiomeEnvironment.BLEND_SECONDS = 3 -- placeholder (spec 5.3)
BiomeEnvironment.POLL = 0.25 -- placeholder: seconds between zone checks (5.1)
BiomeEnvironment.HOLD = 0.5 -- placeholder: a new zone holds this long before the blend starts (5.1)
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
-- Atmosphere profile (spec 5.2) of a zone; zone 0 and any zone without one use the LightingConfig baseline
function BiomeEnvironment.Profile(zone)
	local theme = Themes[biomeOf[zone]]
	return theme and theme.Atmosphere or baseline
end

function BiomeEnvironment.Audio(zone)
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
	return BiomeEnvironment.Row(biomeOf[zone], key, kind)
end

-- Sine ease, 0..1
function BiomeEnvironment.Ease(t)
	t = math.clamp(t, 0, 1)
	return (1 - math.cos(math.pi * t)) / 2
end

return BiomeEnvironment
