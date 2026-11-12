--!nonstrict
-- Boss event UI (design doc 4.37, docs/BOSS_EVENT_SPEC.md Flow and Team HUD, Client/BossEventUi). Owned by ui-test-writer.
-- ui_boss drives the published attributes through UiTestSetup boss_ui_* and never joins an event; the real presses are
-- the boss_* clicks in UiSpec.Clicks, judged after them here.
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   Every part is built once and only hidden: Invite, TeamHud, Warning, BossBar, LeaveButton, BossButton, BossesPanel, EditTeamButton
--     sit directly in the ScreenGui.
--   Team HUD (owner 2026-11-05): TeamHud/Header/CloseButton closes it with at least 1 pick, and invokes BossEventPrepRun; with none, red
--     TeamHud/TeamWarning "Select a character first" fades within 1 s and the HUD stays. EditTeamButton reopens it until the spawn.
--     TeamHud/AverageStamina reads "Average stamina: <n> s", from BossTeamStamina<n> of the picks. The HUD opens on LastBossTeam's ids.
--   Versus (BOSS_EVENT_SPEC "Team HUD", owner 2026-11-10): TeamHud/Versus "VS", TeamHud/RagaPortrait (ImageLabel, SidekickArt.side_raga
--     Portrait), TeamHud/Header/Logo the HudIcons.Boss image (design doc 4.40). TeamHud/Note hides while TeamWarning shows, and back.
--   BossBar/BossTimer: left of the Title's text, above the track, counting to TotalSeconds.
--   Minibar (owner 2026-11-05): RacerHud's Team/Slot<n> read BossTeam while BossEvent is true. While BossWaitEndsAt is set every filled
--     slot is tired grey and none active, and its Arc's Fill dots run from empty to full by that time.
--   Named anywhere inside their part: Invite Countdown; TeamHud Countdown; BossBar Fill (its parent is the track).
--   Boss bar (owner 2026-11-05): BossBar/Title "Big Raga" above the track; BossBar/Value "current/max" with thousands separators,
--     inside the track and drawn over the Fill.
--   Boss bar size (owner 2026-11-05): at desktop width at least 60% of the screen and 56 px tall, Value text 28 px, Title text 36 px.
--     On every screen it stays on screen and clear of HudChrome/TopRight.
--   DropList hidden for now (owner 2026-11-11, both bosses): never shown during an event; the layout below waits for its return.
--   DropList layout (owner 2026-11-05): Heading and rows centre aligned, Rule centred and narrower than the rows, its right edge on
--     the HP bar's right edge and its top just under the bar's bottom, clear of Leave and the bar.
--   HUD columns (design doc 4.40, owner 2026-11-10): while BossEvent is true HudChrome/Grid and HudChrome/ShopColumn are hidden;
--     TopRight, AutoSlot and UpgradeSlot stay shown. Once BossEvent clears both columns show again (unless the Upgrades tree is open).
--   DropList is a GuiObject directly in the ScreenGui, under the bar's right side, shown only to event players in Fight (it may stay
--     on the exhaustion view). Directly in it: Heading "Drop:", Rule, and one Row_<id> per RelicConfig.Odds("big_raga") row plus
--     Row_side_raga, top to bottom in descending odds. Nothing in it is Active. It stays hidden until the spawn Warning has gone, for late
--     joiners and with reduced motion too. The Warning stays horizontally centred on the screen and reserves no room for the list.
--   TeamHud/List: one GuiButton per eligible character, directly in List, named its character id.
--   Slot<n> has attribute CharacterId while it holds a character, none while it is empty.
--   Invite Countdown counts to teleport closing (3:00), TeamHud Countdown to the spawn (1:00). "m:ss" or plain seconds.
--   Decline lasts for one event (one BossEventStart): a new start shows the Invite again.
--   Plaza flow (owner 2026-11-05): the Invite closes by itself after Cfg.InviteSeconds. BossButton shows for anyone outside the event
--     and outside a tutorial, past teleport close too, Invite up or not, declined or not, in a duel too, locked too. Its Text is
--     exactly "Bosses". BackgroundTransparency 1, an ImageLabel Icon showing HudIcons.Boss, the Text at the bottom (design doc
--     4.40 "Market pill and Bosses button"). Child Glow: a UIStroke or a GuiObject. Child UIScale named PulseScale (UiSpec.TransientScales), whose
--     Scale changes until teleporting closes, still with reduced motion. Owner 2026-11-11: its size, Icon size and top offset and
--     its label's font and on-screen TextSize equal HudChrome/Grid/Index's (cell, Icon, Label) at the same viewport. It sits just
--     under Roblox's top bar (top within BUTTON_MAX_GAP px under GuiService.TopbarInset.Max.Y). Its left edge, at every pulse
--     scale, is HudChrome/Grid's when its bottom at BUTTON_PULSE stays above the Grid's top, else within BUTTON_MAX_GAP px
--     past max(TopbarInset.Min.X, the Grid's right edge). At BUTTON_PULSE it overlaps neither the Grid, the shown roll
--     (RollToast/Toast) nor the shown Money / Gems readout. A press only toggles BossesPanel, in every state, and never teleports (owner rule). In an event the panel's Status
--     card Cards/Card_<boss> has State "Live" and its Go (owner 2026-11-11, replaces the Status line and BossAction): with no Sidekick it fires nothing and BossPrompt shows text with
--     "sidekick"; past the close it fires nothing and BossPrompt shows "Teleporting closed". Before a press, no such text shows.
--   Idle (docs/BOSS_EVENT_SPEC.md "Paid spawn"): BossesPanel is the paid spawn, judged by UiBossPaid, so idle checks here skip it.
--   A popup's rows draw only while it shows and only a real press opens it, so they are judged after the clicks.
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
--     FieldOfView is Cfg.WaitCameraFov; after a revive it returns to Cfg.CameraFov. Message reads exactly "Exhausted, reviving".
--     Message, Countdown and Loading stay small (the WAIT_*_MAX numbers) and clear of DropList and the bar.
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
local Spec = require(script.Parent.UiSpec)
local RunnerVisual = require(script.Parent.Parent:WaitForChild("RunnerVisual"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local SidekickArt = require(Shared:WaitForChild("SidekickArt"))
local Icons = require(script.Parent.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))

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
local BOSSES = ROOT .. "/BossesPanel"
local EDIT_TEAM = ROOT .. "/EditTeamButton"
local PARTS = {
	Invite = INVITE,
	TeamHud = HUD,
	Warning = WARNING,
	BossBar = BAR,
	LeaveButton = LEAVE,
	ExhaustedPanel = PANEL,
	BossButton = BUTTON,
	DropList = DROP,
	BossesPanel = BOSSES,
	EditTeamButton = EDIT_TEAM,
}

local NOTE_TEXT = "Only characters with Sidekicks can be equipped for bosses"
local WARNING_TEXT = "Big Raga has emerged, take him down!!!"
local BOSS_NAME = "Big Raga"
local BUTTON_TEXT = "Bosses"
-- Bosses cards (owner 2026-11-11, draft B; BOSS_EVENT_SPEC "Bosses cards"): the live boss's card, with Go on it.
local LIVE_CARD = "RacerBossEvent/BossesPanel/Cards/Card_boss_raga"
local TEAM_WARNING_TEXT = "Select a character first"
local TEAM_WARNING_SECONDS = 1 -- owner 2026-11-05
local WARNING_SLACK = 0.3 -- s around it

local SHOW_WAIT = 2 -- s: an attribute change has replicated and the UI has followed
local WARNING_MAX = 12 -- s: proposed, "goes away by itself" has no number in the docs
local WARNING_QUIET = 1 -- s hidden in a row before a flashing Warning counts as gone
local FLASH_SAMPLE = 3 -- s the Warning and the intro fill are watched
local COUNTDOWN_SLACK = 2 -- s
local RATIO_SLACK = 0.02
local FILL_SLACK = 0.1 -- of the bar: the fill against the server clock while it moves
local FOV_OUTSIDE = 63 -- a value no script sets, so a restore to a fixed default shows
local BUDGET = 110 -- s: the whole scenario
local DIM_MIN, DIM_MAX = 0.5, 0.85 -- BackgroundTransparency: "slightly dimmed"
local WAIT_CENTRE_SLACK = 0.1 -- of the screen
local WAIT_CAMERA_SLACK = 40 -- studs: a boss shake may be on top of the framing
-- Copies of BossWaitCamera's locals, plus a margin: its drift is part of the view, and BossShake only rotates.
local WAIT_PULL_SECONDS = 0.6 + 0.1
local WAIT_VIEW_SLACK = 3 + 1 -- studs: DRIFT_STUDS and a small tolerance
local WAIT_COUNT_SLACK = 0.15 -- s around a whole-second change
local WAIT_MESSAGE_TEXT = "Exhausted, reviving"
-- Owner 2026-11-05, px on 1920x907; a bigger window may grow them in step.
local WAIT_MESSAGE_MAX_HEIGHT, WAIT_COUNTDOWN_MAX_HEIGHT = 36, 48
local WAIT_LOADING_MAX_WIDTH = 400
local WAIT_SIZE_HEIGHT, WAIT_SIZE_WIDTH = 907, 1920
local PHONE_MAX_HEIGHT = 500
local MIN_WARNING_HEIGHT = 40 -- px at desktop: "big"
local BAR_CENTRE_SLACK = 0.05 -- of the screen width
local BAR_MAX_BOTTOM = 0.3 -- of the screen height: "top middle"
local BAR_MIN_WIDTH_SHARE = 0.6 -- of the screen, owner 2026-11-05
local BAR_MIN_HEIGHT = 56 -- px
local BAR_VALUE_MIN_TEXT = 28 -- px
local BAR_TITLE_MIN_TEXT = 36 -- px
local BAR_SIZE_MIN_SCREEN = 1280 -- px of width where those sizes are judged
local TEXT_GONE = 0.9 -- TextTransparency: the flash's out, "fully disappearing"
local TEXT_SOLID = 0.1 -- and its in
local STROKE_SHOWS = 0.5 -- stroke transparency at most, while the text shows
local STROKE_MAX_LUMINANCE = 0.2
local INVITE_SECONDS = Cfg.InviteSeconds or 3 -- read here so a missing value fails its own check, not the whole scenario
local INVITE_EARLY, INVITE_LATE = 0.5, 1 -- s around InviteSeconds, from the request that showed it
local PULSE_SAMPLE = 2 -- s the button's pulse is watched
local PULSE_MIN_SPREAD = 0.02 -- of its Scale: "pulses in size"
local STILL_MAX_SPREAD = 0.001
local BUTTON_MAX_GAP = 12 -- px under TopbarInset.Max.Y / past Roblox's buttons: "just below", "right of"
local BUTTON_PULSE = 1.08 -- the join pulse's biggest Scale (BossEventUi PULSE_SCALE): the button must have room for it
local ROLL = "RollToast/Toast" -- the top-centre roll (compact)
local MONEY = "RacerHud/Money" -- the Money / Gems readout (Gems sits inside Money)
local GRID = "HudChrome/Grid"
local COLUMN_BUTTON = GRID .. "/Index" -- a HUD column button (Client/HudChrome)

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
				-- BossTimer shares the Title's row: their drawn texts are judged by checkBossTimer, not their full-width frames.
				local sameRow = a.Parent == b.Parent
					and a.Parent == h.find(BAR)
					and (a.Name == "BossTimer" or b.Name == "BossTimer")
					and (a.Name == "Title" or b.Name == "Title")
				if not sameRow and not a:IsAncestorOf(b) and not b:IsAncestorOf(a) and crossing(ra, h.rect(b)) then
					table.insert(overlaps, a.Name .. " x " .. b.Name)
				end
			end
		end
		h.checkList(res, tag .. "_no_text_overlap", overlaps)
		h.checkList(res, tag .. "_text_fits", clipped)
		h.checkList(res, tag .. "_text_on_screen", outside)
		local onHud = {}
		for name, path in PARTS do
			if name ~= "Warning" and name ~= "BossesPanel" and shown(path) then -- the popup opens over the HUD by design
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
	-- Second result: the DropList showed before the Warning's last moment on screen.
	local function warningStays(maxSeconds)
		local started = os.clock()
		local lastShown = started
		local dropSeen, dropEarly = false, false
		while os.clock() - started < maxSeconds do
			local warningUp = shown(WARNING)
			dropSeen = dropSeen or shown(DROP)
			dropEarly = dropEarly or (warningUp and dropSeen)
			if warningUp then
				lastShown = os.clock()
			elseif os.clock() - lastShown >= WARNING_QUIET then
				return nil, dropEarly
			end
			task.wait(0.05)
		end
		return maxSeconds, dropEarly
	end
	-- Owner 2026-11-05: while the Warning shows the DropList does not; after it, it does. Call with the Warning up.
	local function checkDropAfterWarning(res, tag, maxSeconds)
		local left, dropEarly = warningStays(maxSeconds)
		check(res, tag .. "_warning_goes_away", left, nil)
		check(res, tag .. "_drop_hidden_during_warning", dropEarly, false)
		-- Owner 2026-11-11: the drop list is hidden for now, so it stays hidden after the Warning too.
		check(res, tag .. "_drop_stays_hidden_after_warning", waitShown(DROP, true), false)
	end
	-- Owner 2026-11-05: centred on the screen on any window, nothing moved aside for the list.
	local function checkWarningCentred(res, tag)
		local middle = workspace.CurrentCamera.ViewportSize.X / 2
		local label = hasText(WARNING, WARNING_TEXT)
		for name, object in { frame = h.find(WARNING), label = label } do
			local r = h.rect(object)
			local off = math.abs(r.x + r.w / 2 - middle)
			h.check(res, tag .. "_warning_centred_" .. name, off, "<= " .. Spec.Tolerance, off <= Spec.Tolerance)
		end
		check(res, tag .. "_warning_text_centred", label and label.TextXAlignment, Enum.TextXAlignment.Center)
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
	-- The biggest Scale difference over `seconds`, the leftmost and lowest edge the button reached; nil without its PulseScale.
	local function watchPulse(seconds)
		local button = h.find(BUTTON)
		local scale = button and button:FindFirstChild("PulseScale")
		if not (scale and scale:IsA("UIScale")) then
			return nil
		end
		local r = h.rect(button)
		local low, high, left, bottom = scale.Scale, scale.Scale, r.x, r.y + r.h
		local stop = os.clock() + seconds
		while os.clock() < stop do
			low, high = math.min(low, scale.Scale), math.max(high, scale.Scale)
			r = h.rect(button)
			left, bottom = math.min(left, r.x), math.max(bottom, r.y + r.h)
			task.wait(0.03)
		end
		return high - low, left, bottom
	end
	-- Owner 2026-11-11 (design doc 4.40): the Bosses button is drawn at a HUD column button's exact sizes, read on screen
	-- (HudChrome's UIScale included) at the same viewport. The pulse is read at rest: PulseScale is transient.
	local function checkColumnSizes(res, tag, b, bossIcon)
		local column = h.find(COLUMN_BUTTON)
		local columnIcon = column and column:FindFirstChild("Icon")
		local columnLabel = column and column:FindFirstChild("Label")
		local wrong = {}
		if not (b and bossIcon and column and columnIcon and columnLabel) then
			table.insert(wrong, "BossButton/Icon or " .. COLUMN_BUTTON .. " Icon / Label missing")
		else
			local pulse = b:FindFirstChild("PulseScale")
			local p = pulse and pulse:IsA("UIScale") and pulse.Scale or 1
			local function near(what, got, want)
				if math.abs(got - want) > 1 then
					table.insert(wrong, ("%s: Bosses %.1f, column %.1f"):format(what, got, want))
				end
			end
			near("cell width", b.AbsoluteSize.X / p, column.AbsoluteSize.X)
			near("cell height", b.AbsoluteSize.Y / p, column.AbsoluteSize.Y)
			near("icon width", bossIcon.AbsoluteSize.X / p, columnIcon.AbsoluteSize.X)
			near("icon height", bossIcon.AbsoluteSize.Y / p, columnIcon.AbsoluteSize.Y)
			near(
				"icon top offset",
				(bossIcon.AbsolutePosition.Y - b.AbsolutePosition.Y) / p,
				columnIcon.AbsolutePosition.Y - column.AbsolutePosition.Y
			)
			-- On-screen text size: TextSize x the object's draw scale (AbsoluteSize / Size offset).
			local columnScale = column.AbsoluteSize.Y / column.Size.Y.Offset
			local bossScale = b.AbsoluteSize.Y / p / b.Size.Y.Offset
			near("label TextSize", b.TextSize * bossScale, columnLabel.TextSize * columnScale)
			if b.Font ~= columnLabel.Font then
				table.insert(
					wrong,
					("label Font: Bosses %s, column %s"):format(tostring(b.Font), tostring(columnLabel.Font))
				)
			end
		end
		h.check(
			res,
			tag .. "_button_column_sizes",
			#wrong == 0 and "same" or table.concat(wrong, "; "),
			"same as " .. COLUMN_BUTTON,
			#wrong == 0
		)
	end
	local function checkButtonShows(res, tag)
		check(res, tag .. "_button_shown", waitShown(BUTTON, true), true)
		check(res, tag .. "_button_text", h.find(BUTTON) and h.find(BUTTON).Text, BUTTON_TEXT)
		check(res, tag .. "_button_active", h.find(BUTTON) and h.find(BUTTON).Active, true)
		check(res, tag .. "_button_glows", waitIs(glowing, true), true)
		-- Design doc 4.40 "Market pill and Bosses button": the HUD column look, a transparent button with the Tab tilt Boss
		-- icon (ImageLabel Icon, HudIcons.Boss) and its label under it
		local b = h.find(BUTTON)
		check(res, tag .. "_button_transparent", b and b.BackgroundTransparency, 1)
		local bossIcon = b and b:FindFirstChild("Icon")
		check(
			res,
			tag .. "_button_boss_icon",
			bossIcon and bossIcon:IsA("ImageLabel") and bossIcon.Image,
			Icons.Boss.Image
		)
		check(
			res,
			tag .. "_button_label_under_icon",
			b
				and b:IsA("TextButton")
				and b.TextYAlignment == Enum.TextYAlignment.Bottom
				and bossIcon ~= nil
				and bossIcon.Position.Y.Scale == 0,
			true
		)
		checkColumnSizes(res, tag, b, bossIcon)
	end
	local function checkButtonPlace(res)
		local inset = GuiService.TopbarInset
		local spread, left, bottom = watchPulse(PULSE_SAMPLE)
		h.check(
			res,
			"button_pulses",
			spread or "no PulseScale",
			">= " .. PULSE_MIN_SPREAD,
			spread ~= nil and spread >= PULSE_MIN_SPREAD
		)
		-- Owner 2026-11-11 (design doc 4.40): just under Roblox's top bar; at the left column's x when its bottom at the
		-- biggest pulse stays above the column's top, else right of Roblox's buttons (and of the column); clear of both
		-- the column and the roll, and of the Money / Gems readout
		local button = h.find(BUTTON)
		local rest = button and h.rect(button)
		local pulse = button and button:FindFirstChild("PulseScale")
		local p = pulse and pulse:IsA("UIScale") and pulse.Scale or 1
		local top = rest and rest.y or 0
		local restW, restH = rest and rest.w / p or 0, rest and rest.h / p or 0
		local grid = h.find(GRID)
		local gridRect = grid and h.rect(grid)
		local room = gridRect ~= nil and top + restH * BUTTON_PULSE <= gridRect.y
		local wantX = gridRect and (room and gridRect.x or math.max(inset.Min.X, gridRect.x + gridRect.w))
		h.check(
			res,
			"button_left_column_x",
			left or "no PulseScale",
			wantX and (room and tostring(wantX) or ("%.1f..%.1f"):format(wantX, wantX + BUTTON_MAX_GAP))
				or "no " .. GRID,
			left ~= nil
				and wantX ~= nil
				and (
					room and math.abs(left - wantX) <= 1
					or not room and left >= wantX and left <= wantX + BUTTON_MAX_GAP
				)
		)
		h.check(
			res,
			"button_under_top_bar",
			top,
			("%.1f..%.1f"):format(inset.Max.Y, inset.Max.Y + BUTTON_MAX_GAP),
			top >= inset.Max.Y - 1 and top <= inset.Max.Y + BUTTON_MAX_GAP
		)
		-- The button's rect at the biggest pulse (it grows right and down from its top-left corner)
		local big = left and bottom and { x = left, y = top, w = restW * BUTTON_PULSE, h = bottom - top }
		local function overlaps(a, b)
			return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
		end
		h.check(
			res,
			"button_clear_of_left_column",
			big and gridRect and (overlaps(big, gridRect) and "overlaps" or "clear") or "no PulseScale / " .. GRID,
			"clear",
			big ~= nil and gridRect ~= nil and not overlaps(big, gridRect)
		)
		-- Hidden parts take no room: a hidden roll or readout passes, and says so.
		for _, part in { { "button_clear_of_roll", ROLL }, { "button_clear_of_money", MONEY } } do
			local o = h.find(part[2])
			local r = o and o:IsA("GuiObject") and o.Visible and h.rect(o)
			h.check(
				res,
				part[1],
				not big and "no PulseScale" or not r and "not shown" or overlaps(big, r) and "overlaps" or "clear",
				"clear",
				big ~= nil and (not r or not overlaps(big, r))
			)
		end
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

		-- Owner 2026-11-05: at 3:00, by the clock alone, only the pulse ends. The button stays for its popup.
		state(res, "Fight", Cfg.JoinSeconds - 1.5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, false)
		task.wait(0.2)
		check(res, "button_shown_before_close", shown(BUTTON), true)
		task.wait(2)
		check(res, "button_shown_at_close", shown(BUTTON), true)
		check(res, "invite_hidden_at_close", shown(INVITE), false)
		state(res, "Fight", Cfg.JoinSeconds + 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, false)
		task.wait(0.3)
		check(res, "invite_hidden_after_close", shown(INVITE), false)
		checkButtonShows(res, "past_close")
		local stillSpread = watchPulse(0.6)
		h.check(
			res,
			"button_no_pulse_past_close",
			stillSpread or "no PulseScale",
			"<= " .. STILL_MAX_SPREAD,
			stillSpread ~= nil and stillSpread <= STILL_MAX_SPREAD
		)

		state(res, "Prep", 5, 0, 0, false)
		check(res, "invite_back_for_new_event", waitShown(INVITE, true), true)
		check(res, "button_back_for_new_event", waitShown(BUTTON, true), true)
		state(res, "Idle", 0, 0, 0, false)
		check(res, "invite_hidden_at_end", waitShown(INVITE, false), false)
		-- At the end the button stays: idle, it is the paid spawn (UiBossPaid).
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

		-- With the Invite gone the button still works; the presses are the clicks boss_button_locked and boss_action_locked.
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
	-- Owner 2026-11-05: X and its warning's parts, the average stamina, the HUD opening on the saved team. Attributes set here stay on
	-- this client: the HUD only reads them. The presses are the boss_close_* and boss_edit_team clicks.
	local function checkTeamHudSaved(res)
		local warning = h.find(HUD .. "/TeamWarning")
		check(res, "hud_warning_is_text", warning ~= nil and warning:IsA("TextLabel"), true)
		check(res, "hud_warning_text", warning and warning.Text, TEAM_WARNING_TEXT)
		check(res, "hud_warning_red", warning ~= nil and isRed(warning.TextColor3), true)
		local close = h.find(HUD .. "/Header/CloseButton")
		check(res, "hud_close_is_a_button", close ~= nil and close:IsA("GuiButton"), true)
		state(res, "Prep", 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, true, 100)
		check(res, "hud_shown_with_empty_team", waitShown(HUD, true), true)
		check(res, "hud_warning_hidden_at_rest", shown(HUD .. "/TeamWarning"), false)
		check(res, "hud_close_shown", shown(HUD .. "/Header/CloseButton"), true)
		local function average()
			return textOf(HUD, "AverageStamina")
		end
		check(res, "hud_average_no_team", waitIs(average, "Average stamina: -"), "Average stamina: -")
		state(res, "Idle", 0, 0, 0, false)
		waitShown(HUD, false)

		local ids = string.split(gearNames(), ",")
		h.player:SetAttribute("LastBossTeam", ids[2] .. "," .. ids[1] .. ",no_such_character")
		h.player:SetAttribute("BossTeamStamina1", 10)
		h.player:SetAttribute("BossTeamStamina2", 20)
		state(res, "Prep", 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, true, 100)
		check(res, "hud_saved_team_shown", waitShown(HUD, true), true)
		local function slotId(n)
			return function()
				local slot = h.find(HUD .. "/Slot" .. n)
				return slot and slot:GetAttribute("CharacterId")
			end
		end
		check(res, "hud_opens_on_saved_slot1", waitIs(slotId(1), ids[2]), ids[2])
		check(res, "hud_opens_on_saved_slot2", slotId(2)(), ids[1])
		check(res, "hud_saved_drops_unknown", slotId(3)(), nil)
		check(res, "hud_average_stamina", waitIs(average, "Average stamina: 15.0 s"), "Average stamina: 15.0 s")
		checkFit(res, "prep_saved_team")
		h.player:SetAttribute("LastBossTeam", "")
		h.player:SetAttribute("BossTeamStamina1", nil)
		h.player:SetAttribute("BossTeamStamina2", nil)
		state(res, "Idle", 0, 0, 0, false)
		waitShown(HUD, false)
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
		local versus = h.find(HUD .. "/Versus")
		check(res, "hud_versus_shown", versus ~= nil and h.visible(versus), true)
		check(res, "hud_versus_text", versus and versus.Text, "VS") -- checkFit below judges it with the other texts
		local raga = h.find(HUD .. "/RagaPortrait")
		check(res, "hud_raga_portrait_shown", raga ~= nil and h.visible(raga), true)
		check(res, "hud_raga_portrait_is_image", raga ~= nil and raga:IsA("ImageLabel"), true)
		check(res, "hud_raga_portrait_image", raga and raga.Image, SidekickArt.side_raga.Portrait)
		local logo = h.find(HUD .. "/Header/Logo")
		check(res, "hud_logo_shown", logo ~= nil and h.visible(logo), true)
		check(res, "hud_logo_boss_icon", logo and logo.Image, Icons.Boss.Image)
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
		checkTeamHudSaved(res)
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
		checkWarningCentred(res, "spawn")

		local reduced = reducedNow()
		if not reduced then
			local bar = h.find(BAR)
			check(res, "bar_pops_in", bar ~= nil and bar:FindFirstChild("MotionScale") ~= nil, true)
		end
		local red, heavy, strokeDark, strokeSolid, strokeFades = true, true, true, true, true
		local faintest, solidest = 0, 1
		local bare = {}
		local dropWithWarning = false
		local stop = os.clock() + FLASH_SAMPLE
		while os.clock() < stop do
			dropWithWarning = dropWithWarning or (shown(WARNING) and shown(DROP))
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
		local stays, dropEarly = warningStays(math.max(left, WARNING_QUIET + 0.1))
		check(res, "warning_goes_away_by_itself", stays, nil)
		check(res, "spawn_drop_hidden_during_warning", dropWithWarning or dropEarly, false)
		-- Owner 2026-11-11: the drop list is hidden for now, so it stays hidden after the Warning too.
		check(res, "spawn_drop_stays_hidden_after_warning", waitShown(DROP, true), false)
		check(res, "bar_stays_after_warning", shown(BAR), true)
		state(res, "Fight", "keep", hp - 1, hp, true, 100)
		task.wait(0.4)
		check(res, "warning_not_back_on_hp_change", shown(WARNING), false)
	end

	-- Owner 2026-11-05: the bar fills with the rise, in 1.5 s, on the server's clock.
	local function checkIntroFill(res)
		local intro = Cfg.RiseSeconds
		check(res, "rise_is_1_5_seconds", intro, 1.5)
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
			h.player:SetAttribute("BossStatus", rows and HttpService:JSONEncode(rows) or nil)
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
		-- Owner 2026-11-11: the drop list is hidden for now; the odds stay in the Bosses popup's Details.
		check(res, "drop_hidden_in_fight", waitShown(DROP, true), false)
		h.player:SetAttribute(
			"BossStatus",
			HttpService:JSONEncode({ { Id = "Shouted", EndsAt = workspace:GetServerTimeNow() + 30 } })
		)
		task.wait(0.5) -- the bar's pop has ended: its size is judged below

		check(res, "drop_side_chance_is_config", ("%.3f"):format(RelicConfig.RagaSidekickChance * 100), "0.001")
		local size = workspace.CurrentCamera.ViewportSize
		local tag = isDesktop() and "desktop" or "phone"
		local screen = { x = 0, y = 0, w = size.X, h = size.Y }
		local barRect = h.rect(h.find(BAR))
		-- Design doc 4.40 (owner 2026-11-10): both columns hide in the event; TopRight and Auto / Upgrade stay.
		for _, column in { "Grid", "ShopColumn" } do
			check(res, "boss_column_hidden_" .. column, waitShown("HudChrome/" .. column, false), false)
		end
		for _, keep in { "TopRight", "AutoSlot", "UpgradeSlot" } do
			check(res, "boss_hud_kept_" .. keep, waitShown("HudChrome/" .. keep, true), true)
		end
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
		h.player:SetAttribute("BossStatus", nil)

		-- A leave takes it; a Prep in the event never had it (prep_droplist_shown).
		state(res, "Fight", "keep", hp, hp, false)
		check(res, "drop_hidden_on_leave", waitShown(DROP, false), false)
		state(res, "Idle", 0, 0, 0, false)
		-- The columns come back once BossEvent clears (the Upgrades tree hides them on its own).
		if not shown("RacerUpgrades/Panel") then
			for _, column in { "Grid", "ShopColumn" } do
				check(res, "boss_column_back_" .. column, waitShown("HudChrome/" .. column, true), true)
			end
		end
	end

	-- Owner 2026-11-05: the time left in the event, top left above the HP bar, sharing the Title's row with no text on text.
	local function checkBossTimer(res)
		local hp = Cfg.HpPerPlayer
		local elapsed = Cfg.PrepSeconds + Cfg.IntroSeconds + 5
		state(res, "Fight", elapsed, hp, hp, true, 100)
		check(res, "timer_bar_shown", waitShown(BAR, true), true)
		local timer, title, track = h.find(BAR .. "/BossTimer"), h.find(BAR .. "/Title"), barTrack()
		check(res, "timer_shown", timer ~= nil and h.visible(timer), true)
		if not (timer and title and track) then
			return
		end
		task.wait(0.2)
		local got = secondsIn(timer.Text)
		local want = Cfg.TotalSeconds - elapsed
		h.check(
			res,
			"timer_counts_to_the_end",
			got or timer.Text,
			("%d +- %d"):format(want, COUNTDOWN_SLACK),
			got ~= nil and math.abs(got - want) <= COUNTDOWN_SLACK
		)
		check(res, "timer_is_clock_format", string.match(timer.Text, "^%d+:%d%d$") ~= nil, true)
		local t, b, r = h.rect(timer), h.rect(title), h.rect(track)
		h.check(res, "timer_above_track", t.y + t.h, "<= " .. r.y, t.y + t.h <= r.y + Spec.Tolerance)
		h.check(res, "timer_at_left", t.x, "about " .. r.x, math.abs(t.x - r.x) <= Spec.Tolerance)
		local timerEnd = t.x + timer.TextBounds.X
		local titleStart = b.x + (b.w - title.TextBounds.X) / 2
		h.check(res, "timer_text_clear_of_title_text", timerEnd, "<= " .. titleStart, timerEnd <= titleStart)
		state(res, "Idle", 0, 0, 0, false)
	end

	-- Owner 2026-11-05: in the event the minibar is the event team. During the wait: all grey, none active, bars refilling by the end
	-- time. Attributes set here stay on this client: TeamHud only reads them. The wait's start and end are sampled, not all of it.
	local function checkWaitMinibar(res)
		local hud = h.find("RacerHud")
		local row = hud and hud:FindFirstChild("Team", true)
		check(res, "minibar_row_present", row ~= nil, true)
		if not row then
			return
		end
		local grey, tired = UiTheme.Palette.TeamGrey, UiTheme.Palette.TeamTired
		local hp, wait = Cfg.HpPerPlayer, Cfg.RefillWaitSeconds
		local ids = string.split(gearNames(), ",")
		local function arcVisible(n)
			local arc = row:FindFirstChild("Slot" .. n) and row["Slot" .. n]:FindFirstChild("Arc")
			return arc ~= nil and arc.Visible
		end
		-- Fill dots shown over all of them, on one slot.
		local function arcShare(n)
			local arc = row["Slot" .. n]:FindFirstChild("Arc")
			local shown_, total = 0, 0
			for _, d in arc:GetChildren() do
				if d.Name == "Fill" then
					total += 1
					shown_ += d.Visible and 1 or 0
				end
			end
			return total > 0 and shown_ / total or 0
		end
		local TEAM_SLOTS = 2 -- BossTeam below holds ids[1] and ids[2]; a slot with no character is never tired (TeamHud render)
		local function sameColour(a, b)
			return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.01 -- float32 only
		end
		-- nil when every team slot is tired grey and none active, else what is not.
		local function tiredProblem()
			for n = 1, TEAM_SLOTS do
				local slot = row["Slot" .. n]
				local ring = slot:FindFirstChildOfClass("UIStroke")
				if not sameColour(ring.Color, grey) then
					return "Slot" .. n .. " ring " .. tostring(ring.Color)
				elseif not sameColour(slot.BackgroundColor3, tired) then
					return "Slot" .. n .. " background " .. tostring(slot.BackgroundColor3)
				elseif slot.Glow.BackgroundTransparency ~= 1 then
					return "Slot" .. n .. " glow " .. slot.Glow.BackgroundTransparency
				end
			end
			return nil
		end
		local mainTeam = h.player:GetAttribute("Team")
		h.player:SetAttribute("BossTeam", ids[1] .. "," .. ids[2])
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true, 100)
		-- Slot 1 shows the main Team's first too: only with BossEvent here does the row read BossTeam.
		check(
			res,
			"minibar_in_event",
			waitIs(function()
				return h.player:GetAttribute("BossEvent")
			end, true),
			true
		)
		for n = 1, TEAM_SLOTS do
			check(
				res,
				"minibar_event_team_slot" .. n,
				waitIs(function()
					return arcVisible(n)
				end, true),
				true
			)
		end
		check(
			res,
			"minibar_event_team_only_two",
			waitIs(function()
				return arcVisible(3)
			end, false),
			false
		)
		check(res, "minibar_main_team_kept", h.player:GetAttribute("Team"), mainTeam)
		local bonus = hud:FindFirstChild("Bonus", true)
		-- Owner 2026-11-06: the badge reads the event team's own bonus, never the main Team's.
		local mainBonus = h.player:GetAttribute("TeamBonus")
		h.player:SetAttribute("TeamBonus", "Preset:leaf")
		h.player:SetAttribute("BossTeamBonus", "")
		check(
			res,
			"minibar_badge_ignores_main_team",
			waitIs(function()
				return bonus ~= nil and bonus.Visible
			end, false),
			false
		)
		h.player:SetAttribute("TeamBonus", mainBonus)
		h.player:SetAttribute("BossTeamBonus", "Preset:leaf")
		check(
			res,
			"minibar_badge_reads_event_team",
			waitIs(function()
				return bonus ~= nil and bonus.Visible
			end, true),
			true
		)
		check(
			res,
			"minibar_badge_names_preset",
			bonus ~= nil and string.find(bonus.Text, "TEAM SEVEN", 1, true) ~= nil,
			true
		)
		h.player:SetAttribute("BossTeamBonus", nil)

		-- A whole wait's start: from about empty, with a run slot that would otherwise be active.
		h.player:SetAttribute("RunSlot", 1)
		setup(res, "boss_ui_wait:" .. wait)
		check(res, "minibar_wait_all_tired", waitIs(tiredProblem, nil), nil)
		local slotOne = row:FindFirstChild("Slot1")
		local thin = slotOne and slotOne:FindFirstChildOfClass("UIStroke").Thickness
		check(res, "minibar_wait_none_active", thin, 2)
		local function expectShare(ends)
			return math.clamp(1 - (ends - workspace:GetServerTimeNow()) / wait, 0, 1)
		end
		local ends = h.player:GetAttribute("BossWaitEndsAt")
		h.check(
			res,
			"minibar_wait_starts_low",
			arcShare(1),
			("%.2f +- %s"):format(ends and expectShare(ends) or 0, FILL_SLACK),
			ends ~= nil and math.abs(arcShare(1) - expectShare(ends)) <= FILL_SLACK
		)
		-- The last of a wait: full exactly as it ends, never falling.
		setup(res, "boss_ui_wait:1.5")
		task.wait(0.1)
		ends = h.player:GetAttribute("BossWaitEndsAt")
		local worst, last, falls = 0, 0, 0
		while ends and ends - workspace:GetServerTimeNow() > 0.03 do
			for n = 1, TEAM_SLOTS do
				worst = math.max(worst, math.abs(arcShare(n) - expectShare(ends)))
			end
			falls += arcShare(1) < last - 0.001 and 1 or 0
			last = arcShare(1)
			task.wait()
		end
		h.check(res, "minibar_wait_fill_follows_end_time", worst, "<= " .. FILL_SLACK, worst <= FILL_SLACK)
		check(res, "minibar_wait_fill_never_falls", falls, 0)
		task.wait(0.1)
		check(res, "minibar_wait_full_at_end", arcShare(1), 1)
		check(res, "minibar_wait_still_tired_at_end", tiredProblem(), nil)

		setup(res, "boss_ui_wait:none")
		check(
			res,
			"minibar_revive_leaves_grey",
			waitIs(function()
				return tiredProblem() ~= nil
			end, true),
			true
		)
		h.player:SetAttribute("RunSlot", nil)
		h.player:SetAttribute("BossTeam", nil)
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
		checkWarningCentred(res, "late_join")
		checkDropAfterWarning(res, "late_join", WARNING_MAX)

		if isDesktop() then
			local restore = h.setPanels({ "RacerIndex/Panel" })
			check(res, "leave_hidden_under_a_panel", waitShown(LEAVE, false), false)
			restore()
			check(res, "leave_back_after_panel", waitShown(LEAVE, true), true)
		end

		-- Near the rise's end the fill is nearly done, whenever the client first drew it.
		state(res, "Idle", 0, 0, 0, false)
		check(res, "late_intro_bar_clear", waitShown(BAR, false), false)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.RiseSeconds - 0.3, 3000, 4000, true, 100)
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
		check(res, "reduced_drop_hidden_with_warning", shown(DROP), false)
		local label = hasText(WARNING, WARNING_TEXT)
		check(res, "reduced_warning_is_red", label ~= nil and isRed(label.TextColor3), true)
		check(res, "reduced_warning_solid", label ~= nil and label.TextTransparency <= TEXT_SOLID, true)
		h.checkList(res, "reduced_warning_text_alone", warningBareList())
		-- Still on screen here: the end of the event takes the Warning too.
		state(res, "Idle", 0, 0, 0, false)
		onlyShown(res, "event_end", {}, { BossButton = true }) -- idle: the paid spawn (UiBossPaid)

		-- The same order as without reduced motion, here to the Warning's end.
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, 4000, 4000, true, 100)
		check(res, "reduced_again_warning_shown", waitShown(WARNING, true), true)
		checkWarningCentred(res, "reduced")
		checkDropAfterWarning(res, "reduced", WARNING_MAX)
		state(res, "Idle", 0, 0, 0, false)
		waitShown(DROP, false)

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
	end

	-- Owner 2026-11-05: the team is exhausted. Camera high above the runner, dim, centred countdown, a loading sign full at the end time.
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
		local function runnerPosition()
			local runner = RunnerVisual.LocalRunner()
			return runner and runner.PrimaryPart and runner.PrimaryPart.Position or nil
		end
		local caughtClock, caughtRunner, caughtTravel = nil, nil, nil
		-- After the pull-out, on the spot for the runner (or the fallback without one) as the wait began.
		local function atRunnerView()
			if not caughtTravel or os.clock() - caughtClock < WAIT_PULL_SECONDS then
				return false
			end
			local frame = Cfg.WaitCameraCFrame(Arena.Center, caughtRunner)
			return (camera.CFrame.Position - frame.Position).Magnitude <= WAIT_VIEW_SLACK + caughtTravel
		end

		state(res, "Idle", 0, 0, 0, false)
		task.wait(0.2)
		local typeBefore, subjectBefore, fovBefore = camera.CameraType, camera.CameraSubject, camera.FieldOfView
		state(res, "Fight", fightAt, hp, hp, true, 100)
		waitShown(BAR, true)
		task.wait(0.2)
		local inEventType = camera.CameraType
		-- The camera follows a moving runner (BossWaitCamera.homeFrame carries its offset from the subject), so a world position
		-- goes stale. The offset's length, since RunnerView.alignYaw turns it around the runner: 40 studs here, 200 in the wait's view (120 out, 160 up).
		local homeBefore = Spec.CameraReach(camera)
		local function atHome()
			return math.abs(Spec.CameraReach(camera) - homeBefore) < WAIT_CAMERA_SLACK
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

		-- BossWaitCamera catches the runner on its first step after this attribute arrives, so a moving runner's one frame counts.
		h.player:GetAttributeChangedSignal("BossWaitEndsAt"):Once(function()
			local clock, at = os.clock(), runnerPosition()
			task.wait()
			local later = runnerPosition()
			caughtClock, caughtRunner = clock, at
			caughtTravel = at and later and (later - at).Magnitude or 0
		end)

		-- A whole wait, sampled to its end.
		waitSet(wait)
		local waitStart = os.clock()
		check(res, "wait_panel_shown", waitShown(PANEL, true), true)
		check(res, "wait_camera_scriptable", waitIs(scriptable, true), true)
		check(res, "wait_camera_at_runner_view", waitIs(atRunnerView, true, WAIT_PULL_SECONDS + SHOW_WAIT), true)
		check(res, "wait_fov", math.round(camera.FieldOfView), math.round(Cfg.WaitCameraFov))
		check(res, "wait_message_shown", h.visible(message), true)
		check(res, "wait_message_text", message.Text, WAIT_MESSAGE_TEXT)
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
		local loading = fill.Parent
		local tallScale = math.max(1, view.Y / WAIT_SIZE_HEIGHT)
		local wideScale = math.max(1, view.X / WAIT_SIZE_WIDTH)
		local messageMax = WAIT_MESSAGE_MAX_HEIGHT * tallScale
		local countdownMax = WAIT_COUNTDOWN_MAX_HEIGHT * tallScale
		local loadingMax = WAIT_LOADING_MAX_WIDTH * wideScale
		h.check(res, "wait_message_small", h.rect(message).h, "<= " .. messageMax, h.rect(message).h <= messageMax)
		h.check(
			res,
			"wait_countdown_small",
			h.rect(countdown).h,
			"<= " .. countdownMax,
			h.rect(countdown).h <= countdownMax
		)
		h.check(res, "wait_loading_small", h.rect(loading).w, "<= " .. loadingMax, h.rect(loading).w <= loadingMax)
		check(res, "wait_message_text_fits", message.TextFits, true)
		check(res, "wait_countdown_text_fits", countdown.TextFits, true)
		-- Judged on rects: the DropList may still be waiting for this fresh spawn's Warning, and its place does not change.
		local panelCrossed = {}
		for _, part in { message, countdown, loading } do
			for name, path in { BossBar = BAR } do -- DropList hidden for now (owner 2026-11-11): nothing to judge
				if crossing(h.rect(part), h.rect(h.find(path))) then
					table.insert(panelCrossed, part.Name .. " x " .. name)
				end
			end
		end
		h.checkList(res, "wait_panel_clear_of_drop_and_bar", panelCrossed)
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
			local at = camera:WorldToViewportPoint(Vector3.new(Arena.Center.X, Arena.DaisY + height, Arena.Center.Z))
			if at.Z <= 0 or at.X < 0 or at.Y < 0 or at.X > view.X or at.Y > view.Y then
				outside += 1
			end
		end
		check(res, "wait_view_sees_boss", outside, 0)

		-- The bar, its status row and Leave stay on top of the dim.
		h.player:SetAttribute(
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
		h.player:SetAttribute("BossStatus", nil)

		-- Both follow the end time. The count reads the whole wait (8.5) until the first whole second, then whole seconds.
		-- Past the wait the panel holds at 1 and full until the server clears the attribute.
		local endsAt = h.player:GetAttribute("BossWaitEndsAt")
		local worstFill, badCount, lastFill, shrank, loose, lost, seen = 0, 0, 0, false, false, false, {}
		local overWait = false
		local function countAt(left)
			return left > math.floor(wait) and wait or math.max(1, math.ceil(left))
		end
		while endsAt and endsAt - workspace:GetServerTimeNow() > 0.03 do
			local remaining = endsAt - workspace:GetServerTimeNow()
			local size = fill.Size.X
			worstFill = math.max(worstFill, math.abs(size.Scale - (1 - remaining / wait)))
			shrank = shrank or size.Scale < lastFill - 0.001
			lastFill = size.Scale
			loose = loose or size.Offset ~= 0
			local shownCount = tonumber(countdown.Text)
			seen[shownCount or "bad"] = true
			overWait = overWait or (shownCount ~= nil and shownCount > wait)
			if
				shownCount ~= countAt(remaining)
				and shownCount ~= countAt(remaining + WAIT_COUNT_SLACK)
				and shownCount ~= countAt(remaining - WAIT_COUNT_SLACK)
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
		check(res, "wait_countdown_never_0_or_over_the_wait", seen[0] or overWait or seen.bad or false, false)
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

	-- The Dodge bar (design doc 4.37): over the roster minibar, its art at the left, a hit's words replacing it.
	function scenarios.ui_boss_dodge(res)
		local hp = Cfg.HpPerPlayer
		local Dodge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BossDodge"))
		-- A boss_ui_* setup delivers the pose data Moment reads (design doc 7 "Join size"); without one it waits forever.
		state(res, "Idle", 0, 0, 0, false)
		local at, name = Dodge.Moment(1)
		local lead = Dodge.SweepSeconds * 0.5
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + at - lead, hp, hp, true, 100)
		local DODGE = "RacerBossDodge/DodgeBar"
		check(res, "dodge_bar_shown", waitShown(DODGE, true, 0.4), true)
		local bar = h.find(DODGE)
		if bar then
			local gui = h.player:WaitForChild("PlayerGui")
			local row = gui.RacerHud.Level:FindFirstChild("Team")
			local inner = bar:FindFirstChild("Bar")
			local wheel = bar:FindFirstChild("Wheel")
			local subtitle = bar:FindFirstChild("Subtitle")
			check(
				res,
				"dodge_bar_above_team_row",
				bar.AbsolutePosition.Y + bar.AbsoluteSize.Y <= row.AbsolutePosition.Y,
				true
			)
			check(res, "dodge_wheel_art", wheel ~= nil and wheel.Image ~= "", true)
			check(
				res,
				"dodge_wheel_at_left_end",
				wheel ~= nil
					and math.abs(wheel.AbsolutePosition.X + wheel.AbsoluteSize.X / 2 - bar.AbsolutePosition.X) <= 1,
				true
			)
			check(
				res,
				"dodge_subtitle_says_how",
				subtitle ~= nil and h.visible(subtitle) and subtitle.Text:find("white") ~= nil,
				true
			)
			local spot = inner and inner:FindFirstChild("Spot")
			check(res, "dodge_spot_clear_of_start", spot ~= nil and spot.Position.X.Scale >= 0.2, true)
		end
		local RESULT = "RacerBossDodge/Result"
		check(res, "dodge_hit_text_shows", waitShown(RESULT, true, lead + 1), true)
		local result = h.find(RESULT)
		check(res, "dodge_hit_words", result and result.Text, Dodge.HitText[name])
		check(res, "dodge_hit_replaces_bar", waitShown(DODGE, false, 0.6), false) -- after its 0.3 s disappearing
		check(res, "dodge_hit_text_red", result and result.TextColor3.R > 0.9 and result.TextColor3.G < 0.3, true)
		-- The dash: into the side asked, mirrored for the other.
		local RunnerVisual = require(script.Parent.Parent:WaitForChild("RunnerVisual"))
		local RunnerFactory = require(ReplicatedStorage.Shared.RunnerFactory)
		local probe = RunnerFactory.build("db_hero")
		RunnerVisual.Pose(probe, CFrame.identity, 0, 1)
		RunnerVisual.PoseDash(probe, CFrame.identity, 0.5, 1)
		local rightUp = probe.Torso.CFrame.UpVector.X
		RunnerVisual.Pose(probe, CFrame.identity, 0, 1)
		RunnerVisual.PoseDash(probe, CFrame.identity, 0.5, -1)
		local leftUp = probe.Torso.CFrame.UpVector.X
		probe:Destroy()
		check(res, "dash_leans_right_when_right", rightUp > 0.4, true)
		check(res, "dash_leans_left_when_left", leftUp < -0.4, true)
		state(res, "Idle", 0, 0, 0, false)
		check(res, "dodge_bar_gone_after_event", waitShown(DODGE, false), false)
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
			onlyShown(res, "rest", {}, { BossButton = true }) -- idle: the paid spawn (UiBossPaid)
			checkInviteWaitsForTutorial(res)
			checkInvite(res)
			checkLocked(res)
			checkTeamHud(res)
			checkIntroFill(res)
			checkSpawn(res)
			checkBarValues(res)
			checkDropList(res)
			checkBossTimer(res)
			checkLateJoin(res)
			checkOutsider(res)
			checkCameraFov(res)
			checkWaitView(res)
			checkWaitMinibar(res)
			checkStatusRow(res)
			checkReduced(res)
		end, debug.traceback)
		h.check(res, "boss_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		h.player:SetAttribute("BossStatus", nil)
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
				return shown(BOSSES .. "/BossPrompt") and shownTextHas(BOSSES .. "/BossPrompt", "sidekick")
			end, true),
			true
		)
		check(res, "boss_locked_button_stays", shown(BUTTON), true)
	end
	-- A press in an event only opens the popup (owner rule): Expect.Remote = false judges that it does not teleport.
	function after.boss_panel_raging(res)
		check(res, "boss_panel_opens", waitShown(BOSSES, true), true)
		check(
			res,
			"boss_panel_live_card",
			waitIs(function()
				local card = h.find(LIVE_CARD)
				return card and card:GetAttribute("State")
			end, "Live"),
			"Live"
		)
		check(res, "boss_panel_go", textOf(LIVE_CARD, "Go"), "Go")
		check(res, "boss_panel_go_shown", shown(LIVE_CARD .. "/Go"), true)
		check(res, "boss_panel_no_details_in_event", shown(BOSSES .. "/BossDetails"), false)
		check(res, "boss_panel_no_next_in_event", shown(BOSSES .. "/NextEvent"), false)
		check(res, "boss_panel_button_text", h.find(BUTTON) and h.find(BUTTON).Text, BUTTON_TEXT)
		checkFit(res, "boss_panel")
	end
	function after.boss_panel_closed(res)
		check(res, "boss_panel_toggles_closed", waitShown(BOSSES, false), false)
		check(res, "boss_panel_keeps_button", shown(BUTTON), true)
	end
	function after.boss_go_closed(res)
		local go = h.find(LIVE_CARD .. "/Go")
		check(res, "boss_go_stays_past_close", go ~= nil and h.visible(go), true)
		check(res, "boss_go_disabled_past_close", go ~= nil and go.Active, false)
		local card = h.find(LIVE_CARD)
		check(res, "boss_card_live_past_close", card and card:GetAttribute("State"), "Live")
		check(res, "boss_prompt_past_close", textOf(BOSSES, "BossPrompt"), "Teleporting closed")
	end
	-- The warning has faded by the time an After runs (Waits.ClickSettle): UiSpec's watcher saw it.
	function after.boss_team_warning(res)
		local watch = Spec.BossEvent.WarningWatch
		check(res, "boss_warning_appeared", watch.ShownAt ~= nil, true)
		check(res, "boss_warning_solid_at_first", watch.Transparency, 0)
		check(res, "boss_warning_shown_text", watch.Text, TEAM_WARNING_TEXT)
		check(res, "boss_warning_hides_note", watch.NoteShown, false)
		check(res, "boss_note_back_after_warning", waitShown(HUD .. "/Note", true), true)
		local seconds = watch.ShownAt and watch.HiddenAt and watch.HiddenAt - watch.ShownAt
		h.check(
			res,
			"boss_warning_fades_in_1_s",
			seconds or "still shown",
			TEAM_WARNING_SECONDS .. " +- " .. WARNING_SLACK,
			seconds and math.abs(seconds - TEAM_WARNING_SECONDS) <= WARNING_SLACK
		)
		check(res, "boss_close_refused_keeps_hud", shown(HUD), true)
		check(res, "boss_close_refused_no_edit_team", shown(EDIT_TEAM), false)
	end
	function after.boss_hud_closed(res)
		check(res, "boss_close_hides_hud", waitShown(HUD, false), false)
		check(res, "boss_close_shows_edit_team", waitShown(EDIT_TEAM, true), true)
		check(res, "boss_close_no_warning", shown(HUD .. "/TeamWarning"), false)
		check(res, "boss_close_keeps_leave", shown(LEAVE), true)
		checkFit(res, "boss_hud_closed")
	end
	function after.boss_hud_reopened(res)
		check(res, "boss_edit_team_shows_hud", waitShown(HUD, true), true)
		check(res, "boss_edit_team_hides_itself", waitShown(EDIT_TEAM, false), false)
		local slot = h.find(HUD .. "/Slot1")
		check(res, "boss_edit_team_keeps_pick", slot and slot:GetAttribute("CharacterId"), Spec.BossEvent.Pick)
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
