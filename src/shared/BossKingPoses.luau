--!nonstrict
-- Placeholder until tools/blender/bake_boss_king.py writes this file from assets/characters_avatar/boss_king/keyframes/keys.json.
-- The Golden King's schedule (design doc 4.37 "Third boss", docs/BOSS_EVENT_SPEC.md "The Golden King"), the same shape as
-- BossMagePoses: the server and BossDodge read Moves[*].Events, CycleSeconds and Schedule only. No keys yet: the bake adds them.
-- Every duration is proposed. Each Dodge bar move opens with a "<move>_start" event (cost 0: no bar, no charge): the moment that
-- ends Fortified, which the "shields" event sets (BossEventService).
local Event = require(script.Parent.BossEventConfig)

-- stylua: ignore
local MOVES = {
	idle = { Duration = 3, Events = {} },
	gates_in = { Duration = 0.75, Events = {} },
	-- Portals open over 2 s, then 2 s of volleys: the cost at the volleys' start, as the mage's lightning.
	gates = { Duration = 5, Events = {{ Time = 0, Name = "gates_start" }, { Time = 2, Name = "gates" }}, Window = { 2, 4 } },
	enuma_in = { Duration = 0.75, Events = {} },
	-- 3 s charge (the Dodge bar window), then the 2 s beam: the cost at the beam's start.
	enuma = { Duration = 5.4, Events = {{ Time = 0, Name = "enuma_start" }, { Time = 3, Name = "enuma" }}, Window = { 3, 5 } },
	shields_in = { Duration = 0.75, Events = {} },
	shields = { Duration = 2.4, Events = {{ Time = 1.5, Name = "shields" }} },
}
-- stylua: ignore
local CYCLE = {
	{"idle", 0, 3},
	{"gates_in"},
	{"gates"},
	{"idle", 0, 3},
	{"idle", 0, 3},
	{"enuma_in"},
	{"enuma"},
	{"idle", 0, 3},
	{"idle", 0, 3},
	{"shields_in"},
	{"shields"},
	{"idle", 0, 3},
}

local Poses = {}
Poses.Moves = MOVES

local cycleLength = 0
local cycle = {}
for _, row in CYCLE do
	local length = row[1] == "idle" and row[3] or MOVES[row[1]].Duration
	table.insert(
		cycle,
		{ Move = row[1], Start = cycleLength, From = row[1] == "idle" and row[2] or 0, Length = length }
	)
	cycleLength += length
end
Poses.CycleSeconds = cycleLength

-- The move and its local time. startTime is the spawn, the start of the rise; idle until startTime + IntroSeconds. Pure.
function Poses.Schedule(startTime, now)
	local since = now - startTime - Event.IntroSeconds
	if since < 0 then
		return "idle", since % MOVES.idle.Duration
	end
	local at = since % cycleLength
	for _, row in cycle do
		if at < row.Start + row.Length then
			return row.Move, math.min(row.From + at - row.Start, MOVES[row.Move].Duration)
		end
	end
	local last = cycle[#cycle]
	return last.Move, MOVES[last.Move].Duration
end

return Poses
