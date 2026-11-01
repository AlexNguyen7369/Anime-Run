--!nonstrict
-- Track 9 (w3, owner 2026-10-30): Spirit Realm Desert: white dunes, dead white tree groves and long runs toward the dome palace.
-- About 984 x 3 x 1.25^8 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
-- Owner 2026-10-30: every bend is at least 1449 studs in radius, so the NPC rival (Shared/NpcRacer grip limit) holds
-- its cruise speed and its time matches the TRACKS_AND_BIOMES_SPEC table.
return {
	Name = "Volcano",
	Description = "Spirit Realm Desert run: white dunes, dead tree groves and long runs toward the dome palace.",
	Number = 9,
	Biome = "Volcano",
	Width = 40,
	Closed = false,
	-- owner 2026-10-31 no-approval, orchestrator default 2026-10-31: pale moonlit blue-grey stone road with dark
	-- basalt lines and rails, so it reads on the white sand at night (Track 9 spec palette)
	Palette = {
		Road = Color3.fromHex("B4BCCB"),
		Support = Color3.fromHex("2E2E3A"),
		Wall = Color3.fromHex("8892A6"),
		Ground = Color3.fromHex("F2F2EE"),
		Line = Color3.fromHex("2E2E3A"),
		Checkpoint = Color3.fromHex("8892A6"),
		WinPad = Color3.fromRGB(255, 218, 42),
	},
	Segments = {
		{ Type = "Straight", Length = 260 },
		{ Type = "Slope", Length = 200, Rise = 34 }, -- white dune
		{ Type = "Straight", Length = 30 },
		{ Type = "Slope", Length = 200, Rise = -34 },
		{ Type = "Straight", Length = 643.528 },
		{ Type = "Turn", Angle = -90, Radius = 1449.203 }, -- corner
		{ Type = "Straight", Length = 850 },
		{ Type = "Straight", Length = 850 },
		{ Type = "Turn", Angle = -90, Radius = 1449.203 }, -- corner
		{ Type = "Straight", Length = 850 },
		{ Type = "Straight", Length = 850 },
		{ Type = "Turn", Angle = -90, Radius = 1449.203 }, -- corner
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 7, Radius = 1500 }, -- dead white tree grove
		{ Type = "Turn", Angle = -14, Radius = 1500 },
		{ Type = "Turn", Angle = 7, Radius = 1500 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -7, Radius = 1500 },
		{ Type = "Turn", Angle = 14, Radius = 1500 },
		{ Type = "Turn", Angle = -7, Radius = 1500 },
		{ Type = "Straight", Length = 200 },
		{ Type = "Slope", Length = 180, Rise = 20 }, -- low dune
		{ Type = "Straight", Length = 30 },
		{ Type = "Slope", Length = 180, Rise = -20 },
		{ Type = "Straight", Length = 130 },
		{ Type = "Slope", Length = 200, Rise = 34 }, -- white dune
		{ Type = "Straight", Length = 30 },
		{ Type = "Slope", Length = 200, Rise = -34 },
		{ Type = "Straight", Length = 746.292 },
		{ Type = "Turn", Angle = -90, Radius = 1449.203 }, -- corner
		{ Type = "Straight", Length = 190.092 }, -- finish straight
	},
}
