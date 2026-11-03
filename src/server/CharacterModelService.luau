--!nonstrict
-- Loads the uploaded runner models (docs/CHARACTER_GACHA_SPEC.md "Avatar pipeline") into
-- ReplicatedStorage.CharacterModels/<id>/<part> so RunnerFactory can clone them on server and clients. Runs in the
-- background: rigs built before it finishes (runners, Dojo squad, Best Roll) are placeholders and get re-skinned at
-- the end. A failed load only leaves that character on the placeholder rig. The root's Ready attribute turns true
-- when done.
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.CharacterModelAssets)
local RunnerFactory = require(Shared.RunnerFactory)

local CharacterModelService = {}

local function load(id, row, root)
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(row.Asset)
	end)
	if not ok then
		warn("[CharacterModels] " .. id .. " failed to load, using the placeholder rig: " .. tostring(asset))
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = id
	for _, d in asset:GetDescendants() do
		if d:IsA("MeshPart") and row.Sizes[d.Name] then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.Material = Enum.Material.SmoothPlastic
			d.Size = row.Sizes[d.Name]
			d.Parent = folder
		end
	end
	asset:Destroy()
	folder.Parent = root
end

function CharacterModelService.Start()
	local root = Instance.new("Folder")
	root.Name = "CharacterModels"
	root.Parent = ReplicatedStorage
	task.spawn(function()
		for id, row in Assets do
			load(id, row, root)
		end
		for _, rig in CollectionService:GetTagged(RunnerFactory.RIG_TAG) do
			local id = rig:GetAttribute("CharacterId")
			if id and RunnerFactory.HasModel(id) then -- the others keep their look (an NPC's own colour)
				RunnerFactory.Restyle(rig, id)
			end
		end
		root:SetAttribute("Ready", true)
	end)
end

return CharacterModelService
