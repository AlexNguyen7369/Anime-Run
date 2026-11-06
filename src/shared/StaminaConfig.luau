--!nonstrict
-- Stamina (docs/TEAM_AND_STAMINA_SPEC.md "Stamina"): seconds a runner runs from 100% to 0%. Never saved.
-- Owner 2026-11-02: track-by-track progression, Commons tire at about 12-15 s, Secrets at 30 s (in-between values and
-- category multis proposed). Category multis: design doc 4.5.
-- Player multis (design doc 4.6-4.8, owner 2026-11-03 tree branch): StaminaConfig.Multi.

local StaminaConfig = {}

StaminaConfig.BASE = {
	Common = 13.5,
	Uncommon = 15.5,
	Rare = 18,
	Epic = 21,
	Legendary = 24,
	Mythic = 27,
	Secret = 30,
	Eternal = 32, -- proposed (design doc 4.39)
}

StaminaConfig.CATEGORY = { Sprinter = 0.9, Balanced = 1, Marathoner = 1.1 }
StaminaConfig.EXHAUSTION_SHARE = 1.0 -- placeholder: share of the per-distance pad cash banked on exhaustion (4.3)

StaminaConfig.TEAM_SIZE = 3
StaminaConfig.PER_POINT = 0.05 -- +5 % per Stamina stat point (placeholder, design doc 4.6; GachaConfig.PER_POINT.Stamina)
StaminaConfig.TEAM_BONUS = { Preset = 1.4, Series = 1.2 } -- placeholders (design doc 4.8)

local function positive(n)
	return type(n) == "number" and n == n and n > 0 and n ~= math.huge
end

-- Player stamina multi for a run: (1 + PER_POINT x points + tree bonus) x potion x team bonus. `bonusKind` is
-- "Preset", "Series" or nil (SeriesCatalog.TeamBonus).
function StaminaConfig.Multi(points, treeBonus, potion, bonusKind)
	local p = positive(points) and math.floor(points) or 0
	return (1 + StaminaConfig.PER_POINT * p + (positive(treeBonus) and treeBonus or 0))
		* (positive(potion) and math.max(potion, 1) or 1)
		* (StaminaConfig.TEAM_BONUS[bonusKind] or 1)
end

-- Bar colour by stamina percent (owner 2026-11-03, display only; thresholds placeholders): blue, amber <= 50, red <= 25.
StaminaConfig.MID = 50
StaminaConfig.LOW = 25
StaminaConfig.COLORS = {
	Full = Color3.fromRGB(60, 150, 255),
	Mid = Color3.fromRGB(255, 186, 60),
	Low = Color3.fromRGB(255, 70, 70),
}
function StaminaConfig.Color(percent)
	percent = tonumber(percent) or 0
	return percent <= StaminaConfig.LOW and StaminaConfig.COLORS.Low
		or percent <= StaminaConfig.MID and StaminaConfig.COLORS.Mid
		or StaminaConfig.COLORS.Full
end

-- Base stamina seconds of a catalog spec: its own Stamina override, else its rarity's.
function StaminaConfig.Base(spec)
	if type(spec) ~= "table" then
		return StaminaConfig.BASE.Common
	end
	if type(spec.Stamina) == "number" and spec.Stamina > 0 then
		return spec.Stamina
	end
	return StaminaConfig.BASE[spec.Rarity] or StaminaConfig.BASE.Common
end

-- Effective stamina seconds of a spec for a run: Base x Category x `multi` (StaminaConfig.Multi, default 1).
function StaminaConfig.Seconds(spec, multi)
	local category = type(spec) == "table" and StaminaConfig.CATEGORY[spec.Category] or 1
	return StaminaConfig.Base(spec) * category * (positive(multi) and multi or 1)
end

return StaminaConfig
