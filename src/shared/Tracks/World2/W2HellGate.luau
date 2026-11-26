--!nonstrict
-- World 2 Track 10 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Hell's Gate run.
-- Same route as World 1's Track 10 (Space), so its length, spiral lap and validator results carry over
-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths"); only the biome, palette and copy are new. Palette proposed.
return {
	Name = "W2HellGate",
	Description = "Hell's Gate run: a red sky over endless doors, floating stairs and a field of giant hands.",
	Number = 10,
	Biome = "HellGate",
	Width = 40,
	Closed = false,
	Palette = {
		Road = Color3.fromHex("3A1A1A"),
		Support = Color3.fromHex("220E0E"),
		Wall = Color3.fromHex("5A2222"),
		Ground = Color3.fromHex("2A0E0E"),
		Line = Color3.fromHex("FF4A2A"),
		Checkpoint = Color3.fromHex("FFD0D0"),
		WinPad = Color3.fromRGB(255, 205, 70),
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
