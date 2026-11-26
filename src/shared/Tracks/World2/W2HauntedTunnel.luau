--!nonstrict
-- World 2 Track 4 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): Haunted Tunnel Road run.
-- Route: World 2's square spiral of long straights (WORLD2_SPEC "World 2 track layout", owner 2026-11-26; pitch 760
-- and corner radius 420 proposed), the target length of docs/TRACKS_AND_BIOMES_SPEC.md "Lengths". Palette proposed.
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
		{ Type = "Straight", Length = 591.9067 }, -- start straight
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 2340 },
		{ Type = "Turn", Angle = -90, Radius = 420 }, -- corner
		{ Type = "Straight", Length = 1514.2243 }, -- finish straight
	},
}
