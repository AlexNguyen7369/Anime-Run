--!nonstrict
-- Track 4 (w3, owner 2026-10-30): Wisteria Night Mountain: town street, stone stair climbs and wisteria grove bends into the dark forest.
-- About 984 x 3 x 1.25^3 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
return {
	Name = "Circuit",
	Description = "Wisteria Night Mountain run: a lantern-lit town street, stone stair climbs and wisteria grove bends.",
	Number = 4,
	Biome = "Suburb",
	Width = 36,
	Closed = false,
	-- owner 2026-10-31 no-approval, builder choice: pale moonlit flagstone road, dark wood rails (Track 4 spec palette)
	Palette = {
		Road = Color3.fromHex("E8E8F0"),
		Support = Color3.fromHex("3B2A1E"),
		Wall = Color3.fromHex("3B2A1E"),
		Ground = Color3.fromHex("1B1A33"),
		Line = Color3.fromHex("F5E6A8"),
		Checkpoint = Color3.fromHex("8E6BBF"),
		WinPad = Color3.fromRGB(255, 205, 70),
	},
	Segments = {
		{ Type = "Straight", Length = 150 },
		{ Type = "Slope", Length = 150, Rise = 20 }, -- stone stair path up and down
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 150, Rise = -20 },
		{ Type = "Straight", Length = 274.458 },
		{ Type = "Turn", Angle = -90, Radius = 215 }, -- corner
		{ Type = "Straight", Length = 130 },
		{ Type = "Turn", Angle = 30, Radius = 120 }, -- wisteria grove bends
		{ Type = "Turn", Angle = -60, Radius = 120 },
		{ Type = "Turn", Angle = 30, Radius = 120 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -30, Radius = 120 },
		{ Type = "Turn", Angle = 60, Radius = 120 },
		{ Type = "Turn", Angle = -30, Radius = 120 },
		{ Type = "Straight", Length = 335 },
		{ Type = "Turn", Angle = -90, Radius = 260 }, -- corner
		{ Type = "Straight", Length = 180 },
		{ Type = "Turn", Angle = 26, Radius = 140 }, -- dark forest bend
		{ Type = "Turn", Angle = -52, Radius = 140 },
		{ Type = "Turn", Angle = 26, Radius = 140 },
		{ Type = "Straight", Length = 120 },
		{ Type = "Slope", Length = 150, Rise = 20 }, -- stone stair path up and down
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 150, Rise = -20 },
		{ Type = "Straight", Length = 122.512 },
		{ Type = "Turn", Angle = -90, Radius = 260 }, -- corner
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 30, Radius = 120 }, -- wisteria grove bends
		{ Type = "Turn", Angle = -60, Radius = 120 },
		{ Type = "Turn", Angle = 30, Radius = 120 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -30, Radius = 120 },
		{ Type = "Turn", Angle = 60, Radius = 120 },
		{ Type = "Turn", Angle = -30, Radius = 120 },
		{ Type = "Straight", Length = 420 },
		{ Type = "Turn", Angle = -90, Radius = 260 }, -- corner
		{ Type = "Straight", Length = 295.974 }, -- finish straight
	},
}
