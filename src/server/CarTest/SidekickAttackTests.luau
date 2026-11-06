--!nonstrict
-- BRIEF: design doc 4.37, docs/BOSS_EVENT_SPEC.md "Boss and attacks", docs/SIDEKICK_SPEC.md (task b7d). The owner approved all 12
-- attacks' key frames (assets/characters_avatar/<id>/keyframes/keys.json); approved keys stay unchanged. Client-side visuals only.
-- Contract these tests assume beyond the brief (implementer: report a change, do not loosen):
--   Shared/SidekickAttacks, generated:
--     Attacks[id] = { Duration, Release = { t, ... }, Keys = { { Time, Parts = { [part] = ... }, ... } }, Approved = { ... } }.
--     Approved = { { Time, Parts = { [part] = { x, y, z } }, RootOffset = { [root] = { x, y, z } } } }, generated from keys.json.
--     Sample(id, t) returns parts, roots: parts[part] and roots[root] are Vector3s (XYZ Euler degrees, model units), every part and
--       every root at every t. t is clamped to 0..Duration; both ends are the rest pose with zero offsets.
--     side_raga: { Duration = 0, Release = { 0 }, Keys = {}, Approved = {}, NeedsOwnerApproval = true }, and Sample returns {}, {}.
--       Design doc 4.37 reviews every Sidekick attack as key frames, and it has none approved: a simple shot, no poses, flagged.
-- On demand: ReplicatedStorage attributes CarTestOnly = "sidekick_attacks", then CarTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.SidekickConfig)
local Tests = {}

local DEGREE_TOLERANCE = 0.01
local OFFSET_TOLERANCE = 0.001
local TIME_TOLERANCE = 1e-6
local FRAME = 1 / 60
-- Easing peaks at about 1.5 times the linear speed; the limit is twice it plus this slack, per frame.
local DEGREE_SLACK, OFFSET_SLACK = 1, 0.01

-- Copied by hand from keys.json, so that a generated table drifting from the approved file is caught.
-- Speed and RootSpeed: the fastest approved segment if linear, degrees and model units a frame at 60 fps.
local APPROVED = {
	side_chain = {
		Duration = 1.35,
		Release = { 0.7 },
		Times = { 0.25, 0.5, 0.7, 1 },
		Parts = { "Bar", "Body", "Handle", "LegBackL", "LegBackR", "LegFrontL", "LegFrontR", "Tail" },
		Roots = { "Body" },
		Spots = { { 0.7, "LegFrontL", Vector3.new(-58, 0, 0), { Body = Vector3.new(0, -0.3, 0.181) } } },
		Rest = { Bar = Vector3.new(0, 0, 32) },
		Speed = 9.17,
		RootSpeed = 0.025,
	},
	side_wyvern = {
		Duration = 1.4,
		Release = { 0.75 },
		Times = { 0.45, 0.75, 1, 1.2 },
		Parts = {
			"Body",
			"BodyNeon",
			"Head",
			"HeadNeon",
			"LegLeft",
			"LegNeonLeft",
			"LegNeonRight",
			"LegRight",
			"Neck",
			"NeckNeon",
			"Tail",
			"TailNeon",
			"WingLeft",
			"WingNeonLeft",
			"WingNeonRight",
			"WingRight",
		},
		Roots = { "Body" },
		Spots = { { 0.75, "WingLeft", Vector3.new(0, 42, -6), { Body = Vector3.new(0, -0.25, -0.15) } } },
		Speed = 4.44,
		RootSpeed = 0.0306,
	},
	side_knight = {
		Duration = 1.4,
		Release = { 0.6 },
		Times = { 0.3, 0.6, 0.85, 1.15 },
		Parts = { "Head", "LeftArm", "LeftLeg", "RightArm", "RightLeg", "Sword", "Torso" },
		Roots = { "Torso" },
		Spots = { { 0.6, "Sword", Vector3.new(170, 0, 0), { Torso = Vector3.new(0, -0.5, -0.055) } } },
		Speed = 9.17,
		RootSpeed = 0.0278,
	},
	side_pig = {
		Duration = 1.3,
		Release = { 0.55 },
		Times = { 0.3, 0.55, 0.8, 1.05 },
		Parts = {
			"Body",
			"Head",
			"HeadEarLeft",
			"HeadEarRight",
			"LegBackLeft",
			"LegBackRight",
			"LegFrontLeft",
			"LegFrontRight",
			"Tail",
		},
		Roots = { "Body" },
		Spots = { { 0.55, "HeadEarLeft", Vector3.new(70, -30, 0), { Body = Vector3.new(0, -0.25, 0.31) } } },
		Speed = 7,
		RootSpeed = 0.0333,
	},
	side_crow = {
		Duration = 1.2,
		Release = { 0.5 },
		Times = { 0.3, 0.5, 0.8 },
		Parts = { "Body", "Head", "LegLeft", "LegRight", "Tail", "WingLeft", "WingRight" },
		Roots = { "Body" },
		Spots = { { 0.5, "WingLeft", Vector3.new(0, 42, -52), { Body = Vector3.new(0, -0.2, -0.15) } } },
		Speed = 7.83,
		RootSpeed = 0.0375,
	},
	side_reindeer = {
		Duration = 1.2,
		Release = { 0.5 },
		Times = { 0.3, 0.5, 0.8 },
		Parts = {
			"ArmLeft",
			"ArmRight",
			"Body",
			"Head",
			"HeadAntlerLeft",
			"HeadAntlerRight",
			"HeadHat",
			"LegLeft",
			"LegRight",
		},
		Roots = { "Body" },
		Spots = { { 0.5, "ArmRight", Vector3.new(-92, 0, -32), { Body = Vector3.new(0, -0.45, 0.062) } } },
		Speed = 13.5,
		RootSpeed = 0.0542,
	},
	side_dogs = {
		Duration = 1.35,
		Release = { 0.5, 0.75 },
		Times = { 0.25, 0.5, 0.75, 1.05 },
		Parts = {
			"BlackBody",
			"BlackHead",
			"BlackHeadJaw",
			"BlackLegBackLeft",
			"BlackLegBackRight",
			"BlackLegFrontLeft",
			"BlackLegFrontRight",
			"BlackTail",
			"WhiteBody",
			"WhiteHead",
			"WhiteHeadJaw",
			"WhiteLegBackLeft",
			"WhiteLegBackRight",
			"WhiteLegFrontLeft",
			"WhiteLegFrontRight",
			"WhiteTail",
		},
		Roots = { "BlackBody", "WhiteBody" },
		Spots = {
			{
				0.5,
				"WhiteHeadJaw",
				Vector3.new(58, 0, 0),
				{ BlackBody = Vector3.new(0, 0.3, 0.36), WhiteBody = Vector3.new(0, -0.5, 0.554) },
			},
			{
				0.75,
				"BlackHeadJaw",
				Vector3.new(58, 0, 0),
				{ BlackBody = Vector3.new(0, -0.5, 0.554), WhiteBody = Vector3.new(0, -0.2, 0.27) },
			},
		},
		Speed = 4.67,
		RootSpeed = 0.0533,
	},
	side_ant = {
		Duration = 1.4,
		Release = { 0.4 },
		Times = { 0.2, 0.4, 0.6, 0.8, 1.1 },
		Parts = {
			"Gaster",
			"Head",
			"HeadNeon",
			"LeftArm",
			"LeftArmNeon",
			"LeftLeg",
			"LeftLegNeon",
			"RightArm",
			"RightArmNeon",
			"RightLeg",
			"RightLegNeon",
			"Torso",
			"TorsoNeon",
		},
		Roots = { "Torso" },
		Spots = { { 0.4, "RightArm", Vector3.new(-120, 55, 0), { Torso = Vector3.new(0, -0.5, 0.208) } } },
		Speed = 11.67,
		RootSpeed = 0.0417,
	},
	side_reaper = {
		Duration = 1.4,
		Release = { 0.7 },
		Times = { 0.35, 0.7, 0.95, 1.2 },
		Parts = { "Head", "LeftArm", "LeftLeg", "RightArm", "RightLeg", "Torso", "WingLeft", "WingRight" },
		Roots = { "Torso" },
		Spots = { { 0.7, "LeftArm", Vector3.new(-165, 28, 0), { Torso = Vector3.new(0, 0, 0.35) } } },
		Speed = 9,
		RootSpeed = 0.0286,
	},
	side_fist = {
		Duration = 1.35,
		Release = { 0.38 },
		Times = { 0.2, 0.38, 0.55, 0.72, 1.05 },
		Parts = {
			"FloatHips",
			"FloatLegLeft",
			"FloatLegRight",
			"FloatShinLeft",
			"FloatShinRight",
			"Hair",
			"Head",
			"LeftArm",
			"RightArm",
			"Scarf",
			"Torso",
		},
		Roots = { "Torso" },
		Spots = { { 0.38, "RightArm", Vector3.new(-92, -14, 0), { Torso = Vector3.new(0, -0.45, 0) } } },
		Rest = {
			FloatLegLeft = Vector3.new(16, 0, 0),
			FloatLegRight = Vector3.new(26, 0, 0),
			FloatShinLeft = Vector3.new(14, 0, 0),
			FloatShinRight = Vector3.new(18, 0, 0),
			RightArm = Vector3.new(-68, 0, 0),
		},
		Speed = 17.84,
		RootSpeed = 0.0694,
	},
	side_curse = {
		Duration = 1.45,
		Release = { 0.75 },
		Times = { 0.4, 0.75, 1, 1.25 },
		Parts = { "Body", "Crest", "Head", "LeftArm", "RightArm", "Tail" },
		Roots = { "Body" },
		Spots = { { 0.75, "LeftArm", Vector3.new(20, -50, 0), { Body = Vector3.new(0, 0.3, 0.3) } } },
		Speed = 6,
		RootSpeed = 0.0433,
	},
	side_fox = {
		Duration = 1.45,
		Release = { 0.95 },
		Times = { 0.35, 0.7, 0.95, 1.2 },
		Parts = {
			"Body",
			"Head",
			"LegBackLeft",
			"LegBackRight",
			"LegFrontLeft",
			"LegFrontRight",
			"Tail1",
			"Tail2",
			"Tail3",
			"Tail4",
			"Tail5",
			"Tail6",
			"Tail7",
			"Tail8",
			"Tail9",
		},
		Roots = { "Body" },
		Spots = { { 0.95, "LegFrontLeft", Vector3.new(-44, -12, 0), { Body = Vector3.new(0, -0.25, 0.026) } } },
		Speed = 6.13,
		RootSpeed = 0.04,
	},
}

local function largest(v)
	return math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

local function fromList(list)
	return Vector3.new(list[1], list[2], list[3])
end

-- Sample's keys are exactly `names`, each holding a Vector3.
local function sameNames(tableOf, names)
	local seen = 0
	for _, name in names do
		if typeof(tableOf[name]) ~= "Vector3" then
			return false
		end
		seen += 1
	end
	for _ in tableOf do
		seen -= 1
	end
	return seen == 0
end

-- The biggest gap to the rest pose: any part against its rest, any root against zero.
local function restError(row, parts, roots)
	local degrees, offset = 0, 0
	for _, part in row.Parts do
		degrees = math.max(degrees, largest(parts[part] - (row.Rest and row.Rest[part] or Vector3.zero)))
	end
	for _, root in row.Roots do
		offset = math.max(offset, largest(roots[root]))
	end
	return degrees, offset
end

function Tests.sidekick_attacks()
	local r, flag = H.report("sidekick_attacks")

	local function section(name, body)
		local ok, err = xpcall(body, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end

	-- The server decides hits, not poses. Source reads only with plugin rights, not in a play server.
	section("server_independent", function()
		local readable, source = pcall(function()
			return script.Parent.Parent.BossEventService.Source
		end)
		if readable then
			flag("service_does_not_require_attacks", not string.find(source, "SidekickAttacks", 1, true))
		else
			r.metrics.service_source_unreadable = true
		end
	end)

	local Attacks = H.module(Shared, "SidekickAttacks")
	flag("attacks_module_loads", Attacks ~= nil)
	if not Attacks then
		return r
	end

	section("every_sidekick", function()
		for _, list in { Config.List, Config.BossDrops } do
			for _, row in list do
				flag("attack_for_" .. row.Id, Attacks.Attacks[row.Id] ~= nil)
			end
		end
	end)

	for id, row in APPROVED do
		section(id, function()
			local attack = Attacks.Attacks[id]
			flag(id .. "_exists", attack ~= nil)
			flag(id .. "_not_flagged", attack.NeedsOwnerApproval == nil)
			flag(
				id .. "_duration",
				math.abs(attack.Duration - row.Duration) <= TIME_TOLERANCE,
				attack.Duration,
				row.Duration
			)

			flag(id .. "_release_count", #attack.Release == #row.Release, #attack.Release, #row.Release)
			for i, t in row.Release do
				local got = attack.Release[i]
				flag(("%s_release_%d"):format(id, i), got ~= nil and math.abs(got - t) <= TIME_TOLERANCE, got, t)
			end

			local last, ordered = -1, true
			for _, key in attack.Keys do
				ordered = ordered and key.Time > last and key.Time <= attack.Duration
				last = key.Time
			end
			flag(id .. "_keys_in_order", ordered and #attack.Keys >= #row.Times, #attack.Keys, #row.Times)

			flag(id .. "_approved_count", #attack.Approved == #row.Times, #attack.Approved, #row.Times)
			for i, t in row.Times do
				local approved = attack.Approved[i]
				flag(
					("%s_approved_time_%d"):format(id, i),
					math.abs(approved.Time - t) <= TIME_TOLERANCE,
					approved.Time,
					t
				)
				local parts, roots = Attacks.Sample(id, t)
				local worst, worstRoot = 0, 0
				for _, part in row.Parts do
					worst = math.max(worst, largest(parts[part] - fromList(approved.Parts[part])))
				end
				for _, root in row.Roots do
					worstRoot = math.max(worstRoot, largest(roots[root] - fromList(approved.RootOffset[root])))
				end
				flag(("%s_sample_at_%s"):format(id, t), worst <= DEGREE_TOLERANCE, worst, DEGREE_TOLERANCE)
				flag(("%s_root_at_%s"):format(id, t), worstRoot <= OFFSET_TOLERANCE, worstRoot, OFFSET_TOLERANCE)
			end

			for _, spot in row.Spots do
				local parts, roots = Attacks.Sample(id, spot[1])
				local e = largest(parts[spot[2]] - spot[3])
				flag(("%s_keys_json_%s_%s"):format(id, spot[1], spot[2]), e <= DEGREE_TOLERANCE, e, DEGREE_TOLERANCE)
				for root, want in spot[4] do
					local offset = largest(roots[root] - want)
					flag(
						("%s_keys_json_%s_%s"):format(id, spot[1], root),
						offset <= OFFSET_TOLERANCE,
						offset,
						OFFSET_TOLERANCE
					)
				end
			end

			-- Starts and ends at rest, so a follower is never left posed, and a stray time cannot break it.
			for tag, t in { start = 0, finish = row.Duration, before = -1, after = row.Duration + 5 } do
				local parts, roots = Attacks.Sample(id, t)
				flag(("%s_%s_all_parts"):format(id, tag), sameNames(parts, row.Parts))
				flag(("%s_%s_all_roots"):format(id, tag), sameNames(roots, row.Roots))
				local degrees, offset = restError(row, parts, roots)
				flag(("%s_%s_rest"):format(id, tag), degrees <= DEGREE_TOLERANCE, degrees, DEGREE_TOLERANCE)
				flag(("%s_%s_rest_root"):format(id, tag), offset <= OFFSET_TOLERANCE, offset, OFFSET_TOLERANCE)
			end

			-- Continuous: no snap anywhere in the attack, at or between the keys.
			local worstDegrees, worstOffset, namesKept = 0, 0, true
			local parts, roots = Attacks.Sample(id, 0)
			for k = 1, math.ceil(row.Duration / FRAME) do
				local nextParts, nextRoots = Attacks.Sample(id, math.min(k * FRAME, row.Duration))
				namesKept = namesKept and sameNames(nextParts, row.Parts) and sameNames(nextRoots, row.Roots)
				for _, part in row.Parts do
					worstDegrees = math.max(worstDegrees, largest(nextParts[part] - parts[part]))
				end
				for _, root in row.Roots do
					worstOffset = math.max(worstOffset, largest(nextRoots[root] - roots[root]))
				end
				parts, roots = nextParts, nextRoots
			end
			local maxDegrees = row.Speed * 2 + DEGREE_SLACK
			local maxOffset = row.RootSpeed * 2 + OFFSET_SLACK
			flag(id .. "_names_every_frame", namesKept)
			flag(id .. "_frame_degrees", worstDegrees <= maxDegrees, worstDegrees, maxDegrees)
			flag(id .. "_frame_offset", worstOffset <= maxOffset, worstOffset, maxOffset)

			-- Moves in between: a held pose would pass everything above if the keys were only hit exactly.
			local a = Attacks.Sample(id, row.Times[1] / 2)
			local moved = 0
			for _, part in row.Parts do
				moved = math.max(moved, largest(a[part] - (row.Rest and row.Rest[part] or Vector3.zero)))
			end
			flag(id .. "_moves_between_keys", moved > DEGREE_TOLERANCE, moved)
		end)
	end

	section("side_raga", function()
		local attack = Attacks.Attacks.side_raga
		flag("raga_exists", attack ~= nil)
		flag("raga_flagged_for_owner", attack.NeedsOwnerApproval == true)
		flag("raga_no_keys", #attack.Keys == 0, #attack.Keys, 0)
		flag("raga_nothing_approved", #attack.Approved == 0, #attack.Approved, 0)
		flag("raga_duration", attack.Duration == 0, attack.Duration, 0)
		flag("raga_releases_at_once", attack.Release[1] == 0 and #attack.Release == 1)
		local parts, roots = Attacks.Sample("side_raga", 0.3)
		flag("raga_no_poses", next(parts) == nil and next(roots) == nil)
	end)

	return r
end

return Tests
