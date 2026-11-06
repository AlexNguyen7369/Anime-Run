--!nonstrict
-- The small toast for a tick's rolls that do not play the animation (Extra Roll passes, docs/MONETIZATION_SPEC.md) and
-- the red text for a try a full bag blocked (docs/BAG_AND_AUTOSELL_SPEC.md). Display only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(shared:WaitForChild("CharacterCatalog"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local RollOptions = require(script.Parent:WaitForChild("RollOptions"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local PALETTE = UiTheme.Palette
local TOAST_SECONDS = 1.5 -- placeholder
local BAG_FULL_SECONDS = 1 -- owner 2026-11-05
local BAG_FULL_RED = Color3.fromRGB(235, 20, 30)

local root = Instance.new("ScreenGui")
root.Name = "RollExtras"
root.ResetOnSpawn = false
root.DisplayOrder = 1 -- under every panel
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
root.Parent = player:WaitForChild("PlayerGui")

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 170)
toast.Size = UDim2.fromOffset(360, 30)
toast.BackgroundColor3 = PALETTE.PanelDeep
toast.BackgroundTransparency = 0.25
toast.Font = UiTheme.Font
toast.TextColor3 = PALETTE.White
toast.TextSize = 16
toast.TextTruncate = Enum.TextTruncate.AtEnd
toast.Visible = false
toast.Parent = root
UiTheme.Corner(toast, "S")

local shownAt = 0
remotes:WaitForChild("ExtraRolls").OnClientEvent:Connect(function(rolls)
	local parts = {}
	for _, roll in type(rolls) == "table" and rolls or {} do
		local spec = CharacterCatalog.Get(roll.Id)
		if spec then
			local suffix = roll.IsNew and " NEW!" or (roll.SoldFor > 0 and " +$" .. HudFormat.Short(roll.SoldFor) or "")
			table.insert(parts, spec.Name .. suffix)
		end
	end
	if #parts == 0 then
		return
	end
	toast.Text = "+ " .. table.concat(parts, ", ")
	toast.Visible = true
	UiMotion.Pop(toast, 0.04)
	local at = os.clock()
	shownAt = at
	task.delay(TOAST_SECONDS, function()
		if shownAt == at then
			toast.Visible = false
		end
	end)
end)

-- Every try the full bag blocks (design doc 4.41): red text, no background, gone within 1 s. Auto roll stays on and tries again.
local bagFull = Instance.new("TextLabel")
bagFull.Name = "BagFull"
bagFull.AnchorPoint = Vector2.new(0.5, 0)
bagFull.Position = UDim2.new(0.5, 0, 0, 70)
bagFull.Size = UDim2.fromOffset(320, 44)
bagFull.BackgroundTransparency = 1
bagFull.Font = UiTheme.Font
bagFull.Text = "BAG FULL"
bagFull.TextColor3 = BAG_FULL_RED
bagFull.TextSize = 34
bagFull.Visible = false
bagFull.Parent = root
local bagFullStroke = Instance.new("UIStroke")
bagFullStroke.Color = UiTheme.Outline
bagFullStroke.Thickness = 2
bagFullStroke.Parent = bagFull

local fades = {}
remotes:WaitForChild("BagFullHit").OnClientEvent:Connect(function()
	for _, fade in fades do
		fade:Cancel()
	end
	bagFull.TextTransparency, bagFullStroke.Transparency = 0, 0
	bagFull.Visible = true
	local info = TweenInfo.new(BAG_FULL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	fades = {
		TweenService:Create(bagFull, info, { TextTransparency = 1 }),
		TweenService:Create(bagFullStroke, info, { Transparency = 1 }),
	}
	for _, fade in fades do
		fade:Play()
	end
	fades[1].Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			bagFull.Visible = false
		end
	end)
end)

-- The auto sell filter, under the roll (design doc 4.41): the roll view that also holds it does not open while a full bag blocks rolls.
local autoSell = Instance.new("TextButton")
autoSell.Name = "AutoSell"
autoSell.AnchorPoint = Vector2.new(0.5, 0)
autoSell.Position = UDim2.new(0.5, 0, 0, 204) -- under the roll's odds and the extra rolls' toast
autoSell.Size = UDim2.fromOffset(170, 26)
autoSell.BackgroundColor3 = PALETTE.Muted
autoSell.Font = UiTheme.Font
autoSell.TextColor3 = PALETTE.White
autoSell.TextSize = 14
autoSell.Parent = root
UiTheme.Corner(autoSell, "S")
autoSell.Activated:Connect(RollOptions.OpenAutoSell)

local function refreshAutoSell()
	local on = player:GetAttribute("AutoSell") == true
	local chance = player:GetAttribute("AutoSellChance")
	autoSell.Text = on and type(chance) == "number" and "Auto Sell: 1 in " .. HudFormat.Short(chance)
		or "Auto Sell: OFF"
	autoSell.BackgroundColor3 = on and PALETTE.MoneyDeep or PALETTE.Muted
	autoSell.Visible = player:GetAttribute("AutoRoll") ~= false
		and player:GetAttribute("NeedsStarter") ~= true
		and player:GetAttribute("BossEvent") ~= true
		and not PanelSwitch.AnyOpen()
end
for _, name in { "AutoSell", "AutoSellChance", "AutoRoll", "NeedsStarter", "BossEvent" } do
	player:GetAttributeChangedSignal(name):Connect(refreshAutoSell)
end
PanelSwitch.OnChange(refreshAutoSell)
refreshAutoSell()

UiTheme.Apply(root)
