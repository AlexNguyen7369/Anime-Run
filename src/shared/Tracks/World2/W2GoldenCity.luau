--!nonstrict
-- World 2 Track 9 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Golden City run.
-- Same route as World 1's Track 9 (Volcano), so its length, spiral lap and validator results carry over
-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths"); only the biome, palette and copy are new. Palette proposed.
return {
	Name = "W2GoldenCity",
	Description = "Golden City run: a city turned to gold, glittering streets and a golden throne tower.",
	Number = 9,
	Biome = "GoldenCity",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("D8B45A"),
		Support = Color3.fromHex("8A6A2A"),
		Wall = Color3.fromHex("F0D080"),
		Ground = Color3.fromHex("B8923A"),
		Line = Color3.fromHex("FFFFFF"),
		Checkpoint = Color3.fromHex("FFF0A0"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 260 },
		{ Type = "Slope", Length = 200, Rise = 34 }, -- white dune
		{ Type = "Straight", Length = 30 },
		{ Type = "Slope", Length = 200, Rise = -34 },
		{ Type = "Straight", Length = 643.528 },
		{ Type = "Turn", Angle = -90, Radius = 1449.203 }, -- corner
		{ Type = "Straight", Length = 850 },
		{ Type = "Straight", Length = 850 },
		{ Type = "Turn", Angle = -90, Radius = 1449.203 }, -- corner
		{ Type = "Straight", Length = 850 },
		{ Type = "Straight", Length = 850 },
		{ Type = "Turn", Angle = -90, Radius = 1449.203 }, -- corner
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 7, Radius = 1500 }, -- dead white tree grove
		{ Type = "Turn", Angle = -14, Radius = 1500 },
		{ Type = "Turn", Angle = 7, Radius = 1500 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -7, Radius = 1500 },
		{ Type = "Turn", Angle = 14, Radius = 1500 },
		{ Type = "Turn", Angle = -7, Radius = 1500 },
		{ Type = "Straight", Length = 200 },
		{ Type = "Slope", Length = 180, Rise = 20 }, -- low dune
		{ Type = "Straight", Length = 30 },
		{ Type = "Slope", Length = 180, Rise = -20 },
		{ Type = "Straight", Length = 130 },
		{ Type = "Slope", Length = 200, Rise = 34 }, -- white dune
		{ Type = "Straight", Length = 30 },
		{ Type = "Slope", Length = 200, Rise = -34 },
		{ Type = "Straight", Length = 746.292 },
		{ Type = "Turn", Angle = -90, Radius = 1449.203 }, -- corner
		{ Type = "Straight", Length = 190.092 }, -- finish straight
	},
}
