--!nonstrict
-- Boss event numbers (design doc 4.37, docs/BOSS_EVENT_SPEC.md). Interval, prep, join, total, refill wait and chat text are
-- owner values; the rest are spec placeholders.
local Arena = require(script.Parent.BossArenaConfig)

local BossEventConfig = {}

BossEventConfig.IntervalSeconds = 1800
BossEventConfig.PrepSeconds = 60
BossEventConfig.JoinSeconds = 180 -- teleporting closes and HP locks
BossEventConfig.TotalSeconds = 480
BossEventConfig.RefillWaitSeconds = 5
BossEventConfig.ChatMessage = "BIG RAGA HAS SPAWNED, TAKE HIM DOWN FOR REWARDS"
BossEventConfig.InviteSeconds = 3 -- owner: then teleporting stays open from the Boss button
-- Schedule event -> the chat line to players in the event (BOSS_EVENT_SPEC, wording proposed).
BossEventConfig.MoveChat = {
	Impact = "Big Raga attacks! -5% stamina",
	Roar = "Big Raga shouts! Damage down for 5 s",
	WheelClick = "Big Raga turns its wheel! It takes 10% less damage for 5 s",
}

BossEventConfig.IntroSeconds = 3 -- owner 2026-11-05: 2 to 3 s, the rise, no damage
BossEventConfig.AttackStaminaCost = 5 -- owner: percent of a full bar, per attack Impact, on the running character
BossEventConfig.ShoutDamageCut = 0.25 -- proposed: players' damage while Shouted
BossEventConfig.ShoutSeconds = 5 -- owner
BossEventConfig.AdaptedCut = 0.10 -- owner: Big Raga takes this much less while Adapted
BossEventConfig.AdaptedSeconds = 5 -- owner
BossEventConfig.CameraFov = 100 -- placeholder
BossEventConfig.WaitCameraFov = 64 -- placeholder: the exhaustion view
-- Placeholders. At WaitCameraFov on a 907 px screen: the runner is at y near 775, about 6 px tall; the boss is 430 to 455 px
-- tall, wheel top at y 43 to 56, feet at y 489 to 498.
local WAIT_CAMERA_OUT = 450 -- past the runner, away from the boss
local WAIT_CAMERA_UP = 320
local WAIT_CAMERA_DOWN_ANGLE = math.rad(11) -- the view's axis, below horizontal
-- No runner: the same distance from the ring, on the boss's front (it faces -Z).
BossEventConfig.WaitCameraOffset = Vector3.new(0, WAIT_CAMERA_UP, -Arena.LaneRadius(4) - WAIT_CAMERA_OUT)
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

-- The exhaustion view: hovers above and outward of the runner, tilted down toward the boss (BOSS_EVENT_SPEC "Exhaustion view"). Pure.
function BossEventConfig.WaitCameraCFrame(center, runnerPosition)
	local flat = runnerPosition and (runnerPosition - center) * Vector3.new(1, 0, 1)
	local eye = center + BossEventConfig.WaitCameraOffset
	if flat and flat.Magnitude >= 1 then
		eye = runnerPosition + flat.Unit * WAIT_CAMERA_OUT + Vector3.yAxis * WAIT_CAMERA_UP
	end
	local inward = ((center - eye) * Vector3.new(1, 0, 1)).Unit
	return CFrame.lookAt(eye, eye + inward - Vector3.yAxis * math.tan(WAIT_CAMERA_DOWN_ANGLE))
end

return BossEventConfig
