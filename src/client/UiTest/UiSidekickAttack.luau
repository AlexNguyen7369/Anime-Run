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
--   Characters act individually (owner 2026-11-06; design doc 4.37, BOSS_EVENT_SPEC "Run rules", "Damage numbers"): an entry is
--   { UserId, SidekickId, Damage, Slot, CharacterId }. One attack and one number per entry, for any member, never summed. The attack
--   leaves that character's own follower: Follower_<BossTeamRig.Owner(UserId, Slot)> where that rig exists, else the front's. The number's
--   TextColor3 is GachaConfig.RARITY_COLORS[CharacterCatalog.Get(CharacterId).Rarity], with no UIGradient. A member whose follower is
--   hidden or absent still shows the number. Fixture: UiTestSetup sidekick_follow_hits takes <userId|me>:<id>:<damage>:<character>:<slot>.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig"))
local Catalog = require(Shared:WaitForChild("CharacterCatalog"))
local GachaConfig = require(Shared:WaitForChild("GachaConfig"))

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
local LINE_USER = 100 -- BossTeamRig.Owner(100, n) is -(1000 + n): UiTestSetup's crowd runner n stands in for that player's slot n rig
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
	-- One entry of the fixture's batch; the front's character by default.
	local function entry(user, id, damage, character, slot)
		return ("%s:%s:%d:%s:%d"):format(tostring(user), id, damage, character or Catalog.Rollable()[1].Id, slot or 1)
	end
	local function rarityColor(character)
		return GachaConfig.RARITY_COLORS[Catalog.Get(character).Rarity]
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
	local function numberColor(gui)
		local label = gui:IsA("TextLabel") and gui or gui:FindFirstChildWhichIsA("TextLabel", true)
		return label and label.TextColor3 or nil
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
			NumberColors = {}, -- text -> colour
			NumberGradients = 0,
			NumbersAtOnce = 0,
			ShotList = {}, -- each shot once: { Owner, Id, First }
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
					if not w.Seen then
						w.Seen = {}
					end
					if not w.Seen[child] then
						w.Seen[child] = true
						table.insert(w.ShotList, {
							Owner = child:GetAttribute("OwnerId"),
							Id = child:GetAttribute("SidekickId"),
							First = at,
						})
					end
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
				w.NumberColors[numberText(gui)] = numberColor(gui)
				if gui:FindFirstChildWhichIsA("UIGradient", true) then
					w.NumberGradients += 1
				end
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
			if (w.ShotAt or w.NumberAt) and quietSince and now - quietSince >= QUIET then
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
		local w = watch(res, remote, entry("me", id, LOCAL_DAMAGE, character), pose and { pose })
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
		check(res, tag .. "_number_rarity_colour", w.NumberColors[tostring(LOCAL_DAMAGE)], rarityColor(character))
		check(res, tag .. "_number_no_gradient", w.NumberGradients, 0)
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

	-- Others draw lighter than the local player, id by id, and each entry has its number (owner 2026-11-06).
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
				table.insert(entries, entry(FAKE_ID, ids[k], OTHER_DAMAGE))
			end
			local w = watch(res, remote, table.concat(entries, ","))
			check(res, ("others_number_per_entry_%d"):format(i), w.NumbersAtOnce, #entries)
			check(res, ("others_number_text_%d"):format(i), w.NumberTexts[tostring(OTHER_DAMAGE)], true)
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
		local entries = { entry("me", "side_fox", LOCAL_DAMAGE), entry(FAKE_ID, "side_chain", OTHER_DAMAGE) }
		for i = 2, CROWD do
			table.insert(entries, entry(FAKE_ID - i + 1, ATTACKS[i].Id, OTHER_DAMAGE))
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
		check(res, "burst_number_per_entry", w.NumbersAtOnce, CROWD + 1)
		check(res, "burst_number_others_text", w.NumberTexts[tostring(OTHER_DAMAGE)], true)
		check(res, "burst_number_is_local_damage", w.NumberTexts[tostring(LOCAL_DAMAGE)], true)
		inRange(res, "burst_other_follower_plays_attack", poses[2].Peak, MIN_POSE, 360)
		checkLeftAtRest(res, "burst", poses)

		-- Two hits of one follower in a catch-up batch: two attacks, two numbers, never summed, and it still ends at rest.
		local twice = burstPoses()
		local again = watch(
			res,
			remote,
			entry("me", "side_fox", LOCAL_DAMAGE) .. "," .. entry("me", "side_fox", OTHER_DAMAGE),
			{ twice[1] }
		)
		check(res, "catch_up_shot", again.ShotAt ~= nil, true)
		check(res, "catch_up_one_attack_per_entry", #again.ShotList, 2)
		check(res, "catch_up_one_number_per_entry", again.NumbersAtOnce, 2)
		check(res, "catch_up_first_number", again.NumberTexts[tostring(LOCAL_DAMAGE)], true)
		check(res, "catch_up_second_number", again.NumberTexts[tostring(OTHER_DAMAGE)], true)
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
		check(res, "reduced_number_per_entry", reduced.NumbersAtOnce, CROWD + 1)
		checkLeftAtRest(res, "reduced", reducedPoses)
		h.player:SetAttribute("ReduceEffects", nil)
	end

	-- A batch the view cannot place draws no pose, breaks nothing, and leaves nothing.
	local function checkUnknown(res)
		setup(res, "sidekick_follow_hits:" .. entry(424242, "side_chain", 5) .. "," .. entry(FAKE_ID, "side_nope", 5))
		-- No follower is no reason to lose the number (owner 2026-11-06).
		check(res, "unknown_owner_shows_number", waitUntil(function()
			return #numbers() > 0
		end, NO_SHOT_WAIT) == true, true)
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

	-- Two characters of two rarities: 2 numbers, 2 colours, each on its own damage, whoever fired.
	local function checkRarity(res, remote, character)
		local first = Catalog.Rollable()[1]
		local other = nil
		for _, row in Catalog.Rollable() do
			if GachaConfig.RARITY_COLORS[row.Rarity] ~= GachaConfig.RARITY_COLORS[first.Rarity] then
				other = row
				break
			end
		end
		check(res, "rarity_setup_two_rarities", other ~= nil, true)
		if not other then
			return
		end
		setup(res, ("sidekick_follow_wear:%s:side_fox"):format(character))
		waitWearing("side_fox")
		setup(res, "sidekick_follow_crowd:1")
		check(res, "rarity_crowd_ready", waitUntil(function()
			return followerOf(FAKE_ID)
		end) ~= nil, true)
		local function checkPair(tag, a, b)
			local w = watch(res, remote, a .. "," .. b)
			check(res, tag .. "_two_numbers", w.NumbersAtOnce, 2)
			check(res, tag .. "_first_colour", w.NumberColors[tostring(LOCAL_DAMAGE)], rarityColor(first.Id))
			check(res, tag .. "_second_colour", w.NumberColors[tostring(OTHER_DAMAGE)], rarityColor(other.Id))
			check(res, tag .. "_no_gradient", w.NumberGradients, 0)
		end
		checkPair(
			"rarity_two_players",
			entry("me", "side_fox", LOCAL_DAMAGE, first.Id, 1),
			entry(FAKE_ID, "side_chain", OTHER_DAMAGE, other.Id, 1)
		)
		-- By the character, not its Sidekick: one Sidekick id, two characters.
		checkPair(
			"rarity_one_sidekick",
			entry("me", "side_fox", LOCAL_DAMAGE, first.Id, 1),
			entry("me", "side_fox", OTHER_DAMAGE, other.Id, 2)
		)
	end

	-- Slot n's attack leaves slot n's follower, also when two wear the same Sidekick.
	local function checkOwnFollower(res, remote)
		setup(res, "sidekick_follow_crowd:3")
		local two, three = FAKE_ID - 1, FAKE_ID - 2
		check(res, "own_follower_rigs_ready", waitUntil(function()
			return followerOf(two) ~= nil and followerOf(three) ~= nil
		end) == true, true)
		local function distanceTo(owner, at)
			return (followerOf(owner):FindFirstChildWhichIsA("BasePart", true).Position - at).Magnitude
		end
		local spot = ATTACKS[1] -- side_chain, which the crowd wears
		local poses = { watchPose(followerOf(two), spot), watchPose(followerOf(three), spot) }
		local w = watch(res, remote, entry(LINE_USER, "side_chain", OTHER_DAMAGE, nil, 3), poses)
		local shot = w.ShotList[1]
		check(res, "own_follower_slot_3_one_shot", #w.ShotList, 1)
		if shot and shot.First then
			local near, far = distanceTo(three, shot.First), distanceTo(two, shot.First)
			h.check(res, "own_follower_slot_3_leaves_its_own", near, "under " .. far, near < far)
		end
		inRange(res, "own_follower_slot_3_plays_attack", poses[2].Peak, MIN_POSE, 360)
		inRange(res, "own_follower_slot_2_stays_still", poses[1].Peak, 0, MIN_POSE)
		checkLeftAtRest(res, "own_follower", poses)
		local both = watch(
			res,
			remote,
			entry(LINE_USER, "side_chain", LOCAL_DAMAGE, nil, 2)
				.. ","
				.. entry(LINE_USER, "side_chain", OTHER_DAMAGE, nil, 3)
		)
		check(res, "own_follower_both_two_shots", #both.ShotList, 2)
		check(res, "own_follower_both_two_numbers", both.NumbersAtOnce, 2)
		local fromTwo, fromThree = false, false
		for _, row in both.ShotList do
			if row.First then
				local toTwo, toThree = distanceTo(two, row.First), distanceTo(three, row.First)
				fromTwo = fromTwo or toTwo < toThree
				fromThree = fromThree or toThree < toTwo
			end
		end
		check(res, "own_follower_both_from_slot_2", fromTwo, true)
		check(res, "own_follower_both_from_slot_3", fromThree, true)
	end

	-- The runner hidden, so its follower is: the number still shows, in its colour.
	local function checkHidden(res, remote)
		setup(res, "sidekick_follow_crowd:1")
		local follower = waitUntil(function()
			return followerOf(FAKE_ID)
		end)
		local rig = workspace:FindFirstChild("FollowCrowd1")
		local torso = rig and rig:FindFirstChild("Torso")
		check(res, "hidden_setup_ready", follower ~= nil and torso ~= nil, true)
		if not (follower and torso) then
			return
		end
		local was = torso.Transparency
		torso.Transparency = 1 -- local only: Client/SidekickFollower hides on this
		check(res, "hidden_follower_hidden", waitUntil(function()
			local part = follower:FindFirstChildWhichIsA("BasePart", true)
			return part and part.LocalTransparencyModifier >= 1
		end) == true, true)
		local character = Catalog.Rollable()[1].Id
		local w = watch(res, remote, entry(FAKE_ID, "side_chain", OTHER_DAMAGE, character, 1))
		check(res, "hidden_number_shows", w.NumbersAtOnce, 1)
		check(res, "hidden_number_text", w.NumberTexts[tostring(OTHER_DAMAGE)], true)
		check(res, "hidden_number_colour", w.NumberColors[tostring(OTHER_DAMAGE)], rarityColor(character))
		torso.Transparency = was
	end

	function scenarios.ui_sidekick_attack(res)
		local started = os.clock()
		local view = script.Parent.Parent:FindFirstChild("SidekickAttackView")
		check(res, "view_present", view ~= nil, true)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local remote = remotes and remotes:WaitForChild("BossHits", REMOTE_WAIT)
		check(res, "remote_present", remote ~= nil, true)
		if not (view and remote) then
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
			-- Design doc 7 "Join size": not at join; the sidekick_follow setup publishes it, as a real boss event does.
			local loaded, Attacks = pcall(function()
				return require(
					ReplicatedStorage:WaitForChild("LateData", MODELS_WAIT):WaitForChild("SidekickAttacks", MODELS_WAIT)
				)
			end)
			check(res, "attacks_module_loads", loaded, true)
			if not loaded then
				return
			end
			check(res, "folder_is_folder", waitUntil(function()
				return effects()
			end) and effects().ClassName or "missing", "Folder")
			local holder = workspace:FindFirstChild("SidekickFollowers")
			check(res, "folder_not_in_followers", holder and holder:FindFirstChild("AttackEffects"), nil)
			local full = checkEveryAttack(res, remote, Attacks, character)
			checkOthersLighter(res, remote, full)
			checkUnknown(res)
			checkBurst(res, remote, character)
			checkRarity(res, remote, character)
			checkOwnFollower(res, remote)
			checkHidden(res, remote)
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
