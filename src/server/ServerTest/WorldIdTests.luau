--!nonstrict
-- BRIEF: docs/BUGS.md w2-worldid-race; design doc 4.47, docs/WORLD2_SPEC.md (WorldConfig.Id: the World 2 place has ReplicatedStorage.WorldId).
-- A client may require Shared/WorldConfig before the place's first replication is in (ReplicatedFirst's LoadingScreen does). Then WorldId is
-- not there yet, and every module that reads WorldConfig.Id at require time acts as World 1 for the session. A fresh copy of WorldConfig is
-- required as a client whose place is not loaded: WorldId comes only with game.Loaded. Offline only (lune: RunService and game are stubbed;
-- a live server never races): lune run tools/lune/server_scenarios <1|2> WorldIdTests.world_id_race
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local H = require(script.Parent.AcceptanceSupport)
local place = game -- stubbed below (offline only)
local Tests = {}

function Tests.world_id_race()
	local r, flag = H.report("world_id_race")
	local world = require(ReplicatedStorage.Shared.WorldConfig).Id
	local value = ReplicatedStorage:FindFirstChild("WorldId")
	local old = { RunService.IsClient, game.IsLoaded, game.Loaded, RunService.IsServer }
	local copy
	local ok, err = xpcall(function()
		local loaded = false
		if value then
			value.Parent = nil -- not replicated yet
		end
		RunService.IsClient = function()
			return true
		end
		RunService.IsServer = function()
			return false
		end
		place.IsLoaded = function()
			return loaded
		end
		place.Loaded = {
			Wait = function()
				loaded = true
				if value then
					value.Parent = ReplicatedStorage
				end
			end,
		}
		copy = ReplicatedStorage.Shared.WorldConfig:Clone()
		copy.Name, copy.Parent = "ServerTestWorldIdRace", ReplicatedStorage.Shared
		local early = require(copy)
		flag("client_early_require_knows_world", early.Id == world, early.Id, world)
		flag("client_waited_for_loaded", loaded == true)
		-- client and server at once (Studio Run mode, the command bar): no wait, even before Loaded
		copy:Destroy()
		RunService.IsServer = function()
			return true
		end
		loaded = false
		copy = ReplicatedStorage.Shared.WorldConfig:Clone()
		copy.Name, copy.Parent = "ServerTestWorldIdRunMode", ReplicatedStorage.Shared
		require(copy)
		flag("run_mode_never_waits", loaded == false)
	end, debug.traceback)
	RunService.IsClient, place.IsLoaded, place.Loaded, RunService.IsServer = old[1], old[2], old[3], old[4]
	if value then
		value.Parent = ReplicatedStorage
	end
	if copy then
		copy:Destroy()
	end
	flag("world_id_race_completed", ok, ok and 1 or tostring(err))
	return r
end

return Tests
