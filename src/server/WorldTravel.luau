--!nonstrict
-- Travel between the World 1 and World 2 places (design doc 4.46, docs/WORLD2_SPEC.md "Travel"). The save is written
-- and its session lock released first, so the other place's load takes the lock at once (PlayerData.LOCK_WAIT covers
-- a late autosave that re-locks it). Admins only while the gate is locked (Server/AdminService /world1, /world2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldConfig"))
local PlayerData = require(script.Parent.PlayerData)

local WorldTravel = {}

WorldTravel.AllowStudio = false -- test seam: Studio cannot teleport, so Go refuses there before it saves

-- Test seam: replaces TeleportService:TeleportAsync(placeId, { player }).
WorldTravel.Teleport = function(placeId, player)
	TeleportService:TeleportAsync(placeId, { player })
end

-- Sends `player` to world `id`. Returns ok, message. Yields (save, teleport).
function WorldTravel.Go(player, id)
	if id == WorldConfig.Id then
		return false, "already in World " .. id
	end
	local placeId = WorldConfig.PLACES[id]
	if type(placeId) ~= "number" then
		return false, "World " .. tostring(id) .. " has no place yet (WorldConfig.PLACES)"
	end
	if RunService:IsStudio() and not WorldTravel.AllowStudio then
		return false, "teleports do not run in Studio"
	end
	if player:GetAttribute("DataLoaded") and not PlayerData.Save(player, nil, true) then
		return false, "could not save before travel"
	end
	local ok, err = pcall(WorldTravel.Teleport, placeId, player)
	if not ok then
		return false, "teleport failed: " .. tostring(err) -- the next autosave takes the lock back
	end
	return true, "travelling to World " .. id
end

-- Open world gates (tag WorldGate, attribute TargetWorld; Shared/SpawnArea) send a touching player's avatar on. One trip
-- at a time per player.
function WorldTravel.Start()
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local busy = {}
	local function hook(part)
		part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local target = part:GetAttribute("TargetWorld")
			if not player or busy[player] or part:GetAttribute("Locked") or type(target) ~= "number" then
				return
			end
			busy[player] = true
			local ok, message = WorldTravel.Go(player, target)
			if not ok then
				warn("WorldTravel: " .. player.Name .. ": " .. message)
				task.wait(3)
			end
			busy[player] = nil
		end)
	end
	CollectionService:GetInstanceAddedSignal("WorldGate"):Connect(hook)
	for _, part in CollectionService:GetTagged("WorldGate") do
		hook(part)
	end
end

return WorldTravel
