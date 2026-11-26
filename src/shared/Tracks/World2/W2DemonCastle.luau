--!nonstrict
-- World 2 Track 2 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Demon King's Castle run.
-- Same route as World 1's Track 2 (Hill), so its length, spiral lap and validator results carry over
-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths"); only the biome, palette and copy are new. Palette proposed.
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
		{ Type = "Straight", Length = 83.456 },
		{ Type = "Turn", Angle = -90, Radius = 125 }, -- corner
		{ Type = "Straight", Length = 528 },
		{ Type = "Turn", Angle = -90, Radius = 125 }, -- corner
		{ Type = "Straight", Length = 130 },
		{ Type = "Slope", Length = 150, Rise = 26 }, -- crater rim climb and drop
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 150, Rise = -26 },
		{ Type = "Straight", Length = 95 },
		{ Type = "Turn", Angle = -90, Radius = 170 }, -- corner
		{ Type = "Straight", Length = 588 },
		{ Type = "Turn", Angle = -90, Radius = 170 }, -- corner
		{ Type = "Straight", Length = 670 },
		{ Type = "Turn", Angle = -90, Radius = 170 }, -- corner
		{ Type = "Straight", Length = 64 }, -- finish straight
	},
}
