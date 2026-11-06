--!nonstrict
-- The click flow for Sidekicks and Relics (design doc 4.36, docs/SIDEKICK_SPEC.md "Click menu"), used by the Bag and the Index:
-- a small menu at the tile, a sale confirmation, and a picker of the player's own characters. Also the confirmation for character
-- sales (docs/BAG_AND_AUTOSELL_SPEC.md). Only asks: the server decides every equip and sale; panels redraw from its attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local BagConfig = require(shared:WaitForChild("BagConfig"))
local CharacterCatalog = require(shared:WaitForChild("CharacterCatalog"))
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local RelicConfig = require(shared:WaitForChild("RelicConfig"))
local SidekickConfig = require(shared:WaitForChild("SidekickConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local Components = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("RacerComponents"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local Palette = UiTheme.Palette
local MENU_WIDTH = 170 -- px
local MENU_ROW = 40 -- px
local MENU_GAP = 6 -- px
local CARD_SIZE = UDim2.fromOffset(112, 128)
local PICKER_MAX = Vector2.new(640, 460) -- px: a phone gets its screen's share instead

local KINDS = {
	Sidekick = {
		Noun = "Sidekick",
		Row = SidekickConfig.Get,
		Bag = SidekickView.Bag,
		Gear = SidekickView.Gear,
		Equip = "SidekickEquip",
		Sell = "SidekickSell",
		Price = function(row)
			return row.SellGems and row.SellGems .. " Gems"
		end,
	},
	Relic = {
		Noun = "Relic",
		Row = RelicConfig.Get,
		Bag = SidekickView.RelicBag,
		Gear = SidekickView.RelicGear,
		Equip = "RelicEquip",
		Sell = "RelicSell",
		Price = function(row)
			local price = BagConfig.SELL_PRICE[row.Rarity]
			return price and "$" .. HudFormat.Short(price)
		end,
	},
}

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local root = make("ScreenGui", "RacerItemMenu", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 30, -- above every panel, under the summon reveal's effects
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
})
-- A press outside closes the top layer. It also keeps that press from reaching the panel underneath.
local scrim = make("TextButton", "Scrim", root, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = UiTheme.Outline,
	BackgroundTransparency = 0.55,
	Text = "",
	AutoButtonColor = false,
})

local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = UiTheme.Font
	props.TextColor3 = props.TextColor3 or Palette.White
	props.TextScaled = true
	local label = make("TextLabel", name, parent, props)
	make("UITextSizeConstraint", "Max", label, { MaxTextSize = props.TextSize or 20 })
	UiTheme.Stroke(label, 2)
	return label
end

local function action(name, parent, text, color, props)
	props = props or {}
	props.BackgroundColor3 = color
	props.Font = UiTheme.Font
	props.Text = text
	props.TextColor3 = Palette.White
	props.TextSize = props.TextSize or 18
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local button = make("TextButton", name, parent, props)
	UiTheme.Corner(button, "M")
	UiTheme.Stroke(button, 3, UiTheme.Outline, true)
	return button
end

local function setEnabled(button, on, color)
	button.Active = on
	button.BackgroundColor3 = on and color or Palette.Disabled
end

local function card(name, size)
	local frame = make("Frame", name, root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		Active = true,
		Visible = false,
		ZIndex = 2,
	})
	UiTheme.Body(frame)
	UiTheme.Corner(frame, "L")
	UiTheme.Stroke(frame, 3, UiTheme.Outline, true)
	return frame
end

-- The small menu ---------------------------------------------------------------------------------------------------------
local menu =
	make("Frame", "Menu", root, { Size = UDim2.fromOffset(MENU_WIDTH, 0), Active = true, Visible = false, ZIndex = 2 })
UiTheme.Body(menu)
UiTheme.Corner(menu, "M")
UiTheme.Stroke(menu, 3, UiTheme.Outline, true)
local menuTitle = caption("Title", menu, {
	Position = UDim2.fromOffset(8, 6),
	Size = UDim2.new(1, -16, 0, 24),
	Text = "",
	TextSize = 18,
})
local menuEquip = action("Equip", menu, "Equip", Palette.MoneyDeep, {
	Position = UDim2.fromOffset(8, 36),
	Size = UDim2.new(1, -16, 0, MENU_ROW),
})
local menuSell = action("Sell", menu, "Sell", Palette.Danger, {
	Position = UDim2.fromOffset(8, 36 + MENU_ROW + MENU_GAP),
	Size = UDim2.new(1, -16, 0, MENU_ROW),
})
local menuNote = caption("Note", menu, {
	Position = UDim2.fromOffset(8, 36 + 2 * (MENU_ROW + MENU_GAP)),
	Size = UDim2.new(1, -16, 0, 18),
	Text = "",
	TextColor3 = Palette.Gold,
	TextSize = 14,
	Visible = false,
})

-- The confirmation -------------------------------------------------------------------------------------------------------
local confirm = card("Confirm", UDim2.fromOffset(340, 190))
local confirmText = caption("Question", confirm, {
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 70),
	Text = "",
	TextWrapped = true,
	TextSize = 22,
})
local stepper = make("Frame", "Stepper", confirm, {
	Position = UDim2.fromOffset(14, 84),
	Size = UDim2.new(1, -28, 0, 36),
	BackgroundTransparency = 1,
	Visible = false,
})
local stepLess = action("Less", stepper, "-", Palette.Row, { Size = UDim2.fromOffset(48, 36), TextSize = 24 })
local stepCount = caption("Count", stepper, {
	Position = UDim2.fromOffset(52, 0),
	Size = UDim2.new(1, -176, 1, 0),
	Text = "",
	TextSize = 24,
})
local stepMore = action("More", stepper, "+", Palette.Row, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -68, 0, 0),
	Size = UDim2.fromOffset(48, 36),
	TextSize = 24,
})
local stepMax = action("Max", stepper, "Max", Palette.Row, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(62, 36),
	TextSize = 16,
})
local confirmYes = action("Yes", confirm, "Sell", Palette.Danger, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -14, 1, -12),
	Size = UDim2.new(0.5, -20, 0, 44),
})
local confirmNo = action("Cancel", confirm, "Cancel", Palette.Row, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 14, 1, -12),
	Size = UDim2.new(0.5, -20, 0, 44),
})

-- The character picker ---------------------------------------------------------------------------------------------------
local picker = card("Picker", UDim2.fromScale(0.86, 0.86))
make("UISizeConstraint", "Max", picker, { MaxSize = PICKER_MAX })
local pickerTitle = caption("Title", picker, {
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.new(1, -90, 0, 34),
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextSize = 24,
})
local pickerClose = action("Close", picker, "X", Palette.Danger, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 8),
	Size = UDim2.fromOffset(44, 36),
})
local pickerGrid = make("ScrollingFrame", "Characters", picker, {
	Position = UDim2.fromOffset(10, 50),
	Size = UDim2.new(1, -20, 1, -60),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIGridLayout", "Layout", pickerGrid, {
	CellSize = CARD_SIZE,
	CellPadding = UDim2.fromOffset(8, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
})
make("UIPadding", "Padding", pickerGrid, { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) })

-- Flow -------------------------------------------------------------------------------------------------------------------
local ItemMenu = {}
local busy = false
local onConfirm = nil
local onScrim = nil
local stepValue, stepLimit, stepWords = 1, 1, nil

local function hideAll()
	root.Enabled = false
	menu.Visible, confirm.Visible, picker.Visible = false, false, false
	onConfirm, onScrim = nil, nil
	for _, child in pickerGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end
ItemMenu.Close = hideAll

scrim.Activated:Connect(function()
	if onScrim then
		onScrim()
	else
		hideAll()
	end
end)
pickerClose.Activated:Connect(hideAll)
confirmNo.Activated:Connect(hideAll)

local function drawStep()
	stepCount.Text = stepValue .. " / " .. stepLimit
	confirmText.Text = stepWords(stepValue)
end
local function step(to)
	stepValue = math.clamp(to, 1, stepLimit)
	drawStep()
end
stepLess.Activated:Connect(function()
	step(stepValue - 1)
end)
stepMore.Activated:Connect(function()
	step(stepValue + 1)
end)
stepMax.Activated:Connect(function()
	step(stepLimit)
end)

-- Asks one remote; a refusal stays visible through `show`. Returns whether the server accepted it.
local function ask(remote, button, cue, show, ...)
	if busy then
		return false
	end
	busy = true
	local args = table.pack(...)
	local called, done, message = pcall(function()
		return ReplicatedStorage:WaitForChild("Remotes")
			:WaitForChild(remote)
			:InvokeServer(table.unpack(args, 1, args.n))
	end)
	busy = false
	local fine = called and done == true
	UiFeedback.Play(fine and cue or "Denied", button)
	if not fine then
		show(called and tostring(message or "Try again") or "Connection error")
	end
	return fine
end

-- A sale's question. `options`: Text (string), Label, and for a quantity Limit (a whole number) and Words (count -> string).
-- `yes(count)` runs on Sell and returns whether the dialog may close.
function ItemMenu.Confirm(options, yes)
	hideAll()
	root.Enabled = true
	confirmYes.Text = options.Label or "Sell"
	stepper.Visible = options.Limit ~= nil
	if options.Limit then
		stepLimit, stepValue, stepWords = options.Limit, options.Limit, options.Words
		drawStep()
	else
		confirmText.Text = options.Text
	end
	onConfirm = function()
		if yes(stepper.Visible and stepValue or nil) then
			hideAll()
		end
	end
	confirm.Visible = true
	UiMotion.Pop(confirm)
end
confirmYes.Activated:Connect(function()
	if onConfirm and not busy then
		onConfirm()
	end
end)

-- For the callers' character sales: asks, with a refusal shown in the dialog.
function ItemMenu.Ask(remote, button, cue, ...)
	return ask(remote, button, cue, function(message)
		confirmText.Text = message
	end, ...)
end

local function wearerOf(kind, entry)
	for character, worn in kind.Gear(player) do
		if worn == entry then
			return character
		end
	end
	return nil
end

local function ownedCharacters()
	local data = player:FindFirstChild("GachaData")
	local list = {}
	for _, spec in CharacterCatalog.All() do
		if data and data:FindFirstChild(spec.Id) then
			table.insert(list, spec)
		end
	end
	return list
end

local function openPicker(kindName, entry)
	local kind = KINDS[kindName]
	local row = nil
	local rows = {} -- entry -> catalog row, for what each character wears now
	for _, item in kind.Bag(player) do
		rows[item.Entry] = kind.Row(item.Id)
		if item.Entry == entry then
			row = kind.Row(item.Id)
		end
	end
	hideAll()
	root.Enabled = true
	pickerTitle.Text = "Equip " .. (row and row.Name or kind.Noun) .. " on"
	local gear = kind.Gear(player)
	for order, spec in ownedCharacters() do
		local worn = gear[spec.Id]
		local tile =
			make("TextButton", spec.Id, pickerGrid, { LayoutOrder = order, Text = "", AutoButtonColor = false })
		Components.CardFace(tile, spec, GachaConfig)
		Components.CardArt(tile, spec)
		UiTheme.Stroke(tile, 3, worn == entry and Palette.Money or UiTheme.Outline, true)
		caption("CharacterName", tile, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -6),
			Size = UDim2.new(1, -12, 0, 22),
			Text = spec.Name,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 18,
			ZIndex = 7,
		})
		if worn then
			local wornRow = rows[worn]
			caption("Worn", tile, {
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.new(1, -12, 0, 16),
				Text = worn == entry and "WEARING" or (wornRow and wornRow.Name or kind.Noun),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = worn == entry and Palette.Money or SidekickView.RarityColor(wornRow and wornRow.Rarity),
				TextSize = 14,
				ZIndex = 7,
			})
		end
		tile.Activated:Connect(function()
			local refused = function(message)
				pickerTitle.Text = message
			end
			if worn == entry or ask(kind.Equip, tile, "Equip", refused, spec.Id, entry) then
				hideAll()
			end
		end)
	end
	picker.Visible = true
	UiMotion.Pop(picker)
end

local function openSale(kindName, entry, row)
	local kind = KINDS[kindName]
	ItemMenu.Confirm({
		Text = string.format("Are you sure you want to sell %s for %s?", row.Name, kind.Price(row)),
	}, function()
		return ItemMenu.Ask(kind.Sell, confirmYes, "UpgradeBought", entry)
	end)
end

-- Beside `anchor`, kept on screen. Works in screen pixels: this gui ignores the inset, so a gui that does not is shifted by it.
local function placeMenu(anchor, height)
	local gui = anchor:FindFirstAncestorOfClass("ScreenGui")
	local inset = gui and not gui.IgnoreGuiInset and GuiService:GetGuiInset().Y or 0
	local screen = workspace.CurrentCamera.ViewportSize
	local x = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + MENU_GAP
	if x + MENU_WIDTH > screen.X then
		x = anchor.AbsolutePosition.X - MENU_WIDTH - MENU_GAP
	end
	local y = anchor.AbsolutePosition.Y + inset
	menu.Size = UDim2.fromOffset(MENU_WIDTH, height)
	menu.Position = UDim2.fromOffset(
		math.clamp(x, 4, math.max(4, screen.X - MENU_WIDTH - 4)),
		math.clamp(y, 4, math.max(4, screen.Y - height - 4))
	)
end

local menuAct = {}
menuEquip.Activated:Connect(function()
	if menuEquip.Active and menuAct.Equip then
		menuAct.Equip()
	end
end)
menuSell.Activated:Connect(function()
	if menuSell.Active and menuAct.Sell then
		menuAct.Sell()
	else
		UiFeedback.Play("Denied", menuSell)
	end
end)

-- The menu of one bag entry (`kindName`: "Sidekick" or "Relic"), beside the tile that was pressed.
function ItemMenu.Open(kindName, entry, anchor)
	local kind = KINDS[kindName]
	local row = nil
	for _, item in kind.Bag(player) do
		if item.Entry == entry then
			row = kind.Row(item.Id)
		end
	end
	local wearer = wearerOf(kind, entry)
	hideAll()
	root.Enabled = true
	local price = row and kind.Price(row)
	menuTitle.Text = row and row.Name or kind.Noun
	menuEquip.Text = wearer and "Take off" or "Equip"
	menuSell.Text = price and "Sell " .. price or "Sell"
	setEnabled(menuEquip, true, wearer and Palette.Row or Palette.MoneyDeep)
	setEnabled(menuSell, price ~= nil and wearer == nil, Palette.Danger)
	menuNote.Visible = wearer ~= nil
	menuNote.Text = wearer and "Take it off first" or ""
	menuAct.Equip = wearer
			and function()
				if
					ask(kind.Equip, menuEquip, "Equip", function(message)
						menuNote.Text, menuNote.Visible = message, true
					end, wearer, nil)
				then
					hideAll()
				end
			end
		or function()
			openPicker(kindName, entry)
		end
	menuAct.Sell = function()
		openSale(kindName, entry, row)
	end
	placeMenu(anchor, 36 + 2 * MENU_ROW + MENU_GAP + (wearer and 26 or 10))
	menu.Visible = true
	UiMotion.Pop(menu, 0.06)
end

-- From an Index tile, which stands for a catalog id: its first free entry, otherwise its first worn one (SIDEKICK_SPEC).
function ItemMenu.OpenId(kindName, id, anchor)
	local kind = KINDS[kindName]
	local gear, worn = kind.Gear(player), {}
	for _, entry in gear do
		worn[entry] = true
	end
	local pick = nil
	for _, item in kind.Bag(player) do
		if item.Id == id then
			if not worn[item.Entry] then
				pick = item.Entry
				break
			end
			pick = pick or item.Entry
		end
	end
	if pick then
		ItemMenu.Open(kindName, pick, anchor)
	end
end

return ItemMenu
