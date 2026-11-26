--!nonstrict
-- The merchants (WORLD_REDESIGN_SPEC 4.2, Shared/PlazaMerchants): a static roster rig at each MerchantSpot whose new stall is
-- uploaded, in its pose, behind one switch (PlazaPieces.MERCHANTS_LIVE, on: owner 2026-11-25). Scenery: anchored, no collision, touch or query.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PlazaMerchants = require(Shared.PlazaMerchants)
local PlazaPieces = require(Shared.PlazaPieces)
local RunnerFactory = require(Shared.RunnerFactory)

local PlazaMerchantRigs = {}

-- The floating name (owner 2026-11-25: shown, but Kakashe's; "Readable from spawn": as large as it can be without covering its stall's
-- sign or header) never covers the stall's sign, from the spawn or close by (docs/BUGS.md merchant-names-cover-signs): studs, not pixels,
-- so it does not grow on screen with distance; on an attachment over the merchant's hair (or in front of it: Bottom), not the head, so it
-- stands where the marker says. Height: the largest, in 0.05 studs, that keeps every view of the sign clear (PlazaPiecesTests merchant_name_clear_*); Forward:
-- studs toward the stall's front, where it lets the name grow. Proposed values.
PlazaMerchantRigs.NAMES = {
	ShopStall = { Height = 1.7, Forward = 1.5 },
	PotionsStall = { Height = 1.9, Forward = 1 },
	-- Its sign is 1.29 studs over Rengoko's hair: owner 2026-11-26 "Readable, rare overlap" (the same readable size as the others,
	-- may touch the sign only from high side views near the stall). Lower, its bottom (studs over the feet at Scale 1) in front of
	-- the top of the hair, 2.25 studs forward where the hair (at most 0.98 forward) stays behind it.
	Marketplace = { Height = 1.75, Forward = 2.25, Bottom = 5.65 },
	IndexBoard = { Height = 1.8, Forward = 0 },
}
PlazaMerchantRigs.NAME_CHAR_WIDTH = 0.62 -- a letter's width over the name's height (FredokaOne, TextScaled)
PlazaMerchantRigs.NAME_OVER_HAIR = 0.15 -- studs from the hair's top to the name's bottom
-- The top of each model's hair, studs over the feet at Scale 1 (the head's centre is 5): measured from the built meshes
-- (draft_merchants.py load(), 2026-11-26), rounded up
PlazaMerchantRigs.HAIR_TOP = {
	sea_navigator = 6.24,
	leaf_medic = 6.49,
	ds_flame = 6.96,
	fr_mage = 6.24,
	leaf_copycat = 7.34,
}

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
		local label = rig.NameLabel
		label.Enabled = not row.HideName
		local nameSpot = Instance.new("Attachment")
		nameSpot.Name = "NameSpot"
		nameSpot.Parent = spot.Parent
		local look = PlazaMerchantRigs.NAMES[name] or { Height = 1, Forward = 0 }
		local text = label:FindFirstChild("Name")
		local h = look.Height
		local w = h * PlazaMerchantRigs.NAME_CHAR_WIDTH * math.max(#(text and text.Text or ""), 4)
		local bottom = look.Bottom and look.Bottom * row.Scale
			or (PlazaMerchantRigs.HAIR_TOP[row.Id] or 7.4) * row.Scale + PlazaMerchantRigs.NAME_OVER_HAIR
		nameSpot.WorldCFrame = spot.WorldCFrame * CFrame.new(0, bottom + h / 2, -look.Forward)
		label.Adornee = nameSpot
		label.Size = UDim2.fromScale(w, h)
		label.StudsOffset = Vector3.zero
		label.StudsOffsetWorldSpace = Vector3.zero
		rig.Parent = service
		local dummy = service:FindFirstChild("Rig") -- the sensei's
		if dummy then
			dummy:Destroy()
		end
	end
end

return PlazaMerchantRigs
