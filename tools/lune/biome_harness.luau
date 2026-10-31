--!nonstrict
-- Biome harness (docs/BIOME_ENVIRONMENT_SPEC.md 3.2): runs the real TrackBuilder, BiomeThemes, BiomeDressing.Prune,
-- TerrainShape.Prepare and BiomeDressing.SnapToTerrain on the track chain in Lune, Instances from @lune/roblox.
-- Run from the repo root: `lune run tools/lune/biome_harness.luau`. Env: ROOT (repo root, default cwd), N (tracks,
-- default 10), ONLY=1 (print every padded prop over 1 stud), NOMESH=1 (fallback parts instead of one part per mesh),
-- TUNNEL=1 (give Track 7 the spec 3.5 example Tunnel and check it: no terrain in the box, ceiling >= 12 studs).
-- Reports per track: padded / pinned props, gap > 1 stud against TerrainShape.Height and against the drawn voxel
-- surface (TerrainBuilder columns every 4 studs, bilinear between column centres), pinned heroes, and corridor cells
-- changed by the pads.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local R = require("@lune/roblox")
local ROOT = process.env.ROOT or process.cwd

-- Model methods Lune lacks: bounding box oriented like the first part (props are yaw-only, all parts share it)
local function parts(m)
	local o = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(o, d)
		end
	end
	return o
end
R.implementMethod("Model", "GetBoundingBox", function(m)
	local ps = parts(m)
	local rot = ps[1] and ps[1].CFrame.Rotation or R.CFrame.identity
	local lo, hi = R.Vector3.new(math.huge, math.huge, math.huge), R.Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ps do
		local h = p.Size / 2
		for _, s in
			{
				{ -1, -1, -1 },
				{ -1, -1, 1 },
				{ -1, 1, -1 },
				{ -1, 1, 1 },
				{ 1, -1, -1 },
				{ 1, -1, 1 },
				{ 1, 1, -1 },
				{ 1, 1, 1 },
			}
		do
			local w = p.CFrame:PointToWorldSpace(R.Vector3.new(h.X * s[1], h.Y * s[2], h.Z * s[3]))
			local l = rot:PointToObjectSpace(w)
			lo, hi = lo:Min(l), hi:Max(l)
		end
	end
	return R.CFrame.new(rot:PointToWorldSpace((lo + hi) / 2)) * rot, hi - lo
end)
for _, cls in { "Part", "WedgePart", "MeshPart", "TrussPart", "CornerWedgePart", "SpawnLocation", "Seat" } do
	pcall(R.implementProperty, cls, "Position", function(p)
		return p.CFrame.Position
	end, function(p, v)
		p.CFrame = p.CFrame.Rotation + v
	end)
end
local pivots = setmetatable({}, { __mode = "k" })
R.implementMethod("Model", "GetPivot", function(m)
	if not pivots[m] then
		local cf = m:GetBoundingBox()
		pivots[m] = cf
	end
	return pivots[m]
end)
R.implementMethod("Model", "PivotTo", function(m, to)
	local from = m:GetPivot()
	local delta = to * from:Inverse()
	for _, p in parts(m) do
		p.CFrame = delta * p.CFrame
		p.Position = p.CFrame.Position
	end
	pivots[m] = to
end)

-- script tree over the filesystem
local cache = {}
local Node = {}
Node.__index = function(self, k)
	if Node[k] then
		return Node[k]
	end
	if k == "Parent" then
		return rawget(self, "_parent")
	end
	return self:FindFirstChild(k)
end
function Node.new(path, parent, name)
	return setmetatable({ _path = path, _parent = parent, Name = name, _kids = {} }, Node)
end
local TREE = {} -- path -> { [childName] = true } built eagerly (fs yields, metamethods cannot)
local FILES = {}
local function walk(dir)
	TREE[dir] = {}
	for _, f in fs.readDir(dir) do
		local p = dir .. "/" .. f
		if fs.isDir(p) then
			TREE[dir][f] = true
			walk(p)
		elseif f:match("%.luau$") and f ~= "init.luau" then
			TREE[dir][(f:gsub("%.luau$", ""))] = true
			FILES[dir .. "/" .. f:gsub("%.luau$", "")] = fs.readFile(p)
		elseif f == "init.luau" then
			FILES[dir] = fs.readFile(p)
		end
	end
end
walk(ROOT .. "/src/shared")
function Node:FindFirstChild(k)
	if self._kids[k] then
		return self._kids[k]
	end
	local t = TREE[self._path]
	if t and t[k] then
		self._kids[k] = Node.new(self._path .. "/" .. k, self, k)
		return self._kids[k]
	end
	return nil
end
function Node:WaitForChild(k)
	return assert(self:FindFirstChild(k), "no child " .. k .. " in " .. self._path)
end
function Node:IsA(c)
	return c == "ModuleScript"
end
function Node:GetChildren()
	local o = {}
	for k in TREE[self._path] or {} do
		table.insert(o, self:FindFirstChild(k))
	end
	table.sort(o, function(a, b)
		return a.Name < b.Name
	end)
	return o
end
local tags = {}
local CS = {
	AddTag = function(_, i, t)
		tags[t] = tags[t] or {}
		table.insert(tags[t], i)
	end,
	GetTagged = function(_, t)
		return tags[t] or {}
	end,
}
local game = {
	GetService = function(_, s)
		if s == "CollectionService" then
			return CS
		end
		return setmetatable({}, {
			__index = function()
				return function() end
			end,
		})
	end,
}
WARNS = {}
local function req(node)
	if type(node) == "string" then
		return require(node)
	end
	if cache[node._path] ~= nil then
		return cache[node._path]
	end
	local src = assert(FILES[node._path], "no module " .. node._path)
	-- Lune keeps Position and CFrame as separate stored properties: sync them after each single-line write
	local out = {}
	local lines = {}
	for line in (src .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	for li, line in lines do
		local nxt = lines[li + 1] or ""
		if nxt:match("^%s*[%*%+%-/]") and not nxt:match("^%s*%-%-") then
			table.insert(out, line)
			continue
		end
		local ind, obj = line:match("^(%s*)([%w_%.]+)%.CFrame = .+[^%(,{]$")
		local ind2, obj2 = line:match("^(%s*)([%w_%.]+)%.Position [%-%+]?= .*Vector3.+[^%(,{]$")
		if obj and not line:find("%-%-") then
			line = line .. "; __syncP(" .. obj .. ")"
		elseif obj2 then
			line = line .. "; __syncC(" .. obj2 .. ")"
		end
		table.insert(out, line)
	end
	src = table.concat(out, "\n")
	if node.Name == "TerrainShape" then
		src = src:gsub(
			"\nreturn TerrainShape%s*$",
			"\nTerrainShape._st = function() return state end\nTerrainShape._sample = function(x, z) return sample(x, z) end\nreturn TerrainShape\n"
		)
	end
	local env = setmetatable({
		script = node,
		game = game,
		require = req,
		Instance = R.Instance,
		Vector3 = R.Vector3,
		Vector2 = R.Vector2,
		CFrame = R.CFrame,
		Color3 = R.Color3,
		ColorSequence = R.ColorSequence,
		ColorSequenceKeypoint = R.ColorSequenceKeypoint,
		NumberSequence = R.NumberSequence,
		NumberSequenceKeypoint = R.NumberSequenceKeypoint,
		NumberRange = R.NumberRange,
		UDim2 = R.UDim2,
		UDim = R.UDim,
		Enum = R.Enum,
		BrickColor = R.BrickColor,
		Font = R.Font,
		task = {
			wait = function() end,
			spawn = function(f, ...)
				f(...)
			end,
			defer = function() end,
		},
		__syncP = function(x)
			pcall(function()
				x.Position = x.CFrame.Position
			end)
		end,
		__syncC = function(x)
			pcall(function()
				x.CFrame = x.CFrame.Rotation + x.Position
			end)
		end,
		warn = function(...)
			table.insert(WARNS, table.concat({ ... }, " "))
		end,
	}, { __index = getfenv() })
	local v = luau.load(src, { environment = env, debugName = node.Name })()
	cache[node._path] = v
	return v
end

local Shared = Node.new(ROOT .. "/src/shared", nil, "Shared")
local World = {}
World.Shared = Shared
World.require = req
World.R = R

function World.build(count)
	local TB = req(Shared.TrackBuilder)
	local TReg = req(Shared.TrackRegistry)
	local Tunnel = req(Shared.Tunnel)
	local Themes = req(Shared.BiomeThemes)
	local entries, models = {}, {}
	local origin = TB.CHAIN_ORIGIN
	for _, spec in TReg.Chain() do
		if spec.Number <= count then
			local model, layout = TB.Build(spec, origin)
			model.Name = spec.Name
			local _, parts = Tunnel.Build(model, layout, Themes[spec.Biome], origin)
			if parts > 0 then
				print(string.format("TUNNEL %s parts %d", spec.Name, parts))
			end
			table.insert(
				entries,
				{ Layout = layout, Origin = origin, Model = model, Number = spec.Number, Biome = spec.Biome }
			)
			table.insert(models, model)
			origin = TB.EndCFrame(layout, origin)
		end
	end
	return entries, models
end

-- The spec 3.5 example (Track 7, section 7 values) for TUNNEL=1; the biome module owns the real one
if process.env.TUNNEL then
	req(Shared.BiomeThemes).Desert.Tunnel = {
		Width = 60,
		Height = 20,
		Wall = { Material = R.Enum.Material.CeramicTiles, Color = "#E9E4D6", Stripe = "#3FA7A0" },
		Ceiling = { Material = R.Enum.Material.Concrete, Color = "#8C8A84" },
		Floor = { Material = R.Enum.Material.Concrete, Color = "#8C8A84" },
		LightEvery = 24,
		Bays = {
			{ From = 0.12, To = 0.17, Side = "Left", Depth = 40, Height = 30 },
			{ From = 0.33, To = 0.40, Side = "Both", Depth = 60, Height = 40 },
			{ From = 0.58, To = 0.63, Side = "Right", Depth = 40, Height = 30 },
			{ From = 0.82, To = 0.90, Side = "Both", Depth = 50, Height = 30 },
		},
		Portals = true,
	}
end

-- Measure
local BD = req(Shared.BiomeDressing)
if not process.env.NOMESH then
	-- like Studio: an uploaded mesh is one part at def.Size (BiomeAssets.Clone)
	BD.Assets = {
		Clone = function(_, _, size)
			local p = R.Instance.new("Part")
			p.Size = size
			return p
		end,
	}
end
local TS = req(Shared.TerrainShape)
local entries, models = World.build(tonumber(process.env.N or "10"))
local spawnArea = R.Instance.new("Part") -- the plaza floor (SpawnArea.FLOOR_SIZE at the origin)
spawnArea.Size = R.Vector3.new(188, 1, 220)
spawnArea.CFrame = R.CFrame.new(0, -1, 0)
spawnArea.Position = spawnArea.CFrame.Position
BD.Prune(models, { spawnArea })
local clear = {}
for _, m in models do
	table.insert(clear, m:FindFirstChild("Checkpoint"))
	table.insert(clear, m:FindFirstChild("WinPad", true))
end
TS.Prepare(entries, clear, { spawnArea })
local function corridor(x, z)
	local _, _, _, _, limit = TS.Column(x, z)
	return limit == nil
end
-- corridor heights before any pad, every 4 studs inside the world box (skirt excluded)
local box = TS.Box()
local corr, ncorr = {}, 0
for x = box.Min.X + 900, box.Max.X - 900, 4 do
	for z = box.Min.Y + 900, box.Max.Y - 900, 4 do
		if corridor(x, z) then
			corr[x .. "," .. z] = TS.Height(x, z)
			ncorr += 1
		end
	end
end
local t0 = os.clock()
local moved, dropped = BD.SnapToTerrain(models)
print(string.format("snap %.1fs moved %d dropped %d", os.clock() - t0, moved, dropped))
local changed = 0
for k, h in corr do
	local x, z = k:match("(.-),(.*)")
	if TS.Height(tonumber(x), tonumber(z)) ~= h then
		changed += 1
	end
end
print("corridor cells", ncorr, "changed", changed)
for _, w in WARNS do
	print("WARN", w)
end

-- The drawn voxel surface: TerrainBuilder writes one column per 4-stud voxel, centred at 2 mod 4 (chunks start at
-- multiples of 256), and the smooth-terrain mesher interpolates between column centres (approximated bilinear)
local RES = 4
local colCache = {}
local function col(i, j)
	local k = i * 1e6 + j
	local h = colCache[k]
	if not h then
		h = TS.Height(i * RES + RES / 2, j * RES + RES / 2)
		colCache[k] = h
	end
	return h
end
local function drawn(x, z)
	local fx, fz = (x - RES / 2) / RES, (z - RES / 2) / RES
	local i, j = math.floor(fx), math.floor(fz)
	local u, v = fx - i, fz - j
	return (col(i, j) * (1 - u) + col(i + 1, j) * u) * (1 - v) + (col(i, j + 1) * (1 - u) + col(i + 1, j + 1) * u) * v
end

-- Worst float (base above ground) of a prop over its footprint on a 1-stud grid, by `ground`
local function gapOf(prop, ground)
	local cf, size = prop:GetBoundingBox()
	local baseY = cf.Position.Y - size.Y / 2
	local worst, wx, wz = 0, 0, 0
	for a = -size.X / 2, size.X / 2 + 0.01, 1 do
		for b = -size.Z / 2, size.Z / 2 + 0.01, 1 do
			local p = cf:PointToWorldSpace(R.Vector3.new(math.min(a, size.X / 2), 0, math.min(b, size.Z / 2)))
			local g = baseY - ground(p.X, p.Z)
			if g > worst then
				worst, wx, wz = g, p.X, p.Z
			end
		end
	end
	return worst, wx, wz, cf, size
end
local only = process.env.ONLY
local total = { n = 0, h = 0, v = 0 }
for _, m in models do
	local env = m:FindFirstChild("Environment")
	local n, overH, overV, worstH, worstV, wname, seated, inCorr = 0, 0, 0, 0, 0, "", 0, 0
	for _, prop in env:GetChildren() do
		if prop:IsA("Model") and (prop:GetAttribute("Pad") or prop:GetAttribute("Pinned")) then
			local g = gapOf(prop, TS.Height)
			local gv, x, z, cf, size = gapOf(prop, drawn)
			local pinned = prop:GetAttribute("Pinned")
			if pinned or (only and math.max(g, gv) > 1) then
				print(
					string.format(
						"  %s %s pinned=%s gap %.2f voxel %.2f at (%.0f,%.0f) corridor=%s base %.2f centre (%.0f,%.0f) size %.0fx%.0f",
						m.Name,
						prop.Name,
						tostring(pinned),
						g,
						gv,
						x,
						z,
						tostring(corridor(x, z)),
						cf.Position.Y - size.Y / 2,
						cf.Position.X,
						cf.Position.Z,
						size.X,
						size.Z
					)
				)
			end
			if not pinned then
				n += 1
				-- road-seated: the footprint grown by one voxel reaches a corridor (base at CorridorLow, spec 3.2)
				seated += TS.CorridorLow(cf, size + R.Vector3.new(8, 0, 8)) and 1 or 0
				inCorr += TS.CorridorLow(cf, size) and 1 or 0
				overH += g > 1 and 1 or 0
				overV += gv > 1 and 1 or 0
				worstH = math.max(worstH, g)
				if gv > worstV then
					worstV, wname = gv, prop.Name
				end
			end
		end
	end
	total.n += n
	total.h += overH
	total.v += overV
	print(
		string.format(
			"%s: padded %d (in corridor %d, within a voxel %d), gap>1 Height %d (worst %.2f), voxel %d (worst %.2f %s)",
			m.Name,
			n,
			inCorr,
			seated,
			overH,
			worstH,
			overV,
			worstV,
			wname
		)
	)
end
print(string.format("TOTAL padded %d, gap>1 Height %d, voxel %d", total.n, total.h, total.v))

-- Identity check (fw5): one hash of every terrain column (every 8 studs, skirt excluded) and every prop pivot after
-- the snap. A change that must not move any biome compares it before and after (with TUNNEL unset).
do
	local h = 0
	local function mix(v)
		h = (h * 31 + v) % 2147483647
	end
	for x = box.Min.X + 900, box.Max.X - 900, 8 do
		for z = box.Min.Y + 900, box.Max.Y - 900, 8 do
			local y, w, m, c, l = TS.Column(x, z)
			mix(math.floor(y * 1000 + 0.5))
			mix(w and math.floor(w * 1000 + 0.5) or 7)
			mix(m.Value)
			mix(c and c.Value or 3)
			mix(l and math.floor(l * 1000) or 5)
		end
	end
	local props = 0
	for _, m in models do
		for _, prop in m:FindFirstChild("Environment"):GetChildren() do
			local p = prop:IsA("Model") and prop:GetPivot().Position or prop.Position
			mix(math.floor(p.X * 100 + 0.5) % 1000003)
			mix(math.floor(p.Y * 100 + 0.5) % 1000003)
			mix(math.floor(p.Z * 100 + 0.5) % 1000003)
			props += 1
		end
	end
	print(string.format("IDENTITY hash %d props %d", h, props))
end

-- Tunnel checks (spec 3.5, TUNNEL=1): every 4 studs inside each tunnel segment's inner box the terrain column has
-- its hollow, floor at most road Y - 1 and earth only above the ceiling; every 20 studs a ray up from the road
-- centre hits a tunnel part no lower than road Y + 12; no tunnel part within CLEARANCE of a checkpoint or WinPad;
-- and the nearest other track's centre line beside each bay.
do
	local Tunnel = req(Shared.Tunnel)
	local Themes = req(Shared.BiomeThemes)
	for _, e in entries do
		local def = Themes[e.Biome].Tunnel
		local folder = e.Model:FindFirstChild("Tunnel")
		if def and folder then
			local segs, s0, s1, total = Tunnel.Segments(e.Layout, e.Origin, def)
			local bad, worst, samples = 0, math.huge, 0
			for _, seg in segs do
				local half = seg.Length / 2
				for t = -half, half, 4 do
					for x = -seg.Left + 1, seg.Right - 1, 4 do
						local p = seg.CFrame * R.CFrame.new(x, 0, -t)
						local road = p.Position.Y
						local y, _, _, _, _, lo, hi = TS.Column(p.Position.X, p.Position.Z)
						samples += 1
						local floor = lo or y
						local ok = floor <= road - 1
							and (y <= road - 1 or (hi and hi >= road + seg.Height + Tunnel.CEILING))
						if not ok then
							bad += 1
							if bad <= 5 then
								print(
									string.format(
										"  terrain in tunnel box at (%.0f,%.0f) road %.1f top %.1f lo %s hi %s",
										p.Position.X,
										p.Position.Z,
										road,
										y,
										tostring(lo),
										tostring(hi)
									)
								)
							end
						end
						if hi then
							worst = math.min(worst, hi - road)
						end
					end
				end
			end
			print(
				string.format(
					"TUNNEL %s box: %d samples, %d with terrain, lowest hollow top %.1f above road (span %.0f-%.0f of %.0f)",
					e.Model.Name,
					samples,
					bad,
					worst,
					s0,
					s1,
					total
				)
			)
			-- rays up every 20 studs along the centre line inside the span
			local parts = {}
			for _, d in folder:GetDescendants() do
				if d:IsA("BasePart") and d.CanQuery then
					table.insert(parts, d)
				end
			end
			local HIT -- the part the last ray hit
			local function rayUp(o)
				local best = math.huge
				for _, part in parts do
					local c = part.CFrame
					if
						math.abs(c.Position.X - o.X) < part.Size.Magnitude
						and math.abs(c.Position.Z - o.Z) < part.Size.Magnitude
					then
						local lo, ld = c:PointToObjectSpace(o), c:VectorToObjectSpace(R.Vector3.new(0, 1, 0))
						local t0, t1 = 0, 200
						for _, ax in { "X", "Y", "Z" } do
							local h = part.Size[ax] / 2
							if math.abs(ld[ax]) < 1e-9 then
								if math.abs(lo[ax]) > h then
									t0 = math.huge
								end
							else
								local a, b = (-h - lo[ax]) / ld[ax], (h - lo[ax]) / ld[ax]
								t0, t1 = math.max(t0, math.min(a, b)), math.min(t1, math.max(a, b))
							end
						end
						if t0 <= t1 and t0 < best then
							best, HIT = t0, part.Name
						end
					end
				end
				return best
			end
			local low, rays, open = math.huge, 0, 0
			for _, seg in segs do
				local s = math.ceil(seg.From / 20) * 20
				while s < seg.To do
					local p = (seg.CFrame * R.CFrame.new(0, 0.5, -(s - (seg.From + seg.To) / 2) / seg.Flat)).Position
					local d = rayUp(p) + 0.5
					rays += 1
					if d < 12 or d == math.huge then
						print(
							string.format(
								"  ray at s %.0f (%.0f,%.1f,%.0f): %.1f %s",
								s,
								p.X,
								p.Y,
								p.Z,
								d,
								tostring(HIT)
							)
						)
					end
					if d == math.huge then
						open += 1
					else
						low = math.min(low, d)
					end
					s += 20
				end
			end
			print(
				string.format(
					"TUNNEL %s rays: %d, open %d, lowest ceiling %.1f above road (need >= 12)",
					e.Model.Name,
					rays,
					open,
					low
				)
			)
			-- clearance to every checkpoint and WinPad (world AABBs, conservative)
			local function aabb(part)
				local cf, size = part.CFrame, part.Size
				local half = (cf.RightVector * size.X):Abs() / 2
					+ (cf.UpVector * size.Y):Abs() / 2
					+ (cf.LookVector * size.Z):Abs() / 2
				return cf.Position - half, cf.Position + half
			end
			local pads = {}
			for _, m in models do
				for _, name in { "CheckpointArea", "WinPad" } do
					local p = m:FindFirstChild(name, true)
					if p then
						local lo, hi = aabb(p)
						table.insert(pads, {
							lo - R.Vector3.one * BD.CLEARANCE,
							hi + R.Vector3.one * BD.CLEARANCE,
							m.Name .. "." .. name,
						})
					end
				end
			end
			local near = 0
			for _, part in parts do
				local lo, hi = aabb(part)
				for _, b in pads do
					if
						lo.X < b[2].X
						and hi.X > b[1].X
						and lo.Y < b[2].Y
						and hi.Y > b[1].Y
						and lo.Z < b[2].Z
						and hi.Z > b[1].Z
					then
						near += 1
						print("  tunnel part near", b[3], part.Name)
					end
				end
			end
			print(string.format("TUNNEL %s parts within CLEARANCE of a checkpoint or WinPad: %d", e.Model.Name, near))
			-- room beside each bay, per side: the nearest other track's centre line from the bay's outer wall
			for _, bay in def.Bays or {} do
				local room = { L = math.huge, R = math.huge }
				for _, seg in segs do
					local m = (seg.From + seg.To) / 2
					if (seg.BayLeft or seg.BayRight) and m >= bay.From * total and m < bay.To * total then
						for _, o in entries do
							if o ~= e then
								for _, w in o.Layout.WorldWaypoints do
									local l = seg.CFrame:PointToObjectSpace(w)
									if math.abs(l.Z) <= seg.Length / 2 + 40 then
										local key = l.X < 0 and "L" or "R"
										local edge = (key == "L" and seg.Left or seg.Right) + Tunnel.WALL
										room[key] = math.min(room[key], math.abs(l.X) - edge)
									end
								end
							end
						end
					end
				end
				print(
					string.format(
						"TUNNEL bay %.2f-%.2f %s depth %d: outer wall to another road centre: left %.0f, right %.0f",
						bay.From,
						bay.To,
						bay.Side,
						bay.Depth,
						room.L,
						room.R
					)
				)
			end
		end
	end
end
