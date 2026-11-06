--!nonstrict
-- BRIEF: Sidekick follow motion (design doc 4.36; docs/SIDEKICK_SPEC.md "Display"; task b7d), the pure Shared/SidekickFollow.
-- The drawn follower is judged by Client/UiTest/UiSidekickFollow. Follow motion only: attacks wait for the owner's key frames.
-- Contract (implementer: report a change, do not loosen):
--   Size(id): target height in studs of the whole model, 1.7-2.3, for every id in List and BossDrops.
--   Offset(row, t): a Vector3 in the runner's frame (x right, y up), from the runner's feet to the follower's centre, at time t s.
--   MaxFollowers: 7, the most followers drawn at once.
--   WornId(gearJson, bagJson, characterId): the Sidekick id that character wears, from the replicated player attributes
--   SidekickGear and SidekickBag, which every client can read. Nil for nothing worn, an entry not in the bag, or bad JSON.
local H = require(script.Parent.AcceptanceSupport)
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.SidekickConfig)
local RunnerFactory = require(Shared.RunnerFactory)

local SIZE_MIN, SIZE_MAX = 1.7, 2.3
local RAGA_NATIVE = 9.237 -- docs/char_evidence/side_raga.md: the model's own height
local RAGA_SCALE, RAGA_SLACK = 0.217, 0.01
local WALK_LIFT = 0.3 -- studs its feet may sit above the ground
local WALK_SINK = 0.05
local BESIDE_MAX = 6 -- studs from the runner's centre
local SHOULDER_SLACK = 1 -- studs
local BOB_MIN, BOB_MAX = 0.05, 0.8 -- studs, whole range: gentle, but it moves
local BOB_STEP = 0.1 -- studs in one 0.05 s sample: no jumps
local SAMPLE_DT, SAMPLE_SECONDS = 0.05, 20

local Tests = {}

local function rows()
	local all = {}
	for _, list in { Config.List, Config.BossDrops } do
		for _, row in list do
			table.insert(all, row)
		end
	end
	return all
end

-- The rig's outer edge and shoulder height, from its feet.
local function bodyOf()
	local half, shoulder = 0, 0
	for _, part in RunnerFactory.PARTS do
		half = math.max(half, math.abs(part[3].X) + part[2].X / 2)
		if part[1] == "Torso" then
			shoulder = RunnerFactory.HIP_HEIGHT + part[2].Y / 2
		end
	end
	return half, shoulder
end

local function checkMotion(flag, Follow, row, bodyHalf, shoulder)
	local id = row.Id
	local height = Follow.Size(id)
	local lowest, highest, jump, beside, wide = math.huge, -math.huge, 0, true, true
	local last = nil
	for i = 0, SAMPLE_SECONDS / SAMPLE_DT do
		local offset = Follow.Offset(row, i * SAMPLE_DT)
		lowest, highest = math.min(lowest, offset.Y), math.max(highest, offset.Y)
		if last then
			jump = math.max(jump, math.abs(offset.Y - last))
		end
		last = offset.Y
		beside = beside and math.abs(offset.X) >= bodyHalf
		wide = wide and math.abs(offset.X) <= BESIDE_MAX
	end
	flag("follow_beside_" .. id, beside and wide)
	if row.Movement == "Walk" then
		flag(
			"follow_walk_on_ground_" .. id,
			lowest - height / 2 >= -WALK_SINK and highest - height / 2 <= WALK_LIFT,
			lowest
		)
	else
		flag(
			"follow_fly_at_shoulder_" .. id,
			math.abs(lowest - shoulder) <= SHOULDER_SLACK and math.abs(highest - shoulder) <= SHOULDER_SLACK,
			lowest
		)
		flag("follow_fly_bobs_" .. id, highest - lowest >= BOB_MIN and highest - lowest <= BOB_MAX, highest - lowest)
		flag("follow_fly_bob_smooth_" .. id, jump <= BOB_STEP, jump)
	end
	flag("follow_same_time_same_offset_" .. id, Follow.Offset(row, 3.3) == Follow.Offset(row, 3.3))
	return lowest, highest
end

function Tests.sidekick_follow()
	local r, flag = H.report("sidekick_follow")
	flag("follow_no_server_instances", workspace:FindFirstChild("SidekickFollowers") == nil)
	local Follow = H.module(Shared, "SidekickFollow")
	flag("follow_module_present", Follow ~= nil)
	if not Follow then
		return r
	end
	flag("follow_budget_seven", Follow.MaxFollowers == 7, Follow.MaxFollowers, 7)

	local bodyHalf, shoulder = bodyOf()
	local highestWalk, lowestFly = -math.huge, math.huge
	for _, row in rows() do
		local height = Follow.Size(row.Id)
		flag("follow_size_" .. row.Id, type(height) == "number" and height >= SIZE_MIN and height <= SIZE_MAX, height)
		flag("follow_movement_known_" .. row.Id, row.Movement == "Walk" or row.Movement == "Fly")
		if type(height) == "number" then
			local lowest, highest = checkMotion(flag, Follow, row, bodyHalf, shoulder)
			if row.Movement == "Walk" then
				highestWalk = math.max(highestWalk, highest)
			else
				lowestFly = math.min(lowestFly, lowest)
			end
		end
	end
	flag("follow_fly_always_above_walk", lowestFly > highestWalk, lowestFly - highestWalk)

	local ragaHeight = Follow.Size("side_raga")
	local ragaScale = type(ragaHeight) == "number" and ragaHeight / RAGA_NATIVE or 0
	flag("follow_raga_scale", math.abs(ragaScale - RAGA_SCALE) <= RAGA_SLACK, ragaScale, RAGA_SCALE)

	local bag = HttpService:JSONEncode({ { Id = "side_chain", Entry = "a" }, { Id = "side_wyvern", Entry = "b" } })
	local gear = HttpService:JSONEncode({ hero = "a", other = "gone" })
	flag("follow_worn_id", Follow.WornId(gear, bag, "hero") == "side_chain")
	flag("follow_worn_per_character", Follow.WornId(gear, bag, "nobody") == nil)
	flag("follow_worn_entry_not_in_bag", Follow.WornId(gear, bag, "other") == nil)
	flag("follow_worn_no_attributes", Follow.WornId(nil, nil, "hero") == nil)
	flag(
		"follow_worn_bad_json",
		Follow.WornId("{not json", bag, "hero") == nil and Follow.WornId(gear, "junk", "hero") == nil
	)
	return r
end

return Tests
