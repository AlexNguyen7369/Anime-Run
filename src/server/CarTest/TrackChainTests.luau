--!nonstrict
-- BRIEF: docs/TRACKS_AND_BIOMES_SPEC.md "Lengths" and "Build order and tests" step 1, docs/WORLD_REDESIGN_SPEC.md
-- section 3 (owner 2026-10-28 / 2026-10-30), design doc sections 3 and 4.9. Written by test-writer BEFORE the
-- Track 1-10 layouts; never loosen a limit to make a track pass.
-- Per track (called from Scenarios.track for every TrackTests/<Track>.luau):
--   * target length 984 x F x 1.25^(n-1) studs, F = 3, within +-5 %, measured along the centre line (layout.Length);
--   * TrackValidator rejects an off-target track (its new TARGET_LENGTH check), probed with a plain L-shaped spec;
--   * no overlap with any other chained track (centre line and race path, the IVS chain rule), the plaza (live
--     Workspace.SpawnArea) or the Dojo plots (live Workspace.Workshops);
--   * driven by the real RaceService on the live route from this track's start to its finish at normal (HALF_STAT)
--     and max (MAX_STAT) stat speed: 0 flips (upright, up Y >= 0.999), 0 off-track (feet within
--     PhysicsTargets.race.MaxPathDeviation of the route), this track's pad paid exactly once.
-- Chain (called from Scenarios.chain): Tracks 1-10 numbered 1..10, built from TrackBuilder.CHAIN_ORIGIN (owner
--   2026-10-30), spiralling outward: each track's mean distance from the plaza centre (the world origin, spec 3)
--   is larger than the previous track's, so Track 1 is nearest. Test-side reading of "farther from the plaza centre".
-- Every pairwise search is grid-bucketed and yields between chunks: long tracks have thousands of waypoints / parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local M = {}

M.BASE, M.FACTOR, M.GROWTH, M.TOLERANCE = 984, 3, 1.25, 0.05 -- spec "Lengths" (F = 3, owner 2026-10-30)
M.TRACK_COUNT = 10 -- Tracks 1-10 (spec "Lengths" table, ORCHESTRATOR_GOALS w3)
local CLEAR_PAD = 8 -- chain no-overlap: wider road + 8 studs (the IVS chain rule in Scenarios.chain)
local JOINT = 60 -- studs around the joint two neighbouring tracks share, skipped (as in Scenarios.chain)
local OVERLAP_TOL = 0.05 -- as spawn_area / world_layout
local MIN_UP_Y = 0.999 -- WORLD_REDESIGN_SPEC section 7: upright, up-vector Y >= 0.999
local GRACE_STUDS = 30 -- RaceService DEVIATION_GRACE_STUDS: deviation counts once the rig has run this far
local WINDOW_SLACK = 36 -- studs of path searched past the reach of one frame (RunnerTests)
local MIN_SAMPLES = 5
local YIELD_EVERY = 20000 -- comparisons between task.wait() calls

function M.target(n)
	return M.BASE * M.FACTOR * M.GROWTH ^ (n - 1)
end

local budget = 0
local function tick(cost)
	budget += cost or 1
	if budget >= YIELD_EVERY then
		budget = 0
		task.wait()
	end
end

-- Every chained track laid out in world space from TrackBuilder.CHAIN_ORIGIN, as Main.server builds it.
-- Returns tracks { Number, Layout, Points (centre), Race (race path), End }, racePathsOk.
function M.world(TrackBuilder, specs)
	local tracks = {}
	local origin = TrackBuilder.CHAIN_ORIGIN or CFrame.new(0, TrackBuilder.TRACK_LIFT or 0, 0)
	local racePathsOk = type(TrackBuilder.RacePath) == "function"
	for i, spec in specs do
		local layout = TrackBuilder.Layout(spec)
		local world = table.create(#layout.Waypoints)
		for j, p in layout.Waypoints do
			world[j] = origin:PointToWorldSpace(p)
		end
		local raceWorld = {}
		if racePathsOk then
			local okRP, rp = pcall(TrackBuilder.RacePath, layout)
			if okRP and type(rp) == "table" and type(rp.Waypoints) == "table" and #rp.Waypoints >= 2 then
				for j, p in rp.Waypoints do
					raceWorld[j] = origin:PointToWorldSpace(p)
				end
			else
				racePathsOk = false
			end
		end
		tracks[i] = {
			Number = spec.Number,
			Layout = layout,
			Points = world,
			Race = raceWorld,
			End = origin:PointToWorldSpace(layout.EndPosition),
		}
		origin = TrackBuilder.EndCFrame(layout, origin)
		tick(#world)
	end
	return tracks, racePathsOk
end

-- Chain no-overlap: centre AND race-path waypoints of different tracks stay the wider road width + 8 apart, except
-- within JOINT studs of the joint neighbouring tracks share. Same rule as the old all-pairs loop, bucketed in an XZ
-- grid (cell = the largest clearance) so only nearby points are compared. only (optional): just pairs with track
-- index `only`. Returns ok, nearest distance found (nil if no pair came within one cell), worst pair "a-b".
function M.overlap(tracks, only)
	local cell = 1
	for _, t in tracks do
		cell = math.max(cell, t.Layout.Width + CLEAR_PAD)
	end
	local function key(x, z)
		return math.floor(x / cell) * 65536 + math.floor(z / cell)
	end
	local grid = {}
	local pts = {}
	for i, t in tracks do
		local list = table.clone(t.Points)
		table.move(t.Race, 1, #t.Race, #list + 1, list)
		pts[i] = list
		for _, p in list do
			local k = key(p.X, p.Z)
			local bucket = grid[k]
			if not bucket then
				bucket = {}
				grid[k] = bucket
			end
			table.insert(bucket, { i, p })
		end
		tick(#list)
	end
	local ok, nearest, worst = true, nil, nil
	for i, list in pts do
		if only == nil or i == only then
			for _, p in list do
				local cx, cz = math.floor(p.X / cell), math.floor(p.Z / cell)
				for dx = -1, 1 do
					for dz = -1, 1 do
						for _, e in grid[(cx + dx) * 65536 + cz + dz] or {} do
							local j, q = e[1], e[2]
							if (only == nil and j > i) or (only ~= nil and j ~= i) then
								local joint = math.abs(i - j) == 1 and tracks[math.min(i, j)].End or nil
								if not joint or ((p - joint).Magnitude > JOINT and (q - joint).Magnitude > JOINT) then
									local d = (p - q).Magnitude
									if nearest == nil or d < nearest then
										nearest = d
										worst = ("%s-%s"):format(tostring(tracks[i].Number), tostring(tracks[j].Number))
									end
									if d < math.max(tracks[i].Layout.Width, tracks[j].Layout.Width) + CLEAR_PAD then
										ok = false
									end
								end
							end
						end
						tick(1)
					end
				end
			end
		end
	end
	return ok, nearest, worst
end

-- Mean XZ distance of a track's centre waypoints from the plaza centre (world origin, WORLD_REDESIGN_SPEC 3)
function M.meanRadius(t)
	local sum = 0
	for _, p in t.Points do
		sum += Vector2.new(p.X, p.Z).Magnitude
	end
	return #t.Points > 0 and sum / #t.Points or 0
end

-- Chain additions (Scenarios.chain): ten numbered tracks and the outward spiral.
function M.chain(check, tracks)
	local numbered = #tracks == M.TRACK_COUNT
	for i, t in tracks do
		numbered = numbered and t.Number == i
	end
	check("chain_tracks_1_to_10", #tracks, M.TRACK_COUNT, numbered)
	local worstStep, outward, radii = math.huge, #tracks >= 2, {}
	for i, t in tracks do
		radii[i] = M.meanRadius(t)
		if i > 1 then
			worstStep = math.min(worstStep, radii[i] - radii[i - 1])
			outward = outward and radii[i] > radii[i - 1]
		end
	end
	check("chain_spiral_outward", worstStep == math.huge and -1 or worstStep, 0, outward)
	local nearestIsOne = #radii >= 1
	for i = 2, #radii do
		nearestIsOne = nearestIsOne and radii[1] < radii[i]
	end
	check("chain_track1_nearest_plaza", radii[1] or -1, 0, nearestIsOne)
	local shown = {}
	for i, r in radii do
		shown[i] = math.round(r)
	end
	return table.concat(shown, ",")
end

-- The validator's TARGET_LENGTH check, probed with a plain L-shaped track of total length `total`: straight, a
-- 90 degree left turn of radius 120, straight. Nothing else about it is invalid.
local function probeSpec(n, total)
	local turn = math.pi / 2 * 120
	local a = (total - turn) / 2
	return {
		Name = "CarTestTargetLengthProbe",
		Number = n,
		Width = 40,
		Closed = false,
		Segments = {
			{ Type = "Straight", Length = a },
			{ Type = "Turn", Angle = 90, Radius = 120 },
			{ Type = "Straight", Length = total - turn - a },
		},
	}
end

-- Live parts of a track model (its Ground and invisible Start marker are not road, as in spawn_area) against every
-- part under `roots`; broad phase on bounding circles. Returns hits, worst separation, worst pair name.
local function liveOverlap(model, roots, partPoly, separation)
	local others = {}
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(others, { Part = d, R = d.Size.Magnitude / 2, Poly = partPoly(d) })
			end
		end
	end
	local hits, worst, worstName = 0, math.huge, nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Ground" and d.Name ~= "Start" then
			local r, poly = d.Size.Magnitude / 2, nil
			for _, o in others do
				local gap = Vector2.new(d.Position.X - o.Part.Position.X, d.Position.Z - o.Part.Position.Z).Magnitude
				if gap <= r + o.R + 1 then
					poly = poly or partPoly(d)
					local sep = separation(poly, o.Poly)
					if sep < worst then
						worst, worstName = sep, d:GetFullName() .. "/" .. o.Part:GetFullName()
					end
					if sep < -OVERLAP_TOL then
						hits += 1
					end
				end
				tick(1)
			end
		end
	end
	return hits, worst, worstName
end

-- Distance from p to the polyline pts over segments lo..hi: distance, segment index (RunnerTests.nearest)
local function nearest(pts, p, lo, hi)
	local bestD, bestI = math.huge, lo
	for i = math.max(lo, 1), math.min(hi, #pts - 1) do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local len2 = ab:Dot(ab)
		if len2 > 1e-6 then
			local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
			local d = (p - (a + ab * t)).Magnitude
			if d < bestD then
				bestD, bestI = d, i
			end
		end
	end
	return bestD, bestI
end

-- Drives the runner rig with the real RaceService along the live route, from track `number`'s start
-- (run:JumpToTrack) to its finish, at `stat`. Measures uprightness and path deviation independently of the run.
local function driveTrack(svc, route, entry, stat)
	local st = { ok = false, minUp = 1, dev = 0, n = 0 }
	local wps = route.Path.WorldWaypoints
	local n = #wps
	local arc = { 0 }
	for i = 2, n do
		arc[i] = arc[i - 1] + (wps[i] - wps[i - 1]).Magnitude
	end
	local character = svc.Catalog.All()[1]
	local okBuild, model = pcall(svc.RunnerFactory.build, character and character.Id)
	if not okBuild or typeof(model) ~= "Instance" then
		st.err = "runner build: " .. tostring(model)
		return st
	end
	model.Name = "CarTestTrackRunner"
	model.Parent = Workspace
	local player = Instance.new("Folder")
	player.Name = "CarTestTrackRunnerPlayer"
	player.Parent = Workspace
	local okRun, run = pcall(function()
		svc.Money.Setup(player)
		svc.PlayerData.Setup(player)
		player.BaseSpeed.Value = stat
		return svc.RaceService.NewRun(model, route, player, nil)
	end)
	local jumped = okRun and type(run) == "table" and run:JumpToTrack(entry.Number) == true
	if not jumped then
		st.err = tostring(run)
		if okRun and type(run) == "table" then
			pcall(run.Destroy, run)
		end
		model:Destroy()
		player:Destroy()
		return st
	end
	st.ok = true
	local torso = model:FindFirstChild("Torso", true)
	local idx = math.max(entry.StartIndex - 1, 1)
	local startArc = arc[math.clamp(entry.StartIndex, 1, n)]
	local finishArc = arc[math.clamp(entry.FinishIndex, 1, n)]
	local timeout = (finishArc - startArc) / (0.5 * math.max(svc.RaceConfig.SpeedFor(stat), 1)) + 20
	local t, travelled = 0, 0
	local prev = model.PrimaryPart and model.PrimaryPart.Position
	while t < timeout do
		local dt = RunService.Heartbeat:Wait()
		t += dt
		local primary = model.PrimaryPart
		if not primary then
			break
		end
		local pos = primary.Position
		local moved = prev and (pos - prev).Magnitude or 0
		prev = pos
		travelled += moved
		st.minUp = math.min(st.minUp, primary.CFrame.UpVector.Y, torso and torso.CFrame.UpVector.Y or -1)
		local reach = arc[idx] + 2 * math.max(moved, (run.TargetSpeed or 0) * dt) + WINDOW_SLACK
		local hi = idx
		while hi < n and arc[hi] <= reach do
			hi += 1
		end
		local cf, size = model:GetBoundingBox()
		local d, seg = nearest(wps, cf.Position - cf.UpVector * (size.Y / 2), math.max(idx - 3, 1), hi)
		idx = seg
		if travelled >= GRACE_STUDS then
			st.dev = math.max(st.dev, d)
			st.n += 1
		end
		if run.Finished or (run.Driver and run.Driver.Index >= entry.FinishIndex) then
			st.finished = true
			break
		end
	end
	task.wait(0.5) -- run on past the pad: a second payout would show now (the next pad is a whole track away)
	st.payouts, st.paid = run.Payouts, run.PaidTotal
	pcall(run.Destroy, run)
	model:Destroy()
	player:Destroy()
	return st
end

-- helpers = { partPoly, polySeparation } (locals of Scenarios.luau, passed in as WorldTests does)
function M.make(helpers)
	local api = {}

	-- Scenarios.track additions. check(name, value, limit, ok) appends to that track's checks.
	function api.track(check, spec, layout, expect, metrics)
		local TrackBuilder = H.module(Shared, "TrackBuilder")
		local TrackValidator = H.module(Shared, "TrackValidator")
		local TrackRegistry = H.module(Shared, "TrackRegistry")
		local n = spec.Number

		if expect.TargetLength then
			-- the test file states the target; it must be the spec formula for its own Number
			local want = type(n) == "number" and M.target(n) or -1
			check("target_length_formula", expect.TargetLength, want, math.abs(expect.TargetLength - want) < 1e-6)
			local err = math.abs(layout.Length - want) / want
			check("target_length", layout.Length, want, want > 0 and err <= M.TOLERANCE)
			metrics.target_length_error = math.round(err * 1000) / 1000
			-- TrackValidator's TARGET_LENGTH check: +-4 % passes, +-6 % is rejected
			if TrackValidator and TrackBuilder and want > 0 then
				local inside, outside = true, true
				for _, f in { 1, 1.04, 0.96 } do
					local probe = probeSpec(n, want * f)
					inside = inside and TrackValidator.Validate(probe, TrackBuilder.Layout(probe)).Ok
				end
				for _, f in { 1.06, 0.94 } do
					local probe = probeSpec(n, want * f)
					outside = outside and not TrackValidator.Validate(probe, TrackBuilder.Layout(probe)).Ok
				end
				check("validator_target_length_accepts_within_5pct", inside and 1 or 0, 1, inside)
				check("validator_target_length_rejects_outside_5pct", outside and 1 or 0, 1, outside)
			else
				check("validator_target_length_accepts_within_5pct", -1, 1, false)
			end
		end

		if expect.NoOverlap then
			local specs = TrackRegistry and TrackRegistry.Chain() or {}
			local tracks = TrackBuilder and M.world(TrackBuilder, specs) or {}
			local index = nil
			for i, t in tracks do
				if t.Number == n then
					index = i
				end
			end
			local ok, near, pair = false, nil, nil
			if index and #tracks >= 2 then
				ok, near, pair = M.overlap(tracks, index)
			end
			check("no_overlap_other_tracks", near or -1, (layout.Width or 0) + CLEAR_PAD, index ~= nil and ok)
			metrics.nearest_other_track = pair
			-- the live plaza and Dojos (Main.server builds them beside the live chain)
			local folder = Workspace:FindFirstChild("Track")
			local model = folder and folder:FindFirstChild(spec.Name)
			local hub, plots = Workspace:FindFirstChild("SpawnArea"), Workspace:FindFirstChild("Workshops")
			check("live_track_built", model and 1 or 0, 1, model ~= nil)
			for _, case in { { "no_overlap_plaza", hub }, { "no_overlap_dojo_plots", plots } } do
				if model and case[2] then
					local hits, worst, name = liveOverlap(model, { case[2] }, helpers.partPoly, helpers.polySeparation)
					check(case[1], hits, 0, hits == 0)
					metrics[case[1] .. "_gap"] = worst == math.huge and -1 or math.round(worst * 10) / 10
					if hits > 0 then
						metrics[case[1] .. "_at"] = name
					end
				else
					check(case[1], -1, 0, false)
				end
			end
		end

		if expect.RunnerRuns then
			local svc = {
				RaceService = H.module(Server, "RaceService"),
				RunnerFactory = H.module(Shared, "RunnerFactory"),
				Money = H.module(Server, "MoneyService"),
				PlayerData = H.module(Server, "PlayerData"),
				RaceConfig = H.module(Shared, "RaceConfig"),
				Catalog = H.module(Shared, "CharacterCatalog"),
			}
			local Targets = H.module(Shared, "PhysicsTargets")
			local maxDev = Targets and Targets.race and Targets.race.MaxPathDeviation
			local route = svc.RaceService and svc.RaceService.GetRoute()
			local entry = nil
			for _, t in route and route.Tracks or {} do
				if t.Number == n then
					entry = t
				end
			end
			local apiOk = entry ~= nil
				and type(maxDev) == "number"
				and svc.RunnerFactory ~= nil
				and svc.Money ~= nil
				and svc.PlayerData ~= nil
				and svc.RaceConfig ~= nil
				and svc.Catalog ~= nil
				and TrackBuilder ~= nil
			check("runner_route_has_track", entry and 1 or 0, 1, apiOk)
			if apiOk then
				local cash = TrackBuilder.CashFor(n)
				for _, case in { { "normal", svc.RaceConfig.HALF_STAT }, { "max", svc.RaceConfig.MAX_STAT } } do
					local st = driveTrack(svc, route, entry, case[2])
					local pre = "runner_" .. case[1] .. "_"
					check(pre .. "run_started", st.ok and 1 or 0, 1, st.ok)
					check(pre .. "finished_track", st.finished and 1 or 0, 1, st.finished == true)
					check(pre .. "no_flips", st.minUp, MIN_UP_Y, st.ok and st.minUp >= MIN_UP_Y)
					check(pre .. "no_off_track", st.dev, maxDev, st.n >= MIN_SAMPLES and st.dev <= maxDev)
					check(pre .. "pad_paid_once", st.payouts or -1, 1, st.payouts == 1 and st.paid == cash)
					if st.err then
						metrics[pre .. "error"] = st.err
					end
				end
			end
		end
	end

	return api
end

return M
