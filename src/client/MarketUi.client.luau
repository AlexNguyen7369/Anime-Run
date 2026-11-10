--!nonstrict
-- Market (docs/HUD_LAYOUT_SPEC.md, Market pill): the Index frame with art tabs, a tile grid and a detail card.
-- Buying and equipping go to the server (MarketPurchase / MarketEquip); the client only shows. An owned aura or
-- trail shows the team slot buttons (SlotPicker): each team slot has its own. BUY stays below MAX_COPIES copies.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Market = require(shared:WaitForChild("MarketConfig"))
local Format = require(shared:WaitForChild("HudFormat"))
local RaceConfig = require(shared:WaitForChild("RaceConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local Ui = script.Parent:WaitForChild("RollToast"):WaitForChild("Ui")
local Icons = require(Ui.HudIcons)
local PotionIcons = require(Ui.PotionIcons)
local MarketArt = require(script.Parent:WaitForChild("MarketArt"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local SlotPicker = require(script.Parent:WaitForChild("SlotPicker"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))

local OUTLINE = UiTheme.Outline
local PALETTE = UiTheme.Palette
local TILE_BLUE = PALETTE.Tile
local TILE_GREEN = PALETTE.Money
local KINDS = { { "Trail", "Trails" }, { "Aura", "Auras" }, { "Potion", "Potions" } }
-- Layout in the Index frame's design units (design doc 4.42, Client/AnimeSkin.IndexFrame); layout() places all.
local TILE_MIN = 130 -- narrowest tile before the grid drops a column
local BUY_W = 120
local BAR = 6 -- the grid's scrollbar

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function corner(parent, radius)
	make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, radius) })
end
local function stroke(parent, color, thickness)
	return make("UIStroke", "Stroke", parent, {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end
local frame -- the Index frame's g (PanelFrame.Attach, below)
-- Every text keeps one of the frame's roles (design doc 4.42); layout() sizes them in units.
local roles = {}
local function caption(name, parent, role, props)
	props.BackgroundTransparency = 1
	local label = make("TextLabel", name, parent, props)
	roles[label] = role
	if frame then
		frame.Role(label, role)
	end
	return label
end
local function cascade(tiles)
	UiMotion.Cascade(tiles, "Stroke")
end

local root = make(
	"ScreenGui",
	"MarketUi",
	gui,
	{ ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }
)
local backdrop = make("Frame", "Backdrop", root, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = PALETTE.Scrim,
	BackgroundTransparency = 1, -- the world dim is HudChrome/PanelDim, below the HUD
	Visible = false,
})
PanelSwitch.Register("Market", backdrop)
local panel = make("Frame", "Panel", backdrop, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 124),
	Size = UDim2.fromOffset(820, 440),
	Active = true,
})
corner(panel, 16)
stroke(panel, OUTLINE, 4)

-- Header: icon, title and close; the Index frame (PanelFrame.Attach) places and styles them.
local header = make("Frame", "Header", panel, { BackgroundColor3 = Color3.new(1, 1, 1) })
make("ImageLabel", "Icon", header, { BackgroundTransparency = 1, Image = Icons.Market.Image })
make("TextLabel", "Title", header, { Text = "Market" })
local close = make("TextButton", "Close", header, { Text = "", AutoButtonColor = false })
make("TextLabel", "X", close, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "X" })

-- The kinds as the frame's art tabs in the tabs row (g.Tabs places them); the rail is a clear anchor over the panel.
local rail = make("Frame", "Tabs", panel, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8 })

-- Potions retain their bottle artwork; cosmetics share the authored vector renderer.
local function swatch(parent, item, kind, pos, size)
	if kind == "Potion" then
		return make("ImageLabel", "Art", parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = size,
			BackgroundTransparency = 1,
			Image = PotionIcons[item.Category] or "",
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		})
	end
	return MarketArt.Draw(parent, item, pos, size)
end

local tabs = {}
local tabButtons = {}
for order, entry in KINDS do
	local kind, label = entry[1], entry[2]
	local b = make("TextButton", kind .. "Tab", rail, {
		LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = false,
	})
	corner(b, 12)
	UiTheme.Gradient(b, PALETTE.TabIdle, PALETTE.TabIdleDeep)
	local edge = stroke(b, OUTLINE, 4)
	swatch(b, Market.Items[kind][1], kind, UDim2.new(), UDim2.new()) -- a small icon left of the caption
	caption("Label", b, "Tab", { Text = label })
	tabs[kind] = { Button = b, Edge = edge }
	tabButtons[order] = b
end

-- Tile grid on the left of the content; layout() sizes the tiles to fill it in whole rows.
local grid = make("ScrollingFrame", "Grid", panel, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, -- the bar sits beside the tiles, not on them
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 3,
})
make("UIGridLayout", "Layout", grid, { SortOrder = Enum.SortOrder.LayoutOrder })

-- Detail card on the right (as the Quests detail): rarity line, name, preview, price + BUY, then the slot buttons
-- (an owned aura / trail) or the description.
local detail = make("Frame", "Detail", panel, {
	BackgroundColor3 = Color3.new(1, 1, 1),
	ZIndex = 3,
})
corner(detail, 12)
stroke(detail, OUTLINE, 3)
make("UIGradient", "Gradient", detail, {
	Color = ColorSequence.new(PALETTE.Row, PALETTE.PanelDeep),
	Rotation = 90,
})
AnimeSkin.Card(detail, AnimeSkin.Tint.Default) -- the Quests detail card (design doc 4.42)
local rarity = caption("Rarity", detail, "Caption", { Text = "", TextXAlignment = Enum.TextXAlignment.Left })
local nameLabel = caption("Name", detail, "Item", { Text = "", TextXAlignment = Enum.TextXAlignment.Left })
local viewport = make("ViewportFrame", "Preview", detail, {
	BackgroundColor3 = PALETTE.TileDeep,
	BackgroundTransparency = 0.5,
	Ambient = Color3.fromRGB(130, 140, 190),
	LightColor = Color3.new(1, 1, 1),
})
corner(viewport, 4)
-- The bottom band holds the slot buttons on an owned item and the description otherwise, so BUY never moves when the
-- first copy arrives (a double tap cannot land on a slot). Above it: price + BUY; the reply sits on the preview's
-- bottom edge.
local priceRow = make("Frame", "Price", detail, {
	BackgroundColor3 = PALETTE.PanelDeep,
	BackgroundTransparency = 0.3,
})
corner(priceRow, 4)
local priceText = caption("Value", priceRow, "Body", { -- scaled: "$1.2m • Owned x2" stays on the row
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
})
local description = caption("Description", detail, "Caption", {
	Text = "",
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})
local action = make("TextButton", "Action", detail, {
	Text = "",
	BackgroundColor3 = TILE_GREEN,
	AutoButtonColor = false,
})
corner(action, 8)
stroke(action, OUTLINE, 3)
UiTheme.Gradient(action, Color3.new(1, 1, 1), PALETTE.SoftText) -- depth on whatever colour it shows
AnimeSkin.Button(action, "Go") -- the Index EQUIP look; drops the gradient above
local actionLabel = caption("Label", action, "Item", { Size = UDim2.fromScale(1, 1), Text = "BUY" })
local pickSlot -- set below: equips the shown item on a team slot
local slots = SlotPicker.new("Slots", detail, { Visible = false }, function(...)
	pickSlot(...)
end)
-- The server's reply, on the preview's bottom edge just above BUY.
local status = caption("Status", detail, "Body", {
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})
-- A purchase / equip answer slides in from the bottom edge.
local statusHome = UDim2.new() -- set by layout(): the status row of the view on screen
local function notify(text)
	status.Text = text
	status.Position = statusHome
	UiMotion.SlideIn(status, Vector2.new(0, frame and frame.px(14) or 14))
end

local function preview(item, kind)
	viewport:ClearAllChildren()
	corner(viewport, 10)
	local world = make("WorldModel", "World", viewport, {})
	local camera = make("Camera", "Camera", viewport, {})
	camera.CFrame = CFrame.lookAt(Vector3.new(3.3, 2.5, 4), Vector3.new(0, 1.3, 0.8))
	viewport.CurrentCamera = camera
	if kind == "Potion" then
		local bottle = make("Part", "Bottle", world, {
			Anchored = true,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			Position = Vector3.new(0, 1.6, 0),
			Color = item.Color,
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
		make("Part", "Cork", world, {
			Anchored = true,
			Size = Vector3.new(0.9, 0.9, 0.9),
			Position = bottle.Position + Vector3.new(0, 1.8, 0),
			Color = Color3.fromRGB(140, 90, 50),
		})
		return
	end
	make("Part", "Body", world, {
		Anchored = true,
		Size = Vector3.new(4.8, 0.8, 2.5),
		Position = Vector3.new(0, 1.2, 0),
		Color = Color3.fromRGB(77, 151, 205),
		Material = Enum.Material.SmoothPlastic,
	})
	if kind == "Aura" then
		make("Part", "Orb", world, {
			Anchored = true,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4.8, 2.6, 3.4),
			Position = Vector3.new(0, 1.8, 0),
			Color = item.Color,
			Material = Enum.Material.Neon,
			Transparency = 0.42,
		})
		make("Part", "Ring", world, {
			Anchored = true,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 5.2, 5.2),
			CFrame = CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = item.Accent or item.Color,
			Material = Enum.Material.Neon,
		})
	else
		for index = 1, 4 do
			make("Part", "Spark" .. index, world, {
				Anchored = true,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.35, 0.35, 0.35),
				Position = Vector3.new(0, 0.75, index * 1.15),
				Color = index % 2 == 0 and (item.Accent or item.Color) or item.Color,
				Material = Enum.Material.Neon,
			})
		end
	end
end

-- Phones (viewport height <= 500, owner 2026-10-28, docs/HUD_LAYOUT_SPEC.md section 6): the grid only; tapping an
-- item swaps the grid for the detail view, whose Back button swaps back. Desktop shows both side by side.
local back = make("TextButton", "Back", detail, {
	BackgroundColor3 = PALETTE.SlotHere,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
})
corner(back, 8)
stroke(back, OUTLINE, 3)
AnimeSkin.Button(back, "Idle")
caption("Label", back, "Item", { Size = UDim2.fromScale(1, 1), Text = "BACK" })

local tileUnits = TILE_MIN -- a tile's side in units (layout() sets it)
-- Inside a tile, 12 padding: count / price top-left, the name at the bottom, the swatch between.
local function layoutTile(g, b)
	local P = g.px
	local art, badge, name = b:FindFirstChild("Art"), b:FindFirstChild("Badge"), b:FindFirstChild("Name")
	badge.Position, badge.Size = g.at(12, 12), UDim2.new(1, -P(24), 0, P(28))
	name.AnchorPoint = Vector2.new(0, 1)
	name.Position, name.Size = UDim2.new(0, P(12), 1, -P(12)), UDim2.new(1, -P(24), 0, P(34))
	local side = math.max(16, tileUnits - 2 * 12 - 28 - 34 - 2 * 4)
	art.Position, art.Size = UDim2.new(0.5, 0, 0, P(12 + 28 + 4 + side / 2)), g.at(side, side)
end
local showingDetail = false
-- An owned aura / trail: the slot buttons take the description's band, in both views.
local function fitDetail()
	description.Visible = not slots.Frame.Visible
end
-- Detail rows in units inside a card of w x h; 24 clear of its cut corners, 12 from top and bottom.
local function layoutDetail(g, w, h)
	local P = g.px
	local inner = w - 48
	priceText.Position, priceText.Size = g.at(8, 0), UDim2.new(1, -P(16), 1, 0)
	if g.Small then
		-- Phone: the preview on the left, the rows and BACK / action on the right.
		local previewW = math.floor(w * 0.4) - 24
		local x = 24 + previewW + 12
		local cw = w - x - 24
		local half = (cw - 8) / 2
		g.Place(viewport, 24, 12, previewW, h - 24)
		g.Place(rarity, x, 12, cw, 22)
		g.Place(nameLabel, x, 34, cw, 30)
		g.Place(priceRow, x, 68, cw, 24)
		g.Place(description, x, 96, cw, 38)
		g.Place(slots.Frame, x, 96, cw, 38)
		g.Place(back, x, h - 56, half, 44)
		g.Place(action, x + half + 8, h - 56, half, 44)
		g.Place(status, 32, h - 48, previewW - 16, 28)
	else
		local previewH = h - 88 - 12 - 44 - 12 - 44 - 12
		g.Place(rarity, 24, 12, inner, 22)
		g.Place(nameLabel, 24, 42, inner, 34)
		g.Place(viewport, 24, 88, inner, previewH)
		g.Place(priceRow, 24, h - 112, inner - 8 - BUY_W, 44)
		g.Place(action, 24 + inner - BUY_W, h - 112, BUY_W, 44)
		g.Place(description, 24, h - 56, inner, 44)
		g.Place(slots.Frame, 24, h - 56, inner, 44)
		g.Place(status, 32, 88 + previewH - 8 - 28, inner - 16, 28)
	end
	slots:Layout(g)
	statusHome = status.Position
end
-- The content: the grid on the left 56%, 12 gap, the detail card on the right (phones: one at a time, full width).
local function layout(g)
	local P, c = g.px, g.Content
	for _, b in tabButtons do
		local icon, label = b:FindFirstChild("Art"), b:FindFirstChild("Label")
		icon.Position, icon.Size, icon.ZIndex = g.at(22, 20), g.at(28, 28), 3
		label.Position, label.Size = g.at(40, 0), UDim2.new(1, -P(48), 1, 0)
	end
	local listW = g.Small and c.W or math.floor(c.W * 0.56)
	local columns = math.max(1, math.floor((listW - BAR + 12) / (TILE_MIN + 12)))
	tileUnits = (listW - BAR - 12 * (columns - 1)) / columns
	local rows = math.max(1, math.floor((c.H + 12) / (tileUnits + 12)))
	g.Place(grid, c.X, c.Y, listW, rows * tileUnits + (rows - 1) * 12) -- whole rows only
	grid.ScrollBarThickness = P(BAR)
	grid.Layout.CellPadding = UDim2.fromOffset(P(12), P(12))
	grid.Layout.CellSize = UDim2.new(1 / columns, -math.ceil(P(12) * (columns - 1) / columns), 0, P(tileUnits))
	for _, b in grid:GetChildren() do
		if b:IsA("TextButton") then
			layoutTile(g, b)
		end
	end
	if g.Small then
		g.Place(detail, c.X, c.Y, c.W, c.H)
		layoutDetail(g, c.W, c.H)
	else
		local detailW = c.W - listW - 12
		g.Place(detail, c.X + listW + 12, c.Y, detailW, c.H)
		layoutDetail(g, detailW, c.H)
	end
	for label, role in roles do
		if label.Parent then
			g.Role(label, role)
		else
			roles[label] = nil
		end
	end
	fitDetail()
	grid.Visible = not (g.Small and showingDetail)
	detail.Visible = not g.Small or showingDetail
	back.Visible = g.Small
end
local function applyLayout()
	if frame then
		layout(frame)
	end
end
back.Activated:Connect(function()
	showingDetail = false
	applyLayout()
end)

local selectedKind = "Trail"
local selected = nil -- item id
local busy = false
local entering = false -- the next render is the panel opening: cascade its tiles
local render

local function owned(kind, id)
	if kind == "Potion" then
		return (player:GetAttribute("Boost_" .. id) or 0) > 0
	end
	return Market.Copies(player, kind, id) > 0
end

-- Grey when short of Money; display only, the server still decides and answers a press.
local money = player:WaitForChild("leaderstats"):WaitForChild("Money")
local function paintBuy()
	local item = selected and Market.Get(selectedKind, selected)
	AnimeSkin.Button(action, (item and item.Price > money.Value) and "Idle" or "Go")
end
money.Changed:Connect(paintBuy)

local function showDetail(item)
	local kind = selectedKind
	local copies = kind ~= "Potion" and Market.Copies(player, kind, item.Id) or 0
	local cosmetic = copies > 0 -- owned aura / trail: pick its team slot
	rarity.Text = kind == "Potion" and (item.Category .. " Potion")
		or string.format(
			"%s  •  %s cruise speed on its slot",
			kind,
			Format.Multi(RaceConfig.ItemCruiseMulti(item.SpeedMulti))
		)
	nameLabel.Text = item.Name
	priceText.Text = kind == "Potion"
			and string.format(
				"%s   •   Owned x%s",
				Format.MoneyText(item.Price),
				Format.Short(player:GetAttribute("Boost_" .. item.Id) or 0)
			)
		or (
			copies >= Market.MAX_COPIES and string.format("Owned x%d (max)", copies)
			or copies > 0 and string.format("%s   •   Owned x%d", Format.MoneyText(item.Price), copies)
			or Format.MoneyText(item.Price)
		)
	description.Text = item.Description
	actionLabel.Text = "BUY"
	action.Visible = copies < Market.MAX_COPIES
	paintBuy()
	slots.Frame.Visible = cosmetic
	fitDetail()
	if cosmetic then
		slots:Update(kind, item.Id)
	end
	preview(item, kind)
end

action.Activated:Connect(function()
	local item = selected and Market.Get(selectedKind, selected)
	if not item or busy then
		return
	end
	local kind = selectedKind
	if kind ~= "Potion" and Market.Copies(player, kind, item.Id) >= Market.MAX_COPIES then
		return
	end
	busy = true
	local ok, done, message = pcall(function()
		return remotes:WaitForChild("MarketPurchase"):InvokeServer(kind, item.Id)
	end)
	busy = false
	notify(ok and tostring(message or (done and "Done" or "Try again")) or "Connection error")
	render()
	if ok and done then
		local counter = UiFeedback.MoneyCounter() -- the cost flies out of the Money counter to BUY
		UiFeedback.Play("MarketBought", action, { Origin = counter, Target = counter and action })
	else
		UiFeedback.Play("Denied", action)
	end
end)

function pickSlot(slot, id)
	local kind = selectedKind
	if busy or kind == "Potion" or not selected then
		return
	end
	busy = true
	local ok, done, message = pcall(function()
		return remotes:WaitForChild("MarketEquip"):InvokeServer(kind, id, slot)
	end)
	busy = false
	notify(ok and tostring(message or (done and "Done" or "Try again")) or "Connection error")
	render()
	UiFeedback.Play((ok and done) and "Equip" or "Denied", slots.Buttons[slot].Button)
end

function render()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for kind, refs in tabs do
		UiMotion.Mark(refs.Edge, { Color = kind == selectedKind and Color3.new(1, 1, 1) or OUTLINE })
		refs.Lit(kind == selectedKind)
	end
	local items = Market.Items[selectedKind]
	if not (selected and Market.Get(selectedKind, selected)) then
		selected = items[1] and items[1].Id
	end
	local shownTiles = {}
	for order, item in items do
		local b = make("TextButton", selectedKind .. "_" .. item.Id, grid, {
			LayoutOrder = order,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = "",
			AutoButtonColor = false,
		})
		table.insert(shownTiles, b)
		corner(b, 12)
		UiTheme.Gradient(b, PALETTE.Row, PALETTE.PanelDeep)
		local onSlot = selectedKind ~= "Potion" and SlotPicker.Equipped(selectedKind, item.Id)
		stroke(b, item.Id == selected and Color3.new(1, 1, 1) or onSlot and TILE_GREEN or TILE_BLUE, 4)
		-- The card art takes the edge's colours (the Stroke stays, hidden, for the cascade): picked white, on a slot green.
		AnimeSkin.Card(
			b,
			item.Id == selected and Color3.new(1, 1, 1) or onSlot and AnimeSkin.Tint.Ready or AnimeSkin.Tint.Default
		)
		swatch(b, item, selectedKind, UDim2.new(), UDim2.new())
		local badge = owned(selectedKind, item.Id)
				and "x" .. (selectedKind == "Potion" and Format.Short(player:GetAttribute("Boost_" .. item.Id) or 0) or Market.Copies(
					player,
					selectedKind,
					item.Id
				))
			or Format.MoneyText(item.Price)
		caption("Badge", b, "Body", { Text = badge, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
		caption("Name", b, "Item", { Text = item.Name, ZIndex = 5 })
		if frame then
			layoutTile(frame, b)
		end
		b.Activated:Connect(function()
			selected = item.Id
			showingDetail = true
			applyLayout()
			render()
		end)
	end
	local item = selected and Market.Get(selectedKind, selected)
	if item then
		showDetail(item)
	end
	if entering then
		entering = false
		cascade(shownTiles)
	end
end

local function open()
	PanelSwitch.Toggle("Market") -- showing it renders (Visible handler below)
end
local function closeMarket()
	PanelSwitch.Close("Market")
end
-- The top-right Market pill (HudChrome) opens it.
PanelSwitch.SetAction("Market", open)
close.Activated:Connect(closeMarket)
require(script.Parent:WaitForChild("PanelFrame")).CloseOnOutsideClick(backdrop, closeMarket)
remotes:WaitForChild("MarketOpen").OnClientEvent:Connect(open)
player.AttributeChanged:Connect(function(attr)
	if backdrop.Visible and (attr:sub(1, 6) == "Boost_" or attr:sub(1, 3) == "Own" or attr:match("^Slot%d")) then
		render()
	end
end)

-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6), in the Index frame.
frame = require(script.Parent:WaitForChild("PanelFrame")).Attach(panel, {
	Theme = "Market",
	Title = "Market",
	Icon = Icons.Market.Image,
	TitleObject = header.Title,
	Close = close,
	MaxWidth = 900,
}).Frame
local lit = frame.Tabs(tabButtons)
for order, entry in KINDS do
	tabs[entry[1]].Lit = lit[order]
end
frame.OnLayout(layout)
for kind, refs in tabs do
	refs.Button.Activated:Connect(function()
		if kind ~= selectedKind then
			UiFeedback.Play("TabSwitch")
		end
		selectedKind = kind
		showingDetail = false
		applyLayout()
		selected = nil
		status.Text = ""
		render()
	end)
end
-- However the panel is shown, its grid is filled.
backdrop:GetPropertyChangedSignal("Visible"):Connect(function()
	if backdrop.Visible then
		entering = true
		showingDetail = false
		applyLayout()
		render()
	end
end)
UiTheme.Apply(root)
