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
