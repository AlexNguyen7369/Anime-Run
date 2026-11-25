--!nonstrict
-- ui_boss_guide: Client/BossGuideUi (docs/BOSS_GUIDE_SPEC.md). The conversation opens through Workspace.BossGuide's prompt
-- (BossGuideUi's Open bindable stands in for the press), pages with Next, closes with its X and on Done, gives way to any
-- other panel, and changes no player attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("BossGuideConfig"))
local Gate = require(Shared:WaitForChild("BossGateConfig"))

local OPEN_WAIT, CLOSE_WAIT = 1, 0.6 -- s: the unroll and the roll-up have finished

local QUIET = 5 -- s without a change before the talk: longer than one auto-roll interval
local SETTLE = 20 -- s at most for that (a run's last payout, a roll already going)
local WATCHED = { "Money", "Gems", "Rolls", "RebirthLevel", "BossCredit", "BossTeam", "SidekickBag", "Relics" }

local Module = {}

function Module.Build(h)
	local scenarios, after = {}, {}
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local PanelSwitch = require(player.PlayerScripts.Client.PanelSwitch)
	local function parts()
		local gui = playerGui:FindFirstChild("BossGuideUi")
		return gui, gui and gui:FindFirstChild("Panel")
	end
	local function ok(res, name, value)
		h.check(res, name, value, true, value == true)
	end

	function scenarios.ui_boss_guide(res)
		local gui, panel = parts()
		ok(res, "gui_exists", panel ~= nil)
		local model = workspace:WaitForChild("BossGuide", Config.IsLive() and 10 or 0.1)
		local prompt = model and model:FindFirstChild("TalkBossGuide", true)
		ok(res, "prompt_follows_live", (prompt ~= nil) == Config.IsLive())
		if not panel then
			return
		end
		-- Server setup `quiet` (UiScenarios.Needs): what changes during the talk is then the talk's. Proved first, without it.
		local replicated = os.clock() + 2 -- the setup's attributes may arrive after its answer
		while
			(player:GetAttribute("AutoRoll") ~= false or player:GetAttribute("AutoRacing") == true)
			and os.clock() < replicated
		do
			task.wait(0.1)
		end
		ok(res, "quiet_auto_roll_off", player:GetAttribute("AutoRoll") == false)
		ok(res, "quiet_not_racing", player:GetAttribute("AutoRacing") ~= true)
		local function watched()
			local values = {}
			for _, name in WATCHED do
				values[name] = player:GetAttribute(name)
			end
			return values
		end
		local function differences(from)
			local changed = {}
			for _, name in WATCHED do
				if player:GetAttribute(name) ~= from[name] then
					table.insert(changed, name)
				end
			end
			return table.concat(changed, ",")
		end
		local started, since, base, noise = os.clock(), os.clock(), watched(), ""
		while os.clock() - since < QUIET and os.clock() - started < SETTLE do
			task.wait(0.1)
			local changed = differences(base)
			if changed ~= "" then
				noise, base, since = changed, watched(), os.clock()
			end
		end
		h.check(res, "quiet_without_the_talk", noise, "quiet for " .. QUIET .. " s", os.clock() - since >= QUIET)
		local before = watched()
		local wasInEvent = player:GetAttribute("BossEvent")
		ok(res, "starts_closed", not panel.Visible)
		local open = gui:FindFirstChild("Open")
		open:Fire()
		task.wait(OPEN_WAIT)
		ok(res, "opens", PanelSwitch.IsOpen("BossGuide"))
		open:Fire() -- a second press keeps the one conversation, on its page
		task.wait(0.1)
		ok(res, "second_press_keeps_it", PanelSwitch.IsOpen("BossGuide"))
		local pages = Config.Pages(
			ReplicatedStorage:GetAttribute(Gate.OPEN_ATTRIBUTE) == true,
			player:GetAttribute("RebirthLevel") or 0
		)
		local line, nextButton = panel:FindFirstChild("Line", true), panel:FindFirstChild("Next", true)
		for i, page in pages do
			h.check(res, "page_" .. page.Id, line.Text, page.Text, line.Text == page.Text)
			ok(res, "page_fits_" .. page.Id, line.TextFits)
			if i < #pages then
				gui.Advance:Fire()
				task.wait(0.05)
			end
		end
		h.check(res, "last_button", nextButton.Text, "Done", nextButton.Text == "Done")
		gui.Advance:Fire()
		task.wait(CLOSE_WAIT)
		ok(res, "done_closes", not panel.Visible)

		open:Fire()
		task.wait(OPEN_WAIT)
		h.check(res, "reopens_on_first_page", line.Text, pages[1].Text, line.Text == pages[1].Text)
		PanelSwitch.Toggle("Checkpoints")
		task.wait(OPEN_WAIT)
		ok(res, "one_at_a_time", not panel.Visible and PanelSwitch.IsOpen("Checkpoints"))
		PanelSwitch.Close("Checkpoints")
		task.wait(CLOSE_WAIT)

		open:Fire()
		task.wait(OPEN_WAIT)
		player:SetAttribute("BossEvent", true) -- local only: a teleport into the event closes it
		task.wait(CLOSE_WAIT)
		ok(res, "event_closes", not panel.Visible)
		player:SetAttribute("BossEvent", wasInEvent)

		local changed = differences(before)
		h.check(res, "grants_nothing", changed, "", changed == "")
	end

	function after.boss_guide_closed(res)
		local _, panel = parts()
		task.wait(CLOSE_WAIT)
		ok(res, "guide_press_closes", panel ~= nil and not panel.Visible)
	end
	function after.boss_guide_advanced(res)
		local _, panel = parts()
		local line = panel and panel:FindFirstChild("Line", true)
		local want = Config.Pages(false, 0)[2].Text
		h.check(res, "guide_next_page", line and line.Text, want, line ~= nil and line.Text == want)
	end

	return { Scenarios = scenarios, After = after }
end

return Module
