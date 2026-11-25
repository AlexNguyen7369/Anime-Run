--!nonstrict
-- BRIEF: docs/BUGS.md w2-sendback-stale-team; design doc 4.47, docs/WORLD2_SPEC.md "Save" (first entry keeps the team). A non-admin who joins the
-- World 2 place while it is closed to them is sent back (WorldTravel.Arrived). Their release save must not write World 2's progress: else
-- Worlds.W2 holds the World 1 team of that day, and a later real first entry takes it instead of the team they have then. A player who stays
-- in World 2 writes it as before. Real PlayerData and WorldTravel over an acceptance store; the teleport and the admin check are stubbed.
-- Offline: lune run tools/lune/server_scenarios <1|2> World2SendBackTests.world2_sendback
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990301000
local VERSION = 19 -- PlayerData save version (as World2ProofTests)

function Tests.world2_sendback()
	local r, flag = H.report("world2_sendback")
	local WorldConfig, WorldSave = require(Shared.WorldConfig), require(Shared.WorldSave)
	local travel = require(Server.WorldTravel)
	local cleanup, sent = {}, {}
	local saved = {
		WorldConfig.Id,
		WorldConfig.GATE_OPEN,
		travel.Save,
		travel.Teleport,
		travel.AllowStudio,
		travel.IsAdmin,
		travel.Depart,
		travel.Retake,
		travel.Kick,
	}
	local ok, err = xpcall(function()
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "ServerTestSendBackData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local store = H.store()
		data.SetStore(store)
		WorldConfig.Id, WorldConfig.GATE_OPEN = 2, false
		travel.AllowStudio = true -- as on a live server
		travel.Depart = function() end
		travel.Retake = function()
			return true
		end
		travel.Kick = function() end
		travel.Save = function(p)
			return data.Save(p, p:GetAttribute("UserId"), true, true) -- WorldTravel's own release save (a test player has no UserId)
		end
		travel.Teleport = function(_, p)
			table.insert(sent, p)
		end
		local admins = {}
		travel.IsAdmin = function(p)
			return admins[p] == true
		end
		local record = {
			Version = VERSION,
			Cars = { "leaf_hero", "sea_captain" },
			Team = { "leaf_hero" },
			Equipped = "leaf_hero",
			BestTrack = 10,
		}
		local function arrive(n, admin)
			local id = UID + n
			store.data[data.KeyFor(id)] = H.copy(record)
			local p = H.player(cleanup, id)
			admins[p] = admin
			data.Load(p, id)
			flag("loaded_" .. n, p:GetAttribute("DataLoaded") == true and p:GetAttribute("Team") == "leaf_hero")
			return p, id
		end

		-- sent back: the release save leaves Worlds.W2's progress as it was (none)
		local guest, guestId = arrive(1, false)
		travel.Arrived(guest)
		local deadline = os.clock() + 3
		while #sent == 0 and os.clock() < deadline do
			task.wait(0.05)
		end
		flag("guest_sent_back", #sent == 1 and sent[1] == guest, #sent, 1)
		local after = store.data[data.KeyFor(guestId)] or {}
		local w2 = type(after.Worlds) == "table" and after.Worlds.W2 or {}
		flag(
			"guest_writes_no_world2_team",
			w2.Team == nil and w2.Equipped == nil,
			w2.Team and table.concat(w2.Team, ",") or "none",
			"none"
		)
		flag("guest_world1_kept", after.Team ~= nil and after.Team[1] == "leaf_hero" and after.BestTrack == 10)
		flag("guest_lock_released", after.Lock == nil)
		-- the stale team the bug leaves: World 1's team changes, then a real first entry
		local later = H.copy(after)
		later.Team, later.Equipped = { "sea_captain" }, "sea_captain"
		flag("later_first_entry_takes_todays_team", WorldSave.View(later, 2).Team[1] == "sea_captain")

		-- an admin stays and plays: their saves write World 2's progress as before (first entry: the team moves into Worlds.W2)
		local owner, ownerId = arrive(2, true)
		flag("admin_stays", travel.Arrived(owner) == false and #sent == 1, #sent, 1)
		data.Save(owner, ownerId, true)
		local mine = store.data[data.KeyFor(ownerId)]
		local team = mine and mine.Worlds and mine.Worlds.W2 and mine.Worlds.W2.Team
		flag("staying_player_writes_world2", team ~= nil and team[1] == "leaf_hero")
		travel.Failed(guest, "ServerTest cleanup")
	end, debug.traceback)
	WorldConfig.Id, WorldConfig.GATE_OPEN = saved[1], saved[2]
	travel.Save, travel.Teleport, travel.AllowStudio, travel.IsAdmin = saved[3], saved[4], saved[5], saved[6]
	travel.Depart, travel.Retake, travel.Kick = saved[7], saved[8], saved[9]
	for _, instance in cleanup do
		instance:Destroy()
	end
	flag("world2_sendback_completed", ok, ok and 1 or tostring(err))
	return r
end

return Tests
