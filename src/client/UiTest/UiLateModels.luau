--!nonstrict
-- Models that arrive after CharacterModels is Ready (Client/LateModels; docs/OWNER_QUESTIONS.md "2026-11-24 w2-cast in game" item 1 (proposed)). Local fixture only: a
-- copy of a loaded character's folder is named after another world's character that nobody here has, empty at first, as
-- replication can deliver it. Contract: a rig this client built gets that character's meshes once the folder holds
-- its Parts; a rig without ClientRig is the server's to re-skin.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("CharacterModelAssets"))
local Catalog = require(Shared:WaitForChild("CharacterCatalog"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))
local WorldConfig = require(Shared:WaitForChild("WorldConfig"))

local READY_WAIT = 60 -- s
local APPLY_WAIT = 3 -- s
local STILL = 0.6 -- s a folder without its parts must change nothing
local FAR = CFrame.new(0, 5000, 0)
local SOURCE = "leaf_hero" -- a starter's model: loaded in every world

local Module = {}

local function meshes(rig)
	local n = 0
	for _, child in rig:GetChildren() do
		n += child:IsA("MeshPart") and 1 or 0
	end
	return n
end

function Module.Build(h)
	local scenarios = {}
	local function waitUntil(fn, seconds)
		local deadline = os.clock() + seconds
		while not fn() and os.clock() < deadline do
			task.wait(0.05)
		end
		return fn()
	end

	function scenarios.ui_late_models(res)
		local models = ReplicatedStorage:WaitForChild("CharacterModels")
		local ready = waitUntil(function()
			return models:GetAttribute("Ready") == true
		end, READY_WAIT)
		h.check(res, "models_ready", ready, true, ready == true)
		-- Another world's character drawn as its own model (no Model field: the id is the model). A save that owns
		-- every other-world character (a World 2 test save keeps its World 1 roster) has them all loaded: one folder
		-- is then held out locally for the test, as if it had not arrived yet, and put back after.
		local id, held
		for _, spec in Catalog.Rollable(3 - WorldConfig.Id) do
			if (spec.Model or spec.Id) == spec.Id and Assets[spec.Id] and spec.Id ~= SOURCE then
				local loaded = models:FindFirstChild(spec.Id)
				if not loaded then
					id, held = spec.Id, nil
					break
				end
				id, held = id or spec.Id, held or loaded
			end
		end
		local source = models:FindFirstChild(SOURCE)
		h.check(res, "other_world_id_not_loaded", id, "an id", id ~= nil)
		h.check(res, "source_model_loaded", source ~= nil, true, source ~= nil)
		if not (ready and id and source) then
			return
		end
		if held then
			held.Parent = nil
		end

		local made = {}
		local ok, err = pcall(function()
			local function rig(client)
				local model = RunnerFactory.build(id)
				table.insert(made, model)
				model:SetAttribute("ClientRig", client)
				model:PivotTo(FAR)
				model.Parent = workspace
				return model
			end
			local mine, servers = rig(true), rig(nil)
			local tagged = CollectionService:HasTag(mine, RunnerFactory.RIG_TAG)
			h.check(res, "rig_is_tagged", tagged, true, tagged)
			h.check(res, "placeholder_before", meshes(mine), 0, meshes(mine) == 0)

			local folder = Instance.new("Folder")
			table.insert(made, folder)
			folder.Name = id
			folder:SetAttribute("Parts", #source:GetChildren())
			folder.Parent = models
			task.wait(STILL)
			h.check(res, "waits_for_the_parts", meshes(mine), 0, meshes(mine) == 0)
			local copies = source:Clone()
			for _, part in copies:GetChildren() do
				part.Parent = folder
			end
			copies:Destroy()
			local want = #folder:GetChildren()
			waitUntil(function()
				return meshes(mine) == want
			end, APPLY_WAIT)
			h.check(res, "client_rig_restyled", meshes(mine), want, want > 0 and meshes(mine) == want)
			h.check(res, "server_rig_left_alone", meshes(servers), 0, meshes(servers) == 0)
			local name = mine:GetAttribute("CharacterId")
			h.check(res, "keeps_its_character", name, id, name == id)
		end)
		for _, instance in made do
			instance:Destroy()
		end
		if held then
			held.Parent = models
		end
		h.check(res, "no_error", ok and "none" or tostring(err), "none", ok)
	end

	return { Scenarios = scenarios }
end

return Module
