--!nonstrict
-- Shop (docs/MONETIZATION_SPEC.md): Gamepasses, Potions + bundle, Server Luck, Codes.
-- Display and purchase prompts only; Roblox owns prices and ownership, Server/ShopService grants products and codes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("MonetizationConfig"))
local Boosts = require(shared:WaitForChild("BoostConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local Ui = script.Parent:WaitForChild("RollToast"):WaitForChild("Ui")
local Icons = require(Ui.HudIcons)
local PotionIcons = require(Ui.PotionIcons)
local UiTheme = require(shared:WaitForChild("UiTheme"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local Dojo = require(script.Parent:WaitForChild("IndexAnimeStyle")).Dojo

local OUTLINE = UiTheme.Outline
local PALETTE = UiTheme.Palette
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"
local HINT = "Follow the socials on the game page for codes!"
-- Layout in the Index frame's design units (Client/AnimeSkin.IndexFrame); OnLayout below places all. Design doc 4.46
-- (assets/ui/scroll_redesign/drafts/shop.html): the one list in three columns, Gamepasses / Potions and the bundle /
-- Server Luck and Codes; phones stack them in that order. Sizes are placeholders.
local TOP = 104 -- no tabs: the list starts under the header rule
local HEAD_H = 32 -- a section heading
local GAP = 8
local PASS_H = 72 -- a gamepass card
local PACK_H = 117 -- a potion pack card
local BUNDLE_H = 140
local LUCK_H = 248
local CODES_H = HEAD_H + GAP + 36 + GAP + 40
local THANKS_H = 24
local DETAILS_W = 60
-- Paid offers (design doc 4.46, kit.css .tag): burgundy cards with pink rims, gold Robux price, cream Buy pill.
local BURG_TOP, BURG_BOTTOM = Color3.fromRGB(90, 30, 42), Color3.fromRGB(64, 20, 32) -- #5A1E2A, #401420
local PINK = Color3.fromRGB(244, 145, 171) -- #F491AB
local PINK_TEXT = Color3.fromRGB(245, 217, 223) -- #F5D9DF
local GOLD = Color3.fromRGB(255, 204, 72) -- #FFCC48
local OFF_FILL, OFF_TEXT = Color3.fromRGB(125, 106, 102), Color3.fromRGB(233, 220, 216) -- a pill that cannot be pressed
local OFF_PRICE = Color3.fromRGB(205, 179, 184) -- #CDB3B8
local TIER_FILL = Color3.fromRGB(42, 11, 20) -- #2A0B14

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function corner(parent, radius)
	make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, radius) })
end
local function stroke(parent, thickness)
	make("UIStroke", "Stroke", parent, {
		Color = OUTLINE,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end
-- Every text keeps one of the frame's roles (design doc 4.42); OnLayout sizes them in units.
local roles = {}
local function role(object, name)
	roles[object] = name
	return object
end
-- color: the text colour on a burgundy card (Dojo.Text keeps it); none: ink on paper.
local function caption(name, parent, roleName, props, color)
	props.BackgroundTransparency = 1
	local label = role(make("TextLabel", name, parent, props), roleName)
	if color then
		label:SetAttribute("DojoTextColor", color)
	end
	return label
end
local function paid(frame)
	Dojo.Fill(frame, BURG_TOP, BURG_BOTTOM)
	Dojo.Rim(frame, PINK, 2)
	Dojo.Corner(frame, 6)
end
-- A pill: a solid fill, rounded ends, its text in `textColor`.
local function pill(label, fill, textColor)
	label.BackgroundTransparency = 0
	label.BackgroundColor3 = fill
	label:SetAttribute("DojoTextColor", textColor)
	label.TextColor3 = textColor
end
local function gradient(parent, a, b)
	make("UIGradient", "Gradient", parent, { Color = ColorSequence.new(a, b), Rotation = 90 })
end
-- Robux prices stay exact ("1,299"); HudFormat suffixes are for Money and Speed.
local function commas(n)
	local s = tostring(math.floor(n))
	repeat
		local count
		s, count = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return s
end
-- A section: its heading on its own 40-unit line (Section role, an optional caption on the right), then its cards.
local sections = {}
local function section(name, order, title, subtitle)
	local frame = make("Frame", name, nil, {
		LayoutOrder = order,
		BackgroundTransparency = 1,
	})
	make("UIListLayout", "Layout", frame, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	if title then
		local heading = caption("Title", frame, "Section", {
			LayoutOrder = 0,
			Text = title,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		if subtitle then
			caption("Subtitle", heading, "Caption", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromScale(0.6, 1),
				Text = subtitle,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
	end
	table.insert(sections, frame)
	return frame
end

local root = make("ScreenGui", "ShopUi", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 7,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local backdrop = make("Frame", "Backdrop", root, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = PALETTE.Scrim,
	BackgroundTransparency = 1, -- the world dim is HudChrome/PanelDim, below the HUD
	Visible = false,
})
PanelSwitch.Register("Shop", backdrop)
local panel = make("Frame", "Panel", backdrop, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 110),
	Size = UDim2.fromScale(0.78, 0.68),
	Active = true,
})
corner(panel, 16)
stroke(panel, 4)
-- The Index frame (through PanelFrame.Attach below) places and styles the title and the close.
local title = make("TextLabel", "Title", panel, { Text = "Shop", ZIndex = 3 })
local close = make("TextButton", "Close", panel, {
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(46, 46),
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
})
make("TextLabel", "X", close, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "X", ZIndex = 3 })

-- The one scrolling list, in the frame's content area; the bar sits inside it, beside the cards. OnLayout places its
-- sections (three columns, or stacked on a phone) and sets the canvas.
local list = make("ScrollingFrame", "Items", panel, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarImageColor3 = Dojo.Colors.Muted,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	ZIndex = 3,
})

-- A paid offer card (design doc 4.46): burgundy with a pink rim. Its Stroke stays for the cascade (Dojo.Rim disables it).
local function card(name, parent, props)
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	local frame = make("Frame", name, parent, props)
	corner(frame, 14)
	stroke(frame, 3)
	paid(frame)
	return frame
end

-- A card's name and description in cream and pale pink; layoutPass / layoutPack place them.
local function tileText(box, name, text)
	caption("Name", box, "Item", { Text = name, TextXAlignment = Enum.TextXAlignment.Left }, Dojo.Colors.Cream)
	caption("Description", box, "Caption", {
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, PINK_TEXT)
end
local function tileIcon(box, props)
	props.BackgroundTransparency = 1
	props.ScaleType = Enum.ScaleType.Fit
	return make("ImageLabel", "Icon", box, props)
end

-- ShopBought waits for the answer, never the prompt. A pass: Roblox's. A product: the server's grant, seen as its
-- Boost_ attributes rising (no remote reports a receipt). shortcut: another potion gain in the same GRANT_WAIT s after a
-- cancelled prompt also plays it (sound and a Pop only); upgrade if ShopService ever reports receipts.
local GRANT_WAIT = 120 -- placeholder
local passCards = {} -- GamepassId -> its card
local grantWaits = {} -- Boost_ attribute -> { Seen, Card, Until }
local function expectGrants(productId, boxOf)
	for _, product in config.Products do
		if product.ProductId == productId then
			for boost in product.Grants or {} do
				local attribute = "Boost_" .. boost
				grantWaits[attribute] =
					{ Seen = player:GetAttribute(attribute) or 0, Card = boxOf, Until = os.clock() + GRANT_WAIT }
			end
		end
	end
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, passId, purchased)
	if who == player and purchased and passCards[passId] then
		UiFeedback.Play("ShopBought", passCards[passId])
	end
end)
player.AttributeChanged:Connect(function(attribute)
	local pending = grantWaits[attribute]
	if pending and os.clock() < pending.Until and (player:GetAttribute(attribute) or 0) > pending.Seen then
		for name, other in grantWaits do
			if other.Card == pending.Card then
				grantWaits[name] = nil -- a bundle's other grants: one cue
			end
		end
		UiFeedback.Play("ShopBought", pending.Card)
	end
end)

local chrome -- PanelFrame's controller (below): its Frame is the Index frame
-- Greyed, disabled, the pill showing a word instead of Buy and no price: an owned pass, or paid luck for a restricted
-- player (design doc 6).
local function setBlocked(button, price, word)
	button.Active = word == nil
	button:FindFirstChild("Robux").Visible = word == nil
	price.Visible = word == nil
	local buyPill = button:FindFirstChild("Pill")
	buyPill.Text = word or "Buy"
	if word then
		pill(buyPill, OFF_FILL, OFF_TEXT)
	else
		pill(buyPill, Dojo.Colors.Cream, Dojo.Colors.Ink)
	end
	if chrome then
		chrome.Frame.Relayout() -- placeBuy sizes the pill by the blocked state
	end
end

-- The price button (kit.css .tag row): the Robux mark and the gold price, then a cream Buy pill, all one button (the UI
-- tests read the price on Buy). kind = "pass" | "product"; id 0 shows the price greyed and a "Coming soon" pill and
-- never prompts. `item` is the catalogue entry: it decides the blocked states. placeBuy lays it out.
local function buyButton(parent, kind, id, robuxPrice, item)
	local button = make("TextButton", "Buy", parent, {
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		-- Id 0 cannot be bought yet: greyed and disabled.
		Active = id > 0,
	})
	make("ImageLabel", "Robux", button, {
		BackgroundTransparency = 1,
		Image = ROBUX_ICON,
		ImageColor3 = id > 0 and GOLD or OFF_PRICE,
		ScaleType = Enum.ScaleType.Fit,
	})
	local price = caption("Price", button, "Body", {
		Text = commas(robuxPrice),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, id > 0 and GOLD or OFF_PRICE)
	local buyPill = caption("Pill", button, "Item", { Text = id > 0 and "Buy" or "Coming soon" })
	corner(buyPill, 10)
	if id <= 0 then
		buyPill.Name = "Soon"
		pill(buyPill, OFF_FILL, OFF_TEXT)
		UiFeedback.DeniedPress(button)
		return button
	end
	pill(buyPill, Dojo.Colors.Cream, Dojo.Colors.Ink)
	local listed = commas(robuxPrice)
	local function refreshBlocked()
		local owned = kind == "pass" and player:GetAttribute("Pass_" .. item.Id) == true
		local restricted = config.PaidLuck[item.Id] and player:GetAttribute("PaidRandomRestricted") ~= false
		setBlocked(button, price, owned and "OWNED" or restricted and "Not available" or nil)
		if not (owned or restricted) then
			price.Text = listed
		end
	end
	task.spawn(function()
		local infoType = kind == "pass" and Enum.InfoType.GamePass or Enum.InfoType.Product
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			listed = commas(info.PriceInRobux)
			refreshBlocked()
		end
	end)
	player:GetAttributeChangedSignal("PaidRandomRestricted"):Connect(refreshBlocked)
	if kind == "pass" then
		player:GetAttributeChangedSignal("Pass_" .. item.Id):Connect(refreshBlocked)
	end
	refreshBlocked()
	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		if kind == "pass" then
			passCards[id] = parent
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			expectGrants(id, parent)
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	return button
end

-- Odds are shown before purchase behind a word, never a bare icon (design doc 6). A small button in the card's
-- top-right corner, beside the name.
local function detailsButton(box)
	local b = make("TextButton", "Details", box, {
		BackgroundTransparency = 1,
		Text = "Details",
		ZIndex = 3,
	})
	Dojo.Rim(b, PINK, 1.5) -- kit.css .det: a pink outlined pill
	Dojo.Corner(b, 10)
	b:SetAttribute("DojoTextColor", PINK)
	role(b, "Item")
	b.Activated:Connect(require(script.Parent:WaitForChild("RollOptions")).OpenDetails)
	return b
end

-- 2. Gamepasses grid.
local passes = section("Gamepasses", 2, "Gamepasses", "Account-bound • no gifting")
passes.Parent = list
local grid = make("Frame", "Grid", passes, {
	LayoutOrder = 2,
	BackgroundTransparency = 1,
})
make("UIGridLayout", "Layout", grid, { SortOrder = Enum.SortOrder.LayoutOrder })
for order, item in config.Gamepasses do
	local box = card(item.Id, grid, { LayoutOrder = order })
	tileText(box, item.Name, item.Description)
	local icon = Icons[item.Icon] or Icons.Shop
	tileIcon(box, {
		Image = icon.Image,
		ImageRectOffset = icon.Offset or Vector2.zero,
		ImageRectSize = icon.Size or Vector2.zero,
	})
	buyButton(box, "pass", item.GamepassId, item.RobuxPrice, item)
	if config.PaidLuck[item.Id] or item.Id == "vip" then
		detailsButton(box)
	end
end

-- 3. Potions: packs and the bundle (developer products).
local first = Boosts.Get("LuckI")
local potions =
	section("Potions", 3, "Potions", string.format("(POTIONS LAST %d SECONDS EACH)", first and first.Duration or 60))
potions.Parent = list
local packRow = make("Frame", "Packs", potions, {
	LayoutOrder = 2,
	BackgroundTransparency = 1,
})
make("UIGridLayout", "Layout", packRow, { SortOrder = Enum.SortOrder.LayoutOrder })
local function grantCategory(grants)
	for id in grants do
		local boost = Boosts.Get(id)
		return boost and boost.Category or "Luck"
	end
	return "Luck"
end
for order, product in config.Products do
	if product.Section == "Potions" then
		local category = grantCategory(product.Grants)
		local box = card(product.Id, packRow, { LayoutOrder = order })
		tileText(box, product.Name, product.Description)
		tileIcon(box, { Image = PotionIcons[category] })
		buyButton(box, "product", product.ProductId, product.RobuxPrice, product)
		if config.PaidLuck[product.Id] then
			detailsButton(box)
		end
	end
end
-- The bundle card: name and description at the top (Details top-right), the bottles with the total, then Buy / Gift.
local bundleBanner
for _, product in config.Products do
	if product.Section == "Bundle" then
		local banner = card("Bundle", potions, { LayoutOrder = 3 })
		bundleBanner = banner
		caption("Name", banner, "Section", { Text = product.Name, TextXAlignment = Enum.TextXAlignment.Left }, GOLD)
		caption("Description", banner, "Caption", {
			Text = product.Description,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, PINK_TEXT)
		local bottles = make("Frame", "Contents", banner, { BackgroundTransparency = 1 })
		make("UIListLayout", "Layout", bottles, {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local total, perCategory = 0, {}
		for id, count in product.Grants do
			local boost = Boosts.Get(id)
			total += count
			if boost then
				perCategory[boost.Category] = (perCategory[boost.Category] or 0) + count
			end
		end
		for order, category in Boosts.Order do
			local bottle = make("ImageLabel", category, bottles, {
				LayoutOrder = order,
				BackgroundTransparency = 1,
				Image = PotionIcons[category],
				ScaleType = Enum.ScaleType.Fit,
			})
			caption("Count", bottle, "Item", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(1, 0.36),
				Text = "x" .. HudFormat.Short(perCategory[category] or 0),
			}, GOLD)
		end
		caption("Total", banner, "Body", {
			Text = "x" .. HudFormat.Short(total) .. " Potions!",
			TextXAlignment = Enum.TextXAlignment.Left,
		}, Dojo.Colors.Cream)
		buyButton(banner, "product", product.ProductId, product.RobuxPrice, product)
		detailsButton(banner)
	end
end

-- 4. DOUBLE Server Luck plate (display only until the Server Luck feature exists): the art on the left, the title and
-- its note, then the three tiers.
local luck = section("ServerLuck", 4, nil, nil)
luck.Parent = list
local luckBanner = card("Banner", luck, { LayoutOrder = 1 })
make("ImageLabel", "Art", luckBanner, {
	BackgroundTransparency = 1,
	Image = PotionIcons.Luck,
	ScaleType = Enum.ScaleType.Fit,
})
caption("Title", luckBanner, "Section", {
	Text = "DOUBLE Server Luck!",
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, GOLD)
caption("Note", luckBanner, "Caption", {
	Text = "Server-wide • no gifting",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, PINK_TEXT)
local tiers = make("Frame", "Tiers", luckBanner, { BackgroundTransparency = 1 })
make("UIGridLayout", "Layout", tiers, { SortOrder = Enum.SortOrder.LayoutOrder })
for order, product in config.Products do
	if product.Section == "ServerLuck" then
		local tier = make("Frame", product.Id, tiers, {
			LayoutOrder = order,
			BackgroundColor3 = TIER_FILL,
			BackgroundTransparency = 0.33,
		})
		Dojo.Rim(tier, PINK, 1.5).Transparency = 0.6
		Dojo.Corner(tier, 6)
		caption(
			"Name",
			tier,
			"Item",
			{ Text = product.Name, TextXAlignment = Enum.TextXAlignment.Left },
			Dojo.Colors.Cream
		)
		buyButton(tier, "product", product.ProductId, product.RobuxPrice, product)
	end
end

-- 5. Codes: the box and Redeem on one row; the hint and the reply on the footer plate.
local codes = section("Codes", 5, "Codes", nil)
codes.Parent = list
local codeBox = make("Frame", "Box", codes, { LayoutOrder = 2, BackgroundTransparency = 1 })
local input = make("TextBox", "Input", codeBox, {})
input.PlaceholderText = "Enter code here.."
input.PlaceholderColor3 = Dojo.Colors.Muted
input.Text = ""
input.ClearTextOnFocus = false
input.TextXAlignment = Enum.TextXAlignment.Left
role(input, "Body")
corner(input, 4)
stroke(input, 3)
Dojo.Fill(input, Dojo.Colors.Field) -- kit.css .field: a paper box with an ink rim
Dojo.Rim(input, Dojo.Colors.Ink, 2)
make("UIPadding", "Padding", input, {})
local redeem = make("TextButton", "Redeem", codeBox, {
	Text = "",
	BackgroundColor3 = Color3.new(1, 1, 1),
	AutoButtonColor = false,
})
corner(redeem, 8)
stroke(redeem, 3)
gradient(redeem, PALETTE.ShopSky, PALETTE.ShopRedeem)
AnimeSkin.Button(redeem, "Go")
caption("Label", redeem, "Item", { Size = UDim2.fromScale(1, 1), Text = "Redeem" })
-- Status keeps the server's reply (its path is the UI tests'); the footer plate shows it.
local status = caption("Status", codeBox, "Caption", { Text = "", Visible = false })
redeem.Activated:Connect(function()
	redeem.Active = false
	local ok, message = remotes:WaitForChild("RedeemCode"):InvokeServer(input.Text)
	status.Text = tostring(message or (ok and "Code redeemed!" or "Try again"))
	UiMotion.SlideIn(chrome.Frame.Footer(status.Text), Vector2.new(0, chrome.Frame.px(12))) -- the answer slides in (section 10)
	if ok then
		input.Text = ""
	else
		UiFeedback.Play("Denied", redeem)
	end
	redeem.Active = true
end)

-- 6. Thanks.
caption("Thanks", list, "Item", {
	LayoutOrder = 6,
	Text = "♥  Thanks for your support!  ♥",
}, Dojo.Colors.Verm)

-- The HudChrome Shop tile opens it (PanelSwitch.Toggle("Shop")).
local openGift = require(script.Parent:WaitForChild("GiftPicker")).Create(panel, list, backdrop)
-- Adds Gift beside the card's Buy and, when gifting is off, the reason caption (reason false: none). The card's
-- layout places them.
local function giftButton(box, product, reason)
	local enabled = product and (product.GiftProductId or 0) > 0 and (product.ProductId or 0) > 0
	if not box:FindFirstChild("Buy") then
		return
	end
	local gift = make("TextButton", "Gift", box, {
		Text = "Gift",
		Active = enabled == true,
		AutoButtonColor = enabled == true,
	})
	corner(gift, 10)
	-- kit.css .gift: a gold pill, greyed while gifting is off
	Dojo.Fill(gift, enabled and GOLD or OFF_FILL)
	gift:SetAttribute("DojoTextColor", enabled and Dojo.Colors.Ink or OFF_TEXT)
	role(gift, "Item")
	if not enabled then
		UiFeedback.DeniedPress(gift)
		if reason ~= false then
			caption("GiftReason", box, "Caption", {
				Text = reason or "Gift unavailable • coming soon",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				-- Design doc 4.46 (shop frame): a gamepass card has no room for it; the Gamepasses heading says it once.
				Visible = box.Parent ~= grid,
			}, PINK_TEXT)
		end
	end
	gift.Activated:Connect(function()
		if enabled then
			openGift(product)
		end
	end)
end
for _, pass in config.Gamepasses do
	giftButton(grid[pass.Id], nil, "Account-bound • no gifting")
end
for _, product in config.Products do
	if product.Section == "Potions" then
		giftButton(packRow[product.Id], product)
	elseif product.Section == "Bundle" then
		giftButton(potions.Bundle, product)
	elseif product.Section == "ServerLuck" then
		giftButton(tiers[product.Id], nil, false) -- the plate's Note says why
	end
end
close.Activated:Connect(function()
	PanelSwitch.Close("Shop")
end)
require(script.Parent:WaitForChild("PanelFrame")).CloseOnOutsideClick(backdrop, function()
	PanelSwitch.Close("Shop")
end)

local function place(object, position, size)
	object.AnchorPoint = Vector2.zero
	object.Position, object.Size = position, size
end
-- The Buy button's parts. Inline (kit.css .row): the Robux mark, the price, the pill at the right end. Stacked (a potion
-- pack): the mark and price on the top half, the pill under them.
local function placeBuy(g, buy, stacked)
	local P = g.px
	local price, mark = buy:FindFirstChild("Price"), buy:FindFirstChild("Robux")
	local buyPill = buy:FindFirstChild("Pill") or buy:FindFirstChild("Soon")
	local pillW = buyPill.Name == "Soon" and 84 or 44
	if not mark.Visible then
		-- Blocked (setBlocked hides the mark and price): the pill fills the button, so the hitbox is what it shows.
		place(buyPill, UDim2.new(), UDim2.fromScale(1, 1))
	elseif stacked then
		place(mark, UDim2.new(), UDim2.new(0, P(14), 0.5, -P(2)))
		place(price, UDim2.fromOffset(P(16), 0), UDim2.new(1, -P(16), 0.5, -P(2)))
		place(buyPill, UDim2.fromScale(0, 0.5), UDim2.fromScale(1, 0.5))
	else
		place(mark, UDim2.new(), UDim2.new(0, P(14), 1, 0))
		place(price, UDim2.fromOffset(P(16), 0), UDim2.new(1, -P(16 + 6 + pillW), 1, 0))
		place(buyPill, UDim2.new(1, -P(pillW), 0, 0), UDim2.new(0, P(pillW), 1, 0))
	end
end
-- A gamepass card (w units wide, PASS_H tall): the art on the left; the name (Details at its right), the description,
-- then the price, Buy and Gift.
local function layoutPass(g, box, w)
	local at = g.at
	local details = box:FindFirstChild("Details")
	place(box.Icon, at(6, 13), at(46, 46))
	place(box:FindFirstChild("Name"), at(58, 4), at(w - 64 - (details and DETAILS_W + 6 or 0), 24))
	if details then
		place(details, at(w - 6 - DETAILS_W, 6), at(DETAILS_W, 20))
	end
	place(box.Description, at(58, 28), at(w - 64, 16))
	place(box.Buy, at(58, 46), at(104, 22))
	placeBuy(g, box.Buy, false)
	if box:FindFirstChild("Gift") then
		place(box.Gift, at(168, 46), at(46, 22))
	end
end
-- A potion pack (w units wide, PACK_H tall): the game's potion art top-right, name, description, the gift reason, then
-- the price over Buy with Gift beside it and Details at the right.
local function layoutPack(g, box, w)
	local at = g.at
	place(box.Icon, at(w - 36, 6), at(30, 40))
	place(box:FindFirstChild("Name"), at(6, 4), at(w - 48, 34))
	box:FindFirstChild("Name").TextWrapped = true
	place(box.Description, at(6, 38), at(w - 12, 15))
	local reason = box:FindFirstChild("GiftReason")
	if reason then
		place(reason, at(6, 54), at(w - 12, 13))
	end
	place(box.Buy, at(6, 70), at(60, 44))
	placeBuy(g, box.Buy, true)
	if box:FindFirstChild("Gift") then
		place(box.Gift, at(72, 92), at(math.min(50, w - 78), 22))
	end
	local details = box:FindFirstChild("Details")
	if details then
		place(details, at(w - 6 - DETAILS_W, 70), at(DETAILS_W, 18))
	end
end
local function layoutBundle(g, banner, w)
	local at = g.at
	place(banner.Details, at(w - 8 - DETAILS_W, 8), at(DETAILS_W, 20))
	place(banner:FindFirstChild("Name"), at(10, 8), at(w - 26 - DETAILS_W, 24))
	place(banner.Description, at(10, 34), at(w - 20, 15))
	local reason = banner:FindFirstChild("GiftReason")
	if reason then
		place(reason, at(10, 50), at(w - 20, 13))
	end
	local bottles = banner.Contents
	place(bottles, at(10, 66), at(4 * 36, 40))
	bottles.Layout.Padding = UDim.new(0, g.px(4))
	for _, bottle in bottles:GetChildren() do
		if bottle:IsA("ImageLabel") then
			bottle.Size = at(32, 40)
		end
	end
	place(banner.Total, at(162, 66), at(w - 172, 40))
	place(banner.Buy, at(10, 110), at(104, 24))
	placeBuy(g, banner.Buy, false)
	place(banner.Gift, at(120, 110), at(50, 24))
end
-- The Server Luck card (w units wide, LUCK_H tall): the art, the title and its note, then the three tiers stacked.
local function layoutLuck(g, w)
	local at, P = g.at, g.px
	place(luckBanner.Art, at(8, 8), at(34, 44))
	place(luckBanner.Title, at(48, 6), at(w - 56, 40))
	place(luckBanner.Note, at(48, 46), at(w - 56, 14))
	place(tiers, at(8, 66), at(w - 16, 3 * 54 + 2 * 6))
	tiers.Layout.CellPadding = UDim2.fromOffset(0, P(6))
	tiers.Layout.CellSize = UDim2.new(1, 0, 0, P(54))
	for _, tier in tiers:GetChildren() do
		if tier:IsA("Frame") then
			place(tier:FindFirstChild("Name"), at(8, 4), UDim2.new(1, -P(16), 0, P(20)))
			place(tier.Buy, at(8, 28), UDim2.new(1, -P(16 + 52), 0, P(22)))
			placeBuy(g, tier.Buy, false)
			if tier:FindFirstChild("Gift") then
				place(tier.Gift, UDim2.new(1, -P(8 + 46), 0, P(28)), at(46, 22))
			end
		end
	end
end

-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6), in the Index frame.
chrome = require(script.Parent:WaitForChild("PanelFrame")).Attach(panel, {
	Theme = "Shop",
	Title = "Shop",
	Icon = Icons.Shop.Image,
	TitleObject = title,
	Close = close,
	MaxWidth = 900,
})
chrome.Frame.Footer(HINT)
chrome.Frame.OnLayout(function(g)
	local P, at, c = g.px, g.at, g.Content
	local listH = g.H - TOP - 82
	g.Place(list, c.X, TOP, c.W, listH)
	list.ScrollBarThickness = P(6)
	local width = c.W - 12 -- clear of the scroll bar
	-- Desktop: three columns. Phone: each section full width, stacked in spec order.
	local col1, col2 = 500, 288
	local col3 = width - 2 * 16 - col1 - col2
	-- Two pack columns on phones too: four left each pack too narrow for Buy and Details side by side.
	local passW, packCols = g.Small and width or col1, 2
	local potW, luckW = g.Small and width or col2, g.Small and width or col3
	local cellW = (passW - GAP) / 2
	local passRows = math.ceil(#config.Gamepasses / 2)
	local packRows = math.max(1, math.ceil((#packRow:GetChildren() - 1) / packCols)) -- less its UIGridLayout
	local packW = (potW - GAP * (packCols - 1)) / packCols
	local heights = {
		Gamepasses = HEAD_H + GAP + passRows * PASS_H + (passRows - 1) * GAP,
		Potions = HEAD_H + GAP + packRows * PACK_H + (packRows - 1) * GAP + (bundleBanner and GAP + BUNDLE_H or 0),
		ServerLuck = LUCK_H,
		Codes = CODES_H,
		Thanks = THANKS_H,
	}
	local widths = { Gamepasses = passW, Potions = potW, ServerLuck = luckW, Codes = luckW, Thanks = luckW }
	local spots = {
		Gamepasses = { 0, 0 },
		Potions = { col1 + 16, 0 },
		ServerLuck = { col1 + col2 + 32, 0 },
		Codes = { col1 + col2 + 32, LUCK_H + GAP },
		Thanks = { col1 + col2 + 32, LUCK_H + GAP + CODES_H + GAP },
	}
	local y, bottom = 0, 0
	for _, name in { "Gamepasses", "Potions", "ServerLuck", "Codes", "Thanks" } do
		local object = list:FindFirstChild(name)
		local x, top = spots[name][1], spots[name][2]
		if g.Small then
			x, top = 0, y
			y += heights[name] + 12
		end
		place(object, at(x, top), at(widths[name], heights[name]))
		bottom = math.max(bottom, top + heights[name])
	end
	list.CanvasSize = UDim2.fromOffset(0, P(bottom))
	for _, frame in sections do
		frame.Layout.Padding = UDim.new(0, P(GAP))
		local heading = frame:FindFirstChild("Title")
		if heading then
			heading.Size = UDim2.new(1, 0, 0, P(HEAD_H))
		end
	end
	grid.Size = at(passW, passRows * PASS_H + (passRows - 1) * GAP)
	grid.Layout.CellPadding = UDim2.fromOffset(P(GAP), P(GAP))
	grid.Layout.CellSize = UDim2.fromOffset(P(cellW), P(PASS_H))
	packRow.Size = at(potW, packRows * PACK_H + (packRows - 1) * GAP)
	packRow.Layout.CellPadding = UDim2.fromOffset(P(GAP), P(GAP))
	packRow.Layout.CellSize = UDim2.fromOffset(P(packW), P(PACK_H))
	for _, box in grid:GetChildren() do
		if box:IsA("Frame") then
			layoutPass(g, box, cellW)
		end
	end
	for _, box in packRow:GetChildren() do
		if box:IsA("Frame") then
			layoutPack(g, box, packW)
		end
	end
	if bundleBanner then
		bundleBanner.Size = at(potW, BUNDLE_H)
		layoutBundle(g, bundleBanner, potW)
	end
	luckBanner.Size = at(luckW, LUCK_H)
	layoutLuck(g, luckW)
	codeBox.Size = at(luckW, 36 + GAP + 40)
	place(input, UDim2.new(), UDim2.new(1, 0, 0, P(36)))
	input.Padding.PaddingLeft, input.Padding.PaddingRight = UDim.new(0, P(12)), UDim.new(0, P(12))
	place(redeem, UDim2.fromOffset(0, P(36 + GAP)), UDim2.new(1, 0, 0, P(40)))
	for object, name in roles do
		g.Role(object, name)
	end
end)

-- Section 10: on open, the first cards light up one after another (background and edge fade in). Grid and list
-- layouts own the card positions, so a slide would not show.
local cards = {}
for _, row in { grid, packRow } do
	local children = row:GetChildren()
	table.sort(children, function(a, b)
		return (a:IsA("GuiObject") and a.LayoutOrder or 0) < (b:IsA("GuiObject") and b.LayoutOrder or 0)
	end)
	for _, box in children do
		if box:IsA("Frame") and box:FindFirstChild("Stroke") and #cards < 12 then
			table.insert(cards, box)
		end
	end
end
backdrop:GetPropertyChangedSignal("Visible"):Connect(function()
	if not backdrop.Visible then
		return
	end
	UiMotion.Cascade(cards, "Stroke")
end)
UiTheme.Apply(root)
