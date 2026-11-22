--!nonstrict
-- The summon page's panels as the owner's reference sheet draws them (design doc 4.45, owner 2026-11-17 "Summon UI State
-- Reference" panels 2-9): Featured Banner, Show Chances, Summon Info, Auto Sell (Keep / Sell per rarity, Save), More menu,
-- the Many summon confirmation, the "You Obtained!" result and the Buy Gems focus state. Display and asks only: the server
-- decides odds, costs, summons, auto-sell and purchases; this reads the attributes and rotation it already publishes.
-- One overlay over the summon canvas; one panel at a time. Sizes and colours proposed.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaConfig = require(Shared:WaitForChild("GachaConfig"))
local HudFormat = require(Shared:WaitForChild("HudFormat"))
local SidekickArt = require(Shared:WaitForChild("SidekickArt"))
local SidekickConfig = require(Shared:WaitForChild("SidekickConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local Icons = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))

local D = UiTheme.Dojo
local W = 520 -- panel width, px at a 720-tall screen
local ROW = 54
local GREEN = Color3.fromRGB(64, 168, 76)
local FACE_TOP = Color3.fromRGB(96, 38, 40)
local FACE_BOTTOM = Color3.fromRGB(47, 19, 22)
local RARITIES = { "Mythic", "Legendary", "Epic", "Rare", "Common" } -- the sheet's order; a rarity with no Sidekick is left out
local SHOW = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local SummonPanels = {}

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function text(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or UiTheme.Font
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or D.Cream
	local maxSize = props.MaxSize or 22
	props.MaxSize = nil
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = D.Ink, Thickness = 1.5, Transparency = 0.2 })
	make("UITextSizeConstraint", "Limit", label, { MaxTextSize = maxSize })
	return label
end

local function plate(frame, top, bottom, edge)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	make("UIGradient", "Shade", frame, { Rotation = 90, Color = ColorSequence.new(top, bottom) })
	UiTheme.Corner(frame, 6)
	make("UIStroke", "Edge", frame, {
		Color = edge or D.Gold,
		Thickness = D.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- A flat button (green for Save / Confirm / Buy / Equip, wood for Cancel / Keep / Close).
local function button(name, parent, label, tone)
	local b = make("TextButton", name, parent, { Text = "", AutoButtonColor = false })
	local top = tone == "Go" and GREEN or Color3.fromRGB(150, 74, 44)
	plate(b, top, top:Lerp(D.Ink, 0.35), tone == "Go" and Color3.fromRGB(170, 240, 140) or D.Gold)
	text("Caption", b, { Size = UDim2.fromScale(1, 1), Text = label })
	local scale = make("UIScale", "Press", b, {})
	b.MouseEnter:Connect(function()
		UiMotion.Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	b.MouseLeave:Connect(function()
		UiMotion.Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		UiMotion.Create(scale, TweenInfo.new(0.08), { Scale = 0.96 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		UiMotion.Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	return b
end

-- A small round rarity marker (the sheet's star, in the rarity's colour).
local function marker(parent, rarity, x, size)
	local dot = make("Frame", "Marker", parent, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, x, 0.5, 0),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = SidekickView.RarityColor(rarity),
		Rotation = 45,
	})
	make("UIStroke", "Edge", dot, { Color = D.Cream, Thickness = 1.5 })
	return dot
end

-- Every summonable id with its odds in this rotation, and the Secret.
local function oddsList(rotation)
	local out = {}
	for _, id in rotation.Ids or {} do
		local row = SidekickConfig.Get(id)
		if row then
			table.insert(out, { Row = row, Odds = (rotation.Odds or {})[id] or 0 })
		end
	end
	local secret = rotation.SecretId and SidekickConfig.Get(rotation.SecretId)
	if secret then
		table.insert(out, { Row = secret, Odds = (rotation.Odds or {})[rotation.SecretId] or 0 })
	end
	return out
end

-- Display shares of `values` (percents summing to 100) in steps of 1/UNITS %, by largest remainder, so the shown numbers
-- sum to exactly 100% (SIDEKICK_SPEC "Panels", owner 2026-11-20). Returns integer step counts, same keys.
local UNITS = 10000
local function exactShares(values)
	local total, out, order, used = 0, {}, {}, 0
	for key, value in values do
		total += value
		table.insert(order, key)
	end
	if total <= 0 then
		for key in values do
			out[key] = 0
		end
		return out
	end
	local frac = {}
	for _, key in order do
		local exact = values[key] / total * 100 * UNITS
		out[key] = math.floor(exact + 1e-7)
		frac[key] = exact - out[key]
		used += out[key]
	end
	table.sort(order, function(a, b)
		if frac[a] ~= frac[b] then
			return frac[a] > frac[b]
		end
		return tostring(a) < tostring(b)
	end)
	for i = 1, 100 * UNITS - used do
		local key = order[(i - 1) % #order + 1]
		out[key] += 1
	end
	return out
end

-- A step count as a percent: up to 4 decimals, at least 2 ("24.4997%", "12.00%", "0.001%").
local function stepsText(steps)
	local s = string.format("%.4f", steps / UNITS)
	s = string.gsub(s, "0+$", "")
	local decimals = #(string.match(s, "%.(%d*)$") or "")
	return s .. string.rep("0", math.max(0, 2 - decimals)) .. "%"
end

-- `canvas`: the summon page's canvas. `deps`: Rotation() -> the published rotation; Toast(text); BuyPack(pack);
-- Remotes (Folder). Returns the panels object.
function SummonPanels.new(canvas, deps)
	local player = Players.LocalPlayer
	local self = { History = {} }

	local overlay = make("Frame", "SummonPanels", canvas, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		Active = true,
		ZIndex = 50,
	})
	local panel = make("Frame", "Panel", overlay, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, 300),
		ZIndex = 51,
	})
	plate(panel, FACE_TOP, FACE_BOTTOM)
	local scale = make("UIScale", "Fit", panel, {})
	local function fit()
		local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(view.Y / 720, view.X / 900), 0.5, 1.3)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	local header = make("Frame", "Header", panel, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64) })
	local icon = make("ImageLabel", "Icon", header, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(44, 44),
		ScaleType = Enum.ScaleType.Fit,
	})
	local title = text("Title", header, {
		MaxSize = 30,
		Position = UDim2.fromOffset(66, 8),
		Size = UDim2.new(1, -140, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local subtitle = text("Subtitle", header, {
		Position = UDim2.fromOffset(66, 40),
		Size = UDim2.new(1, -140, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = D.Sakura,
	})
	local close = make("TextButton", "Close", header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		Text = "",
		AutoButtonColor = false,
	})
	plate(close, Color3.fromRGB(190, 60, 60), Color3.fromRGB(120, 30, 34), D.Cream)
	text("X", close, { Size = UDim2.fromScale(1, 1), Text = "X" })
	make("Frame", "Rule", panel, {
		Position = UDim2.fromOffset(14, 64),
		Size = UDim2.new(1, -28, 0, 1),
		BackgroundColor3 = D.Gold,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	})
	local body = make("Frame", "Body", panel, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 1, -88),
	})
	local footer -- the panel's bottom buttons (Cancel / Save ...), when it has some
	local onClose = nil

	local restoreTo = nil -- the gamepad selection before a panel opened (given back on hide)
	local function hide()
		overlay.Visible = false
		local selected = GuiService.SelectedObject
		if restoreTo and restoreTo:IsDescendantOf(game) and (selected == nil or selected:IsDescendantOf(overlay)) then
			GuiService.SelectedObject = restoreTo
		end
		restoreTo = nil
		local after = onClose
		onClose = nil
		if after then
			after()
		end
	end
	close.Activated:Connect(hide)
	self.Hide = hide
	function self.IsOpen()
		return overlay.Visible
	end

	-- Clears the panel and titles it; `rows` lays out the body top to bottom (list), `height` its px.
	local function begin(name, titleText, subtitleText, iconImage, height)
		for _, child in body:GetChildren() do
			child:Destroy()
		end
		if footer then
			footer:Destroy()
			footer = nil
		end
		panel.Name = name
		title.Text = titleText
		subtitle.Text = subtitleText or ""
		subtitle.Visible = subtitleText ~= nil
		title.Size = UDim2.new(1, -140, 0, subtitleText and 34 or 46)
		title.Position = UDim2.fromOffset(66, subtitleText and 8 or 9)
		icon.Image = iconImage or ""
		panel.Size = UDim2.fromOffset(W, height + 88)
		make("UIListLayout", "List", body, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		local selected = GuiService.SelectedObject
		if not overlay.Visible and selected and not selected:IsDescendantOf(overlay) then
			restoreTo = selected
		end
		overlay.Visible = true
		-- A gamepad (something is selected) starts on the panel's first button: the footer's, a menu row, else the X.
		task.defer(function()
			if not (overlay.Visible and GuiService.SelectedObject) then
				return
			end
			local first = nil
			for _, b in (footer or body):GetDescendants() do
				if b:IsA("GuiButton") and (not first or b.LayoutOrder < first.LayoutOrder) then
					first = b
				end
			end
			GuiService.SelectedObject = first or close
		end)
		panel.Position = UDim2.new(0.5, 0, 0.5, 12)
		panel.BackgroundTransparency = 0
		UiMotion.Create(panel, SHOW, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	end

	-- A row: a shaded strip in `color` with a marker, a name (and optional second line) and a value at the right.
	local function row(order, color, rarity, name, second, value, image, parent)
		local r = make("Frame", "Row" .. order, parent or body, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, ROW) })
		plate(r, color:Lerp(D.Ink, 0.45), color:Lerp(D.Ink, 0.75), color)
		local x = 12
		if image then
			make("ImageLabel", "Art", r, {
				BackgroundColor3 = color:Lerp(D.Ink, 0.5),
				Position = UDim2.fromOffset(6, 4),
				Size = UDim2.fromOffset(ROW - 8, ROW - 8),
				Image = image,
				ScaleType = Enum.ScaleType.Crop,
			})
			x = ROW + 6
		elseif rarity then
			marker(r, rarity, 14, 16)
			x = 42
		end
		text("Name", r, {
			Position = UDim2.fromOffset(x, second and 4 or 0),
			Size = UDim2.new(0.62, -x, 0, second and 26 or ROW),
			Text = name,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rarity and SidekickView.RarityColor(rarity):Lerp(Color3.new(1, 1, 1), 0.25) or D.Cream,
		})
		if second then
			text("Second", r, {
				Position = UDim2.fromOffset(x, 30),
				Size = UDim2.new(0.62, -x, 0, 18),
				Text = second,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = SidekickView.RarityColor(rarity or "Common"),
			})
		end
		if value then
			text("Value", r, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 0),
				Size = UDim2.fromScale(0.35, 1),
				Text = value,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
		return r
	end

	local function buttons(list)
		footer = make("Frame", "Buttons", panel, {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.new(1, -32, 0, 46),
		})
		make("UIListLayout", "List", footer, {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local made = {}
		for i, spec in list do
			local b = button(spec[1], footer, spec[2], spec[3])
			b.LayoutOrder = i
			b.Size = UDim2.new(1 / #list, -16, 1, 0)
			b.Activated:Connect(spec[4])
			made[spec[1]] = b
		end
		return made
	end

	local function percent(odds)
		return string.format(odds > 0 and odds < 0.01 and "%.4f%%" or "%.2f%%", odds)
	end

	-- 2. Featured Banner: this rotation's featured units with their rates.
	function self.Featured()
		local list = oddsList(deps.Rotation())
		table.sort(list, function(a, b)
			local ra = table.find(GachaConfig.RARITY_ORDER, a.Row.Rarity) or 0
			local rb = table.find(GachaConfig.RARITY_ORDER, b.Row.Rarity) or 0
			if ra ~= rb then
				return ra > rb
			end
			return a.Odds < b.Odds
		end)
		local shown = {}
		for _, item in list do
			if item.Row.Rarity ~= "Common" and item.Row.Rarity ~= "Secret" and #shown < 5 then
				table.insert(shown, item)
			end
		end
		begin("FeaturedBanner", "Featured Banner", "Sidekick Banner", Icons.Gem.Image, 36 + #shown * (ROW + 8))
		text(
			"Heading",
			body,
			{ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 28), Text = "Featured Units & Rates", TextColor3 = D.Gold }
		)
		for i, item in shown do
			local art = SidekickArt[item.Row.Id]
			row(
				i,
				SidekickView.RarityColor(item.Row.Rarity),
				item.Row.Rarity,
				item.Row.Name,
				item.Row.Rarity,
				percent(item.Odds),
				art and art.Portrait
			)
		end
		if #shown == 0 then
			text(
				"Waiting",
				body,
				{ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), Text = "Waiting for the rotation..." }
			)
		end
	end

	-- 3. Show Chances: the odds summed per rarity (and the Secret), shown before any summon; under each total every
	-- Sidekick of the live banner at its own rate (SIDEKICK_SPEC "Panels", owner 2026-11-20). The rates are the server's
	-- (Rotation.Odds, the roll weights), rounded so the shown numbers sum to exactly 100%.
	function self.Chances()
		-- A due pity guarantee is the odds now (SIDEKICK_SPEC "No luck ... only pity does, and Details shows it"; section 6):
		-- the tier reads 100%, split evenly over its Sidekicks (the server picks one of them), every other rarity 0%.
		local tier = nil
		if (player:GetAttribute("SidekickPity") or 0) >= SidekickConfig.PityCount - 1 then
			tier = "Mythic"
		elseif (player:GetAttribute("SidekickLegendaryPity") or 0) >= SidekickConfig.LegendaryPityCount - 1 then
			tier = "Legendary"
		end
		local list, byRarity, values = oddsList(deps.Rotation()), {}, {}
		local inTier = 0
		for _, item in list do
			inTier += (tier and item.Row.Rarity == tier) and 1 or 0
		end
		for _, item in list do
			local rarity = item.Row.Rarity
			byRarity[rarity] = byRarity[rarity] or {}
			table.insert(byRarity[rarity], item)
			if tier then
				values[item.Row.Id] = rarity == tier and 100 / inTier or 0
			else
				values[item.Row.Id] = item.Odds
			end
		end
		local steps = exactShares(values)
		local order = table.clone(RARITIES)
		table.insert(order, 1, "Secret")
		local shown = {}
		for _, rarity in order do
			if byRarity[rarity] then
				table.insert(shown, rarity)
			end
		end
		local UNIT_ROW, GAP, LIST_MAX = 32, 4, 430
		local listHeight = 0
		for _, rarity in shown do
			listHeight += ROW + GAP + #byRarity[rarity] * (UNIT_ROW + GAP)
		end
		local viewHeight = math.min(listHeight, LIST_MAX)
		begin("ShowChances", "Details", nil, Icons.Quests.Image, 34 + viewHeight + 8 + 22 + (tier and 30 or 0))
		text("Heading", body, {
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 26),
			Text = "Summon Drop Rates (Sidekick Banner)",
		})
		local rates = make("ScrollingFrame", "Rates", body, {
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, viewHeight),
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = listHeight > LIST_MAX and 6 or 0,
			ScrollBarImageColor3 = D.Gold,
		})
		make("UIListLayout", "List", rates, { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder })
		local at = 0
		for i, rarity in shown do
			local items = byRarity[rarity]
			table.sort(items, function(a, b)
				if steps[a.Row.Id] ~= steps[b.Row.Id] then
					return steps[a.Row.Id] > steps[b.Row.Id]
				end
				return a.Row.Name < b.Row.Name
			end)
			local sum = 0
			for _, item in items do
				sum += steps[item.Row.Id]
			end
			at += 1
			local color = SidekickView.RarityColor(rarity)
			local total = row(i, color, rarity, rarity, nil, stepsText(sum), nil, rates)
			total.LayoutOrder = at
			for _, item in items do
				at += 1
				-- The Secret keeps no name column (owner 2026-11-05): its row reads "???"
				local secret = rarity == "Secret"
				local u = make("Frame", "Unit" .. at, rates, {
					LayoutOrder = at,
					Size = UDim2.new(1, -24, 0, UNIT_ROW),
					BackgroundTransparency = 1,
				})
				u:SetAttribute("Rarity", rarity)
				u:SetAttribute("SidekickId", item.Row.Id)
				make("UIPadding", "Indent", u, { PaddingLeft = UDim.new(0, 24) })
				make("Frame", "Line", u, {
					Size = UDim2.new(1, 0, 0, 1),
					Position = UDim2.new(0, 0, 1, -1),
					BackgroundColor3 = color,
					BackgroundTransparency = 0.6,
					BorderSizePixel = 0,
				})
				-- No drawn portrait: they appear only in the Sidekick index and Bag equip (design doc 4.36 "Art in UI")
				local x = 0
				text("Name", u, {
					MaxSize = 18,
					Position = UDim2.fromOffset(x, 0),
					Size = UDim2.new(0.65, -x, 1, 0),
					Text = secret and "???" or item.Row.Name,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				text("Value", u, {
					MaxSize = 18,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 0),
					Size = UDim2.fromScale(0.35, 1),
					Text = stepsText(steps[item.Row.Id]),
					TextXAlignment = Enum.TextXAlignment.Right,
				})
			end
		end
		text("Note", body, {
			LayoutOrder = 99,
			Size = UDim2.new(1, 0, 0, 22),
			Text = "Luck and potions never change Sidekick odds.",
			TextColor3 = D.Gold,
			Font = Enum.Font.GothamBold,
		})
		if tier then
			text("Guarantee", body, {
				LayoutOrder = 100,
				Size = UDim2.new(1, 0, 0, 22),
				Text = tier .. " guaranteed on the next summon",
				TextColor3 = D.Gold,
			})
		end
	end

	-- The live banner moved on (a new rotation slot): an open Details is rebuilt from it.
	function self.Refresh()
		if overlay.Visible and panel.Name == "ShowChances" then
			self.Chances()
		end
	end

	-- 4. Summon Info: how it works, banner rules, pity with the player's counts, the currency.
	function self.Info()
		local cards = {
			{ "How It Works", "Use Gems to summon Sidekicks. Get units of varying rarities.", D.Gold },
			{ "Banner Rules", "A featured Sidekick banner; it rotates every 30 minutes.", D.Gold },
			{
				"Pity / Progression",
				string.format(
					"Legendary Pity: %d summons (%d / %d)\nMythic Pity: %d summons (%d / %d)",
					SidekickConfig.LegendaryPityCount,
					player:GetAttribute("SidekickLegendaryPity") or 0,
					SidekickConfig.LegendaryPityCount,
					SidekickConfig.PityCount,
					player:GetAttribute("SidekickPity") or 0,
					SidekickConfig.PityCount
				),
				D.Gold,
			},
			{
				"Currency (Gems)",
				"Used for all summons. Earn from gameplay or buy in the Gem Shop.",
				Color3.fromRGB(190, 110, 255),
			},
		}
		begin("SummonInfo", "Summon Info", nil, Icons.Quests.Image, #cards * 76)
		for i, card in cards do
			local r = make("Frame", "Card" .. i, body, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 68) })
			plate(r, Color3.fromRGB(70, 30, 30), D.Ink, D.Gold)
			marker(r, nil, 16, 22).BackgroundColor3 = card[3]
			text("Heading", r, {
				Position = UDim2.fromOffset(52, 6),
				Size = UDim2.new(1, -64, 0, 22),
				Text = card[1],
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			local detail = text("Detail", r, {
				Position = UDim2.fromOffset(52, 30),
				Size = UDim2.new(1, -64, 0, 32),
				Text = card[2],
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
			})
			detail.Outline.Enabled = false
		end
	end

	-- 5. Auto Sell: Keep or Sell per rarity, Cancel / Save; Save sends only the changed rarities.
	function self.AutoSell()
		local now = SidekickView.AutoSell(player)
		local choice = {}
		local shown = {}
		for _, rarity in RARITIES do
			for _, r in SidekickConfig.List do
				if r.Rarity == rarity then
					table.insert(shown, rarity)
					break
				end
			end
		end
		begin("AutoSell", "Auto Sell", nil, Icons.Auto.Image, 30 + #shown * (ROW + 8) + 56)
		local head =
			make("Frame", "Head", body, { LayoutOrder = 0, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22) })
		text(
			"Rarity",
			head,
			{ Size = UDim2.fromScale(0.5, 1), Text = "Rarity", TextXAlignment = Enum.TextXAlignment.Left }
		)
		text("Action", head, { Position = UDim2.fromScale(0.62, 0), Size = UDim2.fromScale(0.3, 1), Text = "Action" })
		for i, rarity in shown do
			choice[rarity] = now[rarity] == true
			local r = row(i, SidekickView.RarityColor(rarity), rarity, rarity)
			local function radio(name, x, sell)
				local b = make("TextButton", name, r, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(x, 0.5),
					Size = UDim2.new(0.2, 0, 0, 30),
					BackgroundTransparency = 1,
					Text = "",
				})
				local ring = make("Frame", "Ring", b, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(20, 20),
					BackgroundColor3 = D.Ink,
				})
				UiTheme.Corner(ring, 999)
				make("UIStroke", "Edge", ring, { Color = D.Cream, Thickness = 1.5 })
				local dot = make("Frame", "Dot", ring, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.6, 0.6),
					BackgroundColor3 = GREEN:Lerp(Color3.new(1, 1, 1), 0.2),
				})
				UiTheme.Corner(dot, 999)
				text("Label", b, {
					Position = UDim2.fromOffset(26, 0),
					Size = UDim2.new(1, -26, 1, 0),
					Text = name,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				local function paint()
					dot.Visible = choice[rarity] == sell
					b:SetAttribute("Selected", dot.Visible)
				end
				b.Activated:Connect(function()
					UiFeedback.Play("Toggle", b)
					choice[rarity] = sell
					for _, other in r:GetChildren() do
						if other:IsA("TextButton") and other:FindFirstChild("Ring") then
							other.Ring.Dot.Visible = (other.Name == "Sell") == sell
							other:SetAttribute("Selected", other.Ring.Dot.Visible)
						end
					end
				end)
				paint()
			end
			radio("Keep", 0.58, false)
			radio("Sell", 0.78, true)
		end
		buttons({
			{ "Cancel", "Cancel", "Idle", hide },
			{
				"Save",
				"Save",
				"Go",
				function()
					-- Only the changed rarities, in one request (the server's 0.25 s remote cooldown refuses a second).
					local changed = {}
					for rarity, sell in choice do
						if (now[rarity] == true) ~= sell then
							changed[rarity] = sell
						end
					end
					local ok = true
					if next(changed) then
						local fine, done = pcall(function()
							return deps.Remotes:WaitForChild("SidekickAutoSell"):InvokeServer(changed)
						end)
						ok = fine and done == true
					end
					hide()
					UiFeedback.Play(ok and "Equip" or "Denied")
					deps.Toast(ok and "Auto Sell Saved!" or "Could not update Auto Sell")
				end,
			},
		})
	end

	-- 6. More: a compact menu of secondary options.
	function self.More()
		local items = {
			{ "Banner Details", self.Featured },
			{ "Pity", self.Info },
			{ "History", self.HistoryPanel },
			{ "Settings", self.AutoSell }, -- the summon page's own setting is Auto Sell
			{ "Gem Packs", self.GemPacks },
			{ "Help", self.Info },
		}
		begin("More", "More", nil, Icons.Settings.Image, #items * 50)
		for i, item in items do
			local b = make("TextButton", item[1]:gsub(" ", ""), body, {
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 42),
				Text = "",
				AutoButtonColor = false,
			})
			plate(b, Color3.fromRGB(80, 34, 30), D.Ink, D.Gold)
			text("Label", b, {
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -60, 1, 0),
				Text = item[1],
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			text("Chevron", b, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.new(0, 24, 1, 0),
				Text = ">",
				TextColor3 = D.Gold,
			})
			b.Activated:Connect(item[2])
		end
	end

	-- This session's summons, newest first (not saved).
	function self.HistoryPanel()
		local list = {}
		for i = #self.History, math.max(1, #self.History - 7), -1 do
			table.insert(list, self.History[i])
		end
		begin("History", "History", "This session", Icons.Quests.Image, math.max(1, #list) * (ROW + 8))
		for i, entry in list do
			row(
				i,
				SidekickView.RarityColor(entry.Rarity),
				entry.Rarity,
				entry.Name,
				entry.Rarity,
				entry.Sold and "Sold" or "Kept"
			)
		end
		if #list == 0 then
			text(
				"Empty",
				body,
				{ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), Text = "No summons yet this session." }
			)
		end
	end

	-- Every gem pack, each through the Buy Gems focus state.
	function self.GemPacks()
		begin("GemPacks", "Gem Packs", nil, Icons.Gem.Image, #deps.Packs * (ROW + 8))
		for i, pack in deps.Packs do
			local r = row(
				i,
				Color3.fromRGB(150, 80, 230),
				nil,
				pack.Name .. " Gems",
				"+" .. HudFormat.Short(pack.Gems) .. " Gems",
				"R$" .. pack.RobuxPrice
			)
			local hit =
				make("TextButton", "Pick", r, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" })
			hit.Activated:Connect(function()
				self.BuyGems(pack)
			end)
		end
	end

	-- 7. Summon confirmation (Many): the count, its cost and the Gems before and after. `yes` sends the summon.
	function self.ConfirmMany(count, cost, yes)
		local gems = player:GetAttribute("Gems") or 0
		begin("SummonConfirmation", "Summon Confirmation", nil, Icons.Gem.Image, 170)
		text("What", body, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), Text = "Summon Many" })
		local strip = make("Frame", "Count", body, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 46) })
		plate(strip, Color3.fromRGB(90, 40, 34), D.Ink, D.Gold)
		text("Label", strip, { Size = UDim2.fromScale(1, 1), Text = string.format("%d Summons", count) })
		text("Cost", body, {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 26),
			Text = string.format("Cost: %s Gems", HudFormat.Short(cost)),
		})
		text("Gems", body, {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 26),
			Text = string.format(
				"Your Gems: %s  ->  %s",
				HudFormat.Short(gems),
				HudFormat.Short(math.max(0, gems - cost))
			),
			TextColor3 = gems >= cost and D.Cream or Color3.fromRGB(255, 110, 120),
		})
		panel.Size = UDim2.fromOffset(W, 170 + 88 + 60)
		buttons({
			{ "Cancel", "Cancel", "Idle", hide },
			{
				"Confirm",
				"Confirm",
				"Go",
				function()
					hide()
					yes()
				end,
			},
		})
	end

	-- 8. The result: "You Obtained!" with the unit, Keep / Equip / Close. Equip puts the new entry on the Team's first runner.
	function self.Result(result)
		local spec = SidekickConfig.Get(result.Id)
		if not spec then
			return
		end
		begin("SummonResult", "You Obtained!", nil, nil, 250)
		-- The actual 3D model, not the drawn portrait (design doc 4.36 "Art in UI": the summon results show the models)
		local view = make("ViewportFrame", "Model", body, {
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 170),
			Ambient = Color3.fromRGB(235, 235, 240),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-1, -2, -1),
		})
		view.CurrentCamera = make("Camera", "Camera", view, { FieldOfView = 30 })
		local models = ReplicatedStorage:FindFirstChild("SidekickModels")
		local source = models and models:FindFirstChild(spec.Id)
		if source then
			local model = source:Clone()
			for _, d in model:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				end
			end
			model.Parent = view
			-- Framed as Client/SidekickReveal frames its result model
			local box, extents = model:GetBoundingBox()
			local dir = Vector3.new(0.45, 0.15, -1).Unit
			local distance = 0.72 * extents.Magnitude / 2 / math.sin(math.rad(15))
			view.CurrentCamera.CFrame = CFrame.lookAt(box.Position + dir * distance, box.Position)
		end
		text("Name", body, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 34), Text = spec.Name })
		text("Rarity", body, {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 26),
			Text = result.Sold and (spec.Rarity .. " (auto-sold)") or spec.Rarity,
			TextColor3 = SidekickView.RarityColor(spec.Rarity),
		})
		panel.Size = UDim2.fromOffset(W, 250 + 88 + 70)
		local list = { { "Keep", "Keep", "Idle", hide } }
		if not result.Sold then
			table.insert(list, {
				"Equip",
				"Equip",
				"Go",
				function()
					hide()
					deps.Equip(result.Id)
				end,
			})
		end
		table.insert(list, { "CloseResult", "Close", "Idle", hide })
		buttons(list)
	end

	-- 9. Buy Gems focus state: the pack, what it gives, Cancel / Buy (R$n).
	function self.BuyGems(pack)
		begin("BuyGems", "Buy Gems", nil, Icons.Gem.Image, 150)
		local strip = make(
			"Frame",
			"Offer",
			body,
			{ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 140), BackgroundTransparency = 1 }
		)
		local card = make("Frame", "Pack", strip, { Size = UDim2.fromOffset(150, 136) })
		plate(card, GREEN, GREEN:Lerp(D.Ink, 0.4), Color3.fromRGB(170, 240, 140))
		make("ImageLabel", "Gem", card, {
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, -28, 0, 12),
			Size = UDim2.fromOffset(56, 56),
			Image = Icons.Gem.Image,
		})
		text(
			"Name",
			card,
			{ Position = UDim2.fromOffset(6, 74), Size = UDim2.new(1, -12, 0, 26), Text = pack.Name .. " Gems" }
		)
		text("Amount", card, {
			Position = UDim2.fromOffset(6, 102),
			Size = UDim2.new(1, -12, 0, 20),
			Text = "+" .. HudFormat.Short(pack.Gems) .. " Gems",
		})
		text("Question", strip, {
			Position = UDim2.fromOffset(170, 10),
			Size = UDim2.new(1, -170, 0, 30),
			Text = string.format("Purchase %s Gems?", pack.Name),
		})
		text("Receive", strip, {
			Position = UDim2.fromOffset(170, 52),
			Size = UDim2.new(1, -170, 0, 22),
			Text = "You will receive:",
			TextColor3 = D.Gold,
		})
		text("Gain", strip, {
			Position = UDim2.fromOffset(170, 80),
			Size = UDim2.new(1, -170, 0, 32),
			Text = "+" .. HudFormat.Short(pack.Gems) .. " Gems",
		})
		panel.Size = UDim2.fromOffset(W, 150 + 88 + 64)
		buttons({
			{ "Cancel", "Cancel", "Idle", hide },
			{
				"Buy",
				"Buy (R$" .. pack.RobuxPrice .. ")",
				"Go",
				function()
					hide()
					deps.BuyPack(pack)
				end,
			},
		})
	end

	-- Records a summon's results for History.
	function self.Record(results)
		for _, result in results do
			local spec = SidekickConfig.Get(result.Id)
			if spec then
				table.insert(self.History, { Name = spec.Name, Rarity = spec.Rarity, Sold = result.Sold })
			end
		end
	end

	return self
end

return SummonPanels
