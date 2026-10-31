--!nonstrict
-- Track 7 (w3, owner 2026-10-30): Sakura Shrine Path: cherry blossom avenues, stone stairs up to the hilltop shrine and switchback bends on the shrine hill.
-- About 984 x 3 x 1.25^6 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
-- Owner 2026-10-30: every bend is at least 320 studs in radius, so the NPC rival (Shared/NpcRacer grip limit) holds
-- its cruise speed and its time matches the TRACKS_AND_BIOMES_SPEC table.
return {
	Name = "Desert",
	Description = "Sakura Shrine Path run: blossom avenues, gate tunnels, shrine stairs and switchback bends.",
	Number = 7,
	Biome = "Desert",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromRGB(112, 82, 66),
		Support = Color3.fromRGB(90, 55, 40),
		Wall = Color3.fromRGB(218, 157, 82),
		Ground = Color3.fromRGB(210, 157, 78),
		Line = Color3.fromRGB(255, 238, 172),
		Checkpoint = Color3.fromRGB(164, 108, 56),
		WinPad = Color3.fromRGB(255, 218, 42),
	},
	Segments = {
		{ Type = "Straight", Length = 40 }, -- start straight
		{ Type = "Turn", Angle = -90, Radius = 350 }, -- corner
		{ Type = "Straight", Length = 180 },
		{ Type = "Turn", Angle = 16, Radius = 320 }, -- cherry blossom avenue sweep
		{ Type = "Turn", Angle = -32, Radius = 320 },
		{ Type = "Turn", Angle = 16, Radius = 320 },
		{ Type = "Straight", Length = 120 },
		{ Type = "Slope", Length = 220, Rise = 34 }, -- stone stairs up to the hilltop shrine
		{ Type = "Straight", Length = 60 },
		{ Type = "Slope", Length = 220, Rise = -34 },
		{ Type = "Straight", Length = 462.184 },
		{ Type = "Turn", Angle = -90, Radius = 395 }, -- corner
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 20, Radius = 320 }, -- switchback bends on the shrine hill
		{ Type = "Turn", Angle = -40, Radius = 320 },
		{ Type = "Turn", Angle = 20, Radius = 320 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -20, Radius = 320 },
		{ Type = "Turn", Angle = 40, Radius = 320 },
		{ Type = "Turn", Angle = -20, Radius = 320 },
		{ Type = "Straight", Length = 572.428 },
		{ Type = "Turn", Angle = -90, Radius = 395 }, -- corner
		{ Type = "Straight", Length = 130 },
		{ Type = "Turn", Angle = 16, Radius = 320 }, -- cherry blossom avenue sweep
		{ Type = "Turn", Angle = -32, Radius = 320 },
		{ Type = "Turn", Angle = 16, Radius = 320 },
		{ Type = "Straight", Length = 260 },
		{ Type = "Slope", Length = 220, Rise = 34 }, -- stone stairs up to the hilltop shrine
		{ Type = "Straight", Length = 60 },
		{ Type = "Slope", Length = 220, Rise = -34 },
		{ Type = "Straight", Length = 495.947 },
		{ Type = "Turn", Angle = -90, Radius = 395 }, -- corner
		{ Type = "Straight", Length = 120 },
		{ Type = "Turn", Angle = 20, Radius = 320 }, -- switchback bends on the shrine hill
		{ Type = "Turn", Angle = -40, Radius = 320 },
		{ Type = "Turn", Angle = 20, Radius = 320 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -20, Radius = 320 },
		{ Type = "Turn", Angle = 40, Radius = 320 },
		{ Type = "Turn", Angle = -20, Radius = 320 },
		{ Type = "Straight", Length = 240 },
		{ Type = "Turn", Angle = 16, Radius = 320 }, -- cherry blossom avenue sweep
		{ Type = "Turn", Angle = -32, Radius = 320 },
		{ Type = "Turn", Angle = 16, Radius = 320 },
		{ Type = "Straight", Length = 330.007 },
		{ Type = "Turn", Angle = -90, Radius = 395 }, -- corner
		{ Type = "Straight", Length = 200 },
		{ Type = "Slope", Length = 220, Rise = 34 }, -- stone stairs up to the hilltop shrine
		{ Type = "Straight", Length = 60 },
		{ Type = "Slope", Length = 220, Rise = -34 },
		{ Type = "Straight", Length = 473.565 }, -- finish straight
	},
}
