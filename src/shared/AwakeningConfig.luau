--!nonstrict
-- Awakening (design doc 4.47, docs/WORLD2_SPEC.md "Awakening"): World 2 only. A character's duplicate Copies buy up to
-- MAX_STARS stars; each star gives +3% cruise and +3% stamina (owner 2026-11-24). Pure.
local AwakeningConfig = {}

AwakeningConfig.MAX_STARS = 5
AwakeningConfig.COSTS = { 1, 2, 4, 8, 16 } -- Copies for star 1..5: placeholders (design doc 4.47)
AwakeningConfig.CRUISE_PER_STAR = 0.03
AwakeningConfig.STAMINA_PER_STAR = 0.03

local function clean(stars)
	return type(stars) == "number" and stars == stars and math.clamp(math.floor(stars), 0, AwakeningConfig.MAX_STARS)
		or 0
end
AwakeningConfig.Clean = clean

-- Copies the next star costs at `stars`, nil at MAX_STARS.
function AwakeningConfig.NextCost(stars)
	return AwakeningConfig.COSTS[clean(stars) + 1]
end

function AwakeningConfig.CruiseMulti(stars)
	return 1 + AwakeningConfig.CRUISE_PER_STAR * clean(stars)
end

function AwakeningConfig.StaminaMulti(stars)
	return 1 + AwakeningConfig.STAMINA_PER_STAR * clean(stars)
end

return AwakeningConfig
