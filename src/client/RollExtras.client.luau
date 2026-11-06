--!nonstrict
-- The small toast for a tick's rolls that do not play the animation (Extra Roll passes, docs/MONETIZATION_SPEC.md) and
-- the banner shown while a full bag stops rolling (docs/BAG_AND_AUTOSELL_SPEC.md). Display only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-- The banner stays while rolling is stopped: otherwise an idle player has no sign of why rolls ended.
local banner = Instance.new("Frame")
banner.Name = "BagFull"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 70)
banner.Size = UDim2.fromOffset(330, 84)
banner.BackgroundColor3 = PALETTE.PanelDeep
banner.Visible = false
banner.Active = true
banner.Parent = root
UiTheme.Corner(banner, "M")
UiTheme.Stroke(banner, 2, PALETTE.DangerDeep, true)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(8, 4)
title.Size = UDim2.new(1, -16, 0, 30)
title.BackgroundTransparency = 1
title.Font = UiTheme.Font
title.Text = "BAG FULL: rolling stopped"
title.TextColor3 = PALETTE.White
title.TextSize = 20
title.Parent = banner

local function action(name, text, x, fn)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(x, 1)
	b.Position = UDim2.new(x, x == 0 and 8 or -8, 1, -8)
	b.Size = UDim2.new(0.5, -12, 0, 36)
	b.BackgroundColor3 = PALETTE.Muted
	b.Font = UiTheme.Font
	b.Text = text
	b.TextColor3 = PALETTE.White
	b.TextSize = 16
	b.Parent = banner
	UiTheme.Corner(b, "S")
	b.Activated:Connect(fn)
end
action("SellSpares", "SELL SPARES", 0, function()
	if not PanelSwitch.IsOpen("Backpack") then
		PanelSwitch.Toggle("Backpack")
	end
end)
action("AutoSell", "AUTO SELL", 1, RollOptions.OpenAutoSell)

local function refresh()
	banner.Visible = player:GetAttribute("BagFull") == true
end
player:GetAttributeChangedSignal("BagFull"):Connect(refresh)
refresh()

UiTheme.Apply(root)
