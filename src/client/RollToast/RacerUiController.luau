--!nonstrict
-- Bind saved UI; all economy, ownership and allocation decisions stay on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared.UiTheme)
local palette = UiTheme.Palette
local catalog = require(Shared.CharacterCatalog)
local config = require(Shared.GachaConfig)
local format = require(Shared.HudFormat)
local RaceConfig = require(Shared.RaceConfig)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- There is only one supported HUD. Remove baked copies from older Studio
-- places before binding the current generated UI, including copies cloned on
-- a later respawn from an old StarterGui.
local legacyNames = { "AutoRaceButton", "SpeedHud", "StatsUi", "RollUi", "IndexUi", "RacerHudConcept" }
local function removeLegacy(child)
	if table.find(legacyNames, child.Name) then
		child:Destroy()
	end
end
for _, name in legacyNames do
	local legacy = playerGui:FindFirstChild(name)
	if legacy then
		legacy:Destroy()
	end
end
playerGui.ChildAdded:Connect(removeLegacy)
local Ui = script.Parent:WaitForChild("Ui")
local Components = require(Ui.RacerComponents)
local HudButtonStyle = require(Ui.HudButtonStyle)
require(Ui.RacerMotion).Attach(playerGui)
local client = script.Parent:IsA("LocalScript") and script.Parent.Parent or script.Parent
local PanelSwitch = require(client.PanelSwitch)
local UiMotion = require(client.UiMotion)
local UiFeedback = require(client.UiFeedback)
local PanelBand = require(client.PanelBand)
local PanelFrame = require(client.PanelFrame)
local AnimeSkin = require(client:WaitForChild("AnimeSkin"))
local NpcConfig = require(Shared.NpcConfig)
local BossWaitCamera = require(client.BossWaitCamera)
local RunnerVisual = require(client.RunnerVisual)
local hud = require(Ui.RacerHud).Bind(playerGui)
require(client.RaceProgressMap).Attach(hud)
-- The saved HUD asset predates the session-local free-points badge. Bake the
-- small badge at runtime so the live HUD and UiSpec share the same contract.
Components.BakeHud(hud)
-- The discovery panel is intentionally cars-only; holdables live in the separate Bag control.
if hud.IndexLabel then
	hud.IndexLabel.Text = "INDEX"
end
-- Uploaded HUD art shares an atlas; keep the individual icon crops when binding.
hud.MoneyIcon.ImageRectOffset = Vector2.new(0, 0)
hud.MoneyIcon.ImageRectSize = Vector2.new(256, 256)
hud.MoneyValue.TextXAlignment = Enum.TextXAlignment.Left
hud.Unbanked.TextXAlignment = Enum.TextXAlignment.Left
-- Read-out look (docs/HUD_LAYOUT_SPEC.md section 9): Money plate, gradient numbers.
UiTheme.Plate(hud.MoneyPlate, palette.MoneyDeep)
UiTheme.Gradient(hud.MoneyValue, Color3.fromRGB(190, 255, 170), palette.MoneyDeep)
UiTheme.Gradient(hud.Unbanked, Color3.fromRGB(255, 240, 150), palette.UnbankedDeep)
hud.MoneyValue.TextColor3 = Color3.new(1, 1, 1)
hud.Unbanked.TextColor3 = Color3.new(1, 1, 1)
-- Gems read-out (design doc 4.35): a new plate just above the Money plate; RacerHud is generated, so it is built here.
local GEM, GEM_DEEP = Color3.fromRGB(150, 235, 255), Color3.fromRGB(50, 130, 255)
local gemsPlate = UiTheme.Plate(Instance.new("Frame"), GEM_DEEP)
gemsPlate.Name = "Gems"
gemsPlate.AnchorPoint = Vector2.new(0, 1)
gemsPlate.Parent = hud.Gui
local gemIcon = Instance.new("ImageLabel")
gemIcon.Name = "GemIcon"
gemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
gemIcon.Position = UDim2.fromScale(0.17, 0.5)
gemIcon.Size = UDim2.fromScale(0.8, 0.8)
gemIcon.SizeConstraint = Enum.SizeConstraint.RelativeYY
gemIcon.BackgroundTransparency = 1
gemIcon.Image = require(Ui.HudIcons).Gem.Image
gemIcon.ZIndex = 3
gemIcon.Parent = gemsPlate
local gemsValue = Instance.new("TextLabel")
gemsValue.Name = "GemsValue"
gemsValue.Position = UDim2.fromScale(0.33, 0.1)
gemsValue.Size = UDim2.fromScale(0.62, 0.8)
gemsValue.BackgroundTransparency = 1
gemsValue.Font = UiTheme.Font
gemsValue.TextSize = 26
gemsValue.TextColor3 = Color3.new(1, 1, 1)
gemsValue.TextXAlignment = Enum.TextXAlignment.Left
gemsValue.Text = "0"
gemsValue.ZIndex = 3
UiTheme.Gradient(gemsValue, GEM, GEM_DEEP)
UiTheme.Stroke(gemsValue, 2, Color3.fromRGB(18, 22, 43))
gemsValue.Parent = gemsPlate
-- Follows the Money plate's desktop and phone layouts, so it needs no phone branch of its own.
local function placeGems()
	local plate = hud.MoneyPlate
	local width, height = plate.Size.X.Offset, plate.Size.Y.Offset
	gemsPlate.Size = UDim2.fromOffset(width * 0.62, height * 0.38)
	gemsPlate.Position = UDim2.new(
		0,
		hud.Money.Position.X.Offset + plate.Position.X.Offset,
		1,
		hud.Money.Position.Y.Offset - hud.Money.Size.Y.Offset + plate.Position.Y.Offset - 4
	)
end
-- Owner 2026-11-01: the speedometer and the cruise read-out are removed from the HUD.
hud.Speed:Destroy()
local index = require(Ui.RacerIndex).Bind(playerGui)
local stats = require(Ui.RacerStats).Bind(playerGui)
local settings = require(Ui.RacerSettings).Bind(playerGui)
local rebirth = require(Ui.RacerRebirth).Bind(playerGui)
local rebirthConfig = require(Shared.RebirthConfig)
-- FredokaOne and token radii on the code-built parts inside the generated screens too (HUD_LAYOUT_SPEC section 8).
for _, refs in { hud, index, stats, settings, rebirth } do
	UiTheme.Apply(refs.Gui)
end
-- Catalog additions extend the saved gallery without waiting forever for an old seven-car bake.
local gallery = index.GridHost:FindFirstChild("Gallery")
local rebuildGallery = gallery == nil or gallery:GetAttribute("DesignVersion") ~= 2
for _, spec in catalog.All() do
	local baked = gallery and gallery:FindFirstChild(spec.Id)
	local art = baked and baked:FindFirstChild("Art")
	local image = Components.PortraitImage(spec)
	-- A saved bake from before an upload holds the wrong Art.
	local current = art and (if image then art:IsA("ImageLabel") and art.Image == image else art:IsA("ViewportFrame"))
	rebuildGallery = rebuildGallery or not current
end
if rebuildGallery then
	if gallery then
		gallery:Destroy()
	end
	Components.BakeIndex(index, catalog, config)
end
local statsRows = stats.StatsHost:FindFirstChild("Rows")
local rebuildStats = statsRows == nil or statsRows:GetAttribute("DesignVersion") ~= 2
if statsRows then
	for _, stat in config.STATS do
		if not statsRows:FindFirstChild(stat) then
			rebuildStats = true
			break
		end
	end
end
if rebuildStats then
	if statsRows then
		statsRows:Destroy()
	end
	Components.BakeStats(stats, config)
end
local tiles = Components.BindIndex(index, catalog)
local rows = Components.BindStats(stats, config)
local data = player:WaitForChild("GachaData")
local leaderstats = player:WaitForChild("leaderstats")
-- The current cruise, studs/s (player attribute Cruise, set by the server; there is no Speed stat, design doc 4.13)
local function cruise()
	local v = player:GetAttribute("Cruise")
	return type(v) == "number" and v == v and v or 0
end
local money = leaderstats:WaitForChild("Money")
local GREEN = palette.Money
local GRAY = palette.Muted
local sessionStartedAt = os.time()

local function formatDuration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local hours = seconds // 3600
	local minutes = (seconds // 60) % 60
	local remainder = seconds % 60
	return hours > 0 and string.format("%dh %02dm", hours, minutes) or string.format("%dm %02ds", minutes, remainder)
end

local function bestRolledCar()
	local best
	for _, spec in catalog.All() do
		if data and data:FindFirstChild(spec.Id) and (not best or (spec.Chance or 0) > (best.Chance or 0)) then
			best = spec
		end
	end
	return best
end

-- Roll entry is the compact animation at the top centre of the screen. The old
-- bottom roll controls and Settings auto-roll row are intentionally hidden.
-- Generated responsive fits reapply authored visibility on viewport changes.
-- Keep the retired entry points hidden throughout those fits. INDEX / STATS / REBIRTH and the Settings gear
-- moved to the HudChrome icon grid and top-right pills (docs/HUD_LAYOUT_SPEC.md).
for _, retired in { hud.RollControls, hud.Gui:FindFirstChild("Navigation"), hud.Gui:FindFirstChild("Settings") } do
	retired.Visible = false
	retired:GetPropertyChangedSignal("Visible"):Connect(function()
		if retired.Visible then
			retired.Visible = false
		end
	end)
end
settings.AutoRow.Visible = true

-- TRACK CAMERA row (docs/CAMERA_SPEC.md): a copy of the generated AutoRow; indexFrame places every Settings row.
-- shortcut: built at runtime because the generated RacerSettings has no spec in this repo; move it into the UI spec when one exists.
local trackCameraRow = settings.AutoRow.Parent:Clone()
-- AUTO SELL row (design doc 4.36), built the same way. Its toggle opens the popup.
local autoSellRow = settings.AutoRow.Parent:Clone()
autoSellRow.Name = "AutoSellRow"
for _, d in autoSellRow:GetDescendants() do
	d.Name = string.gsub(d.Name, "^Auto", "AutoSell")
end
autoSellRow.Parent = settings.AutoRow.Parent.Parent
settings.AutoSellRow = autoSellRow.Face
settings.AutoSellName = settings.AutoSellRow.AutoSellName
settings.AutoSellToggle = settings.AutoSellRow.AutoSellToggle.Face
trackCameraRow.Name = "TrackCameraRow"
for _, d in trackCameraRow:GetDescendants() do
	d.Name = string.gsub(d.Name, "^Auto", "TrackCamera")
end
trackCameraRow.Parent = settings.AutoRow.Parent.Parent
settings.TrackCameraRow = trackCameraRow.Face
settings.TrackCameraName = settings.TrackCameraRow.TrackCameraName
settings.TrackCameraToggle = settings.TrackCameraRow.TrackCameraToggle.Face

hud.Gui.DisplayOrder = 1
local racerPanels = { Index = index, Stats = stats, Settings = settings, Rebirth = rebirth }
for name, refs in pairs(racerPanels) do
	refs.Gui.DisplayOrder = 2
	refs.Panel.Parent.Visible = false
	refs.Gui.Enabled = true
	PanelSwitch.Register(name, refs.Panel.Parent)
	local function closePanel()
		PanelSwitch.Close(name)
	end
	refs.Close.Activated:Connect(closePanel)
	PanelFrame.CloseOnOutsideClick(refs.Panel.Parent, closePanel)
	-- The shared look (PanelFrame.PaintGenerated); Rebirth, Stats and Settings then take the Index frame (indexFrame).
	PanelFrame.PaintGenerated({
		Panel = refs.Panel,
		Header = refs.Header,
		Close = refs.Close,
		CloseLabel = refs.CloseLabel,
		Theme = name,
	})
end

local function label(button, value)
	HudButtonStyle.SetCaption(button, value)
end

-- Settings look (docs/HUD_LAYOUT_SPEC.md section 4): every toggle an ON / OFF
-- pill on a dark track (green ON on the right, muted OFF on the left: off is no error). The whole track stays the hitbox.
local function switch(toggle, on)
	local knob = toggle:FindFirstChild("Knob")
	if not knob then
		knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.Size = UDim2.fromScale(0.6, 1)
		knob.BorderSizePixel = 0
		knob.ZIndex = 3
		Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 10)
		local edge = Instance.new("UIStroke")
		edge.Thickness, edge.Color = 3, UiTheme.Outline
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = knob
		knob.Parent = toggle
		local caption = toggle:FindFirstChild(toggle.Parent.Name .. "Label")
		if caption then
			caption.Parent = knob
			caption.ZIndex = 4
			caption.AnchorPoint = Vector2.zero
			caption.Position, caption.Size = UDim2.new(), UDim2.fromScale(1, 1) -- fills the knob: "OFF" never clips
			caption.TextXAlignment = Enum.TextXAlignment.Center
			caption.TextTruncate = Enum.TextTruncate.None
		end
		local lift = toggle:FindFirstChild("Lift")
		if lift then
			lift.Visible = false
		end
		Components.Tint(toggle, Color3.fromRGB(16, 16, 20))
	end
	UiMotion.Mark(knob, { Position = on and UDim2.fromScale(0.4, 0) or UDim2.fromScale(0, 0) })
	AnimeSkin.Button(knob, on and "Go" or "Idle")
	local caption = knob:FindFirstChildWhichIsA("TextLabel")
	if caption then
		caption.Text = on and "ON" or "OFF"
		caption.TextScaled = true -- "OFF" fits the knob at every size (UI audit: "OF" clipped)
		caption.TextTruncate = Enum.TextTruncate.None
	end
	toggle:SetAttribute("On", on)
end
settings.Title.Text = "SETTINGS" -- the header (logo, title, close) is laid out by indexFrame below

-- Settings owns the read-only Player Profile category from the reference. The
-- separate Stats panel remains exclusively for spending rebirth/index points.
local categoryTabs = Instance.new("Frame")
categoryTabs.Name = "CategoryTabs"
categoryTabs.BackgroundTransparency = 1 -- placed in the tabs row by indexFrame
categoryTabs.ZIndex = 6
categoryTabs.Parent = settings.Header
local categoryLayout = Instance.new("UIListLayout")
categoryLayout.FillDirection = Enum.FillDirection.Horizontal
categoryLayout.VerticalAlignment = Enum.VerticalAlignment.Center
categoryLayout.Padding = UDim.new(0, 8) -- the Index's tab gap
categoryLayout.Parent = categoryTabs

local function categoryButton(name, text, width, parent)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(width, 38)
	button.BackgroundColor3 = palette.PanelDeep
	button.AutoButtonColor = false
	button.Font = UiTheme.Font
	button.Text = text
	button.TextSize = 14
	button.TextColor3 = Color3.new(1, 1, 1)
	button.ZIndex = 7
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	local edge = Instance.new("UIStroke")
	edge.Name = "Outline"
	edge.Color = UiTheme.Outline
	edge.Thickness = 2
	edge.Parent = button
	button.Parent = parent
	return button
end
-- Design doc 4.42: an art tab; returns its lit setter. The flat outline would stroke the hidden text.
local function animeTab(button, art)
	local setLit = AnimeSkin.Tab(button, art)
	button.Outline.Enabled = false
	return setLit
end

local settingsTab = categoryButton("SettingsTab", "SETTINGS", 84, categoryTabs)
local profileTab = categoryButton("ProfileTab", "PLAYER PROFILE", 136, categoryTabs)
local settingsTabLit, profileTabLit = animeTab(settingsTab, 1), animeTab(profileTab, 2)
local profileHost = Instance.new("ScrollingFrame")
profileHost.Name = "PlayerProfile"
profileHost.BackgroundTransparency = 1 -- placed in the content area by indexFrame
profileHost.BorderSizePixel = 0
profileHost.ScrollBarThickness = 5
profileHost.ScrollBarImageColor3 = palette.Muted
profileHost.CanvasSize = UDim2.new()
profileHost.AutomaticCanvasSize = Enum.AutomaticSize.Y
profileHost.ScrollingDirection = Enum.ScrollingDirection.Y
profileHost.ClipsDescendants = true
profileHost.Visible = false
profileHost.ZIndex = 3
profileHost.Parent = settings.Panel
local profileLayout = Instance.new("UIListLayout")
profileLayout.SortOrder = Enum.SortOrder.LayoutOrder
profileLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
profileLayout.Parent = profileHost

local profileRows = {
	{ "TotalRolls", "TOTAL ROLLS", "0" },
	{ "BestRoll", "BEST ROLL", "1 in ?" },
	{ "CharactersDiscovered", "DISCOVERED", "0" },
	{ "Speed", "CRUISE", "0 studs/s" },
	{ "Luck", "LUCK STAT", "x1.00" },
	{ "SessionTime", "TIME THIS SESSION", "0m 00s" },
}
local profileValues = {}
local profileLabels = {} -- row -> { Name, Value }
for order, spec in profileRows do
	local row = Instance.new("Frame")
	row.Name = spec[1]
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.ZIndex = 3
	AnimeSkin.Plate(row) -- design doc 4.42: a slanted plate like the Settings rows; indexFrame sizes it
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Text = spec[2]
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.ZIndex = 4
	name.Parent = row
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Text = spec[3]
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.ZIndex = 4
	value.Parent = row
	row.Parent = profileHost
	profileValues[spec[1]] = value
	profileLabels[row] = { name, value }
end

local settingsCategory = "Settings"
local function setSettingsCategory(category)
	settingsCategory = category == "Profile" and "Profile" or "Settings"
	local showSettings = settingsCategory == "Settings"
	settings.SoundRow.Parent.Visible = showSettings
	settings.EffectsRow.Parent.Visible = showSettings
	settings.AutoRow.Parent.Visible = showSettings
	settings.TrackCameraRow.Parent.Visible = showSettings
	settings.AutoSellRow.Parent.Visible = showSettings
	profileHost.Visible = not showSettings
	settingsTabLit(showSettings)
	profileTabLit(not showSettings)
	settings.Gui:SetAttribute("Category", settingsCategory)
end
settingsTab.Activated:Connect(function()
	setSettingsCategory("Settings")
	UiFeedback.Play("TabSwitch")
end)
profileTab.Activated:Connect(function()
	setSettingsCategory("Profile")
	UiFeedback.Play("TabSwitch")
end)
settings.Panel.Parent:GetPropertyChangedSignal("Visible"):Connect(function()
	if settings.Panel.Parent.Visible then
		setSettingsCategory("Settings")
	end
end)
setSettingsCategory("Settings")

local function refreshProfile()
	local allocations = {}
	for _, stat in config.STATS do
		allocations[stat] = player:GetAttribute("Alloc_" .. stat) or 0
	end
	local multis = config.Multis(allocations)
	local best = bestRolledCar()
	profileValues.TotalRolls.Text = format.SpeedText(player:GetAttribute("Rolls") or 0)
	profileValues.BestRoll.Text = format.Odds(best and best.Chance)
	profileValues.CharactersDiscovered.Text = format.SpeedText(#data:GetChildren())
	profileValues.Speed.Text = format.RateText(cruise())
	profileValues.Luck.Text = format.Multi(multis.Luck) .. string.format(" · %d pts", allocations.Luck)
	profileValues.SessionTime.Text = formatDuration(os.time() - sessionStartedAt)
end
for _, attr in { "Rolls", "Alloc_Luck" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshProfile)
end
data.ChildAdded:Connect(refreshProfile)
data.ChildRemoved:Connect(refreshProfile)
player:GetAttributeChangedSignal("Cruise"):Connect(refreshProfile)
refreshProfile()
task.spawn(function()
	while player.Parent do
		task.wait(1)
		refreshProfile()
	end
end)

-- Rebirth panel (docs/REBIRTH_SPEC.md): the generated layout shows the reset warning, the next rebirth's rewards
-- and the Money requirement (design doc 4.14); the server decides the rebirth, this only displays its numbers and replies.
local function multiplierText(value)
	return format.Multi(value)
end
rebirth.PointRewardCaption.Text = string.format(
	rebirthConfig.POINTS_PER_REBIRTH == 1 and "+%d Stat Point" or "+%d Stat Points",
	rebirthConfig.POINTS_PER_REBIRTH
)
-- The place's saved StarterGui copy still says "Money and Speed"; Rebirth resets only Money (design doc 4.14)
rebirth.WarningText.Text = "Rebirth resets your Money (Robux purchases stay)"
-- These are the next rebirth's rewards, not unlocked ones.
rebirth.RewardsTitle.Text = "NEXT REBIRTH"
rebirth.Title.Text = "REBIRTH"
stats.Title.Text = "STATS"

-- Stats is a category of the Rebirth panel (design doc 4.40): two generated panels, one tab strip in each. The strip
-- stays a child of the header face (UI tests pin the path); indexFrame places it in the tabs row under the header.
local statsTabBadges = {}
local function rebirthTabs(refs, selected)
	local strip = Instance.new("Frame")
	strip.Name = "RebirthTabs"
	strip.BackgroundTransparency = 1
	strip.ZIndex = 6
	strip.Parent = refs.Header
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8) -- the Index's tab gap
	layout.Parent = strip
	for order, tab in { { "RebirthTab", "REBIRTH", "Rebirth" }, { "StatsTab", "STATS", "Stats" } } do
		local button = categoryButton(tab[1], tab[2], 96, strip)
		button.LayoutOrder = order
		animeTab(button, order)(tab[3] == selected)
		button.Activated:Connect(function()
			if tab[3] ~= selected then
				UiFeedback.Play("TabSwitch")
				PanelSwitch.Toggle(tab[3])
			end
		end)
		if tab[3] == "Stats" then
			local badge = Instance.new("TextLabel")
			badge.Name = "Badge"
			badge.AnchorPoint = Vector2.new(0.5, 0.5)
			badge.Position = UDim2.new(1, -4, 0, 4)
			badge.BackgroundColor3 = palette.Danger
			badge.Font = UiTheme.Font
			badge.TextColor3 = Color3.new(1, 1, 1)
			badge.ZIndex = 8
			badge.Visible = false
			Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
			badge.Parent = button
			table.insert(statsTabBadges, badge)
		end
	end
end
rebirthTabs(rebirth, "Rebirth")
rebirthTabs(stats, "Stats")
-- The HUD tile answers for the whole panel: it closes it from either tab.
PanelSwitch.SetAction("Rebirth", function()
	if PanelSwitch.IsOpen("Stats") then
		PanelSwitch.Close("Stats")
	else
		PanelSwitch.Toggle("Rebirth")
	end
end)
-- The Rebirth moment's title. Hidden at rest, never Active; no number, so nothing here can run ahead of the server.
local rebirthSlam = Instance.new("TextLabel")
rebirthSlam.Name = "RebirthSlam"
rebirthSlam.AnchorPoint = Vector2.new(0.5, 0.5)
rebirthSlam.Position = UDim2.fromScale(0.5, 0.16)
rebirthSlam.Size = UDim2.fromScale(0.8, 0.2)
rebirthSlam.BackgroundTransparency = 1
rebirthSlam.Font = UiTheme.Font
rebirthSlam.Text = "REBIRTH!"
rebirthSlam.TextScaled = true
rebirthSlam.TextColor3 = palette.Gold
rebirthSlam.Visible = false
rebirthSlam.ZIndex = 20
UiTheme.Stroke(rebirthSlam, 4)
rebirthSlam.Parent = rebirth.Gui
local rebirthSlamToken = 0
local function playRebirthMoment()
	rebirthSlamToken += 1
	local token = rebirthSlamToken
	UiMotion.Fade(rebirthSlam, true, 0.05)
	UiFeedback.Play("Rebirth", rebirthSlam)
	task.delay(1.4, function() -- placeholder
		if rebirthSlamToken == token then
			UiMotion.Fade(rebirthSlam, false, 0.25)
		end
	end)
end
-- The reply ("REBIRTH COMPLETE", a server message) is wider than the button at its resting size: it shrinks to fit.
-- indexFrame gives it the Item role (scaled, at most the token size).
local rebirthCaption = rebirth.RebirthButton:FindFirstChild("RebirthButtonLabel", true)
local rebirthBusy, rebirthReply = false, nil
local function refreshRebirth()
	local level = player:GetAttribute("RebirthLevel") or 0
	local nextMultiplier = rebirthConfig.NextMultiplier(level)
	rebirth.LuckRewardCaption.Text = multiplierText(nextMultiplier) .. " Luck"
	rebirth.SpeedRewardCaption.Text =
		string.format("+%d%% Speed", math.floor(rebirthConfig.SpeedBonus(level + 1) * 100 + 0.5))
	local required = rebirthConfig.Requirements(level).Money
	local maxed = level >= rebirthConfig.MAX_LEVEL
	local eligible = not maxed and rebirthConfig.CanRebirth(level, money.Value)
	rebirth.BarText.Text = maxed and "MAX REBIRTH"
		or string.format("%s / %s", format.MoneyText(money.Value), format.MoneyText(required))
	UiFeedback.Play("RebirthBar", nil, {
		Bar = rebirth.Fill,
		Goal = UDim2.fromScale(maxed and 1 or math.clamp(money.Value / required, 0, 1), 1),
	})
	local active = eligible and not rebirthBusy
	rebirth.RebirthButton.Active = active
	label(rebirth.RebirthButton, rebirthReply or (maxed and "MAX" or "REBIRTH"))
	AnimeSkin.Button(rebirth.RebirthButton, active and "Go" or "Idle")
end
rebirth.RebirthButton.Activated:Connect(function()
	if not rebirth.RebirthButton.Active or rebirthBusy then
		return
	end
	rebirthBusy = true
	refreshRebirth()
	local ok, success, message = pcall(function()
		return remotes:WaitForChild("Rebirth"):InvokeServer()
	end)
	rebirthReply = ok and (success and "REBIRTH COMPLETE" or tostring(message)) or "Connection error"
	rebirthBusy = false
	refreshRebirth()
	if ok and success then
		playRebirthMoment()
	end
	local shown = rebirthReply
	task.delay(2.5, function()
		if rebirthReply == shown then
			rebirthReply = nil
			refreshRebirth()
		end
	end)
end)
player:GetAttributeChangedSignal("RebirthLevel"):Connect(refreshRebirth)
money.Changed:Connect(refreshRebirth)
refreshRebirth()

-- The former Settings auto-roll row is now the local top-down camera toggle.
local function refreshTopDown()
	local on = player:GetAttribute("TopDownView") == true
	label(settings.AutoName, "TOP-DOWN VIEW")
	switch(settings.AutoToggle, on)
end
settings.AutoToggle.Activated:Connect(function()
	player:SetAttribute("TopDownView", player:GetAttribute("TopDownView") ~= true)
	refreshTopDown()
	UiFeedback.Play("Toggle")
end)
refreshTopDown()

-- Track camera (docs/CAMERA_SPEC.md): LocalPlayer attribute TrackCamera, session-local like TopDownView; unset = ON.
local function refreshTrackCamera()
	label(settings.TrackCameraName, "TRACK CAMERA")
	switch(settings.TrackCameraToggle, player:GetAttribute("TrackCamera") ~= false)
end
-- AUTO SELL row (design doc 4.36): the toggle shows the setting and opens the popup, where N is typed.
label(settings.AutoSellName, "AUTO SELL")
local function refreshAutoSellRow()
	switch(settings.AutoSellToggle, player:GetAttribute("AutoSell") == true)
end
player:GetAttributeChangedSignal("AutoSell"):Connect(refreshAutoSellRow)
refreshAutoSellRow()
settings.AutoSellToggle.Activated:Connect(require(script.Parent.Parent:WaitForChild("RollOptions")).OpenAutoSell)
settings.TrackCameraToggle.Activated:Connect(function()
	player:SetAttribute("TrackCamera", player:GetAttribute("TrackCamera") == false)
	refreshTrackCamera()
	UiFeedback.Play("Toggle")
end)
refreshTrackCamera()

-- Optional bird's-eye camera for auto racing. Mouse-wheel zoom changes the
-- camera height, keeping the car visible from above instead of using a chase
-- camera. The normal Roblox camera is restored when auto racing ends.
local topDownHeight = 48
local TOP_DOWN_MIN = 22
local TOP_DOWN_MAX = 110
local topDownWasActive = false
local savedCameraSubject, savedFieldOfView

local function restoreTopDownCamera(camera)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local wasScripted = topDownWasActive or camera.CameraType == Enum.CameraType.Scriptable
	topDownWasActive = false
	if wasScripted then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid or savedCameraSubject
	end
	if wasScripted and savedFieldOfView then
		camera.FieldOfView = savedFieldOfView
	end
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and player:GetAttribute("TopDownView") == true then
		topDownHeight = math.clamp(topDownHeight - input.Position.Z * 6, TOP_DOWN_MIN, TOP_DOWN_MAX)
	end
end)

-- The local player's visible runner while auto racing (Client/RunnerView), or nil.
local function autoRaceCar()
	local model = RunnerVisual.LocalRunner()
	return model and model:GetAttribute("AutoRace") and model or nil
end

RunService.RenderStepped:Connect(function(dt)
	if BossWaitCamera.Held() then
		return -- the exhaustion view holds the camera Scriptable, and gives it back as it found it
	end
	local camera = workspace.CurrentCamera
	local autoRacing = player:GetAttribute("AutoRacing") == true
	-- A boss event locks its view (design doc 4.37), whatever the saved top-down setting.
	local topDown = player:GetAttribute("TopDownView") == true and player:GetAttribute("BossEvent") ~= true
	local car = autoRacing and topDown and autoRaceCar() or nil
	if car and camera then
		if not topDownWasActive then
			topDownWasActive = true
			savedCameraSubject = camera.CameraSubject
			savedFieldOfView = camera.FieldOfView
		end
		local target = car:GetPivot().Position + Vector3.new(0, 2, 0)
		local desired = CFrame.lookAt(target + Vector3.new(0, topDownHeight, 0), target)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 55
		camera.CFrame = camera.CFrame:Lerp(desired, 1 - 0.84 ^ (dt * 60)) -- same feel as 0.16 per frame at 60 fps, at any fps
	elseif camera and (topDownWasActive or not autoRacing) then
		restoreTopDownCamera(camera)
	end
end)

player:GetAttributeChangedSignal("AutoRacing"):Connect(function()
	if player:GetAttribute("AutoRacing") ~= true then
		local camera = workspace.CurrentCamera
		if camera then
			restoreTopDownCamera(camera)
		end
	end
end)

hud.Index.Activated:Connect(function()
	PanelSwitch.Toggle("Index")
end)
hud.Stats.Activated:Connect(function()
	PanelSwitch.Toggle("Stats")
end)
hud.Settings.Activated:Connect(function()
	PanelSwitch.Toggle("Settings")
end)
hud.Rebirth.Activated:Connect(function()
	PanelSwitch.Toggle("Rebirth")
end)
UserInputService.InputBegan:Connect(function(input, consumed)
	if not consumed and input.KeyCode == Enum.KeyCode.Escape then
		for _, name in ipairs({ "Index", "Stats", "Settings", "Rebirth" }) do
			PanelSwitch.Close(name)
		end
	end
end)

local function refreshIndex()
	local team = string.split(player:GetAttribute("Team") or "", ",")
	local count = 0
	for id, tile in pairs(tiles) do
		local owned = data:FindFirstChild(id) ~= nil
		tile.Frame:SetAttribute("Owned", owned)
		tile.Name.Text = owned and tile.Spec.Name or "???"
		tile.Art.ImageColor3 = owned and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		tile.Locked.Visible = not owned
		tile.Info.Text = owned and format.RateText(RaceConfig.Cruise(tile.Spec)) or tile.Spec.Rarity
		-- No Equip row on an undiscovered card: its rarity and name drop to the bottom edge.
		tile.Info.Position = UDim2.new(0, 8, 1, owned and -78 or -48)
		tile.Name.Position = UDim2.new(0, 8, 1, owned and -62 or -32)
		tile.Category.Visible = owned
		Components.TintCard(tile.Frame, tile.Spec, config, owned)
		tile.Equip.Visible = owned
		local on = table.find(team, id) ~= nil -- design doc 4.22: green = on the Team, in any of its 3 slots
		tile.Stroke.Color = on and GREEN or UiTheme.Outline
		-- Design doc 4.2: single equip moves to slot 1 and the server swaps, so only slot 1 has nothing left to do.
		local first = team[1] == id
		tile.Equip.Active = owned and not first
		tile.Equip.Selectable = owned and not first
		Components.Tint(tile.Equip, first and GRAY or GREEN)
		tile.Equip.Label.Text = first and "IN TEAM" or "EQUIP"
		if owned then
			count += 1
		end
	end
	if index.Gui:GetAttribute("InventoryTab") == "Enemies" then
		local total = #NpcConfig.Tracks
		index.IndexProgress.Text =
			string.format("%d / %d DEFEATED", math.clamp(player:GetAttribute("BestTrack") or 0, 0, total), total)
		return
	end
	if index.Gui:GetAttribute("InventoryTab") == "Sidekicks" then
		index.IndexProgress.Text = index.Gui:GetAttribute("SidekicksProgress") or ""
		return
	end
	if index.Gui:GetAttribute("InventoryTab") == "Relics" then
		index.IndexProgress.Text = index.Gui:GetAttribute("RelicsProgress") or ""
		return
	end
	index.IndexProgress.Text = string.format(
		"%d / %d DISCOVERED · NEXT POINT IN %d",
		count,
		#catalog.All(),
		config.DISCOVERIES_PER_POINT - count % config.DISCOVERIES_PER_POINT
	)
end
local EQUIP_ANSWER_SECONDS = 3 -- placeholder: a press the server has not answered by then was refused
local pressedEquip, pressedUntil = nil, 0
for id, tile in pairs(tiles) do
	tile.Equip.Activated:Connect(function()
		if tile.Equip.Active and data:FindFirstChild(id) then
			pressedEquip, pressedUntil = id, os.clock() + EQUIP_ANSWER_SECONDS
			remotes.EquipCar:FireServer(id)
		end
	end)
end
-- The Equip cue is the server's yes, so a refusal plays none. On the card: a tile that lands on slot 1 turns its button
-- disabled, and a disabled button does not move (design doc 4.20).
local function equipAnswered()
	local id = pressedEquip
	if id and os.clock() > pressedUntil then
		pressedEquip = nil
	elseif
		id
		and (player:GetAttribute("EquippedCar") == id or string.split(player:GetAttribute("Team") or "", ",")[1] == id)
	then
		pressedEquip = nil
		UiFeedback.Play("Equip", tiles[id].Frame)
	end
end
player:GetAttributeChangedSignal("EquippedCar"):Connect(equipAnswered)
player:GetAttributeChangedSignal("Team"):Connect(equipAnswered)
data.ChildAdded:Connect(refreshIndex)
data.ChildRemoved:Connect(refreshIndex)
player:GetAttributeChangedSignal("EquippedCar"):Connect(refreshIndex)
player:GetAttributeChangedSignal("Team"):Connect(refreshIndex)
player:GetAttributeChangedSignal("BestTrack"):Connect(refreshIndex)
index.Gui:GetAttributeChangedSignal("SidekicksProgress"):Connect(refreshIndex)
index.Gui:GetAttributeChangedSignal("RelicsProgress"):Connect(refreshIndex)
refreshIndex()
require(Ui.InventoryTabs).Attach(index, player, refreshIndex)

local function refreshStats()
	local free = player:GetAttribute("StatPoints") or 0
	stats.Points.Text = string.format("%d FREE POINT%s", free, free == 1 and "" or "S")
	for _, badge in statsTabBadges do
		badge.Visible = free > 0
		badge.Text = tostring(free)
	end
	local allocations = {}
	for _, stat in ipairs(config.STATS) do
		allocations[stat] = player:GetAttribute("Alloc_" .. stat) or 0
	end
	local multis = config.Multis(allocations)
	local earned = free
	for _, points in allocations do
		earned += points
	end
	for stat, row in pairs(rows) do
		local available = free > 0
		row.Frame.Accent.Fill.Size = UDim2.fromScale(earned > 0 and allocations[stat] / earned or 0, 1)
		row.Value.Text = string.format(
			"%d pts · %s > %s",
			allocations[stat],
			format.Multi(multis[stat]),
			format.Multi(multis[stat] + config.PER_POINT[stat])
		)
		row.Plus.Active = available
		row.Plus.Selectable = available
		AnimeSkin.Button(row.Plus, available and "Go" or "Idle")
		local accent = row.Frame:GetAttribute("AccentColor")
		if available and accent then
			row.Plus.BackgroundColor3 = accent -- the stat's own colour, as before
		end
	end
	label(hud.Stats, "STATS")
	local badge = hud.Stats:FindFirstChild("PointsBadge")
	if badge then
		badge.Visible = free > 0
		badge.Text = tostring(free)
	end
end
for stat, row in pairs(rows) do
	row.Plus.Activated:Connect(function()
		if row.Plus.Active then
			remotes.AllocateStat:FireServer(stat)
		end
	end)
	player:GetAttributeChangedSignal("Alloc_" .. stat):Connect(refreshStats)
end
player:GetAttributeChangedSignal("StatPoints"):Connect(refreshStats)
refreshStats()

-- Design doc 4.42: stat rows on slanted plates in their own colour, rebirth rewards on angular cards.
for _, row in pairs(rows) do
	local frame = row.Frame
	AnimeSkin.Plate(frame, frame:GetAttribute("AccentColor"))
	frame.Lift.Visible = false
	frame.Accent.BackgroundColor3 = Color3.fromRGB(20, 24, 40)
end
for _, row in settings.Panel:GetDescendants() do
	local face = row:IsA("Frame") and row.Name:match("Row$") and row:FindFirstChild("Face")
	if face then
		AnimeSkin.Plate(face)
		for _, partName in { "Shadow", "Lift" } do
			local part = row:FindFirstChild(partName) or face:FindFirstChild(partName)
			if part then
				part.Visible = false
			end
		end
	end
end
for _, name in { "LuckReward", "SpeedReward", "PointReward" } do
	local reward = rebirth.Gui:FindFirstChild(name, true)
	local face = reward and reward:FindFirstChild("Face")
	if face then
		AnimeSkin.Card(face)
		for _, partName in { "Shadow", "Lift" } do
			local part = reward:FindFirstChild(partName) or face:FindFirstChild(partName)
			if part then
				part.Visible = false
			end
		end
	end
end

-- Design doc 4.42 spacing standard: Rebirth, Stats and Settings wear the Index's frame in its design units, as
-- Client/IndexAnimeStyle and Client/QuestAnimeStyle lay it out (920 x 620, phone 500 x 420): logo, title and close in
-- the header band, art tabs in the row at y 98, content from y 164 to 82 above the bottom, a count line in the footer.
-- fitPanels draws the panels at a UIScale (BaseScale), so a px token becomes design units through `units`. The
-- generated fit() re-applies the authored rects on every resize; those writes queue this layout again (as the Index).
local HudIcons = require(Ui.HudIcons)
local TOKEN, SPACE = AnimeSkin.Size, AnimeSkin.Space
local HEAVY = { Title = true, Section = true, Item = true }
local function phoneView()
	local camera = workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.Y <= 500
end
local function baseScale(frame)
	local scale = frame:GetAttribute("BaseScale")
	return type(scale) == "number" and scale > 0 and scale or 0.57 -- before the first fit: the Index's desktop scale
end
-- A px token (AnimeSkin.Px, so phones scale it too) in `frame`'s design units.
local function units(frame, px)
	return math.floor(AnimeSkin.Px(px) / baseScale(frame) + 0.5)
end
-- One of the five text roles (AnimeSkin.Label) at its px size on screen, after Label's own deferred pass. `fit`: a
-- Body or Caption line may shrink to the Caption size to stay on its line.
local function role(frame, text, name, fit)
	AnimeSkin.Label(text, name)
	local function scaled()
		local size = math.min(units(frame, TOKEN[name]), 100)
		local floor = math.min(size, units(frame, TOKEN.Caption))
		if HEAVY[name] or fit then
			text.TextScaled = true
			local limit = text:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
			limit.MaxTextSize, limit.MinTextSize = size, floor
			limit.Parent = text
		else
			text.TextSize = size
		end
	end
	scaled()
	task.defer(scaled)
end
local function place(gui, x, y, w, h)
	gui.AnchorPoint = Vector2.zero
	gui.Position, gui.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
end
-- The panel's tab strip into the tabs row: art tabs of one size, captions on one line, 14 px or more on screen.
local function tabsRow(strip, g)
	place(strip, 56, g.Tabs, g.W - 112, 40)
	local width = math.min(300, math.floor((g.W - 120) / 2)) -- two tabs; "PLAYER PROFILE" fits on one line
	for _, tab in strip:GetChildren() do
		if tab:IsA("TextButton") then
			tab.Size = UDim2.fromOffset(width, 40)
			local caption = tab:FindFirstChild("AnimeCaption")
			caption.Position, caption.Size = UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0)
			local size = g.u(TOKEN.Body)
			AnimeSkin.Text(caption, size)
			caption:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize =
				math.min(size, math.ceil(14 / baseScale(g.Frame)))
			local badge = tab:FindFirstChild("Badge")
			if badge then
				badge.Size = UDim2.fromOffset(g.u(24), g.u(24))
				badge.TextSize = g.u(TOKEN.Caption)
			end
		end
	end
end
local function indexFrame(refs, icon, content)
	local frame, face, header = refs.Panel.Parent, refs.Panel, refs.Header
	local band, close = header.Parent, refs.Close.Parent
	local chrome = Instance.new("ImageLabel")
	chrome.Name = "AnimeChrome"
	chrome.BackgroundTransparency = 1
	chrome.Image = AnimeSkin.Art.Chrome
	chrome.ScaleType = Enum.ScaleType.Stretch
	chrome.Position, chrome.Size = UDim2.fromOffset(-40, -70), UDim2.new(1, 80, 1, 100)
	chrome.ZIndex = 1
	chrome.Parent = face
	-- The Index chrome replaces the shared body art and strip PanelFrame.PaintGenerated put on.
	local body, strip = face:FindFirstChild("AnimeBody"), header:FindFirstChild("AnimeStrip")
	if body then
		body.Visible = false
	end
	if strip then
		strip.Visible = false
	end
	local logo = Instance.new("ImageLabel")
	logo.Name = "AnimeLogo"
	logo.BackgroundTransparency = 1
	logo.Image = icon
	logo.ScaleType = Enum.ScaleType.Fit
	logo.ZIndex = 11
	logo.Parent = header
	band.ZIndex = 8
	refs.Title.ZIndex = 10
	refs.Title.TextXAlignment = Enum.TextXAlignment.Left
	close.ZIndex = 10
	local closeArt = refs.Close:FindFirstChild("AnimeCloseArt")
	local g = {
		Frame = frame,
		u = function(px)
			return units(frame, px)
		end,
		Role = function(text, name, fit)
			role(frame, text, name, fit)
		end,
	}
	local function layout()
		local small = phoneView()
		local W, H = small and 500 or 920, small and 420 or 620
		if frame.Size ~= UDim2.fromOffset(W, H) then
			frame.Size = UDim2.fromOffset(W, H)
		end
		-- The header band spans the panel's top at its origin, so its parts sit in panel coordinates.
		place(band, 0, 0, W, 64)
		place(refs.Title, 168, -23, W - 266, 76)
		refs.Title.Rotation = -2
		AnimeSkin.Text(refs.Title, 72)
		place(logo, -19, -72, 188, 186)
		place(close, W - 74, 4, 58, 54)
		if closeArt then
			closeArt.AnchorPoint = Vector2.zero
			closeArt.Position, closeArt.Size = UDim2.fromOffset(-8, -10), UDim2.new(1, 16, 1, 20)
		end
		g.W, g.H, g.Tabs = W, H, small and 90 or 98
		g.Top = small and 144 or 164
		g.Height = H - g.Top - 82
		content(g)
	end
	local queued = false
	local function queue()
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				layout()
			end)
		end
	end
	for _, object in { frame, band, close } do
		object:GetPropertyChangedSignal("Position"):Connect(queue)
		object:GetPropertyChangedSignal("Size"):Connect(queue)
	end
	frame:GetAttributeChangedSignal("BaseScale"):Connect(queue)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(queue)
	end
	layout()
	queue() -- after the deferred passes of AnimeSkin.Tab / Title and UiTheme.Apply
end

-- The Index chrome art draws a footer plate: a count line fills it on every Racer panel, as the Index does (G1).
-- The line lives on the panel Face (same coordinates as the Index's IndexProgress), under the header band.
local function footerLine(refs, g, value)
	local face = refs.Panel
	local line = face:FindFirstChild("AnimeFooterLine")
	if not line then
		line = Instance.new("TextLabel")
		line.Name = "AnimeFooterLine"
		line.BackgroundTransparency = 1
		line.ZIndex = 4
		line.Parent = face
	end
	line.Text = value
	place(line, math.floor(g.W * 303 / 920), g.H - 60, math.floor(g.W * 312 / 920), 28)
	line.TextXAlignment = Enum.TextXAlignment.Center
	g.Role(line, "Body", true)
end

indexFrame(rebirth, HudIcons.Rebirth.Image, function(g)
	tabsRow(rebirth.Header.RebirthTabs, g)
	footerLine(rebirth, g, string.format("REBIRTH LEVEL %d", player:GetAttribute("RebirthLevel") or 0))
	-- Owner 2026-11-10: real margins, 16 px in from the content edges like Settings.
	local u = g.u
	local left, width = 56 + u(SPACE.Inset), g.W - 112 - 2 * u(SPACE.Inset)
	local gap, inner, pad = u(SPACE.Gap), u(SPACE.Inner), u(SPACE.Pad)
	local headH, lineH = u(TOKEN.Section + 4), u(TOKEN.Body + 4)
	local bottom = g.Top + g.Height
	for _, part in { rebirth.Warning, rebirth.Rewards, rebirth.Requirements, rebirth.RebirthButton.Parent } do
		part.ZIndex = 3
	end
	-- WARNING and its rule side by side.
	local warnH, headW = 2 * lineH, u(150)
	place(rebirth.Warning, left, g.Top, width, warnH)
	place(rebirth.WarningTitle, 0, math.floor((warnH - headH) / 2), headW, headH)
	place(rebirth.WarningText, headW + gap, 0, width - headW - gap, warnH)
	-- REQUIREMENTS and its bar on the left of the bottom row, REBIRTH on the right: both inside the Index's content area,
	-- clear of the frame's stripe art.
	local buttonW, buttonH, barH = u(160), u(SPACE.Button), u(SPACE.ButtonSmall)
	local reqW, reqH = width - buttonW - gap, headH + inner + barH
	local reqTop = bottom - reqH
	place(rebirth.Requirements, left, reqTop, reqW, reqH)
	place(rebirth.RequirementsTitle, 0, 0, reqW, headH)
	place(rebirth.Bar.Parent, 0, headH + inner, reqW, barH)
	place(rebirth.BarText, 0, 0, reqW, barH)
	place(rebirth.RebirthButton.Parent, left + width - buttonW, bottom - buttonH, buttonW, buttonH)
	-- NEXT REBIRTH: three cards across, between the warning and the bottom row.
	local rewardsTop = g.Top + warnH + gap
	local cardH = math.max(0, reqTop - gap - rewardsTop - headH - inner)
	local cardW = math.floor((width - 2 * gap) / 3)
	local iconSize = math.max(0, cardH - 2 * inner)
	place(rebirth.Rewards, left, rewardsTop, width, headH + inner + cardH)
	place(rebirth.RewardsTitle, 0, 0, width, headH)
	for i, name in { "LuckReward", "SpeedReward", "PointReward" } do
		place(rebirth[name].Parent, (i - 1) * (cardW + gap), headH + inner, cardW, cardH)
		local icon, caption = rebirth[name .. "Icon"], rebirth[name .. "Caption"]
		place(icon, pad, inner, iconSize, iconSize)
		local x = pad + iconSize + inner
		place(caption, x, 0, cardW - x - pad, cardH)
		caption.TextXAlignment = Enum.TextXAlignment.Left
		caption.TextWrapped = true
		g.Role(caption, "Body", true)
	end
	for _, heading in { rebirth.WarningTitle, rebirth.RewardsTitle, rebirth.RequirementsTitle } do
		heading.TextXAlignment = Enum.TextXAlignment.Left
		g.Role(heading, "Section") -- one heading colour, gold (UI audit G11)
	end
	rebirth.WarningText.TextXAlignment = Enum.TextXAlignment.Left
	rebirth.WarningText.TextWrapped = true
	rebirth.WarningText.TextTruncate = Enum.TextTruncate.None -- two lines, never cut
	g.Role(rebirth.WarningText, "Body", true)
	g.Role(rebirth.BarText, "Body", true)
	if rebirthCaption then
		g.Role(rebirthCaption, "Item")
	end
end)

indexFrame(stats, HudIcons.Rebirth.Image, function(g)
	tabsRow(stats.Header.RebirthTabs, g)
	local u, width = g.u, g.W - 112
	local gap, inner, pad = u(SPACE.Gap), u(SPACE.Inner), u(SPACE.Pad)
	place(stats.StatsHost, 56, g.Top, width, g.Height)
	stats.StatsHost.ZIndex = 3
	-- The free points line sits in the footer, where the Index counts its cards (UI audit G10).
	place(stats.Points, math.floor(g.W * 303 / 920), g.H - 60, math.floor(g.W * 312 / 920), 28)
	stats.Points.TextXAlignment = Enum.TextXAlignment.Center
	AnimeSkin.Text(stats.Points, u(TOKEN.Body))
	stats.Points:FindFirstChildOfClass("UIStroke").Thickness = 1.5
	-- The four stat rows fill the content area exactly: whole rows, 12 px apart, nothing to scroll.
	local list = stats.StatsHost:FindFirstChild("Rows")
	list:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, gap)
	local padding = list:FindFirstChildOfClass("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		padding[side] = UDim.new()
	end
	-- Owner 2026-11-10: rows 12 apart on a padded plate: the art 12 in, the text column starts clear of it, the plate's
	-- slanted ends are kept clear (24), the + button 12 from the right. Name on its own line, the rule and the multi
	-- on the next, the accent bar last, each 4 apart.
	-- Row height from its text: the name at the Item size, the rule / multi line at the Body size, the accent bar, 8
	-- between, 8 of padding above and below. Four rows then share the content with what gap is left (at least 4).
	-- The four rows and three 12-unit gaps share the content height exactly, so none spills under the footer;
	-- the text lines scale with the row (TextScaled under their role's size).
	local rowGap = gap
	local rowH = math.floor((g.Height - rowGap * (#config.STATS - 1)) / #config.STATS)
	local rowPad, lineGap, barH = inner, u(4), u(6)
	local textH = rowH - 2 * rowPad - 2 * lineGap - barH
	local nameH = math.floor(textH * 0.55)
	local lineH = textH - nameH
	list:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, rowGap)
	pad = rowPad -- the row's own padding, 8, in place of the card token
	local slant = u(24)
	local artSize = rowH - 2 * pad
	local plusSize = math.min(u(SPACE.Button), rowH - 2 * inner)
	local x = slant + artSize + pad
	local areaW = width - x - slant - plusSize - pad
	local descW = math.floor(areaW * 0.5)
	for _, row in pairs(rows) do
		local frame = row.Frame
		frame.Size = UDim2.new(1, 0, 0, rowH)
		place(frame.Art, slant, pad, artSize, artSize)
		row.Plus.AnchorPoint = Vector2.zero
		row.Plus.Position = UDim2.new(1, -(plusSize + slant), 0, math.floor((rowH - plusSize) / 2))
		row.Plus.Size = UDim2.fromOffset(plusSize, plusSize)
		place(frame.StatName, x, pad, areaW, nameH)
		place(frame.Description, x, pad + nameH + lineGap, descW, lineH)
		place(row.Value, x + descW, pad + nameH + lineGap, areaW - descW, lineH)
		place(frame.Accent, x, pad + nameH + lineGap + lineH + lineGap, areaW, barH)
		frame.StatName.TextXAlignment = Enum.TextXAlignment.Left
		frame.Description.TextXAlignment = Enum.TextXAlignment.Left
		row.Value.TextXAlignment = Enum.TextXAlignment.Right
		g.Role(frame.StatName, "Item")
		g.Role(frame.Description, "Caption")
		g.Role(row.Value, "Body") -- the multi in the card's heavy font (owner 2026-11-10), one step under the name
		row.Value.FontFace = AnimeSkin.Font
	end
end)

indexFrame(settings, HudIcons.Settings.Image, function(g)
	tabsRow(categoryTabs, g)
	-- Owner 2026-11-10: smaller text and real margins: rows 16 px in from the content edges, 12 px apart.
	local u = g.u
	local left, width = 56 + u(SPACE.Inset), g.W - 112 - 2 * u(SPACE.Inset)
	local showSettings = settings.Gui:GetAttribute("Category") ~= "Profile" -- fit() sets the rows Visible again
	local keys = { "Sound", "Effects", "Auto", "TrackCamera", "AutoSell" }
	local gap = u(SPACE.Gap)
	local rowH = math.floor((g.Height - (#keys - 1) * gap) / #keys)
	local toggleH = math.min(u(SPACE.ButtonSmall), rowH - u(SPACE.Inner))
	local toggleW = 2 * toggleH
	local slant = math.floor(rowH / 2) + u(SPACE.Inner)
	settingsTabLit(showSettings)
	profileTabLit(not showSettings)
	profileHost.Visible = not showSettings
	for i, key in keys do
		local wrapper = settings[key .. "Row"].Parent
		place(wrapper, left, g.Top + (i - 1) * (rowH + gap), width, rowH)
		wrapper.ZIndex = 3
		wrapper.Visible = showSettings
		local name = settings[key .. "Name"]
		place(name, slant, 0, width - 2 * slant - toggleW - u(SPACE.Inner), rowH)
		name.TextXAlignment = Enum.TextXAlignment.Left
		g.Role(name, "Body") -- 16 px, down from the Item size
		local toggle = settings[key .. "Toggle"]
		place(toggle.Parent, width - slant - toggleW, math.floor((rowH - toggleH) / 2), toggleW, toggleH)
		local knob = toggle:FindFirstChild("Knob")
		local caption = knob and knob:FindFirstChildWhichIsA("TextLabel")
		if caption then
			g.Role(caption, "Caption", true) -- fits "OFF" inside the knob
		end
	end
	footerLine(settings, g, showSettings and (#keys .. " SETTINGS") or (#profileRows .. " PROFILE LINES"))
	-- PLAYER PROFILE: six plates in the same area, 12 px apart.
	place(profileHost, left, g.Top, width, g.Height)
	local rowGap = u(SPACE.Gap)
	profileLayout.Padding = UDim.new(0, rowGap)
	local plateH = math.floor((g.Height - (#profileRows - 1) * rowGap) / #profileRows)
	local plateSlant = math.floor(plateH / 2) + u(SPACE.Inner)
	local textW = width - 2 * plateSlant
	for row, labels in profileLabels do
		row.Size = UDim2.new(1, 0, 0, plateH)
		place(labels[1], plateSlant, 0, math.floor(textW * 0.55), plateH)
		place(labels[2], plateSlant + math.floor(textW * 0.55), 0, textW - math.floor(textW * 0.55), plateH)
		g.Role(labels[1], "Item")
		g.Role(labels[2], "Body", true)
	end
end)

-- The Auto toggle lives in HudChrome/AutoSlot/Auto now. RacerHud/Race stays as the invisible layout anchor PanelBand and
-- the Toast read; the generated fit() sets Visible back to true on every resize.
local raceAnchor = hud.Race.Parent
raceAnchor:GetPropertyChangedSignal("Visible"):Connect(function()
	raceAnchor.Visible = false
end)
raceAnchor.Visible = false

task.spawn(function()
	playerGui:WaitForChild("RollToast")
	local showcase = playerGui:WaitForChild("RollShowcase")
	local function refreshShowcase()
		-- The full-screen Upgrades tree hides the HUD too (it shows its own Balance).
		hud.Gui.Enabled = not showcase.Enabled and not PanelSwitch.IsOpen("Upgrades")
	end
	showcase:GetPropertyChangedSignal("Enabled"):Connect(refreshShowcase)
	PanelSwitch.OnChange(refreshShowcase)
	refreshShowcase()
end)

local turboTween
local turboPopUntil = 0
-- Rolls done towards the next turbo roll and how many it takes: the server's TurboCount / TurboEvery (upgrade tree),
-- or the every-10th-roll rule from Rolls before those attributes arrive.
local function turboState()
	local count, every = player:GetAttribute("TurboCount"), player:GetAttribute("TurboEvery")
	if type(count) == "number" and type(every) == "number" and every >= 1 then
		return math.clamp(count, 0, every - 1), every
	end
	return config.TurboProgress(player:GetAttribute("Rolls") or 0), config.TURBO_EVERY
end
local function refreshTurbo()
	local progress, every = turboState()
	if os.clock() >= turboPopUntil then
		hud.TurboLabel.Text = string.format("TURBO LUCK %d/%d", progress, every)
	end
	if turboTween then
		turboTween:Cancel()
	end
	-- A turbo roll's label holds the bar full, so it never celebrates over an empty fill.
	local size = os.clock() < turboPopUntil and UDim2.fromScale(1, 1) or UDim2.fromScale(progress / every, 1)
	turboTween = UiMotion.Create(hud.TurboFill, TweenInfo.new(0.2), { Size = size })
	local tweenRef = turboTween
	tweenRef:Play()
	-- Keep the authoritative endpoint exact for HUD checks and for a turbo reset;
	-- the tween still provides the visible transition between updates.
	task.delay(0.25, function()
		if turboTween == tweenRef then
			hud.TurboFill.Size = size
		end
	end)
end
player:GetAttributeChangedSignal("Rolls"):Connect(refreshTurbo)
player:GetAttributeChangedSignal("TurboCount"):Connect(refreshTurbo)
player:GetAttributeChangedSignal("TurboEvery"):Connect(refreshTurbo)
refreshTurbo()
remotes.RollResult.OnClientEvent:Connect(function(_, _, turbo)
	if type(turbo) == "number" and turbo > 1 then
		turboPopUntil = os.clock() + 1.2
		hud.TurboLabel.Text = "TURBO x" .. tostring(turbo) .. "!"
		refreshTurbo()
		-- On the label, which spans the bar: the cue's Pop must not change the fill's measured width.
		UiFeedback.Play("Turbo", hud.TurboLabel, { Bar = hud.TurboFill, Goal = UDim2.fromScale(1, 1) })
		task.delay(1.2, function()
			if os.clock() >= turboPopUntil then
				turboPopUntil = 0
				refreshTurbo()
			end
		end)
	end
end)

-- Levels removed (owner 2026-11-01, design doc 4.14). shortcut: the bar is hidden, not deleted, because HudChrome
-- places the Items / Upgrade pair from its position; delete it with a HUD layout pass.
hud.Level.Visible = false

local shownMoney, shownBank = money.Value, player:GetAttribute("Unbanked") or 0
local shownGems = player:GetAttribute("Gems") or 0
local stopBankPulse
local function readable(value, isMoney)
	return isMoney and format.MoneyText(value) or format.SpeedText(value)
end
-- The Racer panels open in the band between the Race button and the TURBO LUCK bar, centred, clear of the
-- HudChrome icon grid on the left (and the same margin on the right). The generated fit sizes them;
-- here their UIScale shrinks below the generated k only when the band is too small (owner decision 2026-10-08;
-- the compact roll hides while a panel is open). All these ScreenGuis ignore the top-bar inset.
local function fitPanels()
	local camera = workspace.CurrentCamera
	if not camera or camera.ViewportSize.X <= 1 then
		return
	end
	local viewport = camera.ViewportSize
	-- docs/HUD_LAYOUT_SPEC.md section 6: below Race, above TURBO LUCK and Money, between the icon grid and Shop.
	local side, top, right, bottom = PanelBand.Rect()
	if not side then
		return
	end
	local width, height = right - side, bottom - top
	local k = if viewport.Y <= 500
		then math.clamp(viewport.Y / 390, 0.85, 1.15)
		else math.clamp(viewport.Y / 720, 0.6, 1.4)
	for _, refs in pairs(racerPanels) do
		local frame = refs.Panel.Parent
		local scale = frame:FindFirstChildOfClass("UIScale")
		local base = frame.Size
		if scale and base.X.Offset > 0 and base.Y.Offset > 0 then
			local motion = frame:FindFirstChild("MotionK") -- PanelSwitch's open / close scale
			local fitted = math.max(0.3, math.min(k, width / base.X.Offset, height / base.Y.Offset))
			scale.Scale = fitted * (motion and motion.Value or 1)
			-- The resting scale, for the px tokens of the Index-frame layout (indexFrame); 0.01 steps, no per-frame churn.
			local rounded = math.floor(fitted * 100 + 0.5) / 100
			if frame:GetAttribute("BaseScale") ~= rounded then
				frame:SetAttribute("BaseScale", rounded)
			end
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.Position = UDim2.fromOffset((side + right) / 2, top + height / 2)
		end
	end
end

-- The numbers count up towards the server's values (HudFormat.Approach) and pop when they grow (section 9, 10).
local function refreshReadouts(dt)
	shownMoney = format.Approach(shownMoney, money.Value, dt)
	shownBank = format.Approach(shownBank, player:GetAttribute("Unbanked") or 0, dt)
	hud.MoneyValue.Text = readable(shownMoney, true)
	hud.Unbanked.Text = "UNBANKED " .. readable(shownBank, true)
	shownGems = format.Approach(shownGems, player:GetAttribute("Gems") or 0, dt)
	gemsValue.Text = format.Short(shownGems)
	placeGems()
end
-- MoneyBig's threshold (placeholders): a gain of at least this share of the new balance, and at least this much.
local MONEY_BIG_SHARE, MONEY_BIG_MIN = 0.05, 1000
local moneyBigOwed = false -- a big gain that landed during a roll: its coins wait for the roll to end
local rollPhase = UiFeedback.RollPhase
local function playMoneyBig()
	UiFeedback.Play(
		"MoneyBig",
		hud.MoneyValue,
		{ Origin = workspace.CurrentCamera.ViewportSize / 2, Target = hud.MoneyValue }
	)
end
task.spawn(function()
	playerGui:WaitForChild("RollToast"):WaitForChild("Toast"):GetAttributeChangedSignal("Phase"):Connect(function()
		if moneyBigOwed and rollPhase() == "Idle" then
			moneyBigOwed = false
			playMoneyBig()
		end
	end)
end)
local lastMoney = money.Value
money.Changed:Connect(function(value)
	if value > lastMoney then
		if value - lastMoney < math.max(MONEY_BIG_MIN, value * MONEY_BIG_SHARE) then
			UiFeedback.Play("MoneySmall")
		elseif rollPhase() == "Idle" then
			playMoneyBig()
		else
			moneyBigOwed = true
		end
		UiMotion.Pop(hud.MoneyValue)
		UiMotion.Float(
			hud.MoneyValue.Parent,
			"+" .. format.MoneyText(value - lastMoney),
			palette.Money,
			UDim2.fromOffset(hud.MoneyValue.Position.X.Offset, hud.MoneyValue.Position.Y.Offset)
		)
	end
	lastMoney = value
end)
local function refreshBank()
	local banked = (player:GetAttribute("Unbanked") or 0) > 0
	if banked and not stopBankPulse then
		UiMotion.Pop(hud.Unbanked)
		stopBankPulse = UiMotion.Pulse(hud.Unbanked, { TextTransparency = 0.35 }, 0.7)
	elseif not banked and stopBankPulse then
		stopBankPulse()
		stopBankPulse = nil
	end
end
player:GetAttributeChangedSignal("Unbanked"):Connect(refreshBank)
refreshBank()
task.spawn(function()
	while true do
		task.wait(6)
		if hud.Gui.Enabled then
			UiMotion.Shine(hud.MoneyPlate)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	fitPanels()
	refreshReadouts(dt)
	local wrapper = hud.Turbo.Parent
	local position = wrapper.Position
	wrapper.Position = UDim2.new(0.5, 0, position.Y.Scale, position.Y.Offset)
end)
-- Session-local audio preference: preserve authored volumes and mute new sounds too.
local muted = false
local volumes = setmetatable({}, { __mode = "k" })
local function applySound(sound)
	if sound:IsA("Sound") then
		if volumes[sound] == nil then
			volumes[sound] = sound.Volume
		end
		sound.Volume = muted and 0 or volumes[sound]
	end
end
settings.SoundToggle.Activated:Connect(function()
	muted = not muted
	for _, descendant in ipairs(game:GetDescendants()) do
		applySound(descendant)
	end
	switch(settings.SoundToggle, not muted)
	UiFeedback.Play("Toggle")
end)
game.DescendantAdded:Connect(function(descendant)
	if muted then
		applySound(descendant)
	end
end)
settings.EffectsToggle.Activated:Connect(function()
	local reduced = player:GetAttribute("ReduceEffects") ~= true
	player:SetAttribute("ReduceEffects", reduced)
	switch(settings.EffectsToggle, reduced)
	UiFeedback.Play("Toggle")
end)
switch(settings.EffectsToggle, player:GetAttribute("ReduceEffects") == true)
switch(settings.SoundToggle, true)

-- Non-interactive numeric labels must not overflow as saves grow.
for _, object in ipairs({ hud.MoneyValue, hud.Unbanked, gemsValue, index.IndexProgress }) do
	object.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 14
	limit.MaxTextSize = object.TextSize
	limit.Parent = object
end

for _, root in ipairs({ hud.Gui, settings.Gui }) do
	for _, object in ipairs(root:GetDescendants()) do
		-- A label that already has a size limit (art tab captions, styled in indexFrame) keeps that one.
		if
			object:IsA("TextLabel")
			and object.Parent:IsA("TextButton")
			and not object:FindFirstChildOfClass("UITextSizeConstraint")
		then
			object.TextScaled = true
			local limit = Instance.new("UITextSizeConstraint")
			limit.MinTextSize = 14
			limit.MaxTextSize = object.TextSize
			limit.Parent = object
		end
	end
end
hud.Turbo.ClipsDescendants = true
hud.TurboFill.ZIndex = 2
hud.TurboLabel.ZIndex = 5

playerGui:SetAttribute("RacerUiReady", true)

return true
