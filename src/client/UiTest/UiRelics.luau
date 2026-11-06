--!nonstrict
-- Backpack Relics tab (design doc 4.38, docs/RELIC_SPEC.md). Owned by ui-test-writer.
-- ui_relics judges what stands without a press: the tab, the Index page, Client/ItemMenu's parts, the old action rows gone (owner
-- 2026-11-05: tiles open the click menu, design doc 4.36, 4.38), and the fixture relic_states (UiScenarios.Needs). A press cannot be
-- faked here, so the tiles, the menu, equip and sale are judged after the real clicks in UiSpec.Clicks (relics_*, sidekicks_menu_*,
-- index_relics_*, backpack_mass_*, backpack_sell_spares*).
-- Tab order, labels, count and phone fit: ui_backpack_characters reads UiSpec.Backpack.TabOrder at both sizes.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
local Config = require(Shared:WaitForChild("RelicConfig"))
local Spec = require(script.Parent.UiSpec)

local MENU = "RacerItemMenu"
local WAIT = 5 -- s: the bag renders after the attribute arrives
local B = Spec.Backpack

local Module = {}

function Module.Build(h)
	local scenarios, after = {}, {}
	local function check(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local function decode(attribute)
		local raw = h.player:GetAttribute(attribute)
		return type(raw) == "string" and HttpService:JSONDecode(raw) or {}
	end
	-- Polls until `fn` returns nil; returns the last value.
	local function waitFor(fn)
		local deadline = os.clock() + WAIT
		local value = fn()
		while value ~= nil and os.clock() < deadline do
			task.wait(0.1)
			value = fn()
		end
		return value
	end
	local function within(outer, r)
		local t = Spec.Tolerance
		return r.x >= outer.x - t
			and r.y >= outer.y - t
			and r.x + r.w <= outer.x + outer.w + t
			and r.y + r.h <= outer.y + outer.h + t
	end
	local function showsText(holder, text)
		for _, d in holder:GetDescendants() do
			if d:IsA("TextLabel") and string.upper(d.Text) == string.upper(text) then
				return true
			end
		end
		return false
	end
	local function wearerOf(gear, entry)
		for character, worn in gear do
			if worn == entry then
				return character
			end
		end
		return nil
	end

	function scenarios.ui_relics(res)
		h.waitGuis()
		local want = #Config.Bosses.big_raga
		check(res, "relic_fixture_filled", #decode("RelicBag"), want)
		local restore = h.setPanels({ B.Panel })
		local tab = h.find(B.Tabs .. "/RelicsTab")
		check(res, "relic_tab_present", tab ~= nil, true)
		check(res, "relic_tab_shown", tab ~= nil and h.visible(tab), true)
		check(res, "relic_tab_last", B.TabOrder[#B.TabOrder], "Relics")
		check(res, "relic_actions_gone", h.find(B.Panel .. "/RelicActions"), nil)
		check(res, "sidekick_actions_gone", h.find(B.Panel .. "/SidekickActions"), nil)
		for _, path in { "Scrim", "Menu/Equip", "Menu/Sell", "Confirm/Yes", "Confirm/Cancel", "Picker/Close" } do
			local button = h.find(MENU .. "/" .. path)
			check(res, "item_menu_part_" .. path, button ~= nil and button:IsA("GuiButton"), true)
		end
		for _, name in { "Less", "More", "Max" } do
			local button = h.find(MENU .. "/Confirm/Stepper/" .. name)
			check(res, "item_menu_stepper_" .. name, button ~= nil and button:IsA("GuiButton"), true)
		end
		check(res, "item_menu_grid_present", h.find(MENU .. "/Picker/Characters") ~= nil, true)
		local menu = h.find(MENU)
		check(res, "item_menu_hidden_at_rest", menu ~= nil and menu.Enabled, false)
		local index = h.find("RacerIndex/Panel")
		local indexTab = index and index:FindFirstChild("RelicsTab", true)
		check(res, "relic_index_tab_present", indexTab ~= nil, true)
		local page = index and index:FindFirstChild("RelicsPage", true)
		check(res, "relic_index_page_present", page ~= nil, true)
		for _, row in Config.Bosses.big_raga do
			local tile = page and page:FindFirstChild(row.Id)
			check(res, "relic_index_tile_" .. row.Id, tile ~= nil and tile:IsA("GuiButton"), true)
		end
		restore()
	end

	-- After the Backpack's real Relics tab click: one tile per bag entry, its name on it, WORN on the worn one only.
	function after.relics_tab(res)
		local items = h.find(B.Items)
		local bag, gear = decode("RelicBag"), decode("RelicGear")
		check(res, "relic_bag_fixture_filled", #bag, #Config.Bosses.big_raga)
		check(res, "relic_fixture_one_worn", next(gear) ~= nil, true)
		for _, item in bag do
			local row = Config.Get(item.Id)
			local problem = waitFor(function()
				local tile = items and items:FindFirstChild(item.Entry)
				if not tile then
					return "no tile"
				end
				return not showsText(tile, row.Name) and "no name" or nil
			end)
			check(res, "relic_tile_" .. item.Id, problem or "shown", "shown")
			local tile = items and items:FindFirstChild(item.Entry)
			if row.Image then
				local art = tile and tile:FindFirstChild("Art")
				check(res, "relic_art_" .. item.Id, art and art.Image, row.Image)
			end
			local worn = tile and tile:FindFirstChild("Worn")
			local isWorn = wearerOf(gear, item.Entry) ~= nil
			check(res, "relic_worn_mark_" .. item.Id, worn ~= nil and h.visible(worn), isWorn)
			if worn then
				check(res, "relic_worn_text_" .. item.Id, worn.Text, "WORN")
			end
		end

		local slots = h.find(B.Slots)
		check(res, "relic_tab_hides_slots", slots ~= nil and h.visible(slots), false)
		local notButtons = {}
		for _, item in bag do
			local tile = items and items:FindFirstChild(item.Entry)
			if tile and not tile:IsA("GuiButton") then
				table.insert(notButtons, item.Entry)
			end
		end
		h.checkList(res, "relic_tiles_are_buttons", notButtons)
	end

	-- Client/ItemMenu after a real press: on screen and on top.
	local function menuPartsShown(res, tag, frame, parts)
		local box = h.find(MENU .. "/" .. frame)
		check(res, tag .. "_shown", box ~= nil and h.visible(box), true)
		if not (box and h.visible(box)) then
			return
		end
		local view = workspace.CurrentCamera.ViewportSize
		check(res, tag .. "_on_screen", within({ x = 0, y = 0, w = view.X, h = view.Y }, h.rect(box)), true)
		for _, name in parts do
			local button = box:FindFirstChild(name)
			local r = button and h.rect(button)
			local top = r and h.topAt(r.x + r.w / 2, r.y + r.h / 2)
			check(res, tag .. "_topmost_" .. name, top ~= nil and (top == button or button:IsAncestorOf(top)), true)
		end
	end
	local function partText(path)
		local part = h.find(MENU .. "/" .. path)
		return part and part.Text or ""
	end
	function after.item_menu_shown(res)
		menuPartsShown(res, "item_menu", "Menu", { "Equip", "Sell" })
	end
	-- An unworn entry: Equip, and Sell with its price, both live.
	function after.item_menu_free(res)
		after.item_menu_shown(res)
		check(res, "item_menu_equip_text", partText("Menu/Equip"), "Equip")
		local sell = h.find(MENU .. "/Menu/Sell")
		check(res, "item_menu_sell_live", sell ~= nil and sell.Active, true)
		check(res, "item_menu_sell_price", string.match(partText("Menu/Sell"), "^Sell .+") ~= nil, true)
		local note = h.find(MENU .. "/Menu/Note")
		check(res, "item_menu_no_note", note ~= nil and h.visible(note), false)
	end
	-- A worn entry: Take off; Sell disabled, with the reason.
	function after.item_menu_worn(res)
		after.item_menu_shown(res)
		check(res, "item_menu_take_off_text", partText("Menu/Equip"), "Take off")
		local sell = h.find(MENU .. "/Menu/Sell")
		check(res, "item_menu_sell_disabled", sell ~= nil and sell.Active, false)
		local note = h.find(MENU .. "/Menu/Note")
		check(res, "item_menu_note_shown", note ~= nil and h.visible(note), true)
		check(res, "item_menu_note_text", note and note.Text, "Take it off first")
	end
	-- A press on the disabled Sell sells nothing.
	function after.item_menu_stays(res)
		after.item_menu_shown(res)
		check(res, "item_menu_worn_stays_worn", next(decode("RelicGear")) ~= nil, true)
		check(res, "item_menu_worn_keeps_bag", #decode("RelicBag"), #Config.Bosses.big_raga)
		local confirm = h.find(MENU .. "/Confirm")
		check(res, "item_menu_no_confirm_for_worn", confirm ~= nil and h.visible(confirm), false)
	end
	-- One card per owned character, each with its name; none is sold or worn by opening it.
	function after.item_picker_shown(res)
		menuPartsShown(res, "item_picker", "Picker", { "Close" })
		local data = h.player:FindFirstChild("GachaData")
		local grid = h.find(MENU .. "/Picker/Characters")
		local missing, cards = {}, 0
		for _, entry in data and data:GetChildren() or {} do
			if not (grid and grid:FindFirstChild(entry.Name)) and CharacterCatalog.Get(entry.Name) then
				table.insert(missing, entry.Name)
			end
		end
		for _, card in grid and grid:GetChildren() or {} do
			cards += card:IsA("GuiButton") and 1 or 0
		end
		h.checkList(res, "item_picker_lists_owned", missing)
		check(res, "item_picker_has_cards", cards > 0, true)
		check(res, "item_picker_opening_equips_nothing", next(decode("RelicGear")), nil)
	end
	function after.item_confirm_shown(res)
		menuPartsShown(res, "item_confirm", "Confirm", { "Yes", "Cancel" })
		check(
			res,
			"item_confirm_asks",
			string.find(partText("Confirm/Question"), "Are you sure you want to sell", 1, true) ~= nil,
			true
		)
		local menu = h.find(MENU .. "/Menu")
		check(res, "item_confirm_replaces_menu", menu ~= nil and h.visible(menu), false)
	end
	-- Sell spares: how many, from all of them down to 1 (design doc 4.41).
	function after.item_stepper_shown(res)
		after.item_confirm_shown(res)
		local stepper = h.find(MENU .. "/Confirm/Stepper")
		check(res, "item_stepper_shown", stepper ~= nil and h.visible(stepper), true)
		check(res, "item_stepper_starts_at_all", partText("Confirm/Stepper/Count"), "2 / 2")
		check(
			res,
			"item_stepper_question",
			string.find(partText("Confirm/Question"), "2 copies of", 1, true) ~= nil,
			true
		)
	end
	function after.item_menu_closed(res)
		local menu = h.find(MENU)
		check(res, "item_menu_closed", menu ~= nil and menu.Enabled, false)
	end
	-- Index Relics page: its tab shows it alone, with a tile per Relic, and the progress line reads the owned count.
	function after.index_relics_page(res)
		local gui = h.find("RacerIndex")
		check(res, "index_relics_tab_state", gui and gui:GetAttribute("InventoryTab"), "Relics")
		local panel = h.find("RacerIndex/Panel")
		local page = panel and panel:FindFirstChild("RelicsPage", true)
		check(res, "index_relics_page_shown", page ~= nil and h.visible(page), true)
		local gallery = panel and panel:FindFirstChild("Gallery", true)
		check(res, "index_relics_hides_gallery", gallery ~= nil and h.visible(gallery), false)
		local sidekicks = panel and panel:FindFirstChild("SidekicksPage", true)
		check(res, "index_relics_hides_sidekicks", sidekicks ~= nil and h.visible(sidekicks), false)
		local total = #Config.Bosses.big_raga
		check(
			res,
			"index_relics_progress",
			gui and gui:GetAttribute("RelicsProgress"),
			("%d / %d OWNED"):format(total, total)
		)
		local owned = {}
		for _, row in Config.Bosses.big_raga do
			local tile = page and page:FindFirstChild(row.Id)
			if not (tile and tile:GetAttribute("Owned") == true) then
				table.insert(owned, row.Id)
			end
		end
		h.checkList(res, "index_relics_tiles_owned", owned)
	end
	-- A real sale from relic_states_bare: paid for by the server's sell section; here the entry goes and the dialog closes.
	function after.relics_sold(res)
		local want = #Config.Bosses.big_raga - 1
		local left = waitFor(function()
			return #decode("RelicBag") ~= want and #decode("RelicBag") or nil
		end)
		check(res, "relic_sale_reached_server", left == nil, true)
		after.item_menu_closed(res)
	end
	-- Select mode (design doc 4.41).
	local function massBar()
		return h.find(B.Panel .. "/MassBar")
	end
	function after.mass_mode_shown(res)
		local bar = massBar()
		check(res, "mass_bar_shown", bar ~= nil and h.visible(bar), true)
		check(res, "mass_hides_slots", h.visible(h.find(B.Slots)), false)
		local spares = h.find(B.Panel .. "/SellSpares")
		check(res, "mass_hides_sell_spares", spares ~= nil and h.visible(spares), false)
		local sell = bar and bar:FindFirstChild("Sell")
		check(res, "mass_sell_needs_a_pick", sell ~= nil and sell.Active, false)
		for _, name in { "SelectAll", "Sell", "Cancel" } do
			local button = bar and bar:FindFirstChild(name)
			check(res, "mass_bar_part_" .. name, button ~= nil and h.visible(button), true)
		end
	end
	function after.mass_all_selected(res)
		local items = h.find(B.Items)
		local picked = 0
		for _, card in items and items:GetChildren() or {} do
			local mark = card:FindFirstChild("Picked")
			picked += mark and h.visible(mark) and 1 or 0
		end
		check(res, "mass_all_marks_cards", picked > 0, true)
		local bar = massBar()
		local sell = bar and bar:FindFirstChild("Sell")
		check(res, "mass_sell_live_after_all", sell ~= nil and sell.Active, true)
		check(res, "mass_sell_shows_total", sell ~= nil and string.find(sell.Text, "+$", 1, true) ~= nil, true)
	end
	function after.mass_mode_left(res)
		local bar = massBar()
		check(res, "mass_bar_gone", bar ~= nil and h.visible(bar), false)
		local items = h.find(B.Items)
		local marks = {}
		for _, card in items and items:GetChildren() or {} do
			if card:FindFirstChild("Picked") then
				table.insert(marks, card.Name)
			end
		end
		h.checkList(res, "mass_marks_gone", marks)
	end

	-- After a real Equip press from relic_states_bare: the bag's first entry sits on a character, and its tile says so.
	function after.relics_equip(res)
		local bag, wearer = decode("RelicBag"), nil
		local first = bag[1] and bag[1].Entry
		waitFor(function()
			wearer = first and wearerOf(decode("RelicGear"), first)
			return not wearer and "waiting" or nil
		end)
		check(res, "relic_equip_reached_server", wearer ~= nil, true)
		local problem = waitFor(function()
			local tile = first and h.find(B.Items .. "/" .. first)
			local worn = tile and tile:FindFirstChild("Worn")
			return not (worn and h.visible(worn)) and "no worn mark" or nil
		end)
		check(res, "relic_equip_marks_tile", problem or "shown", "shown")
	end

	-- After a real Take off press from relic_states: nothing is worn and the entry stays in the bag.
	function after.relics_take_off(res)
		local count = #decode("RelicBag")
		local left = waitFor(function()
			return next(decode("RelicGear"))
		end)
		check(res, "relic_take_off_reached_server", left == nil, true)
		check(res, "relic_take_off_keeps_entry", #decode("RelicBag"), count)
		check(res, "relic_take_off_keeps_all", count, #Config.Bosses.big_raga)
	end

	-- After the Characters tab click from relic_states: the wearer's card carries the Relic's name.
	function after.relics_character_badge(res)
		local bag, gear = decode("RelicBag"), decode("RelicGear")
		local character, entry = next(gear)
		check(res, "relic_badge_fixture_worn", character ~= nil, true)
		if not character then
			return
		end
		local name = nil
		for _, item in bag do
			if item.Entry == entry then
				name = Config.Get(item.Id).Name
			end
		end
		local got = nil
		waitFor(function()
			local tile = h.find(B.Items .. "/" .. character)
			local badge = tile and tile:FindFirstChild("RelicBadge")
			got = badge and badge.Text or "no RelicBadge"
			return got ~= name and got or nil
		end)
		check(res, "relic_badge_names_relic", got, name)
	end

	return { Scenarios = scenarios, After = after }
end

return Module
