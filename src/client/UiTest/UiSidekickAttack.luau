--!nonstrict
-- Sidekick attacks at the boss (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Boss and attacks", docs/SIDEKICK_SPEC.md; task b7d). Owned by
-- ui-test-writer. Fixtures: UiTestSetup sidekick_follow_*, with sidekick_follow_hits sending fake Remotes.BossHits batches to this
-- client. Pose data's own contract: Server/CarTest/SidekickAttackTests. Effects are approved from a Studio capture (spec's owner gate).
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   Client/SidekickAttackView, a module the client loads. It draws what Remotes.BossHits brings, whatever the event's state; the
--   server only sends it to event players.
--   Folder workspace.AttackEffects: every effect lives in it. Not under workspace.SidekickFollowers: ui_sidekick_follow counts
--   that folder's children as followers.
--   Each direct child is a BasePart or Model with attributes Kind ("Shot" or "Impact"), OwnerId (the entry's UserId), SidekickId, and
--   Particles: what it asks for, emitted plus Rate x lifetime, reduced or not. A Shot also has Effect: a name, one per Sidekick.
--   Effect is "Simple" for side_raga, which has no approved attack, and for every shot under REDUCED EFFECTS.
--   No effect part can collide, query or touch.
--   A Shot moves toward the boss: BigRaga when built, else BossArenaConfig.Center. An Impact lands at the boss.
--   Impact appears about 0.4 s after the batch arrives, whatever the attack's Release time: a long wind-up is entered part way.
--   DamageNumber: a BillboardGui or TextLabel of that name under AttackEffects or PlayerGui, shown at the impact, its text holding the
--   damage. An entry whose id or owner is unknown draws no follower pose and raises no error. An entry whose id is not the one its
--   follower wears still fires its shot, with no pose.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig"))
local Catalog = require(Shared:WaitForChild("CharacterCatalog"))

local WAIT = 5 -- s: a follower may need a frame or a model load
local MODELS_WAIT = 30 -- s
local REMOTE_WAIT = 10 -- s
local GONE_LIMIT = 4 -- s, the brief's limit: a shot appears and is gone
local QUIET = 0.3 -- s the folder stays empty before a hit counts as gone
local NO_SHOT_WAIT = 1 -- s an entry that draws nothing is watched
local ARRIVE_MIN, ARRIVE_MAX = 0.25, 0.65 -- s after the batch: "about 0.4 s", with a frame's slack
local BOSS_REACH = 300 -- studs sideways from the arena's centre: the boss is 560 tall
local MIN_POSE = 15 -- degrees the attack turns the watched part from rest; each is at least 40 in keys.json
local POSE_LEFT = 2 -- degrees
local POSE_WAIT = 2 -- s: an attack is at most 1.45 s
local TOTAL_PARTICLES, REDUCED_PARTICLES = 400, 60 -- 400 the brief's, 60 proposed
local CROWD = 6 -- with the local player, the 7 lanes
local FAKE_ID = -1001 -- UiTestSetup's first crowd runner
local LOCAL_DAMAGE, OTHER_DAMAGE = 77, 88
local GROUP = 3 -- entries per batch when comparing others against local
local BUDGET = 120 -- s: the whole scenario

-- The watched part, a non-wing part the Release pose turns far from rest (keys.json), and its root.
local ATTACKS = {
	{ Id = "side_chain", Root = "Body", Part = "LegFrontL" },
	{ Id = "side_wyvern", Root = "Body", Part = "Neck" },
	{ Id = "side_knight", Root = "Torso", Part = "Sword" },
	{ Id = "side_pig", Root = "Body", Part = "HeadEarLeft" },
	{ Id = "side_crow", Root = "Body", Part = "LegLeft" },
	{ Id = "side_reindeer", Root = "Body", Part = "ArmRight" },
	{ Id = "side_dogs", Root = "WhiteBody", Part = "WhiteHeadJaw" },
	{ Id = "side_ant", Root = "Torso", Part = "RightArm" },
	{ Id = "side_reaper", Root = "Torso", Part = "LeftArm" },
	{ Id = "side_fist", Root = "Torso", Part = "LeftArm" },
	{ Id = "side_curse", Root = "Body", Part = "LeftArm" },
	{ Id = "side_fox", Root = "Body", Part = "LegFrontLeft" },
}
local RAGA = "side_raga"

local Module = {}

function Module.Build(h)
	local scenarios = {}
	local check = function(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local inRange = function(res, name, got, low, high)
		h.check(
			res,
			name,
			got,
			("%s..%s"):format(tostring(low), tostring(high)),
			type(got) == "number" and got >= low and got <= high
		)
	end
	local function setup(res, request)
		local ok, err = h.requestSetup(request)
		if not ok then
			h.check(res, "setup_" .. request, tostring(err), "ok", false)
		end
	end
	local function waitUntil(fn, seconds)
		local deadline = os.clock() + (seconds or WAIT)
		local value = fn()
		while not value and os.clock() < deadline do
			task.wait(0.05)
			value = fn()
		end
		return value or nil
	end

	local function effects()
		return workspace:FindFirstChild("AttackEffects")
	end
	local function followerOf(userId)
		local holder = workspace:FindFirstChild("SidekickFollowers")
		return holder and holder:FindFirstChild("Follower_" .. tostring(userId))
	end
	local function mine()
		return followerOf(h.player.UserId)
	end
	local function waitWearing(id)
		return waitUntil(function()
			local follower = mine()
			return follower
				and follower:GetAttribute("SidekickId") == id
				and follower:FindFirstChildWhichIsA("BasePart", true)
				and follower
		end)
	end

	-- A part's turn against its root, not moved by the follower's own travel.
	local function poseOf(follower, spot)
		local root, part = follower:FindFirstChild(spot.Root, true), follower:FindFirstChild(spot.Part, true)
		return root and part and root.CFrame:ToObjectSpace(part.CFrame).Rotation or nil
	end
	local function turned(a, b)
		local _, angle = (a:Inverse() * b):ToAxisAngle()
		return math.deg(angle)
	end
	local function watchPose(follower, spot)
		return { Follower = follower, Spot = spot, Base = follower and poseOf(follower, spot), Peak = 0 }
	end

	local function numbers()
		local found = {}
		local function search(root)
			for _, d in root and root:GetDescendants() or {} do
				if d.Name == "DamageNumber" and (d:IsA("BillboardGui") or d:IsA("TextLabel")) then
					table.insert(found, d)
				end
			end
		end
		search(effects())
		search(h.player:FindFirstChildOfClass("PlayerGui"))
		return found
	end
	local function numberText(gui)
		local label = gui:IsA("TextLabel") and gui or gui:FindFirstChildWhichIsA("TextLabel", true)
		return label and label.Text or ""
	end

	local function emitterParticles(root)
		local total = 0
		local list = root:GetDescendants()
		table.insert(list, root)
		for _, d in list do
			if d:IsA("ParticleEmitter") then
				total += d.Rate * d.Lifetime.Max
			end
		end
		return total
	end
	local function pivotOf(effect)
		return effect:IsA("PVInstance") and effect:GetPivot().Position or nil
	end
	local function solidParts(effect)
		local solid = 0
		local list = effect:GetDescendants()
		table.insert(list, effect)
		for _, d in list do
			if d:IsA("BasePart") and (d.CanCollide or d.CanQuery or d.CanTouch) then
				solid += 1
			end
		end
		return solid
	end
	local function shows(effect)
		local list = effect:GetDescendants()
		table.insert(list, effect)
		for _, d in list do
			if d:IsA("BasePart") and d.Transparency < 1 then
				return true
			end
		end
		return false
	end

	-- Sends one batch and follows it until the effects are gone, each frame.
	local function watch(res, remote, request, poses)
		local w = {
			Shots = {}, -- owner:id -> { First, Last, Particles, Effect, Shows }
			Peak = 0,
			RatePeak = 0,
			AttrPeakAtRate = 0,
			Solid = 0,
			NumberTexts = {},
			NumbersAtOnce = 0,
		}
		local received = nil
		local connection = remote.OnClientEvent:Connect(function()
			received = received or os.clock()
		end)
		task.spawn(setup, res, "sidekick_follow_hits:" .. request)
		local started, quietSince = os.clock(), nil
		while true do
			RunService.Heartbeat:Wait()
			local now = os.clock()
			local folder = effects()
			local children = folder and folder:GetChildren() or {}
			local total, rate = 0, 0
			for _, child in children do
				total += child:GetAttribute("Particles") or 0
				rate += emitterParticles(child)
				w.Solid = math.max(w.Solid, solidParts(child))
				local kind = child:GetAttribute("Kind")
				local key = ("%s:%s"):format(
					tostring(child:GetAttribute("OwnerId")),
					tostring(child:GetAttribute("SidekickId"))
				)
				local at = pivotOf(child)
				if kind == "Shot" then
					w.ShotAt = w.ShotAt or now
					local shot = w.Shots[key]
					if not shot then
						shot = {
							First = at,
							Particles = child:GetAttribute("Particles"),
							Effect = child:GetAttribute("Effect"),
							Shows = false,
						}
						w.Shots[key] = shot
					end
					shot.Last = at
					shot.Shows = shot.Shows or shows(child)
				elseif kind == "Impact" then
					w.ImpactAt = w.ImpactAt or now
					w.ImpactPosition = w.ImpactPosition or at
				end
			end
			w.Peak = math.max(w.Peak, total)
			if rate > w.RatePeak then
				w.RatePeak, w.AttrPeakAtRate = rate, total
			end
			local shown = numbers()
			w.NumbersAtOnce = math.max(w.NumbersAtOnce, #shown)
			for _, gui in shown do
				w.NumberAt = w.NumberAt or now
				w.NumberTexts[numberText(gui)] = true
			end
			for _, pose in poses or {} do
				local current = pose.Follower
					and pose.Base
					and pose.Follower.Parent
					and poseOf(pose.Follower, pose.Spot)
				if current then
					pose.Peak = math.max(pose.Peak, turned(pose.Base, current))
				end
			end
			if #children == 0 and #shown == 0 then
				quietSince = quietSince or now
			else
				quietSince = nil
			end
			if w.ShotAt and quietSince and now - quietSince >= QUIET then
				w.GoneAt = quietSince
				break
			end
			if now - started > GONE_LIMIT + WAIT then
				break
			end
		end
		connection:Disconnect()
		w.Received = received
		return w
	end

	local function since(w, at)
		return at and w.Received and at - w.Received or -1
	end
	local function checkCommon(res, tag, w)
		check(res, tag .. "_batch_received", w.Received ~= nil, true)
		check(res, tag .. "_shot_appears", w.ShotAt ~= nil, true)
		inRange(res, tag .. "_gone_in_time", since(w, w.GoneAt), 0, GONE_LIMIT)
		check(res, tag .. "_no_solid_parts", w.Solid, 0)
		inRange(res, tag .. "_particles_counted", w.RatePeak - w.AttrPeakAtRate, -math.huge, 0.001)
	end
	-- Every effect left behind fails here, not in the next hit's numbers.
	local function checkLeftAtRest(res, tag, poses)
		for _, pose in poses do
			local follower, base = pose.Follower, pose.Base
			local back = waitUntil(function()
				local current = follower and base and poseOf(follower, pose.Spot)
				return current and turned(base, current) <= POSE_LEFT
			end, POSE_WAIT)
			check(res, ("%s_%s_not_left_posed"):format(tag, pose.Spot.Id), back == true, true)
		end
	end

	local function checkOneAttack(res, remote, Attacks, character, spot)
		local id = spot.Id
		local tag = "attack_" .. id
		setup(res, ("sidekick_follow_wear:%s:%s"):format(character, id))
		local follower = waitWearing(id)
		check(res, tag .. "_follower", follower ~= nil, true)
		if not follower then
			return nil
		end
		-- Pose data and models name the same parts.
		local source = ReplicatedStorage.SidekickModels:FindFirstChild(id)
		local parts = Attacks.Sample(id, 0)
		local missing = {}
		for part in parts do
			if not (source and source:FindFirstChild(part, true) and follower:FindFirstChild(part, true)) then
				table.insert(missing, part)
			end
		end
		check(res, tag .. "_parts_in_model", table.concat(missing, ","), "")

		local pose = spot.Part and watchPose(follower, spot) or nil
		local w = watch(res, remote, ("me:%s:%d"):format(id, LOCAL_DAMAGE), pose and { pose })
		checkCommon(res, tag, w)
		local shot = w.Shots[("%s:%s"):format(tostring(h.player.UserId), id)]
		check(res, tag .. "_shot_tagged", shot ~= nil, true)
		if shot then
			check(res, tag .. "_shot_shows", shot.Shows, true)
			check(res, tag .. "_has_effect", type(shot.Effect) == "string" and shot.Effect ~= "", true)
			check(res, tag .. "_has_particles_count", type(shot.Particles) == "number", true)
			if shot.First and shot.Last then
				local toBoss = function(at)
					return (at - Arena.Center).Magnitude
				end
				h.check(
					res,
					tag .. "_flies_at_boss",
					toBoss(shot.First) - toBoss(shot.Last),
					"> 0",
					toBoss(shot.Last) < toBoss(shot.First)
				)
			else
				check(res, tag .. "_shot_has_position", false, true)
			end
		end
		inRange(res, tag .. "_impact_time", since(w, w.ImpactAt), ARRIVE_MIN, ARRIVE_MAX)
		if w.ImpactPosition then
			local flat = (w.ImpactPosition - Arena.Center) * Vector3.new(1, 0, 1)
			inRange(res, tag .. "_impact_at_boss", flat.Magnitude, 0, BOSS_REACH)
		end
		check(res, tag .. "_shot_before_impact", w.ShotAt ~= nil and w.ImpactAt ~= nil and w.ShotAt < w.ImpactAt, true)
		inRange(res, tag .. "_number_at_impact", since(w, w.NumberAt), ARRIVE_MIN, ARRIVE_MAX + 0.1)
		check(res, tag .. "_number_one", w.NumbersAtOnce, 1)
		local text = next(w.NumberTexts) or ""
		h.check(
			res,
			tag .. "_number_text",
			text,
			tostring(LOCAL_DAMAGE),
			string.find(text, tostring(LOCAL_DAMAGE), 1, true) ~= nil
		)
		if pose then
			inRange(res, tag .. "_plays_attack", pose.Peak, MIN_POSE, 360)
			checkLeftAtRest(res, tag, { pose })
		end
		return shot and shot.Particles or nil, shot and shot.Effect or nil
	end

	local function checkEveryAttack(res, remote, Attacks, character)
		local full, seenEffects = {}, {}
		for _, spot in ATTACKS do
			local particles, effect = checkOneAttack(res, remote, Attacks, character, spot)
			full[spot.Id] = particles
			if effect then
				seenEffects[effect] = true
			end
		end
		local distinct = 0
		for _ in seenEffects do
			distinct += 1
		end
		check(res, "each_sidekick_its_own_effect", distinct, #ATTACKS)
		check(res, "no_attack_is_simple_at_full_strength", seenEffects.Simple, nil)
		-- No approved attack: a simple shot and no pose (design doc 4.37; reported for the owner).
		local particles, effect = checkOneAttack(res, remote, Attacks, character, { Id = RAGA })
		check(res, "raga_simple_shot", effect, "Simple")
		full[RAGA] = particles
		return full
	end

	-- Others draw lighter than the local player, id by id, and get no number.
	local function checkOthersLighter(res, remote, full)
		setup(res, "sidekick_follow_crowd:1")
		check(res, "lighter_crowd_follower", waitUntil(function()
			return followerOf(FAKE_ID)
		end) ~= nil, true)
		local ids = { RAGA }
		for _, spot in ATTACKS do
			table.insert(ids, spot.Id)
		end
		local i = 1
		while i <= #ids do
			local entries = {}
			for k = i, math.min(i + GROUP - 1, #ids) do
				table.insert(entries, ("%d:%s:%d"):format(FAKE_ID, ids[k], OTHER_DAMAGE))
			end
			local w = watch(res, remote, table.concat(entries, ","))
			check(res, ("others_no_number_%d"):format(i), w.NumberAt, nil)
			for k = i, math.min(i + GROUP - 1, #ids) do
				local id = ids[k]
				local shot = w.Shots[("%d:%s"):format(FAKE_ID, id)]
				local tag = "others_" .. id
				check(res, tag .. "_shot", shot ~= nil, true)
				if shot and full[id] and type(shot.Particles) == "number" then
					local lighter = id == RAGA and shot.Particles <= full[id] or shot.Particles < full[id]
					h.check(res, tag .. "_lighter_than_local", shot.Particles, "under " .. full[id], lighter)
				end
			end
			i += GROUP
		end
	end

	-- The local player and 6 others at once, all different ids: side_fox is worn, the first fake fires the crowd's own side_chain.
	local function burstEntries()
		local entries = { ("me:side_fox:%d"):format(LOCAL_DAMAGE), ("%d:side_chain:%d"):format(FAKE_ID, OTHER_DAMAGE) }
		for i = 2, CROWD do
			table.insert(entries, ("%d:%s:%d"):format(FAKE_ID - i + 1, ATTACKS[i].Id, OTHER_DAMAGE))
		end
		return table.concat(entries, ",")
	end
	local function burstPoses()
		return {
			watchPose(mine(), ATTACKS[12]),
			watchPose(followerOf(FAKE_ID), ATTACKS[1]),
		}
	end
	local function countShots(w)
		local count = 0
		for _ in w.Shots do
			count += 1
		end
		return count
	end

	local function checkBurst(res, remote, character)
		setup(res, ("sidekick_follow_wear:%s:side_fox"):format(character))
		waitWearing("side_fox")
		setup(res, "sidekick_follow_crowd:" .. CROWD)
		check(res, "burst_crowd_ready", waitUntil(function()
			return followerOf(FAKE_ID - CROWD + 1) ~= nil and followerOf(FAKE_ID) ~= nil
		end) == true, true)

		local poses = burstPoses()
		local w = watch(res, remote, burstEntries(), poses)
		checkCommon(res, "burst", w)
		check(res, "burst_every_player_shoots", countShots(w), CROWD + 1)
		inRange(res, "burst_particle_budget", w.Peak, 1, TOTAL_PARTICLES)
		check(res, "burst_number_only_local", w.NumbersAtOnce, 1)
		check(res, "burst_number_only_local_text", w.NumberTexts[tostring(OTHER_DAMAGE)], nil)
		h.check(
			res,
			"burst_number_is_local_damage",
			next(w.NumberTexts) or "",
			tostring(LOCAL_DAMAGE),
			string.find(next(w.NumberTexts) or "", tostring(LOCAL_DAMAGE), 1, true) ~= nil
		)
		inRange(res, "burst_other_follower_plays_attack", poses[2].Peak, MIN_POSE, 360)
		checkLeftAtRest(res, "burst", poses)

		-- Two hits of one follower in a catch-up batch still end at rest.
		local twice = burstPoses()
		local again =
			watch(res, remote, ("me:side_fox:%d,me:side_fox:%d"):format(LOCAL_DAMAGE, LOCAL_DAMAGE), { twice[1] })
		check(res, "catch_up_shot", again.ShotAt ~= nil, true)
		inRange(res, "catch_up_gone", since(again, again.GoneAt), 0, GONE_LIMIT + 1)
		checkLeftAtRest(res, "catch_up", { twice[1] })

		h.player:SetAttribute("ReduceEffects", true)
		local reducedPoses = burstPoses()
		local reduced = watch(res, remote, burstEntries(), reducedPoses)
		checkCommon(res, "reduced", reduced)
		check(res, "reduced_every_player_shoots", countShots(reduced), CROWD + 1)
		inRange(res, "reduced_particle_budget", reduced.Peak, 0, REDUCED_PARTICLES)
		h.check(res, "reduced_smaller_than_full", reduced.Peak, "under " .. w.Peak, reduced.Peak < w.Peak)
		for key, shot in reduced.Shots do
			check(res, "reduced_simple_shot_" .. key, shot.Effect, "Simple")
			check(res, "reduced_shot_shows_" .. key, shot.Shows, true)
		end
		check(res, "reduced_number_only_local", reduced.NumbersAtOnce, 1)
		checkLeftAtRest(res, "reduced", reducedPoses)
		h.player:SetAttribute("ReduceEffects", nil)
	end

	-- A batch the view cannot place draws no pose, breaks nothing, and leaves nothing.
	local function checkUnknown(res)
		setup(res, ("sidekick_follow_hits:424242:side_chain:5,%d:side_nope:5"):format(FAKE_ID))
		task.wait(NO_SHOT_WAIT)
		local folder = effects()
		local odd = 0
		for _, child in folder and folder:GetChildren() or {} do
			odd += child:GetAttribute("SidekickId") == "side_nope" and 1 or 0
		end
		check(res, "unknown_id_draws_nothing", odd, 0)
		check(res, "unknown_owner_cleans_up", waitUntil(function()
			local now = effects()
			return now ~= nil and #now:GetChildren() == 0
		end, GONE_LIMIT) == true, true)
	end

	function scenarios.ui_sidekick_attack(res)
		local started = os.clock()
		local view = script.Parent.Parent:FindFirstChild("SidekickAttackView")
		check(res, "view_present", view ~= nil, true)
		local loaded, Attacks = pcall(function()
			return require(Shared:FindFirstChild("SidekickAttacks"))
		end)
		check(res, "attacks_module_loads", loaded, true)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local remote = remotes and remotes:WaitForChild("BossHits", REMOTE_WAIT)
		check(res, "remote_present", remote ~= nil, true)
		if not (view and loaded and remote) then
			return
		end
		local models = ReplicatedStorage:WaitForChild("SidekickModels", MODELS_WAIT)
		check(res, "models_ready", waitUntil(function()
			return models and models:GetAttribute("Ready") == true
		end, MODELS_WAIT) == true, true)
		local character = Catalog.Rollable()[1].Id
		local savedReduce = h.player:GetAttribute("ReduceEffects")
		local ok, err = xpcall(function()
			h.player:SetAttribute("ReduceEffects", nil) -- full strength is judged with the toggle off, whatever the player had
			setup(res, "sidekick_follow_start")
			check(res, "folder_is_folder", waitUntil(function()
				return effects()
			end) and effects().ClassName or "missing", "Folder")
			local holder = workspace:FindFirstChild("SidekickFollowers")
			check(res, "folder_not_in_followers", holder and holder:FindFirstChild("AttackEffects"), nil)
			local full = checkEveryAttack(res, remote, Attacks, character)
			checkOthersLighter(res, remote, full)
			checkUnknown(res)
			checkBurst(res, remote, character)
		end, debug.traceback)
		h.check(res, "attack_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		h.player:SetAttribute("ReduceEffects", savedReduce)
		setup(res, "restore:sidekick_follow")
		local spent = os.clock() - started
		h.check(res, "attack_scenario_time", spent, "< " .. BUDGET, spent < BUDGET)
	end

	return { Scenarios = scenarios }
end

return Module
