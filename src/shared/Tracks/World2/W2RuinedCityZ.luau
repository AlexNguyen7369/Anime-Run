--!nonstrict
-- World 2 Track 3 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Ruined City Zed run.
-- Route: World 2's square spiral of long straights (WORLD2_SPEC "World 2 track layout", owner 2026-11-26; pitch 760
-- and corner radius 420 proposed), the target length of docs/TRACKS_AND_BIOMES_SPEC.md "Lengths". Palette proposed.
return {
	Name = "W2RuinedCityZ",
	Description = "Ruined City Zed run: cracked avenues, a meteor crater and leaning half-fallen towers.",
	Number = 3,
	Biome = "RuinedCityZ",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("6E6A64"),
		Support = Color3.fromHex("4A4744"),
		Wall = Color3.fromHex("8A847C"),
		Ground = Color3.fromHex("5B554E"),
		Line = Color3.fromHex("F2E6C8"),
		Checkpoint = Color3.fromHex("E8B83A"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 40 }, -- start straight
		{ Type = "Turn", Angle = -79.7601, Radius = 420 },
		{ Type = "Straight", Length = 1580 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 1748.0933 }, -- finish straight
	},
}
