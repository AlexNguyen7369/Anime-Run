--!nonstrict
-- World 2 Track 1 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Elven Ruin Plains run.
-- Route: World 2's square spiral of long straights (WORLD2_SPEC "World 2 track layout", owner 2026-11-26; pitch 760
-- and corner radius 420 proposed), the target length of docs/TRACKS_AND_BIOMES_SPEC.md "Lengths". Palette proposed.
return {
	Name = "W2ElvenPlains",
	Description = "Elven Ruin Plains run: wildflower meadows, mossy white ruins and a demon's broken battlefield.",
	Number = 1,
	Biome = "ElvenPlains",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("CFC6B2"),
		Support = Color3.fromHex("8A8070"),
		Wall = Color3.fromHex("E8E2D4"),
		Ground = Color3.fromHex("6FA35A"),
		Line = Color3.fromHex("FFFFFF"),
		Checkpoint = Color3.fromHex("7AC6E8"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 480 }, -- start straight
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 60 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 820 },
		{ Type = "Turn", Angle = -28.4475, Radius = 420 },
		{ Type = "Straight", Length = 64 }, -- finish straight
	},
}
