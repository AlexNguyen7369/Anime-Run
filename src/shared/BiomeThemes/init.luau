--!nonstrict
-- Anime biome themes, one module per track Biome key (docs/BIOME_ENVIRONMENT_SPEC.md section 9.1). Same API as
-- before: BiomeThemes[key]. Shared builders and the data format are in Kit. Each place requires only its own world's
-- themes (Shared/WorldConfig.Id), so World 1 never loads World 2's drafts and World 2 loads only the World 1 themes it
-- reads.
local WorldConfig = require(script.Parent:WaitForChild("WorldConfig"))

local KEYS = { "Speedway", "Forest", "Docks", "Suburb", "PirateCoast", "City", "Desert", "Snow", "Volcano", "Space" }

-- World 2's biome keys (design doc 4.47, docs/WORLD2_SPEC.md): every draft is owner-approved, so each key has its own
-- module in World2/, made from the draft by Kit.fromDraft.
local WORLD2 = {
	"DevilTokyo", -- approved 2026-11-23
	"DemonCastle", -- approved 2026-11-24
	"RuinedCityZ", -- approved 2026-11-23
	"HauntedTunnel", -- approved 2026-11-23
	"KaijuBase", -- approved 2026-11-23
	"ElvenPlains", -- approved 2026-11-23
	"AntIsland", -- approved 2026-11-23
	"MonsterDen", -- approved 2026-11-23
	"GoldenCity", -- approved 2026-11-24
	"HellGate", -- approved 2026-11-23
}
-- World 1 themes World 2 reads: Shared/BiomeEnvironment's plaza rows (Speedway) and boss arena (Snow)
local WORLD2_USES = { "Speedway", "Snow" }

local Themes = {}
if WorldConfig.Id == 1 then
	for _, key in KEYS do
		Themes[key] = require(script:WaitForChild(key))
	end
	return Themes
end
for _, key in WORLD2_USES do
	Themes[key] = require(script:WaitForChild(key))
end
local world2 = script:WaitForChild("World2")
for _, key in WORLD2 do
	Themes[key] = require(world2:WaitForChild(key))
end
return Themes
