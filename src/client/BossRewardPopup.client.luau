--!nonstrict
-- The boss rewards popup (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Rewards"). Contract: Client/UiTest/UiBossPhase2. Display only: the
-- server already paid; this shows RunEvent's BossRewards once the player is out of the event, and leaves the way for any open panel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(shared:WaitForChild("BossEventConfig"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local RelicConfig = require(shared:WaitForChild("RelicConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local Palette = UiTheme.Palette
local Icons = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

-- Placeholders, px.
local WIDTH, HEADER, ROW, ART, AMOUNT = 400, 42, 30, 64, 104
local RAGA_CHEST, ADAPTED_CHEST = "relic_chest_raga", "relic_chest_adapted"

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function label(name, parent, props, maxSize)
	props.BackgroundTransparency = 1
	props.Font = UiTheme.Font
	props.TextColor3 = props.TextColor3 or Palette.White
	props.TextScaled = true
	local text = make("TextLabel", name, parent, props)
	make("UITextSizeConstraint", "Max", text, { MaxTextSize = maxSize })
	UiTheme.Stroke(text, 2)
	return text
end

local root = make("ScreenGui", "RacerBossRewards", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	DisplayOrder = 62, -- above every panel and popup the return may open
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Active = true,
	Visible = false,
})
UiTheme.Body(panel)
UiTheme.Corner(panel, "L")
UiTheme.Stroke(panel, 3, UiTheme.Outline, true)
make("UIListLayout", "List", panel, {
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
make("UIPadding", "Padding", panel, {
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
})
local header = make("Frame", "Header", panel, {
	Size = UDim2.new(1, 0, 0, HEADER),
	LayoutOrder = 0,
	BackgroundColor3 = Palette.White,
	BorderSizePixel = 0,
})
UiTheme.Corner(header, "L")
local colors = PanelFrame.Themes.Daily
make("UIGradient", "Gradient", header, { Color = ColorSequence.new(colors[1], colors[2]) })
local title = label("Title", header, {
	Position = UDim2.fromScale(0.03, 0.14),
	Size = UDim2.new(0.97, -48, 0.72, 0),
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
}, 28)
local closeButton = make("TextButton", "CloseButton", header, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -4, 0.5, 0),
	Size = UDim2.fromOffset(38, 34),
	Text = "X",
	Font = UiTheme.Font,
	TextSize = 20,
	TextColor3 = Palette.White,
	BackgroundColor3 = Palette.Danger,
	AutoButtonColor = false,
	BorderSizePixel = 0,
})
UiTheme.Corner(closeButton, "M")
UiTheme.Stroke(closeButton, 3, UiTheme.Outline, true)
local damage = label("Damage", panel, {
	Size = UDim2.new(1, 0, 0, ROW),
	LayoutOrder = 1,
	Text = "",
}, 24)
local rewards = make("Frame", "Rewards", panel, {
	Size = UDim2.new(1, 0, 0, ART),
	LayoutOrder = 2,
	BackgroundTransparency = 1,
})
make("UIListLayout", "List", rewards, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local function chestArt(id, order)
	return make("ImageLabel", "Chest_" .. id, rewards, {
		Size = UDim2.fromOffset(ART, ART),
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Image = RelicConfig.Chests[id].Image,
		ScaleType = Enum.ScaleType.Fit,
	})
end
local ragaChest, adaptedChest = chestArt(RAGA_CHEST, 1), chestArt(ADAPTED_CHEST, 3)
local money = label("Money", rewards, {
	Size = UDim2.fromOffset(AMOUNT, ROW),
	LayoutOrder = 2,
	Text = "$" .. HudFormat.Commas(Cfg.Phase1Money),
	TextColor3 = Palette.Money,
}, 22)
local gems = label("Gems", rewards, {
	Size = UDim2.fromOffset(AMOUNT, ROW),
	LayoutOrder = 4,
	Text = HudFormat.Commas(Cfg.Phase2Gems),
}, 22)
make("UIPadding", "Padding", gems, { PaddingLeft = UDim.new(0, ROW) })
make("ImageLabel", "Icon", gems, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromOffset(ROW, ROW),
	BackgroundTransparency = 1,
	Image = Icons.Gem.Image,
	ScaleType = Enum.ScaleType.Fit,
})
local note = label("Note", panel, {
	Size = UDim2.new(1, 0, 0, 22),
	LayoutOrder = 3,
	Text = "Deal 5% for rewards",
	TextColor3 = Palette.Gold,
}, 18)

local message = nil -- what waits to show, or shows
local seen = false -- it has been on screen: the next event takes it away

local function close()
	message, seen = nil, false
end
closeButton.Activated:Connect(close)
PanelFrame.CloseOnOutsideClick(panel, close)

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RunEvent").OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" or ev.Kind ~= "BossRewards" then
		return
	end
	message, seen = ev, false
	title.Text = ev.Outcome == "Survived" and "Fully Adapted Raga survived" or "Raga Defeated!"
	damage.Text = "Total damage: " .. HudFormat.Commas(tonumber(ev.Damage) or 0)
	ragaChest.Visible, money.Visible = ev.Stage1 == true, ev.Stage1 == true
	adaptedChest.Visible, gems.Visible = ev.Stage2 == true, ev.Stage2 == true
	rewards.Visible = ev.Stage1 == true or ev.Stage2 == true
	note.Visible = ev.Short == true
end)

RunService.Heartbeat:Connect(function()
	local inEvent = player:GetAttribute("BossEvent") == true
	if inEvent and seen then
		close()
	end
	local show = message ~= nil and not inEvent -- above any panel the return opens, such as Daily
	seen = seen or show
	if show and not panel.Visible then
		UiMotion.Pop(panel)
		UiFeedback.Play("ToastHigh")
	end
	panel.Visible = show
	root.Enabled = show -- never above the showcase or loser screens while closed
end)
