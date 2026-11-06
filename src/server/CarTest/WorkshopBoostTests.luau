--!nonstrict
-- BRIEF: design doc 4.19 and docs/WORLD_REDESIGN_SPEC.md section 5 "Workshop stat boost" (owner 2026-11-03), goal
-- core c4: `workshop_boost`. Never loosen a limit to make it pass. The point values and percentages are the doc's
-- placeholders, written here as literals (Common 1 .. Secret 7, Eternal 8, x 5 %, level scale 1 + 0.1 x (level - 1)).
--
-- API the test reads:
--   Shared/Workshop.Boost(squadSpecs, level) -> fraction added to the chosen stat; Workshop.CleanStat(stat)
--   Shared/WorkshopConfig.STATS = { "Money", "Luck", "Speed", "Stamina" } (first = default)
--   WorkshopService.SetStat(player, stat) -> ok, reason; Snapshot / Apply keep WorkshopStat
--   GachaService.WorkshopBoost(player); player attributes WorkshopStat, WorkshopBoost
--   The boost sits in the chosen stat's additive part: GachaService.MoneyMulti / Luck / Cruise / StaminaMulti.
--   Not here: the SetWorkshopStat remote's rate limit (a server test can not invoke a RemoteFunction).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local TOL = 1e-9
local UID = 991500000

local Tests = {}

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and a == a and math.abs(a - b) <= TOL * math.max(1, math.abs(b))
end

function Tests.workshop_boost()
	local r, flag = H.report("workshop_boost")
	local mods = {
		workshop = H.module(Shared, "Workshop"),
		wconfig = H.module(Shared, "WorkshopConfig"),
		gconfig = H.module(Shared, "GachaConfig"),
		catalog = H.module(Shared, "CharacterCatalog"),
		raceConfig = H.module(Shared, "RaceConfig"),
		wservice = H.module(Server, "WorkshopService"),
		gacha = H.module(Server, "GachaService"),
		data = H.module(Server, "PlayerData"),
		money = H.module(Server, "MoneyService"),
	}
	local api = mods.workshop
		and mods.wconfig
		and mods.gconfig
		and mods.catalog
		and mods.raceConfig
		and mods.wservice
		and mods.gacha
		and mods.data
		and mods.money
		and type(mods.workshop.Boost) == "function"
		and type(mods.workshop.CleanStat) == "function"
		and type(mods.wservice.SetStat) == "function"
		and type(mods.wservice.Snapshot) == "function"
		and type(mods.wservice.Apply) == "function"
		and type(mods.gacha.WorkshopBoost) == "function"
		and type(mods.gacha.SetShowcase) == "function"
		and type(mods.gacha.MoneyMulti) == "function"
		and type(mods.gacha.Luck) == "function"
		and type(mods.gacha.Cruise) == "function"
		and type(mods.gacha.StaminaMulti) == "function"
	flag("workshop_boost_api_exists", api == true)
	if not api then
		return r
	end
	local W, gacha, wservice = mods.workshop, mods.gacha, mods.wservice

	-- 1. Workshop.Boost: rarity points x 5 % x (1 + 0.1 x (level - 1)); empty slots and unknown rarities give 0
	local function specs(...)
		local list = {}
		for i, rarity in { ... } do
			list[i] = rarity and { Id = "cartest_" .. i, Rarity = rarity } or nil
		end
		return list
	end
	local cases = {
		{ "3 Commons", specs("Common", "Common", "Common"), 1, 0.15 },
		{ "3 Secrets", specs("Secret", "Secret", "Secret"), 1, 1.05 },
		{ "3 Eternals", specs("Eternal", "Eternal", "Eternal"), 1, 1.2 }, -- design doc 4.39, 4.19
		{ "Rare Epic Legendary", specs("Rare", "Epic", "Legendary"), 1, 0.6 },
		{ "Uncommon Mythic", specs("Uncommon", "Mythic"), 1, 0.4 },
		{ "empty", {}, 1, 0 },
		{ "one Common, 2 empty", { { Id = "a", Rarity = "Common" } }, 1, 0.05 },
		{ "unknown rarity", specs("Nope"), 1, 0 },
		{ "3 Secrets level 10", specs("Secret", "Secret", "Secret"), 10, 1.05 * 1.9 },
		{ "3 Commons level 5", specs("Common", "Common", "Common"), 5, 0.15 * 1.4 },
		{ "level 0 = level 1", specs("Epic"), 0, 0.2 },
		{ "level past max = max", specs("Epic"), 99, 0.2 * (1 + 0.1 * (mods.wconfig.MAX_LEVEL - 1)) },
		{ "level not a number = 1", specs("Epic"), "x", 0.2 },
	}
	local bad = {}
	for _, c in cases do
		local ok, v = pcall(W.Boost, c[2], c[3])
		if not (ok and near(v, c[4])) then
			table.insert(bad, ("%s=%s/%s"):format(c[1], tostring(v), tostring(c[4])))
		end
	end
	r.metrics.boost_bad = table.concat(bad, " ")
	flag("workshop_boost_values", #bad == 0, #bad, 0)
	flag(
		"workshop_boost_level_10_is_x1_9",
		mods.wconfig.MAX_LEVEL >= 10 and near(W.Boost(specs("Common"), 10), 0.05 * 1.9)
	)

	-- 2. The stat choice: Money, Luck, Speed, Stamina; default Money; the Workshop stat point is retired
	flag(
		"workshop_boost_stats",
		H.same(mods.wconfig.STATS, { "Money", "Luck", "Speed", "Stamina" }),
		table.concat(mods.wconfig.STATS, ","),
		"Money,Luck,Speed,Stamina"
	)
	flag("workshop_stat_point_retired", table.find(mods.gconfig.STATS, "Workshop") == nil)
	flag(
		"workshop_boost_clean_stat",
		W.CleanStat(nil) == "Money" and W.CleanStat("Workshop") == "Money" and W.CleanStat("Luck") == "Luck"
	)

	local cleanup = {}
	local ok, err = pcall(function()
		UID += 1
		local p = H.player(cleanup, UID)
		p.Name = "CarTestWorkshopBoost"
		pcall(mods.money.Setup, p)
		pcall(mods.data.Setup, p)
		pcall(gacha.Setup, p)
		wservice.Apply(p, {})
		flag("workshop_boost_default_money", p:GetAttribute("WorkshopStat") == "Money", p:GetAttribute("WorkshopStat"))

		-- 3. SetStat rejects anything but the 4 stats and changes nothing; a good value is set and saved
		local rejected = wservice.SetStat(p, nil) ~= true and p:GetAttribute("WorkshopStat") == "Money"
		for _, v in { "Workshop", "money", "", " Money", "Speedy", 5, true, {} } do
			local okSet = wservice.SetStat(p, v)
			rejected = rejected and okSet ~= true and p:GetAttribute("WorkshopStat") == "Money"
		end
		flag("workshop_set_stat_rejects_bad", rejected)
		local okLuck = wservice.SetStat(p, "Luck") == true
		flag(
			"workshop_set_stat_saved",
			okLuck and p:GetAttribute("WorkshopStat") == "Luck" and wservice.Snapshot(p).WorkshopStat == "Luck"
		)
		wservice.Apply(p, { WorkshopStat = "Workshop" })
		flag("workshop_stat_bad_save_is_money", p:GetAttribute("WorkshopStat") == "Money")

		-- 4. The boost lands in the chosen stat only. Squad: a Secret, a Legendary and a Rare (7 + 5 + 3 = 15
		-- points = +75 %), workshop level 3 (x1.2) = +90 %. A fresh player has no points, tree or potions, so the
		-- chosen stat's additive part is 1 + boost and every other stat stays at its no-squad value.
		local want = { Secret = true, Legendary = true, Rare = true }
		local squad = {}
		for _, spec in mods.catalog.Rollable() do
			if want[spec.Rarity] and spec.Id ~= mods.catalog.STARTER_ID then
				want[spec.Rarity] = nil
				table.insert(squad, spec.Id)
				gacha.Grant(p, spec.Id)
			end
		end
		p:SetAttribute("WorkshopLevel", 3)
		local function read()
			task.wait() -- attribute changes refresh WorkshopBoost (deferred signals)
			return {
				Money = gacha.MoneyMulti(p),
				Luck = gacha.Luck(p),
				Speed = gacha.Cruise(p),
				Stamina = gacha.StaminaMulti(p),
			}
		end
		local base = read()
		local okSquad = #squad == 3 and gacha.SetShowcase(p, squad) == true
		local boost = gacha.WorkshopBoost(p)
		task.wait()
		flag(
			"workshop_boost_from_squad",
			okSquad and near(boost, 0.9) and near(p:GetAttribute("WorkshopBoost"), 0.9),
			boost,
			0.9
		)
		local starter = mods.catalog.Get(mods.catalog.STARTER_ID)
		flag("workshop_boost_speed_uncapped_here", mods.raceConfig.Cruise(starter, 1.9) < mods.raceConfig.MAX_CRUISE)
		local wrong = {}
		for _, stat in mods.wconfig.STATS do
			wservice.SetStat(p, stat)
			local got = read()
			for other, value in got do
				local ratio = value / base[other]
				local expect = other == stat and 1.9 or 1
				if not near(ratio, expect) then
					table.insert(wrong, ("%s->%s x%.6f/%.1f"):format(stat, other, ratio, expect))
				end
			end
		end
		r.metrics.boost_wrong = table.concat(wrong, " ")
		flag("workshop_boost_lands_in_chosen_stat_only", okSquad and #wrong == 0, #wrong, 0)
	end)
	flag("workshop_boost_no_error", ok)
	if not ok then
		r.metrics.error = tostring(err)
	end
	for _, x in cleanup do
		x:Destroy()
	end
	return r
end

return Tests
