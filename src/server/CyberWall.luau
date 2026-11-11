--!nonstrict
-- Slice 1 of the enclosed cyber dojo (design doc 4.24, owner 2026-11-10): the tech wall round the plaza, both wings and
-- the Dojo ring (Shared/CyberPlaza's rounded rectangle, a gap for the blast door), a warm stone floor over the whole
-- compound and the spawn-to-gate path. Hybrid look (4.24, owner 2026-11-10): no neon grid on the floor or the wall; the
-- wall is wood and steel panels with gold trim and a few wall screens, the path is wood planks on a stone border with
-- soft lantern lights along its edges. The wall collides, so no one walks out on foot; it is WALL_HEIGHT tall, so no
-- track shows from inside. Sizes and colours are proposed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CyberPlaza = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CyberPlaza"))

local C = CyberPlaza.Colors
local Part, Neon, Light = CyberPlaza.Part, CyberPlaza.Neon, CyberPlaza.Light
local TOP, H, T, R = CyberPlaza.TOP, CyberPlaza.WALL_HEIGHT, CyberPlaza.WALL_THICKNESS, CyberPlaza.RADIUS
local LO, HI = CyberPlaza.CORNER_MIN, CyberPlaza.CORNER_MAX

local PIECE = 12 -- longest wall piece (studs)
local ARC_STEP = 10 -- degrees per corner piece
local FLOOR_THICKNESS = 3 -- down to the Baseplate top, like the plaza floor
local PATH_WIDTH = 18
local PATH_BORDER = 2 -- stone kerb either side of the planks
local PATH_LAMP_STEP = 16 -- studs between the path's edge lanterns
local PILASTER_EVERY = 3 -- wall pieces between steel pilasters
local SCREEN_EVERY = 9 -- wall pieces between wall screens

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
				C.Wood,
				Enum.Material.WoodPlanks,
				true
			)
			local inner = base + face * (T / 2 + 0.2)
			-- A steel base course, a gold rail at its top and a gold cap rail under the coping
			Part(folder, "Panel", Vector3.new(0.4, 8, len), inner + Vector3.new(0, 4, 0), C.Steel, Enum.Material.Metal)
			Part(
				folder,
				"Trim",
				Vector3.new(0.6, 0.6, len),
				inner + Vector3.new(0, 8.3, 0),
				C.Gold,
				Enum.Material.Metal
			)
			Part(
				folder,
				"Trim",
				Vector3.new(0.6, 0.8, len),
				inner + Vector3.new(0, H - 3, 0),
				C.Gold,
				Enum.Material.Metal
			)
			Part(
				folder,
				"Coping",
				Vector3.new(T + 0.6, 1, len), -- 0.3 overhang: Track 1's side walls stand 2 studs out
				base + Vector3.new(0, H + 0.5, 0),
				C.DarkWood,
				Enum.Material.Wood
			)
			if i % PILASTER_EVERY == 0 then
				Part(
					folder,
					"Pilaster",
					Vector3.new(1, H - 4, 1.6),
					inner + face * 0.4 + Vector3.new(0, (H - 4) / 2, 0),
					C.Steel,
					Enum.Material.Metal
				)
			end
			if i % SCREEN_EVERY == 0 then
				-- A wall screen: a dark face in a steel frame, lit warm (one in three a soft cyan or pink accent)
				local at = inner + face * 0.3 + Vector3.new(0, 20, 0)
				local tint = (i // SCREEN_EVERY) % 3 == 1 and C.Cyan
					or (i // SCREEN_EVERY) % 3 == 2 and C.Pink
					or C.Paper
				Part(folder, "ScreenFrame", Vector3.new(0.4, 9, len * 0.75), at, C.Steel, Enum.Material.Metal)
				Neon(folder, "ScreenGlow", Vector3.new(0.2, 7.6, len * 0.75 - 1.2), at + face * 0.25, tint).Transparency =
					0.25
			end
		end
		if k % 10 == 0 then
			task.wait() -- chunks: no long frame at server start
		end
	end
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
			C.Paving,
			Enum.Material.Slate,
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
			C.Paving,
			Enum.Material.Slate,
			true
		)
		disc.Shape = Enum.PartType.Cylinder
	end
	-- The plaza's own floor keeps its collision and test contract; this floor is what shows
	local plazaFloor = spawnArea:FindFirstChild("Floor")
	if plazaFloor then
		plazaFloor.Transparency = 1
	end

	-- The path: wood planks on a stone kerb from the spawn's edge to the pad's, a soft lantern on each edge every
	-- PATH_LAMP_STEP studs
	local pad = spawnArea:FindFirstChild("StartPad")
	if pad then
		local to = Vector3.new(pad.Position.X, 0, pad.Position.Z)
		local t0, t1 = 8, to.Magnitude - 8
		local mid = to.Unit * (t0 + t1) / 2 + Vector3.new(0, TOP, 0)
		local frame = CFrame.lookAt(mid, mid + to)
		Part(
			folder,
			"PathKerb",
			Vector3.new(PATH_WIDTH + 2 * PATH_BORDER, 0.1, t1 - t0),
			frame + Vector3.new(0, 0.04, 0),
			C.Stone,
			Enum.Material.Cobblestone
		)
		Part(
			folder,
			"Path",
			Vector3.new(PATH_WIDTH, 0.1, t1 - t0),
			frame + Vector3.new(0, 0.08, 0),
			C.Wood,
			Enum.Material.WoodPlanks
		)
		local lamps = math.floor((t1 - t0) / PATH_LAMP_STEP)
		for k = 0, lamps do
			local z = -(t1 - t0) / 2 + (t1 - t0) * k / math.max(lamps, 1)
			for _, side in { -1, 1 } do
				local at = frame * CFrame.new(side * (PATH_WIDTH / 2 + PATH_BORDER / 2), 0, z)
				Part(
					folder,
					"PathLamp",
					Vector3.new(0.8, 1.6, 0.8),
					at * CFrame.new(0, 0.8, 0),
					C.DarkWood,
					Enum.Material.Wood
				)
				local glow =
					Neon(folder, "PathLampGlow", Vector3.new(0.9, 0.7, 0.9), at * CFrame.new(0, 1.95, 0), C.Paper)
				Light(glow, C.Amber, 0.8, 10)
			end
		end
	end
end

function CyberWall.Build(parent, spawnArea)
	buildFloor(parent, spawnArea)
	task.wait()
	buildWall(parent, CyberPlaza.DoorFrame(spawnArea.StartPad.Position))
end

return CyberWall
