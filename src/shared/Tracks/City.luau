--!nonstrict
-- Track 6 (w3, owner 2026-10-30): Hero Academy City: boulevards past the campus gates, mock-city training blocks and toppled robots.
-- About 984 x 3 x 1.25^5 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
return {
	Name = "City",
	Description = "Hero Academy City run: wide boulevards, campus gates, training-ground blocks and toppled robots.",
	Number = 6,
	Biome = "City",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(45, 48, 68),
		Support = Color3.fromRGB(28, 30, 48),
		Wall = Color3.fromRGB(70, 220, 255),
		Ground = Color3.fromRGB(28, 35, 52),
		Line = Color3.fromRGB(255, 80, 190),
		Checkpoint = Color3.fromRGB(50, 60, 92),
		WinPad = Color3.fromRGB(255, 218, 42),
		Checkered = true,
		CheckerDark = Color3.fromRGB(20, 22, 35),
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
