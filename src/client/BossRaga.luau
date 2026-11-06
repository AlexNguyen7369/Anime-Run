--!nonstrict
-- The live boss (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Boss and attacks"): anchored MeshParts from ReplicatedStorage.BossModels,
-- posed by CFrame every frame from BossRagaPoses. Client-side only: the same server time gives every player the same pose.
-- Pose data has Blender's axes (front -Y, Z up); C turns them into Roblox's (front -Z, Y up), which is how a GLB's mesh arrives.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig"))
local Poses = require(Shared:WaitForChild("BossRagaPoses"))

local C = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
local C_INVERSE = C:Inverse()
local SCALE = Poses.Scale
local RUMBLE_STUDS, RUMBLE_DEGREES = 9, 0.7 -- placeholder: the model's own shake while it rises
local MODEL_WAIT = 30 -- s: the server loads the model at start, so this only matters on a very fresh server
local PARTS = 18

local function vector(list)
	return Vector3.new(list[1], list[2], list[3])
end

-- Parents before children, each with its numbers ready.
local ORDER = {}
do
	local placed = {}
	local function place(name)
		if placed[name] then
			return
		end
		placed[name] = true
		local bind = Poses.Bind[name]
		if bind.Parent then
			place(bind.Parent)
		end
		table.insert(ORDER, {
			Name = name,
			Parent = bind.Parent,
			Offset = vector(bind.Offset) * SCALE,
			Center = CFrame.new(vector(bind.Center) * SCALE),
		})
	end
	for name in Poses.Bind do
		place(name)
	end
end

local BossRaga = {}
BossRaga.__index = BossRaga

-- Makes the Model at once and fills it when the server's copy is there. Every part starts hidden.
function BossRaga.new(parent)
	local self = setmetatable({}, BossRaga)
	self.Model = Instance.new("Model")
	self.Model.Name = "BigRaga"
	self.Model.Parent = parent
	self.Shown = false
	self.Anchor = CFrame.new(Arena.Center)
	self.Joints = {}
	task.spawn(function()
		local root = ReplicatedStorage:WaitForChild("BossModels", MODEL_WAIT)
		local deadline = os.clock() + MODEL_WAIT
		while root and root:GetAttribute("Ready") ~= true and os.clock() < deadline do
			task.wait(0.1)
		end
		local source = root and root:FindFirstChild("boss_raga")
		if not source or #source:GetChildren() ~= PARTS or not self.Model.Parent then
			warn("[BossRaga] no model to show")
			return
		end
		local parts = {}
		for i, row in ORDER do
			local part = source[row.Name]:Clone()
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Transparency = 1
			part.Parent = self.Model
			parts[i] = part
		end
		self.Parts = parts
	end)
	return self
end

-- rise: nil before the spawn, then 0 to 1. Lifting is done by moving the whole boss down, through the dais.
function BossRaga:Step(rise, below, move, localTime, now)
	if not self.Parts then
		return
	end
	local shown = rise ~= nil
	if shown ~= self.Shown then
		self.Shown = shown
		for _, part in self.Parts do
			part.Transparency = shown and 0 or 1
		end
	end
	if not shown then
		return
	end
	local anchor = CFrame.new(Arena.Center.X, Arena.Y - below, Arena.Center.Z)
	if rise < 1 then
		local amount = math.min(1, (1 - rise) * 8)
		local studs, turn = RUMBLE_STUDS * amount, math.rad(RUMBLE_DEGREES) * amount
		anchor *= CFrame.new(
			studs * math.noise(now * 11, 1.5),
			0.5 * studs * math.noise(now * 17, 2.5),
			studs * math.noise(now * 13, 3.5)
		) * CFrame.Angles(turn * math.noise(now * 9, 4.5), 0, turn * math.noise(now * 7, 5.5))
	end
	self.Anchor = anchor
	local parts, root = Poses.Sample(move, localTime)
	local joints = self.Joints
	local frames = {}
	for i, row in ORDER do
		local v = parts[row.Name]
		local offset = row.Parent and row.Offset or row.Offset + root * SCALE
		local joint = CFrame.new(offset)
			* CFrame.Angles(0, 0, math.rad(v.Z))
			* CFrame.Angles(0, math.rad(v.Y), 0)
			* CFrame.Angles(math.rad(v.X), 0, 0)
		if row.Parent then
			joint = joints[row.Parent] * joint
		end
		joints[row.Name] = joint
		frames[i] = anchor * C * joint * row.Center * C_INVERSE
	end
	Workspace:BulkMoveTo(self.Parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- A joint's world CFrame now, with Roblox's axes. At the rest anchor until the first pose.
function BossRaga:Frame(name)
	local joint = self.Joints[name]
	return self.Anchor * C * (joint or CFrame.identity) * C_INVERSE
end

-- A point on a part, given in model units and Blender axes from its joint.
function BossRaga:Point(name, units)
	local joint = self.Joints[name] or CFrame.identity
	return (self.Anchor * C * joint):PointToWorldSpace(units * SCALE)
end

-- A point of the unposed model, in units and Blender axes, standing on the dais.
function BossRaga.RestPoint(units)
	return (CFrame.new(Arena.Center) * C):PointToWorldSpace(units * SCALE)
end

return BossRaga
