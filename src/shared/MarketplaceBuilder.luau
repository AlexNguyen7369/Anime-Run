--!nonstrict
-- The Market: only the Aura stall of the Blender marketplace (docs/WORLD_REDESIGN_SPEC.md section 7). Smooth box
-- boundaries keep its detailed displays from snagging players.
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MeshAssets = require(script.Parent.MarketplaceMeshAssets)

local template = ReplicatedStorage:WaitForChild("SpawnMarketplace"):Clone()
for _, mesh in template:GetDescendants() do
	if mesh:IsA("MeshPart") and not mesh.Name:match("^Aura_") then
		mesh:Destroy() -- the template still holds the removed courtyard: never load it
	elseif mesh:IsA("MeshPart") then
		local assetId = MeshAssets[mesh.Name]
		assert(assetId, "Missing marketplace mesh asset: " .. mesh.Name)
		if mesh.MeshId ~= assetId or mesh.MeshSize.Magnitude == 0 then
			local texture = mesh.TextureID
			local loaded = AssetService:CreateMeshPartAsync(Content.fromUri(assetId), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
			})
			mesh:ApplyMesh(loaded)
			mesh.TextureID = texture
			loaded:Destroy()
		end
		assert(mesh.MeshId == assetId and mesh.MeshSize.Magnitude > 0, "Marketplace mesh failed to load: " .. mesh.Name)
	end
end

local MarketplaceBuilder = {}
-- Local to world: ROTATION 90 sends local +Z to hub +x and local +X to hub -z, so hub (x, z) = CENTER + (local z, -local x).
-- The Aura meshes span local x -23.13 to -10.87 (centre -17) and z -17 to -0.65 at the sign board, 6.5 at the crate.
-- CENTER.X: local z -0.3 (the MarketSign's plane, just in front of that board) lands on hub x 46 (world -72).
-- CENTER.Y: local x -17 lands on hub z -92.5 (world -12.5, the row's Market spot).
MarketplaceBuilder.CENTER = Vector2.new(46.3, -109.5)
MarketplaceBuilder.ROTATION = 90 -- entrance (+Z) faces +x, as the rest of the service row
local COUNTER = Vector3.new(-17, 0, -3)

local function box(parent, name, size, cf, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = collide
	p.CanTouch = false
	p.CanQuery = collide
	p.CastShadow = false
	p.Parent = parent
	return p
end

function MarketplaceBuilder.Build(placement)
	local model = Instance.new("Model")
	model.Name = "Marketplace"
	local visual = template:Clone()
	for _, mesh in visual:GetChildren() do
		if mesh:IsA("BasePart") then
			mesh.CFrame = placement * mesh.CFrame
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanTouch = false
			mesh.CanQuery = false
			mesh.CastShadow = false
			if mesh:IsA("MeshPart") then
				mesh.DoubleSided = true
			end
			mesh.Parent = model
		end
	end
	visual:Destroy()
	local boundaries = Instance.new("Folder")
	boundaries.Name = "CollisionBoundaries"
	boundaries.Parent = model
	local function boundary(name, size, pos)
		return box(boundaries, name, size, placement * CFrame.new(pos), true)
	end
	local floor = boundary("WalkSurface", Vector3.new(12.4, 0.2, 23.8), Vector3.new(-17, 0.1, -5.2))
	model.PrimaryPart = floor
	boundary("BackWall", Vector3.new(11, 10, 0.8), Vector3.new(-17, 5.2, -16.5))
	boundary("Counter", Vector3.new(9.5, 4.2, 3), COUNTER + Vector3.new(0, 2.1, 0))
	boundary("FrontDisplay", Vector3.new(5.2, 3.6, 3.2), Vector3.new(-19, 1.8, 5))
	for _, x in { -22, -12 } do
		for _, z in { -16, -2 } do
			boundary("Post_" .. x .. "_" .. z, Vector3.new(1.5, 11.2, 1.5), Vector3.new(x, 5.8, z))
		end
	end
	local anchor = box(
		model,
		"PromptAnchor",
		Vector3.new(1, 1, 1),
		placement * CFrame.new(COUNTER + Vector3.new(0, 4.5, 1.7)),
		false
	)
	CollectionService:AddTag(anchor, "MarketPad")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenMarket"
	prompt.ActionText = "Browse Market"
	prompt.ObjectText = "Market"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	local mount = Instance.new("Attachment") -- an attachment, not a part: the plaza keeps few parts
	mount.Name = "LanternMount"
	mount.Parent = floor
	mount.WorldCFrame = placement * CFrame.new(-17, 8, -4)
	local light = Instance.new("PointLight")
	light.Name = "WarmLantern"
	light.Color = Color3.fromRGB(255, 201, 117)
	light.Brightness = 1.4
	light.Range = 14
	light.Shadows = false
	light.Parent = mount
	return model
end

return MarketplaceBuilder
