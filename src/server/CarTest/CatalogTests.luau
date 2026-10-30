--!nonstrict
-- BRIEF: docs/CHARACTER_GACHA_SPEC.md "Launch cast" + "Tests" (owner 2026-10-28): 30 rollable characters plus the
-- built-in starter, ids exactly the committed list below (never renamed or removed), unique, every field valid, every
-- Series exists, every preset has 3 distinct members of its own series, and no id contains a real anime name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local H = require(script.Parent.AcceptanceSupport)

local Tests = {}

-- The committed id list: { Id, Name, Rarity, Category, Series name, Chance (nil = catch-all), SpeedMulti, Event }
-- (Event = nil for the 30 regular characters; spec "Event-only characters" for the last 3).
-- (spec "Launch cast" and placeholder Chance / SpeedMulti tables).
local CAST = {
	{ "leaf_medic", "Sakara", "Uncommon", "Balanced", "Narito Shippudon", 10, 1.25 },
	{ "leaf_copycat", "Kakashe", "Rare", "Balanced", "Narito Shippudon", 500, 2 },
	{ "leaf_avenger", "Saske", "Epic", "Sprinter", "Narito Shippudon", 2.5e6, 16.5 },
	{ "leaf_hero", "Narito", "Legendary", "Marathoner", "Narito Shippudon", 1e7, 25 },
	{ "leaf_crow", "Itachy", "Mythic", "Sprinter", "Narito Shippudon", 5e9, 150 },
	{ "db_green", "Pikolo", "Uncommon", "Marathoner", "Dragon Bawl Z", 20, 1.4 },
	{ "db_scholar", "Gohon", "Rare", "Balanced", "Dragon Bawl Z", 1000, 2.6 },
	{ "db_tyrant", "Freezo", "Epic", "Sprinter", "Dragon Bawl Z", 50000, 6 },
	{ "db_prince", "Vegata", "Legendary", "Sprinter", "Dragon Bawl Z", 5e7, 45 },
	{ "db_hero", "Gokku", "Secret", "Balanced", "Dragon Bawl Z", 1.6e16, 1000 },
	{ "sea_navigator", "Nammi", "Common", "Balanced", "One Peace", nil, 1.1 },
	{ "sea_cook", "Sanjy", "Uncommon", "Sprinter", "One Peace", 40, 1.6 },
	{ "sea_swords", "Zoru", "Rare", "Marathoner", "One Peace", 2000, 3.2 },
	{ "sea_flame", "Aice", "Epic", "Sprinter", "One Peace", 120000, 8 },
	{ "sea_captain", "Lufy", "Legendary", "Marathoner", "One Peace", 1e8, 60 },
	{ "ds_boar", "Inosuki", "Uncommon", "Marathoner", "Demon Slicer", 70, 1.8 },
	{ "ds_thunder", "Zenitsa", "Rare", "Sprinter", "Demon Slicer", 4000, 3.9 },
	{ "ds_sister", "Nezuka", "Epic", "Balanced", "Demon Slicer", 300000, 10 },
	{ "ds_hero", "Tanjiru", "Legendary", "Balanced", "Demon Slicer", 3e8, 80 },
	{ "ds_flame", "Rengoko", "Mythic", "Sprinter", "Demon Slicer", 1e11, 250 },
	{ "jk_nails", "Nobora", "Uncommon", "Balanced", "Jujitsu Kaisan", 120, 2 },
	{ "jk_shadows", "Megumo", "Rare", "Marathoner", "Jujitsu Kaisan", 8000, 4.6 },
	{ "jk_vessel", "Yuuji", "Epic", "Sprinter", "Jujitsu Kaisan", 700000, 12 },
	{ "jk_king", "Sukana", "Mythic", "Sprinter", "Jujitsu Kaisan", 1e13, 350 },
	{ "jk_strongest", "Gojio", "Secret", "Balanced", "Jujitsu Kaisan", 5e18, 2800 },
	{ "mha_float", "Ochaku", "Uncommon", "Marathoner", "My Hero Akademia", 200, 2.2 },
	{ "mha_icefire", "Todoroky", "Rare", "Balanced", "My Hero Akademia", 13000, 5.25 },
	{ "mha_blast", "Bakugoo", "Epic", "Sprinter", "My Hero Akademia", 1500000, 14.5 },
	{ "mha_hero", "Deko", "Legendary", "Balanced", "My Hero Akademia", 7.8e8, 100 },
	{ "mha_symbol", "All Mighty", "Mythic", "Marathoner", "My Hero Akademia", 1e15, 425 },
	{ "ds_water", "Giyo", "Epic", "Marathoner", "Demon Slicer", 160000, 6, "rain" },
	{ "jk_night", "Toje", "Legendary", "Sprinter", "Jujitsu Kaisan", 4.3e7, 8, "night" },
	{ "sea_gold", "Rojer", "Legendary", "Balanced", "One Peace", 6.2e8, 10, "gold" },
}

-- Rows as { Id, Rarity, Chance, SpeedMulti, Event } for the gacha scenarios (Scenarios.luau GACHA_CATALOG).
Tests.CAST = {}
for _, row in CAST do
	table.insert(Tests.CAST, { Id = row[1], Rarity = row[3], Chance = row[6], SpeedMulti = row[7], Event = row[8] })
end

local EVENTS = { rain = true, night = true, gold = true } -- WeatherConfig events with an event-only character
-- regular (non-event) characters per rarity
local RARITY_COUNT = { Common = 1, Uncommon = 6, Rare = 6, Epic = 6, Legendary = 5, Mythic = 4, Secret = 2 }
local CATEGORIES = { Sprinter = true, Balanced = true, Marathoner = true }
local ARCHETYPES = {}
for _, a in
	{ "ninja", "swordsman", "mage", "brawler", "idol", "mecha pilot", "beast-kin", "gunslinger", "monk", "spirit" }
do
	ARCHETYPES[a] = true
end
-- Real names (spec "Based on" column and series sources), stored only as { length, hash } (owner 2026-10-28: the
-- names never ship, not even in tests). Names shorter than 5 match a whole "_" segment, longer ones any substring.
local REAL_NAME_HASHES = {
	{ 3, 193485998 },
	{ 4, 2090180944 },
	{ 4, 2090293573 },
	{ 4, 2090299606 },
	{ 4, 2090299645 },
	{ 4, 2090536012 },
	{ 4, 2090766781 },
	{ 4, 2090953000 },
	{ 4, 2090982673 },
	{ 5, 260407764 },
	{ 5, 266550989 },
	{ 5, 273451942 },
	{ 5, 274142524 },
	{ 6, 87472541 },
	{ 6, 143515654 },
	{ 6, 226460687 },
	{ 6, 261247940 },
	{ 6, 266278823 },
	{ 6, 277253982 },
	{ 6, 302373464 },
	{ 6, 456673266 },
	{ 6, 456960535 },
	{ 6, 480391554 },
	{ 6, 578662023 },
	{ 6, 1938854883 },
	{ 6, 2115468427 },
	{ 7, 442789417 },
	{ 7, 521490058 },
	{ 7, 647844424 },
	{ 7, 761341753 },
	{ 7, 1053441324 },
	{ 7, 1332453545 },
	{ 7, 1879133478 },
	{ 7, 2081047238 },
	{ 8, 791639763 },
	{ 8, 1536872249 },
	{ 8, 1941540818 },
	{ 8, 2118733061 },
	{ 9, 655632996 },
	{ 9, 1136966958 },
	{ 10, 379882491 },
	{ 11, 1307652066 },
	{ 11, 1795170271 },
	{ 12, 429441481 },
}

-- djb2 mod 2^31 - 1 (stays exact in a double); tools: the same loop in any language gives the stored values.
local function nameHash(s)
	local x = 5381
	for i = 1, #s do
		x = (x * 33 + string.byte(s, i)) % 2147483647
	end
	return x
end

-- The { length, hash } of the first real name in `id`, as text, or nil.
local function realNameIn(id)
	local segments = {}
	for _, seg in string.split(id, "_") do
		segments[nameHash(seg) .. ":" .. #seg] = true
	end
	for _, entry in REAL_NAME_HASHES do
		local len, hash = entry[1], entry[2]
		local key = hash .. ":" .. len
		if segments[key] then
			return key
		end
		if len >= 5 then
			for i = 1, #id - len + 1 do
				if nameHash(string.sub(id, i, i + len - 1)) == hash then
					return key
				end
			end
		end
	end
	return nil
end

function Tests.catalog()
	local r, flag = H.report("catalog")
	local catalog = H.module(Shared, "CharacterCatalog")
	local series = H.module(Shared, "SeriesCatalog")
	local apiOk = catalog ~= nil
		and type(catalog.Get) == "function"
		and type(catalog.All) == "function"
		and type(catalog.Rollable) == "function"
		and type(catalog.Passes) == "function"
		and series ~= nil
		and type(series.Get) == "function"
		and type(series.List) == "table"
	flag("catalog_api", apiOk)
	if not apiOk then
		return r
	end
	flag("old_car_catalog_removed", Shared:FindFirstChild("CarCatalog") == nil and Shared:FindFirstChild("Cars") == nil)
	flag("characters_folder", Shared:FindFirstChild("Characters") ~= nil)

	-- starter: built in, not rollable, not in the Index, Balanced, no Series
	local starter = catalog.Get("starter")
	flag(
		"starter_built_in",
		catalog.STARTER_ID == "starter"
			and type(starter) == "table"
			and starter.Id == "starter"
			and starter.Rollable == false
			and starter.Chance == nil
			and starter.Category == "Balanced"
			and starter.Series == nil
	)
	local passes = catalog.Passes()
	flag("no_pass_characters", type(passes) == "table" and #passes == 0, type(passes) == "table" and #passes or -1, 0)

	local all, rollable = catalog.All(), catalog.Rollable()
	flag("all_33_characters", #all == #CAST, #all, #CAST)
	flag("rollable_33_characters", #rollable == #CAST, #rollable, #CAST)

	-- ids exactly the committed list, unique, starter excluded
	local want, seen, dupes, extra = {}, {}, {}, {}
	for _, row in CAST do
		want[row[1]] = row
	end
	for _, list in { all, rollable } do
		local local_seen = {}
		for _, c in list do
			local id = type(c) == "table" and c.Id or nil
			if type(id) ~= "string" or local_seen[id] then
				table.insert(dupes, tostring(id))
			else
				local_seen[id] = true
				seen[id] = true
				if not want[id] then
					table.insert(extra, id)
				end
			end
		end
	end
	local missing = {}
	for _, row in CAST do
		if not seen[row[1]] or catalog.Get(row[1]) == nil then
			table.insert(missing, row[1])
		end
	end
	flag("ids_unique", #dupes == 0, table.concat(dupes, ","), "")
	flag(
		"ids_exactly_spec_list",
		#missing == 0 and #extra == 0,
		table.concat(missing, ",") .. "|" .. table.concat(extra, ","),
		""
	)
	flag("starter_not_in_index", not seen.starter)

	-- every field equals the spec table and is valid
	local fieldBad, counts, catchAll = {}, {}, nil
	for _, row in CAST do
		local id, name, rarity, category, seriesName, chance, multi, event = table.unpack(row, 1, 8)
		local c = catalog.Get(id)
		if type(c) ~= "table" then
			continue
		end
		if event == nil then
			counts[c.Rarity] = (counts[c.Rarity] or 0) + 1
		end
		if c.Chance == nil then
			catchAll = id
		end
		local s = type(c.Series) == "string" and series.Get(c.Series) or nil
		local problems = {}
		if c.Id ~= id then
			table.insert(problems, "Id")
		end
		if c.Name ~= name then
			table.insert(problems, "Name")
		end
		if c.Rarity ~= rarity then
			table.insert(problems, "Rarity")
		end
		if c.Chance ~= chance then
			table.insert(problems, "Chance")
		end
		if type(c.SpeedMulti) ~= "number" or math.abs(c.SpeedMulti - multi) > 1e-9 then
			table.insert(problems, "SpeedMulti")
		end
		if c.Category ~= category or not CATEGORIES[c.Category] then
			table.insert(problems, "Category")
		end
		if not (s and s.Name == seriesName) then
			table.insert(problems, "Series")
		end
		if not ARCHETYPES[c.Archetype] then
			table.insert(problems, "Archetype")
		end
		if c.Model ~= nil then
			table.insert(problems, "Model")
		end
		if c.Event ~= event or (c.Event ~= nil and not EVENTS[c.Event]) then
			table.insert(problems, "Event")
		end
		if c.Rollable ~= true then
			table.insert(problems, "Rollable")
		end
		if c.GamepassId ~= nil then
			table.insert(problems, "GamepassId")
		end
		if #problems > 0 then
			table.insert(fieldBad, id .. ":" .. table.concat(problems, "/"))
		end
	end
	flag("fields_match_spec", #fieldBad == 0, table.concat(fieldBad, ", "), "")
	local countBad = {}
	for rarity, n in RARITY_COUNT do
		if (counts[rarity] or 0) ~= n then
			table.insert(countBad, ("%s=%d want %d"):format(rarity, counts[rarity] or 0, n))
		end
	end
	flag("rarity_counts", #countBad == 0, table.concat(countBad, ", "), "")
	flag("catch_all_sea_navigator", catchAll == "sea_navigator", tostring(catchAll), "sea_navigator")
	flag("rollable_catch_all_last", rollable[#rollable] ~= nil and rollable[#rollable].Id == "sea_navigator")

	-- no id contains a real anime name
	local realBad = {}
	for _, list in { all, { starter } } do
		for _, c in list do
			local hit = type(c) == "table" and type(c.Id) == "string" and realNameIn(string.lower(c.Id))
			if hit then
				table.insert(realBad, c.Id .. "~" .. hit)
			end
		end
	end
	flag("no_real_name_in_ids", #realBad == 0, table.concat(realBad, ","), "")

	-- series sizes from the committed list (ds / jk / sea 6 with their event character, others 5); every preset has 3 distinct members of its own series
	local presetBad, perSeries, wantSize = {}, {}, {}
	for _, row in CAST do
		wantSize[row[5]] = (wantSize[row[5]] or 0) + 1
	end
	for _, c in all do
		if type(c.Series) == "string" then
			perSeries[c.Series] = (perSeries[c.Series] or 0) + 1
		end
	end
	for _, s in series.List do
		local members = type(s.Preset) == "table" and s.Preset.Members or nil
		local ok = type(s.Id) == "string"
			and realNameIn(string.lower(s.Id)) == nil
			and perSeries[s.Id] ~= nil
			and perSeries[s.Id] == wantSize[s.Name]
			and type(members) == "table"
			and #members == 3
		if ok then
			local distinct = {}
			for _, id in members do
				local c = catalog.Get(id)
				ok = ok and not distinct[id] and c ~= nil and c.Series == s.Id
				distinct[id] = true
			end
		end
		if not ok then
			table.insert(presetBad, tostring(s.Id))
		end
	end
	flag("series_count_6", #series.List == 6, #series.List, 6)
	flag("presets_three_own_members", #presetBad == 0, table.concat(presetBad, ","), "")
	return r
end

-- Shared with WorldTests (hub / Dojo text never shows a real name, design doc section 5)
Tests.realNameIn = realNameIn

return Tests
