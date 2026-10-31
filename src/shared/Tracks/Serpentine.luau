--!nonstrict
-- Track 5 (w3, owner 2026-10-30): Neon Cursed City: neon avenues, scramble crossing jinks, over the rail overpass and up the hill to the temple school.
-- About 984 x 3 x 1.25^4 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
return {
	Name = "Serpentine",
	Description = "Neon Cursed City run: neon avenues, crossing jinks, a rail overpass and the temple school hill.",
	Number = 5,
	Biome = "PirateCoast",
	Width = 36,
	Closed = false,
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
		{ Type = "Slope", Length = 160, Rise = 18 }, -- over the rail overpass
		{ Type = "Straight", Length = 80 },
		{ Type = "Slope", Length = 160, Rise = -18 },
		{ Type = "Straight", Length = 578 },
		{ Type = "Turn", Angle = -90, Radius = 305 }, -- corner
		{ Type = "Straight", Length = 200 },
		{ Type = "Slope", Length = 200, Rise = 30 }, -- hill up to the temple school
		{ Type = "Straight", Length = 60 },
		{ Type = "Slope", Length = 200, Rise = -30 },
		{ Type = "Straight", Length = 640 },
		{ Type = "Turn", Angle = -90, Radius = 305 }, -- corner
		{ Type = "Straight", Length = 765.255 }, -- finish straight
	},
}
