--!nonstrict
-- The game-wide anime look (design doc 4.42): Client/IndexAnimeStyle's art and text treatment as parts any panel,
-- popup, tab or button can wear. Display only: each screen keeps its own layout, names and remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IndexStyle = require(script.Parent:WaitForChild("IndexAnimeStyle"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local ART, INK, image, text = IndexStyle.Art, IndexStyle.Ink, IndexStyle.Image, IndexStyle.Text
local Skin = { Art = ART, Ink = INK, Text = text }
Skin.Font = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
-- Card and plate tints (placeholders); Default is the Index's card blue.
Skin.Tint = {
	Default = Color3.fromRGB(70, 205, 255),
	Ready = Color3.fromRGB(60, 230, 120),
	Muted = Color3.fromRGB(120, 125, 140),
	Gold = Color3.fromRGB(255, 205, 60),
	Danger = Color3.fromRGB(255, 80, 90),
}
-- Action button fills: Go is the Index's EQUIP green.
local FILL = {
	Go = UiTheme.Palette.MoneyDeep,
	Idle = Color3.fromRGB(34, 40, 66),
	Danger = Color3.fromRGB(215, 50, 70),
	Gold = Color3.fromRGB(235, 160, 20),
}

local function child(parent, class, name)
	local found = parent:FindFirstChild(name)
	if not found then
		found = Instance.new(class)
		found.Name = name
		found.Parent = parent
	end
	return found
end

-- The object's own fill and edge give way to art. Fades tween BackgroundTransparency, so the fill hides through a
-- fully clear gradient instead, which no fade touches.
local function clear(gui)
	local gradient = gui:FindFirstChildOfClass("UIGradient") or child(gui, "UIGradient", "AnimeClear")
	gradient.Transparency = NumberSequence.new(1)
	for _, d in gui:GetChildren() do
		if d:IsA("UIStroke") and d.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			d.Enabled = false
		end
	end
end
Skin.Clear = clear

-- The plain framed body (magenta and cyan edges, cut corners) behind a panel or popup.
function Skin.Body(panel, inset)
	clear(panel)
	local pad = inset or 8
	local body = panel:FindFirstChild("AnimeBody") or image(panel, "AnimeBody", ART.Body, UDim2.new(), UDim2.new(), 0)
	body.Position, body.Size = UDim2.fromOffset(-pad, -pad), UDim2.new(1, 2 * pad, 1, 2 * pad)
	body.ZIndex = 0
	return body
end

-- The slanted cyan-to-violet strip under a header's title. `left` is where it starts (after the logo).
function Skin.Strip(header, left)
	clear(header)
	header.ClipsDescendants = false
	local strip = header:FindFirstChild("AnimeStrip")
		or image(header, "AnimeStrip", ART.Header, UDim2.new(), UDim2.new(), 0) -- under the header's own parts
	strip.Position, strip.Size = UDim2.new(0, left or 0, 0, 4), UDim2.new(1, -(left or 0), 1, -8)
	return strip
end

-- Heavy italic white with the dark outline, sized to fit (at most `max` px). Again next frame: UiTheme.Apply's
-- deferred DescendantAdded puts new text back on Fredoka.
local function title(label, max)
	text(label, max or 30)
	task.defer(function()
		if label.Parent then
			text(label, max or 30)
		end
	end)
end
Skin.Title = title

-- The art close: the button stays (and keeps its name and size) under the art.
function Skin.Close(button, label)
	clear(button)
	button.BackgroundTransparency = 1
	if button:IsA("TextButton") then
		button.TextTransparency = 1
	end
	if button:IsA("GuiButton") then
		button.AutoButtonColor = false
	end
	local caption = label or button:FindFirstChild("X")
	if caption then
		caption.Visible = false
	end
	local art = button:FindFirstChild("AnimeCloseArt")
		or image(
			button,
			"AnimeCloseArt",
			ART.Close,
			UDim2.fromScale(0.5, 0.5),
			UDim2.fromScale(1.3, 1.3),
			button.ZIndex + 1
		)
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.ScaleType = Enum.ScaleType.Fit
	return art
end

-- An art tab. `index` picks the Index's tab art (1 cyan, 2 gold, 3 and 4 violet). The button keeps its Text for
-- the UI tests; a caption on top shows it. Returns a function that marks the tab lit or not.
function Skin.Tab(button, index)
	clear(button)
	button.BackgroundTransparency = 1
	if not button:FindFirstChild("AnimeTabArt") then
		local art = image(
			button,
			"AnimeTabArt",
			ART.Tabs[((index or 1) - 1) % #ART.Tabs + 1],
			UDim2.new(0, -5, 0, -4),
			UDim2.new(1, 10, 1, 8),
			button.ZIndex + 1
		)
		art.ZIndex = 1
	end
	-- A tab whose words are a child label keeps it, raised over the art; a TextButton's own Text gets a caption.
	local caption = button:FindFirstChild("AnimeCaption")
	if not caption then
		for _, d in button:GetChildren() do
			if d:IsA("TextLabel") then
				caption = d
			end
		end
	end
	if not caption and button:IsA("TextButton") then
		caption = Instance.new("TextLabel")
		caption.Name = "AnimeCaption"
		caption.BackgroundTransparency = 1
		caption.Position, caption.Size = UDim2.fromOffset(6, 0), UDim2.new(1, -12, 1, 0)
		caption.Parent = button
		local function sync()
			caption.Text = button.Text
			button.TextTransparency = 1
		end
		sync()
		button:GetPropertyChangedSignal("Text"):Connect(sync)
	end
	if caption then
		caption.ZIndex = 3
		-- Narrow tabs (the Backpack's side rail) need smaller text than Issac's 10 px floor.
		local function fit()
			text(caption, 20)
			caption:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize = 6
		end
		fit()
		task.defer(function()
			if caption.Parent then
				fit()
			end
		end)
	end
	return function(lit)
		button.AnimeTabArt.ImageColor3 = lit and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 170)
	end
end

-- An Index-style action button: flat fill, small corners, heavy italic outlined text. tone: Go, Idle, Danger, Gold.
function Skin.Button(button, tone)
	for _, gradient in button:GetChildren() do
		if gradient:IsA("UIGradient") then
			gradient.Enabled = false
		end
	end
	button.BackgroundColor3 = FILL[tone or "Go"] or FILL.Go
	local corner = button:FindFirstChildOfClass("UICorner") or child(button, "UICorner", "Corner")
	local function style()
		corner.CornerRadius = UDim.new(0, 4) -- UiTheme.Apply snaps new corners to 8: set again after it
		if button:IsA("TextButton") then
			button.FontFace = Skin.Font
			button.TextColor3 = Color3.new(1, 1, 1)
		end
	end
	style()
	task.defer(style)
end

-- The angular card art behind a tile, tinted (rarity colour, state, or the Index's blue).
function Skin.Card(frame, tint)
	clear(frame)
	local card = frame:FindFirstChild("AnimeCard")
		or image(frame, "AnimeCard", ART.Card, UDim2.fromOffset(-3, -3), UDim2.new(1, 6, 1, 6), 0)
	card.ImageColor3 = tint or Skin.Tint.Default
	return card
end

-- Spacing standard (design doc 4.42, owner 2026-11-10): desktop px on a 4 px grid. Phones (viewport height <= 500)
-- take the same tokens through Skin.Px.
Skin.Space = {
	Inset = 16, -- left, right
	Gap = 12, -- header to toolbar, toolbar to content, between cards and rows
	Inner = 8, -- inside a card
	Pad = 12, -- card padding
	Header = 64,
	Toolbar = 40,
	Bottom = 16,
	BottomClear = 24, -- a control at the bottom-left keeps clear of the body art's stripes
	Close = 52,
	CloseGap = 6,
	Logo = 90,
	Button = 40,
	ButtonSmall = 32,
	Footer = 32,
	Scrollbar = 8,
}
Skin.Size = { Title = 38, Section = 26, Item = 20, Body = 16, Caption = 13 }
Skin.Color = {
	Section = Color3.fromRGB(255, 205, 60),
	White = Color3.new(1, 1, 1),
	Caption = Color3.fromRGB(200, 210, 230),
}
local PHONE_SCALE = 0.75 -- placeholder

local function compact()
	local camera = workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.Y <= 500
end
Skin.Compact = compact

-- A token in px for this screen.
function Skin.Px(value)
	return compact() and math.floor(value * PHONE_SCALE + 0.5) or value
end

local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local function applyRole(label, role)
	local size = Skin.Px(Skin.Size[role] or Skin.Size.Body)
	local heavy = role == "Title" or role == "Section" or role == "Item"
	label.FontFace = heavy and Skin.Font or BODY_FONT
	label.TextColor3 = role == "Section" and Skin.Color.Section
		or role == "Caption" and Skin.Color.Caption
		or Skin.Color.White
	label.TextStrokeTransparency = 1
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if heavy then
		stroke = stroke or child(label, "UIStroke", "AnimeOutline")
		stroke.Color, stroke.Thickness, stroke.Enabled = INK, role == "Title" and 2.5 or 2, true
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		label.TextScaled = true
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
			or child(label, "UITextSizeConstraint", "AnimeLimit")
		limit.MaxTextSize, limit.MinTextSize = size, math.min(size, Skin.Px(Skin.Size.Caption))
	else
		if stroke then
			stroke.Enabled = false -- no outline under 16 px: it blurs the letters
		end
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
		if limit then
			limit:Destroy()
		end
		label.TextScaled = false
		label.TextSize = size
	end
end

-- One of the five text roles: "Title", "Section", "Item", "Body", "Caption". Again next frame (UiTheme.Apply's deferred
-- handler resets fonts on new text).
function Skin.Label(label, role)
	applyRole(label, role)
	task.defer(function()
		if label.Parent then
			applyRole(label, role)
		end
	end)
	return label
end

-- The standard header on any panel or popup: strip, overhanging logo, ALL CAPS title, art close. parts: Header (Frame),
-- Title (TextLabel), Icon (ImageLabel, optional), Close (GuiButton, optional), TitleEnd (UDim, optional). Returns a
-- function that re-lays it out; it also follows the panel's size.
function Skin.Header(panel, parts)
	local header, titleLabel, icon, close = parts.Header, parts.Title, parts.Icon, parts.Close
	panel.ClipsDescendants = false
	header.AnchorPoint = Vector2.zero
	header.Position = UDim2.new()
	header.ZIndex = math.max(header.ZIndex, 2)
	local strip = Skin.Strip(header)
	if close then
		Skin.Close(close)
		close.AnchorPoint = Vector2.new(1, 0)
		close.ZIndex = header.ZIndex + 3
	end
	if icon then
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = header.ZIndex + 1
	end
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Rotation = 0
	titleLabel.ZIndex = header.ZIndex + 2
	local function upper()
		local wanted = string.upper(titleLabel.Text)
		if titleLabel.Text ~= wanted then
			titleLabel.Text = wanted
		end
	end
	upper()
	titleLabel:GetPropertyChangedSignal("Text"):Connect(upper)
	local function layout()
		local h = Skin.Px(Skin.Space.Header)
		header.Size = UDim2.new(1, 0, 0, h)
		local gap = Skin.Px(Skin.Space.CloseGap)
		local closeSize = h - 2 * gap
		if close then
			close.Position = UDim2.new(1, -gap, 0, gap)
			close.Size = UDim2.fromOffset(closeSize, closeSize)
		end
		local left = Skin.Px(Skin.Space.Inset)
		if icon then
			local logo = Skin.Px(Skin.Space.Logo)
			icon.Position = UDim2.fromOffset(-math.floor(h * 0.2), -math.floor(h * 0.45))
			icon.Size = UDim2.fromOffset(logo, logo)
			left = logo - math.floor(h * 0.15)
		end
		local stripLeft = icon and math.floor(h * 0.5) or 0
		strip.Position, strip.Size = UDim2.fromOffset(stripLeft, 4), UDim2.new(1, -stripLeft, 1, -8)
		titleLabel.Position = UDim2.fromOffset(left, 4)
		local stop = parts.TitleEnd or UDim.new(1, -(close and closeSize + 2 * gap or gap))
		titleLabel.Size = UDim2.new(stop.Scale, stop.Offset - left, 0, h - 8)
		applyRole(titleLabel, "Title")
	end
	layout()
	task.defer(layout)
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	return layout
end

-- Top of the area under the header, in px (toolbar: also under the toolbar row).
function Skin.Top(withToolbar)
	local top = Skin.Px(Skin.Space.Header) + Skin.Px(Skin.Space.Gap)
	if withToolbar then
		top += Skin.Px(Skin.Space.Toolbar) + Skin.Px(Skin.Space.Gap)
	end
	return top
end

-- The toolbar row under the header: a transparent Frame of the standard height and insets, laid out left to right.
-- Callers parent their tabs and controls to it (or place them on its rect: Skin.ToolbarRect).
function Skin.ToolbarRect()
	local inset = Skin.Px(Skin.Space.Inset)
	return UDim2.fromOffset(inset, Skin.Px(Skin.Space.Header) + Skin.Px(Skin.Space.Gap)),
		UDim2.new(1, -2 * inset, 0, Skin.Px(Skin.Space.Toolbar))
end

-- Places `gui` in the content area: insets 16, under the header (and toolbar), above the footer or bottom inset.
-- opts: Toolbar, Footer, BottomClear (bools). Follows phone / desktop switches.
function Skin.Content(gui, opts)
	opts = opts or {}
	local function place()
		local inset = Skin.Px(Skin.Space.Inset)
		local top = Skin.Top(opts.Toolbar)
		local bottom = Skin.Px(opts.BottomClear and Skin.Space.BottomClear or Skin.Space.Bottom)
		if opts.Footer then
			bottom += Skin.Px(Skin.Space.Footer) + Skin.Px(Skin.Space.Gap)
		end
		gui.AnchorPoint = Vector2.zero
		gui.Position = UDim2.fromOffset(inset, top)
		gui.Size = UDim2.new(1, -2 * inset, 1, -top - bottom)
		if gui:IsA("ScrollingFrame") then
			gui.ScrollBarThickness = 6
			gui.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar -- the bar sits inside the area, not on cards
		end
	end
	place()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	return place
end

-- Index's footer bar at the bottom of a list panel: a slanted plate with one centred caption line. Returns the label.
function Skin.Footer(panel, value)
	local bar = panel:FindFirstChild("AnimeFooter")
	if not bar then
		bar = Instance.new("Frame")
		bar.Name = "AnimeFooter"
		bar.BackgroundTransparency = 1
		bar.ZIndex = 3
		bar.Parent = panel
		local plate = image(bar, "Plate", ART.Plate, UDim2.new(), UDim2.fromScale(1, 1), 3)
		plate.ImageColor3 = Skin.Tint.Default
		local line = Instance.new("TextLabel")
		line.Name = "Line"
		line.BackgroundTransparency = 1
		line.Size = UDim2.fromScale(1, 1)
		line.ZIndex = 4
		line.Parent = bar
	end
	local function place()
		local inset = Skin.Px(Skin.Space.Inset)
		local h = Skin.Px(Skin.Space.Footer)
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, 0, 1, -Skin.Px(Skin.Space.Bottom))
		bar.Size = UDim2.new(1, -2 * inset - 2 * Skin.Px(Skin.Space.Logo), 0, h)
	end
	place()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	bar.Line.Text = value or ""
	bar.Line.TextXAlignment = Enum.TextXAlignment.Center
	Skin.Label(bar.Line, "Body")
	return bar.Line
end

-- The slanted name plate behind a wide row, tinted.
function Skin.Plate(frame, tint)
	clear(frame)
	local plate = frame:FindFirstChild("AnimePlate")
		or image(frame, "AnimePlate", ART.Plate, UDim2.new(), UDim2.fromScale(1, 1), 0)
	plate.ImageColor3 = tint or Skin.Tint.Default
	return plate
end

return Skin
