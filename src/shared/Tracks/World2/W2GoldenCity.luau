--!nonstrict
-- World 2 Track 9 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Golden City run.
-- Route: World 2's square spiral of long straights (WORLD2_SPEC "World 2 track layout", owner 2026-11-26; pitch 760
-- and corner radius 420 proposed), the target length of docs/TRACKS_AND_BIOMES_SPEC.md "Lengths". Palette proposed.
return {
	Name = "W2GoldenCity",
	Description = "Golden City run: a city turned to gold, glittering streets and a golden throne tower.",
	Number = 9,
	Biome = "GoldenCity",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("D8B45A"),
		Support = Color3.fromHex("8A6A2A"),
		Wall = Color3.fromHex("F0D080"),
		Ground = Color3.fromHex("B8923A"),
		Line = Color3.fromHex("FFFFFF"),
		Checkpoint = Color3.fromHex("FFF0A0"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 2270.6513 }, -- start straight
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 6140 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 6900 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 305.4453 }, -- finish straight
	},
}
