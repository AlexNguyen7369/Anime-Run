--!nonstrict
-- BRIEF: design doc 4.36, docs/SIDEKICK_SPEC.md (owner 2026-11-04). Server part of Sidekicks: summons, bag, auto-sell,
-- free summon, per-character equip, run gain, saves (PlayerData VERSION 15). Gem packs and followers are not covered.
-- Numbers are placeholders, so they are always read from Shared/SidekickConfig.
-- Contract these tests assume beyond the brief:
--   Odds is a percent (60 = 60%). Cruise and Stamina are fractions (0.08 = +8%): each multi is 1 + the worn row's value.
--   Summon and GrantFreeSummon return true, results (array of tables with .Id) or false, reason (string).
--   Sell, SetAutoSell and Equip return a true / false first value. Roll may return the row or its id.
--   Snapshot returns exactly the save fields, pity counts included; SidekickAutoSell maps rarity to true; Apply takes the whole save record.
--   Any remote cooldown lives on SidekickService.REMOTE_COOLDOWN, as in QuestService.
--   The clock is held in one slot; real summons are judged against that slot's Rotation.Odds. SidekickRotationTests holds the rotation.
-- Runs on Folder players and an isolated PlayerData clone, like GemTests.
-- On demand: ReplicatedStorage attributes CarTestOnly = "sidekicks", then CarTestRun = true.
local HttpService = game:GetService("HttpService")
local H = require(script.Parent.AcceptanceSupport)
local Shared = game:GetService("ReplicatedStorage").Shared
local Server = script.Parent.Parent
local Tests = {}
local UID = 990136000
local VERSION = 18 -- 18: BossCredit (BossPaidTests); 17: pity (SidekickPityTests); 16: Relics (RelicTests)
local CLOCK = 1800000123 -- one fixed rotation slot for the whole scenario
-- Design doc section 5: the real names no id or name may show, from each docs/char_evidence/side_*.md "Based on" line.
local SOURCE_NAMES = {
	"pochita",
	"igris",
	"kaisel",
	"beru",
	"kasugai",
	"rika",
	"divine dog",
	"divine dogs",
	"star platinum",
	"kurama",
	"hawk",
	"ryuk",
	"chopper",
	"mahoraga",
}

local function gems(p)
	return tonumber(p:GetAttribute("Gems")) or 0
end

local function approx(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

function Tests.sidekicks()
	local r, flag = H.report("sidekicks")
	local gacha, Admin, Quest = require(Server.GachaService), require(Server.AdminService), require(Server.QuestService)
	local GachaConfig = require(Shared.GachaConfig)
	local oldLuck, oldRoll, oldConfigRoll, oldStudio = gacha.Luck, gacha.Roll, GachaConfig.Roll, Admin.AllowStudio
	local rebirth = require(Server.RebirthService)
	local oldRebirthCooldown = rebirth.REMOTE_COOLDOWN
	local S, oldCooldown, oldIsVip
	local cleanup, runs = {}, {}
	local ok, err = xpcall(function()
		local Cfg = require(Shared.SidekickConfig)
		S = require(Server.SidekickService)
		oldCooldown, oldIsVip = S.REMOTE_COOLDOWN, S.IsVip
		S.REMOTE_COOLDOWN = 0
		rebirth.REMOTE_COOLDOWN = 0
		local Rotation = require(Server.SidekickRotation)
		S.SetClock(function()
			return CLOCK
		end)
		local slotOdds = Rotation.Odds(Rotation.Slot(CLOCK))
		Admin.AllowStudio = true
		local RaceService, money = require(Server.RaceService), require(Server.MoneyService)
		local factory, catalog = require(Shared.RunnerFactory), require(Shared.CharacterCatalog)
		local npc, npcConfig = require(Shared.NpcRacer), require(Shared.NpcConfig)
		local RaceConfig, StaminaConfig = require(Shared.RaceConfig), require(Shared.StaminaConfig)
		local RebirthConfig, BoostConfig = require(Shared.RebirthConfig), require(Shared.BoostConfig)
		local List = Cfg.List
		local rowOf = {}
		for _, row in List do
			rowOf[row.Id] = row
		end

		-- Catalog: odds, names, movement and sell values (design doc 4.36 and section 6).
		local odds = 0
		for _, row in List do
			odds += row.Odds
			flag("movement_valid_" .. row.Id, row.Movement == "Walk" or row.Movement == "Fly")
		end
		local allRows = table.clone(List)
		table.move(Cfg.BossDrops, 1, #Cfg.BossDrops, #allRows + 1, allRows)
		flag("catalog_has_13", #allRows == 13, #allRows, 13)
		for _, row in allRows do
			local text = string.lower(row.Id .. " " .. row.Name)
			local clean = require(script.Parent.CatalogTests).realNameIn(string.lower(row.Id)) == nil
				and require(script.Parent.CatalogTests).realNameIn(string.lower(row.Name)) == nil
			for _, name in SOURCE_NAMES do
				-- Whole words, lowercased: "Hawke" is the intended tweak of "Hawk"; "side_hawk" and "Hawk" still fail.
				clean = clean and string.find(text, "%f[%a]" .. name .. "%f[%A]") == nil
			end
			flag("no_real_name_" .. row.Id, clean)
			-- Design doc 4.36: "well under a summon's cost", read as at most 60% of it.
			flag(
				"sells_well_under_cost_" .. row.Id,
				row.SellGems > 0 and row.SellGems <= 0.6 * Cfg.SummonCost,
				row.SellGems,
				0.6 * Cfg.SummonCost
			)
		end
		flag("odds_sum_100", approx(odds, 100), odds, 100)
		flag("config_costs_positive", Cfg.SummonCost > 0 and Cfg.TenCost > 0 and Cfg.BagSize >= 10)
		flag("config_unlock_positive", Cfg.UnlockRebirth >= 1, Cfg.UnlockRebirth)
		flag("kaizel_flies", rowOf.side_wyvern ~= nil and rowOf.side_wyvern.Movement == "Fly")

		-- Clone only PlayerData so SetStore never redirects the live player's autosaves.
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestSidekickData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local store = H.store()
		data.SetStore(store)

		local nextId = UID
		local function loaded(saved)
			nextId += 1
			store.data[data.KeyFor(nextId)] = saved
			local p = H.player(cleanup, nextId)
			return p, nextId, data.Load(p, nextId)
		end
		local function unlocked()
			local p, id = loaded(nil)
			p:SetAttribute("RebirthLevel", Cfg.UnlockRebirth)
			return p, id
		end

		local function snap(p)
			return S.Snapshot(p)
		end
		local function entries(p)
			return snap(p).Sidekicks or {}
		end
		local function gear(p)
			return snap(p).CharacterGear or {}
		end
		local function state(p)
			return { H.copy(snap(p)), gems(p) }
		end
		local function unchanged(p, before)
			return H.same(state(p), before)
		end
		local function has(p, entry)
			for _, item in entries(p) do
				if item.Entry == entry then
					return true
				end
			end
			return false
		end
		-- Summons 1x with exact Gems until the bag holds n. Needs no auto-sell on.
		local function fill(p, n)
			for _ = #entries(p) + 1, n do
				p:SetAttribute("Gems", Cfg.SummonCost)
				S.Summon(p, 1)
			end
			p:SetAttribute("Gems", 0)
		end
		-- Grants one Sidekick of `id` through /sidekick and returns its new entry value.
		local function grant(p, id)
			local seen = {}
			for _, item in entries(p) do
				seen[item.Entry] = true
			end
			Admin.Run(p, "/sidekick " .. id)
			for _, item in entries(p) do
				if item.Id == id and not seen[item.Entry] then
					return item.Entry
				end
			end
			return nil
		end
		local function autoSellAll(p)
			for _, row in List do
				S.SetAutoSell(p, row.Rarity, true)
			end
		end
		local function soldValue(results, rarity)
			local value, count = 0, 0
			for _, result in results do
				local row = rowOf[result.Id]
				if rarity == nil or row.Rarity == rarity then
					value += row.SellGems
					count += 1
				end
			end
			return value, count
		end

		local chars = {}
		for _, spec in catalog.All() do
			if spec.Rollable and spec.Id ~= catalog.STARTER_ID then
				table.insert(chars, spec.Id)
			end
		end
		local charA, charB, charC, charUnowned = chars[1], chars[2], chars[3], chars[4]
		flag("test_has_four_characters", charUnowned ~= nil)
		local function dressed(p)
			gacha.Grant(p, charA)
			gacha.Grant(p, charB)
			gacha.Grant(p, charC)
		end

		-- Luck independence: Roll is pure and reads only the list it is given.
		local function idOf(result)
			return type(result) == "table" and result.Id or result
		end
		local function sequence(seed)
			local rng, out = Random.new(seed), {}
			for i = 1, 200 do
				out[i] = idOf(Cfg.Roll(rng, List))
			end
			return out
		end
		local plainRolls = sequence(4242)
		local lucky = unlocked()
		dressed(lucky)
		lucky:SetAttribute("AdminLuck", 1e6)
		lucky:SetAttribute("RebirthLevel", RebirthConfig.MAX_LEVEL)
		lucky:SetAttribute("BoostUntil_" .. BoostConfig.ItemsFor("Luck")[1].Id, os.time() + 3600)
		flag("luck_setup_real", gacha.Luck(lucky) > 1e6, gacha.Luck(lucky))
		flag("roll_same_with_luck_same_seed", H.same(sequence(4242), plainRolls))
		local only = { List[#List] }
		flag("roll_reads_passed_list", idOf(Cfg.Roll(Random.new(1), only)) == List[#List].Id)

		local tally, rollRng = {}, Random.new(777)
		local ROLLS = 20000
		for _ = 1, ROLLS do
			local id = idOf(Cfg.Roll(rollRng, List))
			tally[id] = (tally[id] or 0) + 1
		end
		for _, row in List do
			local share = (tally[row.Id] or 0) / ROLLS * 100
			flag("roll_matches_odds_" .. row.Id, math.abs(share - row.Odds) < 1.5, share, row.Odds)
		end

		-- Real summons at huge luck: the rate stays the listed odds, and no luck or roll path is touched.
		local touched = 0
		local function touch(original)
			return function(...)
				touched += 1
				return original(...)
			end
		end
		lucky:SetAttribute("Rolls", 7)
		lucky:SetAttribute("TurboCount", 3)
		local questBefore = H.copy(Quest.Snapshot(lucky))
		autoSellAll(lucky)
		lucky:SetAttribute("Gems", 1000 * Cfg.TenCost)
		gacha.Luck, gacha.Roll, GachaConfig.Roll = touch(oldLuck), touch(oldRoll), touch(oldConfigRoll)
		local summonTally, summons = {}, 0
		local summonsOk = true
		for _ = 1, 1000 do
			local fine, results = S.Summon(lucky, 10)
			summonsOk = summonsOk and fine == true
			for _, result in (fine and results or {}) do
				summonTally[result.Id] = (summonTally[result.Id] or 0) + 1
				summons += 1
			end
		end
		S.GrantFreeSummon(lucky)
		gacha.Luck, gacha.Roll, GachaConfig.Roll = oldLuck, oldRoll, oldConfigRoll
		flag("luck_summons_ran", summonsOk and summons == 10000, summons, 10000)
		for _, row in List do
			local share = (summonTally[row.Id] or 0) / math.max(summons, 1) * 100
			local want = slotOdds[row.Id]
			flag(
				"luck_summon_odds_" .. row.Id,
				want ~= nil and math.abs(share - want) < 3 or want == nil and share == 0,
				share,
				want or 0
			)
		end
		flag("summon_never_touches_luck_or_roll", touched == 0, touched, 0)
		flag("summon_keeps_rolls", lucky:GetAttribute("Rolls") == 7, lucky:GetAttribute("Rolls"), 7)
		flag("summon_keeps_turbo", lucky:GetAttribute("TurboCount") == 3, lucky:GetAttribute("TurboCount"), 3)
		flag("summon_keeps_quests", H.same(Quest.Snapshot(lucky), questBefore))

		-- Big Raga: a boss drop only (owner 2026-11-05, docs/SIDEKICK_SPEC.md). 30 is its spec's sell value.
		local raga = Cfg.Get("side_raga")
		flag("raga_in_get", raga ~= nil and raga.Name == "Big Raga" and raga.Rarity == "Secret")
		flag("raga_in_boss_drops", Cfg.BossDrops ~= nil and Cfg.BossDrops[1] == raga)
		flag("raga_not_in_list", rowOf.side_raga == nil)
		flag("raga_sells_for_spec", raga ~= nil and raga.SellGems == 30, raga and raga.SellGems, 30)
		local catalogTests = require(script.Parent.CatalogTests)
		flag(
			"no_real_name_side_raga",
			raga ~= nil
				and catalogTests.realNameIn("side_raga") == nil
				and catalogTests.realNameIn(string.lower(raga.Name)) == nil
		)
		local pool = unlocked()
		autoSellAll(pool)
		local pooled, ragaSummons, poolOk = 0, 0, true
		for _ = 1, 200 do
			pool:SetAttribute("Gems", Cfg.TenCost)
			local fine, results = S.Summon(pool, 10)
			poolOk = poolOk and fine == true
			for _, result in (fine and results or {}) do
				pooled += 1
				ragaSummons += result.Id == "side_raga" and 1 or 0
			end
		end
		flag("raga_pool_summons_ran", poolOk and pooled == 2000, pooled, 2000)
		flag("raga_never_summoned", ragaSummons == 0, ragaSummons, 0)
		local holder = unlocked()
		dressed(holder)
		local ragaEntry = grant(holder, "side_raga")
		flag("raga_granted_to_bag", ragaEntry ~= nil and has(holder, ragaEntry))
		flag("raga_equips", ragaEntry ~= nil and S.Equip(holder, charA, ragaEntry) == true)
		flag("raga_cruise_gain", raga ~= nil and approx(S.CruiseMulti(holder, charA), 1 + raga.Cruise))
		flag("raga_stamina_gain", raga ~= nil and approx(S.StaminaMulti(holder, charA), 1 + raga.Stamina))
		flag("raga_worn_not_sold", S.Sell(holder, ragaEntry) == false and has(holder, ragaEntry))
		S.Equip(holder, charA, nil)
		holder:SetAttribute("Gems", 0)
		flag("raga_sells", S.Sell(holder, ragaEntry) == true and not has(holder, ragaEntry))
		flag("raga_sell_value_is_30", raga ~= nil and raga.SellGems == 30, raga and raga.SellGems, 30)
		flag("raga_sell_pays_spec", raga ~= nil and gems(holder) == raga.SellGems, gems(holder), raga and raga.SellGems)

		-- VIP pays 10% fewer Gems (design doc 4.36). IsVip is a marked shortcut, always false until the monetization branch merges.
		local priced = unlocked()
		flag("cost_1", S.CostFor(priced, 1) == 50, S.CostFor(priced, 1), 50)
		flag("cost_10", S.CostFor(priced, 10) == 500, S.CostFor(priced, 10), 500)
		S.IsVip = function()
			return true
		end
		flag("vip_cost_1", S.CostFor(priced, 1) == 45, S.CostFor(priced, 1), 45)
		flag("vip_cost_10", S.CostFor(priced, 10) == 450, S.CostFor(priced, 10), 450)
		priced:SetAttribute("Gems", 48)
		flag("vip_summon_ok", (S.Summon(priced, 1)) == true)
		flag("vip_summon_spends_45", gems(priced) == 3, gems(priced), 3)
		S.IsVip = oldIsVip

		-- Costs and unlock.
		for _, kind in { { 1, Cfg.SummonCost }, { 10, Cfg.TenCost } } do
			local count, cost = kind[1], kind[2]
			local p = unlocked()
			p:SetAttribute("Gems", cost + 3)
			local fine, results = S.Summon(p, count)
			flag("summon_ok_" .. count, fine == true)
			flag("summon_spends_" .. count, gems(p) == 3, gems(p), 3)
			flag("summon_adds_" .. count, #entries(p) == count, #entries(p), count)
			flag("summon_results_" .. count, type(results) == "table" and #results == count)
			local known = true
			for _, result in results or {} do
				known = known and slotOdds[result.Id] ~= nil
			end
			flag("summon_results_known_" .. count, known)

			local broke = unlocked()
			broke:SetAttribute("Gems", cost - 1)
			local before = state(broke)
			local refused, reason = S.Summon(broke, count)
			flag("poor_refused_" .. count, refused == false and type(reason) == "string")
			flag("poor_no_change_" .. count, unchanged(broke, before))

			local early = unlocked()
			early:SetAttribute("RebirthLevel", Cfg.UnlockRebirth - 1)
			early:SetAttribute("Gems", cost)
			before = state(early)
			refused, reason = S.Summon(early, count)
			flag("locked_refused_" .. count, refused == false and type(reason) == "string")
			flag("locked_no_change_" .. count, unchanged(early, before))
		end

		-- Bag: room is checked for everything a summon would add, after auto-sell.
		local full = unlocked()
		fill(full, Cfg.BagSize)
		flag("bag_filled", #entries(full) == Cfg.BagSize, #entries(full), Cfg.BagSize)
		full:SetAttribute("Gems", Cfg.TenCost)
		local before = state(full)
		flag("bag_full_refuses_1", (S.Summon(full, 1)) == false)
		flag("bag_full_refuses_10", (S.Summon(full, 10)) == false)
		flag("bag_full_no_change", unchanged(full, before))

		local nearly = unlocked()
		fill(nearly, Cfg.BagSize - 9)
		nearly:SetAttribute("Gems", Cfg.TenCost)
		before = state(nearly)
		flag("bag_nine_free_refuses_10", (S.Summon(nearly, 10)) == false)
		flag("bag_nine_free_no_change", unchanged(nearly, before))

		local exact = unlocked()
		fill(exact, Cfg.BagSize - 10)
		exact:SetAttribute("Gems", Cfg.TenCost)
		flag("bag_ten_free_allows_10", (S.Summon(exact, 10)) == true and #entries(exact) == Cfg.BagSize)

		-- Auto-sell: off by default; a sold result pays SellGems and adds nothing, so it may make the room.
		for _, row in List do
			flag("auto_sell_off_by_default_" .. row.Rarity, (snap(full).SidekickAutoSell or {})[row.Rarity] ~= true)
		end
		autoSellAll(full)
		local count = #entries(full)
		for _, n in { { 1, Cfg.SummonCost }, { 10, Cfg.TenCost } } do
			full:SetAttribute("Gems", n[2])
			local fine, results = S.Summon(full, n[1])
			flag("auto_sell_makes_room_" .. n[1], fine == true and #entries(full) == count)
			local value = fine and soldValue(results) or -1
			flag("auto_sell_pays_" .. n[1], gems(full) == value, gems(full), value)
		end

		local mixed = unlocked()
		local soldRarity = List[1].Rarity
		flag("auto_sell_set", S.SetAutoSell(mixed, soldRarity, true) == true)
		flag("auto_sell_saved", snap(mixed).SidekickAutoSell[soldRarity] == true)
		mixed:SetAttribute("Gems", 5 * Cfg.TenCost)
		local paid, sold, all = 0, 0, 0
		for _ = 1, 5 do
			local fine, results = S.Summon(mixed, 10)
			if fine then
				local value, n = soldValue(results, soldRarity)
				paid, sold, all = paid + value, sold + n, all + #results
			end
		end
		flag("mixed_saw_both", sold > 0 and sold < all and all == 50, sold, all)
		flag("mixed_pays_only_sold", gems(mixed) == paid, gems(mixed), paid)
		flag("mixed_adds_only_kept", #entries(mixed) == all - sold, #entries(mixed), all - sold)
		local noSoldKept = true
		for _, item in entries(mixed) do
			noSoldKept = noSoldKept and rowOf[item.Id].Rarity ~= soldRarity
		end
		flag("mixed_keeps_no_sold_rarity", noSoldKept)

		-- With one free slot and partial auto-sell the outcome is random; either way the rule holds.
		local tight = unlocked()
		fill(tight, Cfg.BagSize - 1)
		S.SetAutoSell(tight, soldRarity, true)
		tight:SetAttribute("Gems", Cfg.TenCost)
		local tightSave, holds = H.copy(snap(tight)), true
		for _ = 1, 40 do
			local start = state(tight)
			local fine, results = S.Summon(tight, 10)
			if fine then
				local value, n = soldValue(results, soldRarity)
				holds = holds and #entries(tight) == Cfg.BagSize - 1 + (10 - n) and gems(tight) == value
				holds = holds and 10 - n <= 1
			else
				holds = holds and unchanged(tight, start)
			end
			S.Apply(tight, H.copy(tightSave))
			tight:SetAttribute("Gems", Cfg.TenCost)
		end
		flag("partial_auto_sell_room_rule", holds)

		-- Hand sell.
		local seller = unlocked()
		dressed(seller)
		local keep, spare = grant(seller, List[1].Id), grant(seller, List[#List].Id)
		flag("admin_grant_gives_entries", keep ~= nil and spare ~= nil)
		flag("sell_ok", S.Sell(seller, spare) == true)
		flag("sell_pays", gems(seller) == List[#List].SellGems, gems(seller), List[#List].SellGems)
		flag("sell_removes", not has(seller, spare) and has(seller, keep))
		before = state(seller)
		flag("sell_twice_refused", S.Sell(seller, spare) == false and unchanged(seller, before))

		-- Never sold while equipped: not by hand, not by auto-sell.
		flag("equip_for_sell_ok", S.Equip(seller, charA, keep) == true)
		before = state(seller)
		flag("sell_equipped_refused", S.Sell(seller, keep) == false and unchanged(seller, before))
		autoSellAll(seller)
		seller:SetAttribute("Gems", Cfg.TenCost)
		S.Summon(seller, 10)
		flag("auto_sell_spares_equipped", has(seller, keep) and gear(seller)[charA] == keep)
		S.Equip(seller, charA, nil)
		flag("sell_after_take_off_ok", S.Sell(seller, keep) == true and not has(seller, keep))

		-- Free summon: once, no Gems, needs room, and a refusal does not use it up.
		local free = unlocked()
		flag("free_starts_unused", snap(free).SidekickFreeUsed ~= true)
		local fine, results = S.GrantFreeSummon(free)
		flag("free_works_with_no_gems", fine == true and type(results) == "table" and #results == 1)
		flag("free_adds_one_spends_none", #entries(free) == 1 and gems(free) == 0)
		flag("free_marks_used", snap(free).SidekickFreeUsed == true)
		before = state(free)
		flag("free_twice_refused", (S.GrantFreeSummon(free)) == false and unchanged(free, before))

		local freeFull = unlocked()
		fill(freeFull, Cfg.BagSize)
		before = state(freeFull)
		flag("free_full_bag_refused", (S.GrantFreeSummon(freeFull)) == false and unchanged(freeFull, before))
		S.Sell(freeFull, entries(freeFull)[1].Entry)
		freeFull:SetAttribute("Gems", 0)
		flag("free_kept_after_refusal", (S.GrantFreeSummon(freeFull)) == true)

		-- Past-unlock saves with no flag get it too (spec "Summons").
		local veteran = loaded({ Version = 14, RebirthLevel = RebirthConfig.MAX_LEVEL })
		flag("free_for_old_saves", (S.GrantFreeSummon(veteran)) == true)

		-- Equip: keyed per character; one entry per character, one character per entry.
		local wearer = unlocked()
		dressed(wearer)
		local e1, e2 = grant(wearer, List[1].Id), grant(wearer, List[2].Id)
		flag("equip_ok", S.Equip(wearer, charA, e1) == true and gear(wearer)[charA] == e1)
		flag("equip_move_ok", S.Equip(wearer, charB, e1) == true)
		flag("equip_move_clears_old", gear(wearer)[charA] == nil and gear(wearer)[charB] == e1)
		flag("equip_replace_ok", S.Equip(wearer, charB, e2) == true and gear(wearer)[charB] == e2)
		flag("equip_replace_frees_old", has(wearer, e1) and gear(wearer)[charA] == nil)
		flag("equip_second_character_ok", S.Equip(wearer, charA, e1) == true)
		flag("equip_two_different", gear(wearer)[charA] == e1 and gear(wearer)[charB] == e2)
		before = state(wearer)
		flag("equip_unowned_character_refused", S.Equip(wearer, charUnowned, e1) == false and unchanged(wearer, before))
		flag("equip_unknown_character_refused", S.Equip(wearer, "no_such", e1) == false and unchanged(wearer, before))
		flag(
			"equip_unowned_entry_refused",
			S.Equip(wearer, charC, "no_such_entry") == false and unchanged(wearer, before)
		)
		local stranger = unlocked()
		dressed(stranger)
		local sold3 = grant(stranger, List[1].Id)
		S.Sell(stranger, sold3)
		before = state(stranger)
		flag("equip_sold_entry_refused", S.Equip(stranger, charA, sold3) == false and unchanged(stranger, before))
		flag("equip_take_off", S.Equip(wearer, charA, nil) == true and gear(wearer)[charA] == nil)
		flag("equip_take_off_keeps_entry", has(wearer, e1) and gear(wearer)[charB] == e2)

		-- Run gain: 1 with none; every row's gain on its wearer only.
		local runner = loaded(nil) -- rebirth 0: the speed multi is exactly 1 before the Sidekick
		dressed(runner)
		flag("multi_none_cruise", S.CruiseMulti(runner, charA) == 1)
		flag("multi_none_stamina", S.StaminaMulti(runner, charA) == 1)
		flag("multi_junk_character", S.CruiseMulti(runner, 5) == 1 and S.StaminaMulti(runner, nil) == 1)
		local baseCruise = gacha.CruiseFor(runner, charA)
		local byCruise, byStamina = List[1], List[1]
		for _, row in List do
			local entry = grant(runner, row.Id)
			S.Equip(runner, charA, entry)
			local cruise, stamina = 1 + (row.Cruise or 0), 1 + (row.Stamina or 0)
			flag(
				"multi_cruise_" .. row.Id,
				approx(S.CruiseMulti(runner, charA), cruise),
				S.CruiseMulti(runner, charA),
				cruise
			)
			flag(
				"multi_stamina_" .. row.Id,
				approx(S.StaminaMulti(runner, charA), stamina),
				S.StaminaMulti(runner, charA),
				stamina
			)
			flag(
				"multi_other_character_" .. row.Id,
				S.CruiseMulti(runner, charB) == 1 and S.StaminaMulti(runner, charB) == 1
			)
			flag(
				"cruise_for_" .. row.Id,
				approx(gacha.CruiseFor(runner, charA), baseCruise * cruise),
				gacha.CruiseFor(runner, charA),
				baseCruise * cruise
			)
			S.Equip(runner, charA, nil)
			if (row.Cruise or 0) > (byCruise.Cruise or 0) then
				byCruise = row
			end
			if (row.Stamina or 0) > (byStamina.Stamina or 0) then
				byStamina = row
			end
		end
		flag("catalog_has_both_gains", (byCruise.Cruise or 0) > 0 and (byStamina.Stamina or 0) > 0)
		flag("cruise_back_after_take_off", approx(gacha.CruiseFor(runner, charA), baseCruise))

		-- Just under the cap with no Sidekick; the Sidekick's gain stops at MAX_CRUISE.
		local capped = loaded(nil)
		dressed(capped)
		local points = math.floor((RaceConfig.MAX_CRUISE / baseCruise - 1) / RaceConfig.SPEED_PER_POINT) - 1
		capped:SetAttribute("Alloc_Speed", points)
		local below = gacha.CruiseFor(capped, charA)
		flag("cap_setup_below", below < RaceConfig.MAX_CRUISE, below, RaceConfig.MAX_CRUISE)
		flag("cap_setup_gain_crosses", below * (1 + byCruise.Cruise) > RaceConfig.MAX_CRUISE)
		S.Equip(capped, charA, grant(capped, byCruise.Id))
		local worn = gacha.CruiseFor(capped, charA)
		flag("cruise_capped_when_worn", worn == RaceConfig.MAX_CRUISE, worn, RaceConfig.MAX_CRUISE)

		-- Stamina reaches a real run's snapshot, on the wearer's slot only.
		local points3 = {}
		for i = 0, 2 do
			table.insert(points3, Vector3.new(0, 2000, -i * 20))
		end
		local path = { Waypoints = points3, Curvature = { 0, 0, 0 }, Length = 40 }
		local route = {
			Path = { WorldWaypoints = points3, Curvature = { 0, 0, 0 }, Width = 40, Closed = false },
			Pads = {},
			Tracks = {
				{
					Number = 1,
					StartIndex = 1,
					FinishIndex = 3,
					Npc = { Config = npcConfig.For(1), Path = path, Profile = npc.Profile(path, 1) },
				},
			},
		}
		local function runSeconds(p)
			local car = factory.build(charA)
			car.Name, car.Parent = "CarTestSidekickRunner", p
			local run = RaceService.NewRun(car, route, p, { Npc = true, StartTrack = 1, NpcSpeeds = { [1] = 0.001 } })
			table.insert(runs, run)
			local s1, s2 = p:GetAttribute("RunSeconds1"), p:GetAttribute("RunSeconds2")
			run:Destroy()
			return s1, s2
		end
		local athlete = loaded(nil)
		dressed(athlete)
		flag("team_set", gacha.SetTeam(athlete, { charA, charB }) == true)
		local staminaBase = gacha.StaminaMulti(athlete)
		local wantA = StaminaConfig.Seconds(catalog.Get(charA), staminaBase)
		local wantB = StaminaConfig.Seconds(catalog.Get(charB), staminaBase)
		local s1, s2 = runSeconds(athlete)
		flag("run_stamina_plain", approx(s1, wantA) and approx(s2, wantB), s1, wantA)
		S.Equip(athlete, charA, grant(athlete, byStamina.Id))
		local gain = 1 + byStamina.Stamina
		s1, s2 = runSeconds(athlete)
		flag("run_stamina_worn_slot", approx(s1, wantA * gain), s1, wantA * gain)
		flag("run_stamina_other_slot", approx(s2, wantB), s2, wantB)

		-- Client junk reaches the service unchanged, so the service refuses it (every remote passes through here).
		local target = unlocked()
		dressed(target)
		local entry = grant(target, List[1].Id)
		target:SetAttribute("Gems", 100 * Cfg.TenCost)
		S.Equip(target, charA, entry)
		before = state(target)
		local function refused(label, fn, ...)
			local ran, result = pcall(fn, target, ...)
			flag("junk_refused_" .. label, ran and result == false, tostring(result))
			flag("junk_no_change_" .. label, unchanged(target, before))
		end
		for label, junk in
			{
				negative = -1,
				zero = 0,
				two = 2,
				five = 5,
				eleven = 11,
				fraction = 1.5,
				nan = 0 / 0,
				huge = math.huge,
				text = "10",
				table = {},
				bool = true,
			}
		do
			refused("count_" .. label, S.Summon, junk)
		end
		refused("count_nil", S.Summon, nil)
		for label, junk in { text = "no_such_entry", table = {}, bool = true, number = -1 } do
			refused("sell_" .. label, S.Sell, junk)
			refused("equip_entry_" .. label, S.Equip, charB, junk)
		end
		refused("sell_nil", S.Sell, nil)
		refused("equip_character_number", S.Equip, 5, entry)
		refused("equip_character_table", S.Equip, {}, entry)
		refused("auto_sell_rarity_number", S.SetAutoSell, 5, true)
		refused("auto_sell_rarity_unknown", S.SetAutoSell, "NoSuchRarity", true)
		refused("auto_sell_value_text", S.SetAutoSell, List[1].Rarity, "yes")
		refused("auto_sell_value_nil", S.SetAutoSell, List[1].Rarity, nil)

		-- Save: round trip through a real save, in a form a DataStore can hold.
		local saver, saverId = unlocked()
		dressed(saver)
		local saved1, saved2 = grant(saver, List[1].Id), grant(saver, List[#List].Id)
		S.Equip(saver, charA, saved2)
		S.SetAutoSell(saver, soldRarity, true)
		S.GrantFreeSummon(saver)
		local want = H.copy(snap(saver))
		flag("save_ok", data.Save(saver, saverId, true) == true)
		local record = store.data[data.KeyFor(saverId)]
		flag("save_version", record.Version == VERSION, record.Version, VERSION)
		flag("save_entries", H.same(record.Sidekicks, want.Sidekicks))
		flag("save_gear", record.CharacterGear[charA] == saved2)
		flag("save_auto_sell", record.SidekickAutoSell[soldRarity] == true)
		flag("save_free_used", record.SidekickFreeUsed == true)
		for _, field in { "Sidekicks", "CharacterGear", "SidekickAutoSell" } do
			local decoded = HttpService:JSONDecode(HttpService:JSONEncode(record[field]))
			flag("save_json_safe_" .. field, H.same(decoded, record[field]))
		end
		local again, _, againOk = loaded(H.copy(record))
		flag("round_trip_keeps", againOk == true and H.same(snap(again), want))
		flag(
			"round_trip_has_entry",
			has(again, saved1) and approx(S.CruiseMulti(again, charA), 1 + (List[#List].Cruise or 0))
		)

		local function sidekickFields(p)
			local s = snap(p)
			return #(s.Sidekicks or {}), next(s.CharacterGear or {}), next(s.SidekickAutoSell or {}), s.SidekickFreeUsed
		end
		local function isEmpty(p)
			local n, g, a, f = sidekickFields(p)
			return n == 0 and g == nil and a == nil and f ~= true
		end
		local missing, _, missingOk = loaded({ Version = 14, Money = 5 })
		flag("load_missing_empty", missingOk == true and isEmpty(missing))
		local new, _, newOk = loaded(nil)
		flag("load_new_empty", newOk == true and isEmpty(new))
		for label, junk in { text = "lots", number = 5, bool = true } do
			local bad, _, badOk = loaded({
				Version = VERSION,
				Sidekicks = junk,
				CharacterGear = junk,
				SidekickAutoSell = junk,
				SidekickFreeUsed = "yes",
			})
			flag("load_junk_clean_" .. label, badOk == true and isEmpty(bad))
		end

		-- Rows with no usable id go; a row whose Entry repeats is kept once; gear never points at nothing or doubles up.
		local real1, real2 = want.Sidekicks[1], want.Sidekicks[2]
		local dirty = loaded({
			Version = VERSION,
			Sidekicks = {
				H.copy(real1),
				H.copy(real1),
				H.copy(real2),
				1,
				"x",
				{ Id = 5, Entry = real2.Entry },
				{ Id = "", Entry = real2.Entry },
				{ Entry = real2.Entry },
			},
			CharacterGear = {
				[charA] = real1.Entry,
				[charB] = real1.Entry,
				[charC] = "no_such_entry",
				[charUnowned] = true,
			},
			SidekickAutoSell = { [soldRarity] = "yes", ["5"] = 7 },
		})
		local seenEntries, cleanRows = {}, true
		for _, item in entries(dirty) do
			cleanRows = cleanRows and type(item) == "table" and type(item.Id) == "string" and item.Id ~= ""
			cleanRows = cleanRows and item.Entry ~= nil and not seenEntries[item.Entry]
			seenEntries[item.Entry] = true
		end
		flag("load_rows_clean", cleanRows and #entries(dirty) == 2, #entries(dirty), 2)
		local holders, gearClean = 0, true
		for _, value in gear(dirty) do
			gearClean = gearClean and has(dirty, value)
			holders += value == real1.Entry and 1 or 0
		end
		flag("load_gear_points_at_entries", gearClean)
		flag("load_gear_one_holder", holders <= 1, holders, 1)
		flag("load_auto_sell_clean", (snap(dirty).SidekickAutoSell or {})[soldRarity] ~= true)

		-- An id from a newer version survives so a rollback destroys nothing: kept, worn, gives 1, not sold.
		local futureRow = H.copy(real1)
		futureRow.Id = "side_future_test"
		local future, futureId = loaded({
			Version = VERSION,
			Sidekicks = { futureRow },
			CharacterGear = { [catalog.STARTER_ID] = futureRow.Entry },
		})
		flag("unknown_id_kept", #entries(future) == 1 and entries(future)[1].Id == futureRow.Id)
		flag("unknown_id_gear_kept", gear(future)[catalog.STARTER_ID] == futureRow.Entry)
		flag("unknown_id_multi_one", S.CruiseMulti(future, catalog.STARTER_ID) == 1)
		S.Equip(future, catalog.STARTER_ID, nil)
		before = state(future)
		flag("unknown_id_not_sold", S.Sell(future, futureRow.Entry) == false and unchanged(future, before))
		data.Save(future, futureId, true)
		local futureRecord = store.data[data.KeyFor(futureId)]
		flag("unknown_id_saved", futureRecord.Sidekicks[1].Id == futureRow.Id)

		-- /sidekick grants one; /wipe resets; a rebirth keeps everything.
		local admin = unlocked()
		dressed(admin)
		flag("admin_grant_ok", Admin.Run(admin, "/sidekick " .. List[1].Id) == true)
		flag("admin_grant_one", #entries(admin) == 1 and entries(admin)[1].Id == List[1].Id)
		before = state(admin)
		flag("admin_rejects_unknown", Admin.Run(admin, "/sidekick no_such") == false and unchanged(admin, before))
		flag("admin_rejects_no_id", Admin.Run(admin, "/sidekick") == false and unchanged(admin, before))
		flag(
			"admin_rejects_unknown_player",
			Admin.Run(admin, "/sidekick " .. List[1].Id .. " NoSuchPlayerHere") == false and unchanged(admin, before)
		)
		local _, help = Admin.Run(admin, "/help")
		flag("admin_listed", string.find(help, "/sidekick", 1, true) ~= nil)

		S.Equip(admin, charA, entries(admin)[1].Entry)
		S.SetAutoSell(admin, soldRarity, true)
		S.GrantFreeSummon(admin)
		flag("wipe_ok", Admin.Run(admin, "/wipe") == true)
		flag("wipe_resets", isEmpty(admin))

		local reborn, rebornId = loaded(nil)
		dressed(reborn)
		reborn:SetAttribute("RebirthLevel", Cfg.UnlockRebirth)
		S.Equip(reborn, charA, grant(reborn, List[1].Id))
		S.SetAutoSell(reborn, soldRarity, true)
		S.GrantFreeSummon(reborn)
		local keptSnap = H.copy(snap(reborn))
		money.Setup(reborn).Value = rebirth.Requirements(reborn).Money
		flag("rebirth_succeeds", rebirth.Rebirth(reborn) == true)
		flag("rebirth_keeps", H.same(snap(reborn), keptSnap))
		data.Save(reborn, rebornId, true)
		flag("rebirth_saves", H.same(store.data[data.KeyFor(rebornId)].Sidekicks, keptSnap.Sidekicks))
	end, debug.traceback)
	flag("sidekicks_completed", ok, ok and 1 or tostring(err))
	gacha.Luck, gacha.Roll, GachaConfig.Roll, Admin.AllowStudio = oldLuck, oldRoll, oldConfigRoll, oldStudio
	rebirth.REMOTE_COOLDOWN = oldRebirthCooldown
	if S then
		S.REMOTE_COOLDOWN, S.IsVip = oldCooldown, oldIsVip
		if S.SetClock then
			S.SetClock()
		end
	end
	for _, run in runs do
		pcall(run.Destroy, run)
	end
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end
return Tests
