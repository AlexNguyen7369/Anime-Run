--!nonstrict
-- Stamina (docs/TEAM_AND_STAMINA_SPEC.md "Stamina"): seconds a runner runs from 100% to 0%. Never saved.
-- Placeholders except Mythic 36 and Secret 43 (owner 2026-10-30).

local StaminaConfig = {}

StaminaConfig.BASE = {
	Common = 20,
	Uncommon = 22,
	Rare = 24,
	Epic = 27,
	Legendary = 30,
	Mythic = 36,
	Secret = 43,
}

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

return StaminaConfig
