--!nonstrict
-- BRIEF: design doc 4.25 "Build after join" (owner 2026-11-10), with 4.15 (Sensei checkpoints) and 4.18. Written by
-- test-writer before the code; never loosen a check to make it pass.
-- Rule: players can join once Tracks 1-5 are built; Tracks 6-10 then build one per frame, nearest the players first
-- (a track a player is on or headed to jumps the queue). A run that would start on, or a runner who would cross into, a
-- track not built yet holds at the spawn gate or that finish line until it is built; nothing is paid or lost meanwhile.
-- Contract (implementer: report a change, do not loosen):
--   Workspace.Track.<name> (attribute Number) gets attribute BuiltAt = os.clock() once that track is fully built
--     (parented, pruned, terrain-prepared, snapped). Presence of BuiltAt is the server-side "built" signal.
--   ReplicatedStorage attribute TerrainNearReadyAt = os.clock() when TerrainNearReady is first set true.
--   Server module TrackBuild (ServerScriptService.Server.TrackBuild):
--     IsBuilt(number) -> boolean: the track is built (or a test override says so).
--     SetBuiltOverride(number, value): test seam; false forces unbuilt, true forces built, nil clears (real state).
--     Order(remaining, playerTracks) -> new list, pure, inputs untouched. remaining: unbuilt track numbers;
--       playerTracks: the track each player is on or a held run waits on. Tracks a player is on (p) or headed to (p + 1)
--       come first, ascending; the rest follow by min |n - p| over players, ties lower number first; no players:
--       ascending. Test-side reading of "nearest": tracks spiral outward in Number order (TrackChainTests).
--   RaceService NPC runs poll TrackBuild.IsBuilt: while holding, run.Holding = the awaited track number (nil otherwise),
--     car attribute RunHold = that number (the client's "Loading next track" label; nil otherwise), car RunSpeed = 0,
--     the rail does not move, stamina does not drain, nothing banks; on release the held track's race starts.
--   RaceService.GetRoute().Tracks: all 10 tracks, each Pad the WinPad of its built Track model (a late track still pays).
-- On demand: ReplicatedStorage attributes CarTestOnly = "track_loading", then CarTestRun = true.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990136000
local JOIN_TRACKS, TRACK_COUNT = 5, 10
local BUILD_TIMEOUT = 60 -- s for Tracks 6-10 to finish behind the game
local HOLD_SECONDS = 0.3 -- s a hold is watched for
local RELEASE_SECONDS = 2 -- s a released hold has to start the held race
local STILL = 0.01 -- studs / stamina percent: "did not move"
local SLOW_NPC = 0.001

local function same(a, b)
	if #a ~= #b then
		return false
	end
	for i, v in a do
		if b[i] ~= v then
			return false
		end
	end
	return true
end

local function until_(seconds, fn)
	local deadline = os.clock() + seconds
	while not fn() and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	return fn()
end

-- Pure: the build queue (design doc 4.25 "nearest the players first", "jumps the queue").
local function orderChecks(flag, TrackBuild)
	if type(TrackBuild.Order) ~= "function" then
		flag("order_function_present", false)
		return
	end
	local rest = { 6, 7, 8, 9, 10 }
	local copy = table.clone(rest)
	flag("order_no_players_ascending", same(TrackBuild.Order(rest, {}), { 6, 7, 8, 9, 10 }))
	flag("order_inputs_untouched", same(rest, copy))
	flag("order_plaza_players_ascending", same(TrackBuild.Order(rest, { 1, 2 }), { 6, 7, 8, 9, 10 }))
	flag("order_headed_to_next_first", TrackBuild.Order(rest, { 5 })[1] == 6)
	-- a Sensei checkpoint run waiting on Track 8 (design doc 4.15): 8 and the 9 it heads to jump the queue
	flag("order_held_on_8", same(TrackBuild.Order(rest, { 8 }), { 8, 9, 7, 6, 10 }))
	flag("order_two_players", same(TrackBuild.Order(rest, { 6, 9 }), { 6, 7, 9, 10, 8 }))
	flag("order_mixed_with_plaza", same(TrackBuild.Order({ 7, 8, 9, 10 }, { 2, 8 }), { 8, 9, 7, 10 }))
	flag("order_only_remaining", same(TrackBuild.Order({ 7, 10 }, { 8 }), { 7, 10 }))
	flag("order_empty", #TrackBuild.Order({}, { 3 }) == 0)
end

-- Live: every track built, 1-5 before the join signal, 6-10 after 1-5, the route complete.
local function liveChecks(flag, r, TrackBuild)
	local folder = Workspace:FindFirstChild("Track")
	local function byNumber()
		local found = {}
		for _, model in folder and folder:GetChildren() or {} do
			local number = model:GetAttribute("Number")
			if type(number) == "number" then
				found[number] = model
			end
		end
		return found
	end
	local function builtAt(number)
		local model = byNumber()[number]
		return model and model:GetAttribute("BuiltAt")
	end
	local allBuilt = until_(BUILD_TIMEOUT, function()
		for n = 1, TRACK_COUNT do
			if type(builtAt(n)) ~= "number" then
				return false
			end
		end
		return true
	end)
	flag("live_all_tracks_built", allBuilt)
	for n = 1, TRACK_COUNT do
		flag("live_track_" .. n .. "_built_at", type(builtAt(n)) == "number")
		flag("live_is_built_" .. n, type(TrackBuild.IsBuilt) == "function" and TrackBuild.IsBuilt(n) == true)
	end

	local nearAt = ReplicatedStorage:GetAttribute("TerrainNearReadyAt")
	flag("live_near_ready_at_present", type(nearAt) == "number")
	local lastJoin = -math.huge
	for n = 1, JOIN_TRACKS do
		local at = builtAt(n)
		local ok = type(at) == "number" and type(nearAt) == "number" and at <= nearAt
		flag("live_track_" .. n .. "_before_join", ok, type(at) == "number" and at or -1, nearAt or -1)
		lastJoin = math.max(lastJoin, type(at) == "number" and at or math.huge)
	end
	for n = JOIN_TRACKS + 1, TRACK_COUNT do
		local at = builtAt(n)
		flag("live_track_" .. n .. "_after_join_tracks", type(at) == "number" and at >= lastJoin)
	end

	local RaceService = require(Server.RaceService)
	local route = RaceService.GetRoute()
	local tracks = route and route.Tracks or {}
	flag("live_route_all_tracks", #tracks == TRACK_COUNT, #tracks, TRACK_COUNT)
	local models = byNumber()
	for _, track in tracks do
		local model = models[track.Number]
		flag(
			"live_route_pad_" .. tostring(track.Number),
			model ~= nil and typeof(track.Pad) == "Instance" and track.Pad:IsDescendantOf(model)
		)
	end
	r.metrics.near_ready_at = nearAt
end

-- Runtime: the hold at a finish line and at the spawn gate, on a synthetic 4-track route (like GemTests).
local function holdChecks(flag, TrackBuild, cleanup, runs)
	if type(TrackBuild.SetBuiltOverride) ~= "function" then
		flag("hold_override_present", false)
		return
	end
	local RaceService, gacha = require(Server.RaceService), require(Server.GachaService)
	local factory, catalog = require(Shared.RunnerFactory), require(Shared.CharacterCatalog)
	local npc, npcConfig = require(Shared.NpcRacer), require(Shared.NpcConfig)

	local module = Server.PlayerData:Clone() -- never redirect the live player's autosaves
	module.Name, module.Parent = "CarTestTrackLoadData", Server
	table.insert(cleanup, module)
	local data = require(module)
	data.SetStore(H.store())
	local nextId = UID
	local function newPlayer()
		nextId += 1
		local p = H.player(cleanup, nextId)
		data.Setup(p)
		gacha.Setup(p)
		return p
	end

	local pad = Instance.new("Part")
	pad:SetAttribute("Cash", 10)
	CollectionService:AddTag(pad, "WinPad")
	table.insert(cleanup, pad)
	local points = {}
	for i = 0, 8 do
		table.insert(points, Vector3.new(0, 2000, -i * 20))
	end
	local route = {
		Path = { WorldWaypoints = points, Curvature = table.create(9, 0), Width = 40, Closed = false },
		Pads = {},
		Tracks = {},
	}
	for number = 1, 4 do
		local start = (number - 1) * 2 + 1
		local path = {
			Waypoints = { points[start], points[start + 1], points[start + 2] },
			Curvature = { 0, 0, 0 },
			Length = 40,
		}
		table.insert(route.Tracks, {
			Number = number,
			StartIndex = start,
			FinishIndex = start + 2,
			PadIndex = start + 2,
			Pad = pad,
			Npc = { Config = npcConfig.For(number), Path = path, Profile = npc.Profile(path, 1) },
		})
	end

	local function startRun(options)
		local p = newPlayer()
		local car = factory.build(catalog.All()[1].Id)
		car.Name, car.Parent = "CarTestTrackLoadRunner", p
		local events = {}
		options.Npc = true
		options.NpcSpeeds = { [1] = SLOW_NPC, [2] = SLOW_NPC, [3] = SLOW_NPC, [4] = SLOW_NPC }
		options.StaminaSeconds = { 30, 30, 30 }
		options.OnRaceEvent = function(event)
			table.insert(events, event)
		end
		local run = RaceService.NewRun(car, route, p, options)
		table.insert(runs, run)
		return run, car, p, events
	end
	local function started(events, number)
		for _, e in events do
			if e.Type == "Start" and e.Track == number then
				return true
			end
		end
		return false
	end
	-- Watches a hold for HOLD_SECONDS: rail, stamina, bank, Gems and results all still.
	local function watchHold(prefix, run, car, p, number)
		local d0, s0 = car:GetAttribute("RunDistance"), run.Stamina[run.Slot]
		local bank0, gems0, results0 = run.BankedTotal, p:GetAttribute("Gems"), #run.Results
		task.wait(HOLD_SECONDS)
		local held = run.Holding == number
		flag(prefix .. "_holding", held, run.Holding or 0, number)
		flag(prefix .. "_label_attr", car:GetAttribute("RunHold") == number)
		flag(prefix .. "_speed_zero", car:GetAttribute("RunSpeed") == 0, car:GetAttribute("RunSpeed") or -1, 0)
		local d1 = car:GetAttribute("RunDistance")
		flag(prefix .. "_rail_still", type(d0) == "number" and type(d1) == "number" and math.abs(d1 - d0) <= STILL)
		flag(prefix .. "_stamina_kept", math.abs((run.Stamina[run.Slot] or 0) - (s0 or -1)) <= STILL)
		flag(prefix .. "_nothing_banked", run.BankedTotal == bank0, run.BankedTotal - bank0, 0)
		flag(prefix .. "_no_gems", p:GetAttribute("Gems") == gems0)
		flag(prefix .. "_no_result", #run.Results == results0, #run.Results, results0)
		return d1
	end

	-- 1. Finish line: Track 1 won, Track 2 unbuilt. Track 1's win banks; the runner then waits at its finish.
	TrackBuild.SetBuiltOverride(2, false)
	local run, car, p, events = startRun({ StartTrack = 1 })
	run.Driver.Index = route.Tracks[1].FinishIndex
	until_(1, function()
		return #run.Results >= 1
	end)
	local first = run.Results[1]
	flag("finish_track1_won", first ~= nil and first.Track == 1 and first.Result == "Win")
	flag("finish_track1_banked", run.BankedTotal > 0, run.BankedTotal)
	flag("finish_no_track2_race", not started(events, 2) and run.RaceTrack ~= 2)
	local at = watchHold("finish", run, car, p, 2)
	local finishArc = (route.Tracks[1].FinishIndex - 1) * 20
	local slack = math.max(10, run.TargetSpeed * 0.1) -- one frame of cruise past the line
	flag("finish_at_line", type(at) == "number" and math.abs(at - finishArc) <= slack, at or -1, finishArc)
	TrackBuild.SetBuiltOverride(2, nil)
	local released = until_(RELEASE_SECONDS, function()
		return started(events, 2)
	end)
	flag("finish_release_starts_track2", released)
	flag("finish_release_clears_hold", run.Holding == nil and car:GetAttribute("RunHold") == nil)
	local moved = until_(RELEASE_SECONDS, function()
		return (car:GetAttribute("RunDistance") or 0) > (at or math.huge) + STILL
	end)
	flag("finish_release_moves", moved)
	run.Driver.Index = route.Tracks[2].FinishIndex
	until_(1, function()
		return #run.Results >= 2
	end)
	flag("finish_track2_pays_after_release", run.Results[2] ~= nil and run.Results[2].Track == 2)
	run:Destroy()

	-- 2. Spawn gate: a Sensei checkpoint run (design doc 4.15) starting on unbuilt Track 3 holds at its gate.
	TrackBuild.SetBuiltOverride(3, false)
	run, car, p, events = startRun({ StartTrack = 3 })
	RunService.Heartbeat:Wait()
	flag("gate_no_race_yet", not started(events, 3))
	at = watchHold("gate", run, car, p, 3)
	local gateArc = (route.Tracks[3].StartIndex - 1) * 20 + RaceService.START_AHEAD
	flag("gate_at_start", type(at) == "number" and math.abs(at - gateArc) <= STILL + 1, at or -1, gateArc)
	TrackBuild.SetBuiltOverride(3, nil)
	flag(
		"gate_release_starts_track3",
		until_(RELEASE_SECONDS, function()
			return started(events, 3)
		end)
	)
	flag("gate_release_clears_hold", run.Holding == nil and car:GetAttribute("RunHold") == nil)
	run:Destroy()

	-- 3. A built track never holds.
	run, car, p, events = startRun({ StartTrack = 1 })
	RunService.Heartbeat:Wait()
	flag("built_no_hold", run.Holding == nil and started(events, 1))
	run:Destroy()
end

function Tests.track_loading()
	local r, flag = H.report("track_loading")
	local TrackBuild = H.module(Server, "TrackBuild")
	flag("track_build_module_present", TrackBuild ~= nil)
	if not TrackBuild then
		return r
	end
	orderChecks(flag, TrackBuild)
	local cleanup, runs = {}, {}
	local ok, err = xpcall(function()
		liveChecks(flag, r, TrackBuild)
		holdChecks(flag, TrackBuild, cleanup, runs)
	end, debug.traceback)
	if type(TrackBuild.SetBuiltOverride) == "function" then
		for n = 1, 4 do
			TrackBuild.SetBuiltOverride(n, nil)
		end
	end
	for _, run in runs do
		pcall(run.Destroy, run)
	end
	for i = #cleanup, 1, -1 do
		cleanup[i]:Destroy()
	end
	if not ok then
		flag("no_error", false)
		r.error = tostring(err)
	end
	return r
end

return Tests
