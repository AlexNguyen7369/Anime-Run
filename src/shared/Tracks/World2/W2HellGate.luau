--!nonstrict
-- World 2 Track 10 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Hell's Gate run.
-- Route: World 2's square spiral of long straights (WORLD2_SPEC "World 2 track layout", owner 2026-11-26; pitch 760
-- and corner radius 420 proposed), the target length of docs/TRACKS_AND_BIOMES_SPEC.md "Lengths". Palette proposed.
return {
	Name = "W2HellGate",
	Description = "Hell's Gate run: a red sky over endless doors, floating stairs and a field of giant hands.",
	Number = 10,
	Biome = "HellGate",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("3A1A1A"),
		Support = Color3.fromHex("220E0E"),
		Wall = Color3.fromHex("5A2222"),
		Ground = Color3.fromHex("2A0E0E"),
		Line = Color3.fromHex("FF4A2A"),
		Checkpoint = Color3.fromHex("FFD0D0"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 6594.5547 }, -- start straight
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 7660 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 6420.0764 }, -- finish straight
	},
}
