--!nonstrict
-- Mesh registry for biome props (docs/BIOME_ENVIRONMENT_SPEC.md 4.2). A prop def with Mesh = "<AssetKey>" asks
-- Clone(biome, key, size); the key must be a reviewed Mesh row with an Id in that biome's Assets ledger (4.4).
-- One template per key is loaded with CreateMeshPartAsync on first use (or by Preload, in parallel) and cached. A load
-- that fails or takes over TIMEOUT returns nil, and BiomeDressing builds the def's fallback Parts instead; a failed key
-- is tried again in the background after RETRY seconds (a late load still fills the cache), an unreviewed row never.
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BiomeEnvironment = require(ReplicatedStorage:WaitForChild("Shared").BiomeEnvironment)
local Themes = require(ReplicatedStorage.Shared.BiomeThemes)

local BiomeAssets = {}
BiomeAssets.TAG = "BiomeAsset" -- every placed mesh: the client turns its CastShadow off under REDUCED EFFECTS
BiomeAssets.TIMEOUT = 10 -- placeholder: seconds a build waits on one mesh load before its prop uses the parts
BiomeAssets.RETRY = { 30, 120, 600 } -- placeholder: seconds before a failed key is tried again (the last repeats)
BiomeAssets.DEBUG = RunService:IsStudio() -- os.clock timing prints of each load (Studio only)

-- "<biome>/<key>" -> { Part = template or nil, Pending, Deadline, Tries, RetryAt }
local cache = {}

BiomeAssets.Row = BiomeEnvironment.Row -- the usable ledger row (reviewed, with an Id) or nil

-- Test seam: the template of a reviewed row, or nil / an error when the load fails. Yields.
BiomeAssets.Fetch = function(row)
	-- Collaborators load a copy saved in the place (named by asset id), as CharacterModelService does
	local baked = ServerStorage:FindFirstChild("BakedModels")
	local copy = baked and baked:FindFirstChild(string.match(row.Id, "%d+"))
	if copy then
		return copy:Clone()
	end
	return AssetService:CreateMeshPartAsync(Content.fromUri(row.Id), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Automatic,
	})
end

-- Starts a background load of `id` into its cache entry (a later call retries a failed one)
local function start(id, biome, key)
	local entry = cache[id] or { Tries = 0 }
	cache[id] = entry
	local row = BiomeAssets.Row(biome, key, "Mesh")
	if not row then
		entry.RetryAt = math.huge -- unreviewed: fallback parts for this server's life
		return entry
	end
	entry.Pending, entry.Deadline = true, os.clock() + BiomeAssets.TIMEOUT
	task.spawn(function()
		local t0 = os.clock()
		local ok, part = pcall(BiomeAssets.Fetch, row)
		entry.Pending = false
		if ok and part then
			local texture = row.Texture and BiomeAssets.Row(biome, row.Texture, "Texture")
			if texture then
				part.TextureContent = Content.fromUri(texture.Id)
			end
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			entry.Part, entry.Tries = part, 0
		else
			entry.Tries += 1
			local delay = BiomeAssets.RETRY[math.min(entry.Tries, #BiomeAssets.RETRY)]
			entry.RetryAt = os.clock() + delay
			warn(string.format("[BiomeAssets] %s failed to load (retry in %d s): %s", id, delay, tostring(part)))
		end
		if BiomeAssets.DEBUG then
			print(
				string.format("[BiomeAssets] %s %s in %.2f s", id, entry.Part and "loaded" or "failed", os.clock() - t0)
			)
		end
	end)
	return entry
end

-- Waits for a pending load until its deadline; the template or nil
local function await(id, entry)
	while entry.Pending and os.clock() < entry.Deadline do
		task.wait()
	end
	if entry.Pending and not entry.Warned then
		entry.Warned = true
		warn("[BiomeAssets] " .. id .. " took over " .. BiomeAssets.TIMEOUT .. " s, using parts")
	end
	return entry.Part
end

-- Starts every Mesh key of the `biomes` (names in Shared/BiomeThemes) not tried yet, all in parallel, then waits for
-- them (each up to TIMEOUT). Main.server calls it before track builds, so the builds read a warm cache.
function BiomeAssets.Preload(biomes)
	local seen, started, biome = {}, {}, nil
	local function walk(t)
		if seen[t] then
			return
		end
		seen[t] = true
		local key = rawget(t, "Mesh")
		local id = type(key) == "string" and biome .. "/" .. key
		if id and not cache[id] then
			started[id] = start(id, biome, key)
		end
		for _, v in t do
			if type(v) == "table" then
				walk(v)
			end
		end
	end
	for _, name in biomes do
		biome, seen = name, {} -- themes share Kit tables: each biome walks them again
		local theme = type(name) == "string" and Themes[name]
		if type(theme) == "table" then
			walk(theme)
		end
	end
	for id, entry in started do
		await(id, entry)
	end
end

-- A new anchored, non-colliding MeshPart of the asset at `size`, or nil (use the parts fallback). `castShadow`: the
-- def's CastShadow flag (nil: only a prop over 30 studs across casts, BIOME_ENVIRONMENT_SPEC 8).
function BiomeAssets.Clone(biome, key, size, castShadow)
	local id = biome .. "/" .. key
	local entry = cache[id]
	if not entry then
		entry = start(id, biome, key)
	elseif not entry.Part and not entry.Pending and os.clock() >= entry.RetryAt then
		start(id, biome, key) -- in the background: this prop keeps its parts
		return nil
	end
	local template = if entry.Pending then await(id, entry) else entry.Part
	if not template then
		return nil
	end
	local part = template:Clone()
	part.Size = size
	if castShadow == nil then
		part.CastShadow = size.Magnitude > 30
	else
		part.CastShadow = castShadow
	end
	CollectionService:AddTag(part, BiomeAssets.TAG)
	return part
end

return BiomeAssets
