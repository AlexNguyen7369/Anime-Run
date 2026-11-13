--!nonstrict
-- The Golden King's effects (design doc 4.37 "Third boss", docs/BOSS_EVENT_SPEC.md "The Golden King"). Visual only: nothing here
-- reads back into damage. Timed from BossKingPoses' schedule events, which server time alone decides, and built with Client/BossVfx's
-- helpers (BossVfx.Kit) in the arena's BossEffects folder, after Client/BossMageVfx's spam model. gates_start opens 12 to 20 golden
-- ripple portals around and behind him; gates fires the 2 s volley window: every 0.15 s, 14 times, 7 to 10 weapons
-- as gold projectiles tweened in straight lines from a portal to spots over the whole room, every third a gold beam instead.
-- enuma_start starts the red charge (the room's red dim, wind lines drawn into him) until enuma fires the red-black cyclone beam
-- that turns with his live torso (his baked hip turn) over the Window. The shields open on his call key (SHIELD_CALL s of shields)
-- or when the ReplicatedStorage attribute BossFortified turns true: 5 to 7 gold shields of different shapes orbit him while it is
-- true and shatter with a burst when it turns false; a ring the pose opened that the attribute never held is shattered 1 s into a
-- later move.
-- Pose-tied (BOSS_EVENT_SPEC "Animation rework", "Pose-tied effects"): the portals open one by one in a cascade, EaGlow lights on
-- Ea brighten through the charge, and a white EnumaChargeFlash at Ea's tip just before the beam.
-- Stronger (owner 2026-11-12 after playing; design doc 4.37 "Golden King effects stronger", BOSS_EVENT_SPEC "Golden King
-- effects"): portal, then weapon, then shot: a portal fires only once it is full size and its tip has pushed through, never from
-- his chest (a shot with no ready portal waits for the first). Each hit: a gold StrikeFlash with a white StrikeFlashCore, a gold
-- ShockRing, Sparks and HitDust from one reused HitSpot. Enuma: a white EnumaBeamCore in the red beam, the dark EnumaCyclone
-- rolling about it, EnumaHitBurst and EnumaHitSmoke where it meets the deck.
-- Effects off (design doc 4.37 "Boss effects have no reduced version", BOSS_EVENT_SPEC "Effects setting"): under ReduceEffects or
-- Roblox Reduced Motion nothing is drawn (no portals, weapons, wind, glow, flashes, trails or shields); LastStrikes and LastImpact
-- still log every volley and the beam.
-- Spots and portal places come from a seed of the schedule start and the cycle, so every client draws the same ones. All sizes, counts
-- and colours are placeholders to judge from a capture. Debug field: BossEffects attribute LastStrikes, JSON { Move, Strikes }.
-- BossVfxForce (client-local test attribute, as Client/BossVfx): not nil holds off the schedule; Portals, Volley (with its portals),
-- Charge, Beam or Shields plays that event at once; Gates (portals and volleys) or Enuma (charge, then beam) a whole move. Not drawn
-- yet: the drums' spin on Ea (pose data of the bake). The room's dim goes through Client/BiomeEnvironment (Lighting attributes
-- BossStrikeDim and BossStrikeFloor), as the Elf Mage's. The capture (BossVfx.ScrubTime, Studio only) holds the effects with
-- Kit.held(); a clear() drops the delayed plays of an earlier start.
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig")).For("boss_king")
local Art = require(Shared:WaitForChild("BossVfxArt"))
local Event = require(Shared:WaitForChild("BossEventConfig"))
-- design doc 7: required only while his event or preview shows, so it waits for his poses alone
local Poses =
	require(Shared:WaitForChild("LateData")).Get(require(Shared:WaitForChild("BossCatalog")).Get("boss_king").Poses)
local BossVfx = require(script.Parent:WaitForChild("BossVfx"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local Kit = BossVfx.Kit
local sequence = Kit.sequence
local FORCE = "BossVfxForce"
local FORTIFIED = "BossFortified"
local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)
local GOLD, GOLD_HI = Color3.fromRGB(255, 196, 64), Color3.fromRGB(255, 236, 160)
local RED, DARK = Color3.fromRGB(225, 28, 40), Color3.fromRGB(24, 6, 10)

-- The move's event times, from the stub's or the bake's schedule; fallbacks are the spec's seconds.
local function eventTime(move, name, default)
	for _, row in Poses and Poses.Moves[move] and Poses.Moves[move].Events or {} do
		if row.Name == name then
			return row.Time
		end
	end
	return default
end
local function window(move, default)
	local row = Poses and Poses.Moves[move]
	return row and row.Window and row.Window[2] - row.Window[1] or default
end
local PORTAL_LEAD = eventTime("gates", "gates", 2) - eventTime("gates", "gates_start", 0) -- portals open this long before the volleys
local GATES_WINDOW = window("gates", 2)
local CHARGE = eventTime("enuma", "enuma", 3) - eventTime("enuma", "enuma_start", 0)
local BEAM = window("enuma", 2)
local STRIKE_COUNT, STRIKE_EVERY = 14, 0.15 -- as the mage (owner 2026-11-11): 0, 0.15, ... 1.95 s of the 2 s window
local PER_STRIKE_MIN, PER_STRIKE_MAX = 7, 10
-- BOSS_EVENT_SPEC "Golden King game matched to his sheets" (2026-11-12, proposed): a dense arch of 16 to 22 portals, 18 to 30 studs
local PORTALS_MIN, PORTALS_MAX = 16, 22
local PORTAL_SIZES = { 28, 22, 19, 25 } -- studs across, by turns
local PORTAL_ART = Art.PortalC ~= nil and Art.PortalC ~= "" and Art.PortalC or Art.Ring -- design C once uploaded
local PORTAL_TURN = 0.3 -- radians a second about its facing, slow (proposed)
local PORTAL_CASCADE = 0.7 -- s over which they open, a few then many (proposed)
local LATE_CASCADE = 0.2 -- s: the same cascade for a client that missed gates_start, opened when the volleys start (proposed)
local SHOT_SECONDS = 0.3 -- a projectile's flight (proposed; 0.22 read as a blur, owner 2026-11-11: weapons must be seen flying)
local SHIELDS_MIN, SHIELDS_MAX = 5, 7
local SHIELD_RADIUS, SHIELD_TURN = 17, 0.7 -- studs from him, radians a second
local SHARDS = 5 -- a shattering shield's pieces
local SPOT_MAX = Arena.WallRadius - 4 -- the whole room: centre, lanes and walkway
local SALT = { Portals = 1, Gates = 2, Shields = 3 }
local TIP_HEIGHT = Arena.BossHeight * 0.85 -- the portals' and shields' height over his feet; the beam starts at Ea's tip
-- The swirling wind (owner 2026-11-12, assets/ui/boss_king/wind_draft/ea_wind_strip.png): ribbons orbit Ea's axis, one turn per 0.8 s
-- early, speeding up with the drums to one per 0.35 s by 2.75 s; 4 ribbons, 5 from 1.5 s, 6 from 2.25 s. Sizes proposed.
local WIND_TURN_EARLY, WIND_TURN_LATE = 0.8, 0.35 -- s a turn
local WIND_RAMP_FROM, WIND_RAMP_TO = 0.5, 2.75 -- s into the charge
local WIND_RIBBONS = 6
-- The white helix (sheets' enuma keys 3 to 6): radius, studs a turn, from and to along Ea from its tip, width, s it shows from
local HELIX = { 11, 18, -85, 8, 1.1, 0.9 } -- proposed (Studio 2026-11-12: reaches down round him, as the sheets)
local WIND_CLIMB = 1.2 -- s for a ribbon to climb from his feet to Ea's tip
local WIND_RADIUS_FEET, WIND_RADIUS_TIP, WIND_WIDTH = 12, 5, 1.6 -- studs
local SHIELD_CALL = 0.6 -- s of shields: his call key (rework keys), the ring opens
local EA_GLOW_MAX = 1.5 -- EaGlow's brightness at the end of the charge, from 0 at its start (proposed)
local FLASH_LEAD = 0.08 -- s before the beam: the white flash (proposed)
-- Stronger Gates and Enuma (owner 2026-11-12 after playing; design doc 4.37 "Golden King effects stronger", BOSS_EVENT_SPEC "Golden
-- King effects", proposed). Order: a portal opens to full size, then its weapon tip pushes through, then it may fire.
local PORTAL_GROW, PORTAL_OPEN = 0.12, 0.25 -- s: a dot to a small ring, then to full size
local TIP_PUSH, TIP_READY = 0.3, 0.1 -- s the tip takes to push through; s into the push the portal may fire (the tip shows)
local EMERGE, EMERGE_STUDS = 0.1, 2 -- s and studs a weapon slides out of its portal before it flies
local ENUMA_FLASH = 1.1 -- the 3.0 s flash's brightness: a full white frame (proposed)
local RAY_LENGTH, RAY_SPEED = 30, 420 -- studs long, studs a second: the streaks fly as short rays (proposed)
local STREAK_CORE, STREAK_SHEATH = 1.3, 3.6 -- studs across a streak's white core and gold sheath (the sheets' thick streaks)
local HIT_FLASH, HIT_CORE, HIT_SECONDS = 11, 5, 0.3 -- studs across a hit's gold flash and its white core, s
local RING_FROM, RING_TO, RING_SECONDS = 6, 34, 0.36 -- studs across a hit's gold shock ring as it grows, s
local SPARKS_PER_HIT, DUST_PER_HIT = 6, 2
local BEAM_CORE, BEAM_RED, BEAM_OUTER, BEAM_CYCLONE = 2.6, 7, 10.5, 15 -- studs across Enuma's white core, red, dark red, cyclone
local CYCLONE_TURN = 9 -- radians a second the cyclone rolls about the beam
-- Matched to the approved sheets (design doc 4.37 "The approved Blender key-frame renders are the final look"; rework
-- gates_slices.png, enuma_slices.png; proposed). Gates: the room darkens to about 12% as the portals open, each open portal casting
-- a gold light; blades are glowing rods; streaks leave gold sparkle dust. Enuma: the room goes red through the charge, a white
-- full flash at 3.0 s, four red and black strands coil round the beam (Beams on the rolling cyclone, so they turn with it).
local PORTAL_CLOSE = 0.3 -- s the portals take to close after the last volley (3.55 s) has left them
-- every other open portal's gold PointLight (Studio 2026-11-12: 20 lights at 2 turned him into a flat gold glow)
local PORTAL_LIGHT, PORTAL_LIGHT_RANGE = 0.3, 18
-- The arch of portals behind him, facing his front (the sheets' gates keys 3 to 9): degrees from his left to his right over his
-- head, studs from his chest, studs behind him, the arch's centre over his feet as a fraction of his height (proposed)
-- two rings of the arch, alternate portals on each (inner and outer studs from his chest), so the big ones overlap like the sheet's
local ARCH_SPAN, ARCH_RADIUS, ARCH_BACK, ARCH_HEIGHT = 118, { { 34, 38 }, { 54, 62 } }, { 6, 14 }, 0.6
local TIP_WIDTH = 1.2 -- studs across a portal's glowing blade
local DUST_PER_SHOT = 8 -- gold sparkle dust along each shot's path
local STRANDS, STRAND_PITCH, STRAND_RADIUS, STRAND_WIDTH, STRAND_REACH = 4, 18, 6, 1.3, 170 -- studs; reach: from Ea's tip
local HIT_GLOW = 30 -- studs across the red glow under Enuma's hit
local DIM_OUT, LIFT_SECONDS = 0.6, 0.3 -- s the dim takes to lift; the white flash lifts it this long
local GATES_DIM =
	{ -- the sunset room to a dusky mauve (Studio 2026-11-12: 12% and -0.3 read near black, the sheets are dusk)
		Floor = 0.3,
		In = 0.9,
		-- violet over the dusk sky's sand (Studio 2026-11-12, with BiomeEnvironment's BossStrikeDusk sky and haze)
		Grade = { Brightness = -0.05, Contrast = 0.1, Saturation = -0.1, TintColor = Color3.fromRGB(215, 195, 255) },
		Torch = GOLD,
		TorchDim = 0.35,
	}
local ENUMA_DIM = { -- red through the charge
	Floor = 0.3,
	In = CHARGE * 0.8,
	-- warm, not pink (Studio 2026-11-12: a pink tint turned the white sun pink); the red is the lights'
	Grade = { Brightness = -0.1, Contrast = 0.15, Saturation = 0.1, TintColor = Color3.fromRGB(255, 220, 205) },
	Torch = RED,
	TorchDim = 0.3,
}
local EA_SWING = { 2.6, 3.25 } -- s of enuma: Ea's Trail, the 2.75 s swing into the 3.0 s hit and its follow-through (proposed)

local BossKingVfx = {}

local effects, king = nil, nil
local tracked = {} -- part -> function giving its CFrame each frame
local portals = {} -- the open portals, the volley's origins
local portalTips = {} -- portal -> its weapon tip, flashed as it fires
local ea = nil -- his Ea part, found by name (the rig is built late)
local eaGlow = nil -- its PointLight EaGlow
local shields = {} -- the orbiting shields while Fortified
local shieldRing = nil -- their Folder "ShieldRing" in the effects folder
local pools = {} -- name -> idle pooled parts of that name (Transparency 1) in this arena's folder
local ready = {} -- portals whose weapon tip shows, in the order they got ready: the volleys' origins
local portalsUntil = -math.huge -- os.clock() at which this client's last opened portals are gone
local waiting = {} -- shots with no ready portal yet, { Target, N }: fired from the first portal that gets ready
local hitSpot, hitEmitters = nil, {} -- the one spot the hit particles come from, its emitters by name
local dustLine = nil -- the one part the streak dust comes from, stretched along each shot
local dim = nil -- the room's dim while it runs: { Born, EndAt, Grade, Look, Lights = { light -> its look } }
local generation = 0 -- bumped by clear(): a delayed play of an earlier start draws nothing
local previousMove, previousTime = nil, nil

local function reduced()
	return UiMotion.Reduced()
end

-- The same generator on every client for one move of one cycle: the schedule start and the cycle number, both from server time.
local function rngFor(name)
	local start = ReplicatedStorage:GetAttribute("BossScheduleStart") or 0
	local cycle = Poses and math.floor((Workspace:GetServerTimeNow() - start - Event.IntroSeconds) / Poses.CycleSeconds)
		or 0
	local rng = Random.new((math.floor(start) % 1000000) * 31 + (cycle % 100000) * 7919 + SALT[name] * 104729)
	rng:NextNumber() -- as BossDodge.Spot
	return rng
end

-- The volleys: { T, Spots } for each of the 14, T seconds after the window starts, the same with effects on or off. Every volley
-- takes all its draws. Spots are area-uniform over the room's floor.
local function plan()
	local rng, list = rngFor("Gates"), {}
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
	return list
end

local function logStrikes(list)
	local rows = {}
	for j, strike in list do
		local spots = {}
		for k, at in strike.Spots do
			spots[k] = { math.floor(at.X * 10 + 0.5) / 10, math.floor(at.Z * 10 + 0.5) / 10 }
		end
		rows[j] = { T = strike.T, Spots = spots }
	end
	effects:SetAttribute("LastStrikes", HttpService:JSONEncode({ Move = "Gates", Strikes = rows }))
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
		if make then
			make(part)
		end
	end
	part.Name = name
	part.Material = NEON -- a weapon piece sets its own after
	part.Color, part.Transparency = color, transparency
	Kit.tween(part, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, d in part:GetChildren() do
		if d:IsA("Decal") then
			d.Transparency = 0
			Kit.tween(d, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end
	Kit.after(seconds + 0.03, function()
		if part.Parent == effects then
			tracked[part] = nil
			part.Name, part.Transparency = "Pooled", 1
			local trail = part:FindFirstChildOfClass("Trail")
			if trail then
				trail.Enabled = false
			end
			pools[name] = pools[name] or {}
			table.insert(pools[name], part)
		end
	end)
	return part
end

-- Whether a play started under folder `mine` in run `run` may still draw (not cleared since).
local function current(mine, run)
	return mine ~= nil and effects == mine and generation == run and mine.Parent ~= nil
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

local function disc(part)
	part.Shape = Enum.PartType.Cylinder
end

-- The shock ring's look: a gold disc with a bright ring on top (Right: the cylinder's end, turned up).
local function ringLook(part)
	disc(part)
	Kit.decal(part, Art.Ring, GOLD_HI, Enum.NormalId.Right)
end

-- The hit particles, one emitter each on one spot moved to every hit (no instance per hit). Placeholders.
local HIT_LOOKS = {
	Sparks = {
		Name = "Sparks",
		Texture = Art.Spark,
		Color = ColorSequence.new(WHITE, GOLD),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(80, 80),
		Size = sequence(0, 2.2, 1, 0),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(45, 100),
		Drag = 3,
		Acceleration = Vector3.new(0, -80, 0),
	},
	HitDust = {
		Name = "HitDust",
		Texture = Art.Dust,
		Color = ColorSequence.new(Color3.fromRGB(214, 190, 140), Color3.fromRGB(150, 136, 112)),
		LightInfluence = 0.6,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(70, 70),
		Size = sequence(0, 5, 1, 14),
		Transparency = sequence(0, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(6, 14),
		Drag = 1.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	},
}

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

-- Gold sparkle dust along a shot's path from a to b, from the one dust line (no instance per shot).
local function dustAlong(a, b)
	if not (dustLine and dustLine.Parent == effects) then
		dustLine = Kit.holder("DustLine", CFrame.new(a), Vector3.one)
		Kit.emitter(dustLine, {
			Name = "StreakDust",
			Texture = Art.Spark,
			Color = ColorSequence.new(WHITE, GOLD_HI),
			LightEmission = 1,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			SpreadAngle = Vector2.new(180, 180),
			Size = sequence(0, 0.7, 1, 0),
			Lifetime = NumberRange.new(0.35, 0.7),
			Speed = NumberRange.new(1, 4),
			Drag = 2,
		})
	end
	dustLine.CFrame, dustLine.Size = CFrame.lookAt((a + b) / 2, b), Vector3.new(1, 1, (b - a).Magnitude)
	dustLine.StreakDust:Emit(DUST_PER_SHOT)
	return DUST_PER_SHOT
end

-- Where a weapon or streak lands: a gold flash with a white core, a gold shock ring racing out, gold sparks and dust.
local function hit(at)
	local flat = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	pooled("StrikeFlash", flat, Vector3.new(0.2, HIT_FLASH, HIT_FLASH), GOLD, 0.5, HIT_SECONDS, disc)
	pooled(
		"StrikeFlashCore",
		flat + Vector3.new(0, 0.1, 0),
		Vector3.new(0.25, HIT_CORE, HIT_CORE),
		WHITE,
		0.35,
		0.22,
		disc
	)
	local ring = pooled(
		"ShockRing",
		flat + Vector3.new(0, 0.2, 0),
		Vector3.new(0.3, RING_FROM, RING_FROM),
		GOLD_HI,
		0.3,
		RING_SECONDS,
		ringLook
	)
	Kit.tween(ring, RING_SECONDS, { Size = Vector3.new(0.3, RING_TO, RING_TO) }, Enum.EasingStyle.Quart)
	return emitAt("Sparks", at, SPARKS_PER_HIT) + emitAt("HitDust", at + Vector3.new(0, 1.5, 0), DUST_PER_HIT)
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

-- The room's dim (the Elf Mage's strike dim, BOSS_EVENT_SPEC "Elf Mage strike lighting", with his own looks): a grade named
-- BossStrikeDim, Client/BiomeEnvironment's profile brightness and ambients down to look.Floor (Lighting attributes BossStrikeDim
-- 0 to 1 and BossStrikeFloor), the arena's own lights toward look.Torch. Eases in over look.In, out over DIM_OUT after `endIn`.
-- A running dim takes the new look and end. Nothing with effects off.
local function startDim(look, endIn, rampIn)
	if reduced() or not (effects and effects.Parent) then
		return
	end
	local now = os.clock()
	Lighting:SetAttribute("BossStrikeFloor", look.Floor)
	if dim then
		dim.Look, dim.EndAt = look, now + endIn
		return
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "BossStrikeDim"
	grade.Parent = Lighting
	local lights = {}
	for _, d in effects.Parent:GetDescendants() do
		if d:IsA("Light") and not d:IsDescendantOf(effects) then
			-- a light mid-pulse: its own brightness
			lights[d] = { Brightness = d:GetAttribute("ImpactBase") or d.Brightness, Color = d.Color }
		end
	end
	dim = { Born = now, EndAt = now + endIn, Grade = grade, Lights = lights, Look = look, In = rampIn or look.In }
end

-- The room exactly as it was.
local function endDim()
	if not dim then
		return
	end
	dim.Grade:Destroy()
	Lighting:SetAttribute("BossStrikeDim", nil)
	Lighting:SetAttribute("BossStrikeFloor", nil)
	Lighting:SetAttribute("BossStrikeDusk", nil)
	for light, base in dim.Lights do
		if light.Parent then
			light.Brightness, light.Color = base.Brightness, base.Color
			if light:GetAttribute("ImpactBase") ~= nil then -- an impact pulse still running: set again after it
				task.delay(0.3, function()
					light.Brightness = base.Brightness
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
	local f = math.min((now - dim.Born) / dim.In, 1)
	if now > dim.EndAt then
		f = math.min(f, 1 - (now - dim.EndAt) / DIM_OUT)
	end
	if f <= 0 or reduced() then
		endDim()
		return
	end
	f = f * f * (3 - 2 * f)
	if dim.LiftAt then
		f *= math.clamp((now - dim.LiftAt) / LIFT_SECONDS, 0, 1)
	end
	local look, grade = dim.Look, dim.Grade
	grade.Brightness, grade.Contrast = look.Grade.Brightness * f, look.Grade.Contrast * f
	grade.Saturation, grade.TintColor = look.Grade.Saturation * f, WHITE:Lerp(look.Grade.TintColor, f)
	Lighting:SetAttribute("BossStrikeDim", f)
	Lighting:SetAttribute("BossStrikeDusk", f) -- the sheets' dusk sky through his moves (Client/BiomeEnvironment)
	for light, base in dim.Lights do
		if light.Parent then
			light.Color = base.Color:Lerp(look.Torch, f)
			if light:GetAttribute("ImpactBase") == nil then -- an impact pulse owns its brightness until it ends
				light.Brightness = base.Brightness * (1 - (1 - look.TorchDim) * f)
			end
		end
	end
end

local function him()
	return king.Rest.Position
end

local function eaPart()
	if not (ea and ea.Parent) then
		local model = king.Him and king.Him.Model
		ea = model and model:FindFirstChild("Ea", true)
	end
	return ea
end

-- Gates of Babylon --------------------------------------------------------------------------------------------------------------

local markReady -- portal: it may fire now (below, with the shots)

-- Golden ripple portals open around and behind him, facing out, held through the lead and the volleys: a ring part with a gold
-- shimmer and, once it is fully open, a weapon's tip pushing through; only then may it fire.
local function playPortals(cascade)
	cascade = cascade or PORTAL_CASCADE
	table.clear(portals)
	table.clear(portalTips)
	table.clear(ready)
	table.clear(waiting)
	if reduced() then
		return 0
	end
	local rng = rngFor("Portals")
	local count = rng:NextInteger(PORTALS_MIN, PORTALS_MAX)
	-- held through the lead and the volleys; they close once the last volley (3.55 s) has left them
	local hold = PORTAL_LEAD + GATES_WINDOW + 0.15 + PORTAL_CLOSE
	portalsUntil = os.clock() + hold
	startDim(GATES_DIM, hold - PORTAL_CLOSE)
	local mine, run = effects, generation
	for k = 1, count do
		local size = PORTAL_SIZES[(k - 1) % #PORTAL_SIZES + 1]
		-- on an arch behind him from his left over his head to his right, each facing his front (the sheets; was a ring round
		-- him facing out, which put edge-on discs between him and the lanes)
		local a = math.rad(ARCH_SPAN * (2 * (k - 1) / (count - 1) - 1)) + rng:NextNumber(-0.08, 0.08)
		local facing = (king.Rest.LookVector * Vector3.new(1, 0, 1)).Unit
		local right = facing:Cross(Vector3.yAxis)
		local ring = ARCH_RADIUS[k % 2 + 1]
		local radius = rng:NextNumber(ring[1], ring[2])
		local anchor = him()
			+ Vector3.new(0, Arena.BossHeight * ARCH_HEIGHT, 0)
			+ (right * math.sin(a) + Vector3.yAxis * math.cos(a)) * radius
			- facing * rng:NextNumber(ARCH_BACK[1], ARCH_BACK[2])
		local frame = CFrame.lookAt(anchor, anchor + facing)
		local turn = PORTAL_TURN * (k % 2 == 0 and 1 or -1)
		-- The opening, built when it comes in the cascade: a bright dot, a small ring, full size (Quad, no overshoot past the drawn
		-- size), then the weapon tip through (owner 2026-11-12: portal, then weapon, then shot).
		local opensAt = cascade * math.sqrt((k - 1) / (count - 1))
		Kit.after(opensAt, function()
			if not current(mine, run) then
				return
			end
			local left = hold - opensAt
			local part = Kit.holder("Portal", frame, Vector3.new(0.6, 0.6, 0.3))
			-- design C: white, so the drawn gold shows as drawn (owner 2026-11-12)
			local front = Kit.decal(part, PORTAL_ART, WHITE, Enum.NormalId.Front)
			local back = Kit.decal(part, PORTAL_ART, WHITE, Enum.NormalId.Back)
			local born = os.clock()
			tracked[part] = function()
				return frame * CFrame.Angles(0, 0, (os.clock() - born) * turn)
			end
			-- the blade: a glowing gold rod, tip first through the open portal
			local tip = Kit.holder(
				"PortalTip",
				frame * CFrame.new(0, 0, size * 0.1),
				Vector3.new(TIP_WIDTH, TIP_WIDTH, size * 0.6)
			)
			tip.Material, tip.Color = NEON, GOLD_HI
			-- the drawn portal unlit as well, so it reads bright in the dim room (a decal is lit by the room)
			local shine = Instance.new("SurfaceGui")
			shine.Face, shine.LightInfluence, shine.Brightness = Enum.NormalId.Front, 0, 1.4
			shine.SizingMode, shine.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(256, 256)
			local shineImage = Instance.new("ImageLabel")
			shineImage.Size, shineImage.BackgroundTransparency = UDim2.fromScale(1, 1), 1
			shineImage.Image, shineImage.ImageTransparency = PORTAL_ART, 0.2
			shineImage.Parent = shine
			shine.Parent = part
			local glow = Instance.new("PointLight") -- every other open portal lights the dimmed room gold
			glow.Name = "PortalLight"
			glow.Color, glow.Brightness, glow.Range, glow.Shadows = GOLD, 0, PORTAL_LIGHT_RANGE, false
			glow.Enabled = k % 2 == 1
			glow.Parent = part
			Kit.tween(glow, PORTAL_GROW + PORTAL_OPEN, { Brightness = PORTAL_LIGHT })
			Kit.tween(part, PORTAL_GROW, { Size = Vector3.new(size * 0.3, size * 0.3, 0.3) })
			Kit.after(PORTAL_GROW, function()
				if part.Parent then
					Kit.tween(part, PORTAL_OPEN, { Size = Vector3.new(size, size, 0.3) })
				end
			end)
			Kit.after(PORTAL_GROW + PORTAL_OPEN, function()
				if part.Parent then
					Kit.tween(tip, TIP_PUSH, { CFrame = frame * CFrame.new(0, 0, -size * 0.3), Transparency = 0 })
				end
			end)
			Kit.after(PORTAL_GROW + PORTAL_OPEN + TIP_READY, function()
				if part.Parent and current(mine, run) then
					markReady(part)
				end
			end)
			local shimmer = Kit.emitter(part, {
				Name = "Shimmer",
				Texture = Art.Spark,
				Color = ColorSequence.new(GOLD_HI, GOLD),
				LightEmission = 1,
				Shape = Enum.ParticleEmitterShape.Disc,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				Size = sequence(0, 0.4, 0.5, 1.2, 1, 0),
				Lifetime = NumberRange.new(0.4, 0.7),
				Speed = NumberRange.new(2, 5),
				Rate = 6,
				Enabled = true,
			})
			-- the close: the blade drawn back, the portal shrinks to a dot and goes
			Kit.after(left - PORTAL_CLOSE, function()
				if not part.Parent then
					return
				end
				shimmer.Enabled = false
				Kit.tween(front, PORTAL_CLOSE, { Transparency = 1 })
				Kit.tween(back, PORTAL_CLOSE, { Transparency = 1 })
				Kit.tween(shineImage, PORTAL_CLOSE, { ImageTransparency = 1 })
				Kit.tween(tip, PORTAL_CLOSE, { Transparency = 1, CFrame = frame * CFrame.new(0, 0, size * 0.1) })
				Kit.tween(glow, PORTAL_CLOSE, { Brightness = 0 })
				Kit.tween(
					part,
					PORTAL_CLOSE,
					{ Size = Vector3.new(0.6, 0.6, 0.3) },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
			end)
			Kit.expire(part, left)
			Kit.expire(tip, left)
			table.insert(portals, part)
			portalTips[part] = tip
		end)
	end
	return math.ceil(count * 6 * hold)
end

-- The vault's weapons (owner 2026-11-11: the volleys fire weapons as projectiles, not streaks): pooled pieces about a frame whose
-- -Z is the flight line. { Name, Size, Offset, Color, Material }; the first piece is the blade or shaft, named Streak, with the trail.
local METAL, PLASTIC = Enum.Material.Metal, Enum.Material.SmoothPlastic
local STEEL, DARK_GOLD = Color3.fromRGB(226, 222, 206), Color3.fromRGB(150, 104, 30)
local WEAPONS = {
	-- His size (44 studs): a sword about 14 studs, a spear 18, so they read from the lanes.
	{ -- a sword: blade, gold guard, dark grip
		{ "Streak", Vector3.new(0.8, 2.4, 10), CFrame.new(0, 0, -2.8), STEEL, METAL },
		{ "Guard", Vector3.new(4, 0.9, 1), CFrame.new(0, 0, 2.9), GOLD, METAL },
		{ "Grip", Vector3.new(0.9, 0.9, 3.6), CFrame.new(0, 0, 5.2), DARK, PLASTIC },
	},
	{ -- a spear: shaft, gold tip
		{ "Streak", Vector3.new(0.7, 0.7, 16), CFrame.new(0, 0, 0), DARK_GOLD, METAL },
		{ "Tip", Vector3.new(1, 2, 3.6), CFrame.new(0, 0, -9.6), GOLD_HI, METAL },
	},
	{ -- a broad blade: cleaver, dark grip
		{ "Streak", Vector3.new(0.8, 4.4, 7.6), CFrame.new(0, 0, -2), STEEL, METAL },
		{ "Guard", Vector3.new(3.2, 0.9, 0.9), CFrame.new(0, 0, 2.2), GOLD, METAL },
		{ "Grip", Vector3.new(1, 1, 4.4), CFrame.new(0, 0, 4.8), DARK, PLASTIC },
	},
}
local SPIN = 3 -- radians a second about the flight line

-- A pooled weapon (WEAPONS[k], by turns) with a trail on its blade: it slides EMERGE_STUDS out of its portal over EMERGE, then
-- flies to b in a straight line over SHOT_SECONDS, spinning slightly.
local function shoot(from, to, k)
	local pieces = WEAPONS[(k - 1) % #WEAPONS + 1]
	local born, base = os.clock(), CFrame.lookAt(from, to)
	local out = base * CFrame.new(0, 0, -EMERGE_STUDS)
	local landed = CFrame.lookAt(to, to + base.LookVector)
	local function flight(offset)
		return function()
			local age = os.clock() - born
			local at = age < EMERGE and base:Lerp(out, age / EMERGE)
				or out:Lerp(landed, math.min((age - EMERGE) / SHOT_SECONDS, 1))
			return at * CFrame.Angles(0, 0, age * SPIN) * offset
		end
	end
	local part = nil
	for _, piece in pieces do
		local one = pooled(piece[1], base * piece[3], piece[2], piece[4], 0, EMERGE + SHOT_SECONDS + 0.2)
		one.Material = piece[5]
		tracked[one] = flight(piece[3])
		part = part or one
	end
	local trail = part:FindFirstChildOfClass("Trail")
	if not trail then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 1.6, 0), Vector3.new(0, -1.6, 0) -- a thick gold streak behind it
		a0.Parent, a1.Parent = part, part
		trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(WHITE, GOLD)
		trail.Transparency = sequence(0, 0.05, 1, 1)
		trail.Lifetime = 0.3
		trail.LightEmission = 1
		trail.Parent = part
	end
	trail.Enabled = true
end

-- One shot n from a ready portal to target: its tip flashes, then a weapon (or, every third, a streak) and the hit where it lands.
local function fireShot(portal, target, n)
	local tip = portalTips[portal]
	if tip and tip.Parent then -- the firing flash: the blade white
		tip.Color = WHITE
		Kit.after(0.08, function()
			tip.Color = GOLD_HI
		end)
	end
	local from = portal.Position
	if n % 3 == 0 then
		-- a short gold ray flying from the portal to its spot (Studio 2026-11-12: a full-length bar read as a laser across the room)
		local line = target - from
		local distance = line.Magnitude
		local dir = distance > 0.01 and line / distance or Vector3.yAxis
		local length = math.min(RAY_LENGTH, distance)
		local flight = math.max(0.05, distance / RAY_SPEED)
		local born = os.clock()
		local function along()
			local u = math.min((os.clock() - born) / flight, 1)
			local back = from + dir * (distance - length) * u
			return CFrame.lookAt(back + dir * length / 2, back + dir * length)
		end
		local start = along()
		local sheath = pooled(
			"Streak",
			start,
			Vector3.new(STREAK_SHEATH, STREAK_SHEATH, length + STREAK_SHEATH * 0.5),
			GOLD,
			0.65,
			flight + 0.05
		)
		local core = pooled(
			"StreakCore",
			start,
			Vector3.new(STREAK_CORE, STREAK_CORE, length + STREAK_CORE),
			WHITE,
			0,
			flight + 0.05
		)
		tracked[sheath], tracked[core] = along, along
		local mine, run = effects, generation
		Kit.after(flight, function()
			if current(mine, run) then
				hit(target)
				dustAlong(from, target)
			end
		end)
		return SPARKS_PER_HIT + DUST_PER_HIT + DUST_PER_SHOT
	end
	shoot(from, target, n)
	local mine, run = effects, generation
	Kit.after(EMERGE + SHOT_SECONDS, function()
		if current(mine, run) then
			hit(target)
			dustAlong(from, target) -- the dust it left on its way
		end
	end)
	return SPARKS_PER_HIT + DUST_PER_HIT + DUST_PER_SHOT
end

-- A ready portal of the open ones, by turns (i), or nil while none holds a weapon yet.
local function readyPortal(i)
	for idx = #ready, 1, -1 do
		if not ready[idx].Parent then
			table.remove(ready, idx)
		end
	end
	return #ready > 0 and ready[(i - 1) % #ready + 1] or nil
end

-- A portal's weapon shows: it may fire, and the shots that waited for one fire from it now.
function markReady(portal)
	table.insert(ready, portal)
	local queued = table.clone(waiting)
	table.clear(waiting)
	for _, shot in queued do
		fireShot(portal, shot.Target, shot.N)
	end
end

-- The volleys never fire from his chest: a shot with no ready portal yet (a forced or early volley) waits for the first one.
local function playVolley()
	-- cue: KingGates (a rush of blades)
	local list = plan()
	logStrikes(list)
	local off = reduced()
	if not off and os.clock() >= portalsUntil then
		-- this client missed gates_start (a late join or start): the same seeded portals at once, still portal, tip, shot
		playPortals(LATE_CASCADE)
	end
	for j, strike in list do
		later(strike.T, function()
			if off then -- effects off: the volley logged only
				Kit.impact("Gates", Arena.Center, 0.1, 18, 0.15, strike.T)
				return 0
			end
			local total = 0
			for k, target in strike.Spots do
				local portal = readyPortal(j + k - 1)
				if portal then
					total += fireShot(portal, target, j + k)
				else
					table.insert(waiting, { Target = target, N = j + k })
				end
			end
			roomLight(him() + Vector3.new(0, 30, 0), GOLD, 1, 0.2)
			Kit.impact("Gates", Arena.Center, 0.1, 18, 0.15, strike.T)
			return total
		end)
	end
	return 0
end

-- Enuma Elish -------------------------------------------------------------------------------------------------------------------

-- The charge: the room goes red, wind lines are drawn into Ea's tip through the 3 s, the edges pulse.
local function playCharge()
	-- cue: KingCharge (a rising wind)
	if reduced() then
		return 0
	end
	startDim(ENUMA_DIM, CHARGE + BEAM) -- the room tints red through the charge, held through the beam
	-- At Ea's tip, local Y along Ea (grip to tip; world up with no Ea part): the orbit's axis.
	local function tip()
		local at, part = king:Tip(), eaPart()
		local axis = part and at - part.Position or Vector3.yAxis
		axis = axis.Magnitude > 0.1 and axis.Unit or Vector3.yAxis
		local ref = math.abs(axis.Z) < 0.95 and Vector3.zAxis or Vector3.xAxis
		return CFrame.fromMatrix(at, ref:Cross(axis).Unit, axis)
	end
	local part = Kit.holder("EnumaWind", tip(), Vector3.new(90, 90, 90))
	tracked[part] = tip
	-- The sheets' white double helix round Ea and him through the charge (keys 3 to 6): Beams, so a held frame keeps it (the
	-- ribbons' Trails fade when nothing moves). Two strands from his feet to past Ea's tip, half turns curved by their attachments.
	local helix = {}
	do
		local radius, pitch, low, high = HELIX[1], HELIX[2], HELIX[3], HELIX[4]
		local halves = math.floor((high - low) / (pitch / 2))
		local lean = pitch / (2 * math.pi * radius)
		local reach = 4 / 3 * radius * math.sqrt(1 + lean * lean)
		for strand = 1, 2 do
			local previous = nil
			for half = 0, halves do
				local a = (strand - 1) * math.pi + half * math.pi
				local radial = Vector3.new(math.cos(a), 0, math.sin(a))
				local along = Vector3.new(-math.sin(a), lean, math.cos(a)).Unit
				local point = Instance.new("Attachment")
				point.CFrame =
					CFrame.fromMatrix(radial * radius + Vector3.new(0, low + half * pitch / 2, 0), along, radial)
				point.Parent = part
				if previous then
					local beam = Instance.new("Beam")
					beam.Name = "EnumaHelix"
					beam.Attachment0, beam.Attachment1 = previous, point
					beam.CurveSize0, beam.CurveSize1 = reach, reach
					beam.Width0, beam.Width1 = HELIX[5], HELIX[5]
					beam.FaceCamera, beam.Segments = true, 10
					beam.Color = ColorSequence.new(WHITE)
					beam.LightEmission, beam.LightInfluence = 1, 0
					beam.Transparency = NumberSequence.new(0.15)
					beam.Enabled = false
					beam.Parent = part
					table.insert(helix, beam)
				end
				previous = point
			end
		end
		local mine, run = effects, generation
		Kit.after(HELIX[6], function()
			if current(mine, run) then
				for _, beam in helix do
					beam.Enabled = true
				end
			end
		end)
	end
	local ribbons, born, last, spin = {}, os.clock(), os.clock(), 0
	for k = 1, WIND_RIBBONS do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = part, part
		local trail = Instance.new("Trail")
		trail.Name = "WindRibbon"
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.FaceCamera = true
		trail.LightEmission, trail.LightInfluence = 1, 0
		trail.Color = ColorSequence.new(WHITE)
		trail.Transparency = sequence(0, 1, 0.25, 0.15, 0.75, 0.15, 1, 1) -- faded at both ends
		trail.WidthScale = sequence(0, 0.3, 0.5, 1, 1, 0.3) -- thin, thick, thin
		trail.MinLength = 0
		trail.Enabled = false
		trail.Parent = part
		ribbons[k] = { A0 = a0, A1 = a1, Trail = trail, Climb = 0 }
	end
	tracked[part] = function()
		local now = os.clock()
		local t = now - born
		local ramp = math.clamp((t - WIND_RAMP_FROM) / (WIND_RAMP_TO - WIND_RAMP_FROM), 0, 1)
		local turns = 1 / WIND_TURN_EARLY + (1 / WIND_TURN_LATE - 1 / WIND_TURN_EARLY) * ramp -- a second
		spin += (now - last) * turns * 2 * math.pi
		last = now
		local frame = tip()
		local reach = math.max((frame.Position - him()):Dot(frame.YVector), 10) -- Ea's tip over his feet, along Ea
		local count = t < 1.5 and 4 or t < 2.25 and 5 or 6
		for k, row in ribbons do
			local on = k <= count and t < CHARGE + 0.2
			local climb = (t / WIND_CLIMB + (k - 1) / WIND_RIBBONS) % 1 -- 0 at his feet, 1 at Ea's tip
			local a = spin + (k - 1) / WIND_RIBBONS * 2 * math.pi
			local r = WIND_RADIUS_FEET + (WIND_RADIUS_TIP - WIND_RADIUS_FEET) * climb
			row.A0.Position = Vector3.new(r * math.cos(a), -reach * (1 - climb), r * math.sin(a))
			row.A1.Position = row.A0.Position + Vector3.new(0, WIND_WIDTH, 0)
			if climb < row.Climb or (on and not row.Trail.Enabled) then -- back at his feet, or newly on: no streak across
				row.Trail:Clear()
			end
			row.Climb = climb
			row.Trail.Enabled = on
			row.Trail.Lifetime = 1 / turns -- about one turn
		end
		return frame
	end
	local rate = 30
	local wind = Kit.emitter(part, {
		Name = "Wind",
		Texture = Art.Shaft,
		Color = ColorSequence.new(WHITE, RED),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = sequence(0, 1, 0.5, 2.5, 1, 0.5),
		Transparency = sequence(0, 0.6, 0.5, 0.2, 1, 1),
		Lifetime = NumberRange.new(0.5, 0.7),
		Speed = NumberRange.new(70, 95),
		Rate = rate,
		Enabled = true,
	})
	local light = Instance.new("PointLight") -- the red over the room, with the grade
	light.Name = "ChargeTint"
	light.Color, light.Brightness, light.Range, light.Shadows = RED, 0, 90, false
	light.Parent = part
	Kit.tween(light, CHARGE, { Brightness = 1.2 }) -- Studio 2026-11-12: at 3 he read flat red, the sheets keep him gold
	Kit.pulseEdges(RED, 0.45, CHARGE / 3, 3)
	Kit.after(CHARGE, function()
		wind.Enabled = false
	end)
	-- The charge ends in a white flash at Ea's tip, just before the beam: its own part each Enuma (not pooled), the effects
	-- setting read when it fires.
	local mine, run = effects, generation
	Kit.after(CHARGE - FLASH_LEAD, function()
		if current(mine, run) and king and not reduced() then
			local white = Kit.holder("EnumaChargeFlash", CFrame.new(king:Tip()), Vector3.one * 8)
			white.Shape, white.Material, white.Color, white.Transparency = Enum.PartType.Ball, NEON, WHITE, 0
			tracked[white] = function() -- rides Ea's tip through the swing (Studio 2026-11-12: it was left behind in the air)
				return CFrame.new(king:Tip())
			end
			Kit.tween(white, 0.3, { Size = Vector3.one * 34, Transparency = 1 })
			Kit.expire(white, 0.3)
			roomLight(king:Tip(), WHITE, 5, 0.3)
		end
	end)
	Kit.expire(part, CHARGE + 0.8)
	return math.ceil(rate * CHARGE)
end

-- The beam: a white core in a red beam in a dark cyclone rolling about it, from Ea's tip, pitched down to the lanes, swept once
-- around the room over the Window; dark smoke streams off it, and where it meets the deck a red-white burst and dark smoke follow.
local function playBeam()
	-- cue: KingEnuma (a tearing roar)
	if reduced() then -- effects off: the hit logged only
		Kit.impact("Enuma", Arena.Center, 1.0, 20, BEAM)
		return 0
	end
	local length = Arena.WallRadius * 1.1
	local born = os.clock()
	-- Aimed along his torso's facing, flat: the beam turns with his baked hip turn, frame by frame (posed before this Step).
	local function frame(roll)
		local origin = king:Tip()
		local look = king.Him and king.Him:Frame("Torso").LookVector or Vector3.new(0, 0, -1)
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, -1)
		local pitch = -math.atan((origin.Y - Arena.Y) / (Arena.InnerRadius + Arena.Width / 2))
		local aim = CFrame.lookAt(origin, origin + flat) * CFrame.Angles(pitch, 0, 0)
		return aim * CFrame.new(0, 0, -length / 2) * CFrame.Angles(0, 0, roll)
	end
	local function straight()
		return frame(0)
	end
	local core = Kit.holder("EnumaBeam", frame(0), Vector3.new(BEAM_RED, BEAM_RED, length))
	core.Material, core.Color, core.Transparency = NEON, Color3.fromRGB(255, 95, 45), 0.5 -- warm red-orange -- Studio 2026-11-12: at 0.1 it hid the white core
	tracked[core] = straight
	local white = Kit.holder("EnumaBeamCore", frame(0), Vector3.new(BEAM_CORE, BEAM_CORE, length))
	white.Material, white.Color, white.Transparency = NEON, WHITE, 0
	tracked[white] = straight
	local outer = Kit.holder("EnumaBeamOuter", frame(0), Vector3.new(BEAM_OUTER, BEAM_OUTER, length))
	outer.Material, outer.Color, outer.Transparency = NEON, Color3.fromRGB(190, 45, 25), 0.72
	outer.Shape = Enum.PartType.Cylinder -- a round layer: the Cylinder's axis is X, turned to the beam's Z below
	outer.Size = Vector3.new(length, BEAM_OUTER, BEAM_OUTER)
	local toAxis = CFrame.Angles(0, math.pi / 2, 0)
	tracked[outer] = function()
		return straight() * toAxis
	end
	-- The cyclone: a faint dark sheath rolling about the beam, carrying the four red and black strands (helices of Beams on its
	-- attachments, built once, so they turn with it at no cost a frame).
	local sheath = Kit.holder("EnumaCyclone", frame(0), Vector3.new(BEAM_CYCLONE, BEAM_CYCLONE, length))
	sheath.Material, sheath.Color, sheath.Transparency = Enum.Material.SmoothPlastic, DARK, 0.85
	tracked[sheath] = function()
		return frame((os.clock() - born) * CYCLONE_TURN) -- the sheath rolls: the cyclone
	end
	local strands = {}
	local halves = 2 * math.floor(STRAND_REACH / STRAND_PITCH) -- half turns of each strand, from Ea's tip (local +Z end)
	local lean = STRAND_PITCH / (2 * math.pi * STRAND_RADIUS) -- the helix's slope along the beam a stud of arc
	local reach = 4 / 3 * STRAND_RADIUS * math.sqrt(1 + lean * lean) -- a half circle's cubic control length
	for s = 1, STRANDS do
		local red = s % 2 == 1
		local previous = nil
		for half = 0, halves do
			local a = (s - 1) / STRANDS * 2 * math.pi + half * math.pi
			local radial = Vector3.new(math.cos(a), math.sin(a), 0)
			local along = Vector3.new(-math.sin(a), math.cos(a), -lean).Unit -- the way the strand runs, its Axis
			local point = Instance.new("Attachment")
			point.CFrame = CFrame.fromMatrix(
				radial * STRAND_RADIUS + Vector3.new(0, 0, length / 2 - half * STRAND_PITCH / 2),
				along,
				radial
			)
			point.Parent = sheath
			if previous then
				local beam = Instance.new("Beam")
				beam.Name = "EnumaStrand"
				beam.Attachment0, beam.Attachment1 = previous, point
				beam.CurveSize0, beam.CurveSize1 = reach, reach
				beam.Width0, beam.Width1 = STRAND_WIDTH * 1.4, STRAND_WIDTH * 1.4
				beam.FaceCamera, beam.Segments = true, 8
				-- the light strands pale red-white, so they read on the red beam (Studio 2026-11-12: red on red was lost)
				beam.Color = ColorSequence.new(red and Color3.fromRGB(255, 200, 195) or DARK)
				beam.LightEmission, beam.LightInfluence = red and 1 or 0, 0
				beam.Transparency = NumberSequence.new(half > halves - 4 and 0.5 or 0) -- the far end thins out
				beam.Parent = sheath
				table.insert(strands, beam)
			end
			previous = point
		end
	end
	-- Where the beam meets the deck (the lanes' middle, along its aim): the burst and the smoke ride it through the sweep.
	local function ground()
		local origin = king:Tip()
		local look = straight().LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, -1)
		local at = origin + flat * (Arena.InnerRadius + Arena.Width / 2)
		return CFrame.new(at.X, Arena.Y + 1, at.Z)
	end
	local spot = Kit.holder("EnumaHit", ground(), Vector3.new(16, 1, 16))
	tracked[spot] = ground
	-- the hit's glow on the deck: a red disc with a white ring, a white-hot core, a red light over the lanes
	local flat = CFrame.Angles(0, 0, math.pi / 2)
	local glow = Kit.holder("EnumaHitGlow", ground() * flat, Vector3.new(0.3, HIT_GLOW, HIT_GLOW))
	glow.Shape, glow.Material, glow.Color, glow.Transparency = Enum.PartType.Cylinder, NEON, RED, 0.35
	Kit.decal(glow, Art.Ring, WHITE, Enum.NormalId.Right)
	tracked[glow] = function()
		return ground() * flat
	end
	local hot = Kit.holder("EnumaHitCore", ground(), Vector3.one * 9)
	hot.Shape, hot.Material, hot.Color, hot.Transparency = Enum.PartType.Ball, NEON, WHITE, 0.05
	tracked[hot] = function()
		return ground() + Vector3.new(0, 2, 0)
	end
	local hitLight = Instance.new("PointLight")
	hitLight.Color, hitLight.Brightness, hitLight.Range, hitLight.Shadows = RED, 3, 50, false
	hitLight.Parent = spot
	local burstEmitter = Kit.emitter(spot, {
		Name = "EnumaHitBurst",
		Texture = Art.Spark,
		Color = ColorSequence.new(WHITE, RED),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(75, 75),
		Size = sequence(0, 6, 1, 0), -- the spikes
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(60, 130),
		Drag = 2,
		Acceleration = Vector3.new(0, -90, 0),
		Rate = 45,
		Enabled = true,
	})
	local smokeEmitter = Kit.emitter(spot, {
		Name = "EnumaHitSmoke",
		Texture = Art.Dust,
		Color = ColorSequence.new(DARK, Color3.fromRGB(70, 56, 58)),
		LightInfluence = 0.3,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(60, 60),
		Size = sequence(0, 12, 1, 30),
		Transparency = sequence(0, 0.2, 1, 1),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(10, 24),
		Drag = 1.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		Rate = 28,
		Enabled = true,
	})
	local total = 0
	local smoke = Kit.emitter(sheath, {
		Name = "Smoke",
		Texture = Art.Dust,
		Color = ColorSequence.new(DARK, RED),
		LightInfluence = 0,
		LightEmission = 0.4,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = sequence(0, 6, 1, 14),
		Transparency = sequence(0, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(10, 30),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
		Rate = 60,
		Enabled = true,
	})
	total += (60 + 45 * 0.6 + 28 * 1.3) * BEAM
	-- the white full flash at 3.0 s (the sheet's key 7): the impact's flash white, the red dim lifted under it
	Kit.impact("Enuma", Arena.Center, 1.0, 20, BEAM, 0, ENUMA_FLASH) -- a full white frame (the sheet's key 7)
	if dim then
		dim.LiftAt = os.clock()
	end
	startDim(ENUMA_DIM, BEAM, 0.25) -- a client that missed the charge: the red room for the beam
	roomLight(him() + Vector3.new(0, 30, 0), RED, 2.5, BEAM + 0.3) -- Studio 2026-11-12: at 6 he read flat red
	Kit.after(BEAM, function()
		smoke.Enabled, burstEmitter.Enabled, smokeEmitter.Enabled = false, false, false
		for _, beam in strands do
			beam.Enabled = false
		end
		for _, part in { core, white, outer, sheath, glow, hot } do
			Kit.tween(part, 0.3, { Transparency = 1 })
		end
		Kit.tween(hitLight, 0.3, { Brightness = 0 })
	end)
	Kit.expire(core, BEAM + 0.35)
	Kit.expire(white, BEAM + 0.35)
	Kit.expire(outer, BEAM + 0.35)
	Kit.expire(glow, BEAM + 0.35)
	Kit.expire(hot, BEAM + 0.35)
	Kit.expire(sheath, BEAM + 1.1)
	Kit.expire(spot, BEAM + 1.4)
	return total
end

-- The whole move at once (BossVfxForce "Enuma"): the charge, then the beam when it would fire.
local function playEnuma()
	local count = playCharge()
	local folder, run = effects, generation
	Kit.after(CHARGE, function()
		if current(folder, run) and king then
			playBeam()
		end
	end)
	return count
end

-- Shield Gates ------------------------------------------------------------------------------------------------------------------

local SHIELD_SHAPES = { -- a round, a kite, a tower, a Mesopotamian (wide, bossed) and a small buckler, then round again
	{ Size = Vector3.new(0.6, 9, 9), Shape = Enum.PartType.Cylinder, Roll = math.pi / 2 },
	{ Size = Vector3.new(0.6, 10, 7), Shape = Enum.PartType.Block, Roll = math.pi / 4 },
	{ Size = Vector3.new(0.6, 12, 6), Shape = Enum.PartType.Block, Roll = 0 },
	{ Size = Vector3.new(0.8, 7, 11), Shape = Enum.PartType.Block, Roll = 0 },
	{ Size = Vector3.new(0.6, 6, 6), Shape = Enum.PartType.Cylinder, Roll = math.pi / 2 },
}

local function shatter()
	for _, shield in shields do
		if shield.Parent then
			tracked[shield] = nil
			local at = shield.CFrame
			shield:Destroy()
			for s = 1, SHARDS do
				local a = s / SHARDS * 2 * math.pi
				local piece = pooled("ShieldShard", at, Vector3.new(0.5, 2.4, 2.4), GOLD, 0, 0.6)
				local fling = at * CFrame.new(0, 4 * math.cos(a) - 6, 4 * math.sin(a)) * CFrame.Angles(a, a * 0.5, 0)
				Kit.tween(piece, 0.6, { CFrame = fling }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			end
			local spot = Kit.holder("ShieldBurst", at)
			Kit.expire(spot, 1.2)
			Kit.burst(
				Kit.emitter(spot, {
					Name = "Sparks",
					Texture = Art.Spark,
					Color = ColorSequence.new(GOLD_HI, GOLD),
					LightEmission = 1,
					Size = sequence(0, 1.2, 1, 0),
					Lifetime = NumberRange.new(0.3, 0.6),
					Speed = NumberRange.new(20, 40),
					SpreadAngle = Vector2.new(180, 180),
				}),
				10
			)
		end
	end
	table.clear(shields)
	if shieldRing then
		shieldRing:Destroy()
		shieldRing = nil
	end
	if effects then
		Kit.shakeAt(Arena.Center, 0.5, 20, 0.3) -- BossShake keeps still with effects off
	end
end

-- 5 to 7 shields hover in a ring about his chest, each facing out, turning with the ring; held until BossFortified turns false.
local function playShields()
	-- cue: KingShields (a ring of clangs)
	shatter()
	if reduced() then
		return 0
	end
	local rng = rngFor("Shields")
	local count = rng:NextInteger(SHIELDS_MIN, SHIELDS_MAX)
	local born = os.clock()
	shieldRing = Instance.new("Folder") -- the ring's shields together, shattered together
	shieldRing.Name = "ShieldRing"
	shieldRing.Parent = effects
	for k = 1, count do
		local look = SHIELD_SHAPES[(k - 1) % #SHIELD_SHAPES + 1]
		local a0 = (k - 1) / count * 2 * math.pi
		local lift = 4 * math.sin(k * 1.7)
		local function frame()
			local a = a0 + (os.clock() - born) * SHIELD_TURN
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local at = him() + Vector3.new(0, TIP_HEIGHT * 0.65 + lift, 0) + out * SHIELD_RADIUS
			return CFrame.lookAt(at, at + out) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(look.Roll, 0, 0)
		end
		local shield = Kit.holder("Shield", frame(), look.Size)
		shield.Parent = shieldRing
		shield.Shape = look.Shape
		shield.Material = k % 2 == 0 and Enum.Material.Metal or Enum.Material.DiamondPlate
		shield.Color, shield.Transparency = k % 3 == 0 and GOLD_HI or GOLD, 1
		Kit.tween(shield, 0.35, { Transparency = 0 }, Enum.EasingStyle.Back)
		tracked[shield] = frame
		shields[k] = shield
	end
	Kit.growingRing(
		"ShieldGate",
		CFrame.new(him() + Vector3.new(0, TIP_HEIGHT * 0.65, 0)),
		6,
		50,
		0.6,
		GOLD,
		0,
		Kit.FlatFaces
	)
	return 0
end

-- Runs ---------------------------------------------------------------------------------------------------------------------------

local EVENTS = {
	Portals = playPortals,
	Volley = playVolley,
	Charge = playCharge,
	Beam = playBeam,
	Shields = playShields,
	Gates = playVolley, -- BossVfxForce: a whole move
	Enuma = playEnuma,
}
local LEADS = { Volley = playPortals, Gates = playPortals }

-- The ring opens once: on his call key or BossFortified, whichever comes first.
local function openShields()
	if not (shieldRing and shieldRing.Parent) then
		effects:SetAttribute("LastParticles", playShields())
	end
end
-- The schedule's event names (BossKingPoses) to the plays; shields come from BossFortified instead.
local SCHEDULED = { gates_start = "Portals", gates = "Volley", enuma_start = "Charge", enuma = "Beam" }

local function playEvent(name)
	local play = EVENTS[name]
	if play and effects and king then
		effects:SetAttribute("LastParticles", play())
	end
end

-- Fires the events the move passed between from and to.
local function fire(move, from, to)
	local row = Poses and Poses.Moves[move]
	for _, event in row and row.Events or {} do
		if event.Time > from and event.Time <= to and SCHEDULED[event.Name] then
			playEvent(SCHEDULED[event.Name])
		end
	end
	if move == "shields" and SHIELD_CALL > from and SHIELD_CALL <= to then
		openShields()
	end
end

-- Ea's grooves glow while the drums spin up through the charge and hold through the beam; off otherwise and with effects off.
-- The charge's white ball at Ea's tip (the sheets' enuma keys 4 to 6): from CHARGE_BALL_FROM it grows to the wind-up, one part
-- and a flare while it shows.
local CHARGE_BALL_FROM, CHARGE_BALL = 1.2, { 6, 34 } -- s of enuma; studs across, from to at the hit (proposed)
local CHARGE_BALL_BEAM = 18 -- studs across through the beam: the beam's white source
local chargeBall = nil
local function stepChargeBall(move, localTime)
	-- held at its full size at Ea's tip through the beam (the sheets' keys 7 to 9)
	local on = move == "enuma" and localTime >= CHARGE_BALL_FROM and localTime < CHARGE + BEAM and not reduced()
	if not on then
		if chargeBall then
			chargeBall:Destroy()
			chargeBall = nil
		end
		return
	end
	if not (chargeBall and chargeBall.Parent == effects) then
		chargeBall = Kit.holder("EnumaChargeBall", CFrame.new(king:Tip()), Vector3.one)
		chargeBall.Shape, chargeBall.Material, chargeBall.Color, chargeBall.Transparency =
			Enum.PartType.Ball, NEON, WHITE, 0
		Kit.emitter(chargeBall, {
			Name = "ChargeFlare",
			Texture = Art.Flare,
			Color = ColorSequence.new(WHITE),
			LightEmission = 1,
			LockedToPart = true,
			Speed = NumberRange.new(0),
			Lifetime = NumberRange.new(0.1, 0.14),
			Rotation = NumberRange.new(0, 360),
			Rate = 30,
			Enabled = true,
		})
	end
	local u = math.clamp((localTime - CHARGE_BALL_FROM) / (CHARGE - CHARGE_BALL_FROM), 0, 1)
	local size = localTime >= CHARGE and CHARGE_BALL_BEAM or CHARGE_BALL[1] + (CHARGE_BALL[2] - CHARGE_BALL[1]) * u
	chargeBall.CFrame, chargeBall.Size = CFrame.new(king:Tip()), Vector3.one * size
	-- the glow round it: smaller through the beam, when Ea points at the lanes (Studio 2026-11-12: it filled the view)
	chargeBall.ChargeFlare.Size = NumberSequence.new(size * (localTime >= CHARGE and 1.3 or 1.8))
end

local function stepEaGlow(move, localTime)
	local on = move == "enuma" and localTime < CHARGE + BEAM and Poses.EaShown(move, localTime) and not reduced()
	local part = (on or eaGlow) and eaPart()
	if not part then
		return
	end
	if not (eaGlow and eaGlow.Parent == part) then
		eaGlow = Instance.new("PointLight")
		eaGlow.Name = "EaGlow"
		eaGlow.Color, eaGlow.Range, eaGlow.Shadows = Color3.fromRGB(255, 70, 60), 22, false
		eaGlow.Parent = part
	end
	eaGlow.Enabled = on
	eaGlow.Brightness = on and EA_GLOW_MAX * math.clamp(localTime / CHARGE, 0, 1) or 0
end

-- Fires what the move passed since the last frame.
local function advance(move, t, lastMove, lastTime)
	if move == lastMove and lastTime and t > lastTime then
		if t - lastTime < 0.5 then -- a long hitch skips its effects rather than playing them late
			fire(move, lastTime, t)
		end
	elseif move ~= lastMove and t < 0.5 then -- a new move (or a fresh start early in one, as the capture's)
		fire(move, -1, t)
	end
end

local function clear()
	generation += 1
	endDim()
	dustLine = nil
	table.clear(pools)
	table.clear(ready)
	table.clear(waiting)
	portalsUntil = -math.huge
	hitSpot = nil
	table.clear(hitEmitters)
	table.clear(tracked)
	table.clear(portals)
	table.clear(portalTips)
	if ea and ea.Parent then
		Kit.swingTrail(ea, nil)
	end
	if eaGlow then
		eaGlow.Enabled = false
	end
	if chargeBall then
		chargeBall:Destroy()
		chargeBall = nil
	end
	ea = nil
	table.clear(shields)
	shieldRing = nil
	previousMove, previousTime = nil, nil
end

-- Call with the arena's BossEffects folder and the Client/BossKing.
function BossKingVfx.Start(folder, boss)
	BossVfx.Start(folder, nil) -- points the Kit's helpers at this folder; BossVfx.Step is never called for him
	effects, king = folder, boss
	clear()
	if ReplicatedStorage:GetAttribute(FORTIFIED) == true then
		playEvent("Shields") -- a late join while he is Fortified
	end
end

function BossKingVfx.Stop()
	clear()
	BossVfx.Stop()
	effects, king = nil, nil
end

-- since: seconds since the spawn, nil before it. move, localTime: his move (as Client/BossKing).
function BossKingVfx.Step(since, move, localTime)
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
	-- Ea's Trail in the swing, off otherwise and with effects off (BOSS_EVENT_SPEC "Impact layer")
	local swing = move == "enuma" and localTime >= EA_SWING[1] and localTime <= EA_SWING[2] and not reduced()
	local part = (swing or ea) and eaPart()
	if part then
		Kit.swingTrail(part, swing and king:Tip(), WHITE, RED)
	end
	if ReplicatedStorage:GetAttribute(FORCE) ~= nil then
		return
	end
	stepEaGlow(move, localTime)
	stepChargeBall(move, localTime)
	if since and since >= Event.RiseSeconds then
		advance(move, localTime, previousMove, previousTime)
	end
	-- a ring his call opened that BossFortified never held (no server, or a missed true): gone 1 s into a later move
	if shieldRing and move ~= "shields" and localTime > 1 and ReplicatedStorage:GetAttribute(FORTIFIED) ~= true then
		shatter()
	end
	previousMove, previousTime = move, localTime
end

-- The shields follow the server: open on true, shattered on false (his next move's start) or nil (the event's end).
ReplicatedStorage:GetAttributeChangedSignal(FORTIFIED):Connect(function()
	if not (effects and king) then
		return
	end
	if ReplicatedStorage:GetAttribute(FORTIFIED) == true then
		openShields()
	else
		shatter()
	end
end)

-- Deferred: Client/BossVfx's own listener clears the shared folder first.
ReplicatedStorage:GetAttributeChangedSignal(FORCE):Connect(function()
	task.defer(function()
		local value = ReplicatedStorage:GetAttribute(FORCE)
		if value == nil or not (effects and king) then
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

return BossKingVfx
