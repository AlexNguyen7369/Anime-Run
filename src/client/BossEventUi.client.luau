--!nonstrict
-- Boss event UI (design doc 4.37, docs/BOSS_EVENT_SPEC.md Flow and Team HUD). Contract: Client/UiTest/UiBossEvent. Display only:
-- it follows the server's attributes (ReplicatedStorage BossEvent*, player BossEvent, BossStatus, BossTeamDamage and BossWaitEndsAt) and asks through
-- Remotes.BossEventTeleport, BossEventSetTeam and BossEventLeave. Every part is built once and only hidden.
-- BossButton only opens the BossesPanel popup (BOSS_EVENT_SPEC "Paid spawn", contract: Client/UiTest/UiBossPaid). Its action is Go in an
-- event, otherwise the paid spawn through Remotes.BossBuy and BossUseCredit; the server judges every press.
-- Sound and effects are not in yet. Hook, when they are approved: UiFeedback.Play with an existing cue where "cue:" is marked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
local Monetization = require(shared:WaitForChild("MonetizationConfig"))
local SidekickArt = require(shared:WaitForChild("SidekickArt"))
local StaminaConfig = require(shared:WaitForChild("StaminaConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local Palette = UiTheme.Palette
local HEAVY = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Heavy) -- as RollToast's BOLD: heavy, in the game's family
local PanelBand = require(script.Parent:WaitForChild("PanelBand"))
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local Icons = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
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
local BOSS_BUTTON_WIDTH = 0.095 -- of the screen: on a small phone it ends clear of the roll toast
local PULSE_SCALE = 1.08
local PULSE_PERIOD = 0.6
local GLOW_THICK = 5
local PROMPT_SECONDS = 3
local LOCKED_TEXT = "Get a Sidekick and equip it to teleport"
local RESTRICTED_TEXT = "Paid spawns are not available on your account"
local RAGING_TEXT = "Big Raga is raging right now" -- design doc 4.37: the tweaked name only
local CLOSED_TEXT = "Teleporting closed"
local ABOUT_TEXT = "Every 30 minutes Big Raga rises in the sky arena. Defeat it for a treasure chest!"
-- Popup widths in px at most: the old widths at 920 units wide, stretched to the frame's width (design doc 4.42) so the
-- heights stay as before; k follows from the size.
local WIDE = AnimeSkin.Units.W / 920
local INVITE_WIDTH, HUD_WIDTH, BOSSES_WIDTH = 560 * WIDE, 820 * WIDE, 700 * WIDE
local RAGA_CHEST, ADAPTED_CHEST = "relic_chest_raga", "relic_chest_adapted"
local TITLE_STAGE_1, TITLE_STAGE_2 = "Big Raga", "Fully Adapted Raga"
local TITLE_STAGE_2_COLOR = Color3.fromRGB(235, 20, 30) -- owner 2026-11-06: bold red; HEAVY is already the title's font
local CASCADE_GAP = 0.25 -- s between the drop list's rows, placeholder
local TEAM_WARNING_TEXT = "Select a character first"
local TEAM_WARNING_SECONDS = 1 -- placeholder
local EDIT_TEAM_SIZE = Vector2.new(120, 34) -- px
local EDIT_TEAM_GAP = 64 -- px above the Team row: clear of its enlarged active circle and its marker
local RESEND_GAP = 0.3 -- s between team sends: the server refuses a request inside its 0.25 s cooldown
local PHONE_MAX_HEIGHT = 500 -- the HUD's phone rule
local PHONE_TOP = 56 -- px: under the top row. On a phone the band's top is too low, and the roll it clears is hidden or below
local BAR_LOW_TOP = 58 -- px: under the top row and Roblox's reserved top-left (x 0..360, y 0..58)
local BAR_HIGH_TOP = 10 -- px: where the bar fits between those two
local RESERVED_RIGHT = 360
local EXHAUSTED_TEXT = "Exhausted, reviving"
-- px at full scale. 360 wide stays left of the drop list on 1920 x 907.
local EXHAUSTED_WIDTH, EXHAUSTED_MESSAGE, EXHAUSTED_COUNT, EXHAUSTED_LOADING = 360, 36, 48, 14
local DIM_TRANSPARENCY = 0.65 -- "slightly dims" (BOSS_EVENT_SPEC "Exhaustion view")
local STATUS_GAP = 4 -- px under the bar
local STATUS_HEIGHT, STATUS_HEIGHT_PHONE = 40, 22
local STATUS_SECONDS, STATUS_SECONDS_PHONE = 20, 12
local BAR_WIDTH = 0.62 -- of the screen
local BAR_SIDE_CLEAR = 78 -- px each side, for the LeaveButton (right edge -8, 62 wide) and its gap
local TOP_FULL_HEIGHT = 900 -- px: a shorter screen scales the bar and the drop list down
local TOP_MIN_SCALE = 0.4
local TITLE_HEIGHT, TRACK_HEIGHT = 40, 60 -- px at full scale
local DROP_WIDTH, DROP_WIDTH_MIN = 400, 190
local DROP_HEADING, DROP_HEADING_MIN = 32, 14
local DROP_ROW, DROP_ROW_MIN = 26, 13
-- The icon is a plain in-house shape, a text glyph or a drawn wheel; no image upload. No digit in these texts: the countdown is the number.
local STATUS_LOOKS = {
	{ Id = "Shouted", Glyph = "!", Color = Palette.Danger },
	{ Id = "Adapted", Color = Palette.Gold }, -- the wheel turn that starts it
	{ Id = "Vulnerable", Glyph = "V", Color = Palette.MoneyDeep }, -- no end time: it goes with its row
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
	if not props.FontFace then
		props.Font = UiTheme.Font
	end
	props.TextColor3 = props.TextColor3 or Palette.White
	props.TextScaled = true
	local text = make("TextLabel", name, parent, props)
	make("UITextSizeConstraint", "Max", text, { MaxTextSize = maxSize })
	UiTheme.Stroke(text, 2)
	return text
end

-- Fixed text size, no size constraint: the LeaveButton is one of ui_layout's solved elements at every viewport.
-- tone: an AnimeSkin.Button tone (design doc 4.42).
local function button(name, parent, text, tone, props)
	props.Text = text
	props.Font = UiTheme.Font
	props.TextSize = props.TextSize or 20
	props.TextColor3 = Palette.White
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local object = make("TextButton", name, parent, props)
	UiTheme.Corner(object, "M")
	UiTheme.Stroke(object, 3, UiTheme.Outline, true)
	AnimeSkin.Button(object, tone)
	return object
end

-- The Index frame (design doc 4.42, Client/AnimeSkin.IndexFrame): chrome, overhanging logo, ALL CAPS title, art close,
-- content in the frame's units. The Boss icon is the logo (design doc 4.40). The countdown (Section,
-- gold) sits on a plate at the right of the tabs row. withClose adds Header/CloseButton; the Invite has none (Decline is
-- its way out). Returns the frame's g too: each popup lays its content out in g.OnLayout.
local LOGO = Icons.Boss.Image
local COUNTDOWN_WIDTH = 160 -- units, "m:ss" at the Section size with the plate's 24 clear at each end
local function panel(name, title, withClose)
	local frame = make("Frame", name, nil, { Visible = false, Active = true, AnchorPoint = Vector2.new(0.5, 0.5) })
	UiTheme.Body(frame)
	local header = make("Frame", "Header", frame, { BackgroundTransparency = 1, BorderSizePixel = 0 })
	local titleLabel = make("TextLabel", "Title", header, { Text = title })
	local plate = make("Frame", "CountdownPlate", header, { BackgroundTransparency = 1, Visible = false, ZIndex = 9 })
	AnimeSkin.Plate(plate)
	local countdown = make("TextLabel", "Countdown", header, {
		BackgroundTransparency = 1,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 10,
	})
	countdown:GetPropertyChangedSignal("Text"):Connect(function()
		plate.Visible = countdown.Text ~= ""
	end)
	local logo = make("ImageLabel", "Logo", header, { Image = LOGO })
	local close = withClose and button("CloseButton", header, "X", "Danger", {}) or nil
	local g =
		AnimeSkin.IndexFrame(frame, { Header = header, Title = titleLabel, Icon = logo, Logo = LOGO, Close = close })
	g.OnLayout(function()
		local x, y = g.W - 56 - COUNTDOWN_WIDTH, g.Content.TabsY
		g.Place(plate, x, y, COUNTDOWN_WIDTH, AnimeSkin.Units.TabH)
		g.Place(countdown, x + 24, y, COUNTDOWN_WIDTH - 48, AnimeSkin.Units.TabH)
		g.Role(countdown, "Section")
	end)
	return frame, header, countdown, close, g
end

-- A popup's px size: at most `width`, the frame's aspect, its chrome (40 units past each side, 70 above, 30 below)
-- inside the rect; the frame is centred on the rect.
local function fitPopup(frame, width, left, top, right, bottom)
	local U = AnimeSkin.Units
	local small = AnimeSkin.Compact()
	local w, h = small and U.PhoneW or U.W, small and U.PhoneH or U.H
	width = math.floor(math.max(1, math.min(width, (right - left) * w / (w + 80), (bottom - top) * w / (h + 100))))
	frame.Position = UDim2.fromOffset((left + right) / 2, (top + bottom) / 2)
	frame.Size = UDim2.fromOffset(width, math.floor(width * h / w))
end

local root = make("ScreenGui", "RacerBossEvent", playerGui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 13, -- above the panels and DuelUi (a duel keeps its invite), below the roll view (14)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Invite ------------------------------------------------------------------------------------------------------------------
local invite, _, inviteCountdown, _, inviteFrame = panel("Invite", "BIG RAGA EVENT")
invite.Parent = root
local inviteHint = label("Hint", invite, {
	Text = "",
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, 22)
local teleport = button("TeleportButton", invite, "Teleport", "Go", {})
local decline = button("DeclineButton", invite, "Decline", "Idle", {})
-- The hint (Body) on top, Teleport and Decline side by side on the content's last row, 12 apart.
inviteFrame.OnLayout(function(g)
	local c, U = g.Content, AnimeSkin.Units
	local half = (c.W - U.Gap) / 2
	local y = c.Y + c.H - U.Button
	g.Place(inviteHint, c.X, c.Y, c.W, c.H - U.Gap - U.Button)
	g.Place(teleport, c.X, y, half, U.Button)
	g.Place(decline, c.X + half + U.Gap, y, half, U.Button)
	g.Role(inviteHint, "Body")
	g.Role(teleport, "Item")
	g.Role(decline, "Item")
end)

-- Team HUD ----------------------------------------------------------------------------------------------------------------
local hud, _, hudCountdown, hudClose, hudFrame = panel("TeamHud", "CHOOSE YOUR TEAM", true)
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
	AnimeSkin.Card(slot, AnimeSkin.Tint.Muted)
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
-- Versus (BOSS_EVENT_SPEC "Team HUD", T2): the red VS mark, then Big Raga's drawn portrait (side_raga is his art) on a red card.
local versus = make("TextLabel", "Versus", hud, { BackgroundTransparency = 1, Text = "VS" })
local ragaCard = make("Frame", "RagaCard", hud, { BackgroundTransparency = 1 })
AnimeSkin.Card(ragaCard, AnimeSkin.Tint.Danger)
local ragaPortrait = make("ImageLabel", "RagaPortrait", hud, {
	BackgroundTransparency = 1,
	Image = SidekickArt.side_raga and SidekickArt.side_raga.Portrait or "",
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 2,
})
local teamDamage = label("TeamDamage", hud, {
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
}, 26)
local avgStamina = label("AverageStamina", hud, {
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Left,
}, 22)
local teamWarning = label("TeamWarning", hud, {
	Text = TEAM_WARNING_TEXT,
	Visible = false,
	ZIndex = 5,
}, 28)
local note = label("Note", hud, {
	Text = NOTE_TEXT,
	TextWrapped = true,
}, 16)
local list = make("ScrollingFrame", "List", hud, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Palette.Muted,
	HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar, -- the bar sits inside the area, not on cells
})
local LIST_BLEED = 4 -- units: the card art reaches 3 px past each cell
local listPadding = make("UIPadding", "Padding", list, {})
local listGrid = make("UIGridLayout", "Grid", list, { -- one row: columns of one cell, left to right
	SortOrder = Enum.SortOrder.LayoutOrder,
	FillDirection = Enum.FillDirection.Vertical,
	FillDirectionMaxCells = 1,
})
-- Versus (BOSS_EVENT_SPEC "Team HUD", owner 2026-11-10, positions and sizes proposed): a band over a one-row grid. In the
-- band, left to right: the slots (square, as big as fits), the red VS, Big Raga's portrait, then TeamDamage (Section) over
-- AverageStamina (Body). The grid runs along the bottom and scrolls sideways. The Note (Caption) and the red TeamWarning take the
-- footer plate's line in turn.
local CELL_W, CELL_H, LINE_H = 96, 100, 40
local PHONE_CELL_W, PHONE_CELL_H, PHONE_LINE_H = 64, 68, 28
local VS_W, PHONE_VS_W, STATS_W, PHONE_STATS_W = 72, 32, 220, 96
local RAGA_SHARE = 0.2 -- of the content width at most
hudFrame.OnLayout(function(g)
	local c, U = g.Content, AnimeSkin.Units
	local gap = U.Gap
	local cellW, cellH = g.Small and PHONE_CELL_W or CELL_W, g.Small and PHONE_CELL_H or CELL_H
	local lineH = g.Small and PHONE_LINE_H or LINE_H
	local vsW, statsW = g.Small and PHONE_VS_W or VS_W, g.Small and PHONE_STATS_W or STATS_W
	local gridH = cellH + 2 * LIST_BLEED + U.Inner -- the cells and the sideways scrollbar
	local band = c.H - gridH - gap
	local raga = math.min(band, math.floor(c.W * RAGA_SHARE))
	local n = #slots
	local side = math.max(1, math.min(band, (c.W - statsW - vsW - raga - 3 * gap - (n - 1) * gap) / n))
	for i, slot in slots do
		g.Place(slot.Frame, c.X + (i - 1) * (side + gap), c.Y + (band - side) / 2, side, side)
		g.Role(slot.Number, "Item")
	end
	local x = c.X + n * side + n * gap
	g.Place(versus, x, c.Y, vsW, band)
	g.Role(versus, "Title")
	versus.TextColor3 = WARNING_BRIGHT
	x += vsW + gap
	g.Place(ragaCard, x, c.Y + (band - raga) / 2, raga, raga)
	g.Place(ragaPortrait, x + U.Inner, c.Y + (band - raga) / 2 + U.Inner, raga - 2 * U.Inner, raga - 2 * U.Inner)
	x += raga + gap
	local statsRight = c.X + c.W
	g.Place(teamDamage, x, c.Y + band / 2 - lineH - gap / 2, statsRight - x, lineH)
	g.Place(avgStamina, x, c.Y + band / 2 + gap / 2, statsRight - x, lineH)
	g.Role(teamDamage, "Section")
	g.Role(avgStamina, "Body")

	local listY = c.Y + band + gap
	g.Place(list, c.X, listY, c.W, gridH)
	for _, edge in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		listPadding[edge] = UDim.new(0, g.px(LIST_BLEED))
	end
	listGrid.CellSize = g.at(cellW, cellH)
	listGrid.CellPadding = g.at(gap, gap)
	-- The footer line's rect, as the frame placed it this pass (hooks run after it).
	local footer = hud:FindFirstChild("AnimeFooterLine")
	for _, text in { note, teamWarning } do
		if footer then
			text.AnchorPoint, text.Position, text.Size = footer.AnchorPoint, footer.Position, footer.Size
		end
		text.ZIndex = 5
	end
	g.Role(note, "Caption")
	g.Role(teamWarning, "Item")
	teamWarning.TextColor3 = WARNING_BRIGHT -- the refusal's red, as design doc 4.37 asks
end)
-- One line on the plate: the warning stands in for the note while it shows.
teamWarning:GetPropertyChangedSignal("Visible"):Connect(function()
	note.Visible = not teamWarning.Visible
end)

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
	FontFace = HEAVY,
	TextColor3 = WARNING_BRIGHT,
	TextWrapped = true,
}, 72)
local warningStroke = UiTheme.Stroke(warningLabel, 3, Color3.new(0, 0, 0))

local bar =
	make("Frame", "BossBar", root, { AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Visible = false })
local bossTimer = label("BossTimer", bar, {
	Text = "",
	FontFace = HEAVY,
	TextColor3 = Palette.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, TITLE_HEIGHT)
local barTitle = label("Title", bar, {
	Text = TITLE_STAGE_1,
	FontFace = HEAVY,
}, TITLE_HEIGHT)
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
local barValue = label("Value", bar, { Text = "", ZIndex = 2 }, 36) -- above the Track and its Fill

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
		label("Glyph", icon, { Size = UDim2.fromScale(1, 1), Text = look.Glyph }, 30)
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
		Left = label("Seconds", cell, { Text = "", TextColor3 = Palette.Gold }, STATUS_SECONDS),
		Stack = label("Stack", cell, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.6, 0.35),
			Text = "",
			ZIndex = 2,
			Visible = false,
		}, STATUS_SECONDS),
	}
end

-- Hangs from the bar's bottom-right corner, after the Warning (BOSS_EVENT_SPEC "Boss bar"). Display only, nothing in it is Active.
local dropList = make("Frame", "DropList", root, { BackgroundTransparency = 1, Visible = false })
make("UIListLayout", "List", dropList, {
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 1),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local dropHeading = label("Heading", dropList, {
	LayoutOrder = 1,
	Text = "Drop:",
	FontFace = HEAVY,
}, DROP_HEADING)
local dropRule = make("Frame", "Rule", dropList, {
	LayoutOrder = 2,
	BackgroundColor3 = Palette.SoftText,
	BorderSizePixel = 0,
})
local dropRows = {}
local dropTexts = {} -- row -> { Phase 1's text, Phase 2's }
local dropOutlines = {} -- row -> the light outline a near-black colour needs, or nil
local function oddsText(row)
	return ("%s %s%%"):format(row.Name, tostring(row.Odds))
end
local adaptedOdds = RelicConfig.ChestOdds(ADAPTED_CHEST)
local function adaptedText(id)
	for _, row in adaptedOdds do
		if row.Id == id then
			return oddsText(row)
		end
	end
	return ("Big Raga %.2f%%"):format(RelicConfig.Chests[ADAPTED_CHEST].SidekickChance * 100)
end
local function dropRow(id, text, color, stroke)
	local row = label("Row_" .. id, dropList, {
		LayoutOrder = 3 + #dropRows,
		Text = text,
		TextColor3 = color,
		FontFace = HEAVY,
	}, DROP_ROW)
	UiTheme.Stroke(row, 2, stroke)
	table.insert(dropRows, row)
	dropTexts[row] = { text, adaptedText(id) }
	dropOutlines[row] = stroke
end
local dropOdds = RelicConfig.Odds("big_raga")
table.sort(dropOdds, function(a, b)
	return a.Odds > b.Odds
end)
for _, row in dropOdds do
	-- Secret's near-black needs the light outline Big Raga's black has.
	dropRow(
		row.Id,
		oddsText(row),
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
local editTeam = button("EditTeamButton", root, "Edit Team", "Go", {
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(EDIT_TEAM_SIZE.X, EDIT_TEAM_SIZE.Y),
	TextSize = 18,
	Visible = false,
})
local leave = button("LeaveButton", root, "LEAVE", "Danger", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 56),
	Size = UDim2.fromOffset(62, 44),
	TextSize = 18,
	Visible = false,
})

-- The top-left button. Its pulse grows right and down from a fixed corner, so it never reaches Roblox's buttons. PulseScale goes in
-- first: RacerMotion adds a HoverScale once the button is in the gui, and the first UIScale is the one that draws.
local bossButton = button("BossButton", nil, "Bosses", "Danger", {
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
-- The popup: the Index frame at a fixed size; a hidden row leaves its place empty.
-- Centred, with a header and an X, as the other popups (owner 2026-11-06).
local bossesPanel, _, _, bossesClose, bossesFrame = panel("BossesPanel", "BOSSES", true)
bossesPanel.Parent = root
local bossStatus = make("TextLabel", "Status", bossesPanel, {
	BackgroundTransparency = 1,
	Text = ABOUT_TEXT,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local bossDetailsHeading = make("TextLabel", "DetailsHeading", bossesPanel, {
	BackgroundTransparency = 1,
	Text = "Details",
	TextXAlignment = Enum.TextXAlignment.Left,
})
-- Both chests' tables (BOSS_EVENT_SPEC "Paid spawn"), side by side, from the Drop list's own rows, so they can not disagree. Display only.
-- Each table is a card; its title and rows stay directly in BossDetails (UiBossPaid and UiBossPhase2 read them there).
local bossDetails = make("Frame", "BossDetails", bossesPanel, {
	BackgroundTransparency = 1,
})
local detailColumns = {} -- { Card, Heading, Rows = { { Label, Color, Outline } } } per chest
for column, chest in { RAGA_CHEST, ADAPTED_CHEST } do
	local card = make("Frame", "Card_" .. chest, bossDetails, { BackgroundTransparency = 1, ZIndex = 0 })
	AnimeSkin.Card(card)
	local heading = label("Title_" .. chest, bossDetails, {
		Text = RelicConfig.Chests[chest].Name,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 16)
	local rows = {}
	for _, row in dropRows do
		local copy = row:Clone()
		if column == 2 then
			copy.Name = string.gsub(row.Name, "^Row_", "Adapted_")
			copy.Text = dropTexts[row][2]
		end
		copy.Parent = bossDetails
		table.insert(rows, { copy, row.TextColor3, dropOutlines[row] })
	end
	detailColumns[column] = { Card = card, Heading = heading, Rows = rows }
end
local bossNext = make("TextLabel", "NextEvent", bossesPanel, {
	BackgroundTransparency = 1,
	Text = "",
})
local bossAction = button("BossAction", bossesPanel, "Go", "Go", {})
local bossPrompt = make("TextLabel", "BossPrompt", bossesPanel, {
	BackgroundTransparency = 1,
	Text = "",
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Right,
	Visible = false,
})

-- Design doc 4.42: Details (Section) and the prompt (Body) in the tabs row; the status (Body) on top of the content, the
-- two chest cards side by side under it (title Item, odds rows Caption in their rarity colours), the spawn button 12
-- above the content's bottom, "Next event in" on the footer plate.
bossesFrame.OnLayout(function(g)
	local c, U = g.Content, AnimeSkin.Units
	local gap, pad = U.Gap, U.Pad
	local statusH = 2 * AnimeSkin.UnitSize.Body + U.Inner -- two lines
	g.Place(bossDetailsHeading, c.X, c.TabsY, 240, U.TabH)
	g.Place(bossPrompt, c.X + 240 + gap, c.TabsY, c.W - 240 - gap, U.TabH)
	g.Place(bossStatus, c.X, c.Y, c.W, statusH)
	local actionY = c.Y + c.H - gap - U.Button
	g.Place(bossAction, c.X, actionY, c.W, U.Button)
	local cardsY = c.Y + statusH + gap
	local cardsH = actionY - gap - cardsY
	g.Place(bossDetails, c.X, cardsY, c.W, cardsH)
	local colW = (c.W - gap) / 2
	local item = AnimeSkin.UnitSize.Item
	for column, detail in detailColumns do
		local x = (column - 1) * (colW + gap)
		g.Place(detail.Card, x, 0, colW, cardsH)
		g.Place(detail.Heading, x + pad, pad, colW - 2 * pad, item)
		g.Role(detail.Heading, "Item")
		local rowH = math.min(AnimeSkin.UnitSize.Caption, (cardsH - 2 * pad - item - U.Inner) / #detail.Rows)
		for i, row in detail.Rows do
			local copy, color, outline = row[1], row[2], row[3]
			g.Place(copy, x + pad, pad + item + U.Inner + (i - 1) * rowH, colW - 2 * pad, rowH)
			g.Role(copy, "Caption")
			-- The rarity colour; a near-black (Secret, the Sidekick's black) keeps the thin light outline it needs.
			copy.TextColor3 = color
			copy.TextXAlignment = Enum.TextXAlignment.Left
			local stroke = copy:FindFirstChildOfClass("UIStroke")
			if stroke and outline then
				stroke.Color, stroke.Thickness, stroke.Enabled = outline, 1, true
			end
		end
	end
	-- The frame draws the footer line; NextEvent keeps its name and text for the tests but the frame's line shows it.
	g.Place(bossNext, g.W * 303 / 920, g.H - 60, g.W * 312 / 920, 28)
	bossNext.Visible = false
	g.Footer(bossNext.Text)
	g.Role(bossStatus, "Body")
	g.Role(bossDetailsHeading, "Section")
	g.Role(bossPrompt, "Body")
	g.Role(bossAction, "Item")
end)
local function placeBosses()
	local view = workspace.CurrentCamera.ViewportSize
	fitPopup(bossesPanel, BOSSES_WIDTH, 0, 0, view.X, view.Y)
end
placeBosses()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeBosses)

local function placeBossButton()
	local inset = GuiService.TopbarInset
	local x = inset.Min.X + BOSS_BUTTON_GAP
	local y = math.max(2, (inset.Max.Y - BOSS_BUTTON_SIZE.Y) / 2)
	bossButton.Position = UDim2.fromOffset(x, y)
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
local exhaustedMessage = label("Message", exhausted, {
	AnchorPoint = Vector2.new(0.5, 0),
	Text = EXHAUSTED_TEXT,
	FontFace = HEAVY,
}, EXHAUSTED_MESSAGE)
local exhaustedCount = label("Countdown", exhausted, {
	AnchorPoint = Vector2.new(0.5, 0),
	Text = "",
	FontFace = HEAVY,
	TextColor3 = Palette.Gold,
}, EXHAUSTED_COUNT)
local loading = make("Frame", "Loading", exhausted, {
	AnchorPoint = Vector2.new(0.5, 0),
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

local function placeTop(size, row)
	local scale = math.clamp(size.Y / TOP_FULL_HEIGHT, TOP_MIN_SCALE, 1)
	local width = math.min(math.max(size.X * BAR_WIDTH, 280), size.X - 2 * BAR_SIDE_CLEAR)
	local barLeft = (size.X - width) / 2
	local fits = barLeft >= RESERVED_RIGHT and row and barLeft + width + 8 <= row.AbsolutePosition.X
	local barTop = fits and BAR_HIGH_TOP or BAR_LOW_TOP
	local titleHeight, trackHeight = math.round(TITLE_HEIGHT * scale), math.round(TRACK_HEIGHT * scale)
	local height = titleHeight + 2 + trackHeight
	bar.Position = UDim2.new(0.5, 0, 0, barTop)
	bar.Size = UDim2.fromOffset(width, height)
	barTitle.Size = UDim2.new(1, 0, 0, titleHeight)
	bossTimer.Size = UDim2.new(0.25, 0, 0, titleHeight)
	track.Position = UDim2.fromOffset(0, titleHeight + 2)
	track.Size = UDim2.new(1, 0, 0, trackHeight)
	barValue.Position = UDim2.fromOffset(8, titleHeight + 3)
	barValue.Size = UDim2.new(1, -16, 0, trackHeight - 2)

	local iconSize = math.max(STATUS_HEIGHT_PHONE, math.round(STATUS_HEIGHT * scale))
	local secondsHeight = math.max(STATUS_SECONDS_PHONE, math.round(STATUS_SECONDS * scale))
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
	local headingHeight = math.max(DROP_HEADING_MIN, math.round(DROP_HEADING * scale))
	local ruleHeight = scale < 0.6 and 1 or 2
	local rowRoom = size.Y - listTop - 8 - headingHeight - ruleHeight - #dropRows - 1
	local rowHeight =
		math.clamp(math.floor(rowRoom / #dropRows), 8, math.max(DROP_ROW_MIN, math.round(DROP_ROW * scale)))
	local listHeight = headingHeight + ruleHeight + #dropRows * (rowHeight + 1) + 1
	local listWidth = math.max(DROP_WIDTH_MIN, DROP_WIDTH * scale)
	local listLeft = barLeft + width - listWidth
	dropList.Position = UDim2.fromOffset(listLeft, listTop)
	dropList.Size = UDim2.fromOffset(listWidth, listHeight)
	dropHeading.Size = UDim2.new(1, 0, 0, headingHeight)
	dropRule.Size = UDim2.new(0.6, 0, 0, ruleHeight)
	for _, row in dropRows do
		row.Size = UDim2.new(1, 0, 0, rowHeight)
	end

	-- The list is hidden while this shows, so only the status row is in its way.
	local warningEnd = size.Y / 2 - 8
	local warningTop = listTop + statusHeight + 8
	warning.Position = UDim2.fromOffset(size.X / 2, warningTop)
	warning.Size = UDim2.fromOffset(
		math.min(size.X * 0.86, 1100),
		math.max(36, math.min(size.Y * WARNING_MAX_HEIGHT, warningEnd - warningTop))
	)

	-- Centred: beside the list where it fits between the screen's middle and the list, else under the list.
	local panelWidth = math.round(EXHAUSTED_WIDTH * scale)
	local panelTop = listTop + statusHeight + 8
	if panelWidth / 2 + 8 > listLeft - size.X / 2 then
		panelTop = listTop + listHeight + 8
	end
	local messageHeight = math.round(EXHAUSTED_MESSAGE * scale)
	local countHeight = math.round(EXHAUSTED_COUNT * scale)
	exhaustedMessage.Position = UDim2.new(0.5, 0, 0, panelTop)
	exhaustedMessage.Size = UDim2.fromOffset(panelWidth, messageHeight)
	exhaustedCount.Position = UDim2.new(0.5, 0, 0, panelTop + messageHeight)
	exhaustedCount.Size = UDim2.fromOffset(panelWidth, countHeight)
	loading.Position = UDim2.new(0.5, 0, 0, panelTop + messageHeight + countHeight + 4)
	loading.Size = UDim2.fromOffset(panelWidth, math.round(EXHAUSTED_LOADING * scale))
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
	local pair = chrome and chrome:FindFirstChild("AutoSlot")
	if pair and pair.Visible then
		-- Where Auto and Upgrade stack above the bars, they stay reachable under the band's bottom.
		bottom = math.min(bottom, pair.AbsolutePosition.Y + GuiService:GetGuiInset().Y - 6)
	end
	local row = chrome and chrome:FindFirstChild("TopRight")
	local key = table.concat({ size.X, size.Y, left, top, right, bottom, row and row.AbsolutePosition.X or -1 }, ",")
	if key == lastLayout then
		return
	end
	lastLayout = key
	fitPopup(invite, INVITE_WIDTH, left, top, right, bottom)
	fitPopup(hud, HUD_WIDTH, left, top, right, bottom)
	placeTop(size, row)
	local racerHud = playerGui:FindFirstChild("RacerHud")
	local level = racerHud and racerHud:FindFirstChild("Level")
	local teamRow = level and level:FindFirstChild("Team") -- TeamHud's minibar row
	if teamRow then
		local at = teamRow.AbsolutePosition
		editTeam.Position = UDim2.fromOffset(at.X + teamRow.AbsoluteSize.X / 2, at.Y - EDIT_TEAM_GAP)
	end
end

-- Team --------------------------------------------------------------------------------------------------------------------
local cells = {} -- character id -> { Button, Edge, Badge }
local picks = {} -- ids in slot order; the saved team, else empty until the player picks: the server then chooses at the spawn
local confirmed = {} -- what the server last accepted
local sentKey = ""
local sending = false

local function art(id)
	local spec = CharacterCatalog.Get(id)
	local model = spec and spec.Model or id -- starters are drawn under the model they wear
	return CharacterHeads[id] or CharacterHeads[model] or CharacterPortraits[id] or CharacterPortraits[model] or ""
end

-- A slot's drawn portrait (Versus look), else the drawn head.
local function portrait(id)
	local spec = CharacterCatalog.Get(id)
	local model = spec and spec.Model or id
	return CharacterPortraits[id] or CharacterPortraits[model] or art(id)
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
		slot.Head.Image = id and portrait(id) or ""
		setBadge(slot.Badge, id and sidekickHead(gear[id]) or "")
		slot.Frame.ThemeStroke.Color = id and Palette.Gold or Palette.Muted
		AnimeSkin.Card(slot.Frame, id and AnimeSkin.Tint.Gold or AnimeSkin.Tint.Muted)
	end
	for id, cell in cells do
		cell.Edge.Color = table.find(picks, id) and Palette.Gold or UiTheme.Outline
		AnimeSkin.Card(cell.Button, table.find(picks, id) and AnimeSkin.Tint.Gold or AnimeSkin.Tint.Default)
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

-- Inside a cell: the head over the name (Caption), 8 in from the card's edges.
local function placeCell(cell)
	local g, pad, caption = hudFrame, AnimeSkin.Units.Inner, AnimeSkin.UnitSize.Caption
	cell.Head.Position, cell.Head.Size = g.at(pad, pad), UDim2.new(1, -g.px(2 * pad), 1, -g.px(3 * pad + caption))
	cell.CharacterName.Position = UDim2.new(0, g.px(pad), 1, -g.px(pad + caption))
	cell.CharacterName.Size = UDim2.new(1, -g.px(2 * pad), 0, g.px(caption))
	g.Role(cell.CharacterName, "Caption")
end

local function newCell(id, spec)
	local cell = button(id, list, "", "Idle", {})
	UiTheme.Corner(cell, "S")
	local edge = cell.ThemeStroke
	edge.Thickness = 2
	AnimeSkin.Card(cell)
	make("ImageLabel", "Head", cell, {
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
		Text = spec.Name or id,
	}, 14)
	cell.Activated:Connect(function()
		press(id)
	end)
	placeCell(cell)
	return { Button = cell, Edge = edge, Badge = badge }
end
hudFrame.OnLayout(function()
	for _, cell in cells do
		placeCell(cell.Button)
	end
end)

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
	AnimeSkin.Button(teleport, "Go")
	if locked then
		teleport.BackgroundColor3 = Palette.Disabled
	end
	inviteHint.Text = locked and LOCKED_TEXT or "Teleport to fight Big Raga before the timer ends"
end
player:GetAttributeChangedSignal("SidekickGear"):Connect(refreshGear)
player:GetAttributeChangedSignal("SidekickBag"):Connect(refreshGear)
refreshGear()

-- Presses -----------------------------------------------------------------------------------------------------------------
local declinedStart = nil
local promptUntil = 0
local promptText = ""
local busy = false
local bossesOpen = false
local hudClosed = false -- the player closed the team HUD this event: Edit Team reopens it

local function showPrompt(text)
	promptText = text
	promptUntil = os.clock() + PROMPT_SECONDS
end

-- Remotes are found when pressed (UiBossEvent): progression_spy swaps them. showRefusal puts the server's reason in the BossPrompt.
local function ask(remoteName, target, showRefusal)
	if busy then
		return
	end
	busy = true
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(remoteName)
	local called, ok, message = pcall(remote.InvokeServer, remote)
	busy = false
	if not (called and ok) then
		UiMotion.Shake(target, 6, 0.2) -- cue: Denied
		if showRefusal then
			showPrompt(called and tostring(message or "Try again") or "Connection error")
		end
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
-- Only opens the popup, in every state: teleporting and spawning are its action's job (owner 2026-11-05).
bossButton.Activated:Connect(function()
	bossesOpen = not bossesOpen
	if bossesOpen then
		UiMotion.Pop(bossesPanel)
	end
end)
bossesClose.Activated:Connect(function()
	bossesOpen = false
end)
PanelFrame.CloseOnOutsideClick(bossesPanel, function()
	bossesOpen = false
end)
bossAction.Activated:Connect(function()
	if not bossAction.Active then
		UiMotion.Shake(bossAction, 6, 0.2) -- cue: Denied
	elseif ReplicatedStorage:GetAttribute("BossEventPhase") ~= nil then
		ask("BossEventTeleport", bossAction, true)
	elseif (player:GetAttribute("BossCredit") or 0) >= 1 then
		ask("BossUseCredit", bossAction, true)
	elseif player:GetAttribute("PaidRandomRestricted") == true then
		showPrompt(RESTRICTED_TEXT)
		UiMotion.Shake(bossAction, 6, 0.2) -- cue: Denied
	else
		ask("BossBuy", bossAction, true)
	end
end)
leave.Activated:Connect(function()
	ask("BossEventLeave", leave)
end)
-- Design doc 4.37: closes only with a team to run. Red text, fading, otherwise.
local warningFades = {}
hudClose.Activated:Connect(function()
	if #picks > 0 then
		hudClosed = true
		ask("BossEventPrepRun", hudClose)
		return
	end
	UiMotion.Shake(hudClose, 6, 0.2) -- cue: Denied
	for _, fade in warningFades do
		fade:Cancel()
	end
	local stroke = teamWarning.ThemeStroke
	teamWarning.TextTransparency, stroke.Transparency = 0, 0
	teamWarning.Visible = true
	local info = TweenInfo.new(TEAM_WARNING_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	warningFades = {
		TweenService:Create(teamWarning, info, { TextTransparency = 1 }),
		TweenService:Create(stroke, info, { Transparency = 1 }),
	}
	for _, fade in warningFades do
		fade:Play()
	end
	warningFades[1].Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			teamWarning.Visible = false
		end
	end)
end)
editTeam.Activated:Connect(function()
	hudClosed = false
	UiMotion.Pop(hud)
end)

-- Follows the server ------------------------------------------------------------------------------------------------------
local wasLive = false
local wasFight = false
local teamKey = nil
local warningUntil = 0
local stopFlash = nil
local stopPulse = nil
local pulsing = false
local invitedStart = nil
local inviteUntil = 0

local function clockText(seconds)
	local whole = math.ceil(math.max(0, seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local statusRaw = nil
local statusRows = {} -- id -> { EndsAt, Count }

-- One cell per active effect, each gone at its own EndsAt, on this client's clock of the server's time. A row with no EndsAt shows until it goes.
local function drawStatus()
	local raw = player:GetAttribute("BossStatus")
	if raw ~= statusRaw then
		statusRaw = raw
		statusRows = {}
		local ok, rows = pcall(HttpService.JSONDecode, HttpService, raw or "[]")
		for _, row in ok and rows or {} do
			statusRows[row.Id] = row
		end
	end
	for id, cell in statusCells do
		local row = statusRows[id]
		local left = row and row.EndsAt and row.EndsAt - workspace:GetServerTimeNow()
		cell.Frame.Visible = row ~= nil and (left == nil or left > 0)
		cell.Left.Text = left and left > 0 and math.ceil(left) .. "s" or ""
		cell.Stack.Visible = row ~= nil and (row.Count or 1) > 1
		cell.Stack.Text = cell.Stack.Visible and "x" .. row.Count or ""
	end
end

-- Phase 2's rates, top to bottom one row at a time from the moment the bar is full (BOSS_EVENT_SPEC "Phase 2"). From time alone, so a late
-- view has them all, and stage 1 has Phase 1's.
local function drawDrops(stage, now)
	local schedule = ReplicatedStorage:GetAttribute("BossScheduleStart")
	local since = stage == 2 and schedule and now - schedule - Cfg.IntroSeconds or -1
	local final = since < 0 and 0 or UiMotion.Reduced() and #dropRows or math.floor(since / CASCADE_GAP) + 1
	for i, row in dropRows do
		local text = dropTexts[row][i <= final and 2 or 1]
		if row.Text ~= text then
			row.Text = text
			if i <= final then
				UiMotion.Pop(row)
			end
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

-- The button shows to everyone outside the arena; the popup's rows follow the event. Read afresh at each call (UiBossPaid).
local function drawBossButton(phase, inEvent, joinable)
	local shown = not inEvent and not tutorialActive()
	if joinable ~= pulsing then
		pulsing = joinable
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
	bossButton.Visible = shown
	bossesOpen = bossesOpen and shown
	bossesPanel.Visible = bossesOpen and not PanelSwitch.AnyOpen()
	if not bossesPanel.Visible then
		return
	end
	local active = phase ~= nil
	local armed = teleport.Active -- has a Sidekick: both Go and the spawn need one
	bossStatus.Text = active and RAGING_TEXT or ABOUT_TEXT
	bossDetailsHeading.Visible = not active
	bossDetails.Visible = not active
	bossNext.Visible = not active
	local steady = ""
	if active then
		bossAction.Text = "Go"
		bossAction.Active = joinable and armed
		AnimeSkin.Button(bossAction, "Go")
		if not bossAction.Active then
			bossAction.BackgroundColor3 = Palette.Disabled
		end
		steady = not joinable and CLOSED_TEXT or not armed and LOCKED_TEXT or ""
	else
		local sale = Monetization.BossSpawn
		local credit = (player:GetAttribute("BossCredit") or 0) >= 1
		local restricted = player:GetAttribute("PaidRandomRestricted") == true -- pressable: the press shows the error
		local buyable = armed and (restricted or sale.ProductId > 0)
		bossAction.Text = credit and "Spawn boss (ready)"
			or sale.ProductId > 0 and ("Spawn boss %d R$"):format(sale.Robux)
			or "Coming soon"
		bossAction.Active = armed and (credit or buyable)
		-- Active is armed and (credit or buyable): an inactive action is the Disabled grey.
		AnimeSkin.Button(bossAction, not credit and buyable and "Danger" or "Go")
		if not bossAction.Active then
			bossAction.BackgroundColor3 = Palette.Disabled
		end
		steady = not armed and LOCKED_TEXT or ""
		local nextAt = ReplicatedStorage:GetAttribute("BossEventNextAt")
		bossNext.Text = nextAt and "Next event in " .. clockText(nextAt - workspace:GetServerTimeNow()) or ""
		bossesFrame.Footer(bossNext.Text)
	end
	local passing = os.clock() < promptUntil
	bossPrompt.Text = passing and promptText or steady
	bossPrompt.Visible = bossPrompt.Text ~= ""
end

local function render()
	local phase = ReplicatedStorage:GetAttribute("BossEventPhase")
	local inEvent = player:GetAttribute("BossEvent") == true
	local live = phase ~= nil or inEvent
	if not live and not wasLive then
		drawBossButton(phase, inEvent, false)
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
		-- Opens on the last event's team, as the server's join does (design doc 4.37); with none, the slots start empty.
		local gear = SidekickView.Gear(player)
		picks = {}
		for _, id in string.split(inEvent and player:GetAttribute("LastBossTeam") or "", ",") do
			if gear[id] and CharacterCatalog.Get(id) and #picks < #slots and not table.find(picks, id) then
				table.insert(picks, id)
			end
		end
		confirmed, sentKey = table.clone(picks), table.concat(picks, ",")
		hudClosed = false
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

	local joinable = phase ~= nil
		and not inEvent
		and elapsed < Cfg.JoinSeconds
		and ReplicatedStorage:GetAttribute("BossEventStage") ~= 2 -- Phase 1's defeat closes teleporting (design doc 4.37)
		and not tutorialActive()
	-- Once per event, for its own seconds: after that the Bosses popup carries teleporting.
	if joinable and invitedStart ~= start then
		invitedStart = start
		inviteUntil = os.clock() + Cfg.InviteSeconds
		invite.Visible = declinedStart ~= start
		UiMotion.Pop(invite) -- cue: DuelInvite
	elseif not joinable or declinedStart == start or os.clock() >= inviteUntil then
		invite.Visible = false
	end

	drawBossButton(phase, inEvent, joinable)
	hud.Visible = inEvent and phase == "Prep" and not hudClosed and not panelOpen
	editTeam.Visible = inEvent and phase == "Prep" and hudClosed and not panelOpen
	bar.Visible = inFight
	dropList.Visible = inFight and warningUntil == 0 and not panelOpen
	warning.Visible = inFight and warningUntil > 0 and not panelOpen
	leave.Visible = inEvent and phase ~= nil and not panelOpen

	-- From the server's end time, so a late view is as far along. Past it, full at 1 until the server revives the team.
	local now = workspace:GetServerTimeNow()
	local screamEnds = ReplicatedStorage:GetAttribute("BossScreamEndsAt")
	local screamLeft = type(screamEnds) == "number" and screamEnds > now and screamEnds - now or nil
	local waitEnds = player:GetAttribute("BossWaitEndsAt")
	exhausted.Visible = inEvent and type(waitEnds) == "number" and not screamLeft
	if exhausted.Visible then
		local left = waitEnds - now
		-- 8.5 until the first whole second is reached, then by whole seconds.
		exhaustedCount.Text = left > math.floor(Cfg.RefillWaitSeconds) and tostring(Cfg.RefillWaitSeconds)
			or tostring(math.max(1, math.ceil(left)))
		loadingFill.Size = UDim2.fromScale(math.clamp(1 - left / Cfg.RefillWaitSeconds, 0, 1), 1)
	end

	if invite.Visible then
		inviteCountdown.Text = clockText(Cfg.JoinSeconds - elapsed)
	end
	if hud.Visible then
		hudCountdown.Text = clockText(Cfg.PrepSeconds - elapsed)
		teamDamage.Text = "Team damage: " .. HudFormat.SpeedText(player:GetAttribute("BossTeamDamage"))
		local total = 0
		for i in picks do
			total += player:GetAttribute("BossTeamStamina" .. i) or 0
		end
		avgStamina.Text = #picks > 0 and string.format("Average stamina: %.1f s", total / #picks)
			or "Average stamina: -"
	end
	if bar.Visible then
		local hp = ReplicatedStorage:GetAttribute("BossEventHp") or 0
		local max = ReplicatedStorage:GetAttribute("BossEventMaxHp") or 0
		-- Left to right over the intro, from the server's start: a late joiner sees the same width as everyone.
		local intro = UiMotion.Reduced() and 1 or math.clamp((elapsed - Cfg.PrepSeconds) / Cfg.RiseSeconds, 0, 1)
		local width = max > 0 and math.clamp(hp / max, 0, 1) * intro or 0
		-- The scream fills the new bar from empty, from its end time, for a late view too.
		fill.Size = UDim2.fromScale(screamLeft and math.clamp(1 - screamLeft / Cfg.ScreamSeconds, 0, 1) or width, 1)
		barValue.Text = HudFormat.Commas(math.ceil(hp)) .. "/" .. HudFormat.Commas(math.ceil(max))
		local endsAt = ReplicatedStorage:GetAttribute("BossEventEndsAt")
		bossTimer.Text = clockText(endsAt and endsAt - now or Cfg.TotalSeconds - elapsed)
		local stage = ReplicatedStorage:GetAttribute("BossEventStage") or 1
		barTitle.Text = stage == 2 and TITLE_STAGE_2 or TITLE_STAGE_1
		barTitle.TextColor3 = stage == 2 and TITLE_STAGE_2_COLOR or Palette.White
		drawDrops(stage, now)
		drawStatus()
	end
end

RunService.Heartbeat:Connect(render)
ReplicatedStorage:GetAttributeChangedSignal("BossScreamEndsAt"):Connect(render) -- the fill is low from the scream's first frame
