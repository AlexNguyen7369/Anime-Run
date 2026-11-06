--!nonstrict
-- Sidekick followers (design doc 4.36; docs/SIDEKICK_SPEC.md "Display"), client only. Contract: Client/UiTest/UiSidekickFollow.
-- A VisibleRunner wears what its CharacterId has equipped, from its Owner's replicated SidekickGear and SidekickBag. On foot
-- there is no VisibleRunner, so no follower. Attacks at the boss play on top of the follow motion, from Client/SidekickAttackView.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SidekickConfig"))
local Follow = require(Shared:WaitForChild("SidekickFollow"))
local GachaConfig = require(Shared:WaitForChild("GachaConfig"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))
local RunnerVisual = require(script.Parent.RunnerVisual)
local SidekickAttackView = require(script.Parent.SidekickAttackView)
local UiMotion = require(script.Parent.UiMotion)

-- All placeholders.
local SYNC_SECONDS = 0.2 -- how often worn Sidekicks and the budget are read again
local KEEP_DRAWN = 0.7 -- a drawn follower counts as this much nearer, so two at equal distance do not swap clones
local FULL_TROT = 60 -- studs/s at which the trot reaches full size
local SPEED_RATE = 5 -- 1/s: how fast the measured speed settles
local MAX_SPEED = 800 -- studs/s: a teleport's jump is not a speed
local CAMERA_SIDE = 0.3 -- the camera must be this far off the runner's line, as a sine, to change the follower's side
local SIDE_RATE = 4 -- 1/s: how fast the follower crosses to the camera's side
local CROSS_AHEAD = 3 -- studs: extra lead while crossing, so it passes in front of the runner and not through it
local FLAP, FLAP_RATE = math.rad(28), 9 -- radians each way, rad/s
local DOG_LAG = 0.9 -- radians: the second dog's trot behind the first
local TAIL_RATE = 2 -- tail bounces per stride
local OUTLINE_TRANSPARENCY = 0.35

local player = Players.LocalPlayer
local holder = Instance.new("Folder")
holder.Name = "SidekickFollowers"
holder.Parent = Workspace

local followers = {} -- owner UserId -> follower
local worn = {} -- owner UserId -> the attributes last read and the id they gave, so JSON is decoded only on a change
local nextSync = 0
SidekickAttackView.Start(followers)

local function partsOf(model)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

-- The world box of `parts`, as its low corner and high corner.
local function boxOf(parts)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in parts do
		local cf, half = part.CFrame, part.Size / 2
		local reach = Vector3.new(
			math.abs(cf.XVector.X) * half.X + math.abs(cf.YVector.X) * half.Y + math.abs(cf.ZVector.X) * half.Z,
			math.abs(cf.XVector.Y) * half.X + math.abs(cf.YVector.Y) * half.Y + math.abs(cf.ZVector.Y) * half.Z,
			math.abs(cf.XVector.Z) * half.X + math.abs(cf.YVector.Z) * half.Y + math.abs(cf.ZVector.Z) * half.Z
		)
		low = low:Min(cf.Position - reach)
		high = high:Max(cf.Position + reach)
	end
	return low, high
end

-- The point of `part` nearest `toward`: where a wing or tail joins the body, whatever the mesh's own origin is.
local function jointOf(part, toward)
	local here, half = part.CFrame:PointToObjectSpace(toward), part.Size / 2
	return part.CFrame:PointToWorldSpace(here:Max(-half):Min(half))
end

local function moveOf(kind, joint, centre, sign)
	local at = joint - centre
	return { Kind = kind, Hinge = CFrame.new(at), Back = CFrame.new(-at), Sign = sign }
end

-- What moves on its own inside the model, by part name: wings on flyers, the second dog, a bouncing tail.
local function movesOf(parts, row, centre)
	local byName = {}
	for _, part in parts do
		byName[part.Name] = part
	end
	local body = byName.Body or byName.Torso
	local anchor = body and body.Position or centre
	local trot = Follow.Trot(row.Id)
	local moves = {}
	for i, part in parts do
		local name = part.Name
		if row.Movement == "Fly" and string.sub(name, 1, 4) == "Wing" then
			local wing = byName[string.find(name, "Left", 1, true) and "WingLeft" or "WingRight"] or part
			-- by position: the source's Left and Right are its own, and the flap goes up on both
			moves[i] = moveOf("Wing", jointOf(wing, anchor), centre, wing.Position.X > anchor.X and 1 or -1)
		elseif row.Id == "side_dogs" and string.sub(name, 1, 5) == "Black" then
			moves[i] = { Kind = "Lag" }
		elseif trot.Tail and name == "Tail" then
			moves[i] = moveOf("Tail", jointOf(part, anchor), centre)
		end
	end
	return moves
end

local function build(owner, row, runner)
	local models = ReplicatedStorage:FindFirstChild("SidekickModels")
	local source = models and models:FindFirstChild(row.Id)
	local sourceParts = source and partsOf(source)
	if not (sourceParts and #sourceParts > 0) then
		return nil -- still loading: the next sync tries again
	end
	local sourceLow, sourceHigh = boxOf(sourceParts)
	local model = source:Clone()
	model.Name = "Follower_" .. tostring(owner)
	model:SetAttribute("SidekickId", row.Id)
	model:ScaleTo(Follow.Size(row.Id) / (sourceHigh.Y - sourceLow.Y))
	local parts = partsOf(model)
	local low, high = boxOf(parts)
	local centre = (low + high) / 2
	local rests = table.create(#parts)
	for i, part in parts do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		rests[i] = part.CFrame - centre
	end
	local outline = nil
	if owner == player.UserId then
		outline = Instance.new("Highlight")
		outline.Adornee = model
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.FillTransparency = 1
		outline.OutlineColor = GachaConfig.RARITY_COLORS[row.Rarity] or GachaConfig.RARITY_COLORS.Common
		outline.OutlineTransparency = OUTLINE_TRANSPARENCY
		outline.Parent = model
	end
	return {
		Id = row.Id,
		Row = row,
		Trot = Follow.Trot(row.Id),
		Model = model,
		Runner = runner,
		Parts = parts,
		Rests = rests,
		Moves = movesOf(parts, row, centre),
		Frames = table.clone(rests),
		Outline = outline,
		Phase = 0,
		Speed = 0,
		Hidden = false,
	}
end

local function drop(owner)
	local follower = followers[owner]
	if follower then
		followers[owner] = nil
		follower.Model:Destroy()
	end
end

-- The Sidekick this runner's character wears, or nil.
local function wornBy(runner, owner)
	local fixture = runner:GetAttribute("FollowerFixtureId") -- tests only: a crowd rig has no Player
	if fixture then
		return fixture
	end
	local who = Players:GetPlayerByUserId(owner)
	if not who then
		return nil
	end
	local gear, bag = who:GetAttribute("SidekickGear"), who:GetAttribute("SidekickBag")
	local character = runner:GetAttribute("CharacterId")
	local memo = worn[owner]
	if not (memo and memo.Gear == gear and memo.Bag == bag and memo.Character == character) then
		memo = { Gear = gear, Bag = bag, Character = character, Id = Follow.WornId(gear, bag, character) }
		worn[owner] = memo
	end
	return memo.Id
end

-- Which runners get a follower: the local player's always, then the nearest up to the budget.
local function sync(camera)
	local eye = camera and camera.CFrame.Position or Vector3.zero
	local wanted = {}
	for _, runner in CollectionService:GetTagged(RunnerVisual.TAG) do
		local owner = runner:GetAttribute("Owner")
		local torso = runner:FindFirstChild("Torso")
		local row = type(owner) == "number" and torso and Config.Get(wornBy(runner, owner))
		if row then
			local rank = (torso.Position - eye).Magnitude * (followers[owner] and KEEP_DRAWN or 1)
			table.insert(
				wanted,
				{ Owner = owner, Row = row, Runner = runner, Rank = owner == player.UserId and -1 or rank }
			)
		end
	end
	table.sort(wanted, function(a, b)
		return a.Rank < b.Rank
	end)
	local keep = {}
	for i = 1, math.min(#wanted, Follow.MaxFollowers) do
		keep[wanted[i].Owner] = wanted[i]
	end
	for owner, follower in followers do
		local want = keep[owner]
		if not want or want.Row.Id ~= follower.Id then
			drop(owner)
		end
	end
	for owner, want in keep do
		local follower = followers[owner]
		if follower then
			follower.Runner = want.Runner
		else
			followers[owner] = build(owner, want.Row, want.Runner)
			if followers[owner] then
				followers[owner].Model.Parent = holder
			end
		end
	end
end

local function setHidden(follower, hidden)
	follower.Hidden = hidden
	for _, part in follower.Parts do
		part.LocalTransparencyModifier = hidden and 1 or 0
	end
	if follower.Outline then
		follower.Outline.Enabled = not hidden
	end
end

-- The side of the runner the camera is on: stays put while the camera is near the runner's line.
local function sideGoal(follower, root, camera)
	local seen = root:PointToObjectSpace(camera.CFrame.Position)
	local across = Vector3.new(seen.X, 0, seen.Z).Magnitude
	if across > 0 and math.abs(seen.X) / across > CAMERA_SIDE then
		return seen.X > 0 and 1 or -1
	end
	return follower.SideGoal or 1
end

local function place(follower, camera, now, dt, reduced)
	local torso = follower.Runner:FindFirstChild("Torso")
	if not torso then
		return
	end
	local hidden = torso.LocalTransparencyModifier >= 1 or torso.Transparency >= 1
	if hidden ~= follower.Hidden then
		setHidden(follower, hidden)
	end
	if hidden then
		return
	end
	local root = RunnerVisual.RootOf(follower.Runner) or torso.CFrame
	local measured = follower.Last and dt > 0 and (root.Position - follower.Last).Magnitude / dt or 0
	follower.Last = root.Position
	follower.Speed += (math.min(measured, MAX_SPEED) - follower.Speed) * (1 - math.exp(-SPEED_RATE * dt))

	follower.SideGoal = camera and sideGoal(follower, root, camera) or follower.SideGoal or 1
	follower.Side = follower.Side or follower.SideGoal
	follower.Side += (follower.SideGoal - follower.Side) * (1 - math.exp(-SIDE_RATE * dt))
	local side = follower.Side

	local row, trot = follower.Row, follower.Trot
	local walking = row.Movement == "Walk"
	local amount = (walking and not reduced) and math.clamp(follower.Speed / FULL_TROT, 0, 1) or 0
	follower.Phase = RunnerVisual.Advance(follower.Phase, follower.Speed, dt * trot.Cadence)
	local phase = follower.Phase
	local bob = math.abs(math.sin(phase)) * trot.Bob * amount
	local lag = (math.abs(math.sin(phase + DOG_LAG)) * trot.Bob * amount) - bob
	local flap = reduced and 0 or FLAP * math.sin(now * FLAP_RATE)
	local tail = (trot.Tail or 0) * math.sin(phase * TAIL_RATE) * amount

	local offset = Follow.Offset(row, reduced and 0 or now)
	local ground = root
		* CFrame.new(0, -RunnerFactory.HIP_HEIGHT, 0)
		* CFrame.new(offset.X * side, 0, offset.Z - (1 - side * side) * CROSS_AHEAD)
		* CFrame.Angles(-trot.Lean * amount, 0, 0)
	local frame = ground * CFrame.new(0, offset.Y + bob, 0)

	local rests, moves, frames = follower.Rests, follower.Moves, follower.Frames
	local pose, flaps = SidekickAttackView.Pose(follower, now)
	for i, rest in rests do
		local move = moves[i]
		local posed = pose and pose[i] or CFrame.identity
		if not move then
			frames[i] = frame * posed * rest
		elseif move.Kind == "Wing" then
			local angle = flap * move.Sign * (flaps and flaps[i] or 1)
			frames[i] = frame * posed * move.Hinge * CFrame.Angles(0, 0, angle) * move.Back * rest
		elseif move.Kind == "Lag" then
			frames[i] = frame * CFrame.new(0, lag, 0) * posed * rest
		else
			frames[i] = frame * posed * move.Hinge * CFrame.Angles(tail, 0, 0) * move.Back * rest
		end
	end
	Workspace:BulkMoveTo(follower.Parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- After RunnerView's step (Camera - 1) in the same frame, so a follower is never a frame behind its runner at any speed.
RunService:BindToRenderStep("SidekickFollower", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	local due = now >= nextSync
	for _, follower in followers do
		due = due or not follower.Runner.Parent -- a re-skin rebuilds the runner, a run's end removes it
	end
	if due then
		nextSync = now + SYNC_SECONDS
		sync(camera)
	end
	local reduced = UiMotion.Reduced()
	for _, follower in followers do
		place(follower, camera, now, dt, reduced)
	end
end)

Players.PlayerRemoving:Connect(function(who)
	worn[who.UserId] = nil
	drop(who.UserId)
end)
