--!nonstrict
-- The floating headers over Race Start and the service row, Market included (design doc 4.24 Wayfinding, Service headers): client
-- display only. Each hangs on an attachment in Terrain at a fixed world position, so streaming never hides it. Shown on foot
-- only, and not up close where the landmark's own sign reads. Sizes and distances are proposed placeholders.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("PlazaAssets"))
local PlazaHeader = require(Shared:WaitForChild("PlazaHeader"))

local MAX_DISTANCE = 260
local HIDE_WITHIN = 20
-- The row's headers stay near it and hide sooner: its prompts open within 10-12 studs and no Dojo may lose sight of the spawn.
local ROW_MAX_DISTANCE = 150
local ROW_HIDE_WITHIN = 10
local ROW_SIZE = UDim2.new(11, 60, 4, 24) -- studs plus pixels: grows as you get closer, still reads far away
-- y clears each roof (PlazaAssets: stalls 15.05, Market 17, Index 17.25) by the emblem's half height
local LABELS = {
	{
		Key = "RaceStart",
		Text = "RACE START",
		Shape = "Star",
		Color = Color3.fromRGB(42, 170, 80),
		At = Layout.Landmarks.RaceStart,
		Size = UDim2.fromOffset(280, 110),
		MaxDistance = MAX_DISTANCE,
		HideWithin = HIDE_WITHIN,
	},
	{
		Key = "Market",
		Text = "MARKET",
		Shape = "Gem",
		Color = Color3.fromRGB(122, 63, 184),
		At = Vector3.new(-72, 20, -12.5),
		Size = ROW_SIZE,
		MaxDistance = ROW_MAX_DISTANCE,
		HideWithin = ROW_HIDE_WITHIN,
	},
	{
		Key = "Shop",
		Text = "SHOP",
		Shape = "Gem",
		Color = Color3.fromRGB(40, 110, 220),
		At = Vector3.new(-72, 18, -70),
		Size = ROW_SIZE,
		MaxDistance = ROW_MAX_DISTANCE,
		HideWithin = ROW_HIDE_WITHIN,
	},
	{
		Key = "Potions",
		Text = "POTIONS",
		Shape = "Gem",
		Color = Color3.fromRGB(214, 52, 170),
		At = Vector3.new(-72, 18, -41.25),
		Size = ROW_SIZE,
		MaxDistance = ROW_MAX_DISTANCE,
		HideWithin = ROW_HIDE_WITHIN,
	},
	{
		Key = "Index",
		Text = "INDEX",
		Shape = "Star",
		Color = Color3.fromRGB(240, 180, 30),
		At = Vector3.new(-72, 20, 16.25),
		Size = ROW_SIZE,
		MaxDistance = ROW_MAX_DISTANCE,
		HideWithin = ROW_HIDE_WITHIN,
	},
}

local player = Players.LocalPlayer
local shown = {}
for _, spec in LABELS do
	local anchor = Instance.new("Attachment")
	anchor.Name = "Wayfinding_" .. spec.Key
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = spec.At

	local gui = PlazaHeader.Build(anchor, "Label", spec.Text, spec.Shape, spec.Color, spec.Size, spec.MaxDistance)
	table.insert(shown, { Gui = gui, Position = spec.At, HideWithin = spec.HideWithin })
end

while true do
	local camera = Workspace.CurrentCamera
	local focus = camera and camera.Focus.Position or Vector3.zero
	local racing = player:GetAttribute("AutoRacing") == true
	for _, label in shown do
		local flat = (label.Position - focus) * Vector3.new(1, 0, 1)
		label.Gui.Enabled = not racing and flat.Magnitude > label.HideWithin
	end
	task.wait(0.25)
end
