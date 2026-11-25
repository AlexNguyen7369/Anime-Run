--!nonstrict
-- BRIEF: design doc 4.24 "Harness saves". Once a test harness has started, PlayerData writes to an in-memory copy
-- of the save and never to the store it loaded from: saves, release saves, a reset, a later join and a test's own
-- SetStore(nil) all stay in memory. Server/ShadowStore reads its source once per key and never writes it.
-- On demand: ReplicatedStorage attributes ServerTestOnly = "harness_save", then ServerTestRun = true.
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Tests = {}

local UID = 990152000

function Tests.harness_save()
	local r, flag = H.report("harness_save")
	local cleanup = {}
	local ok, err = xpcall(function()
		-- ShadowStore on its own.
		local Shadow = require(Server.ShadowStore)
		local source = H.store({ k = { Money = 5, Team = { "a" } } })
		local shadow = Shadow.new(source)
		local out = shadow:UpdateAsync("k", function(current)
			current.Money = 9
			table.insert(current.Team, "b")
			return current
		end)
		flag("shadow_update_returns_new", out.Money == 9 and #out.Team == 2)
		flag("shadow_source_untouched", source.data.k.Money == 5 and #source.data.k.Team == 1)
		flag("shadow_source_never_written", source.updates == 0 and source.writes == 0)
		flag("shadow_keeps_write", shadow:GetAsync("k").Money == 9)
		flag("shadow_nil_keeps_value", shadow:UpdateAsync("k", function()
			return nil
		end) == nil and shadow:GetAsync("k").Money == 9)
		source.fail = true
		flag("shadow_failed_read_is_new_save", Shadow.new(source):GetAsync("k") == nil)
		source.fail = nil
		flag("shadow_without_source", Shadow.new(nil):GetAsync("k") == nil)

		-- PlayerData: fresh copy, the fake store plays the live DataStore.
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "ServerTestHarnessSaveData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local real = H.store()
		data.SetStore(real)
		local keyA, keyB = data.KeyFor(UID + 1), data.KeyFor(UID + 2)
		real.data[keyA] = { Version = 19, Gems = 11 }
		real.data[keyB] = { Version = 19, Gems = 22 }
		local a = H.player(cleanup, UID + 1)
		flag("loads_from_real", data.Load(a, UID + 1) == true and a:GetAttribute("Gems") == 11)
		flag("not_isolated_before", data.Isolated ~= true)

		flag("isolate_answers_true", data.IsolateForTests() == true and data.Isolated == true)
		local updates, writes = real.updates, real.writes
		local function realUntouched()
			return real.updates == updates and real.writes == writes
		end
		a:SetAttribute("Gems", 77)
		flag("save_after_isolation", data.Save(a, UID + 1) == true)
		flag("save_not_in_real", realUntouched() and real.data[keyA].Gems == 11)

		data.SetStore(nil) -- what a test does when it is done with its own fake store
		a:SetAttribute("Gems", 78)
		flag("save_after_setstore_nil", data.Save(a, UID + 1) == true)
		flag("setstore_nil_stays_isolated", realUntouched() and real.data[keyA].Gems == 11)

		local own = H.store()
		data.SetStore(own) -- a test's own fake store still works
		flag("test_store_still_used", data.Save(a, UID + 1) == true and own.writes == 1)
		data.SetStore(nil)

		-- A join after isolation reads the real save once and locks only the copy.
		local b = H.player(cleanup, UID + 2)
		flag("later_join_loads_copy", data.Load(b, UID + 2) == true and b:GetAttribute("Gems") == 22)
		flag("later_join_not_in_real", realUntouched() and real.data[keyB].Lock == nil)

		flag("isolate_twice", data.IsolateForTests() == true)
		flag("release_save", data.Save(a, UID + 1, true) == true)
		flag("release_not_in_real", realUntouched() and real.data[keyA].Lock ~= nil)

		-- The copy holds what the session saved: a fresh load of the same key reads 78.
		local again = H.player(cleanup, UID + 1)
		flag("copy_keeps_session", data.Load(again, UID + 1) == true and again:GetAttribute("Gems") == 78)

		flag("reset_to_new", data.ResetToNew(b, UID + 2) == true)
		flag("reset_not_in_real", realUntouched() and real.data[keyB].Gems == 22)
	end, debug.traceback)
	flag("completed", ok, ok and 1 or tostring(err))
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
