--!nonstrict
-- ui_boss_guide: Client/BossGuideUi (docs/BOSS_GUIDE_SPEC.md). The conversation opens through Workspace.BossGuide's prompt
-- (BossGuideUi's Open bindable stands in for the press), pages with Next, closes with its X and on Done, gives way to any
-- other panel, and changes no player attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("BossGuideConfig"))

local OPEN_WAIT, CLOSE_WAIT = 1, 0.6 -- s: the unroll and the roll-up have finished

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
		local model = workspace:WaitForChild("BossGuide", Config.LIVE and 10 or 0.1)
		local prompt = model and model:FindFirstChild("TalkBossGuide", true)
		ok(res, "prompt_follows_live", (prompt ~= nil) == Config.LIVE)
		if not panel then
			return
		end
		local before = player:GetAttributes()
		ok(res, "starts_closed", not panel.Visible)
		local open = gui:FindFirstChild("Open")
		open:Fire()
		task.wait(OPEN_WAIT)
		ok(res, "opens", PanelSwitch.IsOpen("BossGuide"))
		open:Fire() -- a second press keeps the one conversation, on its page
		task.wait(0.1)
		ok(res, "second_press_keeps_it", PanelSwitch.IsOpen("BossGuide"))
		local pages = Config.Pages(
			ReplicatedStorage:GetAttribute("BossEventPhase") ~= nil,
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
		player:SetAttribute("BossEvent", before.BossEvent)

		local changed = {}
		for _, name in { "Money", "Gems", "Rolls", "RebirthLevel", "BossCredit", "BossTeam", "SidekickBag", "Relics" } do
			if player:GetAttribute(name) ~= before[name] then
				table.insert(changed, name)
			end
		end
		h.check(res, "grants_nothing", table.concat(changed, ","), "", #changed == 0)
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
