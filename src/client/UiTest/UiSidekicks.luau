--!nonstrict
-- Sidekick art wiring (design doc 4.36, 4.37; docs/SIDEKICK_SPEC.md "Summon page"). Owned by ui-test-writer.
-- ui_sidekicks judges the poster, Details odds and guarantee, pity bars, Auto-Sell, the Gem icons, the Index page and the desktop
-- fit. Its fixture is sidekick_states (UiScenarios.Needs). A press cannot be faked here, so the Bag art, Details opening and the
-- reveals are judged after real clicks (UiSpec.Clicks sidekicks_*). sidekick_big_reveal scripts a 10x holding a Mythic and a Secret.
-- Page contract: Banner holds only Poster and Sticker. Poster/Names has one cell per featured id (Mythic, Legendaries, Rares of the
--   rotation), with Name, Rarity and Rate ("%g%%"); Poster/Model is one ViewportFrame holding those models, named by id.
--   RotationTimer is a TextLabel showing m:ss to EndsAt. DetailsSheet/List has a row per Public id and one named Secret, each with a
--   label Odds reading "%.3f%%"; the Secret row has Shape/Model, black, holding SecretId's model, and no Name label.
-- Guarantee contract (design doc 4.36, section 6; implementer: report a change, do not loosen): when SidekickPity >= PityCount - 1 the
--   Mythic is due; else when SidekickLegendaryPity >= LegendaryPityCount - 1 a Legendary is due. While one is due the tier's rows
--   share 100% evenly (one Mythic 100.000%, two Legendaries 50.000% each, as the server picks evenly and section 6 sums to 100),
--   all others read 0.000%, Total stays "Total: 100%", and DetailsSheet/List/GuaranteedNote (a shown TextLabel, LayoutOrder below
--   every row, text holding "guaranteed" and the tier) explains it. Nothing due: the note is absent or hidden. It follows the
--   attributes with the sheet open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SidekickConfig"))
local Art = require(Shared:WaitForChild("SidekickArt"))
local Spec = require(script.Parent.UiSpec)
local Client = script.Parent.Parent
local View = require(Client:WaitForChild("SidekickView"))
local Icons = require(Client:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local UiMotion = require(Client:WaitForChild("UiMotion"))

local PANEL = "RacerSidekicks/Panel"
local MAIN = PANEL .. "/Body/Main"
local BANNER = MAIN .. "/Banner"
local POSTER = BANNER .. "/Poster"
local STATUS = PANEL .. "/Header/StatusBlock"
local BARS = STATUS .. "/Bars"
local DETAILS = PANEL .. "/Body/DetailsSheet"
local AUTO_SELL = PANEL .. "/Body/AutoSellSheet"
local REVEAL = "RacerSidekickReveal"
local BIG_REVEAL_WAIT = 20 -- s: the whole 10x, flips and both showcases
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
	-- Mythic, Legendaries and Rares of the rotation: what the poster features. Commons and the Secret are in Details only.
	local function featuredRows(view)
		local rows = {}
		for _, id in view.Ids do
			local row = Config.Get(id)
			if row.Rarity == "Mythic" or row.Rarity == "Legendary" or row.Rarity == "Rare" then
				table.insert(rows, row)
			end
		end
		return rows
	end
	local function posterCells(poster)
		local names = poster:FindFirstChild("Names")
		local cells = {}
		for _, child in names and names:GetChildren() or {} do
			if child:IsA("GuiObject") then
				table.insert(cells, child)
			end
		end
		return cells
	end
	-- nil when the poster's one view holds this Sidekick's model.
	local function posterModelProblem(id)
		local poster = h.find(POSTER)
		local view = poster and poster:FindFirstChild("Model")
		if not (view and view:IsA("ViewportFrame")) then
			return "no ViewportFrame Model"
		end
		local model = view:FindFirstChild(id)
		if not (model and model:IsA("Model") and model:FindFirstChildWhichIsA("BasePart", true)) then
			return "no model " .. id
		end
		return nil
	end
	local function labelText(holder, name)
		local label = holder and holder:FindFirstChild(name)
		return label and label.Text or "missing"
	end
	local function textsUnder(holder)
		local words = {}
		for _, d in holder:GetDescendants() do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				table.insert(words, d.Text)
			end
		end
		return table.concat(words, " ")
	end

	-- No Secret, Common, boss drop or Sidekick out of the slot on the poster: by id, by name, or as a tile.
	local function checkBannerHides(res, banner, view)
		local featured, text = {}, textsUnder(banner)
		for _, row in featuredRows(view) do
			featured[row.Id] = true
		end
		check(res, "sidekick_banner_no_secret_word", string.find(text, "Secret", 1, true) ~= nil, false)
		for _, rows in { Config.List, Config.BossDrops } do
			for _, row in rows do
				if not featured[row.Id] then
					check(res, "sidekick_banner_hides_id_" .. row.Id, banner:FindFirstChild(row.Id, true) == nil, true)
					check(
						res,
						"sidekick_banner_hides_name_" .. row.Id,
						string.find(text, row.Name, 1, true) ~= nil,
						false
					)
				end
			end
		end
	end

	local function checkBanner(res)
		local banner = h.find(BANNER)
		local poster = h.find(POSTER)
		check(res, "sidekick_banner_present", banner ~= nil and poster ~= nil, true)
		local view = public()
		check(res, "sidekick_rotation_attribute_readable", view ~= nil, true)
		if not (banner and poster and view) then
			return
		end
		-- No Rare or Secret tile (owner 2026-11-05): the Rares stand in the poster, and it and its sticker are all the banner holds.
		local others = {}
		for _, child in banner:GetChildren() do
			if child:IsA("GuiObject") and child ~= poster and child.Name ~= "Sticker" then
				table.insert(others, child.Name)
			end
		end
		h.checkList(res, "sidekick_banner_no_other_tiles", others)
		local rows = featuredRows(view)
		check(res, "sidekick_poster_cells_are_the_rotation", #posterCells(poster), #rows)
		for _, row in rows do
			local problem = waitFor(function()
				return posterModelProblem(row.Id)
			end)
			check(res, "sidekick_banner_model_" .. row.Id, problem or "shown", "shown")
			local cell = poster:FindFirstChild("Names") and poster.Names:FindFirstChild(row.Id)
			check(res, "sidekick_poster_name_" .. row.Id, labelText(cell, "Name"), row.Name)
			check(res, "sidekick_poster_rarity_" .. row.Id, labelText(cell, "Rarity"), row.Rarity)
			check(res, "sidekick_poster_rate_" .. row.Id, labelText(cell, "Rate"), string.format("%g%%", row.Odds))
		end
		local models = 0
		for _, child in poster:FindFirstChild("Model") and poster.Model:GetChildren() or {} do
			models += child:IsA("Model") and 1 or 0
		end
		check(res, "sidekick_poster_models_only_featured", models, #rows)
		checkBannerHides(res, banner, view)
		local sticker = labelText(banner, "Sticker")
		check(res, "sidekick_sticker_shown", sticker ~= "missing", true)
		check(res, "sidekick_sticker_no_odds_claim", string.find(sticker, "[%d%%]") ~= nil, false)
	end

	-- Models, not portraits, on the page (design doc 4.36: portraits only in the index and Bag equip).
	local function checkNoPortraits(res, page)
		local portraits, found = {}, {}
		for _, id in allIds() do
			if Art[id] and Art[id].Portrait then
				portraits[Art[id].Portrait] = id
			end
		end
		for _, d in page:GetDescendants() do
			if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and portraits[d.Image] then
				table.insert(found, h.pathOf(d))
			end
		end
		h.checkList(res, "sidekick_page_no_portraits", found)
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

	-- The rotation's one Secret, and only it, as a black shape; "Secret" and its chance, and no name column.
	local function silhouetteProblem(line, view)
		local shape = line and line:FindFirstChild("Shape")
		local model = shape and shape:FindFirstChild("Model")
		if not (model and model:IsA("ViewportFrame")) then
			return "no Shape/Model ViewportFrame"
		end
		if model.ImageColor3 ~= Color3.new(0, 0, 0) then
			return "not black: " .. tostring(model.ImageColor3)
		end
		local live = model:FindFirstChild(view.SecretId)
		if not (live and live:FindFirstChildWhichIsA("BasePart", true)) then
			return "no model of " .. tostring(view.SecretId)
		end
		for _, row in secretRows() do
			if row.Id ~= view.SecretId and model:FindFirstChild(row.Id) then
				return "shows another Secret " .. row.Id
			end
		end
		return nil
	end

	-- The slot turns while the page is open: the poster and Details follow, with nobody reopening it.
	local function checkSlotChange(res)
		local request = ReplicatedStorage:FindFirstChild("UiTestSetupRequest")
		local banner, list = h.find(BANNER), h.find(DETAILS .. "/List")
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
			if banner:FindFirstChild(before, true) or list:FindFirstChild(before) then
				return "old Mythic still shown"
			end
			if not list:FindFirstChild(nextMythic) then
				return "new Mythic not in Details"
			end
			return posterModelProblem(nextMythic) or silhouetteProblem(list:FindFirstChild("Secret"), public())
		end)
		check(res, "sidekick_slot_change_followed", problem or "followed", "followed")
		checkBannerHides(res, banner, public())
		request:InvokeServer("sidekick_ui_clock:real")
		local back = waitFor(function()
			return posterModelProblem(before)
		end)
		check(res, "sidekick_slot_change_back", back or "back", "back")
	end

	-- Name -> percent each Details row must show. tier: the rarity a due guarantee pays; it shares 100%, the rest read 0.
	local function wantOdds(view, tier)
		local odds = {}
		if tier then
			local inTier = 0
			for _, id in view.Ids do
				inTier += Config.Get(id).Rarity == tier and 1 or 0
			end
			for _, id in view.Ids do
				odds[id] = Config.Get(id).Rarity == tier and 100 / inTier or 0
			end
			odds.Secret = 0
			return odds
		end
		-- What the player must see, from the replicated view alone: listed odds, the rest split across Commons.
		local secrets = secretRows()
		odds.Secret = secrets[1] and secrets[1].Odds or 0
		local rest, commons = 100 - odds.Secret, 0
		for _, id in view.Ids do
			local row = Config.Get(id)
			rest -= row.Odds
			commons += row.Rarity == "Common" and 1 or 0
		end
		for _, id in view.Ids do
			local row = Config.Get(id)
			odds[id] = row.Odds + (row.Rarity == "Common" and rest / commons or 0)
		end
		return odds
	end
	local function shownOdds(list, name)
		return labelText(list:FindFirstChild(name), "Odds")
	end
	local function shownSum(res, tag, list, view)
		local sum = 0
		for name in wantOdds(view) do
			sum += tonumber(string.match(shownOdds(list, name), "^(%d+%.%d%d%d)%%$")) or 0
		end
		local rounding = 0.0005 * (#view.Ids + 1) + 1e-6
		h.check(res, tag, sum, "100 +- " .. rounding, math.abs(sum - 100) <= rounding)
	end

	-- Section 6: every summon outcome, read from the shown labels, sums to 100%.
	local function checkDetails(res)
		local button = h.find(POSTER .. "/Details")
		check(res, "sidekick_details_button_shown", button ~= nil and h.visible(button), true)
		check(res, "sidekick_details_button_label", labelText(button, "Label"), "Details")
		local list = h.find(DETAILS .. "/List")
		check(res, "sidekick_details_present", list ~= nil, true)
		if not list then
			return
		end
		local view = public()
		if not view then
			return -- sidekick_rotation_attribute_readable already failed
		end
		for name, odds in wantOdds(view) do
			check(res, "sidekick_details_odds_" .. name, shownOdds(list, name), string.format("%.3f%%", odds))
		end
		shownSum(res, "sidekick_details_sum_100", list, view)
		local secrets = secretRows()
		local liveIsAChoice = false
		for _, row in secrets do
			liveIsAChoice = liveIsAChoice or row.Id == view.SecretId
		end
		check(res, "sidekick_view_secret_id_is_a_choice", liveIsAChoice, true)
		local secretLine = list:FindFirstChild("Secret")
		local problem = waitFor(function()
			return silhouetteProblem(secretLine, view)
		end)
		check(res, "sidekick_details_silhouette", problem or "shown", "shown")
		check(res, "sidekick_details_secret_rarity", labelText(secretLine, "Rarity"), "Secret")
		check(res, "sidekick_details_secret_no_name_column", labelText(secretLine, "Name"), "missing")
		-- The Secret row's words never tell which one is live, and it is not a row of its own.
		local text = secretLine and textsUnder(secretLine) or ""
		for _, row in secrets do
			check(
				res,
				"sidekick_details_secret_hides_name_" .. row.Id,
				string.find(text, row.Name, 1, true) ~= nil,
				false
			)
			check(res, "sidekick_details_hides_id_" .. row.Id, list:FindFirstChild(row.Id) == nil, true)
		end
		for _, row in Config.List do
			if row.Rarity ~= "Secret" and not table.find(view.Ids, row.Id) then
				check(res, "sidekick_details_out_of_rotation_" .. row.Id, list:FindFirstChild(row.Id) == nil, true)
			end
		end
		check(res, "sidekick_details_total_text", labelText(list, "Total"), "Total: 100%")
		for _, row in Config.BossDrops do
			check(res, "sidekick_details_no_boss_drop_" .. row.Id, list:FindFirstChild(row.Id) == nil, true)
		end
	end

	-- Fixture counts drive the pity bars and the Details odds (contract at the top), with the sheet open.
	local function checkGuarantee(res)
		local request = ReplicatedStorage:FindFirstChild("UiTestSetupRequest")
		local sheet, list = h.find(DETAILS), h.find(DETAILS .. "/List")
		local mythicBar, legendaryBar = h.find(BARS .. "/PityBar"), h.find(BARS .. "/LegendaryPityBar")
		local view = public()
		check(res, "sidekick_guarantee_parts", request and sheet and list and mythicBar and legendaryBar and true, true)
		if not (request and sheet and list and mythicBar and legendaryBar and view) then
			return
		end
		check(res, "sidekick_pity_bar_label", labelText(mythicBar, "Label"), "Mythic Pity:")
		check(res, "sidekick_legendary_pity_bar_label", labelText(legendaryBar, "Label"), "Legendary Pity:")
		sheet.Visible = true
		local M, L = Config.PityCount, Config.LegendaryPityCount
		for _, step in
			{
				{ "none", 0, 0, nil },
				{ "one_short", M - 2, L - 2, nil },
				{ "mythic", M - 1, 0, "Mythic" },
				{ "legendary", 0, L - 1, "Legendary" },
				{ "legendary_held_over", 0, L, "Legendary" }, -- a Mythic won the tie: the count stays over
				{ "both_mythic_wins", M - 1, L - 1, "Mythic" },
				{ "back_to_none", 0, 0, nil },
			}
		do
			local tag, mythic, legendary, tier = step[1], step[2], step[3], step[4]
			request:InvokeServer(("sidekick_ui_pity:%d:%d"):format(mythic, legendary))
			local bars = waitFor(function()
				local got = labelText(mythicBar, "Value") .. " " .. labelText(legendaryBar, "Value")
				local want = ("%d/%d %d/%d"):format(mythic, M, legendary, L)
				return got ~= want and got or nil
			end)
			check(res, "sidekick_pity_bars_" .. tag, bars or "follow", "follow")
			local want = wantOdds(view, tier)
			local odds = waitFor(function()
				for name, percent in want do
					local text = string.format("%.3f%%", percent)
					if shownOdds(list, name) ~= text then
						return name .. " " .. shownOdds(list, name) .. " want " .. text
					end
				end
				return nil
			end)
			check(res, "sidekick_guarantee_odds_" .. tag, odds or "right", "right")
			shownSum(res, "sidekick_guarantee_sum_100_" .. tag, list, view)
			check(res, "sidekick_guarantee_total_" .. tag, labelText(list, "Total"), "Total: 100%")
			local note = list:FindFirstChild("GuaranteedNote")
			if tier then
				local words = note and note:IsA("TextLabel") and string.lower(note.Text) or ""
				check(res, "sidekick_guarantee_note_shown_" .. tag, note ~= nil and h.visible(note), true)
				check(
					res,
					"sidekick_guarantee_note_says_" .. tag,
					string.find(words, "guaranteed", 1, true) ~= nil,
					true
				)
				check(
					res,
					"sidekick_guarantee_note_tier_" .. tag,
					string.find(words, string.lower(tier), 1, true) ~= nil,
					true
				)
				local above = note ~= nil
				for name in want do
					local line = list:FindFirstChild(name)
					above = above and line ~= nil and note.LayoutOrder < line.LayoutOrder
				end
				check(res, "sidekick_guarantee_note_above_rows_" .. tag, above, true)
			else
				check(res, "sidekick_guarantee_no_note_" .. tag, note ~= nil and note.Visible, false)
			end
		end
		sheet.Visible = false
	end

	-- Off until turned on: the fixture is a fresh save, and a toggle follows the server both ways.
	local function checkAutoSell(res)
		local list = h.find(AUTO_SELL .. "/List")
		check(res, "sidekick_autosell_present", list ~= nil, true)
		if not list then
			return
		end
		local function toggleText(rarity)
			local line = list:FindFirstChild(rarity)
			return labelText(line and line:FindFirstChild("Toggle"), "Label")
		end
		local rarities = {}
		for _, row in Config.List do
			if not table.find(rarities, row.Rarity) then
				table.insert(rarities, row.Rarity)
				check(res, "sidekick_autosell_off_by_default_" .. row.Rarity, toggleText(row.Rarity), "Off")
			end
		end
		local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("SidekickAutoSell")
		check(res, "sidekick_autosell_remote", remote ~= nil, true)
		if not remote then
			return
		end
		for _, word in { "On", "Off" } do
			-- The second toggle lands inside the server's remote cooldown ("Please wait"), so it asks until accepted.
			local refused = waitFor(function()
				local done, why = remote:InvokeServer(rarities[1], word == "On")
				return done ~= true and tostring(why) or nil
			end)
			check(res, "sidekick_autosell_accepted_" .. word, refused or "accepted", "accepted")
			local problem = waitFor(function()
				return toggleText(rarities[1]) ~= word and toggleText(rarities[1]) or nil
			end)
			check(res, "sidekick_autosell_shows_" .. word, problem or word, word)
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
				PANEL .. "/Body/GemColumn/Packs",
				POSTER .. "/Details",
				MAIN .. "/AutoSell",
				BANNER,
				MAIN .. "/Cost",
				MAIN .. "/Summon1",
				MAIN .. "/Summon10",
				STATUS .. "/Balance",
				BARS .. "/TimerBar",
				BARS .. "/PityBar",
				BARS .. "/LegendaryPityBar",
			}
		do
			local part = h.find(path)
			check(res, "sidekick_part_present_" .. path, part ~= nil, true)
			if part then
				table.insert(parts, part)
			end
		end
		local poster = h.find(POSTER)
		local outside, overlaps, covered = {}, {}, {}
		-- Each featured caption stays in the poster, clear of the others.
		local cellsOutside, cellsCrossing, cellsSmall = {}, {}, {}
		local cells = poster and posterCells(poster) or {}
		local bannerRect = poster and h.rect(poster)
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
		end
		h.checkList(res, "sidekick_banner_cells_in_banner_desktop", cellsOutside)
		h.checkList(res, "sidekick_banner_cells_no_overlap_desktop", cellsCrossing)
		h.checkList(res, "sidekick_banner_cells_big_enough_desktop", cellsSmall)
		for i, part in parts do
			local r = h.rect(part)
			if not within(body:IsAncestorOf(part) and bodyRect or panelRect, r) then
				table.insert(outside, h.pathOf(part))
			end
			for j = i + 1, #parts do
				-- A part inside another (Details in the Banner's poster) is meant to cross it, whichever is listed first.
				if
					not part:IsAncestorOf(parts[j])
					and not parts[j]:IsAncestorOf(part)
					and crossing(r, h.rect(parts[j]))
				then
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
		checkGemIcon(res, "sidekick_page_gem_icon", h.find(STATUS .. "/Balance/GemIcon"))
		checkGemIcon(res, "sidekick_cost_gem_icon", h.find(MAIN .. "/Cost/GemIcon"))
		local blur = Lighting:FindFirstChild("SidekickSummonBlur")
		check(res, "sidekick_blur_while_open", blur ~= nil and blur.Enabled, true)
		checkBanner(res)
		checkNoPortraits(res, page)
		checkTimer(res, page)
		checkDetails(res)
		checkAutoSell(res)
		checkDesktopFit(res)
		checkSlotChange(res)
		checkGuarantee(res)
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

	-- After a real press of the poster's Tap or its Details button.
	function after.sidekicks_details_open(res)
		local sheet = h.find(DETAILS)
		check(res, "sidekick_details_opened", sheet ~= nil and h.visible(sheet), true)
		local main = h.find(MAIN)
		check(res, "sidekick_page_steps_aside_for_details", main ~= nil and main.Visible, false)
	end

	local function revealPart(name)
		return h.find(REVEAL .. "/" .. name)
	end
	local function revealEnded(res, wait)
		local deadline = os.clock() + wait
		while not revealPart("Hint") and os.clock() < deadline do
			task.wait(0.1)
		end
		check(res, "sidekick_reveal_hint", labelText(h.find(REVEAL), "Hint"), "(Click anywhere to continue)")
		-- End: no buttons, a click anywhere continues (owner 2026-11-05). Tap is the one thing that takes it.
		local buttons = {}
		for _, d in h.player.PlayerGui:FindFirstChild(REVEAL) and h.player.PlayerGui[REVEAL]:GetDescendants() or {} do
			if d:IsA("GuiButton") and d.Name ~= "Tap" then
				table.insert(buttons, d.Name)
			end
		end
		h.checkList(res, "sidekick_reveal_no_buttons", buttons)
	end

	-- After a real Summon 1x press: the reveal shows a model, its own name and rarity, never only a name tile.
	function after.sidekicks_reveal_models(res)
		local problem = waitFor(function()
			local layer = revealPart("Stage/Showcase")
			if not layer then
				return "reveal not shown"
			end
			return modelProblem(layer)
		end)
		check(res, "sidekick_reveal_model", problem or "shown", "shown")
		revealEnded(res, WAIT)
		local layer, rarity = revealPart("Stage/Showcase"), "no row of that name"
		for _, row in Config.List do
			if row.Name == labelText(layer, "Name") then
				rarity = row.Rarity
			end
		end
		check(res, "sidekick_reveal_rarity_matches", labelText(layer, "Rarity"), rarity)
	end

	-- After a real Summon 10x press on scripted rolls (sidekick_big_reveal): each Mythic and Secret interrupts with its own
	-- showcase, which goes away again; every card ends face up with its own result.
	function after.sidekicks_reveal_big(res)
		local ids = string.split(h.player:GetAttribute("UiTestRevealIds") or "", ",")
		check(res, "sidekick_big_fixture_results", #ids, 10)
		if #ids ~= 10 then
			return
		end
		local wantSeen = {}
		for _, id in ids do
			local row = Config.Get(id)
			if not UiMotion.Reduced() and (row.Rarity == "Mythic" or row.Rarity == "Secret") then
				table.insert(wantSeen, row.Name .. " " .. row.Rarity)
			end
		end
		local seen, bare = {}, {}
		local last = nil
		local deadline = os.clock() + BIG_REVEAL_WAIT
		while not revealPart("Hint") and os.clock() < deadline do
			local layer = revealPart("Stage/Showcase")
			if
				layer
				and layer ~= last
				and labelText(layer, "Name") ~= "missing"
				and labelText(layer, "Rarity") ~= "missing"
			then
				last = layer
				table.insert(seen, labelText(layer, "Name") .. " " .. labelText(layer, "Rarity"))
				local problem = modelProblem(layer)
				if problem then
					table.insert(bare, labelText(layer, "Name") .. ": " .. problem)
				end
			end
			task.wait()
		end
		check(res, "sidekick_big_showcases", table.concat(seen, ", "), table.concat(wantSeen, ", "))
		h.checkList(res, "sidekick_big_showcase_models", bare)
		revealEnded(res, 0)
		check(res, "sidekick_big_showcases_cleaned_up", revealPart("Stage/Showcase") == nil, true)
		local mythicPity, legendaryPity = 0, 0
		for order, id in ids do
			local row = Config.Get(id)
			local holder = revealPart("Stage/Grid/Result" .. order .. "/Holder")
			check(res, "sidekick_big_card_name_" .. order, labelText(holder, "Name"), row.Name)
			check(res, "sidekick_big_card_rarity_" .. order, labelText(holder, "Rarity"), row.Rarity)
			check(
				res,
				"sidekick_big_card_turned_" .. order,
				holder ~= nil and holder:FindFirstChild("Mark") == nil,
				true
			)
			check(res, "sidekick_big_card_model_" .. order, modelProblem(holder) or "shown", "shown")
			mythicPity = row.Rarity == "Mythic" and 0 or mythicPity + 1
			legendaryPity = row.Rarity == "Legendary" and 0 or legendaryPity + 1
		end
		check(res, "sidekick_big_page_steps_aside", h.player.PlayerGui.RacerSidekicks.Enabled, false)
		-- A Mythic resets only its own count; a Secret resets nothing (design doc 4.36).
		check(res, "sidekick_big_mythic_pity", h.player:GetAttribute("SidekickPity"), mythicPity)
		check(res, "sidekick_big_legendary_pity", h.player:GetAttribute("SidekickLegendaryPity"), legendaryPity)
		check(res, "sidekick_big_all_kept", #View.Bag(h.player), #Config.List + #Config.BossDrops + #ids)
	end

	-- After the press that ends a reveal: gone, with the page back as it stood.
	function after.sidekicks_reveal_closed(res)
		local gui = h.player.PlayerGui
		check(res, "sidekick_reveal_gone", gui:FindFirstChild(REVEAL) == nil, true)
		check(res, "sidekick_page_back", gui.RacerSidekicks.Enabled, true)
		local blur, panel = Lighting:FindFirstChild("SidekickSummonBlur"), h.find(PANEL)
		check(res, "sidekick_blur_follows_page", blur and blur.Enabled, panel and panel.Visible)
	end

	return { Scenarios = scenarios, After = after }
end

return Module
