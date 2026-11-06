--!nonstrict
-- Relics (design doc 4.38, docs/RELIC_SPEC.md). Stat counts, the priority and RagaSidekickChance are owner values; names, odds
-- and bonuses are placeholders. Odds is a percent and each boss's list sums to exactly 100; a bonus 0.15 is +15%.
local RelicConfig = {}

RelicConfig.RagaSidekickChance = 0.00001 -- design doc 4.37: 0.001%, as a fraction
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
}

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

-- Sealed spins saved as rows of the bag (RELIC_SPEC "Chests"), apart from Bosses.
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
		SidekickChance = RelicConfig.RagaSidekickChance,
		Table = RelicConfig.Odds("big_raga"),
	},
	relic_chest_adapted = {
		Id = "relic_chest_adapted",
		Name = "Adapted Raga's Treasure",
		Image = "rbxassetid://81070324097920", -- assets/ui/chest_adapted.png
		Chest = true,
		Bonuses = {},
		Boss = "big_raga",
		SidekickChance = 0.0001, -- owner 2026-11-06: 0.01%, as a fraction
		Table = adaptedTable,
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
