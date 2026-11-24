--!nonstrict
-- World awareness on the HUD (docs/WORLD2_SPEC.md "World HUD", design doc 4.47), display only:
-- * WorldLabel: a small lacquer plate "World N" (Shared/WorldConfig.Id) under the top-right pills, as wide as and
--   right-aligned with HudChrome's right column, so it sits in the gap above that column and right of the race map
--   (Client/RaceProgressMap keeps 8 px left of the column) at every tested viewport, phones included.
-- * Travel: while the server holds a trip (player attribute Travelling, Server/WorldTravel.Go) TeamToast shows
--   "Travelling to World N..."; a failed trip already shows TeamToast's "TRAVEL FAILED, TRY AGAIN".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldConfig"))
local D = require(script.Parent:WaitForChild("AnimeSkin")).Dojo

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GAP = 4 -- px under the pills (placeholder)
local HEIGHT = 24 -- px at the pills' full size (placeholder)

local root = Instance.new("ScreenGui")
root.Name = "WorldHud"
root.ResetOnSpawn = false
root.IgnoreGuiInset = true -- the same frame as HudChrome, which it lines up with
root.DisplayOrder = 1
local label = Instance.new("TextLabel")
label.Name = "WorldLabel"
label.AnchorPoint = Vector2.new(1, 0)
label.Position = UDim2.new(1, -14, 0, 55)
label.Size = UDim2.fromOffset(84, HEIGHT)
label.Text = "World " .. WorldConfig.Id
label.TextScaled = true
label:SetAttribute("DojoTextColor", D.Colors.Gold)
D.Lacquer(label)
D.Text(label, "Item")
local fit = Instance.new("UITextSizeConstraint")
fit.MaxTextSize = 18
fit.Parent = label
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3)
pad.Parent = label
label.Parent = root
root.Parent = playerGui

-- Follows HudChrome: under TopRight's bottom, across ShopColumn's width (their UIScales shrink both on phones).
local hud = playerGui:WaitForChild("HudChrome")
local bar, column = hud:WaitForChild("TopRight"), hud:WaitForChild("ShopColumn")
local function place()
	if hud.AbsoluteSize.X <= 0 then
		return
	end
	local uiScale = bar:FindFirstChildOfClass("UIScale")
	local scale = uiScale and uiScale.Scale or 1
	local right = hud.AbsoluteSize.X - (column.AbsolutePosition.X + column.AbsoluteSize.X)
	label.Position = UDim2.new(1, -right, 0, bar.AbsolutePosition.Y + bar.AbsoluteSize.Y + GAP)
	label.Size = UDim2.fromOffset(column.AbsoluteSize.X, math.floor(HEIGHT * scale + 0.5))
	label.Visible = hud.Enabled and bar.Visible
end
for _, gui in { bar, column, hud } do
	gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
end
hud:GetPropertyChangedSignal("Enabled"):Connect(place)
bar:GetPropertyChangedSignal("Visible"):Connect(place)
place()

-- Travel toast through TeamToast's Message attribute.
-- shortcut: two worlds, so a trip always goes to the other one; send the target on the trip when a third world comes.
local toast = playerGui:WaitForChild("TeamToast")
local function travelling()
	if player:GetAttribute("Travelling") then
		toast:SetAttribute("Message", "Travelling to World " .. (3 - WorldConfig.Id) .. "...")
	end
end
player:GetAttributeChangedSignal("Travelling"):Connect(travelling)
travelling()
