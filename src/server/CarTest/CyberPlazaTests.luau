--!nonstrict
-- BRIEF: design doc 4.24 "Enclosed cyber dojo" (owner 2026-11-10). Written by test-writer; never loosen a limit to
-- make it pass. A tech wall (about 60 studs high, proposed) rings the plaza, both wings and the Dojo ring, so no
-- track shows from anywhere on foot; the RACE START blast door is the only way out; Zone 0 is the compound; Dojos keep
-- their 4 level tiers (levels 1, 4, 7, 10) with screens and rim lights named Glow_lamp. Server checks only: the door
-- opening, the Glow_lamp colour and the first-join reveal are client checks (UiTest/UiCyberPlaza).
-- Contract these tests assume beyond the brief (implementer: report a change, do not loosen):
--   Shared/CyberPlaza: Distance(x, z) (signed studs from the wall's centre line, negative inside), Inside(p), TOP,
--     WALL_THICKNESS, RADIUS, CORNER_MIN, CORNER_MAX, DOOR_WIDTH, DOOR_HEIGHT.
--   Workspace.CyberPlaza (Model): Wall/Wall (colliding pieces), Floor/Floor (slabs; corner discs are Cylinders), Gate
--     (Model: DoorFrame x2, DoorHeader, leaf Models tagged CyberDoorLeaf with a part "Leaf"), Look.
--   Server/CyberDojo.Build(levelTier, frame, parent): Model DojoMesh; free plot (0): part "Closed", no Tier, no
--     Glow_lamp; levels 1 / 4 / 7 / 10: 0 / 1 / 2 / 3 parts named "Tier".
-- Runs inside world_layout (WorldTests) until Scenarios.luau registers it on its own (CarTest/Scenarios.luau is held
-- by another session).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent

local INSIDE_MARGIN = 2 -- studs: every plaza part and Dojo plot this far inside the wall's centre line
local OUTSIDE_MARGIN = 1 -- studs: every road and side wall past the wall's outer face (half its thickness)
local SAMPLE_STEP = 0.5 -- studs between samples on a part's edges; the distance is 1-Lipschitz, so a sampled
-- minimum is at most SAMPLE_STEP / 2 above the true one: the limit adds that, never subtracts it
local WALL_MIN_HEIGHT = 60 -- design doc 4.24: "about 60 studs high" (proposed; change here if the owner tunes it)
local DOJO_LEVELS = { [1] = 0, [4] = 1, [7] = 2, [10] = 3 } -- design doc 4.24 Dojos: level tier -> Tier parts
local MIN_GLOW = 5 -- an owned Dojo's wall screen and its roof's 4 rim lights
local PLAZA_POINT = Vector3.new(160, 1, 160) -- a far corner of the compound, past PlazaRadius
local TRACK_COUNT = 10
local BUILD_TIMEOUT = 180 -- s: Tracks 6-10 build after the join (design doc 4.25)
local PLAZA_TIMEOUT = 60 -- s: PlazaDressing dresses the plots in the background
local GEOM_TOL = 0.05

local Tests = {}

local function waitFor(seconds, fn)
	local deadline = os.clock() + seconds
	while not fn() and os.clock() < deadline do
		task.wait(0.25)
	end
	return fn() and true or false
end

local function round(v)
	return type(v) == "number" and math.round(v * 100) / 100 or v
end

local function partsOf(root)
	local list = {}
	if root == nil then
		return list
	end
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- The 8 world corners of a part's box, indexed by (x, y, z) in {-1, 1}.
local function corners(part)
	local cf, s = part.CFrame, part.Size / 2
	local pts = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(pts, cf:PointToWorldSpace(Vector3.new(x * s.X, y * s.Y, z * s.Z)))
			end
		end
	end
	return pts
end

-- The box's 12 edges as corner index pairs (indices differ in one of x, y, z).
local EDGES = {}
for i = 1, 8 do
	for _, bit in { 1, 2, 4 } do
		local j = bit32.bxor(i - 1, bit) + 1
		if j > i then
			table.insert(EDGES, { i, j })
		end
	end
end

local CyberPlaza = H.module(Shared, "CyberPlaza")

-- Largest distance over a part's footprint: exact (the distance is convex, so its maximum is at a corner).
local function maxDistance(part)
	local worst = -math.huge
	for _, c in corners(part) do
		worst = math.max(worst, CyberPlaza.Distance(c.X, c.Z))
	end
	return worst
end

-- Smallest distance over a part's footprint, sampled on its edges and centre; never more than SAMPLE_STEP / 2 above
-- the true one. Far parts return a lower bound that is already past `limit`.
local function minDistance(part, limit)
	local centre = part.Position
	local reach = 0
	local pts = corners(part)
	for _, c in pts do
		reach = math.max(reach, Vector2.new(c.X - centre.X, c.Z - centre.Z).Magnitude)
	end
	local bound = CyberPlaza.Distance(centre.X, centre.Z) - reach
	if bound > limit then
		return bound
	end
	local best = CyberPlaza.Distance(centre.X, centre.Z)
	for _, e in EDGES do
		local a, b = pts[e[1]], pts[e[2]]
		local n = math.max(1, math.ceil(Vector2.new(b.X - a.X, b.Z - a.Z).Magnitude / SAMPLE_STEP))
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			best = math.min(best, CyberPlaza.Distance(p.X, p.Z))
		end
	end
	return best
end

-- XZ containment in an upright part, and its world top / bottom.
local function covers(part, x, z)
	local l = part.CFrame:PointToObjectSpace(Vector3.new(x, part.Position.Y, z))
	return math.abs(l.X) <= part.Size.X / 2 + GEOM_TOL and math.abs(l.Z) <= part.Size.Z / 2 + GEOM_TOL
end
local function top(part)
	return part.Position.Y + part.Size.Y / 2
end
local function bottom(part)
	return part.Position.Y - part.Size.Y / 2
end

-- Points along the wall's centre line, one stud apart, with the edge each lies on ("west" for the door's edge).
local function centreLine()
	local lo, hi, r = CyberPlaza.CORNER_MIN, CyberPlaza.CORNER_MAX, CyberPlaza.RADIUS
	local pts = {}
	local function straight(a, b, edge)
		local n = math.ceil((b - a).Magnitude)
		for k = 0, n - 1 do
			table.insert(pts, { P = a:Lerp(b, k / n), Edge = edge })
		end
	end
	local function arc(c, from)
		local n = math.ceil(math.pi / 2 * r)
		for k = 0, n - 1 do
			local a = math.rad(from) - (k / n) * math.pi / 2
			table.insert(pts, { P = c + Vector2.new(math.cos(a), math.sin(a)) * r, Edge = "corner" })
		end
	end
	straight(Vector2.new(lo.X - r, lo.Y), Vector2.new(lo.X - r, hi.Y), "west")
	arc(Vector2.new(lo.X, hi.Y), 180)
	straight(Vector2.new(lo.X, hi.Y + r), Vector2.new(hi.X, hi.Y + r), "north")
	arc(Vector2.new(hi.X, hi.Y), 90)
	straight(Vector2.new(hi.X + r, hi.Y), Vector2.new(hi.X + r, lo.Y), "east")
	arc(Vector2.new(hi.X, lo.Y), 0)
	straight(Vector2.new(hi.X, lo.Y - r), Vector2.new(lo.X, lo.Y - r), "south")
	arc(Vector2.new(lo.X, lo.Y), -90)
	return pts
end

local function encloses(flag, m, compound)
	-- SpawnArea: what shows (Transparency < 1) stays INSIDE_MARGIN inside; nothing that collides reaches past the
	-- wall's outer face. The plaza's own Floor is hidden (CyberWall shows its own floor) and runs under the wall.
	local area = Workspace:FindFirstChild("SpawnArea")
	local shown, solid = 0, 0
	local worstShown, worstShownAt, worstSolid, worstSolidAt = -math.huge, nil, -math.huge, nil
	local badShown, badSolid = 0, 0
	local pad = area and area:FindFirstChild("StartPad")
	for _, p in partsOf(area) do
		local d = maxDistance(p)
		if p.Transparency < 1 and p ~= pad then
			shown += 1
			if d > worstShown then
				worstShown, worstShownAt = d, p:GetFullName()
			end
			if d >= -INSIDE_MARGIN then
				badShown += 1
			end
		end
		if p.CanCollide then
			solid += 1
			if d > worstSolid then
				worstSolid, worstSolidAt = d, p:GetFullName()
			end
			if d > OUTSIDE_MARGIN + GEOM_TOL then
				badSolid += 1
			end
		end
	end
	m.cyber_spawn_worst_shown = worstShownAt
	m.cyber_spawn_worst_solid = worstSolidAt
	flag("cyber_spawn_parts_inside_wall", shown > 0 and badShown == 0, round(worstShown), -INSIDE_MARGIN)
	flag("cyber_spawn_solid_parts_within_wall", solid > 0 and badSolid == 0, round(worstSolid), OUTSIDE_MARGIN)
	-- The StartPad is the doorstep: its west edge is SpawnArea's (local x 26), 1 stud inside the wall's centre line,
	-- so it may touch the wall's inner face, never pass it
	local padDistance = pad and maxDistance(pad)
	flag(
		"cyber_start_pad_inside_wall_face",
		padDistance ~= nil and padDistance <= -CyberPlaza.WALL_THICKNESS / 2 + GEOM_TOL,
		round(padDistance),
		-CyberPlaza.WALL_THICKNESS / 2
	)
	local floor = area and area:FindFirstChild("Floor")
	flag(
		"cyber_spawn_floor_hidden_under_compound",
		floor ~= nil and floor.Transparency == 1 and top(floor) <= CyberPlaza.TOP + GEOM_TOL
	)

	-- Dojo plots: every plot's footprint
	local plots, worstPlot, badPlots = 0, -math.huge, 0
	local folder = Workspace:FindFirstChild("Workshops")
	for _, plot in folder and folder:GetChildren() or {} do
		local base = plot:FindFirstChild("Base")
		if base and base:IsA("BasePart") then
			plots += 1
			local d = maxDistance(base)
			worstPlot = math.max(worstPlot, d)
			if d >= -INSIDE_MARGIN then
				badPlots += 1
				m.cyber_plot_outside = plot.Name
			end
		end
	end
	flag("cyber_dojo_plots_inside_wall", plots == 7 and badPlots == 0, round(worstPlot), -INSIDE_MARGIN)

	-- Floor discs: a Cylinder's box overstates its footprint, so each is checked as a disc on a corner centre
	local discsOk, discs = true, 0
	local floorFolder = compound:FindFirstChild("Floor")
	for _, p in partsOf(floorFolder) do
		if p:IsA("Part") and p.Shape == Enum.PartType.Cylinder then
			discs += 1
			local radius = math.max(p.Size.Y, p.Size.Z) / 2
			local onCorner = false
			local lo, hi = CyberPlaza.CORNER_MIN, CyberPlaza.CORNER_MAX
			for _, c in { lo, hi, Vector2.new(lo.X, hi.Y), Vector2.new(hi.X, lo.Y) } do
				if Vector2.new(p.Position.X - c.X, p.Position.Z - c.Y).Magnitude <= GEOM_TOL then
					onCorner = true
				end
			end
			discsOk = discsOk and onCorner and radius <= CyberPlaza.RADIUS + GEOM_TOL
		end
	end
	flag("cyber_floor_discs_inside_wall", discs == 4 and discsOk, discs, 4)

	-- Tracks 1-10: every road and side wall part past the wall's outer face
	local track = Workspace:FindFirstChild("Track")
	local built = waitFor(BUILD_TIMEOUT, function()
		local n = 0
		for _, model in track and track:GetChildren() or {} do
			local number = model:GetAttribute("Number")
			if
				type(number) == "number"
				and number <= TRACK_COUNT
				and type(model:GetAttribute("BuiltAt")) == "number"
			then
				n += 1
			end
		end
		return n >= TRACK_COUNT
	end)
	flag("cyber_tracks_built", built)
	local limit = OUTSIDE_MARGIN + SAMPLE_STEP / 2
	local checked, bad, worst, worstAt = 0, 0, math.huge, nil
	for _, model in track and track:GetChildren() or {} do
		local number = model:GetAttribute("Number")
		if type(number) == "number" and number <= TRACK_COUNT then
			for _, sub in { "Road", "Walls" } do
				for i, p in partsOf(model:FindFirstChild(sub)) do
					if i % 400 == 0 then
						task.wait()
					end
					checked += 1
					local d = minDistance(p, limit)
					if d < worst then
						worst, worstAt = d, p:GetFullName()
					end
					if d <= limit then
						bad += 1
					end
				end
			end
		end
	end
	m.cyber_track_parts_checked = checked
	m.cyber_track_closest = worstAt
	flag("cyber_tracks_outside_wall", built and checked > 0 and bad == 0, round(worst), limit)
end

local function height(flag, m, compound)
	local wallFolder = compound:FindFirstChild("Wall")
	local gate = compound:FindFirstChild("Gate")
	local pieces, short, loose = {}, 0, 0
	local lowest = math.huge
	for _, p in partsOf(wallFolder) do
		if p.Name == "Wall" then
			table.insert(pieces, p)
			local rise = top(p) - CyberPlaza.TOP
			lowest = math.min(lowest, rise)
			if rise < WALL_MIN_HEIGHT - GEOM_TOL then
				short += 1
			end
			if not p.CanCollide then
				loose += 1
			end
		end
	end
	flag("cyber_wall_pieces_tall", #pieces > 0 and short == 0, round(lowest), WALL_MIN_HEIGHT)
	flag("cyber_wall_pieces_collide", #pieces > 0 and loose == 0, loose, 0)

	local posts, header, leafParts = {}, nil, {}
	for _, p in partsOf(gate) do
		if p.Name == "DoorFrame" then
			table.insert(posts, p)
		elseif p.Name == "DoorHeader" then
			header = p
		elseif p.Name == "Leaf" and p.Parent and CollectionService:HasTag(p.Parent, "CyberDoorLeaf") then
			table.insert(leafParts, p)
		end
	end
	flag("cyber_door_parts", #posts == 2 and header ~= nil and #leafParts == 2, #posts + #leafParts, 4)
	if #posts ~= 2 or not header then
		return
	end
	local doorZ = (posts[1].Position.Z + posts[2].Position.Z) / 2
	m.cyber_door_z = round(doorZ)
	-- The door is on the spawn-to-pad axis
	local pad = Workspace:FindFirstChild("SpawnArea") and Workspace.SpawnArea:FindFirstChild("StartPad")
	if pad then
		local axis = Vector3.new(pad.Position.X, 0, pad.Position.Z).Unit
		local doorX = (posts[1].Position.X + posts[2].Position.X) / 2
		local off = Vector3.new(doorX, 0, doorZ)
		local across = (off - axis * off:Dot(axis)).Magnitude
		flag("cyber_door_on_spawn_pad_axis", across <= 1, round(across), 1)
	end

	-- Walk the centre line: every point is under a full-height colliding piece (wall or frame post), except the
	-- doorway between the posts, which the header (above the door) and the shut leaves close
	local solid = table.clone(pieces)
	for _, p in posts do
		table.insert(solid, p)
	end
	local outside, inDoor, doorOpen = 0, 0, 0
	local half = CyberPlaza.DOOR_WIDTH / 2
	for _, s in centreLine() do
		local x, z = s.P.X, s.P.Y
		local ok = false
		for _, p in solid do
			if
				p.CanCollide
				and covers(p, x, z)
				and bottom(p) <= CyberPlaza.TOP + 0.5
				and top(p) - CyberPlaza.TOP >= WALL_MIN_HEIGHT - GEOM_TOL
			then
				ok = true
				break
			end
		end
		if not ok then
			if s.Edge == "west" and math.abs(z - doorZ) <= half + 0.5 then
				inDoor += 1
				local closedAbove = covers(header, x, z)
					and top(header) - CyberPlaza.TOP >= WALL_MIN_HEIGHT - GEOM_TOL
					and bottom(header) <= CyberPlaza.TOP + CyberPlaza.DOOR_HEIGHT + GEOM_TOL
				local closedBelow = false
				for _, leaf in leafParts do
					if
						covers(leaf, x, z)
						and bottom(leaf) <= CyberPlaza.TOP + 0.5
						and top(leaf) >= bottom(header) - GEOM_TOL
					then
						closedBelow = true
					end
				end
				if not (closedAbove and closedBelow) then
					doorOpen += 1
				end
			else
				outside += 1
				m.cyber_wall_gap_at = m.cyber_wall_gap_at or ("%.1f, %.1f"):format(x, z)
			end
		end
	end
	flag("cyber_wall_no_gap_but_door", outside == 0, outside, 0)
	flag("cyber_wall_door_gap", inDoor >= CyberPlaza.DOOR_WIDTH - 2, inDoor, CyberPlaza.DOOR_WIDTH - 2)
	flag("cyber_door_shut_on_server", inDoor > 0 and doorOpen == 0, doorOpen, 0)
end

local function dojo(flag, m)
	local builder = H.module(Server, "CyberDojo")
	flag("cyber_dojo_module", builder ~= nil and type(builder.Build) == "function")
	if builder then
		local scratch = Instance.new("Folder")
		local function count(model, name)
			local n = 0
			for _, d in model:GetDescendants() do
				if d.Name == name and d:IsA("BasePart") then
					n += 1
				end
			end
			return n
		end
		local free = builder.Build(0, CFrame.new(0, 1, 0), scratch)
		flag(
			"cyber_dojo_free_closed",
			free:FindFirstChild("Closed") ~= nil and count(free, "Tier") == 0 and count(free, "Glow_lamp") == 0
		)
		for level, tiers in DOJO_LEVELS do
			local model = builder.Build(level, CFrame.new(0, 1, 0), scratch)
			flag(
				("cyber_dojo_level_%d_tiers"):format(level),
				count(model, "Tier") == tiers,
				count(model, "Tier"),
				tiers
			)
			local glow = count(model, "Glow_lamp")
			flag(("cyber_dojo_level_%d_glow_lamps"):format(level), glow >= MIN_GLOW, glow, MIN_GLOW)
		end
		scratch:Destroy()
	end

	-- The live plots after PlazaDressing: each Dojo's look follows its level's tier
	flag(
		"cyber_plaza_ready",
		waitFor(PLAZA_TIMEOUT, function()
			return ReplicatedStorage:GetAttribute("PlazaReady") == true
		end)
	)
	local folder = Workspace:FindFirstChild("Workshops")
	local bad, seen = 0, 0
	for _, plot in folder and folder:GetChildren() or {} do
		local mesh = plot:FindFirstChild("DojoMesh")
		local workshop = plot:FindFirstChild("Workshop")
		if plot:FindFirstChild("Base") then
			seen += 1
			local want = 0
			local level = workshop and (workshop:GetAttribute("Level") or 1)
			for at, tiers in DOJO_LEVELS do
				if level and level >= at and tiers >= want then
					want = tiers
				end
			end
			local ok = mesh ~= nil
			if ok and workshop then
				local n = 0
				for _, d in mesh:GetDescendants() do
					if d.Name == "Tier" then
						n += 1
					end
				end
				ok = n == want
			elseif ok then
				ok = mesh:FindFirstChild("Closed") ~= nil
			end
			if not ok then
				bad += 1
				m.cyber_dojo_wrong_look = plot.Name
			end
		end
	end
	flag("cyber_dojo_live_tiers", seen > 0 and bad == 0, bad, 0)
end

local function zone(flag)
	local env = H.module(Shared, "BiomeEnvironment")
	flag("cyber_point_inside", CyberPlaza.Inside(PLAZA_POINT))
	flag("cyber_zone_0_far_corner", env ~= nil and env.ZoneAt(PLAZA_POINT) == 0, env and env.ZoneAt(PLAZA_POINT), 0)
	-- and Track 3's first road, outside the wall and past PlazaRadius, is not Zone 0 (once the polylines are published;
	-- Track 1's start leg is within PlazaRadius, which keeps it Zone 0 as before the compound)
	local track3 = nil
	for _, model in Workspace:FindFirstChild("Track") and Workspace.Track:GetChildren() or {} do
		if model:GetAttribute("Number") == 3 then
			track3 = model
		end
	end
	local road = track3 and track3:FindFirstChild("Road") and track3.Road:FindFirstChild("Road1")
	local published = waitFor(10, function()
		return ReplicatedStorage:GetAttribute("BiomeZone_3") ~= nil
	end)
	local z = env and road and published and env.ZoneAt(road.Position)
	flag("cyber_zone_road_not_0", z ~= nil and z ~= 0, z, "not 0")
end

-- Adds the cyber dojo's checks to `flag` (AcceptanceSupport.report) and its metrics to `m`.
function Tests.checks(flag, m)
	local compound = Workspace:FindFirstChild("CyberPlaza")
	local ok = CyberPlaza ~= nil
		and compound ~= nil
		and compound:IsA("Model")
		and compound:FindFirstChild("Wall") ~= nil
		and compound:FindFirstChild("Floor") ~= nil
		and compound:FindFirstChild("Gate") ~= nil
		and compound:FindFirstChild("Look") ~= nil
	flag("cyber_plaza_built", ok)
	if not ok then
		return
	end
	for name, body in
		{
			encloses = function()
				encloses(flag, m, compound)
			end,
			height = function()
				height(flag, m, compound)
			end,
			dojo = function()
				dojo(flag, m)
			end,
			zone = function()
				zone(flag)
			end,
		}
	do
		local done, err = xpcall(body, debug.traceback)
		flag("cyber_" .. name .. "_completed", done, done and 1 or tostring(err))
	end
end

-- A scenario of its own, for when Scenarios.luau registers it (Scenarios.cyber_plaza = ...).
function Tests.cyber_plaza()
	local r, flag = H.report("cyber_plaza")
	Tests.checks(flag, r.metrics)
	return r
end

return Tests
