--!nonstrict
-- Speed balance (docs/SPEED_BALANCE_SPEC.md, design doc 4.13, owner 2026-11-05). Pure numbers: no run is driven.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage:WaitForChild("Shared")

local TRACK_1_LENGTH = 984 * 3 -- design doc 4.9

local function balance()
	local report, flag = H.report("balance")
	local RaceConfig = require(Shared.RaceConfig)
	local NpcConfig = require(Shared.NpcConfig)
	local StaminaConfig = require(Shared.StaminaConfig)
	local HudFormat = require(Shared.HudFormat)
	local RebirthConfig = require(Shared.RebirthConfig)
	local BoostConfig = require(Shared.BoostConfig)
	local MarketConfig = require(Shared.MarketConfig)

	local rising, curve = true, RaceConfig.SPEED_CURVE
	for i = 2, #curve do
		rising = rising and curve[i][1] > curve[i - 1][1] and curve[i][2] > curve[i - 1][2]
	end
	flag("balance_curve_rises", rising)
	flag("balance_curve_top_is_cap", RaceConfig.CruiseOf(1e300) == RaceConfig.MAX_CRUISE, RaceConfig.CruiseOf(1e300))
	-- design doc 4.39: the curve runs on to 7e37 = 1000 studs/s, while MAX_CRUISE holds movement at 800
	local last, beforeLast = curve[#curve], curve[#curve - 1]
	flag(
		"balance_curve_end_anchor",
		last[1] == 7e37 and last[2] == 1000 and beforeLast[1] == 7e31 and beforeLast[2] == 800,
		last[1],
		7e37
	)
	flag("balance_max_cruise_stays_800", RaceConfig.MAX_CRUISE == 800, RaceConfig.MAX_CRUISE, 800)

	local enemiesOnCurve, enemiesRise, recBeats = true, true, true
	for n = 1, 10 do
		local enemy = NpcConfig.For(n)
		local anchored = false
		for _, anchor in curve do
			anchored = anchored or (anchor[1] == enemy.Speed and anchor[2] == enemy.Cruise)
		end
		enemiesOnCurve = enemiesOnCurve and anchored
		enemiesRise = enemiesRise and (n == 1 or enemy.Cruise > NpcConfig.For(n - 1).Cruise)
		recBeats = recBeats and RaceConfig.CruiseOf(NpcConfig.RecommendedSpeed(n)) > enemy.Cruise
	end
	flag("balance_enemies_on_curve", enemiesOnCurve)
	flag("balance_enemies_rise", enemiesRise)
	flag("balance_recommended_beats_enemy", recBeats)
	flag("balance_track9_octillions", string.sub(HudFormat.Short(NpcConfig.For(9).Speed), -2) == "oc")
	flag("balance_track10_octillions", string.sub(HudFormat.Short(NpcConfig.For(10).Speed), -2) == "oc")

	local whole = true
	for rarity in RaceConfig.RARITY_BASE do
		for _, category in { "Sprinter", "Balanced", "Marathoner" } do
			for _, multi in { 1, 1.07, 3.3, 1e9 } do
				local speed = RaceConfig.Speed({ Rarity = rarity, Category = category }, multi)
				whole = whole and speed == math.floor(speed)
			end
		end
	end
	flag("balance_speed_is_whole", whole)

	-- The best kit of the 47 characters before Eternal (design doc 4.13): Secret, rebirth 20, all 35 points in Speed (+70%),
	-- 5 tree tiers (+50%), the best Dojo squad at level 10 (+190%), best potion, preset, best aura and trail. It reaches
	-- 800 studs/s, no further. Eternals pass that Speed and are held at MAX_CRUISE (design doc 4.39), checked below.
	local function best(list)
		local top = 1
		for _, item in list do
			top = math.max(top, item.SpeedMulti)
		end
		return top
	end
	local kitMulti = RaceConfig.SpeedMulti(
		35,
		BoostConfig.ByCategory.Speed[3].Multiplier,
		true,
		best(MarketConfig.Items.Aura),
		best(MarketConfig.Items.Trail),
		0.5 + 1.9,
		RebirthConfig.SpeedMulti(20)
	)
	local kit = RaceConfig.Speed({ Rarity = "Secret", Category = "Balanced" }, kitMulti)
	flag(
		"balance_best_kit_near_800",
		RaceConfig.CruiseOf(kit) >= 780 and RaceConfig.CruiseOf(kit) <= 800,
		RaceConfig.CruiseOf(kit),
		800
	)
	local eternal, secret = { Rarity = "Eternal", Category = "Balanced" }, { Rarity = "Secret", Category = "Balanced" }
	local eternalKit = RaceConfig.Cruise(eternal, kitMulti)
	flag("balance_eternal_best_kit_capped", eternalKit == RaceConfig.MAX_CRUISE, eternalKit, RaceConfig.MAX_CRUISE)
	flag(
		"balance_eternal_above_secret",
		RaceConfig.Cruise(eternal, 1) > RaceConfig.Cruise(secret, 1),
		RaceConfig.Cruise(eternal, 1)
	)
	flag("balance_eternal_base_50qd", RaceConfig.Speed(eternal, 1) == 5e16, RaceConfig.Speed(eternal, 1), 5e16)
	-- 1e34 Speed sits between the 800 and 1000 anchors; past the top anchor too
	local capped = true
	for _, multi in { 2e17, 1e30, 1e100 } do
		capped = capped and RaceConfig.Cruise(eternal, multi) == RaceConfig.MAX_CRUISE
	end
	flag("balance_eternal_capped_at_huge_multi", capped)
	flag("balance_rebirth_5_is_x100", RebirthConfig.SpeedMulti(5) == 100, RebirthConfig.SpeedMulti(5), 100)
	local costsRise = #RebirthConfig.COSTS == RebirthConfig.MAX_LEVEL
		and #RebirthConfig.SPEED_TOTALS == RebirthConfig.MAX_LEVEL
	for i = 2, RebirthConfig.MAX_LEVEL do
		costsRise = costsRise and RebirthConfig.COSTS[i] > RebirthConfig.COSTS[i - 1]
		costsRise = costsRise and RebirthConfig.SPEED_TOTALS[i] > RebirthConfig.SPEED_TOTALS[i - 1]
	end
	flag("balance_rebirth_tables_rise", costsRise)

	-- Track 1 gate, Balanced (spec "Track 1 gate"): "exhaust", "win" or "lose"
	local function gate(team, staminaMulti)
		local left, seconds = TRACK_1_LENGTH, 0
		for _, rarity in team do
			local cruise = RaceConfig.Cruise({ Rarity = rarity, Category = "Balanced" }, 1)
			local step = math.min(left, cruise * StaminaConfig.BASE[rarity] * staminaMulti)
			left -= step
			seconds += step / cruise
		end
		if left > 0 then
			return "exhaust"
		end
		return seconds < TRACK_1_LENGTH / NpcConfig.For(1).Cruise and "win" or "lose"
	end
	local function gateIs(name, team, staminaMulti, want)
		local got = gate(team, staminaMulti)
		flag("balance_gate_" .. name, got == want, got, want)
	end
	gateIs("commons_exhaust", { "Common", "Common", "Common" }, 1.2, "exhaust")
	gateIs("uncommons_exhaust", { "Uncommon", "Uncommon", "Uncommon" }, 1.2, "exhaust")
	gateIs("uncommon_stamina_loses", { "Uncommon", "Uncommon", "Uncommon" }, 2, "lose")
	gateIs("rare_no_buff_exhausts", { "Rare", "Rare", "Rare" }, 1, "exhaust")
	gateIs("rare_buff_wins", { "Rare", "Rare", "Rare" }, 1.2, "win")
	gateIs("two_rares_exhaust", { "Rare", "Rare", "Uncommon" }, 1.2, "exhaust")
	gateIs("epics_win", { "Epic", "Epic", "Epic" }, 1, "win")

	return report
end

return { balance = balance }
