--!nonstrict
-- BRIEF: Track 2 "Hill" (Number 2): same idea as before (hills on the straights, slightly harder than Oval)
--        but point-to-point, Closed=false, ONE 180 degree turn (right turn) instead of two, finish
--        different from start. Length is now TargetLength (below); width >= 36, MinRadius 60, MinPeakHeight 24,
--        MaxGradeDeg 20, lap 15-60 s, but MinTurns = 1 (the second turn was removed by the user).
-- CHANGE (user): wider checkpoint area, winnings pad off to the LEFT; the car auto-races on the plain centre line
--               (no swing over the pad) and is paid when it passes the pad. Checkpoint zone is CHECKPOINT_LENGTH=60.
-- Written by test-writer BEFORE the track. Never loosen a limit to make a track pass.
-- w3 (owner 2026-10-30): Track 2 is about 3,690 studs (984 x 3 x 1.25^1, +-5 %) and laid out from its
--   researched biome (docs/TRACKS_AND_BIOMES_SPEC.md References); the IVS shape minimums below still hold.
return {
	Number = 2,
	Closed = false,
	MinStartFinishGap = 2,
	StraightEndsMin = 40,
	Checkpoint = true,
	WidePad = true, -- wide CheckpointArea, pad on the LEFT apron, RacePath is the RIGHT-HAND lane, LANE_OFFSET=10 right of the centre line (pad beside it, abeam at PadIndex)
	-- MinLength / MaxLength retired: the IVS length band is replaced by the target length below
	-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths", owner 2026-10-30)
	TargetLength = 984 * 3 * 1.25 ^ 1, -- Track 2: 984 x F x 1.25^(n-1), F = 3, +-5 % along the centre line
	NoOverlap = true, -- vs every other chained track, the plaza and the Dojo plots
	RunnerRuns = true, -- live route at normal and max stat speed: 0 flips, 0 off-track, pad paid once
	MinWidth = 36, -- never narrower than Oval, beginner friendly
	MinRadius = 60, -- no tighter than Oval: the challenge is the hills, not the corners
	MinTurns = 1, -- the single 180 degree right turn
	MinPeakHeight = 24, -- must genuinely climb: about 30 studs intended, so a flat track fails
	MaxGradeDeg = 20, -- smooth hills the car can climb: about 16 degrees intended
	-- MinLapTime / MaxLapTime retired with the car lap bots (docs/WORLD_REDESIGN_SPEC.md section 2)
}
