--!nonstrict
-- Track 8 (w3, owner 2026-10-30): Sky Islands: hops onto floating islands, vine bridges between them and bends under the waterfalls.
-- About 984 x 3 x 1.25^7 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
-- Owner 2026-10-30: every bend is at least 638 studs in radius, so the NPC rival (Shared/NpcRacer grip limit) holds
-- its cruise speed and its time matches the TRACKS_AND_BIOMES_SPEC table.
return {
	Name = "Snow",
	Description = "Sky Islands run: island hops, vine bridges and waterfall bends above the clouds.",
	Number = 8,
	Biome = "Snow",
	Width = 40,
	Closed = false,
	Palette = {
		-- b2 (orchestrator default 2026-10-31): a warm weathered-stone road with dark rock supports, so it reads
		-- against the white cloud deck and the green island tops; ruin-stone walls, sky-blue checkpoints.
		Road = Color3.fromRGB(168, 140, 104),
		Support = Color3.fromRGB(110, 94, 76),
		Wall = Color3.fromRGB(214, 206, 190),
		Ground = Color3.fromRGB(124, 195, 106),
		Line = Color3.fromRGB(250, 246, 232),
		Checkpoint = Color3.fromRGB(63, 143, 210),
		WinPad = Color3.fromRGB(255, 218, 42),
	},
	Segments = {
		{ Type = "Straight", Length = 560.197 },
		{ Type = "Turn", Angle = -90, Radius = 638.395 }, -- corner
		{ Type = "Straight", Length = 180 },
		{ Type = "Slope", Length = 160, Rise = 28 }, -- hop onto a floating island
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 160, Rise = -28 },
		{ Type = "Straight", Length = 120 },
		{ Type = "Turn", Angle = 12, Radius = 680 }, -- vine bridge between islands
		{ Type = "Turn", Angle = -24, Radius = 680 },
		{ Type = "Turn", Angle = 12, Radius = 680 },
		{ Type = "Straight", Length = 474.48 },
		{ Type = "Turn", Angle = -90, Radius = 638.395 }, -- corner
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 10, Radius = 680 }, -- under the waterfalls
		{ Type = "Turn", Angle = -20, Radius = 680 },
		{ Type = "Turn", Angle = 10, Radius = 680 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -10, Radius = 680 },
		{ Type = "Turn", Angle = 20, Radius = 680 },
		{ Type = "Turn", Angle = -10, Radius = 680 },
		{ Type = "Straight", Length = 582.571 },
		{ Type = "Turn", Angle = -90, Radius = 638.395 }, -- corner
		{ Type = "Straight", Length = 130 },
		{ Type = "Slope", Length = 160, Rise = 28 }, -- hop onto a floating island
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 160, Rise = -28 },
		{ Type = "Straight", Length = 260 },
		{ Type = "Turn", Angle = 12, Radius = 680 }, -- vine bridge between islands
		{ Type = "Turn", Angle = -24, Radius = 680 },
		{ Type = "Turn", Angle = 12, Radius = 680 },
		{ Type = "Straight", Length = 611.33 },
		{ Type = "Turn", Angle = -90, Radius = 638.395 }, -- corner
		{ Type = "Straight", Length = 120 },
		{ Type = "Turn", Angle = 10, Radius = 680 }, -- under the waterfalls
		{ Type = "Turn", Angle = -20, Radius = 680 },
		{ Type = "Turn", Angle = 10, Radius = 680 },
		{ Type = "Straight", Length = 40 },
		{ Type = "Turn", Angle = -10, Radius = 680 },
		{ Type = "Turn", Angle = 20, Radius = 680 },
		{ Type = "Turn", Angle = -10, Radius = 680 },
		{ Type = "Straight", Length = 240 },
		{ Type = "Slope", Length = 160, Rise = 28 }, -- hop onto a floating island
		{ Type = "Straight", Length = 40 },
		{ Type = "Slope", Length = 160, Rise = -28 },
		{ Type = "Straight", Length = 150 },
		{ Type = "Turn", Angle = 12, Radius = 680 }, -- vine bridge between islands
		{ Type = "Turn", Angle = -24, Radius = 680 },
		{ Type = "Turn", Angle = 12, Radius = 680 },
		{ Type = "Straight", Length = 107.86 },
		{ Type = "Turn", Angle = -90, Radius = 638.395 }, -- corner
		{ Type = "Straight", Length = 593.322 }, -- finish straight
	},
}
