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
		-- BIOME_ENVIRONMENT_SPEC 2.4: once the terrain is built nothing of the baseplate draws, a Texture or Decal on
		-- its tiles included (the World 2 place's template baseplate showed its grid where no terrain covers it)
		if game:GetService("ReplicatedStorage"):GetAttribute("TerrainReady") == true and plate then
			local drawn = 0
			for _, d in plate:GetDescendants() do
				if (d:IsA("BasePart") or d:IsA("Decal")) and d.Transparency < 1 then
					drawn += 1
				end
			end
			flag("world_baseplate_hidden_after_terrain", drawn == 0, drawn, 0)
		end
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
		local saved = {
			travel.Save,
			travel.Teleport,
			travel.Notify,
			travel.AllowStudio,
			travel.TIMEOUT,
			travel.Depart,
			travel.Retake,
			travel.IsAdmin,
		}
		travel.IsAdmin = function() -- the trip mechanics; who may go is world_gate_rule's
			return true
		end
		travel.Depart = function() end
		travel.Retake = function()
			return true
		end
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
		travel.Save, travel.Teleport, travel.Notify, travel.AllowStudio, travel.TIMEOUT, travel.Depart, travel.Retake, travel.IsAdmin =
			table.unpack(saved)
		for _, p in cleanup do
			pcall(travel.Failed, p, "ServerTest cleanup")
			p:Destroy()
		end
		flag("travel_no_error", ok, ok and 1 or tostring(err))
		return r
	end

	-- `world_travel_freeze` (review of 8557dcf, design doc 4.47: nothing earned is lost, nothing granted twice):
	-- WorldTravel.Go runs Depart (stop the run, leave the boss event) BEFORE the release save and freezes the player
	-- before it too, so the save yield pays and grants nothing (no roll, no StartPad run, no receipt); a player who
	-- leaves during the save is not teleported; a failure after the release save retakes the lock (Retake) once; the
	-- TIMEOUT runs while TeleportAsync hangs; a stale failure of an older trip never cancels a newer one.
	function W.world_travel_freeze()
		local r, flag = H.report("world_travel_freeze")
		local Server = script.Parent.Parent
		local travel = H.module(Server, "WorldTravel")
		local money = H.module(Server, "MoneyService")
		local gacha = H.module(Server, "GachaService")
		local runner = H.module(Server, "RunnerService")
		local shop = H.module(Server, "ShopService")
		local WorldConfig = require(Shared:WaitForChild("WorldConfig"))
		local Monetization = require(Shared:WaitForChild("MonetizationConfig"))
		local SpawnArea = require(Shared:WaitForChild("SpawnArea"))
		local oldCooldown = SpawnArea.START_COOLDOWN
		local api = travel ~= nil
			and money ~= nil
			and gacha ~= nil
			and runner ~= nil
			and shop ~= nil
			and type(travel.Depart) == "function"
			and type(travel.Retake) == "function"
		flag("freeze_api_exists", api == true)
		if not api then
			return r
		end
		local target = WorldConfig.Id == 1 and 2 or 1
		local saved = {
			travel.Save,
			travel.Teleport,
			travel.Notify,
			travel.AllowStudio,
			travel.TIMEOUT,
			travel.Depart,
			travel.Retake,
			travel.IsAdmin,
		}
		travel.IsAdmin = function() -- the trip mechanics; who may go is world_gate_rule's
			return true
		end
		local cleanup, log = {}, {}
		local duringSave = nil -- runs inside the release save's yield
		local hang = nil -- seconds the next Teleport hangs, then errors
		local retakes = 0
		travel.AllowStudio = true
		travel.Notify = function() end
		travel.Depart = function(p)
			table.insert(log, "depart:" .. tostring(p:GetAttribute("DataLoaded")))
		end
		travel.Save = function(p)
			table.insert(log, "save:" .. tostring(p:GetAttribute("Travelling")))
			if duringSave then
				duringSave(p)
			end
			return true, false
		end
		travel.Retake = function()
			retakes += 1
			return true
		end
		travel.Teleport = function()
			table.insert(log, "teleport")
			if hang then
				local seconds = hang
				hang = nil
				task.wait(seconds)
				error("ServerTest late teleport error")
			end
		end
		local function player(name)
			local p = H.player(cleanup, 971000 + #cleanup)
			p.Name = "ServerTestFreeze_" .. name
			money.Setup(p)
			p:SetAttribute("DataLoaded", true)
			return p
		end
		local ok, err = pcall(function()
			-- 1. Depart before the freeze and the save; the save sees a frozen player; nothing pays in its yield. The
			-- player has a live fake avatar on foot, so the StartPad would start a run but for the freeze (control below).
			local a = player("Order")
			local character = helpers.newFakeCharacter(runner.WalkSpawnCFrame())
			character.Parent = character.Parent or workspace
			table.insert(cleanup, character)
			runner.OnCharacter(a, character)
			SpawnArea.START_COOLDOWN = 0 -- so only the freeze can refuse the touch
			local leg = character:FindFirstChild("Left Leg")
			local rolls, receipt, pad = "unset", "unset", "unset"
			duringSave = function(p)
				local before = p:GetAttribute("Rolls")
				rolls = gacha.RollTick(p) == nil and gacha.Roll(p) == nil and p:GetAttribute("Rolls") == before
				pad = runner.PadTouched(p, leg) ~= true
					and runner.SetAutoRace(p, true) == false
					and not runner.IsAutoRacing(p)
				local pack = Monetization.GemPacks[1]
				shop.SetSave(function()
					return true
				end)
				shop.SetPlayers({
					GetPlayerByUserId = function()
						return p
					end,
				})
				local gems = p:GetAttribute("Gems")
				local decision = shop.ProcessReceipt({
					PlayerId = p:GetAttribute("UserId"),
					ProductId = pack.ProductId,
					PurchaseId = "ServerTestFreeze_" .. p.Name,
					CurrencySpent = pack.RobuxPrice,
				})
				shop.SetPlayers(nil)
				shop.SetSave(nil)
				receipt = decision == Enum.ProductPurchaseDecision.NotProcessedYet and p:GetAttribute("Gems") == gems
			end
			local okGo = travel.Go(a, target)
			duringSave = nil
			flag("freeze_go_ok", okGo == true)
			flag(
				"freeze_depart_before_save",
				log[1] == "depart:true" and log[2] == "save:true" and log[3] == "teleport",
				table.concat(log, ","),
				"depart:true,save:true,teleport"
			)
			flag("freeze_no_roll_during_save", rolls == true, tostring(rolls))
			flag("freeze_no_pad_run_during_save", pad == true, tostring(pad))
			flag("freeze_receipt_waits_during_save", receipt == true, tostring(receipt))
			flag("freeze_no_income_during_save", money.Award(a, 10) == nil)

			-- 2. A failure after the release save retakes the lock once
			travel.Failed(a, "ServerTest failure")
			task.wait(0.1)
			flag("freeze_failure_retakes_lock", retakes == 1, retakes, 1)
			flag(
				"freeze_failure_restores",
				a:GetAttribute("DataLoaded") == true and a:GetAttribute("Travelling") == nil
			)
			-- control: unfrozen, the same touch starts a run, and the real Depart stops it
			flag("freeze_pad_control_starts_run", runner.PadTouched(a, leg) == true and runner.IsAutoRacing(a))
			pcall(saved[6], a)
			flag("freeze_real_depart_stops_run", not runner.IsAutoRacing(a))
			runner.SetAutoRace(a, false)
			SpawnArea.START_COOLDOWN = oldCooldown

			-- real Save(frozen) and Retake on a PlayerData copy with a fake store: an unflagged save of a frozen player
			-- is refused, the frozen release save writes and drops the lock, the retake save takes it back
			do
				local module = Server.PlayerData:Clone()
				module.Name, module.Parent = "ServerTestFreezeData", Server
				table.insert(cleanup, module)
				local data = require(module)
				local store = H.store()
				data.SetStore(store)
				local id = 979101
				store.data[data.KeyFor(id)] = { Version = 1 }
				local f = H.player(cleanup, id)
				flag("freeze_data_fixture", data.Load(f, id) == true)
				f:SetAttribute("DataLoaded", nil)
				f:SetAttribute("Travelling", true)
				flag("freeze_unflagged_save_refused", data.Save(f, id, true) == false)
				local wrote = data.Save(f, id, true, true)
				local record = store.data[data.KeyFor(id)]
				flag(
					"freeze_frozen_release_save_writes",
					wrote == true and type(record) == "table" and record.Lock == nil
				)
				f:SetAttribute("Travelling", nil)
				f:SetAttribute("DataLoaded", true)
				local relocked = data.Save(f, id)
				record = store.data[data.KeyFor(id)]
				flag(
					"freeze_retake_relocks",
					relocked == true and type(record) == "table" and type(record.Lock) == "table"
				)
			end

			-- 3. Left during the release save: not teleported, not busy
			table.clear(log)
			local b = player("Leaves")
			duringSave = function(p)
				p.Parent = nil
			end
			local okLeft = travel.Go(b, target)
			duringSave = nil
			flag("freeze_left_mid_save_not_teleported", okLeft == false and table.find(log, "teleport") == nil)
			flag("freeze_left_mid_save_not_busy", travel.Busy(b) == false)

			-- 4. A hung TeleportAsync: the TIMEOUT still restores; its late error leaves a newer trip alone
			travel.TIMEOUT = 0.2
			retakes = 0
			local c = player("Hung")
			hang = 0.8
			local first = nil
			task.spawn(function()
				first = table.pack(travel.Go(c, target))
			end)
			task.wait(0.5)
			flag("freeze_hung_teleport_times_out", travel.Busy(c) == false and c:GetAttribute("DataLoaded") == true)
			flag("freeze_hung_teleport_retakes_lock", retakes == 1, retakes, 1)
			travel.TIMEOUT = 60
			local okSecond = travel.Go(c, target) -- a new trip while the first TeleportAsync still hangs
			task.wait(0.6) -- the hung call errors now
			flag("freeze_second_trip_ok", okSecond == true)
			flag("freeze_stale_failure_ignored", travel.Busy(c) == true and c:GetAttribute("Travelling") == true)
			flag("freeze_hung_go_returns_false", first ~= nil and first[1] == false)
		end)
		duringSave, hang = nil, nil
		SpawnArea.START_COOLDOWN = oldCooldown
		shop.SetPlayers(nil)
		shop.SetSave(nil)
		travel.Save, travel.Teleport, travel.Notify, travel.AllowStudio, travel.TIMEOUT, travel.Depart, travel.Retake, travel.IsAdmin =
			table.unpack(saved)
		for _, p in cleanup do
			pcall(travel.Failed, p, "ServerTest cleanup")
			p:Destroy()
		end
		flag("freeze_no_error", ok, ok and 1 or tostring(err))
		return r
	end

	-- `world_arrival` (design doc 4.47: the gate is locked for everyone, admins travel with /world2; audit 2026-11-24):
	-- in World 2 with WorldConfig.GATE_OPEN false, WorldTravel.Arrived sends a non-admin back to World 1 through
	-- WorldTravel.Go; never an admin (AdminService.IsAdmin, wired by Main.server), never with the gate open, never in
	-- World 1, never in Studio (AllowStudio off). WorldConfig.Id / GATE_OPEN are set on the shared module and restored.
	function W.world_arrival()
		local r, flag = H.report("world_arrival")
		local Server = script.Parent.Parent
		local travel = H.module(Server, "WorldTravel")
		local admin = H.module(Server, "AdminService")
		local config = H.module(Server, "AdminConfig")
		local WorldConfig = require(Shared:WaitForChild("WorldConfig"))
		local api = travel ~= nil and admin ~= nil and config ~= nil and type(travel.Arrived) == "function"
		flag("arrival_api_exists", api == true)
		if not api then
			return r
		end
		local saved = {
			travel.Save,
			travel.Teleport,
			travel.AllowStudio,
			travel.IsAdmin,
			admin.AllowStudio,
			WorldConfig.Id,
			WorldConfig.GATE_OPEN,
			travel.Depart,
			travel.Retake,
			travel.Kick,
			travel.ARRIVAL_RETRY,
		}
		local cleanup, sent = {}, {}
		local kicks = {}
		local ADMIN_ID = 978002
		local ok, err = pcall(function()
			flag("arrival_wired_to_admin_check", travel.IsAdmin == admin.IsAdmin)
			travel.IsAdmin = admin.IsAdmin
			travel.Depart = function() end
			travel.Retake = function()
				return true
			end
			travel.Kick = function(p)
				table.insert(kicks, p)
			end
			travel.ARRIVAL_RETRY = 0.05
			admin.AllowStudio = false -- only AdminConfig.UserIds makes an admin here
			table.insert(config.UserIds, ADMIN_ID)
			travel.Save = function()
				return true, false
			end
			travel.Teleport = function(placeId, p)
				table.insert(sent, { placeId, p })
			end
			local function player(id)
				local p = H.player(cleanup, id)
				p:SetAttribute("DataLoaded", true)
				return p
			end
			local guest, owner = player(978001), player(ADMIN_ID)
			WorldConfig.Id, WorldConfig.GATE_OPEN = 2, false

			travel.AllowStudio = false
			flag("arrival_never_in_studio", travel.Arrived(guest) == false and #sent == 0, #sent, 0)
			travel.AllowStudio = true -- as on a live server
			flag("arrival_admin_stays", travel.Arrived(owner) == false and #sent == 0, #sent, 0)
			local okGuest = travel.Arrived(guest)
			flag(
				"arrival_non_admin_sent_to_world1",
				okGuest == true and #sent == 1 and sent[1][1] == WorldConfig.PLACES[1] and sent[1][2] == guest,
				#sent,
				1
			)
			flag("arrival_uses_travel_go", travel.Busy(guest) == true) -- Go's one-trip guard holds the guest
			travel.Failed(guest, "ServerTest cleanup")

			flag(
				"arrival_failed_trip_stays_frozen",
				guest:GetAttribute("Travelling") == true and guest:GetAttribute("DataLoaded") == nil
			)

			-- a return trip that keeps failing: tried ARRIVAL_TRIES times, never unfrozen, then kicked once
			local teleport = travel.Teleport
			local tries = 0
			local failing = player(978005)
			travel.Teleport = function()
				tries += 1
				error("ServerTest teleport down")
			end
			travel.Arrived(failing)
			local deadline = os.clock() + 3
			while #kicks == 0 and os.clock() < deadline do
				task.wait(0.05)
			end
			travel.Teleport = teleport
			flag(
				"arrival_retries_then_kicks",
				tries == travel.ARRIVAL_TRIES and #kicks == 1,
				tries,
				travel.ARRIVAL_TRIES
			)
			flag("arrival_kicks_the_arrival", kicks[1] == failing and failing:GetAttribute("Travelling") == true)
			flag("arrival_failed_never_unfrozen", failing:GetAttribute("DataLoaded") == nil)
			flag("arrival_only_failing_kicked", #kicks == 1 and table.find(kicks, guest) == nil, #kicks, 1)
			sent = { sent[1] } -- the counts below are of the first guest's trip

			WorldConfig.GATE_OPEN = true
			local qualified = player(978003)
			qualified:SetAttribute("World1BestTrack", WorldConfig.GATE_TRACK)
			qualified:SetAttribute("RebirthLevel", WorldConfig.GATE_REBIRTH)
			flag("arrival_open_gate_qualified_stays", travel.Arrived(qualified) == false and #sent == 1, #sent, 1)
			WorldConfig.Id, WorldConfig.GATE_OPEN = 1, false
			flag("arrival_world1_stays", travel.Arrived(player(978004)) == false and #sent == 1, #sent, 1)
		end)
		travel.Save, travel.Teleport, travel.AllowStudio, travel.IsAdmin = saved[1], saved[2], saved[3], saved[4]
		admin.AllowStudio, WorldConfig.Id, WorldConfig.GATE_OPEN = saved[5], saved[6], saved[7]
		travel.Depart, travel.Retake, travel.Kick, travel.ARRIVAL_RETRY = saved[8], saved[9], saved[10], saved[11]
		local at = table.find(config.UserIds, ADMIN_ID)
		if at then
			table.remove(config.UserIds, at)
		end
		for _, p in cleanup do
			pcall(travel.Failed, p, "ServerTest cleanup")
			p:Destroy()
		end
		flag("arrival_no_error", ok, ok and 1 or tostring(err))
		return r
	end

	-- `world_gate_rule` (design doc 4.47, owner 2026-11-24): WorldTravel.CanEnter is the one rule for the gate touch,
	-- Go and the arrival check. Admins always; World 1 always; anyone else needs WorldConfig.GATE_OPEN AND World 1 Track
	-- GATE_TRACK beaten (BestTrack: highest track number beaten; World1BestTrack in World 2) AND RebirthLevel >=
	-- GATE_REBIRTH. A closed gate refuses a qualified non-admin in Go and in Arrived; an open gate keeps a qualified
	-- arrival. GATE_OPEN / Id are set on the shared module for the test and restored.
	function W.world_gate_rule()
		local r, flag = H.report("world_gate_rule")
		local Server = script.Parent.Parent
		local travel = H.module(Server, "WorldTravel")
		local WorldConfig = require(Shared:WaitForChild("WorldConfig"))
		local api = travel ~= nil and type(travel.CanEnter) == "function"
		flag("gate_rule_api_exists", api == true)
		flag("gate_rule_numbers", WorldConfig.GATE_TRACK == 10 and WorldConfig.GATE_REBIRTH == 5)
		flag("gate_rule_ships_closed", WorldConfig.GATE_OPEN == false)
		if not api then
			return r
		end
		local saved = {
			travel.IsAdmin,
			travel.Save,
			travel.Teleport,
			travel.AllowStudio,
			travel.Depart,
			WorldConfig.Id,
			WorldConfig.GATE_OPEN,
		}
		local cleanup, sent, admins = {}, {}, {}
		local ok, err = pcall(function()
			travel.IsAdmin = function(p)
				return admins[p] == true
			end
			travel.Save = function()
				return true, false
			end
			travel.Teleport = function(_, p)
				table.insert(sent, p)
			end
			travel.Depart = function() end
			travel.AllowStudio = true
			local function player(id, best, rebirth)
				local p = H.player(cleanup, id)
				p:SetAttribute("DataLoaded", true)
				p:SetAttribute("BestTrack", best)
				p:SetAttribute("World1BestTrack", best)
				p:SetAttribute("RebirthLevel", rebirth)
				return p
			end
			local T, R = WorldConfig.GATE_TRACK, WorldConfig.GATE_REBIRTH
			local admin = player(979101, 0, 0)
			admins[admin] = true
			local fit, lowTrack, lowRebirth =
				player(979102, T, R), player(979103, T - 1, R + 3), player(979104, T + 5, R - 1)
			for _, id in { 1, 2 } do
				WorldConfig.Id = id
				WorldConfig.GATE_OPEN = false
				local okA = travel.CanEnter(admin, 2)
				local okC, whyC = travel.CanEnter(fit, 2)
				flag("gate_rule_admin_always_closed_w" .. id, okA == true)
				flag("gate_rule_closed_refuses_qualified_w" .. id, okC == false and whyC == "COMING SOON", whyC)
				flag("gate_rule_world1_always_closed_w" .. id, travel.CanEnter(lowTrack, 1) == true)
				WorldConfig.GATE_OPEN = true
				local okF = travel.CanEnter(fit, 2)
				local okT, whyT = travel.CanEnter(lowTrack, 2)
				local okR, whyR = travel.CanEnter(lowRebirth, 2)
				flag("gate_rule_admin_always_open_w" .. id, travel.CanEnter(admin, 2) == true)
				flag("gate_rule_open_admits_qualified_w" .. id, okF == true)
				flag("gate_rule_open_needs_track_w" .. id, okT == false and whyT == "Beat Track " .. T, whyT)
				flag("gate_rule_open_needs_rebirth_w" .. id, okR == false and whyR == "Reach Rebirth " .. R, whyR)
				flag("gate_rule_world1_always_open_w" .. id, travel.CanEnter(lowRebirth, 1) == true)
			end
			-- World 2 reads World 1's progress, not its own BestTrack
			WorldConfig.Id, WorldConfig.GATE_OPEN = 2, true
			local w2Only = player(979105, 0, R)
			w2Only:SetAttribute("BestTrack", T)
			flag("gate_rule_w2_reads_world1_best", travel.CanEnter(w2Only, 2) == false)

			-- PlayerData in World 2 mirrors the save's top-level (World 1) BestTrack into World1BestTrack on load
			local module = Server.PlayerData:Clone()
			module.Name, module.Parent = "ServerTestGateData", Server
			table.insert(cleanup, module)
			local data = require(module)
			local store = H.store()
			data.SetStore(store)
			local function loaded(id, best)
				store.data[data.KeyFor(id)] = { Version = 1, BestTrack = best, RebirthLevel = R }
				local p = H.player(cleanup, id)
				local okLoad = data.Load(p, id)
				return p, okLoad
			end
			local p10, ok10 = loaded(979120, T)
			local p9, ok9 = loaded(979121, T - 1)
			flag("gate_rule_load_fixture", ok10 == true and ok9 == true and p10:GetAttribute("RebirthLevel") == R)
			flag("gate_rule_load_mirrors_world1_best", p10:GetAttribute("World1BestTrack") == T)
			flag("gate_rule_load_w2_own_best", (p10:GetAttribute("BestTrack") or 0) == 0) -- World 2's own, fresh
			flag("gate_rule_load_qualifies", travel.CanEnter(p10, 2) == true)
			flag("gate_rule_load_track9_refused", travel.CanEnter(p9, 2) == false)
			data.Save(p10, 979120)
			local rec = store.data[data.KeyFor(979120)]
			flag(
				"gate_rule_mirror_never_saved",
				type(rec) == "table" and rec.World1BestTrack == nil and rec.BestTrack == T
			)

			-- Go (the gate touch and /world2 both go through it) in World 1: a closed gate is a second condition
			WorldConfig.Id, WorldConfig.GATE_OPEN = 1, false
			local goC, goWhy = travel.Go(fit, 2)
			flag("gate_rule_go_closed_refuses_qualified", goC == false and #sent == 0, goWhy)
			local goA = travel.Go(admin, 2)
			flag("gate_rule_go_admin_closed", goA == true and sent[#sent] == admin, #sent, 1)
			WorldConfig.GATE_OPEN = true
			local goT, goTWhy = travel.Go(lowTrack, 2)
			flag("gate_rule_go_open_refuses_unqualified", goT == false and #sent == 1, goTWhy)
			local goF = travel.Go(fit, 2)
			flag("gate_rule_go_open_admits_qualified", goF == true and sent[#sent] == fit, #sent, 2)
			travel.Failed(admin, "ServerTest cleanup")
			travel.Failed(fit, "ServerTest cleanup")

			-- Arrived (World 2) follows the same rule; each arrival is destroyed at once so no retry runs
			local function arrive(id, best, rebirth)
				local p = player(id, best, rebirth)
				local before = #sent
				local went = travel.Arrived(p)
				local back = #sent > before and sent[#sent] == p
				p.Parent = nil
				return went, back
			end
			WorldConfig.Id, WorldConfig.GATE_OPEN = 2, false
			local wentC, backC = arrive(979110, T, R)
			flag("gate_rule_arrival_closed_sends_qualified_back", wentC == true and backC == true)
			WorldConfig.GATE_OPEN = true
			local wentF, backF = arrive(979111, T, R)
			flag("gate_rule_arrival_open_qualified_stays", wentF == false and backF == false)
			local wentT, backT = arrive(979112, T - 1, R)
			flag("gate_rule_arrival_open_low_track_back", wentT == true and backT == true)
			local wentR, backR = arrive(979113, T, R - 1)
			flag("gate_rule_arrival_open_low_rebirth_back", wentR == true and backR == true)
		end)
		travel.IsAdmin, travel.Save, travel.Teleport, travel.AllowStudio, travel.Depart = table.unpack(saved, 1, 5)
		WorldConfig.Id, WorldConfig.GATE_OPEN = saved[6], saved[7]
		for _, p in cleanup do
			pcall(travel.Failed, p, "ServerTest cleanup")
			p:Destroy()
		end
		flag("gate_rule_no_error", ok, ok and 1 or tostring(err))
		return r
	end

	-- `world_travel_review` (review of 3258513, design doc 4.47): mutants that survived the earlier tests. A release save
	-- that outlives TIMEOUT never travels and retakes the lock once (an arrival's instead marks the lock out for later
	-- tries); a failed save tells a normal traveller once and keeps an arrival frozen; an arrival carries DataLoaded and
	-- the release across return trips, a hung trip still ends at TIMEOUT and the kick comes after one more frozen
	-- release save; TeleportInitFailed with no teleport data fails the pending trip, an older trip id does not; Depart
	-- calls DuelService.PlayerLeft as a traveller (cooldown kept); a frozen player picks no starter and takes no admin
	-- command (and /roll says so); a group rank lookup that keeps failing is "unknown" and the arrival waits.
	function W.world_travel_review()
		local r, flag = H.report("world_travel_review")
		local Server = script.Parent.Parent
		local travel = H.module(Server, "WorldTravel")
		local admin = H.module(Server, "AdminService")
		local config = H.module(Server, "AdminConfig")
		local gacha = H.module(Server, "GachaService")
		local money = H.module(Server, "MoneyService")
		local duel = H.module(Server, "DuelService")
		local runner = H.module(Server, "RunnerService")
		local boss = H.module(Server, "BossEventService")
		local WorldConfig = require(Shared:WaitForChild("WorldConfig"))
		local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
		local api = travel ~= nil
			and admin ~= nil
			and type(travel.InitFailed) == "function"
			and type(admin.RankOf) == "function"
			and type(admin.GroupOf) == "function"
		flag("review_api_exists", api == true)
		if not api then
			return r
		end
		local keys = {
			"Save",
			"Teleport",
			"Notify",
			"AllowStudio",
			"TIMEOUT",
			"Depart",
			"Retake",
			"IsAdmin",
			"Kick",
			"ARRIVAL_RETRY",
			"ADMIN_RECHECK",
			"ADMIN_RECHECKS",
			"ARRIVAL_WAIT",
			"Notice",
			"Stayed",
		}
		local saved = {}
		for i, k in keys do
			saved[i] = travel[k]
		end
		local savedAdmin = { admin.GroupOf, admin.RankOf, admin.RANK_WAIT, admin.AllowStudio }
		local savedDuel = { duel and duel.PlayerLeft, runner and runner.SetAutoRace, boss and boss.Leave }
		local savedWorld = { WorldConfig.Id, WorldConfig.GATE_OPEN }
		local cleanup = {}
		local saves, teleports, notes, retakes, kicks = 0, 0, 0, 0, {}
		local saveFn = function(_p)
			return true, false
		end
		local teleportFn = function(_p) end
		local ok, err = pcall(function()
			travel.AllowStudio = true
			travel.Depart = function() end
			travel.Save = function(p)
				saves += 1
				return saveFn(p)
			end
			travel.Teleport = function(_, p)
				teleports += 1
				return teleportFn(p)
			end
			travel.Notify = function()
				notes += 1
			end
			travel.Retake = function()
				retakes += 1
				return true
			end
			travel.Kick = function(p)
				table.insert(kicks, p)
			end
			travel.IsAdmin = function()
				return false
			end
			travel.ARRIVAL_RETRY = 0.05
			local nextId = 979200
			local function player()
				nextId += 1
				local p = H.player(cleanup, nextId)
				p:SetAttribute("DataLoaded", true)
				return p
			end
			local function reset(save, teleport)
				saves, teleports, notes, retakes, kicks = 0, 0, 0, 0, {}
				saveFn = save or function(_p)
					return true, false
				end
				teleportFn = teleport or function(_p) end
			end
			local function waitUntil(fn, seconds)
				local deadline = os.clock() + seconds
				while not fn() and os.clock() < deadline do
					task.wait(0.05)
				end
				return fn()
			end
			local target = WorldConfig.Id == 1 and 2 or 1
			travel.IsAdmin = function() -- a normal trip: who may go is world_gate_rule's
				return true
			end

			-- 1. Late release save (outlives TIMEOUT): no teleport, unfrozen, one lock retake
			travel.TIMEOUT = 0.15
			reset(function()
				task.wait(0.4)
				return true, false
			end)
			local late = player()
			local okLate, whyLate = travel.Go(late, target)
			task.wait(0.1)
			flag("review_late_save_no_travel", okLate == false and teleports == 0, whyLate)
			flag("review_late_save_retakes_once", retakes == 1, retakes, 1)
			flag("review_late_save_unfrozen", late:GetAttribute("DataLoaded") == true and not travel.Busy(late))
			-- the same for an arrival: the lock is marked out, no retake
			reset(function()
				task.wait(0.4)
				return true, false
			end)
			local carry = { Loaded = true, Released = false }
			local lateArrival = player()
			travel.Go(lateArrival, 1 == WorldConfig.Id and 2 or 1, carry)
			task.wait(0.1)
			flag("review_late_arrival_save_marks_release", carry.Released == true and retakes == 0, retakes, 0)
			flag("review_late_arrival_stays_frozen", lateArrival:GetAttribute("Travelling") == true)
			travel.TIMEOUT = 60

			-- 2. A failed release save: told once and unfrozen; an arrival stays frozen, untold
			reset(function()
				return false, false
			end)
			local failSave = player()
			local okFail = travel.Go(failSave, target)
			flag("review_save_fail_notifies_once", okFail == false and notes == 1 and teleports == 0, notes, 1)
			flag("review_save_fail_unfrozen", failSave:GetAttribute("DataLoaded") == true)
			reset(function()
				return false, false
			end)
			local failArrival = player()
			travel.Go(failArrival, target, { Loaded = true, Released = false })
			flag(
				"review_arrival_save_fail_stays_frozen",
				notes == 0
					and failArrival:GetAttribute("DataLoaded") == nil
					and failArrival:GetAttribute("Travelling") == true
					and not travel.Busy(failArrival)
			)

			-- 3. TeleportInitFailed: no teleport data fails the pending trip; an older trip id leaves it alone
			reset()
			local init = player()
			travel.Go(init, target)
			travel.InitFailed(init, "ServerTest", "old", {
				GetTeleportData = function()
					return { TravelTrip = -1 }
				end,
			})
			flag("review_init_old_id_ignored", travel.Busy(init) == true)
			travel.InitFailed(init, "ServerTest", "nil data", nil)
			flag("review_init_nil_data_fails", travel.Busy(init) == false and notes == 1, notes, 1)

			-- 4. Arrivals (World 2, the gate closed): every save fails, the first one late -> each try saves again
			-- (DataLoaded carried), never unfrozen, one more release save, then one kick
			WorldConfig.Id, WorldConfig.GATE_OPEN = 2, false
			travel.IsAdmin = function()
				return false
			end
			travel.TIMEOUT = 0.15
			local first = true
			reset(function()
				if first then
					first = false
					task.wait(0.3)
				end
				return false, false
			end)
			local stuck = player()
			flag("review_arrival_sent", travel.Arrived(stuck) == true)
			waitUntil(function()
				return #kicks > 0
			end, 4)
			flag(
				"review_arrival_saves_each_try_then_before_kick",
				saves == travel.ARRIVAL_TRIES + 1 and teleports == 0,
				saves,
				travel.ARRIVAL_TRIES + 1
			)
			flag("review_arrival_kicked_once", #kicks == 1 and kicks[1] == stuck, #kicks, 1)
			flag(
				"review_arrival_never_unfrozen",
				stuck:GetAttribute("DataLoaded") == nil and stuck:GetAttribute("Travelling") == true
			)
			-- saved once, every teleport hangs: each hung trip ends at TIMEOUT, later tries skip the save, no extra save
			reset(nil, function()
				task.wait(5)
			end)
			local hung = player()
			travel.Arrived(hung)
			waitUntil(function()
				return #kicks > 0
			end, 4)
			flag("review_hung_trip_still_kicks", #kicks == 1 and kicks[1] == hung, #kicks, 1)
			flag(
				"review_release_carried_across_tries",
				saves == 1 and teleports == travel.ARRIVAL_TRIES,
				saves * 10 + teleports,
				10 + travel.ARRIVAL_TRIES
			)
			-- a pending return trip (teleport went out) is never kicked
			travel.TIMEOUT = 60
			reset()
			local pending = player()
			travel.Arrived(pending)
			task.wait(travel.ARRIVAL_TRIES * travel.ARRIVAL_RETRY + 0.5)
			flag(
				"review_pending_arrival_not_kicked",
				#kicks == 0 and travel.Busy(pending) and teleports == 1,
				#kicks,
				0
			)

			-- 5. Group rank lookup: failing every try is "unknown"; the arrival waits, then goes once the rank is known
			local calls, rank = 0, nil
			admin.GroupOf = function()
				return 1
			end
			admin.RankOf = function()
				calls += 1
				if rank == nil then
					error("ServerTest rank down")
				end
				return rank
			end
			admin.RANK_WAIT = 0.01
			admin.AllowStudio = false
			travel.IsAdmin = admin.IsAdmin
			local member = player()
			local isAdmin, state = admin.IsAdmin(member)
			flag("review_rank_unknown", isAdmin == false and state == "unknown", tostring(state))
			flag("review_rank_tried", calls == admin.RANK_TRIES, calls, admin.RANK_TRIES)
			travel.ADMIN_RECHECK = 0.1
			reset()
			local okArr = travel.Arrived(member)
			flag("review_rank_unknown_arrival_waits", okArr == false and teleports == 0, teleports, 0)
			rank = 0
			flag(
				"review_rank_known_arrival_goes",
				waitUntil(function()
					return teleports == 1
				end, 2),
				teleports,
				1
			)
			local leaver = player()
			calls = 0
			rank = nil
			admin.RankOf = function(p)
				calls += 1
				p.Parent = nil
				error("ServerTest rank down")
			end
			flag("review_rank_left_during_wait", admin.IsAdmin(leaver) == false and calls == 1, calls, 1)
			admin.GroupOf, admin.RankOf, admin.RANK_WAIT = savedAdmin[1], savedAdmin[2], savedAdmin[3]

			-- 6. Depart (the real one) calls DuelService.PlayerLeft as a traveller, stops auto racing, leaves the event
			if duel and runner and boss then
				local seen = {}
				duel.PlayerLeft = function(_, travelling)
					seen.Duel = travelling == true
				end
				runner.SetAutoRace = function(_, on)
					seen.Auto = on == false
				end
				boss.Leave = function(_, why)
					seen.Boss = why == "Travel"
				end
				saved[6](player())
				duel.PlayerLeft, runner.SetAutoRace, boss.Leave = savedDuel[1], savedDuel[2], savedDuel[3]
				flag("review_depart_duel_as_traveller", seen.Duel == true)
				flag("review_depart_stops_auto", seen.Auto == true)
				flag("review_depart_leaves_event", seen.Boss == true)
			end

			-- 7. A frozen (travelling) player picks no starter and takes no admin command; /roll that rolls nothing fails
			local frozen = player()
			if money then
				money.Setup(frozen)
			end
			frozen:SetAttribute("NeedsStarter", true)
			frozen:SetAttribute("Travelling", true)
			local pick = CharacterCatalog.STARTER_PICKS[1]
			flag("review_frozen_no_starter", gacha.PickStarter(frozen, pick) == false)
			table.insert(config.UserIds, frozen:GetAttribute("UserId") or nextId)
			local okCmd, cmdMessage = admin.Run(frozen, "/money 5")
			flag(
				"review_frozen_no_admin_command",
				okCmd == false and string.find(cmdMessage, "travelling") ~= nil,
				cmdMessage
			)
			local roll = admin.Commands.roll
			frozen:SetAttribute("DataLoaded", nil)
			local okRoll, rollMessage = roll.Apply(frozen, 2)
			flag("review_roll_refused_says_so", okRoll == false and not string.find(rollMessage, "rolled"), rollMessage)
			local at = table.find(config.UserIds, frozen:GetAttribute("UserId") or nextId)
			if at then
				table.remove(config.UserIds, at)
			end

			-- 8. The gate touch (WorldTravel.Touched): a Locked gate only tells, never sends (admins too); an open gate
			-- tells a refused player why and sends one CanEnter allows; a part with no TargetWorld does nothing
			local notices = {}
			travel.Notice = function(p, text)
				table.insert(notices, { p, text })
			end
			local adminNow = false
			travel.IsAdmin = function()
				return adminNow
			end
			WorldConfig.Id, WorldConfig.GATE_OPEN = 1, false
			travel.TIMEOUT = 60
			reset()
			local gate = Instance.new("Part")
			table.insert(cleanup, gate)
			gate:SetAttribute("TargetWorld", 2)
			gate:SetAttribute("Locked", true)
			local toucher = player()
			local sentLocked = travel.Touched(gate, toucher)
			flag(
				"review_touch_locked_tells",
				sentLocked == false and #notices == 1 and notices[1][2] == "COMING SOON" and teleports == 0,
				notices[1] and notices[1][2]
			)
			adminNow = true
			local sentAdmin = travel.Touched(gate, toucher)
			flag("review_touch_locked_admin_stays", sentAdmin == false and #notices == 1 and teleports == 0)
			gate:SetAttribute("Locked", false)
			WorldConfig.GATE_OPEN = true
			adminNow = false
			local sentOpen = travel.Touched(gate, toucher)
			flag(
				"review_touch_open_unqualified_told",
				sentOpen == false and #notices == 2 and notices[2][2] == "Beat Track " .. WorldConfig.GATE_TRACK,
				notices[2] and notices[2][2]
			)
			adminNow = true
			flag(
				"review_touch_open_allowed_goes",
				travel.Touched(gate, toucher) == true and teleports == 1,
				teleports,
				1
			)
			travel.Failed(toucher, "ServerTest cleanup")
			gate:SetAttribute("TargetWorld", nil)
			flag("review_touch_no_target_nothing", travel.Touched(gate, player()) == false and #notices == 2)
			WorldConfig.GATE_OPEN = false

			-- 9. Lock retake only for a player still here: Failed after the release, and a late release save
			reset()
			local gone = player()
			travel.Go(gone, 2)
			gone.Parent = nil
			travel.Failed(gone, "ServerTest")
			task.wait(0.1)
			flag("review_retake_not_after_leave", retakes == 0, retakes, 0)
			local here = player()
			travel.Go(here, 2)
			travel.Failed(here, "ServerTest")
			task.wait(0.1)
			flag("review_retake_control", retakes == 1, retakes, 1)
			travel.TIMEOUT = 0.15
			reset(function(p)
				task.wait(0.3)
				p.Parent = nil
				return true, false
			end)
			travel.Go(player(), 2)
			task.wait(0.1)
			flag("review_late_save_no_retake_after_leave", retakes == 0, retakes, 0)
			-- PlayerData.Save(..., present): no write for a player who left
			do
				local module = Server.PlayerData:Clone()
				module.Name, module.Parent = "ServerTestReviewData", Server
				table.insert(cleanup, module)
				local data = require(module)
				local store = H.store()
				data.SetStore(store)
				local id = 979290
				store.data[data.KeyFor(id)] = { Version = 1 }
				local f = H.player(cleanup, id)
				data.Load(f, id)
				local updates = store.updates
				f.Parent = nil
				local wrote = data.Save(f, id, nil, nil, true)
				flag(
					"review_present_save_skips_left",
					wrote == false and store.updates == updates,
					store.updates - updates,
					0
				)
			end

			-- 10. Arrivals in World 2: the retry wait, a read-only save, a player who now qualifies, the bounded final
			-- save, no kick for a player who left, the capped admin recheck, the load wait
			WorldConfig.Id, WorldConfig.GATE_OPEN = 2, false
			adminNow = false
			travel.TIMEOUT = 0.15
			travel.ARRIVAL_RETRY = 0.3
			reset(nil, function()
				error("ServerTest teleport down")
			end)
			local slow = player()
			local t0 = os.clock()
			travel.Arrived(slow)
			waitUntil(function()
				return #kicks > 0
			end, 4)
			local took = os.clock() - t0
			flag("review_retry_waits", #kicks == 1 and took >= 2 * 0.3 - 0.05, took, 0.55)
			travel.ARRIVAL_RETRY = 0.05
			reset(function()
				return false, true
			end, function()
				error("ServerTest teleport down")
			end)
			local reader = player()
			travel.Arrived(reader)
			waitUntil(function()
				return #kicks > 0
			end, 3)
			flag(
				"review_readonly_counts_as_released",
				saves == 1 and teleports == travel.ARRIVAL_TRIES and #kicks == 1,
				saves * 10 + teleports,
				10 + travel.ARRIVAL_TRIES
			)
			reset(nil, function()
				error("ServerTest teleport down")
			end)
			local lateOk = player()
			travel.Arrived(lateOk)
			task.wait(0.02)
			adminNow = true -- qualifies before the second try
			waitUntil(function()
				return lateOk:GetAttribute("Travelling") == nil
			end, 2)
			task.wait(0.1)
			flag(
				"review_now_allowed_stays",
				#kicks == 0 and teleports == 1 and lateOk:GetAttribute("DataLoaded") == true and retakes == 1,
				teleports * 10 + retakes,
				11
			)
			adminNow = false
			local finals = 0
			reset(function()
				finals += 1
				if finals > travel.ARRIVAL_TRIES then
					task.wait(5) -- the final release save hangs
				end
				return false, false
			end)
			local hangs = player()
			travel.Arrived(hangs)
			flag("review_final_save_bounded", waitUntil(function()
				return #kicks > 0
			end, 3) and kicks[1] == hangs)
			finals = 0
			reset(function(p)
				finals += 1
				if finals > travel.ARRIVAL_TRIES then
					p.Parent = nil -- left during the final save
				end
				return false, false
			end)
			travel.Arrived(player())
			task.wait(1)
			flag("review_no_kick_after_leave", #kicks == 0 and finals == travel.ARRIVAL_TRIES + 1, finals)
			-- an admin check that stays "unknown": asked ADMIN_RECHECKS more times, then sent back
			local asks = 0
			travel.IsAdmin = function()
				asks += 1
				return false, "unknown"
			end
			travel.ADMIN_RECHECK, travel.ADMIN_RECHECKS = 0.02, 3
			reset()
			local unsure = player()
			flag("review_unknown_waits", travel.Arrived(unsure) == false and teleports == 0)
			waitUntil(function()
				return teleports > 0
			end, 2)
			flag("review_unknown_capped_then_sent", teleports == 1 and asks >= 4, asks, 4)
			unsure.Parent = nil -- its pending trip would time out and try again
			travel.TIMEOUT = 60
			travel.IsAdmin = function()
				return false
			end
			-- Arrive: a load that never decides is kicked; a failed load is checked (sent back), a loaded one too
			travel.ARRIVAL_WAIT = 0.3
			reset()
			local never = player()
			never:SetAttribute("DataLoaded", nil)
			local okNever = travel.Arrive(never)
			flag("review_arrive_undecided_kicked", okNever == false and kicks[1] == never and teleports == 0)
			reset()
			local failed = player()
			failed:SetAttribute("DataLoaded", nil)
			failed:SetAttribute("DataFailed", true)
			flag("review_arrive_failed_load_checked", travel.Arrive(failed) == true and teleports == 1)
			reset()
			local waits = player()
			waits:SetAttribute("DataLoaded", nil)
			task.delay(0.1, function()
				waits:SetAttribute("DataLoaded", true)
			end)
			flag("review_arrive_waits_for_load", travel.Arrive(waits) == true and #kicks == 0 and teleports == 1)

			-- 11. Review of 3742dd3: a late arrival release save retakes the lock once the arrival stays; Go refuses a
			-- player still loading (and tells them); an admin found only by a recheck gets the welcome
			travel.TIMEOUT = 0.15
			adminNow = false
			travel.IsAdmin = function()
				return adminNow
			end
			reset(function()
				task.wait(0.35)
				return true, false
			end)
			local stays = player()
			travel.Arrived(stays)
			task.wait(0.05)
			adminNow = true -- allowed by the time sendBack asks again
			task.wait(0.6)
			flag(
				"review_late_arrival_save_retaken_when_staying",
				stays:GetAttribute("Travelling") == nil and retakes == 1 and teleports == 0,
				retakes,
				1
			)
			travel.TIMEOUT = 60
			WorldConfig.Id = 1
			reset()
			table.clear(notices)
			local loading = player()
			loading:SetAttribute("DataLoaded", nil)
			local okLoading = travel.Go(loading, 2)
			flag(
				"review_go_refuses_loading",
				okLoading == false and saves == 0 and teleports == 0 and notices[1] and notices[1][1] == loading,
				saves * 10 + teleports
			)
			loading:SetAttribute("DataFailed", true)
			flag("review_go_failed_load_travels", travel.Go(loading, 2) == true and teleports == 1)
			travel.Failed(loading, "ServerTest cleanup")
			WorldConfig.Id = 2
			local stayed, unknownOnce = {}, true
			travel.Stayed = function(p)
				table.insert(stayed, p)
			end
			travel.IsAdmin = function()
				if unknownOnce then
					unknownOnce = false
					return false, "unknown"
				end
				return true
			end
			travel.ADMIN_RECHECK = 0.02
			reset()
			local lateAdmin = player()
			travel.Arrived(lateAdmin)
			flag("review_recheck_admin_welcomed", waitUntil(function()
				return #stayed > 0
			end, 1) and stayed[1] == lateAdmin and teleports == 0)
			flag("review_first_check_no_welcome_call", travel.Arrived(player()) == false and #stayed == 1, #stayed, 1)
		end)
		for i, k in keys do
			travel[k] = saved[i]
		end
		admin.GroupOf, admin.RankOf, admin.RANK_WAIT, admin.AllowStudio = table.unpack(savedAdmin, 1, 4)
		if duel and runner and boss then
			duel.PlayerLeft, runner.SetAutoRace, boss.Leave = savedDuel[1], savedDuel[2], savedDuel[3]
		end
		WorldConfig.Id, WorldConfig.GATE_OPEN = savedWorld[1], savedWorld[2]
		for _, p in cleanup do
			pcall(travel.Failed, p, "ServerTest cleanup")
			p:Destroy()
		end
		flag("review_no_error", ok, ok and 1 or tostring(err))
		return r
	end

	-- `biome_runtime` (World 2 runtime review, BIOME_ENVIRONMENT_SPEC 4.2 and 8, WORLD2_SPEC "Blender first"), on a copy
	-- of Server/BiomeAssets with its Row and Fetch seams: a slow load falls back to parts within TIMEOUT and serves
	-- later props once it arrives; a failed key is loaded again by itself (no Clone needed); a template whose property
	-- writes throw never errors out; an unreviewed row is never fetched; a def's CastShadow wins over the size rule.
	-- BiomeDressing.Build yields every YIELD_EVERY props (control: a huge YIELD_EVERY builds in one go). Every draft
	-- lamp (Lamp_<i>) in the live world stands inside a Placed_ prop and is tagged BiomeEffect (World 2 Play; World 1 has
	-- no draft lamps, so there it only checks that none is loose).
	function W.biome_runtime()
		local r, flag = H.report("biome_runtime")
		local Server = script.Parent.Parent
		local cleanup = {}
		local ok, err = pcall(function()
			local module = Server.BiomeAssets:Clone()
			module.Name, module.Parent = "ServerTestBiomeAssets", Server
			table.insert(cleanup, module)
			local A = require(module)
			A.DEBUG = false
			A.TIMEOUT, A.RETRY = 0.2, { 0.2, 1e9 }
			A.Row = function(_, key, kind)
				if kind == "Mesh" and key ~= "Unreviewed" then
					return { Id = "rbxassetid://1", Key = key }
				end
				return nil
			end
			local fetches = {}
			A.Fetch = function(row)
				fetches[row.Key] = (fetches[row.Key] or 0) + 1
				if row.Key == "Slow" then
					task.wait(0.5)
				elseif row.Key == "Flaky" and fetches.Flaky == 1 then
					error("ServerTest flaky load")
				elseif row.Key == "BadTemplate" then
					return Instance.new("Folder") -- Anchored and the rest do not exist: the writes throw
				end
				local part = Instance.new("Part")
				table.insert(cleanup, part)
				return part
			end
			local small, big = Vector3.new(2, 2, 2), Vector3.new(40, 40, 40)
			local t0 = os.clock()
			flag(
				"assets_timeout_falls_back",
				A.Clone("T", "Slow", small) == nil and os.clock() - t0 < 0.5,
				os.clock() - t0
			)
			task.wait(0.5)
			local late = A.Clone("T", "Slow", small)
			flag("assets_late_load_serves_later_props", late ~= nil and fetches.Slow == 1)

			flag("assets_failure_falls_back", A.Clone("T", "Flaky", small) == nil)
			task.wait(0.5)
			flag("assets_retry_runs_by_itself", fetches.Flaky == 2, fetches.Flaky, 2)
			flag("assets_retry_loads", A.Clone("T", "Flaky", small) ~= nil)

			local okBad, bad = pcall(A.Clone, "T", "BadTemplate", small)
			flag("assets_bad_template_no_error", okBad and bad == nil, tostring(bad))
			flag(
				"assets_unreviewed_never_fetched",
				A.Clone("T", "Unreviewed", small) == nil and fetches.Unreviewed == nil
			)

			local plain, plainBig = A.Clone("T", "Fast", small), A.Clone("T", "Fast", big)
			local off, on = A.Clone("T", "Fast", big, false), A.Clone("T", "Fast", small, true)
			flag(
				"assets_cast_shadow_flag",
				plain.CastShadow == false
					and plainBig.CastShadow == true
					and off.CastShadow == false
					and on.CastShadow == true
			)
			for _, part in { late, plain, plainBig, off, on } do
				part:Destroy()
			end

			-- the build yields every YIELD_EVERY props
			local BD = require(Shared.BiomeDressing)
			local TB = require(Shared.TrackBuilder)
			local spec = require(Shared.TrackRegistry).Chain()[1]
			local old = BD.YIELD_EVERY
			local function build(every)
				BD.YIELD_EVERY = every
				local done, model = false, nil
				task.spawn(function()
					model = TB.Build(spec, CFrame.new(0, -2000, 60000))
					done = true
				end)
				local yielded = not done
				local deadline = os.clock() + 60
				while not done and os.clock() < deadline do
					task.wait(0.1)
				end
				BD.YIELD_EVERY = old
				if model then
					table.insert(cleanup, model)
				end
				return yielded, done
			end
			local yieldedOnce, doneOnce = build(1e9)
			flag("build_control_no_yield", doneOnce and not yieldedOnce)
			local yielded, done = build(1)
			flag("build_yields_between_props", done and yielded)

			-- draft lamps in the live world
			local lamps, loose, untagged = 0, 0, 0
			for _, model in (Workspace:FindFirstChild("Track") or Instance.new("Folder")):GetChildren() do
				local env = model:FindFirstChild("Environment")
				for _, d in env and env:GetDescendants() or {} do
					if d:IsA("BasePart") and string.match(d.Name, "^Lamp_%d+$") then
						lamps += 1
						if not (d.Parent:IsA("Model") and string.match(d.Parent.Name, "^Placed_")) then
							loose += 1
						end
						local light = d:FindFirstChildOfClass("PointLight")
						if not (light and CollectionService:HasTag(light, "BiomeEffect")) then
							untagged += 1
						end
					end
				end
			end
			r.metrics.draft_lamps = lamps
			local WorldConfig = require(Shared:WaitForChild("WorldConfig"))
			if WorldConfig.Id == 2 then
				flag("lamps_built", lamps > 0, lamps)
			end
			flag("lamps_inside_placed_props", loose == 0, loose, 0)
			flag("lamps_tagged_reduced_effects", untagged == 0, untagged, 0)
		end)
		for _, inst in cleanup do
			inst:Destroy()
		end
		flag("biome_runtime_no_error", ok, ok and 1 or tostring(err))
		return r
	end

	return W
end

return Tests
