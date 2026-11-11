--!nonstrict
-- Rhythm circles (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"): before a move with BossCatalog
-- Moves[name].Osu, 4 numbered circles show one by one, each with a ring closing onto it at its beat, from Shared/BossOsu and the
-- event's server time. A click or tap on a circle sends its stamp once (Remotes.BossOsu); the server judges the times and
-- decides the dodge. The local judge only picks the hit or miss art. Mouse and touch only: a gamepad has no pointer here.
-- Test seam: each Circle<k> holds a BindableEvent Press; firing it runs what a click on the circle runs.
-- The result text and stars are the Dodge bar's (RacerBossDodge.ShowResult). Contract: Client/UiTest/UiBossMage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossCatalog = require(Shared:WaitForChild("BossCatalog"))
local BossDodge = require(Shared:WaitForChild("BossDodge"))
local BossMageArt = require(Shared:WaitForChild("BossMageArt"))
local BossOsu = require(Shared:WaitForChild("BossOsu"))
local Cfg = require(Shared:WaitForChild("BossEventConfig"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CAPTION_TEXT = "Golem Slam! Hit every circle!" -- approved mock-ups
local SMALL_SCREEN = 500 -- px of height: a phone, as the Dodge bar's
local RING_FROM = 3 -- the ring's scale of the circle when it shows; 1 at the beat
local RING_COLORS = { Color3.fromRGB(176, 120, 255), Color3.fromRGB(110, 205, 240) } -- violet, cyan, in turn (mock-ups)
local TIMER_FILL = Color3.fromRGB(205, 180, 255)
local INK = Color3.fromRGB(20, 14, 34)
-- Placeholders.
local CAPTION_MAX, CAPTION_MIN = 40, 18 -- px of height
local CAPTION_SHARE = 0.045 -- of the screen's height
local TIMER_HEIGHT = 6 -- px
local GAP = 6 -- px between the HUD, the caption and the timer
local HUD_CLEAR = 8 -- px between a circle and a HUD part
local BURST_GROW, BURST_SECONDS = 1.8, 0.35

local function make(class, props, parent)
	local inst = Instance.new(class)
	for key, value in props do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local root = make("ScreenGui", {
	Name = "RacerBossOsu",
	ResetOnSpawn = false, -- as the Dodge bar's: a respawn keeps the gui, the clock below decides what shows
	IgnoreGuiInset = true,
	DisplayOrder = 13, -- with the boss event's own UI, below the roll view (14)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local caption = make("TextLabel", {
	Name = "Caption",
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	FontFace = AnimeSkin.Font,
	Text = CAPTION_TEXT,
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	Visible = false,
}, root)
make("UIStroke", { Thickness = 2.5, Color = INK }, caption)
local timer = make("Frame", {
	Name = "Timer",
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Visible = false,
}, root)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, timer)
local timerFill = make("Frame", {
	Name = "Fill",
	BackgroundColor3 = TIMER_FILL,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, timer)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, timerFill)

local circles = {} -- k -> { Button, Ring, Number, Burst, Beat, State }; State nil (open), "Sent", "Hit", "Miss"
local open = nil -- { Index, At, MomentAt, Rows, Pending, Dodged } while the circles of one moment show

local function judged(circle, hit)
	circle.State = hit and "Hit" or "Miss"
	circle.Button.Image = hit and BossMageArt.OsuHit or BossMageArt.OsuMiss
	circle.Ring.Visible = false
	circle.Number.Visible = false
	-- A hit bursts out of the circle; under REDUCED EFFECTS only the art swaps. The burst is its own image, so the circle's
	-- rect never grows.
	local burst = circle.Burst
	if hit and not UiMotion.Reduced() then
		burst.Size = UDim2.fromScale(1, 1)
		burst.ImageTransparency = 0
		burst.Visible = true
		local grow = UiMotion.Create(
			burst,
			TweenInfo.new(BURST_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(BURST_GROW, BURST_GROW), ImageTransparency = 1 }
		)
		grow.Completed:Once(function()
			burst.Visible = false
		end)
		grow:Play()
	end
end

local function press(k, input)
	local shown, circle = open, circles[k]
	if not shown or circle.State ~= nil or not circle.Button.Visible then
		return
	end
	-- Round hit test: the button's square corners are not the circle.
	local position = input and input.Position
	if position then
		local size = circle.Button.AbsoluteSize
		local centre = circle.Button.AbsolutePosition + size / 2
		if (Vector2.new(position.X, position.Y) - centre).Magnitude > size.X / 2 then
			return
		end
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("BossOsu")
	if not remote then
		return
	end
	local stamp = workspace:GetServerTimeNow()
	circle.State = "Sent"
	judged(circle, BossOsu.Judge(shown.Rows[k].Lead, shown.MomentAt, stamp, 0))
	shown.Pending += 1
	task.spawn(function()
		local called, ok, reason = pcall(remote.InvokeServer, remote, shown.Index, k, stamp)
		shown.Pending -= 1
		if called and ok and reason == "Dodged" then
			shown.Dodged = true
		elseif called and reason == "Missed" and open == shown and circle.State == "Hit" then
			judged(circle, false) -- the server's judge stands over this client's art
		end
	end)
end

for k = 1, BossOsu.Count do
	local button = make("ImageButton", {
		Name = "Circle" .. k,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Image = BossMageArt.OsuCircle,
		ScaleType = Enum.ScaleType.Fit,
		Selectable = false,
		Visible = false,
		ZIndex = 2,
	}, root)
	local ring = make("ImageLabel", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = BossMageArt.OsuRing,
		ImageColor3 = RING_COLORS[(k - 1) % #RING_COLORS + 1],
		Position = UDim2.fromScale(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(RING_FROM, RING_FROM),
		ZIndex = 3,
	}, button)
	local number = make("TextLabel", {
		Name = "Number",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		FontFace = AnimeSkin.Font, -- design doc 4.42: heavy italic
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.42),
		Text = tostring(k),
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		ZIndex = 4,
	}, button)
	make("UIStroke", { Thickness = 2, Color = INK }, number)
	circles[k] = {
		Button = button,
		Ring = ring,
		Number = number,
		Burst = make("ImageLabel", {
			Name = "Burst",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = BossMageArt.OsuHit,
			Position = UDim2.fromScale(0.5, 0.5),
			ScaleType = Enum.ScaleType.Fit,
			Visible = false,
			ZIndex = 5,
		}, button),
		Beat = 0,
		State = nil,
	}
	button.Activated:Connect(function(input)
		press(k, input)
	end)
	make("BindableEvent", { Name = "Press" }, button).Event:Connect(function()
		press(k, nil) -- no position: the press is on the circle
	end)
end

-- The HUD parts the circles stay clear of, as rects in root's space: { left, top, right, bottom }.
local hudRects = {}
local function addRect(gui)
	if gui and gui.Visible and gui.AbsoluteSize.X > 0 then
		local at = gui.AbsolutePosition - root.AbsolutePosition
		table.insert(hudRects, { at.X, at.Y, at.X + gui.AbsoluteSize.X, at.Y + gui.AbsoluteSize.Y })
	end
end

-- A circle's centre inside a rect grown by its radius moves to the nearest side of it that keeps it in the middle 60%,
-- one diameter from every circle placed before it and clear of the other rects. With none, it stays where the seed put it.
local function clearOf(x, y, radius, placed, size, diameter)
	local function free(px, py)
		if px < size.X * 0.2 + radius or px > size.X * 0.8 - radius then
			return false
		end
		if py < size.Y * 0.2 + radius or py > size.Y * 0.8 - radius then
			return false
		end
		for _, other in placed do
			if (Vector2.new(px, py) - other).Magnitude < diameter then
				return false
			end
		end
		for _, r in hudRects do
			local grow = radius + HUD_CLEAR
			if px > r[1] - grow and px < r[3] + grow and py > r[2] - grow and py < r[4] + grow then
				return false
			end
		end
		return true
	end
	if free(x, y) then
		return x, y
	end
	local spots = {}
	for _, r in hudRects do
		local grow = radius + HUD_CLEAR + 1
		table.insert(spots, { r[1] - grow, y })
		table.insert(spots, { r[3] + grow, y })
		table.insert(spots, { x, r[2] - grow })
		table.insert(spots, { x, r[4] + grow })
	end
	for _, other in placed do -- a circle pushed before this one: one diameter straight away from it
		local away = Vector2.new(x, y) - other
		local spot = other + (away.Magnitude > 0 and away.Unit or Vector2.xAxis) * (diameter + 1)
		table.insert(spots, { spot.X, spot.Y })
	end
	local best, bestX, bestY = math.huge, x, y
	for _, spot in spots do
		local away = math.abs(spot[1] - x) + math.abs(spot[2] - y)
		if away < best and free(spot[1], spot[2]) then
			best, bestX, bestY = away, spot[1], spot[2]
		end
	end
	return bestX, bestY
end

-- Sizes and places everything from the screen and the event HUD, once per moment.
local function place(rows)
	local size = root.AbsoluteSize
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local share = (size.Y < SMALL_SCREEN or touch) and BossOsu.DiameterPhone or BossOsu.Diameter
	local diameter = math.ceil(share * size.Y)

	table.clear(hudRects)
	local event = playerGui:FindFirstChild("RacerBossEvent")
	local bar = event and event:FindFirstChild("BossBar")
	local status = bar and bar:FindFirstChild("Status")
	local dropList = event and event:FindFirstChild("DropList")
	addRect(bar)
	addRect(status)
	addRect(dropList)
	addRect(event and event:FindFirstChild("LeaveButton"))
	local hud = playerGui:FindFirstChild("RacerHud")
	local level = hud and hud:FindFirstChild("Level")
	addRect(level and level:FindFirstChild("Team"))

	-- Caption and timer under the bar's status row, centred, left of the drop list where it hangs beside them.
	local top = size.Y * 0.08
	for _, gui in { bar, status } do
		if gui then
			top = math.max(top, gui.AbsolutePosition.Y - root.AbsolutePosition.Y + gui.AbsoluteSize.Y)
		end
	end
	top += GAP
	local width = size.X * 0.5
	if dropList and dropList.Visible then
		local room = 2 * (dropList.AbsolutePosition.X - root.AbsolutePosition.X - size.X / 2 - GAP)
		width = math.max(200, math.min(width, room))
	end
	local captionHeight = math.clamp(math.round(size.Y * CAPTION_SHARE), CAPTION_MIN, CAPTION_MAX)
	caption.Position = UDim2.fromOffset(size.X / 2, top)
	caption.Size = UDim2.fromOffset(width, captionHeight)
	timer.Position = UDim2.fromOffset(size.X / 2, top + captionHeight + GAP / 2)
	timer.Size = UDim2.fromOffset(width * 0.7, TIMER_HEIGHT)
	addRect(caption)
	addRect(timer)

	local placed = {}
	for k, circle in circles do
		local row = rows[k]
		local x, y = clearOf(row.X * size.X, row.Y * size.Y, diameter / 2, placed, size, diameter)
		table.insert(placed, Vector2.new(x, y))
		circle.Button.Position = UDim2.fromOffset(x, y)
		circle.Button.Size = UDim2.fromOffset(diameter, diameter)
	end
end

local function close()
	open = nil
	caption.Visible = false
	timer.Visible = false
	for _, circle in circles do
		circle.Button.Visible = false
	end
end

local function openCircles(index, at, momentAt, startAt)
	local rows = BossOsu.Circles(player.UserId, startAt, index)
	open = { Index = index, At = at, MomentAt = momentAt, Rows = rows, Pending = 0, Dodged = false }
	caption.Visible = true
	place(rows)
	timer.Visible = true
	for k, circle in circles do
		circle.Beat = momentAt - rows[k].Lead
		circle.State = nil
		circle.Button.Image = BossMageArt.OsuCircle
		circle.Button.Visible = false
		circle.Ring.Visible = true
		circle.Ring.Size = UDim2.fromScale(RING_FROM, RING_FROM)
		circle.Number.Visible = true
		circle.Burst.Visible = false
	end
end

local function showResult(kind, words)
	local dodgeGui = playerGui:FindFirstChild("RacerBossDodge")
	local event = dodgeGui and dodgeGui:FindFirstChild("ShowResult")
	if event then
		event:Fire(kind, words)
	end
end

local doneIndex, doneSchedule = 0, nil -- no second set for a moment; a new event or stage starts over

local function render()
	local startAt = ReplicatedStorage:GetAttribute("BossEventStart")
	local active = player:GetAttribute("BossEvent") == true
		and ReplicatedStorage:GetAttribute("BossEventPhase") == "Fight"
		and startAt ~= nil
		and player:GetAttribute("BossWaitEndsAt") == nil
	if not active then
		if open then
			close() -- no hit: a player in the wait is not hit by this move
		end
		return
	end
	local schedule = ReplicatedStorage:GetAttribute("BossScheduleStart") or startAt + Cfg.PrepSeconds
	if doneSchedule ~= schedule then
		doneIndex, doneSchedule = 0, schedule
		if open then
			close()
			return
		end
	end
	local now = workspace:GetServerTimeNow()
	local since = now - schedule - Cfg.IntroSeconds
	local shown = open
	if shown then
		if shown.Dodged then
			close()
			showResult("Dodged")
		elseif since >= shown.At and shown.Pending == 0 then
			close()
			showResult("Hit", BossDodge.HitText.Slam)
		else
			timerFill.Size = UDim2.fromScale(math.clamp((shown.At - since) / BossOsu.OpenSeconds, 0, 1), 1)
			for _, circle in circles do
				local left = circle.Beat - now
				circle.Button.Visible = left <= BossOsu.ApproachSeconds
				if circle.State == nil and left < -BossOsu.Tolerance then
					judged(circle, false) -- unclicked past its beat
				elseif circle.State == nil then
					local ringScale = 1 + (RING_FROM - 1) * math.clamp(left / BossOsu.ApproachSeconds, 0, 1)
					circle.Ring.Size = UDim2.fromScale(ringScale, ringScale)
				end
			end
		end
	elseif since >= 0 then
		local boss = ReplicatedStorage:GetAttribute("BossEventBoss")
		local index = BossDodge.IndexAtOrBefore(since, boss) + 1
		if index <= doneIndex then
			return
		end
		local at, name = BossDodge.Moment(index, boss)
		local move = BossCatalog.Current().Moves[name]
		if move and move.Osu and at - since <= BossOsu.OpenSeconds then
			doneIndex = index
			openCircles(index, at, schedule + Cfg.IntroSeconds + at, startAt)
		end
	end
end

RunService.Heartbeat:Connect(render)
