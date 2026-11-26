--!nonstrict
-- The spawn hub: an anime town plaza (docs/WORLD_REDESIGN_SPEC.md section 4). A stone-paved square with the game's
-- only SpawnLocation at its centre, a torii StartGate over the StartPad (walking through it starts the run,
-- Server/RunnerService), the spawn terrace with the six service buildings (Shop, Potions, Market, Index, Best Roll, the
-- Sidekick summon altar) on a ring round it, every front facing the spawn (design doc 4.43, WORLD_REDESIGN_SPEC 4), and the
-- Checkpoints sensei beside the gate. Players join and respawn here on foot, and Stop sends them back
-- here. Each stall here is the plain stand-in for its mesh (Server/PlazaDressing): the prompt and collision stay on it,
-- the Market included.
-- Everything is placed in the local space of Track 1's flattened Start part (SpawnArea.Base; forward -Z, right +X).
-- Track 1 starts west of the plaza (local x 0) heading -Z and Track 2 runs along local z 90, so the plaza stays east
-- of Track 1's right wall (1.85 studs off since the 1.2x plaza, WORLD_REDESIGN_SPEC 4 "Plaza size") and clear of Track 2,
-- and the start gate stands at its north-west corner, next to Track 1's start. The walk spawn stays within 150 studs of
-- that start and 75 from any road (auto_toggle / spawn_area). Every spot is Shared/PlazaLayout's: approved, then moved.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local BossGateConfig = require(script.Parent.BossGateConfig)
local LeaderboardConfig = require(script.Parent.LeaderboardConfig)
local CheckpointConfig = require(script.Parent.CheckpointConfig)
local PlazaHeader = require(script.Parent.PlazaHeader)
local PlazaMerchants = require(script.Parent.PlazaMerchants)
local PlazaLayout = require(script.Parent.PlazaLayout)
local PlazaPieces = require(script.Parent.PlazaPieces)
local UiTheme = require(script.Parent.UiTheme)
local WorldConfig = require(script.Parent.WorldConfig)

local SpawnArea = {}

-- Hub-local (x, z) = world + TO_HUB: Track 1's start (TrackBuilder.CHAIN_ORIGIN) is world (-118, 80) heading -Z
SpawnArea.TO_HUB = Vector2.new(118, -80)
-- Hub-local spot of an anchor's approved world spot (Shared/PlazaLayout: the 1.2x plaza on world (20, 0))
local function hub(approved)
	return PlazaLayout.Spot(approved) + SpawnArea.TO_HUB
end
SpawnArea.Hub = hub
-- Hub-local spot of an approved world spot that moves with the spawn unscaled (PlazaLayout.Near)
local function near(approved)
	return PlazaLayout.Near(approved) + SpawnArea.TO_HUB
end
SpawnArea.CENTRE = hub(Vector2.zero) -- local (x, z) of the plaza centre (the Floor's centre and the Spawn)
SpawnArea.FLOOR_SIZE = PlazaLayout.APPROVED_FLOOR * PlazaLayout.SCALE -- studs (x, z) (placeholder, design doc 4.43)
SpawnArea.PAD_CENTRE = hub(Vector2.new(-84, 78)) -- local (x, z) of the StartPad, under the torii
SpawnArea.PAD_SIZE = 16
SpawnArea.TOP_Y = 1 -- floor top = road top
SpawnArea.START_COOLDOWN = 2 -- seconds after a stop or a pad start before the pad can start that player again
SpawnArea.WALK_ROOT_HEIGHT = 3 -- HumanoidRootPart height above the floor top when standing
SpawnArea.TAG = "StartPad"

local THICKNESS = 3 -- reaches the Baseplate top (y = -2) so the floor never shows a gap underneath
local PAD_RAISE = 0.2
local SPAWN_SIZE = 12
local LABEL_DISTANCE = 150
local GATE_POST_Z = 12 -- torii posts stand this far either side of the pad centre (proposed, design doc 4.24)
local GATE_HEIGHT = 34 -- post height above the floor (proposed; was 17)

-- Anime town palette (placeholders)
local STONE = Color3.fromRGB(158, 152, 140)
local VERMILION = Color3.fromRGB(205, 52, 36)
local BLACK = Color3.fromRGB(34, 30, 30)
local WOOD = Color3.fromRGB(150, 98, 60)
local DARK_WOOD = Color3.fromRGB(82, 52, 36)
local ROOF_TILE = Color3.fromRGB(58, 62, 72)
local PAPER = Color3.fromRGB(246, 236, 210)
local LANTERN_GLOW = Color3.fromRGB(255, 196, 120)

-- Spawn showpiece (owner 2026-11-11, design doc 4.43, WORLD_REDESIGN_SPEC 4): the six service buildings stand on a ring of
-- radius 84 round the spawn as approved (100.8 since the 1.2x plaza), every front facing it (CENTRE). Approved world spots;
-- mesh origins from tools/blender/plaza/build_plaza.py (ring_spot). The Shop, Potions, Market and Index keep their approved
-- distance from the spawn (owner rule "Readable from spawn" for their merchants' names; WORLD_REDESIGN_SPEC 4 "Plaza size").
local SHOP_POS = near(Vector2.new(-83.942, -3.109))
local POTIONS_POS = near(Vector2.new(-57.158, -61.555))
local MARKET_POS = near(Vector2.new(3.109, -83.942))
local INDEX_POS = near(Vector2.new(76.7, -34.2)) -- the fuller layout (WORLD_REDESIGN_SPEC 4.2)
local ALTAR_POS = hub(Vector2.new(57.158, 61.555))
-- The terrace under the spawn (4.43): step radii bottom up, each TERRACE_STEP tall; the SpawnLocation and the walk spawn
-- sit on the top step. Server/PlazaDressing lays the Showpiece mesh (spawn disc, moat, lanterns) over these plain steps.
SpawnArea.TERRACE = { 26, 20, 14 }
SpawnArea.TERRACE_STEP = 0.8
SpawnArea.SPAWN_TOP = SpawnArea.TOP_Y + #SpawnArea.TERRACE * SpawnArea.TERRACE_STEP

-- The Sidekick summon altar (design doc 4.36, docs/SIDEKICK_SPEC.md "Summon altar"): sizes proposed placeholders.
local ALTAR_TIERS = { 30, 23, 16 } -- octagon widths across the flats, bottom to top (about 32; 30 clears the sky-loop leg)
local ALTAR_TIER_HEIGHT = 1.2 -- per tier; a runner walks up them
local ALTAR_PILLAR_RADIUS = 7 -- pillars on the top tier's diagonals, outside the ring and clear of the stairs
local ALTAR_PILLAR_HEIGHT = 10
local ALTAR_HALO_RADIUS = 5 -- the client shows the rotation's Mythic inside it (Client/SidekickAltarView)
local ALTAR_HALO_HEIGHT = 7.5 -- halo centre above the top tier
local ALTAR_PROMPT_DISTANCE = 16 -- from the top tier's centre: reaches the bottom step
local ALTAR_STONE = Color3.fromRGB(176, 170, 160)
local ALTAR_DARK = Color3.fromRGB(46, 42, 52)
local ALTAR_GOLD = Color3.fromRGB(232, 178, 60)
local ALTAR_NEON = Color3.fromRGB(46, 200, 208)
-- The Team altar (design doc 4.45, owner 2026-11-17): a small stacked octagonal shrine facing the spawn, at the fuller
-- layout's spot (WORLD_REDESIGN_SPEC 4.2, owner 2026-11-25). Sizes and colours proposed.
local TEAM_ALTAR_POS = hub(Vector2.new(-35, 76.4))
local TEAM_ALTAR_WIDTH = 12 -- one octagonal slab across the flats (owner 2026-11-17: one slab, sakura emblem)
local TEAM_ALTAR_HEIGHT = 1.6
local TEAM_ALTAR_PINK = Color3.fromRGB(255, 150, 190)
local TEAM_ALTAR_PROMPT_DISTANCE = 12

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

-- Where an avatar stands on the plaza: the terrace top at its centre, facing the start gate.
function SpawnArea.WalkCFrame(startCFrame)
	local c, p = SpawnArea.CENTRE, SpawnArea.PAD_CENTRE
	return facing(startCFrame, c.X, c.Y, p.X, p.Y, SpawnArea.SPAWN_TOP + SpawnArea.WALK_ROOT_HEIGHT)
end

-- Spawn scatter (WORLD_REDESIGN_SPEC 4, owner 2026-11-26 "expand spawn location radius to your descretion"; lead's choice, every
-- number proposed): no avatar within Spacing studs of another at the walk spawn. Rings round it, each spot on the spawn disc
-- (radius 9.5).
SpawnArea.SCATTER = { Spacing = 3.5, Rings = { { Radius = 4, Spots = 6 }, { Radius = 8, Spots = 12 } } }

-- Where a player stands at the walk spawn `centre` (a CFrame) with other avatars at `occupied` (Vector3s): the centre when it is
-- free, else the first free spot of the rings (fixed spots; the search starts at `turn`, 0 to 1 of a lap, on each ring), else
-- the spot farthest from every avatar. Every spot keeps the centre's height and facing.
function SpawnArea.ScatterCFrame(centre, occupied, turn)
	local spacing = SpawnArea.SCATTER.Spacing
	local function nearest(cf)
		local best = math.huge
		for _, p in occupied do
			best = math.min(best, Vector2.new(p.X - cf.X, p.Z - cf.Z).Magnitude)
		end
		return best
	end
	if nearest(centre) >= spacing then
		return centre
	end
	local best, bestGap = centre, nearest(centre)
	for _, ring in SpawnArea.SCATTER.Rings do
		local first = math.floor((turn or 0) * ring.Spots)
		for j = 0, ring.Spots - 1 do
			local a = ((first + j) % ring.Spots) / ring.Spots * 2 * math.pi
			local cf = centre * CFrame.new(ring.Radius * math.cos(a), 0, ring.Radius * math.sin(a))
			local gap = nearest(cf)
			if gap >= spacing then
				return cf
			end
			if gap > bestGap then
				best, bestGap = cf, gap
			end
		end
	end
	return best
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

-- An octagonal slab `width` across the flats and `height` tall centred on `cframe`: 4 bars of the width by the edge
-- length, turned 45 degrees apart (their union is the octagon). Returns the 4 parts. Shared with Client/TeamUi's altars.
function SpawnArea.Octagon(parent, name, width, height, cframe, color, material, collide)
	local parts = {}
	for k = 0, 3 do
		parts[k + 1] = block(
			parent,
			name,
			Vector3.new(width, height, width * math.tan(math.pi / 8)),
			cframe * CFrame.Angles(0, k * math.pi / 4, 0),
			color,
			material,
			collide
		)
	end
	return parts
end

-- The Sakura altar (design doc 4.45, owner 2026-11-17 mockup: "one slab with a sakura logo embedded"): one octagonal
-- dark-wood slab `width` across and `height` tall standing on `cframe` (its base), a thin cyan neon rim round its top
-- edge, a soft pink glowing top and a five-petal sakura emblem inlaid in it. Shared by the plaza Team altar and the
-- Team Setup page. Returns { Slab, Rim, Top, Petals } part lists.
local SAKURA_WOOD = Color3.fromRGB(70, 42, 32)
local SAKURA_RIM = Color3.fromRGB(46, 200, 208)
local SAKURA_TOP = Color3.fromRGB(236, 104, 156)
local SAKURA_PETAL = Color3.fromRGB(255, 214, 230)
local SAKURA_HEART = Color3.fromRGB(255, 226, 150)
function SpawnArea.SakuraAltar(parent, cframe, width, height)
	local out = {}
	out.Slab = SpawnArea.Octagon(
		parent,
		"Slab",
		width,
		height,
		cframe * CFrame.new(0, height / 2, 0),
		SAKURA_WOOD,
		Enum.Material.Wood
	)
	-- The rim slab sits just under the top, so only its lip shows as a line.
	out.Rim = SpawnArea.Octagon(
		parent,
		"Rim",
		width + 0.3,
		0.2,
		cframe * CFrame.new(0, height - 0.14, 0),
		SAKURA_RIM,
		Enum.Material.Neon,
		false
	)
	out.Top = SpawnArea.Octagon(
		parent,
		"Top",
		width - 1,
		0.06,
		cframe * CFrame.new(0, height + 0.03, 0),
		SAKURA_TOP,
		Enum.Material.SmoothPlastic, -- Neon washes out to white in a ViewportFrame
		false
	)
	out.Petals = {}
	local r = width * 0.13
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5
		local petal = block(
			parent,
			"Petal",
			Vector3.new(r * 0.9, 0.08, r * 1.5),
			cframe * CFrame.new(0, height + 0.08, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r * 0.85),
			SAKURA_PETAL,
			Enum.Material.SmoothPlastic,
			false
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere -- an ellipse: the petal's outline
		mesh.Parent = petal
		table.insert(out.Petals, petal)
	end
	table.insert(
		out.Petals,
		block(
			parent,
			"Heart",
			Vector3.new(r * 0.5, 0.1, r * 0.5),
			cframe * CFrame.new(0, height + 0.1, 0),
			SAKURA_HEART,
			Enum.Material.SmoothPlastic,
			false
		)
	)
	return out
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

-- Where a merchant will stand (Shared/PlazaMerchants): an empty marker on `part`, in the service's frame.
local function merchantSpot(model, part, frame)
	local row = PlazaMerchants[model.Name]
	local spot = Instance.new("Attachment")
	spot.Name = "MerchantSpot"
	spot:SetAttribute("CharacterId", row.Id)
	spot.Parent = part
	spot.WorldCFrame = frame * CFrame.new(row.Feet)
end

-- The stand-ins of the uploaded stalls (Shared/PlazaPieces): plain blocks on the meshes' solid parts, read off their top views.
-- { name, size, centre, colour }; the first holds the prompt. Proposed.
local PIECE_STAND_INS = {
	SHOPStall = {
		{ "Counter", Vector3.new(9.6, 3.8, 2.6), Vector3.new(0, 1.9, -2.9), WOOD },
		{ "Deck", Vector3.new(16, 0.7, 11.6), Vector3.new(0, 0.35, 0), STONE },
		{ "BackWall", Vector3.new(12, 11, 1.4), Vector3.new(0, 5.5, 4.4), STONE },
		{ "SideWall", Vector3.new(2, 8, 5), Vector3.new(-8, 4, 1.4), STONE },
		{ "SideWall", Vector3.new(2, 8, 5), Vector3.new(8, 4, 1.4), STONE },
	},
	POTIONSStall = {
		{ "Counter", Vector3.new(9, 3.8, 2.6), Vector3.new(0, 1.9, -3), WOOD },
		{ "Deck", Vector3.new(14, 0.7, 10), Vector3.new(0, 0.35, 0), STONE },
		{ "BackWall", Vector3.new(8, 8.4, 1), Vector3.new(0, 4.2, 4.6), STONE },
		{ "Urn", Vector3.new(4, 5, 3.6), Vector3.new(-10.5, 2.5, -2.4), STONE },
		{ "Urn", Vector3.new(4, 5, 3.6), Vector3.new(10.5, 2.5, -2.4), STONE },
	},
	MarketStall = {
		{ "Counter", Vector3.new(12.6, 3.9, 2.6), Vector3.new(0, 1.95, -4), WOOD },
		{ "Deck", Vector3.new(20.6, 0.7, 10.6), Vector3.new(0, 0.35, 0), STONE },
		{ "BackWall", Vector3.new(19, 8.6, 0.6), Vector3.new(0, 4.3, 4.9), STONE },
		{ "SideWall", Vector3.new(0.6, 8.6, 4.9), Vector3.new(-9.5, 4.3, 2.45), STONE },
		{ "SideWall", Vector3.new(0.6, 8.6, 4.9), Vector3.new(9.5, 4.3, 2.45), STONE },
	},
	IndexBoard = {
		{ "Scroll", Vector3.new(12.4, 12.6, 0.8), Vector3.new(0, 6.3, 0.1), PAPER },
		{ "Deck", Vector3.new(24, 0.7, 6), Vector3.new(0, 0.35, -0.6), STONE },
		{ "Wing", Vector3.new(6, 8, 0.8), Vector3.new(-8.8, 4, 0), STONE },
		{ "Wing", Vector3.new(6, 8, 0.8), Vector3.new(8.8, 4, 0), STONE },
	},
}

-- Builds piece `key`'s stand-in in `m` at the service's frame, with its prompt, or returns nil until the piece is uploaded.
local function pieceStandIn(m, f, key, promptName, action, object, distance)
	if not PlazaPieces.Ready(key) then
		return nil
	end
	local first
	for _, row in PIECE_STAND_INS[key] do
		local part = block(m, row[1], row[2], f * CFrame.new(row[3]), row[4], Enum.Material.Slate)
		first = first or part
	end
	m.PrimaryPart = addPrompt(first, promptName, action, object, distance)
	merchantSpot(m, first, f)
	return first
end

-- A wooden market stall on the ring, facing the spawn: counter (with the prompt), posts, a tiled roof, a cloth curtain
-- with its sign.
local function stall(parent, startCFrame, name, x, z, cloth, title, promptName, action, piece)
	local m = Instance.new("Model")
	m.Name = name
	local f = facing(startCFrame, x, z, SpawnArea.CENTRE.X, SpawnArea.CENTRE.Y)
	if pieceStandIn(m, f, piece, promptName, action, title, 10) then
		m.Parent = parent
		return m
	end
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
	merchantSpot(m, counter, f)
	m.Parent = parent
	return m
end

-- The torii over the pad, turned to face the plaza centre (design doc 4.24): two vermilion posts either side of the pad, the
-- nuki tie beam, the kasagi top beam with its black cap and upturned tips, and a plaque with made-up text. Posts and
-- footings collide; the opening over the pad is free.
local function torii(startCFrame)
	local pc = SpawnArea.PAD_CENTRE
	local gate = Instance.new("Model")
	gate.Name = "StartGate"
	local c = SpawnArea.CENTRE
	local gf = base(startCFrame)
		* CFrame.lookAt(Vector3.new(pc.X, SpawnArea.TOP_Y, pc.Y), Vector3.new(c.X, SpawnArea.TOP_Y, c.Y))
	local h, w = GATE_HEIGHT, GATE_POST_Z
	for _, side in { -1, 1 } do
		block(gate, "Post", Vector3.new(2.2, h, 2.2), gf * CFrame.new(side * w, h / 2, 0), VERMILION)
	end
	block(gate, "Nuki", Vector3.new(w * 2 + 4, 1.2, 1.4), gf * CFrame.new(0, h - 3.5, 0), VERMILION, nil, false)
	local kasagi =
		block(gate, "Kasagi", Vector3.new(w * 2 + 5, 1.4, 2.6), gf * CFrame.new(0, h + 0.7, 0), VERMILION, nil, false)
	block(gate, "Cap", Vector3.new(w * 2 + 7, 1, 3), gf * CFrame.new(0, h + 1.9, 0), BLACK, nil, false)
	local plaque = block(gate, "Plaque", Vector3.new(3, 2.6, 0.6), gf * CFrame.new(0, h - 1.2, 0), BLACK, nil, false)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		surfaceText(plaque, face, "Plaque" .. face.Name, "RUN", Color3.fromRGB(255, 214, 90))
	end
	gate.PrimaryPart = kasagi
	return gate
end

-- The Sidekick summon altar (design doc 4.36), plain Parts so it adds nothing to load, an original design: three
-- octagonal stone tiers with steps on the path side, 4 dark pillars with gold caps, a neon ring on the top tier and a
-- vertical gold halo facing the path. Its prompt is the old stall's (Client/PlazaPrompts opens the summon page, which
-- shows the rebirth lock); Client/SidekickAltarView shows the rotation's Mythic at the ModelSpot attachment.
-- The uploaded altars' stand-ins (Shared/PlazaPieces): their tiers, steps and the stand the model is on, at the drafts' sizes
-- (tools/blender/plaza/draft_altar.py); the meshes do not collide. `f`: the floor at its centre, -Z the front.
local ALTAR_STAIRS = { GreatLotus = 11, TwinRoof = 18 } -- width
local function pieceAltar(m, f, piece)
	m:SetAttribute("Look", piece.Look)
	local function disc(name, height, radius, y, z)
		local p = block(
			m,
			name,
			Vector3.new(height, radius * 2, radius * 2),
			f * CFrame.new(0, y + height / 2, z or 0) * CFrame.Angles(0, 0, math.rad(90)),
			ALTAR_STONE,
			Enum.Material.Slate
		)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function slab(name, size, x, y, z)
		return block(m, name, size, f * CFrame.new(x, y + size.Y / 2, z), ALTAR_STONE, Enum.Material.Slate)
	end
	local rise, fronts, last
	if piece.Look == "GreatLotus" then
		rise, fronts = 1.2, { -18.4, -16, -12.6 }
		for i, radius in { 18.4, 16, 12.6 } do
			last = disc("Tier", rise, radius, (i - 1) * rise)
		end
		disc("Stand", piece.Stand - 3.6, 6, 3.6)
	else
		rise, fronts = 1.4, { -16, -13, -10.2 }
		-- each deck: its full width between the cut corners, and the front strip between them
		for i, row in { { 33.4, 19.2 }, { 32.2, 18.4 }, { 31, 17.6 } } do
			local half, front, back = row[1], fronts[i], row[2]
			local y = (i - 1) * rise
			local from, to = front + 9, back - 6
			last = slab("Tier", Vector3.new(half * 2, rise, to - from), 0, y, (from + to) / 2)
			slab("Front", Vector3.new((half - 9) * 2, rise, 9), 0, y, front + 4.5)
			slab("Back", Vector3.new((half - 6) * 2, rise, 6), 0, y, back - 3)
		end
		disc("Stand", piece.Stand - 4.2, 7, 4.2, -piece.Ahead)
		for _, x in { -24, 24 } do -- the two pagodas
			slab("Tower", Vector3.new(9, 12, 10), x, 4.2, 7.5)
		end
	end
	for i, front in fronts do -- a half step before each tier's front
		slab("Step", Vector3.new(ALTAR_STAIRS[piece.Look], rise / 2, 1.2), 0, (i - 1) * rise, front - 0.6)
	end
	local function spot(name, cf)
		local at = Instance.new("Attachment")
		at.Name = name
		at.Parent = last
		at.WorldCFrame = cf
	end
	spot("ModelSpot", f * CFrame.new(0, piece.Stand + piece.ModelSize / 2, -piece.Ahead))
	spot("LockSpot", f * CFrame.new(piece.Lock))
	glow(last, 20)
	-- the prompt's own part, in front of the model's stand: within reach from the steps
	m.PrimaryPart =
		prompt(m, f * CFrame.new(0, piece.Stand, -4.9), "OpenSidekicks", "Summon", "SIDEKICKS", ALTAR_PROMPT_DISTANCE)
	return m
end

local function altar(startCFrame)
	local m = Instance.new("Model")
	m.Name = "SidekickAltar"
	local af = facing(startCFrame, ALTAR_POS.X, ALTAR_POS.Y, SpawnArea.CENTRE.X, SpawnArea.CENTRE.Y, 0)
	local piece = PlazaPieces.Altar()
	if piece then
		return pieceAltar(m, af * CFrame.new(0, SpawnArea.TOP_Y, 0), piece)
	end
	local h, side = ALTAR_TIER_HEIGHT, math.tan(math.pi / 8)
	local top = SpawnArea.TOP_Y
	local topPart
	for i, width in ALTAR_TIERS do
		local tierY = top + (i - 1) * h
		-- An octagon is 4 bars of its width by its edge length, turned 45 degrees apart
		for k = 0, 3 do
			local bar = block(
				m,
				"Tier" .. i,
				Vector3.new(width, h, width * side),
				af * CFrame.new(0, tierY + h / 2, 0) * CFrame.Angles(0, k * math.pi / 4, 0),
				i == 2 and STONE or ALTAR_STONE,
				Enum.Material.Slate
			)
			if i == #ALTAR_TIERS and k == 0 then
				topPart = bar
			end
		end
		-- A half step in front of the tier's path-side flat (its front is -Z)
		block(
			m,
			"Step",
			Vector3.new(width * side, h / 2, 2),
			af * CFrame.new(0, tierY + h / 4, -width / 2 - 1),
			ALTAR_STONE,
			Enum.Material.Slate
		)
	end
	local deck = top + #ALTAR_TIERS * h
	local r = ALTAR_PILLAR_RADIUS
	for k = 0, 3 do
		local spot = af * CFrame.Angles(0, math.pi / 4 + k * math.pi / 2, 0) * CFrame.new(0, 0, -r)
		block(
			m,
			"Pillar",
			Vector3.new(1.6, ALTAR_PILLAR_HEIGHT, 1.6),
			spot * CFrame.new(0, deck + ALTAR_PILLAR_HEIGHT / 2, 0),
			ALTAR_DARK,
			Enum.Material.Basalt
		)
		block(
			m,
			"Cap",
			Vector3.new(2.3, 0.8, 2.3),
			spot * CFrame.new(0, deck + ALTAR_PILLAR_HEIGHT + 0.4, 0),
			ALTAR_GOLD,
			Enum.Material.Metal,
			false
		)
	end
	local ringApothem = ALTAR_TIERS[#ALTAR_TIERS] / 2 - 2.4
	for k = 0, 7 do
		local seg = block(
			m,
			"Ring",
			Vector3.new(2 * ringApothem * side + 0.4, 0.1, 0.5),
			af * CFrame.Angles(0, k * math.pi / 4, 0) * CFrame.new(0, deck + 0.05, -ringApothem),
			ALTAR_NEON,
			Enum.Material.Neon,
			false
		)
		seg.CastShadow = false
	end
	local haloY, segments = deck + ALTAR_HALO_HEIGHT, 20
	for i = 0, segments - 1 do
		local a = i * 2 * math.pi / segments
		local seg = block(
			m,
			"Halo",
			Vector3.new(2 * ALTAR_HALO_RADIUS * math.tan(math.pi / segments) + 0.1, 0.5, 0.5),
			af
				* CFrame.new(0, haloY, 0)
				* CFrame.Angles(0, 0, a)
				* CFrame.new(ALTAR_HALO_RADIUS, 0, 0)
				* CFrame.Angles(0, 0, math.pi / 2),
			ALTAR_GOLD,
			Enum.Material.Neon,
			false
		)
		seg.CastShadow = false
	end
	local modelSpot = Instance.new("Attachment")
	modelSpot.Name = "ModelSpot"
	modelSpot.Parent = topPart
	modelSpot.WorldCFrame = af * CFrame.new(0, haloY, 0) -- -Z faces the path
	glow(topPart, 20)
	m.PrimaryPart = addPrompt(topPart, "OpenSidekicks", "Summon", "SIDEKICKS", ALTAR_PROMPT_DISTANCE)
	return m
end

-- The Team altar (design doc 4.45): dark wood and stone tiers, each topped by a thin cyan edge, a faint sakura glow
-- on the top; its prompt opens Team Setup (Client/PlazaPrompts).
local function teamAltar(startCFrame)
	local m = Instance.new("Model")
	m.Name = "TeamAltar"
	local af = facing(startCFrame, TEAM_ALTAR_POS.X, TEAM_ALTAR_POS.Y, SpawnArea.CENTRE.X, SpawnArea.CENTRE.Y, 0)
	local slab = SpawnArea.SakuraAltar(m, af * CFrame.new(0, SpawnArea.TOP_Y, 0), TEAM_ALTAR_WIDTH, TEAM_ALTAR_HEIGHT)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = TEAM_ALTAR_PINK, 0.8, 10, false
	light.Parent = slab.Top[1]
	m.PrimaryPart = addPrompt(slab.Slab[1], "OpenTeam", "Team", "TEAM SETUP", TEAM_ALTAR_PROMPT_DISTANCE)
	return m
end

-- The world gate (design doc 4.47, docs/WORLD2_SPEC.md "Gate"): an original rift ring on the plaza's south-east corner,
-- clear of the ring of stalls, facing the spawn. In World 1 it leads to World 2 and is locked (chains, a padlock plate, a
-- solid barrier, "COMING SOON") until WorldConfig.GATE_OPEN; admins use /world2. In World 2 it is open and leads back to
-- World 1: its Portal part (tag WorldGate, attribute TargetWorld) sends a runner on touch (Server/WorldTravel). Sizes and
-- colours proposed.
SpawnArea.WORLD_GATE_POS = hub(Vector2.new(76, -96)) -- hub-local (x, z)
SpawnArea.WORLD_GATE_TAG = "WorldGate"
local RING_RADIUS = 11
local RING_SEGMENTS = 16

-- The uploaded gatehouse's stand-in (Shared/PlazaPieces, draft_gate.py B): dais, two jamb walls and a lintel round a doorway 17.2 wide
-- and 24.2 high, its touch part filling the doorway from a runner's feet, the label over the roof (36.5).
local function pieceGate(m, f, target, locked, swirl)
	SpawnArea.Octagon(m, "Dais", 30, 1.2, f * CFrame.new(0, 0.6, 0), STONE, Enum.Material.Slate)
	for _, side in { -1, 1 } do
		block(m, "Jamb", Vector3.new(7.6, 26, 4), f * CFrame.new(side * 12.4, 13, 0), DARK_WOOD, Enum.Material.Wood)
	end
	block(m, "Lintel", Vector3.new(34, 4, 5), f * CFrame.new(0, 28, 0), ROOF_TILE, Enum.Material.Slate, false)
	local portal =
		block(m, "Portal", Vector3.new(16.6, 23, 1), f * CFrame.new(0, 12.7, 0), swirl, Enum.Material.Neon, false)
	portal.Transparency = locked and 0 or 0.25
	portal:SetAttribute("TargetWorld", target)
	portal:SetAttribute("Locked", locked)
	if locked then
		portal.Color = Color3.fromRGB(74, 34, 144)
		portal.Material = Enum.Material.SmoothPlastic
		local wall = block(m, "Barrier", Vector3.new(17.2, 24.2, 1), f * CFrame.new(0, 12.1, -0.6), BLACK)
		wall.Transparency = 1
		wall:SetAttribute("TargetWorld", target)
		wall:SetAttribute("Locked", true)
		CollectionService:AddTag(wall, SpawnArea.WORLD_GATE_TAG)
	else
		portal.CanTouch = true
		CollectionService:AddTag(portal, SpawnArea.WORLD_GATE_TAG)
	end
	local light = Instance.new("PointLight")
	light.Color = swirl
	light.Brightness = 2
	light.Range = 24
	light.Shadows = false
	light.Parent = portal
	billboard(portal, "Label", {
		{ "Title", target == 2 and "WORLD 2" or "WORLD 1", Color3.fromRGB(235, 220, 255) },
		{ "State", locked and "COMING SOON" or "ENTER", Color3.fromRGB(255, 214, 90) },
	}, UDim2.fromOffset(220, 70), 27, LABEL_DISTANCE)
	m.PrimaryPart = portal
	return m
end

local function worldGate(startCFrame)
	local target = WorldConfig.Id == 1 and 2 or 1
	local locked = target == 2 and not WorldConfig.GATE_OPEN
	local swirl = target == 2 and Color3.fromRGB(150, 70, 255) or Color3.fromRGB(70, 210, 255)
	local m = Instance.new("Model")
	m.Name = "WorldGate"
	local pos = SpawnArea.WORLD_GATE_POS
	local f = facing(startCFrame, pos.X, pos.Y, SpawnArea.CENTRE.X, SpawnArea.CENTRE.Y)
	if PlazaPieces.GateReady(locked) then
		return pieceGate(m, f, target, locked, swirl)
	end
	local centre = f * CFrame.new(0, RING_RADIUS + 3, 0)
	-- Dais and two leaning obsidian monoliths
	SpawnArea.Octagon(m, "Dais", 30, 1.2, f * CFrame.new(0, 0.6, 0), STONE, Enum.Material.Slate)
	for _, side in { -1, 1 } do
		block(
			m,
			"Monolith",
			Vector3.new(3.4, RING_RADIUS * 2 + 8, 4),
			f * CFrame.new(side * (RING_RADIUS + 3.5), RING_RADIUS + 4, 0) * CFrame.Angles(0, 0, math.rad(side * 6)),
			BLACK,
			Enum.Material.Basalt
		)
	end
	-- The ring: stone segments with a neon inner lip
	for i = 0, RING_SEGMENTS - 1 do
		local a = i / RING_SEGMENTS * math.pi * 2
		local seg = centre * CFrame.Angles(0, 0, a) * CFrame.new(0, RING_RADIUS, 0)
		local len = 2 * math.pi * RING_RADIUS / RING_SEGMENTS + 0.6
		block(m, "Ring", Vector3.new(len, 2.4, 3), seg, Color3.fromRGB(70, 64, 80), Enum.Material.Slate, false)
		block(m, "RingGlow", Vector3.new(len, 0.4, 3.2), seg * CFrame.new(0, -1.3, 0), swirl, Enum.Material.Neon, false)
	end
	-- The portal face
	local portal = block(
		m,
		"Portal",
		Vector3.new(0.4, RING_RADIUS * 2 - 1.5, RING_RADIUS * 2 - 1.5),
		centre * CFrame.Angles(0, math.rad(90), 0),
		swirl,
		Enum.Material.Neon,
		false
	)
	portal.Shape = Enum.PartType.Cylinder
	portal.Transparency = locked and 0 or 0.25
	if locked then
		portal.Color = Color3.fromRGB(74, 34, 144) -- dim, sealed: the chains read in front of it (Blender draft)
		portal.Material = Enum.Material.SmoothPlastic
	end
	portal:SetAttribute("TargetWorld", target)
	portal:SetAttribute("Locked", locked)
	if not locked then
		portal.CanTouch = true
		CollectionService:AddTag(portal, SpawnArea.WORLD_GATE_TAG)
	end
	if locked then
		-- Crossed chains and a padlock plate; an invisible wall so nobody walks into the ring
		for _, tilt in { 40, -40 } do
			block(
				m,
				"Chain",
				Vector3.new(RING_RADIUS * 2.1, 1.4, 1.4),
				centre * CFrame.new(0, 0, -1.2) * CFrame.Angles(0, 0, math.rad(tilt)),
				Color3.fromRGB(120, 116, 110),
				Enum.Material.DiamondPlate,
				false
			)
		end
		local lock = block(
			m,
			"Padlock",
			Vector3.new(5, 5.6, 1.8),
			centre * CFrame.new(0, -0.8, -2.2),
			Color3.fromRGB(214, 168, 60),
			Enum.Material.Metal,
			false
		)
		block(
			m,
			"Shackle",
			Vector3.new(3.2, 3, 1),
			lock.CFrame * CFrame.new(0, 3.8, 0),
			Color3.fromRGB(150, 150, 150),
			Enum.Material.Metal,
			false
		)
		local wall = block(
			m,
			"Barrier",
			Vector3.new(RING_RADIUS * 2 + 4, RING_RADIUS * 2 + 6, 1),
			f * CFrame.new(0, RING_RADIUS + 3, 0),
			BLACK
		)
		wall.Transparency = 1
		-- touching it tells the player why (Server/WorldTravel: "COMING SOON")
		wall:SetAttribute("TargetWorld", target)
		wall:SetAttribute("Locked", true)
		CollectionService:AddTag(wall, SpawnArea.WORLD_GATE_TAG)
	end
	local light = Instance.new("PointLight")
	light.Color = swirl
	light.Brightness = 2
	light.Range = 24
	light.Shadows = false
	light.Parent = portal
	billboard(portal, "Label", {
		{ "Title", target == 2 and "WORLD 2" or "WORLD 1", Color3.fromRGB(235, 220, 255) },
		{ "State", locked and "COMING SOON" or "ENTER", Color3.fromRGB(255, 214, 90) },
	}, UDim2.fromOffset(220, 70), RING_RADIUS + 6, LABEL_DISTANCE)
	m.PrimaryPart = portal
	return m
end
SpawnArea.WorldGate = worldGate

-- The boss gate's plain stand-in (WORLD_REDESIGN_SPEC 4.2; place, prompt and mesh slots in Shared/BossGateConfig): a stepped
-- dais, two spires and a stone ring round shut doors (closed) or a fire (open), in draft A's box. Built closed. Nobody walks
-- through: its prompt opens the Bosses popup (Client/BossEventUi). Sizes and colours proposed.
local BOSS_STONE, BOSS_RING = Color3.fromRGB(112, 96, 93), Color3.fromRGB(138, 58, 50)
local BOSS_DARK, BOSS_FIRE = Color3.fromRGB(46, 40, 41), Color3.fromRGB(255, 122, 30)
local BOSS_CENTRE, BOSS_OPENING = 13.4, 8.8 -- the opening's centre height and radius (draft_boss_gate.py C, RI)

local function bossGate(startCFrame)
	local m = Instance.new("Model")
	m.Name = "BossGate"
	local c, pos, size = SpawnArea.CENTRE, BossGateConfig.POS, BossGateConfig.SIZE
	local f = facing(startCFrame, pos.X + c.X, pos.Y + c.Y, c.X, c.Y)
	-- Four steps a runner climbs, the widest the draft's whole base
	local steps, rise = 4, 1.1
	for i = 1, steps do
		local depth = size.Z - (i - 1) * 4
		local width = i == 1 and size.X or 34 - (i - 1) * 2
		block(
			m,
			"Step",
			Vector3.new(width, rise, depth),
			f * CFrame.new(0, (i - 0.5) * rise, 0),
			BOSS_STONE,
			Enum.Material.Slate
		)
	end
	for _, side in { -1, 1 } do
		block(
			m,
			"Spire",
			Vector3.new(4, 26, 5),
			f * CFrame.new(side * 13.4, 15, 0) * CFrame.Angles(0, 0, math.rad(side * 3)),
			BOSS_DARK,
			Enum.Material.Basalt
		)
	end
	local centre = f * CFrame.new(0, BOSS_CENTRE, 0)
	local segments, ringRadius = 16, BOSS_OPENING + 1.5
	for i = 0, segments - 1 do
		block(
			m,
			"Ring",
			Vector3.new(2 * ringRadius * math.tan(math.pi / segments) + 0.8, 3, 4),
			centre * CFrame.Angles(0, 0, i / segments * 2 * math.pi) * CFrame.new(0, ringRadius, 0),
			BOSS_RING,
			Enum.Material.Slate,
			i == 0 or i > segments / 2 -- the top half is out of reach
		)
	end
	for _, side in { -1, 1 } do
		local door = block(
			m,
			"Door",
			Vector3.new(BOSS_OPENING, BOSS_OPENING * 2, 1.6),
			centre * CFrame.new(side * BOSS_OPENING / 2, 0, 0),
			BOSS_DARK,
			Enum.Material.Metal
		)
		CollectionService:AddTag(door, BossGateConfig.CLOSED_TAG)
	end
	local fire = block(
		m,
		"Fire",
		Vector3.new(1.4, BOSS_OPENING * 2, BOSS_OPENING * 2),
		centre * CFrame.Angles(0, math.rad(90), 0),
		BOSS_FIRE,
		Enum.Material.Neon,
		false
	)
	fire.Shape = Enum.PartType.Cylinder
	fire.Transparency = 1
	fire.CastShadow = false
	CollectionService:AddTag(fire, BossGateConfig.OPEN_TAG)
	-- The model's frame, at the spot's centre on the floor; the prompt stands in front of the gate
	local root = block(m, "Root", Vector3.one, f * CFrame.new(0, 0.5, 0), BOSS_STONE, nil, false)
	root.Transparency = 1
	root.CastShadow = false
	m.PrimaryPart = root
	local at = BossGateConfig.PROMPT_OFFSET
	prompt(
		m,
		f * CFrame.new(at.X, 3 + (steps - 1) * rise, -at.Y),
		BossGateConfig.PROMPT,
		"Bosses",
		"BOSS GATE",
		BossGateConfig.PROMPT_DISTANCE
	)
	return m
end
SpawnArea.BossGate = bossGate

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
		Color3.fromRGB(205, 187, 158), -- warm paving (design doc 4.24, placeholder)
		Enum.Material.Pavement
	)
	model.PrimaryPart = floor

	-- The terrace under the spawn (design doc 4.43): stone steps a runner walks up, the Showpiece mesh laid over them
	for i, radius in SpawnArea.TERRACE do
		local step = block(
			model,
			"Terrace" .. i,
			Vector3.new(SpawnArea.TERRACE_STEP, radius * 2, radius * 2),
			frame * CFrame.new(c.X, top + (i - 0.5) * SpawnArea.TERRACE_STEP, c.Y) * CFrame.Angles(0, 0, math.rad(90)),
			STONE,
			Enum.Material.Slate
		)
		step.Shape = Enum.PartType.Cylinder
	end

	-- The one SpawnLocation, on the terrace top at the plaza centre
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(SPAWN_SIZE, 1, SPAWN_SIZE)
	spawn.CFrame = frame * CFrame.new(c.X, SpawnArea.SPAWN_TOP + 0.05 - 0.5, c.Y) -- a hair above the step so the two never z-fight
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
		UDim2.fromOffset(130, 32),
		20,
		60
	)
	glow(pad, 18)
	torii(startCFrame).Parent = model
	worldGate(startCFrame).Parent = model

	-- The ring (same panels and remotes as before): each stand-in's origin is its mesh's origin (Shared/PlazaAssets).
	-- The Sidekicks stall became the summon altar (design doc 4.36).
	altar(startCFrame).Parent = model
	teamAltar(startCFrame).Parent = model
	if BossGateConfig.LIVE then
		bossGate(startCFrame).Parent = model
	end
	stall(
		model,
		startCFrame,
		"ShopStall",
		SHOP_POS.X,
		SHOP_POS.Y,
		Color3.fromRGB(40, 90, 170),
		"SHOP",
		"OpenShop",
		"Open Shop",
		"SHOPStall"
	)
	stall(
		model,
		startCFrame,
		"PotionsStall",
		POTIONS_POS.X,
		POTIONS_POS.Y,
		Color3.fromRGB(120, 60, 160),
		"POTIONS",
		"OpenPotions",
		"Potions",
		"POTIONSStall"
	)
	-- The Market, sized to its MarketStall mesh (same origin; the deck front is 5.5 ahead). Deck, counter, front posts and
	-- the closed rear collide; the curtains are cloth and the roof is out of reach.
	local marketplace = Instance.new("Model")
	marketplace.Name = "Marketplace"
	local mf = facing(startCFrame, MARKET_POS.X, MARKET_POS.Y, SpawnArea.CENTRE.X, SpawnArea.CENTRE.Y)
	local marketCounter = pieceStandIn(marketplace, mf, "MarketStall", "OpenMarket", "Browse Market", "Market", 8)
	if not marketCounter then
		block(
			marketplace,
			"Deck",
			Vector3.new(20, 0.5, 11),
			mf * CFrame.new(0, 0.25, 0),
			WOOD,
			Enum.Material.WoodPlanks
		)
		marketCounter = block(
			marketplace,
			"Counter",
			Vector3.new(12.4, 3.9, 2.6),
			mf * CFrame.new(0, 2.45, -3.8),
			WOOD,
			Enum.Material.WoodPlanks
		)
		for _, px in { -9.5, -6.6, 6.6, 9.5 } do
			block(
				marketplace,
				"Post",
				Vector3.new(0.9, 8.6, 0.9),
				mf * CFrame.new(px, 4.6, -4.9),
				DARK_WOOD,
				Enum.Material.Wood
			)
		end
		block(
			marketplace,
			"BackWall",
			Vector3.new(19, 8.6, 0.6),
			mf * CFrame.new(0, 4.6, 4.9),
			DARK_WOOD,
			Enum.Material.Wood
		)
		for _, px in { -9.5, 9.5 } do
			block(
				marketplace,
				"SideWall",
				Vector3.new(0.6, 8.6, 4.9),
				mf * CFrame.new(px, 4.6, 2.45),
				DARK_WOOD,
				Enum.Material.Wood
			)
		end
		block(
			marketplace,
			"Roof",
			Vector3.new(23, 0.6, 14),
			mf * CFrame.new(0, 9.2, 0),
			ROOF_TILE,
			Enum.Material.Slate,
			false
		)
		local marketCurtain = block(
			marketplace,
			"Curtain",
			Vector3.new(12.2, 2.2, 0.2),
			mf * CFrame.new(0, 7.6, -4.8),
			Color3.fromRGB(122, 63, 184),
			Enum.Material.Fabric,
			false
		)
		UiTheme.Stroke(surfaceText(marketCurtain, Enum.NormalId.Front, "Sign", "MARKET", Color3.new(1, 1, 1), 25), 2)
		marketplace.PrimaryPart = addPrompt(marketCounter, "OpenMarket", "Browse Market", "Market", 8)
		merchantSpot(marketplace, marketCounter, mf)
	end
	CollectionService:AddTag(marketCounter, "MarketPad") -- after the prompt: Server/MarketService reads it when tagged
	marketplace.Parent = model

	-- Index board: a wooden frame holding a paper scroll
	local index = Instance.new("Model")
	index.Name = "IndexBoard"
	local xf = facing(startCFrame, INDEX_POS.X, INDEX_POS.Y, SpawnArea.CENTRE.X, SpawnArea.CENTRE.Y)
	if not pieceStandIn(index, xf, "IndexBoard", "OpenIndex", "Open Index", "Runner Index", 12) then
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
		merchantSpot(index, scroll, xf)
	end
	index.Parent = model

	-- Leaderboard banners removed (design doc 4.16, owner 2026-11-01); their data stores are left untouched.

	-- The Best Roll Ever pedestal (docs/LEADERBOARD_SPEC.md 3a). LeaderboardService fills the labels and puts a runner
	-- on the CharacterMount; Client/BestRollView turns it.
	local cfg = LeaderboardConfig.BEST_ROLL
	local stoneDark, gold = Color3.fromRGB(110, 106, 100), Color3.fromRGB(230, 186, 80)
	-- A round platform: returns its Pedestal part (with CharacterMount on top) and a Stats billboard above it
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
		mount.Name = "CharacterMount"
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
	local _, bestStats = pedestal(best, cfg.X, cfg.Z, cfg.RADIUS, UDim2.fromScale(36, 11), 26, cfg.TEXT_DISTANCE)
	stat(bestStats, "Title", 0, 0.4, Color3.new(1, 1, 1), "BEST ROLL EVER")
	stat(bestStats, "Odds", 0.4, 0.22, Color3.fromRGB(255, 214, 90), LeaderboardConfig.NO_DATA)
	stat(bestStats, "Character", 0.62, 0.2, Color3.new(1, 1, 1), "")
	stat(bestStats, "Player", 0.82, 0.18, Color3.fromRGB(200, 220, 255), "")
	best.Parent = model

	-- The sensei (design doc 4.15, checkpoints): a rig on a stone dais; its prompt opens the Tracks panel
	-- (Client/CheckpointUi).
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
		"Tracks",
		"Track overview",
		CheckpointConfig.PROMPT_DISTANCE
	)
	local title = PlazaHeader.Build(
		anchor,
		"Title",
		"SENSEI",
		"Star",
		Color3.fromRGB(244, 124, 32),
		UDim2.new(9, 40, 3.4, 16),
		CheckpointConfig.TEXT_DISTANCE
	)
	title.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	npc.PrimaryPart = anchor
	merchantSpot(npc, anchor, stand)
	npc.Parent = model

	-- Decoration: Server/PlazaDressing places the meshes (design doc 4.24).
	return model
end

return SpawnArea
