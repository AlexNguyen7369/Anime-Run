--!nonstrict
-- Team button and Team panel (design doc 4.40 "Market pill and Bosses button", owner 2026-11-12, layout A "Line-up",
-- assets/ui/team_draft/A_desktop.png; docs/TEAM_AND_STAMINA_SPEC.md "Team" and "HUD" Team editor). Owned by
-- ui-test-writer. ui_team judges the button, the panel and what the panel shows for a Team the server set (ServerSetup
-- team_states). The team_* clicks (UiSpec.Clicks) press for real through Remotes.SetTeam; their After hooks here judge the
-- Team the server answered with and the slots showing it (the client only displays).
--
-- Contract (implementer: report a change, do not loosen):
--   RacerBossEvent/TeamButton: a TextButton in BossButton's style: transparent, Text "Team" at the bottom, an ImageLabel Icon
--     at the top with HudIcons.Team.Image (non-empty), HudChrome/Grid/Index's cell, icon and label sizes on screen, and a
--     TextLabel Key "T" in its top-right quarter, shown while a keyboard is in use. Its left edge equals BossButton's (within
--     X_TOL px); its centre is within MID_TOL px of the midpoint of the Items and Rebirth cells' centres; it is clear of the
--     left column (cells, Key letters, Badges) and of BossButton at its biggest pulse. Hidden in a boss event as BossButton is
--     (UiBossEvent onlyShown). A press, or the T key, toggles RacerTeam/Panel (PanelSwitch "Team"); an open panel draws above it.
--   RacerTeam/Panel: the game-wide frame (PanelFrame.Attach: attribute PanelFrame; UiSpec.BandPanels 1200), Header/Title
--     "TEAM", Header/Close. Directly in Panel (UiSpec.Team): Slots with Slot1..3 GuiButtons, each with Order ("RUNS FIRST",
--     "TAGS IN 2ND", "TAGS IN LAST"), and for a member Portrait (ImageLabel, its CharacterPortraits image when it has one),
--     Name, Category, Cruise ("<n> studs/s"), Stamina (holds the seconds); an empty slot shows Empty and no Portrait. Bonus
--     shows the team bonus name or "No team bonus" and its effect line; Bonus/Total holds the summed Stamina seconds. Roster
--     (ScrollingFrame): one card per owned catalog character, named by its id, with a TextLabel Badge "TEAM n" in green on
--     members. Sort (GuiButton), Search (TextBox). No BestTeam anywhere in it. The world dim (UiSpec.PanelDimmers) is on
--     while it is open.
--   Editing: tap a card, then a slot; a member put on another slot swaps; a member's own slot takes it off; never fewer than
--     1 member (the Backpack's notice); during a run the server refuses it and the panel shows the same notice as the Backpack.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("CharacterCatalog"))
local Portraits = require(Shared:WaitForChild("CharacterPortraits"))
local RaceConfig = require(Shared:WaitForChild("RaceConfig"))
local Format = require(Shared:WaitForChild("HudFormat"))
local Icons = require(script.Parent.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
local Spec = require(script.Parent.UiSpec)

local T = Spec.Team
local BOSS_BUTTON = "RacerBossEvent/BossButton"
local GRID = "HudChrome/Grid"
local COLUMN_CELLS = { "Index", "Items", "Rebirth" } -- the left column, top to bottom
local OVER_PANEL = "RacerIndex/Panel" -- a standard panel opened over the button (owner 2026-11-12, 4.42)
local X_TOL = 1 -- px: "the same column"
local MID_TOL = 12 -- px off the Items / Rebirth centres' midpoint: "level with the gap" (owner 2026-11-12)
local BOSS_PULSE = 1.08 -- BossButton's biggest pulse Scale (UiBossEvent BUTTON_PULSE)
local SHOW_WAIT = 2 -- s: an attribute change has replicated and the UI has followed

local Module = {}

function Module.Build(h)
	local scenarios, after = {}, {}
	local player = h.player or Players.LocalPlayer

	local function check(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local function waitIs(fn, want, seconds)
		local deadline = os.clock() + (seconds or SHOW_WAIT)
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
		return ok
	end
	local function shown(object)
		return object ~= nil and object:IsA("GuiObject") and h.visible(object)
	end
	local function overlaps(a, b)
		return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
	end
	local function number(text)
		return tonumber(string.match(text or "", "%d+%.?%d*"))
	end
	local function textOf(object)
		return object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) and object.Text
			or nil
	end
	local function fixtureIds()
		local raw = player:GetAttribute(T.FixtureAttr)
		return type(raw) == "string" and string.split(raw, ",") or {}
	end
	local function team()
		return player:GetAttribute("Team") or ""
	end
	local function dimOn()
		local gui, frame = h.find(Spec.PanelDimmers.Gui), h.find(Spec.PanelDimmers.Frame)
		return gui ~= nil and gui:IsA("ScreenGui") and gui.Enabled and frame ~= nil and frame.Visible
	end

	-- What the slots show against the Team `ids` in slot order; `exact` also compares Category and the base cruise (a Team
	-- with no bonus). Returns problems, the summed Stamina seconds the slots show.
	local function slotProblems(ids, exact)
		local wrong, sum = {}, 0
		local slots = h.find(T.Slots)
		if not slots then
			return { T.Slots .. " missing" }, 0
		end
		for n = 1, 3 do
			local slot = slots:FindFirstChild("Slot" .. n)
			local tag = "Slot" .. n
			if not (slot and slot:IsA("GuiButton")) then
				table.insert(wrong, tag .. " missing (GuiButton)")
				continue
			end
			local order = textOf(slot:FindFirstChild("Order"))
			if not (order and string.upper(order) == T.Order[n]) then
				table.insert(wrong, ("%s Order %q, want %q"):format(tag, tostring(order), T.Order[n]))
			end
			local portrait = slot:FindFirstChild("Portrait")
			local empty = slot:FindFirstChild("Empty")
			local spec = ids[n] and Catalog.Get(ids[n])
			if not spec then
				if not shown(empty) then
					table.insert(wrong, tag .. ": no member, Empty not shown")
				end
				if shown(portrait) then
					table.insert(wrong, tag .. ": no member, Portrait shown")
				end
				continue
			end
			if shown(empty) then
				table.insert(wrong, tag .. ": " .. spec.Id .. " on it, Empty shown")
			end
			local image = Portraits[spec.Id] or Portraits[spec.Model or spec.Id]
			if not (portrait and portrait:IsA("ImageLabel") and shown(portrait) and portrait.Image ~= "") then
				table.insert(wrong, tag .. ": Portrait not a shown ImageLabel with an image")
			elseif image and portrait.Image ~= image then
				table.insert(wrong, ("%s Portrait %s, want %s's %s"):format(tag, portrait.Image, spec.Id, image))
			end
			local name = textOf(slot:FindFirstChild("Name"))
			if name ~= spec.Name then
				table.insert(wrong, ("%s Name %q, want %q"):format(tag, tostring(name), spec.Name))
			end
			local category = textOf(slot:FindFirstChild("Category"))
			if not category or (exact and category ~= spec.Category) then
				table.insert(wrong, ("%s Category %q, want %q"):format(tag, tostring(category), spec.Category))
			end
			local cruise = textOf(slot:FindFirstChild("Cruise"))
			local wantCruise = Format.RateText(RaceConfig.Cruise(spec))
			if not (cruise and string.find(cruise, "studs/s", 1, true)) or (exact and cruise ~= wantCruise) then
				table.insert(wrong, ("%s Cruise %q, want %q"):format(tag, tostring(cruise), wantCruise))
			end
			local stamina = number(textOf(slot:FindFirstChild("Stamina")))
			if not (stamina and stamina > 0) then
				table.insert(wrong, tag .. " Stamina holds no seconds")
			else
				sum += stamina
			end
		end
		return wrong, sum
	end
	-- Waits until the slots show `ids` (the server's answer), then lists what is still wrong.
	local function checkSlots(res, tag, ids, exact)
		local wrong = waitIs(function()
			return #slotProblems(ids, exact) == 0
		end, true)
		h.checkList(res, tag .. "_slots_show_team", wrong and {} or (slotProblems(ids, exact)))
	end
	-- A notice with `text` shown anywhere in PlayerGui within SHOW_WAIT.
	local function noticeShown(text)
		return waitIs(function()
			for _, d in player:WaitForChild("PlayerGui"):GetDescendants() do
				if
					(d:IsA("TextLabel") or d:IsA("TextButton"))
					and h.visible(d)
					and string.find(d.Text, text, 1, true)
				then
					return true
				end
			end
			return false
		end, true)
	end

	-- Owner 2026-11-11 (4.40, kept for the Team button 2026-11-12): HudChrome/Grid/Index's sizes on screen.
	local function checkColumnSizes(res, b, icon)
		local column = h.find(GRID .. "/Index")
		local columnIcon = column and column:FindFirstChild("Icon")
		local columnLabel = column and column:FindFirstChild("Label")
		local wrong = {}
		if not (b and icon and column and columnIcon and columnLabel) then
			table.insert(wrong, "TeamButton/Icon or " .. GRID .. "/Index Icon / Label missing")
		else
			local function near(what, got, want)
				if math.abs(got - want) > 1 then
					table.insert(wrong, ("%s: Team %.1f, column %.1f"):format(what, got, want))
				end
			end
			near("cell width", b.AbsoluteSize.X, column.AbsoluteSize.X)
			near("cell height", b.AbsoluteSize.Y, column.AbsoluteSize.Y)
			near("icon width", icon.AbsoluteSize.X, columnIcon.AbsoluteSize.X)
			near("icon height", icon.AbsoluteSize.Y, columnIcon.AbsoluteSize.Y)
			near(
				"icon top offset",
				icon.AbsolutePosition.Y - b.AbsolutePosition.Y,
				columnIcon.AbsolutePosition.Y - column.AbsolutePosition.Y
			)
			local columnScale = column.AbsoluteSize.Y / column.Size.Y.Offset
			local scale = b.Size.Y.Offset > 0 and b.AbsoluteSize.Y / b.Size.Y.Offset or 1
			if b:IsA("TextButton") then
				near("label TextSize", b.TextSize * scale, columnLabel.TextSize * columnScale)
				if b.Font ~= columnLabel.Font then
					table.insert(
						wrong,
						("label Font: Team %s, column %s"):format(tostring(b.Font), tostring(columnLabel.Font))
					)
				end
			end
		end
		h.check(
			res,
			"team_button_column_sizes",
			#wrong == 0 and "same" or table.concat(wrong, "; "),
			"same as " .. GRID .. "/Index",
			#wrong == 0
		)
	end

	local function checkButton(res)
		local b = h.find(T.Button)
		check(res, "team_button_present", b ~= nil and b:IsA("TextButton"), true)
		check(
			res,
			"team_button_shown",
			waitIs(function()
				return shown(h.find(T.Button))
			end, true),
			true
		)
		check(res, "team_button_text", textOf(b), T.Label)
		check(res, "team_button_active", b ~= nil and b.Active, true)
		check(res, "team_button_transparent", b and b.BackgroundTransparency, 1)
		local icon = b and b:FindFirstChild("Icon")
		local want = Icons.Team and Icons.Team.Image
		h.check(
			res,
			"team_button_icon",
			icon and icon:IsA("ImageLabel") and icon.Image or "no ImageLabel Icon",
			"HudIcons.Team " .. tostring(want),
			type(want) == "string" and want ~= "" and icon ~= nil and icon:IsA("ImageLabel") and icon.Image == want
		)
		check(
			res,
			"team_button_label_under_icon",
			b ~= nil
				and b:IsA("TextButton")
				and b.TextYAlignment == Enum.TextYAlignment.Bottom
				and icon ~= nil
				and icon.Position.Y.Scale == 0,
			true
		)
		checkColumnSizes(res, b, icon)
		-- Design doc 4.40: the keybind letter (T, proposed) in the top-right quarter, as the column buttons show theirs
		local key = b and b:FindFirstChild("Key", true)
		check(res, "team_button_key_letter", textOf(key), T.Key)
		if UserInputService.KeyboardEnabled and key and key:IsA("GuiObject") then
			check(res, "team_button_key_shown", h.visible(key), true)
			local br, kr = h.rect(b), h.rect(key)
			local quarter = { x = br.x + br.w / 2, y = br.y, w = br.w / 2, h = br.h / 2 }
			check(
				res,
				"team_button_key_top_right",
				kr.x >= quarter.x - 1
					and kr.y >= quarter.y - 1
					and kr.x + kr.w <= quarter.x + quarter.w + 1
					and kr.y + kr.h <= quarter.y + quarter.h + 1,
				true
			)
		end
		check(res, "team_second_column_listed", table.find(Spec.SecondColumnButtons, T.Button) ~= nil, true)
		check(res, "team_panel_registered", Spec.PanelSwitch.Names[T.Panel], T.PanelSwitchName)
	end

	-- Design doc 4.40 (owner 2026-11-12): in the second column under Bosses, level with the Items / Rebirth gap.
	local function checkPlace(res)
		local b, boss, grid = h.find(T.Button), h.find(BOSS_BUTTON), h.find(GRID)
		local r = b and shown(b) and h.rect(b)
		local br = boss and shown(boss) and h.rect(boss)
		h.check(
			res,
			"team_button_left_edge_as_bosses",
			r and r.x or "no " .. T.Button,
			br and ("%.1f +/- %d"):format(br.x, X_TOL) or "no " .. BOSS_BUTTON,
			r ~= nil and br ~= nil and math.abs(r.x - br.x) <= X_TOL
		)
		local cells = {}
		for i, name in COLUMN_CELLS do
			local o = grid and grid:FindFirstChild(name)
			cells[i] = o and o:IsA("GuiObject") and o or nil
		end
		local items, rebirth = cells[2] and h.rect(cells[2]), cells[3] and h.rect(cells[3])
		local wantMid = items and rebirth and (items.y + items.h / 2 + rebirth.y + rebirth.h / 2) / 2
		local mid = r and r.y + r.h / 2
		h.check(
			res,
			"team_button_between_items_and_rebirth",
			mid or "no " .. T.Button,
			wantMid and ("%.1f +/- %d"):format(wantMid, MID_TOL) or "no " .. GRID .. " Items / Rebirth",
			mid ~= nil and wantMid ~= nil and math.abs(mid - wantMid) <= MID_TOL
		)
		for i, name in COLUMN_CELLS do
			local cell, hit = cells[i], nil
			if r and cell then
				hit = overlaps(r, h.rect(cell)) and name
				for _, o in cell:GetDescendants() do
					if not hit and o:IsA("GuiObject") and o.Visible and overlaps(r, h.rect(o)) then
						hit = name .. "/" .. o.Name
					end
				end
			end
			h.check(
				res,
				"team_button_clear_of_" .. string.lower(name),
				not r and "no " .. T.Button
					or not cell and "no " .. GRID .. "/" .. name
					or hit and hit .. " overlaps"
					or "clear",
				"clear",
				r ~= nil and cell ~= nil and not hit
			)
		end
		-- BossButton at its biggest pulse (it grows right and down from its top-left corner)
		local pulse = boss and boss:FindFirstChild("PulseScale")
		local p = pulse and pulse:IsA("UIScale") and pulse.Scale or 1
		local big = br and { x = br.x, y = br.y, w = br.w / p * BOSS_PULSE, h = br.h / p * BOSS_PULSE }
		h.check(
			res,
			"team_button_clear_of_bosses",
			not (r and big) and "missing" or overlaps(r, big) and "overlaps" or "clear",
			"clear",
			r ~= nil and big ~= nil and not overlaps(r, big)
		)
		-- Owner 2026-11-12 (4.42): an open panel may overlap the button and draws above it; the panel covers its centre
		local restore = h.setPanels({ OVER_PANEL })
		local panel = h.find(OVER_PANEL)
		local above, why = false, "no " .. OVER_PANEL
		if panel and b then
			above, why = h.drawsAbove(panel, b)
		end
		h.check(res, "team_button_under_panel", why, "panel above the button", above)
		local hit = b and h.topAt(h.centre(h.rect(b)))
		h.check(
			res,
			"team_button_blocked_under_panel",
			hit and hit:GetFullName() or "nothing",
			"the panel",
			b ~= nil and panel ~= nil and hit ~= nil and (hit == panel or panel:IsAncestorOf(hit))
		)
		restore()
	end

	local function checkPanel(res)
		local panel = h.find(T.Panel)
		check(res, "team_panel_present", panel ~= nil and panel:IsA("Frame"), true)
		check(res, "team_panel_shown", shown(panel), true)
		check(res, "team_panel_shared_frame", panel and panel:GetAttribute("PanelFrame"), true)
		local title = textOf(h.find(T.Title))
		check(res, "team_panel_title", title and string.upper(title), "TEAM")
		local close = h.find(T.Close)
		check(res, "team_panel_close", close ~= nil and close:IsA("GuiButton"), true)
		check(res, "team_panel_dims_world", waitIs(dimOn, true), true)
		local parts = {
			{ T.Slots, "Frame" },
			{ T.Bonus, "GuiObject" },
			{ T.Bonus .. "/Total", "TextLabel" },
			{ T.Roster, "ScrollingFrame" },
			{ T.Sort, "GuiButton" },
			{ T.Search, "TextBox" },
		}
		for _, part in parts do
			local o = h.find(part[1])
			h.check(
				res,
				"team_part_" .. string.match(part[1], "[^/]+$"),
				o and o.ClassName or "missing",
				part[2],
				o ~= nil and o:IsA(part[2])
			)
		end
		for n = 1, 3 do
			local slot = h.find(T.Slots .. "/Slot" .. n)
			check(res, "team_part_Slot" .. n, slot ~= nil and slot:IsA("GuiButton"), true)
		end
		for _, name in T.Gone do
			check(res, "team_no_" .. name, panel and panel:FindFirstChild(name, true), nil)
		end
	end

	-- The roster: one card per owned catalog character; members carry the green TEAM n badge, the others none.
	local function rosterProblems(ids)
		local wrong = {}
		local roster = h.find(T.Roster)
		if not roster then
			return { T.Roster .. " missing" }
		end
		local data = player:FindFirstChild("GachaData")
		for _, entry in data and data:GetChildren() or {} do
			local spec = Catalog.Get(entry.Name)
			if spec then
				local card = roster:FindFirstChild(spec.Id)
				local badge = card and textOf(card:FindFirstChild("Badge"))
				local slot = table.find(ids, spec.Id)
				if not card then
					table.insert(wrong, spec.Id .. ": owned, no card")
				elseif slot then
					local label = card:FindFirstChild("Badge")
					if badge ~= "TEAM " .. slot or not Spec.Backpack.Green(label.TextColor3) then
						table.insert(
							wrong,
							("%s: badge %q, want green %q"):format(spec.Id, tostring(badge), "TEAM " .. slot)
						)
					end
				elseif badge and string.find(badge, "TEAM", 1, true) then
					table.insert(wrong, ("%s: not a member, badge %q"):format(spec.Id, badge))
				end
			end
		end
		return wrong
	end

	function scenarios.ui_team(res)
		h.waitGuis()
		checkButton(res)
		checkPlace(res)
		local restore = h.setPanels({ T.Panel })
		checkPanel(res)
		-- The slots, the bonus and the roster show the Team the server set (A, B; slot 3 empty; teams of 2 have no bonus)
		if setup(res, "team_states") then
			local ids = fixtureIds()
			local ab = ids[1] and ids[2] and (ids[1] .. "," .. ids[2]) or "?"
			check(res, "team_fixture_set", waitIs(team, ab), ab)
			checkSlots(res, "team_ab", { ids[1], ids[2] }, true)
			local _, sum = slotProblems({ ids[1], ids[2] }, true)
			local bonus = h.find(T.Bonus)
			local bonusText = {}
			for _, d in bonus and bonus:GetDescendants() or {} do
				if d:IsA("TextLabel") and h.visible(d) then
					table.insert(bonusText, d.Text)
				end
			end
			h.check(
				res,
				"team_ab_no_bonus",
				table.concat(bonusText, " | "),
				"holds " .. T.NoBonus,
				string.find(string.lower(table.concat(bonusText, " ")), string.lower(T.NoBonus), 1, true) ~= nil
			)
			local total = number(textOf(h.find(T.Bonus .. "/Total")))
			h.check(
				res,
				"team_ab_total_stamina",
				total or "no seconds",
				("%.1f +/- %.2f"):format(sum, T.StaminaSlack),
				total ~= nil and math.abs(total - sum) <= T.StaminaSlack
			)
			local wrong = waitIs(function()
				return #rosterProblems({ ids[1], ids[2] }) == 0
			end, true)
			h.checkList(res, "team_ab_roster", wrong and {} or rosterProblems({ ids[1], ids[2] }))
			setup(res, "team_states_clear")
		end
		restore()
	end

	-- After the real presses (UiSpec.Clicks team_*): the Team the server answered with, letters a / b / c = the
	-- team_states fixture's ids.
	local function judge(res, tag, letters, hold)
		local all = fixtureIds()
		local ids = {}
		for i = 1, #letters do
			ids[i] = all[string.byte(letters, i) - string.byte("a") + 1]
		end
		local want = table.concat(ids, ",")
		if hold then
			task.wait(T.Hold) -- a refused change: the Team must still be the same afterwards
		end
		check(res, tag .. "_team", waitIs(team, want), want)
		checkSlots(res, tag, ids, false)
		local wrong = waitIs(function()
			return #rosterProblems(ids) == 0
		end, true)
		h.checkList(res, tag .. "_roster_badges", wrong and {} or rosterProblems(ids))
	end
	function after.team_dim_on(res)
		check(res, "team_open_dims_world", waitIs(dimOn, true), true)
	end
	function after.team_pick_sends_nothing(res)
		judge(res, "team_pick", "ab", true)
	end
	function after.team_is_abc(res)
		judge(res, "team_put", "abc")
	end
	function after.team_is_bac(res)
		judge(res, "team_swap", "bac")
	end
	function after.team_is_bc(res)
		judge(res, "team_remove", "bc")
	end
	function after.team_is_b(res)
		judge(res, "team_remove_second", "b")
	end
	function after.team_keeps_last_member(res)
		judge(res, "team_last", "b", true)
		check(res, "team_last_notice", noticeShown(T.MinNotice), true)
	end
	function after.team_locked_in_run(res)
		judge(res, "team_run", "ab", true)
		check(res, "team_run_notice", noticeShown(T.RunNotice), true)
	end

	return { Scenarios = scenarios, After = after }
end

return Module
