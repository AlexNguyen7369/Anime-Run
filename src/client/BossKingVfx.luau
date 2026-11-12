--!nonstrict
-- The Golden King's effects (design doc 4.37 "Third boss", docs/BOSS_EVENT_SPEC.md "The Golden King"). Visual only: nothing here
-- reads back into damage. Timed from BossKingPoses' schedule events, which server time alone decides, and built with Client/BossVfx's
-- helpers (BossVfx.Kit) in the arena's BossEffects folder, after Client/BossMageVfx's spam model. gates_start opens 12 to 20 golden
-- ripple portals around and behind him; gates fires the 2 s volley window: every 0.15 s, 14 times, 7 to 10 weapons
-- as gold projectiles tweened in straight lines from a portal to spots over the whole room, every third a gold beam instead.
-- enuma_start starts the red charge (a ColorCorrection tint, wind lines drawn into him) until enuma fires the red-black cyclone beam
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
-- Charge, Beam or Shields plays that event at once; Gates (portals and volleys) or Enuma (charge, then beam) a whole move. Not drawn yet: the drums' spin on Ea (pose data of the bake), the sky's own tint
-- (Client/BiomeEnvironment owns Lighting; the ColorCorrection carries the red).
local HttpService = game:GetService("HttpService")
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
local PORTALS_MIN, PORTALS_MAX = 12, 20
local PORTAL_SIZES = { 17.5, 12.5, 8.75 } -- studs across: 1.25 x the first 14 / 10 / 7 (owner 2026-11-12, proposed)
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
local WIND_CLIMB = 1.2 -- s for a ribbon to climb from his feet to Ea's tip
local WIND_RADIUS_FEET, WIND_RADIUS_TIP, WIND_WIDTH = 12, 5, 1.6 -- studs
local SHIELD_CALL = 0.6 -- s of shields: his call key (rework keys), the ring opens
local EA_GLOW_MAX = 4 -- EaGlow's brightness at the end of the charge, from 0 at its start (proposed)
local FLASH_LEAD = 0.08 -- s before the beam: the white flash (proposed)
-- Stronger Gates and Enuma (owner 2026-11-12 after playing; design doc 4.37 "Golden King effects stronger", BOSS_EVENT_SPEC "Golden
-- King effects", proposed). Order: a portal opens to full size, then its weapon tip pushes through, then it may fire.
local PORTAL_GROW, PORTAL_OPEN = 0.12, 0.25 -- s: a dot to a small ring, then to full size
local TIP_PUSH, TIP_READY = 0.3, 0.1 -- s the tip takes to push through; s into the push the portal may fire (the tip shows)
local EMERGE, EMERGE_STUDS = 0.1, 2 -- s and studs a weapon slides out of its portal before it flies
local STREAK_CORE, STREAK_SHEATH = 1.05, 3 -- studs across a streak's white core and gold sheath (1.5 x 0.7 and 2)
local HIT_FLASH, HIT_CORE, HIT_SECONDS = 15, 6, 0.3 -- studs across a hit's gold flash and its white core, s
local RING_FROM, RING_TO, RING_SECONDS = 6, 34, 0.36 -- studs across a hit's gold shock ring as it grows, s
local SPARKS_PER_HIT, DUST_PER_HIT = 6, 2
local BEAM_CORE, BEAM_RED, BEAM_CYCLONE = 2.6, 7, 15 -- studs across Enuma's white core, red beam and dark cyclone
local CYCLONE_TURN = 9 -- radians a second the cyclone rolls about the beam
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
	task.delay(seconds + 0.03, function()
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

-- Plays `play` seconds from now while this arena's effects last, adding its particles to the event's count.
local function later(seconds, play)
	local mine = effects
	task.delay(seconds, function()
		if mine and effects == mine then
			mine:SetAttribute("LastParticles", (mine:GetAttribute("LastParticles") or 0) + play())
		end
	end)
end

-- A glowing stick from a to b: a Neon core inside a wider, softer Neon sheath, both fading out.
local function streak(name, a, b, core, sheath, coreColor, sheathColor, seconds)
	local frame, length = CFrame.lookAt((a + b) / 2, b), (b - a).Magnitude
	pooled(name, frame, Vector3.new(sheath, sheath, length + sheath * 0.5), sheathColor, 0.4, seconds)
	pooled(name .. "Core", frame, Vector3.new(core, core, length + core), coreColor, 0, seconds)
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

-- Where a weapon or streak lands: a gold flash with a white core, a gold shock ring racing out, gold sparks and dust.
local function hit(at)
	local flat = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	pooled("StrikeFlash", flat, Vector3.new(0.2, HIT_FLASH, HIT_FLASH), GOLD, 0.05, HIT_SECONDS, disc)
	pooled(
		"StrikeFlashCore",
		flat + Vector3.new(0, 0.1, 0),
		Vector3.new(0.25, HIT_CORE, HIT_CORE),
		WHITE,
		0,
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
	local hold = PORTAL_LEAD + GATES_WINDOW + 0.3
	portalsUntil = os.clock() + hold
	for k = 1, count do
		local size = PORTAL_SIZES[(k - 1) % #PORTAL_SIZES + 1]
		local a = math.rad(-150 + 300 * (k - 1) / (count - 1)) + rng:NextNumber(-0.08, 0.08) -- 0 is his front (-Z)
		local out = Vector3.new(math.sin(a), 0, -math.cos(a))
		local anchor = him() + out * rng:NextNumber(14, 30) + Vector3.new(0, rng:NextNumber(10, Arena.BossHeight), 0)
		local frame = CFrame.lookAt(anchor, anchor + out)
		local turn = PORTAL_TURN * (k % 2 == 0 and 1 or -1)
		-- The opening, built when it comes in the cascade: a bright dot, a small ring, full size (Quad, no overshoot past the drawn
		-- size), then the weapon tip through (owner 2026-11-12: portal, then weapon, then shot).
		local opensAt = cascade * math.sqrt((k - 1) / (count - 1))
		local mine = effects
		task.delay(opensAt, function()
			if effects ~= mine or not (mine and mine.Parent) then
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
			local tip = Kit.holder("PortalTip", frame * CFrame.new(0, 0, size * 0.1), Vector3.new(0.6, 0.6, size * 0.6))
			tip.Material, tip.Color = Enum.Material.Metal, GOLD_HI
			Kit.tween(part, PORTAL_GROW, { Size = Vector3.new(size * 0.3, size * 0.3, 0.3) })
			task.delay(PORTAL_GROW, function()
				if part.Parent then
					Kit.tween(part, PORTAL_OPEN, { Size = Vector3.new(size, size, 0.3) })
				end
			end)
			task.delay(PORTAL_GROW + PORTAL_OPEN, function()
				if part.Parent then
					Kit.tween(tip, TIP_PUSH, { CFrame = frame * CFrame.new(0, 0, -size * 0.3), Transparency = 0 })
				end
			end)
			task.delay(PORTAL_GROW + PORTAL_OPEN + TIP_READY, function()
				if part.Parent and effects == mine then
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
			task.delay(left - 0.3, function()
				shimmer.Enabled = false
			end)
			task.delay(left - 0.3, function()
				Kit.tween(front, 0.3, { Transparency = 1 })
				Kit.tween(back, 0.3, { Transparency = 1 })
				Kit.tween(tip, 0.3, { Transparency = 1 })
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
		a0.Position, a1.Position = Vector3.new(0, 1.2, 0), Vector3.new(0, -1.2, 0)
		a0.Parent, a1.Parent = part, part
		trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(GOLD_HI, GOLD)
		trail.Transparency = sequence(0, 0.2, 1, 1)
		trail.Lifetime = 0.25
		trail.LightEmission = 1
		trail.Parent = part
	end
	trail.Enabled = true
end

-- One shot n from a ready portal to target: its tip flashes, then a weapon (or, every third, a streak) and the hit where it lands.
local function fireShot(portal, target, n)
	local tip = portalTips[portal]
	if tip and tip.Parent then -- the firing flash
		tip.Material = NEON
		task.delay(0.08, function()
			tip.Material = Enum.Material.Metal
		end)
	end
	local from = portal.Position
	if n % 3 == 0 then
		streak("Streak", from, target, STREAK_CORE, STREAK_SHEATH, WHITE, GOLD, 0.25) -- thinner than the weapons, so they lead
		return hit(target)
	end
	shoot(from, target, n)
	local mine = effects
	task.delay(EMERGE + SHOT_SECONDS, function()
		if effects == mine and mine then
			hit(target)
		end
	end)
	return SPARKS_PER_HIT + DUST_PER_HIT
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
			roomLight(him() + Vector3.new(0, 30, 0), GOLD, 2.5, 0.2)
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
	Kit.regrade(
		{ TintColor = Color3.fromRGB(255, 120, 110), Contrast = 0.15, Saturation = 0.2 },
		0.6,
		CHARGE + BEAM - 0.6,
		0.6
	)
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
	Kit.tween(light, CHARGE, { Brightness = 3 })
	Kit.pulseEdges(RED, 0.45, CHARGE / 3, 3)
	task.delay(CHARGE, function()
		wind.Enabled = false
	end)
	-- The charge ends in a white flash at Ea's tip, just before the beam: its own part each Enuma (not pooled), the effects
	-- setting read when it fires.
	local mine = effects
	task.delay(CHARGE - FLASH_LEAD, function()
		if effects == mine and mine and mine.Parent and king and not reduced() then
			local white = Kit.holder("EnumaChargeFlash", CFrame.new(king:Tip()), Vector3.one * 8)
			white.Shape, white.Material, white.Color, white.Transparency = Enum.PartType.Ball, NEON, WHITE, 0
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
	core.Material, core.Color, core.Transparency = NEON, RED, 0.2
	tracked[core] = straight
	local white = Kit.holder("EnumaBeamCore", frame(0), Vector3.new(BEAM_CORE, BEAM_CORE, length))
	white.Material, white.Color, white.Transparency = NEON, WHITE, 0
	tracked[white] = straight
	local sheath = Kit.holder("EnumaCyclone", frame(0), Vector3.new(BEAM_CYCLONE, BEAM_CYCLONE, length))
	sheath.Material, sheath.Color, sheath.Transparency = Enum.Material.SmoothPlastic, DARK, 0.45
	tracked[sheath] = function()
		return frame((os.clock() - born) * CYCLONE_TURN) -- the sheath rolls: the cyclone
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
	local burstEmitter = Kit.emitter(spot, {
		Name = "EnumaHitBurst",
		Texture = Art.Spark,
		Color = ColorSequence.new(WHITE, RED),
		LightEmission = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(75, 75),
		Size = sequence(0, 4, 1, 0),
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
		Size = sequence(0, 10, 1, 26),
		Transparency = sequence(0, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(10, 24),
		Drag = 1.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
		Rate = 20,
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
	task.delay(BEAM, function()
		smoke.Enabled = false
	end)
	total += (60 + 45 * 0.6 + 20 * 1.3) * BEAM
	Kit.impact("Enuma", Arena.Center, 1.0, 20, BEAM)
	roomLight(him() + Vector3.new(0, 30, 0), RED, 6, BEAM + 0.3) -- twice as bright (owner 2026-11-12)
	task.delay(BEAM, function()
		burstEmitter.Enabled, smokeEmitter.Enabled = false, false
		Kit.tween(core, 0.3, { Transparency = 1 })
		Kit.tween(white, 0.3, { Transparency = 1 })
		Kit.tween(sheath, 0.3, { Transparency = 1 })
	end)
	Kit.expire(core, BEAM + 0.35)
	Kit.expire(white, BEAM + 0.35)
	Kit.expire(sheath, BEAM + 1.1)
	Kit.expire(spot, BEAM + 1.4)
	return total
end

-- The whole move at once (BossVfxForce "Enuma"): the charge, then the beam when it would fire.
local function playEnuma()
	local count = playCharge()
	local folder = effects
	task.delay(CHARGE, function()
		if effects and effects == folder and king then
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
	elseif move ~= lastMove and lastMove and t < 0.5 then
		fire(move, -1, t)
	end
end

local function clear()
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
	if not effects then
		return
	end
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
