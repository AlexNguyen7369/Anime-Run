--!nonstrict
-- The Dodge bar's clock (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Dodge bar"). Pure: server and client read the same moments and
-- the same spot, so a prompt needs no network traffic. Times are seconds after the intro's end. A moment's index counts every
-- attack, shout and wheel turn of the event from 1. Numbers are placeholders.
local BossCatalog = require(script.Parent.BossCatalog)
local Cfg = require(script.Parent.BossEventConfig)
local LateData = require(script.Parent.LateData)
local RunService = game:GetService("RunService")

local BossDodge = {}

local SWEEPS = { 1.5, 1.1 } -- by stage. Owner: 1 to 2 s, faster in Phase 2
BossDodge.SweepSeconds = SWEEPS[1]
BossDodge.SpotWidth = 0.125 -- of the bar
-- The window ends about 0.35 s before the moment: a press in it reaches the server before the moment is charged.
-- The spot's centre by stage, of the bar; the start is the owner's "a couple meters" clear.
local SPOTS = { { 0.25, 0.69 }, { 0.25, 0.62 } }
BossDodge.ResultSeconds = 1.5
BossDodge.HitText = {
	Impact = "You were hit by Raga's Slice",
	Roar = "Raga yelled, you are intimidated",
	WheelClick = "Raga has adapted to you",
	Lightning = "You were struck by her lightning", -- proposed
	Barrage = "You were blasted by her barrage", -- proposed
	Slam = "The golem crushed you", -- proposed
	Sweep = "The golem swept you", -- proposed
}
BossDodge.DodgeText = "Nice Dodge!"
BossDodge.StarArt = "rbxassetid://103522228947626" -- assets/ui/dodge_star.png

-- A boss's schedule, read once: Events (event name -> its moments in one cycle), List (every moment of one cycle, in time order:
-- { At, Name }) and Cycle. Read off the shared schedule, so every client's animation and the server agree. Rounded to the 3 places
-- the schedule's times are written in.
local SCAN_STEP = 0.01 -- s: shorter than any row of the schedule
local function scan(Poses, events)
	local list = {}
	for _, move in Poses.Moves do
		for _, moveEvent in move.Events do
			events[moveEvent.Name] = {}
		end
	end
	local lastMove, lastLocal = nil, 0
	for k = 0, math.ceil(Poses.CycleSeconds / SCAN_STEP) - 1 do
		local since = k * SCAN_STEP
		local move, localTime = Poses.Schedule(-Cfg.IntroSeconds, since)
		if move ~= lastMove or localTime < lastLocal then
			for _, moveEvent in Poses.Moves[move].Events do
				local at = math.round((since - localTime + moveEvent.Time) * 1000) / 1000
				table.insert(events[moveEvent.Name], at)
				table.insert(list, { At = at, Name = moveEvent.Name })
			end
		end
		lastMove, lastLocal = move, localTime
	end
	table.sort(list, function(a, b)
		return a.At < b.At
	end)
	return { List = list, Events = events, Cycle = Poses.CycleSeconds }
end

BossDodge.Events = {} -- Big Raga's, filled when his schedule is first read

local schedules, poses = {}, {}
-- Join size (design doc 7): a boss's pose data reaches a client with its first event, so it is read on first use.
-- boss: an id, nil for Big Raga. Returns the boss's id.
local function load(boss)
	local id = BossCatalog.Get(boss).Id
	if not schedules[id] then
		local bossPoses = LateData.Get(BossCatalog.Get(id).Poses)
		if not schedules[id] then -- another caller built it while this one waited
			poses[id] = bossPoses
			schedules[id] = scan(bossPoses, id == BossCatalog.Default and BossDodge.Events or {})
		end
	end
	return id
end

local function scheduleOf(boss)
	return schedules[load(boss)]
end

function BossDodge.EventsOf(boss)
	return scheduleOf(boss).Events
end

function BossDodge.SweepFor(stage)
	return SWEEPS[stage]
end

-- Moment `index` of the boss's schedule -> its time and event name.
function BossDodge.Moment(index, boss)
	local schedule = scheduleOf(boss)
	local list = schedule.List
	local cycles = (index - 1) // #list
	local row = list[index - cycles * #list]
	return cycles * schedule.Cycle + row.At, row.Name
end

-- The index of the last moment at or before `since`, 0 if none.
function BossDodge.IndexAtOrBefore(since, boss)
	if since < 0 then
		return 0
	end
	local schedule = scheduleOf(boss)
	local list = schedule.List
	local cycles = math.floor(since / schedule.Cycle)
	local inCycle = since - cycles * schedule.Cycle
	local count = 0
	for _, row in list do
		count += row.At <= inCycle and 1 or 0
	end
	return cycles * #list + count
end

-- The golem slot of the boss's cycle (s after the intro, in its first cycle) and the cycle's length; nil for a boss without one.
function BossDodge.Slot(boss)
	local Poses = poses[load(boss)]
	if Poses.GolemSlotAt then
		return Poses.GolemSlotAt, Poses.CycleSeconds
	end
	return nil
end

-- Golem attack k (from 1, per golem) -> its time in s since BossMinionStart and its event name.
function BossDodge.MinionMoment(k, boss)
	return poses[load(boss)].GolemHit(k)
end

-- The number of the last golem attack at or before `tau` s since BossMinionStart, 0 if none.
function BossDodge.MinionIndexAtOrBefore(tau, boss)
	local Poses = poses[load(boss)]
	local since = math.round((tau - Poses.GolemFirstHit) * 1000) / 1000
	if since < 0 then
		return 0
	end
	return math.floor(since / Poses.GolemEvery) + 1
end

-- Where the spot's centre sits on the bar for this player and moment, 0 to 1.
function BossDodge.Spot(userId, startAt, index, stage)
	local random = Random.new((userId % 1e6) * 31337 + (math.floor(startAt) % 1e6) * 613 + index * 7919)
	random:NextNumber() -- nearby seeds start alike
	local low, high = SPOTS[stage][1], SPOTS[stage][2]
	return low + random:NextNumber() * (high - low)
end

-- The spot as times, for a bar reaching its end at `momentAt`, on momentAt's clock.
function BossDodge.Window(spot, momentAt, stage)
	local sweep = SWEEPS[stage]
	local start = momentAt - sweep
	return start + (spot - BossDodge.SpotWidth / 2) * sweep, start + (spot + BossDodge.SpotWidth / 2) * sweep
end

-- The server reads every boss up front: ServerStorage, so no network cost; a client loads only the boss it is shown (load).
if RunService:IsServer() then
	for _, id in BossCatalog.Order do
		load(id)
	end
end

return BossDodge
