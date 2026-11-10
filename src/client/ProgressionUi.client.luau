--!nonstrict
-- Progression display: all purchases and earnings are owned by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
-- The workshop / Dojo boosts one chosen stat by the squad's rarity (design doc 4.19); there is no idle gain.
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Tree = require(shared.UpgradeTree)
local Tracks = require(shared.TrackRegistry)
local Workshop = require(shared.Workshop)
local Format = require(shared.HudFormat)
local UiTheme = require(shared.UiTheme)
local Weather = require(shared.WeatherConfig)
local Boosts = require(shared.BoostConfig)
local CharacterCatalog = require(shared.CharacterCatalog)
local GachaConfig = require(shared.GachaConfig)
local Switch = require(script.Parent.PanelSwitch)
local UiFeedback = require(script.Parent.UiFeedback)
local Band = require(script.Parent.PanelBand)
local Frame = require(script.Parent.PanelFrame)
local Skin = require(script.Parent:WaitForChild("AnimeSkin"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BLUE = Color3.fromRGB(61, 151, 219)
local GREEN = Color3.fromRGB(89, 225, 138)
local RED = UiTheme.Palette.Danger
local DARK = Color3.fromRGB(29, 32, 53)

local function make(class, name, parent, properties)
	local instance = Instance.new(class)
	instance.Name = name
	for key, value in properties do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end
-- Navy gradient card with a blue glow edge (Backpack look, docs/HUD_LAYOUT_SPEC.md section 8). Opaque: panel
-- surfaces must cover the read-outs behind them.
local function plate(frame)
	UiTheme.Plate(frame, BLUE)
	frame.BackgroundTransparency = 0
	return frame
end
local themed = {}
local function screen(name, order)
	local root = make("ScreenGui", name, gui, {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = order,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	table.insert(themed, root)
	return root
end
local function text(name, parent, position, size, value)
	local label = make("TextLabel", name, parent, {
		Position = position,
		Size = size,
		Text = value,
		Font = UiTheme.Font,
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
	})
	UiTheme.Stroke(label, 1.5)
	return label
end
local function button(name, parent, position, size, value)
	local b = make("TextButton", name, parent, {
		Position = position,
		Size = size,
		Text = value,
		Font = UiTheme.Font,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = BLUE,
		AutoButtonColor = false,
	})
	make("UICorner", "Corner", b, { CornerRadius = UDim.new(0, UiTheme.Radius.S) })
	UiTheme.Stroke(b, 1.5)
	return b
end
-- A disabled button gets no hover / press highlight.
local function setActive(b, active)
	b.Active = active
end
local panels = {}
local function panel(name, title, icon)
	local root = screen("Racer" .. name, 2)
	local p = make("Frame", "Panel", root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 254),
		Size = UDim2.new(0.82, 0, 1, -344),
		BackgroundColor3 = DARK,
		Visible = false,
		Active = true,
	})
	plate(p)
	-- Design doc 4.42: the framed body art and the standard header (strip, overhanging logo, ALL CAPS title, art close).
	Skin.Body(p)
	local header = make("Frame", "Header", p, { BackgroundTransparency = 1 })
	local heading = text("Title", p, UDim2.new(), UDim2.new(), title)
	local logo = make("ImageLabel", "Icon", p, { Image = icon })
	local close = button("Close", p, UDim2.new(), UDim2.new(), "×")
	Frame.PaintClose(close)
	Skin.Header(p, { Header = header, Title = heading, Icon = logo, Close = close })
	Switch.Register(name, p)
	-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6).
	Band.Fit(p, 700)
	local function closePanel()
		Switch.Close(name)
	end
	close.Activated:Connect(closePanel)
	Frame.CloseOnOutsideClick(p, closePanel)
	panels[name] = p
	return p
end
local hud = screen("RacerProgression", 1)
-- Weather icon, bottom right (docs/WEATHER_EVENTS_SPEC.md, "Weather icon"): hover or tap shows the card.
local weather = button("WeatherIcon", hud, UDim2.new(1, -8, 1, -8), UDim2.fromOffset(44, 44), "")
weather.AnchorPoint = Vector2.new(1, 1)
weather.BackgroundColor3 = DARK
weather.TextSize = 24
local weatherCard = make("Frame", "Card", weather, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 0, 0, -6),
	Size = UDim2.fromOffset(200, 74),
	BackgroundColor3 = DARK,
	Visible = false,
})
plate(weatherCard)
local weatherTitle = text("Title", weatherCard, UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 22), "")
local weatherStats = text("Stats", weatherCard, UDim2.fromOffset(8, 26), UDim2.new(1, -16, 0, 22), "")
local weatherTime = text("Time", weatherCard, UDim2.fromOffset(8, 48), UDim2.new(1, -16, 0, 20), "")
weatherStats.TextSize = 13
weatherTime.TextSize = 13
local weatherPinned, weatherHover = false, false
local function showWeatherCard()
	weatherCard.Visible = weatherPinned or weatherHover
end
weather.Activated:Connect(function()
	-- A tap decides alone, so a second tap hides the card while the pointer still rests on the icon.
	weatherPinned = not weatherPinned
	weatherHover = false
	showWeatherCard()
end)
weather.MouseEnter:Connect(function()
	weatherHover = true
	showWeatherCard()
end)
weather.MouseLeave:Connect(function()
	weatherHover = false
	showWeatherCard()
end)

-- Active consumables share the weather status strip. The server owns the expiry attributes; this row only
-- displays the strongest active tier in each category and counts down against the server clock.
local potionStatus = make("Frame", "PotionStatus", hud, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -60, 1, -8),
	Size = UDim2.fromOffset(0, 74),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
})
local _potionLayout = make("UIListLayout", "Layout", potionStatus, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, 10),
})

-- docs/WEATHER_EVENTS_SPEC.md "Weather icon": 8 px from the right edge; on phones (viewport height <= 500) its right
-- edge is 140 px in, left of the Market button. The potion bottles stay left of it (HUD_LAYOUT_SPEC section 5).
local function placeCorner()
	local camera = workspace.CurrentCamera
	local right = camera and camera.ViewportSize.Y <= 500 and 140 or 8
	weather.Position = UDim2.new(1, -right, 1, -8)
	potionStatus.Position = UDim2.new(1, -(right + 52), 1, -8)
end
placeCorner()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeCorner)
end

local potionButtons = {}
local PotionIcons = require(script.Parent.RollToast.Ui.PotionIcons)
-- "9m 33s" under each bottle (docs/HUD_LAYOUT_SPEC.md section 5).
local function potionTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, seconds // 60 % 60)
	elseif seconds >= 60 then
		return string.format("%dm %ds", seconds // 60, seconds % 60)
	end
	return string.format("%ds", seconds)
end
for _, category in Boosts.Order do
	local icon = make("ImageButton", category .. "Potion", potionStatus, {
		Size = UDim2.fromOffset(64, 74),
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
		Visible = false,
	})
	make("ImageLabel", "Bottle", icon, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		BackgroundTransparency = 1,
		Image = PotionIcons[category] or "",
		ScaleType = Enum.ScaleType.Fit,
	})
	local timer = text("Timer", icon, UDim2.fromScale(0.5, 1), UDim2.fromOffset(84, 20), "")
	timer.AnchorPoint = Vector2.new(0.5, 1)
	timer.Font = UiTheme.Font
	timer.TextSize = 17
	timer.TextWrapped = false
	timer.ZIndex = 2
	UiTheme.Stroke(timer, 2)
	local card = make("Frame", "Card", icon, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -6),
		Size = UDim2.fromOffset(190, 72),
		BackgroundColor3 = DARK,
		Visible = false,
		ZIndex = 20,
	})
	UiTheme.Plate(card, BLUE).BackgroundTransparency = 0
	local name = text("Name", card, UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 22), "")
	name.TextSize = 14
	local effect = text("Effect", card, UDim2.fromOffset(8, 26), UDim2.new(1, -16, 0, 20), "")
	effect.TextSize = 12
	local time = text("Time", card, UDim2.fromOffset(8, 47), UDim2.new(1, -16, 0, 18), "")
	time.TextSize = 12
	local hover = false
	local function show()
		card.Visible = hover
	end
	icon.MouseEnter:Connect(function()
		hover = true
		show()
	end)
	icon.MouseLeave:Connect(function()
		hover = false
		show()
	end)
	potionButtons[category] = { Button = icon, Timer = timer, Card = card, Name = name, Effect = effect, Time = time }
end

local function strongestPotion(category, now)
	local best
	for _, item in Boosts.ItemsFor(category) do
		local untilAt = player:GetAttribute("BoostUntil_" .. item.Id)
		if type(untilAt) == "number" and untilAt > now and (not best or item.Multiplier > best.Multiplier) then
			best = { Item = item, Until = untilAt }
		end
	end
	return best
end

local function refreshPotions(now)
	local activeCount = 0
	for _, category in Boosts.Order do
		local slot = potionButtons[category]
		local activePotion = strongestPotion(category, now)
		if activePotion then
			activeCount += 1
			slot.Button.Visible = true
			slot.Button:SetAttribute("PotionId", activePotion.Item.Id)
			slot.Button:SetAttribute("PotionUntil", activePotion.Until)
			slot.Timer.Text = potionTime(activePotion.Until - now)
			slot.Name.Text = activePotion.Item.Name
			slot.Effect.Text = Format.Multi(activePotion.Item.Multiplier) .. " " .. activePotion.Item.Category
			slot.Time.Text = potionTime(activePotion.Until - now) .. " remaining"
		else
			slot.Button.Visible = false
			slot.Button:SetAttribute("PotionId", nil)
			slot.Button:SetAttribute("PotionUntil", nil)
			slot.Card.Visible = false
		end
	end
	potionStatus.Visible = activeCount > 0 and hud.Enabled
end
local treeView = require(script.Parent.RollToast.Ui.UpgradeTreeView).Create(gui, Tree, Format)
local treePanel, feedback, tiles = treeView.Panel, treeView.Feedback, treeView.Tiles
Switch.Register("Upgrades", treePanel)
table.insert(themed, treeView.Refs.Gui)
panels.Upgrades = treePanel
for _, close in { treeView.Refs.Close, treeView.Refs.Exit } do
	close.Activated:Connect(function()
		Switch.Close("Upgrades")
	end)
end
local pendingBuys = {}
for _, tile in Tree.Tiles() do
	local entry = tiles[tile.Id]
	if not entry then
		continue
	end
	local b = entry.Button
	UiFeedback.DeniedPress(b, function() -- not buyable; an owned node is no refusal
		local folder = player:FindFirstChild("Upgrades")
		return not pendingBuys[tile.Id] and not (folder and folder:FindFirstChild(tile.Id))
	end)
	b.Activated:Connect(function()
		if not b.Active or pendingBuys[tile.Id] then
			return
		end
		pendingBuys[tile.Id] = true
		setActive(b, false)
		local ok, bought, reason = pcall(function()
			return remotes:WaitForChild("BuyUpgrade"):InvokeServer(tile.Id)
		end)
		feedback.Text = ok and (bought and ("Bought " .. tile.Name) or tostring(reason))
			or "Connection error; try again"
		feedback.TextColor3 = ok and bought and GREEN or RED
		pendingBuys[tile.Id] = nil
		UiFeedback.Play((ok and bought) and "UpgradeBought" or "Denied", b)
	end)
end
local workshopPanel = panel("Workshop", "WORKSHOP UPGRADE", require(script.Parent.RollToast.Ui.HudIcons).Upgrade.Image)
-- Design doc 4.42 spacing standard (Client/AnimeSkin tokens): under the header, the stat tabs in the toolbar row; then
-- the level column on the left (BUY at its foot, clear of the stripe art) and the showcase on the right. Rows are
-- anchored to the top or the bottom of the band-sized panel, so they follow its height; place() redoes the px tokens
-- when the phone / desktop size changes.
local px = Skin.Px
local boostLabel = text("Boost", workshopPanel, UDim2.new(), UDim2.new(), "")
local levelLabel = text("Level", workshopPanel, UDim2.new(), UDim2.new(), "")
local priceLabel = text("Price", workshopPanel, UDim2.new(), UDim2.new(), "")
local workshopResult = text("Result", workshopPanel, UDim2.new(), UDim2.new(), "")
for label, role in { [boostLabel] = "Item", [levelLabel] = "Body", [priceLabel] = "Body", [workshopResult] = "Caption" } do
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	Skin.Label(label, role)
end
-- The boosted stat picker (design doc 4.19): the server validates the pick; the chosen one is lit.
local statRow = make("Frame", "Stats", workshopPanel, { BackgroundTransparency = 1 })
local statLit = {}
for i, stat in Workshop.Config.STATS do
	local count = #Workshop.Config.STATS
	local gap = px(Skin.Space.Inner)
	local b = button(
		stat,
		statRow,
		UDim2.new((i - 1) / count, gap / 2, 0, 0),
		UDim2.new(1 / count, -gap, 1, 0),
		string.upper(stat)
	)
	statLit[stat] = Skin.Tab(b, i)
	b.Activated:Connect(function()
		local ok, applied, reason = pcall(function()
			return remotes:WaitForChild("SetWorkshopStat"):InvokeServer(stat)
		end)
		workshopResult.Text = ok and tostring(reason or (applied and "Updated" or "Try again"))
			or "Connection error; try again"
	end)
end
local buyWorkshop = button("Buy", workshopPanel, UDim2.new(), UDim2.new(), "BUY NEXT LEVEL")
Skin.Button(buyWorkshop, "Idle")
-- Showcase (docs/WORKSHOP_SPEC.md "Showcase"): the right part of the Workshop panel. The server validates every pick.
local showcaseFrame = make("Frame", "Showcase", workshopPanel, { BackgroundTransparency = 1 })
local squadPoints = text("Points", showcaseFrame, UDim2.new(), UDim2.new(), "")
squadPoints.TextXAlignment = Enum.TextXAlignment.Left
Skin.Label(squadPoints, "Caption")
-- The squad slots and BEST 3: one row of 40 px buttons.
local best3 = button("Best3", showcaseFrame, UDim2.new(), UDim2.new(), "BEST 3")
Skin.Button(best3, "Go")
local slots = {}
for i = 1, GachaConfig.SHOWCASE_SLOTS do
	local slot = make("Frame", "Slot" .. i, showcaseFrame, {})
	Skin.Button(slot, "Idle")
	local name = text("Name", slot, UDim2.new(), UDim2.new(), "EMPTY")
	local info = text("Info", slot, UDim2.new(), UDim2.new(), "")
	for label, role in { [name] = "Body", [info] = "Caption" } do
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		Skin.Label(label, role)
	end
	local clear = button("Clear", slot, UDim2.new(), UDim2.new(), "×")
	Skin.Button(clear, "Danger")
	slots[i] = { Frame = slot, Name = name, Info = info, Clear = clear }
end
local showcaseList = make("ScrollingFrame", "List", showcaseFrame, {
	BackgroundTransparency = 1,
	ScrollBarThickness = px(Skin.Space.Scrollbar) - 2,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, -- the bar sits beside the rows, not on their buttons
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
local showcaseLayout = make("UIListLayout", "Layout", showcaseList, { SortOrder = Enum.SortOrder.LayoutOrder })
local function placeWorkshop()
	local inset, gap, inner = px(Skin.Space.Inset), px(Skin.Space.Gap), px(Skin.Space.Inner)
	local buttonH, top = px(Skin.Space.Button), Skin.Top(true)
	local split = 0.36 -- the level column's share of the width
	statRow.Position, statRow.Size = Skin.ToolbarRect()
	-- Left column: boost, level, price from the top; the result line and BUY from the bottom.
	local function left(label, y, h)
		label.Position, label.Size = UDim2.fromOffset(inset, y), UDim2.new(split, -inset - gap / 2, 0, h)
	end
	local itemH, bodyH = px(Skin.Size.Item) + 4, px(Skin.Size.Body) + 4
	left(boostLabel, top, itemH)
	left(levelLabel, top + itemH + inner, bodyH)
	left(priceLabel, top + itemH + inner + bodyH + inner, 2 * bodyH) -- price may wrap to two lines
	local bottom = px(Skin.Space.BottomClear) -- BUY sits bottom-left, clear of the stripe art
	buyWorkshop.Position = UDim2.new(0, inset, 1, -bottom - buttonH)
	buyWorkshop.Size = UDim2.new(split, -inset - gap / 2, 0, buttonH)
	local resultH = px(Skin.Size.Caption) + 4
	workshopResult.Position = UDim2.new(0, inset, 1, -bottom - buttonH - inner - resultH)
	workshopResult.Size = UDim2.new(split, -inset - gap / 2, 0, resultH)
	-- Right column: the squad line, the slots row, then the candidates list down to the bottom inset.
	showcaseFrame.Position = UDim2.new(split, gap / 2, 0, top)
	showcaseFrame.Size = UDim2.new(1 - split, -inset - gap / 2, 1, -top - px(Skin.Space.Bottom))
	squadPoints.Position, squadPoints.Size = UDim2.new(), UDim2.new(1, 0, 0, resultH)
	local rowTop = resultH + inner
	local best3W = px(76) -- narrower, so each slot shows its full name ("EMPTY", a character) beside the clear button
	best3.Position, best3.Size = UDim2.new(1, -best3W, 0, rowTop), UDim2.fromOffset(best3W, buttonH)
	local count = GachaConfig.SHOWCASE_SLOTS
	for i, slot in slots do
		-- count slots and BEST 3 share the row, `inner` apart: slot width (row - BEST 3 - count * inner) / count
		slot.Frame.Position = UDim2.new((i - 1) / count, -(i - 1) * best3W / count, 0, rowTop)
		slot.Frame.Size = UDim2.new(1 / count, -(best3W + count * inner) / count, 0, buttonH)
		local small = px(Skin.Space.ButtonSmall)
		slot.Clear.Position = UDim2.new(1, -small - (buttonH - small) / 2, 0.5, -small / 2)
		slot.Clear.Size = UDim2.fromOffset(small, small)
		local textW = UDim.new(1, -small - inner - inner) -- up to the clear button, 8 from it
		slot.Name.Position, slot.Name.Size = UDim2.fromOffset(inner, 2), UDim2.new(textW, UDim.new(0, bodyH))
		slot.Info.Position = UDim2.fromOffset(inner, buttonH - resultH - 2)
		slot.Info.Size = UDim2.new(textW, UDim.new(0, resultH))
	end
	showcaseList.Position = UDim2.fromOffset(0, rowTop + buttonH + gap)
	showcaseLayout.Padding = UDim.new(0, gap)
	buyWorkshop.TextSize, best3.TextSize = px(Skin.Size.Body), px(Skin.Size.Body)
end
-- The list ends on a whole row: its height is cut to a multiple of row + gap (design doc 4.42).
local function fitShowcaseList()
	local rowH, gap = px(Skin.Space.Button), px(Skin.Space.Gap)
	local room = math.max(0, showcaseFrame.AbsoluteSize.Y - showcaseList.Position.Y.Offset)
	local whole = math.max(1, math.floor((room + gap) / (rowH + gap)))
	showcaseList.Size = UDim2.new(1, 0, 0, math.min(room, whole * (rowH + gap) - gap))
end
local function placeAll()
	placeWorkshop()
	fitShowcaseList()
end
placeAll()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeAll)
end
showcaseFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitShowcaseList)

local function shownIds()
	local ids = {}
	for id in string.gmatch(player:GetAttribute("Showcase") or "", "[^,]+") do
		table.insert(ids, id)
	end
	return ids
end
-- Owned rollable characters, most rarity points first: { Spec, Points }.
local function showcaseCandidates()
	local list = {}
	local data = player:FindFirstChild("GachaData")
	local team = string.split(player:GetAttribute("Team") or "", ",")
	for _, entry in data and data:GetChildren() or {} do
		local spec = CharacterCatalog.Get(entry.Name)
		-- Team members can not join the Dojo squad (server rule, WORLD_REDESIGN_SPEC section 5)
		if
			spec
			and spec.Rollable
			and spec.Id ~= player:GetAttribute("EquippedCar")
			and not table.find(team, spec.Id)
		then
			table.insert(list, { Spec = spec, Points = Workshop.Points({ spec }) })
		end
	end
	table.sort(list, function(a, b)
		if a.Points ~= b.Points then
			return a.Points > b.Points
		end
		return a.Spec.Id < b.Spec.Id
	end)
	return list
end
local showcaseBusy = false
local function sendShowcase(ids)
	if showcaseBusy then
		return
	end
	showcaseBusy = true
	local ok, applied, reason = pcall(function()
		return remotes:WaitForChild("SetShowcase"):InvokeServer(ids)
	end)
	workshopResult.Text = ok and tostring(reason or (applied and "Showcase updated" or "Try again"))
		or "Connection error; try again"
	showcaseBusy = false
end
local function refreshShowcase()
	local ids = shownIds()
	local candidates = showcaseCandidates()
	local specs = {}
	for i, slot in slots do
		local spec = ids[i] and CharacterCatalog.Get(ids[i])
		specs[i] = spec
		slot.Name.Text = spec and spec.Name or "EMPTY"
		slot.Info.Text = spec and string.format("%s · %d pts", spec.Rarity, Workshop.Points({ spec })) or ""
		slot.Clear.Visible = spec ~= nil
	end
	squadPoints.Text = string.format("SQUAD  %d rarity points", Workshop.Points(specs))
	for _, row in showcaseList:GetChildren() do
		if row:IsA("Frame") then
			row:Destroy()
		end
	end
	local full = #ids >= GachaConfig.SHOWCASE_SLOTS
	for order, c in candidates do
		-- 40 px rows: name (Body) and rarity (Caption) on the left, a 32 px SHOW button on the right.
		local rowH, small, inner = px(Skin.Space.Button), px(Skin.Space.ButtonSmall), px(Skin.Space.Inner)
		local showW = px(80)
		local row = make("Frame", "Character_" .. c.Spec.Id, showcaseList, {
			Size = UDim2.new(1, 0, 0, rowH),
			BackgroundTransparency = 1,
			LayoutOrder = order,
		})
		local label = text("Name", row, UDim2.new(), UDim2.new(0.5, -inner, 1, 0), c.Spec.Name)
		local info = text(
			"Info",
			row,
			UDim2.fromScale(0.5, 0),
			UDim2.new(0.5, -showW - inner, 1, 0),
			string.format("%s · %d pts", c.Spec.Rarity, c.Points)
		)
		for object, role in { [label] = "Body", [info] = "Caption" } do
			object.TextXAlignment = Enum.TextXAlignment.Left
			object.TextWrapped = false
			object.TextTruncate = Enum.TextTruncate.AtEnd
			Skin.Label(object, role)
		end
		local shown = table.find(ids, c.Spec.Id) ~= nil
		local show = button(
			"Show",
			row,
			UDim2.new(1, -showW, 0.5, -small / 2),
			UDim2.fromOffset(showW, small),
			shown and "SHOWN" or "SHOW"
		)
		show.TextSize = px(Skin.Size.Caption)
		Skin.Button(show, shown and "Go" or "Idle")
		setActive(show, shown or not full)
		show.Activated:Connect(function()
			if not show.Active then
				return
			end
			local nextIds = shownIds()
			local at = table.find(nextIds, c.Spec.Id)
			if at then
				table.remove(nextIds, at)
			elseif #nextIds < GachaConfig.SHOWCASE_SLOTS then
				table.insert(nextIds, c.Spec.Id)
			end
			sendShowcase(nextIds)
		end)
	end
end
for i, slot in slots do
	slot.Clear.Activated:Connect(function()
		local ids = shownIds()
		if ids[i] then
			table.remove(ids, i)
			sendShowcase(ids)
		end
	end)
end
best3.Activated:Connect(function()
	local ids = {}
	for _, c in showcaseCandidates() do
		if #ids >= GachaConfig.SHOWCASE_SLOTS then
			break
		end
		table.insert(ids, c.Spec.Id)
	end
	sendShowcase(ids)
end)
local function refreshShowcaseIfOpen()
	if workshopPanel.Visible then
		refreshShowcase()
	end
end
player:GetAttributeChangedSignal("Showcase"):Connect(refreshShowcaseIfOpen)
workshopPanel:GetPropertyChangedSignal("Visible"):Connect(refreshShowcaseIfOpen)
task.spawn(function()
	local data = player:WaitForChild("GachaData")
	data.ChildAdded:Connect(refreshShowcaseIfOpen)
	data.ChildRemoved:Connect(refreshShowcaseIfOpen)
end)

local function refresh()
	local money = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Money")
	local balance = money and money.Value or 0
	local owned = {}
	local folder = player:FindFirstChild("Upgrades")
	if folder then
		for _, v in folder:GetChildren() do
			owned[v.Name] = true
		end
	end
	local state = {
		Owned = owned,
		Money = balance,
		BestTrack = player:GetAttribute("BestTrack") or 0,
		TrackCount = #Tracks.Chain(),
	}
	for id, refs in tiles do
		local canBuy, reason = Tree.CanBuy(state, id)
		setActive(refs.Button, canBuy and not pendingBuys[id])
		refs.Button.Selectable = canBuy
		treeView.Paint(refs, owned[id] == true, canBuy, reason, state.TrackCount)
	end
	treeView.Balance(balance)
	local level = Workshop.CleanLevel(player:GetAttribute("WorkshopLevel"))
	local nextLevel = Workshop.Config.Levels[level + 1]
	levelLabel.Text = "Level " .. level .. " • " .. Format.Multi(Workshop.LevelScale(level)) .. " boost"
	priceLabel.Text = nextLevel
			and ("Level " .. (level + 1) .. " • " .. Format.Multi(Workshop.LevelScale(level + 1)) .. " • " .. Format.MoneyText(
				nextLevel.Price
			))
		or "MAX LEVEL"
	setActive(buyWorkshop, nextLevel ~= nil and balance >= nextLevel.Price)
	buyWorkshop.Selectable = buyWorkshop.Active
	Skin.Button(buyWorkshop, buyWorkshop.Active and "Go" or "Idle")
	-- Server numbers (WorkshopBoost, WorkshopStat); "+35% Luck", one decimal at most
	local stat = Workshop.CleanStat(player:GetAttribute("WorkshopStat"))
	boostLabel.Text = "+"
		.. tostring(math.round((player:GetAttribute("WorkshopBoost") or 0) * 1000) / 10)
		.. "% "
		.. stat
	for name, lit in statLit do
		lit(name == stat)
	end
end
buyWorkshop.Activated:Connect(function()
	if not buyWorkshop.Active then
		return
	end
	setActive(buyWorkshop, false)
	local ok, bought, reason = pcall(function()
		return remotes:WaitForChild("WorkshopUpgrade"):InvokeServer()
	end)
	workshopResult.Text = ok and tostring(reason or (bought and "Upgraded" or "Try again"))
		or "Connection error; try again"
	refresh()
	UiFeedback.Play((ok and bought) and "UpgradeBought" or "Denied", buyWorkshop)
end)
remotes:WaitForChild("WorkshopOpen").OnClientEvent:Connect(function()
	refresh()
	if not workshopPanel.Visible then
		Switch.Toggle("Workshop")
	end
end)
for _, attr in { "BestTrack", "UpgradesBuyable", "WorkshopLevel", "WorkshopStat", "WorkshopBoost" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
task.spawn(function()
	local money = player:WaitForChild("leaderstats"):WaitForChild("Money")
	money.Changed:Connect(refresh)
	local folder = player:WaitForChild("Upgrades")
	folder.ChildAdded:Connect(refresh)
	folder.ChildRemoved:Connect(refresh)
	refresh()
end)
UserInputService.InputBegan:Connect(function(input, consumed)
	if not consumed and input.KeyCode == Enum.KeyCode.Escape then
		for name in panels do
			Switch.Close(name)
		end
	end
end)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.25 then
		return
	end
	elapsed = 0
	local weatherId = ReplicatedStorage:GetAttribute("WeatherEvent") or ""
	local active = Weather.Events[weatherId]
	local spec = active or Weather.Events.clear
	local remaining =
		math.max(0, math.ceil((ReplicatedStorage:GetAttribute("WeatherEndsAt") or 0) - workspace:GetServerTimeNow()))
	weather.Text = spec.Icon
	weatherTitle.Text = spec.Name
	weatherTitle.TextColor3 = spec.Color or Color3.new(1, 1, 1)
	weatherStats.Text = Weather.Describe(weatherId)
	weatherTime.Text = active and string.format("%ds left", remaining) or ""
	local showcase = gui:FindFirstChild("RollShowcase")
	hud.Enabled = not (showcase and showcase.Enabled)
	refreshPotions(workspace:GetServerTimeNow())
end)
refresh()
-- Fredoka text and token radii on every code-built screen, rows added later included (section 8).
for _, root in themed do
	UiTheme.Apply(root)
end
