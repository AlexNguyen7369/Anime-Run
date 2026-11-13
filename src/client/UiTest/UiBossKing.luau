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
--   Arena (Client/BossArenaView): workspace.BossArenaPreview holds Model GoldenKing (part Torso) and his own arena, a Folder or
--     Model named KingArena (the vault is retired, owner 2026-11-12; see ui_boss_king_arena); no ElfMage, Golem or BigRaga while
--     BossEventBoss is boss_king.
--   Effects (Client/BossKingVfx, under BossEffects; BossVfxForce plays Gates, Enuma, Shields):
--     Gates: 16 to 22 instances named Portal, projectiles or beams named Streak; DEBUG FIELD LastStrikes as the mage's,
--       {"Move":"Gates","Strikes":[{"T":<s>,"Spots":[[x,z],...]},...]}: 14 volleys at 0, 0.15, ... 1.95 s, 7 to 10 spots each,
--       the same with effects off.
--     Enuma: an instance named ChargeTint, then one named EnumaBeam.
--     Shields: an instance named ShieldRing with 5 to 7 descendants named Shield.
--   Stronger Gates and Enuma (owner 2026-11-12 after playing; design doc 4.37 "Golden King effects stronger", BOSS_EVENT_SPEC
--     "Golden King effects", proposed), BaseParts under BossEffects; a "spawn" is a part becoming visible under the name
--     (pooled parts are renamed):
--     Order: each Portal reaches full size (98% of its peak) before its PortalTip (the nearest tip) shows (Transparency < 0.9);
--       every shot starts within 6 studs of a Portal whose tip already shows: a weapon's first piece, named Streak with a
--       non-Neon material, at its own position; a streak, named Streak and Neon, at its start end. On the schedule and forced.
--     Hits, over the move, at least as many as LastStrikes' spots: StrikeFlash gold and StrikeFlashCore white, ShockRing gold;
--       ParticleEmitters (or parts) named Sparks and HitDust during the volleys. Streaks: the Neon Streak at least 3 studs
--       thick (1.5 x 2) with a StreakCore white at least 1.05 (1.5 x 0.7).
--     Enuma: EnumaBeamCore white inside the beam; EnumaCyclone red or near-black, rolling about the beam (EnumaBeam) at least
--       10 deg in 0.3 s; EnumaHitBurst (red or white) and EnumaHitSmoke (dark), ParticleEmitter or part, within 30 studs (XZ)
--       of the beam's line, at most 20 studs over the deck.
--     None of these with effects off; the volley log stays the full plan.
--   Effects off (design doc 4.37 "Boss effects have no reduced version", BOSS_EVENT_SPEC "Effects setting", owner 2026-11-12;
--     replaces every reduced count): with ReduceEffects (or Roblox Reduced Motion) no visible BasePart and no enabled
--     ParticleEmitter, Beam or Trail under BossEffects, no portals, wind, trails, glow, flashes or shield ring; LastStrikes
--     still logs the full plan.
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
-- His own arena's part budget (BOSS_EVENT_SPEC "The Golden King's arena": target about 1,200, proposed; measured and reported).
local KING_ARENA_PARTS_MAX = 1250
local PEAK_WATCH = 1.5
local VOLLEY_COUNT, VOLLEY_EVERY, VOLLEY_TIME_SLACK = 14, 0.15, 0.02
local PER_VOLLEY_MIN, PER_VOLLEY_MAX = 7, 10
local PORTALS_MIN, PORTALS_MAX = 16, 22 -- BOSS_EVENT_SPEC "Golden King game matched to his sheets" (2026-11-12, proposed); was 12 to 20
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

	-- The jointed Golden King in game (design doc 4.37 "Rework approvals", BOSS_EVENT_SPEC "Animation rework"; task a1-bake).
	-- Contract (implementer: report a change, do not loosen): workspace.BossArenaPreview holds Model GoldenKing with BaseParts
	-- named as BossKingPoses.Bind: Torso, Head, Left/RightUpperArm, Left/RightLowerArm, Left/RightUpperLeg, Left/RightLowerLeg,
	-- Key, Ea, Ea_Drum1..3, and none of LeftArm, RightArm, LeftLeg, RightLeg. Ea's axis is read from Ea_Drum1 to Ea_Drum3 (the
	-- drums sit along it). A sanity check that enuma plays on the jointed rig, not exact numbers: at 1.7 s (charge, arm up) Ea is
	-- upright and the lower right arm above the upper; at 3.05 s (the swing, key 7 "levelled at the arena") Ea is near level
	-- (within 30 deg) and the lower right arm below the upper. His hover is checked in ui_boss_king_arena (task a8-arena).
	function scenarios.ui_boss_king_rig(res)
		local JOINTED = {
			"Torso",
			"Head",
			"LeftUpperArm",
			"LeftLowerArm",
			"RightUpperArm",
			"RightLowerArm",
			"LeftUpperLeg",
			"LeftLowerLeg",
			"RightUpperLeg",
			"RightLowerLeg",
			"Key",
			"Ea",
			"Ea_Drum1",
			"Ea_Drum2",
			"Ea_Drum3",
		}
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			state(res, "Idle", 0)
			boss(res, KING)
			state(res, "Prep", 5, 4000, 4000, true, 100)
			local king = waitFor(function()
				local folder = workspace:FindFirstChild("BossArenaPreview")
				return folder and folder:FindFirstChild("GoldenKing", true)
			end, BUILD_WAIT)
			check(res, "rig_king_present", king ~= nil and king:IsA("Model"), true)
			if not king then
				return
			end
			local missing = {}
			for _, name in JOINTED do
				local part = king:FindFirstChild(name, true)
				if not (part and part:IsA("BasePart")) then
					table.insert(missing, name)
				end
			end
			h.checkList(res, "rig_jointed_parts", missing)
			for _, name in { "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
				check(res, "rig_no_unjointed_" .. name, king:FindFirstChild(name, true), nil)
			end
			local index, at = firstMoment("enuma")
			check(res, "rig_enuma_moment_found", index ~= nil, true)
			if not index or #missing > 0 then
				return
			end
			local function part(name)
				return king:FindFirstChild(name, true)
			end
			-- enuma's local time `localTime` (the moment is its 3.0 s cost event), then two frames to pose.
			local function at_(localTime)
				state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + at - 3 + localTime, 4000, 4000, true, 100)
				task.wait(0.1)
				local ea = part("Ea_Drum3").Position - part("Ea_Drum1").Position
				return ea.Magnitude > 0 and ea.Unit or Vector3.zero,
					part("RightLowerArm").Position.Y - part("RightUpperArm").Position.Y
			end
			local eaUp, armUp = at_(1.7)
			h.check(res, "rig_charge_ea_upright", eaUp.Y, ">= 0.8", eaUp.Y >= 0.8)
			h.check(res, "rig_charge_lower_arm_raised", armUp, "> 0", armUp > 0)
			local eaSwing, armSwing = at_(3.05)
			h.check(res, "rig_swing_ea_levelled", math.abs(eaSwing.Y), "<= 0.5", math.abs(eaSwing.Y) <= 0.5)
			h.check(res, "rig_swing_lower_arm_down", armSwing, "< 0", armSwing < 0)
			-- His hover over the mound is checked by the arena task (a8-arena): ui_boss_king_arena's king_feet_over_mound and
			-- king_hover_about_12 (it depends on his arena's mound and HoverY).
		end, debug.traceback)
		h.check(res, "king_rig_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		state(res, "Idle", 0)
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

	-- His own arena in game (design doc 4.37 "The Golden King's own arena", "Rework approvals"; BOSS_EVENT_SPEC "The Golden
	-- King's arena"; task a8-arena). Contract (implementer: report a change, do not loosen): workspace.BossArenaPreview holds a
	-- Folder or Model KingArena (his arena, every part of it under it) with the mound under a child named KingMound, and Model
	-- GoldenKing. Checks: the arena's BaseParts (MeshParts included) reported and <= 1,250; nothing on the lane band above the
	-- deck; nothing inside the ring over 12 studs but the mound; his feet (the lowest corner of his leg parts) about 12 over the
	-- mound's top; the camera's FOV 80 (owner 2026-11-12, was 60) for the whole event in his arena (no change during a move), 100
	-- in the mage's and Big Raga's; the sunset profile (BiomeEnvironment.Profile(ARENA_ZONE, "boss_king")) applied in his event, the zone's own after.
	function scenarios.ui_boss_king_arena(res)
		local Lighting = game:GetService("Lighting")
		local LANE_SLACK = 0.3 -- studs over the deck a lane line or paving piece may stand
		local INNER_MAX = 12
		local camera = workspace.CurrentCamera
		local function fov()
			return math.round(camera.FieldOfView * 100) / 100
		end
		local function corners(part)
			local list, half = {}, part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						table.insert(list, part.CFrame:PointToWorldSpace(half * Vector3.new(sx, sy, sz)))
					end
				end
			end
			return list
		end
		local hp = Cfg.HpPerPlayer
		local fovBefore = camera.FieldOfView
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			state(res, "Idle", 0)
			boss(res, KING)
			state(res, "Prep", 5, hp, hp, true, 100)
			local Arena = ((optional("BossArenaConfig") or {}).For or function() end)(KING)
			check(res, "king_arena_config_loads", Arena ~= nil, true)
			local arena = waitFor(function()
				local folder = workspace:FindFirstChild("BossArenaPreview")
				return folder and folder:FindFirstChild("KingArena", true)
			end, BUILD_WAIT)
			local king = waitFor(function()
				local folder = workspace:FindFirstChild("BossArenaPreview")
				return folder and folder:FindFirstChild("GoldenKing", true)
			end, BUILD_WAIT)
			check(res, "king_arena_built", arena ~= nil, true)
			check(res, "king_model_present", king ~= nil, true)
			if not (arena and Arena) then
				return
			end
			task.wait(1) -- the build may place its pieces over a few frames
			local mound = arena:FindFirstChild("KingMound", true)
			check(res, "king_mound_present", mound ~= nil, true)
			local parts, onLanes, tallInside, moundTop = 0, {}, {}, -math.huge
			local inner, outer = Arena.InnerRadius, Arena.InnerRadius + Arena.Width
			for _, d in arena:GetDescendants() do
				if d:IsA("BasePart") then
					parts += 1
					local rMin, rMax, top = math.huge, 0, -math.huge
					for _, c in corners(d) do
						local r = Vector2.new(c.X - Arena.Center.X, c.Z - Arena.Center.Z).Magnitude
						rMin, rMax, top = math.min(rMin, r), math.max(rMax, r), math.max(top, c.Y)
					end
					-- a part's footprint can span the band with every corner outside it: count its centre's reach too
					local centre = Vector2.new(d.Position.X - Arena.Center.X, d.Position.Z - Arena.Center.Z).Magnitude
					rMin = math.min(rMin, math.max(0, centre - Vector2.new(d.Size.X, d.Size.Z).Magnitude / 2))
					local isMound = mound ~= nil and (d == mound or d:IsDescendantOf(mound))
					if isMound then
						moundTop = math.max(moundTop, top)
					end
					if top > Arena.Y + LANE_SLACK and rMax > inner and rMin < outer then
						table.insert(onLanes, d.Name)
					end
					if not isMound and rMax < inner and top > Arena.Y + INNER_MAX then
						table.insert(tallInside, d.Name)
					end
				end
			end
			h.check(
				res,
				"king_arena_parts",
				parts,
				"<= " .. KING_ARENA_PARTS_MAX,
				parts > 0 and parts <= KING_ARENA_PARTS_MAX
			)
			h.checkList(res, "king_arena_lanes_clear", onLanes)
			h.checkList(res, "king_arena_inside_ring_under_12", tallInside)
			-- The camera in Prep (still Prep here; the hover below moves to the fight). FOV 80: owner change 2026-11-12 after playing
			-- (design doc 4.37 "Golden King camera"; was 60).
			check(res, "king_fov_80_in_prep", waitIs(fov, 80), 80)
			-- His hover (BOSS_EVENT_SPEC "The Golden King's arena": "hovers 12 studs over the mound's top and bobs 1.5 studs over
			-- 3 s"), in Fight after the rise (in Prep he is hidden far below) and in the cycle's first idle row (his moves dip the
			-- root on purpose), sampled over one full 3 s bob. king_hover_about_12 reads the rule's point: his rest sole (the
			-- rig's anchor, where the client puts Arena.Y + HoverY plus the bob), 12 +/- 0.75 over the mound's top (+/- 0.05
			-- slack). It is worked back from the live Torso: its joint (part CFrame less the bind's Center, through the rig's
			-- Blender-to-Roblox axes as Client/BossRaga) less the Torso's Offset and the sampled root. The lowest leg-box corner
			-- is no longer that point: the pre-approved idle keys bend the knees 20 to 36 deg with deep leg boxes, about 2 studs
			-- under the rest sole, so king_feet_over_mound is the clearance check: that corner stays over 7 studs above the mound.
			local gatesIndex, gatesAt = firstMoment("gates")
			local HOVER_FROM, HOVER_FOR = 0.3, 3.2 -- s into the fight
			check(
				res,
				"hover_window_in_idle",
				gatesIndex ~= nil and gatesAt - 1.6 - 0.75 >= HOVER_FROM + HOVER_FOR, -- before gates_in and its lead
				true
			)
			local posesOk, KingPoses = pcall(function()
				return require(Shared:WaitForChild("LateData")).Get("BossKingPoses")
			end)
			KingPoses = posesOk and type(KingPoses) == "table" and KingPoses or nil
			check(res, "king_poses_loads", KingPoses ~= nil, true)
			local torso = king and king:FindFirstChild("Torso", true)
			if king and torso and KingPoses and moundTop > -math.huge then
				local AXES =
					CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
				local row, scale = KingPoses.Bind.Torso, KingPoses.Scale
				local centre = CFrame.new(Vector3.new(row.Center[1], row.Center[2], row.Center[3]) * scale)
				local function soleHeight()
					local joint = (torso.CFrame * AXES * centre:Inverse() * AXES:Inverse()).Position
					-- the schedule start as Client/BossArenaView reads it: BossScheduleStart, else the spawn
					local start = ReplicatedStorage:GetAttribute("BossScheduleStart")
						or (ReplicatedStorage:GetAttribute("BossEventStart") or 0) + Cfg.PrepSeconds
					local move, localTime = KingPoses.Schedule(start, workspace:GetServerTimeNow())
					local _, root = KingPoses.Sample(move, localTime)
					return joint.Y - (row.Offset[3] * scale + root.Z) - moundTop -- Blender z is Roblox Y (AXES)
				end
				state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + HOVER_FROM, hp, hp, true, 100)
				task.wait(0.1)
				local low, high, soleLow, soleHigh = math.huge, -math.huge, math.huge, -math.huge
				local stop = os.clock() + HOVER_FOR - 0.1
				while os.clock() < stop do
					local feet = math.huge
					for _, d in king:GetDescendants() do
						if d:IsA("BasePart") and string.find(d.Name, "Leg", 1, true) then
							for _, c in corners(d) do
								feet = math.min(feet, c.Y)
							end
						end
					end
					low, high = math.min(low, feet - moundTop), math.max(high, feet - moundTop)
					local sole = soleHeight()
					soleLow, soleHigh = math.min(soleLow, sole), math.max(soleHigh, sole)
					task.wait()
				end
				h.check(res, "king_feet_over_mound", ("%.2f to %.2f"):format(low, high), "min > 7", low > 7)
				h.check(
					res,
					"king_hover_about_12",
					("%.2f to %.2f"):format(soleLow, soleHigh),
					"11.2 to 12.8",
					soleLow >= 11.25 - 0.05 and soleHigh <= 12.75 + 0.05
				)
			end

			-- The camera: FOV 80 (owner change 2026-11-12, was 60) for the whole event in his arena, through a move.
			local index, at = firstMoment("enuma")
			check(res, "king_enuma_moment_found", index ~= nil, true)
			if index then
				state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + at - 3.2, hp, hp, true, 100)
				local low, high, stop = math.huge, -math.huge, os.clock() + 4.5
				while os.clock() < stop do
					low, high = math.min(low, fov()), math.max(high, fov())
					task.wait(0.03)
				end
				h.check(
					res,
					"king_fov_80_through_enuma",
					("%s to %s"):format(low, high),
					"80 to 80",
					low == 80 and high == 80
				)
			end
			-- The lighting: his sunset profile in his event.
			local Env = optional("BiomeEnvironment")
			check(res, "environment_loads", Env ~= nil, true)
			local sunset = Env and Env.Profile(Env.ARENA_ZONE, KING)
			local want = sunset and sunset.Lighting and sunset.Lighting.ClockTime
			check(res, "sunset_clock_time_set", type(want) == "number", true)
			if type(want) == "number" then
				-- The client blends Lighting over time: wait until ClockTime moves under 0.005 in 1 s (at most 20 s).
				local settled, deadline = false, os.clock() + 20
				local before = Lighting.ClockTime
				while not settled and os.clock() < deadline do
					task.wait(1)
					settled = math.abs(Lighting.ClockTime - before) < 0.005
					before = Lighting.ClockTime
				end
				check(res, "sunset_blend_settled", settled, true)
				local got = math.abs(Lighting.ClockTime - want) <= 0.05
				h.check(res, "sunset_applied_in_event", Lighting.ClockTime, want, got)
			end
			-- The other arenas keep the event's FOV of 100.
			for _, other in { "boss_mage", "none" } do
				boss(res, other)
				state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true, 100)
				check(res, "fov_100_in_" .. (other == "none" and "boss_raga" or other), waitIs(fov, Cfg.CameraFov), 100)
			end
			-- Leaving: the zone's own profile returns.
			boss(res, KING)
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true, 100)
			waitIs(fov, 80)
			state(res, "Idle", 0, 0, 0, false)
			boss(res, nil)
			local left = waitIs(function()
				return Env and Env.CurrentZone ~= Env.ARENA_ZONE
			end, true, 6)
			check(res, "left_arena_zone", left, true)
			if Env and type(want) == "number" then
				local own = Env.Profile(Env.CurrentZone)
				local back = own and own.Lighting and own.Lighting.ClockTime
				local settled = waitIs(function()
					if type(back) == "number" then
						return math.abs(Lighting.ClockTime - back) <= 0.6 -- weather may mix the zone's clock
					end
					return math.abs(Lighting.ClockTime - want) > 0.5
				end, true, 6)
				h.check(res, "zone_profile_back_after", Lighting.ClockTime, back or ("not " .. want), settled == true)
			end
		end, debug.traceback)
		h.check(res, "king_arena_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		camera.FieldOfView = fovBefore
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
		--     between 18 and 30 studs, the largest at least 26 (BOSS_EVENT_SPEC "Golden King game matched to his sheets" (2026-11-12, proposed); replaces 1.25 x the old 14 /
		--     10 / 7); it turns slowly about its facing (LookVector). The portals stand in an arch behind him: every centre within
		--     120 deg (flat) of the direction behind his live Torso, and every portal's facing (either side) within 45 deg of
		--     his Torso's facing, toward the lanes.
		--   Wind: BossVfxForce "Charge" makes a BasePart EnumaWind under BossEffects that follows Ea, its local Y along the orbit's
		--     axis; its Trails (enabled, faded at both ends: Transparency's first and last keypoints >= 0.8) ride Attachment0s
		--     orbiting that axis: 4 early in the charge, 6 near 2.75 s; the orbit turns once per 0.8 s early and once per 0.35 s near
		--     2.75 s (+/- 20%). With effects off no enabled wind Trail (BOSS_EVENT_SPEC "Effects setting").
		--   Ea's trail: an enabled Trail parented under the GoldenKing's Ea part (or whose Attachment0 is) during enuma's swing (3.0 s
		--     +/- 0.3, from the schedule), none at rest (the idle), none under REDUCED EFFECTS. LastStrikes stays as checked above.
		local WHITE_TOLERANCE = 0.01
		local PORTAL_SMALL, PORTAL_LARGE, PORTAL_LARGEST = 18, 30, 26 -- BOSS_EVENT_SPEC "Golden King game matched to his sheets" (2026-11-12, proposed)
		local function portalArt()
			local art = optional("BossVfxArt") or {}
			return art.PortalC or (optional("BossKingArt") or {}).PortalC
		end
		-- Plays Gates and follows every Portal (or parts named `name`) for `seconds`: { [portal] = { Peak, First, Last, Decals = { decal } } }.
		local function watchPortals(seconds, name)
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", "Gates")
			local seen, stop = {}, os.clock() + seconds
			while os.clock() < stop do
				for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
					if d.Name == (name or "Portal") and d:IsA("BasePart") then
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
			-- His own arena replaces the vault (design doc 4.37 "The Golden King's own arena", owner 2026-11-12): the vault
			-- dressing check and its 1,150 primitive cap became king_arena_present here and the part budget in ui_boss_king_arena.
			check(res, "king_arena_present", waitFor(function()
				return inArena("KingArena") ~= nil
			end, BUILD_WAIT) == true, true)
			check(res, "vault_gone", inArena("Vault"), nil)
			for _, other in { "ElfMage", "Golem", "BigRaga" } do
				check(res, other .. "_not_built_for_king", inArena(other), nil)
			end
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
				"gates_portals_16_to_22", -- BOSS_EVENT_SPEC "Golden King game matched to his sheets" (2026-11-12, proposed); was 12 to 20
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
			local wrongArt, notWhite, offSize, turning, watched, largestPortal = {}, {}, {}, 0, 0, 0
			local offArch = {}
			local kingTorso = king:FindFirstChild("Torso", true)
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
				largestPortal = math.max(largestPortal, row.Peak)
				if row.Peak < PORTAL_SMALL - 0.01 or row.Peak > PORTAL_LARGE + 0.01 then
					table.insert(offSize, ("%.2f"):format(row.Peak))
				end
				-- the arch behind him, facing the lanes (from the portal's last frame and his Torso now)
				if kingTorso and row.Last then
					local facing = kingTorso.CFrame.LookVector * Vector3.new(1, 0, 1)
					local out = (row.Last[2].Position - kingTorso.Position) * Vector3.new(1, 0, 1)
					if facing.Magnitude > 1e-3 and out.Magnitude > 1e-3 then
						facing, out = facing.Unit, out.Unit
						local fromBehind = math.deg(math.acos(math.clamp(-facing:Dot(out), -1, 1)))
						local look = row.Last[2].LookVector
						local toLanes = math.deg(math.acos(math.clamp(math.abs(look:Dot(facing)), 0, 1)))
						if fromBehind > 120 or toLanes > 45 then
							table.insert(
								offArch,
								("%.0f deg from behind, faces %.0f deg off"):format(fromBehind, toLanes)
							)
						end
					end
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
			-- BOSS_EVENT_SPEC "Golden King game matched to his sheets" (2026-11-12, proposed): replaces portals_1_25_x_size
			h.checkList(res, "portals_sheet_size", offSize)
			h.check(
				res,
				"portals_sheet_size_largest",
				largestPortal,
				">= " .. PORTAL_LARGEST,
				largestPortal >= PORTAL_LARGEST
			)
			check(res, "portals_king_torso_found", kingTorso ~= nil, true)
			h.checkList(res, "portals_arch_behind", offArch)
			h.check(res, "portals_turn_slowly", turning, "> 0", turning > 0)
			-- Gates ring (owner 2026-11-13, design doc 4.37 / BOSS_EVENT_SPEC "Boss effects after playing", proposed): besides the
			-- arch (`Portal`, checked above), 18 to 24 `PortalRing` parts evenly all round him, 40 to 60 studs (flat) from his
			-- Torso, facing outward (flat LookVector within 30 deg of the way out), pitched down 0 to 35 deg, no PointLight.
			local rings = mostNamed("Gates", "PortalRing")
			h.check(res, "gates_ring_portals_18_to_24", rings, "18 to 24", rings >= 18 and rings <= 24)
			local offRing, lit, quadrants, ringWatched = {}, {}, {}, 0
			for portal, row in watchPortals(3, "PortalRing") do
				ringWatched += 1
				for _, d in portal:GetDescendants() do
					if d:IsA("PointLight") and d.Enabled then
						table.insert(lit, portal:GetFullName())
					end
				end
				if kingTorso and row.Last then
					local cf = row.Last[2]
					local out = (cf.Position - kingTorso.Position) * Vector3.new(1, 0, 1)
					local flatLook = cf.LookVector * Vector3.new(1, 0, 1)
					local dist = out.Magnitude
					local down = math.deg(math.asin(math.clamp(-cf.LookVector.Y, -1, 1)))
					local dot = (dist > 1e-3 and flatLook.Magnitude > 1e-3) and flatLook.Unit:Dot(out.Unit) or -1
					if dist < 40 or dist > 60 or dot < math.cos(math.rad(30)) or down < 0 or down > 35 then
						table.insert(offRing, ("%.0f studs, out dot %.2f, down %.0f deg"):format(dist, dot, down))
					end
					if dist > 1e-3 then
						quadrants[(out.X >= 0 and 1 or 0) + (out.Z >= 0 and 2 or 0)] = true
					end
				end
			end
			local quadrantCount = 0
			for _ in quadrants do
				quadrantCount += 1
			end
			check(res, "gates_ring_portals_watched", ringWatched > 0, true)
			h.checkList(res, "gates_ring_portals_outward", offRing)
			h.check(res, "gates_ring_portals_all_quadrants", quadrantCount, "4", quadrantCount == 4)
			h.checkList(res, "gates_ring_portals_no_light", lit)
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
			-- Effects off (design doc 4.37 "Boss effects have no reduced version", BOSS_EVENT_SPEC "Effects setting", owner
			-- 2026-11-12; replaces "fewer", 3 per volley and "the shields stay"): nothing drawn, the full volley plan logged.
			h.player:SetAttribute("ReduceEffects", true)
			local function drawnPeak(name)
				ReplicatedStorage:SetAttribute("BossVfxForce", "")
				task.wait()
				ReplicatedStorage:SetAttribute("BossVfxForce", name)
				local most, stop = 0, os.clock() + PEAK_WATCH
				while os.clock() < stop do
					local n = 0
					for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
						if
							(d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "StrikeMark")
							or ((d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")) and d.Enabled)
						then
							n += 1
						end
					end
					most = math.max(most, n)
					task.wait(0.05)
				end
				return most
			end
			for _, name in { "Gates", "Enuma", "Shields" } do
				check(res, "reduced_" .. string.lower(name) .. "_no_effects", drawnPeak(name), 0)
			end
			checkVolleys("reduced_gates", volleyLog(), PER_VOLLEY_MIN, PER_VOLLEY_MAX)
			check(res, "reduced_enuma_no_tint", mostNamed("Enuma", "ChargeTint"), 0)
			check(res, "reduced_no_shields", mostNamed("Shields", "Shield"), 0)
			-- Effects off: no wind ribbons, no trail on Ea.
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
			-- Pose-tied effects (BOSS_EVENT_SPEC "Animation rework" bullet "Pose-tied effects"; task a5c). Contract (implementer:
			-- report a change, do not loosen), under BossEffects unless named otherwise:
			--   Portal (as now): first seen over time, a growing cascade (not all in one frame).
			--   EnumaBeam (as now): its yaw (LookVector) keeps one offset from his live Torso's yaw (his baked hip turn) through the
			--     beam: at 3.5 s and 4.5 s the offsets agree within 15 deg, and frame to frame it turns with the torso (at most 3 deg
			--     apart a frame; still while the hips hold). From the schedule, BossVfxForce off.
			--   EaGlow: Light(s) (PointLight or SurfaceLight) under the GoldenKing's Ea or Ea_Drum parts: brighter at 2.5 s of enuma
			--     than at 0.2 s. None lit under REDUCED EFFECTS.
			--   EnumaChargeFlash: the charge's white flash (a BasePart, light or effect), first seen within 0.15 s before the
			--     EnumaBeam. Not under REDUCED EFFECTS. LastImpact for Enuma stays one hit.
			--   Shield (as now): with BossFortified untouched, first seen in the shields move between its call key (0.6 s, rework
			--     keys) and its lock (2.2 s); ShieldBurst when BossFortified turns false (the next move's start). The shields
			--     go with the rest of the effects when they are off (BOSS_EVENT_SPEC "Effects setting", owner 2026-11-12).
			ReplicatedStorage:SetAttribute("BossVfxForce", nil)
			local function firstSeen(names, seconds)
				local seenAt, born = {}, os.clock()
				while os.clock() - born < seconds do
					for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
						if names[d.Name] and not seenAt[d] then
							seenAt[d] = os.clock() - born
						end
					end
					task.wait()
				end
				return seenAt
			end
			local function yaw(look)
				return math.deg(math.atan2(-look.X, -look.Z))
			end
			local function wrap(a)
				return (a + 180) % 360 - 180
			end
			local function eaGlow()
				local most = 0
				for _, d in king:GetDescendants() do
					if d:IsA("Light") and d.Name == "EaGlow" and d.Enabled then
						local p = d.Parent
						if p and (p.Name == "Ea" or string.sub(p.Name, 1, 7) == "Ea_Drum") then
							most = math.max(most, d.Brightness)
						end
					end
				end
				return most
			end
			local fight = Cfg.PrepSeconds + Cfg.IntroSeconds
			local enumaAt, shieldsAt = nil, nil
			for i = 1, SCAN do
				local t, name = BossDodge.Moment(i, KING)
				enumaAt = enumaAt or (name == "enuma" and t or nil)
				shieldsAt = shieldsAt or (name == "shields" and t or nil)
			end
			local torso = king:FindFirstChild("Torso", true)
			check(res, "pose_moments_found", enumaAt ~= nil and shieldsAt ~= nil and torso ~= nil, true)
			-- Gates: the portals open in a cascade.
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", "Gates")
			local opened, firstPortal, lastPortal = firstSeen({ Portal = true }, 2), math.huge, -math.huge
			for _, t in opened do
				firstPortal, lastPortal = math.min(firstPortal, t), math.max(lastPortal, t)
			end
			h.check(res, "gates_portals_cascade", lastPortal - firstPortal, ">= 0.3", lastPortal - firstPortal >= 0.3)
			-- Enuma: the white flash before the beam (the whole move at once), and the impact log unchanged.
			for _, few in { false, true } do
				h.player:SetAttribute("ReduceEffects", few or nil)
				ReplicatedStorage:SetAttribute("BossVfxForce", "")
				task.wait()
				local holder = inArena("BossEffects")
				if holder then
					holder:SetAttribute("LastImpact", nil)
				end
				ReplicatedStorage:SetAttribute("BossVfxForce", "Enuma")
				local flashAt, beamAt = math.huge, math.huge
				for d, t in firstSeen({ EnumaChargeFlash = true, EnumaBeam = true }, 4) do
					if d.Name == "EnumaChargeFlash" then
						flashAt = math.min(flashAt, t)
					else
						beamAt = math.min(beamAt, t)
					end
				end
				if few then
					check(res, "reduced_no_enuma_white_flash", flashAt == math.huge, true)
				else
					local lead = beamAt - flashAt
					h.check(res, "enuma_white_flash_before_beam", lead, "0 to 0.15", lead >= 0 and lead <= 0.15)
					local raw = inArena("BossEffects") and inArena("BossEffects"):GetAttribute("LastImpact")
					local okLog, log = pcall(HttpService.JSONDecode, HttpService, raw or "")
					local hits = okLog and type(log) == "table" and type(log.Hits) == "table" and #log.Hits or 0
					check(res, "enuma_impact_log_one_hit", okLog and log.Move == "Enuma" and hits == 1, true)
				end
			end
			h.player:SetAttribute("ReduceEffects", nil)
			ReplicatedStorage:SetAttribute("BossVfxForce", nil)
			if enumaAt and torso then
				-- Ea's grooves glow while the drums spin (from the schedule).
				for _, few in { false, true } do
					h.player:SetAttribute("ReduceEffects", few or nil)
					state(res, "Fight", fight + enumaAt - 3 + 0.2, 4000, 4000, true, 100)
					task.wait(0.1)
					local glowEarly = eaGlow()
					task.wait(2.2)
					local glowLate = eaGlow()
					if few then
						check(res, "reduced_no_ea_glow", glowLate, 0)
					else
						h.check(
							res,
							"ea_grooves_glow_while_spinning",
							("%s then %s"):format(glowEarly, glowLate),
							"rises",
							glowLate > glowEarly
						)
					end
				end
				h.player:SetAttribute("ReduceEffects", nil)
				-- The beam turns with his hips.
				state(res, "Fight", fight + enumaAt - 0.1, 4000, 4000, true, 100)
				local born, rows = os.clock(), {}
				while os.clock() - born < 2.1 do
					local beam = inArena("EnumaBeam")
					if beam and beam:IsA("BasePart") then
						-- where the beam's axis meets the deck (the part is centred mid-beam along its LookVector)
						local look = beam.CFrame.LookVector
						local origin = beam.Position - look * beam.Size.Z / 2
						local land = math.huge
						if Arena and look.Y < -1e-3 then
							local hit = origin + look * ((Arena.Y - origin.Y) / look.Y)
							land = Vector2.new(hit.X - Arena.Center.X, hit.Z - Arena.Center.Z).Magnitude
						end
						table.insert(rows, {
							T = 2.9 + os.clock() - born,
							Beam = yaw(look),
							Torso = yaw(torso.CFrame.LookVector),
							Land = land,
						})
					end
					task.wait()
				end
				local function offsetNear(t)
					local best = nil
					for _, row in rows do
						if not best or math.abs(row.T - t) < math.abs(best.T - t) then
							best = row
						end
					end
					return best and math.abs(best.T - t) < 0.1 and wrap(best.Beam - best.Torso) or nil
				end
				local a, b = offsetNear(3.5), offsetNear(4.5)
				h.check(
					res,
					"enuma_beam_follows_hips",
					a and b and math.abs(wrap(a - b)) or "no beam",
					"<= 15",
					a ~= nil and b ~= nil and math.abs(wrap(a - b)) <= 15
				)
				local worst = 0
				for i = 2, #rows do
					local turn = wrap(rows[i].Beam - rows[i - 1].Beam) - wrap(rows[i].Torso - rows[i - 1].Torso)
					worst = math.max(worst, math.abs(wrap(turn)))
				end
				h.check(res, "enuma_beam_turns_only_with_hips", worst, "<= 3", #rows > 1 and worst <= 3)
				-- Enuma 360 (owner 2026-11-13, design doc 4.37 / BOSS_EVENT_SPEC "Boss effects after playing", proposed): over the
				-- window (3.0 to 5.0 s) the beam's yaw goes about 370 deg one way, and it lands on the deck within the wall all round.
				local swept, forward, backward, offDeck, prev = 0, 0, 0, {}, nil
				for _, row in rows do
					if row.T >= 3.0 and row.T <= 5.0 then
						if prev then
							local step = wrap(row.Beam - prev.Beam)
							swept += step
							forward += math.max(step, 0)
							backward += math.max(-step, 0)
						end
						prev = row
						if row.T >= 3.05 and row.T <= 4.95 and not (Arena and row.Land <= Arena.WallRadius) then
							table.insert(offDeck, ("%.2f s: %.0f studs"):format(row.T, row.Land))
						end
					end
				end
				h.check(res, "enuma_beam_sweeps_360", math.abs(swept), ">= 350", math.abs(swept) >= 350)
				local against = swept >= 0 and backward or forward
				h.check(res, "enuma_beam_one_way", against, "<= 10", prev ~= nil and against <= 10)
				check(res, "enuma_beam_lands_rows", prev ~= nil and Arena ~= nil, true)
				h.checkList(res, "enuma_beam_lands_on_lanes", offDeck)
			end
			if shieldsAt then
				-- Shields appear with his call gesture, from the pose (BossFortified untouched), and burst when he lowers them.
				local savedFortified = ReplicatedStorage:GetAttribute("BossFortified")
				state(res, "Fight", fight + shieldsAt - 2.2 - 0.3, 4000, 4000, true, 100)
				local first = math.huge
				for _, t in firstSeen({ Shield = true }, 2.6) do
					first = math.min(first, t - 0.3)
				end
				h.check(
					res,
					"shields_appear_with_gesture",
					first,
					"0.6 to 2.2 s into shields",
					first >= 0.6 - 0.05 and first <= 2.2
				)
				ReplicatedStorage:SetAttribute("BossFortified", true)
				task.wait(0.5)
				ReplicatedStorage:SetAttribute("BossFortified", false)
				local burst = next(firstSeen({ ShieldBurst = true }, 0.6)) ~= nil
				check(res, "shields_shatter_burst", burst, true)
				ReplicatedStorage:SetAttribute("BossFortified", savedFortified)
			end
			-- Stronger Gates and Enuma (owner 2026-11-12 after playing; BOSS_EVENT_SPEC "Golden King effects"); see the header.
			ReplicatedStorage:SetAttribute("BossVfxForce", nil)
			local NEAR_PORTAL = 6
			local function isWhiteC(c)
				return c.R >= 0.85 and c.G >= 0.85 and c.B >= 0.85
			end
			local function isGold(c)
				return c.R >= 0.85 and c.G >= 0.55 and c.B <= 0.7
			end
			local function isRedOrDark(c)
				return (c.R >= 0.6 and c.G <= 0.35 and c.B <= 0.35) or (c.R <= 0.2 and c.G <= 0.2 and c.B <= 0.2)
			end
			-- Watches BossEffects for `seconds`: Spawns[name] = { { T, CFrame, Size, Color, Material } } of parts turning visible
			-- under that name; Emitters[name] = set; Portals[part] = { Peak, Sizes = { {T, size} } }; Tips[part] = { T, Position }.
			local function watchGates(seconds)
				local w = { Spawns = {}, Emitters = {}, Portals = {}, Tips = {} }
				local before, born = {}, os.clock()
				while os.clock() - born < seconds do
					local t, now = os.clock() - born, {}
					for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
						if d:IsA("BasePart") and d.Transparency < 1 then
							local key = d.Name
							now[d] = key
							if before[d] ~= key then
								w.Spawns[d.Name] = w.Spawns[d.Name] or {}
								table.insert(w.Spawns[d.Name], {
									T = t,
									CFrame = d.CFrame,
									Size = d.Size,
									Color = d.Color,
									Material = d.Material,
								})
							end
						elseif d:IsA("ParticleEmitter") or d:IsA("Attachment") then
							w.Emitters[d.Name] = w.Emitters[d.Name] or {}
							w.Emitters[d.Name][d] = true
						end
						if d:IsA("BasePart") and d.Name == "Portal" then
							local row = w.Portals[d] or { Peak = 0, Sizes = {} }
							w.Portals[d] = row
							local size = math.max(d.Size.X, d.Size.Y)
							row.Peak = math.max(row.Peak, size)
							row.Position = d.Position
							table.insert(row.Sizes, { t, size })
						elseif
							d:IsA("BasePart")
							and d.Name == "PortalTip"
							and d.Transparency < 0.9
							and not w.Tips[d]
						then
							w.Tips[d] = { T = t, Position = d.Position }
						end
					end
					before = now
					task.wait()
				end
				for _, row in w.Portals do
					row.FullAt = math.huge
					for _, sample in row.Sizes do
						if sample[2] >= 0.98 * row.Peak then
							row.FullAt = math.min(row.FullAt, sample[1])
						end
					end
					row.TipAt = math.huge
				end
				-- each tip belongs to the nearest portal
				for _, tip in w.Tips do
					local best, bestRow = math.huge, nil
					for _, row in w.Portals do
						local d = (row.Position - tip.Position).Magnitude
						if d < best then
							best, bestRow = d, row
						end
					end
					if bestRow then
						bestRow.TipAt = math.min(bestRow.TipAt, tip.T)
					end
				end
				return w
			end
			local function spawnsOf(w, name)
				return w.Spawns[name] or {}
			end
			-- Order checks on one watch.
			local function checkOrder(tag, w)
				local tipEarly, chest, untipped, portalCount = {}, {}, {}, 0
				for _, row in w.Portals do
					portalCount += 1
					if row.TipAt < row.FullAt - 0.03 then
						table.insert(tipEarly, ("tip %.2f before full %.2f"):format(row.TipAt, row.FullAt))
					end
				end
				for _, shot in spawnsOf(w, "Streak") do
					local start = shot.CFrame.Position
					if shot.Material == Enum.Material.Neon then
						start -= shot.CFrame.LookVector * shot.Size.Z / 2
					end
					local best, bestRow = math.huge, nil
					for _, row in w.Portals do
						local d = (row.Position - start).Magnitude
						if d < best then
							best, bestRow = d, row
						end
					end
					if best > NEAR_PORTAL or not bestRow then
						table.insert(chest, ("%.1f studs from a portal at %.2f"):format(best, shot.T))
					elseif bestRow.TipAt > shot.T + 0.03 then
						table.insert(untipped, ("shot %.2f, tip %.2f"):format(shot.T, bestRow.TipAt))
					end
				end
				check(res, tag .. "gates_portals_seen", portalCount > 0, true)
				check(res, tag .. "gates_shots_seen", #spawnsOf(w, "Streak") > 0, true)
				h.checkList(res, tag .. "gates_portal_before_tip", tipEarly)
				h.checkList(res, tag .. "gates_tip_before_shot", untipped)
				h.checkList(res, tag .. "gates_no_shot_from_chest", chest)
			end
			local gatesAt = nil
			for i = 1, SCAN do
				local t, name = BossDodge.Moment(i, KING)
				gatesAt = gatesAt or (name == "gates" and t or nil)
			end
			check(res, "gates_moment_found", gatesAt ~= nil, true)
			if gatesAt then -- the real schedule: gates_start is 1.6 s before the gates moment
				state(res, "Fight", fight + gatesAt - 1.6 - 0.1, 4000, 4000, true, 100)
				checkOrder("schedule_", watchGates(4.2))
			end
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			local logHolder = inArena("BossEffects")
			if logHolder then
				logHolder:SetAttribute("LastStrikes", nil)
			end
			ReplicatedStorage:SetAttribute("BossVfxForce", "Gates")
			local forced = watchGates(4.2)
			checkOrder("forced_", forced)
			-- The hits, against the forced volleys' log.
			local okLog, log = pcall(
				HttpService.JSONDecode,
				HttpService,
				(inArena("BossEffects") or workspace):GetAttribute("LastStrikes") or ""
			)
			local spots = 0
			for _, strike in okLog and type(log) == "table" and log.Strikes or {} do
				spots += type(strike.Spots) == "table" and #strike.Spots or 0
			end
			local function atLeast(tag, name, isColour)
				local seenList, wrong = spawnsOf(forced, name), 0
				for _, row in seenList do
					wrong += isColour(row.Color) and 0 or 1
				end
				h.check(
					res,
					tag,
					("%d of %d, %d off colour"):format(#seenList, spots, wrong),
					">= spots, all coloured",
					spots > 0 and #seenList >= spots and wrong == 0
				)
			end
			atLeast("gates_hit_gold_flash", "StrikeFlash", isGold)
			atLeast("gates_hit_gold_flash_core", "StrikeFlashCore", isWhiteC)
			atLeast("gates_hit_shock_ring", "ShockRing", isGold)
			local function present(w, name)
				return next(w.Emitters[name] or {}) ~= nil or #spawnsOf(w, name) > 0
			end
			check(res, "gates_hit_sparks", present(forced, "Sparks"), true)
			check(res, "gates_hit_dust", present(forced, "HitDust"), true)
			local thin, thinCore, cores = {}, {}, spawnsOf(forced, "StreakCore")
			for _, row in spawnsOf(forced, "Streak") do
				if row.Material == Enum.Material.Neon and math.min(row.Size.X, row.Size.Y) < 3 - 0.01 then
					table.insert(thin, ("%.2f"):format(math.min(row.Size.X, row.Size.Y)))
				end
			end
			for _, row in cores do
				if math.min(row.Size.X, row.Size.Y) < 1.05 - 0.01 or not isWhiteC(row.Color) then
					table.insert(thinCore, ("%.2f"):format(math.min(row.Size.X, row.Size.Y)))
				end
			end
			check(res, "gates_streak_cores_seen", #cores > 0, true)
			h.checkList(res, "gates_streak_thicker", thin)
			h.checkList(res, "gates_streak_white_core", thinCore)
			-- Enuma (forced): the white core, the turning cyclone, the burst and smoke where it sweeps.
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", "Enuma")
			local beamPart = waitFor(function()
				return inArena("EnumaBeam")
			end, 4)
			task.wait(0.1)
			local coreOk = false
			for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
				if d:IsA("BasePart") and d.Name == "EnumaBeamCore" and d.Transparency < 1 and isWhiteC(d.Color) then
					coreOk = true
				end
			end
			check(res, "enuma_beam_white_core", coreOk, true)
			local cyclone = inArena("EnumaCyclone")
			local turned = nil
			if beamPart and cyclone and cyclone:IsA("BasePart") then
				local function roll()
					local rel = beamPart.CFrame:ToObjectSpace(cyclone.CFrame)
					return math.deg(math.atan2(rel.RightVector.Y, rel.RightVector.X))
				end
				local total, last, born = 0, roll(), os.clock()
				while os.clock() - born < 0.3 do
					task.wait()
					local now = roll()
					total += wrap(now - last)
					last = now
				end
				turned = math.abs(total)
			end
			h.check(
				res,
				"enuma_beam_cyclone",
				turned or "no cyclone",
				">= 10 deg in 0.3 s, red or dark",
				turned ~= nil and turned >= 10 and isRedOrDark(cyclone.Color)
			)
			local burstNear, smokeNear = false, false
			local stop = os.clock() + 1.6
			while os.clock() < stop and beamPart and beamPart.Parent do
				local look, length = beamPart.CFrame.LookVector, beamPart.Size.Z
				local a = beamPart.Position - look * length / 2
				local b = beamPart.Position + look * length / 2
				local function nearLine(p)
					local ab = Vector2.new(b.X - a.X, b.Z - a.Z)
					local ap = Vector2.new(p.X - a.X, p.Z - a.Z)
					local u = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
					return (ap - ab * u).Magnitude <= 30 and Arena ~= nil and p.Y <= Arena.Y + 20
				end
				for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
					local name = d.Name
					if name == "EnumaHitBurst" or name == "EnumaHitSmoke" then
						local holder = d:IsA("ParticleEmitter") and d.Parent or d
						local where = holder:IsA("Attachment") and holder.WorldPosition
							or (holder:IsA("BasePart") and holder.Position)
						local colour = d:IsA("ParticleEmitter") and d.Color.Keypoints[1].Value
							or (d:IsA("BasePart") and d.Color)
						if where and colour and nearLine(where) then
							if name == "EnumaHitBurst" then
								burstNear = burstNear or isRedOrDark(colour) or isWhiteC(colour)
							else
								smokeNear = smokeNear or (colour.R <= 0.25 and colour.G <= 0.25 and colour.B <= 0.25)
							end
						end
					end
				end
				task.wait(0.05)
			end
			check(res, "enuma_hit_burst", burstNear, true)
			check(res, "enuma_hit_smoke", smokeNear, true)
			-- Effects off: none of them, the volley log the full plan.
			h.player:SetAttribute("ReduceEffects", true)
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", "Gates")
			local offGates = watchGates(4.2)
			local drawnOff = {}
			for _, name in
				{ "Portal", "PortalTip", "Streak", "StreakCore", "StrikeFlash", "StrikeFlashCore", "ShockRing" }
			do
				if #spawnsOf(offGates, name) > 0 then
					table.insert(drawnOff, name)
				end
			end
			for _, name in { "Sparks", "HitDust" } do
				if present(offGates, name) then
					table.insert(drawnOff, name)
				end
			end
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", "Enuma")
			local offEnuma = watchGates(5.2)
			for _, name in { "EnumaBeam", "EnumaBeamCore", "EnumaCyclone", "EnumaHitBurst", "EnumaHitSmoke" } do
				if present(offEnuma, name) then
					table.insert(drawnOff, name)
				end
			end
			h.checkList(res, "reduced_no_stronger_gates_or_enuma", drawnOff)
			checkVolleys("reduced_stronger_gates", volleyLog(), PER_VOLLEY_MIN, PER_VOLLEY_MAX)
			h.player:SetAttribute("ReduceEffects", nil)
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
