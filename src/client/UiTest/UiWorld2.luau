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
-- ui_hud_look_by_world (design doc 4.46 "HUD look" and 4.40, owner 2026-11-24, both worlds): the always-on HUD
--   has its look from before the Scroll Dojo redesign, no option A dressing (Client/HudPlaque.Old): no "Plaque" frame,
--   no tilted vermilion Key seal, no kit fonts, no Money / Gems lacquer plate (gradient game-font numbers, blue Gems),
--   the generated Turbo bar, dark team circles with the team ring. The panels keep the Scroll Dojo frame (a
--   DojoHandscroll "Handscroll" inside each).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldConfig"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local TEAM_SIZE = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StaminaConfig")).TEAM_SIZE

-- The old HUD's look (design doc 4.40; 4.46 "HUD look").
local WHITE = Color3.new(1, 1, 1)
local PILL = Color3.fromRGB(18, 18, 21) -- Client/HudChrome PILL_COLOR, at BackgroundTransparency 0.12
local GEM_TOP, GEM_BOTTOM = Color3.fromRGB(150, 235, 255), Color3.fromRGB(50, 130, 255) -- the blue Gems gradient

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

	function scenarios.ui_hud_look_by_world(res)
		local function same(c, want)
			return math.abs(c.R - want.R) + math.abs(c.G - want.G) + math.abs(c.B - want.B) < 0.01
		end
		local function list(name, wrong)
			h.check(res, name, #wrong == 0 and "none" or table.concat(wrong, "; "), "none", #wrong == 0)
		end
		-- No option A dressing anywhere on the column buttons, the pills or the second column.
		local plaques, seals, kit = {}, {}, {}
		for _, name in { "HudChrome", "RacerSecondColumn" } do
			local gui = playerGui:WaitForChild(name, 10)
			h.check(res, "gui_" .. name, gui ~= nil, true, gui ~= nil)
			for _, d in gui and gui:GetDescendants() or {} do
				if d.Name == "Plaque" and d:IsA("Frame") then
					table.insert(plaques, d:GetFullName())
				elseif d.Name == "Key" and d:IsA("TextLabel") then
					-- HudPlaque.Seal: a tilted vermilion square; the 4.40 letter stands straight on no background
					if d.Rotation ~= 0 or d.BackgroundTransparency < 1 or not same(d.TextColor3, WHITE) then
						table.insert(seals, d:GetFullName())
					end
				end
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d:GetAttribute("AnimeRole") == "Dojo" then
					table.insert(kit, d:GetFullName())
				end
			end
		end
		list("hud_plaques", plaques)
		list("hud_key_seals", seals)
		list("hud_kit_fonts", kit)
		-- Column buttons (Client/HudChrome, 4.40): a 72 px icon at the cell's top (before the holder's UIScale) and a
		-- white outlined game-font Label under it.
		local hud = playerGui:FindFirstChild("HudChrome")
		local columns = {}
		for _, path in
			{ "Grid/Index", "Grid/Items", "Grid/Rebirth", "ShopColumn/Quests", "ShopColumn/Shop", "ShopColumn/Summon" }
		do
			local holder, name = string.match(path, "^(.-)/(.+)$")
			local tile = hud and hud:FindFirstChild(holder) and hud[holder]:FindFirstChild(name)
			local icon, label = tile and tile:FindFirstChild("Icon"), tile and tile:FindFirstChild("Label")
			if not (icon and icon:IsA("ImageLabel") and label and label:IsA("TextLabel")) then
				table.insert(columns, path .. " Icon or Label missing")
			else
				local outline = label:FindFirstChildOfClass("UIStroke")
				if
					icon.Size ~= UDim2.fromOffset(72, 72)
					or icon.Position.Y.Offset ~= 0
					or icon.Position.Y.Scale ~= 0
				then
					table.insert(
						columns,
						("%s Icon %s at %s"):format(path, tostring(icon.Size), tostring(icon.Position))
					)
				end
				if label.Font ~= UiTheme.Font or not same(label.TextColor3, WHITE) then
					table.insert(columns, ("%s Label %s %s"):format(path, label.Font.Name, tostring(label.TextColor3)))
				end
				if not (outline and outline.Enabled and same(outline.Color, UiTheme.Outline)) then
					table.insert(columns, path .. " Label has no dark outline")
				end
			end
		end
		list("hud_column_buttons_old_look", columns)
		-- Top-right pills (4.40): dark round pills (Client/HudChrome PILL_COLOR, PILL_TRANSPARENCY), white captions (Daily and Market;
		-- Settings is its icon alone).
		local pills = {}
		for _, name in { "Daily", "Market", "Settings" } do
			local pill = hud and hud:FindFirstChild("TopRight") and hud.TopRight:FindFirstChild(name)
			local caption = pill and pill:FindFirstChild("Caption")
			if not pill then
				table.insert(pills, name .. " missing")
			elseif not same(pill.BackgroundColor3, PILL) or math.abs(pill.BackgroundTransparency - 0.12) > 0.01 then
				table.insert(
					pills,
					("%s %s %g"):format(name, tostring(pill.BackgroundColor3), pill.BackgroundTransparency)
				)
			elseif name == "Settings" then
				if caption then -- Client/HudChrome pill("Settings", 4): the icon only
					table.insert(pills, "Settings has a Caption")
				end
			elseif not (caption and caption:IsA("TextLabel")) then
				table.insert(pills, name .. " has no Caption TextLabel")
			elseif caption.Font ~= UiTheme.Font or not same(caption.TextColor3, WHITE) then
				table.insert(pills, ("%s Caption %s %s"):format(name, caption.Font.Name, tostring(caption.TextColor3)))
			end
		end
		list("hud_pills_old_look", pills)
		-- The world label takes its sibling pills' look (Client/WorldHud).
		local world = playerGui:FindFirstChild("WorldHud") and playerGui.WorldHud:FindFirstChild("WorldLabel")
		local worldOld = world ~= nil
			and same(world.BackgroundColor3, PILL)
			and math.abs(world.BackgroundTransparency - 0.12) <= 0.01
			and world.Font == UiTheme.Font
			and same(world.TextColor3, WHITE)
		h.check(res, "world_label_dark_pill", worldOld, true, worldOld)

		-- Money and Gems (Client/RollToast/RacerUiController): gradient game-font numbers on no plate, blue Gems.
		local racer = playerGui:WaitForChild("RacerHud", 10)
		local money = racer and racer:FindFirstChild("Money")
		local lacquer = {}
		for _, d in money and money:GetDescendants() or {} do
			if d.Name == "MoneyLacquer" or d.Name == "GemsLacquer" then
				table.insert(lacquer, d:GetFullName())
			end
		end
		h.check(res, "money_exists", money ~= nil, true, money ~= nil)
		list("money_lacquer", lacquer)
		local moneyValue = money and money:FindFirstChild("MoneyValue")
		local gemsValue = money and money:FindFirstChild("GemsValue", true)
		local fonts = moneyValue ~= nil
			and gemsValue ~= nil
			and moneyValue.Font == UiTheme.Font
			and gemsValue.Font == UiTheme.Font
		h.check(res, "money_gems_game_font", fonts, true, fonts)
		local gradient = gemsValue and gemsValue:FindFirstChildOfClass("UIGradient")
		local keys = gradient and gradient.Color.Keypoints
		local blue = keys ~= nil and same(keys[1].Value, GEM_TOP) and same(keys[#keys].Value, GEM_BOTTOM)
		h.check(res, "gems_gradient_blue", blue, true, blue)

		-- Turbo: the generated bar (Ui/RacerHud), not option A's wooden one (a Wood grain on the rim, a Vermilion fill
		-- gradient, a TileEdge shadow, a hidden Lift).
		local turbo = racer and racer:FindFirstChild("Turbo")
		local face, shadow = turbo and turbo:FindFirstChild("Face"), turbo and turbo:FindFirstChild("Shadow")
		local fill = face and face:FindFirstChild("TurboFill")
		local rim = face and face:FindFirstChildOfClass("UIStroke")
		local wooden = {}
		if not (face and shadow and fill and rim) then
			table.insert(wooden, "Turbo Face, Shadow, TurboFill or rim missing")
		else
			if rim:FindFirstChild("Wood") or rim.Thickness ~= 3 or not same(rim.Color, UiTheme.Outline) then
				table.insert(wooden, ("rim %s %g"):format(tostring(rim.Color), rim.Thickness))
			end
			if fill:FindFirstChild("Vermilion") then
				table.insert(wooden, "TurboFill has the Vermilion gradient")
			end
			if same(shadow.BackgroundColor3, UiTheme.Scroll.TileEdge) or shadow.BackgroundTransparency == 0 then
				table.insert(wooden, "Shadow is the solid wood edge")
			end
		end
		list("turbo_generated_bar", wooden)

		-- Team circles (Client/TeamHud): dark faces with the team ring, the bonus line on a dark see-through plate.
		local level = racer and racer:FindFirstChild("Level")
		local row = level and level:FindFirstChild("Team")
		local palette = UiTheme.Palette
		local function circles()
			local wrong = {}
			for n = 1, TEAM_SIZE do
				local slot = row and row:FindFirstChild("Slot" .. n)
				local ring = slot and slot:FindFirstChildOfClass("UIStroke")
				if not (slot and ring) then
					table.insert(wrong, "Slot" .. n .. " or its ring missing")
				elseif
					not (same(slot.BackgroundColor3, palette.TeamDim) or same(slot.BackgroundColor3, palette.TeamTired))
				then
					table.insert(wrong, ("Slot%d face %s"):format(n, tostring(slot.BackgroundColor3)))
				elseif
					not (
						same(ring.Color, palette.TeamRing)
						or same(ring.Color, palette.Gold)
						or same(ring.Color, palette.TeamGrey)
					)
				then
					table.insert(wrong, ("Slot%d ring %s"):format(n, tostring(ring.Color)))
				end
			end
			return wrong
		end
		local wrong = circles()
		local settleBy = os.clock() + 1 -- a state change tweens the face and ring over 0.35 s
		while #wrong > 0 and os.clock() < settleBy do
			task.wait(0.1)
			wrong = circles()
		end
		list("team_circles_old_look", wrong)
		local bonus = level and level:FindFirstChild("TeamOverlay") and level.TeamOverlay:FindFirstChild("Bonus")
		local bonusOld = bonus ~= nil
			and same(bonus.BackgroundColor3, palette.TeamPlate)
			and math.abs(bonus.BackgroundTransparency - 0.3) <= 0.01
			and bonus:FindFirstChild("Rim") == nil
			and bonus.Font == UiTheme.Font
		h.check(res, "team_bonus_dark_plate", bonusOld, true, bonusOld)

		-- Panels keep the Scroll Dojo frame in both worlds: a DojoHandscroll "Handscroll" inside each.
		for _, name in { "RacerIndex", "RacerSettings", "RacerRebirth" } do
			local gui = playerGui:FindFirstChild(name)
			local scroll = gui and gui:FindFirstChild("Handscroll", true) ~= nil
			h.check(res, "panel_handscroll_" .. name, scroll, true, scroll == true)
		end
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
