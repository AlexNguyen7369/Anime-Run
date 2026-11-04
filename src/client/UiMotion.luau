--!nonstrict
-- Reduced motion for UI (docs/HUD_LAYOUT_SPEC.md section 7): Roblox's Reduced Motion setting or the in-game
-- REDUCED EFFECTS toggle. UI tweens go through Create so they land at once while motion is reduced.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UiMotion = {}

local INSTANT = TweenInfo.new(0)

function UiMotion.Reduced()
	local player = Players.LocalPlayer
	return GuiService.ReducedMotionEnabled or (player ~= nil and player:GetAttribute("ReduceEffects") == true)
end

-- TweenService:Create with the same arguments; a reduced tween takes 0 s and never repeats.
function UiMotion.Create(instance, info, goal)
	return TweenService:Create(instance, UiMotion.Reduced() and INSTANT or info, goal)
end

-- Motion presets (section 10): Pop, SlideIn, Shine, Pulse, Shake, Float (and Cascade, Mark, Fade, design doc
-- 4.20; Slam, Impact, Burst, Fly, Fill, docs/UI_FEEDBACK_SPEC.md section 3); each lands at once while reduced.

-- The UIScale the presets animate. A layout UIScale (any other name) is never touched: nil then.
local function motionScale(gui)
	local scale = gui:FindFirstChildOfClass("UIScale")
	if scale and scale.Name ~= "MotionScale" then
		return nil
	end
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "MotionScale"
		scale.Parent = gui
	end
	return scale
end

-- The UIScale Pop and Slam animate. Only one UIScale applies to a gui, so a button's HoverScale takes the motion; its
-- RacerMotion tweens are not fought: a later Play overrides the running tween on the same property, whichever came first.
local function popScale(gui)
	return motionScale(gui) or gui:FindFirstChild("HoverScale")
end

-- Where that motion ends: 1, or RacerMotion's hover size on a button the pointer is on (the harness pins both).
local function popRest(gui, scale)
	local hovered = scale.Name == "HoverScale"
		and gui.GuiState == Enum.GuiState.Hover
		and (not gui:IsA("GuiButton") or gui.Active)
	return hovered and 1.035 or 1
end

-- Grows the gui by `amount` (default 12%) and settles back, about 0.18 s.
function UiMotion.Pop(gui, amount)
	local scale = popScale(gui)
	if not scale then
		return
	end
	if UiMotion.Reduced() then
		scale.Scale = popRest(gui, scale)
		return
	end
	local up = TweenService:Create(
		scale,
		TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1 + (amount or 0.12) }
	)
	up.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			TweenService:Create(
				scale,
				TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = popRest(gui, scale) }
			):Play()
		end
	end)
	up:Play()
end

-- Moves the gui from `offset` (Vector2, px) to where it is now, fading a CanvasGroup in; Back easing.
function UiMotion.SlideIn(gui, offset, duration)
	local target = gui.Position
	duration = duration or 0.25
	if UiMotion.Reduced() then
		if gui:IsA("CanvasGroup") then
			gui.GroupTransparency = 0
		end
		return
	end
	gui.Position = target + UDim2.fromOffset(offset.X, offset.Y)
	TweenService:Create(gui, TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = target,
	}):Play()
	if gui:IsA("CanvasGroup") then
		gui.GroupTransparency = 1
		TweenService:Create(gui, TweenInfo.new(duration * 0.8), { GroupTransparency = 0 }):Play()
	end
end

-- Sweeps one light band across the gui (a plate or a bar fill). The overlay is reused per gui.
function UiMotion.Shine(gui, duration)
	if UiMotion.Reduced() then
		return
	end
	local overlay = gui:FindFirstChild("MotionShine")
	if not overlay then
		overlay = Instance.new("Frame")
		overlay.Name = "MotionShine"
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = Color3.new(1, 1, 1)
		overlay.BorderSizePixel = 0
		overlay.Active = false
		overlay.ZIndex = gui.ZIndex
		local corner = gui:FindFirstChildOfClass("UICorner")
		if corner then
			corner:Clone().Parent = overlay
		end
		local band = Instance.new("UIGradient")
		band.Rotation = 20
		band.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		band.Parent = overlay
		overlay.Parent = gui
	end
	local band = overlay:FindFirstChildOfClass("UIGradient")
	band.Offset = Vector2.new(-1, 0)
	TweenService:Create(
		band,
		TweenInfo.new(duration or 0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Offset = Vector2.new(1, 0) }
	):Play()
end

-- Loops `instance` between its current properties and `goal` (reversing), one way in `period` seconds.
-- Returns a stop function that puts the starting values back. While reduced nothing loops.
function UiMotion.Pulse(instance, goal, period)
	local start = {}
	for property in goal do
		start[property] = instance[property]
	end
	if UiMotion.Reduced() then
		return function() end
	end
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(period or 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		goal
	)
	tween:Play()
	return function()
		tween:Cancel()
		for property, value in start do
			instance[property] = value
		end
	end
end

-- Shakes the gui sideways by up to `px` for `duration` seconds, then puts it back. A shake over a running one takes
-- over and keeps the first one's home, so overlaps never leave the gui off home.
local shakes = setmetatable({}, { __mode = "k" }) -- gui -> { Home, Run } while it shakes
function UiMotion.Shake(gui, px, duration)
	if UiMotion.Reduced() then
		return
	end
	local shake = shakes[gui] or { Home = gui.Position, Run = 0 }
	shakes[gui] = shake
	shake.Run += 1
	local run = shake.Run
	local steps = 6
	task.spawn(function()
		for i = 1, steps do
			local dx = (i % 2 == 0 and -1 or 1) * (px or 8) * (1 - (i - 1) / steps)
			gui.Position = shake.Home + UDim2.fromOffset(dx, 0)
			task.wait((duration or 0.3) / steps)
			if shake.Run ~= run then
				return
			end
		end
		gui.Position = shake.Home
		shakes[gui] = nil
	end)
end

-- Lights up the first 12 `items` one after another (background and their `edgeName` stroke fade in to the values
-- they had): for tiles a grid or list layout positions, where a slide would not show.
local CASCADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local resting = setmetatable({}, { __mode = "k" }) -- instance -> its transparency at rest while a cascade runs
local function restOf(instance, property)
	local rest = resting[instance]
	if rest == nil then
		rest = instance[property]
		resting[instance] = rest
	end
	return rest
end
function UiMotion.Cascade(items, edgeName)
	if UiMotion.Reduced() then
		return
	end
	for i = 1, math.min(#items, 12) do
		local item = items[i]
		local edge = edgeName and item:FindFirstChild(edgeName)
		-- A cascade restarted mid-way (a quick reopen) still ends on the rest values, never on a faded one.
		local fill, line = restOf(item, "BackgroundTransparency"), edge and restOf(edge, "Transparency")
		item.BackgroundTransparency = 1
		if edge then
			edge.Transparency = 1
		end
		task.delay((i - 1) * 0.03, function()
			local tween = TweenService:Create(item, CASCADE, { BackgroundTransparency = fill })
			tween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					resting[item] = nil
				end
			end)
			tween:Play()
			if edge then
				local edgeTween = TweenService:Create(edge, CASCADE, { Transparency = line })
				edgeTween.Completed:Connect(function(state)
					if state == Enum.PlaybackState.Completed then
						resting[edge] = nil
					end
				end)
				edgeTween:Play()
			end
		end)
	end
end

-- Tweens a selection marker (a tab's or tile's edge / fill colour) to its new state in 0.15 s (design doc 4.20).
local MARK = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
function UiMotion.Mark(instance, goal)
	UiMotion.Create(instance, MARK, goal):Play()
end

-- Toasts (design doc 4.20): fades a plain gui (its fill, text and UIStroke children) in from clear, or out and
-- then hides it. Rest transparencies are read on the first call and put back, so it always ends at rest; a new
-- call cancels the running fade. While reduced it shows / hides at once.
local fades = setmetatable({}, { __mode = "k" })
function UiMotion.Fade(gui, shown, duration)
	local fade = fades[gui]
	if not fade then
		fade = { Parts = { { gui, "BackgroundTransparency", gui.BackgroundTransparency } } }
		if gui:IsA("TextLabel") or gui:IsA("TextButton") then
			table.insert(fade.Parts, { gui, "TextTransparency", gui.TextTransparency })
		end
		for _, child in gui:GetChildren() do
			if child:IsA("UIStroke") then
				table.insert(fade.Parts, { child, "Transparency", child.Transparency })
			end
		end
		fades[gui] = fade
	end
	for _, tween in fade.Tweens or {} do
		tween:Cancel()
	end
	local tweens = {}
	fade.Tweens = tweens
	local reduced = UiMotion.Reduced()
	for _, part in fade.Parts do
		part[1][part[2]] = (shown and not reduced) and 1 or part[3]
	end
	if shown then
		gui.Visible = true
	end
	if reduced then
		if not shown then
			gui.Visible = false
		end
		return
	end
	local info = TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in fade.Parts do
		local tween = TweenService:Create(part[1], info, { [part[2]] = shown and part[3] or 1 })
		table.insert(tweens, tween)
		tween:Play()
	end
	if not shown then
		tweens[1].Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and fade.Tweens == tweens then
				gui.Visible = false
				for _, part in fade.Parts do
					part[1][part[2]] = part[3]
				end
			end
		end)
	end
end

-- A short text ("+$1.2m") that rises from `position` inside `parent`, fades out and is removed.
function UiMotion.Float(parent, text, color, position)
	if UiMotion.Reduced() then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "MotionFloat"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = position
	label.Size = UDim2.fromOffset(200, 30)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 26
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.Text = text
	label.ZIndex = 20
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(18, 22, 43)
	stroke.Thickness = 2.5
	stroke.Parent = label
	label.Parent = parent
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = position - UDim2.fromOffset(0, 46), TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	task.delay(1.15, function()
		label:Destroy()
	end)
end

-- From scale 1.5 down to rest with Back easing, 0.18 s. A second Slam restarts it: Play overrides the running tween on
-- the same property, so it still ends at rest.
function UiMotion.Slam(gui)
	local scale = popScale(gui)
	if not scale then
		return
	end
	if UiMotion.Reduced() then
		scale.Scale = popRest(gui, scale)
		return
	end
	scale.Scale = 1.5
	TweenService:Create(
		scale,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = popRest(gui, scale) }
	):Play()
end

-- A bar tween, 0.2 s. While reduced the size is exact on return.
function UiMotion.Fill(barFill, goalSize)
	UiMotion.Create(barFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = goalSize })
		:Play()
	if UiMotion.Reduced() then
		barFill.Size = goalSize
	end
end

-- UiFx: the one overlay ScreenGui of Impact, Burst and Fly, made on first use, disabled while no piece is out. Pieces are
-- pooled Frames that never take a click; past FX_MAX a preset draws fewer, it never waits.
local FX_MAX = 24
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 214, 90)
local SOLID = NumberSequence.new(0)
-- A speed line, drawn pointing outward: clear at its centre end, solid at its tip.
local STREAK = NumberSequence.new(1, 0)
local SHADE = ColorSequence.new(WHITE, Color3.fromRGB(205, 205, 215))

local fxGui
local fxFree = {}
local fxOut = 0

local function newPiece()
	local piece = Instance.new("Frame")
	piece.Name = "FxPiece"
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.BorderSizePixel = 0
	piece.Active = false
	piece.Interactable = false
	Instance.new("UICorner").Parent = piece
	local gradient = Instance.new("UIGradient")
	gradient.Color = SHADE
	gradient.Parent = piece
	Instance.new("UIStroke").Parent = piece
	piece.Parent = fxGui
	return piece
end

-- A shown piece centred on `at` (screen px), or nil when the pool is spent or PlayerGui is not there yet.
local function takePiece(at, size, color, rotation, radius)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if fxOut >= FX_MAX or not playerGui then
		return nil
	end
	if not fxGui then
		fxGui = Instance.new("ScreenGui")
		fxGui.Name = "UiFx"
		fxGui.IgnoreGuiInset = true
		fxGui.ResetOnSpawn = false
		fxGui.DisplayOrder = 100 -- above every game gui (the highest is 60)
		fxGui.Parent = playerGui
	end
	fxOut += 1
	fxGui.Enabled = true
	local piece = table.remove(fxFree) or newPiece()
	piece.Position = UDim2.fromOffset(at.X, at.Y)
	piece.Size = UDim2.fromOffset(size.X, size.Y)
	piece.Rotation = rotation or 0
	piece.BackgroundColor3 = color
	piece.BackgroundTransparency = 0
	piece.UICorner.CornerRadius = radius or UDim.new(0, 0)
	piece.UIGradient.Transparency = SOLID
	piece.UIStroke.Enabled = false
	piece.UIStroke.Transparency = 0
	piece.Visible = true
	return piece
end

local function releasePiece(piece)
	piece.Visible = false
	table.insert(fxFree, piece)
	fxOut -= 1
	if fxOut == 0 then
		fxGui.Enabled = false
	end
end

-- Tweens a piece to `goal` and puts it back in the pool.
local function sendPiece(piece, duration, goal)
	local tween =
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tween.Completed:Once(function()
		releasePiece(piece)
	end)
	tween:Play()
end

-- `target` (a gui, or a Vector2 in UiFx's pixels) as a point in UiFx's pixels.
local function fxPoint(target)
	if typeof(target) == "Vector2" then
		return target
	end
	local point = target.AbsolutePosition + target.AbsoluteSize / 2
	local owner = target:FindFirstAncestorOfClass("ScreenGui")
	if owner and not owner.IgnoreGuiInset then
		point += (GuiService:GetGuiInset())
	end
	return point
end

local function offset(point)
	return UDim2.fromOffset(point.X, point.Y)
end

-- Pop, Shake, one flash and one ring from the gui. opts.Color tints them.
function UiMotion.Impact(gui, opts)
	UiMotion.Pop(gui)
	UiMotion.Shake(gui, 6, 0.2)
	if UiMotion.Reduced() then
		return
	end
	local color = opts and opts.Color or WHITE
	local at, size = fxPoint(gui), gui.AbsoluteSize
	local corner = gui:FindFirstChildOfClass("UICorner")
	local flash = takePiece(at, size, color, 0, corner and corner.CornerRadius)
	if flash then
		sendPiece(flash, 0.16, { BackgroundTransparency = 1 })
	end
	local side = math.max(size.X, size.Y)
	local ring = takePiece(at, Vector2.new(side, side), color, 0, UDim.new(0.5, 0))
	if ring then
		ring.BackgroundTransparency = 1
		local stroke = ring.UIStroke
		stroke.Enabled = true
		stroke.Color = color
		stroke.Thickness = 5
		TweenService:Create(stroke, TweenInfo.new(0.32), { Transparency = 1 }):Play()
		sendPiece(ring, 0.32, { Size = UDim2.fromOffset(side * 1.5, side * 1.5) })
	end
end

-- Radial shards in opts.Color and white anime speed lines from a gui or a point (Vector2), about 0.45 s. Never in the
-- roll (ROLL_ANIMATION_SPEC).
function UiMotion.Burst(target, opts)
	if UiMotion.Reduced() then
		return
	end
	local at = fxPoint(target)
	local color = opts and opts.Color or GOLD
	local reach = workspace.CurrentCamera.ViewportSize.Y * 0.34
	local count = 8
	for i = 1, count do
		local angle = (i + math.random() * 0.5) / count * 2 * math.pi
		local way = Vector2.new(math.cos(angle), math.sin(angle))
		local line = takePiece(
			at + way * reach * 0.35,
			Vector2.new(reach * 0.5, math.max(3, reach * 0.012)),
			WHITE,
			math.deg(angle)
		)
		if line then
			line.UIGradient.Transparency = STREAK
			sendPiece(line, 0.3, {
				Position = offset(at + way * reach * 1.15),
				Size = UDim2.fromOffset(reach * 0.2, 1),
				BackgroundTransparency = 1,
			})
		end
		local side = reach * (0.06 + math.random() * 0.05)
		local shardAngle = angle + math.pi / count
		local shardWay = Vector2.new(math.cos(shardAngle), math.sin(shardAngle))
		local shard = takePiece(at, Vector2.new(side, side), color, math.random(0, 90), UDim.new(0.15, 0))
		if shard then
			sendPiece(shard, 0.45, {
				Position = offset(at + shardWay * reach * (0.55 + math.random() * 0.35)),
				Size = UDim2.fromOffset(0, 0),
				Rotation = shard.Rotation + 180,
			})
		end
	end
end

-- `count` coins arc from one gui to the other, 0.04 s apart, about 0.5 s each; then the target pops and onLanded fires.
-- Reduced, or no gui to fly between: no coins, and the same ending at once.
function UiMotion.Fly(fromGui, toGui, count, color, onLanded)
	local function land()
		if toGui then
			UiMotion.Pop(toGui)
		end
		if onLanded then
			onLanded()
		end
	end
	if UiMotion.Reduced() or not fromGui or not toGui then
		land()
		return
	end
	local stagger, flight = 0.04, 0.5
	local from, to = fxPoint(fromGui), fxPoint(toGui)
	local side = math.clamp(workspace.CurrentCamera.ViewportSize.Y * 0.03, 14, 32)
	local coins = {}
	for _ = 1, count do
		local coin = takePiece(from, Vector2.new(side, side), color or GOLD, 0, UDim.new(0.5, 0))
		if coin then
			local distance = (to - from).Magnitude
			local bend = (from + to) / 2 + Vector2.new((math.random() - 0.5) * distance * 0.4, -distance * 0.3)
			table.insert(coins, { Piece = coin, Bend = bend })
		end
	end
	task.spawn(function()
		local started = os.clock()
		local last = (#coins - 1) * stagger + flight
		while #coins > 0 and os.clock() - started < last do
			local elapsed = os.clock() - started
			for i, coin in coins do
				local t = TweenService:GetValue(
					math.clamp((elapsed - (i - 1) * stagger) / flight, 0, 1),
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.In
				)
				coin.Piece.Position = offset(from:Lerp(coin.Bend, t):Lerp(coin.Bend:Lerp(to, t), t))
			end
			RunService.Heartbeat:Wait()
		end
		for _, coin in coins do
			releasePiece(coin.Piece)
		end
		land()
	end)
end

return UiMotion
