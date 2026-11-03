--!nonstrict
-- The character series and their preset trios (docs/CHARACTER_GACHA_SPEC.md "Series and preset teams", design doc
-- 4.8). Ids are permanent save keys, like character ids.
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
function SeriesCatalog.TeamBonus(ids, seriesOf)
	if type(ids) ~= "table" or #ids ~= 3 or ids[1] == ids[2] or ids[1] == ids[3] or ids[2] == ids[3] then
		return nil, nil
	end
	for _, series in SeriesCatalog.List do
		local members = series.Preset and series.Preset.Members
		if members and table.find(members, ids[1]) and table.find(members, ids[2]) and table.find(members, ids[3]) then
			return "Preset", series
		end
	end
	local first = seriesOf(ids[1])
	if first and seriesOf(ids[2]) == first and seriesOf(ids[3]) == first and byId[first] then
		return "Series", byId[first]
	end
	return nil, nil
end

return SeriesCatalog
