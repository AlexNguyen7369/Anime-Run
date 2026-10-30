-- Track 9 acceptance contract: volcanic advanced geometry with a technical hairpin.
-- w3 (owner 2026-10-30): Track 9 is about 17,595 studs (984 x 3 x 1.25^8, +-5 %) and laid out from its
--   researched biome (docs/TRACKS_AND_BIOMES_SPEC.md References); the IVS shape minimums below still hold.
return {
	Number = 9,
	Closed = false,
	MinStartFinishGap = 2,
	StraightEndsMin = 40,
	Checkpoint = true,
	WidePad = true,
	Biome = "Volcano",
	-- MinLength / MaxLength retired: the IVS length band is replaced by the target length below
	-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths", owner 2026-10-30)
	TargetLength = 984 * 3 * 1.25 ^ 8, -- Track 9: 984 x F x 1.25^(n-1), F = 3, +-5 % along the centre line
	NoOverlap = true, -- vs every other chained track, the plaza and the Dojo plots
	RunnerRuns = true, -- live route at normal and max stat speed: 0 flips, 0 off-track, pad paid once
	MinWidth = 36,
	MinRadius = 60,
	MinTurns = 2,
	MinPeakHeight = 30,
	MaxGradeDeg = 20,
	-- MinLapTime / MaxLapTime retired with the car lap bots (docs/WORLD_REDESIGN_SPEC.md section 2)
}
