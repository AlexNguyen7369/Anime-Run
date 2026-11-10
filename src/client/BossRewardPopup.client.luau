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

-- Placeholders, in the Index frame's units: the chest art and the amount beside it.
local WIDTH, ART, AMOUNT = 640, 200, 160 -- WIDTH in px at most, the Index's 920 x 620 aspect
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
	Active = true,
	Visible = false,
})
UiTheme.Body(panel)
UiTheme.Corner(panel, "L")
UiTheme.Stroke(panel, 3, UiTheme.Outline, true)
local header = make("Frame", "Header", panel, {
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
-- Design doc 4.42: the Index frame (chest logo: HudIcons has no boss icon, ALL CAPS title, art close); the rows sit
-- in its content area, in its units (place below).
local g = AnimeSkin.IndexFrame(panel, { Header = header, Title = heading, Icon = logo, Close = closeButton })
local damage = label("Damage", panel, { Text = "" }, 24)
local rewards = make("Frame", "Rewards", panel, {
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
local gemPad = make("UIPadding", "Padding", gems, {})
local gemIcon = make("ImageLabel", "Icon", gems, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	BackgroundTransparency = 1,
	Image = Icons.Gem.Image,
	ScaleType = Enum.ScaleType.Fit,
})
local note = make("TextLabel", "Note", panel, {
	BackgroundTransparency = 1,
	Text = "Deal 5% for rewards",
})

-- The popup's px size keeps the frame's aspect and its chrome on screen; k follows from it.
local function size()
	local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local U = AnimeSkin.Units
	local w, h = AnimeSkin.Compact() and U.PhoneW or U.W, AnimeSkin.Compact() and U.PhoneH or U.H
	local width = math.min(WIDTH, (view.X - 32) * w / (w + 80), (view.Y - 32) * w / (h + 100))
	panel.Size = UDim2.fromOffset(math.floor(width), math.floor(width * h / w))
end
size()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(size)
end
-- Damage (Item) on top, the chest tiles 12 apart under it, the note (Body) at the content's bottom.
g.OnLayout(function()
	local c, U = g.Content, AnimeSkin.Units
	local item = AnimeSkin.UnitSize.Item
	local art = math.min(ART, c.H - 2 * item - 2 * U.Gap)
	g.Place(damage, c.X, c.Y, c.W, item)
	g.Place(rewards, c.X, c.Y + item + U.Gap, c.W, c.H - 2 * (item + U.Gap))
	tiles.Padding = UDim.new(0, g.px(U.Gap))
	ragaChest.Size, adaptedChest.Size = g.at(art, art), g.at(art, art)
	money.Size, gems.Size = g.at(AMOUNT, item), g.at(AMOUNT, item)
	gemPad.PaddingLeft = UDim.new(0, g.px(item))
	gemIcon.Size = g.at(item, item)
	g.Place(note, c.X, c.Y + c.H - AnimeSkin.UnitSize.Body, c.W, AnimeSkin.UnitSize.Body)
	for _, text in { damage, money, gems } do
		g.Role(text, "Item")
	end
	g.Role(note, "Body")
	money.TextColor3 = Palette.Money -- the game's cash green over the Item white
end)

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
