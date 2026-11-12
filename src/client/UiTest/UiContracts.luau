--!nonstrict
-- Additive 2026-10-20 UI contracts. Read-only server truth; no real gameplay/purchase remote calls.
-- The main tester runs these at desktop AND real phone sizes; simulated geometry is additional evidence.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.CharacterCatalog)
local Portraits = require(Shared.CharacterPortraits)
local TrackRegistry = require(Shared.TrackRegistry)
local TrackCards = require(Shared.TrackCards)
local NpcConfig = require(Shared.NpcConfig)
local Format = require(Shared.HudFormat)
local Market = require(Shared.MarketConfig)
local RaceConfig = require(Shared.RaceConfig)
local Monetization = require(Shared.MonetizationConfig)
local Daily = require(Shared.DailyLoginConfig)
local Spec = require(script.Parent.UiSpec)

local Contracts = {}

function Contracts.Build(h)
	local scenarios, after = {}, {}
	local function check(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local function required(res, path, class)
		local object = h.find(path)
		h.check(
			res,
			"present_" .. path,
			object and object.ClassName or "missing",
			class,
			object ~= nil and object:IsA(class)
		)
		return object and object:IsA(class) and object or nil
	end
	local function text(object)
		return object and h.allText(object) or "missing"
	end
	local function containsText(value, needle)
		return string.find(string.lower(value), string.lower(needle), 1, true) ~= nil
	end
	local function modulePresent(res, name)
		local object = script.Parent.Parent:FindFirstChild(name)
		check(res, "shared_client_module_" .. name, object ~= nil and object:IsA("ModuleScript"), true)
	end
	local function sameLine(a, b)
		return math.abs(a.AbsolutePosition.Y - b.AbsolutePosition.Y) <= Spec.Tolerance
	end

	-- Independent oracle from design doc 4.15 (never the UI's own IsOpen / Effective helpers): Track 1 and every track
	-- up to BestTrack + 1 are open; the current checkpoint is the saved one clamped into that range.
	local function checkpointState()
		local tracks = TrackRegistry.Chain()
		local best = math.clamp(math.floor(h.player:GetAttribute("BestTrack") or 0) + 1, 1, #tracks)
		local current = math.clamp(math.floor(h.player:GetAttribute("Checkpoint") or 1), 1, best)
		return tracks, best, current
	end
	-- The biome's in-game name (BiomeThemes <Biome>.DisplayName, the welcome popup's), e.g. "Shibuyo Underground"
	local function biomeTitle(biome)
		local theme = require(ReplicatedStorage.Shared.BiomeThemes)[biome or ""]
		return theme and theme.DisplayName or ""
	end

	function scenarios.ui_checkpoints(res)
		local restore = h.setPanels({ Spec.Checkpoints.Panel })
		h.frames(2)
		local panel = required(res, Spec.Checkpoints.Panel, "Frame")
		local cards = required(res, Spec.Checkpoints.Cards, "ScrollingFrame")
		if not (panel and cards) then
			restore()
			return
		end
		-- A click's ScrollIntoView can leave the list scrolled; h.geometry would then flag cards clipped out of view
		cards.CanvasPosition = Vector2.zero
		h.frames(1)
		check(res, "checkpoint_panel_shown", h.visible(panel), true)
		-- HUD_LAYOUT_SPEC section 2 + CHECKPOINT_SPEC section 3 (owner 2026-10-20): the panel uses PanelFrame.Attach
		check(res, "checkpoint_panel_frame_attached", panel:GetAttribute("PanelFrame"), true)
		check(res, "checkpoint_panel_theme", panel:GetAttribute("PanelTheme"), Spec.Checkpoints.PanelTheme)
		required(res, Spec.Checkpoints.Panel .. "/Header/Title", "TextLabel")
		required(res, Spec.Checkpoints.Panel .. "/Header/Icon", "GuiObject")
		local tracks, best, current = checkpointState()
		local expected, shown = {}, 0
		local previous
		-- Design doc 4.15 (owner 2026-11-04): a vertical list of long cards showing only the number, road screenshot, biome
		-- name, definition, recommended speed and enemy. Locked cards stay dimmed and clickable; the click picks nothing.
		for _, track in tracks do
			local n = track.Number
			local prefix = "checkpoint_track_" .. n
			local card = required(res, Spec.Checkpoints.Cards .. "/Track_" .. n, "TextButton")
			expected["Track_" .. n] = true
			if not card then
				continue
			end
			check(res, prefix .. "_order", card.LayoutOrder, n)
			if previous then
				local a, b = previous.AbsolutePosition, card.AbsolutePosition
				check(
					res,
					prefix .. "_below_previous",
					b.Y > a.Y + Spec.Tolerance and b.Y >= a.Y + previous.AbsoluteSize.Y - Spec.Tolerance,
					true
				)
				h.check(res, prefix .. "_same_x", b.X, a.X, math.abs(b.X - a.X) <= Spec.Tolerance)
			end
			previous = card
			local size = card.AbsoluteSize
			h.check(
				res,
				prefix .. "_width_of_list",
				size.X,
				cards.AbsoluteSize.X * Spec.Checkpoints.CardMinWidthShare,
				size.X >= cards.AbsoluteSize.X * Spec.Checkpoints.CardMinWidthShare
			)
			check(res, prefix .. "_long", size.Y > 0 and size.X > size.Y, true)
			local function label(name)
				return text(required(res, h.pathOf(card) .. "/" .. name, "TextLabel"))
			end
			required(res, h.pathOf(card) .. "/Diamond", "Frame")
			check(res, prefix .. "_number", label("Number"), tostring(n))
			local road = required(res, h.pathOf(card) .. "/Road", "ImageLabel")
			check(
				res,
				prefix .. "_road_image",
				road ~= nil and string.match(road.Image, "^rbxassetid://%d+$") ~= nil,
				true
			)
			check(res, prefix .. "_title", label("Title"), biomeTitle(track.Biome))
			local blurb = label("Blurb")
			check(res, prefix .. "_blurb", blurb, (TrackCards[n] or {}).Blurb)
			check(res, prefix .. "_blurb_filled", blurb ~= "" and blurb ~= "missing", true)
			check(
				res,
				prefix .. "_speed",
				label("Speed"),
				Spec.Checkpoints.SpeedPrefix .. Format.SpeedText(NpcConfig.RecommendedSpeed(n))
			)
			check(res, prefix .. "_enemy", label("Enemy"), Spec.Checkpoints.EnemyPrefix .. NpcConfig.For(n).Label)
			local chip = card:FindFirstChild("Chip")
			check(res, prefix .. "_chip_only_on_current", chip ~= nil and chip.Visible == true, n == current)
			if n == current then
				check(res, prefix .. "_chip_text", label("Chip"), Spec.Checkpoints.ChipText)
			end
			local lock = required(res, h.pathOf(card) .. "/Lock", "Frame")
			local unlocked = n <= best
			if lock then
				check(res, prefix .. "_lock_visible", lock.Visible, not unlocked)
				-- (BackgroundTransparency is a float32: 0.4 reads back as 0.40000000596; equal within float precision only)
				h.check(
					res,
					prefix .. "_lock_transparency",
					lock.BackgroundTransparency,
					Spec.Checkpoints.LockTransparency,
					math.abs(lock.BackgroundTransparency - Spec.Checkpoints.LockTransparency) <= 1e-6
				)
				check(res, prefix .. "_lock_reason", text(lock:FindFirstChild("Need")), "Beat Track " .. (n - 1))
				local icon = required(res, h.pathOf(lock) .. "/Icon", "TextLabel")
				check(res, prefix .. "_lock_icon", icon ~= nil and icon.Text ~= "", true)
				-- The lock must not take the click from its card (the click lands on the card and picks nothing)
				local swallows = {}
				for _, o in { lock, table.unpack(lock:GetDescendants()) } do
					if o:IsA("GuiButton") or (o:IsA("GuiObject") and o.Active) then
						table.insert(swallows, h.pathOf(o))
					end
				end
				h.checkList(res, prefix .. "_lock_click_through", swallows)
			end
			check(res, prefix .. "_clickable", card.Active, true)
			-- The card holds no other text (design doc 4.15: no payout, length or time)
			local allowed = {}
			for _, name in { "Number", "Title", "Blurb", "Speed", "Enemy", "Chip" } do
				local object = card:FindFirstChild(name)
				if object then
					allowed[object] = true
				end
			end
			for _, name in { "Icon", "Need" } do
				local object = lock and lock:FindFirstChild(name)
				if object then
					allowed[object] = true
				end
			end
			local strays = {}
			for _, o in { card, table.unpack(card:GetDescendants()) } do
				local hasText = o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")
				if hasText and o.Text ~= "" and h.visible(o) and not allowed[o] then
					table.insert(strays, h.pathOf(o) .. " = " .. o.Text)
				end
			end
			h.checkList(res, prefix .. "_only_card_text", strays)
		end
		local extras = {}
		for _, child in cards:GetChildren() do
			if child:IsA("GuiObject") then
				shown += 1
				if not expected[child.Name] then
					table.insert(extras, child.Name)
				end
			end
		end
		check(res, "checkpoint_exact_card_count", shown, #tracks)
		h.checkList(res, "checkpoint_no_extra_cards", extras)
		-- No 3D render, detail pane or START HERE (design doc 4.15)
		local viewports = {}
		for _, object in panel:GetDescendants() do
			if object:IsA("ViewportFrame") then
				table.insert(viewports, h.pathOf(object))
			end
		end
		h.checkList(res, "checkpoint_no_viewport", viewports)
		check(res, "checkpoint_no_detail_pane", panel:FindFirstChild("Detail", true) == nil, true)
		check(res, "checkpoint_no_start_button", panel:FindFirstChild("Start", true) == nil, true)
		h.geometry.Panel(res, "checkpoint", panel)
		h.geometry.Topmost(res, "checkpoint", panel, cards)
		local header = required(res, Spec.Checkpoints.Panel .. "/Header", "Frame")
		local hint = required(res, Spec.Checkpoints.Panel .. "/Hint", "TextLabel")
		if header and hint then
			-- No section overlaps another
			h.geometry.Group(res, "checkpoint_sections", panel, { header, hint, cards })
		end
		local remote = ReplicatedStorage:FindFirstChild("Remotes")
		remote = remote and remote:FindFirstChild("SetCheckpoint")
		check(res, "checkpoint_remote_function", remote ~= nil and remote:IsA("RemoteFunction"), true)
		-- World entry is part of the UI inventory too; actual E/toggle behavior is a real input check.
		local prompts = {}
		for _, object in workspace:GetDescendants() do
			if object:IsA("ProximityPrompt") and object.Name == Spec.Checkpoints.Prompt then
				table.insert(prompts, object)
			end
		end
		check(res, "checkpoint_exactly_one_prompt", #prompts, 1)
		if #prompts == 1 then
			check(res, "checkpoint_prompt_key", prompts[1].KeyboardKeyCode, Enum.KeyCode.E)
			check(res, "checkpoint_prompt_action", prompts[1].ActionText, "Tracks")
			check(res, "checkpoint_prompt_distance", prompts[1].MaxActivationDistance, 10)
		end
		restore()
	end

	function after.checkpoint_not_optimistic(res, ctx)
		check(res, "checkpoint_unchanged_after_refused_pick", h.player:GetAttribute("Checkpoint"), ctx.pre.Checkpoint)
		scenarios.ui_checkpoints(res)
	end

	-- docs/CHARACTER_GACHA_SPEC.md "Launch cast": every catalog character has its Index tile with its public odds and
	-- Order; Count / Rarities are for the 44 regular characters, the event-only ones (Event set) are checked apart.
	function scenarios.ui_catalog_manifest(res)
		local cast = Catalog.All()
		local restore = h.setPanels({ "RacerIndex/Panel" })
		h.frames(2)
		local root = "RacerIndex/Panel/Face/GridHost/Gallery/"
		local ids, rarities, missing, regular, events = {}, {}, {}, 0, {}
		for _, entry in cast do
			check(res, "cast_unique_" .. entry.Id, ids[entry.Id] == nil, true)
			ids[entry.Id] = true
			if entry.Event == nil then
				regular += 1
				rarities[entry.Rarity] = (rarities[entry.Rarity] or 0) + 1
			else
				events[entry.Id] = entry.Event
			end
			local tile = h.find(root .. entry.Id)
			if not tile then
				table.insert(missing, entry.Id)
			end
			check(
				res,
				"cast_base_rollable_" .. entry.Id,
				entry.Rollable == true
					and entry.GamepassId == nil
					and (entry.Event == nil or Spec.CharacterCast.Events[entry.Id] == entry.Event),
				true
			)
			if tile then
				local odds = tile:FindFirstChild("Odds")
				-- Public rarity stays visible even for undiscovered characters, and never changes with luck.
				check(res, "cast_odds_" .. entry.Id, text(odds), Format.Odds(entry.Chance))
				check(res, "cast_tile_order_" .. entry.Id, tile.LayoutOrder, entry.Order)
			end
		end
		check(res, "cast_count", regular, Spec.CharacterCast.Count)
		for id, event in Spec.CharacterCast.Events do
			check(res, "cast_event_character_" .. id, events[id], event)
			events[id] = nil
		end
		check(res, "cast_no_other_event_characters", next(events) == nil, true)
		for rarity, amount in Spec.CharacterCast.Rarities do
			check(res, "cast_rarity_" .. rarity, rarities[rarity] or 0, amount)
			rarities[rarity] = nil
		end
		check(res, "cast_no_other_rarities", next(rarities) == nil, true)
		h.checkList(res, "cast_tiles_present", missing)
		local catchalls = {}
		for _, car in Catalog.All() do
			if car.Chance == nil then
				table.insert(catchalls, car.Id)
			end
		end
		check(res, "index_single_original_catchall", table.concat(catchalls, ","), "sea_navigator")
		check(res, "index_excludes_starter", h.find(root .. Catalog.STARTER_ID) == nil, true)
		restore()
	end

	-- Reused Header children must not be duplicated or left covering the new frame.
	function scenarios.ui_shared_frames(res)
		modulePresent(res, "PanelFrame")
		local restore = h.setPanels({})
		for _, frame in Spec.SharedFrames do
			h.switch.Close("Daily")
			h.switch.Close(frame.Action)
			-- let the close motion (design doc 4.20) finish before reopening: up to UiSpec.Waits.PanelClose
			local closing = h.find(frame.Panel)
			local deadline = os.clock() + Spec.Waits.PanelClose
			while closing and h.visible(closing) and os.clock() < deadline do
				task.wait()
			end
			h.switch.Action(frame.Action)
			h.frames(2)
			local panel = required(res, frame.Panel, "Frame")
			if not panel then
				continue
			end
			local prefix = "frame_" .. string.lower(frame.Action)
			check(res, prefix .. "_shown", h.visible(panel), true)
			check(res, prefix .. "_shared_marker", panel:GetAttribute("PanelFrame"), true)
			local header = required(res, frame.Panel .. "/Header", "Frame")
			local legacyDaily = frame.Action == "Daily" or frame.Action == "Quests"
			local icon =
				required(res, frame.Panel .. (legacyDaily and "/Header/CalendarIcon" or "/Header/Icon"), "ImageLabel")
			local title = required(
				res,
				frame.Panel .. ((legacyDaily or frame.Action == "Shop") and "/Title" or "/Header/Title"),
				"TextLabel"
			)
			local close = required(res, frame.Panel .. "/" .. frame.Close, "GuiButton")
			if title then
				check(res, prefix .. "_title", containsText(title.Text, frame.Title), true)
			end
			if icon then
				check(res, prefix .. "_icon_drawn", icon.Image ~= "" and h.visible(icon), true)
			end
			local closes, headers = 0, 0
			for _, object in panel:GetDescendants() do
				if object:IsA("GuiButton") and object.Name == "Close" then
					closes += 1
				elseif object:IsA("Frame") and object.Name == "Header" then
					headers += 1
				end
			end
			check(res, prefix .. "_one_close", closes, 1)
			check(res, prefix .. "_one_header", headers, 1)
			check(res, prefix .. "_rounded", panel:FindFirstChildWhichIsA("UICorner") ~= nil, true)
			check(res, prefix .. "_outline", panel:FindFirstChildWhichIsA("UIStroke") ~= nil, true)
			if header then
				local gradient = header:FindFirstChildWhichIsA("UIGradient")
				check(res, prefix .. "_gradient", gradient ~= nil, true)
				if gradient then
					local c = gradient.Color.Keypoints[1].Value
					local colour = frame.Colour
					local matches = colour == "red" and c.R > c.G and c.R > c.B
						or colour == "blue" and c.B > c.R and c.B > c.G
						or colour == "purple" and c.R > c.G and c.B > c.G
						or colour == "orange" and c.R > c.G and c.G > c.B
					check(res, prefix .. "_colour_" .. colour, matches, true)
				end
			end
			if close then
				local c = close.BackgroundColor3
				check(res, prefix .. "_close_red", c.R > c.G and c.R > c.B and close.BackgroundTransparency < 0.5, true)
				h.check(
					res,
					prefix .. "_close_square",
					close.AbsoluteSize.X - close.AbsoluteSize.Y,
					0,
					math.abs(close.AbsoluteSize.X - close.AbsoluteSize.Y) <= Spec.Tolerance
				)
			end
			if header and icon and title and close then
				-- Legacy Close parent is Panel, but it must occupy the header band just like the reused Close.
				h.geometry.Group(res, prefix .. "_header", header, { icon, title, close })
			end
			h.geometry.Panel(res, prefix, panel)
		end
		restore()
	end

	function scenarios.ui_gift_cards(res)
		local restore = h.setPanels({ "ShopUi/Backdrop" })
		h.frames(2)
		local function gift(section, id, enabled, reason)
			local path = Spec.Shop.Items .. "/" .. section .. "/**/" .. id .. "/Gift"
			local button = required(res, path, "GuiButton")
			if not button then
				return
			end
			local prefix = "gift_" .. id
			check(res, prefix .. "_shown", h.visible(button), true)
			check(res, prefix .. "_active", button.Active, enabled)
			check(res, prefix .. "_hover", button.AutoButtonColor, enabled)
			local label = text(button)
			check(res, prefix .. "_label", containsText(label, "gift"), true)
			if not enabled then
				-- A reason must be visible, not only in an internal attribute.
				check(res, prefix .. "_reason", containsText(text(button.Parent), reason), true)
			end
			local count = 0
			for _, child in button.Parent:GetDescendants() do
				if child.Name == "Gift" and child:IsA("GuiButton") then
					count += 1
				end
			end
			check(res, prefix .. "_one_control", count, 1)
		end
		for _, pass in Monetization.Gamepasses do
			gift("Gamepasses", pass.Id, false, Spec.Gifts.Reasons.Account)
		end
		for _, product in Monetization.Products do
			local eligible = product.Section == "Potions" or product.Section == "Bundle"
			local enabled = eligible and (product.ProductId or 0) > 0 and (product.GiftProductId or 0) > 0
			local section = product.Section == "Bundle" and "Potions" or product.Section
			gift(
				section,
				product.Section == "Bundle" and "Bundle" or product.Id,
				enabled,
				eligible and Spec.Gifts.Reasons.Unavailable or Spec.Gifts.Reasons.Server
			)
		end
		restore()
	end

	function scenarios.ui_cosmetic_art(res)
		modulePresent(res, "MarketArt")
		local seen, count = {}, 0
		for _, kind in { "Trail", "Aura" } do
			for _, item in Market.Items[kind] do
				count += 1
				check(res, "cosmetic_icon_metadata_" .. item.Id, type(item.Icon) == "string" and item.Icon ~= "", true)
				if type(item.Icon) == "string" then
					check(res, "cosmetic_distinct_icon_" .. item.Id, seen[item.Icon] == nil, true)
					seen[item.Icon] = true
				end
			end
		end
		-- 5 trails + 3 auras (owner 2026-10-27, "Aura and trail ladders"; icons in Shared/MarketArtConfig)
		check(res, "cosmetic_eight_authored_icons", count, 8)
	end

	function scenarios.ui_daily_cards(res)
		local restore = h.setPanels({})
		h.switch.Action("Daily")
		h.frames(2)
		local area = required(res, Spec.DailyBoosts.Content .. "/RewardCards", "Frame")
		if not area then
			restore()
			return
		end
		local cards, total = {}, 0
		local streak = math.clamp(h.player:GetAttribute("DailyStreak") or 0, 0, #Daily.Rewards)
		for _, child in area:GetChildren() do
			if child:IsA("Frame") then
				total += 1
			end
		end
		check(res, "daily_exactly_seven_cards", total, 7)
		for day, reward in Daily.Rewards do
			local card = required(res, h.pathOf(area) .. "/Day" .. day, "Frame")
			if card then
				cards[day] = card
				local prefix = "daily_card_" .. day
				local icon = required(res, h.pathOf(card) .. "/RewardIcon", "ImageLabel")
				if icon then
					check(res, prefix .. "_art", icon.Image ~= "", true)
					check(res, prefix .. "_completed_art_dimmed", icon.ImageTransparency > 0, day <= streak)
				end
				local rewardText = reward.GuaranteedRare and "GUARANTEED RARE"
					or string.format("x%d %s POTION", reward.BoostCount or 1, string.upper(reward.Boost))
				check(res, prefix .. "_reward", text(card:FindFirstChild("RewardText")), rewardText)
				local completion = card:FindFirstChild("Completion")
				check(
					res,
					prefix .. "_completed_mark",
					text(completion),
					day <= streak and Spec.DailyBoosts.DoneMark or ""
				)
			end
		end
		if #cards == 7 then
			-- Judge the actual branch, not the shape copied from the implementation in a simulated viewport.
			local phone = workspace.CurrentCamera.ViewportSize.Y <= Spec.DailyBoosts.PhoneMaxHeight
			check(res, "daily_live_first_row", sameLine(cards[1], cards[2]), true)
			check(res, "daily_live_columns", sameLine(cards[1], cards[3]), not phone)
			if phone then
				check(
					res,
					"daily_phone_day7_below_grid",
					cards[7].AbsolutePosition.Y
						>= cards[6].AbsolutePosition.Y + cards[6].AbsoluteSize.Y - Spec.Tolerance,
					true
				)
			else
				check(
					res,
					"daily_desktop_featured_beside_grid",
					cards[7].AbsolutePosition.X
						>= cards[3].AbsolutePosition.X + cards[3].AbsoluteSize.X - Spec.Tolerance,
					true
				)
				check(res, "daily_desktop_featured_larger", cards[7].AbsoluteSize.Y > cards[1].AbsoluteSize.Y, true)
			end
			h.geometry.Group(res, "daily_cards", area, cards)
		end
		local countdown = required(res, Spec.DailyBoosts.Content .. "/NextReward", "TextLabel")
		check(res, "daily_countdown_drawn", countdown ~= nil and h.visible(countdown) and countdown.Text ~= "", true)
		restore()
	end

	---------------------------------------------------------------------------------------------------------------
	-- Backpack Cars tab (docs/HUD_LAYOUT_SPEC.md section 3, owner 2026-10-20) and car model icons
	-- (docs/CAR_EXPANSION_SPEC.md "Car icons and model detail"). Live engine rects only: the rail's runtime UIScale
	-- is not in the layout model, so ui-tester runs ui_backpack_cars at desktop AND phone landscape (UiSpec.Backpack).
	local B = Spec.Backpack
	local BLACK = Color3.new(0, 0, 0)
	local function rstr(r)
		return ("(%d,%d %dx%d)"):format(r.x, r.y, r.w, r.h)
	end
	local function inside(outer, r)
		local t = Spec.Tolerance
		return r.x >= outer.x - t
			and r.y >= outer.y - t
			and r.x + r.w <= outer.x + outer.w + t
			and r.y + r.h <= outer.y + outer.h + t
	end
	local function overlap(a, b)
		local t = Spec.Tolerance
		return math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x) > t
			and math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y) > t
	end
	local function waitFor(seconds, fn)
		local deadline = os.clock() + seconds
		local ok, value = fn()
		while not ok and os.clock() < deadline do
			task.wait(0.1)
			ok, value = fn()
		end
		return ok, value
	end
	-- The tile art holds that character's placeholder runner rig (docs/WORLD_REDESIGN_SPEC.md section 2,
	-- owner 2026-10-29: RunnerFactory.build(id) in the ViewportFrame): a Model with Head,
	-- Torso, 2 *Arm* and 2 *Leg* parts, attribute CharacterId = id (test seam), and nothing car-shaped.
	-- docs/CHARACTER_GACHA_SPEC.md "Digital art portrait": a registered card shows an ImageLabel of its image instead.
	local function portraitOf(spec)
		return Portraits[spec.Id] or Portraits[spec.Model or spec.Id]
	end
	local function hasRunner(art, id)
		for _, model in art and art:GetChildren() or {} do
			if model:IsA("Model") and model:GetAttribute("CharacterId") == id then
				local arms, legs, car = 0, 0, 0
				for _, d in model:GetDescendants() do
					if d:IsA("VehicleSeat") or d:IsA("Seat") then
						car += 1
					elseif d:IsA("BasePart") then
						local lower = string.lower(d.Name)
						if string.find(lower, "wheel", 1, true) then
							car += 1
						elseif string.find(d.Name, "Arm", 1, true) then
							arms += 1
						elseif string.find(d.Name, "Leg", 1, true) then
							legs += 1
						end
					end
				end
				local head, torso = model:FindFirstChild("Head", true), model:FindFirstChild("Torso", true)
				if head and head:IsA("BasePart") and torso and torso:IsA("BasePart") and arms == 2 and legs == 2 then
					return car == 0
				end
			end
		end
		return false
	end
	-- What is wrong with a card's Art for `spec`: its portrait (ImageLabel, the card's top 3/4), or with none its rig.
	local function cardArtProblem(art, spec)
		local image = portraitOf(spec)
		if image then
			if not (art and art:IsA("ImageLabel") and art.Image == image) then
				return ("Art is %s, want ImageLabel of %s"):format(art and art.ClassName or "missing", image)
			end
			if art.Size ~= UDim2.fromScale(1, 0.75) then
				return "portrait size " .. tostring(art.Size) .. ", want fromScale(1, 0.75)"
			end
			return nil
		end
		if not (art and art:IsA("ViewportFrame") and hasRunner(art, spec.Id)) then
			return "Art is "
				.. (art and art.ClassName or "missing")
				.. (hasRunner(art, spec.Id) and "" or ", no runner rig of this character")
		end
		return nil
	end
	local function rank(rarity)
		return table.find(B.RarityOrder, rarity) or math.huge
	end
	-- Owned cars, least rare first, then catalog Order: the spec's order. Index cars are owned through
	-- LocalPlayer.GachaData; gamepass cars through the attribute Pass_<carId> and sort by their catalog rarity
	-- (docs/HUD_LAYOUT_SPEC.md section 3, docs/GAMEPASS_CARS_SPEC.md "the Backpack Cars tab lists owned gamepass cars").
	local function ownedInOrder()
		local data = h.player:FindFirstChild("GachaData")
		local list = {}
		for _, car in Catalog.All() do
			if data and data:FindFirstChild(car.Id) then
				table.insert(list, car)
			end
		end
		for _, car in Catalog.Passes() do
			if h.player:GetAttribute("Pass_" .. car.Id) == true then
				table.insert(list, car)
			end
		end
		table.sort(list, function(a, b)
			if rank(a.Rarity) ~= rank(b.Rarity) then
				return rank(a.Rarity) < rank(b.Rarity)
			end
			return a.Order < b.Order
		end)
		return list
	end
	local function decimals(textValue)
		local fraction = string.match(textValue, "%.(%d+)")
		return fraction and #fraction or 0
	end
	local function tileStroke(tile)
		for _, child in tile:GetChildren() do
			if child:IsA("UIStroke") then
				return child
			end
		end
		return nil
	end

	-- Problems of the Backpack grid as the Cars view, per check name (empty lists = all good)
	local function carsGridProblems()
		local p = {
			backpack_characters_owned_only = {},
			backpack_characters_order = {},
			backpack_characters_runner_art = {},
			backpack_characters_name = {},
			backpack_characters_multi = {},
			backpack_characters_multi_no_float_noise = {},
			backpack_characters_equipped_green = {},
			backpack_characters_empty_label = {},
			backpack_characters_no_team_slots = {},
		}
		local grid = h.find(B.Items)
		if not grid then
			table.insert(p.backpack_characters_owned_only, B.Items .. " missing")
			return p
		end
		local want = ownedInOrder()
		local wanted = {}
		for _, car in want do
			wanted[car.Id] = true
		end
		local tiles = {}
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				table.insert(tiles, child)
				if not wanted[child.Name] then
					table.insert(p.backpack_characters_owned_only, child.Name .. ": shown but not an owned car")
				end
			end
		end
		local shownIds = {}
		for _, tile in tiles do
			shownIds[tile.Name] = true
		end
		for _, car in want do
			if not shownIds[car.Id] then
				table.insert(p.backpack_characters_owned_only, car.Id .. ": owned but no tile")
			end
		end
		-- Order: LayoutOrder sequence and the reading order on screen both equal the spec order
		local byLayout, byScreen = table.clone(tiles), table.clone(tiles)
		table.sort(byLayout, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		table.sort(byScreen, function(a, b)
			local ay, by = a.AbsolutePosition.Y, b.AbsolutePosition.Y
			if math.abs(ay - by) > Spec.Tolerance then
				return ay < by
			end
			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end)
		local wantIds, layoutIds, screenIds = {}, {}, {}
		for i, car in want do
			wantIds[i] = car.Id
		end
		for i, tile in byLayout do
			layoutIds[i] = tile.Name
		end
		for i, tile in byScreen do
			screenIds[i] = tile.Name
		end
		local wantText = table.concat(wantIds, ",")
		if table.concat(layoutIds, ",") ~= wantText then
			table.insert(
				p.backpack_characters_order,
				"LayoutOrder " .. table.concat(layoutIds, ",") .. " want " .. wantText
			)
		end
		if table.concat(screenIds, ",") ~= wantText then
			table.insert(p.backpack_characters_order, "screen " .. table.concat(screenIds, ",") .. " want " .. wantText)
		end
		-- Team members (c1: Team of 3, Client/SlotPicker.Equipped) have a green border; the picked tile's is white
		local team = string.split(h.player:GetAttribute("Team") or "", ",")
		local picked = 0
		for _, tile in tiles do
			local car = Catalog.Get(tile.Name)
			if not car then
				continue
			end
			local art = tile:FindFirstChild("Art")
			local artProblem = cardArtProblem(art, car)
			if artProblem then
				table.insert(p.backpack_characters_runner_art, tile.Name .. ": " .. artProblem)
			elseif portraitOf(car) and art.ImageColor3 ~= Color3.new(1, 1, 1) then
				table.insert(p.backpack_characters_runner_art, tile.Name .. ": portrait not white")
			end
			local name = tile:FindFirstChild("Name")
			if not (name and name:IsA("TextLabel") and name.Text == car.Name) then
				table.insert(p.backpack_characters_name, tile.Name .. ": " .. text(name) .. " want " .. car.Name)
			end
			local multi = tile:FindFirstChild("Multi")
			-- The tile shows the character's cruise, fixed by rarity x category (design doc 4.13; was Multi(SpeedMulti))
			local wantMulti = Format.RateText(RaceConfig.Cruise(car))
			local got = multi and multi:IsA("TextLabel") and multi.Text or "missing"
			if got ~= wantMulti then
				table.insert(p.backpack_characters_multi, tile.Name .. ": " .. got .. " want " .. wantMulti)
			end
			if decimals(got) > B.MaxDecimals then
				table.insert(p.backpack_characters_multi_no_float_noise, tile.Name .. ": " .. got)
			end
			local stroke = tileStroke(tile)
			local green = stroke ~= nil and B.Green(stroke.Color)
			local inTeam = table.find(team, tile.Name) ~= nil
			if stroke and stroke.Color == Color3.new(1, 1, 1) then
				picked += 1
			elseif inTeam ~= green then
				table.insert(
					p.backpack_characters_equipped_green,
					tile.Name
						.. (inTeam and ": in the Team but border not green" or ": not in the Team but border green")
				)
			end
		end
		if picked > 1 then
			table.insert(p.backpack_characters_equipped_green, picked .. " tiles drawn as picked (white), want <= 1")
		end
		-- Owner 2026-11-12 (design doc 4.40, TEAM_AND_STAMINA_SPEC "HUD" Team editor): the team slot buttons left the
		-- Characters tab for the Team panel (UiTeam judges them there); the TEAM badge and green border stay above.
		local slotsFrame = h.find(B.Slots)
		if slotsFrame and h.visible(slotsFrame) then
			table.insert(p.backpack_characters_no_team_slots, B.Slots .. " shown in the Characters view")
		end
		local empty = h.find(B.Empty)
		local emptyShown = empty ~= nil and h.visible(empty)
		if emptyShown ~= (#want == 0) then
			table.insert(
				p.backpack_characters_empty_label,
				("Empty shown=%s with %d owned cars"):format(tostring(emptyShown), #want)
			)
		end
		return p
	end
	local function carsGridChecks(res)
		local _, problems = waitFor(B.ModelWait, function()
			local p = carsGridProblems()
			for _, list in p do
				if #list > 0 then
					return false, p
				end
			end
			return true, p
		end)
		local names = {}
		for name in problems do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			h.checkList(res, name, problems[name])
		end
	end

	-- Design doc 4.21: the popup offers exactly the 3 starters and opens only for a player who has to pick.
	-- Structure only: a pick would spend the save's one choice (CarTest Phase2Tests covers the server).
	function scenarios.ui_starter_pick(res)
		local gui = required(res, "StarterPick", "ScreenGui")
		local cards = required(res, "StarterPick/Dim/Panel/Cards", "Frame")
		if not (gui and cards) then
			return
		end
		local needs = h.player:GetAttribute("NeedsStarter") == true
		local revealed = h.player:GetAttribute("ArrivalRevealDone") == true
		check(res, "starter_popup_only_when_needed", gui.Enabled, needs and revealed)
		for _, id in Catalog.STARTER_PICKS do
			local card = cards:FindFirstChild(id)
			local name = card and card:FindFirstChild("CharacterName")
			local choose = card and card:FindFirstChild("Choose")
			check(res, "starter_name_" .. id, name and name.Text, Catalog.Get(id).Name)
			check(res, "starter_choose_" .. id, choose and choose:IsA("GuiButton"), true)
		end
		check(res, "starter_card_count", #cards:GetChildren() - 1, #Catalog.STARTER_PICKS)
	end

	function scenarios.ui_backpack_characters(res)
		local restore = h.setPanels({ B.Panel })
		h.frames(2)
		local panel = required(res, B.Panel, "Frame")
		local rail = required(res, B.Tabs, "Frame")
		local grid = required(res, B.Items, "ScrollingFrame")
		if not (panel and rail and grid) then
			restore()
			return
		end
		-- UI audit A13: opens on Characters, marked by a white tab edge. The session keeps the last tab, so this holds on a
		-- run with no tab clicked before it, or after the backpack_* clicks (Characters is their last).
		local charactersTab = h.find(B.CharactersTab)
		local tabEdge = charactersTab and charactersTab:FindFirstChildOfClass("UIStroke")
		check(res, "backpack_opens_on_characters", tabEdge ~= nil and tabEdge.Color == Color3.new(1, 1, 1), true)
		-- Exactly the tabs of B.TabOrder, top to bottom in the spec's order, each labelled with its name
		local buttons = {}
		for _, child in rail:GetChildren() do
			if child:IsA("GuiButton") then
				table.insert(buttons, child.Name)
			end
		end
		table.sort(buttons)
		local wantButtons = {}
		for i, name in B.TabOrder do
			wantButtons[i] = name .. "Tab"
		end
		table.sort(wantButtons)
		check(res, "backpack_tabs_exactly", table.concat(buttons, ","), table.concat(wantButtons, ","))
		local tabs = {}
		for _, name in B.TabOrder do
			local tab = required(res, B.Tabs .. "/" .. name .. "Tab", "TextButton")
			if tab then
				check(res, "backpack_tab_label_" .. name, text(tab), name)
				check(res, "backpack_tab_shown_" .. name, h.visible(tab), true)
				table.insert(tabs, tab)
			end
		end
		local variant = workspace.CurrentCamera.ViewportSize.Y <= B.PhoneMaxHeight and "_phone" or "_desktop"
		if #tabs == #B.TabOrder then
			local order = {}
			for i = 2, #tabs do
				local a, b = h.realRect(tabs[i - 1]), h.realRect(tabs[i])
				if b.y < a.y + a.h - Spec.Tolerance then
					table.insert(order, tabs[i].Name .. " not below " .. tabs[i - 1].Name)
				end
			end
			h.checkList(res, "backpack_tabs_top_to_bottom" .. variant, order)
		end
		-- Live geometry: every tab inside the rail and the panel, apart from each other and from the Items grid,
		-- and the topmost clickable object at its own centre
		local railRect, panelRect, gridRect = h.realRect(rail), h.realRect(panel), h.realRect(grid)
		local outside, overlaps, covered = {}, {}, {}
		for i, tab in tabs do
			local r = h.realRect(tab)
			if not inside(railRect, r) then
				table.insert(outside, tab.Name .. rstr(r) .. " outside Tabs" .. rstr(railRect))
			end
			if not inside(panelRect, r) then
				table.insert(outside, tab.Name .. rstr(r) .. " outside Panel" .. rstr(panelRect))
			end
			if overlap(r, gridRect) then
				table.insert(overlaps, tab.Name .. rstr(r) .. " x Items" .. rstr(gridRect))
			end
			for j = i + 1, #tabs do
				local other = h.realRect(tabs[j])
				if overlap(r, other) then
					table.insert(overlaps, tab.Name .. rstr(r) .. " x " .. tabs[j].Name .. rstr(other))
				end
			end
			local top = h.topAt(r.x + r.w / 2, r.y + r.h / 2)
			if not (top and (top == tab or tab:IsAncestorOf(top))) then
				table.insert(covered, tab.Name .. " under " .. (top and h.pathOf(top) or "nothing"))
			end
		end
		h.checkList(res, "backpack_tabs_inside_rail" .. variant, outside)
		h.checkList(res, "backpack_tabs_no_overlap" .. variant, overlaps)
		h.checkList(res, "backpack_tabs_topmost" .. variant, covered)
		-- The Characters view itself is judged after the backpack_characters click (After backpack_characters_grid); when the grid
		-- already shows cars (an earlier click) it is judged here too.
		local showsCars = false
		for _, child in grid:GetChildren() do
			showsCars = showsCars or (child:IsA("GuiButton") and Catalog.Get(child.Name) ~= nil)
		end
		if showsCars then
			carsGridChecks(res)
		end
		restore()
	end

	-- Every Index gallery tile shows its character's runner rig (ViewportFrame Art, never the atlas);
	-- an undiscovered car is a black silhouette, a discovered one is not.
	function scenarios.ui_character_icons(res)
		local restore = h.setPanels({ "RacerIndex/Panel" })
		h.frames(2)
		-- catalog_cars_have_model_template retired: the CarModels folder is scrapped (docs/WORLD_REDESIGN_SPEC.md
		-- section 1); the tile art shows the character's placeholder runner rig instead (docs/WORLD_REDESIGN_SPEC.md
		-- section 2, owner 2026-10-29), checked by index_tiles_runner_art below.
		local function problems()
			local p = { index_tiles_runner_art = {}, index_silhouette_state = {} }
			local data = h.player:FindFirstChild("GachaData")
			for _, car in Catalog.All() do
				local tile = h.find(B.IndexGallery .. "/" .. car.Id)
				local art = tile and tile:FindFirstChild("Art")
				local artProblem = cardArtProblem(art, car)
				if artProblem then
					table.insert(p.index_tiles_runner_art, car.Id .. ": " .. artProblem)
				end
				if art and (art:IsA("ViewportFrame") or art:IsA("ImageLabel")) then
					local owned = data ~= nil and data:FindFirstChild(car.Id) ~= nil
					if (art.ImageColor3 == BLACK) == owned then
						table.insert(
							p.index_silhouette_state,
							car.Id .. (owned and ": discovered but black" or ": undiscovered but not black")
						)
					elseif owned and art:IsA("ImageLabel") and art.ImageColor3 ~= Color3.new(1, 1, 1) then
						table.insert(p.index_silhouette_state, car.Id .. ": discovered portrait not white")
					end
				end
			end
			return p
		end
		local _, p = waitFor(B.ModelWait, function()
			local now = problems()
			return #now.index_tiles_runner_art == 0 and #now.index_silhouette_state == 0, now
		end)
		h.checkList(res, "index_tiles_runner_art", p.index_tiles_runner_art)
		h.checkList(res, "index_silhouette_state", p.index_silhouette_state)
		restore()
	end

	-- Click post-conditions (UiSpec.Clicks Expect.After)
	function after.backpack_characters_grid(res)
		carsGridChecks(res)
	end
	-- retired: backpack_tile_shows_equipped (a Backpack tile no longer equips; the Team panel's slots do, UiTeam)
	-- moved: backpack_characters_slots (the Slot<n> names of Team[n]) is UiTeam team_slots_* (owner 2026-11-12, 4.40)

	return { Scenarios = scenarios, After = after }
end

return Contracts
