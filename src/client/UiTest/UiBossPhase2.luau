--!nonstrict
-- Boss Phase 2's presentation and the rewards popup (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Phase 2", "Rewards", "Run rules", "Dodge
-- bar", "Paid spawn"). Owned by ui-test-writer. Both scenarios drive the published attributes through UiTestSetup boss_ui_* and
-- boss_phase2_*, and never join an event; the real press is the boss_rewards_close click in UiSpec.Clicks.
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   RacerBossEvent/BossBar/Title: "Big Raga" in stage 1, "Fully Adapted Raga" in stage 2, the scream included.
--   RacerBossEvent/BossBar/BossTimer counts to BossEventEndsAt.
--   BossBar's Fill: during BossScreamEndsAt follows the time left from low to full; after it, Hp / MaxHp.
--   RacerBossEvent/DropList/Row_<id>, Row_side_raga, top to bottom by LayoutOrder. The rate is the number before "%" in the Text. Bar full is
--     BossScheduleStart + IntroSeconds, the scream's end (BossScreamEndsAt is nil after it, so a late view reads this). From there the
--     rows change one at a time, top first, all final within CASCADE_MAX. A view after that shows all final at once. Stage 1 or no event
--     shows Phase 1's rates again.
--   BossBar/Status/Status_<Id>/Stack: a TextLabel, "x2" at Count 2, not shown at Count 1. Seconds stays "<n>s".
--   BossBar/Status/Status_Vulnerable: Icon, shown until the row goes, with no digit showing in its Seconds.
--   Growth cutscene (owner 2026-11-06): scale is read from the size of workspace.BossArenaPreview's BigRaga/Wheel against stage 1: near 1 at
--     the scream's start, between at its middle, GROWTH at its end and after, for a late view too, and 1 again in the next event; height
--     up, feet still. The camera moves during the scream and is back by its end; ReduceEffects keeps the camera still, and the growth.
--     LowGraphicsBoss (BillboardGui) grows by the same factor where it is enabled. The exhausted panel hides with BossWaitEndsAt nil.
--   RacerBossDodge: in stage 2 `since` is now - BossScheduleStart - IntroSeconds, the sweep BossDodge.SweepFor(2).
--   ExhaustedPanel/Countdown: Text is a number, its first value above 8 and at most 8.5 on an 8.5 s wait.
--   BossesPanel/BossDetails, beside its Row_<id> and Row_side_raga (UiBossPaid): Title_<chest id> with the chest's Name,
--     Adapted_<id> per RelicConfig.ChestOdds("relic_chest_adapted"), Adapted_side_raga "Big Raga 0.01%". Static, whatever the stage.
--   RacerBossRewards (Client/BossRewardPopup; DisplayOrder above the HUD), its Panel hidden until a BossRewards message:
--     Panel/Header/Title, Panel/Header/CloseButton, Panel/Damage (holds the total with commas), Panel/Note ("Deal 5% for rewards", shown
--     only with Short), Panel/Rewards/Chest_<chest id> (ImageLabel, the chest's Image), Panel/Rewards/Money ("100,000" in its Text),
--     Panel/Rewards/Gems ("1,000" in its Text). A reward not paid is not shown.
--   Title: Outcome Survived "Fully Adapted Raga survived", otherwise "Raga Defeated!". Only the player's BossEvent holds it back: a
--     player who left while the event runs sees it at once. A later message replaces the one shown.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("BossEventConfig"))
local Dodge = require(Shared:WaitForChild("BossDodge"))
local RelicConfig = require(Shared:WaitForChild("RelicConfig"))
local Spec = require(script.Parent.UiSpec)

local ROOT = "RacerBossEvent"
local BAR = ROOT .. "/BossBar"
local DROP = ROOT .. "/DropList"
local DETAILS = ROOT .. "/BossesPanel/BossDetails"
local EXHAUSTED = ROOT .. "/ExhaustedPanel"
local DODGE_BAR = "RacerBossDodge/DodgeBar"
local POPUP = "RacerBossRewards/Panel"
local INVITE = ROOT .. "/Invite"
local BUTTON = ROOT .. "/BossButton"
local RAGA_CHEST, ADAPTED_CHEST = "relic_chest_raga", "relic_chest_adapted"

local TITLE_STAGE_1, TITLE_STAGE_2 = "Big Raga", "Fully Adapted Raga"
local SIDE_RATE_1, SIDE_RATE_2 = 0.001, 0.01 -- percent: design doc 4.37, RELIC_SPEC "Chests"
local SHOW_WAIT = 2 -- s: an attribute change has replicated and the UI has followed
local COUNTDOWN_SLACK = 2 -- s
local CASCADE_MAX = 6 -- s after the bar is full, for every row to be final. Not a rule: long enough for any readable pace
local FILL_SLACK = 0.15 -- of the bar: "from low to full" names no curve, only that it follows the scream
local FILL_LOW = 0.35 -- of the bar, in the scream's first moments
local FILL_SHRINK = 0.02
local FILL_END = 0.98
local FILL_HP_SLACK = 0.02
local BAR_FULL_SLACK = 0.1 -- s: this sample's replication lag
local SLIDER_SLACK = 0.06 -- of the bar: a frame of lag; a Phase 1 sweep would read about 0.2 away
local DODGE_LEAD = 1 -- s before the moment: inside SweepFor(2) + the bar's pop, away from either sweep's end
local DODGE_SHOW_WAIT = 0.4 -- s: a Phase 1 clock would not open the bar for 0.55 s
local OLD_CLOCK_PAST = 2 -- s past moment 1 on the Phase 1 clock: its next moment is at least 1.95 s off (moments are 3.95 s apart)
local VULNERABLE_HOLDS = 1 -- s: it has no EndsAt, so nothing may time it out
local GROWTH = 1.25 -- owner 2026-11-06
local GROWTH_START_MAX, GROWTH_MIDDLE_MIN, GROWTH_MIDDLE_MAX = 1.05, 1.05, 1.2
local GROWTH_SLACK = 0.01
local GROWTH_SHRINK = 0.005
local HEIGHT_RATIO_MIN = 1.1 -- wheel top over feet, late against early in the scream: the pose is held between them
local FEET_SLACK = 8 -- studs, as UiBossVfx
local FEET_FROM = 0.2 -- of the scream: past the pose's change into the shout
local CAMERA_MOVED, CAMERA_STILL, CAMERA_HOME_SLACK = 1, 1, 5 -- studs
local CAMERA_SETTLE_HOLD, CAMERA_SETTLE_MAX = 0.5, 4 -- s: Roblox eases the zoom to the event's locked minimum
local BUILD_WAIT = 8 -- s: the arena builds over frames
local GATE_HOLD = 0.6 -- s a held popup must stay hidden
local CLOSED_HOLD = 0.7 -- s: longer than the button's 0.6 s pulse period
local PULSE_SLACK = 0.001
local DAMAGE, DAMAGE_TEXT = 1234567, "1,234,567"
local SHORT_DAMAGE, SHORT_DAMAGE_TEXT = 12345, "12,345"

local Module = {}

function Module.Build(h)
	local scenarios, after = {}, {}

	local function check(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local function setup(res, request)
		local ok, err = h.requestSetup(request)
		if not ok then
			h.check(res, "setup_" .. request, tostring(err), "ok", false)
		end
	end
	local function state(res, phase, elapsed, hp, max, inEvent)
		setup(res, ("boss_ui_state:%s:%s:%s:%s:%s:none"):format(phase, tostring(elapsed), hp, max, tostring(inEvent)))
	end
	-- Seconds from now; "none" clears the attribute. scheduleAgo is how long ago BossScheduleStart was.
	local function stage(res, n, endsIn, screamIn, scheduleAgo)
		setup(
			res,
			("boss_phase2_stage:%d:%s:%s:%s"):format(
				n,
				tostring(endsIn or "none"),
				tostring(screamIn or "none"),
				tostring(scheduleAgo or "none")
			)
		)
	end
	local function shown(path)
		local gui = h.find(path)
		return gui ~= nil and h.visible(gui)
	end
	local function waitIs(fn, want, seconds)
		local deadline = os.clock() + (seconds or SHOW_WAIT)
		local value = fn()
		while value ~= want and os.clock() < deadline do
			task.wait(0.03)
			value = fn()
		end
		return value
	end
	local function waitShown(path, want, seconds)
		return waitIs(function()
			return shown(path)
		end, want, seconds)
	end
	local function textOf(path)
		local gui = h.find(path)
		return gui and gui.Text or ""
	end
	local function checkTextSoon(res, name, path, want)
		check(
			res,
			name,
			waitIs(function()
				return textOf(path)
			end, want),
			want
		)
	end
	local function rateIn(text)
		return tonumber(string.match(text or "", "([%d%.]+)%%"))
	end
	local function near(a, b)
		return a ~= nil and b ~= nil and math.abs(a - b) < 1e-6
	end

	-- { Id, Old, New } top to bottom: the rates each row of the drop list must show.
	local function dropPlan()
		local plan = {}
		local adapted = {}
		for _, row in RelicConfig.ChestOdds(ADAPTED_CHEST) do
			adapted[row.Id] = row.Odds
		end
		local rows = RelicConfig.Odds("big_raga")
		table.sort(rows, function(a, b)
			return a.Odds > b.Odds
		end)
		for _, row in rows do
			table.insert(plan, { Id = row.Id, Old = row.Odds, New = adapted[row.Id] })
		end
		table.insert(plan, { Id = "side_raga", Old = SIDE_RATE_1, New = SIDE_RATE_2 })
		return plan
	end
	local function dropRate(id)
		return rateIn(textOf(DROP .. "/Row_" .. id))
	end
	local function checkRowsAre(res, tag, field)
		for _, row in dropPlan() do
			local want = row[field]
			local got = waitIs(function()
				local rate = dropRate(row.Id)
				return near(rate, want) and want or rate
			end, want)
			check(res, tag .. "_" .. row.Id, got, want)
		end
	end

	local function checkDetails(res)
		for _, id in { RAGA_CHEST, ADAPTED_CHEST } do
			local chest = RelicConfig.Chests[id]
			check(res, "details_title_" .. id, textOf(DETAILS .. "/Title_" .. id), chest and chest.Name)
		end
		for prefix, chest in { Row_ = RAGA_CHEST, Adapted_ = ADAPTED_CHEST } do
			local sum = 0
			for _, row in RelicConfig.ChestOdds(chest) do
				local rate = rateIn(textOf(DETAILS .. "/" .. prefix .. row.Id))
				h.check(res, "details_" .. prefix .. row.Id, rate, row.Odds, near(rate, row.Odds))
				sum += rate or 0
			end
			h.check(res, "details_" .. prefix .. "sum_100", sum, 100, near(sum, 100))
		end
		check(res, "details_raga_side_stage1", textOf(DETAILS .. "/Row_side_raga"), "Big Raga 0.001%")
		check(res, "details_raga_side_stage2", textOf(DETAILS .. "/Adapted_side_raga"), "Big Raga 0.01%")
	end

	local function bossPart(name)
		local arena = workspace:FindFirstChild("BossArenaPreview")
		local model = arena and arena:FindFirstChild("BigRaga", true)
		return model and model:FindFirstChild(name, true)
	end
	local function verticalHalf(part)
		local cf, size = part.CFrame, part.Size
		return (
			math.abs(cf.RightVector.Y) * size.X
			+ math.abs(cf.UpVector.Y) * size.Y
			+ math.abs(cf.LookVector.Y) * size.Z
		) / 2
	end
	local baseWheel, baseFlat = nil, nil -- stage 1's sizes
	local function flatBoss()
		local arena = workspace:FindFirstChild("BossArenaPreview")
		return arena and arena:FindFirstChild("LowGraphicsBoss", true)
	end
	local function takeBase()
		local found = false
		local deadline = os.clock() + BUILD_WAIT
		while not found and os.clock() < deadline do
			found = bossPart("Wheel") ~= nil
			if not found then
				task.wait(0.1)
			end
		end
		local wheel = bossPart("Wheel")
		baseWheel = wheel and wheel.Size.Magnitude
		local flat = flatBoss()
		baseFlat = flat and flat.Enabled and flat.Size.Y.Scale + flat.Size.Y.Offset or nil
	end
	local function bossScale()
		local wheel = bossPart("Wheel")
		return wheel and baseWheel and wheel.Size.Magnitude / baseWheel
	end
	-- `fullAt` on os.clock. Fills `samples` frame by frame until just past the scream.
	local function recordScream(samples, fullAt, scream)
		task.spawn(function()
			while os.clock() < fullAt + 0.2 do
				local wheel, left, right = bossPart("Wheel"), bossPart("LeftFoot"), bossPart("RightFoot")
				local feet = left
					and right
					and math.min(left.Position.Y - verticalHalf(left), right.Position.Y - verticalHalf(right))
				table.insert(samples, {
					At = 1 - (fullAt - os.clock()) / scream,
					Scale = bossScale(),
					Feet = feet,
					Height = wheel and feet and wheel.Position.Y + verticalHalf(wheel) - feet,
					Reach = Spec.CameraReach(workspace.CurrentCamera), -- the runner moves: from the subject, not the world
				})
				task.wait()
			end
		end)
	end
	local function checkGrowth(res, tag, samples)
		local start, middle, early, late = nil, nil, nil, nil
		local shrank, last, feetMoved = false, nil, 0
		for _, sample in samples do
			if sample.At <= 0.1 and not start then
				start = sample
			end
			if sample.At >= 0.45 and sample.At <= 0.55 and not middle then
				middle = sample
			end
			if sample.At >= FEET_FROM and sample.At <= 1 then
				early = early or sample
				late = sample
				if sample.Feet and early.Feet then
					feetMoved = math.max(feetMoved, math.abs(sample.Feet - early.Feet))
				end
			end
			if sample.Scale and last and sample.Scale < last - GROWTH_SHRINK then
				shrank = true
			end
			last = sample.Scale or last
		end
		local startScale, middleScale = start and start.Scale, middle and middle.Scale
		h.check(res, tag .. "_scale_start", startScale, "near 1", startScale ~= nil and startScale <= GROWTH_START_MAX)
		h.check(
			res,
			tag .. "_scale_middle",
			middleScale,
			GROWTH_MIDDLE_MIN .. " to " .. GROWTH_MIDDLE_MAX,
			middleScale ~= nil and middleScale >= GROWTH_MIDDLE_MIN and middleScale <= GROWTH_MIDDLE_MAX
		)
		check(res, tag .. "_scale_never_shrinks", shrank, false)
		local atEnd = waitIs(function()
			local scale = bossScale()
			return scale ~= nil and math.abs(scale - GROWTH) <= GROWTH_SLACK
		end, true)
		h.check(res, tag .. "_scale_end", bossScale(), GROWTH, atEnd == true)
		local ratio = early and late and early.Height and late.Height and late.Height / early.Height
		h.check(res, tag .. "_height_grows", ratio, "> " .. HEIGHT_RATIO_MIN, ratio ~= nil and ratio > HEIGHT_RATIO_MIN)
		h.check(res, tag .. "_feet_still", feetMoved, "<= " .. FEET_SLACK, early ~= nil and feetMoved <= FEET_SLACK)
	end
	-- Waits for the fixture's BossScreamEndsAt. Returns its end on os.clock.
	local function screamEndClock(scream)
		local ends = waitIs(function()
			return ReplicatedStorage:GetAttribute("BossScreamEndsAt") ~= nil
		end, true)
		local at = ReplicatedStorage:GetAttribute("BossScreamEndsAt")
		if not (ends and at) then
			return os.clock() + scream
		end
		return os.clock() + (at - workspace:GetServerTimeNow())
	end

	local function checkStage1(res, hp)
		stage(res, 1, 90)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true)
		check(res, "stage1_bar_shown", waitShown(BAR, true), true)
		takeBase()
		check(res, "growth_boss_present", baseWheel ~= nil, true)
		checkTextSoon(res, "stage1_title", BAR .. "/Title", TITLE_STAGE_1)
		checkRowsAre(res, "stage1_rate", "Old")
		-- BossEventEndsAt, not TotalSeconds: this event's elapsed would read well over 90.
		local left = waitIs(function()
			local minutes, seconds = string.match(textOf(BAR .. "/BossTimer"), "^(%d+):(%d%d)$")
			local value = minutes and tonumber(minutes) * 60 + tonumber(seconds)
			return value and math.abs(value - 90) <= COUNTDOWN_SLACK
		end, true)
		h.check(res, "stage1_timer_to_ends_at", textOf(BAR .. "/BossTimer"), "about 1:30", left == true)
	end

	-- The camera's reach once it holds still for CAMERA_SETTLE_HOLD: an earlier read catches the zoom still easing (RunnerView locks it).
	local function settledReach(camera)
		local reach, stillSince, deadline = Spec.CameraReach(camera), os.clock(), os.clock() + CAMERA_SETTLE_MAX
		while os.clock() - stillSince < CAMERA_SETTLE_HOLD and os.clock() < deadline do
			task.wait(0.05)
			local now = Spec.CameraReach(camera)
			if math.abs(now - reach) > CAMERA_STILL then
				reach, stillSince = now, os.clock()
			end
		end
		return reach
	end

	-- The scream and the cascade after it, read in one pass: it is one stretch of time.
	local function checkScreamAndCascade(res, hp)
		local scream = Cfg.ScreamSeconds
		local plan = dropPlan()
		local fill = h.find(BAR .. "/Track/Fill")
		check(res, "scream_fill_present", fill ~= nil, true)
		local camera = workspace.CurrentCamera
		local cameraHome, cameraType = settledReach(camera), camera.CameraType
		stage(res, 2, 200, scream, Cfg.IntroSeconds - scream)
		local fullAt = screamEndClock(scream)
		local samples = {}
		recordScream(samples, fullAt, scream)
		if not fill then
			return
		end
		task.wait()
		local first = fill.Size.X.Scale
		h.check(res, "scream_fill_starts_low", first, "<= " .. FILL_LOW, first <= FILL_LOW)
		checkTextSoon(res, "scream_title", BAR .. "/Title", TITLE_STAGE_2)
		-- BossEventEndsAt again, in the new stage.
		local timerOk = waitIs(function()
			local minutes, seconds = string.match(textOf(BAR .. "/BossTimer"), "^(%d+):(%d%d)$")
			local value = minutes and tonumber(minutes) * 60 + tonumber(seconds)
			return value and math.abs(value - 200) <= COUNTDOWN_SLACK
		end, true, 0.3)
		h.check(res, "stage2_timer_to_ends_at", textOf(BAR .. "/BossTimer"), "about 3:20", timerOk == true)
		local worst, shrank, last, oldDuringScream = 0, false, first, {}
		local changedAt = {}
		local topFirstLastOld = nil
		local deadline = fullAt + CASCADE_MAX
		while os.clock() < deadline do
			local now = os.clock()
			local remaining = fullAt - now
			if remaining > 0 then
				local size = fill.Size.X.Scale
				worst = math.max(worst, math.abs(size - (1 - remaining / scream)))
				shrank = shrank or size < last - FILL_SHRINK
				last = size
			end
			local done = true
			for i, row in plan do
				local rate = dropRate(row.Id)
				if not changedAt[row.Id] and not near(rate, row.Old) then
					changedAt[row.Id] = now
					if remaining > BAR_FULL_SLACK then
						table.insert(oldDuringScream, row.Id)
					end
					if i == 1 then
						topFirstLastOld = near(dropRate(plan[#plan].Id), plan[#plan].Old)
					end
				end
				done = done and near(rate, row.New)
			end
			if done and remaining <= 0 then
				break
			end
			task.wait()
		end
		checkGrowth(res, "growth", samples)
		local moved = 0
		for _, sample in samples do
			if sample.At <= 1 then
				moved = math.max(moved, math.abs(sample.Reach - cameraHome))
			end
		end
		h.check(res, "growth_camera_frames_boss", moved, ">= " .. CAMERA_MOVED, moved >= CAMERA_MOVED)
		local homeBack = waitIs(function()
			return math.abs(Spec.CameraReach(camera) - cameraHome) <= CAMERA_HOME_SLACK
		end, true)
		h.check(
			res,
			"growth_camera_returns",
			("reach %.1f"):format(Spec.CameraReach(camera)),
			("%.1f +- %d"):format(cameraHome, CAMERA_HOME_SLACK),
			homeBack == true
		)
		check(res, "growth_camera_type_returns", camera.CameraType, cameraType)
		if baseFlat then
			local flat = flatBoss()
			local size = flat and flat.Size.Y.Scale + flat.Size.Y.Offset
			h.check(
				res,
				"growth_flat_boss",
				size,
				baseFlat * GROWTH,
				size and math.abs(size / baseFlat - GROWTH) <= GROWTH_SLACK
			)
		end
		h.check(res, "scream_fill_follows_time", worst, "<= " .. FILL_SLACK, worst <= FILL_SLACK)
		check(res, "scream_fill_never_shrinks", shrank, false)
		local atEnd = waitIs(function()
			return fill.Size.X.Scale >= FILL_END
		end, true)
		check(res, "scream_fill_full_at_end", atEnd, true)
		h.checkList(res, "drop_rows_old_until_bar_full", oldDuringScream)
		for _, row in plan do
			h.check(res, "cascade_final_" .. row.Id, dropRate(row.Id), row.New, near(dropRate(row.Id), row.New))
		end
		check(res, "cascade_top_changes_while_last_is_old", topFirstLastOld, true)
		local order = {}
		for i = 2, #plan do
			local before, this = changedAt[plan[i - 1].Id], changedAt[plan[i].Id]
			if not (before and this and before <= this) then
				table.insert(order, plan[i].Id)
			end
		end
		h.checkList(res, "cascade_top_to_bottom", order)
		local top, bottom = changedAt[plan[1].Id], changedAt[plan[#plan].Id]
		h.check(
			res,
			"cascade_takes_time",
			(top and bottom) and bottom - top or "no change",
			"> 0",
			top and bottom and bottom > top
		)
		-- After the scream the bar is the HP again.
		state(res, "Fight", "keep", hp / 2, hp, true)
		local half = waitIs(function()
			return math.abs(fill.Size.X.Scale - 0.5) <= FILL_HP_SLACK
		end, true)
		check(res, "stage2_fill_follows_hp", half, true)
		state(res, "Fight", "keep", hp, hp, true)
	end

	local function checkLateView(res, hp)
		stage(res, 2, 200, nil, Cfg.IntroSeconds + 60)
		check(
			res,
			"late_title",
			waitIs(function()
				return textOf(BAR .. "/Title")
			end, TITLE_STAGE_2),
			TITLE_STAGE_2
		)
		checkRowsAre(res, "late_rate", "New")
		local fill = h.find(BAR .. "/Track/Fill")
		check(res, "late_fill_is_hp", fill ~= nil and fill.Size.X.Scale >= FILL_END, true)
		h.check(res, "late_scale_snaps", bossScale(), GROWTH, math.abs((bossScale() or 0) - GROWTH) <= GROWTH_SLACK)
		-- A client arriving halfway through the scream snaps to the middle, not to 1.
		state(res, "Idle", 0, 0, 0, false)
		waitShown(BAR, false)
		stage(res, 2, 200, Cfg.ScreamSeconds / 2, Cfg.IntroSeconds - Cfg.ScreamSeconds / 2)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true)
		local snapped = waitIs(function()
			return (bossScale() or 0) >= GROWTH_MIDDLE_MIN
		end, true, 0.5)
		h.check(res, "late_mid_scream_snaps", bossScale(), ">= " .. GROWTH_MIDDLE_MIN, snapped == true)
		-- The next event starts over.
		state(res, "Idle", 0, 0, 0, false)
		check(res, "idle_hides_bar", waitShown(BAR, false), false)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true)
		stage(res, 1, 90)
		checkTextSoon(res, "next_event_title", BAR .. "/Title", TITLE_STAGE_1)
		checkRowsAre(res, "next_event_rate", "Old")
		local reset = waitIs(function()
			return math.abs((bossScale() or 0) - 1) <= GROWTH_SLACK
		end, true)
		h.check(res, "next_event_scale_1", bossScale(), 1, reset == true)
	end

	-- REDUCED EFFECTS keeps the camera still, and the growth.
	local function checkReducedGrowth(res, hp)
		local saved = h.player:GetAttribute("ReduceEffects")
		h.player:SetAttribute("ReduceEffects", true)
		local camera = workspace.CurrentCamera
		task.wait(0.2)
		local home = Spec.CameraReach(camera)
		local scream = Cfg.ScreamSeconds
		stage(res, 2, 200, scream, Cfg.IntroSeconds - scream)
		local fullAt = screamEndClock(scream)
		local samples = {}
		recordScream(samples, fullAt, scream)
		task.wait(math.max(0, fullAt - os.clock()) + 0.3)
		checkGrowth(res, "reduced_growth", samples)
		local moved = 0
		for _, sample in samples do
			moved = math.max(moved, math.abs(sample.Reach - home))
		end
		h.check(res, "reduced_camera_still", moved, "<= " .. CAMERA_STILL, moved <= CAMERA_STILL)
		h.player:SetAttribute("ReduceEffects", saved)
		state(res, "Idle", 0, 0, 0, false)
		waitShown(BAR, false)
		stage(res, 1, 90)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true)
	end

	-- The cutscene skips exhaustion: the server clears the end time as the scream starts, and the view goes with it.
	local function checkExhaustedInScream(res)
		setup(res, "boss_ui_wait:" .. tostring(Cfg.RefillWaitSeconds))
		check(res, "scream_exhausted_fixture_shown", waitShown(EXHAUSTED, true), true)
		stage(res, 2, 200, Cfg.ScreamSeconds, Cfg.IntroSeconds - Cfg.ScreamSeconds)
		setup(res, "boss_ui_wait:none")
		check(res, "scream_exhausted_panel_hidden", waitShown(EXHAUSTED, false, 1), false)
		check(res, "scream_exhausted_end_time_nil", h.player:GetAttribute("BossWaitEndsAt"), nil)
		task.wait(0.5)
		check(res, "scream_exhausted_stays_hidden", shown(EXHAUSTED), false)
	end

	local function checkStatus(res)
		local function set(rows)
			h.player:SetAttribute("BossStatus", rows and HttpService:JSONEncode(rows) or nil)
		end
		local function cell(id)
			return BAR .. "/Status/Status_" .. id
		end
		local function stackShown(id)
			local stack = h.find(cell(id) .. "/Stack")
			return stack ~= nil and h.visible(stack) and stack.Text ~= ""
		end
		local function look(id)
			local icon = h.find(cell(id) .. "/Icon")
			local parts = { icon and icon.Image or "" }
			for _, d in icon and icon:GetDescendants() or {} do
				if d:IsA("TextLabel") or d:IsA("Frame") then
					table.insert(parts, d.Name .. "=" .. (d:IsA("TextLabel") and d.Text or ""))
				end
			end
			return table.concat(parts, "|")
		end
		local ends = workspace:GetServerTimeNow() + 15
		set({ { Id = "Shouted", EndsAt = ends, Count = 2 }, { Id = "Adapted", EndsAt = ends, Count = 1 } })
		check(res, "status_shouted_shown", waitShown(cell("Shouted"), true), true)
		checkTextSoon(res, "status_stack_x2", cell("Shouted") .. "/Stack", "x2")
		check(res, "status_stack_x2_shown", stackShown("Shouted"), true)
		check(
			res,
			"status_count_1_no_suffix",
			waitIs(function()
				return stackShown("Adapted")
			end, false),
			false
		)
		check(
			res,
			"status_count_2_keeps_seconds",
			string.match(textOf(cell("Shouted") .. "/Seconds"), "^%d+s$") ~= nil,
			true
		)

		set({ { Id = "Vulnerable", Count = 1 } })
		check(res, "status_vulnerable_shown", waitShown(cell("Vulnerable"), true), true)
		local seconds = h.find(cell("Vulnerable") .. "/Seconds")
		local showsDigit = seconds ~= nil and h.visible(seconds) and string.find(seconds.Text, "%d") ~= nil
		check(res, "status_vulnerable_no_seconds", showsDigit, false)
		check(res, "status_vulnerable_no_stack", stackShown("Vulnerable"), false)
		local vulnerable = look("Vulnerable")
		check(res, "status_vulnerable_has_icon", h.find(cell("Vulnerable") .. "/Icon") ~= nil, true)
		check(
			res,
			"status_vulnerable_icon_differs",
			vulnerable ~= look("Shouted") and vulnerable ~= look("Adapted"),
			true
		)
		task.wait(VULNERABLE_HOLDS)
		check(res, "status_vulnerable_holds", shown(cell("Vulnerable")), true)
		set(nil)
		check(res, "status_vulnerable_goes_with_its_row", waitShown(cell("Vulnerable"), false), false)
	end

	local function checkExhaustedCount(res)
		setup(res, "boss_ui_wait:" .. tostring(Cfg.RefillWaitSeconds))
		check(res, "exhausted_panel_shown", waitShown(EXHAUSTED, true), true)
		local first = nil
		local deadline = os.clock() + 0.3
		while first == nil and os.clock() < deadline do
			first = tonumber(textOf(EXHAUSTED .. "/Countdown"))
			task.wait()
		end
		h.check(
			res,
			"exhausted_count_starts_at_8_5",
			first,
			"over 8, at most 8.5",
			type(first) == "number" and first > 8 and first <= Cfg.RefillWaitSeconds
		)
		setup(res, "boss_ui_wait:none")
		check(res, "exhausted_panel_gone", waitShown(EXHAUSTED, false), false)
	end

	local function checkDodgeStage2(res, hp)
		local at = Dodge.Moment(1)
		-- Stage first, so the Phase 1 clock never opens a bar of its own on the way in.
		stage(res, 2, 200, nil, Cfg.IntroSeconds + at - DODGE_LEAD)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + at + OLD_CLOCK_PAST, hp, hp, true)
		check(res, "dodge_stage2_uses_schedule", waitShown(DODGE_BAR, true, DODGE_SHOW_WAIT), true)
		local slider = h.find(DODGE_BAR .. "/Bar/Slider")
		local start = ReplicatedStorage:GetAttribute("BossScheduleStart")
		check(res, "dodge_stage2_fixture", type(start), "number")
		if slider and type(start) == "number" then
			task.wait(0.1)
			local since = workspace:GetServerTimeNow() - start - Cfg.IntroSeconds
			local want = math.clamp(1 - (at - since) / Dodge.SweepFor(2), 0, 1)
			local got = slider.Position.X.Scale
			h.check(
				res,
				"dodge_stage2_sweep",
				got,
				("%.2f +- %.2f"):format(want, SLIDER_SLACK),
				math.abs(got - want) <= SLIDER_SLACK
			)
		end
		state(res, "Idle", 0, 0, 0, false)
		check(res, "dodge_stage2_gone", waitShown(DODGE_BAR, false, SHOW_WAIT), false)
	end

	-- Phase 1's defeat closes teleporting, whatever the time left to join (design doc 4.37). The same fixture in stage 1 proves the Invite would show.
	-- shortcut: the popup's Go is drawn only while open and only a real press opens it, so this reads `joinable` through the Invite and the
	-- button's pulse; to read Go itself, add a UiSpec.Clicks entry with bossPopup and a stage 2 fixture.
	local function checkTeleportClosedInStage2(res, hp)
		stage(res, 1, 90)
		state(res, "Fight", 5, hp, hp, false)
		check(res, "stage2_closed_control_invite_stage1", waitShown(INVITE, true), true)
		stage(res, 2, 200)
		check(res, "stage2_closed_invite_goes", waitShown(INVITE, false), false)
		-- A new event start, so nothing but the stage holds the Invite back.
		state(res, "Fight", 6, hp, hp, false)
		local start = ReplicatedStorage:GetAttribute("BossEventStart")
		local started = waitIs(function()
			start = ReplicatedStorage:GetAttribute("BossEventStart")
			return type(start) == "number" and workspace:GetServerTimeNow() - start < Cfg.JoinSeconds
		end, true)
		check(res, "stage2_closed_inside_join_window", started, true)
		check(res, "stage2_closed_not_in_event", h.player:GetAttribute("BossEvent") == true, false)
		check(res, "stage2_closed_button_shown", waitShown(BUTTON, true), true)
		local pulse = h.find(BUTTON .. "/PulseScale")
		check(res, "stage2_closed_pulse_present", pulse ~= nil, true)
		local invited, pulsed = false, false
		local deadline = os.clock() + CLOSED_HOLD
		while os.clock() < deadline do
			invited = invited or shown(INVITE)
			pulsed = pulsed or (pulse ~= nil and math.abs(pulse.Scale - 1) > PULSE_SLACK)
			task.wait()
		end
		check(res, "stage2_closed_no_invite", invited, false)
		check(res, "stage2_closed_no_pulse", pulsed, false)
		state(res, "Idle", 0, 0, 0, false)
	end

	function scenarios.ui_boss_phase2(res)
		h.waitGuis()
		local hp = Cfg.HpPerPlayer
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:1")
			checkDetails(res)
			checkStage1(res, hp)
			checkScreamAndCascade(res, hp)
			checkLateView(res, hp)
			checkReducedGrowth(res, hp)
			checkStatus(res)
			checkExhaustedCount(res)
			checkExhaustedInScream(res)
			state(res, "Idle", 0, 0, 0, false)
			checkDodgeStage2(res, hp)
			checkTeleportClosedInStage2(res, hp)
		end, debug.traceback)
		h.check(res, "phase2_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		h.player:SetAttribute("BossStatus", nil)
		setup(res, "restore:boss_ui")
	end

	local function fire(res, outcome, damage, stage1, stage2, short)
		setup(
			res,
			("boss_phase2_rewards:%s:%s:%s:%s:%s"):format(
				outcome,
				tostring(damage),
				tostring(stage1),
				tostring(stage2),
				tostring(short)
			)
		)
	end
	local function checkPopup(res, tag, want)
		check(res, tag .. "_shown", waitShown(POPUP, true), true)
		if want.Title then
			checkTextSoon(res, tag .. "_title", POPUP .. "/Header/Title", want.Title)
		end
		local damage = waitIs(function()
			return string.find(textOf(POPUP .. "/Damage"), want.Damage, 1, true) ~= nil
		end, true)
		h.check(res, tag .. "_damage", textOf(POPUP .. "/Damage"), "holds " .. want.Damage, damage == true)
		local function rewardShown(name, part, wanted)
			local value = waitIs(function()
				return shown(POPUP .. "/Rewards/" .. part)
			end, wanted)
			check(res, tag .. "_" .. name, value, wanted)
		end
		rewardShown("raga_chest", "Chest_" .. RAGA_CHEST, want.Raga == true)
		rewardShown("adapted_chest", "Chest_" .. ADAPTED_CHEST, want.Adapted == true)
		rewardShown("money", "Money", want.Raga == true)
		rewardShown("gems", "Gems", want.Adapted == true)
		for chest, wanted in { [RAGA_CHEST] = want.Raga, [ADAPTED_CHEST] = want.Adapted } do
			if wanted then
				local image = h.find(POPUP .. "/Rewards/Chest_" .. chest)
				check(res, tag .. "_image_" .. chest, image and image.Image, RelicConfig.Chests[chest].Image)
			end
		end
		if want.Raga then
			local money = textOf(POPUP .. "/Rewards/Money")
			h.check(res, tag .. "_money_text", money, "holds 100,000", string.find(money, "100,000", 1, true) ~= nil)
		end
		if want.Adapted then
			local gems = textOf(POPUP .. "/Rewards/Gems")
			h.check(res, tag .. "_gems_text", gems, "holds 1,000", string.find(gems, "1,000", 1, true) ~= nil)
		end
		local note = waitIs(function()
			return shown(POPUP .. "/Note")
		end, want.Note == true)
		check(res, tag .. "_note_shown", note, want.Note == true)
		if want.Note then
			check(res, tag .. "_note_text", textOf(POPUP .. "/Note"), "Deal 5% for rewards")
		end
	end
	local function checkPopupFit(res)
		local panel, close = h.find(POPUP), h.find(POPUP .. "/Header/CloseButton")
		check(res, "popup_close_present", close ~= nil and close:IsA("GuiButton"), true)
		if not (panel and close) then
			return
		end
		local view = workspace.CurrentCamera.ViewportSize
		local r = h.rect(panel)
		check(res, "popup_on_screen", r.x >= 0 and r.y >= 0 and r.x + r.w <= view.X and r.y + r.h <= view.Y, true)
		local c = h.rect(close)
		local top = h.topAt(c.x + c.w / 2, c.y + c.h / 2)
		check(res, "popup_close_topmost", top ~= nil and (top == close or close:IsAncestorOf(top)), true)
	end

	function scenarios.ui_boss_rewards(res)
		h.waitGuis()
		local hp = Cfg.HpPerPlayer
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:1")
			check(res, "popup_exists", h.find(POPUP) ~= nil, true)
			check(res, "popup_hidden_at_start", shown(POPUP), false)

			-- Held while in the event, from any message, until BossEvent clears.
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true)
			fire(res, "Defeated", DAMAGE, true, true, false)
			task.wait(GATE_HOLD)
			check(res, "popup_held_in_event", shown(POPUP), false)
			state(res, "Idle", 0, 0, 0, false)
			checkPopup(res, "defeated", { Title = "Raga Defeated!", Damage = DAMAGE_TEXT, Raga = true, Adapted = true })
			checkPopupFit(res)

			fire(res, "Survived", DAMAGE, true, false, false)
			checkPopup(res, "survived", { Title = "Fully Adapted Raga survived", Damage = DAMAGE_TEXT, Raga = true })

			-- Left during Phase 2: the event still runs, this player is out of it.
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, false)
			fire(res, "Left", DAMAGE, true, false, false)
			checkPopup(res, "left", { Title = "Raga Defeated!", Damage = DAMAGE_TEXT, Raga = true })
			state(res, "Idle", 0, 0, 0, false)

			fire(res, "Survived", SHORT_DAMAGE, false, false, true)
			checkPopup(res, "short_none", { Damage = SHORT_DAMAGE_TEXT, Note = true })

			-- Short of Phase 2's share only: Phase 1's pay stands.
			fire(res, "Defeated", DAMAGE, true, false, true)
			checkPopup(
				res,
				"short_stage2",
				{ Title = "Raga Defeated!", Damage = DAMAGE_TEXT, Raga = true, Note = true }
			)

			-- A shown popup does not cover the next event.
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true)
			check(res, "popup_hides_in_event", waitShown(POPUP, false), false)
			state(res, "Idle", 0, 0, 0, false)
		end, debug.traceback)
		h.check(res, "rewards_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		setup(res, "restore:boss_ui")
	end

	-- After the real press of Panel/Header/CloseButton (UiSpec.Clicks boss_rewards_close).
	function after.boss_rewards_closed(res)
		check(res, "popup_close_closes", waitShown(POPUP, false), false)
	end

	-- After the real press that opens the Bosses popup idle (UiSpec.Clicks boss_paid_details): every line of both tables on screen.
	function after.boss_details_both_tables(res)
		local details = h.find(DETAILS)
		check(res, "details_both_shown", details ~= nil and h.visible(details), true)
		local view = workspace.CurrentCamera.ViewportSize
		local off = {}
		for _, row in RelicConfig.ChestOdds(ADAPTED_CHEST) do
			local label = h.find(DETAILS .. "/Adapted_" .. row.Id)
			local r = label and h.rect(label)
			if not (r and h.visible(label) and r.y >= 0 and r.y + r.h <= view.Y) then
				table.insert(off, row.Id)
			end
		end
		h.checkList(res, "details_adapted_rows_on_screen", off)
	end

	return { Scenarios = scenarios, After = after }
end

return Module
