--!nonstrict
-- The paid spawn's buttons and its Details (docs/BOSS_EVENT_SPEC.md "Paid spawn", task b9). Owned by ui-test-writer. ui_boss_paid drives
-- the published attributes through UiTestSetup boss_ui_*, as ui_boss does; the real presses are the boss_paid_* clicks in UiSpec.Clicks.
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   RacerBossEvent/BossButton. Read at each render, from player attributes and MonetizationConfig.BossSpawn.ProductId:
--     in an event: as ui_boss, Text exactly "Boss (Active)". Otherwise, with BossCredit >= 1: Text exactly "Boss ready", Active; a
--     press invokes BossUseCredit. Otherwise, no Sidekick: shown, Active false. Otherwise, ProductId 0: Text has "Coming soon",
--     Active false, a press fires nothing. Otherwise: Text has "Boss" and the price 149, Active; a press invokes BossBuy.
--   Player attribute PaidRandomRestricted (ShopService publishes it): a press does not invoke BossBuy and BossPrompt shows an
--     error, whatever the ProductId. A refused BossBuy shows its message in BossPrompt too.
--   RacerBossEvent/BossDetails, a button directly in the ScreenGui, shown with BossButton outside an event, with no purchase needed.
--   Its press toggles RacerBossEvent/BossDetailsPanel, hidden until then. Directly in it: one TextLabel Row_<id> per
--   RelicConfig.Odds("big_raga"), Text holding that row's percent, and Row_side_raga, Text "Big Raga 0.001%", black.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared:WaitForChild("MonetizationConfig"))
local RelicConfig = require(Shared:WaitForChild("RelicConfig"))

local ROOT = "RacerBossEvent"
local BUTTON = ROOT .. "/BossButton"
local DETAILS = ROOT .. "/BossDetails"
local PANEL = ROOT .. "/BossDetailsPanel"
local PROMPT = ROOT .. "/BossPrompt"
local SHOW_WAIT = 2 -- s: an attribute change has replicated and the UI has followed
local FAKE_PRODUCT = 990139901 -- client copy of the config only; nothing is ever prompted

local Module = {}

function Module.Build(h)
	local scenarios, after = {}, {}

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
	local function has(needle)
		return function()
			return string.find(text(), needle, 1, true) ~= nil
		end
	end
	local function active()
		local button = h.find(BUTTON)
		return button ~= nil and button.Active
	end
	local function checkState(res, tag, wantText, wantActive)
		h.check(
			res,
			tag .. "_shown",
			waitIs(function()
				return shown(BUTTON)
			end, true),
			true
		)
		h.check(res, tag .. "_text", waitIs(has(wantText), true) and wantText or text(), wantText)
		if wantActive ~= nil then
			h.check(res, tag .. "_active", waitIs(active, wantActive), wantActive)
		end
	end

	function scenarios.ui_boss_paid(res)
		h.waitGuis()
		for _, path in { BUTTON, DETAILS, PANEL } do
			h.check(res, "paid_part_present_" .. path, h.find(path) ~= nil, true)
		end
		local spawnProduct = Monetization.BossSpawn
		h.check(res, "paid_config", spawnProduct ~= nil, true)
		if not spawnProduct then
			return
		end
		local realId = spawnProduct.ProductId
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:1")
			setup(res, "boss_ui_state:Idle:0:0:0:false:0")
			checkState(res, "coming_soon", "Coming soon", false)
			h.check(
				res,
				"idle_details_shown",
				waitIs(function()
					return shown(DETAILS)
				end, true),
				true
			)
			h.check(res, "details_hidden_until_pressed", shown(PANEL), false)

			spawnProduct.ProductId = FAKE_PRODUCT
			checkState(res, "able", "Boss", true)
			checkState(res, "able_price", tostring(spawnProduct.Robux), true)

			setup(res, "boss_ui_credit:1")
			checkState(res, "credit", "Boss ready", true)
			h.check(res, "credit_text_exact", waitIs(text, "Boss ready"), "Boss ready")

			setup(res, "boss_ui_state:Prep:5:4000:4000:false:0")
			checkState(res, "credit_in_event", "Boss (Active)")
			h.check(res, "event_text_exact", waitIs(text, "Boss (Active)"), "Boss (Active)")
			setup(res, "boss_ui_state:Idle:0:0:0:false:0")
			checkState(res, "credit_after_event", "Boss ready", true)

			setup(res, "boss_ui_credit:0")
			setup(res, "boss_ui_gear:0")
			h.check(
				res,
				"no_sidekick_shown",
				waitIs(function()
					return shown(BUTTON)
				end, true),
				true
			)
			h.check(res, "no_sidekick_disabled", waitIs(active, false), false)
		end, debug.traceback)
		h.check(res, "paid_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		spawnProduct.ProductId = realId
		setup(res, "restore:boss_ui")
	end

	-- After the real presses (UiSpec.Clicks boss_paid_*).
	function after.boss_paid_details_open(res)
		h.check(
			res,
			"details_opens",
			waitIs(function()
				return shown(PANEL)
			end, true),
			true
		)
		local panel = h.find(PANEL)
		local sum = 0
		for _, row in RelicConfig.Odds("big_raga") do
			local label = panel and panel:FindFirstChild("Row_" .. row.Id)
			local percent = label and tonumber(string.match(label.Text, "([%d%.]+)%%"))
			h.check(res, "details_odds_" .. row.Id, percent, row.Odds, percent == row.Odds)
			sum += percent or 0
		end
		h.check(res, "details_sum_100", sum, 100, math.abs(sum - 100) < 1e-6)
		local side = panel and panel:FindFirstChild("Row_side_raga")
		h.check(res, "details_raga_text", side and side.Text, "Big Raga 0.001%")
		h.check(res, "details_raga_black", side and side.TextColor3, Color3.new(0, 0, 0))
	end
	function after.boss_paid_error_shown(res)
		h.check(
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
