--!nonstrict
-- The game-wide Scroll Dojo look (design doc 4.46, docs/UI_SCROLL_SPEC.md Kit; replaced the 4.42 anime art): the
-- handscroll, brush wordmark title with its kanji, seal close, paper tabs, wood tiles and paper buttons, paper cards and
-- slips as parts any panel, popup, tab or button can wear (Client/IndexAnimeStyle.Dojo). Display only: each screen keeps
-- its own layout, names and remotes. The Upgrades tree keeps the 4.42 art (owner 2026-11-20): an object under the
-- RacerUpgrades gui still gets the old Card, Title, Text and Close.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IndexStyle = require(script.Parent:WaitForChild("IndexAnimeStyle"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local ART, INK, image, text = IndexStyle.Art, IndexStyle.Ink, IndexStyle.Image, IndexStyle.Text
local Dojo = IndexStyle.Dojo
local C, F = Dojo.Colors, Dojo.Fonts
local Skin = { Art = ART, Ink = INK, Chrome = IndexStyle.Chrome, Dojo = Dojo }
Skin.Font = F.Button -- Kalam Bold (4.46 replaced the GothamSSm heavy italic)
local LEGACY_TINT = Color3.fromRGB(70, 205, 255) -- the Upgrades detail card's blue
-- Card strip and slip bar tints on paper (placeholders).
Skin.Tint = {
	Default = C.Rim,
	Ready = UiTheme.Dojo.Ready,
	Muted = C.Muted,
	Gold = Color3.fromRGB(240, 160, 32), -- #F0A020
	Danger = C.Verm,
}
-- Action buttons (kit.css): Go the vermilion tile (Claim, Sell), Gold the cream wood tile, Idle the outlined paper
-- button, Danger the paper button with a vermilion rim. { top, bottom, rim, rim px, text }.
local TONE = {
	Go = { C.GoTop, C.GoBottom, C.GoRim, 2, C.Cream },
	Gold = { C.TileTop, C.TileBottom, C.Rim, 3, C.Ink },
	Idle = { C.Field, C.Field, C.Ink, 2, C.Ink },
	Danger = { C.Field, C.Field, C.Verm, 2, C.Verm },
}

-- The Upgrades tree (design doc 4.46 scope: not redesigned) keeps the 4.42 art.
local function legacy(gui)
	return gui:FindFirstAncestor("RacerUpgrades") ~= nil
end

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

-- A panel's or popup's own fill and edge give way (design doc 4.46: the handscroll or the slip is the body; the 4.42
-- framed body art is retired, an old one hides).
function Skin.Body(panel)
	clear(panel)
	local old = panel:FindFirstChild("AnimeBody")
	if old then
		old.Visible = false
	end
end

-- A header's own fill gives way (the 4.42 slanted strip is retired, an old one hides).
function Skin.Strip(header)
	clear(header)
	header.ClipsDescendants = false
	local old = header:FindFirstChild("AnimeStrip")
	if old then
		old.Visible = false
	end
end

-- Text sized to fit (at most `max` px): ink on paper, the brush face from 40 px up, else the button face (the
-- Upgrades tree: heavy italic white with the dark outline). Again next frame: UiTheme.Apply's deferred DescendantAdded
-- puts new text back on Fredoka.
local function paperText(label, max)
	if legacy(label) then
		text(label, max)
		return
	end
	Dojo.Text(label, (max or 0) >= 40 and "Title" or "Item")
	if max then
		label.TextScaled = true
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
			or child(label, "UITextSizeConstraint", "AnimeLimit")
		limit.MinTextSize = math.min(10, max)
		limit.MaxTextSize = max
	end
end
Skin.Text = paperText

local function title(label, max)
	paperText(label, max or 30)
	task.defer(function()
		if label.Parent then
			paperText(label, max or 30)
		end
	end)
end
Skin.Title = title

-- The close: a vermilion seal with a cream X (Client/IndexAnimeStyle.Dojo.Seal); the button keeps its name and size.
-- Returns the X label. The Upgrades tree keeps the 4.42 art close.
function Skin.Close(button, label)
	if not legacy(button) then
		return Dojo.Seal(button, label or button:FindFirstChild("X"))
	end
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

-- A paper tab; lit, a red brush pill with cream text (Client/IndexAnimeStyle.Dojo.Tab). `index` is unused (it picked
-- the retired 4.42 tab art). The button keeps its Text for the UI tests; a caption on top shows it. Returns a function
-- that marks the tab lit or not.
function Skin.Tab(button, _index)
	clear(button)
	button.BackgroundTransparency = 1
	local oldArt = button:FindFirstChild("AnimeTabArt")
	if oldArt then
		oldArt.Visible = false
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
			paperText(caption, 20)
			caption:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize = 6
		end
		fit()
		task.defer(function()
			if caption.Parent then
				fit()
			end
		end)
	end
	local lit = Dojo.Tab(button, caption and { caption } or {})
	lit(false)
	return lit
end

-- An action button (kit.css .tile / .pbtn): tone Go (vermilion tile), Gold (cream wood tile), Idle (outlined paper
-- button), Danger (paper button, vermilion rim); the label in the button face. Its text colour is kept in the
-- DojoTextColor attribute, so a later text role keeps it.
function Skin.Button(button, tone)
	local look = TONE[tone or "Go"] or TONE.Go
	Dojo.Fill(button, look[1], look[2])
	Dojo.Rim(button, look[3], look[4])
	button:SetAttribute("DojoTextColor", look[5])
	local corner = button:FindFirstChildOfClass("UICorner") or child(button, "UICorner", "Corner")
	local function style()
		corner.CornerRadius = UDim.new(0, 6) -- UiTheme.Apply snaps new corners to 8: set again after it
		if button:IsA("TextButton") then
			Dojo.Text(button, "Item")
		end
		for _, d in button:GetChildren() do
			if d:IsA("TextLabel") then
				d:SetAttribute("DojoTextColor", look[5])
				Dojo.Text(d, "Item")
			end
		end
	end
	style()
	task.defer(style)
end

-- Mirrors a tint holder's ImageColor3 into its fill: callers re-tint a card or plate through it (AnimeCard, AnimePlate).
local function tintHolder(frame, name, tint, props)
	local holder = frame:FindFirstChild(name)
	if not holder or not holder:IsA("ImageLabel") then
		holder = image(frame, name, "", UDim2.new(), UDim2.new(), 1)
		holder.BorderSizePixel = 0
		holder.BackgroundTransparency = 0
		holder:GetPropertyChangedSignal("ImageColor3"):Connect(function()
			holder.BackgroundColor3 = holder.ImageColor3
		end)
	end
	for key, value in props do
		holder[key] = value
	end
	holder.ImageColor3 = tint
	holder.BackgroundColor3 = tint
	return holder
end

-- A paper card (kit.css .card): cream paper, brown rim, a coloured strip along the top (rarity, state or the default
-- brown). Returns the strip, an ImageLabel AnimeCard whose ImageColor3 re-tints it. The Upgrades tree keeps the
-- angular card art.
function Skin.Card(frame, tint)
	if not legacy(frame) then
		local old = frame:FindFirstChild("AnimeCard")
		if old and old:IsA("ImageLabel") and old.Image ~= "" then
			old:Destroy() -- a 4.42 card art
		end
		Dojo.Fill(frame, C.CardTop, C.CardBottom)
		Dojo.Rim(frame, C.Rim, 2)
		Dojo.Corner(frame, 6)
		return tintHolder(frame, "AnimeCard", tint or Skin.Tint.Default, {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 0, 5),
		})
	end
	clear(frame)
	local card = frame:FindFirstChild("AnimeCard")
		or image(frame, "AnimeCard", ART.Card, UDim2.fromOffset(-3, -3), UDim2.new(1, 6, 1, 6), 0)
	card.ImageColor3 = tint or LEGACY_TINT
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
Skin.Color = { -- on paper (design doc 4.46)
	Section = C.Ink,
	White = C.Cream, -- text on a dark or vermilion fill
	Caption = C.Muted,
}
local PHONE_SCALE = 0.75 -- placeholder

-- The phone layout: this screen, or the viewport size given (the UI tests' simulated viewports).
local function compact(viewportSize)
	local camera = workspace.CurrentCamera
	local size = viewportSize or (camera and camera.ViewportSize)
	return size ~= nil and size.Y <= 500
end
Skin.Compact = compact

-- A token in px for this screen.
function Skin.Px(value)
	return compact() and math.floor(value * PHONE_SCALE + 0.5) or value
end

local function applyRole(label, role)
	label:SetAttribute("AnimeRole", role) -- UiTheme.Apply leaves this text alone
	local size = Skin.Px(Skin.Size[role] or Skin.Size.Body)
	local heavy = role == "Title" or role == "Section" or role == "Item"
	Dojo.Text(label, role) -- design doc 4.46: ink on paper, no outline
	if heavy then
		label.TextScaled = true
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
			or child(label, "UITextSizeConstraint", "AnimeLimit")
		limit.MaxTextSize, limit.MinTextSize = size, math.min(size, Skin.Px(Skin.Size.Caption))
	else
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

-- The standard header on any panel or popup: logo, ALL CAPS brush title, seal close. parts: Header (Frame),
-- Title (TextLabel), Icon (ImageLabel, optional), Close (GuiButton, optional), TitleEnd (UDim, optional). Returns a
-- function that re-lays it out; it also follows the panel's size.
function Skin.Header(panel, parts)
	local header, titleLabel, icon, close = parts.Header, parts.Title, parts.Icon, parts.Close
	panel.ClipsDescendants = false
	header.AnchorPoint = Vector2.zero
	header.Position = UDim2.new()
	header.ZIndex = math.max(header.ZIndex, 2)
	Skin.Strip(header)
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
			icon.Position = UDim2.fromOffset(left, gap)
			icon.Size = UDim2.fromOffset(closeSize, closeSize)
			left += closeSize + gap
		end
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

-- The footer bar at the bottom of a list panel: a lacquer plate with one centred caption line. Returns the label.
function Skin.Footer(panel, value)
	local bar = panel:FindFirstChild("AnimeFooter")
	if not bar then
		bar = Instance.new("Frame")
		bar.Name = "AnimeFooter"
		bar.BackgroundTransparency = 1
		bar.ZIndex = 3
		bar.Parent = panel
		local plate = Instance.new("Frame")
		plate.Name = "Plate"
		plate.Size = UDim2.fromScale(1, 1)
		plate.ZIndex = 3
		plate.Parent = bar
		Dojo.Lacquer(plate)
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
	Skin.Label(bar.Line, "Footer")
	return bar.Line
end

-- The Index frame (owner 2026-11-10: every panel shares one frame; design doc 4.46 look). Geometry in Issac's design
-- units, 1200 x 620 (phone 650 x 420; design doc 4.42 "Wider panels", kept by 4.46), drawn at k = panel px / units:
-- the handscroll (Client/DojoHandscroll, which PanelSwitch unrolls), the logo, the ALL CAPS brush title with its
-- vermilion kanji and sub line, a brushed rule, the seal close, paper tabs in the row at y 98, content from y 164 to 82
-- above the bottom, and the footer count on a lacquer plate. Same numbers as Client/QuestAnimeStyle and the Index.
Skin.Units = {
	W = IndexStyle.Frame.W,
	H = IndexStyle.Frame.H,
	PhoneW = IndexStyle.Frame.PhoneW,
	PhoneH = IndexStyle.Frame.PhoneH,
	Left = 56, -- content inset, left and right
	TabsY = 98,
	PhoneTabsY = 90,
	Top = 164, -- content top
	PhoneTop = 144,
	Bottom = 82, -- content ends this far above the bottom (the footer plate sits there)
	TabH = 40,
	TabGap = 8,
	Gap = 12, -- between cards and rows
	Inner = 8, -- inside a card
	Pad = 12, -- card padding
	Button = 44,
	ButtonSmall = 32,
}
-- Text sizes in units: Title and Tab as the Index; Item / Body / Caption read 20 / 16 / 13 px at the Index's own scale.
-- Speech: a character's spoken line (the boss gate guide's popup, layout B, owner 2026-11-25).
Skin.UnitSize = { Title = 72, Section = 40, Item = 34, Body = 28, Caption = 22, Tab = 22, Footer = 20, Speech = 48 }

-- parts: Title (TextLabel), Icon (ImageLabel, optional; Logo = image id to put on it), Close (GuiButton, optional),
-- Header (Frame made a transparent band over the header row at the panel's origin, optional), Scroll (false: a paper slip
-- body, no handscroll, for a card that is no scroll in 4.46, the loser card), H (design height in units on desktop,
-- default Units.H; design doc 4.46 Items: the Backpack is 50 taller, 670; the phone frame stays PhoneH), Top (content top in units on desktop, default
-- Units.Top; for a frame without tabs: the boss gate guide, 120).
-- Returns g: W, H, k, Small; px(units), at(x, y); Place(gui, x, y, w, h); Role(label, role); Tabs({buttons}) -> lit
-- setters; Button(button, tone); Content = { X, Y, W, H } in units; Footer(text); SetTitle(text); SetLogo(image);
-- OnLayout(fn(g)) runs now and on every size change; Relayout(); MeasureAt (UI tests). Skin.Frames[panel] = g.
Skin.Frames = setmetatable({}, { __mode = "k" })
function Skin.IndexFrame(panel, parts)
	parts = parts or {}
	panel.ClipsDescendants = false
	clear(panel)
	local aspect = panel:FindFirstChild("AnimeAspect") or child(panel, "UIAspectRatioConstraint", "AnimeAspect")
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.DominantAxis = Enum.DominantAxis.Height
	for _, name in { "AnimeBody", "AnimeStrip", "AnimeChrome" } do
		local old = panel:FindFirstChild(name, true)
		if old then
			old.Visible = false
		end
	end
	-- Design doc 4.46: the handscroll (PanelSwitch unrolls it from the centre), or a paper slip for a card.
	local paper = panel
	if parts.Scroll == false then
		Dojo.Fill(panel, C.Slip)
		Dojo.Rim(panel, C.SlipRim, 1.5)
		Dojo.Corner(panel, 6)
	else
		paper = Dojo.Scroll(panel).Content
	end
	local header = parts.Header
	if header then
		clear(header)
		header.AnchorPoint = Vector2.zero
		header.Position, header.Size = UDim2.new(), UDim2.new(1, 0, 0, 0)
		header.BackgroundTransparency = 1
		header.ClipsDescendants = false
		header.ZIndex = 8
	end
	local titleLabel = parts.Title or child(header or panel, "TextLabel", "Title")
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.AnchorPoint = Vector2.zero
	titleLabel.ZIndex = 10
	local function upper()
		local wanted = string.upper(titleLabel.Text)
		if titleLabel.Text ~= wanted then
			titleLabel.Text = wanted
		end
	end
	upper()
	titleLabel:GetPropertyChangedSignal("Text"):Connect(upper)
	local heading = Dojo.Heading(titleLabel)
	local rule = paper:FindFirstChild("HeaderRule") or child(paper, "Frame", "HeaderRule")
	rule.BackgroundColor3 = C.InkSoft
	rule.BackgroundTransparency = 0.45
	rule.BorderSizePixel = 0
	rule.Active = false
	local icon = parts.Icon
	if not icon and parts.Logo then
		icon = child(header or panel, "ImageLabel", "Icon")
	end
	if icon then
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.AnchorPoint = Vector2.zero
		icon.ZIndex = 11
		if parts.Logo then
			icon.Image = parts.Logo
		end
	end
	local close = parts.Close
	if close then
		Skin.Close(close)
		close.AnchorPoint = Vector2.zero
		close.ZIndex = 10
	end
	local footer = panel:FindFirstChild("AnimeFooterLine") or child(panel, "TextLabel", "AnimeFooterLine")
	footer.BackgroundTransparency = 1
	footer.TextXAlignment = Enum.TextXAlignment.Center
	footer.ZIndex = 4
	if footer.Text == "Label" then
		footer.Text = "" -- a new TextLabel's default text; empty until the panel sets its count line
	end
	Dojo.FooterPlate(footer, 10)

	local frameH = parts.H or Skin.Units.H
	local g = { k = 1, W = Skin.Units.W, H = frameH, Small = false, Content = {} }
	function g.px(units)
		return math.floor(units * g.k + 0.5)
	end
	function g.at(x, y)
		return UDim2.fromOffset(g.px(x), g.px(y))
	end
	function g.Place(gui, x, y, w, h)
		gui.AnchorPoint = Vector2.zero
		gui.Position, gui.Size = g.at(x, y), g.at(w, h)
	end
	-- One of the text roles at its unit size, ink on paper (Client/IndexAnimeStyle.Dojo.Text): Title and Section in the
	-- brush face, Item, Tab and Footer in the button face, Body and Caption in the body face.
	function g.Role(label, role)
		role = Skin.UnitSize[role] and role or "Body"
		label:SetAttribute("AnimeRole", role)
		local size = g.px(Skin.UnitSize[role])
		Dojo.Text(label, role)
		label.TextScaled = true
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
			or child(label, "UITextSizeConstraint", "AnimeLimit")
		limit.MaxTextSize = math.max(1, size)
		limit.MinTextSize = math.max(1, math.min(size, g.px(10)))
		return label
	end
	-- An action button (Skin.Button) with its caption on the Item size, in the tone's text colour.
	function g.Button(button, tone)
		Skin.Button(button, tone)
		if button:IsA("TextButton") then
			g.Role(button, "Item")
		end
	end
	-- Paper tabs across the row at y 98: up to 4 at the Index's width, more share the row. Returns the lit setters.
	local tabSets = {}
	function g.Tabs(buttons)
		local setters = {}
		for i, button in buttons do
			setters[i] = Skin.Tab(button, i)
			local caption = button:FindFirstChild("AnimeCaption") or button:FindFirstChildWhichIsA("TextLabel")
			if caption then
				g.Role(caption, "Tab")
			end
		end
		table.insert(tabSets, buttons)
		g.Relayout()
		return setters
	end
	local footerText = ""
	function g.Footer(value)
		footerText = value or ""
		footer.Text = footerText
		return footer
	end
	function g.SetTitle(value)
		titleLabel.Text = value
	end
	function g.SetLogo(id)
		if icon then
			icon.Image = id
		end
	end
	local hooks = {}
	local measuring = nil -- g.MeasureAt's { Small, W, H } while it lays the frame out at another size
	local function layout()
		local small, wPx, hPx
		if measuring then
			small, wPx, hPx = measuring.Small, measuring.W, measuring.H
		else
			small = compact()
			wPx = panel.Size.X.Offset > 0 and panel.Size.X.Offset or panel.AbsoluteSize.X
			hPx = panel.Size.Y.Offset > 0 and panel.Size.Y.Offset or panel.AbsoluteSize.Y
		end
		local W, H = small and Skin.Units.PhoneW or Skin.Units.W, small and Skin.Units.PhoneH or frameH
		if not measuring then
			aspect.AspectRatio = W / H
		end
		local k = math.min(wPx / W, hPx / H)
		if k <= 0 then
			return
		end
		g.k, g.W, g.H, g.Small = k, W, H, small
		-- Header (kit.css .hdr): logo 70 at (28, 14), the title after it, kanji and sub line after the title, the rule
		-- at y 90, the seal close 64 at 92 in from the right. Parts held to the right or bottom edge use Scale + offset,
		-- not W / H units: the same px here, and a layout read at another viewport (the UI tests' model scales offsets
		-- by k) stays inside the frame.
		if header then
			-- The header band ends where the tabs row starts (98, phone 90): logo (14 to 84), title (12 to 84) and close
			-- (16 to 80) fit inside both.
			header.Size = UDim2.new(1, 0, 0, g.px(small and Skin.Units.PhoneTabsY or Skin.Units.TabsY))
		end
		if icon then
			g.Place(icon, 28, 14, 70, 70)
		end
		local titleLeft = icon and 108 or 36
		titleLabel.AnchorPoint = Vector2.zero
		titleLabel.Position = g.at(titleLeft, 12)
		titleLabel.Size = UDim2.new(1, -g.px(titleLeft + 120), 0, g.px(72))
		titleLabel.Rotation = 0
		g.Role(titleLabel, "Title")
		heading(g.px, g.px(W))
		rule.Position, rule.Size = g.at(28, 90), UDim2.new(1, -g.px(56), 0, math.max(1, g.px(3)))
		if close then
			close.AnchorPoint = Vector2.zero
			close.Position, close.Size = UDim2.new(1, -g.px(92), 0, g.px(16)), g.at(64, 64)
		end
		footer.AnchorPoint = Vector2.zero
		footer.Position = UDim2.new(303 / 920, 0, 1, -g.px(60))
		footer.Size = UDim2.new(312 / 920, 0, 0, g.px(28))
		g.Role(footer, "Footer")
		local tabsY = small and Skin.Units.PhoneTabsY or Skin.Units.TabsY
		for _, buttons in tabSets do
			local n = #buttons
			-- Units, not Scale: the tabs sit in zero-size holders (Backpack Panel/Tabs), where Scale is 0.
			local w = n <= 4 and (W - 136) / 4 or (W - 112 - Skin.Units.TabGap * (n - 1)) / n
			for i, button in buttons do
				g.Place(button, 56 + (i - 1) * (w + Skin.Units.TabGap), tabsY, w, Skin.Units.TabH)
				local caption = button:FindFirstChild("AnimeCaption")
				if caption then
					caption.Position, caption.Size = g.at(8, 0), UDim2.new(1, -g.px(16), 1, 0)
				end
			end
		end
		local top = small and Skin.Units.PhoneTop or parts.Top or Skin.Units.Top
		g.Content.X, g.Content.Y, g.Content.W, g.Content.H = 56, top, W - 112, H - top - Skin.Units.Bottom
		g.Content.TabsY = tabsY
		for _, hook in hooks do
			hook(g)
		end
	end
	local queued = false
	function g.Relayout()
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				layout()
			end)
		end
	end
	function g.OnLayout(fn)
		table.insert(hooks, fn)
		layout()
		g.Relayout() -- after UiTheme.Apply's and Skin.Tab's deferred passes
	end
	-- UI tests: lay the frame and its hooks out at another viewport (phone layout or not) and frame size in px, call
	-- read() on that layout, then lay it out for this screen again, all in one go (no frame is drawn in between).
	function g.MeasureAt(viewportSize, wPx, hPx, read)
		measuring = { Small = compact(viewportSize), W = wPx, H = hPx }
		layout()
		local ok, err = pcall(read)
		measuring = nil
		layout()
		if not ok then
			error(err, 0)
		end
	end
	Skin.Frames[panel] = g
	panel:GetPropertyChangedSignal("Size"):Connect(g.Relayout)
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(g.Relayout)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(g.Relayout)
	end
	layout()
	g.Relayout()
	return g
end

-- A paper slip behind a wide row (kit.css .slip) with a tinted bar at its left end. Returns the bar, an ImageLabel
-- AnimePlate whose ImageColor3 re-tints it. The Upgrades tree keeps the slanted plate art.
function Skin.Plate(frame, tint)
	if not legacy(frame) then
		local old = frame:FindFirstChild("AnimePlate")
		if old and old:IsA("ImageLabel") and old.Image ~= "" then
			old:Destroy() -- a 4.42 plate art
		end
		Dojo.Fill(frame, C.Slip)
		Dojo.Rim(frame, C.SlipRim, 1.5)
		Dojo.Corner(frame, 4)
		return tintHolder(frame, "AnimePlate", tint or Skin.Tint.Default, {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(0, 8, 1, -4),
		})
	end
	clear(frame)
	local plate = frame:FindFirstChild("AnimePlate")
		or image(frame, "AnimePlate", ART.Plate, UDim2.new(), UDim2.fromScale(1, 1), 0)
	plate.ImageColor3 = tint or LEGACY_TINT
	return plate
end

return Skin
