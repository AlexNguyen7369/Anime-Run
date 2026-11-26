--!nonstrict
-- World 2 track effects and motion: DRAFT, owner approval pending (docs/WORLD2_SPEC.md "Track effects (draft, owner
-- approval pending)", data in Shared/TrackFxConfig, math in Shared/TrackFxPlan). Client only: every instance it makes
-- is local, and every prop it moves is moved locally (the server's CFrame is restored when it lets go).
-- Start() does nothing unless TrackFxConfig.Enabled(WorldConfig.Id): LIVE false (the default) or World 1 builds nothing.
-- Only the track the camera is in runs (Shared/BiomeEnvironment.ZoneAt at the camera focus); a zone change tears the old
-- track down. REDUCED EFFECTS (player attribute ReduceEffects, BIOME_ENVIRONMENT_SPEC 8) turns all of it off.
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.TrackFxConfig)
local Plan = require(Shared.TrackFxPlan)

local TrackFx = {}

local EFFECT_TAG = "BiomeEffect" -- BiomeDressing.EFFECT_TAG: the draft lamps' PointLights carry it

local function textureId(key)
	local row = Config.Assets[key]
	return row and row.Id or nil
end

local function sequence(keys)
	local list = {}
	for _, k in keys do
		table.insert(list, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	return NumberSequence.new(list)
end

local function holderPart(name, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	return part
end

-- One emitter on a holder part sized to the preset's Area, so Box emission spreads it
local function makeEmitter(preset, row, cf, name, area)
	local texture = textureId(preset.Texture)
	if not texture then
		return nil -- not uploaded yet: the effect is not built
	end
	local part = holderPart(name, area or preset.Area)
	part.CFrame = cf
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Rate = math.min(preset.Rate, Config.Budget.MaxRate)
	e.Lifetime = NumberRange.new(preset.Lifetime[1], preset.Lifetime[2])
	e.Speed = NumberRange.new(preset.Speed[1], preset.Speed[2])
	e.Acceleration = preset.Acceleration
	e.SpreadAngle = Vector2.new(preset.SpreadAngle, preset.SpreadAngle)
	e.Drag = preset.Drag
	e.EmissionDirection = Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Size = sequence(preset.Size)
	e.Transparency = sequence(preset.Transparency)
	if preset.Squash then
		e.Squash = sequence(preset.Squash)
	end
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(preset.RotSpeed[1], preset.RotSpeed[2])
	e.LightInfluence = preset.LightInfluence
	e.LightEmission = preset.LightEmission
	e.Color = ColorSequence.new(row.Color[1], row.Color[2])
	if preset.Flipbook then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	e.Parent = part
	return part
end

-- Track state ------------------------------------------------------------------------------------------------------

local state = nil -- { Number, Spec, Model, Origin, Waypoints, Theme, Folder, Emitters, Moving, Lights, Dragons, Conns }

local function folderFor()
	local folder = workspace:FindFirstChild("TrackFxClient")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TrackFxClient"
		folder.Parent = workspace
	end
	return folder
end

-- The props of the track's Environment folder with each one's key and box (main part: mesh, MeshBounds, or the model)
local function propsOf(model)
	local env = model:FindFirstChild("Environment")
	local list = {}
	if not env then
		return list
	end
	for _, m in env:GetChildren() do
		if m:IsA("Model") and string.match(m.Name, "^Placed_") then
			local key = Plan.PropName(m)
			if key then
				local main = m:FindFirstChild(key) or m:FindFirstChild("MeshBounds")
				local cf, size
				if main and main:IsA("BasePart") then
					cf, size = main.CFrame, main.Size
				else
					cf, size = m:GetBoundingBox()
				end
				table.insert(list, { Model = m, Key = key, CFrame = cf, Size = size })
			end
		end
	end
	return list
end

-- Smoke: nearest-first anchors under the budget, rebuilt only where the pick changed
local function refreshSmoke(props, camera)
	local candidates, info = {}, {}
	for r, row in state.Theme.Smoke or {} do
		local preset = Config.Presets[row.Preset]
		local mine = {}
		if row.Prop then
			for _, p in props do
				if p.Key == row.Prop then
					table.insert(
						mine,
						{ p.Model, Plan.BoxPoint(p.CFrame, p.Size, row.Offset), Plan.Area(preset, row, p.Size) }
					)
				end
			end
		elseif row.At then
			table.insert(mine, { "At", state.Origin * Plan.TrackPoint(state.Waypoints, row) })
		end
		-- a row keeps at most Max anchors: its nearest ones
		table.sort(mine, function(a, b)
			return (a[2].Position - camera).Magnitude < (b[2].Position - camera).Magnitude
		end)
		for i = 1, math.min(row.Max, #mine) do
			local key = tostring(r) .. "|" .. tostring(mine[i][1])
			table.insert(candidates, {
				Key = key,
				Position = mine[i][2].Position,
				Cost = Plan.Cost(preset),
				Cull = Plan.Cull(preset),
			})
			-- upright, turned with the prop about Y only, so Top emission always rises
			local _, yaw = mine[i][2]:ToEulerAnglesYXZ()
			info[key] = { preset, row, CFrame.new(mine[i][2].Position) * CFrame.Angles(0, yaw, 0), mine[i][3] }
		end
	end
	local kept = Plan.Pick(candidates, camera, Config.Budget.MaxEmittersPerTrack, Config.Budget.MaxParticlesPerTrack)
	for key, part in state.Emitters do
		if not kept[key] then
			part:Destroy()
			state.Emitters[key] = nil
		end
	end
	for key in kept do
		if not state.Emitters[key] then
			local i = info[key]
			local part = makeEmitter(i[1], i[2], i[3], "Fx_" .. i[2].Preset, i[4])
			if part then
				part.Parent = state.Folder
				state.Emitters[key] = part
			end
		end
	end
end

-- Motion: record every BasePart's CFrame relative to the prop's base pivot when it is picked; restore when dropped
local function release(entry)
	for part, cf in entry.Parts do
		if part.Parent then
			part.CFrame = cf
		end
	end
end

local function refreshMotion(props, camera)
	local picks = {}
	for _, row in state.Theme.Motion or {} do
		local mine = {}
		for _, p in props do
			local d = (p.CFrame.Position - camera).Magnitude
			if p.Key == row.Prop and d <= Config.Budget.MotionDistance then
				table.insert(mine, { p, d })
			end
		end
		table.sort(mine, function(a, b)
			return a[2] < b[2]
		end)
		for i = 1, math.min(row.Max, #mine) do
			table.insert(picks, { mine[i][1], mine[i][2], row })
		end
	end
	table.sort(picks, function(a, b)
		return a[2] < b[2]
	end)
	local want = {}
	for i = 1, math.min(#picks, Config.Budget.MaxMovingProps) do
		want[picks[i][1].Model] = picks[i]
	end
	for model, entry in state.Moving do
		if not want[model] or not model.Parent then
			release(entry)
			state.Moving[model] = nil
		end
	end
	for model, pick in want do
		if not state.Moving[model] then
			local p = pick[1]
			-- pivot at the base centre of the prop's box
			local base = p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0)
			local parts, rel = {}, {}
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					parts[d] = d.CFrame
					rel[d] = base:ToObjectSpace(d.CFrame)
				end
			end
			state.Moving[model] = {
				Row = pick[3],
				Base = base,
				Parts = parts,
				Rel = rel,
				Phase = (#model.Name * 0.137 + base.Position.X * 0.013) % 1,
			}
		end
	end
end

local function refreshLights(camera)
	local flicker = state.Theme.Flicker
	if not flicker then
		return
	end
	local env = state.Model:FindFirstChild("Environment")
	local list = {}
	for _, light in CollectionService:GetTagged(EFFECT_TAG) do
		if
			light:IsA("PointLight")
			and light.Parent
			and string.match(light.Parent.Name, "^Lamp_")
			and env
			and light:IsDescendantOf(env)
		then
			local d = (light.Parent.Position - camera).Magnitude
			if d <= Config.Budget.FlickerDistance then
				table.insert(list, { light, d })
			end
		end
	end
	table.sort(list, function(a, b)
		return a[2] < b[2]
	end)
	local want = {}
	for i = 1, math.min(#list, Config.Budget.MaxFlickerLights) do
		want[list[i][1]] = true
	end
	for light in state.Lights do
		if not want[light] then
			light.Brightness = light:GetAttribute("Brightness") or light.Brightness
			state.Lights[light] = nil
		end
	end
	for light in want do
		if not state.Lights[light] then
			state.Lights[light] = (tonumber(string.match(light.Parent.Name, "%d+")) or 1) * 0.618
		end
	end
end

-- Dragons ----------------------------------------------------------------------------------------------------------

local meshCache = {}
local function mesh(key, size)
	local id = Config.Assets[key] and Config.Assets[key].Id
	if not id then
		return nil
	end
	if meshCache[key] == nil then
		local ok, part = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(id), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
			})
		end)
		meshCache[key] = ok and part or false
	end
	local template = meshCache[key]
	if not template then
		return nil
	end
	local part = template:Clone()
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function buildDragon(def)
	local model = Instance.new("Model")
	model.Name = "Fx_" .. def.Kind
	local parts = {}
	if def.Kind == "Drake" then
		local D = Config.Drake
		local body, left, right =
			mesh("TrackFx_DrakeBody", D.BodySize),
			mesh("TrackFx_DrakeWing", D.WingSize),
			mesh("TrackFx_DrakeWing", D.WingSize)
		if not (body and left and right) then
			return nil
		end
		parts = { Body = body, Left = left, Right = right }
	else
		local E = Config.Eel
		local head = mesh("TrackFx_EelHead", E.HeadSize)
		if not head then
			return nil
		end
		parts = { Head = head, Segments = {} }
		for i = 1, E.Segments do
			local seg = mesh("TrackFx_EelSegment", E.SegmentSize * (1 - 0.45 * i / E.Segments))
			if not seg then
				return nil
			end
			seg.Transparency = E.Transparency
			seg.Parent = model
			parts.Segments[i] = seg
		end
		head.Transparency = E.Transparency
	end
	for name, p in parts do
		if typeof(p) == "Instance" then
			p.Name = name
			p.Color = def.Color
			p.Parent = model
		end
	end
	for _, seg in parts.Segments or {} do
		seg.Color = def.Color
	end
	local path = Plan.DragonPath(state.Waypoints, def)
	for i, p in path do
		path[i] = state.Origin:PointToWorldSpace(p)
	end
	model.Parent = state.Folder
	return { Def = def, Model = model, Parts = parts, Path = path }
end

local function pathFrame(path, u)
	local pos, tan = Plan.Spline(path, u)
	return CFrame.lookAt(pos, pos + tan), tan
end

local function updateDragon(d, t, camera)
	local def = d.Def
	local u = (t / def.Period + (def.Phase or 0)) % 1
	local cf, tan = pathFrame(d.Path, u)
	local far = (cf.Position - camera).Magnitude > Config.Budget.DragonCull
	local parent = if far then nil else state.Folder
	if d.Model.Parent ~= parent then
		d.Model.Parent = parent
	end
	if far then
		return
	end
	if def.Kind == "Drake" then
		local D = Config.Drake
		local _, ahead = pathFrame(d.Path, u + 0.01)
		local turn = tan:Cross(ahead).Y -- sign of the turn: bank into it
		local beat = (t / D.FlapPeriod) % 1
		local gliding = ((t / def.Period + (def.Phase or 0)) * 3) % 1 < D.GlideShare
		local flap = gliding and 0.15 or math.sin(beat * math.pi * 2)
		local body = cf
			* CFrame.new(0, -flap * D.Bob, 0)
			* CFrame.Angles(0, 0, math.clamp(turn * 40, -1, 1) * math.rad(D.Bank))
		d.Parts.Body.CFrame = body
		local angle = math.rad(D.FlapAngle) * flap
		local half = D.WingSize.X / 2
		local hl = D.WingHinge
		d.Parts.Left.CFrame = body
			* CFrame.new(-hl.X, hl.Y, hl.Z)
			* CFrame.Angles(0, 0, -angle)
			* CFrame.new(-half, 0, 0)
		d.Parts.Right.CFrame = body
			* CFrame.new(hl.X, hl.Y, hl.Z)
			* CFrame.Angles(0, 0, angle)
			* CFrame.new(half, 0, 0)
			* CFrame.Angles(0, 0, math.pi) -- the same wing mesh turned about the long axis
	else
		local E = Config.Eel
		local lapLength = 0
		for i = 1, #d.Path do
			lapLength += (d.Path[i % #d.Path + 1] - d.Path[i]).Magnitude
		end
		d.Parts.Head.CFrame = cf
		for i, seg in d.Parts.Segments do
			local back = u - i * E.Spacing / lapLength
			local scf = pathFrame(d.Path, back)
			local wave = math.sin(t / E.WavePeriod * math.pi * 2 - i / E.WaveLength * math.pi * 2)
				* E.Wave
				* (i / E.Segments)
			seg.CFrame = scf * CFrame.new(wave, 0, 0)
		end
	end
end

-- Lifecycle --------------------------------------------------------------------------------------------------------

local function teardown(reduced)
	if not state then
		return
	end
	for _, part in state.Emitters do
		part:Destroy()
	end
	for _, entry in state.Moving do
		release(entry)
	end
	for light in state.Lights do
		-- under REDUCED EFFECTS Client/BiomeEnvironment owns the lamp's brightness; never write over its dimmed value
		if light.Parent and not reduced then
			light.Brightness = light:GetAttribute("Brightness") or light.Brightness
		end
	end
	for _, d in state.Dragons do
		d.Model:Destroy()
	end
	state.Folder:Destroy()
	state = nil
end

local function setup(number, chain)
	local spec = chain[number]
	local theme = spec and Config.Tracks[spec.Biome]
	if not theme then
		return
	end
	local trackFolder = workspace:FindFirstChild("Track")
	local model = trackFolder and trackFolder:FindFirstChild(spec.Name)
	local start = model and model:FindFirstChild("Start")
	if not start then
		return -- not built or not streamed in yet: the next poll tries again
	end
	local TrackBuilder = require(Shared.TrackBuilder)
	local folder = Instance.new("Folder")
	folder.Name = spec.Name
	folder.Parent = folderFor()
	state = {
		Number = number,
		Spec = spec,
		Model = model,
		Origin = start.CFrame * CFrame.new(0, -0.5, 0), -- TrackBuilder: Start sits 0.5 above the origin
		Waypoints = TrackBuilder.Layout(spec).Waypoints,
		Theme = theme,
		Folder = folder,
		Emitters = {},
		Moving = {},
		Lights = {},
		Dragons = {},
	}
	for i, def in theme.Dragons or {} do
		if i > Config.Budget.MaxDragonsPerTrack then
			break
		end
		local d = buildDragon(def)
		if d then
			table.insert(state.Dragons, d)
		end
	end
end

function TrackFx.Start()
	local WorldConfig = require(Shared.WorldConfig)
	if not Config.Enabled(WorldConfig.Id) then
		return false
	end
	local Env = require(Shared.BiomeEnvironment)
	local TrackRegistry = require(Shared.TrackRegistry)
	local chain = {}
	for _, spec in TrackRegistry.Chain() do
		chain[spec.Number] = spec
	end
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera

	local lastScan, lastMotion = -math.huge, -math.huge
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local focus = camera.Focus.Position
		local reduced = player:GetAttribute("ReduceEffects") == true
		if now - lastScan >= Config.Budget.RescanSeconds then
			lastScan = now
			local zone = (not reduced) and Env.ZoneAt(focus) or nil
			if state and state.Number ~= zone then
				teardown(reduced)
			end
			if not state and zone and zone > 0 then
				setup(zone, chain)
			end
			if state then
				local props = propsOf(state.Model)
				refreshSmoke(props, camera.CFrame.Position)
				refreshMotion(props, camera.CFrame.Position)
				refreshLights(camera.CFrame.Position)
			end
		end
		if not state then
			return
		end
		local t = workspace:GetServerTimeNow() -- every client sees a dragon at the same spot
		for _, d in state.Dragons do
			updateDragon(d, t, camera.CFrame.Position)
		end
		if now - lastMotion >= 1 / Config.Budget.MotionHz then
			lastMotion = now
			for _, entry in state.Moving do
				local pivot = entry.Base * Plan.Motion(entry.Row, t, entry.Phase)
				for part, rel in entry.Rel do
					if part.Parent then
						part.CFrame = pivot * rel
					end
				end
			end
			for light, seed in state.Lights do
				if light.Parent then
					local base = light:GetAttribute("Brightness") or 1.5
					light.Brightness = base * Plan.Flicker(state.Theme.Flicker, t, seed)
				end
			end
		end
	end)
	return true
end

return TrackFx
