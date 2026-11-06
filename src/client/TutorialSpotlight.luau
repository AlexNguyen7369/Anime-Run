--!nonstrict
-- The spotlight tutorials share (design doc 4.21, 4.36): the screen dims around one control, a ring and an arrow mark it, and a
-- card with the starter's head says what to do. A click in the hole lands on the control. Client/AutoRollTutorial, Client/SidekickTutorial.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
local CharacterHeads = require(Shared:WaitForChild("CharacterHeads"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

-- All proposed (design doc 4.21)
local HOLE_PADDING = 8
local HOLE_RADIUS = 16
local IRIS_START = 220 -- px beyond the hole where the dim starts closing in
local GLIDE_SPEED = 12 -- higher: the spotlight reaches its target sooner
local RIPPLE_SECONDS = 1.3
local RIPPLE_GROWTH = 44
local CARD_SIZE = Vector2.new(380, 104)
local CARD_SIZE_SMALL = Vector2.new(320, 76) -- phones
local SMALL_HEIGHT = 500 -- same phone test as the roll view
local CARD_GAP = 46 -- room for the arrow between the hole and the card
local GOLD = UiTheme.Palette.Unbanked

local TutorialSpotlight = {}

local function new(class, name, props, parent)
	local instance = Instance.new(class)
	instance.Name = name
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function place(frame, x, y, w, h)
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(math.max(w, 0), math.max(h, 0))
end

function TutorialSpotlight.new(guiName, displayOrder)
	local player = Players.LocalPlayer
	local self = {}

	local root = new("ScreenGui", guiName, {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = displayOrder,
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

	root.Parent = player:WaitForChild("PlayerGui")

	-- `extra` px of the card's foot stay free, for a button in it.
	local function layoutCard(screen, extra)
		local small = screen.Y <= SMALL_HEIGHT
		local size = small and CARD_SIZE_SMALL or CARD_SIZE
		local width = math.min(size.X, screen.X - 24)
		card.Size = UDim2.fromOffset(width, size.Y + extra)
		local headSize = size.Y - 20
		head.Position = UDim2.fromOffset(12, size.Y / 2)
		head.Size = UDim2.fromOffset(headSize, headSize)
		local left = headSize + 24
		stepLabel.TextSize = small and 14 or 17
		textLabel.TextSize = small and 19 or 25
		place(stepLabel, left, small and 6 or 10, width - left - 10, small and 16 or 22)
		place(textLabel, left, small and 22 or 32, width - left - 10, size.Y - (small and 26 or 40))
		return width, size.Y + extra
	end

	local shown = {} -- the hole as drawn: X, Y, W, H, gliding toward the target
	local currentStep = nil

	-- The Team's first character is the picked starter: their drawn head is the guide.
	function self.RefreshHead()
		local first = string.match(player:GetAttribute("Team") or "", "[^,]+")
		local spec = first and CharacterCatalog.Get(first)
		head.Image = spec and (CharacterHeads[spec.Id] or CharacterHeads[spec.Model or spec.Id]) or ""
	end

	-- name: which step, step: { Step, Text }.
	function self.SetStep(name, step)
		if name ~= currentStep then
			currentStep = name
			stepLabel.Text = step.Step
			textLabel.Text = step.Text
			UiMotion.Pop(card, 0.1)
		end
	end

	function self.FadeShade(transparency, seconds)
		UiMotion.Create(
			shadeStroke,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = transparency }
		):Play()
	end

	function self.SetStripsVisible(visible)
		for _, strip in strips do
			strip.Visible = visible
		end
	end

	-- Targets, clicks and the card follow the control at once; only the drawn spotlight glides.
	-- options: Quiet (no ripple), FixedCard (the card stays above the screen's middle, for a target in the card or the card itself),
	-- CardExtra (px of the card's foot kept free).
	function self.Aim(target, dt, options)
		options = options or {}
		local screen = layer.AbsoluteSize
		local width, height = layoutCard(screen, options.CardExtra or 0)
		if options.FixedCard then
			card.Position = UDim2.fromOffset(screen.X / 2, screen.Y / 2 - height - 10)
		end
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
		ripple.Visible = not reduced and not options.Quiet
		local grow = RIPPLE_GROWTH * wave
		place(ripple, shown.X - grow / 2, shown.Y - grow / 2, shown.W + grow, shown.H + grow)
		rippleStroke.Transparency = wave

		-- Below a control in the top half of the screen, above one in the bottom half
		local below = at.Y + size.Y / 2 < screen.Y / 2
		local centre = at.X + size.X / 2
		if not options.FixedCard then
			local cardY = below and bottom + CARD_GAP or at.Y - CARD_GAP - height
			card.Position = UDim2.fromOffset(math.clamp(centre, width / 2 + 12, screen.X - width / 2 - 12), cardY)
		end

		local bob = reduced and 0 or math.sin(os.clock() * 5) * 5
		arrow.Rotation = below and 180 or 0
		arrow.Position = UDim2.fromOffset(centre, (below and bottom + CARD_GAP / 2 or at.Y - CARD_GAP / 2) + bob)
		head.Rotation = reduced and 0 or math.sin(os.clock() * 2.5) * 4
	end

	-- Off, and every part back as it starts.
	function self.Reset()
		root.Enabled = false
		shown = {}
		currentStep = nil
		shadeStroke.Transparency = 1
		arrow.Visible = true
		ringStroke.Transparency = 0
		cardScale.Scale = 1
		self.SetStripsVisible(true)
	end

	self.Root = root
	self.Card = card
	self.CardScale = cardScale
	self.Arrow = arrow
	self.Ring = ring
	self.Ripple = ripple
	self.RingStroke = ringStroke
	return self
end

return TutorialSpotlight
