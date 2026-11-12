--!nonstrict
-- The live boss (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Boss and attacks"): anchored MeshParts from ReplicatedStorage.BossModels,
-- posed by CFrame every frame from BossRagaPoses. Client-side only: the same server time gives every player the same pose.
-- Pose data has Blender's axes (front -Y, Z up); C turns them into Roblox's (front -Z, Y up), which is how a GLB's mesh arrives.
-- Also the rig of other bosses (Client/BossMage), through BossRaga.new's options.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig"))
local Poses = require(Shared:WaitForChild("LateData")).Get("BossRagaPoses") -- design doc 7: delivered with the first event

local C = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
local C_INVERSE = C:Inverse()
local SCALE = Poses.Scale * Arena.BossScale -- the meshes arrive at Poses.Scale; BossScale shrinks them and the joints alike
local RUMBLE_STUDS, RUMBLE_DEGREES = 9, 0.7 -- placeholder: the model's own shake while it rises
local TREMBLE_STUDS = 5 -- placeholder: the scream's small shake
local MODEL_WAIT = 30 -- s: the server loads the model at start, so this only matters on a very fresh server

local function vector(list)
	return Vector3.new(list[1], list[2], list[3])
end

-- Parents before children, each with its numbers ready.
local function orderOf(bind, scale)
	local order, placed = {}, {}
	local function place(name)
		if placed[name] then
			return
		end
		placed[name] = true
		local row = bind[name]
		if row.Parent then
			place(row.Parent)
		end
		table.insert(order, {
			Name = name,
			Parent = row.Parent,
			Offset = vector(row.Offset) * scale,
			Center = CFrame.new(vector(row.Center) * scale),
		})
	end
	for name in bind do
		place(name)
	end
	return order
end

local BossRaga = {}
BossRaga.__index = BossRaga

-- Makes the Model at once and fills it when the server's copy is there. Every part starts hidden. options nil is Big Raga; another
-- rig (Client/BossMage) gives { Poses, Bind, Source (its BossModels child), Name, Scale (studs per unit), SizeScale (of the
-- delivered sizes), RootScale (of Sample's root; 1 when it is already studs) }.
function BossRaga.new(parent, options)
	options = options or {}
	local self = setmetatable({}, BossRaga)
	self.Poses = options.Poses or Poses
	self.Scale = options.Scale or SCALE
	self.RootScale = options.RootScale or self.Scale
	self.Order = orderOf(options.Bind or self.Poses.Bind, self.Scale)
	local sourceName, sizeScale = options.Source or "boss_raga", options.SizeScale or Arena.BossScale
	self.Model = Instance.new("Model")
	self.Model.Name = options.Name or "BigRaga"
	self.Model.Parent = parent
	self.Shown = false
	self.Anchor = CFrame.new(Arena.Center)
	self.Joints = {}
	self.Growth = 1
	task.spawn(function()
		local root = ReplicatedStorage:WaitForChild("BossModels", MODEL_WAIT)
		local deadline = os.clock() + MODEL_WAIT
		while root and root:GetAttribute("Ready") ~= true and os.clock() < deadline do
			task.wait(0.1)
		end
		local source = root and root:FindFirstChild(sourceName)
		if not source or #source:GetChildren() ~= #self.Order or not self.Model.Parent then
			warn("[BossRaga] no model to show" .. (options.Source and ": " .. sourceName or ""))
			return
		end
		local parts, sizes = {}, {}
		for i, row in self.Order do
			local part = source[row.Name]:Clone()
			sizes[i] = part.Size * sizeScale
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Transparency = 1
			part.Parent = self.Model
			parts[i] = part
		end
		self.Parts, self.Sizes = parts, sizes
		-- Hidden parts fetch nothing: ask for the meshes and textures now, so the rise (or a late join) shows a whole boss at once.
		task.spawn(pcall, ContentProvider.PreloadAsync, ContentProvider, parts)
	end)
	return self
end

-- A frame relative to the anchor, grown about the anchor: the feet stand there, so they stay on the dais.
local function grown(frame, growth)
	return frame.Rotation + frame.Position * growth
end

-- Shows or hides every part on a change. Returns shown. Call only once Parts is there.
function BossRaga:Show(shown)
	if shown ~= self.Shown then
		self.Shown = shown
		for _, part in self.Parts do
			part.Transparency = shown and 0 or 1
		end
	end
	return shown
end

-- rise: nil before the spawn, then 0 to 1. Lifting is done by moving the whole boss down, through the dais. Stage 2's growth (a part's
-- size and place, at most 18 parts' writes a frame, only during the scream), wheel spin in radians and scream tremble (0 to 1).
function BossRaga:Step(rise, below, move, localTime, now, growth, spin, tremble)
	if not self.Parts then
		return
	end
	if not self:Show(rise ~= nil) then
		return
	end
	local anchor = CFrame.new(Arena.Center.X, Arena.DaisY - below, Arena.Center.Z)
	if rise < 1 then
		local amount = math.min(1, (1 - rise) * 8)
		local studs, turn = RUMBLE_STUDS * amount, math.rad(RUMBLE_DEGREES) * amount
		anchor *= CFrame.new(
			studs * math.noise(now * 11, 1.5),
			0.5 * studs * math.noise(now * 17, 2.5),
			studs * math.noise(now * 13, 3.5)
		) * CFrame.Angles(turn * math.noise(now * 9, 4.5), 0, turn * math.noise(now * 7, 5.5))
	end
	if tremble > 0 then -- sideways only: the feet stay on the dais
		local studs = TREMBLE_STUDS * tremble
		anchor *= CFrame.new(studs * math.noise(now * 19, 6.5), 0, studs * math.noise(now * 23, 7.5))
	end
	local parts, root = self.Poses.Sample(move, localTime)
	self:Pose(anchor, parts, root, growth, spin)
end

-- Places every part from a sampled pose: parts (XYZ degrees), root (times RootScale). locs (units from the parent's joint) replace the
-- bind's offsets when given; size scales each part about its own centre (default growth, which also grows the places).
function BossRaga:Pose(anchor, parts, root, growth, spin, locs, size)
	self.Anchor = anchor
	self.Growth = growth
	size = size or growth
	-- SizedAt starts nil, so the first shown frame applies BossScale even at growth 1 (and a late join's growth)
	if size ~= self.SizedAt then
		self.SizedAt = size
		for i, part in self.Parts do
			part.Size = self.Sizes[i] * size
		end
	end
	local joints = self.Joints
	local frames = {}
	for i, row in self.Order do
		local v = parts[row.Name]
		local offset = locs and locs[row.Name] * self.Scale or row.Offset
		if not row.Parent then
			offset += root * self.RootScale
		end
		local joint = CFrame.new(offset)
			* CFrame.Angles(0, 0, math.rad(v.Z))
			* CFrame.Angles(0, math.rad(v.Y), 0)
			* CFrame.Angles(math.rad(v.X), 0, 0)
		if row.Parent then
			joint = joints[row.Parent] * joint
		end
		joints[row.Name] = joint
		if row.Name == "Wheel" then
			joint *= CFrame.Angles(0, spin, 0) -- the wheel's local Y is its hub (tools/blender/build_boss_event.py raga_wheel)
		end
		frames[i] = anchor * grown(C * joint * row.Center * C_INVERSE, growth)
	end
	Workspace:BulkMoveTo(self.Parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- A joint's world CFrame now, with Roblox's axes. At the rest anchor until the first pose.
function BossRaga:Frame(name)
	local joint = self.Joints[name]
	return self.Anchor * grown(C * (joint or CFrame.identity) * C_INVERSE, self.Growth)
end

-- A point on a part, given in model units and Blender axes from its joint.
function BossRaga:Point(name, units)
	local joint = self.Joints[name] or CFrame.identity
	return self.Anchor:PointToWorldSpace((C * joint):PointToWorldSpace(units * self.Scale) * self.Growth)
end

-- A point of the unposed model, in units and Blender axes, standing on the dais.
function BossRaga.RestPoint(units)
	return (CFrame.new(Arena.Center.X, Arena.DaisY, Arena.Center.Z) * C):PointToWorldSpace(units * SCALE)
end

return BossRaga
