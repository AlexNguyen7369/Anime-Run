--!nonstrict
-- The Summon page's layout R3 "Enso and seals" (design doc 4.45 "Hanging-scroll look", owner 2026-11-19), made to match
-- the owner's reference image 1:1 (4.45 "Summon 1:1 reference", assets/ui/summon_ref/owner_reference_2026-11-19.png), dressed onto
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
local PRICE_FONT = Font.fromEnum(Enum.Font.GothamBlack) -- the gold Robux price, bolder than the body face

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
	local scrollItems, riseItems, tileItems = {}, {}, {}
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
	local scroll =
		DojoScroll.new(canvas, { Name = "DojoScroll", Px = Vector2.new(400, 855), ZIndex = 2, Skin = "Parchment" })
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

	-- Rotation timer as a larger red seal at the enso's lower right: "Ends in" small over the time large.
	local timer = canvas.Timer
	place(timer, 306, 410, 90, 54, true)
	timer.ZIndex, timer.Rotation = CONTENT_Z + 2, 0
	timer.BackgroundColor3, timer.BackgroundTransparency, timer.BorderSizePixel = K.Accent, 0, 0
	timer.FontFace, timer.TextColor3, timer.TextScaled = K.BodyBold, K.SealText, true
	timer.TextStrokeTransparency, timer.TextXAlignment = 1, Enum.TextXAlignment.Center
	timer.TextYAlignment = Enum.TextYAlignment.Center
	local pad = timer:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight =
		UDim.new(0.4, 0), UDim.new(0.06, 0), UDim.new(0.1, 0), UDim.new(0.1, 0)
	pad.Parent = timer
	local rim = timer:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	rim.ApplyStrokeMode, rim.Color, rim.Thickness, rim.Transparency =
		Enum.ApplyStrokeMode.Border, Color3.fromRGB(120, 22, 20), 2, 0
	rim.Parent = timer
	local tc = timer:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	tc.CornerRadius, tc.Parent = UDim.new(0, 6), timer
	-- The padding moves children too: the label sits over the time, inside the seal's top 0.08..0.38.
	local endsIn = timer:FindFirstChild("EndsIn") or DojoScroll.Text("EndsIn", timer, {})
	endsIn.Position, endsIn.Size = UDim2.fromScale(0, -0.68), UDim2.fromScale(1, 0.64)
	endsIn.Text, endsIn.TextColor3, endsIn.FontFace = "Ends in", K.SealText, K.BodyBold
	endsIn.ZIndex = CONTENT_Z + 3
	add(scrollItems, enso, timer)

	-- The featured name and its rate in a red brush pill, the thin rule, rates per rarity, both pity counters, the buttons.
	local featName = label("FeatName", canvas, 65, 454, 332, 32, {
		FontFace = K.Heading,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local featRate = canvas:FindFirstChild("FeatRate")
		or DojoScroll.Pill(
			"FeatRate",
			canvas,
			Color3.fromRGB(168, 38, 42),
			{ FontFace = K.BodyBold, TextColor3 = K.SealText, Text = "" }
		) -- the reference's darker brush red
	place(featRate, 151, 490, 164, 27, true)
	featRate.ZIndex = CONTENT_Z
	if not featRate:FindFirstChild("Brushed") then
		-- Dry-brush ends on the pill.
		local g = Instance.new("UIGradient")
		g.Name = "Brushed"
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.05, 0.05),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.95, 0.05),
			NumberSequenceKeypoint.new(1, 0.45),
		})
		g.Parent = featRate
	end
	local brush = canvas:FindFirstChild("Brush") or DojoScroll.Brush("Brush", canvas, {})
	place(brush, 68, 528, 328, 3, true)
	brush.ZIndex = CONTENT_Z
	-- The thin vertical rule between the rates and the pity counters.
	local split = canvas:FindFirstChild("RateRule") or DojoScroll.Brush("RateRule", canvas, {})
	place(split, 226, 542, 2, 132, true)
	split.ZIndex = CONTENT_Z
	split.Fade.Rotation = 90
	add(scrollItems, featName, featRate, brush, split)

	local rates = canvas:FindFirstChild("Rates") or Instance.new("Frame")
	rates.Name, rates.BackgroundTransparency, rates.Parent = "Rates", 1, canvas
	place(rates, 67, 542, 150, 132, true)
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

	for i, y in { 544, 620 } do
		local title_ = canvas["Pity" .. i]
		place(title_, 236, y, 104, 18, true)
		title_.Text = i == 1 and "Legendary Pity" or "Mythic Pity"
		title_.ZIndex, title_.FontFace, title_.TextColor3 = CONTENT_Z, K.Body, K.Ink
		title_.TextScaled, title_.TextStrokeTransparency = true, 1
		title_.TextXAlignment = Enum.TextXAlignment.Left
		local count = canvas["PityCount" .. i]
		place(count, 340, y, 57, 18, true)
		count.ZIndex, count.FontFace, count.TextColor3 = CONTENT_Z, K.BodyBold, K.Ink
		count.TextScaled, count.TextStrokeTransparency = true, 1
		count.TextXAlignment = Enum.TextXAlignment.Right
		local card = canvas["PityCard" .. i]
		place(card, 236, y + 26, 161, 8, true)
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

	-- Details (the chances), Auto Sell and Info: outlined paper buttons in one row at the scroll's foot.
	for _, spec in
		{
			{ "Chances", "Details", 65, 112, K.Accent, "選" },
			{ "AutoSell", "Auto Sell", 193, 104 },
			{ "Info", "Info", 313, 84 },
		}
	do
		local button = canvas[spec[1]]
		strip(button)
		button:SetAttribute("PopButton", nil)
		place(button, spec[3], 700, spec[4], 50, true)
		button.ZIndex = CONTENT_Z
		button.Text = spec[2]
		DojoScroll.PaperButton(button, spec[2], {
			Rim = spec[5],
			Seal = spec[6],
			Fill = K.Skins.Parchment.Paper,
			Font = K.Script,
		})
		add(scrollItems, button)
	end

	-- Right column: knot Close; under it the gem packs as burgundy cards hung on one cord from the top, knotted between
	-- the cards (each card's own cord segment), and More.
	local close = canvas.Close
	strip(close)
	place(close, 1523, 26, 52, 52)
	close.ZIndex = CONTENT_Z
	DojoScroll.Knot(close)
	-- Gem art: overlapped copies of the page's own gem icon (no new upload). Each: x, y, size (scale of the art frame).
	local gemImage = canvas.Balance.CurrencyGem.Image
	local CLUSTER = { { 0.28, 0.62, 0.66 }, { 0.76, 0.64, 0.6 }, { 0.5, 0.44, 0.86 }, { 0.52, 0.84, 0.52 } }
	local function gemArt(holder, count, x, y, w, h)
		local cluster = holder:FindFirstChild("GemArt") or Instance.new("Frame")
		cluster.Name, cluster.BackgroundTransparency, cluster.Active, cluster.Parent = "GemArt", 1, false, holder
		cluster.Position, cluster.Size, cluster.ZIndex = UDim2.fromScale(x, y), UDim2.fromScale(w, h), CONTENT_Z + 1
		for i = 1, count do
			local spec = CLUSTER[i]
			local gem = cluster:FindFirstChild("Gem" .. i) or Instance.new("ImageLabel")
			gem.Name, gem.BackgroundTransparency, gem.Image, gem.Parent = "Gem" .. i, 1, gemImage, cluster
			gem.AnchorPoint, gem.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(spec[1], spec[2])
			gem.Size, gem.ScaleType = UDim2.fromScale(spec[3], spec[3]), Enum.ScaleType.Fit
			gem.ZIndex = CONTENT_Z + (i == 3 and 2 or 1)
		end
		return cluster
	end
	for i, y in { 118, 227 } do
		local offer = canvas["Offer" .. i]
		place(offer, 1394, y, 189, 95)
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
		DojoScroll.Tag(offer, i == 1 and 30 or 14)
		gemArt(offer, i == 1 and 2 or 3, 0, 0, 0.45, 1)
		for n, spec in
			{
				Title = { 0.44, 0.04, 0.53, 0.3, K.Script, K.TagText, Enum.TextXAlignment.Right },
				Luck = { 0.44, 0.34, 0.53, 0.24, K.BodyBold, K.TagText, Enum.TextXAlignment.Center },
				Price = { 0.44, 0.64, 0.24, 0.26, PRICE_FONT, K.TagGold, Enum.TextXAlignment.Left }, -- clear of the Buy pill
			}
		do
			local t = offer[n]
			t.AnchorPoint, t.Position, t.Size =
				Vector2.zero, UDim2.fromScale(spec[1], spec[2]), UDim2.fromScale(spec[3], spec[4])
			t.FontFace, t.TextColor3, t.TextScaled, t.ZIndex = spec[5], spec[6], true, CONTENT_Z + 1
			t.TextStrokeTransparency, t.BackgroundTransparency = 1, 1
			t.TextXAlignment = spec[7]
			for _, d in t:GetChildren() do
				if d:IsA("UIStroke") then
					d.Enabled = false
				end
			end
		end
		if not offer:FindFirstChild("BuyPill") then
			DojoScroll.Pill("BuyPill", offer, K.Cream, {
				Position = UDim2.fromScale(0.7, 0.62),
				Size = UDim2.fromScale(0.26, 0.28),
				Text = "Buy",
				FontFace = K.BodyBold,
				TextColor3 = K.TileInk,
				ZIndex = CONTENT_Z + 1,
			})
		end
		-- The whole card is the Buy button (opens the Buy Gems focus state first, as before); the pill only shows it.
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
	place(more, 1394, 336, 189, 79)
	more.ZIndex = CONTENT_Z
	more.TextStrokeTransparency, more.TextTransparency, more.Text = 1, 1, "More"
	-- The tag's gradient would tint the button's own text: its Caption child carries the label.
	local moreCaption = more.Caption
	moreCaption.Visible, moreCaption.Text, moreCaption.ZIndex = true, "More", CONTENT_Z + 1
	moreCaption.AnchorPoint, moreCaption.Position = Vector2.zero, UDim2.fromScale(0.5, 0.06)
	moreCaption.Size, moreCaption.TextXAlignment = UDim2.fromScale(0.44, 0.38), Enum.TextXAlignment.Right
	moreCaption.FontFace, moreCaption.TextColor3, moreCaption.TextScaled = K.Script, K.TagText, true
	moreCaption.TextStrokeTransparency = 1
	DojoScroll.Tag(more, 16)
	more.AutoButtonColor = false
	-- shortcut: no uploaded chest-of-gems image exists (the relic chests are boss art); a 4-gem cluster stands in until one is uploaded.
	gemArt(more, 4, 0, 0, 0.48, 1)
	if not more:FindFirstChild("ArrowPill") then
		DojoScroll.Pill("ArrowPill", more, K.Cream, {
			Position = UDim2.fromScale(0.68, 0.52),
			Size = UDim2.fromScale(0.26, 0.34),
			Text = utf8.char(0x203A), -- the "›" arrow
			FontFace = K.BodyBold,
			TextColor3 = K.TileInk,
			ZIndex = CONTENT_Z + 1,
		})
	end
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

	-- The three summons as equal cream paper tiles, no tilt: + Many 500, - Once 50, 自 Auto until stop.
	local tiles = {}
	for name, spec in
		{
			Many = { "+", "Many", 1080 },
			Once = { utf8.char(0x2212), "Once", 1254 },
			Auto = { "自", "Auto", 1428 },
		}
	do
		local button = canvas[name]
		strip(button)
		button:SetAttribute("PopButton", nil)
		place(button, spec[3], 736, 148, 130)
		button.ZIndex = CONTENT_Z
		for _, d in button:GetChildren() do
			if d:IsA("UIScale") and d.Name == "HoverScale" then
				d.Scale = 1
			end
		end
		tiles[name] = DojoScroll.Tile(button, { Glyph = spec[1], Label = spec[2] })
		local cost = tiles[name].Cost
		local gemIcon = button:FindFirstChild("CurrencyGem")
		if gemIcon then
			gemIcon.AnchorPoint, gemIcon.Position = Vector2.new(0, 0.5), UDim2.fromScale(0.56, 0.81)
			gemIcon.Size, gemIcon.ZIndex = UDim2.fromOffset(22, 22), button.ZIndex + 2
			gemIcon.Visible = name ~= "Auto"
			cost.Position, cost.Size =
				UDim2.fromScale(0.08, 0.725), UDim2.fromScale(name ~= "Auto" and 0.45 or 0.84, 0.17)
			cost.TextXAlignment = name ~= "Auto" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center
		end
		add(tileItems, button)
	end
	page.Tiles = tiles

	-- Stage labels: names white and rarities in their colour, both with a dark outline; "Featured!" with its star in a
	-- dark red pill above the Mythic's name.
	for i = 1, 3 do
		local unitLabel, rarity = canvas["Unit" .. i], canvas["Rarity" .. i]
		unitLabel.TextColor3 = Color3.new(1, 1, 1)
		for _, d in rarity:GetChildren() do
			if d:IsA("UIGradient") then
				d.Enabled = false -- the label's TextColor3 (the rarity colour, set by the page) shows as is
			end
		end
	end
	local featured = canvas.Featured
	place(featured, 758, 549, 240, 44)
	featured.BackgroundColor3, featured.BackgroundTransparency = Color3.fromRGB(118, 18, 26), 0.08
	featured.TextColor3, featured.TextScaled = Color3.fromRGB(255, 214, 92), true
	local fg = featured:FindFirstChild("FeaturedGradient")
	if fg then
		fg.Enabled = false -- it would tint the pill as well as the text
	end
	local fc = featured:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	fc.CornerRadius, fc.Parent = UDim.new(0.5, 0), featured
	local fpadding = featured:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	fpadding.PaddingTop, fpadding.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
	fpadding.PaddingLeft, fpadding.PaddingRight = UDim.new(0, 44), UDim.new(0, 14)
	fpadding.Parent = featured
	local star = featured:FindFirstChild("FeaturedStar")
	if star then
		star.AnchorPoint, star.Position, star.Size =
			Vector2.new(0, 0.5), UDim2.new(0, -36, 0.5, 0), UDim2.fromOffset(30, 30)
	end

	-- Server values in, text out. state: { Featured (row or nil), FeaturedOdds, Sums (rarity -> percent),
	-- Unlocked, UnlockRebirth, OnceCost, ManyCost, Auto }.
	function page.Refresh(state)
		local row = state.Featured
		featName.Text = row and row.Name or "Loading rotation…"
		featRate.Text = row and string.format("%s, %s", row.Rarity, percent(state.FeaturedOdds or 0)) or ""
		featRate.Visible = row ~= nil
		for rarity, item in rateRows do
			local sum = state.Sums[rarity]
			item.Row.Visible = sum ~= nil
			item.Value.Text = sum and percent(sum) or ""
		end
		tiles.Once.Cost.Text = tostring(state.OnceCost)
		tiles.Many.Cost.Text = tostring(state.ManyCost)
		tiles.Auto.Cost.Text = "until stop"
		tiles.Auto.Label.Text = state.Auto and "Stop" or "Auto"
		for _, tile in tiles do
			tile.SetLocked(not state.Unlocked)
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
		DojoScroll.Ink(tileItems, true, DojoScroll.RISE_AT + 0.08, 0.32, DojoScroll.RISE)
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
		DojoScroll.Ink(tileItems, false, 0, 0.2)
	end

	canvas:SetAttribute("SummonTheme", "HangingScrollR3")
	return page
end

return SummonScroll
