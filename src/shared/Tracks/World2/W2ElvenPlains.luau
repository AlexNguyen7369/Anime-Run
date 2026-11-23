--!nonstrict
-- World 2 Track 6 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Elven Ruin Plains run.
-- Same route as World 1's Track 6 (City), so its length, spiral lap and validator results carry over
-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths"); only the biome, palette and copy are new. Palette proposed.
return {
	Name = "W2ElvenPlains",
	Description = "Elven Ruin Plains run: wildflower meadows, mossy white ruins and a demon's broken battlefield.",
	Number = 6,
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
		{ Type = "Straight", Length = 180 },
		{ Type = "Turn", Angle = 20, Radius = 200 }, -- past the campus gates
		{ Type = "Turn", Angle = -40, Radius = 200 },
		{ Type = "Turn", Angle = 20, Radius = 200 },
		{ Type = "Straight", Length = 149.129 },
		{ Type = "Turn", Angle = -90, Radius = 305 }, -- corner
		{ Type = "Straight", Length = 240 },
		{ Type = "Turn", Angle = 30, Radius = 120 }, -- mock-city training ground blocks
		{ Type = "Turn", Angle = -60, Radius = 120 },
		{ Type = "Turn", Angle = 30, Radius = 120 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -30, Radius = 120 },
		{ Type = "Turn", Angle = 60, Radius = 120 },
		{ Type = "Turn", Angle = -30, Radius = 120 },
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = -24, Radius = 160 }, -- round the toppled robots
		{ Type = "Turn", Angle = 48, Radius = 160 },
		{ Type = "Turn", Angle = -24, Radius = 160 },
		{ Type = "Straight", Length = 234.689 },
		{ Type = "Turn", Angle = -90, Radius = 350 }, -- corner
		{ Type = "Straight", Length = 130 },
		{ Type = "Turn", Angle = 20, Radius = 200 }, -- past the campus gates
		{ Type = "Turn", Angle = -40, Radius = 200 },
		{ Type = "Turn", Angle = 20, Radius = 200 },
		{ Type = "Straight", Length = 260 },
		{ Type = "Turn", Angle = 30, Radius = 120 }, -- mock-city training ground blocks
		{ Type = "Turn", Angle = -60, Radius = 120 },
		{ Type = "Turn", Angle = 30, Radius = 120 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -30, Radius = 120 },
		{ Type = "Turn", Angle = 60, Radius = 120 },
		{ Type = "Turn", Angle = -30, Radius = 120 },
		{ Type = "Straight", Length = 244.384 },
		{ Type = "Turn", Angle = -90, Radius = 350 }, -- corner
		{ Type = "Straight", Length = 120 },
		{ Type = "Turn", Angle = -24, Radius = 160 }, -- round the toppled robots
		{ Type = "Turn", Angle = 48, Radius = 160 },
		{ Type = "Turn", Angle = -24, Radius = 160 },
		{ Type = "Straight", Length = 240 },
		{ Type = "Turn", Angle = 20, Radius = 200 }, -- past the campus gates
		{ Type = "Turn", Angle = -40, Radius = 200 },
		{ Type = "Turn", Angle = 20, Radius = 200 },
		{ Type = "Straight", Length = 616.072 },
		{ Type = "Turn", Angle = -90, Radius = 350 }, -- corner
		{ Type = "Straight", Length = 200 },
		{ Type = "Turn", Angle = 30, Radius = 120 }, -- mock-city training ground blocks
		{ Type = "Turn", Angle = -60, Radius = 120 },
		{ Type = "Turn", Angle = 30, Radius = 120 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -30, Radius = 120 },
		{ Type = "Turn", Angle = 60, Radius = 120 },
		{ Type = "Turn", Angle = -30, Radius = 120 },
		{ Type = "Straight", Length = 130 },
		{ Type = "Turn", Angle = -24, Radius = 160 }, -- round the toppled robots
		{ Type = "Turn", Angle = 48, Radius = 160 },
		{ Type = "Turn", Angle = -24, Radius = 160 },
		{ Type = "Straight", Length = 427.689 }, -- finish straight
	},
}
