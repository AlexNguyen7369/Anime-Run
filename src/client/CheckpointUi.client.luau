--!nonstrict
-- Tracks panel (design doc 4.15, owner 2026-11-04): opened by the plaza sensei's OpenCheckpoints prompt. One scrolling
-- list of long cards, one per track (number, road screenshot, biome name, definition, recommended speed, enemy, lock).
-- Clicking an open card picks it as the checkpoint; the server decides (Remotes.SetCheckpoint), the panel only shows
-- the attributes Checkpoint and BestTrack.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local TrackRegistry = require(shared.TrackRegistry)
local TrackCards = require(shared.TrackCards)
local CheckpointConfig = require(shared.CheckpointConfig)
local Themes = require(shared.BiomeThemes)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local HudFormat = require(shared.HudFormat)
local NpcConfig = require(shared.NpcConfig)
local UiTheme = require(shared.UiTheme)
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))

local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))

-- Owner reference (placeholder colours): dark violet card, number in a diamond, violet title, green stats.
local OUTLINE = UiTheme.Outline
local CARD = Color3.fromRGB(28, 18, 48)
local CARD_DEEP = Color3.fromRGB(16, 10, 30)
local VIOLET = Color3.fromRGB(170, 130, 255)
local SELECTED = UiTheme.Palette.Money
local STAT = UiTheme.Palette.Money

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function corner(parent, radius)
	make("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, radius) })
end
local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = UiTheme.Font
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextScaled = props.TextScaled ~= false
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round })
	return label
end

local root = make("ScreenGui", "CheckpointUi", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(760, 560),
	Visible = false,
	Active = true,
})
corner(panel, 16)
make("UIStroke", "Stroke", panel, { Color = OUTLINE, Thickness = 4 })
PanelSwitch.Register("Checkpoints", panel)

local close = PanelFrame.Attach(panel, { Theme = "Checkpoints", Title = "Tracks", MaxWidth = 760 }).Close
-- No HudIcons art for tracks: a finish flag glyph fills the header's icon slot.
caption("Flag", panel.Header.Icon, { Size = UDim2.fromScale(1, 1), Text = "🏁", ZIndex = 4 })
local HINT = "Click a track: your runs start there. Tracks past it in one run pay a bonus."
local hint = caption("Hint", panel, {
	Position = UDim2.fromOffset(16, 70),
	Size = UDim2.new(1, -32, 0, 24),
	Text = HINT,
	TextColor3 = Color3.fromRGB(210, 200, 230),
})

local list = make("ScrollingFrame", "Cards", panel, {
	Position = UDim2.fromOffset(16, 102),
	Size = UDim2.new(1, -32, 1, -114),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
-- Left, top and bottom leave room for the card's border stroke, which the list would clip.
make("UIPadding", "Pad", list, {
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 4),
	PaddingLeft = UDim.new(0, 2),
	PaddingRight = UDim.new(0, 8),
})
make("UIListLayout", "List", list, {
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

-- The biome's in-game name (the welcome popup's, design doc 4.17), e.g. "Shibuyo Underground"
local function biomeName(spec)
	local theme = Themes[spec.Biome or ""]
	return theme and theme.DisplayName or spec.Name or ""
end

local chain = TrackRegistry.Chain()
local cards = {}
local picking = false

local function pick(n, card)
	local best = player:GetAttribute("BestTrack")
	if not CheckpointConfig.IsOpen(n, best, #chain) then
		UiFeedback.Play("Denied", card)
		hint.Text = "Beat Track " .. (n - 1) .. " first"
		return
	end
	if picking or n == CheckpointConfig.Effective(player:GetAttribute("Checkpoint"), best, #chain) then
		return
	end
	picking = true
	-- pcall: a failed call must not leave the guard set, or no card could be picked again.
	local called, ok, reason = pcall(function()
		return remotes:WaitForChild("SetCheckpoint"):InvokeServer(n)
	end)
	picking = false
	if called and ok then
		UiFeedback.Play("Equip", card)
	else
		hint.Text = tostring(called and reason or "Try again")
		UiFeedback.Play("Denied", card)
	end
end

for _, spec in chain do
	local n = spec.Number
	local enemy = NpcConfig.For(n)
	local card = make("TextButton", "Track_" .. n, list, {
		LayoutOrder = n,
		Size = UDim2.new(1, -18, 0, 108), -- leaves room for the 1.035 hover scale (RacerMotion), which grows rightward
		BackgroundColor3 = CARD,
		Text = "",
		AutoButtonColor = false,
	})
	corner(card, UiTheme.Radius.M)
	local edge = make("UIStroke", "Stroke", card, {
		Color = VIOLET,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	local diamond = make("Frame", "Diamond", card, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 46, 0.5, 0),
		Size = UDim2.fromOffset(58, 58),
		Rotation = 45,
		BackgroundColor3 = CARD_DEEP,
		BorderSizePixel = 0,
		Active = false,
	})
	make("UIStroke", "Stroke", diamond, { Color = VIOLET, Thickness = 2 })
	caption("Number", card, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 46, 0.5, 0),
		Size = UDim2.fromOffset(44, 34),
		Text = tostring(n),
		ZIndex = 2,
	})
	local road = make("ImageLabel", "Road", card, {
		Position = UDim2.fromOffset(92, 10),
		Size = UDim2.fromOffset(158, 88),
		ScaleType = Enum.ScaleType.Crop,
		Image = TrackCards[n].Road or "",
		BackgroundColor3 = CARD_DEEP,
	})
	corner(road, UiTheme.Radius.S)
	caption("Title", card, {
		Position = UDim2.fromOffset(262, 8),
		Size = UDim2.new(1, -274, 0, 24),
		Text = biomeName(spec),
		TextColor3 = VIOLET,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local blurb = caption("Blurb", card, {
		Position = UDim2.fromOffset(262, 34),
		Size = UDim2.new(1, -274, 0, 42),
		Text = TrackCards[n].Blurb,
		TextColor3 = Color3.fromRGB(235, 230, 245),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	blurb.Outline.Thickness = 1 -- the helper's 2 px closes up text this small
	make("UITextSizeConstraint", "Fit", blurb, { MaxTextSize = 15, MinTextSize = 9 })
	-- Speed and Enemy split the (1, -274) text column, 8 px apart.
	caption("Speed", card, {
		Position = UDim2.fromOffset(262, 80),
		Size = UDim2.new(0.5, -141, 0, 20),
		Text = "RECOMMENDED SPEED " .. HudFormat.SpeedText(NpcConfig.RecommendedSpeed(n)),
		TextColor3 = STAT,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	caption("Enemy", card, {
		Position = UDim2.new(0.5, 129, 0, 80),
		Size = UDim2.new(0.5, -141, 0, 20),
		Text = "ENEMY " .. enemy.Label,
		TextColor3 = STAT,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- Over the Road's bottom right corner: nothing else sits there, so it never covers text.
	local chip = caption("Chip", card, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromOffset(246, 94),
		Size = UDim2.fromOffset(112, 20),
		Text = "YOUR CHECKPOINT",
		BackgroundColor3 = UiTheme.Palette.MoneyDeep,
		Visible = false,
		ZIndex = 2,
	})
	chip.BackgroundTransparency = 0 -- caption() makes labels transparent; this one is a chip
	corner(chip, 999)
	make("UIPadding", "Pad", chip, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	local lock = make("Frame", "Lock", card, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = 3,
		Active = false,
	})
	corner(lock, UiTheme.Radius.M)
	caption("Icon", lock, {
		-- Over the Road image, clear of the card's text
		Position = UDim2.fromOffset(151, 14),
		Size = UDim2.fromOffset(40, 40),
		Text = "🔒",
		ZIndex = 4,
	})
	caption("Need", lock, {
		Position = UDim2.fromOffset(92, 60),
		Size = UDim2.fromOffset(158, 24),
		Text = "Beat Track " .. (n - 1),
		ZIndex = 4,
	})
	card.Activated:Connect(function()
		pick(n, card)
	end)
	cards[n] = { Edge = edge, Chip = chip, Lock = lock }
end

local function render()
	local best = player:GetAttribute("BestTrack")
	local current = CheckpointConfig.Effective(player:GetAttribute("Checkpoint"), best, #chain)
	for n, refs in cards do
		refs.Lock.Visible = not CheckpointConfig.IsOpen(n, best, #chain)
		refs.Chip.Visible = n == current
		UiMotion.Mark(refs.Edge, { Color = n == current and SELECTED or VIOLET })
	end
end

local function closePanel()
	PanelSwitch.Close("Checkpoints")
end
close.Activated:Connect(closePanel)
PanelFrame.CloseOnOutsideClick(panel, closePanel)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	hint.Text = HINT
end)
player.AttributeChanged:Connect(function(attr)
	if attr == "Checkpoint" or attr == "BestTrack" then
		hint.Text = HINT
		render()
	end
end)
-- The hub NPC's prompt (built by Shared/SpawnArea on the server) toggles the panel.
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name == "OpenCheckpoints" then
		PanelSwitch.Toggle("Checkpoints")
	end
end)
UiTheme.Apply(root)
render()
