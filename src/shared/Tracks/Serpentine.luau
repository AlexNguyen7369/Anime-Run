--!nonstrict
-- Track 5 (w3, owner 2026-10-30; redesigned 2026-10-31): Burning Cursed City: a burning avenue, crossing jinks, over
-- the meteor crater and up the rubble mound past the broken viaduct, to a finish under a split tower.
-- About 984 x 3 x 1.25^4 studs along the centre line (docs/TRACKS_AND_BIOMES_SPEC.md Lengths and References).
-- Laid out on the outward square spiral round the plaza (docs/WORLD_REDESIGN_SPEC.md section 3): right-hand
-- corners grow with each lap, so this track sits one lap band outside the previous one.
return {
	Name = "Serpentine",
	Description = "Burning Cursed City run: a burning avenue, crossing jinks, the meteor crater and a rubble mound.",
	Number = 5,
	Biome = "PirateCoast",
	Width = 36,
	Closed = false,
	-- orchestrator default 2026-10-31, builder choice: burnt-concrete road lighter than the night ground so it reads,
	-- dim ember-red walls, flame-yellow lines (Track 5 Burning Cursed City palette)
	Palette = {
		Road = Color3.fromHex("4A4246"),
		Support = Color3.fromHex("4A4448"),
		Wall = Color3.fromHex("7A2A20"),
		Ground = Color3.fromHex("1E1618"),
		Line = Color3.fromHex("FFC23D"),
		Checkpoint = Color3.fromHex("FF6A1A"),
		WinPad = Color3.fromHex("DCE2F0"),
	},
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
		{ Type = "Slope", Length = 160, Rise = 18 }, -- up over the meteor crater
		{ Type = "Straight", Length = 80 },
		{ Type = "Slope", Length = 160, Rise = -18 },
		{ Type = "Straight", Length = 578 },
		{ Type = "Turn", Angle = -90, Radius = 305 }, -- corner
		{ Type = "Straight", Length = 200 },
		{ Type = "Slope", Length = 200, Rise = 30 }, -- up the rubble mound
		{ Type = "Straight", Length = 60 },
		{ Type = "Slope", Length = 200, Rise = -30 },
		{ Type = "Straight", Length = 640 },
		{ Type = "Turn", Angle = -90, Radius = 305 }, -- corner
		{ Type = "Straight", Length = 765.255 }, -- finish straight
	},
}
