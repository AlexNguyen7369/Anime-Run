--!nonstrict
-- Rebirth progression knobs. All thresholds and permanent effects live here so
-- the server and presentation can describe the same progression.

local RebirthConfig = {}

RebirthConfig.DEFAULT_LEVEL = 0
-- Total Luck multi per rebirth level (owner 2026-10-27 rev. 4, docs/REBIRTH_SPEC.md); rebirth 20 is the last
-- one. Rebirth gives no XP (owner 2026-11-01, design doc 4.14).
RebirthConfig.TOTALS = { 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7.5, 10, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11 }
RebirthConfig.MAX_LEVEL = #RebirthConfig.TOTALS
-- Total Speed multi per rebirth level, Money needed for each rebirth (proposed, owner 2026-11-05, design doc 4.14,
-- docs/SPEED_BALANCE_SPEC.md; fitted with tools/balance/speed_model.py)
-- stylua: ignore
RebirthConfig.SPEED_TOTALS = { 5, 12, 25, 50, 100, 250, 600, 1500, 4000, 1e4, 1.6e5, 2.5e6, 4e7, 6.5e8, 1e10, 1.6e11, 2.5e12, 4e13, 6.5e14, 1e16 }
-- stylua: ignore
RebirthConfig.COSTS = { 5e3, 12e3, 25e3, 50e3, 1e5, 3e5, 8e5, 2e6, 5e6, 1.2e7, 2e7, 4e8, 2e9, 1e10, 4e10, 1.2e11, 2.5e11, 3e11, 3.5e11, 5e11 }
RebirthConfig.POINTS_PER_REBIRTH = 1 -- stat points per rebirth (placeholder, owner 2026-10-15; docs/REBIRTH_SPEC.md)

function RebirthConfig.CleanLevel(level)
	if type(level) ~= "number" or level ~= level or level == math.huge or level == -math.huge then
		return RebirthConfig.DEFAULT_LEVEL
	end
	return math.max(RebirthConfig.DEFAULT_LEVEL, math.floor(level))
end

function RebirthConfig.LuckMulti(level)
	level = RebirthConfig.CleanLevel(level)
	if level == 0 then
		return 1
	end
	return RebirthConfig.TOTALS[math.min(level, RebirthConfig.MAX_LEVEL)]
end

-- Total Speed multi of a rebirth level; it multiplies the speed multi (RaceConfig.SpeedMulti).
function RebirthConfig.SpeedMulti(level)
	level = RebirthConfig.CleanLevel(level)
	if level == 0 then
		return 1
	end
	return RebirthConfig.SPEED_TOTALS[math.min(level, RebirthConfig.MAX_LEVEL)]
end

function RebirthConfig.MoneyMulti(_level)
	return 1
end

-- Total multi after the next rebirth, shown on the Rebirth panel so the UI never hard-codes it.
function RebirthConfig.NextMultiplier(level)
	return RebirthConfig.LuckMulti(RebirthConfig.CleanLevel(level) + 1)
end

-- Stat points earned from rebirths, added to the car-index points (never saved: derived from the rebirth count)
function RebirthConfig.Points(level)
	return RebirthConfig.CleanLevel(level) * RebirthConfig.POINTS_PER_REBIRTH
end

function RebirthConfig.Requirements(level)
	level = math.min(RebirthConfig.CleanLevel(level), RebirthConfig.MAX_LEVEL - 1) -- past the last: the final value
	return {
		Money = RebirthConfig.COSTS[level + 1],
	}
end

function RebirthConfig.CanRebirth(level, money)
	if RebirthConfig.CleanLevel(level) >= RebirthConfig.MAX_LEVEL then
		return false
	end
	return type(money) == "number" and money >= RebirthConfig.Requirements(level).Money
end

return RebirthConfig
