--!nonstrict
-- BRIEF: proof that Summon and the boss models work in the World 2 place (deliverables w2-summon, w2-boss).
--   world2_summon: design doc 4.47 "Pity counts stay shared", docs/SIDEKICK_SPEC.md "World 2 set". A real
--     SidekickService.Summon, 1x and 10x, gives only this place's Sidekick set (SidekickConfig.Lists[world]), never the
--     other world's; the pity counts are read from and saved to the shared part of the save, not a world's own part.
--   boss_models_placed: every boss model CharacterModelService.startBoss loads has its copy in this place's
--     ServerStorage.BakedModels (named by asset id) holding every part its bind names. Needs the place file: Studio only.
-- Both run in either place and check that place. Offline (world2_summon only):
--   lune run tools/lune/server_scenarios <1|2> World2ProofTests.world2_summon
-- On demand in Studio: ReplicatedStorage attributes ServerTestOnly = "world2_summon,boss_models_placed", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990262000
local VERSION = 19 -- PlayerData save version (as SidekickPityTests)
local TENS = 60 -- 600 real rolls of the 10x

function Tests.world2_summon()
	local r, flag = H.report("world2_summon")
	local WORLD = require(Shared.WorldConfig).Id
	local OTHER = WORLD == 2 and 1 or 2
	local Cfg = require(Shared.SidekickConfig)
	local WorldConfig, WorldSave = require(Shared.WorldConfig), require(Shared.WorldSave)
	local S = require(Server.SidekickService)
	local oldRoll, oldCooldown = Cfg.Roll, S.REMOTE_COOLDOWN
	local cleanup = {}
	local function section(name, fn)
		local ok, err = xpcall(fn, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end

	local mine, theirs = {}, {}
	for _, row in Cfg.Lists[WORLD] do
		mine[row.Id] = true
	end
	for _, row in Cfg.Lists[OTHER] do
		theirs[row.Id] = true
	end

	local data, store
	local nextId = UID
	local function loaded(saved)
		nextId += 1
		store.data[data.KeyFor(nextId)] = saved
		local p = H.player(cleanup, nextId)
		data.Load(p, nextId)
		p:SetAttribute("RebirthLevel", Cfg.UnlockRebirth)
		for _, row in Cfg.List do
			S.SetAutoSell(p, row.Rarity, true) -- the bag never fills
		end
		return p, nextId
	end
	local function summon(p, count)
		p:SetAttribute("Gems", count == 1 and Cfg.SummonCost or Cfg.TenCost)
		return S.Summon(p, count)
	end

	section("setup", function()
		S.REMOTE_COOLDOWN = 0
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "ServerTestWorld2ProofData", Server
		table.insert(cleanup, module)
		data = require(module)
		store = H.store()
		data.SetStore(store)
	end)

	section("sets", function()
		local shared = {}
		for id in mine do
			if theirs[id] then
				table.insert(shared, id)
			end
		end
		flag("sets_share_no_id", #shared == 0, table.concat(shared, ","), "")
		flag("place_list_is_this_worlds", Cfg.List == Cfg.Lists[WORLD])
		local worldOk = true
		for _, row in Cfg.Lists[2] do
			worldOk = worldOk and row.World == 2
		end
		flag("world2_rows_marked_world_2", worldOk)
	end)

	section("summon", function()
		local p = loaded(nil)
		local ok, results = summon(p, 1)
		flag("one_ok", ok == true and type(results) == "table" and #results == 1, tostring(results))
		local first = ok == true and results[1] and results[1].Id
		flag("one_from_this_world", mine[first] == true and not theirs[first], tostring(first))

		local ran, wrong, kinds = true, {}, {}
		for _ = 1, TENS do
			local tenOk, ten = summon(p, 10)
			ran = ran and tenOk == true and #ten == 10
			for _, result in tenOk == true and ten or {} do
				kinds[result.Id] = true
				if not mine[result.Id] or theirs[result.Id] then
					wrong[result.Id] = true
				end
			end
		end
		local wrongIds, seen = {}, 0
		for id in wrong do
			table.insert(wrongIds, id)
		end
		for _ in kinds do
			seen += 1
		end
		flag("tens_ran", ran)
		flag("tens_only_this_worlds_set", #wrongIds == 0, table.concat(wrongIds, ","), "")
		flag("tens_rolled_more_than_one_sidekick", seen >= 2, seen, 2)
	end)

	-- A save whose counts were earned in the other world: they are the top-level keys, as World 1 has always written.
	section("pity_shared", function()
		for _, key in { "SidekickPity", "SidekickLegendaryPity" } do
			flag("not_per_world_" .. key, table.find(WorldConfig.PROGRESS_KEYS, key) == nil)
		end
		Cfg.Roll = function(rng, rows) -- a Common every time: no count resets
			for _, row in rows do
				if row.Rarity == "Common" then
					return row
				end
			end
			return oldRoll(rng, rows)
		end
		local p, id = loaded({ Version = VERSION, SidekickPity = 7, SidekickLegendaryPity = 5 })
		flag(
			"carried_in",
			p:GetAttribute("SidekickPity") == 7 and p:GetAttribute("SidekickLegendaryPity") == 5,
			tostring(p:GetAttribute("SidekickPity")) .. "," .. tostring(p:GetAttribute("SidekickLegendaryPity")),
			"7,5"
		)
		local ok = summon(p, 1)
		flag(
			"counts_on",
			ok == true and p:GetAttribute("SidekickPity") == 8 and p:GetAttribute("SidekickLegendaryPity") == 6,
			tostring(p:GetAttribute("SidekickPity")) .. "," .. tostring(p:GetAttribute("SidekickLegendaryPity")),
			"8,6"
		)
		flag("save_ok", data.Save(p, id, true) == true)
		local record = store.data[data.KeyFor(id)]
		flag(
			"saved_at_the_top",
			record.SidekickPity == 8 and record.SidekickLegendaryPity == 6,
			tostring(record.SidekickPity) .. "," .. tostring(record.SidekickLegendaryPity),
			"8,6"
		)
		local nested = true
		for _, part in type(record.Worlds) == "table" and record.Worlds or {} do
			nested = nested
				and (type(part) ~= "table" or (part.SidekickPity == nil and part.SidekickLegendaryPity == nil))
		end
		flag("no_world_keeps_its_own_count", nested)
		for world = 1, 2 do
			local view = WorldSave.View(H.copy(record), world)
			flag(
				"world_" .. world .. "_reads_the_same_counts",
				view.SidekickPity == 8 and view.SidekickLegendaryPity == 6,
				tostring(view.SidekickPity) .. "," .. tostring(view.SidekickLegendaryPity),
				"8,6"
			)
		end
	end)

	Cfg.Roll, S.REMOTE_COOLDOWN = oldRoll, oldCooldown
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

function Tests.boss_models_placed()
	local r, flag = H.report("boss_models_placed")
	local Art = require(Shared.SidekickArt)
	local LateData = require(Shared.LateData)
	local baked = ServerStorage:FindFirstChild("BakedModels")
	flag("baked_models_folder", baked ~= nil)
	local ok, err = xpcall(function()
		local mage = LateData.Get("BossMagePoses")
		-- the same four, with the same art rows, as CharacterModelService.startBoss
		local bosses = {
			{ "boss_raga", "boss_raga", LateData.Get("BossRagaPoses").Bind },
			{ "boss_mage", "boss_mage_jointed", mage.Bind },
			{ "boss_golem", "boss_golem", mage.GolemBind },
			{ "boss_king", "boss_king_jointed", LateData.Get("BossKingPoses").Bind },
		}
		for _, boss in bosses do
			local name, artKey, bind = boss[1], boss[2], boss[3]
			local assetId = Art[artKey] and Art[artKey].BossModel
			flag(name .. "_has_a_model_id", assetId ~= nil, tostring(assetId))
			local copy = baked and assetId and baked:FindFirstChild(tostring(assetId))
			flag(name .. "_copy_in_place", copy ~= nil, tostring(assetId))
			local have = {}
			for _, d in copy and copy:GetDescendants() or {} do
				if d:IsA("MeshPart") then
					have[d.Name] = true
				end
			end
			local missing = {}
			for partName, row in bind do
				if not have[row.Mesh or partName] then
					table.insert(missing, partName)
				end
			end
			table.sort(missing)
			flag(name .. "_copy_has_every_bound_part", copy ~= nil and #missing == 0, table.concat(missing, ","), "")
		end
	end, debug.traceback)
	flag("completed", ok, ok and 1 or tostring(err))
	return r
end

return Tests
