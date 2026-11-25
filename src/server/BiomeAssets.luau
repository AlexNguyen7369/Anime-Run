--!nonstrict
-- Mesh registry for biome props (docs/BIOME_ENVIRONMENT_SPEC.md 4.2). A prop def with Mesh = "<AssetKey>" asks
-- Clone(biome, key, size); the key must be a reviewed Mesh row with an Id in that biome's Assets ledger (4.4).
-- One template per key is loaded with CreateMeshPartAsync on first use (or by Preload, in parallel) and cached. A load
-- that fails or takes over TIMEOUT returns nil, and BiomeDressing builds the def's fallback Parts instead. A failed key
-- is loaded again in the background after RETRY seconds, until it loads (an unreviewed row is never tried). A load that
-- arrives late (after its TIMEOUT, or on a retry) serves every prop placed after it, such as the late-built tracks;
-- props already built keep their parts: they were budgeted, pruned and snapped as parts, and a swap after the build would
-- skip those passes. A load that never returns keeps one waiting thread for its key and starts no retry.
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BiomeEnvironment = require(ReplicatedStorage:WaitForChild("Shared").BiomeEnvironment)
local Themes = require(ReplicatedStorage.Shared.BiomeThemes)
local WorldConfig = require(ReplicatedStorage.Shared.WorldConfig)

local BiomeAssets = {}
BiomeAssets.TAG = "BiomeAsset" -- every placed mesh: the client turns its CastShadow off under REDUCED EFFECTS
BiomeAssets.TIMEOUT = 10 -- placeholder: seconds a build waits on one mesh load before its prop uses the parts
BiomeAssets.RETRY = { 30, 120, 600 } -- placeholder: seconds before a failed key is tried again (the last repeats)
BiomeAssets.DEBUG = RunService:IsStudio() -- os.clock timing prints of each load (Studio only)

-- "<biome>/<key>" -> { Part = template or nil, Pending, Deadline, Tries }
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

-- Starts a background load of `id` into its cache entry; a failure schedules the next try
local function start(id, biome, key)
	local entry = cache[id] or { Tries = 0 }
	cache[id] = entry
	local okRow, row = pcall(BiomeAssets.Row, biome, key, "Mesh")
	if not (okRow and row) then
		return entry -- unreviewed: fallback parts for this server's life
	end
	entry.Pending, entry.Deadline = true, os.clock() + BiomeAssets.TIMEOUT
	task.spawn(function()
		local t0 = os.clock()
		local ok, part = pcall(function()
			local template = BiomeAssets.Fetch(row)
			if not template then
				error("no mesh returned")
			end
			local texture = row.Texture and BiomeAssets.Row(biome, row.Texture, "Texture")
			if texture then
				template.TextureContent = Content.fromUri(texture.Id)
			elseif
				WorldConfig.Id == 2
				and not row.Texture
				and template:IsA("MeshPart")
				and template.TextureID == ""
			then
				-- a draft mesh shows its vertex colours: the part's default grey would tint them (docs/BUGS.md w2-dark-props)
				template.Color = Color3.new(1, 1, 1)
			end
			template.Anchored = true
			template.CanCollide = false
			template.CanTouch = false
			template.CanQuery = false
			return template
		end)
		entry.Pending = false
		if ok then
			entry.Part, entry.Tries = part, 0
		else
			entry.Tries += 1
			local delay = BiomeAssets.RETRY[math.min(entry.Tries, #BiomeAssets.RETRY)]
			warn(
				string.format(
					"[BiomeAssets] %s failed to load (retry in %s s): %s",
					id,
					tostring(delay),
					tostring(part)
				)
			)
			task.delay(delay, function()
				if not entry.Part and not entry.Pending then
					start(id, biome, key)
				end
			end)
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
	local entry = cache[id] or start(id, biome, key) -- a failed key retries on its own (start)
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
