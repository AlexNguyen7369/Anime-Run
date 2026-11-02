--!nonstrict
-- Stamina (docs/TEAM_AND_STAMINA_SPEC.md "Stamina"): seconds a runner runs from 100% to 0%. Never saved.
-- Owner 2026-11-02: track-by-track progression, Commons tire at about 12-15 s, Secrets at 30 s (in-between values and
-- category multis proposed). Category multis: design doc 4.5.
-- shortcut: the Stamina stat point, Stamina potion and Series / preset bonus are c2; add their factors in Seconds.

local StaminaConfig = {}

StaminaConfig.BASE = {
	Common = 13.5,
	Uncommon = 15.5,
	Rare = 18,
	Epic = 21,
	Legendary = 24,
	Mythic = 27,
	Secret = 30,
}

StaminaConfig.CATEGORY = { Sprinter = 0.9, Balanced = 1, Marathoner = 1.1 }
StaminaConfig.EXHAUSTION_SHARE = 1.0 -- placeholder: share of the per-distance pad cash banked on exhaustion (4.3)

StaminaConfig.TEAM_SIZE = 3

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

-- Effective stamina seconds of a spec for a run: Base x Category.
function StaminaConfig.Seconds(spec)
	local category = type(spec) == "table" and StaminaConfig.CATEGORY[spec.Category] or 1
	return StaminaConfig.Base(spec) * category
end

return StaminaConfig
