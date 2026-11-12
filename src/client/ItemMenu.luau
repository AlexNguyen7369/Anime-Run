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
local U = AnimeSkin.Units
-- Popup sizes in px, the frame's 1200 x 620 aspect (design doc 4.42: the old heights, 1.3 x wider) (the frame draws at k = px / units); a small screen scales them down.
local MENU_SIZE = Vector2.new(600, 310)
local CONFIRM_SIZE = Vector2.new(730, 377)
local PICKER_SIZE = Vector2.new(938, 485)
-- Design units.
local ODDS_ROW = 28 -- one Caption line
local NOTE_HEIGHT = 28
local QUESTION_HEIGHT = 120 -- three Body lines
local MAX_WIDTH = 120
local CARD_MIN_WIDTH, CARD_HEIGHT = 140, 170 -- picker cells: as many columns as fit, whole rows near this height
local CARD_ART = 3 -- px: the card art reaches 3 px past a cell, padded so the frame never clips it

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

local function label(name, parent, props)
	props.BackgroundTransparency = 1
	return make("TextLabel", name, parent, props)
end

-- A text role through the popup's frame `g`; the label's own colour (a rarity or state) stays.
local function keepColor(g, object, role)
	local color = object:GetAttribute("AnimeColor")
	g.Role(object, role)
	if color then
		object.TextColor3 = color
	end
end
local function caption(g, name, parent, props, role, color)
	local object = label(name, parent, props)
	if color then
		object:SetAttribute("AnimeColor", color)
	end
	keepColor(g, object, role)
	return object
end

local function action(name, parent, text, props)
	props = props or {}
	props.Text = text
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	return make("TextButton", name, parent, props)
end

-- `tone`: an AnimeSkin.Button tone (Go, Idle, Danger, Gold).
local function setEnabled(g, button, on, tone)
	button.Active = on
	g.Button(button, tone)
	if not on then
		button.BackgroundColor3 = Palette.Disabled
	end
end

-- `size` px, kept inside the screen (the frame's chrome and logo overhang it).
local function fit(frame, size)
	local screen = workspace.CurrentCamera.ViewportSize
	local s = math.min(1, screen.X * 0.8 / size.X, screen.Y * 0.7 / size.Y)
	frame.Size = UDim2.fromOffset(math.floor(size.X * s), math.floor(size.Y * s))
end

local function popup(name, size)
	local frame = make("Frame", name, root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Active = true,
		Visible = false,
		ZIndex = 2,
	})
	return frame
end

-- The small menu ---------------------------------------------------------------------------------------------------------
local menu = popup("Menu", MENU_SIZE)
menu.AnchorPoint, menu.Position = Vector2.zero, UDim2.new()
local menuTitle = label("Title", menu, { Text = "" })
local mg = AnimeSkin.IndexFrame(menu, { Title = menuTitle, Logo = ICON })
local menuEquip = action("Equip", menu, "Equip")
local menuSell = action("Sell", menu, "Sell")
local menuNote = caption(mg, "Note", menu, { Text = "", Visible = false }, "Caption")
-- A chest's own: Open and its odds (docs/RELIC_SPEC.md "Chests").
local menuOpen = action("Open", menu, "Open", { Visible = false })
local menuOdds = make("Frame", "Odds", menu, { BackgroundTransparency = 1, Visible = false })
make("UIListLayout", "List", menuOdds, { SortOrder = Enum.SortOrder.LayoutOrder })
setEnabled(mg, menuEquip, true, "Go")
setEnabled(mg, menuSell, true, "Danger")
setEnabled(mg, menuOpen, true, "Go")

-- In the content area: Equip (or Open), Sell (or the odds) and the note, 44 tall, 12 apart.
mg.OnLayout(function(g)
	local c, step = g.Content, U.Button + U.Gap
	g.Place(menuEquip, c.X, c.Y, c.W, U.Button)
	g.Place(menuOpen, c.X, c.Y, c.W, U.Button)
	g.Place(menuSell, c.X, c.Y + step, c.W, U.Button)
	g.Place(menuNote, c.X, c.Y + 2 * step, c.W, NOTE_HEIGHT)
	g.Place(menuOdds, c.X, c.Y + step, c.W, c.H - step)
	for _, button in { menuEquip, menuOpen, menuSell } do
		g.Role(button, "Item")
	end
	keepColor(g, menuNote, "Caption")
	for _, row in menuOdds:GetChildren() do
		if row:IsA("TextLabel") then
			row.Size = UDim2.new(1, 0, 0, g.px(ODDS_ROW))
			keepColor(g, row, "Caption")
		end
	end
end)

-- The confirmation -------------------------------------------------------------------------------------------------------
local confirm = popup("Confirm", CONFIRM_SIZE)
local confirmTitle = label("Title", confirm, { Text = "" })
local cg = AnimeSkin.IndexFrame(confirm, { Title = confirmTitle, Logo = ICON })
local confirmText = caption(cg, "Question", confirm, { Text = "", TextWrapped = true }, "Body")
local stepper = make("Frame", "Stepper", confirm, { BackgroundTransparency = 1, Visible = false })
local stepLess = action("Less", stepper, "-")
local stepCount = caption(cg, "Count", stepper, { Text = "" }, "Item")
local stepMore = action("More", stepper, "+")
local stepMax = action("Max", stepper, "Max")
local confirmYes = action("Yes", confirm, "Sell")
local confirmNo = action("Cancel", confirm, "Cancel")
for _, button in { stepLess, stepMore, stepMax, confirmNo } do
	cg.Button(button, "Idle")
end
cg.Button(confirmYes, "Danger")

-- The question (Body), the stepper (Less, count, More, Max) under it, Yes and Cancel at the bottom of the content.
local function layConfirm(g)
	local c = g.Content
	local row = U.Button
	local bottomY = c.Y + c.H - row
	local question = stepper.Visible and QUESTION_HEIGHT or bottomY - U.Gap - c.Y
	g.Place(confirmText, c.X, c.Y, c.W, question)
	g.Place(stepper, c.X, c.Y + question + U.Gap, c.W, row)
	g.Place(stepLess, 0, 0, row, row)
	g.Place(stepCount, row + U.Gap, 0, c.W - 3 * (row + U.Gap) - MAX_WIDTH + row, row)
	g.Place(stepMore, c.W - MAX_WIDTH - U.Gap - row, 0, row, row)
	g.Place(stepMax, c.W - MAX_WIDTH, 0, MAX_WIDTH, row)
	local half = (c.W - U.Gap) / 2
	g.Place(confirmYes, c.X, bottomY, half, row)
	g.Place(confirmNo, c.X + half + U.Gap, bottomY, half, row)
	g.Role(confirmText, "Body")
	g.Role(stepCount, "Item")
	for _, button in { stepLess, stepMore, stepMax, confirmYes, confirmNo } do
		g.Role(button, "Item")
	end
end
cg.OnLayout(layConfirm)

-- The character picker ---------------------------------------------------------------------------------------------------
local picker = popup("Picker", PICKER_SIZE)
local pickerTitle = label("Title", picker, { Text = "" })
local pickerClose = action("Close", picker, "X")
local pg = AnimeSkin.IndexFrame(picker, { Title = pickerTitle, Close = pickerClose, Logo = ICON })
local pickerGrid = make("ScrollingFrame", "Characters", picker, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, -- the bar sits beside the cards, not on them
})
local pickerLayout = make("UIGridLayout", "Layout", pickerGrid, { SortOrder = Enum.SortOrder.LayoutOrder })
make("UIPadding", "Padding", pickerGrid, {
	PaddingTop = UDim.new(0, CARD_ART),
	PaddingBottom = UDim.new(0, CARD_ART),
	PaddingLeft = UDim.new(0, CARD_ART),
	PaddingRight = UDim.new(0, CARD_ART),
})
-- The grid fills the content area: 12 between cards, cells fill the width, the height holds whole rows only.
pg.OnLayout(function(g)
	local c = g.Content
	g.Place(pickerGrid, c.X, c.Y, c.W, c.H)
	local bar = g.px(8)
	pickerGrid.ScrollBarThickness = bar
	local gap = g.px(U.Gap)
	local width = g.px(c.W) - bar - 2 * CARD_ART
	local height = g.px(c.H) - 2 * CARD_ART
	local columns = math.max(1, math.floor((width + gap) / (g.px(CARD_MIN_WIDTH) + gap)))
	local rows = math.max(1, math.floor((height + gap) / (g.px(CARD_HEIGHT) + gap) + 0.5))
	pickerLayout.CellSize =
		UDim2.fromOffset(math.floor((width - (columns - 1) * gap) / columns), math.floor((height + gap) / rows) - gap)
	pickerLayout.CellPadding = UDim2.fromOffset(gap, gap)
end)

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
	fit(confirm, CONFIRM_SIZE)
	layConfirm(cg)
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
		-- 12 units of card padding (design doc 4.42).
		caption(pg, "CharacterName", tile, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -pg.px(U.Pad), 1, -pg.px(U.Pad)),
			Size = UDim2.new(1, -2 * pg.px(U.Pad), 0, pg.px(34)),
			Text = spec.Name,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 7,
		}, "Item")
		if worn then
			local wornRow = rows[worn]
			caption(pg, "Worn", tile, {
				Position = pg.at(U.Pad, U.Pad),
				Size = UDim2.new(1, -2 * pg.px(U.Pad) - pg.px(36), 0, pg.px(24)), -- clear of the category dot
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
	fit(picker, PICKER_SIZE)
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

-- Beside `anchor`, kept on screen with the frame's chrome and the logo that overhangs the top left (AnimeSkin.IndexFrame:
-- chrome 40 units past the sides, 70 above, 30 below; logo 72 above). Works in screen pixels: this gui ignores the
-- inset, so a gui that does not is shifted by it.
local function placeMenu(anchor)
	fit(menu, MENU_SIZE)
	local W = AnimeSkin.Compact() and U.PhoneW or U.W
	local H = AnimeSkin.Compact() and U.PhoneH or U.H
	local k = math.min(menu.Size.X.Offset / W, menu.Size.Y.Offset / H)
	local width, height = math.floor(W * k), math.floor(H * k) -- the aspect constraint's box
	local function u(value)
		return math.floor(value * k + 0.5) + 4
	end
	local gui = anchor:FindFirstAncestorOfClass("ScreenGui")
	local inset = gui and not gui.IgnoreGuiInset and GuiService:GetGuiInset().Y or 0
	local screen = workspace.CurrentCamera.ViewportSize
	local x = anchor.AbsolutePosition.X + anchor.AbsoluteSize.X + u(U.Gap) + u(40)
	if x + width + u(40) > screen.X then
		x = anchor.AbsolutePosition.X - width - u(U.Gap) - u(40)
	end
	local y = anchor.AbsolutePosition.Y + inset
	menu.Position = UDim2.fromOffset(
		math.clamp(x, u(40), math.max(u(40), screen.X - width - u(40))),
		math.clamp(y, u(72), math.max(u(72), screen.Y - height - u(30)))
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
	setEnabled(mg, menuEquip, true, wearer and "Idle" or "Go")
	setEnabled(mg, menuSell, price ~= nil and wearer == nil, "Danger")
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
	placeMenu(anchor)
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
	setEnabled(mg, menuOpen, true, "Go")
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
	if chest.SidekickChance > 0 then -- its own boss's Sidekick (RELIC_SPEC "Chests": side_raga, side_mage, side_king)
		local sidekick = SidekickConfig.Get(chest.SidekickId)
		table.insert(
			lines,
			{ ("%s %g%%"):format(sidekick and sidekick.Name or "Big Raga", chest.SidekickChance * 100) }
		)
	end
	for order, line in lines do
		caption(mg, "Row" .. order, menuOdds, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, mg.px(ODDS_ROW)),
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
		setEnabled(mg, menuOpen, false, "Go")
		local fine, won = ask("RelicOpenChest", menuOpen, "Equip", function(message)
			menuTitle.Text = message
		end, entry)
		setEnabled(mg, menuOpen, true, "Go")
		if fine then
			hideAll()
			local results = { { Row = RelicConfig.Get(won.Relic) } }
			if won.Sidekick then
				table.insert(results, { Id = "side_raga" })
			end
			SidekickReveal.Play(results, function() end, chest.Image)
		end
	end
	placeMenu(anchor)
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
