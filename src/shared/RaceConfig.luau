--!nonstrict
-- Economy knobs for the auto race. Every character runs at a fixed cruise speed (studs/s) set by its rarity and
-- category, times the speed multi, capped at MAX_CRUISE (owner 2026-11-01, design doc 4.13; there is no Speed stat).

local GachaConfig = require(script.Parent.GachaConfig)

local RaceConfig = {}

RaceConfig.MAX_CRUISE = 800 -- hard cruise cap, studs/s (owner 2026-10-27; speed_probe green to 1000, minus 10 %, max 800)
RaceConfig.ITEM_CRUISE_DAMP = 0.5 -- aura / trail cruise multi = 1 + this x log10(item multi) (owner 2026-10-28, placeholder)
-- Base cruise of a Balanced runner by rarity, studs/s (proposed 2026-11-01, design doc 4.13)
RaceConfig.RARITY_BASE = {
	Common = 24,
	Uncommon = 33,
	Rare = 48,
	Epic = 90,
	Legendary = 200,
	Mythic = 450,
	Secret = 700,
}
-- Category x cruise (design doc 4.5; placeholders)
RaceConfig.CATEGORY_SPEED = { Sprinter = 1.25, Balanced = 1, Marathoner = 0.8 }
RaceConfig.SPEED_PER_POINT = GachaConfig.PER_POINT.Speed -- +2 % cruise per Speed stat point (design doc 4.13)
RaceConfig.PRESET_CRUISE = 1.1 -- preset team cruise bonus (placeholder, design doc 4.8)

local function positive(n)
	return type(n) == "number" and n == n and n > 0 and n ~= math.huge
end

-- Damped cruise multi of an equipped aura or trail (owner 2026-10-28): 1 + ITEM_CRUISE_DAMP x log10(multi), min 1.
function RaceConfig.ItemCruiseMulti(itemMulti)
	if not positive(itemMulti) or itemMulti <= 1 then
		return 1
	end
	return 1 + RaceConfig.ITEM_CRUISE_DAMP * math.log10(itemMulti)
end

-- Speed multi (design doc 4.13): (1 + SPEED_PER_POINT x Speed points + upgrade tree Speed bonus) x Speed potion
-- x preset bonus x damped aura x damped trail. `potion` is the active Speed potion multi (1 = none); `preset` true
-- for a preset team; `treeBonus` the additive bonuses: owned Speed tiers (UpgradeTree.Bonuses(owned).Speed), rebirth level, 0 = none.
function RaceConfig.SpeedMulti(speedPoints, potion, preset, auraMulti, trailMulti, treeBonus)
	local points = positive(speedPoints) and math.floor(speedPoints) or 0
	return (1 + RaceConfig.SPEED_PER_POINT * points + (positive(treeBonus) and treeBonus or 0))
		* (positive(potion) and math.max(potion, 1) or 1)
		* (preset == true and RaceConfig.PRESET_CRUISE or 1)
		* RaceConfig.ItemCruiseMulti(auraMulti)
		* RaceConfig.ItemCruiseMulti(trailMulti)
end

-- Cruise (studs/s) of a character spec at a speed multi: RARITY_BASE x CATEGORY_SPEED x multi, capped at MAX_CRUISE.
-- An unknown rarity runs as Common, an unknown category as Balanced. An admin test spec's AdminCruise wins, uncapped.
function RaceConfig.Cruise(spec, speedMulti)
	if spec and positive(spec.AdminCruise) then
		return spec.AdminCruise
	end
	-- BaseCruise: the exclusive runner's exception to rarity x category (design doc 4.13, 4.35)
	local base = spec and spec.BaseCruise
		or RaceConfig.RARITY_BASE[spec and spec.Rarity]
		or RaceConfig.RARITY_BASE.Common
	local category = RaceConfig.CATEGORY_SPEED[spec and spec.Category] or 1
	local multi = positive(speedMulti) and speedMulti or 1
	return math.min(base * category * multi, RaceConfig.MAX_CRUISE)
end

return RaceConfig
