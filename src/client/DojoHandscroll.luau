--!nonstrict
-- The horizontal handscroll (makimono) of the Scroll Dojo look (design doc 4.46, docs/UI_SCROLL_SPEC.md Kit and
-- Motion): parchment paper between two wooden rollers that unrolls from its centre. Build adds it to a panel; PanelSwitch
-- then runs Open / Close in place of its scale motion. Content in Paper.Content keeps its size and place: the paper
-- clips it, so the unroll reveals it in place and every control is live the moment it shows (4.20 input rule).
-- Colours from UiTheme.Scroll.Skins.Parchment. Sizes and timings are proposed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local C = UiTheme.Scroll.Skins.Parchment
local DojoHandscroll = {}

DojoHandscroll.OPEN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
DojoHandscroll.CLOSE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
DojoHandscroll.FADE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- reduced effects
local ROLLER, CAP_OUT, CAP_H, STRIP = 26, 6, 18, 10 -- px

local handles = setmetatable({}, { __mode = "k" }) -- target -> handle

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function gradient(parent, a, b, rotation)
	make("UIGradient", "Gradient", parent, { Color = ColorSequence.new(a, b), Rotation = rotation })
end

-- Builds the handscroll inside `target` (a GuiObject panel) and returns its handle; a second call returns the first.
-- opts.ZIndex: the scroll's ZIndex (default 0, under the panel's own children).
function DojoHandscroll.Build(target, opts)
	if handles[target] then
		return handles[target]
	end
	opts = opts or {}
	local z = opts.ZIndex or 0
	local white = Color3.new(1, 1, 1)
	local root = make("Frame", "Handscroll", nil, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Active = false,
	})
	local parts = {} -- every drawn frame: the reduced fade runs on these (all rest at transparency 0)
	local function part(name, parent, props)
		local frame = make("Frame", name, parent, { BorderSizePixel = 0, BackgroundColor3 = white, ZIndex = z })
		for key, value in props do
			frame[key] = value
		end
		table.insert(parts, frame)
		return frame
	end
	local paper = part("Paper", root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
	})
	gradient(paper, C.Paper, C.PaperShade, 90)
	for i, y in { 0, 1 } do
		local strip = part(i == 1 and "StripTop" or "StripBottom", paper, {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, STRIP),
			ZIndex = z + 1,
		})
		gradient(strip, C.RuleTop, C.RuleBottom, 90)
	end
	local content = make("Frame", "Content", paper, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
	})
	local rollers = {}
	for _, side in { "RollerL", "RollerR" } do
		local roller = part(side, root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, ROLLER, 1, 0),
			ZIndex = z + 3,
		})
		gradient(roller, C.RodTop, C.RodBottom, 0)
		make("UICorner", "Corner", roller, { CornerRadius = UDim.new(0, ROLLER / 2) })
		for i, y in { 0, 1 } do
			local cap = part(i == 1 and "CapTop" or "CapBottom", roller, {
				AnchorPoint = Vector2.new(0.5, y),
				Position = UDim2.new(0.5, 0, y, (y * 2 - 1) * CAP_OUT),
				Size = UDim2.new(1, 6, 0, CAP_H),
				ZIndex = z + 4,
			})
			gradient(cap, C.CapLight, C.CapDark, 0)
			make("UICorner", "Corner", cap, { CornerRadius = UDim.new(0, 6) })
		end
		rollers[side] = roller
	end
	local unroll = make("NumberValue", "Unroll", root, { Value = 1 })

	local handle = { Root = root, Paper = paper, Content = content, Progress = 1 }
	local running = nil -- { Tweens, Done } while a motion plays

	-- p: 0 rolled up at the centre, 1 open edge to edge. Content is 1/p of the paper wide, so its own size never changes.
	function handle.SetProgress(p)
		p = math.clamp(p, 0, 1)
		handle.Progress = p
		local q = math.max(p, 0.001)
		paper.Visible = p > 0
		paper.Size = UDim2.fromScale(q, 1)
		content.Size = UDim2.fromScale(1 / q, 1)
		rollers.RollerL.Position = UDim2.fromScale(0.5 - q / 2, 0.5)
		rollers.RollerR.Position = UDim2.fromScale(0.5 + q / 2, 0.5)
	end

	local function setFaded(t)
		for _, frame in parts do
			frame.BackgroundTransparency = t
		end
	end

	-- While a roll plays, the target's content rides in Paper.Content so the paper's clip reveals it as the rollers pass
	-- (4.46 "content inks in as the paper reaches it"). Content has the target's absolute size and place, so nothing
	-- moves on screen. Only GuiObjects and the layouts that place them move; modifiers that act on the target itself
	-- (UIScale, UIAspectRatioConstraint, UISizeConstraint, UICorner, UIStroke, UIGradient), values such as MotionK and
	-- scripts stay. At rest every moved child is back under the target (code and tests look up panel.X).
	local moved = {}
	local function movable(child)
		return child ~= root and (child:IsA("GuiObject") or child:IsA("UIGridStyleLayout") or child:IsA("UIPadding"))
	end
	local function gather()
		for _, child in target:GetChildren() do -- child order kept: ties in ZIndex keep their draw order
			if movable(child) then
				table.insert(moved, child)
				child.Parent = content
			end
		end
	end
	local function restore()
		local list = moved
		moved = {}
		for _, child in list do
			if child.Parent == content then -- not destroyed or moved by its owner meanwhile
				child.Parent = target
			end
		end
	end

	-- Cancels the running motion where it is (the content goes back under the target); its onDone never fires.
	function handle.Stop()
		restore()
		local motion = running
		running = nil
		if motion then
			for _, tween in motion.Tweens do
				tween:Cancel()
			end
		end
	end

	-- Unrolls (shown) or rolls up; onDone() runs once the motion completes. Reduced effects: a short fade, no roll.
	function handle.Play(shown, onDone)
		handle.Stop()
		local motion = { Tweens = {} }
		running = motion
		local tweens = motion.Tweens
		if UiMotion.Reduced() then
			handle.SetProgress(1)
			setFaded(shown and 1 or 0)
			for _, frame in parts do
				-- TweenService, not UiMotion.Create: the reduced-effects fade is the motion that stays (4.46)
				table.insert(
					tweens,
					TweenService:Create(frame, DojoHandscroll.FADE, { BackgroundTransparency = shown and 0 or 1 })
				)
			end
		else
			setFaded(0)
			if shown and handle.Progress >= 1 then
				handle.SetProgress(0) -- a fresh open; a reopen mid-close unrolls from where it is
			end
			unroll.Value = handle.Progress
			-- Deferred: code that sets Visible = true and then reads panel.X in the same frame still finds it there.
			task.defer(function()
				if running == motion then
					gather()
				end
			end)
			local info = shown and DojoHandscroll.OPEN or DojoHandscroll.CLOSE
			table.insert(tweens, UiMotion.Create(unroll, info, { Value = shown and 1 or 0 }))
		end
		tweens[1].Completed:Connect(function(state)
			if running ~= motion or state ~= Enum.PlaybackState.Completed then
				return
			end
			running = nil
			restore()
			if onDone then
				onDone()
			end
			setFaded(0) -- a faded-out scroll is back at rest for its next open (its panel is hidden by now)
		end)
		for _, tween in tweens do
			tween:Play()
		end
	end

	unroll.Changed:Connect(function(value)
		if running then
			handle.SetProgress(value)
		end
	end)

	handle.SetProgress(1)
	root.Parent = target
	target:SetAttribute("Handscroll", true)
	handles[target] = handle
	return handle
end

function DojoHandscroll.Get(target)
	return target and handles[target]
end

function DojoHandscroll.Open(target)
	local handle = handles[target]
	if handle then
		handle.Play(true)
	end
end

-- Rolls `target` up; onDone() runs when it is closed (not when a reopen or Stop cuts it short).
function DojoHandscroll.Close(target, onDone)
	local handle = handles[target]
	if handle then
		handle.Play(false, onDone)
	elseif onDone then
		onDone()
	end
end

return DojoHandscroll
