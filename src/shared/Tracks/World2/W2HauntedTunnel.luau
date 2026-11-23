--!nonstrict
-- World 2 Track 4 (design doc 4.46, docs/WORLD2_SPEC.md "Tracks"): Haunted Tunnel Road run.
-- Same route as World 1's Track 4 (Circuit), so its length, spiral lap and validator results carry over
-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths"); only the biome, palette and copy are new. Palette proposed.
return {
	Name = "W2HauntedTunnel",
	Description = "Haunted Tunnel Road run: a cursed mountain tunnel, flickering lamps and a moonlit school gate.",
	Number = 4,
	Biome = "HauntedTunnel",
	Width = 36,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("3E4440"),
		Support = Color3.fromHex("262A28"),
		Wall = Color3.fromHex("56605A"),
		Ground = Color3.fromHex("1E2420"),
		Line = Color3.fromHex("E8F0A0"),
		Checkpoint = Color3.fromHex("3FD6A0"),
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
