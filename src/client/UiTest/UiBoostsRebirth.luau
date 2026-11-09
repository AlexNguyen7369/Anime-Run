--!nonstrict
-- The Rebirth panel's live parts and the Bag / Daily Rewards gui (Client/BoostDailyUi): what they show against the
-- server's attributes and the config modules. Owned by ui-test-writer. Nothing here invokes a remote; the clicks
-- (UiSpec.Clicks rebirth_*, bag_*, daily_*) only run with the RemoteFunctions intercepted (Prepare.Intercept).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoostConfig = require(Shared:WaitForChild("BoostConfig"))
local HudFormat = require(Shared:WaitForChild("HudFormat"))
local DailyLoginConfig = require(Shared:WaitForChild("DailyLoginConfig"))
local RebirthConfig = require(Shared:WaitForChild("RebirthConfig"))
local Spec = require(script.Parent.UiSpec)
local UiResponsive = require(script.Parent.UiResponsive)

local Extras = {}
local SOLD_TICK_WAIT = 20 -- s: a tick at the slowest roll interval, after an emphasized roll's wait

-- h: check, checkList, find, visible, setPanels, player, pathOf, render, provider, viewports, contains, intersects,
-- rstr (UiScenarios' helpers). Returns { Scenarios, After, Snapshot, BoostToken }.
function Extras.Build(h)
	local RB, DB = Spec.Rebirth, Spec.DailyBoosts
	local scenarios, after = {}, {}

	local function attr(name)
		return h.player:GetAttribute(name)
	end
	local function has(text, piece)
		return string.find(text, piece, 1, true) ~= nil
	end
	local function today()
		return math.floor(os.time() / 86400)
	end

	-- Rebirth -------------------------------------------------------------------------------------------------

	local function colourOk(family, c)
		local test = RB.Colours[family]
		return test ~= nil and test(c)
	end
	local function rgb(c)
		return ("rgb(%d,%d,%d)"):format(
			math.floor(c.R * 255 + 0.5),
			math.floor(c.G * 255 + 0.5),
			math.floor(c.B * 255 + 0.5)
		)
	end

	-- The panel's declared nodes found by name (UiSpec.Rebirth.Nodes). Returns nodes (name -> instance, "Panel" ->
	-- the panel) and the list of problems (missing, duplicated, under the wrong parent, wrong class).
	local function rebirthNodes()
		local panel = h.find(RB.Panel)
		if not panel then
			return nil, { RB.Panel .. " missing" }
		end
		local nodes, bad = { Panel = panel }, {}
		for _, spec in RB.Nodes do
			local found = {}
			for _, d in panel:GetDescendants() do
				if d.Name == spec.Name then
					table.insert(found, d)
				end
			end
			local parent = nodes[spec.Parent]
			if #found ~= 1 then
				table.insert(bad, ("%s: found %d, want exactly 1"):format(spec.Name, #found))
			elseif not (parent and parent:IsAncestorOf(found[1])) then
				table.insert(bad, ("%s: %s is not under %s"):format(spec.Name, h.pathOf(found[1]), spec.Parent))
			elseif not found[1]:IsA(spec.Class) then
				table.insert(bad, ("%s: %s, want %s"):format(spec.Name, found[1].ClassName, spec.Class))
			else
				nodes[spec.Name] = found[1]
			end
		end
		return nodes, bad
	end

	-- A tile's <Tile>Icon and <Tile>Caption (declared in UiSpec.Rebirth.Nodes, so rebirthNodes found them once under
	-- their tile).
	local function tileParts(nodes, tileName)
		return nodes[tileName .. "Icon"], nodes[tileName .. "Caption"]
	end

	local function required()
		return RebirthConfig.Requirements(attr("RebirthLevel") or 0).Money
	end

	-- What the panel shows that follows the server and the config modules: reward captions, the requirement bar and
	-- the RebirthButton's state. Used by ui_rebirth and after the (intercepted) rebirth clicks.
	-- skipLabel: after an intercepted click the label shows the proxy's made-up reply for a while (not the server's).
	local function rebirthTruth(res, nodes, skipLabel)
		nodes = nodes or {}
		-- Reward captions: the NEXT rebirth's gains from RebirthConfig. Multiplier tiles show the NEXT TOTAL multi,
		-- RebirthConfig.NextMultiplier(RebirthLevel) = the luck multi of RebirthLevel + 1 (design doc 4.14).
		local captions = {}
		local rebirthLevel = attr("RebirthLevel") or 0
		for _, tile in RB.Tiles do
			local value = if tile.Multiplier
				then RebirthConfig.NextMultiplier(rebirthLevel)
				elseif tile.Next then RebirthConfig[tile.Next](rebirthLevel + 1)
				else RebirthConfig[tile.Config]
			local _, caption = tileParts(nodes, tile.Name)
			local text = caption and caption:IsA("TextLabel") and caption.Text or nil
			if type(value) ~= "number" then
				table.insert(
					captions,
					("%s: RebirthConfig.%s is %s"):format(tile.Name, tile.Next or tile.Config, typeof(value))
				)
			else
				local want
				if tile.Multiplier then
					want = tile.Format:format(HudFormat.Multi(value))
				else
					local n = tile.Percent and math.floor(value * 100 + 0.5) or value
					want = (tile.Plural and n ~= 1) and tile.Plural:format(n) or tile.Format:format(n)
				end
				if text ~= want then
					table.insert(captions, ("%sCaption %q, want %q"):format(tile.Name, tostring(text), want))
				end
			end
		end
		h.checkList(res, "rebirth_reward_captions_match_config", captions)

		-- Requirement bar: "<MoneyText(Money)> / <MoneyText(required)>", fill = Money / required (owner 2026-11-01)
		local stats = h.player:FindFirstChild("leaderstats")
		local moneyValue = stats and stats:FindFirstChild("Money")
		local level, need = moneyValue and moneyValue.Value, required()
		local barText = nodes.BarText and nodes.BarText.Text or "missing"
		local wantText = type(level) == "number"
				and RB.BarFormat:format(HudFormat.MoneyText(level), HudFormat.MoneyText(need))
			or "leaderstats.Money missing"
		h.check(res, "rebirth_bar_text_matches_server", barText, wantText, barText == wantText)
		local fill = nodes.Fill
		local ratio = type(level) == "number" and math.clamp(level / need, 0, 1) or nil
		local shown = nil
		if fill and fill.Parent and fill.Parent:IsA("GuiObject") and fill.Parent.AbsoluteSize.X > 0 then
			h.render()
			shown = fill.AbsoluteSize.X / fill.Parent.AbsoluteSize.X
		end
		h.check(
			res,
			"rebirth_bar_fill_matches_money",
			shown,
			ratio and ("%.3f +- %.2f"):format(ratio, RB.FillTolerance) or "leaderstats.Money missing",
			shown ~= nil and ratio ~= nil and math.abs(shown - ratio) <= RB.FillTolerance
		)
		local met = type(level) == "number" and level >= need
		local fillColour = fill and fill.BackgroundColor3
		h.check(
			res,
			"rebirth_bar_fill_green_when_met",
			fillColour and rgb(fillColour) or "missing",
			met and "green" or "any (requirement not met)",
			fillColour ~= nil and (not met or colourOk("green", fillColour))
		)

		-- RebirthButton: a TextButton, shown, label REBIRTH or a server reply, Active only when the server would accept
		local button = h.find(RB.Button)
		local isButton = button ~= nil and button:IsA("TextButton")
		h.check(res, "rebirth_button_present", button and button.ClassName or "missing", "TextButton", isButton)
		if isButton then
			local eligible = met
			h.check(res, "rebirth_button_enabled_matches_server", button.Active, eligible, button.Active == eligible)
			local label = button:FindFirstChild(RB.ButtonLabel, true)
			local text = label and label:IsA("TextLabel") and label.Text or "missing"
			if skipLabel then
				return
			end
			local allowed = text == RB.ButtonText or string.sub(text, 1, 16) == "REBIRTH COMPLETE"
			for _, reply in RB.ButtonReplies do
				allowed = allowed or text == reply:format(HudFormat.MoneyText(need))
			end
			h.check(res, "rebirth_button_label", text, RB.ButtonText .. " or a server reply", allowed)
		end
	end

	-- Every declared node (tile icons and captions included) inside its parent node and inside the panel, the sections
	-- and the UiSpec.Rebirth.Disjoint groups apart, at every UiSpec.Viewports entry (the panel is open).
	local function rebirthGeometry(res, nodes)
		for _, vpSpec in h.viewports do
			local rectOf = h.provider(vpSpec)
			local panelRect = rectOf(nodes.Panel)
			local outside, spill, overlaps = {}, {}, {}
			local function place(name, obj, parent)
				local r = rectOf(obj)
				if not h.contains(panelRect, r) then
					table.insert(outside, name .. h.rstr(r) .. " outside panel " .. h.rstr(panelRect))
				end
				if parent and parent ~= nodes.Panel then
					local pr = rectOf(parent)
					if not h.contains(pr, r) then
						table.insert(spill, name .. h.rstr(r) .. " outside " .. parent.Name .. h.rstr(pr))
					end
				end
				return r
			end
			local rects = {}
			for _, spec in RB.Nodes do
				if nodes[spec.Name] then
					rects[spec.Name] = place(spec.Name, nodes[spec.Name], nodes[spec.Parent])
				end
			end
			local groups = { RB.Sections }
			for _, g in RB.Disjoint do
				table.insert(groups, g)
			end
			for _, g in groups do
				for a = 1, #g do
					for b = a + 1, #g do
						local ra, rb = rects[g[a]], rects[g[b]]
						if ra and rb and h.intersects(ra, rb) then
							table.insert(overlaps, g[a] .. h.rstr(ra) .. " x " .. g[b] .. h.rstr(rb))
						end
					end
				end
			end
			h.checkList(res, "rebirth_nodes_inside_panel_" .. vpSpec.Name, outside)
			h.checkList(res, "rebirth_nodes_inside_parent_" .. vpSpec.Name, spill)
			h.checkList(res, "rebirth_no_overlap_" .. vpSpec.Name, overlaps)
		end
	end

	function scenarios.ui_rebirth(res)
		local restore = h.setPanels({ RB.Panel })
		local title = h.find(RB.Title)
		local titleText = title and title:IsA("TextButton") and title.Text or "missing"
		h.check(res, "rebirth_title", titleText, RB.TitleText, titleText == RB.TitleText)

		local panel = h.find(RB.Panel)
		local leftovers = {}
		for _, d in panel and panel:GetDescendants() or {} do
			if table.find(RB.Removed, d.Name) then
				table.insert(leftovers, h.pathOf(d))
			end
		end
		h.checkList(res, "rebirth_old_parts_gone", leftovers)

		local nodes, missing = rebirthNodes()
		h.checkList(res, "rebirth_nodes_present", missing)
		nodes = nodes or {}

		local hidden, texts, colours, fits, unmodelled, icons = {}, {}, {}, {}, {}, {}
		local function textFits(name, label)
			if label:IsA("TextLabel") and not (label.TextFits or label.TextScaled) then
				table.insert(fits, ("%s %q does not fit"):format(name, label.Text))
			end
		end
		for _, spec in RB.Nodes do
			local o = nodes[spec.Name]
			if o then
				if h.visible(o) == (spec.Hidden == true) then
					table.insert(hidden, spec.Name)
				end
				-- A node without a model row is only fine when it is scale-only (the same at every variant)
				local scaleOnly = o:IsA("GuiObject")
					and o.Size.X.Offset == 0
					and o.Size.Y.Offset == 0
					and o.Position.X.Offset == 0
					and o.Position.Y.Offset == 0
				if not UiResponsive.Nodes[h.pathOf(o)] and not scaleOnly then
					table.insert(unmodelled, h.pathOf(o))
				end
				if o:IsA("TextLabel") then
					if spec.Text and o.Text ~= spec.Text then
						table.insert(texts, ("%s %q, want %q"):format(spec.Name, o.Text, spec.Text))
					end
					for _, piece in spec.Contains or {} do
						if not has(o.Text, piece) then
							table.insert(texts, ("%s %q lacks %q"):format(spec.Name, o.Text, piece))
						end
					end
					if spec.Colour and not colourOk(spec.Colour, o.TextColor3) then
						table.insert(colours, ("%s %s, want %s"):format(spec.Name, rgb(o.TextColor3), spec.Colour))
					end
					textFits(spec.Name, o)
				end
			end
		end
		for _, tile in RB.Tiles do
			local icon, caption = tileParts(nodes, tile.Name)
			if not (icon and icon:IsA("ImageLabel") and icon.Image ~= "" and h.visible(icon)) then
				table.insert(icons, tile.Name .. "Icon: no shown ImageLabel with an Image")
			end
			if not (caption and caption:IsA("TextLabel") and h.visible(caption)) then
				table.insert(icons, tile.Name .. "Caption: no shown TextLabel")
			end
		end
		local button = h.find(RB.Button)
		local label = button and button:FindFirstChild(RB.ButtonLabel, true)
		if label then
			textFits(RB.ButtonLabel, label)
		end
		h.checkList(res, "rebirth_nodes_shown", hidden)
		h.checkList(res, "rebirth_texts_match_spec", texts)
		h.checkList(res, "rebirth_heading_colours", colours)
		h.checkList(res, "rebirth_reward_tiles_icon_and_caption", icons)
		h.checkList(res, "rebirth_texts_fit", fits)
		h.checkList(res, "rebirth_nodes_in_responsive_model", unmodelled)
		h.check(
			res,
			"rebirth_button_shown",
			button ~= nil and h.visible(button),
			true,
			button ~= nil and h.visible(button)
		)

		rebirthTruth(res, nodes)
		if #missing == 0 then
			rebirthGeometry(res, nodes)
		else
			h.check(res, "rebirth_geometry_measured", "nodes missing", "all nodes present", false)
		end
		restore()
	end

	-- After the (intercepted, refused) click: nothing was reset and the panel still shows the server's truth
	function after.rebirth_not_optimistic(res, ctx)
		local level = attr("RebirthLevel") or 0
		h.check(res, "rebirth_level_unchanged", level, ctx.pre.RebirthLevel, level == ctx.pre.RebirthLevel)
		local stats = h.player:FindFirstChild("leaderstats")
		local money = stats and stats:FindFirstChild("Money")
		local moneyNow = money and money.Value
		h.check(
			res,
			"rebirth_money_not_reset",
			moneyNow,
			ctx.pre.ProgressionMoney,
			moneyNow == ctx.pre.ProgressionMoney
		)
		-- retired: rebirth_speed_not_reset (no Speed stat; rebirth resets Money only, design doc 4.13 / 4.14)
		rebirthTruth(res, (rebirthNodes()), true)
	end

	-- Bag / Daily Rewards ---------------------------------------------------------------------------------------

	-- The DailyRewardButton's text against the server's DailyLast. Returns shown, wanted, ok.
	local function dailyButton()
		local button = h.find(DB.Daily)
		local text = button and button:IsA("TextButton") and button.Text or "missing"
		if attr("DailyLast") ~= today() then
			return text, DB.DailyText[false], text == DB.DailyText[false]
		end
		local left = 86400 - os.time() % 86400
		local want = DB.DailyText[true]:format(math.floor(left / 3600), math.floor(left / 60) % 60, left % 60)
		local hh, mm, ss = string.match(text, "(%d%d):(%d%d):(%d%d)$")
		local shownLeft = hh and (tonumber(hh) * 3600 + tonumber(mm) * 60 + tonumber(ss))
		local prefix = string.sub(want, 1, #want - 8)
		local ok = shownLeft ~= nil
			and string.sub(text, 1, #prefix) == prefix
			and #text == #want
			and math.abs(shownLeft - left) <= DB.TimerTolerance
		return text, want, ok
	end

	local function modalView()
		local title = h.find(DB.Title)
		local text = title and title:IsA("TextLabel") and title.Text or ""
		-- "BAG • CONSUMABLES" / "DAILY REWARDS • 7 DAYS"
		return has(text, DB.DailyTitle) and "daily" or has(text, DB.BagTitle) and "bag" or "unknown", text
	end

	-- Where the Bag view differs from the server's inventory: one row per potion owned or active, nothing else.
	local function bagProblems()
		local view, title = modalView()
		local content = h.find(DB.Content)
		if view ~= "bag" or not content then
			return { ("modal shows %q, not the Bag"):format(title) }
		end
		local bad = {}
		for _, category in BoostConfig.Order do
			for _, item in BoostConfig.ItemsFor(category) do
				local count = attr("Boost_" .. item.Id) or 0
				local active = (attr("BoostUntil_" .. item.Id) or 0) > os.time()
				local row = content:FindFirstChild(item.Id)
				local label, use = row and row:FindFirstChild("Label"), row and row:FindFirstChild("Use")
				if count <= 0 and not active then
					if row then
						table.insert(bad, item.Id .. ": row shown with none owned")
					end
				elseif not (label and label:IsA("TextLabel") and use and use:IsA("TextButton")) then
					table.insert(bad, item.Id .. ": no row with Label and Use")
				else
					-- Counts are shortened like every number ("x1.2k", docs/HUD_LAYOUT_SPEC.md section 8)
					local short = "x" .. HudFormat.Short(count)
					local at = string.find(label.Text, short, 1, true)
					local nextChar = at and string.sub(label.Text, at + #short, at + #short)
					if not (has(label.Text, item.Name) and at and not string.match(nextChar, "[%w%.]")) then
						table.insert(bad, ("%s: label %q, want %s %s"):format(item.Id, label.Text, item.Name, short))
					end
					local usable = count > 0 and not active
					if use.Active ~= usable then
						table.insert(
							bad,
							("%s: Use Active=%s, want %s"):format(item.Id, tostring(use.Active), tostring(usable))
						)
					end
					local textOk = (active and has(use.Text, DB.ActiveText)) or (not active and use.Text == DB.UseText)
					if not textOk then
						table.insert(bad, ("%s: Use shows %q"):format(item.Id, use.Text))
					end
				end
			end
		end
		return bad
	end

	-- Where the Daily view differs from the server's DailyStreak / DailyLast.
	local function dailyProblems()
		local view, title = modalView()
		local content = h.find(DB.Content)
		if view ~= "daily" or not content then
			return { ("modal shows %q, not the Daily Rewards"):format(title) }
		end
		local bad = {}
		local days = #DailyLoginConfig.Rewards
		local streak = math.clamp(attr("DailyStreak") or 0, 0, days)
		local claimed = attr("DailyLast") == today()
		for day = 1, days do
			local row = content:FindFirstChild("RewardCards")
			row = row and row:FindFirstChild(DB.DayRow:format(day))
			local label = row and row:FindFirstChild("Label")
			if not (row and row:IsA("Frame") and label and has(label.Text, DB.DayText:format(day))) then
				table.insert(bad, ("day %d: no row"):format(day))
			else
				local completion = row:FindFirstChild("Completion")
				local marked = completion and completion:IsA("TextLabel") and has(completion.Text, DB.DoneMark)
				if marked ~= (day <= streak) then
					table.insert(bad, ("day %d completion with DailyStreak %d"):format(day, streak))
				end
			end
		end
		local claim = content:FindFirstChild("Claim")
		local want = claimed and DB.ClaimText[true] or DB.ClaimText[false]:format(math.min(streak + 1, days))
		if not (claim and claim:IsA("TextButton")) then
			table.insert(bad, "no Claim button")
		elseif claim.Text ~= want or claim.Active ~= not claimed then
			table.insert(
				bad,
				("Claim shows %q Active=%s, want %q Active=%s"):format(
					claim.Text,
					tostring(claim.Active),
					want,
					tostring(not claimed)
				)
			)
		end
		return bad
	end

	-- Design doc 4.41, owner 2026-11-05: red text, no background, gone within 1 s, for each blocked try. BagFullHit is what the loop fires.
	function scenarios.ui_bag_full(res)
		local gui = h.find("RollExtras")
		h.check(res, "bag_full_gui", gui ~= nil, true, gui ~= nil)
		local label = h.find("RollExtras/BagFull")
		h.check(
			res,
			"bag_full_is_text",
			label and label.ClassName,
			"TextLabel",
			label ~= nil and label:IsA("TextLabel")
		)
		if not (label and label:IsA("TextLabel")) then
			return
		end
		h.check(res, "bag_full_no_background", label.BackgroundTransparency, 1, label.BackgroundTransparency == 1)
		h.check(res, "bag_full_text", label.Text, "BAG FULL", label.Text == "BAG FULL")
		local c = label.TextColor3
		h.check(res, "bag_full_red", rgb(c), "red", c.R >= 0.5 and c.G < 0.3 and c.B < 0.3)
		local buttons = {}
		for _, d in gui:GetDescendants() do
			if d:IsA("GuiButton") then
				table.insert(buttons, d.Name) -- auto sell is in Settings only (owner 2026-11-09)
			end
		end
		h.checkList(res, "bag_full_no_buttons", buttons)
		local function untilShown(want, seconds)
			local deadline = os.clock() + seconds
			while h.visible(label) ~= want and os.clock() < deadline do
				task.wait()
			end
			return h.visible(label)
		end
		h.check(res, "bag_full_hidden_at_rest", untilShown(false, 1.5), false, untilShown(false, 0) == false)
		local fired, why = h.requestSetup("bag_full_hit")
		h.check(res, "bag_full_hit_setup", tostring(why), "ok", fired == true)
		h.check(res, "bag_full_shows_on_a_hit", untilShown(true, 2), true, h.visible(label))
		local shownAt = os.clock()
		h.check(res, "bag_full_solid_at_first", label.TextTransparency, "< 0.5", label.TextTransparency < 0.5)

		-- A second try restarts it: solid again, and a full second from there.
		task.wait(0.6)
		local faded = label.TextTransparency
		h.check(res, "bag_full_fades", faded, "> 0", faded > 0)
		h.requestSetup("bag_full_hit")
		local deadline, restarted = os.clock() + 1, false
		while not restarted and os.clock() < deadline do
			restarted = label.TextTransparency < faded
			task.wait()
		end
		h.check(res, "bag_full_restarts_on_a_hit", restarted, true, restarted)
		shownAt = os.clock()
		local gone = untilShown(false, 1.5) == false
		local seconds = os.clock() - shownAt
		h.check(res, "bag_full_gone", gone, true, gone)
		h.check(res, "bag_full_gone_within_1_s", seconds, "<= 1.2", seconds <= 1.2)

		-- Owner 2026-11-06: a tick that sells at a full bag warns too. The real loop, on this player; rolls and copies are the server's.
		local rollsBefore = attr("Rolls")
		local soldUp, soldWhy = h.requestSetup("bag_full_sold")
		h.check(res, "bag_full_sold_setup", tostring(soldWhy), "ok", soldUp == true)
		local warned = untilShown(true, SOLD_TICK_WAIT)
		h.check(res, "bag_full_warns_on_a_sold_tick", warned, true, warned == true)
		local rolled = attr("Rolls") ~= rollsBefore
		h.check(res, "bag_full_sold_tick_counts", attr("Rolls"), "not " .. tostring(rollsBefore), rolled)
		h.check(res, "bag_full_stays_full", attr("BagFull"), true, attr("BagFull") == true)
		-- A missing roll's failure reads the cause (ui_toast, ui_roll_anim), proved on this really full bag.
		local noRoll = Spec.NoRollWhy(h.player)
		h.check(
			res,
			"no_roll_reason_names_full_bag",
			noRoll,
			"bag full",
			string.find(noRoll, "bag full", 1, true) ~= nil
		)
		h.check(res, "bag_full_autoroll_stays_on", attr("AutoRoll"), true, attr("AutoRoll") == true)
		h.requestSetup("bag_spares_clear")
		untilShown(false, 1.5)
	end

	-- After the real press: it opens the Auto Sell popup and sends nothing; its Close shuts it.
	function after.auto_sell_popup_open(res)
		local popup = h.find("RollOptions/AutoSell")
		h.check(
			res,
			"auto_sell_popup_opens",
			popup ~= nil and h.visible(popup),
			true,
			popup ~= nil and h.visible(popup)
		)
	end
	function after.auto_sell_popup_closed(res)
		local popup = h.find("RollOptions/AutoSell")
		h.check(
			res,
			"auto_sell_popup_closes",
			popup ~= nil and h.visible(popup),
			false,
			popup ~= nil and not h.visible(popup)
		)
	end

	function scenarios.ui_daily_boosts(res)
		for _, part in
			{
				{ "bag_button", DB.Bag, "TextButton", "BAG" },
				{ "daily_button", DB.Daily, "TextButton" },
				{ "status", DB.Status, "TextLabel" },
				{ "modal", DB.Panel, "Frame" },
				{ "modal_title", DB.Title, "TextLabel" },
				{ "modal_close", DB.Close, "TextButton", "×" },
				{ "modal_content", DB.Content, "ScrollingFrame" },
			}
		do
			local o = h.find(part[2])
			local ok = o ~= nil and o.ClassName == part[3]
			h.check(res, "daily_boosts_part_" .. part[1], o and o.ClassName or "missing", part[3], ok)
			if ok and part[4] then
				h.check(res, "daily_boosts_text_" .. part[1], o.Text, part[4], o.Text == part[4])
			end
		end
		local text, want, ok = dailyButton()
		h.check(res, "daily_button_follows_server_daily_last", text, want, ok)
		-- Whatever the modal last rendered must be the server's truth (the clicks render and re-check each view)
		local view = modalView()
		if view == "daily" then
			h.checkList(res, "daily_view_matches_server", dailyProblems())
		elseif view == "bag" then
			-- The Bag re-renders once a second while shown; hidden, it keeps its last render (not judged)
			local panel = h.find(DB.Panel)
			if panel and panel:IsA("GuiObject") and h.visible(panel) then
				h.checkList(res, "bag_view_matches_server", bagProblems())
			end
		end
	end

	function after.bag_shows_server_inventory(res)
		h.checkList(res, "bag_shows_server_inventory", bagProblems())
	end
	function after.daily_shows_server_streak(res)
		h.checkList(res, "daily_shows_server_streak", dailyProblems())
		local text, want, ok = dailyButton()
		h.check(res, "daily_button_follows_server_daily_last", text, want, ok)
	end
	-- After the (intercepted, refused) click: the server's values are what they were
	function after.boost_not_optimistic(res, ctx)
		for _, key in { "Boost_" .. DB.FixtureBoost, "BoostUntil_" .. DB.FixtureBoost } do
			h.check(res, "unchanged_" .. string.lower(key), attr(key), ctx.pre[key], attr(key) == ctx.pre[key])
		end
	end
	function after.daily_not_optimistic(res, ctx)
		for _, key in { "DailyLast", "DailyStreak" } do
			h.check(res, "unchanged_" .. string.lower(key), attr(key), ctx.pre[key], attr(key) == ctx.pre[key])
		end
	end

	-- Extra values the click protocol remembers before a click (merged into its attribute snapshot).
	local function snapshot(into)
		into.RebirthLevel = attr("RebirthLevel") or 0
		for _, key in { "DailyLast", "DailyStreak", "Boost_" .. DB.FixtureBoost, "BoostUntil_" .. DB.FixtureBoost } do
			into[key] = attr(key)
		end
		return into
	end

	-- "{boost}" in a click path: the fixture's potion, when the server says the Bag has a row for it.
	local function boostToken()
		local id = DB.FixtureBoost
		if (attr("Boost_" .. id) or 0) > 0 or (attr("BoostUntil_" .. id) or 0) > os.time() then
			return id
		end
		return nil
	end

	return { Scenarios = scenarios, After = after, Snapshot = snapshot, BoostToken = boostToken }
end

return Extras
