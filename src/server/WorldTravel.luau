--!nonstrict
-- Travel between the World 1 and World 2 places (design doc 4.47, docs/WORLD2_SPEC.md "Travel"). The save is written
-- and its session lock released first, so the other place's load takes the lock at once. CanEnter decides who may go
-- (admins always, Server/AdminService /world1, /world2). One trip at a time per player (gate and admin commands alike): the
-- player stays busy from Go until they leave the server or the trip fails.
-- Go first ends what could still pay (Depart: the run stops, the boss event is left), then freezes the player
-- (DataLoaded off, as PlayerData.ResetToNew does, so no remote, receipt, roll, run or autosave runs; Travelling on, so
-- MoneyService pays nothing) and only then writes the release save, so nothing earned is left out of it. The TIMEOUT
-- runs from the start of the trip, the save included. A failure restores the state, takes the lock back with a normal
-- save and tells the player; an arrival trip (Arrived) instead stays frozen, is tried ARRIVAL_TRIES times, then kicks.
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

-- Test seam: after a failed trip whose release save ran, a normal save takes the session lock back (only if the
-- player is still here once PlayerData's save queue reaches it: never a lock for a player who left).
WorldTravel.Retake = function(player)
	return PlayerData.Save(player, nil, nil, nil, true)
end

-- Test seam: ends what could still pay before the freeze (the leave hooks, without forgetting the avatar). Required
-- here, not at the top: AdminService requires this module, and these load after it.
WorldTravel.Depart = function(player)
	require(script.Parent.DuelService).PlayerLeft(player, true) -- a request is cancelled, a duel race forfeited
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

-- Test seam: tells the player why the gate refused them (Client/TeamToast: Remotes.RunEvent { Kind = "WorldGate", Text }).
WorldTravel.Notice = function(player, text)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local event = remotes and remotes:FindFirstChild("RunEvent")
	if event and player:IsA("Player") then
		event:FireClient(player, { Kind = "WorldGate", Text = text })
	end
end

-- Test seam: the player's World 1 BestTrack (the highest World 1 track number beaten, RaceService). In World 2 the
-- BestTrack attribute is World 2's, so it reads World1BestTrack there (PlayerData's read-only mirror of the save's
-- top-level BestTrack, set on load).
WorldTravel.World1Best = function(player)
	return tonumber(player:GetAttribute(WorldConfig.Id == 1 and "BestTrack" or "World1BestTrack")) or 0
end

-- Design doc 4.47: may `player` enter world `id`? Returns ok, reason (the player's notice when refused). World 1 and
-- admins always; anyone else needs the gate open (WorldConfig.GATE_OPEN) AND the opening rule: World 1 Track
-- GATE_TRACK beaten and rebirth >= GATE_REBIRTH (no Money cost, nothing resets). Go and Arrived both ask it.
-- A third value true: refused, but the admin check could not tell (AdminService.IsAdmin "unknown").
function WorldTravel.CanEnter(player, id)
	if id == 1 then
		return true, nil
	end
	local admin, adminState = WorldTravel.IsAdmin(player)
	if admin then
		return true, nil
	end
	local reason = nil
	if not WorldConfig.GATE_OPEN then
		reason = "COMING SOON"
	elseif WorldTravel.World1Best(player) < WorldConfig.GATE_TRACK then
		reason = "Beat Track " .. WorldConfig.GATE_TRACK
	elseif (tonumber(player:GetAttribute("RebirthLevel")) or 0) < WorldConfig.GATE_REBIRTH then
		reason = "Reach Rebirth " .. WorldConfig.GATE_REBIRTH
	end
	return reason == nil, reason, reason ~= nil and adminState == "unknown"
end
-- placeholder: seconds an arrival waits for its load to finish or fail (a load retries a held lock for LOCK_WAIT)
WorldTravel.ARRIVAL_WAIT = PlayerData.LOCK_WAIT + 30
WorldTravel.ARRIVAL_TRIES = 3 -- placeholder: return trips tried before the arrival is kicked
WorldTravel.ARRIVAL_RETRY = 3 -- placeholder: seconds between return trips
WorldTravel.ADMIN_RECHECK = 10 -- placeholder: seconds before an arrival whose admin check failed is checked again
WorldTravel.ADMIN_RECHECKS = 6 -- placeholder: such rechecks before the player counts as no admin
WorldTravel.KICK_MESSAGE = "Could not move you between worlds. Please rejoin Anime Run."

-- Test seam: an arrival allowed to stay only after an admin recheck missed the welcome at load (Server/WorldWelcome).
WorldTravel.Stayed = function(player)
	require(script.Parent.WorldWelcome).Check(player)
end

-- Test seam: removes an arrival whose return trips all failed.
WorldTravel.Kick = function(player, message)
	player:Kick(message)
end

function WorldTravel.Busy(player)
	return busy[player] ~= nil
end

local function unfreeze(player, trip)
	player:SetAttribute("Travelling", nil)
	if trip.Loaded then
		player:SetAttribute("DataLoaded", true)
	end
end

local function retake(player)
	task.spawn(function()
		if not player.Parent then
			return
		end
		local ok, saved = pcall(WorldTravel.Retake, player)
		if not (ok and saved) then
			warn("WorldTravel: " .. player.Name .. ": the lock retake save failed; the next autosave tries again")
		end
	end)
end

-- The trip failed (TeleportAsync error, TeleportInitFailed, or the timeout): restore the frozen state, clear busy, take
-- the lock back and tell the player. `trip` (optional): only that trip fails; a stale failure of an older one is ignored.
function WorldTravel.Failed(player, reason, trip)
	local current = busy[player]
	if not current or (trip ~= nil and trip ~= current) then
		return
	end
	busy[player] = nil
	if current.Arrival then
		warn("WorldTravel: " .. player.Name .. ": return trip failed (stays frozen): " .. tostring(reason))
		return -- never unfrozen: the arrival keeps trying to leave (Arrived), then is kicked
	end
	unfreeze(player, current)
	if current.Released then
		retake(player)
	end
	warn("WorldTravel: " .. player.Name .. ": " .. tostring(reason))
	pcall(WorldTravel.Notify, player)
end

-- Sends `player` to world `id`. Returns ok, message. Yields (save, teleport). `arrival` (sendBack's carry table
-- { Loaded, Released }, or true): a failure keeps the player frozen; the carry holds DataLoaded from before the first
-- freeze and whether a release save already went out, across the return trips.
function WorldTravel.Go(player, id, arrival)
	if busy[player] then
		return false, "already travelling"
	end
	if id == WorldConfig.Id then
		return false, "already in World " .. id
	end
	if not arrival and not (player:GetAttribute("DataLoaded") or player:GetAttribute("DataFailed")) then
		pcall(WorldTravel.Notice, player, "Still loading, try again")
		return false, "still loading" -- a trip now would skip the release save of a load still in flight
	end
	local allowed, reason = WorldTravel.CanEnter(player, id)
	if not allowed then
		return false, reason
	end
	local placeId = WorldConfig.PLACES[id]
	if type(placeId) ~= "number" then
		return false, "World " .. tostring(id) .. " has no place yet (WorldConfig.PLACES)"
	end
	if RunService:IsStudio() and not WorldTravel.AllowStudio then
		return false, "teleports do not run in Studio"
	end
	tripCount += 1
	local carry = type(arrival) == "table" and arrival or nil
	local trip = {
		Id = tripCount,
		Loaded = if carry then carry.Loaded == true else player:GetAttribute("DataLoaded") == true,
		Released = carry ~= nil and carry.Released == true,
		Arrival = arrival ~= nil and arrival ~= false,
	}
	busy[player] = trip
	-- from the start: a hung release save (UpdateAsync) or TeleportAsync never freezes the player without end
	task.delay(WorldTravel.TIMEOUT, function()
		if busy[player] == trip and player.Parent then
			WorldTravel.Failed(player, "no departure after " .. WorldTravel.TIMEOUT .. " s", trip)
		end
	end)
	local okDepart, departErr = pcall(WorldTravel.Depart, player)
	if not okDepart then
		warn("WorldTravel: " .. player.Name .. ": depart: " .. tostring(departErr))
	end
	player:SetAttribute("Travelling", true)
	if trip.Loaded and not trip.Released then
		player:SetAttribute("DataLoaded", nil)
		local saved, readOnly = WorldTravel.Save(player)
		if (saved or readOnly) and carry then
			carry.Released = true -- the lock is out even if this trip timed out: later return trips skip the save
		end
		if busy[player] ~= trip then -- the trip timed out during the save: it does not go on
			-- the late release save dropped the lock: take it back unless the arrival is still frozen (sendBack then
			-- retakes it if the player is allowed to stay after all)
			if (saved or readOnly) and (not trip.Arrival or player:GetAttribute("Travelling") ~= true) then
				retake(player)
			end
			return false, "the trip timed out"
		end
		if not saved and not readOnly then -- a read-only save (newer version) needs no write: travel anyway
			busy[player] = nil
			if trip.Arrival then
				return false, "could not save before the return trip (stays frozen)"
			end
			unfreeze(player, trip)
			pcall(WorldTravel.Notify, player)
			return false, "could not save before travel"
		end
		trip.Released = true
	end
	if not player.Parent then
		busy[player] = nil -- left during the save: the release save already holds everything
		return false, "left before travel"
	end
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

-- Design doc 4.47: a player who arrives in World 2 but may not enter it (CanEnter: not an admin and the gate closed,
-- or open but the opening rule unmet) is sent back to World 1 (never in Studio, as Go).
-- The return trip runs in the background: a failed one is tried again (the player stays frozen) up to ARRIVAL_TRIES
-- times, CanEnter asked again before each (a player who now may enter stays: unfrozen, the lock taken back if a
-- release save went out). Then the player is kicked, after one more frozen release save (bounded by TIMEOUT) if none
-- went out: the kick's leave save skips a frozen player. If every release save failed, the kick leaves the session lock
-- until PlayerData.LOCK_TIMEOUT (the next join waits for it). Each Go runs in its own thread, so a hung save or
-- TeleportAsync still ends at TIMEOUT. An admin check that failed ("unknown") neither keeps nor sends: Arrived is asked
-- again after ADMIN_RECHECK, up to ADMIN_RECHECKS times, then the player counts as no admin.
local function sendBack(player)
	local carry = { Loaded = player:GetAttribute("DataLoaded") == true, Released = false }
	player:SetAttribute("SendingBack", true) -- set by Arrived already; cleared below if it may stay after all
	for try = 1, WorldTravel.ARRIVAL_TRIES do
		if try > 1 then
			task.wait(WorldTravel.ARRIVAL_RETRY)
			if player.Parent and WorldTravel.CanEnter(player, 2) then
				player:SetAttribute("SendingBack", nil)
				unfreeze(player, carry)
				if carry.Released then
					retake(player)
				end
				return
			end
		end
		if not player.Parent then
			return
		end
		task.spawn(WorldTravel.Go, player, 1, carry) -- sets busy before its first yield
		while busy[player] and player.Parent do -- until departure (the player leaves) or a failure
			task.wait(0.25)
		end
		if not player.Parent then
			return
		end
	end
	if carry.Loaded and not carry.Released then
		local done = false
		task.spawn(function()
			local ok, saved, readOnly = pcall(WorldTravel.Save, player)
			done = true
			if not (ok and (saved or readOnly)) then
				warn("WorldTravel: " .. player.Name .. ": the release save before the kick failed")
			end
		end)
		local deadline = os.clock() + WorldTravel.TIMEOUT
		while not done and player.Parent and os.clock() < deadline do
			task.wait(0.1)
		end
	end
	if not player.Parent then
		return
	end
	warn("WorldTravel: " .. player.Name .. ": every return trip failed, kicked")
	pcall(WorldTravel.Kick, player, WorldTravel.KICK_MESSAGE)
end

-- `recheck` (internal): how many ADMIN_RECHECKs already ran for this arrival.
function WorldTravel.Arrived(player, recheck)
	if WorldConfig.Id ~= 2 then
		return false, "not World 2"
	end
	if RunService:IsStudio() and not WorldTravel.AllowStudio then
		return false, "no arrival check in Studio"
	end
	recheck = recheck or 0
	local allowed, _, unknown = WorldTravel.CanEnter(player, 2)
	-- from the first refusal or unknown answer its saves keep the carried team out of Worlds.W2 (PlayerData, WorldSave.Fold
	-- `keep`; docs/BUGS.md w2-sendback-stale-team), until it may stay
	player:SetAttribute("SendingBack", if allowed then nil else true)
	if allowed then
		if recheck > 0 then
			pcall(WorldTravel.Stayed, player)
		end
		return false, "may stay"
	end
	if unknown and recheck < WorldTravel.ADMIN_RECHECKS then
		task.delay(WorldTravel.ADMIN_RECHECK, function()
			if player.Parent then
				WorldTravel.Arrived(player, recheck + 1)
			end
		end)
		return false, "admin check failed, asked again later"
	end
	if busy[player] then
		return false, "already travelling"
	end
	task.spawn(sendBack, player) -- runs up to its first yield: the first trip is out when this returns
	return true, "sending back to World 1"
end

-- The arrival check once the save loaded or failed (Go then writes it and releases its lock). A load still undecided
-- after ARRIVAL_WAIT is kicked: acting earlier could freeze a player whose load then finishes mid-trip.
function WorldTravel.Arrive(player)
	local deadline = os.clock() + WorldTravel.ARRIVAL_WAIT
	local function decided()
		return player:GetAttribute("DataLoaded") == true or player:GetAttribute("DataFailed") == true
	end
	while player.Parent and not decided() and os.clock() < deadline do
		task.wait(0.5)
	end
	if not player.Parent then
		return false, "left"
	end
	if not decided() then
		if WorldConfig.Id == 2 and not (RunService:IsStudio() and not WorldTravel.AllowStudio) then
			pcall(WorldTravel.Kick, player, WorldTravel.KICK_MESSAGE)
			return false, "load undecided, kicked"
		end
		return false, "load undecided"
	end
	local ok, message = WorldTravel.Arrived(player)
	if ok then
		print("WorldTravel: " .. player.Name .. " may not stay in World 2: " .. message)
	end
	return ok, message
end

-- A touch of gate `part` by `player`: on through Go if CanEnter allows and the gate is not Locked, else the player is
-- told why (Notice). A Locked gate never sends: admins travel with /world2. Returns whether a trip started.
function WorldTravel.Touched(part, player)
	local target = part:GetAttribute("TargetWorld")
	if type(target) ~= "number" then
		return false
	end
	local ok, message = WorldTravel.CanEnter(player, target)
	if not ok then
		pcall(WorldTravel.Notice, player, message)
		return false
	end
	if part:GetAttribute("Locked") then
		return false
	end
	ok, message = WorldTravel.Go(player, target)
	if not ok then
		warn("WorldTravel: " .. player.Name .. ": " .. message)
	end
	return ok
end

-- TeleportService.TeleportInitFailed: fails the pending trip; an older trip's late failure (its TravelTrip id in the
-- teleport data) leaves the new one alone; no readable id fails the pending trip.
function WorldTravel.InitFailed(player, result, message, options)
	local ok, data = pcall(function()
		return options and options:GetTeleportData()
	end)
	local id = ok and type(data) == "table" and data.TravelTrip
	local trip = busy[player]
	if trip and (not id or id == trip.Id) then
		WorldTravel.Failed(player, "teleport init failed: " .. tostring(result) .. " " .. tostring(message), trip)
	end
end

function WorldTravel.Start()
	local CollectionService = game:GetService("CollectionService")
	TeleportService.TeleportInitFailed:Connect(function(player, result, message, _, options)
		WorldTravel.InitFailed(player, result, message, options)
	end)
	local cooldown = setmetatable({}, { __mode = "k" }) -- a refused touch waits 3 s before it is tried again
	-- World gates (tag WorldGate; Shared/SpawnArea): Touched decides
	local function hook(part)
		part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or cooldown[player] then
				return
			end
			cooldown[player] = true
			if not WorldTravel.Touched(part, player) then
				task.wait(3)
			end
			cooldown[player] = nil
		end)
	end
	CollectionService:GetInstanceAddedSignal("WorldGate"):Connect(hook)
	for _, part in CollectionService:GetTagged("WorldGate") do
		hook(part)
	end
	local function arrive(player)
		WorldTravel.Arrive(player)
	end
	Players.PlayerAdded:Connect(arrive)
	for _, player in Players:GetPlayers() do
		task.spawn(arrive, player)
	end
end

return WorldTravel
