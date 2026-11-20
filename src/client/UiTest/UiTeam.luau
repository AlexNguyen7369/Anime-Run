--!nonstrict
-- Team button, Team Setup page and its entry points (design doc 4.40 Team button, owner 2026-11-12; design doc 4.45
-- "Sakura Dojo pages", owner 2026-11-17, which replaces layout A; docs/TEAM_AND_STAMINA_SPEC.md "Team Setup page";
-- docs/team_setup_contract.md). Owned by ui-test-writer. ui_team judges the button, the page and what it shows for a Team
-- the server set (ServerSetup team_states). ui_entry_points judges the Summon button, the minibar, the plaza prompts,
-- the transition and the input lock. The team_* clicks (UiSpec.Clicks) edit the local draft and Deploy for real through
-- Remotes.SetTeam; their After hooks here judge the draft the page shows and the Team the server answered with.
--
-- Contract (implementer: report a change, do not loosen):
--   RacerSecondColumn/TeamButton: a TextButton in BossButton's style: transparent, Text "Team" at the bottom, an ImageLabel Icon
--     at the top with HudIcons.Team.Image (non-empty), HudChrome/Grid/Index's cell, icon and label sizes on screen, and a
--     TextLabel Key "T" in its top-right quarter, shown while a keyboard is in use. Its left edge equals BossButton's (within
--     X_TOL px); its centre is within MID_TOL px of the midpoint of the Items and Rebirth cells' centres; it is clear of the
--     left column (cells, Key letters, Badges) and of BossButton at its biggest pulse. Hidden in a boss event as BossButton is
--     (UiBossEvent onlyShown). A press, or the T key, toggles RacerTeam/Panel (PanelSwitch "Team"); an open panel draws above it.
--   RacerTeam/Panel: a full-screen page (owner 2026-11-17: AbsoluteSize = its ScreenGui's within 2 px; not a band
--     panel, UiSpec.FullScreenPanels), Header/Title "TEAM SETUP" (upper-cased), Header/Close, Header/BonusButton. The world dim is on while it is open.
--     BonusPopover (hidden until BonusButton; a second press hides it): Name (bonus or "No team bonus"), Effect, Total
--     ("Total <n> s"). Dots/Dot1..3: BackgroundTransparency < 0.5 when that draft slot is filled, else >= 0.5.
--     Altars/Altar1..3 (TextButtons, left to right, same Y, not overlapping): SlotLabel "SLOT n"; Pedestal (ViewportFrame
--     holding a Model "Altar", and a Model "Figure" (the member's 3D model) only on a member altar); its Portrait, Name and
--     Info stay hidden (owner 2026-11-19, 4.45 T2: a numbered seal instead of the name line); a member hides Plus / Add;
--     an empty altar shows Plus "+" and Add "Add Character". Remove "Remove" shows only on the selected altar holding a
--     member; attribute Selected on it. LedgerRows/Row1..3 (GuiButtons): a member shows Portrait (ImageLabel, its
--     CharacterPortraits image), Name (character name), Rarity (its rarity), Cruise ("<n> studs/s"); an empty row shows no
--     portrait image, no character name, no Rarity / Cruise text.
--     Footer: TeamName "Team 1", Status "Ready" (draft == saved Team) or "Unsaved changes" (or the server's refusal),
--     Count "<n> / 3", Progress/Fill Size.X.Scale = n/3. Tray: Tabs/Characters, Tabs/Sidekicks (attribute
--     Active on the shown one), Sort (GuiButton), Search (TextBox), Roster (ScrollingFrame): one card per owned character
--     named by its id with a green TextLabel Badge "TEAM n" on draft members. QuickSetup, Deploy (attribute Enabled false
--     while draft == saved Team or the draft is empty). ConfirmClose (hidden; Deploy, Discard). No BestTeam anywhere; no
--     Slots or Bonus child of Panel.
--   Gear: every member altar and every character card with a RelicGear / SidekickGear entry holds Gear (top-right: in the
--     card's top-right quarter, on an altar in the Pedestal's top-right quarter) with Relic / Sidekick ImageLabels shown,
--     attributes ItemName and Rarity. UiTooltip/Tip (Title, Rarity, Body) shows on SelectionGained of an icon with Title ==
--     ItemName, and hides on SelectionLost.
--   Editing: tap an altar, then a card (draft only, nothing sent); a member already on another altar swaps; Remove takes
--     it off; Deploy sends SetTeam(draft) and closes on success; an empty draft never deploys; during a run the server
--     refuses, the page stays open with the draft and Footer/Status shows "Stop running to change your Team". Quick Setup
--     fills the draft's empty slots (TeamQuickPick) without saving. A dirty Close shows ConfirmClose and keeps the page open.
--   Entry points: HudChrome/ShopColumn/Summon (Key "G", attribute Panel "Sidekicks") opens the summon page; RacerHud's
--     OpenTeam opens Team Setup; workspace prompts OpenTeam ActionText "Team", OpenSidekicks "Summon". PlayerGui.UiTransition
--     (ScreenGui, Paper) sets Playing true when a page opens. LocalPlayer PageInputLocked is true while Team is open and
--     false after close. Two quick opens leave Team open exactly once (PanelSwitch.IsOpen and Panel.Visible agree).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("CharacterCatalog"))
local Portraits = require(Shared:WaitForChild("CharacterPortraits"))
local Icons = require(script.Parent.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
local SidekickView = require(script.Parent.Parent:WaitForChild("SidekickView"))
local Spec = require(script.Parent.UiSpec)

local T = Spec.Team
local BOSS_BUTTON = "RacerSecondColumn/BossButton"
local GRID = "HudChrome/Grid"
local COLUMN_CELLS = { "Index", "Items", "Rebirth" } -- the left column, top to bottom
local OVER_PANEL = "RacerIndex/Panel" -- a standard panel opened over the button (owner 2026-11-12, 4.42)
local X_TOL = 1 -- px: "the same column"
local MID_TOL = 12 -- px off the Items / Rebirth centres' midpoint: "level with the gap" (owner 2026-11-12)
local BOSS_PULSE = 1.08 -- BossButton's biggest pulse Scale (UiBossEvent BUTTON_PULSE)
local SHOW_WAIT = 2 -- s: an attribute change has replicated and the UI has followed
local TOL = 1 -- px
local DOT_FILLED = 0.5 -- Dot BackgroundTransparency below this: filled
local FILL_TOL = 0.02 -- Progress/Fill Size.X.Scale against n/3
local GEAR_CLEAR = 4 -- px between an altar's Gear and its SlotLabel (112999f)

local Module = {}

function Module.Build(h)
	local scenarios, after = {}, {}
	local player = h.player or Players.LocalPlayer
	local quickDraft = nil -- the draft team_quick_filled saw, for team_is_quick

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
	local function inside(outer, r)
		return r.x >= outer.x - TOL
			and r.y >= outer.y - TOL
			and r.x + r.w <= outer.x + outer.w + TOL
			and r.y + r.h <= outer.y + outer.h + TOL
	end
	local function topRight(r)
		return { x = r.x + r.w / 2, y = r.y, w = r.w / 2, h = r.h / 2 }
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
	local function panelSwitch()
		return require(script.Parent.Parent:WaitForChild("PanelSwitch"))
	end
	local function altar(n)
		return h.find(T.Altars .. "/Altar" .. n)
	end
	-- Letters a / b / c = the team_states fixture's ids, in slot order.
	local function idsOf(letters)
		local all, ids = fixtureIds(), {}
		for i = 1, #letters do
			ids[i] = all[string.byte(letters, i) - string.byte("a") + 1]
		end
		return ids
	end
	local function row(n)
		return h.find(T.Ledger .. "/Row" .. n)
	end
	-- The ids the ledger rows show, in slot order (nil for an empty slot), read from Name against the catalog
	-- (owner 2026-11-19, 4.45 T2: the member's name shows in its ledger row, not on the altar).
	local function draftShown()
		local out = {}
		for n = 1, 3 do
			local r = row(n)
			local name = r and shown(r:FindFirstChild("Name")) and textOf(r:FindFirstChild("Name"))
			if name and name ~= T.AddText and name ~= "" then
				for _, spec in Catalog.All() do
					if spec.Name == name then
						out[n] = spec.Id
						break
					end
				end
				out[n] = out[n] or ("?" .. name)
			end
		end
		return out
	end

	-- What the altars and ledger rows show against the draft `ids` (slot n empty when ids[n] is nil).
	local function altarProblems(ids)
		local wrong = {}
		for n = 1, 3 do
			local a, tag = altar(n), "Altar" .. n
			if not (a and a:IsA("TextButton")) then
				table.insert(wrong, tag .. " missing (TextButton)")
				continue
			end
			local label = textOf(a:FindFirstChild("SlotLabel"))
			if label ~= T.SlotLabels[n] then
				table.insert(wrong, ("%s SlotLabel %q, want %q"):format(tag, tostring(label), T.SlotLabels[n]))
			end
			local pedestal = a:FindFirstChild("Pedestal")
			local model = pedestal and pedestal:IsA("ViewportFrame") and pedestal:FindFirstChild("Altar", true)
			if not (model and model:IsA("Model")) then
				table.insert(wrong, tag .. ": Pedestal is not a ViewportFrame holding a Model Altar")
			end
			-- Owner 2026-11-17 (4.45): a member stands on its altar as its 3D model; an empty altar holds none
			local figure = pedestal and pedestal:FindFirstChild("Figure", true)
			local hasFigure = figure ~= nil and figure:IsA("Model")
			if hasFigure ~= (ids[n] ~= nil) then
				table.insert(
					wrong,
					("%s: Pedestal Model Figure %s, want %s"):format(
						tag,
						hasFigure and "present" or "absent",
						ids[n] and "present" or "absent"
					)
				)
			end
			-- Owner 2026-11-19 (4.45 T2): the altar carries a numbered seal instead of the name line; the member's
			-- portrait, name, rarity and cruise show in its ledger row
			for _, part in { "Portrait", "Name", "Info" } do
				if shown(a:FindFirstChild(part)) then
					table.insert(wrong, ("%s: %s shown (T2: the ledger row shows it)"):format(tag, part))
				end
			end
			local r, rowTag = row(n), "Ledger Row" .. n
			if not (r and r:IsA("GuiButton")) then
				table.insert(wrong, rowTag .. " missing (GuiButton)")
				continue
			end
			local portrait, name = r:FindFirstChild("Portrait"), r:FindFirstChild("Name")
			local rarity, cruise = r:FindFirstChild("Rarity"), r:FindFirstChild("Cruise")
			local plus, add = a:FindFirstChild("Plus"), a:FindFirstChild("Add")
			local spec = ids[n] and Catalog.Get(ids[n])
			if not spec then
				if not (shown(plus) and textOf(plus) == T.PlusText) then
					table.insert(wrong, tag .. ': empty, Plus "+" not shown')
				end
				if not (shown(add) and textOf(add) == T.AddText) then
					table.insert(wrong, tag .. ': empty, Add "Add Character" not shown')
				end
				if shown(portrait) and portrait:IsA("ImageLabel") and portrait.Image ~= "" then
					table.insert(wrong, rowTag .. ": empty, Portrait image " .. portrait.Image .. " shown")
				end
				local shownName = shown(name) and textOf(name)
				if shownName and shownName ~= T.AddText and shownName ~= "" then
					table.insert(wrong, ("%s: empty, Name %q shown"):format(rowTag, shownName))
				end
				for _, o in { rarity, cruise } do
					if shown(o) and (textOf(o) or "") ~= "" then
						table.insert(wrong, ("%s: empty, %s %q shown"):format(rowTag, o.Name, textOf(o)))
					end
				end
				continue
			end
			if shown(plus) or shown(add) then
				table.insert(wrong, tag .. ": " .. spec.Id .. " on it, Plus / Add shown")
			end
			local image = Portraits[spec.Id] or Portraits[spec.Model or spec.Id]
			if not (portrait and portrait:IsA("ImageLabel") and shown(portrait)) then
				table.insert(wrong, rowTag .. ": Portrait not a shown ImageLabel")
			elseif image and portrait.Image ~= image then
				table.insert(wrong, ("%s Portrait %s, want %s's %s"):format(rowTag, portrait.Image, spec.Id, image))
			end
			if textOf(name) ~= spec.Name or not shown(name) then
				table.insert(wrong, ("%s Name %q, want %q"):format(rowTag, tostring(textOf(name)), spec.Name))
			end
			local rarityText = shown(rarity) and textOf(rarity) or ""
			if rarityText ~= spec.Rarity then
				table.insert(wrong, ("%s Rarity %q, want %q"):format(rowTag, rarityText, spec.Rarity))
			end
			local cruiseText = shown(cruise) and textOf(cruise) or ""
			if not string.find(cruiseText, "studs/s", 1, true) then
				table.insert(wrong, ('%s Cruise %q, want "<n> studs/s"'):format(rowTag, cruiseText))
			end
		end
		return wrong
	end
	-- Footer, Dots and Deploy for a draft of `count` members; `status` the Footer/Status text it must show.
	local function footerProblems(ids, status, deployOn)
		local wrong, count = {}, 0
		for n = 1, 3 do
			count += ids[n] and 1 or 0
		end
		local function want(path, text)
			local got = textOf(h.find(path))
			if got ~= text then
				table.insert(wrong, ("%s %q, want %q"):format(path, tostring(got), text))
			end
		end
		want(T.Footer .. "/TeamName", T.TeamName)
		want(T.Footer .. "/Status", status)
		want(T.Footer .. "/Count", T.CountText:format(count))
		local fill = h.find(T.Footer .. "/Progress/Fill")
		local scale = fill and fill:IsA("GuiObject") and fill.Size.X.Scale
		if not (scale and math.abs(scale - count / 3) <= FILL_TOL) then
			table.insert(wrong, ("Progress/Fill Size.X.Scale %s, want %.2f"):format(tostring(scale), count / 3))
		end
		for n = 1, 3 do
			local dot = h.find(T.Dots .. "/Dot" .. n)
			local filled = dot and dot:IsA("GuiObject") and dot.BackgroundTransparency < DOT_FILLED
			if not dot then
				table.insert(wrong, "Dot" .. n .. " missing")
			elseif filled ~= (ids[n] ~= nil) then
				table.insert(wrong, ("Dot%d filled=%s, want %s"):format(n, tostring(filled), tostring(ids[n] ~= nil)))
			end
		end
		local deploy = h.find(T.Deploy)
		local enabled = deploy and deploy:GetAttribute("Enabled")
		if deployOn ~= nil and enabled ~= deployOn then
			table.insert(wrong, ("Deploy Enabled %s, want %s"):format(tostring(enabled), tostring(deployOn)))
		end
		return wrong
	end
	-- Waits until the page shows the draft `ids` with `status`, then lists what is still wrong.
	local function checkDraft(res, tag, ids, status, deployOn)
		local function all()
			local wrong = altarProblems(ids)
			for _, w in footerProblems(ids, status, deployOn) do
				table.insert(wrong, w)
			end
			return wrong
		end
		local ok = waitIs(function()
			return #all() == 0
		end, true)
		h.checkList(res, tag .. "_page_shows_draft", ok and {} or all())
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
		-- Owner 2026-11-12 (4.42): an open panel MAY overlap the button; where it does it draws above it and takes the
		-- clicks there, where it does not the button stays shown and pressable
		local restore = h.setPanels({ OVER_PANEL })
		local panel = h.find(OVER_PANEL)
		if not (panel and b) then
			h.check(res, "team_button_under_panel", not b and "no " .. T.Button or "no " .. OVER_PANEL, "both", false)
		else
			local pr, br2 = h.rect(panel), h.rect(b)
			local ix1, iy1 = math.max(pr.x, br2.x), math.max(pr.y, br2.y)
			local ix2, iy2 = math.min(pr.x + pr.w, br2.x + br2.w), math.min(pr.y + pr.h, br2.y + br2.h)
			if ix2 > ix1 and iy2 > iy1 then
				local above, why = h.drawsAbove(panel, b)
				h.check(res, "team_button_under_panel_where_covered", why, "panel above the button", above)
				local hit = h.topAt((ix1 + ix2) / 2, (iy1 + iy2) / 2)
				h.check(
					res,
					"team_button_blocked_under_panel_where_covered",
					hit and hit:GetFullName() or "nothing",
					"not the button",
					hit == nil or not (hit == b or b:IsAncestorOf(hit))
				)
			else
				h.check(res, "team_button_shown_clear_of_panel_here", shown(b), true, shown(b))
				local hit = h.topAt(h.centre(br2))
				h.check(
					res,
					"team_button_pressable_clear_of_panel_here",
					hit and hit:GetFullName() or "nothing",
					"the button",
					hit ~= nil and (hit == b or b:IsAncestorOf(hit))
				)
			end
		end
		restore()
	end
	local function checkPanel(res)
		local panel = h.find(T.Panel)
		check(res, "team_panel_present", panel ~= nil and panel:IsA("Frame"), true)
		check(res, "team_panel_shown", shown(panel), true)
		-- Owner 2026-11-17 (4.45): a full-screen page, not the game-wide panel frame
		local gui = panel and panel:FindFirstAncestorWhichIsA("LayerCollector")
		local full = panel ~= nil
			and gui ~= nil
			and math.abs(panel.AbsoluteSize.X - gui.AbsoluteSize.X) <= T.FullScreenTol
			and math.abs(panel.AbsoluteSize.Y - gui.AbsoluteSize.Y) <= T.FullScreenTol
		h.check(
			res,
			"team_panel_full_screen",
			panel
					and gui
					and ("%.0fx%.0f in %.0fx%.0f"):format(
						panel.AbsoluteSize.X,
						panel.AbsoluteSize.Y,
						gui.AbsoluteSize.X,
						gui.AbsoluteSize.Y
					)
				or "missing",
			"the ScreenGui's size +/- " .. T.FullScreenTol,
			full
		)
		check(res, "team_panel_not_band", Spec.BandPanels[T.Panel], nil)
		local title = textOf(h.find(T.Title))
		check(res, "team_panel_title", title and string.upper(title), T.TitleText)
		local close = h.find(T.Close)
		check(res, "team_panel_close", close ~= nil and close:IsA("GuiButton"), true)
		check(res, "team_panel_dims_world", waitIs(dimOn, true), true)
		local parts = {
			{ T.BonusButton, "TextButton" },
			{ T.BonusPopover, "Frame" },
			{ T.Dots, "GuiObject" },
			{ T.Altars, "GuiObject" },
			{ T.Footer, "GuiObject" },
			{ T.Footer .. "/Progress/Fill", "GuiObject" },
			{ T.Tabs .. "/Characters", "TextButton" },
			{ T.Tabs .. "/Sidekicks", "TextButton" },
			{ T.Roster, "ScrollingFrame" },
			{ T.Sort, "GuiButton" },
			{ T.Search, "TextBox" },
			{ T.QuickSetup, "TextButton" },
			{ T.Deploy, "TextButton" },
			{ T.ConfirmClose, "Frame" },
			{ T.ConfirmClose .. "/Deploy", "TextButton" },
			{ T.ConfirmClose .. "/Discard", "TextButton" },
		}
		for _, part in parts do
			local o = h.find(part[1])
			h.check(
				res,
				"team_part_" .. string.gsub(string.sub(part[1], #T.Panel + 2), "/", "_"),
				o and o.ClassName or "missing",
				part[2],
				o ~= nil and o:IsA(part[2])
			)
		end
		check(res, "team_quick_setup_text", textOf(h.find(T.QuickSetup)), "Quick Setup")
		check(res, "team_deploy_text", textOf(h.find(T.Deploy)), "Deploy")
		check(res, "team_bonus_button_text", textOf(h.find(T.BonusButton)), "Team Bonus")
		check(res, "team_bonus_popover_hidden_at_open", shown(h.find(T.BonusPopover)), false)
		check(res, "team_confirm_close_hidden_at_open", shown(h.find(T.ConfirmClose)), false)
		for _, name in T.Gone do
			check(res, "team_no_" .. name, panel and panel:FindFirstChild(name, true), nil)
		end
		for _, name in T.GoneDirect do
			check(res, "team_no_panel_" .. name, panel and panel:FindFirstChild(name), nil)
		end
		-- Three altars, left to right, level, apart
		local rects, wrong = {}, {}
		for n = 1, 3 do
			local a = altar(n)
			if shown(a) then
				rects[n] = h.rect(a)
			else
				table.insert(wrong, "Altar" .. n .. " missing or hidden")
			end
		end
		for n = 1, 2 do
			local a, b = rects[n], rects[n + 1]
			if a and b then
				if a.x + a.w / 2 >= b.x + b.w / 2 then
					table.insert(wrong, ("Altar%d not left of Altar%d"):format(n, n + 1))
				end
				if math.abs(a.y - b.y) > TOL then
					table.insert(wrong, ("Altar%d y %.0f, Altar%d y %.0f"):format(n, a.y, n + 1, b.y))
				end
			end
			for m = n + 1, 3 do
				if rects[n] and rects[m] and overlaps(rects[n], rects[m]) then
					table.insert(wrong, ("Altar%d overlaps Altar%d"):format(n, m))
				end
			end
		end
		h.checkList(res, "team_altars_in_a_row", wrong)
	end

	-- The roster: one card per owned catalog character; draft members carry the green TEAM n badge, the others none.
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

	-- Gear icons on `holder` (a card, or an altar judged against its Portrait) for `characterId`.
	local function gearProblems(holder, characterId, frame, tag, icons)
		local wrong = {}
		local relic = SidekickView.RelicGear(player)[characterId]
		local sidekick = SidekickView.Gear(player)[characterId]
		if relic == nil and sidekick == nil then
			return wrong
		end
		local gear = holder:FindFirstChild("Gear", true)
		if not (gear and shown(gear)) then
			table.insert(wrong, tag .. ": wears gear, no shown Gear")
			return wrong
		end
		if not inside(topRight(h.rect(frame)), h.rect(gear)) then
			table.insert(wrong, tag .. ": Gear not in the top-right quarter of " .. frame.Name)
		end
		for _, part in { { "Relic", relic }, { "Sidekick", sidekick } } do
			local icon = gear:FindFirstChild(part[1], true)
			if part[2] == nil then
				continue
			end
			local name = icon and icon:GetAttribute("ItemName")
			if not (icon and icon:IsA("ImageLabel") and shown(icon)) then
				table.insert(wrong, tag .. ": " .. part[1] .. " icon not a shown ImageLabel")
			elseif type(name) ~= "string" or name == "" then
				table.insert(wrong, tag .. ": " .. part[1] .. " icon has no ItemName")
			elseif type(icon:GetAttribute("Rarity")) ~= "string" then
				table.insert(wrong, tag .. ": " .. part[1] .. " icon has no Rarity")
			else
				table.insert(icons, icon)
			end
		end
		return wrong
	end
	-- The tooltip on gamepad focus of an icon: shown with Title == ItemName, hidden when focus leaves.
	local function checkTooltip(res, icon)
		if not icon then
			h.check(res, "team_gear_tooltip", "no gear icon to focus", "an icon", false)
			return
		end
		local wasSelectable = icon.Selectable
		icon.Selectable = true -- shortcut: the contract shows the tip on SelectionGained; hover can not be sent from a test
		GuiService.SelectedObject = icon
		local tip = h.find(T.Tooltip)
		local function title()
			local t = h.find(T.Tooltip .. "/Title")
			return shown(h.find(T.Tooltip)) and textOf(t) or nil
		end
		local got = waitIs(title, icon:GetAttribute("ItemName"))
		check(res, "team_gear_tooltip_names_item", got, icon:GetAttribute("ItemName"))
		for _, part in { "Title", "Rarity", "Body" } do
			check(res, "team_gear_tooltip_has_" .. string.lower(part), tip and tip:FindFirstChild(part) ~= nil, true)
		end
		GuiService.SelectedObject = nil
		check(
			res,
			"team_gear_tooltip_hides",
			waitIs(function()
				return shown(h.find(T.Tooltip))
			end, false),
			false
		)
		icon.Selectable = wasSelectable
	end
	-- Gear on every card and member altar (relic_states puts a Relic on Team[1]).
	local function checkGear(res, ids)
		local wrong, icons = {}, {}
		local roster = h.find(T.Roster)
		for _, card in roster and roster:GetChildren() or {} do
			if card:IsA("GuiObject") and Catalog.Get(card.Name) then
				for _, w in gearProblems(card, card.Name, card, "card " .. card.Name, icons) do
					table.insert(wrong, w)
				end
			end
		end
		for n = 1, 3 do
			local a = altar(n)
			local pedestal = a and a:FindFirstChild("Pedestal")
			if ids[n] and pedestal then
				for _, w in gearProblems(a, ids[n], pedestal, "Altar" .. n, icons) do
					table.insert(wrong, w)
				end
			end
		end
		local worn = SidekickView.RelicGear(player)[ids[1]] ~= nil
		check(res, "team_gear_fixture_relic_on_first", worn, true)
		h.checkList(res, "team_gear_icons", wrong)
		-- 112999f: an altar's gear icons sit right of the seal, GEAR_CLEAR px clear of its SlotLabel (the eye check
		-- runs it at 4:3, where it is tightest)
		local crowded = {}
		for n = 1, 3 do
			local a = altar(n)
			local gear = ids[n] and a and a:FindFirstChild("Gear", true)
			local label = a and a:FindFirstChild("SlotLabel", true)
			if gear and label and shown(gear) and shown(label) then
				local l = h.rect(label)
				local grown =
					{ x = l.x - GEAR_CLEAR, y = l.y - GEAR_CLEAR, w = l.w + 2 * GEAR_CLEAR, h = l.h + 2 * GEAR_CLEAR }
				if overlaps(grown, h.rect(gear)) then
					table.insert(crowded, "Altar" .. n .. ": Gear within " .. GEAR_CLEAR .. " px of SlotLabel")
				end
			end
		end
		h.checkList(res, "team_gear_clear_of_slot_label", crowded)
		checkTooltip(res, icons[1])
	end

	function scenarios.ui_team(res)
		h.waitGuis()
		checkButton(res)
		checkPlace(res)
		local restore = h.setPanels({ T.Panel })
		checkPanel(res)
		-- The altars, footer and roster show the Team the server set (A, B; altar 3 empty), unchanged: Ready, Deploy off
		if setup(res, "team_states") then
			local ids = fixtureIds()
			local ab = ids[1] and ids[2] and (ids[1] .. "," .. ids[2]) or "?"
			check(res, "team_fixture_set", waitIs(team, ab), ab)
			restore()
			restore = h.setPanels({ T.Panel }) -- reopen: the draft is the saved Team on open
			checkDraft(res, "team_ab", { ids[1], ids[2] }, T.Ready, false)
			local tab = h.find(T.Tabs .. "/Characters")
			check(res, "team_characters_tab_active", tab and tab:GetAttribute("Active"), true)
			local wrong = waitIs(function()
				return #rosterProblems({ ids[1], ids[2] }) == 0
			end, true)
			h.checkList(res, "team_ab_roster", wrong and {} or rosterProblems({ ids[1], ids[2] }))
			-- 112999f: a gamepad starts on the first altar (FirstFocus), not on Close; only Altar1 carries it
			local firstFocus = {}
			for _, d in h.find(T.Panel) and h.find(T.Panel):GetDescendants() or {} do
				if d:IsA("GuiButton") and d:GetAttribute("FirstFocus") then
					table.insert(firstFocus, d.Name)
				end
			end
			check(res, "team_first_focus_is_altar1", table.concat(firstFocus, ","), "Altar1")
			for n = 1, 3 do
				local a = altar(n)
				check(
					res,
					"team_altar" .. n .. "_remove_hidden_at_open",
					shown(a and a:FindFirstChild("Remove")),
					false
				)
			end
			if setup(res, "relic_states") then
				task.wait(0.5)
				checkGear(res, { ids[1], ids[2] })
				setup(res, "restore:relic_states")
			end
			setup(res, "team_states_clear")
		end
		restore()
	end

	-- Entry points (design doc 4.45). The presses themselves are clicks (open_summon, summon_key_g, open_team_minibar).
	function scenarios.ui_entry_points(res)
		h.waitGuis()
		local summon = h.find(T.Summon)
		check(res, "entry_summon_present", summon ~= nil and summon:IsA("ImageButton"), true)
		check(res, "entry_summon_shown", shown(summon), true)
		check(res, "entry_summon_panel_attr", summon and summon:GetAttribute("Panel"), "Sidekicks")
		check(res, "entry_summon_key_letter", textOf(summon and summon:FindFirstChild("Key", true)), T.SummonKey)
		local label = summon and summon:FindFirstChild("Label", true)
		check(res, "entry_summon_label", textOf(label), "Summon")
		local hud = h.find("RacerHud")
		local open = hud and hud:FindFirstChild("OpenTeam", true)
		check(res, "entry_minibar_open_team", open ~= nil and open:IsA("TextButton"), true)
		for name, action in T.Prompts do
			local prompt = workspace:FindFirstChild(name, true)
			check(res, "entry_prompt_" .. string.lower(name), prompt ~= nil and prompt:IsA("ProximityPrompt"), true)
			check(res, "entry_prompt_" .. string.lower(name) .. "_text", prompt and prompt.ActionText, action)
		end
		local altarModel = workspace:FindFirstChild("TeamAltar", true)
		check(res, "entry_team_altar_model", altarModel ~= nil and altarModel:IsA("Model"), true)

		local PanelSwitch = panelSwitch()
		local restore = h.setPanels({})
		local gui = player.PlayerGui:FindFirstChild(T.Transition)
		check(res, "entry_transition_gui", gui ~= nil and gui:IsA("ScreenGui"), true)
		check(res, "entry_transition_paper", gui ~= nil and gui:FindFirstChild("Paper", true) ~= nil, true)
		check(res, "entry_input_unlocked_at_rest", player:GetAttribute(T.InputLockAttr) == true, false)
		-- Two quick opens: the second is ignored while the first plays; Team ends open exactly once
		PanelSwitch.Action(T.PanelSwitchName)
		PanelSwitch.Action(T.PanelSwitchName)
		check(
			res,
			"entry_transition_plays_on_open",
			waitIs(function()
				return gui ~= nil and gui:GetAttribute("Playing") == true
			end, true, 0.5),
			true
		)
		task.wait(1)
		local panel = h.find(T.Panel)
		check(res, "entry_double_open_team_open", PanelSwitch.IsOpen(T.PanelSwitchName), true)
		check(res, "entry_double_open_panel_shown", shown(panel), true)
		check(
			res,
			"entry_input_locked_while_open",
			waitIs(function()
				return player:GetAttribute(T.InputLockAttr) == true
			end, true),
			true
		)
		PanelSwitch.Close(T.PanelSwitchName)
		check(
			res,
			"entry_input_unlocked_after_close",
			waitIs(function()
				return player:GetAttribute(T.InputLockAttr) == true
			end, false),
			false
		)
		check(
			res,
			"entry_team_closed",
			waitIs(function()
				return shown(h.find(T.Panel))
			end, false),
			false
		)
		restore()
	end

	-- After the real presses (UiSpec.Clicks team_*). Letters a / b / c = the team_states fixture's ids.
	local function savedIs(res, tag, letters, hold)
		local want = table.concat(idsOf(letters), ",")
		if hold then
			task.wait(T.Hold) -- a draft-only or refused change: the saved Team must still be the same afterwards
		end
		check(res, tag .. "_saved_team", waitIs(team, want), want)
	end
	local function draftIs(res, tag, letters, status, deployOn)
		local ids = idsOf(letters)
		checkDraft(res, tag, ids, status, deployOn)
		local wrong = waitIs(function()
			return #rosterProblems(ids) == 0
		end, true)
		h.checkList(res, tag .. "_roster_badges", wrong and {} or rosterProblems(ids))
	end
	-- A successful Deploy: the saved Team the server answered with, and the page closed.
	local function deployed(res, tag, want)
		check(res, tag .. "_saved_team", waitIs(team, want, SHOW_WAIT + T.DeployClose), want)
		check(
			res,
			tag .. "_page_closed",
			waitIs(function()
				return shown(h.find(T.Panel))
			end, false, T.DeployClose),
			false
		)
	end
	function after.team_dim_on(res)
		check(res, "team_open_dims_world", waitIs(dimOn, true), true)
	end
	function after.team_altar3_selected(res)
		local wrong = {}
		for n = 1, 3 do
			local a = altar(n)
			if (a and a:GetAttribute("Selected") == true) ~= (n == 3) then
				table.insert(wrong, "Altar" .. n .. " Selected " .. tostring(a and a:GetAttribute("Selected")))
			end
		end
		h.checkList(res, "team_altar3_selected", wrong)
		check(res, "team_select_empty_no_remove", shown(altar(3) and altar(3):FindFirstChild("Remove")), false)
	end
	function after.team_draft_abc(res)
		draftIs(res, "team_draft_abc", "abc", T.Unsaved, true)
		savedIs(res, "team_draft_abc", "ab", true)
	end
	function after.team_is_abc(res)
		deployed(res, "team_deploy_abc", table.concat(idsOf("abc"), ","))
	end
	function after.team_draft_ba(res)
		draftIs(res, "team_draft_ba", "ba", T.Unsaved, true)
		savedIs(res, "team_draft_ba", "ab", true)
	end
	function after.team_remove_shown(res)
		local remove = altar(2) and altar(2):FindFirstChild("Remove")
		check(res, "team_remove_shown", shown(remove) and textOf(remove), T.RemoveText)
	end
	function after.team_draft_b(res)
		draftIs(res, "team_draft_b", "b", T.Unsaved, true)
		savedIs(res, "team_draft_b", "ab", true)
	end
	function after.team_is_b(res)
		deployed(res, "team_deploy_b", table.concat(idsOf("b"), ","))
	end
	function after.team_draft_empty(res)
		checkDraft(res, "team_draft_empty", {}, T.Unsaved, false)
	end
	function after.team_empty_kept(res)
		savedIs(res, "team_empty", "ab", true)
		check(res, "team_empty_page_open", shown(h.find(T.Panel)), true)
	end
	function after.team_locked_in_run(res)
		savedIs(res, "team_run", "ab", true)
		checkDraft(res, "team_run_draft_kept", idsOf("abc"), T.RunNotice, nil)
		check(res, "team_run_page_open", shown(h.find(T.Panel)), true)
	end
	function after.team_draft_a(res)
		draftIs(res, "team_draft_a", "a", T.Unsaved, true)
	end
	function after.team_quick_filled(res)
		local a = idsOf("a")[1]
		local got = waitIs(function()
			local d = draftShown()
			return d[1] ~= nil and d[2] ~= nil and d[3] ~= nil
		end, true)
		local d = draftShown()
		local wrong = {}
		if not got then
			table.insert(wrong, ("draft %s, %s, %s: not filled"):format(tostring(d[1]), tostring(d[2]), tostring(d[3])))
		end
		if d[1] ~= a then
			table.insert(wrong, ("Altar1 %s, want %s kept"):format(tostring(d[1]), tostring(a)))
		end
		local seen, data = {}, player:FindFirstChild("GachaData")
		for n = 1, 3 do
			local id = d[n]
			if id and seen[id] then
				table.insert(wrong, "duplicate " .. id)
			end
			if id then
				seen[id] = true
			end
			if id and id ~= Catalog.STARTER_ID and not (data and data:FindFirstChild(id)) then
				table.insert(wrong, "unowned " .. id)
			end
		end
		h.checkList(res, "team_quick_fills_draft", wrong)
		quickDraft = { d[1], d[2], d[3] }
		checkDraft(res, "team_quick", quickDraft, T.Unsaved, true)
		savedIs(res, "team_quick", "ab", true)
	end
	function after.team_is_quick(res)
		deployed(res, "team_deploy_quick", quickDraft and table.concat(quickDraft, ",") or "no draft seen")
	end
	function after.team_confirm_shown(res)
		check(
			res,
			"team_confirm_close_shown",
			waitIs(function()
				return shown(h.find(T.ConfirmClose))
			end, true),
			true
		)
		check(res, "team_confirm_page_open", shown(h.find(T.Panel)), true)
		savedIs(res, "team_confirm", "ab", true)
	end
	-- 112999f: the question has a blocker behind it (ConfirmBlocker shown with ConfirmClose); Back (gamepad B, Escape:
	-- PanelSwitch.Back) closes the question first and keeps the page and the draft. The real key press is an eye check.
	local function blockerShown()
		return shown(h.find(T.Panel .. "/ConfirmBlocker"))
	end
	function after.team_confirm_back(res)
		local confirm = h.find(T.ConfirmClose)
		check(
			res,
			"team_back_confirm_shown",
			waitIs(function()
				return shown(confirm)
			end, true),
			true
		)
		check(res, "team_back_blocker_with_confirm", waitIs(blockerShown, true), true)
		panelSwitch().Back("Team")
		check(
			res,
			"team_back_hides_confirm",
			waitIs(function()
				return shown(confirm)
			end, false),
			false
		)
		check(res, "team_back_hides_blocker", waitIs(blockerShown, false), false)
		check(res, "team_back_keeps_page", shown(h.find(T.Panel)) and panelSwitch().IsOpen("Team"), true)
		savedIs(res, "team_back", "ab", true)
	end
	-- 112999f: asking for the Sidekicks page over a dirty draft asks Deploy / Discard first (Team stays open) ...
	function after.team_ask_sidekicks(res)
		panelSwitch().Toggle("Sidekicks")
		check(
			res,
			"team_ask_confirm_shown",
			waitIs(function()
				return shown(h.find(T.ConfirmClose))
			end, true),
			true
		)
		check(res, "team_ask_page_stays", shown(h.find(T.Panel)), true)
		check(res, "team_ask_sidekicks_not_yet", panelSwitch().IsOpen("Sidekicks"), false)
	end
	-- ... and Discard then opens the Sidekicks page that was asked for
	function after.team_discard_opens_sidekicks(res)
		check(
			res,
			"team_discard_then_sidekicks_open",
			waitIs(function()
				return panelSwitch().IsOpen("Sidekicks") and shown(h.find(T.SummonPanel))
			end, true),
			true
		)
		check(res, "team_discard_then_team_closed", shown(h.find(T.Panel)), false)
		savedIs(res, "team_discard_sidekicks", "ab", true)
	end
	function after.team_discarded(res)
		savedIs(res, "team_discard", "ab", true)
		check(res, "team_discard_page_closed", shown(h.find(T.Panel)), false)
	end
	function after.team_bonus_shown(res)
		local pop = h.find(T.BonusPopover)
		check(
			res,
			"team_bonus_popover_shown",
			waitIs(function()
				return shown(pop)
			end, true),
			true
		)
		check(res, "team_bonus_popover_no_bonus", textOf(pop and pop:FindFirstChild("Name")), T.NoBonus)
		check(res, "team_bonus_popover_effect", pop ~= nil and pop:FindFirstChild("Effect") ~= nil, true)
		local total = textOf(pop and pop:FindFirstChild("Total")) or ""
		check(res, "team_bonus_popover_total", string.match(total, "^Total [%d%.]+ s$") ~= nil, true)
		savedIs(res, "team_bonus", "ab", false)
	end
	function after.team_bonus_hidden(res)
		check(
			res,
			"team_bonus_popover_hidden",
			waitIs(function()
				return shown(h.find(T.BonusPopover))
			end, false),
			false
		)
	end
	local function tabActive(res, tag, active)
		for _, name in { "Characters", "Sidekicks" } do
			local tab = h.find(T.Tabs .. "/" .. name)
			check(res, tag .. "_" .. string.lower(name), tab and tab:GetAttribute("Active") == true, name == active)
		end
	end
	function after.team_tab_sidekicks_active(res)
		tabActive(res, "team_tab_sidekicks", "Sidekicks")
		local roster, wrong = h.find(T.Roster), {}
		for _, card in roster and roster:GetChildren() or {} do
			if card:IsA("GuiButton") and shown(card) and type(card:GetAttribute("SidekickId")) ~= "string" then
				table.insert(wrong, card.Name .. ": no SidekickId")
			end
		end
		h.checkList(res, "team_tab_sidekicks_cards", wrong)
	end
	function after.team_tab_characters_active(res)
		tabActive(res, "team_tab_characters", "Characters")
		local ids = idsOf("ab")
		h.checkList(res, "team_tab_characters_roster", rosterProblems(ids))
	end

	return { Scenarios = scenarios, After = after }
end

return Module
