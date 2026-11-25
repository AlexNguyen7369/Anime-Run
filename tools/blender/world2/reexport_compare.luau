--!nonstrict
-- Compares an old and a new uploaded mesh vertex by vertex (docs/W2_REEXPORT_PLAN.md): `upload_reexport.py compare-script <batch>` prints
-- this with ROWS filled, to run in Studio's command bar; each REEXPORT_COMPARE line goes back through `upload_reexport.py compare <file>`.
-- Max is the largest distance from a vertex, or a triangle's centre, of either mesh to the nearest one of the other, in mesh-native units: the order
-- and the splitting of vertices on import do not count, a moved or missing one does. It changes nothing in the place.
local ROWS = {} --ROWS

local M = {}

local function grid(points, cell)
	local out = {}
	for _, p in points do
		local k = math.floor(p[1] / cell) .. "," .. math.floor(p[2] / cell) .. "," .. math.floor(p[3] / cell)
		out[k] = out[k] or {}
		table.insert(out[k], p)
	end
	return out
end

local function distance(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

-- The largest distance from a point of `a` to its nearest point of `b`; `cell` when none is within it.
local function oneWay(a, b, cell)
	local near, worst = grid(b, cell), 0
	for _, p in a do
		local best = cell
		local x, y, z = math.floor(p[1] / cell), math.floor(p[2] / cell), math.floor(p[3] / cell)
		for i = x - 1, x + 1 do
			for j = y - 1, y + 1 do
				for k = z - 1, z + 1 do
					for _, q in near[i .. "," .. j .. "," .. k] or {} do
						best = math.min(best, distance(p, q))
					end
				end
			end
		end
		worst = math.max(worst, best)
	end
	return worst
end

-- { Points, Centres } (lists of { x, y, z }) of two meshes: the largest difference, capped at `cell` (mesh-native units). An empty mesh is `cell`.
function M.Max(old, new, cell)
	cell = cell or 0.5
	local worst = 0
	for _, part in { "Points", "Centres" } do
		if #old[part] == 0 or #new[part] == 0 then
			return cell
		end
		worst = math.max(worst, oneWay(old[part], new[part], cell), oneWay(new[part], old[part], cell))
	end
	return worst
end

-- A mesh asset's points and triangle centres (Studio only).
function M.Read(id)
	local mesh = game:GetService("AssetService"):CreateEditableMeshAsync(Content.fromUri("rbxassetid://" .. id))
	local out = { Points = {}, Centres = {} }
	for _, v in mesh:GetVertices() do
		local p = mesh:GetPosition(v)
		table.insert(out.Points, { p.X, p.Y, p.Z })
	end
	for _, f in mesh:GetFaces() do
		local c = Vector3.zero
		for _, v in mesh:GetFaceVertices(f) do
			c += mesh:GetPosition(v) / 3
		end
		table.insert(out.Centres, { c.X, c.Y, c.Z })
	end
	mesh:Destroy()
	return out
end

for _, row in ROWS do
	local ok, err = pcall(function()
		local old, new = M.Read(row[2]), M.Read(row[3])
		print(
			string.format(
				'REEXPORT_COMPARE {"Key": "%s", "Old": "%s", "New": "%s", "Max": %.6f, "TrisOld": %d, "TrisNew": %d}',
				row[1],
				row[2],
				row[3],
				M.Max(old, new),
				#old.Centres,
				#new.Centres
			)
		)
	end)
	if not ok then
		warn("NOT COMPARED " .. row[1] .. ": " .. tostring(err))
	end
end

return M
