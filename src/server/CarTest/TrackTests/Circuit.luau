--!nonstrict
-- BRIEF: Track 4 "Circuit": a technical point-to-point circuit with four 90-degree
--        corners and two S-bends (eight direction-change turns total). It must use
--        the numbered track ladder, have straight join/finish ends, stay at least
--        two road widths from its start at the finish, and retain the shared
--        checkpoint and left-side winnings-pad contract.
-- Written by test-writer BEFORE the track implementation. Never loosen a limit to
-- make a track pass.
-- w3 (owner 2026-10-30): Track 4 is about 5,766 studs (984 x 3 x 1.25^3, +-5 %) and laid out from its
--   researched biome (docs/TRACKS_AND_BIOMES_SPEC.md References); the IVS shape minimums below still hold.
return {
	Number = 4,
	Closed = false, -- every numbered route is point-to-point; the finish is not the start
	MinStartFinishGap = 2, -- at least two road widths between start and finish
	StraightEndsMin = 40, -- straight into the previous finish and straight at this finish
	Checkpoint = true,
	WidePad = true, -- wide finish area, left apron pad, right-hand RacePath
	-- MinLength / MaxLength retired: the IVS length band is replaced by the target length below
	-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths", owner 2026-10-30)
	TargetLength = 984 * 3 * 1.25 ^ 3, -- Track 4: 984 x F x 1.25^(n-1), F = 3, +-5 % along the centre line
	NoOverlap = true, -- vs every other chained track, the plaza and the Dojo plots
	RunnerRuns = true, -- live route at normal and max stat speed: 0 flips, 0 off-track, pad paid once
	MinWidth = 36,
	MinRadius = 60,
	MinTurns = 8, -- four 90-degree corners plus two two-part S-bends
	-- MinLapTime / MaxLapTime retired with the car lap bots (docs/WORLD_REDESIGN_SPEC.md section 2)
}
