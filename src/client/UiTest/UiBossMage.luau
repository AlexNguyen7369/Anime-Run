--!nonstrict
-- The Elf Mage, the second boss (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"; boss-mage task T1). Owned
-- by ui-test-writer. Red first: written before Client/BossOsuUi and the per-boss UI. Driven by UiTestSetup boss_ui_* fixtures, as
-- UiBossEvent, plus boss_ui_boss:<id> (ReplicatedStorage BossEventBoss) and boss_ui_osu_spy (a logging Remotes.BossOsu).
--
-- Contract these checks assume beyond the brief (boss-mage-code-plan.md section 4; implementer: report a change, do not loosen):
--   Shared/BossCatalog, Shared/BossMageArt (StaffIcon, OsuCircle, OsuRing, OsuHit, OsuMiss, StatusCrushed, Portrait), Shared/BossOsu,
--     BossDodge.Moment(index, boss).
--   Client/BossEventUi reads BossCatalog.Current() at use time: Warning text, BossBar/Title, Invite texts, TeamHud/RagaPortrait (the
--     name is kept) and BossesPanel Status follow BossEventBoss. BossBar/Status/Status_Crushed's Icon shows BossMageArt.StatusCrushed.
--   Client/BossDodgeUi: DodgeBar/Wheel.Image is BossCatalog.Current().DodgeIcon or RelicConfig.WheelArt; no bar on a Slam moment.
--   BossesPanel/BossDetails rows Mage_<relicId> per ChestOdds row, plus Mage_side_mage "<SidekickConfig.Get('side_mage').Name> 0.001%"
--     (BossEventUi chestLines, from RelicConfig.Chests[chest].SidekickId; design doc 4.38, owner 2026-11-11). No Mage_side_raga.
--   Client/BossOsuUi: ScreenGui RacerBossOsu with Circle1..Circle4 (GuiButtons) directly in it, each with a GuiObject Ring whose
--     AbsoluteSize closes from 3x to 1x the circle's over ApproachSeconds. Active under the Dodge bar's rule (BossEvent true, Fight,
--     BossEventStart set, no BossWaitEndsAt): a fixture cannot give the client a run, so "has a run" is not required here.
--     Circle k shows at moment - Lead_k - ApproachSeconds, with moment = BossEventStart + PrepSeconds + IntroSeconds +
--     BossDodge.Moment(index, "boss_mage") and Lead from BossOsu.Circles(LocalPlayer.UserId, BossEventStart, index).
--   TEST SEAM (a LocalScript cannot fire Activated): each Circle<k> holds a BindableEvent named Press; Press:Fire() runs exactly
--     what Activated runs (stamp = workspace:GetServerTimeNow(), InvokeServer(index, k, stamp)).
--   A press shows an image with BossMageArt.OsuHit or OsuMiss (by BossOsu.Judge) somewhere in RacerBossOsu. "Nice Dodge!" in gold
--     after a true, "Dodged" answer; otherwise BossDodge.HitText.Slam in red at the moment, in RacerBossOsu or RacerBossDodge.
--   Mage arena (Client/BossArenaView): workspace.BossArenaPreview holds Models ElfMage (with part Torso, the TargetPart) and Golem;
--     no BigRaga while BossEventBoss is boss_mage. Effects live in Folder BossEffects; BossVfxForce plays Lightning, Slam, Barrage.
--     The golem's BaseParts are all Transparency 1 outside the golem move.
--   DEBUG FIELD (BossMageVfx): when Lightning or Barrage plays, BossEffects gets string attribute LastStrikes, JSON
--     {"Move":"Lightning"|"Barrage","Strikes":[{"T":<s after the window start>,"Spots":[[x,z],...]},...]}: every strike of the
--     move as planned (the same with effects off), its bolts' or beams' floor spots in world X, Z. Lightning leaves one StrikeMark
--     part per bolt in BossEffects.
--   Stronger effects (owner 2026-11-12 after playing; design doc 4.37 "Elf Mage effects stronger", BOSS_EVENT_SPEC "Pose-tied
--     effect values", proposed), BaseParts under BossEffects; a "spawn" is a part taking the name (pooled parts are renamed):
--     Lightning, per strike, as many as its LastStrikes spots within a frame: StrikeFlash white (each channel >= 0.85) and
--     ShockRing purple; per bolt at least one BoltCore white (the core) and one Bolt purple (the glow layer); a ParticleEmitter
--     named Sparks under BossEffects during the strikes.
--     Barrage, per beam (as many as the strike's spots): BarrageBeamCore white and BarrageBeamEdge near-black (each channel
--     <= 0.2); a ParticleEmitter or BasePart named BarrageSmoke, dark, during the window.
--     MagicCircle: 10, see the barrage watch.
--   Effects off (design doc 4.37 "Boss effects have no reduced version", BOSS_EVENT_SPEC "Effects setting", owner
--     2026-11-12): with ReduceEffects (or Roblox Reduced Motion) no boss visual effect at all under BossEffects (no visible
--     BasePart, enabled ParticleEmitter, Beam or Trail) except the strike marks (StrikeMark), a telegraph; LastStrikes still
--     logs the full strike plan (7 to 10 spots a strike).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("BossEventConfig"))
local RelicConfig = require(Shared:WaitForChild("RelicConfig"))
-- pcall: a BossDodge that fails to load (its pose modules) fails these scenarios, not the whole UI harness.
local _, BossDodge = pcall(require, Shared:WaitForChild("BossDodge"))

local MAGE = "boss_mage"
local ROOT = "RacerBossEvent"
local INVITE = ROOT .. "/Invite"
local HUD = ROOT .. "/TeamHud"
local WARNING = ROOT .. "/Warning"
local BAR = ROOT .. "/BossBar"
local BOSSES = ROOT .. "/BossesPanel"
local DODGE = "RacerBossDodge/DodgeBar"
local RESULT = "RacerBossDodge/Result"
local OSU = "RacerBossOsu"
local POPUP = "RacerBossRewards/Panel"

-- Owner 2026-11-11 (design doc 4.37) and the plan's proposed texts.
local NAME = "The Elf Mage"
local WARNING_TEXT = "The Elf Mage has awakened, take her down!!!"
local INVITE_TITLE = "THE ELF MAGE EVENT"
local INVITE_HINT = "Teleport to fight The Elf Mage before the timer ends"
local DEFEATED_TITLE = "The Elf Mage Defeated!"
local LIGHTNING_HIT = "You were struck by her lightning"
local SLAM_HIT = "The golem crushed you"
local SWEEP_HIT = "The golem swept you" -- BOSS_EVENT_SPEC "Texts" (proposed)
local DODGE_TEXT = "Nice Dodge!"
local DIAMETER, DIAMETER_PHONE = 0.145, 0.19 -- of the screen height (owner's 2026-11-11 easing, values proposed)
local GOLEM_NAME = "Stone Golem"
local GOLEM_FIRST, GOLEM_EVERY = 4.2, 6 -- s after BossMinionStart: attack k at 4.2 + 6 (k - 1), slam then sweep (proposed)
local CAPTIONS = { Slam = "Golem Slam! Hit every circle!", Sweep = "Golem Sweep! Hit every circle!" } -- proposed
local SPAWN_NOTE = "Each event picks one boss at random" -- owner 2026-11-11, draft B
local MAGE_CHEST = "relic_chest_mage"
local MINION = "RacerBossEvent/BossBar/MinionBar"
local CARDS = "RacerBossEvent/BossesPanel/Cards"
local MIDDLE = 0.2 -- the middle 60%: 20% margins on each side
local PHONE_MAX_HEIGHT = 500
local SHOW_SLACK = 0.15 -- s around a circle's appearance
local RING_START_MIN = 2.5 -- ring over circle when it shows (3x, a frame or two in)
local RING_BEAT_SLACK = 0.15
local STAMP_SLACK = 0.1 -- s between the press and the spied stamp
local SHOW_WAIT = 2
local BUILD_WAIT = 8
local PRIMITIVE_MAX = 1150 -- plan section 5 (budget about 1,050)
local PEAK_WATCH = 1.5
-- Owner 2026-11-11 (BOSS_EVENT_SPEC "Strike window"): a strike every 0.15 s, 14 in the 2 s window, 7 to 10 bolts or beams each,
-- at spots over the centre, all lanes and the walkway (the same plan with effects off, BOSS_EVENT_SPEC "Effects setting").
local STRIKE_COUNT, STRIKE_EVERY, STRIKE_TIME_SLACK = 14, 0.15, 0.02
local PER_STRIKE_MIN, PER_STRIKE_MAX = 7, 10
local SCAN = 40

local Module = {}

local function optional(name, parent)
	local source = (parent or Shared):FindFirstChild(name)
	local ok, value = pcall(function()
		return source and require(source)
	end)
	return ok and type(value) == "table" and value or nil
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
	local function hasText(path, text)
		local root = h.find(path)
		for _, d in root and root:GetDescendants() or {} do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text == text then
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
			local at, got = BossDodge.Moment(index, MAGE)
			if got == name then
				return index, at
			end
		end
		return nil
	end
	local function crossing(a, b)
		return a.x + a.w > b.x and b.x + b.w > a.x and a.y + a.h > b.y and b.y + b.h > a.y
	end

	-- Per-boss texts, the versus portrait and the Crushed status.
	function scenarios.ui_boss_mage(res)
		h.waitGuis()
		local Catalog, Art = optional("BossCatalog"), optional("BossMageArt")
		check(res, "mage_catalog_loads", Catalog ~= nil, true)
		check(res, "mage_art_loads", Art ~= nil, true)
		local hp = Cfg.HpPerPlayer
		local savedStatus = h.player:GetAttribute("BossStatus")
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			state(res, "Idle", 0)
			boss(res, MAGE)
			state(res, "Prep", 5, 0, 0, false)
			check(res, "mage_invite_shown", waitShown(INVITE, true), true)
			check(
				res,
				"mage_invite_title",
				waitIs(function()
					return hasText(INVITE, INVITE_TITLE) ~= nil
				end, true),
				true
			)
			check(res, "mage_invite_hint", hasText(INVITE, INVITE_HINT) ~= nil, true)

			state(res, "Prep", 5, hp, hp, true, 1234)
			check(res, "mage_team_hud_shown", waitShown(HUD, true), true)
			local portrait = h.find(HUD .. "/RagaPortrait")
			check(
				res,
				"mage_versus_portrait",
				waitIs(function()
					return portrait and portrait.Image
				end, Art and Art.Portrait),
				Art and Art.Portrait
			)

			state(res, "Prep", Cfg.PrepSeconds - 0.5, hp, hp, true, 100)
			waitShown(HUD, true)
			state(res, "Fight", "keep", hp, hp, true, 100)
			check(res, "mage_bar_shown", waitShown(BAR, true), true)
			check(
				res,
				"mage_warning_text",
				waitIs(function()
					return hasText(WARNING, WARNING_TEXT) ~= nil
				end, true),
				true
			)
			check(
				res,
				"mage_bar_title",
				waitIs(function()
					return textOf(BAR .. "/Title")
				end, NAME),
				NAME
			)

			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true, 100)
			local now = workspace:GetServerTimeNow()
			h.player:SetAttribute(
				"BossStatus",
				HttpService:JSONEncode({ { Id = "Crushed", EndsAt = now + 12, Count = 1 } })
			)
			local CELL = BAR .. "/Status/Status_Crushed"
			check(res, "mage_crushed_shown", waitShown(CELL, true), true)
			local cell = h.find(CELL)
			local icon, seconds = cell and cell:FindFirstChild("Icon"), cell and cell:FindFirstChild("Seconds")
			check(res, "mage_crushed_icon_is_image", icon ~= nil and icon:IsA("ImageLabel"), true)
			check(res, "mage_crushed_icon_art", icon and icon.Image, Art and Art.StatusCrushed)
			local text = seconds and seconds:IsA("TextLabel") and seconds.Text or ""
			check(res, "mage_crushed_seconds_format", string.match(text, "^%d+s$") ~= nil, true)
			h.player:SetAttribute("BossStatus", nil)

			-- Back to Big Raga: his texts return with the attribute.
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
		h.check(res, "mage_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		h.player:SetAttribute("BossStatus", savedStatus)
		setup(res, "restore:boss_ui")
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
	local function cardOf(id)
		return h.find(CARDS .. "/Card_" .. id)
	end
	-- The pill's words: its Text child draws them (Pill.Text itself may be blank).
	local function pillOf(card)
		local child = textOf(card .. "/Pill/Text")
		return child ~= "" and child or textOf(card .. "/Pill")
	end
	local function stateOf(id)
		local card = cardOf(id)
		return card and card:GetAttribute("State")
	end

	-- After the real press (UiSpec.Clicks boss_mage_button; her event in Prep, the player outside): her card is the live one.
	function after.boss_mage_panel_casting(res)
		check(res, "mage_panel_opens", waitShown(BOSSES, true), true)
		local card = CARDS .. "/Card_" .. MAGE
		check(
			res,
			"mage_card_live",
			waitIs(function()
				return stateOf(MAGE)
			end, "Live"),
			"Live"
		)
		check(res, "mage_card_large", cardOf(MAGE) and cardOf(MAGE):GetAttribute("Large"), true)
		check(res, "mage_card_tag_live", textOf(card .. "/Tag"), "LIVE")
		check(res, "mage_card_pill_left", string.match(pillOf(card), "^%d+:%d%d left$") ~= nil, true)
		check(res, "mage_card_go_shown", shown(card .. "/Go"), true)
		local go = h.find(card .. "/Go")
		check(res, "mage_card_go_active", go ~= nil and go.Active, true)
		check(res, "raga_card_other_in_her_event", stateOf("boss_raga"), "Other")
		check(res, "raga_card_dimmed_in_her_event", shown(CARDS .. "/Card_boss_raga/Dim"), true)
		check(res, "raga_card_no_go", shown(CARDS .. "/Card_boss_raga/Go"), false)
		check(res, "spawn_note_in_event", shown(BOSSES .. "/SpawnBox/SpawnNote"), true)
		local action = h.find(BOSSES .. "/BossAction")
		check(res, "spawn_action_inactive_in_event", action ~= nil and action.Active, false)
		h.checkList(res, "cards_inside_panel_live", outsidePanel(CARDS))
	end

	-- After the real press (UiSpec.Clicks boss_cards_next_mage): no event, her card announced next.
	function after.boss_cards_next_mage(res)
		check(res, "cards_panel_opens", waitShown(BOSSES, true), true)
		local card = CARDS .. "/Card_" .. MAGE
		check(
			res,
			"mage_card_next",
			waitIs(function()
				return stateOf(MAGE)
			end, "Next"),
			"Next"
		)
		check(res, "mage_card_next_large", cardOf(MAGE) and cardOf(MAGE):GetAttribute("Large"), true)
		check(res, "mage_card_tag_next", textOf(card .. "/Tag"), "NEXT")
		check(res, "mage_card_tag_shown", shown(card .. "/Tag"), true)
		local pill = pillOf(card)
		check(res, "mage_card_pill_next_event", string.match(pill, "^Next event in %d+:%d%d$") ~= nil, true)
		check(res, "mage_card_no_go_idle", shown(card .. "/Go"), false)
		check(res, "raga_card_other", stateOf("boss_raga"), "Other")
		check(res, "raga_card_not_large", cardOf("boss_raga") and cardOf("boss_raga"):GetAttribute("Large"), false)
		check(res, "raga_card_pill_not_this_time", pillOf(CARDS .. "/Card_boss_raga"), "Not this time")
		check(res, "raga_card_dimmed", shown(CARDS .. "/Card_boss_raga/Dim"), true)
		check(res, "raga_card_details_shown", shown(CARDS .. "/Card_boss_raga/Details"), true)
		check(res, "spawn_box_note", textOf(BOSSES .. "/SpawnBox/Note"), SPAWN_NOTE)
		check(res, "spawn_box_note_shown", shown(BOSSES .. "/SpawnBox/Note"), true)
		check(res, "spawn_note_hidden_idle", shown(BOSSES .. "/SpawnBox/SpawnNote"), false)
		check(res, "spawn_action_idle", textOf(BOSSES .. "/BossAction"), "Spawn boss 149 R$")
		h.checkList(res, "cards_inside_panel_next", outsidePanel(CARDS))
		h.checkList(res, "spawn_box_inside_panel", outsidePanel(BOSSES .. "/SpawnBox"))
	end

	-- After her card's Details press (UiSpec.Clicks boss_mage_details): her chest's table over the cards, no Big Raga line.
	function after.boss_mage_details_open(res)
		check(res, "mage_details_shown", waitShown(BOSSES .. "/BossDetails", true), true)
		local details = BOSSES .. "/BossDetails"
		local chest = RelicConfig.Chests[MAGE_CHEST]
		check(res, "mage_details_column_shown", shown(details .. "/Card_" .. MAGE_CHEST), true)
		check(res, "mage_details_title", textOf(details .. "/Title_" .. MAGE_CHEST), chest and chest.Name)
		check(res, "mage_details_raga_column_hidden", shown(details .. "/Title_relic_chest_raga"), false)
		local sum, off = 0, {}
		for _, row in RelicConfig.ChestOdds(MAGE_CHEST) do
			local path = details .. "/Mage_" .. row.Id
			local percent = tonumber(string.match(textOf(path), "([%d%.]+)%%"))
			h.check(res, "mage_details_odds_" .. row.Id, percent, row.Odds, percent == row.Odds)
			sum += percent or 0
			if not shown(path) then
				table.insert(off, row.Id)
			end
		end
		h.check(res, "mage_details_sum_100", sum, 100, math.abs(sum - 100) < 1e-6)
		h.checkList(res, "mage_details_rows_shown", off)
		local raga = {}
		for _, d in h.find(details) and h.find(details):GetDescendants() or {} do
			if d:IsA("TextLabel") and h.visible(d) and string.find(d.Text, "Big Raga", 1, true) then
				table.insert(raga, d.Name)
			end
		end
		h.checkList(res, "mage_details_no_raga_line", raga)
		h.checkList(res, "mage_details_inside_panel", outsidePanel(details))
	end

	-- The cards' built parts (BOSS_EVENT_SPEC "Bosses cards", draft B). States and texts are the Afters above: only a real press
	-- opens the popup.
	function scenarios.ui_boss_cards(res)
		h.waitGuis()
		local Catalog = optional("BossCatalog")
		check(res, "cards_catalog_loads", Catalog ~= nil, true)
		if not Catalog then
			return
		end
		check(res, "cards_frame_present", h.find(CARDS) ~= nil, true)
		check(res, "spawn_box_present", h.find(BOSSES .. "/SpawnBox") ~= nil, true)
		check(res, "spawn_box_note_text", textOf(BOSSES .. "/SpawnBox/Note"), SPAWN_NOTE)
		check(res, "details_back_present", h.find(BOSSES .. "/BossDetails/Back") ~= nil, true)
		for _, gone in { "Status", "DetailsHeading" } do
			check(res, "cards_replace_" .. gone, h.find(BOSSES .. "/" .. gone), nil)
		end
		for _, id in Catalog.Order do
			local row = Catalog.Get(id)
			local card = CARDS .. "/Card_" .. id
			check(res, "card_present_" .. id, h.find(card) ~= nil, true)
			for _, part in { "Portrait", "Title", "Phases", "Tag", "Pill", "Details", "Rewards", "Dim" } do
				check(res, ("card_%s_has_%s"):format(id, part), h.find(card .. "/" .. part) ~= nil, true)
			end
			local portrait = h.find(card .. "/Portrait")
			check(res, "card_portrait_" .. id, portrait and portrait:IsA("ImageLabel") and portrait.Image, row.Portrait)
			check(res, "card_title_" .. id, textOf(card .. "/Title"), row.Name)
			check(res, "card_phases_" .. id, textOf(card .. "/Phases"), row.Stages == 1 and "1 phase" or "2 phases")
			for _, chest in row.Chests or {} do
				local reward = h.find(card .. "/Rewards/Reward_" .. chest)
				check(res, ("card_%s_reward_%s"):format(id, chest), reward ~= nil, true)
				local count = reward and reward:FindFirstChild("Count", true)
				check(res, ("card_%s_reward_%s_count"):format(id, chest), count and count.Text, "1x")
			end
			check(res, "card_reward_money_" .. id, h.find(card .. "/Rewards/Reward_Money") ~= nil, true)
			check(res, "card_reward_gems_" .. id, h.find(card .. "/Rewards/Reward_Gems") ~= nil, row.Stages >= 2)
		end
		check(res, "card_mage_one_chest", h.find(CARDS .. "/Card_" .. MAGE .. "/Rewards/Reward_relic_chest_raga"), nil)
		-- Her chest's column in BossDetails, built once (texts are there before any press).
		local details = BOSSES .. "/BossDetails"
		check(res, "details_mage_column", h.find(details .. "/Card_" .. MAGE_CHEST) ~= nil, true)
		local sum = 0
		for _, row in RelicConfig.ChestOdds(MAGE_CHEST) do
			sum += tonumber(string.match(textOf(details .. "/Mage_" .. row.Id), "([%d%.]+)%%")) or 0
		end
		h.check(res, "details_mage_rows_sum_100", sum, 100, math.abs(sum - 100) < 1e-6)
		-- Design doc 4.38 (owner 2026-11-11): every chest rolls its own Sidekick, shown as its own odds row; never Raga's here.
		check(res, "details_mage_sidekick_row", h.find(details .. "/Mage_side_mage") ~= nil, true)
		check(
			res,
			"details_mage_sidekick_odds",
			string.find(textOf(details .. "/Mage_side_mage"), "0.001%", 1, true) ~= nil,
			true
		)
		check(res, "details_mage_no_raga_row", h.find(details .. "/Mage_side_raga"), nil)
	end

	-- The Stone Golem's bar under hers (BOSS_EVENT_SPEC "The Elf Mage": about 60% of her bar, proposed).
	function scenarios.ui_boss_golem(res)
		h.waitGuis()
		local hp = Cfg.HpPerPlayer
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			state(res, "Idle", 0)
			boss(res, MAGE)
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, hp, hp, true, 100)
			check(res, "golem_her_bar_shown", waitShown(BAR, true), true)
			check(res, "golem_bar_hidden_without_golem", shown(MINION), false)
			setup(res, "boss_ui_minion:640,1000")
			check(res, "golem_bar_shown", waitShown(MINION, true), true)
			check(
				res,
				"golem_bar_title",
				waitIs(function()
					return textOf(MINION .. "/Title")
				end, GOLEM_NAME),
				GOLEM_NAME
			)
			check(
				res,
				"golem_bar_value",
				waitIs(function()
					return textOf(MINION .. "/Value")
				end, "640/1,000"),
				"640/1,000"
			)
			check(res, "golem_bar_fill_present", h.find(MINION .. "/Track/Fill") ~= nil, true)
			check(res, "golem_her_bar_dims", waitShown(BAR .. "/Track/Dim", true), true)
			local bar, mini = h.find(BAR), h.find(MINION)
			if bar and mini then
				local a, b = h.rect(bar), h.rect(mini)
				h.check(res, "golem_bar_width_0_6", b.w, 0.6 * a.w, math.abs(b.w - 0.6 * a.w) <= 2)
				h.check(res, "golem_bar_height_0_6", b.h, 0.6 * a.h, math.abs(b.h - 0.6 * a.h) <= 2)
				local centre = (b.x + b.w / 2) - (a.x + a.w / 2)
				h.check(res, "golem_bar_centred", centre, "0 +- 2", math.abs(centre) <= 2)
				h.check(res, "golem_bar_under_hers", b.y, ">= " .. (a.y + a.h), b.y >= a.y + a.h - 1)
				for _, path in { BAR .. "/Status", ROOT .. "/DropList", ROOT .. "/LeaveButton" } do
					local other = h.find(path)
					if other and shown(path) then
						check(res, "golem_bar_clear_of_" .. path, crossing(b, h.rect(other)), false)
					end
				end
			end
			setup(res, "boss_ui_minion:none")
			check(res, "golem_bar_hides", waitShown(MINION, false), false)
			check(res, "golem_her_bar_dim_hides", waitShown(BAR .. "/Track/Dim", false), false)
		end, debug.traceback)
		h.check(res, "golem_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		setup(res, "boss_ui_minion:none")
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	-- Her staff on the Dodge bar; Raga keeps his wheel. No bar while the golem stands (her clock is stopped).
	function scenarios.ui_boss_mage_dodge(res)
		local Art = optional("BossMageArt")
		check(res, "mage_art_loads", Art ~= nil, true)
		local hp = Cfg.HpPerPlayer
		local lead = BossDodge.SweepFor(1) * 0.5
		local ok, err = xpcall(function()
			local index, at = firstMoment("Lightning")
			check(res, "mage_lightning_moment_found", index ~= nil, true)
			if index then
				state(res, "Idle", 0)
				boss(res, MAGE)
				state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + at - lead, hp, hp, true, 100)
				check(res, "mage_dodge_bar_shown", waitShown(DODGE, true, lead), true)
				local bar = h.find(DODGE)
				local wheel = bar and bar:FindFirstChild("Wheel")
				check(res, "mage_dodge_staff_icon", wheel and wheel.Image, Art and Art.StaffIcon)
				check(res, "mage_dodge_hit_shows", waitShown(RESULT, true, lead + 1), true)
				check(res, "mage_dodge_hit_words", textOf(RESULT), LIGHTNING_HIT)

				state(res, "Idle", 0)
				boss(res, MAGE)
				setup(res, "boss_ui_minion:640,1000")
				state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + at - lead, hp, hp, true, 100)
				check(res, "mage_no_dodge_bar_while_golem", waitShown(DODGE, true, lead + 0.5), false)
				setup(res, "boss_ui_minion:none")
			end
			state(res, "Idle", 0)
			boss(res, nil)
			local ragaAt = BossDodge.Moment(1)
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + ragaAt - lead, hp, hp, true, 100)
			check(res, "raga_dodge_bar_shown", waitShown(DODGE, true, lead), true)
			local bar = h.find(DODGE)
			local wheel = bar and bar:FindFirstChild("Wheel")
			check(res, "raga_dodge_wheel_art", wheel and wheel.Image, RelicConfig.WheelArt)
		end, debug.traceback)
		h.check(res, "mage_dodge_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		setup(res, "boss_ui_minion:none")
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	-- One golem attack's circles, watched frame by frame: attack k of a golem standing from now. presses[c] = seconds from circle
	-- c's beat to press it (nil: never pressed).
	local function watchAttack(res, Osu, k, presses, inWait)
		local hp = Cfg.HpPerPlayer
		state(res, "Idle", 0)
		boss(res, MAGE)
		state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 40, hp, hp, true, 100)
		if inWait then
			setup(res, "boss_ui_wait:30") -- after the state: boss_ui_state:Idle clears it
		end
		local before = ReplicatedStorage:GetAttribute("BossMinionStart")
		setup(res, "boss_ui_minion:640,1000")
		local startAt = ReplicatedStorage:GetAttribute("BossMinionStart")
		local deadline = os.clock() + SHOW_WAIT
		while (type(startAt) ~= "number" or startAt == before) and os.clock() < deadline do
			task.wait(0.05)
			startAt = ReplicatedStorage:GetAttribute("BossMinionStart")
		end
		startAt = startAt or workspace:GetServerTimeNow()
		local name = k % 2 == 1 and "Slam" or "Sweep"
		local moment = startAt + GOLEM_FIRST + GOLEM_EVERY * (k - 1)
		local rows = Osu.Circles(h.player.UserId, startAt, k)
		local seen = { Shown = {}, Rect = {}, RingFirst = {}, RingBeat = {}, BeatGap = {}, Pressed = {}, Name = name }
		local Art = optional("BossMageArt") or {}
		local hitText = name == "Slam" and SLAM_HIT or SWEEP_HIT
		local function scanImages(root)
			for _, d in root and root:GetDescendants() or {} do
				if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and h.visible(d) then
					seen.Hit = seen.Hit or (Art.OsuHit ~= nil and d.Image == Art.OsuHit)
					seen.Miss = seen.Miss or (Art.OsuMiss ~= nil and d.Image == Art.OsuMiss)
				end
			end
		end
		local function scanTexts(root)
			for _, d in root and root:GetDescendants() or {} do
				if d:IsA("TextLabel") and h.visible(d) then
					if d.Text == DODGE_TEXT then
						seen.Gold = seen.Gold or d.TextColor3
					elseif d.Text == hitText then
						seen.Red = seen.Red or d.TextColor3
					elseif d.Text == CAPTIONS[name] then
						seen.Caption = true
					elseif d.Text == CAPTIONS.Slam or d.Text == CAPTIONS.Sweep then
						seen.WrongCaption = d.Text
					end
				end
			end
		end
		while workspace:GetServerTimeNow() < moment + 1.2 do
			local now = workspace:GetServerTimeNow()
			local gui = h.find(OSU)
			seen.DodgeBar = seen.DodgeBar or shown(DODGE)
			for c, row in rows do
				local circle = h.find(OSU .. "/Circle" .. c)
				local beat = moment - row.Lead
				if circle and shown(OSU .. "/Circle" .. c) then
					local ring = circle:FindFirstChild("Ring")
					local ratio = ring
						and ring:IsA("GuiObject")
						and circle.AbsoluteSize.X > 0
						and ring.AbsoluteSize.X / circle.AbsoluteSize.X
					if not seen.Shown[c] then
						seen.Shown[c] = now
						seen.RingFirst[c] = ratio
					end
					local gap = math.abs(now - beat)
					if seen.BeatGap[c] == nil or gap < seen.BeatGap[c] then
						seen.BeatGap[c], seen.RingBeat[c], seen.Rect[c] = gap, ratio, h.rect(circle)
					end
				end
				local offset = presses[c]
				if offset and not seen.Pressed[c] and now >= beat + offset then
					local press = circle and circle:FindFirstChild("Press")
					seen.Pressed[c] = now
					if press and press:IsA("BindableEvent") then
						press:Fire()
					end
				end
			end
			seen.ExtraCircle = seen.ExtraCircle or shown(OSU .. "/Circle4")
			scanImages(gui)
			scanTexts(gui)
			scanTexts(h.find("RacerBossDodge"))
			RunService.Heartbeat:Wait()
		end
		return seen, rows, moment
	end

	local function spyLog()
		local raw = ReplicatedStorage:GetAttribute("UiTestBossOsuLog")
		local ok, list = pcall(HttpService.JSONDecode, HttpService, raw or "[]")
		return ok and list or {}
	end

	function scenarios.ui_boss_osu(res)
		h.waitGuis()
		local Osu, Art = optional("BossOsu"), optional("BossMageArt")
		check(res, "osu_module_loads", Osu ~= nil, true)
		check(res, "mage_art_loads", Art ~= nil, true)
		if not Osu then
			return
		end
		local ok, err = xpcall(function()
			setup(res, "boss_ui_osu_spy")
			check(
				res,
				"osu_gui_present",
				waitIs(function()
					return h.find(OSU) ~= nil
				end, true),
				true
			)

			-- The golem's first attack (its slam), all three on the beat: dodged.
			local seen, rows, moment = watchAttack(res, Osu, 1, { 0, 0, 0 })
			check(res, "osu_no_dodge_bar", seen.DodgeBar == true, false)
			check(res, "osu_three_circles_only", seen.ExtraCircle == true, false)
			check(res, "osu_caption_slam", seen.Caption == true, true)
			check(res, "osu_caption_not_sweep", seen.WrongCaption, nil)
			local view = workspace.CurrentCamera.ViewportSize
			local touchOnly = UserInputService.TouchEnabled
				and not UserInputService.MouseEnabled
				and not UserInputService.KeyboardEnabled
			local share = (view.Y < PHONE_MAX_HEIGHT or touchOnly) and DIAMETER_PHONE or DIAMETER
			local hud = {}
			for _, path in { BAR, MINION, ROOT .. "/DropList", ROOT .. "/LeaveButton", "RacerHud/Level/Team" } do
				local object = h.find(path)
				if object and shown(path) then
					hud[path] = h.rect(object)
				end
			end
			check(res, "osu_golem_bar_judged", hud[MINION] ~= nil, true)
			local lastShown = -math.huge
			for c = 1, 3 do
				local want = moment - rows[c].Lead - Osu.ApproachSeconds
				local got = seen.Shown[c]
				h.check(
					res,
					"osu_circle_" .. c .. "_appears_on_time",
					got and got - want or "never shown",
					"0 +- " .. SHOW_SLACK,
					got ~= nil and math.abs(got - want) <= SHOW_SLACK
				)
				check(res, "osu_circle_" .. c .. "_in_order", got ~= nil and got > lastShown, true)
				lastShown = got or lastShown
				local r = seen.Rect[c]
				if r then
					local px = share * view.Y
					h.check(res, "osu_circle_" .. c .. "_size", r.h, ">= " .. px, r.h >= px - 1 and r.w >= px - 1)
					local inside = r.x >= MIDDLE * view.X
						and r.x + r.w <= (1 - MIDDLE) * view.X
						and r.y >= MIDDLE * view.Y
						and r.y + r.h <= (1 - MIDDLE) * view.Y
					check(res, "osu_circle_" .. c .. "_in_middle_60", inside, true)
					for path, other in hud do
						check(res, "osu_circle_" .. c .. "_clear_of_" .. path, crossing(r, other), false)
					end
					for j = 1, c - 1 do
						local o = seen.Rect[j]
						if o then
							local d = (Vector2.new(r.x + r.w / 2, r.y + r.h / 2) - Vector2.new(
								o.x + o.w / 2,
								o.y + o.h / 2
							)).Magnitude
							local need = math.max(r.h, o.h)
							h.check(res, ("osu_circles_%d_%d_apart"):format(j, c), d, ">= " .. need, d >= need - 1)
						end
					end
				end
				local first, beat = seen.RingFirst[c], seen.RingBeat[c]
				h.check(
					res,
					"osu_ring_" .. c .. "_starts_wide",
					first or "no Ring",
					">= " .. RING_START_MIN,
					type(first) == "number" and first >= RING_START_MIN
				)
				h.check(
					res,
					"osu_ring_" .. c .. "_meets_circle_at_beat",
					beat or "no Ring",
					"1 +- " .. RING_BEAT_SLACK,
					type(beat) == "number" and math.abs(beat - 1) <= RING_BEAT_SLACK
				)
			end
			local log = spyLog()
			local per = {}
			for _, entry in log do
				per[entry[2]] = (per[entry[2]] or 0) + 1
				check(res, "osu_press_attack_" .. tostring(entry[2]), entry[1], 1)
				local pressed = seen.Pressed[entry[2]]
				h.check(
					res,
					"osu_press_stamp_" .. tostring(entry[2]),
					pressed and entry[3] and entry[3] - pressed or "none",
					"0 +- " .. STAMP_SLACK,
					pressed ~= nil and type(entry[3]) == "number" and math.abs(entry[3] - pressed) <= STAMP_SLACK
				)
			end
			for c = 1, 3 do
				check(res, "osu_press_once_circle_" .. c, per[c], 1)
			end
			check(res, "osu_hit_art_shown", seen.Hit == true, true)
			local gold = seen.Gold
			check(res, "osu_dodged_gold_text", gold ~= nil and gold.R > 0.85 and gold.G > 0.6 and gold.B < 0.45, true)
			check(res, "osu_dodged_no_hit_text", seen.Red ~= nil, false)

			-- The second attack (its sweep): one early press, one never pressed: missed and hit, sweep texts.
			setup(res, "boss_ui_osu_spy") -- a fresh log
			seen = watchAttack(res, Osu, 2, { 0, -0.45 })
			check(res, "osu_caption_sweep", seen.Caption == true, true)
			check(res, "osu_miss_art_shown", seen.Miss == true, true)
			local red = seen.Red
			check(res, "osu_miss_sweep_hit_text_red", red ~= nil and red.R > 0.9 and red.G < 0.3, true)
			check(res, "osu_miss_no_gold", seen.Gold ~= nil, false)
			log = spyLog()
			check(res, "osu_miss_presses_sent", #log, 2)
			check(res, "osu_miss_press_attack_2", log[1] and log[1][1], 2)

			-- In the wait: no circles.
			seen = watchAttack(res, Osu, 1, {}, true)
			check(res, "osu_hidden_in_wait", next(seen.Shown) ~= nil, false)
			setup(res, "boss_ui_wait:none")
		end, debug.traceback)
		h.check(res, "osu_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		setup(res, "boss_ui_minion:none")
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	function scenarios.ui_boss_mage_rewards(res)
		h.waitGuis()
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:1")
			state(res, "Idle", 0)
			setup(res, "boss_phase2_rewards:Defeated:1234567:true:false:false:0.12:" .. MAGE)
			check(res, "mage_rewards_shown", waitShown(POPUP, true), true)
			check(
				res,
				"mage_rewards_title",
				waitIs(function()
					return textOf(POPUP .. "/Header/Title")
				end, DEFEATED_TITLE),
				DEFEATED_TITLE
			)
			-- Her chest's art, Phase 1's Money, no Gems (RELIC_SPEC "The Elf Mage's drops").
			local mageChest = POPUP .. "/Rewards/Chest_" .. MAGE_CHEST
			check(res, "mage_rewards_chest_shown", waitShown(mageChest, true), true)
			local art = h.find(mageChest)
			local chestRow = RelicConfig.Chests[MAGE_CHEST]
			check(res, "mage_rewards_chest_art", art and art.Image, chestRow and chestRow.Image)
			check(res, "mage_rewards_no_raga_chest", shown(POPUP .. "/Rewards/Chest_relic_chest_raga"), false)
			check(res, "mage_rewards_money_shown", shown(POPUP .. "/Rewards/Money"), true)
			check(res, "mage_rewards_no_gems", shown(POPUP .. "/Rewards/Gems"), false)
			setup(res, "boss_phase2_rewards:Defeated:1234567:true:false:false:0.12")
			check(
				res,
				"raga_rewards_title_kept",
				waitIs(function()
					return textOf(POPUP .. "/Header/Title")
				end, "Raga Defeated!"),
				"Raga Defeated!"
			)
			check(res, "raga_rewards_chest_kept", waitShown(POPUP .. "/Rewards/Chest_relic_chest_raga", true), true)
			check(res, "raga_rewards_no_mage_chest", shown(mageChest), false)
			boss(res, MAGE)
			state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 5, Cfg.HpPerPlayer, Cfg.HpPerPlayer, true)
			waitShown(POPUP, false)
			-- Owner 2026-11-11: the drop list is hidden for now, for her too; her odds stay in the Bosses popup's Details.
			check(res, "mage_drop_list_hidden", waitShown(ROOT .. "/DropList", true), false)
			boss(res, nil)
		end, debug.traceback)
		h.check(res, "mage_rewards_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	-- Her arena, the golem and her effects.
	function scenarios.ui_boss_mage_vfx(res)
		setup(res, "boss_ui_gear:2")
		local loaded, Poses = pcall(function()
			-- Design doc 7 "Join size": not at join; the boss setup publishes it, as a real event does.
			return require(
				ReplicatedStorage:WaitForChild("LateData", BUILD_WAIT):WaitForChild("BossMagePoses", BUILD_WAIT)
			)
		end)
		Poses = loaded and type(Poses) == "table" and Poses or nil
		check(res, "mage_poses_loads", Poses ~= nil, true)
		if not Poses then
			setup(res, "restore:boss_ui")
			return
		end
		local function inArena(name)
			local folder = workspace:FindFirstChild("BossArenaPreview")
			return folder and folder:FindFirstChild(name, true)
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
		local function shownParts(model)
			local n = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 1 then
					n += 1
				end
			end
			return n
		end
		-- Seconds since the spawn at which `move` plays at local time from..to, and holds for `hold` s.
		local function timeOf(move, from, to, hold)
			for s = Cfg.IntroSeconds + 1, Cfg.IntroSeconds + 2 * Poses.CycleSeconds, 0.05 do
				local all = true
				for t = 0, hold, 0.25 do
					local name, localTime = Poses.Schedule(0, s + t)
					all = all and name == move and (t > 0 or (localTime >= from and localTime <= to))
				end
				if all then
					return s
				end
			end
			return nil
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
		local savedReduce = h.player:GetAttribute("ReduceEffects")
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			h.player:SetAttribute("ReduceEffects", nil)
			state(res, "Idle", 0)
			boss(res, MAGE)
			state(res, "Prep", 5, 4000, 4000, true, 100)
			local mage = waitFor(function()
				return inArena("ElfMage")
			end, BUILD_WAIT)
			local golem = waitFor(function()
				return inArena("Golem")
			end, BUILD_WAIT)
			check(res, "mage_model_present", mage ~= nil and mage:IsA("Model"), true)
			check(res, "golem_model_present", golem ~= nil and golem:IsA("Model"), true)
			check(res, "mage_target_part_present", mage ~= nil and mage:FindFirstChild("Torso", true) ~= nil, true)
			check(
				res,
				"raga_not_built_for_mage",
				waitFor(function()
					return inArena("BigRaga") == nil
				end, SHOW_WAIT),
				true
			)
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
				"arena_primitives",
				primitives,
				"<= " .. PRIMITIVE_MAX,
				primitives > 0 and primitives <= PRIMITIVE_MAX
			)
			if not (mage and golem) then
				return
			end

			-- The golem stands only while BossMinionStart is set (the miniboss), and crumbles in her golem_fall row.
			local idleAt = timeOf("idle", 0, math.huge, 1)
			local fallAt = timeOf("golem_fall", 0.2, 0.4, 0.25)
			check(res, "schedule_has_idle", idleAt ~= nil, true)
			check(res, "schedule_has_golem_fall", fallAt ~= nil, true)
			if idleAt then
				state(res, "Fight", Cfg.PrepSeconds + idleAt, 4000, 4000, true, 100)
				task.wait(0.4)
				check(res, "golem_hidden_without_minion", shownParts(golem), 0)
				setup(res, "boss_ui_minion:640,1000")
				check(res, "golem_shown_with_minion", waitFor(function()
					return shownParts(golem) > 0
				end, 2) == true, true)
				setup(res, "boss_ui_minion:none")
				check(res, "golem_hidden_after_minion", waitFor(function()
					return shownParts(golem) == 0
				end, 1) == true, true)
			end
			if fallAt then
				state(res, "Fight", Cfg.PrepSeconds + fallAt, 4000, 4000, true, 100)
				check(res, "golem_shown_in_its_fall", waitFor(function()
					return shownParts(golem) > 0
				end, 0.4) == true, true)
			end

			state(res, "Fight", Cfg.PrepSeconds + (idleAt or Cfg.IntroSeconds + 1), 4000, 4000, true, 100)
			-- Her strikes spread over the 2 s window (owner 2026-11-11): fewer bolts made by +0.1 s than by +2.1 s.
			local function boltCounts()
				local made, n, early = {}, 0, nil
				local start = os.clock()
				while os.clock() - start < 2.1 do
					local holder = inArena("BossEffects")
					for _, d in holder and holder:GetDescendants() or {} do
						if d.Name == "Bolt" and not made[d] then
							made[d] = true
							n += 1
						end
					end
					if early == nil and os.clock() - start >= 0.1 then
						early = n
					end
					task.wait()
				end
				return early or n, n
			end
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", "Lightning")
			local early, late = boltCounts()
			h.check(res, "lightning_strikes_spread", early, "< " .. late, late > 0 and early < late)
			-- The move's strikes as drawn, from the LastStrikes debug field (nil if it never came).
			local Arena = (optional("BossArenaConfig") or {}).For
			Arena = Arena and Arena(MAGE)
			check(res, "mage_arena_config_loads", Arena ~= nil, true)
			local function strikeLog(name)
				ReplicatedStorage:SetAttribute("BossVfxForce", "")
				task.wait()
				local holder = inArena("BossEffects")
				if holder then
					holder:SetAttribute("LastStrikes", nil)
				end
				ReplicatedStorage:SetAttribute("BossVfxForce", name)
				local raw = waitFor(function()
					local now = inArena("BossEffects")
					return now and now:GetAttribute("LastStrikes")
				end, SHOW_WAIT)
				local decoded, log = pcall(HttpService.JSONDecode, HttpService, raw or "")
				return decoded and type(log) == "table" and log or nil
			end
			-- Owner 2026-11-11: 14 strikes at 0, 0.15, ... 1.95 s; per strike `least`..`most` bolts or beams.
			local function checkStrikes(tag, name, log, least, most)
				check(res, tag .. "_strike_log", log ~= nil and log.Move, name)
				local list = log and log.Strikes or {}
				check(res, tag .. "_strike_count", #list, STRIKE_COUNT)
				local offTime, offCount, total = {}, {}, 0
				for k, strike in list do
					local want = STRIKE_EVERY * (k - 1)
					if type(strike.T) ~= "number" or math.abs(strike.T - want) > STRIKE_TIME_SLACK then
						table.insert(offTime, ("%d at %s, want %.2f"):format(k, tostring(strike.T), want))
					end
					local n = type(strike.Spots) == "table" and #strike.Spots or 0
					total += n
					if n < least or n > most then
						table.insert(offCount, ("%d has %d"):format(k, n))
					end
				end
				h.checkList(res, tag .. "_strikes_every_0_15", offTime)
				h.checkList(res, tag .. "_per_strike_" .. least .. "_to_" .. most, offCount)
				local lo, hi = STRIKE_COUNT * least, STRIKE_COUNT * most
				h.check(res, tag .. "_total", total, lo .. " to " .. hi, total >= lo and total <= hi)
				return list, total
			end
			-- Not clustered: spots in the centre, on the lanes and on the walkway, in every quarter, none past the wall.
			local function checkSpread(tag, list)
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
			local lightningLog = strikeLog("Lightning")
			local lightningList, bolts =
				checkStrikes("lightning", "Lightning", lightningLog, PER_STRIKE_MIN, PER_STRIKE_MAX)
			checkSpread("lightning", lightningList)
			-- A mark leads each bolt (owner 2026-11-11).
			local marks = 0
			for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
				marks += d.Name == "StrikeMark" and 1 or 0
			end
			check(res, "lightning_mark_per_bolt", marks, bolts)
			local barrageList = checkStrikes("barrage", "Barrage", strikeLog("Barrage"), PER_STRIKE_MIN, PER_STRIKE_MAX)
			checkSpread("barrage", barrageList)
			-- The stronger look (owner 2026-11-12 after playing): per strike, spawns of each layer, grouped into strikes by time.
			local function spawnsOf(name, seconds)
				local out, before, extra, born = {}, {}, {}, os.clock()
				while os.clock() - born < seconds do
					local now = {}
					for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
						if d.Name == name and d:IsA("BasePart") and d.Transparency < 1 then
							now[d] = true
							if not before[d] then
								table.insert(out, { T = os.clock() - born, Color = d.Color })
							end
						elseif d.Name == name and d:IsA("ParticleEmitter") then
							extra[d] = true
						end
					end
					before = now
					task.wait()
				end
				return out, extra
			end
			local function clusters(list) -- spawns within 0.06 s of the one before belong to one strike
				local groups, last = {}, -math.huge
				for _, row in list do
					if row.T - last > 0.06 then
						table.insert(groups, {})
					end
					table.insert(groups[#groups], row)
					last = row.T
				end
				return groups
			end
			local function isWhite(c)
				return c.R >= 0.85 and c.G >= 0.85 and c.B >= 0.85
			end
			local function isPurple(c)
				return c.R >= 0.35 and c.B >= 0.6 and c.G <= 0.55 and c.B > c.G
			end
			local function isDark(c)
				return c.R <= 0.2 and c.G <= 0.2 and c.B <= 0.2
			end
			local function emitterDark(e)
				local k = e.Color.Keypoints
				return isDark(k[1].Value)
			end
			-- Plays `move` and watches one layer `name` (one pass per layer: a forced move draws the same seeded strikes each time).
			local function play(move, name)
				ReplicatedStorage:SetAttribute("BossVfxForce", "")
				task.wait()
				ReplicatedStorage:SetAttribute("BossVfxForce", move)
				return spawnsOf(name, 2.6)
			end
			local function spotsOf(move)
				local log = strikeLog(move)
				local counts = {}
				for k, strike in log and log.Strikes or {} do
					counts[k] = type(strike.Spots) == "table" and #strike.Spots or 0
				end
				return counts
			end
			-- Each group's spawns (all of `ok` colour) against the strike's spots: exactly (`exact`) or at least.
			local function perStrike(tag, groups, counts, isColour, exact)
				local bad = {}
				if #groups ~= #counts then
					table.insert(bad, ("%d strikes drawn, %d logged"):format(#groups, #counts))
				end
				for k, group in groups do
					local want = counts[k] or 0
					local n, wrong = #group, 0
					for _, row in group do
						wrong += isColour(row.Color) and 0 or 1
					end
					if (exact and n ~= want) or n < want or wrong > 0 then
						table.insert(bad, ("%d: %d for %d spots, %d off colour"):format(k, n, want, wrong))
					end
				end
				h.checkList(res, tag, bad)
			end
			for _, few in { false, true } do
				h.player:SetAttribute("ReduceEffects", few or nil)
				local pre = few and "reduced_" or ""
				local lightningSpots = spotsOf("Lightning")
				local cores = play("Lightning", "BoltCore")
				if few then -- effects off: no bolt at all (was plain bolts)
					check(res, "reduced_lightning_no_bolts", #cores, 0)
				else
					perStrike(pre .. "lightning_white_core", clusters(cores), lightningSpots, isWhite, false)
				end
				local glow = play("Lightning", "Bolt")
				local flashes = play("Lightning", "StrikeFlash")
				local rings = play("Lightning", "ShockRing")
				local _, sparks = play("Lightning", "Sparks")
				if few then
					check(res, "reduced_lightning_no_glow", #glow, 0)
					check(res, "reduced_lightning_no_shock_ring", #rings, 0)
					check(res, "reduced_lightning_no_sparks", next(sparks) ~= nil, false)
				else
					perStrike("lightning_purple_glow", clusters(glow), lightningSpots, isPurple, false)
					perStrike("lightning_hit_flash_white", clusters(flashes), lightningSpots, isWhite, true)
					perStrike("lightning_shock_ring_purple", clusters(rings), lightningSpots, isPurple, true)
					check(res, "lightning_sparks", next(sparks) ~= nil, true)
				end
				local barrageSpots = spotsOf("Barrage")
				local beamCores = play("Barrage", "BarrageBeamCore")
				local edges = play("Barrage", "BarrageBeamEdge")
				local smokeParts, smokeEmitters = play("Barrage", "BarrageSmoke")
				local smokeDark = #smokeParts > 0 or next(smokeEmitters) ~= nil
				for _, row in smokeParts do
					smokeDark = smokeDark and isDark(row.Color)
				end
				for e in smokeEmitters do
					smokeDark = smokeDark and emitterDark(e)
				end
				if few then
					check(res, "reduced_barrage_no_black_smoke", #smokeParts == 0 and next(smokeEmitters) == nil, true)
					check(res, "reduced_barrage_no_beams", #beamCores + #edges, 0)
				else
					perStrike("barrage_beam_white_core", clusters(beamCores), barrageSpots, isWhite, false)
					perStrike("barrage_beam_dark_edge", clusters(edges), barrageSpots, isDark, false)
					check(res, "barrage_black_smoke", smokeDark, true)
				end
			end
			h.player:SetAttribute("ReduceEffects", nil)
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			ReplicatedStorage:SetAttribute("BossVfxForce", "")
			task.wait()
			ReplicatedStorage:SetAttribute("BossVfxForce", "Sweep")
			check(res, "sweep_makes_dust", waitFor(function()
				return inArena("SweepDust") ~= nil
			end, PEAK_WATCH) == true, true)
			local full = {}
			for _, name in { "Lightning", "Slam", "Sweep", "Barrage" } do
				full[name] = peak(name)
				h.check(res, "full_" .. string.lower(name) .. "_effects", full[name], "> 0", full[name] > 0)
			end
			-- Effects off (design doc 4.37 "Boss effects have no reduced version", BOSS_EVENT_SPEC "Effects setting", owner
			-- 2026-11-12; replaces "fewer" and 3 per strike): no effect drawn at all, the strike marks stay, and the strike log
			-- keeps the full plan.
			h.player:SetAttribute("ReduceEffects", true)
			local function effectsDrawn(name)
				ReplicatedStorage:SetAttribute("BossVfxForce", "")
				task.wait()
				ReplicatedStorage:SetAttribute("BossVfxForce", name)
				local most, markPeak, stop = 0, 0, os.clock() + PEAK_WATCH
				while os.clock() < stop do
					local n, m = 0, 0
					for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
						local mark = d.Name == "StrikeMark" or (d.Parent and d.Parent.Name == "StrikeMark")
						if mark then
							m += d.Name == "StrikeMark" and 1 or 0
						elseif
							(d:IsA("BasePart") and d.Transparency < 1)
							or (d:IsA("ParticleEmitter") and d.Enabled)
							or (d:IsA("Beam") and d.Enabled)
							or (d:IsA("Trail") and d.Enabled)
						then
							n += 1
						end
					end
					most, markPeak = math.max(most, n), math.max(markPeak, m)
					task.wait(0.05)
				end
				return most, markPeak
			end
			for _, name in { "Lightning", "Slam", "Sweep", "Barrage" } do
				local drawn, markPeak = effectsDrawn(name)
				check(res, "reduced_" .. string.lower(name) .. "_no_effects", drawn, 0)
				if name == "Lightning" then
					h.check(res, "reduced_lightning_marks_stay", markPeak, "> 0", markPeak > 0)
				end
			end
			for _, name in { "Lightning", "Barrage" } do
				local tag = "reduced_" .. string.lower(name)
				checkStrikes(tag, name, strikeLog(name), PER_STRIKE_MIN, PER_STRIKE_MAX)
			end
			-- A Trail on her staff while it swings in lightning and barrage, none at rest, none under REDUCED EFFECTS
			-- (BOSS_EVENT_SPEC "Animation rework" "Impact layer"; task a5b-fx). Contract: an enabled Trail parented under the ElfMage's
			-- Staff part, or whose Attachment0 is, at some time in the move, from the schedule (BossVfxForce off).
			ReplicatedStorage:SetAttribute("BossVfxForce", nil)
			local staff = mage and mage:FindFirstChild("Staff", true)
			check(res, "mage_staff_part_present", staff ~= nil, true)
			local function staffTrailSeen(seconds)
				local stop = os.clock() + seconds
				repeat
					for _, d in workspace:GetDescendants() do
						if d:IsA("Trail") and d.Enabled then
							local a0 = d.Attachment0
							if d:IsDescendantOf(staff) or (a0 and a0:IsDescendantOf(staff)) then
								return true
							end
						end
					end
					task.wait(0.05)
				until os.clock() >= stop
				return false
			end
			if staff then
				for _, move in { "lightning", "barrage" } do
					local startAt = timeOf(move, 0, 0.1, 0)
					check(res, "schedule_has_" .. move, startAt ~= nil, true)
					if startAt then
						state(res, "Fight", Cfg.PrepSeconds + startAt, 4000, 4000, true, 100)
						check(res, "reduced_no_staff_trail_" .. move, staffTrailSeen(Poses.Moves[move].Duration), false)
					end
				end
				h.player:SetAttribute("ReduceEffects", nil)
				if idleAt then
					state(res, "Fight", Cfg.PrepSeconds + idleAt, 4000, 4000, true, 100)
					check(res, "no_staff_trail_at_rest", staffTrailSeen(1), false)
				end
				for _, move in { "lightning", "barrage" } do
					local startAt = timeOf(move, 0, 0.1, 0)
					if startAt then
						state(res, "Fight", Cfg.PrepSeconds + startAt, 4000, 4000, true, 100)
						check(res, "staff_trail_in_" .. move, staffTrailSeen(Poses.Moves[move].Duration), true)
					end
				end
			end
			-- Pose-tied effects (BOSS_EVENT_SPEC "Animation rework" bullet "Pose-tied effects"; task a5c), from the schedule with
			-- BossVfxForce off. Contract (implementer: report a change, do not loosen), instances under BossEffects:
			--   StaffCharge: a BasePart (or Attachment) holding the lightning's charge point, within 3 studs of the staff's tip
			--     (Bind.Staff.Tip on the live Staff part) at some frame of lightning 1.0 to 2.0 s. Not under REDUCED EFFECTS.
			--   MagicCircle (the barrage's circles, as now): each, at the frame it is first seen before 2.0 s, within 25 deg of the
			--     staff's pointing (grip joint to tip) from the tip; first seen one after another with peak sizes not decreasing.
			--     None with effects off (BOSS_EVENT_SPEC "Effects setting", owner 2026-11-12; was 3).
			--   SweepDust (as now): during the golem's sweep, first seen over time (not all in one frame), each within 10 studs (XZ)
			--     of the nearer fist (Golem FistL / FistR) when first seen. None with effects off (was 3 puffs).
			--   GolemRiseDust during the golem's rise (golem 0 to 1.4 s after BossMinionStart), GolemFallDust during her golem_fall
			--     row. Neither under REDUCED EFFECTS.
			--   LastStrikes stays as checked above.
			ReplicatedStorage:SetAttribute("BossVfxForce", nil)
			local AXES =
				CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
			local staffPart = mage and mage:FindFirstChild("Staff", true)
			local staffRow = Poses.Bind.Staff
			-- the staff's grip joint and tip in the world, from the live part (Client/BossRaga's frames, read back)
			local function staffEnds()
				local joint = staffPart.CFrame
					* AXES
					* CFrame.new(Vector3.new(staffRow.Center[1], staffRow.Center[2], staffRow.Center[3]) * Poses.Scale)
						:Inverse()
				local tip = joint:PointToWorldSpace(
					Vector3.new(staffRow.Tip[1], staffRow.Tip[2], staffRow.Tip[3]) * Poses.Scale
				)
				return joint.Position, tip
			end
			-- Every instance called `name` under BossEffects over `seconds`: { [instance] = { At (s from now), Position, Peak } },
			-- with `onFrame(instance, row)` on the frame it is first seen.
			local function watchNamed(name, seconds, onFrame)
				local seen, born = {}, os.clock()
				while os.clock() - born < seconds do
					for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
						if d.Name == name and (d:IsA("BasePart") or d:IsA("Attachment")) then
							local at = d:IsA("Attachment") and d.WorldPosition or d.Position
							local row = seen[d]
							if not row then
								row = { At = os.clock() - born, Position = at, Peak = 0 }
								seen[d] = row
								if onFrame then
									onFrame(d, row)
								end
							end
							row.Peak = d:IsA("BasePart") and math.max(row.Peak, d.Size.X, d.Size.Y) or row.Peak
						end
					end
					task.wait()
				end
				return seen
			end
			local function count(seen)
				local n = 0
				for _ in seen do
					n += 1
				end
				return n
			end
			local lightningAt, barrageAt = timeOf("lightning", 0.75, 0.85, 0), timeOf("barrage", 0, 0.1, 0)
			check(res, "pose_schedule_found", lightningAt ~= nil and barrageAt ~= nil and staffPart ~= nil, true)
			for _, few in { false, true } do
				h.player:SetAttribute("ReduceEffects", few or nil)
				local tag = few and "reduced_" or ""
				if lightningAt and staffPart then
					state(res, "Fight", Cfg.PrepSeconds + lightningAt, 4000, 4000, true, 100)
					local nearest = math.huge
					local stop = os.clock() + 1.2 -- from 0.8 to 2.0 s
					while os.clock() < stop do
						local _, tip = staffEnds()
						for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
							if d.Name == "StaffCharge" and (d:IsA("BasePart") or d:IsA("Attachment")) then
								local at = d:IsA("Attachment") and d.WorldPosition or d.Position
								nearest = math.min(nearest, (at - tip).Magnitude)
							end
						end
						task.wait()
					end
					if few then
						check(res, "reduced_no_lightning_charge", nearest == math.huge, true)
					else
						h.check(res, "lightning_charge_at_staff_tip", nearest, "<= 3", nearest <= 3)
					end
				end
				if barrageAt and staffPart then
					-- Owner 2026-11-12 morning (BOSS_EVENT_SPEC "Pose-tied effect values", proposed): the circles open one by one,
					-- 0.28 s apart from 0.3 s, all fully open before the beams fire at 2.0 s, 15 to 36 studs across. Watched from the
					-- move's start to 2.4 s; times are the move's local time (BossMagePoses.Schedule on the client's schedule start).
					-- Only this barrage's circles (a Studio run counted another's): start from a room with none, read the move's
					-- local time from the client's own schedule each frame, keep circles first seen inside this occurrence's 0 to
					-- 2.4 s, and if the schedule leaves it or jumps (another source), watch the next cycle's barrage instead.
					local function scheduleNow()
						local start = ReplicatedStorage:GetAttribute("BossScheduleStart")
							or (ReplicatedStorage:GetAttribute("BossEventStart") or 0) + Cfg.PrepSeconds
						return Poses.Schedule(start, workspace:GetServerTimeNow())
					end
					local function circlesLeft()
						for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
							if d.Name == "MagicCircle" then
								return true
							end
						end
						return false
					end
					local clean = true
					local function observe(at)
						if idleAt then
							state(res, "Fight", Cfg.PrepSeconds + idleAt, 4000, 4000, true, 100)
						end
						local cleanBy = os.clock() + 6
						while circlesLeft() and os.clock() < cleanBy do
							task.wait(0.05)
						end
						clean = clean and not circlesLeft()
						state(res, "Fight", Cfg.PrepSeconds + at, 4000, 4000, true, 100)
						local seenOff, rows, firstBeam = {}, {}, math.huge
						local entered = os.clock() + 2
						local move, t = scheduleNow()
						while not (move == "barrage" and t < 0.3) and os.clock() < entered do
							task.wait()
							move, t = scheduleNow()
						end
						if not (move == "barrage" and t < 0.3) then
							return false
						end
						local last = t
						while true do
							move, t = scheduleNow()
							if move ~= "barrage" or t < last - 1e-3 then
								return t >= 2.4 and move == "barrage", rows, seenOff, firstBeam
							end
							if t > 2.4 then
								return true, rows, seenOff, firstBeam
							end
							last = t
							for _, d in (inArena("BossEffects") or workspace):GetDescendants() do
								if d:IsA("BasePart") and d.Name == "MagicCircle" then
									local row = rows[d]
									if not row then
										-- Owner 2026-11-12 after playing (BOSS_EVENT_SPEC "Pose-tied effect values": "a wide fan
										-- of rings in front of the staff and around her"): within 70 deg of the staff's aim seen
										-- from her (was 25 deg from the tip, for a row of circles along the aim).
										local grip, tip = staffEnds()
										local her = mage:FindFirstChild("Torso", true)
										local aim = (tip - grip).Unit
										local to = d.Position - (her and her.Position or tip)
										local angle = to.Magnitude > 0
												and math.deg(math.acos(math.clamp(aim:Dot(to.Unit), -1, 1)))
											or 180
										if angle > 70 then
											table.insert(seenOff, ("%.0f"):format(angle))
										end
										row = { At = t, Peak = 0, Sizes = {} }
										rows[d] = row
									end
									local size = math.max(d.Size.X, d.Size.Y)
									row.Peak = math.max(row.Peak, size)
									table.insert(row.Sizes, { t, size })
								elseif d:IsA("BasePart") and d.Name == "BarrageBeam" and d.Transparency < 1 then
									firstBeam = math.min(firstBeam, t)
								end
							end
							task.wait()
						end
					end
					local watched, circleRows, off, beamAt = observe(barrageAt)
					if not watched then
						watched, circleRows, off, beamAt = observe(barrageAt + Poses.CycleSeconds)
					end
					check(res, tag .. "barrage_clean_start", clean, true)
					check(res, tag .. "barrage_window_watched", watched == true, true)
					circleRows, off, beamAt = circleRows or {}, off or {}, beamAt or math.huge
					local list = {}
					for _, row in circleRows do
						row.FullAt = math.huge -- first time at 98% of its peak
						for _, sample in row.Sizes do
							if sample[2] >= 0.98 * row.Peak then
								row.FullAt = math.min(row.FullAt, sample[1])
							end
						end
						table.insert(list, row)
					end
					table.sort(list, function(x, y)
						return x.At < y.At
					end)
					local ordered, minGap = #list > 1, math.huge
					for i = 2, #list do
						ordered = ordered and list[i].At > list[i - 1].At and list[i].Peak >= list[i - 1].Peak - 0.01
						minGap = math.min(minGap, list[i].At - list[i - 1].At)
					end
					local want = 10 -- owner 2026-11-12 after playing: 10 (was 6)
					local beforeBeams, lastFull, smallest, largest = 0, -math.huge, math.huge, 0
					for _, row in list do
						beforeBeams += row.At < 2.0 and 1 or 0
						lastFull = math.max(lastFull, row.FullAt)
						smallest, largest = math.min(smallest, row.Peak), math.max(largest, row.Peak)
					end
					-- effects off (design doc 4.37 "Boss effects have no reduced version", BOSS_EVENT_SPEC "Effects setting"): no
					-- circles (was 3)
					if few then
						check(res, "reduced_no_barrage_circles", #list, 0)
					else
						check(res, tag .. "barrage_circles_seen", #list > 0, true)
						h.checkList(res, tag .. "barrage_circles_in_front_of_staff", off)
						check(res, tag .. "barrage_circles_one_after_another", ordered, true)
						-- 0.15 s apart (owner 2026-11-12 after playing; was 0.28 with a 0.2 floor), 0.12 with frame slack
						h.check(res, tag .. "barrage_circles_spaced", minGap, ">= 0.12", #list > 1 and minGap >= 0.12)
						h.check(
							res,
							tag .. "barrage_circles_all_open_before_beams",
							("%d of %d by 2.0 s, last full at %.2f, first beam at %.2f"):format(
								beforeBeams,
								want,
								lastFull,
								beamAt
							),
							("%d, full before the first beam and 2.0 s"):format(want),
							beforeBeams == want and lastFull <= math.min(beamAt, 2.0)
						)
						do
							h.check(
								res,
								"barrage_circles_bigger",
								("%.1f to %.1f"):format(smallest, largest),
								"smallest >= 28, largest >= 65", -- 30 to 70 studs (owner 2026-11-12 after playing; was 15 to 36)
								#list > 0 and smallest >= 28 and largest >= 65
							)
						end
					end
				end
				-- The golem: its rise raises dust; its sweep's dust follows the fist; her golem_fall row raises dust.
				if golem then
					setup(res, "boss_ui_minion:640,1000")
					local rise = watchNamed("GolemRiseDust", 1.4)
					if few then
						check(res, "reduced_no_golem_rise_dust", count(rise), 0)
					else
						h.check(res, "golem_rise_dust", count(rise), "> 0", count(rise) > 0)
					end
					-- the second attack is the sweep: its track starts 7.6 s after the start (hit 10.2 s, 2.6 s into the track)
					ReplicatedStorage:SetAttribute("BossMinionStart", workspace:GetServerTimeNow() - 7.4)
					local far = {}
					local fists = { golem:FindFirstChild("FistL", true), golem:FindFirstChild("FistR", true) }
					local dust = watchNamed("SweepDust", 4.4, function(_, row)
						local best = math.huge
						for _, fist in fists do
							local d = (fist.Position - row.Position) * Vector3.new(1, 0, 1)
							best = math.min(best, d.Magnitude)
						end
						if best > 10 then
							table.insert(far, ("%.1f"):format(best))
						end
					end)
					local first, last = math.huge, -math.huge
					for _, row in dust do
						first, last = math.min(first, row.At), math.max(last, row.At)
					end
					check(res, tag .. "golem_fists_present", fists[1] ~= nil and fists[2] ~= nil, true)
					if few then -- effects off (BOSS_EVENT_SPEC "Effects setting"): no sweep dust (was 3 puffs)
						check(res, "reduced_no_sweep_dust", count(dust), 0)
					else
						check(res, "sweep_dust_seen", count(dust) > 0, true)
						h.checkList(res, "sweep_dust_follows_fist", far)
						h.check(res, "sweep_dust_over_time", last - first, ">= 0.3", last - first >= 0.3)
					end
					setup(res, "boss_ui_minion:none")
					local fallStart = timeOf("golem_fall", 0, 0.1, 0)
					check(res, "schedule_has_golem_fall_row", fallStart ~= nil, true)
					if fallStart then
						state(res, "Fight", Cfg.PrepSeconds + fallStart, 4000, 4000, true, 100)
						local fall = watchNamed("GolemFallDust", Poses.Moves.golem_fall.Duration)
						if few then
							check(res, "reduced_no_golem_fall_dust", count(fall), 0)
						else
							h.check(res, "golem_fall_dust", count(fall), "> 0", count(fall) > 0)
						end
					end
				end
			end
			h.player:SetAttribute("ReduceEffects", nil)
		end, debug.traceback)
		h.check(res, "mage_vfx_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		ReplicatedStorage:SetAttribute("BossVfxForce", nil)
		h.player:SetAttribute("ReduceEffects", savedReduce)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	-- The jointed Elf Mage in game (design doc 4.37 "Animation rework", BOSS_EVENT_SPEC "Animation rework" Rigs; task a4-mage), as
	-- ui_boss_king_rig. Contract (implementer: report a change, do not loosen): workspace.BossArenaPreview holds Model ElfMage with
	-- BaseParts named as BossMagePoses.Bind: Torso, Head, Left/RightUpperArm, Left/RightLowerArm, Left/RightUpperLeg,
	-- Left/RightLowerLeg, TailL1..3, TailR1..3, Staff, and none of LeftArm, RightArm, LeftLeg, RightLeg, TailL, TailR. The staff's
	-- axis is its BasePart's longest side. Until the jointed meshes are uploaded the rig falls back to the old meshes on the upper
	-- segments, so rig_jointed_parts stays red then; the pose checks use only Head and Staff and still run. A sanity check that
	-- lightning plays on the jointed rig, not exact numbers: at 1.0 s (cast raise, key 3 at 0.95 s) the staff's upper end is above
	-- her head and the staff upright; at 2.05 s (the first strike, key 6 at 2.0 s "levelled at the arena") the staff is near level.
	function scenarios.ui_boss_mage_rig(res)
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
			"TailL1",
			"TailL2",
			"TailL3",
			"TailR1",
			"TailR2",
			"TailR3",
			"Staff",
		}
		local LIGHTNING_AT = 2.0 -- the Lightning event in lightning's local time (BossDodge's moment)
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			state(res, "Idle", 0)
			boss(res, MAGE)
			state(res, "Prep", 5, 4000, 4000, true, 100)
			local deadline, mage = os.clock() + BUILD_WAIT, nil
			repeat
				local folder = workspace:FindFirstChild("BossArenaPreview")
				mage = folder and folder:FindFirstChild("ElfMage", true)
				if not mage then
					task.wait(0.05)
				end
			until mage or os.clock() > deadline
			check(res, "rig_mage_present", mage ~= nil and mage:IsA("Model"), true)
			if not mage then
				return
			end
			local missing = {}
			for _, name in JOINTED do
				local part = mage:FindFirstChild(name, true)
				if not (part and part:IsA("BasePart")) then
					table.insert(missing, name)
				end
			end
			h.checkList(res, "rig_jointed_parts", missing)
			for _, name in { "LeftArm", "RightArm", "LeftLeg", "RightLeg", "TailL", "TailR" } do
				check(res, "rig_no_unjointed_" .. name, mage:FindFirstChild(name, true), nil)
			end
			local index, at = firstMoment("Lightning")
			check(res, "rig_lightning_moment_found", index ~= nil, true)
			local staff, head = mage:FindFirstChild("Staff", true), mage:FindFirstChild("Head", true)
			check(
				res,
				"rig_staff_and_head",
				staff ~= nil and head ~= nil and staff:IsA("BasePart") and head:IsA("BasePart"),
				true
			)
			if not index or not (staff and head and staff:IsA("BasePart") and head:IsA("BasePart")) then
				return
			end
			-- lightning's local time `localTime`, then a few frames to pose: the staff's unit axis, its upper end's height above
			-- the top of her head's box.
			local function at_(localTime)
				state(
					res,
					"Fight",
					Cfg.PrepSeconds + Cfg.IntroSeconds + at - LIGHTNING_AT + localTime,
					4000,
					4000,
					true,
					100
				)
				task.wait(0.1)
				local size, cf = staff.Size, staff.CFrame
				local axis, length = cf.RightVector, size.X
				if size.Y > length then
					axis, length = cf.UpVector, size.Y
				end
				if size.Z > length then
					axis, length = cf.LookVector, size.Z
				end
				local top = staff.Position.Y + math.abs(axis.Y) * length / 2
				local headTop = -math.huge
				for _, x in { -0.5, 0.5 } do
					for _, y in { -0.5, 0.5 } do
						for _, z in { -0.5, 0.5 } do
							headTop = math.max(headTop, (head.CFrame * (head.Size * Vector3.new(x, y, z))).Y)
						end
					end
				end
				return axis, top - headTop
			end
			local castAxis, castAbove = at_(1.0)
			h.check(res, "rig_cast_staff_above_head", castAbove, "> 0", castAbove > 0)
			h.check(res, "rig_cast_staff_upright", math.abs(castAxis.Y), ">= 0.8", math.abs(castAxis.Y) >= 0.8)
			local strikeAxis = at_(2.05)
			h.check(res, "rig_strike_staff_level", math.abs(strikeAxis.Y), "<= 0.5", math.abs(strikeAxis.Y) <= 0.5)
		end, debug.traceback)
		h.check(res, "mage_rig_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	return { Scenarios = scenarios, After = after }
end

return Module
