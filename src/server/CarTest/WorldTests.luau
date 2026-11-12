--!nonstrict
-- BRIEF: docs/WORLD_REDESIGN_SPEC.md sections 3 and 7 (owner 2026-10-28), design doc sections 3 and 4.10. Written
-- by test-writer BEFORE the world build; never loosen a limit to make it pass.
-- `world_layout` (section 3 + 7): "hub at the centre, Track 1 start at the start gate, no overlaps, baseplate covers
--   everything, one SpawnLocation". Coordinates are chosen by the world build, so every check reads the LIVE world and
--   tests relationships, never positions:
--     * hub = Workspace.SpawnArea, its plaza floor = SpawnArea.Floor; "world centre" = the world origin (x 0, z 0).
--     * start gate = SpawnArea.StartPad (tag StartPad); Track 1's Start part lies within one road width of it.
--     * safety baseplate = Workspace.Baseplate (a BasePart, or a Model / Folder of tiles), below the plaza floor,
--       covering every part of the hub and the track chain plus BASEPLATE_MARGIN studs.
-- retired: the 7 Dojo plots and the `dojo` scenario (Dojo squad, plot assignment): Dojos removed, design doc 4.43
--   (owner 2026-11-11).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local H = require(script.Parent.AcceptanceSupport)
local TrackChain = require(script.Parent.TrackChainTests)
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CENTRE_TOL = 8 -- studs: hub centre from the world origin, SpawnLocation from the plaza centre (IVS SPAWN_MIDDLE)
local BASEPLATE_MARGIN = 20 -- studs; "plus a margin" (test-side value, owner may tune)
local OVERLAP_TOL = 0.05

local Tests = {}

local function flatDist(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function parts(root)
	local list = {}
	if root == nil then
		return list
	end
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- World XZ corners of a part's footprint.
local function corners(part)
	local cf, s = part.CFrame, part.Size / 2
	local pts = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(pts, cf:PointToWorldSpace(Vector3.new(x * s.X, y * s.Y, z * s.Z)))
			end
		end
	end
	return pts
end

local function track1Start()
	local registry = H.module(Shared, "TrackRegistry")
	local specs = registry and type(registry.Chain) == "function" and registry.Chain() or {}
	local folder = Workspace:FindFirstChild("Track")
	local model = folder and specs[1] and folder:FindFirstChild(specs[1].Name)
	local start = model and model:FindFirstChild("Start")
	return start and start:IsA("BasePart") and start or nil, specs[1] and specs[1].Width or 40
end

-- helpers = { newFakeCharacter, partPoly, polySeparation } (locals of Scenarios.luau, passed in)
function Tests.make(helpers)
	local partPoly, separation = helpers.partPoly, helpers.polySeparation

	-- Worst separation between any part of `a` and any part of `b` (parts lists); count of overlaps.
	-- Broad-phased and yielding (TrackChainTests.footprintOverlaps): the count is exact; the worst separation is
	-- exact whenever some pair lies within BROAD_MARGIN studs (math.huge, shown as -1, when none does).
	local function overlaps(a, b)
		local hits, worst, pa, pb = TrackChain.footprintOverlaps(a, b, partPoly, separation, OVERLAP_TOL)
		return hits, worst, pa and (pa:GetFullName() .. "/" .. pb:GetFullName()) or ""
	end

	local function roadParts()
		local list = {}
		for _, d in parts(Workspace:FindFirstChild("Track")) do
			if d.Name ~= "Ground" and d.Name ~= "Start" then -- as in spawn_area: neither is road
				table.insert(list, d)
			end
		end
		return list
	end

	local W = {}

	function W.world_layout()
		local r, flag = H.report("world_layout")
		local m = r.metrics
		local area = Workspace:FindFirstChild("SpawnArea")
		local floor = area and area:FindFirstChild("Floor")
		local hubOk = area ~= nil and area:IsA("Model") and floor ~= nil and floor:IsA("BasePart")
		flag("world_hub_exists", hubOk)
		local start, roadWidth = track1Start()
		flag("world_track1_start_exists", start ~= nil)
		if not hubOk then
			return r
		end
		local centre = Vector3.new(floor.Position.X, 0, floor.Position.Z)

		-- 1. Hub at the world centre; the one SpawnLocation at the plaza centre
		local dOrigin = flatDist(centre, Vector3.zero)
		m.hub_centre = ("%.1f, %.1f"):format(centre.X, centre.Z)
		flag("world_hub_at_world_centre", dOrigin <= CENTRE_TOL, dOrigin, CENTRE_TOL)
		local spawns = {}
		for _, d in Workspace:GetDescendants() do
			if d:IsA("SpawnLocation") then
				table.insert(spawns, d)
			end
		end
		local spawn = area:FindFirstChild("Spawn")
		flag("world_one_spawn_location", #spawns == 1 and spawns[1] == spawn, #spawns, 1)
		local dSpawn = spawn and flatDist(spawn.Position, centre) or math.huge
		flag("world_spawn_at_plaza_centre", dSpawn <= CENTRE_TOL, dSpawn == math.huge and -1 or dSpawn, CENTRE_TOL)

		-- 2. retired: the seven Dojo plots (Dojos removed, design doc 4.43, owner 2026-11-11)

		-- 3. No overlaps: hub vs roads
		local roads = roadParts()
		local hits, worst, name = overlaps(parts(area), roads)
		m.hub_road_gap = worst == math.huge and -1 or worst
		if hits > 0 then
			m.hub_road_overlap = name
		end
		flag("world_hub_clear_of_tracks", #roads > 0 and hits == 0, hits, 0)

		-- 4. Track 1 starts at the start gate
		local pad = area:FindFirstChild("StartPad")
		local padOk = pad ~= nil and pad:IsA("BasePart") and CollectionService:HasTag(pad, "StartPad")
		local gateGap = (padOk and start) and separation(partPoly(pad), partPoly(start)) or math.huge
		flag(
			"world_track1_start_at_start_gate",
			padOk and start ~= nil and gateGap <= roadWidth,
			gateGap == math.huge and -1 or gateGap,
			roadWidth
		)

		-- 5. Safety baseplate under everything, plus a margin
		local plate = Workspace:FindFirstChild("Baseplate")
		local tiles = parts(plate)
		local plateOk = #tiles > 0
		local top = -math.huge
		for _, t in tiles do
			plateOk = plateOk and t.Anchored
			top = math.max(top, t.Position.Y + t.Size.Y / 2)
		end
		flag("world_baseplate_exists", plateOk)
		local floorTop = floor.Position.Y + floor.Size.Y / 2
		flag("world_baseplate_below_plaza", plateOk and top < floorTop, top, floorTop)
		local function covered(x, z)
			for _, t in tiles do
				local l = t.CFrame:PointToObjectSpace(Vector3.new(x, t.Position.Y, z))
				if math.abs(l.X) <= t.Size.X / 2 and math.abs(l.Z) <= t.Size.Z / 2 then
					return true
				end
			end
			return false
		end
		-- shortcut: samples the margin-grown corners of each part's world box, not the whole area; enough for the
		-- convex tiles a baseplate is made of, upgrade if tiles leave holes between sample points
		local uncovered, checked, firstMiss = 0, 0, nil
		for _, root in { area, Workspace:FindFirstChild("Track") } do
			for i, p in parts(root) do
				if i % 500 == 0 then
					task.wait() -- yield only: tens of thousands of parts x 5 points x every tile
				end
				local lo, hi = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
				for _, c in corners(p) do
					lo = Vector2.new(math.min(lo.X, c.X), math.min(lo.Y, c.Z))
					hi = Vector2.new(math.max(hi.X, c.X), math.max(hi.Y, c.Z))
				end
				lo -= Vector2.new(BASEPLATE_MARGIN, BASEPLATE_MARGIN)
				hi += Vector2.new(BASEPLATE_MARGIN, BASEPLATE_MARGIN)
				for _, pt in { lo, hi, Vector2.new(lo.X, hi.Y), Vector2.new(hi.X, lo.Y), (lo + hi) / 2 } do
					checked += 1
					if not covered(pt.X, pt.Y) then
						uncovered += 1
						firstMiss = firstMiss or p:GetFullName()
					end
				end
			end
		end
		m.baseplate_points_checked = checked
		m.baseplate_first_miss = firstMiss
		flag("world_baseplate_covers_everything", plateOk and checked > 0 and uncovered == 0, uncovered, 0)

		-- 6. No real names on the hub (spec 4 "no logos or real names", design doc section 5)
		local realNameIn = require(script.Parent.CatalogTests).realNameIn
		local named = {}
		for _, root in { area } do
			for _, d in root and root:GetDescendants() or {} do
				local text = (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text or d.Name
				local key = string.gsub(string.lower(text), "[^%w]+", "_")
				if realNameIn(key) then
					table.insert(named, d:GetFullName())
				end
			end
		end
		m.real_name_at = named[1]
		flag("world_no_real_names_in_hub", #named == 0, #named, 0)
		return r
	end

	return W
end

return Tests
