--!nonstrict
-- BRIEF: Track 3 "DragRace": a short, straight point-to-point sprint after Hill.
--        Keep the numbered ladder, separate start and finish, straight ends, the
--        new target length (below), and the shared checkpoint/left-pad contract.
-- Written by test-writer BEFORE the track implementation. Never loosen a limit
-- to make a track pass.
-- w3 (owner 2026-10-30): Track 3 is about 4,612 studs (984 x 3 x 1.25^2, +-5 %) and laid out from its
--   researched biome (docs/TRACKS_AND_BIOMES_SPEC.md References); the IVS shape minimums below still hold.
return {
	Number = 3,
	Closed = false,
	MinStartFinishGap = 2, -- at least two road widths between start and finish
	StraightEndsMin = 40, -- the sprint is straight into and out of its joins
	Checkpoint = true,
	WidePad = true, -- wide checkpoint, left-apron pad, right-hand RacePath
	-- MinLength / MaxLength retired: the IVS length band is replaced by the target length below
	-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths", owner 2026-10-30)
	TargetLength = 984 * 3 * 1.25 ^ 2, -- Track 3: 984 x F x 1.25^(n-1), F = 3, +-5 % along the centre line
	NoOverlap = true, -- vs every other chained track, the plaza and the Dojo plots
	RunnerRuns = true, -- live route at normal and max stat speed: 0 flips, 0 off-track, pad paid once
	MinWidth = 36,
	MinRadius = 60, -- the shared corner floor; a straight has no tighter turn
	-- MinLapTime / MaxLapTime retired with the car lap bots (docs/WORLD_REDESIGN_SPEC.md section 2)
}
