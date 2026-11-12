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
local SidekickArt = require(Shared:WaitForChild("SidekickArt"))

-- shortcut: the jointed model (SidekickArt.boss_king_jointed.BossModel, from build/avatar_glb/boss_king_jointed.glb) is not uploaded
-- yet. Until it is, ReplicatedStorage.BossModels.boss_king is the 6-part model (SidekickArt.boss_king.BossModel, Poses.Bind6;
-- Server/CharacterModelService picks the same) posed from the jointed data: each whole old limb keeps its upper segment's twist and
-- is aimed from its shoulder or hip at where the jointed chain's end lands (the wrist, the sole), and Ea sits on the jointed hand
-- with its jointed turn. Drop with the upload.
local JOINTED = SidekickArt.boss_king_jointed ~= nil

local function vector(list)
	return Vector3.new(list[1], list[2], list[3])
end

-- XYZ Euler degrees as BossRaga:Pose builds them (Z, then Y, then X), and back.
local function angles(v)
	return CFrame.Angles(0, 0, math.rad(v.Z)) * CFrame.Angles(0, math.rad(v.Y), 0) * CFrame.Angles(math.rad(v.X), 0, 0)
end

local function degrees(frame)
	local _, _, _, r00, _, _, r10, _, _, r20, r21, r22 = frame:GetComponents()
	return Vector3.new(
		math.deg(math.atan2(r21, r22)),
		math.deg(math.asin(math.clamp(-r20, -1, 1))),
		math.deg(math.atan2(r10, r00))
	)
end

-- old limb -> { upper, lower, the chain's end from the lower joint (units): the wrist (Ea's grip) or the sole (the floor at rest) }
local LIMBS = {}
if Poses and Poses.Bind then
	local bind = Poses.Bind
	for _, side in { "Left", "Right" } do
		LIMBS[side .. "Arm"] = { side .. "UpperArm", side .. "LowerArm", vector(bind.Ea.Offset) }
		local sole = bind[side .. "UpperLeg"].Offset[3] + bind[side .. "LowerLeg"].Offset[3]
		LIMBS[side .. "Leg"] = { side .. "UpperLeg", side .. "LowerLeg", Vector3.new(0, 0, -sole) }
	end
end

-- The upper segment's turn swung so the straight limb (rest: lower offset + end, straight down) points at the bent chain's end.
local function aimed(parts, row)
	local r1, r2 = angles(parts[row[1]]), angles(parts[row[2]])
	local bend = vector(Poses.Bind[row[2]].Offset)
	local reach = r1:VectorToWorldSpace(bend + r2:VectorToWorldSpace(row[3]))
	local rest = r1:VectorToWorldSpace(bend + row[3])
	local axis = rest:Cross(reach)
	local swing = axis.Magnitude > 1e-6 and CFrame.fromAxisAngle(axis.Unit, math.atan2(axis.Magnitude, rest:Dot(reach)))
		or CFrame.identity
	return swing * r1, r1, r2
end

local function sixPart(parts, locs)
	local ea, eaAt = parts.Ea, locs.Ea
	for old, row in LIMBS do
		local limb, r1, r2 = aimed(parts, row)
		parts[old], locs[old] = degrees(limb), locs[row[1]]
		if old == "RightArm" then -- Ea on the jointed hand: through the forearm, seen from the aimed arm
			local turn = limb:Inverse() * r1
			locs.Ea = turn:VectorToWorldSpace(vector(Poses.Bind.RightLowerArm.Offset) + r2:VectorToWorldSpace(eaAt))
			parts.Ea = degrees(turn * r2 * angles(ea))
		end
	end
	return parts, locs
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
		Bind = JOINTED and Poses.Bind or Poses.Bind6,
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
		if not JOINTED then
			parts, locs = sixPart(parts, locs)
		end
		local below = (1 - rise) * (Arena.BossHeight + Arena.HoverY)
		local bob = Arena.BobStuds / 2 * math.sin(Workspace:GetServerTimeNow() * 2 * math.pi / Arena.BobSeconds)
		him:Pose(self.Rest - Vector3.new(0, below - bob, 0), parts, root, 1, 0, locs)
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
