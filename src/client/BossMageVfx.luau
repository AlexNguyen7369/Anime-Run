--!nonstrict
-- The Elf Mage's effects (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"). Visual only: nothing here reads
-- back into damage. Timed from BossMagePoses, which server time alone decides, and built with Client/BossVfx's helpers (BossVfx.Kit)
-- in the arena's BossEffects folder. Each move has a lead cue before its event: lightning marks its floor spots 1.0 s ahead, the golem
-- gathers motes 2.2 s before each slam, the barrage opens its magic circles 1.2 s ahead. Spots come from a seed of the schedule
-- start and the cycle, so every client draws the same ones. All sizes, counts and colours are placeholders to judge from a capture.
-- Lightning and barrage spam the whole arena over the move's 2 s Window (owner 2026-11-11, BOSS_EVENT_SPEC "Strike window"): a
-- strike every 0.15 s, 14 strikes, 7 to 10 bolts or beams each (3 under REDUCED EFFECTS), a mark leading each bolt. Bolt, beam and
-- flash parts are pooled and short-lived. The golem's events run on its own move (BossMagePoses.GolemAt while a golem stands),
-- tracked apart from hers. Debug field: BossEffects attribute LastStrikes, JSON { Move, Strikes = { { T, Spots = { {x, z} } } } }.
-- BossVfxForce (client-local test attribute, as Client/BossVfx): not nil holds off the schedule; Lightning, Slam, Sweep or Barrage
-- plays that event with its lead cue at once.
local HttpService = game:GetService("HttpService")
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
local ICE, BLUE = Color3.fromRGB(205, 232, 255), Color3.fromRGB(90, 150, 255) -- the barrage's white and blue
local DUST = Color3.fromRGB(196, 158, 116) -- the colosseum's ochre stone

local function eventTime(move)
	return Poses.Moves[move].Events[1].Time
end
local LIGHTNING_AT, SLAM_AT, BARRAGE_AT = eventTime("lightning"), eventTime("golem"), eventTime("barrage")
local MARK_LEAD, GATHER_FROM, CIRCLE_LEAD = 1.0, 2.0, 1.2
local STRIKE_COUNT, STRIKE_EVERY = 14, 0.15 -- owner 2026-11-11: 0, 0.15, ... 1.95 s of the 2 s window
local PER_STRIKE_MIN, PER_STRIKE_MAX, PER_STRIKE_REDUCED = 7, 10, 3 -- bolts or beams per strike (reduced: proposed)
local BARRAGE_WINDOW = Poses.Moves.barrage.Window[2] - Poses.Moves.barrage.Window[1]
local SWEEP_PUFFS, SWEEP_PUFFS_REDUCED = 9, 3
local BOLT_TOP = 95 -- studs over the floor: the bolts fall from the dome
local BOLT_KINKS = 3
local CIRCLES, CIRCLES_REDUCED = 6, 3
local CIRCLE_SIZES = { 24, 16, 10 } -- studs across: 3 sizes, as the rules ask
local SPOT_MAX = Arena.WallRadius - 4 -- the whole room: centre, lanes and walkway
local SALT = { Lightning = 1, Barrage = 2 }
local STAFF_TIP = Vector3.new(Poses.Bind.Staff.Tip[1], Poses.Bind.Staff.Tip[2], Poses.Bind.Staff.Tip[3])

local BossMageVfx = {}

local effects, mage = nil, nil
local tracked = {} -- part -> function giving its CFrame each frame
local circles = {} -- the barrage's open circles, its beams' origins
local pool = {} -- idle pooled parts (Transparency 1) in this arena's folder
local previousMove, previousTime = nil, nil
local previousGolem, previousGolemTime = nil, nil

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

-- The move's strikes: { T, Spots } for each of the 14, T seconds after the window starts. Every strike takes all its draws, so
-- REDUCED EFFECTS keeps the same spots, only fewer of them. Spots are area-uniform over the room's floor.
local function plan(name)
	local rng, few, list = rngFor(name), reduced(), {}
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

-- A flat glowing disc where a bolt or beam lands.
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

-- Lightning --------------------------------------------------------------------------------------------------------------------

-- 1.0 s ahead of each bolt: a purple ring closing in on its spot (one part each: there are up to 140).
local function playMarks()
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

local function playLightning()
	-- cue: MageLightning (a crack of thunder)
	local few = reduced()
	local list, rng = plan("Lightning")
	logStrikes("Lightning", list)
	for _, strike in list do
		local bolts = {}
		for k, at in strike.Spots do
			local points = { at + Vector3.new(rng:NextNumber(-10, 10), BOLT_TOP, rng:NextNumber(-10, 10)) }
			for i = 1, BOLT_KINKS - 1 do
				local p = points[1]:Lerp(at, i / BOLT_KINKS)
				table.insert(points, p + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)))
			end
			table.insert(points, at)
			bolts[k] = points
		end
		later(strike.T, function()
			for _, points in bolts do
				for i = 1, #points - 1 do
					streak("Bolt", points[i], points[i + 1], 1.1, 3.5, WHITE, VIOLET, 0.22)
				end
				flash(points[#points], VIOLET, 10, 0.3)
			end
			roomLight(Vector3.new(Arena.Center.X, Arena.Y + 50, Arena.Center.Z), VIOLET, few and 1 or 2.5, 0.2)
			Kit.impact("Lightning", Arena.Center, 0.12, 20, 0.15, strike.T)
			return 0
		end)
	end
	if not few then
		Kit.regrade({ TintColor = Color3.fromRGB(222, 196, 255), Brightness = 0.06, Contrast = 0.1 }, 0.05, 1.9, 0.55)
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
	Kit.impact("Slam", at, 1.6, 20, 0.5)
	return total
end

-- The sweep: the slam's dust rings in a 120 degree arc along the lanes' middle, centred on the golem, swept out one by one.
local function playSweep()
	-- cue: GolemSweep (a grinding rush)
	local few = reduced()
	local torso = mage:GolemFrame("Torso").Position - Arena.Center
	local facing = math.atan2(-torso.Z, torso.X) -- as spots(): x = cos, z = -sin
	local radius = Arena.InnerRadius + Arena.Width / 2
	local count = few and SWEEP_PUFFS_REDUCED or SWEEP_PUFFS
	for i = 0, count - 1 do
		local a = facing + math.rad(-60 + 120 * i / (count - 1))
		local at =
			Vector3.new(Arena.Center.X + radius * math.cos(a), Arena.Y + 0.3, Arena.Center.Z - radius * math.sin(a))
		Kit.expire(Kit.holder("SweepDust", CFrame.new(at), Vector3.new(20, 1, 20)), 0.04 * i + 1.5)
		Kit.growingRing("SweepDust", CFrame.new(at), 8, 26, 1.0, DUST, 0.04 * i, Kit.FlatFaces)
	end
	Kit.impact("Sweep", Arena.Center, 1.2, 20, 0.5)
	return 0
end

-- Barrage ------------------------------------------------------------------------------------------------------------------------

-- 1.2 s ahead, held over the window: magic circles of 3 sizes open in a fan around her, facing out, turning, riding her bob.
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
		task.delay(CIRCLE_LEAD + BARRAGE_WINDOW + 0.25, function()
			Kit.tween(front, 0.3, { Transparency = 1 })
			Kit.tween(back, 0.3, { Transparency = 1 })
		end)
		Kit.expire(part, CIRCLE_LEAD + BARRAGE_WINDOW + 0.6)
		circles[k] = part
	end
	return 0
end

local function playBarrage()
	-- cue: MageBarrage (a volley of zaps)
	local few = reduced()
	local list = plan("Barrage")
	logStrikes("Barrage", list)
	for j, strike in list do
		later(strike.T, function()
			for k, target in strike.Spots do
				local circle = #circles > 0 and circles[(j + k - 2) % #circles + 1]
				local from = circle and circle.Parent and circle.Position or mage:Point("Staff", STAFF_TIP)
				streak("BarrageBeam", from, target, 1.2, 3.6, WHITE, k % 2 == 0 and BLUE or ICE, 0.25)
				flash(target, BLUE, 9, 0.3)
			end
			roomLight(mage.Her.Anchor.Position + Vector3.new(0, 30, 0), BLUE, few and 1 or 2, 0.2)
			Kit.impact("Barrage", Arena.Center, 0.1, 18, 0.15, strike.T)
			return 0
		end)
	end
	return 0
end

-- Runs ---------------------------------------------------------------------------------------------------------------------------

local EVENTS = { Lightning = playLightning, Slam = playSlam, Sweep = playSweep, Barrage = playBarrage }
local LEADS = { Lightning = playMarks, Slam = playGather, Barrage = playCircles }
local TIMED = {
	lightning = { { LIGHTNING_AT - MARK_LEAD, playMarks } },
	barrage = { { BARRAGE_AT - CIRCLE_LEAD, playCircles } },
}
local GOLEM_TIMED = {
	golem = { { GATHER_FROM, playGather } },
	golem_slam = { { 0.6, playGather } }, -- the slam track's lead: its own 2.2 s wind-up, as the golem move's
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
	table.clear(pool)
	table.clear(tracked)
	table.clear(circles)
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
