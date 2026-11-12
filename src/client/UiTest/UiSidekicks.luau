--!nonstrict
-- Sidekick art wiring (design doc 4.36, 4.37, section 6; docs/SIDEKICK_SPEC.md "Summon presentation", "Summon page"). Owned by
-- ui-test-writer. ui_sidekicks judges the galaxy summon screen (owner 2026-11-12: "The Sidekick UI tests check the galaxy
-- screen's real elements"): the stage and its featured models, names, rates, Details odds and guarantee, pity cards, Gem balance
-- and icons, costs, Auto-Sell, closing, the Index page and the desktop fit. Its fixture is sidekick_states (UiScenarios.Needs).
-- A press cannot be faked here, so the Bag art, Details and Auto-Sell opening and the reveals are judged after real clicks
-- (UiSpec.Clicks sidekicks_*). sidekick_big_reveal scripts a 10x holding a Mythic and a Secret.
-- Screen contract (RacerSidekicks.rbxm, Client/SidekickUi): ScreenGui RacerSidekicks; Canvas is the panel PanelSwitch toggles.
--   Open: workspace holds the local stage SummoningStageLocal, Units/Unit1..3 each with one ActualSidekick model (Unit2 the
--   rotation's Mythic, Unit1 and Unit3 its Legendaries), labels Canvas/Unit<i> (name) and Canvas/Rarity<i>; the camera is
--   Scriptable, the player cannot walk, Lighting has SummonPreviewActive. Closed: camera, movement, lighting and HUD are as they
--   were and the stage is gone (SIDEKICK_SPEC "Summon presentation").
--   Canvas/Balance shows the Gems (HudFormat.Short) with CurrencyGem; Canvas/Once and Canvas/Many show their cost with
--   CurrencyGem; Canvas/Timer shows m:ss to EndsAt; Canvas/Pity1+PityCount1+PityCard1 is Legendary pity, Pity2+PityCount2+
--   PityCard2 Mythic pity ("%d / %d", Track/Progress filled count / limit); Canvas/Featured is the sticker.
-- Contract the implementer must still provide (red until then; implementer: report a change, do not loosen):
--   Canvas/Chances, the odds button, reads "Details" (section 6 names "Info" or "Details"; SIDEKICK_SPEC "Paid random item rules"
--   fixes "Details"). Canvas/Rate<i> (TextLabel) under Canvas/Unit<i> reads that Sidekick's rate "%g%%" (design doc 4.36: "each
--   one's rate under its name"). The rotation's Rares are on the screen by name too (4.36 poster: "the Legendaries and Rares").
--   No drawn portrait anywhere on the screen (4.36 "Art in UI"; Canvas/Banner1/UnitArtwork shows one today).
--   Details list Canvas/Modal/Panel/DetailsScroll/List exists from load, kept current with SidekickRotation and the pity
--   attributes whether shown or not; Details shows it (Modal visible), other dialogs hide it. It has a row per Public id and one
--   named Secret, each with a label Odds reading "%.3f%%", a Rarity label and (not the Secret) a Name label; the Secret row has
--   Shape/Model, black, holding SecretId's model. Rows come from Public.Odds, rounded to 3 decimals by largest remainder, so the
--   shown rows sum to exactly 100.000. List/Total reads "Total: 100%".
-- Guarantee contract (design doc 4.36, section 6): when SidekickPity >= PityCount - 1 the Mythic is due; else when
--   SidekickLegendaryPity >= LegendaryPityCount - 1 a Legendary is due. While one is due the tier's rows share 100% evenly, all
--   others read 0.000%, Total stays "Total: 100%", and List/GuaranteedNote (a shown TextLabel, LayoutOrder below every row, text
--   holding "guaranteed" and the tier) explains it. Nothing due: the note is absent or hidden.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SidekickConfig"))
local Art = require(Shared:WaitForChild("SidekickArt"))
local HudFormat = require(Shared:WaitForChild("HudFormat"))
local Monetization = require(Shared:WaitForChild("MonetizationConfig"))
local Spec = require(script.Parent.UiSpec)
local Client = script.Parent.Parent
local View = require(Client:WaitForChild("SidekickView"))
local Icons = require(Client:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local UiMotion = require(Client:WaitForChild("UiMotion"))

local GUI = "RacerSidekicks"
local CANVAS = GUI .. "/Canvas"
local MODAL = CANVAS .. "/Modal"
local DETAILS = MODAL .. "/Panel/DetailsScroll/List"
local ACTIONS = MODAL .. "/Panel/DetailsScroll/Actions"
local STAGE = "SummoningStageLocal"
local REVEAL = "RacerSidekickReveal"
local BIG_REVEAL_WAIT = 20 -- s: the whole 10x, flips and both showcases
local WAIT = 5 -- s: models and bag art may arrive a moment after the screen opens
local PHONE_MAX_HEIGHT = 500
local TIMER_SLACK = 3 -- s
local LIGHTING_KEYS = { "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "GlobalShadows" }

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

	local function checkGemIcon(res, name, icon, image)
		check(res, name .. "_class", icon and icon.ClassName or "missing", "ImageLabel")
		local got = icon and icon:IsA("ImageLabel") and icon.Image or "missing"
		if image then
			check(res, name .. "_image", got, image)
		else
			-- The galaxy screen draws its own gem (RacerSidekicks.rbxm); no rule names the HUD's Tab tilt gem for it.
			h.check(res, name .. "_image", got, "an image", got ~= "missing" and got ~= "")
		end
		return got
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
	local function rowsOf(view, rarity)
		local rows = {}
		for _, id in view.Ids do
			local row = Config.Get(id)
			if row.Rarity == rarity then
				table.insert(rows, row)
			end
		end
		return rows
	end
	-- Mythic, Legendaries and Rares of the rotation: what the poster features (design doc 4.36). Commons and the Secret are in
	-- Details only.
	local function featuredRows(view)
		local rows = {}
		for _, rarity in { "Mythic", "Legendary", "Rare" } do
			for _, row in rowsOf(view, rarity) do
				table.insert(rows, row)
			end
		end
		return rows
	end
	local function labelText(holder, name)
		local label = holder and holder:FindFirstChild(name)
		return label and label.Text or "missing"
	end
	-- Texts of the screen a player can read: shown labels and buttons, outside the dialog.
	local function shownTexts(holder, skip)
		local words = {}
		for _, d in holder:GetDescendants() do
			if
				(d:IsA("TextLabel") or d:IsA("TextButton"))
				and h.visible(d)
				and not (skip and d:IsDescendantOf(skip))
			then
				table.insert(words, d.Text)
			end
		end
		return words
	end
	local function stage()
		return workspace:FindFirstChild(STAGE)
	end
	local function partCount(model)
		local n = 0
		for _, d in model and model:GetDescendants() or {} do
			n += d:IsA("BasePart") and 1 or 0
		end
		return n
	end
	-- nil when stage unit `index` stands this Sidekick's actual model (a clone of SidekickModels[id], same parts).
	local function unitModelProblem(index, id)
		local live = stage()
		if not live then
			return "no " .. STAGE
		end
		local unit = live:FindFirstChild("Units") and live.Units:FindFirstChild("Unit" .. index)
		local model = unit and unit:FindFirstChild("ActualSidekick")
		if not (model and model:IsA("Model")) then
			return "no ActualSidekick in Unit" .. index
		end
		local source = ReplicatedStorage:FindFirstChild("SidekickModels")
		source = source and source:FindFirstChild(id)
		if partCount(model) == 0 or partCount(model) ~= partCount(source) then
			return ("Unit%d is not %s's model (%d parts, want %d)"):format(
				index,
				id,
				partCount(model),
				partCount(source)
			)
		end
		return nil
	end

	-- No Secret, Common, boss drop or Sidekick out of the slot on the screen, by name; Details (the dialog) is apart.
	local function checkScreenHides(res, canvas, view)
		local featured = {}
		for _, row in featuredRows(view) do
			featured[row.Id] = true
		end
		local text = table.concat(shownTexts(canvas, canvas:FindFirstChild("Modal")), " ")
		check(res, "sidekick_screen_no_secret_word", string.find(text, "Secret", 1, true) ~= nil, false)
		for _, rows in { Config.List, Config.BossDrops } do
			for _, row in rows do
				if not featured[row.Id] then
					check(
						res,
						"sidekick_screen_hides_name_" .. row.Id,
						string.find(text, row.Name, 1, true) ~= nil,
						false
					)
				end
			end
		end
	end

	-- Design doc 4.36 poster, on the galaxy stage: the Mythic in the centre (Igriz, SIDEKICK_SPEC "Summon presentation"), the
	-- Legendaries beside it, actual 3D models, each one's name, rarity and rate.
	local function checkFeatured(res, canvas)
		local view = public()
		check(res, "sidekick_rotation_attribute_readable", view ~= nil, true)
		if not view then
			return
		end
		local mythic, legendaries = rowsOf(view, "Mythic")[1], rowsOf(view, "Legendary")
		check(res, "sidekick_featured_mythic_is_igriz", mythic and mythic.Id, Config.FeaturedMythic)
		local slots = { [2] = mythic, [1] = legendaries[1], [3] = legendaries[2] }
		for index = 1, 3 do
			local row = slots[index]
			if row then
				local problem = waitFor(function()
					return unitModelProblem(index, row.Id)
				end)
				check(res, "sidekick_stage_model_" .. row.Id, problem or "shown", "shown")
				check(res, "sidekick_stage_name_" .. row.Id, labelText(canvas, "Unit" .. index), row.Name)
				check(res, "sidekick_stage_rarity_" .. row.Id, labelText(canvas, "Rarity" .. index), row.Rarity)
				-- Design doc 4.36: "each one's rate under its name". Canvas/Rate<i> is new (contract at the top).
				check(
					res,
					"sidekick_stage_rate_" .. row.Id,
					labelText(canvas, "Rate" .. index),
					("%g%%"):format(row.Odds)
				)
			end
		end
		local models = 0
		for _, d in stage() and stage():GetDescendants() or {} do
			models += (d:IsA("Model") and d.Name == "ActualSidekick") and 1 or 0
		end
		check(res, "sidekick_stage_models_only_featured", models, 3)
		-- Design doc 4.36 poster: "the Legendaries and Rares beside it". Owner question: the galaxy screen has 3 units.
		local text = table.concat(shownTexts(canvas, canvas:FindFirstChild("Modal")), " ")
		for _, row in rowsOf(view, "Rare") do
			check(res, "sidekick_screen_shows_rare_" .. row.Id, string.find(text, row.Name, 1, true) ~= nil, true)
		end
		checkScreenHides(res, canvas, view)
		local sticker = canvas:FindFirstChild("Featured")
		check(res, "sidekick_sticker_shown", sticker ~= nil and h.visible(sticker), true)
		check(res, "sidekick_sticker_no_odds_claim", string.find(labelText(canvas, "Featured"), "[%d%%]") ~= nil, false)
	end

	-- Models, not portraits, on the page (design doc 4.36 "Art in UI": portraits only in the index and Bag equip).
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

	local function timerSeconds(timer)
		local minutes, rest = string.match(timer.Text, "(%d+):(%d%d)")
		return minutes and tonumber(minutes) * 60 + tonumber(rest) or nil
	end
	local function checkTimer(res, canvas)
		local timer = canvas:FindFirstChild("Timer")
		check(res, "sidekick_timer_present", timer ~= nil and timer:IsA("TextLabel"), true)
		local view = public()
		if not (timer and timer:IsA("TextLabel") and view) then
			return
		end
		check(res, "sidekick_timer_shown", h.visible(timer), true)
		local got = timerSeconds(timer)
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

	-- Design doc 4.36 / SIDEKICK_SPEC "Summon page": the Gem balance at the top; the costs; the Gem icons.
	local function checkGemsAndCosts(res, canvas)
		local balance = canvas:FindFirstChild("Balance")
		local gems = h.player:GetAttribute("Gems") or 0
		local shown = waitFor(function()
			local text = balance and balance.Text or "missing"
			return text ~= HudFormat.Short(gems) and text or nil
		end)
		check(res, "sidekick_balance_shows_gems", shown or HudFormat.Short(gems), HudFormat.Short(gems))
		local pageIcon = checkGemIcon(res, "sidekick_page_gem_icon", balance and balance:FindFirstChild("CurrencyGem"))
		for _, cost in
			{
				{ "Once", h.player:GetAttribute("SidekickCost1") or Config.SummonCost },
				{ "Many", h.player:GetAttribute("SidekickCost10") or Config.TenCost },
			}
		do
			local button = canvas:FindFirstChild(cost[1])
			check(res, "sidekick_summon_button_shown_" .. cost[1], button ~= nil and h.visible(button), true)
			local text = button and button.Text or ""
			check(res, "sidekick_cost_shown_" .. cost[1], string.find(text, tostring(cost[2]), 1, true) ~= nil, true)
			checkGemIcon(
				res,
				"sidekick_cost_gem_icon_" .. cost[1],
				button and button:FindFirstChild("CurrencyGem"),
				pageIcon
			)
		end
	end

	-- More Gems (design doc 4.36, SIDEKICK_SPEC "Summon page"): its entry is on the screen and the bundles shown are real packs.
	local function checkMoreGems(res, canvas)
		local more = canvas:FindFirstChild("More")
		check(res, "sidekick_more_gems_shown", more ~= nil and h.visible(more), true)
		local names = {}
		for _, pack in Monetization.GemPacks do
			names[pack.Name .. " Gems"] = pack
		end
		for i = 1, 2 do
			local offer = canvas:FindFirstChild("Offer" .. i)
			local pack = offer and names[labelText(offer, "Title")]
			check(res, "sidekick_offer_is_a_pack_" .. i, pack ~= nil, true)
			if pack then
				check(res, "sidekick_offer_price_" .. i, labelText(offer, "Price"), "R$" .. pack.RobuxPrice)
			end
		end
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

	-- The slot turns while the screen is open: the timer and Details follow with nobody reopening it, and the featured Mythic
	-- stays Igriz (SIDEKICK_SPEC "Summon presentation"). The fixture moves to a slot with another Secret.
	local function checkSlotChange(res, canvas)
		local request = ReplicatedStorage:FindFirstChild("UiTestSetupRequest")
		local list, timer = h.find(DETAILS), canvas:FindFirstChild("Timer")
		check(res, "sidekick_slot_change_parts", request ~= nil and list ~= nil and timer ~= nil, true)
		local before = public()
		if not (request and list and timer and before) then
			return
		end
		request:InvokeServer("sidekick_ui_clock:next")
		local problem = waitFor(function()
			local now = public()
			if not now or now.EndsAt == before.EndsAt then
				return "attribute did not change"
			end
			local got = timerSeconds(timer)
			if not (got and math.abs(got - (now.EndsAt - workspace:GetServerTimeNow())) <= TIMER_SLACK) then
				return "timer still on the old slot: " .. timer.Text
			end
			return silhouetteProblem(list:FindFirstChild("Secret"), now)
		end)
		check(res, "sidekick_slot_change_followed", problem or "followed", "followed")
		local mythic = public() and rowsOf(public(), "Mythic")[1]
		check(res, "sidekick_slot_change_mythic_stays_igriz", labelText(canvas, "Unit2"), mythic and mythic.Name)
		checkScreenHides(res, canvas, public() or before)
		request:InvokeServer("sidekick_ui_clock:real")
		local back = waitFor(function()
			local now = public()
			return not (now and now.EndsAt == before.EndsAt) and "not back" or nil
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
		-- What the server rolls, from the replicated view alone.
		local served = view.Odds or {}
		odds.Secret = served[view.SecretId] or 0
		for _, id in view.Ids do
			odds[id] = served[id] or 0
		end
		return odds
	end
	local function shownOdds(list, name)
		return labelText(list:FindFirstChild(name), "Odds")
	end
	local function shownThousandths(list, name)
		local number = tonumber(string.match(shownOdds(list, name), "^(%d+%.%d%d%d)%%$"))
		return number and math.round(number * 1000)
	end
	local function shownSum(res, tag, list, view)
		local sum = 0
		for name in wantOdds(view) do
			sum += shownThousandths(list, name) or 0
		end
		check(res, tag, sum, 100000)
	end
	-- nil when every shown row is its percent rounded by largest remainder: down or up by under 0.001, only the largest remainders up.
	local function oddsProblem(list, want)
		local lowestUp, highestDown = math.huge, -math.huge
		for name, percent in want do
			local shown = shownThousandths(list, name)
			local exact = percent * 1000 + 1e-6 -- 24.166 * 1000 lands just under 24166
			local floor = math.floor(exact)
			local remainder = exact - floor
			if shown == floor then
				highestDown = math.max(highestDown, remainder)
			elseif shown == floor + 1 and remainder > 2e-6 then
				lowestUp = math.min(lowestUp, remainder)
			else
				return name .. " " .. shownOdds(list, name) .. " want about " .. string.format("%.5f%%", percent)
			end
		end
		return lowestUp < highestDown - 2e-6 and "not largest remainder" or nil
	end

	-- Section 6: every summon outcome, behind a button labelled "Details", read from the shown labels, sums to 100%.
	local function checkDetails(res, canvas)
		local button = canvas:FindFirstChild("Chances")
		check(res, "sidekick_details_button_shown", button ~= nil and h.visible(button), true)
		check(res, "sidekick_details_button_label", labelText(button, "Caption"), "Details")
		local list = h.find(DETAILS)
		check(res, "sidekick_details_present", list ~= nil, true)
		if not list then
			return
		end
		local view = public()
		if not view then
			return -- sidekick_rotation_attribute_readable already failed
		end
		check(res, "sidekick_public_has_odds", type(view.Odds), "table")
		local rows = waitFor(function()
			return oddsProblem(list, wantOdds(view))
		end)
		check(res, "sidekick_details_odds_match_server", rows or "right", "right")
		shownSum(res, "sidekick_details_sum_100", list, view)
		for _, id in view.Ids do
			check(res, "sidekick_details_name_" .. id, labelText(list:FindFirstChild(id), "Name"), Config.Get(id).Name)
		end
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
		local text = secretLine and table.concat(shownTexts(secretLine), " ") or ""
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

	-- A pity card follows its count: "%d / %d" and the track filled count / limit.
	local function pityProblem(canvas, index, count, limit)
		local want = ("%d / %d"):format(count, limit)
		local got = labelText(canvas, "PityCount" .. index)
		if got ~= want then
			return "PityCount" .. index .. " " .. got .. " want " .. want
		end
		local card = canvas:FindFirstChild("PityCard" .. index)
		local fill = card and card:FindFirstChild("Track") and card.Track:FindFirstChild("Progress")
		if not fill or math.abs(fill.Size.X.Scale - math.clamp(count / limit, 0, 1)) > 1e-3 then
			return "PityCard" .. index .. " track not at " .. count .. "/" .. limit
		end
		return nil
	end
	-- Fixture counts drive the pity cards and the Details odds (contract at the top).
	local function checkGuarantee(res, canvas)
		local request = ReplicatedStorage:FindFirstChild("UiTestSetupRequest")
		local list = h.find(DETAILS)
		local view = public()
		check(res, "sidekick_guarantee_parts", request ~= nil and list ~= nil, true)
		check(res, "sidekick_legendary_pity_label", string.lower(labelText(canvas, "Pity1")), "legendary")
		check(res, "sidekick_mythic_pity_label", string.lower(labelText(canvas, "Pity2")), "mythic")
		if not (request and view) then
			return
		end
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
				return pityProblem(canvas, 2, mythic, M) or pityProblem(canvas, 1, legendary, L)
			end)
			check(res, "sidekick_pity_cards_" .. tag, bars or "follow", "follow")
			if list then
				local want = wantOdds(view, tier)
				local odds = waitFor(function()
					return oddsProblem(list, want)
				end)
				check(res, "sidekick_guarantee_odds_" .. tag, odds or "right", "right")
				shownSum(res, "sidekick_guarantee_sum_100_" .. tag, list, view)
				check(res, "sidekick_guarantee_total_" .. tag, labelText(list, "Total"), "Total: 100%")
				local note = list:FindFirstChild("GuaranteedNote")
				if tier then
					local words = note and note:IsA("TextLabel") and string.lower(note.Text) or ""
					check(res, "sidekick_guarantee_note_present_" .. tag, note ~= nil and note.Visible, true)
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
		end
	end

	-- Off until turned on (SIDEKICK_SPEC "Summon page"): the fixture is a fresh save, and a toggle reaches the server both ways.
	-- The Auto-Sell dialog itself is judged after its real press (after.sidekicks_autosell_open).
	local function checkAutoSell(res, canvas)
		local button = canvas:FindFirstChild("AutoSell")
		check(res, "sidekick_autosell_button_shown", button ~= nil and h.visible(button), true)
		local rarities = {}
		for _, row in Config.List do
			if not table.find(rarities, row.Rarity) then
				table.insert(rarities, row.Rarity)
				check(
					res,
					"sidekick_autosell_off_by_default_" .. row.Rarity,
					View.AutoSell(h.player)[row.Rarity] == true,
					false
				)
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
				local on = View.AutoSell(h.player)[rarities[1]] == true
				return on ~= (word == "On") and "server still " .. (on and "On" or "Off") or nil
			end)
			check(res, "sidekick_autosell_server_" .. word, problem or word, word)
		end
	end

	local DESKTOP_PARTS = {
		"Balance",
		"Timer",
		"PityCard1",
		"PityCard2",
		"Chances",
		"Info",
		"Close",
		"AutoSell",
		"Once",
		"Many",
		"Auto",
		"Offer1",
		"Offer2",
		"More",
	}
	local function checkDesktopFit(res, canvas)
		local size = workspace.CurrentCamera.ViewportSize
		if size.Y <= PHONE_MAX_HEIGHT then
			return -- this scenario judges the fit at desktop only
		end
		local screen = { x = 0, y = 0, w = size.X, h = size.Y }
		local parts, outside, overlaps, covered = {}, {}, {}, {}
		for _, name in DESKTOP_PARTS do
			local part = canvas:FindFirstChild(name)
			check(res, "sidekick_part_present_" .. name, part ~= nil and h.visible(part), true)
			if part then
				table.insert(parts, part)
			end
		end
		for i, part in parts do
			local r = h.rect(part)
			if not within(screen, r) then
				table.insert(outside, part.Name)
			end
			for j = i + 1, #parts do
				if crossing(r, h.rect(parts[j])) then
					table.insert(overlaps, part.Name .. " x " .. parts[j].Name)
				end
			end
			local button = part:IsA("GuiButton") and part or part:FindFirstChildWhichIsA("GuiButton")
			if button then
				local b = h.rect(button)
				local top = h.topAt(b.x + b.w / 2, b.y + b.h / 2)
				if not (top and (top == button or button:IsAncestorOf(top))) then
					table.insert(covered, h.pathOf(button) .. " under " .. (top and h.pathOf(top) or "nothing"))
				end
			end
		end
		h.checkList(res, "sidekick_parts_on_screen_desktop", outside)
		h.checkList(res, "sidekick_parts_no_overlap_desktop", overlaps)
		h.checkList(res, "sidekick_buttons_topmost_desktop", covered)
		-- The featured names stay on screen and clear of each other (they follow their models).
		local names, crossed = {}, {}
		for i = 1, 3 do
			local label = canvas:FindFirstChild("Unit" .. i)
			if label then
				table.insert(names, label)
				check(res, "sidekick_featured_name_on_screen_" .. i, within(screen, h.rect(label)), true)
			end
		end
		for i, a in names do
			for j = i + 1, #names do
				if crossing(h.rect(a), h.rect(names[j])) then
					table.insert(crossed, a.Name .. " x " .. names[j].Name)
				end
			end
		end
		h.checkList(res, "sidekick_featured_names_no_overlap_desktop", crossed)
	end

	-- What the screen takes over while open, and must give back on close (SIDEKICK_SPEC "Summon presentation").
	local function worldState()
		local camera = workspace.CurrentCamera
		local character = h.player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local state = {
			CameraType = camera.CameraType,
			FieldOfView = camera.FieldOfView,
			CameraSubject = camera.CameraSubject,
			WalkSpeed = hum and hum.WalkSpeed,
			JumpPower = hum and hum.JumpPower,
			Hud = h.find("RacerHud") and h.find("RacerHud").Enabled,
		}
		for _, key in LIGHTING_KEYS do
			state[key] = Lighting[key]
		end
		for _, effect in Lighting:GetChildren() do
			if effect:IsA("PostEffect") then
				state["Effect " .. effect.Name] = effect.Enabled
			end
		end
		return state
	end
	-- The world is out of sight while open (replaces the old page's blur, SIDEKICK_SPEC "Summon page": the galaxy stage is
	-- full screen, SIDEKICK_SPEC "Summon presentation").
	local function checkOpenStage(res)
		local problem = waitFor(function()
			local camera = workspace.CurrentCamera
			if not stage() then
				return "no " .. STAGE .. " in workspace"
			end
			if camera.CameraType ~= Enum.CameraType.Scriptable then
				return "camera " .. tostring(camera.CameraType)
			end
			local centre = stage():FindFirstChild("Units") and stage().Units:FindFirstChild("Unit2")
			if not (centre and centre:IsA("Model")) then
				return "no Units/Unit2"
			end
			local _, onScreen = camera:WorldToViewportPoint(centre:GetPivot().Position)
			return not onScreen and "camera not on the stage" or nil
		end)
		check(res, "sidekick_stage_shown_while_open", problem or "shown", "shown")
		check(res, "sidekick_lighting_marked_while_open", Lighting:GetAttribute("SummonPreviewActive"), true)
		local character = h.player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		check(res, "sidekick_player_held_while_open", hum and hum.WalkSpeed, 0)
	end
	local function checkClosed(res, before)
		local now = worldState()
		local changed = {}
		for key, value in before do
			if now[key] ~= value then
				table.insert(changed, ("%s %s (was %s)"):format(key, tostring(now[key]), tostring(value)))
			end
		end
		h.checkList(res, "sidekick_close_restores_world", changed)
		check(res, "sidekick_close_removes_stage", stage(), nil)
		check(res, "sidekick_close_clears_lighting_mark", Lighting:GetAttribute("SummonPreviewActive"), nil)
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
		-- The HUD's Gems row moved under Money (design doc 4.40, owner 2026-11-10; Client/RollToast/RacerUiController).
		checkGemIcon(res, "sidekick_hud_gem_icon", h.find("RacerHud/Money/Gems/GemIcon"), Icons.Gem.Image)
		local canvas = h.find(CANVAS)
		check(res, "sidekick_panel_present", canvas ~= nil, true)
		if not canvas then
			return
		end
		check(res, "sidekick_stage_absent_while_closed", stage(), nil)
		local before = worldState()
		local restore = h.setPanels({ CANVAS })
		check(res, "sidekick_panel_opens", h.visible(canvas), true)
		checkOpenStage(res)
		checkGemsAndCosts(res, canvas)
		checkFeatured(res, canvas)
		checkNoPortraits(res, canvas)
		checkTimer(res, canvas)
		checkDetails(res, canvas)
		checkAutoSell(res, canvas)
		checkMoreGems(res, canvas)
		checkDesktopFit(res, canvas)
		checkSlotChange(res, canvas)
		checkGuarantee(res, canvas)
		restore()
		checkClosed(res, before)
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
		-- Owner 2026-11-05: tiles open Client/ItemMenu (the sidekicks_menu_* clicks, UiRelics); the Bag's action row is gone.
		check(res, "sidekick_actions_row_gone", h.find("RacerBackpack/Panel/SidekickActions"), nil)
	end

	-- After a real press of Details (Canvas/Chances) or the featured banner (Canvas/Banner1): the dialog shows the odds list,
	-- and no summon can be pressed through it.
	function after.sidekicks_details_open(res)
		local modal, list = h.find(MODAL), h.find(DETAILS)
		check(res, "sidekick_details_opened", modal ~= nil and h.visible(modal), true)
		check(res, "sidekick_details_list_shown", list ~= nil and h.visible(list), true)
		local once = h.find(CANVAS .. "/Once")
		local r = once and h.rect(once)
		local top = r and h.topAt(r.x + r.w / 2, r.y + r.h / 2)
		check(
			res,
			"sidekick_page_steps_aside_for_details",
			top ~= nil and modal ~= nil and top:IsDescendantOf(modal),
			true
		)
	end

	-- After a real press of Auto Sell: one line per rarity, each off on the fresh fixture, and no odds list in the way.
	function after.sidekicks_autosell_open(res)
		local modal, actions = h.find(MODAL), h.find(ACTIONS)
		check(res, "sidekick_autosell_opened", modal ~= nil and h.visible(modal), true)
		local list = h.find(DETAILS)
		check(res, "sidekick_autosell_hides_details", list ~= nil and h.visible(list), false)
		local lines = actions and shownTexts(actions) or {}
		local rarities = {}
		for _, row in Config.List do
			if not table.find(rarities, row.Rarity) then
				table.insert(rarities, row.Rarity)
				local found = "missing"
				for _, text in lines do
					if string.find(text, row.Rarity, 1, true) == 1 then
						found = string.upper(text)
					end
				end
				check(res, "sidekick_autosell_line_" .. row.Rarity, found ~= "missing", true)
				check(res, "sidekick_autosell_line_off_" .. row.Rarity, string.find(found, "OFF", 1, true) ~= nil, true)
			end
		end
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

	-- After a real Summon 1x (Canvas/Once) press: the reveal shows a model, its own name and rarity, never only a name tile.
	function after.sidekicks_reveal_models(res)
		local problem = waitFor(function()
			local layer = revealPart("Stage/Showcase")
			if not layer then
				return "reveal not shown"
			end
			return modelProblem(layer)
		end)
		check(res, "sidekick_reveal_model", problem or "shown", "shown")
		check(res, "sidekick_reveal_page_steps_aside", h.player.PlayerGui[GUI].Enabled, false)
		revealEnded(res, WAIT)
		local layer, rarity = revealPart("Stage/Showcase"), "no row of that name"
		for _, row in Config.List do
			if row.Name == labelText(layer, "Name") then
				rarity = row.Rarity
			end
		end
		check(res, "sidekick_reveal_rarity_matches", labelText(layer, "Rarity"), rarity)
	end

	-- After a real Summon 10x (Canvas/Many) press on scripted rolls (sidekick_big_reveal): each Mythic and Secret interrupts with
	-- its own showcase, which goes away again; every card ends face up with its own result.
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
		check(res, "sidekick_big_page_steps_aside", h.player.PlayerGui[GUI].Enabled, false)
		-- A Mythic resets only its own count; a Secret resets nothing (design doc 4.36).
		check(res, "sidekick_big_mythic_pity", h.player:GetAttribute("SidekickPity"), mythicPity)
		check(res, "sidekick_big_legendary_pity", h.player:GetAttribute("SidekickLegendaryPity"), legendaryPity)
		check(res, "sidekick_big_all_kept", #View.Bag(h.player), #Config.List + #Config.BossDrops + #ids)
	end

	-- After the press that ends a reveal: gone, with the screen back as it stood (its stage with it).
	function after.sidekicks_reveal_closed(res)
		local gui = h.player.PlayerGui
		check(res, "sidekick_reveal_gone", gui:FindFirstChild(REVEAL) == nil, true)
		check(res, "sidekick_page_back", gui[GUI].Enabled, true)
		local canvas = h.find(CANVAS)
		local back = waitFor(function()
			return not (canvas and canvas.Visible) and "screen not back" or nil
		end)
		check(res, "sidekick_screen_back", back or "back", "back")
		check(res, "sidekick_stage_follows_screen", stage() ~= nil, canvas ~= nil and canvas.Visible)
	end

	return { Scenarios = scenarios, After = after }
end

return Module
