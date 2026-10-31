--!nonstrict
-- BRIEF: Track 1 "Oval" (Number 1): easy beginner point-to-point oval, Closed=false. Two long straights,
--        a wide 180 degree hairpin, then a 90 degree turn and a short finish straight, so the FINISH is a
--        different place from the START (>= 2 road widths apart). Keep the old bands (length now TargetLength, below):
--        width >= 36, MinRadius 60, MinTurns 2, lap time 10-40 s.
-- CHANGE (user): wider checkpoint area, winnings pad off to the LEFT; the car auto-races on the plain centre line
--               (no swing over the pad) and is paid when it passes the pad. Checkpoint zone is CHECKPOINT_LENGTH=60.
-- Written by test-writer BEFORE the track. Never loosen a limit to make a track pass.
-- w3 (owner 2026-10-30): Track 1 is about 2,952 studs (984 x 3 x 1.25^0, +-5 %) and laid out from its
--   researched biome (docs/TRACKS_AND_BIOMES_SPEC.md References); the IVS shape minimums below still hold.
return {
	Number = 1,
	Closed = false, -- point-to-point: finish is not the start
	MinStartFinishGap = 2, -- road widths between start and finish
	StraightEndsMin = 40, -- first and last segments are straights of at least 40 studs
	Checkpoint = true,
	WidePad = true, -- wide CheckpointArea, pad on the LEFT apron, RacePath is the RIGHT-HAND lane, LANE_OFFSET=10 right of the centre line (pad beside it, abeam at PadIndex)
	-- MinLength / MaxLength retired: the IVS length band is replaced by the target length below
	-- (docs/TRACKS_AND_BIOMES_SPEC.md "Lengths", owner 2026-10-30)
	TargetLength = 984 * 3 * 1.25 ^ 0, -- Track 1: 984 x F x 1.25^(n-1), F = 3, +-5 % along the centre line
	NoOverlap = true, -- vs every other chained track, the plaza and the Dojo plots
	RunnerRuns = true, -- live route at normal and max stat speed: 0 flips, 0 off-track, pad paid once
	MinWidth = 36,
	MinRadius = 60, -- beginner friendly: no tight corners
	MinTurns = 2, -- the 180 hairpin and the 90 turn
	-- MinLapTime / MaxLapTime retired with the car lap bots (docs/WORLD_REDESIGN_SPEC.md section 2)
}
