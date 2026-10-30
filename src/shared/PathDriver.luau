--!nonstrict
-- The race rail (docs/WORLD_REDESIGN_SPEC.md section 2): the chain of tracks joined into one path, and the pose of
-- an anchored runner at an arc distance along it. Server/RaceService moves the authoritative rig with PoseAt; every
-- client draws the visible runner with the same function from the distance and speed the server publishes.

local TrackBuilder = require(script.Parent.TrackBuilder)

local PathDriver = {}

-- Cumulative arc length at every waypoint: arc[1] = 0, arc[i] = studs from waypoint 1 to waypoint i.
function PathDriver.Arc(wps)
	local arc = table.create(#wps)
	arc[1] = 0
	for i = 2, #wps do
		arc[i] = arc[i - 1] + (wps[i] - wps[i - 1]).Magnitude
	end
	return arc
end

-- Flat (XZ) path direction at waypoint k: between its neighbours, so the heading turns smoothly through a corner.
local function tangentAt(wps, k)
	local d = wps[math.min(k + 1, #wps)] - wps[math.max(k - 1, 1)]
	return Vector3.new(d.X, 0, d.Z)
end

-- The segment k (1..n-1) holding arc distance `dist`, searched from `hint`.
function PathDriver.SegmentAt(arc, dist, hint)
	local n = #arc
	local k = math.clamp(hint or 1, 1, math.max(n - 1, 1))
	while k < n - 1 and arc[k + 1] <= dist do
		k += 1
	end
	while k > 1 and arc[k] > dist do
		k -= 1
	end
	return k
end

-- The pose `dist` studs along the path: the point on the waypoint polyline (feet on the road, exact arc length) and
-- an upright CFrame at that point facing along the path (heading blended between the waypoint tangents).
-- Returns cframe (at the feet), segment index.
function PathDriver.PoseAt(wps, arc, dist, hint)
	local n = #wps
	dist = math.clamp(dist, 0, arc[n])
	local k = PathDriver.SegmentAt(arc, dist, hint)
	local len = arc[k + 1] - arc[k]
	local t = len > 1e-6 and (dist - arc[k]) / len or 0
	local pos = wps[k]:Lerp(wps[k + 1], t)
	local dir = tangentAt(wps, k):Lerp(tangentAt(wps, k + 1), t)
	if dir.Magnitude < 1e-6 then
		local d = wps[k + 1] - wps[k]
		dir = Vector3.new(d.X, 0, d.Z)
	end
	if dir.Magnitude < 1e-6 then
		dir = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(pos, pos + dir.Unit), k
end

-- Joins the tracks of the chain into one path. entries = { { Layout, Origin, Model?, Number? }, ... } in
-- Number order. Each track contributes its RacePath (centre line plus the swing over the winnings pad).
-- The first point of every later track is the previous track's finish, so it is dropped.
-- path.PadIndices[i] is the waypoint index of entry i's pad; StartIndices[i] / FinishIndices[i] are the first and
-- last waypoint of entry i (a later track starts on the previous finish, so its StartIndex is that FinishIndex).
function PathDriver.Chain(entries)
	local waypoints, curvature, padIndices = {}, {}, {}
	local startIndices, finishIndices = {}, {}
	for i, entry in entries do
		local race = TrackBuilder.RacePath(entry.Layout)
		local first = i == 1 and 1 or 2
		startIndices[i] = math.max(#waypoints, 1)
		for k = first, #race.Waypoints do
			table.insert(waypoints, entry.Origin:PointToWorldSpace(race.Waypoints[k]))
			table.insert(curvature, race.Curvature[k])
		end
		padIndices[i] = #waypoints - (#race.Waypoints - race.PadIndex)
		finishIndices[i] = #waypoints
	end
	return {
		WorldWaypoints = waypoints,
		Curvature = curvature,
		Closed = false,
		Width = entries[1] and entries[1].Layout.Width or 40,
		PadIndices = padIndices,
		StartIndices = startIndices,
		FinishIndices = finishIndices,
	}
end

return PathDriver
