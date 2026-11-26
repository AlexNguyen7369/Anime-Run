--!nonstrict
-- Pure helpers of the World 2 track effects draft (Shared/TrackFxConfig, docs/WORLD2_SPEC.md "Track effects (draft,
-- owner approval pending)"): no instances are made here, so the ServerTest track_fx checks run it offline (lune) and in
-- Studio. Client/TrackFx does the instances.
local Config = require(script.Parent.TrackFxConfig)

local TrackFxPlan = {}

-- Mean particles alive for one emitter of a preset at its (capped) rate: Rate x mean Lifetime
function TrackFxPlan.Cost(preset)
	local rate = math.min(preset.Rate, Config.Budget.MaxRate)
	return rate * (preset.Lifetime[1] + preset.Lifetime[2]) / 2
end

-- Cull distance of a preset, never past Budget.MaxCull
function TrackFxPlan.Cull(preset)
	return math.min(preset.Cull or Config.Budget.CullDistance, Config.Budget.MaxCull)
end

-- Worst case of one track's rows: every row at its Max anchors (what the configured caps allow before the budget picks)
function TrackFxPlan.WorstCase(track)
	local emitters, particles = 0, 0
	for _, row in track.Smoke or {} do
		local preset = Config.Presets[row.Preset]
		emitters += row.Max
		particles += row.Max * TrackFxPlan.Cost(preset)
	end
	return emitters, particles
end

-- Draft prop key of a placed prop Model (BiomeDressing: the mesh child is named the key, the fallback parts key..i,
-- a lane C box sets Model.Mesh = "<biome>_<key>"). Cut pieces keep their own key (Mountain_p1).
function TrackFxPlan.PropName(model)
	local mesh = model:GetAttribute("Mesh")
	if type(mesh) == "string" then
		local key = string.match(mesh, "^[^_]+_(.+)$")
		if key then
			return key
		end
	end
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "MeshBounds" and not string.match(child.Name, "^Lamp_") then
			return (string.gsub(child.Name, "%d+$", ""))
		end
	end
	return nil
end

-- World CFrame of a point of a prop's box: offset -1..1 per axis of the half size (beyond 1 is outside the box)
function TrackFxPlan.BoxPoint(boxCFrame, size, offset)
	return boxCFrame * CFrame.new(offset * size / 2)
end

-- Emitter box of a row on a prop: the preset's Area, or the prop's box times the row's Fill where that is larger (a long
-- lava river or a wide square spreads its emitter instead of piling it in one spot). Rate is not raised by it.
function TrackFxPlan.Area(preset, row, size)
	if not (row.Fill and size) then
		return preset.Area
	end
	local f = size * row.Fill
	return Vector3.new(math.max(preset.Area.X, f.X), math.max(preset.Area.Y, f.Y), math.max(preset.Area.Z, f.Z))
end

-- Track-local CFrame at fraction `at` of a centre line (waypoints, track-local), facing along the road
function TrackFxPlan.AlongTrack(waypoints, at)
	local total, lengths = 0, { 0 }
	for i = 2, #waypoints do
		total += (waypoints[i] - waypoints[i - 1]).Magnitude
		lengths[i] = total
	end
	local goal = math.clamp(at, 0, 1) * total
	for i = 2, #waypoints do
		if lengths[i] >= goal then
			local a, b = waypoints[i - 1], waypoints[i]
			local span = lengths[i] - lengths[i - 1]
			local p = a:Lerp(b, span > 0 and (goal - lengths[i - 1]) / span or 0)
			local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			return flat.Magnitude > 1e-6 and CFrame.lookAt(p, p + flat) or CFrame.new(p)
		end
	end
	return CFrame.new(waypoints[#waypoints])
end

-- Track-local anchor of an At row: on the centre line at At, Lateral studs to Side, Height up
function TrackFxPlan.TrackPoint(waypoints, row)
	local cf = TrackFxPlan.AlongTrack(waypoints, row.At)
	return cf * CFrame.new((row.Side or 1) * (row.Lateral or 0), row.Height or 0, 0)
end

-- A dragon's loop: 8 track-local control points on a wobbly ellipse round its centre (At / Side / Lateral), Altitude
-- above the centre line's height there. Closed Catmull-Rom through them (Spline).
function TrackFxPlan.DragonPath(waypoints, def)
	local centre = TrackFxPlan.AlongTrack(waypoints, def.At)
		* CFrame.new((def.Side or 1) * def.Lateral, def.Altitude, 0)
	local points = {}
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local r = def.Radius * (1 + 0.18 * math.sin(a * 2 + 1))
		local h = 22 * math.sin(a * 3)
		table.insert(points, (centre * CFrame.new(math.cos(a) * r, h, math.sin(a) * r * 0.7)).Position)
	end
	return points
end

-- Point and tangent at u (0..1, wraps) on the closed Catmull-Rom spline through `points`
function TrackFxPlan.Spline(points, u)
	local n = #points
	local f = (u % 1) * n
	local i = math.floor(f)
	local t = f - i
	local p0, p1, p2, p3 = points[(i - 1) % n + 1], points[i % n + 1], points[(i + 1) % n + 1], points[(i + 2) % n + 1]
	local t2, t3 = t * t, t * t * t
	local pos = 0.5
		* ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
	local tan = 0.5 * ((-p0 + p2) + 2 * (2 * p0 - 5 * p1 + 4 * p2 - p3) * t + 3 * (-p0 + 3 * p1 - 3 * p2 + p3) * t2)
	return pos, tan.Magnitude > 1e-6 and tan.Unit or Vector3.zAxis
end

-- Arc-length table of the closed spline: Catmull-Rom's parameter does not move at an even speed (a short span is
-- crossed as fast as a long one), so a body laid out by parameter bunches on the short spans and stretches on the
-- long ones, worst where the loop closes. { Length, U = { u_k }, D = { distance_k } } over `samples` even steps of u.
function TrackFxPlan.ArcTable(points, samples)
	samples = samples or 256
	local us, ds, total = { 0 }, { 0 }, 0
	local last = TrackFxPlan.Spline(points, 0)
	for k = 1, samples do
		local u = k / samples
		local p = TrackFxPlan.Spline(points, u)
		total += (p - last).Magnitude
		last = p
		us[k + 1], ds[k + 1] = u, total
	end
	return { Length = total, U = us, D = ds }
end

-- Point and tangent at distance d along the closed spline (wraps both ways), from ArcTable
function TrackFxPlan.SplineAt(points, arc, d)
	local goal = d % arc.Length
	local ds = arc.D
	local lo, hi = 1, #ds
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if ds[mid] <= goal then
			lo = mid
		else
			hi = mid
		end
	end
	local span = ds[hi] - ds[lo]
	local u = arc.U[lo] + (arc.U[hi] - arc.U[lo]) * (span > 0 and (goal - ds[lo]) / span or 0)
	return TrackFxPlan.Spline(points, u)
end

-- Distance behind the head of eel segment i: segments shrink toward the tail (to 55%), and so do the gaps between them
function TrackFxPlan.EelBack(i)
	local E, back = Config.Eel, 0
	for k = 1, i do
		back += E.Spacing * (1 - 0.45 * (k - 0.5) / E.Segments)
	end
	return back
end

-- Smallest 3D distance from the path (sampled) to the track's centre line points
function TrackFxPlan.Clearance(points, waypoints, samples)
	local best = math.huge
	for s = 0, (samples or 64) - 1 do
		local p = TrackFxPlan.Spline(points, s / (samples or 64))
		for _, w in waypoints do
			best = math.min(best, (p - w).Magnitude)
		end
	end
	return best
end

-- Every track's origin (the CFrame its Layout is built at), from the chain alone, as Main.server builds it: the first
-- at TrackBuilder.CHAIN_ORIGIN, each next at the previous one's EndCFrame. Number -> CFrame. Never read from a part, which
-- may not be streamed in (WORLD2_SPEC "Track effects").
function TrackFxPlan.ChainOrigins(TrackBuilder, chain)
	local out, origin = {}, TrackBuilder.CHAIN_ORIGIN
	for _, spec in chain do
		out[spec.Number] = origin
		origin = TrackBuilder.EndCFrame(TrackBuilder.Layout(spec), origin)
	end
	return out
end

local LINE_CELL = 64 -- studs per grid cell of the centre-line segments
local LINE_REACH = 160 -- a segment is filed in every cell within this of it: nearer queries never miss it

-- Every track's centre line in world space, with a grid of its segments for near queries:
-- { Lines = { { Number, Points } }, Grid = { ["x,z"] = { { a, b, Number } } } }
function TrackFxPlan.CentreLines(TrackBuilder, chain, origins)
	local lines, grid = {}, {}
	for _, spec in chain do
		local o = origins[spec.Number]
		local pts = {}
		for i, w in TrackBuilder.Layout(spec).Waypoints do
			pts[i] = o:PointToWorldSpace(w)
		end
		table.insert(lines, { Number = spec.Number, Points = pts })
		for i = 2, #pts do
			local a, b = pts[i - 1], pts[i]
			local seg = { a, b, spec.Number }
			for gx = math.floor((math.min(a.X, b.X) - LINE_REACH) / LINE_CELL), math.floor((math.max(a.X, b.X) + LINE_REACH) / LINE_CELL) do
				for gz = math.floor((math.min(a.Z, b.Z) - LINE_REACH) / LINE_CELL), math.floor((math.max(a.Z, b.Z) + LINE_REACH) / LINE_CELL) do
					local key = gx .. "," .. gz
					grid[key] = grid[key] or {}
					table.insert(grid[key], seg)
				end
			end
		end
	end
	return { Lines = lines, Grid = grid }
end

-- Horizontal distance from (x, z) to segment a-b, and the closest point's x, z
local function segDistance(x, z, a, b)
	local dx, dz = b.X - a.X, b.Z - a.Z
	local len2 = dx * dx + dz * dz
	local t = len2 > 0 and math.clamp(((x - a.X) * dx + (z - a.Z) * dz) / len2, 0, 1) or 0
	local cx, cz = a.X + dx * t, a.Z + dz * t
	return math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2), cx, cz
end

-- Per track, the nearest horizontal distance from (x, z) to its centre line and the closest point there. Only tracks
-- within LINE_REACH are found from the grid; `full` scans every segment (any distance). Number -> { d, x, z }.
local function nearestByTrack(lines, x, z, full)
	local best = {}
	local function take(a, b, n)
		local d, cx, cz = segDistance(x, z, a, b)
		local cur = best[n]
		if not cur or d < cur[1] then
			best[n] = { d, cx, cz }
		end
	end
	if full then
		for _, line in lines.Lines do
			for i = 2, #line.Points do
				take(line.Points[i - 1], line.Points[i], line.Number)
			end
		end
	else
		for _, seg in lines.Grid[math.floor(x / LINE_CELL) .. "," .. math.floor(z / LINE_CELL)] or {} do
			take(seg[1], seg[2], seg[3])
		end
	end
	return best
end

-- The track whose ground (x, z) is: the nearest centre line of all tracks (the scenery's gap-midline ownership,
-- TerrainShape.Owner). Returns number, its distance, the next nearest other track's distance.
function TrackFxPlan.Owner(lines, x, z)
	local by = nearestByTrack(lines, x, z, true)
	local n, d, other = nil, math.huge, math.huge
	for k, v in by do
		if v[1] < d then
			n, other, d = k, d, v[1]
		elseif v[1] < other then
			other = v[1]
		end
	end
	return n, d, other
end

-- Radius of an emitter's spread: the circle round its box's footprint (any yaw)
local function spreadRadius(area)
	return math.sqrt((area.X / 2) ^ 2 + (area.Z / 2) ^ 2)
end

-- Nearest road edge clearance of a spread at `pos`: its distance to the nearest centre line less its radius (math.huge
-- when no centre line is within LINE_REACH)
function TrackFxPlan.SpreadClearance(pos, area, lines)
	local d = math.huge
	for _, v in nearestByTrack(lines, pos.X, pos.Z) do
		d = math.min(d, v[1])
	end
	return d - spreadRadius(area)
end

-- An emitter kept off every road (WORLD2_SPEC "Track effects", the props rule): its spread clears every centre line by
-- Budget.RoadClear, first by narrowing it (down to Budget.MinSpread of its width), then by moving it straight away from
-- the nearest centre line. Returns the position and area to use, or nil when it cannot clear (between two roads).
function TrackFxPlan.ClearSpread(pos, area, lines)
	local B = Config.Budget
	local r = spreadRadius(area)
	local d, cx, cz = math.huge, nil, nil
	for _, v in nearestByTrack(lines, pos.X, pos.Z) do
		if v[1] < d then
			d, cx, cz = v[1], v[2], v[3]
		end
	end
	if d - r >= B.RoadClear then
		return pos, area
	end
	local scale = (d - B.RoadClear - 0.01) / r
	if scale >= B.MinSpread then
		return pos, Vector3.new(area.X * scale, area.Y, area.Z * scale)
	end
	local small = Vector3.new(area.X * B.MinSpread, area.Y, area.Z * B.MinSpread)
	local away = Vector3.new(pos.X - cx, 0, pos.Z - cz)
	if away.Magnitude < 1e-3 then
		return nil
	end
	local moved = Vector3.new(cx, pos.Y, cz) + away.Unit * (B.RoadClear + spreadRadius(small) + 0.01)
	if TrackFxPlan.SpreadClearance(moved, small, lines) < B.RoadClear then
		return nil
	end
	return moved, small
end

-- A dragon loop over its own track's ground (WORLD2_SPEC "Track effects"): the loop is resampled into OWN_POINTS control
-- points (so the spline between them cannot stray far), and every one not owned by track `n` by Budget.OwnMargin is
-- pulled straight toward `toward` (height kept) until it is: the loop's anchor on its own centre line (DragonFoot), mid
-- track, never the start or finish its neighbours share.
-- A dragon loop over its own track's ground (WORLD2_SPEC "Track effects"), its shape kept: the whole loop is shrunk about
-- its foot on its own centre line (its side offset and its radius by the same factor) to the largest size whose every
-- sampled point lies over its own track's ground by Budget.OwnMargin. Returns the control points (track-local, as
-- DragonPath) and the factor, or nil when even a loop of Budget.MinLoopRadius does not fit: that dragon is not built.
local FIT_SAMPLES = 96
function TrackFxPlan.FitLoop(waypoints, def, origin, n, lines)
	local B = Config.Budget
	local function fits(k)
		local scaled = table.clone(def)
		scaled.Lateral, scaled.Radius = def.Lateral * k, def.Radius * k
		local path = TrackFxPlan.DragonPath(waypoints, scaled)
		local world = {}
		for i, p in path do
			world[i] = origin:PointToWorldSpace(p)
		end
		for s = 0, FIT_SAMPLES - 1 do
			local q = TrackFxPlan.Spline(world, s / FIT_SAMPLES)
			local owner, d, other = TrackFxPlan.Owner(lines, q.X, q.Z)
			if owner ~= n or d + B.OwnMargin > other then
				return nil
			end
		end
		return path
	end
	local full = fits(1)
	if full then
		return full, 1
	end
	local lo, hi = B.MinLoopRadius / def.Radius, 1
	if not fits(lo) then
		return nil
	end
	for _ = 1, 12 do
		local mid = (lo + hi) / 2
		if fits(mid) then
			lo = mid
		else
			hi = mid
		end
	end
	return fits(lo), lo
end

-- Nearest-first pick under the budget. candidates: { { Key, Position, Cost, Cull } }. Returns the kept keys as a set.
function TrackFxPlan.Pick(candidates, camera, maxCount, maxCost)
	local list = {}
	for _, c in candidates do
		local d = (c.Position - camera).Magnitude
		if d <= c.Cull then
			table.insert(list, { c, d })
		end
	end
	table.sort(list, function(a, b)
		return a[2] < b[2]
	end)
	local kept, count, cost = {}, 0, 0
	for _, e in list do
		local c = e[1]
		if count + 1 > maxCount then
			break
		end
		if cost + (c.Cost or 0) <= maxCost then
			kept[c.Key] = true
			count += 1
			cost += c.Cost or 0
		end
	end
	return kept, count, cost
end

-- Prop motion: the offset applied at the prop's base pivot at time t (phase 0..1 per prop)
function TrackFxPlan.Motion(row, t, phase)
	local w = math.pi * 2 * (t / row.Period + phase)
	if row.Kind == "Sway" then
		-- two slow sines on two axes, so the top traces a lazy loop instead of a line
		return CFrame.Angles(math.rad(row.Angle) * math.sin(w), 0, math.rad(row.Angle) * 0.6 * math.sin(w * 0.73 + 1.3))
	elseif row.Kind == "Bob" then
		return CFrame.new(0, row.Height * math.sin(w), 0)
			* CFrame.Angles(0, 0, math.rad(row.Roll or 0) * math.sin(w * 0.8 + 0.7))
	elseif row.Kind == "Spin" then
		return CFrame.Angles(0, w, 0)
	end
	return CFrame.identity
end

-- Light flicker multiplier at time t for a lamp of `seed`: smooth noise round 1, minus Depth, and rare short dropouts
function TrackFxPlan.Flicker(flicker, t, seed)
	local s = t * flicker.Speed + seed * 17.31
	local n = math.sin(s) * 0.5 + math.sin(s * 2.37 + 1.1) * 0.3 + math.sin(s * 5.11 + 2.3) * 0.2 -- -1..1
	local k = 1 - flicker.Depth * (0.5 + 0.5 * n)
	if (flicker.Dropout or 0) > 0 then
		-- a dropout window of 0.12 s comes up with probability Dropout per window, decided by a hash of the window
		local window = math.floor(t / 0.12)
		local h = math.sin(window * 12.9898 + seed * 78.233) * 43758.5453
		if h - math.floor(h) < flicker.Dropout then
			k = 0.08
		end
	end
	return math.clamp(k, 0, 1)
end

return TrackFxPlan
