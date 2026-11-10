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
local SidekickReveal = require(script.Parent:WaitForChild("SidekickReveal"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))

local Palette = UiTheme.Palette
local ICON = require(script.Parent.RollToast.Ui:WaitForChild("HudIcons")).Items.Image -- the Backpack's logo
local SPACE = AnimeSkin.Space
local px = AnimeSkin.Px
-- Desktop px (AnimeSkin.Px scales them on phones).
local MENU_WIDTH = 240 -- room for the logo and a title after it
local CHEST_WIDTH = 260 -- its odds rows need more than an item's menu
local CONFIRM_WIDTH = 380
local QUESTION_HEIGHT = 60 -- three Body lines
local NOTE_HEIGHT = 16 -- one Caption line
local ODDS_ROW = 16
local MAX_WIDTH = 64
local CARD_SIZE = Vector2.new(112, 128)
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
	Font = UiTheme.Font,
	Text = "",
	AutoButtonColor = false,
})

-- A label in one of AnimeSkin's five text roles; `color` (a rarity or state) wins over the role's colour.
local function caption(name, parent, props, role, color)
	props.BackgroundTransparency = 1
	local label = AnimeSkin.Label(make("TextLabel", name, parent, props), role)
	if color then
		label.TextColor3 = color
		task.defer(function() -- after the role's own deferred pass
			label.TextColor3 = color
		end)
	end
	return label
end

-- `tone`: an AnimeSkin.Button tone (Go, Idle, Danger, Gold).
local function action(name, parent, text, tone, props)
	props = props or {}
	props.Text = text
	props.TextSize = props.TextSize or px(AnimeSkin.Size.Body)
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local button = make("TextButton", name, parent, props)
	AnimeSkin.Button(button, tone)
	return button
end

local function setEnabled(button, on, tone)
	button.Active = on
	AnimeSkin.Button(button, tone)
	if not on then
		button.BackgroundColor3 = Palette.Disabled
	end
end

-- The standard header on a popup (design doc 4.42): strip, the Backpack's logo, ALL CAPS title, art close if any.
local function header(frame, title, close)
	AnimeSkin.Header(frame, {
		Header = make("Frame", "Header", frame, { BackgroundTransparency = 1 }),
		Title = title,
		Icon = make("ImageLabel", "Icon", frame, { Image = ICON }),
		Close = close,
	})
end

local function card(name)
	local frame = make("Frame", name, root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Active = true,
		Visible = false,
		ZIndex = 2,
	})
	AnimeSkin.Body(frame)
	return frame
end

-- The small menu ---------------------------------------------------------------------------------------------------------
local menu = make("Frame", "Menu", root, { Active = true, Visible = false, ZIndex = 2 })
AnimeSkin.Body(menu)
local menuTitle = caption("Title", menu, { Text = "" }, "Title")
header(menu, menuTitle, nil)
local menuEquip = action("Equip", menu, "Equip", "Go")
local menuSell = action("Sell", menu, "Sell", "Danger")
local menuNote = caption("Note", menu, { Text = "", Visible = false }, "Caption")
-- A chest's own: Open and its odds (docs/RELIC_SPEC.md "Chests").
local menuOpen = action("Open", menu, "Open", "Go", { Visible = false })
local menuOdds = make("Frame", "Odds", menu, { BackgroundTransparency = 1, Visible = false })
make("UIListLayout", "List", menuOdds, { SortOrder = Enum.SortOrder.LayoutOrder })

-- Rows under the header: 16 insets, 12 gaps, 40 tall buttons. Returns the menu's height. Laid out at each open, so a
-- phone / desktop switch takes the right tokens.
local function layMenu(lines, note)
	local inset, gap, row = px(SPACE.Inset), px(SPACE.Gap), px(SPACE.Button)
	local y = AnimeSkin.Top(false)
	for _, button in { menuEquip, menuOpen } do
		button.Position, button.Size = UDim2.fromOffset(inset, y), UDim2.new(1, -2 * inset, 0, row)
	end
	y += row + gap
	menuSell.Position, menuSell.Size = UDim2.fromOffset(inset, y), UDim2.new(1, -2 * inset, 0, row)
	menuOdds.Position, menuOdds.Size = UDim2.fromOffset(inset, y), UDim2.new(1, -2 * inset, 0, lines * px(ODDS_ROW))
	if lines > 0 then
		return y + lines * px(ODDS_ROW) + px(SPACE.BottomClear)
	end
	y += row
	menuNote.Position, menuNote.Size = UDim2.fromOffset(inset, y + gap), UDim2.new(1, -2 * inset, 0, px(NOTE_HEIGHT))
	return y + (note and gap + px(NOTE_HEIGHT) or 0) + px(SPACE.BottomClear) -- Sell sits at the bottom-left
end

-- The confirmation -------------------------------------------------------------------------------------------------------
local confirm = card("Confirm")
local confirmTitle = caption("Title", confirm, { Text = "" }, "Title")
local confirmNo = make("TextButton", "Cancel", confirm, { Text = "Cancel", AutoButtonColor = false })
header(confirm, confirmTitle, confirmNo)
local confirmText = caption("Question", confirm, { Text = "", TextWrapped = true }, "Body")
local stepper = make("Frame", "Stepper", confirm, { BackgroundTransparency = 1, Visible = false })
local stepLess = action("Less", stepper, "-", "Idle", { TextSize = px(AnimeSkin.Size.Item) })
local stepCount = caption("Count", stepper, { Text = "" }, "Item")
local stepMore =
	action("More", stepper, "+", "Idle", { AnchorPoint = Vector2.new(1, 0), TextSize = px(AnimeSkin.Size.Item) })
local stepMax = action("Max", stepper, "Max", "Idle", { AnchorPoint = Vector2.new(1, 0) })
local confirmYes = action("Yes", confirm, "Sell", "Danger")

local function layConfirm()
	local inset, gap, row = px(SPACE.Inset), px(SPACE.Gap), px(SPACE.Button)
	local y = AnimeSkin.Top(false)
	local question = px(QUESTION_HEIGHT)
	confirmText.Position, confirmText.Size = UDim2.fromOffset(inset, y), UDim2.new(1, -2 * inset, 0, question)
	y += question + gap
	stepper.Position, stepper.Size = UDim2.fromOffset(inset, y), UDim2.new(1, -2 * inset, 0, row)
	local maxWidth = px(MAX_WIDTH)
	stepLess.Size, stepMore.Size = UDim2.fromOffset(row, row), UDim2.fromOffset(row, row)
	stepMore.Position = UDim2.new(1, -maxWidth - gap, 0, 0)
	stepMax.Position, stepMax.Size = UDim2.fromScale(1, 0), UDim2.fromOffset(maxWidth, row)
	stepCount.Position = UDim2.fromOffset(row + gap, 0)
	stepCount.Size = UDim2.new(1, -2 * (row + gap) - maxWidth - gap, 1, 0)
	if stepper.Visible then
		y += row + gap
	end
	confirmYes.Position, confirmYes.Size = UDim2.fromOffset(inset, y), UDim2.new(1, -2 * inset, 0, row)
	confirm.Size = UDim2.fromOffset(px(CONFIRM_WIDTH), y + row + px(SPACE.BottomClear)) -- Yes spans the bottom-left
end

-- The character picker ---------------------------------------------------------------------------------------------------
local picker = card("Picker")
picker.Size = UDim2.fromScale(0.86, 0.86)
make("UISizeConstraint", "Max", picker, { MaxSize = PICKER_MAX })
local pickerTitle = caption("Title", picker, { Text = "" }, "Title")
local pickerClose = make("TextButton", "Close", picker, { Text = "X", AutoButtonColor = false })
header(picker, pickerTitle, pickerClose)
local pickerGrid = make("ScrollingFrame", "Characters", picker, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
AnimeSkin.Content(pickerGrid)
local pickerLayout = make("UIGridLayout", "Layout", pickerGrid, {
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local CARD_ART = 3 -- the card art reaches 3 px past a cell: padded so the frame never clips it
make("UIPadding", "Padding", pickerGrid, { PaddingTop = UDim.new(0, CARD_ART), PaddingBottom = UDim.new(0, CARD_ART) })
-- 12 between cards, and the visible height holds whole rows only (design doc 4.42).
local function fitPicker()
	local gap = px(SPACE.Gap)
	local height = pickerGrid.AbsoluteSize.Y - 2 * CARD_ART
	if height <= 0 then
		return
	end
	local rows = math.max(1, math.floor((height + gap) / (px(CARD_SIZE.Y) + gap) + 0.5))
	pickerLayout.CellSize = UDim2.fromOffset(px(CARD_SIZE.X), math.floor((height + gap) / rows) - gap)
	pickerLayout.CellPadding = UDim2.fromOffset(gap, gap)
end
pickerGrid:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPicker)
fitPicker()

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
	return fine, message
end

-- A sale's question. `options`: Text (string), Label, and for a quantity Limit (a whole number) and Words (count -> string).
-- `yes(count)` runs on Sell and returns whether the dialog may close.
function ItemMenu.Confirm(options, yes)
	hideAll()
	root.Enabled = true
	confirmYes.Text = options.Label or "Sell"
	confirmTitle.Text = options.Label or "Sell"
	stepper.Visible = options.Limit ~= nil
	layConfirm()
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
		-- Angular art (design doc 4.42): white for the one wearing it (and Secret, as the Index), else the rarity.
		AnimeSkin.Card(
			tile,
			(worn == entry or spec.Rarity == "Secret") and Color3.new(1, 1, 1)
				or GachaConfig.RARITY_COLORS[spec.Rarity]
				or AnimeSkin.Tint.Default
		)
		tile.Rim.Visible = false
		caption("CharacterName", tile, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -8),
			Size = UDim2.new(1, -16, 0, 22),
			Text = spec.Name,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 7,
		}, "Item")
		if worn then
			local wornRow = rows[worn]
			caption("Worn", tile, {
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 0, 16),
				Text = worn == entry and "WEARING" or (wornRow and wornRow.Name or kind.Noun),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 7,
			}, "Caption", worn == entry and Palette.Money or SidekickView.RarityColor(wornRow and wornRow.Rarity))
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
	fitPicker()
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

-- Beside `anchor`, kept on screen with room for the logo that overhangs the top left. Works in screen pixels: this gui
-- ignores the inset, so a gui that does not is shifted by it.
local function placeMenu(anchor, height, width)
	width = px(width or MENU_WIDTH)
	local logoLeft = math.floor(px(SPACE.Header) * 0.2) + 4 -- AnimeSkin.Header's logo offset
	local logoTop = math.floor(px(SPACE.Header) * 0.45) + 4
	local gui = anchor:FindFirstAncestorOfClass("ScreenGui")
	local inset = gui and not gui.IgnoreGuiInset and GuiService:GetGuiInset().Y or 0
	local screen = workspace.CurrentCamera.ViewportSize
	local gap = px(SPACE.Gap)
	local x = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + gap + logoLeft
	if x + width > screen.X then
		x = anchor.AbsolutePosition.X - width - gap
	end
	local y = anchor.AbsolutePosition.Y + inset
	menu.Size = UDim2.fromOffset(width, height)
	menu.Position = UDim2.fromOffset(
		math.clamp(x, logoLeft, math.max(logoLeft, screen.X - width - 4)),
		math.clamp(y, logoTop, math.max(logoTop, screen.Y - height - 4))
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
menuOpen.Activated:Connect(function()
	if menuOpen.Active and menuAct.Open then
		menuAct.Open()
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
	menuEquip.Visible, menuSell.Visible = true, true
	menuOpen.Visible, menuOdds.Visible = false, false
	local price = row and kind.Price(row)
	menuTitle.Text = row and row.Name or kind.Noun
	menuEquip.Text = wearer and "Take off" or "Equip"
	menuSell.Text = price and "Sell " .. price or "Sell"
	setEnabled(menuEquip, true, wearer and "Idle" or "Go")
	setEnabled(menuSell, price ~= nil and wearer == nil, "Danger")
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
	placeMenu(anchor, layMenu(0, wearer ~= nil))
	menu.Visible = true
	UiMotion.Pop(menu, 0.06)
end

-- The menu of a chest tile, which stands for every entry of chest `id`: Open takes the first. Only the server's answer opens the reveal.
function ItemMenu.OpenChest(id, anchor)
	local chest = RelicConfig.Chests[id]
	hideAll()
	root.Enabled = true
	menuTitle.Text = chest.Name
	menuEquip.Visible, menuSell.Visible, menuNote.Visible = false, false, false
	menuOpen.Visible, menuOdds.Visible = true, true
	setEnabled(menuOpen, true, "Go")
	for _, child in menuOdds:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local lines = {}
	for order, row in RelicConfig.ChestOdds(id) do
		lines[order] = {
			("%s %s%%"):format(row.Name, tostring(row.Odds)),
			row.Rarity ~= "Secret" and SidekickView.RarityColor(row.Rarity) or nil, -- Secret's black would not read here
		}
	end
	table.insert(lines, { ("Big Raga %g%%"):format(chest.SidekickChance * 100) })
	for order, line in lines do
		caption("Row" .. order, menuOdds, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, px(ODDS_ROW)),
			Text = line[1],
		}, "Caption", line[2])
	end
	menuAct.Open = function()
		local entry = nil
		for _, item in SidekickView.RelicBag(player) do
			if item.Id == id then
				entry = item.Entry
				break
			end
		end
		setEnabled(menuOpen, false, "Go")
		local fine, won = ask("RelicOpenChest", menuOpen, "Equip", function(message)
			menuTitle.Text = message
		end, entry)
		setEnabled(menuOpen, true, "Go")
		if fine then
			hideAll()
			local results = { { Row = RelicConfig.Get(won.Relic) } }
			if won.Sidekick then
				table.insert(results, { Id = "side_raga" })
			end
			SidekickReveal.Play(results, function() end, chest.Image)
		end
	end
	placeMenu(anchor, layMenu(#lines, false), CHEST_WIDTH)
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
