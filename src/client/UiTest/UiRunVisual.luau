--!nonstrict
-- ui_run_visual (core c3, owner 2026-11-04): what this client really draws per frame during a live animated run with an
-- aura and a trail on. Design doc 4.13 (per-slot aura and trail), 4.23 (NinjaRun), section 5 (blocky R15, 6 meshes).
-- Limits and their sources: UiSpec.RunVisual.
--
-- It never changes saved state: UiTestSetup's run_visual fixture builds a rig for no Player (a Folder holds the slot
-- attributes, Owner = 0) with the real RunnerFactory and VehicleEffects.Apply, and publishes RunRoute / RunSpeed /
-- RunDistance on a straight route of its own. The real Client/RunnerView draws it, so every number here comes from the
-- real drawn copy. Team, owned items and Money are not read or written.
--
-- Clipping cannot be judged by code: UiRunVisual.Capture holds a chosen run for screenshots (protocol at Capture).
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Spec = require(script.Parent:WaitForChild("UiSpec"))
local Client = script.Parent.Parent
local RunnerVisual = require(Client:WaitForChild("RunnerVisual"))
local UiMotion = require(Client:WaitForChild("UiMotion"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
local CharacterModelAssets = require(Shared:WaitForChild("CharacterModelAssets"))
local MarketConfig = require(Shared:WaitForChild("MarketConfig"))
local PhysicsTargets = require(Shared:WaitForChild("PhysicsTargets"))
local RaceConfig = require(Shared:WaitForChild("RaceConfig"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))

local cfg = Spec.RunVisual
local smooth = Spec.RunnerSmooth
local player = Players.LocalPlayer

local UiRunVisual = {}
UiRunVisual.CAPTURE_ATTR = "UiRunVisualCapture"
UiRunVisual.CAPTURE_READY_ATTR = "UiRunVisualCaptureReady"

local LIMBS = { "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local SWUNG = { "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local RUN_FX = "RunStyleFx" -- Client/RunStyleFx FX_NAME
local TWO_PI = 2 * math.pi

-- Every named check, so each one shows in the result even when nothing fails.
local CHECKS = {
	-- frame glitches
	"rows_drawn",
	"frames_measured",
	"copy_not_rebuilt_mid_run",
	"pos_no_pop",
	"pos_no_backward_jump",
	"cframes_finite",
	"joint_no_angle_jump",
	"joint_no_position_jump",
	"no_rest_pose_frames",
	"no_lost_animation_frames",
	"pose_phase_advances",
	"pose_full_swing",
	-- mesh bugs
	"meshes_exactly_six",
	"mesh_loaded",
	"texture_loaded",
	"copy_matches_rig",
	"rig_hidden",
	"rig_scale_matches",
	"parts_visible",
	"limbs_near_root",
	"feet_rest_on_ground",
	"feet_on_ground",
	"runner_upright",
	"style_pose_matches",
	-- aura and trail
	"effects_match_row",
	"emitters_on",
	"emitters_not_at_origin",
	"attachments_on_part",
	"attachments_near_part",
	"trails_on",
	"ninja_fx_on",
	-- slot swap (design doc 4.13: each slot's own aura and trail)
	"swap_no_pop",
	"swap_settled",
}

local function invoke(request)
	local rf = ReplicatedStorage:FindFirstChild("UiTestSetupRequest")
	if not (rf and rf:IsA("RemoteFunction")) then
		return false, "no ReplicatedStorage.UiTestSetupRequest"
	end
	local okCall, ok, err = pcall(rf.InvokeServer, rf, request)
	if not (okCall and ok) then
		return false, tostring(okCall and err or ok)
	end
	return true
end

local function findCopy(rigName)
	local want = rigName .. "_Visible"
	for _, m in CollectionService:GetTagged(smooth.Tag) do
		if m.Name == want and m:IsA("Model") and m:IsDescendantOf(Workspace) then
			return m
		end
	end
	return nil
end

-- The fixture's route: where the rail is, which way the run goes. Nil until it replicated.
local function waitRoute()
	local deadline = os.clock() + smooth.Wait
	repeat
		local root = ReplicatedStorage:FindFirstChild("RunRoutes")
		local folder = root and root:FindFirstChild(cfg.Route)
		local a, b = folder and folder:FindFirstChild("1"), folder and folder:FindFirstChild("2")
		if a and b then
			return { Forward = (b.Value - a.Value).Unit, Ground = a.Value.Y }
		end
		task.wait(0.1)
	until os.clock() > deadline
	return nil
end

local function finite(v)
	local sum = v.X + v.Y + v.Z -- a NaN or an inf anywhere makes the sum NaN or inf
	return sum == sum and math.abs(sum) ~= math.huge
end

local function cframeFinite(cf)
	return finite(cf.Position) and finite(cf.XVector) and finite(cf.YVector) and finite(cf.ZVector)
end

-- Lowest world height of a part's box.
local function lowY(part)
	local cf, half = part.CFrame, part.Size / 2
	local reach = math.abs(cf.XVector.Y) * half.X + math.abs(cf.YVector.Y) * half.Y + math.abs(cf.ZVector.Y) * half.Z
	return cf.Position.Y - reach
end

local function feetLow(model)
	return math.min(lowY(model.LeftLeg), lowY(model.RightLeg))
end

-- A limb's swing angle about the Torso's x axis (radians, not wrapped at +-90 as ToOrientation is).
local function pitchOf(torsoCf, limbCf)
	local look = torsoCf:ToObjectSpace(limbCf).LookVector
	return math.atan2(look.Y, -look.Z)
end

local function angleBetween(a, b)
	local _, angle = a:ToObjectSpace(b):ToAxisAngle()
	return math.abs(angle)
end

-- What the pose itself says for this rig, measured on an unparented clone with the real RunnerVisual.Pose so the
-- placeholder angles (SWING, BOB, NINJA) are never copied here:
--   Lean: the Torso in the root's space (identity in the default swing, the 45 degree lean in NinjaRun)
--   Rate / PosRate: a limb's largest change against the Torso per radian of stride phase
--   FootLow / FootHigh: lowest leg point above the ground over a stride; RestLow: the same standing still
--   PitchRange, PitchMid: the swing of RightLeg against the Torso
local poses = setmetatable({}, { __mode = "k" })
local function poseOf(copy)
	local pose = poses[copy]
	if pose then
		return pose
	end
	local probe = copy:Clone()
	local torso = probe.Torso
	local hip = RunnerFactory.HIP_HEIGHT
	pose = { Rate = {}, PosRate = {}, FootLow = math.huge, FootHigh = -math.huge }
	RunnerVisual.Pose(probe, CFrame.identity, 0, 0)
	pose.RestLow = feetLow(probe) + hip
	RunnerVisual.Pose(probe, CFrame.identity, 0, 1)
	pose.Lean = torso.CFrame
	local step = TWO_PI / cfg.ProbeSteps
	local minPitch, maxPitch, prev = math.huge, -math.huge, nil
	for i = 0, cfg.ProbeSteps do
		RunnerVisual.Pose(probe, CFrame.identity, step * i, 1)
		local low = feetLow(probe) + hip
		pose.FootLow, pose.FootHigh = math.min(pose.FootLow, low), math.max(pose.FootHigh, low)
		local pitch = pitchOf(torso.CFrame, probe.RightLeg.CFrame)
		minPitch, maxPitch = math.min(minPitch, pitch), math.max(maxPitch, pitch)
		local now = {}
		for _, name in LIMBS do
			now[name] = torso.CFrame:ToObjectSpace(probe[name].CFrame)
			if prev then
				local angle = angleBetween(prev[name], now[name]) / step
				local moved = (prev[name].Position - now[name].Position).Magnitude / step
				pose.Rate[name] = math.max(pose.Rate[name] or 0, angle)
				pose.PosRate[name] = math.max(pose.PosRate[name] or 0, moved)
			end
		end
		prev = now
	end
	pose.PitchRange, pose.PitchMid = maxPitch - minPitch, (maxPitch + minPitch) / 2
	probe:Destroy()
	poses[copy] = pose
	return pose
end

-- Torso and every limb are there (a copy cloned while the rig's parts are still replicating may not have them yet).
local function complete(copy)
	if not (copy and copy:FindFirstChild("Torso")) then
		return false
	end
	for _, name in LIMBS do
		if not copy:FindFirstChild(name) then
			return false
		end
	end
	return true
end

local function hasEffect(model, id)
	for _, d in model:GetDescendants() do
		if (d:IsA("Trail") or d:IsA("ParticleEmitter")) and string.sub(d.Name, 1, #id) == id then
			return true
		end
	end
	return false
end

-- The drawn copy of `rigName` once it shows this character and items and has not been rebuilt for SettleSeconds (the
-- rig's parts replicate over a few frames, and each one rebuilds the copy). onFrame(copy) sees every frame waited.
local function settle(rigName, id, aura, trail, onFrame)
	local deadline = os.clock() + smooth.Wait
	local held, since = nil, 0
	repeat
		RunService.Heartbeat:Wait()
		local copy = findCopy(rigName)
		if onFrame then
			onFrame(copy)
		end
		local folder = copy and copy:FindFirstChild("MarketEffects")
		local ready = folder
			and copy:GetAttribute("CharacterId") == id
			and folder:GetAttribute("Aura") == aura
			and folder:GetAttribute("Trail") == trail
			and complete(copy)
		if not ready then
			held = nil
		elseif held ~= copy then
			held, since = copy, os.clock()
		elseif os.clock() - since >= cfg.SettleSeconds then
			return copy
		end
	until os.clock() > deadline
	return nil
end

-- Loads a model's meshes and textures before its run starts, so a slow fetch never eats the run's route.
local function preload(modelId)
	local root = ReplicatedStorage:FindFirstChild("CharacterModels")
	local folder = root and root:FindFirstChild(modelId)
	if not folder then
		return
	end
	local done = false
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, folder:GetChildren())
		done = true
	end)
	local deadline = os.clock() + cfg.PreloadSeconds
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
end

local function fetched(content)
	local ok, status = pcall(ContentProvider.GetAssetFetchStatus, ContentProvider, content)
	return ok and status == Enum.AssetFetchStatus.Success, ok and status.Name or tostring(status)
end

local function modelIdOf(id)
	local spec = CharacterCatalog.Get(id)
	return spec and spec.Model or id
end

-- PreloadAsync returns before a MeshPart's fetch starts (status None, then Loading once the drawn copy needs it), so the
-- row waits on the copy itself, up to PreloadSeconds: a fetch that has not ended by then is still mesh_loaded's red.
local function waitFetched(copy)
	local deadline = os.clock() + cfg.PreloadSeconds
	while os.clock() < deadline do
		local fetching = false
		for _, part in copy:GetChildren() do
			if part:IsA("MeshPart") then
				for _, content in { part.MeshId, part.TextureID } do
					local ok, status = pcall(ContentProvider.GetAssetFetchStatus, ContentProvider, content)
					local ended = ok
						and (status == Enum.AssetFetchStatus.Success or status == Enum.AssetFetchStatus.Failure)
					fetching = fetching or not ended
				end
			end
		end
		if not fetching then
			return
		end
		task.wait(0.05)
	end
end

-- Checks that hold for the whole run, once per row. out[check] collects "<label>: <what>".
local function checkRow(out, label, row, copy, rig)
	local function add(name, what)
		table.insert(out[name], label .. ": " .. what)
	end
	waitFetched(copy)
	-- Meshes
	local count = 0
	for _, d in copy:GetChildren() do
		if d:IsA("MeshPart") then
			count += 1
		end
	end
	local missing = {}
	for _, name in cfg.Meshes do
		if not (copy:FindFirstChild(name) and copy[name]:IsA("MeshPart")) then
			table.insert(missing, name)
		end
	end
	if count ~= #cfg.Meshes or #missing > 0 then
		add("meshes_exactly_six", ("%d meshes, missing %s"):format(count, table.concat(missing, ",")))
	end
	local trim = copy:FindFirstChild("Trim")
	if trim and trim.Transparency < 1 then
		add("meshes_exactly_six", "placeholder Trim shows")
	end
	local sizes = CharacterModelAssets[modelIdOf(row.Id)]
	sizes = sizes and sizes.Sizes
	if math.abs(copy:GetScale() - 1) > cfg.ScaleTolerance then
		add("rig_scale_matches", "model scale " .. copy:GetScale())
	end
	for _, name in cfg.Meshes do
		local part = copy:FindFirstChild(name)
		if part and part:IsA("MeshPart") then
			local okMesh, meshStatus = fetched(part.MeshId)
			if part.MeshId == "" or not okMesh or part.MeshSize.Magnitude <= 0 then
				add(
					"mesh_loaded",
					("%s id %q %s size %s"):format(name, part.MeshId, meshStatus, tostring(part.MeshSize))
				)
			end
			local okTexture, textureStatus = fetched(part.TextureID)
			if part.TextureID == "" or not okTexture then
				add("texture_loaded", ("%s id %q %s"):format(name, part.TextureID, textureStatus))
			end
			local want = sizes and sizes[name] and sizes[name] * RunnerFactory.SCALE
			if want and (part.Size - want).Magnitude > cfg.ScaleTolerance then
				add("rig_scale_matches", ("%s %s, want %s"):format(name, tostring(part.Size), tostring(want)))
			end
			local source = rig and rig:FindFirstChild(name)
			if not source then
				add("copy_matches_rig", name .. " not on the rig")
			elseif
				not source:IsA("MeshPart")
				or source.MeshId ~= part.MeshId
				or source.TextureID ~= part.TextureID
				or (source.Size - part.Size).Magnitude > cfg.ScaleTolerance
			then
				add("copy_matches_rig", name .. " differs from the rig")
			end
			if source and source.LocalTransparencyModifier < 1 then
				add("rig_hidden", name .. " of the server rig draws too")
			end
		end
	end
	-- The pose
	local pose = poseOf(copy)
	if math.abs(pose.RestLow) > cfg.FootRestTolerance then
		add("feet_rest_on_ground", ("%.3f studs above the ground standing"):format(pose.RestLow))
	end
	local leans = pose.Lean.UpVector.Y < PhysicsTargets.lap.MinUpYStrict
	if leans ~= (row.Style == "NinjaRun") then
		add("style_pose_matches", ("style %s, torso up y %.3f"):format(tostring(row.Style), pose.Lean.UpVector.Y))
	end
	-- Effects
	local folder = copy:FindFirstChild("MarketEffects")
	if not folder or folder:GetAttribute("Aura") ~= row.Aura or folder:GetAttribute("Trail") ~= row.Trail then
		add("effects_match_row", "MarketEffects does not name " .. row.Aura .. " + " .. row.Trail)
	end
	for _, id in { row.Aura, row.Trail } do
		if not hasEffect(copy, id) then
			add("effects_match_row", id .. " draws nothing")
		end
	end
	local runFx = 0
	for _, d in copy:GetDescendants() do
		if d.Name == RUN_FX and d:IsA("ParticleEmitter") then
			runFx += 1
		end
	end
	local state = copy:GetAttribute("RunFxState")
	if row.Style == "NinjaRun" and (runFx == 0 or (state ~= "all" and state ~= "streaks")) then
		add("ninja_fx_on", ("%d emitters, state %s"):format(runFx, tostring(state)))
	elseif row.Style ~= "NinjaRun" and runFx > 0 then
		add("ninja_fx_on", ("%d emitters without the style"):format(runFx))
	end
end

-- Watches the drawn copy for `seconds` of its live run: one sample per frame, on Heartbeat (as ui_runner_smooth: after
-- this frame's steps placed it). Everything failing is added to out[check] as "<label>: <n> frames, worst <value>".
local function watch(out, label, ctx, copy, seconds, minFrames)
	local bad = {}
	local function note(name, value)
		local entry = bad[name]
		if entry then
			entry.Frames += 1
			entry.Worst = math.max(entry.Worst, value)
		else
			bad[name] = { Frames = 1, Worst = value }
		end
	end
	local pose = poseOf(copy)
	local torso = copy:FindFirstChild("Torso")
	local parts, attachments, emitters, trails = {}, {}, {}, {}
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("Attachment") then
			-- the most this attachment may ever be from its part: its rest offset + its motion's own radius or box.
			-- Effect radii unscaled by RunnerFactory.SCALE is a known cosmetic note, not a failure: they are taken as they are.
			local base = d:GetAttribute("FxBase")
			local box = d:GetAttribute("FxBox")
			local reach = (typeof(base) == "CFrame" and base.Position or d.Position).Magnitude
				+ (d:GetAttribute("FxRadius") or 0)
				+ (typeof(box) == "Vector3" and box.Magnitude or 0)
			table.insert(attachments, { Att = d, Parent = d.Parent, Reach = reach })
		elseif d:IsA("ParticleEmitter") then
			table.insert(emitters, d)
		elseif d:IsA("Trail") then
			table.insert(trails, d)
		end
	end
	local cadence = math.min(ctx.Speed / RunnerVisual.STRIDE, RunnerVisual.MAX_CADENCE)
	local steps, dts = {}, {}
	local last = {}
	local prevPos, prevAt, prevPitch = nil, nil, nil
	local minPitch, maxPitch, crossings = math.huge, -math.huge, 0
	local restRun, restMost, stuckRun, stuckMost, frames = 0, 0, 0, 0, 0
	local started = os.clock()
	local up = PhysicsTargets.lap.MinUpYStrict
	-- The clock RunnerView poses by: its last step each frame is on PreSimulation. A hitch between PreSimulation and
	-- Heartbeat would otherwise shorten the next Heartbeat gap against the stride phase really advanced.
	local poseClock = started
	local poseClockConn = RunService.PreSimulation:Connect(function()
		poseClock = os.clock()
	end)
	while os.clock() - started < seconds do
		RunService.Heartbeat:Wait()
		local now = poseClock
		if findCopy(ctx.Rig) ~= copy then
			note("copy_not_rebuilt_mid_run", now - started)
			break
		end
		frames += 1
		local torsoCf = torso.CFrame
		local dt = prevAt and now - prevAt or 0
		-- Root motion, reusing ui_runner_smooth's rule at the speed the run publishes
		if prevPos then
			local move = torsoCf.Position - prevPos
			table.insert(steps, move.Magnitude)
			table.insert(dts, dt)
			local along = move:Dot(ctx.Forward)
			if along < -cfg.BackwardTolerance then
				note("pos_no_backward_jump", -along)
			end
		end
		prevPos, prevAt = torsoCf.Position, now
		-- Limbs against the Torso: a jump is more than the pose's own largest rate allows over this frame's stride phase
		local phaseStep = TWO_PI * cadence * dt
		local rest, stuck = true, true
		for _, name in LIMBS do
			local limb = copy:FindFirstChild(name)
			if limb then
				local rel = torsoCf:ToObjectSpace(limb.CFrame)
				local before = last[name]
				if before then
					local angle = angleBetween(before, rel)
					local moved = (before.Position - rel.Position).Magnitude
					local angleLimit = pose.Rate[name] * phaseStep * cfg.JointRateFactor + math.rad(cfg.JointMinDegrees)
					local moveLimit = pose.PosRate[name] * phaseStep * cfg.JointRateFactor + cfg.JointMinStuds
					if angle > angleLimit then
						note("joint_no_angle_jump", math.deg(angle))
					end
					if moved > moveLimit then
						note("joint_no_position_jump", moved)
					end
					if angle > math.rad(cfg.StuckDegrees) or moved > cfg.StuckStuds then
						stuck = false
					end
				end
				last[name] = rel
			else
				note("copy_not_rebuilt_mid_run", now - started)
			end
		end
		for _, name in SWUNG do
			local limb = copy:FindFirstChild(name)
			if limb and angleBetween(torsoCf, limb.CFrame) > math.rad(cfg.RestDegrees) then
				rest = false
			end
		end
		-- A stride crosses the rest pose twice in a frame or so; a held rest or T pose stays there
		restRun = rest and restRun + 1 or 0
		restMost = math.max(restMost, restRun)
		stuckRun = (stuck and frames > 1) and stuckRun + 1 or 0
		stuckMost = math.max(stuckMost, stuckRun)
		local rightLeg = copy:FindFirstChild("RightLeg")
		if rightLeg then
			local pitch = pitchOf(torsoCf, rightLeg.CFrame)
			minPitch, maxPitch = math.min(minPitch, pitch), math.max(maxPitch, pitch)
			if prevPitch and (prevPitch - pose.PitchMid) * (pitch - pose.PitchMid) < 0 then
				crossings += 1
			end
			prevPitch = pitch
		end
		-- Every part of the copy
		for _, part in parts do
			local cf = part.CFrame
			if not cframeFinite(cf) then
				note("cframes_finite", 1)
			end
			if
				part.Name ~= "Trim" and (part.Transparency > 0 or part.LocalTransparencyModifier > 0 or not part.Parent)
			then
				note("parts_visible", part.Transparency + part.LocalTransparencyModifier)
			end
			local away = (cf.Position - torsoCf.Position).Magnitude
			if away > cfg.LimbBoundHips * RunnerFactory.HIP_HEIGHT then
				note("limbs_near_root", away)
			end
		end
		-- Feet: within what the pose itself lifts them (both legs swing out together), never below the sink limit
		local low = feetLow(copy) - ctx.Ground
		if
			low < pose.FootLow - cfg.FootTolerance
			or low > pose.FootHigh + cfg.FootTolerance
			or low < -cfg.FootSinkLimit
		then
			note("feet_on_ground", math.abs(low))
		end
		-- The root (the pose's Lean taken off the Torso) stays upright and faces the travel
		local root = torsoCf * pose.Lean:Inverse()
		local tilt = math.min(root.UpVector.Y, root.LookVector:Dot(ctx.Forward))
		if tilt < up then
			note("runner_upright", 1 - tilt)
		end
		-- Effects
		for _, entry in attachments do
			local att, host = entry.Att, entry.Parent
			local world = att.WorldPosition
			if att.Parent ~= host or not att:IsDescendantOf(copy) then
				note("attachments_on_part", 1)
			else
				local wanted = host.CFrame:PointToWorldSpace(att.Position)
				if not finite(world) or (world - wanted).Magnitude > cfg.AttachmentTolerance then
					note("attachments_on_part", (world - wanted).Magnitude)
				end
				if att:GetAttribute("MarketEffect") and host ~= torso then
					note("attachments_on_part", 1)
				end
				if att.Position.Magnitude > entry.Reach + cfg.AttachmentTolerance then
					note("attachments_near_part", att.Position.Magnitude)
				end
			end
			if world.Magnitude < cfg.OriginClear then
				note("emitters_not_at_origin", world.Magnitude)
			end
		end
		local reduced = UiMotion.Reduced()
		for _, emitter in emitters do
			local dustOff = reduced and emitter.Name == RUN_FX and emitter:GetAttribute("Dust") == true
			if not dustOff and (not emitter.Enabled or emitter.Rate <= 0) then
				note("emitters_on", emitter.Rate)
			end
		end
		for _, trail in trails do
			local a0, a1 = trail.Attachment0, trail.Attachment1
			local attached = a0 and a1 and a0:IsDescendantOf(copy) and a1:IsDescendantOf(copy)
			local width = attached and (a0.WorldPosition - a1.WorldPosition).Magnitude or 0
			if not trail.Enabled or width < cfg.MinRibbonWidth then
				note("trails_on", width)
			end
		end
	end
	poseClockConn:Disconnect()
	for name, entry in bad do
		table.insert(out[name], ("%s: %d frames, worst %.3f"):format(label, entry.Frames, entry.Worst))
	end
	local elapsed = os.clock() - started
	if #steps < minFrames then
		table.insert(out.frames_measured, ("%s: %d frames, want >= %d"):format(label, #steps, minFrames))
		return
	end
	local off = ctx.StepsOff(steps, dts, ctx.Speed, smooth)
	if off / #steps > smooth.MaxBadShare then
		table.insert(out.pos_no_pop, ("%s: %d of %d frames off speed x dt"):format(label, off, #steps))
	end
	if restMost > cfg.MaxRestFrames then
		table.insert(out.no_rest_pose_frames, ("%s: %d frames in a row"):format(label, restMost))
	end
	if stuckMost > cfg.MaxStuckFrames then
		table.insert(out.no_lost_animation_frames, ("%s: %d frames in a row"):format(label, stuckMost))
	end
	local wantCrossings = 2 * cadence * elapsed * cfg.PhaseShare
	if crossings < wantCrossings then
		table.insert(
			out.pose_phase_advances,
			("%s: %d crossings, want >= %.1f"):format(label, crossings, wantCrossings)
		)
	end
	if maxPitch - minPitch < pose.PitchRange * cfg.SwingShare then
		table.insert(
			out.pose_full_swing,
			("%s: %.1f deg of %.1f"):format(label, math.deg(maxPitch - minPitch), math.deg(pose.PitchRange))
		)
	end
end

-- Coverage: every model in CharacterModelAssets (30 characters + foe_ models) in the style it really runs, and each
-- starter wearing a model in another style (Karate Kid). Each style goes through every aura and every trail on its own.
local function buildRows()
	local ids = {}
	for id in CharacterModelAssets do
		table.insert(ids, id)
	end
	for _, id in CharacterCatalog.STARTER_PICKS do
		local spec = CharacterCatalog.Get(id)
		if spec and spec.RunStyle then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local rows, counts = {}, {}
	for _, id in ids do
		local spec = CharacterCatalog.Get(id)
		local style = spec and spec.RunStyle or nil
		local key = style or "default"
		counts[key] = (counts[key] or 0) + 1
		local auras, trails = MarketConfig.Items.Aura, MarketConfig.Items.Trail
		table.insert(rows, {
			Id = id,
			Style = style,
			Speed = spec and RaceConfig.Cruise(spec, 1) or cfg.FoeSpeed,
			Aura = auras[(counts[key] - 1) % #auras + 1].Id,
			Trail = trails[(counts[key] - 1) % #trails + 1].Id,
		})
	end
	return rows
end

local serial = 0
local function startRig(row, speed)
	serial += 1
	local name = cfg.RigPrefix .. serial
	preload(modelIdOf(row.Id))
	local ok, err =
		invoke(("run_visual_rig:%s:%s:%s:%s:%.3f"):format(name, row.Id, row.Aura, row.Trail, speed or row.Speed))
	return ok and name or nil, err
end

-- deps: check, checkList, stateMissing, renderFrame, stepsOff (ui_runner_smooth's rule, helpers of UiScenarios).
function UiRunVisual.Build(deps)
	local scenarios = {}

	function scenarios.ui_run_visual(res)
		UiRunVisual.Capture("off")
		if res.setup_error then
			deps.stateMissing(res, "rows_drawn", "run_visual", res.setup_error)
			return
		end
		if not deps.renderFrame() then
			deps.stateMissing(res, "rows_drawn", "rendering", "the client renders no frames")
			return
		end
		local models = ReplicatedStorage:FindFirstChild("CharacterModels")
		local modelsBy = os.clock() + cfg.ModelsWait
		while not (models and models:GetAttribute("Ready") == true) and os.clock() < modelsBy do
			task.wait(0.25)
			models = ReplicatedStorage:FindFirstChild("CharacterModels")
		end
		if not (models and models:GetAttribute("Ready") == true) then
			deps.stateMissing(res, "rows_drawn", "character_models_ready")
			return
		end
		local route = waitRoute()
		if not route then
			deps.stateMissing(res, "rows_drawn", "run_visual", "no route " .. cfg.Route)
			return
		end

		local out = {}
		for _, name in CHECKS do
			out[name] = {}
		end
		local started = os.clock()
		local rows = buildRows()
		local covered, drawn = {}, 0
		local function runRow(row, label, seconds, minFrames)
			local rig, err = startRig(row)
			if not rig then
				table.insert(out.rows_drawn, label .. ": " .. tostring(err))
				return nil
			end
			local copy = settle(rig, row.Id, row.Aura, row.Trail)
			if not copy then
				table.insert(out.rows_drawn, label .. ": no settled copy in " .. smooth.Wait .. " s")
				return nil
			end
			local ctx = {
				Rig = rig,
				Speed = row.Speed,
				Forward = route.Forward,
				Ground = route.Ground,
				StepsOff = deps.stepsOff,
			}
			checkRow(out, label, row, copy, Workspace:FindFirstChild(rig))
			watch(out, label, ctx, copy, seconds, minFrames)
			return ctx, copy
		end
		for _, row in rows do
			if os.clock() - started > cfg.MaxSeconds then
				break -- models_covered then fails and names the shortfall
			end
			if runRow(row, row.Id, cfg.SampleSeconds, smooth.MinFrames) then
				drawn += 1
				local key = row.Style or "default"
				covered[key] = covered[key] or {}
				covered[key][row.Aura] = true
				covered[key][row.Trail] = true
			end
		end

		-- Slot swap mid run, both ways (CarService.ApplyCharacter's order): the new slot's look and items on the same run
		local function firstOf(style)
			for _, row in rows do
				if row.Style == style then
					return row
				end
			end
			return nil
		end
		local plain, ninja = firstOf(nil), firstOf("NinjaRun")
		local swaps = 0
		for _, pair in { { plain, ninja }, { ninja, plain } } do
			local from, to = pair[1], pair[2]
			if from and to then
				local label = ("swap %s to %s"):format(from.Id, to.Id)
				local swapped = table.clone(to)
				local auras, trails = MarketConfig.Items.Aura, MarketConfig.Items.Trail
				swapped.Aura = auras[#auras].Id ~= from.Aura and auras[#auras].Id or auras[1].Id
				swapped.Trail = trails[#trails].Id ~= from.Trail and trails[#trails].Id or trails[1].Id
				local ctx = runRow(from, label .. " (before)", cfg.SwapSeconds, cfg.SwapMinFrames)
				if ctx then
					local ok, err = invoke(("run_visual_swap:%s:%s:%s"):format(to.Id, swapped.Aura, swapped.Trail))
					if not ok then
						table.insert(out.swap_settled, label .. ": " .. tostring(err))
					else
						-- The drawn distance must carry straight on through the rebuild, against the root (the lean differs)
						local steps, dts, prev, prevAt = {}, {}, nil, nil
						local copy = settle(ctx.Rig, to.Id, swapped.Aura, swapped.Trail, function(c)
							if complete(c) then
								local now = os.clock()
								local rootPos = (c.Torso.CFrame * poseOf(c).Lean:Inverse()).Position
								if prev then
									table.insert(steps, (rootPos - prev).Magnitude)
									table.insert(dts, now - prevAt)
								end
								prev, prevAt = rootPos, now
							end
						end)
						if not copy then
							table.insert(out.swap_settled, label .. ": no settled copy")
						else
							swaps += 1
							local off = deps.stepsOff(steps, dts, ctx.Speed, smooth)
							if off > cfg.SwapMaxBadFrames then
								table.insert(
									out.swap_no_pop,
									("%s: %d of %d frames off speed x dt"):format(label, off, #steps)
								)
							end
							checkRow(out, label, swapped, copy, Workspace:FindFirstChild(ctx.Rig))
							watch(out, label, ctx, copy, cfg.SwapSeconds, cfg.SwapMinFrames)
						end
					end
				end
			end
		end
		invoke("run_visual_clear")

		-- Results
		local modelCount = 0
		for _ in CharacterModelAssets do
			modelCount += 1
		end
		deps.check(res, "models_covered", drawn, ("%d rows (%d models)"):format(#rows, modelCount), drawn == #rows)
		local gaps = {}
		for _, key in { "default", "NinjaRun" } do
			for _, kind in { "Aura", "Trail" } do
				for _, item in MarketConfig.Items[kind] do
					if not (covered[key] and covered[key][item.Id]) then
						table.insert(gaps, key .. " " .. item.Id)
					end
				end
			end
		end
		deps.checkList(res, "each_style_each_effect", gaps)
		deps.check(res, "slot_swaps_run", swaps, 2, swaps == 2)
		for _, name in CHECKS do
			deps.checkList(res, name, out[name])
		end
		local total = os.clock() - started
		deps.check(res, "runtime_seconds", total, cfg.MaxSeconds + 30, total <= cfg.MaxSeconds + 30)
	end

	return scenarios
end

---------------------------------------------------------------------------------------------------------------
-- Capture: holds one run for screen_capture, since clipping between parts cannot be judged by code.
-- In the CLIENT datamodel (execute_luau), one command at a time:
--   game.ReplicatedStorage:SetAttribute("UiRunVisualCapture", "<characterId>:<auraId>:<trailId>:<view>:<phase>")
-- view: front | side | back. phase: degrees of the stride (90 = full swing, 0 = legs crossing) or live (animated).
-- Wait until LocalPlayer attribute UiRunVisualCaptureReady == that same string ("error:..." if it failed), then
-- screen_capture with no camera args. A new string changes the view or phase on the same run. "off" ends it.
local capture = nil
local captureBusy = false

local function stopCapture()
	if not capture then
		return
	end
	RunService:UnbindFromRenderStep("UiRunVisualCapture")
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = capture.CameraType
		camera.CameraSubject = capture.CameraSubject
	end
	for gui, enabled in capture.Guis do
		if gui.Parent then
			gui.Enabled = enabled
		end
	end
	capture.Floor:Destroy()
	capture = nil
	invoke("restore:run_visual")
end

local function captureFrame()
	local state = capture
	local copy = state and findCopy(state.Rig)
	local camera = Workspace.CurrentCamera
	if not (complete(copy) and camera) then
		return
	end
	-- After Client/RunnerView's step this frame: same root, the chosen phase. The run and its effects stay live.
	local root = copy.Torso.CFrame * poseOf(copy).Lean:Inverse()
	if state.Phase then
		RunnerVisual.Pose(copy, root, state.Phase, 1)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local eye = root:PointToWorldSpace(cfg.CaptureViews[state.View])
	camera.CFrame = CFrame.lookAt(eye, root.Position)
	state.Floor.CFrame = CFrame.new(root.X, state.Ground - state.Floor.Size.Y / 2, root.Z)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	for _, gui in playerGui and playerGui:GetChildren() or {} do
		if gui:IsA("ScreenGui") then
			if state.Guis[gui] == nil then
				state.Guis[gui] = gui.Enabled
			end
			gui.Enabled = false
		end
	end
	state.Frames += 1
end

local function captureCommand(command)
	if command == "off" then
		stopCapture()
		return
	end
	local id, aura, trail, view, phase = string.match(command, "^([^:]+):([^:]+):([^:]+):(%a+):([%w%.]+)$")
	if not (id and cfg.CaptureViews[view] and (phase == "live" or tonumber(phase))) then
		error("want <characterId>:<auraId>:<trailId>:<front|side|back>:<degrees|live>")
	end
	local warm = 0
	if not (capture and capture.Id == id and capture.Aura == aura and capture.Trail == trail) then
		stopCapture()
		local ok, err = invoke("run_visual")
		if not ok then
			error(err)
		end
		local route = waitRoute()
		if not route then
			error("no route " .. cfg.Route)
		end
		local rig, rigErr = startRig({ Id = id, Aura = aura, Trail = trail }, cfg.CaptureSpeed)
		if not rig then
			error(rigErr)
		end
		if not settle(rig, id, aura, trail) then
			error("no settled copy of " .. rig)
		end
		local camera = Workspace.CurrentCamera
		local floor = Instance.new("Part") -- client only: shows sinking and floating; the fixture's route has no world under it
		floor.Name = "UiRunVisualFloor"
		floor.Anchored, floor.CanCollide, floor.CanTouch, floor.CanQuery = true, false, false, false
		floor.Size = cfg.CaptureFloor
		floor.Color = Color3.fromRGB(120, 125, 120)
		floor.Material = Enum.Material.SmoothPlastic
		floor.Parent = Workspace
		capture = {
			Id = id,
			Aura = aura,
			Trail = trail,
			Rig = rig,
			Ground = route.Ground,
			Floor = floor,
			Guis = {},
			Frames = 0,
			CameraType = camera.CameraType,
			CameraSubject = camera.CameraSubject,
		}
		RunService:BindToRenderStep("UiRunVisualCapture", Enum.RenderPriority.Camera.Value + 2, captureFrame)
		warm = cfg.CaptureWarmSeconds
	end
	capture.View = view
	capture.Phase = tonumber(phase) and math.rad(tonumber(phase)) or nil
	local from = capture.Frames
	local deadline = os.clock() + warm + smooth.Wait
	task.wait(warm)
	while capture.Frames < from + cfg.CaptureFrames do
		if os.clock() > deadline then
			error("no rendered frames")
		end
		task.wait()
	end
end

-- Runs one capture command; the outcome lands on LocalPlayer's UiRunVisualCaptureReady.
function UiRunVisual.Capture(command)
	if command == "off" and not capture then
		return
	end
	while captureBusy do
		task.wait(0.05)
	end
	captureBusy = true
	player:SetAttribute(UiRunVisual.CAPTURE_READY_ATTR, nil)
	local ok, err = pcall(captureCommand, command)
	player:SetAttribute(UiRunVisual.CAPTURE_READY_ATTR, ok and command or "error:" .. tostring(err))
	captureBusy = false
end

return UiRunVisual
