--!nonstrict
-- Slice 4 of the enclosed cyber dojo (design doc 4.24 Dojos, owner 2026-11-10): a Dojo's look at its level tier in
-- steel, over the Workshop's steel shell (Shared/WorkshopBuilder keeps the walls, floor, zone and collision). Every
-- screen and rim light is named Glow_lamp: Client/DojoExtras paints them in the owner's WorkshopStat colour. A free
-- plot gets a closed steel shell with a shutter. Sizes are proposed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CyberPlaza = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CyberPlaza"))

local C = CyberPlaza.Colors
local Part, Neon = CyberPlaza.Part, CyberPlaza.Neon

local TIERS = { [1] = 0, [4] = 1, [7] = 2, [10] = 3 } -- level tier -> stacked tiers on the roof
local SHELL = 36 -- WorkshopBuilder's shell
local ROOF_Y = 12.75 -- roof slab centre: its bottom meets the shell's wall tops
local TIER_HEIGHT = 6
local GLOW = "Glow_lamp"

local CyberDojo = {}

-- A Model "DojoMesh" for level tier `tier` (0 = free plot) at `frame` (on the floor top, -Z = the open front).
function CyberDojo.Build(tier, frame, parent)
	local m = Instance.new("Model")
	m.Name = "DojoMesh"
	local half = SHELL / 2
	local stack = TIERS[tier]
	if not stack then
		Part(m, "Closed", Vector3.new(SHELL, 12, SHELL), frame * CFrame.new(0, 6, 0), C.Steel, Enum.Material.Metal)
		Part(
			m,
			"Shutter",
			Vector3.new(24, 9, 0.3),
			frame * CFrame.new(0, 4.5, -half - 0.15),
			C.DoorSteel,
			Enum.Material.DiamondPlate
		)
		Neon(
			m,
			"ClosedSign",
			Vector3.new(8, 1.2, 0.3),
			frame * CFrame.new(0, 10.5, -half - 0.2),
			Color3.fromRGB(255, 50, 60)
		)
		m.Parent = parent
		return m
	end
	Part(
		m,
		"Roof",
		Vector3.new(SHELL + 2, 1, SHELL + 2),
		frame * CFrame.new(0, ROOF_Y, 0),
		C.Steel,
		Enum.Material.Metal
	)
	Part(
		m,
		"Lintel",
		Vector3.new(SHELL, 3, 1),
		frame * CFrame.new(0, ROOF_Y - 2, -half + 0.5),
		C.Steel,
		Enum.Material.Metal
	)
	Neon(m, GLOW, Vector3.new(16, 2.2, 0.3), frame * CFrame.new(0, ROOF_Y - 2, -half - 0.15), C.Cyan) -- the wall screen
	local edge = half + 1.2
	for _, bar in
		{
			{ Vector3.new(2 * edge, 0.4, 0.4), Vector3.new(0, 0, -edge) },
			{ Vector3.new(2 * edge, 0.4, 0.4), Vector3.new(0, 0, edge) },
			{ Vector3.new(0.4, 0.4, 2 * edge), Vector3.new(-edge, 0, 0) },
			{ Vector3.new(0.4, 0.4, 2 * edge), Vector3.new(edge, 0, 0) },
		}
	do
		Neon(m, GLOW, bar[1], frame * CFrame.new(bar[2].X, ROOF_Y - 0.5, bar[2].Z), C.Cyan) -- the roof's rim light
	end
	local y = ROOF_Y + 0.5
	for s = 0, stack - 1 do
		local w = 30 - 7 * s
		-- the tier's rim light: a neon slab under it, showing round its edge
		Neon(m, GLOW, Vector3.new(w + 0.6, 0.4, w + 0.6), frame * CFrame.new(0, y + 0.2, 0), C.Cyan)
		Part(
			m,
			"Tier",
			Vector3.new(w, TIER_HEIGHT, w),
			frame * CFrame.new(0, y + 0.4 + TIER_HEIGHT / 2, 0),
			C.Steel,
			Enum.Material.Metal
		)
		y += 0.4 + TIER_HEIGHT
	end
	if stack >= 2 then
		for _, side in { -1, 1 } do
			local lamp = Neon(
				m,
				GLOW,
				Vector3.new(0.5, 1.8, 1.8),
				frame * CFrame.new(side * (half + 3), 15, -half + 4) * CFrame.Angles(0, 0, math.pi / 2),
				C.Cyan
			)
			lamp.Shape = Enum.PartType.Cylinder
		end
	end
	if stack == 3 then
		CyberPlaza.Ring(m, "Crest", frame * CFrame.new(0, y + 4, 0), 3, 0.4, C.Cyan, 12)
	end
	m.Parent = parent
	return m
end

return CyberDojo
