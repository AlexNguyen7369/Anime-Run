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
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

-- Placeholders, px.
local WIDTH, ROW, ART, AMOUNT = 400, 32, 64, 96
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
local px, space = AnimeSkin.Px, AnimeSkin.Space
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(px(WIDTH), 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Active = true,
	Visible = false,
})
UiTheme.Body(panel)
UiTheme.Corner(panel, "L")
UiTheme.Stroke(panel, 3, UiTheme.Outline, true)
-- Design doc 4.42 rhythm: the header full width at the top, rows 16 in from the sides, 12 apart, 16 above the bottom.
local list = make("UIListLayout", "List", panel, {
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, px(space.Gap)),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local padding = make("UIPadding", "Padding", panel, { PaddingBottom = UDim.new(0, px(space.Bottom)) })
local header = make("Frame", "Header", panel, {
	LayoutOrder = 0,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
})
-- Title keeps the server's words for the UI tests (UiBossPhase2 reads them exactly); Heading shows them in the standard
-- header's ALL CAPS, as AnimeSkin.Tab's caption does.
local title = make("TextLabel", "Title", header, {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(0, 0),
	Text = "",
	TextTransparency = 1,
})
local heading = make("TextLabel", "Heading", header, { Text = "" })
title:GetPropertyChangedSignal("Text"):Connect(function()
	heading.Text = title.Text
end)
local logo = make("ImageLabel", "Logo", header, { Image = RelicConfig.Chests[RAGA_CHEST].Image })
local closeButton = make("TextButton", "CloseButton", header, {
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
-- Design doc 4.42: framed body and the standard header (strip, chest logo: HudIcons has no boss icon, ALL CAPS title,
-- art close). The panel's UIListLayout would take the body art as a row, so it hangs from the header (ZIndex 0: every row
-- draws over it), sized to the whole panel in the header's unscaled px (a pop scales both).
AnimeSkin.Header(panel, { Header = header, Title = heading, Icon = logo, Close = closeButton })
AnimeSkin.Clear(panel)
header.ZIndex = 0
local body = AnimeSkin.Body(header)
local function fitBody()
	local scale = header.AbsoluteSize.Y / math.max(1, header.Size.Y.Offset)
	if scale <= 0 then
		return
	end
	local at = (panel.AbsolutePosition - header.AbsolutePosition) / scale
	local size = panel.AbsoluteSize / scale
	body.Position = UDim2.fromOffset(at.X - 8, at.Y - 8)
	body.Size = UDim2.fromOffset(size.X + 16, size.Y + 16)
end
for _, signal in
	{
		panel:GetPropertyChangedSignal("AbsoluteSize"),
		header:GetPropertyChangedSignal("AbsoluteSize"),
		header:GetPropertyChangedSignal("AbsolutePosition"),
	}
do
	signal:Connect(fitBody)
end
fitBody()
local damage = label("Damage", panel, { LayoutOrder = 1, Text = "" }, 24)
AnimeSkin.Label(damage, "Item")
local rewards = make("Frame", "Rewards", panel, {
	LayoutOrder = 2,
	BackgroundTransparency = 1,
})
local tiles = make("UIListLayout", "List", rewards, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local function chestArt(id, order)
	return make("ImageLabel", "Chest_" .. id, rewards, {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Image = RelicConfig.Chests[id].Image,
		ScaleType = Enum.ScaleType.Fit,
	})
end
local ragaChest, adaptedChest = chestArt(RAGA_CHEST, 1), chestArt(ADAPTED_CHEST, 3)
local money = label("Money", rewards, {
	LayoutOrder = 2,
	Text = "$" .. HudFormat.Commas(Cfg.Phase1Money),
}, 22)
local gems = label("Gems", rewards, {
	LayoutOrder = 4,
	Text = HudFormat.Commas(Cfg.Phase2Gems),
}, 22)
for _, amount in { money, gems } do
	AnimeSkin.Label(amount, "Item")
end
-- Money keeps the game's cash green over the Item role's white (set again after Label's deferred pass).
money.TextColor3 = Palette.Money
task.defer(function()
	money.TextColor3 = Palette.Money
end)
local gemPad = make("UIPadding", "Padding", gems, {})
local gemIcon = make("ImageLabel", "Icon", gems, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	BackgroundTransparency = 1,
	Image = Icons.Gem.Image,
	ScaleType = Enum.ScaleType.Fit,
})
local note = make("TextLabel", "Note", panel, {
	LayoutOrder = 3,
	BackgroundTransparency = 1,
	Text = "Deal 5% for rewards",
})
AnimeSkin.Label(note, "Body")

-- Every rect from the tokens, again when the screen crosses the phone line.
local function place()
	local inset, row, art, amount = px(space.Inset), px(ROW), px(ART), px(AMOUNT)
	panel.Size = UDim2.fromOffset(px(WIDTH), 0)
	list.Padding = UDim.new(0, px(space.Gap))
	padding.PaddingBottom = UDim.new(0, px(space.Bottom))
	damage.Size = UDim2.new(1, -2 * inset, 0, px(24))
	rewards.Size = UDim2.new(1, -2 * inset, 0, art)
	tiles.Padding = UDim.new(0, px(space.Gap))
	ragaChest.Size, adaptedChest.Size = UDim2.fromOffset(art, art), UDim2.fromOffset(art, art)
	money.Size, gems.Size = UDim2.fromOffset(amount, row), UDim2.fromOffset(amount, row)
	gemPad.PaddingLeft = UDim.new(0, row)
	gemIcon.Size = UDim2.fromOffset(row, row)
	note.Size = UDim2.new(1, -2 * inset, 0, px(20))
end
place()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
end

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
