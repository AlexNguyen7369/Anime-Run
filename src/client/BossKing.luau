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
		-- locs: the legs' offsets move round the hip as his body turns (the beam sweep)
		local parts, root, locs = Poses.Sample(move, localTime)
		local below = (1 - rise) * (Arena.BossHeight + BossColosseum.VaultMoundTop)
		him:Pose(self.Rest - Vector3.new(0, below, 0), parts, root, 1, 0, locs)
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

-- Ea's tip (Poses.EaTip from the Ea joint) in the world, the beam's origin; with no rig a point at his chest over the heap.
function BossKing:Tip()
	local him = self.Him
	if him and him.Joints.Ea then
		return him:Point("Ea", Poses.EaTip)
	end
	return self.Rest.Position + Vector3.new(0, Arena.BossHeight * 0.85, 0)
end

return BossKing
