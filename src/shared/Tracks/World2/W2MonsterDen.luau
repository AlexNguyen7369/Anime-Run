--!nonstrict
-- World 2 Track 8 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Monster Den run.
-- Route: World 2's square spiral of long straights (WORLD2_SPEC "World 2 track layout", owner 2026-11-26; pitch 760
-- and corner radius 420 proposed), the target length of docs/TRACKS_AND_BIOMES_SPEC.md "Lengths". Palette proposed.
return {
	Name = "W2MonsterDen",
	Description = "Monster Den run: an underground lair of caverns, bone bridges and glowing pits.",
	Number = 8,
	Biome = "MonsterDen",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("3A2E3A"),
		Support = Color3.fromHex("221A22"),
		Wall = Color3.fromHex("4A3A4A"),
		Ground = Color3.fromHex("1A141A"),
		Line = Color3.fromHex("B8FF4A"),
		Checkpoint = Color3.fromHex("D83A6A"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 3507.3824 }, -- start straight
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 5380 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 3869.3487 }, -- finish straight
	},
}
