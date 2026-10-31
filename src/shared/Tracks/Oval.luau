--!nonstrict
-- Track 1 (w3, owner 2026-10-30): Leafwind Village: forest start through the village gate, a long main street and cliff base, two river bridges, then a forest gorge of S-bends, all on the spiral's first lap round the plaza.
-- About 984 x 3 x 1.25^0 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
return {
	Name = "Oval",
	Description = "Leafwind Village run: a forest start through the village gate, a long main street, river bridges and a winding forest gorge. Ends on a level straight with a wide checkpoint area that leads to the next track.",
	Number = 1,
	Biome = "Speedway",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(110, 116, 132),
		Support = Color3.fromRGB(70, 74, 88),
		Wall = Color3.fromRGB(188, 42, 48),
		Ground = Color3.fromRGB(74, 112, 72),
		Line = Color3.fromRGB(245, 245, 245),
		Checkpoint = Color3.fromRGB(128, 34, 40),
		WinPad = Color3.fromRGB(255, 218, 42),
		Checkered = true,
		CheckerDark = Color3.fromRGB(28, 30, 38),
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
