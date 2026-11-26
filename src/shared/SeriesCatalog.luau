--!nonstrict
-- The character series and their preset trios (docs/CHARACTER_GACHA_SPEC.md "Series and preset teams", design doc
-- 4.8). Ids are permanent save keys, like character ids.
local StaminaConfig = require(script.Parent.StaminaConfig)

local SeriesCatalog = {}

SeriesCatalog.List = {
	{
		Id = "leaf",
		Name = "Narito Shippudon",
		Preset = { Name = "Team Seven", Members = { "leaf_hero", "leaf_avenger", "leaf_medic" } },
	},
	{
		Id = "db",
		Name = "Dragon Bawl Z",
		Preset = { Name = "Sayan Pride", Members = { "db_hero", "db_prince", "db_scholar" } },
	},
	{
		Id = "sea",
		Name = "One Peace",
		Preset = { Name = "Straw Crew", Members = { "sea_captain", "sea_swords", "sea_cook" } },
	},
	{
		Id = "ds",
		Name = "Demon Slicer",
		Preset = { Name = "Kamada Squad", Members = { "ds_hero", "ds_thunder", "ds_boar" } },
	},
	{
		Id = "jk",
		Name = "Jujitsu Kaisan",
		Preset = { Name = "First Years", Members = { "jk_vessel", "jk_shadows", "jk_nails" } },
	},
	{
		Id = "mha",
		Name = "My Hero Akademia",
		Preset = { Name = "Class 1-A", Members = { "mha_hero", "mha_blast", "mha_icefire" } },
	},
	{
		Id = "soul",
		Name = "Bleech",
		Preset = { Name = "Substitute Squad", Members = { "soul_substitute", "soul_ice", "soul_fang" } },
	},
	-- World 2 (design doc 4.47): preset names proposed
	{
		Id = "saw",
		Name = "Saw Man",
		World = 2,
		Preset = { Name = "Division Four", Members = { "saw_hero", "saw_blood", "saw_fox" } },
	},
	{
		Id = "solo",
		Name = "Solo Levelup",
		World = 2,
		Preset = { Name = "Ajin Guild", Members = { "solo_monarch", "solo_blade", "solo_vice" } },
	},
	{
		Id = "punch",
		Name = "One Punch",
		World = 2,
		Preset = { Name = "S-Class", Members = { "punch_psychic", "punch_fist", "punch_cyborg" } },
	},
	{
		Id = "dan",
		Name = "Dandadun",
		World = 2,
		Preset = { Name = "Occult Club", Members = { "dan_turbo", "dan_psychic", "dan_idol" } },
	},
	{
		Id = "kaiju",
		Name = "Kaijo No. 8",
		World = 2,
		Preset = { Name = "Third Division", Members = { "kaiju_hero", "kaiju_ice", "kaiju_axe" } },
	},
	{
		Id = "fr",
		Name = "Frierin",
		World = 2,
		Preset = { Name = "Frierin Party", Members = { "fr_mage", "fr_staff", "fr_axe" } },
	},
}

local byId = {}
for _, series in SeriesCatalog.List do
	byId[series.Id] = series
end

-- The series with this id, or nil.
function SeriesCatalog.Get(id)
	return byId[id]
end

-- Team bonus of a full team (design doc 4.8): "Preset", series (its 3 ids are a preset trio, any order), else
-- "Series", series (all 3 share one Series), else nil. `seriesOf(id)` returns a character's Series. Teams of 1-2: nil.
-- World 2 (4.47): a team of 3 or 4 whose 3 members are the trio, or 3 of one Series; the preset wins.
function SeriesCatalog.TeamBonus(ids, seriesOf)
	-- World 1: exactly 3 members; World 2 (design doc 4.47): any 3 matching members of up to 4
	local need = StaminaConfig.BONUS_MEMBERS
	if type(ids) ~= "table" or #ids < need or #ids > StaminaConfig.TEAM_SIZE then
		return nil, nil
	end
	local count = {}
	for i = 1, #ids do
		if table.find(ids, ids[i]) ~= i then
			return nil, nil -- a duplicate
		end
		local s = seriesOf(ids[i])
		if s then
			count[s] = (count[s] or 0) + 1
		end
	end
	for _, series in SeriesCatalog.List do
		local members = series.Preset and series.Preset.Members
		if members and table.find(ids, members[1]) and table.find(ids, members[2]) and table.find(ids, members[3]) then
			return "Preset", series
		end
	end
	for s, n in count do
		if n >= need and byId[s] then
			return "Series", byId[s]
		end
	end
	return nil, nil
end

return SeriesCatalog
