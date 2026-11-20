--!nonstrict
-- Team Select DRAFT (goal team-dojo): the redesigned screen built client-side at runtime in a Play session, for owner
-- screenshots only. Paste into Studio's execute_luau on the Client datamodel. Not a game script: it saves nothing,
-- uploads nothing and edits no script. Matches the owner reference (1920x1080 design canvas) and the approved
-- "A · Makimono" skin (artifact 894a7735). After a run: _G.TSD.build("A"|"B"), _G.TSD.mode("full"|"stage"),
-- _G.TSD.freeze(t or nil), _G.TSD.teardown(), _G.TSD.restoreOthers().

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local RaceConfig = require(Shared.RaceConfig)
local SeriesCatalog = require(Shared.SeriesCatalog)
local StaminaConfig = require(Shared.StaminaConfig)
local Portraits = require(Shared.CharacterPortraits)
local RunnerFactory = require(Shared.RunnerFactory)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

if _G.TSD and _G.TSD.teardown then
	_G.TSD.teardown()
end
local TSD = {}
_G.TSD = TSD

-- ---------- data ----------
local TEAMS = {
	A = { "leaf_hero", "leaf_avenger", "leaf_medic" },
	B = { "leaf_crow", "ds_hero", "mha_hero" },
}
local OTHERS = { "jk_strongest", "ds_flame", "sea_captain", "jk_vessel", "leaf_copycat" }
-- Relic image + Sidekick portrait per character (draft picks from RelicConfig / SidekickArt).
local RELIC = {
	talisman = "rbxassetid://112073311599626",
	nail = "rbxassetid://116058098442275",
	finger = "rbxassetid://104879331110597",
	eyes = "rbxassetid://109441811086116",
	helmet = "rbxassetid://125164800672073",
	bracelet = "rbxassetid://97483480150926",
	flask = "rbxassetid://79563216957049",
	grimoire = "rbxassetid://87657515215586",
}
local SIDE = {
	fox = "rbxassetid://123904858057635",
	crow = "rbxassetid://121367034931386",
	dogs = "rbxassetid://79265029206445",
	ant = "rbxassetid://87188552266607",
	curse = "rbxassetid://119448828185312",
}
local GEAR = {
	leaf_hero = { "eyes", "fox" },
	leaf_avenger = { "finger", "crow" },
	leaf_medic = { "flask", "fox" },
	leaf_crow = { "eyes", "crow" },
	ds_hero = { "talisman", "fox" },
	mha_hero = { "bracelet", "fox" },
	jk_strongest = { "eyes", "curse" },
	ds_flame = { "finger", "fox" },
	sea_captain = { "helmet", "fox" },
	jk_vessel = { "grimoire", "curse" },
	leaf_copycat = { "nail", "dogs" },
}
local RAR_CREAM = { -- rarity text on cream paper
	Common = Color3.fromHex("6a6a6a"),
	Uncommon = Color3.fromHex("2e9a3e"),
	Rare = Color3.fromHex("2a7ae0"),
	Epic = Color3.fromHex("8a3ad8"),
	Legendary = Color3.fromHex("c88a00"),
	Mythic = Color3.fromHex("d8204a"),
	Secret = Color3.fromHex("1a1a1a"),
}
local RAR_DARK = { -- rarity text on dark lacquer
	Common = Color3.fromHex("cfcfcf"),
	Uncommon = Color3.fromHex("7ee07e"),
	Rare = Color3.fromHex("6aaeff"),
	Epic = Color3.fromHex("c890ff"),
	Legendary = Color3.fromHex("ffcf3a"),
	Mythic = Color3.fromHex("ff86c8"),
	Secret = Color3.fromHex("f4f4f4"),
}
local RAR_BG = {
	Common = Color3.fromHex("9a9a9a"),
	Uncommon = Color3.fromHex("5ac85a"),
	Rare = Color3.fromHex("3a8ae8"),
	Epic = Color3.fromHex("9a5ae0"),
	Legendary = Color3.fromHex("e79a2a"),
	Mythic = Color3.fromHex("e23a3a"),
	Secret = Color3.fromHex("2a2a34"),
}
local function spec(id)
	return require(Shared.Characters[id])
end

-- ---------- helpers ----------
local NUN = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
local NUNI = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local NUM = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular)
local function N(class, parent, props)
	local o = Instance.new(class)
	for k, v in props or {} do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function F(parent, x, y, w, h, color, props)
	local p = { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BorderSizePixel = 0 }
	if color then
		p.BackgroundColor3 = color
	else
		p.BackgroundTransparency = 1
	end
	for k, v in props or {} do
		p[k] = v
	end
	return N("Frame", parent, p)
end
local function T(parent, text, x, y, w, h, size, color, font, props)
	local p = {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or Color3.new(1, 1, 1),
		FontFace = font or NUN,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	}
	for k, v in props or {} do
		p[k] = v
	end
	return N("TextLabel", parent, p)
end
local function I(parent, image, x, y, w, h, props)
	local p = {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Crop,
	}
	for k, v in props or {} do
		p[k] = v
	end
	return N("ImageLabel", parent, p)
end
local function corner(o, r)
	N("UICorner", o, { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 8) })
	return o
end
local function stroke(o, color, t, mode)
	N("UIStroke", o, {
		Color = color,
		Thickness = t or 2,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	return o
end
local function grad(o, c0, c1, rot, mid)
	local seq
	if mid then
		seq = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c0),
			ColorSequenceKeypoint.new(mid[1], mid[2]),
			ColorSequenceKeypoint.new(1, c1),
		})
	else
		seq = ColorSequence.new(c0, c1)
	end
	N("UIGradient", o, { Color = seq, Rotation = rot or 90 })
	return o
end
local function hex(h)
	return Color3.fromHex(h)
end
local function textStroke(o, color, t)
	N("UIStroke", o, { Color = color or Color3.new(0, 0, 0), Thickness = t or 2, Transparency = 0.35 })
	return o
end
-- Soft radial glow: stacked translucent ellipses (no image asset).
local function glow(parent, cx, cy, w, h, color, alpha, n)
	n = n or 10
	for k = 1, n do
		local s = k / n
		local g = F(parent, cx - w * s / 2, cy - h * s / 2, w * s, h * s, color, {
			BackgroundTransparency = 1 - alpha / n * 1.6,
		})
		corner(g, UDim.new(0.5, 0))
	end
end
local function seal(parent, x, y, s)
	local b = T(parent, "桜", x, y, s, s, s * 0.72, hex("c2222c"), NUN, { TextXAlignment = Enum.TextXAlignment.Center })
	corner(b, 4)
	stroke(b, hex("c2222c"), 2)
	return b
end
-- Drawn icon set (owner 2026-11-20: "draw the icons"; 256x256 transparent PNGs, uploaded).
local ICON = {
	members = "rbxassetid://120701226138389",
	cruise = "rbxassetid://90390164671669",
	check = "rbxassetid://80155502075768",
	flower = "rbxassetid://109103491597058",
	heart = "rbxassetid://121022170152825",
	bolt = "rbxassetid://125367337236897",
	stamina = "rbxassetid://90685209894294",
	pencil = "rbxassetid://126773689674292",
	person = "rbxassetid://134691081100736",
	fox = "rbxassetid://80346729214213",
	search = "rbxassetid://101694582811922",
	sort = "rbxassetid://98275488757200",
	star = "rbxassetid://138766078045247",
}
local function icon(parent, key, x, y, s, props)
	local p = { ScaleType = Enum.ScaleType.Fit, Name = "Icon_" .. key }
	for k, v in props or {} do
		p[k] = v
	end
	return I(parent, ICON[key], x, y, s, s, p)
end
-- A sakura blossom (the drawn flower icon) centred on cx, cy; `color` is unused since the art is coloured.
local function sakura(parent, cx, cy, s, _color, rot)
	return icon(parent, "flower", cx - s / 2, cy - s / 2, s, { Rotation = rot or 0 })
end
local function gem(parent, image, x, y, s, bg)
	local b = F(parent, x, y, s, s, bg or hex("3a120c"))
	corner(b, 9)
	stroke(b, hex("8a5a2a"), 2)
	grad(b, hex("6a2414"), hex("240806"), 90)
	I(b, image, 3, 3, s - 6, s - 6, { ScaleType = Enum.ScaleType.Fit })
	return b
end

-- Gradient box with a text label on top (a UIGradient on a TextLabel would tint its text too).
local function pill(parent, text, x, y, w, h, size, color, font, c0, c1, sc, st, r, props)
	local b = F(parent, x, y, w, h, Color3.new(1, 1, 1))
	grad(b, c0, c1, 90)
	corner(b, r or 10)
	if sc then
		stroke(b, sc, st or 2)
	end
	local p = { TextXAlignment = Enum.TextXAlignment.Center }
	for k, v in props or {} do
		p[k] = v
	end
	local l = T(b, text, 0, 0, w, h, size, color, font, p)
	return b, l
end

-- ---------- camera / projection matched to the plate ----------
local CAM = { f = 1870, cx = 1089, cy = 242, h = 6.52 }
local function project(x, y, z)
	return CAM.cx + CAM.f * x / -z, CAM.cy + CAM.f * (CAM.h - y) / -z
end
local SLOTS = {
	{ X = 0, Z = -35.1, rb = 5.9, rt = 4.9, hb = 0.62, ht = 0.80, scale = 1.0, delay = 0 },
	{ X = -9.37, Z = -47.5, rb = 3.5, rt = 3.1, hb = 0.30, ht = 0.30, scale = 0.905, delay = 1.12 },
	{ X = 10.26, Z = -47.5, rb = 3.5, rt = 3.1, hb = 0.30, ht = 0.30, scale = 0.905, delay = 2.24 },
}
local AP = math.cos(math.pi / 8)

-- ---------- GUI root ----------
local hidden = {}
for _, g in playerGui:GetChildren() do
	if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "TeamSelectDraft" then
		g.Enabled = false
		table.insert(hidden, g)
	end
end
local old = playerGui:FindFirstChild("TeamSelectDraft")
if old then
	old:Destroy()
end
local gui = N("ScreenGui", playerGui, {
	Name = "TeamSelectDraft",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
N("Frame", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 })
local canvas = N("Frame", gui, {
	Name = "Canvas",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundColor3 = hex("12040a"),
	BorderSizePixel = 0,
	ClipsDescendants = true,
})
local uiScale = N("UIScale", canvas, {})
local function fit()
	uiScale.Scale = gui.AbsoluteSize.Y / 1080
end
local fitConn = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local conns = { fitConn }
local layers = {}
local rigs = {}
local frozen = nil
TSD.rigs = rigs -- exposed for live tweaks and the idle-clip capture

function TSD.restoreOthers()
	for _, g in hidden do
		if g.Parent then
			g.Enabled = true
		end
	end
	hidden = {}
end
function TSD.teardown()
	for _, c in conns do
		c:Disconnect()
	end
	conns = {}
	if gui then
		gui:Destroy()
	end
	TSD.restoreOthers()
end
function TSD.freeze(t)
	frozen = t
end

-- ---------- static layers ----------
I(canvas, "rbxassetid://84852553726102", 0, 0, 1920, 1080, { Name = "Plate", ScaleType = Enum.ScaleType.Stretch })
local glowL = F(canvas, 0, 0, 1920, 1080, nil, { Name = "Glow" })
local arcL = F(canvas, 0, 0, 1920, 1080, nil, { Name = "Arcs" })
local vf = N("ViewportFrame", canvas, {
	Name = "Stage",
	Position = UDim2.fromOffset(0, CAM.cy - 838),
	Size = UDim2.fromOffset(2 * CAM.cx, 2 * 838),
	BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(130, 96, 100),
	LightColor = Color3.fromRGB(255, 222, 196),
	LightDirection = Vector3.new(0.55, -0.75, -1),
})
local cam = N("Camera", vf, { FieldOfView = math.deg(2 * math.atan(838 / CAM.f)) })
cam.CFrame = CFrame.lookAt(Vector3.new(0, CAM.h, 0), Vector3.new(0, CAM.h, -1))
vf.CurrentCamera = cam
local world = N("WorldModel", vf, {})
local ui = F(canvas, 0, 0, 1920, 1080, nil, { Name = "UI" })
layers.ui = ui

-- ring arrows: ellipse centre (1102,442), radii 555 x 149, upper arc 150..392 deg, five arrowheads
do
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
		F(arcL, mid.X, mid.Y, d.Magnitude + 2, 11, hex("ff4f8f"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rot,
			BackgroundTransparency = 1 - 0.28 * fade,
		})
		F(arcL, mid.X, mid.Y, d.Magnitude + 1, 3.2, hex("ffc3dc"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rot,
			BackgroundTransparency = 1 - fade,
		})
	end
	for _, h in { { 192, 1 }, { 234.7, -1 }, { 248.9, 1 }, { 304.5, 1 }, { 361, -1 } } do
		local a, dir = math.rad(h[1]), h[2]
		local p = P(a)
		local ang = math.deg(math.atan2(RY * math.cos(a) * dir, -RX * math.sin(a) * dir))
		-- arrowhead: two bars meeting at the tip (a filled chevron), with a soft glow copy under it
		local tip = p + Vector2.new(math.cos(math.rad(ang)), math.sin(math.rad(ang))) * 12
		for _, layer in { { 16, hex("ff4f8f"), 0.6, 34 }, { 7, hex("ffd1e4"), 0, 28 } } do
			for _, side in { -1, 1 } do
				local back = math.rad(ang + 180 + side * 32)
				local len = layer[4]
				local c = tip + Vector2.new(math.cos(back), math.sin(back)) * (len / 2 - 2)
				local bar = F(arcL, c.X, c.Y, len, layer[1], layer[2], {
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

-- ---------- 3D altars ----------
local WOOD = hex("2c0c09")
local WOOD_FACE = hex("2a0a08")
local GOLD = hex("e7b552")
local RING = hex("ffb43a") -- gold-orange ring core (owner 2026-11-20, as the reference)
local function part(parent, size, cf, color, props)
	local p = N("Part", nil, {
		Anchored = true,
		CanCollide = false,
		CastShadow = false,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end
local function octagon(parent, apothem, h, cf, color, props)
	local w = 2 * apothem
	for k = 0, 3 do
		part(parent, Vector3.new(w, h, w * math.tan(math.pi / 8)), cf * CFrame.Angles(0, k * math.pi / 4, 0), color, props)
	end
end
local function octRing(parent, apothem, y, cf, color, thick, width)
	local edge = 2 * apothem * math.tan(math.pi / 8)
	for k = 0, 7 do
		local a = k * math.pi / 4
		local c = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, y, apothem)
		part(parent, Vector3.new(edge + width * 0.83, thick, width), c, color)
	end
end
local function buildAltar(s)
	local m = N("Model", world, { Name = "Altar" })
	local yaw = math.atan2(-s.X, -s.Z)
	local cf = CFrame.new(s.X, 0, s.Z) * CFrame.Angles(0, yaw, 0)
	local ab, at = s.rb * AP, s.rt * AP
	local top = s.hb + s.ht
	octagon(m, ab + 0.06, 0.06, cf * CFrame.new(0, 0.03, 0), GOLD)
	octagon(m, ab, s.hb, cf * CFrame.new(0, s.hb / 2, 0), WOOD, { Reflectance = 0.08 })
	octagon(m, ab + 0.04, 0.07, cf * CFrame.new(0, s.hb - 0.035, 0), GOLD)
	octagon(m, at, s.ht, cf * CFrame.new(0, s.hb + s.ht / 2, 0), WOOD, { Reflectance = 0.08 })
	octagon(m, at + 0.04, 0.08, cf * CFrame.new(0, top - 0.04, 0), GOLD)
	octagon(m, at - 0.08, 0.02, cf * CFrame.new(0, top + 0.01, 0), WOOD_FACE)
	octRing(m, at * 0.86, top + 0.03, cf, RING, 0.03, s.rb > 4 and 0.16 or 0.12)
	octRing(m, at * 0.62, top + 0.03, cf, hex("ff8a1e"), 0.02, 0.06)
	-- warm light panels on the front faces
	local lamp = hex("ffd27a")
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
	return m, yaw, top
end

-- ---------- members: idle stance + breathing ----------
-- Static idle stance (owner 2026-11-20: "spread legs and arms", like the reference), applied under the breathing.
-- The rigs are 6 rigid MeshParts (no elbows or knees), so each limb turns whole about its joint. Degrees; arm values
-- are { left, right } for a little asymmetry. Live-tunable: edit _G.TSD.stance then _G.TSD.build(team).
local STANCE = { legRoll = 13, armRoll = { 15, 19 }, armFwd = { 8, 14 }, lean = 3, headTilt = 2.5 }
TSD.stance = STANCE
local function rotAbout(pt, rot)
	return CFrame.new(pt) * rot * CFrame.new(-pt)
end
-- Stance CFrame of one part in rig space (feet centre at the origin, front = -Z), applied as stance * cf.
local function stanceOf(name, cf, size, legTop)
	local A = STANCE
	local sgn = cf.X >= 0 and 1 or -1
	local i = sgn < 0 and 1 or 2
	if name == "LeftLeg" or name == "RightLeg" then
		return rotAbout(Vector3.new(cf.X, cf.Y + size.Y / 2, cf.Z), CFrame.Angles(0, 0, sgn * math.rad(A.legRoll)))
	end
	local lean = rotAbout(Vector3.new(0, legTop, cf.Z), CFrame.Angles(-math.rad(A.lean), 0, 0)) -- top toward -Z (camera)
	if name == "LeftArm" or name == "RightArm" then
		-- pivot at the arm's top inner corner (the armpit), so the arm swings out without poking above the shoulder
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
	-- re-seat: the lowest foot corner touches the altar top
	local seat = CFrame.new(0, low == math.huge and 0 or -low, 0)
	for _, info in r.parts do
		info.stance = seat * info.stance
	end
end

local function placeMember(slot, id)
	local s = SLOTS[slot]
	local _, yaw, top = buildAltar(s)
	local ok, rig = pcall(RunnerFactory.build, id)
	if not ok or not rig then
		warn("TSD: no model for", id, rig)
		return
	end
	local label = rig:FindFirstChild("NameLabel")
	if label then
		label:Destroy()
	end
	if s.scale ~= 1 then
		rig:ScaleTo(s.scale)
	end
	-- face the camera: the rig's front is its -Z (LookVector), so turn it half round from the altar's yaw
	local face = yaw + math.pi
	rig:PivotTo(CFrame.Angles(0, face, 0))
	local box, ext = rig:GetBoundingBox()
	local feet = Vector3.new(box.X, box.Y - ext.Y / 2, box.Z)
	local root = CFrame.new(s.X, top, s.Z) * CFrame.Angles(0, face, 0)
	rig:PivotTo(rig:GetPivot() + (root.Position - feet))
	rig.Parent = world
	local r = { root = root, parts = {}, delay = s.delay, k = s.scale }
	for _, p in rig:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			r.parts[p] = { cf = root:ToObjectSpace(p.CFrame), size = p.Size }
		end
	end
	r.torso = rig:FindFirstChild("Torso")
	r.head = rig:FindFirstChild("Head")
	applyStance(r)
	table.insert(rigs, r)
	return rig
end

local PERIOD = 3.4
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
		local cf, size = info.stance * info.cf, info.size -- breathing plays on top of the stance
		local name = p.Name
		if name == "Torso" then
			size = Vector3.new(size.X * (1 + 0.012 * inhale), size.Y * (1 + 0.022 * inhale), size.Z * (1 + 0.03 * inhale))
			cf = CFrame.new(0, rise + grow / 2, 0) * cf
		elseif name == "Head" then
			local neckY = torsoInfo and (torsoInfo.cf.Y + torsoInfo.size.Y / 2) or cf.Y - size.Y / 2
			local pivot = CFrame.new(cf.X, neckY, cf.Z)
			cf = CFrame.new(0, rise + grow + 0.01 * k * inhale, 0) * pivot * CFrame.Angles(math.rad(-2) * b, 0, 0) * pivot:Inverse() * cf
		elseif name == "LeftArm" or name == "RightArm" then
			local sgn = cf.X >= 0 and 1 or -1
			local shoulder = CFrame.new(cf.X, cf.Y + size.Y / 2, cf.Z)
			cf = CFrame.new(0, 0.05 * k * inhale + grow * 0.6, 0)
				* shoulder
				* CFrame.Angles(0, 0, sgn * math.rad(2) * inhale)
				* shoulder:Inverse()
				* cf
		elseif name ~= "LeftLeg" and name ~= "RightLeg" then
			cf = CFrame.new(0, rise * 0.5, 0) * cf -- trim/belt rides with the waist
		end
		p.CFrame = r.root * sway * cf
		if size ~= info.size then
			p.Size = size
		end
	end
end
table.insert(
	conns,
	RunService.RenderStepped:Connect(function()
		local t = frozen or os.clock()
		for _, r in rigs do
			pose(r, t)
		end
	end)
)

-- ---------- static UI ----------
local CREAM = hex("f4e7cd")
local INK = hex("3a1a12")
local function lacquer(o)
	grad(o, hex("2e0d12"), hex("1b0609"), 90)
	return o
end

-- header
do
	local h = F(ui, 0, 0, 1920, 68, hex("3b0d17"), { Name = "Header" })
	grad(h, hex("3b0d17"), hex("250710"), 90)
	F(ui, 0, 68, 1920, 2, hex("7a2a36"))
	sakura(h, 34, 18, 62, hex("ffb3cf"), 10)
	sakura(h, 82, 40, 40, hex("ff9cc0"), -20)
	sakura(h, 118, 8, 32, hex("ffc8dc"), 30)
	local ttl = T(h, 'AnimeRun - <font color="#ffb3cf">Team Select</font>', 142, 2, 600, 62, 50, CREAM, NUNI)
	textStroke(ttl, hex("1a0408"), 2)
	T(h, "/", 724, 2, 40, 62, 48, hex("e9c9cf"), NUNI)
	local crumb = T(h, 'Sakura Dojo  <font color="#ff9cc0">•</font>  Team Selection', 776, 9, 410, 48, 27, hex("ffe6ec"), NUN, {
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = hex("4a1220"),
	})
	corner(crumb, 24)
	stroke(crumb, hex("d9707f"), 2)
	for _, b in { { 1236, 30, 46, 0 }, { 1290, 16, 56, -15 }, { 1352, 34, 42, 20 }, { 1408, 12, 40, 5 }, { 1460, 30, 30, -30 } } do
		sakura(h, b[1], b[2], b[3], b[4] % 2 == 0 and hex("ffb3cf") or hex("ff9cc0"), b[4])
	end
	for _, b in { { 1640, 20, 34, 10 }, { 1700, 44, 26, -20 }, { 1770, 14, 30, 30 } } do
		sakura(h, b[1], b[2], b[3], hex("ff9cc0"), b[4])
	end
	pill(h, "×", 1843, 9, 58, 50, 52, Color3.new(1, 1, 1), NUN, hex("4a1220"), hex("2a0810"), hex("d9707f"), 2, 10)
end

-- Parchment scroll skin (owner 2026-11-20: "consistent with the Summon UI"): the Summon page's tokens and fonts from
-- UiTheme.Scroll / Scroll.Skins.Parchment (Client/SummonScroll + DojoScroll, Skin = "Parchment").
local K = require(Shared.UiTheme).Scroll
local PK = K.Skins.Parchment
local KALAM = K.Script -- Kalam Bold
local MARKER = K.Heading -- Permanent Marker
local BODY = K.Body -- Titillium Web
local BODYB = K.BodyBold
local PINK = K.TileInk -- dark ink on paper
local RIM = K.PaperRim -- #3A2A20 ink-brush rim
local VERM = K.Accent -- vermilion
local function paperFill(o, top, bottom)
	grad(o, top or PK.Paper, bottom or PK.PaperShade, 90)
	return o
end
-- Parchment sheet edge to edge, a faint aged vignette and a thin dark outline.
local function paper(parent, x, y, w, h)
	local p = F(parent, x, y, w, h, Color3.new(1, 1, 1))
	paperFill(p)
	stroke(p, RIM, 1.5)
	for _, e in { { 0, 0, w, 18, 90 }, { 0, h - 18, w, 18, 270 } } do -- top and bottom age shading
		local s = F(p, e[1], e[2], e[3], e[4], PK.MountDark)
		N("UIGradient", s, {
			Rotation = e[5],
			Transparency = NumberSequence.new(0.35, 1),
		})
	end
	return p
end
-- Round wooden rod with darker rounded end caps sticking out past the paper.
local function woodRod(parent, x, y, w, h, vertical)
	local r = F(parent, x, y, w, h, Color3.new(1, 1, 1))
	corner(r, UDim.new(0.5, 0))
	grad(r, PK.RodTop, PK.RodBottom, vertical and 0 or 90, { 0.35, PK.RodTop:Lerp(Color3.new(1, 1, 1), 0.18) })
	stroke(r, PK.CapDark, 1)
	local caps = vertical and { { x - 4, y - 14, w + 8, 18 }, { x - 4, y + h - 4, w + 8, 18 } }
		or { { x - 14, y - 4, 18, h + 8 }, { x + w - 4, y - 4, 18, h + 8 } }
	for _, c in caps do
		local cap = F(parent, c[1], c[2], c[3], c[4], Color3.new(1, 1, 1))
		corner(cap, 6)
		grad(cap, PK.CapLight, PK.CapDark, vertical and 90 or 0)
	end
	return r
end
-- Summon-style section heading: black ink Permanent Marker in small caps, a thin rule under it.
local function smallCaps(text, big, small)
	local out = {}
	for word in text:gmatch("%S+") do
		table.insert(out, ('<font size="%d">%s</font>%s'):format(big, word:sub(1, 1):upper(), word:sub(2):upper()))
	end
	return table.concat(out, " "), small
end
local function heading(parent, text, x, y, w)
	local t, s = smallCaps(text, 34, 28)
	T(parent, t, x, y, w, 38, s, PINK, MARKER)
	F(parent, x, y + 40, w, 2, PK.RuleTop, { BackgroundTransparency = 0.55 })
end
local function rule(parent, x, y, w)
	F(parent, x, y, w, 2, PK.RuleTop, { BackgroundTransparency = 0.6 })
end
-- Red square seal (like 選 on Summon): vermilion fill, cream glyph.
local function redSeal(parent, text, x, y, s, font)
	local b = T(parent, text, x, y, s, s, s * 0.7, K.SealText, font or NUM, {
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = VERM,
	})
	corner(b, 4)
	return b
end
-- Red brush pill (like "Mythic, 0.5%"): vermilion swash with ragged ends.
local function brushPill(parent, text, x, y, w, h, size)
	local b = F(parent, x, y, w, h, VERM)
	corner(b, UDim.new(0.5, 0))
	N("UIGradient", b, {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.06, 0),
			NumberSequenceKeypoint.new(0.94, 0),
			NumberSequenceKeypoint.new(1, 0.35),
		}),
	})
	T(b, text, 0, 0, w, h, size or 24, K.SealText, KALAM, { TextXAlignment = Enum.TextXAlignment.Center })
	return b
end
-- Summon paper button: parchment fill, ink-brush rim 3 px, Kalam Bold mixed case.
local function paperButton(parent, text, x, y, w, h, size, rimColor, textColor, props, top, bottom)
	local b = F(parent, x, y, w, h, Color3.new(1, 1, 1))
	paperFill(b, top or K.Cream, bottom or PK.PaperShade)
	corner(b, 10)
	stroke(b, rimColor or RIM, 3)
	local p = { TextXAlignment = Enum.TextXAlignment.Center }
	for k, v in props or {} do
		p[k] = v
	end
	local l = T(b, text, 0, 0, w, h, size, textColor or PINK, KALAM, p)
	return b, l
end

-- Kalam and Titillium read smaller than Nunito at the same TextSize; bring them up to the Summon page's weight.
local function fontPass(root)
	for _, l in root:GetDescendants() do
		if l:IsA("TextLabel") and not l:GetAttribute("Sized") then
			local fam = l.FontFace.Family
			if fam:find("Kalam") then
				l.TextSize = math.floor(l.TextSize * 1.22)
			elseif fam:find("Titillium") then
				l.TextSize = math.floor(l.TextSize * 1.1)
			end
			l:SetAttribute("Sized", true)
		end
	end
end

-- left panel: hanging parchment scroll
local panel = F(ui, 0, 0, 1920, 1080, nil, { Name = "Panel" })
do
	paper(panel, 16, 100, 376, 956)
	-- two leather strips hang the top rod and run a little onto the paper
	for _, x in { 96, 300 } do
		F(panel, x, 70, 12, 50, PK.Cord, { BorderSizePixel = 0 })
		F(panel, x - 3, 112, 18, 10, PK.CapDark)
	end
	woodRod(panel, 10, 86, 388, 22, false)
	woodRod(panel, 10, 1046, 388, 26, false)
	-- vertical vermilion kanji pair (like 召喚): 編成 = team formation
	T(panel, "編\n成", 350, 206, 36, 74, 30, VERM, KALAM, {
		TextXAlignment = Enum.TextXAlignment.Center,
		LineHeight = 0.95,
	})
end

-- nav arrows (stage controls, unchanged)
for _, n in { { 444, "‹" }, { 1791, "›" } } do
	local b = pill(ui, "", n[1], 532, 74, 72, 10, Color3.new(1, 1, 1), NUN, hex("3a141a"), hex("1d080b"), hex("c9a6a0"), 3, 12)
	b.Name = "Nav"
	local dir = n[2] == "‹" and -1 or 1
	for _, side in { -1, 1 } do -- chevron drawn with two rounded bars
		local bar = F(b, 37 - dir * 4, 36 + side * 9, 28, 8, Color3.new(1, 1, 1), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = -side * dir * 45,
		})
		corner(bar, UDim.new(0.5, 0))
	end
end

-- tabs, search, sort: paper tabs and parchment fields with ink rims
local tabs = F(ui, 0, 0, 1920, 1080, nil, { Name = "Tabs" })
do
	local a = paperButton(tabs, "      Characters", 432, 690, 258, 64, 32, RIM, VERM, nil, PK.Paper, PK.Paper)
	icon(a, "person", 26, 13, 38)
	local b = paperButton(tabs, "        Sidekicks", 706, 690, 238, 64, 32, RIM, PINK, nil, PK.PaperShade, PK.MountDark)
	icon(b, "fox", 22, 12, 40)
	local s = paperButton(tabs, "Search character...", 981, 694, 553, 54, 25, RIM, K.Muted, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(70, 0),
		FontFace = BODY,
	})
	icon(s, "search", 18, 9, 36)
	local so = paperButton(tabs, "Sort: Rarity", 1572, 694, 324, 54, 28, RIM, PINK, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(84, 0),
	})
	icon(so, "sort", 20, 9, 36)
	T(so, "›", 280, 2, 30, 50, 44, PINK, NUN, { Rotation = 90, TextXAlignment = Enum.TextXAlignment.Center })
end

fontPass(panel)
fontPass(tabs)

-- roster: horizontal handscroll, the same wood rods standing at both ends
local roster = F(ui, 0, 0, 1920, 1080, nil, { Name = "Roster" })
paper(roster, 424, 762, 1470, 306)
woodRod(roster, 408, 752, 28, 326, true)
woodRod(roster, 1882, 752, 28, 326, true)

-- dynamic layer (rebuilt per team)
local dyn = F(ui, 0, 0, 1920, 1080, nil, { Name = "Dyn" })
local plates = F(ui, 0, 0, 1920, 1080, nil, { Name = "Plates" })

-- ---------- per-team build ----------
local function nameplate(parent, x, y, w, h, d, centre)
	if centre then
		local gl = F(parent, x - 8, y - 8, w + 16, h + 16, hex("ff5a8a"), { BackgroundTransparency = 0.82 })
		corner(gl, 16)
	end
	local p = F(parent, x, y, w, h, hex("2e0d12"), { BackgroundTransparency = 0.05 })
	lacquer(p)
	corner(p, 10)
	stroke(p, centre and hex("ff9cc0") or hex("e2b64a"), 3)
	local tx = centre and 64 or 18
	if centre then
		icon(p, "star", 12, 9, 44)
	end
	local nameSize = centre and 40 or 30
	local nm = T(p, d.Name, tx, centre and 2 or 1, w - tx - 2 * (centre and 64 or 58), centre and 44 or 34, nameSize, Color3.new(1, 1, 1), NUN)
	textStroke(nm, hex("0a0204"), 1.5)
	T(p, d.Rarity, tx, centre and 42 or 32, 200, centre and 32 or 26, centre and 28 or 22, (centre and d.Rarity == "Mythic") and hex("ff86c8") or RAR_DARK[d.Rarity], NUN)
	local s = centre and 58 or 52
	local g = GEAR[d.Id]
	gem(p, RELIC[g[1]], w - 2 * s - 18, (h - s) / 2, s)
	gem(p, SIDE[g[2]], w - s - 10, (h - s) / 2, s)
	return p
end

-- Parchment roster card: thin ink rim, rarity colour band, Kalam name, Titillium details.
local function card(parent, x, y, d, slot, cruise)
	local c = F(parent, x, y, 170, 228, Color3.new(1, 1, 1), { ClipsDescendants = true })
	paperFill(c, K.Cream, PK.PaperShade)
	corner(c, 8)
	stroke(c, slot == 1 and VERM or RIM, slot == 1 and 3 or 1.5)
	local pic = F(c, 0, 0, 170, 128, Color3.new(1, 1, 1))
	grad(pic, RAR_BG[d.Rarity]:Lerp(Color3.new(1, 1, 1), 0.35), RAR_BG[d.Rarity], 90)
	I(pic, Portraits[d.Id] or "", 0, 0, 170, 128, { ScaleType = Enum.ScaleType.Crop })
	F(c, 0, 128, 170, 5, RAR_BG[d.Rarity]) -- rarity colour band
	if slot then
		redSeal(c, tostring(slot), 8, 8, 34)
	end
	local g = GEAR[d.Id]
	local icons = slot and { RELIC[g[1]], SIDE[g[2]], "ok" } or { RELIC[g[1]], SIDE[g[2]] }
	for k, img in icons do
		local ix = 170 - 6 - (#icons - k + 1) * 36
		if img == "ok" then
			icon(c, "check", ix - 1, 5, 36) -- the drawn green check
		else
			local b = F(c, ix, 6, 34, 34, hex("2a0c0c"), { BackgroundTransparency = 0.2 })
			corner(b, 7)
			stroke(b, Color3.new(1, 1, 1), 2)
			b:FindFirstChildOfClass("UIStroke").Transparency = 0.6
			I(b, img, 2, 2, 30, 30, { ScaleType = Enum.ScaleType.Fit })
		end
	end
	icon(c, "star", 6, 140, 24)
	T(c, d.Name, 36, 132, 132, 34, 26, PINK, KALAM, { TextTruncate = Enum.TextTruncate.AtEnd })
	T(c, d.Rarity, 36, 162, 130, 22, 19, RAR_CREAM[d.Rarity], BODYB)
	if slot then
		redSeal(c, "桜", 10, 188, 28, KALAM)
	end
	T(c, cruise .. ' <font size="15">st/s</font>', 50, 186, 112, 32, 22, PINK, BODYB, {
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	return c
end

function TSD.build(team)
	team = team or "A"
	for _, f in { dyn, plates, world, glowL } do
		for _, ch in f:GetChildren() do
			ch:Destroy()
		end
	end
	table.clear(rigs)

	local ids = TEAMS[team]
	local specs = {}
	for i, id in ids do
		specs[i] = spec(id)
	end
	local kind, series = SeriesCatalog.TeamBonus(ids, function(id)
		return spec(id).Series
	end)
	local multi = kind == "Preset" and RaceConfig.PRESET_CRUISE or 1
	local cruise = {}
	local total = 0
	for i, s in specs do
		cruise[i] = math.floor(RaceConfig.Cruise(s, multi) + 0.5)
		total += cruise[i]
	end

	-- glows behind the stage (2D, under the ViewportFrame)
	glow(glowL, 1089, 640, 900, 190, hex("ff9a2a"), 0.55, 10) -- warm orange-gold floor glow
	glow(glowL, 720, 500, 420, 90, hex("ffb34a"), 0.45, 8)
	glow(glowL, 1493, 500, 420, 90, hex("ffb34a"), 0.45, 8)
	glow(glowL, 1089, 350, 560, 560, hex("ff2a3a"), 1.1, 14)
	glow(glowL, 1089, 340, 300, 380, hex("ff5a7a"), 0.8, 10)

	for slot, id in ids do
		placeMember(slot, id)
	end

	-- nameplates, badges, selected plate (stage, unchanged)
	nameplate(plates, 940, 123, 328, 80, specs[1], true)
	nameplate(plates, 598, 219, 256, 64, specs[2], false)
	nameplate(plates, 1362, 219, 262, 64, specs[3], false)
	for slot = 2, 3 do
		local s = SLOTS[slot]
		local yaw = math.atan2(-s.X, -s.Z)
		local a = s.rt * AP
		local bx, by = project(s.X + math.sin(yaw) * a, s.hb + s.ht * 0.5, s.Z + math.cos(yaw) * a)
		local gl = F(plates, bx - 40, by - 36, 80, 72, hex("ffb34a"), { BackgroundTransparency = 0.8 })
		corner(gl, 20)
		local b, l = pill(plates, tostring(slot), bx - 26, by - 24, 52, 48, 38, hex("ffd26a"), NUM, hex("4a1a0e"), hex("2a0c06"), hex("e7b552"), 3, 10)
		b.Name = "Badge"
		textStroke(l, hex("3a1000"), 1.5)
	end
	do
		local s = SLOTS[1]
		local a = s.rt * AP
		local sx, sy = project(0, s.hb + s.ht, s.Z + a)
		sy -= 16
		local gl = F(plates, sx - 160, sy - 36, 320, 72, hex("ff6a3a"), { BackgroundTransparency = 0.75 })
		corner(gl, 16)
		local p = F(plates, sx - 146, sy - 28, 292, 56, hex("f6e4c0"), { Name = "Selected" })
		grad(p, hex("fff4dc"), hex("efd8ae"), 90)
		corner(p, 8)
		stroke(p, hex("c98a3a"), 3)
		local no = T(p, "1", 8, 8, 40, 40, 32, Color3.new(1, 1, 1), NUM, {
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = hex("b0202a"),
		})
		corner(no, 7)
		T(p, "Selected", 56, 0, 180, 56, 36, hex("2a0a08"), NUNI, { TextXAlignment = Enum.TextXAlignment.Center })
		seal(p, 244, 9, 38)
		local ex, ey = project(0, s.hb * 0.5, s.Z + s.rb * AP)
		sakura(plates, ex, ey, 44, hex("ffb3cf"), 0)
	end

	-- petals (static)
	local rnd = Random.new(7)
	for _ = 1, 16 do
		local px, py = rnd:NextNumber(470, 1880), rnd:NextNumber(90, 680)
		if not (px > 930 and px < 1250 and py > 500 and py < 580) then -- keep clear of the Selected plate
			local p = F(plates, px, py, 16, 10, hex("ffb0cc"), {
				Rotation = rnd:NextNumber(0, 180),
				BackgroundTransparency = 0.15,
			})
			corner(p, UDim.new(0.5, 0))
		end
	end

	-- left panel contents (Summon parchment look)
	do
		local _, ddl = paperButton(dyn, "Team 1", 50, 140, 252, 52, 30, RIM, PINK, {
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(22, 0),
		})
		_ = ddl
		T(dyn, "›", 266, 140, 30, 52, 40, PINK, NUN, { Rotation = 90, TextXAlignment = Enum.TextXAlignment.Center })
		local pen = paperButton(dyn, "", 312, 140, 56, 52, 26, RIM, PINK)
		icon(pen, "pencil", 10, 8, 36)

		heading(dyn, "Team Status", 50, 226, 290)
		icon(dyn, "check", 52, 279, 36)
		T(dyn, "Ready to Deploy", 104, 277, 260, 40, 27, hex("2a8a3a"), BODYB)
		icon(dyn, "members", 54, 317, 36)
		T(dyn, #ids .. " / 3 Members", 104, 315, 260, 40, 27, PINK, BODYB)
		icon(dyn, "cruise", 54, 357, 36)
		T(dyn, 'Cruise: <font family="rbxasset://fonts/families/Kalam.json" size="32">' .. total .. '</font> <font size="17">st/s</font>', 104, 353, 230, 44, 27, PINK, BODYB)
		redSeal(dyn, "桜", 334, 332, 34, KALAM)

		heading(dyn, "Team Members", 50, 418, 318)
		for i, s in specs do
			local y = 470 + (i - 1) * 61
			local pbg = F(dyn, 50, y, 58, 56, RAR_BG[s.Rarity])
			corner(pbg, 7)
			stroke(pbg, RIM, 1.5)
			local im = I(pbg, Portraits[s.Id] or "", 0, 0, 58, 56)
			corner(im, 7)
			redSeal(dyn, tostring(i), 122, y + 12, 32)
			T(dyn, s.Name, 168, y, 140, 56, 29, PINK, KALAM)
			T(dyn, cruise[i] .. ' <font size="15">st/s</font>', 270, y, 96, 56, 22, PINK, BODYB, {
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			if i < #specs then
				rule(dyn, 50, y + 59, 318)
			end
		end

		heading(dyn, "Team Bonus", 50, 678, 270)
		redSeal(dyn, "桜", 334, 684, 34, KALAM)
		if kind then
			local stam = math.floor((StaminaConfig.TEAM_BONUS[kind] - 1) * 100 + 0.5)
			local label = kind == "Preset" and (series.Preset and series.Preset.Name or "Preset") or (series.Name or "Series")
			brushPill(dyn, kind .. ": " .. label, 50, 734, 300, 40, 25) -- the highlight, like "Mythic, 0.5%"
			icon(dyn, "heart", 54, 786, 36)
			T(dyn, 'Stamina <font color="#2a8a3a" size="30">+' .. stam .. "%</font>", 104, 784, 270, 40, 27, PINK, BODYB)
			if kind == "Preset" then
				icon(dyn, "stamina", 54, 830, 36)
				T(dyn, 'Cruise <font color="#2a6ad0" size="30">×' .. RaceConfig.PRESET_CRUISE .. "</font>", 104, 828, 270, 40, 27, PINK, BODYB)
			end
		else
			T(dyn, "No team bonus", 54, 736, 300, 40, 29, PINK, KALAM)
			T(dyn, "Mixed series", 54, 778, 300, 34, 23, K.Muted, BODYB)
			T(dyn, "3 of one series: Stamina +20%", 54, 812, 310, 34, 20, K.Muted, BODY)
		end
		rule(dyn, 50, 884, 318)

		local qs = paperButton(dyn, "      Quick Setup", 24, 936, 172, 68, 25, RIM, PINK)
		icon(qs, "bolt", 10, 18, 32)
		local dep = paperButton(dyn, "▶ Deploy", 206, 936, 178, 68, 32, VERM, VERM)
		redSeal(dep, "出", 150, -12, 30, KALAM) -- seal on the primary, like 選 on Details
	end

	-- roster cards: team first, then others
	local list = {}
	for i, s in specs do
		table.insert(list, { s, i, cruise[i] })
	end
	for _, id in OTHERS do
		local s = spec(id)
		table.insert(list, { s, nil, math.floor(RaceConfig.Cruise(s, 1) + 0.5) })
	end
	for k, e in list do
		card(dyn, 452 + (k - 1) * 178, 792, e[1], e[2], e[3])
	end
	fontPass(dyn)
	return { kind = kind, total = total, cruise = cruise }
end

-- "stage": hide the UI except the nameplates, badges and Selected plate.
function TSD.mode(m)
	for _, ch in ui:GetChildren() do
		ch.Visible = (m ~= "stage") or ch == plates
	end
end

local info = TSD.build(_G.TSD_TEAM or "A")
return ("built team %s, bonus %s, total cruise %d"):format(_G.TSD_TEAM or "A", tostring(info.kind), info.total)
