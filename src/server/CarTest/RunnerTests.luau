--!nonstrict
-- BRIEF: docs/WORLD_REDESIGN_SPEC.md (owner 2026-10-28), design doc sections 4.1 and 4.10. Written by test-writer
-- BEFORE the runner exists; never loosen a limit to make it pass.
-- `runner` (section 2 + 7): every player's character and every NPC rival is a blocky humanoid rig (Head, Torso,
--   2 arms, 2 legs) with no wheels / VehicleSeat / suspension, anchored and moved by RaceService along the race path:
--   upright (up Y >= 0.999) on every track at normal (HALF_STAT) and max (MAX_STAT) stat speed, on the path
--   (deviation <= PhysicsTargets.race.MaxPathDeviation), at exactly its cruise speed from the first second, every pad
--   paid once. A BillboardGui shows the character's name (finite MaxDistance). Auras and trails attach to the Torso.
-- `scrap` (section 1 + 7): no CarFactory / CarPhysics / CarConfig, no VehicleSeat or wheel parts, no car assets
--   (RacingGarage, RaceStartPavilion, CarModels), no car-only PhysicsTargets, no `Cars` collision group (`Runners`).
-- Test seam (not named by the spec): Shared/RunnerFactory.build(characterId) -> Model (PrimaryPart set), the body
-- RaceService.NewRun drives, as CarFactory.build was.
--
-- SMOOTH-MOTION CONTRACT (owner 2026-10-28, spec section 2; replaces the IVS `rail_never_snaps` check). The server's
-- anchored rig is the exact authoritative pose; clients interpolate the visible runner from what the server publishes.
-- Server (RaceService, every run), checked by `runner_<normal|max>_publishes_*` below:
--   * Attributes on the runner model (the Model passed to RaceService.NewRun; replicates to every client):
--       RunRoute    string  name of a Folder in ReplicatedStorage.RunRoutes that holds the run's route path:
--                           one Vector3Value per waypoint, named "1".."n", Value = route.Path.WorldWaypoints[i]
--                           (exists before RunRoute is set; one folder per route, shared by its runs)
--       RunDistance number  studs along that path (arc length from waypoint 1) of the rig's current pose
--       RunSpeed    number  studs/s the rig moves along the path now (= run.TargetSpeed while running)
--   * Published at least every PUBLISH_INTERVAL s, so RunDistance + RunSpeed x (time since it changed) is the rig's
--     arc position within DISTANCE_TOLERANCE + RunSpeed x FRAME_LAG; RunDistance never decreases during one pass
--     (a restart / loop back to the start is the only backward jump, and the client snaps there).
-- Client (checked by the client harness, src/client/UiTest `ui_runner_smooth` and `ui_speed_dial`):
--   * The visible runner is a Workspace Model with the CollectionService tag "VisibleRunner" and attribute Owner =
--     the owner's UserId (it may be the server rig itself, moved locally each frame, or a client copy). Each frame it
--     is placed at the path point for RunDistance + RunSpeed x (time since RunDistance changed): every frame's step
--     is about RunSpeed x dt, never a zero step followed by a double one (the IVS stutter: 3.7, 0, 3.7, 0 studs).
--   * The camera follows the visible runner while racing (`ui_camera_follows_runner`, ruling 2026-10-28).
-- NPC rivals are outside this contract: their pose is already computed on each client (NpcRacerView ->
-- NpcRacer.PoseAt from the shared profile), never replicated from the server.
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local MIN_UP_Y = 0.999 -- spec section 7: upright, up-vector Y >= 0.999
local SPEED_TOLERANCE = 0.01 -- "exact cruise speed": measured distance / (target x time), whole run
local FIRST_SECOND_TOLERANCE = 0.05 -- "at once": the first second already covers target x 1 s (no ramp)
local MIN_TRACK_SAMPLES = 5 -- frames measured on each track, so an unmeasured track can never pass
local DEVIATION_GRACE = 3 -- s, or DEVIATION_GRACE_STUDS travelled: the IVS rule kept by spec section 2
local DEVIATION_GRACE_STUDS = 30
local WINDOW_SLACK = 36 -- studs of path searched past the reach of one frame
local PUBLISH_INTERVAL = 0.25 -- s: longest gap between RunDistance updates (contract above)
local DISTANCE_TOLERANCE = 2 -- studs between the published arc position and the rig's
local FRAME_LAG = 0.05 -- s: the test may read the attributes up to ~3 frames before / after the rig moved
local BODY_PARTS = { "Head", "Torso" }
local FORBIDDEN_CLASSES = { "VehicleSeat", "Seat", "Constraint", "BodyMover" }

local Tests = {}

local function finite(x)
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- The rig's limbs and body parts: Head, Torso, parts named *Arm*, parts named *Leg*.
local function rigShape(model)
	local shape = { arms = {}, legs = {}, wheels = 0, forbidden = 0, unanchored = 0, parts = 0 }
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			shape.parts += 1
			if not d.Anchored then
				shape.unanchored += 1
			end
			if string.find(string.lower(d.Name), "wheel", 1, true) then
				shape.wheels += 1
			end
			if string.find(d.Name, "Arm", 1, true) then
				table.insert(shape.arms, d.Name)
			elseif string.find(d.Name, "Leg", 1, true) then
				table.insert(shape.legs, d.Name)
			end
		end
		for _, class in FORBIDDEN_CLASSES do
			if d:IsA(class) then
				shape.forbidden += 1
			end
		end
	end
	table.sort(shape.arms)
	table.sort(shape.legs)
	shape.key = table.concat(shape.arms, ",") .. "|" .. table.concat(shape.legs, ",")
	return shape
end

-- Rig checks shared by the player's runner and the NPC rival.
local function checkRig(flag, pre, model)
	local shape = rigShape(model)
	for _, name in BODY_PARTS do
		local part = model:FindFirstChild(name, true)
		flag(pre .. "has_" .. string.lower(name), part ~= nil and part:IsA("BasePart"))
	end
	flag(pre .. "two_arms", #shape.arms == 2, #shape.arms, 2)
	flag(pre .. "two_legs", #shape.legs == 2, #shape.legs, 2)
	flag(pre .. "no_wheels", shape.wheels == 0, shape.wheels, 0)
	-- no VehicleSeat / Seat, no suspension springs or physics movers: the rail moves an anchored rig
	flag(pre .. "no_seat_or_suspension", shape.forbidden == 0, shape.forbidden, 0)
	flag(pre .. "anchored", shape.parts > 0 and shape.unanchored == 0, shape.unanchored, 0)
	flag(pre .. "primary_part", model.PrimaryPart ~= nil)
	return shape
end

-- A BillboardGui with a finite MaxDistance whose text contains `name` (any text when name is nil).
local function nameLabel(model, name)
	for _, gui in model:GetDescendants() do
		if gui:IsA("BillboardGui") and finite(gui.MaxDistance) and gui.MaxDistance > 0 then
			for _, label in gui:GetDescendants() do
				if label:IsA("TextLabel") and (name == nil or string.find(label.Text, name, 1, true)) then
					return true
				end
			end
		end
	end
	return false
end

-- Every effect instance VehicleEffects adds hangs off the Torso (an Attachment on it, a Trail/Beam between two of
-- its Attachments, a ParticleEmitter on it or on one of its Attachments). Returns ok, number of effect objects.
local function effectsOnTorso(model, before)
	local torso = model:FindFirstChild("Torso", true)
	local count, ok = 0, torso ~= nil
	local function onTorso(inst)
		local parent = inst and inst.Parent
		return parent ~= nil and (parent == torso or (parent:IsA("Attachment") and parent.Parent == torso))
	end
	for _, d in model:GetDescendants() do
		if not before[d] then
			if d:IsA("Attachment") then
				count += 1
				ok = ok and d.Parent == torso
			elseif d:IsA("Trail") or d:IsA("Beam") then
				count += 1
				ok = ok and onTorso(d.Attachment0) and onTorso(d.Attachment1)
			elseif d:IsA("ParticleEmitter") then
				count += 1
				ok = ok and onTorso(d)
			end
		end
	end
	return ok and count > 0, count
end

-- Distance from p to the polyline pts over segments lo..hi: distance, segment index, fraction along that segment.
local function nearest(pts, p, lo, hi)
	local bestD, bestI, bestT = math.huge, lo, 0
	for i = math.max(lo, 1), math.min(hi, #pts - 1) do
		local a, b = pts[i], pts[i + 1]
		local ab = b - a
		local len2 = ab:Dot(ab)
		if len2 > 1e-6 then
			local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
			local d = (p - (a + ab * t)).Magnitude
			if d < bestD then
				bestD, bestI, bestT = d, i, t
			end
		end
	end
	return bestD, bestI, bestT
end

-- The rig's feet: the bottom centre of its bounding box (the point that runs on the road).
local function feet(model)
	local cf, size = model:GetBoundingBox()
	return cf.Position - cf.UpVector * (size.Y / 2)
end

function Tests.runner()
	local r, flag = H.report("runner")
	local metrics = r.metrics
	local RunnerFactory = H.module(Shared, "RunnerFactory")
	local RaceService = H.module(Server, "RaceService")
	local Money = H.module(Server, "MoneyService")
	local PlayerData = H.module(Server, "PlayerData")
	local RaceConfig = H.module(Shared, "RaceConfig")
	local NpcRacer = H.module(Shared, "NpcRacer")
	local NpcConfig = H.module(Shared, "NpcConfig")
	local Catalog = H.module(Shared, "CharacterCatalog")
	local Effects = H.module(Shared, "VehicleEffects")
	local MarketConfig = H.module(Shared, "MarketConfig")
	local TrackBuilder = H.module(Shared, "TrackBuilder")
	local Targets = H.module(Shared, "PhysicsTargets")
	local maxDev = Targets and Targets.race and Targets.race.MaxPathDeviation
	local apiOk = RunnerFactory ~= nil
		and type(RunnerFactory.build) == "function"
		and RaceService ~= nil
		and type(RaceService.NewRun) == "function"
		and type(RaceService.GetRoute) == "function"
		and Money ~= nil
		and PlayerData ~= nil
		and RaceConfig ~= nil
		and type(RaceConfig.SpeedFor) == "function"
		and NpcRacer ~= nil
		and type(NpcRacer.BuildModel) == "function"
		and NpcConfig ~= nil
		and Catalog ~= nil
		and type(Catalog.All) == "function"
		and Effects ~= nil
		and type(Effects.ApplyProfile) == "function"
		and MarketConfig ~= nil
		and TrackBuilder ~= nil
		and type(TrackBuilder.CashFor) == "function"
		and type(maxDev) == "number"
	flag("runner_api_exists", apiOk)
	if not apiOk then
		return r
	end

	local character = Catalog.All()[1]
	local charId = character and character.Id
	flag("runner_test_character", type(charId) == "string")
	local okBuild, body = pcall(RunnerFactory.build, charId)
	okBuild = okBuild and typeof(body) == "Instance" and body:IsA("Model")
	flag("runner_builds", okBuild)
	if not okBuild then
		return r
	end

	-- 1. The rig itself: humanoid, nothing car-shaped, anchored, a name label
	local playerShape = checkRig(flag, "runner_", body)
	flag("runner_name_label", nameLabel(body, character.Name))
	metrics.player_rig = playerShape.key

	-- 2. The NPC rival uses the same rig
	local okNpc, npc = pcall(NpcRacer.BuildModel, NpcConfig.For(1))
	okNpc = okNpc and typeof(npc) == "Instance" and npc:IsA("Model")
	flag("npc_builds", okNpc)
	if okNpc then
		local npcShape = checkRig(flag, "npc_", npc)
		flag("npc_same_rig", npcShape.key == playerShape.key and #playerShape.arms == 2)
		flag("npc_name_label", nameLabel(npc, nil))
		metrics.npc_rig = npcShape.key
		npc:Destroy()
	end

	-- 3. Auras and trails attach to the Torso
	for _, kind in { "Aura", "Trail" } do
		local item = MarketConfig.Items and MarketConfig.Items[kind] and MarketConfig.Items[kind][1]
		local id = item and item.Id
		local before = {}
		for _, d in body:GetDescendants() do
			before[d] = true
		end
		local okApply = id ~= nil and pcall(Effects.ApplyProfile, body, kind, id)
		local onTorso, count = effectsOnTorso(body, before)
		flag(string.lower(kind) .. "_attaches_to_torso", okApply and onTorso, count, 1)
	end
	body:Destroy()

	-- 4. Driven by the real RaceService along the live route (every track) at normal and max stat speed
	local route = RaceService.GetRoute()
	local routeOk = type(route) == "table"
		and type(route.Path) == "table"
		and type(route.Path.WorldWaypoints) == "table"
		and #route.Path.WorldWaypoints >= 2
		and type(route.Tracks) == "table"
		and #route.Tracks >= 1
		and type(route.Pads) == "table"
	flag("runner_live_route", routeOk)
	if not routeOk then
		return r
	end
	local wps = route.Path.WorldWaypoints
	local n = #wps
	local arc = { 0 }
	for i = 2, n do
		arc[i] = arc[i - 1] + (wps[i] - wps[i - 1]).Magnitude
	end
	local wantCash = 0
	for _, pad in route.Pads do
		wantCash += TrackBuilder.CashFor(pad.Number)
	end
	-- which track a waypoint index is on
	local function trackAt(i)
		for k, t in route.Tracks do
			if i >= (t.StartIndex or 0) and i < (t.FinishIndex or 0) then
				return k
			end
		end
		return nil
	end

	local function drive(stat)
		local st = { ok = false, minUp = 1, dev = 0, devN = 0, dist = 0, want = 0, perTrack = {} }
		-- smooth-motion contract samples (header): frames read, frames missing an attribute, worst errors
		local pub = { n = 0, missing = 0, distErr = 0, speedErr = 0, age = 0, backward = 0 }
		st.pub = pub
		local model = RunnerFactory.build(charId)
		model.Name = "CarTestRunner"
		model.Parent = Workspace
		local player = Instance.new("Folder")
		player.Name = "CarTestRunnerPlayer"
		player.Parent = Workspace
		local okSetup = pcall(function()
			Money.Setup(player)
			PlayerData.Setup(player)
			player.BaseSpeed.Value = stat
		end)
		local okRun, run = false, nil
		if okSetup then
			okRun, run = pcall(RaceService.NewRun, model, route, player, nil)
		end
		if not okRun or type(run) ~= "table" then
			st.err = tostring(run)
			model:Destroy()
			player:Destroy()
			return st
		end
		st.ok = true
		st.target0 = run.TargetSpeed
		local changedAt = os.clock()
		local distConn = model:GetAttributeChangedSignal("RunDistance"):Connect(function()
			changedAt = os.clock()
		end)
		local lastPub = nil
		local timeout = arc[n] / (0.5 * math.max(RaceConfig.SpeedFor(stat), 1)) + 40
		local torso = model:FindFirstChild("Torso", true)
		local prev = model.PrimaryPart and model.PrimaryPart.Position
		local idx, t, unanchored, firstDist = 1, 0, 0, 0
		while t < timeout and not run.Finished do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			local primary = model.PrimaryPart
			if not primary or run.Finished then
				break
			end
			local pos = primary.Position
			local moved = prev and (pos - prev).Magnitude or 0
			prev = pos
			local target = type(run.TargetSpeed) == "number" and run.TargetSpeed or 0
			st.dist += moved
			st.want += target * dt
			if t <= 1 then
				firstDist += moved
				st.firstWant = (st.firstWant or 0) + target * dt
			end
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and not d.Anchored then
					unanchored += 1
				end
			end
			local up = math.min(primary.CFrame.UpVector.Y, torso and torso.CFrame.UpVector.Y or -1)
			st.minUp = math.min(st.minUp, up)
			-- route index: search ahead only as far as the rig can have run this frame
			local reach = arc[idx] + 2 * math.max(moved, target * dt) + WINDOW_SLACK
			local hi = idx
			while hi < n and arc[hi] <= reach do
				hi += 1
			end
			local d, seg, frac = nearest(wps, feet(model), math.max(idx - 3, 1), hi)
			idx = seg
			local k = trackAt(idx)
			if k then
				local pt = st.perTrack[k] or { n = 0, minUp = 1 }
				pt.n += 1
				pt.minUp = math.min(pt.minUp, up)
				st.perTrack[k] = pt
			end
			if t > DEVIATION_GRACE or st.dist >= DEVIATION_GRACE_STUDS then
				st.dev = math.max(st.dev, d)
				st.devN += 1
				-- the published arc position, extrapolated as a client does, is where the rig is
				local rd, rs, rr =
					model:GetAttribute("RunDistance"), model:GetAttribute("RunSpeed"), model:GetAttribute("RunRoute")
				pub.n += 1
				if finite(rd) and finite(rs) and type(rr) == "string" and rr ~= "" then
					local age = os.clock() - changedAt
					local rigArc = arc[seg] + frac * (arc[seg + 1] - arc[seg])
					pub.distErr = math.max(pub.distErr, math.abs(rd + rs * age - rigArc) - rs * FRAME_LAG)
					pub.speedErr = math.max(pub.speedErr, math.abs(rs - target) / math.max(target, 1))
					pub.age = math.max(pub.age, age)
					if lastPub and rd < lastPub - 1e-3 then
						pub.backward += 1
					end
					lastPub = rd
					pub.route = rr
				else
					pub.missing += 1
				end
			end
		end
		distConn:Disconnect()
		st.finished = run.Finished == true
		st.firstDist = firstDist
		st.unanchored = unanchored
		task.wait(1) -- linger by the last pad: a second payout would show now
		st.payouts = run.Payouts
		local money = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Money")
		st.balance = money and money.Value or -1
		pcall(function()
			run:Destroy()
		end)
		model:Destroy()
		player:Destroy()
		return st
	end

	for _, case in { { "normal", RaceConfig.HALF_STAT }, { "max", RaceConfig.MAX_STAT } } do
		local label, stat = case[1], case[2]
		local st = drive(stat)
		local pre = "runner_" .. label .. "_"
		flag(pre .. "run_started", st.ok)
		if st.ok then
			local want = RaceConfig.SpeedFor(stat)
			flag(
				pre .. "target_is_cruise",
				type(st.target0) == "number" and math.abs(st.target0 - want) <= 0.01,
				st.target0 or -1,
				want
			)
			flag(pre .. "finished", st.finished)
			flag(pre .. "stays_anchored", st.unanchored == 0, st.unanchored, 0)
			flag(pre .. "upright", st.minUp >= MIN_UP_Y, st.minUp, MIN_UP_Y)
			for k, track in route.Tracks do
				local pt = st.perTrack[k] or { n = 0, minUp = -1 }
				flag(
					pre .. "upright_track" .. tostring(track.Number),
					pt.n >= MIN_TRACK_SAMPLES and pt.minUp >= MIN_UP_Y,
					pt.minUp,
					MIN_UP_Y
				)
			end
			flag(pre .. "on_path", st.devN >= MIN_TRACK_SAMPLES and st.dev <= maxDev, st.dev, maxDev)
			local ratio = st.want > 0 and st.dist / st.want or -1
			flag(pre .. "exact_cruise_speed", math.abs(ratio - 1) <= SPEED_TOLERANCE, ratio, 1)
			local first = st.firstWant and st.firstWant > 0 and st.firstDist / st.firstWant or -1
			flag(pre .. "cruise_at_once", math.abs(first - 1) <= FIRST_SECOND_TOLERANCE, first, 1)
			flag(
				pre .. "pad_paid_once",
				st.payouts == #route.Pads and st.balance == wantCash,
				st.payouts or -1,
				#route.Pads
			)
			-- smooth-motion contract (header): what a client needs to interpolate the visible runner
			local pub = st.pub
			flag(pre .. "publishes_attributes", pub.n >= MIN_TRACK_SAMPLES and pub.missing == 0, pub.missing, 0)
			flag(
				pre .. "publishes_distance",
				pub.n >= MIN_TRACK_SAMPLES and pub.missing == 0 and pub.distErr <= DISTANCE_TOLERANCE,
				pub.distErr,
				DISTANCE_TOLERANCE
			)
			flag(
				pre .. "publishes_speed",
				pub.n >= MIN_TRACK_SAMPLES and pub.missing == 0 and pub.speedErr <= SPEED_TOLERANCE,
				pub.speedErr,
				SPEED_TOLERANCE
			)
			flag(
				pre .. "publishes_often",
				pub.n >= MIN_TRACK_SAMPLES and pub.age <= PUBLISH_INTERVAL + FRAME_LAG,
				pub.age,
				PUBLISH_INTERVAL + FRAME_LAG
			)
			flag(pre .. "publishes_distance_forward", pub.n >= MIN_TRACK_SAMPLES and pub.backward == 0, pub.backward, 0)
			-- the route folder holds the run's path, waypoint for waypoint
			local runRoutes = ReplicatedStorage:FindFirstChild("RunRoutes")
			local folder = runRoutes and pub.route and runRoutes:FindFirstChild(pub.route)
			local wrong = folder and 0 or n
			if folder then
				local count = 0
				for _, v in folder:GetChildren() do
					local i = tonumber(v.Name)
					if v:IsA("Vector3Value") and i and wps[i] and (v.Value - wps[i]).Magnitude <= 1e-3 then
						count += 1
					end
				end
				wrong = math.abs(n - count) + math.abs(#folder:GetChildren() - n)
			end
			flag(pre .. "publishes_route", wrong == 0, wrong, 0)
			metrics[label .. "_dev"] = math.round(st.dev * 1000) / 1000
			metrics[label .. "_speed_ratio"] = math.round(ratio * 10000) / 10000
		end
	end
	return r
end

-- Every instance in the place the server can see (the synced src/ modules and the built world).
local function placeDescendants()
	local out = {}
	for _, name in
		{
			"Workspace",
			"ReplicatedStorage",
			"ReplicatedFirst",
			"ServerScriptService",
			"ServerStorage",
			"StarterPlayer",
			"StarterGui",
			"StarterPack",
			"Lighting",
		}
	do
		local ok, service = pcall(game.GetService, game, name)
		if ok and service then
			for _, d in service:GetDescendants() do
				table.insert(out, d)
			end
		end
	end
	return out
end

function Tests.scrap()
	local r, flag = H.report("scrap")
	local named =
		{ CarFactory = 0, CarPhysics = 0, CarConfig = 0, RacingGarage = 0, RaceStartPavilion = 0, CarModels = 0 }
	local seats, wheels = 0, 0
	for _, d in placeDescendants() do
		if named[d.Name] then
			named[d.Name] += 1
		end
		if d:IsA("VehicleSeat") then
			seats += 1
		end
		if d:IsA("BasePart") and string.find(string.lower(d.Name), "wheel", 1, true) then
			wheels += 1
		end
	end
	for _, name in { "CarFactory", "CarPhysics", "CarConfig", "RacingGarage", "RaceStartPavilion", "CarModels" } do
		flag("no_" .. name, named[name] == 0, named[name], 0)
	end
	flag("no_vehicle_seat", seats == 0, seats, 0)
	flag("no_wheel_parts", wheels == 0, wheels, 0)
	-- the car-only parts of PhysicsTargets (the retired car physics scenarios' limits)
	local Targets = H.module(ReplicatedStorage:WaitForChild("Shared"), "PhysicsTargets")
	local carOnly = 0
	for _, key in { "static_settle", "accel", "brake", "skidpad" } do
		if Targets and Targets[key] ~= nil then
			carOnly += 1
		end
	end
	flag("no_car_physics_targets", Targets ~= nil and carOnly == 0, carOnly, 0)
	-- `Cars` becomes `Runners`: players still pass through each other
	local function registered(name)
		local ok, yes = pcall(PhysicsService.IsCollisionGroupRegistered, PhysicsService, name)
		return ok and yes == true
	end
	flag("no_cars_collision_group", not registered("Cars"))
	flag("runners_collision_group", registered("Runners"))
	local okC, collide = pcall(PhysicsService.CollisionGroupsAreCollidable, PhysicsService, "Runners", "Runners")
	flag("runners_pass_through_each_other", registered("Runners") and okC and collide == false)
	return r
end

return Tests
