--!nonstrict
-- One shared tooltip (design doc 4.45, owner 2026-11-17): an item's name, rarity and effect over a small icon, shown on
-- hover, gamepad focus or a tap, hidden on leave. Bind(gui, info) where info() returns { Title, Rarity, Body }.
-- Appears in 0.2 s (fade and a 6 px rise, proposed); lands at once under reduced motion.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaConfig = require(Shared:WaitForChild("GachaConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local D = UiTheme.Dojo
local W, H = 220, 84
local SHOW = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local UiTooltip = {}
local tip, owner

local function label(name, parent, y, h, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(10, y)
	l.Size = UDim2.new(1, -20, 0, h)
	l.Font = font or UiTheme.Font
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = D.Cream
	l.ZIndex = 2
	l.Parent = parent
	return l
end

local function build()
	if tip and tip.Parent then
		return tip
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "UiTooltip"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	tip = Instance.new("Frame")
	tip.Name = "Tip"
	tip.Size = UDim2.fromOffset(W, H)
	tip.BackgroundColor3 = D.Ink
	tip.BackgroundTransparency = 0.05
	tip.Visible = false
	tip.Active = false
	tip.Parent = gui
	UiTheme.Corner(tip, "S")
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Edge"
	stroke.Thickness = D.Stroke
	stroke.Color = D.Gold
	stroke.Parent = tip
	label("Title", tip, 6, 24)
	label("Rarity", tip, 30, 16, Enum.Font.GothamBold)
	label("Body", tip, 48, 30, Enum.Font.Gotham)
	return tip
end

local function hide(gui)
	if tip and owner == gui then
		owner = nil
		tip.Visible = false
	end
end

local function show(gui, info)
	local t = build()
	local data = info()
	if not data then
		return
	end
	owner = gui
	t.Title.Text = data.Title or ""
	t.Rarity.Text = data.Rarity or ""
	t.Rarity.TextColor3 = GachaConfig.RARITY_COLORS[data.Rarity] or D.Gold
	t.Edge.Color = GachaConfig.RARITY_COLORS[data.Rarity] or D.Gold
	t.Body.Text = data.Body or ""
	-- Above the icon, kept on screen.
	local view = workspace.CurrentCamera.ViewportSize
	local inset = game:GetService("GuiService"):GetGuiInset()
	local x = math.clamp(gui.AbsolutePosition.X + gui.AbsoluteSize.X / 2 - W / 2, 4, view.X - W - 4)
	local y = gui.AbsolutePosition.Y + inset.Y - H - 8
	if y < 4 then
		y = gui.AbsolutePosition.Y + inset.Y + gui.AbsoluteSize.Y + 8
	end
	t.Position = UDim2.fromOffset(x, y + 6)
	t.BackgroundTransparency = 1
	t.Visible = true
	UiMotion.Create(t, SHOW, { Position = UDim2.fromOffset(x, y), BackgroundTransparency = 0.05 }):Play()
end

-- Shows the tooltip for `gui` (any GuiObject) on hover, focus or tap. Connections end with the gui.
function UiTooltip.Bind(gui, info)
	gui.MouseEnter:Connect(function()
		show(gui, info)
	end)
	gui.MouseLeave:Connect(function()
		hide(gui)
	end)
	gui.SelectionGained:Connect(function()
		show(gui, info)
	end)
	gui.SelectionLost:Connect(function()
		hide(gui)
	end)
	gui.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if owner == gui and tip.Visible then
				hide(gui)
			else
				show(gui, info)
			end
		end
	end)
	gui.AncestryChanged:Connect(function()
		if not gui:IsDescendantOf(game) then
			hide(gui)
		end
	end)
end

task.spawn(build) -- PlayerGui.UiTooltip/Tip exists before the first hover

function UiTooltip.Hide()
	if tip then
		owner = nil
		tip.Visible = false
	end
end

return UiTooltip
