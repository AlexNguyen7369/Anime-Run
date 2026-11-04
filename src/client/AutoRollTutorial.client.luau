--!nonstrict
-- New player spotlight tutorial (design doc 4.21): a save with no rolls starts with auto-roll off, and this dims the screen
-- around one control until the player turns it on: the compact roll card, then the roll view's AUTO button. The server
-- decides AutoRoll; this only points at the buttons Client/RollToast already has, and a click in the hole lands on them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
local CharacterHeads = require(Shared:WaitForChild("CharacterHeads"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local ArrivalState = require(script.Parent:WaitForChild("ArrivalState"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

-- All proposed (design doc 4.21)
local REVEAL_SECONDS = 4 -- lets the starter pick's in-world reveal play first
local HOLE_PADDING = 8
local HOLE_RADIUS = 16
local SHADE_TRANSPARENCY = 0.3
local IRIS_START = 220 -- px beyond the hole where the dim starts closing in
local GLIDE_SPEED = 12 -- higher: the spotlight reaches its target sooner
local RIPPLE_SECONDS = 1.3
local RIPPLE_GROWTH = 44
local CARD_SIZE = Vector2.new(380, 104)
local CARD_SIZE_SMALL = Vector2.new(320, 76) -- phones
local SMALL_HEIGHT = 500 -- same phone test as the roll view
local CARD_GAP = 46 -- room for the arrow between the hole and the card
local DONE_SECONDS = 1.4
local CLOSE_SECONDS = 0.25
local CLOSE_TWEEN = TweenInfo.new(CLOSE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local GOLD = UiTheme.Palette.Unbanked
local STEPS = {
	Open = { Step = "STEP 1 OF 2", Text = "Tap your roll card" },
	Auto = { Step = "STEP 2 OF 2", Text = "Turn AUTO on to roll for your team" },
	Done = { Step = "NICE!", Text = "AUTO ON! Your team is rolling" },
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local toast = playerGui:WaitForChild("RollToast"):WaitForChild("Toast")
local showcase = playerGui:WaitForChild("RollShowcase")
local autoButton = showcase:WaitForChild("AutoButton")

local function new(class, name, props, parent)
	local instance = Instance.new(class)
	instance.Name = name
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local root = new("ScreenGui", "AutoRollTutorial", {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 18, -- above the roll view (14), below the starter popup (19)
	Enabled = false,
}, nil)
local layer = new("Frame", "Layer", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, root)

-- The dim is the outside of a very thick stroke, which gives the hole round corners. A stroke takes no clicks, so four
-- clear strips around the control swallow them, and nothing covers the control.
local shade = new("Frame", "Shade", { BackgroundTransparency = 1, ZIndex = 1 }, layer)
UiTheme.Corner(shade, HOLE_RADIUS)
local shadeStroke = new("UIStroke", "Dim", {
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Color = UiTheme.Palette.PanelDeep,
	Transparency = 1,
}, shade)

local strips = {}
for _, name in { "Top", "Bottom", "Left", "Right" } do
	strips[name] = new("Frame", name, { BackgroundTransparency = 1, Active = true, ZIndex = 2 }, layer)
end

local function ringFrame(name, thickness)
	local frame = new("Frame", name, { BackgroundTransparency = 1, ZIndex = 3 }, layer)
	UiTheme.Corner(frame, HOLE_RADIUS)
	local stroke = new("UIStroke", "Line", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = GOLD,
		Thickness = thickness,
	}, frame)
	return frame, stroke
end
local ring, ringStroke = ringFrame("Ring", 4)
local ripple, rippleStroke = ringFrame("Ripple", 3)
UiMotion.Pulse(ringStroke, { Thickness = 7 }, 0.55)

-- A chevron of two bars; Rotation 0 points down.
local arrow = new("Frame", "Arrow", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(36, 36),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, layer)
for side, angle in { [-1] = 45, [1] = -45 } do
	local bar = new("Frame", "Bar", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, side * 9, 0.5, 0),
		Size = UDim2.fromOffset(28, 9),
		Rotation = angle,
		BackgroundColor3 = GOLD,
		ZIndex = 4,
	}, arrow)
	UiTheme.Corner(bar, 4)
	UiTheme.Stroke(bar, 2, UiTheme.Outline, true)
end

local card = new("Frame", "Card", {
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = UiTheme.Palette.White,
	ZIndex = 5,
}, layer)
UiTheme.Corner(card, "L")
UiTheme.Gradient(card, UiTheme.Palette.Row, UiTheme.Palette.PanelDeep)
UiTheme.Stroke(card, 3, GOLD, true)
local cardScale = new("UIScale", "MotionScale", {}, card) -- UiMotion.Pop animates the same one

local head = new("ImageLabel", "Head", {
	AnchorPoint = Vector2.new(0, 0.5),
	BackgroundColor3 = UiTheme.Palette.Panel,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 6,
}, card)
UiTheme.Corner(head, 999)
UiTheme.Stroke(head, 2, GOLD, true)

local stepLabel = new("TextLabel", "Step", {
	BackgroundTransparency = 1,
	Font = UiTheme.Font,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6,
}, card)
UiTheme.Stroke(stepLabel, 2)
local textLabel = new("TextLabel", "Text", {
	BackgroundTransparency = 1,
	Font = UiTheme.Font,
	TextColor3 = UiTheme.Palette.White,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextWrapped = true,
	ZIndex = 6,
}, card)
UiTheme.Stroke(textLabel, 2)

root.Parent = playerGui

local function place(frame, x, y, w, h)
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(math.max(w, 0), math.max(h, 0))
end

local function layoutCard(screen)
	local small = screen.Y <= SMALL_HEIGHT
	local size = small and CARD_SIZE_SMALL or CARD_SIZE
	local width = math.min(size.X, screen.X - 24)
	card.Size = UDim2.fromOffset(width, size.Y)
	local headSize = size.Y - 20
	head.Position = UDim2.fromOffset(12, size.Y / 2)
	head.Size = UDim2.fromOffset(headSize, headSize)
	local left = headSize + 24
	stepLabel.TextSize = small and 14 or 17
	textLabel.TextSize = small and 19 or 25
	place(stepLabel, left, small and 6 or 10, width - left - 10, small and 16 or 22)
	place(textLabel, left, small and 22 or 32, width - left - 10, size.Y - (small and 26 or 40))
	return width, size.Y
end

-- The Team's first character is the picked starter: their drawn head is the guide.
local function refreshHead()
	local first = string.match(player:GetAttribute("Team") or "", "[^,]+")
	local spec = first and CharacterCatalog.Get(first)
	head.Image = spec and (CharacterHeads[spec.Id] or CharacterHeads[spec.Model or spec.Id]) or ""
end

local doneUntil = nil -- while set: AUTO is on and the closing animation plays
local shown = {} -- the hole as drawn: X, Y, W, H, gliding toward the target
local currentStep = nil

local function setStep(name)
	if name ~= currentStep then
		currentStep = name
		stepLabel.Text = STEPS[name].Step
		textLabel.Text = STEPS[name].Text
		UiMotion.Pop(card, 0.1)
	end
end

local function fadeShade(transparency, seconds)
	UiMotion.Create(
		shadeStroke,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = transparency }
	):Play()
end

-- Targets, clicks and the card follow the control at once; only the drawn spotlight glides.
local function spotlight(target, dt)
	local screen = layer.AbsoluteSize
	local at = target.AbsolutePosition - layer.AbsolutePosition - Vector2.one * HOLE_PADDING
	local size = target.AbsoluteSize + Vector2.one * HOLE_PADDING * 2
	local bottom = at.Y + size.Y

	place(strips.Top, 0, 0, screen.X, at.Y)
	place(strips.Bottom, 0, bottom, screen.X, screen.Y - bottom)
	place(strips.Left, 0, at.Y, at.X, size.Y)
	place(strips.Right, at.X + size.X, at.Y, screen.X - at.X - size.X, size.Y)

	local reduced = UiMotion.Reduced()
	local blend = reduced and 1 or 1 - math.exp(-dt * GLIDE_SPEED)
	shown.X = shown.X and shown.X + (at.X - shown.X) * blend or at.X - (reduced and 0 or IRIS_START)
	shown.Y = shown.Y and shown.Y + (at.Y - shown.Y) * blend or at.Y - (reduced and 0 or IRIS_START)
	shown.W = shown.W and shown.W + (size.X - shown.W) * blend or size.X + (reduced and 0 or IRIS_START * 2)
	shown.H = shown.H and shown.H + (size.Y - shown.H) * blend or size.Y + (reduced and 0 or IRIS_START * 2)
	place(shade, shown.X, shown.Y, shown.W, shown.H)
	place(ring, shown.X, shown.Y, shown.W, shown.H)
	shadeStroke.Thickness = math.max(screen.X, screen.Y) * 2

	local wave = os.clock() / RIPPLE_SECONDS % 1
	ripple.Visible = not reduced and not doneUntil
	local grow = RIPPLE_GROWTH * wave
	place(ripple, shown.X - grow / 2, shown.Y - grow / 2, shown.W + grow, shown.H + grow)
	rippleStroke.Transparency = wave

	-- Below a control in the top half of the screen, above one in the bottom half
	local width, height = layoutCard(screen)
	local below = at.Y + size.Y / 2 < screen.Y / 2
	local cardY = below and bottom + CARD_GAP or at.Y - CARD_GAP - height
	local centre = at.X + size.X / 2
	card.Position = UDim2.fromOffset(math.clamp(centre, width / 2 + 12, screen.X - width / 2 - 12), cardY)

	local bob = reduced and 0 or math.sin(os.clock() * 5) * 5
	arrow.Rotation = below and 180 or 0
	arrow.Position = UDim2.fromOffset(centre, (below and bottom + CARD_GAP / 2 or at.Y - CARD_GAP / 2) + bob)
	head.Rotation = reduced and 0 or math.sin(os.clock() * 2.5) * 4
end

local startAt = 0
player:GetAttributeChangedSignal("StarterPicked"):Connect(function()
	startAt = os.clock() + REVEAL_SECONDS
end)

ArrivalState.WaitForLoading()

local showing = false
local lastTarget = toast
local stepper

local function hide()
	root.Enabled = false
	showing = false
	shown = {}
	currentStep = nil
	shadeStroke.Transparency = 1
	arrow.Visible = true
	ringStroke.Transparency = 0
	cardScale.Scale = 1
	for _, strip in strips do
		strip.Visible = true
	end
end

stepper = RunService.RenderStepped:Connect(function(dt)
	if doneUntil then
		spotlight(lastTarget, dt)
		if os.clock() >= doneUntil then
			doneUntil = nil
			hide()
		end
		return
	end
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end
	if (player:GetAttribute("Rolls") or 0) > 0 then
		root:Destroy() -- rolled: this player never needs it again
		stepper:Disconnect()
		return
	end
	if showing and player:GetAttribute("AutoRoll") == true then
		-- Turned on: the strips let go at once, and the rest plays out over the roll view
		for _, strip in strips do
			strip.Visible = false
		end
		doneUntil = os.clock() + DONE_SECONDS
		arrow.Visible = false
		setStep("Done")
		UiFeedback.Play("AutoOn", lastTarget)
		fadeShade(1, DONE_SECONDS)
		task.delay(DONE_SECONDS - CLOSE_SECONDS, function()
			UiMotion.Create(cardScale, CLOSE_TWEEN, { Scale = 0 }):Play()
			UiMotion.Create(ringStroke, CLOSE_TWEEN, { Transparency = 1 }):Play()
		end)
		return
	end
	local waiting = player:GetAttribute("NeedsStarter") == true
		or player:GetAttribute("AutoRoll") ~= false
		or os.clock() < startAt
	-- An open panel hides the roll card, and the card comes back with the panel shut
	local enlarged = showcase.Enabled and autoButton.Visible
	local target = enlarged and autoButton or toast
	if waiting or not target.Visible then
		if showing then
			hide()
		end
		return
	end
	if not showing then
		showing = true
		root.Enabled = true
		refreshHead()
		fadeShade(SHADE_TRANSPARENCY, 0.35)
	end
	lastTarget = target
	setStep(enlarged and "Auto" or "Open")
	spotlight(target, dt)
end)
