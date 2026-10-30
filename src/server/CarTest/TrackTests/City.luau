-- Track 6 acceptance contract: long city route, broad turns, and biome metadata.
return {
	Number = 6,
	Closed = false,
	MinStartFinishGap = 2,
	StraightEndsMin = 40,
	Checkpoint = true,
	WidePad = true,
	Biome = "City",
	MinLength = 1400,
	MaxLength = 1900,
	MinWidth = 36,
	MinRadius = 60,
	MinTurns = 4,
	-- MinLapTime / MaxLapTime retired with the car lap bots (docs/WORLD_REDESIGN_SPEC.md section 2)
}
