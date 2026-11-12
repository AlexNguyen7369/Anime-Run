--!nonstrict
-- Relics (design doc 4.38, docs/RELIC_SPEC.md). Stat counts, the priority and each chest's SidekickChance are owner values;
-- names, odds and bonuses are placeholders. Odds is a percent and each boss's list sums to exactly 100; a bonus 0.15 is +15%.
local BossMageArt = require(script.Parent.BossMageArt)

local RelicConfig = {}

RelicConfig.WheelArt = "rbxassetid://126470652353383" -- assets/ui/raga_wheel.png, also on the Dodge bar (design doc 4.37)

-- The one universal Secret: every boss's list ends with this same row (design doc 4.38).
local WORLD_CORE = {
	Id = "relic_world_core",
	Name = "World Core",
	Image = "rbxassetid://90225252879253", -- assets/ui/relic_world_core.png
	Rarity = "Secret",
	Odds = 0.1,
	Bonuses = { Damage = 0.15, AttackSpeed = 0.15, Luck = 0.15, Money = 0.15, Speed = 0.15, Stamina = 0.15 },
}

RelicConfig.Bosses = {
	big_raga = {
		{
			Id = "relic_talisman",
			Name = "Cursed Talisman",
			Image = "rbxassetid://112073311599626", -- assets/ui/relic_talisman.png
			Rarity = "Common",
			Odds = 55,
			Bonuses = { Stamina = 0.03 },
		},
		{
			Id = "relic_nail",
			Name = "Nobora's Nail",
			Image = "rbxassetid://116058098442275", -- assets/ui/relic_nail.png
			Rarity = "Rare",
			Odds = 28,
			Bonuses = { Damage = 0.06 },
		},
		{
			Id = "relic_cube", -- saved id kept from the Sealing Cube, so saved bags lose nothing (RELIC_SPEC)
			Name = "Raga's Wheel",
			Image = RelicConfig.WheelArt,
			Rarity = "Epic",
			Odds = 12,
			Bonuses = { Stamina = 0.1, Damage = 0.1 },
		},
		{
			Id = "relic_finger",
			Name = "Sukana's Finger",
			Image = "rbxassetid://104879331110597", -- assets/ui/relic_finger.png
			Rarity = "Legendary",
			Odds = 4,
			Bonuses = { Stamina = 0.15, Damage = 0.15, AttackSpeed = 0.04 },
		},
		{
			Id = "relic_eyes",
			Name = "Gojio's Sixfold Eyes",
			Image = "rbxassetid://109441811086116", -- assets/ui/relic_eyes.png
			Rarity = "Mythic",
			Odds = 0.9,
			Bonuses = { Stamina = 0.22, Damage = 0.22, AttackSpeed = 0.06, Luck = 0.06 },
		},
		WORLD_CORE,
	},
	-- Owner 2026-11-11: names and art approved; odds and bonuses placeholder.
	boss_mage = {
		{
			Id = "relic_helmet",
			Name = "Dwarf's Helmet",
			Image = "rbxassetid://125164800672073", -- assets/ui/relic_helmet.png
			Rarity = "Common",
			Odds = 55,
			Bonuses = { AttackSpeed = 0.03 },
		},
		{
			Id = "relic_bracelet",
			Name = "Hero's Bracelet",
			Image = "rbxassetid://97483480150926", -- assets/ui/relic_bracelet.png
			Rarity = "Rare",
			Odds = 28,
			Bonuses = { Luck = 0.06 },
		},
		{
			Id = "relic_staff",
			Name = "Elf Staff",
			Image = BossMageArt.StaffIcon, -- the Dodge bar's staff art (RELIC_SPEC)
			Rarity = "Epic",
			Odds = 12,
			Bonuses = { AttackSpeed = 0.1, Luck = 0.1 },
		},
		{
			Id = "relic_flask",
			Name = "Priest's Flask",
			Image = "rbxassetid://79563216957049", -- assets/ui/relic_flask.png
			Rarity = "Legendary",
			Odds = 4,
			Bonuses = { AttackSpeed = 0.15, Luck = 0.15, Damage = 0.04 },
		},
		{
			Id = "relic_grimoire",
			Name = "Master's Grimoire",
			Image = "rbxassetid://87657515215586", -- assets/ui/relic_grimoire.png
			Rarity = "Mythic",
			Odds = 0.9,
			Bonuses = { AttackSpeed = 0.22, Luck = 0.22, Damage = 0.06, Money = 0.06 },
		},
		WORLD_CORE,
	},
	-- Owner 2026-11-11: names and the damage / money priority; odds and bonuses placeholder as Big Raga's. Art waits for the owner.
	boss_king = {
		{
			Id = "relic_coin",
			Name = "Gold Coin",
			Image = "rbxassetid://135239262918195",
			Rarity = "Common",
			Odds = 55,
			Bonuses = { Damage = 0.03 },
		},
		{
			Id = "relic_goblet",
			Name = "Royal Goblet",
			Image = "rbxassetid://127993300718190",
			Rarity = "Rare",
			Odds = 28,
			Bonuses = { Money = 0.06 },
		},
		{
			Id = "relic_chain",
			Name = "Chain of Heaven",
			Image = "rbxassetid://133136348725864",
			Rarity = "Epic",
			Odds = 12,
			Bonuses = { Damage = 0.1, Money = 0.1 },
		},
		{
			Id = "relic_armor",
			Name = "Golden Armor",
			Image = "rbxassetid://108222955394755",
			Rarity = "Legendary",
			Odds = 4,
			Bonuses = { Damage = 0.15, Money = 0.15, AttackSpeed = 0.04 },
		},
		{
			Id = "relic_key",
			Name = "Key of Babylon", -- the Dodge bar's key art (RELIC_SPEC)
			Image = "rbxassetid://117675496916992",
			Rarity = "Mythic",
			Odds = 0.9,
			Bonuses = { Damage = 0.22, Money = 0.22, AttackSpeed = 0.06, Luck = 0.06 },
		},
		WORLD_CORE,
	},
}
RelicConfig.Order = { "big_raga", "boss_mage", "boss_king" } -- a stable walk of Bosses; World Core sits on each list

local byId = {}
for _, list in RelicConfig.Bosses do
	for _, row in list do
		byId[row.Id] = row
	end
end

function RelicConfig.Get(id)
	return byId[id]
end

-- What a Details sheet shows (section 6): every outcome of `boss`, {} for an unknown boss.
function RelicConfig.Odds(boss)
	local shown = {}
	for i, row in RelicConfig.Bosses[boss] or {} do
		shown[i] = { Id = row.Id, Name = row.Name, Rarity = row.Rarity, Odds = row.Odds }
	end
	return shown
end

-- Sealed spins saved as rows of the bag (RELIC_SPEC "Chests"), apart from Bosses. SidekickId / SidekickChance: the chest's own
-- boss's Sidekick and its separate roll, as a fraction (owner 2026-11-11: 0.001%, Adapted Raga's 0.01%).
local ADAPTED_ODDS = { Common = 38.5, Rare = 30, Epic = 20, Legendary = 8, Mythic = 3, Secret = 0.5 }
local adaptedTable = RelicConfig.Odds("big_raga")
for _, row in adaptedTable do
	row.Odds = ADAPTED_ODDS[row.Rarity]
end

RelicConfig.Chests = {
	relic_chest_raga = {
		Id = "relic_chest_raga",
		Name = "Raga's Treasure",
		Image = "rbxassetid://129792034295199", -- assets/ui/chest_raga.png
		Chest = true,
		Bonuses = {},
		Boss = "big_raga",
		SidekickId = "side_raga",
		SidekickChance = 0.00001,
		Table = RelicConfig.Odds("big_raga"),
	},
	relic_chest_adapted = {
		Id = "relic_chest_adapted",
		Name = "Adapted Raga's Treasure",
		Image = "rbxassetid://81070324097920", -- assets/ui/chest_adapted.png
		Chest = true,
		Bonuses = {},
		Boss = "big_raga",
		SidekickId = "side_raga",
		SidekickChance = 0.0001, -- owner 2026-11-06: 0.01%
		Table = adaptedTable,
	},
	relic_chest_mage = {
		Id = "relic_chest_mage",
		Name = "Elf Mage's Treasure",
		Image = "rbxassetid://118852320501133", -- assets/ui/chest_mage.png
		Chest = true,
		Bonuses = {},
		Boss = "boss_mage",
		SidekickId = "side_mage",
		SidekickChance = 0.00001,
		Table = RelicConfig.Odds("boss_mage"),
	},
	relic_chest_king = {
		Id = "relic_chest_king",
		Name = "Golden King's Treasure", -- proposed
		Image = "rbxassetid://123537148348616",
		Chest = true,
		Bonuses = {},
		Boss = "boss_king",
		SidekickId = "side_king",
		SidekickChance = 0.00001,
		Table = RelicConfig.Odds("boss_king"),
	},
}
for id, chest in RelicConfig.Chests do
	byId[id] = chest
end

-- A copy of a chest's rows, {} for anything else.
function RelicConfig.ChestOdds(id)
	local shown = {}
	local chest = id ~= nil and RelicConfig.Chests[id]
	for i, row in chest and chest.Table or {} do
		shown[i] = table.clone(row)
	end
	return shown
end

local STAT_WORDS = {
	{ "Damage", "Damage" },
	{ "AttackSpeed", "Attack Speed" },
	{ "Luck", "Luck" },
	{ "Money", "Money" },
	{ "Speed", "Speed" },
	{ "Stamina", "Stamina" },
}

-- "+15% Damage, +4% Attack Speed".
function RelicConfig.GainText(row)
	local parts = {}
	for _, stat in STAT_WORDS do
		local value = row.Bonuses[stat[1]]
		if value then
			table.insert(parts, string.format("+%d%% %s", math.round(value * 100), stat[2]))
		end
	end
	return table.concat(parts, ", ")
end

return RelicConfig
