--!nonstrict
-- Backpack Relics tab (design doc 4.38, docs/RELIC_SPEC.md). Owned by ui-test-writer.
-- ui_relics judges what stands without a press: the tab, the action row's buttons, no Sell (reading: no rule gives Relics a
-- value) and the fixture relic_states (UiScenarios.Needs). A press cannot be faked here, so the tiles, the worn marks and
-- equip are judged after the real clicks in UiSpec.Clicks (relics_tab, relics_equip, relics_take_off, relics_character_badge).
-- Tab order, labels, count and phone fit: ui_backpack_characters reads UiSpec.Backpack.TabOrder at both sizes.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("RelicConfig"))
local Spec = require(script.Parent.UiSpec)

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
	local function crossing(a, b)
		local t = Spec.Tolerance
		return a.x + a.w > b.x + t and b.x + b.w > a.x + t and a.y + a.h > b.y + t and b.y + b.h > a.y + t
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
		local row = h.find(B.RelicActions)
		check(res, "relic_actions_present", row ~= nil, true)
		for _, name in B.RelicButtons do
			local button = row and row:FindFirstChild(name)
			check(res, "relic_action_" .. name, button ~= nil and button:IsA("GuiButton"), true)
		end
		check(res, "reading_relic_actions_no_sell", row ~= nil and row:FindFirstChild("Sell") == nil, true)
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
			local worn = tile and tile:FindFirstChild("Worn")
			local isWorn = wearerOf(gear, item.Entry) ~= nil
			check(res, "relic_worn_mark_" .. item.Id, worn ~= nil and h.visible(worn), isWorn)
			if worn then
				check(res, "relic_worn_text_" .. item.Id, worn.Text, "WORN")
			end
		end

		local panel, row = h.find(B.Panel), h.find(B.RelicActions)
		check(res, "relic_actions_shown", row ~= nil and h.visible(row), true)
		local sidekickRow = h.find(B.Panel .. "/SidekickActions")
		check(res, "relic_tab_hides_sidekick_row", sidekickRow ~= nil and h.visible(sidekickRow), false)
		local slots = h.find(B.Slots)
		check(res, "relic_tab_hides_slots", slots ~= nil and h.visible(slots), false)
		if not (panel and row and items) then
			return
		end
		local variant = workspace.CurrentCamera.ViewportSize.Y <= B.PhoneMaxHeight and "_phone" or "_desktop"
		local panelRect, gridRect = h.rect(panel), h.rect(items)
		local outside, overlaps, covered = {}, {}, {}
		for i, name in B.RelicButtons do
			local button = row:FindFirstChild(name)
			if button then
				local r = h.rect(button)
				if not within(panelRect, r) then
					table.insert(outside, name)
				end
				if crossing(r, gridRect) then
					table.insert(overlaps, name .. " x Items")
				end
				for j = i + 1, #B.RelicButtons do
					local other = row:FindFirstChild(B.RelicButtons[j])
					if other and crossing(r, h.rect(other)) then
						table.insert(overlaps, name .. " x " .. other.Name)
					end
				end
				local top = h.topAt(r.x + r.w / 2, r.y + r.h / 2)
				if not (top and (top == button or button:IsAncestorOf(top))) then
					table.insert(covered, name .. " under " .. (top and h.pathOf(top) or "nothing"))
				end
			end
		end
		h.checkList(res, "relic_actions_in_panel" .. variant, outside)
		h.checkList(res, "relic_actions_no_overlap" .. variant, overlaps)
		h.checkList(res, "relic_actions_topmost" .. variant, covered)
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
