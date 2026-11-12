--!nonstrict
-- Test-first progression UI contract. No gameplay calls; state comes from the server.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tree = require(Shared.UpgradeTree)
local Tracks = require(Shared.TrackRegistry)
local Format = require(Shared.HudFormat)
local WeatherConfig = require(Shared.WeatherConfig)
local Spec = require(script.Parent.UiSpec)
local Responsive = require(script.Parent.UiResponsive)
local Progression = {}

function Progression.Build(h)
	local scenarios = {}
	local function expect(res, name, actual, wanted)
		h.check(res, name, actual, wanted, actual == wanted)
	end
	local function state()
		local owned = {}
		local data = h.player:FindFirstChild("Upgrades")
		if data then
			for _, tile in data:GetChildren() do
				owned[tile.Name] = true
			end
		end
		local stats = h.player:FindFirstChild("leaderstats")
		return {
			Owned = owned,
			Money = stats and stats.Money.Value or 0,
			BestTrack = h.player:GetAttribute("BestTrack") or 0,
			TrackCount = #Tracks.Chain(),
		}
	end
	function scenarios.ui_upgrades(res)
		local canvas = h.find(Spec.Progression.Canvas)
		local world = h.find(Spec.Progression.TreeWorld)
		local truth = state()
		local count = h.player:GetAttribute("UpgradesBuyable")
		expect(res, "buyable_count_matches_tree", count, Tree.BuyableCount(truth))
		local badge = h.find("RacerProgression/UpgradeButton/Badge")
		h.check(res, "upgrade_badge_present", badge ~= nil, true, badge ~= nil)
		if badge then
			expect(res, "upgrade_badge_visible_with_buyable", badge.Visible, type(count) == "number" and count > 0)
			if type(count) == "number" and count > 0 then
				expect(res, "upgrade_badge_server_count", h.text(badge), tostring(count))
			end
		end
		for _, tile in Tree.Tiles() do
			local button = world and world:FindFirstChild(tile.Id)
			h.check(
				res,
				"tile_present_" .. tile.Id,
				button and button.ClassName or "missing",
				"GuiButton",
				button ~= nil and button:IsA("GuiButton")
			)
			if button and button:IsA("GuiButton") then
				local canBuy, reason = Tree.CanBuy(truth, tile.Id)
				expect(res, "tile_enabled_" .. tile.Id, button.Active, canBuy)
				expect(res, "tile_width_" .. tile.Id, button.Size.X.Offset, Spec.Progression.TileSize.X)
				expect(res, "tile_height_" .. tile.Id, button.Size.Y.Offset, Spec.Progression.TileSize.Y)
				local text = h.text(button)
				local wanted = reason == "owned" and "OWNED"
					or reason == "locked" and "?"
					or reason == "gated" and ("Reach Track " .. Tree.RequiredTrack(tile.Id, truth.TrackCount))
					or Format.MoneyText(Tree.Price(tile.Id))
				h.check(res, "tile_truth_" .. tile.Id, text, wanted, string.find(text, wanted, 1, true) ~= nil)
				-- UPGRADE_TREE_SPEC section 5: a buyable price is green if affordable, red if not
				local price = button:FindFirstChild("Price", true)
				if canBuy or reason == "money" then
					local c = price and price:IsA("TextLabel") and price.TextColor3
					local green = Spec.Progression.AffordableColour
					h.check(
						res,
						"tile_price_colour_" .. tile.Id,
						c and tostring(c) or "no Price label",
						canBuy and tostring(green) or "red (R > G and R > B)",
						c ~= nil
							and (
								canBuy
									and math.abs(c.R - green.R) + math.abs(c.G - green.G) + math.abs(c.B - green.B) <= 0.02
								or not canBuy and c.R > c.G and c.R > c.B
							)
					)
				end
				local angled = 0
				for _, part in button:GetDescendants() do
					if part:IsA("Frame") and part.BackgroundTransparency < 1 and math.abs(part.Rotation) % 90 > 1 then
						angled += 1
					end
				end
				h.check(res, "tile_hex_geometry_" .. tile.Id, angled, ">=2 slanted visible polygon parts", angled >= 2)
			end
		end
		local restore = h.setPanels({ "RacerUpgrades/Panel" })
		h.frames(2)
		-- UI audit A30, one way out: EXIT stays hidden with the tree open, X is drawn (click close_upgrades presses it).
		local exitButton = h.find("RacerUpgrades/ZoomTools/Exit")
		local exitShown = exitButton ~= nil and h.visible(exitButton)
		h.check(res, "upgrades_exit_hidden", exitShown, false, not exitShown)
		local closeButton = h.find("RacerUpgrades/Close/Face")
		local closeShown = closeButton ~= nil and h.visible(closeButton)
		h.check(res, "upgrades_close_shown", closeShown, true, closeShown)
		-- The hex tree pans by drag / wheel (UpgradeTreeView sets CanvasPosition itself; native scrolling is off), so
		-- the canvas must be a clipping ScrollingFrame whose canvas spans the whole zoomed TreeWorld (measured with
		-- the tree open): every tile can be panned into the window (tile_pan_reachable_* / tile_pan_hit_* prove it).
		local spans = canvas ~= nil
			and world ~= nil
			and canvas:IsA("ScrollingFrame")
			and canvas.ClipsDescendants
			and world.AbsoluteSize.X > 0
			and canvas.CanvasSize.X.Offset + Spec.Tolerance >= world.AbsoluteSize.X
			and canvas.CanvasSize.Y.Offset + Spec.Tolerance >= world.AbsoluteSize.Y
		h.check(
			res,
			"upgrade_canvas_scrolls",
			canvas
					and world
					and ("%s canvas %s world %s"):format(
						canvas.ClassName,
						tostring(canvas:IsA("ScrollingFrame") and canvas.CanvasSize or "-"),
						tostring(world.AbsoluteSize)
					)
				or "missing",
			"clipping ScrollingFrame, CanvasSize >= TreeWorld size",
			spans
		)
		if canvas and canvas:IsA("ScrollingFrame") then
			local original = canvas.CanvasPosition
			for _, tile in Tree.Tiles() do
				local b = world and world:FindFirstChild(tile.Id)
				if b and b:IsA("GuiButton") then
					-- Pan the tile to the middle of the window (clear of the chrome along the screen edges)
					local position = b.AbsolutePosition - canvas.AbsolutePosition + canvas.CanvasPosition
					local target = position + b.AbsoluteSize / 2 - canvas.AbsoluteSize / 2
					canvas.CanvasPosition = Vector2.new(math.max(0, target.X), math.max(0, target.Y))
					h.frames(2)
					local br, cr = h.rect(b), h.rect(canvas)
					h.check(
						res,
						"tile_pan_reachable_" .. tile.Id,
						{ br, cr },
						"whole tile inside scrolled window",
						h.contains(cr, br)
					)
					local top = h.top(h.centre(br))
					h.check(
						res,
						"tile_pan_hit_" .. tile.Id,
						top and top.Name or "nothing",
						tile.Id,
						top ~= nil and (top == b or b:IsAncestorOf(top))
					)
				end
			end
			canvas.CanvasPosition = original
		end
		restore()
		-- Owner 2026-10-13: the spawn-area upgrade pad is removed; the tree opens only from the HUD Upgrade button
		-- (clicks open_upgrades / close_upgrades). The Dojo plots and their UpgradePads are gone too (design doc 4.43).
		local worldPads = 0
		for _, pad in CollectionService:GetTagged("UpgradePad") do
			if pad:IsDescendantOf(workspace) then
				worldPads += 1
			end
		end
		expect(res, "upgrade_no_world_pad", worldPads, 0)
		local spawnArea = workspace:FindFirstChild("SpawnArea")
		local spawnPad = spawnArea and spawnArea:FindFirstChild("UpgradePad", true)
		expect(res, "upgrade_no_spawn_area_pad", spawnPad and spawnPad:GetFullName() or "none", "none")
	end
	-- retired: ui_workshop_modal (Dojos removed, design doc 4.43, owner 2026-11-11)
	function scenarios.ui_progression_layout(res)
		for _, vpSpec in Spec.Viewports do
			local rect, vp = h.provider(vpSpec)
			for _, name in { "Upgrades" } do
				local panel = h.find("Racer" .. name .. "/Panel")
				local race, turbo = h.find(Spec.Band.Race), h.find(Spec.Hud.Turbo)
				local lower = string.lower(name) .. "_" .. vpSpec.Name
				if Spec.FullScreenPanels["Racer" .. name .. "/Panel"] then
					-- Owner 2026-10-26 (HUD_LAYOUT_SPEC sections 1 and 6): a full-screen overlay, exempt from the band
					for _, rule in { "panel_in_band_top_", "panel_below_race_", "panel_above_turbo_" } do
						h.check(res, rule .. lower, "exempt", "exempt (full-screen overlay)", true)
					end
				end
				if Spec.FullScreenPanels["Racer" .. name .. "/Panel"] and panel then
					local p = rect(panel)
					h.check(
						res,
						"panel_positive_size_" .. lower,
						{ p.w, p.h },
						"positive viewport-contained area",
						p.w > 0 and p.h > 0 and p.x >= 0 and p.x + p.w <= vp.X and p.y + p.h <= vp.Y
					)
				elseif panel and race and turbo then
					local p, a, t = rect(panel), rect(race), rect(turbo)
					-- Owner 2026-10-28 (HUD_LAYOUT_SPEC section 6): the compact roll HIDES while a panel is open, so
					-- the panel no longer has to clear it (ui_toast checks the hiding). The panel opens in the
					-- PanelBand (Client/PanelBand.Rect, design doc 4.42 "Panel size"): top ReachUp above the hidden Race
					-- anchor's bottom + Band.Gap, never above inset + Band.Gap; bottom ReachDown above the TURBO bar.
					local bandTop = math.max(
						GuiService:GetGuiInset().Y + Spec.Band.Gap,
						a.y + a.h + Spec.Band.Gap - Spec.Band.ReachUp
					)
					local bandBottom = t.y - Spec.Band.ReachDown
					h.check(
						res,
						"panel_in_band_top_" .. string.lower(name) .. "_" .. vpSpec.Name,
						p.y,
						">= " .. bandTop,
						p.y >= bandTop - Spec.Tolerance
					)
					h.check(
						res,
						"panel_below_race_" .. string.lower(name) .. "_" .. vpSpec.Name,
						p.y,
						">= " .. bandTop,
						p.y >= bandTop - Spec.Tolerance
					)
					h.check(
						res,
						"panel_above_turbo_" .. string.lower(name) .. "_" .. vpSpec.Name,
						p.y + p.h,
						"<= " .. bandBottom,
						p.y + p.h <= bandBottom + Spec.Tolerance
					)
					h.check(
						res,
						"panel_positive_size_" .. string.lower(name) .. "_" .. vpSpec.Name,
						{ p.w, p.h },
						"positive viewport-contained area",
						p.w > 0 and p.h > 0 and p.x >= 0 and p.x + p.w <= vp.X and p.y + p.h <= vp.Y
					)
				else
					expect(res, "panel_layout_dependencies_" .. string.lower(name) .. "_" .. vpSpec.Name, false, true)
				end
			end
		end
	end
	function scenarios.ui_progression_hud(res)
		-- retired: the workshop stat boost label checks (Dojos removed, design doc 4.43, owner 2026-11-11)
		local button = h.find("RacerProgression/UpgradeButton")
		if button then
			expect(res, "upgrade_button_width", button.Size.X.Offset, 110)
			expect(res, "upgrade_button_height", button.Size.Y.Offset, 40)
			-- UDim scales are float32 (0.22 reads back as 0.2199999988): compare within 1e-4, not exactly
			local top = button.Position.Y.Scale
			h.check(res, "upgrade_button_top", top, 0.22, math.abs(top - 0.22) <= 1e-4)
			expect(res, "upgrade_button_right", button.Position.X.Offset, -16)
		else
			expect(res, "upgrade_button_present", false, true)
		end
	end
	-- retired: ui_workshop_showcase, the Workshop Showcase helpers and the showcase_* click conditions (Dojos removed,
	-- design doc 4.43, owner 2026-11-11)
	-- retired: ui_offline_welcome and ui_offline_double (no offline credit, no Robux double: design doc 4.19, owner 2026-11-03)
	-- Weather icon (UiSpec.Weather; docs/WEATHER_EVENTS_SPEC.md "Weather icon"). The weather the UI must show now:
	-- the replicated id, its WeatherConfig entry (the Clear entry when no weather is active) and whether one runs.
	local W = Spec.Weather
	local function weatherNow()
		local event = ReplicatedStorage:GetAttribute("WeatherEvent")
		local endsAt = ReplicatedStorage:GetAttribute("WeatherEndsAt")
		local active = type(event) == "string" and event ~= ""
		return event, endsAt, active, WeatherConfig.Events[active and event or W.ClearId]
	end
	-- The Card's three labels against the server's weather (the Card may be hidden: labels are kept current).
	local function weatherCardContent(res)
		local _, endsAt, active, config = weatherNow()
		local texts = {}
		for _, name in W.Labels do
			local obj = h.find(W.Card .. "/" .. name)
			h.check(
				res,
				"weather_card_label_" .. string.lower(name),
				obj and obj.ClassName or "missing",
				"TextLabel",
				obj ~= nil and obj:IsA("TextLabel")
			)
			texts[name] = obj and obj:IsA("TextLabel") and obj.Text or "missing"
		end
		expect(res, "weather_card_title", texts.Title, active and config and config.Name or W.ClearTitle)
		local parts = {}
		for _, part in W.StatParts do
			local multi = config and config[part.Key]
			if type(multi) == "number" and multi ~= 1 then
				table.insert(parts, part.Text .. tostring(multi))
			end
		end
		expect(res, "weather_card_stats", texts.Stats, #parts > 0 and table.concat(parts, W.Separator) or W.NoBonus)
		if active and type(endsAt) == "number" then
			local shown = tonumber(string.match(texts.Time, W.TimeText))
			local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			h.check(
				res,
				"weather_card_time_server_countdown",
				shown or texts.Time,
				remaining,
				shown ~= nil and math.abs(shown - remaining) <= W.TimeTolerance
			)
		else
			expect(res, "weather_card_time_empty_without_weather", texts.Time, "")
		end
	end
	-- Waits (ProgressionUi polls its visibility) until the icon's shown state is `want`, then returns the state.
	local function iconShown(want)
		local deadline = os.clock() + Spec.HiddenWhilePanelOpenWait
		local icon = h.find(W.Icon)
		while icon and h.visible(icon) ~= want and os.clock() < deadline do
			h.frames(1)
		end
		return icon ~= nil and h.visible(icon)
	end
	function scenarios.ui_weather(res)
		local event, endsAt, active, config = weatherNow()
		h.check(res, "weather_event_replicated", event or "missing", "string", type(event) == "string")
		h.check(res, "weather_end_replicated", endsAt or "missing", "number", type(endsAt) == "number")
		h.check(
			res,
			"weather_event_in_config",
			event or "missing",
			"'' or a WeatherConfig.Events id",
			event == "" or (active and WeatherConfig.Events[event] ~= nil)
		)
		local banner = h.find(W.Banner)
		h.check(res, "weather_banner_removed", banner and banner.ClassName or "absent", "absent", banner == nil)

		local restore = h.setPanels({})
		local icon, card = h.find(W.Icon), h.find(W.Card)
		h.check(
			res,
			"weather_icon_is_textbutton",
			icon and icon.ClassName or "missing",
			"TextButton",
			icon ~= nil and icon:IsA("TextButton")
		)
		h.check(
			res,
			"weather_card_is_frame",
			card and card.ClassName or "missing",
			"Frame",
			card ~= nil and card:IsA("Frame")
		)
		-- Always on the HUD, with or without a weather
		expect(res, "weather_icon_visible", iconShown(true), true)
		local wantIcon = config and config.Icon
		h.check(
			res,
			"weather_icon_text",
			icon and icon:IsA("TextButton") and icon.Text or "missing",
			wantIcon or "WeatherConfig.Events[id].Icon missing",
			icon ~= nil
				and icon:IsA("TextButton")
				and type(wantIcon) == "string"
				and wantIcon ~= ""
				and icon.Text == wantIcon
		)
		expect(res, "weather_card_hidden_at_rest", card and card.Visible, false)
		weatherCardContent(res)

		-- Geometry at every tested viewport. The live one is also solved ("current_sim"), so the hidden Card's
		-- rect never depends on the engine laying out an invisible Frame.
		local _, liveVp = h.provider({ Name = "current" })
		for _, vpSpec in Spec.Viewports do
			local rect, vp, ctx = h.provider(vpSpec)
			local tag = vpSpec.Name
			if icon and icon:IsA("GuiObject") then
				local r = rect(icon)
				h.check(
					res,
					"weather_icon_size_" .. tag,
					("%gx%g"):format(r.w, r.h),
					("%gx%g"):format(W.IconSize.X, W.IconSize.Y),
					math.abs(r.w - W.IconSize.X) <= Spec.Tolerance and math.abs(r.h - W.IconSize.Y) <= Spec.Tolerance
				)
				local right, bottom = vp.X - (r.x + r.w), vp.Y - (r.y + r.h)
				local bottomOk = bottom >= -Spec.Tolerance and bottom <= W.CornerMargin
				if vp.Y <= Responsive.PHONE_MAX_HEIGHT then
					h.check(
						res,
						"weather_icon_bottom_right_" .. tag,
						("right %g, bottom %g"):format(right, bottom),
						("phone: right edge %d px, bottom edge 0..%d px from the screen's"):format(
							W.PhoneRight,
							W.CornerMargin
						),
						math.abs(right - W.PhoneRight) <= Spec.Tolerance and bottomOk
					)
					-- WEATHER_EVENTS_SPEC's "8 px left of the Market button" assumed the bottom-right Bag / Daily / Market
					-- stack, which HUD_LAYOUT_SPEC (owner 2026-10-15) replaced with the top-right pills: the 140 px rule
					-- above stays; against Market only the no-overlap rule remains.
					local market = h.find(W.MarketButton)
					local m = market and rect(market)
					h.check(
						res,
						"weather_icon_clear_of_market_" .. tag,
						m and h.rstr(m) or "MarketButton missing",
						"no overlap with icon " .. h.rstr(r),
						m ~= nil and not h.intersects(r, m)
					)
				else
					h.check(
						res,
						"weather_icon_bottom_right_" .. tag,
						("right %g, bottom %g"):format(right, bottom),
						"right and bottom edge 0.." .. W.CornerMargin .. " px from the screen's",
						right >= -Spec.Tolerance and right <= W.CornerMargin and bottomOk
					)
				end
			else
				expect(res, "weather_icon_size_" .. tag, "missing", "present")
				expect(res, "weather_icon_bottom_right_" .. tag, "missing", "present")
			end
			if card and card:IsA("GuiObject") then
				if not vpSpec.Size then
					rect, vp, ctx = h.provider({ Name = "current_sim", Size = liveVp })
				end
				local r = rect(card)
				local unsupported = ctx.unsupported[W.Card] or ctx.unsupported[W.Icon]
				h.check(
					res,
					"weather_card_inside_screen_" .. tag,
					unsupported and ("layout the solver can not model: " .. unsupported) or r,
					"whole Card on screen, positive size",
					not unsupported and r.w > 0 and r.h > 0 and h.contains({ x = 0, y = 0, w = vp.X, h = vp.Y }, r)
				)
			else
				expect(res, "weather_card_inside_screen_" .. tag, "missing", "present")
			end
		end
		restore()
		-- WEATHER_EVENTS_SPEC "Displayed odds": a roll during Rain keeps its catalog rarity. Only
		-- with the weather_rain_roll fixture (it plants that roll; checks roll_odds_*, see UiSpec.RollOdds).
		local fixture = h.rollOddsFixture()
		if fixture and fixture.fixture == "weather_rain_roll" then
			expect(res, "weather_rain_roll_event_is_rain", event, "rain")
			h.rollOdds(res)
		end
	end
	-- retired: ui_offline_zero (design doc 4.19, owner 2026-11-03)
	-- Click post-conditions (UiSpec.Clicks Expect.After), run by UiScenarios.RunClick.
	local function cardVisible(res, name, want)
		local card = h.find(W.Card)
		local deadline = os.clock() + Spec.HiddenWhilePanelOpenWait
		while card and h.visible(card) ~= want and os.clock() < deadline do
			h.frames(1)
		end
		h.check(res, name, card and h.visible(card), want, card ~= nil and h.visible(card) == want)
		return card
	end
	Progression.After = {
		-- retired: offline_double_click_result (design doc 4.19, owner 2026-11-03)
		weather_card_shown = function(res)
			local card = cardVisible(res, "weather_card_shown_after_click", true)
			weatherCardContent(res)
			if card then
				local _, vp = h.provider({ Name = "current" })
				local r = h.rect(card)
				h.check(
					res,
					"weather_card_inside_screen_live",
					r,
					"whole Card on screen, positive size",
					r.w > 0 and r.h > 0 and h.contains({ x = 0, y = 0, w = vp.X, h = vp.Y }, r)
				)
			end
		end,
		weather_card_hidden = function(res)
			cardVisible(res, "weather_card_hidden_after_second_click", false)
			expect(res, "weather_icon_still_visible", iconShown(true), true)
		end,
		weather_icon_hidden_while_showcase_open = function(res)
			h.check(res, "weather_icon_present", h.find(W.Icon) ~= nil, true, h.find(W.Icon) ~= nil)
			expect(res, "weather_icon_hidden_while_showcase_open", iconShown(false), false)
		end,
		weather_icon_shown_after_showcase = function(res)
			expect(res, "weather_icon_shown_after_showcase", iconShown(true), true)
		end,
	}
	return scenarios
end

return Progression
