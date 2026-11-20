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
local function sakura(parent, cx, cy, s, color, rot)
	local l = T(parent, "✿", cx - s / 2, cy - s / 2, s, s, s, color or hex("ffb3cf"), NUN, {
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = rot or 0,
	})
	textStroke(l, hex("c23a6a"), 1.5)
	return l
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
local RING = hex("ff4f8a")
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
	octRing(m, at * 0.62, top + 0.03, cf, hex("ff86b0"), 0.02, 0.06)
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

-- ---------- members + idle breathing ----------
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
		local cf, size = info.cf, info.size
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

-- Makimono scroll helpers (approved skin A)
local function rodH(parent, x, y, w)
	local r = F(parent, x, y, w, 26, hex("6a2a18"))
	corner(r, 12)
	grad(r, hex("170604"), hex("170604"), 90, { 0.42, hex("a2543a") })
	for _, cx in { x - 6, x + w - 16 } do
		local c = F(parent, cx, y - 3, 22, 32, GOLD)
		corner(c, 7)
		grad(c, hex("fff3b0"), hex("7a4a10"), 60, { 0.4, hex("e7b552") })
	end
	return r
end
local function rodV(parent, x, y, h)
	local r = F(parent, x, y, 32, h, hex("6a2a18"))
	corner(r, 12)
	grad(r, hex("170604"), hex("170604"), 0, { 0.42, hex("a2543a") })
	for _, cy in { y - 8, y + h - 14 } do
		local c = F(parent, x - 3, cy, 38, 22, GOLD)
		corner(c, 7)
		grad(c, hex("fff3b0"), hex("7a4a10"), 60, { 0.4, hex("e7b552") })
	end
	return r
end
local function paper(parent, x, y, w, h)
	local p = F(parent, x, y, w, h, hex("f3e2bf"))
	grad(p, hex("fbf0d8"), hex("ddc093"), 90, { 0.55, hex("ecd6ad") })
	stroke(p, hex("b98a4a"), 3)
	local inner = F(p, 3, 3, w - 6, h - 6, nil)
	stroke(inner, hex("e9d3a8"), 2)
	return p
end
local function band(parent, text, x, y, w)
	local b = F(parent, x, y, w, 42, hex("b0242c"))
	N("UIGradient", b, {
		Color = ColorSequence.new(hex("8e1b23"), hex("b0242c")),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.72, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	local l = T(b, text, 28, 0, w - 30, 42, 30, Color3.new(1, 1, 1), NUNI)
	textStroke(l, hex("4a0a0e"), 1.5)
	return b
end
local function divider(parent, x, y, w)
	F(parent, x, y, w, 2, hex("c9a878"), { BackgroundTransparency = 0.2 })
end

-- left panel frame
local panel = F(ui, 0, 0, 1920, 1080, nil, { Name = "Panel" })
paper(panel, 16, 102, 376, 954)
rodH(panel, 6, 88, 396)
rodH(panel, 6, 1044, 396)

-- nav arrows
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

-- tabs, search, sort
local tabs = F(ui, 0, 0, 1920, 1080, nil, { Name = "Tabs" })
do
	pill(tabs, "👤  Characters", 432, 690, 258, 64, 32, hex("c2223a"), NUNI, hex("fff2dc"), hex("f4d8b4"), hex("b98a4a"), 3, 10)
	local b = pill(tabs, "        Sidekicks", 706, 690, 238, 64, 32, INK, NUNI, hex("f6e6c6"), hex("e2c69a"), hex("b98a4a"), 3, 10)
	I(b, SIDE.fox, 22, 14, 38, 38, { ScaleType = Enum.ScaleType.Fit })
	sakura(tabs, 690, 744, 36, hex("ffb3cf"), 15)
	local s = T(tabs, "Search character...", 981, 694, 553, 54, 26, hex("d8bcc0"), NUN, {
		BackgroundTransparency = 0.15,
		BackgroundColor3 = hex("2a0c12"),
	})
	N("UIPadding", s, { PaddingLeft = UDim.new(0, 70) })
	corner(s, 10)
	stroke(s, hex("c9a6a0"), 2)
	local lens = F(tabs, 1003, 708, 22, 22, nil)
	corner(lens, UDim.new(0.5, 0))
	stroke(lens, Color3.new(1, 1, 1), 3)
	F(tabs, 1024, 733, 12, 4, Color3.new(1, 1, 1), { Rotation = 45 })
	local so = T(tabs, "Sort: Rarity", 1572, 694, 324, 54, 28, Color3.new(1, 1, 1), NUN, {
		BackgroundTransparency = 0.15,
		BackgroundColor3 = hex("2a0c12"),
	})
	N("UIPadding", so, { PaddingLeft = UDim.new(0, 84) })
	corner(so, 10)
	stroke(so, hex("c9a6a0"), 2)
	for k = 0, 2 do
		F(tabs, 1596, 708 + k * 10, 5, 5, Color3.new(1, 1, 1))
		F(tabs, 1606, 708 + k * 10, 24 - k * 6, 4, Color3.new(1, 1, 1))
	end
	T(tabs, "›", 1852, 696, 30, 50, 44, Color3.new(1, 1, 1), NUN, {
		Rotation = 90,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
end

-- roster handscroll
local roster = F(ui, 0, 0, 1920, 1080, nil, { Name = "Roster" })
paper(roster, 424, 762, 1470, 306)
rodV(roster, 406, 750, 330)
rodV(roster, 1880, 750, 330)

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
		local st = T(p, "★", 12, 8, 46, 46, 40, hex("ffd23a"), NUN, { TextXAlignment = Enum.TextXAlignment.Center })
		textStroke(st, hex("7a4a00"), 1.5)
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

local function card(parent, x, y, d, slot, cruise)
	local c = F(parent, x, y, 170, 228, hex("fbf2de"), { ClipsDescendants = true })
	corner(c, 12)
	stroke(c, slot == 1 and hex("d6343c") or hex("e2c99c"), 3)
	local pic = F(c, 0, 0, 170, 128, Color3.new(1, 1, 1))
	grad(pic, RAR_BG[d.Rarity]:Lerp(Color3.new(1, 1, 1), 0.35), RAR_BG[d.Rarity], 90)
	I(pic, Portraits[d.Id] or "", 0, 0, 170, 128, { ScaleType = Enum.ScaleType.Crop })
	if slot then
		local no = T(c, tostring(slot), 8, 8, 34, 34, 26, Color3.new(1, 1, 1), NUM, {
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = hex("b0202a"),
		})
		corner(no, 6)
	end
	local g = GEAR[d.Id]
	local icons = slot and { RELIC[g[1]], SIDE[g[2]], "ok" } or { RELIC[g[1]], SIDE[g[2]] }
	for k, img in icons do
		local ix = 170 - 6 - (#icons - k + 1) * 36 - (#icons - k) * 0
		local b = F(c, ix + (k - 1) * 0, 6, 34, 34, img == "ok" and hex("2fa84f") or hex("2a0c0c"), {
			BackgroundTransparency = img == "ok" and 0 or 0.2,
		})
		corner(b, 7)
		stroke(b, img == "ok" and hex("bff0c8") or Color3.new(1, 1, 1), 2)
		b:FindFirstChildOfClass("UIStroke").Transparency = img == "ok" and 0 or 0.6
		if img == "ok" then
			T(b, "✓", 0, 0, 34, 34, 28, Color3.new(1, 1, 1), NUN, { TextXAlignment = Enum.TextXAlignment.Center })
		else
			I(b, img, 2, 2, 30, 30, { ScaleType = Enum.ScaleType.Fit })
		end
	end
	local st = T(c, "★", 8, 130, 28, 30, 24, hex("f2b51e"), NUN)
	textStroke(st, hex("7a4a00"), 1)
	T(c, d.Name, 36, 128, 132, 32, 26, INK, NUN, { TextTruncate = Enum.TextTruncate.AtEnd })
	T(c, d.Rarity, 38, 156, 130, 22, 19, RAR_CREAM[d.Rarity], NUNI)
	if slot then
		seal(c, 10, 186, 30)
	end
	T(c, cruise .. ' <font size="15">st/s</font>', 50, 186, 112, 32, 21, INK, NUN, {
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	return c
end

function TSD.build(team)
	team = team or "A"
	for _, ch in dyn:GetChildren() do
		ch:Destroy()
	end
	for _, ch in plates:GetChildren() do
		ch:Destroy()
	end
	for _, ch in world:GetChildren() do
		ch:Destroy()
	end
	for _, ch in glowL:GetChildren() do
		ch:Destroy()
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
	glow(glowL, 1089, 640, 900, 190, hex("ff6a4a"), 0.55, 10)
	glow(glowL, 720, 500, 420, 90, hex("ffb34a"), 0.45, 8)
	glow(glowL, 1493, 500, 420, 90, hex("ffb34a"), 0.45, 8)
	glow(glowL, 1089, 350, 560, 560, hex("ff2a3a"), 1.1, 14)
	glow(glowL, 1089, 340, 300, 380, hex("ff5a7a"), 0.8, 10)

	for slot, id in ids do
		placeMember(slot, id)
	end

	-- nameplates, badges, selected plate
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
		-- sakura emblem on the centre altar's base front
		local ex, ey = project(0, s.hb * 0.5, s.Z + s.rb * AP)
		sakura(plates, ex, ey, 44, hex("ffb3cf"), 0)
	end

	-- petals (static)
	local rnd = Random.new(7)
	for _ = 1, 16 do
		local px, py = rnd:NextNumber(470, 1880), rnd:NextNumber(90, 680)
		local p = F(plates, px, py, 16, 10, hex("ffb0cc"), {
			Rotation = rnd:NextNumber(0, 180),
			BackgroundTransparency = 0.15,
		})
		corner(p, UDim.new(0.5, 0))
	end

	-- left panel contents
	do
		pill(dyn, "Team 1", 50, 140, 252, 52, 30, Color3.new(1, 1, 1), NUN, hex("4a1a18"), hex("2a0a0a"), hex("7a3a2a"), 2, 9, {
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(22, 0),
		})
		T(dyn, "›", 266, 140, 30, 52, 40, Color3.new(1, 1, 1), NUN, { Rotation = 90, TextXAlignment = Enum.TextXAlignment.Center })
		pill(dyn, "✏️", 312, 140, 56, 52, 28, Color3.new(1, 1, 1), NUN, hex("4a1a18"), hex("2a0a0a"), hex("7a3a2a"), 2, 9)
		divider(dyn, 50, 206, 318)
		sakura(dyn, 356, 222, 30, hex("ffb3cf"), 0)

		band(dyn, "Team Status", 36, 228, 330)
		local ok = F(dyn, 54, 279, 32, 32, hex("2fa84f"))
		corner(ok, UDim.new(0.5, 0))
		stroke(ok, hex("1e7a30"), 2)
		T(ok, "✓", 0, 0, 32, 32, 24, Color3.new(1, 1, 1), NUN, { TextXAlignment = Enum.TextXAlignment.Center })
		T(dyn, "Ready to Deploy", 104, 275, 260, 40, 27, hex("2a8a3a"), NUN)
		T(dyn, "👥", 52, 313, 40, 40, 28, INK, NUN, { TextXAlignment = Enum.TextXAlignment.Center })
		T(dyn, #ids .. " / 3 Members", 104, 313, 260, 40, 27, INK, NUN)
		T(dyn, "⚔", 52, 353, 40, 40, 30, INK, NUN, { TextXAlignment = Enum.TextXAlignment.Center })
		local cr = T(dyn, 'Cruise: <font color="#b07a00" size="34"><i>' .. total .. '</i></font> <font size="17">st/s</font>', 104, 351, 260, 44, 27, INK, NUN)
		_ = cr
		seal(dyn, 330, 330, 38)
		divider(dyn, 50, 404, 318)

		band(dyn, "Team Members", 36, 422, 330)
		for i, s in specs do
			local y = 470 + (i - 1) * 61
			local pbg = F(dyn, 50, y, 58, 56, RAR_BG[s.Rarity])
			corner(pbg, 7)
			stroke(pbg, hex("d8bf98"), 2)
			local im = I(pbg, Portraits[s.Id] or "", 0, 0, 58, 56)
			corner(im, 7)
			local no = T(dyn, tostring(i), 122, y + 12, 32, 32, 24, Color3.new(1, 1, 1), NUM, {
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0,
				BackgroundColor3 = hex("b0202a"),
			})
			corner(no, 7)
			T(dyn, s.Name, 168, y, 140, 56, 28, INK, NUN)
			T(dyn, cruise[i] .. ' <font size="15">st/s</font>', 270, y, 96, 56, 22, INK, NUN, {
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTransparency = 0.1,
			})
			if i < #specs then
				divider(dyn, 50, y + 59, 318)
			end
		end
		divider(dyn, 50, 660, 318)

		band(dyn, "Team Bonus", 36, 682, 330)
		seal(dyn, 330, 690, 38)
		if kind then
			local stam = math.floor((StaminaConfig.TEAM_BONUS[kind] - 1) * 100 + 0.5)
			T(dyn, "🌸", 50, 736, 44, 40, 30, INK, NUN, { TextXAlignment = Enum.TextXAlignment.Center })
			local label = kind == "Preset" and (series.Preset and series.Preset.Name or "Preset") or (series.Name or "Series")
			T(dyn, kind .. ": " .. label, 104, 736, 270, 40, 27, INK, NUN)
			T(dyn, "💚", 50, 782, 44, 40, 28, INK, NUN, { TextXAlignment = Enum.TextXAlignment.Center })
			T(dyn, 'Stamina <font color="#2a8a3a" size="30"><i>+' .. stam .. "%</i></font>", 104, 782, 270, 40, 27, INK, NUN)
			if kind == "Preset" then
				T(dyn, "⚡", 50, 828, 44, 40, 28, INK, NUN, { TextXAlignment = Enum.TextXAlignment.Center })
				T(dyn, 'Cruise <font color="#2a6ad0" size="30"><i>×' .. RaceConfig.PRESET_CRUISE .. "</i></font>", 104, 828, 270, 40, 27, INK, NUN)
			end
		else
			T(dyn, "🌸", 50, 736, 44, 40, 30, INK, NUN, { TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.55 })
			T(dyn, "No team bonus", 104, 736, 270, 40, 27, INK, NUN)
			T(dyn, "Mixed series", 104, 778, 270, 34, 22, hex("8a6a50"), NUNI)
			T(dyn, "3 of one series: Stamina +20%", 104, 812, 270, 34, 19, hex("8a6a50"), NUN)
		end
		divider(dyn, 50, 884, 318)
		sakura(dyn, 362, 900, 30, hex("ffb3cf"), 0)

		pill(dyn, "⚡Quick Setup", 24, 936, 172, 68, 24, hex("3a1a0a"), NUNI, hex("f6e2b8"), hex("ddb878"), hex("9a6a2a"), 3, 12)
		local _, dl = pill(dyn, "▶ Deploy", 206, 936, 178, 68, 34, Color3.new(1, 1, 1), NUNI, hex("d33a30"), hex("8e1a1a"), hex("5a0a0a"), 3, 12)
		textStroke(dl, hex("4a0606"), 1.5)
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
