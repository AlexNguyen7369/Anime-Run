--!nonstrict
-- The Golden King, the third boss (design doc 4.37 "Third boss", docs/BOSS_EVENT_SPEC.md "The Golden King"; boss-king task k7).
-- Owned by ui-test-writer. Red first: written before Client/BossKing, Client/BossKingVfx, the vault dressing and the Fortified
-- notice. Driven by UiTestSetup boss_ui_* fixtures, as UiBossMage.
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   Shared/BossCatalog row boss_king (FortifiedText); Shared/BossKingArt (KeyIcon, Portrait, StatusFortified);
--     BossDodge.Moment(index, "boss_king") named gates, enuma, shields.
--   Client/BossEventUi: texts, versus portrait and BossBar/Title follow BossEventBoss = boss_king as the mage's do. Fortified: when
--     ReplicatedStorage attribute BossFortified turns true (the server also lists { Id = "Fortified", Count = 1 } in BossStatus;
--     the fixture here sets both), a TextLabel somewhere under RacerBossEvent shows "The Golden King has fortified his defenses"
--     in the hit header's red, and BossBar/Status/Status_Fortified shows with Icon = BossKingArt.StatusFortified and no seconds
--     (no Seconds label, or one hidden or blank). Both go when the attribute turns false and the row is gone.
--   Client/BossDodgeUi: DodgeBar/Wheel.Image is BossKingArt.KeyIcon for his gates and enuma moments; no bar around a shields moment.
--   Bosses cards: Card_boss_king as the mage's card; BossDetails column Card_relic_chest_king, Title_relic_chest_king and rows
--     King_<relicId> (the mage's are Mage_<relicId>). Fixtures boss_ui_invite_king and boss_ui_idle_next_king (UiSpec.ServerSetup).
--   Rewards popup: Chest_relic_chest_king with RelicConfig.Chests.relic_chest_king.Image; title "The Golden King Defeated!".
--   Arena (Client/BossArenaView + BossColosseum "vault" dressing): workspace.BossArenaPreview holds Model GoldenKing (part Torso)
--     and a Folder or Model named Vault; no ElfMage, Golem or BigRaga while BossEventBoss is boss_king. Primitives <= 1,150.
--   Effects (Client/BossKingVfx, under BossEffects; BossVfxForce plays Gates, Enuma, Shields):
--     Gates: 12 to 20 instances named Portal, projectiles or beams named Streak; DEBUG FIELD LastStrikes as the mage's,
--       {"Move":"Gates","Strikes":[{"T":<s>,"Spots":[[x,z],...]},...]}: 14 volleys at 0, 0.15, ... 1.95 s, 7 to 10 spots each,
--       3 each under REDUCED EFFECTS.
--     Enuma: an instance named ChargeTint (dropped under REDUCED EFFECTS), then one named EnumaBeam.
--     Shields: an instance named ShieldRing with 5 to 7 descendants named Shield; the shields stay under REDUCED EFFECTS.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("BossEventConfig"))
local RelicConfig = require(Shared:WaitForChild("RelicConfig"))
-- pcall: a BossDodge that fails to load (its pose modules) fails these scenarios, not the whole UI harness.
local _, BossDodge = pcall(require, Shared:WaitForChild("BossDodge"))

local KING = "boss_king"
local ROOT = "RacerBossEvent"
local INVITE = ROOT .. "/Invite"
local HUD = ROOT .. "/TeamHud"
local WARNING = ROOT .. "/Warning"
local BAR = ROOT .. "/BossBar"
local BOSSES = ROOT .. "/BossesPanel"
local CARDS = BOSSES .. "/Cards"
local DODGE = "RacerBossDodge/DodgeBar"
local RESULT = "RacerBossDodge/Result"
local POPUP = "RacerBossRewards/Panel"

-- BOSS_EVENT_SPEC "The Golden King" (texts proposed except the move chat lines and the Enuma hit text).
local NAME = "The Golden King"
local WARNING_TEXT = "The Golden King has arrived, take him down!!!"
local INVITE_TITLE = "THE GOLDEN KING EVENT"
local INVITE_HINT = "Teleport to fight The Golden King before the timer ends"
local DEFEATED_TITLE = "The Golden King Defeated!"
local GATES_HIT = "The King's treasures struck you"
local FORTIFIED_NOTICE = "The Golden King has fortified his defenses"
local KING_CHEST = "relic_chest_king"
local SHOW_WAIT = 2
local BUILD_WAIT = 8
local PRIMITIVE_MAX = 1150 -- the colosseum's part cap holds for the vault
local PEAK_WATCH = 1.5
local VOLLEY_COUNT, VOLLEY_EVERY, VOLLEY_TIME_SLACK = 14, 0.15, 0.02
local PER_VOLLEY_MIN, PER_VOLLEY_MAX, PER_VOLLEY_REDUCED = 7, 10, 3
local PORTALS_MIN, PORTALS_MAX = 12, 20
local SHIELDS_MIN, SHIELDS_MAX = 5, 7
local SCAN = 40

local Module = {}

local function optional(name)
	local source = Shared:FindFirstChild(name)
	local ok, value = pcall(function()
		return source and require(source)
	end)
	return ok and type(value) == "table" and value or nil
end

local function isRed(color)
	return typeof(color) == "Color3" and color.R > 0.85 and color.G < 0.35 and color.B < 0.35
end

function Module.Build(h)
	local scenarios, after = {}, {}
	local function check(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local function setup(res, request)
		local ok, err = h.requestSetup(request)
		if not ok then
			h.check(res, "setup_" .. request, tostring(err), "ok", false)
		end
	end
	local function state(res, phase, elapsed, hp, max, inEvent, damage)
		setup(
			res,
			("boss_ui_state:%s:%s:%s:%s:%s:%s"):format(
				phase,
				tostring(elapsed),
				tostring(hp or 0),
				tostring(max or 0),
				tostring(inEvent == true),
				tostring(damage or "none")
			)
		)
	end
	local function boss(res, id)
		setup(res, "boss_ui_boss:" .. (id or "none"))
	end
	local function shown(path)
		local object = h.find(path)
		return object ~= nil and object:IsA("GuiObject") and h.visible(object)
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
	local function waitShown(path, want, seconds)
		return waitIs(function()
			return shown(path)
		end, want, seconds)
	end
	local function waitFor(fn, seconds)
		local deadline = os.clock() + seconds
		local value = fn()
		while not value and os.clock() < deadline do
			task.wait(0.05)
			value = fn()
		end
		return value
	end
	local function hasText(path, text)
		local root = h.find(path)
		for _, d in root and root:GetDescendants() or {} do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text == text and h.visible(d) then
				return d
			end
		end
		return nil
	end
	local function textOf(path)
		local label = h.find(path)
		return label and (label:IsA("TextLabel") or label:IsA("TextButton")) and label.Text or ""
	end
	local function firstMoment(name)
		for index = 1, SCAN do
			local at, got = BossDodge.Moment(index, KING)
			if got == name then
				return index, at
			end
		end
		return nil
	end
	local function cardOf(id)
		return h.find(CARDS .. "/Card_" .. id)
	end
	local function pillOf(card)
		local child = textOf(card .. "/Pill/Text")
		return child ~= "" and child or textOf(card .. "/Pill")
	end
	local function stateOf(id)
		local card = cardOf(id)
		return card and card:GetAttribute("State")
	end
	-- Every visible GuiObject under `path` sits inside BossesPanel's rect (2 px slack); returns the names that do not.
	local function outsidePanel(path)
		local panel, root = h.find(BOSSES), h.find(path)
		local out = {}
		if not (panel and root) then
			return { "missing " .. path }
		end
		local p = h.rect(panel)
		for _, d in root:GetDescendants() do
			if d:IsA("GuiObject") and h.visible(d) then
				local r = h.rect(d)
				if r.x < p.x - 2 or r.y < p.y - 2 or r.x + r.w > p.x + p.w + 2 or r.y + r.h > p.y + p.h + 2 then
					table.insert(out, d.Name)
				end
			end
		end
		return out
	end

	-- Per-boss texts and the versus portrait.
	function scenarios.ui_boss_king(res)
		h.waitGuis()
		local Catalog, Art = optional("BossCatalog"), optional("BossKingArt")
		check(res, "king_catalog_loads", Catalog ~= nil, true)
		check(res, "king_art_loads", Art ~= nil, true)
		check(res, "king_in_catalog_order", Catalog and table.find(Catalog.Order, KING) ~= nil, true)
		local hp = Cfg.HpPerPlayer
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			state(res, "Idle", 0)
			boss(res, KING)
			state(res, "Prep", 5, 0, 0, false)
			check(res, "king_invite_shown", waitShown(INVITE, true), true)
			check(
				res,
				"king_invite_title",
				waitIs(function()
					return hasText(INVITE, INVITE_TITLE) ~= nil
				end, true),
				true
			)
			check(res, "king_invite_hint", hasText(INVITE, INVITE_HINT) ~= nil, true)

			state(res, "Prep", 5, hp, hp, true, 1234)
			check(res, "king_team_hud_shown", waitShown(HUD, true), true)
			local portrait = h.find(HUD .. "/RagaPortrait")
			check(
				res,
				"king_versus_portrait",
				waitIs(function()
					return portrait and portrait.Image
				end, Art and Art.Portrait),
				Art and Art.Portrait
			)

			state(res, "Prep", Cfg.PrepSeconds - 0.5, hp, hp, true, 100)
			waitShown(HUD, true)
			state(res, "Fight", "keep", hp, hp, true, 100)
			check(res, "king_bar_shown", waitShown(BAR, true), true)
			check(
				res,
				"king_warning_text",
				waitIs(function()
					return hasText(WARNING, WARNING_TEXT) ~= nil
				end, true),
				true
			)
			check(
				res,
				"king_bar_title",
				waitIs(function()
					return textOf(BAR .. "/Title")
				end, NAME),
				NAME
			)
			-- No golem bar for him: no miniboss.
			check(res, "king_no_minion_bar", shown(BAR .. "/MinionBar"), false)

			boss(res, nil)
			check(
				res,
				"raga_bar_title_back",
				waitIs(function()
					return textOf(BAR .. "/Title")
				end, "Big Raga"),
				"Big Raga"
			)
		end, debug.traceback)
		h.check(res, "king_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		setup(res, "restore:boss_ui")
	end

	-- After the real press (UiSpec.Clicks boss_king_button; his event in Prep, the player outside): his card is the live one.
	function after.boss_king_panel_judging(res)
		check(res, "king_panel_opens", waitShown(BOSSES, true), true)
		local card = CARDS .. "/Card_" .. KING
		check(
			res,
			"king_card_live",
			waitIs(function()
				return stateOf(KING)
			end, "Live"),
			"Live"
		)
		check(res, "king_card_large", cardOf(KING) and cardOf(KING):GetAttribute("Large"), true)
		check(res, "king_card_tag_live", textOf(card .. "/Tag"), "LIVE")
		check(res, "king_card_go_shown", shown(card .. "/Go"), true)
		for _, other in { "boss_raga", "boss_mage" } do
			check(res, other .. "_card_other_in_his_event", stateOf(other), "Other")
			check(res, other .. "_card_dimmed_in_his_event", shown(CARDS .. "/Card_" .. other .. "/Dim"), true)
		end
		h.checkList(res, "king_cards_inside_panel_live", outsidePanel(CARDS))
	end

	-- After the real press (UiSpec.Clicks boss_cards_next_king): no event, his card announced next.
	function after.boss_cards_next_king(res)
		check(res, "king_cards_panel_opens", waitShown(BOSSES, true), true)
		local card = CARDS .. "/Card_" .. KING
		check(
			res,
			"king_card_next",
			waitIs(function()
				return stateOf(KING)
			end, "Next"),
			"Next"
		)
		check(res, "king_card_next_large", cardOf(KING) and cardOf(KING):GetAttribute("Large"), true)
		check(res, "king_card_tag_next", textOf(card .. "/Tag"), "NEXT")
		check(res, "king_card_pill_next_event", string.match(pillOf(card), "^Next event in %d+:%d%d$") ~= nil, true)
		check(res, "king_card_no_go_idle", shown(card .. "/Go"), false)
		for _, other in { "boss_raga", "boss_mage" } do
			check(res, other .. "_card_other_king_next", stateOf(other), "Other")
			check(res, other .. "_card_pill_not_this_time", pillOf(CARDS .. "/Card_" .. other), "Not this time")
		end
		h.checkList(res, "king_cards_inside_panel_next", outsidePanel(CARDS))
	end

	-- After his card's Details press (UiSpec.Clicks boss_king_details): his chest's table over the cards, his Sidekick's odds row.
	function after.boss_king_details_open(res)
		check(res, "king_details_shown", waitShown(BOSSES .. "/BossDetails", true), true)
		local details = BOSSES .. "/BossDetails"
		local chest = RelicConfig.Chests[KING_CHEST]
		check(res, "king_details_column_shown", shown(details .. "/Card_" .. KING_CHEST), true)
		check(res, "king_details_title", textOf(details .. "/Title_" .. KING_CHEST), chest and chest.Name)
		for _, other in { "relic_chest_raga", "relic_chest_mage" } do
			check(res, "king_details_hides_" .. other, shown(details .. "/Title_" .. other), false)
		end
		local sum, off = 0, {}
		for _, row in RelicConfig.ChestOdds(KING_CHEST) do
			local path = details .. "/King_" .. row.Id
			local percent = tonumber(string.match(textOf(path), "([%d%.]+)%%"))
			h.check(res, "king_details_odds_" .. row.Id, percent, row.Odds, percent == row.Odds)
			sum += percent or 0
			if not shown(path) then
				table.insert(off, row.Id)
			end
		end
		h.check(res, "king_details_sum_100", sum, 100, math.abs(sum - 100) < 1e-6)
		h.checkList(res, "king_details_rows_shown", off)
		-- Design doc 4.37: the Sidekick's odds shown with the Relic odds, as its own row.
		local sideRow = details .. "/King_side_king"
		check(res, "king_details_sidekick_row_shown", shown(sideRow), true)
		check(res, "king_details_sidekick_percent", string.find(textOf(sideRow), "0.001%", 1, true) ~= nil, true)
		h.checkList(res, "king_details_inside_panel", outsidePanel(details))
	end

	-- The Key of Babylon on the Dodge bar for Gates and Enuma; no bar around Shields.
	function scenarios.ui_boss_king_dodge(res)
		local Art = optional("BossKingArt")
		check(res, "king_art_loads", Art ~= nil, true)
		local hp = Cfg.HpPerPlayer
		local lead = BossDodge.SweepFor(1) * 0.5
		local ok, err = xpcall(function()
			for _, name in { "gates", "enuma" } do
				local index, at = firstMoment(name)
				check(res, "king_" .. name .. "_moment_found", index ~= nil, true)
				if index then
					state(res, "Idle", 0)
					boss(res, KING)
					state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + at - lead, hp, hp, true, 100)
					check(res, "king_dodge_bar_shown_" .. name, waitShown(DODGE, true, lead), true)
					local bar = h.find(DODGE)
					local wheel = bar and bar:FindFirstChild("Wheel")
					check(res, "king_dodge_key_icon_" .. name, wheel and wheel.Image, Art and Art.KeyIcon)
					if name == "gates" then
						check(res, "king_dodge_hit_shows", waitShown(RESULT, true, lead + 1), true)
						check(res, "king_dodge_hit_words", textOf(RESULT), GATES_HIT)
					end
				end
			end
			local index, at = firstMoment("shields")
			check(res, "king_shields_moment_found", index ~= nil, true)
			if index then
				state(res, "Idle", 0)
				boss(res, KING)
				state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + at - lead, hp, hp, true, 100)
				check(res, "king_no_dodge_bar_for_shields", waitShown(DODGE, true, lead + 0.5), false)
				check(res, "king_no_hit_text_for_shields", shown(RESULT), false)
			end
		end, debug.traceback)
		h.check(res, "king_dodge_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	-- Fortified (BOSS_EVENT_SPEC "The Golden King"): the red notice and the status icon under his HP bar, from BossFortified.
	-- The 40% damage cut is a server check (boss_king_event).
	function scenarios.ui_boss_fortified(res)
		h.waitGuis()
		local Art = optional("BossKingArt")
		check(res, "king_art_loads", Art ~= nil, true)
		local hp = Cfg.HpPerPlayer
		local savedFortified = ReplicatedStorage:GetAttribute("BossFortified")
		local savedStatus = h.player:GetAttribute("BossStatus")
		local CELL = BAR .. "/Status/Status_Fortified"
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			state(res, "Idle", 0)
			boss(res, KING)
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true, 100)
			check(res, "fortified_bar_shown", waitShown(BAR, true), true)
			check(res, "fortified_cell_hidden_before", shown(CELL), false)
			check(res, "fortified_notice_absent_before", hasText(ROOT, FORTIFIED_NOTICE), nil)
			ReplicatedStorage:SetAttribute("BossFortified", true)
			h.player:SetAttribute("BossStatus", HttpService:JSONEncode({ { Id = "Fortified", Count = 1 } }))
			local notice = waitFor(function()
				return hasText(ROOT, FORTIFIED_NOTICE)
			end, SHOW_WAIT)
			check(res, "fortified_notice_shown", notice ~= nil, true)
			check(res, "fortified_notice_red", notice ~= nil and isRed(notice.TextColor3), true)
			check(res, "fortified_cell_shown", waitShown(CELL, true), true)
			local cell = h.find(CELL)
			local icon, seconds = cell and cell:FindFirstChild("Icon"), cell and cell:FindFirstChild("Seconds")
			check(res, "fortified_icon_is_image", icon ~= nil and icon:IsA("ImageLabel"), true)
			check(res, "fortified_icon_art", icon and icon.Image, Art and Art.StatusFortified)
			local secondsText = seconds and seconds:IsA("TextLabel") and h.visible(seconds) and seconds.Text or ""
			check(res, "fortified_no_seconds", secondsText, "")
			local bar, rect = h.find(BAR), cell and h.rect(cell)
			if bar and rect then
				local b = h.rect(bar)
				h.check(res, "fortified_cell_under_bar", rect.y, ">= " .. (b.y + b.h - 1), rect.y >= b.y + b.h - 1)
			end
			ReplicatedStorage:SetAttribute("BossFortified", false)
			h.player:SetAttribute("BossStatus", nil)
			check(res, "fortified_cell_hides", waitShown(CELL, false), false)
			check(
				res,
				"fortified_notice_goes",
				waitIs(function()
					return hasText(ROOT, FORTIFIED_NOTICE) == nil
				end, true, 6),
				true
			)
		end, debug.traceback)
		h.check(res, "fortified_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		ReplicatedStorage:SetAttribute("BossFortified", savedFortified)
		h.player:SetAttribute("BossStatus", savedStatus)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	function scenarios.ui_boss_king_rewards(res)
		h.waitGuis()
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:1")
			state(res, "Idle", 0)
			setup(res, "boss_phase2_rewards:Defeated:1234567:true:false:false:0.12:" .. KING)
			check(res, "king_rewards_shown", waitShown(POPUP, true), true)
			check(
				res,
				"king_rewards_title",
				waitIs(function()
					return textOf(POPUP .. "/Header/Title")
				end, DEFEATED_TITLE),
				DEFEATED_TITLE
			)
			-- His chest's art, Phase 1's Money, no Gems (RELIC_SPEC "The Golden King's drops").
			local kingChest = POPUP .. "/Rewards/Chest_" .. KING_CHEST
			check(res, "king_rewards_chest_shown", waitShown(kingChest, true), true)
			local art = h.find(kingChest)
			local chestRow = RelicConfig.Chests[KING_CHEST]
			check(res, "king_rewards_chest_art", art and art.Image, chestRow and chestRow.Image)
			check(res, "king_rewards_no_raga_chest", shown(POPUP .. "/Rewards/Chest_relic_chest_raga"), false)
			check(res, "king_rewards_no_mage_chest", shown(POPUP .. "/Rewards/Chest_relic_chest_mage"), false)
			check(res, "king_rewards_money_shown", shown(POPUP .. "/Rewards/Money"), true)
			check(res, "king_rewards_no_gems", shown(POPUP .. "/Rewards/Gems"), false)
			setup(res, "boss_phase2_rewards:Defeated:1234567:true:false:false:0.12")
			check(
				res,
				"raga_rewards_title_kept",
				waitIs(function()
					return textOf(POPUP .. "/Header/Title")
				end, "Raga Defeated!"),
				"Raga Defeated!"
			)
			check(res, "raga_rewards_no_king_chest", shown(kingChest), false)
			boss(res, KING)
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, true)
			waitShown(POPUP, false)
			-- Owner 2026-11-11: the drop list is hidden in events; his odds stay in the Bosses popup's Details.
			check(res, "king_drop_list_hidden", waitShown(ROOT .. "/DropList", true), false)
			boss(res, nil)
		end, debug.traceback)
		h.check(res, "king_rewards_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	-- His vault, his model and his effects.
	function scenarios.ui_boss_king_vfx(res)
		local function inArena(name)
			local folder = workspace:FindFirstChild("BossArenaPreview")
			return folder and folder:FindFirstChild(name, true)
		end
		local function countNamed(root, name)
			local n = 0
			for _, d in root and root:GetDescendants() or {} do
				n += d.Name == name and 1 or 0
			end
			return n
		end
		local function peak(name)
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", name)
			local most, stop = 0, os.clock() + PEAK_WATCH
			while os.clock() < stop do
				local effects = inArena("BossEffects")
				local n = 0
				for _, d in effects and effects:GetDescendants() or {} do
					if d:IsA("BasePart") or d:IsA("ParticleEmitter") or d:IsA("Beam") then
						n += 1
					end
				end
				most = math.max(most, n)
				task.wait(0.05)
			end
			return most
		end
		-- Plays `name` and returns the most instances called `child` seen under BossEffects within PEAK_WATCH.
		local function mostNamed(name, child)
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", name)
			local most, stop = 0, os.clock() + PEAK_WATCH
			while os.clock() < stop do
				most = math.max(most, countNamed(inArena("BossEffects"), child))
				task.wait(0.05)
			end
			return most
		end
		local function volleyLog()
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			local holder = inArena("BossEffects")
			if holder then
				holder:SetAttribute("LastStrikes", nil)
			end
			ReplicatedStorage:SetAttribute("BossVfxForce", "Gates")
			local raw = waitFor(function()
				local now = inArena("BossEffects")
				return now and now:GetAttribute("LastStrikes")
			end, SHOW_WAIT)
			local decoded, log = pcall(HttpService.JSONDecode, HttpService, raw or "")
			return decoded and type(log) == "table" and log or nil
		end
		-- Task a5b-fx (BOSS_EVENT_SPEC "Gates portals and Ea's wind", "Impact layer"; design doc 4.37 "Rework approvals"). Contract
		-- (implementer: report a change, do not loosen):
		--   Portals: every Decal under each Portal part shows design C, the image id in Shared/BossVfxArt.PortalC (the ledger the
		--     king's effects read; BossKingArt.PortalC also accepted), Color3 white; a portal's Size (X or Y, the drawn disc) peaks
		--     at 1.25 x the old 14 / 10 / 7 studs (+/- 2%); it turns slowly about its facing (LookVector).
		--   Wind: BossVfxForce "Charge" makes a BasePart EnumaWind under BossEffects that follows Ea, its local Y along the orbit's
		--     axis; its Trails (enabled, faded at both ends: Transparency's first and last keypoints >= 0.8) ride Attachment0s
		--     orbiting that axis: 4 early in the charge, 6 near 2.75 s; the orbit turns once per 0.8 s early and once per 0.35 s near
		--     2.75 s (+/- 20%). Under REDUCED EFFECTS no enabled wind Trail (the strictest reading of "off or reduced").
		--   Ea's trail: an enabled Trail parented under the GoldenKing's Ea part (or whose Attachment0 is) during enuma's swing (3.0 s
		--     +/- 0.3, from the schedule), none at rest (the idle), none under REDUCED EFFECTS. LastStrikes stays as checked above.
		local WHITE_TOLERANCE = 0.01
		local OLD_PORTAL_SIZES = { 14, 10, 7 }
		local function portalArt()
			local art = optional("BossVfxArt") or {}
			return art.PortalC or (optional("BossKingArt") or {}).PortalC
		end
		-- Plays Gates and follows every Portal for `seconds`: { [portal] = { Peak, First, Last, Decals = { decal } } }.
		local function watchPortals(seconds)
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", "Gates")
			local seen, stop = {}, os.clock() + seconds
			while os.clock() < stop do
				for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
					if d.Name == "Portal" and d:IsA("BasePart") then
						local row = seen[d] or { Peak = 0, Decals = {} }
						seen[d] = row
						row.Peak = math.max(row.Peak, d.Size.X, d.Size.Y)
						row.First = row.First or { os.clock(), d.CFrame }
						row.Last = { os.clock(), d.CFrame }
						for _, decal in d:GetDescendants() do
							if decal:IsA("Decal") then
								row.Decals[decal] = true
							end
						end
					end
				end
				task.wait(0.05)
			end
			return seen
		end
		local function enabledTrails(root)
			local n = 0
			for _, d in root and root:GetDescendants() or {} do
				n += (d:IsA("Trail") and d.Enabled) and 1 or 0
			end
			return n
		end
		-- An enabled Trail on `part` (parented under it, or riding an attachment under it), seen within `seconds`.
		local function trailSeen(part, seconds)
			local stop = os.clock() + seconds
			repeat
				for _, d in workspace:GetDescendants() do
					if d:IsA("Trail") and d.Enabled then
						local a0 = d.Attachment0
						if d:IsDescendantOf(part) or (a0 and a0:IsDescendantOf(part)) then
							return true
						end
					end
				end
				task.wait(0.05)
			until os.clock() >= stop
			return false
		end
		-- The wind's orbit: turns a second of the first enabled Trail's Attachment0 about EnumaWind's local Y, from now for `seconds`.
		local function windTurnRate(seconds)
			local wind = inArena("EnumaWind")
			local trail = nil
			for _, d in wind and wind:GetDescendants() or {} do
				if d:IsA("Trail") and d.Enabled and d.Attachment0 then
					trail = trail or d
				end
			end
			if not (wind and wind:IsA("BasePart") and trail) then
				return nil
			end
			local function angle()
				local p = wind.CFrame:PointToObjectSpace(trail.Attachment0.WorldPosition)
				return math.atan2(p.Z, p.X)
			end
			local total, last, born = 0, angle(), os.clock()
			while os.clock() - born < seconds do
				task.wait()
				local now = angle()
				total += (now - last + math.pi) % (2 * math.pi) - math.pi
				last = now
			end
			return math.abs(total) / (2 * math.pi) / (os.clock() - born)
		end
		local function faded(trail)
			local keys = trail.Transparency.Keypoints
			return keys[1].Value >= 0.8 and keys[#keys].Value >= 0.8
		end
		-- 14 volleys at 0, 0.15, ... 1.95 s; per volley `least`..`most` projectiles or beams (BOSS_EVENT_SPEC "The Golden King").
		local function checkVolleys(tag, log, least, most)
			check(res, tag .. "_volley_log", log ~= nil and log.Move, "Gates")
			local list = log and log.Strikes or {}
			check(res, tag .. "_volley_count", #list, VOLLEY_COUNT)
			local offTime, offCount, total = {}, {}, 0
			for k, strike in list do
				local want = VOLLEY_EVERY * (k - 1)
				if type(strike.T) ~= "number" or math.abs(strike.T - want) > VOLLEY_TIME_SLACK then
					table.insert(offTime, ("%d at %s, want %.2f"):format(k, tostring(strike.T), want))
				end
				local n = type(strike.Spots) == "table" and #strike.Spots or 0
				total += n
				if n < least or n > most then
					table.insert(offCount, ("%d has %d"):format(k, n))
				end
			end
			h.checkList(res, tag .. "_volleys_every_0_15", offTime)
			h.checkList(res, tag .. "_per_volley_" .. least .. "_to_" .. most, offCount)
			return list
		end
		-- Across the whole arena: the centre, the lanes and the walkway, every quarter, none past the wall.
		local function checkSpread(tag, list, Arena)
			if not Arena then
				return
			end
			local outer = Arena.InnerRadius + Arena.Width
			local zones, quarters, outside = {}, {}, {}
			for _, strike in list do
				for _, spot in type(strike.Spots) == "table" and strike.Spots or {} do
					local dx, dz = (spot[1] or 0) - Arena.Center.X, (spot[2] or 0) - Arena.Center.Z
					local r = math.sqrt(dx * dx + dz * dz)
					zones[r < Arena.InnerRadius and "centre" or r <= outer and "lanes" or "walkway"] = true
					quarters[(dx >= 0 and 1 or 0) + (dz >= 0 and 2 or 0)] = true
					if r > Arena.WallRadius then
						table.insert(outside, ("%.0f"):format(r))
					end
				end
			end
			for _, zone in { "centre", "lanes", "walkway" } do
				check(res, tag .. "_spots_reach_" .. zone, zones[zone] == true, true)
			end
			local quarterCount = 0
			for _ in quarters do
				quarterCount += 1
			end
			check(res, tag .. "_spots_every_quarter", quarterCount, 4)
			h.checkList(res, tag .. "_spots_inside_wall", outside)
		end
		local savedReduce = h.player:GetAttribute("ReduceEffects")
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			h.player:SetAttribute("ReduceEffects", nil)
			state(res, "Idle", 0)
			boss(res, KING)
			state(res, "Prep", 5, 4000, 4000, true, 100)
			local king = waitFor(function()
				return inArena("GoldenKing")
			end, BUILD_WAIT)
			check(res, "king_model_present", king ~= nil and king:IsA("Model"), true)
			check(res, "king_target_part_present", king ~= nil and king:FindFirstChild("Torso", true) ~= nil, true)
			check(res, "vault_dressing_present", waitFor(function()
				return inArena("Vault") ~= nil
			end, BUILD_WAIT) == true, true)
			for _, other in { "ElfMage", "Golem", "BigRaga" } do
				check(res, other .. "_not_built_for_king", inArena(other), nil)
			end
			local primitives = 0
			local folder = workspace:FindFirstChild("BossArenaPreview")
			local effects = inArena("BossEffects")
			for _, d in folder and folder:GetDescendants() or {} do
				if d:IsA("BasePart") and not d:IsA("MeshPart") and not (effects and d:IsDescendantOf(effects)) then
					primitives += 1
				end
			end
			h.check(
				res,
				"vault_primitives",
				primitives,
				"<= " .. PRIMITIVE_MAX,
				primitives > 0 and primitives <= PRIMITIVE_MAX
			)
			if not king then
				return
			end
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 1, 4000, 4000, true, 100)

			local ArenaFor = (optional("BossArenaConfig") or {}).For
			local Arena = ArenaFor and ArenaFor(KING)
			check(res, "king_arena_config_loads", Arena ~= nil, true)
			-- Gates of Babylon: portals, then volleys of streaks over the whole arena.
			local portals = mostNamed("Gates", "Portal")
			h.check(
				res,
				"gates_portals_12_to_20",
				portals,
				PORTALS_MIN .. " to " .. PORTALS_MAX,
				portals >= PORTALS_MIN and portals <= PORTALS_MAX
			)
			h.check(res, "gates_streaks_drawn", mostNamed("Gates", "Streak"), "> 0", mostNamed("Gates", "Streak") > 0)
			-- Design C, the sun wheel (owner 2026-11-12): its image, white, 1.25 x the old sizes, turning slowly.
			local wantArt = portalArt()
			check(
				res,
				"portal_c_art_set",
				type(wantArt) == "string" and string.find(wantArt, "rbxassetid://", 1, true) == 1,
				true
			)
			local wrongArt, notWhite, offSize, turning, watched = {}, {}, {}, 0, 0
			for portal, row in watchPortals(2.6) do
				watched += 1
				for decal in row.Decals do
					if decal.Texture ~= wantArt then
						table.insert(wrongArt, tostring(decal.Texture))
					end
					local c = decal.Color3
					if math.min(c.R, c.G, c.B) < 1 - WHITE_TOLERANCE then
						table.insert(notWhite, tostring(c))
					end
				end
				if next(row.Decals) == nil then
					table.insert(wrongArt, portal:GetFullName() .. " has no decal")
				end
				local fits = false
				for _, old in OLD_PORTAL_SIZES do
					fits = fits or math.abs(row.Peak - 1.25 * old) <= 0.02 * 1.25 * old
				end
				if not fits then
					table.insert(offSize, ("%.2f"):format(row.Peak))
				end
				if row.First and row.Last and row.Last[1] - row.First[1] >= 0.5 then
					local a, b = row.First[2], row.Last[2]
					local turned = math.deg(math.acos(math.clamp(a.RightVector:Dot(b.RightVector), -1, 1)))
					local perSecond = turned / (row.Last[1] - row.First[1])
					turning += (turned > 1 and perSecond < 180) and 1 or 0
				end
			end
			check(res, "portals_watched", watched > 0, true)
			h.checkList(res, "portals_design_c_art", wrongArt)
			h.checkList(res, "portals_white", notWhite)
			h.checkList(res, "portals_1_25_x_size", offSize)
			h.check(res, "portals_turn_slowly", turning, "> 0", turning > 0)
			local list = checkVolleys("gates", volleyLog(), PER_VOLLEY_MIN, PER_VOLLEY_MAX)
			checkSpread("gates", list, Arena)
			-- Enuma Elish: the red charge tint, then the beam.
			h.check(
				res,
				"enuma_charge_tint",
				mostNamed("Enuma", "ChargeTint"),
				"> 0",
				mostNamed("Enuma", "ChargeTint") > 0
			)
			check(res, "enuma_beam_drawn", waitFor(function()
				return inArena("EnumaBeam") ~= nil
			end, 6) == true, true)
			-- The swirling wind (owner 2026-11-12): 4 ribbons, one turn per 0.8 s early; 6, one turn per 0.35 s near 2.75 s.
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", "Charge")
			local charged = os.clock()
			task.wait(0.1)
			local early = windTurnRate(0.4)
			local earlyTrails = enabledTrails(inArena("EnumaWind"))
			h.check(res, "wind_trails_4_early", earlyTrails, 4, earlyTrails == 4)
			h.check(
				res,
				"wind_turn_0_8_s_early",
				early,
				"1.25 +/- 20%",
				type(early) == "number" and math.abs(early - 1 / 0.8) <= 0.2 / 0.8
			)
			local fades = true
			for _, d in (inArena("EnumaWind") or workspace):GetDescendants() do
				if d:IsA("Trail") and inArena("EnumaWind") and d:IsDescendantOf(inArena("EnumaWind")) then
					fades = fades and faded(d)
				end
			end
			check(res, "wind_trails_faded_both_ends", earlyTrails > 0 and fades, true)
			task.wait(math.max(0, 2.55 - (os.clock() - charged)))
			local late = windTurnRate(0.4)
			local lateTrails = enabledTrails(inArena("EnumaWind"))
			h.check(res, "wind_trails_6_late", lateTrails, 6, lateTrails == 6)
			h.check(
				res,
				"wind_turn_0_35_s_late",
				late,
				"2.86 +/- 20%",
				type(late) == "number" and math.abs(late - 1 / 0.35) <= 0.2 / 0.35
			)
			-- Shield Gates: a ring of 5 to 7 shields.
			local shields = mostNamed("Shields", "Shield")
			check(res, "shields_ring_drawn", waitFor(function()
				return inArena("ShieldRing") ~= nil
			end, 1) == true, true)
			h.check(
				res,
				"shields_5_to_7",
				shields,
				SHIELDS_MIN .. " to " .. SHIELDS_MAX,
				shields >= SHIELDS_MIN and shields <= SHIELDS_MAX
			)
			local full = {}
			for _, name in { "Gates", "Enuma", "Shields" } do
				full[name] = peak(name)
				h.check(res, "full_" .. string.lower(name) .. "_effects", full[name], "> 0", full[name] > 0)
			end
			-- REDUCED EFFECTS (proposed): 3 per volley, the sky tint dropped, the shields stay.
			h.player:SetAttribute("ReduceEffects", true)
			for _, name in { "Gates", "Enuma" } do
				local reduced = peak(name)
				h.check(
					res,
					"reduced_" .. string.lower(name) .. "_fewer",
					reduced,
					"> 0 and < " .. full[name],
					reduced > 0 and reduced < full[name]
				)
			end
			checkVolleys("reduced_gates", volleyLog(), PER_VOLLEY_REDUCED, PER_VOLLEY_REDUCED)
			check(res, "reduced_enuma_no_tint", mostNamed("Enuma", "ChargeTint"), 0)
			local reducedShields = mostNamed("Shields", "Shield")
			h.check(
				res,
				"reduced_shields_stay",
				reducedShields,
				SHIELDS_MIN .. " to " .. SHIELDS_MAX,
				reducedShields >= SHIELDS_MIN and reducedShields <= SHIELDS_MAX
			)
			-- REDUCED EFFECTS: no wind ribbons, no trail on Ea.
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", "Charge")
			local reducedWind, windStop = 0, os.clock() + 3
			while os.clock() < windStop do
				reducedWind = math.max(reducedWind, enabledTrails(inArena("EnumaWind")))
				task.wait(0.1)
			end
			check(res, "reduced_no_wind_trails", reducedWind, 0)
			-- Ea's trail while it swings (BOSS_EVENT_SPEC "Impact layer"), from the schedule: the force off.
			ReplicatedStorage:SetAttribute("BossVfxForce", nil)
			local ea = king:FindFirstChild("Ea", true)
			check(res, "king_ea_part_present", ea ~= nil, true)
			local index, at = nil, nil
			for i = 1, SCAN do
				local t, name = BossDodge.Moment(i, KING)
				if name == "enuma" and not index then
					index, at = i, t
				end
			end
			if ea and index then
				local fight = Cfg.PrepSeconds + Cfg.IntroSeconds
				state(res, "Fight", fight + at - 0.3, 4000, 4000, true, 100)
				check(res, "reduced_no_ea_trail", trailSeen(ea, 0.6), false)
				h.player:SetAttribute("ReduceEffects", nil)
				state(res, "Fight", fight + 1, 4000, 4000, true, 100)
				check(res, "no_ea_trail_at_rest", trailSeen(ea, 1), false)
				state(res, "Fight", fight + at - 0.3, 4000, 4000, true, 100)
				check(res, "ea_trail_in_swing", trailSeen(ea, 0.6), true)
			end
		end, debug.traceback)
		h.check(res, "king_vfx_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		ReplicatedStorage:SetAttribute("BossVfxForce", nil)
		h.player:SetAttribute("ReduceEffects", savedReduce)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	return { Scenarios = scenarios, After = after }
end

return Module
