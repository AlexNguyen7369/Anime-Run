--!nonstrict
-- BRIEF: World 2 track skies (owner 2026-11-25, design doc change log, owner question 33 "Four tracks"; docs/WORLD2_SPEC.md
-- "Track skies"). Hell's Gate, Demon Castle, Golden City and Ant Island get in-house gradient skyboxes from their approved
-- drafts' sky colours; the other tracks keep the default sky. Until the images are uploaded and reviewed the ledger rows
-- hold rbxassetid://0 and the switch TrackSkyConfig.LIVE is off: nothing changes in game. Checked here, through the same
-- Shared/BiomeEnvironment.SkyboxFace the client applies: a profile whose row has id 0 changes nothing (switch on or off,
-- reviewed or not); with a made-up id, the switch on and the row reviewed it sets the six faces in that zone only and the
-- place's own sky comes back on leaving; a half-uploaded set shows nothing; World 1 is unchanged by the switch.
-- Runs in either place and checks that place's rule. Offline: lune run tools/lune/server_scenarios <1|2> World2SkyTests.world2_skies
-- On demand in Studio: ReplicatedStorage attributes ServerTestOnly = "world2_skies", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Tests = {}

local FACES = { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }
-- the owner's four (question 33), track number -> biome key; literals from the spec, not read from the code
local SKY_TRACKS = { [10] = "HellGate", [2] = "DemonCastle", [9] = "GoldenCity", [7] = "AntIsland" }
local ZERO = "rbxassetid://0"
-- made-up ids for the test only: one per image (the four sides share one, as the plaza's SkyGolden)
local FAKE = { Side = "rbxassetid://990250000001", Up = "rbxassetid://990250000002", Dn = "rbxassetid://990250000003" }
local SERVER_SKY = "rbxasset://textures/sky/sky512_" -- stands for the place's own Sky faces

local function fakeFace(face)
	return face == "Up" and FAKE.Up or face == "Dn" and FAKE.Dn or FAKE.Side
end

function Tests.world2_skies()
	local r, flag = H.report("world2_skies")
	local WorldConfig = require(Shared.WorldConfig)
	local Env = require(Shared.BiomeEnvironment)
	local Themes = require(Shared.BiomeThemes)
	local configModule = Shared:FindFirstChild("TrackSkyConfig")
	local Config = configModule and require(configModule)
	flag("switch_module", Config ~= nil and type(Config.LIVE) == "boolean")
	flag("switch_off", Config ~= nil and Config.LIVE == false, Config and tostring(Config.LIVE), "false")
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

		-- World 2: the four profiles carry their key; the other six none
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
				local zeros = type(row) == "table"
					and row.Kind == "Skybox"
					and row.Id == ZERO
					and type(row.Faces) == "table"
				for _, face in FACES do
					zeros = zeros and row.Faces[face] == ZERO
				end
				flag(("track_%d_row_id_0"):format(n), zeros == true)
				flag(("track_%d_row_not_reviewed"):format(n), type(row) == "table" and row.Reviewed == nil)
				rows[n] = row
			else
				flag(("track_%d_default_sky"):format(n), sky.Skybox == nil, sky.Skybox, "nil")
			end
		end

		-- Switch off: every zone shows the place's own sky (the plaza keeps its own look)
		Config.LIVE = false
		local before = snapshot()
		local bad = 0
		for n = 1, 10 do
			bad += allServer(before[n]) and 0 or 1
		end
		flag("off_every_track_default", bad == 0, bad, 0)

		-- Id 0 changes nothing even with the switch on and the row signed
		Config.LIVE = true
		for _, row in rows do
			restore[row] = { Id = row.Id, Faces = row.Faces, Values = table.clone(row.Faces), Reviewed = row.Reviewed }
			row.Reviewed = "2026-11-25 test"
		end
		local zero = snapshot()
		local changed = 0
		for zone = 0, 10 do
			changed += same(before[zone], zero[zone]) and 0 or 1
		end
		flag("id0_changes_nothing", changed == 0, changed, 0)

		-- Track 10 with made-up ids, the other three still 0
		local hell = rows[10]
		if hell then
			hell.Id = FAKE.Side
			for _, face in FACES do
				hell.Faces[face] = fakeFace(face)
			end
			-- not reviewed: nothing
			hell.Reviewed = nil
			flag("unreviewed_changes_nothing", allServer(shown(10)))
			hell.Reviewed = "2026-11-25 test"
			-- switch off: nothing
			Config.LIVE = false
			flag("switch_off_changes_nothing", allServer(shown(10)))
			Config.LIVE = true
			-- on, reviewed, real-looking ids: the six faces in zone 10
			local in10 = shown(10)
			local set = true
			for _, face in FACES do
				set = set and in10[face] == fakeFace(face)
			end
			flag("made_up_id_sets_six_faces", set)
			-- that zone only
			local others = 0
			for zone = 0, 9 do
				others += same(before[zone], shown(zone)) and 0 or 1
			end
			flag("made_up_id_that_zone_only", others == 0, others, 0)
			-- leaving: a run 9 -> 10 -> 1 (the next lap), the faces as the client would write them each zone
			local seen = {}
			for i, zone in { 9, 10, 1 } do
				seen[i] = shown(zone)
			end
			local back = same(seen[1], before[9]) and same(seen[2], in10) and same(seen[3], before[1])
			flag("restores_on_leaving", back and allServer(seen[3]))
			-- a set with one face still 0 shows nothing (whole set or none)
			hell.Faces.Up = ZERO
			flag("half_set_changes_nothing", allServer(shown(10)))
			hell.Faces.Up = FAKE.Up
			-- and the id 0 in the row's Id alone (faces real) shows nothing either
			hell.Id = ZERO
			flag("id0_row_changes_nothing", allServer(shown(10)))
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
