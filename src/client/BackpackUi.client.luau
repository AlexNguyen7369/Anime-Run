--!nonstrict
-- Backpack (docs/HUD_LAYOUT_SPEC.md section 3): Misc (potions), Trails, Auras and Characters tabs with item tiles.
-- Clicking a potion asks the server to use one; clicking a character, trail or aura picks it, and the team slot
-- buttons below the grid (SlotPicker) put it on a slot or take it off (characters: Remotes.SetTeam, 3 slots, design
-- doc 4.2). The server
-- decides all of them. Characters are listed least rare first (owner, 2026-10-20) unless the player picks another
-- sort; their cards are the shared collection card (design doc 4.22). The Sidekicks and Relics tabs are bags (design doc 4.36,
-- 4.38): a tile opens Client/ItemMenu. Spare characters sell one by one or in select mode (design doc 4.41); the server decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Market = require(shared.MarketConfig)
local Boosts = require(shared.BoostConfig)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local Ui = script.Parent:WaitForChild("RollToast"):WaitForChild("Ui")
local Icons = require(Ui.HudIcons)
local PotionIcons = require(Ui.PotionIcons)
local MarketArt = require(script.Parent:WaitForChild("MarketArt"))
local BagConfig = require(shared.BagConfig)
local CharacterCatalog = require(shared.CharacterCatalog)
local GachaConfig = require(shared.GachaConfig)
local Components = require(Ui.RacerComponents)
local UiTheme = require(shared:WaitForChild("UiTheme"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local RaceConfig = require(shared:WaitForChild("RaceConfig"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local SlotPicker = require(script.Parent:WaitForChild("SlotPicker"))
local StaminaConfig = require(shared:WaitForChild("StaminaConfig"))
local SidekickConfig = require(shared:WaitForChild("SidekickConfig"))
local RelicConfig = require(shared:WaitForChild("RelicConfig"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local ItemMenu = require(script.Parent:WaitForChild("ItemMenu"))

local OUTLINE = UiTheme.Outline
local PALETTE = UiTheme.Palette
local TILE_BLUE = PALETTE.Tile
local TILE_GREEN = PALETTE.Money
local GOLD = PALETTE.Unbanked
-- Characters grid (design doc 4.22; placeholders): as many columns as fit cells at least this wide.
local CARD_MIN_WIDTH = 112
local CARD_HEIGHT = 128
local CARD_GAP = 10
local TILE_SIZE = UDim2.fromOffset(104, 104)
local TILE_GAP = UDim2.fromOffset(12, 12)
local SORTS = { "Rarity", "Speed", "Stamina" }

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
local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = UiTheme.Font
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round })
	return label
end
local function count(n)
	return "x" .. HudFormat.Short(n)
end
local function cascade(tiles)
	UiMotion.Cascade(tiles, "Stroke")
end

local root = make("ScreenGui", "RacerBackpack", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(720, 420),
	Visible = false,
	Active = true,
})
corner(panel, 16)
stroke(panel, OUTLINE, 4)
PanelSwitch.Register("Backpack", panel)

-- Header: blue checkered band, icon, title and the square red X.
local header = make("Frame", "Header", panel, {
	Size = UDim2.new(1, 0, 0, 64),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ClipsDescendants = true,
})
corner(header, 16)
make("UIGradient", "Gradient", header, {
	Color = ColorSequence.new(Color3.fromRGB(104, 104, 245), Color3.fromRGB(80, 170, 250)),
})
caption("Title", header, {
	Position = UDim2.fromOffset(78, 0),
	Size = UDim2.new(1, -160, 1, 0),
	Text = "Backpack",
	TextSize = 36,
	TextXAlignment = Enum.TextXAlignment.Left,
})
make("ImageLabel", "Icon", header, {
	Position = UDim2.fromOffset(14, 6),
	Size = UDim2.fromOffset(52, 52),
	BackgroundTransparency = 1,
	Image = Icons.Items.Image,
	ScaleType = Enum.ScaleType.Fit,
})
local close = make("TextButton", "Close", header, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(72, 64),
	Text = "",
	AutoButtonColor = false,
})
caption("X", close, { Size = UDim2.fromScale(1, 1), Text = "X", TextSize = 40 })

-- Side tabs.
local rail = make("Frame", "Tabs", panel, {
	Position = UDim2.fromOffset(12, 76),
	Size = UDim2.new(0, 96, 1, -88),
	BackgroundTransparency = 1,
})
make("UIListLayout", "Layout", rail, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
local tabs = {}
local function tab(name, order, art)
	local b = make("TextButton", name .. "Tab", rail, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = false,
	})
	corner(b, 12)
	UiTheme.Gradient(b, PALETTE.TabIdle, PALETTE.TabIdleDeep)
	local edge = stroke(b, OUTLINE, 4)
	art(b)
	local label = caption("Label", b, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -6, 0, 24),
		Text = name,
		TextSize = 20,
		TextScaled = true, -- "Characters" is wider than the tab at 20 px
	})
	make("UITextSizeConstraint", "MaxSize", label, { MaxTextSize = 20 })
	-- Per-tab scale: a UIScale on the rail would shrink the rail with the tabs and never make them fit.
	tabs[name] = { Button = b, Edge = edge, Scale = make("UIScale", "Scale", b, {}) }
	return b
end
-- Same original art as Market tiles, tabs and detail previews.
local function swatch(parent, item, kind, pos, size)
	return MarketArt.Draw(parent, item, pos, kind == "Trail" and UDim2.new(size.X, size.X) or size)
end
tab("Misc", 1, function(b)
	make("ImageLabel", "Art", b, {
		Position = UDim2.fromOffset(18, 6),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		Image = PotionIcons.Luck,
		ScaleType = Enum.ScaleType.Fit,
	})
end)
tab("Trails", 2, function(b)
	swatch(b, Market.Items.Trail[1], "Trail", UDim2.fromOffset(48, 36), UDim2.fromOffset(66, 22))
end)
tab("Auras", 3, function(b)
	swatch(b, Market.Items.Aura[1], "Aura", UDim2.fromOffset(48, 36), UDim2.fromOffset(48, 48))
end)
tab("Characters", 4, function(b)
	Components.PortraitArt(b, "Art", CharacterCatalog.All()[1], UDim2.fromOffset(8, 2), UDim2.fromOffset(80, 66))
end)
tab("Sidekicks", 5, function(b)
	SidekickView.Art(b, SidekickConfig.List[1], UDim2.fromOffset(48, 36), UDim2.fromOffset(56, 56)).Label.Visible =
		false
end)
tab("Relics", 6, function(b)
	local list = RelicConfig.Bosses.big_raga
	SidekickView.Art(b, list[#list], UDim2.fromOffset(48, 36), UDim2.fromOffset(56, 56)).Label.Visible = false
end)

-- Owned cars, least rare first, then catalog order.
local rarityRank = {}
for i, rarity in GachaConfig.RARITY_ORDER do
	rarityRank[rarity] = i
end
local sortMode = SORTS[1]
local function ownedCars()
	local data = player:FindFirstChild("GachaData")
	local list = {}
	for _, spec in CharacterCatalog.All() do
		if data and data:FindFirstChild(spec.Id) then
			table.insert(list, spec)
		end
	end
	table.sort(list, function(a, b)
		-- Highest first; a tie falls through to the default order.
		local va = sortMode == "Speed" and RaceConfig.Cruise(a)
			or sortMode == "Stamina" and StaminaConfig.Seconds(a)
			or 0
		local vb = sortMode == "Speed" and RaceConfig.Cruise(b)
			or sortMode == "Stamina" and StaminaConfig.Seconds(b)
			or 0
		if va ~= vb then
			return va > vb
		end
		local ra, rb = rarityRank[a.Rarity] or 99, rarityRank[b.Rarity] or 99
		if ra ~= rb then
			return ra < rb
		end
		return (a.Order or 0) < (b.Order or 0)
	end)
	return list
end

local grid = make("ScrollingFrame", "Items", panel, {
	Position = UDim2.fromOffset(120, 76),
	Size = UDim2.new(1, -132, 1, -88),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIPadding", "Padding", grid, {
	PaddingTop = UDim.new(0, 4),
	PaddingLeft = UDim.new(0, 4),
	PaddingRight = UDim.new(0, 10),
})
local gridLayout = make("UIGridLayout", "Layout", grid, {
	CellSize = TILE_SIZE,
	CellPadding = TILE_GAP,
	SortOrder = Enum.SortOrder.LayoutOrder,
})

-- Sort and search live in the header band, Characters tab only: the grid keeps its height on short screens.
local toolbar = make("Frame", "Toolbar", header, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -76, 0.5, 0),
	Size = UDim2.new(0.5, 0, 0, 40),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 5,
})
make("UIListLayout", "Layout", toolbar, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local sortButton = make("TextButton", "Sort", toolbar, {
	LayoutOrder = 1,
	Size = UDim2.new(0, 112, 1, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "",
	AutoButtonColor = false,
})
corner(sortButton, UiTheme.Radius.M)
UiTheme.Gradient(sortButton, PALETTE.Row, PALETTE.PanelDeep)
stroke(sortButton, PALETTE.White, 2)
local sortLabel = caption("Label", sortButton, {
	Size = UDim2.fromScale(1, 1),
	Text = "Sort: " .. sortMode,
	TextSize = 15,
})
local massSell = make("TextButton", "MassSell", toolbar, {
	LayoutOrder = 2,
	Size = UDim2.new(0, 84, 1, 0),
	BackgroundColor3 = PALETTE.Danger,
	Font = UiTheme.Font,
	Text = "Mass sell",
	TextColor3 = PALETTE.White,
	TextSize = 15,
	AutoButtonColor = false,
})
corner(massSell, UiTheme.Radius.M)
stroke(massSell, PALETTE.White, 2)
local search = make("TextBox", "Search", toolbar, {
	LayoutOrder = 3,
	Size = UDim2.new(1, -212, 1, 0),
	BackgroundColor3 = OUTLINE,
	BackgroundTransparency = 0.25,
	ClearTextOnFocus = false,
	Font = UiTheme.Font,
	PlaceholderText = "Search",
	PlaceholderColor3 = PALETTE.SoftText,
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 18,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
corner(search, 10)
stroke(search, OUTLINE, 3)
make("UIPadding", "Padding", search, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
local bagCount = caption("BagCount", header, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -76, 0.5, 0),
	Size = UDim2.fromOffset(120, 40),
	Text = "",
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Right,
	Visible = false,
	ZIndex = 5,
})
-- Bag space and selling a chosen character's spares (docs/BAG_AND_AUTOSELL_SPEC.md). Characters tab only.
local bagLabel = caption("Bag", panel, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -176, 1, -6),
	Size = UDim2.fromOffset(110, 22),
	Text = "",
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 8,
	Visible = false,
})
local sellSpares = make("TextButton", "SellSpares", panel, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -4),
	Size = UDim2.fromOffset(156, 28),
	BackgroundColor3 = PALETTE.Muted,
	Font = UiTheme.Font,
	Text = "",
	TextColor3 = PALETTE.White,
	TextSize = 15,
	AutoButtonColor = true,
	ZIndex = 8,
	Visible = false,
})
corner(sellSpares, UiTheme.Radius.S)
stroke(sellSpares, OUTLINE, 2)
local empty = caption("Empty", panel, {
	Position = UDim2.fromOffset(120, 140),
	Size = UDim2.new(1, -132, 0, 40),
	Text = "",
	TextSize = 22,
	Visible = false,
})
local hint = caption("Hint", panel, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 120, 1, -6),
	Size = UDim2.new(1, -132, 0, 22),
	Text = "",
	TextSize = 16,
	TextColor3 = PALETTE.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})
make("UITextSizeConstraint", "MaxSize", hint, { MaxTextSize = 16 })
hint.TextScaled = true -- a long line shrinks to fit: on the Characters tab it shares its row with Bag and Sell
local hintHome = hint.Position
local GRID_SIZE = grid.Size
local pickSlot -- set below
local slots = SlotPicker.new("Slots", panel, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 120, 1, -32),
	Size = UDim2.new(1, -132, 0, 44),
	Visible = false,
}, function(...)
	pickSlot(...)
end)
-- Select mode's row, where the Slots show otherwise (design doc 4.41).
local massBar = make("Frame", "MassBar", panel, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 120, 1, -32),
	Size = UDim2.new(1, -132, 0, 44),
	BackgroundTransparency = 1,
	Visible = false,
})
local function barButton(name, text, x, width, color)
	local b = make("TextButton", name, massBar, {
		Position = UDim2.fromScale(x, 0),
		Size = UDim2.fromScale(width, 1),
		BackgroundColor3 = color,
		Font = UiTheme.Font,
		Text = text,
		TextColor3 = PALETTE.White,
		TextSize = 17,
		AutoButtonColor = false,
	})
	corner(b, UiTheme.Radius.M)
	stroke(b, OUTLINE, 3)
	return b
end
local massAll = barButton("SelectAll", "Select all", 0, 0.24, PALETTE.Row)
local massGo = barButton("Sell", "", 0.26, 0.5, PALETTE.Danger)
local massCancel = barButton("Cancel", "Cancel", 0.78, 0.22, PALETTE.Row)
-- A server answer (equip / use) slides in from the bottom edge; hover text just appears.
local function notify(text)
	hint.Text = text
	hint.Position = hintHome
	UiMotion.SlideIn(hint, Vector2.new(0, 14))
end

local current = "Characters" -- the common job; Misc is usually empty
local chosen = nil -- the trail / aura id the slot buttons equip
local chosenCharacter = nil -- the character id the slot buttons put on the Team
local gearOf = {} -- character id -> the Sidekick row it wears (filled per render)
local relicOf = {} -- character id -> the Relic row it wears (filled per render)
local selecting = false -- select mode: a card marks itself for the mass sale
local selected = {} -- character id -> true
local render -- set below
local function refreshBag()
	local onCharacters = toolbar.Visible
	hint.Size = UDim2.new(1, onCharacters and -412 or -132, 0, 22) -- ends short of the Bag label
	local used, cap = player:GetAttribute("BagUsed") or 0, player:GetAttribute("BagCap") or 0
	bagLabel.Visible = onCharacters
	bagLabel.Text = "Bag " .. used .. "/" .. cap
	bagLabel.TextColor3 = used >= cap and PALETTE.DangerDeep or PALETTE.White
	local data = player:FindFirstChild("GachaData")
	local entry = data and chosenCharacter and data:FindFirstChild(chosenCharacter)
	local spares = entry and entry:GetAttribute("Copies") or 0
	local spec = chosenCharacter and CharacterCatalog.Get(chosenCharacter)
	local price = spec and BagConfig.SELL_PRICE[spec.Rarity]
	sellSpares.Visible = onCharacters and not selecting and spares > 0 and price ~= nil
	if sellSpares.Visible then
		sellSpares.Text = "SELL " .. spares .. " SPARE" .. (spares == 1 and "" or "S")
	end
end
sellSpares.Activated:Connect(function()
	local data = player:FindFirstChild("GachaData")
	local entry = data and chosenCharacter and data:FindFirstChild(chosenCharacter)
	local spares = entry and entry:GetAttribute("Copies") or 0
	local spec = chosenCharacter and CharacterCatalog.Get(chosenCharacter)
	local price = spec and BagConfig.SELL_PRICE[spec.Rarity]
	if spares < 1 or not price then
		return
	end
	ItemMenu.Confirm({
		Limit = spares,
		Words = function(n)
			return string.format(
				"Are you sure you want to sell %d %s for $%s?",
				n,
				n == 1 and "copy of " .. spec.Name or "copies of " .. spec.Name,
				HudFormat.Short(n * price)
			)
		end,
	}, function(n)
		local ok = ItemMenu.Ask("SellSpares", sellSpares, "MoneyBig", chosenCharacter, n)
		if ok then
			render()
		end
		return ok
	end)
end)
player:GetAttributeChangedSignal("BagUsed"):Connect(refreshBag)
player:GetAttributeChangedSignal("BagCap"):Connect(refreshBag)
toolbar:GetPropertyChangedSignal("Visible"):Connect(refreshBag)
local busy = false
local entering = false -- the next render is the panel opening: cascade its tiles
local shownTiles = {}
local function tile(id, order, highlighted)
	local b = make("TextButton", id, grid, {
		LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = false,
	})
	corner(b, 12)
	UiTheme.Gradient(b, PALETTE.Row, PALETTE.PanelDeep)
	stroke(b, highlighted and TILE_GREEN or TILE_BLUE, 4)
	table.insert(shownTiles, b)
	return b
end

-- A character's collection card; the generic tile's gradient gives way to the rarity tint.
local function characterTile(spec, order)
	local b = make("TextButton", spec.Id, grid, {
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = false,
	})
	Components.CardFace(b, spec, GachaConfig)
	local slot = table.find(SlotPicker.Team(), spec.Id)
	stroke(b, slot and TILE_GREEN or OUTLINE, 3)
	if spec.Id == chosenCharacter then
		b.Stroke.Color = Color3.new(1, 1, 1)
	end
	table.insert(shownTiles, b)
	Components.CardArt(b, spec)
	local worn = gearOf[spec.Id]
	if worn then
		caption("SidekickBadge", b, {
			Position = UDim2.fromOffset(9, 28),
			Size = UDim2.new(1, -18, 0, 16),
			Text = worn.Name,
			TextSize = 13,
			TextColor3 = SidekickView.RarityColor(worn.Rarity),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
		})
	end
	local relic = relicOf[spec.Id]
	if relic then
		caption("RelicBadge", b, {
			Position = UDim2.fromOffset(9, worn and 44 or 28),
			Size = UDim2.new(1, -18, 0, 16),
			Text = relic.Name,
			TextSize = 13,
			TextColor3 = SidekickView.RarityColor(relic.Rarity),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
		})
	end
	local data = player:FindFirstChild("GachaData")
	local entry = data and data:FindFirstChild(spec.Id)
	local copies = entry and entry:GetAttribute("Copies") or 1
	caption("Badge", b, {
		Position = UDim2.fromOffset(9, 7),
		Size = UDim2.new(1, -42, 0, 22),
		Text = slot and ("TEAM " .. slot) or (copies > 1 and count(copies) or ""),
		TextSize = 16,
		TextColor3 = slot and TILE_GREEN or GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
	})
	caption("Multi", b, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -28),
		Size = UDim2.new(1, -16, 0, 16),
		Text = HudFormat.RateText(RaceConfig.Cruise(spec)),
		TextSize = 14,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 7,
	})
	local nameLabel = caption("Name", b, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -6),
		Size = UDim2.new(1, -16, 0, 22),
		Text = spec.Name,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 7,
	})
	make("UITextSizeConstraint", "MaxSize", nameLabel, { MaxTextSize = 19 })
	return b
end

local function characterFacts(spec)
	return string.format(
		"%s (%s, %s): %s, %.1f s stamina.",
		spec.Name,
		spec.Rarity,
		spec.Category or "Balanced",
		HudFormat.RateText(RaceConfig.Cruise(spec)),
		StaminaConfig.Seconds(spec)
	)
end

-- Hides the cards the search box rules out (no rebuild per keystroke: each card holds a live model).
local function applySearch()
	local query = string.lower(search.Text)
	for _, b in shownTiles do
		local spec = CharacterCatalog.Get(b.Name)
		b.Visible = query == "" or (spec ~= nil and string.find(string.lower(spec.Name), query, 1, true) ~= nil)
	end
end

local function fitCards()
	if current ~= "Characters" then
		gridLayout.CellSize, gridLayout.CellPadding = TILE_SIZE, TILE_GAP
		return
	end
	local width = grid.AbsoluteSize.X - 14 - grid.ScrollBarThickness
	local columns = math.max(2, math.floor((width + CARD_GAP) / (CARD_MIN_WIDTH + CARD_GAP)))
	gridLayout.CellSize = UDim2.fromOffset(math.floor((width - (columns - 1) * CARD_GAP) / columns), CARD_HEIGHT)
	gridLayout.CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP)
end
grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCards)

function pickSlot(slot, id, picked)
	if busy then
		return
	end
	if not picked then
		notify(
			current == "Trails" and "Pick a trail first"
				or (current == "Auras" and "Pick an aura first" or "Pick a character first")
		)
		UiFeedback.Play("Denied", slots.Buttons[slot].Button)
		return
	end
	if current == "Characters" then
		local team = SlotPicker.TeamWith(slot, id)
		if not team then
			notify("Your Team needs at least 1 character")
			UiFeedback.Play("Denied", slots.Buttons[slot].Button)
			return
		end
		busy = true
		local ok, done, message = pcall(function()
			return remotes:WaitForChild("SetTeam"):InvokeServer(team)
		end)
		busy = false
		notify(ok and tostring(message or (done and "Team updated" or "Try again")) or "Connection error")
		render()
		UiFeedback.Play((ok and done) and "Equip" or "Denied", slots.Buttons[slot].Button)
		return
	end
	busy = true
	local ok, done, message = pcall(function()
		return remotes:WaitForChild("MarketEquip"):InvokeServer(current == "Trails" and "Trail" or "Aura", id, slot)
	end)
	busy = false
	notify(ok and tostring(message or (done and "Done" or "Try again")) or "Connection error")
	render()
	UiFeedback.Play((ok and done) and "Equip" or "Denied", slots.Buttons[slot].Button)
end
local function use(item)
	if busy then
		return
	end
	busy = true
	local ok, used, message = pcall(function()
		return remotes:WaitForChild("UseBoost"):InvokeServer(item.Id)
	end)
	busy = false
	notify(ok and (used and (item.Name .. " activated") or tostring(message)) or "Connection error")
	render()
	if not (ok and used) then
		UiFeedback.Play("Denied") -- render replaced the tile
	end
end

-- Bag entry facts in words; the numbers come from the shared catalog, the server pays them.
local function sidekickFacts(row)
	if not row then
		return "A Sidekick from a newer version. It stays in your Bag and cannot be sold."
	end
	return string.format(
		"%s (%s): %s. Sells for %d Gems.",
		row.Name,
		row.Rarity,
		SidekickView.GainText(row),
		row.SellGems
	)
end

local function relicFacts(row)
	if not row then
		return "A Relic from a newer version. It stays in your Bag."
	end
	return string.format(
		"%s (%s): %s. Sells for $%s.",
		row.Name,
		row.Rarity,
		RelicConfig.GainText(row),
		HudFormat.Short(BagConfig.SELL_PRICE[row.Rarity] or 0)
	)
end

-- One tile per bag entry, the worn ones marked. `rowOf` finds the catalog row, `facts` words it; a press opens the menu.
local function entryTiles(bag, wearers, kind, rowOf, facts)
	for order, item in bag do
		local row = rowOf(item.Id)
		local b = tile(item.Entry, order, wearers[item.Entry] ~= nil)
		SidekickView.Art(b, row, UDim2.fromScale(0.5, 0.5), UDim2.new(1, -12, 1, -12))
		if wearers[item.Entry] then
			caption("Worn", b, {
				Position = UDim2.fromOffset(8, 4),
				Size = UDim2.new(1, -16, 0, 18),
				Text = "WORN",
				TextSize = 15,
				TextColor3 = TILE_GREEN,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 5,
			})
		end
		b.MouseEnter:Connect(function()
			hint.Text = facts(row)
		end)
		b.Activated:Connect(function()
			hint.Text = facts(row) -- touch has no hover
			UiMotion.Pop(b, 0.06)
			ItemMenu.Open(kind, item.Entry, b)
		end)
	end
end

local function renderSidekicks(wearers)
	local bag = SidekickView.Bag(player)
	entryTiles(bag, wearers, "Sidekick", SidekickConfig.Get, sidekickFacts)
	bagCount.Text = #bag .. " / " .. SidekickConfig.BagSize
	empty.Text = "No Sidekicks yet. Summon them at the Sidekicks stall!"
	return #bag
end

local function relicWearers()
	local wearers = {} -- entry -> character id
	for character, entry in SidekickView.RelicGear(player) do
		wearers[entry] = character
	end
	return wearers
end

-- One tile per chest id, ahead of the Relics, its entries counted on it (docs/RELIC_SPEC.md "Chests").
local function chestTile(chest, order, copies)
	local b = tile(chest.Id, order, false)
	SidekickView.Art(b, chest, UDim2.fromScale(0.5, 0.5), UDim2.new(1, -12, 1, -12))
	caption("Count", b, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -2),
		Size = UDim2.new(1, -12, 0, 30),
		Text = count(copies),
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
	})
	local words = chest.Name .. ": open it for a Relic."
	b.MouseEnter:Connect(function()
		hint.Text = words
	end)
	b.Activated:Connect(function()
		hint.Text = words -- touch has no hover
		UiMotion.Pop(b, 0.06)
		ItemMenu.OpenChest(chest.Id, b)
	end)
end

local function renderRelics()
	local bag = SidekickView.RelicBag(player)
	local relics, chests = {}, {}
	for at, item in bag do
		if not RelicConfig.Chests[item.Id] then
			table.insert(relics, item)
		elseif chests[item.Id] then
			chests[item.Id].Copies += 1
		else
			chests[item.Id] = { Copies = 1, Order = at - #bag - 1 } -- below every Relic's order, in the bag's order
		end
	end
	for id, row in chests do
		chestTile(RelicConfig.Chests[id], row.Order, row.Copies)
	end
	entryTiles(relics, relicWearers(), "Relic", RelicConfig.Get, relicFacts)
	bagCount.Text = tostring(#bag) -- no cap: no rule gives this bag one
	empty.Text = "No Relics yet. Defeat a boss to earn one!"
	return #bag
end

-- Select mode's bar: the total at the moment of drawing; a roll landing after it only adds to the sale.
local function drawMassBar()
	local data = player:FindFirstChild("GachaData")
	local spares, money = 0, 0
	for id in selected do
		local spec = CharacterCatalog.Get(id)
		local entry = data and data:FindFirstChild(id)
		local copies = entry and entry:GetAttribute("Copies") or 0
		spares += copies
		money += copies * (spec and BagConfig.SELL_PRICE[spec.Rarity] or 0)
	end
	massGo.Text = string.format("Sell %d spare%s +$%s", spares, spares == 1 and "" or "s", HudFormat.Short(money))
	massGo.Active = spares > 0
	massGo.BackgroundColor3 = spares > 0 and PALETTE.Danger or PALETTE.Disabled
	return spares, money
end

local function setSelected(card, id, on)
	selected[id] = on or nil
	card.Picked.Visible = on
	card.Stroke.Color = on and PALETTE.Danger or OUTLINE
end

local function leaveSelect()
	selecting = false
	table.clear(selected)
	massSell.Text = "Mass sell"
end

function render()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for name, refs in tabs do
		UiMotion.Mark(refs.Edge, { Color = name == current and Color3.new(1, 1, 1) or OUTLINE })
	end
	local shown = 0
	table.clear(shownTiles)
	local cosmetic = current == "Trails" or current == "Auras" or current == "Characters"
	local inBag = current == "Sidekicks"
	local inRelics = current == "Relics"
	selecting = selecting and current == "Characters"
	slots.Frame.Visible = cosmetic and not selecting
	massBar.Visible = selecting
	bagCount.Visible = inBag or inRelics
	-- ends above the Slots row
	grid.Size = cosmetic and (GRID_SIZE - UDim2.fromOffset(0, 72)) or GRID_SIZE
	toolbar.Visible = current == "Characters"
	fitCards()
	local wearers = {} -- entry -> character id
	for character, entry in SidekickView.Gear(player) do
		wearers[entry] = character
	end
	table.clear(gearOf)
	for _, item in SidekickView.Bag(player) do
		local character = wearers[item.Entry]
		if character then
			gearOf[character] = SidekickConfig.Get(item.Id)
		end
	end
	table.clear(relicOf)
	local relicRows = {} -- entry -> Relic row
	for _, item in SidekickView.RelicBag(player) do
		relicRows[item.Entry] = RelicConfig.Get(item.Id)
	end
	for character, entry in SidekickView.RelicGear(player) do
		relicOf[character] = relicRows[entry]
	end
	if inBag then
		shown = renderSidekicks(wearers)
	elseif inRelics then
		shown = renderRelics()
	elseif current == "Characters" then
		local owned = ownedCars()
		local still = false
		for _, spec in owned do
			still = still or spec.Id == chosenCharacter
		end
		chosenCharacter = still and chosenCharacter or (owned[1] and owned[1].Id)
		for order, spec in owned do
			shown += 1
			local b = characterTile(spec, order)
			b.MouseEnter:Connect(function()
				hint.Text = characterFacts(spec)
			end)
			local entry = selecting and player.GachaData:FindFirstChild(spec.Id)
			local spares = entry and entry:GetAttribute("Copies") or 0
			if selecting then
				caption("Picked", b, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.4),
					Size = UDim2.new(1, -8, 0, 30),
					Text = "SELL",
					TextSize = 26,
					TextColor3 = PALETTE.Danger,
					Visible = false,
					ZIndex = 8,
				})
				if spares > 0 then
					setSelected(b, spec.Id, selected[spec.Id] == true)
				else
					selected[spec.Id] = nil
					make("Frame", "Dim", b, { -- no spares: the last copy is never sold (design doc 4.41)
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = OUTLINE,
						BackgroundTransparency = 0.45,
						BorderSizePixel = 0,
						ZIndex = 9,
					})
				end
			end
			b.Activated:Connect(function()
				if selecting then
					if spares > 0 then
						setSelected(b, spec.Id, not selected[spec.Id])
						drawMassBar()
						UiMotion.Pop(b, 0.06)
					else
						UiFeedback.Play("Denied", b)
					end
					return
				end
				chosenCharacter = spec.Id
				hint.Text = characterFacts(spec) -- touch has no hover
				render()
				local picked = grid:FindFirstChild(spec.Id)
				if picked then
					UiMotion.Pop(picked, 0.06)
				end
			end)
		end
		applySearch()
		slots:Update("Character", chosenCharacter)
		refreshBag()
		if selecting then
			drawMassBar()
		end
		empty.Text = "No characters yet. Keep rolling!"
	elseif current ~= "Misc" then
		local kind = current == "Trails" and "Trail" or "Aura"
		if not (Market.Get(kind, chosen) and Market.Copies(player, kind, chosen) > 0) then
			chosen = nil
		end
		for order, item in Market.Items[kind] do
			local copies = Market.Copies(player, kind, item.Id)
			if copies > 0 then
				shown += 1
				chosen = chosen or item.Id
				local b = tile(item.Id, order, SlotPicker.Equipped(kind, item.Id))
				caption("Copies", b, {
					Position = UDim2.fromOffset(6, 2),
					Size = UDim2.new(1, -12, 0, 20),
					Text = "x" .. copies,
					TextSize = 15,
					TextScaled = true,
					TextColor3 = PALETTE.Gold,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 5,
				})
				if item.Id == chosen then
					b.Stroke.Color = Color3.new(1, 1, 1)
				end
				swatch(
					b,
					item,
					kind,
					UDim2.new(0.5, 0, 0.5, -10),
					kind == "Trail" and UDim2.fromOffset(78, 26) or UDim2.fromOffset(56, 56)
				)
				caption("Name", b, {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -4),
					Size = UDim2.new(1, -8, 0, 22),
					Text = item.Name,
					TextSize = 15,
					TextScaled = true,
					ZIndex = 5,
				})
				b.MouseEnter:Connect(function()
					hint.Text = (item.Description or item.Name) .. " Pick a team slot below."
				end)
				b.Activated:Connect(function()
					chosen = item.Id
					render()
				end)
			end
		end
		slots:Update(kind, chosen)
		empty.Text = "None owned yet. Buy them in the Market!"
	else
		local order = 0
		for _, category in Boosts.Order do
			for _, item in Boosts.ItemsFor(category) do
				local n = player:GetAttribute("Boost_" .. item.Id) or 0
				order += 1
				if n > 0 then
					shown += 1
					local b = tile(item.Id, order, false)
					make("ImageLabel", "Art", b, {
						Position = UDim2.fromOffset(10, 6),
						Size = UDim2.new(1, -20, 1, -20),
						BackgroundTransparency = 1,
						Image = PotionIcons[category] or "",
						ScaleType = Enum.ScaleType.Fit,
					})
					caption("Tier", b, {
						Position = UDim2.fromOffset(8, 4),
						Size = UDim2.fromOffset(40, 24),
						Text = item.Roman,
						TextSize = 20,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 5,
					})
					caption("Count", b, {
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -6, 1, -2),
						Size = UDim2.new(1, -12, 0, 30),
						Text = count(n),
						TextSize = 26,
						TextXAlignment = Enum.TextXAlignment.Right,
						ZIndex = 5,
					})
					b.MouseEnter:Connect(function()
						hint.Text = string.format(
							"%s: %s %s for %ds. Click to use.",
							item.Name,
							HudFormat.Multi(item.Multiplier),
							category,
							item.Duration
						)
					end)
					b.Activated:Connect(function()
						use(item)
					end)
				end
			end
		end
		empty.Text = "No potions. Win races and claim daily rewards!"
	end
	empty.Visible = shown == 0
	if entering then
		entering = false
		cascade(shownTiles)
	end
end

for name, refs in tabs do
	refs.Button.Activated:Connect(function()
		if name ~= current then
			UiFeedback.Play("TabSwitch")
		end
		current = name
		hint.Text = ""
		if name ~= "Characters" then
			leaveSelect()
		end
		render()
	end)
end
close.Activated:Connect(function()
	PanelSwitch.Close("Backpack")
end)
massSell.Activated:Connect(function()
	if selecting then
		leaveSelect()
	else
		selecting = true
		massSell.Text = "Done"
		hint.Text = "Pick characters with spares. The last copy always stays."
	end
	UiFeedback.Play("TabSwitch")
	render()
end)
massCancel.Activated:Connect(function()
	leaveSelect()
	render()
end)
massAll.Activated:Connect(function()
	for _, card in grid:GetChildren() do
		if card:FindFirstChild("Picked") and not card:FindFirstChild("Dim") and card.Visible then
			setSelected(card, card.Name, true)
		end
	end
	drawMassBar()
end)
massGo.Activated:Connect(function()
	local spares, money = drawMassBar()
	if spares < 1 then
		UiFeedback.Play("Denied", massGo)
		return
	end
	ItemMenu.Confirm({
		Text = string.format(
			"Are you sure you want to sell %d spare%s for $%s? The last copy of each stays.",
			spares,
			spares == 1 and "" or "s",
			HudFormat.Short(money)
		),
	}, function()
		local ids = {}
		for id in selected do
			table.insert(ids, id)
		end
		local ok = ItemMenu.Ask("SellSparesMany", massGo, "MoneyBig", ids)
		if ok then
			leaveSelect()
			render()
		end
		return ok
	end)
end)
sortButton.Activated:Connect(function()
	sortMode = SORTS[table.find(SORTS, sortMode) % #SORTS + 1]
	sortLabel.Text = "Sort: " .. sortMode
	render()
end)
search:GetPropertyChangedSignal("Text"):Connect(applySearch)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		hint.Text = ""
		entering = true
		leaveSelect()
		render()
	else
		ItemMenu.Close()
	end
end)
player.AttributeChanged:Connect(function(attr)
	local watched = attr == "SidekickBag"
		or attr == "SidekickGear"
		or attr == "RelicBag"
		or attr == "RelicGear"
		or attr:sub(1, 6) == "Boost_"
		or attr:sub(1, 3) == "Own"
		or attr:sub(1, 8) == "Equipped"
		or attr:match("^Slot%d") ~= nil
		or attr == "Team"
	if panel.Visible and watched then
		render()
	end
end)
task.spawn(function()
	local data = player:WaitForChild("GachaData")
	local function changed()
		if panel.Visible and current == "Characters" then
			render()
		end
	end
	data.ChildAdded:Connect(changed)
	data.ChildRemoved:Connect(changed)
	-- The models load in the background: redraw an open grid once they arrive.
	local models = ReplicatedStorage:WaitForChild("CharacterModels")
	if models:GetAttribute("Ready") ~= true then
		models:GetAttributeChangedSignal("Ready"):Wait()
	end
	changed()
end)
-- Same band as the other panels; short panels (phones) shrink the six tabs to fit.
require(script.Parent:WaitForChild("PanelFrame")).Attach(panel, {
	Theme = "Backpack",
	Title = "Backpack",
	Icon = Icons.Items.Image,
	TitleObject = header.Title,
	Close = close,
	MaxWidth = 760,
	TitleEnd = UDim.new(0.5, -80), -- the Toolbar starts at 0.5, -76
})
require(script.Parent:WaitForChild("PanelFrame")).CloseOnOutsideClick(panel, function()
	PanelSwitch.Close("Backpack")
end)
local function fitTabs()
	local ancestor = rail.AbsoluteSize.X / 96 -- PanelBand scale; the rail is 96 design px wide
	if ancestor <= 0 then
		return
	end
	-- As Client/MarketUi: on phones the tabs may shrink below 0.4 so all stay inside the rail (owner 2026-10-28).
	local phone = workspace.CurrentCamera.ViewportSize.Y <= 500
	local gap = phone and 2 or 6 -- six tabs need the phone rail's gaps too
	rail.Layout.Padding = UDim.new(0, gap)
	local scale = math.clamp((rail.AbsoluteSize.Y / ancestor - 5 * gap) / (6 * 96), phone and 0.1 or 0.4, 1)
	for _, refs in tabs do
		refs.Scale.Scale = scale
	end
end
rail:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTabs)
fitTabs()
UiTheme.Apply(root)
