--!nonstrict
-- The Dodge bar (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Dodge bar"): before each Big Raga move a slider sweeps a bar above the
-- roster minibar, from Shared/BossDodge and the event's server time. A press asks the server, which decides. Contract:
-- Client/UiTest/UiBossEvent.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossDodge = require(Shared:WaitForChild("BossDodge"))
local Cfg = require(Shared:WaitForChild("BossEventConfig"))
local RelicConfig = require(Shared:WaitForChild("RelicConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ACTION = "BossDodgePress"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value -- over the default jump on Space
local BAR_MAX_WIDTH = 640 -- px, placeholder
local BAR_WIDTH = 0.58 -- of the screen, placeholder
local BAR_HEIGHT, BAR_HEIGHT_SMALL = 36, 24 -- px, placeholder
local SMALL_SCREEN = 500 -- px of height: a phone
local HUD_GAP = 34 -- px above the Team row: clear of its enlarged active circle, placeholder
local FALLBACK_BOTTOM = 130 -- px from the bottom when the Team row is not there
local FLASH_PERIOD = 0.4
local BAR_ANIM_SECONDS = 0.3 -- owner 2026-11-06: the bar's pop up and its disappearing
local GOLD = Color3.fromRGB(250, 197, 72)
local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 45, 45)
-- Result motion, placeholders.
local POP_FROM, POP_PEAK, HIT_POP = 0.3, 1.45, 1.2
local POP_OUT_SECONDS, POP_SETTLE_SECONDS = 0.24, 0.2
local HIT_FLASH_PERIOD = 0.13
local HIT_SHAKE = 7 -- px
local UI_STARS, WORLD_STARS = 12, 22
local STAR_MIN, STAR_MAX = 26, 54 -- px
local STAR_REACH_MIN, STAR_REACH_MAX = 150, 320 -- px
local STAR_SECONDS = 0.7

local function make(class, props, parent)
	local inst = Instance.new(class)
	for key, value in props do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local root = make("ScreenGui", {
	Name = "RacerBossDodge",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 13, -- with the boss event's own UI, below the roll view (14)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local function text(name, parent)
	return make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Font = UiTheme.Font,
		TextColor3 = WHITE,
		TextScaled = true,
		Visible = false,
	}, parent) -- no border: the owner's white text
end

local dodge = make(
	"Frame",
	{ Name = "DodgeBar", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Visible = false },
	root
)
local barScale = make("UIScale", { Name = "BarScale", Scale = 0 }, dodge)
local bar = make("TextButton", {
	Name = "Bar",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.fromRGB(24, 18, 12),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, dodge)
make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, bar)
make("UIStroke", { Thickness = 2, Color = GOLD, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bar)
local spot = make("Frame", {
	Name = "Spot",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(BossDodge.SpotWidth, 0.9),
}, bar)
make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 236, 130)),
		ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 236, 130)),
		ColorSequenceKeypoint.new(1, GOLD),
	}),
}, spot)
local slider = make("Frame", {
	Name = "Slider",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	Size = UDim2.new(0, 6, 1.5, 0),
	ZIndex = 2,
}, bar)
make("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0) }, slider)
local wheel = make("ImageLabel", {
	Name = "Wheel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Image = RelicConfig.WheelArt,
	Position = UDim2.fromScale(0, 0.5),
	ZIndex = 3,
}, dodge)
local subtitle = text("Subtitle", dodge)
subtitle.AnchorPoint = Vector2.new(0.5, 1)
local result = text("Result", root)
result.AnchorPoint = Vector2.new(0.5, 0.5)
local resultScale = make("UIScale", { Name = "ResultScale" }, result)
make("UIStroke", { Thickness = 2.5, Color = Color3.fromRGB(45, 15, 5) }, result) -- gold and red both need it over a bright sky

local prompt = nil -- { Index, At, Name, Pending, Missed, Dodged }
local doneIndex, doneSchedule = 0, nil -- no second bar for a moment; a new event or stage starts over
local resultUntil = 0
local stopFlash = nil

local function pressPrompt()
	local shown = prompt
	if not shown or shown.Pending or shown.Missed then
		return
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("BossDodge")
	if not remote then
		return
	end
	shown.Pending = true
	local stamp = workspace:GetServerTimeNow()
	task.spawn(function()
		local called, ok = pcall(remote.InvokeServer, remote, shown.Index, stamp)
		shown.Pending = false
		if called and ok then
			shown.Dodged = true
		else
			shown.Missed = true
			slider.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		end
	end)
end

bar.Activated:Connect(pressPrompt)

local function closePrompt()
	ContextActionService:UnbindAction(ACTION)
	if stopFlash then
		stopFlash()
		stopFlash = nil
	end
	prompt = nil
	local closing = UiMotion.Create(
		barScale,
		TweenInfo.new(BAR_ANIM_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Scale = 0 }
	)
	closing.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			dodge.Visible = false
		end
	end)
	closing:Play()
end

local stopResultFlash = nil

local function showResult(words, color)
	if stopResultFlash then
		stopResultFlash()
		stopResultFlash = nil
	end
	result.Text = words
	result.TextColor3 = color
	result.TextTransparency = 0
	result.Visible = true
	resultUntil = os.clock() + BossDodge.ResultSeconds
end

-- Stars fly out of the text, and burst off the local runner. Client only, gone under REDUCED EFFECTS.
local function starBurst()
	if UiMotion.Reduced() then
		return
	end
	local center = result.AbsolutePosition + result.AbsoluteSize / 2 - root.AbsolutePosition
	for i = 1, UI_STARS do
		local size = math.random(STAR_MIN, STAR_MAX)
		local angle = (i + math.random()) / UI_STARS * 2 * math.pi
		local reach = math.random(STAR_REACH_MIN, STAR_REACH_MAX)
		local star = make("ImageLabel", {
			Name = "Star",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = BossDodge.StarArt,
			Position = UDim2.fromOffset(center.X, center.Y),
			Size = UDim2.fromOffset(size * 0.4, size * 0.4),
			ZIndex = 4,
		}, root)
		UiMotion.Create(star, TweenInfo.new(STAR_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(center.X + math.cos(angle) * reach, center.Y + math.sin(angle) * reach * 0.6),
			Rotation = math.random(-200, 200),
			Size = UDim2.fromOffset(size, size),
			ImageTransparency = 1,
		}):Play()
		Debris:AddItem(star, STAR_SECONDS)
	end
	local runner = RunnerVisual.LocalRunner()
	local torso = runner and runner:FindFirstChild("Torso")
	if torso then
		local attachment = make("Attachment", { Name = "DodgeStars" }, torso)
		make("ParticleEmitter", {
			Enabled = false,
			Texture = BossDodge.StarArt,
			LockedToPart = true,
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(12, 26),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 4,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-240, 240),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.15, 2.4),
				NumberSequenceKeypoint.new(1, 0),
			}),
			LightEmission = 0.4,
		}, attachment):Emit(WORLD_STARS)
		Debris:AddItem(attachment, 1.2)
	end
end

-- "Nice Dodge!" pops out at the player in gold, then settles (design doc 4.37, owner 2026-11-06).
local function showDodged()
	showResult(BossDodge.DodgeText, GOLD)
	resultScale.Scale = POP_FROM
	local out = UiMotion.Create(
		resultScale,
		TweenInfo.new(POP_OUT_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = POP_PEAK }
	)
	out.Completed:Once(function()
		UiMotion.Create(resultScale, TweenInfo.new(POP_SETTLE_SECONDS, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
	end)
	out:Play()
	starBurst()
end

-- The hit's words, red, flashing at the player (owner 2026-11-06).
local function showHit(words)
	showResult(words, RED)
	resultScale.Scale = HIT_POP
	UiMotion.Create(resultScale, TweenInfo.new(POP_OUT_SECONDS, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	stopResultFlash = UiMotion.Pulse(result, { TextTransparency = 0.65 }, HIT_FLASH_PERIOD)
	UiMotion.Shake(result, HIT_SHAKE, POP_OUT_SECONDS * 1.5)
end

-- Places everything from the screen and the Team row, each time a bar opens.
local function place()
	local size = root.AbsoluteSize
	local small = size.Y < SMALL_SCREEN
	local width = math.min(BAR_MAX_WIDTH, size.X * BAR_WIDTH)
	local height = small and BAR_HEIGHT_SMALL or BAR_HEIGHT
	local hud = playerGui:FindFirstChild("RacerHud")
	local row = hud and hud:FindFirstChild("Level") and hud.Level:FindFirstChild("Team")
	-- root's AbsolutePosition is above 0 by the top inset; offsets inside root start there
	local bottom = row and row.AbsolutePosition.Y - root.AbsolutePosition.Y - HUD_GAP or size.Y - FALLBACK_BOTTOM
	local words = small and 18 or 26
	dodge.Size = UDim2.fromOffset(width, height)
	dodge.Position = UDim2.fromOffset(size.X / 2, bottom)
	wheel.Size = UDim2.fromOffset(height * 2.2, height * 2.2)
	subtitle.Position = UDim2.new(0.5, 0, 0, -height * 0.7)
	subtitle.Size = UDim2.new(1, 0, 0, words)
	result.Position = UDim2.fromOffset(size.X / 2, bottom - height / 2)
	result.Size = UDim2.fromOffset(width, (small and 30 or 46))
	dodge.Visible = true
end

local function currentStage()
	return ReplicatedStorage:GetAttribute("BossEventStage") or 1
end

local function openPrompt(index, at, name, startAt)
	prompt = { Index = index, At = at, Name = name }
	doneIndex = index
	slider.BackgroundColor3 = WHITE
	spot.Position = UDim2.fromScale(BossDodge.Spot(player.UserId, startAt, index, currentStage()), 0.5)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	subtitle.Text = touch and "Tap when the bar hits the white!" or "Press SPACE when the bar hits the white!"
	subtitle.TextTransparency = 0
	subtitle.Visible = true
	result.Visible = false
	place()
	UiMotion.Create(
		barScale,
		TweenInfo.new(BAR_ANIM_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	)
		:Play()
	stopFlash = UiMotion.Pulse(subtitle, { TextTransparency = 0.45 }, FLASH_PERIOD)
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			pressPrompt()
		end
		return Enum.ContextActionResult.Sink
	end, false, ACTION_PRIORITY, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

local function render()
	if result.Visible and os.clock() >= resultUntil then
		if stopResultFlash then
			stopResultFlash()
			stopResultFlash = nil
		end
		result.Visible = false
	end
	local startAt = ReplicatedStorage:GetAttribute("BossEventStart")
	local active = player:GetAttribute("BossEvent") == true
		and ReplicatedStorage:GetAttribute("BossEventPhase") == "Fight"
		and startAt ~= nil
		and player:GetAttribute("BossWaitEndsAt") == nil
	if not active then
		if prompt then
			closePrompt() -- no hit: a player in the wait is not hit by this move
		end
		return
	end
	local schedule = ReplicatedStorage:GetAttribute("BossScheduleStart") or startAt + Cfg.PrepSeconds
	if doneSchedule ~= schedule then
		doneIndex, doneSchedule = 0, schedule
		if prompt then
			closePrompt() -- no hit: the schedule it belonged to is over (BOSS_EVENT_SPEC "Phase 2")
			return
		end
	end
	-- Below 0 through the scream: the new schedule's moments start at its end.
	local since = workspace:GetServerTimeNow() - schedule - Cfg.IntroSeconds
	if prompt then
		if prompt.Dodged then
			closePrompt()
			showDodged()
		elseif since >= prompt.At and not prompt.Pending then
			local name = prompt.Name
			closePrompt()
			showHit(BossDodge.HitText[name])
		else
			slider.Position =
				UDim2.fromScale(math.clamp(1 - (prompt.At - since) / BossDodge.SweepFor(currentStage()), 0, 1), 0.5)
		end
	elseif since >= 0 then
		local index = BossDodge.IndexAtOrBefore(since) + 1
		local at, name = BossDodge.Moment(index)
		if index > doneIndex and at - since <= BossDodge.SweepFor(currentStage()) + BAR_ANIM_SECONDS then
			openPrompt(index, at, name, startAt)
		end
	end
end

RunService.Heartbeat:Connect(render)
