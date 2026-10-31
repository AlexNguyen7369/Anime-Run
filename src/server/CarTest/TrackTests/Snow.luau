-- Track 8 acceptance contract: frozen pass with rolling terrain and a hairpin.
-- w3 (owner 2026-10-30): Track 8 is about 14,076 studs (984 x 3 x 1.25^7, +-5 %) and laid out from its
--   researched biome (docs/TRACKS_AND_BIOMES_SPEC.md References); the IVS shape minimums below still hold.
return {
	Number = 8,
	Closed = false,
	MinStartFinishGap = 2,
	StraightEndsMin = 40,
	Checkpoint = true,
	WidePad = true,
	Biome = "Snow",
	-- MinLength / MaxLength retired: the IVS length band is replaced by the target length below
	-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths", owner 2026-10-30)
	TargetLength = 984 * 3 * 1.25 ^ 7, -- Track 8: 984 x F x 1.25^(n-1), F = 3, +-5 % along the centre line
	NoOverlap = true, -- vs every other chained track, the plaza and the Dojo plots
	RunnerRuns = true, -- live route at normal and max stat speed: 0 flips, 0 off-track, pad paid once
	MinWidth = 36,
	MinRadius = 60,
	MinTurns = 3,
	MinPeakHeight = 20,
	MaxGradeDeg = 20,
	-- MinLapTime / MaxLapTime retired with the car lap bots (docs/WORLD_REDESIGN_SPEC.md section 2)
}
