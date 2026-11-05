--!nonstrict
-- BRIEF: design doc 4.38, 4.37, 4.13, section 5 and 6; docs/RELIC_SPEC.md (task b8). Stat counts, the priority and the
-- 0.001% chance are owner values, asserted here; names, odds and bonuses are placeholders, always read from the config.
--
-- Contract these tests assume beyond the brief:
--   Shared/RelicConfig:
--     Bosses.big_raga: array, least rare first, of { Id, Name, Rarity, Odds, Bonuses = { <stat> = fraction } }. Odds is a percent;
--     a bonus 0.15 is +15%. Stats: Damage, AttackSpeed, Luck, Money, Speed, Stamina. Ids are lowercase.
--     Get(id): that same row, nil if unknown. Odds(boss): array of { Id, Name, Rarity, Odds }, {} for an unknown boss.
--     RagaSidekickChance = 0.00001, a fraction (design doc 4.37: 0.001%).
--   Server/RelicService (bag and gear as Server/SidekickService):
--     Roll(boss, rng): the row, nil for an unknown boss. Pure, exactly one rng:NextNumber() and nothing else.
--     Grant(player, id): true, entry or false, reason. Bag row = { Id, Entry }, Entry a unique string.
--     Equip(player, characterId, entry): true or false, reason. entry nil takes off (the one remote carries both);
--     Unequip(player, characterId): the same take-off, returns true.
--     Snapshot(player): { Relics = rows, RelicGear = { [characterId] = entry } }, exactly these 2 fields.
--     Apply(player, saved): takes the whole save record; junk reads as empty; an unknown id stays, worn or not.
--     Multi(player, characterId, stat): 1 + the worn Relic's bonus, 1 with none, an unknown id or junk.
--     GrantDefeat(player, boss, rng): true or false, reason. Draw 1 picks the Relic, draw 2 is the Sidekick roll:
--     a draw <= RagaSidekickChance grants side_raga through SidekickService.Grant. A refusal there leaves the Relic given.
--     Start(): makes RemoteFunction Remotes.RelicEquip, args (characterId, entry or nil). Attributes RelicBag and RelicGear are JSON.
--   Saved fields `Relics` and `RelicGear`, PlayerData VERSION 16. CharacterGear stays Sidekick-only: its value is one entry
--     string that SidekickService.Apply and the sidekicks tests read, so nesting Relics there would change a saved shape.
--     docs/RELIC_SPEC.md and BOSS_EVENT_SPEC say `CharacterGear` for this: their wording needs the owner's update.
--   BossEventService.Hooks.Rewards default: GrantDefeat(player, "big_raga", its own Random) for each player.
--   GachaService.MoneyMulti and Luck: each Team character's Multi - 1 is added like the tree bonus (GachaConfig.Multis).
--   CruiseFor and the run's stamina seconds: multiplied by the wearer's Multi, like the Sidekick's.
--   Boss TeamDamage: each Sidekick's Damage x its wearer's Multi, then averaged. Hit spacing = HitEverySeconds / attack multi.
--
-- READINGS the docs leave open, each pinned by a check and for the owner to confirm (names start with reading_):
--   full Sidekick bag: SidekickService.Grant's own rule refuses, so the 0.001% win is lost while the Relic is still given.
--   team attack speed: the team hits as one (4.37), so its attack multi is the average of the team's multis.
--   relic bag: no rule gives it a cap, so a defeat's Relic is never refused. No sell: no rule gives Relics a value.
--   rebirth keeps Relics, like Sidekicks.
-- NOT covered: icons (in-house art, none yet), the Details sheet showing these odds (the paid spawn's task).
--
-- Runs on Folder players and an isolated PlayerData clone, like SidekickTests.
-- On demand: ReplicatedStorage attributes CarTestOnly = "relics", then CarTestRun = true.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990138000
local VERSION = 16
local BOSS = "big_raga"
local STATS = { "Damage", "AttackSpeed", "Luck", "Money", "Speed", "Stamina" }
local STAT_COUNT = { Common = 1, Rare = 1, Epic = 2, Legendary = 3, Mythic = 4, Secret = 6 } -- design doc 4.38
local RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local SOURCE_NAMES = { "sukuna", "gojo", "mahoraga", "sixeyes" } -- section 5; compared with letters only
local T0 = 1000000 -- the fake boss clock's start
local WINDOW = 60 -- s of hits counted in the attack speed checks

local function approx(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6
end

-- A stand-in for Random: hands out `values` in order, then repeats the last. Draws counts the calls.
local function scripted(values)
	local rng = { Draws = 0 }
	function rng:NextNumber()
		self.Draws += 1
		return values[self.Draws] or values[#values]
	end
	return rng
end

function Tests.relics()
	local r, flag = H.report("relics")
	local gacha, Admin = require(Server.GachaService), require(Server.AdminService)
	local GachaConfig = require(Shared.GachaConfig)
	local rebirth = require(Server.RebirthService)
	local oldLuck, oldRoll, oldConfigRoll = gacha.Luck, gacha.Roll, GachaConfig.Roll
	local oldStudio, oldRebirthCooldown = Admin.AllowStudio, rebirth.REMOTE_COOLDOWN
	local B, oldHooks
	local cleanup, runs = {}, {}

	local function section(name, body)
		local ok, err = xpcall(body, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end

	local ok, err = xpcall(function()
		local C = require(Shared.RelicConfig)
		local S = require(Server.RelicService)
		local Sidekick = require(Server.SidekickService)
		local SidekickConfig = require(Shared.SidekickConfig)
		local catalog = require(Shared.CharacterCatalog)
		local catalogTests = require(script.Parent.CatalogTests)
		local RaceConfig, StaminaConfig = require(Shared.RaceConfig), require(Shared.StaminaConfig)
		local RaceService, money = require(Server.RaceService), require(Server.MoneyService)
		local factory, npc, npcConfig =
			require(Shared.RunnerFactory), require(Shared.NpcRacer), require(Shared.NpcConfig)
		Admin.AllowStudio = true
		rebirth.REMOTE_COOLDOWN = 0

		local rows = C.Bosses[BOSS]
		local rowOf = {}
		for _, row in rows do
			rowOf[row.Rarity] = row
		end
		local secret = rowOf.Secret
		local function bonus(row, stat)
			return row.Bonuses[stat] or 0
		end

		-- Clone only PlayerData so SetStore never redirects the live player's autosaves.
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestRelicData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local store = H.store()
		data.SetStore(store)

		local nextId = UID
		local function loaded(saved)
			nextId += 1
			store.data[data.KeyFor(nextId)] = saved
			local p = H.player(cleanup, nextId)
			return p, nextId, data.Load(p, nextId)
		end

		local chars = {}
		for _, spec in catalog.All() do
			if spec.Rollable and spec.Id ~= catalog.STARTER_ID then
				table.insert(chars, spec.Id)
			end
		end
		local charA, charB, charC, charUnowned = chars[1], chars[2], chars[3], chars[4]
		flag("test_has_four_characters", charUnowned ~= nil)
		local function dressed()
			local p, id, fine = loaded(nil)
			gacha.Grant(p, charA)
			gacha.Grant(p, charB)
			gacha.Grant(p, charC)
			return p, id, fine
		end
		local function snap(p)
			return S.Snapshot(p)
		end
		local function bag(p)
			return snap(p).Relics or {}
		end
		local function gear(p)
			return snap(p).RelicGear or {}
		end
		local function unchanged(p, before)
			return H.same(snap(p), before)
		end
		local function has(p, entry)
			for _, item in bag(p) do
				if item.Entry == entry then
					return true
				end
			end
			return false
		end
		local function grant(p, id)
			local _, entry = S.Grant(p, id)
			return entry
		end
		local function ragas(p)
			local n = 0
			for _, item in Sidekick.Snapshot(p).Sidekicks do
				n += item.Id == "side_raga" and 1 or 0
			end
			return n
		end

		section("config", function()
			flag("boss_lists_six", #rows == 6, #rows, 6)
			for i, rarity in RARITIES do
				flag("one_row_" .. rarity, rowOf[rarity] ~= nil and rows[i] == rowOf[rarity])
			end
			local knownStat = {}
			for _, stat in STATS do
				knownStat[stat] = true
			end
			local seen = {}
			for _, row in rows do
				local label = row.Rarity
				flag("id_unique_" .. label, type(row.Id) == "string" and row.Id ~= "" and not seen[row.Id])
				seen[row.Id] = true
				flag("id_lowercase_" .. label, row.Id == string.lower(row.Id))
				flag("get_returns_row_" .. label, C.Get(row.Id) == row)
				local letters = string.gsub(string.lower(row.Id .. " " .. row.Name), "%A", "")
				local clean = catalogTests.realNameIn(string.lower(row.Id)) == nil
					and catalogTests.realNameIn(string.lower(row.Name)) == nil
				for _, name in SOURCE_NAMES do
					clean = clean and string.find(letters, name, 1, true) == nil
				end
				flag("no_real_name_" .. label, clean, row.Id .. " " .. row.Name)
				local count, valid = 0, true
				for stat, value in row.Bonuses do
					count += 1
					valid = valid and knownStat[stat] == true and type(value) == "number" and value > 0 and value < 1
				end
				flag("bonuses_valid_" .. label, valid)
				flag("stat_count_" .. label, count == STAT_COUNT[label], count, STAT_COUNT[label])
			end
			flag("get_unknown_nil", C.Get("no_such") == nil and C.Get(5) == nil and C.Get(nil) == nil)

			-- Design doc 4.38: Rare's one stat is higher than Common's.
			local function top(row)
				local best = 0
				for _, value in row.Bonuses do
					best = math.max(best, value)
				end
				return best
			end
			flag("rare_higher_than_common", top(rowOf.Rare) > top(rowOf.Common), top(rowOf.Rare), top(rowOf.Common))

			-- Big Raga's priority: Stamina and Damage on Epic to Mythic, everything else lower.
			local lastStamina, lastDamage = 0, 0
			for _, rarity in { "Epic", "Legendary", "Mythic" } do
				local row = rowOf[rarity]
				local stamina, damage = bonus(row, "Stamina"), bonus(row, "Damage")
				flag("priority_has_both_" .. rarity, stamina > 0 and damage > 0)
				local highestOther = 0
				for stat, value in row.Bonuses do
					if stat ~= "Stamina" and stat ~= "Damage" then
						highestOther = math.max(highestOther, value)
					end
				end
				flag(
					"priority_highest_" .. rarity,
					math.min(stamina, damage) > highestOther,
					math.min(stamina, damage),
					highestOther
				)
				flag("priority_grows_" .. rarity, stamina > lastStamina and damage > lastDamage)
				lastStamina, lastDamage = stamina, damage
			end
			for _, stat in STATS do
				flag("secret_has_" .. stat, bonus(secret, stat) > 0)
			end

			-- Section 6: every outcome, as a percentage, summing to exactly 100.
			local list = C.Odds(BOSS)
			flag("odds_lists_all", #list == #rows, #list, #rows)
			local rowSum, listSum = 0, 0
			for i, row in rows do
				rowSum += row.Odds
				local shown = list[i]
				listSum += shown and shown.Odds or 0
				flag(
					"odds_row_" .. row.Rarity,
					shown ~= nil and shown.Id == row.Id and shown.Odds == row.Odds and shown.Name == row.Name
				)
				flag("odds_rarer_is_rarer_" .. row.Rarity, i == 1 or row.Odds < rows[i - 1].Odds)
			end
			flag("rows_sum_100", math.abs(rowSum - 100) < 1e-9, rowSum, 100)
			flag("odds_sum_100", math.abs(listSum - 100) < 1e-9, listSum, 100)
			flag("odds_unknown_boss_empty", #C.Odds("no_boss") == 0)

			-- Design doc 4.38: one universal Secret, shared by every boss.
			for name, list2 in C.Bosses do
				local secrets = {}
				for _, row in list2 do
					if row.Rarity == "Secret" then
						table.insert(secrets, row)
					end
				end
				flag("boss_shares_secret_" .. name, #secrets == 1 and secrets[1] == secret)
			end
			flag("secret_not_named_for_a_boss", string.find(secret.Id, "raga", 1, true) == nil, secret.Id)

			-- Design doc 4.37: 0.001%, shown as the Sidekick row's own percent.
			flag("raga_chance_owner_value", C.RagaSidekickChance == 0.00001, C.RagaSidekickChance, 0.00001)
			local raga = SidekickConfig.Get("side_raga")
			flag("raga_row_agrees", raga ~= nil and approx(C.RagaSidekickChance * 100, raga.Odds))
		end)

		section("roll", function()
			local cumulative = 0
			for _, row in rows do
				local rng = scripted({ (cumulative + row.Odds / 2) / 100 })
				local rolled = S.Roll(BOSS, rng)
				flag("roll_maps_" .. row.Rarity, rolled == row, rolled and rolled.Id, row.Id)
				flag("roll_one_draw_" .. row.Rarity, rng.Draws == 1, rng.Draws, 1)
				cumulative += row.Odds
			end
			flag("roll_unknown_boss", S.Roll("no_boss", Random.new(1)) == nil)

			local ROLLS, tally, rng = 100000, {}, Random.new(20261105)
			for _ = 1, ROLLS do
				local id = S.Roll(BOSS, rng).Id
				tally[id] = (tally[id] or 0) + 1
			end
			for _, row in rows do
				local share = (tally[row.Id] or 0) / ROLLS * 100
				local p = row.Odds / 100
				local allowed = 5 * math.sqrt(p * (1 - p) / ROLLS) * 100 -- 5 standard deviations
				flag("distribution_" .. row.Rarity, math.abs(share - row.Odds) < allowed, share, row.Odds)
			end

			-- RELIC_SPEC: luck, potions and pity never change the odds. A worn Luck bonus included.
			local function sequence(seed)
				local seeded, out = Random.new(seed), {}
				for i = 1, 200 do
					out[i] = S.Roll(BOSS, seeded).Id
				end
				return out
			end
			local plain = sequence(4242)
			local lucky = dressed()
			S.Equip(lucky, charA, grant(lucky, secret.Id))
			lucky:SetAttribute("AdminLuck", 1e6)
			flag("luck_setup_real", gacha.Luck(lucky) > 1e6, gacha.Luck(lucky))
			local touched = 0
			local function touch(original)
				return function(...)
					touched += 1
					return original(...)
				end
			end
			gacha.Luck, gacha.Roll, GachaConfig.Roll = touch(oldLuck), touch(oldRoll), touch(oldConfigRoll)
			local same = H.same(sequence(4242), plain)
			S.GrantDefeat(lucky, BOSS, Random.new(9))
			gacha.Luck, gacha.Roll, GachaConfig.Roll = oldLuck, oldRoll, oldConfigRoll
			flag("roll_same_with_luck", same)
			flag("drop_never_touches_luck_or_gacha_roll", touched == 0, touched, 0)
		end)

		section("defeat", function()
			local function afterDraws(values)
				local p = loaded(nil)
				local rng = scripted(values)
				local done = S.GrantDefeat(p, BOSS, rng)
				return p, rng, done
			end
			local NEVER = 0.5
			local chance = C.RagaSidekickChance
			local p, rng, done = afterDraws({ 0, NEVER })
			flag("defeat_ok", done == true)
			flag("defeat_one_relic", #bag(p) == 1, #bag(p), 1)
			flag("defeat_first_draw_picks_relic", bag(p)[1] ~= nil and bag(p)[1].Id == rows[1].Id)
			flag("defeat_two_draws", rng.Draws == 2, rng.Draws, 2)
			flag("defeat_miss_no_sidekick", ragas(p) == 0)

			p = afterDraws({ NEVER, chance })
			flag("raga_hits_at_threshold", ragas(p) == 1, ragas(p), 1)
			flag("raga_hit_keeps_relic", #bag(p) == 1)
			p = afterDraws({ NEVER, 0 })
			flag("raga_hits_below_threshold", ragas(p) == 1, ragas(p), 1)
			p = afterDraws({ NEVER, chance * 1.0001 })
			flag("raga_misses_above_threshold", ragas(p) == 0, ragas(p), 0)

			-- Independent: the Relic's own draw never decides the Sidekick, and the other way round.
			p = afterDraws({ chance, NEVER })
			flag("relic_draw_does_not_grant_raga", ragas(p) == 0, ragas(p), 0)
			p = afterDraws({ 0.99999, chance })
			flag("secret_relic_and_raga_together", bag(p)[1].Id == secret.Id and ragas(p) == 1)

			local grantedTo = loaded(nil)
			S.GrantDefeat(grantedTo, BOSS, scripted({ NEVER, chance }))
			local ragaRows = Sidekick.Snapshot(grantedTo).Sidekicks
			flag("raga_entry_usable", #ragaRows == 1 and type(ragaRows[1].Entry) == "string")
			flag("raga_not_auto_worn", next(Sidekick.Snapshot(grantedTo).CharacterGear) == nil)

			-- Nothing changes for a boss that does not exist.
			local stranger = loaded(nil)
			local before = H.copy(snap(stranger))
			flag("defeat_unknown_boss_refused", (S.GrantDefeat(stranger, "no_boss", Random.new(1))) == false)
			flag("defeat_unknown_boss_no_change", unchanged(stranger, before) and ragas(stranger) == 0)

			-- SidekickService.Grant refuses into a full bag; no drop rule overrides it (design doc 4.36 has only summons).
			local full = loaded(nil)
			for _ = 1, SidekickConfig.BagSize do
				Sidekick.Grant(full, SidekickConfig.List[1].Id)
			end
			local count = #Sidekick.Snapshot(full).Sidekicks
			flag("full_bag_setup", count == SidekickConfig.BagSize, count, SidekickConfig.BagSize)
			local fullRng = scripted({ NEVER, chance })
			flag("reading_raga_full_bag_defeat_still_ok", S.GrantDefeat(full, BOSS, fullRng) == true)
			flag("reading_raga_full_bag_relic_given", #bag(full) == 1, #bag(full), 1)
			flag(
				"reading_raga_full_bag_refused",
				ragas(full) == 0 and #Sidekick.Snapshot(full).Sidekicks == count,
				ragas(full),
				0
			)

			-- 60 is past the Sidekick bag's 50: Relics have no cap rule, and a defeat must not lose its Relic.
			local hoard = loaded(nil)
			for _ = 1, 60 do
				S.Grant(hoard, rows[1].Id)
			end
			flag("reading_relic_bag_no_cap", #bag(hoard) == 60, #bag(hoard), 60)
		end)

		section("equip", function()
			local p = dressed()
			local fine, e1 = S.Grant(p, rows[1].Id)
			local e2 = grant(p, rows[1].Id)
			flag("grant_ok", fine == true and type(e1) == "string")
			flag("duplicates_are_entries", e1 ~= e2 and #bag(p) == 2, #bag(p), 2)
			flag("bag_row_shape", bag(p)[1].Id == rows[1].Id and bag(p)[1].Entry == e1)

			flag("equip_ok", S.Equip(p, charA, e1) == true and gear(p)[charA] == e1)
			flag("duplicate_on_second_character", S.Equip(p, charB, e2) == true and gear(p)[charB] == e2)
			flag("equip_move_ok", S.Equip(p, charC, e1) == true)
			flag("equip_move_clears_old", gear(p)[charA] == nil and gear(p)[charC] == e1)
			local e3 = grant(p, rows[3].Id)
			flag("equip_replace_ok", S.Equip(p, charC, e3) == true and gear(p)[charC] == e3)
			flag("equip_replace_frees_old", has(p, e1) and gear(p)[charA] == nil)

			local before = H.copy(snap(p))
			flag("equip_unowned_refused", S.Equip(p, charUnowned, e1) == false and unchanged(p, before))
			flag("equip_unknown_character_refused", S.Equip(p, "no_such", e1) == false and unchanged(p, before))
			flag("equip_unknown_entry_refused", S.Equip(p, charA, "no_such") == false and unchanged(p, before))
			local other = dressed()
			flag("equip_other_players_entry_refused", S.Equip(other, charA, e1) == false)

			for label, junk in { text = "lots", table = {}, bool = true, number = -1 } do
				local ran, result = pcall(S.Equip, p, charA, junk)
				flag("junk_entry_" .. label, ran and result == false and unchanged(p, before), tostring(result))
			end
			for label, junk in { number = 5, table = {}, bool = true, missing = false } do
				local character = junk ~= false and junk or nil
				local ran, result = pcall(S.Equip, p, character, e1)
				flag("junk_character_" .. label, ran and result == false and unchanged(p, before), tostring(result))
				ran, result = pcall(S.Unequip, p, character)
				flag("junk_unequip_" .. label, ran and result == false and unchanged(p, before), tostring(result))
			end
			for label, junk in { number = 5, table = {}, unknown = "no_such", missing = false } do
				local ran, result = pcall(S.Grant, p, junk ~= false and junk or nil)
				flag("junk_grant_" .. label, ran and result == false and unchanged(p, before), tostring(result))
			end

			flag("unequip_ok", S.Unequip(p, charC) == true and gear(p)[charC] == nil and has(p, e3))
			S.Equip(p, charA, e1)
			flag("equip_nil_takes_off", S.Equip(p, charA, nil) == true and gear(p)[charA] == nil)
			flag("unequip_unowned_refused", S.Unequip(p, charUnowned) == false)

			-- Attributes are what the client reads.
			S.Equip(p, charA, e1)
			local shownBag = HttpService:JSONDecode(p:GetAttribute("RelicBag"))
			local shownGear = HttpService:JSONDecode(p:GetAttribute("RelicGear"))
			flag("attribute_bag", H.same(shownBag, bag(p)))
			flag("attribute_gear", H.same(shownGear, gear(p)))

			-- Relics and Sidekicks share a character, never a saved slot.
			local _, sideEntry = Sidekick.Grant(p, SidekickConfig.List[1].Id)
			Sidekick.Equip(p, charA, sideEntry)
			flag("sidekick_gear_untouched", Sidekick.Snapshot(p).CharacterGear[charA] == sideEntry)
			flag("relic_gear_untouched", gear(p)[charA] == e1)

			-- Design doc 4.38: never traded.
			flag("no_trade_api", S.Trade == nil and S.Gift == nil and S.Transfer == nil)
			flag("reading_no_relic_sell", S.Sell == nil)
			S.Start()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local equipRemote = remotes and remotes:FindFirstChild("RelicEquip")
			flag("remote_exists", equipRemote ~= nil and equipRemote:IsA("RemoteFunction"))
			local others = {}
			for _, item in remotes and remotes:GetChildren() or {} do
				if string.find(string.lower(item.Name), "relic", 1, true) and item ~= equipRemote then
					table.insert(others, item.Name)
				end
			end
			flag("only_remote_is_equip", #others == 0, table.concat(others, ","), "")
		end)

		section("multi", function()
			local p = dressed()
			flag("multi_none", S.Multi(p, charA, "Damage") == 1)
			flag("multi_junk", S.Multi(p, 5, "Damage") == 1 and S.Multi(p, nil, "Stamina") == 1)
			for _, row in rows do
				S.Equip(p, charA, grant(p, row.Id))
				for _, stat in STATS do
					local want = 1 + bonus(row, stat)
					flag(
						"multi_" .. row.Rarity .. "_" .. stat,
						approx(S.Multi(p, charA, stat), want),
						S.Multi(p, charA, stat),
						want
					)
					flag("multi_other_character_" .. row.Rarity .. "_" .. stat, S.Multi(p, charB, stat) == 1)
				end
				flag("multi_unknown_stat_" .. row.Rarity, S.Multi(p, charA, "NoSuchStat") == 1)
				S.Unequip(p, charA)
				flag("multi_off_after_take_off_" .. row.Rarity, S.Multi(p, charA, "Stamina") == 1)
			end
		end)

		section("cruise", function()
			local p = dressed()
			local base = gacha.CruiseFor(p, charA)
			local baseB = gacha.CruiseFor(p, charB)
			S.Equip(p, charA, grant(p, secret.Id))
			local gain = 1 + bonus(secret, "Speed")
			flag("cruise_gain", approx(gacha.CruiseFor(p, charA), base * gain), gacha.CruiseFor(p, charA), base * gain)
			flag("cruise_other_character_unchanged", approx(gacha.CruiseFor(p, charB), baseB))
			local fast = SidekickConfig.Get("side_wyvern")
			local _, sideEntry = Sidekick.Grant(p, fast.Id)
			Sidekick.Equip(p, charA, sideEntry)
			local both = base * gain * (1 + fast.Cruise)
			flag("cruise_multiplies_sidekick", approx(gacha.CruiseFor(p, charA), both), gacha.CruiseFor(p, charA), both)
			S.Unequip(p, charA)
			Sidekick.Equip(p, charA, nil)
			flag("cruise_back_after_take_off", approx(gacha.CruiseFor(p, charA), base))

			-- Without Speed a Relic moves no cruise; just under the cap, Secret stops at MAX_CRUISE.
			S.Equip(p, charA, grant(p, rows[1].Id))
			flag("cruise_common_no_speed", bonus(rows[1], "Speed") > 0 or approx(gacha.CruiseFor(p, charA), base))
			local capped = dressed()
			local points = math.floor((RaceConfig.MAX_CRUISE / base - 1) / RaceConfig.SPEED_PER_POINT) - 1
			capped:SetAttribute("Alloc_Speed", points)
			local below = gacha.CruiseFor(capped, charA)
			flag("cap_setup_below", below < RaceConfig.MAX_CRUISE, below, RaceConfig.MAX_CRUISE)
			flag("cap_setup_crosses", below * gain > RaceConfig.MAX_CRUISE)
			S.Equip(capped, charA, grant(capped, secret.Id))
			local worn = gacha.CruiseFor(capped, charA)
			flag("cruise_capped", worn == RaceConfig.MAX_CRUISE, worn, RaceConfig.MAX_CRUISE)
		end)

		section("stamina", function()
			local points3 = {}
			for i = 0, 2 do
				table.insert(points3, Vector3.new(0, 2000, -i * 20))
			end
			local path = { Waypoints = points3, Curvature = { 0, 0, 0 }, Length = 40 }
			local route = {
				Path = { WorldWaypoints = points3, Curvature = { 0, 0, 0 }, Width = 40, Closed = false },
				Pads = {},
				Tracks = {
					{
						Number = 1,
						StartIndex = 1,
						FinishIndex = 3,
						Npc = { Config = npcConfig.For(1), Path = path, Profile = npc.Profile(path, 1) },
					},
				},
			}
			local function runSeconds(p)
				local car = factory.build(charA)
				car.Name, car.Parent = "CarTestRelicRunner", p
				local run =
					RaceService.NewRun(car, route, p, { Npc = true, StartTrack = 1, NpcSpeeds = { [1] = 0.001 } })
				table.insert(runs, run)
				local s1, s2 = p:GetAttribute("RunSeconds1"), p:GetAttribute("RunSeconds2")
				run:Destroy()
				return s1, s2
			end
			local p = dressed()
			flag("team_set", gacha.SetTeam(p, { charA, charB }) == true)
			local multi = gacha.StaminaMulti(p)
			local wantA = StaminaConfig.Seconds(catalog.Get(charA), multi)
			local wantB = StaminaConfig.Seconds(catalog.Get(charB), multi)
			local s1, s2 = runSeconds(p)
			flag("stamina_plain", approx(s1, wantA) and approx(s2, wantB), s1, wantA)
			S.Equip(p, charA, grant(p, secret.Id))
			local gain = 1 + bonus(secret, "Stamina")
			s1, s2 = runSeconds(p)
			flag("stamina_worn_slot", approx(s1, wantA * gain), s1, wantA * gain)
			flag("stamina_other_slot", approx(s2, wantB), s2, wantB)
			flag("team_row_refreshed_on_equip", math.abs((p:GetAttribute("TeamStamina1") or 0) - wantA * gain) < 0.06)
			local tough = SidekickConfig.Get("side_chain")
			local _, sideEntry = Sidekick.Grant(p, tough.Id)
			Sidekick.Equip(p, charA, sideEntry)
			local both = wantA * gain * (1 + tough.Stamina)
			s1 = runSeconds(p)
			flag("stamina_multiplies_sidekick", approx(s1, both), s1, both)
		end)

		section("team_stats", function()
			-- Design doc 4.38 and RELIC_SPEC: counted while on the Team, added like the upgrade tree bonus.
			for _, kind in
				{
					{ "Money", gacha.MoneyMulti },
					{ "Luck", gacha.Luck },
				}
			do
				local stat, read = kind[1], kind[2]
				local value = bonus(secret, stat)
				local p = dressed()
				flag(stat .. "_team_set", gacha.SetTeam(p, { charA, charB }) == true)
				p:SetAttribute("Alloc_" .. stat, 3)
				local alloc = { [stat] = 3 }
				local plain = GachaConfig.Multis(alloc, {})[stat]
				local base = read(p)
				local function want(extra)
					return base * GachaConfig.Multis(alloc, { [stat] = extra })[stat] / plain
				end
				S.Equip(p, charC, grant(p, secret.Id))
				flag(stat .. "_off_team_counts_nothing", approx(read(p), base), read(p), base)
				gacha.SetTeam(p, { charA, charC })
				flag(stat .. "_on_team_added", approx(read(p), want(value)), read(p), want(value))
				S.Equip(p, charA, grant(p, secret.Id))
				flag(stat .. "_two_add_up", approx(read(p), want(2 * value)), read(p), want(2 * value))
				gacha.SetTeam(p, { charB })
				flag(stat .. "_off_team_again", approx(read(p), base), read(p), base)
			end
		end)

		section("boss", function()
			B = require(Server.BossEventService)
			local Cfg = require(Shared.BossEventConfig)
			oldHooks = table.clone(B.Hooks)
			local clock = T0
			local runOf = {}
			B.SetClock(function()
				return clock
			end)
			B.Hooks.Arrive = function() end
			B.Hooks.Depart = function() end
			B.Hooks.Chat = function() end
			B.Hooks.StartRun = function(p, team, lane)
				local run = { TargetSpeed = 0, Waiting = false, Team = team, Lane = lane }
				function run:Destroy() end
				runOf[p] = run
				return run
			end
			local FIGHT = Cfg.PrepSeconds + Cfg.IntroSeconds
			local function to(t)
				clock = T0 + t
				B.Advance(clock)
			end
			local function begin()
				clock = T0
				B.Reset(T0)
				B.Start("Test")
			end
			-- A player whose listed characters each wear the Sidekick side_chain; `relics` maps character to Relic id.
			local function fighter(list, relics)
				local p = dressed()
				for _, id in list do
					local _, sideEntry = Sidekick.Grant(p, "side_chain")
					Sidekick.Equip(p, id, sideEntry)
				end
				for id, relic in relics do
					S.Equip(p, id, grant(p, relic))
				end
				return p
			end
			local side = SidekickConfig.Get("side_chain").Damage

			begin()
			local plain = fighter({ charA }, {})
			local strong = fighter({ charA }, { [charA] = secret.Id })
			local pair = fighter({ charA, charB }, { [charA] = secret.Id })
			local offTeam = fighter({ charA }, { [charB] = secret.Id })
			for _, p in { plain, strong, pair, offTeam } do
				flag("join_ok", B.Join(p) == true)
			end
			B.SetTeam(pair, { charA, charB })
			B.SetTeam(strong, { charA })
			-- Before a run the speed scale reads CruiseFor, so a Speed bonus reaches it.
			local gain = 1 + bonus(secret, "Damage")
			local wantBefore = Cfg.TeamDamage({ side * gain }, gacha.CruiseFor(strong, charA, 1))
			flag("damage_before_run", approx(B.TeamDamage(strong), wantBefore), B.TeamDamage(strong), wantBefore)
			to(FIGHT)
			for _, p in { plain, strong, pair, offTeam } do
				runOf[p].TargetSpeed = 400
			end
			flag("damage_plain", approx(B.TeamDamage(plain), Cfg.TeamDamage({ side }, 400)))
			flag(
				"damage_relic",
				approx(B.TeamDamage(strong), Cfg.TeamDamage({ side * gain }, 400)),
				B.TeamDamage(strong)
			)
			local wantPair = Cfg.TeamDamage({ side * gain, side }, 400)
			flag("damage_average_of_scaled", approx(B.TeamDamage(pair), wantPair), B.TeamDamage(pair), wantPair)
			flag("damage_off_team_relic_nothing", approx(B.TeamDamage(offTeam), Cfg.TeamDamage({ side }, 400)))
			flag("hit_uses_relic_damage", approx(B.RecordHit(strong), Cfg.TeamDamage({ side * gain }, 400)))

			-- Attack speed: the same fight window, more hits. Team damage is held still, so damage / team damage = hits.
			local function hits(list, relics, team)
				begin()
				local p = fighter(list, relics)
				B.Join(p)
				B.SetTeam(p, team or list)
				to(FIGHT)
				runOf[p].TargetSpeed = 0
				to(FIGHT + WINDOW)
				local dealt, per = B.DamageOf(p), B.TeamDamage(p)
				flag("hits_setup_alive", B.IsIn(p) == true)
				return per > 0 and dealt / per or 0
			end
			local baseHits = hits({ charA }, {})
			local wantBase = math.floor(WINDOW / Cfg.HitEverySeconds)
			flag("attack_none_base_cadence", approx(baseHits, wantBase), baseHits, wantBase)
			flag("attack_setup_common_has_none", bonus(rows[1], "AttackSpeed") == 0)
			local commonHits = hits({ charA }, { [charA] = rows[1].Id })
			flag("attack_no_stat_same_cadence", approx(commonHits, wantBase), commonHits, wantBase)
			-- At most 1 short: the first hit may wait a whole base interval after the intro.
			local function close(got, multi)
				local want = WINDOW * multi / Cfg.HitEverySeconds
				return got <= want + 1e-6 and got >= math.floor(want) - 1
			end
			local attack = 1 + bonus(secret, "AttackSpeed")
			flag("attack_setup_faster", math.floor(WINDOW * attack / Cfg.HitEverySeconds) - 1 > wantBase)
			local fastHits = hits({ charA }, { [charA] = secret.Id })
			flag("attack_secret_faster", close(fastHits, attack), fastHits, WINDOW * attack / Cfg.HitEverySeconds)
			local averaged = 1 + bonus(secret, "AttackSpeed") / 2
			local pairHits = hits({ charA, charB }, { [charA] = secret.Id })
			flag(
				"reading_attack_speed_team_average",
				close(pairHits, averaged),
				pairHits,
				WINDOW * averaged / Cfg.HitEverySeconds
			)

			-- The real Rewards default, through a real defeat; a timeout still pays nothing (design doc 4.37).
			B.Hooks.Rewards = oldHooks.Rewards
			begin()
			local winner, idler = fighter({ charA }, {}), fighter({ charA }, {})
			B.Join(winner)
			B.Join(idler)
			to(FIGHT)
			runOf[winner].TargetSpeed = 800
			local guard = 0
			while B.IsIn(winner) and guard < 5000 do
				B.RecordHit(winner)
				guard += 1
			end
			flag("defeat_reached", B.State().LastEnd == "Defeated", B.State().LastEnd, "Defeated")
			flag("rewards_hook_gives_winner_one", #bag(winner) == 1, #bag(winner), 1)
			flag("rewards_hook_skips_no_damage", #bag(idler) == 0, #bag(idler), 0)
			flag("rewards_hook_big_raga_relic", bag(winner)[1] ~= nil and rowOf[C.Get(bag(winner)[1].Id).Rarity] ~= nil)

			begin()
			local late = fighter({ charA }, {})
			B.Join(late)
			to(Cfg.TotalSeconds)
			flag("timeout_reached", B.State().LastEnd == "Timeout", B.State().LastEnd, "Timeout")
			flag("timeout_pays_nothing", #bag(late) == 0, #bag(late), 0)
		end)

		section("data", function()
			local saver, saverId = dressed()
			local e1, e2 = grant(saver, rows[1].Id), grant(saver, secret.Id)
			S.Equip(saver, charA, e2)
			local _, sideEntry = Sidekick.Grant(saver, SidekickConfig.List[1].Id)
			Sidekick.Equip(saver, charA, sideEntry)
			local want = H.copy(snap(saver))
			flag("snapshot_two_fields", H.same({ want.Relics ~= nil, want.RelicGear ~= nil }, { true, true }))
			local fields = 0
			for _ in want do
				fields += 1
			end
			flag("snapshot_exactly_two", fields == 2, fields, 2)
			flag("save_ok", data.Save(saver, saverId, true) == true)
			local record = store.data[data.KeyFor(saverId)]
			flag("save_version", record.Version == VERSION, record.Version, VERSION)
			flag("save_relics", H.same(record.Relics, want.Relics))
			flag("save_gear", record.RelicGear ~= nil and record.RelicGear[charA] == e2)
			flag("save_sidekick_gear_shape", record.CharacterGear[charA] == sideEntry)
			for _, field in { "Relics", "RelicGear" } do
				local decoded = HttpService:JSONDecode(HttpService:JSONEncode(record[field]))
				flag("save_json_safe_" .. field, H.same(decoded, record[field]))
			end
			local again, _, againOk = loaded(H.copy(record))
			flag("round_trip_keeps", againOk == true and H.same(snap(again), want))
			flag("round_trip_has_entry", has(again, e1))
			flag("round_trip_multi", approx(S.Multi(again, charA, "Speed"), 1 + bonus(secret, "Speed")))
			flag("round_trip_attributes", H.same(HttpService:JSONDecode(again:GetAttribute("RelicBag")), want.Relics))

			local function empty(p)
				return #bag(p) == 0 and next(gear(p)) == nil
			end
			local old, _, oldOk = loaded({ Version = 15, Money = 5, Sidekicks = {}, CharacterGear = {} })
			flag("old_save_empty", oldOk == true and empty(old))
			local older, _, olderOk = loaded({ Version = 3, Rolls = 2 })
			flag("older_save_empty", olderOk == true and empty(older))
			local new, _, newOk = loaded(nil)
			flag("new_save_empty", newOk == true and empty(new))
			for label, junk in { text = "lots", number = 5, bool = true } do
				local bad, _, badOk = loaded({ Version = VERSION, Relics = junk, RelicGear = junk })
				flag("load_junk_clean_" .. label, badOk == true and empty(bad))
			end

			-- Rows with no usable id go; a repeated Entry is kept once; gear never points at nothing or doubles up.
			local real1, real2 = want.Relics[1], want.Relics[2]
			local dirty = loaded({
				Version = VERSION,
				Relics = {
					H.copy(real1),
					H.copy(real1),
					H.copy(real2),
					1,
					"x",
					{ Id = 5, Entry = "a" },
					{ Id = "", Entry = "b" },
					{ Entry = "c" },
					{ Id = rows[1].Id, Entry = 5 },
				},
				RelicGear = {
					[charA] = real1.Entry,
					[charB] = real1.Entry,
					[charC] = "no_such_entry",
					[charUnowned] = true,
				},
			})
			flag("load_rows_clean", #bag(dirty) == 2, #bag(dirty), 2)
			local holders, gearClean = 0, true
			for _, value in gear(dirty) do
				gearClean = gearClean and has(dirty, value)
				holders += value == real1.Entry and 1 or 0
			end
			flag("load_gear_points_at_entries", gearClean)
			flag("load_gear_one_holder", holders == 1, holders, 1)

			-- An id from a newer version survives so a rollback destroys nothing: kept, worn, gives 1.
			local futureRow = { Id = "relic_future_test", Entry = "future-entry" }
			local future, futureId = loaded({
				Version = VERSION,
				Relics = { futureRow },
				RelicGear = { [catalog.STARTER_ID] = futureRow.Entry },
			})
			flag("unknown_id_kept", #bag(future) == 1 and bag(future)[1].Id == futureRow.Id)
			flag("unknown_id_gear_kept", gear(future)[catalog.STARTER_ID] == futureRow.Entry)
			flag("unknown_id_multi_one", S.Multi(future, catalog.STARTER_ID, "Damage") == 1)
			data.Save(future, futureId, true)
			flag("unknown_id_saved", store.data[data.KeyFor(futureId)].Relics[1].Id == futureRow.Id)
		end)

		section("admin", function()
			local admin = dressed()
			flag("admin_grant_ok", Admin.Run(admin, "/relic " .. rows[1].Id) == true)
			flag("admin_grant_one", #bag(admin) == 1 and bag(admin)[1].Id == rows[1].Id)
			local before = H.copy(snap(admin))
			flag("admin_rejects_unknown", Admin.Run(admin, "/relic no_such") == false and unchanged(admin, before))
			flag("admin_rejects_no_id", Admin.Run(admin, "/relic") == false and unchanged(admin, before))
			flag(
				"admin_rejects_unknown_player",
				Admin.Run(admin, "/relic " .. rows[1].Id .. " NoSuchPlayerHere") == false and unchanged(admin, before)
			)
			local _, help = Admin.Run(admin, "/help")
			flag("admin_listed", string.find(help, "/relic", 1, true) ~= nil)

			S.Equip(admin, charA, bag(admin)[1].Entry)
			flag("wipe_ok", Admin.Run(admin, "/wipe") == true)
			flag("wipe_resets", #bag(admin) == 0 and next(gear(admin)) == nil)
			flag("wipe_multi_back", S.Multi(admin, charA, "Stamina") == 1)

			local reborn, rebornId = dressed()
			S.Equip(reborn, charA, grant(reborn, rows[1].Id))
			local kept = H.copy(snap(reborn))
			money.Setup(reborn).Value = rebirth.Requirements(reborn).Money
			flag("rebirth_succeeds", rebirth.Rebirth(reborn) == true)
			flag("reading_rebirth_keeps_relics", H.same(snap(reborn), kept))
			data.Save(reborn, rebornId, true)
			flag("rebirth_saves", H.same(store.data[data.KeyFor(rebornId)].Relics, kept.Relics))
		end)
	end, debug.traceback)
	flag("relics_completed", ok, ok and 1 or tostring(err))

	-- Whatever failed above, nothing of this test stays in the live game.
	gacha.Luck, gacha.Roll, GachaConfig.Roll, Admin.AllowStudio = oldLuck, oldRoll, oldConfigRoll, oldStudio
	rebirth.REMOTE_COOLDOWN = oldRebirthCooldown
	if B then
		pcall(function()
			for name, fn in oldHooks or {} do
				B.Hooks[name] = fn
			end
			B.SetClock(nil)
			B.Reset(workspace:GetServerTimeNow())
		end)
	end
	for _, run in runs do
		pcall(run.Destroy, run)
	end
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
