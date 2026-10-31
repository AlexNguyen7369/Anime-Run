--!nonstrict
-- The world's terrain shape, pure (docs/BIOME_ENVIRONMENT_SPEC.md sections 2.2, 2.3, 3.2, 3.3). No instances are
-- written: Prepare stamps every track centre line into a distance grid, and Height / Material / Zone read it with
-- each biome's Terrain profile (Shared/BiomeThemes/<Key>.Terrain). Same inputs give the same world.
-- Server/TerrainBuilder writes the voxels; BiomeDressing.SnapToTerrain drops props onto Height.
local Themes = require(script.Parent.BiomeThemes)

local TerrainShape = {}
TerrainShape.GROUND_TOP = -1 -- TrackBuilder GROUND_TOP: the corridor's flat top
TerrainShape.FLOOR = -24 -- placeholder: the terrain floor (deeper under Drop / Water ridges)
TerrainShape.CORRIDOR = 44 -- placeholder: W/2 + 24, flat
TerrainShape.SHOULDER = 60 -- placeholder: end of the shoulder rise
TerrainShape.MIDLINE = 77 -- placeholder: about the gap midline
TerrainShape.FAR_BLEND = 20 -- placeholder: studs past MIDLINE over which the last track's ridge turns into its Far shape
TerrainShape.SEAM = 32 -- placeholder: height blend band between zones
TerrainShape.CELL = 8 -- placeholder: grid cell (studs)
TerrainShape.STAMP = 120 -- placeholder: stamp radius (studs)
TerrainShape.COARSE = 64 -- studs per coarse cell for nodes past the stamp radius
TerrainShape.POLY_STEP = 64 -- placeholder: studs between ZonePolyline points
TerrainShape.PLAZA_MARGIN = 64 -- placeholder: zone 0 = plaza + Dojos + this
TerrainShape.SKIRT = 900 -- placeholder: terrain past the outermost road edge
TerrainShape.EMBANK_BELOW = 3 -- placeholder: an Embank corridor sits this far below the road
-- placeholder: an Embank corridor sits EMBANK_BELOW under the lowest road Y within this many studs (grid nodes of the
-- same track), so on a ramp it stays under the road at every point beside it, not only at the cell's own road point
TerrainShape.EMBANK_REACH = 24
TerrainShape.CRATER_TRIES = 4 -- placeholder: candidate spots per pit before a track gives up on it
TerrainShape.CLEARANCE = require(script.Parent.BiomeDressing).CLEARANCE -- clear boxes grow by this

local G = TerrainShape.GROUND_TOP
local M = Enum.Material
local DEFAULT_MATERIALS = { Corridor = M.Ground, Ridge = M.Grass, Cliff = M.Rock, Bed = M.Sand }
local DEFAULT_RIDGE = { Shape = "Hills", Height = 12 }
local FAR = 65535 -- u16 sentinel: not stamped
local NONE = 255 -- u8 sentinel: no track
local REC = 10 -- bytes per node: u8 t1, u8 t2, u16 d1*4, u16 d2*4, i16 roadY*8, u16 dc*4
-- Sections grid (only built when some biome has Sections), 4 bytes per node: u16 p1, u16 p2 for tracks t1, t2.
-- p = q * 2 + inner, q = the nearest centre-line point's length fraction * POS_Q; FAR when unknown (coarse nodes).
local POS_Q = 32766
local WATER_RIDGE = { Shape = "Water" } -- a section with Water but no Ridge dips into a basin, so the water shows

local state = nil -- set by Prepare
local sample -- grid lookup, defined below Prepare (which places craters with it)

local function clamp01(x)
	return x < 0 and 0 or x > 1 and 1 or x
end

local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

local function hash(x, z)
	local h = math.sin(x * 12.9898 + z * 78.233) * 43758.5453
	return h - math.floor(h)
end

local function q16(d)
	return math.min(FAR - 1, math.floor(d * 4 + 0.5))
end

-- Point to segment distance in XZ and the segment parameter
local function segment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = len2 > 0 and clamp01(((px - ax) * dx + (pz - az) * dz) / len2) or 0
	local ex, ez = px - (ax + dx * t), pz - (az + dz * t)
	return math.sqrt(ex * ex + ez * ez), t
end

-- Offers distance d of track n (road Y y) to node k: keeps the nearest and the nearest other track
-- (and its section position p into sec, when given)
local function offer(buf, k, n, d, y, sec, p)
	local o = k * REC
	local qd = q16(d)
	local d1 = buffer.readu16(buf, o + 2)
	local function setFirst()
		buffer.writeu8(buf, o, n)
		buffer.writeu16(buf, o + 2, qd)
		buffer.writei16(buf, o + 6, math.clamp(math.floor(y * 8 + 0.5), -32768, 32767))
		if sec then
			buffer.writeu16(sec, k * 4, p)
		end
	end
	if buffer.readu8(buf, o) == n then
		if qd < d1 then
			setFirst()
		end
	elseif qd < d1 then
		buffer.writeu8(buf, o + 1, buffer.readu8(buf, o)) -- the old nearest becomes the second
		buffer.writeu16(buf, o + 4, d1)
		if sec then
			buffer.writeu16(sec, k * 4 + 2, buffer.readu16(sec, k * 4))
		end
		setFirst()
	elseif qd < buffer.readu16(buf, o + 4) then
		buffer.writeu8(buf, o + 1, n)
		buffer.writeu16(buf, o + 4, qd)
		if sec then
			buffer.writeu16(sec, k * 4 + 2, p)
		end
	end
end

-- XZ boxes { Min = Vector2, Max = Vector2 } from Instances (every BasePart's world box) or boxes as given
local function boxesOf(roots)
	local boxes = {}
	local function add(p)
		local cf, size = p.CFrame, p.Size
		local half = (cf.RightVector * size.X):Abs() / 2
			+ (cf.UpVector * size.Y):Abs() / 2
			+ (cf.LookVector * size.Z):Abs() / 2
		local c = cf.Position
		table.insert(
			boxes,
			{ Min = Vector2.new(c.X - half.X, c.Z - half.Z), Max = Vector2.new(c.X + half.X, c.Z + half.Z) }
		)
	end
	for _, root in roots or {} do
		if typeof(root) == "Instance" then
			if root:IsA("BasePart") then
				add(root)
			end
			for _, d in root:GetDescendants() do
				if d:IsA("BasePart") then
					add(d)
				end
			end
		elseif type(root) == "table" and root.Min then
			table.insert(boxes, root)
		end
	end
	return boxes
end

-- Track n's centre line resampled every POLY_STEP studs (XZ), first and last waypoints included
local function polyline(pts)
	local out = { Vector2.new(pts[1].X, pts[1].Z) }
	local carry = 0
	for k = 2, #pts do
		local a, b = Vector2.new(pts[k - 1].X, pts[k - 1].Z), Vector2.new(pts[k].X, pts[k].Z)
		local len = (b - a).Magnitude
		local s = TerrainShape.POLY_STEP - carry
		while s <= len do
			table.insert(out, a:Lerp(b, s / len))
			s += TerrainShape.POLY_STEP
		end
		carry = len - (s - TerrainShape.POLY_STEP)
	end
	local last = Vector2.new(pts[#pts].X, pts[#pts].Z)
	if (out[#out] - last).Magnitude > 1 then
		table.insert(out, last)
	end
	return out
end

-- entries: { Layout, Origin, Number, Biome } (Main.server's chain entries). clearRoots: Instances (checkpoints,
-- WinPads, the plaza...) or XZ boxes that get flat ground plus CLEARANCE. plazaRoots: the SpawnArea and Workshops
-- (also clear), which set PlazaRadius. Yields while it stamps.
function TerrainShape.Prepare(entries, clearRoots, plazaRoots)
	local CELL, STAMP = TerrainShape.CELL, TerrainShape.STAMP
	local tracks, biomes, last = {}, {}, 0
	local lo, hi = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	for _, e in entries do
		local pts = table.create(#e.Layout.Waypoints)
		for i, p in e.Layout.Waypoints do
			local w = e.Origin:PointToWorldSpace(p)
			pts[i] = w
			lo = Vector2.new(math.min(lo.X, w.X), math.min(lo.Y, w.Z))
			hi = Vector2.new(math.max(hi.X, w.X), math.max(hi.Y, w.Z))
		end
		tracks[e.Number] = pts
		biomes[e.Number] = e.Biome
		last = math.max(last, e.Number)
	end
	local x0 = math.floor((lo.X - STAMP - CELL) / CELL) * CELL
	local z0 = math.floor((lo.Y - STAMP - CELL) / CELL) * CELL
	local nx = math.ceil((hi.X + STAMP + CELL - x0) / CELL) + 1
	local nz = math.ceil((hi.Y + STAMP + CELL - z0) / CELL) + 1
	local buf = buffer.create(nx * nz * REC)
	buffer.fill(buf, 0, 255)
	local function node(i, j)
		return j * nx + i
	end
	local profiles = {}
	for n, key in biomes do
		local theme = Themes[key]
		profiles[n] = theme and theme.Terrain or {}
	end

	-- Sections (spec 3.3): per track its XZ length, and which side of the centre line is Inner (toward the plaza at
	-- the world origin). Inner is fixed per track by its winding around the origin: the sum of cross(a, b) over its
	-- segments is twice the signed area it sweeps, and the origin lies on the side of travel that sign points to,
	-- so a point is Inner when cross(b - a, p - a) has the same sign. One rule per track never flips on a radial
	-- or wiggly stretch, as a per-segment "direction to origin" test would.
	local sec, sections, lengths, cum, wind = nil, {}, {}, {}, {}
	for n, prof in profiles do
		if prof.Sections and tracks[n] then
			local pts, c, area = tracks[n], { 0 }, 0
			for k = 2, #pts do
				local a, b = pts[k - 1], pts[k]
				c[k] = c[k - 1] + Vector2.new(b.X - a.X, b.Z - a.Z).Magnitude
				area += a.X * b.Z - a.Z * b.X
			end
			cum[n], lengths[n], wind[n] = c, math.max(c[#pts], 1), area >= 0 and 1 or -1
			sections[n] = {}
			for _, def in prof.Sections do
				table.insert(sections[n], {
					From = (def.From or 0) * lengths[n],
					To = (def.To or 1) * lengths[n],
					Side = def.Side or "Both",
					Ridge = def.Ridge or (def.Water and WATER_RIDGE) or nil,
					Water = def.Water,
					Material = def.Material,
					Prof = { Water = def.Water or prof.Water }, -- what shapeY reads for the water level
				})
			end
			if not sec then
				sec = buffer.create(nx * nz * 4)
				buffer.fill(sec, 0, 255)
			end
		end
	end

	-- 1. Stamp every segment within STAMP studs
	local work = 0
	for n, pts in tracks do
		for k = 2, #pts do
			local a, b = pts[k - 1], pts[k]
			local i0 = math.max(0, math.floor((math.min(a.X, b.X) - STAMP - x0) / CELL))
			local i1 = math.min(nx - 1, math.ceil((math.max(a.X, b.X) + STAMP - x0) / CELL))
			local j0 = math.max(0, math.floor((math.min(a.Z, b.Z) - STAMP - z0) / CELL))
			local j1 = math.min(nz - 1, math.ceil((math.max(a.Z, b.Z) + STAMP - z0) / CELL))
			for j = j0, j1 do
				local pz = z0 + j * CELL
				for i = i0, i1 do
					local px = x0 + i * CELL
					local d, t = segment(px, pz, a.X, a.Z, b.X, b.Z)
					if d <= STAMP then
						local p = FAR
						if cum[n] then
							local c = cum[n]
							local q = math.floor((c[k - 1] + (c[k] - c[k - 1]) * t) / lengths[n] * POS_Q + 0.5)
							local cross = (b.X - a.X) * (pz - a.Z) - (b.Z - a.Z) * (px - a.X)
							p = q * 2 + (cross * wind[n] > 0 and 1 or 0)
						end
						offer(buf, node(i, j), n, d, a.Y + (b.Y - a.Y) * t, sec, p)
					end
				end
			end
			work += 1
			if work % 300 == 0 then
				task.wait()
			end
		end
	end

	-- 2. Coarse pass: nodes past the stamp take the nearest polyline points of a COARSE cell
	local polys = {}
	for n, pts in tracks do
		polys[n] = polyline(pts)
	end
	local coarse = {}
	local per = TerrainShape.COARSE // CELL
	for j = 0, nz - 1 do
		for i = 0, nx - 1 do
			local k = node(i, j)
			if buffer.readu8(buf, k * REC) == NONE then
				local key = (j // per) * 100000 + i // per
				local c = coarse[key]
				if not c then
					local cx = x0 + ((i // per) + 0.5) * TerrainShape.COARSE
					local cz = z0 + ((j // per) + 0.5) * TerrainShape.COARSE
					local best = {}
					for n, poly in polys do
						local m = math.huge
						for _, p in poly do
							local dx, dz = p.X - cx, p.Y - cz
							m = math.min(m, dx * dx + dz * dz)
						end
						best[n] = math.sqrt(m)
					end
					c = { NONE, FAR, NONE, FAR }
					for n, d in best do
						if d < c[2] then
							c[3], c[4], c[1], c[2] = c[1], c[2], n, d
						elseif d < c[4] then
							c[3], c[4] = n, d
						end
					end
					coarse[key] = c
					work += 1
					if work % 300 == 0 then
						task.wait()
					end
				end
				local o = k * REC
				buffer.writeu8(buf, o, c[1])
				buffer.writeu16(buf, o + 2, q16(math.max(STAMP, c[2])))
				buffer.writeu8(buf, o + 1, c[3])
				buffer.writeu16(buf, o + 4, q16(math.max(STAMP, c[4])))
				buffer.writei16(buf, o + 6, 8 * 1)
			end
		end
	end

	-- 2b. Embank road Y (only when a biome embanks): each node's lowest road Y over the nodes of its own track within
	-- EMBANK_REACH, as two separable min passes (along x, then along z)
	local low = nil
	for _, prof in profiles do
		if prof.Embank then
			low = buffer.create(nx * nz * 2)
			break
		end
	end
	if low then
		local r = math.ceil(TerrainShape.EMBANK_REACH / CELL)
		local pass = buffer.create(nx * nz * 2)
		for j = 0, nz - 1 do
			for i = 0, nx - 1 do
				local k = node(i, j)
				local t, m = buffer.readu8(buf, k * REC), buffer.readi16(buf, k * REC + 6)
				for ii = math.max(0, i - r), math.min(nx - 1, i + r) do
					local o = node(ii, j) * REC
					if buffer.readu8(buf, o) == t then
						m = math.min(m, buffer.readi16(buf, o + 6))
					end
				end
				buffer.writei16(pass, k * 2, m)
			end
			if j % 64 == 0 then
				task.wait()
			end
		end
		for j = 0, nz - 1 do
			for i = 0, nx - 1 do
				local k = node(i, j)
				local t, m = buffer.readu8(buf, k * REC), buffer.readi16(pass, k * 2)
				for jj = math.max(0, j - r), math.min(nz - 1, j + r) do
					local kk = node(i, jj)
					if buffer.readu8(buf, kk * REC) == t then
						m = math.min(m, buffer.readi16(pass, kk * 2))
					end
				end
				buffer.writei16(low, k * 2, m)
			end
			if j % 64 == 0 then
				task.wait()
			end
		end
	end

	-- 3. Clear boxes: distance to the nearest grown box, out to the shoulder width
	local plaza = boxesOf(plazaRoots)
	local clear = boxesOf(clearRoots)
	for _, b in plaza do
		table.insert(clear, b)
	end
	local grow = TerrainShape.CLEARANCE
	local reach = TerrainShape.SHOULDER - TerrainShape.CORRIDOR
	for bi, b in clear do
		local bl, bh = b.Min - Vector2.one * grow, b.Max + Vector2.one * grow
		local i0 = math.max(0, math.floor((bl.X - reach - x0) / CELL))
		local i1 = math.min(nx - 1, math.ceil((bh.X + reach - x0) / CELL))
		local j0 = math.max(0, math.floor((bl.Y - reach - z0) / CELL))
		local j1 = math.min(nz - 1, math.ceil((bh.Y + reach - z0) / CELL))
		for j = j0, j1 do
			local pz = z0 + j * CELL
			local ez = math.max(bl.Y - pz, 0, pz - bh.Y)
			for i = i0, i1 do
				local px = x0 + i * CELL
				local ex = math.max(bl.X - px, 0, px - bh.X)
				local o = node(i, j) * REC + 8
				local q = q16(math.sqrt(ex * ex + ez * ez))
				if q < buffer.readu16(buf, o) then
					buffer.writeu16(buf, o, q)
				end
			end
		end
		if bi % 500 == 0 then
			task.wait()
		end
	end

	local radius = 0
	for _, b in plaza do
		for _, p in { b.Min, b.Max, Vector2.new(b.Min.X, b.Max.Y), Vector2.new(b.Max.X, b.Min.Y) } do
			radius = math.max(radius, p.Magnitude)
		end
	end
	state = {
		Buf = buf,
		Low = low,
		Sec = sec,
		Sections = sections,
		Pits = {},
		X0 = x0,
		Z0 = z0,
		NX = nx,
		NZ = nz,
		Last = last,
		Polys = polys,
		Lengths = lengths,
		Profiles = profiles,
		PlazaRadius = #plaza > 0 and radius + TerrainShape.PLAZA_MARGIN or 0,
		-- the world box: every centre line plus the road half-width and the skirt
		Box = {
			Min = lo - Vector2.one * (20 + TerrainShape.SKIRT),
			Max = hi + Vector2.one * (20 + TerrainShape.SKIRT),
		},
	}
	-- 4. Craters (spec 3.3): pit centres on random polyline points, pushed sideways into the ridge band. A spot is
	-- kept only when the grid says it is track n's own ridge, so a hairpin or a neighbour's road never gets one.
	for n, prof in profiles do
		local cr = prof.Craters
		local poly = polys[n]
		if cr and poly and #poly >= 2 then
			local S, MID = TerrainShape.SHOULDER, TerrainShape.MIDLINE
			local pits = {}
			local tries = 0
			while #pits < (cr.Count or 12) and tries < (cr.Count or 12) * TerrainShape.CRATER_TRIES do
				tries += 1
				local k = math.clamp(1 + math.floor(hash(n * 7.31, tries * 1.17) * #poly), 1, #poly)
				local a, b = poly[math.max(1, k - 1)], poly[math.min(#poly, k + 1)]
				local dir = (b - a).Unit
				local side = hash(tries * 3.7, n * 0.53) < 0.5 and -1 or 1
				local c = poly[k] + Vector2.new(-dir.Y, dir.X) * side * (S + hash(n * 1.9, tries * 5.3) * (MID - S))
				local A, dA = sample(c.X, c.Y)
				if A == n and dA >= S then
					table.insert(pits, c)
				end
			end
			state.Pits[n] = { Centres = pits, Radius = cr.Radius or 40, Depth = cr.Depth or 8 }
		end
	end
end

-- Levels a pad at height y under the oriented box (cf, size), grown by CLEARANCE and blended out over the shoulder
-- width (spec 3.2: a pinned hero). The pad fades to nothing at the corridor edge, so it never moves road or clear-box
-- ground. Call after Prepare and before the terrain is built.
function TerrainShape.AddPad(cf, size, y)
	local half = (cf.RightVector * size.X):Abs() / 2 + (cf.LookVector * size.Z):Abs() / 2
	local g = Vector2.one * TerrainShape.CLEARANCE
	local c = Vector2.new(cf.Position.X, cf.Position.Z)
	state.Pads = state.Pads or {}
	table.insert(
		state.Pads,
		{ Min = c - Vector2.new(half.X, half.Z) - g, Max = c + Vector2.new(half.X, half.Z) + g, Y = y }
	)
end

function TerrainShape.Ready()
	return state ~= nil
end

function TerrainShape.PlazaRadius()
	return state and state.PlazaRadius or 0
end

-- The world box { Min, Max } (Vector2 XZ) the terrain covers
function TerrainShape.Box()
	return state and state.Box
end

-- "x,z;x,z;..." of track n's centre line, one point per POLY_STEP studs (published as BiomeZone_<n>)
function TerrainShape.ZonePolyline(n)
	local poly = state and state.Polys[n]
	if not poly then
		return nil
	end
	local parts = table.create(#poly)
	for i, p in poly do
		parts[i] = string.format("%.1f,%.1f", p.X, p.Y)
	end
	return table.concat(parts, ";")
end

function TerrainShape.Profile(n)
	return state and state.Profiles[n] or {}
end

-- Distance of track n at the node at byte offset o, or nil when the node keeps neither of its two tracks as n
local function distOf(buf, o, n)
	if buffer.readu8(buf, o) == n then
		return buffer.readu16(buf, o + 2) / 4
	elseif buffer.readu8(buf, o + 1) == n then
		return buffer.readu16(buf, o + 4) / 4
	end
	return nil
end

-- m, lowered to the embank road Y of the node at byte offset o when that node's nearest track is A
local function lowAt(buf, low, o, A, m)
	return buffer.readu8(buf, o) == A and math.min(m, buffer.readi16(low, o // REC * 2)) or m
end

local function bilinear(a, b, c, d, u, v)
	return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v
end

-- Nearest track A, its distance, second track B (or nil), its distance, road Y and clear-box distance at (x, z),
-- bilinear between nodes where all four corners know the track (the nearest node's values otherwise). When a biome
-- embanks, road Y is the embank road Y instead (the low over EMBANK_REACH; road Y is only read by Embank).
function sample(x, z)
	local CELL, buf = TerrainShape.CELL, state.Buf
	local fx, fz = (x - state.X0) / CELL, (z - state.Z0) / CELL
	if fx < 0 or fz < 0 or fx > state.NX - 1 or fz > state.NZ - 1 then
		local ex = math.max(-fx, 0, fx - (state.NX - 1)) * CELL
		local ez = math.max(-fz, 0, fz - (state.NZ - 1)) * CELL
		-- past the grid: the nearest edge node's track, farther by the distance to the grid
		local o = (math.clamp(math.round(fz), 0, state.NZ - 1) * state.NX + math.clamp(math.round(fx), 0, state.NX - 1))
			* REC
		local d = buffer.readu16(buf, o + 2) / 4 + math.sqrt(ex * ex + ez * ez)
		return buffer.readu8(buf, o), d, nil, math.huge, 1, math.huge
	end
	local i, j = math.min(math.floor(fx), state.NX - 2), math.min(math.floor(fz), state.NZ - 2)
	local u, v = fx - i, fz - j
	local o00 = (j * state.NX + i) * REC
	local o10, o01, o11 = o00 + REC, o00 + state.NX * REC, o00 + (state.NX + 1) * REC
	local near = v < 0.5 and (u < 0.5 and o00 or o10) or (u < 0.5 and o01 or o11)
	local A, B = buffer.readu8(buf, near), buffer.readu8(buf, near + 1)
	local a, b, c, d = distOf(buf, o00, A), distOf(buf, o10, A), distOf(buf, o01, A), distOf(buf, o11, A)
	local dA = (a and b and c and d) and bilinear(a, b, c, d, u, v) or buffer.readu16(buf, near + 2) / 4
	local dB = math.huge
	if B ~= NONE then
		a, b, c, d = distOf(buf, o00, B), distOf(buf, o10, B), distOf(buf, o01, B), distOf(buf, o11, B)
		dB = (a and b and c and d) and bilinear(a, b, c, d, u, v) or buffer.readu16(buf, near + 4) / 4
	end
	local roadY = buffer.readi16(buf, near + 6) / 8
	if state.Low then
		-- Embank: the lowest of the cell's corner nodes of track A (each already the low over EMBANK_REACH)
		local low = state.Low
		local m = buffer.readi16(low, near // REC * 2)
		m = lowAt(buf, low, o00, A, lowAt(buf, low, o10, A, lowAt(buf, low, o01, A, lowAt(buf, low, o11, A, m))))
		roadY = m / 8
	elseif
		buffer.readu8(buf, o00) == A
		and buffer.readu8(buf, o10) == A
		and buffer.readu8(buf, o01) == A
		and buffer.readu8(buf, o11) == A
	then
		roadY = bilinear(
			buffer.readi16(buf, o00 + 6) / 8,
			buffer.readi16(buf, o10 + 6) / 8,
			buffer.readi16(buf, o01 + 6) / 8,
			buffer.readi16(buf, o11 + 6) / 8,
			u,
			v
		)
	end
	local dc = bilinear(
		buffer.readu16(buf, o00 + 8) / 4,
		buffer.readu16(buf, o10 + 8) / 4,
		buffer.readu16(buf, o01 + 8) / 4,
		buffer.readu16(buf, o11 + 8) / 4,
		u,
		v
	)
	local pA, pB
	if state.Sec then
		local k = near // REC * 4
		pA, pB = buffer.readu16(state.Sec, k), buffer.readu16(state.Sec, k + 2)
	end
	return A, dA, B ~= NONE and B or nil, dB, roadY, dc, pA, pB
end

local function noise(R, x, z, seed)
	local f = R.Noise or 0.03
	return math.noise(x * f, z * f, seed + 0.37) * (R.Amp or (R.Height or 12) * 0.25)
end

-- Absolute top of a ridge (or Far) shape at band position r (0 at SHOULDER, 1 at MIDLINE)
local function shapeY(R, r, x, z, seed, prof)
	local H = R.Height or 12
	local shape = R.Shape or "Hills"
	local level = prof.Water and prof.Water.Level or -3
	if shape == "Hills" then
		return G + H * (1 - math.cos(math.pi * (0.5 + 0.5 * r))) / 2 + noise(R, x, z, seed)
	elseif shape == "Cliff" then
		return G + H * (0.15 + 0.85 * smooth((r - 0.65) / 0.1)) + noise(R, x, z, seed) * 0.3
	elseif shape == "Dunes" then
		return G + H * (0.55 + 0.45 * math.sin((x + z) * 0.045 + noise(R, x, z, seed) * 0.2)) * (0.6 + 0.4 * r)
	elseif shape == "Mesa" then
		local step = H / 4
		return G + math.floor((H * (0.4 + 0.6 * r) + noise(R, x, z, seed)) / step + 0.5) * step
	elseif shape == "Water" then
		return level - 6 + noise(R, x, z, seed) * 0.2
	elseif shape == "Drop" then
		return -40
	end
	return G -- Blocks: flat; the city blocks are the dressing's Blocks layer
end

-- One biome's top at distance d from its track: corridor, shoulder rise, ridge, and Far for the last track.
-- Also returns the band ("Corridor", "Ridge" or "Far"), that band's shape, de, and the section that rules here (its
-- blend weight >= 0.5) or nil. p is the node's section position of track n (see the Sections grid).
local function biomeY(n, d, x, z, roadY, dc, p)
	local prof = state.Profiles[n] or {}
	local C, S, MID = TerrainShape.CORRIDOR, TerrainShape.SHOULDER, TerrainShape.MIDLINE
	local sec, sw = nil, 0
	if state.Sections[n] and p and p ~= FAR then
		local at = (p // 2) / POS_Q * state.Lengths[n]
		local inner = p % 2 == 1
		for _, s in state.Sections[n] do
			if s.Side == "Both" or (s.Side == "Inner") == inner then
				-- 0.5 on the From / To line, blended over SEAM studs of track length
				local w = clamp01(0.5 + math.min(at - s.From, s.To - at) / TerrainShape.SEAM)
				if w > sw then
					sec, sw = s, w
				end
			end
		end
	end
	local rules = sw >= 0.5 and sec or nil
	local de = math.min(d, (dc or math.huge) + C) -- clear boxes are corridor too
	local base = G
	if prof.Embank and d <= S and dc + C > d then
		base = math.max(G, roadY - TerrainShape.EMBANK_BELOW)
	end
	if de <= C then
		return base, "Corridor", nil, de, rules
	end
	local R = prof.Ridge or DEFAULT_RIDGE
	local r = clamp01((de - S) / (MID - S))
	local y = shapeY(R, r, x, z, n, prof)
	local band, shape = "Ridge", R.Shape or "Hills"
	if sec and sec.Ridge then
		y += (shapeY(sec.Ridge, r, x, z, n, sec.Prof) - y) * sw
		if rules then
			shape = sec.Ridge.Shape or "Hills"
		end
	end
	if prof.Far and n == state.Last and de > MID then
		local f = smooth((de - MID) / TerrainShape.FAR_BLEND)
		y += (shapeY(prof.Far, 1, x, z, n + 100, prof) - y) * f
		if f >= 0.5 then
			band, shape = "Far", prof.Far.Shape or "Hills"
		end
	end
	local pits = state.Pits[n]
	if pits then
		-- smooth bowl, zero slope at its rim; it only lowers, and the shoulder blend below zeroes it at the corridor
		local rad, dip = pits.Radius, 0
		for _, c in pits.Centres do
			local dx, dz = x - c.X, z - c.Y
			local r2 = (dx * dx + dz * dz) / (rad * rad)
			if r2 < 1 then
				dip = math.max(dip, pits.Depth * (1 - r2) * (1 - r2)) -- overlapping pits never dig past Depth
			end
		end
		y -= dip
	end
	return base + (y - base) * smooth((de - C) / (S - C)), band, shape, de, rules
end

-- The column at (x, z): top Y, water top (or nil), its material, the cliff material and slope limit (nil in the
-- corridor). Materials dither across the seam (spec 2.3).
function TerrainShape.Column(x, z)
	local A, dA, B, dB, roadY, dc, pA, pB = sample(x, z)
	local yA, bandA, shapeA, deA, secA = biomeY(A, dA, x, z, roadY, dc, pA)
	local y, n, band, shape, sec = yA, A, bandA, shapeA, secA
	if B and dB - dA < TerrainShape.SEAM / 2 then
		local w = clamp01(0.5 + (dB - dA) / TerrainShape.SEAM)
		local yB, bandB, shapeB, _, secB = biomeY(B, dB, x, z, roadY, dc, pB)
		y = yA * w + yB * (1 - w)
		if hash(x, z) >= w then
			n, band, shape, sec = B, bandB, shapeB, secB
		end
	end
	local C, S = TerrainShape.CORRIDOR, TerrainShape.SHOULDER
	for _, pad in state.Pads or {} do
		local ex = math.max(pad.Min.X - x, 0, x - pad.Max.X)
		local ez = math.max(pad.Min.Y - z, 0, z - pad.Max.Y)
		local w = (1 - smooth(math.sqrt(ex * ex + ez * ez) / (S - C))) * smooth((deA - C) / (S - C))
		y += (pad.Y - y) * w
	end
	local prof = state.Profiles[n] or {}
	local mats = prof.Materials or DEFAULT_MATERIALS
	local own = sec and sec.Material -- a section's Material is its corridor and ridge material
	if band == "Corridor" then
		return y, nil, own or mats.Corridor or DEFAULT_MATERIALS.Corridor, nil, nil
	end
	local water = sec and sec.Water or prof.Water
	local wet = shape == "Water" or (water and water.Where == band)
	local waterY = wet and (water and water.Level or -3) or nil
	if waterY and y >= waterY then
		waterY = nil
	end
	local surface = (waterY or shape == "Drop") and (mats.Bed or DEFAULT_MATERIALS.Bed)
		or own
		or mats.Ridge
		or DEFAULT_MATERIALS.Ridge
	return y, waterY, surface, mats.Cliff or DEFAULT_MATERIALS.Cliff, prof.CliffSlope or 0.9
end

function TerrainShape.Height(x, z)
	return (TerrainShape.Column(x, z))
end

-- Zone of (x, z) from the grid: 0 inside the plaza radius, else the nearest track
function TerrainShape.Zone(x, z)
	if x * x + z * z <= state.PlazaRadius * state.PlazaRadius then
		return 0
	end
	return (sample(x, z))
end

-- Zone ownership for the dressing (gap midline, spec 2.2 / 2.3): the nearest track at (x, z), plaza or not, and
-- track n's distance there (math.huge when the grid keeps neither of its two tracks as n)
function TerrainShape.Owner(x, z, n)
	local A, dA, B, dB = sample(x, z)
	return A, A == n and dA or B == n and dB or math.huge
end

-- Material of the voxel at (x, y, z); slope (rise / run) is sampled from Height when not given
function TerrainShape.Material(x, y, z, slope)
	local h, waterY, surface, cliff, limit = TerrainShape.Column(x, z)
	if waterY and y > h then
		return M.Water
	end
	if cliff then
		if not slope then
			local s = 4
			slope = math.max(
				math.abs(TerrainShape.Height(x + s, z) - TerrainShape.Height(x - s, z)),
				math.abs(TerrainShape.Height(x, z + s) - TerrainShape.Height(x, z - s))
			) / (2 * s)
		end
		if slope > limit then
			return cliff
		end
	end
	return surface
end

function TerrainShape.WaterLevel(zone)
	local water = state and state.Profiles[zone] and state.Profiles[zone].Water
	return water and water.Level or nil
end

return TerrainShape
