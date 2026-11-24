--!nonstrict
-- BRIEF: docs/WORLD2_SPEC.md "Welcome" (design doc 4.47). The welcome flag lives in Worlds.W2.Welcomed, VERSION
-- unchanged: an old save without it loads and is welcomed once; the flag never clears; keys of Worlds.W2 this
-- version does not know are kept; a World 1 server (old or new: its save path is the same) keeps Worlds.W2 whole.
-- Server/WorldWelcome welcomes a loaded player in World 2 once, never one the locked gate sends back.
-- On demand: ReplicatedStorage attributes ServerTestOnly = "world2_welcome", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990147000

function Tests.world2_welcome()
	local r, flag = H.report("world2_welcome")
	local WorldSave = require(Shared.WorldSave)
	local WorldConfig = require(Shared.WorldConfig)
	local W = require(Server.WorldWelcome)
	local saved = { WorldId = W.WorldId, InStudio = W.InStudio, CanEnter = W.CanEnter }
	local cleanup = {}
	local ok, err = xpcall(function()
		-- Pure save shape (World 2's id passed in, so it runs in either place).
		local old = { Version = 19, Money = 5, Worlds = { W2 = { BestTrack = 2, Team = { "punch_rider" } } } }
		flag("old_save_view_unwelcomed", WorldSave.View(old, 2).Welcomed == nil)
		flag("no_worlds_view_unwelcomed", WorldSave.View({ Version = 19 }, 2).Welcomed == nil)
		local payload = { Money = 6, BestTrack = 3, Team = { "punch_rider" }, Welcomed = true }
		local out = WorldSave.Fold(payload, old, 2)
		flag("fold_writes_flag_in_w2", out.Worlds.W2.Welcomed == true)
		flag("fold_no_top_level_flag", out.Welcomed == nil)
		flag("fold_progress_still_moved", out.Worlds.W2.BestTrack == 3 and out.BestTrack == nil)
		local again = WorldSave.Fold({ Money = 7, BestTrack = 4 }, out, 2)
		flag("flag_never_clears", again.Worlds.W2.Welcomed == true)
		flag("view_reads_flag", WorldSave.View(again, 2).Welcomed == true)
		local future = { Worlds = { W2 = { BestTrack = 1, FutureKey = "x" }, W3 = { BestTrack = 9 } } }
		local kept = WorldSave.Fold({ BestTrack = 2 }, future, 2)
		flag("unknown_w2_key_kept", kept.Worlds.W2.FutureKey == "x")
		flag("other_world_kept", kept.Worlds.W3 and kept.Worlds.W3.BestTrack == 9)
		flag("world1_fold_untouched", WorldSave.Fold(payload, old, 1) == payload)

		-- WorldWelcome.Check: once, only in World 2, never a locked-gate arrival that is sent back.
		flag("uses_gate_rule", W.CanEnter ~= nil and W.GateOpen == nil and W.IsAdmin == nil)
		local enter = false -- what Server/WorldTravel.CanEnter answers (world_gate_rule tests the rule itself)
		W.WorldId, W.InStudio, W.CanEnter = 2, function()
			return false
		end, function()
			return enter
		end
		local p = H.player(cleanup, UID + 1)
		p:SetAttribute("DataLoaded", true)
		flag("refused_not_welcomed", W.Check(p) == false and p:GetAttribute("World2Welcomed") == nil)
		enter = true
		flag("allowed_welcomed", W.Check(p) == true and p:GetAttribute("World2WelcomeShow") == true)
		flag("welcomed_once", W.Check(p) == false)
		local q = H.player(cleanup, UID + 2)
		flag("not_before_load", W.Check(q) == false)
		q:SetAttribute("DataLoaded", true)
		q:SetAttribute("Travelling", true)
		flag("not_while_travelling", W.Check(q) == false)
		q:SetAttribute("Travelling", nil)
		flag("open_gate_welcomed", W.Check(q) == true)
		W.WorldId = 1
		local w1 = H.player(cleanup, UID + 3)
		w1:SetAttribute("DataLoaded", true)
		flag("never_in_world1", W.Check(w1) == false and w1:GetAttribute("World2WelcomeShow") == nil)

		-- PlayerData round trip in this place (fresh copy, fake store).
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "ServerTestWorld2WelcomeData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local store = H.store()
		data.SetStore(store)
		local key = data.KeyFor(UID + 4)
		store.data[key] = H.copy(old)
		local a = H.player(cleanup, UID + 4)
		local loadedOk = data.Load(a, UID + 4)
		flag("old_save_loads", loadedOk == true and a:GetAttribute("World2Welcomed") == nil)
		if WorldConfig.Id == 2 then
			W.WorldId = 2
			flag("old_save_welcomed_once", W.Check(a) == true and W.Check(a) == false)
			flag("saves", data.Save(a, UID + 4) == true)
			local stored = store.data[key]
			flag("stored_in_w2", stored.Worlds.W2.Welcomed == true and stored.Welcomed == nil)
			local b = H.player(cleanup, UID + 5)
			store.data[data.KeyFor(UID + 5)] = H.copy(stored)
			data.Load(b, UID + 5)
			flag("reload_stays_welcomed", b:GetAttribute("World2Welcomed") == true and W.Check(b) == false)
		else
			-- World 1 (this build, and any older one: the World 1 save path is unchanged) keeps Worlds.W2 whole.
			local withFlag = H.copy(old)
			withFlag.Worlds.W2.Welcomed = true
			local k2 = data.KeyFor(UID + 5)
			store.data[k2] = withFlag
			local b = H.player(cleanup, UID + 5)
			flag("world1_loads_flagged_save", data.Load(b, UID + 5) == true)
			flag("world1_attr_unset", b:GetAttribute("World2Welcomed") == nil)
			flag("world1_saves", data.Save(b, UID + 5) == true)
			local stored = store.data[k2]
			flag("world1_keeps_w2_flag", stored.Worlds.W2.Welcomed == true)
			flag("world1_keeps_w2_progress", H.same(stored.Worlds.W2.Team, { "punch_rider" }))
			flag("world1_no_top_level_flag", stored.Welcomed == nil)
		end
	end, debug.traceback)
	flag("completed", ok, ok and 1 or tostring(err))
	for name, value in saved do
		W[name] = value
	end
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
