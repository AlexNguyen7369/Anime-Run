--!nonstrict
-- World 2 Track 5 (design doc 4.46, docs/WORLD2_SPEC.md "Tracks"): Wrecked Tachikawa run.
-- Same route as World 1's Track 5 (Serpentine), so its length, spiral lap and validator results carry over
-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths"); only the biome, palette and copy are new. Palette proposed.
return {
	Name = "W2KaijuBase",
	Description = "Wrecked Tachikawa run: a kaiju-smashed city, defense force base walls and giant bones in the streets.",
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
		{ Type = "Straight", Length = 862.026 },
		{ Type = "Turn", Angle = -90, Radius = 260 }, -- corner
		{ Type = "Straight", Length = 180 },
		{ Type = "Turn", Angle = 24, Radius = 150 }, -- scramble crossing jink
		{ Type = "Turn", Angle = -48, Radius = 150 },
		{ Type = "Turn", Angle = 24, Radius = 150 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -24, Radius = 150 },
		{ Type = "Turn", Angle = 48, Radius = 150 },
		{ Type = "Turn", Angle = -24, Radius = 150 },
		{ Type = "Straight", Length = 486.916 },
		{ Type = "Turn", Angle = -90, Radius = 305 }, -- corner
		{ Type = "Straight", Length = 240 },
		{ Type = "Slope", Length = 160, Rise = 18 }, -- up over the meteor crater
		{ Type = "Straight", Length = 80 },
		{ Type = "Slope", Length = 160, Rise = -18 },
		{ Type = "Straight", Length = 578 },
		{ Type = "Turn", Angle = -90, Radius = 305 }, -- corner
		{ Type = "Straight", Length = 200 },
		{ Type = "Slope", Length = 200, Rise = 30 }, -- up the rubble mound
		{ Type = "Straight", Length = 60 },
		{ Type = "Slope", Length = 200, Rise = -30 },
		{ Type = "Straight", Length = 640 },
		{ Type = "Turn", Angle = -90, Radius = 305 }, -- corner
		{ Type = "Straight", Length = 765.255 }, -- finish straight
	},
}
