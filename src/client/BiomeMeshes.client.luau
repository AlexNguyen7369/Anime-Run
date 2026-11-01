--!nonstrict
-- Puts the baked CC0 meshes on biome props near the camera (docs/BIOME_DRESSING_SPEC.md "Assets"). The server
-- tags each prop that has one "BiomeMesh" with attribute Mesh = "<Biome>_<Prop>" and an invisible MeshBounds box.
-- EditableMesh content does not replicate and the client has a strict EditableMesh memory budget, so this builds
-- a mesh only while a prop using it is within LOAD_DISTANCE (nearest first), destroys it when none is, and
-- shows the fallback parts everywhere else (and whenever the budget is full).
-- Loading at high speed (design doc 4.18, BIOME_ENVIRONMENT_SPEC section 8): the uploaded ledger meshes, textures
-- and skyboxes of the camera's zone and of the next track are preloaded once each, and the area the runner reaches
-- in STREAM_LEAD seconds is requested from the server, so props are cached and streamed in before arrival.

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BiomeDressing = require(Shared.BiomeDressing)
local BiomeEnvironment = require(Shared.BiomeEnvironment)
local BiomeMeshAssets = require(Shared.BiomeMeshAssets)
local BiomeMeshCodec = require(Shared.BiomeMeshCodec)
local BiomeThemes = require(Shared.BiomeThemes)
local RaceConfig = require(Shared.RaceConfig)

local LOAD_DISTANCE = 1024 -- studs from the camera (was 450: under 0.6 s of warning at MAX_CRUISE)
local REFRESH = 0.25 -- seconds between range checks (was 1: a runner at MAX_CRUISE covered 800 studs per check)
local PRELOAD_POLL = 1 -- placeholder: seconds between zone checks for the preload
local PRELOAD_KINDS = { Mesh = true, Texture = true, Skybox = true }
local STREAM_LEAD = 1.5 -- placeholder: seconds ahead of the camera focus the stream request is centred
local STREAM_POLL = 0.25 -- placeholder: seconds between stream requests
local STREAM_MIN_SPEED = 150 -- placeholder: studs/s; below this the streaming radius keeps up on its own

local preloaded = {} -- asset id -> true; an id shared by several biomes is fetched once

-- Fetches every usable Mesh / Texture / Skybox id of a biome's ledger not fetched yet (yields)
local function preloadBiome(biome)
	local theme = biome and BiomeThemes[biome]
	local ids = {}
	for key, row in theme and theme.Assets or {} do
		if PRELOAD_KINDS[row.Kind] and BiomeEnvironment.Row(biome, key) then
			for _, id in row.Faces or { row.Id } do
				if not preloaded[id] then
					preloaded[id] = true
					table.insert(ids, id)
				end
			end
		end
	end
	if #ids > 0 then
		pcall(ContentProvider.PreloadAsync, ContentProvider, ids)
	end
end

-- Zone n is track n (0 the plaza) and track n + 1 starts at track n's finish, so on entering a zone the next
-- track's assets download while this one is run.
task.spawn(function()
	local lastZone
	while true do
		local camera = Workspace.CurrentCamera
		local zone = camera and BiomeEnvironment.ZoneAt(camera.Focus.Position)
		if zone and zone ~= lastZone then
			lastZone = zone
			preloadBiome(BiomeEnvironment.BiomeOf(zone))
			preloadBiome(BiomeEnvironment.BiomeOf(zone + 1))
		end
		task.wait(PRELOAD_POLL)
	end
end)

-- The streaming radius alone gives about 1.3 s of warning at MAX_CRUISE, so also ask for the area ahead.
task.spawn(function()
	local player = Players.LocalPlayer
	local last, lastT
	while true do
		local camera = Workspace.CurrentCamera
		if camera and Workspace.StreamingEnabled then
			local p, t = camera.Focus.Position, os.clock()
			local v = last and (p - last) / math.max(t - lastT, 1e-3)
			last, lastT = p, t
			-- faster than 1.5 x MAX_CRUISE is a teleport, not a run
			if v and v.Magnitude > STREAM_MIN_SPEED and v.Magnitude < RaceConfig.MAX_CRUISE * 1.5 then
				pcall(player.RequestStreamAroundAsync, player, p + v * STREAM_LEAD, 1)
			end
		end
		task.wait(STREAM_POLL)
	end
end)

local built = {} -- key -> { Mesh = EditableMesh, Part = MeshPart }

local function build(key)
	local biome, name = string.match(key, "^([^_]+)_(.+)$")
	local data = biome and BiomeDressing.MeshFor(biome, name)
	local mesh = data and BiomeMeshCodec.Build(data.Data)
	if not mesh then
		return nil -- no data, or the mesh budget is full: keep the fallback
	end
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
		})
	end)
	if not ok then
		mesh:Destroy()
		return nil
	end
	local texture = BiomeMeshAssets[key]
	if texture then
		part.TextureContent = Content.fromUri(texture)
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return { Mesh = mesh, Part = part }
end

local function setFallback(model, visible)
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "MeshBounds" and child.Name ~= "BiomeMesh" then
			child.LocalTransparencyModifier = visible and 0 or 1
		end
	end
end

local function show(model, entry)
	local bounds = model:FindFirstChild("MeshBounds")
	if not bounds or model:FindFirstChild("BiomeMesh") then
		return
	end
	local part = entry.Part:Clone()
	part.Name = "BiomeMesh"
	part.Size = bounds.Size
	part.CFrame = bounds.CFrame
	part.CastShadow = bounds.Size.Magnitude > 30
	CollectionService:AddTag(part, "BiomeAsset") -- Client/BiomeEnvironment turns its shadow off under REDUCED EFFECTS
	setFallback(model, false)
	part.Parent = model
end

local function hide(model)
	local part = model:FindFirstChild("BiomeMesh")
	if part then
		part:Destroy()
		setFallback(model, true)
	end
end

while true do
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	if eye then
		local nearest, inRange = {}, {}
		for _, model in CollectionService:GetTagged("BiomeMesh") do
			local bounds = model:FindFirstChild("MeshBounds")
			local key = model:GetAttribute("Mesh")
			if bounds and key then
				local d = (bounds.Position - eye).Magnitude
				if d < LOAD_DISTANCE then
					inRange[model] = key
					nearest[key] = math.min(nearest[key] or math.huge, d)
				else
					hide(model)
				end
			end
		end
		for key, entry in built do
			if not nearest[key] then
				for _, model in CollectionService:GetTagged("BiomeMesh") do
					if model:GetAttribute("Mesh") == key then
						hide(model)
					end
				end
				entry.Mesh:Destroy() -- frees its share of the budget at once
				entry.Part:Destroy()
				built[key] = nil
			end
		end
		local wanted = {}
		for key in nearest do
			if not built[key] then
				table.insert(wanted, key)
			end
		end
		table.sort(wanted, function(a, b)
			return nearest[a] < nearest[b]
		end)
		for _, key in wanted do
			local entry = build(key)
			if not entry then
				break -- budget full: farther meshes wait for one to be released
			end
			built[key] = entry
		end
		for model, key in inRange do
			if built[key] then
				show(model, built[key])
			end
		end
	end
	task.wait(REFRESH)
end
