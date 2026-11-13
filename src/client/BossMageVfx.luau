--!nonstrict
-- The Elf Mage's effects (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"). Visual only: nothing here reads
-- back into damage. Timed from BossMagePoses, which server time alone decides, and built with Client/BossVfx's helpers (BossVfx.Kit)
-- in the arena's BossEffects folder. Each move has a lead cue before its event: lightning marks its floor spots 1.0 s ahead, the golem
-- gathers motes 2.2 s before each slam, the barrage opens its magic circles one by one from 0.3 s. Spots come from a seed of the schedule
-- start and the cycle, so every client draws the same ones. All sizes, counts and colours are placeholders to judge from a capture.
-- Lightning and barrage spam the whole arena over the move's 2 s Window (owner 2026-11-11, BOSS_EVENT_SPEC "Strike window"): a
-- strike every 0.15 s, 14 strikes, 7 to 10 bolts or beams each, a mark leading each bolt. Bolt, beam and flash parts are pooled
-- per name and short-lived; the hit particles come from one reused spot. The golem's events run on its own move
-- (BossMagePoses.GolemAt while a golem stands), tracked apart from hers. Debug field: BossEffects attribute LastStrikes, JSON
-- { Move, Strikes = { { T, Spots = { {x, z} } } } }.
-- BossVfxForce (client-local test attribute, as Client/BossVfx): not nil holds off the schedule; Lightning, Slam, Sweep or Barrage
-- plays that event with its lead cue at once.
-- Pose-tied (BOSS_EVENT_SPEC "Animation rework", "Pose-tied effects"): the lightning charges as a StaffCharge point at the staff's
-- tip, the barrage's 10 circles open one after another in a wide fan in front of the staff and around her, small to large, facing
-- along it, the sweep's dust puffs follow the golem's lower fist, and the golem's rise and her golem_fall row raise dust.
-- Positions come from the live posed parts (Client/BossMage:Point), the same frame they are drawn.
-- Stronger look (owner 2026-11-12 after playing, design doc 4.37 "Elf Mage effects stronger"): each bolt a white BoltCore inside a
-- purple Bolt glow with a branch, a white StrikeFlash, a purple ShockRing, Sparks and lit purple smoke at its spot; each barrage beam
-- a white core, a blue-white glow and a near-black BarrageBeamEdge with a rounded head, a white flash, white sparks and black
-- BarrageSmoke at its spot.
-- Strike lighting (owner 2026-11-12, BOSS_EVENT_SPEC "Elf Mage strike lighting"): the room dims to a dark blue-violet from her
-- lightning's or barrage's lead-in to 0.5 s after the window, the bolts glow deep violet and light the floor where they land.
-- Effects off (design doc 4.37 "Boss effects have no reduced version", BOSS_EVENT_SPEC "Effects setting"): under ReduceEffects or
-- Roblox Reduced Motion nothing is drawn but the strike marks, the room is not dimmed; LastStrikes and LastImpact still log every
-- strike. The capture (BossVfx.ScrubTime, Studio only) holds the effects with Kit.hold: delays go through Kit.after.
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig")).For("boss_mage")
local Art = require(Shared:WaitForChild("BossVfxArt"))
local MageArt = require(Shared:WaitForChild("BossMageArt"))
local Event = require(Shared:WaitForChild("BossEventConfig"))
-- design doc 7: required only while her event or preview shows, so it waits for her poses alone
local Poses =
	require(Shared:WaitForChild("LateData")).Get(require(Shared:WaitForChild("BossCatalog")).Get("boss_mage").Poses)
local BossVfx = require(script.Parent:WaitForChild("BossVfx"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local Kit = BossVfx.Kit
local sequence = Kit.sequence
local FORCE = "BossVfxForce"
local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)
local VIOLET = Color3.fromRGB(176, 84, 255)
local LAVENDER = Color3.fromRGB(226, 196, 255) -- the shock ring's bright rim
-- Owner 2026-11-12 (references lightning_dim_ref_1/2; BOSS_EVENT_SPEC "Elf Mage strike lighting", proposed): deep violet, not magenta
local DEEP = Color3.fromRGB(110, 60, 210) -- the bolts' glow
local FLOOR_GLOW = Color3.fromRGB(130, 70, 255) -- the light each bolt throws on the floor
local ICE = Color3.fromRGB(205, 232, 255) -- the barrage's white
local INK, SOOT = Color3.fromRGB(16, 12, 24), Color3.fromRGB(72, 68, 80) -- the barrage's black edge and smoke, smoke's grey end
local DUST = Color3.fromRGB(196, 158, 116) -- the colosseum's ochre stone

local function eventTime(move)
	return Poses.Moves[move].Events[1].Time
end
local LIGHTNING_AT, SLAM_AT, BARRAGE_AT = eventTime("lightning"), eventTime("golem"), eventTime("barrage")
local MARK_LEAD, GATHER_FROM = 1.0, 2.0
local STRIKE_COUNT, STRIKE_EVERY = 14, 0.15 -- owner 2026-11-11: 0, 0.15, ... 1.95 s of the 2 s window
local PER_STRIKE_MIN, PER_STRIKE_MAX = 7, 10 -- bolts or beams per strike
local BARRAGE_WINDOW = Poses.Moves.barrage.Window[2] - Poses.Moves.barrage.Window[1]
local SWEEP_PUFFS = 9
local BOLT_TOP = 95 -- studs over the floor: the bolts fall from the dome
-- Owner 2026-11-12, matched to the approved lightning slices (proposed): thin jagged white-cored bolts in a soft deep violet halo,
-- with small branches, 5 to 8 segments a bolt and 2 to 4 branches.
-- Owner 2026-11-12 later (design doc 4.37 "Elf Mage target sheets"): a dark purple storm: thick white-violet bolts filling the view,
-- a few big ones a strike from far above, purple clouds lit from inside, a dark purple haze in the room (proposed).
local BOLT_SEGMENTS, BOLT_BRANCHES = { 4, 6 }, { 1, 3 }
local BOLT_JAG = 6 -- studs a bolt's kink strays sideways at most
local BOLT_CORE, BOLT_GLOW, BOLT_SECONDS = 2, 7, 0.24 -- studs across the white core and the violet halo, s they show
local BRANCH_CORE, BRANCH_LENGTH = 0.8, { 10, 26 } -- a branch's white core, studs across and long
local GLOW_TRANSPARENCY = 0.5 -- the halo: soft, the core shows through
local STORM_BOLTS, STORM_TOP, STORM_SEGMENTS = 2, 170, 7 -- big bolts a strike, from this high, segments
local STORM_CORE, STORM_GLOW, STORM_JAG = 4, 14, 14 -- their core and halo, studs across; their kinks stray this far
local CLOUDS_PER_STRIKE, CLOUD_HEIGHT = 2, { 45, 80 } -- purple clouds lit from inside, studs over the floor
local FLOOR_LIGHT, FLOOR_RANGE, FLOOR_UP = 5, 26, 4 -- a bolt's floor light: brightness, range, studs over its spot
local TIP_SEGMENTS = 4 -- the bolt from her staff's tip to each strike's first spot
local STAFF_BURST = { 12, 0.18 } -- studs across and s of the pink-white burst at her staff's tip as each strike leaves it
local PINK_WHITE = Color3.fromRGB(255, 222, 255)
-- The room dims for her strikes: from her lead-in to DIM_TAIL after the window, in over DIM_IN, back over DIM_OUT. The grade is
-- BossStrikeDim (Lighting); Lighting's brightness and ambients go to 25% through Client/BiomeEnvironment (Lighting attribute
-- BossStrikeDim, 0 to 1); the arena's own lights to TORCH_DIM. The tint is low in saturation so her white robe stays white-ish.
local DIM_IN, DIM_OUT, DIM_TAIL = 0.25, 0.6, 0.5
local DIM_GRADE = { Brightness = -0.25, Contrast = 0.08, Saturation = 0.05, TintColor = Color3.fromRGB(205, 200, 235) }
local TORCH_DIM = 0.35 -- dim, not dark red
local LIFT_SECONDS = 0.3 -- the first strike's white flash lifts the dim for this long
local HIT_FLASH, HIT_FLASH_SECONDS = 7, 0.2 -- studs across a hit's small white disc at the bolt's foot, s
local RING_FROM, RING_TO, RING_SECONDS = 4, 18, 0.36 -- studs across a hit's thin violet ring as it grows, s (pool reuse after 0.45 s)
local SPARKS_PER_HIT, SMOKE_PER_HIT = 6, 2 -- particles at each lightning spot
local BEAM_CORE, BEAM_GLOW, BEAM_EDGE, BEAM_SECONDS = 3, 5, 6.8, 0.25 -- studs across the barrage beam's layers, s
local BEAM_HEAD = 5 -- studs across the beam's rounded white head at the hit
local CYAN = Color3.fromRGB(150, 225, 255) -- the beams' rims
local BEAM_SPARKS, BEAM_SMOKE = 4, 2 -- particles at each barrage hit
local CIRCLES = 10
-- Owner 2026-11-12 after playing (BOSS_EVENT_SPEC "Pose-tied effect values", proposed): 10, much bigger, one by one 0.15 s apart
-- from 0.2 s, all open before the beams at 2.0 s: the tenth opens at 0.2 + 9 x 0.15 = 1.55 s and is full by 1.75 s.
local CIRCLE_SMALL, CIRCLE_LARGE = 30, 70 -- studs across, the first and the last circle: small to large
local CIRCLE_FROM, CIRCLE_EVERY = 0.2, 0.15 -- s of barrage the first circle opens, s between two
local CIRCLE_OPEN = 0.2 -- s a circle takes to open (Quad, no overshoot)
-- Matched to the approved barrage slices: a loose cluster in front of the staff's tip along its aim, 1 to 1.5 staff lengths out,
-- facing the shot, turning with the staff, soft cyan-white, brightening to full by key 5 (1.85 s).
local CIRCLE_TINT = Color3.fromRGB(205, 240, 255)
local CIRCLE_BRIGHT_AT = 1.85 -- s of barrage
local CIRCLE_LIGHT = { Color3.fromRGB(170, 230, 255), 2, 40 } -- each circle's light: colour, brightness when full, range
-- circle k's place in the cluster: { staff lengths past the tip, sideways and up as a fraction of its size }
-- (owner 2026-11-12, target sheets: pulled in to 1 to 1.5 staff lengths)
local CIRCLE_CLUSTER = {
	{ 1.0, 0, 0 },
	{ 1.05, 0.35, 0.2 },
	{ 1.1, -0.3, 0.3 },
	{ 1.15, 0.1, -0.35 },
	{ 1.2, -0.35, -0.2 },
	{ 1.25, 0.4, -0.1 },
	{ 1.3, -0.15, 0.4 },
	{ 1.35, 0.3, 0.35 },
	{ 1.42, -0.4, 0.05 },
	{ 1.5, 0.05, -0.4 },
}
local CHARGE_FROM = 0.6 -- s of lightning: the staff tip's charge from here to the strike (proposed)
local CHARGE_RAYS, CHARGE_FLARE = { 8, 30 }, { 6, 18 } -- studs: the starburst's ray length and flare size, from to at the strike
local SWEEP_AT = Poses.GolemMoves.golem_sweep.Events[1].Time
local SWEEP_DUST = { SWEEP_AT - 0.4, SWEEP_AT + 0.4 } -- s of golem_sweep over which the puffs follow the fist (proposed)
local RISE_DUST_AT, FALL_DUST_AT = 0.75, 0.55 -- s of golem (its scale starts growing) and of golem_fall (it sinks) (proposed)
local SPOT_MAX = Arena.WallRadius - 4 -- the whole room: centre, lanes and walkway
local SALT = { Lightning = 1, Barrage = 2 }
local STAFF_TIP = Vector3.new(Poses.Bind.Staff.Tip[1], Poses.Bind.Staff.Tip[2], Poses.Bind.Staff.Tip[3])
-- The staff's Trail while it swings (BOSS_EVENT_SPEC "Impact layer"): s of her move about its strike event (proposed)
local STAFF_SWING = {
	lightning = { LIGHTNING_AT - 0.6, LIGHTNING_AT + 0.4 },
	barrage = { BARRAGE_AT - 0.6, BARRAGE_AT + 0.4 },
}
-- The hit particles, one emitter each on one spot moved to every hit (no instance per hit). Placeholders.
local HIT_LOOKS = {
	Sparks = { -- lightning: white-violet sparks thrown off the hit
		Name = "Sparks",
		Texture = Art.Spark,
		Color = ColorSequence.new(WHITE, VIOLET),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(80, 80),
		Size = sequence(0, 2.4, 1, 0),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(50, 110),
		Drag = 3,
		Acceleration = Vector3.new(0, -80, 0),
	},
	StormCloud = { -- lightning: a big purple cloud lit from inside, drifting dark
		Name = "StormCloud",
		Texture = Art.Dust,
		Color = ColorSequence.new(Color3.fromRGB(150, 90, 255), Color3.fromRGB(30, 15, 55)),
		LightEmission = 0.35,
		Size = sequence(0, 40, 1, 85),
		Transparency = sequence(0, 0.4, 0.5, 0.6, 1, 1),
		Lifetime = NumberRange.new(1.4, 2.2),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-15, 15),
	},
	StrikeSmoke = { -- lightning: purple smoke lit from inside, settling grey (clip 3)
		Name = "StrikeSmoke",
		Texture = Art.Dust,
		Color = ColorSequence.new(VIOLET, SOOT),
		LightEmission = 0.5,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(70, 70),
		Size = sequence(0, 7, 1, 18),
		Transparency = sequence(0, 0.35, 1, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(6, 14),
		Drag = 1.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	},
	BarrageSparks = { -- barrage: white bursts at the hit
		Name = "BarrageSparks",
		Texture = Art.Spark,
		Color = ColorSequence.new(WHITE, ICE),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(80, 80),
		Size = sequence(0, 2.2, 1, 0),
		Lifetime = NumberRange.new(0.25, 0.5),
		Speed = NumberRange.new(40, 90),
		Drag = 3,
	},
	BarrageSmoke = { -- barrage: black smoke at the hit, thinning to grey (owner: add black)
		Name = "BarrageSmoke",
		Texture = Art.Dust,
		Color = ColorSequence.new(INK, SOOT),
		LightInfluence = 0.3,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(60, 60),
		Size = sequence(0, 3, 1, 8), -- small (pairs 2026-11-12)
		Transparency = sequence(0, 0.25, 1, 1),
		Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(6, 16),
		Drag = 1.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	},
}

local BossMageVfx = {}

local effects, mage = nil, nil
local tracked = {} -- part -> function giving its CFrame each frame
local circles = {} -- the barrage's open circles, its beams' origins
local pools = {} -- name -> idle pooled parts of that name's look (Transparency 1) in this arena's folder
local hitSpot, hitEmitters = nil, {} -- the one spot the hit particles come from, its emitters by name
local lightPool = {} -- idle floor lights (holder parts with a disabled PointLight)
local dim = nil -- the room's dim while it runs: { Born, EndAt, Grade, Lights = { light -> its brightness } }
local generation = 0 -- bumped by clear(): a `later` of an earlier start draws nothing
local previousMove, previousTime = nil, nil
local previousGolem, previousGolemTime = nil, nil
local staff = nil -- her Staff part, found by name (the rig is built late)
local charge, chargeLight = nil, nil -- the lightning's StaffCharge while it shows
local chargeRays, chargeFlare = {}, nil -- its starburst: two rays facing the camera and a flare

local function reduced()
	return UiMotion.Reduced()
end

-- The same generator on every client for one move of one cycle: the schedule start and the cycle number, both from server time.
local function rngFor(name)
	local start = ReplicatedStorage:GetAttribute("BossScheduleStart") or 0
	local cycle = math.floor((Workspace:GetServerTimeNow() - start - Event.IntroSeconds) / Poses.CycleSeconds)
	local rng = Random.new((math.floor(start) % 1000000) * 31 + (cycle % 100000) * 7919 + SALT[name] * 104729)
	rng:NextNumber() -- as BossDodge.Spot
	return rng
end

-- The move's strikes: { T, Spots } for each of the 14, T seconds after the window starts, the same with effects on or off.
-- Every strike takes all its draws. Spots are area-uniform over the room's floor.
local function plan(name)
	local rng, list = rngFor(name), {}
	for j = 1, STRIKE_COUNT do
		local n = rng:NextInteger(PER_STRIKE_MIN, PER_STRIKE_MAX)
		local spots = {}
		for k = 1, PER_STRIKE_MAX do
			local a, r = rng:NextNumber(0, 2 * math.pi), SPOT_MAX * math.sqrt(rng:NextNumber())
			if k <= n then
				spots[k] =
					Vector3.new(Arena.Center.X + r * math.cos(a), Arena.Y + 0.15, Arena.Center.Z - r * math.sin(a))
			end
		end
		list[j] = { T = STRIKE_EVERY * (j - 1), Spots = spots }
	end
	return list, rng
end

local function logStrikes(name, list)
	local rows = {}
	for j, strike in list do
		local spots = {}
		for k, at in strike.Spots do
			spots[k] = { math.floor(at.X * 10 + 0.5) / 10, math.floor(at.Z * 10 + 0.5) / 10 }
		end
		rows[j] = { T = strike.T, Spots = spots }
	end
	effects:SetAttribute("LastStrikes", HttpService:JSONEncode({ Move = name, Strikes = rows }))
end

-- A Neon part of `name` from its pool (or a new one, shaped by `make`), back to the pool `seconds` later; its decals fade with
-- it. Parts the folder lost are dropped.
local function pooled(name, cframe, size, color, transparency, seconds, make)
	local idle = pools[name]
	local part = idle and table.remove(idle)
	while part and part.Parent ~= effects do
		part = table.remove(idle)
	end
	if part then
		part.CFrame, part.Size = cframe, size
	else
		part = Kit.holder(name, cframe, size)
		part.Material = NEON
		if make then
			make(part)
		end
	end
	part.Name, part.Color, part.Transparency = name, color, transparency
	Kit.tween(part, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, d in part:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = 0
			Kit.tween(d, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end
	Kit.after(seconds + 0.03, function()
		if part.Parent == effects then
			part.Name, part.Transparency = "Pooled", 1
			pools[name] = pools[name] or {}
			table.insert(pools[name], part)
		end
	end)
	return part
end

-- Plays `play` seconds from now while this arena's effects last, adding its particles to the event's count.
local function later(seconds, play)
	local mine, run = effects, generation
	Kit.after(seconds, function()
		if mine and effects == mine and generation == run then
			mine:SetAttribute("LastParticles", (mine:GetAttribute("LastParticles") or 0) + play())
		end
	end)
end

-- Effects off: each strike's hit is still logged in LastImpact (Flash "None", Kick 0), nothing is drawn.
local function logHits(move, list, full, roughness)
	for _, strike in list do
		later(strike.T, function()
			Kit.impact(move, Arena.Center, full, roughness, 0.15, strike.T)
			return 0
		end)
	end
	return 0
end

-- A glowing stick from a to b: a Neon core inside a wider, softer Neon sheath, both fading out.
local function streak(name, a, b, core, sheath, coreColor, sheathColor, seconds, sheathTransparency)
	local frame, length = CFrame.lookAt((a + b) / 2, b), (b - a).Magnitude
	pooled(
		name,
		frame,
		Vector3.new(sheath, sheath, length + sheath * 0.5),
		sheathColor,
		sheathTransparency or 0.35,
		seconds
	)
	pooled(name .. "Core", frame, Vector3.new(core, core, length + core), coreColor, 0, seconds)
	return frame, length
end

local function ballLook(part)
	part.Shape = Enum.PartType.Ball
end

local function disc(part)
	part.Shape = Enum.PartType.Cylinder
end

-- A flat glowing white disc where a bolt or beam lands.
local function flash(at, size, seconds)
	pooled(
		"StrikeFlash",
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.2, size, size),
		WHITE,
		0,
		seconds,
		disc
	)
end

-- `count` particles of HIT_LOOKS[name] at `at`, from the one hit spot.
local function emitAt(name, at, count)
	if not (hitSpot and hitSpot.Parent == effects) then
		hitSpot = Kit.holder("HitSpot", CFrame.new(at), Vector3.new(4, 1, 4))
		table.clear(hitEmitters)
	end
	local e = hitEmitters[name]
	if not e then
		e = Kit.emitter(hitSpot, HIT_LOOKS[name])
		hitEmitters[name] = e
	end
	hitSpot.CFrame = CFrame.new(at)
	e:Emit(count)
	return count
end

-- A violet light on the floor at a bolt's spot for `seconds`, from a pool (one per spot).
local function floorLight(at, seconds)
	local part = table.remove(lightPool)
	while part and part.Parent ~= effects do
		part = table.remove(lightPool)
	end
	local light = part and part:FindFirstChildOfClass("PointLight")
	if not light then
		part = Kit.holder("BoltLight", CFrame.new(), Vector3.one)
		light = Instance.new("PointLight")
		light.Color, light.Range, light.Shadows = FLOOR_GLOW, FLOOR_RANGE, false
		light.Parent = part
	end
	part.CFrame = CFrame.new(at + Vector3.new(0, FLOOR_UP, 0))
	light.Enabled, light.Brightness = true, FLOOR_LIGHT
	Kit.tween(light, seconds, { Brightness = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Kit.after(seconds + 0.03, function()
		if part.Parent == effects then
			light.Enabled = false
			table.insert(lightPool, part)
		end
	end)
end

-- The room's dim ---------------------------------------------------------------------------------------------------------------

-- Starts the dim, to end `endIn` s from now plus its fade. A running dim keeps going; an event (the window's start) sets its end.
-- haze: her lightning's dark purple haze too (Client/BiomeEnvironment, Lighting attribute BossStrikeHaze).
local function startDim(endIn, event, haze)
	if reduced() or not (effects and effects.Parent) then
		return
	end
	local now = os.clock()
	if dim then
		if event then
			dim.EndAt = now + endIn
		end
		return
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "BossStrikeDim"
	grade.Parent = Lighting
	local lights = {}
	for _, d in effects.Parent:GetDescendants() do
		if d:IsA("Light") and not d:IsDescendantOf(effects) then
			lights[d] = d:GetAttribute("ImpactBase") or d.Brightness -- a light mid-pulse: its own brightness
		end
	end
	dim = { Born = now, EndAt = now + endIn, Grade = grade, Lights = lights, Haze = haze }
end

-- The room exactly as it was: the grade gone, the profile's lighting (Client/BiomeEnvironment), the arena's lights.
local function endDim()
	if not dim then
		return
	end
	dim.Grade:Destroy()
	Lighting:SetAttribute("BossStrikeDim", nil)
	Lighting:SetAttribute("BossStrikeHaze", nil)
	for light, base in dim.Lights do
		if light.Parent then
			light.Brightness = base
			if light:GetAttribute("ImpactBase") ~= nil then -- an impact pulse still running: set again after it
				task.delay(0.3, function()
					light.Brightness = base
				end)
			end
		end
	end
	dim = nil
end

-- The first strike's white flash: the dim lifts for LIFT_SECONDS and settles back.
local function liftDim()
	if dim then
		dim.LiftAt = os.clock()
	end
end

local function stepDim()
	if not dim then
		return
	end
	local now = os.clock()
	local f = math.min((now - dim.Born) / DIM_IN, 1)
	if now > dim.EndAt then
		f = math.min(f, 1 - (now - dim.EndAt) / DIM_OUT)
	end
	if f <= 0 or reduced() then
		endDim()
		return
	end
	f = f * f * (3 - 2 * f)
	if dim.LiftAt then
		f *= math.clamp((os.clock() - dim.LiftAt) / LIFT_SECONDS, 0, 1)
	end
	local grade = dim.Grade
	grade.Brightness, grade.Contrast = DIM_GRADE.Brightness * f, DIM_GRADE.Contrast * f
	grade.Saturation, grade.TintColor = DIM_GRADE.Saturation * f, WHITE:Lerp(DIM_GRADE.TintColor, f)
	Lighting:SetAttribute("BossStrikeDim", f)
	Lighting:SetAttribute("BossStrikeHaze", dim.Haze and f or nil)
	for light, base in dim.Lights do
		if light.Parent and light:GetAttribute("ImpactBase") == nil then -- an impact pulse owns it until it ends
			light.Brightness = base * (1 - (1 - TORCH_DIM) * f)
		end
	end
end

-- A short flash of light for the room: few lights, so the interior stays cheap at quality 1.
local function roomLight(position, color, brightness, seconds)
	local spot = Kit.holder("FlashLight", CFrame.new(position))
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = color, brightness, 60, false
	light.Parent = spot
	Kit.tween(light, seconds, { Brightness = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Kit.expire(spot, seconds + 0.05)
end

-- Lightning --------------------------------------------------------------------------------------------------------------------

-- 1.0 s ahead of each bolt: a pale ring closing in on its spot (one part each: there are up to 140). Shown with effects off too:
-- the marks are the telegraph. Pale and faint, so they read under the dim without crowding the floor.
local MARK_COLOR, MARK_TRANSPARENCY = Color3.fromRGB(205, 190, 255), 0.45
local function playMarks()
	startDim(Poses.Moves.lightning.Window[2] - (LIGHTNING_AT - MARK_LEAD) + DIM_TAIL, false, true)
	for _, strike in plan("Lightning") do
		local lead = MARK_LEAD + strike.T
		for _, at in strike.Spots do
			local rim = Kit.holder("StrikeMark", CFrame.new(at), Vector3.new(16, 0.2, 16))
			Kit.decal(rim, Art.Ring, MARK_COLOR, Enum.NormalId.Top, MARK_TRANSPARENCY)
			Kit.tween(rim, lead, { Size = Vector3.new(7, 0.2, 7) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Kit.expire(rim, lead + 0.15)
		end
	end
	return 0
end

-- The shock ring's look: a thin ring on the floor (the decal); its part is a near-clear violet carrier, so no disc shows.
local function shockLook(part)
	part.Material = Enum.Material.SmoothPlastic
	Kit.decal(part, Art.Ring, LAVENDER, Enum.NormalId.Top)
end

-- A round segment from a to b (a cylinder along the line): the bolts' cores and halos.
local function rod(part)
	part.Shape = Enum.PartType.Cylinder
end
local ALONG = CFrame.Angles(0, math.pi / 2, 0) -- a cylinder's axis (X) along a lookAt frame's Z
local function segment(name, a, b, width, color, transparency)
	local length = (b - a).Magnitude
	pooled(
		name,
		CFrame.lookAt((a + b) / 2, b) * ALONG,
		Vector3.new(length + width * 0.5, width, width),
		color,
		transparency,
		BOLT_SECONDS,
		rod
	)
end

-- A jagged bolt through `points`: a white core in a soft deep violet halo on each segment.
local function bolt(points, core, glow)
	for i = 1, #points - 1 do
		segment("Bolt", points[i], points[i + 1], glow or BOLT_GLOW, DEEP, GLOW_TRANSPARENCY)
		segment("BoltCore", points[i], points[i + 1], core or BOLT_CORE, WHITE, 0)
	end
end

-- From `from` to `to` in `count` segments, each kink strayed sideways by a draw of `rng` (up to `jag` studs, less near the ends).
local function jagged(rng, from, to, count, jag)
	local points = { from }
	for i = 1, count - 1 do
		local u = i / count
		local stray = jag * math.sin(math.pi * u)
		table.insert(
			points,
			from:Lerp(to, u) + Vector3.new(rng:NextNumber(-stray, stray), 0, rng:NextNumber(-stray, stray))
		)
	end
	table.insert(points, to)
	return points
end

-- One bolt's hit: a small white disc at its foot, a thin violet ring racing out, sparks, lit purple smoke and a violet light on the
-- floor.
local function boltHit(at)
	flash(at, HIT_FLASH, HIT_FLASH_SECONDS)
	floorLight(at, 0.3)
	local ring = pooled(
		"ShockRing",
		CFrame.new(at + Vector3.new(0, 0.25, 0)),
		Vector3.new(RING_FROM, 0.2, RING_FROM),
		VIOLET,
		0.92,
		RING_SECONDS,
		shockLook
	)
	Kit.tween(ring, RING_SECONDS, { Size = Vector3.new(RING_TO, 0.2, RING_TO) }, Enum.EasingStyle.Quart)
	return emitAt("Sparks", at, SPARKS_PER_HIT) + emitAt("StrikeSmoke", at + Vector3.new(0, 2, 0), SMOKE_PER_HIT)
end

-- A strike leaving her staff: a pink-white burst at its tip and sparks (the slices show each strike from the staff).
local function staffBurst(tip)
	local burst =
		pooled("StaffBurst", CFrame.new(tip), Vector3.one * STAFF_BURST[1], PINK_WHITE, 0, STAFF_BURST[2], ballLook)
	Kit.tween(burst, STAFF_BURST[2], { Size = Vector3.one * STAFF_BURST[1] * 0.4 })
	return emitAt("Sparks", tip, SPARKS_PER_HIT)
end

local function playLightning()
	-- cue: MageLightning (a crack of thunder)
	local list, rng = plan("Lightning")
	logStrikes("Lightning", list)
	if reduced() then
		return logHits("Lightning", list, 0.12, 20)
	end
	startDim(Poses.Moves.lightning.Window[2] - LIGHTNING_AT + DIM_TAIL, true, true)
	for j, strike in list do
		local bolts = {}
		for k, at in strike.Spots do
			local top = at + Vector3.new(rng:NextNumber(-10, 10), BOLT_TOP, rng:NextNumber(-10, 10))
			local points = jagged(rng, top, at, rng:NextInteger(BOLT_SEGMENTS[1], BOLT_SEGMENTS[2]), BOLT_JAG)
			local branches = {}
			for _ = 1, rng:NextInteger(BOLT_BRANCHES[1], BOLT_BRANCHES[2]) do
				local from = points[rng:NextInteger(2, #points - 1)]
				local out = Vector3.new(rng:NextNumber(-1, 1), -rng:NextNumber(0.6, 1.4), rng:NextNumber(-1, 1)).Unit
				table.insert(branches, { from, from + out * rng:NextNumber(BRANCH_LENGTH[1], BRANCH_LENGTH[2]) })
			end
			bolts[k] = { Points = points, Branches = branches }
		end
		local tipRng = Random.new(j) -- the staff bolt's kinks: fixed per strike, its ends live
		local storms = {}
		for b = 1, STORM_BOLTS do
			local at = strike.Spots[(b - 1) * 3 % #strike.Spots + 1]
			local top = at + Vector3.new(rng:NextNumber(-30, 30), STORM_TOP, rng:NextNumber(-30, 30))
			storms[b] = jagged(rng, top, at, STORM_SEGMENTS, STORM_JAG)
		end
		local clouds = {}
		for c = 1, CLOUDS_PER_STRIKE do
			local at = strike.Spots[(c * 2 - 1) % #strike.Spots + 1]
			clouds[c] = at + Vector3.new(0, rng:NextNumber(CLOUD_HEIGHT[1], CLOUD_HEIGHT[2]), 0)
		end
		later(strike.T, function()
			local total = 0
			for _, points in storms do
				bolt(points, STORM_CORE, STORM_GLOW)
			end
			for _, at in clouds do
				total += emitAt("StormCloud", at, 1)
			end
			for _, row in bolts do
				bolt(row.Points)
				for _, branch in row.Branches do
					segment("BoltCore", branch[1], branch[2], BRANCH_CORE, WHITE, 0)
				end
				total += boltHit(row.Points[#row.Points])
			end
			local tip = mage:Point("Staff", STAFF_TIP)
			bolt(jagged(tipRng, tip, strike.Spots[1], TIP_SEGMENTS, BOLT_JAG))
			total += staffBurst(tip)
			roomLight(Vector3.new(Arena.Center.X, Arena.Y + 50, Arena.Center.Z), DEEP, 3.5, 0.2)
			if strike.T == 0 then -- the first strike flashes the whole room white (the slices' key 6)
				liftDim()
			end
			Kit.impact("Lightning", Arena.Center, 0.12, 20, 0.15, strike.T, true)
			return total
		end)
	end
	return 0
end

-- Golem --------------------------------------------------------------------------------------------------------------------------

-- From 2.0 s of the move: violet motes drawn into the golem's chest through its wind-up.
local function playGather()
	if reduced() then
		return 0
	end
	local function chest()
		return mage:GolemFrame("Torso")
	end
	local part = Kit.holder("GolemGather", chest(), Vector3.new(70, 70, 70))
	tracked[part] = chest
	local rate = 22
	local motes = Kit.emitter(part, {
		Name = "Motes",
		Texture = Art.Spark,
		Color = ColorSequence.new(WHITE, VIOLET),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Size = sequence(0, 0.6, 0.5, 2, 1, 0.4),
		Lifetime = NumberRange.new(0.45, 0.6),
		Speed = NumberRange.new(55, 70),
		Rate = rate,
		Enabled = true,
	})
	local seconds = SLAM_AT - GATHER_FROM
	Kit.after(seconds, function()
		motes.Enabled = false
	end)
	Kit.expire(part, seconds + 0.7)
	return math.ceil(rate * seconds)
end

local function playSlam()
	-- cue: GolemSlam (a deep thud)
	local fist = mage:GolemFrame("FistR").Position:Lerp(mage:GolemFrame("FistL").Position, 0.5)
	local at = Vector3.new(fist.X, Arena.Y + 0.3, fist.Z)
	if reduced() then -- effects off: the hit logged only
		Kit.impact("Slam", at, 1.6, 20, 0.5)
		return 0
	end
	-- Across the lanes: from the golem's spot to past the ring's far side
	local reach = 2 * (Arena.InnerRadius + Arena.Width + ((at - Arena.Center) * Vector3.new(1, 0, 1)).Magnitude)
	Kit.growingRing("SlamRing", CFrame.new(at), 12, reach, 0.9, WHITE, 0, Kit.FlatFaces)
	local total = 0
	Kit.growingRing("SlamDust", CFrame.new(at), 20, reach * 0.55, 1.4, DUST, 0.05, Kit.FlatFaces)
	local spot = Kit.holder("SlamSpot", CFrame.new(at), Vector3.new(40, 1, 40))
	Kit.expire(spot, 3)
	total += Kit.burst(
		Kit.emitter(spot, {
			Name = "Dust",
			Texture = Art.Dust,
			Color = ColorSequence.new(DUST),
			LightInfluence = 0.6,
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(75, 75),
			Size = sequence(0, 8, 0.4, 18, 1, 24),
			Transparency = sequence(0, 0.2, 0.6, 0.45, 1, 1),
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(40, 90),
			Drag = 2,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
		}),
		28
	)
	total += Kit.burst(
		Kit.emitter(spot, {
			Name = "Debris",
			Texture = Art.Shard,
			Color = ColorSequence.new(DUST),
			LightInfluence = 0.8,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(55, 55),
			Size = sequence(0, 3, 1, 2),
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(50, 110),
			Acceleration = Vector3.new(0, -160, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-300, 300),
		}),
		14,
		0.03
	)
	Kit.impact("Slam", at, 1.6, 20, 0.5)
	return total
end

-- Dust on the floor under the golem: a ring and a burst (its rise and its fall). None with effects off.
local function groundDust(name)
	if reduced() then
		return 0
	end
	local torso = mage:GolemFrame("Torso").Position
	local at = Vector3.new(torso.X, Arena.Y + 0.3, torso.Z)
	Kit.growingRing(name, CFrame.new(at), 14, 70, 1.2, DUST, 0, Kit.FlatFaces)
	local spot = Kit.holder(name, CFrame.new(at), Vector3.new(36, 1, 36))
	Kit.expire(spot, 2.2)
	return Kit.burst(
		Kit.emitter(spot, {
			Name = "Dust",
			Texture = Art.Dust,
			Color = ColorSequence.new(DUST),
			LightInfluence = 0.6,
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(70, 70),
			Size = sequence(0, 7, 0.4, 15, 1, 20),
			Transparency = sequence(0, 0.25, 0.6, 0.5, 1, 1),
			Lifetime = NumberRange.new(0.9, 1.5),
			Speed = NumberRange.new(25, 60),
			Drag = 2,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
		}),
		18
	)
end

local function playRiseDust()
	return groundDust("GolemRiseDust")
end

local function playFallDust()
	return groundDust("GolemFallDust")
end

-- The sweep's puff i of SWEEP_PUFFS (none with effects off), on the floor under the golem's lower fist now.
local FIST_L = Vector3.new(table.unpack(Poses.GolemBind.FistL.Center))
local FIST_R = Vector3.new(table.unpack(Poses.GolemBind.FistR.Center))
local function playPuff()
	if reduced() then
		return 0
	end
	local left, right = mage.Golem:Point("FistL", FIST_L), mage.Golem:Point("FistR", FIST_R)
	local fist = left.Y < right.Y and left or right
	local at = Vector3.new(fist.X, Arena.Y + 0.3, fist.Z)
	Kit.expire(Kit.holder("SweepDust", CFrame.new(at), Vector3.new(14, 1, 14)), 1.2)
	Kit.growingRing("SweepDust", CFrame.new(at), 6, 22, 0.9, DUST, 0, Kit.FlatFaces)
	return 0
end

-- The puffs' times in golem_sweep, one row each.
local SWEEP_ROWS = {}
for i = 1, SWEEP_PUFFS do
	SWEEP_ROWS[i] = {
		SWEEP_DUST[1] + (SWEEP_DUST[2] - SWEEP_DUST[1]) * (i - 1) / (SWEEP_PUFFS - 1),
		playPuff,
	}
end

-- The sweep's hit (its dust is SWEEP_ROWS, from the fist).
local function playSweep()
	-- cue: GolemSweep (a grinding rush)
	Kit.impact("Sweep", Arena.Center, 1.2, 20, 0.5)
	return 0
end

-- BossVfxForce "Sweep": the puffs from now, as the track would play them.
local function playSweepDust()
	for _, row in SWEEP_ROWS do
		later(row[1] - SWEEP_DUST[1], row[2])
	end
	return 0
end

-- Barrage ------------------------------------------------------------------------------------------------------------------------

-- From CIRCLE_FROM, held over the window: circle k of the barrage opens CIRCLE_EVERY after the one before, in a loose cluster in front
-- of the staff's tip along its pointing (grip to tip), 1 to 3 staff lengths out, facing along it and turning with the staff, small to
-- large, soft cyan-white with a bright rim and its own light, brightening to full by CIRCLE_BRIGHT_AT; a white pop as it opens.
local function circleFrame(k, size, born)
	local place, turn = CIRCLE_CLUSTER[k], (k % 2 == 0 and 1 or -1) * math.rad(90)
	return function()
		local grip, tip = mage:Point("Staff", Vector3.zero), mage:Point("Staff", STAFF_TIP)
		local reach = (tip - grip).Magnitude
		local aim = reach > 0.01 and (tip - grip) / reach or Vector3.new(0, 0, -1)
		local ref = math.abs(aim.Y) < 0.95 and Vector3.yAxis or Vector3.xAxis
		local right = aim:Cross(ref).Unit
		local up = right:Cross(aim)
		local center = tip + aim * math.max(reach, 12) * place[1] + (right * place[2] + up * place[3]) * size
		return CFrame.lookAt(center, center + aim) * CFrame.Angles(0, 0, turn * (os.clock() - born))
	end
end

local function playCircle(k)
	if k > CIRCLES or reduced() then
		return 0
	end
	if k == 1 then
		table.clear(circles)
		startDim(Poses.Moves.barrage.Window[2] - CIRCLE_FROM + DIM_TAIL)
	end
	local size = CIRCLE_SMALL + (CIRCLE_LARGE - CIRCLE_SMALL) * (k - 1) / (CIRCLES - 1)
	local frame = circleFrame(k, size, os.clock())
	local part = Kit.holder("MagicCircle", frame(), Vector3.new(1, 1, 0.2))
	tracked[part] = frame
	local opensAt = CIRCLE_FROM + (k - 1) * CIRCLE_EVERY
	local brighten = math.max(0.15, CIRCLE_BRIGHT_AT - opensAt)
	local faces = {}
	for _, face in Kit.UprightFaces do
		table.insert(faces, Kit.decal(part, MageArt.MagicCircle, CIRCLE_TINT, face, 0.6))
		table.insert(faces, Kit.decal(part, Art.Ring, WHITE, face, 0.6)) -- the bright rim
	end
	for _, d in faces do
		Kit.tween(d, brighten, { Transparency = 0 })
	end
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = CIRCLE_LIGHT[1], 0, CIRCLE_LIGHT[3], false
	light.Parent = part
	Kit.tween(light, brighten, { Brightness = CIRCLE_LIGHT[2] })
	Kit.tween(part, CIRCLE_OPEN, { Size = Vector3.new(size, size, 0.2) })
	local pop = pooled("CirclePop", frame(), Vector3.one * 4, WHITE, 0, 0.25, ballLook) -- the white burst as it opens
	Kit.tween(pop, 0.25, { Size = Vector3.one * size * 0.3 })
	local hold = BARRAGE_AT - opensAt + BARRAGE_WINDOW
	Kit.after(hold + 0.25, function()
		for _, d in faces do
			Kit.tween(d, 0.3, { Transparency = 1 })
		end
		Kit.tween(light, 0.3, { Brightness = 0 })
	end)
	Kit.expire(part, hold + 0.6)
	table.insert(circles, part)
	return 0
end

-- BossVfxForce "Barrage": the circles from now, one after another at the same spacing (its beams start at once).
local function playCircles()
	for k = 1, CIRCLES do
		later((k - 1) * CIRCLE_EVERY, function()
			return playCircle(k)
		end)
	end
	return 0
end

-- The edge's look: dark, not glowing.
local function edgeLook(part)
	part.Material = Enum.Material.SmoothPlastic
end

-- One beam out of a circle's centre (her staff's tip with no circle open) to its strike's planned spot on the floor, so the
-- beams fan out from the cluster onto the logged spots (owner 2026-11-12, target sheets): a white-hot core in a cyan rim inside a
-- near-black edge, a rounded white head, and at the spot a white flash, white sparks and small black smoke.
local function beam(circle, target, k)
	local from = circle and circle.Position or mage:Point("Staff", STAFF_TIP)
	local frame, length =
		streak("BarrageBeam", from, target, BEAM_CORE, BEAM_GLOW, WHITE, k % 2 == 0 and CYAN or ICE, BEAM_SECONDS)
	pooled("BarrageBeamEdge", frame, Vector3.new(BEAM_EDGE, BEAM_EDGE, length), INK, 0.75, BEAM_SECONDS, edgeLook)
	pooled("BarrageBeamHead", CFrame.new(target), Vector3.one * BEAM_HEAD, WHITE, 0, BEAM_SECONDS, ballLook)
	flash(target, 10, 0.25)
	return emitAt("BarrageSparks", target, BEAM_SPARKS)
		+ emitAt("BarrageSmoke", target + Vector3.new(0, 1, 0), BEAM_SMOKE)
end

local function playBarrage()
	-- cue: MageBarrage (a volley of zaps)
	local list = plan("Barrage")
	logStrikes("Barrage", list)
	if reduced() then
		return logHits("Barrage", list, 0.1, 18)
	end
	startDim(Poses.Moves.barrage.Window[2] - BARRAGE_AT + DIM_TAIL, true)
	for j, strike in list do
		later(strike.T, function()
			local total = 0
			for k, target in strike.Spots do
				local circle = #circles > 0 and circles[(j + k - 2) % #circles + 1]
				total += beam(circle and circle.Parent and circle, target, k)
			end
			roomLight(mage.Her.Anchor.Position + Vector3.new(0, 30, 0), ICE, 3, 0.2)
			if strike.T == 0 then -- the first strike flashes the whole room white (the slices' key 6)
				liftDim()
			end
			Kit.impact("Barrage", Arena.Center, 0.1, 18, 0.15, strike.T, true)
			return total
		end)
	end
	return 0
end

-- The staff's trail: on inside STAFF_SWING, off otherwise and with effects off.
local function stepStaffTrail(move, localTime)
	local swing = STAFF_SWING[move]
	local on = swing and localTime >= swing[1] and localTime <= swing[2] and not reduced()
	if on and not (staff and staff.Parent) then
		local model = mage.Her and mage.Her.Model
		staff = model and model:FindFirstChild("Staff", true)
	end
	if staff and staff.Parent then
		Kit.swingTrail(staff, on and mage:Point("Staff", STAFF_TIP), ICE, VIOLET)
	end
end

-- The lightning's charge: a bright point at the staff's tip from CHARGE_FROM to the strike, growing. One part while it shows.
local function stepStaffCharge(move, localTime)
	local on = move == "lightning" and localTime >= CHARGE_FROM and localTime < LIGHTNING_AT and not reduced()
	if not on then
		if charge then
			charge:Destroy()
			charge, chargeLight, chargeFlare = nil, nil, nil
		end
		return
	end
	if not (charge and charge.Parent == effects) then
		charge = Kit.holder("StaffCharge", CFrame.new(), Vector3.one)
		charge.Shape, charge.Material, charge.Color, charge.Transparency = Enum.PartType.Ball, NEON, WHITE, 0.05
		chargeLight = Instance.new("PointLight")
		chargeLight.Color, chargeLight.Range, chargeLight.Shadows = VIOLET, 24, false
		chargeLight.Parent = charge
		for k = 1, 2 do
			local ray = Kit.holder("StaffChargeRay", CFrame.new(), Vector3.one)
			ray.Material, ray.Color, ray.Transparency = NEON, WHITE, 0
			ray.Parent = charge
			chargeRays[k] = ray
		end
		chargeFlare = Kit.emitter(charge, {
			Name = "ChargeFlare",
			Texture = Art.Flare,
			Color = ColorSequence.new(WHITE, PINK_WHITE),
			LightEmission = 1,
			LockedToPart = true,
			Speed = NumberRange.new(0),
			Lifetime = NumberRange.new(0.08, 0.12),
			Rotation = NumberRange.new(0, 360),
			Rate = 40,
			Enabled = true,
		})
	end
	-- the slices' keys 3 and 4: a large white starburst at the tip, growing to the strike
	local u = (localTime - CHARGE_FROM) / (LIGHTNING_AT - CHARGE_FROM)
	local tip = mage:Point("Staff", STAFF_TIP)
	charge.CFrame = CFrame.new(tip)
	charge.Size = Vector3.one * (1.5 + 3.5 * u)
	chargeLight.Brightness = 1 + 3 * u
	local camera = Workspace.CurrentCamera
	local facing = camera and CFrame.lookAt(tip, camera.CFrame.Position) or CFrame.new(tip)
	local reach = CHARGE_RAYS[1] + (CHARGE_RAYS[2] - CHARGE_RAYS[1]) * u
	chargeRays[1].CFrame, chargeRays[1].Size = facing, Vector3.new(reach, 0.25, 0.1)
	chargeRays[2].CFrame, chargeRays[2].Size =
		facing * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(reach * 0.8, 0.25, 0.1)
	chargeFlare.Size = NumberSequence.new(CHARGE_FLARE[1] + (CHARGE_FLARE[2] - CHARGE_FLARE[1]) * u)
end

-- Runs ---------------------------------------------------------------------------------------------------------------------------

local EVENTS = { Lightning = playLightning, Slam = playSlam, Sweep = playSweep, Barrage = playBarrage }
local LEADS = { Lightning = playMarks, Slam = playGather, Sweep = playSweepDust, Barrage = playCircles }
local CIRCLE_ROWS = {}
for k = 1, CIRCLES do
	CIRCLE_ROWS[k] = {
		CIRCLE_FROM + (k - 1) * CIRCLE_EVERY,
		function()
			return playCircle(k)
		end,
	}
end
local TIMED = {
	lightning = { { LIGHTNING_AT - MARK_LEAD, playMarks } },
	barrage = CIRCLE_ROWS,
	golem_fall = { { FALL_DUST_AT, playFallDust } },
}
local GOLEM_TIMED = {
	golem = { { RISE_DUST_AT, playRiseDust }, { GATHER_FROM, playGather } },
	golem_slam = { { 0.6, playGather } }, -- the slam track's lead: its own 2.2 s wind-up, as the golem move's
	golem_sweep = SWEEP_ROWS,
}

local function playEvent(name)
	local play = EVENTS[name]
	if play and effects and mage then
		effects:SetAttribute("LastParticles", play())
	end
end

local function fireRows(timed, events, from, to)
	for _, row in timed or {} do
		if row[1] > from and row[1] <= to then
			row[2]()
		end
	end
	for _, event in events do
		if event.Time > from and event.Time <= to then
			playEvent(event.Name)
		end
	end
end

-- Her move's cues; the golem move's events are the golem tracker's.
local function fireHer(move, from, to)
	if move ~= "golem" then
		fireRows(TIMED[move], Poses.Moves[move].Events, from, to)
	end
end

-- Only moves with golem frames: with no golem standing the golem tracker follows her move.
local function fireGolem(move, from, to)
	local row = Poses.Moves[move] or Poses.GolemMoves[move]
	if row and row.Golem then
		fireRows(GOLEM_TIMED[move], row.Events, from, to)
	end
end

-- Fires what one tracker's move passed since its last frame.
local function advance(fire, move, t, lastMove, lastTime)
	if move == lastMove and lastTime and t > lastTime then
		if t - lastTime < 0.5 then -- a long hitch skips its effects rather than playing them late
			fire(move, lastTime, t)
		end
	elseif move ~= lastMove and lastMove and t < 0.5 then
		fire(move, -1, t)
	end
end

local function clear()
	generation += 1
	endDim()
	table.clear(lightPool)
	table.clear(pools)
	hitSpot = nil
	table.clear(hitEmitters)
	table.clear(tracked)
	table.clear(circles)
	if staff and staff.Parent then
		Kit.swingTrail(staff, nil)
	end
	staff = nil
	if charge then
		charge:Destroy()
		charge, chargeLight = nil, nil
	end
	previousMove, previousTime = nil, nil
	previousGolem, previousGolemTime = nil, nil
end

-- Call with the arena's BossEffects folder and the Client/BossMage.
function BossMageVfx.Start(folder, boss)
	BossVfx.Start(folder, nil) -- points the Kit's helpers at this folder; BossVfx.Step is never called for her
	effects, mage = folder, boss
	clear()
end

function BossMageVfx.Stop()
	clear()
	BossVfx.Stop()
	effects, mage = nil, nil
end

-- since: seconds since the spawn, nil before it. move, localTime: her move; golemMove, golemTime: the golem's (as Client/BossMage).
function BossMageVfx.Step(since, move, localTime, golemMove, golemTime)
	if not effects or Kit.held() then -- held: the capture's frame stays as drawn (BossVfx.ScrubStep)
		return
	end
	stepDim()
	for part, source in tracked do
		if part.Parent then
			part.CFrame = source()
		else
			tracked[part] = nil
		end
	end
	stepStaffTrail(move, localTime)
	if ReplicatedStorage:GetAttribute(FORCE) ~= nil then
		return
	end
	stepStaffCharge(move, localTime)
	if since and since >= Event.RiseSeconds then
		advance(fireHer, move, localTime, previousMove, previousTime)
		advance(fireGolem, golemMove, golemTime, previousGolem, previousGolemTime)
	end
	previousMove, previousTime = move, localTime
	previousGolem, previousGolemTime = golemMove, golemTime
end

-- Deferred: Client/BossVfx's own listener clears the shared folder first.
ReplicatedStorage:GetAttributeChangedSignal(FORCE):Connect(function()
	task.defer(function()
		local value = ReplicatedStorage:GetAttribute(FORCE)
		if value == nil or not (effects and mage) then
			return
		end
		clear()
		local lead = LEADS[value]
		if lead then
			lead()
		end
		playEvent(value)
	end)
end)

return BossMageVfx
