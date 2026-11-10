--!nonstrict
-- Market (docs/HUD_LAYOUT_SPEC.md, Market pill): the Backpack look with side tabs, a tile grid and a detail pane.
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
-- A text in one of the five roles (design doc 4.42): Title, Section, Item, Body, Caption.
local function caption(name, parent, role, props)
	props.BackgroundTransparency = 1
	return AnimeSkin.Label(make("TextLabel", name, parent, props), role)
end
-- Spacing tokens (design doc 4.42, Client/AnimeSkin), in px for this screen.
local P = AnimeSkin.Px
local function space(name)
	return P(AnimeSkin.Space[name])
end
local RAIL_W = 96 -- design px (UiSpec.Market.TabFit.RailWidth)
local TILE_MIN = 104 -- narrowest tile before the grid drops a column
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

-- Header: gradient band, icon, title and the square red X (same as the Backpack).
local header = make("Frame", "Header", panel, {
	Size = UDim2.new(1, 0, 0, 64),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ClipsDescendants = true,
})
corner(header, 16)
make("UIGradient", "Gradient", header, {
	Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(250, 90, 170)),
})
make("ImageLabel", "Icon", header, {
	Position = UDim2.fromOffset(14, 6),
	Size = UDim2.fromOffset(52, 52),
	BackgroundTransparency = 1,
	Image = Icons.Market.Image,
	ScaleType = Enum.ScaleType.Fit,
})
caption("Title", header, "Title", { Text = "Market" }) -- AnimeSkin.Header places it
local close = make("TextButton", "Close", header, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(72, 64),
	Text = "",
	AutoButtonColor = false,
})
make("TextLabel", "X", close, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "X" })

-- Side tabs: a left rail of art tabs, inset 16, 12 from the grid, clear of the body art's bottom-left stripes.
-- applyLayout places it.
local rail = make("Frame", "Tabs", panel, { BackgroundTransparency = 1 })
make("UIListLayout", "Layout", rail, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })

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
for order, entry in KINDS do
	local kind, label = entry[1], entry[2]
	local b = make("TextButton", kind .. "Tab", rail, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = false,
	})
	corner(b, 12)
	UiTheme.Gradient(b, PALETTE.TabIdle, PALETTE.TabIdleDeep)
	local edge = stroke(b, OUTLINE, 4)
	swatch(b, Market.Items[kind][1], kind, UDim2.fromOffset(48, 36), UDim2.fromOffset(52, 52)) -- above the label
	caption("Label", b, "Item", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 24),
		Text = label,
	})
	-- Per-tab scale: a UIScale on the rail would shrink the rail with the tabs and never make them fit.
	tabs[kind] = { Button = b, Edge = edge, Scale = make("UIScale", "Scale", b, {}), Lit = AnimeSkin.Tab(b, order) }
end

-- Tile grid, from the rail to 12 before the detail card. fitGrid sizes the tiles to fill it.
local grid = make("ScrollingFrame", "Grid", panel, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, -- the bar sits beside the tiles, not on them
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIGridLayout", "Layout", grid, {
	CellSize = UDim2.fromOffset(TILE_MIN, TILE_MIN),
	CellPadding = UDim2.fromOffset(12, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

-- Detail pane (like the Items reference): rarity line, name, big preview, price, description, action. 12 padding.
local detail = make("Frame", "Detail", panel, {
	BackgroundColor3 = Color3.new(1, 1, 1),
})
corner(detail, 12)
stroke(detail, OUTLINE, 3)
make("UIGradient", "Gradient", detail, {
	Color = ColorSequence.new(PALETTE.Row, PALETTE.PanelDeep),
	Rotation = 90,
})
AnimeSkin.Card(detail, AnimeSkin.Tint.Default) -- the Quests detail card (design doc 4.42)
-- applyLayout places every part (desktop: the rows below; phones: two columns).
local rarity = caption("Rarity", detail, "Body", { Text = "", TextXAlignment = Enum.TextXAlignment.Left })
local nameLabel = caption("Name", detail, "Item", { Text = "", TextXAlignment = Enum.TextXAlignment.Left })
local viewport = make("ViewportFrame", "Preview", detail, {
	BackgroundColor3 = PALETTE.TileDeep,
	BackgroundTransparency = 0.5,
	Ambient = Color3.fromRGB(130, 140, 190),
	LightColor = Color3.new(1, 1, 1),
})
corner(viewport, 4)
-- Desktop rows, bottom up. The bottom band holds the slot buttons on an owned item and the description otherwise, so
-- BUY never moves when the first copy arrives (a double tap cannot land on a slot). Above it: price + BUY; the reply
-- sits on the preview's bottom edge.
local priceRow = make("Frame", "Price", detail, {
	BackgroundColor3 = PALETTE.PanelDeep,
	BackgroundTransparency = 0.3,
})
corner(priceRow, 4)
local priceText = caption("Value", priceRow, "Item", { -- scaled: "$1.2m • Owned x2" stays on the row
	Position = UDim2.fromOffset(8, 0),
	Size = UDim2.new(1, -16, 1, 0),
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
local slots = SlotPicker.new("Slots", detail, {
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.new(1, -24, 0, 40),
	Visible = false,
}, function(...)
	pickSlot(...)
end)
-- The server's reply, on the preview's bottom edge just above BUY.
local status = caption("Status", detail, "Body", {
	AnchorPoint = Vector2.new(0, 1),
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})
-- A purchase / equip answer slides in from the bottom edge.
local statusHome -- set by applyLayout: the status row of the view on screen
local function notify(text, color)
	status.Text = text
	status.TextColor3 = color
	status.Position = statusHome
	UiMotion.SlideIn(status, Vector2.new(0, 14))
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
-- Desktop: rail, grid and detail card side by side under the header; inside the card 12 padding, 8 between rows.
local function desktopLayout()
	local top, inset, gap = AnimeSkin.Top(false), space("Inset"), space("Gap")
	local pad, inner, btn = space("Pad"), space("Inner"), space("Button")
	local bottom = space("Bottom")
	local gridLeft = inset + RAIL_W + gap
	local textRow, nameRow = P(20), P(24)
	local previewTop = pad + textRow + inner + nameRow + inner
	local rowBottom = -(pad + btn + inner) -- price + BUY, above the bottom band
	local half = UDim2.new(0.5, -(pad + inner / 2), 0, btn)
	return {
		-- The rail stops clear of the body art's bottom-left stripes.
		[rail] = {
			Position = UDim2.fromOffset(inset, top),
			Size = UDim2.new(0, RAIL_W, 1, -top - space("BottomClear")),
		},
		[grid] = {
			Position = UDim2.fromOffset(gridLeft, top),
			Size = UDim2.new(0.58, -gridLeft - gap, 1, -top - bottom),
		},
		[detail] = {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -inset, 0, top),
			Size = UDim2.new(0.42, -inset, 1, -top - bottom),
		},
		[rarity] = {
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromOffset(pad, pad),
			Size = UDim2.new(1, -2 * pad, 0, textRow),
		},
		[nameLabel] = {
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromOffset(pad, pad + textRow + inner),
			Size = UDim2.new(1, -2 * pad, 0, nameRow),
		},
		[viewport] = {
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromOffset(pad, previewTop),
			Size = UDim2.new(1, -2 * pad, 1, -previewTop - pad - 2 * (btn + inner)),
		},
		[priceRow] = { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, pad, 1, rowBottom), Size = half },
		[action] = { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -pad, 1, rowBottom), Size = half },
		[description] = {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, pad, 1, -pad),
			Size = UDim2.new(1, -2 * pad, 0, btn),
		},
		[slots.Frame] = {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -pad),
			Size = UDim2.new(1, -2 * pad, 0, btn),
		},
		[status] = { -- on the preview's bottom edge, 8 inside it
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, pad + inner, 1, rowBottom - btn - 2 * inner),
			Size = UDim2.new(1, -2 * (pad + inner), 0, textRow),
		},
	}
end
-- Phone detail: the preview on the left, the text rows and BACK / action on the right, in fractions of the pane so
-- nothing overlaps however short the band is.
local function phoneLayout()
	local top, inset, gap, pad = AnimeSkin.Top(false), space("Inset"), space("Gap"), space("Pad")
	local left = inset + RAIL_W + gap
	local function column(y, h)
		return {
			AnchorPoint = Vector2.zero,
			Position = UDim2.new(0.4, pad, y, 0),
			Size = UDim2.new(0.6, -2 * pad, h, 0),
		}
	end
	local pane =
		{ Position = UDim2.fromOffset(left, top), Size = UDim2.new(1, -left - inset, 1, -top - space("Bottom")) }
	return {
		[rail] = {
			Position = UDim2.fromOffset(inset, top),
			Size = UDim2.new(0, RAIL_W, 1, -top - space("BottomClear")),
		},
		[grid] = pane,
		[detail] = { AnchorPoint = Vector2.zero, Position = pane.Position, Size = pane.Size },
		[viewport] = {
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromOffset(pad, pad),
			Size = UDim2.new(0.4, -pad, 1, -2 * pad),
		},
		[rarity] = column(0.03, 0.13),
		[nameLabel] = column(0.17, 0.18),
		[priceRow] = column(0.37, 0.15),
		[description] = column(0.54, 0.2),
		[action] = {
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromScale(0.7, 0.77),
			Size = UDim2.new(0.3, -pad, 0.2, 0),
		},
		[slots.Frame] = column(0.54, 0.21), -- over the description, which an owned aura / trail hides on phones
		[back] = {
			AnchorPoint = Vector2.zero,
			Position = UDim2.new(0.4, pad, 0.77, 0),
			Size = UDim2.new(0.3, -2 * pad, 0.2, 0),
		},
		[status] = { -- on the preview
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2 * pad, 1, -2 * pad),
			Size = UDim2.new(0.4, -3 * pad, 0, P(20)),
		},
	}
end
local showingDetail = false
-- An owned aura / trail: the slot buttons take the description's band, in both views.
local function fitDetail()
	description.Visible = not slots.Frame.Visible
end
local function applyLayout()
	local camera = workspace.CurrentCamera
	local phone = camera ~= nil and camera.ViewportSize.Y <= 500
	local layout = phone and phoneLayout() or desktopLayout()
	for part, props in layout do
		for key, value in props do
			part[key] = value
		end
	end
	statusHome = layout[status].Position
	fitDetail()
	grid.Visible = not (phone and showingDetail)
	detail.Visible = not phone or showingDetail
	back.Visible = phone
end
-- Tiles fill the grid up to the detail card, 12 apart, and as tall as a whole number of rows of its window.
local function fitGrid()
	local gap = space("Gap")
	local w, h = grid.AbsoluteSize.X - grid.ScrollBarThickness, grid.AbsoluteSize.Y
	if w <= 0 or h <= 0 then
		return
	end
	local columns = math.max(1, math.floor((w + gap) / (P(TILE_MIN) + gap)))
	local tile = (w - gap * (columns - 1)) / columns
	local rows = math.max(1, math.floor((h + gap) / (tile + gap)))
	grid.Layout.CellPadding = UDim2.fromOffset(gap, gap)
	grid.Layout.CellSize =
		UDim2.new(1 / columns, -gap * (columns - 1) / columns, 0, math.floor((h - gap * (rows - 1)) / rows))
end
grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGrid)
fitGrid()
back.Activated:Connect(function()
	showingDetail = false
	applyLayout()
end)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
end
applyLayout()

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
	notify(
		ok and tostring(message or (done and "Done" or "Try again")) or "Connection error",
		(ok and done) and TILE_GREEN or PALETTE.Reject
	)
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
	notify(
		ok and tostring(message or (done and "Done" or "Try again")) or "Connection error",
		(ok and done) and TILE_GREEN or PALETTE.Reject
	)
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
		-- Inside the tile, 8 padding: count / price on top, the name at the bottom, the swatch between.
		swatch(b, item, selectedKind, UDim2.new(0.5, 0, 0.5, -2), UDim2.fromOffset(P(56), P(56)))
		local badge = owned(selectedKind, item.Id)
				and "x" .. (selectedKind == "Potion" and Format.Short(player:GetAttribute("Boost_" .. item.Id) or 0) or Market.Copies(
					player,
					selectedKind,
					item.Id
				))
			or Format.MoneyText(item.Price)
		caption("Badge", b, "Body", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, P(20)),
			Text = badge,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
		})
		caption("Name", b, "Item", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, P(24)),
			Text = item.Name,
			ZIndex = 5,
		})
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

-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6); short panels shrink the tabs.
require(script.Parent:WaitForChild("PanelFrame")).Attach(panel, {
	Theme = "Market",
	Title = "Market",
	Icon = Icons.Market.Image,
	TitleObject = header.Title,
	Close = close,
	MaxWidth = 900,
})
local function fitTabs()
	local ancestor = rail.AbsoluteSize.X / 96 -- PanelBand scale; the rail is 96 design px wide
	if ancestor <= 0 then
		return
	end
	local count = 0
	for _ in tabs do
		count += 1
	end
	-- Owner 2026-10-28: on phones (viewport height <= 500) the tabs may shrink below 0.4 so all stay inside the rail.
	local phone = workspace.CurrentCamera.ViewportSize.Y <= 500
	local scale =
		math.clamp((rail.AbsoluteSize.Y / ancestor - (count - 1) * 10) / (count * 96), phone and 0.1 or 0.4, 1)
	for _, refs in tabs do
		refs.Scale.Scale = scale
	end
end
rail:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTabs)
fitTabs()
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
