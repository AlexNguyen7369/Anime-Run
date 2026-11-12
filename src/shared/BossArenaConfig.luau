--!nonstrict
-- The boss arena's numbers and its closed lane routes (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Arena").
local PathDriver = require(script.Parent.PathDriver)

local BossArenaConfig = {}

BossArenaConfig.InnerRadius = 550 -- owner 2026-11-06
BossArenaConfig.Width = 80
BossArenaConfig.Lanes = 7
BossArenaConfig.Y = 1200 -- track top; spec: "about 1,200, confirmed by a Studio read"
-- +Z of the plaza, past the world (about +-4150, grass to about 4500, BIOME_ENVIRONMENT_SPEC and VfxArea): at least 1,500
-- studs from its edge, so the streaming target (1024) brings none of it under the arena; the test origins start at
-- +-20000. Kept under 8192 because PoseAt's heading picks up float noise that doubles past that coordinate.
BossArenaConfig.Center = Vector3.new(0, BossArenaConfig.Y, 7000)
-- Proposed 2026-11-10 (owner: the whole boss must fit the frame, and from the ring the camera alone cannot do it): the model is drawn
-- this much smaller. 1 is the model's own size (561 to the head top, owner 2026-11-04).
BossArenaConfig.BossScale = 0.75
BossArenaConfig.BossHeight = 561 * BossArenaConfig.BossScale -- feet to head top; the model's Poses.Scale times BossScale, not the ring
BossArenaConfig.BossWheelHeight = 243 * BossArenaConfig.BossScale -- the draft's wheel, above the head
BossArenaConfig.BossTotalHeight = BossArenaConfig.BossHeight + BossArenaConfig.BossWheelHeight
BossArenaConfig.DaisRadius = 190
BossArenaConfig.DaisY = BossArenaConfig.Y - 50 -- proposed: the dais's top, where the boss's feet stand (owner 2026-11-06: lower)
BossArenaConfig.Segments = 144 -- points on a lane and pieces of the deck; a chord cuts a lane by under 0.25 studs

-- The ring's functions on an arena's numbers, each arena with its own route cache.
local function build(arena)
	-- Centre-line radius of a lane, 1 (innermost) to Lanes.
	function arena.LaneRadius(lane)
		return arena.InnerRadius + (lane - 0.5) * arena.Width / arena.Lanes
	end

	-- A point on the ring at this radius, height y. Growing i runs counter-clockwise from above, as the draft does.
	function arena.RingPoint(radius, i, y)
		local a = i / arena.Segments * 2 * math.pi
		local c = arena.Center
		return Vector3.new(c.X + radius * math.cos(a), y or arena.Y, c.Z - radius * math.sin(a))
	end

	local routes = {}

	-- The lane's route, built once: { WorldWaypoints, Curvature, Width, Closed, Length }. The last waypoint repeats the first.
	function arena.LaneRoute(lane)
		local route = routes[lane]
		if route then
			return route
		end
		local radius = arena.LaneRadius(lane)
		local waypoints, curvature = {}, {}
		for i = 0, arena.Segments - 1 do
			table.insert(waypoints, arena.RingPoint(radius, i))
			table.insert(curvature, 1 / radius)
		end
		table.insert(waypoints, waypoints[1])
		table.insert(curvature, 1 / radius)
		route = {
			WorldWaypoints = waypoints,
			Curvature = curvature,
			Width = arena.Width / arena.Lanes,
			Closed = true,
			Length = PathDriver.Arc(waypoints)[#waypoints],
		}
		routes[lane] = route
		return route
	end

	-- Studs per lap of the lane.
	function arena.LaneLength(lane)
		return arena.LaneRoute(lane).Length
	end
	return arena
end

build(BossArenaConfig)

-- The Elf Mage's colosseum (BOSS_EVENT_SPEC "The Elf Mage"), the same fields plus the wall and her hover. All proposed. -Z of the
-- plaza, mirroring the sky arena's site: as clear of the world, and under 8192.
local colosseum = { Y = 1200 }
colosseum.Center = Vector3.new(0, colosseum.Y, -7000)
colosseum.InnerRadius = 70
colosseum.Width = 56
colosseum.Lanes = 7
colosseum.Segments = 144 -- as the sky arena: run:SwitchRoute keeps the waypoint count
colosseum.DaisY = colosseum.Y
colosseum.DaisRadius = 40
colosseum.BossScale = 1
colosseum.BossHeight = 44 -- 8 x a character (owner 2026-11-11)
colosseum.HoverY = 8
colosseum.BobStuds = 1.5
colosseum.BobSeconds = 3
colosseum.BossTotalHeight = colosseum.BossHeight + colosseum.HoverY + colosseum.BobStuds
colosseum.WallHeight = 70
-- The wall's inner face: the locked 40-stud camera at yaw 75 puts the eye up to 157 studs out on lane 7.
colosseum.WallRadius = 164
-- Owner 2026-11-11: travel speed is capped here so the room does not spin around her; the value is proposed. About 77 deg/s on
-- lane 1, as the sky arena turns at 800 studs/s. The sky arena has none.
colosseum.MaxRunSpeed = 100
build(colosseum)

-- The Golden King's own arena (design doc 4.37 "The Golden King's own arena", BOSS_EVENT_SPEC "The Golden King's arena", owner
-- 2026-11-12; replaces the 2026-11-11 vault re-dress of the colosseum): an open sandstone stadium built by Client/BossKingArena from
-- the approved draft tools/blender/arena/build_king_arena.py. All values proposed. The colosseum's site: one arena stands at a time.
local king = { Y = 1200 }
king.Center = colosseum.Center
king.InnerRadius = 110
king.Width = 56 -- 7 lanes of 8
king.Lanes = 7
king.Segments = 144 -- as the sky arena: run:SwitchRoute keeps the waypoint count
king.DaisY = king.Y
king.DaisRadius = 67 -- the mound's foot
king.BossScale = 1
king.BossHeight = 44 -- 8 x a character, as the mage
king.MoundTop = 35 -- the gold cap's top over the deck, the highest point of the mound
king.HoverY = king.MoundTop + 12 -- his feet over the deck: 12 over the mound's top
king.BobStuds = 1.5
king.BobSeconds = 3
king.BossTotalHeight = king.BossHeight + king.HoverY + king.BobStuds
king.WallRadius = 250 -- the podium's face; the locked camera's eye reaches about 200 on lane 7
king.MaxRunSpeed = 100 -- the lane cap, unchanged
build(king)

-- "boss_mage": the colosseum; "boss_king": his own arena; anything else: this module, the sky arena.
function BossArenaConfig.For(bossId)
	if bossId == "boss_king" then
		return king
	end
	return bossId == "boss_mage" and colosseum or BossArenaConfig
end

return BossArenaConfig
