--!nonstrict
-- Boss event UI (design doc 4.37, docs/BOSS_EVENT_SPEC.md Flow and Team HUD, Client/BossEventUi). Owned by ui-test-writer.
-- ui_boss drives the published attributes through UiTestSetup boss_ui_* and never joins an event; the real presses are
-- the boss_* clicks in UiSpec.Clicks, judged after them here.
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   Every part is built once and only hidden: Invite, TeamHud, Warning, BossBar, LeaveButton sit directly in the ScreenGui.
--   Named anywhere inside their part: Invite Countdown; TeamHud Countdown; BossBar Name, Value, Fill (its parent is the track).
--   TeamHud/List: one GuiButton per eligible character, directly in List, named its character id.
--   Slot<n> has attribute CharacterId while it holds a character, none while it is empty.
--   Invite Countdown counts to teleport closing (3:00), TeamHud Countdown to the spawn (1:00). "m:ss" or plain seconds.
--   Decline lasts for one event (one BossEventStart): a new start shows the Invite again.
--   Remotes are found when pressed (WaitForChild in Activated): progression_spy swaps them for logging proxies.
--   The Fill follows BossEventStart, not a local tween from the moment it showed: a late joiner sees the right width.
--   The BossBar pops through UiMotion.Pop (UIScale MotionScale). LeaveButton hides while a PanelSwitch panel is open.
--   The Warning frame is the plate: red and opaque, its flash stays red, white heavy text on it. No flash with reduced motion.
--   The Invite waits while a save is in the starter pick or the roll tutorial (boss_ui_gear sets a save past both).
-- READINGS the docs leave open, for the owner (names start with reading_):
--   a Sidekick only in the Bag, on no character, locks the Invite: the server refuses that join ("Needs a Sidekick").
-- Invite and TeamHud are not UiSpec Panels (Panels must be PanelSwitch ones and close each other, the Invite must not), so
-- ui_layout does not see them; their fit at desktop is judged here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Cfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BossEventConfig"))
local Spec = require(script.Parent.UiSpec)

local ROOT = "RacerBossEvent"
local INVITE = ROOT .. "/Invite"
local TELEPORT = INVITE .. "/TeleportButton"
local DECLINE = INVITE .. "/DeclineButton"
local HUD = ROOT .. "/TeamHud"
local LIST = HUD .. "/List"
local WARNING = ROOT .. "/Warning"
local BAR = ROOT .. "/BossBar"
local LEAVE = ROOT .. "/LeaveButton"
local PARTS = { Invite = INVITE, TeamHud = HUD, Warning = WARNING, BossBar = BAR, LeaveButton = LEAVE }

local NOTE_TEXT = "Only characters with Sidekicks can be equipped for bosses"
local WARNING_TEXT = "Big Raga has emerged, take him down!!!"
local BOSS_NAME = "Big Raga"

local SHOW_WAIT = 2 -- s: an attribute change has replicated and the UI has followed
local WARNING_MAX = 12 -- s: proposed, "goes away by itself" has no number in the docs
local WARNING_QUIET = 1 -- s hidden in a row before a flashing Warning counts as gone
local FLASH_SAMPLE = 3 -- s the Warning and the intro fill are watched
local COUNTDOWN_SLACK = 2 -- s
local RATIO_SLACK = 0.02
local BUDGET = 40 -- s: the whole scenario
local PHONE_MAX_HEIGHT = 500
local MIN_WARNING_HEIGHT = 40 -- px at desktop: "big"
local BAR_CENTRE_SLACK = 0.05 -- of the screen width
local BAR_MAX_BOTTOM = 0.3 -- of the screen height: "top middle"
local PLATE_MAX_TRANSPARENCY = 0.1
local MIN_TEXT_CONTRAST = 3 -- WCAG large text

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
	local function gear(res, how)
		setup(res, "boss_ui_gear:" .. tostring(how))
	end
	-- elapsed = "keep" leaves BossEventStart alone. phase "Idle" clears the event; damage "none" clears BossTeamDamage.
	local function state(res, phase, elapsed, hp, max, inEvent, damage)
		setup(
			res,
			("boss_ui_state:%s:%s:%s:%s:%s:%s"):format(
				phase,
				tostring(elapsed),
				tostring(hp),
				tostring(max),
				tostring(inEvent),
				tostring(damage or "none")
			)
		)
	end

	local function shown(path)
		local object = h.find(path)
		return object ~= nil and object:IsA("GuiObject") and h.visible(object)
	end
	-- Polls until fn() equals want; returns the last value.
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
	-- `want` names the parts that must show; every other part must not. A part in `skip` is not judged.
	local function onlyShown(res, tag, want, skip)
		for name, path in PARTS do
			if not (skip and skip[name]) then
				check(
					res,
					tag .. "_" .. string.lower(name) .. "_shown",
					waitShown(path, want[name] == true),
					want[name] == true
				)
			end
		end
	end

	local function textObjects(root)
		local list = {}
		for _, d in root and root:GetDescendants() or {} do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
				table.insert(list, d)
			end
		end
		if root and (root:IsA("TextLabel") or root:IsA("TextButton")) and root.Text ~= "" then
			table.insert(list, root)
		end
		return list
	end
	local function hasText(path, text)
		for _, label in textObjects(h.find(path)) do
			if label.Text == text then
				return label
			end
		end
		return nil
	end
	local function shownTextHas(path, piece)
		for _, label in textObjects(h.find(path)) do
			if h.visible(label) and string.find(string.lower(label.Text), piece, 1, true) then
				return true
			end
		end
		return false
	end
	local function named(partPath, name)
		local part = h.find(partPath)
		return part and part:FindFirstChild(name, true)
	end
	local function textOf(partPath, name)
		local label = named(partPath, name)
		return label and (label:IsA("TextLabel") or label:IsA("TextButton")) and label.Text or ""
	end
	local function digits(text)
		return (string.gsub(text, ",", ""))
	end
	local function secondsIn(text)
		local minutes, seconds = string.match(text, "(%d+):(%d%d)")
		if minutes then
			return tonumber(minutes) * 60 + tonumber(seconds)
		end
		return tonumber(string.match(text, "%d+"))
	end
	local function checkCountdown(res, name, partPath, want)
		local got = secondsIn(textOf(partPath, "Countdown"))
		h.check(
			res,
			name,
			got or "no seconds in the text",
			("%d +- %d"):format(want, COUNTDOWN_SLACK),
			got ~= nil and math.abs(got - want) <= COUNTDOWN_SLACK
		)
	end
	local function fillRatio()
		local fill = named(BAR, "Fill")
		if not (fill and fill:IsA("GuiObject") and fill.Parent:IsA("GuiObject")) or fill.Parent.AbsoluteSize.X <= 0 then
			return nil
		end
		return fill.AbsoluteSize.X / fill.Parent.AbsoluteSize.X
	end
	local function checkRatio(res, name, want)
		local got
		waitIs(function()
			got = fillRatio()
			return got ~= nil and math.abs(got - want) <= RATIO_SLACK
		end, true)
		h.check(
			res,
			name,
			got or "no Fill",
			("%.3f +- %.2f"):format(want, RATIO_SLACK),
			got ~= nil and math.abs(got - want) <= RATIO_SLACK
		)
	end
	local function crossing(a, b)
		local t = Spec.Tolerance
		return a.x + a.w > b.x + t and b.x + b.w > a.x + t and a.y + a.h > b.y + t and b.y + b.h > a.y + t
	end
	local function within(outer, r)
		local t = Spec.Tolerance
		return r.x >= outer.x - t
			and r.y >= outer.y - t
			and r.x + r.w <= outer.x + outer.w + t
			and r.y + r.h <= outer.y + outer.h + t
	end
	local function isDesktop()
		return workspace.CurrentCamera.ViewportSize.Y > PHONE_MAX_HEIGHT
	end

	-- Everything that shows now: no two texts cross, each fits and stays on screen. At desktop, nothing of the event but the
	-- Warning sits on a shown always-on HUD element (the BossBar replaces the roll, which hides in the event).
	local function checkFit(res, tag)
		if not isDesktop() then
			return -- this scenario judges the fit at desktop only
		end
		local texts = {}
		for _, label in textObjects(h.find(ROOT)) do
			if h.visible(label) then
				table.insert(texts, label)
			end
		end
		local size = workspace.CurrentCamera.ViewportSize
		local screen = { x = 0, y = 0, w = size.X, h = size.Y }
		local overlaps, clipped, outside = {}, {}, {}
		for i, a in texts do
			local ra = h.rect(a)
			if not a.TextFits then
				table.insert(clipped, a:GetFullName())
			end
			if not within(screen, ra) then
				table.insert(outside, a:GetFullName())
			end
			for j = i + 1, #texts do
				local b = texts[j]
				if not a:IsAncestorOf(b) and not b:IsAncestorOf(a) and crossing(ra, h.rect(b)) then
					table.insert(overlaps, a.Name .. " x " .. b.Name)
				end
			end
		end
		h.checkList(res, tag .. "_no_text_overlap", overlaps)
		h.checkList(res, tag .. "_text_fits", clipped)
		h.checkList(res, tag .. "_text_on_screen", outside)
		local onHud = {}
		for name, path in PARTS do
			if name ~= "Warning" and shown(path) then
				local r = h.rect(h.find(path))
				for guiName, gui in Spec.Guis do
					for _, element in gui.AlwaysOn or {} do
						local other = h.find(guiName .. "/" .. element)
						if
							guiName ~= ROOT
							and guiName ~= "RollToast"
							and other
							and other:IsA("GuiObject")
							and h.visible(other)
							and crossing(r, h.rect(other))
						then
							table.insert(onHud, name .. " x " .. guiName .. "/" .. element)
						end
					end
				end
			end
		end
		h.checkList(res, tag .. "_clear_of_hud", onHud)
	end

	local function isRed(c)
		return c.R >= 0.5 and c.G < 0.3 and c.B < 0.3
	end
	local function luminance(c)
		local function channel(v)
			return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
		end
		return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
	end
	local function contrast(a, b)
		local la, lb = luminance(a), luminance(b)
		return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
	end
	-- The plate is red and solid, and the exact text reads against this moment's colour.
	local function warningPlate()
		local warning, label = h.find(WARNING), hasText(WARNING, WARNING_TEXT)
		if not (warning and label) then
			return { Red = false, Bright = false, Readable = false, Heavy = false }
		end
		local plate = warning.BackgroundColor3
		return {
			Red = isRed(plate) and warning.BackgroundTransparency <= PLATE_MAX_TRANSPARENCY,
			Bright = plate.R >= 0.8,
			Readable = contrast(label.TextColor3, plate) >= MIN_TEXT_CONTRAST and label.TextTransparency <= 0.1,
			Heavy = label.FontFace.Weight.Value >= Enum.FontWeight.Bold.Value,
		}
	end

	-- What a flash changes, as one string, for the Warning and everything in it.
	local function warningLook()
		local warning = h.find(WARNING)
		if not warning then
			return "missing"
		end
		local look = {}
		for _, d in { warning, table.unpack(warning:GetDescendants()) } do
			if d:IsA("GuiObject") then
				table.insert(look, tostring(d.Visible))
				table.insert(look, ("%.2f"):format(d.BackgroundTransparency))
				table.insert(look, tostring(d.BackgroundColor3))
			end
			if d:IsA("TextLabel") then
				local c = d.TextColor3
				table.insert(look, ("%.2f"):format(d.TextTransparency))
				table.insert(look, ("%.2f"):format(d.TextStrokeTransparency))
				table.insert(look, tostring(c))
			elseif d:IsA("UIStroke") then
				table.insert(look, ("%.2f"):format(d.Transparency))
			end
		end
		return table.concat(look, ",")
	end
	local function reducedNow()
		return GuiService.ReducedMotionEnabled or h.player:GetAttribute("ReduceEffects") == true
	end
	-- nil once the Warning has stayed hidden WARNING_QUIET s in a row, else the seconds it had when time ran out.
	local function warningStays(maxSeconds)
		local started = os.clock()
		local lastShown = started
		while os.clock() - started < maxSeconds do
			if shown(WARNING) then
				lastShown = os.clock()
			elseif os.clock() - lastShown >= WARNING_QUIET then
				return nil
			end
			task.wait(0.05)
		end
		return maxSeconds
	end

	-- A 0-roll save with auto-roll off. Client/AutoRollTutorial destroys its gui for good at the first roll, so a session past
	-- that gets a stand-in of the same name: BossEventUi's check reads only that name and the two attributes.
	local function checkInviteWaitsForTutorial(res)
		gear(res, 2)
		setup(res, "boss_ui_tutorial:on")
		waitIs(function()
			return h.player:GetAttribute("Rolls") == 0 and h.player:GetAttribute("AutoRoll") == false
		end, true)
		local playerGui = h.player:WaitForChild("PlayerGui")
		local standIn = nil
		if not playerGui:FindFirstChild("AutoRollTutorial") then
			standIn = Instance.new("ScreenGui")
			standIn.Name = "AutoRollTutorial"
			standIn.Enabled = false
			standIn.Parent = playerGui
		end
		state(res, "Prep", 5, 0, 0, false)
		check(res, "invite_hidden_during_tutorial", waitShown(INVITE, true, 1), false)
		setup(res, "boss_ui_tutorial:off")
		check(res, "invite_shows_after_tutorial", waitShown(INVITE, true), true)
		if standIn then
			standIn:Destroy()
		end
		state(res, "Idle", 0, 0, 0, false)
		waitShown(INVITE, false)
	end

	local function checkInvite(res)
		gear(res, 2)
		state(res, "Prep", 5, 0, 0, false)
		onlyShown(res, "invite", { Invite = true })
		check(res, "invite_teleport_shown", shown(TELEPORT), true)
		check(res, "invite_decline_shown", shown(DECLINE), true)
		local teleport = h.find(TELEPORT)
		check(res, "invite_teleport_enabled", teleport ~= nil and teleport.Active, true)
		checkCountdown(res, "invite_countdown_to_close", INVITE, Cfg.JoinSeconds - 5)
		checkFit(res, "invite")

		state(res, "Fight", 100, Cfg.HpPerPlayer, Cfg.HpPerPlayer, false)
		check(res, "invite_stays_after_spawn", waitShown(INVITE, true), true)
		task.wait(0.3)
		checkCountdown(res, "invite_countdown_after_spawn", INVITE, Cfg.JoinSeconds - 100)

		-- Owner 2026-11-05: a player in a duel can teleport in. A real Duel message, to this client only.
		setup(res, "duel_countdown")
		task.wait(0.3)
		check(res, "invite_stays_in_duel", shown(INVITE), true)
		check(res, "invite_teleport_enabled_in_duel", teleport ~= nil and teleport.Active, true)

		state(res, "Prep", 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, true, 10)
		check(res, "invite_hidden_after_joining", waitShown(INVITE, false), false)

		-- Gone at 3:00 by the clock alone: no attribute changes here.
		state(res, "Fight", Cfg.JoinSeconds - 1.5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, false)
		task.wait(0.2)
		check(res, "invite_shown_before_close", shown(INVITE), true)
		check(res, "invite_hidden_at_close", waitShown(INVITE, false, 3), false)
		state(res, "Fight", Cfg.JoinSeconds + 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, false)
		task.wait(0.3)
		check(res, "invite_hidden_after_close", shown(INVITE), false)

		state(res, "Prep", 5, 0, 0, false)
		check(res, "invite_back_for_new_event", waitShown(INVITE, true), true)
		state(res, "Idle", 0, 0, 0, false)
		check(res, "invite_hidden_at_end", waitShown(INVITE, false), false)
	end

	local function teleportActive()
		local teleport = h.find(TELEPORT)
		return teleport ~= nil and teleport.Active
	end
	local function checkLocked(res)
		gear(res, 0)
		state(res, "Prep", 5, 0, 0, false)
		check(res, "locked_invite_shown", waitShown(INVITE, true), true)
		check(res, "locked_teleport_disabled", waitIs(teleportActive, false), false)
		check(
			res,
			"locked_prompts_for_sidekick",
			waitIs(function()
				return shownTextHas(INVITE, "sidekick")
			end, true),
			true
		)
		checkFit(res, "locked")

		gear(res, "bag")
		task.wait(0.3)
		check(res, "reading_bag_only_teleport_disabled", waitIs(teleportActive, false), false)

		gear(res, 2) -- equipping during the invite opens it, with no event attribute changing
		check(res, "locked_opens_when_a_sidekick_is_worn", waitIs(teleportActive, true), true)
	end

	local function listNames()
		local names = {}
		local list = h.find(LIST)
		for _, child in list and list:GetChildren() or {} do
			if child:IsA("GuiButton") and h.visible(child) then
				table.insert(names, child.Name)
			end
		end
		table.sort(names)
		return table.concat(names, ",")
	end
	local function gearNames()
		local names = {}
		local raw = h.player:GetAttribute("SidekickGear")
		for id in type(raw) == "string" and HttpService:JSONDecode(raw) or {} do
			table.insert(names, id)
		end
		table.sort(names)
		return table.concat(names, ",")
	end
	local function checkTeamHud(res)
		gear(res, 2)
		state(res, "Prep", 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, true, 1234)
		onlyShown(res, "prep", { TeamHud = true, LeaveButton = true })
		for i = 1, 3 do
			check(res, "hud_slot" .. i .. "_shown", shown(HUD .. "/Slot" .. i), true)
		end
		check(res, "hud_no_slot4", h.find(HUD .. "/Slot4"), nil)
		local eligible = gearNames()
		check(res, "hud_fixture_has_two_eligible", select(2, string.gsub(eligible, ",", "")), 1)
		check(res, "hud_lists_eligible_only", waitIs(listNames, eligible), eligible)
		local third = h.find(HUD .. "/Slot3")
		check(res, "hud_empty_slot_stays_empty", third and third:GetAttribute("CharacterId"), nil)
		local note = hasText(HUD, NOTE_TEXT)
		check(res, "hud_note_exact_and_shown", note ~= nil and h.visible(note), true)
		check(res, "hud_team_damage_shown", shown(HUD .. "/TeamDamage"), true)
		local function damageShows(number)
			return function()
				local label = h.find(HUD .. "/TeamDamage")
				return label ~= nil and string.find(digits(label.Text), number, 1, true) ~= nil
			end
		end
		check(res, "hud_team_damage_value", waitIs(damageShows("1234"), true), true)
		checkCountdown(res, "hud_countdown_to_spawn", HUD, Cfg.PrepSeconds - 5)
		checkFit(res, "prep")

		state(res, "Prep", "keep", Cfg.HpPerPlayer, Cfg.HpPerPlayer, true, 2000)
		check(res, "hud_team_damage_follows_attribute", waitIs(damageShows("2000"), true), true)

		gear(res, 4)
		local four = waitIs(function()
			return select(2, string.gsub(listNames(), ",", ""))
		end, 3)
		check(res, "hud_list_follows_gear", four, 3)
		checkFit(res, "prep_full_list")

		state(res, "Prep", "keep", Cfg.HpPerPlayer, Cfg.HpPerPlayer, false)
		check(res, "hud_hidden_outside_arena", waitShown(HUD, false), false)
		gear(res, 2)
	end

	local function checkBarGeometry(res)
		local bar = h.find(BAR)
		if not (bar and isDesktop()) then
			return
		end
		local size = workspace.CurrentCamera.ViewportSize
		local r = h.rect(bar)
		local off = math.abs(r.x + r.w / 2 - size.X / 2) / size.X
		h.check(res, "bar_top_middle_x", off, "<= " .. BAR_CENTRE_SLACK, off <= BAR_CENTRE_SLACK)
		local bottom = (r.y + r.h) / size.Y
		h.check(res, "bar_top_middle_y", bottom, "<= " .. BAR_MAX_BOTTOM, bottom <= BAR_MAX_BOTTOM)
	end

	-- The spawn as a member sees it: the phase turns, the Warning flashes, the bar pops in and fills from the left.
	local function checkSpawn(res)
		local hp = Cfg.HpPerPlayer
		state(res, "Prep", Cfg.PrepSeconds - 0.5, hp, hp, true, 100)
		check(res, "hud_shown_before_spawn", waitShown(HUD, true), true)
		check(res, "no_warning_before_spawn", shown(WARNING), false)
		check(res, "no_bar_before_spawn", shown(BAR), false)

		local spawnedAt = os.clock()
		state(res, "Fight", "keep", hp, hp, true, 100) -- BossEventStart holds through a real spawn
		check(res, "spawn_bar_shown", waitShown(BAR, true), true)
		check(res, "spawn_warning_shown", waitShown(WARNING, true), true)
		check(res, "spawn_hud_hidden", waitShown(HUD, false), false)
		check(res, "spawn_invite_hidden", shown(INVITE), false)
		check(res, "spawn_leave_shown", shown(LEAVE), true)
		check(res, "spawn_roll_hidden", shown("RollToast/Toast"), false)
		local label = hasText(WARNING, WARNING_TEXT)
		check(res, "warning_exact_text", label ~= nil, true)
		if label and isDesktop() then
			local height = h.rect(label).h
			h.check(res, "warning_is_big", height, ">= " .. MIN_WARNING_HEIGHT, height >= MIN_WARNING_HEIGHT)
		end
		check(res, "bar_name", textOf(BAR, "Name"), BOSS_NAME)
		checkBarGeometry(res)

		local reduced = reducedNow()
		if not reduced then
			local bar = h.find(BAR)
			check(res, "bar_pops_in", bar ~= nil and bar:FindFirstChild("MotionScale") ~= nil, true)
		end
		local looks, ratios, leftDrift = {}, {}, 0
		local red, bright, readable, heavy = true, false, true, true
		local stop = os.clock() + FLASH_SAMPLE
		while os.clock() < stop do
			looks[warningLook()] = true
			local plate = warningPlate()
			red = red and plate.Red
			bright = bright or plate.Bright
			readable = readable and plate.Readable
			heavy = heavy and plate.Heavy
			local ratio = fillRatio()
			if ratio then
				table.insert(ratios, ratio)
				local fill = named(BAR, "Fill")
				leftDrift = math.max(leftDrift, math.abs(fill.AbsolutePosition.X - fill.Parent.AbsolutePosition.X))
			end
			task.wait(0.05)
		end
		local count = 0
		for _ in looks do
			count += 1
		end
		check(res, "warning_is_red", red, true) -- every moment of the flash
		check(res, "warning_reaches_bright_red", bright, true)
		check(res, "warning_text_readable_on_plate", readable, true)
		check(res, "warning_text_heavy", heavy, true)
		checkFit(res, "fight")
		if not reduced then
			h.check(res, "warning_flashes", count, ">= 2 looks", count >= 2)
			local first, last = ratios[1] or 1, ratios[#ratios] or 0
			-- Three seconds into the 20 s fill, with a little room for a curve.
			h.check(res, "bar_starts_nearly_empty", first, "< 0.35", first < 0.35)
			h.check(res, "bar_fill_grows", last - first, "> 0", last > first)
			local falls = 0
			for i = 2, #ratios do
				falls += ratios[i] < ratios[i - 1] - 0.001 and 1 or 0
			end
			check(res, "bar_fill_never_falls", falls, 0)
			h.check(res, "bar_fills_from_the_left", leftDrift, "<= " .. Spec.Tolerance, leftDrift <= Spec.Tolerance)
		end

		-- An HP change is not a new spawn: the Warning ends once and does not come back.
		local left = WARNING_MAX - (os.clock() - spawnedAt)
		check(res, "warning_goes_away_by_itself", warningStays(math.max(left, WARNING_QUIET + 0.1)), nil)
		check(res, "bar_stays_after_warning", shown(BAR), true)
		state(res, "Fight", "keep", hp - 1, hp, true, 100)
		task.wait(0.4)
		check(res, "warning_not_back_on_hp_change", shown(WARNING), false)
	end

	local function checkBarValues(res)
		local hp = Cfg.HpPerPlayer
		local afterIntro = Cfg.PrepSeconds + Cfg.IntroSeconds + 5
		state(res, "Fight", afterIntro, 2500, 4000, true, 100)
		checkRatio(res, "bar_ratio_2500_of_4000", 2500 / 4000)
		local value = waitIs(function()
			local text = digits(textOf(BAR, "Value"))
			return string.find(text, "2500", 1, true) ~= nil and string.find(text, "4000", 1, true) ~= nil
		end, true)
		check(res, "bar_value_text", value, true)
		state(res, "Fight", "keep", 1000, 4000, true, 100)
		checkRatio(res, "bar_ratio_follows_hp", 1000 / 4000)
		state(res, "Fight", "keep", 6000, 8000, true, 100)
		checkRatio(res, "bar_ratio_follows_max", 6000 / 8000) -- a joiner adds to both before 3:00
		state(res, "Fight", "keep", 2500.5, 4000, true, 100)
		checkRatio(res, "bar_ratio_unrounded_hp", 2500.5 / 4000)
		task.wait(0.3)
		check(res, "bar_value_whole_numbers", string.find(textOf(BAR, "Value"), ".", 1, true), nil) -- TeamDamage is unrounded
		state(res, "Fight", "keep", 0, hp, true, 100)
		checkRatio(res, "bar_ratio_empty", 0)
		checkFit(res, "bar_values")
	end

	-- 1:00-3:00: each joiner sees the header too, and a bar already at the right width.
	local function checkLateJoin(res)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 10, 3000, 4000, false)
		onlyShown(res, "before_join", { Invite = true })
		state(res, "Fight", "keep", 3000, 4000, true, 100)
		check(res, "late_join_warning_shown", waitShown(WARNING, true), true)
		check(res, "late_join_bar_shown", waitShown(BAR, true), true)
		check(res, "late_join_leave_shown", waitShown(LEAVE, true), true)
		check(res, "late_join_no_team_hud", shown(HUD), false)
		checkRatio(res, "late_join_ratio", 3000 / 4000)

		if isDesktop() then
			local restore = h.setPanels({ "RacerIndex/Panel" })
			check(res, "leave_hidden_under_a_panel", waitShown(LEAVE, false), false)
			restore()
			check(res, "leave_back_after_panel", waitShown(LEAVE, true), true)
		end

		-- Near the intro's end the fill is nearly done, whenever the client first drew it.
		state(res, "Idle", 0, 0, 0, false)
		check(res, "late_intro_bar_clear", waitShown(BAR, false), false)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds - 2, 3000, 4000, true, 100)
		check(res, "late_intro_bar_shown", waitShown(BAR, true), true)
		local early = fillRatio() or 0
		h.check(res, "late_intro_fill_follows_the_clock", early, "> 0.5 of 0.75", early > 0.5)
		task.wait(2.2)
		checkRatio(res, "late_intro_fill_ends_at_hp", 3000 / 4000)
	end

	local function checkOutsider(res)
		state(res, "Prep", Cfg.PrepSeconds - 3, 4000, 4000, false)
		onlyShown(res, "outsider_prep", { Invite = true })
		state(res, "Fight", Cfg.PrepSeconds, 4000, 4000, false)
		task.wait(1)
		onlyShown(res, "outsider_spawn", { Invite = true })
		-- A leave: everything of the arena goes with the attribute.
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, 4000, 4000, true, 100)
		check(res, "leaver_bar_shown_first", waitShown(BAR, true), true)
		state(res, "Fight", "keep", 4000, 4000, false)
		onlyShown(res, "after_leave", {}, { Invite = true })
	end

	-- UiMotion: Roblox's Reduced Motion or the REDUCED EFFECTS toggle. The header stays still and stays readable.
	local function checkReduced(res)
		h.player:SetAttribute("ReduceEffects", true)
		state(res, "Idle", 0, 0, 0, false)
		task.wait(0.2)
		state(res, "Prep", Cfg.PrepSeconds - 0.5, 4000, 4000, true, 100)
		waitShown(HUD, true)
		state(res, "Fight", "keep", 4000, 4000, true, 100)
		check(res, "reduced_warning_shown", waitShown(WARNING, true), true)
		task.wait(0.1)
		local looks, count, alwaysShown = {}, 0, true
		local stop = os.clock() + 1.2
		while os.clock() < stop do
			local look = warningLook()
			if not looks[look] then
				looks[look] = true
				count += 1
			end
			alwaysShown = alwaysShown and shown(WARNING)
			task.wait(0.05)
		end
		check(res, "reduced_warning_does_not_flash", count, 1)
		check(res, "reduced_warning_stays_shown", alwaysShown, true)
		local plate = warningPlate()
		check(res, "reduced_warning_solid_red", plate.Red, true)
		check(res, "reduced_warning_bright", plate.Bright, true)
		check(res, "reduced_warning_text_readable", plate.Readable, true)
		-- Still on screen here: the end of the event takes the Warning too.
		state(res, "Idle", 0, 0, 0, false)
		onlyShown(res, "event_end", {})
	end

	function scenarios.ui_boss(res)
		h.waitGuis()
		local gui = h.find(ROOT)
		check(res, "boss_gui_present", gui ~= nil, true)
		if not gui then
			return
		end
		for _, path in { TELEPORT, DECLINE, HUD .. "/Slot1", WARNING, BAR, LEAVE } do
			check(res, "boss_part_present_" .. path, h.find(path) ~= nil, true)
		end
		local started = os.clock()
		local savedReduce = h.player:GetAttribute("ReduceEffects")
		local ok, err = xpcall(function()
			state(res, "Idle", 0, 0, 0, false)
			onlyShown(res, "rest", {})
			checkInviteWaitsForTutorial(res)
			checkInvite(res)
			checkLocked(res)
			checkTeamHud(res)
			checkSpawn(res)
			checkBarValues(res)
			checkLateJoin(res)
			checkOutsider(res)
			checkReduced(res)
		end, debug.traceback)
		h.check(res, "boss_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		h.player:SetAttribute("ReduceEffects", savedReduce)
		setup(res, "restore:boss_ui")
		local spent = os.clock() - started
		h.check(res, "boss_scenario_time", spent, "< " .. BUDGET, spent < BUDGET)
	end

	-- After the real presses (UiSpec.Clicks boss_*). The spy answers false to Teleport: refused means not joined.
	function after.boss_invite_shown(res)
		check(res, "boss_refused_teleport_keeps_invite", shown(INVITE), true)
	end
	function after.boss_invite_hidden(res)
		check(res, "boss_decline_hides_invite", waitShown(INVITE, false), false)
	end
	function after.boss_slot1_filled(res)
		local slot = h.find(HUD .. "/Slot1")
		local want = Spec.BossEvent.Pick
		check(
			res,
			"boss_tap_fills_slot1",
			waitIs(function()
				return slot and slot:GetAttribute("CharacterId")
			end, want),
			want
		)
		local third = h.find(HUD .. "/Slot3")
		check(res, "boss_tap_keeps_slot3_empty", third and third:GetAttribute("CharacterId"), nil)
	end

	return { Scenarios = scenarios, After = after }
end

return Module
