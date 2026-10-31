--!nonstrict
-- Mesh registry for biome props (docs/BIOME_ENVIRONMENT_SPEC.md 4.2). A prop def with Mesh = "<AssetKey>" asks
-- Clone(biome, key, size); the key must be a reviewed Mesh row with an Id in that biome's Assets ledger (4.4).
-- One template per key is loaded with CreateMeshPartAsync on first use and cached; a load failure or an unreviewed
-- row returns nil, and BiomeDressing builds the def's fallback Parts instead.
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeEnvironment = require(ReplicatedStorage:WaitForChild("Shared").BiomeEnvironment)

local BiomeAssets = {}
BiomeAssets.TAG = "BiomeAsset" -- every placed mesh: the client turns its CastShadow off under REDUCED EFFECTS

local cache = {} -- "<biome>/<key>" -> MeshPart template, or false after a failure

BiomeAssets.Row = BiomeEnvironment.Row -- the usable ledger row (reviewed, with an Id) or nil

local function load(biome, key)
	local row = BiomeAssets.Row(biome, key, "Mesh")
	if not row then
		return nil
	end
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(row.Id), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
	end)
	if not ok or not part then
		warn("[BiomeAssets] " .. biome .. "/" .. key .. " failed to load, using parts: " .. tostring(part))
		return nil
	end
	local texture = row.Texture and BiomeAssets.Row(biome, row.Texture, "Texture")
	if texture then
		part.TextureContent = Content.fromUri(texture.Id)
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

-- A new anchored, non-colliding MeshPart of the asset at `size`, or nil (use the parts fallback)
function BiomeAssets.Clone(biome, key, size)
	local id = biome .. "/" .. key
	if cache[id] == nil then
		cache[id] = load(biome, key) or false
	end
	if not cache[id] then
		return nil
	end
	local part = cache[id]:Clone()
	part.Size = size
	part.CastShadow = size.Magnitude > 30
	CollectionService:AddTag(part, BiomeAssets.TAG)
	return part
end

return BiomeAssets
