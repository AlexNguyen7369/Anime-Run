--!nonstrict
-- BRIEF: design doc 4.36 "Summon pool rotation" (owner 2026-11-05), docs/SIDEKICK_SPEC.md "Rotation". SidekickTests holds the
-- rest of the Sidekick rules. POOL is the 12-row table; only the Legendary, Mythic and Secret odds are owner-confirmed, the
-- other values are proposed: tune them here and in the spec together. Names are read from config.
-- Contract these tests assume beyond the brief (implementer: report a change, do not loosen):
--   Server/SidekickRotation (server only; a client learns only the current slot's Secret, never a future one) reads SidekickArt at call time, so a row losing its Model leaves the rotation.
--     A tier with too few rows that have a Model holds the ones it has.
--   Rotation.Odds maps only in-rotation ids.
--   Rotation.Public(slot) has exactly: Ids (array), SecretChoices (array of { Name, Odds }), SecretId (the slot's
--     live Secret, owner ruling: Details shows it as a black silhouette), EndsAt ((slot + 1) * 1800), Odds (Rotation.Odds(slot):
--     id to percent, the numbers Details shows).
--   SidekickService.Roll(rng): the row or id of one roll on the clock's slot, one rng:NextNumber() per roll (Config.Roll),
--     which lets the sweep below judge exact odds without any luck. SetClock(fn) replaces os.time and publishes at once;
--     SetClock() puts the real clock back. A summon reads the clock once. Start keeps the attribute current within 2 s.
--   ReplicatedStorage attribute SidekickRotation: HttpService JSON of Public(current slot).
-- On demand: ReplicatedStorage attributes CarTestOnly = "sidekick_rotation", then CarTestRun = true.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990137000
local SLOT0 = 1000000 -- far from today, so the live slot cannot pass by accident
local SLOTS = 200
local GRID = 120000 -- finer than the 0.001% band, so the sweep always lands in a Secret's band
local GRID_SLACK = 0.002 -- percent: one grid step per row boundary
local TIER_SIZE = { Mythic = 1, Legendary = 2, Rare = 2 }

-- id, rarity, odds, Movement, Cruise, Stamina, Damage, SellGems
local POOL = {
	{ "side_chain", "Common", 24.166, "Walk", 0, 0.05, 6, 2 },
	{ "side_pig", "Common", 24.166, "Walk", 0, 0.05, 6, 2 },
	{ "side_crow", "Common", 24.166, "Fly", 0, 0.05, 6, 2 },
	{ "side_dogs", "Rare", 12, "Walk", 0, 0.12, 10, 5 },
	{ "side_reindeer", "Rare", 12, "Walk", 0, 0.12, 10, 5 },
	{ "side_ant", "Legendary", 1, "Walk", 0.1, 0.05, 22, 20 },
	{ "side_reaper", "Legendary", 1, "Fly", 0.1, 0.05, 22, 20 },
	{ "side_fist", "Mythic", 0.5, "Fly", 0.15, 0.1, 35, 25 },
	{ "side_knight", "Mythic", 0.5, "Walk", 0.15, 0.1, 35, 25 },
	{ "side_wyvern", "Mythic", 0.5, "Fly", 0.15, 0.1, 35, 25 },
	{ "side_curse", "Secret", 0.001, "Fly", 0.2, 0.2, 55, 30 },
	{ "side_fox", "Secret", 0.001, "Walk", 0.2, 0.2, 55, 30 },
}

local function near(a, b, slack)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (slack or 1e-6)
end

local function idOf(result)
	return type(result) == "table" and result.Id or result
end

local function setOf(list)
	local set = {}
	for _, id in list do
		set[id] = true
	end
	return set
end

local function members(rotation)
	local out = {}
	for _, tier in { "Mythic", "Legendary", "Rare", "Common" } do
		for _, id in rotation[tier] do
			table.insert(out, id)
		end
	end
	return out
end

function Tests.sidekick_rotation()
	local r, flag = H.report("sidekick_rotation")
	local S, oldCooldown
	local cleanup = {}
	local function section(name, fn)
		local ok, err = xpcall(fn, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end

	local Cfg = require(Shared.SidekickConfig)
	local Art = require(Shared.SidekickArt)
	local byRarity, secretIds, secretNames = {}, {}, {}
	for _, row in Cfg.List do
		byRarity[row.Rarity] = byRarity[row.Rarity] or {}
		table.insert(byRarity[row.Rarity], row.Id)
		if row.Rarity == "Secret" then
			table.insert(secretIds, row.Id)
			table.insert(secretNames, row.Name)
		end
	end
	local function listed(id)
		return Cfg.Get(id).Odds
	end
	local function listedSum(ids)
		local sum = 0
		for _, id in ids do
			sum += listed(id)
		end
		return sum
	end

	section("pool", function()
		flag("list_has_12", #Cfg.List == #POOL, #Cfg.List, #POOL)
		local seenNames, odds = {}, 0
		for _, want in POOL do
			local row = Cfg.Get(want[1])
			local id = want[1]
			flag("listed_" .. id, row ~= nil and table.find(Cfg.List, row) ~= nil)
			if row then
				flag("rarity_" .. id, row.Rarity == want[2], row.Rarity, want[2])
				flag("odds_" .. id, near(row.Odds, want[3]), row.Odds, want[3])
				flag("movement_" .. id, row.Movement == want[4], row.Movement, want[4])
				flag("cruise_" .. id, near(row.Cruise, want[5]), row.Cruise, want[5])
				flag("stamina_" .. id, near(row.Stamina, want[6]), row.Stamina, want[6])
				flag("damage_" .. id, row.Damage == want[7], row.Damage, want[7])
				flag("sell_" .. id, row.SellGems == want[8], row.SellGems, want[8])
				flag("name_" .. id, type(row.Name) == "string" and row.Name ~= "" and not seenNames[row.Name])
				seenNames[row.Name] = true
				odds += row.Odds
			end
		end
		flag("listed_odds_sum_100", near(odds, 100), odds, 100)
		local raga = Cfg.BossDrops[1]
		flag("raga_stays_a_boss_drop", raga.Id == "side_raga" and #Cfg.BossDrops == 1)
		flag("raga_not_listed", table.find(Cfg.List, raga) == nil)
	end)

	flag("rotation_module_not_replicated", ReplicatedStorage:FindFirstChild("SidekickRotation", true) == nil)

	section("pure", function()
		local Rotation = require(Server.SidekickRotation)
		flag("slot_seconds", Rotation.SLOT_SECONDS == 1800, Rotation.SLOT_SECONDS, 1800)
		for _, case in { { 0, 0 }, { 1799, 0 }, { 1799.9, 0 }, { 1800, 1 }, { 3600, 2 }, { 1800000123, 1000000 } } do
			flag("slot_of_" .. case[1], Rotation.Slot(case[1]) == case[2], Rotation.Slot(case[1]), case[2])
		end

		local first = H.copy(Rotation.For(SLOT0))
		local seen, mythicChanges, secretChanges = {}, 0, 0
		local countsOk, ranksOk, commonsOk, noRaga, oddsKeysOk, oddsSumOk, keepOk, commonOk =
			true, true, true, true, true, true, true, true
		local publicSecretOk, publicSecretChoice = true, true
		local publicKeysOk, publicIdsOk, publicEndsOk, publicHidden, choicesSame = true, true, true, true, true
		local publicOddsOk = true
		local firstChoices
		local previous
		for slot = SLOT0, SLOT0 + SLOTS - 1 do
			local rotation = Rotation.For(slot)
			for tier, size in TIER_SIZE do
				local ids = rotation[tier]
				local distinct = 0
				for _ in setOf(ids) do
					distinct += 1
				end
				countsOk = countsOk and #ids == size and distinct == size
				for _, id in ids do
					seen[id] = true
					ranksOk = ranksOk and Cfg.Get(id).Rarity == tier
				end
			end
			commonsOk = commonsOk and H.same(setOf(rotation.Common), setOf(byRarity.Common))
			local secret = rotation.Secret
			ranksOk = ranksOk and type(secret) == "string" and Cfg.Get(secret).Rarity == "Secret"
			seen[secret] = true

			local inRotation = members(rotation)
			table.insert(inRotation, secret)
			noRaga = noRaga and table.find(inRotation, "side_raga") == nil
			if previous then
				mythicChanges += previous.Mythic[1] ~= rotation.Mythic[1] and 1 or 0
				secretChanges += previous.Secret ~= secret and 1 or 0
			end
			previous = rotation

			local odds = Rotation.Odds(slot)
			local keys, sum = {}, 0
			for id, percent in odds do
				keys[id] = true
				sum += percent
			end
			oddsKeysOk = oddsKeysOk and H.same(keys, setOf(inRotation))
			oddsSumOk = oddsSumOk and near(sum, 100)
			local extra = (100 - listedSum(inRotation)) / #byRarity.Common
			for _, id in inRotation do
				if Cfg.Get(id).Rarity == "Common" then
					commonOk = commonOk and near(odds[id], listed(id) + extra)
				else
					keepOk = keepOk and near(odds[id], listed(id))
				end
			end
			commonOk = commonOk and near(odds[rotation.Common[1]], 24.5, 0.01) -- with today's art and rates

			local public = Rotation.Public(slot)
			local publicKeys = {}
			for key in public do
				publicKeys[key] = true
			end
			publicKeysOk = publicKeysOk
				and H.same(
					publicKeys,
					{ Ids = true, SecretChoices = true, SecretId = true, EndsAt = true, Odds = true }
				)
			publicOddsOk = publicOddsOk and H.same(public.Odds, odds)
			publicIdsOk = publicIdsOk and H.same(setOf(public.Ids or {}), setOf(members(rotation)))
			publicEndsOk = publicEndsOk and public.EndsAt == (slot + 1) * 1800
			local raw = HttpService:JSONEncode(public)
			publicSecretOk = publicSecretOk and public.SecretId == rotation.Secret
			local liveChoice = false
			for _, choice in public.SecretChoices do
				liveChoice = liveChoice or choice.Name == Cfg.Get(rotation.Secret).Name
			end
			publicSecretChoice = publicSecretChoice and liveChoice
			for _, id in secretIds do
				publicHidden = publicHidden and (id == rotation.Secret or string.find(raw, id, 1, true) == nil)
			end
			-- The same every slot: SecretId alone tells the live Secret.
			local choices = HttpService:JSONEncode(public.SecretChoices)
			firstChoices = firstChoices or choices
			choicesSame = choicesSame and choices == firstChoices
		end
		flag("tier_counts_exact", countsOk)
		flag("tier_ranks_right", ranksOk)
		flag("commons_all_in", commonsOk)
		flag("raga_never_in_rotation", noRaga)
		for _, want in POOL do
			if want[2] ~= "Common" then
				flag("seen_over_200_slots_" .. want[1], seen[want[1]] == true)
			end
		end
		flag("mythic_really_rotates", mythicChanges >= 20, mythicChanges, 20)
		flag("secret_really_rotates", secretChanges >= 20, secretChanges, 20)

		flag("odds_keys_are_the_rotation", oddsKeysOk)
		flag("odds_sum_100", oddsSumOk)
		flag("odds_keep_listed", keepOk)
		flag("odds_remainder_on_commons", commonOk)

		flag("public_keys_exact", publicKeysOk)
		flag("public_odds_are_the_slots", publicOddsOk)
		flag("public_ids_without_secret", publicIdsOk)
		flag("public_ends_at_slot_end", publicEndsOk)
		flag("public_secret_id_is_the_slots", publicSecretOk)
		flag("public_secret_id_is_a_choice", publicSecretChoice)
		flag("public_hides_the_other_secret_ids", publicHidden)
		flag("public_choices_same_every_slot", choicesSame)
		local choices = Rotation.Public(SLOT0).SecretChoices
		local names = {}
		for _, choice in choices do
			table.insert(names, choice.Name)
			flag("public_choice_odds_" .. tostring(choice.Name), near(choice.Odds, 0.001), choice.Odds, 0.001)
		end
		flag("public_choices_every_secret_name", H.same(setOf(names), setOf(secretNames)) and #names == #secretNames)

		-- From the slot alone: no call order, no global random, no module state, any server.
		flag("for_same_after_other_slots", H.same(Rotation.For(SLOT0), first))
		math.randomseed(1)
		local seededOne = H.copy(Rotation.For(SLOT0 + 7))
		local nextOne = math.random()
		math.randomseed(1)
		local seededTwo = H.copy(Rotation.For(SLOT0 + 7))
		flag("for_leaves_global_random_alone", math.random() == nextOne)
		math.randomseed(99)
		flag("for_ignores_global_random", H.same(seededOne, seededTwo) and H.same(Rotation.For(SLOT0 + 7), seededOne))
		local clone = Server.SidekickRotation:Clone()
		clone.Name = "CarTestRotationClone"
		clone.Parent = Server
		table.insert(cleanup, clone)
		local server2 = require(clone)
		local sameOnAServer2 = true
		for slot = SLOT0 + SLOTS - 1, SLOT0, -1 do
			sameOnAServer2 = sameOnAServer2 and H.same(server2.For(slot), Rotation.For(slot))
		end
		flag("for_same_on_a_fresh_server", sameOnAServer2)

		-- No uploaded Model: out of its tier. Art is put back before any yield, because live code shares it.
		local function without(ids, fn)
			local saved = {}
			for _, id in ids do
				saved[id] = Art[id].Model
				Art[id].Model = nil
			end
			local ok, err = pcall(fn)
			for id, model in saved do
				Art[id].Model = model
			end
			if not ok then
				error(err, 0)
			end
		end
		local function everySlot(fn)
			local holds = true
			for slot = SLOT0, SLOT0 + SLOTS - 1 do
				holds = fn(slot, Rotation.For(slot), Rotation.Odds(slot)) and holds
			end
			return holds
		end
		local function sums100(odds)
			local sum = 0
			for _, percent in odds do
				sum += percent
			end
			return near(sum, 100)
		end
		without({ "side_fist" }, function()
			flag(
				"no_model_mythic_out",
				everySlot(function(_, rotation, odds)
					return rotation.Mythic[1] ~= "side_fist"
						and #rotation.Mythic == 1
						and odds.side_fist == nil
						and sums100(odds)
				end)
			)
		end)
		without({ "side_dogs" }, function()
			flag(
				"no_model_rare_out",
				everySlot(function(_, rotation, odds)
					return H.same(rotation.Rare, { "side_reindeer" })
						and odds.side_dogs == nil
						and sums100(odds)
						and near(
							odds.side_chain,
							listed("side_chain") + (100 - listedSum(members(rotation)) - listed(rotation.Secret)) / 3
						)
				end)
			)
			flag("no_model_public_hides_it", table.find(Rotation.Public(SLOT0).Ids, "side_dogs") == nil)
		end)
		without({ "side_dogs", "side_reindeer", "side_ant", "side_reaper" }, function()
			flag(
				"no_model_tier_empty_still_100",
				everySlot(function(_, rotation, odds)
					return #rotation.Rare == 0 and #rotation.Legendary == 0 and sums100(odds)
				end)
			)
		end)
	end)

	section("service", function()
		local Rotation = require(Server.SidekickRotation)
		S = require(Server.SidekickService)
		oldCooldown = S.REMOTE_COOLDOWN
		S.REMOTE_COOLDOWN = 0
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestRotationData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local store = H.store()
		data.SetStore(store)
		local nextId = UID
		local function unlocked()
			nextId += 1
			local p = H.player(cleanup, nextId)
			data.Load(p, nextId)
			p:SetAttribute("RebirthLevel", Cfg.UnlockRebirth)
			for _, row in Cfg.List do
				S.SetAutoSell(p, row.Rarity, true)
			end
			return p
		end
		local function at(utc)
			S.SetClock(function()
				return utc
			end)
		end
		local function sweep(points)
			local x = 0
			local fake = {
				NextNumber = function()
					return x
				end,
			}
			local tally = {}
			for i = 0, points - 1 do
				x = (i + 0.5) / points
				local id = idOf(S.Roll(fake))
				tally[id] = (tally[id] or 0) + 1
				if i % 20000 == 19999 then
					task.wait() -- the script timeout
				end
			end
			return tally
		end

		-- Every id of a slot gets exactly its share of the unit interval, so no rare tier needs luck to be judged.
		local slotOfSecret = {}
		for slot = SLOT0, SLOT0 + SLOTS - 1 do
			slotOfSecret[Rotation.For(slot).Secret] = slotOfSecret[Rotation.For(slot).Secret] or slot
		end
		for _, secret in secretIds do
			local slot = slotOfSecret[secret]
			flag("test_found_slot_of_" .. secret, slot ~= nil)
			if slot then
				at(slot * 1800 + 60)
				local tally = sweep(GRID)
				local odds = Rotation.Odds(slot)
				for id in tally do
					flag("only_rotation_" .. secret .. "_" .. id, odds[id] ~= nil)
				end
				for id, percent in odds do
					local share = (tally[id] or 0) / GRID * 100
					flag("sweep_share_" .. secret .. "_" .. id, near(share, percent, GRID_SLACK), share, percent)
				end
				flag("live_secret_can_drop_" .. secret, (tally[secret] or 0) >= 1, tally[secret] or 0, 1)
				for _, other in secretIds do
					if other ~= secret then
						flag("other_secret_never_" .. secret, tally[other] == nil)
					end
				end
				flag("raga_never_rolled_" .. secret, tally.side_raga == nil)
			end
		end

		-- Judged by the slot when the request arrives, up to the last moment of it.
		local edge
		for slot = SLOT0, SLOT0 + SLOTS - 2 do
			if Rotation.For(slot).Mythic[1] ~= Rotation.For(slot + 1).Mythic[1] then
				edge = slot
				break
			end
		end
		flag("test_found_mythic_change", edge ~= nil)
		if edge then
			local endsAt = (edge + 1) * 1800
			local before, after = Rotation.For(edge).Mythic[1], Rotation.For(edge + 1).Mythic[1]
			at(endsAt - 0.5)
			local late = sweep(2000)
			flag("last_moment_old_mythic", late[before] ~= nil and late[after] == nil)
			at(endsAt)
			local early = sweep(2000)
			flag("first_moment_new_mythic", early[after] ~= nil and early[before] == nil)
		end

		-- Listed rates on a real seeded rng: only the common tiers, whose shares are well sampled.
		local slot = SLOT0 + 3
		at(slot * 1800)
		local odds = Rotation.Odds(slot)
		local rng, tally, ROLLS = Random.new(4242), {}, 40000
		for i = 1, ROLLS do
			local id = idOf(S.Roll(rng))
			tally[id] = (tally[id] or 0) + 1
			if i % 20000 == 0 then
				task.wait()
			end
		end
		for _, tier in { "Common", "Rare" } do
			for _, id in Rotation.For(slot)[tier] do
				local share = (tally[id] or 0) / ROLLS * 100
				flag("seeded_share_" .. id, near(share, odds[id], 1), share, odds[id])
			end
		end
		for id in tally do
			flag("seeded_in_rotation_" .. id, odds[id] ~= nil)
		end
		local function sequence()
			local seeded, out = Random.new(9), {}
			for i = 1, 300 do
				out[i] = idOf(S.Roll(seeded))
			end
			return out
		end
		local rollsBefore = sequence()

		-- Real summons: 10 independent rolls of one slot; S.Roll stays pure: pity lives in summons (SidekickPityTests).
		local p = unlocked()
		local inRotation, fine, varied = true, true, true
		for _ = 1, 300 do
			p:SetAttribute("Gems", Cfg.TenCost)
			local ok, results = S.Summon(p, 10)
			fine = fine and ok == true and #results == 10
			local kinds = {}
			for _, result in ok and results or {} do
				inRotation = inRotation and odds[result.Id] ~= nil
				kinds[result.Id] = true
			end
			varied = varied and next(kinds, next(kinds)) ~= nil
		end
		flag("tens_ran", fine)
		flag("tens_only_this_slot", inRotation)
		flag("tens_rolls_independent", varied)
		flag("no_pity_same_rolls_after_summons", H.same(sequence(), rollsBefore))
		local fresh = unlocked()
		local freeOk, freeResults = S.GrantFreeSummon(fresh)
		flag("free_summon_in_rotation", freeOk == true and odds[freeResults[1].Id] ~= nil)
		local outOfSlot = {}
		for _, row in Cfg.List do
			if odds[row.Id] == nil then
				table.insert(outOfSlot, row.Id)
			end
		end
		flag("test_has_out_of_rotation_rows", #outOfSlot > 0)
		-- A summon's slot is one reading: the clock moving on every read cannot split a 10x.
		local reads, moving = 0, unlocked()
		moving:SetAttribute("Gems", Cfg.TenCost)
		S.SetClock(function()
			reads += 1
			return slot * 1800 + reads * 1800
		end)
		reads = 0
		S.Summon(moving, 10)
		flag("ten_reads_clock_once", reads == 1, reads, 1)

		-- The replicated attribute: the client's whole view, and of the Secrets only the live one.
		local function attribute()
			local raw = ReplicatedStorage:GetAttribute("SidekickRotation")
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
			return raw, ok and decoded or nil
		end
		local same, hidden, named = true, true, true
		for check = SLOT0, SLOT0 + 49 do
			at(check * 1800 + 5)
			local raw, decoded = attribute()
			same = same and H.same(decoded, Rotation.Public(check))
			local rawText = type(raw) == "string" and raw or ""
			for _, id in secretIds do
				hidden = hidden and (id == Rotation.For(check).Secret or string.find(rawText, id, 1, true) == nil)
			end
			hidden = hidden and type(decoded) == "table" and decoded.SecretId == Rotation.For(check).Secret
			for _, name in secretNames do
				named = named and string.find(rawText, name, 1, true) ~= nil
			end
		end
		flag("attribute_is_public_json", same)
		flag("attribute_only_the_live_secret_id", hidden)
		flag("attribute_names_both_choices", named)

		-- The running service follows the clock into the next slot with nobody summoning.
		local now = (SLOT0 + 1) * 1800 - 1
		S.SetClock(function()
			return now
		end)
		now = (SLOT0 + 1) * 1800 + 1
		local deadline, followed = os.clock() + 2.5, false
		while os.clock() < deadline and not followed do
			local _, decoded = attribute()
			followed = decoded ~= nil and decoded.EndsAt == (SLOT0 + 2) * 1800
			task.wait(0.1)
		end
		flag("attribute_follows_slot_change", followed)

		S.SetClock()
		local _, real = attribute()
		local wantEnds = (Rotation.Slot(os.time()) + 1) * 1800
		flag("set_clock_restores_real_time", real ~= nil and real.EndsAt == wantEnds, real and real.EndsAt, wantEnds)
	end)

	if S then
		S.REMOTE_COOLDOWN = oldCooldown or S.REMOTE_COOLDOWN
		if S.SetClock then
			S.SetClock()
		end
	end
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
