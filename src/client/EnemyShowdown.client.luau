--!nonstrict
-- Enemy showdown banners (design doc 4.28): "VS" when a track race starts, "DEFEATED" when it is won. Display only, from
-- the events Server/RaceService sends this player (Remotes.NpcRace). Nothing here is Active, so no input is taken.
-- DisplayOrder is below the HUD and panels, so an open panel covers the banner, never the reverse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcConfig = require(Shared.NpcConfig)
local TrackRegistry = require(Shared.TrackRegistry)
local Themes = require(Shared.BiomeThemes)
local UiTheme = require(Shared.UiTheme)
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local Components = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("RacerComponents"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace")

-- All placeholders (design doc 4.28).
local BANNER_W, BANNER_H = 460, 100 -- px
local HOME = UDim2.fromScale(0.5, 0.62) -- placeholder: under the runner, above the team row
local VS_SECONDS = 1.6
local DEFEATED_SECONDS = 1.4
-- RaceService sends a win and the next track's Start in the same frame: the defeat stays this long before VS replaces it.
local DEFEATED_MIN_SECONDS = 1

local trackNames = {}
for _, spec in TrackRegistry.Chain() do
	local theme = Themes[spec.Biome]
	trackNames[spec.Number] = theme and theme.DisplayName or spec.Name -- the name players know, as BiomeWelcome shows
end

local gui = Instance.new("ScreenGui")
gui.Name = "EnemyShowdown"
gui.DisplayOrder = -1
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = HOME
banner.Size = UDim2.fromOffset(BANNER_W, BANNER_H)
banner.Visible = false
UiTheme.Plate(banner, UiTheme.Palette.Danger)
banner.Parent = gui

-- Layout scale (not MotionScale), as the loser card: phones shrink, desktop never does (design doc 4.27).
local fit = Instance.new("UIScale")
fit.Name = "FitScale"
fit.Parent = banner
local function refit()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		fit.Scale = math.min(1, (size.X - 32) / BANNER_W, size.Y / 500)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

local function line(name, y, height, textSize, color)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Position = UDim2.fromOffset(100, y)
	text.Size = UDim2.new(1, -112, 0, height)
	text.BackgroundTransparency = 1
	text.Font = UiTheme.Font
	text.TextSize = textSize
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.ZIndex = 5
	UiTheme.Stroke(text, 2)
	text.Parent = banner
	return text
end

local vs = line("Vs", 8, 26, 24, UiTheme.Palette.Danger)
vs.Text = "VS"
vs.Visible = false
local defeated = line("Defeated", 8, 26, 24, UiTheme.Palette.Money)
defeated.Text = "DEFEATED!"
defeated.Visible = false
local enemyName = line("EnemyName", 34, 34, 30, UiTheme.Palette.White)
local trackName = line("TrackName", 70, 22, 16, UiTheme.Palette.Unbanked)

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
refit()

local portrait = nil
local function setPortrait(model)
	if portrait then
		portrait:Destroy()
	end
	-- foe_ ids are model names, not catalog entries; both helpers take either
	portrait = Components.PortraitArt(
		banner,
		"Portrait",
		{ Id = model },
		UDim2.fromOffset(8, 8),
		UDim2.fromOffset(84, 84),
		true
	)
end

local FADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function fade(title, shown)
	for _, part in { banner, title, enemyName, trackName } do
		UiMotion.Fade(part, shown, 0.2)
	end
	if shown then
		portrait.ImageTransparency = UiMotion.Reduced() and 0 or 1
	end
	UiMotion.Create(portrait, FADE, { ImageTransparency = shown and 0 or 1 }):Play()
end

local shownToken = 0 -- bumps per banner, so an older banner's timed fade-out never hides a newer one
local pending = nil -- the latest event held back while the banner is locked
local lockedUntil = 0 -- os.clock(): a defeat's minimum time, or the loser screen

local show

local function lock(seconds)
	lockedUntil = os.clock() + seconds
	task.delay(seconds, function()
		if pending and os.clock() >= lockedUntil then
			local event = pending
			pending = nil
			show(event)
		end
	end)
end

function show(event)
	shownToken += 1
	local mine = shownToken
	local won = event.Type == "Result"
	local info = NpcConfig.For(event.Track)
	local title = won and defeated or vs
	vs.Visible = false
	defeated.Visible = false
	enemyName.Text = info.Label
	trackName.Text = ("TRACK %d · %s"):format(event.Track, trackNames[event.Track])
	setPortrait(info.Model)
	banner.Position = HOME -- a banner replaced mid-slide must not start from the old one's position
	fade(title, true)
	UiMotion.SlideIn(banner, Vector2.new(0, -24), 0.2)
	if won then
		lock(DEFEATED_MIN_SECONDS)
	end
	task.delay(won and DEFEATED_SECONDS or VS_SECONDS, function()
		if shownToken == mine then
			fade(title, false)
		end
	end)
end

local function clear()
	pending = nil
	shownToken += 1
	banner.Visible = false
end

remote.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then
		return
	end
	if event.Type == "Start" or (event.Type == "Result" and event.Result == "Win") then
		if trackNames[event.Track] then
			if os.clock() < lockedUntil then
				pending = event
			else
				show(event)
			end
		end
	elseif event.Type == "Result" and event.Result == "Lose" then
		clear()
		lock(NpcConfig.LOSE_SCREEN_SECONDS) -- no banner over the loser screen; the Start behind it shows afterwards
	elseif event.Type == "Stop" then
		clear()
		lockedUntil = 0
	end
end)
