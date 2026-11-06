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
local Arena = require(Shared.BossArenaConfig)
local BossCfg = require(Shared.BossEventConfig)
local PathDriver = require(Shared.PathDriver)
local RunnerFactory = require(Shared.RunnerFactory)
local BossWaitCamera = require(script.Parent.BossWaitCamera)
local RunnerVisual = require(script.Parent.RunnerVisual)
local RunStyleFx = require(script.Parent.RunStyleFx)

local SERVER_TAG = "RunnerRig" -- Server/CarService.RUNNER_TAG
local CORRECT_RATE = 2 -- 1/s: how fast the drawn distance closes on the published one (no visible jump)
local SNAP_STUDS = 40 -- a larger gap (restart, jump, late join) is snapped at once
local SNAP_SECONDS = 0.5 -- ...as is a gap of more than this many seconds of running
local LANE_SLIDE_SECONDS = 0.35 -- placeholder: the drawn runner's side dash into the next lane on a dodge
local TRACK_CAMERA_RATE = 4 -- 1/s, placeholder: how fast the camera yaw turns to the runner's travel (docs/CAMERA_SPEC.md)
-- The boss event camera turns inward (docs/BOSS_EVENT_SPEC.md "Arena"), angles from the arena draft's GAME_YAW, GAME_PITCH.
local ARENA_YAW, ARENA_PITCH = math.rad(55), math.rad(12)

local player = Players.LocalPlayer
local views = {} -- server rig -> view state

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

-- A team with no one left in the line: the held body is gone too, until the refill (BOSS_EVENT_SPEC "Line run").
local function teamGone(rig)
	local id = rig:GetAttribute("Owner")
	local owner = type(id) == "number" and Players:GetPlayerByUserId(id)
	return owner and owner:GetAttribute("BossEvent") == true and owner:GetAttribute("BossLine") == "" or false
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
	-- the rig's PrimaryPart can replicate nil after a re-skin (first tag-in), which would drop the camera to the hidden avatar
	copy.PrimaryPart = copy:FindFirstChild("Torso") or copy.PrimaryPart
	CollectionService:AddTag(copy, RunnerVisual.TAG)
	RunStyleFx.Attach(copy)
	copy.Parent = Workspace
	view.Copy = copy
	if view.Gone then
		for _, d in copy:GetDescendants() do
			hide(d)
		end
	end
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
	local gone = teamGone(rig)
	if gone ~= (view.Gone == true) then
		view.Gone = gone
		rebuild(view) -- hides it, or brings it back with its effects as they were
		copy = view.Copy
	end
	local dt = math.max(0, now - (view.At or now))
	view.At = now
	local rd, rs = rig:GetAttribute("RunDistance"), rig:GetAttribute("RunSpeed")
	local route = RunnerVisual.RouteOf(rig:GetAttribute("RunRoute"))
	if not (route and type(rd) == "number" and type(rs) == "number") then
		-- not running (a held duel start): show it where the server holds it
		view.Dist = nil
		view.Moving = false
		RunStyleFx.SetMoving(copy, false)
		-- Client/BossPrepRun's display-only run: nothing here moves the rig
		local held = copy:GetAttribute("HeldPose")
		RunnerVisual.Pose(
			copy,
			held or rig:GetPivot(),
			held and copy:GetAttribute("HeldPhase") or 0,
			held and copy:GetAttribute("HeldAmount") or 0
		)
		return
	end
	if view.Route and view.Route ~= route and view.Route.Closed and route.Closed and view.Dist then -- a dodge (design doc 4.37): same lap angle, sliding over from the old lane
		local scaled = view.Dist * route.Arc[#route.Arc] / view.Route.Arc[#view.Route.Arc]
		local old = PathDriver.PoseAt(view.Route.Wps, view.Route.Arc, view.Dist, nil, view.Route.Closed)
		local new = PathDriver.PoseAt(route.Wps, route.Arc, scaled, nil, route.Closed)
		view.Dist, view.Hint = scaled, nil
		view.Slide, view.SlideLeft = old.Position - new.Position, LANE_SLIDE_SECONDS
		view.SlideSide = new.RightVector:Dot(new.Position - old.Position) >= 0 and 1 or -1
	end
	view.Route = route
	local arcEnd = route.Closed and math.huge or route.Arc[#route.Arc] -- a lap route's distance keeps growing; PoseAt wraps it
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
	view.Moving = rs > 0
	RunStyleFx.SetMoving(copy, view.Moving)
	local feet, k = PathDriver.PoseAt(route.Wps, route.Arc, dist, view.Hint, route.Closed)
	view.Hint = k
	local dashAt = nil
	if view.Slide then
		view.SlideLeft -= dt
		if view.SlideLeft > 0 then
			feet += view.Slide * (view.SlideLeft / LANE_SLIDE_SECONDS) ^ 2
			dashAt = 1 - view.SlideLeft / LANE_SLIDE_SECONDS
		else
			view.Slide = nil
		end
	end
	view.Phase = RunnerVisual.Advance(view.Phase, rs, dt)
	local root = feet * CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0)
	RunnerVisual.Pose(copy, root, view.Phase, rs > 0 and 1 or 0)
	if dashAt then
		RunnerVisual.PoseDash(copy, root, dashAt, view.SlideSide)
	end
end

local function stepAll()
	local now = os.clock()
	for _, view in views do
		step(view, now)
	end
end

-- Track camera (docs/CAMERA_SPEC.md): turns the camera yaw toward the runner's travel, keeping the player's pitch and
-- zoom. Runs before the default camera, which builds its next frame from this look direction.
local savedPitch = nil -- the player's pitch from before the boss event; the event sets it once and the player keeps control

local function setAngles(camera, pitch, yaw)
	local focus = camera.Focus.Position
	local distance = (camera.CFrame.Position - focus).Magnitude
	camera.CFrame = CFrame.new(focus) * CFrame.fromOrientation(pitch, yaw, 0) * CFrame.new(0, 0, distance)
end

-- The rise (docs/BOSS_EVENT_SPEC.md "Arena"): through the intro the camera looks at the arena centre, so the boss is seen
-- coming up from under the track. It orbits the focus, which keeps the player's character on screen.
local function riseCameraOn(camera)
	if
		player:GetAttribute("BossEvent") ~= true
		or ReplicatedStorage:GetAttribute("BossEventPhase") ~= "Fight"
		or player:GetAttribute("TrackCamera") == false
		or player:GetAttribute("TopDownView") == true
		or camera.CameraType ~= Enum.CameraType.Custom
	then
		return false
	end
	local start = ReplicatedStorage:GetAttribute("BossEventStart")
	return start ~= nil and Workspace:GetServerTimeNow() - start < BossCfg.PrepSeconds + BossCfg.IntroSeconds
end

local function faceArena(camera, dt)
	local inward = (Arena.Center - camera.Focus.Position) * Vector3.new(1, 0, 1)
	if inward.Magnitude < 1e-3 then
		return
	end
	local look = camera.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local turn = (math.atan2(-inward.X, -inward.Z) - yaw + math.pi) % (2 * math.pi) - math.pi
	local ease = 1 - math.exp(-TRACK_CAMERA_RATE * dt)
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	savedPitch = savedPitch or pitch
	setAngles(camera, pitch + (ARENA_PITCH - pitch) * ease, yaw + turn * ease)
end

local function alignYaw(camera, torso, dt)
	local dir = torso.CFrame.LookVector
	local inEvent = player:GetAttribute("BossEvent") == true
	if inEvent then
		local inward = ((Arena.Center - torso.Position) * Vector3.new(1, 0, 1)).Unit
		dir = dir * math.cos(ARENA_YAW) + inward * math.sin(ARENA_YAW)
	end
	if Vector2.new(dir.X, dir.Z).Magnitude < 1e-3 then
		return
	end
	local look = camera.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local turn = (math.atan2(-dir.X, -dir.Z) - yaw + math.pi) % (2 * math.pi) - math.pi
	yaw += turn * (1 - math.exp(-TRACK_CAMERA_RATE * dt))
	local pitch = math.asin(math.clamp(look.Y, -1, 1))
	if inEvent and not savedPitch then
		savedPitch, pitch = pitch, ARENA_PITCH
	end
	setAngles(camera, pitch, yaw)
end

local function trackCameraOn(camera, mine)
	if player:GetAttribute("TrackCamera") == false or player:GetAttribute("TopDownView") == true then
		return false -- default ON (attribute unset); top-down view takes the camera when both are on
	end
	if camera.CameraType ~= Enum.CameraType.Custom then
		return false
	end
	for _, view in views do
		if view.Copy == mine then
			return view.Moving == true
		end
	end
	return false
end

local cameraOnRunner = false
local followed = nil -- { Part, Position }: where the camera last framed the local runner
local fovBefore = nil -- the camera's own FOV while the event's wider one is on
local zoomBefore = nil
RunService:BindToRenderStep("RunnerView", Enum.RenderPriority.Camera.Value - 1, function(dt)
	stepAll()
	-- the camera follows the local player's visible runner while racing, and goes back to the avatar after
	local camera = Workspace.CurrentCamera
	if camera then
		BossWaitCamera.Step(camera, dt)
	end
	local waitView = BossWaitCamera.Held() -- it owns the camera and its FOV until it has given them back
	if camera and savedPitch and player:GetAttribute("BossEvent") ~= true then
		local look = camera.CFrame.LookVector
		setAngles(camera, savedPitch, math.atan2(-look.X, -look.Z))
		savedPitch = nil
	end
	-- The event's locked view (BOSS_EVENT_SPEC "Run rules"). A saved top-down setting does not apply in an event. Outside one,
	-- top-down runs after this step and restores the normal FOV itself.
	local wide = camera and player:GetAttribute("BossEvent") == true and camera.CameraType == Enum.CameraType.Custom
	if waitView then
		wide = fovBefore ~= nil
	end
	if wide and not fovBefore then
		fovBefore, zoomBefore = camera.FieldOfView, player.CameraMinZoomDistance
		camera.FieldOfView = BossCfg.CameraFov
		player.CameraMinZoomDistance = BossCfg.CameraZoom
	elseif camera and not wide and fovBefore then
		camera.FieldOfView = fovBefore
		player.CameraMinZoomDistance = zoomBefore
		fovBefore = nil
	end
	local rising = camera and riseCameraOn(camera)
	local mine = player:GetAttribute("AutoRacing") == true and RunnerVisual.LocalRunner()
	local torso = mine and mine.PrimaryPart
	followed = nil
	if camera and torso then
		if camera.CameraSubject ~= torso then
			camera.CameraSubject = torso
		end
		cameraOnRunner = true
		if not rising and trackCameraOn(camera, mine) then
			alignYaw(camera, torso, dt)
		end
		followed = not waitView and { Part = torso, Position = torso.Position } or nil
	elseif camera and cameraOnRunner then
		cameraOnRunner = false
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	if rising then
		faceArena(camera, dt)
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

-- Tunnel camera clamp (docs/BIOME_ENVIRONMENT_SPEC.md 3.5), after the default camera: while a tunnel part is straight
-- above the camera focus, the camera pops in front of any tunnel wall or ceiling between it and the focus and stays
-- CAMERA_GAP under that ceiling. Moves the camera along its own view line only, so the yaw (track camera or the
-- regular one) and the player's zoom setting are left alone.
local TUNNEL_TAG = "Tunnel" -- Shared/Tunnel.TAG
local CEILING_PROBE = 80 -- studs, placeholder: highest tunnel ceiling looked for above the focus
local CAMERA_GAP = 1 -- studs, placeholder
local tunnelRay = RaycastParams.new()
tunnelRay.FilterType = Enum.RaycastFilterType.Include
local tunnelCount = 0
RunService:BindToRenderStep("TunnelCamera", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = Workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local tunnels = CollectionService:GetTagged(TUNNEL_TAG)
	if #tunnels == 0 then
		return
	end
	if #tunnels ~= tunnelCount then
		tunnelCount = #tunnels
		tunnelRay.FilterDescendantsInstances = tunnels
	end
	local focus = camera.Focus.Position
	local up = Workspace:Raycast(focus, Vector3.new(0, CEILING_PROBE, 0), tunnelRay)
	if not up then
		return -- not under a tunnel
	end
	local eye = camera.CFrame.Position
	local back = eye - focus
	if back.Magnitude < 1e-3 then
		return
	end
	local hit = Workspace:Raycast(focus, back, tunnelRay)
	if hit then
		eye = hit.Position - back.Unit * CAMERA_GAP
	end
	local limit = up.Position.Y - CAMERA_GAP
	if eye.Y > limit and limit > focus.Y then
		eye = focus + (eye - focus) * ((limit - focus.Y) / (eye.Y - focus.Y))
	end
	if (eye - camera.CFrame.Position).Magnitude > 1e-3 then
		camera.CFrame = camera.CFrame.Rotation + eye
	end
end)
