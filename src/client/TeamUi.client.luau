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
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
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
local CARD_W, CARD_H = 104, 116 -- roster cards, design units

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
	button.AutoButtonColor = false
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	UiTheme.Corner(button, 4)
	local stroke = button:FindFirstChild("Edge") or make("UIStroke", "Edge", button, {})
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness, stroke.Color = D.Stroke, D.Gold
	return button
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
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(720, 420),
	Visible = false,
	Active = true,
})

local header = make("Frame", "Header", panel, { BackgroundTransparency = 1 })
caption("Title", header, { Text = "Team Setup" })
make("ImageLabel", "Icon", header, { BackgroundTransparency = 1, Image = Icons.Team.Image })
local close = make("TextButton", "Close", header, { Text = "", AutoButtonColor = false })
caption("X", close, { Size = UDim2.fromScale(1, 1), Text = "X" })
local bonusButton = flat(make("TextButton", "BonusButton", header, { Text = "Team Bonus", ZIndex = 10 }), D.Burgundy)

local g -- the frame's units (PanelFrame.Attach, below)

-- State: the draft (slot -> id or nil), the picked altar, the picked card (character id or Sidekick entry).
local draft = {}
local selected = nil
local chosen = nil
local chosenSidekick = nil
local tab = "Characters"
local busy = false
local render -- set below

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

-- Backdrop: warm dojo wood behind the content (the frame's chrome stays the game-wide one, 4.42).
local backdrop = make("Frame", "Backdrop", panel, { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
make("UIGradient", "Wood", backdrop, {
	Rotation = 90,
	Color = ColorSequence.new(D.Burgundy, D.Ink),
})
UiTheme.Corner(backdrop, 6)
for k = 1, 3 do -- faint shoji lines
	make("Frame", "Shoji" .. k, backdrop, {
		Position = UDim2.fromScale(k / 4, 0),
		Size = UDim2.new(0, 1, 0.55, 0),
		BackgroundColor3 = D.Gold,
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
	})
end

-- Top centre: one dot per altar.
local dots = make("Frame", "Dots", panel, { BackgroundTransparency = 1 })
make("UIListLayout", "Layout", dots, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 10),
})
for n = 1, SLOTS do
	local dot = make("Frame", "Dot" .. n, dots, { BackgroundColor3 = D.Cyan, LayoutOrder = n })
	UiTheme.Corner(dot, 999)
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
		Ambient = Color3.fromRGB(150, 120, 120),
		LightColor = Color3.fromRGB(255, 230, 210),
		LightDirection = Vector3.new(-1, -2, -1),
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
	local core = SpawnArea.Octagon(model, "Core", 3, 0.2, CFrame.new(0, #TIERS * TIER_H + 0.1, 0), D.Sakura)
	local camera = make("Camera", "Camera", view, { FieldOfView = 30 })
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 14, 34), Vector3.new(0, 1.2, 0))
	view.CurrentCamera = camera
	local plus = caption("Plus", b, { Text = "+", TextColor3 = D.Cyan, ZIndex = 4 })
	local add = caption("Add", b, { Text = "Add Character", TextColor3 = D.Cream, ZIndex = 4 })
	local remove = flat(make("TextButton", "Remove", b, { Text = "Remove", Visible = false, ZIndex = 6 }), D.Burgundy)
	altars[n] = {
		Button = b,
		Edges = edges,
		Core = core,
		SlotLabel = caption("SlotLabel", b, { Text = "Slot " .. n, TextColor3 = D.Gold, ZIndex = 4 }),
		Portrait = make("ImageLabel", "Portrait", b, {
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
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
local teamName =
	caption("TeamName", footer, { Text = "Team 1", TextColor3 = D.Cream, TextXAlignment = Enum.TextXAlignment.Left })
local status =
	caption("Status", footer, { Text = "Ready", TextColor3 = D.Cyan, TextXAlignment = Enum.TextXAlignment.Left })
local count = caption("Count", footer, { Text = "", TextColor3 = D.Cream })
local progress = make("Frame", "Progress", footer, { BackgroundColor3 = D.Ink, BorderSizePixel = 0 })
local fill = make("Frame", "Fill", progress, { BackgroundColor3 = D.Cyan, BorderSizePixel = 0 })
local quick = flat(make("TextButton", "QuickSetup", panel, { Text = "Quick Setup", TextColor3 = D.Cream }), D.Wood)
local deploy = flat(make("TextButton", "Deploy", panel, { Text = "Deploy", TextColor3 = D.Ink }), D.Cyan)

-- Roster tray: Characters / Sidekicks tabs, Sort and Search, one row of cards.
local tray = make("Frame", "Tray", panel, { BackgroundColor3 = D.Ink, BackgroundTransparency = 0.25 })
UiTheme.Corner(tray, 4)
make("UIStroke", "Edge", tray, { Color = D.Cyan, Thickness = 1, Transparency = 0.4 })
local tabs = make("Frame", "Tabs", tray, { BackgroundTransparency = 1 })
local tabButtons = {}
for i, name in { "Characters", "Sidekicks" } do
	local t = make("TextButton", name, tabs, { Text = name, AutoButtonColor = false, BackgroundTransparency = 1 })
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

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or D.Cyan
end

-- Layout in the frame's design units: header row, altars, footer row, tray.
local function layout()
	local c = g.Content
	local top, bottom = c.TabsY, c.Y + c.H
	local h = bottom - top
	local small = g.Small
	local headerH = small and 26 or 34
	local footerH = small and 30 or 40
	local trayH = small and 92 or 150
	local altarsY = top + headerH + 4
	local altarsH = h - headerH - footerH - trayH - 16
	g.Place(backdrop, c.X - 8, top - 6, c.W + 16, h + 12)
	g.Place(dots, c.X + c.W / 2 - 60, top, 120, headerH * 0.5)
	for _, dot in dots:GetChildren() do
		if dot:IsA("Frame") then
			dot.Size = g.at(headerH * 0.4, headerH * 0.4)
		end
	end
	g.Place(bonusButton, c.X + c.W - (small and 120 or 170), top, small and 120 or 170, headerH)
	g.Role(bonusButton, "Body").TextColor3 = D.Cream
	g.Place(altarsFrame, c.X, altarsY, c.W, altarsH)
	local w = c.W / SLOTS
	for n, a in altars do
		g.Place(a.Button, (n - 1) * w + w * 0.08, 0, w * 0.84, altarsH)
		local aw = w * 0.84
		a.SlotLabel.Position, a.SlotLabel.Size = g.at(0, 0), g.at(aw, altarsH * 0.1)
		g.Role(a.SlotLabel, "Body").TextColor3 = D.Gold
		a.Portrait.Position, a.Portrait.Size = g.at(aw * 0.25, altarsH * 0.08), g.at(aw * 0.5, altarsH * 0.5)
		local pedestal = a.Button.Pedestal
		pedestal.Position, pedestal.Size = g.at(0, altarsH * 0.42), g.at(aw, altarsH * 0.36)
		a.Plus.Position, a.Plus.Size = g.at(aw * 0.35, altarsH * 0.2), g.at(aw * 0.3, altarsH * 0.22)
		a.Add.Position, a.Add.Size = g.at(0, altarsH * 0.78), g.at(aw, altarsH * 0.1)
		g.Role(a.Add, "Body").TextColor3 = D.Cream
		a.Name.Position, a.Name.Size = g.at(0, altarsH * 0.78), g.at(aw, altarsH * 0.12)
		g.Role(a.Name, "Item").TextColor3 = D.Cream
		a.Info.Position, a.Info.Size = g.at(0, altarsH * 0.9), g.at(aw, altarsH * 0.09)
		g.Role(a.Info, "Caption").TextColor3 = D.Gold
		-- The icons fit the portrait's top-right quarter; Remove sits under them.
		a.GearPos = g.at(aw * 0.75, altarsH * 0.08)
		a.GearSize = math.max(8, math.min(g.px(22), math.floor((g.px(aw * 0.25) - 6) / 2), g.px(altarsH * 0.2)))
		a.Remove.Position, a.Remove.Size = g.at(aw - 84, altarsH * 0.34), g.at(84, small and 22 or 28)
		g.Role(a.Remove, "Caption").TextColor3 = D.Cream
	end
	local fy = altarsY + altarsH + 4
	g.Place(footer, c.X, fy, c.W, footerH)
	teamName.Position, teamName.Size = g.at(0, 0), g.at(180, footerH * 0.55)
	g.Role(teamName, "Item").TextColor3 = D.Cream
	status.Position, status.Size = g.at(0, footerH * 0.55), g.at(220, footerH * 0.45)
	local statusColor = status.TextColor3
	g.Role(status, "Caption").TextColor3 = statusColor
	local countW = small and 120 or 260
	count.Position, count.Size = g.at(c.W / 2 - countW / 2 - (small and 40 or 0), 0), g.at(countW, footerH * 0.65)
	g.Role(count, "Body").TextColor3 = D.Cream
	progress.Position, progress.Size =
		g.at(c.W / 2 - countW / 2 - (small and 40 or 0) + 10, footerH * 0.72), g.at(countW - 20, 4)
	local bw = small and 110 or 160
	g.Place(quick, c.X + c.W - 2 * bw - 10, fy + 2, bw, footerH - 4)
	g.Place(deploy, c.X + c.W - bw, fy + 2, bw, footerH - 4)
	g.Role(quick, "Body").TextColor3 = D.Cream
	g.Role(deploy, "Body").TextColor3 = D.Ink
	local ty = fy + footerH + 8
	g.Place(tray, c.X, ty, c.W, bottom - ty)
	local tabH = small and 22 or 30
	local tabW = small and 84 or 122
	tabs.Position, tabs.Size = g.at(8, 4), g.at(2 * tabW + 8, tabH)
	for i, t in tabButtons do
		t.Position, t.Size = g.at((i - 1) * (tabW + 8), 0), g.at(tabW, tabH)
		g.Role(t, "Body").TextColor3 = D.Cream
	end
	local sortW, searchW = small and 100 or 160, small and 120 or 210
	sortButton.Position, sortButton.Size = g.at(c.W - 8 - searchW - 10 - sortW, 4), g.at(sortW, tabH)
	g.Role(sortButton, "Caption").TextColor3 = D.Cream
	search.Position, search.Size = g.at(c.W - 8 - searchW, 4), g.at(searchW, tabH)
	g.Role(search, "Caption").TextColor3 = D.Cream
	roster.Position, roster.Size = g.at(6, tabH + 8), UDim2.new(1, -g.px(12), 1, -g.px(tabH + 12))
	rosterLayout.Padding = UDim.new(0, g.px(8))
	popover.Position, popover.Size = g.at(c.X + c.W - 260, top + headerH + 4), g.at(260, 120)
	bonusName.Position, bonusName.Size = g.at(10, 8), g.at(240, 26)
	bonusEffect.Position, bonusEffect.Size = g.at(10, 38), g.at(240, 44)
	bonusTotal.Position, bonusTotal.Size = g.at(10, 88), g.at(240, 22)
	confirm.Position, confirm.Size = g.at(c.X + c.W / 2 - 180, top + h / 2 - 70), g.at(360, 140)
	confirmText.Position, confirmText.Size = g.at(20, 14), g.at(320, 40)
	confirmDeploy.Position, confirmDeploy.Size = g.at(30, 80), g.at(140, 40)
	confirmDiscard.Position, confirmDiscard.Size = g.at(190, 80), g.at(140, 40)
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
		a.SlotLabel.TextColor3 = isSelected and D.Cyan or D.Gold
		paintEdges(n)
		local model = a.Portrait:FindFirstChild("Model")
		if model and a.ShownId ~= id then
			model:Destroy()
		end
		local gearFrame = a.Button:FindFirstChild("Gear")
		if gearFrame then
			gearFrame:Destroy()
		end
		if spec then
			local image = Components.PortraitImage(spec)
			a.Portrait.Image = image or ""
			if not image and not a.Portrait:FindFirstChild("Model") then
				Components.RunnerArt(a.Portrait, "Model", spec, UDim2.new(), UDim2.fromScale(1, 1), true)
			end
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
		t.TextTransparency = active and 0 or 0.4
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

UiTheme.Apply(root)
-- The game-wide 1200 x 620 frame, in the panels' band (design doc 4.42).
g = PanelFrame.Attach(panel, {
	Theme = "Backpack",
	Title = "Team Setup",
	Icon = Icons.Team.Image,
	TitleObject = header.Title,
	Close = close,
}).Frame
PanelFrame.CloseOnOutsideClick(panel, function()
	PanelSwitch.Close("Team")
end)
UiTheme.Corner(search, 4) -- after UiTheme.Apply, which snaps corners to its own radii
PanelSwitch.Register("Team", panel, D.Cyan) -- after g exists: an open renders at once
g.OnLayout(layout)
