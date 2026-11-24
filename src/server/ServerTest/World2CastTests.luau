--!nonstrict
-- BRIEF: design doc 4.47 "Cast in game" (2026-11-24), docs/WORLD2_SPEC.md "Cast in game". World 2 rolls only its 43 characters
-- and summons only its 12 Sidekicks; World 1's pool, odds and rotation stay exactly what they were; saves keep every world's ids.
-- On demand: ReplicatedStorage attributes ServerTestOnly = "world2_cast", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local CatalogTests = require(script.Parent.CatalogTests)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990247000
-- docs/WORLD2_CAST.md, rarest last
local CAST = {
	Common = { "punch_rider" },
	Uncommon = { "dan_hex", "kaiju_ice", "fr_axe", "solo_vice", "saw_nervous" },
	Rare = { "punch_cyborg", "dan_idol", "kaiju_axe", "fr_staff", "solo_mage", "saw_fox" },
	Epic = {
		"punch_speed",
		"dan_medium",
		"kaiju_blade",
		"fr_hero",
		"saw_blood",
		"solo_blade",
		"saw_katana",
		"dan_granny",
	},
	Legendary = {
		"punch_psychic",
		"dan_psychic",
		"kaiju_captain",
		"fr_cut",
		"saw_bomb",
		"solo_beast",
		"fr_scales",
		"kaiju_nine",
		"solo_flame",
	},
	Mythic = {
		"punch_fist",
		"dan_turbo",
		"kaiju_hero",
		"fr_mage",
		"saw_hero",
		"solo_goliath",
		"solo_ant",
		"punch_serpent",
		"fr_gold",
		"punch_monster",
	},
	Eternal = { "solo_monarch", "saw_control", "fr_great", "punch_void" },
}
local CAST_SIZE = 43
local ENEMIES = {
	"saw_katana",
	"solo_flame",
	"punch_monster",
	"dan_granny",
	"kaiju_nine",
	"fr_scales",
	"solo_ant",
	"punch_serpent",
	"fr_gold",
	"saw_control",
}
local SIDEKICKS = {
	side_box = "Common",
	side_cat = "Common",
	side_lucky = "Common",
	side_tiger = "Rare",
	side_bird = "Rare",
	side_hound = "Legendary",
	side_shaman = "Legendary",
	side_acrobat = "Mythic",
	side_brawler = "Mythic",
	side_general = "Mythic",
	side_dragon = "Secret",
	side_dark = "Secret",
}
-- World 1's set in list order: the order decides the seeded draws
local WORLD1_SIDEKICKS = {
	"side_chain",
	"side_pig",
	"side_crow",
	"side_dogs",
	"side_reindeer",
	"side_ant",
	"side_reaper",
	"side_fist",
	"side_knight",
	"side_wyvern",
	"side_curse",
	"side_fox",
}
-- docs/WORLD2_SPEC.md "Cast in game" and CHARACTER_GACHA_SPEC "World 2 cast": id -> { Name, Category, Chance, SpeedMulti }
local SPEC = {
	punch_rider = { "Mumon Rider", "Marathoner", 1, 1.1 },
	dan_hex = { "Jijo", "Balanced", 12, 1.31 },
	kaiju_ice = { "Rino", "Balanced", 25, 1.54 },
	fr_axe = { "Stork", "Marathoner", 50, 1.76 },
	solo_vice = { "Jinhu", "Marathoner", 160, 2.1 },
	saw_nervous = { "Kobene", "Marathoner", 180, 2.15 },
	punch_cyborg = { "Genus", "Sprinter", 550, 2.1 },
	dan_idol = { "Airah", "Balanced", 650, 2.26 },
	kaiju_axe = { "Kikuru", "Sprinter", 1600, 3.16 },
	fr_staff = { "Ferne", "Balanced", 2500, 3.61 },
	solo_mage = { "Jongen", "Balanced", 5000, 4.1 },
	saw_fox = { "Akki", "Balanced", 6000, 4.3 },
	punch_speed = { "Speedo Sonik", "Sprinter", 60000, 6.49 },
	dan_medium = { "Seika", "Balanced", 140000, 8.76 },
	kaiju_blade = { "Hoshena", "Sprinter", 350000, 11.2 },
	fr_hero = { "Himmal", "Balanced", 600000, 12.7 },
	saw_blood = { "Powah", "Sprinter", 800000, 12.5 },
	saw_katana = { "Katanah Man", "Sprinter", 1.1e6, 14.3 },
	dan_granny = { "Turbo Grammy", "Sprinter", 1.4e6, 14.9 },
	solo_blade = { "Sha Hain", "Sprinter", 1.8e6, 15 },
	punch_psychic = { "Tatsumako", "Balanced", 1.2e7, 28.1 },
	dan_psychic = { "Momu", "Balanced", 3.5e7, 46.6 },
	kaiju_captain = { "Mena Ashiru", "Balanced", 6e7, 55.8 },
	fr_cut = { "Ubbel", "Sprinter", 1.2e8, 67.8 },
	fr_scales = { "Ora", "Marathoner", 1.8e8, 74.8 },
	kaiju_nine = { "Kaijo No. 9", "Balanced", 2.5e8, 80.4 },
	saw_bomb = { "Rezi", "Sprinter", 4e8, 85 },
	solo_beast = { "Yunho", "Marathoner", 6e8, 95 },
	solo_flame = { "Barran", "Balanced", 7e8, 98.1 },
	punch_fist = { "Bange", "Marathoner", 6e9, 154 },
	dan_turbo = { "Okaron", "Sprinter", 2e10, 181 },
	kaiju_hero = { "Kafko", "Balanced", 8e10, 212 },
	fr_mage = { "Frierin", "Balanced", 2e11, 233 },
	solo_ant = { "Berru", "Sprinter", 2e12, 285 },
	punch_serpent = { "Orochy", "Marathoner", 8e12, 316 },
	fr_gold = { "Makto", "Balanced", 2e13, 337 },
	saw_hero = { "Denjy", "Balanced", 5e13, 370 },
	punch_monster = { "Garoo", "Sprinter", 2e14, 389 },
	solo_goliath = { "Golioth", "Marathoner", 7e14, 415 },
	solo_monarch = { "Jinwu", "Balanced", 6e18, 4000 },
	saw_control = { "Makina", "Marathoner", 7e18, 5000 },
	fr_great = { "Serye", "Balanced", 8e18, 5420 },
	punch_void = { "Void Saitamo", "Balanced", 9e18, 6000 },
}
-- The World 2 source names, hashed as CatalogTests keeps World 1's: { length, hash }
local SOURCE_HASHES = {
	{ 6, 159852035 },
	{ 3, 193486266 },
	{ 4, 2090684541 },
	{ 5, 256497457 },
	{ 6, 221847675 },
	{ 6, 114052001 },
	{ 5, 263756671 },
	{ 5, 261087564 },
	{ 6, 708224327 },
	{ 6, 504244599 },
	{ 5, 253252497 },
	{ 7, 35406450 },
	{ 5, 267744489 },
	{ 5, 260055395 },
	{ 9, 1015580300 },
	{ 5, 259916005 },
	{ 6, 320416175 },
	{ 4, 2090400877 },
	{ 4, 2090077700 },
	{ 5, 274280866 },
	{ 4, 2090515327 },
	{ 6, 311628379 },
	{ 4, 2090684155 },
	{ 6, 153070976 },
	{ 7, 1420976533 },
	{ 4, 2090508812 },
	{ 6, 1920945552 },
	{ 5, 264646469 },
	{ 5, 274811436 },
	{ 4, 2090253042 },
	{ 6, 35734055 },
	{ 7, 1090972917 },
	{ 5, 274290591 },
	{ 5, 253985931 },
	{ 4, 2090109301 },
	{ 5, 267172280 },
	{ 5, 253978639 },
	{ 6, 479123896 },
	{ 5, 274427891 },
	{ 7, 1862591724 },
	{ 8, 2018587539 },
	{ 8, 150328071 },
	{ 8, 554322656 },
	{ 5, 267014964 },
	{ 4, 2090773614 },
	{ 14, 568994612 },
	{ 8, 1659613731 },
	{ 13, 700217521 },
	{ 12, 273609702 },
	{ 10, 779136316 },
	{ 9, 1260940076 },
	{ 12, 1854864974 },
	{ 4, 2090090768 },
	{ 4, 2090788399 },
	{ 6, 121149904 },
	{ 5, 273468277 },
	{ 5, 271097524, true }, -- a common word: a whole segment only
	{ 4, 2090104799, true }, -- a common word: a whole segment only
	{ 5, 274645603, true }, -- a common word: a whole segment only
	{ 5, 267313366, true }, -- a common word: a whole segment only
}
local SLOT0, SLOTS = 1000000, 100

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= 1e-9
end

Tests.SPEC = SPEC -- Scenarios.gacha rolls against it

function Tests.world2_cast()
	local r, flag = H.report("world2_cast")
	local catalog, gacha = require(Shared.CharacterCatalog), require(Shared.GachaConfig)
	local race, series, npc = require(Shared.RaceConfig), require(Shared.SeriesCatalog), require(Shared.NpcConfig)
	local cleanup = {}
	local function section(name, fn)
		local ok, err = xpcall(fn, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end

	section("cast", function()
		local want, missing = {}, {}
		for rarity, ids in CAST do
			for _, id in ids do
				want[id] = true
				local spec = catalog.Get(id)
				if
					not (
						spec
						and spec.World == 2
						and spec.Rarity == rarity
						and spec.Rollable
						and series.Get(spec.Series)
					)
				then
					table.insert(missing, id)
				end
			end
		end
		flag("cast_in_rarities", #missing == 0, table.concat(missing, ","), "")
		flag("cast_43", #catalog.All(2) == CAST_SIZE, #catalog.All(2), CAST_SIZE)
		flag("pool_43", #catalog.Rollable(2) == CAST_SIZE, #catalog.Rollable(2), CAST_SIZE)
		local extra = {}
		for _, spec in catalog.Rollable(2) do
			if not want[spec.Id] then
				table.insert(extra, spec.Id)
			end
		end
		flag("pool_only_world2", #extra == 0, table.concat(extra, ","), "")
		local pool = catalog.Rollable(2)
		flag("catch_all_mumon_rider", pool[#pool].Id == "punch_rider" and pool[#pool].Chance == 1, pool[#pool].Id)
		-- rarer rarity, rarer odds; every Chance (the RarestCharacter board's key) and Order unique over both worlds but the two catch-alls
		local rank, ordered, chances, orders, unique = {}, true, {}, {}, true
		for i, rarity in gacha.RARITY_ORDER do
			rank[rarity] = i
		end
		for i, spec in pool do
			ordered = ordered
				and (i == 1 or (spec.Chance < pool[i - 1].Chance and rank[spec.Rarity] <= rank[pool[i - 1].Rarity]))
		end
		for _, spec in catalog.Everything() do
			unique = unique and (spec.Chance == 1 or not chances[spec.Chance]) and not orders[spec.Order]
			chances[spec.Chance], orders[spec.Order] = true, true
			unique = unique and spec.Chance <= 9e18 -- LeaderboardService's cap
		end
		flag("odds_follow_rarity", ordered)
		flag("chance_and_order_unique", unique)
		local presets = 0
		for _, s in series.List do
			if s.World == 2 then
				presets += 1
				local kind, got = series.TeamBonus(s.Preset.Members, function(id)
					return catalog.Get(id).Series
				end)
				local own = kind == "Preset" and got == s
				for _, id in s.Preset.Members do
					own = own and catalog.Get(id).Series == s.Id
				end
				flag("preset_" .. s.Id, own)
			end
		end
		flag("series_6", presets == 6, presets, 6)
		for number, id in ENEMIES do
			flag(
				"enemy_" .. number,
				npc.World2[number].Model == id and npc.World2[number].Label == catalog.Get(id).Name
			)
		end
	end)

	section("names", function()
		local bad, real, count = {}, {}, 0
		local function scan(...)
			for _, text in { ... } do
				-- as ids: "Kaijo No. 8" -> kaijo_no_8, so the hash list's "_" segments match
				local key = string.gsub(string.lower(text), "[^a-z0-9]+", "_")
				if CatalogTests.realNameIn(key) or CatalogTests.realNameIn(key, SOURCE_HASHES) then
					table.insert(real, text)
				end
			end
		end
		for id, want in SPEC do
			count += 1
			local c = catalog.Get(id)
			if not (c and H.same({ c.Name, c.Category, c.Chance, c.SpeedMulti }, want)) then
				table.insert(bad, id)
			end
			scan(id, c and c.Name or "") -- the shipped name, not the table's
		end
		for _, s in series.List do
			if s.World == 2 then
				scan(s.Id, s.Name, s.Preset.Name)
			end
		end
		for _, enemy in npc.World2 do
			scan(enemy.Label)
		end
		for _, row in require(Shared.SidekickConfig).Lists[2] do
			scan(row.Id, row.Name)
		end
		flag("spec_fields_43", #bad == 0 and count == CAST_SIZE, table.concat(bad, ","), "")
		flag("no_real_names", #real == 0, table.concat(real, ","), "")
	end)

	section("daily", function()
		local Daily = require(Server.DailyLoginService)
		local function rarest(world, allowed)
			for _, spec in catalog.Rollable(world) do
				if allowed(spec) then
					return spec
				end
			end
			return nil
		end
		local first = Daily.GuaranteedPick({}, 2)
		flag("daily_world2_legendary", first ~= nil and first.Id == "solo_flame", first and first.Id)
		local owned, capped = {}, true
		for _ = 1, CAST_SIZE do
			local spec = Daily.GuaranteedPick(owned, 2)
			if not spec then
				break
			end
			capped = capped and spec.Rarity ~= "Mythic" and spec.Rarity ~= "Eternal" and not owned[spec.Id]
			owned[spec.Id] = true
		end
		flag("daily_world2_never_above_legendary", capped and Daily.GuaranteedPick(owned, 2) == nil)
		local none = Daily.GuaranteedPick({}, 1)
		flag("daily_world1_rarest", none ~= nil and none.Id == "jk_strongest", none and none.Id)
		local second = Daily.GuaranteedPick({ jk_strongest = true }, 1)
		local want = rarest(1, function(spec)
			return spec.Id ~= "jk_strongest"
		end)
		flag("daily_world1_unchanged", second == want, second and second.Id)
	end)

	section("pity_tier", function()
		local Cfg = require(Shared.SidekickConfig)
		local M, L = Cfg.PityCount - 1, Cfg.LegendaryPityCount - 1
		local common, rare = { Rarity = "Common" }, { Rarity = "Rare" }
		local legendary, mythic = { Rarity = "Legendary" }, { Rarity = "Mythic" }
		local all = { common, rare, legendary, mythic }
		flag("pity_none", Cfg.DueTier(M - 1, L - 1, all) == nil)
		flag("pity_mythic_first", Cfg.DueTier(M, L, all) == "Mythic")
		flag("pity_legendary", Cfg.DueTier(M - 1, L, all) == "Legendary")
		flag("pity_no_mythic_rows", Cfg.DueTier(M, L, { common, legendary }) == "Legendary")
		flag("pity_mythic_only_due", Cfg.DueTier(M, 0, { common, legendary }) == nil)
		flag("pity_no_rows", Cfg.DueTier(M, L, { common, rare }) == nil)
	end)

	section("world1_unchanged", function()
		-- The committed World 1 cast, walked as GachaConfig.Roll always did: rarest first, the catch-all last.
		local regular = {}
		for _, row in CatalogTests.CAST do
			if not row.Event then
				table.insert(regular, row)
			end
		end
		table.sort(regular, function(a, b)
			return a.Chance > b.Chance
		end)
		flag("world1_index_47", #catalog.All(1) == #CatalogTests.CAST, #catalog.All(1), #CatalogTests.CAST)
		for _, luck in { 1, 30, 1e4 } do
			local odds, left, same = gacha.Odds(luck, 1), 1, true
			same = #odds == #regular
			for i, row in regular do
				local hit = i == #regular and 1 or math.min(1, luck / row.Chance)
				same = same and odds[i] ~= nil and odds[i].Spec.Id == row.Id and near(odds[i].Chance, left * hit)
				left *= 1 - hit
			end
			flag("world1_odds_luck_" .. luck, same)
		end
		-- same seed, same characters: the per-world argument changes no draw
		local a, b, same = Random.new(5), Random.new(5), true
		for _ = 1, 2000 do
			same = same and gacha.Roll(a, 50, 1) == gacha.Roll(b, 50, "rain") -- anything but a world: this place's pool
		end
		flag("world1_default_pool", same or require(Shared.WorldConfig).Id ~= 1)
	end)

	section("odds", function()
		for world = 1, 2 do
			for _, luck in { 1, 7.35, 30, 1e6, 1e20 } do
				local sum, only = 0, true
				for _, row in gacha.OddsPercents(luck, world) do
					sum += row.Percent
					only = only and row.Spec.World == world
				end
				flag(("odds_w%d_%g"):format(world, luck), math.abs(sum - 100) < 1e-9 and only, sum, 100)
			end
			local rng, only = Random.new(world), true
			for _ = 1, 5000 do
				only = only and catalog.Get(gacha.Roll(rng, 1e7, world)).World == world
			end
			flag("rolls_only_world_" .. world, only)
		end
	end)

	section("cruise", function()
		local w1, w2, starter = catalog.Get("leaf_hero"), catalog.Get("punch_psychic"), catalog.Get("starter")
		flag("cruise_eternal_780", race.Cruise(catalog.Get("punch_void"), 1, 2) == 780)
		for _, multi in { 1, 2.5, 100 } do
			flag("cruise_carry_" .. multi, near(race.Cruise(w1, multi, 2), race.Cruise(w1, multi, 1) * 0.1))
			flag("cruise_world2_full_" .. multi, race.Cruise(w2, multi, 2) == race.Cruise(w2, multi, 1))
		end
		flag("cruise_maxed_carry_80", near(race.Cruise(w1, 100, 2), 80), race.Cruise(w1, 100, 2), 80)
		flag("cruise_starter_full", race.Cruise(starter, 1, 2) == 24, race.Cruise(starter, 1, 2), 24)
		flag("cruise_saitamo_carry", near(race.Cruise(catalog.Get(catalog.EXCLUSIVE_ID), 1, 2), 35))
		flag("cruise_kami_same", race.Cruise(catalog.Get(catalog.KAMI_ID), 1, 2) == 800)
		local same = true
		for _, spec in catalog.All(1) do
			local category = race.CATEGORY_SPEED[spec.Category]
			same = same and race.Cruise(spec, 1, 1) == math.min(race.RARITY_BASE[spec.Rarity] * category, 800)
		end
		flag("cruise_world1_unchanged", same)
	end)

	section("sidekicks", function()
		local Cfg, Art = require(Shared.SidekickConfig), require(Shared.SidekickArt)
		local Rotation = require(Server.SidekickRotation)
		local list, total, rowsOk = Cfg.Lists[2], 0, #Cfg.Lists[2] == 12
		local like = {}
		for i, row in Cfg.Lists[1] do
			like[row.Rarity] = row
			rowsOk = rowsOk and row.World == 1 and row.Id == WORLD1_SIDEKICKS[i]
		end
		rowsOk = rowsOk and #Cfg.Lists[1] == #WORLD1_SIDEKICKS
		for _, row in list do
			total += row.Odds
			local same = like[row.Rarity]
			rowsOk = rowsOk and row.World == 2 and SIDEKICKS[row.Id] == row.Rarity and Cfg.Get(row.Id) == row
			for _, key in { "Odds", "Cruise", "Stamina", "Damage", "SellGems" } do
				rowsOk = rowsOk and row[key] == same[key]
			end
		end
		flag("sidekick_rows", rowsOk)
		flag("sidekick_odds_100", math.abs(total - 100) < 1e-9, total, 100)

		local saved, fake = {}, {}
		for id in SIDEKICKS do
			saved[id] = Art[id]
		end
		local function check(name, withArt)
			local only, hundred, featured, models, secrets = true, true, true, true, {}
			for slot = SLOT0, SLOT0 + SLOTS do
				local rotation, public = Rotation.For(slot, 2), Rotation.Public(slot, 2)
				local sum = 0
				for id, odds in Rotation.Odds(slot, 2) do
					sum += odds
					only = only and SIDEKICKS[id] ~= nil
				end
				hundred = hundred and math.abs(sum - 100) < 1e-9
				for _, id in public.Ids do
					only = only and SIDEKICKS[id] ~= nil
				end
				for _, choice in public.SecretChoices do
					only = only and (choice.Name == "Solara Dragon" or choice.Name == "Darknez Devill")
				end
				secrets[public.SecretId] = true
				featured = featured and rotation.Mythic[1] == (withArt and "side_general" or nil)
				models = models
					and #rotation.Legendary == (withArt and 2 or 0)
					and #rotation.Rare == (withArt and 2 or 0)
					and #rotation.Common == 3
			end
			flag(name .. "_only_its_12", only)
			flag(name .. "_odds_100", hundred)
			flag(name .. "_featured_belleon", featured)
			flag(name .. "_tiers", models)
			flag(name .. "_both_secrets", secrets.side_dragon and secrets.side_dark)
		end
		local ok, err = pcall(function()
			for id in SIDEKICKS do
				Art[id] = nil
			end
			check("rotation_no_art", false)
			for id in SIDEKICKS do
				fake[id] = { Model = 1 }
				Art[id] = fake[id]
			end
			check("rotation", true)
		end)
		for id in SIDEKICKS do
			Art[id] = saved[id]
		end
		flag("rotation_checked", ok, ok and 1 or tostring(err))

		-- World 1's rotation against the algorithm as it was, on the committed 12
		local same, old = true, true
		local function pool(rarity)
			local ids = {}
			for _, id in WORLD1_SIDEKICKS do
				if Cfg.Get(id).Rarity == rarity then
					table.insert(ids, id)
				end
			end
			return ids
		end
		for slot = SLOT0, SLOT0 + SLOTS do
			local rng, got = Random.new(slot * 1000003), Rotation.For(slot, 1)
			rng:NextInteger(1, 3) -- the Mythic draw, replaced by the featured one
			for _, tier in { "Legendary", "Rare" } do
				local ids, drawn = pool(tier), {}
				for _ = 1, 2 do
					table.insert(drawn, table.remove(ids, rng:NextInteger(1, #ids)))
				end
				same = same and H.same(got[tier], drawn)
			end
			same = same and H.same(got.Mythic, { "side_knight" }) and H.same(got.Common, pool("Common"))
			same = same and (got.Secret == "side_curse" or got.Secret == "side_fox")
			for id in Rotation.Odds(slot, 1) do
				old = old and table.find(WORLD1_SIDEKICKS, id) ~= nil
			end
		end
		flag("rotation_world1_unchanged", same)
		flag("rotation_world1_only_its_12", old)
	end)

	-- docs/OWNER_QUESTIONS.md "2026-11-24 w2-cast in game" item 1 (proposed): which models load at start
	section("models", function()
		local Service = require(Server.CharacterModelService)
		local world1, world2, common = true, true, true
		for _, spec in require(Shared.CharacterCatalog).Everything() do
			local shared = spec.Id == "sea_captain" or spec.Id == "leaf_hero" or spec.Id == "db_hero"
			world1 = world1 and Service.Eager(spec.Id, 1) == (spec.World == 1)
			world2 = world2 and Service.Eager(spec.Id, 2) == (spec.World == 2 or shared)
		end
		for _, id in { "punch_hero", "leaf_hero", "sea_captain", "db_hero", "foe_sea" } do
			common = common and Service.Eager(id, 1) and Service.Eager(id, 2)
		end
		flag("models_world1_eager", world1)
		flag("models_world2_eager", world2)
		flag("models_shared_in_both", common)
		local sides = true
		for world, list in require(Shared.SidekickConfig).Lists do
			for _, row in list do
				sides = sides and Service.EagerSidekick(row.Id, world) and not Service.EagerSidekick(row.Id, 3 - world)
			end
		end
		flag("sidekick_models_per_world", sides)
		flag("boss_drops_in_both", Service.EagerSidekick("side_raga", 1) and Service.EagerSidekick("side_raga", 2))
	end)

	section("saves", function()
		local GachaService, SidekickService = require(Server.GachaService), require(Server.SidekickService)
		local WorldSave = require(Shared.WorldSave)
		local p = H.player(cleanup, UID)
		GachaService.Setup(p)
		local ids = { "future_hero", "leaf_hero", "punch_rider", "saw_hero", "sea_navigator" } -- sorted, as Snapshot writes
		GachaService.Apply(p, {
			Cars = ids,
			Copies = { punch_rider = 3, leaf_hero = 2, future_hero = 1 },
			Team = { "saw_hero", "leaf_hero", "future_hero" },
			Rolls = 9,
		})
		local out = GachaService.Snapshot(p)
		flag("save_keeps_every_id", H.same(out.Cars, ids))
		flag(
			"save_keeps_copies",
			out.Copies.punch_rider == 3 and out.Copies.leaf_hero == 2 and out.Copies.future_hero == 1
		)
		flag("team_mixes_worlds", H.same(out.Team, { "saw_hero", "leaf_hero" }), table.concat(out.Team, ","))
		flag("index_shared", GachaService.UniqueCount(p) == 4, GachaService.UniqueCount(p), 4)
		local bag = {}
		for i, id in { "side_chain", "side_general", "side_future", "side_raga" } do
			bag[i] = { Id = id, Entry = "e" .. i }
		end
		SidekickService.Apply(p, { Sidekicks = bag, CharacterGear = { leaf_hero = "e2", saw_hero = "e1" } })
		local side = SidekickService.Snapshot(p)
		local kept = #side.Sidekicks == 4
		for i, row in side.Sidekicks do
			kept = kept and row.Id == bag[i].Id and row.Entry == bag[i].Entry
		end
		flag("save_keeps_sidekicks", kept)
		flag("sidekick_gain_any_world", near(SidekickService.CruiseMulti(p, "leaf_hero"), 1.15))
		-- World 2 play never touches World 1's team; a first entry has no team, which Apply turns into the starter
		local record = { Cars = ids, Team = { "leaf_hero" }, Equipped = "leaf_hero", BestTrack = 10 }
		local folded = WorldSave.Fold({ Cars = ids, Team = { "punch_rider" }, BestTrack = 2 }, record, 2)
		flag("fold_keeps_cast", H.same(folded.Cars, ids) and H.same(folded.Worlds.W2.Team, { "punch_rider" }))
		local fresh = H.player(cleanup, UID + 1)
		GachaService.Setup(fresh)
		GachaService.Apply(fresh, WorldSave.View(record, 2))
		flag("fresh_world2_team_starter", fresh:GetAttribute("Team") == "starter", fresh:GetAttribute("Team"))
	end)

	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
