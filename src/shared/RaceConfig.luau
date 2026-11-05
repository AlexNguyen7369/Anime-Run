--!nonstrict
-- Economy knobs for the auto race (design doc 4.13, docs/SPEED_BALANCE_SPEC.md). Speed is the game's whole number, set by
-- rarity, category and the multis. Cruise is the real movement in studs/s, read from Speed through SPEED_CURVE.

local GachaConfig = require(script.Parent.GachaConfig)

local RaceConfig = {}

RaceConfig.MAX_CRUISE = 800 -- hard cruise cap, studs/s (owner 2026-10-27; speed_probe green to 1000, minus 10 %, max 800)
-- Base Speed of a Balanced runner by rarity (proposed 2026-11-05)
RaceConfig.RARITY_BASE = {
	Common = 100,
	Uncommon = 300,
	Rare = 1200,
	Epic = 2e4,
	Legendary = 5e6,
	Mythic = 5e10,
	Secret = 5e13,
}
-- { Speed, studs/s }, ascending (proposed 2026-11-05): Common, Uncommon, Track 1's enemy, Rare, then the enemies of Tracks
-- 2-10 (NpcConfig.Tracks), then the best kit of the current cast at 800. Above the last anchor the runner holds its cruise.
RaceConfig.SPEED_CURVE = {
	{ 10, 10 },
	{ 100, 24 },
	{ 300, 33 },
	{ 1e3, 45.5 },
	{ 1200, 48 },
	{ 1e5, 61.2 },
	{ 1e7, 82.2 },
	{ 3e9, 110.6 },
	{ 3e12, 148.7 },
	{ 3e15, 199.9 },
	{ 3e18, 268.7 },
	{ 1e22, 361.3 },
	{ 1e27, 485.7 },
	{ 5e29, 653 },
	{ 7e31, 800 },
}
-- Category x Speed (design doc 4.5; placeholders)
RaceConfig.CATEGORY_SPEED = { Sprinter = 1.25, Balanced = 1, Marathoner = 0.8 }
RaceConfig.SPEED_PER_POINT = GachaConfig.PER_POINT.Speed -- +2 % Speed per Speed stat point (design doc 4.13)
RaceConfig.PRESET_CRUISE = 1.1 -- preset team Speed bonus (placeholder, design doc 4.8)

local function positive(n)
	return type(n) == "number" and n == n and n > 0 and n ~= math.huge
end

-- Speed multi of an equipped aura or trail: its listed multi, min 1 (proposed 2026-11-05; SPEED_CURVE now protects the cap).
function RaceConfig.ItemCruiseMulti(itemMulti)
	return positive(itemMulti) and math.max(itemMulti, 1) or 1
end

-- Speed multi (design doc 4.13): (1 + SPEED_PER_POINT x Speed points + upgrade tree Speed bonus) x Speed potion
-- x preset bonus x aura x trail. `potion` is the active Speed potion multi (1 = none); `preset` true
-- for a preset team; `treeBonus` the additive bonuses: owned Speed tiers (UpgradeTree.Bonuses(owned).Speed), 0 = none;
-- `rebirth` the rebirth level's total (RebirthConfig.SpeedMulti), 1 = none.
function RaceConfig.SpeedMulti(speedPoints, potion, preset, auraMulti, trailMulti, treeBonus, rebirth)
	local points = positive(speedPoints) and math.floor(speedPoints) or 0
	return (1 + RaceConfig.SPEED_PER_POINT * points + (positive(treeBonus) and treeBonus or 0))
		* (positive(potion) and math.max(potion, 1) or 1)
		* (preset == true and RaceConfig.PRESET_CRUISE or 1)
		* RaceConfig.ItemCruiseMulti(auraMulti)
		* RaceConfig.ItemCruiseMulti(trailMulti)
		* (positive(rebirth) and rebirth or 1)
end

-- Whole Speed of a character spec at a speed multi: RARITY_BASE x CATEGORY_SPEED x multi, no cap. An unknown rarity runs
-- as Common, an unknown category as Balanced. An admin test spec's AdminSpeed wins.
function RaceConfig.Speed(spec, speedMulti)
	if spec and positive(spec.AdminSpeed) then
		return spec.AdminSpeed
	end
	local base = RaceConfig.RARITY_BASE[spec and spec.Rarity] or RaceConfig.RARITY_BASE.Common
	local category = RaceConfig.CATEGORY_SPEED[spec and spec.Category] or 1
	local multi = positive(speedMulti) and speedMulti or 1
	return math.floor(math.min(base * category * multi, 1e300))
end

-- Studs/s of a Speed: log-log between the SPEED_CURVE anchors, capped at MAX_CRUISE.
function RaceConfig.CruiseOf(speed)
	local curve = RaceConfig.SPEED_CURVE
	local value = curve[#curve][2]
	if not positive(speed) or speed <= curve[1][1] then
		value = curve[1][2]
	else
		for i = 2, #curve do
			local a, b = curve[i - 1], curve[i]
			if speed < b[1] then -- an exact anchor falls to the next segment at t = 0, so it reads its value exactly
				local t = math.log(speed / a[1]) / math.log(b[1] / a[1])
				value = a[2] * (b[2] / a[2]) ^ t
				break
			end
		end
	end
	return math.min(value, RaceConfig.MAX_CRUISE)
end

-- Cruise (studs/s) of a character spec at a speed multi.
function RaceConfig.Cruise(spec, speedMulti)
	return RaceConfig.CruiseOf(RaceConfig.Speed(spec, speedMulti))
end

return RaceConfig
