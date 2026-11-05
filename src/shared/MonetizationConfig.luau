--!nonstrict
-- Shop catalogue (docs/MONETIZATION_SPEC.md). The Creator Dashboard supplies the real
-- ids; zero keeps an entry visible as "Coming soon". RobuxPrice is the listed price (proposed) shown until Roblox
-- reports the live one. Title/Color/Icon are presentation only.
local MonetizationConfig = {}

-- Ids come from tools/monetization/create_products.py (ledger product_ids.json).
local PASS_IDS = {
	vip = 2072398327,
	auto_roll_2x = 2072460303,
	extra_roll_1 = 2071152820,
	extra_roll_2 = 2067428411,
	money_2x = 2071590457,
	luck_1 = 2071600457,
	luck_2 = 2071522505,
	dojo_master = 2071362782,
	deep_stamina = 2071540479,
	inventory = 2067308486,
	exclusive_runner = 2067692445,
}

local function pass(id, name, price, description, color, icon)
	return {
		Id = id,
		Name = name,
		GamepassId = PASS_IDS[id] or 0,
		RobuxPrice = price,
		Description = description,
		Color = color,
		Icon = icon,
	}
end
local GOLD = Color3.fromRGB(255, 196, 70)
local MINT = Color3.fromRGB(110, 230, 160)
local SKY = Color3.fromRGB(110, 205, 255)
local VIOLET = Color3.fromRGB(175, 120, 255)
local LIME = Color3.fromRGB(200, 240, 110)

MonetizationConfig.Gamepasses = {
	pass("vip", "VIP", 499, "VIP title, +10% Money and Luck!", GOLD, "Rebirth"),
	pass("auto_roll_2x", "2x Auto-Roll", 199, "Roll twice as fast!", MINT, "Index"),
	pass("extra_roll_1", "Extra Roll I", 299, "+1 auto-roll at once (2 total)!", SKY, "Index"),
	pass("extra_roll_2", "Extra Roll II", 599, "+1 more auto-roll (3 total)!", VIOLET, "Index"),
	pass("money_2x", "2x Money", 249, "Doubles race payouts!", GOLD, "Shop"),
	pass("luck_1", "Lucky", 149, "Permanent +1 Luck!", LIME, "Stats"),
	pass("luck_2", "ULTRA Lucky", 299, "Permanent +2 Luck!", VIOLET, "Stats"),
	pass("dojo_master", "Dojo Master", 299, "Workshop boost x1.5!", GOLD, "Upgrade"),
	pass("deep_stamina", "Deep Stamina", 199, "+25% stamina for your team!", SKY, "Stats"),
	pass("inventory", "+ Inventory", 199, "+100 bag spaces!", MINT, "Items"),
	pass("exclusive_runner", "Saitamo", 999, "Exclusive runner: 350 studs/s!", VIOLET, "Index"),
}

-- Items that change roll odds (design doc 6): restricted players can not buy them, and they show "Details".
MonetizationConfig.PaidLuck = { luck_1 = true, luck_2 = true, potion_luck_pack = true, potion_bundle = true }

-- Developer products. Grants are boost ids from Shared/BoostConfig; Server/ShopService grants them per receipt.
local bundle = {}
for _, category in { "Luck", "Money", "Speed", "Stamina" } do
	for _, roman in { "I", "II", "III" } do
		bundle[category .. roman] = 10
	end
end
MonetizationConfig.Products = {
	{
		Id = "potion_luck_pack",
		Name = "x5 Luck Potion III",
		Description = "x2 Luck",
		Section = "Potions",
		ProductId = 3728396283,
		RobuxPrice = 49,
		Grants = { LuckIII = 5 },
	},
	{
		Id = "potion_money_pack",
		Name = "x5 Money Potion III",
		Description = "x2 Money",
		Section = "Potions",
		ProductId = 3728396286,
		RobuxPrice = 49,
		Grants = { MoneyIII = 5 },
	},
	{
		Id = "potion_speed_pack",
		Name = "x5 Speed Potion III",
		Description = "x2 cruise speed",
		Section = "Potions",
		ProductId = 3728396289,
		RobuxPrice = 49,
		Grants = { SpeedIII = 5 },
	},
	{
		Id = "potion_stamina_pack",
		Name = "x5 Stamina Potion III",
		Description = "x2 stamina",
		Section = "Potions",
		ProductId = 3728396292,
		RobuxPrice = 49,
		Grants = { StaminaIII = 5 },
	},
	{
		Id = "potion_bundle",
		Name = "POTION BUNDLE!",
		Description = "x10 of EVERY potion",
		Section = "Bundle",
		ProductId = 3728396295,
		RobuxPrice = 999,
		Grants = bundle,
	},
	{
		Id = "server_luck_2x",
		Name = "2x Server Luck",
		Description = "Whole server, 15 min",
		Section = "ServerLuck",
		ProductId = 0,
		RobuxPrice = 199,
	},
	{
		Id = "server_luck_4x",
		Name = "4x Server Luck",
		Description = "Whole server, 15 min",
		Section = "ServerLuck",
		ProductId = 0,
		RobuxPrice = 399,
	},
	{
		Id = "server_luck_8x",
		Name = "8x Server Luck",
		Description = "Whole server, 15 min",
		Section = "ServerLuck",
		ProductId = 0,
		RobuxPrice = 799,
	},
}

-- Offline reward double (docs/OFFLINE_DOUBLE_SPEC.md). Not a Shop entry: it is sold only from the offline reward
-- panel. ProductId 0 = not on sale yet; set the real id: create a 19 R$ developer product on the Creator Dashboard
-- and paste its id here. RobuxPrice and WINDOW_SECONDS are placeholders.
MonetizationConfig.OfflineDouble = {
	Id = "offline_double",
	Name = "Double offline Speed",
	ProductId = 0,
	RobuxPrice = 19,
	WINDOW_SECONDS = 300,
}

-- Separate ids keep a delayed ordinary receipt from consuming a gift reservation.
-- Ids come from tools/monetization/create_products.py (ledger product_ids.json).
local GIFT_IDS = {
	potion_luck_pack = 3728396304,
	potion_money_pack = 3728396311,
	potion_speed_pack = 3728396315,
	potion_stamina_pack = 3728396319,
	potion_bundle = 3728396326,
}
for _, product in MonetizationConfig.Products do
	if product.Grants then
		product.GiftProductId = GIFT_IDS[product.Id] or 0
	end
end

return MonetizationConfig
