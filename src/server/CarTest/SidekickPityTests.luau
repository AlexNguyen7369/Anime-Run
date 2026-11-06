--!nonstrict
-- BRIEF: design doc 4.36 "Summon pity" (owner 2026-11-05), section 6, docs/SIDEKICK_SPEC.md "Pity". SidekickTests and
-- SidekickRotationTests hold the rest of the Sidekick rules.
-- Owner ruling, relayed 2026-11-05: a Mythic resets only the Mythic count; the Legendary count neither resets nor pauses on it.
-- A Secret has no pity, resets nothing and advances both counts.
-- Contract these tests assume beyond the brief (implementer: report a change, do not loosen):
--   Natural rolls go through SidekickConfig.Roll, read from the table at call time. The tests replace it to rig the rarity.
--     A guarantee may skip that roll, or call it with a filtered list: the rig then rolls that list normally.
--   Snapshot, the saved record and the attributes all carry the same SidekickPity and SidekickLegendaryPity.
--   SidekickPity = PityCount - 1 at rest means the next summon is the guaranteed Mythic, and the same for the Legendary count,
--     so Details can show the updated odds (section 6) from the attributes and SidekickConfig alone.
--   When both land on one summon, the Legendary count stays at LegendaryPityCount - 1 or above, so the next summon pays it.
--     Its exact value is not pinned. Any saved value at or above a threshold pays on the next summon.
--   A result has Pity = true only when guaranteed; other results leave it out or false.
-- On demand: ReplicatedStorage attributes CarTestOnly = "sidekick_pity", then CarTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990138000
local VERSION = 18 -- 18: BossCredit; 17: SidekickPity, SidekickLegendaryPity
local SLOT0 = 1000000 -- far from today, so the live slot cannot pass by accident
local MYTHIC_AT, LEGENDARY_AT = 300, 100 -- design doc 4.36

function Tests.sidekick_pity()
	local r, flag = H.report("sidekick_pity")
	local Cfg = require(Shared.SidekickConfig)
	local Admin = require(Server.AdminService)
	local S = require(Server.SidekickService)
	local Rotation = require(Server.SidekickRotation)
	local oldRoll, oldStudio = Cfg.Roll, Admin.AllowStudio
	local cleanup = {}
	local function section(name, fn)
		local ok, err = xpcall(fn, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end

	flag("config_mythic_count", Cfg.PityCount == MYTHIC_AT, Cfg.PityCount, MYTHIC_AT)
	flag("config_legendary_count", Cfg.LegendaryPityCount == LEGENDARY_AT, Cfg.LegendaryPityCount, LEGENDARY_AT)

	-- Every natural roll gives this rarity of the slot, when the list holds it.
	local want = "Common"
	Cfg.Roll = function(rng, rows)
		for _, row in rows do
			if row.Rarity == want then
				return row
			end
		end
		return oldRoll(rng, rows)
	end
	Admin.AllowStudio = true

	-- One slot for most sections, and two with different Mythics for the carry across a slot change.
	local slotA, slotB
	for slot = SLOT0, SLOT0 + 200 do
		if Rotation.For(slot).Mythic[1] ~= Rotation.For(slot + 1).Mythic[1] then
			slotA, slotB = slot, slot + 1
			break
		end
	end
	flag("test_found_mythic_change", slotA ~= nil)
	local function at(slot)
		S.SetClock(function()
			return slot * Rotation.SLOT_SECONDS + 60
		end)
	end
	at(slotA)
	local mythicOf = Rotation.For(slotA).Mythic[1]

	local module = Server.PlayerData:Clone()
	module.Name, module.Parent = "CarTestPityData", Server
	table.insert(cleanup, module)
	local data = require(module)
	local store = H.store()
	data.SetStore(store)

	local nextId = UID
	local function loaded(saved)
		nextId += 1
		store.data[data.KeyFor(nextId)] = saved
		local p = H.player(cleanup, nextId)
		local loadedOk = data.Load(p, nextId)
		p:SetAttribute("RebirthLevel", Cfg.UnlockRebirth)
		return p, nextId, loadedOk
	end
	local function withCounts(mythic, legendary)
		return loaded({ Version = VERSION, SidekickPity = mythic, SidekickLegendaryPity = legendary })
	end
	local function autoSellAll(p)
		for _, row in Cfg.List do
			S.SetAutoSell(p, row.Rarity, true)
		end
		return p
	end
	local function summon(p, count)
		p:SetAttribute("Gems", count == 1 and Cfg.SummonCost or Cfg.TenCost)
		return S.Summon(p, count)
	end
	local function one(p)
		local ok, results = summon(p, 1)
		return ok == true and results[1] or {}
	end
	local function rarity(result)
		local row = Cfg.Get(result.Id)
		return row and row.Rarity
	end
	local function isMythic(result)
		return result.Id == mythicOf and result.Pity == true
	end
	local function isLegendary(result)
		return rarity(result) == "Legendary"
			and table.find(Rotation.For(slotA).Legendary, result.Id) ~= nil
			and result.Pity == true
	end
	local function plain(result, kind)
		return rarity(result) == kind and result.Pity ~= true
	end
	-- Attributes and Snapshot both hold the counts.
	local function expect(label, p, mythic, legendary)
		local snap = S.Snapshot(p)
		local got = p:GetAttribute("SidekickPity")
		local gotLegendary = p:GetAttribute("SidekickLegendaryPity")
		flag(label .. "_mythic", got == mythic, got, mythic)
		flag(label .. "_legendary", gotLegendary == legendary, gotLegendary, legendary)
		flag(label .. "_snapshot", snap.SidekickPity == mythic and snap.SidekickLegendaryPity == legendary)
	end
	local function frozen(p)
		return {
			H.copy(S.Snapshot(p)),
			p:GetAttribute("Gems"),
			p:GetAttribute("SidekickPity"),
			p:GetAttribute("SidekickLegendaryPity"),
		}
	end
	local function fillBag(p, leave)
		for _ = 1, Cfg.BagSize - leave do
			S.Grant(p, Cfg.List[1].Id)
		end
	end

	section("full_run", function()
		-- Real summons, all Common, across a slot change. The Legendary count lands at 100 and 200, then with the Mythic at 300.
		local p = autoSellAll(loaded(nil))
		expect("new_player", p, 0, 0)
		want = "Common"
		local commons, legendaries, attributes = true, 0, true
		for i = 1, MYTHIC_AT - 1 do
			if i == 151 then
				at(slotB)
			end
			local result = one(p)
			if i % LEGENDARY_AT == 0 then
				legendaries += rarity(result) == "Legendary" and result.Pity == true and 1 or 0
				attributes = attributes and p:GetAttribute("SidekickLegendaryPity") == 0
			else
				commons = commons and plain(result, "Common")
			end
			attributes = attributes and p:GetAttribute("SidekickPity") == i
		end
		flag("run_commons_plain", commons)
		flag("run_legendary_each_100", legendaries == 2, legendaries, 2)
		flag("run_counts_every_summon", attributes)
		expect("run_at_threshold", p, MYTHIC_AT - 1, LEGENDARY_AT - 1)
		local last = one(p)
		local mythicB = Rotation.For(slotB).Mythic[1]
		flag("run_300th_new_slots_mythic", last.Id == mythicB and last.Pity == true, last.Id, mythicB)
		flag("run_300th_not_old_slots_mythic", last.Id ~= Rotation.For(slotA).Mythic[1])
		flag("run_mythic_count_reset", p:GetAttribute("SidekickPity") == 0, p:GetAttribute("SidekickPity"), 0)
		local after = one(p)
		flag("run_legendary_pays_next", rarity(after) == "Legendary" and after.Pity == true, after.Id)
		expect("run_after_both", p, 1, 0)
		at(slotA)
	end)

	section("guarantees", function()
		want = "Common"
		local p = autoSellAll(withCounts(MYTHIC_AT - 1, 10))
		expect("loaded_attributes", p, MYTHIC_AT - 1, 10)
		flag("mythic_guaranteed", isMythic(one(p)))
		expect("mythic_resets_only_its_count", p, 0, 11)

		p = autoSellAll(withCounts(10, LEGENDARY_AT - 1))
		flag("legendary_guaranteed", isLegendary(one(p)))
		expect("legendary_resets_only_its_count", p, 11, 0)

		-- A random Legendary: all of the slot's appear, each from a fresh guarantee.
		local seen = {}
		for _ = 1, 40 do
			local again = autoSellAll(withCounts(0, LEGENDARY_AT - 1))
			seen[one(again).Id] = true
		end
		for _, id in Rotation.For(slotA).Legendary do
			flag("legendary_random_" .. id, seen[id] == true)
		end

		-- Over a threshold, as a save could hold, still pays.
		p = autoSellAll(withCounts(5000, 3))
		flag("over_mythic_threshold_pays", isMythic(one(p)))
		p = autoSellAll(withCounts(3, 5000))
		flag("over_legendary_threshold_pays", isLegendary(one(p)))
	end)

	section("natural", function()
		for _, case in
			{
				{ "Mythic", 0, 11 },
				{ "Legendary", 11, 0 },
				{ "Secret", 11, 11 },
				{ "Rare", 11, 11 },
				{ "Common", 11, 11 },
			}
		do
			want = case[1]
			local p = autoSellAll(withCounts(10, 10))
			local result = one(p)
			flag("natural_plain_" .. case[1], plain(result, case[1]), result.Id)
			expect("natural_" .. case[1], p, case[2], case[3])
		end
		-- A natural Mythic advances the Legendary count, up to its guarantee.
		want = "Mythic"
		local m = autoSellAll(withCounts(10, LEGENDARY_AT - 2))
		one(m)
		expect("natural_mythic_advances_legendary", m, 0, LEGENDARY_AT - 1)
		want = "Common"
		flag("natural_mythic_then_legendary_pays", isLegendary(one(m)))
		expect("natural_mythic_then_paid", m, 1, 0)
	end)

	section("both_on_one", function()
		want = "Common"
		local p, id = withCounts(MYTHIC_AT - 1, LEGENDARY_AT - 1)
		autoSellAll(p)
		flag("both_mythic_wins", isMythic(one(p)))
		flag("both_mythic_count_reset", p:GetAttribute("SidekickPity") == 0)
		local pending = p:GetAttribute("SidekickLegendaryPity")
		flag(
			"both_legendary_pending",
			type(pending) == "number" and pending >= LEGENDARY_AT - 1,
			pending,
			LEGENDARY_AT - 1
		)

		-- The waiting Legendary survives a rejoin.
		flag("both_save_ok", data.Save(p, id, true) == true)
		local back = autoSellAll(loaded(H.copy(store.data[data.KeyFor(id)])))
		flag("both_legendary_pays_after_rejoin", isLegendary(one(back)))
		expect("both_after_pay", back, 1, 0)
	end)

	section("free_summon", function()
		want = "Common"
		local p = autoSellAll(withCounts(4, 4))
		flag("free_ok", (S.GrantFreeSummon(p)) == true)
		expect("free_counts", p, 5, 5)
		local top = autoSellAll(withCounts(MYTHIC_AT - 1, 4))
		local ok, results = S.GrantFreeSummon(top)
		flag("free_can_be_guaranteed", ok == true and isMythic(results[1]))
		expect("free_guarantee_resets", top, 0, 5)
	end)

	section("ten", function()
		want = "Common"
		local p = autoSellAll(withCounts(10, LEGENDARY_AT - 4))
		local ok, results = summon(p, 10)
		flag("ten_ok", ok == true and #results == 10)
		for i, result in results do
			flag(
				"ten_legendary_slot_" .. i,
				i == 4 and isLegendary(result) or i ~= 4 and plain(result, "Common"),
				result.Id
			)
		end
		expect("ten_counts", p, 20, 6)

		-- Both land on the 5th: the Mythic, then the Legendary on the 6th, then the counts run on.
		p = autoSellAll(withCounts(MYTHIC_AT - 5, LEGENDARY_AT - 5))
		ok, results = summon(p, 10)
		flag("ten_both_ok", ok == true and #results == 10)
		for i, result in results do
			local fine
			if i == 5 then
				fine = isMythic(result)
			elseif i == 6 then
				fine = isLegendary(result)
			else
				fine = plain(result, "Common")
			end
			flag("ten_both_slot_" .. i, fine, result.Id)
		end
		expect("ten_both_counts", p, 5, 4)

		want = "Legendary"
		p = autoSellAll(withCounts(10, 10))
		summon(p, 10)
		expect("ten_natural_legendaries", p, 20, 0)
		want = "Common"
	end)

	section("refused", function()
		want = "Common"
		local function refused(label, p, ...)
			local before = frozen(p)
			flag(label .. "_refused", (S.Summon(p, ...)) == false)
			flag(label .. "_nothing_moved", H.same(frozen(p), before))
		end
		local full = withCounts(7, 7)
		fillBag(full, 0)
		full:SetAttribute("Gems", Cfg.TenCost)
		refused("full_bag_1", full, 1)
		refused("full_bag_10", full, 10)
		local before = frozen(full)
		flag("full_bag_free_refused", (S.GrantFreeSummon(full)) == false)
		flag("full_bag_free_nothing_moved", H.same(frozen(full), before))

		local nearly = withCounts(7, 7)
		fillBag(nearly, 9)
		nearly:SetAttribute("Gems", Cfg.TenCost)
		refused("nine_free_10", nearly, 10)

		local poor = withCounts(MYTHIC_AT - 1, LEGENDARY_AT - 1)
		poor:SetAttribute("Gems", Cfg.SummonCost - 1)
		refused("few_gems_1", poor, 1)
		poor:SetAttribute("Gems", Cfg.TenCost - 1)
		refused("few_gems_10", poor, 10)

		local locked = withCounts(7, 7)
		locked:SetAttribute("Gems", Cfg.TenCost)
		locked:SetAttribute("RebirthLevel", Cfg.UnlockRebirth - 1)
		refused("locked", locked, 1)
		locked:SetAttribute("RebirthLevel", Cfg.UnlockRebirth)
		refused("bad_count", locked, 3)

		-- The guarantee is what must fit: Commons would sell, but the Mythic stays, so a full bag refuses it.
		local waiting = withCounts(MYTHIC_AT - 1, 7)
		fillBag(waiting, 0)
		S.SetAutoSell(waiting, "Common", true)
		waiting:SetAttribute("Gems", Cfg.SummonCost)
		refused("full_bag_kept_guarantee", waiting, 1)
		flag("guarantee_waits_room", S.Sell(waiting, S.Snapshot(waiting).Sidekicks[1].Entry) == true)
		flag("guarantee_paid_after_room", isMythic(one(waiting)))
		expect("guarantee_paid_counts", waiting, 0, 8)
	end)

	section("auto_sold", function()
		want = "Common"
		local p = autoSellAll(withCounts(MYTHIC_AT - 1, 4))
		local result = one(p)
		flag("sold_guarantee_is_mythic", isMythic(result))
		flag("sold_marked", result.Sold == true and result.Entry == nil)
		flag("sold_nothing_kept", #S.Snapshot(p).Sidekicks == 0)
		local value = Cfg.Get(mythicOf).SellGems
		flag("sold_pays", p:GetAttribute("Gems") == value, p:GetAttribute("Gems"), value)
		expect("sold_guarantee_resets", p, 0, 5)
		local plainSold = autoSellAll(withCounts(4, 4))
		one(plainSold)
		expect("sold_common_counts", plainSold, 5, 5)

		local keeper = withCounts(MYTHIC_AT - 1, 4)
		local kept = one(keeper)
		flag("kept_guarantee_is_mythic", isMythic(kept) and kept.Sold ~= true)
		local bag = S.Snapshot(keeper).Sidekicks
		flag("kept_in_bag", #bag == 1 and bag[1].Id == mythicOf and bag[1].Entry == kept.Entry)
		flag("kept_costs_listed", keeper:GetAttribute("Gems") == 0, keeper:GetAttribute("Gems"), 0)
	end)

	section("saves", function()
		want = "Common"
		-- Round trip at each threshold: the record matches the attributes, and the rejoin pays.
		local p, id = withCounts(MYTHIC_AT - 2, LEGENDARY_AT - 2)
		autoSellAll(p)
		one(p)
		expect("save_at_threshold", p, MYTHIC_AT - 1, LEGENDARY_AT - 1)
		flag("save_ok", data.Save(p, id, true) == true)
		local record = store.data[data.KeyFor(id)]
		flag("save_version", record.Version == VERSION, record.Version, VERSION)
		flag(
			"save_mythic_matches_attribute",
			record.SidekickPity == p:GetAttribute("SidekickPity"),
			record.SidekickPity
		)
		flag(
			"save_legendary_matches_attribute",
			record.SidekickLegendaryPity == p:GetAttribute("SidekickLegendaryPity"),
			record.SidekickLegendaryPity
		)
		local back = loaded(H.copy(record))
		expect("rejoin_keeps", back, MYTHIC_AT - 1, LEGENDARY_AT - 1)
		flag("rejoin_mythic_pays", isMythic(one(autoSellAll(back))))

		local legendaryAt, legendaryId = withCounts(9, LEGENDARY_AT - 1)
		data.Save(legendaryAt, legendaryId, true)
		local legendaryBack = autoSellAll(loaded(H.copy(store.data[data.KeyFor(legendaryId)])))
		flag("rejoin_legendary_pays", isLegendary(one(legendaryBack)))

		for _, version in { 14, 16 } do
			local old, oldId, oldOk = loaded({ Version = version, Money = 5 })
			flag("old_v" .. version .. "_loads", oldOk == true)
			expect("old_v" .. version, old, 0, 0)
			data.Save(old, oldId, true)
			local upgraded = store.data[data.KeyFor(oldId)]
			flag(
				"old_v" .. version .. "_upgrades",
				upgraded.Version == VERSION and upgraded.SidekickPity == 0 and upgraded.SidekickLegendaryPity == 0
			)
		end

		for _, case in
			{
				{ "negative", -1 },
				{ "text", "7" },
				{ "bool", true },
				{ "table", {} },
				{ "nan", 0 / 0 },
			}
		do
			expect("junk_" .. case[1], withCounts(case[2], case[2]), 0, 0)
		end
		expect("whole_kept", withCounts(7, 8), 7, 8)
		local function whole(value)
			return type(value) == "number" and value >= 0 and value < math.huge and value == math.floor(value)
		end
		for label, junk in { fraction = 7.5, huge = math.huge } do
			local cleaned = withCounts(junk, junk)
			local snap = S.Snapshot(cleaned)
			flag("clean_" .. label .. "_whole", whole(snap.SidekickPity) and whole(snap.SidekickLegendaryPity))
			flag("clean_" .. label .. "_attribute", cleaned:GetAttribute("SidekickPity") == snap.SidekickPity)
		end
	end)

	section("wipe", function()
		want = "Common"
		local p, id = withCounts(MYTHIC_AT - 1, LEGENDARY_AT - 1)
		flag("wipe_ok", Admin.Run(p, "/wipe") == true)
		expect("wipe_resets", p, 0, 0)
		data.Save(p, id, true)
		local record = store.data[data.KeyFor(id)]
		flag("wipe_saves", record.SidekickPity == 0 and record.SidekickLegendaryPity == 0)
	end)

	Cfg.Roll, Admin.AllowStudio = oldRoll, oldStudio
	S.SetClock()
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
