--!nonstrict
-- Track 3 (w3, owner 2026-10-30): Pirate Harbor Isle: beach start, along the docks, through the harbor town lanes, over the cliff road and round the palms.
-- About 984 x 3 x 1.25^2 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
return {
	Name = "DragRace",
	Description = "Pirate Harbor Isle run: docks, harbor town lanes, a cliff road over the sea and palm-lined bends.",
	Number = 3,
	Biome = "Docks",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(72, 48, 88),
		Support = Color3.fromRGB(45, 30, 62),
		Wall = Color3.fromRGB(255, 119, 58),
		Ground = Color3.fromRGB(112, 67, 74),
		Line = Color3.fromRGB(255, 235, 174),
		Checkpoint = Color3.fromRGB(94, 49, 76),
		WinPad = Color3.fromRGB(255, 194, 54),
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
