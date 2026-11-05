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

	local rising, curve = true, RaceConfig.SPEED_CURVE
	for i = 2, #curve do
		rising = rising and curve[i][1] > curve[i - 1][1] and curve[i][2] > curve[i - 1][2]
	end
	flag("balance_curve_rises", rising)
	flag("balance_curve_top_is_cap", RaceConfig.CruiseOf(1e300) == RaceConfig.MAX_CRUISE, RaceConfig.CruiseOf(1e300))

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
