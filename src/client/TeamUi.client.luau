--!nonstrict
-- Team Setup page (design doc 4.45, owner 2026-11-17; docs/TEAM_AND_STAMINA_SPEC.md "Team" and "Team Setup page";
-- replaces layout A of 4.40). Opened by the second column's Team button and its key T (Client/BossEventUi), a click on
-- the team minibar (Client/TeamHud) and the plaza Team altar (Client/PlazaPrompts), all PanelSwitch "Team", with the
-- shared Sakura transition (cyan accent). Full screen over the Team button; its own Close or Back closes it (4.40,
-- owner 2026-11-20).
-- Look: "Team Select night dojo" (4.45, owner 2026-11-19/20; the approved Studio draft tools/studio/team_select_draft.luau,
-- captures https://claude.ai/artifact/16AdtJyLjWfV8AUwD2mo4D): the night-dojo plate with one camera matched to it (each
-- altar's Pedestal is a full-stage ViewportFrame with that camera, so the three altars share it), two-tier lacquer altars
-- with gold-orange rings, the members as their models in an idle stance with breathing, dark lacquer nameplates over
-- them, the Makimono parchment scroll on the left (Summon's parchment look), the roster handscroll along the bottom and
-- the drawn icons (assets/ui/team_icons). Laid out on a 1080-tall design canvas (Panel's Fit UIScale); the stage keeps
-- the plate's 1920 x 1080 geometry and shifts to sit right of the scroll. Sizes and offsets are proposed.
-- Left out until the owner rules (4.45 open questions, no behaviour given): the Team 1 dropdown and pencil (one team,
-- no rename) and the ‹ › nav arrows. A picked altar keeps the "Selected" plate and a brighter ring (the doc's default).
-- Every control keeps its name and parent so the UI tests still find it.
-- Three altars hold a local draft of the Team: tap an altar or its ledger row, then a roster card (or the other way
-- round); a member put on another altar swaps; Remove takes one off. Quick Setup asks the server (TeamQuickPick) for the
-- best owned characters for the empty altars; Deploy sends the draft through the unchanged SetTeam and closes with the
-- altars' activation. Closing with an undeployed draft asks Deploy or Discard. The Sidekicks tab equips a Sidekick on a
-- member at once (SidekickEquip). The server decides every figure; the client only displays. Models and the breathing
-- loop live only while the page is open.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CharacterCatalog = require(shared:WaitForChild("CharacterCatalog"))
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local RaceConfig = require(shared:WaitForChild("RaceConfig"))
local SeriesCatalog = require(shared:WaitForChild("SeriesCatalog"))
local SidekickConfig = require(shared:WaitForChild("SidekickConfig"))
local StaminaConfig = require(shared:WaitForChild("StaminaConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local Components = require(script.Parent.RollToast.Ui:WaitForChild("RacerComponents"))
local DojoScroll = require(script.Parent:WaitForChild("DojoScroll"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local RosterCard = require(script.Parent:WaitForChild("RosterCard"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local SlotPicker = require(script.Parent:WaitForChild("SlotPicker"))
local TouchTarget = require(script.Parent:WaitForChild("TouchTarget"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local UiTooltip = require(script.Parent:WaitForChild("UiTooltip"))

local D = UiTheme.Dojo
local K = UiTheme.Scroll
local PK = K.Skins.Parchment -- the Summon page's parchment skin (owner 2026-11-20: "consistent with the Summon UI")
local SLOTS = 3
local SIZE = StaminaConfig.TEAM_SIZE
local DESIGN_H = 1080 -- the page is laid out in px of a 1080-tall screen
local STAGE_W = 1920 -- the plate's design width
local SCROLL_R = 392 -- the left scroll's right edge; the stage centres in the room right of it
local PLATE = "rbxassetid://84852553726102" -- the night-dojo plate (assets/ui/team_dojo)
local FLY = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CARD_W, CARD_H, CARD_GAP = 170, 228, 8 -- roster parchment cards
local TRAY_X, TRAY_Y = 400, 676 -- the roster handscroll's top-left (tabs, search and sort ride on it)

-- Camera matched to the plate (4.45): level, 6.52 studs up, focal 1870 px, floor vanishing point (1089, 242).
local CAM = { f = 1870, cx = 1089, cy = 242, h = 6.52 }
local VIEW_HALF = 838 -- px: half the stage viewport's height
local AP = math.cos(math.pi / 8) -- an octagon's apothem over its radius
-- Altars (4.45): slot 1 centre, slots 2 and 3 behind it left and right, turned toward the camera.
local GEO = {
	{ X = 0, Z = -35.1, rb = 5.9, rt = 4.9, hb = 0.62, ht = 0.80, scale = 1.0, delay = 0 },
	{ X = -9.37, Z = -47.5, rb = 3.5, rt = 3.1, hb = 0.30, ht = 0.30, scale = 0.905, delay = 1.12 },
	{ X = 10.26, Z = -47.5, rb = 3.5, rt = 3.1, hb = 0.30, ht = 0.30, scale = 0.905, delay = 2.24 },
}
-- Stage px: each altar's tap area (member and altar top, apart from each other) and its nameplate (the approved draft).
local HIT = { { 870, 110, 440, 550 }, { 582, 205, 280, 330 }, { 1350, 205, 284, 330 } }
local PLATES = { { 940, 123, 328, 80 }, { 598, 219, 256, 64 }, { 1362, 219, 262, 64 } }

-- Drawn icons (owner 2026-11-20: "draw the icons"; assets/ui/team_icons/asset.json).
local ICON = {
	members = "rbxassetid://120701226138389",
	cruise = "rbxassetid://90390164671669",
	check = "rbxassetid://80155502075768",
	flower = "rbxassetid://109103491597058",
	heart = "rbxassetid://121022170152825",
	bolt = "rbxassetid://125367337236897",
	stamina = "rbxassetid://90685209894294",
	person = "rbxassetid://134691081100736",
	fox = "rbxassetid://80346729214213",
	search = "rbxassetid://101694582811922",
	sort = "rbxassetid://98275488757200",
	star = "rbxassetid://138766078045247",
}
local hex = Color3.fromHex
local RAR_CREAM = { -- rarity text on parchment
	Common = hex("6a6a6a"),
	Uncommon = hex("2e9a3e"),
	Rare = hex("2a7ae0"),
	Epic = hex("8a3ad8"),
	Legendary = hex("c88a00"),
	Mythic = hex("d8204a"),
	Secret = hex("1a1a1a"),
	Eternal = hex("0a8f88"),
}
local RAR_DARK = { -- rarity text on dark lacquer
	Common = hex("cfcfcf"),
	Uncommon = hex("7ee07e"),
	Rare = hex("6aaeff"),
	Epic = hex("c890ff"),
	Legendary = hex("ffcf3a"),
	Mythic = hex("ff86c8"),
	Secret = hex("f4f4f4"),
	Eternal = hex("6af0e6"),
}
local RAR_BG = { -- behind a portrait
	Common = hex("9a9a9a"),
	Uncommon = hex("5ac85a"),
	Rare = hex("3a8ae8"),
	Epic = hex("9a5ae0"),
	Legendary = hex("e79a2a"),
	Mythic = hex("e23a3a"),
	Secret = hex("2a2a34"),
	Eternal = hex("1fa8a0"),
}
local NUN = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
local NUNI = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local NUM = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
local KALAM, MARKER, BODY, BODYB = K.Script, K.Heading, K.Body, K.BodyBold
local INK = K.TileInk -- dark ink on paper
local RIM = K.PaperRim -- ink-brush rim
local VERM = K.Accent
local RING = hex("ffb43a") -- the altars' gold-orange ring (owner 2026-11-20)
local READY = hex("2a8a3a") -- "Ready" on parchment
local WARN = D.Warn -- "Unsaved changes" on paper
local OFF = Color3.fromRGB(175, 165, 155) -- an off button's paper

-- ---------- builders ----------
local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function box(name, parent, x, y, w, h, color, props)
	local p = { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BorderSizePixel = 0 }
	if color then
		p.BackgroundColor3 = color
	else
		p.BackgroundTransparency = 1
	end
	for key, value in props or {} do
		p[key] = value
	end
	return make("Frame", name, parent, p)
end
-- Kalam and Titillium read smaller than Nunito at one TextSize; they come up to the Summon page's weight.
local function textSize(face, size)
	local family = face.Family
	if string.find(family, "Kalam") then
		return math.floor(size * 1.22)
	elseif string.find(family, "Titillium") then
		return math.floor(size * 1.1)
	end
	return size
end
local function label(name, parent, text, x, y, w, h, size, color, face, props)
	face = face or NUN
	local p = {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Text = text,
		TextSize = textSize(face, size),
		TextColor3 = color or Color3.new(1, 1, 1),
		FontFace = face,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	}
	for key, value in props or {} do
		p[key] = value
	end
	return make("TextLabel", name, parent, p)
end
local function picture(name, parent, image, x, y, w, h, props)
	local p = {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Crop,
	}
	for key, value in props or {} do
		p[key] = value
	end
	return make("ImageLabel", name, parent, p)
end
local function corner(gui, r)
	make("UICorner", "Round", gui, { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 8) })
	return gui
end
local function stroke(gui, color, thickness, name)
	return make("UIStroke", name or "Edge", gui, {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end
local function shade(gui, top, bottom, rotation, mid)
	local seq = mid
			and ColorSequence.new({
				ColorSequenceKeypoint.new(0, top),
				ColorSequenceKeypoint.new(mid[1], mid[2]),
				ColorSequenceKeypoint.new(1, bottom),
			})
		or ColorSequence.new(top, bottom)
	local g = gui:FindFirstChild("Shade") or make("UIGradient", "Shade", gui, {})
	g.Color, g.Rotation = seq, rotation or 90
	return g
end
local function outline(gui, color, thickness)
	return make(
		"UIStroke",
		"Outline",
		gui,
		{ Color = color or Color3.new(0, 0, 0), Thickness = thickness or 2, Transparency = 0.35 }
	)
end
local function icon(parent, key, x, y, s, props)
	local p = { ScaleType = Enum.ScaleType.Fit }
	for k, v in props or {} do
		p[k] = v
	end
	return picture("Icon_" .. key, parent, ICON[key], x, y, s, s, p)
end
-- Parchment sheet: gradient fill, thin ink outline, aged shading top and bottom.
local function paper(name, parent, x, y, w, h)
	local p = box(name, parent, x, y, w, h, Color3.new(1, 1, 1))
	shade(p, PK.Paper, PK.PaperShade)
	stroke(p, RIM, 1.5)
	for i, e in { { 0, 0, 90 }, { h - 18, 0, 270 } } do
		local s = box("Age" .. i, p, 0, e[1], w, 18, PK.MountDark)
		make("UIGradient", "Fade", s, { Rotation = e[3], Transparency = NumberSequence.new(0.35, 1) })
	end
	return p
end
-- Round wooden rod with darker end caps past the paper.
local function woodRod(name, parent, x, y, w, h, vertical)
	local r = box(name, parent, x, y, w, h, Color3.new(1, 1, 1))
	corner(r, UDim.new(0.5, 0))
	shade(r, PK.RodTop, PK.RodBottom, vertical and 0 or 90, { 0.35, PK.RodTop:Lerp(Color3.new(1, 1, 1), 0.18) })
	stroke(r, PK.CapDark, 1)
	local caps = vertical and { { 0.5, 0, -14, w + 8, 18 }, { 0.5, 1, 14, w + 8, 18 } }
		or { { 0, 0.5, 0, 18, h + 8 }, { 1, 0.5, 0, 18, h + 8 } }
	for i, c in caps do
		local cap = make("Frame", i == 1 and "CapTop" or "CapBottom", r, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = vertical and UDim2.new(0.5, 0, c[2], c[3] / 2) or UDim2.new(c[1], c[1] == 0 and -5 or 5, 0.5, 0),
			Size = UDim2.fromOffset(c[4], c[5]),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
		})
		corner(cap, 6)
		shade(cap, PK.CapLight, PK.CapDark, vertical and 90 or 0)
	end
	return r
end
-- Summon-style section heading: Permanent Marker ink (its lowercase reads as small caps), a thin rule under it.
local function rule(name, parent, x, y, w)
	return box(name, parent, x, y, w, 2, PK.RuleTop, { BackgroundTransparency = 0.6 })
end
local function heading(name, parent, text, x, y, w)
	local l = label(name, parent, text, x, y, w, 38, 30, INK, MARKER, { RichText = false })
	rule(name .. "Rule", parent, x, y + 40, w)
	return l
end
-- Red square seal (as 選 on Summon): vermilion fill, cream glyph.
local function redSeal(name, parent, text, x, y, s, face)
	local b = label(name, parent, text, x, y, s, s, math.floor(s * 0.7), K.SealText, face or NUM, {
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = VERM,
	})
	corner(b, 4)
	return b
end
-- Summon paper look on a button or box: parchment fill, ink-brush rim. Its own text shows (dark ink barely tints).
local function paperDress(gui, top, bottom, rim, thickness)
	if gui:IsA("GuiButton") then
		gui.AutoButtonColor = false
	end
	gui.BackgroundColor3 = Color3.new(1, 1, 1)
	gui.BackgroundTransparency = 0
	gui.BorderSizePixel = 0
	shade(gui, top or K.Cream, bottom or PK.PaperShade)
	corner(gui, 10)
	stroke(gui, rim or RIM, thickness or 3)
	return gui
end
local function pad(gui, left, right)
	return make(
		"UIPadding",
		"Pad",
		gui,
		{ PaddingLeft = UDim.new(0, left or 0), PaddingRight = UDim.new(0, right or 0) }
	)
end
local function fitText(gui, maxSize)
	gui.TextScaled = true
	make("UITextSizeConstraint", "Limit", gui, { MaxTextSize = maxSize, MinTextSize = 8 })
end
local function hoverable(button)
	local scale = button:FindFirstChild("HoverScale") or make("UIScale", "HoverScale", button, {})
	button.MouseEnter:Connect(function()
		UiMotion.Create(scale, HOVER, { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		UiMotion.Create(scale, HOVER, { Scale = 1 }):Play()
	end)
end
-- Soft radial glow: stacked see-through ellipses (no image asset), as the draft.
local function glow(parent, cx, cy, w, h, color, alpha, n)
	for k = 1, n do
		local s = k / n
		local g = box("Glow", parent, cx - w * s / 2, cy - h * s / 2, w * s, h * s, color, {
			BackgroundTransparency = 1 - alpha / n * 1.6,
		})
		corner(g, UDim.new(0.5, 0))
	end
end
local function project(x, y, z)
	return CAM.cx + CAM.f * x / -z, CAM.cy + CAM.f * (CAM.h - y) / -z
end

local root = make("ScreenGui", "RacerTeam", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2, -- the panels' order (Backpack, Checkpoints)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
-- Full screen (owner 2026-11-17 / 2026-11-20). Fit scales the 1080-tall design canvas to the screen.
local panel = make("Frame", "Panel", root, {
	Size = UDim2.fromOffset(STAGE_W, DESIGN_H),
	BackgroundColor3 = hex("12040a"),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Visible = false,
	Active = true,
})
local fit = make("UIScale", "Fit", panel, {})

-- ---------- stage: plate, glows, ring arrows (static) ----------
local stage = box("Stage", panel, 0, 0, STAGE_W, DESIGN_H, nil, { ZIndex = 1 })
local plate = picture("Plate", stage, PLATE, 0, 0, STAGE_W, DESIGN_H, { ScaleType = Enum.ScaleType.Stretch })
local plateFade = make("UIGradient", "Fade", plate, { Enabled = false }) -- a screen wider than the plate fades its ends
do
	local glows = box("Glows", stage, 0, 0, STAGE_W, DESIGN_H)
	glow(glows, 1089, 640, 900, 190, hex("ff9a2a"), 0.55, 10) -- warm floor glow
	glow(glows, 720, 500, 420, 90, hex("ffb34a"), 0.45, 8)
	glow(glows, 1493, 500, 420, 90, hex("ffb34a"), 0.45, 8)
	glow(glows, 1089, 350, 560, 560, hex("ff2a3a"), 1.1, 14) -- the soft red-pink aura behind the centre member
	glow(glows, 1089, 340, 300, 380, hex("ff5a7a"), 0.8, 10)
	-- Pink ring arrows on the ellipse centred (1102, 442), 555 x 149 (4.45): upper arc 150..392 deg, five arrowheads.
	local arcs = box("Arcs", stage, 0, 0, STAGE_W, DESIGN_H)
	local C, RX, RY = Vector2.new(1102, 442), 555, 149
	local function P(a)
		return C + Vector2.new(RX * math.cos(a), RY * math.sin(a))
	end
	local a0, a1, n = math.rad(150), math.rad(392), 120
	for i = 0, n - 1 do
		local u = i / n
		local fade = math.min(1, u / 0.08, (1 - u) / 0.08)
		local p1, p2 = P(a0 + (a1 - a0) * u), P(a0 + (a1 - a0) * (i + 1) / n)
		local mid, d = (p1 + p2) / 2, p2 - p1
		local rot = math.deg(math.atan2(d.Y, d.X))
		box("Arc", arcs, mid.X, mid.Y, d.Magnitude + 2, 11, hex("ff4f8f"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rot,
			BackgroundTransparency = 1 - 0.28 * fade,
		})
		box("Core", arcs, mid.X, mid.Y, d.Magnitude + 1, 3.2, hex("ffc3dc"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rot,
			BackgroundTransparency = 1 - fade,
		})
	end
	for _, head in { { 192, 1 }, { 234.7, -1 }, { 248.9, 1 }, { 304.5, 1 }, { 361, -1 } } do
		local a, dir = math.rad(head[1]), head[2]
		local p = P(a)
		local ang = math.deg(math.atan2(RY * math.cos(a) * dir, -RX * math.sin(a) * dir))
		local tip = p + Vector2.new(math.cos(math.rad(ang)), math.sin(math.rad(ang))) * 12
		for _, layer in { { 16, hex("ff4f8f"), 0.6, 34 }, { 7, hex("ffd1e4"), 0, 28 } } do
			for _, side in { -1, 1 } do
				local back = math.rad(ang + 180 + side * 32)
				local len = layer[4]
				local c = tip + Vector2.new(math.cos(back), math.sin(back)) * (len / 2 - 2)
				local bar = box("Head", arcs, c.X, c.Y, len, layer[1], layer[2], {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = math.deg(back),
					BackgroundTransparency = layer[3],
				})
				corner(bar, UDim.new(0.5, 0))
				if layer[3] == 0 then
					stroke(bar, hex("ff5a9a"), 1.5)
				end
			end
		end
	end
end
-- Static petals over the stage.
local petals = box("Petals", panel, 0, 0, STAGE_W, DESIGN_H, nil, { ZIndex = 3 })
do
	local rnd = Random.new(7)
	for _ = 1, 16 do
		local px, py = rnd:NextNumber(470, 1880), rnd:NextNumber(90, 680)
		if not (px > 930 and px < 1250 and py > 500 and py < 580) then -- clear of the Selected plate
			local p = box("Petal", petals, px, py, 16, 10, hex("ffb0cc"), {
				Rotation = rnd:NextNumber(0, 180),
				BackgroundTransparency = 0.15,
			})
			corner(p, UDim.new(0.5, 0))
		end
	end
end

-- ---------- 3D altars (built on open, destroyed on close) ----------
local WOOD, WOOD_FACE, GOLD = hex("2c0c09"), hex("2a0a08"), hex("e7b552")
local function part(parent, size, cf, color, props)
	local p = make("Part", "Part", nil, {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	for key, value in props or {} do
		p[key] = value
	end
	p.Parent = parent
	return p
end
local function octagon(parent, apothem, h, cf, color, props)
	local w = 2 * apothem
	for k = 0, 3 do
		part(
			parent,
			Vector3.new(w, h, w * math.tan(math.pi / 8)),
			cf * CFrame.Angles(0, k * math.pi / 4, 0),
			color,
			props
		)
	end
end
local function octRing(parent, apothem, y, cf, color, thick, width)
	local edge = 2 * apothem * math.tan(math.pi / 8)
	local out = {}
	for k = 0, 7 do
		local c = cf * CFrame.Angles(0, k * math.pi / 4, 0) * CFrame.new(0, y, apothem)
		table.insert(out, part(parent, Vector3.new(edge + width * 0.83, thick, width), c, color))
	end
	return out
end
local function yawOf(s)
	return math.atan2(-s.X, -s.Z) -- a flat face to the camera
end
-- Two-tier octagon in dark lacquered wood with gold trim and a glowing gold-orange ring on top. Returns the ring parts.
local function buildAltar(parent, s)
	local m = make("Model", "Altar", parent)
	local cf = CFrame.new(s.X, 0, s.Z) * CFrame.Angles(0, yawOf(s), 0)
	local ab, at = s.rb * AP, s.rt * AP
	local top = s.hb + s.ht
	octagon(m, ab + 0.06, 0.06, cf * CFrame.new(0, 0.03, 0), GOLD)
	octagon(m, ab, s.hb, cf * CFrame.new(0, s.hb / 2, 0), WOOD, { Reflectance = 0.08 })
	octagon(m, ab + 0.04, 0.07, cf * CFrame.new(0, s.hb - 0.035, 0), GOLD)
	octagon(m, at, s.ht, cf * CFrame.new(0, s.hb + s.ht / 2, 0), WOOD, { Reflectance = 0.08 })
	octagon(m, at + 0.04, 0.08, cf * CFrame.new(0, top - 0.04, 0), GOLD)
	octagon(m, at - 0.08, 0.02, cf * CFrame.new(0, top + 0.01, 0), WOOD_FACE)
	local rings = octRing(m, at * 0.86, top + 0.03, cf, RING, 0.03, s.rb > 4 and 0.16 or 0.12)
	octRing(m, at * 0.62, top + 0.03, cf, hex("ff8a1e"), 0.02, 0.06)
	local lamp = hex("ffd27a") -- warm light panels on the front faces
	if s.rb > 4 then
		for _, x in { -2.4, 2.4 } do
			part(m, Vector3.new(0.62, 0.32, 0.05), cf * CFrame.new(x, s.hb * 0.5, ab + 0.02), lamp)
		end
		for _, side in { -1, 1 } do
			local c = cf * CFrame.Angles(0, side * math.pi / 4, 0) * CFrame.new(0, s.hb * 0.5, ab + 0.02)
			part(m, Vector3.new(0.5, 0.3, 0.05), c, lamp)
		end
		for _, x in { -1.6, 1.6 } do
			part(m, Vector3.new(0.9, 0.06, 0.05), cf * CFrame.new(x, s.hb + s.ht * 0.5, at + 0.02), lamp)
		end
	else
		for _, x in { -1.3, 1.3 } do
			part(m, Vector3.new(0.7, 0.07, 0.05), cf * CFrame.new(x, s.hb * 0.5, ab + 0.02), lamp)
		end
	end
	return m, rings
end

-- ---------- members: idle stance + breathing (4.45) ----------
-- Static idle stance under the breathing; the rigs are rigid parts, so each limb turns whole about its joint. Degrees;
-- arm values are { left, right }.
local STANCE = { legRoll = 13, armRoll = { 15, 19 }, armFwd = { 8, 14 }, lean = 3, headTilt = 2.5 }
local PERIOD = 3.4 -- s per breath
local function rotAbout(pt, rot)
	return CFrame.new(pt) * rot * CFrame.new(-pt)
end
local function stanceOf(name, cf, size, legTop)
	local A = STANCE
	local sgn = cf.X >= 0 and 1 or -1
	local i = sgn < 0 and 1 or 2
	if name == "LeftLeg" or name == "RightLeg" then
		return rotAbout(Vector3.new(cf.X, cf.Y + size.Y / 2, cf.Z), CFrame.Angles(0, 0, sgn * math.rad(A.legRoll)))
	end
	local lean = rotAbout(Vector3.new(0, legTop, cf.Z), CFrame.Angles(-math.rad(A.lean), 0, 0)) -- top toward the camera
	if name == "LeftArm" or name == "RightArm" then
		-- pivot at the armpit, so the arm swings out without poking above the shoulder
		local pivot = Vector3.new(cf.X - sgn * size.X / 2, cf.Y + size.Y / 2, cf.Z)
		local rot = CFrame.Angles(math.rad(A.armFwd[i]), 0, 0) * CFrame.Angles(0, 0, sgn * math.rad(A.armRoll[i]))
		return lean * rotAbout(pivot, rot)
	elseif name == "Head" then
		return lean * rotAbout(Vector3.new(cf.X, cf.Y - size.Y / 2, cf.Z), CFrame.Angles(0, 0, math.rad(A.headTilt)))
	end
	return lean
end
local function boxMinY(cf, size)
	local m = math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				m = math.min(m, (cf * (Vector3.new(x, y, z) * size / 2)).Y)
			end
		end
	end
	return m
end
local function applyStance(r)
	local legTop = 0
	for p, info in r.parts do
		if p.Name == "LeftLeg" or p.Name == "RightLeg" then
			legTop = math.max(legTop, info.cf.Y + info.size.Y / 2)
		end
	end
	local low = math.huge
	for p, info in r.parts do
		info.stance = stanceOf(p.Name, info.cf, info.size, legTop)
		if p.Name == "LeftLeg" or p.Name == "RightLeg" then
			low = math.min(low, boxMinY(info.stance * info.cf, info.size))
		end
	end
	local seat = CFrame.new(0, low == math.huge and 0 or -low, 0) -- the lowest foot corner touches the altar top
	for _, info in r.parts do
		info.stance = seat * info.stance
	end
end
-- One frame of breathing at time t (3.4 s sine; torso Y +2.2 %, Z +3 %, rise 0.035; shoulders rise 0.05 and roll
-- 2 deg; head nod 2 deg; sway 0.46 deg over two breaths).
local function pose(r, t)
	local tt = t - r.delay
	local b = math.sin(2 * math.pi * tt / PERIOD)
	local inhale = (b + 1) / 2
	local k = r.k
	local sway = CFrame.Angles(0, 0, math.rad(0.46) * math.sin(math.pi * tt / PERIOD))
	local torsoInfo = r.torso and r.parts[r.torso]
	local grow = torsoInfo and torsoInfo.size.Y * 0.022 * inhale or 0
	local rise = 0.035 * k * inhale
	for p, info in r.parts do
		local cf, size = info.stance * info.cf, info.size
		local name = p.Name
		if name == "Torso" then
			size =
				Vector3.new(size.X * (1 + 0.012 * inhale), size.Y * (1 + 0.022 * inhale), size.Z * (1 + 0.03 * inhale))
			cf = CFrame.new(0, rise + grow / 2, 0) * cf
		elseif name == "Head" then
			local neckY = torsoInfo and (torsoInfo.cf.Y + torsoInfo.size.Y / 2) or cf.Y - size.Y / 2
			local pivot = CFrame.new(cf.X, neckY, cf.Z)
			cf = CFrame.new(0, rise + grow + 0.01 * k * inhale, 0)
				* pivot
				* CFrame.Angles(math.rad(-2) * b, 0, 0)
				* pivot:Inverse()
				* cf
		elseif name == "LeftArm" or name == "RightArm" then
			local sgn = cf.X >= 0 and 1 or -1
			local shoulder = CFrame.new(cf.X, cf.Y + size.Y / 2, cf.Z)
			cf = CFrame.new(0, 0.05 * k * inhale + grow * 0.6, 0)
				* shoulder
				* CFrame.Angles(0, 0, sgn * math.rad(2) * inhale)
				* shoulder:Inverse()
				* cf
		elseif name ~= "LeftLeg" and name ~= "RightLeg" then
			cf = CFrame.new(0, rise * 0.5, 0) * cf -- trim and belt ride with the waist
		end
		p.CFrame = r.root * sway * cf
		if size ~= p.Size then
			p.Size = size
		end
	end
end

-- ---------- header ----------
local header = make("Frame", "Header", panel, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 })
local bar = box("Bar", header, 0, 0, STAGE_W, 68, Color3.new(1, 1, 1))
shade(bar, hex("3b0d17"), hex("250710"))
local barLine = box("BarLine", header, 0, 68, STAGE_W, 2, hex("7a2a36"))
-- The brand group shifts right of Roblox's top bar buttons.
local brand = box("Brand", header, 0, 0, 1200, 68)
for _, f in { { 34, 18, 62, 10 }, { 82, 40, 40, -20 }, { 118, 8, 32, 30 } } do
	icon(brand, "flower", f[1] - f[3] / 2, f[2] - f[3] / 2, f[3], { Rotation = f[4] })
end
-- The title's words stay "TEAM SETUP" (the page's name, hidden); the header shows the approved heading.
local title = label("Title", header, "TEAM SETUP", 142, 2, 600, 62, 50, D.Cream, NUNI, {
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	RichText = false,
})
local headingText = label(
	"Heading",
	brand,
	'AnimeRun - <font color="#ffb3cf">Team Select</font>',
	142,
	2,
	600,
	62,
	50,
	hex("f4e7cd"),
	NUNI
)
outline(headingText, hex("1a0408"), 2)
label("Slash", brand, "/", 724, 2, 40, 62, 48, hex("e9c9cf"), NUNI)
local crumb = label(
	"Crumb",
	brand,
	'Sakura Dojo  <font color="#ff9cc0">•</font>  Team Selection',
	776,
	9,
	410,
	48,
	27,
	hex("ffe6ec"),
	NUN,
	{
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = hex("4a1220"),
	}
)
corner(crumb, 24)
stroke(crumb, hex("d9707f"), 2)
local headerPetals = {}
for _, f in
	{
		{ 1236, 30, 46, 0 },
		{ 1290, 16, 56, -15 },
		{ 1352, 34, 42, 20 },
		{ 1408, 12, 40, 5 },
		{ 1460, 30, 30, -30 },
		{ 1640, 20, 34, 10 },
		{ 1700, 44, 26, -20 },
		{ 1770, 14, 30, 30 },
	}
do
	local p = icon(header, "flower", f[1] - f[3] / 2, f[2] - f[3] / 2, f[3], { Rotation = f[4] })
	table.insert(headerPetals, { p, f[1] - f[3] / 2, f[1] + f[3] / 2 })
end
local close = make(
	"TextButton",
	"Close",
	header,
	{ Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }
)
close.Size = UDim2.fromOffset(58, 50)
shade(close, hex("4a1220"), hex("2a0810"))
corner(close, 10)
stroke(close, hex("d9707f"), 2)
label("X", close, "X", 0, 0, 58, 50, 40, Color3.new(1, 1, 1), NUN, {
	TextXAlignment = Enum.TextXAlignment.Center,
	RichText = false,
})
local kanjiTitle = label("Kanji", header, "編\n成", 350, 206, 36, 74, 30, VERM, KALAM, {
	TextXAlignment = Enum.TextXAlignment.Center,
	LineHeight = 0.95,
	RichText = false,
}) -- 編成 = team formation; decoration only (4.45), every label stays English
-- Team Bonus heading and its View link (opens the popover).
local bonusLabel = heading("BonusLabel", header, "Team Bonus", 50, 678, 240)
local bonusButton = make("TextButton", "BonusButton", header, {
	Text = "View",
	TextColor3 = INK,
	Selectable = true,
	Position = UDim2.fromOffset(292, 680),
	Size = UDim2.fromOffset(76, 38),
})
DojoScroll.Link(bonusButton, "View")
bonusButton.LinkLabel.FontFace = KALAM
bonusButton.LinkLabel.TextColor3 = VERM

-- ---------- left parchment scroll (Makimono) ----------
local ledgerFrame = box("Ledger", panel, 0, 0, 420, DESIGN_H, nil, { ZIndex = 4 })
paper("Paper", ledgerFrame, 16, 100, 376, 956)
for i, x in { 96, 300 } do -- two leather strips hang the top rod
	box("Strip" .. i, ledgerFrame, x, 70, 12, 50, PK.Cord)
	box("Clasp" .. i, ledgerFrame, x - 3, 112, 18, 10, PK.CapDark)
end
woodRod("TopRod", ledgerFrame, 10, 86, 388, 22, false)
woodRod("BottomRod", ledgerFrame, 10, 1046, 388, 26, false)
local teamPlate = box("TeamPlate", ledgerFrame, 50, 140, 318, 52, Color3.new(1, 1, 1))
paperDress(teamPlate)
heading("StatusHeading", ledgerFrame, "Team Status", 50, 226, 290)
local statusIcon = icon(ledgerFrame, "check", 52, 279, 36)
icon(ledgerFrame, "members", 54, 317, 36)
label("MembersWord", ledgerFrame, "Members", 170, 315, 160, 40, 27, INK, BODYB, { RichText = false })
icon(ledgerFrame, "cruise", 54, 357, 36)
local cruiseTotal = label("CruiseTotal", ledgerFrame, "", 104, 353, 230, 44, 27, INK, BODYB)
redSeal("StatusSeal", ledgerFrame, "桜", 334, 332, 34, KALAM)
heading("MembersHeading", ledgerFrame, "Team Members", 50, 418, 318)
for i = 1, SLOTS - 1 do
	rule("RowRule" .. i, ledgerFrame, 50, 470 + (i - 1) * 61 + 59, 318)
end
-- The Team Bonus section shows the saved Team's real bonus (4.8; the server's TeamBonus attribute).
local bonusInfo = box("Bonus", ledgerFrame, 0, 0, 420, DESIGN_H)
local bonusPill = box("Pill", bonusInfo, 50, 734, 300, 40, VERM)
corner(bonusPill, UDim.new(0.5, 0))
make("UIGradient", "Brush", bonusPill, {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.06, 0),
		NumberSequenceKeypoint.new(0.94, 0),
		NumberSequenceKeypoint.new(1, 0.35),
	}),
})
local bonusPillText = label("Text", bonusPill, "", 8, 0, 284, 40, 25, K.SealText, KALAM, {
	TextXAlignment = Enum.TextXAlignment.Center,
	RichText = false,
})
fitText(bonusPillText, textSize(KALAM, 25))
local heartIcon = icon(bonusInfo, "heart", 54, 786, 36)
local staminaLine = label("Stamina", bonusInfo, "", 104, 784, 270, 40, 27, INK, BODYB)
local cruiseIcon = icon(bonusInfo, "stamina", 54, 830, 36)
local cruiseLine = label("Cruise", bonusInfo, "", 104, 828, 270, 40, 27, INK, BODYB)
local noneTitle = label("NoneTitle", bonusInfo, "No team bonus", 54, 736, 300, 40, 29, INK, KALAM, { RichText = false })
local noneSub = label("NoneSub", bonusInfo, "", 54, 778, 300, 34, 23, K.Muted, BODYB, { RichText = false })
local noneHint = label("NoneHint", bonusInfo, "", 54, 812, 310, 34, 20, K.Muted, BODY, { RichText = false })
rule("BonusRule", ledgerFrame, 50, 884, 318)

-- Footer (its name and children stay): Team 1 and its status, the count; the count bar is hidden (follows the draft).
local footer = make("Frame", "Footer", panel, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
label("TeamName", footer, "Team 1", 72, 140, 280, 52, 30, INK, KALAM, { RichText = false })
local status =
	label("Status", footer, "Ready", 104, 277, 264, 40, 27, READY, BODYB, { RichText = false, TextWrapped = true })
fitText(status, textSize(BODYB, 27))
local count = label("Count", footer, "", 104, 315, 64, 40, 27, INK, BODYB, { RichText = false })
local progress = make("Frame", "Progress", footer, { BackgroundTransparency = 1, Visible = false })
local fill = make("Frame", "Fill", progress, { BackgroundColor3 = VERM, BorderSizePixel = 0 })
-- The top-centre slot dots went with T2 (the scroll lists the slots); kept hidden, still following the draft.
local dots = make("Frame", "Dots", panel, { BackgroundTransparency = 1, Visible = false })
for n = 1, SLOTS do
	make("Frame", "Dot" .. n, dots, { BackgroundColor3 = VERM })
end

-- Team Members rows: portrait, numbered seal, name, rarity, cruise; a tap picks that slot.
local ledger =
	make("Frame", "LedgerRows", panel, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
local rows = {}
for n = 1, SLOTS do
	local r = make("TextButton", "Row" .. n, ledger, {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Selectable = true,
		Position = UDim2.fromOffset(50, 470 + (n - 1) * 61),
		Size = UDim2.fromOffset(318, 56),
	})
	local pick = box("Pick", r, -4, 0, 326, 56, VERM, { BackgroundTransparency = 0.88, Visible = false })
	corner(pick, 6)
	box("Bar", pick, 0, 0, 4, 56, VERM)
	local portrait =
		picture("Portrait", r, "", 0, 0, 58, 56, { BackgroundTransparency = 0, BackgroundColor3 = PK.MountDark })
	corner(portrait, 7)
	stroke(portrait, RIM, 1.5)
	local seal = redSeal("Seal", r, tostring(n), 70, 12, 32)
	rows[n] = {
		Button = r,
		Pick = pick,
		Seal = seal,
		Portrait = portrait,
		Name = label(
			"Name",
			r,
			"",
			114,
			-2,
			204,
			34,
			26,
			INK,
			KALAM,
			{ RichText = false, TextTruncate = Enum.TextTruncate.AtEnd }
		),
		Rarity = label("Rarity", r, "", 114, 32, 100, 22, 17, K.Muted, BODYB, { RichText = false }),
		Cruise = label("Cruise", r, "", 196, 32, 122, 22, 17, INK, BODYB, {
			RichText = false,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	}
end

-- Quick Setup and Deploy at the scroll's foot.
local quick = make("TextButton", "QuickSetup", panel, {
	Text = "Quick Setup",
	TextColor3 = INK,
	FontFace = KALAM,
	Position = UDim2.fromOffset(24, 936),
	Size = UDim2.fromOffset(172, 68),
	ZIndex = 6,
})
paperDress(quick)
pad(quick, 42, 6)
fitText(quick, textSize(KALAM, 25))
icon(quick, "bolt", -32, 18, 32)
local deploy = make("TextButton", "Deploy", panel, {
	Text = "Deploy",
	TextColor3 = VERM,
	FontFace = KALAM,
	TextSize = textSize(KALAM, 32),
	Position = UDim2.fromOffset(206, 936),
	Size = UDim2.fromOffset(178, 68),
	ZIndex = 6,
})
paperDress(deploy, nil, nil, VERM)
pad(deploy, 30, 0)
label("Arrow", deploy, "▶", -18, 0, 30, 68, 26, VERM, NUN, { RichText = false })
redSeal("Seal", deploy, "出", 120, -12, 30, KALAM) -- the primary's seal, like 選 on Summon's Details

-- ---------- the altars' 2D layer: tap areas, pedestals, nameplates, badges ----------
local altarsFrame = box("Altars", panel, 0, 0, STAGE_W, DESIGN_H, nil, { ZIndex = 2 })
local altars = {}
for n = 1, SLOTS do
	local s, hit = GEO[n], HIT[n]
	local hx, hy = hit[1], hit[2]
	local b = make("TextButton", "Altar" .. n, altarsFrame, {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Selectable = true,
		Position = UDim2.fromOffset(hx, hy),
		Size = UDim2.fromOffset(hit[3], hit[4]),
		ZIndex = n == 1 and 3 or 2, -- the centre altar stands in front
	})
	-- A full-stage viewport with the plate's camera, holding this altar and its member only.
	local view = make("ViewportFrame", "Pedestal", b, {
		BackgroundTransparency = 1,
		Active = false,
		Position = UDim2.fromOffset(-hx, CAM.cy - VIEW_HALF - hy),
		Size = UDim2.fromOffset(2 * CAM.cx, 2 * VIEW_HALF),
		Ambient = Color3.fromRGB(130, 96, 100),
		LightColor = Color3.fromRGB(255, 222, 196),
		LightDirection = Vector3.new(0.55, -0.75, -1),
		ZIndex = 1,
	})
	local world = make("WorldModel", "World", view) -- the altar and the member, as the approved draft
	local camera = make("Camera", "Camera", view, { FieldOfView = math.deg(2 * math.atan(VIEW_HALF / CAM.f)) })
	camera.CFrame = CFrame.lookAt(Vector3.new(0, CAM.h, 0), Vector3.new(0, CAM.h, -1))
	view.CurrentCamera = camera
	local function at(x, y)
		return x - hx, y - hy
	end
	local yaw = yawOf(s)
	local top = s.hb + s.ht
	-- Where the badge and the Selected plate sit: slot 1 on its top's front edge, slots 2 and 3 on their front face.
	local ax, ay
	if n == 1 then
		ax, ay = project(0, top, s.Z + s.rt * AP)
		ay -= 16
	else
		local a = s.rt * AP
		ax, ay = project(s.X + math.sin(yaw) * a, s.hb + s.ht * 0.5, s.Z + math.cos(yaw) * a)
	end
	ax, ay = at(ax, ay)
	-- The member's middle: the "+" of an empty altar and the fly-in's landing.
	local mx, my = project(s.X, top + 2.5 * s.scale, s.Z)
	mx, my = at(mx, my)
	if n == 1 then -- the sakura emblem on the centre altar's front
		local ex, ey = project(0, s.hb * 0.5, s.Z + s.rb * AP)
		ex, ey = at(ex, ey)
		icon(b, "flower", ex - 22, ey - 22, 44, { Name = "Emblem", ZIndex = 2 })
	end
	-- Nameplate: dark lacquer with gold (the centre one pink with a star), name, rarity, relic and Sidekick icons.
	local pl = PLATES[n]
	local px, py = at(pl[1], pl[2])
	local pw, ph = pl[3], pl[4]
	local centre = n == 1
	local nameplate = box("Nameplate", b, px, py, pw, ph, nil, { ZIndex = 4, Visible = false })
	if centre then
		local halo = box("Halo", nameplate, -8, -8, pw + 16, ph + 16, hex("ff5a8a"), { BackgroundTransparency = 0.82 })
		corner(halo, 16)
	end
	local face = box("Face", nameplate, 0, 0, pw, ph, Color3.new(1, 1, 1), { BackgroundTransparency = 0.05 })
	shade(face, hex("2e0d12"), hex("1b0609"))
	corner(face, 10)
	stroke(face, centre and hex("ff9cc0") or hex("e2b64a"), 3)
	local tx = centre and 64 or 18
	if centre then
		icon(face, "star", 12, 9, 44)
	end
	local gearSize = centre and 58 or 52
	local plateName = label(
		"PlateName",
		face,
		"",
		tx,
		centre and 2 or 1,
		pw - tx - 2 * gearSize - 20,
		centre and 44 or 34,
		centre and 40 or 30,
		Color3.new(1, 1, 1),
		NUN,
		{
			RichText = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}
	)
	outline(plateName, hex("0a0204"), 1.5)
	fitText(plateName, centre and 40 or 30)
	local plateRarity = label(
		"PlateRarity",
		face,
		"",
		tx,
		centre and 42 or 32,
		200,
		centre and 32 or 26,
		centre and 28 or 22,
		RAR_DARK.Common,
		NUN,
		{ RichText = false }
	)
	-- Number badge (2, 3; slot 1's "1" while another altar is picked): the SlotLabel keeps its words "SLOT n".
	local sealGlow =
		box("SealGlow", b, ax - 40, ay - 36, 80, 72, hex("ffb34a"), { BackgroundTransparency = 0.8, ZIndex = 3 })
	corner(sealGlow, 20)
	local slotLabel = label("SlotLabel", b, "SLOT " .. n, ax - 26, ay - 24, 52, 48, 38, hex("ffd26a"), NUM, {
		TextTransparency = 1,
		RichText = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = 4,
	})
	shade(slotLabel, hex("4a1a0e"), hex("2a0c06"))
	corner(slotLabel, 10)
	stroke(slotLabel, hex("e7b552"), 3)
	local number = label("Number", slotLabel, tostring(n), 0, 0, 52, 48, 38, hex("ffd26a"), NUM, {
		TextXAlignment = Enum.TextXAlignment.Center,
		RichText = false,
	})
	outline(number, hex("3a1000"), 1.5)
	-- The picked altar's "n Selected" plate (until the owner rules on the picked look, 4.45).
	local pw2 = centre and 292 or 236
	local selectedPlate = box("SelectedPlate", b, ax - pw2 / 2, ay - 28, pw2, 56, nil, { ZIndex = 5, Visible = false })
	local plateGlow =
		box("Glow", selectedPlate, -14, -8, pw2 + 28, 72, hex("ff6a3a"), { BackgroundTransparency = 0.75 })
	corner(plateGlow, 16)
	local plateFace = box("Face", selectedPlate, 0, 0, pw2, 56, Color3.new(1, 1, 1))
	shade(plateFace, hex("fff4dc"), hex("efd8ae"))
	corner(plateFace, 8)
	stroke(plateFace, hex("c98a3a"), 3)
	local no = label("No", plateFace, tostring(n), 8, 8, 40, 40, 32, Color3.new(1, 1, 1), NUM, {
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = hex("b0202a"),
		RichText = false,
	})
	corner(no, 7)
	label("Word", plateFace, "Selected", 56, 0, pw2 - 112, 56, centre and 36 or 30, hex("2a0a08"), NUNI, {
		TextXAlignment = Enum.TextXAlignment.Center,
		RichText = false,
	})
	local sakuraSeal = label("Seal", plateFace, "桜", pw2 - 48, 9, 38, 38, 27, hex("c2222c"), NUN, {
		TextXAlignment = Enum.TextXAlignment.Center,
		RichText = false,
	})
	corner(sakuraSeal, 4)
	stroke(sakuraSeal, hex("c2222c"), 2)
	-- Empty altar: a glowing "+" and "Add Character".
	local plus = label("Plus", b, "+", mx - 60, my - 70, 120, 120, 110, hex("ffd26a"), NUN, {
		TextXAlignment = Enum.TextXAlignment.Center,
		RichText = false,
		ZIndex = 4,
	})
	outline(plus, hex("ff6a1a"), 3)
	local add = label("Add", b, "Add Character", mx - 130, my + 44, 260, 34, centre and 30 or 26, hex("fff0dc"), NUN, {
		TextXAlignment = Enum.TextXAlignment.Center,
		RichText = false,
		ZIndex = 4,
	})
	outline(add, hex("1a0408"), 2)
	-- Remove: a paper slip under the nameplate, only on the picked altar holding a member.
	local remove = make("TextButton", "Remove", b, {
		Text = "Remove",
		TextColor3 = VERM,
		FontFace = KALAM,
		TextSize = textSize(KALAM, 22),
		Position = UDim2.fromOffset(px + pw - 124, py + ph + 8),
		Size = UDim2.fromOffset(124, 42),
		Visible = false,
		ZIndex = 6,
	})
	paperDress(remove, nil, nil, VERM, 2)
	altars[n] = {
		Button = b,
		View = view,
		World = world,
		Edges = {},
		Geo = s,
		Nameplate = nameplate,
		PlateFace = face,
		PlateName = plateName,
		PlateRarity = plateRarity,
		GearY = (ph - gearSize) / 2,
		GearSize = gearSize,
		SlotLabel = slotLabel,
		Glow = sealGlow,
		SelectedPlate = selectedPlate,
		-- Hidden since T2 (the scroll lists the member); the Portrait is the fly-in's target on the figure.
		Portrait = picture("Portrait", b, "", mx - 30, my - 30, 60, 60, { Visible = false, ZIndex = 4 }),
		Name = label("Name", b, "", 0, 0, 10, 10, 10, D.Cream, NUN, { Visible = false, RichText = false }),
		Info = label("Info", b, "", 0, 0, 10, 10, 10, D.Gold, NUN, { Visible = false, RichText = false }),
		Plus = plus,
		Add = add,
		Remove = remove,
	}
end

-- ---------- roster handscroll: tabs, search, sort, parchment cards ----------
local tray = make("Frame", "Tray", panel, {
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Position = UDim2.fromOffset(TRAY_X, TRAY_Y),
	ZIndex = 4,
})
local paperStrip = paper("Paper", tray, 24, 86, 1470, 306)
local rollers =
	{ woodRod("LeftRoller", tray, 8, 76, 28, 326, true), woodRod("RightRoller", tray, 1482, 76, 28, 326, true) }
local tabs = box("Tabs", tray, 32, 14, 520, 64, nil, { ZIndex = 5 })
local tabButtons = {}
for i, t in { { "Characters", "person", 0, 258 }, { "Sidekicks", "fox", 274, 238 } } do
	local b = make("TextButton", t[1], tabs, {
		Text = t[1],
		TextColor3 = INK,
		FontFace = KALAM,
		TextSize = textSize(KALAM, 32),
		Position = UDim2.fromOffset(t[3], 0),
		Size = UDim2.fromOffset(t[4], 64),
	})
	paperDress(b, PK.Paper, PK.Paper)
	pad(b, 56, 0)
	icon(b, t[2], i == 1 and -30 or -34, i == 1 and 13 or 12, i == 1 and 38 or 40)
	tabButtons[i] = b
end
local search = make("TextBox", "Search", tray, {
	ClearTextOnFocus = false,
	PlaceholderText = "Search character...",
	PlaceholderColor3 = K.Muted,
	Text = "",
	TextColor3 = INK,
	FontFace = BODY,
	TextSize = textSize(BODY, 25),
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(581, 18),
	Size = UDim2.fromOffset(553, 54),
	ZIndex = 5,
})
paperDress(search)
pad(search, 70, 10)
icon(search, "search", -52, 9, 36)
local sortMode = RosterCard.Sorts[1]
local sortButton = make("TextButton", "Sort", tray, {
	Text = "Sort: " .. sortMode,
	TextColor3 = INK,
	FontFace = KALAM,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(1172, 18),
	Size = UDim2.fromOffset(324, 54),
	ZIndex = 5,
})
paperDress(sortButton)
pad(sortButton, 70, 40)
fitText(sortButton, textSize(KALAM, 28))
icon(sortButton, "sort", -50, 9, 36)
label("Chevron", sortButton, "›", 0, 2, 30, 50, 44, INK, NUN, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 36, 0, 2),
	Rotation = 90,
	TextXAlignment = Enum.TextXAlignment.Center,
	RichText = false,
})
local roster = make("ScrollingFrame", "Roster", tray, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(44, 104),
	Size = UDim2.fromOffset(1430, 252),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = RIM,
	HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	ZIndex = 5,
})
make("UIListLayout", "Layout", roster, {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Top,
	Padding = UDim.new(0, CARD_GAP),
})
make("UIPadding", "Pad", roster, { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 8) })

-- ---------- popovers on paper slips: the team bonus, and the unsaved-draft question ----------
local popover = make("Frame", "BonusPopover", panel, {
	Visible = false,
	ZIndex = 20,
	Position = UDim2.fromOffset(404, 640),
	Size = UDim2.fromOffset(340, 156),
})
paperDress(popover, nil, nil, RIM, 2)
local bonusName = label("Name", popover, "", 16, 12, 308, 36, 26, VERM, KALAM, { RichText = false })
fitText(bonusName, textSize(KALAM, 26))
local bonusEffect =
	label("Effect", popover, "", 16, 52, 308, 54, 22, INK, BODYB, { RichText = false, TextWrapped = true })
local bonusTotal = label("Total", popover, "", 16, 112, 308, 30, 22, INK, BODYB, { RichText = false })
-- While the question shows, a see-through blocker under it takes every tap on the page behind.
local confirmBlocker = make("Frame", "ConfirmBlocker", panel, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Active = true,
	Visible = false,
	ZIndex = 29,
})
local confirm =
	make("Frame", "ConfirmClose", panel, { Visible = false, ZIndex = 30, Size = UDim2.fromOffset(440, 184) })
confirm:GetPropertyChangedSignal("Visible"):Connect(function()
	confirmBlocker.Visible = confirm.Visible
end)
paperDress(confirm, nil, nil, RIM, 3)
label("Question", confirm, "Deploy your changes?", 20, 22, 400, 50, 32, INK, MARKER, {
	TextXAlignment = Enum.TextXAlignment.Center,
	RichText = false,
})
local confirmDeploy = make("TextButton", "Deploy", confirm, {
	Text = "Deploy",
	TextColor3 = VERM,
	FontFace = KALAM,
	TextSize = textSize(KALAM, 28),
	Position = UDim2.fromOffset(40, 100),
	Size = UDim2.fromOffset(170, 58),
	ZIndex = 31,
})
paperDress(confirmDeploy, nil, nil, VERM)
local confirmDiscard = make("TextButton", "Discard", confirm, {
	Text = "Discard",
	TextColor3 = INK,
	FontFace = KALAM,
	TextSize = textSize(KALAM, 28),
	Position = UDim2.fromOffset(230, 100),
	Size = UDim2.fromOffset(170, 58),
	ZIndex = 31,
})
paperDress(confirmDiscard)

for _, b in { quick, deploy, sortButton, confirmDeploy, confirmDiscard, table.unpack(tabButtons) } do
	hoverable(b)
end

-- State: the draft (slot -> id or nil), the picked altar, the picked card (character id or Sidekick entry).
local draft = {}
local selected = nil
local chosen = nil
local chosenSidekick = nil
local tab = "Characters"
local busy = false
local render -- set below
local figureOn -- set below

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or READY
	statusIcon.Visible = text == "Ready" or text == "Deployed" or text == "Sidekick equipped"
end

local function saved()
	local out = {}
	for i, id in SlotPicker.Team() do
		out[i] = id ~= "" and id or nil
	end
	return out
end
local function list(t)
	local out = {}
	for i = 1, SIZE do
		if t[i] then
			table.insert(out, t[i])
		end
	end
	return out
end
local function filled()
	return #list(draft)
end
-- Slot by slot: a gap the altars show (a member moved to slot 3) is a change too; Deploy closes it up.
local function differs(a, b)
	for i = 1, SIZE do
		if a[i] ~= b[i] then
			return true
		end
	end
	return false
end
local function dirty()
	return differs(draft, saved())
end
local base = {} -- the saved Team the open draft started from
-- The draft slot holding `id` (the draft may have gaps, so not table.find).
local function slotOf(id)
	for i = 1, SIZE do
		if draft[i] == id then
			return i
		end
	end
	return nil
end
local openCount = 0 -- each open; a delayed close of an earlier open does nothing

-- The page's parts that ink in when it opens, and the stage's (4.45 motion; reduced effects: fades only).
local scrollItems = { ledgerFrame, footer, ledger, kanjiTitle, bonusLabel, bonusButton, quick, deploy }
local stageItems = { close }
for _, a in altars do
	table.insert(stageItems, a.SlotLabel)
end
local trayItems = { tabs, sortButton, search }

-- Layout: Fit scales the design canvas to the screen's height; W is the screen's width in design px. The scroll is
-- fixed at the left, the stage centres right of it (clamped so the plate covers the screen where it can), Close and
-- Sort follow the right edge, the roster takes the width.
local trayFull = UDim2.new() -- the tray's unrolled size (the open animation grows it to this)
local W = STAGE_W
local function layout()
	local size = root.AbsoluteSize
	if size.Y <= 0 or size.X <= 0 then
		return
	end
	local k = size.Y / DESIGN_H
	fit.Scale = k
	W = size.X / k
	panel.Size = UDim2.fromOffset(W, DESIGN_H)
	local spare = W - STAGE_W
	local ox = math.clamp(math.floor((SCROLL_R + W) / 2 - CAM.cx + 0.5), math.min(0, spare), math.max(0, spare))
	for _, f in { stage, altarsFrame, petals } do
		f.Position = UDim2.fromOffset(ox, 0)
	end
	local left, right = ox > 0, ox + STAGE_W < W
	plateFade.Enabled = left or right
	plateFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, left and 1 or 0),
		NumberSequenceKeypoint.new(0.06, 0),
		NumberSequenceKeypoint.new(0.94, 0),
		NumberSequenceKeypoint.new(1, right and 1 or 0),
	})
	-- Header: the bar spans the width; the brand starts right of Roblox's top bar buttons; Close at the right.
	bar.Size, barLine.Size = UDim2.fromOffset(W, 68), UDim2.fromOffset(W, 2)
	local inset = GuiService.TopbarInset
	local shift = inset.Max.X > 0 and math.max(0, inset.Min.X / k - 16) or 0
	brand.Position = UDim2.fromOffset(shift, 0)
	title.Position = UDim2.fromOffset(142 + shift, 2)
	close.Position = UDim2.fromOffset(W - 77, 9)
	for _, p in headerPetals do
		p[1].Visible = p[3] < W - 100 and p[2] > 776 + crumb.Size.X.Offset + shift + 10
	end
	-- Roster handscroll: its paper, right roller, search and sort follow the width.
	local tw = W - TRAY_X - 10
	tray.Size = UDim2.fromOffset(tw, DESIGN_H - TRAY_Y)
	trayFull = tray.Size
	paperStrip.Size = UDim2.fromOffset(tw - 50, 306)
	rollers[2].Position = UDim2.fromOffset(tw - 38, 76)
	roster.Size = UDim2.fromOffset(tw - 90, 252)
	local sortW = W >= 1800 and 324 or 250
	local sortX = tw - 24 - sortW
	sortButton.Position, sortButton.Size = UDim2.fromOffset(sortX, 18), UDim2.fromOffset(sortW, 54)
	search.Size = UDim2.fromOffset(math.max(150, sortX - 581 - 20), 54)
	-- The question centres over the stage.
	confirm.Position = UDim2.fromOffset(math.floor((SCROLL_R + W) / 2 - 220), 380)
end

local function percent(multi)
	return math.floor((multi - 1) * 100 + 0.5)
end
local function drawBonus()
	local kind, seriesId = string.match(player:GetAttribute("TeamBonus") or "", "^(%a+):(.+)$")
	local series = seriesId and SeriesCatalog.Get(seriesId)
	local has = series ~= nil and (kind == "Preset" or kind == "Series")
	if series and kind == "Preset" then
		bonusName.Text = "★ " .. string.upper(series.Preset.Name)
		bonusEffect.Text = string.format(
			"+%d%% STAMINA, +%d%% SPEED",
			percent(StaminaConfig.TEAM_BONUS.Preset),
			percent(RaceConfig.PRESET_CRUISE)
		)
	elseif series and kind == "Series" then
		bonusName.Text = string.upper(series.Name)
		bonusEffect.Text = string.format("+%d%% STAMINA", percent(StaminaConfig.TEAM_BONUS.Series))
	else
		bonusName.Text = "No team bonus"
		bonusEffect.Text = string.format("3 of one series: +%d%% stamina", percent(StaminaConfig.TEAM_BONUS.Series))
	end
	local total, members = 0, 0
	for n, id in saved() do
		local spec = CharacterCatalog.Get(id)
		local seconds = tonumber(player:GetAttribute("TeamStamina" .. n)) or (spec and StaminaConfig.Seconds(spec)) or 0
		total += math.round(seconds * 10) / 10
		members += 1
	end
	bonusTotal.Text = string.format("Total %.1f s", total)
	-- The scroll's Team Bonus section: the same bonus, the preset or series name in the red brush pill.
	bonusPill.Visible, heartIcon.Visible, staminaLine.Visible = has, has, has
	cruiseIcon.Visible = has and kind == "Preset"
	cruiseLine.Visible = cruiseIcon.Visible
	noneTitle.Visible, noneSub.Visible, noneHint.Visible = not has, not has, not has
	if has then
		bonusPillText.Text = kind .. ": " .. (kind == "Preset" and series.Preset.Name or series.Name)
		staminaLine.Text =
			string.format('Stamina <font color="#2a8a3a">+%d%%</font>', percent(StaminaConfig.TEAM_BONUS[kind]))
		cruiseLine.Text = string.format('Cruise <font color="#2a6ad0">×%s</font>', tostring(RaceConfig.PRESET_CRUISE))
	else
		noneSub.Text = members < SLOTS and "Only full teams of 3" or "Mixed series"
		noneHint.Text = string.format("3 of one series: Stamina +%d%%", percent(StaminaConfig.TEAM_BONUS.Series))
	end
end

-- Puts character `id` on draft slot `slot` (nil: takes it off); a member on another slot swaps there.
local function place(slot, id)
	if id then
		for i = 1, SIZE do
			if draft[i] == id then
				draft[i] = draft[slot]
			end
		end
	end
	draft[slot] = id
end

-- The portrait flies from a roster card onto its altar's member, then the altar's ring pulses (4.45 placement).
-- Where a card's art is now (read before a render redraws the roster).
local function artSnapshot(card)
	local art = card and card:FindFirstChild("Art")
	if not (art and art:IsA("ImageLabel") and art.Image ~= "") then
		return nil
	end
	return { Image = art.Image, Position = art.AbsolutePosition, Size = art.AbsoluteSize }
end
local function landed(slot)
	UiMotion.Pop(altars[slot].Nameplate, 0.12)
	UiMotion.Pop(rows[slot].Portrait, 0.08)
end
local function flyIn(from, slot)
	local a = altars[slot]
	if not from or UiMotion.Reduced() then
		landed(slot)
		return
	end
	local inset = GuiService:GetGuiInset().Y -- RacerTeam ignores the inset; AbsolutePosition does not
	local ghost = make("ImageLabel", "Fly", root, {
		BackgroundTransparency = 1,
		Image = from.Image,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(from.Position.X, from.Position.Y + inset),
		Size = UDim2.fromOffset(from.Size.X, from.Size.Y),
		ZIndex = 50,
	})
	local target = a.Portrait
	local t = UiMotion.Create(ghost, FLY, {
		Position = UDim2.fromOffset(target.AbsolutePosition.X, target.AbsolutePosition.Y + inset),
		Size = UDim2.fromOffset(target.AbsoluteSize.X, target.AbsoluteSize.Y),
		ImageTransparency = 0.6,
	})
	t.Completed:Connect(function()
		ghost:Destroy()
		landed(slot)
	end)
	t:Play()
end

-- An altar's ring: brighter while picked, else gold-orange.
local function paintEdges(slot)
	local a = altars[slot]
	for _, p in a.Edges do
		p.Color = selected == slot and RING:Lerp(Color3.new(1, 1, 1), 0.45) or RING
	end
end
local function pulseEdges(slot, delay)
	task.delay(delay or 0, function()
		for _, p in altars[slot].Edges do
			p.Color = D.Sakura
		end
		task.delay(0.3, function()
			paintEdges(slot)
		end)
	end)
end

local function selectSlot(slot)
	selected = slot
	if chosen and slot then
		local from = artSnapshot(roster:FindFirstChild(chosen))
		local here = draft[slot] == chosen
		place(slot, not here and chosen or nil)
		chosen, selected = nil, nil -- placed: the next tap on this altar selects it again
		render()
		if not here then
			flyIn(from, slot)
			pulseEdges(slot, 0.35)
			UiFeedback.Play("Equip", altars[slot].Button)
		end
		return
	end
	if chosenSidekick and slot and draft[slot] then
		-- Sidekicks tab: equip on that member at once (SidekickEquip; not part of the draft).
		local entry = chosenSidekick
		chosenSidekick = nil
		local ok, done, message = pcall(function()
			return remotes:WaitForChild("SidekickEquip"):InvokeServer(draft[slot], entry)
		end)
		setStatus(
			ok and done and "Sidekick equipped" or tostring(ok and message or "Connection error"),
			not (ok and done) and VERM or nil
		)
		UiFeedback.Play((ok and done) and "Equip" or "Denied", altars[slot].Button)
	end
	render()
end

local function deployDraft(thenClose)
	if busy then
		return
	end
	local team = list(draft)
	if #team == 0 then
		setStatus("Your Team needs at least 1 character", VERM)
		UiFeedback.Play("Denied", deploy)
		return
	end
	busy = true
	local ok, done, message = pcall(function()
		return remotes:WaitForChild("SetTeam"):InvokeServer(team)
	end)
	busy = false
	if not (ok and done) then
		setStatus(ok and tostring(message or "Try again") or "Connection error", VERM)
		UiFeedback.Play("Denied", deploy)
		confirm.Visible = false
		return
	end
	-- Saved: the three altars fire together, then the page closes.
	UiFeedback.Play("Equip", deploy)
	for n = 1, SLOTS do
		pulseEdges(n, (n - 1) * 0.08)
		if draft[n] then
			task.delay((n - 1) * 0.08, function()
				landed(n)
			end)
		end
	end
	-- The draft is now what the server saved (gaps closed up), so the Team change that follows is not "unsaved"
	draft, base = table.clone(team), table.clone(team)
	confirm.Visible = false
	setStatus("Deployed")
	if thenClose ~= false then
		local this = openCount
		task.delay(UiMotion.Reduced() and 0 or 0.8, function()
			if openCount == this and panel.Visible then
				PanelSwitch.ForceClose("Team")
			end
		end)
	end
end

local function applySearch()
	local query = string.lower(search.Text)
	for _, card in roster:GetChildren() do
		if card:IsA("GuiButton") then
			card.Visible = query == ""
				or string.find(string.lower(card:GetAttribute("SearchName") or ""), query, 1, true) ~= nil
		end
	end
end

-- Marks, strokes and seals follow the draft in place; the cards are rebuilt only when what they list changes.
local rosterKey = nil
local gearKey = nil -- the gear the Characters cards show; a change redraws their icons in place
local views = nil -- RosterCard.Views for the render under way (four JSON decodes, once)
local function markRoster()
	for _, card in roster:GetChildren() do
		if not card:IsA("GuiButton") then
			continue
		end
		local edge = card.Stroke
		if tab == "Characters" then
			local slot = slotOf(card.Name)
			-- The Badge keeps the words "TEAM n" (green) for the code that reads it; the slot seal shows the number.
			card.Badge.Text = slot and ("TEAM " .. slot) or ""
			card.SlotSeal.Visible = slot ~= nil
			card.SlotSeal.Text = slot and tostring(slot) or ""
			card.Member.Visible = slot ~= nil
			local on = card.Name == chosen
			edge.Color, edge.Thickness = on and VERM or RIM, on and 3 or 1.5
		else
			local spec = SidekickConfig.Get(card:GetAttribute("SidekickId"))
			edge.Color = card.Name == chosenSidekick and VERM or SidekickView.RarityColor(spec and spec.Rarity)
		end
	end
end
local function ownedKey()
	local data = player:FindFirstChild("GachaData")
	local ids = {}
	for _, entry in data and data:GetChildren() or {} do
		table.insert(ids, entry.Name)
	end
	table.sort(ids)
	return table.concat(ids, ",")
end
-- A parchment card: thin ink rim, rarity colour band, Kalam name, Titillium details.
local function paperCard(name, order)
	local card = make("TextButton", name, roster, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	shade(card, K.Cream, PK.PaperShade)
	corner(card, 8)
	stroke(card, RIM, 1.5, "Stroke")
	return card
end
local function rarityStrip(card, color)
	box("RarityStrip", card, 0, 128, CARD_W, 5, color, { ZIndex = 3 })
end
local function drawRoster()
	-- Gear lives on the Characters cards (updated in place below); the Sidekicks cards list the bag and who wears what.
	local key = table.concat({
		tab,
		sortMode,
		ownedKey(),
		tab == "Sidekicks" and (player:GetAttribute("SidekickBag") or "") or "",
		tab == "Sidekicks" and (player:GetAttribute("SidekickGear") or "") or "",
	}, "|")
	local worn = table.concat({
		player:GetAttribute("SidekickBag") or "",
		player:GetAttribute("SidekickGear") or "",
		player:GetAttribute("RelicBag") or "",
		player:GetAttribute("RelicGear") or "",
	}, "|")
	if key == rosterKey then
		if tab == "Characters" and worn ~= gearKey then
			gearKey = worn
			for _, card in roster:GetChildren() do
				if card:IsA("GuiButton") then
					RosterCard.Gear(card, card.Name, player, 6, 34, views)
				end
			end
		end
		markRoster()
		return
	end
	rosterKey, gearKey = key, worn
	for _, child in roster:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if tab == "Characters" then
		for order, spec in RosterCard.Owned(player, sortMode, true) do
			local card = paperCard(spec.Id, order)
			card:SetAttribute("SearchName", spec.Name)
			local bg = RAR_BG[spec.Rarity] or RAR_BG.Common
			-- The rarity gradient sits on its own frame: a UIGradient on the art would tint the portrait too.
			local artBg = box("ArtBg", card, 0, 0, CARD_W, 128, Color3.new(1, 1, 1), { ZIndex = 2 })
			shade(artBg, bg:Lerp(Color3.new(1, 1, 1), 0.35), bg)
			picture("Art", card, Components.PortraitImage(spec) or "", 0, 0, CARD_W, 128, { ZIndex = 2 })
			rarityStrip(card, bg)
			icon(card, "star", 6, 140, 24, { ZIndex = 3 })
			label("Name", card, spec.Name, 36, 132, 130, 34, 26, INK, KALAM, {
				RichText = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 3,
			})
			label("Rarity", card, spec.Rarity, 36, 162, 130, 22, 19, RAR_CREAM[spec.Rarity] or K.Muted, BODYB, {
				RichText = false,
				ZIndex = 3,
			})
			label("Cruise", card, HudFormat.RateText(RaceConfig.Cruise(spec)), 44, 188, 120, 30, 19, INK, BODYB, {
				RichText = false,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 3,
			})
			label("Badge", card, "", 0, 0, 10, 10, 10, UiTheme.Palette.Money, NUN, {
				TextTransparency = 1,
				RichText = false,
				ZIndex = 3,
			})
			local seal = redSeal("SlotSeal", card, "", 8, 8, 34)
			seal.Visible, seal.ZIndex = false, 6
			icon(card, "check", 8, 190, 28, { Name = "Member", Visible = false, ZIndex = 3 }) -- the drawn green check
			RosterCard.Gear(card, spec.Id, player, 6, 34, views)
			card.Activated:Connect(function()
				chosenSidekick = nil
				if selected then
					chosen = spec.Id
					selectSlot(selected)
					return
				end
				chosen = chosen ~= spec.Id and spec.Id or nil
				render()
				local picked = roster:FindFirstChild(spec.Id)
				if picked then
					UiMotion.Pop(picked, 0.06)
				end
			end)
		end
	else
		local gear = SidekickView.Gear(player)
		local wearer = {}
		for id, entry in gear do
			wearer[entry] = id
		end
		-- Highest rarity first, then bag order (Sort's Speed / Stamina are character stats; a Sidekick sorts by rarity).
		local bag = SidekickView.Bag(player)
		local rank = {}
		for i, row in bag do
			local spec = SidekickConfig.Get(row.Id)
			rank[row] = { table.find(GachaConfig.RARITY_ORDER, spec and spec.Rarity) or 0, i }
		end
		table.sort(bag, function(a, b)
			if rank[a][1] ~= rank[b][1] then
				return rank[a][1] > rank[b][1]
			end
			return rank[a][2] < rank[b][2]
		end)
		for order, row in bag do
			local spec = SidekickConfig.Get(row.Id)
			local card = paperCard(row.Entry, order)
			card:SetAttribute("SidekickId", row.Id)
			card:SetAttribute("SearchName", spec and spec.Name or row.Id)
			local rarityColor = SidekickView.RarityColor(spec and spec.Rarity)
			card.Stroke.Thickness = 2
			card.Stroke.Color = row.Entry == chosenSidekick and VERM or rarityColor
			SidekickView.Art(card, spec, UDim2.fromOffset(CARD_W / 2, 64), UDim2.fromOffset(120, 120))
			local who = wearer[row.Entry] and CharacterCatalog.Get(wearer[row.Entry])
			rarityStrip(card, rarityColor)
			label("Name", card, spec and spec.Name or row.Id, 10, 140, 150, 34, 24, INK, KALAM, {
				RichText = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 3,
			})
			label("Worn", card, who and ("on " .. who.Name) or "", 10, 176, 150, 26, 18, VERM, BODYB, {
				RichText = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 3,
			})
			card.Activated:Connect(function()
				chosen = nil
				chosenSidekick = chosenSidekick ~= row.Entry and row.Entry or nil
				setStatus(
					chosenSidekick and "Tap a member to equip" or (dirty() and "Unsaved changes" or "Ready"),
					chosenSidekick and INK or (dirty() and WARN or READY)
				)
				render()
			end)
		end
	end
	markRoster()
	applySearch()
end

function render()
	views = RosterCard.Views(player)
	local total = 0
	for n, a in altars do
		local id = draft[n]
		local spec = id and CharacterCatalog.Get(id)
		local isSelected = selected == n
		a.Button:SetAttribute("Selected", isSelected)
		a.Plus.Visible, a.Add.Visible = spec == nil, spec == nil
		a.Remove.Visible = isSelected and spec ~= nil
		a.SelectedPlate.Visible = isSelected
		a.SlotLabel.Visible, a.Glow.Visible = not isSelected, not isSelected
		paintEdges(n)
		-- A failed build is not retried every render; CharacterModels.Ready clears it (and ShownId) to build again.
		if a.ShownId ~= id or (spec and not a.World:FindFirstChild("Figure") and a.FailedId ~= id) then
			figureOn(a, spec)
		end
		a.Nameplate.Visible = spec ~= nil
		if spec then
			a.Portrait.Image = Components.PortraitImage(spec) or ""
			a.Name.Text = spec.Name
			a.Info.Text = string.format("%s · %s", spec.Rarity, HudFormat.RateText(RaceConfig.Cruise(spec)))
			a.PlateName.Text = spec.Name
			a.PlateRarity.Text = spec.Rarity
			a.PlateRarity.TextColor3 = RAR_DARK[spec.Rarity] or RAR_DARK.Common
			RosterCard.Gear(a.PlateFace, id, player, a.GearY, a.GearSize, views)
			total += RaceConfig.Cruise(spec)
		else
			local gearFrame = a.PlateFace:FindFirstChild("Gear")
			if gearFrame then
				gearFrame:Destroy()
			end
		end
		a.ShownId = id
		-- Its row on the scroll.
		local r = rows[n]
		r.Button:SetAttribute("Selected", isSelected)
		r.Pick.Visible = isSelected
		r.Portrait.Image = spec and Components.PortraitImage(spec) or ""
		r.Portrait.BackgroundColor3 = spec and (RAR_BG[spec.Rarity] or RAR_BG.Common) or PK.MountDark
		r.Name.Text = spec and spec.Name or "Add Character"
		r.Name.TextColor3 = spec and INK or K.Muted
		r.Rarity.Text = spec and spec.Rarity or ""
		r.Rarity.TextColor3 = spec and (RAR_CREAM[spec.Rarity] or K.Muted) or K.Muted
		r.Cruise.Text = spec and HudFormat.RateText(RaceConfig.Cruise(spec)) or ""
	end
	local n = filled()
	for i = 1, SLOTS do
		dots["Dot" .. i].BackgroundTransparency = draft[i] and 0 or 0.7
	end
	count.Text = string.format("%d / %d", n, SLOTS)
	fill.Size = UDim2.fromScale(n / SLOTS, 1)
	-- Cruise where the reference shows Lv. and Power (4.45 open question; display only, the draft's members summed).
	cruiseTotal.Text = string.format(
		'Cruise: <font family="rbxasset://fonts/families/Kalam.json" size="34">%s</font>',
		HudFormat.RateText(total)
	)
	local changed = dirty()
	-- An off button dulls its paper and ink (Ink owns the transparencies).
	for button, on in { [deploy] = changed and n > 0, [quick] = n < SLOTS } do
		button:SetAttribute("Enabled", on)
		button.BackgroundColor3 = on and Color3.new(1, 1, 1) or OFF
		button.TextColor3 = on and (button == deploy and VERM or INK) or K.Muted
	end
	if status.Text == "Ready" or status.Text == "Unsaved changes" or status.Text == "Deployed" then
		setStatus(changed and "Unsaved changes" or "Ready", changed and WARN or READY)
	end
	for i, t in tabButtons do
		local active = (i == 1) == (tab == "Characters")
		t:SetAttribute("Active", active)
		shade(t, active and PK.Paper or PK.PaperShade, active and PK.Paper or PK.MountDark)
		t.TextColor3 = active and VERM or INK
	end
	drawBonus()
	drawRoster()
end

local function tapSlot(n)
	if selected == n and not chosen and not chosenSidekick then
		selected = nil -- a second tap lets go of it
		render()
		return
	end
	UiFeedback.Play("Toggle", altars[n].Button)
	selectSlot(n)
end
for n, a in altars do
	a.Button.Activated:Connect(function()
		tapSlot(n)
	end)
	rows[n].Button.Activated:Connect(function()
		tapSlot(n) -- a scroll row picks its slot as its altar does
	end)
	local function remove()
		place(n, nil)
		selected = nil
		render()
	end
	a.Remove.Activated:Connect(remove)
	TouchTarget.Add(a.Remove, remove) -- phones: a 44 px tap area (audit 2026-11-20)
end
altars[1].Button:SetAttribute("FirstFocus", true) -- a gamepad starts on the first altar, not on Close
local function quickSetup()
	if busy or filled() >= SLOTS then
		return
	end
	busy = true
	local ok, done, ids = pcall(function()
		return remotes:WaitForChild("TeamQuickPick"):InvokeServer(list(draft))
	end)
	busy = false
	if not (ok and done and type(ids) == "table") then
		setStatus(ok and tostring(ids or "Try again") or "Connection error", VERM)
		UiFeedback.Play("Denied", quick)
		return
	end
	-- Keep each member on its altar; the new picks fill the empty altars in slot order.
	local new = {}
	for _, id in ids do
		if not slotOf(id) then
			table.insert(new, id)
		end
	end
	local delay = 0
	for i = 1, SIZE do
		if not draft[i] and #new > 0 then
			draft[i] = table.remove(new, 1)
			pulseEdges(i, delay)
			local slot = i
			task.delay(delay, function()
				landed(slot)
			end)
			delay += 0.15
		end
	end
	selected, chosen = nil, nil
	UiFeedback.Play("Equip", quick)
	render()
end
quick.Activated:Connect(quickSetup)
TouchTarget.Add(quick, quickSetup, "Y")
local function deployPressed()
	if deploy:GetAttribute("Enabled") then
		deployDraft(true)
	else
		UiFeedback.Play("Denied", deploy)
	end
end
deploy.Activated:Connect(deployPressed)
TouchTarget.Add(deploy, deployPressed, "Y")
local function confirmedDeploy()
	deployDraft(true)
end
local function discard()
	confirm.Visible = false
	draft = saved()
	PanelSwitch.ForceClose("Team")
end
confirmDeploy.Activated:Connect(confirmedDeploy)
TouchTarget.Add(confirmDeploy, confirmedDeploy, "Y")
confirmDiscard.Activated:Connect(discard)
TouchTarget.Add(confirmDiscard, discard, "Y")
local function toggleBonus()
	popover.Visible = not popover.Visible
	if popover.Visible then
		drawBonus()
		UiMotion.Pop(popover, 0.04)
	end
end
bonusButton.Activated:Connect(toggleBonus)
TouchTarget.Add(bonusButton, toggleBonus)
local function setTab(i)
	tab = i == 1 and "Characters" or "Sidekicks"
	chosen, chosenSidekick = nil, nil
	render()
end
for i, t in tabButtons do
	local function pick()
		setTab(i)
	end
	t.Activated:Connect(pick)
	TouchTarget.Add(t, pick, "Y")
end
local function closePage()
	PanelSwitch.Close("Team")
end
close.Activated:Connect(closePage)
TouchTarget.Add(close, closePage)
local function nextSort()
	sortMode = RosterCard.Sorts[table.find(RosterCard.Sorts, sortMode) % #RosterCard.Sorts + 1]
	sortButton.Text = "Sort: " .. sortMode
	render()
end
sortButton.Activated:Connect(nextSort)
TouchTarget.Add(sortButton, nextSort, "Y")
search:GetPropertyChangedSignal("Text"):Connect(applySearch)

-- An undeployed draft asks before the page closes (4.45).
PanelSwitch.SetCloseGuard("Team", function()
	if dirty() then
		confirm.Visible = true
		popover.Visible = false
		UiMotion.Pop(confirm, 0.04)
		if GuiService.SelectedObject then -- a gamepad moves onto the question
			GuiService.SelectedObject = confirmDeploy
		end
		return true
	end
	return false
end)
-- Back (gamepad B, Escape): the question or the bonus popover closes first, then the page (U6, audit 2026-11-20).
PanelSwitch.SetBack("Team", function()
	if confirm.Visible then
		confirm.Visible = false
		if GuiService.SelectedObject then
			GuiService.SelectedObject = deploy
		end
		return true
	end
	if popover.Visible then
		popover.Visible = false
		return true
	end
	return false
end)
-- L1 / R1 switch the roster's tabs while the page is open.
local TAB_ACTION = "TeamSetupTabs"
local function bumper(_, state, input)
	if state == Enum.UserInputState.Begin and not confirm.Visible then
		setTab(input.KeyCode == Enum.KeyCode.ButtonL1 and 1 or 2)
		UiFeedback.Play("TabSwitch")
	end
	return Enum.ContextActionResult.Sink
end

-- Open: the scroll's words ink in, Close and the badges fade in, the roster handscroll unrolls left to right (4.45
-- motion; reduced effects: fades only). Close: everything fades under the wash.
local trayTween = nil
local inked = false
local function openScroll()
	inked = true
	DojoScroll.Ink(scrollItems, true, 0.12)
	DojoScroll.Ink(stageItems, true, 0.3)
	DojoScroll.Ink(trayItems, true, DojoScroll.INK_AT)
	if trayTween then
		trayTween:Cancel()
	end
	if UiMotion.Reduced() then
		tray.Size = trayFull
		return
	end
	tray.Size = UDim2.fromOffset(60, trayFull.Y.Offset)
	trayTween = UiMotion.Create(
		tray,
		TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.1),
		{ Size = trayFull }
	)
	trayTween:Play()
end
local function closeScroll()
	if not inked then
		return
	end
	inked = false
	DojoScroll.Ink(scrollItems, false, 0, 0.12)
	DojoScroll.Ink(stageItems, false, 0, 0.2)
	DojoScroll.Ink(trayItems, false, 0, 0.2)
end
task.spawn(function()
	local wash = player:WaitForChild("PlayerGui"):WaitForChild("UiTransition")
	wash:GetAttributeChangedSignal("Playing"):Connect(function()
		if wash:GetAttribute("Playing") and panel.Visible then
			closeScroll()
		end
	end)
end)

-- The stage lives only while the page is open: the altar models are built on open; the altars, members and the
-- breathing loop go on close.
local breathing = nil
local stillPosed = false -- reduced effects: the members hold one still pose
local function breathe()
	local reduced = UiMotion.Reduced()
	if reduced and stillPosed then
		return
	end
	local t = os.clock()
	for _, a in altars do
		if a.Rig then
			pose(a.Rig, reduced and a.Rig.delay or t)
		end
	end
	stillPosed = reduced
end
local function buildStage()
	for _, a in altars do
		if not a.World:FindFirstChild("Altar") then
			local _, rings = buildAltar(a.World, a.Geo)
			a.Edges = rings
		end
		a.ShownId, a.FailedId = false, nil
	end
	if not breathing then
		breathing = RunService.RenderStepped:Connect(breathe)
	end
end
local function clearStage()
	if breathing then
		breathing:Disconnect()
		breathing = nil
	end
	for _, a in altars do
		for _, name in { "Figure", "Altar" } do
			local m = a.World:FindFirstChild(name)
			if m then
				m:Destroy()
			end
		end
		a.Edges, a.Rig, a.ShownId, a.FailedId = {}, nil, false, nil
	end
end

panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		openCount += 1
		rosterKey = nil
		draft, selected, chosen, chosenSidekick = saved(), nil, nil, nil
		base = saved()
		tab = "Characters"
		confirm.Visible, popover.Visible = false, false
		setStatus("Ready")
		buildStage()
		render()
		openScroll()
		ContextActionService:BindAction(TAB_ACTION, bumper, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
	else
		ContextActionService:UnbindAction(TAB_ACTION)
		UiTooltip.Hide()
		confirm.Visible = false
		clearStage()
	end
end)
player.AttributeChanged:Connect(function(attr)
	if
		panel.Visible
		and (
			attr == "Team"
			or attr == "TeamBonus"
			or attr == "SidekickGear"
			or attr == "SidekickBag"
			or attr == "RelicGear"
			or string.match(attr, "^TeamStamina%d$")
		)
	then
		if attr == "Team" then
			-- The saved Team changed under an open page (another device, a Deploy): an untouched draft follows it
			if not differs(draft, base) then
				draft = saved()
			end
			base = saved()
		end
		render()
	end
end)
task.spawn(function()
	local data = player:WaitForChild("GachaData")
	local function changed()
		if panel.Visible then
			render()
		end
	end
	data.ChildAdded:Connect(changed)
	data.ChildRemoved:Connect(changed)
	local models = ReplicatedStorage:WaitForChild("CharacterModels")
	if models:GetAttribute("Ready") ~= true then
		models:GetAttributeChangedSignal("Ready"):Wait()
	end
	-- The members built before the models arrived are placeholders: build every altar's again.
	for _, a in altars do
		a.ShownId, a.FailedId = false, nil
	end
	changed()
end)

-- The member standing on its altar as its 3D model (owner 2026-11-17: an exception to the portrait rule for Team Setup
-- only), facing the camera, in the idle stance (4.45), feet on the altar top; the breathing plays on top.
function figureOn(a, spec)
	local old = a.World:FindFirstChild("Figure")
	if old then
		old:Destroy()
	end
	a.Rig = nil
	if not spec then
		return
	end
	local ok, rig = pcall(function()
		return require(shared:WaitForChild("RunnerFactory")).build(spec.Id)
	end)
	if not ok or not rig then
		a.FailedId = spec.Id
		return
	end
	a.FailedId = nil
	rig.Name = "Figure"
	local nameTag = rig:FindFirstChild("NameLabel")
	if nameTag then
		nameTag:Destroy()
	end
	local s = a.Geo
	if s.scale ~= 1 then
		rig:ScaleTo(s.scale)
	end
	-- the rig's front is its -Z, so it turns half round from the altar's yaw to face the camera
	local face = yawOf(s) + math.pi
	rig:PivotTo(CFrame.Angles(0, face, 0))
	local box3, extents = rig:GetBoundingBox()
	local feet = Vector3.new(box3.X, box3.Y - extents.Y / 2, box3.Z)
	local rootCf = CFrame.new(s.X, s.hb + s.ht, s.Z) * CFrame.Angles(0, face, 0)
	rig:PivotTo(rig:GetPivot() + (rootCf.Position - feet))
	local r = { root = rootCf, parts = {}, delay = s.delay, k = s.scale }
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			r.parts[p] = { cf = rootCf:ToObjectSpace(p.CFrame), size = p.Size }
		end
	end
	r.torso = rig:FindFirstChild("Torso")
	applyStance(r)
	pose(r, s.delay) -- at once, so the stance shows before the next frame (and stays while reduced)
	rig.Parent = a.World
	a.Rig = r
	stillPosed = false
end

root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layout)
PanelSwitch.Register("Team", panel, D.Cyan)
layout()
