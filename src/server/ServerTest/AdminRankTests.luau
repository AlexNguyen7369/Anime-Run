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
	local saved = {
		admin.GroupOf,
		admin.RankOf,
		admin.RANK_WAIT,
		admin.AllowStudio,
		admin.RANK_RETRY_AFTER,
		admin.RANK_LOOK_TIMEOUT,
	}
	-- the real values: a hold shorter than the arrival's recheck, so each recheck asks again
	local travel = require(Server.WorldTravel)
	flag(
		"hold_under_arrival_recheck",
		type(admin.RANK_RETRY_AFTER) == "number" and admin.RANK_RETRY_AFTER < travel.ADMIN_RECHECK,
		tostring(admin.RANK_RETRY_AFTER),
		tostring(travel.ADMIN_RECHECK)
	)
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

		-- a lookup whose thread is killed mid-lookup: the next checks wait at most RANK_LOOK_TIMEOUT, answer "unknown"
		-- (no admin), and a check after that looks again
		admin.RANK_LOOK_TIMEOUT = 0.3
		local stuck = H.player(cleanup, UID + 5)
		admin.RankOf = function()
			calls += 1
			task.wait(100)
		end
		calls = 0
		local thread = task.spawn(admin.IsAdmin, stuck)
		task.wait(0.05)
		task.cancel(thread)
		local waited = { done = false }
		task.spawn(function()
			waited.result = { admin.IsAdmin(stuck) }
			waited.done = true
		end)
		local until_ = os.clock() + 2
		while not waited.done and os.clock() < until_ do
			task.wait(0.05)
		end
		flag("killed_lookup_waiter_returns", waited.done == true)
		flag(
			"killed_lookup_fails_closed",
			waited.done and waited.result[1] == false and waited.result[2] == "unknown",
			waited.done and tostring(waited.result[2]) or "still waiting",
			"unknown"
		)
		rank = 0
		admin.RankOf = function()
			calls += 1
			return rank
		end
		calls = 0
		flag("after_timeout_looks_again", admin.IsAdmin(stuck) == false and calls == 1, calls, 1)
	end, debug.traceback)
	admin.GroupOf, admin.RankOf, admin.RANK_WAIT, admin.AllowStudio = saved[1], saved[2], saved[3], saved[4]
	admin.RANK_RETRY_AFTER, admin.RANK_LOOK_TIMEOUT = saved[5], saved[6]
	for _, instance in cleanup do
		instance:Destroy()
	end
	flag("admin_rank_completed", ok, ok and 1 or tostring(err))
	return r
end

return Tests
