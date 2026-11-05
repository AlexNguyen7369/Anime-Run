--!nonstrict
-- Boss arena blockout (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Arena"). Client-only: the diameter exceeds the streaming
-- target. Plain parts from BossArenaConfig; the dressing and clouds come later. Built while this player is in an event
-- (player attribute BossEvent), or while the test attribute BossArenaPreview is on.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BossArenaConfig"))
local Event = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BossEventConfig"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local ATTRIBUTE = "BossArenaPreview"
local PARTS_PER_FRAME = 60 -- about 1,450 parts, so about 25 frames
-- Placeholder sizes, all studs.
local DECK_THICK = 8
local LINE_WIDTH, LINE_THICK = 0.5, 0.1
local RAIL_WIDTH, RAIL_HEIGHT = 2, 4
local DAIS_THICK = 14
local BOSS_WIDTH, BOSS_DEPTH = 200, 120 -- a stand-in for the height only
local WHEEL_THICK = 30
local GREY = Color3.fromRGB(150, 150, 150)
local DECK = Color3.fromRGB(205, 200, 190)
local LINE = Color3.fromRGB(245, 245, 245)
local RAIL = Color3.fromRGB(120, 120, 125)
-- The spawn rise (BOSS_EVENT_SPEC Flow, 1:00): through the dais from under the track. shortcut: stand-ins only, add the model
-- and the flat fallback here once they are in this file.
local RISERS = { BossStandIn = true, WheelStandIn = true }

local folder = nil -- the built arena, nil when off
local added = 0
local homes = setmetatable({}, { __mode = "k" }) -- riser part -> its full-height CFrame
local lastRise = nil

local function addPart(name, size, cframe, color, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Transparency = RISERS[name] and 1 or 0 -- a riser stays hidden until stepRise has placed it
	part.Anchored = true
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Parent = folder
	added += 1
	if added % PARTS_PER_FRAME == 0 then
		task.wait()
	end
end

-- A ring of Segments straight pieces, each as long as the chord at the outer edge so the ring has no gaps.
-- Returns false if the build was cancelled.
local function addRing(mine, name, radius, width, height, top, color)
	local length = (Cfg.RingPoint(radius + width / 2, 0) - Cfg.RingPoint(radius + width / 2, 1)).Magnitude
	local y = top - height / 2
	for i = 0, Cfg.Segments - 1 do
		if folder ~= mine then
			return false
		end
		local a, b = Cfg.RingPoint(radius, i, y), Cfg.RingPoint(radius, i + 1, y)
		addPart(name, Vector3.new(width, height, length), CFrame.lookAt((a + b) / 2, b), color)
	end
	return true
end

local function build(mine)
	local y, center = Cfg.Y, Cfg.Center
	local outer = Cfg.InnerRadius + Cfg.Width
	if not addRing(mine, "Deck", Cfg.InnerRadius + Cfg.Width / 2, Cfg.Width, DECK_THICK, y, DECK) then
		return
	end
	for lane = 1, Cfg.Lanes do
		if
			not addRing(mine, "LaneLine" .. lane, Cfg.LaneRadius(lane), LINE_WIDTH, LINE_THICK, y + LINE_THICK, LINE)
		then
			return
		end
	end
	if not addRing(mine, "RailInner", Cfg.InnerRadius, RAIL_WIDTH, RAIL_HEIGHT, y + RAIL_HEIGHT, RAIL) then
		return
	end
	if not addRing(mine, "RailOuter", outer, RAIL_WIDTH, RAIL_HEIGHT, y + RAIL_HEIGHT, RAIL) then
		return
	end
	if folder ~= mine then
		return
	end
	-- A cylinder's axis is its X: this turn stands the dais on end. The wheel keeps its axis horizontal, like the boss's.
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local dais = Vector3.new(DAIS_THICK, 2 * Cfg.DaisRadius, 2 * Cfg.DaisRadius)
	addPart("Dais", dais, CFrame.new(center.X, y - DAIS_THICK / 2, center.Z) * upright, GREY, Enum.PartType.Cylinder)
	local body = Vector3.new(BOSS_WIDTH, Cfg.BossHeight, BOSS_DEPTH)
	addPart("BossStandIn", body, CFrame.new(center.X, y + Cfg.BossHeight / 2, center.Z), GREY)
	local wheelY = y + Cfg.BossHeight + Cfg.BossWheelHeight / 2
	local wheel = Vector3.new(WHEEL_THICK, Cfg.BossWheelHeight, Cfg.BossWheelHeight)
	addPart("WheelStandIn", wheel, CFrame.new(center.X, wheelY, center.Z), GREY, Enum.PartType.Cylinder)
end

local function refresh()
	local want = ReplicatedStorage:GetAttribute(ATTRIBUTE) == true
		or Players.LocalPlayer:GetAttribute("BossEvent") == true
	if want == (folder ~= nil) then
		return
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	if want then
		local mine = Instance.new("Folder")
		mine.Name = "BossArenaPreview"
		mine.Parent = Workspace
		folder = mine
		build(mine)
	end
end

-- nil before the spawn; 0 to 1 over the intro from the server's start time. A preview with no event shows it risen.
local function riseNow()
	local start = ReplicatedStorage:GetAttribute("BossEventStart")
	if not start then
		return 1
	end
	local t = (Workspace:GetServerTimeNow() - start - Event.PrepSeconds) / Event.IntroSeconds
	if t < 0 then
		return nil
	end
	return UiMotion.Reduced() and 1
		or TweenService:GetValue(math.min(t, 1), Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
end

local function stepRise()
	if not folder then
		lastRise = nil
		return
	end
	local rise = riseNow()
	local below = (1 - (rise or 0)) * (Cfg.BossHeight + Cfg.BossWheelHeight + DAIS_THICK)
	for name in RISERS do
		local part = folder:FindFirstChild(name)
		if part then
			homes[part] = homes[part] or part.CFrame
			if rise ~= lastRise or part.Transparency == 1 and rise then
				part.CFrame = homes[part] - Vector3.new(0, below, 0)
				part.Transparency = rise and 0 or 1
			end
		end
	end
	lastRise = rise
end

RunService.Heartbeat:Connect(stepRise)
ReplicatedStorage:GetAttributeChangedSignal(ATTRIBUTE):Connect(refresh)
Players.LocalPlayer:GetAttributeChangedSignal("BossEvent"):Connect(refresh)
refresh()
