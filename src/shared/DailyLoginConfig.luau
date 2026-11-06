--!nonstrict
-- UTC-day login rewards. The server owns claim timing.
-- No Money: Money comes only from race cash-outs and duplicate car sales (design doc, "Economy").

local DailyLoginConfig = {}

-- The guaranteed reward's top rarity (owner 2026-11-05, design doc 4.39): players progress past it. Tunable.
DailyLoginConfig.MAX_GUARANTEED_RARITY = "Legendary"

DailyLoginConfig.Rewards = {
	{ Boost = "Luck" },
	{ Boost = "Money" },
	{ Boost = "Stamina" }, -- owner 2026-10-28: daily login gives Stamina potions (design doc 4.7)
	{ Boost = "Money" },
	{ Boost = "Speed" },
	{ Boost = "Luck", BoostCount = 2 },
	{ GuaranteedRare = true },
}

return DailyLoginConfig
