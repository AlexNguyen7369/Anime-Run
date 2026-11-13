--!nonstrict
-- Sidekick tutorial (design doc 4.36, 4.21; docs/SIDEKICK_SPEC.md "Summon presentation": "Tutorial and tests follow the galaxy
-- screen", owner 2026-11-12; Client/SidekickTutorial). Owned by ui-test-writer. Fixtures: UiTestSetup sidekick_tutorial_ready and
-- sidekick_tutorial:<step>. A press cannot be faked here: PanelSwitch.Action and a direct remote call stand in for the taps, and the
-- real taps are UiSpec.Clicks sidekick_tutorial_go (step 1), sidekick_tutorial_free (step 2, then the result) and
-- sidekick_tutorial_result_close (the reveal's end, then the equip step).
--
-- The steps on the galaxy screen (SIDEKICK_SPEC "Summon presentation", "Tutorial on the galaxy screen", owner 2026-11-12;
-- design doc 4.36: one free summon, the last step points to equip it in the Bag):
--   1. Screen closed: the spotlight is on the card's own open button Layer/Card/GoButton (the galaxy look stays on the summon
--      page only, design doc 4.36), which opens the screen (PanelSwitch "Sidekicks"). The card names the Sidekick.
--   2. Screen open: the spotlight is on RacerSidekicks/Canvas/AutoFuse, the free-summon button (its text says "free"), shown
--      while SidekickFreeUsed is false. GoButton is hidden.
--   3. The result: the free summon's reveal (RacerSidekickReveal) plays with the tutorial waiting: SidekickTutorial disabled,
--      taking no click, until the reveal is gone.
--   4. Equip: once the result is over (or at once when the summon lands with no reveal, as the direct remote call here), the
--      tutorial closes the summon screen itself (PanelSwitch "Sidekicks" closed, also when the reveal's end reopened it), so the
--      HUD shows; the ring is on HudChrome/Grid/Items and the card tells to equip it to join boss events. It closes by itself.
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen; prefer the screen's own names):
--   ScreenGui SidekickTutorial stays in PlayerGui for the session and is Enabled only while showing. Parts as Client/AutoRollTutorial:
--   Layer/Card (message), Layer/Ring, Layer/Arrow, Layer/Ripple. GoButton is Layer/Card/GoButton, shown in step 1 only.
--   The step comes only from attributes, the open screen and the reveal, with no saved step. Screen closed: step 1. Screen open:
--   step 2. So a rejoin, or closing the screen, goes back to step 1. SidekickFreeUsed (the saved flag) turning true: steps 3-4.
--   The script keeps watching for the session, and shows without a start delay once nothing blocks it.
--   Coordinator ruling 2026-11-05: auto-running must not delay it forever, so it shows during a normal track run (RaceEvent
--   "Racing"). A run-start or teleport transition may delay it a few seconds (RUN_WAIT).
--   Blocked, waiting and hidden: DuelActive, ShowdownActive or BossEvent true,
--   NeedsStarter true, or a ScreenGui AutoRollTutorial with Enabled true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SidekickConfig"))

local GUI = "SidekickTutorial"
local CARD = GUI .. "/Layer/Card"
local RING = GUI .. "/Layer/Ring"
local ARROW = GUI .. "/Layer/Arrow"
local RIPPLE = GUI .. "/Layer/Ripple"
local GO = CARD .. "/GoButton"
local REOPEN = "RacerSidekicks/Reopen" -- the galaxy look stays on the summon page (design doc 4.36)
local CANVAS = "RacerSidekicks/Canvas"
local FREE = CANVAS .. "/AutoFuse"
local REVEAL = "RacerSidekickReveal"
local ITEMS = "HudChrome/Grid/Items"
local WAIT = 5 -- s
local PROMPT = 1 -- s: shows this fast once nothing blocks it
local RUN_WAIT = 5 -- s: a run-start or teleport transition may delay it this long
local HIDDEN_FOR = 1 -- s a blocked tutorial is watched
local STEP3_MIN, STEP3_MAX = 1.5, 12 -- s: long enough to read, and it closes by itself
local PHONE_MAX_HEIGHT = 500
local RING_SLACK = 2 -- px

local Module = {}

function Module.Build(h)
	local scenarios, after = {}, {}
	local PanelSwitch = require(script.Parent.Parent:WaitForChild("PanelSwitch"))

	local function check(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local function setup(res, request)
		local ok, err = h.requestSetup(request)
		if not ok then
			h.check(res, "setup_" .. request, tostring(err), "ok", false)
		end
	end
	local function waitUntil(fn, seconds)
		local deadline = os.clock() + (seconds or WAIT)
		local value = fn()
		while not value and os.clock() < deadline do
			task.wait(0.05)
			value = fn()
		end
		return value and true or false
	end
	local function showing()
		local gui = h.find(GUI)
		return gui ~= nil and gui.Enabled
	end
	local function shown(path)
		local object = h.find(path)
		return object ~= nil and h.visible(object)
	end
	local function stepOne()
		return showing() and shown(GO) and not shown(CANVAS)
	end
	local function stepTwo()
		return showing() and shown(FREE) and not shown(GO)
	end
	local function staysHidden()
		task.wait(0.2) -- the fixture's attributes replicate
		local stop = os.clock() + HIDDEN_FOR
		while os.clock() < stop do
			if showing() then
				return false
			end
			task.wait(0.05)
		end
		return true
	end
	local function cardText()
		local text = {}
		local card = h.find(CARD)
		for _, d in card and card:GetDescendants() or {} do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and h.visible(d) then
				table.insert(text, string.lower(d.Text))
			end
		end
		return table.concat(text, " ")
	end
	local function has(piece)
		return string.find(cardText(), piece, 1, true) ~= nil
	end
	local function checkTopmost(res, name, path)
		local object = h.find(path)
		check(res, name .. "_present", object ~= nil and object:IsA("GuiButton"), true)
		if object then
			local r = h.rect(object)
			local top = h.topAt(r.x + r.w / 2, r.y + r.h / 2)
			check(res, name .. "_topmost", top ~= nil and (top == object or top:IsDescendantOf(object)), true)
		end
	end
	local function inside(outer, inner, slack)
		return inner.x >= outer.x - slack
			and inner.y >= outer.y - slack
			and inner.x + inner.w <= outer.x + outer.w + slack
			and inner.y + inner.h <= outer.y + outer.h + slack
	end
	local function overlaps(a, b)
		return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
	end
	local function ringAround(path)
		local ring, target = h.find(RING), h.find(path)
		return ring ~= nil and target ~= nil and inside(h.rect(ring), h.rect(target), RING_SLACK)
	end
	-- Desktop fit: the card on screen, the spotlit button on screen, and neither covers the other unless the button is in the card.
	local function checkFit(res, tag, path, inCard)
		local size = workspace.CurrentCamera.ViewportSize
		if size.Y <= PHONE_MAX_HEIGHT then
			return
		end
		local screen = { x = 0, y = 0, w = size.X, h = size.Y }
		local card, target = h.find(CARD), h.find(path)
		check(res, tag .. "_parts_present", card ~= nil and target ~= nil, true)
		if not (card and target) then
			return
		end
		check(res, tag .. "_card_on_screen", inside(screen, h.rect(card), 0), true)
		check(res, tag .. "_button_on_screen", inside(screen, h.rect(target), 0), true)
		if inCard then
			check(res, tag .. "_button_in_card", inside(h.rect(card), h.rect(target), 0), true)
		else
			check(res, tag .. "_card_clear_of_button", overlaps(h.rect(card), h.rect(target)), false)
		end
	end

	local standIn = nil
	local function checkWaits(res)
		setup(res, "sidekick_tutorial_ready")
		setup(res, "sidekick_tutorial:block:run")
		setup(res, "sidekick_tutorial:rebirth:0")
		waitUntil(function()
			return not showing()
		end) -- the fixture passes the unlock for a moment on its way here
		check(res, "below_unlock_hidden", staysHidden(), true)
		setup(res, "sidekick_tutorial:block:off")
		check(res, "below_unlock_hidden_on_foot", staysHidden(), true)
		setup(res, "sidekick_tutorial:rebirth:" .. (Config.UnlockRebirth - 1))
		check(res, "one_below_unlock_hidden", staysHidden(), true)

		for _, kind in { "duel", "showdown", "boss" } do
			setup(res, "sidekick_tutorial:block:" .. kind)
			setup(res, "sidekick_tutorial:rebirth:" .. Config.UnlockRebirth)
			check(res, "waits_during_" .. kind, staysHidden(), true)
			setup(res, "sidekick_tutorial:rebirth:" .. (Config.UnlockRebirth - 1))
			setup(res, "sidekick_tutorial:block:off")
		end

		-- Another tutorial first. The fixture has Rolls 1, so the real AutoRollTutorial is gone or going.
		local playerGui = h.player:WaitForChild("PlayerGui")
		waitUntil(function()
			return playerGui:FindFirstChild("AutoRollTutorial") == nil
		end)
		standIn = Instance.new("ScreenGui")
		standIn.Name = "AutoRollTutorial"
		standIn.Enabled = true
		standIn.Parent = playerGui
		setup(res, "sidekick_tutorial:rebirth:" .. Config.UnlockRebirth)
		check(res, "waits_for_auto_roll_tutorial", staysHidden(), true)
		standIn:Destroy()
		standIn = nil
		check(res, "shows_after_waiting", waitUntil(stepOne, PROMPT), true)
	end

	-- A normal track run never holds it back.
	local function checkShowsDuringRun(res)
		setup(res, "sidekick_tutorial:block:boss")
		waitUntil(function()
			return not showing()
		end)
		setup(res, "sidekick_tutorial:block:run")
		check(res, "shows_during_track_run", waitUntil(stepOne, RUN_WAIT), true)
		task.wait(1)
		check(res, "stays_during_track_run", stepOne(), true)
		setup(res, "sidekick_tutorial:block:off")
	end

	local function checkReduced(res)
		setup(res, "sidekick_tutorial:block:boss")
		waitUntil(function()
			return not showing()
		end)
		local saved = h.player:GetAttribute("ReduceEffects")
		h.player:SetAttribute("ReduceEffects", true)
		setup(res, "sidekick_tutorial:block:off")
		check(res, "reduced_shows", waitUntil(stepOne, PROMPT), true)
		task.wait(0.1)
		check(res, "reduced_spotlight_lands_at_once", ringAround(GO), true)
		check(res, "reduced_no_ripple", shown(RIPPLE), false)
		local arrow = h.find(ARROW)
		local at = arrow and h.rect(arrow).y
		local still = arrow ~= nil
		local stop = os.clock() + 0.6
		while os.clock() < stop and arrow do
			still = still and math.abs(h.rect(arrow).y - at) <= 0.5
			task.wait(0.05)
		end
		check(res, "reduced_arrow_still", still, true)
		h.player:SetAttribute("ReduceEffects", saved)
	end

	local function checkStepOne(res)
		check(res, "step1_shows", waitUntil(stepOne), true)
		check(res, "step1_names_vendor", has("sidekick"), true)
		check(
			res,
			"step1_spotlight_on_go",
			waitUntil(function()
				return ringAround(GO)
			end),
			true
		)
		check(res, "step1_free_not_offered_yet", stepTwo(), false)
		check(res, "step1_galaxy_open_button_unused", shown(REOPEN), false)
		checkTopmost(res, "step1_go", GO)
		checkFit(res, "step1", GO, true)
	end

	local function checkStepTwo(res)
		PanelSwitch.Action("Sidekicks")
		check(
			res,
			"step2_page_open",
			waitUntil(function()
				return PanelSwitch.IsOpen("Sidekicks")
			end),
			true
		)
		check(res, "step2_shows", waitUntil(stepTwo), true)
		check(
			res,
			"step2_spotlight_on_free",
			waitUntil(function()
				return ringAround(FREE)
			end),
			true
		)
		local free = h.find(FREE)
		check(
			res,
			"step2_free_says_free",
			free ~= nil and string.find(string.lower(free.Text), "free", 1, true) ~= nil,
			true
		)
		check(res, "step2_go_hidden", shown(GO), false)
		checkTopmost(res, "step2_free", FREE)
		checkFit(res, "step2", FREE, false)
	end

	local function checkResume(res)
		PanelSwitch.Close("Sidekicks")
		check(res, "resume_goes_back_to_step1", waitUntil(stepOne), true)
		-- A boss event starting mid tutorial hides it, and it comes back where the player is.
		setup(res, "sidekick_tutorial:block:boss")
		check(
			res,
			"boss_mid_tutorial_hides",
			waitUntil(function()
				return not showing()
			end),
			true
		)
		setup(res, "sidekick_tutorial:block:off")
		check(res, "boss_over_shows_again", waitUntil(stepOne, PROMPT), true)
	end

	local function checkStepThree(res)
		local remote = ReplicatedStorage:FindFirstChild("Remotes")
			and ReplicatedStorage.Remotes:FindFirstChild("SidekickFreeSummon")
		check(res, "free_remote_present", remote ~= nil, true)
		if not remote then
			return false
		end
		local ok = remote:InvokeServer()
		check(res, "free_remote_grants", ok, true)
		check(
			res,
			"free_used_attribute",
			waitUntil(function()
				return h.player:GetAttribute("SidekickFreeUsed") == true
			end),
			true
		)
		local opened = os.clock()
		check(
			res,
			"step3_tells_equip",
			waitUntil(function()
				return showing() and has("equip")
			end),
			true
		)
		check(res, "step3_tells_boss_events", has("boss"), true)
		check(res, "step3_go_hidden", shown(GO), false)
		check(res, "free_button_hidden_after_use", shown(FREE), false)
		local again = remote:InvokeServer()
		check(res, "free_summon_only_once", again == true, false)
		-- To equip in the Bag: the tutorial closes the summon screen itself, the HUD shows, and the ring is on its Items tile.
		check(
			res,
			"step3_closes_summon_screen",
			waitUntil(function()
				return not PanelSwitch.IsOpen("Sidekicks")
			end),
			true
		)
		check(
			res,
			"step3_points_at_items",
			waitUntil(function()
				local items = h.find(ITEMS)
				return showing() and items ~= nil and h.visible(items) and ringAround(ITEMS)
			end, 3),
			true
		)
		check(
			res,
			"step3_closes_itself",
			waitUntil(function()
				return not showing()
			end, STEP3_MAX),
			true
		)
		check(res, "step3_readable", os.clock() - opened >= STEP3_MIN, true)
		return true
	end

	local function checkCleanedUp(res)
		local gui = h.find(GUI)
		check(res, "cleanup_gui_stays_disabled", gui ~= nil and gui.Enabled == false, true)
		check(res, "cleanup_saved_flag", h.player:GetAttribute("SidekickFreeUsed"), true)
		local size = workspace.CurrentCamera.ViewportSize
		local top = h.topAt(size.X / 2, size.Y / 2)
		check(res, "cleanup_no_click_catcher", top ~= nil and gui ~= nil and top:IsDescendantOf(gui), false)
		PanelSwitch.Close("Sidekicks")
		check(res, "never_again_after_free", staysHidden(), true)
		PanelSwitch.Action("Sidekicks")
		task.wait(0.2)
		check(res, "never_again_page_open", showing(), false)
		check(res, "never_again_go", shown(GO), false)
		check(res, "never_again_free_button", shown(FREE), false)
		PanelSwitch.Close("Sidekicks")
	end

	function scenarios.ui_sidekick_tutorial(res)
		h.waitGuis()
		local gui = h.find(GUI)
		check(res, "gui_present", gui ~= nil and gui:IsA("ScreenGui"), true)
		if not gui then
			return
		end
		local savedReduced = h.player:GetAttribute("ReduceEffects")
		local ok, err = xpcall(function()
			checkWaits(res)
			checkShowsDuringRun(res)
			checkReduced(res)
			checkStepOne(res)
			checkStepTwo(res)
			checkResume(res)
			PanelSwitch.Action("Sidekicks")
			waitUntil(stepTwo)
			if checkStepThree(res) then
				checkCleanedUp(res)
			end
		end, debug.traceback)
		check(res, "completed", ok and true or tostring(err), true)
		h.player:SetAttribute("ReduceEffects", savedReduced)
		PanelSwitch.Close("Sidekicks")
		if standIn then
			standIn:Destroy() -- only when a failure skipped it
		end
		setup(res, "restore:sidekick_tutorial")
	end

	-- After the real tap on GoButton (step 1): the screen and step 2.
	function after.sidekick_tutorial_go(res)
		check(res, "click_go_opens_step2", waitUntil(stepTwo), true)
	end
	-- After the real tap on the free-summon button (step 2): the summon landed, and its reveal plays with the tutorial waiting.
	function after.sidekick_tutorial_free(res)
		check(
			res,
			"click_free_used",
			waitUntil(function()
				return h.player:GetAttribute("SidekickFreeUsed") == true
			end),
			true
		)
		check(
			res,
			"result_reveal_plays",
			waitUntil(function()
				return h.find(REVEAL) ~= nil
			end),
			true
		)
		check(res, "result_tutorial_waits", staysHidden(), true)
		local size = workspace.CurrentCamera.ViewportSize
		local top = h.topAt(size.X / 2, size.Y / 2)
		local reveal = h.find(REVEAL)
		check(res, "result_reveal_keeps_click", top ~= nil and reveal ~= nil and top:IsDescendantOf(reveal), true)
	end
	-- After the real tap that ends the reveal: the tutorial closes the summon screen, points at Items to equip, and closes.
	function after.sidekick_tutorial_equip(res)
		check(
			res,
			"equip_reveal_gone",
			waitUntil(function()
				return h.find(REVEAL) == nil
			end),
			true
		)
		check(
			res,
			"equip_closes_summon_screen",
			waitUntil(function()
				return not PanelSwitch.IsOpen("Sidekicks")
			end),
			true
		)
		check(
			res,
			"equip_step_after_result",
			waitUntil(function()
				return showing() and has("equip")
			end),
			true
		)
		check(res, "equip_tells_boss_events", has("boss"), true)
		check(
			res,
			"equip_points_at_items",
			waitUntil(function()
				local items = h.find(ITEMS)
				return items ~= nil and h.visible(items) and ringAround(ITEMS)
			end),
			true
		)
		check(
			res,
			"equip_closes_itself",
			waitUntil(function()
				return not showing()
			end, STEP3_MAX),
			true
		)
	end

	return { Scenarios = scenarios, After = after }
end

return Module
