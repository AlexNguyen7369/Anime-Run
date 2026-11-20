--!nonstrict
-- The hanging-scroll kit of the Sakura Dojo pages (design doc 4.45 "Hanging-scroll look", owner 2026-11-19): a mounted
-- kakejiku built from native Frames, plus the hanko seal, paper slip, hanging tag, knot and link builders that Summon
-- (R3) and Team Setup (T2) share. Inside the scroll every size is Scale of its root, so the caller sizes one frame.
-- Colours and fonts come from UiTheme.Scroll. Sizes and timings are proposed. Reduced motion (UiMotion.Reduced): fades only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local K = UiTheme.Scroll
local DojoScroll = {}

-- Open: drop 0.22 s; unroll 0.5 s from 0.12 s; the paper's text inks in from 0.5 s; other controls rise from 0.48 s.
-- Close: rolls up in 0.3 s.
DojoScroll.DROP, DojoScroll.UNROLL_AT, DojoScroll.UNROLL = 0.22, 0.12, 0.5
DojoScroll.INK_AT, DojoScroll.INK, DojoScroll.RISE_AT, DojoScroll.CLOSE = 0.5, 0.28, 0.48, 0.3
local FADE = 0.18 -- reduced motion
local DROP_PX, RISE_PX = 40, 28

-- Design px of the scroll parts (R3 at 1920 wide); the root's own size sets the scale.
-- Room around the scroll inside its root (px): the rod ends and the roller caps reach past the paper's edge.
local MARGIN = Vector2.new(20, 6)
DojoScroll.MARGIN = MARGIN
local PARTS = { Cord = 30, Rod = 13, Ten = 50, Rule = 8, Chi = 50, Jiku = 21, Side = 15, Strip = 17, StripDrop = 30 }

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function gradient(parent, top, bottom, rotation)
	local g = parent:FindFirstChildOfClass("UIGradient") or make("UIGradient", "Gradient", parent)
	g.Color = ColorSequence.new(top, bottom)
	g.Transparency = NumberSequence.new(0)
	g.Offset = Vector2.zero
	g.Rotation = rotation or 90
	return g
end

local function corner(parent, radius)
	local c = parent:FindFirstChildOfClass("UICorner") or make("UICorner", "Corner", parent)
	c.CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius)
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = parent:FindFirstChildOfClass("UIStroke") or make("UIStroke", "Edge", parent)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color, s.Thickness, s.Transparency = color, thickness, transparency or 0
	return s
end

local function fill(name, parent, color, props)
	local frame = make("Frame", name, parent, { BackgroundColor3 = color, BorderSizePixel = 0 })
	for key, value in props do
		frame[key] = value
	end
	return frame
end

local function text(name, parent, props)
	local label = make("TextLabel", name, parent, {
		BackgroundTransparency = 1,
		TextColor3 = K.Ink,
		FontFace = K.Body,
		TextScaled = true,
		Active = false,
	})
	for key, value in props do
		label[key] = value
	end
	return label
end
DojoScroll.Text = text

local function tween(object, seconds, goal, style, direction)
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- A vertical hanging scroll. opts: Name, Parent, Position (UDim2), AnchorPoint, Px (Vector2, the scroll's design size;
-- the root is Px plus MARGIN on every side and gets Size = fromOffset of that unless opts.Size), ZIndex, Chi (the bottom
-- mount's height in design px, for buttons on it; default PARTS.Chi). Returns { Root, Paper (the content frame, a CanvasGroup that
-- inks in), Open(), Close(), Destroy(), Opened() }.
function DojoScroll.new(parent, opts)
	opts = opts or {}
	-- Skin: a named colour set from UiTheme.Scroll.Skins over the default Sumi ink (Summon uses "Parchment").
	local C = setmetatable(table.clone(opts.Skin and K.Skins[opts.Skin] or {}), { __index = K })
	local W, H = opts.Px.X, opts.Px.Y
	local P = PARTS
	local z = opts.ZIndex or 2
	local bodyTop = P.Cord + P.Rod
	local bodyH = H - bodyTop - P.Jiku
	local home = opts.Position or UDim2.new()

	-- One CanvasGroup, so the whole scroll fades as one (the drop and reduced motion).
	-- A CanvasGroup clips to its bounds: the root is the scroll plus MARGIN on each side, for the rod ends and roller caps.
	local TW, TH = W + 2 * MARGIN.X, H + 2 * MARGIN.Y
	local root = make("CanvasGroup", opts.Name or "DojoScroll", nil, {
		Size = opts.Size or UDim2.fromOffset(TW, TH),
		Position = home,
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		ZIndex = z,
		Active = false,
	})
	make("UIAspectRatioConstraint", "Aspect", root, { AspectRatio = TW / TH })
	local frame = make("Frame", "Scroll", root, {
		Position = UDim2.fromScale(MARGIN.X / TW, MARGIN.Y / TH),
		Size = UDim2.fromScale(W / TW, H / TH),
		BackgroundTransparency = 1,
		ZIndex = z,
	})
	local function sx(px)
		return px / W
	end
	local function sy(px)
		return px / H
	end

	-- Cord and hook: two lines from the rod ends to a cap at the top centre (R3 path M6 10 L50 0 L94 10).
	local dx, dy = 0.44 * W, P.Cord
	local length = math.sqrt(dx * dx + dy * dy)
	local angle = math.deg(math.atan2(dy, dx))
	for i, side in { -1, 1 } do
		fill("Cord" .. i, frame, C.Cord, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + side * 0.22, sy(P.Cord / 2 + 1)),
			Size = UDim2.new(sx(length), 0, 0, 2),
			Rotation = side * angle,
			ZIndex = z,
		})
	end
	local hook = fill("Hook", frame, Color3.new(1, 1, 1), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, sy(2)),
		Size = UDim2.fromScale(sx(13), sy(13)),
		ZIndex = z + 1,
	})
	corner(hook, UDim.new(0.5, 0))
	gradient(hook, C.CapLight, C.CapDark, 45)

	-- Drop shadow under the body; follows the unroll.
	local shadow = fill("Shadow", frame, Color3.new(0, 0, 0), {
		Position = UDim2.fromScale(sx(6), sy(bodyTop + 10)),
		Size = UDim2.fromScale(1 - sx(6), sy(bodyH)),
		BackgroundTransparency = 0.72,
		ZIndex = z,
	})
	corner(shadow, 6)

	-- Body: grows from the rod down (the clip), the sheet inside keeps its full height.
	local body = make("Frame", "Body", frame, {
		Position = UDim2.fromScale(0, sy(bodyTop)),
		Size = UDim2.fromScale(1, sy(bodyH)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = z + 1,
	})
	local sheet = fill("Sheet", body, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
	gradient(sheet, C.Mount, C.MountDark, 0)
	local function by(px)
		return px / bodyH
	end
	-- Top mount (ten) with its two hanging strips (futai); the rules (ichimonji); the bottom mount (chi).
	for i, x in { 0.27, 1 - 0.27 - sx(P.Strip) } do
		local strip = fill("Strip" .. i, sheet, Color3.new(1, 1, 1), {
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromScale(sx(P.Strip), by(P.Ten + P.StripDrop)),
			ZIndex = z + 4,
		})
		gradient(strip, C.RuleTop, C.RuleBottom, 0)
		fill("End", strip, C.RuleBottom, {
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 3),
			ZIndex = z + 4,
		})
	end
	local paperTop = P.Ten + P.Rule
	local paperH = bodyH - P.Ten - (opts.Chi or P.Chi) - 2 * P.Rule
	for i, y in { P.Ten, P.Ten + P.Rule + paperH } do
		local rule = fill("Rule" .. i, sheet, Color3.new(1, 1, 1), {
			Position = UDim2.fromScale(sx(P.Side), by(y)),
			Size = UDim2.fromScale(1 - 2 * sx(P.Side), by(P.Rule)),
			ZIndex = z + 2,
		})
		gradient(rule, C.RuleTop, C.RuleBottom)
	end
	local paper = fill("Paper", sheet, Color3.new(1, 1, 1), {
		Position = UDim2.fromScale(sx(P.Side), by(paperTop)),
		Size = UDim2.fromScale(1 - 2 * sx(P.Side), by(paperH)),
		ClipsDescendants = true,
		ZIndex = z + 2,
	})
	gradient(paper, C.Paper, C.PaperShade)
	local content = make("CanvasGroup", "Content", paper, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z + 3,
	})
	make("UIPadding", "Pad", content, {
		PaddingLeft = UDim.new(0.05, 0),
		PaddingRight = UDim.new(0.05, 0),
		PaddingTop = UDim.new(0.025, 0),
		PaddingBottom = UDim.new(0.025, 0),
	})

	-- Rod (top) and roller (jiku) with its end caps.
	local rod = fill("Rod", frame, Color3.new(1, 1, 1), {
		Position = UDim2.fromScale(-sx(7), sy(P.Cord)),
		Size = UDim2.fromScale(1 + sx(14), sy(P.Rod)),
		ZIndex = z + 5,
	})
	gradient(rod, C.RodTop, C.RodBottom)
	corner(rod, 4)
	local jW = W + 8
	local roller = fill("Roller", frame, Color3.new(1, 1, 1), {
		Position = UDim2.fromScale(-sx(4), sy(bodyTop + bodyH)),
		Size = UDim2.fromScale(1 + sx(8), sy(P.Jiku)),
		ZIndex = z + 5,
	})
	gradient(roller, C.RodTop, C.RodBottom)
	corner(roller, UDim.new(0.5, 0))
	for i, x in { -17 / jW, 1 - 4 / jW } do
		local cap = fill("Cap" .. i, roller, Color3.new(1, 1, 1), {
			Position = UDim2.fromScale(x, -4 / P.Jiku),
			Size = UDim2.fromScale(21 / jW, 28 / P.Jiku),
			ZIndex = z + 6,
		})
		gradient(cap, C.CapLight, C.CapDark, 45)
		corner(cap, 6)
	end
	root.Parent = parent

	-- p: 0 rolled up, 1 open.
	local unroll = make("NumberValue", "Unroll", root, { Value = 1 })
	local function set(p)
		local q = math.max(p, 0.001)
		body.Size = UDim2.fromScale(1, sy(bodyH) * q)
		sheet.Size = UDim2.fromScale(1, 1 / q)
		shadow.Size = UDim2.fromScale(1 - sx(6), sy(bodyH) * q)
		roller.Position = UDim2.fromScale(-sx(4), sy(bodyTop + bodyH * p))
	end
	unroll.Changed:Connect(set)

	local self = { Root = root, Paper = content, Body = body }
	local version, opened, tweens = 0, false, {}
	local function stop()
		version += 1
		for _, t in tweens do
			t:Cancel()
		end
		table.clear(tweens)
		return version
	end
	local function later(seconds, mine, fn)
		task.delay(seconds, function()
			if version == mine then
				fn()
			end
		end)
	end

	function self.Opened()
		return opened
	end

	function self.Open()
		local mine = stop()
		opened = true
		if UiMotion.Reduced() then
			root.Position, unroll.Value, content.GroupTransparency = home, 1, 0
			root.GroupTransparency = 1
			table.insert(tweens, tween(root, FADE, { GroupTransparency = 0 }, Enum.EasingStyle.Quad))
			return
		end
		root.Position = home - UDim2.fromOffset(0, DROP_PX)
		root.GroupTransparency, unroll.Value, content.GroupTransparency = 1, 0, 1
		table.insert(
			tweens,
			tween(root, DojoScroll.DROP, { Position = home, GroupTransparency = 0 }, Enum.EasingStyle.Quint)
		)
		later(DojoScroll.UNROLL_AT, mine, function()
			table.insert(tweens, tween(unroll, DojoScroll.UNROLL, { Value = 1 }))
		end)
		later(DojoScroll.INK_AT, mine, function()
			table.insert(tweens, tween(content, DojoScroll.INK, { GroupTransparency = 0 }, Enum.EasingStyle.Quad))
		end)
	end

	-- Rolls up (reduced: fades out). `done` runs at the end unless Open runs first.
	function self.Close(done)
		local mine = stop()
		opened = false
		local seconds = UiMotion.Reduced() and FADE or DojoScroll.CLOSE
		if UiMotion.Reduced() then
			table.insert(tweens, tween(root, FADE, { GroupTransparency = 1 }, Enum.EasingStyle.Quad))
		else
			table.insert(tweens, tween(content, 0.12, { GroupTransparency = 1 }, Enum.EasingStyle.Quad))
			table.insert(tweens, tween(unroll, seconds, { Value = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
			later(seconds * 0.6, mine, function()
				table.insert(tweens, tween(root, seconds * 0.4, { GroupTransparency = 1 }, Enum.EasingStyle.Quad))
			end)
		end
		later(seconds, mine, function()
			if done then
				done()
			end
		end)
	end

	-- Moves the scroll's resting place (a responsive re-fit); a running drop lands there.
	function self.SetHome(position)
		home = position
		if version == 0 or opened then
			root.Position = position
		end
	end

	function self.Destroy()
		stop()
		root:Destroy()
	end

	return self
end

-- Ink fade for page controls that live outside the scroll's paper (they keep their own parents). The first call records
-- each object's resting transparencies; later calls fade between those and fully clear. `rise` (px) slides each top-level
-- object up into place as it shows. Returns nothing; a newer call on the same object cancels the older one.
-- Strong tables: a weak key drops an Instance whose Lua handle was collected, losing its resting values.
-- shortcut: entries live as long as the page; add a release call if pages ever get destroyed and rebuilt.
local resting, running = {}, {}
local PROPS = {
	{ "GuiObject", "BackgroundTransparency" },
	{ "TextLabel", "TextTransparency" },
	{ "TextLabel", "TextStrokeTransparency" },
	{ "TextButton", "TextTransparency" },
	{ "TextButton", "TextStrokeTransparency" },
	{ "ImageLabel", "ImageTransparency" },
	{ "ImageButton", "ImageTransparency" },
	{ "UIStroke", "Transparency" },
}
local function record(object)
	if resting[object] then
		return resting[object]
	end
	local values = {}
	for _, pair in PROPS do
		if object:IsA(pair[1]) and object[pair[2]] < 1 then
			values[pair[2]] = object[pair[2]]
		end
	end
	resting[object] = values
	return values
end

function DojoScroll.Ink(objects, show, delay, seconds, rise)
	local reduced = UiMotion.Reduced()
	seconds = reduced and FADE or seconds or DojoScroll.INK
	delay = reduced and 0 or delay or 0
	for _, top in objects do
		local list = top:GetDescendants()
		table.insert(list, top)
		for _, object in list do
			local values = record(object)
			for _, t in running[object] or {} do
				t:Cancel()
			end
			running[object] = {}
			if show then
				for prop in values do
					object[prop] = 1
				end
			end
		end
		local home = top:IsA("GuiObject") and top:GetAttribute("DojoHome")
		if show and rise and not reduced and home then
			top.Position = home + UDim2.fromOffset(0, rise)
		end
		local function go()
			for _, object in list do
				local goal = {}
				for prop, value in resting[object] do
					goal[prop] = show and value or 1
				end
				if next(goal) then
					table.insert(running[object], tween(object, seconds, goal, Enum.EasingStyle.Quad))
				end
			end
			if show and rise and not reduced and home then
				table.insert(running[top], tween(top, 0.32, { Position = home }, Enum.EasingStyle.Back))
			end
		end
		if delay > 0 then
			local mine = running[top]
			task.delay(delay, function()
				if running[top] == mine then
					go()
				end
			end)
		else
			go()
		end
	end
end
DojoScroll.RISE = RISE_PX

-- Press and hover motion shared by the builders: hover tilts and grows a little, a press scales to 0.94 in 0.12 s.
local function motion(button, tilt, grow)
	local scale = button:FindFirstChild("DojoScale") or make("UIScale", "DojoScale", button)
	local base = button.Rotation
	local hovering, pressed = false, false
	local current = {}
	local function update()
		for _, t in current do
			t:Cancel()
		end
		local s = pressed and 0.94 or hovering and grow or 1
		local info = pressed and 0.12 or 0.16
		current = {
			UiMotion.Create(
				scale,
				TweenInfo.new(info, pressed and Enum.EasingStyle.Quad or Enum.EasingStyle.Back),
				{ Scale = s }
			),
			UiMotion.Create(
				button,
				TweenInfo.new(0.2, Enum.EasingStyle.Back),
				{ Rotation = base + (hovering and not pressed and tilt or 0) }
			),
		}
		for _, t in current do
			t:Play()
		end
	end
	button.MouseEnter:Connect(function()
		hovering = true
		update()
	end)
	button.MouseLeave:Connect(function()
		hovering, pressed = false, false
		update()
	end)
	button.SelectionGained:Connect(function()
		hovering = true
		update()
	end)
	button.SelectionLost:Connect(function()
		hovering, pressed = false, false
		update()
	end)
	button.MouseButton1Down:Connect(function()
		pressed = true
		update()
	end)
	button.MouseButton1Up:Connect(function()
		pressed = false
		update()
	end)
	return scale
end

-- Hanko seal: a red square with an inset cream double rule, a kanji, a label and a cost line. Dresses `button` (its
-- own Text stays as is, hidden). opts: Kanji, Label, Cost, Rotation. Returns { Kanji, Label, Cost, SetLocked(bool) }.
function DojoScroll.Seal(button, opts)
	button.AutoButtonColor = false
	button.BackgroundColor3 = K.Accent
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.TextTransparency = 1
	button.TextStrokeTransparency = 1
	button.Rotation = opts.Rotation or 0
	button.ClipsDescendants = false
	local z = button.ZIndex
	local grad = gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(222, 210, 206), 90)
	corner(button, UDim.new(0.07, 0))
	stroke(button, Color3.fromRGB(110, 20, 18), 1, 0.4)
	for i, inset in { 0.045, 0.085 } do
		local rule = make("Frame", "SealRule" .. i, button, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1 - 2 * inset, 1 - 2 * inset),
			BackgroundTransparency = 1,
			ZIndex = z + 1,
			Active = false,
		})
		corner(rule, UDim.new(0.05, 0))
		stroke(rule, K.SealText, i == 1 and 2.5 or 1, i == 1 and 0.12 or 0.35)
	end
	local kanji = text("Kanji", button, {
		Position = UDim2.fromScale(0.1, 0.12),
		Size = UDim2.fromScale(0.8, 0.4),
		Text = opts.Kanji or "",
		TextColor3 = K.SealText,
		Font = Enum.Font.GothamBold, -- CJK through Roblox's font fallback; decoration only
		ZIndex = z + 2,
	})
	local label = text("Label", button, {
		Position = UDim2.fromScale(0.1, 0.53),
		Size = UDim2.fromScale(0.8, 0.17),
		Text = opts.Label or "",
		TextColor3 = K.SealText,
		FontFace = K.Heading,
		ZIndex = z + 2,
	})
	local cost = text("Cost", button, {
		Position = UDim2.fromScale(0.1, 0.72),
		Size = UDim2.fromScale(0.8, 0.13),
		Text = opts.Cost or "",
		TextColor3 = K.SealText,
		FontFace = K.BodyBold,
		ZIndex = z + 2,
	})
	motion(button, -2, 1.03)
	local seal = { Kanji = kanji, Label = label, Cost = cost }
	function seal.SetLocked(locked)
		button.BackgroundColor3 = locked and Color3.fromRGB(142, 128, 124) or K.Accent
		grad.Enabled = not locked
	end
	return seal
end

-- Paper tile (Summon 1:1 reference, 4.45): a cream wood tile with a brown rim, a slight bevel and no tilt; a dark ink
-- glyph, a brush label and a cost line. Dresses `button` (its own Text stays, hidden). opts: Glyph, Label, Cost.
-- Returns { Glyph, Label, Cost, SetLocked(bool) }.
function DojoScroll.Tile(button, opts)
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.TextTransparency = 1
	button.TextStrokeTransparency = 1
	button.Rotation = 0
	button.ClipsDescendants = false
	local z = button.ZIndex
	local grad = gradient(button, K.TileTop, K.TileBottom, 90)
	grad.Enabled = true
	corner(button, 8)
	stroke(button, K.TileRim, 4, 0).Enabled = true
	-- A darker outer edge round the rim.
	local edge = button:FindFirstChild("TileEdge")
		or make("Frame", "TileEdge", button, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 8, 1, 8),
			BackgroundTransparency = 1,
			ZIndex = z,
			Active = false,
		})
	corner(edge, 11)
	stroke(edge, K.TileEdge, 1.5, 0)
	-- Wood planks: two faint horizontal seams across the face, between the glyph, the label and the cost.
	for i, y in { 0.465, 0.71 } do
		fill("PlankSeam" .. i, button, K.TileRim, {
			Position = UDim2.new(0, 5, y, 0),
			Size = UDim2.new(1, -10, 0, 1),
			BackgroundTransparency = 0.72,
			ZIndex = z + 1,
			Active = false,
		})
	end
	-- Bevel: a light inner edge and a darker lower lip.
	local bevel = make("Frame", "TileBevel", button, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Active = false,
	})
	corner(bevel, 6)
	stroke(bevel, Color3.fromRGB(255, 251, 238), 1.5, 0.2)
	fill("TileLip", button, K.TileRim, {
		Position = UDim2.new(0, 6, 1, -8),
		Size = UDim2.new(1, -12, 0, 3),
		BackgroundTransparency = 0.65,
		ZIndex = z + 1,
		Active = false,
	})
	local glyph = text("Glyph", button, {
		Position = UDim2.fromScale(0.1, 0.03),
		Size = UDim2.fromScale(0.8, 0.43),
		Text = opts.Glyph or "",
		TextColor3 = K.TileInk,
		Font = Enum.Font.GothamBlack, -- heavy ink; CJK through Roblox's font fallback; decoration only
		ZIndex = z + 2,
	})
	local label = text("Label", button, {
		Position = UDim2.fromScale(0.06, 0.475),
		Size = UDim2.fromScale(0.88, 0.23),
		Text = opts.Label or "",
		TextColor3 = K.TileInk,
		FontFace = K.Heading,
		ZIndex = z + 2,
	})
	local cost = text("Cost", button, {
		Position = UDim2.fromScale(0.08, 0.725),
		Size = UDim2.fromScale(0.84, 0.17),
		Text = opts.Cost or "",
		TextColor3 = K.TileInk,
		FontFace = K.BodyBold,
		ZIndex = z + 2,
	})
	motion(button, 0, 1.03)
	local tile = { Glyph = glyph, Label = label, Cost = cost }
	function tile.SetLocked(locked)
		grad.Color = locked and ColorSequence.new(Color3.fromRGB(196, 190, 182), Color3.fromRGB(160, 154, 146))
			or ColorSequence.new(K.TileTop, K.TileBottom)
		for _, t in { glyph, label, cost } do
			t.TextColor3 = locked and K.Muted or K.TileInk
		end
	end
	return tile
end

-- Paper button (Summon 1:1 reference, 4.45): paper with an ink brush-line rim and its label in a script face. opts: Rim
-- (colour, default PaperRim), Fill (default Slip), Font (default Heading), Seal (a small red seal with this kanji over the
-- top-right corner). Shows `label` in a child PaperLabel (the button's own Text stays, hidden).
function DojoScroll.PaperButton(button, label, opts)
	opts = opts or {}
	button.AutoButtonColor = false
	button.BackgroundColor3 = opts.Fill or K.Slip
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.TextTransparency = 1
	button.TextStrokeTransparency = 1
	button.ClipsDescendants = false
	for _, d in button:GetChildren() do
		if d:IsA("UIGradient") then
			d.Enabled = false
		end
	end
	corner(button, 6)
	stroke(button, opts.Rim or K.PaperRim, 3, 0).Enabled = true
	local z = button.ZIndex
	local shown = button:FindFirstChild("PaperLabel")
		or text("PaperLabel", button, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.66),
			FontFace = opts.Font or K.Heading,
			TextColor3 = K.TileInk,
			ZIndex = z + 1,
		})
	shown.Text = label
	if opts.Seal and not button:FindFirstChild("Seal") then
		local seal = fill("Seal", button, K.Accent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 1),
			Size = UDim2.fromOffset(26, 26),
			Rotation = 6,
			ZIndex = z + 2,
			Active = false,
		})
		corner(seal, 3)
		text("Kanji", seal, {
			Position = UDim2.fromScale(0.1, 0.1),
			Size = UDim2.fromScale(0.8, 0.8),
			Text = opts.Seal,
			TextColor3 = K.SealText,
			Font = Enum.Font.GothamBold, -- CJK through Roblox's font fallback; decoration only
			ZIndex = z + 3,
		})
	end
	motion(button, 0, 1.04)
	return shown
end

-- Pill: a rounded label with its own fill (the cream Buy and arrow pills, the featured rate's red brush pill).
function DojoScroll.Pill(name, parent, color, props)
	local pill = text(name, parent, { BackgroundColor3 = color, BackgroundTransparency = 0, BorderSizePixel = 0 })
	for key, value in props or {} do
		pill[key] = value
	end
	corner(pill, UDim.new(0.5, 0))
	make("UIPadding", "Pad", pill, {
		PaddingTop = UDim.new(0.16, 0),
		PaddingBottom = UDim.new(0.16, 0),
		PaddingLeft = UDim.new(0.1, 0),
		PaddingRight = UDim.new(0.1, 0),
	})
	return pill
end

-- Paper slip: a cream card with a faint ink edge.
function DojoScroll.Slip(frame)
	frame.BackgroundColor3 = K.Slip
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	corner(frame, 5)
	stroke(frame, K.Ink, 1, 0.8)
	return frame
end

-- Hanging tag: burgundy lacquer with a pink rim on a cord. `cordPx` is the cord length above the tag.
function DojoScroll.Tag(frame, cordPx)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = false
	gradient(frame, K.TagTop, K.TagBottom)
	corner(frame, 6)
	stroke(frame, K.TagRim, 1.5, 0)
	local cord = frame:FindFirstChild("TagCord")
		or make("Frame", "TagCord", frame, { BorderSizePixel = 0, Active = false })
	cord.AnchorPoint = Vector2.new(0.5, 1)
	cord.Position = UDim2.fromScale(0.5, 0)
	cord.Size = UDim2.fromOffset(2, cordPx or 22)
	cord.BackgroundColor3 = K.TagCord
	cord.ZIndex = frame.ZIndex
	local knot = cord:FindFirstChild("Knot")
		or make("Frame", "Knot", cord, { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Active = false })
	knot.Position = UDim2.fromScale(0.5, 0)
	knot.Size = UDim2.fromOffset(8, 8) -- a red bead
	knot.BackgroundColor3 = K.TagCord
	knot.ZIndex = frame.ZIndex
	corner(knot, UDim.new(0.5, 0))
	return frame
end

-- Knot close button: a round lacquer button with a vermilion edge and a cream cross.
function DojoScroll.Knot(button)
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Text = ""
	gradient(button, K.Lacquer, K.LacquerDark)
	corner(button, UDim.new(0.5, 0))
	stroke(button, K.Accent, 2.5, 0)
	local glyph = button:FindFirstChild("Glyph")
		or text("Glyph", button, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromScale(0.66, 0.66),
			Text = utf8.char(0x00D7),
			TextColor3 = K.SealText,
			FontFace = K.BodyBold,
			ZIndex = button.ZIndex + 1,
		})
	motion(button, 0, 1.08)
	return glyph
end

-- Link: bold ink text with a vermilion underline that follows the text width. Shows `label` in a child Label (the
-- button's own Text stays, hidden).
function DojoScroll.Link(button, label)
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.TextTransparency = 1
	button.TextStrokeTransparency = 1
	local shown = button:FindFirstChild("LinkLabel")
		or text("LinkLabel", button, {
			Size = UDim2.fromScale(1, 0.8),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = K.BodyBold,
			ZIndex = button.ZIndex + 1,
		})
	shown.Text = label
	local line = button:FindFirstChild("Underline")
		or make("Frame", "Underline", button, {
			BackgroundColor3 = K.Accent,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.86),
			ZIndex = button.ZIndex + 1,
			Active = false,
		})
	local function fit()
		line.Size = UDim2.new(shown.TextBounds.X / math.max(shown.AbsoluteSize.X, 1), 0, 0, 2)
	end
	shown:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	fit()
	motion(button, 0, 1.04)
	return shown
end

-- A thin brushed ink line across `parent` (fading at both ends).
function DojoScroll.Brush(name, parent, props)
	local line = fill(name, parent, K.Ink, props)
	local g = make("UIGradient", "Fade", line)
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.15, 0.45),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	corner(line, UDim.new(0.5, 0))
	return line
end

-- The baked brush wordmark ("Summon" or "Team"), tinted ink.
function DojoScroll.Wordmark(name, parent, which, props)
	local rect = K.WordmarkRects[which]
	local image = make("ImageLabel", name, parent, {
		BackgroundTransparency = 1,
		Image = K.Wordmarks,
		ImageRectOffset = Vector2.new(rect[1], rect[2]),
		ImageRectSize = Vector2.new(rect[3], rect[4]),
		ImageColor3 = K.Ink,
		ScaleType = Enum.ScaleType.Fit,
		Active = false,
	})
	for key, value in props or {} do
		image[key] = value
	end
	return image
end

return DojoScroll
