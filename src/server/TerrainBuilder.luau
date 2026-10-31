--!nonstrict
-- Writes the world's terrain from Shared/TerrainShape at every server start (docs/BIOME_ENVIRONMENT_SPEC.md 3.1).
-- Deterministic, in CHUNK x CHUNK chunks with one task.wait() each, the plaza and Track 1 first, then outward.
-- Publishes ReplicatedStorage TerrainProgress (0-1) and TerrainReady = true. On success the safety baseplate drops
-- to BASEPLATE_TOP and turns invisible and the track Ground tiles stop rendering and colliding (spec 2.4); on a
-- failure both stay as they are.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TerrainShape = require(ReplicatedStorage:WaitForChild("Shared").TerrainShape)

local TerrainBuilder = {}
TerrainBuilder.CHUNK = 256 -- placeholder: studs per chunk side
TerrainBuilder.BASEPLATE_TOP = -60 -- placeholder: below the deepest terrain floor
local RES = 4 -- voxel resolution (studs)
-- Studs the smooth-terrain mesher draws a column's surface above `voxel bottom + occupancy * RES` (placeholder,
-- calibrated in Studio 2026-10-30: corridor Height -1 written that way rendered at y 1.00, flush with the road top).
-- Occupancy is written LIFT lower so the drawn surface sits at TerrainShape.Height: the corridor shows 2 studs under
-- the road top (road top 1, corridor -1) and props snapped to Height stand on the drawn ground. Set 0 to undo.
TerrainBuilder.LIFT = RES / 2
local M = Enum.Material

-- Spec 3.4 palette (global per material; colours are placeholders). Water colour is set per zone on the client.
TerrainBuilder.PALETTE = {
	[M.Grass] = "5DA04A",
	[M.LeafyGrass] = "3FB59A",
	[M.Ground] = "A07B52",
	[M.Mud] = "2A2440",
	[M.Slate] = "2E2A3E",
	[M.Rock] = "8A6E52", -- owner 2026-10-31: warm brown stone (was 7C8C99, read blue; 9C8F7E too light for the texture)
	[M.Sandstone] = "B8834F",
	[M.Sand] = "F3E2B3",
	[M.Salt] = "F2F2EE",
	[M.Limestone] = "DADAD2",
	[M.Basalt] = "2E2E3A",
	[M.Cobblestone] = "9E9E9E",
	[M.Asphalt] = "1C1828",
	[M.Concrete] = "6B6B78",
	[M.Pavement] = "E6E9EE",
	[M.Snow] = "FFFFFF",
	[M.CrackedLava] = "FF6A1A", -- owner redesign 2026-10-31, spec 3.4 (placeholder)
}

-- One chunk: heights first (for min / max and slope), then the shaped layer with WriteVoxels and the floor below
-- it with one FillBlock
local function writeChunk(terrain, cx, cz)
	local n = TerrainBuilder.CHUNK // RES
	local h, water, mat, cliff, limit = table.create(n * n), {}, table.create(n * n), {}, {}
	local holeLo, holeHi = {}, {} -- tunnel hollows (spec 3.5): no voxel from lo up to hi
	local lo, hi = math.huge, -math.huge
	for i = 1, n do
		local x = cx + (i - 0.5) * RES
		for k = 1, n do
			local z = cz + (k - 0.5) * RES
			local idx = (i - 1) * n + k
			local y, w, m, c, l, tlo, thi = TerrainShape.Column(x, z)
			h[idx], water[idx], mat[idx], cliff[idx], limit[idx] = y, w, m, c, l
			holeLo[idx], holeHi[idx] = tlo, thi
			lo = math.min(lo, y)
			hi = math.max(hi, w or y)
		end
	end
	local y0 = math.floor(lo / RES) * RES - RES -- one full voxel below the lowest surface
	local y1 = math.ceil(hi / RES) * RES
	local ny = (y1 - y0) // RES
	local lift = TerrainBuilder.LIFT
	local mats, occ = table.create(n), table.create(n)
	for i = 1, n do
		local mi, oi = table.create(ny), table.create(ny)
		for j = 1, ny do
			mi[j], oi[j] = table.create(n), table.create(n)
		end
		for k = 1, n do
			local idx = (i - 1) * n + k
			local y, w = h[idx], water[idx]
			local m = mat[idx]
			if cliff[idx] then
				local ia, ib = math.max(1, i - 1), math.min(n, i + 1)
				local ka, kb = math.max(1, k - 1), math.min(n, k + 1)
				local slope = math.max(
					math.abs(h[(ib - 1) * n + k] - h[(ia - 1) * n + k]) / ((ib - ia) * RES),
					math.abs(h[(i - 1) * n + kb] - h[(i - 1) * n + ka]) / ((kb - ka) * RES)
				)
				if slope > limit[idx] then
					m = cliff[idx]
				end
			end
			local tlo, thi = holeLo[idx], holeHi[idx]
			for j = 1, ny do
				local yb = y0 + (j - 1) * RES
				-- under a tunnel's earth the column stops at the tunnel floor; the voxel at the hollow top stays air
				local inHole = tlo and yb < thi
				local o = math.clamp(((inHole and tlo or y) - lift - yb) / RES, 0, 1)
				if o > 0 then
					mi[j][k], oi[j][k] = m, o
				elseif w and not inHole and yb < w - lift then
					mi[j][k], oi[j][k] = M.Water, math.clamp((w - lift - yb) / RES, 0, 1)
				else
					mi[j][k], oi[j][k] = M.Air, 0
				end
			end
		end
		mats[i], occ[i] = mi, oi
	end
	local size = TerrainBuilder.CHUNK
	terrain:WriteVoxels(Region3.new(Vector3.new(cx, y0, cz), Vector3.new(cx + size, y1, cz + size)), RES, mats, occ)
	local floor = math.min(TerrainShape.FLOOR, y0 - 2 * RES)
	if y0 > floor then
		terrain:FillBlock(
			CFrame.new(cx + size / 2, (floor + y0) / 2, cz + size / 2),
			Vector3.new(size, y0 - floor, size),
			M.Rock
		)
	end
end

local function finish(trackModels, baseplate)
	for _, tile in baseplate and baseplate:GetDescendants() or {} do
		if tile:IsA("BasePart") then
			tile.Position =
				Vector3.new(tile.Position.X, TerrainBuilder.BASEPLATE_TOP - tile.Size.Y / 2, tile.Position.Z)
			tile.Transparency = 1
			tile.CanCollide = true
		end
	end
	for _, model in trackModels do
		for _, tile in model:GetChildren() do
			if tile.Name == "Ground" and tile:IsA("BasePart") then
				tile.Transparency = 1
				tile.CanCollide = false
				tile.CanQuery = false
			end
		end
	end
end

-- Call after TerrainShape.Prepare (task.spawn it: it yields once per chunk)
function TerrainBuilder.Build(trackModels, baseplate)
	local t0 = os.clock()
	local terrain = Workspace.Terrain
	ReplicatedStorage:SetAttribute("TerrainReady", false)
	ReplicatedStorage:SetAttribute("TerrainProgress", 0)
	local ok, err = pcall(function()
		terrain:Clear() -- no terrain is saved in the place (spec 3.1)
		for material, hex in TerrainBuilder.PALETTE do
			terrain:SetMaterialColor(material, Color3.fromHex(hex))
		end
		local box, size = TerrainShape.Box(), TerrainBuilder.CHUNK
		local chunks = {}
		for cx = math.floor(box.Min.X / size) * size, box.Max.X, size do
			for cz = math.floor(box.Min.Y / size) * size, box.Max.Y, size do
				local mx, mz = cx + size / 2, cz + size / 2
				-- the plaza (zone 0) and Track 1 first, then zones outward, nearest first within a zone
				local key = TerrainShape.Zone(mx, mz) * 1e7 + math.sqrt(mx * mx + mz * mz)
				table.insert(chunks, { cx, cz, key })
			end
		end
		table.sort(chunks, function(a, b)
			return a[3] < b[3]
		end)
		for i, c in chunks do
			writeChunk(terrain, c[1], c[2])
			ReplicatedStorage:SetAttribute("TerrainProgress", i / #chunks)
			task.wait()
		end
		return #chunks
	end)
	if not ok then
		warn("[TERRAIN] build failed, baseplate kept: " .. tostring(err))
		return false
	end
	finish(trackModels, baseplate)
	print(string.format("[TERRAIN] built in %.1fs, chunks=%d", os.clock() - t0, err))
	ReplicatedStorage:SetAttribute("TerrainReady", true)
	return true
end

return TerrainBuilder
