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

-- Sakura Dojo pages (design doc 4.45, owner 2026-11-17): Summon and Team Setup share these, matching
-- Client/SummonShrineTheme. Proposed values.
UiTheme.Dojo = {
	Wood = Color3.fromRGB(107, 47, 32),
	WoodDark = Color3.fromRGB(64, 40, 30),
	Burgundy = Color3.fromRGB(87, 25, 44),
	Ink = Color3.fromRGB(47, 19, 22),
	Cream = Color3.fromRGB(255, 243, 216),
	Sakura = Color3.fromRGB(244, 145, 171),
	Gold = Color3.fromRGB(237, 183, 93),
	Cyan = Color3.fromRGB(46, 200, 208),
	Stroke = 1.5, -- px: medium-thin outlines
	Petal = "rbxassetid://130260166899982", -- the plaza petal (tools/blender/plaza/plaza_assets.json)
	-- Moved here from the two pages' scripts (audit 2026-11-20), same values.
	Ready = Color3.fromRGB(62, 142, 106), -- Team Setup's "Ready" green on paper
	Warn = Color3.fromRGB(176, 104, 20), -- "Unsaved changes" on paper
	Card = Color3.fromRGB(255, 250, 240), -- a roster paper card
	ArtTop = Color3.fromRGB(249, 230, 234), -- behind a drawn portrait, top
	ArtBottom = Color3.fromRGB(242, 201, 211),
	DeployTop = Color3.fromRGB(226, 82, 92), -- the vermilion Deploy button
	DeployBottom = Color3.fromRGB(157, 31, 43),
	DeployRim = Color3.fromRGB(255, 213, 138),
	SealRim = Color3.fromRGB(120, 22, 20), -- the Summon timer seal's rim
	BrushRed = Color3.fromRGB(168, 38, 42), -- the featured rate's brush pill
	FeaturedPill = Color3.fromRGB(118, 18, 26), -- "Featured!" pill
	FeaturedText = Color3.fromRGB(255, 214, 92),
}

-- Hanging-scroll kit, Sumi ink skin (design doc 4.45 "Hanging-scroll look", owner 2026-11-19), read by Client/DojoScroll.
-- Proposed values. Images: assets/ui/hanging_scroll/asset.json (white art, tinted by ImageColor3).
UiTheme.Scroll = {
	Mount = Color3.fromRGB(207, 201, 189),
	MountDark = Color3.fromRGB(184, 177, 164),
	RuleTop = Color3.fromRGB(165, 157, 144),
	RuleBottom = Color3.fromRGB(109, 103, 93),
	Paper = Color3.fromRGB(251, 249, 243),
	PaperShade = Color3.fromRGB(238, 233, 222),
	Ink = Color3.fromRGB(20, 18, 20),
	Muted = Color3.fromRGB(109, 104, 98),
	Accent = Color3.fromRGB(200, 48, 44), -- vermilion #C8302C
	SealText = Color3.fromRGB(255, 248, 238),
	RodTop = Color3.fromRGB(44, 38, 38),
	RodBottom = Color3.fromRGB(10, 8, 8),
	CapLight = Color3.fromRGB(122, 122, 122),
	CapDark = Color3.fromRGB(20, 20, 20),
	Cord = Color3.fromRGB(58, 52, 52),
	Lacquer = Color3.fromRGB(42, 37, 38),
	LacquerDark = Color3.fromRGB(15, 12, 13),
	Slip = Color3.fromRGB(251, 249, 243),
	-- Gem-pack tags: burgundy with pink rims (the owner's one change to R3).
	TagTop = Color3.fromRGB(90, 30, 42), -- #5A1E2A
	TagBottom = Color3.fromRGB(64, 20, 32), -- #401420
	TagRim = Color3.fromRGB(244, 145, 171),
	TagCord = Color3.fromRGB(192, 48, 58), -- #C0303A
	TagText = Color3.fromRGB(255, 243, 216),
	TagPrice = Color3.fromRGB(246, 196, 150), -- pink-gold
	-- Summon 1:1 reference (4.45, owner 2026-11-19): gold pack price, cream pills, cream wood summon tiles, paper buttons.
	TagGold = Color3.fromRGB(255, 204, 72),
	Cream = Color3.fromRGB(250, 236, 204),
	TileTop = Color3.fromRGB(241, 221, 180), -- #F1DDB4
	TileBottom = Color3.fromRGB(226, 196, 143), -- #E2C48F
	TileRim = Color3.fromRGB(90, 58, 34), -- #5A3A22
	TileEdge = Color3.fromRGB(44, 26, 14),
	TileInk = Color3.fromRGB(46, 30, 22),
	PaperRim = Color3.fromRGB(58, 42, 32), -- #3A2A20, an ink brush line
	-- Summon's scroll skin (DojoScroll.new Skin = "Parchment"): warm parchment, brown wood and leather. Team keeps Sumi ink.
	Skins = {
		Parchment = {
			Paper = Color3.fromRGB(239, 227, 200), -- #EFE3C8
			PaperShade = Color3.fromRGB(230, 214, 182), -- #E6D6B6
			Mount = Color3.fromRGB(230, 214, 182), -- the mount is parchment too: the reference shows one sheet edge to edge
			MountDark = Color3.fromRGB(218, 199, 162),
			RuleTop = Color3.fromRGB(92, 58, 36),
			RuleBottom = Color3.fromRGB(62, 38, 24),
			RodTop = Color3.fromRGB(128, 84, 48),
			RodBottom = Color3.fromRGB(82, 50, 26),
			CapLight = Color3.fromRGB(92, 58, 32),
			CapDark = Color3.fromRGB(48, 28, 14),
			Cord = Color3.fromRGB(96, 62, 36),
		},
	},
	Body = Font.fromEnum(Enum.Font.TitilliumWeb),
	BodyBold = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.Bold),
	Heading = Font.fromEnum(Enum.Font.PermanentMarker),
	Script = Font.new("rbxasset://fonts/families/Kalam.json", Enum.FontWeight.Bold), -- Summon's buttons and pack titles
	Wordmarks = "rbxassetid://98796658340171", -- Kaushan Script "Summon" over "Team", 1024x512
	WordmarkRects = { Summon = { 150, 30, 750, 200 }, Team = { 330, 286, 410, 200 } },
	Enso = "rbxassetid://123264633411621",
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
	if object:GetAttribute("AnimeRole") then
		return -- Client/AnimeSkin owns this text's font (design doc 4.42): never put it back on Fredoka
	end
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
