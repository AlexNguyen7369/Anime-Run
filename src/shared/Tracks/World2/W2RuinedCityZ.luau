--!nonstrict
-- World 2 Track 3 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Ruined City Zed run.
-- Same route as World 1's Track 3 (DragRace), so its length, spiral lap and validator results carry over
-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths"); only the biome, palette and copy are new. Palette proposed.
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
		{ Type = "Straight", Length = 240 },
		{ Type = "Turn", Angle = -16, Radius = 200 }, -- along the wooden docks
		{ Type = "Turn", Angle = 32, Radius = 200 },
		{ Type = "Turn", Angle = -16, Radius = 200 },
		{ Type = "Straight", Length = 213.49 },
		{ Type = "Turn", Angle = -90, Radius = 170 }, -- corner
		{ Type = "Straight", Length = 775 },
		{ Type = "Turn", Angle = -90, Radius = 215 }, -- corner
		{ Type = "Straight", Length = 130 },
		{ Type = "Turn", Angle = 26, Radius = 130 }, -- harbor town lanes
		{ Type = "Turn", Angle = -52, Radius = 130 },
		{ Type = "Turn", Angle = 26, Radius = 130 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -26, Radius = 130 },
		{ Type = "Turn", Angle = 52, Radius = 130 },
		{ Type = "Turn", Angle = -26, Radius = 130 },
		{ Type = "Straight", Length = 172.094 },
		{ Type = "Turn", Angle = -90, Radius = 215 }, -- corner
		{ Type = "Straight", Length = 180 },
		{ Type = "Slope", Length = 170, Rise = 22 }, -- cliff road with sea views
		{ Type = "Straight", Length = 60 },
		{ Type = "Slope", Length = 170, Rise = -22 },
		{ Type = "Straight", Length = 300 },
		{ Type = "Turn", Angle = -90, Radius = 215 }, -- corner
		{ Type = "Straight", Length = 183.542 }, -- finish straight
	},
}
