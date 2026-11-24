--!nonstrict
-- BRIEF: design doc 4.47 "World 2 only: a team of 4" (slot 4 unlocked on first entry; amends 4.2 and 4.8 for World 2:
-- bonuses need any 3 matching members) and "Boss events in World 2" (the World 2 team of 4). World 1 stays a team of 3.
-- Runs in either place and checks that place's rule. Offline: lune run tools/lune/server_scenarios <1|2> World2TeamTests.world2_team
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
	local SIZE = W2 and 4 or 3
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
		if W2 then
			flag("four_accepted_w2", ok == true and p:GetAttribute("Team") == table.concat(four, ","))
		else
			flag("four_refused_w1", ok == false and p:GetAttribute("Team") ~= table.concat(four, ","))
		end
		flag("five_refused", GachaService.SetTeam(p, ids) == false)
		local okPick, picked = GachaService.QuickPick(p, {})
		flag("quick_pick_fills_size", okPick == true and #picked == SIZE, okPick and #picked or -1, SIZE)
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
		if W2 then
			flag("w2_preset_3_of_4", kind(presetPlus) == "Preset:" .. first.Id, kind(presetPlus))
			flag("w2_series_3_of_4", kind(seriesPlus) == "Series:" .. first.Id, kind(seriesPlus))
			flag("w2_preset_beats_series_of_4", kind({ m[1], m[2], other, m[3] }) == "Preset:" .. first.Id)
			flag("w2_two_and_two_none", kind({ m[1], m[2], n[1], n[2] }) == "none")
			flag("w2_duplicates_none", kind({ m[1], m[2], m[3], m[1] }) == "none")
			local p = newPlayer(2)
			flag(
				"w2_stamina_multi_bonus",
				math.abs(GachaService.StaminaMulti(p, presetPlus) - StaminaConfig.TEAM_BONUS.Preset) < 1e-9,
				GachaService.StaminaMulti(p, presetPlus),
				StaminaConfig.TEAM_BONUS.Preset
			)
		else
			flag("w1_four_none", kind(presetPlus) == "none" and kind(seriesPlus) == "none")
		end
		flag("pairs_none", kind({ m[1], m[2] }) == "none")
	end)

	section("slot4_save", function()
		local ids = rollable(4)
		-- an old save: World 1 Team of 3 at the top level, no Worlds, no TeamSlots
		local old = { Cars = ids, Team = { ids[1], ids[2], ids[3] }, Equipped = ids[1] }
		local p = newPlayer(3)
		GachaService.Apply(p, WorldSave.View(old, WORLD))
		local snap = GachaService.Snapshot(p)
		if W2 then
			flag("w2_first_entry_unlocks_slot4", p:GetAttribute("TeamSlots") == 4 and snap.TeamSlots == 4)
			GachaService.SetTeam(p, ids)
			local folded = WorldSave.Fold(GachaService.Snapshot(p), old, 2)
			flag("w2_slot4_saved_under_w2", folded.Worlds.W2.TeamSlots == 4 and #folded.Worlds.W2.Team == 4)
			flag("w2_no_top_level_slot4", folded.TeamSlots == nil and folded.Team == nil)
			-- the stored record, as PlayerData.Save overlays the payload on it; World 1 reads its Team of 3, no slot 4
			local stored = table.clone(old)
			for key, value in folded do
				stored[key] = value
			end
			flag("w1_top_team_still_3", H.same(stored.Team, old.Team) and stored.TeamSlots == nil)
			local p1 = newPlayer(4)
			GachaService.Apply(p1, WorldSave.View(stored, 1))
			flag("w1_team_kept", p1:GetAttribute("Team") == table.concat(old.Team, ","), p1:GetAttribute("Team"))
			-- a saved unlock is kept on a later entry
			local p2 = newPlayer(5)
			GachaService.Apply(p2, WorldSave.View(stored, 2))
			flag(
				"w2_reentry_keeps_4",
				p2:GetAttribute("TeamSlots") == 4 and p2:GetAttribute("Team") == table.concat(ids, ",")
			)
		else
			flag("w1_no_slot4", p:GetAttribute("TeamSlots") == nil and snap.TeamSlots == nil)
			flag("w1_old_team_same", p:GetAttribute("Team") == table.concat(old.Team, ","))
			-- a (malformed) 4-long top-level Team loads as 3 in World 1
			local p1 = newPlayer(6)
			GachaService.Apply(p1, { Cars = ids, Team = ids })
			flag("w1_caps_at_3", #string.split(p1:GetAttribute("Team"), ",") == 3)
			flag("w1_fold_untouched", WorldSave.Fold(snap, old, 1).Worlds == nil)
		end
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
	end)

	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
