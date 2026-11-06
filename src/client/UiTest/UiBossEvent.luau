--!nonstrict
-- Boss event UI (design doc 4.37, docs/BOSS_EVENT_SPEC.md Flow and Team HUD, Client/BossEventUi). Owned by ui-test-writer.
-- ui_boss drives the published attributes through UiTestSetup boss_ui_* and never joins an event; the real presses are
-- the boss_* clicks in UiSpec.Clicks, judged after them here.
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   Every part is built once and only hidden: Invite, TeamHud, Warning, BossBar, LeaveButton, BossButton sit directly in the ScreenGui.
--   Named anywhere inside their part: Invite Countdown; TeamHud Countdown; BossBar Fill (its parent is the track).
--   Boss bar (owner 2026-11-05): BossBar/Title "Big Raga" above the track; BossBar/Value "current/max" with thousands separators,
--     inside the track and drawn over the Fill.
--   Boss bar size (owner 2026-11-05): at desktop width at least 60% of the screen and 56 px tall, Value text 28 px, Title text 36 px.
--     On every screen it stays on screen and clear of HudChrome/TopRight.
--   DropList layout (owner 2026-11-05): Heading and rows centre aligned, Rule centred and narrower than the rows, its centre past the
--     bar's right end minus 15% of bar width, clear of ShopColumn/Quests, ShopColumn/Shop, Leave and the bar.
--   DropList is a GuiObject directly in the ScreenGui, under the bar's right side, shown only to event players in Fight (it may stay
--     on the exhaustion view). Directly in it: Heading "Drop:", Rule, and one Row_<id> per RelicConfig.Odds("big_raga") row plus
--     Row_side_raga, top to bottom in descending odds. Nothing in it is Active. checkFit's text rules also judge it against the
--     Warning: the Warning has to clear the list.
--   TeamHud/List: one GuiButton per eligible character, directly in List, named its character id.
--   Slot<n> has attribute CharacterId while it holds a character, none while it is empty.
--   Invite Countdown counts to teleport closing (3:00), TeamHud Countdown to the spawn (1:00). "m:ss" or plain seconds.
--   Decline lasts for one event (one BossEventStart): a new start shows the Invite again.
--   Plaza flow (owner 2026-11-05): the Invite closes by itself after Cfg.InviteSeconds. BossButton shows for an outsider from the
--     event's start until teleporting closes at 3:00, Invite up or not, declined or not, in a duel too, locked too. Its Text is
--     exactly "Boss (Active)". Child Glow: a UIStroke or a GuiObject. Child UIScale named PulseScale (UiSpec.TransientScales), whose
--     Scale changes, still with reduced motion. Its left edge stays past GuiService.TopbarInset.Min.X at every pulse scale. A press
--     with no Sidekick does not fire BossEventTeleport and shows text with "sidekick" anywhere in the ScreenGui; before it, no such
--     text shows once the Invite has closed.
--   Remotes are found when pressed (WaitForChild in Activated): progression_spy swaps them for logging proxies.
--   The Fill follows BossEventStart, not a local tween from the moment it showed: a late joiner sees the right width.
--   BossBar/Status, under the bar's left side, has one Status_<Id> per BossStatus entry (attribute JSON, EndsAt in server time). In
--     it: Icon, an ImageLabel whose Image or text differs per status (a colour alone is not distinct), and Seconds, like "4s".
--     No name is required. It goes when EndsAt passes. ui_boss sets BossStatus locally, client side.
--   The arena camera: workspace.CurrentCamera.FieldOfView is Cfg.CameraFov while player attribute BossEvent is true; the value it
--     had before comes back when the attribute goes, not a fixed default.
--   The BossBar pops through UiMotion.Pop (UIScale MotionScale). LeaveButton hides while a PanelSwitch panel is open.
--   The Warning (owner 2026-11-05) is flashing text alone: no background anywhere in it, no border, a heavy red label with a dark
--     text stroke (TextStroke*, or a UIStroke in the label in Contextual mode) that fades with the text. It flashes through
--     TextTransparency, near 1 and near 0 in turn. Solid with reduced motion.
--   The Invite waits while a save is in the starter pick or the roll tutorial (boss_ui_gear sets a save past both).
--   Exhaustion view (owner 2026-11-05, spec "Exhaustion view"): ExhaustedPanel is a GuiObject directly in the ScreenGui, with
--     Message, Countdown, Dim and Loading/Fill directly in it. It runs only on the local player's own BossWaitEndsAt, while
--     BossEvent is true; the server clears BossEvent first on leaving, so a stale end time must not hold the view. The view's
--     FieldOfView is Cfg.WaitCameraFov; after a revive it returns to Cfg.CameraFov.
-- READINGS the docs leave open, for the owner (names start with reading_):
--   a Sidekick only in the Bag, on no character, locks the Invite: the server refuses that join ("Needs a Sidekick").
-- Invite and TeamHud are not UiSpec Panels (Panels must be PanelSwitch ones and close each other, the Invite must not), so
-- ui_layout does not see them; their fit at desktop is judged here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("BossEventConfig"))
local Arena = require(Shared:WaitForChild("BossArenaConfig"))
local RelicConfig = require(Shared:WaitForChild("RelicConfig"))
local GachaConfig = require(Shared:WaitForChild("GachaConfig"))
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
local PANEL = ROOT .. "/ExhaustedPanel"
local BUTTON = ROOT .. "/BossButton"
local DROP = ROOT .. "/DropList"
local PARTS = {
	Invite = INVITE,
	TeamHud = HUD,
	Warning = WARNING,
	BossBar = BAR,
	LeaveButton = LEAVE,
	ExhaustedPanel = PANEL,
	BossButton = BUTTON,
	DropList = DROP,
}

local NOTE_TEXT = "Only characters with Sidekicks can be equipped for bosses"
local WARNING_TEXT = "Big Raga has emerged, take him down!!!"
local BOSS_NAME = "Big Raga"
local BUTTON_TEXT = "Boss (Active)"

local SHOW_WAIT = 2 -- s: an attribute change has replicated and the UI has followed
local WARNING_MAX = 12 -- s: proposed, "goes away by itself" has no number in the docs
local WARNING_QUIET = 1 -- s hidden in a row before a flashing Warning counts as gone
local FLASH_SAMPLE = 3 -- s the Warning and the intro fill are watched
local COUNTDOWN_SLACK = 2 -- s
local RATIO_SLACK = 0.02
local FILL_SLACK = 0.1 -- of the bar: the fill against the server clock while it moves
local FOV_OUTSIDE = 63 -- a value no script sets, so a restore to a fixed default shows
local BUDGET = 84 -- s: the whole scenario
local DIM_MIN, DIM_MAX = 0.5, 0.85 -- BackgroundTransparency: "slightly dimmed"
local WAIT_CENTRE_SLACK = 0.1 -- of the screen
local WAIT_CAMERA_SLACK = 40 -- studs: a boss shake may be on top of the framing
local WAIT_COUNT_SLACK = 0.15 -- s around a whole-second change
local PHONE_MAX_HEIGHT = 500
local MIN_WARNING_HEIGHT = 40 -- px at desktop: "big"
local BAR_CENTRE_SLACK = 0.05 -- of the screen width
local BAR_MAX_BOTTOM = 0.3 -- of the screen height: "top middle"
local BAR_MIN_WIDTH_SHARE = 0.6 -- of the screen, owner 2026-11-05
local BAR_MIN_HEIGHT = 56 -- px
local BAR_VALUE_MIN_TEXT = 28 -- px
local BAR_TITLE_MIN_TEXT = 36 -- px
local BAR_SIZE_MIN_SCREEN = 1280 -- px of width where those sizes are judged
local DROP_RIGHT_SHARE = 0.15 -- of the bar's width, back from its right end
local DROP_ROW_MIN_HEIGHT = 16 -- px at desktop: bigger than the old 15
local TEXT_GONE = 0.9 -- TextTransparency: the flash's out, "fully disappearing"
local TEXT_SOLID = 0.1 -- and its in
local STROKE_SHOWS = 0.5 -- stroke transparency at most, while the text shows
local STROKE_MAX_LUMINANCE = 0.2
local INVITE_SECONDS = Cfg.InviteSeconds or 3 -- read here so a missing value fails its own check, not the whole scenario
local INVITE_EARLY, INVITE_LATE = 0.5, 1 -- s around InviteSeconds, from the request that showed it
local PULSE_SAMPLE = 2 -- s the button's pulse is watched
local PULSE_MIN_SPREAD = 0.02 -- of its Scale: "pulses in size"
local STILL_MAX_SPREAD = 0.001
local BUTTON_MAX_PAST_INSET = 40 -- px from TopbarInset.Min.X: "very top left"
local OUTLINE_MIN_LUMINANCE = 0.5 -- the Big Raga row's outline: "light", against its black text

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
	-- The label's stroke as the player sees it: its colour and transparency, or nil with no stroke at all.
	local function textStroke(label)
		for _, d in label:GetChildren() do
			if d:IsA("UIStroke") and d.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
				return d.Color, d.Transparency
			end
		end
		return label.TextStrokeColor3, label.TextStrokeTransparency
	end
	-- Text alone: every background in the Warning is clear and nothing draws a border.
	local function warningBareList()
		local warning = h.find(WARNING)
		local bad = {}
		for _, d in warning and { warning, table.unpack(warning:GetDescendants()) } or {} do
			if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
				table.insert(bad, d.Name .. " background")
			elseif d:IsA("UIStroke") and d.ApplyStrokeMode == Enum.ApplyStrokeMode.Border and d.Transparency < 1 then
				table.insert(bad, d.Parent.Name .. " border")
			elseif d:IsA("ImageLabel") and d.ImageTransparency < 1 then
				table.insert(bad, d.Name .. " image")
			end
		end
		return bad
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

	local function glowing()
		local glow = named(BUTTON, "Glow")
		if glow and glow:IsA("UIStroke") then
			return glow.Transparency < 1 and glow.Thickness > 0
		end
		return glow ~= nil and glow:IsA("GuiObject") and h.visible(glow)
	end
	-- The biggest Scale difference over `seconds` and the leftmost the button reached; nil without its PulseScale.
	local function watchPulse(seconds)
		local button = h.find(BUTTON)
		local scale = button and button:FindFirstChild("PulseScale")
		if not (scale and scale:IsA("UIScale")) then
			return nil
		end
		local low, high, left = scale.Scale, scale.Scale, h.rect(button).x
		local stop = os.clock() + seconds
		while os.clock() < stop do
			low, high = math.min(low, scale.Scale), math.max(high, scale.Scale)
			left = math.min(left, h.rect(button).x)
			task.wait(0.03)
		end
		return high - low, left
	end
	local function checkButtonShows(res, tag)
		check(res, tag .. "_button_shown", waitShown(BUTTON, true), true)
		check(res, tag .. "_button_text", h.find(BUTTON) and h.find(BUTTON).Text, BUTTON_TEXT)
		check(res, tag .. "_button_active", h.find(BUTTON) and h.find(BUTTON).Active, true)
		check(res, tag .. "_button_glows", waitIs(glowing, true), true)
	end
	local function checkButtonPlace(res)
		local inset = GuiService.TopbarInset
		local spread, left = watchPulse(PULSE_SAMPLE)
		h.check(
			res,
			"button_pulses",
			spread or "no PulseScale",
			">= " .. PULSE_MIN_SPREAD,
			spread ~= nil and spread >= PULSE_MIN_SPREAD
		)
		h.check(
			res,
			"button_past_roblox_buttons",
			left or "no PulseScale",
			">= " .. inset.Min.X,
			left ~= nil and left >= inset.Min.X - 1
		)
		h.check(
			res,
			"button_very_left",
			left or "no PulseScale",
			"<= " .. inset.Min.X + BUTTON_MAX_PAST_INSET,
			left ~= nil and left <= inset.Min.X + BUTTON_MAX_PAST_INSET
		)
		local top = h.rect(h.find(BUTTON)).y
		h.check(res, "button_very_top", top, "<= " .. inset.Max.Y, top <= inset.Max.Y)
	end

	local function checkInvite(res)
		check(res, "invite_seconds_is_3", Cfg.InviteSeconds, 3)
		gear(res, 2)
		local asked = os.clock()
		state(res, "Prep", 5, 0, 0, false)
		onlyShown(res, "invite", { Invite = true, BossButton = true })
		check(res, "invite_teleport_shown", shown(TELEPORT), true)
		check(res, "invite_decline_shown", shown(DECLINE), true)
		local teleport = h.find(TELEPORT)
		check(res, "invite_teleport_enabled", teleport ~= nil and teleport.Active, true)
		checkCountdown(res, "invite_countdown_to_close", INVITE, Cfg.JoinSeconds - 5)
		checkButtonShows(res, "invite")
		checkFit(res, "invite")

		-- It closes by itself, on its own time, and the button carries on until 3:00.
		check(res, "invite_closes_by_itself", waitShown(INVITE, false, INVITE_SECONDS + INVITE_LATE), false)
		local closedAfter = os.clock() - asked
		h.check(
			res,
			"invite_shows_for_its_seconds",
			closedAfter,
			("%s -%s +%s"):format(INVITE_SECONDS, INVITE_EARLY, INVITE_LATE),
			closedAfter >= INVITE_SECONDS - INVITE_EARLY and closedAfter <= INVITE_SECONDS + INVITE_LATE
		)
		checkButtonShows(res, "plaza")
		checkButtonPlace(res)
		checkFit(res, "plaza")

		state(res, "Fight", "keep", Cfg.HpPerPlayer, Cfg.HpPerPlayer, false)
		task.wait(0.3)
		check(res, "invite_not_back_at_spawn", shown(INVITE), false)
		checkButtonShows(res, "spawn")

		-- Owner 2026-11-05: a player in a duel can teleport in. A real Duel message, to this client only.
		setup(res, "duel_countdown")
		task.wait(0.3)
		checkButtonShows(res, "duel")
		state(res, "Prep", 5, 0, 0, false)
		check(res, "invite_shows_in_duel", waitShown(INVITE, true), true)
		check(res, "invite_teleport_enabled_in_duel", teleport ~= nil and teleport.Active, true)
		checkButtonShows(res, "duel_new_event")

		state(res, "Prep", 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, true, 10)
		check(res, "invite_hidden_after_joining", waitShown(INVITE, false), false)
		check(res, "button_hidden_after_joining", waitShown(BUTTON, false), false)

		-- Gone at 3:00 by the clock alone: no attribute changes here.
		state(res, "Fight", Cfg.JoinSeconds - 1.5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, false)
		task.wait(0.2)
		check(res, "button_shown_before_close", shown(BUTTON), true)
		check(res, "button_hidden_at_close", waitShown(BUTTON, false, 3), false)
		check(res, "invite_hidden_at_close", shown(INVITE), false)
		state(res, "Fight", Cfg.JoinSeconds + 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, false)
		task.wait(0.3)
		check(res, "invite_hidden_after_close", shown(INVITE), false)
		check(res, "button_hidden_after_close", shown(BUTTON), false)

		state(res, "Prep", 5, 0, 0, false)
		check(res, "invite_back_for_new_event", waitShown(INVITE, true), true)
		check(res, "button_back_for_new_event", waitShown(BUTTON, true), true)
		state(res, "Idle", 0, 0, 0, false)
		check(res, "invite_hidden_at_end", waitShown(INVITE, false), false)
		check(res, "button_hidden_at_end", waitShown(BUTTON, false), false)
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
		checkButtonShows(res, "locked")
		checkFit(res, "locked")

		gear(res, "bag")
		task.wait(0.3)
		check(res, "reading_bag_only_teleport_disabled", waitIs(teleportActive, false), false)

		gear(res, 2) -- equipping during the invite opens it, with no event attribute changing
		check(res, "locked_opens_when_a_sidekick_is_worn", waitIs(teleportActive, true), true)

		-- With the Invite gone the button still reads Active; the press itself is the click boss_button_locked.
		gear(res, 0)
		state(res, "Prep", 5, 0, 0, false)
		waitShown(INVITE, true)
		check(res, "locked_invite_closes_by_itself", waitShown(INVITE, false, INVITE_SECONDS + INVITE_LATE), false)
		checkButtonShows(res, "locked_plaza")
		check(res, "locked_no_prompt_before_a_press", shownTextHas(ROOT, "sidekick"), false)
		gear(res, 2)
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

	local function barTrack()
		local fill = named(BAR, "Fill")
		return fill and fill.Parent
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
		local title, track = h.find(BAR .. "/Title"), barTrack()
		check(res, "bar_title", title and title.Text, BOSS_NAME)
		if title and track then
			local titleBottom, trackTop = h.rect(title).y + h.rect(title).h, h.rect(track).y
			h.check(
				res,
				"bar_title_above_track",
				titleBottom,
				"<= " .. trackTop,
				titleBottom <= trackTop + Spec.Tolerance
			)
		end
		checkBarGeometry(res)

		local reduced = reducedNow()
		if not reduced then
			local bar = h.find(BAR)
			check(res, "bar_pops_in", bar ~= nil and bar:FindFirstChild("MotionScale") ~= nil, true)
		end
		local red, heavy, strokeDark, strokeSolid, strokeFades = true, true, true, true, true
		local faintest, solidest = 0, 1
		local bare = {}
		local stop = os.clock() + FLASH_SAMPLE
		while os.clock() < stop do
			local current = hasText(WARNING, WARNING_TEXT)
			if current then
				local gone = current.TextTransparency
				faintest, solidest = math.max(faintest, gone), math.min(solidest, gone)
				red = red and isRed(current.TextColor3)
				heavy = heavy and current.FontFace.Weight.Value >= Enum.FontWeight.Bold.Value
				local color, stroke = textStroke(current)
				strokeDark = strokeDark and luminance(color) <= STROKE_MAX_LUMINANCE
				strokeSolid = strokeSolid and (gone > TEXT_SOLID or stroke <= STROKE_SHOWS)
				strokeFades = strokeFades and (gone < TEXT_GONE or stroke >= TEXT_GONE)
			end
			for _, item in warningBareList() do
				bare[item] = true
			end
			task.wait(0.03)
		end
		local bareList = {}
		for item in bare do
			table.insert(bareList, item)
		end
		h.checkList(res, "warning_text_alone", bareList)
		check(res, "warning_is_red", red, true) -- every moment of the flash
		check(res, "warning_text_heavy", heavy, true)
		check(res, "warning_stroke_is_dark", strokeDark, true)
		check(res, "warning_stroke_shows_with_text", strokeSolid, true)
		check(res, "warning_stroke_goes_with_text", strokeFades, true)
		checkFit(res, "fight")
		if reduced then
			h.check(res, "warning_solid", faintest, "<= " .. TEXT_SOLID, faintest <= TEXT_SOLID)
		else
			h.check(res, "warning_flashes_out", faintest, ">= " .. TEXT_GONE, faintest >= TEXT_GONE)
			h.check(res, "warning_flashes_in", solidest, "<= " .. TEXT_SOLID, solidest <= TEXT_SOLID)
		end

		-- An HP change is not a new spawn: the Warning ends once and does not come back.
		local left = WARNING_MAX - (os.clock() - spawnedAt)
		check(res, "warning_goes_away_by_itself", warningStays(math.max(left, WARNING_QUIET + 0.1)), nil)
		check(res, "bar_stays_after_warning", shown(BAR), true)
		state(res, "Fight", "keep", hp - 1, hp, true, 100)
		task.wait(0.4)
		check(res, "warning_not_back_on_hp_change", shown(WARNING), false)
	end

	-- Owner 2026-11-05: the bar fills with the rise, in 2-3 s, on the server's clock.
	local function checkIntroFill(res)
		local intro = Cfg.IntroSeconds
		h.check(res, "intro_is_2_to_3_seconds", intro, "2 to 3", intro >= 2 and intro <= 3)
		if reducedNow() then
			return
		end
		local hp = Cfg.HpPerPlayer
		state(res, "Idle", 0, 0, 0, false)
		check(res, "fill_bar_clear", waitShown(BAR, false), false)
		state(res, "Fight", Cfg.PrepSeconds, hp, hp, true, 100)
		check(res, "fill_bar_shown", waitShown(BAR, true), true)
		local ratios, worst, leftDrift = {}, 0, 0
		local stop = os.clock() + intro + 0.5
		while os.clock() < stop do
			local ratio = fillRatio()
			local start = ReplicatedStorage:GetAttribute("BossEventStart")
			if ratio and start then
				table.insert(ratios, ratio)
				local want = math.clamp((workspace:GetServerTimeNow() - start - Cfg.PrepSeconds) / intro, 0, 1)
				worst = math.max(worst, math.abs(ratio - want))
				local fill = named(BAR, "Fill")
				leftDrift = math.max(leftDrift, math.abs(fill.AbsolutePosition.X - fill.Parent.AbsolutePosition.X))
			end
			task.wait(0.05)
		end
		local first, last = ratios[1] or 1, ratios[#ratios] or 0
		h.check(res, "bar_starts_nearly_empty", first, "< 0.5", first < 0.5)
		h.check(res, "bar_fill_follows_the_intro", worst, "<= " .. FILL_SLACK, worst <= FILL_SLACK)
		h.check(res, "bar_full_when_the_intro_ends", last, ">= " .. 1 - RATIO_SLACK, last >= 1 - RATIO_SLACK)
		local falls = 0
		for i = 2, #ratios do
			falls += ratios[i] < ratios[i - 1] - 0.001 and 1 or 0
		end
		check(res, "bar_fill_never_falls", falls, 0)
		h.check(res, "bar_fills_from_the_left", leftDrift, "<= " .. Spec.Tolerance, leftDrift <= Spec.Tolerance)
		state(res, "Idle", 0, 0, 0, false)
	end

	-- Owner 2026-11-05: Shouted and Adapted under the boss bar, for event players.
	local function checkStatusRow(res)
		local hp = Cfg.HpPerPlayer
		local function setStatus(rows)
			ReplicatedStorage:SetAttribute("BossStatus", rows and HttpService:JSONEncode(rows) or nil)
		end
		local function cell(id)
			local found = named(BAR, "Status_" .. id)
			return found and found:IsA("GuiObject") and h.visible(found) and found or nil
		end
		local function cellShown(id)
			return cell(id) ~= nil
		end
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true, 100)
		check(res, "status_bar_shown", waitShown(BAR, true), true)
		local now = workspace:GetServerTimeNow()
		setStatus({ { Id = "Shouted", EndsAt = now + 2 }, { Id = "Adapted", EndsAt = now + 12 } })
		check(res, "status_row_present", h.find(BAR .. "/Status") ~= nil, true)
		local track, looks, firstLeft = barTrack(), {}, nil
		for id, ends in { Shouted = 2, Adapted = 12 } do
			check(
				res,
				"status_shows_" .. id,
				waitIs(function()
					return cellShown(id)
				end, true),
				true
			)
			local item = h.find(BAR .. "/Status/Status_" .. id)
			local icon, seconds = item and item:FindFirstChild("Icon"), item and item:FindFirstChild("Seconds")
			check(res, "status_icon_" .. id, icon ~= nil and icon:IsA("ImageLabel"), true)
			check(res, "status_seconds_" .. id, seconds ~= nil and seconds:IsA("TextLabel"), true)
			if icon then
				local look = { icon.Image }
				for _, d in icon:GetDescendants() do
					if d:IsA("TextLabel") then
						table.insert(look, d.Text)
					end
				end
				looks[id] = table.concat(look, "|")
			end
			local text = seconds and seconds:IsA("TextLabel") and seconds.Text or ""
			check(res, "status_seconds_format_" .. id, string.match(text, "^%d+s$") ~= nil, true)
			local left = secondsIn(text)
			h.check(res, "status_countdown_" .. id, left, "<= " .. ends, left ~= nil and left <= ends + COUNTDOWN_SLACK)
			if id == "Adapted" then
				firstLeft = left
			end
			if item and track then
				local r, t = h.rect(item), h.rect(track)
				h.check(res, "status_under_track_" .. id, r.y, ">= " .. t.y + t.h, r.y >= t.y + t.h - Spec.Tolerance)
				local middle = t.x + t.w / 2
				h.check(
					res,
					"status_left_side_" .. id,
					r.x + r.w,
					"<= " .. middle,
					r.x + r.w <= middle + Spec.Tolerance
				)
			end
		end
		check(res, "status_icons_differ", looks.Shouted ~= nil and looks.Shouted ~= looks.Adapted, true)
		check(
			res,
			"status_gone_when_expired",
			waitIs(function()
				return cellShown("Shouted")
			end, false, 3.5),
			false
		)
		check(res, "status_other_stays", cellShown("Adapted"), true)
		local adapted = h.find(BAR .. "/Status/Status_Adapted/Seconds")
		local laterLeft = adapted and secondsIn(adapted.Text)
		h.check(
			res,
			"status_seconds_count_down",
			laterLeft or "no Seconds",
			"< " .. tostring(firstLeft),
			laterLeft ~= nil and firstLeft ~= nil and laterLeft < firstLeft
		)
		state(res, "Fight", "keep", hp, hp, false)
		check(
			res,
			"status_hidden_outside_event",
			waitIs(function()
				return cellShown("Adapted")
			end, false),
			false
		)
		setStatus(nil)
		state(res, "Idle", 0, 0, 0, false)
	end

	-- Owner 2026-11-05: the wider event camera, in the arena only.
	local function checkCameraFov(res)
		local camera = workspace.CurrentCamera
		local function fov()
			return math.round(camera.FieldOfView * 100) / 100
		end
		local hp = Cfg.HpPerPlayer
		local before = camera.FieldOfView
		state(res, "Idle", 0, 0, 0, false)
		task.wait(0.2)
		camera.FieldOfView = FOV_OUTSIDE
		state(res, "Prep", 5, hp, hp, false)
		task.wait(0.3)
		check(res, "fov_outsider_in_prep_unchanged", fov(), FOV_OUTSIDE)
		state(res, "Prep", "keep", hp, hp, true, 100)
		check(res, "fov_wide_in_prep", waitIs(fov, Cfg.CameraFov), Cfg.CameraFov)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true, 100)
		task.wait(0.3)
		check(res, "fov_wide_in_fight", fov(), Cfg.CameraFov)
		state(res, "Fight", "keep", hp, hp, false)
		check(res, "fov_restored_on_leave", waitIs(fov, FOV_OUTSIDE), FOV_OUTSIDE)
		task.wait(0.3)
		check(res, "fov_outsider_in_fight_unchanged", fov(), FOV_OUTSIDE)
		state(res, "Fight", "keep", hp, hp, true, 100)
		check(res, "fov_wide_on_late_join", waitIs(fov, Cfg.CameraFov), Cfg.CameraFov)
		state(res, "Idle", 0, 0, 0, false)
		check(res, "fov_restored_on_event_end", waitIs(fov, FOV_OUTSIDE), FOV_OUTSIDE)
		camera.FieldOfView = before
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
		local valueLabel, track = h.find(BAR .. "/Value"), barTrack()
		check(res, "bar_value_separators", valueLabel and valueLabel.Text, "2,500/4,000")
		if valueLabel and track then
			check(res, "bar_value_inside_track", within(h.rect(track), h.rect(valueLabel)), true)
			local middle = valueLabel.AbsolutePosition + valueLabel.AbsoluteSize / 2
			local hits = h.player:WaitForChild("PlayerGui"):GetGuiObjectsAtPosition(middle.X, middle.Y)
			local valueAt, fillAt = table.find(hits, valueLabel), table.find(hits, named(BAR, "Fill"))
			check(res, "bar_value_over_fill", valueAt ~= nil and (fillAt == nil or valueAt < fillAt), true)
		end
		state(res, "Fight", "keep", 1234567, 2000000, true, 100)
		check(
			res,
			"bar_value_millions",
			waitIs(function()
				return textOf(BAR, "Value")
			end, "1,234,567/2,000,000"),
			"1,234,567/2,000,000"
		)
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

	-- Owner 2026-11-05: the odds under the bar's right side. Judged on the engine's rects at the viewport the run is on: BossEventUi
	-- writes the bar's size for the live screen, so ui_layout's solver cannot place it at another one.
	local function checkDropList(res)
		local hp = Cfg.HpPerPlayer
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true, 100)
		check(res, "drop_shown_in_fight", waitShown(DROP, true), true)
		local list = h.find(DROP)
		if not list then
			return
		end
		ReplicatedStorage:SetAttribute(
			"BossStatus",
			HttpService:JSONEncode({ { Id = "Shouted", EndsAt = workspace:GetServerTimeNow() + 30 } })
		)
		task.wait(0.5) -- the bar's pop has ended: its size is judged below

		local heading, rule = list:FindFirstChild("Heading"), list:FindFirstChild("Rule")
		check(res, "drop_heading", heading and h.visible(heading) and heading.Text, "Drop:")
		check(res, "drop_rule_shown", rule ~= nil and h.visible(rule), true)

		local odds = RelicConfig.Odds("big_raga")
		table.sort(odds, function(a, b)
			return a.Odds > b.Odds
		end)
		check(res, "drop_has_relics", #odds > 0, true)
		check(res, "drop_side_chance_is_config", ("%.3f"):format(RelicConfig.RagaSidekickChance * 100), "0.001")
		local rowCount = 0
		for _, child in list:GetChildren() do
			rowCount += string.sub(child.Name, 1, 4) == "Row_" and 1 or 0
		end
		check(res, "drop_row_count", rowCount, #odds + 1)
		local parts, missing = {}, false
		local function add(part)
			missing = missing or part == nil
			if part then
				table.insert(parts, part)
			end
		end
		add(heading)
		add(rule)
		for _, row in odds do
			local name = "Row_" .. row.Id
			local label = list:FindFirstChild(name)
			check(res, "drop_text_" .. name, label and label.Text, ("%s %s%%"):format(row.Name, tostring(row.Odds)))
			check(res, "drop_colour_" .. name, label and label.TextColor3, GachaConfig.RARITY_COLORS[row.Rarity])
			add(label)
		end
		local side = list:FindFirstChild("Row_side_raga")
		check(res, "drop_text_Row_side_raga", side and side.Text, "Big Raga 0.001%")
		check(res, "drop_colour_Row_side_raga", side and side.TextColor3, Color3.new(0, 0, 0))
		add(side)
		if side then
			local color, stroke = textStroke(side)
			local light = luminance(color)
			h.check(res, "drop_outline_light", light, ">= " .. OUTLINE_MIN_LUMINANCE, light >= OUTLINE_MIN_LUMINANCE)
			h.check(res, "drop_outline_shows", stroke, "<= " .. STROKE_SHOWS, stroke <= STROKE_SHOWS)
		end

		-- Non-interactive, whatever the implementer nests.
		local active = {}
		for _, d in { list, table.unpack(list:GetDescendants()) } do
			if d:IsA("GuiObject") and d.Active then
				table.insert(active, d.Name)
			end
		end
		h.checkList(res, "drop_not_active", active)

		if missing then -- its own check above already failed
			state(res, "Idle", 0, 0, 0, false)
			ReplicatedStorage:SetAttribute("BossStatus", nil)
			return
		end
		local size = workspace.CurrentCamera.ViewportSize
		local tag = isDesktop() and "desktop" or "phone"
		local screen = { x = 0, y = 0, w = size.X, h = size.Y }
		local barRect = h.rect(h.find(BAR))
		local others = { BossBar = barRect, LeaveButton = h.rect(h.find(LEAVE)) }
		for _, tile in { "Quests", "Shop" } do
			local found = h.find("HudChrome/ShopColumn/" .. tile)
			check(res, "drop_tile_exists_" .. tile, found ~= nil, true)
			if found and h.visible(found) then
				others[tile] = h.rect(found)
			end
		end
		local status = h.find(BAR .. "/Status/Status_Shouted")
		if status then
			others.Status = h.rect(status)
		end
		local crossed, outOfOrder, outside, clipped = {}, {}, {}, {}
		for i, a in parts do
			local ra = h.rect(a)
			if not within(screen, ra) then
				table.insert(outside, a.Name)
			end
			if a:IsA("TextLabel") and not a.TextFits then
				table.insert(clipped, a.Name)
			end
			for name, r in others do
				if crossing(ra, r) then
					table.insert(crossed, a.Name .. " x " .. name)
				end
			end
			for j = i + 1, #parts do
				local b = parts[j]
				local rb = h.rect(b)
				if crossing(ra, rb) then
					table.insert(crossed, a.Name .. " x " .. b.Name)
				end
			end
			local nextPart = parts[i + 1]
			if nextPart and h.rect(nextPart).y < ra.y + ra.h - Spec.Tolerance then
				table.insert(outOfOrder, a.Name .. " before " .. nextPart.Name)
			end
		end
		h.checkList(res, "drop_no_overlap_" .. tag, crossed)
		h.checkList(res, "drop_in_odds_order_" .. tag, outOfOrder)
		h.checkList(res, "drop_on_screen_" .. tag, outside)
		h.checkList(res, "drop_text_fits_" .. tag, clipped)
		local r = h.rect(list)
		local barBottom = barRect.y + barRect.h
		h.check(res, "drop_under_bar_" .. tag, r.y, ">= " .. barBottom, r.y >= barBottom - Spec.Tolerance)
		local middle = barRect.x + barRect.w / 2
		h.check(res, "drop_right_side_" .. tag, r.x, ">= " .. middle, r.x >= middle - Spec.Tolerance)
		local centre = r.x + r.w / 2
		local rightMost = barRect.x + barRect.w * (1 - DROP_RIGHT_SHARE)
		h.check(res, "drop_far_right_" .. tag, centre, "> " .. rightMost, centre > rightMost)

		-- Owner's reference: a centred column, the rule shorter than the rows.
		local offCentre, leftAligned, small = {}, {}, {}
		local widestRow = 0
		for _, part in parts do
			local partRect = h.rect(part)
			if math.abs(partRect.x + partRect.w / 2 - centre) > Spec.Tolerance then
				table.insert(offCentre, part.Name)
			end
			if part:IsA("TextLabel") and part.TextXAlignment ~= Enum.TextXAlignment.Center then
				table.insert(leftAligned, part.Name)
			end
			if string.sub(part.Name, 1, 4) == "Row_" then
				widestRow = math.max(widestRow, partRect.w)
				if isDesktop() and partRect.h < DROP_ROW_MIN_HEIGHT then
					table.insert(small, part.Name)
				end
			end
		end
		h.checkList(res, "drop_centred_" .. tag, offCentre)
		h.checkList(res, "drop_centre_aligned_" .. tag, leftAligned)
		h.checkList(res, "drop_rows_bigger_" .. tag, small)
		local ruleWidth = h.rect(rule).w
		h.check(res, "drop_rule_shorter_" .. tag, ruleWidth, "< " .. widestRow, ruleWidth < widestRow)

		h.check(res, "bar_on_screen_" .. tag, barRect, "inside the screen", within(screen, barRect))
		local topRight = h.find("HudChrome/TopRight")
		check(res, "bar_clear_of_top_right_" .. tag, topRight ~= nil and crossing(barRect, h.rect(topRight)), false)
		if isDesktop() and size.X >= BAR_SIZE_MIN_SCREEN then
			local minWidth = size.X * BAR_MIN_WIDTH_SHARE
			h.check(res, "bar_wide", barRect.w, ">= " .. minWidth, barRect.w >= minWidth)
			h.check(res, "bar_tall", barRect.h, ">= " .. BAR_MIN_HEIGHT, barRect.h >= BAR_MIN_HEIGHT)
			for name, least in { Value = BAR_VALUE_MIN_TEXT, Title = BAR_TITLE_MIN_TEXT } do
				local label = h.find(BAR .. "/" .. name)
				local tall = label and label.TextBounds.Y or 0
				h.check(res, "bar_" .. string.lower(name) .. "_text_tall", tall, ">= " .. least, tall >= least)
			end
		end
		ReplicatedStorage:SetAttribute("BossStatus", nil)

		-- A leave takes it; a Prep in the event never had it (prep_droplist_shown).
		state(res, "Fight", "keep", hp, hp, false)
		check(res, "drop_hidden_on_leave", waitShown(DROP, false), false)
		state(res, "Idle", 0, 0, 0, false)
	end

	-- 1:00-3:00: each joiner sees the header too, and a bar already at the right width.
	local function checkLateJoin(res)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 10, 3000, 4000, false)
		onlyShown(res, "before_join", { BossButton = true }, { Invite = true })
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
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds - 0.5, 3000, 4000, true, 100)
		check(res, "late_intro_bar_shown", waitShown(BAR, true), true)
		local early = fillRatio() or 0
		h.check(res, "late_intro_fill_follows_the_clock", early, "> 0.5 of 0.75", early > 0.5)
		task.wait(0.7)
		checkRatio(res, "late_intro_fill_ends_at_hp", 3000 / 4000)
	end

	local function checkOutsider(res)
		state(res, "Prep", Cfg.PrepSeconds - 3, 4000, 4000, false)
		onlyShown(res, "outsider_prep", { BossButton = true }, { Invite = true })
		state(res, "Fight", Cfg.PrepSeconds, 4000, 4000, false)
		task.wait(1)
		onlyShown(res, "outsider_spawn", { BossButton = true }, { Invite = true })
		-- A leave: everything of the arena goes with the attribute.
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, 4000, 4000, true, 100)
		check(res, "leaver_bar_shown_first", waitShown(BAR, true), true)
		state(res, "Fight", "keep", 4000, 4000, false)
		onlyShown(res, "after_leave", {}, { Invite = true, BossButton = true }) -- rejoining after leaving: no rule
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
		local label = hasText(WARNING, WARNING_TEXT)
		check(res, "reduced_warning_is_red", label ~= nil and isRed(label.TextColor3), true)
		check(res, "reduced_warning_solid", label ~= nil and label.TextTransparency <= TEXT_SOLID, true)
		h.checkList(res, "reduced_warning_text_alone", warningBareList())
		-- Still on screen here: the end of the event takes the Warning too.
		state(res, "Idle", 0, 0, 0, false)
		onlyShown(res, "event_end", {})

		-- The button: glow yes, pulse no.
		state(res, "Prep", 5, 0, 0, false)
		checkButtonShows(res, "reduced")
		local spread = watchPulse(1.5)
		h.check(
			res,
			"reduced_button_no_pulse",
			spread or "no PulseScale",
			"<= " .. STILL_MAX_SPREAD,
			spread ~= nil and spread <= STILL_MAX_SPREAD
		)
		state(res, "Idle", 0, 0, 0, false)
		waitShown(BUTTON, false)
	end

	-- Owner 2026-11-05: the team is exhausted. Aerial camera, dim, centred countdown, a loading sign full at the end time.
	local function checkWaitView(res)
		local camera = workspace.CurrentCamera
		local wait = Cfg.RefillWaitSeconds
		local fightAt = Cfg.PrepSeconds + Cfg.IntroSeconds + 5
		local hp = Cfg.HpPerPlayer
		local function waitSet(seconds)
			setup(res, "boss_ui_wait:" .. tostring(seconds))
		end
		local function scriptable()
			return camera.CameraType == Enum.CameraType.Scriptable
		end

		local panel = h.find(PANEL)
		local message, countdown = h.find(PANEL .. "/Message"), h.find(PANEL .. "/Countdown")
		local fill, dim = h.find(PANEL .. "/Loading/Fill"), h.find(PANEL .. "/Dim")
		check(res, "wait_panel_complete", panel and message and countdown and fill and dim and true, true)
		check(res, "wait_cframe_present", type(Cfg.WaitCameraCFrame), "function")
		if not (panel and message and countdown and fill and dim) or type(Cfg.WaitCameraCFrame) ~= "function" then
			return
		end
		local function atAerial()
			local character = h.player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local frame = Cfg.WaitCameraCFrame(Arena.Center, root and root.Position)
			return (camera.CFrame.Position - frame.Position).Magnitude < WAIT_CAMERA_SLACK
		end

		state(res, "Idle", 0, 0, 0, false)
		task.wait(0.2)
		local typeBefore, subjectBefore, fovBefore = camera.CameraType, camera.CameraSubject, camera.FieldOfView
		state(res, "Fight", fightAt, hp, hp, true, 100)
		waitShown(BAR, true)
		task.wait(0.2)
		local inEventType = camera.CameraType
		local homeBefore = camera.CFrame.Position
		local function atHome()
			return (camera.CFrame.Position - homeBefore).Magnitude < WAIT_CAMERA_SLACK
		end
		local function checkRestored(tag, fov)
			check(res, tag .. "_panel_gone", waitShown(PANEL, false), false)
			check(res, tag .. "_not_scriptable", waitIs(scriptable, false), false)
			check(res, tag .. "_camera_type", camera.CameraType, typeBefore)
			check(res, tag .. "_camera_subject", camera.CameraSubject, subjectBefore)
			-- The wait's spot follows the runner now, so nearness to it no longer tells the two views apart.
			check(res, tag .. "_camera_back_home", waitIs(atHome, true), true)
			check(res, tag .. "_fov", math.round(camera.FieldOfView), math.round(fov))
		end
		check(res, "wait_none_panel_hidden", shown(PANEL), false)
		check(res, "wait_none_camera_free", camera.CameraType, typeBefore)

		-- Not this player's wait: the end time on anything else starts nothing.
		ReplicatedStorage:SetAttribute("BossWaitEndsAt", workspace:GetServerTimeNow() + wait)
		task.wait(0.4)
		check(res, "wait_other_panel_hidden", shown(PANEL), false)
		check(res, "wait_other_camera_free", camera.CameraType, inEventType)
		ReplicatedStorage:SetAttribute("BossWaitEndsAt", nil)

		-- A whole wait, sampled to its end.
		waitSet(wait)
		local waitStart = os.clock()
		check(res, "wait_panel_shown", waitShown(PANEL, true), true)
		check(res, "wait_camera_scriptable", waitIs(scriptable, true), true)
		check(res, "wait_camera_at_aerial", waitIs(atAerial, true), true)
		check(res, "wait_fov", math.round(camera.FieldOfView), math.round(Cfg.WaitCameraFov))
		check(res, "wait_message_shown", h.visible(message), true)
		check(
			res,
			"wait_message_says_exhausted",
			string.find(string.lower(message.Text), "exhaust", 1, true) ~= nil,
			true
		)
		check(res, "wait_countdown_shown", h.visible(countdown), true)
		check(res, "wait_fill_shown", h.visible(fill), true)
		check(res, "wait_dim_shown", h.visible(dim), true)
		check(res, "wait_dim_is_frame", dim.ClassName, "Frame")
		h.check(
			res,
			"wait_dim_slight",
			dim.BackgroundTransparency,
			DIM_MIN .. " to " .. DIM_MAX,
			dim.BackgroundTransparency >= DIM_MIN and dim.BackgroundTransparency <= DIM_MAX
		)
		local view = camera.ViewportSize
		h.check(
			res,
			"wait_dim_full_screen",
			dim.AbsoluteSize,
			view,
			dim.AbsoluteSize.X >= view.X - 1 and dim.AbsoluteSize.Y >= view.Y - 1
		)
		for name, label in { countdown = countdown, message = message } do
			local centre = (label.AbsolutePosition + label.AbsoluteSize / 2 + GuiService:GetGuiInset()) / view
			h.check(
				res,
				"wait_" .. name .. "_centred",
				centre,
				"within " .. WAIT_CENTRE_SLACK,
				math.abs(centre.X - 0.5) <= WAIT_CENTRE_SLACK and math.abs(centre.Y - 0.5) <= 2 * WAIT_CENTRE_SLACK
			)
		end

		-- The live camera sees the whole boss, wheel top to feet (BossEventTests judges the runner and the sizes, purely).
		local outside = 0
		for _, height in { 0, Arena.BossTotalHeight } do
			local at = camera:WorldToViewportPoint(Arena.Center + Vector3.yAxis * height)
			if at.Z <= 0 or at.X < 0 or at.Y < 0 or at.X > view.X or at.Y > view.Y then
				outside += 1
			end
		end
		check(res, "wait_view_sees_boss", outside, 0)

		-- The bar, its status row and Leave stay on top of the dim.
		ReplicatedStorage:SetAttribute(
			"BossStatus",
			HttpService:JSONEncode({ { Id = "Shouted", EndsAt = workspace:GetServerTimeNow() + wait + 5 } })
		)
		-- The cell always exists, hidden; it must show and take its place in the row before a hit test can find it.
		waitIs(function()
			local cell = named(BAR, "Status_Shouted")
			return cell ~= nil and h.visible(cell)
		end, true)
		task.wait(0.1)
		local playerGui = h.player:WaitForChild("PlayerGui")
		for name, target in { bar = h.find(BAR), status = named(BAR, "Status_Shouted"), leave = h.find(LEAVE) } do
			local firstTarget, firstDim
			if target then
				local middle = target.AbsolutePosition + target.AbsoluteSize / 2
				for i, hit in playerGui:GetGuiObjectsAtPosition(middle.X, middle.Y) do
					if not firstTarget and (hit == target or hit:IsDescendantOf(target)) then
						firstTarget = i
					elseif hit == dim then
						firstDim = i
					end
				end
			end
			h.check(
				res,
				"wait_" .. name .. "_above_dim",
				tostring(firstTarget) .. " vs " .. tostring(firstDim),
				"target hit before the dim",
				firstTarget ~= nil and firstDim ~= nil and firstTarget < firstDim
			)
		end
		check(res, "wait_leave_usable", h.find(LEAVE).Active and h.find(LEAVE).Interactable, true)
		ReplicatedStorage:SetAttribute("BossStatus", nil)

		-- Both follow the end time. Past 5 s the panel holds at 1 and full until the server clears the attribute.
		local endsAt = h.player:GetAttribute("BossWaitEndsAt")
		local worstFill, badCount, lastFill, shrank, loose, lost, seen = 0, 0, 0, false, false, false, {}
		while endsAt and endsAt - workspace:GetServerTimeNow() > 0.03 do
			local remaining = endsAt - workspace:GetServerTimeNow()
			local size = fill.Size.X
			worstFill = math.max(worstFill, math.abs(size.Scale - (1 - remaining / wait)))
			shrank = shrank or size.Scale < lastFill - 0.001
			lastFill = size.Scale
			loose = loose or size.Offset ~= 0
			local shownCount = tonumber(countdown.Text)
			seen[shownCount or "bad"] = true
			if
				shownCount ~= math.ceil(remaining)
				and shownCount ~= math.ceil(remaining + WAIT_COUNT_SLACK)
				and shownCount ~= math.ceil(remaining - WAIT_COUNT_SLACK)
			then
				badCount += 1
			end
			lost = lost or not scriptable() or not shown(PANEL)
			task.wait()
		end
		h.check(res, "wait_fill_follows_end_time", worstFill, "<= " .. FILL_SLACK, worstFill <= FILL_SLACK)
		check(res, "wait_fill_never_shrinks", shrank, false)
		check(res, "wait_fill_uses_scale", loose, false)
		check(res, "wait_countdown_follows_end_time", badCount, 0)
		check(res, "wait_countdown_reaches_1", seen[1] == true, true)
		check(res, "wait_countdown_never_0_or_more_than_5", seen[0] or seen[6] or seen.bad or false, false)
		check(res, "wait_view_held_throughout", lost, false)
		task.wait(0.1)
		h.check(res, "wait_fill_complete_at_end", fill.Size.X.Scale, ">= 0.98", fill.Size.X.Scale >= 0.98)
		check(res, "wait_countdown_holds_1_at_end", countdown.Text, "1")
		local waited = os.clock() - waitStart
		h.check(res, "wait_ran_its_time", waited, "about " .. wait, math.abs(waited - wait) < 1)

		-- Revive: everything back, still in the event.
		waitSet("none")
		checkRestored("revive", Cfg.CameraFov)

		-- A wait seen part-way, as after a rejoin of the view: the panel starts from the end time, not from 0.
		waitSet(2)
		waitShown(PANEL, true)
		local partFill = fill.Size.X.Scale
		h.check(
			res,
			"wait_late_fill_from_end_time",
			partFill,
			">= " .. (1 - 2 / wait - FILL_SLACK),
			partFill >= 1 - 2 / wait - FILL_SLACK
		)
		h.check(res, "wait_late_countdown", countdown.Text, "<= 2", (tonumber(countdown.Text) or 99) <= 2)

		-- Leaving mid-wait: BossEvent goes first, the end time a moment later.
		waitSet(4)
		check(res, "wait_leave_case_shown", waitShown(PANEL, true), true)
		state(res, "Fight", "keep", hp, hp, false)
		checkRestored("wait_leave", fovBefore)
		waitSet("none")

		-- The event's end mid-wait.
		state(res, "Fight", fightAt, hp, hp, true, 100)
		waitSet(4)
		check(res, "wait_end_case_shown", waitShown(PANEL, true), true)
		state(res, "Idle", 0, 0, 0, false)
		checkRestored("wait_event_end", fovBefore)
		camera.FieldOfView = fovBefore
	end

	function scenarios.ui_boss(res)
		h.waitGuis()
		local gui = h.find(ROOT)
		check(res, "boss_gui_present", gui ~= nil, true)
		if not gui then
			return
		end
		for _, path in { TELEPORT, DECLINE, HUD .. "/Slot1", WARNING, BAR, LEAVE, BUTTON, DROP } do
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
			checkIntroFill(res)
			checkSpawn(res)
			checkBarValues(res)
			checkDropList(res)
			checkLateJoin(res)
			checkOutsider(res)
			checkCameraFov(res)
			checkWaitView(res)
			checkStatusRow(res)
			checkReduced(res)
		end, debug.traceback)
		h.check(res, "boss_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		ReplicatedStorage:SetAttribute("BossStatus", nil)
		ReplicatedStorage:SetAttribute("BossWaitEndsAt", nil)
		h.player:SetAttribute("ReduceEffects", savedReduce)
		setup(res, "restore:boss_ui")
		local spent = os.clock() - started
		h.check(res, "boss_scenario_time", spent, "< " .. BUDGET, spent < BUDGET)
	end

	-- After the real presses (UiSpec.Clicks boss_*). The spy answers false to Teleport: refused means not joined.
	function after.boss_refused_keeps_button(res)
		check(res, "boss_refused_teleport_keeps_button", shown(BUTTON), true)
	end
	function after.boss_invite_hidden(res)
		check(res, "boss_decline_hides_invite", waitShown(INVITE, false), false)
		check(res, "boss_decline_keeps_button", shown(BUTTON), true)
	end
	function after.boss_button_prompts_for_sidekick(res)
		check(
			res,
			"boss_locked_button_prompts_for_sidekick",
			waitIs(function()
				return shownTextHas(ROOT, "sidekick")
			end, true),
			true
		)
		check(res, "boss_locked_button_stays", shown(BUTTON), true)
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
