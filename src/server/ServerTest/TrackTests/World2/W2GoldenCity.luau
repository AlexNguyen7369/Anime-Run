-- World 2 Track 9 acceptance contract (design doc 4.47, docs/WORLD2_SPEC.md "World 2 track layout", owner 2026-11-26).
-- Written before the wide layout: the IVS shape minimums World 1's briefs hold, plus the owner's road gap.
return {
	Number = 9,
	Closed = false,
	MinStartFinishGap = 2,
	StraightEndsMin = 40,
	Checkpoint = true,
	WidePad = true,
	Biome = "GoldenCity",
	TargetLength = 984 * 3 * 1.25 ^ 8, -- Track 9: 984 x F x 1.25^(n-1), F = 3, +-5 % along the centre line
	NoOverlap = true, -- vs every other chained track and the plaza
	MinRoadGap = 600, -- road edge to any other World 2 track's road edge (owner 2026-11-26; joint pairs within 1,200 of chain skipped)
	RunnerRuns = true, -- live route at normal and max stat speed: 0 flips, 0 off-track, pad paid once
	MinWidth = 36,
	MinRadius = 60,
	MinTurns = 1,
}
