--!nonstrict
-- World 2 Track 1 (design doc 4.46, docs/WORLD2_SPEC.md "Tracks"): Devil Hunter Tokyo run.
-- Same route as World 1's Track 1 (Oval), so its length, spiral lap and validator results carry over
-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths"); only the biome, palette and copy are new. Palette proposed.
return {
	Name = "W2DevilTokyo",
	Description = "Devil Hunter Tokyo run: neon night streets, alley corners and the hunters' headquarters tower.",
	Number = 1,
	Biome = "DevilTokyo",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("2B2D36"),
		Support = Color3.fromHex("1C1D24"),
		Wall = Color3.fromHex("3A3D4A"),
		Ground = Color3.fromHex("15161C"),
		Line = Color3.fromHex("FFD23F"),
		Checkpoint = Color3.fromHex("E0483E"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 200 },
		{ Type = "Turn", Angle = -90, Radius = 80 }, -- corner
		{ Type = "Straight", Length = 168 },
		{ Type = "Turn", Angle = -90, Radius = 80 }, -- corner
		{ Type = "Straight", Length = 250 },
		{ Type = "Turn", Angle = -90, Radius = 80 }, -- corner
		{ Type = "Straight", Length = 70 },
		{ Type = "Turn", Angle = 18, Radius = 120 }, -- red arched bridge over the river
		{ Type = "Turn", Angle = -36, Radius = 120 },
		{ Type = "Turn", Angle = 18, Radius = 120 },
		{ Type = "Straight", Length = 99.672 },
		{ Type = "Turn", Angle = -90, Radius = 80 }, -- corner
		{ Type = "Straight", Length = 70 },
		{ Type = "Turn", Angle = -18, Radius = 120 }, -- red arched bridge over the river
		{ Type = "Turn", Angle = 36, Radius = 120 },
		{ Type = "Turn", Angle = -18, Radius = 120 },
		{ Type = "Straight", Length = 136.672 },
		{ Type = "Turn", Angle = -90, Radius = 125 }, -- corner
		{ Type = "Straight", Length = 70 },
		{ Type = "Turn", Angle = 26, Radius = 100 }, -- forest and waterfall gorge bend
		{ Type = "Turn", Angle = -52, Radius = 100 },
		{ Type = "Turn", Angle = 26, Radius = 100 },
		{ Type = "Straight", Length = 132.652 },
		{ Type = "Turn", Angle = -90, Radius = 125 }, -- corner
		{ Type = "Straight", Length = 376.544 }, -- finish straight
	},
}
