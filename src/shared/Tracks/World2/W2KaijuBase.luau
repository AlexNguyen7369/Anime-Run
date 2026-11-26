--!nonstrict
-- World 2 Track 5 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Wrecked Kaiju Base run.
-- Route: World 2's square spiral of long straights (WORLD2_SPEC "World 2 track layout", owner 2026-11-26; pitch 760
-- and corner radius 420 proposed), the target length of docs/TRACKS_AND_BIOMES_SPEC.md "Lengths". Palette proposed.
return {
	Name = "W2KaijuBase",
	Description = "Wrecked Kaiju Base run: a kaiju-smashed city, defense force base walls and giant bones in the streets.",
	Number = 5,
	Biome = "KaijuBase",
	Width = 36,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("5A5E66"),
		Support = Color3.fromHex("3A3E46"),
		Wall = Color3.fromHex("7A808A"),
		Ground = Color3.fromHex("4A4E46"),
		Line = Color3.fromHex("FF8A1E"),
		Checkpoint = Color3.fromHex("2F7FD8"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 1585.7757 }, -- start straight
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 3100 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 1201.7554 }, -- finish straight
	},
}
