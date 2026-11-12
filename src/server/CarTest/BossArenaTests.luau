--!nonstrict
-- BRIEF: design doc 4.37, docs/BOSS_EVENT_SPEC.md "Arena" (task b4): the arena's numbers, 7 lanes and the closed rail.
-- Owner values (radius 550, width 80, 7 lanes, y about 1,200, dais 190) are asserted literally. The boss is the
-- model's 561 / 804 times BossScale (owner 2026-11-10: drawn smaller so the whole boss fits the frame).
-- The draft's direction comes from tools/blender/arena/build_arena.py. Everything else is read from the config.
-- Contract these tests assume beyond the brief:
--   Shared/BossArenaConfig: Center, InnerRadius, Width, Lanes, Y, BossHeight, BossTotalHeight, DaisRadius,
--   LaneRadius(lane), LaneRoute(lane), LaneLength(lane). Lane 1 is the innermost.
--   LaneRoute returns one cached { WorldWaypoints, Curvature, Width, Closed = true } per lane. The last waypoint repeats
--   the first, so PathDriver.Arc(wps)[n] is the lap. Curvature is 1 / radius (the sign is free).
--   PathDriver.PoseAt(wps, arc, dist, hint, closed): closed = route.Closed wraps dist and heading. Without it nothing changes.
--   A server-built arena sits under workspace.BossArena, which the clear-of-the-world checks skip.
-- On demand: ReplicatedStorage attributes CarTestOnly = "boss_arena", then CarTestRun = true.
local H = require(script.Parent.AcceptanceSupport)
local Shared = game:GetService("ReplicatedStorage").Shared
local PathDriver = require(Shared.PathDriver)
local Tests = {}

local LAP_TOLERANCE = 50 -- spec rounds lane 4's lap to the nearest hundred: "about 3,700"
local Y_TOLERANCE = 100 -- "y about 1,200", final value set by a Studio read
local RUNNER_ROOM = 5.75 -- the draft's runner height, wider than the rig: lanes this far apart cannot touch
local DAIS_DEPTH = 120 -- the draft's dais stem hangs this far under the track top
local SPEEDS = { 0.4, 13.34 } -- one 60 Hz step at 24 and 800 studs/s (spec "Laps")

local function near(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= tolerance
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function angle(a, b)
	return math.atan2(a:Cross(b).Magnitude, a:Dot(b))
end

local function samePose(a, b)
	return (a.Position - b.Position).Magnitude < 0.01 and angle(a.LookVector, b.LookVector) < 1e-3
end

-- The world-space top of a part, rotation included.
local function partTop(part)
	local cf, s = part.CFrame, part.Size
	return cf.Y
		+ (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
end

function Tests.boss_arena()
	local r, flag = H.report("boss_arena")

	local function section(name, body)
		local ok, err = xpcall(body, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end

	-- Runs with or without the config: the race rail must not change.
	section("open_path", function()
		local wps = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 10) }
		local arc = PathDriver.Arc(wps)
		flag("open_arc", arc[1] == 0 and arc[2] == 10 and arc[3] == 20)
		local function poseIs(label, dist, position, look, segment)
			local cf, k = PathDriver.PoseAt(wps, arc, dist)
			local same = samePose(cf, (PathDriver.PoseAt(wps, arc, dist, nil, false)))
			flag(
				label,
				same
					and k == segment
					and (cf.Position - position).Magnitude < 1e-3
					and angle(cf.LookVector, look.Unit) < 1e-3
			)
		end
		poseIs("open_middle_blends_heading", 5, Vector3.new(5, 0, 0), Vector3.new(2, 0, 1), 1)
		poseIs("open_clamps_before_start", -5, Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), 1)
		poseIs("open_clamps_past_end", 25, Vector3.new(10, 0, 10), Vector3.new(0, 0, 1), 2)
		-- A path that ends where it starts is still open unless it says otherwise.
		local loop = {
			Vector3.new(0, 0, 0),
			Vector3.new(10, 0, 0),
			Vector3.new(10, 0, 10),
			Vector3.new(0, 0, 10),
			Vector3.new(0, 0, 0),
		}
		local cf = PathDriver.PoseAt(loop, PathDriver.Arc(loop), 41)
		flag("open_loop_does_not_wrap", (cf.Position - loop[5]).Magnitude < 1e-3)
		flag("open_loop_keeps_end_heading", angle(cf.LookVector, Vector3.new(0, 0, -1)) < 1e-3)
	end)

	local Cfg = H.module(Shared, "BossArenaConfig")
	flag("config_exists", Cfg ~= nil)
	if not Cfg then
		return r
	end

	section("owner_values", function()
		flag("inner_radius_550", Cfg.InnerRadius == 550, Cfg.InnerRadius, 550) -- owner 2026-11-06
		flag("width_80", Cfg.Width == 80, Cfg.Width, 80)
		flag("lanes_7", Cfg.Lanes == 7, Cfg.Lanes, 7)
		flag("y_about_1200", near(Cfg.Y, 1200, Y_TOLERANCE), Cfg.Y, 1200)
		flag("center_is_at_y", typeof(Cfg.Center) == "Vector3" and near(Cfg.Center.Y, Cfg.Y, 0.01))
		local scale = Cfg.BossScale
		flag("boss_scale_in_range", type(scale) == "number" and scale > 0 and scale <= 1, scale)
		scale = type(scale) == "number" and scale or 1
		-- The model's own heights (561 head top, 804 wheel top) times BossScale; the ring does not scale it.
		flag("boss_height_fixed", near(Cfg.BossHeight, 561 * scale, 1.5 * scale), Cfg.BossHeight, 561 * scale) -- the draft measures 560
		flag("boss_height_about_560", near(Cfg.BossHeight, 560 * scale, 2 * scale), Cfg.BossHeight, 560 * scale)
		flag("boss_total_804", near(Cfg.BossTotalHeight, 804 * scale, 1 * scale), Cfg.BossTotalHeight, 804 * scale) -- the draft measures 804.4
		flag("dais_190", Cfg.DaisRadius == 190, Cfg.DaisRadius, 190)
		flag("dais_clears_inner_edge", Cfg.DaisRadius < Cfg.InnerRadius, Cfg.DaisRadius, Cfg.InnerRadius)
		local lap = Cfg.LaneLength(4)
		flag("lap_lane4_about_3700", near(lap, 3700, LAP_TOLERANCE), lap, 3700)
	end)

	section("lanes", function()
		local inner, outer, pitches = Cfg.InnerRadius, Cfg.InnerRadius + Cfg.Width, {}
		local ordered, inside, longer = true, true, true
		for lane = 1, Cfg.Lanes do
			local radius = Cfg.LaneRadius(lane)
			inside = inside and radius - inner >= RUNNER_ROOM / 2 and outer - radius >= RUNNER_ROOM / 2
			if lane > 1 then
				local gap = radius - Cfg.LaneRadius(lane - 1)
				ordered = ordered and gap >= RUNNER_ROOM
				longer = longer and Cfg.LaneLength(lane) > Cfg.LaneLength(lane - 1)
				table.insert(pitches, gap)
			end
		end
		flag("lanes_distinct_inner_to_outer", ordered)
		flag("lanes_inside_edges_with_room", inside)
		flag("lanes_longer_outward", longer)
		flag("lanes_even", #pitches > 0 and math.max(table.unpack(pitches)) - math.min(table.unpack(pitches)) < 0.01)
	end)

	for lane = 1, Cfg.Lanes or 0 do
		section("route_" .. lane, function()
			local route = Cfg.LaneRoute(lane)
			local tag = "_lane_" .. lane
			local wps, radius, C = route.WorldWaypoints, Cfg.LaneRadius(lane), Cfg.Center
			local arc = PathDriver.Arc(wps)
			local n, lap = #wps, arc[#wps]
			local function pose(dist, hint)
				return PathDriver.PoseAt(wps, arc, dist, hint, route.Closed)
			end

			flag("route_cached" .. tag, rawequal(route, Cfg.LaneRoute(lane)))
			flag("route_closed" .. tag, route.Closed == true)
			flag("route_width" .. tag, type(route.Width) == "number" and route.Width > 0 and route.Width <= Cfg.Width)
			flag("route_repeats_first" .. tag, (wps[n] - wps[1]).Magnitude < 1e-3)
			flag("route_length" .. tag, near(Cfg.LaneLength(lane), lap, 0.01), Cfg.LaneLength(lane), lap)

			local onCircle, curved, hugs = true, #route.Curvature == n, true
			for i, p in wps do
				onCircle = onCircle and near(flat(p - C).Magnitude, radius, 0.01) and near(p.Y, Cfg.Y, 0.01)
				curved = curved and near(math.abs(route.Curvature[i]), 1 / radius, 1e-6)
				if i < n then
					-- The rail cuts corners between points; a runner must stay in its own lane.
					hugs = hugs and radius - flat((p + wps[i + 1]) / 2 - C).Magnitude < RUNNER_ROOM / 2
				end
			end
			flag("route_on_circle" .. tag, onCircle)
			flag("route_curvature" .. tag, curved)
			flag("route_stays_in_lane" .. tag, hugs)

			-- Closed wrap: any whole number of laps away is the same pose.
			local wraps = samePose(pose(lap), pose(0))
			for _, d in { 0, 1, lap / 3, lap / 2, lap - 1 } do
				wraps = wraps and samePose(pose(d), pose(d + lap)) and samePose(pose(d), pose(d + 3 * lap))
			end
			flag("closed_wrap" .. tag, wraps)

			-- Heading follows the circle, the way the draft runs (counter-clockwise from above).
			local tangent, ccw = true, true
			for i = 0, 11 do
				local cf, k = pose(lap * i / 12)
				local out = flat(cf.Position - C).Unit
				tangent = tangent and k >= 1 and k < n and math.abs(cf.LookVector:Dot(out)) < 0.01
				ccw = ccw and out:Cross(cf.LookVector).Y > 0
			end
			flag("heading_tangent" .. tag, tangent)
			flag("heading_counter_clockwise" .. tag, ccw)

			-- Seam: a step across it moves like a step anywhere else, with the live hint a runner carries.
			for _, ds in SPEEDS do
				local function walk(from)
					local worstStep, worstTurn, hintOk = 0, 0, true
					local d = from
					local last, hint = pose(d)
					for _ = 1, 40 do
						d += ds
						local cf, k = pose(d, hint)
						hintOk = hintOk and samePose(cf, pose(d))
						worstStep = math.max(worstStep, math.abs((cf.Position - last.Position).Magnitude - ds))
						worstTurn = math.max(worstTurn, angle(last.LookVector, cf.LookVector))
						last, hint = cf, k
					end
					return worstStep, worstTurn, hintOk
				end
				local seamStep, seamTurn, seamHint = walk(lap - 20 * ds)
				local _, baseTurn = walk(lap / 4)
				local speed = "_" .. ds .. tag
				flag("seam_step_even" .. speed, seamStep <= 0.05 * ds, seamStep, 0.05 * ds)
				-- 1e-3 rad is CFrame noise at this radius; a seam without wrapped tangents jumps about 0.04 rad.
				flag("seam_heading_even" .. speed, seamTurn <= 1.5 * baseTurn + 1e-3, seamTurn, 1.5 * baseTurn + 1e-3)
				flag("seam_hint_agrees" .. speed, seamHint)
			end
		end)
	end

	-- What a server test can read: parts by their tops, and rays through the ring for terrain and anything else.
	-- The boss and arena visuals build on the client (spec), so they are not seen here.
	section("clear_of_world", function()
		local arena = workspace:FindFirstChild("BossArena")
		local limit, tallest, tallestName = Cfg.Y - DAIS_DEPTH, -math.huge, "none"
		for _, part in workspace:GetDescendants() do
			if part:IsA("BasePart") and not part:IsA("Terrain") and not (arena and part:IsDescendantOf(arena)) then
				local top = partTop(part)
				if top > tallest then
					tallest, tallestName = top, part:GetFullName()
				end
			end
		end
		r.metrics.tallest_part = tallestName
		flag("arena_above_tallest_part", tallest < limit, tallest, limit)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { arena }
		local clear = true
		for i = 0, 35 do
			local a = math.rad(i * 10)
			local at = Cfg.Center + Vector3.new(math.cos(a), 0, math.sin(a)) * Cfg.LaneRadius(4)
			clear = clear and workspace:Raycast(at + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params) == nil
		end
		flag("ring_band_empty", clear)
	end)

	return r
end

return Tests
