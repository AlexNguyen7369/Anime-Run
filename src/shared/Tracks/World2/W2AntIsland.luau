--!nonstrict
-- World 2 Track 7 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Ant Island run.
-- Same route as World 1's Track 7 (Desert), so its length, spiral lap and validator results carry over
-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths"); only the biome, palette and copy are new. Palette proposed.
return {
	Name = "W2AntIsland",
	Description = "Ant Island run: volcanic shores, giant hive mounds and tunnels of the ant nest.",
	Number = 7,
	Biome = "AntIsland",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("5C4A3A"),
		Support = Color3.fromHex("3A2E24"),
		Wall = Color3.fromHex("6E5A46"),
		Ground = Color3.fromHex("3E3228"),
		Line = Color3.fromHex("E8C860"),
		Checkpoint = Color3.fromHex("8A3AC8"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 40 }, -- start straight
		{ Type = "Turn", Angle = -90, Radius = 350 }, -- corner
		{ Type = "Straight", Length = 180 },
		{ Type = "Turn", Angle = 16, Radius = 320 }, -- cherry blossom avenue sweep
		{ Type = "Turn", Angle = -32, Radius = 320 },
		{ Type = "Turn", Angle = 16, Radius = 320 },
		{ Type = "Straight", Length = 120 },
		{ Type = "Slope", Length = 220, Rise = 34 }, -- stone stairs up to the hilltop shrine
		{ Type = "Straight", Length = 60 },
		{ Type = "Slope", Length = 220, Rise = -34 },
		{ Type = "Straight", Length = 462.184 },
		{ Type = "Turn", Angle = -90, Radius = 395 }, -- corner
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 20, Radius = 320 }, -- switchback bends on the shrine hill
		{ Type = "Turn", Angle = -40, Radius = 320 },
		{ Type = "Turn", Angle = 20, Radius = 320 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -20, Radius = 320 },
		{ Type = "Turn", Angle = 40, Radius = 320 },
		{ Type = "Turn", Angle = -20, Radius = 320 },
		{ Type = "Straight", Length = 572.428 },
		{ Type = "Turn", Angle = -90, Radius = 395 }, -- corner
		{ Type = "Straight", Length = 130 },
		{ Type = "Turn", Angle = 16, Radius = 320 }, -- cherry blossom avenue sweep
		{ Type = "Turn", Angle = -32, Radius = 320 },
		{ Type = "Turn", Angle = 16, Radius = 320 },
		{ Type = "Straight", Length = 260 },
		{ Type = "Slope", Length = 220, Rise = 34 }, -- stone stairs up to the hilltop shrine
		{ Type = "Straight", Length = 60 },
		{ Type = "Slope", Length = 220, Rise = -34 },
		{ Type = "Straight", Length = 495.947 },
		{ Type = "Turn", Angle = -90, Radius = 395 }, -- corner
		{ Type = "Straight", Length = 120 },
		{ Type = "Turn", Angle = 20, Radius = 320 }, -- switchback bends on the shrine hill
		{ Type = "Turn", Angle = -40, Radius = 320 },
		{ Type = "Turn", Angle = 20, Radius = 320 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -20, Radius = 320 },
		{ Type = "Turn", Angle = 40, Radius = 320 },
		{ Type = "Turn", Angle = -20, Radius = 320 },
		{ Type = "Straight", Length = 240 },
		{ Type = "Turn", Angle = 16, Radius = 320 }, -- cherry blossom avenue sweep
		{ Type = "Turn", Angle = -32, Radius = 320 },
		{ Type = "Turn", Angle = 16, Radius = 320 },
		{ Type = "Straight", Length = 330.007 },
		{ Type = "Turn", Angle = -90, Radius = 395 }, -- corner
		{ Type = "Straight", Length = 200 },
		{ Type = "Slope", Length = 220, Rise = 34 }, -- stone stairs up to the hilltop shrine
		{ Type = "Straight", Length = 60 },
		{ Type = "Slope", Length = 220, Rise = -34 },
		{ Type = "Straight", Length = 473.565 }, -- finish straight
	},
}
