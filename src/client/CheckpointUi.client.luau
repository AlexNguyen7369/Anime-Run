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
-- A label in one of AnimeSkin's five text roles (design doc 4.42). color: replaces the role's colour. fit: long words
-- shrink to the Caption floor on one line. Again next frame, after AnimeSkin.Label's own pass.
local function role(label, name, color, fit)
	AnimeSkin.Label(label, name)
	local function after()
		if color then
			label.TextColor3 = color
		end
		if fit then
			label.TextScaled = true
			label.TextWrapped = false
			local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
				or make("UITextSizeConstraint", "Fit", label, {})
			limit.MaxTextSize = AnimeSkin.Px(AnimeSkin.Size[name])
			limit.MinTextSize = AnimeSkin.Px(AnimeSkin.Size.Caption)
		end
	end
	after()
	task.defer(after)
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
-- No HudIcons art for tracks: a finish flag glyph fills the standard header's logo slot (AnimeSkin.Header places it).
caption("Flag", panel.Header.Icon, { Size = UDim2.fromScale(1, 1), Text = "🏁", ZIndex = 4 }).Outline.Enabled = false
local HINT = "Click a track: your runs start there. Tracks past it in one run pay a bonus."
local hint = role(
	caption("Hint", panel, {
		Text = HINT,
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
	"Body",
	nil,
	true
)

local list = make("ScrollingFrame", "Cards", panel, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
-- 2 px top and bottom: the plate has no edge for the list to clip. Cards are 12 apart.
local CARD_GAP, CARD_PAD, CARD_MIN = 12, 2, 100
make("UIPadding", "Pad", list, {
	PaddingTop = UDim.new(0, CARD_PAD),
	PaddingBottom = UDim.new(0, CARD_PAD),
})
make("UIListLayout", "List", list, {
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, CARD_GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
-- Design doc 4.42: the hint 12 under the header (one Body line), the list 12 under it, 16 in and 16 from the bottom.
local function place()
	local inset, top = AnimeSkin.Px(AnimeSkin.Space.Inset), AnimeSkin.Top(false)
	local line = AnimeSkin.Px(AnimeSkin.Size.Body) + 4
	hint.Position, hint.Size = UDim2.fromOffset(inset, top), UDim2.new(1, -2 * inset, 0, line)
	local listTop = top + line + AnimeSkin.Px(AnimeSkin.Space.Gap)
	list.Position = UDim2.fromOffset(inset, listTop)
	list.Size = UDim2.new(1, -2 * inset, 1, -listTop - AnimeSkin.Px(AnimeSkin.Space.Bottom))
	list.ScrollBarThickness = 6
	list.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
end
place()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
end
-- As many whole cards as fit (at least CARD_MIN tall) fill the visible area, so no card is cut at the frame.
local function fitCards()
	local room = list.AbsoluteSize.Y - 2 * CARD_PAD
	local count = math.max(1, math.floor((room + CARD_GAP) / (CARD_MIN + CARD_GAP)))
	local tall = math.max(CARD_MIN, math.floor((room - (count - 1) * CARD_GAP) / count))
	for _, card in list:GetChildren() do
		if card:IsA("GuiButton") then
			card.Size = UDim2.new(1, -18, 0, tall)
		end
	end
end
list:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCards)

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
	-- Card layout (design doc 4.42), left to right: the diamond, 12, the road shot, 12, the text column. The plate's
	-- slanted ends take about 16 px, so content starts 28 in from the left and stops 32 in from the right (12 clear of
	-- the art). Top to bottom in the text column: title, 8, description, 8, stats, each 12 from the card's top and bottom.
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
	-- Design doc 4.42: the slanted plate replaces the card's fill and edge; its tint marks the checkpoint.
	local plate = AnimeSkin.Plate(card, VIOLET)
	-- 40 square turned 45 degrees: 57 across, its left tip 28 in, inside the plate.
	local diamond = make("Frame", "Diamond", card, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 56, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		Rotation = 45,
		BackgroundColor3 = CARD_DEEP,
		BorderSizePixel = 0,
		Active = false,
	})
	make("UIStroke", "Stroke", diamond, { Color = VIOLET, Thickness = 2 })
	role(
		caption("Number", card, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 56, 0.5, 0),
			Size = UDim2.fromOffset(32, 24),
			Text = tostring(n),
			ZIndex = 2,
		}),
		"Item"
	)
	local road = make("ImageLabel", "Road", card, {
		Position = UDim2.fromOffset(96, 12),
		Size = UDim2.new(0, 150, 1, -24),
		ScaleType = Enum.ScaleType.Crop,
		Image = TrackCards[n].Road or "",
		BackgroundColor3 = CARD_DEEP,
	})
	corner(road, UiTheme.Radius.S)
	local TEXT_X, TEXT_W = 258, -290 -- 96 + 150 + 12; ends 32 from the card's right
	role(
		caption("Title", card, {
			Position = UDim2.fromOffset(TEXT_X, 12),
			Size = UDim2.new(1, TEXT_W, 0, 20),
			Text = biomeName(spec),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		"Item"
	)
	role(
		caption("Blurb", card, {
			Position = UDim2.fromOffset(TEXT_X, 40),
			Size = UDim2.new(1, TEXT_W, 1, -76),
			Text = TrackCards[n].Blurb,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		"Caption"
	)
	-- Speed and Enemy split the text column, 12 apart.
	role(
		caption("Speed", card, {
			Position = UDim2.new(0, TEXT_X, 1, -28),
			Size = UDim2.new(0.5, TEXT_W / 2 - 6, 0, 16),
			Text = "RECOMMENDED SPEED " .. HudFormat.SpeedText(NpcConfig.RecommendedSpeed(n)),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		"Body",
		STAT,
		true
	)
	role(
		caption("Enemy", card, {
			Position = UDim2.new(0.5, TEXT_X + TEXT_W / 2 + 6, 1, -28),
			Size = UDim2.new(0.5, TEXT_W / 2 - 6, 0, 16),
			Text = "ENEMY " .. enemy.Label,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		"Body",
		STAT,
		true
	)
	-- Over the Road's bottom right corner, 4 in: nothing else sits there, so it never covers text.
	local chip = role(
		caption("Chip", card, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(0, 242, 1, -16),
			Size = UDim2.fromOffset(130, 20),
			Text = "YOUR CHECKPOINT",
			BackgroundColor3 = UiTheme.Palette.MoneyDeep,
			Visible = false,
			ZIndex = 2,
		}),
		"Caption",
		Color3.new(1, 1, 1),
		true
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
	-- Both over the Road image (x 96 to 246), clear of the card's text.
	caption("Icon", lock, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0, 171, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		Text = "🔒",
		ZIndex = 4,
	}).Outline.Enabled =
		false
	role(
		caption("Need", lock, {
			Position = UDim2.new(0, 96, 0.5, 4),
			Size = UDim2.fromOffset(150, 20),
			Text = "Beat Track " .. (n - 1),
			ZIndex = 4,
		}),
		"Body",
		nil,
		true
	)
	card.Activated:Connect(function()
		pick(n, card)
	end)
	cards[n] = { Edge = edge, Plate = plate, Chip = chip, Lock = lock }
end

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
fitCards()
render()
