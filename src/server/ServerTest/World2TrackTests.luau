--!nonstrict
-- BRIEF: docs/WORLD2_SPEC.md "World 2 track layout" (owner 2026-11-26), docs/TRACKS_AND_BIOMES_SPEC.md "Lengths": the
-- layout half of World 2's ten track briefs (ServerTest/TrackTests/World2), with no live parts and no runner, so it runs
-- offline. The live half (checkpoint, collision, plaza, runner at normal and max speed) is Scenarios.track in Studio.
-- Per brief: target length +-5 %, TrackValidator Ok, first and last segments level straights >= StraightEndsMin, min
-- radius, turns, start-finish gap, no overlap with any other chained track, and the owner's road gap: road edge to any
-- other track's road edge >= MinRoadGap (pairs within TrackChainTests.ROAD_GAP_SKIP of chain through a joint skipped).
-- Offline: lune run tools/lune/server_scenarios 2 World2TrackTests.world2_tracks
-- In World 1 it checks nothing but that it is not World 2 (World 1's briefs are the track:<Name> scenarios).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrackChain = require(script.Parent.TrackChainTests)

local Tests = {}

function Tests.world2_tracks()
	local checks = {}
	local function check(name, value, limit, ok)
		table.insert(checks, { name = name, value = value, limit = limit, pass = ok == true })
	end
	if require(Shared.WorldConfig).Id ~= 2 then
		check("world1_not_checked", 1, 1, true)
		return { scenario = "world2_tracks", checks = checks }
	end
	local TrackBuilder = require(Shared.TrackBuilder)
	local TrackValidator = require(Shared.TrackValidator)
	local TrackRegistry = require(Shared.TrackRegistry)
	local briefs = script.Parent.TrackTests.World2
	local specs = TrackRegistry.Chain()
	local tracks = TrackChain.world(TrackBuilder, specs)
	check("briefs_cover_chain", #briefs:GetChildren(), #specs, #briefs:GetChildren() == #specs and #specs == 10)
	for i, spec in specs do
		local module = briefs:FindFirstChild(spec.Name)
		local pre = ("t%d_"):format(spec.Number)
		check(pre .. "brief_exists", module and 1 or 0, 1, module ~= nil)
		if module then
			local expect = require(module)
			local layout = tracks[i].Layout
			check(pre .. "number", spec.Number, expect.Number, spec.Number == expect.Number)
			local want = TrackChain.target(spec.Number)
			check(
				pre .. "target_length_formula",
				expect.TargetLength,
				want,
				math.abs(expect.TargetLength - want) < 1e-6
			)
			local err = math.abs(layout.Length - want) / want
			check(pre .. "target_length", layout.Length, want, err <= TrackChain.TOLERANCE)
			local v = TrackValidator.Validate(spec, layout)
			check(pre .. "track_valid", #v.Issues, 0, v.Ok)
			local segs = spec.Segments
			local first, last = segs[1], segs[#segs]
			local need = expect.StraightEndsMin
			check(
				pre .. "first_segment_straight",
				first.Length or 0,
				need,
				first.Type == "Straight" and first.Length >= need
			)
			check(
				pre .. "last_segment_straight",
				last.Length or 0,
				need,
				last.Type == "Straight" and last.Length >= need
			)
			local smallest, turns = math.huge, 0
			for _, seg in segs do
				if seg.Type == "Turn" then
					smallest = math.min(smallest, seg.Radius)
					turns += 1
				end
			end
			check(pre .. "min_radius", smallest, expect.MinRadius, smallest >= expect.MinRadius)
			check(pre .. "min_turns", turns, expect.MinTurns, turns >= expect.MinTurns)
			local sf = layout.EndPosition.Magnitude
			check(
				pre .. "start_finish_gap",
				sf,
				expect.MinStartFinishGap * layout.Width,
				sf >= expect.MinStartFinishGap * layout.Width
			)
			local ok, near = TrackChain.overlap(tracks, i)
			check(pre .. "no_overlap_other_tracks", near or -1, layout.Width + 8, ok)
			local gap = TrackChain.roadGap(tracks, i, expect.MinRoadGap + 100)
			check(pre .. "min_road_gap_other_tracks", gap, expect.MinRoadGap, gap >= expect.MinRoadGap)
		end
	end
	return { scenario = "world2_tracks", checks = checks }
end

return Tests
