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

local OUTLINE = UiTheme.Outline
local PALETTE = UiTheme.Palette
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"
local HINT = "Follow the socials on the game page for codes!"
-- Layout in the Index frame's design units (design doc 4.42, Client/AnimeSkin.IndexFrame); OnLayout below places all.
local CARD_H = 272 -- gamepass and potion cards: a card and its section heading fit the 374-unit content once
local BANNER_H = 120 -- bundle and Server Luck plates
local DETAILS_W = 96
local ROW_TOP = 12 + 22 + 12 + 44 -- a card's Buy / Gift row starts this far above its bottom

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
local function caption(name, parent, roleName, props)
	props.BackgroundTransparency = 1
	return role(make("TextLabel", name, parent, props), roleName)
end
local function gradient(parent, a, b)
	make("UIGradient", "Gradient", parent, { Color = ColorSequence.new(a, b), Rotation = 90 })
end
local function lighter(color, t)
	return color:Lerp(Color3.new(1, 1, 1), t)
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
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
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

-- The one scrolling list, in the frame's content area; the bar sits inside it, beside the cards.
local list = make("ScrollingFrame", "Items", panel, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarImageColor3 = PALETTE.Muted,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	ZIndex = 3,
})
make("UIListLayout", "Layout", list, { SortOrder = Enum.SortOrder.LayoutOrder })
make("UIPadding", "Padding", list, {})

-- A colour card: the anime card art (a wide banner: the slanted plate) tinted in its colour (design doc 4.42).
-- The fill, gradient and Stroke stay for the cascade; AnimeSkin hides them.
local function card(name, parent, color, props, plate)
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	local frame = make("Frame", name, parent, props)
	corner(frame, 14)
	stroke(frame, 3)
	gradient(frame, lighter(color, 0.55), color)
	if plate then
		AnimeSkin.Plate(frame, color)
	else
		AnimeSkin.Card(frame, color)
	end
	return frame
end

-- A tile card's name, description and art; layoutTile places them.
local tiles = {}
local function tileText(box, name, text)
	caption("Name", box, "Item", { Text = name, TextXAlignment = Enum.TextXAlignment.Left })
	caption("Description", box, "Caption", {
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	table.insert(tiles, box)
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

-- Grey, disabled, with a word instead of the price: an owned pass, or paid luck for a restricted player (design doc 6).
local function setBlocked(button, price, word)
	button.Active = word == nil
	button:FindFirstChild("Robux").Visible = word == nil
	if word then
		price.Text = word
		button.Gradient.Color = ColorSequence.new(PALETTE.Muted, PALETTE.Disabled)
	else
		button.Gradient.Color = ColorSequence.new(PALETTE.Money, PALETTE.MoneyDeep)
	end
	AnimeSkin.Button(button, word and "Idle" or "Go")
end

-- The green price button. kind = "pass" | "product"; id 0 shows "Coming soon" and never prompts. `item` is the catalogue
-- entry: it decides the blocked states. The card's layout places it.
local function buyButton(parent, kind, id, robuxPrice, item)
	local button = make("TextButton", "Buy", parent, {
		Text = "",
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		-- Id 0 cannot be bought yet: grey and disabled, so green always means a real price.
		Active = id > 0,
	})
	corner(button, 8)
	stroke(button, 3)
	if id > 0 then
		gradient(button, PALETTE.Money, PALETTE.MoneyDeep)
	else
		gradient(button, PALETTE.Muted, PALETTE.Disabled)
	end
	AnimeSkin.Button(button, id > 0 and "Go" or "Idle")
	make("ImageLabel", "Robux", button, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.1, id > 0 and 0.5 or 0.35),
		Size = UDim2.fromScale(0.22, 0.6),
		BackgroundTransparency = 1,
		Image = ROBUX_ICON,
		ImageColor3 = PALETTE.White,
		ScaleType = Enum.ScaleType.Fit,
	})
	-- Id 0: the price over a "Coming soon" caption line, both inside the button.
	local price = caption("Price", button, "Item", {
		Position = UDim2.fromScale(0.32, id > 0 and 0.15 or 0.04),
		Size = UDim2.fromScale(0.62, id > 0 and 0.7 or 0.5),
		Text = commas(robuxPrice),
	})
	if id <= 0 then
		caption("Soon", button, "Caption", {
			Position = UDim2.fromScale(0.05, 0.55),
			Size = UDim2.fromScale(0.9, 0.42),
			Text = "Coming soon",
		})
		UiFeedback.DeniedPress(button)
		return button
	end
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
		BackgroundColor3 = PALETTE.PanelDeep,
		Text = "Details",
		ZIndex = 3,
	})
	corner(b, 4)
	AnimeSkin.Button(b, "Idle")
	role(b, "Item")
	b.Activated:Connect(require(script.Parent:WaitForChild("RollOptions")).OpenDetails)
	return b
end

-- 2. Gamepasses grid.
local passes = section("Gamepasses", 2, "Gamepasses", nil)
passes.Parent = list
local grid = make("Frame", "Grid", passes, {
	LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIGridLayout", "Layout", grid, { SortOrder = Enum.SortOrder.LayoutOrder })
for order, item in config.Gamepasses do
	local box = card(item.Id, grid, item.Color or PALETTE.ShopSky, { LayoutOrder = order })
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
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIGridLayout", "Layout", packRow, { SortOrder = Enum.SortOrder.LayoutOrder })
local POTION_COLORS = {
	Luck = PALETTE.ShopMint,
	Money = PALETTE.ShopAmber,
	Speed = PALETTE.ShopSky,
	Stamina = PALETTE.ShopCobalt,
}
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
		local box = card(product.Id, packRow, POTION_COLORS[category], { LayoutOrder = order })
		tileText(box, product.Name, product.Description)
		tileIcon(box, { Image = PotionIcons[category] })
		buyButton(box, "product", product.ProductId, product.RobuxPrice, product)
		if config.PaidLuck[product.Id] then
			detailsButton(box)
		end
	end
end
-- The bundle plate: the bottles on the left; name, description and total in the middle; Details and Buy / Gift on
-- the right.
local bundleBanner
for _, product in config.Products do
	if product.Section == "Bundle" then
		local banner = card("Bundle", potions, PALETTE.ShopPink, { LayoutOrder = 3 }, true)
		bundleBanner = banner
		banner.Gradient.Rotation = 0
		banner.Gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, PALETTE.ShopSky),
			ColorSequenceKeypoint.new(0.5, PALETTE.ShopAmber),
			ColorSequenceKeypoint.new(1, PALETTE.ShopPink),
		})
		caption("Name", banner, "Item", { Text = product.Name, TextXAlignment = Enum.TextXAlignment.Left })
		caption("Description", banner, "Caption", {
			Text = product.Description,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
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
			})
		end
		caption("Total", banner, "Body", {
			Text = "x" .. HudFormat.Short(total) .. " Potions!",
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		buyButton(banner, "product", product.ProductId, product.RobuxPrice, product)
		detailsButton(banner)
	end
end

-- 4. DOUBLE Server Luck plate (display only until the Server Luck feature exists): the art on the left, the title and
-- its note, then the three tiers.
local luck = section("ServerLuck", 4, nil, nil)
luck.Parent = list
local luckBanner = card("Banner", luck, PALETTE.ShopLime, { LayoutOrder = 1 }, true)
make("ImageLabel", "Art", luckBanner, {
	BackgroundTransparency = 1,
	Image = PotionIcons.Luck,
	ScaleType = Enum.ScaleType.Fit,
})
caption("Title", luckBanner, "Section", {
	Text = "DOUBLE Server Luck!",
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
})
caption("Note", luckBanner, "Caption", {
	Text = "Server-wide • no gifting",
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
})
local tiers = make("Frame", "Tiers", luckBanner, { BackgroundTransparency = 1 })
make("UIGridLayout", "Layout", tiers, { SortOrder = Enum.SortOrder.LayoutOrder })
for order, product in config.Products do
	if product.Section == "ServerLuck" then
		local tier = make("Frame", product.Id, tiers, { LayoutOrder = order, BackgroundTransparency = 1 })
		caption("Name", tier, "Item", { Text = product.Name })
		buyButton(tier, "product", product.ProductId, product.RobuxPrice, product)
	end
end

-- 5. Codes: the box and Redeem on one row; the hint and the reply on the footer plate.
local codes = section("Codes", 5, "Codes", nil)
codes.Parent = list
local codeBox = make("Frame", "Box", codes, { LayoutOrder = 2, BackgroundTransparency = 1 })
local input = make("TextBox", "Input", codeBox, {})
input.BackgroundColor3 = PALETTE.ShopField
input.PlaceholderText = "Enter code here.."
input.PlaceholderColor3 = PALETTE.SoftText
input.Text = ""
input.ClearTextOnFocus = false
input.TextXAlignment = Enum.TextXAlignment.Left
role(input, "Body")
corner(input, 4)
stroke(input, 3)
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
local chrome -- PanelFrame's controller (below): its Frame is the Index frame
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
caption("Thanks", list, "Body", {
	LayoutOrder = 6,
	Text = "♥  Thanks for your support!  ♥",
})

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
		BackgroundColor3 = PALETTE.ShopGift,
		BackgroundTransparency = enabled and 0 or 0.45,
		Active = enabled == true,
		AutoButtonColor = enabled == true,
	})
	corner(gift, 4)
	stroke(gift, 3)
	AnimeSkin.Button(gift, enabled and "Gold" or "Idle")
	role(gift, "Item")
	if not enabled then
		UiFeedback.DeniedPress(gift)
		if reason ~= false then
			caption("GiftReason", box, "Caption", {
				Text = reason or "Gift unavailable • coming soon",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
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

-- Buy and Gift side by side, 8 apart, 44 tall, in the row at (x, y) of width w (UDims, px).
local function placePair(g, box, x, y, w)
	local buy, gift = box:FindFirstChild("Buy"), box:FindFirstChild("Gift")
	local half = UDim.new(w.Scale / 2, math.floor((w.Offset - g.px(8)) / 2))
	buy.AnchorPoint = Vector2.zero
	buy.Position, buy.Size = UDim2.new(x, y), UDim2.new(half, UDim.new(0, g.px(44)))
	if gift then
		gift.AnchorPoint = Vector2.zero
		gift.Position, gift.Size = UDim2.new(x + half + UDim.new(0, g.px(8)), y), buy.Size
	end
end
local function place(object, position, size)
	object.AnchorPoint = Vector2.zero
	object.Position, object.Size = position, size
end
-- A tile card, 12 padding: the name with Details at the top-right, the description, then the art filling everything
-- down to 8 above the Buy / Gift row, which ends 12 above the caption line, 12 above the bottom.
local function layoutTile(g, box)
	local P = g.px
	local details = box:FindFirstChild("Details")
	local reason = box:FindFirstChild("GiftReason")
	place(box:FindFirstChild("Name"), g.at(12, 12), UDim2.new(1, -P(details and 32 + DETAILS_W or 24), 0, P(34)))
	if details then
		place(details, UDim2.new(1, -P(12 + DETAILS_W), 0, P(12)), g.at(DETAILS_W, 32))
	end
	place(box:FindFirstChild("Description"), g.at(12, 54), UDim2.new(1, -P(24), 0, P(22)))
	local rowTop = reason and ROW_TOP or 12 + 44 -- no caption line: the row drops to 12 above the bottom
	place(box:FindFirstChild("Icon"), g.at(12, 84), UDim2.new(1, -P(24), 1, -P(84 + 8 + rowTop)))
	placePair(g, box, UDim.new(0, P(12)), UDim.new(1, -P(rowTop)), UDim.new(1, -P(24)))
	if reason then
		place(reason, UDim2.new(0, P(12), 1, -P(34)), UDim2.new(1, -P(24), 0, P(22)))
	end
end
-- A plate keeps everything 24 clear of its slanted ends.
local function layoutBundle(g, banner)
	local P = g.px
	local bottles = banner.Contents
	place(bottles, g.at(24, 12), UDim2.new(0.38, -P(24), 0, P(96)))
	bottles.Layout.Padding = UDim.new(0, P(8))
	for _, bottle in bottles:GetChildren() do
		if bottle:IsA("ImageLabel") then
			bottle.Size = UDim2.new(0.25, -P(6), 1, 0)
		end
	end
	-- The middle column: name, description, total.
	for name, row in { Name = { 12, 34 }, Description = { 54, 22 }, Total = { 80, 28 } } do
		place(banner:FindFirstChild(name), UDim2.new(0.38, P(12), 0, P(row[1])), UDim2.new(0.24, -P(24), 0, P(row[2])))
	end
	-- The right column: Details at the top, Buy / Gift 12 above the bottom.
	place(banner:FindFirstChild("Details"), UDim2.new(1, -P(24 + DETAILS_W), 0, P(12)), g.at(DETAILS_W, 32))
	placePair(g, banner, UDim.new(0.62, P(12)), UDim.new(1, -P(56)), UDim.new(0.38, -P(36)))
	local reason = banner:FindFirstChild("GiftReason")
	if reason then
		place(reason, UDim2.new(0.62, P(12), 0, P(17)), UDim2.new(0.38, -P(44 + DETAILS_W), 0, P(22)))
	end
end
local function layoutLuck(g)
	local P = g.px
	place(luckBanner.Art, g.at(24, 12), g.at(96, 96))
	place(luckBanner.Title, g.at(132, 12), UDim2.new(0.45, -P(144), 0, P(62)))
	place(luckBanner.Note, g.at(132, 86), UDim2.new(0.45, -P(144), 0, P(22)))
	place(tiers, UDim2.new(0.45, 0, 0, P(12)), UDim2.new(0.55, -P(24), 0, P(96)))
	tiers.Layout.CellPadding = UDim2.fromOffset(P(12), 0)
	tiers.Layout.CellSize = UDim2.new(1 / 3, -P(8), 1, 0)
	for _, tier in tiers:GetChildren() do
		if tier:IsA("Frame") then
			place(tier:FindFirstChild("Name"), UDim2.new(), UDim2.new(1, 0, 0, P(34)))
			placePair(g, tier, UDim.new(), UDim.new(1, -P(44)), UDim.new(1, 0))
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
	local P, c = g.px, g.Content
	g.Place(list, c.X, c.Y, c.W, c.H)
	list.ScrollBarThickness = P(6)
	list.Padding.PaddingRight = UDim.new(0, P(4))
	list.Layout.Padding = UDim.new(0, P(12))
	for _, frame in sections do
		frame.Layout.Padding = UDim.new(0, P(12))
		local heading = frame:FindFirstChild("Title")
		if heading then
			heading.Size = UDim2.new(1, 0, 0, P(40))
		end
	end
	-- Gamepasses 3 across, potion packs 4 (phones: 2 and 2).
	for row, columns in { [grid] = g.Small and 2 or 3, [packRow] = g.Small and 2 or 4 } do
		row.Layout.CellPadding = UDim2.fromOffset(P(12), P(12))
		row.Layout.CellSize = UDim2.new(1 / columns, -math.ceil(P(12) * (columns - 1) / columns), 0, P(CARD_H))
	end
	for _, box in tiles do
		layoutTile(g, box)
	end
	luckBanner.Size = UDim2.new(1, 0, 0, P(BANNER_H))
	layoutLuck(g)
	if bundleBanner then
		bundleBanner.Size = UDim2.new(1, 0, 0, P(BANNER_H))
		layoutBundle(g, bundleBanner)
	end
	codeBox.Size = UDim2.new(1, 0, 0, P(44))
	place(input, UDim2.new(), UDim2.new(1, -P(160 + 12), 1, 0))
	input.Padding.PaddingLeft, input.Padding.PaddingRight = UDim.new(0, P(12)), UDim.new(0, P(12))
	place(redeem, UDim2.new(1, -P(160), 0, 0), UDim2.new(0, P(160), 1, 0))
	list.Thanks.Size = UDim2.new(1, 0, 0, P(34))
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
