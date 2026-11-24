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
-- `world_travel` (design doc 4.47, docs/WORLD2_SPEC.md "Travel and gate", audit 2026-11-24): Server/WorldTravel.Go
--   keeps the player busy from the call until departure or failure, for the gate and the admin /world1 /world2 alike;
--   after the release save the player is frozen (DataLoaded off, Travelling on: MoneyService pays nothing); a failure
--   (TeleportAsync error, TeleportInitFailed -> WorldTravel.Failed, or the TIMEOUT) restores DataLoaded, clears busy and
--   notifies the player once; a read-only save (PlayerData.Save returns false, true) still travels. Seams:
--   WorldTravel.Save / Teleport / Notify / AllowStudio / TIMEOUT. Fake players are Folders.
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

	function W.world_travel()
		local r, flag = H.report("world_travel")
		local Server = script.Parent.Parent
		local travel = H.module(Server, "WorldTravel")
		local money = H.module(Server, "MoneyService")
		local admin = H.module(Server, "AdminService")
		local WorldConfig = require(Shared:WaitForChild("WorldConfig"))
		local api = travel ~= nil
			and money ~= nil
			and admin ~= nil
			and type(travel.Go) == "function"
			and type(travel.Failed) == "function"
			and type(travel.Busy) == "function"
			and type(travel.Save) == "function"
			and type(travel.Notify) == "function"
		flag("travel_api_exists", api == true)
		if not api then
			return r
		end
		local target = WorldConfig.Id == 1 and 2 or 1
		local command = admin.Commands["world" .. target]
		local saved = { travel.Save, travel.Teleport, travel.Notify, travel.AllowStudio, travel.TIMEOUT }
		local cleanup = {}
		local saves, teleports, notes = 0, 0, 0
		local saveResult = { true, false }
		local teleportError = nil
		travel.AllowStudio = true
		travel.Save = function()
			saves += 1
			return saveResult[1], saveResult[2]
		end
		travel.Teleport = function()
			teleports += 1
			if teleportError then
				error(teleportError)
			end
		end
		travel.Notify = function()
			notes += 1
		end
		local function player(name)
			local p = H.player(cleanup, 970000 + #cleanup)
			p.Name = "ServerTestTravel_" .. name
			money.Setup(p)
			p:SetAttribute("DataLoaded", true)
			return p
		end
		local function reset()
			saves, teleports, notes, saveResult, teleportError = 0, 0, 0, { true, false }, nil
		end
		local ok, err = pcall(function()
			-- 1. A trip in flight: busy, frozen, and the gate and admin command are refused
			local a = player("Pending")
			local okGo = travel.Go(a, target)
			flag("travel_go_ok", okGo == true and saves == 1 and teleports == 1, saves * 10 + teleports, 11)
			flag("travel_busy_until_departure", travel.Busy(a) == true)
			flag("travel_frozen_data_loaded_off", a:GetAttribute("DataLoaded") == nil)
			flag("travel_frozen_travelling_on", a:GetAttribute("Travelling") == true)
			local before = a.leaderstats.Money.Value
			local paid = money.Award(a, 100)
			flag("travel_frozen_no_income", paid == nil and a.leaderstats.Money.Value == before, paid or 0, 0)
			flag("travel_frozen_no_gems", money.AddGems(a, 5) == nil)
			local again, againMessage = travel.Go(a, target)
			flag("travel_second_go_refused", again == false and saves == 1 and teleports == 1, againMessage)
			local okAdmin = command and command.Apply(a, command.Check({}))
			flag("travel_admin_shares_busy_guard", command ~= nil and okAdmin == false and teleports == 1)

			-- 2. TeleportInitFailed (WorldTravel.Failed): restored, not busy, told once
			travel.Failed(a, "ServerTest init failed")
			flag("travel_init_failed_clears_busy", travel.Busy(a) == false)
			flag("travel_init_failed_restores_data", a:GetAttribute("DataLoaded") == true)
			flag("travel_init_failed_unfreezes", a:GetAttribute("Travelling") == nil and money.Award(a, 1) ~= nil)
			flag("travel_init_failed_notifies", notes == 1, notes, 1)
			travel.Failed(a, "late duplicate")
			flag("travel_failed_twice_notifies_once", notes == 1, notes, 1)

			-- 3. TeleportAsync errors: the same restore
			reset()
			local b = player("Error")
			teleportError = "ServerTest teleport error"
			local okErr = travel.Go(b, target)
			flag("travel_error_returns_false", okErr == false)
			flag(
				"travel_error_restores",
				travel.Busy(b) == false and b:GetAttribute("DataLoaded") == true and b:GetAttribute("Travelling") == nil
			)
			flag("travel_error_notifies", notes == 1, notes, 1)

			-- 4. A failed save: no teleport, nothing frozen
			reset()
			local c = player("NoSave")
			saveResult = { false, false }
			local okSave = travel.Go(c, target)
			flag("travel_save_failed_refused", okSave == false and teleports == 0, teleports, 0)
			flag("travel_save_failed_not_frozen", travel.Busy(c) == false and c:GetAttribute("DataLoaded") == true)

			-- 5. A read-only save (newer version): no write needed, travels anyway
			reset()
			local d = player("ReadOnly")
			saveResult = { false, true }
			local okRead = travel.Go(d, target)
			flag("travel_read_only_travels", okRead == true and teleports == 1, teleports, 1)
			travel.Failed(d, "ServerTest cleanup")

			-- 6. No departure and no failure event within TIMEOUT: restored
			reset()
			travel.TIMEOUT = 0.2
			local e = player("Timeout")
			travel.Go(e, target)
			task.wait(0.6)
			flag("travel_timeout_restores", travel.Busy(e) == false and e:GetAttribute("DataLoaded") == true)

			-- 7. PlayerData: a release save of a read-only record returns false, true and releases the lock
			local module = Server.PlayerData:Clone()
			module.Name, module.Parent = "ServerTestTravelData", Server
			table.insert(cleanup, module)
			local data = require(module)
			local store = H.store()
			data.SetStore(store)
			local id = 979001
			store.data[data.KeyFor(id)] = { Version = 1e6, Money = 5 }
			local f = H.player(cleanup, id)
			local loaded = data.Load(f, id)
			flag("travel_read_only_fixture", loaded == true and f:GetAttribute("DataReadOnly") == true)
			local wrote, readOnly = data.Save(f, id, true)
			local record = store.data[data.KeyFor(id)]
			flag("travel_read_only_save_flag", wrote == false and readOnly == true)
			flag("travel_read_only_lock_released", type(record) == "table" and record.Lock == nil)
			flag("travel_read_only_record_kept", type(record) == "table" and record.Version == 1e6)
			local g = H.player(cleanup, id + 1)
			store.data[data.KeyFor(id + 1)] = { Version = 1 }
			data.Load(g, id + 1)
			local wroteG, readOnlyG = data.Save(g, id + 1, true)
			flag("travel_normal_save_flag", wroteG == true and readOnlyG == false)
		end)
		travel.Save, travel.Teleport, travel.Notify, travel.AllowStudio, travel.TIMEOUT = table.unpack(saved)
		for _, p in cleanup do
			pcall(travel.Failed, p, "ServerTest cleanup")
			p:Destroy()
		end
		flag("travel_no_error", ok, ok and 1 or tostring(err))
		return r
	end

	return W
end

return Tests
