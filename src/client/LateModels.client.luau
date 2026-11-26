--!nonstrict
-- A character of another world loads after CharacterModels is Ready (Server/CharacterModelService). Rigs this client built
-- before it arrived (panels, boss team, HUD) are placeholders: re-skin them in place once its parts are here.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))

local PARTS_WAIT = 10 -- seconds for a late folder's parts to replicate

local models = ReplicatedStorage:WaitForChild("CharacterModels")

models.ChildAdded:Connect(function(folder)
	if models:GetAttribute("Ready") ~= true then
		return -- the panels rebuild on Ready
	end
	local deadline = os.clock() + PARTS_WAIT
	while #folder:GetChildren() < (folder:GetAttribute("Parts") or 1) and os.clock() < deadline do
		task.wait(0.1)
	end
	for _, rig in CollectionService:GetTagged(RunnerFactory.RIG_TAG) do
		local id = rig:GetAttribute("ClientRig") and rig:GetAttribute("CharacterId")
		local spec = id and CharacterCatalog.Get(id)
		if id and (spec and spec.Model or id) == folder.Name then
			RunnerFactory.Restyle(rig, id)
		end
	end
end)
