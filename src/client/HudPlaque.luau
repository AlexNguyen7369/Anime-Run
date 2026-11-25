--!nonstrict
-- HUD option A "wood plaques" (design doc 4.46, drafts/hud_a.html): the cream wood plaque behind a HUD button, the
-- vermilion key-letter seal and the dark lacquer plate with a gold rim. Each dresses an existing GuiObject; the button
-- keeps its own transparent background, so its hover / press UIScale (RacerMotion) and click stay as they are.
-- Colours and fonts are UiTheme.Scroll's (the Summon kit). Sizes are proposed.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local K = UiTheme.Scroll
local HudPlaque = {}
-- The one switch for the always-on HUD's look from before option A (4.40 Tab tilt icons, white outlined labels, dark
-- pills, blue Gems, the generated Turbo bar, dark team circles). On in both worlds (design doc 4.46 "HUD look" and
-- 4.47, owner 2026-11-24: "revert HUD to world 1 hud or old hud. not scrol hud. Scroll Gui can stay."): every HUD site
-- reads it and skips its option A dressing (BossEventUi only for the Bosses / Team column); panels, popups, toasts,
-- banners and the boss event UI keep the Scroll Dojo look. False brings option A back.
HudPlaque.Old = true
HudPlaque.Ink = K.TileInk
HudPlaque.Script = K.Script -- Kalam Bold brush labels
HudPlaque.Heading = K.Heading -- Permanent Marker
HudPlaque.BodyBold = K.BodyBold
HudPlaque.Gold = K.TagGold
HudPlaque.LacquerColor = K.Lacquer

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

-- A kit font on `label`; UiTheme.Apply leaves text with an AnimeRole alone (it would put it back on Fredoka).
function HudPlaque.Font(label, face)
	label.FontFace = face
	label:SetAttribute("AnimeRole", "Dojo")
	return label
end

-- The wood plaque: a Frame "Plaque" filling `button` under its icon and label (ZIndex `z`, default 1), cream wood with a
-- brown rim, a light inner bevel and a dark lip under its foot. `radius` px (default 7). Never takes input.
function HudPlaque.Plaque(button, z, radius)
	z = z or 1
	local plaque = make("Frame", "Plaque", button, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
		Active = false,
		Selectable = false,
	})
	make("UIGradient", "Wood", plaque, { Color = ColorSequence.new(K.TileTop, K.TileBottom), Rotation = 90 })
	make("UICorner", "Corner", plaque, { CornerRadius = UDim.new(0, radius or 7) })
	make("UIStroke", "Rim", plaque, {
		Color = K.TileRim,
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	local bevel = make("Frame", "Bevel", plaque, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ZIndex = z,
		Active = false,
	})
	make("UICorner", "Corner", bevel, { CornerRadius = UDim.new(0, math.max((radius or 7) - 3, 2)) })
	make("UIStroke", "Edge", bevel, {
		Color = Color3.new(1, 1, 1),
		Thickness = 1,
		Transparency = 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	-- The lip: a dark edge just under the plaque's rim (the draft's 4 px drop), outside the button's own rect.
	local lip = make("Frame", "Lip", plaque, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 1),
		Size = UDim2.new(1, -4, 0, 4),
		BackgroundColor3 = K.TileEdge,
		BorderSizePixel = 0,
		ZIndex = z,
		Active = false,
	})
	make("UICorner", "Corner", lip, { CornerRadius = UDim.new(0, 3) })
	return plaque
end

-- The key-letter seal: `label` (a TextLabel) becomes a small tilted vermilion square with a cream letter and a thin
-- cream inner rule.
function HudPlaque.Seal(label)
	label.BackgroundColor3 = K.Accent
	label.BackgroundTransparency = 0
	label.BorderSizePixel = 0
	label.Rotation = -6
	label.TextColor3 = K.SealText
	label.TextXAlignment = Enum.TextXAlignment.Center
	HudPlaque.Font(label, K.BodyBold)
	make("UICorner", "Corner", label, { CornerRadius = UDim.new(0, 4) })
	make("UIStroke", "Rim", label, {
		Color = K.SealText,
		Thickness = 1,
		Transparency = 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	return label
end

-- The lacquer plate: `frame` becomes dark lacquer with a gold rim (Money, Gems, the team bonus, the info card).
function HudPlaque.Lacquer(frame, radius)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	if frame:IsA("TextLabel") then
		frame.BackgroundColor3 = K.Lacquer -- flat: a UIGradient on a label would tint its text too
	else
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		make("UIGradient", "Lacquer", frame, { Color = ColorSequence.new(K.Lacquer, K.LacquerDark), Rotation = 90 })
	end
	make("UICorner", "Corner", frame, { CornerRadius = UDim.new(0, radius or 8) })
	make("UIStroke", "Rim", frame, {
		Color = K.TagGold,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	return frame
end

return HudPlaque
