--!nonstrict
-- The bold floating labels over Race Start and the Market (design doc 4.24 Wayfinding): client display only. Each hangs on
-- an attachment in Terrain at a fixed world position (Shared/PlazaAssets.Landmarks), so streaming never hides it. Shown on
-- foot only, and not up close where the landmark's own sign reads. Sizes and distances are proposed placeholders.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("PlazaAssets"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local MAX_DISTANCE = 260
local HIDE_WITHIN = 20
local LABELS = {
	{ Key = "RaceStart", Text = "RACE START", Color = Color3.fromRGB(42, 170, 80) },
	{ Key = "Market", Text = "MARKET", Color = Color3.fromRGB(122, 63, 184) },
}

local player = Players.LocalPlayer
local shown = {}
for _, spec in LABELS do
	local anchor = Instance.new("Attachment")
	anchor.Name = "Wayfinding_" .. spec.Key
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = Layout.Landmarks[spec.Key]

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(190, 62)
	gui.MaxDistance = MAX_DISTANCE -- AlwaysOnTop stays off: these billboards do not draw with it
	gui.LightInfluence = 0
	gui.Parent = anchor

	local pill = Instance.new("Frame")
	pill.Size = UDim2.new(1, 0, 0, 44)
	pill.BackgroundColor3 = spec.Color
	pill.BorderSizePixel = 0
	pill.Parent = gui
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 12)
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.new(1, 1, 1)
	rim.Thickness = 3
	rim.Parent = pill

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -12, 1, -6)
	text.Position = UDim2.fromOffset(6, 3)
	text.BackgroundTransparency = 1
	text.Font = UiTheme.Font
	text.Text = spec.Text
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	UiTheme.Stroke(text, 2)
	text.Parent = pill

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(1, 0, 0, 18)
	arrow.Position = UDim2.fromOffset(0, 44)
	arrow.BackgroundTransparency = 1
	arrow.Font = UiTheme.Font
	arrow.Text = "▼"
	arrow.TextColor3 = spec.Color
	arrow.TextScaled = true
	UiTheme.Stroke(arrow, 2)
	arrow.Parent = gui

	table.insert(shown, { Gui = gui, Position = Layout.Landmarks[spec.Key] })
end

while true do
	local camera = Workspace.CurrentCamera
	local focus = camera and camera.Focus.Position or Vector3.zero
	local racing = player:GetAttribute("AutoRacing") == true
	for _, label in shown do
		local flat = (label.Position - focus) * Vector3.new(1, 0, 1)
		label.Gui.Enabled = not racing and flat.Magnitude > HIDE_WITHIN
	end
	task.wait(0.25)
end
