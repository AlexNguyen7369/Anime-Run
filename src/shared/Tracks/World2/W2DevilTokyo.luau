--!nonstrict
-- World 2 Track 6 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Devil Hunter City run.
-- Route: World 2's square spiral of long straights (WORLD2_SPEC "World 2 track layout", owner 2026-11-26; pitch 760
-- and corner radius 420 proposed), the target length of docs/TRACKS_AND_BIOMES_SPEC.md "Lengths". Palette proposed.
return {
	Name = "W2DevilTokyo",
	Description = "Devil Hunter City run: neon night streets, alley corners and the hunters' headquarters tower.",
	Number = 6,
	Biome = "DevilTokyo",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("2B2D36"),
		Support = Color3.fromHex("1C1D24"),
		Wall = Color3.fromHex("3A3D4A"),
		Ground = Color3.fromHex("15161C"),
		Line = Color3.fromHex("FFD23F"),
		Checkpoint = Color3.fromHex("E0483E"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 3614.2446 }, -- start straight
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 3960 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 115.0865 }, -- finish straight
	},
}
