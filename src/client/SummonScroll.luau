--!nonstrict
-- The Summon page's layout R3 "Enso and seals" (design doc 4.45 "Hanging-scroll look", owner 2026-11-19), dressed onto
-- the native template's controls (StarterGui.RacerSidekicks.Canvas) with Client/DojoScroll. Every control keeps its name
-- and its parent (the canvas) so the page script and the UI tests still find it; only looks and places change. The
-- client only displays: costs, odds, pity and the rotation come from the server's attributes. Sizes proposed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(shared:WaitForChild("UiTheme"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local DojoScroll = require(script.Parent:WaitForChild("DojoScroll"))

local K = UiTheme.Scroll
local SummonScroll = {}

local RARITIES = { "Common", "Rare", "Legendary", "Mythic", "Secret" }
local CONTENT_Z = 6

-- Template decoration from the shrine look that R3 drops.
local OLD = { TopLight = true, Gloss = true, HoverGlow = true, ShrineBlossomStamp = true, CloseIcon = true }
local function strip(object)
	for _, d in object:GetDescendants() do
		if OLD[d.Name] and d:IsA("GuiObject") then
			d.Visible = false
		elseif d:IsA("UIGradient") and d.Name == "CaptionGradient" then
			d.Enabled = false
		end
	end
	local caption = object:FindFirstChild("Caption")
	if caption then
		caption.Visible = false
	end
end

-- Places a canvas child in design px (1600 x 900; Client/SidekickUi fit() turns that into the real place). `item`:
-- part of the scroll (stays with the scroll on tall screens).
local function place(object, x, y, w, h, item)
	object.AnchorPoint = Vector2.zero
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(w, h)
	object:SetAttribute("DesignPosition", Vector2.new(x, y))
	object:SetAttribute("ScrollItem", item or nil)
	object.Visible = true
end

local function label(name, canvas, x, y, w, h, props)
	local l = canvas:FindFirstChild(name) or DojoScroll.Text(name, canvas, {})
	place(l, x, y, w, h, true)
	l.ZIndex = CONTENT_Z
	for key, value in props or {} do
		l[key] = value
	end
	return l
end

local function percent(odds)
	if odds > 0 and odds < 0.01 then
		return string.format("%.3f%%", odds)
	end
	return (string.format("%.2f", odds):gsub("%.?0+$", "")) .. "%"
end

-- Builds the scroll and dresses the template. Returns the page object: Refresh(state), Open(), Close(), InkItems.
function SummonScroll.Apply(canvas)
	local page = {}
	local scrollItems, riseItems, sealItems = {}, {}, {}
	local function add(list, ...)
		for _, o in { ... } do
			table.insert(list, o)
		end
	end
	for _, name in
		{
			"TopShade",
			"BottomShade",
			"SummonTicket",
			"OnceDepth",
			"ManyDepth",
			"AutoDepth",
			"AutoFuseDepth",
			"AutoSellDepth",
		}
	do
		local o = canvas:FindFirstChild(name)
		if o then
			o.Visible = false
		end
	end

	-- The scroll (left). Paper spans y 101..776, x 45..415; content x 65..397.
	local scroll = DojoScroll.new(canvas, { Name = "DojoScroll", Px = Vector2.new(400, 855), ZIndex = 2 })
	scroll.Root:SetAttribute("DesignPosition", Vector2.new(30, 0) - DojoScroll.MARGIN)
	scroll.Root:SetAttribute("ScrollItem", true)
	page.Scroll = scroll

	-- Wordmark, kanji, banner line.
	local title = canvas.Title
	place(title, 66, 112, 230, 70, true)
	title.ZIndex = CONTENT_Z
	title.Text = "Summon"
	title.TextTransparency = 1 -- the baked wordmark shows instead (assets/ui/hanging_scroll)
	title.TextStrokeTransparency = 1
	local mark = title:FindFirstChild("Wordmark")
		or DojoScroll.Wordmark("Wordmark", title, "Summon", { Size = UDim2.fromScale(1, 1), ZIndex = CONTENT_Z })
	mark.ImageColor3 = K.Ink
	local kanji = label("Kanji", canvas, 364, 116, 36, 72, {
		Text = "召\n喚",
		TextColor3 = K.Accent,
		Font = Enum.Font.GothamBold, -- CJK through Roblox's font fallback; decoration only (4.45)
		LineHeight = 0.95,
	})
	local subtitle = canvas.Subtitle
	place(subtitle, 67, 196, 220, 26, true)
	subtitle.ZIndex, subtitle.TextScaled = CONTENT_Z, true
	subtitle.FontFace, subtitle.TextColor3 = K.Heading, K.Ink
	subtitle.TextStrokeTransparency, subtitle.TextXAlignment = 1, Enum.TextXAlignment.Left
	subtitle.Text = "Sidekick Banner"
	local tagline = canvas.Tagline
	place(tagline, 250, 200, 147, 20, true)
	tagline.ZIndex, tagline.TextScaled, tagline.TextWrapped = CONTENT_Z, true, true
	tagline.FontFace, tagline.TextColor3 = K.Body, K.Muted
	tagline.TextStrokeTransparency, tagline.TextXAlignment = 1, Enum.TextXAlignment.Right
	add(scrollItems, title, kanji, subtitle, tagline)

	-- The enso: Banner1 (opens the Featured panel) holds the featured Mythic's drawn portrait (owner 2026-11-19).
	local enso = canvas.Banner1
	strip(enso)
	place(enso, 125, 232, 216, 216, true)
	enso.ZIndex = CONTENT_Z
	enso.BackgroundTransparency, enso.AutoButtonColor = 1, false
	enso.TextTransparency, enso.TextStrokeTransparency = 1, 1
	for _, d in enso:GetChildren() do
		if d:IsA("UIStroke") or d:IsA("UIGradient") then
			d.Enabled = false
		end
	end
	local ring = enso:FindFirstChild("Ring") or Instance.new("ImageLabel")
	ring.Name, ring.Parent = "Ring", enso
	ring.BackgroundTransparency, ring.Image, ring.ImageColor3 = 1, K.Enso, K.Ink
	ring.ImageTransparency, ring.Size, ring.ZIndex = 0.1, UDim2.fromScale(1, 1), CONTENT_Z + 1
	local art = enso.UnitArtwork
	art.AnchorPoint, art.Position = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.13)
	art.Size, art.ZIndex = UDim2.fromScale(0.72, 0.72), CONTENT_Z
	art.ScaleType = Enum.ScaleType.Fit
	art.BackgroundTransparency = 1

	-- Rotation timer as a red seal at the enso's lower right.
	local timer = canvas.Timer
	place(timer, 318, 392, 70, 46, true)
	timer.ZIndex, timer.Rotation = CONTENT_Z + 2, -3
	timer.BackgroundColor3, timer.BackgroundTransparency, timer.BorderSizePixel = K.Accent, 0, 0
	timer.FontFace, timer.TextColor3, timer.TextScaled = K.BodyBold, K.Paper, true
	timer.TextStrokeTransparency, timer.TextXAlignment = 1, Enum.TextXAlignment.Center
	timer.TextYAlignment = Enum.TextYAlignment.Bottom
	local pad = timer:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight =
		UDim.new(0.38, 0), UDim.new(0.08, 0), UDim.new(0.08, 0), UDim.new(0.08, 0)
	pad.Parent = timer
	local rim = timer:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	rim.ApplyStrokeMode, rim.Color, rim.Thickness, rim.Transparency = Enum.ApplyStrokeMode.Border, K.Paper, 1.5, 0.2
	rim.Parent = timer
	local tc = timer:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	tc.CornerRadius, tc.Parent = UDim.new(0, 6), timer
	if not timer:FindFirstChild("EndsIn") then
		DojoScroll.Text("EndsIn", timer, {
			Position = UDim2.fromScale(0, -0.62),
			Size = UDim2.fromScale(1, 0.5),
			Text = "ends in",
			TextColor3 = K.Paper,
			ZIndex = CONTENT_Z + 2,
		})
	end
	add(scrollItems, enso, timer)

	-- The featured name and rate, the brush line, rates per rarity, both pity counters, the links.
	local featName = label("FeatName", canvas, 65, 454, 332, 32, {
		FontFace = K.Heading,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local featRate = label("FeatRate", canvas, 65, 486, 332, 19, {
		FontFace = K.BodyBold,
		Text = "",
		TextColor3 = SidekickView.RarityColor("Mythic"),
	})
	local brush = canvas:FindFirstChild("Brush") or DojoScroll.Brush("Brush", canvas, {})
	place(brush, 68, 520, 328, 4, true)
	brush.ZIndex = CONTENT_Z
	add(scrollItems, featName, featRate, brush)

	local rates = canvas:FindFirstChild("Rates") or Instance.new("Frame")
	rates.Name, rates.BackgroundTransparency, rates.Parent = "Rates", 1, canvas
	place(rates, 67, 540, 160, 128, true)
	rates.ZIndex = CONTENT_Z
	local rateRows = {}
	for i, rarity in RARITIES do
		local row = rates:FindFirstChild(rarity) or Instance.new("Frame")
		row.Name, row.BackgroundTransparency, row.Parent = rarity, 1, rates
		row.Position, row.Size, row.ZIndex = UDim2.fromScale(0, (i - 1) / 5), UDim2.fromScale(1, 0.18), CONTENT_Z
		local dot = row:FindFirstChild("Dot") or Instance.new("Frame")
		dot.Name, dot.Parent, dot.BorderSizePixel = "Dot", row, 0
		dot.AnchorPoint, dot.Position = Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5)
		dot.Size, dot.ZIndex = UDim2.fromOffset(11, 11), CONTENT_Z
		dot.BackgroundColor3 = SidekickView.RarityColor(rarity)
		local dc = dot:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		dc.CornerRadius, dc.Parent = UDim.new(0.5, 0), dot
		local name = row:FindFirstChild("Name") or DojoScroll.Text("Name", row, {})
		name.Position, name.Size, name.ZIndex = UDim2.fromOffset(19, 0), UDim2.new(0.62, -19, 1, 0), CONTENT_Z
		name.Text, name.TextXAlignment = rarity, Enum.TextXAlignment.Left
		local value = row:FindFirstChild("Value") or DojoScroll.Text("Value", row, {})
		value.Position, value.Size, value.ZIndex = UDim2.fromScale(0.55, 0), UDim2.fromScale(0.45, 1), CONTENT_Z
		value.FontFace, value.TextXAlignment, value.Text = K.BodyBold, Enum.TextXAlignment.Right, ""
		rateRows[rarity] = { Row = row, Value = value }
	end
	add(scrollItems, rates)

	for i, y in { 548, 612 } do
		local title_ = canvas["Pity" .. i]
		place(title_, 240, y, 100, 22, true)
		title_.ZIndex, title_.FontFace, title_.TextColor3 = CONTENT_Z, K.Body, K.Ink
		title_.TextScaled, title_.TextStrokeTransparency = true, 1
		title_.TextXAlignment = Enum.TextXAlignment.Left
		local count = canvas["PityCount" .. i]
		place(count, 300, y, 97, 22, true)
		count.ZIndex, count.FontFace, count.TextColor3 = CONTENT_Z, K.BodyBold, K.Ink
		count.TextScaled, count.TextStrokeTransparency = true, 1
		count.TextXAlignment = Enum.TextXAlignment.Right
		local card = canvas["PityCard" .. i]
		place(card, 240, y + 30, 157, 8, true)
		card.ZIndex, card.BackgroundTransparency = CONTENT_Z, 1
		for _, d in card:GetChildren() do
			if d:IsA("UIStroke") or d:IsA("UIGradient") then
				d.Enabled = false
			elseif d.Name == "Star" then
				d.Visible = false
			end
		end
		local track = card.Track
		track.Position, track.Size, track.ZIndex = UDim2.new(), UDim2.fromScale(1, 1), CONTENT_Z
		track.BackgroundColor3, track.BackgroundTransparency = K.Ink, 0.86
		local trc = track:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		trc.CornerRadius, trc.Parent = UDim.new(0.5, 0), track
		local progress = track.Progress
		progress.ZIndex = CONTENT_Z + 1
		progress.BackgroundColor3 = SidekickView.RarityColor(i == 1 and "Legendary" or "Mythic")
		local pg = progress:FindFirstChildOfClass("UIGradient")
		if pg then
			pg.Enabled = false
		end
		local pc = progress:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		pc.CornerRadius, pc.Parent = UDim.new(0.5, 0), progress
		add(scrollItems, title_, count, card)
	end

	-- Links: Details (the chances), Auto Sell, Summon Info.
	for _, spec in
		{ { "Chances", "Details", 67, 64 }, { "AutoSell", "Auto Sell", 147, 86 }, { "Info", "Info", 249, 40 } }
	do
		local button = canvas[spec[1]]
		strip(button)
		button:SetAttribute("PopButton", nil)
		place(button, spec[3], 678, spec[4], 28, true)
		button.ZIndex = CONTENT_Z
		for _, d in button:GetChildren() do
			if d:IsA("UIStroke") or d:IsA("UIGradient") then
				d.Enabled = false
			end
		end
		button.Text = spec[2]
		DojoScroll.Link(button, spec[2])
		add(scrollItems, button)
	end

	-- Right column: knot Close, burgundy gem-pack tags and More under it.
	local close = canvas.Close
	strip(close)
	place(close, 1523, 26, 52, 52)
	close.ZIndex = CONTENT_Z
	DojoScroll.Knot(close)
	for i, y in { 125, 240 } do
		local offer = canvas["Offer" .. i]
		place(offer, 1421, y, 152, 86)
		offer.ZIndex = CONTENT_Z
		for _, n in { "Symbol", "PotionIcon", "Glow", "Sheen" } do
			local o = offer:FindFirstChild(n)
			if o then
				o.Visible = false
			end
		end
		local prism = offer:FindFirstChild("Prism", true)
		if prism then
			prism.Enabled = false
		end
		DojoScroll.Tag(offer, 22)
		for n, spec in
			{
				Title = { 0.1, 0.36, K.Heading, K.TagText },
				Luck = { 0.43, 0.22, K.Body, K.TagText },
				Price = { 0.66, 0.24, K.BodyBold, K.TagPrice },
			}
		do
			local t = offer[n]
			t.AnchorPoint, t.Position, t.Size =
				Vector2.zero, UDim2.fromScale(0.05, spec[1]), UDim2.fromScale(0.9, spec[2])
			t.FontFace, t.TextColor3, t.TextScaled, t.ZIndex = spec[3], spec[4], true, CONTENT_Z + 1
			t.TextStrokeTransparency, t.BackgroundTransparency = 1, 1
			t.TextXAlignment = Enum.TextXAlignment.Center
			for _, d in t:GetChildren() do
				if d:IsA("UIStroke") then
					d.Enabled = false
				end
			end
		end
		-- The whole tag is the Buy button (opens the Buy Gems focus state first, as before).
		local buy = offer.Buy
		strip(buy)
		buy.AnchorPoint, buy.Position, buy.Size = Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1)
		buy.BackgroundTransparency, buy.TextTransparency, buy.TextStrokeTransparency = 1, 1, 1
		buy.ZIndex, buy.AutoButtonColor = CONTENT_Z + 2, false
		for _, d in buy:GetChildren() do
			if d:IsA("UIStroke") or d:IsA("UIGradient") then
				d.Enabled = false
			end
		end
		add(riseItems, offer)
	end
	local more = canvas.More
	strip(more)
	place(more, 1421, 352, 152, 36)
	more.ZIndex = CONTENT_Z
	more.TextStrokeTransparency, more.TextTransparency, more.Text = 1, 1, "More"
	-- The tag's gradient would tint the button's own text: its Caption child carries the label.
	local moreCaption = more.Caption
	moreCaption.Visible, moreCaption.Text, moreCaption.ZIndex = true, "More", CONTENT_Z + 1
	moreCaption.AnchorPoint, moreCaption.Position, moreCaption.Size = Vector2.zero, UDim2.new(), UDim2.fromScale(1, 1)
	moreCaption.FontFace, moreCaption.TextColor3, moreCaption.TextScaled = K.Heading, K.TagText, false
	moreCaption.TextSize, moreCaption.TextStrokeTransparency = 18, 1
	DojoScroll.Tag(more, 14)
	more.AutoButtonColor = false
	add(riseItems, more)

	-- Gem balance on a paper slip; the free summon on a slip beside it when it is offered.
	local balance = canvas.Balance
	place(balance, 1423, 655, 146, 44)
	balance.ZIndex = CONTENT_Z
	DojoScroll.Slip(balance)
	balance.FontFace, balance.TextColor3, balance.TextScaled = K.BodyBold, K.Ink, true
	balance.TextStrokeTransparency, balance.TextXAlignment = 1, Enum.TextXAlignment.Left
	local bpad = balance:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	bpad.PaddingLeft, bpad.PaddingRight = UDim.new(0, 44), UDim.new(0, 48)
	bpad.PaddingTop, bpad.PaddingBottom, bpad.Parent = UDim.new(0, 8), UDim.new(0, 8), balance
	local gem = balance.CurrencyGem
	gem.AnchorPoint, gem.Position, gem.Size = Vector2.new(0, 0.5), UDim2.new(0, -32, 0.5, 0), UDim2.fromOffset(24, 24)
	gem.ZIndex = CONTENT_Z + 1
	if not balance:FindFirstChild("Unit") then
		DojoScroll.Text("Unit", balance, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 44, 0.12, 0),
			Size = UDim2.new(0, 40, 0.8, 0),
			Text = "gems",
			TextColor3 = K.Muted,
			ZIndex = CONTENT_Z + 1,
		})
	end
	local free = canvas.AutoFuse
	local freeShown = free.Visible
	strip(free)
	free:SetAttribute("PopButton", nil)
	place(free, 1250, 655, 160, 44)
	free.Visible = freeShown
	free.ZIndex = CONTENT_Z
	for _, d in free:GetChildren() do
		if d:IsA("UIGradient") then
			d.Enabled = false
		end
	end
	DojoScroll.Slip(free)
	free.FontFace, free.TextColor3, free.TextScaled = K.Heading, K.Accent, true
	free.TextStrokeTransparency, free.TextTransparency = 1, 0
	local fpad = free:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	fpad.PaddingTop, fpad.PaddingBottom, fpad.Parent = UDim.new(0.2, 0), UDim.new(0.2, 0), free
	free.Text = "Free summon"
	add(riseItems, balance, free)

	-- The three summons as hanko seals: Many 500, Once 50 (largest, centre), Auto.
	local seals = {}
	for name, spec in
		{
			Many = { "十", "Many", 1156, 804, 137, 2 },
			Once = { "一", "Once", 1329, 793, 160, -2 },
			Auto = { "自", "Auto", 1501, 804, 137, 1.5 },
		}
	do
		local button = canvas[name]
		strip(button)
		button:SetAttribute("PopButton", nil)
		place(button, spec[3] - spec[5] / 2, spec[4] - spec[5] / 2, spec[5], spec[5])
		button.ZIndex = CONTENT_Z
		for _, d in button:GetChildren() do
			if d:IsA("UIScale") and d.Name == "HoverScale" then
				d.Scale = 1
			end
		end
		seals[name] = DojoScroll.Seal(button, { Kanji = spec[1], Label = spec[2], Rotation = spec[6] })
		local cost = seals[name].Cost
		local gemIcon = button:FindFirstChild("CurrencyGem")
		if gemIcon then
			gemIcon.AnchorPoint, gemIcon.Position = Vector2.new(0, 0.5), UDim2.fromScale(0.6, 0.785)
			gemIcon.Size, gemIcon.ZIndex = UDim2.fromScale(0.13, 0.13), button.ZIndex + 2
			gemIcon.Visible = name ~= "Auto"
			cost.Position, cost.Size = UDim2.fromScale(0.1, 0.72), UDim2.fromScale(name ~= "Auto" and 0.48 or 0.8, 0.13)
			cost.TextXAlignment = name ~= "Auto" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center
		end
		add(sealItems, button)
	end
	page.Seals = seals

	-- Server values in, text out. state: { Featured (row or nil), FeaturedOdds, Sums (rarity -> percent),
	-- Unlocked, UnlockRebirth, OnceCost, ManyCost, Auto }.
	function page.Refresh(state)
		local row = state.Featured
		featName.Text = row and row.Name or "Loading rotation…"
		featRate.Text = row and string.format("%s, %s", row.Rarity, percent(state.FeaturedOdds or 0)) or ""
		featRate.TextColor3 = SidekickView.RarityColor(row and row.Rarity or "Mythic")
		for rarity, item in rateRows do
			local sum = state.Sums[rarity]
			item.Row.Visible = sum ~= nil
			item.Value.Text = sum and percent(sum) or ""
		end
		seals.Once.Cost.Text = tostring(state.OnceCost)
		seals.Many.Cost.Text = tostring(state.ManyCost)
		seals.Auto.Cost.Text = "until stop"
		seals.Auto.Label.Text = state.Auto and "Stop" or "Auto"
		for _, seal in seals do
			seal.SetLocked(not state.Unlocked)
		end
		tagline.Text = state.Unlocked and "This rotation" or string.format("Unlocks at Rebirth %d", state.UnlockRebirth)
		tagline.TextColor3 = state.Unlocked and K.Muted or K.Accent
	end

	-- Open: the scroll drops and unrolls, its text inks in, the right-hand controls rise (4.45 motion).
	function page.Open()
		scroll.Open()
		DojoScroll.Ink(scrollItems, true, DojoScroll.INK_AT)
		DojoScroll.Ink({ close }, true, 0.3)
		DojoScroll.Ink(riseItems, true, DojoScroll.RISE_AT, 0.32, DojoScroll.RISE)
		DojoScroll.Ink(sealItems, true, DojoScroll.RISE_AT + 0.08, 0.32, DojoScroll.RISE)
	end

	-- Close: rolls the scroll up and fades the rest (0.3 s), under the Sakura wash.
	function page.Close()
		if not scroll.Opened() then
			return
		end
		scroll.Close()
		DojoScroll.Ink(scrollItems, false, 0, 0.12)
		DojoScroll.Ink({ close }, false, 0, 0.2)
		DojoScroll.Ink(riseItems, false, 0, 0.2)
		DojoScroll.Ink(sealItems, false, 0, 0.2)
	end

	canvas:SetAttribute("SummonTheme", "HangingScrollR3")
	return page
end

return SummonScroll
