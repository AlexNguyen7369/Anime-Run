--!nonstrict
-- BRIEF: docs/W2_RENDER_AUDIT.md (2026-11-26), owner's rendering priority 1: nothing shows through a road. On every built
-- track, in any world and any layout (read from the built road, never from positions):
--  * no visible part of the scenery crosses a road's top surface (World 2's draft road supports, Fill / Bank / Pier,
--    stuck up to 1.6 studs through the asphalt on every climb: flat boxes topped at the road's centre height; fixed in the
--    Blender generators, kit.support_top);
--  * no visible scenery part reaches into a road's deck: none holds a point DECK above the road's underside (a support
--    stays SUPPORT_CLEARANCE 0.05 under it, kit.support_top); this is stricter than the crossing check;
--  * no terrain stands above, or flush with, a road's top, and no Grass lies under a road (W2_VISUAL_BUGS w2-grass-through-road).
-- Scenery is every built track's (a neighbour's part over this road counts). Not checked: MeshParts (their box is not their
-- shape: arches and tunnel rings span the road; the exporter's triangle road test covers draft meshes offline), and the
-- road's own Walls, TrackBuilder Supports and the checkpoint apron (0.05 over the road by design). Run in World 2 so far.
-- On demand in Studio (waits for every track and the terrain): ReplicatedStorage attributes ServerTestOnly =
-- "road_surface_clear", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tests = {}

local WAIT = 180 -- seconds for every track to build and the terrain to finish
local STEP_X, STEP_Z = 3, 2 -- studs between road surface samples
local LIFT = 0.05 -- a sample sits this far over the road top
local SINK = 0.3 -- a crossing part also holds the point this far under the road top
local GRASS_REACH = 4 -- Grass whose top is less than this under the road top would grow blades through it
local DECK = 0.02 -- a deck sample sits this far over the road's underside

local function report(name)
	local r = { scenario = name, pass = true, checks = {}, metrics = {} }
	local function flag(label, ok, value, limit)
		table.insert(
			r.checks,
			{ name = label, pass = ok == true, value = value or (ok and 1 or 0), limit = limit or 1 }
		)
		r.pass = r.pass and ok == true
	end
	return r, flag
end

local function inside(part, point)
	local l = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	return math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z
end

-- Built track models (BuiltAt set), waiting for all of them and the terrain
local function builtTracks()
	local t0 = os.clock()
	local folder, models
	repeat
		folder = Workspace:FindFirstChild("Track")
		models = {}
		local pending = 0
		for _, m in folder and folder:GetChildren() or {} do
			if m:GetAttribute("BuiltAt") then
				table.insert(models, m)
			else
				pending += 1
			end
		end
		local done = folder and pending == 0 and #models > 0 and ReplicatedStorage:GetAttribute("TerrainReady") == true
		if not done then
			task.wait(1)
		end
	until done or os.clock() - t0 > WAIT
	table.sort(models, function(a, b)
		return (a:GetAttribute("Number") or 0) < (b:GetAttribute("Number") or 0)
	end)
	return models, os.clock() - t0
end

-- Visible scenery parts of every track, bucketed on a 32-stud grid: not the roads, walls, TrackBuilder supports or checkpoints
local GRID = 32
local function sceneryGrid(models)
	local grid = {}
	local skip = {}
	for _, model in models do
		for _, name in { "Road", "Walls", "Supports", "Checkpoint" } do
			local c = model:FindFirstChild(name)
			if c then
				skip[c] = true
			end
		end
	end
	local function skipped(d)
		for root in skip do
			if d:IsDescendantOf(root) then
				return true
			end
		end
		return false
	end
	local all = {}
	for _, model in models do
		for _, d in model:GetDescendants() do
			table.insert(all, d)
		end
	end
	for i, d in all do
		if d:IsA("BasePart") and not d:IsA("MeshPart") and d.Transparency < 1 and not skipped(d) then
			local h = d.Size.Magnitude / 2
			for gx = math.floor((d.Position.X - h) / GRID), math.floor((d.Position.X + h) / GRID) do
				for gz = math.floor((d.Position.Z - h) / GRID), math.floor((d.Position.Z + h) / GRID) do
					local k = gx .. "," .. gz
					grid[k] = grid[k] or {}
					table.insert(grid[k], d)
				end
			end
		end
		if i % 3000 == 0 then
			task.wait()
		end
	end
	return grid
end

function Tests.road_surface_clear()
	local r, flag = report("road_surface_clear")
	local models, waited = builtTracks()
	r.metrics.waited_s = math.round(waited)
	flag("tracks_built", #models > 0 and ReplicatedStorage:GetAttribute("TerrainReady") == true, #models)
	local terrainRay = RaycastParams.new()
	terrainRay.FilterType = Enum.RaycastFilterType.Include
	terrainRay.FilterDescendantsInstances = { Workspace.Terrain }
	local totals = { crossing = 0, deck = 0, terrainAbove = 0, grassUnder = 0, samples = 0 }
	local grid = sceneryGrid(models)
	for _, model in models do
		local n = model:GetAttribute("Number")
		local roads = model:FindFirstChild("Road")
		local crossing, names, terrainAbove, grassUnder, samples = {}, {}, 0, 0, 0
		local inDeck, deckNames = {}, {}
		for i, road in roads and roads:GetDescendants() or {} do
			if road:IsA("BasePart") then
				local sx, sz = road.Size.X / 2, road.Size.Z / 2
				for x = -sx + 1, sx - 1, STEP_X do
					for z = -sz + 0.5, sz - 0.5, STEP_Z do
						samples += 1
						local top = road.CFrame * Vector3.new(x, road.Size.Y / 2, z)
						local over, under = top + road.CFrame.UpVector * LIFT, top - road.CFrame.UpVector * SINK
						local deck = road.CFrame * Vector3.new(x, -road.Size.Y / 2 + DECK, z)
						for _, p in grid[math.floor(over.X / GRID) .. "," .. math.floor(over.Z / GRID)] or {} do
							if not crossing[p] and inside(p, over) and inside(p, under) then
								crossing[p] = true
								local key = string.gsub(p.Name, "%d+$", "")
								names[key] = (names[key] or 0) + 1
							end
							if not inDeck[p] and inside(p, deck) then
								inDeck[p] = true
								local key = string.gsub(p.Name, "%d+$", "")
								deckNames[key] = (deckNames[key] or 0) + 1
							end
						end
						local hit = Workspace:Raycast(top + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), terrainRay)
						if hit then
							if hit.Position.Y >= top.Y - 0.05 then
								terrainAbove += 1
							end
							if hit.Material == Enum.Material.Grass and hit.Position.Y > top.Y - GRASS_REACH then
								grassUnder += 1
							end
						end
					end
				end
			end
			if i % 20 == 0 then
				task.wait()
			end
		end
		local list, count = {}, 0
		for k, c in names do
			table.insert(list, k .. ":" .. c)
			count += c
		end
		table.sort(list)
		flag("T" .. tostring(n) .. "_no_part_through_road", count == 0, count == 0 and 0 or table.concat(list, " "), 0)
		local dlist, dcount = {}, 0
		for k, c in deckNames do
			table.insert(dlist, k .. ":" .. c)
			dcount += c
		end
		table.sort(dlist)
		flag("T" .. tostring(n) .. "_road_sampled", samples > 0, samples)
		flag(
			"T" .. tostring(n) .. "_no_part_in_road_deck",
			dcount == 0,
			dcount == 0 and 0 or table.concat(dlist, " "),
			0
		)
		flag("T" .. tostring(n) .. "_no_terrain_at_road_top", terrainAbove == 0, terrainAbove, 0)
		flag("T" .. tostring(n) .. "_no_grass_under_road", grassUnder == 0, grassUnder, 0)
		totals.crossing += count
		totals.deck += dcount
		totals.samples += samples
		totals.terrainAbove += terrainAbove
		totals.grassUnder += grassUnder
	end
	r.metrics.samples = totals.samples
	flag("no_part_through_any_road", totals.crossing == 0, totals.crossing, 0)
	flag("no_part_in_any_road_deck", totals.deck == 0, totals.deck, 0)
	flag("no_terrain_at_any_road_top", totals.terrainAbove == 0, totals.terrainAbove, 0)
	flag("no_grass_under_any_road", totals.grassUnder == 0, totals.grassUnder, 0)
	return r
end

return Tests
