--!nonstrict
-- The boss sky arena (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Arena"). Client-only: the diameter exceeds the streaming
-- target. Marble and gold parts from BossArenaConfig, matching tools/blender/arena/build_arena.py's approved draft, over a
-- cloud deck; the sky is the arena zone of Client/BiomeEnvironment. Engine primitives only, no uploaded meshes. Built while
-- this player is in an event (player attribute BossEvent), or while the test attribute BossArenaPreview is on. While the event's boss
-- (ReplicatedStorage attribute BossEventBoss) is boss_mage, the colosseum (Client/BossColosseum) and Client/BossMage stand instead.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaConfig = require(Shared:WaitForChild("BossArenaConfig"))
local Cfg = ArenaConfig -- the standing arena's numbers; Big Raga's sky arena unless the colosseum stands
local Event = require(Shared:WaitForChild("BossEventConfig"))
local ATTRIBUTE = "BossArenaPreview"
local BossCatalog = require(Shared:WaitForChild("BossCatalog"))

-- Design doc 7 "Join size": a boss's meshes and images start loading when its poses arrive (2 minutes ahead) or its event starts,
-- not at the teleport, and not at the 30-minute announcement.
local preloaded = {}
local function preload(id)
	if id == nil or preloaded[id] then
		return
	end
	preloaded[id] = true
	local row = BossCatalog.Get(id)
	task.spawn(function()
		local models = ReplicatedStorage:WaitForChild("BossModels", 60)
		local list = { row.Portrait, row.DodgeIcon }
		for _, name in { row.Id, row.Minion and row.Minion.Id } do
			local model = models and name and models:WaitForChild(name, 60)
			if model then
				table.move(model:GetChildren(), 1, #model:GetChildren(), #list + 1, list)
			end
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, list)
	end)
end
ReplicatedStorage:GetAttributeChangedSignal("BossEventBoss"):Connect(function()
	preload(ReplicatedStorage:GetAttribute("BossEventBoss"))
end)
preload(ReplicatedStorage:GetAttribute("BossEventBoss"))
local function watchLate(late)
	if late.Name ~= "LateData" then
		return
	end
	local function arrived(child)
		for _, id in BossCatalog.Order do
			if BossCatalog.Get(id).Poses == child.Name then
				preload(id)
			end
		end
	end
	late.ChildAdded:Connect(arrived)
	for _, child in late:GetChildren() do
		arrived(child)
	end
end
ReplicatedStorage.ChildAdded:Connect(watchLate)
if ReplicatedStorage:FindFirstChild("LateData") then
	watchLate(ReplicatedStorage.LateData)
end

-- Join size (design doc 7): the view waits for an event or a preview; then only that boss's modules and poses load (viewOf).
while Players.LocalPlayer:GetAttribute("BossEvent") ~= true and ReplicatedStorage:GetAttribute(ATTRIBUTE) ~= true do
	RunService.Heartbeat:Wait()
end
local LateData = require(Shared:WaitForChild("LateData"))
local BossColosseum = require(script.Parent:WaitForChild("BossColosseum"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local PARTS_PER_FRAME = 60 -- about 1,650 parts, so about 28 frames
-- Every second ring point: 72 pieces of about 78 studs on each ring. The draft's 144 would be about 1,200 more parts.
local RING_STEP = 2
-- Placeholder sizes, all studs. Heights and radii not named here are the draft's.
local DECK_THICK = 8
local DAIS_THICK = 14
local LINE_WIDTH, LINE_THICK = 1, 0.1
local GROWTH = Event.ScreamGrowth
local ARCH_COUNT, ARCH_START, SECTOR = 6, math.rad(15), math.rad(60) -- the draft's ARCH_START and SECTOR
local ARCH_PIECES = 8 -- the draft's 12, for phones
local BAY_OFFSETS = { math.rad(20), math.rad(40) } -- colonnade bays after each arch
local BAY_HALF, BAY_COLUMNS, BAY_HEIGHT = math.rad(8), 7, 62 -- the draft's 13 columns, for phones
local CLOUD_Y = Cfg.Y - 720 -- the draft's cloud sea
local TILE, TILES = 2040, 3 -- deck slabs: 2048 is the largest part; a 7 x 7 grid without its corners
-- A ring of big puffs hides the deck's edge. The arena's Atmosphere is too thin to, and at FOV 100 the aerial camera sees the
-- horizon, so the upper row tops out above that camera (850 over the ring, placeholder values, all studs).
local BANK_RADIUS, BANK_PUFFS, BANK_PUFF = 6900, 31, 1024
local BANK_LOW, BANK_HIGH = 0, 1300 -- row centres above the deck
local PUFFS, WISPS = 60, 12

local function look(hex, material, shadow)
	return { Color = Color3.fromHex(hex), Material = material, Shadow = shadow == true }
end
local Marble, Plastic = Enum.Material.Marble, Enum.Material.SmoothPlastic
-- The draft's palette
local MARBLE = look("F3EFE6", Marble, true)
local MARBLE2 = look("E6DFCF", Marble)
local MARBLE3 = look("DDD6C8", Marble)
local LANE_A, LANE_A2 = look("F7F3EA", Marble), look("EEE8DB", Marble)
local LANE_B, LANE_B2 = look("DCD5C6", Marble), look("D2CBBA", Marble)
local GOLD, GOLD2 = look("E8B23C", Plastic), look("C9922B", Plastic)
local CLOUD, CLOUD2 = look("FFFFFF", Plastic), look("EAF1FA", Plastic)

local folder = nil -- the built arena, nil when off
local added = 0
local raga = nil -- the boss, while the arena stands
local mage = nil -- or The Elf Mage, while the colosseum stands
local builtBoss = nil -- the boss id the standing arena was built for

-- Call before each stretch of parts: yields every PARTS_PER_FRAME. False once the build was cancelled.
local function pace(mine)
	if added >= PARTS_PER_FRAME then
		added = 0
		task.wait()
	end
	return folder == mine
end

local function addPart(name, size, cframe, style, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Transparency = 0
	part.Anchored = true
	part.CanTouch = false
	-- Only the deck is solid, so that the camera stops at it and an arch passing never pops the camera in.
	part.CanCollide = name == "Deck"
	part.CanQuery = name == "Deck"
	part.CastShadow = style.Shadow
	part.Material = style.Material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = style.Color
	part.Parent = folder
	added += 1
	return part
end

-- A ring of straight pieces, each as long as the chord at the outer edge so the ring has no gaps. With style2 the pieces
-- alternate, as the draft's lanes do; those stand a hair higher because neighbours overlap at their inner corners.
-- step: ring points a piece, default RING_STEP. Returns false if the build was cancelled.
local function addRing(mine, name, radius, width, height, top, style, style2, step)
	step = step or RING_STEP
	local length = (Cfg.RingPoint(radius + width / 2, 0) - Cfg.RingPoint(radius + width / 2, step)).Magnitude
	for k = 0, Cfg.Segments / step - 1 do
		if not pace(mine) then
			return false
		end
		local other = style2 ~= nil and k % 2 == 1
		local y = top - height / 2 + (other and 0.02 or 0)
		local a, b = Cfg.RingPoint(radius, k * step, y), Cfg.RingPoint(radius, (k + 1) * step, y)
		addPart(name, Vector3.new(width, height, length), CFrame.lookAt((a + b) / 2, b), other and style2 or style)
	end
	return true
end

-- Local axes around a ring angle: X outward, Y up, Z along the ring. Same turning sense as Cfg.RingPoint.
local function ringFrame(angle)
	return CFrame.new(Cfg.Center) * CFrame.Angles(0, angle, 0)
end

-- A triumphal arch over all 7 lanes: 23 parts.
local function addArch(angle)
	local frame = ringFrame(angle)
	local inner, outer = Cfg.InnerRadius - 8, Cfg.InnerRadius + Cfg.Width + 16
	local middle, span = (inner + outer) / 2, (outer - inner) / 2
	local spring = 70
	for _, r in { inner, outer } do
		addPart("ArchPylon", Vector3.new(16, 100, 26), frame * CFrame.new(r, 20, 0), MARBLE)
		addPart("ArchTrim", Vector3.new(20, 5, 30), frame * CFrame.new(r, 2.5, 0), GOLD)
		addPart("ArchTrim", Vector3.new(20, 5, 30), frame * CFrame.new(r, spring + 2.5, 0), GOLD)
	end
	local function point(k)
		local a = k / ARCH_PIECES * math.pi
		return Vector3.new(middle - span * math.cos(a), spring + 5 + span * math.sin(a) * 0.85, 0)
	end
	for k = 0, ARCH_PIECES - 1 do
		local p, q = point(k), point(k + 1)
		local length = (q - p).Magnitude
		addPart("ArchRib", Vector3.new(15, 15, length), frame * CFrame.lookAt((p + q) / 2, q), MARBLE2)
		local lift = Vector3.new(0, 8, 0)
		addPart("ArchTrim", Vector3.new(5, 5, length), frame * CFrame.lookAt((p + q) / 2 + lift, q + lift), GOLD)
	end
	addPart("ArchKey", Vector3.new(13, 22, 20), frame * CFrame.new(middle, point(ARCH_PIECES / 2).Y + 3, 0), GOLD)
end

-- A stretch of columns on the outer plinth with a marble and gold cornice: 13 parts.
local function addBay(angle)
	local radius = Cfg.InnerRadius + Cfg.Width + 18
	local base = 3
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder's axis is its X
	for k = 0, BAY_COLUMNS - 1 do
		local at = ringFrame(angle - BAY_HALF + 2 * BAY_HALF * k / (BAY_COLUMNS - 1))
		local column = Vector3.new(BAY_HEIGHT, 7, 7)
		addPart(
			"Column",
			column,
			at * CFrame.new(radius, base + BAY_HEIGHT / 2, 0) * upright,
			MARBLE,
			Enum.PartType.Cylinder
		)
	end
	local top = base + BAY_HEIGHT
	local third = BAY_HALF * 2 / 3
	local length = 2 * radius * math.tan(third / 2)
	for k = -1, 1 do
		local at = ringFrame(angle + k * third)
		addPart("Cornice", Vector3.new(14, 8, length), at * CFrame.new(radius, top + 4, 0), MARBLE2)
		addPart("CorniceTrim", Vector3.new(18, 3, length), at * CFrame.new(radius, top + 9.5, 0), GOLD)
	end
end

local function addDais()
	local y, center = Cfg.DaisY, Cfg.Center
	local radius = Cfg.DaisRadius
	local function drum(name, top, height, r, style)
		-- A cylinder's axis is its X: this turn stands it on end.
		local cf = CFrame.new(center.X, top - height / 2, center.Z) * CFrame.Angles(0, 0, math.pi / 2)
		addPart(name, Vector3.new(height, 2 * r, 2 * r), cf, style, Enum.PartType.Cylinder)
	end
	drum("Dais", y, DAIS_THICK, radius, MARBLE)
	drum("DaisTrim", y - DAIS_THICK, 6, radius + 15, GOLD)
	drum("DaisDrum", y - 20, 40, radius + 15, MARBLE2)
	drum("DaisStem", y - 60, 60, 40, GOLD2)
end

-- A flattened sphere, an engine primitive.
local function addPuff(x, y, z, radius, style, height)
	local part =
		addPart("Cloud", Vector3.new(2 * radius, height or 0.9 * radius, 2 * radius), CFrame.new(x, y, z), style)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

-- Slabs hide the terrain below, puffs break up their flat top, and wisps under the ring make it read as floating.
-- Returns false if the build was cancelled.
local function addClouds(mine)
	local center = Cfg.Center
	for ix = -TILES, TILES do
		for iz = -TILES, TILES do
			if not pace(mine) then
				return false
			end
			-- The corners lie wholly behind the bank.
			if math.abs(ix) < TILES or math.abs(iz) < TILES then
				local at = CFrame.new(center.X + ix * TILE, CLOUD_Y - 10, center.Z + iz * TILE)
				addPart("CloudDeck", Vector3.new(2048, 20, 2048), at, CLOUD2)
			end
		end
	end
	for i = 1, BANK_PUFFS do
		if not pace(mine) then
			return false
		end
		local a = 2 * math.pi * i / BANK_PUFFS
		for row, above in { BANK_LOW, BANK_HIGH } do
			local turn = a + (row - 1) * math.pi / BANK_PUFFS -- staggered, so one row's dips meet the other's tops
			local x, z = center.X + BANK_RADIUS * math.cos(turn), center.Z + BANK_RADIUS * math.sin(turn)
			addPuff(x, CLOUD_Y + above, z, BANK_PUFF, row == 1 and CLOUD2 or CLOUD, 2 * BANK_PUFF)
		end
	end
	local rng = Random.new(7) -- the same sky for everyone
	local function polar(min, max)
		local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(min, max)
		return center.X + r * math.cos(a), center.Z + r * math.sin(a), r
	end
	for _ = 1, PUFFS do
		if not pace(mine) then
			return false
		end
		local x, z, r = polar(300, 6500)
		local size = rng:NextNumber(130, 340) * (1 + r / 8000)
		addPuff(x, CLOUD_Y + size * 0.1, z, size, CLOUD)
	end
	for _ = 1, WISPS do
		if not pace(mine) then
			return false
		end
		local x, z = polar(Cfg.InnerRadius - 90, Cfg.InnerRadius + 270)
		addPuff(x, Cfg.Y - rng:NextNumber(130, 260), z, rng:NextNumber(50, 110), CLOUD2)
	end
	return true
end

local function build(mine)
	local y = Cfg.Y
	local inner, width = Cfg.InnerRadius, Cfg.Width
	local outer = inner + width
	local laneWidth = width / Cfg.Lanes
	local rings = {
		{ "Deck", inner + width / 2, width, DECK_THICK, y, LANE_A, LANE_A2 },
		{ "RailInner", inner - 3, 6, 3, y + 2.5, MARBLE3 },
		{ "RailInnerTrim", inner - 1, 2, 0.2, y + 2.6, GOLD },
		{ "RailOuter", outer + 3, 6, 6, y + 5, MARBLE3 },
		{ "RailOuterTrim", outer + 1, 2, 0.2, y + 5.1, GOLD },
		{ "Plinth", outer + 18, 24, 7, y + 3, MARBLE2 },
		{ "Hull", inner + width / 2 + 12, width + 36, 40, y - 8, MARBLE2 },
		{ "HullTrim", inner + width / 2 + 12, width + 40, 4, y - 4, GOLD },
	}
	for lane = 2, Cfg.Lanes - 1, 2 do
		table.insert(rings, { "Lane" .. lane, Cfg.LaneRadius(lane), laneWidth, 0.05, y + 0.05, LANE_B, LANE_B2 })
	end
	for lane = 1, Cfg.Lanes - 1 do
		local radius = inner + lane * laneWidth - LINE_WIDTH / 2
		table.insert(rings, { "LaneLine" .. lane, radius, LINE_WIDTH, LINE_THICK, y + LINE_THICK, GOLD })
	end
	for _, ring in rings do
		if not addRing(mine, table.unpack(ring)) then
			return
		end
	end
	for k = 0, ARCH_COUNT - 1 do
		local angle = ARCH_START + SECTOR * k
		if not pace(mine) then
			return
		end
		addArch(angle)
		for _, offset in BAY_OFFSETS do
			if not pace(mine) then
				return
			end
			addBay(angle + offset)
		end
	end
	if not pace(mine) then
		return
	end
	addDais()
	addClouds(mine)
end

-- A boss's client modules, required on its first showing: each reads that boss's poses alone, waiting until they are delivered.
local views = {}
local function viewOf(boss)
	if not views[boss] then
		local poses = LateData.Get(BossCatalog.Get(boss).Poses)
		local rig, vfx = "BossRaga", "BossVfx"
		if boss == "boss_mage" then
			rig, vfx = "BossMage", "BossMageVfx"
		end
		views[boss] = {
			Poses = poses,
			Rig = require(script.Parent:WaitForChild(rig)),
			Vfx = require(script.Parent:WaitForChild(vfx)),
			RoarAt = poses.Moves.shout and poses.Moves.shout.Events[1].Time,
		}
	end
	return views[boss]
end

local function refresh()
	local want = ReplicatedStorage:GetAttribute(ATTRIBUTE) == true
		or Players.LocalPlayer:GetAttribute("BossEvent") == true
	local boss = ReplicatedStorage:GetAttribute("BossEventBoss") == "boss_mage" and "boss_mage" or "boss_raga"
	if want == (folder ~= nil) and (not want or boss == builtBoss) then
		return
	end
	if folder then
		if mage or raga then
			views[builtBoss].Vfx.Stop()
		end
		folder:Destroy()
		folder = nil
		raga = nil
		mage = nil
		builtBoss = nil
	end
	if want then
		local mine = Instance.new("Folder")
		mine.Name = "BossArenaPreview"
		mine.Parent = Workspace
		folder = mine
		builtBoss = boss
		Cfg = ArenaConfig.For(boss)
		-- The arena stands at once; the boss joins it when its poses are here (at once when delivered before the teleport).
		task.spawn(function()
			local view = viewOf(boss)
			if folder ~= mine then
				return -- torn down while the poses were on their way
			end
			local rig = view.Rig.new(mine)
			local effects = Instance.new("Folder")
			effects.Name = "BossEffects"
			effects.Parent = mine
			if boss == "boss_mage" then
				mage = rig
			else
				raga = rig
			end
			view.Vfx.Start(effects, rig)
		end)
		if boss == "boss_mage" then
			local kit = { addPart = addPart, addRing = addRing, ringFrame = ringFrame, pace = pace, look = look }
			BossColosseum.Build(mine, kit)
			return
		end
		build(mine)
	end
end

-- Seconds since the spawn from the server's start time, nil before it. A preview with no event shows it risen.
local function sinceSpawn(now)
	local start = ReplicatedStorage:GetAttribute("BossEventStart")
	if not start then
		return Event.IntroSeconds
	end
	local t = now - start - Event.PrepSeconds
	return t >= 0 and t or nil
end

-- Stage 2 from server time alone, so a late client is right: the growth, the wheel's turn, the scream's seconds left (nil outside it).
local function stage2At(now)
	if ReplicatedStorage:GetAttribute("BossEventStage") ~= 2 then
		return 1, 0, nil
	end
	local ends = ReplicatedStorage:GetAttribute("BossScreamEndsAt")
	local left = ends and ends > now and ends - now or nil
	local started = (ReplicatedStorage:GetAttribute("BossScheduleStart") or now)
		+ Event.IntroSeconds
		- Event.ScreamSeconds
	local done = left and math.clamp(1 - left / Event.ScreamSeconds, 0, 1) or 1
	return 1 + (GROWTH - 1) * done * done * (3 - 2 * done), Event.WheelSpinAt(now - started), left
end

-- Her entrance (BOSS_EVENT_SPEC "The Elf Mage"): lowered from the broken dome over RiseSeconds, easing to a stop. No stage 2.
local function stepMage()
	local now = Workspace:GetServerTimeNow()
	local since = sinceSpawn(now)
	local rise = since and (UiMotion.Reduced() and 1 or 1 - (1 - math.min(1, since / Event.RiseSeconds)) ^ 3)
	local schedule = ReplicatedStorage:GetAttribute("BossScheduleStart") or (since and now - since or now)
	local minionStart = ReplicatedStorage:GetAttribute("BossMinionStart")
	local move, localTime, golemMove, golemTime
	if minionStart then
		move, localTime, golemMove, golemTime = views.boss_mage.Poses.GolemAt(now - minionStart)
	else
		-- only her golem_fall row has golem frames: the fall plays on her clock after the golem's HP reaches 0
		move, localTime = views.boss_mage.Poses.Schedule(schedule, now)
		golemMove, golemTime = move, localTime
	end
	mage:Step(rise, move, localTime, now, golemMove, golemTime)
	views.boss_mage.Vfx.Step(since, move, localTime, golemMove, golemTime)
end

-- The spawn rise (BOSS_EVENT_SPEC Flow, 1:00), through the dais from under the track, and every frame of the boss after it.
local function step()
	if mage then
		stepMage()
		return
	end
	if not raga then
		return
	end
	local Poses = views.boss_raga.Poses
	local now = Workspace:GetServerTimeNow()
	local since = sinceSpawn(now)
	local rise = since and (UiMotion.Reduced() and 1 or Poses.RiseAt(since))
	local below = (1 - (rise or 0)) * (Cfg.BossTotalHeight + DAIS_THICK)
	local schedule = ReplicatedStorage:GetAttribute("BossScheduleStart") or (since and now - since or now)
	local move, localTime = Poses.Schedule(schedule, now)
	local growth, spin, screamLeft = stage2At(now)
	if screamLeft then
		move, localTime = "shout", views.boss_raga.RoarAt -- the approved pose, held: no new key frames (BOSS_EVENT_SPEC "Phase 2")
	end
	raga:Step(rise, below, move, localTime, now, growth, spin, screamLeft and not UiMotion.Reduced() and 1 or 0)
	views.boss_raga.Vfx.Step(since, move, localTime, screamLeft)
end

RunService.Heartbeat:Connect(step)
ReplicatedStorage:GetAttributeChangedSignal(ATTRIBUTE):Connect(refresh)
Players.LocalPlayer:GetAttributeChangedSignal("BossEvent"):Connect(refresh)
ReplicatedStorage:GetAttributeChangedSignal("BossEventBoss"):Connect(refresh)
refresh()
