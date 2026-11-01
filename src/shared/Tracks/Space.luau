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
	-- b2 (orchestrator default 2026-10-31): pale sandy path, rock supports, dome-white walls, Track 10 spec palette
	Palette = {
		Road = Color3.fromHex("CFC79E"),
		Support = Color3.fromHex("6E7F5A"),
		Wall = Color3.fromHex("F0F0E6"),
		Ground = Color3.fromHex("3FB59A"),
		Line = Color3.fromHex("2E8B8B"),
		Checkpoint = Color3.fromHex("6E7F5A"),
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
