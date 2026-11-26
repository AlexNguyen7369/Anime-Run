--!nonstrict
-- BRIEF: World 2 track skies (owner 2026-11-25, design doc change log, owner question 33 "Four tracks"; owner 2026-11-26
-- choice F: uploaded, reviewed and checked in Studio before switched on; docs/WORLD2_SPEC.md "Track skies"). Hell's Gate,
-- Demon Castle, Golden City and Ant Island get in-house gradient skyboxes from their approved drafts' sky colours; the
-- other tracks keep the default sky. Checked here, through the same Shared/BiomeEnvironment.SkyboxFace and Profile the
-- client uses: each of the four rows holds its uploaded, reviewed ids; with the switch (TrackSkyConfig.LIVE) off, set for
-- the check, nothing changes; on, each track shows its own six faces in its zone only and the place's own sky comes back
-- on leaving; a row with any id 0 or unreviewed changes nothing (whole set or none); while its sky shows a track's fog
-- takes the sky's colours (and Ant Island its dusk light) with the road-and-runner floors kept; World 1 is unchanged.
-- Runs in either place and checks that place's rule. Offline: lune run tools/lune/server_scenarios <1|2> World2SkyTests.world2_skies
-- On demand in Studio: ReplicatedStorage attributes ServerTestOnly = "world2_skies", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Tests = {}

local FACES = { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }
-- the owner's four (question 33), track number -> biome key; literals from the spec, not read from the code
local SKY_TRACKS = { [10] = "HellGate", [2] = "DemonCastle", [9] = "GoldenCity", [7] = "AntIsland" }
-- uploaded 2026-11-26 under the owner's account (choice F), image ids { Side, Up, Dn }; signed by the rules auditor
local IDS = {
	HellGate = { "86680490565696", "90282386160927", "93152644275483" },
	GoldenCity = { "81386184856083", "110292604700791", "127822365813655" },
	AntIsland = { "80259567382435", "135567629453732", "72479367010394" },
	DemonCastle = { "130503656954140", "106416109766477", "74778906620679" },
}
local REVIEWED = "2026-11-26 rules-auditor"
local ZERO = "rbxassetid://0"
local SERVER_SKY = "rbxasset://textures/sky/sky512_" -- stands for the place's own Sky faces

local function wantFace(key, face)
	local ids = IDS[key]
	return "rbxassetid://" .. (face == "Up" and ids[2] or face == "Dn" and ids[3] or ids[1])
end

function Tests.world2_skies()
	local r, flag = H.report("world2_skies")
	local WorldConfig = require(Shared.WorldConfig)
	local Env = require(Shared.BiomeEnvironment)
	local Themes = require(Shared.BiomeThemes)
	local configModule = Shared:FindFirstChild("TrackSkyConfig")
	local Config = configModule and require(configModule)
	flag("switch_module", Config ~= nil and type(Config.LIVE) == "boolean")
	-- owner choice F: on once the four are uploaded and reviewed (the Studio check runs on this commit before merging)
	flag("switch_on", Config ~= nil and Config.LIVE == true, Config and tostring(Config.LIVE), "true")
	flag("skybox_face_api", type(Env.SkyboxFace) == "function")
	if not (Config and type(Env.SkyboxFace) == "function") then
		return r
	end
	local wasLive = Config.LIVE
	local restore = {}

	-- The six faces a zone shows, as the client writes them: the zone's id, or the place's own face
	local function shown(zone)
		local out = {}
		for _, face in FACES do
			out[face] = Env.SkyboxFace(zone, Env.Profile(zone), face) or (SERVER_SKY .. face)
		end
		return out
	end
	local function same(a, b)
		for _, face in FACES do
			if a[face] ~= b[face] then
				return false
			end
		end
		return true
	end
	local function allServer(faces)
		for _, face in FACES do
			if faces[face] ~= SERVER_SKY .. face then
				return false
			end
		end
		return true
	end
	local function isTrack(faces, key)
		for _, face in FACES do
			if faces[face] ~= wantFace(key, face) then
				return false
			end
		end
		return true
	end
	local function snapshot()
		local all = {}
		for zone = 0, 10 do
			all[zone] = shown(zone)
		end
		return all
	end

	local ok, err = xpcall(function()
		if WorldConfig.Id ~= 2 then
			-- World 1: no World 2 theme is loaded and the switch changes no zone's sky
			flag("world1_no_world2_themes", Themes.HellGate == nil and Themes.GoldenCity == nil)
			Config.LIVE = false
			local off = snapshot()
			Config.LIVE = true
			local on = snapshot()
			Config.LIVE = wasLive
			local changed = 0
			for zone = 0, 10 do
				changed += same(off[zone], on[zone]) and 0 or 1
			end
			flag("world1_switch_changes_nothing", changed == 0, changed, 0)
			-- the plaza's reviewed golden sky still shows (its six faces are its own, not the place's)
			flag("world1_plaza_sky_kept", not allServer(off[0]))
			return
		end

		-- World 2: the four profiles carry their key and their uploaded, reviewed ids; the other six none
		local rows = {}
		for n = 1, 10 do
			local key = SKY_TRACKS[n]
			local biome = Env.BiomeOf(n)
			local sky = Env.Profile(n).Sky or {}
			if key then
				flag(("track_%d_is_%s"):format(n, key), biome == key, biome, key)
				local want = "W2_" .. key .. "_Sky"
				flag(("track_%d_profile_skybox"):format(n), sky.Skybox == want, sky.Skybox, want)
				local theme = Themes[key]
				local row = theme and theme.Assets and theme.Assets[want]
				local ids = type(row) == "table"
					and row.Kind == "Skybox"
					and row.Id == wantFace(key, "Bk")
					and type(row.Faces) == "table"
				for _, face in FACES do
					ids = ids and row.Faces[face] == wantFace(key, face)
				end
				flag(("track_%d_row_uploaded_ids"):format(n), ids == true)
				flag(
					("track_%d_row_reviewed"):format(n),
					type(row) == "table" and row.Reviewed == REVIEWED,
					type(row) == "table" and row.Reviewed,
					REVIEWED
				)
				rows[n] = row
				if type(row) == "table" then
					restore[row] =
						{ Id = row.Id, Faces = row.Faces, Values = table.clone(row.Faces), Reviewed = row.Reviewed }
				end
			else
				flag(("track_%d_default_sky"):format(n), sky.Skybox == nil, sky.Skybox, "nil")
			end
		end

		-- Switch off (set for the check): every track shows the place's own sky and the theme's own profile
		Config.LIVE = false
		local off = snapshot()
		local bad, own = 0, 0
		for n = 1, 10 do
			bad += allServer(off[n]) and 0 or 1
		end
		for n, key in SKY_TRACKS do
			own += Env.Profile(n) == Themes[key].Atmosphere and 0 or 1
		end
		flag("off_every_track_default", bad == 0, bad, 0)
		flag("off_profile_is_theme_own", own == 0, own, 0)

		-- Switch on: each of the four shows its own six faces in its zone only; the plaza and the other six keep theirs
		Config.LIVE = true
		local on = snapshot()
		for n, key in SKY_TRACKS do
			flag(("live_%d_six_faces"):format(n), isTrack(on[n], key))
		end
		local others = 0
		for zone = 0, 10 do
			if not SKY_TRACKS[zone] then
				others += same(off[zone], on[zone]) and 0 or 1
			end
		end
		flag("live_other_zones_unchanged", others == 0, others, 0)
		-- leaving: a run 9 -> 10 -> 1 (the next lap), the faces as the client would write them each zone
		local seen = {}
		for i, zone in { 9, 10, 1 } do
			seen[i] = shown(zone)
		end
		flag(
			"restores_on_leaving",
			isTrack(seen[1], "GoldenCity") and isTrack(seen[2], "HellGate") and allServer(seen[3])
		)

		-- A row that is not whole or not signed shows nothing, switch on (whole set or none)
		local hell = rows[10]
		if hell then
			hell.Reviewed = nil
			flag("unreviewed_changes_nothing", allServer(shown(10)))
			hell.Reviewed = REVIEWED
			hell.Faces.Up = ZERO
			flag("half_set_changes_nothing", allServer(shown(10)))
			hell.Faces.Up = wantFace("HellGate", "Up")
			hell.Id = ZERO
			flag("id0_row_changes_nothing", allServer(shown(10)))
			hell.Id = wantFace("HellGate", "Bk")
		end
		-- every id 0 (as before the uploads): nothing changes anywhere, switch on
		for _, row in rows do
			row.Id = ZERO
			for _, face in FACES do
				row.Faces[face] = ZERO
			end
		end
		local zero = snapshot()
		local changed = 0
		for zone = 0, 10 do
			changed += same(off[zone], zero[zone]) and 0 or 1
		end
		flag("id0_changes_nothing", changed == 0, changed, 0)
		for row, was in restore do
			for face, id in was.Values do
				was.Faces[face] = id
			end
			row.Id = was.Id
		end

		-- With its sky shown, a track's fog takes the drawn sky's colours so no seam shows at the horizon, and Ant Island
		-- its dusk light (WORLD2_SPEC "Track skies", all proposed)
		local function near(c, hex, tol)
			local want = Color3.fromHex(hex)
			return typeof(c) == "Color3"
				and math.abs(c.R - want.R) <= tol
				and math.abs(c.G - want.G) <= tol
				and math.abs(c.B - want.B) <= tol
		end
		local function top(c)
			return typeof(c) == "Color3" and math.max(c.R, c.G, c.B) or 0
		end
		-- drawn by tools/blender/world2/track_sky.py: the sky at the horizon and 2 degrees up (Ramp.at_height(0), (0.035))
		local FOG = {
			[10] = { "FF8A4A", "F6743C" },
			[2] = { "F37428", "C04A28" },
			[9] = { "FFFE8A", "FFF076" },
			[7] = { "CE8D65", "A1786A" },
		}
		for n, key in SKY_TRACKS do
			local p, theme = Env.Profile(n), Themes[key].Atmosphere
			local a = p.Atmosphere or {}
			flag(
				("live_%d_fog_colour"):format(n),
				near(a.Color, FOG[n][1], 1.5 / 255),
				a.Color and a.Color:ToHex(),
				FOG[n][1]
			)
			flag(
				("live_%d_fog_decay"):format(n),
				near(a.Decay, FOG[n][2], 1.5 / 255),
				a.Decay and a.Decay:ToHex(),
				FOG[n][2]
			)
			flag(
				("live_%d_fog_density_kept"):format(n),
				a.Density == theme.Atmosphere.Density and a.Haze == theme.Atmosphere.Haze
			)
			flag(("live_%d_sky_key_kept"):format(n), p.Sky and p.Sky.Skybox == "W2_" .. key .. "_Sky")
			local l = p.Lighting or {}
			-- the road-and-runner floors (WORLD2_SPEC "Track lighting") still hold with the sky
			flag(
				("live_%d_floors"):format(n),
				l.Brightness >= 1.4 and top(l.Ambient) >= 0.36 and top(l.OutdoorAmbient) >= 0.6
			)
			if n ~= 7 then
				flag(("live_%d_light_unchanged"):format(n), p.Lighting == theme.Lighting and p.Grade == theme.Grade)
			end
		end
		local ant = Env.Profile(7)
		local l, g = ant.Lighting or {}, ant.Grade or {}
		flag("live_7_dusk_clock", l.ClockTime == 17.6, l.ClockTime, 17.6)
		flag("live_7_dusk_brightness", l.Brightness == 1.4, l.Brightness, 1.4)
		flag("live_7_dusk_exposure", l.ExposureCompensation == -0.3, l.ExposureCompensation, -0.3)
		flag(
			"live_7_dusk_outdoor",
			near(l.OutdoorAmbient, "A37D6D", 1.5 / 255),
			l.OutdoorAmbient and l.OutdoorAmbient:ToHex(),
			"A37D6D"
		)
		flag("live_7_dusk_saturation", g.Saturation == -0.1, g.Saturation, -0.1)
		flag("live_7_own_light_untouched", Themes.AntIsland.Atmosphere.Lighting.ClockTime ~= 17.6)
		-- one track's row not whole keeps its own profile
		if rows[2] then
			rows[2].Faces.Up = ZERO
			flag("id0_track_keeps_own_profile", Env.Profile(2) == Themes.DemonCastle.Atmosphere)
		end
	end, debug.traceback)
	flag("completed", ok, ok and 1 or tostring(err))

	for row, was in restore do
		for face, id in was.Values do
			was.Faces[face] = id
		end
		row.Id, row.Faces, row.Reviewed = was.Id, was.Faces, was.Reviewed
	end
	Config.LIVE = wasLive
	flag("switch_restored", Config.LIVE == wasLive)
	return r
end

return Tests
