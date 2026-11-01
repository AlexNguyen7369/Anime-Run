--!nonstrict
-- BRIEF (owner, 2026-10-20; design doc "Racing" > "Track environments", contract docs/BIOME_DRESSING_SPEC.md):
-- "every track has its own visual theme ... drive-by scenery". Spec "Acceptance (harness scenario `environment`)":
-- "For every chain track: an `Environment` folder exists and the `Biome` attribute is set; every BasePart in it is
-- anchored and has `CanCollide`, `CanTouch` and `CanQuery` false; after `Prune` no prop is within `CLEARANCE` of any
-- road, wall, checkpoint, pad or spawn-area part; the part count is within the budget; two builds give the same prop
-- names and CFrames; and `Lighting` is unchanged."
-- Also from the spec: the Biome table (track number -> Biome), `Shared/BiomeThemes[biome]`, a `Gate` at each track
-- start, local lights with `Shadows = false`, and no Atmosphere / Sky / Clouds from dressing.
-- Written before BiomeThemes, BiomeDressing.Prune/CLEARANCE/BUDGET and the Biome of tracks 1-5 exist: red by design.
-- Everything is built unparented (never in Workspace) and destroyed at the end.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackBuilder = require(Shared.TrackBuilder)
local TrackRegistry = require(Shared.TrackRegistry)
local RaceConfig = require(Shared.RaceConfig)
local NpcConfig = require(Shared.NpcConfig)
local HudFormat = require(Shared.HudFormat)

local Tests = {}

-- Spec "Themes": track number -> Biome
local BIOMES = { "Speedway", "Forest", "Docks", "Suburb", "PirateCoast", "City", "Desert", "Snow", "Volcano", "Space" }
-- Anime biomes (w4, docs/TRACKS_AND_BIOMES_SPEC.md "Biomes" table): track number -> working biome name, shown as the
-- theme's DisplayName. Theme keys (BIOMES) and track ids stay (owner 2026-10-30).
local BIOME_NAMES = {
	"Leafwind Village",
	"Tournament Wasteland",
	"Pirate Harbor Isle",
	"Wisteria Night Mountain",
	"Burning Cursed City",
	"Hero Academy City",
	"Blossom Shrine Path",
	"Skypeia",
	"Spirit Realm Desert",
	"Green Alien Planet",
}
local NIGHT_TRACKS = { 4, 5, 9 } -- spec "Night biomes (4, 5, 9) ... never change global Lighting"
-- Texture ids the fork inherited from IVS (BiomeMeshAssets before w4). Logic-only fork (design doc 5 "no ripped
-- model / texture"): no anime theme prop may resolve to one, and no theme or built instance may carry one.
local IVS_ASSET_IDS = {}
for _, id in
	{
		"92423737416544",
		"128394726145519",
		"85846093929544",
		"72274392470670",
		"91606076532126",
		"113770468212081",
		"95508523642574",
		"76676257187222",
		"85521508755919",
		"75698100170016",
		"103373710817708",
		"89929750979816",
		"124766458868838",
		"103593247926248",
		"135230145762047",
		"108440050975370",
		"127961462840313",
		"132366709821625",
		"79761841457379",
		"130180280383767",
		"87067139590673",
		"77211822777880",
		"115437395308843",
		"74620414108710",
		"128293532540657",
		"71357970279693",
		"140690212753632",
		"138118073743869",
		"93867391692488",
		"113366033365449",
		"103964466413530",
		"79033882912159",
		"135244581594694",
		"79454986937479",
		"83506704181258",
		"75606138619397",
		"93817877871959",
		"121949863588548",
		"123258403810822",
		"105771940584993",
		"113271510794732",
		"79832470988304",
		"119293630858724",
		"98025384367368",
		"81189885999508",
	}
do
	IVS_ASSET_IDS[id] = true
end
local CHAIN_ORIGIN = Vector3.new(-20000, 0, 20000) -- far from the play area and the other scenario origins
local GEOM_TOL = 0.05 -- studs of overlap ignored (boxes that only touch)
local CFRAME_TOL = 1e-3
local CELL = 64 -- broad-phase grid cell, studs
local LIGHT_TOL = 1e-3
local SIZE_TOL = 1e-3
local GROUND_TOP = -1 -- TrackBuilder GROUND_TOP (world Y of the grass top)
local GROUND_STEP = 0.02 -- contract: track N's ground top sits 0.02 * N below GROUND_TOP (no z-fighting)
local MAX_TRIANGLES = 20000
local MAX_VERTICES = 60000
-- Visual pass (owner 2026-10-26, spec Layers 7-8 and Acceptance "Added 2026-10-26")
local PARTICLE_MAX_RATE = 8 -- spec placeholder PARTICLE_MAX_RATE
local MIN_SCATTER = 10
local MIN_PATCHES = 5
local PATCH_THICKNESS = 0.2
local PATCH_GROUND_TOL = 0.05
-- Scale and detail (owner 2026-10-27, design doc Track environments; spec Rules "Budget", "Scale", "City skyscrapers")
local BUDGET = 1200 -- spec placeholder: BaseParts per track Environment
-- Owner 2026-10-30 (spec Biomes): the budget grows with track length, BUDGET parts per ~BUDGET_STUDS of track
-- (placeholder). Test reading: never below BUDGET.
local BUDGET_STUDS = 3000
-- Owner 2026-10-30 (spec Biomes): Track 1's gate is the plaza torii StartGate, next to its start. Test-side bound,
-- from the SpawnArea contract "walk spawn within 150 studs of that start".
local TORII_NEAR = 150
local WANT_SCALE = { Landmarks = 1.75, Horizon = 2, Scatter = 1.5 } -- spec placeholders; Rhythm and gate unscaled
local LAYER_OF_PREFIX = { Landmark_ = "Landmarks", Horizon_ = "Horizon", Scatter_ = "Scatter" }
local CITY = 6
local CITY_TOWER_PROPS = { Skyscraper = true, SkyscraperPink = true, Block = true, Skyline = true }
local CITY_TOWER_MIN_PARTS = 25
local CITY_TOWER_MIN_HEIGHT = 100 -- studs, model bounding box of the tallest City landmark
-- Populated city (owner 2026-10-27, design doc Track environments; spec Layers 9 Blocks, Rules "Theme budget")
local CITY_MIN_BLOCKS = 60
local BLOCK_SHRINK = 0.5 -- studs each footprint is shrunk by before the overlap test
local BLOCK_PROBE_STEP = 24 -- studs between coverage probes along straight road
local BLOCK_MIN_COVERAGE = 0.7

local function module(parent, name)
	local source = parent:FindFirstChild(name)
	if not source then
		return nil
	end
	local ok, value = pcall(require, source)
	return ok and type(value) == "table" and value or nil
end

local function report(name)
	local r = { scenario = name, pass = true, checks = {}, metrics = {} }
	local function flag(label, ok, value, limit)
		table.insert(
			r.checks,
			{ name = label, pass = ok == true, value = value or (ok and 1 or 0), limit = limit or 1 }
		)
		r.pass = r.pass and ok == true
	end
	return r, flag
end

local function baseParts(root)
	local out = {}
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
	end
	return out
end

-- Oriented box overlap (separating axis test). Touching or a gap = no overlap.
local function boxesOverlap(cfA, halfA, cfB, halfB)
	local a = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local b = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local ha = { halfA.X, halfA.Y, halfA.Z }
	local hb = { halfB.X, halfB.Y, halfB.Z }
	local t = cfB.Position - cfA.Position
	local function separated(axis)
		if axis.Magnitude < 1e-6 then
			return false
		end
		axis = axis.Unit
		local ra = math.abs(a[1]:Dot(axis)) * ha[1]
			+ math.abs(a[2]:Dot(axis)) * ha[2]
			+ math.abs(a[3]:Dot(axis)) * ha[3]
		local rb = math.abs(b[1]:Dot(axis)) * hb[1]
			+ math.abs(b[2]:Dot(axis)) * hb[2]
			+ math.abs(b[3]:Dot(axis)) * hb[3]
		return math.abs(t:Dot(axis)) >= ra + rb
	end
	for i = 1, 3 do
		if separated(a[i]) or separated(b[i]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separated(a[i]:Cross(b[j])) then
				return false
			end
		end
	end
	return true
end

-- World axis-aligned half extents of an oriented box
local function aabbHalf(cf, half)
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z,
		math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z,
		math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
	)
end

-- XZ footprint of a part's oriented box, shrunk by `shrink` on every side
local function footprint(part, shrink)
	local function flat(v)
		local f = Vector2.new(v.X, v.Z)
		return f.Magnitude > 1e-6 and f.Unit or Vector2.new(1, 0)
	end
	return {
		C = Vector2.new(part.Position.X, part.Position.Z),
		A = { flat(part.CFrame.RightVector), flat(part.CFrame.LookVector) },
		H = { math.max(0, part.Size.X / 2 - shrink), math.max(0, part.Size.Z / 2 - shrink) },
	}
end

-- 2D separating axis test; touching = no overlap
local function footprintsOverlap(a, b)
	local d = b.C - a.C
	for _, axis in { a.A[1], a.A[2], b.A[1], b.A[2] } do
		local ra = math.abs(a.A[1]:Dot(axis)) * a.H[1] + math.abs(a.A[2]:Dot(axis)) * a.H[2]
		local rb = math.abs(b.A[1]:Dot(axis)) * b.H[1] + math.abs(b.A[2]:Dot(axis)) * b.H[2]
		if math.abs(d:Dot(axis)) >= ra + rb then
			return false
		end
	end
	return true
end

local function footprintHas(f, point)
	local d = point - f.C
	return math.abs(d:Dot(f.A[1])) <= f.H[1] and math.abs(d:Dot(f.A[2])) <= f.H[2]
end

-- Obstacles: every road, wall, checkpoint (incl. WinPad) part of every track, plus the spawn area
local function obstacleGrid(trackModels, extra)
	local grid, list = {}, {}
	local function add(part)
		local half = part.Size / 2
		local ext = aabbHalf(part.CFrame, half)
		local p = part.Position
		local o = { CFrame = part.CFrame, Half = half, Min = p - ext, Max = p + ext, Name = part:GetFullName() }
		table.insert(list, o)
		for x = math.floor(o.Min.X / CELL), math.floor(o.Max.X / CELL) do
			for z = math.floor(o.Min.Z / CELL), math.floor(o.Max.Z / CELL) do
				local key = x .. "," .. z
				grid[key] = grid[key] or {}
				table.insert(grid[key], o)
			end
		end
	end
	for _, model in trackModels do
		for _, name in { "Road", "Walls", "Checkpoint" } do
			for _, part in baseParts(model:FindFirstChild(name)) do
				add(part)
			end
		end
		local pad = model:FindFirstChild("WinPad", true)
		if pad and pad:IsA("BasePart") and not pad:IsDescendantOf(model:FindFirstChild("Checkpoint") or pad) then
			add(pad)
		end
	end
	-- extra: one root Instance or a list of roots (spawn area, Dojos)
	for _, root in (typeof(extra) == "Instance" and { extra } or extra or {}) do
		for _, part in baseParts(root) do
			add(part)
		end
	end
	return grid, #list
end

-- First obstacle a prop box (grown by `grow` on every side) overlaps, or nil
local function firstHit(grid, part, grow)
	local half = part.Size / 2 + Vector3.one * grow
	local ext = aabbHalf(part.CFrame, half)
	local p = part.Position
	local mn, mx = p - ext, p + ext
	local seen = {}
	for x = math.floor(mn.X / CELL), math.floor(mx.X / CELL) do
		for z = math.floor(mn.Z / CELL), math.floor(mx.Z / CELL) do
			for _, o in grid[x .. "," .. z] or {} do
				if
					not seen[o]
					and mn.X < o.Max.X
					and mx.X > o.Min.X
					and mn.Y < o.Max.Y
					and mx.Y > o.Min.Y
					and mn.Z < o.Max.Z
					and mx.Z > o.Min.Z
				then
					seen[o] = true
					if boxesOverlap(part.CFrame, half, o.CFrame, o.Half) then
						return o
					end
				end
				seen[o] = true
			end
		end
	end
	return nil
end

local function buildChain(specs)
	local tracks = {}
	local origin = CFrame.new(CHAIN_ORIGIN + Vector3.new(0, TrackBuilder.TRACK_LIFT or 0, 0))
	for _, spec in specs do
		local model, layout = TrackBuilder.Build(spec, origin)
		table.insert(tracks, { Spec = spec, Model = model, Layout = layout, Origin = origin })
		origin = TrackBuilder.EndCFrame(layout, origin)
		task.wait() -- yield only: each long track is one big unyielding Build
	end
	return tracks
end

-- Sorted (name, CFrame) list of an Environment folder, for the determinism check
local function signature(env)
	local out = {}
	for _, part in baseParts(env) do
		local p = part.Position
		table.insert(
			out,
			{ Key = ("%s|%.1f|%.1f|%.1f"):format(part.Name, p.X, p.Y, p.Z), Name = part.Name, CFrame = part.CFrame }
		)
	end
	table.sort(out, function(x, y)
		return x.Key < y.Key
	end)
	return out
end

local function sameSignature(a, b)
	if #a ~= #b then
		return false, math.abs(#a - #b)
	end
	local worst = 0
	for i = 1, #a do
		if i % 2000 == 0 then
			task.wait() -- yield only
		end
		if a[i].Name ~= b[i].Name then
			return false, -1
		end
		local ca, cb = { a[i].CFrame:GetComponents() }, { b[i].CFrame:GetComponents() }
		for k = 1, 12 do
			worst = math.max(worst, math.abs(ca[k] - cb[k]))
		end
	end
	return worst <= CFRAME_TOL, worst
end

local function lightingSnapshot()
	local function count(parent, class)
		local n = 0
		for _, c in parent:GetChildren() do
			if c:IsA(class) then
				n += 1
			end
		end
		return n
	end
	return {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Ambient = Lighting.Ambient,
		Atmosphere = count(Lighting, "Atmosphere"),
		Sky = count(Lighting, "Sky"),
		Clouds = count(Workspace.Terrain, "Clouds"),
		FogEnd = Lighting.FogEnd,
		FogColor = Lighting.FogColor,
		ColorShift = Lighting.ColorShift_Top,
		Exposure = Lighting.ExposureCompensation,
		Children = #Lighting:GetChildren(), -- catches post effects (ColorCorrection, Bloom ...)
	}
end

local function colorDiff(a, b)
	return math.max(math.abs(a.R - b.R), math.abs(a.G - b.G), math.abs(a.B - b.B))
end

-- Every prop definition of a theme ({ Name, Size, Parts }), keyed by Name (first one wins)
local function themeProps(theme)
	local out, seen = {}, {}
	local function walk(t)
		if type(t) ~= "table" or seen[t] then
			return
		end
		seen[t] = true
		if type(t.Name) == "string" and typeof(t.Size) == "Vector3" and type(t.Parts) == "table" then
			out[t.Name] = out[t.Name] or t
		end
		for _, v in t do
			walk(v)
		end
	end
	walk(theme)
	return out
end

-- Baked mesh entry rules: { Size = Vector3, Data = base64 } decoding to u16 vc, u16 ic, vc*10 bytes, ic u16 indices
-- Every rbxassetid number in a theme's strings, as a list
local function themeAssetIds(theme)
	local out, seen = {}, {}
	local function walk(t)
		if type(t) == "string" then
			for id in string.gmatch(t, "rbxassetid://(%d+)") do
				table.insert(out, id)
			end
		elseif type(t) == "table" and not seen[t] then
			seen[t] = true
			for k, v in t do
				walk(k)
				walk(v)
			end
		end
	end
	walk(theme)
	return out
end

-- Every string in a theme (keys and values), for the real-name check
local function themeStrings(theme)
	local out, seen = {}, {}
	local function walk(t)
		if type(t) == "string" then
			table.insert(out, t)
		elseif type(t) == "table" and not seen[t] then
			seen[t] = true
			for k, v in t do
				walk(k)
				walk(v)
			end
		end
	end
	walk(theme)
	return out
end

local function nameKey(text)
	return (string.gsub(string.lower(text), "[^%w]+", "_"))
end

local function meshEntryProblem(codec, entry)
	if type(entry) ~= "table" or typeof(entry.Size) ~= "Vector3" or type(entry.Data) ~= "string" then
		return "shape"
	end
	if entry.Size.X <= 0 or entry.Size.Y <= 0 or entry.Size.Z <= 0 then
		return "size"
	end
	local ok, blob = pcall(codec.Decode, entry.Data)
	if not ok or type(blob) ~= "buffer" or buffer.len(blob) < 4 then
		return "decode"
	end
	local vc, ic = buffer.readu16(blob, 0), buffer.readu16(blob, 2)
	if buffer.len(blob) ~= 4 + vc * 10 + ic * 2 then
		return "length"
	end
	if ic % 3 ~= 0 or ic // 3 > MAX_TRIANGLES or vc > MAX_VERTICES then
		return "counts"
	end
	local base = 4 + vc * 10
	for k = 0, ic - 1 do
		if buffer.readu16(blob, base + k * 2) >= vc then
			return "index"
		end
	end
	return nil
end

-- The theme prop a built prop Model comes from: its Mesh attribute, else its first fallback part's name
-- without the trailing number (parts are named <Prop><i>)
local function propNameOf(model, biome)
	local mesh = model:GetAttribute("Mesh")
	if type(mesh) == "string" and string.sub(mesh, 1, #biome + 1) == biome .. "_" then
		return string.sub(mesh, #biome + 2)
	end
	for _, c in model:GetChildren() do
		if c:IsA("BasePart") and c.Name ~= "MeshBounds" then
			return (string.gsub(c.Name, "%d+$", ""))
		end
	end
	return nil
end

function Tests.environment()
	local r, flag = report("environment")
	local Dressing = module(Shared, "BiomeDressing")
	local Themes = module(Shared, "BiomeThemes")
	local SpawnArea = module(Shared, "SpawnArea")
	flag("dressing_module", Dressing ~= nil)
	flag("themes_module", Themes ~= nil)
	local clearance = Dressing and Dressing.CLEARANCE
	local budget = Dressing and Dressing.BUDGET
	flag("clearance_value", clearance == 8, type(clearance) == "number" and clearance or -1, 8)
	flag("budget_value", budget == BUDGET, type(budget) == "number" and budget or -1, BUDGET)
	-- Scale rule (owner 2026-10-27): SCALE = { Landmarks = 1.75, Horizon = 2, Scatter = 1.5 }
	local scale = Dressing and type(Dressing.SCALE) == "table" and Dressing.SCALE or nil
	flag("scale_table", scale ~= nil)
	for layer, want in WANT_SCALE do
		local got = scale and scale[layer]
		flag(
			("scale_%s"):format(string.lower(layer)),
			type(got) == "number" and math.abs(got - want) <= SIZE_TOL,
			type(got) == "number" and got or -1,
			want
		)
	end
	flag("prune_api", Dressing ~= nil and type(Dressing.Prune) == "function")

	local specs = TrackRegistry.Chain()
	flag("chain_length", #specs == #BIOMES, #specs, #BIOMES)
	for _, spec in specs do
		local want = BIOMES[spec.Number]
		flag(("biome_spec_%d"):format(spec.Number), spec.Biome == want and want ~= nil)
		flag(
			("biome_theme_%d"):format(spec.Number),
			Themes ~= nil and type(spec.Biome) == "string" and Themes[spec.Biome] ~= nil
		)
	end

	-- w4 anime themes (spec "Biomes": "rhythm props along the road, corner / crest landmarks, ... a start `Gate`,
	-- themed ground and sky tint"): DisplayName is the working name; core pieces present (structure, not art)
	local realNameIn = require(script.Parent.CatalogTests).realNameIn
	local AssetsIp = module(Shared, "BiomeMeshAssets") or {}
	for n, biome in BIOMES do
		local theme = Themes and Themes[biome]
		local t = type(theme) == "table" and theme or {}
		flag(("theme_display_name_%d"):format(n), t.DisplayName == BIOME_NAMES[n], t.DisplayName, BIOME_NAMES[n])
		local ground = type(t.Ground) == "table" and t.Ground or {}
		flag(("theme_ground_%d"):format(n), typeof(ground.Color) == "Color3" and typeof(ground.Material) == "EnumItem")
		local sky = type(t.Sky) == "table" and t.Sky or {}
		flag(("theme_sky_tint_%d"):format(n), typeof(sky.Color) == "Color3")
		local gateDef = type(t.Gate) == "table" and t.Gate or {}
		flag(("theme_gate_%d"):format(n), typeof(gateDef.Color) == "Color3")
		local function propsOk(layer)
			local props = type(layer) == "table" and layer.Props
			if type(props) ~= "table" or #props == 0 then
				return false
			end
			for _, p in props do
				if type(p) ~= "table" or type(p.Name) ~= "string" or typeof(p.Size) ~= "Vector3" then
					return false
				end
			end
			return true
		end
		flag(("theme_rhythm_props_%d"):format(n), propsOk(t.Rhythm))
		flag(("theme_landmark_%d"):format(n), propsOk(t.Landmarks))

		-- IP (design doc 5): no real character, series or place names anywhere in the theme data
		local hit = nil
		for _, text in themeStrings(theme) do
			if realNameIn(nameKey(text)) then
				hit = hit or text
			end
		end
		flag(("theme_no_real_names_%d"):format(n), theme ~= nil and hit == nil)
		r.metrics[("theme_real_name_%d"):format(n)] = hit and realNameIn(nameKey(hit)) -- hash only, never the name
		-- IP: no IVS asset in the theme, and no theme prop resolves to an IVS-uploaded mesh texture
		local ivs = 0
		for _, id in themeAssetIds(theme) do
			if IVS_ASSET_IDS[id] then
				ivs += 1
			end
		end
		for name in themeProps(theme) do
			local id = AssetsIp[biome .. "_" .. name]
			if type(id) == "string" and IVS_ASSET_IDS[string.match(id, "%d+") or ""] then
				ivs += 1
			end
		end
		flag(("theme_no_ivs_assets_%d"):format(n), theme ~= nil and ivs == 0, ivs, 0)
	end

	local before = lightingSnapshot()
	local okA, chainA = pcall(buildChain, specs)
	local okB, chainB = pcall(buildChain, specs)
	flag("chain_builds", okA and okB, nil, nil)
	if not (okA and okB) then
		r.error = tostring(okA and chainB or chainA)
		return r
	end

	-- Determinism: two fresh builds (before Prune) give the same prop names and CFrames
	for i, t in chainA do
		local same, worst = sameSignature(
			signature(t.Model:FindFirstChild("Environment")),
			signature(chainB[i].Model:FindFirstChild("Environment"))
		)
		flag(("deterministic_%d"):format(t.Spec.Number), same, worst, CFRAME_TOL)
	end
	-- Baked meshes (Shared/BiomeMeshData, BiomeMeshCodec, BiomeMeshAssets)
	local meshFolder = Shared:FindFirstChild("BiomeMeshData")
	local Codec = module(Shared, "BiomeMeshCodec")
	local Assets = module(Shared, "BiomeMeshAssets")
	local meshForOk = Dressing ~= nil and type(Dressing.MeshFor) == "function"
	flag("mesh_data_folder", meshFolder ~= nil and meshFolder:IsA("Folder"))
	flag("mesh_codec", Codec ~= nil and type(Codec.Decode) == "function")
	flag("mesh_assets_module", Assets ~= nil)
	flag("mesh_for_api", meshForOk)
	local meshEntries, meshProblems = 0, {}
	for _, biome in BIOMES do
		local data = meshFolder and module(meshFolder, biome)
		local bad, badIds, badLookup, first = 0, 0, 0, nil
		for name, entry in data or {} do
			meshEntries += 1
			local problem = "codec" -- no codec: every entry fails
			if Codec and type(Codec.Decode) == "function" then
				problem = meshEntryProblem(Codec, entry) -- nil when the entry is valid
			end
			if problem then
				bad += 1
				first = first or (name .. ":" .. problem)
			end
			local id = Assets and Assets[biome .. "_" .. name]
			if type(id) ~= "string" or not string.match(id, "^rbxassetid://%d+$") then
				badIds += 1
				first = first or (name .. ":asset_id")
			end
			if not meshForOk or Dressing.MeshFor(biome, name) ~= entry then
				badLookup += 1
				first = first or (name .. ":mesh_for")
			end
		end
		flag(("mesh_data_valid_%s"):format(biome), bad == 0, bad, 0)
		flag(("mesh_asset_ids_%s"):format(biome), badIds == 0, badIds, 0)
		flag(("mesh_for_matches_%s"):format(biome), badLookup == 0, badLookup, 0)
		if first then
			meshProblems[biome] = first
		end
	end
	r.metrics.mesh_entries = meshEntries
	r.metrics.mesh_problems = meshProblems

	-- Built props (fresh build, before Prune): a prop with baked data is a tagged BiomeMesh model with an
	-- invisible MeshBounds at the prop's SCALED height (def.Size.Y * SCALE[layer], layer from the name prefix of the
	-- prop's top-level Environment child; Rhythm_ and the gate x1; missing SCALE = red) and the mesh's proportions;
	-- a prop without data has neither
	local meshCounts = {}
	local function layerScale(env, m)
		local top = m
		while top.Parent and top.Parent ~= env do
			top = top.Parent
		end
		for prefix, layer in LAYER_OF_PREFIX do
			if string.sub(top.Name, 1, #prefix) == prefix then
				local v = scale and scale[layer]
				return type(v) == "number" and v or nil, layer
			end
		end
		return 1, nil
	end
	for _, t in chainB do
		local n, biome = t.Spec.Number, BIOMES[t.Spec.Number]
		local env = t.Model:FindFirstChild("Environment")
		local defs = themeProps(Themes and biome and Themes[biome])
		local meshBad, plainBad, meshed, firstBad = 0, 0, 0, nil
		for _, m in (env and env:GetDescendants() or {}) do
			if m:IsA("Model") then
				local propName = biome and propNameOf(m, biome)
				local def = propName and defs[propName]
				local data = def and meshForOk and Dressing.MeshFor(biome, propName)
				local bounds = m:FindFirstChild("MeshBounds")
				local tagged = CollectionService:HasTag(m, "BiomeMesh")
				if data then
					meshed += 1
					local ok = tagged and m:GetAttribute("Mesh") == biome .. "_" .. propName
					ok = ok and bounds ~= nil and bounds:IsA("Part") and bounds.Transparency == 1
					ok = ok
						and bounds.Anchored
						and not bounds.CanCollide
						and not bounds.CanTouch
						and not bounds.CanQuery
					if ok then
						-- Spec Rules "Scale" (owner 2026-10-27): a horizon piece that fits at no HORIZON_FIT offset
						-- shrinks by 0.25 steps from SCALE.Horizon toward x1; every other layer is exact
						local k, layer = layerScale(env, m)
						local fits = false
						if k ~= nil then
							local s = k
							repeat
								fits = fits or math.abs(bounds.Size.Y - def.Size.Y * s) <= SIZE_TOL
								s -= 0.25
							until layer ~= "Horizon" or s < 1 - SIZE_TOL
						end
						ok = fits
						local ratio = bounds.Size / data.Size
						local lo = math.min(ratio.X, ratio.Y, ratio.Z)
						local hi = math.max(ratio.X, ratio.Y, ratio.Z)
						ok = ok and hi - lo <= SIZE_TOL
					end
					if not ok then
						meshBad += 1
						firstBad = firstBad or m.Name
					end
				elseif bounds ~= nil or tagged then
					plainBad += 1
					firstBad = firstBad or m.Name
				end
			end
		end
		flag(("mesh_props_%d"):format(n), env ~= nil and meshBad == 0, meshBad, 0)
		flag(("meshless_props_plain_%d"):format(n), env ~= nil and plainBad == 0, plainBad, 0)
		meshCounts[tostring(n)] = { meshed = meshed, first_bad = firstBad }

		-- City skyscrapers (owner 2026-10-27, spec Rules "City skyscrapers"): landmark, scatter-block and skyline
		-- towers have no baked mesh; every City landmark is a detailed tower (>= 25 parts, Glass window bands, a
		-- Neon crown) and the tallest is at least 100 studs high (fresh build, before Prune)
		if n == CITY then
			local meshedTowers, towersFirst = 0, nil
			local landmarks, thin, noGlass, noNeon, tallest, landmarkFirst = 0, 0, 0, 0, 0, nil
			for _, c in (env and env:GetChildren() or {}) do
				local isLayer = false
				for prefix in LAYER_OF_PREFIX do
					isLayer = isLayer or string.sub(c.Name, 1, #prefix) == prefix
				end
				if c:IsA("Model") and isLayer then
					local propName = propNameOf(c, biome)
					local isLandmark = string.sub(c.Name, 1, 9) == "Landmark_"
					local isSkyline = string.sub(c.Name, 1, 8) == "Horizon_"
					if isLandmark or isSkyline or CITY_TOWER_PROPS[propName] then
						for _, d in c:GetDescendants() do
							local meshAttr = d:GetAttribute("Mesh")
							local towerMesh = type(meshAttr) == "string"
								and CITY_TOWER_PROPS[string.sub(meshAttr, #biome + 2)]
							if d.Name == "MeshBounds" or CollectionService:HasTag(d, "BiomeMesh") or towerMesh then
								meshedTowers += 1
								towersFirst = towersFirst or c.Name
								break
							end
						end
						local meshAttr = c:GetAttribute("Mesh")
						if
							c:FindFirstChild("MeshBounds") ~= nil
							or CollectionService:HasTag(c, "BiomeMesh")
							or (type(meshAttr) == "string" and CITY_TOWER_PROPS[string.sub(meshAttr, #biome + 2)])
						then
							meshedTowers += 1
							towersFirst = towersFirst or c.Name
						end
					end
					if isLandmark then
						landmarks += 1
						local parts = baseParts(c)
						local glass, neon = false, false
						for _, part in parts do
							glass = glass or part.Material == Enum.Material.Glass
							neon = neon or part.Material == Enum.Material.Neon
						end
						if #parts < CITY_TOWER_MIN_PARTS then
							thin += 1
							landmarkFirst = landmarkFirst or ("%s parts=%d"):format(c.Name, #parts)
						end
						if not glass then
							noGlass += 1
							landmarkFirst = landmarkFirst or (c.Name .. " no_glass")
						end
						if not neon then
							noNeon += 1
							landmarkFirst = landmarkFirst or (c.Name .. " no_neon")
						end
						if #parts > 0 then
							local _, size = c:GetBoundingBox()
							tallest = math.max(tallest, size.Y)
						end
					end
				end
			end
			flag("city_towers_no_mesh", env ~= nil and meshedTowers == 0, meshedTowers, 0)
			flag("city_landmarks_present", landmarks >= 1, landmarks, 1)
			flag("city_landmarks_detailed", landmarks >= 1 and thin == 0, thin, 0)
			flag("city_landmarks_glass_bands", landmarks >= 1 and noGlass == 0, noGlass, 0)
			flag("city_landmarks_neon_crown", landmarks >= 1 and noNeon == 0, noNeon, 0)
			flag(
				"city_landmark_height",
				tallest >= CITY_TOWER_MIN_HEIGHT,
				math.round(tallest * 100) / 100,
				CITY_TOWER_MIN_HEIGHT
			)
			r.metrics.city = { landmarks = landmarks, tallest = tallest, first_bad = towersFirst or landmarkFirst }
		end

		-- Ground top: TrackBuilder's GROUND_TOP lowered 0.02 per track number
		local ground = t.Model:FindFirstChild("Ground")
		local top = ground and ground:IsA("BasePart") and ground.Position.Y + ground.Size.Y / 2 or math.huge
		local want = GROUND_TOP - GROUND_STEP * n
		flag(
			("ground_top_%d"):format(n),
			math.abs(top - want) <= SIZE_TOL,
			top == math.huge and -1 or math.round(top * 1000) / 1000,
			want
		)
	end
	r.metrics.mesh_props = meshCounts
	for _, t in chainB do
		t.Model:Destroy()
	end

	local spawnModel
	if SpawnArea and type(SpawnArea.Build) == "function" then
		local start = chainA[1].Model:FindFirstChild("Start", true)
		local okS, m = pcall(SpawnArea.Build, start and start.CFrame or chainA[1].Origin)
		spawnModel = okS and m or nil
	end
	flag("spawn_area_builds", spawnModel ~= nil)

	-- Probes: one prop sitting on Track 1's road must be pruned, one high above it must survive
	local models, prePrune = {}, {}
	for _, t in chainA do
		table.insert(models, t.Model)
		prePrune[t.Spec.Number] = #baseParts(t.Model:FindFirstChild("Environment"))
	end
	local env1 = chainA[1].Model:FindFirstChild("Environment")
	local nearProbe, farProbe
	if env1 then
		local road = chainA[1].Model:FindFirstChild("Road")
		local roadPart = road and baseParts(road)[1]
		local base = roadPart and roadPart.CFrame or chainA[1].Origin
		nearProbe = Instance.new("Part")
		nearProbe.Name = "CarTestNearProbe"
		nearProbe.Size = Vector3.new(2, 2, 2)
		nearProbe.CFrame = base * CFrame.new(0, 4, 0)
		nearProbe.Anchored, nearProbe.CanCollide, nearProbe.CanTouch, nearProbe.CanQuery = true, false, false, false
		nearProbe.Parent = env1
		farProbe = nearProbe:Clone()
		farProbe.Name = "CarTestFarProbe"
		farProbe.CFrame = base * CFrame.new(0, 400, 0)
		farProbe.Parent = env1
	end

	local pruneOk = false
	if Dressing and type(Dressing.Prune) == "function" then
		local okP, err = pcall(Dressing.Prune, models, spawnModel and { spawnModel } or nil)
		pruneOk = okP
		if not okP then
			r.error = tostring(err)
		end
	end
	flag("prune_runs", pruneOk)
	flag("prune_removes_road_probe", pruneOk and nearProbe ~= nil and nearProbe.Parent == nil)
	flag("prune_keeps_far_probe", pruneOk and farProbe ~= nil and farProbe.Parent == env1)
	if farProbe then
		farProbe:Destroy()
	end

	local grid, obstacles = obstacleGrid(models, spawnModel)
	r.metrics.obstacles = obstacles
	local grow = (type(clearance) == "number" and clearance or 8) - GEOM_TOL
	local counts, worstHits, visualCounts = {}, {}, {}
	for _, t in chainA do
		local n = t.Spec.Number
		local model = t.Model
		local env = model:FindFirstChild("Environment")
		flag(("environment_folder_%d"):format(n), env ~= nil and env:IsA("Folder"))
		flag(("biome_attribute_%d"):format(n), model:GetAttribute("Biome") == BIOMES[n] and BIOMES[n] ~= nil)
		local parts = baseParts(env)
		counts[tostring(n)] = { built = prePrune[n] or 0, kept = #parts }
		flag(("environment_nonempty_%d"):format(n), #parts > 0, #parts, 1)
		-- w4 IP (design doc 5): no real names in built instance names or text; no IVS asset on any built instance
		local named, ivsBuilt = nil, 0
		for _, d in env and env:GetDescendants() or {} do
			local text = d:IsA("TextLabel") and d.Text or d.Name
			if realNameIn(nameKey(text)) or realNameIn(nameKey(d.Name)) then
				named = named or d:GetFullName()
			end
			local ids = d:IsA("MeshPart") and { d.MeshId, d.TextureID }
				or d:IsA("FileMesh") and { d.MeshId, d.TextureId }
				or d:IsA("Decal") and { d.Texture }
				or {}
			for _, value in ids do
				if IVS_ASSET_IDS[string.match(value, "%d+") or ""] then
					ivsBuilt += 1
				end
			end
		end
		flag(("environment_no_real_names_%d"):format(n), env ~= nil and named == nil)
		flag(("environment_no_ivs_assets_%d"):format(n), env ~= nil and ivsBuilt == 0, ivsBuilt, 0)
		-- Length-scaled budget (owner 2026-10-30, replaces the fixed BUDGET / CITY_BUDGET caps): BUDGET parts per
		-- BUDGET_STUDS of the track's Length attribute, never below BUDGET
		local theme = Themes and BIOMES[n] and Themes[BIOMES[n]]
		local length = model:GetAttribute("Length")
		local limit = math.floor(BUDGET * math.max(1, (type(length) == "number" and length or 0) / BUDGET_STUDS))
		flag(("environment_budget_%d"):format(n), #parts <= limit, #parts, limit)

		-- Gate (spec Layers 4): a Gate* part on the FIRST STRAIGHT, after Prune: its horizontal distance from Start along
		-- the start direction is within 0..spec.Segments[1].Length
		local start = model:FindFirstChild("Start", true)
		local startCF = start and start.CFrame or t.Origin
		local ahead = startCF.LookVector * Vector3.new(1, 0, 1)
		ahead = ahead.Magnitude > 1e-6 and ahead.Unit or Vector3.new(0, 0, -1)
		local first = type(t.Spec.Segments) == "table" and t.Spec.Segments[1]
		local firstLength = first and type(first.Length) == "number" and first.Length or 0
		local gateAlong = nil
		for _, part in parts do
			if string.sub(part.Name, 1, 4) == "Gate" then
				local along = ((part.Position - startCF.Position) * Vector3.new(1, 0, 1)):Dot(ahead)
				if along >= 0 and along <= firstLength and (gateAlong == nil or along < gateAlong) then
					gateAlong = along
				end
			end
		end
		if n == 1 then
			-- Owner 2026-10-30: Track 1 builds no biome gate; the plaza torii StartGate near its start is its gate
			local torii = spawnModel and spawnModel:FindFirstChild("StartGate")
			local dist = torii
					and torii:IsA("Model")
					and ((torii:GetPivot().Position - startCF.Position) * Vector3.new(1, 0, 1)).Magnitude
				or -1
			flag("gate_at_start_1", dist >= 0 and dist <= TORII_NEAR, math.round(dist * 100) / 100, TORII_NEAR)
			flag("gate_none_in_biome_1", env ~= nil and env:FindFirstChild("Gate") == nil)
		else
			flag(
				("gate_at_start_%d"):format(n),
				gateAlong ~= nil,
				gateAlong == nil and -1 or math.round(gateAlong * 100) / 100,
				firstLength
			)
		end

		-- Gate sign (owner 2026-10-21, design doc Track environments "gate signs"; spec Layers 4 "Sign"): Part GateSign
		-- in Environment/Gate, SurfaceGui GateSignGui on the face toward the oncoming car, TextLabel Biome (upper-case
		-- biome, words split) and TextLabel RecSpeed = "REC. SPEED " .. the shown Speed whose cruise speed is the
		-- track's NPC speed (RaceConfig.StatFor), formatted like the HUD Speed (Short when infinite).
		local gateModel = env and env:FindFirstChild("Gate")
		local sign = gateModel and gateModel:FindFirstChild("GateSign")
		local gui = sign and sign:IsA("BasePart") and sign:FindFirstChild("GateSignGui")
		gui = gui and gui:IsA("SurfaceGui") and gui or nil
		local signed = n ~= 1 -- the torii has no biome sign (plaque only), so Track 1 has no sign checks
		if signed then
			flag(("gate_sign_gui_%d"):format(n), gui ~= nil)
		end
		local biomeLabel = gui and gui:FindFirstChild("Biome")
		local recLabel = gui and gui:FindFirstChild("RecSpeed")
		biomeLabel = biomeLabel and biomeLabel:IsA("TextLabel") and biomeLabel or nil
		recLabel = recLabel and recLabel:IsA("TextLabel") and recLabel or nil
		-- w4: the sign shows the biome's working name (theme DisplayName), upper-case
		local wantBiome = BIOME_NAMES[n] and string.upper(BIOME_NAMES[n]) or "?"
		if signed then
			flag(("gate_sign_biome_%d"):format(n), biomeLabel ~= nil and biomeLabel.Text == wantBiome)
		end
		local npcSpeed = NpcConfig.For(n).Speed
		local rec = RaceConfig.StatFor(npcSpeed)
		local recText = rec == math.huge and HudFormat.Short(rec) or HudFormat.SpeedText(rec)
		if signed then
			flag(("gate_sign_rec_speed_%d"):format(n), recLabel ~= nil and recLabel.Text == "REC. SPEED " .. recText)
		end
		-- owner 2026-10-27: the number uses the lowercase suffixes (k m b t qd ...), never "10K" / "1Qd"
		local recNum = recLabel and string.sub(recLabel.Text, #"REC. SPEED " + 1) or "?"
		if signed then
			flag(("gate_sign_rec_lowercase_%d"):format(n), recLabel ~= nil and not string.find(recNum, "%u"))
		end
		-- The recommended shown Speed really cruises at the NPC's speed (finite cases)
		local cruise = rec < math.huge and RaceConfig.SpeedFor(rec) or npcSpeed
		flag(
			("gate_sign_rec_matches_npc_%d"):format(n),
			rec > 0 and math.abs(cruise - npcSpeed) <= 1e-6 * npcSpeed,
			cruise,
			npcSpeed
		)
		-- Owner 2026-10-21 ("lower track requirements"): every track's recommended Speed is a real (finite) number,
		-- and Track 1 does not need ~10M Speed: below 10,000
		flag(("gate_sign_rec_finite_%d"):format(n), rec > 0 and rec < math.huge, rec < math.huge and rec or -1, 1)
		if n == 1 then
			-- 10K old Speed x the design doc 4.11 stat scale
			flag("gate_sign_rec_track1_below_10k", rec > 0 and rec < 10000 * (1e15 / 3e5), rec, 10000 * (1e15 / 3e5))
		end
		-- Faces the oncoming car: the GUI face normal points back along the drive direction
		local facing = -1
		if gui then
			local normal = sign.CFrame:VectorToWorldSpace(Vector3.FromNormalId(gui.Face))
			facing = -(normal * Vector3.new(1, 0, 1)):Dot(ahead)
		end
		if signed then
			flag(("gate_sign_faces_car_%d"):format(n), facing >= 0.9, math.round(facing * 100) / 100, 0.9)
		end

		local flagsBad, hits, firstBad = 0, 0, nil
		for _, part in parts do
			if not part.Anchored or part.CanCollide or part.CanTouch or part.CanQuery then
				flagsBad += 1
			end
			local o = firstHit(grid, part, grow)
			if o then
				hits += 1
				firstBad = firstBad or (part.Name .. " -> " .. o.Name)
			end
		end
		flag(("props_visual_only_%d"):format(n), env ~= nil and flagsBad == 0, flagsBad, 0)
		flag(("props_clear_of_road_%d"):format(n), env ~= nil and hits == 0, hits, 0)
		if firstBad then
			worstHits[tostring(n)] = firstBad
		end

		local badLights, skyLike = 0, 0
		for _, d in (env and env:GetDescendants() or {}) do
			if d:IsA("Light") and d.Shadows then
				badLights += 1
			end
		end
		for _, d in model:GetDescendants() do
			if d:IsA("Atmosphere") or d:IsA("Sky") or d:IsA("Clouds") then
				skyLike += 1
			end
		end
		flag(("lights_no_shadows_%d"):format(n), badLights == 0, badLights, 0)
		flag(("no_sky_or_atmosphere_%d"):format(n), skyLike == 0, skyLike, 0)

		-- Visual pass (owner 2026-10-26): after Prune each track keeps landmarks, horizon, scatter and flat patches
		local prefixCount = { Landmark_ = 0, Horizon_ = 0, Scatter_ = 0, Patch_ = 0 }
		local patchBad, patchFirst = 0, nil
		local ground = model:FindFirstChild("Ground")
		local groundTop = ground and ground:IsA("BasePart") and ground.Position.Y + ground.Size.Y / 2 or nil
		for _, c in (env and env:GetChildren() or {}) do
			for prefix, k in prefixCount do
				if string.sub(c.Name, 1, #prefix) == prefix then
					prefixCount[prefix] = k + 1
				end
			end
			if string.sub(c.Name, 1, 6) == "Patch_" then
				local patchParts = baseParts(c)
				if c:IsA("BasePart") then
					table.insert(patchParts, c)
				end
				for _, part in patchParts do
					local bottom = part.Position.Y - part.Size.Y / 2
					local ok = part.Size.Y <= PATCH_THICKNESS + SIZE_TOL
						and groundTop ~= nil
						and math.abs(bottom - groundTop) <= PATCH_GROUND_TOL
					if not ok then
						patchBad += 1
						patchFirst = patchFirst or ("%s y=%.3f h=%.3f"):format(part:GetFullName(), bottom, part.Size.Y)
					end
				end
			end
		end
		flag(("landmark_present_%d"):format(n), prefixCount.Landmark_ >= 1, prefixCount.Landmark_, 1)
		flag(("horizon_present_%d"):format(n), prefixCount.Horizon_ >= 1, prefixCount.Horizon_, 1)
		flag(("scatter_present_%d"):format(n), prefixCount.Scatter_ >= MIN_SCATTER, prefixCount.Scatter_, MIN_SCATTER)
		flag(("patches_present_%d"):format(n), prefixCount.Patch_ >= MIN_PATCHES, prefixCount.Patch_, MIN_PATCHES)
		flag(("patches_flat_on_ground_%d"):format(n), env ~= nil and patchBad == 0, patchBad, 0)

		-- Particles (spec Layer 8): only BiomeParticles, inside a Landmark_* model, Rate <= 8, one per landmark
		local emitters, particlesBad, particlesFirst, perLandmark = 0, 0, nil, {}
		for _, d in (env and env:GetDescendants() or {}) do
			if d:IsA("ParticleEmitter") then
				local top = d
				while top.Parent and top.Parent ~= env do
					top = top.Parent
				end
				local inLandmark = top ~= d and top:IsA("Model") and string.sub(top.Name, 1, 9) == "Landmark_"
				if d.Name == "BiomeParticles" then
					emitters += 1
				end
				if inLandmark then
					perLandmark[top] = (perLandmark[top] or 0) + 1
				end
				local ok = d.Name == "BiomeParticles"
					and inLandmark
					and d.Rate <= PARTICLE_MAX_RATE
					and perLandmark[top] <= 1
				if not ok then
					particlesBad += 1
					particlesFirst = particlesFirst or ("%s rate=%g"):format(d:GetFullName(), d.Rate)
				end
			end
		end
		flag(("particles_rules_%d"):format(n), env ~= nil and particlesBad == 0, particlesBad, 0)
		flag(("particles_present_%d"):format(n), emitters >= 1, emitters, 1)
		visualCounts[tostring(n)] = {
			landmarks = prefixCount.Landmark_,
			horizon = prefixCount.Horizon_,
			scatter = prefixCount.Scatter_,
			patches = prefixCount.Patch_,
			particles = emitters,
			first_patch_bad = patchFirst,
			first_particle_bad = particlesFirst,
		}

		-- Populated city (owner 2026-10-27, spec Layers 9 Blocks), after Prune: Block_<slot><L|R><row> models line
		-- both sides two rows deep, their footprints (oriented XZ box of each model's largest part, shrunk by
		-- BLOCK_SHRINK) never overlap, and probes every BLOCK_PROBE_STEP studs along the straight road, offset
		-- Width/2 + Near + RowDepth/2 to each side (middle of row 1), mostly fall inside a Block_ footprint.
		if n == CITY then
			local blocks, rows, sides = {}, {}, {}
			for _, c in (env and env:GetChildren() or {}) do
				local _, side, row = string.match(c.Name, "^Block_(%d+)([LR])(%d+)$")
				local largest
				for _, part in baseParts(c) do
					if largest == nil or part.Size.X * part.Size.Z > largest.Size.X * largest.Size.Z then
						largest = part
					end
				end
				if side and c:IsA("Model") and largest then
					table.insert(blocks, { Name = c.Name, Part = largest })
					rows[tonumber(row)] = true
					sides[side] = true
				end
			end
			flag("city_blocks_count", #blocks >= CITY_MIN_BLOCKS, #blocks, CITY_MIN_BLOCKS)
			flag("city_blocks_both_rows", rows[1] == true and rows[2] == true)
			flag("city_blocks_both_sides", sides.L == true and sides.R == true)

			local overlaps, overlapFirst = 0, nil
			local shrunk, full = {}, {}
			for i, b in blocks do
				shrunk[i] = footprint(b.Part, BLOCK_SHRINK)
				full[i] = footprint(b.Part, 0)
			end
			for i = 1, #blocks do
				for j = i + 1, #blocks do
					if footprintsOverlap(shrunk[i], shrunk[j]) then
						overlaps += 1
						overlapFirst = overlapFirst or (blocks[i].Name .. " x " .. blocks[j].Name)
					end
				end
			end
			flag("city_blocks_no_overlap", #blocks > 0 and overlaps == 0, overlaps, 0)

			local cfg = theme and type(theme.Blocks) == "table" and theme.Blocks or nil
			local probes, covered = 0, 0
			if cfg and type(cfg.Near) == "number" and type(cfg.RowDepth) == "number" then
				local offset = t.Layout.Width / 2 + cfg.Near + cfg.RowDepth / 2
				local wps, curv = t.Layout.Waypoints, t.Layout.Curvature
				local along, nextProbe = 0, 0
				for i = 2, #wps do
					if curv[i] == 0 then
						local a, b = t.Origin * wps[i - 1], t.Origin * wps[i]
						local d = Vector2.new(b.X - a.X, b.Z - a.Z)
						local len = d.Magnitude
						if len > 1e-6 then
							local dir = d.Unit
							local right = Vector2.new(-dir.Y, dir.X)
							while nextProbe <= along + len do
								local p = Vector2.new(a.X, a.Z) + dir * (nextProbe - along)
								for _, s in { -1, 1 } do
									local q = p + right * s * offset
									probes += 1
									for _, f in full do
										if footprintHas(f, q) then
											covered += 1
											break
										end
									end
								end
								nextProbe += BLOCK_PROBE_STEP
							end
							along += len
						end
					end
				end
			end
			local coverage = probes > 0 and covered / probes or 0
			flag(
				"city_blocks_gap",
				probes > 0 and coverage >= BLOCK_MIN_COVERAGE,
				math.round(coverage * 1000) / 1000,
				BLOCK_MIN_COVERAGE
			)
			r.metrics.city_blocks = {
				count = #blocks,
				overlaps = overlaps,
				first_overlap = overlapFirst,
				probes = probes,
				covered = covered,
			}
		end
	end
	r.metrics.parts = counts
	r.metrics.first_overlap = worstHits
	r.metrics.visual = visualCounts

	local after = lightingSnapshot()
	local lightOk = math.abs(after.ClockTime - before.ClockTime) <= LIGHT_TOL
		and math.abs(after.Brightness - before.Brightness) <= LIGHT_TOL
		and colorDiff(after.OutdoorAmbient, before.OutdoorAmbient) <= LIGHT_TOL
		and colorDiff(after.Ambient, before.Ambient) <= LIGHT_TOL
	flag("lighting_unchanged", lightOk)
	-- w4 night biomes (spec "Night biomes (4, 5, 9) ... never change global `Lighting`"): the chain built them, and
	-- fog, colour shift, exposure and Lighting's children are unchanged too
	local nightBuilt = true
	for _, n in NIGHT_TRACKS do
		nightBuilt = nightBuilt and chainA[n] ~= nil and chainA[n].Model:FindFirstChild("Environment") ~= nil
	end
	flag(
		"night_biomes_lighting_unchanged",
		nightBuilt
			and lightOk
			and math.abs(after.FogEnd - before.FogEnd) <= LIGHT_TOL
			and colorDiff(after.FogColor, before.FogColor) <= LIGHT_TOL
			and colorDiff(after.ColorShift, before.ColorShift) <= LIGHT_TOL
			and math.abs(after.Exposure - before.Exposure) <= LIGHT_TOL
			and after.Children == before.Children
	)
	flag(
		"no_new_sky_atmosphere_clouds",
		after.Atmosphere == before.Atmosphere and after.Sky == before.Sky and after.Clouds == before.Clouds
	)

	for _, t in chainA do
		t.Model:Destroy()
	end
	if spawnModel then
		spawnModel:Destroy()
	end
	return r
end

-- ===================================================================================================================
-- docs/BIOME_ENVIRONMENT_SPEC.md section 10 (goal `biomes`, b1): four minimal dev-tool scenarios, on demand
-- (TestConfig.OnDemand, CarTestOnly). Written by test-writer BEFORE the b1 framework; red until it lands.
-- They read the LIVE world built by Main.server and wait for ReplicatedStorage attribute TerrainReady (spec 3.1).
-- Contract used (spec 2.4, 3.1-3.3, 4.4, 5.1-5.3, 9.1):
--   * ReplicatedStorage attributes TerrainReady (true at the end), BiomeZone_<n> ("x,z;x,z;..."), PlazaRadius;
--   * Shared.BiomeDressing.CLEARANCE and .SnapToTerrain;
--   * Shared.BiomeEnvironment (pure, server-requirable; the client BiomeEnvironment.client.luau uses it):
--     ZoneAt(p: Vector3) -> zone number (0 = plaza), BLEND_SECONDS;
--   * Shared.BiomeThemes/<Key> ModuleScripts with Terrain, Atmosphere (Atmosphere.Lighting.ClockTime), Audio
--     ({ Loop, OneShots, Volume, Reverb }) and Assets (ledger rows { Kind, Id, Lane, Prompt, Creator, Reviewed }).
-- ===================================================================================================================
local TERRAIN_WAIT = 120 -- s; spec 3.1 budget is 45 s on the Studio server (placeholder), test-side slack
local CORRIDOR_STEP = 20 -- studs between centre-line samples (spec 10 placeholder)
local CORRIDOR_BELOW = 0.5 -- spec 10: from road Y - 0.5 ...
local CORRIDOR_ABOVE = 12 -- ... to road Y + 12
local VOXEL = 4 -- ReadVoxels resolution (spec 3.1)
local GAP_POINTS = 3 -- spec 10: solid terrain at 3 sampled gap points per zone
local GAP_OFFSETS = { 66, 58 } -- studs from the centre line: the ridge band (60 to ~77) and the shoulder (44-60)
local GAP_MIN_DIST = 50 -- test-side: a gap point is at least this far from EVERY centre line (past the corridor 44)
local COLUMN_LO, COLUMN_HI = -64, 256 -- studs: below the Drop deck (-40) to above the highest ridge
local POLY_TOL = 1 -- studs (XZ): a BiomeZone_<n> point lies on track n's centre line
local PLAZA_CENTRE_TOL = 8 -- WorldTests CENTRE_TOL: the hub centre is within 8 studs of the world origin

local Terrain = Workspace.Terrain

local function waitTerrainReady()
	local t0 = os.clock()
	while ReplicatedStorage:GetAttribute("TerrainReady") ~= true and os.clock() - t0 < TERRAIN_WAIT do
		task.wait(0.5)
	end
	return ReplicatedStorage:GetAttribute("TerrainReady") == true, math.round((os.clock() - t0) * 10) / 10
end

-- Live centre lines (world space, as Main.server chains them) resampled every `step` studs: { Number, Width, Pts }
local function centreLines(step)
	local chain = require(script.Parent.TrackChainTests)
	local out = {}
	for _, t in chain.world(TrackBuilder, TrackRegistry.Chain()) do
		local pts, wps = {}, t.Points
		local carry = 0
		if wps[1] then
			table.insert(pts, wps[1])
		end
		for i = 2, #wps do
			local a, b = wps[i - 1], wps[i]
			local len = (b - a).Magnitude
			local at = step - carry
			while at < len do
				table.insert(pts, a:Lerp(b, at / len))
				at += step
			end
			-- every waypoint is kept too, so corners are never chord-cut; spacing restarts at it (always <= step)
			table.insert(pts, b)
			carry = 0
		end
		table.insert(out, { Number = t.Number, Width = t.Layout.Width, Pts = pts })
	end
	return out
end

local function segDistXZ(px, pz, a, b)
	local dx, dz = b.X - a.X, b.Z - a.Z
	local len2 = dx * dx + dz * dz
	local u = len2 > 1e-9 and math.clamp(((px - a.X) * dx + (pz - a.Z) * dz) / len2, 0, 1) or 0
	local qx, qz = a.X + dx * u - px, a.Z + dz * u - pz
	return math.sqrt(qx * qx + qz * qz)
end

local function isSolid(material)
	return material ~= Enum.Material.Air and material ~= Enum.Material.Water
end

-- 1. terrain_built (spec 10.1, 2.2, 3.1)
function Tests.terrain_built()
	local r, flag = report("terrain_built")
	local ready, waited = waitTerrainReady()
	flag("terrain_ready", ready)
	r.metrics.waited_s = waited
	r.metrics.terrain_progress = ReplicatedStorage:GetAttribute("TerrainProgress")
	if not ready then
		return r
	end
	local Dressing = module(Shared, "BiomeDressing")
	local clearance = Dressing and type(Dressing.CLEARANCE) == "number" and Dressing.CLEARANCE or nil
	flag("clearance_value", clearance ~= nil)
	clearance = clearance or 8
	local lines = centreLines(CORRIDOR_STEP)
	flag("centre_lines", #lines == #BIOMES, #lines, #BIOMES)

	-- Corridor: no solid or water voxel within road half-width + CLEARANCE of the centre line, from road Y - 0.5 to
	-- road Y + 12. A voxel's filled top is read as bottom + occupancy * VOXEL (smooth terrain fills from below).
	local corridor = {}
	for _, line in lines do
		local pts, reach = line.Pts, line.Width / 2 + clearance
		local hits, samples, first = 0, 0, nil
		for i, p in pts do
			if i % 25 == 0 then
				task.wait() -- yield per chunk of samples
			end
			samples += 1
			local a, b = pts[math.max(1, i - 1)], pts[math.min(#pts, i + 1)]
			local lo, hi = p.Y - CORRIDOR_BELOW, p.Y + CORRIDOR_ABOVE
			local region =
				Region3.new(Vector3.new(p.X - reach, lo, p.Z - reach), Vector3.new(p.X + reach, hi, p.Z + reach))
			region = region:ExpandToGrid(VOXEL)
			local mats, occ = Terrain:ReadVoxels(region, VOXEL)
			local size = mats.Size
			local min = region.CFrame.Position - region.Size / 2
			local bad = false
			for x = 1, size.X do
				local cx = min.X + (x - 0.5) * VOXEL
				for z = 1, size.Z do
					local cz = min.Z + (z - 0.5) * VOXEL
					if segDistXZ(cx, cz, a, b) <= reach then
						for y = 1, size.Y do
							local o = occ[x][y][z]
							local yb = min.Y + (y - 1) * VOXEL
							if mats[x][y][z] ~= Enum.Material.Air and o > 0 and yb + o * VOXEL > lo and yb < hi then
								bad = true
								first = first
									or ("%s at %.0f,%.0f,%.0f road %.1f"):format(
										mats[x][y][z].Name,
										cx,
										yb + o * VOXEL,
										cz,
										p.Y
									)
							end
						end
					end
				end
			end
			if bad then
				hits += 1
			end
		end
		flag(("corridor_clear_%d"):format(line.Number), samples > 0 and hits == 0, hits, 0)
		corridor[tostring(line.Number)] = { samples = samples, hits = hits, first = first }
	end
	r.metrics.corridor = corridor

	-- Gaps: each zone has solid terrain at 3 points in its own gap (nearest centre line is track n, >= 50 away)
	local plazaRadius = ReplicatedStorage:GetAttribute("PlazaRadius")
	plazaRadius = type(plazaRadius) == "number" and plazaRadius or 0
	local function nearestTrack(x, z)
		local best, bestN = math.huge, nil
		for _, line in lines do
			for _, q in line.Pts do
				local dx, dz = q.X - x, q.Z - z
				local d = dx * dx + dz * dz
				if d < best then
					best, bestN = d, line.Number
				end
			end
		end
		return bestN, math.sqrt(best)
	end
	local gaps = {}
	for _, line in lines do
		local pts, found, solid, tried = line.Pts, 0, 0, 0
		for k = 1, 9 do
			local i = math.clamp(math.floor(#pts * k / 10), 2, math.max(2, #pts - 1))
			local p, a, b = pts[i], pts[i - 1], pts[i + 1]
			if found >= GAP_POINTS or not (p and a and b) then
				break
			end
			local dir = Vector2.new(b.X - a.X, b.Z - a.Z)
			dir = dir.Magnitude > 1e-6 and dir.Unit or Vector2.new(1, 0)
			for _, side in { 1, -1 } do
				for _, off in GAP_OFFSETS do
					if found < GAP_POINTS then
						local x, z = p.X - dir.Y * side * off, p.Z + dir.X * side * off
						tried += 1
						task.wait() -- yield per candidate (each scans every centre line)
						local n, d = nearestTrack(x, z)
						if n == line.Number and d >= GAP_MIN_DIST and Vector2.new(x, z).Magnitude > plazaRadius then
							found += 1
							local region =
								Region3.new(Vector3.new(x - 2, COLUMN_LO, z - 2), Vector3.new(x + 2, COLUMN_HI, z + 2))
									:ExpandToGrid(VOXEL)
							local mats, occ = Terrain:ReadVoxels(region, VOXEL)
							local any = false
							for xi = 1, mats.Size.X do
								for yi = 1, mats.Size.Y do
									for zi = 1, mats.Size.Z do
										any = any or (isSolid(mats[xi][yi][zi]) and occ[xi][yi][zi] > 0)
									end
								end
							end
							if any then
								solid += 1
							end
						end
					end
				end
			end
		end
		flag(("gap_points_found_%d"):format(line.Number), found >= GAP_POINTS, found, GAP_POINTS)
		flag(("gap_terrain_solid_%d"):format(line.Number), solid >= GAP_POINTS, solid, GAP_POINTS)
		gaps[tostring(line.Number)] = { tried = tried, found = found, solid = solid }
	end
	r.metrics.gaps = gaps
	return r
end

-- Parses a BiomeZone_<n> attribute "x,z;x,z;..." into a Vector2 list (nil when missing or malformed)
local function parsePolyline(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local out = {}
	for _, pair in string.split(text, ";") do
		if pair ~= "" then
			local x, z = string.match(pair, "^%s*(%-?[%d%.e%-]+)%s*,%s*(%-?[%d%.e%-]+)%s*$")
			x, z = tonumber(x), tonumber(z)
			if not (x and z) then
				return nil
			end
			table.insert(out, Vector2.new(x, z))
		end
	end
	return #out >= 2 and out or nil
end

-- 2. zone_switch (spec 10.2, 3.2, 5.1, 5.3). The harness runs on the server, and the client-local
-- Lighting.ClockTime after forcing a zone cannot be read from here: that half is the client's (UiTest / manual).
-- This scenario tests the pure part: the published polylines, Shared.BiomeEnvironment.ZoneAt and the profiles.
function Tests.zone_switch()
	local r, flag = report("zone_switch")
	local ready, waited = waitTerrainReady()
	flag("terrain_ready", ready)
	r.metrics.waited_s = waited
	r.metrics.client_blend_checked = false -- limitation: needs a client probe (see header)
	local Env = module(Shared, "BiomeEnvironment")
	local zoneAt = Env and type(Env.ZoneAt) == "function" and Env.ZoneAt or nil
	flag("biome_environment_module", Env ~= nil)
	flag("zone_at_api", zoneAt ~= nil)
	local blend = Env and Env.BLEND_SECONDS
	flag("blend_seconds", type(blend) == "number" and blend > 0, type(blend) == "number" and blend or -1, 0)
	local plazaRadius = ReplicatedStorage:GetAttribute("PlazaRadius")
	flag("plaza_radius_attr", type(plazaRadius) == "number" and plazaRadius > 0)
	plazaRadius = type(plazaRadius) == "number" and plazaRadius or 0

	local function zone(p)
		if not zoneAt then
			return nil
		end
		local ok, z = pcall(zoneAt, p)
		return ok and z or nil
	end
	local lift = TrackBuilder.TRACK_LIFT or 1
	flag("zone_at_plaza_is_0", zone(Vector3.new(0, lift, 0)) == 0, zone(Vector3.new(0, lift, 0)) or -1, 0)

	local lines = {}
	for _, line in centreLines(8) do
		lines[line.Number] = line
	end
	local Themes = module(Shared, "BiomeThemes")
	local zones = {}
	for n, biome in BIOMES do
		local poly = parsePolyline(ReplicatedStorage:GetAttribute("BiomeZone_" .. n))
		flag(("zone_polyline_%d"):format(n), poly ~= nil, poly and #poly or 0, 2)
		-- every published point lies on track n's centre line (XZ)
		local off, worst = 0, 0
		local line = lines[n]
		for i, q in poly or {} do
			if i % 20 == 0 then
				task.wait()
			end
			local best = math.huge
			for j = 2, #(line and line.Pts or {}) do
				best = math.min(best, segDistXZ(q.X, q.Y, line.Pts[j - 1], line.Pts[j]))
			end
			worst = math.max(worst, best)
			if best > POLY_TOL then
				off += 1
			end
		end
		flag(("zone_polyline_on_track_%d"):format(n), poly ~= nil and off == 0, off, 0)
		-- ZoneAt is n for every interior polyline point outside the plaza (ends are shared with the neighbours)
		local checked, wrong, firstWrong = 0, 0, nil
		for i = 2, (poly and #poly or 0) - 1 do
			local q = poly[i]
			if q.Magnitude > plazaRadius + PLAZA_CENTRE_TOL then
				checked += 1
				local got = zone(Vector3.new(q.X, lift, q.Y))
				if got ~= n then
					wrong += 1
					firstWrong = firstWrong or ("%.0f,%.0f -> %s"):format(q.X, q.Y, tostring(got))
				end
			end
		end
		flag(("zone_at_track_%d"):format(n), checked > 0 and wrong == 0, wrong, 0)
		-- the profile the client blends to has a ClockTime (spec 5.2)
		local theme = Themes and Themes[biome]
		local atmo = type(theme) == "table" and type(theme.Atmosphere) == "table" and theme.Atmosphere or {}
		local light = type(atmo.Lighting) == "table" and atmo.Lighting or {}
		local clock = light.ClockTime
		flag(
			("profile_clock_time_%d"):format(n),
			type(clock) == "number" and clock >= 0 and clock < 24,
			type(clock) == "number" and clock or -1,
			24
		)
		zones[tostring(n)] =
			{ points = poly and #poly or 0, worst_off = math.round(worst * 100) / 100, first_wrong = firstWrong }
	end
	r.metrics.zones = zones
	return r
end

-- 3. server_lighting_unchanged (spec 10.3, 1, 8): the environment Lighting snapshot, taken again after
-- TerrainReady, equals the one at scenario start and the LightingConfig baseline (weather-owned ClockTime,
-- Brightness and OutdoorAmbient only while ReplicatedStorage.WeatherEvent is empty).
function Tests.server_lighting_unchanged()
	local r, flag = report("server_lighting_unchanged")
	local before = lightingSnapshot()
	local ready, waited = waitTerrainReady()
	flag("terrain_ready", ready)
	r.metrics.waited_s = waited
	task.wait(1) -- a frame or more after the build, so any late write shows
	local after = lightingSnapshot()
	local function same(a, b)
		if typeof(a) == "Color3" and typeof(b) == "Color3" then
			return colorDiff(a, b) <= LIGHT_TOL
		elseif type(a) == "number" and type(b) == "number" then
			return math.abs(a - b) <= LIGHT_TOL
		end
		return a == b
	end
	local changed = {}
	for k, v in before do
		if not same(v, after[k]) then
			table.insert(changed, k)
		end
	end
	table.sort(changed)
	flag("snapshot_unchanged", #changed == 0, #changed, 0)
	r.metrics.changed = table.concat(changed, ",")

	local Config = module(Shared, "LightingConfig")
	flag("lighting_config", Config ~= nil)
	local event = ReplicatedStorage:GetAttribute("WeatherEvent")
	local weatherOn = type(event) == "string" and event ~= ""
	r.metrics.weather_event = weatherOn and event or ""
	local WEATHER_PROPS = { ClockTime = true, Brightness = true, OutdoorAmbient = true }
	local off = {}
	for prop, want in Config and Config.Lighting or {} do
		if not (weatherOn and WEATHER_PROPS[prop]) and not same(Lighting[prop], want) then
			table.insert(off, prop)
		end
	end
	for _, effect in Config and Config.Effects or {} do
		local inst = Lighting:FindFirstChild(effect[2])
		if not (inst and inst:IsA(effect[1])) then
			table.insert(off, effect[2])
		else
			for prop, want in effect[3] do
				if not same(inst[prop], want) then
					table.insert(off, effect[2] .. "." .. prop)
				end
			end
		end
	end
	table.sort(off)
	flag("lighting_at_baseline", Config ~= nil and #off == 0, #off, 0)
	r.metrics.off_baseline = table.concat(off, ",")
	flag(
		"no_new_sky_atmosphere_clouds",
		after.Sky == before.Sky and after.Atmosphere == before.Atmosphere and after.Clouds == before.Clouds
	)
	return r
end

local ASSET_KINDS = { Mesh = true, Texture = true, Skybox = true, Sound = true }
local ASSET_LANES = { A = true, B = true, C = true, D = true }
local ASSET_ID = "^rbxassetid://%d+$"
local REVIEWED = "^%d%d%d%d%-%d%d%-%d%d %S" -- spec 4.1 step 3: "<date> <who>"

local function nonEmpty(v)
	return type(v) == "string" and string.match(v, "%S") ~= nil
end

-- Spec 4.4 ledger row shape. Returns a problem string or nil.
local function ledgerRowProblem(row)
	if type(row) ~= "table" then
		return "shape"
	elseif not ASSET_KINDS[row.Kind] then
		return "kind"
	elseif not ASSET_LANES[row.Lane] then
		return "lane"
	elseif row.Id ~= nil and not (type(row.Id) == "string" and string.match(row.Id, ASSET_ID)) then
		return "id"
	elseif (row.Lane == "A" or row.Lane == "B") and not nonEmpty(row.Prompt) then
		return "prompt" -- spec 4.1 step 2: the generation prompt is stored in the ledger
	elseif row.Lane == "D" and not (nonEmpty(row.Creator) and row.Id ~= nil) then
		return "creator" -- spec 4.1 Lane D: Creator and the Creator Store asset id
	elseif row.Reviewed ~= nil and not (type(row.Reviewed) == "string" and string.match(row.Reviewed, REVIEWED)) then
		return "reviewed"
	end
	return nil
end

-- Every asset key a biome def uses: { Kind, Key } for Mesh = / Skybox = / Sound = strings anywhere (ledger excluded)
-- and the Audio Loop / OneShots keys (spec 6, 9.1)
local function usedAssetKeys(def)
	local out, seen = {}, {}
	local function walk(t)
		if type(t) ~= "table" or seen[t] then
			return
		end
		seen[t] = true
		for k, v in t do
			if (k == "Mesh" or k == "Skybox" or k == "Sound") and type(v) == "string" then
				table.insert(out, { Kind = k, Key = v })
			end
			if k ~= "Assets" then
				walk(v)
			end
		end
	end
	walk(def)
	local audio = type(def.Audio) == "table" and def.Audio or {}
	if type(audio.Loop) == "string" then
		table.insert(out, { Kind = "Sound", Key = audio.Loop })
	end
	for _, key in type(audio.OneShots) == "table" and audio.OneShots or {} do
		if type(key) == "string" then
			table.insert(out, { Kind = "Sound", Key = key })
		end
	end
	return out
end

-- 4. assets_ip (spec 10.4, 4.1-4.4, 9.1; design doc 5)
function Tests.assets_ip()
	local r, flag = report("assets_ip")
	local realNameIn = require(script.Parent.CatalogTests).realNameIn
	local folder = Shared:FindFirstChild("BiomeThemes")
	local problems = {}
	for _, biome in BIOMES do
		local def = folder and module(folder, biome)
		flag(("biome_module_%s"):format(biome), def ~= nil)
		local d = def or {}
		flag(
			("biome_module_sections_%s"):format(biome),
			def ~= nil
				and type(d.Terrain) == "table"
				and type(d.Atmosphere) == "table"
				and type(d.Audio) == "table"
				and type(d.Assets) == "table"
		)
		-- IP (design doc 5): no real names anywhere in the module, ledger prompts and creators included
		local hit = nil
		for _, text in themeStrings(def) do
			if realNameIn(nameKey(text)) then
				hit = hit or text
			end
		end
		flag(("biome_module_no_real_names_%s"):format(biome), def ~= nil and hit == nil)
		r.metrics[("real_name_%s"):format(biome)] = hit and realNameIn(nameKey(hit)) -- hash only, never the name
		local ivs = 0
		for _, id in themeAssetIds(def) do
			if IVS_ASSET_IDS[id] then
				ivs += 1
			end
		end
		flag(("biome_module_no_ivs_assets_%s"):format(biome), def ~= nil and ivs == 0, ivs, 0)
		-- Ledger rows (spec 4.4)
		local ledger = type(d.Assets) == "table" and d.Assets or {}
		local badRows, firstRow = 0, nil
		for key, row in ledger do
			local problem = ledgerRowProblem(row)
			if problem then
				badRows += 1
				firstRow = firstRow or (tostring(key) .. ":" .. problem)
			end
		end
		flag(("ledger_rows_valid_%s"):format(biome), def ~= nil and badRows == 0, badRows, 0)
		-- Every Mesh / Skybox / Sound key used resolves to a ledger row of that Kind with an Id and Reviewed
		local unresolved, firstKey = 0, nil
		for _, use in usedAssetKeys(d) do
			local row = ledger[use.Key]
			local ok = type(row) == "table"
				and row.Kind == use.Kind
				and type(row.Id) == "string"
				and string.match(row.Id, ASSET_ID) ~= nil
				and type(row.Reviewed) == "string"
				and string.match(row.Reviewed, REVIEWED) ~= nil
			if not ok then
				unresolved += 1
				firstKey = firstKey or (use.Kind .. ":" .. use.Key)
			end
		end
		flag(("assets_used_resolve_%s"):format(biome), def ~= nil and unresolved == 0, unresolved, 0)
		if firstRow or firstKey then
			problems[biome] = firstRow or firstKey
		end
	end
	r.metrics.problems = problems

	-- The environment prop clearance check, on the LIVE world after SnapToTerrain (Main.server step 5)
	local Dressing = module(Shared, "BiomeDressing")
	flag("snap_to_terrain_api", Dressing ~= nil and type(Dressing.SnapToTerrain) == "function")
	local ready, waited = waitTerrainReady()
	flag("terrain_ready", ready)
	r.metrics.waited_s = waited
	local trackFolder = Workspace:FindFirstChild("Track")
	local numberOf, models = {}, {}
	for _, spec in TrackRegistry.Chain() do
		local m = trackFolder and trackFolder:FindFirstChild(spec.Name)
		if m then
			numberOf[m] = spec.Number
			table.insert(models, m)
		end
	end
	flag("live_tracks", #models == #BIOMES, #models, #BIOMES)
	local extra = {}
	for _, name in { "SpawnArea", "Workshops" } do
		local root = Workspace:FindFirstChild(name)
		flag(("live_%s"):format(string.lower(name)), root ~= nil)
		table.insert(extra, root)
	end
	local grid, obstacles = obstacleGrid(models, extra)
	r.metrics.obstacles = obstacles
	local clearance = Dressing and type(Dressing.CLEARANCE) == "number" and Dressing.CLEARANCE or 8
	local grow = clearance - GEOM_TOL
	local live = {}
	for _, m in models do
		local n = numberOf[m]
		local env = m:FindFirstChild("Environment")
		local parts = baseParts(env)
		local hits, firstBad = 0, nil
		for i, part in parts do
			if i % 300 == 0 then
				task.wait() -- yield only: tens of thousands of live props
			end
			local o = firstHit(grid, part, grow)
			if o then
				hits += 1
				firstBad = firstBad or (part:GetFullName() .. " -> " .. o.Name)
			end
		end
		flag(("live_props_clear_of_road_%d"):format(n), env ~= nil and #parts > 0 and hits == 0, hits, 0)
		live[tostring(n)] = { parts = #parts, hits = hits, first = firstBad }
	end
	r.metrics.live = live
	return r
end

return Tests
