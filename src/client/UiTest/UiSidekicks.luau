--!nonstrict
-- Sidekick art wiring (design doc 4.36, 4.37, section 6; docs/SIDEKICK_SPEC.md "Summon presentation", "Summon page"). Owned by
-- ui-test-writer. ui_sidekicks judges the galaxy summon screen (owner 2026-11-12: "The Sidekick UI tests check the galaxy
-- screen's real elements"; "The galaxy screen as built is the rule"): the stage and its featured models and names, the odds
-- button, pity cards, Gem balance and icons, costs, Auto-Sell, More Gems, closing, the Index page and the desktop fit. Its
-- fixture is sidekick_states (UiScenarios.Needs). A press cannot be faked here, so the Bag art, the odds dialog (and its
-- guaranteed odds, fixture sidekick_pity_due), Auto-Sell and More Gems dialogs and the reveals are judged after real clicks
-- (UiSpec.Clicks sidekicks_*). sidekick_big_reveal scripts a 10x holding a Mythic and a Secret.
-- Screen contract (RacerSidekicks.rbxm, Client/SidekickUi): ScreenGui RacerSidekicks; Canvas is the panel PanelSwitch toggles.
--   Open: workspace holds the local stage SummoningStageLocal, Units/Unit1..3 each with one ActualSidekick model (Unit2 the
--   rotation's Mythic Igriz, Unit1 and Unit3 its Legendaries; no Rares, no rates), labels Canvas/Unit<i> (name) and
--   Canvas/Rarity<i>; the camera is Scriptable, the player cannot walk, Lighting has SummonPreviewActive. Closed: camera,
--   movement, lighting and HUD are as they were and the stage is gone (SIDEKICK_SPEC "Summon presentation").
--   Canvas/Balance shows the Gems (HudFormat.Short) with CurrencyGem; Canvas/Once and Canvas/Many show their cost with
--   CurrencyGem; Canvas/Timer shows m:ss to EndsAt; Canvas/Pity1+PityCount1+PityCard1 is Legendary pity, Pity2+PityCount2+
--   PityCard2 Mythic pity ("%d / %d", Track/Progress filled count / limit); Canvas/Featured is the sticker.
--   Canvas/Chances ("Show Chances") opens Canvas/Modal, whose Panel/DetailsScroll/Body lists every outcome of the rotation, one
--   line each holding the Sidekick's name (the Secret as "Secret") and its percent with 3 decimals. While a guarantee is due
--   (design doc 4.36, section 6: Mythic at SidekickPity >= PityCount - 1, else Legendary) the tier's lines share 100% evenly,
--   the others read 0.000%, and the text says "guaranteed". No silhouette row and no exact-100% rounding (owner 2026-11-12).
--   Auto Sell and More open the same Modal with rows under Panel/DetailsScroll/Actions.
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
	-- The Mythic and Legendaries of the rotation: what the stage features (SIDEKICK_SPEC "Summon presentation": "as built is the rule"; no Rares).
	-- Commons, Rares and the Secret are in the odds dialog only.
	local function featuredRows(view)
		local rows = {}
		for _, rarity in { "Mythic", "Legendary" } do
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

	-- The galaxy stage: the Mythic Igriz in the centre, the Legendaries beside it, actual 3D models, each one's name and rarity.
	-- No rates under the names and no Rares (SIDEKICK_SPEC "Summon presentation": "as built is the rule").
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
			end
		end
		local models = 0
		for _, d in stage() and stage():GetDescendants() or {} do
			models += (d:IsA("Model") and d.Name == "ActualSidekick") and 1 or 0
		end
		check(res, "sidekick_stage_models_only_featured", models, 3)
		checkScreenHides(res, canvas, view)
		local sticker = canvas:FindFirstChild("Featured")
		check(res, "sidekick_sticker_shown", sticker ~= nil and h.visible(sticker), true)
		check(res, "sidekick_sticker_no_odds_claim", string.find(labelText(canvas, "Featured"), "[%d%%]") ~= nil, false)
	end

	-- Models, not portraits, on the page (design doc 4.36 "Art in UI": portraits only in the index and Bag equip). The banner
	-- Canvas/Banner1 may show the Mythic's drawn portrait (SIDEKICK_SPEC "Summon presentation": "as built is the rule").
	local function checkNoPortraits(res, page)
		local banner = page:FindFirstChild("Banner1")
		local portraits, found = {}, {}
		for _, id in allIds() do
			if Art[id] and Art[id].Portrait then
				portraits[Art[id].Portrait] = id
			end
		end
		for _, d in page:GetDescendants() do
			local inBanner = banner ~= nil and (d == banner or d:IsDescendantOf(banner))
			if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and portraits[d.Image] and not inBanner then
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
			-- The buttons read "Once" and "Many" (SIDEKICK_SPEC "Summon presentation": "as built is the rule"; replaces "Summon 1x / 10x").
			local button = canvas:FindFirstChild(cost[1])
			check(
				res,
				"sidekick_summon_label_" .. cost[1],
				string.find(button and button.Text or "", cost[1], 1, true) == 1,
				true
			)
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

	-- More Gems: two pack cards and a "More" button, no badges (SIDEKICK_SPEC "Summon presentation": "as built is the rule"; replaces the four-pack
	-- column). The More dialog is judged after its real press (after.sidekicks_more_gems).
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

	-- The slot turns while the screen is open: the timer follows with nobody reopening it, and the featured Mythic stays Igriz
	-- (SIDEKICK_SPEC "Summon presentation"). The odds dialog is built on its press, so only the stage and timer can follow.
	local function checkSlotChange(res, canvas)
		local request = ReplicatedStorage:FindFirstChild("UiTestSetupRequest")
		local timer = canvas:FindFirstChild("Timer")
		check(res, "sidekick_slot_change_parts", request ~= nil and timer ~= nil, true)
		local before = public()
		if not (request and timer and before) then
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
			return nil
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

	-- Name -> percent each outcome must show. tier: the rarity a due guarantee pays; it shares 100%, the rest read 0.
	local function wantOdds(view, tier)
		local odds = {}
		if tier then
			local inTier = 0
			for _, id in view.Ids do
				inTier += Config.Get(id).Rarity == tier and 1 or 0
			end
			for _, id in view.Ids do
				odds[Config.Get(id).Name] = Config.Get(id).Rarity == tier and 100 / inTier or 0
			end
			odds.Secret = 0
			return odds
		end
		-- What the server rolls, from the replicated view alone.
		local served = view.Odds or {}
		odds.Secret = served[view.SecretId] or 0
		for _, id in view.Ids do
			odds[Config.Get(id).Name] = served[id] or 0
		end
		return odds
	end
	-- nil when the dialog has a line per outcome with its percent to 3 decimals (no exact-sum rule, owner 2026-11-12).
	local function dialogProblem(text, want)
		local lines = string.split(text, "\n")
		for name, percent in want do
			local shown = nil
			for _, line in lines do
				local starts = string.find(line, name, 1, true) == 1
				if starts and not (name == "Secret" and string.find(line, "•", 1, true)) then
					shown = tonumber(string.match(line, "([%d%.]+)%%%s*$"))
				end
			end
			if not shown then
				return "no line with a percent for " .. name
			end
			if math.abs(shown - percent) > 0.0006 then
				return ("%s shows %.3f%%, want %.3f%%"):format(name, shown, percent)
			end
		end
		return nil
	end
	local function dialogText()
		local body = h.find(MODAL .. "/Panel/DetailsScroll/Body")
		return body and h.visible(body) and body.Text or ""
	end
	-- Section 6: every outcome with its percent before any summon, behind the odds button. It reads "Show Chances"
	-- (SIDEKICK_SPEC "Summon presentation": "as built is the rule"; replaces the "Details" label); the dialog is judged after its press.
	local function checkDetails(res, canvas)
		local button = canvas:FindFirstChild("Chances")
		check(res, "sidekick_odds_button_shown", button ~= nil and h.visible(button), true)
		check(res, "sidekick_odds_button_label", labelText(button, "Caption"), "Show Chances")
		local view = public()
		check(res, "sidekick_public_has_odds", view and type(view.Odds), "table")
		if view then
			local liveIsAChoice = false
			for _, row in secretRows() do
				liveIsAChoice = liveIsAChoice or row.Id == view.SecretId
			end
			check(res, "sidekick_view_secret_id_is_a_choice", liveIsAChoice, true)
		end
	end
	-- After a real press of the odds button: tier nil, or the guarantee the fixture made due.
	local function checkDialogOdds(res, tag, tier)
		local modal, view = h.find(MODAL), public()
		check(res, "sidekick_odds_dialog_opened" .. tag, modal ~= nil and h.visible(modal), true)
		check(res, "sidekick_odds_rotation_readable" .. tag, view ~= nil, true)
		if not view then
			return
		end
		local problem = waitFor(function()
			return dialogProblem(dialogText(), wantOdds(view, tier))
		end)
		check(res, "sidekick_odds_dialog_lists_outcomes" .. tag, problem or "right", "right")
		local text = dialogText()
		-- The Secret's line never tells which one is live; boss drops and Sidekicks out of the slot are not outcomes.
		for _, rows in { secretRows(), Config.BossDrops } do
			for _, row in rows do
				check(res, "sidekick_odds_hides_" .. row.Id .. tag, string.find(text, row.Name, 1, true) ~= nil, false)
			end
		end
		for _, row in Config.List do
			if row.Rarity ~= "Secret" and not table.find(view.Ids, row.Id) then
				check(
					res,
					"sidekick_odds_out_of_rotation_" .. row.Id .. tag,
					string.find(text, row.Name, 1, true) ~= nil,
					false
				)
			end
		end
		local says = string.find(string.lower(text), "guaranteed", 1, true) ~= nil
		check(res, "sidekick_odds_guarantee_note" .. tag, says, tier ~= nil)
		if tier then
			check(
				res,
				"sidekick_odds_guarantee_tier" .. tag,
				string.find(text, tier .. " guaranteed", 1, true) ~= nil,
				true
			)
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
	-- Fixture counts drive the pity cards (design doc 4.36). The guaranteed odds are judged after a real press of the odds
	-- button on a due fixture (after.sidekicks_details_guaranteed): the dialog is built on its press.
	local function checkGuarantee(res, canvas)
		local request = ReplicatedStorage:FindFirstChild("UiTestSetupRequest")
		check(res, "sidekick_guarantee_parts", request ~= nil, true)
		check(res, "sidekick_legendary_pity_label", string.lower(labelText(canvas, "Pity1")), "legendary")
		check(res, "sidekick_mythic_pity_label", string.lower(labelText(canvas, "Pity2")), "mythic")
		if not request then
			return
		end
		local M, L = Config.PityCount, Config.LegendaryPityCount
		for _, step in
			{
				{ "none", 0, 0 },
				{ "one_short", M - 2, L - 2 },
				{ "mythic", M - 1, 0 },
				{ "legendary", 0, L - 1 },
				{ "legendary_held_over", 0, L }, -- a Mythic won the tie: the count stays over
				{ "back_to_none", 0, 0 },
			}
		do
			local tag, mythic, legendary = step[1], step[2], step[3]
			request:InvokeServer(("sidekick_ui_pity:%d:%d"):format(mythic, legendary))
			local bars = waitFor(function()
				return pityProblem(canvas, 2, mythic, M) or pityProblem(canvas, 1, legendary, L)
			end)
			check(res, "sidekick_pity_cards_" .. tag, bars or "follow", "follow")
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

	-- After a real press of the odds button (Canvas/Chances) or the featured banner (Canvas/Banner1), before any summon: the
	-- dialog lists every outcome with its percent, and no summon can be pressed through it.
	function after.sidekicks_details_open(res)
		checkDialogOdds(res, "", nil)
		local modal, once = h.find(MODAL), h.find(CANVAS .. "/Once")
		local r = once and h.rect(once)
		local top = r and h.topAt(r.x + r.w / 2, r.y + r.h / 2)
		check(
			res,
			"sidekick_page_steps_aside_for_details",
			top ~= nil and modal ~= nil and top:IsDescendantOf(modal),
			true
		)
	end
	-- The same press with the Mythic due (fixture sidekick_pity_due): the updated odds (section 6).
	function after.sidekicks_details_guaranteed(res)
		check(res, "sidekick_pity_due_fixture", h.player:GetAttribute("SidekickPity"), Config.PityCount - 1)
		checkDialogOdds(res, "_due", "Mythic")
	end

	-- After a real press of More: the More Gems dialog offers every pack, with its Gems and price.
	function after.sidekicks_more_gems(res)
		local modal, actions = h.find(MODAL), h.find(ACTIONS)
		check(res, "sidekick_more_gems_opened", modal ~= nil and h.visible(modal), true)
		local text = table.concat(actions and shownTexts(actions) or {}, "\n")
		for _, pack in Monetization.GemPacks do
			local line = string.find(text, pack.Name, 1, true) ~= nil
				and string.find(text, "R$" .. pack.RobuxPrice, 1, true) ~= nil
			check(res, "sidekick_more_gems_lists_" .. pack.Id, line, true)
		end
	end

	-- After a real press of Auto Sell: one line per rarity, each off on the fresh fixture, and no odds list in the way.
	function after.sidekicks_autosell_open(res)
		local modal, actions = h.find(MODAL), h.find(ACTIONS)
		check(res, "sidekick_autosell_opened", modal ~= nil and h.visible(modal), true)
		local body = h.find(MODAL .. "/Panel/DetailsScroll/Body")
		check(res, "sidekick_autosell_hides_odds", body ~= nil and h.visible(body), false)
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
