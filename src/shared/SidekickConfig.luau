--!nonstrict
-- Sidekick catalog and summon costs (design doc 4.36, docs/SIDEKICK_SPEC.md). All numbers are placeholders.
-- Odds is a percent and the list sums to 100, within float rounding. A summon uses the current rotation's odds, Server/SidekickRotation. Cruise and Stamina are fractions of that character's own value.
local SidekickConfig = {}

SidekickConfig.SummonCost = 50
SidekickConfig.TenCost = 500
SidekickConfig.BagSize = 50
SidekickConfig.UnlockRebirth = 2
SidekickConfig.PityCount = 300 -- the summon that reaches this without a Mythic gives the rotation's Mythic (design doc 4.36)
SidekickConfig.LegendaryPityCount = 100 -- the same for one of the rotation's Legendaries
SidekickConfig.HitInterval = 1.5 -- seconds between a Sidekick's hits in a boss event (design doc 4.37)

SidekickConfig.List = {
	{
		Id = "side_chain",
		Name = "Pochito",
		Rarity = "Common",
		Odds = 24.166,
		Movement = "Walk",
		Cruise = 0,
		Stamina = 0.05,
		Damage = 6,
		SellGems = 2,
	},
	{
		Id = "side_pig",
		Name = "Hawke",
		Rarity = "Common",
		Odds = 24.166,
		Movement = "Walk",
		Cruise = 0,
		Stamina = 0.05,
		Damage = 6,
		SellGems = 2,
	},
	{
		Id = "side_crow",
		Name = "Kasugay",
		Rarity = "Common",
		Odds = 24.166,
		Movement = "Fly",
		Cruise = 0,
		Stamina = 0.05,
		Damage = 6,
		SellGems = 2,
	},
	{
		Id = "side_dogs",
		Name = "Gyokan",
		Rarity = "Rare",
		Odds = 12,
		Movement = "Walk",
		Cruise = 0,
		Stamina = 0.12,
		Damage = 10,
		SellGems = 5,
	},
	{
		Id = "side_reindeer",
		Name = "Choppa",
		Rarity = "Rare",
		Odds = 12,
		Movement = "Walk",
		Cruise = 0,
		Stamina = 0.12,
		Damage = 10,
		SellGems = 5,
	},
	{
		Id = "side_ant",
		Name = "Beroo",
		Rarity = "Legendary",
		Odds = 1,
		Movement = "Walk",
		Cruise = 0.1,
		Stamina = 0.05,
		Damage = 22,
		SellGems = 20,
	},
	{
		Id = "side_reaper",
		Name = "Ryuuk",
		Rarity = "Legendary",
		Odds = 1,
		Movement = "Fly",
		Cruise = 0.1,
		Stamina = 0.05,
		Damage = 22,
		SellGems = 20,
	},
	{
		Id = "side_fist",
		Name = "Purple Platina",
		Rarity = "Mythic",
		Odds = 0.5,
		Movement = "Fly",
		Cruise = 0.15,
		Stamina = 0.1,
		Damage = 35,
		SellGems = 25,
	},
	{
		Id = "side_knight",
		Name = "Igriz",
		Rarity = "Mythic",
		Odds = 0.5,
		Movement = "Walk",
		Cruise = 0.15,
		Stamina = 0.1,
		Damage = 35,
		SellGems = 25,
	},
	{
		Id = "side_wyvern",
		Name = "Kaizel",
		Rarity = "Mythic",
		Odds = 0.5,
		Movement = "Fly",
		Cruise = 0.15,
		Stamina = 0.1,
		Damage = 35,
		SellGems = 25,
	},
	{
		Id = "side_curse",
		Name = "Rikka",
		Rarity = "Secret",
		Odds = 0.001,
		Movement = "Fly",
		Cruise = 0.2,
		Stamina = 0.2,
		Damage = 55,
		SellGems = 30,
	},
	{
		Id = "side_fox",
		Name = "Kurami",
		Rarity = "Secret",
		Odds = 0.001,
		Movement = "Walk",
		Cruise = 0.2,
		Stamina = 0.2,
		Damage = 55,
		SellGems = 30,
	},
}

-- Boss drops only, never summoned (docs/SIDEKICK_SPEC.md; design doc 4.36 "Boss Sidekicks"). Summon rolls read List alone.
-- Odds is the chest's separate roll, as a percent; the chest's own fraction is RelicConfig.Chests[*].SidekickChance.
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
		SellGems = 30,
	},
	{
		Id = "side_mage",
		Name = "The Elf Mage",
		Rarity = "Secret",
		Odds = 0.001,
		Movement = "Fly", -- hovers as her boss does
		Cruise = 0.1,
		Stamina = 0.1,
		Damage = 40,
		SellGems = 30,
	},
	{
		Id = "side_king",
		Name = "The Golden King",
		Rarity = "Secret",
		Odds = 0.001,
		Movement = "Walk",
		Cruise = 0.1,
		Stamina = 0.1,
		Damage = 40,
		SellGems = 30,
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
