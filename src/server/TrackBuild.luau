--!nonstrict
-- Build after join (docs/GAME_DESIGN_REQUIREMENTS.md 4.25): Main.server builds Tracks 1-5 before the join, then the
-- rest one per frame in Order. A track Main marked pending is not built yet; RaceService holds a run that would start
-- on or cross into one (run.Holding, car attribute RunHold). Every other number counts as built (test routes).
-- Each Workspace.Track model gets attribute BuiltAt = os.clock() once fully built (Main.server).
local RunService = game:GetService("RunService")

local TrackBuild = {}

local pending, override = {}, {}

-- Main.server: `number` is (true) or is no longer (nil) waiting to be built
function TrackBuild.SetPending(number, on)
	pending[number] = on or nil
end

function TrackBuild.IsBuilt(number)
	local forced = override[number]
	if forced ~= nil then
		return forced
	end
	return not pending[number]
end

-- Test hook: false forces `number` unbuilt, true built, nil clears. Does nothing on a live server.
function TrackBuild.SetBuiltOverride(number, value)
	if RunService:IsStudio() then
		override[number] = value
	end
end

-- Pure: the build queue. remaining: unbuilt track numbers; playerTracks: the track each player is on or a held run
-- waits on. Tracks a player is on (p) or headed to (p + 1) first, ascending; then by min |n - p| over players, ties
-- lower number first; no players: ascending. Returns a new list.
function TrackBuild.Order(remaining, playerTracks)
	local function key(n)
		local d = math.huge
		for _, p in playerTracks do
			d = math.min(d, (n == p or n == p + 1) and -1 or math.abs(n - p))
		end
		return d
	end
	local out = table.clone(remaining)
	table.sort(out, function(a, b)
		local ka, kb = key(a), key(b)
		if ka ~= kb then
			return ka < kb
		end
		return a < b
	end)
	return out
end

return TrackBuild
