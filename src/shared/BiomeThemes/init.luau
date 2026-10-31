--!nonstrict
-- Anime biome themes, one module per track Biome key (docs/BIOME_ENVIRONMENT_SPEC.md section 9.1). Same API as
-- before: BiomeThemes[key]. Shared builders and the data format are in Kit.
local KEYS = { "Speedway", "Forest", "Docks", "Suburb", "PirateCoast", "City", "Desert", "Snow", "Volcano", "Space" }

local Themes = {}
for _, key in KEYS do
	Themes[key] = require(script:WaitForChild(key))
end
return Themes
