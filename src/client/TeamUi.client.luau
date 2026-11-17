--!nonstrict
-- Team Setup page (design doc 4.45, owner 2026-11-17; docs/TEAM_AND_STAMINA_SPEC.md "Team" and "Team Setup page";
-- replaces layout A of 4.40). Opened by the second column's Team button and its key T (Client/BossEventUi), a click on
-- the team minibar (Client/TeamHud) and the plaza Team altar (Client/PlazaPrompts), all PanelSwitch "Team", with the
-- shared Sakura transition (cyan accent).
-- Three stacked octagonal altars hold a local draft of the Team: tap an altar, then a roster card (or the other way
-- round); a member put on another altar swaps; Remove takes one off. Quick Setup asks the server (TeamQuickPick) for the
-- best owned characters for the empty altars; Deploy sends the draft through the unchanged SetTeam and closes with the
-- altars' activation. Closing with an undeployed draft asks Deploy or Discard. The Sidekicks tab equips a Sidekick on a
-- member at once (SidekickEquip). The server decides every figure; the client only displays.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CharacterCatalog = require(shared:WaitForChild("CharacterCatalog"))
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local RaceConfig = require(shared:WaitForChild("RaceConfig"))
local SeriesCatalog = require(shared:WaitForChild("SeriesCatalog"))
local SidekickConfig = require(shared:WaitForChild("SidekickConfig"))
local SpawnArea = require(shared:WaitForChild("SpawnArea"))
local StaminaConfig = require(shared:WaitForChild("StaminaConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local Icons = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
local Components = require(script.Parent.RollToast.Ui:WaitForChild("RacerComponents"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local RosterCard = require(script.Parent:WaitForChild("RosterCard"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local SlotPicker = require(script.Parent:WaitForChild("SlotPicker"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local UiTooltip = require(script.Parent:WaitForChild("UiTooltip"))

local D = UiTheme.Dojo
local SLOTS = 3
local SIZE = StaminaConfig.TEAM_SIZE
-- Altar tiers in studs (bottom up) as the plaza Team altar; the viewport frames them. Proposed.
local TIERS = { 14, 10.5, 7 }
local TIER_H = 1.2
local FLY = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CARD_W, CARD_H = 112, 132 -- roster cards, design units
local DESIGN_H = 720 -- the full-screen page is laid out in units of a 720-tall screen (owner 2026-11-17 mockup)
local GREEN = Color3.fromRGB(64, 168, 76) -- Deploy, as the mockup
local PURPLE = Color3.fromRGB(122, 72, 176) -- the shown tray tab, as the mockup
local BACKDROP = "rbxassetid://119528763151983" -- the approved blossom-shrine clean plate (assets/ui/summon_shrine)

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	props.TextScaled = props.TextScaled ~= false
	return make("TextLabel", name, parent, props)
end
local function flat(button, color)
	-- Flat, restrained buttons (4.45): a fill, a medium-thin outline, no pill.
	if button:IsA("GuiButton") then
		button.AutoButtonColor = false
	end
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	UiTheme.Corner(button, 4)
	local stroke = button:FindFirstChild("Edge") or make("UIStroke", "Edge", button, {})
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness, stroke.Color = D.Stroke, D.Gold
	return button
end
-- A small icon glyph at a button's left (its Text stays the plain words).
local function glyph(button, char)
	make("UIPadding", "Pad", button, { PaddingLeft = UDim.new(0.16, 0) })
	return make("TextLabel", "Glyph", button, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(-0.12, 0.5),
		Size = UDim2.fromScale(0.14, 0.6),
		Text = char,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = button.TextColor3,
		ZIndex = button.ZIndex + 1,
	})
end

local function hoverable(button)
	local scale = button:FindFirstChild("HoverScale") or make("UIScale", "HoverScale", button, {})
	button.MouseEnter:Connect(function()
		UiMotion.Create(scale, HOVER, { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		UiMotion.Create(scale, HOVER, { Scale = 1 }):Play()
	end)
end

local root = make("ScreenGui", "RacerTeam", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2, -- the panels' order (Backpack, Checkpoints)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
-- Full screen (owner 2026-11-17, from the mockup): the dojo scene behind everything.
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = D.Ink,
	BorderSizePixel = 0,
	Visible = false,
	Active = true,
})

local header = make("Frame", "Header", panel, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
local title = caption("Title", header, {
	Text = "TEAM SETUP",
	TextColor3 = D.Cream,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6,
})
local titleLine = make("Frame", "Underline", header, { BackgroundColor3 = D.Cyan, BorderSizePixel = 0, ZIndex = 6 })
local icon = make("ImageLabel", "Icon", header, {
	BackgroundTransparency = 1,
	Image = Icons.Team.Image,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 6,
})
local close =
	make("TextButton", "Close", header, { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, ZIndex = 6 })
local closeX = caption("X", close, { Size = UDim2.fromScale(1, 1), Text = "✕", TextColor3 = D.Cream, ZIndex = 7 })
local bonusButton =
	flat(make("TextButton", "BonusButton", header, { Text = "Team Bonus", TextColor3 = D.Cream, ZIndex = 6 }), D.Ink)
make("Frame", "Underline", bonusButton, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 4),
	Size = UDim2.new(1, 0, 0, 2),
	BackgroundColor3 = D.Cyan,
	BorderSizePixel = 0,
	ZIndex = 6,
})

-- Units of a 720-tall screen (k px each); W is the screen's width in units. The roles size text as the panels do.
local ROLE = { Title = 44, Section = 32, Item = 24, Body = 19, Caption = 15, Footer = 16 }
local g = { k = 1, W = 1280, Small = false }
function g.px(u)
	return math.floor(u * g.k + 0.5)
end
function g.at(x, y)
	return UDim2.fromOffset(g.px(x), g.px(y))
end
function g.Place(gui, x, y, w, h)
	gui.AnchorPoint = Vector2.zero
	gui.Position, gui.Size = g.at(x, y), g.at(w, h)
end
function g.Role(label, role)
	local size = ROLE[role] or ROLE.Body
	label:SetAttribute("AnimeRole", role)
	label.Font = UiTheme.Font
	label.TextScaled = true
	local limit = label:FindFirstChild("RoleLimit") or make("UITextSizeConstraint", "RoleLimit", label, {})
	limit.MaxTextSize = math.max(1, g.px(size))
	limit.MinTextSize = math.max(1, math.min(g.px(size), g.px(9)))
	local stroke = label:FindFirstChild("RoleStroke")
		or make("UIStroke", "RoleStroke", label, { ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	stroke.Color = D.Ink
	stroke.Thickness = (role == "Title" or role == "Item") and 2 or 1
	stroke.Transparency = role == "Caption" and 1 or 0.15
	return label
end

-- State: the draft (slot -> id or nil), the picked altar, the picked card (character id or Sidekick entry).
local draft = {}
local selected = nil
local chosen = nil
local chosenSidekick = nil
local tab = "Characters"
local busy = false
local render -- set below
local figureOn -- set below

local function saved()
	local out = {}
	for i, id in SlotPicker.Team() do
		out[i] = id ~= "" and id or nil
	end
	return out
end
local function list(t)
	local out = {}
	for i = 1, SIZE do
		if t[i] then
			table.insert(out, t[i])
		end
	end
	return out
end
local function filled()
	return #list(draft)
end
-- Slot by slot: a gap the altars show (a member moved to slot 3) is a change too; Deploy closes it up.
local function dirty()
	local was = saved()
	for i = 1, SIZE do
		if draft[i] ~= was[i] then
			return true
		end
	end
	return false
end
-- The draft slot holding `id` (the draft may have gaps, so not table.find).
local function slotOf(id)
	for i = 1, SIZE do
		if draft[i] == id then
			return i
		end
	end
	return nil
end
local openCount = 0 -- each open; a delayed close of an earlier open does nothing

-- Backdrop: the approved blossom-shrine scene (as the summon page's), darkened toward the tray so text reads.
local backdrop = make("ImageLabel", "Backdrop", panel, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = BACKDROP,
	ScaleType = Enum.ScaleType.Crop,
	ZIndex = 0,
})
local shade = make("Frame", "Shade", backdrop, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = D.Ink,
	BorderSizePixel = 0,
	ZIndex = 0,
})
make("UIGradient", "Fade", shade, {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.25, 0.8),
		NumberSequenceKeypoint.new(0.62, 0.7),
		NumberSequenceKeypoint.new(1, 0.15),
	}),
})

-- Top centre: one dot per altar.
local dots = make("Frame", "Dots", panel, { BackgroundTransparency = 1 })
make("UIListLayout", "Layout", dots, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 10),
})
for n = 1, SLOTS do
	local dot = make("Frame", "Dot" .. n, dots, { BackgroundColor3 = D.Cyan, LayoutOrder = n, Rotation = 45 })
	make("UIStroke", "Edge", dot, { Color = D.Cream, Thickness = 1.5 })
	make("UIAspectRatioConstraint", "Square", dot, {})
end

-- The three altars: a ViewportFrame pedestal of stacked octagons (SpawnArea.Octagon, as the plaza's), the member's
-- portrait standing over it, name and rarity / cruise under it; an empty one shows "+" and "Add Character".
local altarsFrame = make("Frame", "Altars", panel, { BackgroundTransparency = 1 })
local altars = {}
for n = 1, SLOTS do
	local b = make("TextButton", "Altar" .. n, altarsFrame, {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Selectable = true,
	})
	local view = make("ViewportFrame", "Pedestal", b, {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 150, 150),
		LightColor = Color3.fromRGB(255, 235, 220),
		LightDirection = Vector3.new(-0.6, -2, -1),
		ZIndex = 2,
	})
	local model = make("Model", "Altar", view)
	local edges = {}
	for i, width in TIERS do
		local y = (i - 1) * TIER_H
		SpawnArea.Octagon(
			model,
			"Tier" .. i,
			width,
			TIER_H,
			CFrame.new(0, y + TIER_H / 2, 0),
			i == 2 and Color3.fromRGB(158, 152, 140) or D.WoodDark,
			Enum.Material.SmoothPlastic
		)
		for _, part in SpawnArea.Octagon(model, "Edge" .. i, width + 0.3, 0.18, CFrame.new(0, y + TIER_H, 0), D.Cyan) do
			table.insert(edges, part)
		end
	end
	local deck = #TIERS * TIER_H
	local core = SpawnArea.Octagon(model, "Core", TIERS[#TIERS] - 0.6, 0.12, CFrame.new(0, deck + 0.06, 0), D.Sakura)
	-- The light column over the deck (pink under a member, cyan over an empty altar), as the mockup.
	local column = make("Part", "Column", model, {
		Anchored = true,
		Size = Vector3.new(TIERS[#TIERS] - 1.5, 9, TIERS[#TIERS] - 1.5),
		CFrame = CFrame.new(0, deck + 4.5, 0),
		Material = Enum.Material.Neon,
		Color = D.Sakura,
		Transparency = 0.86,
		CastShadow = false,
	})
	local camera = make("Camera", "Camera", view, { FieldOfView = 30 })
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 9.5, 36), Vector3.new(0, 4.6, 0))
	view.CurrentCamera = camera
	local plus = caption("Plus", b, { Text = "+", TextColor3 = D.Cyan, ZIndex = 4 })
	local add = caption("Add", b, { Text = "Add Character", TextColor3 = D.Cream, ZIndex = 4 })
	local remove = flat(make("TextButton", "Remove", b, { Text = "Remove", Visible = false, ZIndex = 6 }), D.Burgundy)
	altars[n] = {
		Button = b,
		Edges = edges,
		Core = core,
		Column = column,
		View = view,
		Deck = deck,
		SlotLabel = flat(
			caption(
				"SlotLabel",
				b,
				{ Text = "SLOT " .. n, TextColor3 = D.Cream, ZIndex = 4, BackgroundTransparency = 0.1 }
			),
			D.Ink
		),
		-- A small drawn-portrait badge by the name; the member itself stands on the altar as its 3D model.
		Portrait = make("ImageLabel", "Portrait", b, {
			BackgroundColor3 = D.Ink,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 4,
		}),
		Name = caption("Name", b, { TextColor3 = D.Cream, ZIndex = 4 }),
		Info = caption("Info", b, { TextColor3 = D.Gold, ZIndex = 4 }),
		Plus = plus,
		Add = add,
		Remove = remove,
	}
end

-- Footer row: Team 1 and its status, the count with a thin bar, Quick Setup and Deploy.
local footer = make("Frame", "Footer", panel, { BackgroundTransparency = 1 })
local pill = flat(make("Frame", "Pill", footer, { BackgroundTransparency = 0.15 }), D.Ink)
local countLines = {}
for i = 1, 2 do
	countLines[i] = make("Frame", "Line" .. i, footer, { BackgroundColor3 = D.Gold, BorderSizePixel = 0 })
end
local teamName =
	caption("TeamName", footer, { Text = "Team 1", TextColor3 = D.Cream, TextXAlignment = Enum.TextXAlignment.Left })
local status =
	caption("Status", footer, { Text = "Ready", TextColor3 = D.Cyan, TextXAlignment = Enum.TextXAlignment.Left })
local count = caption("Count", footer, { Text = "", TextColor3 = D.Cream })
local progress = make("Frame", "Progress", footer, { BackgroundColor3 = D.Ink, BorderSizePixel = 0 })
local fill = make("Frame", "Fill", progress, { BackgroundColor3 = D.Cyan, BorderSizePixel = 0 })
local quick = flat(make("TextButton", "QuickSetup", panel, { Text = "Quick Setup", TextColor3 = D.Ink }), D.Cream)
local deploy = flat(make("TextButton", "Deploy", panel, { Text = "Deploy", TextColor3 = D.Cream }), GREEN)

-- Roster tray: Characters / Sidekicks tabs, Sort and Search, one row of cards.
local tray =
	make("Frame", "Tray", panel, { BackgroundColor3 = D.Ink, BackgroundTransparency = 0.2, BorderSizePixel = 0 })
make("Frame", "TopLine", tray, {
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = D.Gold,
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
})
local tabs = make("Frame", "Tabs", tray, { BackgroundTransparency = 1 })
local tabButtons = {}
for i, name in { "Characters", "Sidekicks" } do
	local t = flat(make("TextButton", name, tabs, { Text = name, TextColor3 = D.Cream }), D.Ink)
	make("Frame", "Underline", t, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = D.Cyan,
		BorderSizePixel = 0,
	})
	tabButtons[i] = t
end
local sortMode = RosterCard.Sorts[1]
local sortButton = flat(make("TextButton", "Sort", tray, { Text = "Sort: " .. sortMode, TextColor3 = D.Cream }), D.Wood)
local search = make("TextBox", "Search", tray, {
	BackgroundColor3 = D.Ink,
	ClearTextOnFocus = false,
	PlaceholderText = "Search",
	PlaceholderColor3 = D.Gold,
	Text = "",
	TextColor3 = D.Cream,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
})
UiTheme.Corner(search, 4)
local roster = make("ScrollingFrame", "Roster", tray, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 6,
	HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
})
local rosterLayout = make("UIListLayout", "Layout", roster, {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
})

-- Popovers: the team bonus, and the unsaved-draft question.
local popover = make("Frame", "BonusPopover", panel, { BackgroundColor3 = D.Ink, Visible = false, ZIndex = 20 })
UiTheme.Corner(popover, 4)
make("UIStroke", "Edge", popover, { Color = D.Gold, Thickness = D.Stroke })
local bonusName = caption("Name", popover, { TextColor3 = D.Gold, ZIndex = 21 })
local bonusEffect = caption("Effect", popover, { TextColor3 = D.Cream, ZIndex = 21, TextWrapped = true })
local bonusTotal = caption("Total", popover, { TextColor3 = D.Cyan, ZIndex = 21 })
local confirm = make("Frame", "ConfirmClose", panel, { BackgroundColor3 = D.Ink, Visible = false, ZIndex = 30 })
UiTheme.Corner(confirm, 4)
make("UIStroke", "Edge", confirm, { Color = D.Gold, Thickness = D.Stroke })
local confirmText = caption("Question", confirm, { Text = "Deploy your changes?", TextColor3 = D.Cream, ZIndex = 31 })
local confirmDeploy =
	flat(make("TextButton", "Deploy", confirm, { Text = "Deploy", TextColor3 = D.Ink, ZIndex = 31 }), D.Cyan)
local confirmDiscard =
	flat(make("TextButton", "Discard", confirm, { Text = "Discard", TextColor3 = D.Cream, ZIndex = 31 }), D.Burgundy)

for _, b in { quick, deploy, sortButton, bonusButton, confirmDeploy, confirmDiscard, table.unpack(tabButtons) } do
	hoverable(b)
end

glyph(bonusButton, "☰")
glyph(quick, "⚡")
glyph(deploy, "▶")

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or D.Cyan
end

-- Full-screen layout (owner mockup 2026-11-17) in units of a 720-tall screen: title, dots, Team Bonus and close on top;
-- the three altars across the middle; Team 1, the count, Quick Setup and Deploy in a row; the roster tray at the bottom.
local function layout()
	local size = panel.AbsoluteSize
	if size.Y <= 0 then
		return
	end
	g.k = size.Y / DESIGN_H
	g.W = size.X / g.k
	g.Small = size.Y < 500
	local W = g.W
	local M = 28 -- side margin
	-- Top row
	g.Place(icon, M, 18, 54, 54)
	g.Place(title, M + 64, 16, 360, 52)
	g.Role(title, "Title").TextColor3 = D.Cream
	g.Place(titleLine, M + 64, 70, 250, 3)
	g.Place(dots, W / 2 - 60, 26, 120, 20)
	for _, dot in dots:GetChildren() do
		if dot:IsA("Frame") then
			dot.Size = g.at(16, 16)
		end
	end
	dots.Layout.Padding = UDim.new(0, g.px(18))
	g.Place(close, W - M - 54, 16, 54, 54)
	g.Role(closeX, "Title").TextColor3 = D.Cream
	g.Place(bonusButton, W - M - 54 - 16 - 220, 20, 220, 46)
	g.Role(bonusButton, "Body").TextColor3 = D.Cream
	-- Altars
	local top, altarsH = 92, 380
	local spacing = math.min(W / 3.2, 420)
	local aw = math.min(spacing * 0.92, 360)
	g.Place(altarsFrame, 0, top, W, altarsH)
	for n, a in altars do
		local cx = W / 2 + (n - 2) * spacing
		g.Place(a.Button, cx - aw / 2, 0, aw, altarsH)
		g.Place(a.SlotLabel, aw / 2 - 64, 0, 128, 34)
		g.Role(a.SlotLabel, "Body").TextColor3 = D.Cream
		a.SlotLabel.BackgroundTransparency = 0.1 -- a pill (caption() made it clear)
		g.Place(a.Portrait, aw / 2 - 110, 42, 30, 30)
		UiTheme.Corner(a.Portrait, 999)
		g.Place(a.Name, aw / 2 - 74, 40, 190, 32)
		a.Name.TextXAlignment = Enum.TextXAlignment.Left
		g.Role(a.Name, "Item").TextColor3 = D.Cream
		g.Place(a.Info, 0, 72, aw, 22)
		g.Role(a.Info, "Caption").TextColor3 = D.Gold
		g.Place(a.Add, 0, 44, aw, 30)
		g.Role(a.Add, "Item").TextColor3 = D.Cream
		g.Place(a.View, 0, 96, aw, altarsH - 96)
		g.Place(a.Plus, aw / 2 - 60, 150, 120, 120)
		g.Role(a.Plus, "Title").TextColor3 = D.Cyan
		a.Plus:FindFirstChild("RoleLimit").MaxTextSize = g.px(120)
		-- The icons sit at the figure's top-right; Remove under them.
		a.GearPos = g.at(aw * 0.78, 104)
		a.GearSize = g.px(24)
		g.Place(a.Remove, aw - 104, 140, 96, 30)
		g.Role(a.Remove, "Caption").TextColor3 = D.Cream
	end
	-- Footer row
	local fy = top + altarsH + 8
	g.Place(footer, 0, fy, W, 60)
	g.Place(pill, M, 4, 300, 52)
	g.Place(teamName, M + 20, 6, 150, 46)
	g.Role(teamName, "Item").TextColor3 = D.Cream
	g.Place(status, M + 160, 6, 130, 46)
	status.TextXAlignment = Enum.TextXAlignment.Right
	local statusColor = status.TextColor3
	g.Role(status, "Caption").TextColor3 = statusColor
	g.Place(count, W / 2 - 150, 10, 300, 36)
	g.Role(count, "Item").TextColor3 = D.Cream
	g.Place(countLines[1], W / 2 - 270, 28, 110, 2)
	g.Place(countLines[2], W / 2 + 160, 28, 110, 2)
	g.Place(progress, W / 2 - 110, 50, 220, 4)
	g.Place(deploy, W - M - 240, fy + 2, 240, 56)
	g.Place(quick, W - M - 240 - 16 - 220, fy + 4, 220, 52)
	g.Role(quick, "Item").TextColor3 = D.Ink
	g.Role(deploy, "Section").TextColor3 = D.Cream
	-- Tray
	local ty = fy + 72
	g.Place(tray, 0, ty, W, DESIGN_H - ty)
	local trayH = DESIGN_H - ty
	tabs.Position, tabs.Size = g.at(M, 14), g.at(330, 46)
	for i, t in tabButtons do
		t.Position, t.Size = g.at((i - 1) * 168, 0), g.at(160, 46)
		g.Role(t, "Item").TextColor3 = D.Cream
	end
	g.Place(sortButton, M, 70, 160, 34)
	g.Role(sortButton, "Caption").TextColor3 = D.Cream
	g.Place(search, M + 168, 70, 160, 34)
	g.Role(search, "Caption").TextColor3 = D.Cream
	g.Place(roster, M + 350, 8, W - 2 * M - 350, trayH - 16)
	rosterLayout.Padding = UDim.new(0, g.px(10))
	-- Popovers
	g.Place(popover, W - M - 54 - 16 - 260, 76, 260, 120)
	g.Place(bonusName, 10, 8, 240, 26)
	g.Place(bonusEffect, 10, 38, 240, 44)
	g.Place(bonusTotal, 10, 88, 240, 22)
	g.Place(confirm, W / 2 - 200, 230, 400, 150)
	g.Place(confirmText, 20, 16, 360, 44)
	g.Place(confirmDeploy, 36, 90, 150, 44)
	g.Place(confirmDiscard, 214, 90, 150, 44)
	for _, b in { confirmText, confirmDeploy, confirmDiscard, bonusName, bonusEffect, bonusTotal } do
		local color = b.TextColor3
		g.Role(b, "Body").TextColor3 = color
	end
	if panel.Visible then
		task.defer(render)
	end
end

local function drawBonus()
	local kind, seriesId = string.match(player:GetAttribute("TeamBonus") or "", "^(%a+):(.+)$")
	local series = seriesId and SeriesCatalog.Get(seriesId)
	local function percent(multi)
		return math.floor((multi - 1) * 100 + 0.5)
	end
	if series and kind == "Preset" then
		bonusName.Text = "★ " .. string.upper(series.Preset.Name)
		bonusEffect.Text = string.format(
			"+%d%% STAMINA, +%d%% SPEED",
			percent(StaminaConfig.TEAM_BONUS.Preset),
			percent(RaceConfig.PRESET_CRUISE)
		)
	elseif series and kind == "Series" then
		bonusName.Text = string.upper(series.Name)
		bonusEffect.Text = string.format("+%d%% STAMINA", percent(StaminaConfig.TEAM_BONUS.Series))
	else
		bonusName.Text = "No team bonus"
		bonusEffect.Text = string.format("3 of one series: +%d%% stamina", percent(StaminaConfig.TEAM_BONUS.Series))
	end
	local total = 0
	for n, id in saved() do
		local spec = CharacterCatalog.Get(id)
		local seconds = tonumber(player:GetAttribute("TeamStamina" .. n)) or (spec and StaminaConfig.Seconds(spec)) or 0
		total += math.round(seconds * 10) / 10
	end
	bonusTotal.Text = string.format("Total %.1f s", total)
end

-- Puts character `id` on draft slot `slot` (nil: takes it off); a member on another slot swaps there.
local function place(slot, id)
	if id then
		for i = 1, SIZE do
			if draft[i] == id then
				draft[i] = draft[slot]
			end
		end
	end
	draft[slot] = id
end

-- The portrait flies from a roster card to its altar, then the altar's edges pulse (4.45 placement).
local GuiService = game:GetService("GuiService")
-- Where a card's art is now (read before a render redraws the roster).
local function artSnapshot(card)
	local art = card and card:FindFirstChild("Art")
	if not (art and art:IsA("ImageLabel") and art.Image ~= "") then
		return nil
	end
	return { Image = art.Image, Position = art.AbsolutePosition, Size = art.AbsoluteSize }
end
local function flyIn(from, slot)
	local a = altars[slot]
	if not from or UiMotion.Reduced() then
		UiMotion.Pop(a.Portrait, 0.08)
		return
	end
	local inset = GuiService:GetGuiInset().Y -- RacerTeam ignores the inset; AbsolutePosition does not
	local ghost = make("ImageLabel", "Fly", root, {
		BackgroundTransparency = 1,
		Image = from.Image,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(from.Position.X, from.Position.Y + inset),
		Size = UDim2.fromOffset(from.Size.X, from.Size.Y),
		ZIndex = 50,
	})
	local target = a.Portrait
	local t = UiMotion.Create(ghost, FLY, {
		Position = UDim2.fromOffset(target.AbsolutePosition.X, target.AbsolutePosition.Y + inset),
		Size = UDim2.fromOffset(target.AbsoluteSize.X, target.AbsoluteSize.Y),
	})
	t.Completed:Connect(function()
		ghost:Destroy()
		UiMotion.Pop(a.Portrait, 0.06)
	end)
	t:Play()
end

-- An altar's edge colour: bright cyan while selected, the member's rarity, else cyan.
local function paintEdges(slot)
	local a = altars[slot]
	local spec = draft[slot] and CharacterCatalog.Get(draft[slot])
	local edge = selected == slot and D.Cyan:Lerp(Color3.new(1, 1, 1), 0.35)
		or spec and (GachaConfig.RARITY_COLORS[spec.Rarity] or D.Cyan)
		or D.Cyan
	for _, part in a.Edges do
		part.Color = edge
	end
end

local function pulseEdges(slot, delay)
	task.delay(delay or 0, function()
		for _, part in altars[slot].Edges do
			part.Color = D.Sakura
		end
		task.delay(0.3, function()
			paintEdges(slot)
		end)
	end)
end

local function selectSlot(slot)
	selected = slot
	if chosen and slot then
		local from = artSnapshot(roster:FindFirstChild(chosen))
		local here = draft[slot] == chosen
		place(slot, not here and chosen or nil)
		chosen, selected = nil, nil -- placed: the next tap on this altar selects it again
		render()
		if not here then
			flyIn(from, slot)
			pulseEdges(slot, 0.35)
			UiFeedback.Play("Equip", altars[slot].Button)
		end
		return
	end
	if chosenSidekick and slot and draft[slot] then
		-- Sidekicks tab: equip on that member at once (SidekickEquip; not part of the draft).
		local entry = chosenSidekick
		chosenSidekick = nil
		local ok, done, message = pcall(function()
			return remotes:WaitForChild("SidekickEquip"):InvokeServer(draft[slot], entry)
		end)
		setStatus(
			ok and done and "Sidekick equipped" or tostring(ok and message or "Connection error"),
			not (ok and done) and D.Sakura or nil
		)
		UiFeedback.Play((ok and done) and "Equip" or "Denied", altars[slot].Button)
	end
	render()
end

local function deployDraft(thenClose)
	if busy then
		return
	end
	local team = list(draft)
	if #team == 0 then
		setStatus("Your Team needs at least 1 character", D.Sakura)
		UiFeedback.Play("Denied", deploy)
		return
	end
	busy = true
	local ok, done, message = pcall(function()
		return remotes:WaitForChild("SetTeam"):InvokeServer(team)
	end)
	busy = false
	if not (ok and done) then
		setStatus(ok and tostring(message or "Try again") or "Connection error", D.Sakura)
		UiFeedback.Play("Denied", deploy)
		confirm.Visible = false
		return
	end
	-- Saved: the three altars fire together (cyan then sakura), then the page closes.
	UiFeedback.Play("Equip", deploy)
	for n = 1, SLOTS do
		pulseEdges(n, (n - 1) * 0.08)
		if draft[n] then
			task.delay((n - 1) * 0.08, function()
				UiMotion.Pop(altars[n].Portrait, 0.08)
			end)
		end
	end
	confirm.Visible = false
	setStatus("Deployed")
	if thenClose ~= false then
		local this = openCount
		task.delay(UiMotion.Reduced() and 0 or 0.8, function()
			if openCount == this and panel.Visible then
				PanelSwitch.ForceClose("Team")
			end
		end)
	end
end

local function applySearch()
	local query = string.lower(search.Text)
	for _, card in roster:GetChildren() do
		if card:IsA("GuiButton") then
			card.Visible = query == ""
				or string.find(string.lower(card:GetAttribute("SearchName") or ""), query, 1, true) ~= nil
		end
	end
end

-- Marks, strokes and badges follow the draft in place; the cards are rebuilt only when what they list changes.
local rosterKey = nil
local function markRoster()
	for _, card in roster:GetChildren() do
		if not card:IsA("GuiButton") then
			continue
		end
		if tab == "Characters" then
			local slot = slotOf(card.Name)
			card.Badge.Text = slot and ("TEAM " .. slot) or ""
			card.Badge.TextColor3 = UiTheme.Palette.Money
			card.Stroke.Color = card.Name == chosen and D.Cyan or slot and D.Gold or UiTheme.Outline
		else
			local spec = SidekickConfig.Get(card:GetAttribute("SidekickId"))
			card.Stroke.Color = card.Name == chosenSidekick and D.Cyan or SidekickView.RarityColor(spec and spec.Rarity)
		end
	end
end
local function ownedKey()
	local data = player:FindFirstChild("GachaData")
	local ids = {}
	for _, entry in data and data:GetChildren() or {} do
		table.insert(ids, entry.Name)
	end
	table.sort(ids)
	return table.concat(ids, ",")
end
local function drawRoster()
	local key = table.concat({
		tab,
		sortMode,
		tostring(g.k),
		ownedKey(),
		player:GetAttribute("SidekickBag") or "",
		player:GetAttribute("SidekickGear") or "",
		player:GetAttribute("RelicGear") or "",
	}, "|")
	if key == rosterKey then
		markRoster()
		return
	end
	rosterKey = key
	for _, child in roster:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local size = UDim2.fromOffset(g.px(CARD_W), g.px(CARD_H))
	if tab == "Characters" then
		for order, spec in RosterCard.Owned(player, sortMode, true) do
			local card = RosterCard.new(roster, spec, order, g, spec.Id == chosen)
			card.Size = size
			RosterCard.Gear(card, spec.Id, player, g.px(34), g.px(18))
			card.Activated:Connect(function()
				chosenSidekick = nil
				if selected then
					chosen = spec.Id
					selectSlot(selected)
					return
				end
				chosen = chosen ~= spec.Id and spec.Id or nil
				render()
				local picked = roster:FindFirstChild(spec.Id)
				if picked then
					UiMotion.Pop(picked, 0.06)
				end
			end)
		end
	else
		local gear = SidekickView.Gear(player)
		local wearer = {}
		for id, entry in gear do
			wearer[entry] = id
		end
		for order, row in SidekickView.Bag(player) do
			local spec = SidekickConfig.Get(row.Id)
			local card = make("TextButton", row.Entry, roster, {
				LayoutOrder = order,
				Size = size,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = D.Ink,
			})
			card:SetAttribute("SidekickId", row.Id)
			card:SetAttribute("SearchName", spec and spec.Name or row.Id)
			UiTheme.Corner(card, 4)
			make("UIStroke", "Stroke", card, {
				Thickness = 2,
				Color = row.Entry == chosenSidekick and D.Cyan or SidekickView.RarityColor(spec and spec.Rarity),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})
			SidekickView.Art(card, spec, UDim2.fromScale(0.5, 0.4), UDim2.fromScale(0.8, 0.62))
			local who = wearer[row.Entry] and CharacterCatalog.Get(wearer[row.Entry])
			g.Role(
				caption("Name", card, {
					Position = UDim2.fromScale(0.05, 0.74),
					Size = UDim2.fromScale(0.9, 0.13),
					Text = spec and spec.Name or row.Id,
					ZIndex = 5,
				}),
				"Caption"
			).TextColor3 =
				D.Cream
			g.Role(
				caption("Worn", card, {
					Position = UDim2.fromScale(0.05, 0.87),
					Size = UDim2.fromScale(0.9, 0.11),
					Text = who and ("on " .. who.Name) or "",
					ZIndex = 5,
				}),
				"Caption"
			).TextColor3 =
				D.Cyan
			card.Activated:Connect(function()
				chosen = nil
				chosenSidekick = chosenSidekick ~= row.Entry and row.Entry or nil
				setStatus(
					chosenSidekick and "Tap a member's altar to equip" or (dirty() and "Unsaved changes" or "Ready")
				)
				render()
			end)
		end
	end
	markRoster()
	applySearch()
end

function render()
	for n, a in altars do
		local id = draft[n]
		local spec = id and CharacterCatalog.Get(id)
		local isSelected = selected == n
		a.Button:SetAttribute("Selected", isSelected)
		for _, part in { a.Portrait, a.Name, a.Info } do
			part.Visible = spec ~= nil
		end
		a.Plus.Visible, a.Add.Visible = spec == nil, spec == nil
		a.Remove.Visible = isSelected and spec ~= nil
		a.SlotLabel.TextColor3 = isSelected and D.Cyan or D.Cream
		a.SlotLabel.Edge.Color = isSelected and D.Cyan or D.Gold
		paintEdges(n)
		if a.ShownId ~= id or not a.View:FindFirstChild("Figure") and spec then
			figureOn(a, spec)
		end
		local gearFrame = a.Button:FindFirstChild("Gear")
		if gearFrame then
			gearFrame:Destroy()
		end
		if spec then
			a.Portrait.Image = Components.PortraitImage(spec) or ""
			a.Name.Text = spec.Name
			a.Info.Text = string.format("%s · %s", spec.Rarity, HudFormat.RateText(RaceConfig.Cruise(spec)))
			RosterCard.Gear(a.Button, id, player, 0, a.GearSize or g.px(22)).Position = a.GearPos or UDim2.new()
		end
		a.ShownId = id
	end
	local n = filled()
	for i = 1, SLOTS do
		dots["Dot" .. i].BackgroundTransparency = draft[i] and 0 or 0.7
	end
	count.Text = string.format("%d / %d Slots Filled", n, SLOTS)
	UiMotion.Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(n / SLOTS, 1) }):Play()
	local changed = dirty()
	deploy:SetAttribute("Enabled", changed and n > 0)
	deploy.BackgroundColor3 = (changed and n > 0) and D.Cyan or D.Cyan:Lerp(D.Ink, 0.6)
	quick:SetAttribute("Enabled", n < SLOTS)
	quick.BackgroundColor3 = n < SLOTS and D.Wood or D.Wood:Lerp(D.Ink, 0.6)
	if status.Text == "Ready" or status.Text == "Unsaved changes" or status.Text == "Deployed" then
		setStatus(changed and "Unsaved changes" or "Ready", changed and D.Gold or D.Cyan)
	end
	for i, t in tabButtons do
		local active = (i == 1) == (tab == "Characters")
		t:SetAttribute("Active", active)
		t.Underline.Visible = active
		t.BackgroundColor3 = active and PURPLE or D.Ink
		t.TextTransparency = active and 0 or 0.3
	end
	drawBonus()
	drawRoster()
end

for n, a in altars do
	a.Button.Activated:Connect(function()
		if selected == n and not chosen and not chosenSidekick then
			selected = nil -- a second tap lets go of it
			render()
			return
		end
		UiFeedback.Play("Toggle", a.Button)
		selectSlot(n)
	end)
	a.Remove.Activated:Connect(function()
		place(n, nil)
		selected = nil
		render()
	end)
end
quick.Activated:Connect(function()
	if busy or filled() >= SLOTS then
		return
	end
	busy = true
	local ok, done, ids = pcall(function()
		return remotes:WaitForChild("TeamQuickPick"):InvokeServer(list(draft))
	end)
	busy = false
	if not (ok and done and type(ids) == "table") then
		setStatus(ok and tostring(ids or "Try again") or "Connection error", D.Sakura)
		UiFeedback.Play("Denied", quick)
		return
	end
	-- Keep each member on its altar; the new picks fill the empty altars left to right.
	local new = {}
	for _, id in ids do
		if not slotOf(id) then
			table.insert(new, id)
		end
	end
	local delay = 0
	for i = 1, SIZE do
		if not draft[i] and #new > 0 then
			draft[i] = table.remove(new, 1)
			pulseEdges(i, delay)
			local slot = i
			task.delay(delay, function()
				UiMotion.Pop(altars[slot].Portrait, 0.08)
			end)
			delay += 0.15
		end
	end
	selected, chosen = nil, nil
	UiFeedback.Play("Equip", quick)
	render()
end)
deploy.Activated:Connect(function()
	if deploy:GetAttribute("Enabled") then
		deployDraft(true)
	else
		UiFeedback.Play("Denied", deploy)
	end
end)
confirmDeploy.Activated:Connect(function()
	deployDraft(true)
end)
confirmDiscard.Activated:Connect(function()
	confirm.Visible = false
	draft = saved()
	PanelSwitch.ForceClose("Team")
end)
bonusButton.Activated:Connect(function()
	popover.Visible = not popover.Visible
	if popover.Visible then
		drawBonus()
		UiMotion.Pop(popover, 0.04)
	end
end)
for i, t in tabButtons do
	t.Activated:Connect(function()
		tab = i == 1 and "Characters" or "Sidekicks"
		chosen, chosenSidekick = nil, nil
		render()
	end)
end
close.Activated:Connect(function()
	PanelSwitch.Close("Team")
end)
sortButton.Activated:Connect(function()
	sortMode = RosterCard.Sorts[table.find(RosterCard.Sorts, sortMode) % #RosterCard.Sorts + 1]
	sortButton.Text = "Sort: " .. sortMode
	render()
end)
search:GetPropertyChangedSignal("Text"):Connect(applySearch)

-- An undeployed draft asks before the page closes (4.45).
PanelSwitch.SetCloseGuard("Team", function()
	if dirty() then
		confirm.Visible = true
		popover.Visible = false
		UiMotion.Pop(confirm, 0.04)
		return true
	end
	return false
end)

panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		openCount += 1
		rosterKey = nil
		draft, selected, chosen, chosenSidekick = saved(), nil, nil, nil
		tab = "Characters"
		confirm.Visible, popover.Visible = false, false
		setStatus("Ready")
		render()
	else
		UiTooltip.Hide()
		confirm.Visible = false
	end
end)
player.AttributeChanged:Connect(function(attr)
	if
		panel.Visible
		and (
			attr == "Team"
			or attr == "TeamBonus"
			or attr == "SidekickGear"
			or attr == "SidekickBag"
			or attr == "RelicGear"
			or string.match(attr, "^TeamStamina%d$")
		)
	then
		render()
	end
end)
task.spawn(function()
	local data = player:WaitForChild("GachaData")
	local function changed()
		if panel.Visible then
			render()
		end
	end
	data.ChildAdded:Connect(changed)
	data.ChildRemoved:Connect(changed)
	local models = ReplicatedStorage:WaitForChild("CharacterModels")
	if models:GetAttribute("Ready") ~= true then
		models:GetAttributeChangedSignal("Ready"):Wait()
	end
	changed()
end)

-- The 3D member standing on its altar (owner 2026-11-17: the mockup's models; an exception to the portrait rule for
-- Team Setup only), turned a little toward the camera, feet on the deck.
function figureOn(a, spec)
	local old = a.View:FindFirstChild("Figure")
	if old then
		old:Destroy()
	end
	a.Column.Color = spec and D.Sakura or D.Cyan
	if not spec then
		return
	end
	local ok, rig = pcall(function()
		return require(shared:WaitForChild("RunnerFactory")).build(spec.Id)
	end)
	if not ok or not rig then
		return
	end
	rig.Name = "Figure"
	local label = rig:FindFirstChild("NameLabel")
	if label then
		label:Destroy()
	end
	rig:PivotTo(CFrame.Angles(0, math.pi - 0.3, 0))
	local box, extents = rig:GetBoundingBox()
	rig:PivotTo(rig:GetPivot() + Vector3.new(-box.X, a.Deck - (box.Y - extents.Y / 2), -box.Z))
	rig.Parent = a.View
end

panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
UiTheme.Corner(search, 4)
PanelSwitch.Register("Team", panel, D.Cyan)
layout()
