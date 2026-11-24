--!nonstrict
-- Anime biome themes, one module per track Biome key (docs/BIOME_ENVIRONMENT_SPEC.md section 9.1). Same API as
-- before: BiomeThemes[key]. Shared builders and the data format are in Kit. Each place requires only its own world's
-- themes (Shared/WorldConfig.Id), so World 1 never loads World 2's drafts and World 2 loads only the World 1 themes it
-- reads.
local WorldConfig = require(script.Parent:WaitForChild("WorldConfig"))

local KEYS = { "Speedway", "Forest", "Docks", "Suburb", "PirateCoast", "City", "Desert", "Snow", "Volcano", "Space" }

-- World 2's biome keys (design doc 4.47, docs/WORLD2_SPEC.md). A key whose Blender draft the owner approved (true) has
-- its own module in World2/, made from the draft by Kit.fromDraft. shortcut: the others use World 1's Track N theme so
-- the World 2 place boots; replace each with its own module once its draft is approved.
local WORLD2 = {
	DevilTokyo = true, -- approved 2026-11-23
	DemonCastle = "Forest",
	RuinedCityZ = true, -- approved 2026-11-23
	HauntedTunnel = true, -- approved 2026-11-23
	KaijuBase = true, -- approved 2026-11-23
	ElvenPlains = true, -- approved 2026-11-23
	AntIsland = true, -- approved 2026-11-23
	MonsterDen = true, -- approved 2026-11-23
	GoldenCity = "Volcano",
	HellGate = true, -- approved 2026-11-23
}
-- World 1 themes World 2 reads besides the stand-ins: Shared/BiomeEnvironment's plaza rows (Speedway) and boss arena (Snow)
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
for key, standIn in WORLD2 do
	if standIn ~= true then
		Themes[standIn] = Themes[standIn] or require(script:WaitForChild(standIn))
	end
	Themes[key] = standIn == true and require(world2:WaitForChild(key)) or Themes[standIn]
end
return Themes
