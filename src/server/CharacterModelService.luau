--!nonstrict
-- Loads the uploaded runner models (docs/CHARACTER_GACHA_SPEC.md "Avatar pipeline") into
-- ReplicatedStorage.CharacterModels/<id>/<part> so RunnerFactory can clone them on server and clients. Runs in the
-- background: rigs built before it finishes (runners, Dojo squad, Best Roll) are placeholders and get re-skinned at
-- the end. A failed load only leaves that character on the placeholder rig. The root's Ready attribute turns true
-- when done; its Loaded_<id> attribute turns true as each character finishes (loaded or failed), for the loading screen.
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.CharacterModelAssets)
local BossMagePoses = require(Shared.BossMagePoses)
local BossRagaPoses = require(Shared.BossRagaPoses)
local RunnerFactory = require(Shared.RunnerFactory)
local SidekickArt = require(Shared.SidekickArt)

local CharacterModelService = {}

local NEON_BLUE = Color3.fromRGB(82, 216, 250) -- side_wyvern's "glow" ramp (tools/blender/build_boss_event.py)

local function fetch(assetId)
	-- LoadAsset needs the assets' owner in Studio, so collaborators load a copy saved in the place (named by asset id)
	local baked = ServerStorage:FindFirstChild("BakedModels")
	local copy = baked and baked:FindFirstChild(tostring(assetId))
	if copy then
		return true, copy:Clone()
	end
	local ok, asset
	for attempt = 1, 3 do -- all load at once, so a throttled request gets another try
		ok, asset = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	return ok, asset
end

local function load(id, row, root)
	local ok, asset = fetch(row.Asset)
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
			d.Size = row.Sizes[d.Name] * RunnerFactory.SCALE
			d.Parent = folder
		end
	end
	asset:Destroy()
	folder.Parent = root
end

-- A Sidekick's whole Model, in ReplicatedStorage.SidekickModels/<id> (docs/SIDEKICK_SPEC.md). It keeps its authored layout,
-- unlike a runner's parts, and meshes named *Neon* get Material Neon (docs/char_evidence/side_wyvern.md).
local function loadSidekick(id, assetId, root)
	local ok, asset = fetch(assetId)
	if not ok then
		warn("[SidekickModels] " .. id .. " failed to load: " .. tostring(asset))
		return
	end
	local model = asset:FindFirstChildOfClass("Model") or asset
	model.Name = id
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			if string.find(d.Name, "Neon", 1, true) then
				-- The import gives every part a grey SurfaceAppearance, which overrides Color on an untextured mesh.
				local surface = d:FindFirstChildOfClass("SurfaceAppearance")
				if surface then
					surface:Destroy()
				end
				d.Material = Enum.Material.Neon
				d.Color = NEON_BLUE
			end
		end
	end
	model.Parent = root
	if model ~= asset then
		asset:Destroy()
	end
end

local function startSidekicks()
	local root = Instance.new("Folder")
	root.Name = "SidekickModels"
	root.Parent = ReplicatedStorage
	task.spawn(function()
		local pending = 0
		for id, art in SidekickArt do
			if art.Model then
				pending += 1
				task.spawn(function()
					pcall(loadSidekick, id, art.Model, root)
					pending -= 1
				end)
			end
		end
		while pending > 0 do
			task.wait()
		end
		root:SetAttribute("Ready", true)
	end)
end

-- A boss's loose parts, in ReplicatedStorage.BossModels/<name>, at their game size (docs/BOSS_EVENT_SPEC.md "Boss and attacks",
-- "The Elf Mage"). Each client clones and poses them. Its parts keep the import's SurfaceAppearance: it holds the texture.
local function loadBoss(name, assetId, binds, root)
	local ok, asset = fetch(assetId)
	if not ok then
		warn("[BossModels] " .. name .. " failed to load: " .. tostring(asset))
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	for _, d in asset:GetDescendants() do
		local bind = d:IsA("MeshPart") and binds[d.Name]
		if bind then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.Material = Enum.Material.SmoothPlastic
			d.Size = Vector3.new(bind.Size[1], bind.Size[2], bind.Size[3])
			d.Parent = folder
		end
	end
	asset:Destroy()
	folder.Parent = root
end

local function startBoss()
	local root = Instance.new("Folder")
	root.Name = "BossModels"
	root.Parent = ReplicatedStorage
	task.spawn(function()
		for name, bind in
			{ boss_raga = BossRagaPoses.Bind, boss_mage = BossMagePoses.Bind, boss_golem = BossMagePoses.GolemBind }
		do
			local art = SidekickArt[name]
			if art and art.BossModel then
				pcall(loadBoss, name, art.BossModel, bind, root)
			end
		end
		root:SetAttribute("Ready", true)
	end)
end

function CharacterModelService.Start()
	startSidekicks()
	startBoss()
	local root = Instance.new("Folder")
	root.Name = "CharacterModels"
	root.Parent = ReplicatedStorage
	task.spawn(function()
		-- All at once: 30 one after another held a fresh server's loading screen for seconds (design doc 4.24)
		local pending = 0
		for id, row in Assets do
			pending += 1
			task.spawn(function()
				pcall(load, id, row, root)
				root:SetAttribute("Loaded_" .. id, true)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
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
