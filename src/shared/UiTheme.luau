--!nonstrict
-- The one UI theme (docs/HUD_LAYOUT_SPEC.md section 8): tokens shared by baked and code-built screens and the
-- server billboards. The spec `theme` block (ui/specs/*.ui.json, ui/tooling/uispec.py) carries the same values.
local UiTheme = {}

UiTheme.Font = Enum.Font.FredokaOne
UiTheme.Outline = Color3.fromRGB(18, 22, 43)
UiTheme.Radius = { S = 8, M = 12, L = 16 }

-- Placeholders (tunable).
UiTheme.Palette = {
	Money = Color3.fromRGB(60, 255, 60),
	MoneyDeep = Color3.fromRGB(16, 186, 84),
	Speed = Color3.fromRGB(255, 232, 30),
	SpeedDeep = Color3.fromRGB(255, 140, 26),
	Unbanked = Color3.fromRGB(255, 214, 72),
	UnbankedDeep = Color3.fromRGB(255, 150, 30),
	Danger = Color3.fromRGB(255, 70, 80),
	DangerDeep = Color3.fromRGB(150, 14, 40),
	Ahead = Color3.fromRGB(64, 255, 144),
	Behind = Color3.fromRGB(255, 102, 117),
	Panel = Color3.fromRGB(32, 43, 71),
	PanelDeep = Color3.fromRGB(16, 22, 42),
	Row = Color3.fromRGB(41, 55, 83),
	Muted = Color3.fromRGB(104, 111, 135),
	White = Color3.new(1, 1, 1),
	Tile = Color3.fromRGB(47, 107, 255), -- a tile's or card's glow edge
	TileDeep = Color3.fromRGB(14, 24, 52),
	TabIdle = Color3.fromRGB(44, 52, 60),
	TabIdleDeep = Color3.fromRGB(34, 40, 48),
	SlotHere = Color3.fromRGB(55, 110, 180), -- a team slot holding the shown item: tapping takes it off
	Gold = Color3.fromRGB(255, 214, 90),
	SoftText = Color3.fromRGB(210, 220, 240),
	Scrim = Color3.fromRGB(8, 10, 22),
	Reject = Color3.fromRGB(255, 100, 120), -- a server "no" in text
	ShopSky = Color3.fromRGB(110, 205, 255),
	ShopMint = Color3.fromRGB(110, 230, 160),
	ShopAmber = Color3.fromRGB(255, 200, 70),
	ShopCobalt = Color3.fromRGB(90, 140, 255),
	ShopPink = Color3.fromRGB(255, 170, 220),
	ShopLime = Color3.fromRGB(150, 230, 90),
	ShopIce = Color3.fromRGB(130, 180, 255),
	ShopIndigo = Color3.fromRGB(30, 60, 140),
	ShopRedeem = Color3.fromRGB(70, 170, 245),
	ShopGift = Color3.fromRGB(130, 75, 190),
	ShopField = Color3.fromRGB(80, 92, 112),
	Disabled = Color3.fromRGB(70, 75, 90),
	Done = Color3.fromRGB(12, 15, 22),
	Featured = Color3.fromRGB(184, 85, 255),
	DoneText = Color3.fromRGB(120, 120, 120),
	Sky = Color3.fromRGB(80, 170, 250),
	Lime = Color3.fromRGB(184, 255, 28),
	TeamGrey = Color3.fromRGB(110, 110, 110),
	TeamTired = Color3.fromRGB(50, 50, 55),
	TeamDim = Color3.fromRGB(26, 36, 66),
	TeamRing = Color3.fromRGB(230, 236, 250),
	TeamPlate = Color3.fromRGB(18, 24, 44),
	TeamSoft = Color3.fromRGB(190, 200, 225),
	Sprinter = Color3.fromRGB(255, 110, 70),
	Balanced = Color3.fromRGB(90, 210, 120),
	Marathoner = Color3.fromRGB(80, 160, 255),
}

local function child(parent, class, name)
	local value = parent:FindFirstChild(name)
	if not value then
		value = Instance.new(class)
		value.Name = name
		value.Parent = parent
	end
	return value
end

-- Rounds a gui with a token radius ("S", "M", "L" or px).
function UiTheme.Corner(gui, radius)
	local corner = gui:FindFirstChildOfClass("UICorner") or child(gui, "UICorner", "ThemeCorner")
	corner.CornerRadius = UDim.new(0, UiTheme.Radius[radius] or radius or UiTheme.Radius.M)
	return corner
end

-- Dark outline: around the text of a label / button (Contextual) or around a frame's border.
function UiTheme.Stroke(gui, thickness, color, border)
	local stroke = gui:FindFirstChild("ThemeStroke") or child(gui, "UIStroke", "ThemeStroke")
	stroke.Color = color or UiTheme.Outline
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual
	return stroke
end

-- Vertical colour gradient, `top` to `bottom` (text gradients on labels, fills on frames).
function UiTheme.Gradient(gui, top, bottom)
	local gradient = gui:FindFirstChild("ThemeGradient") or child(gui, "UIGradient", "ThemeGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	return gradient
end

-- Rounded navy plate with a coloured glow edge, for read-outs (Money) and cards. Non-interactive.
function UiTheme.Plate(gui, glow)
	gui.BackgroundColor3 = Color3.new(1, 1, 1)
	gui.BackgroundTransparency = 0.12
	gui.BorderSizePixel = 0
	UiTheme.Corner(gui, "M")
	UiTheme.Gradient(gui, UiTheme.Palette.Panel, UiTheme.Palette.PanelDeep)
	local edge = UiTheme.Stroke(gui, 2, glow or UiTheme.Palette.Muted, true)
	edge.Transparency = 0.25
	return gui
end

-- The opaque panel body every panel shares: Panel to PanelDeep, no see-through (panel surfaces cover the read-outs).
function UiTheme.Body(gui)
	gui.BackgroundColor3 = Color3.new(1, 1, 1)
	gui.BackgroundTransparency = 0
	gui.BorderSizePixel = 0
	for _, other in gui:GetChildren() do
		if other:IsA("UIGradient") and other.Name ~= "ThemeGradient" then
			other:Destroy() -- only one gradient draws
		end
	end
	UiTheme.Gradient(gui, UiTheme.Palette.Panel, UiTheme.Palette.PanelDeep)
	return gui
end

-- The nearest token for an authored px radius; scale radii (round pills) are left alone.
local function snapRadius(px)
	if px <= 0 or px >= 24 then
		return px
	end
	local best, bestDiff = px, math.huge
	for _, token in UiTheme.Radius do
		local diff = math.abs(token - px)
		if diff < bestDiff then
			best, bestDiff = token, diff
		end
	end
	return best
end

local function themeOne(object)
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		if not object.FontFace.Family:find("Fredoka") then
			object.Font = UiTheme.Font
		end
	elseif object:IsA("UICorner") then
		local radius = object.CornerRadius
		if radius.Scale == 0 then
			object.CornerRadius = UDim.new(0, snapRadius(radius.Offset))
		end
	end
end

-- Puts a code-built screen on the theme: Fredoka text (every other font, Legacy included) and token corner radii, now and for anything added later.
-- Colours, layout and names are not changed. Returns the DescendantAdded connection.
function UiTheme.Apply(root)
	themeOne(root)
	for _, object in root:GetDescendants() do
		themeOne(object)
	end
	return root.DescendantAdded:Connect(themeOne)
end

return UiTheme
