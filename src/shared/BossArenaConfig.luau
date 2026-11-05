--!nonstrict
-- The boss arena's numbers and its closed lane routes (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Arena").
local PathDriver = require(script.Parent.PathDriver)

local BossArenaConfig = {}

BossArenaConfig.InnerRadius = 850
BossArenaConfig.Width = 80
BossArenaConfig.Lanes = 7
BossArenaConfig.Y = 1200 -- track top; spec: "about 1,200, confirmed by a Studio read"
-- +Z of the plaza, past the world (about +-4150, grass to about 4500, BIOME_ENVIRONMENT_SPEC and VfxArea): at least 1,500
-- studs from its edge, so the streaming target (1024) brings none of it under the arena; the test origins start at
-- +-20000. Kept under 8192 because PoseAt's heading picks up float noise that doubles past that coordinate.
BossArenaConfig.Center = Vector3.new(0, BossArenaConfig.Y, 7000)
BossArenaConfig.BossHeight = 0.66 * BossArenaConfig.InnerRadius -- feet to head top
BossArenaConfig.BossWheelHeight = 243 -- placeholder until the model is placed (b7): the draft's wheel, above the head
BossArenaConfig.BossTotalHeight = BossArenaConfig.BossHeight + BossArenaConfig.BossWheelHeight
BossArenaConfig.DaisRadius = 190
BossArenaConfig.Segments = 144 -- points on a lane and pieces of the deck; a chord cuts a lane by under 0.25 studs

-- Centre-line radius of a lane, 1 (innermost) to Lanes.
function BossArenaConfig.LaneRadius(lane)
	return BossArenaConfig.InnerRadius + (lane - 0.5) * BossArenaConfig.Width / BossArenaConfig.Lanes
end

-- A point on the ring at this radius, height y. Growing i runs counter-clockwise from above, as the draft does.
function BossArenaConfig.RingPoint(radius, i, y)
	local a = i / BossArenaConfig.Segments * 2 * math.pi
	local c = BossArenaConfig.Center
	return Vector3.new(c.X + radius * math.cos(a), y or BossArenaConfig.Y, c.Z - radius * math.sin(a))
end

local routes = {}

-- The lane's route, built once: { WorldWaypoints, Curvature, Width, Closed, Length }. The last waypoint repeats the first.
function BossArenaConfig.LaneRoute(lane)
	local route = routes[lane]
	if route then
		return route
	end
	local radius = BossArenaConfig.LaneRadius(lane)
	local waypoints, curvature = {}, {}
	for i = 0, BossArenaConfig.Segments - 1 do
		table.insert(waypoints, BossArenaConfig.RingPoint(radius, i))
		table.insert(curvature, 1 / radius)
	end
	table.insert(waypoints, waypoints[1])
	table.insert(curvature, 1 / radius)
	route = {
		WorldWaypoints = waypoints,
		Curvature = curvature,
		Width = BossArenaConfig.Width / BossArenaConfig.Lanes,
		Closed = true,
		Length = PathDriver.Arc(waypoints)[#waypoints],
	}
	routes[lane] = route
	return route
end

-- Studs per lap of the lane.
function BossArenaConfig.LaneLength(lane)
	return BossArenaConfig.LaneRoute(lane).Length
end

return BossArenaConfig
