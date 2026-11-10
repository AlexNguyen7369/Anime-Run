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
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))

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
-- The Index frame (design doc 4.42) PanelFrame.Attach gives the panel, below: every size is in its units.
local g
-- Labels by text role; the layout sizes them again at the frame's scale. color: replaces the role's colour.
local roles = {}
local function role(label, name, color)
	roles[label] = { name, color }
	label.TextWrapped = false
	g.Role(label, name)
	if color then
		label.TextColor3 = color
	end
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

local chrome = PanelFrame.Attach(panel, { Theme = "Checkpoints", Title = "Tracks", MaxWidth = 760 })
local close = chrome.Close
g = chrome.Frame
-- No HudIcons art for tracks: a finish flag glyph fills the frame's logo slot.
caption("Flag", panel.Header.Icon, { Size = UDim2.fromScale(1, 1), Text = "🏁", ZIndex = 12 }).Outline.Enabled = false
-- The hint is the frame's footer line; two lines on the plate, as it is long.
local HINT = "Click a track: your runs start there. Tracks past it in one run pay a bonus."
local hint = g.Footer(HINT)
hint.TextWrapped = true

local list = make("ScrollingFrame", "Cards", panel, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 6,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
})
local CARD_GAP, CARD_MIN = 12, 124 -- units; 124 holds title, one blurb line and the stats with 12 padding
local listLayout = make("UIListLayout", "List", list, {
	FillDirection = Enum.FillDirection.Vertical,
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
	-- Card layout (design doc 4.42), placed by placeCard in frame units.
	local card = make("TextButton", "Track_" .. n, list, {
		LayoutOrder = n,
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
	-- Design doc 4.42: the slanted plate replaces the card's fill and edge; its tint marks the checkpoint.
	local plate = AnimeSkin.Plate(card, VIOLET)
	local diamond = make("Frame", "Diamond", card, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = CARD_DEEP,
		BorderSizePixel = 0,
		Active = false,
	})
	make("UIStroke", "Stroke", diamond, { Color = VIOLET, Thickness = 2 })
	role(
		caption("Number", card, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = tostring(n),
			ZIndex = 2,
		}),
		"Item"
	)
	local road = make("ImageLabel", "Road", card, {
		ScaleType = Enum.ScaleType.Crop,
		Image = TrackCards[n].Road or "",
		BackgroundColor3 = CARD_DEEP,
	})
	corner(road, UiTheme.Radius.S)
	role(
		caption("Title", card, {
			Text = biomeName(spec),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		"Item"
	)
	role(
		caption("Blurb", card, {
			Text = TrackCards[n].Blurb,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		"Caption"
	).TextWrapped =
		true
	role(
		caption("Speed", card, {
			Text = "RECOMMENDED SPEED " .. HudFormat.SpeedText(NpcConfig.RecommendedSpeed(n)),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		"Body",
		STAT
	)
	role(
		caption("Enemy", card, {
			Text = "ENEMY " .. enemy.Label,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		"Body",
		STAT
	)
	-- Over the Road's bottom right corner: nothing else sits there, so it never covers text.
	local chip = role(
		caption("Chip", card, {
			AnchorPoint = Vector2.new(1, 1),
			Text = "YOUR CHECKPOINT",
			BackgroundColor3 = UiTheme.Palette.MoneyDeep,
			Visible = false,
			ZIndex = 2,
		}),
		"Caption",
		Color3.new(1, 1, 1)
	)
	chip.BackgroundTransparency = 0 -- caption() makes labels transparent; this one is a chip
	corner(chip, 4) -- design doc 4.42: 4 px corners, no pills
	make("UIPadding", "Pad", chip, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
	local lock = make("Frame", "Lock", card, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = 3,
		Active = false,
	})
	corner(lock, UiTheme.Radius.M)
	-- Both over the Road image, clear of the card's text.
	caption("Icon", lock, {
		AnchorPoint = Vector2.new(0.5, 1),
		Text = "🔒",
		ZIndex = 4,
	}).Outline.Enabled =
		false
	role(
		caption("Need", lock, {
			Text = "Beat Track " .. (n - 1),
			ZIndex = 4,
		}),
		"Body"
	)
	card.Activated:Connect(function()
		pick(n, card)
	end)
	cards[n] = { Edge = edge, Plate = plate, Chip = chip, Lock = lock }
end

-- One card, h units tall. Left to right: the number diamond (its tip 24 in from the plate's left end), 12, the road
-- shot, 12, the text column, which stops 24 from the plate's right end. Text column, top down: title, 8, description,
-- 8, speed and enemy (12 apart), 12 padding at the top and bottom.
local function placeCard(card, h, roadW)
	local px = g.px
	g.Place(card.Diamond, 24 + 28, h / 2, 40, 40) -- 40 square turned 45 degrees: 57 across
	g.Place(card.Number, 24 + 28, h / 2, 40, 34)
	card.Diamond.AnchorPoint, card.Number.AnchorPoint = Vector2.new(0.5, 0.5), Vector2.new(0.5, 0.5)
	local roadX = 24 + 57 + 12
	g.Place(card.Road, roadX, 12, roadW, h - 24)
	local x = roadX + roadW + 12
	local textW = UDim.new(1, -px(x + 24))
	card.Title.Position, card.Title.Size = g.at(x, 12), UDim2.new(textW, UDim.new(0, px(34)))
	local blurbH = h - 12 - 34 - 8 - 8 - 28 - 12
	card.Blurb.Visible = blurbH >= 22
	card.Blurb.Position, card.Blurb.Size = g.at(x, 54), UDim2.new(textW, UDim.new(0, px(math.max(0, blurbH))))
	-- Speed and Enemy split the text column, 12 apart.
	local half = UDim.new(0.5, -px((x + 24) / 2 + 6))
	card.Speed.Position, card.Speed.Size = g.at(x, h - 12 - 28), UDim2.new(half, UDim.new(0, px(28)))
	card.Enemy.Position = UDim2.new(0.5, px(x - (x + 24) / 2 + 6), 0, px(h - 12 - 28))
	card.Enemy.Size = card.Speed.Size
	local chip = card.Chip
	chip.AnchorPoint = Vector2.new(1, 1)
	chip.Position, chip.Size = g.at(roadX + roadW - 4, h - 16), g.at(math.min(150, roadW - 8), 22)
	local lock = card.Lock
	lock.Icon.AnchorPoint = Vector2.new(0.5, 1)
	lock.Icon.Position, lock.Icon.Size = g.at(roadX + roadW / 2, h / 2), g.at(36, 36)
	g.Place(lock.Need, roadX, h / 2 + 4, roadW, 28)
end

-- The cards fill the content area: as many whole cards as fit at CARD_MIN, 12 apart, so none is cut at the frame.
g.OnLayout(function()
	local c = g.Content
	for label, entry in roles do
		g.Role(label, entry[1])
		if entry[2] then
			label.TextColor3 = entry[2]
		end
	end
	g.Place(list, c.X, c.Y, c.W, c.H)
	listLayout.Padding = UDim.new(0, g.px(CARD_GAP))
	local count = math.max(1, math.floor((c.H + CARD_GAP) / (CARD_MIN + CARD_GAP)))
	local h = math.floor((c.H - (count - 1) * CARD_GAP) / count)
	local roadW = math.floor(c.W * 0.2)
	for _, card in list:GetChildren() do
		if card:IsA("GuiButton") then
			-- 18 px short: room for the 1.035 hover scale (RacerMotion), which grows rightward
			card.Size = UDim2.new(1, -18, 0, g.px(h))
			placeCard(card, h, roadW)
		end
	end
end)

local function render()
	local best = player:GetAttribute("BestTrack")
	local current = CheckpointConfig.Effective(player:GetAttribute("Checkpoint"), best, #chain)
	for n, refs in cards do
		refs.Lock.Visible = not CheckpointConfig.IsOpen(n, best, #chain)
		refs.Chip.Visible = n == current
		UiMotion.Mark(refs.Edge, { Color = n == current and SELECTED or VIOLET })
		refs.Plate.ImageColor3 = n == current and SELECTED or VIOLET
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
