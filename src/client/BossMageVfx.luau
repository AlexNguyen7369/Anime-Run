--!nonstrict
-- The Elf Mage's effects (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"). Visual only: nothing here reads
-- back into damage. Timed from BossMagePoses, which server time alone decides, and built with Client/BossVfx's helpers (BossVfx.Kit)
-- in the arena's BossEffects folder. Each move has a lead cue before its event: lightning marks its floor spots 1.0 s ahead, the golem
-- gathers motes from 2.0 s of its move, the barrage opens its magic circles 1.2 s ahead. Spots come from a seed of the schedule
-- start and the cycle, so every client draws the same ones. All sizes, counts and colours are placeholders to judge from a capture.
-- BossVfxForce (client-local test attribute, as Client/BossVfx): not nil holds off the schedule; Lightning, Slam or Barrage plays
-- that event with its lead cue at once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig")).For("boss_mage")
local Art = require(Shared:WaitForChild("BossVfxArt"))
local MageArt = require(Shared:WaitForChild("BossMageArt"))
local Event = require(Shared:WaitForChild("BossEventConfig"))
local Poses = require(Shared:WaitForChild("BossMagePoses"))
local BossVfx = require(script.Parent:WaitForChild("BossVfx"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local Kit = BossVfx.Kit
local sequence = Kit.sequence
local FORCE = "BossVfxForce"
local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)
local VIOLET, PURPLE = Color3.fromRGB(176, 84, 255), Color3.fromRGB(110, 36, 220)
local ICE, BLUE = Color3.fromRGB(205, 232, 255), Color3.fromRGB(90, 150, 255) -- the barrage's white and blue
local DUST = Color3.fromRGB(196, 158, 116) -- the colosseum's ochre stone

local function eventTime(move)
	return Poses.Moves[move].Events[1].Time
end
local LIGHTNING_AT, SLAM_AT, BARRAGE_AT = eventTime("lightning"), eventTime("golem"), eventTime("barrage")
local MARK_LEAD, GATHER_FROM, CIRCLE_LEAD = 1.0, 2.0, 1.2
local STRIKES, STRIKES_REDUCED = 10, 4 -- bolts; the marks stay all 10 under REDUCED EFFECTS: they are the telegraph
local BOLT_TOP = 95 -- studs over the floor: the bolts fall from the dome
local BOLT_KINKS = 4
local CIRCLES, CIRCLES_REDUCED = 6, 3
local CIRCLE_SIZES = { 24, 16, 10 } -- studs across: 3 sizes, as the rules ask
local SPOT_MIN, SPOT_MAX = Arena.InnerRadius + 3, Arena.InnerRadius + Arena.Width - 3 -- over the lanes
local SALT = { Lightning = 1, Barrage = 2 }
local STAFF_TIP = Vector3.new(Poses.Bind.Staff.Tip[1], Poses.Bind.Staff.Tip[2], Poses.Bind.Staff.Tip[3])

local BossMageVfx = {}

local effects, mage = nil, nil
local tracked = {} -- part -> function giving its CFrame each frame
local circles = {} -- the barrage's open circles, its beams' origins
local previousMove, previousTime = nil, nil

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

local function spots(name, count)
	local rng, list = rngFor(name), {}
	for k = 1, count do
		local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(SPOT_MIN, SPOT_MAX)
		list[k] = Vector3.new(Arena.Center.X + r * math.cos(a), Arena.Y + 0.15, Arena.Center.Z - r * math.sin(a))
	end
	return list, rng
end

-- A glowing stick from a to b: a Neon core inside a wider, softer Neon sheath, both fading out.
local function streak(name, a, b, core, sheath, coreColor, sheathColor, seconds)
	local frame, length = CFrame.lookAt((a + b) / 2, b), (b - a).Magnitude
	local outer = Kit.holder(name, frame, Vector3.new(sheath, sheath, length + sheath * 0.5))
	outer.Material, outer.Color, outer.Transparency = NEON, sheathColor, 0.4
	local inner = Kit.holder(name .. "Core", frame, Vector3.new(core, core, length + core))
	inner.Material, inner.Color, inner.Transparency = NEON, coreColor, 0
	Kit.tween(outer, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Kit.tween(inner, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Kit.expire(outer, seconds + 0.05)
	Kit.expire(inner, seconds + 0.05)
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

local function flare(spot, color, size, count)
	return Kit.burst(
		Kit.emitter(spot, {
			Name = "Flash",
			Texture = Art.Flare,
			Color = ColorSequence.new(WHITE, color),
			LightEmission = 1,
			Size = sequence(0, size * 0.6, 0.3, size, 1, size * 0.8),
			Transparency = sequence(0, 0, 1, 1),
			Lifetime = NumberRange.new(0.15, 0.3),
			Rotation = NumberRange.new(0, 360),
			Speed = NumberRange.new(0),
			ZOffset = 2,
		}),
		count
	)
end

local function sparks(spot, color, speed, count)
	return Kit.burst(
		Kit.emitter(spot, {
			Name = "Sparks",
			Texture = Art.Spark,
			Color = ColorSequence.new(WHITE, color),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(70, 70),
			Size = sequence(0, 2.5, 1, 0.3),
			Lifetime = NumberRange.new(0.25, 0.5),
			Speed = NumberRange.new(speed * 0.5, speed),
			Drag = 2,
			Acceleration = Vector3.new(0, -60, 0),
		}),
		count
	)
end

-- Lightning --------------------------------------------------------------------------------------------------------------------

-- 1.0 s ahead: a purple ring closing in on a white core at every strike spot.
local function playMarks()
	for _, at in spots("Lightning", STRIKES) do
		local rim = Kit.holder("StrikeMark", CFrame.new(at), Vector3.new(22, 0.2, 22))
		Kit.decal(rim, Art.Ring, VIOLET, Enum.NormalId.Top)
		Kit.tween(rim, MARK_LEAD, { Size = Vector3.new(11, 0.2, 11) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Kit.expire(rim, MARK_LEAD + 0.15)
		local core =
			Kit.holder("StrikeCore", CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.12, 2, 2))
		core.Shape, core.Material, core.Color, core.Transparency = Enum.PartType.Cylinder, NEON, WHITE, 0.15
		Kit.tween(core, MARK_LEAD, { Size = Vector3.new(0.12, 7, 7) }, Enum.EasingStyle.Sine)
		Kit.expire(core, MARK_LEAD + 0.15)
	end
	return 0
end

local function playLightning()
	-- cue: MageLightning (a crack of thunder)
	local few = reduced()
	local list, rng = spots("Lightning", STRIKES)
	local total = 0
	for k, at in list do
		if k <= (few and STRIKES_REDUCED or STRIKES) then
			local points = { at + Vector3.new(rng:NextNumber(-14, 14), BOLT_TOP, rng:NextNumber(-14, 14)) }
			for i = 1, BOLT_KINKS - 1 do
				local p = points[1]:Lerp(at, i / BOLT_KINKS)
				table.insert(points, p + Vector3.new(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7)))
			end
			table.insert(points, at)
			for i = 1, #points - 1 do
				streak("Bolt", points[i], points[i + 1], 1.4, 4.5, WHITE, VIOLET, 0.35)
			end
		end
		if not few then
			local spot = Kit.holder("StrikeSpot", CFrame.new(at), Vector3.new(6, 1, 6))
			Kit.expire(spot, 1)
			total += flare(spot, VIOLET, 26, 1)
			total += sparks(spot, PURPLE, 70, 5)
			Kit.growingRing("StrikeRing", CFrame.new(at), 6, 26, 0.45, VIOLET, 0, Kit.FlatFaces)
		end
	end
	roomLight(Vector3.new(Arena.Center.X, Arena.Y + 50, Arena.Center.Z), VIOLET, few and 3 or 8, 0.5)
	if not few then
		Kit.regrade({ TintColor = Color3.fromRGB(222, 196, 255), Brightness = 0.06, Contrast = 0.1 }, 0.05, 0.12, 0.55)
	end
	Kit.shakeAt(Arena.Center, 0.9, 20, 0.4)
	return total
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
	task.delay(seconds, function()
		motes.Enabled = false
	end)
	Kit.expire(part, seconds + 0.7)
	return math.ceil(rate * seconds)
end

local function playSlam()
	-- cue: GolemSlam (a deep thud)
	local few = reduced()
	local fist = mage:GolemFrame("FistR").Position:Lerp(mage:GolemFrame("FistL").Position, 0.5)
	local at = Vector3.new(fist.X, Arena.Y + 0.3, fist.Z)
	-- Across the lanes: from the golem's spot to past the ring's far side
	local reach = 2 * (Arena.InnerRadius + Arena.Width + ((at - Arena.Center) * Vector3.new(1, 0, 1)).Magnitude)
	Kit.growingRing("SlamRing", CFrame.new(at), 12, reach, 0.9, WHITE, 0, Kit.FlatFaces)
	local total = 0
	if not few then
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
	end
	Kit.shakeAt(at, 1.6, 20, 0.5)
	return total
end

-- Barrage ------------------------------------------------------------------------------------------------------------------------

-- 1.2 s ahead: magic circles of 3 sizes open in a fan around her, facing out, turning, riding her bob.
local function playCircles()
	local few = reduced()
	table.clear(circles)
	local count = few and CIRCLES_REDUCED or CIRCLES
	for k = 1, count do
		local size = CIRCLE_SIZES[(k - 1) % #CIRCLE_SIZES + 1]
		local a = math.rad(-120 + 240 * (k - 1) / math.max(1, count - 1)) -- 0 is her front (-Z)
		local out = Vector3.new(math.sin(a), 0, -math.cos(a))
		local offset = out * (18 + size * 0.4) + Vector3.new(0, 18 + 24 * ((k * 0.618) % 1), 0)
		local turn = (k % 2 == 0 and 1 or -1) * math.rad(90)
		local born = os.clock()
		local function frame()
			local anchor = mage.Her.Anchor.Position + offset
			return CFrame.lookAt(anchor, anchor + out) * CFrame.Angles(0, 0, turn * (os.clock() - born))
		end
		local part = Kit.holder("MagicCircle", frame(), Vector3.new(1, 1, 0.2))
		tracked[part] = frame
		local front = Kit.decal(part, MageArt.MagicCircle, k % 2 == 0 and BLUE or ICE, Enum.NormalId.Front)
		local back = Kit.decal(part, MageArt.MagicCircle, k % 2 == 0 and BLUE or ICE, Enum.NormalId.Back)
		Kit.tween(part, 0.35, { Size = Vector3.new(size, size, 0.2) }, Enum.EasingStyle.Back)
		task.delay(CIRCLE_LEAD + 0.25, function()
			Kit.tween(front, 0.3, { Transparency = 1 })
			Kit.tween(back, 0.3, { Transparency = 1 })
		end)
		Kit.expire(part, CIRCLE_LEAD + 0.6)
		circles[k] = part
	end
	return 0
end

local function playBarrage()
	-- cue: MageBarrage (a volley of zaps)
	local few = reduced()
	local count = few and CIRCLES_REDUCED or CIRCLES
	local targets = spots("Barrage", count)
	local total = 0
	for k, target in targets do
		local circle = circles[k]
		local from = circle and circle.Parent and circle.Position or mage:Point("Staff", STAFF_TIP)
		streak("BarrageBeam", from, target, 1.6, 5, WHITE, k % 2 == 0 and BLUE or ICE, 0.45)
		if not few then
			local spot = Kit.holder("BarrageHit", CFrame.new(target), Vector3.new(6, 1, 6))
			Kit.expire(spot, 1)
			total += flare(spot, BLUE, 22, 1)
			total += sparks(spot, BLUE, 60, 4)
			Kit.growingRing("BarrageRing", CFrame.new(target), 4, 20, 0.4, ICE, 0, Kit.FlatFaces)
		end
	end
	roomLight(mage.Her.Anchor.Position + Vector3.new(0, 30, 0), BLUE, few and 2 or 5, 0.45)
	Kit.shakeAt(Arena.Center, 0.9, 18, 0.35)
	return total
end

-- Runs ---------------------------------------------------------------------------------------------------------------------------

local EVENTS = { Lightning = playLightning, Slam = playSlam, Barrage = playBarrage }
local LEADS = { Lightning = playMarks, Slam = playGather, Barrage = playCircles }
local TIMED = {
	lightning = { { LIGHTNING_AT - MARK_LEAD, playMarks } },
	golem = { { GATHER_FROM, playGather } },
	barrage = { { BARRAGE_AT - CIRCLE_LEAD, playCircles } },
}

local function playEvent(name)
	local play = EVENTS[name]
	if play and effects and mage then
		effects:SetAttribute("LastParticles", play())
	end
end

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
	table.clear(tracked)
	table.clear(circles)
	previousMove, previousTime = nil, nil
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

-- since: seconds since the spawn, nil before it. move, localTime: BossMagePoses.Schedule's.
function BossMageVfx.Step(since, move, localTime)
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
