--!nonstrict
-- Per-zone sky, light, water, particles and ambient audio, client-local only (docs/BIOME_ENVIRONMENT_SPEC.md 5, 6, 8).
-- The zone comes from Shared/BiomeEnvironment.ZoneAt at the camera focus. Every property lerps from its current
-- value to the zone's profile over BLEND_SECONDS (sine ease); swaps (sky textures, reverb, particles) happen at the
-- blend midpoint under a haze peak. Values the profile leaves out stay at the server's replicated value, and a
-- server write (only WeatherService writes these) is kept as that value and re-applied over. REDUCED EFFECTS
-- (player attribute ReduceEffects) drops particles, one-shots, per-zone post-FX, shadows and far landmark detail,
-- and halves the tunnel lights (spec 3.5). An Underground profile has no sky and no weather mix.
-- Client/BiomeAmbience (prop motion) and Client/BiomeMeshes (Lane C meshes) write no Lighting.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Env = require(Shared.BiomeEnvironment)
local WeatherConfig = require(Shared.WeatherConfig)

local player = Players.LocalPlayer
local terrain = Workspace.Terrain
local BLEND = Env.BLEND_SECONDS

local function reduced()
	return player:GetAttribute("ReduceEffects") == true
end

local function weatherActive()
	local spec = WeatherConfig.Events[ReplicatedStorage:GetAttribute("WeatherEvent") or ""]
	return spec ~= nil and spec.Sky ~= nil
end

-- Managed properties: { Group, Key (profile key), Prop, Find, Mix (weather mix), Reduce (baseline when reduced) }
local function atmosphere()
	return Lighting:FindFirstChildOfClass("Atmosphere")
end
local function named(name, class)
	return function()
		local inst = Lighting:FindFirstChild(name)
		return inst and inst:IsA(class) and inst or nil
	end
end
local function sky()
	return Lighting:FindFirstChildOfClass("Sky")
end
local function clouds()
	return terrain:FindFirstChildOfClass("Clouds")
end
local function lighting()
	return Lighting
end
local function getTerrain()
	return terrain
end

local entries = {}
local function manage(group, find, keys, opts)
	for key, prop in keys do
		if type(key) == "number" then
			key = prop
		end
		table.insert(entries, {
			Group = group,
			Key = key,
			Prop = prop,
			Find = find,
			Mix = opts and opts.Mix and opts.Mix[key] or false,
			Reduce = opts and opts.Reduce or false,
		})
	end
end
manage("Lighting", lighting, {
	"ClockTime",
	"Brightness",
	"Ambient",
	"OutdoorAmbient",
	"ExposureCompensation",
	"ColorShift_Top",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
}, { Mix = { ClockTime = true, Brightness = true, OutdoorAmbient = true } })
manage(
	"Atmosphere",
	atmosphere,
	{ "Density", "Offset", "Color", "Decay", "Glare", "Haze" },
	{ Mix = { Density = true, Color = true, Haze = true } } -- the Atmosphere properties weather writes
)
manage("Grade", named("Grade", "ColorCorrectionEffect"), { "Brightness", "Contrast", "Saturation", "TintColor" }, {
	Reduce = true,
})
manage("Bloom", named("Bloom", "BloomEffect"), { "Intensity", "Size", "Threshold" }, { Reduce = true })
manage("SunRays", named("SunRays", "SunRaysEffect"), { "Intensity", "Spread" }, { Reduce = true })
manage("Clouds", clouds, { "Cover", "Density", "Color" }, { Mix = { Cover = true, Density = true, Color = true } })
manage("Water", getTerrain, {
	Color = "WaterColor",
	Transparency = "WaterTransparency",
	Reflectance = "WaterReflectance",
	WaveSize = "WaterWaveSize",
	WaveSpeed = "WaterWaveSpeed",
})
manage("Sky", sky, {
	"SunAngularSize",
	"MoonAngularSize",
	"StarCount",
	"CelestialBodiesShown",
	"SunTextureId",
	"MoonTextureId",
})
local FACES = { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }
for _, face in FACES do
	manage("Skybox", sky, { [face] = "Skybox" .. face })
end
manage("Shadows", lighting, { "GlobalShadows" })
local reverbEntry = {
	Group = "Reverb",
	Prop = "AmbientReverb",
	Find = function()
		return SoundService
	end,
}
table.insert(entries, reverbEntry)

-- Underground profiles (Atmosphere.Underground = true, spec 3.5): no sky, no sun, no clouds, so only the tunnel lights
-- and Ambient light the scene. These win over the profile; its Ambient, OutdoorAmbient and Environment scales stay.
local UNDERGROUND = {
	Lighting = { ClockTime = 0, Brightness = 0 },
	Sky = { StarCount = 0, CelestialBodiesShown = false },
	Clouds = { Cover = 0 },
}

local zone, profile, audio = nil, Env.Profile(0), {}
local blendStart = -math.huge
local dirty = false

local function same(a, b)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 1e-3
	elseif typeof(a) == "Color3" and typeof(b) == "Color3" then
		return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 3e-3
	end
	return a == b
end

local function lerp(a, b, t)
	if type(a) == "number" and type(b) == "number" then
		return a + (b - a) * t
	elseif typeof(a) == "Color3" and typeof(b) == "Color3" then
		return a:Lerp(b, t)
	end
	return t >= 0.5 and b or a
end

-- Binds an entry to its instance once it exists: its server value and a listener for server writes
local function bind(e)
	if e.Inst and e.Inst.Parent then
		return e.Inst
	end
	local inst = e.Find()
	if not inst then
		return nil
	end
	e.Inst = inst
	e.Server = inst[e.Prop]
	e.Current = e.Server
	e.From = e.Server
	inst:GetPropertyChangedSignal(e.Prop):Connect(function()
		if not same(inst[e.Prop], e.Written) then
			e.Server = inst[e.Prop] -- a server write (weather): keep it and re-apply over it next frame
			e.Current = e.Server
			dirty = true
		end
	end)
	return inst
end

local function skyboxFace(face)
	local key = profile.Sky and profile.Sky.Skybox
	local row = Env.Asset(zone, key, "Skybox")
	if not row then
		return nil
	end
	return row.Faces and row.Faces[face] or row.Id
end

-- The value an entry blends to in the current zone
local function target(e)
	local v
	if e.Group == "Reverb" then
		local name = audio.Reverb
		v = type(name) == "string" and Enum.ReverbType[name] or nil
	elseif e.Group == "Shadows" then
		v = reduced() and false or nil
	elseif e.Group == "Sky" and (e.Key == "SunTextureId" or e.Key == "MoonTextureId") then
		local row = Env.Asset(zone, profile.Sky and profile.Sky[e.Key], "Texture") -- an AssetKey, never a raw id
		v = row and row.Id
	elseif e.Group == "Skybox" then
		v = skyboxFace(e.Key)
	elseif profile.Underground and UNDERGROUND[e.Group] and UNDERGROUND[e.Group][e.Key] ~= nil then
		v = UNDERGROUND[e.Group][e.Key]
	elseif not (e.Reduce and reduced()) then
		local group = profile[e.Group]
		v = group and group[e.Key]
	end
	if v == nil then
		return e.Server
	elseif e.Mix and weatherActive() and not profile.Underground then -- no weather underground (spec 3.5)
		return lerp(v, e.Server, Env.WEATHER_MIX)
	end
	return v
end

local function write(e, value)
	if not same(e.Current, value) then
		e.Current = value
		e.Written = value
		e.Inst[e.Prop] = value
	end
end

-- Particles: one client-only box ahead of the camera with up to PARTICLE_EMITTERS emitters (spec 5.2)
local box = Instance.new("Part")
box.Name = "BiomeParticles"
box.Anchored = true
box.CanCollide = false
box.CanQuery = false
box.CanTouch = false
box.Transparency = 1
box.Parent = Workspace.CurrentCamera or Workspace
local emitters = {}
for i = 1, Env.PARTICLE_EMITTERS do
	local e = Instance.new("ParticleEmitter")
	e.Name = "Zone" .. i
	e.Enabled = false
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = box
	emitters[i] = { Emitter = e, Rate = 0 }
end

local function texture(key)
	if type(key) ~= "string" then
		return nil
	end
	if string.match(key, "^rbxasset://") then -- engine built-ins only; uploaded ids come from the ledger
		return key
	end
	local row = Env.Asset(zone, key, "Texture")
	return row and row.Id
end

local function configureParticles()
	local list = profile.Particles or {}
	for i, slot in emitters do
		local cfg = list[i]
		local tex = cfg and texture(cfg.Texture)
		slot.Rate = tex and math.min(cfg.Rate or 10, Env.PARTICLE_MAX_RATE) or 0
		if tex then
			local e = slot.Emitter
			e.Texture = tex
			e.Color = typeof(cfg.Color) == "ColorSequence" and cfg.Color
				or ColorSequence.new(cfg.Color or Color3.new(1, 1, 1))
			e.Size = NumberSequence.new(cfg.Size or 0.5)
			e.Lifetime = NumberRange.new(cfg.Lifetime or 4)
			e.Speed = NumberRange.new(cfg.Speed or 1)
			e.SpreadAngle = Vector2.new(cfg.SpreadAngle or 180, cfg.SpreadAngle or 180)
			e.LightEmission = cfg.LightEmission or 0
		end
		if i == 1 then
			box.Size = cfg and cfg.Area or Vector3.new(60, 30, 60)
		end
	end
end

-- Audio: SoundGroup "Ambience" (Volume 1) with two sub-groups A / B that crossfade; the Sounds keep Volume 1 so the
-- Settings SOUND toggle (RacerUiController, Sound.Volume) still mutes them
local ambience = SoundService:FindFirstChild("Ambience") or Instance.new("SoundGroup")
ambience.Name = "Ambience"
ambience.Volume = 1
ambience.Parent = SoundService
local loops = {}
for _, name in { "A", "B" } do
	local group = Instance.new("SoundGroup")
	group.Name = "Ambience" .. name
	group.Volume = 0
	group.Parent = ambience
	local sound = Instance.new("Sound")
	sound.Name = "Loop" .. name
	sound.Looped = true
	sound.SoundGroup = group
	sound.Parent = group
	loops[name] = { Group = group, Sound = sound, Volume = 0, From = 0 }
end
local active, idle = loops.A, loops.B

local function startLoop()
	active, idle = idle, active
	local row = Env.Asset(zone, audio.Loop, "Sound")
	active.Sound:Stop()
	active.Sound.SoundId = row and row.Id or ""
	active.Volume = row and (audio.Volume or Env.LOOP_VOLUME) or 0
	if row then
		active.Sound:Play()
	end
	for _, l in loops do
		l.From = l.Group.Volume
	end
end

local swapped = true
local function startBlend(z)
	zone = z
	Env.CurrentZone = z
	profile, audio = Env.Profile(z), Env.Audio(z)
	blendStart = os.clock()
	swapped = false
	for _, e in entries do
		if bind(e) then
			e.From = e.Current
		end
	end
	startLoop()
end

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if camera then
		box.CFrame = camera.CFrame * CFrame.new(0, 0, -Env.PARTICLE_AHEAD)
	end
	local t = (os.clock() - blendStart) / BLEND
	local blending = t < 1
	if not (blending or dirty) then
		return
	end
	dirty = false
	local k = Env.Ease(t)
	local peak = blending and math.sin(math.pi * math.clamp(t, 0, 1)) or 0
	if not swapped and t >= 0.5 then
		swapped = true
		configureParticles()
	end
	for _, e in entries do
		if bind(e) then
			local goal = target(e)
			local value = blending and lerp(e.From, goal, k) or goal
			if peak > 0 and e.Group == "Atmosphere" and (e.Key == "Haze" or e.Key == "Density") then
				value += peak * (e.Key == "Haze" and Env.HAZE_PEAK or Env.DENSITY_PEAK)
			end
			write(e, value)
		end
	end
	local fade = blending and (t < 0.5 and 1 - 2 * t or 2 * t - 1) or 1
	for _, slot in emitters do
		slot.Emitter.Enabled = slot.Rate > 0 and not reduced()
		slot.Emitter.Rate = slot.Rate * fade
	end
	for _, l in loops do
		local goal = l == active and l.Volume or 0
		l.Group.Volume = blending and l.From + (goal - l.From) * k or goal
	end
	if not blending and idle.Sound.IsPlaying then
		idle.Sound:Stop()
	end
end)

-- Zone check every POLL at the camera focus; a new zone must hold for HOLD (Env.ForcedZone overrides, for tests)
task.spawn(function()
	local pending, since = nil, 0
	while true do
		local camera = Workspace.CurrentCamera
		local z = Env.ForcedZone
		if z == nil and camera then
			z = Env.ZoneAt(camera.Focus.Position)
		end
		if z ~= nil and z ~= zone then
			if zone == nil or Env.ForcedZone ~= nil or (pending == z and os.clock() - since >= Env.HOLD) then
				startBlend(z)
				pending = nil
			elseif pending ~= z then
				pending, since = z, os.clock()
			end
		else
			pending = nil
		end
		task.wait(Env.POLL)
	end
end)

-- One-shots: a random one every ONESHOT_EVERY seconds, ONESHOT_DISTANCE studs from the camera (off when reduced)
task.spawn(function()
	local rng = Random.new()
	while true do
		task.wait(rng:NextNumber(Env.ONESHOT_EVERY.Min, Env.ONESHOT_EVERY.Max))
		local shots = audio.OneShots or {}
		local camera = Workspace.CurrentCamera
		local row = #shots > 0 and Env.Asset(zone, shots[rng:NextInteger(1, #shots)], "Sound")
		if row and camera and not reduced() then
			local angle = rng:NextNumber(0, 2 * math.pi)
			local dist = rng:NextNumber(Env.ONESHOT_DISTANCE.Min, Env.ONESHOT_DISTANCE.Max)
			local at = Instance.new("Attachment")
			at.WorldPosition = camera.CFrame.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * dist
			at.Parent = terrain
			local sound = Instance.new("Sound")
			sound.SoundId = row.Id
			sound.Volume = rng:NextNumber(Env.ONESHOT_VOLUME.Min, Env.ONESHOT_VOLUME.Max)
			sound.SoundGroup = ambience
			sound.Parent = at
			sound.Ended:Once(function()
				at:Destroy()
			end)
			sound:Play()
			task.delay(30, function()
				at:Destroy() -- a sound that never loads
			end)
		end
	end
end)

-- REDUCED EFFECTS (spec 8): mesh shadows off and far hero detail hidden; post-FX, shadows and particles follow
-- `reduced()` in the blend loop above
local function applyShadow(part)
	if part:IsA("BasePart") then
		if part:GetAttribute("BiomeCastShadow") == nil then
			part:SetAttribute("BiomeCastShadow", part.CastShadow)
		end
		part.CastShadow = part:GetAttribute("BiomeCastShadow") and not reduced()
	end
end
CollectionService:GetInstanceAddedSignal("BiomeAsset"):Connect(applyShadow)

-- Tunnel light strips (spec 3.5; tag TunnelLight = Shared/Tunnel.LIGHT_TAG, attribute Index): REDUCED EFFECTS hides
-- every second strip and stops the flicker; otherwise one strip in FLICKER_EVERY flickers while near the camera
local LIGHT_TAG = "TunnelLight"
local FLICKER_EVERY = 11 -- placeholder: "a few lights flicker"
local FLICKER_DISTANCE = 300 -- placeholder: studs from the camera
local flickers = {} -- strip -> its SurfaceLight's server Brightness
local function applyLight(strip)
	local index = strip:GetAttribute("Index")
	local light = strip:FindFirstChildOfClass("SurfaceLight")
	if type(index) ~= "number" then
		return
	end
	if light and index % FLICKER_EVERY == 0 and not flickers[strip] then
		flickers[strip] = light.Brightness
	end
	local off = reduced() and index % 2 == 0
	strip.LocalTransparencyModifier = off and 1 or 0
	if light then
		light.Enabled = not off
		light.Brightness = flickers[strip] or light.Brightness
	end
end
CollectionService:GetInstanceAddedSignal(LIGHT_TAG):Connect(applyLight)
CollectionService:GetInstanceRemovedSignal(LIGHT_TAG):Connect(function(strip)
	flickers[strip] = nil
end)
RunService.Heartbeat:Connect(function()
	local camera = Workspace.CurrentCamera
	if reduced() or not camera or next(flickers) == nil then
		return
	end
	local eye, t = camera.CFrame.Position, os.clock()
	for strip, brightness in flickers do
		local light = strip:FindFirstChildOfClass("SurfaceLight")
		if light and (strip.Position - eye).Magnitude < FLICKER_DISTANCE then
			-- short dark stutters: noise below the threshold blanks the strip
			local dark = math.noise(t * 7, strip:GetAttribute("Index") * 0.37) < -0.25
			light.Brightness = dark and brightness * 0.1 or brightness
			strip.LocalTransparencyModifier = dark and 0.6 or 0
		end
	end
end)

local function applyQuality()
	for _, part in CollectionService:GetTagged("BiomeAsset") do
		applyShadow(part)
	end
	for _, strip in CollectionService:GetTagged(LIGHT_TAG) do
		applyLight(strip)
	end
	dirty = true
end
player:GetAttributeChangedSignal("ReduceEffects"):Connect(applyQuality)
ReplicatedStorage:GetAttributeChangedSignal("WeatherEvent"):Connect(function()
	dirty = true
end)
applyQuality()

local hidden = {} -- BiomeDetail instance -> true while hidden
task.spawn(function()
	while true do
		local camera = Workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		for _, inst in CollectionService:GetTagged("BiomeDetail") do
			local pos = inst:IsA("Model") and inst:GetPivot().Position or inst:IsA("BasePart") and inst.Position
			local hide = reduced() and eye ~= nil and pos ~= nil and (pos - eye).Magnitude > Env.DETAIL_DISTANCE
			if (hidden[inst] or false) ~= hide then
				hidden[inst] = hide or nil
				for _, part in inst:IsA("BasePart") and { inst } or inst:GetDescendants() do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = hide and 1 or 0
					end
				end
			end
		end
		task.wait(1)
	end
end)
