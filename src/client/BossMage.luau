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
-- segments (Server/CharacterModelService), posed from the jointed data: the upper arm, thigh and first tail segment drive the old
-- limb and tail, the forearms, shins and lower tail segments are not drawn, and the staff hangs from the upper arm a straight
-- forearm's length down, turned by the forearm and its own key. Drop with the upload.
local JOINTED = SidekickArt.boss_mage_jointed ~= nil
local function vector(list)
	return Vector3.new(list[1], list[2], list[3])
end
local HAND = vector(Poses.Bind.RightLowerArm.Offset) + vector(Poses.Bind.Staff.Offset)
local function angles(v)
	return CFrame.Angles(0, 0, math.rad(v.Z)) * CFrame.Angles(0, math.rad(v.Y), 0) * CFrame.Angles(math.rad(v.X), 0, 0)
end

local function sixPart(parts, locs)
	locs.Staff = HAND
	-- Z, then Y, then X (as BossRaga poses), back out of the forearm-and-staff turn: its inverse's XYZ angles, negated
	local x, y, z = (angles(parts.RightLowerArm) * angles(parts.Staff)):Inverse():ToEulerAnglesXYZ()
	parts.Staff = Vector3.new(-math.deg(x), -math.deg(y), -math.deg(z))
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
