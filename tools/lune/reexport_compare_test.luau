-- The comparison of tools/blender/world2/reexport_compare.luau, no engine: lune run tools/lune/reexport_compare_test
local M = require("../blender/world2/reexport_compare")

local function mesh(shift, drop)
	local points, centres = {}, {}
	for i = 1, 40 do
		table.insert(points, { i * 3, (i % 5) * 2, -i })
		table.insert(centres, { i * 3 + 1, i % 7, i })
	end
	if shift then
		points[20][2] += shift
	end
	if drop then
		table.remove(centres, 7)
	end
	return { Points = points, Centres = centres }
end
local function reversed(m)
	local out = { Points = {}, Centres = m.Centres }
	for i = #m.Points, 1, -1 do
		table.insert(out.Points, m.Points[i])
		table.insert(out.Points, m.Points[i]) -- split on import
	end
	return out
end
assert(M.Max(mesh(), mesh()) == 0)
assert(M.Max(mesh(), reversed(mesh())) == 0, "order and splitting do not count")
assert(math.abs(M.Max(mesh(), mesh(0.0005)) - 0.0005) < 1e-9)
assert(math.abs(M.Max(mesh(0.02), mesh()) - 0.02) < 1e-9)
assert(M.Max(mesh(), mesh(5)) == 0.5, "far: capped")
assert(
	M.Max(mesh(), mesh(nil, true)) == 0.5 and M.Max(mesh(nil, true), mesh()) == 0.5,
	"a missing triangle, either way"
)
assert(M.Max(mesh(), { Points = {}, Centres = {} }) == 0.5, "an empty mesh never passes")
print("COMPARE TEST ok")
