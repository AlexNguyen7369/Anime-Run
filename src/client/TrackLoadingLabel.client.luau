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

local TAG = "RunnerRig" -- Server/RunnerService.RUNNER_TAG
local function watch(rig)
	if rig:GetAttribute("Owner") ~= player.UserId then
		return
	end
	local function update()
		label.Visible = rig:GetAttribute("RunHold") ~= nil
	end
	rig:GetAttributeChangedSignal("RunHold"):Connect(update)
	update()
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(rig)
	if rig:GetAttribute("Owner") == player.UserId then
		label.Visible = false
	end
end)
for _, rig in CollectionService:GetTagged(TAG) do
	watch(rig)
end
