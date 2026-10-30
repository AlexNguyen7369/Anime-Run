--!nonstrict
-- BRIEF: Track 5 "Serpentine": a point-to-point sprint with four alternating
--        90-degree direction changes and long entry, mid-course, and finish
--        straights. It must use the numbered ladder, keep its finish separate from
--        its start, and retain the shared straight-end, checkpoint, and left-side
--        winnings-pad contract.
-- Written by test-writer BEFORE the track implementation. Never loosen a limit to
-- make a track pass.
-- w3 (owner 2026-10-30): Track 5 is about 7,207 studs (984 x 3 x 1.25^4, +-5 %) and laid out from its
--   researched biome (docs/TRACKS_AND_BIOMES_SPEC.md References); the IVS shape minimums below still hold.
return {
	Number = 5,
	Closed = false,
	MinStartFinishGap = 2, -- at least two road widths between start and finish
	StraightEndsMin = 40, -- level straights are required at both chain boundaries
	Checkpoint = true,
	WidePad = true, -- wide finish area, left apron pad, right-hand RacePath
	-- MinLength / MaxLength retired: the IVS length band is replaced by the target length below
	-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths", owner 2026-10-30)
	TargetLength = 984 * 3 * 1.25 ^ 4, -- Track 5: 984 x F x 1.25^(n-1), F = 3, +-5 % along the centre line
	NoOverlap = true, -- vs every other chained track, the plaza and the Dojo plots
	RunnerRuns = true, -- live route at normal and max stat speed: 0 flips, 0 off-track, pad paid once
	MinWidth = 36,
	MinRadius = 60,
	MinTurns = 4, -- alternating 90-degree corners
	-- MinLapTime / MaxLapTime retired with the car lap bots (docs/WORLD_REDESIGN_SPEC.md section 2)
}
