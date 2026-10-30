--!nonstrict
-- The spawn hub: an anime town plaza (docs/WORLD_REDESIGN_SPEC.md section 4). A stone-paved square with the game's
-- only SpawnLocation at its centre, a torii StartGate over the StartPad (walking through it starts the run,
-- Server/CarService), the shop street (Shop, Market, Potions stalls), the Rebirth shrine, the Index scroll board, the
-- leaderboard banners, the Best Roll pedestal and the Checkpoints sensei. Players join and respawn here on foot, and
-- Stop sends them back here. The 7 Dojo plots (Shared/WorkshopConfig) ring the plaza; this floor runs under them.
-- Everything is placed in the local space of Track 1's flattened Start part (SpawnArea.Base; forward -Z, right +X).
-- Track 1 starts west of the plaza (local x 0) heading -Z and Track 2 runs along local z 90, so the plaza stays east
-- of x 22 and south of z 68, clear of the Track 1 / Track 2 biome gates at (34, -204) and (79, 56), and the start
-- gate stands at its north-west corner, next to Track 1's start. The walk spawn stays within 150 studs of that
-- start and 75 from any road (auto_toggle / spawn_area).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local MarketplaceBuilder = require(script.Parent.MarketplaceBuilder)
local LeaderboardConfig = require(script.Parent.LeaderboardConfig)
local CheckpointConfig = require(script.Parent.CheckpointConfig)
local UiTheme = require(script.Parent.UiTheme)

local SpawnArea = {}

SpawnArea.CENTRE = Vector2.new(118, -80) -- local (x, z) of the plaza centre (the Floor's centre and the Spawn)
SpawnArea.FLOOR_SIZE = Vector2.new(188, 220) -- studs (x, z); runs under part of the Dojo ring (placeholder)
SpawnArea.PAD_CENTRE = Vector2.new(34, -2) -- local (x, z) of the StartPad, under the torii
SpawnArea.PAD_SIZE = 16
SpawnArea.TOP_Y = 1 -- floor top = road top
SpawnArea.START_COOLDOWN = 2 -- seconds after a stop or a pad start before the pad can start that player again
SpawnArea.WALK_ROOT_HEIGHT = 3 -- HumanoidRootPart height above the floor top when standing
SpawnArea.TAG = "StartPad"

local THICKNESS = 3 -- reaches the Baseplate top (y = -2) so the floor never shows a gap underneath
local PAD_RAISE = 0.2
local SPAWN_SIZE = 12
local LABEL_DISTANCE = 150
local GATE_POST_Z = 11 -- torii posts stand this far either side of the pad centre (opening 19.8 studs)
local GATE_HEIGHT = 17 -- post height above the floor

-- Anime town palette (placeholders)
local STONE = Color3.fromRGB(158, 152, 140)
local VERMILION = Color3.fromRGB(205, 52, 36)
local BLACK = Color3.fromRGB(34, 30, 30)
local WOOD = Color3.fromRGB(150, 98, 60)
local DARK_WOOD = Color3.fromRGB(82, 52, 36)
local ROOF_TILE = Color3.fromRGB(58, 62, 72)
local PAPER = Color3.fromRGB(246, 236, 210)
local BLOSSOM = Color3.fromRGB(255, 183, 214)
local LANTERN_GLOW = Color3.fromRGB(255, 196, 120)

-- Track 1's start, flattened: yaw only, at ground level (the local space every plaza and plot position uses)
local function base(startCFrame)
	local look = startCFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
	local p = Vector3.new(startCFrame.Position.X, 0, startCFrame.Position.Z)
	return CFrame.lookAt(p, p + flat)
end

SpawnArea.Base = base

-- A local frame at (x, z), height y, facing the local point (tx, tz) (its -Z looks there).
local function facing(startCFrame, x, z, tx, tz, y)
	local here = Vector3.new(x, y or SpawnArea.TOP_Y, z)
	return base(startCFrame) * CFrame.lookAt(here, Vector3.new(tx, here.Y, tz))
end

local function world(startCFrame, x, z, y)
	local p = base(startCFrame):PointToWorldSpace(Vector3.new(x, 0, z))
	return Vector3.new(p.X, y or SpawnArea.TOP_Y, p.Z)
end

-- World box (Y = TOP_Y) of a size.X x size.Y rectangle centred on `cf`.
local function box(cf, size)
	local lo, hi = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
	for _, x in { -size.X / 2, size.X / 2 } do
		for _, z in { -size.Y / 2, size.Y / 2 } do
			local w = cf:PointToWorldSpace(Vector3.new(x, 0, z))
			lo = Vector3.new(math.min(lo.X, w.X), 0, math.min(lo.Z, w.Z))
			hi = Vector3.new(math.max(hi.X, w.X), 0, math.max(hi.Z, w.Z))
		end
	end
	return {
		Min = Vector3.new(lo.X, SpawnArea.TOP_Y, lo.Z),
		Max = Vector3.new(hi.X, SpawnArea.TOP_Y, hi.Z),
	}
end

-- World corners (Y = TOP_Y) of the plaza floor and of the start pad.
function SpawnArea.Bounds(startCFrame)
	local c, p = SpawnArea.CENTRE, SpawnArea.PAD_CENTRE
	return {
		Area = box(base(startCFrame) * CFrame.new(c.X, 0, c.Y), SpawnArea.FLOOR_SIZE),
		Pad = box(base(startCFrame) * CFrame.new(p.X, 0, p.Y), Vector2.one * SpawnArea.PAD_SIZE),
	}
end

-- Where an avatar stands on the plaza: its centre, facing the start gate.
function SpawnArea.WalkCFrame(startCFrame)
	local c, p = SpawnArea.CENTRE, SpawnArea.PAD_CENTRE
	return facing(startCFrame, c.X, c.Y, p.X, p.Y, SpawnArea.TOP_Y + SpawnArea.WALK_ROOT_HEIGHT)
end

-- An anchored part. Decoration (collide = false) also leaves touch and query alone.
local function block(parent, name, size, cframe, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if collide == false then
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end
	p.Parent = parent
	return p
end

local function glow(parent, range)
	local light = Instance.new("PointLight")
	light.Color = LANTERN_GLOW
	light.Brightness = 1.2
	light.Range = range or 14
	light.Shadows = false -- local light only; the global Lighting / weather stays as it is
	light.Parent = parent
end

-- A BillboardGui of text lines { name, text, colour } over `adornee`.
local function billboard(adornee, name, lines, size, height, distance)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = distance or LABEL_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = adornee
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = line[1]
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, (i - 1) / #lines)
		label.Size = UDim2.fromScale(1, 1 / #lines)
		label.Font = UiTheme.Font
		label.TextScaled = true
		label.Text = line[2]
		label.TextColor3 = line[3] or Color3.new(1, 1, 1)
		UiTheme.Stroke(label, 2)
		label.Parent = gui
	end
	return gui
end

local function surfaceText(part, face, name, text, colour, ppsOrNil)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	if ppsOrNil then
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = ppsOrNil
	end
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = UiTheme.Font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = colour
	label.Parent = gui
	return label
end

-- A ProximityPrompt on `anchor` (a part of the feature itself, so the plaza needs no extra parts). Returns anchor.
local function addPrompt(anchor, name, action, object, distance)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 10
	p.RequiresLineOfSight = false
	p.Parent = anchor
	return anchor
end

-- An invisible anchor carrying a ProximityPrompt.
local function prompt(parent, cframe, name, action, object, distance)
	local anchor = block(parent, "PromptAnchor", Vector3.new(1, 1, 1), cframe, PAPER, nil, false)
	anchor.Transparency = 1
	anchor.CastShadow = false
	return addPrompt(anchor, name, action, object, distance)
end

-- A gabled roof over a local frame: ridge along local X at `ridgeY`, `width` x `depth`.
local function roof(parent, frame, width, depth, ridgeY)
	local slope = math.rad(22)
	local half = depth / 2
	local run = half / math.cos(slope)
	for _, side in { -1, 1 } do
		block(
			parent,
			"Roof",
			Vector3.new(width, 0.6, run),
			frame
				* CFrame.new(0, ridgeY - math.tan(slope) * half / 2, side * half / 2)
				* CFrame.Angles(side * slope, 0, 0),
			ROOF_TILE,
			Enum.Material.Slate,
			false
		)
	end
end

-- A stone lantern (toro) with a warm light.
local function stoneLantern(parent, startCFrame, x, z)
	local m = Instance.new("Model")
	m.Name = "StoneLantern"
	local f = base(startCFrame) * CFrame.new(x, SpawnArea.TOP_Y, z)
	block(m, "Post", Vector3.new(1.6, 4, 1.6), f * CFrame.new(0, 2, 0), STONE, Enum.Material.Slate)
	local light =
		block(m, "Light", Vector3.new(2.6, 2.2, 2.6), f * CFrame.new(0, 5.1, 0), PAPER, Enum.Material.Neon, false)
	light.Transparency = 0.15
	glow(light, 16)
	m.Parent = parent
end

-- A cherry tree: a trunk and a cloud of blossom (footprint about 14 x 14).
local function cherryTree(parent, startCFrame, x, z)
	local m = Instance.new("Model")
	m.Name = "CherryTree"
	local f = base(startCFrame) * CFrame.new(x, SpawnArea.TOP_Y, z)
	block(m, "Trunk", Vector3.new(1.8, 9, 1.8), f * CFrame.new(0, 4.5, 0), DARK_WOOD, Enum.Material.Wood)
	for i, spec in
		{
			{ Vector3.new(0, 11, 0), 12 },
		}
	do
		local ball = block(
			m,
			"Blossom" .. i,
			Vector3.one * spec[2],
			f * CFrame.new(spec[1]),
			BLOSSOM:Lerp(Color3.new(1, 1, 1), (i % 3) * 0.12),
			Enum.Material.Grass,
			false
		)
		ball.Shape = Enum.PartType.Ball
	end
	m.Parent = parent
end

-- A wooden market stall facing the plaza centre: counter (with the prompt), posts, a tiled roof, a cloth curtain
-- with its sign.
local function stall(parent, startCFrame, name, x, z, cloth, title, promptName, action)
	local c = SpawnArea.CENTRE
	local m = Instance.new("Model")
	m.Name = name
	local f = facing(startCFrame, x, z, c.X, c.Y)
	local counter =
		block(m, "Counter", Vector3.new(10, 3.6, 2), f * CFrame.new(0, 1.8, -2), WOOD, Enum.Material.WoodPlanks)
	for _, px in { -4.8, 4.8 } do
		for _, pz in { -3.4 } do
			block(m, "Post", Vector3.new(0.8, 9, 0.8), f * CFrame.new(px, 4.5, pz), DARK_WOOD, Enum.Material.Wood)
		end
	end
	block(
		m,
		"Roof",
		Vector3.new(12, 0.6, 9),
		f * CFrame.new(0, 10, -0.5) * CFrame.Angles(math.rad(-12), 0, 0),
		ROOF_TILE,
		Enum.Material.Slate,
		false
	)
	local curtain = block(
		m,
		"Curtain",
		Vector3.new(9.6, 2.2, 0.2),
		f * CFrame.new(0, 7.6, -3.6),
		cloth,
		Enum.Material.Fabric,
		false
	)
	UiTheme.Stroke(surfaceText(curtain, Enum.NormalId.Front, "Sign", title, Color3.new(1, 1, 1), 25), 2)
	m.PrimaryPart = addPrompt(counter, promptName, action, title, 10)
	m.Parent = parent
	return m
end

-- The torii over the pad: two vermilion posts either side of the pad (across the walking direction, local z), the
-- nuki tie beam, the kasagi top beam with its black cap and upturned tips, and a plaque with made-up text. Posts and
-- footings collide; the opening over the pad is free.
local function torii(startCFrame)
	local pc = SpawnArea.PAD_CENTRE
	local gate = Instance.new("Model")
	gate.Name = "StartGate"
	local gf = base(startCFrame) * CFrame.new(pc.X, SpawnArea.TOP_Y, pc.Y) * CFrame.Angles(0, math.rad(90), 0)
	local h, w = GATE_HEIGHT, GATE_POST_Z
	for _, side in { -1, 1 } do
		block(gate, "Post", Vector3.new(2.2, h, 2.2), gf * CFrame.new(side * w, h / 2, 0), VERMILION)
	end
	block(gate, "Nuki", Vector3.new(w * 2 + 6, 1.2, 1.4), gf * CFrame.new(0, h - 3.5, 0), VERMILION, nil, false)
	local kasagi =
		block(gate, "Kasagi", Vector3.new(w * 2 + 8, 1.4, 2.6), gf * CFrame.new(0, h + 0.7, 0), VERMILION, nil, false)
	block(gate, "Cap", Vector3.new(w * 2 + 10, 1, 3), gf * CFrame.new(0, h + 1.9, 0), BLACK, nil, false)
	local plaque = block(gate, "Plaque", Vector3.new(3, 2.6, 0.6), gf * CFrame.new(0, h - 1.2, 0), BLACK, nil, false)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		surfaceText(plaque, face, "Plaque" .. face.Name, "RUN", Color3.fromRGB(255, 214, 90))
	end
	gate.PrimaryPart = kasagi
	return gate
end

function SpawnArea.Build(startCFrame)
	local model = Instance.new("Model")
	model.Name = "SpawnArea"
	local top = SpawnArea.TOP_Y
	local c, pc = SpawnArea.CENTRE, SpawnArea.PAD_CENTRE
	local frame = base(startCFrame)

	-- Plaza floor: stone paving, centred on the plaza centre
	local floor = block(
		model,
		"Floor",
		Vector3.new(SpawnArea.FLOOR_SIZE.X, THICKNESS, SpawnArea.FLOOR_SIZE.Y),
		frame * CFrame.new(c.X, top - THICKNESS / 2, c.Y),
		STONE,
		Enum.Material.Cobblestone
	)
	model.PrimaryPart = floor

	-- The one SpawnLocation, at the plaza centre
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(SPAWN_SIZE, 1, SPAWN_SIZE)
	spawn.CFrame = frame * CFrame.new(c.X, top + 0.05 - 0.5, c.Y) -- a hair above the floor so the two never z-fight
	spawn.Neutral = true
	spawn.Duration = 0 -- no force field
	spawn.Color = Color3.fromRGB(196, 186, 168)
	spawn.Material = Enum.Material.Slate
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = model

	-- StartPad under the torii StartGate: walking through the gate is walking onto the pad
	local pad = block(
		model,
		"StartPad",
		Vector3.new(SpawnArea.PAD_SIZE, 1, SpawnArea.PAD_SIZE),
		frame * CFrame.new(pc.X, top + PAD_RAISE - 0.5, pc.Y),
		Color3.fromRGB(176, 64, 48),
		Enum.Material.WoodPlanks
	)
	CollectionService:AddTag(pad, SpawnArea.TAG)
	billboard(
		pad,
		"Label",
		{ { "Text", "START RUN", Color3.fromRGB(255, 230, 160) } },
		UDim2.fromOffset(200, 50),
		GATE_HEIGHT + 6
	)
	glow(pad, 18)
	torii(startCFrame).Parent = model

	-- Shop street (same panels and remotes as before): Shop and Potions stalls south-west of the spawn, the Market east
	stall(model, startCFrame, "ShopStall", 80, -100, Color3.fromRGB(40, 90, 170), "SHOP", "OpenShop", "Open Shop")
	stall(
		model,
		startCFrame,
		"PotionsStall",
		80,
		-125,
		Color3.fromRGB(120, 60, 160),
		"POTIONS",
		"OpenPotions",
		"Potions"
	)
	local marketCenter = MarketplaceBuilder.CENTER
	local marketplace = MarketplaceBuilder.Build(
		frame
			* CFrame.new(marketCenter.X, top, marketCenter.Y)
			* CFrame.Angles(0, math.rad(MarketplaceBuilder.ROTATION), 0)
	)
	marketplace.Parent = model

	-- Rebirth shrine: a raised stone floor, vermilion pillars, a gabled roof, a bell and an offering box (the prompt)
	local shrine = Instance.new("Model")
	shrine.Name = "RebirthShrine"
	local sf = facing(startCFrame, 118, -30, c.X, c.Y)
	block(shrine, "Platform", Vector3.new(16, 1, 13), sf * CFrame.new(0, 0.5, 0), STONE, Enum.Material.Slate)
	for _, px in { -6.5, 6.5 } do
		for _, pz in { -4.8 } do
			block(
				shrine,
				"Pillar",
				Vector3.new(1.2, 10, 1.2),
				sf * CFrame.new(px, 6, pz),
				VERMILION,
				Enum.Material.Wood
			)
		end
	end
	roof(shrine, sf, 17, 13, 14.5)
	local offering = block(
		shrine,
		"OfferingBox",
		Vector3.new(4.5, 2.4, 2.4),
		sf * CFrame.new(0, 2.2, -3),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
	local shrineAnchor = addPrompt(offering, "OpenRebirth", "Rebirth", "Rebirth Shrine", 10)
	billboard(
		shrineAnchor,
		"Title",
		{ { "Name", "REBIRTH SHRINE", Color3.fromRGB(255, 214, 90) } },
		UDim2.fromScale(14, 2),
		13
	)
	glow(shrineAnchor, 16)
	shrine.PrimaryPart = shrineAnchor
	shrine.Parent = model

	-- Index board: a wooden frame holding a paper scroll, facing the plaza centre
	local index = Instance.new("Model")
	index.Name = "IndexBoard"
	local xf = facing(startCFrame, 116, -140, c.X, c.Y)
	for _, px in { -10.5, 10.5 } do
		block(index, "Post", Vector3.new(1, 11, 1), xf * CFrame.new(px, 5.5, 0), DARK_WOOD, Enum.Material.Wood)
	end
	local scroll =
		block(index, "Scroll", Vector3.new(19, 8, 0.4), xf * CFrame.new(0, 6.4, 0), PAPER, Enum.Material.Fabric)
	local sgui = Instance.new("SurfaceGui")
	sgui.Name = "Scroll"
	sgui.Face = Enum.NormalId.Front
	sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sgui.PixelsPerStud = 25
	sgui.LightInfluence = 0
	sgui.Parent = scroll
	for i, line in { { "Title", "RUNNER INDEX", 0, 0.55 }, { "Sub", "Every runner you have met", 0.6, 0.3 } } do
		local text = Instance.new("TextLabel")
		text.Name = line[1]
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromScale(0.05, line[3])
		text.Size = UDim2.fromScale(0.9, line[4])
		text.Font = UiTheme.Font
		text.TextScaled = true
		text.Text = line[2]
		text.TextColor3 = i == 1 and Color3.fromRGB(150, 30, 30) or DARK_WOOD
		text.Parent = sgui
	end
	index.PrimaryPart = addPrompt(scroll, "OpenIndex", "Open Index", "Runner Index", 12)
	index.Parent = model

	-- Leaderboard banners (docs/LEADERBOARD_SPEC.md): a row along the plaza's west edge, facing the spawn, under one
	-- tiled eave.
	-- The server (LeaderboardService) writes the rows.
	local boards = Instance.new("Model")
	boards.Name = "Leaderboards"
	local size = LeaderboardConfig.SIGN_SIZE
	for i, board in LeaderboardConfig.Boards do
		local sign = Instance.new("Part")
		sign.Name = "Board_" .. board.Id
		sign.Anchored = true
		sign.Size = size
		-- a quarter turn: the part's front (-Z) looks east, at the plaza centre
		sign.CFrame = frame
			* CFrame.new(LeaderboardConfig.SIGN_X, top + size.Y / 2, LeaderboardConfig.SIGN_Z[i])
			* CFrame.Angles(0, -math.pi / 2, 0)
		sign.Color = Color3.fromRGB(46, 30, 26)
		sign.Material = Enum.Material.WoodPlanks
		sign.TopSurface = Enum.SurfaceType.Smooth
		sign.BottomSurface = Enum.SurfaceType.Smooth
		sign.Parent = boards
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = sign
		local function line(name, order, height, colour, font)
			local label = Instance.new("TextLabel")
			label.Name = name
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, -24, height, 0)
			label.Position = UDim2.new(0, 12, order, 0)
			label.Font = font
			label.TextScaled = true
			label.TextColor3 = colour
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = ""
			UiTheme.Stroke(label, 2)
			label.Parent = gui
			return label
		end
		local title = line("Title", 0.02, 0.14, Color3.fromRGB(255, 214, 90), UiTheme.Font)
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.Text = board.Title
		for row = 1, LeaderboardConfig.TOP_N do
			line("Row" .. row, 0.18 + (row - 1) * 0.08, 0.07, Color3.new(1, 1, 1), UiTheme.Font)
		end
	end
	local zs = LeaderboardConfig.SIGN_Z
	local mid = (zs[1] + zs[#zs]) / 2
	local span = math.abs(zs[#zs] - zs[1]) + size.X
	local eave = frame * CFrame.new(LeaderboardConfig.SIGN_X, top + size.Y + 1, mid)
	block(boards, "Eave", Vector3.new(3.2, 0.8, span + 4), eave, ROOF_TILE, Enum.Material.Slate, false)
	boards.Parent = model

	-- The Best Roll Ever pedestal (docs/LEADERBOARD_SPEC.md 3a). LeaderboardService fills the labels and puts a runner
	-- on the CarMount; Client/BestRollView turns it.
	local cfg = LeaderboardConfig.BEST_ROLL
	local stoneDark, gold = Color3.fromRGB(110, 106, 100), Color3.fromRGB(230, 186, 80)
	-- A round platform: returns its Pedestal part (with CarMount on top) and a Stats billboard above it
	local function pedestal(parent, x, z, radius, statsSize, statsHeight, textDistance)
		-- name, bottom and top as fractions of HEIGHT, radius inset (the stripe sits in a groove)
		for _, layer in
			{ { "Pedestal", 0, 0.4, 0, stoneDark }, { "Stripe", 0.4, 0.6, 0.2, gold }, { "Top", 0.6, 1, 0, STONE } }
		do
			local disc = Instance.new("Part")
			disc.Name = layer[1]
			disc.Shape = Enum.PartType.Cylinder -- the axis is the part's X: turned upright below
			disc.Anchored = true
			local diameter = (radius - layer[4]) * 2
			disc.Size = Vector3.new((layer[3] - layer[2]) * cfg.HEIGHT, diameter, diameter)
			disc.CFrame = frame
				* CFrame.new(x, top + (layer[2] + layer[3]) / 2 * cfg.HEIGHT, z)
				* CFrame.Angles(0, 0, math.rad(90))
			disc.Color = layer[5]
			disc.Material = Enum.Material.Slate
			disc.TopSurface = Enum.SurfaceType.Smooth
			disc.BottomSurface = Enum.SurfaceType.Smooth
			disc.Parent = parent
		end
		local part = parent.Pedestal
		local mount = Instance.new("Attachment")
		mount.Name = "CarMount"
		mount.Parent = part
		mount.WorldCFrame = frame * CFrame.new(x, top + cfg.HEIGHT, z)
		local stats = Instance.new("BillboardGui")
		stats.Name = "Stats"
		stats.Size = statsSize -- studs: the text keeps its size in the world
		stats.Adornee = mount -- upright, unlike the turned cylinder: the offset below points straight up
		stats.StudsOffsetWorldSpace = Vector3.new(0, statsHeight, 0)
		stats.MaxDistance = textDistance
		stats.LightInfluence = 0
		stats.Parent = part
		return part, stats
	end
	local function stat(stats, name, y, height, colour, value)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, height)
		label.Font = UiTheme.Font
		label.TextScaled = true
		label.TextColor3 = colour
		UiTheme.Stroke(label, 2)
		label.Text = value
		label.Parent = stats
	end

	local best = Instance.new("Model")
	best.Name = "BestRoll"
	local _, bestStats = pedestal(best, cfg.X, cfg.Z, cfg.RADIUS, UDim2.fromScale(36, 11), 15, cfg.TEXT_DISTANCE)
	stat(bestStats, "Title", 0, 0.4, Color3.new(1, 1, 1), "BEST ROLL EVER")
	stat(bestStats, "Odds", 0.4, 0.22, Color3.fromRGB(255, 214, 90), LeaderboardConfig.NO_DATA)
	stat(bestStats, "Character", 0.62, 0.2, Color3.new(1, 1, 1), "")
	stat(bestStats, "Player", 0.82, 0.18, Color3.fromRGB(200, 220, 255), "")
	best.Parent = model

	-- The Checkpoints sensei (docs/CHECKPOINT_SPEC.md): a rig on a stone dais; its prompt opens Client/CheckpointUi.
	local npc = Instance.new("Model")
	npc.Name = "CheckpointNpc"
	local spot = CheckpointConfig.NPC_POS
	local here = world(startCFrame, spot.X, spot.Y, top)
	local face = world(startCFrame, CheckpointConfig.NPC_FACE.X, CheckpointConfig.NPC_FACE.Y, top)
	local stand = CFrame.lookAt(here, face)
	local dais = block(
		npc,
		"Dais",
		Vector3.new(0.6, 8, 8),
		stand * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		STONE,
		Enum.Material.Slate,
		false
	)
	dais.Shape = Enum.PartType.Cylinder
	-- Only the server can build a rig from a description; anywhere else the dais and prompt still work.
	local ok, rig = pcall(function()
		local look = Instance.new("HumanoidDescription")
		look.HeadColor = Color3.fromRGB(240, 204, 170)
		look.TorsoColor = Color3.fromRGB(240, 240, 232) -- a white training gi
		look.LeftArmColor = look.TorsoColor
		look.RightArmColor = look.TorsoColor
		look.LeftLegColor = Color3.fromRGB(40, 40, 60)
		look.RightLegColor = look.LeftLegColor
		return Players:CreateHumanoidModelFromDescription(look, Enum.HumanoidRigType.R6) -- R6: few parts
	end)
	if ok and rig then
		rig.Name = "Rig"
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		local humanoid = rig:FindFirstChildOfClass("Humanoid")
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		rig:PivotTo(stand * CFrame.new(0, 0.6 + 3, 0)) -- an R6 root stands 3 studs above the feet
		rig.Parent = npc
	end
	local anchor = prompt(
		npc,
		stand * CFrame.new(0, 3, 0),
		"OpenCheckpoints",
		"Checkpoints",
		"Choose your start",
		CheckpointConfig.PROMPT_DISTANCE
	)
	billboard(anchor, "Title", {
		{ "Name", "SENSEI", Color3.new(1, 1, 1) },
		{ "Sub", "Checkpoints: choose your start", Color3.fromRGB(255, 190, 140) },
	}, UDim2.fromScale(10, 2.4), 4.2, CheckpointConfig.TEXT_DISTANCE)
	npc.PrimaryPart = anchor
	npc.Parent = model

	-- Decoration: stone lanterns along the path to the gate, cherry trees between the buildings. Kept small: the
	-- world tests compare every plaza part with every track part in one go
	-- (every spot clears the Dojo ring and the buildings; checked by world_layout / workshop)
	local decor = Instance.new("Model")
	decor.Name = "Decor"
	local dir = Vector2.new(pc.X - c.X, pc.Y - c.Y).Unit
	local side = Vector2.new(-dir.Y, dir.X) * 10
	for _, x in { 95, 60 } do
		local p = c + dir * ((x - c.X) / dir.X)
		for _, s in { side, -side } do
			stoneLantern(decor, startCFrame, p.X + s.X, p.Y + s.Y)
		end
	end
	for _, p in { { 150, -30 }, { 62, -125 } } do
		cherryTree(decor, startCFrame, p[1], p[2])
	end
	decor.Parent = model
	return model
end

return SpawnArea
