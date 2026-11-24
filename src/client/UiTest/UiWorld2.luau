--!nonstrict
-- World awareness (docs/WORLD2_SPEC.md "World HUD" and "Welcome", design doc 4.47). Runs in either place; the
-- current viewport only (phones: run it again under the Device Simulator).
-- ui_world_label: Client/WorldHud's WorldHud/WorldLabel reads "World <WorldConfig.Id>", shows on screen, sits under
--   HudChrome/TopRight and over HudChrome/ShopColumn without touching either; Travelling (set here, locally) shows
--   TeamToast's "Travelling to World <other>...".
-- ui_world2_welcome (World 1: no World2Welcome gui at all): Client/World2Welcome opens on World2WelcomeShow with the
--   world name, "Team of 4 unlocked", "New summon pool" and the gate hint, all inside the screen; clearing the attribute (what Close and OK do) closes it;
--   setting it again the same session does not reopen it. The attribute is set locally; the once-per-save rule is the
--   server's (ServerTest world2_welcome).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldConfig"))

local OPEN_WAIT = 1 -- s: the 0.45 s unroll (or the reduced fade) has finished
local CLOSE_WAIT = 0.6 -- s: the 0.25 s roll-up has finished

local Module = {}

local function rect(gui)
	return gui.AbsolutePosition, gui.AbsolutePosition + gui.AbsoluteSize
end
local function apart(a, b) -- no overlap of the two rects
	local a0, a1 = rect(a)
	local b0, b1 = rect(b)
	return a1.X <= b0.X or b1.X <= a0.X or a1.Y <= b0.Y or b1.Y <= a0.Y
end
local function inside(gui, screen)
	-- AbsolutePosition is in inset space: an IgnoreGuiInset ScreenGui starts at y = -inset, so judge from its origin
	local root = gui:FindFirstAncestorWhichIsA("LayerCollector")
	local origin = root and root.AbsolutePosition or Vector2.zero
	local p0, p1 = rect(gui)
	p0, p1 = p0 - origin, p1 - origin
	return p0.X >= 0 and p0.Y >= 0 and p1.X <= screen.X + 0.5 and p1.Y <= screen.Y + 0.5
end

function Module.Build(h)
	local scenarios = {}
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	function scenarios.ui_world_label(res)
		local gui = playerGui:WaitForChild("WorldHud", 10)
		local label = gui and gui:FindFirstChild("WorldLabel")
		local hud = playerGui:FindFirstChild("HudChrome")
		local bar, column = hud and hud:FindFirstChild("TopRight"), hud and hud:FindFirstChild("ShopColumn")
		h.check(res, "label_exists", label ~= nil, true, label ~= nil)
		h.check(res, "hud_exists", bar ~= nil and column ~= nil, true, bar ~= nil and column ~= nil)
		if not (label and bar and column) then
			return
		end
		task.wait() -- one layout pass after any viewport change
		local want = "World " .. WorldConfig.Id
		h.check(res, "label_text", label.Text, want, label.Text == want)
		h.check(res, "label_shown", label.Visible and gui.Enabled, true, label.Visible and gui.Enabled)
		h.check(res, "label_fits_text", label.TextFits, true, label.TextFits)
		h.check(res, "label_on_screen", inside(label, gui.AbsoluteSize), true, inside(label, gui.AbsoluteSize))
		h.check(res, "label_clear_of_pills", apart(label, bar), true, apart(label, bar))
		local below = label.AbsolutePosition.Y >= bar.AbsolutePosition.Y + bar.AbsoluteSize.Y
		h.check(res, "label_under_pills", below, true, below)
		h.check(res, "label_clear_of_right_column", apart(label, column), true, apart(label, column))
		local map = playerGui:FindFirstChild("RaceProgressMap", true)
		if map and map:IsA("GuiObject") and map.Visible then
			h.check(res, "label_clear_of_race_map", apart(label, map), true, apart(label, map))
		end

		-- Travel toast (TeamToast/Toast), driven by the Travelling attribute the server sets in WorldTravel.Go.
		local toast = playerGui:FindFirstChild("TeamToast") and playerGui.TeamToast:FindFirstChild("Toast")
		h.check(res, "toast_exists", toast ~= nil, true, toast ~= nil)
		if toast then
			local before = player:GetAttribute("Travelling")
			player:SetAttribute("Travelling", true)
			task.wait(0.1)
			local trip = "Travelling to World " .. (3 - WorldConfig.Id) .. "..."
			h.check(res, "travel_toast_text", toast.Text, trip, toast.Text == trip)
			h.check(res, "travel_toast_shown", toast.Visible, true, toast.Visible)
			player:SetAttribute("Travelling", before)
		end
	end

	function scenarios.ui_world2_welcome(res)
		if WorldConfig.Id ~= 2 then -- World 1: Client/World2Welcome builds nothing
			local none = playerGui:WaitForChild("World2Welcome", 2) == nil
			h.check(res, "welcome_absent_in_world1", none, true, none)
			return
		end
		local gui = playerGui:WaitForChild("World2Welcome", 10)
		local panel = gui and gui:FindFirstChild("Panel")
		h.check(res, "welcome_exists", panel ~= nil, true, panel ~= nil)
		if not panel then
			return
		end
		local before = player:GetAttribute("World2WelcomeShow")
		local done = gui:GetAttribute("Done")
		player:SetAttribute("World2WelcomeShow", nil)
		task.wait(CLOSE_WAIT)
		gui:SetAttribute("Done", nil) -- test seam: shows again even after the real welcome this session
		player:SetAttribute("World2WelcomeShow", true)
		task.wait(OPEN_WAIT)
		local shown = gui.Enabled and panel.Visible
		h.check(res, "welcome_opens", shown, true, shown)
		local screen = gui.AbsoluteSize
		h.check(res, "welcome_on_screen", inside(panel, screen), true, inside(panel, screen))
		local title = panel:FindFirstChild("Title", true)
		local titleOk = title and string.upper(title.Text) == "WORLD 2"
		h.check(res, "welcome_world_name", title and title.Text, "WORLD 2", titleOk == true)
		for _, want in { "Team of 4 unlocked", "New summon pool" } do
			local found = false
			for _, d in panel:GetDescendants() do
				if d:IsA("TextLabel") and d.Text == want and d.Visible then
					found = d.TextFits and inside(d, screen)
				end
			end
			h.check(res, "welcome_line_" .. want, found, true, found)
		end
		local hint = panel:FindFirstChild("Hint", true)
		local hintOk = hint ~= nil and string.find(hint.Text, "World 1", 1, true) ~= nil and hint.TextFits
		h.check(res, "welcome_return_hint", hint and hint.Text, "mentions World 1", hintOk)
		local okButton = panel:FindFirstChild("OK", true)
		h.check(res, "welcome_dismiss_button", okButton ~= nil and okButton.Visible, true, okButton ~= nil)

		player:SetAttribute("World2WelcomeShow", nil) -- what Close and OK do
		task.wait(CLOSE_WAIT)
		local closed = not panel.Visible and not gui.Enabled
		h.check(res, "welcome_closes", closed, true, closed)
		player:SetAttribute("World2WelcomeShow", true)
		task.wait(OPEN_WAIT)
		h.check(res, "welcome_shown_once", not panel.Visible, true, not panel.Visible)

		player:SetAttribute("World2WelcomeShow", nil)
		task.wait(CLOSE_WAIT)
		gui:SetAttribute("Done", done)
		player:SetAttribute("World2WelcomeShow", before)
	end

	-- After the real press of Panel/CloseButton or Panel/OK (UiSpec.Clicks world2_welcome_close / world2_welcome_ok).
	local after = {}
	function after.world2_welcome_closed(res)
		local gui = playerGui:FindFirstChild("World2Welcome")
		local panel = gui and gui:FindFirstChild("Panel")
		task.wait(CLOSE_WAIT)
		local closed = panel ~= nil and not panel.Visible and not gui.Enabled
		h.check(res, "welcome_press_closes", closed, true, closed)
		local cleared = player:GetAttribute("World2WelcomeShow") == nil
		h.check(res, "welcome_press_clears_show", cleared, true, cleared)
	end

	return { Scenarios = scenarios, After = after }
end

return Module
