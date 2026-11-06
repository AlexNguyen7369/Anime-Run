--!nonstrict
-- Boss event UI (design doc 4.37, docs/BOSS_EVENT_SPEC.md Flow and Team HUD). Contract: Client/UiTest/UiBossEvent. Display only:
-- it follows the server's attributes (ReplicatedStorage BossEvent* and BossStatus, player BossEvent, BossTeamDamage and BossWaitEndsAt) and asks through
-- Remotes.BossEventTeleport, BossEventSetTeam and BossEventLeave. Every part is built once and only hidden.
-- Sound and effects are not in yet. Hook, when they are approved: UiFeedback.Play with an existing cue where "cue:" is marked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(shared:WaitForChild("BossEventConfig"))
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local RelicConfig = require(shared:WaitForChild("RelicConfig"))
local CharacterCatalog = require(shared:WaitForChild("CharacterCatalog"))
local CharacterHeads = require(shared:WaitForChild("CharacterHeads"))
local CharacterPortraits = require(shared:WaitForChild("CharacterPortraits"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local SidekickArt = require(shared:WaitForChild("SidekickArt"))
local StaminaConfig = require(shared:WaitForChild("StaminaConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local Palette = UiTheme.Palette
local PanelBand = require(script.Parent:WaitForChild("PanelBand"))
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local WARNING_TEXT = "Big Raga has emerged, take him down!!!" -- design doc 4.37
local NOTE_TEXT = "Only characters with Sidekicks can be equipped for bosses" -- BOSS_EVENT_SPEC
-- Placeholders.
local WARNING_SECONDS = 6
local FLASH_PERIOD = 0.3 -- s one way: under 2 flashes a second
local WARNING_BRIGHT = Color3.fromRGB(235, 20, 30)
local WARNING_MAX_HEIGHT = 0.18 -- of the screen; it also ends above the middle, short of Big Raga's body
local BOSS_BUTTON_GAP = 8 -- px past Roblox's buttons
local BOSS_BUTTON_SIZE = Vector2.new(128, 40) -- at most: the width follows the screen
local BOSS_BUTTON_WIDTH = 0.15 -- of the screen: at 667 wide, with the pulse and glow it ends at x 329, clear of Auto at 333
local PULSE_SCALE = 1.08
local PULSE_PERIOD = 0.6
local GLOW_THICK = 5
local PROMPT_SECONDS = 3
local LOCKED_TEXT = "Get a Sidekick and equip it to teleport"
local RESEND_GAP = 0.3 -- s between team sends: the server refuses a request inside its 0.25 s cooldown
local PHONE_MAX_HEIGHT = 500 -- the HUD's phone rule
local PHONE_TOP = 56 -- px: under the top row. On a phone the band's top is too low, and the roll it clears is hidden or below
local BAR_LOW_TOP = 58 -- px: under the top row and Roblox's reserved top-left (x 0..360, y 0..58)
local BAR_HIGH_TOP = 10 -- px: where the bar fits between those two
local RESERVED_RIGHT = 360
local EXHAUSTED_TEXT = "Your team is exhausted. Reviving..."
local DIM_TRANSPARENCY = 0.65 -- "slightly dims" (BOSS_EVENT_SPEC "Exhaustion view")
local STATUS_GAP = 4 -- px under the bar
local STATUS_HEIGHT, STATUS_HEIGHT_PHONE = 28, 22
local STATUS_SECONDS, STATUS_SECONDS_PHONE = 14, 12
local WARNING_MIN_BELOW = 40 -- px: under the drop list only with this much room above the screen's middle, else left of the list
-- The icon is a plain in-house shape, a text glyph or a drawn wheel; no image upload. No digit in these texts: the countdown is the number.
local STATUS_LOOKS = {
	{ Id = "Shouted", Glyph = "!", Color = Palette.Danger },
	{ Id = "Adapted", Color = Palette.Gold }, -- the wheel turn that starts it
}

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
	props.Font = props.Font or UiTheme.Font
	props.TextColor3 = props.TextColor3 or Palette.White
	props.TextScaled = true
	local text = make("TextLabel", name, parent, props)
	make("UITextSizeConstraint", "Max", text, { MaxTextSize = maxSize })
	UiTheme.Stroke(text, 2)
	return text
end

-- Fixed text size, no size constraint: the LeaveButton is one of ui_layout's solved elements at every viewport.
local function button(name, parent, text, color, props)
	props.Text = text
	props.Font = UiTheme.Font
	props.TextSize = props.TextSize or 20
	props.TextColor3 = Palette.White
	props.BackgroundColor3 = color
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local object = make("TextButton", name, parent, props)
	UiTheme.Corner(object, "M")
	UiTheme.Stroke(object, 3, UiTheme.Outline, true)
	return object
end

-- PanelFrame's look without its Close and its band fit: neither part closes with an X, and each lays itself out here.
local function panel(name, title)
	local frame = make("Frame", name, nil, { Visible = false, Active = true, AnchorPoint = Vector2.new(0.5, 0.5) })
	UiTheme.Body(frame)
	UiTheme.Corner(frame, "L")
	UiTheme.Stroke(frame, 3, UiTheme.Outline, true)
	local header = make("Frame", "Header", frame, { BackgroundColor3 = Palette.White, BorderSizePixel = 0 })
	UiTheme.Corner(header, "L")
	local colors = PanelFrame.Themes.Daily
	make("UIGradient", "Gradient", header, { Color = ColorSequence.new(colors[1], colors[2]) })
	label("Title", header, {
		Position = UDim2.fromScale(0.03, 0.14),
		Size = UDim2.fromScale(0.62, 0.72),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 28)
	label("Countdown", header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.97, 0.14),
		Size = UDim2.fromScale(0.28, 0.72),
		Text = "",
		TextColor3 = Palette.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, 28)
	return frame, header, header.Countdown
end

local root = make("ScreenGui", "RacerBossEvent", playerGui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 13, -- above the panels and DuelUi (a duel keeps its invite), below the roll view (14)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Invite ------------------------------------------------------------------------------------------------------------------
local invite, inviteHeader, inviteCountdown = panel("Invite", "BIG RAGA EVENT")
invite.Parent = root
local inviteHint = label("Hint", invite, { Text = "", TextWrapped = true }, 22)
local teleport = button("TeleportButton", invite, "Teleport", Palette.MoneyDeep, {
	Position = UDim2.fromOffset(8, 0),
})
local decline = button("DeclineButton", invite, "Decline", Palette.TabIdle, {
	AnchorPoint = Vector2.new(1, 0),
})

-- Team HUD ----------------------------------------------------------------------------------------------------------------
local hud, hudHeader, hudCountdown = panel("TeamHud", "CHOOSE YOUR TEAM")
hud.Parent = root
local slots = {}
for i = 1, StaminaConfig.TEAM_SIZE do
	-- RacerHover before parenting: Ui/RacerMotion owes a Frame with a CharacterId its HoverScale, and looks only when it is added.
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. i
	slot.BackgroundColor3 = Palette.TeamDim
	slot.BorderSizePixel = 0
	slot:SetAttribute("RacerHover", true)
	UiTheme.Corner(slot, "M")
	UiTheme.Stroke(slot, 2, Palette.Muted, true)
	slot.Parent = hud
	local number = label("Number", slot, {
		Position = UDim2.fromScale(0.2, 0.2),
		Size = UDim2.fromScale(0.6, 0.6),
		Text = tostring(i),
		TextColor3 = Palette.Muted,
	}, 28)
	local head = make("ImageLabel", "Head", slot, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	})
	local badge = make("ImageLabel", "Sidekick", slot, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromScale(0.42, 0.42),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	})
	slots[i] = { Frame = slot, Number = number, Head = head, Badge = badge }
end
local teamDamage = label("TeamDamage", hud, {
	Text = "",
	TextColor3 = Palette.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, 26)
local note = label("Note", hud, {
	Text = NOTE_TEXT,
	TextColor3 = Palette.SoftText,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
}, 16)
local list = make("ScrollingFrame", "List", hud, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Palette.Muted,
})
make("UIPadding", "Padding", list, {
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 4),
	PaddingLeft = UDim.new(0, 4),
	PaddingRight = UDim.new(0, 10), -- clear of the scroll bar
})
local listGrid = make("UIGridLayout", "Grid", list, {
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

-- Warning, BossBar, LeaveButton -------------------------------------------------------------------------------------------
local warning = make("Frame", "Warning", root, {
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
})
local warningLabel = label("Text", warning, {
	Size = UDim2.fromScale(1, 1),
	Text = WARNING_TEXT,
	Font = Enum.Font.GothamBlack,
	TextColor3 = WARNING_BRIGHT,
	TextWrapped = true,
}, 72)
local warningStroke = UiTheme.Stroke(warningLabel, 3, Color3.new(0, 0, 0))

local bar =
	make("Frame", "BossBar", root, { AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Visible = false })
local barTitle = label("Title", bar, {
	Text = "Big Raga",
	Font = Enum.Font.GothamBlack,
}, 24)
local track = make("Frame", "Track", bar, {
	BackgroundColor3 = Palette.TeamTired,
	BorderSizePixel = 0,
})
UiTheme.Corner(track, "S")
UiTheme.Stroke(track, 2, Palette.Gold, true)
local fill = make("Frame", "Fill", track, {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Palette.White,
	BorderSizePixel = 0,
})
UiTheme.Corner(fill, "S")
-- Two bands with a hard edge, bright over deep.
UiTheme.Gradient(fill, Palette.Danger, Palette.DangerDeep).Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Palette.Danger),
	ColorSequenceKeypoint.new(0.5, Palette.Danger),
	ColorSequenceKeypoint.new(0.501, Palette.DangerDeep),
	ColorSequenceKeypoint.new(1, Palette.DangerDeep),
})
local barValue = label("Value", bar, { Text = "", ZIndex = 2 }, 20) -- above the Track and its Fill

-- Under the bar's left side, with the bar on screen and off: the Warning sits below this row.
local statusRow = make("Frame", "Status", bar, { BackgroundTransparency = 1 })
make("UIListLayout", "List", statusRow, {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local statusCells = {}
for order, look in STATUS_LOOKS do
	local cell = make("Frame", "Status_" .. look.Id, statusRow, {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Visible = false,
	})
	local icon = make("ImageLabel", "Icon", cell, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundColor3 = look.Color,
		BorderSizePixel = 0,
	})
	UiTheme.Corner(icon, "S")
	UiTheme.Stroke(icon, 2, UiTheme.Outline, true)
	if look.Glyph then
		label("Glyph", icon, { Size = UDim2.fromScale(1, 1), Text = look.Glyph }, 20)
	else
		local wheel = make("Frame", "Wheel", icon, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			BackgroundTransparency = 1,
		})
		make("UICorner", "Round", wheel, { CornerRadius = UDim.new(1, 0) })
		UiTheme.Stroke(wheel, 2, UiTheme.Outline, true)
		for name, size in { Across = UDim2.new(1, 0, 0, 2), Down = UDim2.new(0, 2, 1, 0) } do
			make("Frame", name, wheel, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = size,
				BackgroundColor3 = UiTheme.Outline,
				BorderSizePixel = 0,
			})
		end
	end
	statusCells[look.Id] = {
		Frame = cell,
		Icon = icon,
		Left = label("Seconds", cell, { Text = "", TextColor3 = Palette.Gold }, 14),
	}
end

-- Under the bar's right side (BOSS_EVENT_SPEC "Boss bar"). Display only, nothing in it is Active.
local dropList = make("Frame", "DropList", root, { BackgroundTransparency = 1, Visible = false })
make("UIListLayout", "List", dropList, { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder })
local dropHeading = label("Heading", dropList, {
	LayoutOrder = 1,
	Text = "Drop:",
	TextXAlignment = Enum.TextXAlignment.Left,
}, 18)
local dropRule = make("Frame", "Rule", dropList, {
	LayoutOrder = 2,
	BackgroundColor3 = Palette.SoftText,
	BorderSizePixel = 0,
})
local dropRows = {}
local function dropRow(id, text, color, stroke)
	local row = label("Row_" .. id, dropList, {
		LayoutOrder = 3 + #dropRows,
		Text = text,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 15)
	UiTheme.Stroke(row, 1, stroke)
	table.insert(dropRows, row)
end
local dropOdds = RelicConfig.Odds("big_raga")
table.sort(dropOdds, function(a, b)
	return a.Odds > b.Odds
end)
for _, row in dropOdds do
	-- Secret's near-black needs the light outline Big Raga's black has.
	dropRow(
		row.Id,
		("%s %s%%"):format(row.Name, tostring(row.Odds)),
		GachaConfig.RARITY_COLORS[row.Rarity],
		row.Rarity == "Secret" and Palette.White or nil
	)
end
dropRow(
	"side_raga",
	("Big Raga %.3f%%"):format(RelicConfig.RagaSidekickChance * 100),
	Color3.new(0, 0, 0),
	Palette.White
)

-- One rect at every viewport (ui_layout solves it there): under the top-right row, above the Shop column, right of the band.
local leave = button("LeaveButton", root, "LEAVE", Palette.Danger, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 56),
	Size = UDim2.fromOffset(62, 44),
	TextSize = 18,
	Visible = false,
})

-- The top-left button. Its pulse grows right and down from a fixed corner, so it never reaches Roblox's buttons. PulseScale goes in
-- first: RacerMotion adds a HoverScale once the button is in the gui, and the first UIScale is the one that draws.
local bossButton = button("BossButton", nil, "Boss (Active)", Palette.Danger, {
	Size = UDim2.new(BOSS_BUTTON_WIDTH, 0, 0, BOSS_BUTTON_SIZE.Y), -- scale, not a live write: ui_layout solves it at every viewport
	TextSize = 14,
	Visible = false,
})
make("UISizeConstraint", "MaxWidth", bossButton, { MaxSize = BOSS_BUTTON_SIZE })
make("UIScale", "PulseScale", bossButton, {})
local bossGlow = bossButton.ThemeStroke
bossGlow.Name = "Glow"
bossGlow.Color = Palette.Gold
bossButton.Parent = root
local bossPrompt = label("BossPrompt", root, {
	Size = UDim2.fromOffset(300, 24),
	Text = LOCKED_TEXT,
	TextColor3 = Palette.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
}, 18)

local function placeBossButton()
	local inset = GuiService.TopbarInset
	local x = inset.Min.X + BOSS_BUTTON_GAP
	local y = math.max(2, (inset.Max.Y - BOSS_BUTTON_SIZE.Y) / 2)
	bossButton.Position = UDim2.fromOffset(x, y)
	bossPrompt.Position = UDim2.fromOffset(x, y + BOSS_BUTTON_SIZE.Y + 6)
end
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeBossButton)
placeBossButton()

-- The exhaustion view: under every other part (ZIndex 0), so that the bar, its status row and Leave read and press above the dim.
local exhausted = make("Frame", "ExhaustedPanel", root, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 0,
	Visible = false,
})
make("Frame", "Dim", exhausted, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = DIM_TRANSPARENCY,
	BorderSizePixel = 0,
	ZIndex = 0,
})
label("Message", exhausted, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.43),
	Size = UDim2.fromScale(0.8, 0.11),
	Text = EXHAUSTED_TEXT,
	Font = Enum.Font.GothamBlack,
}, 48)
local exhaustedCount = label("Countdown", exhausted, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.56),
	Size = UDim2.fromScale(0.3, 0.14),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextColor3 = Palette.Gold,
}, 84)
local loading = make("Frame", "Loading", exhausted, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.67),
	Size = UDim2.new(0.4, 0, 0, 18),
	BackgroundColor3 = Palette.TeamTired,
	BorderSizePixel = 0,
})
UiTheme.Corner(loading, "S")
UiTheme.Stroke(loading, 2, UiTheme.Outline, true)
local loadingFill = make("Frame", "Fill", loading, {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Palette.Gold,
	BorderSizePixel = 0,
})
UiTheme.Corner(loadingFill, "S")

-- Layout ------------------------------------------------------------------------------------------------------------------
local lastLayout = nil

local function placeInvite(phone, left, top, right, bottom)
	local width = math.min(right - left, phone and 400 or 460)
	local height = math.min(bottom - top, phone and 150 or 210)
	local head = phone and 34 or 46
	local press = phone and 44 or 52
	invite.Position = UDim2.fromOffset((left + right) / 2, (top + bottom) / 2)
	invite.Size = UDim2.fromOffset(width, height)
	inviteHeader.Size = UDim2.new(1, 0, 0, head)
	inviteHint.Position = UDim2.fromOffset(12, head + 4)
	inviteHint.Size = UDim2.new(1, -24, 0, math.max(0, height - head - press - 20))
	teleport.Position = UDim2.new(0, 8, 1, -press - 8)
	teleport.Size = UDim2.new(0.5, -12, 0, press)
	decline.Position = UDim2.new(1, -8, 1, -press - 8)
	decline.Size = UDim2.new(0.5, -12, 0, press)
end

local function placeHud(phone, left, top, right, bottom)
	local width = math.min(right - left, phone and 560 or 640)
	local height = math.min(bottom - top, 410)
	local head = phone and 30 or 46
	local side = phone and 48 or 72
	local gap = phone and 6 or 8
	hud.Position = UDim2.fromOffset((left + right) / 2, (top + bottom) / 2)
	hud.Size = UDim2.fromOffset(width, height)
	hudHeader.Size = UDim2.new(1, 0, 0, head)
	local slotTop = head + gap
	for i, slot in slots do
		slot.Frame.Position = UDim2.fromOffset(8 + (i - 1) * (side + gap), slotTop)
		slot.Frame.Size = UDim2.fromOffset(side, side)
	end
	local slotsEnd = 8 + #slots * (side + gap)
	if phone then
		-- Two columns: the band is short and wide, and the list keeps its own scroll.
		local column = math.floor(width * 0.46)
		local belowSlots = slotTop + side + 2
		teamDamage.Position = UDim2.fromOffset(8, belowSlots)
		teamDamage.Size = UDim2.fromOffset(column - 8, 20)
		note.Position = UDim2.fromOffset(8, belowSlots + 22)
		note.Size = UDim2.fromOffset(column - 8, math.max(0, height - belowSlots - 28))
		list.Position = UDim2.fromOffset(column + 4, slotTop)
		list.Size = UDim2.fromOffset(width - column - 12, math.max(0, height - slotTop - 6))
		listGrid.CellSize = UDim2.fromOffset(58, 58)
	else
		teamDamage.Position = UDim2.fromOffset(slotsEnd + 8, slotTop)
		teamDamage.Size = UDim2.fromOffset(width - slotsEnd - 20, side)
		local noteTop = slotTop + side + 4
		note.Position = UDim2.fromOffset(12, noteTop)
		note.Size = UDim2.fromOffset(width - 24, 22)
		local listTop = noteTop + 26
		list.Position = UDim2.fromOffset(8, listTop)
		list.Size = UDim2.fromOffset(width - 16, math.max(0, height - listTop - 8))
		listGrid.CellSize = UDim2.fromOffset(88, 100)
	end
end

local function placeTop(phone, size, row)
	local width = math.clamp(size.X * 0.42, 280, 620)
	local barLeft = (size.X - width) / 2
	local fits = barLeft >= RESERVED_RIGHT and row and barLeft + width + 8 <= row.AbsolutePosition.X
	local barTop = fits and BAR_HIGH_TOP or BAR_LOW_TOP
	local titleHeight, trackHeight = phone and 16 or 24, phone and 20 or 26
	local height = titleHeight + 2 + trackHeight
	bar.Position = UDim2.new(0.5, 0, 0, barTop)
	bar.Size = UDim2.fromOffset(width, height)
	barTitle.Size = UDim2.new(1, 0, 0, titleHeight)
	track.Position = UDim2.fromOffset(0, titleHeight + 2)
	track.Size = UDim2.new(1, 0, 0, trackHeight)
	barValue.Position = UDim2.fromOffset(8, titleHeight + 3)
	barValue.Size = UDim2.new(1, -16, 0, trackHeight - 2)

	local iconSize = phone and STATUS_HEIGHT_PHONE or STATUS_HEIGHT
	local secondsHeight = phone and STATUS_SECONDS_PHONE or STATUS_SECONDS
	local statusHeight = iconSize + secondsHeight
	statusRow.Position = UDim2.new(0, 0, 1, STATUS_GAP)
	statusRow.Size = UDim2.new(0.5, -4, 0, statusHeight)
	for _, cell in statusCells do
		cell.Frame.Size = UDim2.fromOffset(iconSize + 8, statusHeight)
		cell.Icon.Size = UDim2.fromOffset(iconSize, iconSize)
		cell.Left.Position = UDim2.fromOffset(0, iconSize)
		cell.Left.Size = UDim2.new(1, 0, 0, secondsHeight)
	end

	-- A short screen takes smaller rows, never fewer.
	local listTop = barTop + height + STATUS_GAP
	local headingHeight, ruleHeight = phone and 13 or 18, phone and 1 or 2
	local rowRoom = size.Y - listTop - 8 - headingHeight - ruleHeight - #dropRows - 1
	local rowHeight = math.clamp(math.floor(rowRoom / #dropRows), 8, phone and 11 or 15)
	local listHeight = headingHeight + ruleHeight + #dropRows * (rowHeight + 1) + 1
	local listWidth = math.min(width / 2, phone and 140 or 220)
	local listLeft = barLeft + width - listWidth
	dropList.Position = UDim2.fromOffset(listLeft, listTop)
	dropList.Size = UDim2.fromOffset(listWidth, listHeight)
	dropHeading.Size = UDim2.new(1, 0, 0, headingHeight)
	dropRule.Size = UDim2.new(1, 0, 0, ruleHeight)
	for _, row in dropRows do
		row.Size = UDim2.new(1, 0, 0, rowHeight)
	end

	-- Under the list where that still ends above the middle, else left of it.
	local warningEnd = size.Y / 2 - 8
	local warningTop = listTop + listHeight + 8
	local warningWidth = math.min(size.X * 0.86, 1100)
	local warningX = size.X / 2
	if warningEnd - warningTop < WARNING_MIN_BELOW then
		warningTop = listTop + statusHeight + 8
		warningWidth = listLeft - 16
		warningX = 8 + warningWidth / 2
	end
	warning.Position = UDim2.fromOffset(warningX, warningTop)
	warning.Size =
		UDim2.fromOffset(warningWidth, math.max(36, math.min(size.Y * WARNING_MAX_HEIGHT, warningEnd - warningTop)))
end

-- Follows the HUD while a part shows (PanelBand.Fit's way); the writes run only when a number changed.
local function layout()
	local size = workspace.CurrentCamera.ViewportSize
	local phone = size.Y <= PHONE_MAX_HEIGHT
	local left, top, right, bottom = PanelBand.Rect()
	if not left then
		left, top, right, bottom = size.X * 0.1, BAR_LOW_TOP, size.X * 0.9, size.Y - BAR_LOW_TOP
	end
	if phone then
		top = PHONE_TOP
	end
	local chrome = playerGui:FindFirstChild("HudChrome")
	local items = chrome and chrome:FindFirstChild("ItemsSlot")
	if items and items.Visible then
		-- Where Items and Upgrade stack above the bars, they stay reachable under the band's bottom.
		bottom = math.min(bottom, items.AbsolutePosition.Y + GuiService:GetGuiInset().Y - 6)
	end
	local row = chrome and chrome:FindFirstChild("TopRight")
	local key = table.concat({ size.X, size.Y, left, top, right, bottom, row and row.AbsolutePosition.X or -1 }, ",")
	if key == lastLayout then
		return
	end
	lastLayout = key
	placeInvite(phone, left, top, right, bottom)
	placeHud(phone, left, top, right, bottom)
	placeTop(phone, size, row)
end

-- Team --------------------------------------------------------------------------------------------------------------------
local cells = {} -- character id -> { Button, Edge, Badge }
local picks = {} -- ids in slot order; empty until the player picks: the server then chooses at the spawn
local confirmed = {} -- what the server last accepted
local sentKey = ""
local sending = false

local function art(id)
	local spec = CharacterCatalog.Get(id)
	local model = spec and spec.Model or id -- starters are drawn under the model they wear
	return CharacterHeads[id] or CharacterHeads[model] or CharacterPortraits[id] or CharacterPortraits[model] or ""
end

-- The drawn head of the Sidekick `entry`, or "" while it has no upload.
local function sidekickHead(entry)
	local row = entry and SidekickView.Row(player, entry)
	local drawn = row and SidekickArt[row.Id]
	return drawn and drawn.Head or ""
end

local function setBadge(badge, image)
	badge.Image = image
	badge.Visible = image ~= ""
end

local function drawPicks()
	local gear = SidekickView.Gear(player)
	for i, slot in slots do
		local id = picks[i]
		slot.Frame:SetAttribute("CharacterId", id)
		slot.Number.Visible = id == nil
		slot.Head.Visible = id ~= nil
		slot.Head.Image = id and art(id) or ""
		setBadge(slot.Badge, id and sidekickHead(gear[id]) or "")
		slot.Frame.ThemeStroke.Color = id and Palette.Gold or Palette.Muted
	end
	for id, cell in cells do
		cell.Edge.Color = table.find(picks, id) and Palette.Gold or UiTheme.Outline
	end
end

local function sendTeam()
	if sending then
		return
	end
	sending = true
	while #picks > 0 and sentKey ~= table.concat(picks, ",") do
		local team = table.clone(picks)
		local key = table.concat(team, ",")
		local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BossEventSetTeam")
		local called, ok = pcall(remote.InvokeServer, remote, team)
		if called and ok then
			confirmed, sentKey = team, key
		else
			picks = table.clone(confirmed)
			sentKey = table.concat(picks, ",")
			drawPicks()
			UiMotion.Shake(list, 6, 0.2)
		end
		task.wait(RESEND_GAP)
	end
	sending = false
end

local function press(id)
	local at = table.find(picks, id)
	-- The server has no empty team, so the last pick stays until another joins it. A full team takes no more.
	if (at and #picks == 1) or (not at and #picks >= #slots) then
		UiMotion.Shake(list, 6, 0.2)
		return
	end
	if at then
		table.remove(picks, at)
	else
		table.insert(picks, id)
	end
	drawPicks()
	task.spawn(sendTeam)
end

local function newCell(id, spec)
	local cell = button(id, list, "", Palette.Row, {})
	UiTheme.Corner(cell, "S")
	local edge = cell.ThemeStroke
	edge.Thickness = 2
	make("ImageLabel", "Head", cell, {
		Size = UDim2.fromScale(1, 0.72),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Image = art(id),
	})
	local badge = make("ImageLabel", "Sidekick", cell, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.4, 0.4),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
	})
	label("CharacterName", cell, {
		Position = UDim2.new(0, 2, 0.72, 0),
		Size = UDim2.new(1, -4, 0.26, 0),
		Text = spec.Name or id,
	}, 14)
	cell.Activated:Connect(function()
		press(id)
	end)
	return { Button = cell, Edge = edge, Badge = badge }
end

-- The list, the slots and the Invite's lock follow the published gear.
local function refreshGear()
	local gear = SidekickView.Gear(player)
	local rows = {}
	for id in gear do
		local spec = CharacterCatalog.Get(id) -- an id this version does not know cannot be slotted
		if spec then
			table.insert(rows, { Id = id, Spec = spec })
		end
	end
	table.sort(rows, function(a, b)
		return (a.Spec.Name or a.Id) < (b.Spec.Name or b.Id)
	end)
	local seen = {}
	for order, row in rows do
		seen[row.Id] = true
		cells[row.Id] = cells[row.Id] or newCell(row.Id, row.Spec)
		cells[row.Id].Button.LayoutOrder = order
		setBadge(cells[row.Id].Badge, sidekickHead(gear[row.Id]))
	end
	for id, cell in cells do
		if not seen[id] then
			cell.Button:Destroy()
			cells[id] = nil
		end
	end
	local kept = {}
	for _, id in picks do
		if seen[id] then
			table.insert(kept, id)
		end
	end
	picks = kept
	drawPicks()
	task.spawn(sendTeam) -- a pick that lost its Sidekick leaves the server's team too

	local locked = #rows == 0 -- READING in UiBossEvent: a Sidekick only in the Bag locks it, the server refuses that join
	teleport.Active = not locked
	teleport.BackgroundColor3 = locked and Palette.Disabled or Palette.MoneyDeep
	inviteHint.Text = locked and LOCKED_TEXT or "Teleport to fight Big Raga before the timer ends"
end
player:GetAttributeChangedSignal("SidekickGear"):Connect(refreshGear)
player:GetAttributeChangedSignal("SidekickBag"):Connect(refreshGear)
refreshGear()

-- Presses -----------------------------------------------------------------------------------------------------------------
local declinedStart = nil
local promptUntil = 0
local busy = false

-- Remotes are found when pressed (UiBossEvent): progression_spy swaps them.
local function ask(remoteName, target)
	if busy then
		return
	end
	busy = true
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(remoteName)
	local called, ok = pcall(remote.InvokeServer, remote)
	busy = false
	if not (called and ok) then
		UiMotion.Shake(target, 6, 0.2) -- cue: Denied
	end
end

teleport.Activated:Connect(function()
	if teleport.Active then
		ask("BossEventTeleport", teleport)
	end
end)
decline.Activated:Connect(function()
	declinedStart = ReplicatedStorage:GetAttribute("BossEventStart")
end)
bossButton.Activated:Connect(function()
	if teleport.Active then
		ask("BossEventTeleport", bossButton)
	else
		promptUntil = os.clock() + PROMPT_SECONDS
	end
end)
leave.Activated:Connect(function()
	ask("BossEventLeave", leave)
end)

-- Follows the server ------------------------------------------------------------------------------------------------------
local wasLive = false
local wasFight = false
local teamKey = nil
local warningUntil = 0
local stopFlash = nil
local stopPulse = nil
local invitedStart = nil
local inviteUntil = 0

local function clockText(seconds)
	local whole = math.ceil(math.max(0, seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local statusRaw = nil
local statusEnds = {} -- id -> EndsAt

-- One cell per active effect, each gone at its own EndsAt, on this client's clock of the server's time.
local function drawStatus()
	local raw = ReplicatedStorage:GetAttribute("BossStatus")
	if raw ~= statusRaw then
		statusRaw = raw
		statusEnds = {}
		local ok, rows = pcall(HttpService.JSONDecode, HttpService, raw or "[]")
		for _, row in ok and rows or {} do
			statusEnds[row.Id] = row.EndsAt
		end
	end
	for id, cell in statusCells do
		local left = (statusEnds[id] or 0) - workspace:GetServerTimeNow()
		cell.Frame.Visible = left > 0
		if left > 0 then
			cell.Left.Text = math.ceil(left) .. "s"
		end
	end
end

local function endWarning()
	warningUntil = 0
	if stopFlash then
		stopFlash()
		stopFlash = nil
	end
end

-- The roll tutorial and the starter popup dim the screen and take the clicks: from the pick until AUTO's closing animation ends.
local function tutorialActive()
	local tutorial = playerGui:FindFirstChild("AutoRollTutorial")
	return player:GetAttribute("NeedsStarter") == true
		or (tutorial ~= nil and tutorial.Enabled)
		or (tutorial ~= nil and player:GetAttribute("AutoRoll") == false and (player:GetAttribute("Rolls") or 0) == 0)
end

local function render()
	local phase = ReplicatedStorage:GetAttribute("BossEventPhase")
	local inEvent = player:GetAttribute("BossEvent") == true
	local live = phase ~= nil or inEvent
	if not live and not wasLive then
		return
	end
	wasLive = live

	local start = ReplicatedStorage:GetAttribute("BossEventStart")
	local elapsed = start and workspace:GetServerTimeNow() - start or 0
	local panelOpen = PanelSwitch.AnyOpen()
	local inFight = inEvent and phase == "Fight"
	layout()

	local key = inEvent and start or nil
	if key ~= teamKey then
		teamKey = key
		picks, confirmed, sentKey = {}, {}, ""
		drawPicks()
	end

	-- Flashes on the spawn and for each player who joins after it, not on an HP change.
	if inFight ~= wasFight then
		wasFight = inFight
		endWarning()
		if inFight then
			bar.Visible = true
			UiMotion.Pop(bar)
			warningUntil = os.clock() + WARNING_SECONDS
			local stopText = UiMotion.Pulse(warningLabel, { TextTransparency = 1 }, FLASH_PERIOD)
			local stopStroke = UiMotion.Pulse(warningStroke, { Transparency = 1 }, FLASH_PERIOD)
			stopFlash = function()
				stopText()
				stopStroke()
			end
			-- cue: ToastHigh
		end
	end
	if warningUntil > 0 and os.clock() >= warningUntil then
		endWarning()
	end

	local joinable = phase ~= nil and not inEvent and elapsed < Cfg.JoinSeconds and not tutorialActive()
	-- Once per event, for its own seconds: after that the Boss button carries teleporting.
	if joinable and invitedStart ~= start then
		invitedStart = start
		inviteUntil = os.clock() + Cfg.InviteSeconds
		invite.Visible = declinedStart ~= start
		UiMotion.Pop(invite) -- cue: DuelInvite
	elseif not joinable or declinedStart == start or os.clock() >= inviteUntil then
		invite.Visible = false
	end

	if joinable ~= bossButton.Visible then
		bossButton.Visible = joinable
		if stopPulse then
			stopPulse()
			stopPulse = nil
		end
		if joinable then
			local stopSize = UiMotion.Pulse(bossButton.PulseScale, { Scale = PULSE_SCALE }, PULSE_PERIOD)
			local stopGlow = UiMotion.Pulse(bossGlow, { Thickness = GLOW_THICK }, PULSE_PERIOD)
			stopPulse = function()
				stopSize()
				stopGlow()
			end
		end
	end
	bossPrompt.Visible = joinable and not invite.Visible and not teleport.Active and os.clock() < promptUntil
	hud.Visible = inEvent and phase == "Prep" and not panelOpen
	bar.Visible = inFight
	dropList.Visible = inFight and not panelOpen
	warning.Visible = inFight and warningUntil > 0 and not panelOpen
	leave.Visible = inEvent and phase ~= nil and not panelOpen

	-- From the server's end time, so a late view is as far along. Past it, full at 1 until the server revives the team.
	local waitEnds = player:GetAttribute("BossWaitEndsAt")
	exhausted.Visible = inEvent and type(waitEnds) == "number"
	if exhausted.Visible then
		local left = waitEnds - workspace:GetServerTimeNow()
		exhaustedCount.Text = tostring(math.clamp(math.ceil(left), 1, Cfg.RefillWaitSeconds))
		loadingFill.Size = UDim2.fromScale(math.clamp(1 - left / Cfg.RefillWaitSeconds, 0, 1), 1)
	end

	if invite.Visible then
		inviteCountdown.Text = clockText(Cfg.JoinSeconds - elapsed)
	end
	if hud.Visible then
		hudCountdown.Text = clockText(Cfg.PrepSeconds - elapsed)
		teamDamage.Text = "Team damage: " .. HudFormat.SpeedText(player:GetAttribute("BossTeamDamage"))
	end
	if bar.Visible then
		local hp = ReplicatedStorage:GetAttribute("BossEventHp") or 0
		local max = ReplicatedStorage:GetAttribute("BossEventMaxHp") or 0
		-- Left to right over the intro, from the server's start: a late joiner sees the same width as everyone.
		local intro = UiMotion.Reduced() and 1 or math.clamp((elapsed - Cfg.PrepSeconds) / Cfg.IntroSeconds, 0, 1)
		fill.Size = UDim2.fromScale(max > 0 and math.clamp(hp / max, 0, 1) * intro or 0, 1)
		barValue.Text = HudFormat.Commas(math.ceil(hp)) .. "/" .. HudFormat.Commas(math.ceil(max))
		drawStatus()
	end
end

RunService.Heartbeat:Connect(render)
