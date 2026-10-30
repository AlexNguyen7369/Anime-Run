--!nonstrict
-- Pass/fail limits used by the server-side CarTest harness for the runner on the race rail
-- (docs/WORLD_REDESIGN_SPEC.md section 2). Only change a target on purpose (it is a game-feel decision, not a bug fix).
-- The car physics limits (static_settle, accel, brake, skidpad) were scrapped with the car body (section 1).

return {
	lap = {
		MaxOffTrackSeconds = 3,
		MaxFlips = 0,
		MinUpY = 0.3,
		MinUpYStrict = 0.9, -- user: the runner must not flip or tilt by any means
	},
	race = {
		MaxPathDeviation = 5, -- studs from the route, start (after 3 s) to the last checkpoint
		MinUpY = 0.9,
		MaxFlips = 0,
	},
}
