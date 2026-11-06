--!nonstrict
-- The paid spawn's buttons and its Details (docs/BOSS_EVENT_SPEC.md "Paid spawn", task b9). Owned by ui-test-writer. ui_boss_paid drives
-- the published attributes through UiTestSetup boss_ui_*, as ui_boss does; the real presses are the boss_paid_* clicks in UiSpec.Clicks.
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   RacerBossEvent/BossButton: Text exactly "Bosses", Active, in every state; a press only toggles RacerBossEvent/BossesPanel.
--   BossesPanel/BossAction, drawn only while the popup shows. In an event: as ui_boss. Otherwise, read at each render from player
--     attributes and MonetizationConfig.BossSpawn.ProductId: with BossCredit >= 1, "Spawn boss (ready)", a press invokes BossUseCredit.
--     Otherwise, ProductId 0: "Coming soon", Active false, a press fires nothing. Otherwise: "Spawn boss 149 R$", a press invokes
--     BossBuy. No Sidekick: Active false (with no credit).
--   Player attribute PaidRandomRestricted (ShopService publishes it): a press does not invoke BossBuy and BossPrompt shows an
--     error, whatever the ProductId. A refused BossBuy shows its message in BossPrompt too.
--   BossesPanel/BossDetails, a Frame, shown with DetailsHeading and NextEvent outside an event. Directly in it: one TextLabel Row_<id> per
--     RelicConfig.Odds("big_raga"), Text holding that row's percent, and Row_side_raga, Text "Big Raga 0.001%", black.
--   NextEvent: "Next event in m:ss", from ReplicatedStorage.BossEventNextAt.
--   BossesPanel is centred, with Header/CloseButton, and closes on a click outside it (owner 2026-11-06; boss_panel_* clicks).
--   A popup only a real press opens can not be judged by the scenario: its states are the boss_paid_* clicks (UiSpec.Clicks).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared:WaitForChild("MonetizationConfig"))
local RelicConfig = require(Shared:WaitForChild("RelicConfig"))

local ROOT = "RacerBossEvent"
local BUTTON = ROOT .. "/BossButton"
local PANEL = ROOT .. "/BossesPanel"
local DETAILS = PANEL .. "/BossDetails"
local ACTION = PANEL .. "/BossAction"
local PROMPT = PANEL .. "/BossPrompt"
local NEXT_EVENT = PANEL .. "/NextEvent"
local BUTTON_TEXT = "Bosses"
local NEXT_SLACK = 5 -- s
local SHOW_WAIT = 2 -- s: an attribute change has replicated and the UI has followed

local Module = {}

function Module.Build(h)
	local scenarios, after = {}, {}

	-- h.check takes the verdict as its fifth argument; without it every check fails.
	local function check(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local function waitIs(fn, want)
		local deadline = os.clock() + SHOW_WAIT
		local value = fn()
		while value ~= want and os.clock() < deadline do
			task.wait(0.05)
			value = fn()
		end
		return value
	end
	local function setup(res, request)
		local ok, err = h.requestSetup(request)
		if not ok then
			h.check(res, "setup_" .. request, tostring(err), "ok", false)
		end
	end
	local function shown(path)
		local gui = h.find(path)
		return gui ~= nil and h.visible(gui)
	end
	local function text()
		local button = h.find(BUTTON)
		return button and button.Text or ""
	end
	local function active()
		local button = h.find(BUTTON)
		return button ~= nil and button.Active
	end
	local function checkState(res, tag)
		check(
			res,
			tag .. "_shown",
			waitIs(function()
				return shown(BUTTON)
			end, true),
			true
		)
		check(res, tag .. "_text", waitIs(text, BUTTON_TEXT), BUTTON_TEXT)
		check(res, tag .. "_active", waitIs(active, true), true)
	end

	function scenarios.ui_boss_paid(res)
		h.waitGuis()
		for _, path in
			{ BUTTON, PANEL, DETAILS, ACTION, PROMPT, NEXT_EVENT, PANEL .. "/Status", PANEL .. "/DetailsHeading" }
		do
			check(res, "paid_part_present_" .. path, h.find(path) ~= nil, true)
		end
		for _, gone in { "BossDetails", "BossDetailsPanel", "BossPrompt" } do
			check(res, "paid_part_moved_" .. gone, h.find(ROOT .. "/" .. gone), nil)
		end
		local details = h.find(DETAILS)
		check(res, "paid_details_is_a_frame", details ~= nil and details.ClassName, "Frame")
		local spawnProduct = Monetization.BossSpawn
		check(res, "paid_config", spawnProduct ~= nil, true)
		if not spawnProduct then
			return
		end
		local realId = spawnProduct.ProductId
		local ok, err = xpcall(function()
			-- Client copy of the config only, put back below on every path: nothing is prompted.
			spawnProduct.ProductId = 0
			setup(res, "boss_ui_gear:1")
			setup(res, "boss_ui_state:Idle:0:0:0:false:0")
			checkState(res, "coming_soon")
			check(res, "panel_hidden_until_pressed", shown(PANEL), false)

			spawnProduct.ProductId = realId
			checkState(res, "able")

			setup(res, "boss_ui_credit:1")
			checkState(res, "credit")

			setup(res, "boss_ui_state:Prep:5:5000:5000:false:0")
			checkState(res, "credit_in_event")
			setup(res, "boss_ui_state:Idle:0:0:0:false:0")
			checkState(res, "credit_after_event")

			setup(res, "boss_ui_credit:0")
			setup(res, "boss_ui_gear:0")
			checkState(res, "no_sidekick") -- it still opens the popup: BossAction is what a no-Sidekick player can not press
		end, debug.traceback)
		h.check(res, "paid_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		spawnProduct.ProductId = realId
		setup(res, "restore:boss_ui")
	end

	-- After the real presses (UiSpec.Clicks boss_paid_*).
	function after.boss_paid_details_open(res)
		check(
			res,
			"details_opens",
			waitIs(function()
				return shown(PANEL)
			end, true),
			true
		)
		check(res, "details_heading_shown", shown(PANEL .. "/DetailsHeading"), true)
		check(res, "details_shown", shown(DETAILS), true)
		local action = h.find(ACTION)
		check(res, "idle_action_text", action and action.Text, "Spawn boss 149 R$")
		local status = h.find(PANEL .. "/Status")
		check(
			res,
			"idle_status_is_about",
			status ~= nil and status.Text ~= "" and status.Text ~= "Big Raga is raging right now",
			true
		)
		local nextAt = ReplicatedStorage:GetAttribute("BossEventNextAt")
		check(res, "next_at_published", type(nextAt), "number")
		local nextLabel = h.find(NEXT_EVENT)
		local minutes, seconds = string.match(nextLabel and nextLabel.Text or "", "^Next event in (%d+):(%d%d)$")
		local left = minutes and tonumber(minutes) * 60 + tonumber(seconds)
		local want = type(nextAt) == "number" and nextAt - workspace:GetServerTimeNow() or 0
		h.check(
			res,
			"next_event_text",
			left or (nextLabel and nextLabel.Text),
			("%d +- %d"):format(want, NEXT_SLACK),
			left ~= nil and math.abs(left - want) <= NEXT_SLACK
		)
		local panel = h.find(DETAILS)
		local sum = 0
		for _, row in RelicConfig.Odds("big_raga") do
			local label = panel and panel:FindFirstChild("Row_" .. row.Id)
			local percent = label and tonumber(string.match(label.Text, "([%d%.]+)%%"))
			h.check(res, "details_odds_" .. row.Id, percent, row.Odds, percent == row.Odds)
			sum += percent or 0
		end
		h.check(res, "details_sum_100", sum, 100, math.abs(sum - 100) < 1e-6)
		local side = panel and panel:FindFirstChild("Row_side_raga")
		check(res, "details_raga_text", side and side.Text, "Big Raga 0.001%")
		check(res, "details_raga_black", side and side.TextColor3, Color3.new(0, 0, 0))
	end
	function after.boss_paid_refusal_shown(res)
		check(
			res,
			"refused_buy_message_shown",
			waitIs(function()
				local prompt = h.find(PROMPT)
				return shown(PROMPT) and prompt.Text == "money"
			end, true),
			true
		)
	end
	function after.boss_paid_error_shown(res)
		check(
			res,
			"restricted_error_shown",
			waitIs(function()
				local prompt = h.find(PROMPT)
				return shown(PROMPT) and prompt.Text ~= ""
			end, true),
			true
		)
	end

	return { Scenarios = scenarios, After = after }
end

return Module
