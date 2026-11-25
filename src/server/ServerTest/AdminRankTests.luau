--!nonstrict
-- BRIEF: docs/BUGS.md admin-ranklookup-yield. While group rank lookups fail, AdminService.IsAdmin tried RANK_TRIES times with RANK_WAIT between
-- on every call, so every gate touch, chat command and join check yielded about 2 s and sent more requests. A failed lookup now holds for
-- RANK_RETRY_AFTER (checks in that time answer "unknown" at once), and checks running at the same time share one lookup. Who counts as admin
-- does not change: unknown stays no admin (fail closed), a rank once read is kept, the AdminConfig ids win without a lookup.
-- Offline: lune run tools/lune/server_scenarios <1|2> AdminRankTests.admin_rank
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Tests = {}

local UID = 990302000

function Tests.admin_rank()
	local r, flag = H.report("admin_rank")
	local admin, config = require(Server.AdminService), require(Server.AdminConfig)
	local saved = { admin.GroupOf, admin.RankOf, admin.RANK_WAIT, admin.AllowStudio, admin.RANK_RETRY_AFTER }
	local cleanup = {}
	local ok, err = xpcall(function()
		local calls, rank = 0, nil
		admin.GroupOf = function()
			return 1
		end
		admin.RankOf = function()
			calls += 1
			if rank == nil then
				error("ServerTest rank down")
			end
			return rank
		end
		admin.RANK_WAIT = 0.2
		admin.RANK_RETRY_AFTER = 0.6
		admin.AllowStudio = false
		local p = H.player(cleanup, UID + 1)

		local isAdmin, state = admin.IsAdmin(p)
		flag("failed_lookup_unknown", isAdmin == false and state == "unknown", tostring(state))
		flag("failed_lookup_tried", calls == admin.RANK_TRIES, calls, admin.RANK_TRIES)
		local t0 = os.clock()
		isAdmin, state = admin.IsAdmin(p)
		local took = os.clock() - t0
		flag("repeat_check_still_unknown", isAdmin == false and state == "unknown", tostring(state))
		flag("repeat_check_no_wait", took < 0.05, ("%.2f"):format(took), "0.05")
		flag("repeat_check_no_request", calls == admin.RANK_TRIES, calls, admin.RANK_TRIES)

		-- after the hold: tried again, and a rank now read decides
		task.wait(0.65)
		rank = config.GROUP_MIN_RANK
		calls = 0
		flag("after_hold_tried_again", admin.IsAdmin(p) == true and calls == 1, calls, 1)
		flag("known_rank_kept", admin.IsAdmin(p) == true and calls == 1, calls, 1)

		-- checks at the same time share one lookup
		local q = H.player(cleanup, UID + 2)
		rank, calls = nil, 0
		local done, results = 0, {}
		for i = 1, 3 do
			task.spawn(function()
				results[i] = { admin.IsAdmin(q) }
				done += 1
			end)
		end
		local deadline = os.clock() + 3
		while done < 3 and os.clock() < deadline do
			task.wait(0.05)
		end
		local allUnknown = done == 3
		for _, row in results do
			allUnknown = allUnknown and row[1] == false and row[2] == "unknown"
		end
		flag("concurrent_all_unknown", allUnknown, done, 3)
		flag("concurrent_one_lookup", calls == admin.RANK_TRIES, calls, admin.RANK_TRIES)

		-- a rank under the minimum is no admin, and AdminConfig ids need no lookup
		local low = H.player(cleanup, UID + 3)
		rank, calls = config.GROUP_MIN_RANK - 1, 0
		flag("low_rank_no_admin", admin.IsAdmin(low) == false)
		local listed = H.player(cleanup, UID + 4)
		table.insert(config.UserIds, UID + 4)
		rank, calls = nil, 0
		flag("listed_admin_no_lookup", admin.IsAdmin(listed) == true and calls == 0, calls, 0)
		table.remove(config.UserIds, table.find(config.UserIds, UID + 4))
	end, debug.traceback)
	admin.GroupOf, admin.RankOf, admin.RANK_WAIT, admin.AllowStudio, admin.RANK_RETRY_AFTER = table.unpack(saved, 1, 5)
	for _, instance in cleanup do
		instance:Destroy()
	end
	flag("admin_rank_completed", ok, ok and 1 or tostring(err))
	return r
end

return Tests
