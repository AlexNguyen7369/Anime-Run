--!nonstrict
-- Anime biome themes, one module per track Biome key (docs/BIOME_ENVIRONMENT_SPEC.md section 9.1). Same API as
-- before: BiomeThemes[key]. Shared builders and the data format are in Kit.
local KEYS = { "Speedway", "Forest", "Docks", "Suburb", "PirateCoast", "City", "Desert", "Snow", "Volcano", "Space" }

-- World 2's biome keys (design doc 4.47, docs/WORLD2_SPEC.md). Their themes are written from the owner-approved Blender
-- drafts (tools/blender/world2). shortcut: until then each uses World 1's Track N theme so the World 2 place boots;
-- replace each entry with its own module once its draft is approved.
local WORLD2 = {
	DevilTokyo = "Speedway",
	DemonCastle = "Forest",
	RuinedCityZ = "Docks",
	HauntedTunnel = "Suburb",
	KaijuBase = "PirateCoast",
	ElvenPlains = "City",
	AntIsland = "Desert",
	MonsterDen = "Snow",
	GoldenCity = "Volcano",
	HellGate = "Space",
}

local Themes = {}
for _, key in KEYS do
	Themes[key] = require(script:WaitForChild(key))
end
for key, standIn in WORLD2 do
	Themes[key] = Themes[key] or Themes[standIn]
end
return Themes
