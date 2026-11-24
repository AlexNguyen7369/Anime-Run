--!nonstrict
-- Travel between the World 1 and World 2 places (design doc 4.47, docs/WORLD2_SPEC.md "Travel"). The save is written
-- and its session lock released first, so the other place's load takes the lock at once. Admins only while the gate
-- is locked (Server/AdminService /world1, /world2). One trip at a time per player (gate and admin commands alike): the
-- player stays busy from Go until they leave the server or the trip fails.
-- Go first ends what could still pay (Depart: the run stops, the boss event is left), then freezes the player
-- (DataLoaded off, as PlayerData.ResetToNew does, so no remote, receipt, roll, run or autosave runs; Travelling on, so
-- MoneyService pays nothing) and only then writes the release save, so nothing earned is left out of it. A failure
-- restores the state, takes the lock back with a normal save and tells the player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldConfig"))
local PlayerData = require(script.Parent.PlayerData)

local WorldTravel = {}

WorldTravel.AllowStudio = false -- test seam: Studio cannot teleport, so Go refuses there before it saves
WorldTravel.TIMEOUT = 60 -- placeholder: seconds a trip may stay pending with no departure and no failure event

-- player -> { Id, Loaded = DataLoaded before the freeze, Released = the release save moved the lock } while pending
local busy = setmetatable({}, { __mode = "k" })
local tripCount = 0

-- Test seam: replaces TeleportService:TeleportAsync(placeId, { player }, options). `tripId` comes back in
-- TeleportInitFailed's teleport data, so an old trip's failure never cancels a newer one.
WorldTravel.Teleport = function(placeId, player, tripId)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ TravelTrip = tripId })
	TeleportService:TeleportAsync(placeId, { player }, options)
end

-- Test seam: the release save of a frozen player. Returns saved, readOnly (PlayerData.Save).
WorldTravel.Save = function(player)
	return PlayerData.Save(player, nil, true, true)
end

-- Test seam: after a failed trip whose release save ran, a normal save takes the session lock back.
WorldTravel.Retake = function(player)
	return PlayerData.Save(player)
end

-- Test seam: ends what could still pay before the freeze (the leave hooks, without forgetting the avatar). Required
-- here, not at the top: AdminService requires this module, and these load after it.
WorldTravel.Depart = function(player)
	require(script.Parent.RunnerService).SetAutoRace(player, false)
	require(script.Parent.BossEventService).Leave(player, "Travel")
end

-- Test seam: tells the player the trip failed (Client/TeamToast shows Remotes.RunEvent { Kind = "TravelFailed" }).
WorldTravel.Notify = function(player)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local event = remotes and remotes:FindFirstChild("RunEvent")
	if event and player:IsA("Player") then
		event:FireClient(player, { Kind = "TravelFailed" })
	end
end

-- Test seam and wiring: Main.server sets AdminService.IsAdmin (AdminService requires this module, so not required here)
WorldTravel.IsAdmin = function()
	return false
end
WorldTravel.ARRIVAL_WAIT = 30 -- placeholder: seconds an arrival waits for its save to load before it is sent back

function WorldTravel.Busy(player)
	return busy[player] ~= nil
end

local function unfreeze(player, trip)
	player:SetAttribute("Travelling", nil)
	if trip.Loaded then
		player:SetAttribute("DataLoaded", true)
	end
end

-- The trip failed (TeleportAsync error, TeleportInitFailed, or the timeout): restore the frozen state, clear busy, take
-- the lock back and tell the player. `trip` (optional): only that trip fails; a stale failure of an older one is ignored.
function WorldTravel.Failed(player, reason, trip)
	local current = busy[player]
	if not current or (trip ~= nil and trip ~= current) then
		return
	end
	busy[player] = nil
	unfreeze(player, current)
	if current.Released and player.Parent then
		task.spawn(function()
			local ok, saved = pcall(WorldTravel.Retake, player)
			if not (ok and saved) then
				warn("WorldTravel: " .. player.Name .. ": the lock retake save failed; the next autosave tries again")
			end
		end)
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
	tripCount += 1
	local trip = { Id = tripCount, Loaded = player:GetAttribute("DataLoaded") == true }
	busy[player] = trip
	local okDepart, departErr = pcall(WorldTravel.Depart, player)
	if not okDepart then
		warn("WorldTravel: " .. player.Name .. ": depart: " .. tostring(departErr))
	end
	player:SetAttribute("Travelling", true)
	if trip.Loaded then
		player:SetAttribute("DataLoaded", nil)
		local saved, readOnly = WorldTravel.Save(player)
		if not saved and not readOnly then -- a read-only save (newer version) needs no write: travel anyway
			busy[player] = nil
			unfreeze(player, trip)
			return false, "could not save before travel"
		end
		trip.Released = true
	end
	if not player.Parent then
		busy[player] = nil -- left during the save: the release save already holds everything
		return false, "left before travel"
	end
	-- the timeout runs from before TeleportAsync, which can hang
	task.delay(WorldTravel.TIMEOUT, function()
		if busy[player] == trip and player.Parent then
			WorldTravel.Failed(player, "no departure after " .. WorldTravel.TIMEOUT .. " s", trip)
		end
	end)
	local ok, err = pcall(WorldTravel.Teleport, placeId, player, trip.Id)
	if not ok then
		WorldTravel.Failed(player, "teleport failed: " .. tostring(err), trip)
		return false, "teleport failed: " .. tostring(err)
	end
	if busy[player] ~= trip then
		return false, "the trip failed" -- timed out (or failed) while TeleportAsync was still running
	end
	return true, "travelling to World " .. id
end

-- Design doc 4.47: the World 2 gate is locked for everyone and admins travel with /world2, so while
-- WorldConfig.GATE_OPEN is false a non-admin who arrives in World 2 is sent back to World 1 (never in Studio, as Go).
-- Returns ok, message (Go's result, or false and the reason it stays).
function WorldTravel.Arrived(player)
	if WorldConfig.Id ~= 2 or WorldConfig.GATE_OPEN then
		return false, "the gate is open here"
	end
	if RunService:IsStudio() and not WorldTravel.AllowStudio then
		return false, "no arrival check in Studio"
	end
	if WorldTravel.IsAdmin(player) then
		return false, "admin"
	end
	return WorldTravel.Go(player, 1)
end

-- Open world gates (tag WorldGate, attribute TargetWorld; Shared/SpawnArea) send a touching player's avatar on.
function WorldTravel.Start()
	local CollectionService = game:GetService("CollectionService")
	TeleportService.TeleportInitFailed:Connect(function(player, result, message, _, options)
		local ok, data = pcall(function()
			return options and options:GetTeleportData()
		end)
		local id = ok and type(data) == "table" and data.TravelTrip
		local trip = busy[player]
		if trip and (id == nil or id == trip.Id) then -- an older trip's late failure leaves the new one alone
			WorldTravel.Failed(player, "teleport init failed: " .. tostring(result) .. " " .. tostring(message), trip)
		end
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
	-- the arrival check after the save loads (Go then writes it and releases its lock)
	local function arrive(player)
		local deadline = os.clock() + WorldTravel.ARRIVAL_WAIT
		while player.Parent and not player:GetAttribute("DataLoaded") and os.clock() < deadline do
			task.wait(0.5)
		end
		if player.Parent then
			local ok, message = WorldTravel.Arrived(player)
			if ok then
				print("WorldTravel: " .. player.Name .. " arrived while the gate is locked: " .. message)
			end
		end
	end
	Players.PlayerAdded:Connect(arrive)
	for _, player in Players:GetPlayers() do
		task.spawn(arrive, player)
	end
end

return WorldTravel
