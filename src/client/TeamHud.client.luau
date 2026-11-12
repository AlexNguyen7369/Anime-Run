--!nonstrict
-- Team row (owner 2026-11-02 / 2026-11-03, docs/TEAM_AND_STAMINA_SPEC.md "HUD"): 3 circle portraits in the retired
-- Level bar's place, slot 1-3 left to right. Each portrait is only the avatar head, breaking out of a dark circle;
-- rarity is never shown. A thick arc on the lower right shows Stamina<n> and a slanted number its seconds left, both
-- eased per frame; the active slot (RunSlot) is enlarged with a pulsing gold glow and a bobbing marker, pops on a
-- tag-in; a slot at 0 fades grey and shrinks. Slots sit at fixed positions, so scaling one never moves the others. A badge above
-- the row names the team bonus (TeamBonus). Hover (tap on touch) opens an info card: name, category and its effect,
-- cruise and stamina (server attributes TeamCruise<n> / TeamStamina<n>). Display only. Motion goes through UiMotion
-- (design doc 4.20): tweens land at once and the active pulse + bob stop while motion is reduced.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(shared.CharacterCatalog)
local CharacterHeads = require(shared.CharacterHeads)
local BossCfg = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BossEventConfig"))
local RaceConfig = require(shared.RaceConfig)
local SeriesCatalog = require(shared.SeriesCatalog)
local StaminaConfig = require(shared.StaminaConfig)
local PowerUpConfig = require(shared.PowerUpConfig)
local Components = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("RacerComponents"))
local UiTheme = require(shared.UiTheme)
local Palette = UiTheme.Palette
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local SLOTS = 3
local CIRCLE = 52 -- px (placeholder)
local SPACING = 78 -- px between slot centres (placeholder)
local ARC_THICK = 8 -- px (placeholder)
local ARC_START, ARC_SWEEP = 125, 155 -- degrees clockwise from east: empty end at lower left, full end at the right
local ARC_DOTS = 24 -- straight band segments per Track and per Fill; shortcut: no ring image asset, upload one if the edge ever looks faceted
-- Design doc 4.40: a curved parallelogram, both ends cut on the same slant off the radial (proposed)
local ARC_SLANT = math.tan(math.rad(30))
local ARC_LANES = 4 -- strips across the band at each slanted end: the cut is a fine staircase
local ARC_OUTLINE = 1.5 -- px of the dark Track beyond the Fill on every side
local ARC_RADIUS = CIRCLE / 2 - 1
local ARC_LEN = ARC_RADIUS * math.rad(ARC_SWEEP) -- px along the centre line
local FILL_CUT = ARC_THICK / 2 * ARC_SLANT -- px the slanted cut leans from the centre line to an edge
local FILL_STEP = (ARC_LEN - 2 * FILL_CUT) / ARC_DOTS
local EASE = 10 -- per second, arc and number easing (placeholder)
local HEAD_FIT = 0.95 -- camera distance factor for the head (placeholder)
local CARD_WIDTH = 240 -- px (placeholder)
local ACTIVE_SCALE = 1.18 -- placeholders
local TIRED_SCALE = 0.88
local GOLD = Palette.Gold
local DIM = Palette.TeamDim
local RING = Palette.TeamRing
local GREY = Palette.TeamGrey
local CATEGORY_COLORS = {
	Sprinter = Palette.Sprinter,
	Balanced = Palette.Balanced,
	Marathoner = Palette.Marathoner,
}
local CATEGORY_HINT = { Sprinter = "fast, tires sooner", Balanced = "all-round", Marathoner = "slower, runs longer" }

local hud = player:WaitForChild("PlayerGui"):WaitForChild("RacerHud")
local level = hud:WaitForChild("Level") -- kept (hidden face) because HudChrome places Items / Upgrade from it
local shadow = level:FindFirstChild("Shadow")
if shadow then
	shadow.Visible = false
end

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end
local function text(parent, name, props)
	local label = make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Font = UiTheme.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = false,
		ZIndex = 31,
	}, parent)
	for k, v in props do
		label[k] = v
	end
	make("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.3 }, label)
	return label
end
local function tween(inst, seconds, goal, style, dir)
	local t = UiMotion.Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local row = make("Frame", {
	Name = "Team",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromOffset(0, -14), -- the enlarged active circle clears the TURBO LUCK bar below
	ZIndex = 5,
}, level)

-- Overlay for the badge, marker and card, so they can sit anywhere over the row.
local overlay = make("Frame", {
	Name = "TeamOverlay",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Position = row.Position,
}, level)

local badge = text(overlay, "Bonus", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -44),
	AutomaticSize = Enum.AutomaticSize.X, -- preset lines run longer than the row
	Size = UDim2.fromOffset(0, 20),
	TextSize = 13,
	TextColor3 = GOLD,
	BackgroundTransparency = 0.3,
	BackgroundColor3 = Palette.TeamPlate, -- stays readable over every biome
	Visible = false,
	ZIndex = 8,
})
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, badge)
make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, badge)

local marker = text(overlay, "Marker", {
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(20, 14),
	Text = "▼",
	TextSize = 14,
	TextColor3 = GOLD,
	Visible = false,
	ZIndex = 8,
})

-- Speed power-up badge (design doc 4.44, draft H2): on the running portrait's top-right corner while
-- PowerSpeedUntil is ahead; its ring of dots empties over the boost.
local BADGE = 26 -- px (proposed)
local BADGE_DOTS = 16
local powerBadge = make("Frame", {
	Name = "PowerBadge",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(BADGE, BADGE),
	BackgroundColor3 = DIM,
	Visible = false,
	ZIndex = 12,
}, overlay)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, powerBadge)
make("UIStroke", { Thickness = 1.5, Color = PowerUpConfig.COLORS.Speed }, powerBadge)
text(powerBadge, "Symbol", {
	Size = UDim2.fromScale(1, 1),
	Text = "»",
	TextSize = 18,
	TextColor3 = PowerUpConfig.COLORS.Speed,
	ZIndex = 13,
})
local badgeDots = {}
for i = 1, BADGE_DOTS do
	local a = math.rad(-90 + (i - 0.5) * 360 / BADGE_DOTS) -- from the top, clockwise
	badgeDots[i] = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, (BADGE / 2 + 3) * math.cos(a), 0.5, (BADGE / 2 + 3) * math.sin(a)),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = PowerUpConfig.COLORS.Speed,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, powerBadge)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, badgeDots[i])
end

local card = make("Frame", {
	Name = "InfoCard",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(CARD_WIDTH, 96),
	BackgroundColor3 = Palette.TeamPlate,
	BackgroundTransparency = 0.08,
	Visible = false,
	ZIndex = 30,
}, overlay)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
local cardStroke = make("UIStroke", { Thickness = 2, Color = RING, Transparency = 0.2 }, card)
make("UIPadding", {
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
	PaddingTop = UDim.new(0, 6),
}, card)
local cardName = text(card, "Name", {
	Size = UDim2.new(1, 0, 0, 22),
	TextSize = 19,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local chip = make("Frame", {
	Name = "Category",
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.fromOffset(92, 20),
	BackgroundColor3 = CATEGORY_COLORS.Balanced,
	ZIndex = 31,
}, card)
make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, chip)
local chipText = text(chip, "Text", { Size = UDim2.fromScale(1, 1), TextSize = 13 })
local hint = text(card, "Hint", {
	Position = UDim2.fromOffset(100, 26),
	Size = UDim2.new(1, -100, 0, 20),
	TextSize = 12,
	TextColor3 = Palette.TeamSoft,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local effect = text(card, "Effect", { -- own line: beside the chip it wrapped into the stats below
	Position = UDim2.fromOffset(0, 50),
	Size = UDim2.new(1, 0, 0, 16),
	TextSize = 13,
	TextColor3 = Palette.TeamSoft,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local stats = text(card, "Stats", {
	Position = UDim2.fromOffset(0, 68),
	Size = UDim2.new(1, 0, 0, 18),
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local circles = {}
local shownSlot = nil

-- The event roster while in an event (design doc 4.37), the main Team otherwise. The two never mix.
local function inEvent()
	return player:GetAttribute("BossEvent") == true
end

local function teamIds()
	return string.split(player:GetAttribute(inEvent() and "BossTeam" or "Team") or "", ",")
end

local function teamStat(stat, slot)
	return tonumber(player:GetAttribute((inEvent() and "BossTeam" or "Team") .. stat .. slot))
end

-- Seconds left of the event's exhausted wait, nil outside it.
local function waitLeft()
	local ends = player:GetAttribute("BossWaitEndsAt")
	return inEvent() and type(ends) == "number" and math.max(0, ends - workspace:GetServerTimeNow()) or nil
end

local function factor(x)
	return (x == math.floor(x) and string.format("x%d", x) or string.format("x%.2g", x))
end

-- Screen px per Offset px of the overlay (the HUD's layout UIScale), to turn Absolute positions into offsets.
local function hudScale()
	local width = level.Size.X.Offset
	return width > 0 and overlay.AbsoluteSize.X / width or 1
end

local function showCard(slot)
	local circle = circles[slot]
	local spec = circle and circle.Id and CharacterCatalog.Get(circle.Id)
	if not spec then
		card.Visible = false
		shownSlot = nil
		return
	end
	local category = spec.Category or "Balanced"
	cardName.Text = spec.Name or spec.Id
	chip.BackgroundColor3 = CATEGORY_COLORS[category] or CATEGORY_COLORS.Balanced
	cardStroke.Color = chip.BackgroundColor3
	chipText.Text = string.upper(category)
	effect.Text = factor(RaceConfig.CATEGORY_SPEED[category] or 1)
		.. " speed · "
		.. factor(StaminaConfig.CATEGORY[category] or 1)
		.. " stamina"
	local cruise = teamStat("Cruise", slot)
	local seconds = teamStat("Stamina", slot)
	stats.Text = (cruise and string.format("%d studs/s", math.floor(cruise + 0.5)) or "-")
		.. "  ·  "
		.. (seconds == math.huge and "∞ stamina" or seconds and string.format("%.1f s stamina", seconds) or "-")
	hint.Text = CATEGORY_HINT[category] or ""
	-- Centred on the portrait, but kept on screen (the row sits mid-screen on desktop, near the edges on a phone)
	local half = card.AbsoluteSize.X / 2 + 8
	local screen = hud.AbsoluteSize.X
	local center = circle.Frame.AbsolutePosition.X + circle.Frame.AbsoluteSize.X / 2
	center = math.clamp(center, half, math.max(half, screen - half))
	card.Position = UDim2.fromOffset((center - overlay.AbsolutePosition.X) / hudScale(), -52)
	if not card.Visible or shownSlot ~= slot then
		UiMotion.Pop(card)
	end
	card.Visible = true
	shownSlot = slot
end

-- Angle (radians, clockwise from east) at `s` px along the arc's centre line; on the lane `rho` px off the centre
-- (outward positive) it lands on the slanted cut through that point.
local function arcAngle(s, rho)
	rho = rho or 0
	return math.rad(ARC_START) - s / ARC_RADIUS - rho * ARC_SLANT / (ARC_RADIUS + rho)
end

local function piece(parent, name, color, z)
	return make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
end

-- A straight piece of the band from angle a0 to a1 at radius r, laid along the arc's tangent (flat sides, no corner).
local function place(frame, a0, a1, r, thick, extra)
	local mid = (a0 + a1) / 2
	local len = 2 * (r + thick / 2) * math.sin(math.abs(a1 - a0) / 2) + extra -- outer chord: no gap on the outside
	frame.Position = UDim2.new(0.5, r * math.cos(mid), 0.5, r * math.sin(mid))
	frame.Size = UDim2.fromOffset(len, thick)
	frame.Rotation = math.deg(mid) + 90
end

-- ARC_DOTS segments along the centre line from `from` to `to` px: the band's square-cut body.
local function arcBody(parent, name, from, to, thick, color, z)
	local list, step = {}, (to - from) / ARC_DOTS
	for i = 1, ARC_DOTS do
		list[i] = piece(parent, name, color, z)
		place(list[i], arcAngle(from + (i - 1) * step), arcAngle(from + i * step), ARC_RADIUS, thick, 1) -- 1 px overlap hides seams
	end
	return list
end

local function arcLanes(parent, name, color, z)
	local list = {}
	for k = 1, ARC_LANES do
		list[k] = piece(parent, name, color, z)
	end
	return list
end

-- A slanted end: every lane runs from the cut through `cut` px back `len` px (negative: forward), so the end piece is
-- itself a small parallelogram that covers the body's square end.
local function placeEnd(lanes, cut, len, thick)
	for k, lane in lanes do
		local rho = (k - 0.5) * thick / ARC_LANES - thick / 2
		place(lane, arcAngle(cut, rho), arcAngle(cut - len, rho), ARC_RADIUS + rho, thick / ARC_LANES + 0.5, 0)
	end
end

for slot = 1, SLOTS do
	local c = make("Frame", {
		Name = "Slot" .. slot,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, (slot - 2) * SPACING, 0.5, 0),
		Size = UDim2.fromOffset(CIRCLE, CIRCLE),
		BackgroundColor3 = DIM,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, row)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, c)
	local glow = make("Frame", { -- behind the circle; pulses on the active runner
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 14, 1, 14),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, c)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, glow)
	local ring = make("UIStroke", {
		Thickness = 2,
		Color = RING,
		Transparency = 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, c)
	local scale = make("UIScale", { Scale = 1 }, c)
	local arc = make("Frame", { Name = "Arc", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8 }, c)
	-- Track: the dark outline and the empty part, the Fill's shape grown by ARC_OUTLINE on every side
	local trackThick = ARC_THICK + 2 * ARC_OUTLINE
	local trackCut = trackThick / 2 * ARC_SLANT
	arcBody(arc, "Track", trackCut - ARC_OUTLINE, ARC_LEN + ARC_OUTLINE - trackCut, trackThick, DIM, 8)
	placeEnd(arcLanes(arc, "Track", DIM, 8), -ARC_OUTLINE, -(2 * trackCut + 1), trackThick)
	placeEnd(arcLanes(arc, "Track", DIM, 8), ARC_LEN + ARC_OUTLINE, 2 * trackCut + 1, trackThick)
	local dots = arcBody(arc, "Fill", FILL_CUT, ARC_LEN - FILL_CUT, ARC_THICK, StaminaConfig.COLORS.Full, 9)
	local fillStart = arcLanes(arc, "FillStart", StaminaConfig.COLORS.Full, 9) -- the empty end's slanted cut
	placeEnd(fillStart, 0, -(2 * FILL_CUT + 1), ARC_THICK)
	-- The moving end: its lanes slide with the stamina, cut on the same slant
	local tip =
		make("Frame", { Name = "Tip", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9 }, arc)
	local tipLanes = arcLanes(tip, "Lane", StaminaConfig.COLORS.Full, 9)
	local number = text(c, "Seconds", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -12, 1, 6),
		Size = UDim2.fromOffset(34, 24),
		Font = UiTheme.Font,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
	})
	number:FindFirstChildOfClass("UIStroke").Thickness = 2.5
	number:FindFirstChildOfClass("UIStroke").Color = DIM
	number:FindFirstChildOfClass("UIStroke").Transparency = 0
	-- Hover / tap on the circle itself (no invisible button: the row is display-only, not a control)
	c.MouseEnter:Connect(function()
		showCard(slot)
	end)
	c.MouseLeave:Connect(function()
		if shownSlot == slot then
			card.Visible = false
			shownSlot = nil
		end
	end)
	c.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if shownSlot == slot and card.Visible then -- touch: tap toggles
			card.Visible = false
			shownSlot = nil
		else
			showCard(slot)
		end
	end)
	circles[slot] = {
		Frame = c,
		Glow = glow,
		Ring = ring,
		Scale = scale,
		Arc = arc,
		Dots = dots,
		FillStart = fillStart,
		Tip = tip,
		TipLanes = tipLanes,
		Number = number,
		Id = nil,
		Art = nil,
		State = nil,
		Target = 1, -- 0-1, the server's stamina
		Shown = nil, -- 0-1, eased toward Target each frame
		Color = StaminaConfig.COLORS.Full,
		Seconds = nil,
	}
end

-- Draws the arc at `t` (0-1): Fill segments up to t (their share of all Fill is t, to one segment), the slanted tip
-- just past the last one. At t = 1 the tip's cut meets the Track's full end.
local function drawArc(circle, t)
	local last = t * ARC_DOTS + 1e-6
	for i, d in circle.Dots do
		d.Visible = t > 0 and i <= last
	end
	for _, lane in circle.FillStart do
		lane.Visible = t > 0
	end
	circle.Tip.Visible = t > 0
	local cut = 2 * FILL_CUT + t * (ARC_LEN - 2 * FILL_CUT) -- segment i ends behind this cut's inner edge once i <= t * ARC_DOTS
	placeEnd(circle.TipLanes, cut, math.min(2 * FILL_CUT + FILL_STEP + 1, cut), ARC_THICK)
end

local function paintArc(circle, color)
	for _, list in { circle.Dots, circle.FillStart, circle.TipLanes } do
		for _, d in list do
			d.BackgroundColor3 = color
		end
	end
end

-- The drawn portrait, or with none yet the live model cut to its head: the body (and its rarity belt) never shows, so
-- rarity is not evident on the row.
local function headArt(circle, spec)
	local drawn = CharacterHeads[spec.Id] or CharacterHeads[spec.Model or spec.Id]
	if drawn then
		-- The head-only art (CHARACTER_GACHA_SPEC "Digital art portrait"), breaking out of the top like the live head
		local image = Instance.new("ImageLabel")
		image.Name = "Art"
		image.BackgroundTransparency = 1
		image.Position = UDim2.fromScale(-0.2, -0.34)
		image.Size = UDim2.fromScale(1.4, 1.4)
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = drawn
		image.ZIndex = 7
		image.Parent = circle.Frame
		return image
	end
	-- Larger than the circle and not clipped: the head breaks out of the top
	local art =
		Components.PortraitArt(circle.Frame, "Art", spec, UDim2.fromScale(-0.2, -0.34), UDim2.fromScale(1.4, 1.4))
	art.ZIndex = 7
	local rig = art:FindFirstChildWhichIsA("Model")
	local head = rig and rig:FindFirstChild("Head")
	if not head then
		return art
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") and d ~= head and not d:IsDescendantOf(head) then
			d:Destroy()
		end
	end
	if art.CurrentCamera then
		art.CurrentCamera.FieldOfView = 30
		local focus = head.Position
		-- Fitted to the head's size: a character model's head (with its hair) is larger than the placeholder's
		local distance = 0.5 * head.Size.Magnitude / math.sin(math.rad(15)) * HEAD_FIT
		art.CurrentCamera.CFrame = CFrame.lookAt(focus + Vector3.new(-0.45, 0.1, -1).Unit * distance, focus)
	end
	return art
end

local lastSlot = nil
local wasWaiting = false
local function render()
	local team = teamIds()
	local running = player:GetAttribute("RunSlot")
	local waiting = waitLeft() ~= nil
	local bossLine = player:GetAttribute("BossLine")
	if wasWaiting and not waiting and not UiMotion.Reduced() then
		lastSlot = nil -- revived: the first runner takes the tag-in pop, even in a team of 1
	end
	wasWaiting = waiting
	for slot, circle in circles do
		local spec = team[slot] and team[slot] ~= "" and CharacterCatalog.Get(team[slot])
		local id = spec and spec.Id
		if circle.Id ~= id then
			circle.Id = id
			if circle.Art then
				circle.Art:Destroy()
				circle.Art = nil
			end
			if spec then
				circle.Art = headArt(circle, spec)
			end
			circle.State = nil -- the new art takes the current look
		end
		local stamina = tonumber(player:GetAttribute("Stamina" .. slot))
		local active = running == slot and spec ~= nil and not waiting
		local gone = inEvent()
			and type(bossLine) == "string"
			and not table.find(string.split(bossLine, ","), tostring(slot))
		local tired = spec ~= nil and (waiting or gone or (running ~= nil and (stamina or 1) <= 0))
		local state = active and "active" or tired and "tired" or "idle"
		-- on foot every runner shows full stamina
		circle.Target = running ~= nil and stamina and math.clamp(stamina / 100, 0, 1) or 1
		circle.Arc.Visible = spec ~= nil
		circle.Number.Visible = spec ~= nil
		circle.Frame.BackgroundTransparency = spec and 0 or 0.25
		if circle.State ~= state then
			circle.State = state
			tween(circle.Ring, 0.25, {
				Color = active and GOLD or tired and GREY or RING,
				Thickness = active and 3.5 or 2,
				Transparency = active and 0 or tired and 0.4 or 0.6,
			})
			if circle.Art then
				tween(circle.Art, 0.35, {
					ImageColor3 = tired and GREY or Color3.new(1, 1, 1),
					ImageTransparency = tired and 0.45 or 0,
				})
			end
			tween(circle.Frame, 0.35, { BackgroundColor3 = tired and Palette.TeamTired or DIM })
			if not active then
				tween(circle.Glow, 0.25, { BackgroundTransparency = 1 })
				tween(circle.Scale, 0.35, { Scale = tired and TIRED_SCALE or 1 }, Enum.EasingStyle.Quint)
			end
		end
		if active and lastSlot ~= slot then
			-- tag-in pop
			circle.Scale.Scale = ACTIVE_SCALE + 0.12
			tween(circle.Scale, 0.45, { Scale = ACTIVE_SCALE }, Enum.EasingStyle.Back)
		end
	end
	lastSlot = running
	-- team bonus badge
	local kind, seriesId =
		string.match(player:GetAttribute(inEvent() and "BossTeamBonus" or "TeamBonus") or "", "^(%a+):(.+)$")
	local series = seriesId and SeriesCatalog.Get(seriesId)
	if series and kind == "Preset" then
		badge.Text = string.format(
			"★ %s  +%d%% STAMINA  +%d%% SPEED",
			string.upper(series.Preset.Name),
			math.floor((StaminaConfig.TEAM_BONUS.Preset - 1) * 100 + 0.5),
			math.floor((RaceConfig.PRESET_CRUISE - 1) * 100 + 0.5)
		)
	elseif series and kind == "Series" then
		badge.Text = string.format(
			"%s  +%d%% STAMINA",
			string.upper(series.Name),
			math.floor((StaminaConfig.TEAM_BONUS.Series - 1) * 100 + 0.5)
		)
	end
	badge.Visible = series ~= nil
	if shownSlot and card.Visible then
		showCard(shownSlot)
	end
end

-- Per frame: arc and number ease to the server's stamina; pulse + marker bob for the active runner
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	local reduced = UiMotion.Reduced()
	local blend = reduced and 1 or 1 - math.exp(-EASE * dt)
	local running = player:GetAttribute("RunSlot")
	local left = waitLeft()
	for slot, circle in circles do
		if circle.Id then
			local shown = circle.Shown or circle.Target
			if left then
				-- The revive (design doc 4.37): grey bars fill from the bottom, full exactly as the wait ends. Display only.
				shown = math.clamp(1 - left / BossCfg.RefillWaitSeconds, 0, 1)
				circle.Shown = shown
				drawArc(circle, shown)
			elseif shown ~= circle.Target or circle.Shown == nil then
				shown += (circle.Target - shown) * blend
				if math.abs(shown - circle.Target) < 0.001 then
					shown = circle.Target
				end
				circle.Shown = shown
				drawArc(circle, shown)
			end
			local goal = left and GREY or StaminaConfig.Color(shown * 100)
			if circle.Color ~= goal then
				local color = circle.Color:Lerp(goal, blend)
				local gap = math.abs(color.R - goal.R) + math.abs(color.G - goal.G) + math.abs(color.B - goal.B)
				circle.Color = gap < 0.01 and goal or color
				paintArc(circle, circle.Color)
			end
			-- The run's own fixed seconds while running: TeamStamina moves if a potion is used mid-run
			local total = tonumber(player:GetAttribute("RunSeconds" .. slot)) or teamStat("Stamina", slot)
			-- A Stamina power-up's extra (design doc 4.44): the bar stays full, the number counts it, in blue
			local raw = running and tonumber(player:GetAttribute("Stamina" .. slot))
			local over = raw ~= nil and raw > 100 and total ~= nil and total ~= math.huge
			local seconds = total and math.ceil(total * (over and raw / 100 or shown)) or nil
			if seconds ~= circle.Seconds or over ~= circle.Over then
				circle.Seconds, circle.Over = seconds, over
				circle.Number.Text = seconds == math.huge and "∞" or seconds and tostring(seconds) or "" -- Kami
				circle.Number.TextColor3 = over and StaminaConfig.COLORS.Full or Color3.new(1, 1, 1)
			end
		end
	end
	local circle = running and circles[running]
	if not (circle and circle.State == "active") then
		marker.Visible = false
		powerBadge.Visible = false
		return
	end
	local boostLeft = (tonumber(player:GetAttribute("PowerSpeedUntil")) or 0) - workspace:GetServerTimeNow()
	powerBadge.Visible = boostLeft > 0
	if boostLeft > 0 then
		local f, s = circle.Frame, hudScale()
		powerBadge.Position = UDim2.fromOffset(
			(f.AbsolutePosition.X + f.AbsoluteSize.X - overlay.AbsolutePosition.X) / s,
			(f.AbsolutePosition.Y - overlay.AbsolutePosition.Y) / s
		)
		local lit = math.ceil(BADGE_DOTS * math.clamp(boostLeft / PowerUpConfig.SPEED_SECONDS, 0, 1))
		for i, d in badgeDots do
			d.Visible = i <= lit
		end
	end
	circle.Glow.BackgroundTransparency = 0.6 + (reduced and 0 or 0.2 * math.sin(clock * 2.5))
	local f = circle.Frame
	local scale = hudScale()
	marker.Visible = true
	marker.Position = UDim2.fromOffset(
		(f.AbsolutePosition.X + f.AbsoluteSize.X / 2 - overlay.AbsolutePosition.X) / scale,
		(f.AbsolutePosition.Y - overlay.AbsolutePosition.Y) / scale - 14 + (reduced and 0 or 2 * math.sin(clock * 3))
	)
end)

-- The moments of the run (docs/TEAM_AND_STAMINA_SPEC.md): the circle has its own tag-in pop in render.
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RunEvent").OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then
		return
	end
	if ev.Kind == "Swap" then
		UiFeedback.Play("TagIn")
	elseif ev.Kind == "Exhausted" then
		UiFeedback.Play("Exhausted", row)
	end
end)

player.AttributeChanged:Connect(function(name)
	if
		name == "Team"
		or name == "BossEvent"
		or name == "BossWaitEndsAt"
		or name == "BossLine"
		or (string.sub(name, 1, 8) == "BossTeam" and name ~= "BossTeamDamage")
		or name == "RunSlot"
		or name == "TeamBonus"
		or string.sub(name, 1, 7) == "Stamina"
		or string.sub(name, 1, 10) == "TeamCruise"
		or string.sub(name, 1, 11) == "TeamStamina"
	then
		render()
	end
end)
render()

-- The character models load in the background: redraw the heads once they arrive.
task.spawn(function()
	local models = ReplicatedStorage:WaitForChild("CharacterModels")
	if models:GetAttribute("Ready") ~= true then
		models:GetAttributeChangedSignal("Ready"):Wait()
	end
	for _, circle in circles do
		if circle.Art then
			circle.Art:Destroy()
			circle.Art = nil
		end
		circle.Id = nil
	end
	render()
end)
