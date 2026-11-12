--!nonstrict
-- BRIEF: design doc 4.38, 4.37, 4.13, section 5 and 6; docs/RELIC_SPEC.md (task b8). Stat counts, the priority and the
-- 0.001% chance are owner values, asserted here; names, odds and bonuses are placeholders, always read from the config.
--
-- Contract these tests assume beyond the brief:
--   Shared/RelicConfig:
--     Bosses.big_raga: array, least rare first, of { Id, Name, Rarity, Odds, Bonuses = { <stat> = fraction } }. Odds is a percent;
--     a bonus 0.15 is +15%. Stats: Damage, AttackSpeed, Luck, Money, Speed, Stamina. Ids are lowercase.
--     Get(id): that same row, nil if unknown. Odds(boss): array of { Id, Name, Rarity, Odds }, {} for an unknown boss.
--     Chests[id].SidekickId and SidekickChance (a fraction; owner 2026-11-11, k7: raga 0.00001, adapted 0.0001, mage 0.00001,
--     king 0.00001) replace RagaSidekickChance; design doc 4.37: 0.001% / 0.01%.
--   Server/RelicService (bag and gear as Server/SidekickService):
--     Roll(boss, rng): the row, nil for an unknown boss. Pure, exactly one rng:NextNumber() and nothing else.
--     Grant(player, id): true, entry or false, reason. Bag row = { Id, Entry }, Entry a unique string.
--     Equip(player, characterId, entry): true or false, reason. entry nil takes off (the one remote carries both);
--     Unequip(player, characterId): the same take-off, returns true.
--     Snapshot(player): { Relics = rows, RelicGear = { [characterId] = entry } }, exactly these 2 fields.
--     Apply(player, saved): takes the whole save record; junk reads as empty; an unknown id stays, worn or not.
--     Multi(player, characterId, stat): 1 + the worn Relic's bonus, 1 with none, an unknown id or junk.
--     GrantDefeat is gone (k7, no production caller): the drop path is GrantChest then OpenChest; draw 1 picks the Relic,
--     draw 2 is the Sidekick roll: a draw <= the chest's SidekickChance grants its SidekickId through SidekickService.GrantDrop.
--   Server/SidekickService.GrantDrop(player, id): true, entry, ignoring BagSize, for every SidekickConfig.BossDrops row (design
--     doc 4.36 Boss Sidekicks: side_raga, side_mage, side_king; design doc 4.37: nothing else
--     may overflow); any other id is false, reason, with nothing changed.
--     Start(): makes RemoteFunctions Remotes.RelicEquip, args (characterId, entry or nil), and Remotes.RelicSell, args (entry).
--     Attributes RelicBag and RelicGear are JSON.
--     Sell(player, entry) (owner 2026-11-05): true, price or false, reason. Pays BagConfig.SELL_PRICE by rarity through MoneyService,
--     never Gems. Refuses a worn entry, an entry not in the bag and an id this version does not know.
--   Saved fields `Relics` and `RelicGear`, PlayerData VERSION 16. CharacterGear stays Sidekick-only: its value is one entry
--     string that SidekickService.Apply and the sidekicks tests read, so nesting Relics there would change a saved shape.
--     docs/RELIC_SPEC.md and BOSS_EVENT_SPEC likewise save Relic wear in the separate `RelicGear`.
--     Chests (owner 2026-11-06, design doc 4.38, RELIC_SPEC "Chests", task p2): RelicConfig.Chests[id] = { Id, Name, Chest = true,
--     Bonuses = {}, Boss, SidekickChance, Table = rows of { Id, Name, Rarity, Odds } }, apart from Bosses; Get(id) returns it;
--     ChestOdds(id): a copy of its rows, {} if unknown. GrantChest(player, id): true, entry or false, reason. OpenChest(player, entry,
--     rng): true, relicRow, wonSidekick or false, reason; draw 1 picks the Relic, draw 2 the Sidekick. Remote RelicOpenChest(entry).
--   BossEventService.Hooks.PayStage default: GrantChest plus Phase1Money through MoneyService.Award in stage 1, Phase2Gems through
--     MoneyService.AddGems in stage 2.
--   GachaService.MoneyMulti and Luck: each Team character's Multi - 1 is added like the tree bonus (GachaConfig.Multis).
--   CruiseFor and the run's stamina seconds: multiplied by the wearer's Multi, like the Sidekick's.
--   Boss hit (owner 2026-11-06): a character's Sidekick Damage x its Multi x the speed scale of its own cruise. TeamDamage: the sum over
--   the line. Hit spacing = HitEverySeconds / attack multi.
--
-- READINGS the docs leave open, each pinned by a check and for the owner to confirm (names start with reading_):
--   attack speed: each slot spaces its own hits by its own Relic's multi (4.37, owner 2026-11-06); no team average.
--   relic bag: no rule gives it a cap, so a defeat's Relic is never refused.
--   rebirth keeps Relics, like Sidekicks.
--   Her list (boss-mage-2-code-plan.md A7): Bosses.boss_mage, World Core shared by rawequal, Order = { "big_raga", "boss_mage" },
--     Chests.relic_chest_mage { Boss = "boss_mage", SidekickId = "side_mage", SidekickChance = 0.00001, Table = Odds("boss_mage") }
--     and relic_chest_king likewise for side_king (owner 2026-11-11). BossEventService.Start("Test", "boss_mage") pays hers.
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
local VERSION = 18
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

		-- Big Raga's Phase 1 chest, granted and opened: the defeat drop path since GrantDefeat went (k7).
		local RAGA_CHEST = "relic_chest_raga"
		local function defeat(p, rng)
			local _, entry = S.GrantChest(p, RAGA_CHEST)
			return S.OpenChest(p, entry, rng)
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
			local ragaChance = C.Chests.relic_chest_raga and C.Chests.relic_chest_raga.SidekickChance
			flag("raga_chance_owner_value", ragaChance == 0.00001, ragaChance, 0.00001)
			flag("raga_chance_field_gone", C.RagaSidekickChance == nil, C.RagaSidekickChance) -- k7: per chest now
			local raga = SidekickConfig.Get("side_raga")
			flag("raga_row_agrees", raga ~= nil and approx(ragaChance * 100, raga.Odds))
		end)

		-- The Elf Mage's own 6 (owner 2026-11-11, design doc 4.38, RELIC_SPEC "The Elf Mage's drops"; values proposed as written).
		section("mage_config", function()
			local MageArt = require(Shared.BossMageArt)
			local mage = C.Bosses.boss_mage
			flag("mage_list_exists", type(mage) == "table")
			if type(mage) ~= "table" then
				return
			end
			flag("mage_lists_six", #mage == 6, #mage, 6)
			local want = {
				{ "relic_helmet", "Dwarf's Helmet", "Common", 55, { AttackSpeed = 0.03 } },
				{ "relic_bracelet", "Hero's Bracelet", "Rare", 28, { Luck = 0.06 } },
				{ "relic_staff", "Elf Staff", "Epic", 12, { AttackSpeed = 0.10, Luck = 0.10 } },
				{ "relic_flask", "Priest's Flask", "Legendary", 4, { AttackSpeed = 0.15, Luck = 0.15, Damage = 0.04 } },
				{
					"relic_grimoire",
					"Master's Grimoire",
					"Mythic",
					0.9,
					{ AttackSpeed = 0.22, Luck = 0.22, Damage = 0.06, Money = 0.06 },
				},
			}
			local sum = 0
			for i, row in mage do
				sum += row.Odds
				local spec = want[i]
				if spec then
					local tag = spec[1]
					flag("mage_row_id_" .. i, row.Id == spec[1], row.Id, spec[1])
					flag("mage_row_name_" .. tag, row.Name == spec[2], row.Name, spec[2])
					flag("mage_row_rarity_" .. tag, row.Rarity == spec[3], row.Rarity, spec[3])
					flag("mage_row_odds_" .. tag, row.Odds == spec[4], row.Odds, spec[4])
					local same = true
					for stat, value in spec[5] do
						same = same and approx(row.Bonuses[stat], value)
					end
					for stat in row.Bonuses do
						same = same and spec[5][stat] ~= nil
					end
					flag("mage_row_bonuses_" .. tag, same)
					flag(
						"mage_row_stat_count_" .. tag,
						(function()
							local n = 0
							for _ in row.Bonuses do
								n += 1
							end
							return n == STAT_COUNT[row.Rarity]
						end)()
					)
					flag("mage_get_" .. tag, C.Get(row.Id) == row)
					local clean = catalogTests.realNameIn(string.lower(row.Id)) == nil
						and catalogTests.realNameIn(string.lower(row.Name)) == nil
					flag("mage_no_real_name_" .. tag, clean, row.Name)
					if tag == "relic_staff" then
						flag(
							"mage_staff_art_is_dodge_staff",
							row.Image == MageArt.StaffIcon,
							row.Image,
							MageArt.StaffIcon
						)
					else
						local image = type(row.Image) == "string" and row.Image or ""
						flag("mage_art_id_" .. tag, string.match(image, "^rbxassetid://%d+$") ~= nil, row.Image)
					end
				end
			end
			flag("mage_last_is_world_core", rawequal(mage[6], secret), mage[6] and mage[6].Id)
			flag("mage_sum_100", math.abs(sum - 100) < 1e-9, sum, 100)
			local odds = C.Odds("boss_mage")
			flag("mage_odds_lists_all", #odds == 6, #odds, 6)
			-- Her priority: attack speed and luck on Epic to Mythic, above every other stat.
			for i = 3, 5 do
				local row = mage[i]
				local attack, luck = bonus(row, "AttackSpeed"), bonus(row, "Luck")
				local highestOther = 0
				for stat, value in row.Bonuses do
					if stat ~= "AttackSpeed" and stat ~= "Luck" then
						highestOther = math.max(highestOther, value)
					end
				end
				flag(
					"mage_priority_" .. row.Rarity,
					attack > 0 and luck > 0 and math.min(attack, luck) > highestOther,
					math.min(attack, luck),
					highestOther
				)
			end
			flag("relic_order", H.same(C.Order, { "big_raga", "boss_mage", "boss_king" }))
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
			flag("luck_setup_team", gacha.SetTeam(lucky, { charA }) == true) -- Luck counts only on the Team (design doc 4.38)
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
			defeat(lucky, Random.new(9))
			gacha.Luck, gacha.Roll, GachaConfig.Roll = oldLuck, oldRoll, oldConfigRoll
			flag("roll_same_with_luck", same)
			flag("drop_never_touches_luck_or_gacha_roll", touched == 0, touched, 0)
		end)

		section("defeat", function()
			flag("grant_defeat_gone", S.GrantDefeat == nil) -- k7: no production caller
			local function afterDraws(values)
				local p = loaded(nil)
				local rng = scripted(values)
				local done = defeat(p, rng)
				return p, rng, done
			end
			local NEVER = 0.5
			local chance = C.Chests[RAGA_CHEST].SidekickChance
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
			defeat(grantedTo, scripted({ NEVER, chance }))
			local ragaRows = Sidekick.Snapshot(grantedTo).Sidekicks
			flag("raga_entry_usable", #ragaRows == 1 and type(ragaRows[1].Entry) == "string")
			flag("raga_not_auto_worn", next(Sidekick.Snapshot(grantedTo).CharacterGear) == nil)

			-- Nothing changes for a boss that does not exist.
			local stranger = loaded(nil)
			local before = H.copy(snap(stranger))
			flag("defeat_unknown_boss_refused", (S.GrantChest(stranger, "no_boss")) == false)
			flag("defeat_unknown_boss_no_change", unchanged(stranger, before) and ragas(stranger) == 0)

			-- The Big Raga drop may overflow the Sidekick bag; nothing else may (owner 2026-11-05, design doc 4.37).
			local full, fullId = loaded(nil)
			for _ = 1, SidekickConfig.BagSize do
				Sidekick.Grant(full, SidekickConfig.List[1].Id)
			end
			local function sidekicks(p)
				return #Sidekick.Snapshot(p).Sidekicks
			end
			local count = sidekicks(full)
			flag("full_bag_setup", count == SidekickConfig.BagSize, count, SidekickConfig.BagSize)
			defeat(full, scripted({ NEVER, chance * 1.0001 }))
			flag(
				"raga_overflow_miss_adds_nothing",
				ragas(full) == 0 and sidekicks(full) == count,
				sidekicks(full),
				count
			)
			local otherBefore = H.copy(Sidekick.Snapshot(full))
			flag(
				"raga_overflow_drop_only_for_raga",
				(Sidekick.GrantDrop(full, SidekickConfig.List[1].Id)) == false
					and (Sidekick.GrantDrop(full, "no_such")) == false
					and H.same(Sidekick.Snapshot(full), otherBefore)
			)
			local relicsBefore = #bag(full)
			flag("raga_overflow_defeat_ok", (defeat(full, scripted({ NEVER, chance }))) == true)
			flag("raga_overflow_relic_given", #bag(full) == relicsBefore + 1, #bag(full), relicsBefore + 1)
			flag("raga_overflow_adds_raga", ragas(full) == 1, ragas(full), 1)
			flag("raga_overflow_bag_51", sidekicks(full) == count + 1, sidekicks(full), count + 1)

			-- Kept across a save round trip; load cleaning trims nothing.
			flag("raga_overflow_save_ok", data.Save(full, fullId, true) == true)
			local fullRecord = store.data[data.KeyFor(fullId)]
			flag("raga_overflow_saved", #fullRecord.Sidekicks == count + 1, #fullRecord.Sidekicks, count + 1)
			local cleaned = Sidekick.CleanBag(H.copy(fullRecord.Sidekicks), H.copy(fullRecord.CharacterGear))
			flag("raga_overflow_clean_bag_keeps", #cleaned == count + 1, #cleaned, count + 1)
			local again, _, againOk = loaded(H.copy(fullRecord))
			flag("raga_overflow_load_ok", againOk == true)
			flag("raga_overflow_load_keeps", sidekicks(again) == count + 1, sidekicks(again), count + 1)
			flag("raga_overflow_load_keeps_raga", ragas(again) == 1, ragas(again), 1)
			flag(
				"raga_overflow_load_same",
				H.same(Sidekick.Snapshot(again).Sidekicks, Sidekick.Snapshot(full).Sidekicks)
			)

			-- Over the cap, every other way in still refuses and spends no Gems.
			local GEMS = 10 * SidekickConfig.TenCost
			again:SetAttribute("RebirthLevel", SidekickConfig.UnlockRebirth)
			again:SetAttribute("Gems", GEMS)
			local function refusesAll(label, want)
				flag("raga_overflow_summon_1_refused_" .. label, (Sidekick.Summon(again, 1)) == false)
				flag("raga_overflow_summon_10_refused_" .. label, (Sidekick.Summon(again, 10)) == false)
				flag("raga_overflow_free_refused_" .. label, (Sidekick.GrantFreeSummon(again)) == false)
				flag(
					"raga_overflow_grant_refused_" .. label,
					(Sidekick.Grant(again, SidekickConfig.List[1].Id)) == false
				)
				Admin.Run(again, "/sidekick " .. SidekickConfig.List[1].Id)
				flag("raga_overflow_bag_unchanged_" .. label, sidekicks(again) == want, sidekicks(again), want)
			end
			refusesAll("51", count + 1)
			flag("raga_overflow_no_gems_spent", again:GetAttribute("Gems") == GEMS, again:GetAttribute("Gems"), GEMS)

			-- Selling one brings it to 50, the cap: still no room.
			local sold = SidekickConfig.List[1]
			local soldEntry
			for _, row in Sidekick.Snapshot(again).Sidekicks do
				if row.Id == sold.Id then
					soldEntry = row.Entry
					break
				end
			end
			flag("raga_overflow_sell_ok", (Sidekick.Sell(again, soldEntry)) == true)
			flag("raga_overflow_sell_to_50", sidekicks(again) == count, sidekicks(again), count)
			flag(
				"raga_overflow_sell_pays",
				again:GetAttribute("Gems") == GEMS + sold.SellGems,
				again:GetAttribute("Gems"),
				GEMS + sold.SellGems
			)
			refusesAll("50", count)

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
			S.Start()
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local equipRemote = remotes and remotes:FindFirstChild("RelicEquip")
			local sellRemote = remotes and remotes:FindFirstChild("RelicSell")
			flag("remote_exists", equipRemote ~= nil and equipRemote:IsA("RemoteFunction"))
			flag("sell_remote_exists", sellRemote ~= nil and sellRemote:IsA("RemoteFunction"))
			local openRemote = remotes and remotes:FindFirstChild("RelicOpenChest")
			flag("open_chest_remote_exists", openRemote ~= nil and openRemote:IsA("RemoteFunction"))
			local others = {}
			for _, item in remotes and remotes:GetChildren() or {} do
				if
					string.find(string.lower(item.Name), "relic", 1, true)
					and item ~= equipRemote
					and item ~= sellRemote
					and item ~= openRemote
				then
					table.insert(others, item.Name)
				end
			end
			flag("only_remotes_are_equip_sell_and_open", #others == 0, table.concat(others, ","), "")
		end)

		-- Owner 2026-11-05 (design doc 4.38, docs/RELIC_SPEC.md "Selling"): by rarity, for Money, never a worn one.
		section("sell", function()
			local BagConfig = require(Shared.BagConfig)
			local p = dressed()
			local cash = money.Setup(p)
			local start, gems = cash.Value, p:GetAttribute("Gems")
			local paid = 0
			for _, row in rows do
				local entry = grant(p, row.Id)
				local count = #bag(p)
				local price = BagConfig.SELL_PRICE[row.Rarity]
				flag("sell_price_exists_" .. row.Rarity, type(price) == "number" and price > 0, price, "> 0")
				local done, got = S.Sell(p, entry)
				paid += price
				flag("sell_ok_" .. row.Rarity, done == true and got == price, got, price)
				flag("sell_pays_" .. row.Rarity, cash.Value == start + paid, cash.Value, start + paid)
				flag("sell_removes_" .. row.Rarity, not has(p, entry) and #bag(p) == count - 1)
				flag("sell_twice_refused_" .. row.Rarity, (S.Sell(p, entry)) == false and cash.Value == start + paid)
			end
			flag("sell_no_gems", p:GetAttribute("Gems") == gems, p:GetAttribute("Gems"), gems)

			local total = cash.Value
			local worn = grant(p, rows[1].Id)
			S.Equip(p, charA, worn)
			local before = snap(p)
			flag("sell_refuses_worn", (S.Sell(p, worn)) == false and unchanged(p, before) and cash.Value == total)
			for label, junk in { unknown = "no_such_entry", number = 5, table = {} } do
				local ran, result = pcall(S.Sell, p, junk)
				flag("sell_refuses_" .. label, ran and result == false and unchanged(p, before) and cash.Value == total)
			end
			flag("sell_refuses_nil", (S.Sell(p, nil)) == false and unchanged(p, before) and cash.Value == total)
			S.Equip(p, charA, nil)
			flag("sell_after_take_off", (S.Sell(p, worn)) == true and not has(p, worn))

			-- An id this version does not know may be worth something after a rollback: it stays.
			local future = dressed()
			S.Apply(future, { Relics = { { Id = "relic_future", Entry = "x" } }, RelicGear = {} })
			flag("sell_refuses_unknown_id", (S.Sell(future, "x")) == false and has(future, "x"))

			-- The Money comes first: a refused payment keeps the Relic.
			local entry = grant(p, rows[1].Id)
			local realAward = money.Award
			money.Award = function()
				return nil
			end
			local ran, result = pcall(S.Sell, p, entry)
			money.Award = realAward
			flag("sell_refused_payment_keeps_relic", ran and result == false and has(p, entry), tostring(result))
		end)

		-- Owner 2026-11-06 (design doc 4.37, 4.38, docs/RELIC_SPEC.md "Chests"): sealed spins, saved as rows of Relics.
		section("chests", function()
			local RAGA, ADAPTED = "relic_chest_raga", "relic_chest_adapted"
			local NEVER = 0.5
			local raga, adapted = C.Chests[RAGA], C.Chests[ADAPTED]
			flag("chest_rows_exist", raga ~= nil and adapted ~= nil)
			flag("chest_names", raga.Name == "Raga's Treasure" and adapted.Name == "Adapted Raga's Treasure")
			flag("chest_raga_chance", raga.SidekickChance == 0.00001, raga.SidekickChance, 0.00001)
			flag("chest_adapted_chance", adapted.SidekickChance == 0.0001, adapted.SidekickChance, 0.0001)
			for id, chest in { [RAGA] = raga, [ADAPTED] = adapted } do
				flag("chest_id_" .. id, chest.Id == id)
				flag("chest_flag_" .. id, chest.Chest == true)
				flag("chest_no_bonuses_" .. id, type(chest.Bonuses) == "table" and next(chest.Bonuses) == nil)
				flag("chest_boss_" .. id, chest.Boss == BOSS)
				flag("chest_get_" .. id, C.Get(id) == chest)
				flag("chest_not_in_bosses_" .. id, C.Bosses[id] == nil)
				local inLists = false
				for _, list in C.Bosses do
					for _, row in list do
						inLists = inLists or row.Id == id or row.Chest == true
					end
				end
				flag("chest_no_row_in_bosses_" .. id, not inLists)
				local letters = string.gsub(string.lower(chest.Id .. " " .. chest.Name), "%A", "")
				local clean = catalogTests.realNameIn(string.lower(chest.Id)) == nil
					and catalogTests.realNameIn(string.lower(chest.Name)) == nil
				for _, name in SOURCE_NAMES do
					clean = clean and string.find(letters, name, 1, true) == nil
				end
				flag("chest_no_real_name_" .. id, clean, chest.Name)
				local sum = 0
				for _, row in chest.Table do
					sum += row.Odds
					local fields = 0
					for _ in row do
						fields += 1
					end
					flag("chest_row_shape_" .. id .. "_" .. row.Rarity, fields == 4 and C.Get(row.Id) ~= nil, fields, 4)
				end
				flag("chest_sums_100_" .. id, math.abs(sum - 100) < 1e-9, sum, 100)
				local shown = C.ChestOdds(id)
				flag("chest_odds_same_" .. id, H.same(shown, chest.Table))
				flag("chest_odds_is_a_copy_" .. id, shown ~= chest.Table and shown[1] ~= chest.Table[1])
			end
			flag("chest_odds_unknown_empty", #C.ChestOdds("no_such") == 0 and #C.ChestOdds(rows[1].Id) == 0)
			flag("chest_odds_nil_empty", #C.ChestOdds(nil) == 0)
			flag("chest_raga_table_is_phase_1", H.same(raga.Table, C.Odds(BOSS)))
			-- Design doc 4.38: Phase 2 raises every rarity above Common, World Core at 0.5.
			flag("chest_adapted_six_rows", #adapted.Table == #raga.Table, #adapted.Table, #raga.Table)
			for i, row in adapted.Table do
				local old = raga.Table[i]
				flag("chest_adapted_same_relic_" .. old.Rarity, row.Id == old.Id and row.Rarity == old.Rarity)
				if old.Rarity == "Common" then
					flag("chest_adapted_common_lower", row.Odds < old.Odds, row.Odds, old.Odds)
				else
					flag("chest_adapted_higher_" .. old.Rarity, row.Odds > old.Odds, row.Odds, old.Odds)
				end
				if old.Rarity == "Secret" then
					flag("chest_adapted_world_core_owner_value", row.Odds == 0.5, row.Odds, 0.5)
				end
			end

			-- Grant: only a chest id.
			local p = loaded(nil)
			local fine, entry = S.GrantChest(p, RAGA)
			flag("grant_chest_ok", fine == true and type(entry) == "string")
			flag("grant_chest_row", bag(p)[1] ~= nil and bag(p)[1].Id == RAGA and bag(p)[1].Entry == entry)
			flag("grant_chest_published", H.same(HttpService:JSONDecode(p:GetAttribute("RelicBag")), bag(p)))
			local before = H.copy(snap(p))
			for label, junk in { relic = rows[1].Id, unknown = "no_such", number = 5, table = {}, missing = false } do
				local ran, result = pcall(S.GrantChest, p, junk ~= false and junk or nil)
				flag(
					"grant_chest_refuses_" .. label,
					ran and result == false and unchanged(p, before),
					tostring(result)
				)
			end

			-- Open: each draw lands on its own chest's table; draw 2 is the Sidekick.
			local function freshChest(id)
				local who = loaded(nil)
				local _, chestEntry = S.GrantChest(who, id)
				return who, chestEntry
			end
			for id, chest in { [RAGA] = raga, [ADAPTED] = adapted } do
				local cumulative = 0
				for _, row in chest.Table do
					local who, chestEntry = freshChest(id)
					local rng = scripted({ (cumulative + row.Odds / 2) / 100, NEVER })
					local done, relicRow, won = S.OpenChest(who, chestEntry, rng)
					local tag = id .. "_" .. row.Rarity
					flag("open_ok_" .. tag, done == true)
					flag(
						"open_returns_row_" .. tag,
						relicRow ~= nil and relicRow.Id == row.Id,
						relicRow and relicRow.Id,
						row.Id
					)
					flag("open_two_draws_" .. tag, rng.Draws == 2, rng.Draws, 2)
					flag("open_no_sidekick_" .. tag, not won and ragas(who) == 0)
					flag("open_removes_chest_" .. tag, not has(who, chestEntry))
					flag("open_adds_relic_" .. tag, #bag(who) == 1 and bag(who)[1].Id == row.Id)
					cumulative += row.Odds
				end
				local who, chestEntry = freshChest(id)
				local chance = chest.SidekickChance
				local done, _, won = S.OpenChest(who, chestEntry, scripted({ NEVER, chance }))
				flag(
					"open_sidekick_at_threshold_" .. id,
					done == true and won == true and ragas(who) == 1,
					ragas(who),
					1
				)
				flag("open_sidekick_keeps_relic_" .. id, #bag(who) == 1, #bag(who), 1)
				who, chestEntry = freshChest(id)
				_, _, won = S.OpenChest(who, chestEntry, scripted({ NEVER, chance * 1.0001 }))
				flag("open_sidekick_misses_above_" .. id, not won and ragas(who) == 0, ragas(who), 0)
				who, chestEntry = freshChest(id)
				S.OpenChest(who, chestEntry, scripted({ chance, NEVER }))
				flag("open_relic_draw_grants_no_sidekick_" .. id, ragas(who) == 0, ragas(who), 0)
			end
			-- The richer chance belongs to the Adapted chest alone.
			local BETWEEN = (raga.SidekickChance + adapted.SidekickChance) / 2
			local who, chestEntry = freshChest(RAGA)
			S.OpenChest(who, chestEntry, scripted({ NEVER, BETWEEN }))
			flag("raga_chest_misses_between", ragas(who) == 0, ragas(who), 0)
			who, chestEntry = freshChest(ADAPTED)
			S.OpenChest(who, chestEntry, scripted({ NEVER, BETWEEN }))
			flag("adapted_chest_hits_between", ragas(who) == 1, ragas(who), 1)

			-- May overflow the Sidekick bag (design doc 4.37).
			local full = loaded(nil)
			for _ = 1, SidekickConfig.BagSize do
				Sidekick.Grant(full, SidekickConfig.List[1].Id)
			end
			local _, fullChest = S.GrantChest(full, ADAPTED)
			S.OpenChest(full, fullChest, scripted({ NEVER, 0 }))
			flag(
				"open_overflows_sidekick_bag",
				#Sidekick.Snapshot(full).Sidekicks == SidekickConfig.BagSize + 1 and ragas(full) == 1,
				#Sidekick.Snapshot(full).Sidekicks,
				SidekickConfig.BagSize + 1
			)

			-- Every boss's chest rolls its own Sidekick (owner 2026-11-11, design doc 4.37, RELIC_SPEC "Chests"): the mage's and
			-- the king's chests, each with its table and its boss's Sidekick at 0.001%, through Chests[*].SidekickId.
			local function sidekicksOf(holder, id)
				local n = 0
				for _, item in Sidekick.Snapshot(holder).Sidekicks do
					n += item.Id == id and 1 or 0
				end
				return n
			end
			flag("chest_raga_sidekick_id", raga.SidekickId == "side_raga", raga.SidekickId)
			flag("chest_adapted_sidekick_id", adapted.SidekickId == "side_raga", adapted.SidekickId)
			for _, own in
				{
					{ "mage", "relic_chest_mage", "Elf Mage's Treasure", "boss_mage", "side_mage" },
					{ "king", "relic_chest_king", "Golden King's Treasure", "boss_king", "side_king" },
				}
			do
				local tag, id, name, bossId, sideId = own[1], own[2], own[3], own[4], own[5]
				local chest = C.Chests[id]
				flag("chest_" .. tag .. "_exists", chest ~= nil)
				if chest then
					flag("chest_" .. tag .. "_name", chest.Name == name, chest.Name)
					flag("chest_" .. tag .. "_id", chest.Id == id)
					flag("chest_" .. tag .. "_flag", chest.Chest == true)
					flag("chest_" .. tag .. "_boss", chest.Boss == bossId, chest.Boss)
					flag("chest_" .. tag .. "_sidekick_id", chest.SidekickId == sideId, chest.SidekickId, sideId)
					flag(
						"chest_" .. tag .. "_sidekick_chance",
						chest.SidekickChance == 0.00001,
						chest.SidekickChance,
						0.00001
					)
					local sideRow = SidekickConfig.Get(sideId)
					flag(
						"chest_" .. tag .. "_row_agrees",
						sideRow ~= nil and approx(chest.SidekickChance * 100, sideRow.Odds)
					)
					flag("chest_" .. tag .. "_table", H.same(chest.Table, C.Odds(bossId)))
					flag("chest_" .. tag .. "_get", C.Get(id) == chest)
					local opener, ownEntry = freshChest(id)
					flag("chest_" .. tag .. "_granted", ownEntry ~= nil)
					local rng = scripted({ 0, NEVER })
					local done, relicRow, won = S.OpenChest(opener, ownEntry, rng)
					flag("chest_" .. tag .. "_opens", done == true)
					local first = chest.Table[1]
					flag(
						"chest_" .. tag .. "_first_draw_relic",
						relicRow ~= nil and first ~= nil and relicRow.Id == first.Id
					)
					flag("chest_" .. tag .. "_miss_no_sidekick", not won and sidekicksOf(opener, sideId) == 0)
					flag("chest_" .. tag .. "_two_draws", rng.Draws == 2, rng.Draws, 2)
					-- Draw 2 at the chance: its own Sidekick, never Raga's; overflows the bag as Raga's does.
					local lucky, luckyEntry = freshChest(id)
					local _, _, hit = S.OpenChest(lucky, luckyEntry, scripted({ NEVER, chest.SidekickChance }))
					flag(
						"chest_" .. tag .. "_hit_grants_own",
						hit ~= nil and sidekicksOf(lucky, sideId) == 1,
						sidekicksOf(lucky, sideId),
						1
					)
					flag("chest_" .. tag .. "_hit_not_raga", ragas(lucky) == 0, ragas(lucky), 0)
					flag("chest_" .. tag .. "_hit_keeps_relic", #bag(lucky) == 1, #bag(lucky), 1)
					local above, aboveEntry = freshChest(id)
					S.OpenChest(above, aboveEntry, scripted({ NEVER, chest.SidekickChance * 1.0001 }))
					flag("chest_" .. tag .. "_misses_above_threshold", sidekicksOf(above, sideId) == 0)
				end
			end

			-- Luck never reaches it (RELIC_SPEC).
			local touched = 0
			local function touch(original)
				return function(...)
					touched += 1
					return original(...)
				end
			end
			who, chestEntry = freshChest(RAGA)
			gacha.Luck, gacha.Roll, GachaConfig.Roll = touch(oldLuck), touch(oldRoll), touch(oldConfigRoll)
			local rolled, opened = pcall(S.OpenChest, who, chestEntry, scripted({ NEVER, NEVER }))
			gacha.Luck, gacha.Roll, GachaConfig.Roll = oldLuck, oldRoll, oldConfigRoll
			flag("open_no_error_under_watch", rolled and opened == true, tostring(opened))
			flag("open_never_touches_luck_or_gacha_roll", touched == 0, touched, 0)

			-- Refusals leave the bag unchanged.
			local owner = dressed()
			local chestE = select(2, S.GrantChest(owner, RAGA))
			local relicE = grant(owner, rows[1].Id)
			local held = H.copy(snap(owner))
			for label, junk in
				{ unknown = "no_such_entry", relic = relicE, number = 5, table = {}, bool = true, missing = false }
			do
				local ran, result = pcall(S.OpenChest, owner, junk ~= false and junk or nil, scripted({ NEVER, 0 }))
				flag("open_refuses_" .. label, ran and result == false and unchanged(owner, held), tostring(result))
			end
			flag("open_refused_grants_no_sidekick", ragas(owner) == 0, ragas(owner), 0)
			local stranger = dressed()
			flag("open_other_players_chest_refused", (S.OpenChest(stranger, chestE, scripted({ NEVER, 0 }))) == false)

			-- Never worn, never sold.
			flag("equip_refuses_chest", (S.Equip(owner, charA, chestE)) == false and unchanged(owner, held))
			local cash = money.Setup(owner)
			local start = cash.Value
			flag("sell_refuses_chest", (S.Sell(owner, chestE)) == false and unchanged(owner, held))
			flag("sell_chest_pays_nothing", cash.Value == start, cash.Value, start)
			for _, stat in STATS do
				flag("multi_chest_in_bag_" .. stat, S.Multi(owner, charA, stat) == 1, S.Multi(owner, charA, stat), 1)
			end
			-- A save that somehow wears one: no error, no gain.
			local odd = dressed()
			S.Apply(odd, { Relics = { { Id = RAGA, Entry = "c" } }, RelicGear = { [charA] = "c" } })
			local ran, multi = pcall(S.Multi, odd, charA, "Damage")
			flag("multi_chest_worn_no_error", ran and multi == 1, tostring(multi), 1)

			-- Saved rows: Snapshot and Apply, and a whole save round trip that can still open it.
			local saver, saverId = dressed()
			local savedChest = select(2, S.GrantChest(saver, ADAPTED))
			local want = H.copy(snap(saver))
			local copy = dressed()
			S.Apply(copy, H.copy(want))
			flag("apply_keeps_chest_rows", H.same(snap(copy), want))
			flag("chest_save_ok", data.Save(saver, saverId, true) == true)
			local record = store.data[data.KeyFor(saverId)]
			flag("chest_saved", H.same(record.Relics, want.Relics))
			flag(
				"chest_save_json_safe",
				H.same(HttpService:JSONDecode(HttpService:JSONEncode(record.Relics)), record.Relics)
			)
			local back, _, backOk = loaded(H.copy(record))
			flag("chest_load_keeps", backOk == true and H.same(snap(back), want))
			local openedBack, backRow = S.OpenChest(back, savedChest, scripted({ NEVER, NEVER }))
			flag("chest_opens_after_load", openedBack == true and backRow ~= nil and not has(back, savedChest))
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
			B.Hooks.DamageMulti = function()
				return 1
			end
			B.Hooks.Arrive = function() end
			B.Hooks.Depart = function() end
			B.Hooks.Chat = function() end
			B.Hooks.StartRun = function(p, team, lane)
				local run = {
					TargetSpeed = 0,
					Waiting = false,
					Team = team,
					Lane = lane,
					Slot = 1,
					Stamina = { 100, 100, 100 },
				}
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
			-- side_chain's hit from `slot` of `team`, before statuses, at `multi`.
			local function hitOf(p, team, slot, multi)
				return side * multi * Cfg.SpeedScale(gacha.CruiseFor(p, team[slot], slot, team))
			end

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
			local wantBefore = hitOf(strong, { charA }, 1, gain)
			flag("damage_before_run", approx(B.TeamDamage(strong), wantBefore), B.TeamDamage(strong), wantBefore)
			to(FIGHT)
			for _, p in { plain, strong, pair, offTeam } do
				runOf[p].TargetSpeed = 400 -- not read: the speed scale is each character's own cruise
			end
			flag("damage_plain", approx(B.TeamDamage(plain), hitOf(plain, B.TeamOf(plain), 1, 1)))
			local wantStrong = hitOf(strong, { charA }, 1, gain)
			flag("damage_relic", approx(B.TeamDamage(strong), wantStrong), B.TeamDamage(strong), wantStrong)
			local wantPair = hitOf(pair, { charA, charB }, 1, gain) + hitOf(pair, { charA, charB }, 2, 1)
			flag("damage_sum_of_scaled", approx(B.TeamDamage(pair), wantPair), B.TeamDamage(pair), wantPair)
			flag(
				"damage_off_team_relic_nothing",
				approx(B.TeamDamage(offTeam), hitOf(offTeam, B.TeamOf(offTeam), 1, 1))
			)
			flag("hit_uses_relic_damage", approx(B.RecordHit(strong), wantStrong))
			B.Hooks.DamageMulti = function()
				return 0.75 * 0.9
			end
			flag("status_cut_keeps_relic_bonus", approx(B.RecordHit(strong), wantStrong * 0.75 * 0.9))
			B.Hooks.DamageMulti = function()
				return 1
			end

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
				return got <= want + 1e-6 and got >= math.floor(want) - 1 - 1e-6
			end
			local attack = 1 + bonus(secret, "AttackSpeed")
			flag("attack_setup_faster", math.floor(WINDOW * attack / Cfg.HitEverySeconds) - 1 > wantBase)
			local fastHits = hits({ charA }, { [charA] = secret.Id })
			flag("attack_secret_faster", close(fastHits, attack), fastHits, WINDOW * attack / Cfg.HitEverySeconds)
			-- Each slot on its own Relic's speed: the same window, counted per slot from the hits sent.
			begin()
			local slotHits = {}
			local oldBossHits = B.Hooks.BossHits
			B.Hooks.BossHits = function(_, entries)
				for _, entry in entries do
					slotHits[entry.Slot] = (slotHits[entry.Slot] or 0) + 1
				end
			end
			local duo = fighter({ charA, charB }, { [charA] = secret.Id })
			B.Join(duo)
			B.SetTeam(duo, { charA, charB })
			to(FIGHT)
			to(FIGHT + WINDOW)
			B.Hooks.BossHits = oldBossHits
			local fastSlot, plainSlot = slotHits[1] or 0, slotHits[2] or 0
			flag(
				"reading_attack_speed_own_slot",
				close(fastSlot, attack),
				fastSlot,
				WINDOW * attack / Cfg.HitEverySeconds
			)
			flag("reading_attack_speed_not_shared", close(plainSlot, 1), plainSlot, WINDOW / Cfg.HitEverySeconds)

			-- The real PayStage and RewardPopup defaults, through real defeats; a timeout still pays nothing (design doc 4.37).
			begin()
			local winner, idler = fighter({ charA }, {}), fighter({ charA }, {})
			local cash = money.Setup(winner)
			local startMoney, startGems = cash.Value, winner:GetAttribute("Gems") or 0
			B.Join(winner)
			B.Join(idler)
			to(FIGHT)
			runOf[winner].TargetSpeed = 800
			local guard = 0
			while B.IsIn(winner) and B.State().Stage ~= 2 and guard < 5000 do
				B.RecordHit(winner)
				guard += 1
			end
			flag("defeat_reached", B.State().Stage == 2, B.State().Stage, 2)
			flag("rewards_hook_gives_winner_one", #bag(winner) == 1, #bag(winner), 1)
			flag("rewards_hook_skips_no_damage", #bag(idler) == 0, #bag(idler), 0)
			flag("rewards_hook_raga_chest", bag(winner)[1] ~= nil and bag(winner)[1].Id == "relic_chest_raga")
			flag(
				"rewards_hook_phase_1_money",
				cash.Value == startMoney + Cfg.Phase1Money,
				cash.Value,
				startMoney + Cfg.Phase1Money
			)
			flag("rewards_hook_phase_1_no_gems", (winner:GetAttribute("Gems") or 0) == startGems)
			to(B.State().ScreamEndsAt - T0)
			B.Hooks.DamageMulti = function()
				return 1e9
			end
			B.RecordHit(winner)
			B.Hooks.DamageMulti = function()
				return 1
			end
			flag("final_defeat_reached", B.State().LastEnd == "Defeated", B.State().LastEnd, "Defeated")
			flag("rewards_hook_second_chest", #bag(winner) == 2 and bag(winner)[2].Id == "relic_chest_adapted")
			flag(
				"rewards_hook_phase_2_gems",
				winner:GetAttribute("Gems") == startGems + Cfg.Phase2Gems,
				winner:GetAttribute("Gems"),
				startGems + Cfg.Phase2Gems
			)
			flag(
				"rewards_hook_phase_2_no_money",
				cash.Value == startMoney + Cfg.Phase1Money,
				cash.Value,
				startMoney + Cfg.Phase1Money
			)
			flag("rewards_hook_idler_still_nothing", #bag(idler) == 0, #bag(idler), 0)

			-- Her defeat pays her own chest and Phase 1's Money, and no Phase 2 (design doc 4.37).
			clock = T0
			B.Reset(T0)
			B.Start("Test", "boss_mage")
			local mageWinner = fighter({ charA }, {})
			local mageCash = money.Setup(mageWinner)
			local mageStart = mageCash.Value
			B.Join(mageWinner)
			to(FIGHT)
			B.Hooks.DamageMulti = function()
				return 1e9
			end
			B.RecordHit(mageWinner)
			B.Hooks.DamageMulti = function()
				return 1
			end
			flag("mage_defeat_reached", B.State().LastEnd == "Defeated", B.State().LastEnd, "Defeated")
			flag(
				"rewards_hook_mage_chest",
				#bag(mageWinner) == 1 and bag(mageWinner)[1].Id == "relic_chest_mage",
				bag(mageWinner)[1] and bag(mageWinner)[1].Id,
				"relic_chest_mage"
			)
			flag(
				"rewards_hook_mage_money",
				mageCash.Value == mageStart + Cfg.Phase1Money,
				mageCash.Value,
				mageStart + Cfg.Phase1Money
			)

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
			flag("admin_relics_listed", string.find(help, "/relics", 1, true) ~= nil)

			-- /relics: one of every Relic, a universal one on several bosses' lists only once.
			local distinct = {}
			local want = 0
			for _, list in C.Bosses do
				for _, row in list do
					want += distinct[row.Id] and 0 or 1
					distinct[row.Id] = true
				end
			end
			local collector = dressed()
			flag("admin_relics_ok", Admin.Run(collector, "/relics") == true)
			local got = {}
			for _, item in bag(collector) do
				got[item.Id] = (got[item.Id] or 0) + 1
			end
			flag("admin_relics_count", #bag(collector) == want, #bag(collector), want)
			local wrong = {}
			for id in distinct do
				if got[id] ~= 1 then
					table.insert(wrong, id)
				end
			end
			flag("admin_relics_one_each", #wrong == 0, table.concat(wrong, ","), "")
			local full = H.copy(snap(collector))
			flag(
				"admin_relics_rejects_unknown_player",
				Admin.Run(collector, "/relics NoSuchPlayerHere") == false and unchanged(collector, full)
			)

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
