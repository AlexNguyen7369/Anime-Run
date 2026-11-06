--!nonstrict
-- Sidekick follow motion, pure (design doc 4.36; docs/SIDEKICK_SPEC.md "Display"). Contract: Server/CarTest/SidekickFollowTests.
-- Drawn by Client/SidekickFollower. All distances and rates are placeholders. Offset is on the runner's right; the client mirrors it.
local HttpService = game:GetService("HttpService")

local RunnerFactory = require(script.Parent.RunnerFactory)

local SidekickFollow = {}

SidekickFollow.MaxFollowers = 7

local HEIGHT = 2.2 -- studs: the large end of the 1.7-2.3 rule, as the owner wants them very visible (2026-11-05)
local HEIGHTS = { side_raga = 2 } -- docs/char_evidence/side_raga.md: its small-size detail is sized for 2 studs

local SHOULDER = RunnerFactory.HIP_HEIGHT
for _, part in RunnerFactory.PARTS do
	if part[1] == "Torso" then
		SHOULDER += part[2].Y / 2
	end
end

-- Arena lanes are about 11.4 studs wide and a runner's arm reaches 1.44 from its centre.
local WALK_SIDE = 3
local FLY_SIDE = 4 -- wider: the crow's wingspan is 5 studs at this height
local AHEAD = 1.5 -- studs in front of the runner, so the track camera has it in frame
local BOB, BOB_RATE = 0.2, 4 -- studs, rad/s
local DRIFT, DRIFT_RATE = 0.35, 1.3 -- studs, rad/s: the slow orbit around the shoulder

-- Trot by id. Bob is studs at full trot, Lean radians forward, Cadence times the runner's stride, Tail radians of bounce.
local TROT = { Bob = 0.16, Lean = math.rad(7), Cadence = 1 }
local TROTS = {
	side_chain = { Bob = 0.2, Lean = math.rad(5), Cadence = 1.25, Tail = math.rad(28) },
	side_knight = { Bob = 0.1, Lean = math.rad(16), Cadence = 1 },
}

function SidekickFollow.Size(id)
	return HEIGHTS[id] or HEIGHT
end

function SidekickFollow.Trot(id)
	return TROTS[id] or TROT
end

-- From the runner's feet to the follower's centre, at time t s.
function SidekickFollow.Offset(row, t)
	if row.Movement == "Fly" then
		return Vector3.new(
			FLY_SIDE + DRIFT * math.cos(t * DRIFT_RATE),
			SHOULDER + BOB * math.sin(t * BOB_RATE),
			-AHEAD + DRIFT * math.sin(t * DRIFT_RATE)
		)
	end
	return Vector3.new(WALK_SIDE, SidekickFollow.Size(row.Id) / 2, -AHEAD)
end

local function decode(text)
	if type(text) ~= "string" then
		return nil
	end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, text)
	return ok and type(value) == "table" and value or nil
end

-- The Sidekick id that character wears, from the replicated player attributes SidekickGear and SidekickBag.
function SidekickFollow.WornId(gearJson, bagJson, characterId)
	local gear, bag = decode(gearJson), decode(bagJson)
	local entry = gear and gear[characterId]
	if not (bag and entry) then
		return nil
	end
	for _, item in bag do
		if type(item) == "table" and item.Entry == entry then
			return item.Id
		end
	end
	return nil
end

return SidekickFollow
