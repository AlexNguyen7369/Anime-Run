--!nonstrict
-- The merchants (WORLD_REDESIGN_SPEC 4.2, Shared/PlazaMerchants): a static roster rig at each MerchantSpot whose new stall is
-- uploaded, in its pose, behind one switch (PlazaPieces.MERCHANTS_LIVE, off). Scenery: anchored, no collision, touch or query.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PlazaMerchants = require(Shared.PlazaMerchants)
local PlazaPieces = require(Shared.PlazaPieces)
local RunnerFactory = require(Shared.RunnerFactory)

local PlazaMerchantRigs = {}

-- Service -> the piece its merchant stands in
local PIECE = {
	ShopStall = "SHOPStall",
	PotionsStall = "POTIONSStall",
	Marketplace = "MarketStall",
	IndexBoard = "IndexBoard",
	CheckpointNpc = "SenseiDais",
}

local function still(part)
	if part:IsA("BasePart") then
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
	end
end

-- Turns the rig's limbs about their joints, the rig standing at `root` (its Torso's frame) at model scale `scale`. A limb's later mesh takes
-- its CFrame over (RunnerFactory.Restyle).
local OFFSETS = {}
for _, row in RunnerFactory.PARTS do
	OFFSETS[row[1]] = row[3]
end
local function pose(rig, root, scale, limbs)
	for name, turn in limbs do
		local limb = rig:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			local joint = Vector3.new(0, (name == "Head" and -0.65 or 1) * RunnerFactory.SCALE * scale, 0)
			-- the draft's x, y, z are this frame's -X, Z, Y
			local spin = CFrame.Angles(0, math.rad(turn[3]), 0)
				* CFrame.Angles(0, 0, math.rad(turn[2]))
				* CFrame.Angles(math.rad(-turn[1]), 0, 0)
			limb.CFrame = root * CFrame.new(OFFSETS[name] * scale + joint) * spin * CFrame.new(-joint)
		end
	end
end

function PlazaMerchantRigs.Stand(spawnArea)
	if not PlazaPieces.MERCHANTS_LIVE then
		return
	end
	for name, row in PlazaMerchants do
		local service = spawnArea:FindFirstChild(name)
		local spot = service and service:FindFirstChild("MerchantSpot", true)
		if not spot or not PlazaPieces.Ready(PIECE[name]) or service:FindFirstChild("Merchant") then
			continue
		end
		local rig = RunnerFactory.build(row.Id)
		rig.Name = "Merchant"
		for _, d in rig:GetDescendants() do
			still(d)
		end
		rig.DescendantAdded:Connect(still) -- the model's meshes arrive later
		local scale = row.Scale / RunnerFactory.SCALE
		rig:ScaleTo(scale)
		local root = spot.WorldCFrame
			* CFrame.Angles(0, math.rad(row.Yaw or 0), 0)
			* CFrame.new(0, RunnerFactory.HIP_HEIGHT * scale, 0)
		rig:PivotTo(root)
		pose(rig, root, scale, row.Pose)
		rig.NameLabel.Enabled = not row.HideName
		rig.Parent = service
		local dummy = service:FindFirstChild("Rig") -- the sensei's
		if dummy then
			dummy:Destroy()
		end
	end
end

return PlazaMerchantRigs
