--!nonstrict
-- Sidekick art wiring (design doc 4.36, 4.37; docs/SIDEKICK_SPEC.md). Owned by ui-test-writer.
-- ui_sidekicks judges models, Details odds, the Gem icons, the Index page and the desktop fit. Its fixture is
-- sidekick_states (UiScenarios.Needs). A press cannot be faked here, so the Bag art and the reveal are judged after the
-- real clicks sidekicks_bag_art and sidekicks_reveal_models.
-- Rotation (design doc 4.36, SIDEKICK_SPEC "Rotation"). Contract beyond the brief (implementer: report a change, do not loosen):
--   Banner holds one cell per Public id, named its id, and the mystery cell named Secret; anything else in it is RotationTimer.
--   RotationTimer is a TextLabel anywhere on the page, showing m:ss to EndsAt. DetailsSheet/List has a row per Public id and
--   one row named Secret; each has a label Odds reading "%.3f%%". Page and Details follow the attribute when the slot changes.
--   The attribute carries SecretId (owner ruling, for the Details silhouette); the banner's mystery tile still never shows it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SidekickConfig"))
local Art = require(Shared:WaitForChild("SidekickArt"))
local Spec = require(script.Parent.UiSpec)
local Client = script.Parent.Parent
local View = require(Client:WaitForChild("SidekickView"))
local Icons = require(Client:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
local HttpService = game:GetService("HttpService")

local PANEL = "RacerSidekicks/Panel"
local RIGHT = PANEL .. "/Body/Right"
local LEFT = PANEL .. "/Body/Left"
local WAIT = 5 -- s: model and bag art may arrive a moment after the panel opens
local PHONE_MAX_HEIGHT = 500
local MIN_CELL = 40 -- px at desktop: a banner model can still be told apart
local TIMER_SLACK = 3 -- s

local Module = {}

function Module.Build(h)
	local scenarios, after = {}, {}
	local function check(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local function waitFor(fn)
		local deadline = os.clock() + WAIT
		local value = fn()
		while value ~= nil and os.clock() < deadline do
			task.wait(0.1)
			value = fn()
		end
		return value
	end
	-- nil when `holder` shows a real model; a blank ViewportFrame is a problem too.
	local function modelProblem(holder)
		local viewport = holder and holder:FindFirstChild("Model", true)
		if not (viewport and viewport:IsA("ViewportFrame")) then
			return "no ViewportFrame Model"
		end
		if viewport:FindFirstChildWhichIsA("BasePart", true) == nil then
			return "ViewportFrame Model is empty"
		end
		return nil
	end
	local function allIds()
		local ids = {}
		for _, row in Config.List do
			table.insert(ids, row.Id)
		end
		for _, row in Config.BossDrops do
			table.insert(ids, row.Id)
		end
		return ids
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

	local function checkModelsFolder(res)
		local folder = ReplicatedStorage:FindFirstChild("SidekickModels")
		check(res, "sidekick_models_folder", folder ~= nil, true)
		for _, id in allIds() do
			local model = folder and folder:FindFirstChild(id)
			check(res, "sidekick_model_" .. id, model and model.ClassName or "missing", "Model")
			check(res, "sidekick_portrait_listed_" .. id, Art[id] ~= nil and Art[id].Portrait ~= nil, true)
		end
	end

	local function checkGemIcon(res, name, icon)
		check(res, name .. "_class", icon and icon.ClassName or "missing", "ImageLabel")
		check(res, name .. "_image", icon and icon:IsA("ImageLabel") and icon.Image or "missing", Icons.Gem.Image)
	end

	local function public()
		local raw = ReplicatedStorage:GetAttribute("SidekickRotation")
		local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
		return ok and type(value) == "table" and type(value.Ids) == "table" and value or nil
	end
	local function secretRows()
		local rows = {}
		for _, row in Config.List do
			if row.Rarity == "Secret" then
				table.insert(rows, row)
			end
		end
		return rows
	end
	local function bannerCells(banner)
		local cells = {}
		for _, child in banner:GetChildren() do
			if child:IsA("GuiObject") and child.Name ~= "RotationTimer" then
				table.insert(cells, child)
			end
		end
		return cells
	end

	-- The mystery tile: no model, no drawn face, no Secret's name; and no Secret's id anywhere in the banner.
	local function checkMystery(res, banner)
		local tile = banner:FindFirstChild("Secret")
		check(res, "sidekick_banner_mystery_present", tile ~= nil, true)
		if not tile then
			return
		end
		check(res, "sidekick_mystery_no_model", tile:FindFirstChildWhichIsA("ViewportFrame", true) == nil, true)
		for _, row in secretRows() do
			check(res, "sidekick_banner_hides_id_" .. row.Id, banner:FindFirstChild(row.Id, true) == nil, true)
			local shows = false
			for _, d in tile:GetDescendants() do
				shows = shows
					or (d:IsA("ImageLabel") and d.Image == Art[row.Id].Portrait)
					or ((d:IsA("TextLabel") or d:IsA("TextButton")) and string.find(d.Text, row.Name, 1, true) ~= nil)
			end
			check(res, "sidekick_mystery_hides_" .. row.Id, shows, false)
		end
	end

	local function checkBanner(res)
		local banner = h.find(RIGHT .. "/Banner")
		check(res, "sidekick_banner_present", banner ~= nil, true)
		local view = public()
		check(res, "sidekick_rotation_attribute_readable", view ~= nil, true)
		if not (banner and view) then
			return
		end
		check(res, "sidekick_banner_cells_are_the_rotation", #bannerCells(banner), #view.Ids + 1)
		for _, row in Config.BossDrops do
			check(res, "sidekick_banner_no_boss_drop_" .. row.Id, banner:FindFirstChild(row.Id, true) == nil, true)
		end
		for _, row in Config.List do
			if row.Rarity ~= "Secret" and not table.find(view.Ids, row.Id) then
				check(res, "sidekick_banner_out_of_rotation_" .. row.Id, banner:FindFirstChild(row.Id) == nil, true)
			end
		end
		for _, id in view.Ids do
			local problem = waitFor(function()
				return modelProblem(banner:FindFirstChild(id))
			end)
			check(res, "sidekick_banner_model_" .. id, problem or "shown", "shown")
		end
		checkMystery(res, banner)
	end

	local function checkTimer(res, page)
		local timer = page:FindFirstChild("RotationTimer", true)
		check(res, "sidekick_timer_present", timer ~= nil and timer:IsA("TextLabel"), true)
		local view = public()
		if not (timer and timer:IsA("TextLabel") and view) then
			return
		end
		check(res, "sidekick_timer_shown", h.visible(timer), true)
		local function seconds()
			local minutes, rest = string.match(timer.Text, "(%d+):(%d%d)")
			return minutes and tonumber(minutes) * 60 + tonumber(rest) or nil
		end
		local got = seconds()
		local want = view.EndsAt - workspace:GetServerTimeNow()
		h.check(
			res,
			"sidekick_timer_counts_to_slot_end",
			got or timer.Text,
			("%d +- %d"):format(want, TIMER_SLACK),
			got ~= nil and math.abs(got - want) <= TIMER_SLACK
		)
		local text = timer.Text
		task.wait(2.1)
		check(res, "sidekick_timer_ticks", timer.Text ~= text, true)
	end

	-- The slot turns while the page is open: tiles and Details follow, with nobody reopening it.
	local function checkSlotChange(res)
		local request = ReplicatedStorage:FindFirstChild("UiTestSetupRequest")
		local banner, list = h.find(RIGHT .. "/Banner"), h.find(PANEL .. "/Body/DetailsSheet/List")
		check(res, "sidekick_slot_change_parts", request ~= nil and banner ~= nil and list ~= nil, true)
		local function mythic()
			for _, id in (public() or { Ids = {} }).Ids do
				if Config.Get(id).Rarity == "Mythic" then
					return id
				end
			end
			return nil
		end
		local before = mythic()
		if not (request and banner and list and before) then
			return
		end
		request:InvokeServer("sidekick_ui_clock:next")
		local nextMythic = before
		local problem = waitFor(function()
			nextMythic = mythic()
			if nextMythic == before then
				return "attribute did not change"
			end
			if banner:FindFirstChild(before) or list:FindFirstChild(before) then
				return "old Mythic still shown"
			end
			if not list:FindFirstChild(nextMythic) then
				return "new Mythic not in Details"
			end
			return modelProblem(banner:FindFirstChild(nextMythic))
		end)
		check(res, "sidekick_slot_change_followed", problem or "followed", "followed")
		checkMystery(res, banner)
		request:InvokeServer("sidekick_ui_clock:real")
		local back = waitFor(function()
			return not banner:FindFirstChild(before) and "old Mythic not back"
				or modelProblem(banner:FindFirstChild(before))
		end)
		check(res, "sidekick_slot_change_back", back or "back", "back")
	end

	-- Section 6: every summon outcome, read from the shown labels, sums to 100%.
	local function checkDetails(res)
		check(res, "sidekick_details_button_shown", h.visible(h.find(LEFT .. "/Details")), true)
		local list = h.find(PANEL .. "/Body/DetailsSheet/List")
		check(res, "sidekick_details_present", list ~= nil, true)
		if not list then
			return
		end
		local view = public()
		if not view then
			return -- sidekick_rotation_attribute_readable already failed
		end
		-- What the player must see, from the replicated view alone: listed odds, the rest split across Commons.
		local secrets = secretRows()
		local secretOdds = secrets[1] and secrets[1].Odds or 0
		local rest, commons = 100 - secretOdds, 0
		for _, id in view.Ids do
			local row = Config.Get(id)
			rest -= row.Odds
			commons += row.Rarity == "Common" and 1 or 0
		end
		local sum = 0
		local function shownOdds(name, want)
			local line = list:FindFirstChild(name)
			local odds = line and line:FindFirstChild("Odds")
			check(res, "sidekick_details_odds_" .. name, odds and odds.Text or "missing", string.format("%.3f%%", want))
			sum += odds and tonumber(string.match(odds.Text, "^(%d+%.%d%d%d)%%$")) or 0
		end
		for _, id in view.Ids do
			local row = Config.Get(id)
			shownOdds(id, row.Odds + (row.Rarity == "Common" and rest / commons or 0))
		end
		shownOdds("Secret", secretOdds)
		local rounding = 0.0005 * (#view.Ids + 1) + 1e-6
		h.check(res, "sidekick_details_sum_100", sum, "100 +- " .. rounding, math.abs(sum - 100) <= rounding)
		local liveIsAChoice = false
		for _, row in secrets do
			liveIsAChoice = liveIsAChoice or row.Id == view.SecretId
		end
		check(res, "sidekick_view_secret_id_is_a_choice", liveIsAChoice, true)
		-- The Secret row names every outcome (section 6); its text does not tell which one is live.
		local secretLine = list:FindFirstChild("Secret")
		local words = {}
		for _, d in secretLine and secretLine:GetDescendants() or {} do
			if d:IsA("TextLabel") then
				table.insert(words, d.Text)
			end
		end
		local text = table.concat(words, " ")
		for _, row in secrets do
			check(res, "sidekick_details_secret_names_" .. row.Id, string.find(text, row.Name, 1, true) ~= nil, true)
			check(res, "sidekick_details_hides_id_" .. row.Id, list:FindFirstChild(row.Id, true) == nil, true)
		end
		for _, row in Config.List do
			if row.Rarity ~= "Secret" and not table.find(view.Ids, row.Id) then
				check(res, "sidekick_details_out_of_rotation_" .. row.Id, list:FindFirstChild(row.Id) == nil, true)
			end
		end
		local total = list:FindFirstChild("Total")
		check(res, "sidekick_details_total_text", total and total.Text or "missing", "Total: 100%")
		for _, row in Config.BossDrops do
			check(res, "sidekick_details_no_boss_drop_" .. row.Id, list:FindFirstChild(row.Id) == nil, true)
		end
	end

	local function checkDesktopFit(res)
		local size = workspace.CurrentCamera.ViewportSize
		if size.Y <= PHONE_MAX_HEIGHT then
			return -- this scenario judges the fit at desktop only
		end
		local screen = { x = 0, y = 0, w = size.X, h = size.Y }
		local panel = h.find(PANEL)
		local body = h.find(PANEL .. "/Body")
		check(res, "sidekick_page_parts_present", panel ~= nil and body ~= nil, true)
		if not (panel and body) then
			return
		end
		local panelRect, bodyRect = h.rect(panel), h.rect(body)
		check(res, "sidekick_panel_on_screen_desktop", within(screen, panelRect), true)
		check(res, "sidekick_body_in_panel_desktop", within(panelRect, bodyRect), true)
		local parts = {}
		for _, path in
			{
				LEFT .. "/Packs",
				LEFT .. "/Details",
				LEFT .. "/Settings",
				RIGHT .. "/Banner",
				RIGHT .. "/Balance",
				RIGHT .. "/Status",
				RIGHT .. "/Summon1",
				RIGHT .. "/Summon10",
			}
		do
			local part = h.find(path)
			check(res, "sidekick_part_present_" .. path, part ~= nil, true)
			if part then
				table.insert(parts, part)
			end
		end
		local banner, timer = h.find(RIGHT .. "/Banner"), panel:FindFirstChild("RotationTimer", true)
		if timer then
			table.insert(parts, timer)
		end
		local outside, overlaps, covered = {}, {}, {}
		-- 9 cells where 3 were: each stays in the banner, clear of the others and of the timer.
		local cellsOutside, cellsCrossing, cellsSmall = {}, {}, {}
		local cells = banner and bannerCells(banner) or {}
		local bannerRect = banner and h.rect(banner)
		for i, cell in cells do
			local r = h.rect(cell)
			if not within(bannerRect, r) then
				table.insert(cellsOutside, cell.Name)
			end
			if r.w < MIN_CELL or r.h < MIN_CELL then
				table.insert(cellsSmall, cell.Name)
			end
			for j = i + 1, #cells do
				if crossing(r, h.rect(cells[j])) then
					table.insert(cellsCrossing, cell.Name .. " x " .. cells[j].Name)
				end
			end
			if timer and not cell:IsAncestorOf(timer) and crossing(r, h.rect(timer)) then
				table.insert(cellsCrossing, cell.Name .. " x RotationTimer")
			end
		end
		h.checkList(res, "sidekick_banner_cells_in_banner_desktop", cellsOutside)
		h.checkList(res, "sidekick_banner_cells_no_overlap_desktop", cellsCrossing)
		h.checkList(res, "sidekick_banner_cells_big_enough_desktop", cellsSmall)
		for i, part in parts do
			local r = h.rect(part)
			if not within(bodyRect, r) then
				table.insert(outside, h.pathOf(part))
			end
			for j = i + 1, #parts do
				if not part:IsAncestorOf(parts[j]) and crossing(r, h.rect(parts[j])) then
					table.insert(overlaps, part.Name .. " x " .. parts[j].Name)
				end
			end
			if part:IsA("GuiButton") then
				local top = h.topAt(r.x + r.w / 2, r.y + r.h / 2)
				if not (top and (top == part or part:IsAncestorOf(top))) then
					table.insert(covered, part.Name .. " under " .. (top and h.pathOf(top) or "nothing"))
				end
			end
		end
		h.checkList(res, "sidekick_parts_in_body_desktop", outside)
		h.checkList(res, "sidekick_parts_no_overlap_desktop", overlaps)
		h.checkList(res, "sidekick_buttons_topmost_desktop", covered)
	end

	local function checkIndex(res)
		local panel = h.find("RacerIndex/Panel")
		local tab = panel and panel:FindFirstChild("SidekicksTab", true)
		check(res, "sidekick_index_tab_present", tab ~= nil, true)
		check(res, "sidekick_index_tab_shown", tab ~= nil and h.visible(tab), true)
		if not panel then
			return
		end
		local lastOrder = -math.huge
		for _, id in allIds() do
			local tile = panel:FindFirstChild(id, true)
			check(res, "sidekick_index_lists_" .. id, tile ~= nil, true)
			if tile and tile:IsA("GuiObject") then
				check(res, "sidekick_index_order_" .. id, tile.LayoutOrder > lastOrder, true)
				lastOrder = tile.LayoutOrder
				local portrait = false
				for _, d in tile:GetDescendants() do
					portrait = portrait or (d:IsA("ImageLabel") and d.Image == Art[id].Portrait)
				end
				check(res, "sidekick_index_portrait_" .. id, portrait, true) -- SIDEKICK_SPEC: portraits in the index
			end
		end
	end

	function scenarios.ui_sidekicks(res)
		h.waitGuis()
		check(res, "sidekick_rotation_not_on_client", ReplicatedStorage:FindFirstChild("SidekickRotation", true), nil)
		checkModelsFolder(res)
		checkGemIcon(res, "sidekick_hud_gem_icon", h.find("RacerHud/Gems/GemIcon"))
		local page = h.find(PANEL)
		check(res, "sidekick_panel_present", page ~= nil, true)
		if not page then
			return
		end
		local restore = h.setPanels({ PANEL })
		checkGemIcon(res, "sidekick_page_gem_icon", page:FindFirstChild("GemIcon", true))
		checkBanner(res)
		checkTimer(res, page)
		checkDetails(res)
		checkDesktopFit(res)
		checkSlotChange(res)
		restore()
		restore = h.setPanels({ "RacerIndex/Panel" })
		checkIndex(res)
		restore()
	end

	-- After the Backpack's real Sidekicks tab click: each Bag entry's tile shows that Sidekick's portrait.
	function after.sidekicks_bag_art(res)
		local bag = View.Bag(h.player)
		check(res, "sidekick_bag_fixture_filled", #bag, #Config.List + #Config.BossDrops)
		local items = h.find("RacerBackpack/Panel/Items")
		for _, item in bag do
			local got = nil
			waitFor(function()
				local tile = items and items:FindFirstChild(item.Entry)
				local art = tile and tile:FindFirstChild("Art")
				got = art and art:IsA("ImageLabel") and art.Image or "no ImageLabel Art"
				return got ~= Art[item.Id].Portrait and got or nil
			end)
			check(res, "sidekick_bag_art_" .. item.Id, got, Art[item.Id].Portrait)
		end
	end

	-- After a real Summon 1x press: the reveal shows a model, never only a name tile.
	function after.sidekicks_reveal_models(res)
		local reveal = h.find(RIGHT .. "/Reveal")
		local problem = waitFor(function()
			if not (reveal and h.visible(reveal)) then
				return "reveal not shown"
			end
			return modelProblem(reveal:FindFirstChild("Result1", true))
		end)
		check(res, "sidekick_reveal_model", problem or "shown", "shown")
	end

	return { Scenarios = scenarios, After = after }
end

return Module
