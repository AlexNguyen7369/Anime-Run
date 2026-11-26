--!nonstrict
-- The floating headers over Race Start, the economy wing (Market included), the Sidekick summon altar and the Team altar (design doc 4.24 Wayfinding, Service headers): client
-- display only. Each hangs on an attachment in Terrain at a fixed world position, so streaming never hides it. Shown on foot
-- only, and not up close where the landmark's own sign reads. Sizes and distances are proposed placeholders.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("PlazaAssets"))
local PlazaHeader = require(Shared:WaitForChild("PlazaHeader"))
local PlazaLayout = require(Shared:WaitForChild("PlazaLayout"))
local PlazaPieces = require(Shared:WaitForChild("PlazaPieces"))
local SidekickConfig = require(Shared:WaitForChild("SidekickConfig"))

local MAX_DISTANCE = 260
local HIDE_WITHIN = 20
-- The wings' headers stay near them and hide sooner: their prompts open within 10-16 studs.
local ROW_MAX_DISTANCE = 150
local ROW_HIDE_WITHIN = 10
local ROW_SIZE = UDim2.new(11, 60, 4, 24) -- studs plus pixels: grows as you get closer, still reads far away
-- y clears each roof (PlazaAssets: stalls 15.05, Market 17, Index 17.25; altar halo 16.1) by the emblem's half height.
-- (x, z): each front (stall origin + 5 along its face, Market + 5.5, Index and the altar at their origins) on the showpiece
-- ring, design doc 4.43, WORLD_REDESIGN_SPEC 4 (heights proposed). Approved spots, moved by Shared/PlazaLayout.
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
		At = PlazaLayout.With(Vector3.new(2.905, 20, -78.446), Vector2.new(3.109, -83.942)), -- moves with the Market
		Size = ROW_SIZE,
		MaxDistance = ROW_MAX_DISTANCE,
		HideWithin = ROW_HIDE_WITHIN,
	},
	{
		Key = "Sidekicks",
		Text = "SIDEKICKS",
		Shape = "Star",
		Color = Color3.fromRGB(30, 150, 170),
		At = PlazaLayout.Spot(Vector3.new(57.158, 21, 61.555)), -- the summon altar
		Size = ROW_SIZE,
		MaxDistance = ROW_MAX_DISTANCE,
		HideWithin = ROW_HIDE_WITHIN,
	},
	{
		Key = "Team",
		Text = "TEAM",
		Shape = "Star",
		Color = Color3.fromRGB(46, 200, 208), -- UiTheme.Dojo.Cyan, the Team page's accent
		At = PlazaLayout.Spot(Vector3.new(-35, 12, 76.4)), -- the Team altar (design doc 4.45), its top tier at about 3.6 plus the emblem
		Size = ROW_SIZE,
		MaxDistance = ROW_MAX_DISTANCE,
		HideWithin = ROW_HIDE_WITHIN,
	},
	{
		Key = "Shop",
		Text = "SHOP",
		Shape = "Gem",
		Color = Color3.fromRGB(40, 110, 220),
		At = PlazaLayout.With(Vector3.new(-78.945, 18, -2.924), Vector2.new(-83.942, -3.109)), -- with the Shop
		Size = ROW_SIZE,
		MaxDistance = ROW_MAX_DISTANCE,
		HideWithin = ROW_HIDE_WITHIN,
	},
	{
		Key = "Potions",
		Text = "POTIONS",
		Shape = "Gem",
		Color = Color3.fromRGB(214, 52, 170),
		At = PlazaLayout.With(Vector3.new(-53.755, 18, -57.891), Vector2.new(-57.158, -61.555)), -- with Potions
		Size = ROW_SIZE,
		MaxDistance = ROW_MAX_DISTANCE,
		HideWithin = ROW_HIDE_WITHIN,
	},
	{
		Key = "Index",
		Text = "INDEX",
		Shape = "Star",
		Color = Color3.fromRGB(240, 180, 30),
		At = PlazaLayout.Spot(Vector3.new(76.7, 20, -34.2)),
		Size = ROW_SIZE,
		MaxDistance = ROW_MAX_DISTANCE,
		HideWithin = ROW_HIDE_WITHIN,
	},
}

-- The new altar is taller than today's: its header stands over the crest
local altar = PlazaPieces.Altar()
for _, spec in LABELS do
	if altar and spec.Key == "Sidekicks" then
		spec.At = Vector3.new(spec.At.X, altar.HeaderY, spec.At.Z)
	end
end

local player = Players.LocalPlayer
local shown = {}
for _, spec in LABELS do
	local anchor = Instance.new("Attachment")
	anchor.Name = "Wayfinding_" .. spec.Key
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = spec.At

	local gui = PlazaHeader.Build(anchor, "Label", spec.Text, spec.Shape, spec.Color, spec.Size, spec.MaxDistance)
	table.insert(shown, { Gui = gui, Position = spec.At, HideWithin = spec.HideWithin, Key = spec.Key })
end

while true do
	local camera = Workspace.CurrentCamera
	local focus = camera and camera.Focus.Position or Vector3.zero
	local racing = player:GetAttribute("AutoRacing") == true
	-- the altar's sign waits for rebirth 1 (owner 2026-11-20, design doc 4.36)
	local early = (player:GetAttribute("RebirthLevel") or 0) < SidekickConfig.HudFromRebirth
	for _, label in shown do
		local flat = (label.Position - focus) * Vector3.new(1, 0, 1)
		label.Gui.Enabled = not racing
			and flat.Magnitude > label.HideWithin
			and not (early and label.Key == "Sidekicks")
	end
	task.wait(0.25)
end
