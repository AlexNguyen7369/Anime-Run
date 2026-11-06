--!nonstrict
-- BRIEF: docs/CHARACTER_GACHA_SPEC.md "Launch cast" + "Bleech series" + "Villains" + "Tests" (owner 2026-10-28, 2026-11-04, design doc 4.39): 56 rollable
-- characters plus the built-in starter, ids exactly the committed list below (never renamed or removed), unique, every field valid, every
-- Series exists, every preset has 3 distinct members of its own series, and no id contains a real anime name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local H = require(script.Parent.AcceptanceSupport)

local Tests = {}

-- The committed id list: { Id, Name, Rarity, Category, Series name, Chance (1 = catch-all), SpeedMulti, Event }
-- (Event = nil for the 56 regular characters; spec "Event-only characters" for the last 3).
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
	{ "sea_navigator", "Nammi", "Common", "Balanced", "One Peace", 1, 1.1 },
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
	{ "soul_healer", "Orihima", "Uncommon", "Balanced", "Bleech", 150, 2.1 },
	{ "soul_ice", "Rukiya", "Rare", "Marathoner", "Bleech", 3000, 3.5 },
	{ "soul_fang", "Renjy", "Epic", "Sprinter", "Bleech", 1000000, 13 },
	{ "soul_substitute", "Ichigu", "Legendary", "Balanced", "Bleech", 2e8, 70 },
	{ "soul_hollow", "Ulquiorro", "Mythic", "Sprinter", "Bleech", 3e10, 200 },
	{ "soul_lord", "Aizon", "Mythic", "Marathoner", "Bleech", 3e14, 400 },
	-- Villains (design doc 4.32, spec "Villains")
	{ "leaf_rings", "Paine", "Legendary", "Balanced", "Narito Shippudon", 3e7, 35 },
	{ "db_perfect", "Selle", "Mythic", "Balanced", "Dragon Bawl Z", 1e10, 170 },
	{ "sea_shark", "Arlon", "Epic", "Marathoner", "One Peace", 900000, 11 },
	{ "sea_thunder", "Enelu", "Mythic", "Sprinter", "One Peace", 3e12, 300 },
	{ "ds_upper", "Akazo", "Mythic", "Sprinter", "Demon Slicer", 1e14, 380 },
	{ "jk_volcano", "Jogoh", "Epic", "Marathoner", "Jujitsu Kaisan", 1200000, 13.5 },
	{ "jk_patch", "Mahitoh", "Legendary", "Balanced", "Jujitsu Kaisan", 5e8, 90 },
	{ "mha_decay", "Shigaraky", "Legendary", "Sprinter", "My Hero Akademia", 1.5e8, 65 },
	-- Two new series (design doc 4.39)
	{ "saw_nervous", "Kobene", "Uncommon", "Marathoner", "Chainsaw Mann", 180, 2.15 },
	{ "saw_fox", "Akki", "Rare", "Balanced", "Chainsaw Mann", 6000, 4.3 },
	{ "saw_blood", "Powah", "Epic", "Sprinter", "Chainsaw Mann", 800000, 12.5 },
	{ "saw_bomb", "Rezi", "Legendary", "Sprinter", "Chainsaw Mann", 4e8, 85 },
	{ "saw_hero", "Denjy", "Mythic", "Balanced", "Chainsaw Mann", 5e13, 370 },
	{ "saw_control", "Makina", "Eternal", "Marathoner", "Chainsaw Mann", 3e19, 5000 },
	{ "solo_vice", "Jinhoe", "Uncommon", "Marathoner", "Solo Levelin", 160, 2.1 },
	{ "solo_mage", "Jongen", "Rare", "Balanced", "Solo Levelin", 5000, 4.1 },
	{ "solo_blade", "Cha Hain", "Epic", "Sprinter", "Solo Levelin", 1800000, 15 },
	{ "solo_beast", "Yunho", "Legendary", "Marathoner", "Solo Levelin", 6e8, 95 },
	{ "solo_goliath", "Tomas Andre", "Mythic", "Marathoner", "Solo Levelin", 7e14, 415 },
	{ "solo_monarch", "Jinwu", "Eternal", "Balanced", "Solo Levelin", 1.5e19, 4000 },
	{ "ds_water", "Giyo", "Epic", "Marathoner", "Demon Slicer", 160000, 6, "rain" },
	{ "jk_night", "Toje", "Legendary", "Sprinter", "Jujitsu Kaisan", 4.3e7, 8, "night" },
	{ "sea_gold", "Rojer", "Legendary", "Balanced", "One Peace", 6.2e8, 10, "gold" },
}

-- A character wearing another id's model (spec "Bleech series" and "Villains" Model columns); every other character has Model = nil.
Tests.SHARED_MODEL = {
	soul_hollow = "foe_soul",
	leaf_rings = "foe_leaf",
	db_perfect = "foe_db",
	sea_shark = "foe_sea",
	sea_thunder = "foe_sea2",
	ds_upper = "foe_ds",
	jk_volcano = "foe_jk",
	jk_patch = "foe_jk2",
	mha_decay = "foe_mha",
}

-- Rows as { Id, Rarity, Chance, SpeedMulti, Event } for the gacha scenarios (Scenarios.luau GACHA_CATALOG).
Tests.CAST = {}
for _, row in CAST do
	table.insert(Tests.CAST, { Id = row[1], Rarity = row[3], Chance = row[6], SpeedMulti = row[7], Event = row[8] })
end

local EVENTS = { rain = true, night = true, gold = true } -- WeatherConfig events with an event-only character
-- regular (non-event) characters per rarity
local RARITY_COUNT =
	{ Common = 1, Uncommon = 9, Rare = 9, Epic = 11, Legendary = 11, Mythic = 11, Secret = 2, Eternal = 2 }
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
	-- Bleech series and its "Based on" column (design doc 4.30)
	{ 5, 253096350 },
	{ 5, 273100351 },
	{ 5, 273672035 },
	{ 6, 67569950 },
	{ 6, 1951662473 },
	{ 7, 1976864668 },
	{ 9, 1958541188 },
	-- Villains' "Based on" column (design doc 4.32)
	{ 4, 2090607759 },
	{ 4, 2090145031 },
	{ 6, 1919909773 },
	{ 4, 2090226475 },
	{ 5, 253141679 },
	{ 4, 2090407318 },
	{ 6, 221740109 },
	{ 9, 1370699169 },
	-- Chainsaw Mann and Solo Levelin, series and "Based on" column (design doc 4.39). A tweaked name may hold part of a
	-- real one, so two-part names are stored whole: the scan reads hub and Dojo text, where tweaked names may show.
	{ 6, 159852035 },
	{ 3, 193486266 },
	{ 5, 271097524 },
	{ 4, 2090684541 },
	{ 5, 256497457 },
	{ 6, 221847675 },
	{ 9, 1044187460 },
	{ 7, 1850452240 },
	{ 6, 25944079 },
	{ 6, 708224327 },
	{ 12, 1130477581 },
	{ 6, 114052001 },
	{ 12, 1717385066 },
	{ 13, 700217521 },
	-- Real place names from docs/TRACKS_AND_BIOMES_SPEC.md "References" (w4, design doc section 5 "no real place names")
	{ 6, 160293963 },
	{ 6, 42764698 },
	{ 5, 268211667 },
	{ 5, 261806107 },
	{ 6, 277297131 },
	{ 7, 308729511 },
	{ 6, 2112140938 },
	{ 10, 1514019198 },
	{ 8, 1085260683 },
	{ 7, 1105951376 },
	{ 7, 758389615 },
	{ 5, 253114223 },
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
	flag("all_59_characters", #all == 59 and #all == #CAST, #all, #CAST)
	flag("rollable_56_characters", #rollable == 56 and #rollable == #CAST - 3, #rollable, #CAST - 3) -- owner 2026-11-03: 3 event-only out

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
		if c.Chance == 1 then
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
		if c.Model ~= Tests.SHARED_MODEL[id] then
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

	-- No two rollable characters share a Chance: the rarest-first order and the Best Roll pedestal both read it
	local chanceOwner, chanceDupes = {}, {}
	for _, c in rollable do
		if chanceOwner[c.Chance] then
			table.insert(chanceDupes, chanceOwner[c.Chance] .. "=" .. c.Id)
		end
		chanceOwner[c.Chance] = c.Id
	end
	flag("rollable_chances_unique", #chanceDupes == 0, table.concat(chanceDupes, ","), "")

	-- Every rarity has its row in each per-rarity table: RaceConfig and StaminaConfig fall back to Common silently
	local gachaConfig = H.module(Shared, "GachaConfig")
	local raceConfig = H.module(Shared, "RaceConfig")
	local staminaConfig = H.module(Shared, "StaminaConfig")
	local workshopConfig = H.module(Shared, "WorkshopConfig")
	local rollAnim = H.module(Shared, "RollAnimConfig")
	local rowsOk = gachaConfig and raceConfig and staminaConfig and workshopConfig and rollAnim
	flag("rarity_tables_exist", rowsOk ~= nil and rowsOk ~= false)
	if rowsOk then
		local rowBad = {}
		for _, rarity in gachaConfig.RARITY_ORDER do
			local function need(name, ok)
				if not ok then
					table.insert(rowBad, name .. "." .. rarity)
				end
			end
			need("RaceConfig.RARITY_BASE", type(raceConfig.RARITY_BASE[rarity]) == "number")
			need("StaminaConfig.BASE", type(staminaConfig.BASE[rarity]) == "number")
			need("WorkshopConfig.RARITY_POINTS", type(workshopConfig.RARITY_POINTS[rarity]) == "number")
			need("GachaConfig.RARITY_COLORS", typeof(gachaConfig.RARITY_COLORS[rarity]) == "Color3")
			need("RollAnimConfig.HOLD", type(rollAnim.HOLD[rarity]) == "number")
		end
		flag("every_rarity_has_its_rows", #rowBad == 0, table.concat(rowBad, ", "), "")
	end

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

	-- series sizes from the committed list (sea / jk 8, ds 7, with their event character; others 6); every preset has 3 distinct members of its own series
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
	flag("series_count_9", #series.List == 9, #series.List, 9)
	flag("presets_three_own_members", #presetBad == 0, table.concat(presetBad, ","), "")

	-- Bleech (design doc 4.30, spec "Bleech series"): the 6 ids in their rarities, the shared enemy model, the preset
	local soulBad = {}
	for id, rarity in
		{
			soul_healer = "Uncommon",
			soul_ice = "Rare",
			soul_fang = "Epic",
			soul_substitute = "Legendary",
			soul_hollow = "Mythic",
			soul_lord = "Mythic",
		}
	do
		local c = catalog.Get(id)
		if not (c and c.Rarity == rarity and c.Series == "soul" and c.Rollable == true) then
			table.insert(soulBad, id)
		end
	end
	flag("soul_ids_in_rarities", #soulBad == 0, table.concat(soulBad, ","), "")
	local hollow = catalog.Get("soul_hollow")
	flag("soul_hollow_uses_foe_soul", hollow ~= nil and hollow.Model == "foe_soul", hollow and hollow.Model, "foe_soul")
	local soul = series.Get("soul")
	local soulPreset = soul and soul.Preset
	flag(
		"soul_preset_substitute_squad",
		type(soulPreset) == "table"
			and soulPreset.Name == "Substitute Squad"
			and H.same(soulPreset.Members, { "soul_substitute", "soul_ice", "soul_fang" })
	)

	-- Two new series (design doc 4.39): their presets
	for _, want in
		{
			{ "saw", "Division Four", { "saw_hero", "saw_blood", "saw_fox" } },
			{ "solo", "Ajin Guild", { "solo_monarch", "solo_blade", "solo_vice" } },
		}
	do
		local s = series.Get(want[1])
		local preset = s and s.Preset
		flag(
			want[1] .. "_preset",
			type(preset) == "table" and preset.Name == want[2] and H.same(preset.Members, want[3])
		)
	end

	-- Villains (design doc 4.32): every track enemy's model is worn by a rollable character
	local npc = H.module(Shared, "NpcConfig")
	local tracks = npc and npc.Tracks or {}
	local wearer, villainBad, foeTracks = {}, {}, 0
	for _, c in rollable do
		if c.Model ~= nil then
			wearer[c.Model] = c.Id
		end
	end
	for number, track in tracks do
		if type(track.Model) == "string" and string.sub(track.Model, 1, 4) == "foe_" then
			foeTracks += 1
			if wearer[track.Model] == nil then
				table.insert(villainBad, ("track %d:%s"):format(number, track.Model))
			end
		end
	end
	local track9, track10 = tracks[9], tracks[10]
	local tyrant = catalog.Get("db_tyrant")
	if not (track9 and wearer[track9.Model] == "soul_hollow") then
		table.insert(villainBad, "track 9")
	end
	if not (track10 and track10.Model == "db_tyrant" and tyrant and tyrant.Rollable == true) then
		table.insert(villainBad, "track 10")
	end
	if foeTracks ~= 9 then -- tracks 1 to 9; guards against the loop passing on nothing
		table.insert(villainBad, "foe tracks " .. foeTracks)
	end
	flag("villains_share_enemy_models", #villainBad == 0, table.concat(villainBad, ", "), "")
	return r
end

-- Best Roll pedestal store (design doc 4.39): Chance passes int64, so the RarestCar board stores a log-scale score in
-- LB_RarestCar_v2. Checked through LeaderboardService's own seams: the score it would write, read back by a fake store.
local RAREST_ROUND_TRIP = { "saw_control", "solo_monarch", "jk_strongest" } -- Chance 3e19, 1.5e19, 5e18
local RAREST_UID = 991600000

local function fakePlayerOwning(id)
	local p = Instance.new("Folder")
	p.Name = "CarTestRarest"
	local owned = Instance.new("Folder")
	owned.Name = "GachaData"
	owned.Parent = p
	local entry = Instance.new("StringValue")
	entry.Name = id
	entry.Value = id
	entry.Parent = owned
	return p
end

local function fakeStore(rows)
	return {
		GetSortedAsync = function()
			return {
				GetCurrentPage = function()
					return rows
				end,
			}
		end,
	}
end

function Tests.rarest_board()
	local r, flag = H.report("rarest_board")
	local catalog = H.module(Shared, "CharacterCatalog")
	local config = H.module(Shared, "LeaderboardConfig")
	local format = H.module(Shared, "HudFormat")
	local service = H.module(script.Parent.Parent, "LeaderboardService")
	local apiOk = catalog ~= nil
		and config ~= nil
		and format ~= nil
		and service ~= nil
		and type(service.Scores) == "function"
		and type(service.SetStore) == "function"
		and type(service.SetNameLookup) == "function"
		and type(service.Refresh) == "function"
	flag("rarest_board_api", apiOk)
	if not apiOk then
		return r
	end

	local store
	for _, board in config.Boards do
		if board.Id == "RarestCar" then
			store = board.Store
		end
	end
	flag("rarest_board_store_v2", store == "LB_RarestCar_v2", store, "LB_RarestCar_v2")

	-- The score OrderedDataStore can hold, and rarer always scores higher (Rollable is rarest first)
	local function scoreOf(id)
		local p = fakePlayerOwning(id)
		local score = service.Scores(p).RarestCar
		p:Destroy()
		return score
	end
	local fitBad, orderBad, above = {}, {}, nil
	for _, spec in catalog.Rollable() do
		local score = scoreOf(spec.Id)
		if not (type(score) == "number" and score == math.floor(score) and score >= 0 and score <= 9.2e18) then
			table.insert(fitBad, spec.Id .. "=" .. tostring(score))
		elseif above and score >= above then
			table.insert(orderBad, spec.Id)
		end
		above = score
	end
	flag("rarest_score_fits_int64", #fitBad == 0, table.concat(fitBad, ","), "")
	flag("rarest_score_rises_with_chance", #orderBad == 0, table.concat(orderBad, ","), "")
	flag("rarest_score_eternal_beats_secret", scoreOf("saw_control") > scoreOf("solo_monarch"))
	flag("rarest_score_lowest_eternal_beats_secret", scoreOf("solo_monarch") > scoreOf("jk_strongest"))

	-- Round trip: the stored score reads back as the same character, with its own odds, on the pedestal
	local area = Workspace:FindFirstChild("SpawnArea")
	local best = area and area:FindFirstChild("BestRoll")
	local stats = best and best:FindFirstChild("Stats", true)
	flag("rarest_pedestal_exists", stats ~= nil)
	if stats then
		service.SetNameLookup(function()
			return "CarTestRarest"
		end)
		local only = { RarestCar = true }
		local ok, err = pcall(function()
			for _, id in RAREST_ROUND_TRIP do
				local spec = catalog.Get(id)
				service.SetStore(function()
					return fakeStore({ { key = tostring(RAREST_UID), value = scoreOf(id) } })
				end)
				service.Refresh(only)
				flag(
					"rarest_round_trip_id_" .. id,
					best:GetAttribute("CharacterId") == id,
					best:GetAttribute("CharacterId"),
					id
				)
				flag(
					"rarest_round_trip_name_" .. id,
					stats.Character.Text == spec.Name,
					stats.Character.Text,
					spec.Name
				)
				local odds = format.Odds(spec.Chance)
				flag("rarest_round_trip_odds_" .. id, stats.Odds.Text == odds, stats.Odds.Text, odds)
			end
		end)
		flag("rarest_round_trip_no_error", ok)
		if not ok then
			r.metrics.error = tostring(err)
		end
		-- Leave the pedestal empty and hand it back to the real store; its next read fills it
		service.SetStore(function()
			return fakeStore({})
		end)
		pcall(service.Refresh, only)
		service.SetStore(nil)
		service.SetNameLookup(nil)
	end
	return r
end

-- Shared with WorldTests (hub / Dojo text never shows a real name, design doc section 5)
Tests.realNameIn = realNameIn

return Tests
