--!nonstrict
-- UTC-day login rewards. The server owns claim timing.
-- No Money: Money comes only from race cash-outs and duplicate character sales (design doc, "Economy").

local DailyLoginConfig = {}

-- The guaranteed reward's top rarity by world; none in World 1 (proposed, no owner words on file; docs/OWNER_QUESTIONS.md).
-- Players progress past it.
DailyLoginConfig.MAX_GUARANTEED_RARITY = { [2] = "Legendary" }

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
