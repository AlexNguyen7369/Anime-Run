--!nonstrict
-- Track 10 (w3, owner 2026-10-30): Green Alien Planet: grassy island hills, land bridges over blue-green water and dome village bends.
-- About 984 x 3 x 1.25^9 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
-- Owner 2026-10-30: every bend is at least 3297 studs in radius, so the NPC rival (Shared/NpcRacer grip limit) holds
-- its cruise speed and its time matches the TRACKS_AND_BIOMES_SPEC table.
return {
	Name = "Space",
	Description = "Green Alien Planet run: island hills, land bridges over the water and dome village bends.",
	Number = 10,
	Biome = "Space",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(42, 55, 88),
		Support = Color3.fromRGB(24, 30, 60),
		Wall = Color3.fromRGB(84, 245, 255),
		Ground = Color3.fromRGB(10, 14, 35),
		Line = Color3.fromRGB(180, 120, 255),
		Checkpoint = Color3.fromRGB(48, 72, 130),
		WinPad = Color3.fromRGB(255, 218, 42),
	},
	Segments = {
		{ Type = "Straight", Length = 120 },
		{ Type = "Slope", Length = 220, Rise = 54 }, -- grassy island hill
		{ Type = "Straight", Length = 30 },
		{ Type = "Slope", Length = 220, Rise = -54 },
		{ Type = "Straight", Length = 919.908 },
		{ Type = "Turn", Angle = -90, Radius = 3297.927 }, -- corner
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 5, Radius = 3350 }, -- land bridge over blue-green water
		{ Type = "Turn", Angle = -10, Radius = 3350 },
		{ Type = "Turn", Angle = 5, Radius = 3350 },
		{ Type = "Straight", Length = 382.113 },
		{ Type = "Turn", Angle = -90, Radius = 3297.927 }, -- corner
		{ Type = "Straight", Length = 850 },
		{ Type = "Straight", Length = 850 },
		{ Type = "Turn", Angle = -90, Radius = 3297.927 }, -- corner
		{ Type = "Straight", Length = 764.274 }, -- finish straight
		{ Type = "Straight", Length = 764.274 }, -- finish straight
	},
}
