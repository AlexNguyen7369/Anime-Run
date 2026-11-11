--!nonstrict
-- Slice 2 of the enclosed cyber dojo (design doc 4.24, owner 2026-11-10): the RACE START gate. A holo arch with a
-- scanning ring over the StartPad, and a closed blast door in the wall behind it, on the spawn-to-pad axis. The run
-- still starts as before (CarService: the StartPad touch or Remotes.SetAutoRace, both through SetAutoRace, which sets
-- the player attribute AutoRacing); Client/CyberPlaza opens the door for that player from AutoRacing. The torii stand-in
-- (SpawnArea.StartGate) stays for its collision and test contract, unseen. Hybrid look (4.24, owner 2026-11-10): a gold
-- arch with a soft cyan scanning ring, red lacquer door leaves with gold bands in a dark wood frame, a lacquer RACE
-- START board on the header. Sizes and colours are proposed.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CyberPlaza = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CyberPlaza"))

local C = CyberPlaza.Colors
local Part, Neon = CyberPlaza.Part, CyberPlaza.Neon
local TOP, H, T = CyberPlaza.TOP, CyberPlaza.WALL_HEIGHT, CyberPlaza.WALL_THICKNESS
local W, DH, FRAME = CyberPlaza.DOOR_WIDTH, CyberPlaza.DOOR_HEIGHT, CyberPlaza.FRAME

local ARCH_RADIUS = 12 -- the arch's feet stand where the torii stand-in's posts collide (SpawnArea GATE_POST_Z)
local ARCH_SEGMENTS = 14
local ARCH_THICKNESS = 1.2
local SCAN_RADIUS = 5
local SCAN_HEIGHT = 7 -- ring centre above the floor
local CHEVRONS = 6

local CyberGate = {}

local function hide(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CastShadow = false
		elseif d:IsA("SurfaceGui") then
			d.Enabled = false
		end
	end
end

local function arch(parent, pad)
	local here = Vector3.new(pad.Position.X, TOP, pad.Position.Z)
	local axis = Vector3.new(here.X, 0, here.Z).Unit
	local frame = CFrame.lookAt(here, here + axis) -- X across the path, Y up
	local length = 2 * ARCH_RADIUS * math.tan(math.pi / (2 * ARCH_SEGMENTS)) + 0.05
	for i = 0, ARCH_SEGMENTS - 1 do
		local a = -math.pi / 2 + (i + 0.5) * math.pi / ARCH_SEGMENTS
		Neon(
			parent,
			"HoloArch",
			Vector3.new(length, ARCH_THICKNESS, ARCH_THICKNESS),
			frame * CFrame.Angles(0, 0, a) * CFrame.new(0, ARCH_RADIUS, 0),
			C.Gold
		)
	end
	-- The scanning ring turns about its vertical axis on clients near it (Client/BiomeAmbience, tag BiomeSpin)
	local ring = Instance.new("Model")
	ring.Name = "ScanRing"
	local centre = frame * CFrame.new(0, SCAN_HEIGHT, 0)
	CyberPlaza.Ring(ring, "Scan", centre, SCAN_RADIUS, 0.4, C.Cyan, 16)
	ring.WorldPivot = centre
	ring:SetAttribute("BasePivot", centre)
	ring.Parent = parent
	CollectionService:AddTag(ring, "BiomeSpin")
end

local function door(parent, pad)
	local d = CyberPlaza.DoorFrame(pad.Position) -- -Z (LookVector) into the compound, X along the wall
	local front = -(T / 2 + 1) -- the frame's plaza face, local z
	for _, side in { -1, 1 } do
		Part(
			parent,
			"DoorFrame",
			Vector3.new(FRAME, H + 6, T + 2),
			d * CFrame.new(side * (W + FRAME) / 2, (H + 6) / 2, 0),
			C.DarkWood,
			Enum.Material.Wood,
			true
		)
		Neon(
			parent,
			"DoorFrameGlow",
			Vector3.new(0.6, H, 0.4),
			d * CFrame.new(side * (W / 2 + 1), H / 2, front - 0.2),
			C.Amber
		)

		-- A leaf: a Model the client slides by its Slide attribute (world studs) into the frame and the wall
		local leaf = Instance.new("Model")
		leaf.Name = side < 0 and "LeafL" or "LeafR"
		local x = side * W / 4
		Part(
			leaf,
			"Leaf",
			Vector3.new(W / 2, DH, T * 0.8),
			d * CFrame.new(x, DH / 2, 0),
			C.Lacquer,
			Enum.Material.SmoothPlastic,
			true
		)
		Neon(leaf, "Seam", Vector3.new(0.5, DH, 0.2), d * CFrame.new(side * 0.25, DH / 2, -0.85), C.Gold)
		for k = 1, CHEVRONS do
			Part(
				leaf,
				"Chevron",
				Vector3.new(W / 2 - 2, 0.8, 0.2),
				d * CFrame.new(x, k * DH / (CHEVRONS + 1), -0.85),
				C.Gold,
				Enum.Material.Metal
			)
		end
		leaf:SetAttribute("Slide", d.RightVector * side * W / 2)
		leaf.Parent = parent
		CollectionService:AddTag(leaf, CyberPlaza.TAG)
	end
	Part(
		parent,
		"DoorHeader",
		Vector3.new(W, H + 6 - DH, T + 2),
		d * CFrame.new(0, DH + (H + 6 - DH) / 2, 0),
		C.DarkWood,
		Enum.Material.Wood,
		true
	)
	-- A lacquer sign board behind the header's text, gold-edged
	local board = d * CFrame.new(0, DH + 9, front - 0.05)
	Part(parent, "SignBoard", Vector3.new(W + 2 * FRAME, 8, 0.2), board, C.Lacquer) -- spans the frame posts: the text is 32 wide
	Part(
		parent,
		"SignTrim",
		Vector3.new(W + 2 * FRAME + 1, 0.5, 0.25),
		board * CFrame.new(0, 4.1, 0),
		C.Gold,
		Enum.Material.Metal
	)
	Part(
		parent,
		"SignTrim",
		Vector3.new(W + 2 * FRAME + 1, 0.5, 0.25),
		board * CFrame.new(0, -4.1, 0),
		C.Gold,
		Enum.Material.Metal
	)
	CyberPlaza.Sign(parent, "RACE START", (d * CFrame.new(0, DH + 9, front - 0.2)).Position, d.LookVector, 4.5, C.Gold)
end

function CyberGate.Build(parent, spawnArea)
	local gate = Instance.new("Model")
	gate.Name = "Gate"
	local pad = spawnArea:FindFirstChild("StartPad")
	local torii = spawnArea:FindFirstChild("StartGate")
	if torii then
		hide(torii)
	end
	arch(gate, pad)
	door(gate, pad)
	gate.Parent = parent
end

return CyberGate
