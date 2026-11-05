--!nonstrict
-- Sidekick art wiring (design doc 4.36, 4.37; docs/SIDEKICK_SPEC.md). Owned by ui-test-writer.
-- ui_sidekicks judges models, Details odds, the Gem icons, the Index page and the desktop fit. Its fixture is
-- sidekick_states (UiScenarios.Needs). A press cannot be faked here, so the Bag art and the reveal are judged after the
-- real clicks sidekicks_bag_art and sidekicks_reveal_models.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SidekickConfig"))
local Art = require(Shared:WaitForChild("SidekickArt"))
local Spec = require(script.Parent.UiSpec)
local Client = script.Parent.Parent
local View = require(Client:WaitForChild("SidekickView"))
local Icons = require(Client:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))

local PANEL = "RacerSidekicks/Panel"
local RIGHT = PANEL .. "/Body/Right"
local LEFT = PANEL .. "/Body/Left"
local WAIT = 5 -- s: model and bag art may arrive a moment after the panel opens
local PHONE_MAX_HEIGHT = 500

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

	local function checkBanner(res)
		local banner = h.find(RIGHT .. "/Banner")
		check(res, "sidekick_banner_present", banner ~= nil, true)
		if not banner then
			return
		end
		local cells = 0
		for _, child in banner:GetChildren() do
			if child:IsA("GuiObject") then
				cells += 1
			end
		end
		check(res, "sidekick_banner_cells_are_the_pool", cells, #Config.List)
		for _, row in Config.BossDrops do
			check(res, "sidekick_banner_no_boss_drop_" .. row.Id, banner:FindFirstChild(row.Id, true) == nil, true)
		end
		for _, row in Config.List do
			local problem = waitFor(function()
				return modelProblem(banner:FindFirstChild(row.Id))
			end)
			check(res, "sidekick_banner_model_" .. row.Id, problem or "shown", "shown")
		end
	end

	-- Section 6: every summon outcome, read from the shown labels, sums to 100%.
	local function checkDetails(res)
		check(res, "sidekick_details_button_shown", h.visible(h.find(LEFT .. "/Details")), true)
		local list = h.find(PANEL .. "/Body/DetailsSheet/List")
		check(res, "sidekick_details_present", list ~= nil, true)
		if not list then
			return
		end
		local sum = 0
		for _, row in Config.List do
			local odds = list:FindFirstChild(row.Id) and list[row.Id]:FindFirstChild("Odds")
			local shown = odds and tonumber(string.match(odds.Text, "^([%d%.]+)%%$"))
			check(res, "sidekick_details_odds_" .. row.Id, shown or "missing", row.Odds)
			sum += shown or 0
		end
		check(res, "sidekick_details_sum_100", sum, 100)
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
		local outside, overlaps, covered = {}, {}, {}
		for i, part in parts do
			local r = h.rect(part)
			if not within(bodyRect, r) then
				table.insert(outside, h.pathOf(part))
			end
			for j = i + 1, #parts do
				if crossing(r, h.rect(parts[j])) then
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
		checkDetails(res)
		checkDesktopFit(res)
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
