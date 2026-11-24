--!nonstrict
-- Sidekick catalog and summon costs (design doc 4.36, docs/SIDEKICK_SPEC.md). All numbers are placeholders.
-- Odds is a percent and the list sums to 100, within float rounding. A summon uses the current rotation's odds, Server/SidekickRotation. Cruise and Stamina are fractions of that character's own value.
local WorldConfig = require(script.Parent.WorldConfig)

local SidekickConfig = {}
-- The Mythic of every slot, by world (design doc 4.47: each world has its own set and rotation)
SidekickConfig.FeaturedMythics = { [1] = "side_knight", [2] = "side_general" }
SidekickConfig.FeaturedMythic = SidekickConfig.FeaturedMythics[WorldConfig.Id]

SidekickConfig.SummonCost = 50
SidekickConfig.TenCost = 500
SidekickConfig.BagSize = 50
SidekickConfig.UnlockRebirth = 2
SidekickConfig.HudFromRebirth = 1 -- Summon, Bosses, the plaza sign and the Bag tabs show from here (owner 2026-11-20, design doc 4.36)
SidekickConfig.PityCount = 300 -- the summon that reaches this without a Mythic gives the rotation's Mythic (design doc 4.36)
SidekickConfig.LegendaryPityCount = 100 -- the same for one of the rotation's Legendaries
SidekickConfig.HitInterval = 1.5 -- seconds between a Sidekick's hits in a boss event (design doc 4.37)

-- Each world's summon set. Every world's rows keep working in both worlds (Get); only summons and the Index are per world.
-- World 2's numbers are World 1's row of the same rarity (docs/SIDEKICK_SPEC.md "World 2 set", proposed).
SidekickConfig.Lists = {
	[1] = {
		{
			Id = "side_chain",
			Name = "Pochito",
			World = 1,
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
			World = 1,
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
			World = 1,
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
			World = 1,
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
			World = 1,
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
			World = 1,
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
			World = 1,
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
			World = 1,
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
			World = 1,
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
			World = 1,
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
			World = 1,
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
			World = 1,
			Rarity = "Secret",
			Odds = 0.001,
			Movement = "Walk",
			Cruise = 0.2,
			Stamina = 0.2,
			Damage = 55,
			SellGems = 30,
		},
	},
	[2] = {
		{
			Id = "side_box",
			Name = "Mimik",
			World = 2,
			Rarity = "Common",
			Odds = 24.166,
			Movement = "Walk",
			Cruise = 0,
			Stamina = 0.05,
			Damage = 6,
			SellGems = 2,
		},
		{
			Id = "side_cat",
			Name = "Meowee",
			World = 2,
			Rarity = "Common",
			Odds = 24.166,
			Movement = "Walk",
			Cruise = 0,
			Stamina = 0.05,
			Damage = 6,
			SellGems = 2,
		},
		{
			Id = "side_lucky",
			Name = "Turbo Nyan",
			World = 2,
			Rarity = "Common",
			Odds = 24.166,
			Movement = "Walk",
			Cruise = 0,
			Stamina = 0.05,
			Damage = 6,
			SellGems = 2,
		},
		{
			Id = "side_tiger",
			Name = "Bakku",
			World = 2,
			Rarity = "Rare",
			Odds = 12,
			Movement = "Walk",
			Cruise = 0,
			Stamina = 0.12,
			Damage = 10,
			SellGems = 5,
		},
		{
			Id = "side_bird",
			Name = "Stilla",
			World = 2,
			Rarity = "Rare",
			Odds = 12,
			Movement = "Fly",
			Cruise = 0,
			Stamina = 0.12,
			Damage = 10,
			SellGems = 5,
		},
		{
			Id = "side_hound",
			Name = "Rovar",
			World = 2,
			Rarity = "Legendary",
			Odds = 1,
			Movement = "Walk",
			Cruise = 0.1,
			Stamina = 0.05,
			Damage = 22,
			SellGems = 20,
		},
		{
			Id = "side_shaman",
			Name = "Toskar",
			World = 2,
			Rarity = "Legendary",
			Odds = 1,
			Movement = "Walk",
			Cruise = 0.1,
			Stamina = 0.05,
			Damage = 22,
			SellGems = 20,
		},
		{
			Id = "side_acrobat",
			Name = "Acro Silka",
			World = 2,
			Rarity = "Mythic",
			Odds = 0.5,
			Movement = "Walk",
			Cruise = 0.15,
			Stamina = 0.1,
			Damage = 35,
			SellGems = 25,
		},
		{
			Id = "side_brawler",
			Name = "Kaijo No. 10",
			World = 2,
			Rarity = "Mythic",
			Odds = 0.5,
			Movement = "Walk",
			Cruise = 0.15,
			Stamina = 0.1,
			Damage = 35,
			SellGems = 25,
		},
		{
			Id = "side_general",
			Name = "Belleon",
			World = 2,
			Rarity = "Mythic",
			Odds = 0.5,
			Movement = "Walk",
			Cruise = 0.15,
			Stamina = 0.1,
			Damage = 35,
			SellGems = 25,
		},
		{
			Id = "side_dragon",
			Name = "Solara Dragon",
			World = 2,
			Rarity = "Secret",
			Odds = 0.001,
			Movement = "Fly",
			Cruise = 0.2,
			Stamina = 0.2,
			Damage = 55,
			SellGems = 30,
		},
		{
			Id = "side_dark",
			Name = "Darknez Devill",
			World = 2,
			Rarity = "Secret",
			Odds = 0.001,
			Movement = "Fly",
			Cruise = 0.2,
			Stamina = 0.2,
			Damage = 55,
			SellGems = 30,
		},
	},
}
SidekickConfig.List = SidekickConfig.Lists[WorldConfig.Id] -- this place's set

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
	for _, list in { SidekickConfig.Lists[1], SidekickConfig.Lists[2], SidekickConfig.BossDrops } do
		for _, row in list do
			if row.Id == id then
				return row
			end
		end
	end
	return nil
end

-- The tier the next summon is guaranteed, or nil: the server rolls it and Details shows it (design doc 4.36, section 6).
-- `rows` = { { Rarity } } on offer; a tier with none cannot be paid, so its count waits.
function SidekickConfig.DueTier(mythicPity, legendaryPity, rows)
	local has = {}
	for _, row in rows do
		has[row.Rarity] = true
	end
	return mythicPity + 1 >= SidekickConfig.PityCount and has.Mythic and "Mythic"
		or legendaryPity + 1 >= SidekickConfig.LegendaryPityCount and has.Legendary and "Legendary"
		or nil
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
