--!nonstrict
-- Loads the uploaded runner models (docs/CHARACTER_GACHA_SPEC.md "Avatar pipeline") into
-- ReplicatedStorage.CharacterModels/<id>/<part> so RunnerFactory can clone them on server and clients. Runs in the
-- background: rigs built before it finishes (runners, Best Roll) are placeholders and get re-skinned at
-- the end. A failed load only leaves that character on the placeholder rig. The root's Ready attribute turns true
-- when done; its Loaded_<id> attribute turns true as each character finishes (loaded or failed), for the loading screen.
-- Only this world's cast loads at start (design doc 4.47, owner 2026-11-24). Another world's character or Sidekick loads once, when a player in
-- this server owns it or a rig wears it.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.CharacterModelAssets)
local BossKingPoses = require(Shared.LateData).Get("BossKingPoses")
local BossMagePoses = require(Shared.LateData).Get("BossMagePoses")
local BossRagaPoses = require(Shared.LateData).Get("BossRagaPoses")
local CharacterCatalog = require(Shared.CharacterCatalog)
local RunnerFactory = require(Shared.RunnerFactory)
local SidekickArt = require(Shared.SidekickArt)
local SidekickConfig = require(Shared.SidekickConfig)
local WorldConfig = require(Shared.WorldConfig)

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
	folder:SetAttribute("Parts", #folder:GetChildren()) -- a client may see the folder before its parts
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

-- The models every world shows: the exclusive runner's, and those worn by a runner with no world of its own.
local shared = { [CharacterCatalog.EXCLUSIVE_ID] = true }
for _, id in { CharacterCatalog.KAMI_ID, table.unpack(CharacterCatalog.STARTER_PICKS) } do
	shared[CharacterCatalog.Get(id).Model] = true
end

-- True if character model `id` loads when a world's server (default: this one's) starts. Enemy-only models have no spec.
function CharacterModelService.Eager(id, world)
	local spec = CharacterCatalog.Get(id)
	return shared[id] == true or spec == nil or spec.World == nil or spec.World == (world or WorldConfig.Id)
end

-- The same for a Sidekick: a world's own set, and the boss drops, which every world has.
function CharacterModelService.EagerSidekick(id, world)
	for other, list in SidekickConfig.Lists do
		if other ~= (world or WorldConfig.Id) then
			for _, row in list do
				if row.Id == id then
					return false
				end
			end
		end
	end
	return true
end

local requestedSidekicks = {} -- id -> true once its load started

local function startSidekicks()
	local root = Instance.new("Folder")
	root.Name = "SidekickModels"
	root.Parent = ReplicatedStorage
	task.spawn(function()
		local pending = 0
		for id, art in SidekickArt do
			if art.Model and CharacterModelService.EagerSidekick(id) then
				requestedSidekicks[id] = true
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
	return root
end

-- A boss's loose parts, in ReplicatedStorage.BossModels/<name>, at their game size (docs/BOSS_EVENT_SPEC.md "Boss and attacks",
-- "The Elf Mage"). Each client clones and poses them. Big Raga's parts keep the import's SurfaceAppearance; the golem's draw TextureID.
local function loadBoss(name, assetId, binds, root)
	local ok, asset = fetch(assetId)
	if not ok then
		warn("[BossModels] " .. name .. " failed to load: " .. tostring(asset))
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	local texture = ""
	local names = {} -- the upload's part name -> its bind name (a bind row's Mesh, when it stands in for another part)
	for partName, row in binds do
		names[row.Mesh or partName] = partName
	end
	for _, d in asset:GetDescendants() do
		local partName = d:IsA("MeshPart") and names[d.Name]
		local bind = partName and binds[partName]
		if bind then
			d.Name = partName
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.Material = Enum.Material.SmoothPlastic
			d.Size = Vector3.new(bind.Size[1], bind.Size[2], bind.Size[3])
			-- The golem import put one stray SurfaceAppearance on FistL, its EmissiveMap rbxassetid://17 never loads (a script
			-- cannot read its ColorMap): drop it, and the part takes the one atlas its siblings use.
			-- Golem only: Big Raga's parts keep the import's SurfaceAppearance, it holds his texture.
			local surface = name == "boss_golem" and d:FindFirstChildOfClass("SurfaceAppearance")
			if surface then
				surface:Destroy()
			end
			if d.TextureID ~= "" then
				texture = d.TextureID
			end
			d.Parent = folder
		end
	end
	if name == "boss_golem" then
		for _, part in folder:GetChildren() do
			if part.TextureID == "" then
				part.TextureID = texture
			end
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
			{
				boss_raga = BossRagaPoses.Bind,
				boss_mage = BossMagePoses.Bind,
				boss_golem = BossMagePoses.GolemBind,
				boss_king = BossKingPoses.Bind,
			}
		do
			-- the bosses' jointed uploads, not the old 6-part ones (still in SidekickArt)
			local art = SidekickArt[(name == "boss_king" or name == "boss_mage") and name .. "_jointed" or name]
			if art and art.BossModel then
				pcall(loadBoss, name, art.BossModel, bind, root)
			end
		end
		root:SetAttribute("Ready", true)
	end)
end

local function restyle(only)
	for _, rig in CollectionService:GetTagged(RunnerFactory.RIG_TAG) do
		local id = rig:GetAttribute("CharacterId")
		if id and (only == nil or id == only) and RunnerFactory.HasModel(id) then -- the others keep their look (an NPC's own colour)
			RunnerFactory.Restyle(rig, id)
		end
	end
end

-- Another world's models, for the players and rigs in this server that need them.
local function watchOwned(root, sidekickRoot, requested)
	local function character(id)
		local spec = CharacterCatalog.Get(id)
		local model = spec and spec.Model or id
		if not Assets[model] or requested[model] then
			return
		end
		requested[model] = true
		task.spawn(function()
			pcall(load, model, Assets[model], root)
			root:SetAttribute("Loaded_" .. model, true)
			restyle(id)
		end)
	end
	local function sidekicks(player)
		local ok, bag = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("SidekickBag") or "{}")
		for _, row in ok and type(bag) == "table" and bag or {} do
			local id = row.Id
			local art = SidekickArt[id]
			if art and art.Model and not requestedSidekicks[id] then
				requestedSidekicks[id] = true
				task.spawn(pcall, loadSidekick, id, art.Model, sidekickRoot)
			end
		end
	end
	local function join(player)
		player:GetAttributeChangedSignal("SidekickBag"):Connect(function()
			sidekicks(player)
		end)
		sidekicks(player)
		local data = player:FindFirstChild("GachaData")
		while not data and player.Parent do
			task.wait(0.5)
			data = player:FindFirstChild("GachaData")
		end
		if data then
			data.ChildAdded:Connect(function(entry)
				character(entry.Name)
			end)
			for _, entry in data:GetChildren() do
				character(entry.Name)
			end
		end
	end
	local function rig(model)
		local id = model:GetAttribute("CharacterId")
		if id then
			character(id)
		end
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
	CollectionService:GetInstanceAddedSignal(RunnerFactory.RIG_TAG):Connect(rig)
	for _, model in CollectionService:GetTagged(RunnerFactory.RIG_TAG) do
		rig(model)
	end
end

function CharacterModelService.Start()
	local sidekickRoot = startSidekicks()
	local requested = {} -- model id -> true once its load started
	startBoss()
	local root = Instance.new("Folder")
	root.Name = "CharacterModels"
	root.Parent = ReplicatedStorage
	task.spawn(function()
		-- All at once: 30 one after another held a fresh server's loading screen for seconds (design doc 4.24)
		local pending = 0
		for id, row in Assets do
			if CharacterModelService.Eager(id) then
				requested[id] = true
				pending += 1
				task.spawn(function()
					pcall(load, id, row, root)
					root:SetAttribute("Loaded_" .. id, true)
					pending -= 1
				end)
			end
		end
		watchOwned(root, sidekickRoot, requested)
		while pending > 0 do
			task.wait()
		end
		restyle()
		root:SetAttribute("Ready", true)
	end)
end

return CharacterModelService
