--!nonstrict
-- Quests in the Index look (design doc 4.42): Client/IndexAnimeStyle's art and text treatment on BoostDailyUi's
-- shared modal, laid out in the Index's design units (920 x 620, phone 500 x 420) scaled to the modal. Display only.
local IndexStyle = require(script.Parent:WaitForChild("IndexAnimeStyle"))
local UiTheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UiTheme"))
local ART, image, text = IndexStyle.Art, IndexStyle.Image, IndexStyle.Text

local Style = {}
-- Plate colours by quest state (placeholders). In progress uses the Index's default card blue.
Style.Tint = {
	Ready = Color3.fromRGB(60, 230, 120),
	Progress = Color3.fromRGB(70, 205, 255),
	Claimed = Color3.fromRGB(120, 125, 140),
}
local DIM = Color3.fromRGB(225, 225, 235) -- an unlit tab, as in the Index
local WHITE = Color3.new(1, 1, 1)

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
	local body = image(layer, "Body", ART.Chrome, UDim2.new(), UDim2.new(), 1)
	local banner = make("Frame", "Banner", layer, { BackgroundTransparency = 1, ZIndex = 6 })
	local logo = image(banner, "Logo", refs.Logo, UDim2.new(), UDim2.new(), 11)
	logo.ScaleType = Enum.ScaleType.Fit
	local title = make("TextLabel", "Title", banner, {
		BackgroundTransparency = 1,
		Rotation = -2,
		Text = "QUESTS",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
	})
	local close = make("ImageButton", "Close", layer, {
		BackgroundTransparency = 1,
		Image = ART.Close,
		ScaleType = Enum.ScaleType.Fit,
		AutoButtonColor = false,
		ZIndex = 10,
	})
	close.Activated:Connect(refs.OnClose)
	local footer = make("TextLabel", "Footer", layer, { BackgroundTransparency = 1, Text = "", ZIndex = 4 })
	-- Above the art layer, as the Index's header (8) and grid (3) sit above its chrome.
	refs.Tabs.ZIndex = 8
	refs.Content.ZIndex = 3
	refs.Detail.ZIndex = 3

	-- Tabs: the Index's DAILY / WEEKLY art in place of the flat buttons. The button keeps its Text for the UI tests.
	local tabs = {}
	for i, tab in { refs.Daily, refs.Weekly } do
		tab.BackgroundTransparency = 1
		tab.TextTransparency = 1
		local edge = tab:FindFirstChild("Edge")
		if edge then
			edge.Enabled = false
		end
		tabs[tab] = {
			Art = image(tab, "AnimeTabArt", ART.Tabs[i], UDim2.new(), UDim2.new(), 2),
			Caption = make(
				"TextLabel",
				"AnimeCaption",
				tab,
				{ BackgroundTransparency = 1, Text = tab.Text, ZIndex = 4 }
			),
		}
	end

	-- Detail: the angular card, cyan like an undiscovered-rarity Index card.
	local detail = refs.Detail
	detail.BackgroundTransparency = 1
	local detailEdge = detail:FindFirstChildOfClass("UIStroke")
	if detailEdge then
		detailEdge.Enabled = false
	end
	local card = image(detail, "AngularCard", ART.Card, UDim2.new(), UDim2.fromScale(1, 1), 0)
	card.ImageColor3 = Style.Tint.Progress
	refs.Type.TextColor3 = UiTheme.Palette.Sky
	refs.Reward.TextColor3 = UiTheme.Palette.Gold
	refs.Track.BackgroundColor3 = Color3.fromRGB(6, 9, 22)
	for _, bar in { refs.Track, refs.Fill } do
		bar:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 3)
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
		text(name, px(24))
		text(line, px(17))
		line.TextColor3 = UiTheme.Palette.SoftText
		local claim = row.Claim
		claim.Position, claim.Size = UDim2.new(1, -px(158), 0.5, -px(22)), at(126, 44)
		claim.TextScaled = true
		local limit = claim:FindFirstChild("AnimeLimit") or make("UITextSizeConstraint", "AnimeLimit", claim, {})
		limit.MaxTextSize = px(20)
	end

	local function layout()
		local small = phone()
		local W, H = small and 500 or 920, small and 420 or 620
		aspect.AspectRatio = W / H
		k = math.min(modal.Size.X.Offset / W, modal.Size.Y.Offset / H)
		if k <= 0 then
			return
		end
		body.Position, body.Size = at(-40, -70), UDim2.new(1, px(80), 1, px(100))
		banner.Position, banner.Size = at(-34, -18), UDim2.new(1, px(68), 0, px(86))
		logo.Position, logo.Size = at(15, -54), at(188, 186)
		title.Position, title.Size = at(202, -5), at(250, 76)
		text(title, px(72))
		close.Position, close.Size = at(W - 82, -6), at(74, 74)
		footer.Position, footer.Size = at(W * 303 / 920, H - 60), at(W * 312 / 920, 28)
		text(footer, px(20))
		local stroke = footer:FindFirstChildOfClass("UIStroke")
		stroke.Thickness = 1.5

		-- Same tab size as the Index's four.
		refs.Tabs.Position, refs.Tabs.Size = at(56, small and 90 or 98), at(W - 112, 40)
		refs.TabLayout.Padding = UDim.new(0, px(8))
		for tab, parts in tabs do
			tab.Size = at((W - 136) / 4, 40)
			parts.Art.Position, parts.Art.Size = at(-7, -5), UDim2.new(1, px(14), 1, px(10))
			parts.Caption.Position, parts.Caption.Size = at(8, 0), UDim2.new(1, -px(16), 1, 0)
			text(parts.Caption, px(22))
		end

		-- The Index grid's area: the list on the left, the detail card on the right (phones: the list only).
		local top = small and 144 or 164
		local gridW, gridH = W - 112, H - top - 82
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
		text(refs.Type, px(16))
		refs.Type.TextColor3 = UiTheme.Palette.Sky
		text(refs.Name, px(30))
		text(refs.ProgressText, px(17))
		text(refs.Reward, px(19))
		refs.Reward.TextColor3 = UiTheme.Palette.Gold
	end

	local controller = {}
	local active = false
	function controller:SetActive(on)
		active = on
		aspect.Parent = on and modal or nil
		layer.Visible = on
		refs.Header.Visible = not on
		refs.Title.Visible = not on
		refs.Close.Visible = not on
		-- The modal's own dark body and edge give way to the chrome art. Fades only move BackgroundTransparency.
		local gradient = modal:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Transparency = NumberSequence.new(on and 1 or 0)
		end
		local edge = modal:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Enabled = not on
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
			parts.Art.ImageColor3 = tab.Name == category and WHITE or DIM
		end
	end
	-- state: "Ready", "Progress" or "Claimed". The row's own fill and Selection edge stay clear.
	function controller:Row(row, state)
		row:SetAttribute("AnimeRow", state)
		row.BackgroundTransparency = 1
		row.Selection.Transparency = 1
		local plate = image(row, "AngularPlate", ART.Plate, UDim2.new(), UDim2.fromScale(1, 1), 0)
		plate.ImageColor3 = Style.Tint[state]
		local claim = row.Claim
		local function fonts()
			rowGeometry(row)
			claim.FontFace =
				Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
		end
		fonts()
		-- UiTheme.Apply's deferred DescendantAdded puts new text back on Fredoka: style again after it.
		task.defer(function()
			if row.Parent then
				fonts()
			end
		end)
		claim:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 3)
		if state == "Claimed" then
			row:FindFirstChild("Text").TextTransparency = 0.35
			row.Progress.TextTransparency = 0.35
		end
	end
	-- The chosen quest's plate shows the art's own white edge, as a lit Index tab does.
	function controller:Select(rows, id)
		for rowId, refsOfRow in rows do
			local plate = refsOfRow.Button:FindFirstChild("AngularPlate")
			if plate then
				local base = Style.Tint[refsOfRow.Button:GetAttribute("AnimeRow")] or Style.Tint.Progress
				plate.ImageColor3 = rowId == id and WHITE or base
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
