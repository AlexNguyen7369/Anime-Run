--!nonstrict
-- Quests and Daily rewards in the Scroll Dojo look (design doc 4.46, assets/ui/scroll_redesign/drafts/quests.html and
-- daily.html): Client/IndexAnimeStyle.Dojo's parts on BoostDailyUi's shared modal (a handscroll through PanelFrame),
-- laid out in the Index's design units (Client/AnimeSkin.Units) scaled to the modal. Display only.
local IndexStyle = require(script.Parent:WaitForChild("IndexAnimeStyle"))
local Skin = require(script.Parent:WaitForChild("AnimeSkin"))
local image = IndexStyle.Image
local Dojo = IndexStyle.Dojo
local C = Dojo.Colors

local Style = {}
-- Row bar colours by quest state (placeholders): ready vermilion, in progress paper brown, claimed muted.
Style.Tint = {
	Ready = C.Verm,
	Progress = C.TileBottom,
	Claimed = C.Muted,
}

-- A text role at `max` px, fitted (Client/IndexAnimeStyle.Dojo.Text).
local function text(label, role, max)
	Dojo.Text(label, role)
	label.TextScaled = true
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	limit.Name = limit.Name == "UITextSizeConstraint" and "AnimeLimit" or limit.Name
	limit.MinTextSize = math.min(10, max)
	limit.MaxTextSize = max
	limit.Parent = label
end

local function make(class, name, parent, props)
	local o = Instance.new(class)
	o.Name = name
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function phone()
	local camera = workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.Y <= 500
end

-- refs: Modal, Header, Title, Close (the PanelFrame parts the look replaces), Tabs, TabLayout, Daily, Weekly,
-- Content, Detail, Type, Name, Track, Fill, ProgressText, Reward, Logo, OnClose.
function Style.Attach(refs)
	local modal = refs.Modal
	-- Parented only while Quests show (a constraint has no Enabled): the Index's footprint inside the band.
	local aspect = make("UIAspectRatioConstraint", "AnimeAspect", nil, {
		AspectType = Enum.AspectType.FitWithinMaxSize,
		DominantAxis = Enum.DominantAxis.Height,
	})
	local layer = make(
		"Frame",
		"AnimeQuests",
		modal,
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }
	)
	local banner = make("Frame", "Banner", layer, { BackgroundTransparency = 1, ZIndex = 6 })
	local logo = image(banner, "Logo", refs.Logo, UDim2.new(), UDim2.new(), 11)
	logo.ScaleType = Enum.ScaleType.Fit
	local title = make("TextLabel", "Title", banner, {
		BackgroundTransparency = 1,
		Text = "QUESTS",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
	})
	local heading = Dojo.Heading(title)
	local rule = make("Frame", "HeaderRule", banner, {
		BackgroundColor3 = C.InkSoft,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 6,
		Active = false,
	})
	-- The seal close (an ImageButton for the UI tests' path; no image, the seal is its fill).
	local close = make("ImageButton", "Close", layer, {
		BackgroundTransparency = 1,
		Image = "",
		ZIndex = 10,
	})
	Dojo.Seal(close)
	close.Activated:Connect(refs.OnClose)
	local footer = make("TextLabel", "Footer", layer, { BackgroundTransparency = 1, Text = "", ZIndex = 4 })
	Dojo.FooterPlate(footer, 10)
	-- Above the art layer, as the Index's header (8) and grid (3) sit above its chrome.
	refs.Tabs.ZIndex = 8
	refs.Content.ZIndex = 3
	refs.Detail.ZIndex = 3

	-- Tabs: paper tabs, the shown one a red brush pill. The button keeps its Text for the UI tests.
	local tabs = {}
	for _, tab in { refs.Daily, refs.Weekly } do
		tab.BackgroundTransparency = 1
		tab.TextTransparency = 1
		local edge = tab:FindFirstChild("Edge")
		if edge then
			edge.Enabled = false
		end
		local caption =
			make("TextLabel", "AnimeCaption", tab, { BackgroundTransparency = 1, Text = tab.Text, ZIndex = 4 })
		tabs[tab] = { Caption = caption, Lit = Dojo.Tab(tab, { caption }) }
		tabs[tab].Lit(false)
	end

	-- Detail: a paper slip.
	local detail = refs.Detail
	Dojo.Fill(detail, C.Slip)
	Dojo.Rim(detail, C.SlipRim, 1.5)
	Dojo.Corner(detail, 6)
	refs.Track.BackgroundColor3 = C.Track
	refs.Fill.BackgroundColor3 = C.Verm
	for _, bar in { refs.Track, refs.Fill } do
		bar:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	end

	local k = 1
	local function px(x)
		return math.floor(x * k + 0.5)
	end
	local function at(x, y)
		return UDim2.fromOffset(px(x), px(y))
	end

	-- A row's "Text" child: row.Text would read the TextButton's Text property.
	local function rowGeometry(row)
		local name, line = row:FindFirstChild("Text"), row:FindFirstChild("Progress")
		row.Size = UDim2.new(1, -px(10), 0, px(100))
		name.Position, name.Size = at(26, 16), UDim2.new(1, -px(200), 0, px(30))
		line.Position, line.Size = at(26, 54), UDim2.new(1, -px(200), 0, px(24))
		text(name, "Item", px(24))
		text(line, "Caption", px(17))
		local claim = row.Claim
		claim.Position, claim.Size = UDim2.new(1, -px(158), 0.5, -px(22)), at(126, 44)
		claim.TextScaled = true
		local limit = claim:FindFirstChild("AnimeLimit") or make("UITextSizeConstraint", "AnimeLimit", claim, {})
		limit.MaxTextSize = px(20)
	end

	local controller = {}
	local view = "Quests"
	local active = false
	local function layout()
		local small = phone()
		local U = Skin.Units
		local W, H = small and U.PhoneW or U.W, small and U.PhoneH or U.H
		aspect.AspectRatio = W / H
		k = math.min(modal.Size.X.Offset / W, modal.Size.Y.Offset / H)
		if k <= 0 then
			return
		end
		local daily = view == "Daily"
		-- Header as AnimeSkin.IndexFrame's (kit.css .hdr): logo, brush title, kanji and sub line, rule, seal close.
		banner.Position, banner.Size = UDim2.new(), UDim2.new(1, 0, 0, px(98))
		logo.Position, logo.Size = at(28, 14), at(70, 70)
		title.Position, title.Size = at(108, 12), at(W - 228, 72)
		text(title, "Title", px(72))
		heading(px, px(W))
		rule.Position, rule.Size = at(28, 90), UDim2.new(1, -px(56), 0, math.max(1, px(3)))
		close.Position, close.Size = at(W - 92, 16), at(64, 64)
		footer.Position, footer.Size = at(W * 303 / 920, H - 60), at(W * 312 / 920, 28)
		text(footer, "Footer", px(20))

		local top = small and 144 or 164
		local gridW, gridH = W - 112, H - top - 82
		if daily then
			-- The Daily view: same chrome, its own content in the grid area (Client/BoostDailyUi lays it out).
			controller.Rect =
				{ X = px(56), Y = px(top), W = px(gridW), H = px(gridH), k = k, Units = { W = gridW, H = gridH } }
			if controller.OnDaily then
				controller.OnDaily(controller.Rect)
			end
			return
		end

		-- Same tab size as the Index's four.
		refs.Tabs.Position, refs.Tabs.Size = at(56, small and 90 or 98), at(W - 112, 40)
		refs.TabLayout.Padding = UDim.new(0, px(8))
		for tab, parts in tabs do
			tab.Size = at((W - 136) / 4, 40)
			parts.Caption.Position, parts.Caption.Size = at(8, 0), UDim2.new(1, -px(16), 1, 0)
			text(parts.Caption, "Tab", px(22))
		end

		-- The Index grid's area: the list on the left, the detail card on the right (phones: the list only).
		local listW = small and gridW or math.floor(gridW * 0.56)
		refs.Content.Position, refs.Content.Size = at(56, top), at(listW, gridH)
		local layoutObject = refs.Content:FindFirstChildOfClass("UIListLayout")
		if layoutObject then
			layoutObject.Padding = UDim.new(0, px(12))
		end
		for _, row in refs.Content:GetChildren() do
			if row:GetAttribute("AnimeRow") then
				rowGeometry(row)
			end
		end
		local detailW = gridW - listW - 16
		detail.Position, detail.Size = at(56 + listW + 16, top), at(detailW, gridH)
		refs.Type.Position, refs.Type.Size = at(26, 26), at(detailW - 52, 22)
		refs.Name.Position, refs.Name.Size = at(26, 52), at(detailW - 52, 70)
		refs.Track.Position, refs.Track.Size = at(26, gridH - 132), at(detailW - 52, 30)
		refs.Reward.Position, refs.Reward.Size = at(26, gridH - 90), at(detailW - 52, 64)
		text(refs.Type, "Item", px(16))
		refs.Type.TextColor3 = C.Verm
		text(refs.Name, "Title", px(30))
		text(refs.ProgressText, "Body", px(17))
		refs.ProgressText.TextColor3 = refs.Fill.Size.X.Scale >= 0.5 and C.Cream or C.Ink
		text(refs.Reward, "Item", px(19))
	end

	controller.px, controller.at = px, at
	-- A text role in design units (Client/AnimeSkin.UnitSize, the same treatment as AnimeSkin.IndexFrame's g.Role).
	function controller.Role(label, role)
		local size = px(Skin.UnitSize[role] or Skin.UnitSize.Body)
		label:SetAttribute("AnimeRole", role)
		Dojo.Text(label, role)
		label.TextScaled = true
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
			or make("UITextSizeConstraint", "AnimeLimit", label, {})
		limit.MaxTextSize = math.max(1, size)
		limit.MinTextSize = math.max(1, math.min(size, px(10)))
	end
	function controller.Button(button, tone)
		Skin.Button(button, tone)
		controller.Role(button, "Item")
	end
	-- "Quests": tabs, list, detail, as approved. "Daily": the same chrome with the Daily title and logo; the caller
	-- lays its content in controller.Rect (px) from controller.OnDaily(rect), called on every layout.
	function controller:SetView(name)
		view = name
		title.Text = name == "Daily" and "DAILY REWARDS" or "QUESTS"
		logo.Image = name == "Daily" and (refs.DailyLogo or refs.Logo) or refs.Logo
		if active then
			layout()
		end
		return controller.Rect
	end
	function controller:SetActive(on)
		active = on
		aspect.Parent = on and modal or nil
		layer.Visible = on
		refs.Header.Visible = not on
		refs.Title.Visible = not on
		refs.Close.Visible = not on
		-- The modal's own fill and edge are already clear (Client/AnimeSkin via PanelFrame); the Index chrome covers
		-- the shared body art while Quests show.
		local body = modal:FindFirstChild("AnimeBody")
		if body then
			body.Visible = not on
		end
		if on then
			layout()
		end
	end
	function controller:Layout()
		if active then
			layout()
		end
	end
	function controller:Tab(category)
		for tab, parts in tabs do
			parts.Lit(tab.Name == category)
		end
	end
	-- state: "Ready", "Progress" or "Claimed". The row is a paper slip with the state's bar at its left end (kit.css
	-- quests frame); its Selection edge stays clear. Claim: the vermilion tile when ready, else an outlined paper button.
	function controller:Row(row, state)
		row:SetAttribute("AnimeRow", state)
		row.Selection.Transparency = 1
		Skin.Plate(row, Style.Tint[state])
		local claim = row.Claim
		Skin.Button(claim, state == "Ready" and "Go" or "Idle")
		local function fonts()
			rowGeometry(row)
			Dojo.Text(claim, "Item")
		end
		fonts()
		-- UiTheme.Apply's deferred DescendantAdded puts new text back on Fredoka: style again after it.
		task.defer(function()
			if row.Parent then
				fonts()
			end
		end)
		if state == "Claimed" then
			row:FindFirstChild("Text").TextTransparency = 0.35
			row.Progress.TextTransparency = 0.35
		end
	end
	-- The chosen quest's slip takes a vermilion rim.
	function controller:Select(rows, id)
		for rowId, refsOfRow in rows do
			local rim = refsOfRow.Button:FindFirstChild("DojoRim")
			if rim then
				rim.Color = rowId == id and C.Verm or C.SlipRim
				rim.Thickness = rowId == id and 2.5 or 1.5
			end
		end
	end
	function controller:Footer(value)
		footer.Text = value
	end
	modal:GetPropertyChangedSignal("Size"):Connect(function()
		if active then
			task.defer(layout)
		end
	end)
	return controller
end

return Style
