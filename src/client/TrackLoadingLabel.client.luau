--!nonstrict
-- "Loading next track" (docs/GAME_DESIGN_REQUIREMENTS.md 4.25, text proposed): shown while the server holds this
-- player's runner for an unbuilt track (runner rig attribute RunHold, Server/RaceService). Display only; styled like
-- Client/BiomeWelcome. SafeInsets gives the ScreenGui its safe insets.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiTheme = require(ReplicatedStorage:WaitForChild("Shared").UiTheme)

local player = Players.LocalPlayer
local root = Instance.new("ScreenGui")
root.Name = "TrackLoadingLabel"
root.ResetOnSpawn = false
root.DisplayOrder = 2
local label = Instance.new("TextLabel")
label.Name = "Loading"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.fromScale(0.5, 0.3) -- placeholder: under the biome welcome popup
label.Size = UDim2.fromOffset(640, 48)
label.BackgroundTransparency = 1
label.Font = UiTheme.Font
label.TextSize = 32
label.TextColor3 = UiTheme.Palette.White
label.Text = "Loading next track"
label.Visible = false
UiTheme.Stroke(label, 2.5)
label.Parent = root
root.Parent = player:WaitForChild("PlayerGui")

while true do
	local held = false
	for _, rig in CollectionService:GetTagged("RunnerRig") do -- Server/CarService.RUNNER_TAG
		if rig:GetAttribute("Owner") == player.UserId and rig:GetAttribute("RunHold") then
			held = true
		end
	end
	label.Visible = held
	task.wait(0.2)
end
