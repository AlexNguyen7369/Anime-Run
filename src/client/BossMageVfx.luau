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
local ICE, BLUE = Color3.fromRGB(205, 232, 255), Color3.fromRGB(90, 150, 255) -- the barrage's white and blue
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
local BOLT_KINKS = 3
-- Owner 2026-11-12 after playing (BOSS_EVENT_SPEC "Pose-tied effect values", proposed): thick white-violet bolts that hit hard.
local BOLT_CORE, BOLT_GLOW, BOLT_SECONDS = 1.8, 7, 0.24 -- studs across the white core and the purple glow, s they show
local GLOW_TRANSPARENCY = 0.2 -- the deep violet glow, low transparency
local FLOOR_LIGHT, FLOOR_RANGE, FLOOR_UP = 5, 26, 4 -- a bolt's floor light: brightness, range, studs over its spot
-- The room dims for her strikes: from her lead-in to DIM_TAIL after the window, in over DIM_IN, back over DIM_OUT. The grade is
-- BossStrikeDim (Lighting); Lighting's brightness and ambients go to 25% through Client/BiomeEnvironment (Lighting attribute
-- BossStrikeDim, 0 to 1); the arena's own lights to TORCH_DIM.
local DIM_IN, DIM_OUT, DIM_TAIL = 0.25, 0.6, 0.5
local DIM_GRADE = { Brightness = -0.25, Contrast = 0.08, Saturation = 0.15, TintColor = Color3.fromRGB(150, 140, 255) }
local TORCH_DIM = 0.2
local HIT_FLASH, HIT_FLASH_SECONDS = 22, 0.3 -- studs across a hit's white disc, s
local RING_FROM, RING_TO, RING_SECONDS = 8, 46, 0.36 -- studs across a hit's purple shock ring as it grows, s (pool reuse after 0.45 s)
local SPARKS_PER_HIT, SMOKE_PER_HIT = 6, 2 -- particles at each lightning spot
local BEAM_CORE, BEAM_GLOW, BEAM_EDGE, BEAM_SECONDS = 2.4, 4.4, 6.4, 0.25 -- studs across the barrage beam's layers, s
local BEAM_HEAD = 7 -- studs across the beam's rounded white head at the hit
local BEAM_SPARKS, BEAM_SMOKE = 4, 3 -- particles at each barrage spot
local CIRCLES = 10
-- Owner 2026-11-12 after playing (BOSS_EVENT_SPEC "Pose-tied effect values", proposed): 10, much bigger, one by one 0.15 s apart
-- from 0.2 s, all open before the beams at 2.0 s: the tenth opens at 0.2 + 9 x 0.15 = 1.55 s and is full by 1.75 s.
local CIRCLE_SMALL, CIRCLE_LARGE = 30, 70 -- studs across, the first and the last circle: small to large
local CIRCLE_FROM, CIRCLE_EVERY = 0.2, 0.15 -- s of barrage the first circle opens, s between two
local CIRCLE_OPEN = 0.2 -- s a circle takes to open (Quad, no overshoot)
local CIRCLE_NEAR, CIRCLE_STEP = 22, 2.5 -- studs from her torso to the first circle's centre, and further for each next one
-- The fan: circle k's { degrees off the staff's aim seen from her torso, degrees around the aim }: one on the aim, three close
-- about it, six wider (within the 70 degrees of the contract).
local CIRCLE_FAN = {
	{ 0, 0 },
	{ 26, 0 },
	{ 26, 120 },
	{ 26, 240 },
	{ 48, 30 },
	{ 48, 90 },
	{ 48, 150 },
	{ 48, 210 },
	{ 48, 270 },
	{ 48, 330 },
}
local CHARGE_FROM = 0.6 -- s of lightning: the staff tip's charge from here to the strike (proposed)
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
		Size = sequence(0, 5, 1, 15),
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
local function startDim(endIn, event)
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
	dim = { Born = now, EndAt = now + endIn, Grade = grade, Lights = lights }
end

-- The room exactly as it was: the grade gone, the profile's lighting (Client/BiomeEnvironment), the arena's lights.
local function endDim()
	if not dim then
		return
	end
	dim.Grade:Destroy()
	Lighting:SetAttribute("BossStrikeDim", nil)
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
	local grade = dim.Grade
	grade.Brightness, grade.Contrast = DIM_GRADE.Brightness * f, DIM_GRADE.Contrast * f
	grade.Saturation, grade.TintColor = DIM_GRADE.Saturation * f, WHITE:Lerp(DIM_GRADE.TintColor, f)
	Lighting:SetAttribute("BossStrikeDim", f)
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

-- 1.0 s ahead of each bolt: a purple ring closing in on its spot (one part each: there are up to 140). Shown with effects off too:
-- the marks are the telegraph.
local function playMarks()
	startDim(Poses.Moves.lightning.Window[2] - (LIGHTNING_AT - MARK_LEAD) + DIM_TAIL)
	for _, strike in plan("Lightning") do
		local lead = MARK_LEAD + strike.T
		for _, at in strike.Spots do
			local rim = Kit.holder("StrikeMark", CFrame.new(at), Vector3.new(16, 0.2, 16))
			Kit.decal(rim, Art.Ring, VIOLET, Enum.NormalId.Top)
			Kit.tween(rim, lead, { Size = Vector3.new(7, 0.2, 7) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Kit.expire(rim, lead + 0.15)
		end
	end
	return 0
end

-- The shock ring's look: a purple disc with a bright ring on top (Right: the cylinder's end, turned up).
local function shockLook(part)
	disc(part)
	Kit.decal(part, Art.Ring, LAVENDER, Enum.NormalId.Right)
end

-- One bolt's hit: a white disc, a purple shock ring racing out, sparks, lit purple smoke and a violet light on the floor.
local function boltHit(at)
	flash(at, HIT_FLASH, HIT_FLASH_SECONDS)
	floorLight(at, HIT_FLASH_SECONDS)
	local frame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local ring =
		pooled("ShockRing", frame, Vector3.new(0.3, RING_FROM, RING_FROM), VIOLET, 0.3, RING_SECONDS, shockLook)
	Kit.tween(ring, RING_SECONDS, { Size = Vector3.new(0.3, RING_TO, RING_TO) }, Enum.EasingStyle.Quart)
	return emitAt("Sparks", at, SPARKS_PER_HIT) + emitAt("StrikeSmoke", at + Vector3.new(0, 2, 0), SMOKE_PER_HIT)
end

local function playLightning()
	-- cue: MageLightning (a crack of thunder)
	local list, rng = plan("Lightning")
	logStrikes("Lightning", list)
	if reduced() then
		return logHits("Lightning", list, 0.12, 20)
	end
	startDim(Poses.Moves.lightning.Window[2] - LIGHTNING_AT + DIM_TAIL, true)
	for _, strike in list do
		local bolts = {}
		for k, at in strike.Spots do
			local points = { at + Vector3.new(rng:NextNumber(-10, 10), BOLT_TOP, rng:NextNumber(-10, 10)) }
			for i = 1, BOLT_KINKS - 1 do
				local p = points[1]:Lerp(at, i / BOLT_KINKS)
				table.insert(points, p + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)))
			end
			table.insert(points, at)
			-- a branch off the lower kink, forking down and out (clip 3), and a thinner one off the upper kink
			local fork = points[BOLT_KINKS]
				+ Vector3.new(rng:NextNumber(-16, 16), -rng:NextNumber(12, 24), rng:NextNumber(-16, 16))
			local twig = points[2]
				+ Vector3.new(rng:NextNumber(-18, 18), -rng:NextNumber(10, 20), rng:NextNumber(-18, 18))
			bolts[k] = { Points = points, Fork = fork, Twig = twig }
		end
		later(strike.T, function()
			local total = 0
			for _, bolt in bolts do
				local points = bolt.Points
				for i = 1, #points - 1 do
					streak(
						"Bolt",
						points[i],
						points[i + 1],
						BOLT_CORE,
						BOLT_GLOW,
						WHITE,
						DEEP,
						BOLT_SECONDS,
						GLOW_TRANSPARENCY
					)
				end
				streak(
					"Bolt",
					points[BOLT_KINKS],
					bolt.Fork,
					BOLT_CORE * 0.6,
					BOLT_GLOW * 0.6,
					WHITE,
					DEEP,
					BOLT_SECONDS,
					GLOW_TRANSPARENCY
				)
				streak(
					"Bolt",
					points[2],
					bolt.Twig,
					BOLT_CORE * 0.4,
					BOLT_GLOW * 0.4,
					WHITE,
					DEEP,
					BOLT_SECONDS,
					GLOW_TRANSPARENCY
				)
				total += boltHit(points[#points])
			end
			roomLight(Vector3.new(Arena.Center.X, Arena.Y + 50, Arena.Center.Z), DEEP, 3.5, 0.2)
			Kit.impact("Lightning", Arena.Center, 0.12, 20, 0.15, strike.T)
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

-- From CIRCLE_FROM, held over the window: circle k of the barrage opens CIRCLE_EVERY after the one before, in a wide fan in front
-- of her along the staff's pointing (grip to tip), facing along it, small to large, turning, with a bright rim and a white pop.
local function ballLook(part)
	part.Shape = Enum.PartType.Ball
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
	local grip, tip = mage:Point("Staff", Vector3.zero), mage:Point("Staff", STAFF_TIP)
	local aim = (tip - grip).Magnitude > 0.01 and (tip - grip).Unit or Vector3.new(0, 0, -1)
	local torso = mage.Her.Model and mage.Her.Model:FindFirstChild("Torso", true)
	local from = torso and torso.Position or tip
	local ref = math.abs(aim.Y) < 0.95 and Vector3.yAxis or Vector3.xAxis
	local right = aim:Cross(ref).Unit
	local up = right:Cross(aim)
	local off, around = math.rad(CIRCLE_FAN[k][1]), math.rad(CIRCLE_FAN[k][2])
	local out = aim * math.cos(off) + (right * math.cos(around) + up * math.sin(around)) * math.sin(off)
	local center = from + out * (CIRCLE_NEAR + CIRCLE_STEP * (k - 1))
	local offset = center - mage.Her.Anchor.Position
	local turn = (k % 2 == 0 and 1 or -1) * math.rad(90)
	local born = os.clock()
	local function frame()
		local anchor = mage.Her.Anchor.Position + offset
		return CFrame.lookAt(anchor, anchor + aim) * CFrame.Angles(0, 0, turn * (os.clock() - born))
	end
	local part = Kit.holder("MagicCircle", frame(), Vector3.new(1, 1, 0.2))
	tracked[part] = frame
	local tint = k % 2 == 0 and BLUE or ICE
	local faces = {}
	for _, face in Kit.UprightFaces do
		table.insert(faces, Kit.decal(part, MageArt.MagicCircle, tint, face))
		table.insert(faces, Kit.decal(part, Art.Ring, WHITE, face, 0.15)) -- the bright rim
	end
	Kit.tween(part, CIRCLE_OPEN, { Size = Vector3.new(size, size, 0.2) })
	local pop = pooled("CirclePop", CFrame.new(center), Vector3.one * 4, WHITE, 0, 0.25, ballLook) -- the white burst as it opens
	Kit.tween(pop, 0.25, { Size = Vector3.one * size * 0.4 })
	local hold = BARRAGE_AT - (CIRCLE_FROM + (k - 1) * CIRCLE_EVERY) + BARRAGE_WINDOW
	Kit.after(hold + 0.25, function()
		for _, d in faces do
			Kit.tween(d, 0.3, { Transparency = 1 })
		end
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

-- One beam from a circle to its spot: a white-hot core in a blue-white glow inside a near-black edge, a rounded white head, a
-- white flash, white sparks and black smoke where it hits.
local function beam(from, target, k)
	local frame, length =
		streak("BarrageBeam", from, target, BEAM_CORE, BEAM_GLOW, WHITE, k % 2 == 0 and BLUE or ICE, BEAM_SECONDS)
	pooled("BarrageBeamEdge", frame, Vector3.new(BEAM_EDGE, BEAM_EDGE, length), INK, 0.7, BEAM_SECONDS, edgeLook)
	pooled(
		"BarrageBeamHead",
		CFrame.new(target + Vector3.new(0, BEAM_HEAD * 0.3, 0)),
		Vector3.one * BEAM_HEAD,
		WHITE,
		0,
		BEAM_SECONDS,
		ballLook
	)
	flash(target, 16, 0.3)
	return emitAt("BarrageSparks", target, BEAM_SPARKS)
		+ emitAt("BarrageSmoke", target + Vector3.new(0, 2, 0), BEAM_SMOKE)
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
				local from = circle and circle.Parent and circle.Position or mage:Point("Staff", STAFF_TIP)
				total += beam(from, target, k)
			end
			roomLight(mage.Her.Anchor.Position + Vector3.new(0, 30, 0), ICE, 3, 0.2)
			Kit.impact("Barrage", Arena.Center, 0.1, 18, 0.15, strike.T)
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
			charge, chargeLight = nil, nil
		end
		return
	end
	if not (charge and charge.Parent == effects) then
		charge = Kit.holder("StaffCharge", CFrame.new(), Vector3.one)
		charge.Shape, charge.Material, charge.Color, charge.Transparency = Enum.PartType.Ball, NEON, WHITE, 0.05
		chargeLight = Instance.new("PointLight")
		chargeLight.Color, chargeLight.Range, chargeLight.Shadows = VIOLET, 24, false
		chargeLight.Parent = charge
	end
	local u = (localTime - CHARGE_FROM) / (LIGHTNING_AT - CHARGE_FROM)
	charge.CFrame = CFrame.new(mage:Point("Staff", STAFF_TIP))
	charge.Size = Vector3.one * (1.5 + 3.5 * u)
	chargeLight.Brightness = 1 + 3 * u
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
