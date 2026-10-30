--!nonstrict
-- Smooth runners (docs/WORLD_REDESIGN_SPEC.md section 2, owner 2026-10-28; contract in Server/CarTest/RunnerTests).
-- The server's anchored rig (tag RunnerRig) is the authoritative pose but replicates in steps, so this client hides it
-- locally and draws a copy (tag VisibleRunner, same Owner) placed every frame on the run's path at
-- RunDistance + RunSpeed x (time since RunDistance changed), with a procedural run animation. The camera follows the
-- local player's visible runner while racing.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PathDriver = require(Shared.PathDriver)
local RunnerFactory = require(Shared.RunnerFactory)
local RunnerVisual = require(script.Parent.RunnerVisual)

local SERVER_TAG = "RunnerRig" -- Server/CarService.RUNNER_TAG
local CORRECT_RATE = 2 -- 1/s: how fast the drawn distance closes on the published one (no visible jump)
local SNAP_STUDS = 40 -- a larger gap (restart, jump, late join) is snapped at once
local SNAP_SECONDS = 0.5 -- ...as is a gap of more than this many seconds of running

local player = Players.LocalPlayer
local views = {} -- server rig -> view state
local routes = {} -- RunRoutes folder name -> { Wps, Arc }

local EFFECTS = { "ParticleEmitter", "Trail", "Beam", "BillboardGui" }
local function isEffect(d)
	for _, class in EFFECTS do
		if d:IsA(class) then
			return true
		end
	end
	return false
end

-- Hides one instance of the server rig on this client only.
local function hide(d)
	if d:IsA("BasePart") or d:IsA("Decal") then
		d.LocalTransparencyModifier = 1
	elseif isEffect(d) then
		d.Enabled = false
	end
end

-- The route's waypoints once every one has replicated, else nil.
local function routeOf(name)
	if type(name) ~= "string" then
		return nil
	end
	local cached = routes[name]
	if cached then
		return cached
	end
	local root = ReplicatedStorage:FindFirstChild("RunRoutes")
	local folder = root and root:FindFirstChild(name)
	local count = folder and folder:GetAttribute("Count")
	if not (folder and type(count) == "number" and #folder:GetChildren() >= count and count >= 2) then
		return nil
	end
	local wps = table.create(count)
	for i = 1, count do
		local v = folder:FindFirstChild(tostring(i))
		if not v then
			return nil
		end
		wps[i] = v.Value
	end
	cached = { Wps = wps, Arc = PathDriver.Arc(wps) }
	routes[name] = cached
	return cached
end

-- (Re)builds the drawn copy from the server rig (its look, aura and trail), keeping the run state.
local function rebuild(view)
	view.Dirty = false
	if view.Copy then
		view.Copy:Destroy()
	end
	local rig = view.Rig
	local wasArchivable = rig.Archivable
	rig.Archivable = true
	local copy = rig:Clone()
	rig.Archivable = wasArchivable
	if not copy then
		return
	end
	CollectionService:RemoveTag(copy, SERVER_TAG)
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		elseif isEffect(d) then
			d.Enabled = true -- VehicleEffects never adds a disabled effect; hide() turned them off on the rig
		end
	end
	copy.Name = rig.Name .. "_Visible"
	CollectionService:AddTag(copy, RunnerVisual.TAG)
	copy.Parent = Workspace
	view.Copy = copy
end

local function add(rig)
	if views[rig] or not rig:IsA("Model") then
		return
	end
	local view = { Rig = rig, Dist = nil, Phase = 0, Connections = {} }
	views[rig] = view
	for _, d in rig:GetDescendants() do
		hide(d)
	end
	table.insert(
		view.Connections,
		rig.DescendantAdded:Connect(function(d)
			hide(d)
			view.Dirty = true
		end)
	)
	table.insert(
		view.Connections,
		rig.DescendantRemoving:Connect(function()
			view.Dirty = true
		end)
	)
	-- a re-skin (ApplyCharacter) recolours the rig in place
	table.insert(
		view.Connections,
		rig:GetAttributeChangedSignal("CharacterId"):Connect(function()
			view.Dirty = true
		end)
	)
	view.ChangedAt = os.clock()
	table.insert(
		view.Connections,
		rig:GetAttributeChangedSignal("RunDistance"):Connect(function()
			view.ChangedAt = os.clock()
		end)
	)
	rebuild(view)
end

local function remove(rig)
	local view = views[rig]
	if not view then
		return
	end
	views[rig] = nil
	for _, c in view.Connections do
		c:Disconnect()
	end
	if view.Copy then
		view.Copy:Destroy()
	end
end

CollectionService:GetInstanceAddedSignal(SERVER_TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(SERVER_TAG):Connect(remove)
for _, rig in CollectionService:GetTagged(SERVER_TAG) do
	task.spawn(add, rig)
end

-- Puts the drawn copy where the run is at time `now` (os.clock). Called from the render step (before the camera) and
-- again before the physics step, so every frame moves it even when this client renders less often than it steps.
local function step(view, now)
	local rig, copy = view.Rig, view.Copy
	if not rig.Parent then
		remove(rig)
		return
	end
	if view.Dirty or not (copy and copy.Parent) then
		rebuild(view)
		copy = view.Copy
	end
	local dt = math.max(0, now - (view.At or now))
	view.At = now
	local rd, rs = rig:GetAttribute("RunDistance"), rig:GetAttribute("RunSpeed")
	local route = routeOf(rig:GetAttribute("RunRoute"))
	if not (route and type(rd) == "number" and type(rs) == "number") then
		-- not running (a held duel start): show it where the server holds it
		view.Dist = nil
		RunnerVisual.Pose(copy, rig:GetPivot(), 0, 0)
		return
	end
	local arcEnd = route.Arc[#route.Arc]
	local target = math.min(rd + rs * (now - view.ChangedAt), arcEnd)
	local dist = view.Dist
	if not dist or math.abs(target - dist) > math.max(SNAP_STUDS, rs * SNAP_SECONDS) then
		dist = target
	else
		dist += rs * dt
		dist += (target - dist) * math.min(1, CORRECT_RATE * dt)
	end
	dist = math.clamp(dist, 0, arcEnd)
	view.Dist = dist
	local feet, k = PathDriver.PoseAt(route.Wps, route.Arc, dist, view.Hint)
	view.Hint = k
	view.Phase = RunnerVisual.Advance(view.Phase, rs, dt)
	RunnerVisual.Pose(copy, feet * CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0), view.Phase, rs > 0 and 1 or 0)
end

local function stepAll()
	local now = os.clock()
	for _, view in views do
		step(view, now)
	end
end

local cameraOnRunner = false
local followed = nil -- { Part, Position }: where the camera last framed the local runner
RunService:BindToRenderStep("RunnerView", Enum.RenderPriority.Camera.Value - 1, function()
	stepAll()
	-- the camera follows the local player's visible runner while racing, and goes back to the avatar after
	local camera = Workspace.CurrentCamera
	local mine = player:GetAttribute("AutoRacing") == true and RunnerVisual.LocalRunner()
	local torso = mine and mine.PrimaryPart
	followed = nil
	if camera and torso then
		if camera.CameraSubject ~= torso then
			camera.CameraSubject = torso
		end
		cameraOnRunner = true
		followed = { Part = torso, Position = torso.Position }
	elseif camera and cameraOnRunner then
		cameraOnRunner = false
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end)

-- Between render steps the runner keeps moving; the camera is carried along by the same amount
RunService.PreSimulation:Connect(function()
	stepAll()
	local camera = Workspace.CurrentCamera
	if followed and camera and camera.CameraSubject == followed.Part and followed.Part.Parent then
		local delta = followed.Part.Position - followed.Position
		followed.Position = followed.Part.Position
		camera.CFrame += delta
		camera.Focus += delta
	end
end)
