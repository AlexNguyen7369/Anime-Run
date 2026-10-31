--!nonstrict
-- Enclosed tunnel corridor (docs/BIOME_ENVIRONMENT_SPEC.md 3.5). A biome module's optional `Tunnel` field:
--   Tunnel = {
--   	Width = 60, Height = 20,                          -- inner clear size, centred on the road centre line
--   	Wall = { Material, Color = "#hex", Stripe = "#hex"? },
--   	Ceiling = { Material, Color = "#hex" },
--   	Floor = { Material, Color = "#hex" }?,             -- a slab under the road across the whole tunnel width
--   	LightEvery = 24,                                  -- one ceiling light strip every N studs
--   	Bays = { { From = 0.12, To = 0.17, Side = "Left"|"Right"|"Both", Depth = 40, Height = 30 }, ... },
--   	Portals = true,                                   -- entrance facades at the start and finish
--   }
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

-- Cross section at track position s: left and right inner half-widths, inner height and the bay sides there
local function section(def, s, total)
	local half = (def.Width or 60) / 2
	local left, right, h = half, half, def.Height or 20
	local bayL, bayR = false, false
	for _, bay in def.Bays or {} do
		if s >= (bay.From or 0) * total and s < (bay.To or 1) * total then
			local side = bay.Side or "Both"
			if side ~= "Right" then
				left, bayL = math.max(left, half + (bay.Depth or 0)), true
			end
			if side ~= "Left" then
				right, bayR = math.max(right, half + (bay.Depth or 0)), true
			end
			h = math.max(h, bay.Height or h)
		end
	end
	return left, right, h, bayL, bayR
end
Tunnel.Section = section -- BiomeDressing places props inside the walls and on the bay platforms from it

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
-- Right / Height (inner cross section), BayLeft / BayRight, and TanStart / TanEnd (tan of half the bend between
-- chords at a chord end, 0 at a cut inside a chord) so parts can be lengthened to close the gaps between chords.
-- A Loop segment inside the span is not supported.
function Tunnel.Segments(layout, origin, def)
	local s0, s1, total = Tunnel.Span(layout)
	local list = chords(layout, origin)
	local cuts = { s0, s1 }
	for _, bay in def.Bays or {} do
		table.insert(cuts, (bay.From or 0) * total)
		table.insert(cuts, (bay.To or 1) * total)
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
				local left, right, h, bayL, bayR = section(def, m, total)
				local p = at(m)
				table.insert(out, {
					CFrame = CFrame.fromMatrix(p, rightVec, rightVec:Cross(f)),
					Length = (at(v) - at(u)).Magnitude,
					Flat = flat,
					From = u,
					To = v,
					Left = left,
					Right = right,
					Height = h,
					BayLeft = bayL,
					BayRight = bayR,
					TanStart = u == c.SA and k > 1 and tanHalf(c, list[k - 1]) or 0,
					TanEnd = v == c.SB and k < #list and tanHalf(c, list[k + 1]) or 0,
				})
			end
		end
	end
	return out, s0, s1, total
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
-- segment's chord ends by (`reach` + its height) x tan(half the bend) so neighbouring chords meet on a bend or crest
local function along(folder, name, seg, x0, x1, y0, y1, reach, color, material)
	reach += math.max(math.abs(y0), math.abs(y1))
	local eS, eE = reach * seg.TanStart, reach * seg.TanEnd
	local length = seg.Length + eS + eE
	return newPart(
		folder,
		name,
		Vector3.new(x1 - x0, y1 - y0, length),
		seg.CFrame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, -(eE - eS) / 2),
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
	local segs, s0, s1, total = Tunnel.Segments(layout, origin, def)
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
		along(folder, "WallL" .. i, seg, -l - W, -l, -R, h + C, l + W, wallCol, wallMat)
		along(folder, "WallR" .. i, seg, r, r + W, -R, h + C, r + W, wallCol, wallMat)
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
			for _, x in { -l + 0.1, r - 0.1 } do
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
					M.SmoothPlastic
				)
				band.CanCollide, band.CanQuery, band.CanTouch = false, false, false
			end
		end
		local half = (def.Width or 60) / 2
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
			local nl, nr, nh = nxt.Left, nxt.Right, nxt.Height
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
	local index, k = 0, 1
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
			local l, r, h = seg.Left, seg.Right, seg.Height
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
