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
-- Spacing tokens (design doc 4.42, Client/AnimeSkin), in px for this screen.
local P = AnimeSkin.Px
local PAD, INNER, GAP = P(AnimeSkin.Space.Pad), P(AnimeSkin.Space.Inner), P(AnimeSkin.Space.Gap)
local BTN, SMALL = P(AnimeSkin.Space.Button), P(AnimeSkin.Space.ButtonSmall)
local CAP, BODY, ITEM, SECTION = P(13), P(20), P(24), P(32) -- row heights of the Caption, Body, Item, Section roles
local DETAILS_W = P(80)
local HINT = "Follow the socials on the game page for codes!"

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
-- A text in one of the five roles (design doc 4.42): Title, Section, Item, Body, Caption.
local function caption(name, parent, role, props)
	props.BackgroundTransparency = 1
	return AnimeSkin.Label(make("TextLabel", name, parent, props), role)
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
-- A section: its heading row (Section role, an optional caption on the right), then its cards 8 below.
local function section(name, order, title, subtitle)
	local frame = make("Frame", name, nil, {
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	})
	make("UIListLayout", "Layout", frame, {
		Padding = UDim.new(0, INNER),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	if title then
		local heading = caption("Title", frame, "Section", {
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, SECTION),
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
-- AnimeSkin.Header (through PanelFrame.Attach below) places and styles the title and the close.
local title = caption("Title", panel, "Title", { Text = "Shop", ZIndex = 3 })
local close = make("TextButton", "Close", panel, {
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(46, 46),
	Text = "",
	AutoButtonColor = false,
	ZIndex = 3,
})
make("TextLabel", "X", close, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "X", ZIndex = 3 })

local list = make("ScrollingFrame", "Items", panel, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarImageColor3 = PALETTE.Muted,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
AnimeSkin.Content(list, { Footer = true }) -- insets 16, under the header, above the codes footer
make("UIListLayout", "Layout", list, { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder })
-- The scrollbar keeps 8 px off the cards.
make("UIPadding", "Padding", list, { PaddingRight = UDim.new(0, INNER) })
-- The codes reply line (and the codes hint until a reply), in the footer bar.
local footer = AnimeSkin.Footer(panel, HINT)

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

-- A tile card's text and icon rows (12 padding, 8 between rows): name (beside Details, if any), description, then
-- the icon down to 8 above the Buy / Gift row that giftButton places.
local BOTTOM_ROWS = PAD + CAP + PAD + BTN -- caption 12 from the bottom, buttons 12 above it
local function tileText(box, name, text, details)
	caption("Name", box, "Item", {
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.new(1, -2 * PAD - (details and DETAILS_W + INNER or 0), 0, ITEM),
		Text = name,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	caption("Description", box, "Body", {
		Position = UDim2.fromOffset(PAD, PAD + ITEM + INNER),
		Size = UDim2.new(1, -2 * PAD, 0, BODY),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end
local ICON_TOP = PAD + ITEM + INNER + BODY + INNER
local function tileIcon(box, props)
	props.AnchorPoint = Vector2.new(0.5, 0)
	props.Position = UDim2.new(0.5, 0, 0, ICON_TOP)
	props.Size = UDim2.new(1, -2 * PAD, 1, -ICON_TOP - BOTTOM_ROWS - INNER)
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
-- entry: it decides the blocked states. giftButton places it.
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
	-- Id 0: the price over a "Coming soon" caption line, both inside the 40 px button.
	local price = caption("Price", button, "Item", {
		Position = id > 0 and UDim2.new(0.32, 0, 0, INNER) or UDim2.new(0.32, 0, 0, 2),
		Size = UDim2.new(0.62, 0, 0, id > 0 and BTN - 2 * INNER or BTN - CAP - 4),
		Text = commas(robuxPrice),
	})
	if id <= 0 then
		caption("Soon", button, "Caption", {
			Position = UDim2.new(0.05, 0, 1, -CAP - 2),
			Size = UDim2.new(0.9, 0, 0, CAP),
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
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD, 0, PAD),
		Size = UDim2.fromOffset(DETAILS_W, SMALL),
		BackgroundColor3 = PALETTE.PanelDeep,
		Text = "Details",
		TextColor3 = PALETTE.White,
		TextSize = P(AnimeSkin.Size.Body),
		ZIndex = 3,
	})
	corner(b, 4)
	AnimeSkin.Button(b, "Idle")
	b.Activated:Connect(require(script.Parent:WaitForChild("RollOptions")).OpenDetails)
	return b
end

-- 2. Gamepasses grid. Cell sizes: fitCells (below).
local passes = section("Gamepasses", 2, "Gamepasses", nil)
passes.Parent = list
local grid = make("Frame", "Grid", passes, {
	LayoutOrder = 2,
	Size = UDim2.fromScale(1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIGridLayout", "Layout", grid, {
	CellSize = UDim2.new(1 / 3, -8, 0, 214),
	CellPadding = UDim2.fromOffset(GAP, GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
for order, item in config.Gamepasses do
	local box = card(item.Id, grid, item.Color or PALETTE.ShopSky, { LayoutOrder = order })
	local details = config.PaidLuck[item.Id] or item.Id == "vip"
	tileText(box, item.Name, item.Description, details)
	local icon = Icons[item.Icon] or Icons.Shop
	tileIcon(box, {
		Image = icon.Image,
		ImageRectOffset = icon.Offset or Vector2.zero,
		ImageRectSize = icon.Size or Vector2.zero,
	})
	buyButton(box, "pass", item.GamepassId, item.RobuxPrice, item)
	if details then
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
make("UIGridLayout", "Layout", packRow, {
	CellSize = UDim2.new(0.25, -9, 0, 214),
	CellPadding = UDim2.fromOffset(GAP, GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
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
		local details = config.PaidLuck[product.Id]
		tileText(box, product.Name, product.Description, details)
		tileIcon(box, { Image = PotionIcons[category] })
		buyButton(box, "product", product.ProductId, product.RobuxPrice, product)
		if details then
			detailsButton(box)
		end
	end
end
-- The bundle banner: name, description and the bottles on the left; Details, total and Buy / Gift on the right.
local bundleBanner
for _, product in config.Products do
	if product.Section == "Bundle" then
		local banner = card("Bundle", potions, PALETTE.ShopPink, {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 214),
		}, true)
		bundleBanner = banner
		banner.Gradient.Rotation = 0
		banner.Gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, PALETTE.ShopSky),
			ColorSequenceKeypoint.new(0.5, PALETTE.ShopAmber),
			ColorSequenceKeypoint.new(1, PALETTE.ShopPink),
		})
		caption("Name", banner, "Item", {
			Position = UDim2.fromOffset(PAD, PAD),
			Size = UDim2.new(0.55, -PAD, 0, ITEM),
			Text = product.Name,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		caption("Description", banner, "Body", {
			Position = UDim2.fromOffset(PAD, PAD + ITEM + INNER),
			Size = UDim2.new(0.55, -PAD, 0, BODY),
			Text = product.Description,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local bottles = make("Frame", "Contents", banner, {
			Position = UDim2.fromOffset(PAD, ICON_TOP),
			Size = UDim2.new(0.55, -PAD, 1, -ICON_TOP - PAD),
			BackgroundTransparency = 1,
		})
		make("UIListLayout", "Layout", bottles, {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, INNER),
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
				Size = UDim2.new(0.25, -INNER, 1, 0),
				BackgroundTransparency = 1,
				Image = PotionIcons[category],
				ScaleType = Enum.ScaleType.Fit,
			})
			caption("Count", bottle, "Item", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, ITEM),
				Text = "x" .. HudFormat.Short(perCategory[category] or 0),
			})
		end
		caption("Total", banner, "Item", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -PAD, 0, PAD + SMALL + INNER),
			Size = UDim2.new(0.4, -PAD, 0, ITEM),
			Text = "x" .. HudFormat.Short(total) .. " Potions!",
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		buyButton(banner, "product", product.ProductId, product.RobuxPrice, product)
		detailsButton(banner)
	end
end

-- 4. DOUBLE Server Luck banner (display only until the Server Luck feature exists).
local luck = section("ServerLuck", 4, nil, nil)
luck.Parent = list
local luckBanner = card("Banner", luck, PALETTE.ShopLime, {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 214),
}, true)
caption("Title", luckBanner, "Section", {
	Position = UDim2.fromOffset(PAD, PAD),
	Size = UDim2.new(1, -2 * PAD, 0, SECTION),
	Text = "DOUBLE Server Luck!",
})
local TIERS_TOP = PAD + SECTION + INNER
local tiers = make("Frame", "Tiers", luckBanner, {
	Position = UDim2.fromOffset(PAD, TIERS_TOP),
	Size = UDim2.new(1, -2 * PAD, 1, -TIERS_TOP - PAD),
	BackgroundTransparency = 1,
})
make("UIGridLayout", "Layout", tiers, {
	CellSize = UDim2.new(1 / 3, -8, 1, 0),
	CellPadding = UDim2.fromOffset(GAP, 0),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
for order, product in config.Products do
	if product.Section == "ServerLuck" then
		local tier = make("Frame", product.Id, tiers, { LayoutOrder = order, BackgroundTransparency = 1 })
		caption("Name", tier, "Item", { Size = UDim2.new(1, 0, 0, ITEM), Text = product.Name })
		buyButton(tier, "product", product.ProductId, product.RobuxPrice, product)
	end
end

-- 5. Codes: the box, then the reply in the footer bar.
local codes = section("Codes", 5, "Codes", nil)
codes.Parent = list
local codeBox = card("Box", codes, PALETTE.ShopIce, {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, PAD + BTN + PAD + BTN + PAD),
})
local input = make("TextBox", "Input", codeBox, {})
input.AnchorPoint = Vector2.new(0.5, 0)
input.Position = UDim2.new(0.5, 0, 0, PAD)
input.Size = UDim2.new(0.5, 0, 0, BTN)
input.BackgroundColor3 = PALETTE.ShopField
input.PlaceholderText = "Enter code here.."
input.PlaceholderColor3 = PALETTE.SoftText
input.Text = ""
input.ClearTextOnFocus = false
input.Font = UiTheme.Font
input.TextSize = P(AnimeSkin.Size.Body)
input.TextColor3 = Color3.new(1, 1, 1)
corner(input, 4)
stroke(input, 3)
local redeem = make("TextButton", "Redeem", codeBox, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, PAD + BTN + PAD),
	Size = UDim2.fromOffset(P(160), BTN),
	Text = "",
	BackgroundColor3 = Color3.new(1, 1, 1),
	AutoButtonColor = false,
})
corner(redeem, 8)
stroke(redeem, 3)
gradient(redeem, PALETTE.ShopSky, PALETTE.ShopRedeem)
AnimeSkin.Button(redeem, "Go")
caption("Label", redeem, "Item", { Size = UDim2.fromScale(1, 1), Text = "Redeem" })
-- Status keeps the server's reply (its path is the UI tests'); the footer bar shows it.
local status = make("TextLabel", "Status", codeBox, { BackgroundTransparency = 1, Text = "", Visible = false })
redeem.Activated:Connect(function()
	redeem.Active = false
	local ok, message = remotes:WaitForChild("RedeemCode"):InvokeServer(input.Text)
	status.Text = tostring(message or (ok and "Code redeemed!" or "Try again"))
	footer.Text = status.Text
	footer.TextColor3 = ok and PALETTE.Money or PALETTE.Reject -- bright: readable on the footer plate
	footer.Position = UDim2.new()
	UiMotion.SlideIn(footer, Vector2.new(0, 12)) -- the answer slides in from the bottom edge (section 10)
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
	Size = UDim2.new(1, 0, 0, ITEM),
	Text = "♥  Thanks for your support!  ♥",
})

-- The HudChrome Shop tile opens it (PanelSwitch.Toggle("Shop")).
local openGift = require(script.Parent:WaitForChild("GiftPicker")).Create(panel, list, backdrop)
-- Places the card's Buy and adds Gift beside it (8 apart), 12 above the reason caption, which sits 12 above the bottom.
-- pad: the card padding (0 in a Server Luck tier, which sits inside its banner's padding). left: where the pair starts.
local function giftButton(box, product, reason, pad, left)
	local enabled = product and (product.GiftProductId or 0) > 0 and (product.ProductId or 0) > 0
	local buy = box:FindFirstChild("Buy")
	if not buy then
		return
	end
	pad, left = pad or PAD, left or 0
	local rowBottom = -(pad + CAP + PAD)
	local width = UDim2.new((1 - left) / 2, -(pad + INNER) / 2 - (left > 0 and 0 or pad / 2), 0, BTN)
	buy.AnchorPoint = Vector2.new(0, 1)
	buy.Position = UDim2.new(left, left > 0 and 0 or pad, 1, rowBottom)
	buy.Size = width
	local gift = make("TextButton", "Gift", box, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -pad, 1, rowBottom),
		Size = width,
		Text = "Gift",
		TextSize = P(AnimeSkin.Size.Item),
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = PALETTE.ShopGift,
		BackgroundTransparency = enabled and 0 or 0.45,
		Active = enabled == true,
		AutoButtonColor = enabled == true,
	})
	corner(gift, 4)
	stroke(gift, 3)
	AnimeSkin.Button(gift, enabled and "Gold" or "Idle")
	if not enabled then
		UiFeedback.DeniedPress(gift)
		caption("GiftReason", box, "Caption", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(left, left > 0 and 0 or pad, 1, -pad),
			Size = UDim2.new(1 - left, -pad - (left > 0 and 0 or pad), 0, CAP),
			Text = reason or "Gift unavailable • coming soon",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
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
		giftButton(potions.Bundle, product, nil, PAD, 0.6)
	elseif product.Section == "ServerLuck" then
		giftButton(tiers[product.Id], nil, "Server-wide • no gifting", 0)
	end
end
close.Activated:Connect(function()
	PanelSwitch.Close("Shop")
end)
require(script.Parent:WaitForChild("PanelFrame")).CloseOnOutsideClick(backdrop, function()
	PanelSwitch.Close("Shop")
end)

-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6).
require(script.Parent:WaitForChild("PanelFrame")).Attach(panel, {
	Theme = "Shop",
	Title = "Shop",
	Icon = Icons.Shop.Image,
	TitleObject = title,
	Close = close,
	MaxWidth = 900,
})
-- One card row is as tall as the list's window, so a card scrolled to the top is never cut at the frame.
local function fitCells()
	local columns = panel.AbsoluteSize.X < 560 and 2 or 3
	local packs = columns == 3 and 4 or 2 -- 4 potion packs: one row of 4 or 2 x 2
	-- The window minus the section's heading row above the cards.
	local height = math.clamp(math.floor(list.AbsoluteSize.Y) - SECTION - INNER, P(160), P(260))
	grid.Layout.CellSize = UDim2.new(1 / columns, -GAP * (columns - 1) / columns, 0, height)
	packRow.Layout.CellSize = UDim2.new(1 / packs, -GAP * (packs - 1) / packs, 0, height)
	luckBanner.Size = UDim2.new(1, 0, 0, height)
	if bundleBanner then
		bundleBanner.Size = UDim2.new(1, 0, 0, height)
	end
end
panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCells)
list:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCells)
fitCells()

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
