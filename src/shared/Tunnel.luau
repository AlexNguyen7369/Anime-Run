--!nonstrict
-- Enclosed tunnel corridor (docs/BIOME_ENVIRONMENT_SPEC.md 3.5). A biome module's optional `Tunnel` field:
--   Tunnel = {
--   	Width = 120, Height = 26,                         -- target inner width (narrowed per side, below) and height
--   	Wall = { Material, Color = "#hex", Stripe = "#hex"? },
--   	Ceiling = { Material, Color = "#hex" },
--   	Floor = { Material, Color = "#hex" }?,             -- a slab under the road across the whole tunnel width
--   	LightEvery = 24,                                  -- one ceiling light strip every N studs
--   	Bays = { { From = 0.12, To = 0.17, Side = "Left"|"Right"|"Both", Depth = 40, Height = 30 }, ... },
--   	Portals = true,                                   -- entrance facades at the start and finish
--   }
-- Owner 2026-11-01 (fw8): the inner half-width on each side is min(Width / 2, room), where room keeps the tunnel box
-- (walls + MARGIN) ROOM_MARGIN studs off every other track's corridor (TerrainShape.CORRIDOR from its centre line) and
-- off this track's own far laps. It changes by at most TAPER studs per stud along the road, so the walls slope, never
-- step. Profile(layout, origin, def) is that per-side width every STEP studs; Section and Segments read it.
-- Segments(layout, origin, def) is pure: the tunnel cut into straight pieces along the road, each with its cross
-- section. Build places the parts from it (server, Main.server right after TrackBuilder.Build); TerrainShape reads
-- the same segments to keep the tunnel box clear of voxels and to heap earth over it (option A, owner 2026-10-31).
local CollectionService = game:GetService("CollectionService")
local TrackBuilder = require(script.Parent.TrackBuilder)
local CLEARANCE = require(script.Parent.BiomeDressing).CLEARANCE

local Tunnel = {}
Tunnel.TAG = "Tunnel" -- on each track's Tunnel folder (the client camera clamp raycasts against these)
Tunnel.LIGHT_TAG = "TunnelLight" -- on each light strip, attribute Index (1, 2, ...) along the track
Tunnel.WALL = 2 -- placeholder: wall thickness
Tunnel.CEILING = 2 -- placeholder: ceiling thickness
Tunnel.ROAD = 2 -- TrackBuilder ROAD_THICKNESS: walls start at the road slab's underside
Tunnel.MARGIN = 4 -- one terrain voxel: the hollow reaches this far past the walls, ceiling and segment ends
Tunnel.COVER = 6 -- placeholder: earth over the hollow
Tunnel.BLEND = 24 -- placeholder: studs over which the earth slopes from the cover down to the ridge
-- placeholder: the start portal's face sits this far past the track start, clear of the previous track's
-- checkpoint by CLEARANCE; the finish portal's face sits CLEARANCE + 2 before this track's checkpoint area
Tunnel.START = CLEARANCE + 8
Tunnel.PORTAL = 16 -- placeholder: facade depth along the road; the earth starts PORTAL / 2 inside it
Tunnel.PLATFORM = 4 -- placeholder: a bay platform's top above the road top
-- fw8 (orchestrator default 2026-11-01, placeholders): the adaptive width
Tunnel.STEP = 8 -- studs between width stations along the road
Tunnel.TAPER = 0.25 -- studs of width change per stud along the road (about 14 degrees)
Tunnel.ROOM_MARGIN = 4 -- studs the tunnel box keeps from another track's corridor edge
Tunnel.CORRIDOR = 44 -- TerrainShape.CORRIDOR (TerrainShape requires this module)
Tunnel.SELF_GAP = 400 -- studs along the road past which this track's own centre line counts as a neighbour
Tunnel.PLATFORM_EDGE = 30 -- a bay platform's road-side edge from the centre line (the old Width / 2)
Tunnel.SIDE_LIGHTS = 3 -- side light rows (where the half-width is at least SIDE_LIGHT_HALF): one every 3 x LightEvery
Tunnel.SIDE_LIGHT_HALF = 40
-- The hollow's floor sits under the lowest road within this many studs along it (spec test corridor_clear reads
-- voxel columns up to the sample spacing plus the road half-width plus CLEARANCE away along a ramp)
Tunnel.FLOOR_REACH = 40
-- placeholders; colour from the Track 7 palette
Tunnel.LIGHT =
	{ Size = Vector3.new(2, 0.3, 8), Range = 20, Brightness = 2, Angle = 120, Color = Color3.fromHex("CFE8FF") }

local function colour(c, fallback)
	if typeof(c) == "Color3" then
		return c
	end
	return type(c) == "string" and Color3.fromHex(c) or fallback
end

-- Track positions (XZ studs from the start) where the tunnel starts and ends, and the track's XZ length (the same
-- length TerrainShape uses for Sections)
function Tunnel.Span(layout)
	local total = 0
	local wps = layout.Waypoints
	for k = 2, #wps do
		total += Vector2.new(wps[k].X - wps[k - 1].X, wps[k].Z - wps[k - 1].Z).Magnitude
	end
	return Tunnel.START, total - TrackBuilder.CHECKPOINT_LENGTH - CLEARANCE - 2, total
end

-- Every chain track's centre line in world XZ (TrackRegistry order from CHAIN_ORIGIN, as Main.server builds it),
-- once: the neighbours a tunnel keeps its box away from. { Pts (Vector2), Cum (XZ studs), Origin (Vector3) }
local chainLines
local function chain()
	if not chainLines then
		chainLines = {}
		local origin = TrackBuilder.CHAIN_ORIGIN
		for _, spec in require(script.Parent.TrackRegistry).Chain() do
			local layout = TrackBuilder.Layout(spec)
			local pts, cum = {}, {}
			for k, p in layout.Waypoints do
				local w = origin:PointToWorldSpace(p)
				pts[k] = Vector2.new(w.X, w.Z)
				cum[k] = k == 1 and 0 or cum[k - 1] + (pts[k] - pts[k - 1]).Magnitude
			end
			table.insert(chainLines, { Pts = pts, Cum = cum, Origin = origin.Position })
			origin = TrackBuilder.EndCFrame(layout, origin)
		end
	end
	return chainLines
end

-- First t >= 0 where the ray c + dir * t (dir a unit Vector2) comes within `radius` of the piece a-b (a capsule), or
-- math.huge
local function rayHit(c, dir, a, b, radius)
	local best = math.huge
	for _, q in { a, b } do -- the end caps
		local m = c - q
		local bq, cq = m:Dot(dir), m:Dot(m) - radius * radius
		if cq <= 0 then
			return 0
		end
		local disc = bq * bq - cq
		if disc >= 0 and -bq - math.sqrt(disc) >= 0 then
			best = math.min(best, -bq - math.sqrt(disc))
		end
	end
	local ab = b - a
	local len = ab.Magnitude
	if len > 1e-6 then -- the band along the piece
		local e = ab / len
		local g0 = (c - a).X * e.Y - (c - a).Y * e.X
		local kk = dir.X * e.Y - dir.Y * e.X
		if math.abs(kk) > 1e-9 then
			local t1, t2 = (-radius - g0) / kk, (radius - g0) / kk
			local tE = math.max(0, math.min(t1, t2))
			if tE <= math.max(t1, t2) then
				local along = (c + dir * tE - a):Dot(e)
				if along >= 0 and along <= len then
					best = math.min(best, tE)
				end
			end
		end
	end
	return best
end

-- The bays at track position s: extra depth left and right (nil where none) and the inner height
local function baysAt(def, s, total)
	local dL, dR, h = nil, nil, def.Height or 20
	for _, bay in def.Bays or {} do
		if s >= (bay.From or 0) * total and s < (bay.To or 1) * total then
			local side = bay.Side or "Both"
			if side ~= "Right" then
				dL = math.max(dL or 0, bay.Depth or 0)
			end
			if side ~= "Left" then
				dR = math.max(dR or 0, bay.Depth or 0)
			end
			h = math.max(h, bay.Height or h)
		end
	end
	return dL, dR, h
end

local profiles = setmetatable({}, { __mode = "k" })
-- Per-side widths every STEP studs from the tunnel start to its end (memoised per layout): Main (L, R) is the inner
-- half-width outside a bay, Room (L, R) the most any wall may reach there (also inside a bay), MinRoom (L, R) the raw
-- room before the taper (the harness reports crossings from it), Edge the bay platform's road-side edge.
function Tunnel.Profile(layout, origin, def)
	local memo = profiles[layout]
	if memo and memo.Def == def and memo.Origin == origin then
		return memo
	end
	local s0, s1 = Tunnel.Span(layout)
	local wps = layout.Waypoints
	local pts, cum = table.create(#wps), table.create(#wps)
	for k, p in wps do
		local w = origin:PointToWorldSpace(p)
		pts[k] = Vector2.new(w.X, w.Z)
		cum[k] = k == 1 and 0 or cum[k - 1] + Vector2.new(p.X - wps[k - 1].X, p.Z - wps[k - 1].Z).Magnitude
	end
	local half = (def.Width or 60) / 2
	local deepest = 0
	for _, bay in def.Bays or {} do
		deepest = math.max(deepest, bay.Depth or 0)
	end
	local W, MG, RM = Tunnel.WALL, Tunnel.MARGIN, Tunnel.ROOM_MARGIN
	local reach = math.max(half, Tunnel.PLATFORM_EDGE + deepest) + W + MG + RM -- farthest box edge looked at
	local minHalf = layout.Width / 2 + 2 + CLEARANCE -- the road, its wall and the prop clearance
	-- every other track's centre-line pieces (and this track's own, flagged with their track positions) in 64-stud cells
	local GRID, cells = 64, {}
	local function put(a, b, self, sa, sb)
		local lo, hi = a:Min(b), a:Max(b)
		for i = math.floor(lo.X / GRID), math.floor(hi.X / GRID) do
			for j = math.floor(lo.Y / GRID), math.floor(hi.Y / GRID) do
				local key = i * 65536 + j
				cells[key] = cells[key] or {}
				table.insert(cells[key], { a, b, self, sa, sb })
			end
		end
	end
	local start = origin.Position
	for _, line in chain() do
		local self = (line.Origin - start).Magnitude < 0.5 and #line.Pts == #pts
		for k = 2, #line.Pts do
			put(line.Pts[k - 1], line.Pts[k], self, line.Cum[k - 1], line.Cum[k])
		end
	end
	local n = math.max(1, math.ceil((s1 - s0) / Tunnel.STEP))
	local raw = { L = table.create(n + 1), R = table.create(n + 1) }
	local k = 1
	for i = 0, n do
		local s = s0 + (s1 - s0) * i / n
		while k < #wps - 1 and cum[k + 1] < s do
			k += 1
		end
		local u = math.clamp((s - cum[k]) / math.max(1e-6, cum[k + 1] - cum[k]), 0, 1)
		local c = pts[k]:Lerp(pts[k + 1], u)
		local d = pts[k + 1] - pts[k]
		local f = d.Magnitude > 1e-6 and d.Unit or Vector2.new(0, -1)
		local right = Vector2.new(-f.Y, f.X) -- the segment frame's +X (rightVec = (-f.Z, 0, f.X))
		local near = {}
		local r = reach + Tunnel.CORRIDOR + half + Tunnel.STEP
		for gi = math.floor((c.X - r) / GRID), math.floor((c.X + r) / GRID) do
			for gj = math.floor((c.Y - r) / GRID), math.floor((c.Y + r) / GRID) do
				for _, piece in cells[gi * 65536 + gj] or {} do
					-- own pieces count only far along the road; a far lap gets a whole tunnel's width (half + W +
					-- MARGIN) instead of a corridor, so two laps' boxes never meet
					if not piece[3] then
						near[piece] = Tunnel.CORRIDOR
					elseif math.min(math.abs(piece[4] - s), math.abs(piece[5] - s)) > Tunnel.SELF_GAP then
						near[piece] = half + W + MG
					end
				end
			end
		end
		for _, side in { -1, 1 } do
			local dir = right * side
			local hit = reach
			for piece, radius in near do
				hit = math.min(hit, rayHit(c, dir, piece[1], piece[2], radius))
			end
			-- hit: the box may reach this far; the inner wall stands W + MARGIN + ROOM_MARGIN inside it
			raw[side < 0 and "L" or "R"][i + 1] = hit >= reach and math.huge or hit - W - MG - RM
		end
	end
	-- the taper: the lower envelope of cones of slope TAPER, so the room never exceeds raw and never steps
	local drop = Tunnel.TAPER * (s1 - s0) / n
	local room = {}
	for key, list in raw do
		local e = table.clone(list)
		for i = 2, #e do
			e[i] = math.min(e[i], e[i - 1] + drop)
		end
		for i = #e - 1, 1, -1 do
			e[i] = math.min(e[i], e[i + 1] + drop)
		end
		room[key] = e
	end
	local main = { L = table.create(n + 1), R = table.create(n + 1) }
	for key, e in room do
		for i, v in e do
			e[i] = math.max(minHalf, v)
			main[key][i] = math.min(half, e[i])
		end
	end
	memo = {
		Def = def,
		Origin = origin,
		S0 = s0,
		S1 = s1,
		N = n,
		Main = main,
		Room = room,
		Raw = raw,
		Edge = Tunnel.PLATFORM_EDGE,
	}
	profiles[layout] = memo
	return memo
end

-- Station index (0-based, fractional) of track position s in profile `prof`
local function station(prof, s)
	return math.clamp((s - prof.S0) / (prof.S1 - prof.S0), 0, 1) * prof.N
end

-- The inner half-width at station i (integer, 0-based) on `key` ("L" / "R") with bay depth `depth` (nil: no bay):
-- the main width, or a bay wall at Edge + depth where the room allows (never narrower than the main width)
local function widthAt(prof, key, i, depth)
	local m = prof.Main[key][i + 1]
	return depth and math.max(m, math.min(prof.Edge + depth, prof.Room[key][i + 1])) or m
end

-- Inner half-widths left and right at track position s with the given bay depths (linear between stations)
local function widths(def, prof, s, dL, dR)
	if not prof then
		local half = (def.Width or 60) / 2
		return half + (dL or 0), half + (dR or 0)
	end
	local x = station(prof, s)
	local i = math.min(math.floor(x), prof.N - 1)
	local u = x - i
	local function at(key, depth)
		local a, b = widthAt(prof, key, i, depth), widthAt(prof, key, i + 1, depth)
		return a + (b - a) * u
	end
	return at("L", dL), at("R", dR)
end

-- Cross section at track position s: left and right inner half-widths, inner height and the bay sides there.
-- `prof`: Tunnel.Profile (nil: the fixed Width, as before fw8).
local function section(def, s, total, prof)
	local dL, dR, h = baysAt(def, s, total)
	local left, right = widths(def, prof, s, dL, dR)
	return left, right, h, dL ~= nil, dR ~= nil
end
Tunnel.Section = section -- BiomeDressing places props inside the walls and on the bay platforms from it

-- The bay platform's road-side edge (Width / 2 without a profile, as before fw8)
function Tunnel.Edge(def, prof)
	return prof and prof.Edge or (def.Width or 60) / 2
end

-- The road centre line as long straight chords: consecutive waypoints merge while every one in between stays within
-- CHORD_XZ studs (sideways) and CHORD_Y studs (up) of the chord, so a bend or a ramp costs a few parts, not one per
-- road piece. Returns { A, B (world, road top), SA, SB (track positions) }.
Tunnel.CHORD_XZ = 1 -- placeholder
Tunnel.CHORD_Y = 0.25 -- placeholder
Tunnel.CHORD_MAX = 1024 -- studs: half the largest part
local function chords(layout, origin)
	local wps = layout.Waypoints
	local pts, cum = table.create(#wps), table.create(#wps)
	for k, p in wps do
		pts[k] = origin:PointToWorldSpace(p)
		cum[k] = k == 1 and 0 or cum[k - 1] + Vector2.new(p.X - wps[k - 1].X, p.Z - wps[k - 1].Z).Magnitude
	end
	local function fits(i, j)
		local a, b = pts[i], pts[j]
		local len = cum[j] - cum[i]
		if len > Tunnel.CHORD_MAX then
			return false
		end
		local d = Vector2.new(b.X - a.X, b.Z - a.Z)
		local unit = d.Magnitude > 1e-6 and d.Unit or Vector2.new(0, 0)
		for k = i + 1, j - 1 do
			local q = Vector2.new(pts[k].X - a.X, pts[k].Z - a.Z)
			local side = math.abs(q.X * unit.Y - q.Y * unit.X)
			local t = len > 0 and (cum[k] - cum[i]) / len or 0
			if side > Tunnel.CHORD_XZ or math.abs(pts[k].Y - (a.Y + (b.Y - a.Y) * t)) > Tunnel.CHORD_Y then
				return false
			end
		end
		return true
	end
	local out, i = {}, 1
	while i < #pts do
		local j = i + 1
		while j < #pts and fits(i, j + 1) do
			j += 1
		end
		if cum[j] - cum[i] > 1e-3 then
			table.insert(out, { A = pts[i], B = pts[j], SA = cum[i], SB = cum[j] })
		end
		i = j
	end
	return out
end

-- The tunnel as straight segments in world space, in track order. Each: CFrame (road top centre, facing along the
-- road with its pitch), Length (along it), Flat (XZ studs per stud of Length), From / To (track positions), Left /
-- Right / Height (inner cross section; Left / Right the wider end), LeftA / LeftB / RightA / RightB (the inner
-- half-widths at From and To: the walls run straight between them), BayLeft / BayRight, and TanStart / TanEnd (tan of
-- half the bend between chords at a chord end, 0 at a cut inside a chord) so parts can be lengthened to close the gaps
-- between chords. A segment's ends differ by at most TAPER x STEP studs (fw8: every width station where the width
-- changes is a cut). A Loop segment inside the span is not supported. Also returns the Profile.
function Tunnel.Segments(layout, origin, def)
	local s0, s1, total = Tunnel.Span(layout)
	local prof = Tunnel.Profile(layout, origin, def)
	local list = chords(layout, origin)
	local cuts = { s0, s1 }
	for _, bay in def.Bays or {} do
		table.insert(cuts, (bay.From or 0) * total)
		table.insert(cuts, (bay.To or 1) * total)
	end
	-- a station where either wall (with the bay state there) changes on either side of it
	for i = 1, prof.N - 1 do
		local s = s0 + (s1 - s0) * i / prof.N
		local dL, dR = baysAt(def, s, total)
		for _, w in { { "L", dL }, { "R", dR } } do
			local a, b, c =
				widthAt(prof, w[1], i - 1, w[2]), widthAt(prof, w[1], i, w[2]), widthAt(prof, w[1], i + 1, w[2])
			if math.abs(a - b) > 1e-3 or math.abs(c - b) > 1e-3 then
				table.insert(cuts, s)
				break
			end
		end
	end
	-- tan of half the angle between two chords (a bend or a crest), capped at 60 degrees
	local function tanHalf(a, b)
		local dot = math.clamp((a.B - a.A).Unit:Dot((b.B - b.A).Unit), -1, 1)
		return math.tan(math.min(math.acos(dot), math.pi / 3) / 2)
	end
	local out = {}
	for k, c in list do
		local u0, v0 = math.max(c.SA, s0), math.min(c.SB, s1)
		if v0 - u0 > 0.05 then
			local points = { u0, v0 }
			for _, cut in cuts do
				if cut > u0 + 0.05 and cut < v0 - 0.05 then
					table.insert(points, cut)
				end
			end
			table.sort(points)
			local d = c.B - c.A
			local flat = Vector2.new(d.X, d.Z).Magnitude / d.Magnitude
			-- the frame from its axes: Lune's CFrame.lookAt (the offline harness) mirrors Z
			local f = d.Unit
			local rightVec = Vector3.new(-f.Z, 0, f.X).Unit
			local function at(s)
				return c.A + d * ((s - c.SA) / (c.SB - c.SA))
			end
			for i = 1, #points - 1 do
				local u, v = points[i], points[i + 1]
				local m = (u + v) / 2
				local dL, dR, h = baysAt(def, m, total)
				local lA, rA = widths(def, prof, u, dL, dR)
				local lB, rB = widths(def, prof, v, dL, dR)
				local p = at(m)
				table.insert(out, {
					CFrame = CFrame.fromMatrix(p, rightVec, rightVec:Cross(f)),
					Length = (at(v) - at(u)).Magnitude,
					Flat = flat,
					From = u,
					To = v,
					Left = math.max(lA, lB),
					Right = math.max(rA, rB),
					LeftA = lA,
					LeftB = lB,
					RightA = rA,
					RightB = rB,
					Height = h,
					BayLeft = dL ~= nil,
					BayRight = dR ~= nil,
					TanStart = u == c.SA and k > 1 and tanHalf(c, list[k - 1]) or 0,
					TanEnd = v == c.SB and k < #list and tanHalf(c, list[k + 1]) or 0,
				})
			end
		end
	end
	return out, s0, s1, total, prof
end

local function newPart(folder, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- A part along segment `seg` spanning x0..x1 (piece-local, +X right), y0..y1 (above road top), lengthened at the
-- segment's chord ends by (`reach` + its height) x tan(half the bend) so neighbouring chords meet on a bend or crest.
-- `dx` (fw8, optional): the part runs from x - dx / 2 at the segment's start to x + dx / 2 at its end (a tapered wall;
-- x0..x1 is its span at the middle), turned about its centre.
local function along(folder, name, seg, x0, x1, y0, y1, reach, color, material, dx)
	reach += math.max(math.abs(y0), math.abs(y1))
	local eS, eE = reach * seg.TanStart, reach * seg.TanEnd
	local length = seg.Length + eS + eE
	local turn = dx and -math.atan2(dx, seg.Length) or 0
	return newPart(
		folder,
		name,
		Vector3.new(x1 - x0, y1 - y0, length / math.cos(turn)),
		seg.CFrame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, -(eE - eS) / 2) * CFrame.Angles(0, turn, 0),
		color,
		material
	)
end

-- Places the tunnel of a track whose biome has a Tunnel field under model.Tunnel (a Folder tagged Tunnel).
-- Returns the folder and its part count, or nil when the biome has no tunnel.
function Tunnel.Build(model, layout, theme, origin)
	local def = theme and theme.Tunnel
	if not def then
		return nil, 0
	end
	local segs, s0, s1, total, prof = Tunnel.Segments(layout, origin, def)
	local folder = Instance.new("Folder")
	folder.Name = "Tunnel"
	folder.Parent = model
	CollectionService:AddTag(folder, Tunnel.TAG)
	local wall, ceil, floor = def.Wall or {}, def.Ceiling or {}, def.Floor
	local M = Enum.Material
	local wallMat, wallCol = wall.Material or M.Concrete, colour(wall.Color, Color3.fromRGB(200, 200, 200))
	local ceilMat, ceilCol = ceil.Material or M.Concrete, colour(ceil.Color, Color3.fromRGB(140, 138, 132))
	local stripe = wall.Stripe and colour(wall.Stripe)
	local W, C, R, P = Tunnel.WALL, Tunnel.CEILING, Tunnel.ROAD, Tunnel.PLATFORM
	for i, seg in segs do
		local l, r, h = seg.Left, seg.Right, seg.Height
		-- fw8: each wall runs straight from its width at From to its width at To
		local lm, rm, dl, dr =
			(seg.LeftA + seg.LeftB) / 2, (seg.RightA + seg.RightB) / 2, seg.LeftA - seg.LeftB, seg.RightB - seg.RightA
		along(folder, "WallL" .. i, seg, -lm - W, -lm, -R, h + C, l + W, wallCol, wallMat, dl)
		along(folder, "WallR" .. i, seg, rm, rm + W, -R, h + C, r + W, wallCol, wallMat, dr)
		along(folder, "Ceiling" .. i, seg, -l - W, r + W, h, h + C, math.max(l, r) + W, ceilCol, ceilMat)
		if floor then
			-- under the road top by more than CHORD_Y, so the road always shows on it
			along(
				folder,
				"Floor" .. i,
				seg,
				-l,
				r,
				-0.4 - R,
				-0.4,
				math.max(l, r),
				colour(floor.Color, ceilCol),
				floor.Material or M.Concrete
			)
		end
		if stripe then
			local y = math.min(4, h / 2) -- placeholder: a band at eye height of the runners
			for _, at in { { -lm + 0.1, dl }, { rm - 0.1, dr } } do
				local x = at[1]
				local band = along(
					folder,
					"Stripe" .. i,
					seg,
					x - 0.1,
					x + 0.1,
					y,
					y + 1.5,
					math.abs(x),
					stripe,
					M.SmoothPlastic,
					at[2]
				)
				band.CanCollide, band.CanQuery, band.CanTouch = false, false, false
			end
		end
		local half = Tunnel.Edge(def, prof) -- the platform's road-side edge
		if seg.BayLeft then
			along(folder, "PlatformL" .. i, seg, -l, -half, -R, P, l, wallCol, wallMat)
		end
		if seg.BayRight then
			along(folder, "PlatformR" .. i, seg, half, r, -R, P, r, wallCol, wallMat)
		end
		-- a step in the cross section (a bay starts or ends): cap the difference on the narrower side
		local nxt = segs[i + 1]
		if nxt and math.abs(nxt.From - seg.To) < 0.1 then
			local endCF = seg.CFrame * CFrame.new(0, 0, -seg.Length / 2)
			l, r = seg.LeftB, seg.RightB -- the step is between this end and the next start
			local nl, nr, nh = nxt.LeftA, nxt.RightA, nxt.Height
			local function cap(name, x0, x1, y0, y1, narrowIsThis)
				if x1 - x0 > 0.05 and y1 - y0 > 0.05 then
					local z = narrowIsThis and W / 2 or -W / 2
					newPart(
						folder,
						name,
						Vector3.new(x1 - x0, y1 - y0, W),
						endCF * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, z),
						wallCol,
						wallMat
					)
				end
			end
			local top = math.max(h, nh) + C
			cap("CapL" .. i, -math.max(l, nl) - W, -math.min(l, nl), -R, top, l < nl)
			cap("CapR" .. i, math.min(r, nr), math.max(r, nr) + W, -R, top, r < nr)
			cap("CapTop" .. i, -math.min(l, nl) - W, math.min(r, nr) + W, math.min(h, nh) + C, top, h < nh)
		end
	end
	-- Ceiling light strips every LightEvery studs (spec 3.5: Shadows off; the client halves them under REDUCED
	-- EFFECTS and flickers a few)
	local every = def.LightEvery or 24
	local lightCol = Tunnel.LIGHT.Color
	local index, k, row = 0, 1, 0
	for s = s0 + every / 2, s1 - every / 2, every do
		while segs[k] and segs[k].To < s do
			k += 1
		end
		local seg = segs[k]
		if seg then
			index += 1
			local cf = seg.CFrame
				* CFrame.new(0, seg.Height - Tunnel.LIGHT.Size.Y / 2, -(s - (seg.From + seg.To) / 2) / seg.Flat)
			local strip = newPart(folder, "Light" .. index, Tunnel.LIGHT.Size, cf, lightCol, M.Neon)
			strip.CanCollide, strip.CanTouch = false, false
			strip.CastShadow = false
			strip:SetAttribute("Index", index)
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = Tunnel.LIGHT.Range
			light.Brightness = Tunnel.LIGHT.Brightness
			light.Angle = Tunnel.LIGHT.Angle
			light.Color = lightCol
			light.Shadows = false
			light.Parent = strip
			CollectionService:AddTag(strip, Tunnel.LIGHT_TAG)
			-- fw8: on every SIDE_LIGHTS-th strip, one more strip over the middle of each wide side
			row += 1
			if row % Tunnel.SIDE_LIGHTS == 0 then
				local l, r = section(def, s, total, prof)
				for _, x in { -l / 2, r / 2 } do
					if math.abs(x) * 2 >= Tunnel.SIDE_LIGHT_HALF then
						index += 1
						local side = strip:Clone()
						side.Name = "Light" .. index
						side.CFrame = cf * CFrame.new(x, 0, 0)
						side:SetAttribute("Index", index)
						side.Parent = folder
						CollectionService:AddTag(side, Tunnel.LIGHT_TAG)
					end
				end
			end
		end
	end
	-- Portals: a facade block round each opening, as deep as PORTAL and as wide and high as the earth over the
	-- tunnel, so the cut face of the terrain (it starts PORTAL / 2 inside) never shows
	if def.Portals ~= false and #segs > 0 then
		for _, at in { { segs[1], 1 }, { segs[#segs], -1 } } do
			local seg, dir = at[1], at[2]
			local flatCF = CFrame.new(seg.CFrame.Position) * CFrame.Angles(0, select(2, seg.CFrame:ToOrientation()), 0)
			-- the opening's face, then PORTAL / 2 into the tunnel
			local face = flatCF * CFrame.new(0, 0, dir * seg.Length / 2 * seg.Flat)
			local mid = face * CFrame.new(0, 0, -dir * Tunnel.PORTAL / 2)
			local l, r, h = seg.LeftA, seg.RightA, seg.Height
			if dir < 0 then
				l, r = seg.LeftB, seg.RightB
			end
			local side = Tunnel.MARGIN + Tunnel.BLEND
			local top = h + C + Tunnel.MARGIN + Tunnel.COVER + 2
			local function block(name, x0, x1, y0, y1)
				newPart(
					folder,
					name,
					Vector3.new(x1 - x0, y1 - y0, Tunnel.PORTAL),
					mid * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0),
					ceilCol,
					ceilMat
				)
			end
			local tag = dir > 0 and "Start" or "Finish"
			block("Portal" .. tag .. "L", -l - W - side, -l - W, -R, top)
			block("Portal" .. tag .. "R", r + W, r + W + side, -R, top)
			block("Portal" .. tag .. "Top", -l - W, r + W, h + C, top)
		end
	end
	local count = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	folder:SetAttribute("From", s0)
	folder:SetAttribute("To", s1)
	folder:SetAttribute("Length", total)
	return folder, count
end

return Tunnel
