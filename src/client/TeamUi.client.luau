--!nonstrict
-- Team panel (design doc 4.40 "Market pill and Bosses button", owner 2026-11-12, layout A "Line-up"; docs/
-- TEAM_AND_STAMINA_SPEC.md "Team" and "HUD" Team editor, moved here from the Backpack Characters tab). Opened by the
-- second column's Team button and its key T (Client/BossEventUi, PanelSwitch "Team"). Three slot cards in run order with
-- each member's portrait, category, cruise and stamina; the team bonus box at their right; the owned roster below with
-- Sort and Search. Tap a card, then a slot (SlotPicker): a member put on another slot swaps, its own slot takes it off.
-- The server decides (Remotes.SetTeam: at least 1 member, locked during a run); every figure is the one the Backpack
-- (cruise) and the minibar (TeamStamina<n>, TeamBonus) read, the summed stamina a display sum of the slots' figures.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CharacterCatalog = require(shared:WaitForChild("CharacterCatalog"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local RaceConfig = require(shared:WaitForChild("RaceConfig"))
local SeriesCatalog = require(shared:WaitForChild("SeriesCatalog"))
local StaminaConfig = require(shared:WaitForChild("StaminaConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local Icons = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
local Components = require(script.Parent.RollToast.Ui:WaitForChild("RacerComponents"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local RosterCard = require(script.Parent:WaitForChild("RosterCard"))
local SlotPicker = require(script.Parent:WaitForChild("SlotPicker"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local U = AnimeSkin.Units
local OUTLINE = UiTheme.Outline
local GOLD = UiTheme.Palette.Unbanked
local CATEGORY = Color3.fromRGB(110, 205, 240)
local STAMINA_BAR = Color3.fromRGB(60, 150, 255)
local ORDER = { "RUNS FIRST", "TAGS IN 2ND", "TAGS IN LAST" } -- the run order (TEAM_AND_STAMINA_SPEC "Swap")
-- Design units (placeholders): the slot row's height, the bonus box's width, the toolbar's widths, the roster cells.
local SLOTS_H, PHONE_SLOTS_H = 150, 104 -- 150: room for the desktop roster's two rows of cards (layout A)
local BONUS_W, PHONE_BONUS_W = 220, 150
local SORT_W, SEARCH_W = 220, 300
local CARD_MIN_WIDTH, CARD_HEIGHT = 140, 120
local CARD_ART = 3 -- px: the card art reaches 3 px past a cell, so the grid pads it

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	return make("TextLabel", name, parent, props)
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
PanelSwitch.Register("Team", panel)

local header = make("Frame", "Header", panel, { BackgroundTransparency = 1 })
caption("Title", header, { Text = "Team" })
make("ImageLabel", "Icon", header, { BackgroundTransparency = 1, Image = Icons.Team.Image })
local close = make("TextButton", "Close", header, { Text = "", AutoButtonColor = false })
caption("X", close, { Size = UDim2.fromScale(1, 1), Text = "X" })

local g -- the Index frame (PanelFrame.Attach, below): every size is in its design units
local chosen = nil -- the picked character the slots put on the Team
local hint = "" -- the last answer or notice, shown in the footer until the panel closes
local busy = false
local render -- set below

local function showFooter()
	local spec = chosen and CharacterCatalog.Get(chosen)
	return g.Footer(
		hint ~= "" and hint
			or spec and (spec.Name .. " picked: tap a slot. Members swap places.")
			or "Tap a character, then a slot."
	)
end
local function notify(text)
	hint = text
	UiMotion.SlideIn(showFooter(), Vector2.new(0, g.px(14)))
end

-- The slots (SlotPicker: Slot1..3 and the tap logic); each carries its member's card instead of the picker's lines.
local function pickSlot(slot, id, picked)
	if busy then
		return
	end
	local button = panel.Slots["Slot" .. slot]
	if not picked then
		notify("Pick a character first")
		UiFeedback.Play("Denied", button)
		return
	end
	local team = SlotPicker.TeamWith(slot, id)
	if not team then
		notify("Your Team needs at least 1 character")
		UiFeedback.Play("Denied", button)
		return
	end
	busy = true
	local ok, done, message = pcall(function()
		return remotes:WaitForChild("SetTeam"):InvokeServer(team)
	end)
	busy = false
	notify(ok and tostring(message or (done and "Team updated" or "Try again")) or "Connection error")
	render()
	UiFeedback.Play((ok and done) and "Equip" or "Denied", button)
end
local slots = SlotPicker.new("Slots", panel, {}, pickSlot)
local cards = {} -- slot -> its parts
for n, refs in slots.Buttons do
	refs.Title.Visible, refs.Items.Visible = false, false
	local b = refs.Button
	local function part(name, x, y, w, h, props)
		props.Position, props.Size = UDim2.fromScale(x, y), UDim2.fromScale(w, h)
		props.ZIndex = 3
		return caption(name, b, props)
	end
	local left = Enum.TextXAlignment.Left
	cards[n] = {
		Order = part("Order", 0.05, 0.04, 0.9, 0.15, { Text = ORDER[n], TextXAlignment = left }),
		Portrait = make("ImageLabel", "Portrait", b, {
			Position = UDim2.fromScale(0.03, 0.2),
			Size = UDim2.fromScale(0.45, 0.6),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		}),
		Name = part("Name", 0.5, 0.22, 0.47, 0.18, { TextXAlignment = left }),
		Category = part("Category", 0.5, 0.42, 0.47, 0.13, { TextXAlignment = left }),
		Cruise = part("Cruise", 0.5, 0.57, 0.47, 0.13, { TextXAlignment = left }),
		Stamina = part(
			"Stamina",
			0.05,
			0.82,
			0.9,
			0.14,
			{ BackgroundTransparency = 0, BackgroundColor3 = STAMINA_BAR }
		),
		Empty = part("Empty", 0.05, 0.35, 0.9, 0.3, { Text = "Empty slot" }),
	}
	UiTheme.Corner(cards[n].Stamina, "S")
end

-- The team bonus box (TeamBonus, as the minibar's badge) and the summed stamina of the slots.
local bonus = make("Frame", "Bonus", panel, { BackgroundColor3 = OUTLINE, BackgroundTransparency = 0.25 })
local function bonusLine(name, y, h, text)
	return caption(name, bonus, {
		Position = UDim2.fromScale(0.06, y),
		Size = UDim2.fromScale(0.88, h),
		Text = text or "",
		TextWrapped = true,
	})
end
local bonusHeading = bonusLine("Heading", 0.04, 0.14, "Team bonus")
local bonusName = bonusLine("Name", 0.22, 0.16)
local bonusEffect = bonusLine("Effect", 0.42, 0.24)
local bonusTotal = bonusLine("Total", 0.72, 0.16)

local sortMode = RosterCard.Sorts[1]
local sortButton = make("TextButton", "Sort", panel, { Text = "", AutoButtonColor = false })
local sortLabel = caption("Label", sortButton, { Size = UDim2.fromScale(1, 1), Text = "Sort: " .. sortMode })
local search = make("TextBox", "Search", panel, {
	BackgroundColor3 = OUTLINE,
	BackgroundTransparency = 0.25,
	ClearTextOnFocus = false,
	PlaceholderText = "Search",
	PlaceholderColor3 = UiTheme.Palette.SoftText,
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
local searchPadding = make("UIPadding", "Padding", search, {})

local roster = make("ScrollingFrame", "Roster", panel, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIPadding", "Padding", roster, {
	PaddingTop = UDim.new(0, CARD_ART),
	PaddingBottom = UDim.new(0, CARD_ART),
	PaddingLeft = UDim.new(0, CARD_ART),
	PaddingRight = UDim.new(0, CARD_ART),
})
local rosterLayout = make("UIGridLayout", "Layout", roster, { SortOrder = Enum.SortOrder.LayoutOrder })

-- Layout A in the frame's units: the slot row and the bonus box from the tabs row (no tabs here) down, the toolbar
-- under them, the roster to the content's bottom; cells fill the width with whole rows, as the Backpack's.
local renderedK = nil
local function layout()
	local c = g.Content
	local gap, row = U.Gap, U.Button
	local top, bottom = c.TabsY, c.Y + c.H
	local slotsH, bonusW = g.Small and PHONE_SLOTS_H or SLOTS_H, g.Small and PHONE_BONUS_W or BONUS_W
	g.Place(slots.Frame, c.X, top, c.W - bonusW - gap, slotsH)
	slots:Layout(g)
	for _, parts in cards do
		g.Role(parts.Order, "Body")
		g.Role(parts.Name, "Item")
		g.Role(parts.Category, "Body").TextColor3 = CATEGORY
		g.Role(parts.Cruise, "Body").TextColor3 = GOLD
		g.Role(parts.Stamina, "Body")
		g.Role(parts.Empty, "Body").TextColor3 = AnimeSkin.Color.Caption
	end
	g.Place(bonus, c.X + c.W - bonusW, top, bonusW, slotsH)
	g.Role(bonusHeading, "Body")
	g.Role(bonusName, "Item").TextColor3 = GOLD
	g.Role(bonusEffect, "Caption")
	g.Role(bonusTotal, "Body")
	local toolY = top + slotsH + gap
	g.Place(search, c.X + c.W - SEARCH_W, toolY, SEARCH_W, row)
	g.Place(sortButton, c.X + c.W - SEARCH_W - gap - SORT_W, toolY, SORT_W, row)
	searchPadding.PaddingLeft, searchPadding.PaddingRight = UDim.new(0, g.px(U.Pad)), UDim.new(0, g.px(U.Pad))
	g.Role(search, "Body")
	sortLabel.Position, sortLabel.Size = g.at(U.Pad, 0), UDim2.new(1, -g.px(2 * U.Pad), 1, 0)
	g.Role(sortLabel, "Item")
	local rosterY = toolY + row + gap
	g.Place(roster, c.X, rosterY, c.W, bottom - rosterY)
	roster.ScrollBarThickness = g.px(8)
	local gapPx = g.px(gap)
	local width = g.px(c.W) - roster.ScrollBarThickness - 2 * CARD_ART
	local height = g.px(bottom - rosterY) - 2 * CARD_ART
	if width > 0 and height > 0 then
		local columns = math.max(2, math.floor((width + gapPx) / (g.px(CARD_MIN_WIDTH) + gapPx)))
		local rows = math.max(g.Small and 1 or 2, math.floor((height + gapPx) / (g.px(CARD_HEIGHT) + gapPx) + 0.5))
		rosterLayout.CellSize = UDim2.fromOffset(
			math.floor((width - (columns - 1) * gapPx) / columns),
			math.floor((height + gapPx) / rows) - gapPx
		)
		rosterLayout.CellPadding = UDim2.fromOffset(gapPx, gapPx)
	end
	-- The card text is sized at drawing: a new scale draws the open roster again.
	if renderedK and renderedK ~= g.k and panel.Visible then
		renderedK = g.k
		task.defer(render)
	end
end

-- Hides the cards the search box rules out, by the name each card was drawn with.
local function applySearch()
	local query = string.lower(search.Text)
	for _, card in roster:GetChildren() do
		if card:IsA("GuiButton") then
			card.Visible = query == ""
				or string.find(string.lower(card:GetAttribute("SearchName") or ""), query, 1, true) ~= nil
		end
	end
end

-- The bonus as the minibar names it (TeamBonus "Preset:<id>" / "Series:<id>" / ""), and what it gives.
local function drawBonus(total)
	local kind, seriesId = string.match(player:GetAttribute("TeamBonus") or "", "^(%a+):(.+)$")
	local series = seriesId and SeriesCatalog.Get(seriesId)
	local function percent(multi)
		return math.floor((multi - 1) * 100 + 0.5)
	end
	if series and kind == "Preset" then
		bonusName.Text = "★ " .. string.upper(series.Preset.Name)
		bonusEffect.Text = string.format(
			"+%d%% STAMINA\n+%d%% SPEED",
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
	bonusTotal.Text = string.format("Total %.1f s", total)
end

function render()
	renderedK = g.k
	slots:Update("Character", chosen)
	local team = SlotPicker.Team()
	local total = 0
	for n, parts in cards do
		local spec = team[n] and team[n] ~= "" and CharacterCatalog.Get(team[n])
		for name, part in parts do
			if name == "Empty" then
				part.Visible = not spec
			elseif name ~= "Order" then
				part.Visible = spec ~= false and spec ~= nil
			end
		end
		local model = parts.Portrait:FindFirstChild("Model")
		if model then
			model:Destroy()
		end
		if spec then
			-- The drawn portrait (CharacterPortraits); with none yet, the live model over an empty image.
			local image = Components.PortraitImage(spec)
			parts.Portrait.Image = image or ""
			if not image then
				Components.RunnerArt(parts.Portrait, "Model", spec, UDim2.new(), UDim2.fromScale(1, 1), true)
			end
			parts.Name.Text = spec.Name
			parts.Category.Text = spec.Category or "Balanced"
			parts.Cruise.Text = HudFormat.RateText(RaceConfig.Cruise(spec))
			local seconds = tonumber(player:GetAttribute("TeamStamina" .. n)) or StaminaConfig.Seconds(spec)
			seconds = math.round(seconds * 10) / 10
			total += seconds
			parts.Stamina.Text = string.format("%.1f s stamina", seconds)
		end
	end
	drawBonus(total)
	for _, child in roster:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, spec in RosterCard.Owned(player, sortMode, true) do
		local card = RosterCard.new(roster, spec, order, g, spec.Id == chosen)
		card.Activated:Connect(function()
			chosen = spec.Id
			hint = ""
			render()
			local picked = roster:FindFirstChild(spec.Id)
			if picked then
				UiMotion.Pop(picked, 0.06)
			end
		end)
	end
	applySearch()
	showFooter()
end

close.Activated:Connect(function()
	PanelSwitch.Close("Team")
end)
sortButton.Activated:Connect(function()
	sortMode = RosterCard.Sorts[table.find(RosterCard.Sorts, sortMode) % #RosterCard.Sorts + 1]
	sortLabel.Text = "Sort: " .. sortMode
	render()
end)
search:GetPropertyChangedSignal("Text"):Connect(applySearch)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		chosen, hint = nil, ""
		render()
	end
end)
player.AttributeChanged:Connect(function(attr)
	if panel.Visible and (attr == "Team" or attr == "TeamBonus" or string.match(attr, "^TeamStamina%d$")) then
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
	-- The models load in the background: redraw an open roster once they arrive.
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
	Title = "Team",
	Icon = Icons.Team.Image,
	TitleObject = header.Title,
	Close = close,
}).Frame
PanelFrame.CloseOnOutsideClick(panel, function()
	PanelSwitch.Close("Team")
end)
sortButton.BorderSizePixel = 0
g.Button(sortButton, "Idle")
UiTheme.Corner(search, "S") -- after UiTheme.Apply, which snaps corners to its own radii
g.OnLayout(layout)
