--!nonstrict
-- The roll animation (docs/ROLL_ANIMATION_SPEC.md, design doc 4.31). Every auto-roll result (Remotes.RollResult,
-- decided by the server's GachaService) plays as: pop in -> spin (characters swap in one fixed spot, slowing down;
-- fillers are real rolls, never fake near-misses) -> land (the result pops, then its odds and name appear) -> hold
-- (longer for rarer characters, with rarity effects) -> exit (the figure shrinks and a small icon of it flies to the
-- INDEX button). All phases scale to the player's roll interval (RollAnimConfig.TimeScale).
--   Compact view (default): RollToast/Toast at top centre under the hidden RacerHud/Race anchor: NO card, only the bare
--   figure, its "1 in N" and its name. Shown only while a roll plays (or while auto-roll is off), hidden while the
--   enlarged view or any panel is open.
--   Enlarged view: no visible card either: a big figure on a rarity crystal, gradient odds above it, the outlined name
--   below it, smaller rarity and cruise text, NEW / +1 COPY / TURBO badges, in the RollShowcase overlay (dimmed +
--   blurred), with the AUTO toggle and "Tap anywhere to close". Clicking the compact roll opens it. An emphasized roll
--   (server flag) opens it by itself and drops back to compact after the roll.
-- Both bodies always hold the same roll, but only the visible one draws a figure: the character's drawn portrait
-- (Portrait, inside Viewport), or with none loaded its live model (one reusable rig per character).
-- Tests read the Phase / RollId / RollSerial attributes on each card, ShownId on each body, the View attribute on the
-- RollToast ScreenGui and ReelIds on each Reel.

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared.CharacterCatalog)
local GachaConfig = require(Shared.GachaConfig)
local HudFormat = require(Shared.HudFormat)
local RaceConfig = require(Shared.RaceConfig)
local RollAnimConfig = require(Shared.RollAnimConfig)
local RunnerFactory = require(Shared.RunnerFactory)
local UiTheme = require(Shared.UiTheme)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local rollRemote = remotes:WaitForChild("RollResult")
local autoRollRemote = remotes:WaitForChild("SetAutoRoll")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))

local A = RollAnimConfig
local COMPACT_TEXT_BAND = 20 -- px each for the odds and the name under the compact figure
local SWAP_POP = 0.85 -- a cycle swap grows from this scale to 1x
local SWAP_POP_TIME = 0.16 -- s, at most
local LAND_RISE = 0.35 -- share of LAND spent growing to LAND_POP; the rest settles while the text appears
local MODEL_WAIT = 5 -- s the first roll waits for models to load; a failed load must not hold rolls back for good
local VIEW_FOV = 30
local VIEW_DIR = Vector3.new(-0.35, 0.08, -1).Unit -- from the figure to the camera, the Index card's angle (rigs face -Z)
local VIEW_MARGIN = 1.06
local BUST_TORSO_HALF = 1.2 -- studs a Torso mesh counts below its centre; a longer one is a cape or coat
local BUST_FADE = 0.15 -- share of the view the bottom fade takes
local BUST_ARM_HALF = 0.8 -- studs an arm mesh counts each side of its centre; a wider one holds a weapon
local VIEW_FADE_START = 0.82 -- of the view's height: the figure fades out from here to the bottom edge
local VIEW_AMBIENT = Color3.fromRGB(175, 175, 185)
local VIEW_LIGHT_DIR = Vector3.new(-1, -2, -1)
-- Enlarged layout, px at the generated card's size: a text band, the square figure, a text band, centred on the card.
-- The desktop figure spills past the card's 320 px; it still clears the AUTO button down to height 501.
local ENLARGED_DESKTOP = { Width = 760, Height = 320, Figure = 280, Band = 56 }
local ENLARGED_PHONE = { Width = 540, Height = 224, Figure = 150, Band = 36 }
local CRYSTAL_SHARE = 0.72 -- the crystal's square side, of the figure's; rotated 45 degrees its corners reach about 1x
-- Smaller diamonds around the crystal: x and y offset from the figure's centre and side, in figure heights
local SHARDS = { { -0.42, 0.1, 0.3 }, { 0.42, 0.1, 0.3 }, { -0.3, -0.36, 0.2 }, { 0.3, -0.36, 0.2 } }
local SHOWCASE_ORDER = 14 -- above the HUD and DuelUi (12), below the loser screen (20)
local BLUR_SIZE = 14
local TAKEOVER_TITLE = 1 -- s the Secret title covers the screen (placeholder)
local TICK_PITCH_RISE = 0.5 -- the last RollTick plays this much above pitch 1 (placeholder)
-- Rarity to landing cue (SFX audit in docs/UI_AUDIT.md). Secret is RollSecret, played on its title.
local LAND_CUES = {
	Common = "RollLand1",
	Uncommon = "RollLand1",
	Rare = "RollLand2",
	Epic = "RollLand3",
	Legendary = "RollLand4",
	Mythic = "RollLand5",
	Secret = "RollSecret",
}
local AUTO_BUTTON_SIZE = Vector2.new(180, 44)
local AUTO_BUTTON_BOTTOM = 38 -- keeps the toggle below the card on small phones
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CARD_BG = Color3.fromRGB(20, 28, 48)
local GOLD = Color3.fromRGB(255, 200, 60)
local TURBO_BLUE = Color3.fromRGB(60, 170, 255)
local UNKNOWN_CRYSTAL = Color3.fromRGB(60, 70, 95)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 255, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 140, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 60, 255)),
})
-- FredokaOne everywhere (docs/HUD_LAYOUT_SPEC.md section 8)
local ITALIC = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BOLD = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Heavy)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Ui = script:WaitForChild("Ui")
local Components = require(Ui.RacerComponents)
task.spawn(function()
	require(script:WaitForChild("RacerUiController"))
end)
local rollRefs = require(Ui.RollShowcase).Bind(playerGui)
rollRefs.Gui.Enabled = false

local rng = Random.new()

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function round(inst, radius)
	return make("UICorner", { CornerRadius = radius }, inst)
end

local function rarityColor(spec)
	return GachaConfig.RARITY_COLORS[spec.Rarity] or WHITE
end

-- Readable text colour for a rarity (Secret is near-black: white text, the colour goes to the outline)
local function textColor(spec)
	return spec.Rarity == "Secret" and WHITE or rarityColor(spec)
end

local function rarityRank(spec)
	return table.find(GachaConfig.RARITY_ORDER, spec.Rarity) or 1
end

-- Card body ------------------------------------------------------------------------------------------------------
-- Everything inside a body is laid out in fractions of the body, so PopIn, LAND_POP and Exit scale all of it.

local function label(name, pos, size, parent, font)
	return make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		FontFace = font or BOLD,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "",
		ZIndex = 6,
	}, parent)
end

local function screenHeight()
	local camera = workspace.CurrentCamera
	local height = camera and camera.ViewportSize.Y or 0
	-- Studio can briefly report a placeholder 1x1 camera while PlayerGui is already laid out
	if height <= 1 and rollRefs.Gui.AbsoluteSize.Y > 1 then
		height = rollRefs.Gui.AbsoluteSize.Y
	end
	return height
end

-- Same lighting and camera in every view, so the figure never changes colour between the cycle and the landing.
local function figureView(name, z, parent)
	local view = make("ViewportFrame", {
		Name = name,
		BackgroundTransparency = 1,
		Ambient = VIEW_AMBIENT,
		LightColor = WHITE,
		LightDirection = VIEW_LIGHT_DIR,
		AnchorPoint = Vector2.new(0, 0),
		ZIndex = z,
	}, parent)
	view.CurrentCamera = make("Camera", { Name = "Camera", FieldOfView = VIEW_FOV }, view)
	make("UIGradient", {
		Name = "BottomFade",
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(VIEW_FADE_START, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, view)
	return view
end

local function figureScale(view)
	return make("UIScale", { Name = "MotionScale" }, view)
end

-- Inside the view: same rect and same MotionScale pops, and the view's BottomFade does not reach children.
local function portraitLabel(view, name, z)
	return make("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		ImageColor3 = WHITE,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = z,
	}, view)
end

-- Portrait, and under it the previous image held until the new one has drawn, so a swap never shows a blank frame.
local function portraitParts(b, z)
	b.Portrait = portraitLabel(b.Viewport, "Portrait", z + 5)
	b.PortraitHold = portraitLabel(b.Viewport, "PortraitHold", z + 4)
	b.Portrait:GetPropertyChangedSignal("IsLoaded"):Connect(function()
		b.PortraitHold.Visible = b.Portrait.Visible and not b.Portrait.IsLoaded
	end)
	return b
end

local function placeholderLabel(view, z)
	local placeholder = label("Placeholder", UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.4, 0.4), view, ITALIC)
	placeholder.Text = "?"
	placeholder.ZIndex = z
	placeholder.TextStrokeTransparency = 0.3
	return placeholder
end

-- Every landing's ring, expanding from the figure's centre in the rarity's colour.
local function landWave(parent, z)
	local wave = make("Frame", {
		Name = "LandWave",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	round(wave, UDim.new(0.5, 0))
	make("UIAspectRatioConstraint", { DominantAxis = Enum.DominantAxis.Height }, wave)
	return wave, make("UIStroke", { Thickness = 3, Color = WHITE, Transparency = 1 }, wave)
end

local function diamond(name, z, parent)
	return make("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BorderSizePixel = 0,
		BackgroundColor3 = WHITE,
		ZIndex = z,
	}, parent)
end

local function buildBody(z)
	local body = rollRefs.CardBody
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.BackgroundTransparency = 1
	body:FindFirstChildOfClass("UIStroke").Enabled = false
	body.Lift.Visible = false
	body.Parent.Shadow.Visible = false

	-- The rarity crystal behind the figure: our own rotated frames and gradients (spec "Views"). The core keeps the
	-- name Glow, its gradient slowly turning.
	local glow = diamond("Glow", z + 1, body)
	local glowGradient = make("UIGradient", { Name = "Spin" }, glow)
	local shards = {}
	for i in SHARDS do
		local shard = diamond("Shard" .. i, z + 1, body)
		shard.BackgroundTransparency = 0.15
		make("UIGradient", { Rotation = 45 }, shard)
		shards[i] = shard
	end
	local facet = diamond("Facet", z + 2, body)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.65),
			NumberSequenceKeypoint.new(0.5, 0.65),
			NumberSequenceKeypoint.new(0.5001, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, facet)

	local ring = diamond("Ring", z + 2, body)
	ring.BackgroundTransparency = 1
	ring.Visible = false
	local ringStroke = make("UIStroke", { Thickness = 4, Color = WHITE }, ring)

	local burst = make("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.9),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = z,
	}, body)
	round(burst, UDim.new(0.5, 0))
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, burst)

	-- Nothing slides any more; tests read ReelIds from this frame
	local reel = make("Frame", {
		Name = "Reel",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = z + 3,
	}, body)
	local wave, waveStroke = landWave(body, z + 3)
	wave.Position = UDim2.fromScale(0.5, 0.5)

	local viewport = figureView("Viewport", z + 4, body)
	local placeholder = placeholderLabel(viewport, z + 6)

	-- Mythic: a band of light across the figure
	local flare = make("Frame", {
		Name = "Flare",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.1, 0.5),
		Size = UDim2.fromScale(0.3, 0.18),
		Rotation = 20,
		BackgroundColor3 = Color3.fromRGB(255, 250, 220),
		BackgroundTransparency = 0.2,
		Visible = false,
		ZIndex = z + 7,
	}, body)
	round(flare, UDim.new(0.5, 0))

	-- Text
	local odds = rollRefs.ResultOdds
	local characterName = rollRefs.ResultName
	local speedMulti = rollRefs.ResultSpeed
	local rarity = rollRefs.ResultRarity
	for _, text in ipairs({ odds, characterName, speedMulti, rarity }) do
		text.TextScaled = true
		text.ZIndex = z + 6
	end
	odds.FontFace = ITALIC
	odds.TextColor3 = WHITE -- the gradient below colours it
	local oddsGradient = make("UIGradient", { Name = "OddsGradient", Rotation = 90 }, odds)
	characterName.FontFace = BOLD
	local nameStroke = characterName:FindFirstChildOfClass("UIStroke")
	if not nameStroke then
		nameStroke = make("UIStroke", {}, characterName)
	end
	nameStroke.Color = BLACK
	nameStroke.Thickness = 3
	nameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local function aliasText(name, primary)
		local alias = make("TextLabel", {
			Name = name,
			AnchorPoint = primary.AnchorPoint,
			BackgroundTransparency = 1,
			FontFace = primary.FontFace,
			Text = primary.Text,
			TextColor3 = primary.TextColor3,
			TextScaled = primary.TextScaled,
			TextTransparency = 1,
			Visible = primary.Visible,
			ZIndex = primary.ZIndex,
		}, body)
		return alias
	end
	local aliasName = aliasText("CharacterName", characterName)
	local aliasSpeed = aliasText("SpeedMulti", speedMulti)
	local aliasRarity = aliasText("Rarity", rarity)
	local aliasOdds = aliasText("Odds", odds)
	make("UIStroke", { Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, aliasName)

	local function badge(name, text, color, y)
		local b = label(name, UDim2.fromScale(0.77, y), UDim2.fromScale(0.2, 0.12), body)
		b.BackgroundTransparency = 0
		b.BackgroundColor3 = color
		b.Text = text
		b.Visible = false
		round(b, UDim.new(0, 4))
		return b
	end
	local newBadge = badge("NewBadge", "NEW!", Color3.fromRGB(60, 255, 60), 0.3)
	local scrapBadge = badge("ScrapBadge", "SCRAP", Color3.fromRGB(255, 190, 60), 0.3)
	local turboBadge = badge("TurboBadge", "TURBO", TURBO_BLUE, 0.46)

	local flames = diamond("TurboFlames", z + 2, body)
	flames.BackgroundTransparency = 1
	flames.Visible = false
	local flameStroke = make("UIStroke", { Thickness = 5, Color = WHITE }, flames)
	local flameGradient = make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 90, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 230, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 90, 255)),
		}),
	}, flameStroke)

	return portraitParts({
		Body = body,
		Glow = glow,
		GlowGradient = glowGradient,
		Shards = shards,
		Facet = facet,
		Ring = ring,
		RingStroke = ringStroke,
		Burst = burst,
		Reel = reel,
		Wave = wave,
		WaveStroke = waveStroke,
		Viewport = viewport,
		FigureScale = figureScale(viewport),
		Placeholder = placeholder,
		Flare = flare,
		Odds = odds,
		OddsGradient = oddsGradient,
		CharacterName = characterName,
		SpeedMulti = speedMulti,
		Rarity = rarity,
		NewBadge = newBadge,
		ScrapBadge = scrapBadge,
		TurboBadge = turboBadge,
		Flames = flames,
		FlameGradient = flameGradient,
		Aliases = { Name = aliasName, Speed = aliasSpeed, Rarity = aliasRarity, Odds = aliasOdds },
		Full = true,
	}, z)
end

-- The compact roll: no card, only the bare figure with its "1 in N" and name under it. fitCompact sizes these.
local function buildBare(parent, z)
	local body = make("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	local reel = make("Frame", {
		Name = "Reel",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = z + 3,
	}, body)
	local wave, waveStroke = landWave(body, z + 3)
	local viewport = figureView("Viewport", z + 4, body)
	local placeholder = placeholderLabel(viewport, z + 6)
	local odds = label("Odds", UDim2.new(), UDim2.new(), body)
	odds.FontFace = ITALIC
	odds.TextStrokeTransparency = 1
	make("UIStroke", { Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, odds)
	local characterName = label("CharacterName", UDim2.new(), UDim2.new(), body)
	characterName.TextStrokeTransparency = 1
	make("UIStroke", { Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, characterName)
	local autoOff = label("AutoOff", UDim2.new(), UDim2.new(1, 0, 0, 20), body)
	autoOff.Text = "AUTO OFF"
	autoOff.Font = Enum.Font.FredokaOne
	autoOff.TextScaled = false
	autoOff.TextSize = 16
	autoOff.TextStrokeTransparency = 1
	make("UIStroke", { Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, autoOff)
	autoOff.Visible = false
	return portraitParts({
		Body = body,
		Reel = reel,
		Wave = wave,
		WaveStroke = waveStroke,
		Viewport = viewport,
		FigureScale = figureScale(viewport),
		Placeholder = placeholder,
		Odds = odds,
		CharacterName = characterName,
		AutoOff = autoOff,
		Full = false,
	}, z)
end

-- Compact card --------------------------------------------------------------------------------------------------

local gui = make("ScreenGui", {
	Name = "RollToast",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
}, playerGui)
-- The compact toast must receive clicks above the base HUD, while the enlarged showcase
-- keeps its separate higher DisplayOrder below LoserScreen.
gui.DisplayOrder = 3
gui:SetAttribute("View", "Compact")

local toast = make("TextButton", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
}, gui)
local toastSize = make("UISizeConstraint", {}, toast)
local compact = buildBare(toast, 2)

local flyIcon = make("Frame", {
	Name = "FlyIcon",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(44, 44),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 20,
}, gui)
local flyView = figureView("Icon", 21, flyIcon)
flyView.Size = UDim2.fromScale(1, 1)
local flyPortrait = portraitLabel(flyView, "Portrait", 22)

-- Enlarged view -------------------------------------------------------------------------------------------------

local showcase = rollRefs.Gui
showcase.DisplayOrder = SHOWCASE_ORDER
showcase.Enabled = false

-- Anywhere off the card: close
local backdrop = make("TextButton", {
	Name = "Backdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 10, 20),
	BackgroundTransparency = 0.35,
	AutoButtonColor = false,
	Text = "",
}, showcase)
make("TextLabel", {
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(320, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(200, 210, 230),
	Text = "Tap anywhere to close",
}, backdrop)

-- The card (Active: clicks on it do not close). About 3x the compact card, above the AUTO button on a phone too.
local card = rollRefs.Card
card.Active = true
card.ZIndex = 2
local CARD_POS = UDim2.fromScale(0.5, 0.46)
local function isPhone()
	return screenHeight() <= 500
end
local function cardTargetSize()
	return isPhone() and UDim2.fromOffset(540, 224) or UDim2.fromOffset(760, 320)
end
local enlarged = buildBody(3)

local autoButton = make("TextButton", {
	Name = "AutoButton",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -AUTO_BUTTON_BOTTOM),
	Size = UDim2.fromOffset(AUTO_BUTTON_SIZE.X, AUTO_BUTTON_SIZE.Y),
	FontFace = BOLD,
	TextSize = 22,
	TextColor3 = WHITE,
	AutoButtonColor = true,
	ZIndex = 4,
}, showcase)
round(autoButton, UDim.new(0, 12))
make("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = CARD_BG }, autoButton)

-- Beside AUTO: every outcome's odds (design doc 6). Auto sell is in Settings only (owner 2026-11-09).
local function viewButton(name, text, xOffset)
	local b = make("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, xOffset, 1, -AUTO_BUTTON_BOTTOM),
		Size = UDim2.fromOffset(130, AUTO_BUTTON_SIZE.Y),
		BackgroundColor3 = Color3.fromRGB(104, 111, 135),
		FontFace = BOLD,
		Text = text,
		TextSize = 18,
		TextColor3 = WHITE,
		AutoButtonColor = true,
		ZIndex = 4,
	}, showcase)
	round(b, UDim.new(0, 12))
	make("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Color = CARD_BG }, b)
	return b
end
local detailsButton = viewButton("DetailsButton", "Details", (AUTO_BUTTON_SIZE.X + 130) / 2 + 8)

-- Inset by the border's width: a UIStroke draws outside its frame, so a full-screen frame would draw it off screen.
local takeover = make("Frame", {
	Name = "Takeover",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -20, 1, -20),
	BackgroundColor3 = Color3.fromRGB(5, 5, 8),
	BackgroundTransparency = 0.15,
	Visible = false,
	ZIndex = 10,
}, showcase)
local takeoverStroke = make("UIStroke", { Thickness = 10, Color = WHITE }, takeover)
local rainbow = make("UIGradient", { Color = RAINBOW }, takeoverStroke)
local takeoverText = make("TextLabel", {
	Name = "Title",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.13), -- above the figure
	Size = UDim2.fromScale(0.8, 0.2),
	BackgroundTransparency = 1,
	Font = UiTheme.Font,
	TextScaled = true,
	TextColor3 = WHITE,
	ZIndex = 11,
}, takeover)
local takeoverSkip = make("TextLabel", {
	Name = "Skip",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.24),
	Size = UDim2.fromOffset(320, 24),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.fromRGB(200, 210, 230),
	Text = "Tap to skip",
	ZIndex = 11,
}, takeover)

local blur = Lighting:FindFirstChild("RollShowcaseBlur")
if not blur then
	blur = make("BlurEffect", { Name = "RollShowcaseBlur", Size = BLUR_SIZE }, Lighting)
end
blur.Enabled = false

local bodies = { compact, enlarged }
local cards = { toast, card }

-- State ---------------------------------------------------------------------------------------------------------

local latest = nil -- { Spec, IsNew, Turbo, Emphasized, ScrapMoney } of the roll playing or last played
local serial = 0 -- RollResults received
local phase = "Idle"
local tweens = {} -- running tweens of the current roll (cancelled when a new roll starts)
local autoOpened = false -- the enlarged view was opened by an emphasized roll, not by the player
local switchStamp = 0
local shownId = nil -- the character on screen, in whichever body is visible
local drawnRig = nil
local rigs = {} -- character id -> its one rig, reused between rolls
local modelsReady = false
local portraitsReady = false

local function setAttr(name, value)
	for _, c in cards do
		c:SetAttribute(name, value)
	end
end
setAttr("Phase", "Idle")
setAttr("RollSerial", 0)

local function tween(inst, seconds, props, style, direction)
	local t = UiMotion.Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	table.insert(tweens, t)
	t:Play()
	return t
end

local function cancelTweens()
	for _, t in tweens do
		t:Cancel()
	end
	table.clear(tweens)
end

local function autoRollOn()
	return player:GetAttribute("AutoRoll") ~= false
end

local function isEnlarged()
	return gui:GetAttribute("View") == "Enlarged"
end

-- Figures ---------------------------------------------------------------------------------------------------------

-- The portrait to draw for a character: only a loaded one, so nothing blank reaches a frame. nil falls back to its rig.
local function portraitFor(id)
	local spec = CharacterCatalog.Get(id)
	local image = spec and Components.PortraitImage(spec)
	if image and ContentProvider:GetAssetFetchStatus(image) == Enum.AssetFetchStatus.Success then
		return image
	end
	return nil
end

local function rigFor(id)
	local rig = rigs[id]
	if not rig and RunnerFactory.HasModel(id) then
		rig = RunnerFactory.build(id)
		rig.NameLabel:Destroy() -- the view shows the name itself
		rigs[id] = rig
	end
	return rig
end

-- Bust framing (spec "Accuracy"), the same for cycle, landing and fly icon: from the Head mesh's top, which holds the
-- hair, to the Torso's bottom, wide enough for hair and shoulders. Only these parts count, and the caps ignore a cape
-- on the Torso or a weapon on an arm, so they cannot shrink the face. The top stays at the view's top edge when width
-- is the limit; the body below is cut off by the view and its fade.
local function frameRig(view, rig, aspect)
	local head, torso = rig.Head, rig.Torso
	local top = head.Position.Y + head.Size.Y / 2
	local bottom = torso.Position.Y - math.min(torso.Size.Y / 2, BUST_TORSO_HALF)
	local halfWidth = math.max(head.Size.X, torso.Size.X) / 2
	for _, arm in { rig.LeftArm, rig.RightArm } do
		local shoulder = math.abs(arm.Position.X - torso.Position.X) + math.min(arm.Size.X / 2, BUST_ARM_HALF)
		halfWidth = math.max(halfWidth, shoulder)
	end
	local half = Vector3.new(halfWidth, (top - bottom) / 2, math.max(head.Size.Z, torso.Size.Z) / 2)
	local centre = Vector3.new(torso.Position.X, (top + bottom) / 2, torso.Position.Z)
	local look = CFrame.lookAt(centre + VIEW_DIR, centre)
	local tanV = math.tan(math.rad(VIEW_FOV / 2))
	local forWidth, forHeight = 0, 0
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = Vector3.new(sx, sy, sz) * half
				local toward = corner:Dot(VIEW_DIR)
				forWidth = math.max(forWidth, toward + math.abs(corner:Dot(look.RightVector)) / (tanV * aspect))
				forHeight = math.max(forHeight, toward + math.abs(corner:Dot(look.UpVector)) / tanV)
			end
		end
	end
	local distance = math.max(forWidth, forHeight) * VIEW_MARGIN
	local focus = centre - look.UpVector * (distance - forHeight * VIEW_MARGIN) * tanV
	view.CurrentCamera.CFrame = CFrame.lookAt(focus + VIEW_DIR * distance, focus)
	-- A slim figure leaves room under its torso when its width sets the distance: the fade ends at the torso's bottom,
	-- so the rest of the body never shows.
	local cut = view.CurrentCamera.CFrame:PointToObjectSpace(Vector3.new(centre.X, bottom, centre.Z))
	local fadeEnd = math.clamp((1 - cut.Y / (-cut.Z * tanV)) / 2, BUST_FADE + 0.01, 0.99)
	view.BottomFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(fadeEnd - BUST_FADE, 0),
		NumberSequenceKeypoint.new(fadeEnd, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- Only one body draws at a time, and neither while a panel hides the compact roll.
local function visibleBody()
	if isEnlarged() then
		return enlarged
	end
	return toast.Visible and compact or nil
end

local function bodyAspect(b)
	if b.Full then
		return 1 -- the enlarged figure's rect is square
	end
	return math.max(toast.AbsoluteSize.X, 1) / math.max(toast.AbsoluteSize.Y - 2 * COMPACT_TEXT_BAND, 1)
end

local function showPortrait(b, image)
	local front, hold = b.Portrait, b.PortraitHold
	if image and front.Image ~= image then
		hold.Image = front.Image
		front.Image = image
	end
	front.Visible = image ~= nil
	hold.Visible = image ~= nil and not front.IsLoaded
end

local function drawShown()
	local b = visibleBody()
	local image = b and shownId and portraitFor(shownId) or nil
	local rig = b and shownId and not image and rigFor(shownId) or nil
	if drawnRig and drawnRig ~= rig then
		drawnRig.Parent = nil
	end
	drawnRig = rig
	if rig then
		frameRig(b.Viewport, rig, bodyAspect(b))
		rig.Parent = b.Viewport
	end
	local noModel = shownId == nil or not (portraitFor(shownId) or RunnerFactory.HasModel(shownId))
	for _, each in bodies do
		showPortrait(each, each == b and image or nil)
		each.Placeholder.Visible = noModel
	end
end

local function setShown(id)
	shownId = id
	for _, b in bodies do
		b.Body:SetAttribute("ShownId", id)
	end
	drawShown()
end

-- Portraits load before the first roll, as the rigs below do. Starters wear rollable models, so this covers their images.
task.spawn(function()
	local images = {}
	for _, spec in CharacterCatalog.All() do
		local image = Components.PortraitImage(spec)
		if image then
			table.insert(images, make("ImageLabel", { Image = image }))
		end
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, images)
	portraitsReady = true
end)

-- Loads every character's meshes, then builds a rig per frame, so neither an empty figure nor a hitch reaches a roll.
-- A character with a portrait gets no rig unless its image fails to load (play builds one then).
task.spawn(function()
	local root = ReplicatedStorage:WaitForChild("CharacterModels")
	while not root:GetAttribute("Ready") do
		root:GetAttributeChangedSignal("Ready"):Wait()
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, { root })
	modelsReady = true
	for _, spec in CharacterCatalog.Rollable() do
		if not Components.PortraitImage(spec) then
			rigFor(spec.Id)
			task.wait()
		end
	end
end)

-- Views state -------------------------------------------------------------------------------------------------------

-- The compact roll is the top-centre entry point. Clicking it opens the enlarged showcase, where the AUTO option
-- lives. Owner 2026-10-28 (docs/HUD_LAYOUT_SPEC.md section 6, docs/ROLL_ANIMATION_SPEC.md): it HIDES while any
-- PanelSwitch panel is open, so it never covers a panel's top or takes its clicks; the roll keeps playing.
local function refreshToast()
	local playing = phase ~= "Idle"
	local show = not isEnlarged()
		and not PanelSwitch.AnyOpen()
		and (playing or not autoRollOn())
		and player:GetAttribute("BossEvent") ~= true
	local hud = playerGui:FindFirstChild("RacerHud")
	if hud and not isEnlarged() then
		hud.Enabled = true
		if not playing then
			showcase.Enabled = false
		end
	end
	toast.Visible = show
	-- While AutoRoll is off the idle compact roll stays shown with the caption AUTO OFF
	compact.AutoOff.Visible = show and not playing and not autoRollOn()
	if show and not playing then
		compact.Body.Size = UDim2.fromScale(1, 1)
		if not latest then
			compact.Odds.Text = "?"
		end
	end
	drawShown()
end

local function setPhase(name)
	phase = name
	setAttr("Phase", name)
	refreshToast()
end

-- Card contents -------------------------------------------------------------------------------------------------

local function setText(b, name, odds)
	b.CharacterName.Text = name
	b.Odds.Text = odds
	if b.Full then
		b.Aliases.Name.Text = name
		b.Aliases.Odds.Text = odds
	end
end

local function tintCrystal(b, color)
	b.Glow.BackgroundColor3 = color
	b.GlowGradient.Color = ColorSequence.new(WHITE:Lerp(color, 0.6), color:Lerp(BLACK, 0.45))
	for _, shard in b.Shards do
		shard.BackgroundColor3 = color
		shard:FindFirstChildOfClass("UIGradient").Color =
			ColorSequence.new(WHITE:Lerp(color, 0.75), color:Lerp(BLACK, 0.3))
	end
end

-- The body before the spin: no text (the odds and name appear on Land), neutral crystal, turbo flames + badge on a
-- turbo roll
local function resetBody(b, roll)
	setText(b, "???", "?")
	b.Odds.TextColor3 = WHITE
	if b.OddsGradient then
		b.OddsGradient.Color = ColorSequence.new(WHITE) -- never a hint from the last roll's rarity
		b.OddsGradient.Offset = Vector2.new()
		b.OddsMoving = false
	end
	b.WaveStroke.Transparency = 1
	b.FigureScale.Scale = 1
	if b.Full then
		tintCrystal(b, UNKNOWN_CRYSTAL)
		b.Ring.Visible = false
		b.Burst.Visible = false
		b.Flare.Visible = false
		b.SpeedMulti.Text = ""
		b.Rarity.Text = ""
		b.Aliases.Speed.Text = ""
		b.Aliases.Rarity.Text = ""
		b.NewBadge.Visible = false
		b.ScrapBadge.Visible = false
		local turbo = roll.Turbo > 1
		b.TurboBadge.Visible = turbo
		b.TurboBadge.Text = "TURBO x" .. tostring(roll.Turbo)
		b.Flames.Visible = turbo
	else
		b.AutoOff.Visible = false
	end
	b.Body.Position = UDim2.fromScale(0.5, 0.5)
end

-- The odds gradient follows the rarity; Mythic and Secret get the slowly moving multi-colour one.
local function paintOdds(b, spec)
	local moving = spec.Rarity == "Mythic" or spec.Rarity == "Secret"
	local color = rarityColor(spec)
	b.OddsGradient.Color = moving and RAINBOW or ColorSequence.new(WHITE:Lerp(color, 0.55), color)
	b.OddsGradient.Offset = Vector2.new()
	b.OddsMoving = moving
end

-- The result's text, appearing over `seconds`.
local function revealText(b, roll, seconds)
	local spec = roll.Spec
	-- Every landed roll shows the catalog's odds, never the temporary luck the server rolled with, so a boost cannot
	-- turn a 1 in 100,000 into a misleading 1 in 1. roll.Luck stays in the payload for compatibility.
	setText(b, spec.Name, HudFormat.Odds(spec.Chance))
	local shown = { b.Odds, b.CharacterName }
	if b.Full then
		paintOdds(b, spec)
		b.SpeedMulti.Text = HudFormat.RateText(RaceConfig.Cruise(spec))
		b.Rarity.Text = spec.Rarity
		b.Rarity.TextColor3 = textColor(spec)
		b.Rarity.TextStrokeColor3 = spec.Rarity == "Secret" and rarityColor(spec) or BLACK
		b.Rarity.TextStrokeTransparency = spec.Rarity == "Secret" and 0 or 0.4
		b.NewBadge.Visible = roll.IsNew
		-- A duplicate is kept as a copy. An auto sold roll shows no badge: only Money moves (owner 2026-11-09).
		b.ScrapBadge.Visible = not roll.IsNew and roll.ScrapMoney <= 0
		b.ScrapBadge.Text = "+1 COPY"
		b.Aliases.Speed.Text = "Cruise " .. HudFormat.RateText(RaceConfig.Cruise(spec))
		b.Aliases.Rarity.Text = spec.Rarity
		b.Aliases.Name.TextColor3 = b.CharacterName.TextColor3
		b.Aliases.Speed.TextColor3 = b.SpeedMulti.TextColor3
		b.Aliases.Rarity.TextColor3 = b.Rarity.TextColor3
		b.Aliases.Odds.TextColor3 = textColor(spec)
		table.insert(shown, b.SpeedMulti)
		table.insert(shown, b.Rarity)
	else
		b.Odds.TextColor3 = textColor(spec)
	end
	for _, text in shown do
		text.TextTransparency = 1
		tween(text, seconds, { TextTransparency = 0 })
	end
end

-- Views ---------------------------------------------------------------------------------------------------------

local function openEnlarged(auto)
	if isEnlarged() then
		-- The player asked for the view while an emphasized roll was auto-opening it: keep it open after that roll
		if auto ~= true then
			autoOpened = false
		end
		return
	end
	autoOpened = auto == true
	PanelSwitch.Close("Index")
	PanelSwitch.Close("Stats")
	PanelSwitch.Close("Settings")
	PanelSwitch.Close("Rebirth")
	gui:SetAttribute("View", "Enlarged")
	backdrop.Visible = true
	autoButton.Visible = true
	showcase.Enabled = true
	blur.Enabled = true
	local hud = playerGui:FindFirstChild("RacerHud")
	if hud then
		hud.Enabled = false
	end
	refreshToast()
	-- Grow from where the compact card is to the centre, with a slight overshoot
	local stamp = os.clock()
	switchStamp = stamp
	local inset = GuiService:GetGuiInset()
	local targetSize = cardTargetSize()
	local from = toast.AbsolutePosition + inset + toast.AbsoluteSize / 2
	card.Position = UDim2.fromOffset(from.X, from.Y)
	card.Size = UDim2.fromOffset(toast.AbsoluteSize.X, toast.AbsoluteSize.Y)
	local info = TweenInfo.new(A.SWITCH, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	UiMotion.Create(card, info, { Position = CARD_POS, Size = targetSize }):Play()
	task.delay(A.SWITCH + 0.05, function()
		if switchStamp == stamp and isEnlarged() then
			card.Position = CARD_POS
			card.Size = targetSize
		end
	end)
end

local function closeEnlarged()
	if not isEnlarged() then
		return
	end
	autoOpened = false
	takeover.Visible = false
	local stamp = os.clock()
	switchStamp = stamp
	gui:SetAttribute("View", "Compact")
	blur.Enabled = false
	local hud = playerGui:FindFirstChild("RacerHud")
	if hud then
		hud.Enabled = true
	end
	-- The reverse: shrink back towards the compact card's place, then hide
	local to = Vector2.new(card.AbsolutePosition.X + card.AbsoluteSize.X / 2, A.COMPACT_TOP + toast.AbsoluteSize.Y / 2)
	local info = TweenInfo.new(A.SWITCH, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	UiMotion.Create(card, info, {
		Position = UDim2.fromOffset(to.X, to.Y),
		Size = UDim2.fromOffset(card.AbsoluteSize.X / A.ENLARGED_FACTOR, toast.AbsoluteSize.Y),
	}):Play()
	backdrop.Visible = false
	autoButton.Visible = false
	task.delay(A.SWITCH, function()
		if switchStamp == stamp then
			showcase.Enabled = false
			backdrop.Visible = true
			autoButton.Visible = true
			card.Position = CARD_POS
			card.Size = cardTargetSize()
			refreshToast()
		end
	end)
	refreshToast()
end

-- The roll sequence -----------------------------------------------------------------------------------------------

-- Landing extras by rarity (design doc "Effects by rarity"; spec "Hold")
local function landEffects(b, roll)
	local spec = roll.Spec
	local rank = rarityRank(spec)
	local color = rarityColor(spec)
	local reduced = UiMotion.Reduced()
	local stroke = b.WaveStroke
	stroke.Color = spec.Rarity == "Secret" and WHITE or color
	stroke.Thickness = rank >= 3 and 6 or 3 -- Rare and up: a stronger ring
	stroke.Transparency = 0
	-- Legendary and Mythic: the land's one shake, so their cues carry none. A Secret's is in its cue (on the title).
	if rank == 5 or rank == 6 then
		UiMotion.Shake(b.Body, 6, 0.2)
	end
	local waveRest = b.Wave:GetAttribute("Rest")
	b.Wave.Size = UDim2.fromScale(waveRest * 0.4, waveRest * 0.4)
	tween(b.Wave, 0.45, { Size = UDim2.fromScale(waveRest * 1.25, waveRest * 1.25) })
	tween(stroke, 0.45, { Transparency = 1 })
	if not b.Full then
		return -- the compact roll has no card: only the ring
	end
	tintCrystal(b, color)
	if rank >= 4 and not reduced then -- Epic: pulsing ring (a loop: never under reduced motion)
		b.Ring.Visible = true
		b.RingStroke.Color = color
		b.RingStroke.Transparency = 0
		local pulse = UiMotion.Create(
			b.RingStroke,
			TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.8 }
		)
		table.insert(tweens, pulse)
		pulse:Play()
	end
	if rank >= 5 and not reduced then -- Legendary: radial gold burst
		b.Burst.Visible = true
		b.Burst.Size = UDim2.fromScale(0.3, 0.5)
		b.Burst.BackgroundTransparency = 0.1
		tween(b.Burst, 0.6, { Size = UDim2.fromScale(1.4, 2.2), BackgroundTransparency = 1 })
	end
	if rank >= 6 and not reduced then -- Mythic: a band of light sweeps across the figure
		b.Flare.Visible = true
		b.Flare.Position = UDim2.fromScale(-0.1, 0.5)
		b.Flare.BackgroundTransparency = 0.2
		tween(b.Flare, 0.5, { Position = UDim2.fromScale(1.1, 0.5), BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	end
	if spec.Rarity == "Secret" and isEnlarged() then -- Secret: full-screen takeover
		takeoverText.Text = "SECRET\n" .. spec.Name
		takeover.BackgroundTransparency = 0.15
		takeoverText.TextTransparency = 0
		takeoverSkip.TextTransparency = 0
		takeover.Visible = true
		-- The title clears so the rolled figure is visible for the rest of the hold; the rainbow border stays.
		local mySerial = serial
		task.delay(TAKEOVER_TITLE, function()
			if serial == mySerial and takeover.Visible then
				tween(takeover, 0.3, { BackgroundTransparency = 1 })
				tween(takeoverText, 0.3, { TextTransparency = 1 })
				tween(takeoverSkip, 0.3, { TextTransparency = 1 })
			end
		end)
	end
end

local function flyToIndex(spec, seconds)
	local chrome = playerGui:FindFirstChild("HudChrome")
	local grid = chrome and chrome:FindFirstChild("Grid", true)
	local target = grid and grid:FindFirstChild("Index")
	if not target or not target.Visible then
		return
	end
	local inset = GuiService:GetGuiInset()
	-- FlyIcon lives in the IgnoreGuiInset RollToast gui: AbsolutePosition + inset = its offset space
	local from = isEnlarged() and (card.AbsolutePosition + inset + card.AbsoluteSize / 2)
		or (toast.AbsolutePosition + inset + toast.AbsoluteSize / 2)
	local to = target.AbsolutePosition + inset + target.AbsoluteSize / 2
	local old = flyView:FindFirstChildOfClass("Model")
	if old then
		old:Destroy()
	end
	local image = portraitFor(spec.Id)
	flyPortrait.Image = image or ""
	flyPortrait.Visible = image ~= nil
	-- A copy: the rig itself stays in the view shrinking behind this icon
	local rig = not image and rigFor(spec.Id)
	if rig then
		local icon = rig:Clone()
		frameRig(flyView, icon, 1)
		icon.Parent = flyView
	end
	flyIcon.Position = UDim2.fromOffset(from.X, from.Y)
	flyIcon.Visible = true
	-- Lands inside Exit and rests on the button until Phase "Idle" hides it. Drive this
	-- from Heartbeat so the compatibility probe observes intermediate positions even
	-- when Studio has no rendered frame.
	local started = os.clock()
	task.spawn(function()
		while flyIcon.Visible and phase == "Exit" do
			local alpha = UiMotion.Reduced() and 1
				or math.clamp((os.clock() - started) / math.max(seconds * 0.7, 0.01), 0, 1)
			local eased = 1 - (1 - alpha) ^ 2
			flyIcon.Position = UDim2.fromOffset(from.X + (to.X - from.X) * eased, from.Y + (to.Y - from.Y) * eased)
			if alpha >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if flyIcon.Visible then
			flyIcon.Position = UDim2.fromOffset(to.X, to.Y)
		end
	end)
end

local function play(roll)
	serial += 1
	local mySerial = serial
	cancelTweens()
	flyIcon.Visible = false
	takeover.Visible = false
	latest = roll
	local spec = roll.Spec
	setAttr("RollSerial", mySerial)
	setAttr("RollId", spec.Id)

	local function alive()
		return serial == mySerial
	end
	local function after(seconds)
		task.wait(seconds)
		return alive()
	end

	local timeScale = A.TimeScale(roll.Interval)
	local reelIds = A.Reel(rng, spec.Id)
	for _, id in reelIds do
		if not portraitFor(id) then
			rigFor(id) -- before anything shows: a build mid-cycle would be a visible hitch
		end
	end
	for _, b in bodies do
		resetBody(b, roll)
		b.Reel:SetAttribute("ReelIds", table.concat(reelIds, ","))
	end
	if roll.Emphasized and not isEnlarged() then
		setShown(reelIds[1]) -- the view opens on a figure, not the last roll's or "?"
		openEnlarged(true)
		-- The card settles first, so the cycle plays in a fixed spot (Duration already counts this SWITCH).
		if not after(A.SWITCH) then
			return
		end
	end

	-- Pop in: the figure area grows from nothing, on the first character of the cycle
	setPhase("PopIn")
	setShown(reelIds[1])
	for _, b in bodies do
		b.Body.Size = UDim2.fromScale(0, 0)
		tween(b.Body, A.POP * timeScale, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	end
	if not after(A.POP * timeScale) then
		return
	end

	-- Spin: fillers swap in the one fixed spot, each slot longer than the last. Reduced motion stays on the first one.
	setPhase("Spin")
	local started = os.clock()
	local elapsed = 0
	local slots = A.SpinSlots(roll.Interval)
	for i, slot in slots do
		if i > 1 and not UiMotion.Reduced() then
			setShown(reelIds[i])
			local b = visibleBody()
			if b then
				b.FigureScale.Scale = SWAP_POP
				tween(b.FigureScale, math.min(SWAP_POP_TIME, slot), { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		if i > 1 and roll.Emphasized then
			UiFeedback.Play("RollTick", nil, { Sound = true, Pitch = 1 + TICK_PITCH_RISE * i / #slots })
		end
		elapsed += slot
		if not after(started + elapsed - os.clock()) then
			return
		end
	end

	-- Land: the result pops to LAND_POP and settles while its odds and name appear
	setShown(spec.Id)
	setPhase("Land")
	local landing = A.LAND * timeScale
	local peak = UiMotion.Reduced() and 1 or A.LAND_POP
	for _, b in bodies do
		tween(b.Body, landing * LAND_RISE, { Size = UDim2.fromScale(peak, peak) })
		landEffects(b, roll)
	end
	-- Never on Body: LAND_POP stays the only size change it gets. No visible body (a panel is open): sound only.
	local landed = visibleBody()
	UiFeedback.Play(
		LAND_CUES[spec.Rarity] or "RollLand1",
		spec.Rarity == "Secret" and takeover.Visible and takeoverText or (landed and landed.Wave),
		{ Color = rarityColor(spec), NoShake = true }
	)
	if not after(landing * LAND_RISE) then
		return
	end
	local settle = landing * (1 - LAND_RISE)
	for _, b in bodies do
		tween(b.Body, settle, { Size = UDim2.fromScale(1, 1) })
		revealText(b, roll, settle)
	end
	if not after(settle) then
		return
	end

	-- Hold: the result stays, longer for rarer characters
	setPhase("Hold")
	if not after(A.Hold(spec.Rarity) * timeScale) then
		return
	end
	takeover.Visible = false

	-- Exit: the figure shrinks away, a small icon of it flies to the INDEX button. The enlarged text stays readable.
	local leaving = A.EXIT * timeScale
	setPhase("Exit")
	flyToIndex(spec, leaving)
	tween(enlarged.FigureScale, leaving, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local exitStarted = os.clock()
	task.spawn(function()
		while phase == "Exit" and compact.Body.Parent do
			local alpha = UiMotion.Reduced() and 1
				or math.clamp((os.clock() - exitStarted) / math.max(leaving, 0.01), 0, 1)
			local eased = alpha * alpha
			compact.Body.Size = UDim2.fromScale(1 - eased, 1 - eased)
			if alpha >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if compact.Body.Parent then
			compact.Body.Size = UDim2.fromScale(0, 0)
		end
	end)
	if not after(leaving) then
		return
	end
	flyIcon.Visible = false
	setPhase("Idle")
	compact.Body.Size = UDim2.fromScale(1, 1)
	enlarged.FigureScale.Scale = 1
	if roll.Emphasized and autoOpened then
		closeEnlarged()
	end
end

-- Inputs --------------------------------------------------------------------------------------------------------

local function refreshAutoButton()
	local on = autoRollOn()
	autoButton.Text = on and "AUTO: ON" or "AUTO: OFF"
	autoButton.BackgroundColor3 = on and Color3.fromRGB(60, 255, 60) or Color3.fromRGB(104, 111, 135)
	refreshToast()
end
player:GetAttributeChangedSignal("AutoRoll"):Connect(refreshAutoButton)
refreshAutoButton()

autoButton.Activated:Connect(function()
	autoRollRemote:FireServer(not autoRollOn())
end)
local RollOptions = require(script.Parent:WaitForChild("RollOptions"))
detailsButton.Activated:Connect(RollOptions.OpenDetails)

-- Open on the press, not the release: the idle toast can hide between the two (it shows only while a roll plays)
-- and a release on a hidden button never fires Activated.
toast.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		openEnlarged(false)
	end
end)
toast.Activated:Connect(function()
	openEnlarged(false)
end)

-- A click on the card or the AUTO button does not close: an Active frame does not stop the backdrop button under it
-- from firing, so the backdrop ignores presses inside them (the showcase ignores the GUI inset: both use screen
-- pixels)
local function over(gobj)
	local p = UserInputService:GetMouseLocation()
	local a, size = gobj.AbsolutePosition, gobj.AbsoluteSize
	return p.X >= a.X and p.X <= a.X + size.X and p.Y >= a.Y and p.Y <= a.Y + size.Y
end
backdrop.Activated:Connect(function()
	if takeover.Visible then
		takeover.Visible = false -- tap to skip the Secret takeover
		return
	end
	if RollOptions.IsOpen() then
		return -- the press belongs to the popup above the view
	end
	if not over(card) and not over(autoButton) and not over(detailsButton) then
		closeEnlarged()
	else
		-- The player is using the view (e.g. pressed where the toast was just as an emphasized roll opened it):
		-- it is theirs now, so the end of that roll no longer closes it
		autoOpened = false
	end
end)

-- Slow loops on the crystal, the odds, the turbo flames and the Secret rainbow; none under reduced motion
RunService.Heartbeat:Connect(function(dt)
	if UiMotion.Reduced() then
		return
	end
	enlarged.GlowGradient.Rotation = (enlarged.GlowGradient.Rotation + dt * 60) % 360
	if enlarged.OddsMoving then
		enlarged.OddsGradient.Offset = Vector2.new(math.sin(os.clock()) * 0.3, 0)
	end
	if enlarged.Flames.Visible then
		enlarged.FlameGradient.Offset = Vector2.new(math.sin(os.clock() * 9) * 0.3, 0)
	end
	if takeover.Visible then
		rainbow.Rotation = (rainbow.Rotation + dt * 120) % 360
	end
end)

local rollQueue = {}
local playingRoll = false

local function drainRollQueue()
	if playingRoll then
		return
	end
	playingRoll = true
	local deadline = os.clock() + MODEL_WAIT
	while not (modelsReady and portraitsReady) and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	while #rollQueue > 0 do
		local roll = table.remove(rollQueue, 1)
		play(roll)
	end
	playingRoll = false
end

rollRemote.OnClientEvent:Connect(function(id, isNew, turboMulti, emphasized, scrapMoney, luck, interval)
	local spec = CharacterCatalog.Get(id)
	if not spec then
		return
	end
	table.insert(rollQueue, {
		Spec = spec,
		IsNew = isNew == true,
		Turbo = (type(turboMulti) == "number" and turboMulti > 1) and turboMulti or 1,
		Emphasized = emphasized == true,
		ScrapMoney = type(scrapMoney) == "number" and scrapMoney or 0,
		Luck = luck, -- validated by HudFormat.Odds
		Interval = type(interval) == "number" and interval > 0 and interval or nil,
	})
	task.spawn(drainRollQueue)
end)

-- Compatibility entry point for older callers; the visible entry point is the
-- compact top-centre Toast itself.
local openRollView = make("BindableEvent", { Name = "OpenRollView" }, gui)
openRollView.Event:Connect(function()
	openEnlarged(false)
end)
-- The figure is capped to a share of the screen; the Toast adds the caption band above it and two text bands below.
local function fitCompact()
	local figure = math.min(A.COMPACT_HEIGHT, math.floor(A.COMPACT_SCREEN_SHARE * screenHeight()))
	local toastTop = A.COMPACT_TOP
	local bands = 2 * COMPACT_TEXT_BAND
	-- On a small phone the top-right row reaches the centre: the roll sits just under it instead
	local chrome = playerGui:FindFirstChild("HudChrome")
	local row = chrome and chrome:FindFirstChild("TopRight", true)
	local camera = workspace.CurrentCamera
	if row and camera then
		local halfWidth = math.clamp(A.COMPACT_WIDTH * camera.ViewportSize.X, A.COMPACT_MIN, A.COMPACT_MAX) / 2
		if row.AbsolutePosition.X < camera.ViewportSize.X / 2 + halfWidth + A.COMPACT_GAP then
			toastTop = row.AbsolutePosition.Y + GuiService:GetGuiInset().Y + row.AbsoluteSize.Y + A.COMPACT_GAP
		end
	end
	-- On a phone the 30 % cap alone would run the name into the LEVEL bar
	local racerHud = playerGui:FindFirstChild("RacerHud")
	local level = racerHud and racerHud:FindFirstChild("Level")
	if level then
		local levelTop = level.AbsolutePosition.Y + GuiService:GetGuiInset().Y
		figure = math.min(figure, math.floor(levelTop - A.COMPACT_GAP - toastTop - bands))
	end
	local total = bands + figure
	toast.Position = UDim2.new(0.5, 0, 0, toastTop)
	toast.Size = UDim2.new(A.COMPACT_WIDTH, 0, 0, total)
	toastSize.MinSize = Vector2.new(A.COMPACT_MIN, total)
	toastSize.MaxSize = Vector2.new(A.COMPACT_MAX, total)
	local top = 0
	local share = figure / total
	local band = COMPACT_TEXT_BAND / total
	for _, view in { compact.Reel, compact.Viewport } do
		view.Position = UDim2.fromScale(0, top)
		view.Size = UDim2.fromScale(1, share)
	end
	compact.Wave.Position = UDim2.fromScale(0.5, top + share / 2)
	compact.Wave:SetAttribute("Rest", share)
	compact.Wave.Size = UDim2.fromScale(share, share)
	compact.Odds.Position = UDim2.fromScale(0, top + share)
	compact.Odds.Size = UDim2.fromScale(1, band)
	compact.CharacterName.Position = UDim2.fromScale(0, top + share + band)
	compact.CharacterName.Size = UDim2.fromScale(1, band)
end
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitCompact)
end
fitCompact()
-- Synchronously, so the toast is never drawn for a frame after a panel opens.
PanelSwitch.OnChange(refreshToast)
player:GetAttributeChangedSignal("BossEvent"):Connect(refreshToast) -- design doc 4.37: auto-roll pauses in the event
toast:GetPropertyChangedSignal("AbsoluteSize"):Connect(drawShown)

-- The generated RollShowcase is the old card layout, and its fit() puts these rows back on every resize. Runtime
-- layout wins: each pinned property snaps back whenever fit() writes it.
local pins = {}
local function pin(inst, props)
	local held = pins[inst]
	if not held then
		held = {}
		pins[inst] = held
		inst.Changed:Connect(function(property)
			local want = held[property]
			if want ~= nil and inst[property] ~= want then
				inst[property] = want
			end
		end)
	end
	for property, value in props do
		held[property] = value
		inst[property] = value
	end
end

-- Enlarged layout in fractions of the body: odds, figure and name stacked on the card's centre, rarity and cruise in a
-- column to the figure's left, badges to its right.
local function fitShowcase()
	local m = isPhone() and ENLARGED_PHONE or ENLARGED_DESKTOP
	local top = (m.Height - m.Figure - 2 * m.Band) / 2
	local figureW, figureH = m.Figure / m.Width, m.Figure / m.Height
	local figureSize = UDim2.fromScale(figureW, figureH)
	local figurePos = UDim2.fromScale(0.5 - figureW / 2, 0.5 - figureH / 2)
	local bandSize = UDim2.fromScale(0.8, m.Band / m.Height)
	local oddsPos = UDim2.fromScale(0.1, top / m.Height)
	local namePos = UDim2.fromScale(0.1, (top + m.Band + m.Figure) / m.Height)
	local sideSize = UDim2.fromScale(0.2, 0.12)
	local raritySize = UDim2.fromScale(0.26, 0.18) -- TextScaled: the box sets the word's size (audit A27)
	pin(rollRefs.PreviewRunner, { Position = figurePos, Size = figureSize, Visible = false })
	pin(rollRefs.RollHeader, { Visible = false })
	pin(rollRefs.RollHeader.Parent, { Visible = false }) -- the outer frame owns the header's Shadow
	pin(enlarged.Odds, { Position = oddsPos, Size = bandSize })
	pin(enlarged.CharacterName, { Position = namePos, Size = bandSize })
	pin(enlarged.Rarity, { Position = UDim2.fromScale(0.03, 0.28), Size = raritySize })
	pin(enlarged.SpeedMulti, { Position = UDim2.fromScale(0.03, 0.46), Size = sideSize })
	for _, alias in { enlarged.Aliases.Odds, enlarged.Aliases.Name, enlarged.Aliases.Rarity, enlarged.Aliases.Speed } do
		alias.AnchorPoint = Vector2.new(0, 0)
	end
	enlarged.Aliases.Odds.Position, enlarged.Aliases.Odds.Size = oddsPos, bandSize
	enlarged.Aliases.Name.Position, enlarged.Aliases.Name.Size = namePos, bandSize
	enlarged.Aliases.Rarity.Position, enlarged.Aliases.Rarity.Size = enlarged.Rarity.Position, raritySize
	enlarged.Aliases.Speed.Position, enlarged.Aliases.Speed.Size = enlarged.SpeedMulti.Position, sideSize
	enlarged.Reel.Position, enlarged.Reel.Size = figurePos, figureSize
	enlarged.Viewport.Position, enlarged.Viewport.Size = figurePos, figureSize
	enlarged.Wave.Size = figureSize
	enlarged.Wave:SetAttribute("Rest", figureH)
	local centre = UDim2.fromScale(0.5, 0.5)
	local crystal = UDim2.fromScale(figureW * CRYSTAL_SHARE, figureH * CRYSTAL_SHARE)
	for _, part in { enlarged.Glow, enlarged.Facet, enlarged.Ring, enlarged.Flames } do
		part.Position = centre
		part.Size = crystal
	end
	for i, shard in SHARDS do
		enlarged.Shards[i].Position = UDim2.fromScale(0.5 + shard[1] * figureW, 0.5 + shard[2] * figureH)
		enlarged.Shards[i].Size = UDim2.fromScale(shard[3] * figureW, shard[3] * figureH)
	end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitShowcase)
fitShowcase()
autoButton.Font = Enum.Font.FredokaOne
autoButton:FindFirstChildOfClass("UIStroke").Thickness = 3
UiTheme.Apply(gui)
UiTheme.Apply(showcase)

-- Last: this can yield, and a roll may arrive meanwhile
local hud = playerGui:WaitForChild("RacerHud")
hud:WaitForChild("Level"):GetPropertyChangedSignal("AbsolutePosition"):Connect(fitCompact)
task.spawn(function()
	local row = playerGui:WaitForChild("HudChrome"):WaitForChild("TopRight")
	-- Daily's countdown changes its width; the position settles after the size, so follow both
	row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCompact)
	row:GetPropertyChangedSignal("AbsolutePosition"):Connect(fitCompact)
	fitCompact()
end)
fitCompact()
