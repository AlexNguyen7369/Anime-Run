--!nonstrict
-- The Elf Mage, the second boss (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"; boss-mage task T1). Owned
-- by ui-test-writer. Red first: written before Client/BossOsuUi and the per-boss UI. Driven by UiTestSetup boss_ui_* fixtures, as
-- UiBossEvent, plus boss_ui_boss:<id> (ReplicatedStorage BossEventBoss) and boss_ui_osu_spy (a logging Remotes.BossOsu).
--
-- Contract these checks assume beyond the brief (boss-mage-code-plan.md section 4; implementer: report a change, do not loosen):
--   Shared/BossCatalog, Shared/BossMageArt (StaffIcon, OsuCircle, OsuRing, OsuHit, OsuMiss, StatusCrushed, Portrait), Shared/BossOsu,
--     BossDodge.Moment(index, boss).
--   Client/BossEventUi reads BossCatalog.Current() at use time: Warning text, BossBar/Title, Invite texts, TeamHud/RagaPortrait (the
--     name is kept) and BossesPanel Status follow BossEventBoss. BossBar/Status/Status_Crushed's Icon shows BossMageArt.StatusCrushed.
--   Client/BossDodgeUi: DodgeBar/Wheel.Image is BossCatalog.Current().DodgeIcon or RelicConfig.WheelArt; no bar on a Slam moment.
--   Client/BossOsuUi: ScreenGui RacerBossOsu with Circle1..Circle4 (GuiButtons) directly in it, each with a GuiObject Ring whose
--     AbsoluteSize closes from 3x to 1x the circle's over ApproachSeconds. Active under the Dodge bar's rule (BossEvent true, Fight,
--     BossEventStart set, no BossWaitEndsAt): a fixture cannot give the client a run, so "has a run" is not required here.
--     Circle k shows at moment - Lead_k - ApproachSeconds, with moment = BossEventStart + PrepSeconds + IntroSeconds +
--     BossDodge.Moment(index, "boss_mage") and Lead from BossOsu.Circles(LocalPlayer.UserId, BossEventStart, index).
--   TEST SEAM (a LocalScript cannot fire Activated): each Circle<k> holds a BindableEvent named Press; Press:Fire() runs exactly
--     what Activated runs (stamp = workspace:GetServerTimeNow(), InvokeServer(index, k, stamp)).
--   A press shows an image with BossMageArt.OsuHit or OsuMiss (by BossOsu.Judge) somewhere in RacerBossOsu. "Nice Dodge!" in gold
--     after a true, "Dodged" answer; otherwise BossDodge.HitText.Slam in red at the moment, in RacerBossOsu or RacerBossDodge.
--   Mage arena (Client/BossArenaView): workspace.BossArenaPreview holds Models ElfMage (with part Torso, the TargetPart) and Golem;
--     no BigRaga while BossEventBoss is boss_mage. Effects live in Folder BossEffects; BossVfxForce plays Lightning, Slam, Barrage.
--     The golem's BaseParts are all Transparency 1 outside the golem move.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("BossEventConfig"))
local RelicConfig = require(Shared:WaitForChild("RelicConfig"))
-- pcall: a BossDodge that fails to load (its pose modules) fails these scenarios, not the whole UI harness.
local _, BossDodge = pcall(require, Shared:WaitForChild("BossDodge"))

local MAGE = "boss_mage"
local ROOT = "RacerBossEvent"
local INVITE = ROOT .. "/Invite"
local HUD = ROOT .. "/TeamHud"
local WARNING = ROOT .. "/Warning"
local BAR = ROOT .. "/BossBar"
local BOSSES = ROOT .. "/BossesPanel"
local DODGE = "RacerBossDodge/DodgeBar"
local RESULT = "RacerBossDodge/Result"
local OSU = "RacerBossOsu"
local POPUP = "RacerBossRewards/Panel"

-- Owner 2026-11-11 (design doc 4.37) and the plan's proposed texts.
local NAME = "The Elf Mage"
local WARNING_TEXT = "The Elf Mage has awakened, take her down!!!"
local ACTIVE_TEXT = "The Elf Mage is casting right now"
local INVITE_TITLE = "THE ELF MAGE EVENT"
local INVITE_HINT = "Teleport to fight The Elf Mage before the timer ends"
local DEFEATED_TITLE = "The Elf Mage Defeated!"
local LIGHTNING_HIT = "You were struck by her lightning"
local SLAM_HIT = "The golem crushed you"
local DODGE_TEXT = "Nice Dodge!"
local DIAMETER, DIAMETER_PHONE = 0.12, 0.16 -- of the screen height (spec, proposed)
local MIDDLE = 0.2 -- the middle 60%: 20% margins on each side
local PHONE_MAX_HEIGHT = 500
local SHOW_SLACK = 0.15 -- s around a circle's appearance
local RING_START_MIN = 2.5 -- ring over circle when it shows (3x, a frame or two in)
local RING_BEAT_SLACK = 0.15
local STAMP_SLACK = 0.1 -- s between the press and the spied stamp
local LEAD_IN = 0.5 -- s before the circles open at which a run is set up
local SHOW_WAIT = 2
local BUILD_WAIT = 8
local PRIMITIVE_MAX = 1150 -- plan section 5 (budget about 1,050)
local PEAK_WATCH = 1.5
local SCAN = 40

local Module = {}

local function optional(name)
	local source = Shared:FindFirstChild(name)
	local ok, value = pcall(function()
		return source and require(source)
	end)
	return ok and type(value) == "table" and value or nil
end

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
	local function state(res, phase, elapsed, hp, max, inEvent, damage)
		setup(
			res,
			("boss_ui_state:%s:%s:%s:%s:%s:%s"):format(
				phase,
				tostring(elapsed),
				tostring(hp or 0),
				tostring(max or 0),
				tostring(inEvent == true),
				tostring(damage or "none")
			)
		)
	end
	local function boss(res, id)
		setup(res, "boss_ui_boss:" .. (id or "none"))
	end
	local function shown(path)
		local object = h.find(path)
		return object ~= nil and object:IsA("GuiObject") and h.visible(object)
	end
	local function waitIs(fn, want, seconds)
		local deadline = os.clock() + (seconds or SHOW_WAIT)
		local value = fn()
		while value ~= want and os.clock() < deadline do
			task.wait(0.05)
			value = fn()
		end
		return value
	end
	local function waitShown(path, want, seconds)
		return waitIs(function()
			return shown(path)
		end, want, seconds)
	end
	local function hasText(path, text)
		local root = h.find(path)
		for _, d in root and root:GetDescendants() or {} do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text == text then
				return d
			end
		end
		return nil
	end
	local function textOf(path)
		local label = h.find(path)
		return label and (label:IsA("TextLabel") or label:IsA("TextButton")) and label.Text or ""
	end
	local function firstMoment(name)
		for index = 1, SCAN do
			local at, got = BossDodge.Moment(index, MAGE)
			if got == name then
				return index, at
			end
		end
		return nil
	end
	local function crossing(a, b)
		return a.x + a.w > b.x and b.x + b.w > a.x and a.y + a.h > b.y and b.y + b.h > a.y
	end

	-- Per-boss texts, the versus portrait and the Crushed status.
	function scenarios.ui_boss_mage(res)
		h.waitGuis()
		local Catalog, Art = optional("BossCatalog"), optional("BossMageArt")
		check(res, "mage_catalog_loads", Catalog ~= nil, true)
		check(res, "mage_art_loads", Art ~= nil, true)
		local hp = Cfg.HpPerPlayer
		local savedStatus = h.player:GetAttribute("BossStatus")
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			state(res, "Idle", 0)
			boss(res, MAGE)
			state(res, "Prep", 5, 0, 0, false)
			check(res, "mage_invite_shown", waitShown(INVITE, true), true)
			check(
				res,
				"mage_invite_title",
				waitIs(function()
					return hasText(INVITE, INVITE_TITLE) ~= nil
				end, true),
				true
			)
			check(res, "mage_invite_hint", hasText(INVITE, INVITE_HINT) ~= nil, true)

			state(res, "Prep", 5, hp, hp, true, 1234)
			check(res, "mage_team_hud_shown", waitShown(HUD, true), true)
			local portrait = h.find(HUD .. "/RagaPortrait")
			check(
				res,
				"mage_versus_portrait",
				waitIs(function()
					return portrait and portrait.Image
				end, Art and Art.Portrait),
				Art and Art.Portrait
			)

			state(res, "Prep", Cfg.PrepSeconds - 0.5, hp, hp, true, 100)
			waitShown(HUD, true)
			state(res, "Fight", "keep", hp, hp, true, 100)
			check(res, "mage_bar_shown", waitShown(BAR, true), true)
			check(
				res,
				"mage_warning_text",
				waitIs(function()
					return hasText(WARNING, WARNING_TEXT) ~= nil
				end, true),
				true
			)
			check(
				res,
				"mage_bar_title",
				waitIs(function()
					return textOf(BAR .. "/Title")
				end, NAME),
				NAME
			)

			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true, 100)
			local now = workspace:GetServerTimeNow()
			h.player:SetAttribute(
				"BossStatus",
				HttpService:JSONEncode({ { Id = "Crushed", EndsAt = now + 12, Count = 1 } })
			)
			local CELL = BAR .. "/Status/Status_Crushed"
			check(res, "mage_crushed_shown", waitShown(CELL, true), true)
			local cell = h.find(CELL)
			local icon, seconds = cell and cell:FindFirstChild("Icon"), cell and cell:FindFirstChild("Seconds")
			check(res, "mage_crushed_icon_is_image", icon ~= nil and icon:IsA("ImageLabel"), true)
			check(res, "mage_crushed_icon_art", icon and icon.Image, Art and Art.StatusCrushed)
			local text = seconds and seconds:IsA("TextLabel") and seconds.Text or ""
			check(res, "mage_crushed_seconds_format", string.match(text, "^%d+s$") ~= nil, true)
			h.player:SetAttribute("BossStatus", nil)

			-- Back to Big Raga: his texts return with the attribute.
			boss(res, nil)
			check(
				res,
				"raga_bar_title_back",
				waitIs(function()
					return textOf(BAR .. "/Title")
				end, "Big Raga"),
				"Big Raga"
			)
		end, debug.traceback)
		h.check(res, "mage_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		h.player:SetAttribute("BossStatus", savedStatus)
		setup(res, "restore:boss_ui")
	end

	-- After the real press (UiSpec.Clicks boss_mage_button): her line in the Bosses popup.
	function after.boss_mage_panel_casting(res)
		check(res, "mage_panel_opens", waitShown(BOSSES, true), true)
		local status = h.find(BOSSES) and h.find(BOSSES):FindFirstChild("Status", true)
		check(
			res,
			"mage_panel_status",
			waitIs(function()
				return status and status.Text
			end, ACTIVE_TEXT),
			ACTIVE_TEXT
		)
	end

	-- Her staff on the Dodge bar; Raga keeps his wheel.
	function scenarios.ui_boss_mage_dodge(res)
		local Art = optional("BossMageArt")
		check(res, "mage_art_loads", Art ~= nil, true)
		local hp = Cfg.HpPerPlayer
		local lead = BossDodge.SweepFor(1) * 0.5
		local ok, err = xpcall(function()
			local index, at = firstMoment("Lightning")
			check(res, "mage_lightning_moment_found", index ~= nil, true)
			if index then
				state(res, "Idle", 0)
				boss(res, MAGE)
				state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + at - lead, hp, hp, true, 100)
				check(res, "mage_dodge_bar_shown", waitShown(DODGE, true, lead), true)
				local bar = h.find(DODGE)
				local wheel = bar and bar:FindFirstChild("Wheel")
				check(res, "mage_dodge_staff_icon", wheel and wheel.Image, Art and Art.StaffIcon)
				check(res, "mage_dodge_hit_shows", waitShown(RESULT, true, lead + 1), true)
				check(res, "mage_dodge_hit_words", textOf(RESULT), LIGHTNING_HIT)
			end
			state(res, "Idle", 0)
			boss(res, nil)
			local ragaAt = BossDodge.Moment(1)
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + ragaAt - lead, hp, hp, true, 100)
			check(res, "raga_dodge_bar_shown", waitShown(DODGE, true, lead), true)
			local bar = h.find(DODGE)
			local wheel = bar and bar:FindFirstChild("Wheel")
			check(res, "raga_dodge_wheel_art", wheel and wheel.Image, RelicConfig.WheelArt)
		end, debug.traceback)
		h.check(res, "mage_dodge_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	-- One Slam's circles, watched frame by frame. presses[k] = seconds from circle k's beat to press it (nil: never pressed).
	local function watchSlam(res, Osu, index, at, presses, inWait)
		local hp = Cfg.HpPerPlayer
		local before = ReplicatedStorage:GetAttribute("BossEventStart")
		state(res, "Idle", 0)
		boss(res, MAGE)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + at - Osu.OpenSeconds - LEAD_IN, hp, hp, true, 100)
		if inWait then
			setup(res, "boss_ui_wait:30") -- after the state: boss_ui_state:Idle clears it
		end
		local startAt = ReplicatedStorage:GetAttribute("BossEventStart")
		local deadline = os.clock() + SHOW_WAIT
		while (startAt == nil or startAt == before) and os.clock() < deadline do
			task.wait(0.05)
			startAt = ReplicatedStorage:GetAttribute("BossEventStart")
		end
		local moment = startAt + Cfg.PrepSeconds + Cfg.IntroSeconds + at
		local rows = Osu.Circles(h.player.UserId, startAt, index)
		local seen = { Shown = {}, Rect = {}, RingFirst = {}, RingBeat = {}, BeatGap = {}, Pressed = {} }
		local Art = optional("BossMageArt") or {}
		local function scanImages(root)
			for _, d in root and root:GetDescendants() or {} do
				if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and h.visible(d) then
					seen.Hit = seen.Hit or (Art.OsuHit ~= nil and d.Image == Art.OsuHit)
					seen.Miss = seen.Miss or (Art.OsuMiss ~= nil and d.Image == Art.OsuMiss)
				end
			end
		end
		local function scanTexts(root)
			for _, d in root and root:GetDescendants() or {} do
				if d:IsA("TextLabel") and h.visible(d) then
					if d.Text == DODGE_TEXT then
						seen.Gold = seen.Gold or d.TextColor3
					elseif d.Text == SLAM_HIT then
						seen.Red = seen.Red or d.TextColor3
					end
				end
			end
		end
		while workspace:GetServerTimeNow() < moment + 1.2 do
			local now = workspace:GetServerTimeNow()
			local gui = h.find(OSU)
			seen.DodgeBar = seen.DodgeBar or shown(DODGE)
			for k, row in rows do
				local circle = h.find(OSU .. "/Circle" .. k)
				local beat = moment - row.Lead
				if circle and shown(OSU .. "/Circle" .. k) then
					local ring = circle:FindFirstChild("Ring")
					local ratio = ring
						and ring:IsA("GuiObject")
						and circle.AbsoluteSize.X > 0
						and ring.AbsoluteSize.X / circle.AbsoluteSize.X
					if not seen.Shown[k] then
						seen.Shown[k] = now
						seen.RingFirst[k] = ratio
					end
					local gap = math.abs(now - beat)
					if seen.BeatGap[k] == nil or gap < seen.BeatGap[k] then
						seen.BeatGap[k], seen.RingBeat[k], seen.Rect[k] = gap, ratio, h.rect(circle)
					end
				end
				local offset = presses[k]
				if offset and not seen.Pressed[k] and now >= beat + offset then
					local press = circle and circle:FindFirstChild("Press")
					seen.Pressed[k] = now
					if press and press:IsA("BindableEvent") then
						press:Fire()
					end
				end
			end
			scanImages(gui)
			scanTexts(gui)
			scanTexts(h.find("RacerBossDodge"))
			RunService.Heartbeat:Wait()
		end
		return seen, rows, moment
	end

	local function spyLog()
		local raw = ReplicatedStorage:GetAttribute("UiTestBossOsuLog")
		local ok, list = pcall(HttpService.JSONDecode, HttpService, raw or "[]")
		return ok and list or {}
	end

	function scenarios.ui_boss_osu(res)
		h.waitGuis()
		local Osu, Art = optional("BossOsu"), optional("BossMageArt")
		check(res, "osu_module_loads", Osu ~= nil, true)
		check(res, "mage_art_loads", Art ~= nil, true)
		local index, at = firstMoment("Slam")
		check(res, "osu_slam_moment_found", index ~= nil, true)
		if not (Osu and index) then
			return
		end
		local ok, err = xpcall(function()
			setup(res, "boss_ui_osu_spy")
			check(
				res,
				"osu_gui_present",
				waitIs(function()
					return h.find(OSU) ~= nil
				end, true),
				true
			)

			-- All four on the beat: dodged.
			local seen, rows, moment = watchSlam(res, Osu, index, at, { 0, 0, 0, 0 })
			check(res, "osu_no_dodge_bar", seen.DodgeBar == true, false)
			local view = workspace.CurrentCamera.ViewportSize
			local touchOnly = UserInputService.TouchEnabled
				and not UserInputService.MouseEnabled
				and not UserInputService.KeyboardEnabled
			local share = (view.Y < PHONE_MAX_HEIGHT or touchOnly) and DIAMETER_PHONE or DIAMETER
			local hud = {}
			for _, path in { BAR, ROOT .. "/DropList", ROOT .. "/LeaveButton", "RacerHud/Level/Team" } do
				local object = h.find(path)
				if object and shown(path) then
					hud[path] = h.rect(object)
				end
			end
			local lastShown = -math.huge
			for k = 1, 4 do
				local want = moment - rows[k].Lead - Osu.ApproachSeconds
				local got = seen.Shown[k]
				h.check(
					res,
					"osu_circle_" .. k .. "_appears_on_time",
					got and got - want or "never shown",
					"0 +- " .. SHOW_SLACK,
					got ~= nil and math.abs(got - want) <= SHOW_SLACK
				)
				check(res, "osu_circle_" .. k .. "_in_order", got ~= nil and got > lastShown, true)
				lastShown = got or lastShown
				local r = seen.Rect[k]
				if r then
					local px = share * view.Y
					h.check(res, "osu_circle_" .. k .. "_size", r.h, ">= " .. px, r.h >= px - 1 and r.w >= px - 1)
					local inside = r.x >= MIDDLE * view.X
						and r.x + r.w <= (1 - MIDDLE) * view.X
						and r.y >= MIDDLE * view.Y
						and r.y + r.h <= (1 - MIDDLE) * view.Y
					check(res, "osu_circle_" .. k .. "_in_middle_60", inside, true)
					for path, other in hud do
						check(res, "osu_circle_" .. k .. "_clear_of_" .. path, crossing(r, other), false)
					end
					for j = 1, k - 1 do
						local o = seen.Rect[j]
						if o then
							local d = (Vector2.new(r.x + r.w / 2, r.y + r.h / 2) - Vector2.new(
								o.x + o.w / 2,
								o.y + o.h / 2
							)).Magnitude
							local need = math.max(r.h, o.h)
							h.check(res, ("osu_circles_%d_%d_apart"):format(j, k), d, ">= " .. need, d >= need - 1)
						end
					end
				end
				local first, beat = seen.RingFirst[k], seen.RingBeat[k]
				h.check(
					res,
					"osu_ring_" .. k .. "_starts_wide",
					first or "no Ring",
					">= " .. RING_START_MIN,
					type(first) == "number" and first >= RING_START_MIN
				)
				h.check(
					res,
					"osu_ring_" .. k .. "_meets_circle_at_beat",
					beat or "no Ring",
					"1 +- " .. RING_BEAT_SLACK,
					type(beat) == "number" and math.abs(beat - 1) <= RING_BEAT_SLACK
				)
			end
			local log = spyLog()
			local per = {}
			for _, entry in log do
				per[entry[2]] = (per[entry[2]] or 0) + 1
				check(res, "osu_press_index_" .. tostring(entry[2]), entry[1], index)
				local pressed = seen.Pressed[entry[2]]
				h.check(
					res,
					"osu_press_stamp_" .. tostring(entry[2]),
					pressed and entry[3] and entry[3] - pressed or "none",
					"0 +- " .. STAMP_SLACK,
					pressed ~= nil and type(entry[3]) == "number" and math.abs(entry[3] - pressed) <= STAMP_SLACK
				)
			end
			for k = 1, 4 do
				check(res, "osu_press_once_circle_" .. k, per[k], 1)
			end
			check(res, "osu_hit_art_shown", seen.Hit == true, true)
			local gold = seen.Gold
			check(res, "osu_dodged_gold_text", gold ~= nil and gold.R > 0.85 and gold.G > 0.6 and gold.B < 0.45, true)
			check(res, "osu_dodged_no_hit_text", seen.Red ~= nil, false)

			-- One early press, two never pressed: missed and hit.
			setup(res, "boss_ui_osu_spy") -- a fresh log
			seen = watchSlam(res, Osu, index, at, { 0, -0.45 })
			check(res, "osu_miss_art_shown", seen.Miss == true, true)
			local red = seen.Red
			check(res, "osu_miss_hit_text_red", red ~= nil and red.R > 0.9 and red.G < 0.3, true)
			check(res, "osu_miss_no_gold", seen.Gold ~= nil, false)
			check(res, "osu_miss_presses_sent", #spyLog(), 2)

			-- In the wait: no circles.
			seen = watchSlam(res, Osu, index, at, {}, true)
			check(res, "osu_hidden_in_wait", next(seen.Shown) ~= nil, false)
			setup(res, "boss_ui_wait:none")
		end, debug.traceback)
		h.check(res, "osu_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	function scenarios.ui_boss_mage_rewards(res)
		h.waitGuis()
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:1")
			state(res, "Idle", 0)
			setup(res, "boss_phase2_rewards:Defeated:1234567:true:false:false:0.12:" .. MAGE)
			check(res, "mage_rewards_shown", waitShown(POPUP, true), true)
			check(
				res,
				"mage_rewards_title",
				waitIs(function()
					return textOf(POPUP .. "/Header/Title")
				end, DEFEATED_TITLE),
				DEFEATED_TITLE
			)
			setup(res, "boss_phase2_rewards:Defeated:1234567:true:false:false:0.12")
			check(
				res,
				"raga_rewards_title_kept",
				waitIs(function()
					return textOf(POPUP .. "/Header/Title")
				end, "Raga Defeated!"),
				"Raga Defeated!"
			)
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, true)
			waitShown(POPUP, false)
		end, debug.traceback)
		h.check(res, "mage_rewards_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	-- Her arena, the golem and her effects.
	function scenarios.ui_boss_mage_vfx(res)
		local Poses = optional("BossMagePoses")
		check(res, "mage_poses_loads", Poses ~= nil, true)
		if not Poses then
			return
		end
		local function inArena(name)
			local folder = workspace:FindFirstChild("BossArenaPreview")
			return folder and folder:FindFirstChild(name, true)
		end
		local function waitFor(fn, seconds)
			local deadline = os.clock() + seconds
			local value = fn()
			while not value and os.clock() < deadline do
				task.wait(0.05)
				value = fn()
			end
			return value
		end
		local function shownParts(model)
			local n = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 1 then
					n += 1
				end
			end
			return n
		end
		-- Seconds since the spawn at which `move` plays at local time from..to, and holds for `hold` s.
		local function timeOf(move, from, to, hold)
			for s = Cfg.IntroSeconds + 1, Cfg.IntroSeconds + 2 * Poses.CycleSeconds, 0.05 do
				local all = true
				for t = 0, hold, 0.25 do
					local name, localTime = Poses.Schedule(0, s + t)
					all = all and name == move and (t > 0 or (localTime >= from and localTime <= to))
				end
				if all then
					return s
				end
			end
			return nil
		end
		local function peak(name)
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", name)
			local most, stop = 0, os.clock() + PEAK_WATCH
			while os.clock() < stop do
				local effects = inArena("BossEffects")
				local n = 0
				for _, d in effects and effects:GetDescendants() or {} do
					if d:IsA("BasePart") or d:IsA("ParticleEmitter") or d:IsA("Beam") then
						n += 1
					end
				end
				most = math.max(most, n)
				task.wait(0.05)
			end
			return most
		end
		local savedReduce = h.player:GetAttribute("ReduceEffects")
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			h.player:SetAttribute("ReduceEffects", nil)
			state(res, "Idle", 0)
			boss(res, MAGE)
			state(res, "Prep", 5, 4000, 4000, true, 100)
			local mage = waitFor(function()
				return inArena("ElfMage")
			end, BUILD_WAIT)
			local golem = waitFor(function()
				return inArena("Golem")
			end, BUILD_WAIT)
			check(res, "mage_model_present", mage ~= nil and mage:IsA("Model"), true)
			check(res, "golem_model_present", golem ~= nil and golem:IsA("Model"), true)
			check(res, "mage_target_part_present", mage ~= nil and mage:FindFirstChild("Torso", true) ~= nil, true)
			check(
				res,
				"raga_not_built_for_mage",
				waitFor(function()
					return inArena("BigRaga") == nil
				end, SHOW_WAIT),
				true
			)
			local primitives = 0
			local folder = workspace:FindFirstChild("BossArenaPreview")
			local effects = inArena("BossEffects")
			for _, d in folder and folder:GetDescendants() or {} do
				if d:IsA("BasePart") and not d:IsA("MeshPart") and not (effects and d:IsDescendantOf(effects)) then
					primitives += 1
				end
			end
			h.check(
				res,
				"arena_primitives",
				primitives,
				"<= " .. PRIMITIVE_MAX,
				primitives > 0 and primitives <= PRIMITIVE_MAX
			)
			if not (mage and golem) then
				return
			end

			local idleAt = timeOf("idle", 0, math.huge, 1)
			local golemAt = timeOf("golem", 2.4, 2.6, 0.5)
			check(res, "schedule_has_idle", idleAt ~= nil, true)
			check(res, "schedule_has_golem", golemAt ~= nil, true)
			if idleAt then
				state(res, "Fight", Cfg.PrepSeconds + idleAt, 4000, 4000, true, 100)
				task.wait(0.4)
				check(res, "golem_hidden_outside_its_move", shownParts(golem), 0)
			end
			if golemAt then
				state(res, "Fight", Cfg.PrepSeconds + golemAt, 4000, 4000, true, 100)
				check(res, "golem_shown_in_its_move", waitFor(function()
					return shownParts(golem) > 0
				end, 0.6) == true, true)
			end

			state(res, "Fight", Cfg.PrepSeconds + (idleAt or Cfg.IntroSeconds + 1), 4000, 4000, true, 100)
			local full = {}
			for _, name in { "Lightning", "Slam", "Barrage" } do
				full[name] = peak(name)
				h.check(res, "full_" .. string.lower(name) .. "_effects", full[name], "> 0", full[name] > 0)
			end
			h.player:SetAttribute("ReduceEffects", true)
			for _, name in { "Lightning", "Slam", "Barrage" } do
				local reduced = peak(name)
				h.check(
					res,
					"reduced_" .. string.lower(name) .. "_fewer",
					reduced,
					"> 0 and < " .. full[name],
					reduced > 0 and reduced < full[name]
				)
			end
		end, debug.traceback)
		h.check(res, "mage_vfx_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		ReplicatedStorage:SetAttribute("BossVfxForce", nil)
		h.player:SetAttribute("ReduceEffects", savedReduce)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	return { Scenarios = scenarios, After = after }
end

return Module
