--!nonstrict
-- The Golden King's effects (design doc 4.37 "Third boss", docs/BOSS_EVENT_SPEC.md "The Golden King"). Visual only: nothing here
-- reads back into damage. Timed from BossKingPoses' schedule events, which server time alone decides, and built with Client/BossVfx's
-- helpers (BossVfx.Kit) in the arena's BossEffects folder, after Client/BossMageVfx's spam model. gates_start opens 12 to 20 golden
-- ripple portals around and behind him; gates fires the 2 s volley window: every 0.15 s, 14 times, 7 to 10 weapons (3 under REDUCED
-- EFFECTS) as gold projectiles tweened in straight lines from a portal to spots over the whole room, every third a gold beam instead.
-- enuma_start starts the red charge (a ColorCorrection tint, wind lines drawn into him) until enuma fires the red-black cyclone beam
-- that sweeps the room over the Window. The shields follow the ReplicatedStorage attribute BossFortified, not the schedule: 5 to 7
-- gold shields of different shapes orbit him while it is true and shatter when it turns false (the shields stay under REDUCED EFFECTS).
-- Spots and portal places come from a seed of the schedule start and the cycle, so every client draws the same ones. All sizes, counts
-- and colours are placeholders to judge from a capture. Debug field: BossEffects attribute LastStrikes, JSON { Move, Strikes }.
-- BossVfxForce (client-local test attribute, as Client/BossVfx): not nil holds off the schedule; Portals, Volley (with its portals),
-- Charge, Beam or Shields plays that event at once. Not drawn yet: the drums' spin on Ea (pose data of the bake), the sky's own tint
-- (Client/BiomeEnvironment owns Lighting; the ColorCorrection carries the red).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig")).For("boss_king")
local Art = require(Shared:WaitForChild("BossVfxArt"))
local Event = require(Shared:WaitForChild("BossEventConfig"))
local posesModule = Shared:FindFirstChild("BossKingPoses")
local Poses = posesModule and require(posesModule) or nil
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
local PER_STRIKE_MIN, PER_STRIKE_MAX, PER_STRIKE_REDUCED = 7, 10, 3
local PORTALS_MIN, PORTALS_MAX = 12, 20
local PORTAL_SIZES = { 14, 10, 7 } -- studs across
local SHOT_SECONDS = 0.22 -- a projectile's flight
local SHIELDS_MIN, SHIELDS_MAX = 5, 7
local SHIELD_RADIUS, SHIELD_TURN = 17, 0.7 -- studs from him, radians a second
local SHARDS = 5 -- a shattering shield's pieces
local SPOT_MAX = Arena.WallRadius - 4 -- the whole room: centre, lanes and walkway
local SALT = { Portals = 1, Gates = 2, Shields = 3 }
local TIP_HEIGHT = Arena.BossHeight * 0.85 -- where Ea is held, over his feet, until the bake names the joint

local BossKingVfx = {}

local effects, king = nil, nil
local tracked = {} -- part -> function giving its CFrame each frame
local portals = {} -- the open portals, the volley's origins
local shields = {} -- the orbiting shields while Fortified
local pool = {} -- idle pooled parts (Transparency 1) in this arena's folder
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

-- The volleys: { T, Spots } for each of the 14, T seconds after the window starts. Every volley takes all its draws, so REDUCED
-- EFFECTS keeps the same spots, only fewer of them. Spots are area-uniform over the room's floor.
local function plan()
	local rng, few, list = rngFor("Gates"), reduced(), {}
	for j = 1, STRIKE_COUNT do
		local n = few and PER_STRIKE_REDUCED or rng:NextInteger(PER_STRIKE_MIN, PER_STRIKE_MAX)
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

-- A Neon part from the pool (or a new one), back to the pool `seconds` later. Parts the folder lost are dropped.
local function pooled(name, cframe, size, color, transparency, seconds)
	local part = table.remove(pool)
	while part and part.Parent ~= effects do
		part = table.remove(pool)
	end
	if part then
		part.Name, part.CFrame, part.Size = name, cframe, size
	else
		part = Kit.holder(name, cframe, size)
		part.Material = NEON
	end
	part.Color, part.Transparency = color, transparency
	Kit.tween(part, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(seconds + 0.03, function()
		if part.Parent == effects then
			part.Name, part.Transparency = "Pooled", 1
			local trail = part:FindFirstChildOfClass("Trail")
			if trail then
				trail.Enabled = false
			end
			table.insert(pool, part)
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

-- A flat glowing disc where a weapon or beam lands.
local function flash(at, color, size, seconds)
	pooled(
		"StrikeFlash",
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.2, size, size),
		color,
		0.1,
		seconds
	)
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

-- Gates of Babylon --------------------------------------------------------------------------------------------------------------

-- Golden ripple portals open around and behind him, facing out, held through the lead and the volleys: a ring part with a gold
-- shimmer and a weapon's tip showing in each.
local function playPortals()
	table.clear(portals)
	local rng, few = rngFor("Portals"), reduced()
	local count = rng:NextInteger(PORTALS_MIN, PORTALS_MAX)
	local hold = PORTAL_LEAD + GATES_WINDOW + 0.3
	for k = 1, count do
		local size = PORTAL_SIZES[(k - 1) % #PORTAL_SIZES + 1]
		local a = math.rad(-150 + 300 * (k - 1) / (count - 1)) + rng:NextNumber(-0.08, 0.08) -- 0 is his front (-Z)
		local out = Vector3.new(math.sin(a), 0, -math.cos(a))
		local anchor = him() + out * rng:NextNumber(14, 30) + Vector3.new(0, rng:NextNumber(10, Arena.BossHeight), 0)
		local frame = CFrame.lookAt(anchor, anchor + out)
		local part = Kit.holder("Portal", frame, Vector3.new(1, 1, 0.3))
		local front = Kit.decal(part, Art.Ring, k % 2 == 0 and GOLD or GOLD_HI, Enum.NormalId.Front)
		local back = Kit.decal(part, Art.Ring, k % 2 == 0 and GOLD or GOLD_HI, Enum.NormalId.Back)
		Kit.tween(part, 0.35, { Size = Vector3.new(size, size, 0.3) }, Enum.EasingStyle.Back)
		local tip = Kit.holder("PortalTip", frame * CFrame.new(0, 0, -size * 0.3), Vector3.new(0.6, 0.6, size * 0.6))
		tip.Material, tip.Color, tip.Transparency = Enum.Material.Metal, GOLD_HI, 0
		if not few then
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
			task.delay(hold - 0.3, function()
				shimmer.Enabled = false
			end)
		end
		task.delay(hold - 0.3, function()
			Kit.tween(front, 0.3, { Transparency = 1 })
			Kit.tween(back, 0.3, { Transparency = 1 })
			Kit.tween(tip, 0.3, { Transparency = 1 })
		end)
		Kit.expire(part, hold)
		Kit.expire(tip, hold)
		portals[k] = part
	end
	return few and 0 or math.ceil(count * 6 * hold)
end

-- A pooled gold projectile with a trail, flown from a to b in a straight line.
local function shoot(from, to)
	local frame = CFrame.lookAt(from, to)
	local part = pooled("Weapon", frame, Vector3.new(0.9, 0.9, 7), GOLD_HI, 0, SHOT_SECONDS + 0.2)
	local trail = part:FindFirstChildOfClass("Trail")
	if not trail then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.6, 0), Vector3.new(0, -0.6, 0)
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
	Kit.tween(part, SHOT_SECONDS, { CFrame = CFrame.lookAt(to, to + frame.LookVector) }, Enum.EasingStyle.Linear)
end

local function playVolley()
	-- cue: KingGates (a rush of blades)
	local few = reduced()
	local list = plan()
	logStrikes(list)
	for j, strike in list do
		later(strike.T, function()
			for k, target in strike.Spots do
				local portal = #portals > 0 and portals[(j + k - 2) % #portals + 1]
				local from = portal and portal.Parent and portal.Position or him() + Vector3.new(0, TIP_HEIGHT, 0)
				if (j + k) % 3 == 0 then
					streak("GateBeam", from, target, 1.2, 3.6, WHITE, GOLD, 0.25)
					flash(target, GOLD, 9, 0.3)
				else
					shoot(from, target)
					task.delay(SHOT_SECONDS, function()
						if effects then
							flash(target, GOLD_HI, 7, 0.25)
						end
					end)
				end
			end
			roomLight(him() + Vector3.new(0, 30, 0), GOLD, few and 1 or 2, 0.2)
			if not few then
				Kit.shakeAt(Arena.Center, 0.1, 18, 0.15)
			end
			return 0
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
	local function tip()
		return king:Frame("Ea")
	end
	local part = Kit.holder("EnumaWind", tip(), Vector3.new(90, 90, 90))
	tracked[part] = tip
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
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = RED, 0, 90, false
	light.Parent = part
	Kit.tween(light, CHARGE, { Brightness = 3 })
	task.delay(CHARGE, function()
		wind.Enabled = false
	end)
	Kit.expire(part, CHARGE + 0.8)
	Kit.pulseEdges(RED, 0.45, CHARGE / 3, 3)
	return math.ceil(rate * CHARGE)
end

-- The beam: a red core in a dark sheath from Ea's tip, pitched down to the lanes, swept once around the room over the Window; dark
-- smoke streams off it.
local function playBeam()
	-- cue: KingEnuma (a tearing roar)
	local few = reduced()
	local length = Arena.WallRadius * 1.1
	local born = os.clock()
	local function frame(roll)
		local origin = king:Frame("Ea").Position
		local a = (os.clock() - born) / BEAM * 2 * math.pi
		local pitch = -math.atan((origin.Y - Arena.Y) / (Arena.InnerRadius + Arena.Width / 2))
		local look = CFrame.new(origin) * CFrame.Angles(0, -a, 0) * CFrame.Angles(pitch, 0, 0)
		return look * CFrame.new(0, 0, -length / 2) * CFrame.Angles(0, 0, roll)
	end
	local core = Kit.holder("EnumaBeam", frame(0), Vector3.new(6, 6, length))
	core.Material, core.Color, core.Transparency = NEON, RED, 0
	tracked[core] = function()
		return frame(0)
	end
	local sheath = Kit.holder("EnumaCyclone", frame(0), Vector3.new(14, 14, length))
	sheath.Material, sheath.Color, sheath.Transparency = Enum.Material.SmoothPlastic, DARK, 0.35
	tracked[sheath] = function()
		return frame((os.clock() - born) * 9) -- the sheath spins: the cyclone
	end
	local total = 0
	if not few then
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
		total += 60 * BEAM
		Kit.shakeAt(Arena.Center, 1.0, 20, BEAM)
	end
	roomLight(him() + Vector3.new(0, 30, 0), RED, few and 1.5 or 3, BEAM + 0.3)
	task.delay(BEAM, function()
		Kit.tween(core, 0.3, { Transparency = 1 })
		Kit.tween(sheath, 0.3, { Transparency = 1 })
	end)
	Kit.expire(core, BEAM + 0.35)
	Kit.expire(sheath, BEAM + 1.1)
	return total
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
	local few = reduced()
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
			if not few then
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
	end
	table.clear(shields)
	if effects then
		Kit.shakeAt(Arena.Center, few and 0 or 0.5, 20, 0.3)
	end
end

-- 5 to 7 shields hover in a ring about his chest, each facing out, turning with the ring; held until BossFortified turns false.
local function playShields()
	-- cue: KingShields (a ring of clangs)
	shatter()
	local rng = rngFor("Shields")
	local count = rng:NextInteger(SHIELDS_MIN, SHIELDS_MAX)
	local born = os.clock()
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

local EVENTS =
	{ Portals = playPortals, Volley = playVolley, Charge = playCharge, Beam = playBeam, Shields = playShields }
local LEADS = { Volley = playPortals }
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
	table.clear(pool)
	table.clear(tracked)
	table.clear(portals)
	table.clear(shields)
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
	if ReplicatedStorage:GetAttribute(FORCE) ~= nil then
		return
	end
	if since and since >= Event.RiseSeconds then
		advance(move, localTime, previousMove, previousTime)
	end
	previousMove, previousTime = move, localTime
end

-- The shields follow the server: open on true, shattered on false (his next move's start) or nil (the event's end).
ReplicatedStorage:GetAttributeChangedSignal(FORTIFIED):Connect(function()
	if not (effects and king) then
		return
	end
	if ReplicatedStorage:GetAttribute(FORTIFIED) == true then
		playEvent("Shields")
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
