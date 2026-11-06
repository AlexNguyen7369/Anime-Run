--!nonstrict
-- BRIEF: design doc 4.37, docs/BOSS_EVENT_SPEC.md "Boss and attacks" (task b7b). Owner approved the key frames 2026-11-05
-- (assets/characters_avatar/boss_raga/keyframes/keys.json); approved keys stay unchanged. Moves are client-side visuals; the server reads only Schedule and Events, for attack stamina
-- (owner 2026-11-05, boss_event attack_stamina).
-- Contract these tests assume beyond the brief (implementer: report a change, do not loosen):
--   Shared/BossRagaPoses, generated:
--     Moves[name] = { Duration, Keys = { { Time, Parts = { [part] = ... } } }, Events = { { Time, Name } }, Approved = { times } };
--       idle's Approved is empty.
--     Approved[move] = { { Time, Parts = { [part] = { x, y, z } }, RootOffset = { x, y, z } } }, generated from keys.json.
--     Sample(move, t) returns parts, rootOffset: parts[part] is a Vector3 of XYZ Euler degrees, rootOffset a Vector3.
--     Schedule(startTime, now) returns move, localTime. startTime is the spawn, the start of the rise (BossEventStart +
--       PrepSeconds), so "idle" plays until startTime + IntroSeconds.
--     RiseAt(t): t is seconds since the spawn, clamped 0 to 1 over IntroSeconds.
-- wheel_spin in keys.json is not sampled: the Wheel's rotations already hold it.
-- On demand: ReplicatedStorage attributes CarTestOnly = "boss_anim", then CarTestRun = true.
local H = require(script.Parent.AcceptanceSupport)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Event = require(Shared.BossEventConfig)
local Tests = {}

local MOVES = { "attack", "shout", "wheel_turn" }
local DEGREE_TOLERANCE = 0.01
local OFFSET_TOLERANCE = 0.001
local FRAME = 1 / 60
-- The fastest approved segment is 3.33 degrees a frame if linear (attack's strike); this leaves room for easing.
local MAX_DEGREES_PER_FRAME = 12
local MAX_OFFSET_PER_FRAME = 0.05 -- the fastest approved segment is 0.0086 if linear
local IMPACT_WINDOW = 0.05 -- s around Impact and WheelClick where a snap is allowed
local CYCLES_SECONDS = 120 -- every move is seen this soon after the rise
local MIN_IDLE, MAX_IDLE = 1, 30 -- s
local KNOWN_PARTS = {
	"Head",
	"LeftFoot",
	"LeftHand",
	"LeftLowerArm",
	"LeftLowerLeg",
	"LeftUpperArm",
	"LeftUpperLeg",
	"LowerTorso",
	"RightFoot",
	"RightHand",
	"RightLowerArm",
	"RightLowerLeg",
	"RightUpperArm",
	"RightUpperLeg",
	"Sword",
	"Tail",
	"UpperTorso",
	"Wheel",
}
-- Copied by hand from keys.json, so that a generated table drifting from the approved file is caught.
local APPROVED_TIMES = {
	attack = { 0.7, 1.4, 1.75, 2.05, 2.9 },
	shout = { 0.45, 1, 1.35, 2.5 },
	wheel_turn = { 0, 0.3, 0.5, 0.7, 1 },
}
local APPROVED_ENDS = { attack = 3.6, shout = 3.4, wheel_turn = 1.6 }
local APPROVED_SPOTS = {
	{ "attack", 0.7, "RightUpperArm", Vector3.new(-15, 82, 0) },
	{ "attack", 2.9, "RightUpperArm", Vector3.new(-22, 28, 0) },
	{ "shout", 0.45, "RightUpperArm", Vector3.new(-34, 14, 0) },
	{ "shout", 2.5, "RightUpperArm", Vector3.new(0, 40, 0) },
	{ "wheel_turn", 0.7, "Wheel", Vector3.new(-15.34, 48.974, -11.692) },
}
local APPROVED_ROOTS = {
	{ "attack", 1.75, Vector3.new(0, 0.26, -0.28) },
	{ "shout", 1.35, Vector3.new(0, 0.1, -0.05) },
	{ "wheel_turn", 0.3, Vector3.new(0, 0, -0.04) },
}
-- Each named event once, at its approved moment: the strike to the blade biting the floor, the roar's rise, the click.
local EVENTS = {
	attack = { Name = "Impact", From = 1.75, To = 2.05 },
	shout = { Name = "Roar", From = 1, To = 1.35 },
	wheel_turn = { Name = "WheelClick", From = 0.65, To = 0.75 },
}

local function largest(v)
	return math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

local function fromList(list)
	return Vector3.new(list[1], list[2], list[3])
end

-- The biggest change of any part (and of the root) between two samples. A wheel's spoke step looks the same at the seam.
local function jump(partsA, rootA, partsB, rootB, skipWheel)
	local degrees = 0
	for _, part in KNOWN_PARTS do
		if not (skipWheel and part == "Wheel") then
			degrees = math.max(degrees, largest(partsA[part] - partsB[part]))
		end
	end
	return degrees, largest(rootA - rootB)
end

local function nearEvent(move, t)
	for _, event in move.Events do
		if (event.Name == "Impact" or event.Name == "WheelClick") and math.abs(event.Time - t) <= IMPACT_WINDOW then
			return true
		end
	end
	return false
end

function Tests.boss_anim()
	local r, flag = H.report("boss_anim")

	local function section(name, body)
		local ok, err = xpcall(body, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end

	local Poses = H.module(Shared, "BossRagaPoses")
	flag("poses_module_loads", Poses ~= nil)
	if not Poses then
		return r
	end

	section("structure", function()
		local known = {}
		for _, part in KNOWN_PARTS do
			known[part] = true
		end
		local unknown = {}
		for name, move in Poses.Moves do
			for _, key in move.Keys do
				for part in key.Parts do
					if not known[part] then
						unknown[name .. ":" .. tostring(part)] = true
					end
				end
			end
		end
		flag("keys_only_known_parts", next(unknown) == nil, next(unknown))
		flag("idle_exists", Poses.Moves.idle ~= nil)
		local idle = Poses.Moves.idle.Duration
		flag("idle_duration_bounds", idle >= MIN_IDLE and idle <= MAX_IDLE, idle)
		for _, name in MOVES do
			local move = Poses.Moves[name]
			flag(name .. "_exists", move ~= nil)
			local d = move.Duration
			flag(name .. "_duration_is_approved", math.abs(d - APPROVED_ENDS[name]) <= 0.01, d, APPROVED_ENDS[name])
			local last = -1
			local ordered = true
			for _, key in move.Keys do
				ordered = ordered and key.Time > last and key.Time <= d
				last = key.Time
			end
			flag(name .. "_keys_in_order", ordered)

			local spec = EVENTS[name]
			local found, placed = 0, true
			for _, event in move.Events do
				if event.Name == spec.Name then
					found += 1
					placed = placed and event.Time >= spec.From and event.Time <= spec.To
				end
			end
			flag(name .. "_has_one_" .. spec.Name, found == 1, found, 1)
			flag(name .. "_" .. spec.Name .. "_time", placed)
		end
	end)

	section("approved", function()
		for _, name in MOVES do
			local move = Poses.Moves[name]
			local times = APPROVED_TIMES[name]
			flag(name .. "_approved_count", #move.Approved == #times, #move.Approved, #times)
			flag(name .. "_expected_count", #Poses.Approved[name] == #times, #Poses.Approved[name], #times)
			for i, t in times do
				flag(name .. "_approved_time_" .. i, math.abs(move.Approved[i] - t) < 1e-6, move.Approved[i], t)
				local want = Poses.Approved[name][i]
				flag(name .. "_expected_time_" .. i, math.abs(want.Time - t) < 1e-6, want.Time, t)
				local parts, root = Poses.Sample(name, t)
				local worst = 0
				for _, part in KNOWN_PARTS do
					worst = math.max(worst, largest(parts[part] - fromList(want.Parts[part])))
				end
				flag(name .. "_sample_at_" .. t, worst <= DEGREE_TOLERANCE, worst, DEGREE_TOLERANCE)
				local rootError = largest(root - fromList(want.RootOffset))
				flag(name .. "_root_at_" .. t, rootError <= OFFSET_TOLERANCE, rootError, OFFSET_TOLERANCE)
			end
		end
		for _, spot in APPROVED_SPOTS do
			local parts = Poses.Sample(spot[1], spot[2])
			local e = largest(parts[spot[3]] - spot[4])
			flag(("keys_json_%s_%s_%s"):format(spot[1], spot[2], spot[3]), e <= DEGREE_TOLERANCE, e, DEGREE_TOLERANCE)
		end
		for _, spot in APPROVED_ROOTS do
			local _, root = Poses.Sample(spot[1], spot[2])
			local e = largest(root - spot[3])
			flag(("keys_json_%s_%s_root"):format(spot[1], spot[2]), e <= OFFSET_TOLERANCE, e, OFFSET_TOLERANCE)
		end
	end)

	section("continuous", function()
		for name, move in Poses.Moves do
			local worstDegrees, worstOffset, worstAt = 0, 0, 0
			local parts, root = Poses.Sample(name, 0)
			local frames = math.floor(move.Duration / FRAME)
			for k = 1, frames do
				local t = k * FRAME
				local nextParts, nextRoot = Poses.Sample(name, t)
				if not nearEvent(move, t) then
					local degrees, offset = jump(parts, root, nextParts, nextRoot)
					if degrees > worstDegrees then
						worstDegrees, worstAt = degrees, t
					end
					worstOffset = math.max(worstOffset, offset)
				end
				parts, root = nextParts, nextRoot
			end
			r.metrics[name .. "_worst_frame_at"] = worstAt
			flag(name .. "_frame_degrees", worstDegrees <= MAX_DEGREES_PER_FRAME, worstDegrees, MAX_DEGREES_PER_FRAME)
			flag(name .. "_frame_offset", worstOffset <= MAX_OFFSET_PER_FRAME, worstOffset, MAX_OFFSET_PER_FRAME)
		end
	end)

	section("schedule", function()
		local intro = Event.IntroSeconds
		local START = 5000
		local duringRise = true
		for t = -5, intro - 0.05, 0.1 do
			duringRise = duringRise and Poses.Schedule(START, START + t) == "idle"
		end
		flag("schedule_idle_during_rise", duringRise)

		local seen, agree, inRange, firstIdleGap = {}, true, true, false
		local previous = nil
		for t = intro, intro + CYCLES_SECONDS, 0.1 do
			local name, localTime = Poses.Schedule(START, START + t)
			local otherName, otherTime = Poses.Schedule(START + 1234.5, START + 1234.5 + t)
			agree = agree and name == otherName and math.abs(localTime - otherTime) < 1e-6
			seen[name] = true
			local move = Poses.Moves[name]
			inRange = inRange and move ~= nil and localTime >= 0 and localTime <= move.Duration + 1e-6
			firstIdleGap = firstIdleGap or (previous ~= nil and previous ~= "idle" and name == "idle")
			previous = name
		end
		flag("schedule_offsets_agree", agree)
		flag("schedule_local_time_in_range", inRange)
		flag("schedule_returns_to_idle", firstIdleGap)
		for _, name in MOVES do
			flag("schedule_covers_" .. name, seen[name] == true)
		end

		-- No shared state: asked out of order, or twice, the answer is the same.
		local at = START + intro + 77.7
		local name1, time1 = Poses.Schedule(START, at)
		Poses.Schedule(START, at + 500)
		Poses.Schedule(START + 9, at - 40)
		local name2, time2 = Poses.Schedule(START, at)
		flag("schedule_no_shared_state", name1 == name2 and time1 == time2)

		local far = 1e7
		local farName, farTime = Poses.Schedule(START, START + far)
		local farMove = Poses.Moves[farName]
		flag("schedule_loops_indefinitely", farMove ~= nil and farTime >= 0 and farTime <= farMove.Duration + 1e-6)

		-- The seams between moves are as smooth as the moves.
		local worst = 0
		local name, localTime = Poses.Schedule(START, START + intro)
		local parts, root = Poses.Sample(name, localTime)
		for k = 1, CYCLES_SECONDS * 60 do
			local nextName, nextTime = Poses.Schedule(START, START + intro + k * FRAME)
			local nextParts, nextRoot = Poses.Sample(nextName, nextTime)
			if not nearEvent(Poses.Moves[nextName], nextTime) then
				worst = math.max(worst, (jump(parts, root, nextParts, nextRoot, true)))
			end
			parts, root = nextParts, nextRoot
			if k % 600 == 0 then
				task.wait() -- 7,200 full samples: do not stall the harness
			end
		end
		flag("schedule_seams_degrees", worst <= MAX_DEGREES_PER_FRAME, worst, MAX_DEGREES_PER_FRAME)
	end)

	section("rise", function()
		local intro = Event.IntroSeconds
		flag("rise_starts_at_0", Poses.RiseAt(0) == 0, Poses.RiseAt(0), 0)
		flag("rise_ends_at_1", Poses.RiseAt(intro) == 1, Poses.RiseAt(intro), 1)
		flag("rise_clamped_before", Poses.RiseAt(-5) == 0, Poses.RiseAt(-5), 0)
		flag("rise_clamped_after", Poses.RiseAt(intro + 50) == 1, Poses.RiseAt(intro + 50), 1)
		local monotonic, last = true, 0
		for t = 0, intro, 0.05 do
			local value = Poses.RiseAt(t)
			monotonic = monotonic and value >= last
			last = value
		end
		flag("rise_monotonic", monotonic)
		local middle = Poses.RiseAt(intro / 2)
		flag("rise_moves_midway", middle > 0 and middle < 1, middle)
	end)

	return r
end

return Tests
