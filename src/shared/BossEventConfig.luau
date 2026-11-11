--!nonstrict
-- Boss event numbers (design doc 4.37, docs/BOSS_EVENT_SPEC.md). Interval, prep, join, total, refill wait and chat text are
-- owner values; the rest are spec placeholders.
local Arena = require(script.Parent.BossArenaConfig)

local BossEventConfig = {}

BossEventConfig.IntervalSeconds = 1800
BossEventConfig.PrepSeconds = 60
BossEventConfig.JoinSeconds = 180 -- teleporting closes and HP locks
BossEventConfig.TotalSeconds = 480
BossEventConfig.RefillWaitSeconds = 8.5 -- owner 2026-11-06
BossEventConfig.ChatMessage = "BIG RAGA HAS SPAWNED, TAKE HIM DOWN FOR REWARDS"
BossEventConfig.InviteSeconds = 3 -- owner: then teleporting stays open from the Boss button

BossEventConfig.IntroSeconds = 3 -- owner 2026-11-05: the rise and the cutscene, no damage; the fight starts at its end
BossEventConfig.RiseSeconds = 1.5 -- owner 2026-11-05: the first part of it, Big Raga rising with the HP bar
BossEventConfig.ShoutDamageCut = 0.25 -- proposed: players' damage while Shouted
BossEventConfig.AdaptedCut = 0.10 -- owner: Big Raga takes this much less while Adapted
-- Radians the wheel has turned `since` seconds after the scream began (BOSS_EVENT_SPEC "Phase 2"): time-based, so a late client
-- agrees. Placeholders.
local WHEEL_FAST, WHEEL_RAMP, WHEEL_HOLD, WHEEL_SLOW = math.rad(1080), 0.35, 1, math.rad(50)
function BossEventConfig.WheelSpinAt(since)
	if since <= 0 then
		return 0
	end
	local fast = math.min(since, BossEventConfig.ScreamSeconds)
	local angle = fast < WHEEL_RAMP and WHEEL_FAST * fast * fast / (2 * WHEEL_RAMP)
		or WHEEL_FAST * (fast - WHEEL_RAMP / 2)
	return angle + WHEEL_SLOW * math.max(0, since - BossEventConfig.ScreamSeconds - WHEEL_HOLD)
end

BossEventConfig.CameraFov = 100 -- owner 2026-11-06: locked for the whole event
BossEventConfig.CameraZoom = 40 -- proposed: studs while running, the distance in the owner's 2026-11-06 screenshot; also the game's max
BossEventConfig.WaitCameraFov = BossEventConfig.CameraFov
-- Placeholders (owner 2026-11-06: zoomed in a lot, was 450 out, 320 up, 11 deg).
local WAIT_CAMERA_OUT = 120 -- past the runner, away from the boss
local WAIT_CAMERA_UP = 80
local WAIT_CAMERA_DOWN_ANGLE = math.rad(4) -- the view's axis, below horizontal
-- No runner: the same distance from the ring, on the boss's front (it faces -Z).
BossEventConfig.WaitCameraOffset = Vector3.new(0, WAIT_CAMERA_UP, -Arena.LaneRadius(4) - WAIT_CAMERA_OUT)
BossEventConfig.HpPerPlayer = 7500 -- owner 2026-11-06
BossEventConfig.Phase2ExtraHp = 50000 -- owner 2026-11-06: Phase 2's HP is Phase 1's max plus this
BossEventConfig.Phase2ExtraSeconds = 120 -- owner 2026-11-06
BossEventConfig.ScreamSeconds = 6 -- owner 2026-11-06, was 3
BossEventConfig.ScreamGrowth = 1.25 -- owner 2026-11-06
BossEventConfig.Phase1Money = 100000 -- owner 2026-11-06
BossEventConfig.Phase2Gems = 1000 -- owner 2026-11-06
BossEventConfig.VulnerableMulti = 1.5 -- owner 2026-11-06: the next undodged Impact's cost
BossEventConfig.HitEverySeconds = 1.5 -- placeholder: SidekickConfig.HitInterval
BossEventConfig.MinDamageShare = 0.05 -- owner 2026-11-06: of the phase's own max HP, for its reward
local FULL_SCALE_CRUISE = 800 -- placeholder: the cruise that reaches the +100% cap

-- Owner 2026-11-06. AttackStaminaCost: percent of a full bar, per attack Impact, on every character in the line.
local STAGES = {
	{ AttackStaminaCost = 15, StatusSeconds = 15 },
	{ AttackStaminaCost = 30, StatusSeconds = 20 },
}

function BossEventConfig.Stage(stage)
	return STAGES[stage]
end

-- Schedule event -> the chat line to players in the event (BOSS_EVENT_SPEC, wording proposed).
function BossEventConfig.MoveChat(name, stage)
	local row = STAGES[stage]
	if name == "Impact" then
		return string.format("Big Raga attacks! -%d%% stamina", row.AttackStaminaCost)
	elseif name == "Roar" then
		return string.format("Big Raga shouts! Damage down for %d s", row.StatusSeconds)
	end
	return string.format(
		"Big Raga turns its wheel! It takes %d%% less damage for %d s",
		math.round(BossEventConfig.AdaptedCut * 100),
		row.StatusSeconds
	)
end

-- 1 + min(1, cruise / 800): at most +100% (owner 2026-11-05).
function BossEventConfig.SpeedScale(cruise)
	return 1 + math.min(1, cruise / FULL_SCALE_CRUISE)
end

-- The scream's close view (BOSS_EVENT_SPEC "Phase 2"): still, on the boss's front (it faces -Z), inside the ring, so it visibly fills
-- the frame as it grows. At the locked FOV the view spans about 512 studs up and down from this distance, at the model's own size;
-- both scale with the boss (Arena.BossScale), so the framing stays. Proposed. Pure.
local SCREAM_CAMERA_BACK, SCREAM_CAMERA_UP = 430 * Arena.BossScale, 400 * Arena.BossScale
function BossEventConfig.ScreamCameraCFrame()
	local middle = Vector3.new(Arena.Center.X, Arena.DaisY + SCREAM_CAMERA_UP, Arena.Center.Z)
	return CFrame.lookAt(middle - Vector3.zAxis * SCREAM_CAMERA_BACK, middle)
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
