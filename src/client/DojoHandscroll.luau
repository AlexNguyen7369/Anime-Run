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

	-- Content inks in as the rollers pass (4.46; owner 2026-11-20: content never changes parent, so panel.X lookups hold
	-- mid-roll). At roll start the target's shown content splits into blocks: a GuiObject at least CONTAINER of the
	-- target's width with GuiObject children is a container and is walked into (to DEPTH levels), anything else is a
	-- block. A block not reached yet is not drawn: its transparencies go to 1 and it is not Interactable. The scroll never
	-- writes Visible, so a part its owner hides or shows mid-roll keeps the owner's choice (Visible changes fire no
	-- signal when the value is already the same, so a Visible-based hide could not tell). Opening, a block shows once the
	-- paper's half-width reaches its centre and fades in over INK s; closing, it hides when the paper edge passes inward
	-- over its centre. At rest every block is back at its own transparencies and Interactable.
	-- shortcut: a transparency the owner sets on a hidden block mid-roll is put back to the saved value at rest; fine
	-- while panel code only toggles Visible during an open, revisit if one fades its own parts in.
	local CONTAINER, DEPTH, INK = 0.6, 6, 0.15
	local FADED = {
		GuiObject = { "BackgroundTransparency" },
		TextLabel = { "TextTransparency", "TextStrokeTransparency" },
		TextButton = { "TextTransparency", "TextStrokeTransparency" },
		TextBox = { "TextTransparency", "TextStrokeTransparency" },
		ImageLabel = { "ImageTransparency" },
		ImageButton = { "ImageTransparency" },
		ViewportFrame = { "ImageTransparency" },
		ScrollingFrame = { "ScrollBarImageTransparency" },
		UIStroke = { "Transparency" },
	}
	local blocks = {} -- { Gui, At (0..1 centre distance), Hidden, Interactable, Saved = { [object] = { prop = value } }, Tweens }
	local function cancelTweens(block)
		for _, tween in block.Tweens do
			tween:Cancel()
		end
		block.Tweens = {}
	end
	-- Back at its own transparencies and Interactable.
	local function unfade(block)
		cancelTweens(block)
		for object, values in block.Saved do
			for prop, value in values do
				object[prop] = value
			end
		end
		if block.Hidden then
			block.Hidden = false
			block.Gui.Interactable = block.Interactable
		end
	end
	local function hide(block)
		cancelTweens(block)
		block.Hidden = true
		block.Gui.Interactable = false
		for object, values in block.Saved do
			for prop in values do
				object[prop] = 1
			end
		end
	end
	local function restoreBlocks()
		local list = blocks
		blocks = {}
		for _, block in list do
			unfade(block)
		end
	end
	local function save(object, saved)
		local values = {}
		for class, props in FADED do
			if object:IsA(class) then
				for _, prop in props do
					values[prop] = object[prop]
				end
			end
		end
		if next(values) then
			saved[object] = values
		end
	end
	local function collect()
		local w = target.AbsoluteSize.X
		if w <= 0 then
			return
		end
		local centre = target.AbsolutePosition.X + w / 2
		local function walk(parent, depth)
			for _, gui in parent:GetChildren() do
				if gui == root or not gui:IsA("GuiObject") or not gui.Visible then
					continue
				end
				local inner = false
				for _, c in gui:GetChildren() do
					if c:IsA("GuiObject") then
						inner = true
						break
					end
				end
				if inner and depth < DEPTH and gui.AbsoluteSize.X >= CONTAINER * w then
					walk(gui, depth + 1)
					continue
				end
				local at = math.abs(gui.AbsolutePosition.X + gui.AbsoluteSize.X / 2 - centre) / (w / 2)
				local block =
					{ Gui = gui, At = at, Hidden = false, Interactable = gui.Interactable, Saved = {}, Tweens = {} }
				save(gui, block.Saved)
				for _, d in gui:GetDescendants() do
					save(d, block.Saved)
				end
				table.insert(blocks, block)
			end
		end
		walk(target, 1)
	end
	-- Follows the paper (p = its width as a share of the target's).
	local function inkBlocks(p, opening)
		for _, block in blocks do
			local reached = p >= block.At
			if opening and block.Hidden and reached then
				block.Hidden = false
				block.Gui.Interactable = block.Interactable
				for object, values in block.Saved do
					local goal = {}
					for prop, value in values do
						if value < 1 then
							goal[prop] = value
						end
					end
					if next(goal) then
						local tween = TweenService:Create(object, TweenInfo.new(INK, Enum.EasingStyle.Quad), goal)
						table.insert(block.Tweens, tween)
						tween:Play()
					end
				end
			elseif not opening and not block.Hidden and not reached then
				unfade(block)
				hide(block)
			end
		end
	end
	local opening = true

	-- Cancels the running motion where it is (every block shows again, at its own transparencies); its onDone never
	-- fires.
	function handle.Stop()
		restoreBlocks()
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
			opening = shown
			-- Deferred (before the frame draws): owner code that shows the panel and then its own parts in the same
			-- frame has done so when the blocks are read.
			task.defer(function()
				if running == motion then
					collect()
					if shown then
						for _, block in blocks do
							if block.At > handle.Progress then
								hide(block)
							end
						end
					end
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
			restoreBlocks()
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
			inkBlocks(handle.Progress, opening)
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
