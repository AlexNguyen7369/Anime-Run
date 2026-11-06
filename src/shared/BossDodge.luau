--!nonstrict
-- The Dodge bar's clock (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Dodge bar"). Pure: server and client read the same moments and
-- the same spot, so a prompt needs no network traffic. Times are seconds after the intro's end. A moment's index counts every
-- attack, shout and wheel turn of the event from 1. Numbers are placeholders.
local Cfg = require(script.Parent.BossEventConfig)
local Poses = require(script.Parent.BossRagaPoses)

local BossDodge = {}

BossDodge.SweepSeconds = 1.5 -- owner: 1 to 2 s
BossDodge.SpotWidth = 0.14 -- of the bar
-- The window ends at least 0.35 s before the moment: a press in it reaches the server before the moment is charged.
local SPOT_MIN, SPOT_MAX = 0.25, 0.69 -- the spot's centre, of the bar; the start is the owner's "a couple meters" clear
BossDodge.ResultSeconds = 1.5
BossDodge.HitText = {
	Impact = "You were hit by Raga's Slice",
	Roar = "Raga yelled, you are intimidated",
	WheelClick = "Raga has adapted to you",
}
BossDodge.DodgeText = "Nice Dodge!"
BossDodge.StarArt = "rbxassetid://103522228947626" -- assets/ui/dodge_star.png

-- Event name -> its moments in one schedule cycle. Read off the shared schedule, so every client's animation and the server
-- agree. Rounded to the 3 places the schedule's times are written in.
BossDodge.Events = {}
local SCAN_STEP = 0.01 -- s: shorter than any row of the schedule
for _, move in Poses.Moves do
	for _, moveEvent in move.Events do
		BossDodge.Events[moveEvent.Name] = {}
	end
end
local list = {} -- every moment of one cycle, in time order: { At, Name }
do
	local lastMove, lastLocal = nil, 0
	for k = 0, math.ceil(Poses.CycleSeconds / SCAN_STEP) - 1 do
		local since = k * SCAN_STEP
		local move, localTime = Poses.Schedule(-Cfg.IntroSeconds, since)
		if move ~= lastMove or localTime < lastLocal then
			for _, moveEvent in Poses.Moves[move].Events do
				local at = math.round((since - localTime + moveEvent.Time) * 1000) / 1000
				table.insert(BossDodge.Events[moveEvent.Name], at)
				table.insert(list, { At = at, Name = moveEvent.Name })
			end
		end
		lastMove, lastLocal = move, localTime
	end
	table.sort(list, function(a, b)
		return a.At < b.At
	end)
end

-- Moment `index` -> its time and event name.
function BossDodge.Moment(index)
	local cycles = (index - 1) // #list
	local row = list[index - cycles * #list]
	return cycles * Poses.CycleSeconds + row.At, row.Name
end

-- The index of the last moment at or before `since`, 0 if none.
function BossDodge.IndexAtOrBefore(since)
	if since < 0 then
		return 0
	end
	local cycles = math.floor(since / Poses.CycleSeconds)
	local inCycle = since - cycles * Poses.CycleSeconds
	local count = 0
	for _, row in list do
		count += row.At <= inCycle and 1 or 0
	end
	return cycles * #list + count
end

-- Where the spot's centre sits on the bar for this player and moment, 0 to 1.
function BossDodge.Spot(userId, startAt, index)
	local random = Random.new((userId % 1e6) * 31337 + (math.floor(startAt) % 1e6) * 613 + index * 7919)
	random:NextNumber() -- nearby seeds start alike
	return SPOT_MIN + random:NextNumber() * (SPOT_MAX - SPOT_MIN)
end

-- The spot as times, for a bar reaching its end at `momentAt`, on momentAt's clock.
function BossDodge.Window(spot, momentAt)
	local start = momentAt - BossDodge.SweepSeconds
	return start + (spot - BossDodge.SpotWidth / 2) * BossDodge.SweepSeconds,
		start + (spot + BossDodge.SpotWidth / 2) * BossDodge.SweepSeconds
end

return BossDodge
