--!nonstrict
-- The Golden King (design doc 4.37 "Third boss", docs/BOSS_EVENT_SPEC.md "The Golden King"): one Client/BossRaga rig from
-- ReplicatedStorage.BossModels (boss_king), posed every frame from BossKingPoses. In his own arena he hovers over the treasure
-- mound, his feet BossArenaConfig HoverY over the deck (12 over the mound's top), and bobs BobStuds (top to bottom) every BobSeconds
-- on the server clock (owner 2026-11-12, design doc 4.37 "The Golden King's own arena"), facing as Big Raga does. Ea and the Key
-- are parts of the bind, so the bake's drum spin plays as pose data; the rig has elbows and knees (design doc 4.37 "Animation
-- rework"). Entrance (an open question in the spec): he rises through the mound over RiseSeconds as Big Raga does, until the owner
-- rules. Poses are late data (design doc 7), read when his event or preview first shows him.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig")).For("boss_king")
local BossCatalog = require(Shared:WaitForChild("BossCatalog"))
-- design doc 7: required only while his event or preview shows, so it waits for his poses alone
local Poses =
	require(Shared:WaitForChild("LateData")).Get(require(Shared:WaitForChild("BossCatalog")).Get("boss_king").Poses)
local BossRaga = require(script.Parent:WaitForChild("BossRaga"))

-- Enuma 360 (owner 2026-11-13, design doc 4.37 / BOSS_EVENT_SPEC "Boss effects after playing", proposed): over the Window his
-- whole rig turns about his centre on top of the baked pose, so his torso's yaw goes SWEEP_DEGREES one way (smoothstep), then
-- the extra eases back to facing front by SWEEP_HOME s.
local SWEEP_DEGREES, SWEEP_HOME = 370, 5.6
local WINDOW = Poses and Poses.Moves and Poses.Moves.enuma and Poses.Moves.enuma.Window or { 3, 5 }
local C = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0)) -- as BossRaga's
local C_INVERSE = C:Inverse()
local sweepFrom, sweepSign = nil, nil -- the baked torso yaw at the Window's start, the way the keys turn there

local function smoothstep(u)
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function wrap(a)
	return math.atan2(math.sin(a), math.cos(a))
end

-- The baked Torso's yaw (radians, Roblox axes) from a sampled pose: the Torso is a root joint, so its XYZ degrees alone, in
-- BossRaga:Pose's order.
local function bakedYaw(parts)
	local v = parts.Torso
	local turned = CFrame.Angles(0, 0, math.rad(v.Z))
		* CFrame.Angles(0, math.rad(v.Y), 0)
		* CFrame.Angles(math.rad(v.X), 0, 0)
	local look = (C * turned * C_INVERSE).LookVector
	return math.atan2(-look.X, -look.Z)
end

-- The rig's extra yaw at time t of enuma, given the baked pose's parts at t.
local function sweepYaw(parts, t)
	if t <= WINDOW[1] or t >= SWEEP_HOME then
		return 0
	end
	if not sweepFrom then
		sweepFrom = bakedYaw((Poses.Sample("enuma", WINDOW[1])))
		local ahead = wrap(bakedYaw((Poses.Sample("enuma", WINDOW[1] + 0.05))) - sweepFrom)
		sweepSign = ahead < 0 and -1 or 1
	end
	local function extraAt(at, baked)
		local theta = sweepSign * math.rad(SWEEP_DEGREES) * smoothstep((at - WINDOW[1]) / (WINDOW[2] - WINDOW[1]))
		return theta - (baked - sweepFrom) -- mod 2 pi: his torso's world yaw is sweepFrom + theta
	end
	if t <= WINDOW[2] then
		return extraAt(t, bakedYaw(parts))
	end
	local last = wrap(extraAt(WINDOW[2], bakedYaw((Poses.Sample("enuma", WINDOW[2])))))
	return last * (1 - smoothstep((t - WINDOW[2]) / (SWEEP_HOME - WINDOW[2])))
end

local BossKing = {}
BossKing.__index = BossKing

function BossKing.new(parent)
	local self = setmetatable({}, BossKing)
	self.Rest = CFrame.new(Arena.Center.X, Arena.Y + Arena.HoverY, Arena.Center.Z)
	if not (Poses and Poses.Bind and Poses.Sample) then
		warn("[BossKing] BossKingPoses has no keys yet: no rig")
		return self
	end
	self.Him = BossRaga.new(parent, {
		Poses = Poses,
		Source = "boss_king",
		Bind = Poses.Bind,
		Name = BossCatalog.Get("boss_king").ModelName,
		Scale = Poses.Scale,
		SizeScale = 1,
		RootScale = 1, -- Sample's root is studs, as the mage's
	})
	self.Him.Anchor = self.Rest
	return self
end

-- rise: nil before the spawn (hidden), then 0 to 1 as he comes up through the mound. move, localTime: Poses.Schedule's.
function BossKing:Step(rise, move, localTime)
	local him = self.Him
	if him and him.Parts and him:Show(rise ~= nil) then
		-- locs: the hips move round as his body turns (the beam sweep), Ea's grip moves on the forearm (out of the hand at rest)
		local parts, root, locs = Poses.Sample(move, localTime)
		local below = (1 - rise) * (Arena.BossHeight + Arena.HoverY)
		local bob = Arena.BobStuds / 2 * math.sin(Workspace:GetServerTimeNow() * 2 * math.pi / Arena.BobSeconds)
		local turn = move == "enuma" and sweepYaw(parts, localTime) or 0
		local at = self.Rest - Vector3.new(0, below - bob, 0)
		him:Pose(at * CFrame.Angles(0, turn, 0), parts, root, 1, 0, locs)
		if move == "enuma" and localTime > WINDOW[1] and localTime < SWEEP_HOME and him.Joints.Ea then
			-- The beam runs along Ea's blade (design doc 4.37), and Ea's baked yaw drifts about 45 deg against the turn over the
			-- Window, so the sweep is driven by Ea's yaw, not the torso's: Ea's world yaw goes SWEEP_DEGREES one way from where
			-- it is at the Window's start, then the extra eases home as before. Joints are rig-local, so turn only adds yaw.
			local v = (C * him.Joints.Ea):VectorToWorldSpace(Poses.EaTip)
			local ea = math.atan2(-v.X, -v.Z)
			if localTime <= WINDOW[2] then
				self.EaFrom = self.EaFrom or ea + turn
				local u = smoothstep((localTime - WINDOW[1]) / (WINDOW[2] - WINDOW[1]))
				local want = self.EaFrom + sweepSign * math.rad(SWEEP_DEGREES) * u
				turn += wrap(want - (ea + turn))
				self.EaTurn = turn
			else
				turn = wrap(self.EaTurn or turn) * (1 - smoothstep((localTime - WINDOW[2]) / (SWEEP_HOME - WINDOW[2])))
			end
			him:Pose(at * CFrame.Angles(0, turn, 0), parts, root, 1, 0, locs)
		elseif move ~= "enuma" or localTime <= WINDOW[1] then
			self.EaFrom, self.EaTurn = nil, nil
		end
		-- Ea and its drums show only inside a move's EaShown window (enuma): drawn from the vault otherwise. Written every hidden
		-- frame (4 parts), since Show's toggle makes every part visible again.
		local eaShown = Poses.EaShown(move, localTime)
		if not eaShown or eaShown ~= self.EaShown then
			self.EaShown = eaShown
			for i, row in him.Order do
				if row.Name == "Ea" or row.Parent == "Ea" then
					him.Parts[i].Transparency = eaShown and 0 or 1
				end
			end
		end
	end
end

-- Ea's tip (Poses.EaTip from the Ea joint) in the world, the beam's origin; with no rig a point at his chest over the mound.
function BossKing:Tip()
	local him = self.Him
	if him and him.Joints.Ea then
		return him:Point("Ea", Poses.EaTip)
	end
	return self.Rest.Position + Vector3.new(0, Arena.BossHeight * 0.85, 0)
end

return BossKing
