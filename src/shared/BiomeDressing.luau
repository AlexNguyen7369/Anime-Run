--!nonstrict
-- Deterministic, non-colliding drive-by scenery for every track (docs/BIOME_DRESSING_SPEC.md).
-- Build(model, layout, spec, origin) dresses one track from Shared/BiomeThemes[spec.Biome].
-- Prune(trackModels, extra) runs after the whole chain is built and removes props too close to any road.
-- SnapToTerrain(trackModels) drops every prop onto Shared/TerrainShape's height (docs/BIOME_ENVIRONMENT_SPEC.md 3.2).
-- A prop def with Mesh = "<AssetKey>" is one uploaded MeshPart from BiomeDressing.Assets (Server/BiomeAssets, set by
-- Main.server) when its ledger row is usable, and its Parts otherwise (spec 4.2). Hero = true marks a hero landmark
-- (Atomic streaming, SLIM level of detail, spec 4.3).

local CollectionService = game:GetService("CollectionService")
local Themes = require(script.Parent.BiomeThemes)
local HudFormat = require(script.Parent.HudFormat)
local UiTheme = require(script.Parent.UiTheme)
local NpcConfig = require(script.Parent.NpcConfig)
local RaceConfig = require(script.Parent.RaceConfig)

local BiomeDressing = {}
BiomeDressing.Assets = nil -- the mesh registry ({ Clone(biome, key, size) }); nil builds every prop from parts
BiomeDressing.CLEARANCE = 8 -- studs every prop keeps from any road, wall, checkpoint, pad or spawn-area part
BiomeDressing.BUDGET = 1200 -- BaseParts per BUDGET_STUDS of track (owner 2026-10-27; length-scaled 2026-10-30)
BiomeDressing.BUDGET_STUDS = 3000 -- placeholder: a track's budget is BUDGET per this many studs, never below BUDGET
-- Size factor per layer (owner 2026-10-27, placeholders); Rhythm and the gate keep their theme sizes
BiomeDressing.SCALE = { Landmarks = 1.75, Horizon = 2, Scatter = 1.5 }
BiomeDressing.GATE_HEIGHT = 28 -- studs from the road to the gate beam
BiomeDressing.PARTICLE_MAX_RATE = 8 -- particles per second per landmark emitter
BiomeDressing.EMITTER_TAG = "BiomeEmitter" -- on each landmark emitter: Client/BiomeEnvironment turns it off under
-- REDUCED EFFECTS
BiomeDressing.TUNNEL_INSET = 1 -- placeholder: studs a tunnel prop keeps from the tunnel wall and the platform edge
-- placeholder: extra wall gap per stud of a tunnel prop's half-length. The prop is square to its waypoint's tangent,
-- the wall is a chord (Tunnel.CHORD_XZ), up to ~4.5 degrees apart on a 320-stud bend
BiomeDressing.TUNNEL_TURN = 0.1

local GROUND_Y = -1 -- TrackBuilder GROUND_TOP: props stand on the grass
local GROUND_STEP = 0.02 -- studs each later track's ground sits below the previous one
local WALL = 2 -- studs of wall outside the road edge
local GATE_INDEX = 4 -- waypoint of the start gate (past the previous track's checkpoint)
local HORIZON_EVERY = 30 -- waypoints between horizon pieces on long runs without corners
local HORIZON_FIT = { 1, 0.75, 0.5, 1 / 3 } -- fractions of the horizon Offset tried until the piece fits on the ground
local PATCH_THICKNESS = 0.2 -- studs: ground patches are flat slabs
local SCATTER_PASSES = 4 -- scatter spots are visited in interleaved passes so a full budget still covers the whole track
local GRID = 64 -- studs per broad-phase cell in Prune
local HERO_STRAIGHT = 200 -- studs: a straight this long is a hero spot (spec 4.3)
local SNAP_SINK = 1 -- placeholder: a snapped prop's base sits at most this far below the ground at its centre
local SNAP_OVERHANG = 6 -- placeholder: a landmark's footprint corner may sit at most this far below its snapped base
local SNAP_SLIDE_STEP = 4 -- placeholder: studs per try when a prop slides toward its road to fit
local SNAP_SLIDE_MAX = 24 -- placeholder: the farthest a prop slides before it is dropped
-- placeholder: a padded prop's (house's) pad reaches this far past its footprint (spec 3.2); at least one terrain
-- voxel (4 studs), so the drawn surface under the footprint edge interpolates only flat pad columns
local PAD_MARGIN = 4
local HERO_FLOOR = 2 -- spec 3.2 (owner 2026-10-31): hero landmarks are never deleted below this many per biome
-- Shares of the budget left after the gate, landmarks and horizon (owner 2026-10-30: every layer gets built).
-- Each layer may use its share; what it leaves rolls on to the next one.
local SHARE = { Rhythm = 0.35, Blocks = 0.35 } -- scatter gets the rest

local MeshData = script.Parent:WaitForChild("BiomeMeshData")
local dataCache = {}
-- Baked CC0 mesh of a prop (Shared/BiomeMeshData/<Biome>), or nil when the prop only has fallback parts.
function BiomeDressing.MeshFor(biome, name)
	if dataCache[biome] == nil then
		local module = MeshData:FindFirstChild(biome)
		dataCache[biome] = module and require(module) or false
	end
	return dataCache[biome] and dataCache[biome][name] or nil
end

-- The prop's real size: a baked mesh keeps its proportions and is scaled to the prop's height.
local function footprint(biome, def)
	local mesh = BiomeDressing.MeshFor(biome, def.Name)
	return mesh and mesh.Size * (def.Size.Y / mesh.Size.Y) or def.Size
end

local boxCache = setmetatable({}, { __mode = "k" })
-- The prop's box for the tunnel fit (spec 3.5): its footprint grown to every fallback part's corners (eaves and
-- roofs may reach past def.Size), symmetric across its centre in X and Z, from its base to its top in Y.
local function tunnelBox(biome, def)
	if not boxCache[def] then
		local box = footprint(biome, def)
		for _, p in def.Parts do
			local cf = CFrame.new(p.Pos) * (p.Rot or CFrame.identity)
			for _, c in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, 1) } do
				for _, k in { 1, -1 } do
					local q = cf:PointToWorldSpace(c * k * p.Size / 2)
					box = box:Max(Vector3.new(2 * math.abs(q.X), q.Y, 2 * math.abs(q.Z)))
				end
			end
		end
		boxCache[def] = box
	end
	return boxCache[def]
end

local scaledCache = setmetatable({}, { __mode = "k" })
-- A prop grown by k: part sizes and offsets alike, same Name (so the same baked mesh, scaled to the new height).
local function scaled(def, k)
	if not k or k == 1 then
		return def
	end
	local byK = scaledCache[def] or {}
	scaledCache[def] = byK
	if not byK[k] then
		local copy = table.clone(def)
		copy.Size = def.Size * k
		copy.Parts = {}
		for i, p in def.Parts do
			local q = table.clone(p)
			q.Size = p.Size * k
			q.Pos = p.Pos * k
			copy.Parts[i] = q
		end
		byK[k] = copy
	end
	return byK[k]
end

local function visual(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- Theme particle settings -> a ParticleEmitter (spec Layers 8: one per landmark, capped Rate).
local function emitter(parent, cfg)
	local e = Instance.new("ParticleEmitter")
	e.Name = "BiomeParticles"
	e.Texture = cfg.Texture
	e.Color = typeof(cfg.Color) == "ColorSequence" and cfg.Color or ColorSequence.new(cfg.Color)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, cfg.Size),
		NumberSequenceKeypoint.new(1, cfg.Size * 0.6),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, cfg.Transparency or 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(cfg.Lifetime * 0.7, cfg.Lifetime)
	e.Rate = math.min(cfg.Rate, BiomeDressing.PARTICLE_MAX_RATE)
	e.Speed = NumberRange.new(cfg.Speed * 0.5, cfg.Speed)
	e.SpreadAngle = Vector2.new(cfg.Spread or 180, cfg.Spread or 180)
	e.Acceleration = cfg.Acceleration or Vector3.zero
	e.EmissionDirection = cfg.Direction or Enum.NormalId.Top
	e.LightEmission = cfg.LightEmission or 0
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	CollectionService:AddTag(e, BiomeDressing.EMITTER_TAG)
	e.Parent = parent
end

local meshOk = {} -- "<biome>/<key>" -> true once that uploaded mesh has been placed

-- Budget parts a def will take: 1 for an uploaded mesh known to load (spec 4.5), else its Parts plus `extra`.
-- A mesh's first placement is costed as its parts, since the load can still fail and fall back to them.
local function cost(biome, def, extra)
	return def.Mesh and meshOk[biome .. "/" .. def.Mesh] and 1 or #def.Parts + extra
end

-- One prop as a Model whose base centre is `base` and whose -Z faces the road. `inTunnel`: it stands inside a
-- Tunnel (spec 3.5), so SnapToTerrain leaves it where it is.
local function place(folder, biome, def, base, name, glow, particles, inTunnel)
	local model = Instance.new("Model")
	model.Name = name
	if inTunnel then
		model:SetAttribute("Tunnel", true)
	end
	local mesh = def.Mesh and BiomeDressing.Assets and BiomeDressing.Assets.Clone(biome, def.Mesh, def.Size)
	if mesh then
		meshOk[biome .. "/" .. def.Mesh] = true
	end
	if mesh then
		mesh.Name = def.Name
		mesh.CFrame = base * CFrame.new(0, def.Size.Y / 2, 0)
		mesh.Parent = model
	end
	if def.Pad then
		model:SetAttribute("Pad", true) -- SnapToTerrain levels a small pad under it (spec 3.2)
	end
	if def.Hero then
		model:SetAttribute("Hero", true) -- SnapToTerrain's hero floor
		if def.At then
			model:SetAttribute("Pinned", true) -- spec 3.2 (owner 2026-10-31): a pinned hero is never deleted
		end
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		-- SLIM where the engine has it, StreamingMesh otherwise. Game scripts lack the PluginOrOpenCloud capability
		-- to write LevelOfDetail at runtime, so both are pcalled; Atomic still applies.
		if not pcall(function()
			model.LevelOfDetail = Enum.ModelLevelOfDetail.SLIM
		end) then
			pcall(function()
				model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
			end)
		end
	end
	for i, p in mesh and {} or def.Parts do
		local part = Instance.new("Part")
		part.Name = def.Name .. i
		part.Size = p.Size
		part.CFrame = base * CFrame.new(p.Pos) * (p.Rot or CFrame.identity)
		part.Color = p.Color
		part.Material = p.Material or Enum.Material.SmoothPlastic
		if p.Shape then
			part.Shape = p.Shape
		end
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		visual(part)
		part.Parent = model
	end
	if not mesh and BiomeDressing.MeshFor(biome, def.Name) then
		-- Invisible box at the mesh's real size: Prune checks it, and Client/BiomeMeshes puts the mesh there
		-- and hides the fallback parts (EditableMesh content does not replicate, so each client builds it).
		local size = footprint(biome, def)
		local bounds = Instance.new("Part")
		bounds.Name = "MeshBounds"
		bounds.Size = size
		bounds.CFrame = base * CFrame.new(0, size.Y / 2, 0)
		bounds.Transparency = 1
		visual(bounds)
		bounds.Parent = model
		model:SetAttribute("Mesh", biome .. "_" .. def.Name)
		CollectionService:AddTag(model, "BiomeMesh")
	end
	for _, part in model:GetChildren() do
		part.CastShadow = def.Size.Magnitude > 30 -- small props cast no shadow
	end
	if glow and def.Glow then
		local light = Instance.new("PointLight")
		light.Color = def.Glow
		light.Range = 24
		light.Shadows = false
		light.Parent = model:GetChildren()[1]
	end
	if particles then
		emitter(model:GetChildren()[1], particles)
	end
	if def.Tag then
		model:SetAttribute("BasePivot", model:GetPivot()) -- Client/BiomeAmbience's rest pose (it streams in late)
		CollectionService:AddTag(model, def.Tag)
	end
	model.Parent = folder
	return #model:GetChildren()
end

local function flat(vector)
	local f = Vector3.new(vector.X, 0, vector.Z)
	return f.Magnitude > 1e-4 and f.Unit or Vector3.new(0, 0, -1)
end

-- World base CFrame `distance` studs to one side (-1 left, 1 right) of waypoint i, on the ground, facing the road.
-- `t` (optional, 0..1) slides the point that far toward waypoint i + 1, for layers spaced in studs, not waypoints.
local function beside(layout, origin, i, side, distance, t)
	local wps = layout.Waypoints
	local tangent = flat(wps[math.min(#wps, i + 1)] - wps[math.max(1, i - 1)])
	local right = Vector3.new(-tangent.Z, 0, tangent.X)
	local at = t and wps[i]:Lerp(wps[math.min(#wps, i + 1)], t) or wps[i]
	local point = origin:PointToWorldSpace(at + right * side * distance)
	local toRoad = flat(origin:VectorToWorldSpace(-right * side))
	local base = Vector3.new(point.X, GROUND_Y, point.Z)
	return CFrame.lookAt(base, base + toRoad)
end

-- Where props stand on a Tunnel track (spec 3.5, fw6). `right` above is the Tunnel's piece-local +X for the same
-- tangent ((-f.Z, 0, f.X) in both), so side -1 is the Tunnel's Left and 1 its Right. Returns:
--   Spot(i, side, distance, t, size): the base CFrame (as beside, `distance` clamped into the room) of a prop of
--     `size` (X along the road, Z across) inside the walls at road Y, or on the bay platform at road Y +
--     Tunnel.PLATFORM where a bay on `side` covers its whole length; nil outside the span or where it does not fit
--     (width, or the ceiling over it)
--   Bay(at): the bay covering fraction `at` of the track (nil if none) and the waypoint nearest that point
--   Cum (XZ studs from the start per waypoint) and S0 (where the tunnel starts)
local function tunnelSpots(layout, origin, def, edge)
	local Tunnel = require(script.Parent.Tunnel) -- here, not at the top: Tunnel requires this module
	local wps = layout.Waypoints
	local s0, s1, total = Tunnel.Span(layout)
	local cum = { 0 }
	for k = 2, #wps do
		cum[k] = cum[k - 1] + Vector2.new(wps[k].X - wps[k - 1].X, wps[k].Z - wps[k - 1].Z).Magnitude
	end
	local half, inset = (def.Width or 60) / 2, BiomeDressing.TUNNEL_INSET
	local spots = { Cum = cum, S0 = s0 }
	-- road Y (world) at track position s, searching from waypoint k
	local function roadY(s, k)
		while k > 1 and cum[k] > s do
			k -= 1
		end
		while k < #wps - 1 and cum[k + 1] < s do
			k += 1
		end
		local u = math.clamp((s - cum[k]) / math.max(1e-6, cum[k + 1] - cum[k]), 0, 1)
		return origin:PointToWorldSpace(wps[k]:Lerp(wps[k + 1], u)).Y
	end
	function spots.Spot(i, side, distance, t, size)
		local j = math.min(#wps, i + 1)
		local s = cum[i] + (cum[j] - cum[i]) * (t or 0)
		local a = size.X / 2
		-- on the inside of a bend the prop's far corners reach farther along the track than its centre line
		local l0, r0 = Tunnel.Section(def, s, total)
		local curv = math.max(layout.Curvature[i] or 0, layout.Curvature[j] or 0)
		local reach = a / math.max(0.25, 1 - (side < 0 and l0 or r0) * curv)
		if s - reach < s0 or s + reach > s1 then
			return nil
		end
		local inner, height, bay = math.huge, math.huge, nil
		for _, at in { s - reach, s, s + reach } do
			local l, r, h, bayL, bayR = Tunnel.Section(def, at, total)
			local b = side < 0 and bayL or bayR
			if bay ~= nil and b ~= bay then
				return nil -- straddles a bay end
			end
			bay, inner, height = b, math.min(inner, side < 0 and l or r), math.min(height, h)
		end
		local lift = bay and Tunnel.PLATFORM or 0
		local lo = (bay and half or edge) + inset
		local hi = (bay and inner or half) - inset - a * BiomeDressing.TUNNEL_TURN
		-- on a slope the flat prop's base sits at the road Y under its centre, so its downhill end has half the rise
		-- less headroom (and its uphill end sinks that much into the floor)
		local rise = math.abs(roadY(s + a, i) - roadY(s - a, i)) / 2
		if hi - lo < size.Z or lift + size.Y + rise > height then
			return nil
		end
		local d = math.clamp(distance, lo + size.Z / 2, hi - size.Z / 2)
		local road = origin:PointToWorldSpace(t and wps[i]:Lerp(wps[j], t) or wps[i]).Y
		return beside(layout, origin, i, side, d, t) + Vector3.new(0, road + lift - GROUND_Y, 0)
	end
	function spots.Bay(at)
		local target = math.clamp(at, 0, 1) * total
		local best = 1
		for k = 2, #wps do
			if math.abs(cum[k] - target) < math.abs(cum[best] - target) then
				best = k
			end
		end
		for _, bay in def.Bays or {} do
			if target >= (bay.From or 0) * total and target < (bay.To or 1) * total then
				return bay, best
			end
		end
		return nil, best
	end
	return spots
end

-- Corners (runs of curvature) with their middle waypoint and outside side, and the tops of climbs.
local function features(layout)
	local wps, curv = layout.Waypoints, layout.Curvature
	local corners, crests = {}, {}
	local i = 2
	while i < #wps do
		if (curv[i] or 0) > 0 then
			local s = i
			while i < #wps and (curv[i + 1] or 0) > 0 do
				i += 1
			end
			local t1 = flat(wps[s] - wps[s - 1])
			local t2 = flat(wps[math.min(#wps, i + 1)] - wps[i])
			local cross = t1.Z * t2.X - t1.X * t2.Z -- > 0 for a left turn, whose outside is the right
			table.insert(corners, { Index = (s + i) // 2, Exit = math.min(#wps, i + 1), Side = cross > 0 and 1 or -1 })
		end
		i += 1
	end
	local rise = 0
	for j = 2, #wps - 1 do
		local dy = wps[j].Y - wps[j - 1].Y
		rise = dy > 0.05 and rise + dy or 0
		if rise >= 8 and wps[j + 1].Y - wps[j].Y <= 0.05 then
			table.insert(crests, j)
		end
	end
	return corners, crests
end

-- Hero spot for At (fraction of track length, spec 4.3): the waypoint nearest that length among corner exits and
-- straights of HERO_STRAIGHT+ studs (any waypoint along one); the target waypoint itself when there is neither.
-- Returns the waypoint and the side (a corner's outside; straights alternate by `n`).
local function heroSpot(layout, corners, at, n)
	local wps, curv = layout.Waypoints, layout.Curvature
	local cum = { 0 }
	for i = 2, #wps do
		cum[i] = cum[i - 1] + (wps[i] - wps[i - 1]).Magnitude
	end
	local target = math.clamp(at, 0, 1) * cum[#wps]
	local best, bestGap, side = 1, math.huge, n % 2 == 0 and 1 or -1
	for i = 1, #wps do
		if math.abs(cum[i] - target) < math.abs(cum[best] - target) then
			best = i
		end
	end
	local function offer(i, s)
		if math.abs(cum[i] - target) < bestGap then
			best, bestGap, side = i, math.abs(cum[i] - target), s
		end
	end
	for _, c in corners do
		offer(c.Exit, c.Side)
	end
	local i = 1
	while i < #wps do
		local s = i
		while i < #wps and (curv[i + 1] or 0) == 0 do
			i += 1
		end
		if cum[i] - cum[s] >= HERO_STRAIGHT then
			for j = s, i do
				offer(j, n % 2 == 0 and 1 or -1)
			end
		end
		i += 1
	end
	return best, side
end

local function near(list, index, gap)
	for _, other in list do
		if math.abs(other - index) < gap then
			return true
		end
	end
	return false
end

-- Arch over the road at the track start: posts outside the clearance, beam GATE_HEIGHT above the road.
local SIGN_HEIGHT = 8 -- studs the gate sign hangs below the beam

-- The biome's working name in upper case ("LEAFWIND VILLAGE"); a key without a theme splits its words
local function biomeTitle(biome)
	local theme = Themes[biome]
	local name = theme and theme.DisplayName or string.gsub(biome, "(%l)(%u)", "%1 %2")
	return string.upper(name)
end
BiomeDressing.Title = biomeTitle

-- The recommended Speed for track n: the stat whose cruise speed matches its NPC (gate sign, checkpoint panel).
function BiomeDressing.RecSpeed(n)
	return RaceConfig.StatFor(NpcConfig.For(n or 1).Speed)
end

-- Text on the sign's face toward the oncoming car: the biome and the recommended Speed (owner 2026-10-21).
local function signText(sign, spec)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GateSignGui"
	gui.Face = Enum.NormalId.Back -- +Z: the car drives toward -Z (look direction)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = sign
	local function line(name, text, y, height, color)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.05, y)
		label.Size = UDim2.fromScale(0.9, height)
		label.Font = UiTheme.Font
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		UiTheme.Stroke(label, 2)
		label.Parent = gui
	end
	local rec = BiomeDressing.RecSpeed(spec.Number)
	-- SpeedText shows a non-finite number as 0; Short shows "inf"
	local recText = rec == math.huge and HudFormat.Short(rec) or HudFormat.SpeedText(rec)
	line("Biome", biomeTitle(spec.Biome), 0.06, 0.52, Color3.new(1, 1, 1))
	line("RecSpeed", "REC. SPEED " .. recText, 0.6, 0.34, Color3.fromRGB(255, 220, 60))
end

local function gate(folder, layout, origin, theme, spec, tunnel)
	local wps = layout.Waypoints
	local at = theme.Gate.Index or GATE_INDEX
	if #wps <= at + 1 then
		return 0
	end
	if tunnel then
		-- spec 3.5 (fw6): on a Tunnel track the gate stands in front of the start portal, never under the ceiling.
		-- Without Gate.Index it moves back to the last waypoint whose posts (4 deep) end before the portal.
		local post = 2
		if not theme.Gate.Index then
			while at > 2 and tunnel.Cum[at] + post > tunnel.S0 do
				at -= 1
			end
		end
		if tunnel.Cum[at] + post > tunnel.S0 then
			warn(
				string.format(
					"[BiomeDressing] gate of track %s at waypoint %d is inside its tunnel: not built",
					tostring(spec.Number),
					at
				)
			)
			return 0
		end
	end
	local road = origin:PointToWorldSpace(wps[at])
	local tangent = flat(origin:VectorToWorldSpace(wps[at + 1] - wps[at - 1]))
	local look = CFrame.lookAt(road, road + tangent)
	local lateral = layout.Width / 2 + BiomeDressing.CLEARANCE + 6
	local postHeight = road.Y + BiomeDressing.GATE_HEIGHT - GROUND_Y
	local model = Instance.new("Model")
	model.Name = "Gate"
	local function piece(name, size, cf, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = cf
		part.Color = color
		part.Material = material
		visual(part)
		part.Parent = model
		return part
	end
	for _, side in { -1, 1 } do
		local foot = (look * CFrame.new(side * lateral, 0, 0)).Position
		piece(
			"GatePost" .. (side < 0 and "L" or "R"),
			Vector3.new(4, postHeight, 4),
			CFrame.new(foot.X, GROUND_Y + postHeight / 2, foot.Z) * look.Rotation,
			theme.Gate.Color,
			theme.Gate.Material
		)
	end
	local beam = piece(
		"GateBeam",
		Vector3.new(lateral * 2 + 4, 3, 4),
		look * CFrame.new(0, BiomeDressing.GATE_HEIGHT, 0),
		theme.Gate.Color,
		theme.Gate.Material
	)
	local sign = piece(
		"GateSign",
		Vector3.new(math.min(lateral * 2 - 8, 48), SIGN_HEIGHT, 0.5),
		look * CFrame.new(0, BiomeDressing.GATE_HEIGHT - 1.5 - SIGN_HEIGHT / 2, 2.3),
		Color3.fromRGB(20, 22, 30),
		Enum.Material.SmoothPlastic
	)
	signText(sign, spec)
	if theme.Gate.Glow then
		local light = Instance.new("PointLight")
		light.Color = theme.Gate.Glow
		light.Range = 30
		light.Shadows = false
		light.Parent = beam
	end
	model.Parent = folder
	return #model:GetChildren()
end

-- 0..1 from a waypoint, a side and a salt: variety without randomness, so two builds are identical.
local function hash(i, side, salt)
	local x = math.sin(i * 12.9898 + side * 78.233 + salt * 37.719) * 43758.5453
	return x - math.floor(x)
end

-- Scatter layer (spec Layers 7): props and flat ground patches between Near and Far studs from the road edge,
-- built last into whatever budget is left. Returns the new part count. `spot` is Build's (spec 3.5 on a Tunnel track).
local function scatter(folder, layout, origin, theme, biome, ground, edge, count, onGround, budget, spot)
	local s, wps = theme.Scatter, layout.Waypoints
	local named = {}
	for _, layer in { theme.Rhythm, theme.Landmarks } do
		for _, def in layer.Props do
			named[def.Name] = def
		end
	end
	local groundTop = ground and ground.Position.Y + ground.Size.Y / 2 or GROUND_Y
	local stride = s.Every * SCATTER_PASSES
	for pass = 0, SCATTER_PASSES - 1 do
		for i = 2 + pass * s.Every, #wps - 1, stride do
			for _, side in { -1, 1 } do
				local tag = i .. (side < 0 and "L" or "R")
				local def = s.Props[math.floor(hash(i, side, 1) * 1000) % #s.Props + 1]
				def = scaled(named[def] or def, BiomeDressing.SCALE.Scatter)
				local size = footprint(biome, def)
				local reach = Vector2.new(size.X, size.Z).Magnitude / 2
				local distance = edge + s.Near + (s.Far - s.Near) * hash(i, side, 2) + reach
				local box = tunnelBox(biome, def)
				local turned = Vector2.new(box.X, box.Z).Magnitude -- turned freely: its diagonal both ways
				local base, inTunnel = spot(s, i, side, distance, nil, Vector3.new(turned, box.Y, turned))
				base = base and base * CFrame.Angles(0, hash(i, side, 3) * 2 * math.pi, 0)
				-- The patch (one part) goes first, so a tight budget still covers the ground. No ground patches
				-- inside a tunnel.
				if (i // s.Every) % 2 == 0 and count + 1 <= budget and not inTunnel then
					local p = s.Patches[math.floor(hash(i, side, 4) * 1000) % #s.Patches + 1]
					local patchReach = Vector2.new(p.Size.X, p.Size.Z).Magnitude / 2
					local at = edge + s.Near + (s.Far - s.Near) * hash(i, side, 5) + patchReach
					local cf = beside(layout, origin, i, side, at) * CFrame.Angles(0, hash(i, side, 6) * math.pi, 0)
					if onGround(cf, patchReach) then
						local slab = Instance.new("Part")
						slab.Name = p.Name .. "1"
						slab.Size = Vector3.new(p.Size.X, PATCH_THICKNESS, p.Size.Z)
						slab.CFrame = cf - Vector3.new(0, cf.Position.Y - groundTop - PATCH_THICKNESS / 2, 0)
						slab.Color = p.Color
						slab.Material = p.Material
						slab.TopSurface = Enum.SurfaceType.Smooth
						slab.BottomSurface = Enum.SurfaceType.Smooth
						slab.CastShadow = false
						visual(slab)
						local patch = Instance.new("Model")
						patch.Name = "Patch_" .. tag
						slab.Parent = patch
						patch.Parent = folder
						count += 1
					end
				end
				if base and count + cost(biome, def, 1) <= budget and onGround(base, reach) then
					count += place(folder, biome, def, base, "Scatter_" .. tag, false, nil, inTunnel)
				end
			end
		end
	end
	return count
end

-- Footprints (XZ) of two ground-standing boxes overlap: 2D separating axis test.
local function footprintsOverlap(a, b)
	local axes = { a.CFrame.RightVector, a.CFrame.LookVector, b.CFrame.RightVector, b.CFrame.LookVector }
	local d = b.CFrame.Position - a.CFrame.Position
	for _, axis in axes do
		axis = flat(axis)
		local function radius(box)
			return math.abs(flat(box.CFrame.RightVector):Dot(axis)) * box.Half.X
				+ math.abs(flat(box.CFrame.LookVector):Dot(axis)) * box.Half.Y
		end
		if math.abs(Vector3.new(d.X, 0, d.Z):Dot(axis)) >= radius(a) + radius(b) then
			return false
		end
	end
	return true
end

-- Blocks layer (spec Layers 9): street-wall rows of low-rise buildings, a slot every `Spacing` studs along the road
-- on each side, `Rows` deep. A building overlapping one already placed (inside corners) is skipped.
local function blocks(folder, layout, theme, biome, edge, count, onGround, budget, spot)
	local b, wps = theme.Blocks, layout.Waypoints
	local placed = {}
	for _, m in folder:GetChildren() do -- landmarks and horizon pieces keep their ground
		if m:IsA("Model") and (string.match(m.Name, "^Landmark_") or string.match(m.Name, "^Horizon_")) then
			local cf, size = m:GetBoundingBox()
			table.insert(placed, { CFrame = cf, Half = Vector2.new(size.X / 2, size.Z / 2) })
		end
	end
	-- Slots sit exactly `Spacing` studs apart along the road (between waypoints too), so equal-width buildings
	-- never land closer than `Spacing` and the street wall has no waypoint-rounding gaps or overlaps.
	-- Row 1 runs the whole track before row 2, so a tight budget still lines every street
	for row = 1, b.Rows do
		local travelled, nextSlot, slot = 0, 0, 0
		for i = 2, #wps - 1 do
			local len = (Vector3.new(wps[i].X, 0, wps[i].Z) - Vector3.new(wps[i - 1].X, 0, wps[i - 1].Z)).Magnitude
			while len > 0 and nextSlot <= travelled + len do
				local t = (nextSlot - travelled) / len
				slot += 1
				nextSlot += b.Spacing
				for _, side in { -1, 1 } do
					local def = b.Props[math.floor(hash(slot, side, row + 10) * 1000) % #b.Props + 1]
					local distance = edge + b.Near + (row - 1) * b.RowDepth + def.Size.Z / 2
					local base, inTunnel = spot(b, i - 1, side, distance, t, tunnelBox(biome, def))
					local box = base and { CFrame = base, Half = Vector2.new(def.Size.X / 2, def.Size.Z / 2) }
					local clear = base ~= nil
						and count + cost(biome, def, 0) <= budget
						and onGround(base, Vector2.new(def.Size.X, def.Size.Z).Magnitude / 2)
					for _, other in placed do
						if not clear then
							break
						end
						clear = not footprintsOverlap(box, other)
					end
					if clear then
						table.insert(placed, box)
						count += place(
							folder,
							biome,
							def,
							base,
							"Block_" .. slot .. (side < 0 and "L" or "R") .. row,
							false,
							nil,
							inTunnel
						)
					end
				end
			end
			travelled += len
		end
	end
	return count
end

function BiomeDressing.Build(model, layout, spec, origin)
	local biome = spec.Biome
	local theme = type(biome) == "string" and Themes[biome]
	if not theme then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Environment"
	folder.Parent = model
	model:SetAttribute("Biome", biome)
	local ground = model:FindFirstChild("Ground")
	-- A long track's grass is several equal Ground tiles (TrackBuilder); `lo` / `hi` bound them all in the first
	-- tile's space (they share its rotation)
	local lo, hi = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
	for _, tile in model:GetChildren() do
		if tile.Name == "Ground" and tile:IsA("BasePart") then
			tile.Color = theme.Ground.Color
			tile.Material = theme.Ground.Material
			-- Neighbouring tracks' grounds overlap; a per-track step keeps their different colours from z-fighting.
			tile.Position -= Vector3.new(0, GROUND_STEP * (spec.Number or 0), 0)
			local c = ground.CFrame:PointToObjectSpace(tile.Position)
			lo = lo:Min(c - tile.Size / 2)
			hi = hi:Max(c + tile.Size / 2)
		end
	end

	local wps = layout.Waypoints
	local edge = layout.Width / 2 + WALL
	local budget = math.floor(BiomeDressing.BUDGET * math.max(1, (layout.Length or 0) / BiomeDressing.BUDGET_STUDS))
	-- spec 3.5 (fw6): on a Tunnel track every prop stands inside the walls or on a bay platform, except layers with
	-- Surface = true (sparse dressing on the earth over the tunnel: vents, station entrances)
	local tunnel = theme.Tunnel and tunnelSpots(layout, origin, theme.Tunnel, edge)
	-- A prop's base CFrame (nil where it does not fit) and whether it stands inside the tunnel. `size`: its box, X along
	-- the road
	local function spot(layer, i, side, distance, t, size)
		if tunnel and not layer.Surface then
			return tunnel.Spot(i, side, distance, t, size), true
		end
		return beside(layout, origin, i, side, distance, t), false
	end
	-- Track 1 has no biome gate: the plaza torii is its gate (owner 2026-10-30)
	local count = theme.Gate.Skip and 0 or gate(folder, layout, origin, theme, spec, tunnel)
	-- A prop whose footprint leaves this track's ground would hang over the void (or the Baseplate below it).
	-- `reach` is the prop's half-width on the ground (its half-diagonal when it is turned).
	local function onGround(base, reach)
		if not ground then
			return true
		end
		local l = ground.CFrame:PointToObjectSpace(base.Position)
		return l.X - reach >= lo.X and l.X + reach <= hi.X and l.Z - reach >= lo.Z and l.Z + reach <= hi.Z
	end
	-- Hero defs with At are pinned (below); the rest keep cycling by index
	local landmarks, pinned = theme.Landmarks, {}
	for _, def in landmarks.Props do
		if def.At then
			table.insert(pinned, def)
		end
	end
	if #pinned > 0 then
		landmarks = table.clone(landmarks)
		landmarks.Props, landmarks.Landmark = {}, true
		for _, def in theme.Landmarks.Props do
			if not def.At then
				table.insert(landmarks.Props, def)
			end
		end
	end
	local function add(layer, n, i, side, glow, name, fits)
		if #layer.Props == 0 then
			return
		end
		local k = (layer == theme.Landmarks or layer.Landmark) and BiomeDressing.SCALE.Landmarks
			or layer == theme.Horizon and BiomeDressing.SCALE.Horizon
		local raw = layer.Props[n % #layer.Props + 1]
		-- A horizon piece that fits nowhere at its scale shrinks toward x1 (spec Rules, Scale)
		local steps = { k }
		if fits and k then
			for s = k - 0.25, 1, -0.25 do
				table.insert(steps, s)
			end
		end
		for _, s in steps do
			local def = scaled(raw, s)
			local size = footprint(biome, def)
			if count + cost(biome, def, 1) > budget then
				return
			end
			for _, f in fits or { 1 } do
				local offset = fits and math.max(layer.Offset * f, theme.Landmarks.Offset) or layer.Offset
				local base, inTunnel = spot(layer, i, side, edge + offset + size.Z / 2, nil, tunnelBox(biome, def))
				if base and onGround(base, math.max(size.X, size.Z) / 2) then
					count += place(folder, biome, def, base, name, glow, glow and theme.Particles, inTunnel)
					return true
				end
			end
		end
	end
	local function alternate(n)
		return n % 2 == 0 and 1 or -1
	end

	-- Landmarks and horizon first, so the rhythm layer is what the budget trims.
	-- A spiral has a corner every few hundred studs: corners closer than Every / 2 to a placed landmark are skipped,
	-- so landmarks keep their spacing. The horizon piece goes on the inside, the landmark on the outside.
	local every = theme.Landmarks.Every
	local corners, crests = features(layout)
	local spots, n = {}, 0
	for p, def in pinned do
		local i, side = heroSpot(layout, corners, def.At, p)
		local inside = tunnel and not theme.Landmarks.Surface
		if inside then
			-- spec 3.5 (fw6): a pinned hero on a Tunnel track stands in the bay covering its At, on that bay's side
			-- (Both: the side heroSpot gives)
			local bay
			bay, i = tunnel.Bay(def.At)
			if bay then
				side = bay.Side == "Left" and -1 or bay.Side == "Right" and 1 or side
			else
				warn(
					string.format(
						"[BiomeDressing] pinned hero %s (track %s, At %.2f): no tunnel bay covers it",
						def.Name,
						tostring(spec.Number),
						def.At
					)
				)
			end
		end
		local one = table.clone(theme.Landmarks)
		one.Props, one.Landmark = { def }, true
		if not add(one, 0, i, side, true, "Landmark_" .. i) and inside then
			warn(
				string.format(
					"[BiomeDressing] pinned hero %s (track %s, At %.2f) does not fit inside the tunnel: not built",
					def.Name,
					tostring(spec.Number),
					def.At
				)
			)
		end
		table.insert(spots, i)
	end
	for _, c in corners do
		if not near(spots, c.Index, every // 2) then
			add(landmarks, n, c.Index, c.Side, true, "Landmark_" .. c.Index)
			add(theme.Horizon, n, c.Index, -c.Side, false, "Horizon_" .. c.Index, HORIZON_FIT)
			table.insert(spots, c.Index)
			n += 1
		end
	end
	for _, i in crests do
		if not near(spots, i, 6) then
			add(landmarks, n, i, alternate(n), true, "Landmark_" .. i)
			table.insert(spots, i)
			n += 1
		end
	end
	local first = math.min(every, #wps // 2) -- a short straight track still gets one
	for i = first, #wps - first, every do
		if not near(spots, i, every // 2) then
			add(landmarks, n, i, alternate(n), true, "Landmark_" .. i)
			table.insert(spots, i)
			n += 1
		end
	end
	local horizonEvery = math.min(HORIZON_EVERY, #wps // 2)
	for i = horizonEvery, #wps, horizonEvery do
		if not near(spots, i, horizonEvery // 2) then
			local h = i // horizonEvery
			add(theme.Horizon, h, i, alternate(h), false, "Horizon_" .. i, HORIZON_FIT)
		end
	end

	-- Rhythm, blocks and scatter share what is left, so each layer is built along the whole track
	local rhythm, k = theme.Rhythm, 0
	local share = theme.Shares or SHARE
	local rhythmCap = count + math.floor((budget - count) * (theme.Blocks and share.Rhythm or 0.5))
	local perProp = 0
	for _, def in rhythm.Props do
		perProp += cost(biome, def, 0) / #rhythm.Props
	end
	-- Spread the rhythm out (larger step) when its share cannot fill every slot
	local slots = 2 * (#wps - 2) / rhythm.Every
	local step = rhythm.Every * math.max(1, math.ceil(slots * perProp / math.max(1, rhythmCap - count)))
	for i = 2, #wps - 1, step do
		for _, side in { -1, 1 } do
			if count + perProp > rhythmCap then
				break
			end
			add(rhythm, k, i, side, false, "Rhythm_" .. i .. (side < 0 and "L" or "R"))
			k += 1
		end
	end
	if theme.Blocks then
		local cap = count + math.floor((budget - count) * share.Blocks / (1 - share.Rhythm))
		count = blocks(folder, layout, theme, biome, edge, count, onGround, cap, spot)
	end
	if theme.Scatter then
		count = scatter(folder, layout, origin, theme, biome, ground, edge, count, onGround, budget, spot)
	end
end

-- World axis-aligned box of an oriented box: the broad phase only.
local function bounds(cf, size)
	local r, u, b = cf.RightVector * size.X / 2, cf.UpVector * size.Y / 2, cf.LookVector * size.Z / 2
	local e = Vector3.new(
		math.abs(r.X) + math.abs(u.X) + math.abs(b.X),
		math.abs(r.Y) + math.abs(u.Y) + math.abs(b.Y),
		math.abs(r.Z) + math.abs(u.Z) + math.abs(b.Z)
	)
	return cf.Position - e, cf.Position + e
end

-- Oriented box overlap (separating axis test), the same test as the `environment` scenario. Touching is no overlap.
local function overlaps(cfA, halfA, cfB, halfB)
	local a = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local b = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local ha, hb = { halfA.X, halfA.Y, halfA.Z }, { halfB.X, halfB.Y, halfB.Z }
	local t = cfB.Position - cfA.Position
	local function separated(axis)
		if axis.Magnitude < 1e-6 then
			return false
		end
		axis = axis.Unit
		local ra, rb = 0, 0
		for k = 1, 3 do
			ra += math.abs(a[k]:Dot(axis)) * ha[k]
			rb += math.abs(b[k]:Dot(axis)) * hb[k]
		end
		return math.abs(t:Dot(axis)) >= ra + rb
	end
	for k = 1, 3 do
		if separated(a[k]) or separated(b[k]) then
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

local function blockers(trackModels, extra)
	local list = {}
	local function addAll(root)
		if root:IsA("BasePart") then
			table.insert(list, root)
		end
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	end
	for _, model in trackModels do
		for _, name in { "Road", "Walls", "Checkpoint" } do
			local child = model:FindFirstChild(name)
			if child then
				addAll(child)
			end
		end
		local pad = model:FindFirstChild("WinPad", true)
		if pad then
			addAll(pad)
		end
	end
	local columns = #list -- parts after this index are `extra` (the spawn area): blockers at every height
	for _, inst in extra or {} do
		addAll(inst)
	end
	return list, columns
end

local function cells(lo, hi, fn)
	for cx = math.floor(lo.X / GRID), math.floor(hi.X / GRID) do
		for cz = math.floor(lo.Z / GRID), math.floor(hi.Z / GRID) do
			fn(cx .. "," .. cz)
		end
	end
end

-- Broad-phase grid of the blockers, and a test: does `prop`, grown by CLEARANCE, touch any of them?
local function clearance(trackModels, extra)
	local grid = {}
	local list, columns = blockers(trackModels, extra)
	for k, part in list do
		local lo, hi = bounds(part.CFrame, part.Size)
		local box = { lo, hi, part.CFrame, part.Size / 2, k > columns }
		cells(lo, hi, function(key)
			grid[key] = grid[key] or {}
			table.insert(grid[key], box)
		end)
	end
	local grow = Vector3.one * BiomeDressing.CLEARANCE
	return function(prop)
		local hit = false
		-- Each part on its own: a gate's posts and beam are clear even though their joint box spans the road.
		for _, part in prop:IsA("BasePart") and { prop } or prop:GetDescendants() do
			if part:IsA("BasePart") and not hit then
				local half = part.Size / 2 + grow -- grown in the part's own axes
				local lo, hi = bounds(part.CFrame, half * 2)
				cells(lo, hi, function(key)
					for _, box in grid[key] or {} do
						-- a column: test the part as if it stood at the blocker's height (yaw-only parts: a 2D test)
						local cf = box[5] and part.CFrame + Vector3.new(0, box[3].Position.Y - part.Position.Y, 0)
							or part.CFrame
						hit = hit
							or (
								lo.X < box[2].X
								and hi.X > box[1].X
								and (box[5] or lo.Y < box[2].Y and hi.Y > box[1].Y)
								and lo.Z < box[2].Z
								and hi.Z > box[1].Z
								and overlaps(cf, half, box[3], box[4])
							)
					end
				end)
			end
		end
		return hit
	end
end

-- Removes every Environment prop whose box, grown by CLEARANCE, touches a blocker. Returns how many.
-- The spawn area (`extra`) is an area on the ground, so a prop also may not hang over it at any height (a giant
-- tree's canopy above the floor or a workshop plot): its parts block as vertical columns.
function BiomeDressing.Prune(trackModels, extra)
	local touches = clearance(trackModels, extra)
	local removed = 0
	for _, model in trackModels do
		local folder = model:FindFirstChild("Environment")
		for _, prop in folder and folder:GetChildren() or {} do
			if touches(prop) then
				prop:Destroy()
				removed += 1
			end
		end
	end
	return removed
end

-- Drops every Environment prop of every track onto the terrain (placeholder rule): its base goes to the lowest
-- TerrainShape height of 5 samples (centre and 4 footprint corners), but never more than SNAP_SINK below the height at
-- its centre, so a prop on a slope is not buried in the hill (its downhill side may float a little instead).
-- Corridor props (centre at GROUND_Y) stay, and a move that would bring a prop into a road's CLEARANCE (an elevated
-- road above a hill) is undone. Call after TerrainShape.Prepare and Prune.
-- A prop must also fit its own zone (spec 2.2 / 2.3): every one of the 5 samples is nearest to its own track (the
-- gap midline is the seam), or within that track's corridor. A landmark must not overhang a drop: no corner more
-- than SNAP_OVERHANG under its snapped base. A prop that fails slides toward its road in SNAP_SLIDE_STEP steps (up to
-- SNAP_SLIDE_MAX, never within the track's Width / 2 + CLEARANCE of the road, never onto another prop) or is dropped.
-- A hero (spec 3.2) is never dropped below HERO_FLOOR per biome, and a pinned hero (At) is never dropped: it stays put
-- and is warned about instead. Props inside a tunnel (attribute Tunnel, spec 3.5) are left where Build put them.
-- Returns how many props moved, how many were dropped, and heroes dropped per biome ({ [biome] = count }).
function BiomeDressing.SnapToTerrain(trackModels)
	local TerrainShape = require(script.Parent.TerrainShape)
	if not TerrainShape.Ready() then
		return 0, 0, {}
	end
	local touches = clearance(trackModels)
	local moved, dropped = 0, 0
	local heroes, heroDropped = {}, {} -- biome -> heroes left, heroes dropped
	-- Pinned heroes first (spec 3.2): each is raised onto a pad levelled to the natural height at its centre, before
	-- any other prop samples the ground near it
	local pinned = {} -- their footprints grown by CLEARANCE, kept clear of every other prop
	local padded = {} -- padded props' pads (footprint grown by PAD_MARGIN): no later pad may overlap one
	for _, model in trackModels do
		local folder = model:FindFirstChild("Environment")
		for _, prop in folder and folder:GetChildren() or {} do
			if prop:IsA("Model") and prop:GetAttribute("Pinned") and not prop:GetAttribute("Tunnel") then
				local cf, size = prop:GetBoundingBox()
				local pivot = prop:GetPivot()
				-- spec 3.2: a footprint that reaches a corridor is pushed outward, away from its road, until it is clear
				if TerrainShape.CorridorLow(cf, size) then
					local n = model:GetAttribute("Number")
					local function dist(px, pz)
						return select(2, TerrainShape.Owner(px, pz, n))
					end
					local x, z = cf.Position.X, cf.Position.Z
					local g = Vector3.new(dist(x + 4, z) - dist(x - 4, z), 0, dist(x, z + 4) - dist(x, z - 4))
					if g.Magnitude > 1e-3 and g.Magnitude < math.huge then
						for step = SNAP_SLIDE_STEP, SNAP_SLIDE_MAX, SNAP_SLIDE_STEP do
							local shift = g.Unit * step
							if not TerrainShape.CorridorLow(cf + shift, size) then
								cf, pivot = cf + shift, pivot + shift
								break
							end
						end
					end
				end
				local y = TerrainShape.Height(cf.Position.X, cf.Position.Z)
				prop:PivotTo(pivot + Vector3.new(0, y - GROUND_Y, 0))
				if touches(prop) then -- raised into a road's clearance: keep it and its pad at the base
					prop:PivotTo(pivot)
					y = GROUND_Y
					warn(
						string.format("[BiomeDressing] pinned hero %s would touch a road: left at its base", prop.Name)
					)
				end
				if TerrainShape.AddPad(cf, size, y) then
					warn(
						string.format(
							"[BiomeDressing] pinned hero %s (track %s) reaches into a road corridor: that part is not levelled",
							prop.Name,
							tostring(model:GetAttribute("Number"))
						)
					)
				end
				if prop:GetAttribute("BasePivot") then
					prop:SetAttribute("BasePivot", prop:GetPivot())
				end
				local grow = Vector2.one * BiomeDressing.CLEARANCE
				table.insert(pinned, { CFrame = cf, Half = Vector2.new(size.X / 2, size.Z / 2) + grow })
			end
		end
	end
	for _, model in trackModels do
		local folder = model:FindFirstChild("Environment")
		local biome = model:GetAttribute("Biome")
		for _, prop in folder and biome and folder:GetChildren() or {} do
			if prop:GetAttribute("Hero") then
				heroes[biome] = (heroes[biome] or 0) + 1
			end
		end
	end
	local CORNERS = { { 0, 0 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }
	-- Two passes: padded props (houses, spec 3.2) first, so every other prop snaps onto ground that already has
	-- their pads
	for _, padPass in { true, false } do
		for _, model in trackModels do
			local folder = model:FindFirstChild("Environment")
			local trackN = model:GetAttribute("Number")
			local roadHalf = (model:GetAttribute("Width") or 0) / 2
			local biome = model:GetAttribute("Biome")
			local n -- this prop's track: the model's Number, else the nearest track at the prop's centre
			local boxes = nil -- other props' footprints, built on the first slide in this folder
			-- Ground height change dy for the prop's box (cf, size) moved by `shift`, or nil when it leaves its zone or
			-- (a landmark) overhangs a drop; also the centre height
			local function fit(prop, cf, size, shift)
				local box = { CFrame = cf + shift, Half = Vector2.new(size.X / 2, size.Z / 2) }
				for _, pin in pinned do
					if footprintsOverlap(box, pin) then
						return nil -- off every pinned hero's pad, whatever its track
					end
				end
				if prop:GetAttribute("Pad") then
					local grown = { CFrame = box.CFrame, Half = box.Half + Vector2.one * PAD_MARGIN }
					for _, pad in padded do
						if footprintsOverlap(grown, pad) then
							return nil -- two pads at different heights cannot both be flat where they meet
						end
					end
				end
				local centre, low = nil, math.huge
				for _, c in CORNERS do
					local p = cf:PointToWorldSpace(Vector3.new(c[1] * size.X / 2, 0, c[2] * size.Z / 2)) + shift
					if n then
						local owner, d = TerrainShape.Owner(p.X, p.Z, n)
						if owner ~= n and d > TerrainShape.CORRIDOR then
							return nil
						end
					end
					local h = TerrainShape.Height(p.X, p.Z)
					centre = centre or h
					low = math.min(low, h)
				end
				local base = math.max(low, centre - SNAP_SINK)
				if low < base - SNAP_OVERHANG and string.match(prop.Name, "^Landmark_") then
					return nil
				end
				if prop:GetAttribute("Pad") then
					-- a padded prop sits on its own pad at the centre height, or at the lowest corridor ground under
					-- its pad (footprint plus PAD_MARGIN) when that reaches a corridor (pads never change corridor
					-- ground, spec 3.2)
					base = TerrainShape.CorridorLow(cf + shift, size + Vector3.new(2, 0, 2) * PAD_MARGIN) or centre
				end
				return base - GROUND_Y, centre
			end
			-- Levels a padded prop's pad at its base height y under its box (spec 3.2), moved or not
			local function padOn(prop, cf, size, y)
				if prop:GetAttribute("Pad") then
					TerrainShape.AddPad(cf, size, y, PAD_MARGIN)
					local grow = Vector2.one * PAD_MARGIN
					table.insert(padded, { CFrame = cf, Half = Vector2.new(size.X / 2, size.Z / 2) + grow })
				end
			end
			local function onProp(prop, cf, size)
				if not boxes then
					boxes = {}
					for _, other in folder:GetChildren() do
						if
							other:IsA("Model")
							and not string.match(other.Name, "^Patch_")
							and not other:GetAttribute("Tunnel")
						then
							local ocf, osize = other:GetBoundingBox()
							boxes[other] = { CFrame = ocf, Half = Vector2.new(osize.X / 2, osize.Z / 2) }
						end
					end
				end
				local box = { CFrame = cf, Half = Vector2.new(size.X / 2, size.Z / 2) }
				for other, b in boxes do
					if other ~= prop and other.Parent and footprintsOverlap(box, b) then
						return true
					end
				end
				return false
			end
			for _, prop in folder and folder:GetChildren() or {} do
				-- pinned heroes are already on their pads (above); tunnel props stay on the tunnel floor (spec 3.5)
				if
					prop:IsA("Model")
					and not prop:GetAttribute("Pinned")
					and not prop:GetAttribute("Tunnel")
					and (prop:GetAttribute("Pad") == true) == padPass
				then
					local cf, size = prop:GetBoundingBox()
					n = trackN or (TerrainShape.Owner(cf.Position.X, cf.Position.Z, nil))
					local x, z = cf.Position.X, cf.Position.Z
					local function dist(px, pz)
						return n and select(2, TerrainShape.Owner(px, pz, n)) or math.huge
					end
					-- toward the road: down the gradient of this track's distance
					local g = Vector3.new(dist(x - 4, z) - dist(x + 4, z), 0, dist(x, z - 4) - dist(x, z + 4))
					-- spec 3.2 (fw4): a padded prop outside the corridor but within PAD_MARGIN of it is pushed outward
					-- until its pad clears the corridor, so the drawn voxel step down to the corridor stays off its
					-- footprint; with no clear spot it sits at the corridor seat (fit)
					local push = Vector3.zero
					local grown = size + Vector3.new(2, 0, 2) * PAD_MARGIN
					if
						prop:GetAttribute("Pad")
						and g.Magnitude > 1e-3
						and g.Magnitude < math.huge
						and not TerrainShape.CorridorLow(cf, size)
						and TerrainShape.CorridorLow(cf, grown)
					then
						for step = SNAP_SLIDE_STEP, SNAP_SLIDE_MAX, SNAP_SLIDE_STEP do
							local shift = -g.Unit * step
							if
								not TerrainShape.CorridorLow(cf + shift, grown)
								and fit(prop, cf, size, shift)
								and not onProp(prop, cf + shift, size)
							then
								push = shift
								break
							end
						end
					end
					local dy, centre = fit(prop, cf, size, push)
					if dy then
						local lift = 0
						if push ~= Vector3.zero or (math.abs(centre - GROUND_Y) > 0.05 and math.abs(dy) > 0.05) then
							local pivot = prop:GetPivot()
							prop:PivotTo(pivot + push + Vector3.new(0, dy, 0))
							if touches(prop) then
								prop:PivotTo(pivot)
								push = Vector3.zero
							else
								lift = dy
								moved += 1
								if boxes and boxes[prop] then
									boxes[prop].CFrame = cf + push
								end
							end
						end
						padOn(prop, cf + push, size, GROUND_Y + lift)
					else
						-- slide toward the road
						local reach = Vector2.new(size.X, size.Z).Magnitude / 2
						local pivot, done = prop:GetPivot(), false
						if g.Magnitude > 1e-3 and g.Magnitude < math.huge then
							local dir = g.Unit
							for step = SNAP_SLIDE_STEP, SNAP_SLIDE_MAX, SNAP_SLIDE_STEP do
								local shift = dir * step
								local p = cf.Position + shift
								local sdy, scentre = fit(prop, cf, size, shift)
								if
									sdy
									and dist(p.X, p.Z) - reach >= roadHalf + BiomeDressing.CLEARANCE
									and not onProp(prop, cf + shift, size)
								then
									local lift = math.abs(scentre - GROUND_Y) > 0.05 and sdy or 0
									prop:PivotTo(pivot + shift + Vector3.new(0, lift, 0))
									if touches(prop) then
										prop:PivotTo(pivot)
									else
										if boxes[prop] then
											boxes[prop].CFrame = cf + shift
										end
										padOn(prop, cf + shift, size, GROUND_Y + lift)
										moved += 1
										done = true
										break
									end
								end
							end
						end
						if
							not done
							and prop:GetAttribute("Hero")
							and (prop:GetAttribute("Pinned") or (heroes[biome] or 0) <= HERO_FLOOR)
						then
							warn(
								string.format(
									"[BiomeDressing] hero %s (biome %s, track %s) does not fit its zone: left in place",
									prop.Name,
									tostring(biome),
									tostring(trackN)
								)
							)
						elseif not done then
							if prop:GetAttribute("Hero") then
								heroes[biome] -= 1
								heroDropped[biome] = (heroDropped[biome] or 0) + 1
							end
							prop:Destroy()
							dropped += 1
						end
					end
					if prop.Parent and prop:GetAttribute("BasePivot") then
						prop:SetAttribute("BasePivot", prop:GetPivot())
					end
				end
			end
		end
	end
	return moved, dropped, heroDropped
end

return BiomeDressing
