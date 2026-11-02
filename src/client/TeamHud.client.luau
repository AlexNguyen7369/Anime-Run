--!nonstrict
-- Team row (owner 2026-11-02, docs/TEAM_AND_STAMINA_SPEC.md "HUD"): 3 circle portraits in the retired Level bar's
-- place, slot 1-3 left to right. While running, the active slot (RunSlot) is larger and highlighted and a slot at
-- Stamina<n> = 0 is greyed out. Reads the server's player attributes Team, RunSlot and Stamina1..3; display only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(shared.CharacterCatalog)
local GachaConfig = require(shared.GachaConfig)
local Components = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("RacerComponents"))

local SLOTS = 3
local CIRCLE = 48 -- px (placeholder)
local ACTIVE_SCALE = 1.2 -- placeholder
local HIGHLIGHT = Color3.fromRGB(255, 214, 80)
local DIM = Color3.fromRGB(28, 38, 62)
local GREY = Color3.fromRGB(110, 110, 110)

local hud = player:WaitForChild("PlayerGui"):WaitForChild("RacerHud")
local level = hud:WaitForChild("Level") -- kept (hidden face) because HudChrome places Items / Upgrade from it
local shadow = level:FindFirstChild("Shadow")
if shadow then
	shadow.Visible = false
end

local row = Instance.new("Frame")
row.Name = "Team"
row.BackgroundTransparency = 1
row.Size = UDim2.fromScale(1, 1)
row.Position = UDim2.fromOffset(0, -8) -- the enlarged active circle clears the TURBO LUCK bar below
row.ZIndex = 5
row.Parent = level
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 14)
layout.Parent = row

local circles = {}
for slot = 1, SLOTS do
	local c = Instance.new("Frame")
	c.Name = "Slot" .. slot
	c.LayoutOrder = slot
	c.Size = UDim2.fromOffset(CIRCLE, CIRCLE)
	c.BackgroundColor3 = DIM
	c.BorderSizePixel = 0
	c.ZIndex = 5
	c.Parent = row
	Instance.new("UICorner", c).CornerRadius = UDim.new(0.5, 0)
	local clip = Instance.new("CanvasGroup") -- a Frame clips square; a CanvasGroup clips to the round corner
	clip.Name = "Clip"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.ZIndex = 6
	clip.Parent = c
	Instance.new("UICorner", clip).CornerRadius = UDim.new(0.5, 0)
	local ring = Instance.new("UIStroke")
	ring.Thickness = 3
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = c
	local scale = Instance.new("UIScale")
	scale.Parent = c
	circles[slot] = { Frame = c, Clip = clip, Ring = ring, Scale = scale, Id = nil, Art = nil }
end

local function render()
	local team = string.split(player:GetAttribute("Team") or "", ",")
	local running = player:GetAttribute("RunSlot")
	for slot, circle in circles do
		local spec = team[slot] and team[slot] ~= "" and CharacterCatalog.Get(team[slot])
		local id = spec and spec.Id
		if circle.Id ~= id then
			circle.Id = id
			if circle.Art then
				circle.Art:Destroy()
				circle.Art = nil
			end
			if spec then
				circle.Art = Components.RunnerArt(circle.Clip, "Art", spec, UDim2.new(), UDim2.fromScale(1, 1))
				-- head-and-shoulders: RunnerArt frames the whole rig, too small to read in a 48 px circle
				local head = circle.Art:FindFirstChild("Head", true)
				if head and circle.Art.CurrentCamera then
					local focus = head.Position - Vector3.new(0, 0.6, 0)
					circle.Art.CurrentCamera.CFrame =
						CFrame.lookAt(focus + Vector3.new(-0.35, 0.15, -1).Unit * 7, focus)
				end
			end
		end
		local active = running == slot and spec ~= nil
		local exhausted = running ~= nil
			and spec ~= nil
			and (tonumber(player:GetAttribute("Stamina" .. slot)) or 1) <= 0
		local rarity = spec and GachaConfig.RARITY_COLORS[spec.Rarity] or DIM
		circle.Ring.Color = active and HIGHLIGHT or exhausted and GREY or rarity
		circle.Ring.Thickness = active and 4 or 3
		circle.Frame.BackgroundColor3 = exhausted and GREY or DIM
		circle.Frame.BackgroundTransparency = spec and 0 or 0.4
		circle.Clip.GroupColor3 = exhausted and GREY or Color3.new(1, 1, 1)
		circle.Clip.GroupTransparency = exhausted and 0.35 or 0
		TweenService:Create(circle.Scale, TweenInfo.new(0.2), { Scale = active and ACTIVE_SCALE or 1 }):Play()
	end
end

player.AttributeChanged:Connect(function(name)
	if name == "Team" or name == "RunSlot" or string.sub(name, 1, 7) == "Stamina" then
		render()
	end
end)
render()
