--!nonstrict
-- Track 2 (w3, owner 2026-10-30): Tournament Wasteland: crater rims to climb and drop, weaving between mesa pillars, past the open stone ring and along the cliffs.
-- About 984 x 3 x 1.25^1 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
return {
	Name = "Hill",
	Description = "Tournament Wasteland run: crater rims, mesa weaves and cliff sweeps around the open stone ring.",
	Width = 40,
	Closed = false,
	Number = 2,
	Biome = "Forest",
	Palette = {
		Road = Color3.fromRGB(36, 111, 122),
		Support = Color3.fromRGB(24, 69, 82),
		Wall = Color3.fromRGB(102, 222, 210),
		Ground = Color3.fromRGB(58, 126, 105),
		Line = Color3.fromRGB(226, 255, 248),
		Checkpoint = Color3.fromRGB(33, 92, 102),
		WinPad = Color3.fromRGB(255, 187, 44),
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
