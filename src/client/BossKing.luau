--!nonstrict
-- The Golden King (design doc 4.37 "Third boss", docs/BOSS_EVENT_SPEC.md "The Golden King"): one Client/BossRaga rig from
-- ReplicatedStorage.BossModels (boss_king), posed every frame from BossKingPoses. He stands on the vault's gold heap at the centre
-- (Client/BossColosseum.VaultMoundTop), no hover, no bob, facing as Big Raga does. Ea and the Key are parts of the bind, so the
-- bake's drum spin plays as pose data. Entrance (an open question in the spec): he rises through the heap over RiseSeconds as Big
-- Raga does, until the owner rules. Until the bake lands, BossKingPoses is the k7 stub (Moves, CycleSeconds and Schedule, no Bind
-- or Sample): then no rig is made and Step draws nothing. With no module at all, Poses is nil and the arena view skips his schedule.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig")).For("boss_king")
local BossCatalog = require(Shared:WaitForChild("BossCatalog"))
local posesModule = Shared:FindFirstChild("BossKingPoses")
local Poses = posesModule and require(posesModule) or nil
local BossColosseum = require(script.Parent:WaitForChild("BossColosseum"))
local BossRaga = require(script.Parent:WaitForChild("BossRaga"))

local BossKing = {}
BossKing.__index = BossKing
BossKing.Poses = Poses -- nil until Shared/BossKingPoses exists

function BossKing.new(parent)
	local self = setmetatable({}, BossKing)
	self.Rest = CFrame.new(Arena.Center.X, Arena.Y + BossColosseum.VaultMoundTop, Arena.Center.Z)
	if not (Poses and Poses.Bind and Poses.Sample) then
		warn("[BossKing] BossKingPoses has no keys yet: no rig")
		return self
	end
	self.Him = BossRaga.new(parent, {
		Poses = Poses,
		Source = "boss_king",
		Name = BossCatalog.Get("boss_king").ModelName,
		Scale = Poses.Scale,
		SizeScale = 1,
		RootScale = 1, -- Sample's root is studs, as the mage's
	})
	self.Him.Anchor = self.Rest
	return self
end

-- rise: nil before the spawn (hidden), then 0 to 1 as he comes up through the heap. move, localTime: Poses.Schedule's.
function BossKing:Step(rise, move, localTime)
	local him = self.Him
	if him and him.Parts and him:Show(rise ~= nil) then
		local parts, root = Poses.Sample(move, localTime)
		local below = (1 - rise) * (Arena.BossHeight + BossColosseum.VaultMoundTop)
		him:Pose(self.Rest - Vector3.new(0, below, 0), parts, root, 1, 0)
	end
end

-- A joint's world CFrame for the effects. With no rig, or a joint the bind lacks, a frame at his chest over the heap.
function BossKing:Frame(name)
	local him = self.Him
	if him and him.Joints[name] then
		return him:Frame(name)
	end
	return self.Rest + Vector3.new(0, Arena.BossHeight * 0.7, 0)
end

return BossKing
