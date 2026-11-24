--!nonstrict
-- Biome harness (docs/BIOME_ENVIRONMENT_SPEC.md 3.2): runs the real TrackBuilder, BiomeThemes, BiomeDressing.Prune,
-- TerrainShape.Prepare and BiomeDressing.SnapToTerrain on the track chain in Lune, Instances from @lune/roblox.
-- Run from the repo root: `lune run tools/lune/biome_harness.luau`. Env: ROOT (repo root, default cwd), N (tracks,
-- default 10), WORLD=2 (World 2's tracks and themes), NOFIGHT=1 (no fight scenes, fw7), NOTUNNEL=1 (no biome has a Tunnel, fw8: the framework's identity
-- check), SIGNED=1 (every ledger row counts as reviewed), ONLY=1 (print every padded prop over 1 stud), NOMESH=1 (fallback parts instead of one part per mesh),
-- TUNNEL=1 (give Track 7 the spec 3.5 example Tunnel and a pinned test hero outside the bays, and check it: no terrain in the
-- box, ceiling >= 12 studs, every prop inside the walls or on a bay platform, pinned heroes in their bays, the gate
-- before the start portal).
-- Reports per track: padded / pinned props, gap > 1 stud against TerrainShape.Height and against the drawn voxel
-- surface (TerrainBuilder columns every 4 studs, bilinear between column centres), pinned heroes, and corridor cells
-- changed by the pads.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local R = require("@lune/roblox")
local ROOT = process.env.ROOT or process.cwd
local failed = false -- any printed FAIL line makes the process exit 1 at the end
local rawPrint = print
print = function(...)
	failed = failed or string.find(tostring((...)), "FAIL", 1, true) ~= nil
	rawPrint(...)
end

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
	return c == (FILES[self._path] and "ModuleScript" or "Folder") -- a directory without init.luau is a Folder
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
		if s == "ReplicatedStorage" and process.env.WORLD == "2" then -- Shared/WorldConfig reads WorldId
			return {
				FindFirstChild = function(_, name)
					if name == "WorldId" then
						local id = R.Instance.new("IntValue")
						id.Value = 2
						return id
					end
					return nil
				end,
			}
		end
		return setmetatable({}, {
			__index = function()
				return function() end
			end,
		})
	end,
}
WARNS = {}
-- Lune's CFrame.lookAt mirrors Z, so a prop beside a diagonal road is turned wrong offline. Every run but NOTUNNEL=1
-- uses Roblox's lookAt (fw9: the tunnel fit checks need the real yaw; the mirrored one turned 7 of Track 7's
-- wall-hugging Rhythm props through its wall offline only); NOTUNNEL=1 keeps the mirror, so its IDENTITY hash stays
-- comparable with older runs.
local CF = R.CFrame
if not process.env.NOTUNNEL then
	CF = setmetatable({
		lookAt = function(at, target, up)
			local look = (target - at).Unit
			local right = look:Cross(up or R.Vector3.new(0, 1, 0)).Unit
			return R.CFrame.fromMatrix(at, right, right:Cross(look))
		end,
	}, { __index = R.CFrame })
end
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
		CFrame = CF,
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

-- The spec 3.5 example (Track 7, section 7 values) for TUNNEL=1; the biome module owns the real one. World 1 only:
-- WORLD=2 loads no Desert theme, so the example is skipped there (its own tunnels are still checked)
if process.env.TUNNEL and not req(Shared.BiomeThemes).Desert then
	print("INFO TUNNEL=1: no Desert theme in this world, the spec 3.5 example Tunnel is skipped")
elseif process.env.TUNNEL then
	req(Shared.BiomeThemes).Desert.Tunnel = {
		Width = 120, -- fw8 (owner 2026-11-01): the target width, narrowed per side near other tracks
		Height = 26,
		Wall = { Material = R.Enum.Material.CeramicTiles, Color = "#E9E4D6", Stripe = "#3FA7A0" },
		Ceiling = { Material = R.Enum.Material.Concrete, Color = "#8C8A84" },
		Floor = { Material = R.Enum.Material.Concrete, Color = "#8C8A84" },
		LightEvery = 24,
		Bays = {
			{ From = 0.12, To = 0.17, Side = "Left", Depth = 40, Height = 30 },
			{ From = 0.33, To = 0.40, Side = "Left", Depth = 60, Height = 40 },
			{ From = 0.58, To = 0.63, Side = "Right", Depth = 40, Height = 30 },
			{ From = 0.82, To = 0.90, Side = "Both", Depth = 50, Height = 30 },
		},
		Portals = true,
	}
	-- pinned test hero (fw6): one where no bay is (a warning, not built). fw8: the Track 7 redesign pins its own
	-- heroes in all four bays (Left, Right, Both), so the old Blossom Shrine test pins are gone
	local lm = req(Shared.BiomeThemes).Desert.Landmarks
	local def = table.clone(lm.Props[1])
	def.Hero, def.At, def.Name = true, 0.5, "Pin" .. def.Name -- own name: scatter looks landmarks up by name
	table.insert(lm.Props, def)
end

-- NOFIGHT=1: no biome builds its fight scene (fw7), so the IDENTITY hash must match the one from before fw7
if process.env.NOFIGHT then
	for _, theme in req(Shared.BiomeThemes) do
		if type(theme) == "table" then
			theme.FightScene = nil
		end
	end
end
-- NOTUNNEL=1 (fw8): no biome has a Tunnel, so the IDENTITY hash must match the one from before any tunnel change
if process.env.NOTUNNEL then
	for _, theme in req(Shared.BiomeThemes) do
		if type(theme) == "table" then
			theme.Tunnel = nil
		end
	end
end
-- SIGNED=1: treat every ledger row as reviewed (exercises the fight scene's meshes and textured effects offline)
if process.env.SIGNED then
	for _, theme in req(Shared.BiomeThemes) do
		for _, row in type(theme) == "table" and theme.Assets or {} do
			row.Reviewed = row.Reviewed or "harness"
		end
	end
end

-- WORLD=2: the approved World 2 themes (docs/WORLD2_SPEC.md "Blender first", BIOME_ENVIRONMENT_SPEC 4.2-4.5, design doc
-- 5). Prints "W2 FAIL <check>" per problem and "W2 CHECKS pass=<n> fail=<n>"; LEDGER=1 stops after these checks.
local W2_APPROVED = {
	"DevilTokyo",
	"DemonCastle",
	"RuinedCityZ",
	"HauntedTunnel",
	"KaijuBase",
	"ElvenPlains",
	"AntIsland",
	"MonsterDen",
	"GoldenCity",
	"HellGate",
}
-- A prop cut into pieces for the 2048-stud limit (WORLD2_SPEC 2026-11-24) is <Prop>_p<i>: the designed prop's name
local function designed(name)
	return string.match(name, "^(.-)_p%d+$") or name
end
if process.env.WORLD == "2" then
	-- realNameIn from the server tests' own source, so the hashed name list stays in one place
	local cat = fs.readFile(ROOT .. "/src/server/ServerTest/CatalogTests.luau")
	local from, to = cat:find("local REAL_NAME_HASHES", 1, true), cat:find("function Tests.catalog", 1, true)
	local realNameIn = luau.load(cat:sub(from, to - 1) .. "\nreturn realNameIn", { debugName = "realNameIn" })()
	local Themes = req(Shared.BiomeThemes)
	local pass, fail = 0, 0
	local function check(ok, name)
		if ok then
			pass += 1
		else
			fail += 1
			print("W2 FAIL " .. name)
		end
	end
	local function strings(t, out, seen)
		if type(t) == "string" then
			table.insert(out, t)
		elseif type(t) == "table" and not seen[t] then
			seen[t] = true
			for k, v in t do
				strings(k, out, seen)
				strings(v, out, seen)
			end
		end
		return out
	end
	for _, key in W2_APPROVED do
		local t = Themes[key]
		check(t ~= nil and t.Placed ~= nil and #t.Placed > 0, key .. " has its own draft theme")
		t = t or {}
		check(
			type(t.Terrain) == "table"
				and type(t.Atmosphere) == "table"
				and type(t.Atmosphere.Lighting.ClockTime) == "number"
				and type(t.Audio) == "table"
				and type(t.Assets) == "table",
			key .. " sections"
		)
		local hit
		for _, text in strings(t, {}, {}) do
			hit = hit or realNameIn((string.gsub(string.lower(text), "[^%w]+", "_")))
		end
		check(hit == nil, key .. " no real names")
		local used, meshes, seenProp = {}, 0, {}
		for name, def in t.Props or {} do
			check(#def.Parts > 0, key .. "/" .. name .. " has a parts fallback")
			if def.Mesh then
				-- the 12-mesh cap counts designed props; a prop's pieces are one (ledger Notes list them)
				meshes += seenProp[designed(name)] and 0 or 1
				seenProp[designed(name)] = true
				used[def.Mesh] = true
				local row = t.Assets[def.Mesh]
				check(
					type(row) == "table"
						and row.Kind == "Mesh"
						and row.Lane == "B"
						and type(row.Tris) == "number"
						and type(row.Prompt) == "string"
						and row.Prompt ~= ""
						and (row.Id == nil or string.match(row.Id, "^rbxassetid://%d+$") ~= nil)
						and (row.Reviewed == nil or string.match(row.Reviewed, "^%d%d%d%d%-%d%d%-%d%d %S") ~= nil),
					key .. "/" .. def.Mesh .. " ledger row"
				)
				check(string.sub(def.Mesh, 1, #key + 4) == "W2_" .. key .. "_", def.Mesh .. " key uses the biome key")
			end
		end
		for asset in t.Assets or {} do
			check(used[asset] == true, key .. "/" .. asset .. " ledger row is used")
		end
		check(meshes <= 12, key .. " unique meshes " .. meshes .. " <= 12")
		local unknown = 0
		for _, e in t.Placed or {} do
			unknown += (t.Props[e[1]] and 0 or 1)
		end
		check(unknown == 0, key .. " placements name known props")
		-- A placed prop's mesh (def.Size times its Scale or Stretch, BiomeDressing.placed) and every fallback part
		-- must fit Roblox's 2048-stud part limit per axis, or the engine clamps it and the art changes shape
		for i, e in t.Placed or {} do
			local def, k = t.Props[e[1]], e[9] or e[6]
			if def then
				local big = def.Size * k
				for _, p in def.Parts do
					big = big:Max(p.Size * k)
				end
				local axis = math.max(big.X, big.Y, big.Z)
				check(
					axis <= 2048,
					string.format("%s Placed_%d %s fits 2048 (%.0f x %.0f x %.0f)", key, i, e[1], big.X, big.Y, big.Z)
				)
			end
		end
	end
	print(string.format("W2 CHECKS pass=%d fail=%d", pass, fail))
	if process.env.LEDGER then
		process.exit(fail == 0 and 0 or 1)
	end
end

-- Spawn plaza look per world (design doc 4.47 "Moonlit Dojo"): in World 2 the plaza profile and colours come from
-- Shared/PlazaLook's World 2 table; World 1 has none and keeps its golden hour. Prints "PLAZA FAIL <check>" per problem
-- and "PLAZA CHECKS pass=<n> fail=<n>".
do
	local Look = req(Shared.PlazaLook)
	local p = req(Shared.BiomeEnvironment).Profile(0)
	local hex = R.Color3.fromHex
	local pass, fail = 0, 0
	local function check(ok, name)
		if ok then
			pass += 1
		else
			fail += 1
			print("PLAZA FAIL " .. name)
		end
	end
	if process.env.WORLD == "2" then
		local a = Look.Atmosphere
		check(
			a ~= nil and Look.Glow ~= nil and Look.Accent ~= nil and Look.Rift ~= nil and Look.Sakura == nil,
			"World 2 table"
		)
		a = a or { Lighting = {}, Atmosphere = {}, Sky = {} }
		for _, key in { "ClockTime", "Ambient", "OutdoorAmbient", "Brightness" } do
			check(p.Lighting[key] == a.Lighting[key], "Lighting." .. key .. " from the table")
		end
		check(
			p.Atmosphere.Density == a.Atmosphere.Density and p.Atmosphere.Color == a.Atmosphere.Color,
			"fog from the table"
		)
		check(p.Sky.Skybox == nil and p.Sky.SunAngularSize == a.Sky.SunAngularSize, "dusk sky from the table")
		check(p.Particles[1].Texture == "PlazaPetal" and p.Particles[1].Color == hex("FFFFFF"), "World 1 petals kept")
		check(p.Lighting.ClockTime > 16 and p.Lighting.ClockTime < 19, "dusk clock")
		check(#(Look.Islands or {}) == 5, "five islands")
		for i, isle in Look.Islands or {} do -- outside the plaza floor (x +-94, z +-110)
			check(math.abs(isle[1]) > 94 or math.abs(isle[2]) > 110, "island " .. i .. " outside the floor")
		end
	else
		check(next(Look) == nil, "World 1 has no plaza overrides")
		check(p.Lighting.ClockTime == 16.6 and p.Lighting.OutdoorAmbient == hex("B09A88"), "golden hour kept")
		check(p.Atmosphere.Density == 0.18 and p.Sky.Skybox == "SkyGolden", "golden fog and sky kept")
		check(p.Particles[1].Color == hex("FFFFFF"), "white petals kept")
	end
	print(string.format("PLAZA CHECKS pass=%d fail=%d", pass, fail))
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
local function placedCount(m) -- WORLD=2: draft placements standing in a track's Environment
	local n = 0
	for _, c in m.Environment:GetChildren() do
		n += string.match(c.Name, "^Placed_") and 1 or 0
	end
	return n
end
local built, plaza, finish = {}, {}, {}
local builtHeroes = {} -- track -> designed prop name -> built (before any Prune), for the hero check's message
for i, m in models do
	built[i] = placedCount(m)
	builtHeroes[i] = {}
	local theme = process.env.WORLD == "2" and req(Shared.BiomeThemes)[entries[i].Biome]
	for _, c in m.Environment:GetChildren() do
		local k = theme and theme.Placed and tonumber(string.match(c.Name, "^Placed_(%d+)$"))
		if k then
			builtHeroes[i][designed(theme.Placed[k][1])] = true
		end
	end
end
if process.env.WORLD == "2" then -- first what the other tracks and the spawn area remove, then the own finish pieces
	for i, m in models do
		local others = table.clone(models)
		table.remove(others, i)
		BD.Prune(others, { spawnArea }, { m })
		plaza[i] = placedCount(m)
		local stub = R.Instance.new("Model") -- the own Checkpoint (finish area and WinPad) without the Road and Walls
		m.Checkpoint:Clone().Parent = stub
		BD.Prune({ stub }, nil, { m })
		finish[i] = placedCount(m)
	end
end
BD.Prune(models, { spawnArea })
if process.env.WORLD == "2" then -- draft placements kept by the budget and own-ground rule (built), then by Prune (kept)
	local Themes = req(Shared.BiomeThemes)
	-- WORLD2_SPEC 2026-11-24: draft props are road-tested at export against every track (export_props.py, real
	-- triangles), so in the built result (a) every hero of each approved biome (its draft's Heroes, MODEL_SHOTS) has a
	-- kept placement, and (b) no kept Placed_ prop intrudes on another track's corridor. (b) approximates the exporter's
	-- triangle test: each part's box centre (a mesh is one box here) within 24 studs of another track's centre line and
	-- from its road top to 14 over it. A box is coarser than the triangles and every draft placement already passed the
	-- exporter's test, so a (b) hit is a "W2 ROAD WARN" line, not a FAIL. Prints "W2 ROAD FAIL <check>" and
	-- "W2 ROAD CHECKS pass=<n> fail=<n> warn=<n>".
	do
		local rpass, rfail, rwarn = 0, 0, 0
		local function rcheck(ok, name)
			if ok then
				rpass += 1
			else
				rfail += 1
				print("W2 ROAD FAIL " .. name)
			end
		end
		-- Each centre-line segment as clearance.py's corridor box: along it (2 studs past each end), 24 to each side,
		-- from its road top to 14 over its higher end. A part's oriented box against them (separating axes), every
		-- track, its own too unless the prop is in its biome's CLEAR_EXEMPT.
		local CELL = 64
		local grid = {}
		for i, e in entries do
			local wps = e.Layout.WorldWaypoints
			for j = 1, #wps - 1 do
				local a, b = wps[j], wps[j + 1]
				local d = R.Vector3.new(b.X - a.X, 0, b.Z - a.Z)
				if d.Magnitude > 1e-6 then
					local u = d.Unit
					local lo, hi = math.min(a.Y, b.Y) + 0.05, math.max(a.Y, b.Y) + 14
					local box = {
						i,
						R.CFrame.fromMatrix(
							R.Vector3.new((a.X + b.X) / 2, (lo + hi) / 2, (a.Z + b.Z) / 2),
							R.Vector3.new(-u.Z, 0, u.X),
							R.Vector3.yAxis
						),
						R.Vector3.new(24, (hi - lo) / 2, d.Magnitude / 2 + 2),
					}
					local r = d.Magnitude / 2 + 2 + 24
					local cx, cz = (a.X + b.X) / 2, (a.Z + b.Z) / 2
					for gx = math.floor((cx - r) / CELL), math.floor((cx + r) / CELL) do
						for gz = math.floor((cz - r) / CELL), math.floor((cz + r) / CELL) do
							local k = gx .. "," .. gz
							grid[k] = grid[k] or {}
							table.insert(grid[k], box)
						end
					end
				end
			end
		end
		local function sat(ca, ha, cb, hb)
			local A = { ca.RightVector, ca.UpVector, ca.LookVector }
			local B = { cb.RightVector, cb.UpVector, cb.LookVector }
			local la, lb = { ha.X, ha.Y, ha.Z }, { hb.X, hb.Y, hb.Z }
			local t = cb.Position - ca.Position
			local axes = { A[1], A[2], A[3], B[1], B[2], B[3] }
			for x = 1, 3 do
				for y = 1, 3 do
					table.insert(axes, A[x]:Cross(B[y]))
				end
			end
			for _, ax in axes do
				if ax.Magnitude > 1e-6 then
					ax = ax.Unit
					local ra, rb = 0, 0
					for k = 1, 3 do
						ra += math.abs(A[k]:Dot(ax)) * la[k]
						rb += math.abs(B[k]:Dot(ax)) * lb[k]
					end
					if math.abs(t:Dot(ax)) >= ra + rb then
						return false
					end
				end
			end
			return true
		end
		for i, e in entries do
			if table.find(W2_APPROVED, e.Biome) then
				local draftModule =
					Shared:FindFirstChild("BiomeThemes"):FindFirstChild("World2"):FindFirstChild(e.Biome .. "Draft")
				local heroes = draftModule and req(draftModule).Heroes
				rcheck(heroes ~= nil, e.Biome .. " draft lists its Heroes")
				local py = fs.readFile(ROOT .. "/tools/blender/world2/biomes/" .. e.Biome .. ".py")
				local exempt = {}
				for n in string.gmatch(string.match(py, "\nCLEAR_EXEMPT = {([^}]*)}") or "", '"(%w+)"') do
					exempt[n] = true
				end
				local kept, bad = {}, {}
				for _, prop in models[i].Environment:GetChildren() do
					local k = tonumber(string.match(prop.Name, "^Placed_(%d+)$"))
					local name = k and Themes[e.Biome].Placed[k][1]
					local ps = name and parts(prop) or {}
					if #ps > 0 then -- a hero counts only with something built (a mesh or its fallback parts)
						kept[designed(name)] = (kept[designed(name)] or 0) + 1
					end
					for _, part in ps do
						local half = part.Size / 2
						local cf = part.CFrame
						local ext = R.Vector3.new(
							math.abs(cf.RightVector.X) * half.X
								+ math.abs(cf.UpVector.X) * half.Y
								+ math.abs(cf.LookVector.X) * half.Z,
							0,
							math.abs(cf.RightVector.Z) * half.X
								+ math.abs(cf.UpVector.Z) * half.Y
								+ math.abs(cf.LookVector.Z) * half.Z
						)
						local seen = {}
						for gx = math.floor((cf.X - ext.X) / CELL), math.floor((cf.X + ext.X) / CELL) do
							for gz = math.floor((cf.Z - ext.Z) / CELL), math.floor((cf.Z + ext.Z) / CELL) do
								for _, box in grid[gx .. "," .. gz] or {} do
									if not seen[box] and not (box[1] == i and exempt[designed(name)]) then
										seen[box] = true
										if sat(cf, half, box[2], box[3]) then
											bad[prop.Name .. " " .. name .. " on track " .. box[1]] = true
										end
									end
								end
							end
						end
					end
				end
				for _, hero in heroes or {} do
					local inDraft = false
					for _, pe in Themes[e.Biome].Placed do
						inDraft = inDraft or designed(pe[1]) == hero
					end
					rcheck(
						kept[hero] ~= nil,
						string.format(
							"%s hero %s has a kept placement (%s)",
							e.Biome,
							hero,
							not inDraft and "dropped at export"
								or builtHeroes[i][hero] and "built, then removed by Prune"
								or "in the draft, not built: budget or own-ground rule"
						)
					)
				end
				local list = {}
				for what in bad do
					table.insert(list, what)
				end
				table.sort(list)
				for _, what in list do
					print(
						"W2 ROAD WARN "
							.. e.Biome
							.. " box test hit (the exporter's triangle test cleared it): "
							.. what
					)
				end
				rwarn += #list
			end
		end
		print(string.format("W2 ROAD CHECKS pass=%d fail=%d warn=%d", rpass, rfail, rwarn))
	end
	for i, e in entries do -- shadow casters among the kept draft props (Kit.fromDraft's NO_SHADOW)
		local casters = 0
		for _, prop in models[i].Environment:GetChildren() do
			if string.match(prop.Name, "^Placed_") then
				for _, part in parts(prop) do
					if part.CastShadow and part.Transparency < 1 then
						casters += 1
						break
					end
				end
			end
		end
		print(string.format("W2 SHADOW %s casters %d", e.Biome, casters))
	end
	for i, e in entries do
		local total = Themes[e.Biome].Placed and #Themes[e.Biome].Placed or 0
		print(
			string.format(
				"W2 PLACED %s total %d built %d clear of other tracks and the plaza %d kept %d",
				e.Biome,
				total,
				built[i],
				plaza[i],
				placedCount(models[i])
			)
		)
	end
	-- Owner 2026-11-23 (WORLD2_SPEC "Render set approvals"): an approved draft's placements keep the draft's own
	-- clearance, so their own track's Road and Walls remove none of them in Prune (other tracks' roads, the spawn area
	-- and the own finish pieces still do, counted before the test). WARN only: the placements (but the draft's CLEAR_EXEMPT spans / supports, read from
	-- tools/blender/world2/biomes/<Key>.py) whose footprint comes within 24 studs of their track's centre line, counting
	-- only parts reaching the band from the road top to 14 studs over it. The footprint is each part's box (a mesh is one
	-- box here); clearance.py's vertex test is the authority (WORLD2_SPEC).
	local pass, fail = 0, 0
	for i, e in entries do
		if table.find(W2_APPROVED, e.Biome) then
			print(
				string.format("INFO W2 %s own finish area removed %d draft placements", e.Biome, plaza[i] - finish[i])
			)
			local removed = finish[i] - placedCount(models[i])
			if removed == 0 then
				pass += 1
			else
				fail += 1
				print(
					string.format(
						"W2 FAIL %s Prune removed %d draft placements for their own Road or Walls",
						e.Biome,
						removed
					)
				)
			end
			local py = fs.readFile(ROOT .. "/tools/blender/world2/biomes/" .. e.Biome .. ".py")
			local exempt = {}
			for name in string.gmatch(string.match(py, "\nCLEAR_EXEMPT = {([^}]*)}") or "", '"(%w+)"') do
				exempt[name] = true
			end
			local wps = e.Layout.WorldWaypoints
			local close = {}
			local function seen(d, name)
				if d < 24 then
					close[name] = math.min(close[name] or d, d)
				end
			end
			for _, prop in models[i].Environment:GetChildren() do
				local k = tonumber(string.match(prop.Name, "^Placed_(%d+)$"))
				local key = k and Themes[e.Biome].Placed[k][1]
				local name = key and prop.Name .. " " .. key
				for _, part in key and not exempt[key] and parts(prop) or {} do
					local h = part.Size / 2
					local lo, hi, road, best = math.huge, -math.huge, nil, math.huge
					for _, c in
						{
							{ 1, 1, 1 },
							{ 1, 1, -1 },
							{ 1, -1, 1 },
							{ 1, -1, -1 },
							{ -1, 1, 1 },
							{ -1, 1, -1 },
							{ -1, -1, 1 },
							{ -1, -1, -1 },
						}
					do
						local y = part.CFrame:PointToWorldSpace(R.Vector3.new(c[1] * h.X, c[2] * h.Y, c[3] * h.Z)).Y
						lo, hi = math.min(lo, y), math.max(hi, y)
					end
					for _, w in wps do
						local d = (w.X - part.Position.X) ^ 2 + (w.Z - part.Position.Z) ^ 2
						if d < best then
							best, road = d, w.Y
						end
					end
					if hi <= road or lo >= road + 14 then
						continue -- under the road top, or 14+ overhead
					end
					for _, w in wps do -- the road running through the footprint
						local q = part.CFrame:PointToObjectSpace(R.Vector3.new(w.X, part.Position.Y, w.Z))
						if math.abs(q.X) <= h.X and math.abs(q.Z) <= h.Z then
							seen(0, name)
						end
					end
					for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
						for _, y in { 1, -1 } do
							local p = part.CFrame:PointToWorldSpace(R.Vector3.new(c[1] * h.X, y * h.Y, c[2] * h.Z))
							for j = 1, #wps - 1 do
								local a, b = wps[j], wps[j + 1]
								local ab = R.Vector3.new(b.X - a.X, 0, b.Z - a.Z)
								local ap = R.Vector3.new(p.X - a.X, 0, p.Z - a.Z)
								local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-9), 0, 1)
								seen((ap - ab * t).Magnitude, name)
							end
						end
					end
				end
			end
			local near = {}
			for name, d in close do
				table.insert(near, { name, d })
			end
			table.sort(near, function(a, b)
				return a[2] < b[2]
			end)
			for j, n in near do
				near[j] = string.format("%s %.1f", n[1], n[2])
			end
			if #near > 0 then
				print(string.format("WARN W2 %s box footprint < 24 studs: %s", e.Biome, table.concat(near, ", ")))
			end
		end
	end
	print(string.format("W2 DRAFT CLEARANCE pass=%d fail=%d", pass, fail))
	-- tools/blender/world2/chain.py (the drafts' and the exporter's road) against the game's chain: every world
	-- waypoint of build/world2/chain.json within 0.05 studs of TrackBuilder's (run chain.py first)
	local ok, text = pcall(fs.readFile, ROOT .. "/build/world2/chain.json")
	if ok then
		local chain, worst, same = require("@lune/serde").decode("json", text), 0, #entries == 10
		for i, e in entries do
			local wps, py = e.Layout.WorldWaypoints, chain[i] and chain[i].Waypoints or {}
			same = same and #wps == #py
			for j = 1, math.min(#wps, #py) do
				local w, p = wps[j], py[j]
				worst = math.max(worst, math.abs(w.X - p[1]), math.abs(w.Y - p[2]), math.abs(w.Z - p[3]))
			end
		end
		print(string.format("W2 CHAIN PARITY %s worst %.3f studs", same and worst <= 0.05 and "pass" or "FAIL", worst))
	else
		print("W2 CHAIN PARITY skipped: no build/world2/chain.json")
	end
end
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
		if
			prop:IsA("Model")
			and (prop:GetAttribute("Pad") or prop:GetAttribute("Pinned"))
			and not prop:GetAttribute("Tunnel") -- on the tunnel floor, not the terrain (fw6 checks below)
		then
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
	-- fw8: the same over the tracks whose biome has no Tunnel only (their props, and the columns in their corridors),
	-- so a tunnel change can show it leaves every other biome alone
	local Themes = req(Shared.BiomeThemes)
	local own, nOwn = {}, 0
	for _, e in entries do
		own[e.Number] = Themes[e.Biome] and Themes[e.Biome].Tunnel ~= nil
	end
	h = 0
	for x = box.Min.X + 900, box.Max.X - 900, 8 do
		for z = box.Min.Y + 900, box.Max.Y - 900, 8 do
			local A, dA = TS._sample(x, z)
			if A and own[A] == false and dA <= TS.CORRIDOR then
				local y, w, m = TS.Column(x, z)
				mix(math.floor(y * 1000 + 0.5))
				mix(w and math.floor(w * 1000 + 0.5) or 7)
				mix(m.Value)
			end
		end
	end
	for _, e in entries do
		if own[e.Number] == false then
			for _, prop in e.Model:FindFirstChild("Environment"):GetChildren() do
				local p = prop:IsA("Model") and prop:GetPivot().Position or prop.Position
				mix(math.floor(p.X * 100 + 0.5) % 1000003)
				mix(math.floor(p.Y * 100 + 0.5) % 1000003)
				mix(math.floor(p.Z * 100 + 0.5) % 1000003)
				nOwn += 1
			end
		end
	end
	print(string.format("IDENTITY no-tunnel tracks hash %d props %d", h, nOwn))
	-- per track: its corridor columns, then its props (to find what a change moved)
	local per = {}
	for x = box.Min.X + 900, box.Max.X - 900, 8 do
		for z = box.Min.Y + 900, box.Max.Y - 900, 8 do
			local A, dA = TS._sample(x, z)
			if A and dA <= TS.CORRIDOR then
				local y = TS.Column(x, z)
				per[A] = ((per[A] or 0) * 31 + math.floor(y * 1000 + 0.5)) % 2147483647
			end
		end
	end
	local line = {}
	for _, e in entries do
		local ph = 0
		for _, prop in e.Model:FindFirstChild("Environment"):GetChildren() do
			local p = prop:IsA("Model") and prop:GetPivot().Position or prop.Position
			ph = (ph * 31 + math.floor(p.X * 100 + 0.5) % 1000003) % 2147483647
			ph = (ph * 31 + math.floor(p.Y * 100 + 0.5) % 1000003) % 2147483647
			ph = (ph * 31 + math.floor(p.Z * 100 + 0.5) % 1000003) % 2147483647
		end
		table.insert(line, string.format("%d:%d/%d", e.Number, per[e.Number] or 0, ph))
	end
	print("IDENTITY per track (corridor/props) " .. table.concat(line, " "))
	if process.env.DUMP then -- DUMP=<file>: every prop's pivot, to diff two runs
		local out = {}
		for _, e in entries do
			for _, prop in e.Model:FindFirstChild("Environment"):GetChildren() do
				local p = prop:IsA("Model") and prop:GetPivot().Position or prop.Position
				table.insert(out, string.format("%d %s %.2f %.2f %.2f", e.Number, prop.Name, p.X, p.Y, p.Z))
			end
		end
		fs.writeFile(process.env.DUMP, table.concat(out, "\n"))
	end
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
			local segs, s0, s1, total, prof = Tunnel.Segments(e.Layout, e.Origin, def)
			-- fw8: a segment's inner half-width on `sgn`'s side at piece-local z (From at +Length / 2, To at -)
			local function wallAt(seg, sgn, z)
				local a, b = sgn < 0 and seg.LeftA or seg.RightA, sgn < 0 and seg.LeftB or seg.RightB
				local u = math.clamp(0.5 - z / seg.Length, 0, 1)
				return a + (b - a) * u
			end
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
			-- fw8: Studio test 1's corridor_clear on this track, offline. Centre line resampled every 20 studs (and every
			-- waypoint); each voxel column (centres at 2 mod 4) within road half-width + CLEARANCE of the segment to the
			-- neighbouring samples, filled as TerrainBuilder writes it (occupancy LIFT lower, the hollow from lo to hi);
			-- a hit is any filled voxel whose top is above the sample's road Y - 0.5 and whose bottom is below road Y + 12.
			do
				local lift = 2 -- TerrainBuilder.LIFT (server module, not loaded here)
				local wps, pts = e.Layout.WorldWaypoints, {}
				table.insert(pts, wps[1])
				for i = 2, #wps do
					local a, b = wps[i - 1], wps[i]
					local len = (b - a).Magnitude
					local at = 20
					while at < len do
						table.insert(pts, a:Lerp(b, at / len))
						at += 20
					end
					table.insert(pts, b)
				end
				local reach = e.Layout.Width / 2 + BD.CLEARANCE
				local hits, first, colMemo = 0, nil, {}
				local function column(x, z)
					local k = x .. "," .. z
					if not colMemo[k] then
						colMemo[k] = table.pack(TS.Column(x, z))
					end
					return colMemo[k]
				end
				-- fw9: TerrainBuilder.writeChunk writes voxels only from its chunk's y0 (a voxel under the lowest column)
				-- and FillBlocks Rock below; y0 must come from the hollow floors too, or the hollow under earth fills
				local chunkMemo = {}
				local function chunkY0(x, z)
					local cx, cz = math.floor(x / 256) * 256, math.floor(z / 256) * 256
					local k = cx .. "," .. cz
					if not chunkMemo[k] then
						local low = math.huge
						for ix = cx + 2, cx + 256, 4 do
							for iz = cz + 2, cz + 256, 4 do
								local c = column(ix, iz)
								low = math.min(low, c[6] or c[1]) -- the top, or the hollow floor (fw9)
							end
						end
						chunkMemo[k] = math.floor(low / 4) * 4 - 4
					end
					return chunkMemo[k]
				end
				for i, p in pts do
					local a, b = pts[math.max(1, i - 1)], pts[math.min(#pts, i + 1)]
					local lo, hi = p.Y - 0.5, p.Y + 12
					local bad = false
					for cx = math.floor((p.X - reach) / 4) * 4 + 2, p.X + reach, 4 do
						for cz = math.floor((p.Z - reach) / 4) * 4 + 2, p.Z + reach, 4 do
							local dx, dz = b.X - a.X, b.Z - a.Z
							local len2 = dx * dx + dz * dz
							local u = len2 > 1e-9 and math.clamp(((cx - a.X) * dx + (cz - a.Z) * dz) / len2, 0, 1) or 0
							if R.Vector2.new(a.X + dx * u - cx, a.Z + dz * u - cz).Magnitude <= reach then
								local c = column(cx, cz)
								local y, w, tlo, thi = c[1], c[2], c[6], c[7]
								for yb = math.floor(lo / 4) * 4 - 4, hi, 4 do
									local inHole = tlo and yb < thi
									local o = math.clamp(((inHole and tlo or y) - lift - yb) / 4, 0, 1)
									if yb < chunkY0(cx, cz) then
										o = 1 -- the chunk's Rock FillBlock
									end
									local top = o > 0 and yb + o * 4
									if not top and w and not inHole and yb < w - lift then
										top = yb + math.clamp((w - lift - yb) / 4, 0, 1) * 4
									end
									if top and top > lo and yb < hi then
										bad = true
										first = first
											or string.format(
												"%.0f,%.1f,%.0f road %.1f (column top %.1f hollow %s-%s)",
												cx,
												top,
												cz,
												p.Y,
												y,
												tostring(tlo),
												tostring(thi)
											)
									end
								end
							end
						end
					end
					hits += bad and 1 or 0
				end
				print(
					string.format(
						"TUNNEL %s corridor_clear: %d samples, %d hits (first %s)",
						e.Model.Name,
						#pts,
						hits,
						tostring(first)
					)
				)
			end
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
			-- fw6 1(a): every prop of a non-Surface layer (attribute Tunnel) has all 8 box corners inside the walls
			-- under the ceiling, at road level within Width / 2 or on a bay platform (road + PLATFORM) past it; any
			-- other prop but the gate must come from a Surface layer. 1(b): each pinned hero stands in a bay, on the
			-- side of that bay. The gate stands before the start portal.
			-- a box corner (or the base centre, `floor`: it stands on the road or the platform) is inside: across
			-- the walls, under the ceiling, on a bay side past Width / 2. A prop on a slope is flat, so only its base
			-- centre is held to the floor. A segment reaches past its ends by the bend's wedge (as Tunnel parts do).
			local half = Tunnel.Edge(def, prof) -- fw8: the bay platform's road-side edge
			local function inside(p, floor, reach)
				local eps = 0.05 + Tunnel.CHORD_Y
				for _, seg in segs do
					local l = seg.CFrame:PointToObjectSpace(p)
					local x, y = l.X, l.Y
					if math.abs(l.Z) <= seg.Length / 2 + 1 + math.abs(x) * math.max(seg.TanStart, seg.TanEnd) then
						local bay = if x < 0 then seg.BayLeft else seg.BayRight
						-- fw8: past the platform edge only a bay has a platform; elsewhere the floor runs to the wall
						local floorY = bay and math.abs(x) > half + eps and Tunnel.PLATFORM or 0
						if
							x >= -wallAt(seg, -1, l.Z) - eps
							and x <= wallAt(seg, 1, l.Z) + eps
							and y <= seg.Height + eps
							-- a flat base on a pitched segment: off by up to sin(pitch) x its reach
							and (not floor or math.abs(y - floorY) <= eps + math.sqrt(1 - seg.Flat ^ 2) * reach)
						then
							return true, x, floorY
						end
					end
				end
				return false
			end
			local nIn, nBay, nOut, nOther, pins, pinsOk = 0, 0, 0, 0, 0, 0
			for _, prop in e.Model:FindFirstChild("Environment"):GetChildren() do
				if prop:GetAttribute("FightScene") then
					continue -- its dome is sunk into the platform; checked below
				elseif prop:GetAttribute("Tunnel") then
					-- every part's 8 corners (the model box here is oriented like its first part, which may be turned)
					local ok, lowY, cx, cz, n, pts = true, math.huge, 0, 0, 0, {}
					for _, part in prop:GetDescendants() do
						if not part:IsA("BasePart") then
							continue
						end
						for _, c in { -1, 1 } do
							for _, d in { -1, 1 } do
								for _, f in { -1, 1 } do
									local p = part.CFrame:PointToWorldSpace(R.Vector3.new(c, d, f) * part.Size / 2)
									ok = ok and inside(p)
									lowY = math.min(lowY, p.Y)
									table.insert(pts, p)
								end
							end
						end
						cx, cz, n = cx + part.Position.X, cz + part.Position.Z, n + 1
					end
					local reach = 0
					for _, p in pts do
						reach = math.max(reach, R.Vector2.new(p.X - cx / n, p.Z - cz / n).Magnitude)
					end
					local okBase, x, floorY = inside(R.Vector3.new(cx / n, lowY, cz / n), true, reach)
					ok = ok and okBase
					local size = select(2, prop:GetBoundingBox())
					local onBay = floorY == Tunnel.PLATFORM -- fw8: raised onto a bay platform
					nIn += ok and 1 or 0
					nOut += ok and 0 or 1
					nBay += (ok and onBay) and 1 or 0
					if not ok and nOut <= 5 then
						-- the first corner outside, in the piece-local frame of the nearest segment along it
						local why = ""
						for _, p in pts do
							if not inside(p) then
								local best, bl
								for _, seg in segs do
									local l = seg.CFrame:PointToObjectSpace(p)
									if
										math.abs(l.Z) <= seg.Length / 2 + 1
										and (not best or math.abs(l.X) < math.abs(bl.X))
									then
										best, bl = seg, l
									end
								end
								why = best
										and string.format(
											"corner x %.2f y %.2f z %.1f of %.1f; wall %.2f / %.2f, height %.1f, s %.0f-%.0f",
											bl.X,
											bl.Y,
											bl.Z,
											best.Length,
											-wallAt(best, -1, bl.Z),
											wallAt(best, 1, bl.Z),
											best.Height,
											best.From,
											best.To
										)
									or "no segment"
								break
							end
						end
						if why == "" then
							local b = R.Vector3.new(cx / n, lowY, cz / n)
							local best, bl
							for _, seg in segs do
								local l = seg.CFrame:PointToObjectSpace(b)
								if
									math.abs(l.Z) <= seg.Length / 2 + 1 and (not best or math.abs(l.X) < math.abs(bl.X))
								then
									best, bl = seg, l
								end
							end
							why = best
									and string.format(
										"base not on the floor: x %.2f y %.2f, bay %s, s %.0f-%.0f, flat %.3f",
										bl.X,
										bl.Y,
										tostring(if bl.X < 0 then best.BayLeft else best.BayRight),
										best.From,
										best.To,
										best.Flat
									)
								or "base not on the floor"
						end
						print(
							string.format(
								"  prop %s not inside the tunnel (size %s): %s",
								prop.Name,
								tostring(size),
								why
							)
						)
					end
					if prop:GetAttribute("Pinned") then
						pins += 1
						pinsOk += (ok and onBay) and 1 or 0
						print(
							string.format(
								"  pinned %s inside=%s side x %.1f on bay=%s",
								prop.Name,
								tostring(ok),
								x or 0,
								tostring(onBay)
							)
						)
					end
				elseif prop.Name ~= "Gate" then
					nOther += 1
				end
			end
			local gateAt = "none"
			local g = e.Model:FindFirstChild("Environment"):FindFirstChild("Gate")
			if g and #segs > 0 then
				local l = segs[1].CFrame:PointToObjectSpace(g:FindFirstChild("GateBeam").Position)
				gateAt = string.format("%.1f studs before the portal face", l.Z - segs[1].Length / 2)
			end
			print(
				string.format(
					"TUNNEL %s props: inside %d (on bays %d), not inside %d, not tunnel (Surface) %d; pinned in their bay %d/%d; gate %s",
					e.Model.Name,
					nIn,
					nBay,
					nOut,
					nOther,
					pinsOk,
					pins,
					gateAt
				)
			)
			-- fw8 (owner 2026-11-01, very wide throughout): the per-side inner width outside bays (by length), the
			-- ceiling outside bays, the terrain box (walls + MARGIN) and every tunnel part's footprint against other
			-- tracks' corridors (CORRIDOR from their centre lines), and the props: per 100 studs, the longest stretch
			-- without one per side, and corners in the running lane (road half-width) or its clearance (+ wall +
			-- CLEARANCE)
			do
				local W, MG = Tunnel.WALL, Tunnel.MARGIN
				local st = {}
				for _, key in { "L", "R" } do
					st[key] = { lo = math.huge, hi = -math.huge, sum = 0, len = 0 }
				end
				local cLo, cHi, mainLen = math.huge, -math.huge, 0
				for _, seg in segs do
					local len = seg.To - seg.From
					for key, w in
						{ L = { seg.BayLeft, seg.LeftA, seg.LeftB }, R = { seg.BayRight, seg.RightA, seg.RightB } }
					do
						if not w[1] then
							local t = st[key]
							t.lo, t.hi = math.min(t.lo, w[2], w[3]), math.max(t.hi, w[2], w[3])
							t.sum += (w[2] + w[3]) / 2 * len
							t.len += len
						end
					end
					if not (seg.BayLeft or seg.BayRight) then
						cLo, cHi = math.min(cLo, seg.Height), math.max(cHi, seg.Height)
						mainLen += len
					end
				end
				for _, key in { "L", "R" } do
					local t = st[key]
					print(
						string.format(
							"TUNNEL %s width %s (half, outside bays): min %.1f avg %.1f max %.1f (target %.0f)",
							e.Model.Name,
							key == "L" and "left" or "right",
							t.lo,
							t.sum / math.max(1, t.len),
							t.hi,
							(def.Width or 60) / 2
						)
					)
				end
				local short = 0 -- stations whose raw room is below the width built (clamped to the road's minimum)
				for _, key in { "L", "R" } do
					for i, v in prof.Raw[key] do
						short += v < prof.Main[key][i] - 0.01 and 1 or 0
					end
				end
				print(
					string.format(
						"TUNNEL %s ceiling outside bays %.1f-%.1f; %d segments; stations short of room %d",
						e.Model.Name,
						cLo,
						cHi,
						#segs,
						short
					)
				)
				-- a point in another track's corridor, as TerrainShape decides it: that track is the nearest and within
				-- CORRIDOR (the junction with the previous and next track is this track's own ground)
				local function crosses(p)
					local A, dA = TS._sample(p.X, p.Y)
					if A and A ~= e.Number and dA <= TS.CORRIDOR then
						return "track " .. A
					end
					return nil
				end
				local boxHits, boxFirst = 0, nil
				for _, seg in segs do
					local cf = seg.CFrame
					local f = R.Vector2.new(cf.LookVector.X, cf.LookVector.Z).Unit
					local rv = R.Vector2.new(-f.Y, f.X)
					local c = R.Vector2.new(cf.Position.X, cf.Position.Z)
					local hz = seg.Length * seg.Flat / 2 + MG
					for z = -hz, hz + 0.01, 4 do
						for _, x in { -(seg.Left + W + MG), seg.Right + W + MG } do
							local who = crosses(c + f * math.min(z, hz) + rv * x)
							if who then
								boxHits += 1
								boxFirst = boxFirst or string.format("%s at s %.0f x %.0f", who, seg.From, x)
							end
						end
					end
				end
				local partHits, portalHits, partFirst = 0, 0, nil
				for _, part in folder:GetDescendants() do
					if part:IsA("BasePart") then
						local hx, hz = part.Size.X / 2, part.Size.Z / 2
						local hit
						-- the footprint's outline every 4 studs or less
						local function probe(x, z)
							local w = part.CFrame:PointToWorldSpace(R.Vector3.new(x, 0, z))
							hit = hit or crosses(R.Vector2.new(w.X, w.Z))
						end
						local nx, nz = math.ceil(hx / 2), math.ceil(hz / 2)
						for k = 0, nx do
							probe(-hx + 2 * hx * k / nx, -hz)
							probe(-hx + 2 * hx * k / nx, hz)
						end
						for k = 0, nz do
							probe(-hx, -hz + 2 * hz * k / nz)
							probe(hx, -hz + 2 * hz * k / nz)
						end
						if hit then
							if part.Name:match("^Portal") then
								portalHits += 1
							else
								partHits += 1
							end
							partFirst = partFirst or (part.Name .. " in " .. hit)
						end
					end
				end
				print(
					string.format(
						"TUNNEL %s corridor crossings: box samples %d (%s), parts %d, portal parts %d (%s)",
						e.Model.Name,
						boxHits,
						tostring(boxFirst),
						partHits,
						portalHits,
						tostring(partFirst)
					)
				)
				-- props: track position and side of each tunnel prop's pivot, and its part corners against the lane
				local function locate(p, from, to)
					local best, bi, bl
					for k = from or 1, to or #segs do
						local seg = segs[k]
						local l = seg.CFrame:PointToObjectSpace(p)
						if math.abs(l.Z) <= seg.Length / 2 + 2 and math.abs(l.Y) < 60 then
							if not best or math.abs(l.X) < best then
								best, bi, bl = math.abs(l.X), k, l
							end
						end
					end
					return bi, bl
				end
				local roadHalf = e.Layout.Width / 2
				local at = { L = {}, R = {} }
				local nMain, nAll, inLane, inClear = 0, 0, 0, 0
				for _, prop in e.Model:FindFirstChild("Environment"):GetChildren() do
					if prop:GetAttribute("Tunnel") and not prop:GetAttribute("FightScene") then
						local k, l = locate(prop:GetPivot().Position)
						if k then
							local seg = segs[k]
							local sAt = (seg.From + seg.To) / 2 - l.Z * seg.Flat
							local key = l.X < 0 and "L" or "R"
							table.insert(at[key], sAt)
							nAll += 1
							nMain += ((key == "L" and seg.BayLeft) or (key == "R" and seg.BayRight)) and 0 or 1
							local lane, clear = false, false
							for _, part in prop:GetDescendants() do
								if part:IsA("BasePart") then
									for _, c in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
										local w = part.CFrame:PointToWorldSpace(
											R.Vector3.new(c[1] * part.Size.X / 2, 0, c[2] * part.Size.Z / 2)
										)
										local _, q = locate(w, math.max(1, k - 3), math.min(#segs, k + 3))
										local x = q and math.abs(q.X) or math.huge
										lane = lane or x < roadHalf
										clear = clear or x < roadHalf + 2 + BD.CLEARANCE
									end
								end
							end
							inLane += lane and 1 or 0
							inClear += clear and 1 or 0
						end
					end
				end
				local gaps = {}
				for key, list in at do
					table.sort(list)
					local prev, worst = s0, 0
					for _, v in list do
						worst, prev = math.max(worst, v - prev), v
					end
					gaps[key] = math.max(worst, s1 - prev)
				end
				print(
					string.format(
						"TUNNEL %s tunnel props %d (outside bays %d): %.2f per 100 studs (outside bays %.2f per 100 studs of main tunnel); longest stretch without a prop: left %.0f, right %.0f; in the running lane %d, within the road clearance %d",
						e.Model.Name,
						nAll,
						nMain,
						nAll / (s1 - s0) * 100,
						nMain / math.max(1, mainLen) * 100,
						gaps.L,
						gaps.R,
						inLane,
						inClear
					)
				)
			end
			-- fw7: the fight scene is built (and survived Prune), and every part corner at or above the platform top
			-- is inside the bay box on its side: past Width / 2 on a bay segment, under the ceiling, inside the wall
			local scene = Themes[e.Biome].FightScene
			local group = e.Model:FindFirstChild("Environment"):FindFirstChild("FightScene")
			if scene then
				local sgn = scene.Side == "Right" and 1 or -1
				local corners, outBay, ceil, wall, nParts = 0, 0, 0, 0, 0
				for _, part in group and group:GetDescendants() or {} do
					if part:IsA("BasePart") then
						nParts += 1
						for _, c in { -1, 1 } do
							for _, d in { -1, 1 } do
								for _, f in { -1, 1 } do
									local p = part.CFrame:PointToWorldSpace(R.Vector3.new(c, d, f) * part.Size / 2)
									-- the nearest segment across whose length the corner lies (other turns of the track
									-- may line up along Z too)
									local found
									for _, seg in segs do
										local l = seg.CFrame:PointToObjectSpace(p)
										if
											math.abs(l.Z) <= seg.Length / 2 + 1
											and math.abs(l.Y) < 60
											and (not found or math.abs(l.X) < math.abs(found[2].X))
										then
											found = { seg, l }
										end
									end
									if found and found[2].Y >= Tunnel.PLATFORM - 0.05 then
										local seg, l = found[1], found[2]
										corners += 1
										local bay = if sgn < 0 then seg.BayLeft else seg.BayRight
										local inner = wallAt(seg, sgn, l.Z)
										if l.Y > seg.Height + 0.05 then
											ceil += 1
										end
										if l.X * sgn > inner + 0.05 then
											wall += 1
										end
										if not bay or l.X * sgn < half - 0.05 or l.X * sgn > inner + 0.05 then
											outBay += 1
										end
									elseif not found then
										outBay += 1
									end
								end
							end
						end
					end
				end
				print(
					string.format(
						"FIGHT %s built %s: items %s (no Def %s), parts %d, emitters %s, beams %s, lights %s, effects skipped %s; corners checked %d, outside the bay box %d, ceiling clip %d, wall clip %d",
						e.Model.Name,
						tostring(group ~= nil),
						tostring(group and group:GetAttribute("Items")),
						tostring(group and group:GetAttribute("MissingItems")),
						nParts,
						tostring(group and group:GetAttribute("Emitter")),
						tostring(group and group:GetAttribute("Beam")),
						tostring(group and group:GetAttribute("Light")),
						tostring(group and group:GetAttribute("Skipped")),
						corners,
						outBay,
						ceil,
						wall
					)
				)
			end
		end
	end
end
process.exit(failed and 1 or 0)
