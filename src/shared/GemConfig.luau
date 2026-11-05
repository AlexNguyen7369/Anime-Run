--!nonstrict
-- Gem amounts (design doc 4.35, docs/SIDEKICK_SPEC.md "Gems"). All placeholders.
local GemConfig = {}

GemConfig.Daily = 5 -- each daily task
GemConfig.Weekly = 25 -- each weekly task

-- Every win on Track n.
function GemConfig.TrackWin(n)
	return n
end

-- The win that raises BestTrack to n.
function GemConfig.FirstClear(n)
	return 10 * n
end

return GemConfig
