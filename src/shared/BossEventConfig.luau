--!nonstrict
-- Boss event numbers (design doc 4.37, docs/BOSS_EVENT_SPEC.md). Interval, prep, join, total, refill wait and chat text are
-- owner values; the rest are spec placeholders.
local BossEventConfig = {}

BossEventConfig.IntervalSeconds = 1800
BossEventConfig.PrepSeconds = 60
BossEventConfig.JoinSeconds = 180 -- teleporting closes and HP locks
BossEventConfig.TotalSeconds = 480
BossEventConfig.RefillWaitSeconds = 5
BossEventConfig.ChatMessage = "BIG RAGA HAS SPAWNED, TAKE HIM DOWN FOR REWARDS"

BossEventConfig.IntroSeconds = 20 -- placeholder: the rise, no damage
BossEventConfig.HpPerPlayer = 4000 -- placeholder
BossEventConfig.HitEverySeconds = 1.5 -- placeholder: SidekickConfig.HitInterval
BossEventConfig.MinDamageShare = 0.01 -- placeholder: of max HP, for a reward
local FULL_SCALE_CRUISE = 800 -- placeholder: the cruise that reaches the +100% cap

-- 1 + min(1, cruise / 800): at most +100% (owner 2026-11-05).
function BossEventConfig.SpeedScale(cruise)
	return 1 + math.min(1, cruise / FULL_SCALE_CRUISE)
end

-- The average of the team's Sidekick damages, times the speed scale. No rounding.
function BossEventConfig.TeamDamage(damages, cruise)
	if #damages == 0 then
		return 0
	end
	local total = 0
	for _, damage in damages do
		total += damage
	end
	return total / #damages * BossEventConfig.SpeedScale(cruise)
end

return BossEventConfig
