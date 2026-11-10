--!nonstrict
-- Bag and seven-day daily reward presentation. Server remotes own all grants.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local dailyConfig = require(ReplicatedStorage.Shared.DailyLoginConfig)
local questConfig = require(ReplicatedStorage.Shared.QuestConfig)
local HttpService = game:GetService("HttpService")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local HudIcons = require(script.Parent.RollToast.Ui.HudIcons)
local PotionIcons = require(script.Parent.RollToast.Ui.PotionIcons)
local UiTheme = require(ReplicatedStorage.Shared:WaitForChild("UiTheme"))
local HudFormat = require(ReplicatedStorage.Shared:WaitForChild("HudFormat"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local ArrivalState = require(script.Parent:WaitForChild("ArrivalState"))
local QuestAnimeStyle = require(script.Parent:WaitForChild("QuestAnimeStyle"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))

local screen = Instance.new("ScreenGui")
screen.Name = "DailyBoosts"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 6
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = gui

-- Backpack / Market vocabulary (HUD_LAYOUT_SPEC section 3): dark body, navy tiles with a blue glow border,
-- white border on the selection, Fredoka text with a dark outline.
local OUTLINE = UiTheme.Outline
local PALETTE = UiTheme.Palette
local Boosts = require(ReplicatedStorage.Shared:WaitForChild("BoostConfig"))
local TILE = PALETTE.TileDeep
local TILE_BLUE = PALETTE.Tile
local TAB = PALETTE.TabIdle
local GREEN = PALETTE.MoneyDeep -- white stroked text stays readable on it
local REPLY_SECONDS = 2 -- placeholder: a reply stays this long, then fades
local SHINE_EVERY = 3 -- placeholder: seconds between a claimable button's light sweeps

local function make(class, name, parent, props)
	local instance = Instance.new(class)
	instance.Name = name
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function rounded(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function button(name, parent, position, size, text)
	local instance = make("TextButton", name, parent, {
		Position = position,
		Size = size,
		BackgroundColor3 = TAB,
		TextColor3 = Color3.new(1, 1, 1),
		Font = UiTheme.Font,
		TextSize = 18,
		Text = text,
		AutoButtonColor = false,
	})
	rounded(instance, UiTheme.Radius.S)
	make(
		"UIStroke",
		"Edge",
		instance,
		{ Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
	)
	return instance
end

local function cascade(rows, edgeName)
	UiMotion.Cascade(rows, edgeName)
end

local backdrop = make("Frame", "ModalBackdrop", screen, {
	Position = UDim2.fromScale(0, 0),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, -- the world dim is HudChrome/PanelDim, below the HUD
	Visible = false,
	Active = false, -- HUD tiles behind stay clickable (owner 2026-10-20)
})
PanelSwitch.Register("Daily", backdrop)
local modal = make("Frame", "Modal", backdrop, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.08),
	Size = UDim2.fromScale(0.82, 0.78),
})
rounded(modal, UiTheme.Radius.L)
local header = make("Frame", "Header", modal, {
	Position = UDim2.fromOffset(5, 5),
	Size = UDim2.new(1, -10, 0, 72),
	BorderSizePixel = 0,
})
rounded(header, 10)
make("ImageLabel", "CalendarIcon", header, {
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.fromOffset(52, 52),
	BackgroundTransparency = 1,
	Image = HudIcons.Daily.Image,
	ScaleType = Enum.ScaleType.Fit,
})
local title = make("TextLabel", "Title", modal, {
	Position = UDim2.fromOffset(78, 14),
	Size = UDim2.new(1, -150, 0, 48),
	BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1),
	Font = UiTheme.Font,
	TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "DAILY REWARDS",
})
UiTheme.Stroke(title, 2)
local close = button("Close", modal, UDim2.new(1, -62, 0, 12), UDim2.fromOffset(48, 48), "")
local panelFrame = require(script.Parent:WaitForChild("PanelFrame")).Attach(modal, {
	IndexFrame = false, -- Client/QuestAnimeStyle draws the Index frame for both views
	Theme = "Daily",
	Title = "DAILY REWARDS",
	Icon = HudIcons.Daily.Image,
	TitleObject = title,
	IconObject = header.CalendarIcon,
	Close = close,
	MaxWidth = 760,
})
local content = make("ScrollingFrame", "Content", modal, {
	Position = UDim2.fromOffset(14, 88),
	Size = UDim2.new(1, -28, 1, -100),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
})
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = content

-- Quest list/detail treatment from images/UI_QuestReference.png. The game has
-- Daily and Weekly quest data only, so the reference's other categories and
-- search controls are intentionally omitted.
local questTabs = make("Frame", "QuestTabs", modal, {
	Position = UDim2.fromOffset(14, 52),
	Size = UDim2.new(1, -28, 0, 38),
	BackgroundTransparency = 1,
	Visible = false,
})
local questTabLayout = Instance.new("UIListLayout")
questTabLayout.FillDirection = Enum.FillDirection.Horizontal
questTabLayout.Padding = UDim.new(0, 8)
questTabLayout.Parent = questTabs
local dailyQuestTab = button("Daily", questTabs, UDim2.new(), UDim2.new(0.5, -4, 1, 0), "DAILY")
local weeklyQuestTab = button("Weekly", questTabs, UDim2.new(), UDim2.new(0.5, -4, 1, 0), "WEEKLY")

local questDetail = make("Frame", "QuestDetail", modal, {
	Position = UDim2.new(0.55, 0, 0, 100),
	Size = UDim2.new(0.45, -14, 1, -114),
	BackgroundColor3 = TILE,
	BorderSizePixel = 0,
	Visible = false,
})
rounded(questDetail, 12)
local questDetailEdge = Instance.new("UIStroke")
questDetailEdge.Color = TILE_BLUE
questDetailEdge.Thickness = 4
questDetailEdge.Parent = questDetail
local function detailText(name, position, size, textSize, color)
	local label = make("TextLabel", name, questDetail, {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = color,
		Font = UiTheme.Font,
		TextSize = textSize + 2,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round })
	return label
end
local questType = detailText("Type", UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 20), 13, PALETTE.Sky)
local questName = detailText("Name", UDim2.fromOffset(14, 35), UDim2.new(1, -28, 0, 54), 22, PALETTE.Gold)
local questGoal = detailText("Goal", UDim2.fromOffset(14, 94), UDim2.new(1, -28, 0, 42), 14, PALETTE.SoftText)
local progressTrack = make("Frame", "ProgressTrack", questDetail, {
	Position = UDim2.fromOffset(14, 144),
	Size = UDim2.new(1, -28, 0, 24),
	BackgroundColor3 = PALETTE.Done,
	BorderSizePixel = 0,
})
rounded(progressTrack, 8)
local progressFill = make("Frame", "Fill", progressTrack, {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = GREEN,
	BorderSizePixel = 0,
})
rounded(progressFill, 8)
local progressText = make("TextLabel", "Progress", progressTrack, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "0 / 0",
	TextColor3 = Color3.new(1, 1, 1),
	Font = UiTheme.Font,
	TextSize = 13,
})
local questReward = detailText("Reward", UDim2.fromOffset(14, 184), UDim2.new(1, -28, 0, 48), 15, PALETTE.Gold)
-- Quests wear the Index look (design doc 4.42); the Daily view keeps PanelFrame's.
local anime = QuestAnimeStyle.Attach({
	Modal = modal,
	Header = header,
	Title = title,
	Close = close,
	Tabs = questTabs,
	TabLayout = questTabLayout,
	Daily = dailyQuestTab,
	Weekly = weeklyQuestTab,
	Content = content,
	Detail = questDetail,
	Type = questType,
	Name = questName,
	Track = progressTrack,
	Fill = progressFill,
	ProgressText = progressText,
	Reward = questReward,
	Logo = HudIcons.Quests.Image,
	DailyLogo = HudIcons.Daily.Image,
	OnClose = function()
		PanelSwitch.Close("Daily")
	end,
})

local status = make("TextLabel", "Status", screen, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 1, -130),
	Size = UDim2.fromOffset(160, 42),
	BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1),
	Font = UiTheme.Font,
	TextSize = 13,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "",
})
local statusHome = status.Position
UiTheme.Stroke(status, 2)
-- The reply inside the panel: Status hides while a panel is open (HUD_LAYOUT_SPEC section 6), so a claim's answer shows here.
local reply = make("TextLabel", "Reply", modal, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -6),
	Size = UDim2.new(1, -28, 0, 24),
	BackgroundColor3 = PALETTE.PanelDeep,
	BackgroundTransparency = 0.15,
	TextColor3 = PALETTE.White,
	Font = UiTheme.Font,
	TextSize = 18,
	Text = "",
	Visible = false,
	ZIndex = 6,
})
rounded(reply, UiTheme.Radius.S)
UiTheme.Stroke(reply, 2)
local replySerial = 0
-- A claim answer slides in from the right edge, stays 2 s and fades away (design doc 4.20).
local function notify(text)
	replySerial += 1
	local mine = replySerial
	status.Text = text
	status.Position = statusHome
	status.TextTransparency = 0
	status.ThemeStroke.Transparency = 0
	UiMotion.SlideIn(status, Vector2.new(40, 0))
	reply.Text = text
	UiMotion.Fade(reply, true, 0.15)
	task.delay(REPLY_SECONDS, function()
		if replySerial ~= mine then
			return
		end
		UiMotion.Fade(reply, false, 0.25)
		UiMotion.Create(status, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		UiMotion.Create(status.ThemeStroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		task.delay(0.3, function()
			if replySerial == mine then
				status.Text = ""
				reply.Text = ""
			end
		end)
	end)
end
local stopClaimPulse, stopTodayPulse = nil, nil -- the Daily claim button and today's tile glow while claimable
local shineRun = 0 -- bumping it ends every claimable button's shine loop
local function stopPulse()
	shineRun += 1
	if stopClaimPulse then
		stopClaimPulse()
		stopClaimPulse = nil
	end
	if stopTodayPulse then
		stopTodayPulse()
		stopTodayPulse = nil
	end
end

-- A light sweep every SHINE_EVERY s until stopPulse or the button stops being claimable. Shine does nothing while reduced.
local function shineWhileClaimable(claim)
	local run = shineRun
	task.spawn(function()
		while true do
			task.wait(SHINE_EVERY)
			if run ~= shineRun or not claim.Parent or not claim.Active then
				return
			end
			UiMotion.Shine(claim, 0.9)
		end
	end)
end

-- An answer rebuilt the panel, so the new gui has its screen place only next frame. find() gets it (nil: sound only).
local function answerCue(cue, find)
	task.delay(0, function()
		-- No Target, so no coins: these rewards are potions, not money.
		UiFeedback.Play(cue, find())
	end)
end

local view = nil -- "Daily" or "Quests": which content the shared modal shows
local questCategory = "Daily"
local questRows = {}

local function layoutView()
	local camera = workspace.CurrentCamera
	local phone = camera and camera.ViewportSize.Y <= 500
	local quests = view == "Quests"
	questTabs.Visible = quests
	questDetail.Visible = quests and not phone
	content.ScrollBarThickness = (quests and 5) or (phone and 4) or 0 -- the Daily grid fits the desktop area
	content.VerticalScrollBarInset = Enum.ScrollBarInset.None
	anime:Layout() -- the Daily view lays out from anime.OnDaily
end

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutView)
end

local function refreshChrome()
	local camera = workspace.CurrentCamera
	local compact = camera and camera.ViewportSize.Y <= 500
	status.Visible = not compact and not PanelSwitch.AnyOpen()
end

PanelSwitch.OnChange(refreshChrome)
backdrop:GetPropertyChangedSignal("Visible"):Connect(function()
	if not backdrop.Visible then
		stopPulse() -- no loop while hidden
	end
	refreshChrome()
end)

local function clearContent()
	stopPulse()
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local fresh = Instance.new("UIListLayout")
	fresh.Padding = UDim.new(0, 8)
	fresh.Parent = content
end

local function rewardArt(reward)
	if reward.GuaranteedRare then
		return HudIcons.Rebirth.Image
	end
	return PotionIcons[reward.Boost] or HudIcons.Daily.Image
end

local function dailyCard(parent, day, reward, done, featured)
	local card = make("Frame", "Day" .. day, parent, {
		BackgroundColor3 = done and PALETTE.Done or Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	})
	rounded(card, 12)
	if not done then -- completed cards stay dark and flat
		UiTheme.Gradient(card, PALETTE.Row, PALETTE.PanelDeep)
	end
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Color = done and PALETTE.MoneyDeep or (featured and PALETTE.Featured or PALETTE.Tile)
	edge.Thickness = 3
	edge.Parent = card
	-- Design doc 4.42: the angular card; only today's card keeps its glowing edge (set in showDaily).
	AnimeSkin.Card(card, done and AnimeSkin.Tint.Muted or featured and AnimeSkin.Tint.Gold or AnimeSkin.Tint.Default)
	edge.Enabled = false
	local align = featured and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
	make("TextLabel", "Label", card, {
		BackgroundTransparency = 1,
		Text = "DAY " .. day,
		TextXAlignment = align,
		TextTransparency = done and 0.35 or 0,
	})
	make("ImageLabel", "RewardIcon", card, {
		BackgroundTransparency = 1,
		Image = rewardArt(reward),
		ScaleType = Enum.ScaleType.Fit,
		ImageTransparency = done and 0.55 or 0,
	})
	local detail = reward.GuaranteedRare and "GUARANTEED RARE"
		or string.format("x%s %s POTION", HudFormat.Short(reward.BoostCount or 1), (reward.Boost or ""):upper())
	make("TextLabel", "RewardText", card, {
		BackgroundTransparency = 1,
		Text = detail,
		TextXAlignment = align,
		TextTransparency = done and 0.35 or 0,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	make("TextLabel", "Completion", card, {
		BackgroundTransparency = 1,
		Text = done and "✓" or "",
		TextColor3 = PALETTE.Money,
		Font = UiTheme.Font,
		TextScaled = true,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = PALETTE.PanelDeep,
	})
	return card
end

-- Inside a card (design doc 4.42), in the Index's units: 12 padding, DAY n (Item) top, reward (Caption) bottom, the icon
-- fills the rest with 8 above and below it.
local function placeCard(card, h)
	local px, at, U, size = anime.px, anime.at, AnimeSkin.Units, AnimeSkin.UnitSize
	local top = U.Pad + size.Item + U.Inner
	local iconH = math.max(0, h - top - U.Inner - size.Caption - U.Pad)
	card.Label.Position, card.Label.Size = at(U.Pad, U.Pad), UDim2.new(1, -px(2 * U.Pad), 0, px(size.Item))
	for _, icon in { card.RewardIcon, card.Completion } do
		icon.Position, icon.Size = at(U.Pad, top), UDim2.new(1, -px(2 * U.Pad), 0, px(iconH))
	end
	card.RewardText.Position = UDim2.new(0, px(U.Pad), 1, -px(U.Pad + size.Caption))
	card.RewardText.Size = UDim2.new(1, -px(2 * U.Pad), 0, px(size.Caption))
	anime.Role(card.Label, "Item")
	anime.Role(card.RewardText, "Caption")
end

-- The Daily view in the Index frame's content area (anime.Rect, px; Units in design units): days 1-6 in three columns
-- of two rows, Day 7 the fourth column at full height, CLAIM (44) the last row, 12 between. Runs on every frame layout.
local function placeDaily(rect)
	rect = rect or anime.Rect
	local area, claim = content:FindFirstChild("RewardCards"), content:FindFirstChild("Claim")
	if not (rect and area and claim) then
		return
	end
	local at, U = anime.at, AnimeSkin.Units
	content.Position, content.Size = UDim2.fromOffset(rect.X, rect.Y), UDim2.fromOffset(rect.W, rect.H)
	local W, gap = rect.Units.W, U.Gap
	local colW = (W - 3 * gap) / 4
	-- shortcut: phones (area 194 tall) cannot hold two rows of readable cards, so cards keep 140 and the area scrolls.
	local cardH = math.max((rect.Units.H - gap - U.Button - gap) / 2, 140)
	local areaH = 2 * cardH + gap
	area.Position, area.Size = UDim2.new(), at(W, areaH)
	for day = 1, #dailyConfig.Rewards do
		local card = area:FindFirstChild("Day" .. day)
		if card then
			local featured = day == #dailyConfig.Rewards
			local i = day - 1
			if featured then
				card.Position, card.Size = at(3 * (colW + gap), 0), at(colW, areaH)
			else
				card.Position, card.Size = at(i % 3 * (colW + gap), math.floor(i / 3) * (cardH + gap)), at(colW, cardH)
			end
			placeCard(card, featured and areaH or cardH)
		end
	end
	claim.Position, claim.Size = at(0, areaH + gap), at(W, U.Button)
	anime.Role(claim, "Item")
end
anime.OnDaily = placeDaily

-- The count line on the frame's footer plate: the day and the time to the next reward.
local function dailyFooter()
	local days = #dailyConfig.Rewards
	local streak = math.clamp(player:GetAttribute("DailyStreak") or 0, 0, days)
	if (player:GetAttribute("DailyLast") or -1) ~= math.floor(os.time() / 86400) then
		return string.format("DAY %d OF %d · CLAIM TODAY'S REWARD!", math.min(streak + 1, days), days)
	end
	local remaining = 86400 - (os.time() % 86400)
	return string.format(
		"DAY %d OF %d · NEXT REWARD IN %dh %02dm",
		math.max(streak, 1),
		days,
		math.floor(remaining / 3600),
		math.floor(remaining % 3600 / 60)
	)
end

local function showDaily()
	local opening = not backdrop.Visible or view ~= "Daily"
	view = "Daily"
	panelFrame:SetTheme("Daily", nil, HudIcons.Daily.Image)
	if not backdrop.Visible then
		PanelSwitch.Toggle("Daily")
	end
	backdrop.Visible = true
	refreshChrome()
	anime:SetView("Daily")
	anime:SetActive(true)
	layoutView()
	title.Text = "DAILY REWARDS • 7 DAYS"
	clearContent()
	content:FindFirstChildOfClass("UIListLayout"):Destroy() -- placeDaily sets every rect; Quests make a new one
	local streak = math.clamp(player:GetAttribute("DailyStreak") or 0, 0, 7)
	local last = player:GetAttribute("DailyLast") or -1
	local claimedToday = last == math.floor(os.time() / 86400)
	local area = make("Frame", "RewardCards", content, { BackgroundTransparency = 1 })
	for day, reward in ipairs(dailyConfig.Rewards) do
		dailyCard(area, day, reward, day <= streak, day == #dailyConfig.Rewards)
	end
	local claim = button(
		"Claim",
		content,
		UDim2.new(),
		UDim2.new(),
		claimedToday and "CLAIMED TODAY" or "CLAIM DAY " .. tostring(math.min(streak + 1, 7))
	)
	claim.Active = not claimedToday
	anime.Button(claim, claim.Active and "Go" or "Idle")
	anime:Footer(dailyFooter())
	anime:Layout()
	task.defer(function()
		anime:Layout() -- after UiTheme.Apply's and Skin.Button's deferred passes
	end)
	if opening then -- cards rise in, each a little later (section 10)
		for day = 1, #dailyConfig.Rewards do
			UiMotion.SlideIn(area["Day" .. day], Vector2.new(0, 24), 0.22 + 0.03 * day)
		end
	end
	if claim.Active then
		claim.Edge.Color = PALETTE.Speed
		stopClaimPulse = UiMotion.Pulse(claim.Edge, { Transparency = 0.75 }, 0.7)
		-- Today's tile: the same glow, so the prize waiting now is plain to see.
		local today = area:FindFirstChild("Day" .. math.min(streak + 1, 7))
		if today then
			today.Edge.Enabled = true
			UiMotion.Mark(today.Edge, { Color = PALETTE.Speed })
			stopTodayPulse = UiMotion.Pulse(today.Edge, { Transparency = 0.6 }, 0.7)
		end
		shineWhileClaimable(claim)
	end
	claim.Activated:Connect(function()
		if not claim.Active then
			return
		end
		local ok, success, reward = pcall(function()
			return ReplicatedStorage.Remotes:WaitForChild("DailyClaim"):InvokeServer()
		end)
		if ok and success then
			notify("Claimed Day " .. tostring(reward.Day))
			showDaily()
			answerCue("DailyClaim", function()
				local cards = content:FindFirstChild("RewardCards")
				return cards and cards:FindFirstChild("Day" .. tostring(reward.Day))
			end)
		else
			notify(ok and tostring(reward) or "Connection error")
			UiFeedback.Play("Denied", claim)
		end
	end)
end

local function decode(name)
	local raw = player:GetAttribute(name)
	if type(raw) ~= "string" then
		return {}
	end
	local ok, value = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return ok and type(value) == "table" and value or {}
end

-- "Luck Potion I", not the save id "LuckI".
local function rewardName(quest)
	local boost = Boosts.Get(quest.Reward)
	return boost and boost.Name or quest.Reward
end

local function selectQuest(quest, current, weekly)
	for id, refs in questRows do
		refs.Edge.Color = id == quest.Id and Color3.new(1, 1, 1) or TILE_BLUE
	end
	anime:Select(questRows, quest.Id)
	questType.Text = weekly and "WEEKLY QUEST" or "DAILY QUEST"
	questName.Text = quest.Name
	questGoal.Text = "" -- the quest's name already says its goal
	UiMotion.Fill(progressFill, UDim2.fromScale(math.clamp(current / math.max(1, quest.Target), 0, 1), 1))
	progressText.Text = string.format(
		"%s / %s  (%d%%)",
		HudFormat.Short(current),
		HudFormat.Short(quest.Target),
		math.floor(current / math.max(1, quest.Target) * 100 + 0.5)
	)
	questReward.Text = string.format(
		"REWARD  •  x%s %s  •  %s Gems",
		HudFormat.Short(quest.RewardCount or 1),
		rewardName(quest),
		HudFormat.Short(quest.Gems)
	)
end

local function showQuests()
	local opening = not backdrop.Visible or view ~= "Quests"
	view = "Quests"
	panelFrame:SetTheme("Quests", nil, HudIcons.Quests.Image)
	if not backdrop.Visible then
		PanelSwitch.Toggle("Daily")
	end
	backdrop.Visible = true
	refreshChrome()
	anime:SetView("Quests")
	anime:SetActive(true)
	layoutView()
	title.Text = "QUESTS"
	clearContent()
	questRows = {}
	for _, tab in { dailyQuestTab, weeklyQuestTab } do
		local selected = tab.Name == questCategory
		UiMotion.Mark(tab, { BackgroundColor3 = selected and TILE_BLUE or TAB })
		UiMotion.Mark(tab.Edge, { Color = selected and Color3.new(1, 1, 1) or OUTLINE })
	end
	anime:Tab(questCategory)
	local weekly = questCategory == "Weekly"
	local quests = weekly and questConfig.Weekly or questConfig.Daily
	local progress = decode(weekly and "QuestWeeklyProgress" or "QuestDailyProgress")
	local claimed = decode(weekly and "QuestWeeklyClaimed" or "QuestDailyClaimed")
	local selectedQuest, selectedCurrent = nil, 0
	local rows = {}
	local ready, claimedCount = 0, 0
	for _, quest in quests do
		local current = math.min(quest.Target, progress[quest.Id] or 0)
		local done = claimed[quest.Id] == 1
		local row = button(quest.Id, content, UDim2.new(), UDim2.new(1, -8, 0, 72), "")
		row.AutoButtonColor = false
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		UiTheme.Gradient(row, PALETTE.Row, PALETTE.PanelDeep)
		row.Edge:Destroy()
		table.insert(rows, row)
		rounded(row, 12)
		local rowEdge = Instance.new("UIStroke")
		rowEdge.Name = "Selection"
		rowEdge.Color = TILE_BLUE
		rowEdge.Thickness = 4
		rowEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rowEdge.Parent = row
		make("TextLabel", "Text", row, {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -124, 0, 24),
			BackgroundTransparency = 1,
			Text = quest.Name,
			Font = UiTheme.Font,
			TextSize = 18,
			TextColor3 = PALETTE.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		make("TextLabel", "Progress", row, {
			Position = UDim2.fromOffset(12, 38),
			Size = UDim2.new(1, -124, 0, 20),
			BackgroundTransparency = 1,
			Text = string.format(
				"%s / %s  •  %s",
				HudFormat.Short(current),
				HudFormat.Short(quest.Target),
				rewardName(quest)
			),
			Font = UiTheme.Font,
			TextSize = 15,
			TextColor3 = PALETTE.SoftText,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local claim = button(
			"Claim",
			row,
			UDim2.new(1, -106, 0.5, -18),
			UDim2.fromOffset(96, 32),
			done and "CLAIMED" or current >= quest.Target and "CLAIM" or "LOCKED"
		)
		claim.Active = not done and current >= quest.Target
		claim.BackgroundColor3 = claim.Active and GREEN or TAB
		if claim.Active then
			UiTheme.Stroke(claim, 2)
			shineWhileClaimable(claim)
		end
		questRows[quest.Id] = { Button = row, Edge = rowEdge }
		local state = done and "Claimed" or claim.Active and "Ready" or "Progress"
		anime:Row(row, state)
		ready += state == "Ready" and 1 or 0
		claimedCount += done and 1 or 0
		if not selectedQuest then
			selectedQuest, selectedCurrent = quest, current
		end
		row.Activated:Connect(function()
			selectQuest(quest, current, weekly)
		end)
		claim.Activated:Connect(function()
			if not claim.Active then
				return
			end
			local ok, success, message = pcall(function()
				return ReplicatedStorage.Remotes.QuestClaim:InvokeServer(weekly, quest.Id)
			end)
			notify(ok and (success and ("Claimed " .. rewardName(quest)) or tostring(message)) or "Connection error")
			showQuests()
			answerCue((ok and success) and "QuestClaim" or "Denied", function()
				local newRow = content:FindFirstChild(quest.Id)
				return newRow and ((ok and success) and newRow or newRow:FindFirstChild("Claim"))
			end)
		end)
	end
	anime:Footer(string.format("%d READY · %d / %d CLAIMED", ready, claimedCount, #quests))
	if selectedQuest then
		selectQuest(selectedQuest, selectedCurrent, weekly)
	end
	if opening then
		cascade(rows, "Selection")
	end
end

dailyQuestTab.Activated:Connect(function()
	if questCategory ~= "Daily" then
		UiFeedback.Play("TabSwitch")
	end
	questCategory = "Daily"
	showQuests()
end)
weeklyQuestTab.Activated:Connect(function()
	if questCategory ~= "Weekly" then
		UiFeedback.Play("TabSwitch")
	end
	questCategory = "Weekly"
	showQuests()
end)

-- The top-right Daily and Quests pills (HudChrome) share this modal; a second click on the same pill closes it.
local function action(name, show)
	return function()
		if backdrop.Visible and view == name then
			PanelSwitch.Close("Daily")
			return
		end
		show()
	end
end
PanelSwitch.SetAction("Daily", action("Daily", showDaily))
PanelSwitch.SetAction("Quests", action("Quests", showQuests))
local function closePanel()
	PanelSwitch.Close("Daily")
	refreshChrome()
end
close.Activated:Connect(closePanel)
require(script.Parent:WaitForChild("PanelFrame")).CloseOnOutsideClick(backdrop, closePanel)

refreshChrome()
task.spawn(function()
	while screen.Parent do
		refreshChrome()
		task.wait(0.05)
	end
end)

-- Design doc 4.24: a new player gets no Daily until their first run ends (ArrivalState.IsNew survives a rejoin). Sticky,
-- since a win pays MoneyEarned during that run. Nor does anyone before their save is known; a failed load holds nothing.
local newPlayer, raced, firstRunEnded = false, false, false
player:GetAttributeChangedSignal("AutoRacing"):Connect(function()
	local racing = player:GetAttribute("AutoRacing") == true
	firstRunEnded = firstRunEnded or (raced and not racing)
	raced = raced or racing
end)
local function dailyHeld()
	newPlayer = newPlayer or ArrivalState.IsNew(player)
	local unknown = player:GetAttribute("DataLoaded") ~= true and player:GetAttribute("DataFailed") ~= true
	return unknown or (newPlayer and not firstRunEnded)
end

local autoShownDay = nil
task.spawn(function()
	while screen.Parent do
		task.wait(1)
		local held = dailyHeld()
		local last = player:GetAttribute("DailyLast") or -1
		local today = math.floor(os.time() / 86400)
		if view == "Daily" and backdrop.Visible then
			anime:Footer(dailyFooter())
		end
		-- Auto-open once per UTC day: after the player closes it, only the button reopens it.
		if last ~= today and autoShownDay ~= today and not backdrop.Visible and not held then
			autoShownDay = today
			showDaily()
		end
	end
end)

-- A real resize can cross the phone line, which lays the days out differently: that one rebuilds.
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if view == "Daily" and backdrop.Visible then
			showDaily()
		end
	end)
end

-- Opens in the shared band between the HUD entries (docs/HUD_LAYOUT_SPEC.md section 6).
UiTheme.Apply(screen)
