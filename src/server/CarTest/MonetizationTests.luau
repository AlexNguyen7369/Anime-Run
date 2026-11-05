--!nonstrict
-- BRIEF: design doc 4.35, 4.36 and 6; docs/MONETIZATION_SPEC.md, docs/BAG_AND_AUTOSELL_SPEC.md. Scenarios `passes`, `odds`,
-- `bag`. Numbers are the docs' values, written here as literals. Never loosen a limit to make one pass.
-- Fake players are Folders; made-up gamepass ids are put on the catalogue and taken off again, even after an error.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local BagConfig = require(Shared.BagConfig)
local CharacterCatalog = require(Shared.CharacterCatalog)
local GachaConfig = require(Shared.GachaConfig)
local Monetization = require(Shared.MonetizationConfig)
local RaceConfig = require(Shared.RaceConfig)
local UpgradeTree = require(Shared.UpgradeTree)
local GachaService = require(Server.GachaService)
local MoneyService = require(Server.MoneyService)
local PassService = require(Server.PassService)

local TOL = 1e-9
local Tests = {}

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and a == a and math.abs(a - b) <= TOL * math.max(1, math.abs(b))
end

local function fakePlayer(name)
	local p = Instance.new("Folder")
	p.Name = name
	p.Parent = Workspace
	GachaService.Setup(p)
	PassService.Setup(p)
	return p
end

-- Always misses every rarer check, so a roll gives the catch-all.
local CATCH_ALL_ROLLER = {
	NextNumber = function()
		return 0.999999
	end,
}
local function catchAll()
	local rollable = CharacterCatalog.Rollable()
	return rollable[#rollable]
end

function Tests.passes()
	local r, flag = H.report("passes")
	local byId = {}
	for _, pass in Monetization.Gamepasses do
		byId[pass.Id] = pass
	end
	flag("passes_count_11", #Monetization.Gamepasses == 11, #Monetization.Gamepasses, 11)
	for _, id in
		{
			"vip",
			"auto_roll_2x",
			"extra_roll_1",
			"extra_roll_2",
			"money_2x",
			"luck_1",
			"luck_2",
			"dojo_master",
			"deep_stamina",
			"inventory",
			"exclusive_runner",
		}
	do
		flag("passes_has_" .. id, byId[id] ~= nil)
	end
	flag("passes_workshop_tiers_gone", not (byId.workshop_gold or byId.workshop_diamond or byId.workshop_void))
	flag("passes_exclusive_999", byId.exclusive_runner and byId.exclusive_runner.RobuxPrice == 999)

	local cleanup = {}
	local function player(name)
		local p = fakePlayer(name)
		table.insert(cleanup, p)
		return p
	end
	local ok, err = pcall(function()
		-- Ownership
		byId.money_2x.GamepassId, byId.vip.GamepassId = 990076001, 990076002
		local p = player("PassOwner")
		PassService.SetOwnerCheck(function(_, id)
			return id == 990076001
		end)
		flag("passes_refresh_answers", PassService.Refresh(p) == true)
		flag("passes_owned_set", PassService.Owns(p, "money_2x"))
		flag("passes_unowned_not_set", not PassService.Owns(p, "vip"))
		flag("passes_by_id", PassService.ById(990076002) == byId.vip)
		flag("passes_by_id_zero_is_nil", PassService.ById(0) == nil)

		PassService.SetOwnerCheck(function()
			error("store down")
		end)
		flag("passes_lookup_failure_reported", PassService.Refresh(p) == false)
		flag("passes_lookup_failure_keeps_pass", PassService.Owns(p, "money_2x"))
		flag("passes_lookup_failure_grants_nothing", not PassService.Owns(p, "vip"))

		-- Policy
		local q = player("PassPolicy")
		flag("passes_policy_default_restricted", not PassService.PaidLuckAllowed(q))
		PassService.SetPolicyRead(function()
			error("policy down")
		end)
		flag("passes_policy_failure_reported", PassService.RefreshPolicy(q) == false)
		flag("passes_policy_failure_restricted", not PassService.PaidLuckAllowed(q))
		PassService.SetPolicyRead(function()
			return { ArePaidRandomItemsRestricted = false }
		end)
		flag("passes_policy_read", PassService.RefreshPolicy(q) and PassService.PaidLuckAllowed(q))

		-- Effects: each one measured against the same player without the pass.
		local function ratio(name, pass, read, attrs)
			local e = player("PassEffect" .. name)
			for key, value in attrs or {} do
				e:SetAttribute(key, value)
			end
			local before = read(e)
			e:SetAttribute("Pass_" .. pass, true)
			return read(e) / before
		end
		local allowed = { PaidRandomRestricted = false }
		local function interval(e)
			return GachaService.RollInterval(e)
		end
		flag("passes_auto_roll_half", near(ratio("Auto", "auto_roll_2x", interval), 0.5))
		flag("passes_money_2x", near(ratio("Money", "money_2x", GachaService.MoneyMulti), 2))
		flag("passes_vip_money", near(ratio("VipMoney", "vip", GachaService.MoneyMulti), 1.1))
		flag("passes_vip_luck", near(ratio("VipLuck", "vip", GachaService.Luck, allowed), 1.1))
		flag("passes_luck_1", near(ratio("Lucky", "luck_1", GachaService.Luck, allowed), 2))
		flag("passes_luck_2", near(ratio("Ultra", "luck_2", GachaService.Luck, allowed), 3))
		flag("passes_luck_off_restricted", near(ratio("Restricted", "luck_2", GachaService.Luck), 1))
		flag("passes_vip_luck_off_restricted", near(ratio("VipRestricted", "vip", GachaService.Luck), 1))
		flag("passes_deep_stamina", near(ratio("Stamina", "deep_stamina", GachaService.StaminaMulti), 1.25))

		local squad = player("PassSquad")
		for _, spec in CharacterCatalog.All() do
			if spec.Rollable and not spec.Event then
				GachaService.Grant(squad, spec.Id)
				squad:SetAttribute("Showcase", spec.Id)
				break
			end
		end
		local boost = GachaService.WorkshopBoost(squad)
		squad:SetAttribute("Pass_dojo_master", true)
		flag("passes_dojo_master", boost > 0 and near(GachaService.WorkshopBoost(squad), boost * 1.5))

		-- The exclusive runner
		local spec = CharacterCatalog.Get(CharacterCatalog.EXCLUSIVE_ID)
		flag("passes_exclusive_name", spec and spec.Name == "Saitamo")
		flag("passes_exclusive_not_rollable", spec and spec.Rollable == false and spec.Chance == nil)
		flag("passes_exclusive_id_not_in_index", not table.find(CharacterCatalog.All(), spec))
		flag("passes_exclusive_id_not_rolled", not table.find(CharacterCatalog.Rollable(), spec))
		flag("passes_exclusive_cruise_350", RaceConfig.Cruise(spec, 1) == 350, RaceConfig.Cruise(spec, 1), 350)
		flag("passes_exclusive_boosts_apply", RaceConfig.Cruise(spec, 2) == 700)
		flag("passes_exclusive_capped", RaceConfig.Cruise(spec, 3) == RaceConfig.MAX_CRUISE)
		local e = player("PassExclusive")
		flag("passes_exclusive_absent_before", e.GachaData:FindFirstChild(spec.Id) == nil)
		e:SetAttribute("Pass_exclusive_runner", true)
		task.wait()
		flag("passes_exclusive_granted", e.GachaData:FindFirstChild(spec.Id) ~= nil)
		e:SetAttribute("Team", spec.Id)
		e:SetAttribute("EquippedCar", spec.Id)
		flag("passes_exclusive_runs_350", GachaService.CruiseFor(e, spec.Id, 1) >= 350)
		local saved = GachaService.Snapshot(e)
		local reload = player("PassExclusiveReload")
		GachaService.Apply(reload, saved)
		flag("passes_exclusive_save_round_trip", reload.GachaData:FindFirstChild(spec.Id) ~= nil)
		flag("passes_exclusive_no_stat_point", GachaService.UniqueCount(e) == 0)

		-- Paid luck list
		for _, id in { "luck_1", "luck_2", "potion_luck_pack", "potion_bundle" } do
			flag("passes_paid_luck_" .. id, Monetization.PaidLuck[id] == true)
		end
	end)
	PassService.SetOwnerCheck(nil)
	PassService.SetPolicyRead(nil)
	byId.money_2x.GamepassId, byId.vip.GamepassId = 0, 0
	for _, p in cleanup do
		p:Destroy()
	end
	flag("passes_no_error", ok, ok and 1 or tostring(err))
	return r
end

function Tests.odds()
	local r, flag = H.report("odds")
	for _, luck in { 1, 2, 10, 1e6, 1e15, 1e20 } do
		local sum, count = 0, 0
		for _, row in GachaConfig.Odds(luck) do
			sum += row.Chance
			count += 1
		end
		flag("odds_sum_1_luck_" .. luck, near(sum, 1), sum, 1)
		flag("odds_every_outcome_luck_" .. luck, count == #CharacterCatalog.Rollable(), count)
		local shown = 0
		for _, row in GachaConfig.OddsPercents(luck) do
			shown += row.Percent
		end
		flag("odds_percent_sum_100_luck_" .. luck, near(shown, 100), shown, 100)
	end
	flag("odds_bad_luck_is_1", GachaConfig.Odds(0)[1].Chance == GachaConfig.Odds(1)[1].Chance)

	-- The list must match what a roll really does: a seeded simulation, 5 sigma on every outcome.
	for _, luck in { 10, 1e6 } do
		local N = 1000000
		local rng, seen = Random.new(75001), {}
		for i = 1, N do
			local id = GachaConfig.Roll(rng, luck)
			seen[id] = (seen[id] or 0) + 1
			if i % 50000 == 0 then
				task.wait()
			end
		end
		local bad = {}
		for _, row in GachaConfig.Odds(luck) do
			local p = row.Chance
			local sigma = math.sqrt(N * p * (1 - p))
			local off = math.abs((seen[row.Spec.Id] or 0) - N * p)
			if off > 5 * sigma + 1 then
				table.insert(bad, row.Spec.Id)
			end
		end
		flag("odds_match_simulation_luck_" .. luck, #bad == 0, table.concat(bad, ","), "")
	end
	return r
end

function Tests.bag()
	local r, flag = H.report("bag")
	flag("bag_base_80", BagConfig.BASE == 80)
	flag("bag_pass_100", BagConfig.Cap(true, 0) == 180)
	local tree = UpgradeTree.Bonuses({ inventory_1 = true, inventory_2 = true })
	flag("bag_tree_50_per_tier", tree.Inventory == 100, tree.Inventory, 100)
	flag("bag_cap_max_430", BagConfig.Cap(true, 250) == 430)

	-- The new branch's tiles sit on free hexes
	local seen, clash = {}, {}
	for _, tile in UpgradeTree.Tiles() do
		local key = tile.Q .. "," .. tile.R
		if seen[key] or key == "0,0" then
			table.insert(clash, tile.Id)
		end
		seen[key] = true
	end
	flag("bag_tree_hexes_free", #clash == 0, table.concat(clash, ","), "")

	-- Auto sell rule
	local rare = { Chance = 1000, Rarity = "Rare" }
	flag("bag_sell_off", not BagConfig.ShouldSell(false, 1000, rare))
	flag("bag_sell_at_n", BagConfig.ShouldSell(true, 1000, rare))
	flag("bag_keep_rarer_than_n", not BagConfig.ShouldSell(true, 999, rare))
	flag("bag_never_without_chance", not BagConfig.ShouldSell(true, 1000, { Rarity = "Rare" }))
	for _, value in { 0, -1, 1.5, 0 / 0, math.huge, 1e19, "100" } do
		flag("bag_bad_chance_" .. tostring(value), BagConfig.CleanChance(value) == nil)
	end

	local cleanup = {}
	local function player(name)
		local p = fakePlayer(name)
		table.insert(cleanup, p)
		return p
	end
	local ok, err = pcall(function()
		local id = catchAll().Id
		local price = BagConfig.SELL_PRICE[catchAll().Rarity]

		-- Full bag stops rolling, before Rolls and Turbo move
		local p = player("BagFull")
		GachaService.Grant(p, id)
		flag("bag_used_counts_first", GachaService.BagUsed(p) == 1)
		p.GachaData[id]:SetAttribute("Copies", 79)
		flag("bag_used_counts_copies", GachaService.BagUsed(p) == 80, GachaService.BagUsed(p), 80)
		flag("bag_full_at_cap", GachaService.BagFull(p))
		local rolls, turbo = p:GetAttribute("Rolls"), p:GetAttribute("TurboCount")
		flag("bag_full_no_roll", GachaService.RollTick(p, CATCH_ALL_ROLLER) == nil)
		flag("bag_full_rolls_unchanged", p:GetAttribute("Rolls") == rolls)
		flag("bag_full_turbo_unchanged", p:GetAttribute("TurboCount") == turbo)

		-- Space from the pass: rolling resumes
		p:SetAttribute("Pass_inventory", true)
		flag("bag_pass_cap", GachaService.BagCap(p) == 180, GachaService.BagCap(p), 180)
		flag("bag_resumes", GachaService.RollTick(p, CATCH_ALL_ROLLER) ~= nil)
		flag("bag_roll_adds_copy", GachaService.BagUsed(p) == 81)
		flag("bag_attribute_refreshed", p:GetAttribute("BagUsed") == 81 and p:GetAttribute("BagCap") == 180)

		-- Extra rolls, stopping when the bag fills
		local x = player("BagExtra")
		GachaService.Grant(x, id)
		x:SetAttribute("Pass_extra_roll_1", true)
		x:SetAttribute("Pass_extra_roll_2", true)
		GachaService.RollTick(x, CATCH_ALL_ROLLER)
		flag("bag_extra_rolls_3", x:GetAttribute("Rolls") == 3, x:GetAttribute("Rolls"), 3)
		x.GachaData[id]:SetAttribute("Copies", 77) -- 78 used: 2 spaces left
		x:SetAttribute("Rolls", 0)
		GachaService.RollTick(x, CATCH_ALL_ROLLER)
		flag("bag_extra_stops_when_full", x:GetAttribute("Rolls") == 2, x:GetAttribute("Rolls"), 2)

		-- Auto sell: duplicate sold, discovery kept, last copy safe
		local s = player("BagSell")
		local money = MoneyService.Setup(s)
		flag(
			"bag_set_refuses_bad",
			not GachaService.SetAutoSell(s, true, -1) and not GachaService.SetAutoSell(s, "on", 5)
		)
		flag("bag_set_accepts", GachaService.SetAutoSell(s, true, 1))
		local _, isNew, _, _, sold = GachaService.Roll(s, CATCH_ALL_ROLLER)
		flag("bag_discovery_kept", isNew == true and sold == 0 and s.GachaData:FindFirstChild(id) ~= nil)
		flag("bag_discovery_pays_nothing", money.Value == 0)
		_, isNew, _, _, sold = GachaService.Roll(s, CATCH_ALL_ROLLER)
		flag("bag_duplicate_sold", isNew == false and sold == price, sold, price)
		flag("bag_sale_pays", money.Value == price, money.Value, price)
		flag("bag_sale_adds_no_copy", GachaService.Copies(s, id) == 0)
		flag("bag_sale_counts_roll", s:GetAttribute("Rolls") == 2)

		-- Sell spares
		local m = player("BagSpares")
		local cash = MoneyService.Setup(m)
		GachaService.Grant(m, id)
		m.GachaData[id]:SetAttribute("Copies", 10)
		flag("bag_spares_needs_load", GachaService.SellSpares(m, id) == false and cash.Value == 0)
		m:SetAttribute("DataLoaded", true)
		flag("bag_spares_bad_id", GachaService.SellSpares(m, 5) == false)
		flag("bag_spares_unowned", GachaService.SellSpares(m, "not_a_character") == false)
		flag("bag_spares_sells", GachaService.SellSpares(m, id) == true)
		flag("bag_spares_pays", cash.Value == 10 * price, cash.Value, 10 * price)
		flag("bag_spares_last_copy_stays", m.GachaData:FindFirstChild(id) ~= nil and GachaService.BagUsed(m) == 1)
		flag("bag_spares_pays_once", GachaService.SellSpares(m, id) == false and cash.Value == 10 * price)

		-- Saves
		local o = player("BagSave")
		GachaService.Grant(o, id)
		o.GachaData[id]:SetAttribute("Copies", 500)
		GachaService.SetAutoSell(o, true, 1000)
		local saved = GachaService.Snapshot(o)
		flag("bag_snapshot_fields", saved.AutoSell == true and saved.AutoSellChance == 1000)
		local reload = player("BagReload")
		GachaService.Apply(reload, saved)
		flag("bag_over_cap_save_intact", GachaService.Copies(reload, id) == 500)
		flag("bag_over_cap_full", reload:GetAttribute("BagFull") == true)
		flag(
			"bag_auto_sell_reloaded",
			reload:GetAttribute("AutoSell") == true and reload:GetAttribute("AutoSellChance") == 1000
		)
		local old = player("BagOld")
		GachaService.Apply(old, { Cars = { id } })
		flag(
			"bag_missing_fields_off",
			old:GetAttribute("AutoSell") == false and old:GetAttribute("AutoSellChance") == nil
		)
		local junk = player("BagJunk")
		GachaService.Apply(junk, { Cars = { id }, AutoSell = true, AutoSellChance = "lots" })
		flag("bag_junk_fields_off", junk:GetAttribute("AutoSell") == false)
	end)
	for _, p in cleanup do
		p:Destroy()
	end
	flag("bag_no_error", ok, ok and 1 or tostring(err))
	return r
end

return Tests
