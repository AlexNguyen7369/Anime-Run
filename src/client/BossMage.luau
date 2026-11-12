--!nonstrict
-- The Elf Mage and her golem (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"): two Client/BossRaga rigs from
-- ReplicatedStorage.BossModels (boss_mage, boss_golem), posed every frame from BossMagePoses. She hovers HoverStuds over the arena
-- floor at its centre, facing as Big Raga does; the idle bob (BobStuds over BobSeconds, not keyed) is added here. Her rig has elbows,
-- knees and 3-segment tails (design doc 4.37 "Animation rework"). Her entrance lowers her from the broken dome. The golem stands at GolemAnchor from her rest feet and shows only while its track's scale is above 0: while a
-- golem stands (BossMinionStart) and during her golem_fall row.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig")).For("boss_mage")
-- design doc 7: required only while her event or preview shows, so it waits for her poses alone
local Poses =
	require(Shared:WaitForChild("LateData")).Get(require(Shared:WaitForChild("BossCatalog")).Get("boss_mage").Poses)
local BossRaga = require(script.Parent:WaitForChild("BossRaga"))
local SidekickArt = require(Shared:WaitForChild("SidekickArt"))

local C = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0)) -- Blender to Roblox
local DESCENT = 110 -- proposed: studs above her hover at the entrance's start, her head inside the dome's opening

-- shortcut: the jointed model (SidekickArt.boss_mage_jointed.BossModel, from build/avatar_glb/boss_mage_jointed.glb) is not uploaded
-- yet. Until it is, ReplicatedStorage.BossModels.boss_mage is the 6-part model on Poses.Bind6, its parts named after the upper
-- segments (Server/CharacterModelService), posed from the jointed data: each whole old arm, leg and tail keeps its first segment's
-- twist and is aimed from its joint at where the jointed chain ends (the wrist, the sole, the third tail segment's tip), and the
-- staff sits on the jointed hand with its jointed turn. Drop with the upload.
local JOINTED = SidekickArt.boss_mage_jointed ~= nil
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

-- old part (named as its first segment) -> { the jointed chain, its end from the last joint (units) }: the wrist (the staff's
-- grip), the sole (the floor at rest), the tail's tip (twice its last segment's box centre).
local CHAINS = {}
if Poses and Poses.Bind then
	local bind = Poses.Bind
	for _, side in { "Left", "Right" } do
		CHAINS[side .. "UpperArm"] = { { side .. "UpperArm", side .. "LowerArm" }, vector(bind.Staff.Offset) }
		local sole = bind[side .. "UpperLeg"].Offset[3] + bind[side .. "LowerLeg"].Offset[3]
		CHAINS[side .. "UpperLeg"] = { { side .. "UpperLeg", side .. "LowerLeg" }, Vector3.new(0, 0, -sole) }
	end
	for _, side in { "L", "R" } do
		CHAINS["Tail" .. side .. "1"] = {
			{ "Tail" .. side .. "1", "Tail" .. side .. "2", "Tail" .. side .. "3" },
			2 * vector(bind["Tail" .. side .. "3"].Center),
		}
	end
end

-- The first segment's turn swung so the old part's rest line (its chain unbent) points at the posed chain's end.
local function aimed(parts, chain)
	local names, reach, rest = chain[1], chain[2], chain[2]
	for i = #names, 2, -1 do
		local offset = vector(Poses.Bind[names[i]].Offset)
		reach = offset + angles(parts[names[i]]):VectorToWorldSpace(reach)
		rest += offset
	end
	local first = angles(parts[names[1]])
	reach, rest = first:VectorToWorldSpace(reach), first:VectorToWorldSpace(rest)
	local axis = rest:Cross(reach)
	local swing = axis.Magnitude > 1e-6 and CFrame.fromAxisAngle(axis.Unit, math.atan2(axis.Magnitude, rest:Dot(reach)))
		or CFrame.identity
	return swing * first, first
end

local function sixPart(parts, locs)
	local staff = parts.Staff
	for old, chain in CHAINS do
		local limb, first = aimed(parts, chain)
		parts[old] = degrees(limb)
		if old == "RightUpperArm" then -- the staff on the jointed hand: through the forearm, seen from the aimed arm
			local turn, forearm = limb:Inverse() * first, angles(parts.RightLowerArm)
			locs.Staff = turn:VectorToWorldSpace(
				vector(Poses.Bind.RightLowerArm.Offset) + forearm:VectorToWorldSpace(vector(Poses.Bind.Staff.Offset))
			)
			parts.Staff = degrees(turn * forearm * angles(staff))
		end
	end
	return parts, locs
end

local BossMage = {}
BossMage.__index = BossMage

function BossMage.new(parent)
	local self = setmetatable({}, BossMage)
	self.Her = BossRaga.new(parent, {
		Poses = Poses,
		Source = "boss_mage",
		Bind = JOINTED and Poses.Bind or Poses.Bind6,
		Name = "ElfMage",
		Scale = Poses.Scale,
		SizeScale = 1,
		RootScale = 1, -- Sample's root is studs
	})
	self.Golem = BossRaga.new(parent, {
		Poses = Poses,
		Bind = Poses.GolemBind,
		Source = "boss_golem",
		Name = "Golem",
		Scale = Poses.GolemScale,
		SizeScale = 1,
	})
	self.Rest = CFrame.new(Arena.Center.X, Arena.Y + Poses.HoverStuds, Arena.Center.Z)
	self.GolemRest = self.Rest
		* C
		* CFrame.new(Poses.GolemAnchor)
		* CFrame.Angles(0, 0, math.rad(Poses.GolemYaw))
		* C:Inverse()
	self.Her.Anchor = self.Rest
	self.Golem.Anchor = self.GolemRest
	return self
end

-- rise: nil before the spawn (hidden), then 0 to 1 as she comes down. move, localTime: her move (Schedule's or GolemAt's);
-- golemMove, golemTime: the golem's (GolemAt's, or her move while no golem stands).
function BossMage:Step(rise, move, localTime, _now, golemMove, golemTime)
	local her = self.Her
	if her.Parts and her:Show(rise ~= nil) then
		local parts, root, locs = Poses.Sample(move, localTime)
		if move == "idle" then -- every idle row plays whole 3 s loops from 0, so the bob starts and ends at rest
			root += Vector3.new(0, 0, Arena.BobStuds * (1 - math.cos(2 * math.pi * localTime / Arena.BobSeconds)) / 2)
		end
		if not JOINTED then
			parts, locs = sixPart(parts, locs)
		end
		her:Pose(self.Rest + Vector3.new(0, (1 - rise) * DESCENT, 0), parts, root, 1, 0, locs)
	end
	local golem = self.Golem
	if golem.Parts then
		local scale, parts, locs, root = 0, nil, nil, nil
		if rise ~= nil and golemMove then
			scale, parts, locs, root = Poses.SampleGolem(golemMove, golemTime)
		end
		if golem:Show(scale > 0) then
			golem:Pose(self.GolemRest, parts, root, 1, 0, locs, scale)
		end
	end
end

-- Her joint's world CFrame, and a point on her part in units from its joint (Blender axes), for the effects.
function BossMage:Frame(name)
	return self.Her:Frame(name)
end

function BossMage:Point(name, units)
	return self.Her:Point(name, units)
end

-- The golem's joint's world CFrame; its rest root while it is not posed.
function BossMage:GolemFrame(name)
	return self.Golem:Frame(name)
end

return BossMage
