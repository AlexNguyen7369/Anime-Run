--!nonstrict
-- Biome welcome popup (docs/GAME_DESIGN_REQUIREMENTS.md 4.17): when Client/BiomeEnvironment blends to a new track
-- zone (Shared/BiomeEnvironment.CurrentZone), the biome's display name fades in at the top centre, holds, and fades
-- out. Never for the plaza (zone 0). Client-only display; SafeInsets gives the ScreenGui its safe insets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Env = require(Shared.BiomeEnvironment)
local Themes = require(Shared.BiomeThemes)
local UiTheme = require(Shared.UiTheme)
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local FADE_IN, HOLD, FADE_OUT = 0.4, 2, 0.6 -- placeholder (4.17)

local root = Instance.new("ScreenGui")
root.Name = "BiomeWelcome"
root.ResetOnSpawn = false
root.DisplayOrder = 2
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local group = Instance.new("CanvasGroup") -- one GroupTransparency fades the text and its stroke together
group.Name = "Popup"
group.AnchorPoint = Vector2.new(0.5, 0)
group.Position = UDim2.fromScale(0.5, 0.22) -- below the AUTO RACE button (Studio check 2026-11-01)
group.Size = UDim2.fromOffset(640, 56)
group.BackgroundTransparency = 1
group.GroupTransparency = 1
group.Visible = false
group.Parent = root
local label = Instance.new("TextLabel")
label.Name = "BiomeName"
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = UiTheme.Font
label.TextSize = 38
label.TextColor3 = UiTheme.Palette.White
label.Text = ""
UiTheme.Stroke(label, 2.5)
label.Parent = group
root.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local shown = 0 -- bumps per popup, so an older popup's fade-out never hides a newer one
local function show(name)
	shown += 1
	local mine = shown
	label.Text = name
	group.GroupTransparency = 1
	group.Visible = true
	UiMotion.Create(group, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
	}):Play()
	task.delay(FADE_IN + HOLD, function()
		if shown ~= mine then
			return
		end
		local out = UiMotion.Create(group, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			GroupTransparency = 1,
		})
		out.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and shown == mine then
				group.Visible = false
			end
		end)
		out:Play()
	end)
end

local last = Env.CurrentZone
while true do
	local zone = Env.CurrentZone
	if zone ~= last then
		last = zone
		local theme = zone and zone ~= 0 and Themes[Env.BiomeOf(zone)]
		if theme and type(theme.DisplayName) == "string" then
			show(theme.DisplayName)
		end
	end
	task.wait(0.1)
end
