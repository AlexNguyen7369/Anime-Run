--!nonstrict
-- Sidekick catalog and summon costs (design doc 4.36, docs/SIDEKICK_SPEC.md). All numbers are placeholders.
-- Odds is a percent and the list sums to exactly 100. Cruise and Stamina are fractions of that character's own value.
local SidekickConfig = {}

SidekickConfig.SummonCost = 50
SidekickConfig.TenCost = 500
SidekickConfig.BagSize = 50
SidekickConfig.UnlockRebirth = 2
SidekickConfig.HitInterval = 1.5 -- seconds between a Sidekick's hits in a boss event (design doc 4.37)

SidekickConfig.List = {
	{
		Id = "side_chain",
		Name = "Pochito",
		Rarity = "Rare",
		Odds = 60,
		Movement = "Walk",
		Cruise = 0,
		Stamina = 0.12,
		Damage = 10,
		SellGems = 5,
	},
	{
		Id = "side_wyvern",
		Name = "Kaizel",
		Rarity = "Epic",
		Odds = 30,
		Movement = "Fly",
		Cruise = 0.08,
		Stamina = 0,
		Damage = 14,
		SellGems = 10,
	},
	{
		Id = "side_knight",
		Name = "Igriz",
		Rarity = "Legendary",
		Odds = 10,
		Movement = "Walk",
		Cruise = 0.03,
		Stamina = 0.03,
		Damage = 22,
		SellGems = 20,
	},
}

-- Boss drops only, never summoned (docs/SIDEKICK_SPEC.md). Summon rolls read List alone.
SidekickConfig.BossDrops = {
	{
		Id = "side_raga",
		Name = "Big Raga",
		Rarity = "Secret",
		Odds = 0.001,
		Movement = "Walk",
		Cruise = 0.1,
		Stamina = 0.1,
		Damage = 40,
		SellGems = 500,
	},
}

function SidekickConfig.Get(id)
	for _, list in { SidekickConfig.List, SidekickConfig.BossDrops } do
		for _, row in list do
			if row.Id == id then
				return row
			end
		end
	end
	return nil
end

-- One independent roll over `list`. Pure: reads only its arguments, so no luck source can reach it (design doc 4.36).
function SidekickConfig.Roll(rng, list)
	local total = 0
	for _, row in list do
		total += row.Odds
	end
	local pick = rng:NextNumber() * total
	for _, row in list do
		pick -= row.Odds
		if pick < 0 then
			return row
		end
	end
	return list[#list]
end

return SidekickConfig
