--!nonstrict
-- Team row (owner 2026-11-02 / 2026-11-03, docs/TEAM_AND_STAMINA_SPEC.md "HUD"): 3 circle portraits in the retired
-- Level bar's place, slot 1-3 left to right. Each portrait is only the avatar head; rarity is never shown. While
-- running, each portrait's background fills like a liquid level to Stamina<n>; the active slot (RunSlot) is enlarged
-- with a pulsing gold glow and a bobbing marker, pops on a tag-in; a slot at 0 fades grey and shrinks. A badge above
-- the row names the team bonus (TeamBonus). Hover (tap on touch) opens an info card: name, category and its effect,
-- cruise and stamina (server attributes TeamCruise<n> / TeamStamina<n>). Display only. Motion goes through UiMotion
-- (design doc 4.20): tweens land at once and the active pulse + bob stop while motion is reduced.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(shared.CharacterCatalog)
local RaceConfig = require(shared.RaceConfig)
local SeriesCatalog = require(shared.SeriesCatalog)
local StaminaConfig = require(shared.StaminaConfig)
local Components = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("RacerComponents"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local SLOTS = 3
local CIRCLE = 48 -- px (placeholder)
local CARD_WIDTH = 240 -- px (placeholder)
local ACTIVE_SCALE = 1.25 -- placeholders
local TIRED_SCALE = 0.88
local GOLD = Color3.fromRGB(255, 214, 80)
local DIM = Color3.fromRGB(28, 38, 62)
local RING = Color3.fromRGB(230, 236, 250)
local GREY = Color3.fromRGB(110, 110, 110)
local CATEGORY_COLORS = {
	Sprinter = Color3.fromRGB(255, 110, 70),
	Balanced = Color3.fromRGB(90, 210, 120),
	Marathoner = Color3.fromRGB(80, 160, 255),
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
		Font = Enum.Font.FredokaOne,
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
	Position = UDim2.fromOffset(0, -8), -- the enlarged active circle clears the TURBO LUCK bar below
	ZIndex = 5,
}, level)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 16),
}, row)

-- Overlay for the badge, marker and card: outside the list layout so it can sit anywhere over the row.
local overlay = make("Frame", {
	Name = "TeamOverlay",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Position = row.Position,
}, level)

local badge = text(overlay, "Bonus", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -30),
	AutomaticSize = Enum.AutomaticSize.X, -- preset lines run longer than the row
	Size = UDim2.fromOffset(0, 20),
	TextSize = 13,
	TextColor3 = GOLD,
	BackgroundTransparency = 0.3,
	BackgroundColor3 = Color3.fromRGB(18, 24, 44), -- stays readable over every biome
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

local card = make("Frame", {
	Name = "InfoCard",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(CARD_WIDTH, 96),
	BackgroundColor3 = Color3.fromRGB(18, 24, 44),
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
local cardScale = make("UIScale", { Scale = 1 }, card)
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
	TextColor3 = Color3.fromRGB(190, 200, 225),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local effect = text(card, "Effect", { -- own line: beside the chip it wrapped into the stats below
	Position = UDim2.fromOffset(0, 50),
	Size = UDim2.new(1, 0, 0, 16),
	TextSize = 13,
	TextColor3 = Color3.fromRGB(190, 200, 225),
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

local function teamIds()
	return string.split(player:GetAttribute("Team") or "", ",")
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
	local cruise = tonumber(player:GetAttribute("TeamCruise" .. slot))
	local seconds = tonumber(player:GetAttribute("TeamStamina" .. slot))
	stats.Text = (cruise and string.format("%d studs/s", math.floor(cruise + 0.5)) or "-")
		.. "  ·  "
		.. (seconds and string.format("%.1f s stamina", seconds) or "-")
	hint.Text = CATEGORY_HINT[category] or ""
	-- Centred on the portrait, but kept on screen (the row sits mid-screen on desktop, near the edges on a phone)
	local half = card.AbsoluteSize.X / 2 + 8
	local screen = hud.AbsoluteSize.X
	local center = circle.Frame.AbsolutePosition.X + circle.Frame.AbsoluteSize.X / 2
	center = math.clamp(center, half, math.max(half, screen - half))
	card.Position = UDim2.fromOffset((center - overlay.AbsolutePosition.X) / hudScale(), -40)
	if not card.Visible or shownSlot ~= slot then
		cardScale.Scale = 0.85
		tween(cardScale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	card.Visible = true
	shownSlot = slot
end

for slot = 1, SLOTS do
	local c = make("Frame", {
		Name = "Slot" .. slot,
		LayoutOrder = slot,
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
	local clip = make("CanvasGroup", { -- a Frame clips square; a CanvasGroup clips to the round corner
		Name = "Clip",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
	}, c)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, clip)
	local liquid = make("Frame", { -- stamina level behind the head
		Name = "Stamina",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = StaminaConfig.COLORS.Full,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, clip)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(0, 0.45),
	}, liquid)
	local ring = make("UIStroke", {
		Thickness = 3,
		Color = RING,
		Transparency = 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, c)
	local scale = make("UIScale", { Scale = 1 }, c)
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
		Clip = clip,
		Glow = glow,
		Liquid = liquid,
		Ring = ring,
		Scale = scale,
		Id = nil,
		Art = nil,
		State = nil,
	}
end

-- Head only: the body (and its rarity belt) never shows, so rarity is not evident on the row.
local function headArt(circle, spec)
	local art = Components.RunnerArt(circle.Clip, "Art", spec, UDim2.new(), UDim2.fromScale(1, 1))
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
		art.CurrentCamera.CFrame = CFrame.lookAt(focus + Vector3.new(-0.3, 0.1, -1).Unit * 5.4, focus)
	end
	return art
end

local lastSlot = nil
local function render()
	local team = teamIds()
	local running = player:GetAttribute("RunSlot")
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
		end
		local stamina = tonumber(player:GetAttribute("Stamina" .. slot))
		local active = running == slot and spec ~= nil
		local tired = running ~= nil and spec ~= nil and (stamina or 1) <= 0
		local state = active and "active" or tired and "tired" or "idle"
		-- liquid level: only while running
		local pct = running ~= nil and spec and stamina and math.clamp(stamina / 100, 0, 1) or 0
		tween(circle.Liquid, 0.12, {
			Size = UDim2.fromScale(1, pct),
			BackgroundColor3 = StaminaConfig.Color(stamina or 100),
		}, Enum.EasingStyle.Linear)
		circle.Frame.BackgroundTransparency = spec and 0 or 0.25
		if circle.State ~= state then
			circle.State = state
			tween(circle.Ring, 0.2, {
				Color = active and GOLD or tired and GREY or RING,
				Thickness = active and 4 or 3,
				Transparency = active and 0 or 0.25,
			})
			tween(circle.Clip, 0.35, {
				GroupColor3 = tired and GREY or Color3.new(1, 1, 1),
				GroupTransparency = tired and 0.45 or 0,
			})
			tween(circle.Frame, 0.35, { BackgroundColor3 = tired and Color3.fromRGB(50, 50, 55) or DIM })
			if not active then
				tween(circle.Glow, 0.2, { BackgroundTransparency = 1 })
				tween(circle.Scale, 0.3, { Scale = tired and TIRED_SCALE or 1 })
			end
		end
		if active and lastSlot ~= slot then
			-- tag-in pop
			circle.Scale.Scale = ACTIVE_SCALE + 0.3
			tween(circle.Scale, 0.4, { Scale = ACTIVE_SCALE }, Enum.EasingStyle.Back)
		end
	end
	lastSlot = running
	-- team bonus badge
	local kind, seriesId = string.match(player:GetAttribute("TeamBonus") or "", "^(%a+):(.+)$")
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

-- pulse + marker bob for the active runner
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	local slot = player:GetAttribute("RunSlot")
	local circle = slot and circles[slot]
	if not (circle and circle.State == "active") then
		marker.Visible = false
		return
	end
	local reduced = UiMotion.Reduced()
	circle.Glow.BackgroundTransparency = 0.55 + (reduced and 0 or 0.25 * math.sin(clock * 5))
	local f = circle.Frame
	local scale = hudScale()
	marker.Visible = true
	marker.Position = UDim2.fromOffset(
		(f.AbsolutePosition.X + f.AbsoluteSize.X / 2 - overlay.AbsolutePosition.X) / scale,
		(f.AbsolutePosition.Y - overlay.AbsolutePosition.Y) / scale - 4 + (reduced and 0 or 3 * math.sin(clock * 6))
	)
end)

player.AttributeChanged:Connect(function(name)
	if
		name == "Team"
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
