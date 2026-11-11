--!nonstrict
-- Slice 1 of the enclosed cyber dojo (design doc 4.24, owner 2026-11-10): the tech wall round the plaza, both wings and
-- the Dojo ring (Shared/CyberPlaza's rounded rectangle, a gap for the blast door), a steel floor over the whole
-- compound with a neon grid, and the spawn-to-gate path. The wall collides, so no one walks out on foot; it is
-- WALL_HEIGHT tall, so no track shows from inside. Sizes and colours are proposed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CyberPlaza = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CyberPlaza"))

local C = CyberPlaza.Colors
local Part, Neon = CyberPlaza.Part, CyberPlaza.Neon
local TOP, H, T, R = CyberPlaza.TOP, CyberPlaza.WALL_HEIGHT, CyberPlaza.WALL_THICKNESS, CyberPlaza.RADIUS
local LO, HI = CyberPlaza.CORNER_MIN, CyberPlaza.CORNER_MAX

local PIECE = 12 -- longest wall piece (studs)
local ARC_STEP = 10 -- degrees per corner piece
local FLOOR_THICKNESS = 3 -- down to the Baseplate top, like the plaza floor
local GRID_STEP = 8
local PATH_WIDTH = 18

local CyberWall = {}

-- The wall's centre line, from the door's north end round the compound to its south end (corners from 180 degrees).
local function outline(door)
	local west = LO.X - R
	local gap = CyberPlaza.DOOR_WIDTH / 2 + CyberPlaza.FRAME
	local points = { Vector2.new(west, door.Position.Z + gap) }
	for _, corner in { { LO.X, HI.Y, 180 }, { HI.X, HI.Y, 90 }, { HI.X, LO.Y, 0 }, { LO.X, LO.Y, -90 } } do
		for a = corner[3], corner[3] - 90, -ARC_STEP do
			local r = math.rad(a)
			table.insert(points, Vector2.new(corner[1] + R * math.cos(r), corner[2] + R * math.sin(r)))
		end
	end
	table.insert(points, Vector2.new(west, door.Position.Z - gap))
	return points
end

local function buildWall(parent, door)
	local folder = Instance.new("Folder")
	folder.Name = "Wall"
	folder.Parent = parent
	local points = outline(door)
	local i = 0
	for k = 1, #points - 1 do
		local a, b = points[k], points[k + 1]
		local n = math.max(1, math.ceil((b - a).Magnitude / PIECE))
		for j = 1, n do
			i += 1
			local p0, p1 = a:Lerp(b, (j - 1) / n), a:Lerp(b, j / n)
			local mid, dir = (p0 + p1) / 2, (p1 - p0).Unit
			local len = (p1 - p0).Magnitude + 0.4 -- closes the joints between angled corner pieces
			local inward = Vector2.new(-dir.Y, dir.X)
			if CyberPlaza.Distance(mid.X + inward.X, mid.Y + inward.Y) > CyberPlaza.Distance(mid.X, mid.Y) then
				inward = -inward
			end
			local base = CFrame.lookAt(Vector3.new(mid.X, TOP, mid.Y), Vector3.new(p1.X, TOP, p1.Y))
			local face = Vector3.new(inward.X, 0, inward.Y) -- world offset to the inner face
			Part(
				folder,
				"Wall",
				Vector3.new(T, H, len),
				base + Vector3.new(0, H / 2, 0),
				C.Steel,
				Enum.Material.Metal,
				true
			)
			Neon(
				folder,
				"Rim",
				Vector3.new(0.8, 0.8, len),
				base + face * (T / 2 + 0.4) + Vector3.new(0, H - 1, 0),
				C.Cyan
			)
			if i % 2 == 0 then
				Neon(
					folder,
					"Strip",
					Vector3.new(0.3, H * 0.8, 0.6),
					base + face * (T / 2 + 0.15) + Vector3.new(0, H * 0.45, 0),
					i % 4 == 0 and C.Cyan or C.Magenta
				)
			end
			if i % 6 == 0 then
				Neon(
					folder,
					"Panel",
					Vector3.new(0.3, 10, len * 0.6),
					base + face * (T / 2 + 0.15) + Vector3.new(0, 22, 0),
					C.Panel
				)
			end
		end
		if k % 10 == 0 then
			task.wait() -- chunks: no long frame at server start
		end
	end
end

-- Z (or X) extent of the compound's floor at x (or z), inset by `inset`; nil outside.
local function span(c, lo, hi, loOther, hiOther, inset)
	local r = R - inset
	local d = math.max(lo - c, 0, c - hi)
	if d >= r then
		return nil
	end
	local h = math.sqrt(r * r - d * d)
	return loOther - h, hiOther + h
end

local function buildFloor(parent, spawnArea)
	local folder = Instance.new("Folder")
	folder.Name = "Floor"
	folder.Parent = parent
	local y = TOP - FLOOR_THICKNESS / 2
	local west, east = LO.X - R, HI.X + R
	local function slab(x0, x1, z0, z1)
		Part(
			folder,
			"Floor",
			Vector3.new(x1 - x0, FLOOR_THICKNESS, z1 - z0),
			CFrame.new((x0 + x1) / 2, y, (z0 + z1) / 2),
			C.Gunmetal,
			nil,
			true
		)
	end
	slab(west, east, LO.Y, HI.Y)
	slab(LO.X, HI.X, LO.Y - R, LO.Y)
	slab(LO.X, HI.X, HI.Y, HI.Y + R)
	for _, c in { LO, HI, Vector2.new(LO.X, HI.Y), Vector2.new(HI.X, LO.Y) } do
		local disc = Part(
			folder,
			"Floor",
			Vector3.new(FLOOR_THICKNESS, 2 * R, 2 * R),
			CFrame.new(c.X, y, c.Y) * CFrame.Angles(0, 0, math.pi / 2),
			C.Gunmetal,
			nil,
			true
		)
		disc.Shape = Enum.PartType.Cylinder
	end
	-- The plaza's own floor keeps its collision and test contract; this floor is what shows
	local plazaFloor = spawnArea:FindFirstChild("Floor")
	if plazaFloor then
		plazaFloor.Transparency = 1
	end

	-- Grid: thin lines, tops below the Dojo bases (TOP + 0.05) so they never z-fight
	local inset = T / 2 + 0.5
	for x = math.ceil(west / GRID_STEP) * GRID_STEP, east, GRID_STEP do
		local z0, z1 = span(x, LO.X, HI.X, LO.Y, HI.Y, inset)
		if z0 then
			local line =
				Neon(folder, "Grid", Vector3.new(0.3, 0.04, z1 - z0), CFrame.new(x, TOP + 0.02, (z0 + z1) / 2), C.Cyan)
			line.Transparency = 0.45
		end
	end
	for z = math.ceil((LO.Y - R) / GRID_STEP) * GRID_STEP, HI.Y + R, GRID_STEP do
		local x0, x1 = span(z, LO.Y, HI.Y, LO.X, HI.X, inset)
		if x0 then
			local line =
				Neon(folder, "Grid", Vector3.new(x1 - x0, 0.04, 0.3), CFrame.new((x0 + x1) / 2, TOP + 0.02, z), C.Cyan)
			line.Transparency = 0.45
		end
	end

	-- The path: steel with neon edges from the spawn's edge to the pad's
	local pad = spawnArea:FindFirstChild("StartPad")
	if pad then
		local to = Vector3.new(pad.Position.X, 0, pad.Position.Z)
		local t0, t1 = 8, to.Magnitude - 8
		local mid = to.Unit * (t0 + t1) / 2 + Vector3.new(0, TOP, 0)
		local frame = CFrame.lookAt(mid, mid + to)
		Part(
			folder,
			"Path",
			Vector3.new(PATH_WIDTH, 0.1, t1 - t0),
			frame + Vector3.new(0, 0.05, 0),
			C.Steel,
			Enum.Material.Metal
		)
		for _, side in { -1, 1 } do
			Neon(
				folder,
				"PathEdge",
				Vector3.new(0.5, 0.15, t1 - t0),
				frame * CFrame.new(side * (PATH_WIDTH / 2 + 0.25), 0.075, 0),
				C.Cyan
			)
		end
	end
end

function CyberWall.Build(parent, spawnArea)
	buildFloor(parent, spawnArea)
	task.wait()
	buildWall(parent, CyberPlaza.DoorFrame(spawnArea.StartPad.Position))
end

return CyberWall
