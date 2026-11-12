--!nonstrict
-- Big Raga's effects (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Boss and attacks"; owner 2026-11-05: show the boss's urgency). Visual
-- only: nothing here reads back into damage or speed. Timed from BossRagaPoses, which server time alone decides, so every player
-- sees the same effect at the same moment. Everything lives in the arena's BossEffects folder, and leaves it within 6 s; the two
-- things the engine needs elsewhere, a Lighting grade and a screen-edge gui, end by themselves.
-- All sizes and counts are placeholders to judge by eye. A particle tops out near 100 studs, so the shapes that must read from 900
-- studs are parts with a Decal or Neon; particles are the texture around them. Sounds: only the "cue:" hooks below.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig"))
local Art = require(Shared:WaitForChild("BossVfxArt"))
local Event = require(Shared:WaitForChild("BossEventConfig"))
local Poses = require(Shared:WaitForChild("BossRagaPoses"))
local BossRaga = require(script.Parent:WaitForChild("BossRaga"))
local BossShake = require(script.Parent:WaitForChild("BossShake"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local FORCE = "BossVfxForce" -- client-local test attribute: not nil holds off the schedule, an event name plays that event
local RED, HOT, ORANGE = Color3.fromRGB(255, 36, 24), Color3.fromRGB(255, 226, 190), Color3.fromRGB(255, 120, 40)
local GOLD, PALE_GOLD = Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 240, 170)
local DUST, DARK = Color3.fromRGB(214, 200, 182), Color3.fromRGB(58, 48, 48)
local SHOCK_SEGMENTS, SHOCK_SEGMENTS_REDUCED = 36, 18 -- Neon panels of the shockwave's wall
local SHOCK_REACH, SHOCK_SECONDS = 1500, 1.15 -- studs from the blade, past the far side of the ring
local SHOCK_HEIGHT = 90
local MAX_DECAL_PART = 2048 -- a part's largest size
local LOW_HP = 0.25 -- owner: below this, a red aura and embers only; the schedule stays as the server decides
local MOUTH = Vector3.new(0, -0.9, 0.75) -- units from the Head's joint
local HUB_UP = 1700 -- studs of the wheel's beam
local SHAFTS, SHAFTS_REDUCED = 6, 3
local RISE_PULSES = 3 -- the rise's cracks and jolts, evenly through it
local RISE_DUST, RISE_DUST_REDUCED = 15, 3 -- a second of the rise; with the debris, the bursts and the pulses: budget 150, reduced 30
local RISE_DEBRIS = 15 -- a second of the rise
local RISE_PULSE_DUST, RISE_PULSE_DUST_REDUCED = 10, 3
local SCREAM_PULSES, SCREAM_PULSES_REDUCED = 10, 3 -- budget: 10 x (20 + 14) + 4 = 344, reduced 3 x (6 + 5) + 2 = 35
local SCREAM_LATE = 0.5 -- s into the scream: a client later than this skips its effects
-- Phase 2's look (BOSS_EVENT_SPEC "Phase 2"), proposed: the screen dims in the scream, then stays darkish. No tint (owner 2026-11-06).
local TONE_SCREAM = { Brightness = -0.22 }
local TONE_PHASE = { Brightness = -0.08 }
local TONE_SECONDS = 0.8

local BossVfx = {}

local effects, raga = nil, nil
local tracked = {} -- part -> { Joint, or a function } moved to the boss each frame
local previousMove, previousTime = nil, nil
local screaming = false
local tone, toneGoal = nil, nil -- Phase 2's ColorCorrectionEffect and the look it is heading for
local risePlay, aura = nil, nil
local impactPoint = BossRaga.RestPoint(Poses.ImpactPoint) * Vector3.new(1, 0, 1) + Vector3.new(0, Arena.Y + 1, 0)

local function reduced()
	return UiMotion.Reduced()
end

-- Helpers ----------------------------------------------------------------------------------------------------------------------

local function expire(instance, seconds)
	task.delay(seconds, function()
		instance:Destroy()
		tracked[instance] = nil
	end)
end

local function sequence(...)
	local values, keys = { ... }, {}
	for i = 1, #values, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(values[i], values[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function holder(name, cframe, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Transparency = 1
	part.Size = size or Vector3.one
	part.CFrame = cframe
	part.Parent = effects
	return part
end

local function emitter(part, props)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightInfluence = 0
	for k, v in props do
		e[k] = v
	end
	e.Parent = part
	return e
end

-- Burst after a beat: a just-parented emitter can drop an Emit.
local function burst(e, count, delay)
	task.delay(0.03 + (delay or 0), function()
		if e.Parent then
			e:Emit(count)
		end
	end)
	return count
end

local function tween(instance, seconds, goal, style, direction)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

local function decal(part, texture, color, face, transparency)
	local d = Instance.new("Decal")
	d.Texture = texture
	d.Color3 = color
	d.Face = face
	d.Transparency = transparency or 0
	d.Parent = part
	return d
end

-- A flat ring seen from both sides, growing and fading. faces: the two faces the plane looks out of.
local function growingRing(name, cframe, from, to, seconds, color, delay, faces, thin)
	task.delay(delay or 0, function()
		if not effects or not effects.Parent then
			return
		end
		local function size(s)
			s = math.min(s, MAX_DECAL_PART)
			return thin == "Z" and Vector3.new(s, s, 0.2) or Vector3.new(s, 0.2, s)
		end
		local part = holder(name, cframe, size(from))
		local top = decal(part, Art.Ring, color, faces[1])
		local bottom = decal(part, Art.Ring, color, faces[2])
		tween(part, seconds, { Size = size(to) }, Enum.EasingStyle.Quart)
		tween(top, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(bottom, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		expire(part, seconds + 0.1)
	end)
end
local FLAT_FACES = { Enum.NormalId.Top, Enum.NormalId.Bottom }
local UPRIGHT_FACES = { Enum.NormalId.Front, Enum.NormalId.Back }

-- Screen ---------------------------------------------------------------------------------------------------------------------

local grade = nil -- the ColorCorrectionEffect while a grade runs
-- A brief look on the whole view. Own effect: Client/BiomeEnvironment owns Lighting's properties.
local function regrade(goal, inSeconds, hold, outSeconds)
	if grade then
		grade:Destroy()
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "BossVfxGrade"
	effect.Parent = Lighting
	grade = effect
	tween(effect, inSeconds, goal)
	task.delay(inSeconds + hold, function()
		if grade == effect then
			tween(effect, outSeconds, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) })
		end
	end)
	task.delay(inSeconds + hold + outSeconds, function()
		effect:Destroy()
		if grade == effect then
			grade = nil
		end
	end)
end

-- Own effect, as regrade's. Stepped every frame from server attributes, so a late client gets it too.
local function stepTone(screamLeft)
	local goal = ReplicatedStorage:GetAttribute("BossEventStage") == 2 and (screamLeft and TONE_SCREAM or TONE_PHASE)
	if not goal then
		if tone then
			tone:Destroy()
			tone, toneGoal = nil, nil
		end
		return
	end
	if goal ~= toneGoal then
		toneGoal = goal
		if not tone then
			tone = Instance.new("ColorCorrectionEffect")
			tone.Name = "BossPhase2Tone"
			tone.Parent = Lighting
		end
		tween(tone, reduced() and 0 or TONE_SECONDS, goal)
	end
end

local edges = nil
local function ensureEdges()
	if edges then
		return edges
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossVfxScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1 -- under the HUD
	gui.Enabled = false
	local frames = {}
	for _, row in
		{
			{ UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0), 90 },
			{ UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.7), -90 },
			{ UDim2.fromScale(0.25, 1), UDim2.fromScale(0, 0), 0 },
			{ UDim2.fromScale(0.25, 1), UDim2.fromScale(0.75, 0), 180 },
		}
	do
		local frame = Instance.new("Frame")
		frame.Size, frame.Position = row[1], row[2]
		frame.BorderSizePixel = 0
		frame.BackgroundTransparency = 1
		frame.Active = false
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = row[3]
		gradient.Transparency = sequence(0, 0, 1, 1)
		gradient.Parent = frame
		frame.Parent = gui
		table.insert(frames, frame)
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	edges = { Gui = gui, Frames = frames, Token = 0 }
	return edges
end

-- Screen-edge pulses: count times up to `peak` opacity and away. Reduced keeps one pulse, softer.
local function pulseEdges(color, peak, seconds, count)
	local e = ensureEdges()
	e.Token += 1
	local token = e.Token
	e.Gui.Enabled = true
	if reduced() then
		peak, count = peak * 0.5, 1
	end
	for _, frame in e.Frames do
		frame.BackgroundColor3 = color
	end
	task.spawn(function()
		for _ = 1, count do
			for _, frame in e.Frames do
				tween(frame, seconds * 0.25, { BackgroundTransparency = 1 - peak })
			end
			task.wait(seconds * 0.25)
			for _, frame in e.Frames do
				tween(frame, seconds * 0.75, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
			end
			task.wait(seconds * 0.75)
		end
		if e.Token == token then
			e.Gui.Enabled = false
		end
	end)
end

-- By distance from the camera: full up close, never less than `floor` of it, since the boss is huge from anywhere on the ring.
local function shakeAt(position, magnitude, roughness, fade, floor)
	local camera = Workspace.CurrentCamera
	local distance = camera and (camera.CFrame.Position - position).Magnitude or 0
	BossShake.Kick(magnitude * math.clamp(1 - distance / 2400, floor or 0.3, 1), roughness, fade)
end

-- Impact: the blade hits ---------------------------------------------------------------------------------------------------------

-- The shockwave's wall: one ring of thin Neon panels racing outward along the floor, through the track and out over the clouds.
local function shockwave(center)
	local count = reduced() and SHOCK_SEGMENTS_REDUCED or SHOCK_SEGMENTS
	local panels = {}
	for k = 1, count do
		local panel = holder("Shockwave", CFrame.new(center))
		panel.Material = Enum.Material.Neon
		panel.Color = k % 2 == 0 and HOT or RED
		panels[k] = panel
	end
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local u = (os.clock() - started) / SHOCK_SECONDS
		if u >= 1 or not panels[1].Parent then
			connection:Disconnect()
			for _, panel in panels do
				panel:Destroy()
			end
			return
		end
		local eased = 1 - (1 - u) ^ 2
		local radius = 20 + (SHOCK_REACH - 20) * eased
		local chord = 2 * radius * math.tan(math.pi / count) * 1.04
		local height = SHOCK_HEIGHT * (1 - 0.8 * u)
		for k, panel in panels do
			panel.Size = Vector3.new(chord, height, 5)
			panel.CFrame = CFrame.new(center)
				* CFrame.Angles(0, k / count * 2 * math.pi, 0)
				* CFrame.new(0, height / 2, -radius)
			panel.Transparency = 0.08 + 0.92 * u ^ 2
		end
	end)
	-- The ring on the floor, racing with it. Its part stops at the largest size, a little past the track.
	growingRing("Shockwave", CFrame.new(center), 100, MAX_DECAL_PART, SHOCK_SECONDS * 0.8, RED, 0, FLAT_FACES)
	-- A jolt when the wave passes this player
	local camera = Workspace.CurrentCamera
	if camera then
		local distance = ((camera.CFrame.Position - center) * Vector3.new(1, 0, 1)).Magnitude
		if distance < SHOCK_REACH then
			local u = 1 - math.sqrt(1 - distance / SHOCK_REACH)
			task.delay(u * SHOCK_SECONDS, BossShake.Kick, 1.6, 22, 0.35)
		end
	end
end

local function playImpact()
	-- cue: BossImpact (a boom with a crack on top)
	local few = reduced()
	local center = impactPoint + (impactPoint - Arena.Center) * Vector3.new(1, 0, 1) * (raga.Growth - 1)
	local spot = holder("ImpactSpot", CFrame.new(center), Vector3.new(160, 1, 160))
	expire(spot, 4.4)
	local total = 0
	total += burst(
		emitter(spot, {
			Name = "Flash",
			Texture = Art.Flare,
			Color = ColorSequence.new(HOT, RED),
			LightEmission = 1,
			Size = sequence(0, 70, 0.3, 100, 1, 90),
			Transparency = sequence(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.18, 0.3),
			Rotation = NumberRange.new(0, 360),
			Speed = NumberRange.new(0),
			ZOffset = 8,
		}),
		few and 1 or 3
	)
	total += burst(
		emitter(spot, {
			Name = "Dust",
			Texture = Art.Dust,
			Color = ColorSequence.new(DUST),
			LightInfluence = 0.6,
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(70, 70),
			Size = sequence(0, 34, 0.4, 80, 1, 100),
			Transparency = sequence(0, 0.2, 0.6, 0.45, 1, 1),
			Lifetime = NumberRange.new(1.4, 2.6),
			Speed = NumberRange.new(130, 320),
			Drag = 2.2,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
		}),
		few and 14 or 40
	)
	total += burst(
		emitter(spot, {
			Name = "Sparks",
			Texture = Art.Spark,
			Color = ColorSequence.new(HOT, ORANGE),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(75, 75),
			Size = sequence(0, 26, 1, 2),
			Squash = NumberSequence.new(1.5),
			Lifetime = NumberRange.new(0.35, 0.8),
			Speed = NumberRange.new(450, 1000),
			Drag = 1.6,
			Acceleration = Vector3.new(0, -300, 0),
		}),
		few and 12 or 40
	)
	if not few then
		total += burst(
			emitter(spot, {
				Name = "Debris",
				Texture = Art.Shard,
				Color = ColorSequence.new(Color3.fromRGB(226, 218, 204)),
				LightInfluence = 0.8,
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(55, 55),
				Size = sequence(0, 18, 1, 12),
				Lifetime = NumberRange.new(1.2, 2.2),
				Speed = NumberRange.new(260, 520),
				Acceleration = Vector3.new(0, -520, 0),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-300, 300),
			}),
			30,
			0.04
		)
		-- Black twin: value under the bright dust
		total += burst(
			emitter(spot, {
				Name = "Smoke",
				Texture = Art.Dust,
				Color = ColorSequence.new(DARK),
				LightInfluence = 0.2,
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(60, 60),
				Size = sequence(0, 40, 1, 100),
				Transparency = sequence(0, 0.3, 0.7, 0.55, 1, 1),
				Lifetime = NumberRange.new(1.6, 3),
				Speed = NumberRange.new(60, 160),
				Drag = 1.4,
				Rotation = NumberRange.new(0, 360),
				ZOffset = -2,
			}),
			15,
			0.1
		)
	end
	shockwave(center)
	-- Hit stop's look: the pose holds (the bake), and the screen hits, once, briefly
	if not few then
		regrade({ Brightness = 0.35, Contrast = 0.5, Saturation = -0.4 }, 0.02, 0.05, 0.22)
	end
	shakeAt(center, 4.5, 11, 1.1, 0.35)
	pulseEdges(RED, 0.4, 0.35, 1)
	return total
end

-- The wind-up and the slash, around the Impact ------------------------------------------------------------------------------------

local blade = nil -- the part holding the blade's attachments while the attack runs

local function bladeCFrame()
	return raga:Frame("Sword")
end

-- Charged glow on the blade arm: a Beam along the blade that swells until the strike, with embers coming off it.
local function playCharge()
	-- cue: BossCharge (a rising whine)
	local few = reduced()
	local tip = Vector3.new(Poses.Bind.Sword.Tip[1], Poses.Bind.Sword.Tip[3], Poses.Bind.Sword.Tip[2])
		* Poses.Scale
		* Arena.BossScale
	tip = Vector3.new(-tip.X, tip.Y, tip.Z)
	local part = holder("BladeCharge", bladeCFrame())
	tracked[part] = bladeCFrame
	blade = part
	local base, point = Instance.new("Attachment"), Instance.new("Attachment")
	base.Parent = part
	point.Parent = part
	point.Position = tip
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = base, point
	beam.Texture = Art.Shaft
	beam.Color = ColorSequence.new(HOT, RED)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = 12, 4
	beam.Transparency = NumberSequence.new(0.1)
	beam.Parent = part
	local width = Instance.new("NumberValue")
	width.Value = 12
	width.Changed:Connect(function(value)
		beam.Width0, beam.Width1 = value, value * 0.5
	end)
	width.Parent = part
	tween(width, 1.05, { Value = 110 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local embers = emitter(part, {
		Name = "Embers",
		Texture = Art.Spark,
		Color = ColorSequence.new(ORANGE, RED),
		LightEmission = 1,
		Rate = few and 6 or 30,
		Size = sequence(0, 14, 1, 2),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(60, 180),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 220, 0),
		Enabled = true,
	})
	task.delay(1.05, function()
		embers.Enabled = false
	end)
	-- Blade from wind-up (0.7 s) to just past the blade's bite (2.05 s); the embers it let go still die here
	expire(part, 1.5)
end

-- The slash arc is the blade's real path: a ribbon from the wrist to the point, only while it swings.
local function playSlash()
	if not blade or not blade.Parent then
		return
	end
	-- cue: BossSlash (a heavy whoosh)
	local base, point = blade:FindFirstChildOfClass("Attachment"), nil
	for _, child in blade:GetChildren() do
		if child:IsA("Attachment") and child ~= base then
			point = child
		end
	end
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = base, point
	trail.Color = ColorSequence.new(HOT, RED)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = 0.45
	trail.MinLength = 0
	trail.Transparency = sequence(0, 0.05, 1, 1)
	trail.Parent = blade
end

-- Roar ------------------------------------------------------------------------------------------------------------------------

local function playRoar()
	-- cue: BossRoar
	local few = reduced()
	local mouth = raga:Point("Head", MOUTH)
	local spot = holder("RoarSpot", CFrame.new(mouth), Vector3.new(60, 60, 60))
	expire(spot, 4)
	local total = 0
	total += burst(
		emitter(spot, {
			Name = "Flash",
			Texture = Art.Flare,
			Color = ColorSequence.new(HOT, RED),
			LightEmission = 1,
			Size = sequence(0, 60, 0.5, 100, 1, 70),
			Transparency = sequence(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.25, 0.4),
			Rotation = NumberRange.new(0, 360),
			Speed = NumberRange.new(0),
		}),
		few and 2 or 4
	)
	total += burst(
		emitter(spot, {
			Name = "Blast",
			Texture = Art.Spark,
			Color = ColorSequence.new(HOT, RED),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Size = sequence(0, 40, 1, 4),
			Lifetime = NumberRange.new(0.5, 1.1),
			Speed = NumberRange.new(500, 1100),
			Drag = 1.2,
		}),
		few and 14 or 50
	)
	total += burst(
		emitter(spot, {
			Name = "Breath",
			Texture = Art.Dust,
			Color = ColorSequence.new(DARK, RED),
			LightInfluence = 0.2,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Size = sequence(0, 30, 1, 100),
			Transparency = sequence(0, 0.25, 0.6, 0.55, 1, 1),
			Lifetime = NumberRange.new(1.2, 2.4),
			Speed = NumberRange.new(150, 340),
			Drag = 1.8,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
		}),
		few and 12 or 40
	)
	if not few then
		total += burst(
			emitter(spot, {
				Name = "Ash",
				Texture = Art.Shard,
				Color = ColorSequence.new(DARK),
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
				Size = sequence(0, 10, 1, 4),
				Lifetime = NumberRange.new(1.5, 3),
				Speed = NumberRange.new(200, 480),
				Drag = 1.5,
				Acceleration = Vector3.new(0, -90, 0),
				RotSpeed = NumberRange.new(-200, 200),
			}),
			30,
			0.05
		)
	end
	-- Expanding sonic rings: level with the mouth and tipped, so one always opens toward a viewer
	local rings = few and 2 or 3
	for k = 1, rings do
		local tilt = CFrame.Angles(math.rad(k == 2 and 24 or k == 3 and -24 or 0), 0, 0)
		growingRing(
			"SonicRing",
			CFrame.new(mouth) * tilt,
			160,
			1800,
			0.95,
			k % 2 == 1 and RED or HOT,
			(k - 1) * 0.17,
			FLAT_FACES
		)
	end
	-- Sky darkens: a grade over everything, on the frame the roar opens
	regrade(
		{ Brightness = -0.2, Contrast = 0.15, Saturation = -0.15, TintColor = Color3.fromRGB(255, 190, 180) },
		0.25,
		1.5,
		0.9
	)
	pulseEdges(RED, 0.65, 0.55, 3)
	shakeAt(mouth, 3, 14, 1.6, 0.45)
	return total
end

-- The scream (BOSS_EVENT_SPEC "Phase 2"): a Roar held for its whole length, from one spot on the mouth, in even pulses over `seconds`.
local function playScream(seconds)
	-- cue: BossRoar
	local few = reduced()
	local function mouth()
		return CFrame.new(raga:Point("Head", MOUTH))
	end
	local spot = holder("RoarSpot", mouth(), Vector3.new(90, 90, 90))
	tracked[spot] = mouth
	expire(spot, seconds + 3)
	local total = burst(
		emitter(spot, {
			Name = "Flash",
			Texture = Art.Flare,
			Color = ColorSequence.new(HOT, RED),
			LightEmission = 1,
			Size = sequence(0, 70, 0.5, 100, 1, 80),
			Transparency = sequence(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.3, 0.5),
			Rotation = NumberRange.new(0, 360),
			Speed = NumberRange.new(0),
		}),
		few and 2 or 4
	)
	local blast = emitter(spot, {
		Name = "Blast",
		Texture = Art.Spark,
		Color = ColorSequence.new(HOT, RED),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Size = sequence(0, 70, 1, 6),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(600, 1300),
		Drag = 1.2,
	})
	local breath = emitter(spot, {
		Name = "Breath",
		Texture = Art.Dust,
		Color = ColorSequence.new(RED),
		LightInfluence = 0.2,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		Size = sequence(0, 50, 1, 100),
		Transparency = sequence(0, 0.6, 0.6, 0.8, 1, 1), -- thin: the close camera must see the head through it
		Lifetime = NumberRange.new(1.2, 2.4),
		Speed = NumberRange.new(200, 420),
		Drag = 1.8,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
	})
	local pulses = few and SCREAM_PULSES_REDUCED or SCREAM_PULSES
	for k = 0, pulses - 1 do
		local delay = k * seconds / pulses
		total += burst(blast, few and 6 or 20, delay)
		total += burst(breath, few and 5 or 14, delay)
		task.delay(delay, function()
			if raga and spot.Parent then
				local tilt = CFrame.Angles(math.rad(k % 3 == 1 and 24 or k % 3 == 2 and -24 or 0), 0, 0)
				growingRing(
					"SonicRing",
					mouth() * tilt,
					200,
					MAX_DECAL_PART,
					1.1,
					k % 2 == 0 and RED or HOT,
					0,
					FLAT_FACES
				)
			end
		end)
	end
	regrade(
		{ Brightness = -0.25, Contrast = 0.2, Saturation = -0.2, TintColor = Color3.fromRGB(255, 180, 170) },
		0.25,
		seconds - 0.25,
		0.6
	)
	pulseEdges(RED, 0.65, seconds / 3, 3)
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("RacerBossEvent")
	UiFeedback.Play("BossScream", gui and gui:FindFirstChild("BossBar"))
	effects:SetAttribute("LastParticles", total)
end

-- WheelClick: the source's adaptation signature --------------------------------------------------------------------------------

local function playClick(scale)
	scale = scale or 1
	-- cue: BossWheelClick (the clunk of one step)
	local few = reduced()
	local frame = raga:Frame("Wheel")
	local hub = frame.Position
	local spot = holder("WheelSpot", CFrame.new(hub), Vector3.new(220, 220, 20))
	expire(spot, 3)
	local total = 0
	total += burst(
		emitter(spot, {
			Name = "Flare",
			Texture = Art.Flare,
			Color = ColorSequence.new(PALE_GOLD, GOLD),
			LightEmission = 1,
			Size = sequence(0, 70 * scale, 0.3, 100 * scale, 1, 70 * scale),
			Transparency = sequence(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.3, 0.5),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120),
			Speed = NumberRange.new(0),
		}),
		few and 2 or 6
	)
	total += burst(
		emitter(spot, {
			Name = "Sparks",
			Texture = Art.Spark,
			Color = ColorSequence.new(PALE_GOLD, GOLD),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Size = sequence(0, 22, 1, 2),
			Lifetime = NumberRange.new(0.4, 1),
			Speed = NumberRange.new(260 * scale, 640 * scale),
			Drag = 1.2,
			Acceleration = Vector3.new(0, -200, 0),
		}),
		few and 12 or 36
	)
	if not few then
		total += burst(
			emitter(spot, {
				Name = "Motes",
				Texture = Art.Flare,
				Color = ColorSequence.new(GOLD),
				LightEmission = 1,
				Size = sequence(0, 16, 1, 0),
				Lifetime = NumberRange.new(1, 2),
				Speed = NumberRange.new(30, 110),
				SpreadAngle = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, 70, 0),
			}),
			20,
			0.08
		)
	end
	-- A beam straight up from the hub, every step
	local base, top = Instance.new("Attachment"), Instance.new("Attachment")
	base.Parent = spot
	top.Parent = spot
	top.WorldPosition = hub + Vector3.new(0, HUB_UP, 0)
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = base, top
	beam.Texture = Art.Shaft
	beam.Color = ColorSequence.new(PALE_GOLD, GOLD)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = 170, 70
	beam.Transparency = sequence(0, 0.05, 1, 0.6)
	beam.Parent = spot
	local fade = Instance.new("NumberValue")
	fade.Value = 0.05
	fade.Changed:Connect(function(value)
		beam.Transparency = sequence(0, value, 1, 0.6 + 0.4 * value)
	end)
	fade.Parent = spot
	tween(fade, 0.8, { Value = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	-- The wheel's own ring, in its plane
	growingRing("WheelRing", frame, 260, 1100, 0.6, GOLD, 0, UPRIGHT_FACES, "Z")
	-- A brief red warning: it has adapted
	pulseEdges(RED, 0.5, 0.5, 1)
	shakeAt(hub, 1.2, 18, 0.45, 0.5)
	return total
end

local EVENTS = { Impact = playImpact, Roar = playRoar, WheelClick = playClick }

local function playEvent(name)
	local play = EVENTS[name]
	if not (play and effects) then
		return
	end
	effects:SetAttribute("LastParticles", play())
end

-- The rise --------------------------------------------------------------------------------------------------------------------

local function daisTop()
	return Vector3.new(Arena.Center.X, Arena.DaisY + 0.6, Arena.Center.Z)
end

local function startRise()
	-- cue: BossRiseRumble (a looped rumble with this shake)
	local few = reduced()
	local play = { Stage = 0 }
	local spot =
		holder("RiseSpot", CFrame.new(daisTop()), Vector3.new(2 * Arena.DaisRadius + 40, 1, 2 * Arena.DaisRadius + 40))
	play.Spot = spot
	local dust = emitter(spot, {
		Name = "Dust",
		Texture = Art.Dust,
		Color = ColorSequence.new(DUST),
		LightInfluence = 0.6,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(50, 50),
		Size = sequence(0, 40, 0.5, 90, 1, 100),
		Transparency = sequence(0, 0.3, 0.6, 0.5, 1, 1),
		Lifetime = NumberRange.new(2, 3.2),
		Speed = NumberRange.new(80, 220),
		Drag = 0.8,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
		Rate = few and RISE_DUST_REDUCED or RISE_DUST,
		Enabled = true,
	})
	play.Dust = dust
	local total = burst(dust, few and 8 or 30)
		+ math.ceil((few and RISE_DUST_REDUCED or RISE_DUST) * Event.RiseSeconds)
		+ RISE_PULSES * (few and RISE_PULSE_DUST_REDUCED or RISE_PULSE_DUST)
	if not few then
		local debris = emitter(spot, {
			Name = "Debris",
			Texture = Art.Shard,
			Color = ColorSequence.new(Color3.fromRGB(226, 218, 204)),
			LightInfluence = 0.8,
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(30, 30),
			Size = sequence(0, 16, 1, 10),
			Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(260, 460),
			Acceleration = Vector3.new(0, -420, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-260, 260),
			Rate = RISE_DEBRIS,
			Enabled = true,
		})
		play.Debris = debris
		total += math.ceil(RISE_DEBRIS * Event.RiseSeconds)
	end
	-- Cracks that spread in stages across the dais, a jolt on each. Only the dais: past it is open air.
	local crack = holder("Cracks", CFrame.new(daisTop()), Vector3.new(160, 0.2, 160))
	decal(crack, Art.Cracks, RED, Enum.NormalId.Top)
	play.Crack = crack
	-- Light shafts up out of the dais rim
	play.Shafts = {}
	local count = few and SHAFTS_REDUCED or SHAFTS
	for k = 1, count do
		local a = k / count * 2 * math.pi
		local rim = Vector3.new(math.cos(a), 0, math.sin(a)) * (Arena.DaisRadius - 10)
		local low, high = Instance.new("Attachment"), Instance.new("Attachment")
		low.Parent = spot
		high.Parent = spot
		low.Position = rim
		high.Position = rim * 1.5 + Vector3.new(0, 1300, 0)
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = low, high
		beam.Texture = Art.Shaft
		beam.Color = ColorSequence.new(HOT, RED)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Width0, beam.Width1 = 40, 150
		beam.Transparency = sequence(0, 0.2, 0.7, 0.55, 1, 1)
		beam.Parent = spot
		table.insert(play.Shafts, beam)
	end
	pulseEdges(RED, 0.5, 0.8, 2)
	BossShake.Kick(4, 13, 1)
	effects:SetAttribute("LastParticles", total)
	return play
end

local function stepRise(play, since)
	local rumble = 1.6 * (0.45 + 0.55 * math.clamp(1 - since / Event.RiseSeconds, 0, 1))
	BossShake.Hold("BossRise", rumble, 16)
	local stage = math.floor(since / (Event.RiseSeconds / (RISE_PULSES + 1)))
	if stage ~= play.Stage then
		play.Stage = stage
		local size = math.min(160 + stage * 60, 2 * Arena.DaisRadius)
		tween(play.Crack, 0.25, { Size = Vector3.new(size, 0.2, size) }, Enum.EasingStyle.Back)
		burst(play.Dust, reduced() and RISE_PULSE_DUST_REDUCED or RISE_PULSE_DUST)
		BossShake.Kick(2.8, 13, 0.8)
	end
end

-- Ends the shapes; a landing at the end of the rise is nothing more than the same shapes fading as the dust settles.
local function endRise(play, now)
	BossShake.Hold("BossRise", 0)
	if now then
		play.Spot:Destroy()
		play.Crack:Destroy()
		return
	end
	play.Dust.Enabled = false
	if play.Debris then
		play.Debris.Enabled = false
	end
	for _, beam in play.Shafts do
		beam.Enabled = false
	end
	for _, d in play.Crack:GetChildren() do
		tween(d, 3, { Transparency = 1 })
	end
	expire(play.Spot, 3.4)
	expire(play.Crack, 3.4)
end

-- The low-HP aura -------------------------------------------------------------------------------------------------------------

-- Below LOW_HP only, for as long as it holds. Tongues hugging the body and embers rising off it; no faster schedule, no damage.
local function startAura()
	-- cue: BossEnraged
	local few = reduced()
	local bodyFrame = function()
		return raga:Frame("UpperTorso") * CFrame.new(0, 60 * Arena.BossScale, 0)
	end
	local part = holder("LowHpAura", bodyFrame(), Vector3.new(300, 440, 150) * Arena.BossScale)
	tracked[part] = bodyFrame
	emitter(part, {
		Name = "Tongues",
		Texture = Art.Dust,
		Color = ColorSequence.new(ORANGE, RED),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Top,
		Size = sequence(0, 60, 1, 14),
		Transparency = sequence(0, 0.35, 1, 1),
		Lifetime = NumberRange.new(0.5, 0.95),
		Speed = NumberRange.new(90, 180),
		Acceleration = Vector3.new(0, 120, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		Rate = few and 3 or 12,
		Enabled = true,
	})
	emitter(part, {
		Name = "Embers",
		Texture = Art.Spark,
		Color = ColorSequence.new(ORANGE, RED),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(25, 25),
		Size = sequence(0, 12, 1, 2),
		Lifetime = NumberRange.new(1.2, 2.6),
		Speed = NumberRange.new(90, 260),
		Rate = few and 4 or 14,
		Enabled = true,
	})
	return part
end

-- Runs ---------------------------------------------------------------------------------------------------------------------------

-- Moments of the schedule, per move, on top of the bake's own Events.
local TIMED = {
	attack = { { 0.7, playCharge }, { 1.4, playSlash } },
}

local function fireBetween(move, from, to)
	for _, row in TIMED[move] or {} do
		if row[1] > from and row[1] <= to then
			row[2]()
		end
	end
	for _, event in Poses.Moves[move].Events do
		if event.Time > from and event.Time <= to then
			playEvent(event.Name)
		end
	end
end

local function clear()
	if risePlay then
		endRise(risePlay, true)
		risePlay = nil
	end
	BossShake.Hold("BossRise", 0)
	if tone then
		tone:Destroy()
		tone, toneGoal = nil, nil
	end
	aura = nil
	table.clear(tracked)
	blade = nil
	if effects then
		effects:ClearAllChildren()
	end
end

-- Call with the arena's BossEffects folder and the boss.
function BossVfx.Start(folder, boss)
	effects, raga = folder, boss
	previousMove, previousTime = nil, nil
	screaming = false
end

function BossVfx.Stop()
	clear()
	effects, raga = nil, nil
end

-- since: seconds since the spawn, nil before it. screamLeft: the scream's seconds left, nil outside it.
function BossVfx.Step(since, move, localTime, screamLeft)
	if not effects then
		return
	end
	for part, source in tracked do
		part.CFrame = source()
	end
	stepTone(screamLeft)
	if ReplicatedStorage:GetAttribute(FORCE) ~= nil then
		return
	end
	local rising = since ~= nil and since < Event.RiseSeconds
	if rising and not risePlay then
		risePlay = startRise()
	elseif risePlay and not rising then
		endRise(risePlay)
		risePlay = nil
	end
	if risePlay then
		stepRise(risePlay, since)
	end

	local hp, max = ReplicatedStorage:GetAttribute("BossEventHp"), ReplicatedStorage:GetAttribute("BossEventMaxHp")
	local fighting = ReplicatedStorage:GetAttribute("BossEventPhase") == "Fight" and not rising
	local low = fighting and hp and max and max > 0 and hp / max < LOW_HP
	if low and not aura then
		aura = startAura()
	elseif aura and not low then
		tracked[aura] = nil
		aura:Destroy()
		aura = nil
	end

	if screamLeft and not screaming and screamLeft >= Event.ScreamSeconds - SCREAM_LATE then
		playScream(screamLeft)
	end
	if screaming and not screamLeft then
		-- The wheel's dead stop (BOSS_EVENT_SPEC "Phase 2"), for a client that saw the scream.
		playClick(2.5)
		local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		gui = gui and gui:FindFirstChild("RacerBossEvent")
		UiFeedback.Play("BossScream", gui and gui:FindFirstChild("BossBar"))
	end
	screaming = screamLeft ~= nil

	if since and not rising then
		if move == previousMove and previousTime and localTime > previousTime then
			if localTime - previousTime < 0.5 then -- a long hitch skips its effects rather than playing them late
				fireBetween(move, previousTime, localTime)
			end
		elseif move ~= previousMove and previousMove and localTime < 0.5 then
			fireBetween(move, -1, localTime)
		end
	end
	previousMove, previousTime = move, localTime
end

ReplicatedStorage:GetAttributeChangedSignal(FORCE):Connect(function()
	local value = ReplicatedStorage:GetAttribute(FORCE)
	if value == nil then
		return
	end
	clear()
	if value ~= "" then
		playEvent(value)
	end
end)

return BossVfx
