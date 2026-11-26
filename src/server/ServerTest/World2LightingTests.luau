--!nonstrict
-- BRIEF: docs/WORLD2_SPEC.md "Track lighting", brighter tracks (owner 2026-11-26: "adjust sky lighting so not too dim ...
-- Like solo leveling ant track, too dim cant see much/dark"). Every World 2 track's lighting profile (and its with-sky look)
-- meets the raised floors: Brightness, Ambient and OutdoorAmbient (largest channel) and their luminance; night tracks' exposure;
-- Track 7 under its sky gets its brighter dusk look. Only brightness: the draft's sky, fog colours and ClockTime stay.
-- Literals from the spec, not read from Kit. Offline: lune run tools/lune/server_scenarios 2 World2LightingTests.world2_lighting
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Tests = {}

local W2 = {
	"ElvenPlains",
	"DemonCastle",
	"RuinedCityZ",
	"HauntedTunnel",
	"KaijuBase",
	"DevilTokyo",
	"AntIsland",
	"MonsterDen",
	"GoldenCity",
	"HellGate",
}
local NIGHT = { HauntedTunnel = true, DevilTokyo = true, MonsterDen = true }
local FLOOR = {
	Day = { Brightness = 1.7, Ambient = 0.42, OutdoorAmbient = 0.66, AmbLum = 0.28, OutLum = 0.46 },
	Night = { Brightness = 2.2, Ambient = 0.56, OutdoorAmbient = 0.68, AmbLum = 0.36, OutLum = 0.5, Exposure = 1.25 },
}
local EPS = 1e-3

local function top(c)
	return math.max(c.R, c.G, c.B)
end
local function lum(c)
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

function Tests.world2_lighting()
	local r, flag = H.report("world2_lighting")
	if require(Shared.WorldConfig).Id ~= 2 then
		flag("world2_only", true)
		return r
	end
	local Themes = require(Shared.BiomeThemes)
	for _, key in W2 do
		local theme = Themes[key]
		local p = theme and theme.Atmosphere
		if not (p and p.Lighting) then
			flag(key .. "_profile", false)
			continue
		end
		local f = NIGHT[key] and FLOOR.Night or FLOOR.Day
		-- the profile and, where the track's own sky can show, the look under it
		local looks = { { "", p.Lighting } }
		if p.WithSky and p.WithSky.Lighting then
			local merged = table.clone(p.Lighting)
			for k, v in p.WithSky.Lighting do
				merged[k] = v
			end
			table.insert(looks, { "_sky", merged })
		end
		for _, look in looks do
			local tag, L = key .. look[1], look[2]
			flag(tag .. "_brightness", L.Brightness >= f.Brightness - EPS, L.Brightness, f.Brightness)
			flag(tag .. "_ambient", top(L.Ambient) >= f.Ambient - EPS, math.floor(top(L.Ambient) * 1000) / 1000, f.Ambient)
			flag(tag .. "_ambient_lum", lum(L.Ambient) >= f.AmbLum - EPS, math.floor(lum(L.Ambient) * 1000) / 1000, f.AmbLum)
			flag(
				tag .. "_outdoor",
				top(L.OutdoorAmbient) >= f.OutdoorAmbient - EPS,
				math.floor(top(L.OutdoorAmbient) * 1000) / 1000,
				f.OutdoorAmbient
			)
			flag(
				tag .. "_outdoor_lum",
				lum(L.OutdoorAmbient) >= f.OutLum - EPS,
				math.floor(lum(L.OutdoorAmbient) * 1000) / 1000,
				f.OutLum
			)
			if f.Exposure then
				flag(tag .. "_exposure", math.abs(L.ExposureCompensation - f.Exposure) < EPS, L.ExposureCompensation, f.Exposure)
			end
		end
	end
	-- Track 7's dusk under its sky: brighter, the dusk clock kept
	local ant = Themes.AntIsland and Themes.AntIsland.Atmosphere
	local sky = ant and ant.WithSky and ant.WithSky.Lighting or {}
	flag("ant_sky_brightness_2_1", sky.Brightness == 2.1, sky.Brightness, 2.1)
	flag("ant_sky_exposure_0_2", sky.ExposureCompensation == 0.2, sky.ExposureCompensation, 0.2)
	flag("ant_sky_dusk_clock_kept", sky.ClockTime == 17.6, sky.ClockTime, 17.6)
	return r
end

return Tests
