--!nonstrict
-- Travel between the World 1 and World 2 places (design doc 4.47, docs/WORLD2_SPEC.md "Travel"). The save is written
-- and its session lock released first, so the other place's load takes the lock at once (PlayerData.LOCK_WAIT covers
-- a late autosave that re-locks it). Admins only while the gate is locked (Server/AdminService /world1, /world2).
-- One trip at a time per player (gate and admin commands alike): the player stays busy from Go until they leave the
-- server or the teleport fails. After the release save the player's state is frozen (DataLoaded off, as
-- PlayerData.ResetToNew does, so no remote, purchase or save runs; Travelling on, so MoneyService pays nothing) until
-- departure; a failure restores it and tells the player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldConfig"))
local PlayerData = require(script.Parent.PlayerData)

local WorldTravel = {}

WorldTravel.AllowStudio = false -- test seam: Studio cannot teleport, so Go refuses there before it saves
WorldTravel.TIMEOUT = 60 -- placeholder: seconds a trip may stay pending with no departure and no failure event

-- player -> { Loaded = DataLoaded before the freeze } while a trip is pending
local busy = setmetatable({}, { __mode = "k" })

-- Test seam: replaces TeleportService:TeleportAsync(placeId, { player }).
WorldTravel.Teleport = function(placeId, player)
	TeleportService:TeleportAsync(placeId, { player })
end

-- Test seam: the release save. Returns saved, readOnly (PlayerData.Save).
WorldTravel.Save = function(player)
	return PlayerData.Save(player, nil, true)
end

-- Test seam: tells the player the trip failed (Client/TeamToast shows Remotes.RunEvent { Kind = "TravelFailed" }).
WorldTravel.Notify = function(player)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local event = remotes and remotes:FindFirstChild("RunEvent")
	if event and player:IsA("Player") then
		event:FireClient(player, { Kind = "TravelFailed" })
	end
end

function WorldTravel.Busy(player)
	return busy[player] ~= nil
end

-- The trip failed (TeleportAsync error, TeleportInitFailed, or the timeout): restore the frozen state, clear busy and
-- tell the player. The lock was released, so the next autosave takes it back.
function WorldTravel.Failed(player, reason)
	local trip = busy[player]
	if not trip then
		return
	end
	busy[player] = nil
	player:SetAttribute("Travelling", nil)
	if trip.Loaded then
		player:SetAttribute("DataLoaded", true)
	end
	warn("WorldTravel: " .. player.Name .. ": " .. tostring(reason))
	pcall(WorldTravel.Notify, player)
end

-- Sends `player` to world `id`. Returns ok, message. Yields (save, teleport).
function WorldTravel.Go(player, id)
	if busy[player] then
		return false, "already travelling"
	end
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
	local trip = { Loaded = player:GetAttribute("DataLoaded") == true }
	busy[player] = trip
	if trip.Loaded then
		local saved, readOnly = WorldTravel.Save(player)
		if not saved and not readOnly then -- a read-only save (newer version) needs no write: travel anyway
			busy[player] = nil
			return false, "could not save before travel"
		end
		player:SetAttribute("DataLoaded", nil)
	end
	player:SetAttribute("Travelling", true)
	local ok, err = pcall(WorldTravel.Teleport, placeId, player)
	if not ok then
		WorldTravel.Failed(player, "teleport failed: " .. tostring(err))
		return false, "teleport failed: " .. tostring(err)
	end
	task.delay(WorldTravel.TIMEOUT, function()
		if busy[player] == trip and player.Parent then
			WorldTravel.Failed(player, "no departure after " .. WorldTravel.TIMEOUT .. " s")
		end
	end)
	return true, "travelling to World " .. id
end

-- Open world gates (tag WorldGate, attribute TargetWorld; Shared/SpawnArea) send a touching player's avatar on.
function WorldTravel.Start()
	local CollectionService = game:GetService("CollectionService")
	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		WorldTravel.Failed(player, "teleport init failed: " .. tostring(result) .. " " .. tostring(message))
	end)
	local cooldown = setmetatable({}, { __mode = "k" }) -- a refused touch waits 3 s before it is tried again
	local function hook(part)
		part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local target = part:GetAttribute("TargetWorld")
			if not player or cooldown[player] or part:GetAttribute("Locked") or type(target) ~= "number" then
				return
			end
			cooldown[player] = true
			local ok, message = WorldTravel.Go(player, target)
			if not ok then
				warn("WorldTravel: " .. player.Name .. ": " .. message)
				task.wait(3)
			end
			cooldown[player] = nil
		end)
	end
	CollectionService:GetInstanceAddedSignal("WorldGate"):Connect(hook)
	for _, part in CollectionService:GetTagged("WorldGate") do
		hook(part)
	end
end

return WorldTravel
