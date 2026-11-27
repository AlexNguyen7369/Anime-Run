--!nonstrict
-- BRIEF: design doc 4.47 "Team of 3 in World 2" (owner 2026-11-26: "Remove 4th team slot mechanic"): World 2's Team has
-- 3 slots exactly as World 1's, bonuses need a full team of 3 (4.2, 4.8), and the boss team is 3. A stored World 2 Team
-- of 4 (the team-of-4 build) loses nothing: docs/WORLD2_SPEC.md "Save", Team of 3 migration.
-- Runs in either place and checks the same rule. Offline: lune run tools/lune/server_scenarios <1|2> World2TeamTests.world2_team
-- On demand in Studio: ReplicatedStorage attributes ServerTestOnly = "world2_team", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990248000

function Tests.world2_team()
	local r, flag = H.report("world2_team")
	local WORLD = require(Shared.WorldConfig).Id
	local W2 = WORLD == 2
	local SIZE = 3 -- both worlds (owner 2026-11-26)
	local catalog, series = require(Shared.CharacterCatalog), require(Shared.SeriesCatalog)
	local StaminaConfig, WorldSave = require(Shared.StaminaConfig), require(Shared.WorldSave)
	local GachaService = require(Server.GachaService)
	local cleanup = {}
	local function section(name, fn)
		local ok, err = xpcall(fn, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end
	local function seriesOf(id)
		local spec = catalog.Get(id)
		return spec and spec.Series
	end
	local function newPlayer(n)
		local p = H.player(cleanup, UID + n)
		GachaService.Setup(p)
		return p
	end
	local function rollable(count)
		local ids = {}
		for _, spec in catalog.Rollable() do
			if #ids < count then
				table.insert(ids, spec.Id)
			end
		end
		return ids
	end

	section("size", function()
		flag("team_size_by_world", StaminaConfig.TEAM_SIZE == SIZE, StaminaConfig.TEAM_SIZE, SIZE)
	end)

	section("set_team", function()
		local p = newPlayer(1)
		local ids = rollable(5)
		for _, id in ids do
			GachaService.Grant(p, id)
		end
		local four = { ids[1], ids[2], ids[3], ids[4] }
		local ok = GachaService.SetTeam(p, four)
		flag("four_refused", ok == false and p:GetAttribute("Team") ~= table.concat(four, ","))
		flag("three_accepted", GachaService.SetTeam(p, { ids[3], ids[1], ids[2] }) == true)
		flag("five_refused", GachaService.SetTeam(p, ids) == false)
		local okPick, picked = GachaService.QuickPick(p, {})
		flag("quick_pick_fills_size", okPick == true and #picked == SIZE, okPick and #picked or -1, SIZE)
		-- Quick Setup keeps the draft in front and fills the rest up to the world's size, each id once
		local okDraft, filled = GachaService.QuickPick(p, { ids[2], ids[1] })
		local distinct = okDraft == true
		for i, id in okDraft and filled or {} do
			distinct = distinct and table.find(filled, id) == i and GachaService.Owns(p, id)
		end
		flag(
			"quick_pick_draft_fills_size",
			distinct and #filled == SIZE and filled[1] == ids[2] and filled[2] == ids[1],
			okDraft and #filled or -1,
			SIZE
		)
		flag("quick_pick_over_size_refused", GachaService.QuickPick(p, ids) == false)
		-- the team row's numbers for every slot, none past the world's size
		GachaService.SetTeam(p, table.move(ids, 1, SIZE, 1, {}))
		GachaService.RefreshTeam(p)
		flag("stamina_attr_last_slot", type(p:GetAttribute("TeamStamina" .. SIZE)) == "number")
		flag("cruise_attr_last_slot", type(p:GetAttribute("TeamCruise" .. SIZE)) == "number")
		flag("no_attr_past_size", p:GetAttribute("TeamStamina" .. SIZE + 1) == nil)
	end)

	section("bonus", function()
		local first, second = series.List[1], series.List[2]
		local m, n = first.Preset.Members, second.Preset.Members
		local other
		for _, spec in catalog.All(1) do
			if spec.Series == first.Id and not table.find(m, spec.Id) then
				other = spec.Id
				break
			end
		end
		local function kind(ids)
			local k, s = series.TeamBonus(ids, seriesOf)
			return k and (k .. ":" .. s.Id) or "none"
		end
		local presetPlus = { n[1], m[2], m[1], m[3] } -- the preset trio and one other, in any slots
		local seriesPlus = { m[1], n[1], other, m[2] } -- 3 of one series, not the preset
		flag("trio_preset_both_worlds", kind({ m[3], m[1], m[2] }) == "Preset:" .. first.Id)
		flag("trio_series_both_worlds", kind({ m[1], m[2], other }) == "Series:" .. first.Id)
		-- a list of 4 is no team: no bonus in either world, even with the trio or 3 of one series in it
		flag("four_preset_none", kind(presetPlus) == "none", kind(presetPlus))
		flag("four_series_none", kind(seriesPlus) == "none", kind(seriesPlus))
		local p = newPlayer(2)
		flag(
			"four_stamina_multi_no_bonus",
			math.abs(GachaService.StaminaMulti(p, presetPlus) - 1) < 1e-9,
			GachaService.StaminaMulti(p, presetPlus),
			1
		)
		flag("pairs_none", kind({ m[1], m[2] }) == "none")
	end)

	section("no_slot4", function()
		local ids = rollable(4)
		-- an old save: World 1 Team of 3 at the top level, no Worlds; a first World 2 entry takes it as it is
		local old = { Cars = ids, Team = { ids[1], ids[2], ids[3] }, Equipped = ids[1] }
		local p = newPlayer(3)
		GachaService.Apply(p, WorldSave.View(old, WORLD))
		flag("old_team_same", p:GetAttribute("Team") == table.concat(old.Team, ","), p:GetAttribute("Team"))
		local snap = GachaService.Snapshot(p)
		local extra = {}
		for key in snap do
			if string.find(string.lower(key), "slot", 1, true) then
				table.insert(extra, key)
			end
		end
		flag("no_slot_field_saved", #extra == 0, table.concat(extra, ","), "")
		flag("no_team_slots_attr", p:GetAttribute("TeamSlots") == nil, p:GetAttribute("TeamSlots"))
		-- a (malformed or team-of-4 build) 4-long top-level Team loads as 3
		local p1 = newPlayer(6)
		GachaService.Apply(p1, { Cars = ids, Team = ids })
		flag("caps_at_3", #string.split(p1:GetAttribute("Team"), ",") == 3, p1:GetAttribute("Team"))
		flag("w1_fold_untouched", WorldSave.Fold(snap, old, 1).Worlds == nil)
	end)

	-- docs/WORLD2_SPEC.md "Save", Team of 3 migration: a Worlds.W2 Team of 4 stored by the team-of-4 build
	section("migration", function()
		local ids = rollable(6)
		local a, b, c, d, e = ids[1], ids[2], ids[3], ids[4], ids[5]
		local unowned = ids[6]
		local copies = { [a] = 2, [b] = 3, [c] = 4, [d] = 5, [e] = 6 }
		local record = {
			Cars = { a, b, c, d, e },
			Copies = copies,
			Team = { a, b, c }, -- World 1's
			Equipped = a,
			Worlds = {
				W2 = {
					Team = { d, c, b, a }, -- slot 4 holds a
					Equipped = d,
					Awakening = { [a] = 2 },
					Welcomed = true,
					BestTrack = 3,
				},
			},
		}
		local p = newPlayer(8)
		GachaService.Apply(p, WorldSave.View(record, 2))
		flag("migrated_team_first_3", p:GetAttribute("Team") == table.concat({ d, c, b }, ","), p:GetAttribute("Team"))
		flag("migrated_equipped_slot1", p:GetAttribute("EquippedCharacter") == d, p:GetAttribute("EquippedCharacter"))
		flag("slot4_member_still_owned", GachaService.Owns(p, a) == true)
		flag("slot4_member_copies_kept", GachaService.Copies(p, a) == copies[a], GachaService.Copies(p, a), copies[a])
		if W2 then -- stars are read in World 2 only
			flag("slot4_member_stars_kept", GachaService.Stars(p, a) == 2, GachaService.Stars(p, a), 2)
		end
		local owned = 0
		for _, id in record.Cars do
			owned += GachaService.Owns(p, id) and 1 or 0
		end
		flag("every_character_kept", owned == #record.Cars, owned, #record.Cars)
		-- the next World 2 save writes 3 and Equipped = Team[1]; World 1's top level and the other W2 keys untouched
		local snap = GachaService.Snapshot(p)
		local folded = WorldSave.Fold(snap, record, 2)
		local w2 = folded.Worlds.W2
		flag("saved_w2_team_3", #w2.Team == 3 and H.same(w2.Team, { d, c, b }), table.concat(w2.Team, ","))
		flag("saved_w2_equipped_consistent", w2.Equipped == w2.Team[1], w2.Equipped)
		flag("saved_cars_all_5", #snap.Cars == 5, #snap.Cars, 5)
		flag("saved_top_team_untouched", folded.Team == nil and H.same(record.Team, { a, b, c }))
		flag("saved_w2_welcomed_kept", w2.Welcomed == true)
		-- a stored list with an unowned id in front: the first 3 owned ids, in order
		local q = newPlayer(9)
		local odd = table.clone(record)
		odd.Worlds = { W2 = { Team = { unowned, d, c, b }, Equipped = unowned } }
		GachaService.Apply(q, WorldSave.View(odd, 2))
		flag(
			"unowned_skipped_first_3_owned",
			q:GetAttribute("Team") == table.concat({ d, c, b }, ","),
			q:GetAttribute("Team")
		)
		-- a keep save (being sent back) leaves the stored 4 as stored; the next load trims again
		local kept = WorldSave.Fold(snap, record, 2, true)
		flag("keep_leaves_stored_team", H.same(kept.Worlds.W2.Team, record.Worlds.W2.Team))
		local r2 = newPlayer(10)
		GachaService.Apply(r2, WorldSave.View(kept, 2))
		flag("keep_reload_trims", r2:GetAttribute("Team") == table.concat({ d, c, b }, ","), r2:GetAttribute("Team"))
		-- World 1 still reads its own Team of 3
		local w1 = newPlayer(11)
		GachaService.Apply(w1, WorldSave.View(record, 1))
		flag("w1_team_kept", w1:GetAttribute("Team") == table.concat({ a, b, c }, ","), w1:GetAttribute("Team"))
	end)

	section("boss_team", function()
		local SidekickService = require(Server.SidekickService)
		local BossEventService = require(Server.BossEventService)
		local p = newPlayer(7)
		local ids = rollable(5)
		local bag, gear = {}, {}
		for i, id in ids do
			GachaService.Grant(p, id)
			local row = require(Shared.SidekickConfig).List[i]
			bag[i] = { Id = row.Id, Entry = "e" .. i }
			gear[id] = "e" .. i
		end
		SidekickService.Apply(p, { Sidekicks = bag, CharacterGear = gear })
		local team = BossEventService.AutoTeam(p)
		flag("boss_auto_team_size", #team == SIZE, #team, SIZE)
		-- the shared LastBossTeam of 4 loading as 3: BossEventTests saved_team
	end)

	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
