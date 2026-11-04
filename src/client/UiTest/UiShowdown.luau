--!nonstrict
-- Enemy showdown banners and the Defeated Enemies page (design doc 4.28, 4.29). Owned by ui-test-writer.
-- The server fixtures (UiTestSetup showdown_start, showdown_win, lose_event, defeated_states) drive the states; the
-- scenarios only listen to Remotes.NpcRace, so a real race event arriving mid-check moves the expected enemy with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BiomeThemes = require(Shared:WaitForChild("BiomeThemes"))
local NpcConfig = require(Shared:WaitForChild("NpcConfig"))
local RaceProgressMap = require(Shared:WaitForChild("RaceProgressMap"))
local TrackRegistry = require(Shared:WaitForChild("TrackRegistry"))
local Spec = require(script.Parent.UiSpec)
local B = Spec.Guis.EnemyShowdown
local D = Spec.DefeatedEnemies

local Showdown = {}

-- The player-facing name: track specs keep the fork's internal Name, BiomeThemes.DisplayName is what players read.
local function trackName(number)
	for _, spec in TrackRegistry.Chain() do
		if spec.Number == number then
			local theme = BiomeThemes[spec.Biome]
			return theme and theme.DisplayName
		end
	end
	return nil
end

-- Repeats fn every frame until it returns an empty list or the time is up; returns the last list.
local function poll(seconds, fn)
	local deadline = os.clock() + seconds
	local bad = fn()
	while #bad > 0 and os.clock() < deadline do
		task.wait()
		bad = fn()
	end
	return bad
end

local function showsText(label)
	return (label:IsA("TextLabel") or label:IsA("TextButton")) and label.Text ~= "" and label.TextTransparency < 0.95
end

-- An enemy's portrait really shows (docs/CHARACTER_GACHA_SPEC.md "Digital art portrait"): an ImageLabel of its drawn
-- image when one exists for its model (`track`'s NpcConfig Model), else a ViewportFrame with a camera and a model with
-- parts. Adds what is wrong to bad; returns what it draws (the image, or the model's name), nil when it draws nothing.
local function portraitModel(portrait, bad, who, track)
	local client = script.Parent.Parent
	local Components = require(client:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("RacerComponents"))
	local image = Components.PortraitImage({ Id = NpcConfig.For(track).Model })
	if image then
		if not (portrait and portrait:IsA("ImageLabel") and portrait.Image == image) then
			table.insert(
				bad,
				("%s: %s, want an ImageLabel of %s"):format(who, portrait and portrait.ClassName or "missing", image)
			)
			return nil
		end
		return image
	end
	if not (portrait and portrait:IsA("ViewportFrame")) then
		table.insert(bad, who .. ": no ViewportFrame")
		return nil
	end
	local model = portrait:FindFirstChildWhichIsA("Model", true)
	if not (model and model:FindFirstChildWhichIsA("BasePart", true)) then
		table.insert(bad, who .. ": no model with parts in the portrait")
		return nil
	end
	if not portrait.CurrentCamera then
		table.insert(bad, who .. ": portrait has no CurrentCamera, it draws nothing")
	end
	return model.Name
end

function Showdown.Build(h)
	local check, checkList, stateMissing = h.check, h.checkList, h.stateMissing
	local S = {}

	local function showdownChecks(res, gui, banner, track)
		local function named(name)
			return banner:FindFirstChild(name, true)
		end
		local function drawn(name)
			local label = named(name)
			return label ~= nil and h.visible(label) and showsText(label)
		end
		local lastStart, lastWin, loseAt, wins = nil, nil, nil, 0
		local portraits = {}
		track.on = function(event)
			if event.Type == "Start" then
				lastStart = event
			elseif event.Type == "Result" and event.Result == "Win" then
				lastWin, wins = event, wins + 1
			elseif event.Type == "Result" and event.Result == "Lose" then
				loseAt = os.clock()
			end
		end
		local function waitHidden(window)
			local hard = os.clock() + 4 * window
			while h.visible(banner) and os.clock() < math.min(hard, track.lastAt + window) do
				task.wait()
			end
			return not h.visible(banner)
		end
		local function enemyBad(number, bad)
			local want = NpcConfig.For(number).Label
			local name = named(B.EnemyName)
			if not (drawn(B.EnemyName) and name.Text == want) then
				table.insert(bad, ("EnemyName %q want %q"):format(name and name.Text or "missing", want))
			end
			local portrait = named(B.Portrait)
			if not (portrait and h.visible(portrait)) then
				table.insert(bad, "Portrait not shown")
			end
			local drawnFigure = portraitModel(portrait, bad, "Portrait", number)
			if drawnFigure then
				portraits[number] = portraits[number] or drawnFigure
			end
		end
		local function vsBad()
			local bad = {}
			if not lastStart then
				return { "no NpcRace Start" }
			end
			if not drawn(B.Vs) then
				table.insert(bad, "Vs not shown")
			end
			if drawn(B.Defeated) then
				table.insert(bad, "Defeated shown on a Start")
			end
			enemyBad(lastStart.Track, bad)
			local want = trackName(lastStart.Track)
			local name = named(B.TrackName)
			if not (want and drawn(B.TrackName) and string.find(name.Text, want, 1, true)) then
				table.insert(bad, ("TrackName %q want %q"):format(name and name.Text or "missing", tostring(want)))
			end
			return bad
		end

		local rest = waitHidden(2 * B.MaxShown)
		check(res, "showdown_banner_hidden_at_rest", rest, true, rest)

		-- VS on Start
		local ok, err = h.requestSetup("showdown_start")
		if not ok then
			stateMissing(res, "showdown_vs_shown", "showdown_start", tostring(err))
			return
		end
		checkList(res, "showdown_vs_shown", poll(B.ShowWait, vsBad))
		local swallowing = {}
		for _, d in gui:GetDescendants() do
			if d:IsA("GuiObject") and h.swallows(d) then
				table.insert(swallowing, h.pathOf(d))
			end
		end
		checkList(res, "showdown_takes_no_input_while_shown", swallowing)
		local hidden = waitHidden(B.MaxShown)
		check(res, "showdown_vs_hides_by_itself", hidden, true, hidden)

		-- A real win fires Result Win and the next track's Start in the same frame (RaceService), and both must show
		lastWin = nil
		ok, err = h.requestSetup("showdown_win")
		if not ok then
			stateMissing(res, "showdown_defeated_shown", "showdown_win", tostring(err))
			return
		end
		local defeatedBad = poll(B.ShowWait, function()
			local bad = {}
			if not lastWin then
				return { "no NpcRace Result Win" }
			end
			if not drawn(B.Defeated) then
				table.insert(bad, "Defeated not shown")
			end
			if drawn(B.Vs) then
				table.insert(bad, "Vs shown with Defeated")
			end
			enemyBad(lastWin.Track, bad)
			if #bad == 0 then
				bad.modelName = portraitModel(named(B.Portrait), bad, "Portrait", lastWin.Track)
			end
			return bad
		end)
		checkList(res, "showdown_defeated_shown", defeatedBad)
		if lastWin and defeatedBad.modelName then
			local want = portraits[lastWin.Track]
			check(res, "showdown_defeated_same_portrait", defeatedBad.modelName, want, defeatedBad.modelName == want)
		end
		checkList(res, "showdown_vs_follows_the_win", poll(2 * B.MaxShown, vsBad))
		hidden = waitHidden(B.MaxShown)
		check(res, "showdown_hides_after_the_win", hidden, true, hidden)

		-- Lose: never Defeated, up to and past lose_event's own Reset and Start
		local winsBefore = wins
		loseAt = nil
		ok, err = h.requestSetup("lose_event")
		if not ok then
			stateMissing(res, "showdown_lose_shows_no_defeated", "lose_event", tostring(err))
			return
		end
		local deadline = os.clock() + Spec.Waits.LoseEvent
		while not loseAt and os.clock() < deadline do
			task.wait()
		end
		if not loseAt then
			stateMissing(res, "showdown_lose_shows_no_defeated", "lose_event", "no NpcRace Result Lose received")
			return
		end
		local shown = false
		deadline = os.clock() + NpcConfig.LOSE_SCREEN_SECONDS + B.ShowWait
		while os.clock() < deadline do
			shown = shown or drawn(B.Defeated)
			task.wait()
		end
		if wins ~= winsBefore then
			stateMissing(res, "showdown_lose_shows_no_defeated", "lose_event", "a real win arrived during the check")
			return
		end
		check(res, "showdown_lose_shows_no_defeated", shown, false, not shown)
	end

	function S.ui_showdown(res)
		h.waitGuis()
		local gui = h.playerGui:FindFirstChild("EnemyShowdown")
		local banner = gui and gui:FindFirstChild(B.Banner)
		check(res, "showdown_banner_present", banner and banner:GetFullName(), B.Banner, banner ~= nil)
		if not banner then
			return
		end
		local track = { lastAt = os.clock() }
		local conn = ReplicatedStorage:WaitForChild("Remotes")
			:WaitForChild("NpcRace").OnClientEvent
			:Connect(function(event)
				if type(event) == "table" and track.on then
					track.lastAt = os.clock()
					track.on(event)
				end
			end)
		showdownChecks(res, gui, banner, track)
		conn:Disconnect()
	end

	-- `tile` is the outer frame: the page behind it may be closed, so tile content is judged from the tile down.
	local function drawnInTile(obj, tile)
		local node = obj
		while node and node ~= tile do
			if node:IsA("GuiObject") and not node.Visible then
				return false
			end
			node = node.Parent
		end
		return node == tile
	end

	local function tileBad(n, tile, best)
		local bad = {}
		local who = D.TileFormat:format(n)
		local label = NpcConfig.For(n).Label
		local beaten = n <= best
		if tile:GetAttribute(D.Beaten) ~= beaten then
			table.insert(
				bad,
				("%s: Beaten %s want %s"):format(who, tostring(tile:GetAttribute(D.Beaten)), tostring(beaten))
			)
		end
		local texts, viewports = {}, {}
		for _, d in tile:GetDescendants() do
			if drawnInTile(d, tile) then
				if d:IsA("GuiObject") and showsText(d) then
					table.insert(texts, d.Text)
				elseif d:IsA("ViewportFrame") or (d:IsA("ImageLabel") and d.Name == B.Portrait) then
					table.insert(viewports, d)
				end
			end
		end
		local function shows(text)
			for _, t in texts do
				if string.find(string.lower(t), string.lower(text), 1, true) then
					return true
				end
			end
			return false
		end
		if beaten then
			if not table.find(texts, label) then
				table.insert(bad, who .. ": beaten, no label reads " .. label)
			end
			local seconds = h.player:GetAttribute(D.TimeAttr:format(n))
			-- Only the fixture knows the time: a live save may have reached a track before race bests were kept
			if seconds and not shows(RaceProgressMap.FormatTime(seconds)) then
				table.insert(bad, who .. ": beaten, no label reads " .. RaceProgressMap.FormatTime(seconds))
			end
			if #viewports == 0 then
				table.insert(bad, who .. ": beaten, no portrait shown")
			else
				portraitModel(viewports[1], bad, who, n)
			end
		else
			if shows(label) then
				table.insert(bad, who .. ": locked but shows the name")
			end
			if #viewports > 0 then
				table.insert(bad, who .. ": locked but shows a portrait")
			end
		end
		return bad
	end

	function S.ui_defeated(res)
		h.waitGuis()
		local panel = h.find("RacerIndex/Panel")
		local page = panel and panel:FindFirstChild(D.Page, true)
		check(res, "enemies_page_present", page and page:GetFullName(), D.Page, page ~= nil)
		if not page then
			return
		end
		local restore = h.setPanels({ "RacerIndex/Panel" })

		-- The tab's name is not agreed: the page shows when the Index opens, or a visible button names it
		local reachable = h.visible(page)
		for _, d in panel:GetDescendants() do
			if d:IsA("GuiButton") and h.visible(d) and not d:IsDescendantOf(page) then
				local words =
					string.lower(d.Name .. " " .. d.Parent.Name .. " " .. (d:IsA("TextButton") and d.Text or ""))
				reachable = reachable
					or string.find(words, "enem", 1, true) ~= nil
					or string.find(words, "defeat", 1, true) ~= nil
			end
		end
		check(res, "enemies_page_reachable_from_index", reachable, true, reachable)

		-- One tile per track
		local total = #NpcConfig.Tracks
		local tiles, wrong = {}, {}
		for _, d in page:GetDescendants() do
			local n = d:IsA("GuiObject") and tonumber(string.match(d.Name, "^" .. D.TilePattern .. "$"))
			if n then
				if tiles[n] or n < 1 or n > total then
					table.insert(wrong, "extra " .. d.Name)
				end
				tiles[n] = d
			end
		end
		for n = 1, total do
			if not tiles[n] then
				table.insert(wrong, "missing " .. D.TileFormat:format(n))
			end
		end
		checkList(res, "one_enemy_tile_per_track", wrong)
		if #wrong > 0 then
			restore()
			return
		end

		-- Track order. A closed page may not have laid its tiles out, so it falls back to LayoutOrder.
		local order, want = {}, {}
		for n = 1, total do
			order[n], want[n] = n, n
		end
		local pageOpen = h.visible(page)
		table.sort(order, function(a, b)
			if not pageOpen then
				return tiles[a].LayoutOrder < tiles[b].LayoutOrder
			end
			local ra, rb = h.rect(tiles[a]), h.rect(tiles[b])
			if math.abs(ra.y - rb.y) > h.tolerance then
				return ra.y < rb.y
			end
			return ra.x < rb.x
		end)
		local seen, expected = table.concat(order, ","), table.concat(want, ",")
		check(res, "enemy_tiles_in_track_order", seen, expected, seen == expected)

		-- BestTrack n: re-read each pass, a racing main run can raise it
		local best = 0
		checkList(
			res,
			"enemy_tiles_match_best_track",
			poll(D.FillWait, function()
				local bad = {}
				best = tonumber(h.player:GetAttribute("BestTrack")) or 0
				for n = 1, total do
					for _, line in tileBad(n, tiles[n], best) do
						table.insert(bad, line)
					end
				end
				return bad
			end)
		)
		-- The fixture must really give both kinds; a main run judges whatever the save holds
		if h.player:GetAttribute(D.TimeAttr:format(1)) then
			if best < 1 then
				stateMissing(res, "has_beaten_enemy_tile", "defeated_states", "BestTrack " .. best)
			end
			if best >= total then
				stateMissing(res, "has_locked_enemy_tile", "defeated_states", "BestTrack " .. best)
			end
		end
		restore()
	end

	return { Scenarios = S }
end

return Showdown
