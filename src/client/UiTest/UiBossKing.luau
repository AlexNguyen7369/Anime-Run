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
-- His own arena's part budget (BOSS_EVENT_SPEC "The Golden King's arena": target about 1,200, proposed; measured and reported).
local KING_ARENA_PARTS_MAX = 1250
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

	-- His own arena in game (design doc 4.37 "The Golden King's own arena", "Rework approvals"; BOSS_EVENT_SPEC "The Golden
	-- King's arena"; task a8-arena). Contract (implementer: report a change, do not loosen): workspace.BossArenaPreview holds a
	-- Folder or Model KingArena (his arena, every part of it under it) with the mound under a child named KingMound, and Model
	-- GoldenKing. Checks: the arena's BaseParts (MeshParts included) reported and <= 1,250; nothing on the lane band above the
	-- deck; nothing inside the ring over 12 studs but the mound; his feet (the lowest corner of his leg parts) about 12 over the
	-- mound's top; the camera's FOV 60 for the whole event in his arena (no change during a move), 100 in the mage's and Big
	-- Raga's; the sunset profile (BiomeEnvironment.Profile(ARENA_ZONE, "boss_king")) applied in his event, the zone's own after.
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
			-- The camera in Prep (still Prep here; the hover below moves to the fight).
			check(res, "king_fov_60_in_prep", waitIs(fov, 60), 60)
			-- His hover, in Fight after the rise (in Prep he is hidden far below) and in the cycle's first idle row (his moves dip
			-- the root on purpose), sampled over one full 3 s bob: 12 +/- 0.75 with a little float slack.
			local gatesIndex, gatesAt = firstMoment("gates")
			local HOVER_FROM, HOVER_FOR = 0.3, 3.2 -- s into the fight
			check(
				res,
				"hover_window_in_idle",
				gatesIndex ~= nil and gatesAt - 1.6 - 0.75 >= HOVER_FROM + HOVER_FOR, -- before gates_in and its lead
				true
			)
			if king and moundTop > -math.huge then
				state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + HOVER_FROM, hp, hp, true, 100)
				task.wait(0.1)
				local low, high, stop = math.huge, -math.huge, os.clock() + HOVER_FOR - 0.1
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
					task.wait()
				end
				local span = ("%.2f to %.2f"):format(low, high)
				h.check(res, "king_feet_over_mound", span, "min > 0", low > 0)
				h.check(res, "king_hover_about_12", span, "10.5 to 13.5", low >= 10.5 and high <= 13.5)
			end

			-- The camera: FOV 60 for the whole event in his arena, through a move.
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
					"king_fov_60_through_enuma",
					("%s to %s"):format(low, high),
					"60 to 60",
					low == 60 and high == 60
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
			waitIs(fov, 60)
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
				"gates_portals_12_to_20",
				portals,
				PORTALS_MIN .. " to " .. PORTALS_MAX,
				portals >= PORTALS_MIN and portals <= PORTALS_MAX
			)
			h.check(res, "gates_streaks_drawn", mostNamed("Gates", "Streak"), "> 0", mostNamed("Gates", "Streak") > 0)
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
