--!nonstrict
-- World 2 Track 7 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Ant Island run.
-- Route: World 2's square spiral of long straights (WORLD2_SPEC "World 2 track layout", owner 2026-11-26; pitch 760
-- and corner radius 420 proposed), the target length of docs/TRACKS_AND_BIOMES_SPEC.md "Lengths". Palette proposed.
return {
	Name = "W2AntIsland",
	Description = "Ant Island run: volcanic shores, giant hive mounds and tunnels of the ant nest.",
	Number = 7,
	Biome = "AntIsland",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("5C4A3A"),
		Support = Color3.fromHex("3A2E24"),
		Wall = Color3.fromHex("6E5A46"),
		Ground = Color3.fromHex("3E3228"),
		Line = Color3.fromHex("E8C860"),
		Checkpoint = Color3.fromHex("8A3AC8"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 4604.9135 }, -- start straight
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 4720 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 616.6176 }, -- finish straight
	},
}
