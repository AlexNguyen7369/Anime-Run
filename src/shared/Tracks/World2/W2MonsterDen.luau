--!nonstrict
-- World 2 Track 8 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Monster Den run.
-- Same route as World 1's Track 8 (Snow), so its length, spiral lap and validator results carry over
-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths"); only the biome, palette and copy are new. Palette proposed.
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
		{ Type = "Straight", Length = 560.197 },
		{ Type = "Turn", Angle = -90, Radius = 638.395 }, -- corner
		{ Type = "Straight", Length = 180 },
		{ Type = "Slope", Length = 160, Rise = 28 }, -- hop onto a floating island
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 160, Rise = -28 },
		{ Type = "Straight", Length = 120 },
		{ Type = "Turn", Angle = 12, Radius = 680 }, -- vine bridge between islands
		{ Type = "Turn", Angle = -24, Radius = 680 },
		{ Type = "Turn", Angle = 12, Radius = 680 },
		{ Type = "Straight", Length = 474.48 },
		{ Type = "Turn", Angle = -90, Radius = 638.395 }, -- corner
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 10, Radius = 680 }, -- under the waterfalls
		{ Type = "Turn", Angle = -20, Radius = 680 },
		{ Type = "Turn", Angle = 10, Radius = 680 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -10, Radius = 680 },
		{ Type = "Turn", Angle = 20, Radius = 680 },
		{ Type = "Turn", Angle = -10, Radius = 680 },
		{ Type = "Straight", Length = 582.571 },
		{ Type = "Turn", Angle = -90, Radius = 638.395 }, -- corner
		{ Type = "Straight", Length = 130 },
		{ Type = "Slope", Length = 160, Rise = 28 }, -- hop onto a floating island
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 160, Rise = -28 },
		{ Type = "Straight", Length = 260 },
		{ Type = "Turn", Angle = 12, Radius = 680 }, -- vine bridge between islands
		{ Type = "Turn", Angle = -24, Radius = 680 },
		{ Type = "Turn", Angle = 12, Radius = 680 },
		{ Type = "Straight", Length = 611.33 },
		{ Type = "Turn", Angle = -90, Radius = 638.395 }, -- corner
		{ Type = "Straight", Length = 120 },
		{ Type = "Turn", Angle = 10, Radius = 680 }, -- under the waterfalls
		{ Type = "Turn", Angle = -20, Radius = 680 },
		{ Type = "Turn", Angle = 10, Radius = 680 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -10, Radius = 680 },
		{ Type = "Turn", Angle = 20, Radius = 680 },
		{ Type = "Turn", Angle = -10, Radius = 680 },
		{ Type = "Straight", Length = 240 },
		{ Type = "Slope", Length = 160, Rise = 28 }, -- hop onto a floating island
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 160, Rise = -28 },
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 12, Radius = 680 }, -- vine bridge between islands
		{ Type = "Turn", Angle = -24, Radius = 680 },
		{ Type = "Turn", Angle = 12, Radius = 680 },
		{ Type = "Straight", Length = 107.86 },
		{ Type = "Turn", Angle = -90, Radius = 638.395 }, -- corner
		{ Type = "Straight", Length = 593.322 }, -- finish straight
	},
}
