--!nonstrict
-- The merchants (WORLD_REDESIGN_SPEC 4.2, Shared/PlazaMerchants): a static roster rig at each MerchantSpot whose new stall is
-- uploaded, behind one switch (PlazaPieces.MERCHANTS_LIVE, off). No poses yet. Scenery: anchored, no collision, touch or query.
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
		rig:PivotTo(spot.WorldCFrame * CFrame.new(0, RunnerFactory.HIP_HEIGHT * scale, 0))
		rig.Parent = service
		local dummy = service:FindFirstChild("Rig") -- the sensei's
		if dummy then
			dummy:Destroy()
		end
	end
end

return PlazaMerchantRigs
