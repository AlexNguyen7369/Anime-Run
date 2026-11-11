--!nonstrict
-- The Elf Mage and her golem (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"): two Client/BossRaga rigs from
-- ReplicatedStorage.BossModels (boss_mage, boss_golem), posed every frame from BossMagePoses. She hovers HoverStuds over the arena
-- floor at its centre, facing as Big Raga does; the idle bob is in the pose data's root. Her entrance lowers her from the broken
-- dome. The golem stands at GolemAnchor from her rest feet and shows only while its track's scale is above 0: while a
-- golem stands (BossMinionStart) and during her golem_fall row.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig")).For("boss_mage")
local Poses = require(Shared:WaitForChild("BossMagePoses"))
local BossRaga = require(script.Parent:WaitForChild("BossRaga"))

local C = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0)) -- Blender to Roblox
local DESCENT = 110 -- proposed: studs above her hover at the entrance's start, her head inside the dome's opening

local BossMage = {}
BossMage.__index = BossMage

function BossMage.new(parent)
	local self = setmetatable({}, BossMage)
	self.Her = BossRaga.new(parent, {
		Poses = Poses,
		Source = "boss_mage",
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
		local parts, root = Poses.Sample(move, localTime)
		her:Pose(self.Rest + Vector3.new(0, (1 - rise) * DESCENT, 0), parts, root, 1, 0)
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
