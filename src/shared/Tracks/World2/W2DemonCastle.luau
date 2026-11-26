--!nonstrict
-- World 2 Track 2 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Demon King's Castle run.
-- Route: World 2's square spiral of long straights (WORLD2_SPEC "World 2 track layout", owner 2026-11-26; pitch 760
-- and corner radius 420 proposed), the target length of docs/TRACKS_AND_BIOMES_SPEC.md "Lengths". Palette proposed.
return {
	Name = "W2DemonCastle",
	Description = "Demon King's Castle run: black stone ramparts, spiral stairs and floating spires over a blood-red sky.",
	Number = 2,
	Biome = "DemonCastle",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("4A4452"),
		Support = Color3.fromHex("2A2530"),
		Wall = Color3.fromHex("3B3443"),
		Ground = Color3.fromHex("1F1A24"),
		Line = Color3.fromHex("C93A3A"),
		Checkpoint = Color3.fromHex("7A2FBF"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 40 }, -- start straight
		{ Type = "Turn", Angle = -61.5525, Radius = 420 },
		{ Type = "Straight", Length = 820 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 1580 },
		{ Type = "Turn", Angle = -10.2399, Radius = 420 },
		{ Type = "Straight", Length = 64 }, -- finish straight
	},
}
