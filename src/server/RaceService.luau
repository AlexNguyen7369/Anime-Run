--!nonstrict
-- Auto race. The server moves every player's runner (the anchored rig from Shared/RunnerFactory) along the chain of
-- tracks on a rail: its arc distance grows by exactly the cruise speed every frame (no acceleration, no corner
-- slowing; design doc, owner 2026-10-20), and the rig is put at that point of the path, upright and facing along it
-- (docs/WORLD_REDESIGN_SPEC.md section 2). No physics forces. The rig is the authoritative pose; for smooth drawing
-- the run publishes RunRoute / RunDistance / RunSpeed on the model and every client interpolates the visible runner
-- (Client/RunnerView; contract in Server/CarTest/RunnerTests). While it runs, the player's Speed stat grows at a
-- flat base rate multiplied only by permanent Speed Gain upgrades and rebirths. The cruise speed follows the stat.
-- When the runner passes a winnings pad the pad pays the player (MoneyService.Collect); the rig never has to touch
-- the pad. After the last finish the runner is put back at the start of Track 1 and keeps running.
--
-- NPC races (options.Npc, on for players): every track is a race against that track's NPC (Shared/NpcConfig,
-- Shared/NpcRacer). If the NPC reaches a checkpoint first, the player loses at that checkpoint and is immediately
-- teleported back to the start of Track 1; the client is told which checkpoint was lost.
-- Banked winnings (docs/SPAWN_AND_ROLLS_SPEC.md, owner 2026-10-30 in TEAM_AND_STAMINA_SPEC): winning a track adds its
-- pad's value (MoneyService.Quote) to the run's bank (run.Unbanked, mirrored in the player attribute Unbanked) instead
-- of paying; a loss empties the bank; run:CashOut() (also done by run:Destroy, so Stop, death and leaving) pays it.
-- Team and stamina (docs/TEAM_AND_STAMINA_SPEC.md): an NPC run reads the player's Team at start. The active runner's
-- stamina drains 100 / seconds percent per second; at 0 the next filled slot tags in at its own cruise speed; when the
-- last one is empty the bank is cashed out, the run stops and the player goes back on foot. A loss reset refills.
-- Race events go to the owning player only (Remotes.NpcRace:FireClient), whose client draws the NPC.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestService = require(script.Parent.QuestService)
local PathDriver = require(Shared.PathDriver)
local RaceConfig = require(Shared.RaceConfig)
local RunnerFactory = require(Shared.RunnerFactory)
local NpcConfig = require(Shared.NpcConfig)
local NpcRacer = require(Shared.NpcRacer)
local CharacterCatalog = require(Shared.CharacterCatalog)
local StaminaConfig = require(Shared.StaminaConfig)
local CheckpointConfig = require(Shared.CheckpointConfig)
local MoneyService = require(script.Parent.MoneyService)
local PlayerData = require(script.Parent.PlayerData)
local GachaService = require(script.Parent.GachaService)
local UpgradeService = require(script.Parent.UpgradeService)
local BoostConfig = require(Shared.BoostConfig)
local BoostService = require(script.Parent.BoostService)
local LevelService = require(script.Parent.LevelService)
local RaceTimeService = require(script.Parent.RaceTimeService)

local RaceService = {}

RaceService.COMMIT_INTERVAL = 0.25 -- seconds between writes of the gained Speed stat (replication is not per frame)
RaceService.START_AHEAD = 5 -- studs along the path from the road's first edge where a run starts
RaceService.PUBLISH_INTERVAL = 0.1 -- s between RunDistance / RunSpeed updates (contract: at most 0.25 s)
local DEVIATION_GRACE = 3 -- seconds after the start before path deviation is measured
local DEVIATION_GRACE_STUDS = 30 -- ...or this far along it: a MAX_STAT runner finishes the route in under 3 s

local RUNNER_GROUP = "Runners"

local route = nil
local npcRemote = nil -- Remotes.NpcRace, created by Start
local runRemote = nil -- Remotes.RunEvent, created by Start: Swap / Exhausted to the owner

-- entries = { { Layout, Origin, Model, Number }, ... } in Number order (the chain Main builds).
function RaceService.BuildRoute(entries)
	local path = PathDriver.Chain(entries)
	local pads, tracks = {}, {}
	for i, entry in entries do
		local pad = entry.Model and entry.Model:FindFirstChild("WinPad", true)
		table.insert(pads, { Pad = pad, Index = path.PadIndices[i], Number = entry.Number or i })
		local config = NpcConfig.For(entry.Number or i)
		local lane = NpcRacer.LanePath(entry)
		table.insert(tracks, {
			Number = entry.Number or i,
			StartIndex = path.StartIndices[i],
			FinishIndex = path.FinishIndices[i],
			PadIndex = path.PadIndices[i],
			Pad = pad,
			Npc = { Config = config, Path = lane, Profile = NpcRacer.Profile(lane, config.Speed) },
		})
	end
	return { Path = path, Pads = pads, Tracks = tracks }
end

function RaceService.SetRoute(newRoute)
	route = newRoute
end

function RaceService.GetRoute()
	return route
end

local function isPlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player")
end

-- The upgrade tree's gate: the best track the player has won (NPC mode) or finished (no NPC). Fakes are Instances too.
local function reachTrack(player, number)
	if typeof(player) == "Instance" then
		UpgradeService.ReachTrack(player, number)
	end
end

local function setCarGroup(car)
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = RUNNER_GROUP
		end
	end
end

local arcs = setmetatable({}, { __mode = "k" }) -- path -> PathDriver.Arc of its waypoints
local routeNames = setmetatable({}, { __mode = "k" }) -- path -> its folder name in ReplicatedStorage.RunRoutes
local routeCount = 0

local function arcOf(path)
	local arc = arcs[path]
	if not arc then
		arc = PathDriver.Arc(path.WorldWaypoints)
		arcs[path] = arc
	end
	return arc
end

-- The route a client interpolates along (contract RunRoute): a Folder in ReplicatedStorage.RunRoutes holding one
-- Vector3Value per waypoint, named "1".."n" (attribute Count = n), built once per route before any run names it.
-- shortcut: folders are never removed (one per route built; tests build a handful), add cleanup if routes churn.
local function routeName(path)
	local name = routeNames[path]
	if name then
		return name
	end
	local root = ReplicatedStorage:FindFirstChild("RunRoutes")
	if not root then
		root = Instance.new("Folder")
		root.Name = "RunRoutes"
		root.Parent = ReplicatedStorage
	end
	routeCount += 1
	name = "Route" .. routeCount
	local folder = Instance.new("Folder")
	folder.Name = name
	folder:SetAttribute("Count", #path.WorldWaypoints)
	for i, p in path.WorldWaypoints do
		local v = Instance.new("Vector3Value")
		v.Name = tostring(i)
		v.Value = p
		v.Parent = folder
	end
	folder.Parent = root
	routeNames[path] = name
	return name
end

-- The rig's pivot (its Torso) for the feet pose `feet` on the path.
local function rigCFrame(feet)
	return feet * CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0)
end

-- Starts driving `car` along `raceRoute` for `player`. Returns a run object; call run:Destroy() to stop.
-- options: { Loop = true } puts the car back at the start of the route after the last finish.
--          { Npc = true } races every track against its NPC. Test hooks: NpcSpeeds = { [number] = speed },
--          LoseScreenSeconds, OnRaceEvent(event), StaminaSeconds = { s1, s2, s3 }, OnRunEvent(event).
--          { StartTrack = n } (NPC mode) starts on track n, and a loss or the loop goes back to it (checkpoints).
--          { Duel = { Track = n, OnFinish = fn(run, seconds) } } is a duel run (docs/DUEL_SPEC.md): no NPC, starts
--          on track n, pays no pad, banks nothing, and is Finished (OnFinish called once) at that track's finish.
function RaceService.NewRun(car, raceRoute, player, options)
	options = options or {}
	car:SetAttribute("AutoRace", true)

	PlayerData.Setup(player)
	local stat = PlayerData.SpeedStat(player)
	local wps = raceRoute.Path.WorldWaypoints
	local n = #wps
	local arc = arcOf(raceRoute.Path)
	-- Index: the waypoint nearest the runner along the path (n once past the last one); Done past the end.
	-- Tests may set Index; the rail then moves the runner to that waypoint.
	local driver =
		{ Index = 1, Done = false, TargetSpeed = RaceConfig.SpeedFor(stat, GachaService.CruiseMultis(player)) }
	local run = {
		Car = car,
		TargetSpeed = driver.TargetSpeed,
		Finished = false,
		Payouts = 0,
		PaidTotal = 0,
		Unbanked = 0, -- NPC mode: won, not yet paid (paid by CashOut)
		BankedTotal = 0, -- NPC mode: everything wins added to the bank
		Gained = 0,
		MinUpY = 1,
		MaxPathDeviation = 0,
		FlipRecoveries = 0, -- a rail runner cannot flip; kept for old callers
		RailSnaps = 0, -- kept for old callers: the rail places the anchored rig every frame
		OffTrackSeconds = 0,
		Laps = 0,
		Driver = driver,
		RaceTrack = nil, -- number of the track being raced against its NPC
		Results = {}, -- every Result event
		Wins = 0,
		Losses = 0,
		Resets = 0,
	}

	local function rewardTrackWin(trackNumber)
		local id = BoostConfig.WinReward(trackNumber)
		BoostService.Add(player, id, 1)
		player:SetAttribute("LastWinBoost", id)
	end
	local npcMode = options.Npc == true and type(raceRoute.Tracks) == "table" and #raceRoute.Tracks > 0
	local duel = not npcMode and type(options.Duel) == "table" and options.Duel or nil
	-- options.StartTrack (docs/CHECKPOINT_SPEC.md): the NPC run starts here, restarts here after a loss and loops here
	local startIndex = 1
	for i, track in npcMode and raceRoute.Tracks or {} do
		if track.Number == options.StartTrack then
			startIndex = i
		end
	end
	local duelIndex = nil -- index in raceRoute.Tracks of the duel's track
	local race = nil -- { Index, Number, Started, NpcTime }
	local alive = true
	local paid = {} -- pad entry -> already paid this pass
	local pending, sinceCommit = 0, 0
	local runTime = 0
	local dist, lastIndex, sincePublish = 0, 1, 0 -- arc position of the rig, Index it was put at, publish clock
	local routeId = routeName(raceRoute.Path)

	-- The nearer end of segment k to the runner (the IVS driver's nearest-waypoint Index)
	local function nearestIndex(k)
		return dist - arc[k] < arc[k + 1] - dist and k or k + 1
	end
	-- Puts the rig at its arc position, upright and facing along the path. Returns the segment index.
	local function place()
		local feet, k = PathDriver.PoseAt(wps, arc, dist, driver.Index)
		car:PivotTo(rigCFrame(feet))
		return k
	end
	-- What clients interpolate the visible runner from (contract in Server/CarTest/RunnerTests)
	local function publish()
		sincePublish = 0
		car:SetAttribute("RunRoute", routeId)
		car:SetAttribute("RunSpeed", run.Finished and 0 or run.TargetSpeed)
		car:SetAttribute("RunDistance", dist)
	end
	-- Puts the runner `ahead` studs past waypoint `index` (a start, restart or jump; clients snap there).
	local function moveTo(index, ahead)
		dist = math.min(arc[math.clamp(index, 1, n)] + ahead, arc[n])
		driver.Index = nearestIndex(PathDriver.SegmentAt(arc, dist, index))
		driver.Done = false
		lastIndex = driver.Index
		place()
		publish()
	end
	-- Every run starts START_AHEAD studs onto the road of Track 1 (the first waypoint is the road's very edge)
	moveTo(1, RaceService.START_AHEAD)

	local function setUnbanked(amount)
		run.Unbanked = amount
		if typeof(player) == "Instance" then
			player:SetAttribute("Unbanked", amount)
		end
	end
	if npcMode then
		setUnbanked(0)
	end

	local function emit(event)
		if options.OnRaceEvent then
			local ok, err = pcall(options.OnRaceEvent, event)
			if not ok then
				warn("OnRaceEvent: " .. tostring(err))
			end
		end
		if npcRemote and isPlayer(player) then
			npcRemote:FireClient(player, event) -- the owner only: nobody else sees this NPC
		end
	end

	-- Team and stamina (NPC runs only). Server state; replicated as RunSlot and Stamina1..3.
	local staminaMode = npcMode
	local team = GachaService.TeamList(player)
	local seconds = {}
	for slot, id in team do
		local given = options.StaminaSeconds and options.StaminaSeconds[slot]
		seconds[slot] = type(given) == "number" and given > 0 and given or StaminaConfig.Base(CharacterCatalog.Get(id))
	end
	run.Team = team
	run.Slot = 1
	run.Stamina = {}
	local sinceStamina = 0
	local function publishStamina()
		sinceStamina = 0
		for slot = 1, StaminaConfig.TEAM_SIZE do
			local v = run.Stamina[slot]
			player:SetAttribute("Stamina" .. slot, v and math.round(v * 10) / 10 or nil)
		end
	end
	local function runEvent(event)
		if options.OnRunEvent then
			local ok, err = pcall(options.OnRunEvent, event)
			if not ok then
				warn("OnRunEvent: " .. tostring(err))
			end
		end
		if runRemote and isPlayer(player) then
			runRemote:FireClient(player, event)
		end
	end
	local commitStat -- forward declaration (defined below)
	-- Makes `slot` the active runner: EquippedCar follows (CarService re-skins the runner) and its cruise applies at once
	local function setSlot(slot)
		run.Slot = slot
		player:SetAttribute("RunSlot", slot)
		if player:GetAttribute("EquippedCar") ~= team[slot] then
			player:SetAttribute("EquippedCar", team[slot])
		end
		if commitStat then
			commitStat()
			publish()
		end
	end
	local function refill()
		for slot in team do
			run.Stamina[slot] = 100
		end
		setSlot(1)
		publishStamina()
	end

	local function startRace(i)
		local track = raceRoute.Tracks[i]
		local cfg = track.Npc.Config
		local speed = options.NpcSpeeds and options.NpcSpeeds[track.Number] or cfg.Speed
		speed *= require(script.Parent.WeatherService).Multipliers().NpcSpeed
		local profile = track.Npc.Profile
		if speed ~= profile.Speed then
			profile = NpcRacer.Profile(track.Npc.Path, speed)
		end
		race = { Index = i, Number = track.Number, Started = runTime, NpcTime = profile.TotalTime }
		run.RaceTrack = track.Number
		emit({
			Type = "Start",
			Track = track.Number,
			ServerStart = workspace:GetServerTimeNow(),
			Speed = speed,
			Color = cfg.Color,
			Label = cfg.Label,
			Model = cfg.Model,
			BestTime = RaceTimeService.Best(player, track.Number),
		})
	end

	local function backToStart()
		paid = {}
		moveTo(1, RaceService.START_AHEAD)
	end

	-- Starts the run's start track again (Track 1 in place, a checkpoint by a jump that also resets the car).
	local function startAgain()
		if startIndex > 1 then
			run:JumpToTrack(raceRoute.Tracks[startIndex].Number)
		else
			startRace(1)
		end
	end

	-- The player's car reached the finish of the track it is racing on: decide, pay a win, move on.
	local function finishRace()
		local track = raceRoute.Tracks[race.Index]
		local playerTime = runTime - race.Started
		local win = playerTime < race.NpcTime
		local amount = 0
		local bestTime, newBest = RaceTimeService.Best(player, track.Number), false
		if win then
			bestTime, newBest = RaceTimeService.Record(player, track.Number, playerTime)
			QuestService.Progress(player, "Races")
			amount = track.Pad and MoneyService.Quote(player, track.Pad) or 0
			run.BankedTotal += amount
			setUnbanked(run.Unbanked + amount)
			reachTrack(player, track.Number)
			rewardTrackWin(track.Number)
		else
			setUnbanked(0) -- a lost race loses what was not cashed out yet
		end
		local event = {
			Type = "Result",
			Track = track.Number,
			Result = win and "Win" or "Lose",
			PlayerTime = playerTime,
			NpcTime = race.NpcTime,
			Banked = amount,
			Unbanked = run.Unbanked,
			BestTime = bestTime,
			NewBest = newBest,
		}
		table.insert(run.Results, event)
		emit(event)
		local index = race.Index
		race = nil
		if win then
			run.Wins += 1
			if index < #raceRoute.Tracks then
				startRace(index + 1)
			elseif options.Loop then
				run.Laps += 1
				backToStart()
				startAgain()
			else
				run.Laps += 1
				run.Finished = true
			end
		else
			run.Losses += 1
			-- The loser screen is presentation-only; the authoritative car reset is
			-- immediate and names the checkpoint that was lost.
			backToStart()
			run.Resets += 1
			if staminaMode then
				refill() -- a loss reset is a new run (owner 2026-10-30): full stamina from slot 1
			end
			emit({ Type = "Reset", Track = raceRoute.Tracks[startIndex].Number, LostAt = track.Number })
			startAgain()
		end
	end

	local function payPads()
		for _, entry in raceRoute.Pads do
			if entry.Pad and not paid[entry] and driver.Index >= entry.Index then
				paid[entry] = true
				reachTrack(player, entry.Number)
				local amount = MoneyService.Collect(player, entry.Pad)
				if amount > 0 then
					run.Payouts += 1
					run.PaidTotal += amount
					rewardTrackWin(entry.Number)
				end
			end
		end
	end

	-- Distance from the rig's feet to the route: the nearer of the two segments around its segment
	local function pathDeviation()
		local pos = car.PrimaryPart.Position - Vector3.new(0, RunnerFactory.HIP_HEIGHT, 0)
		local best = math.huge
		for k = math.max(driver.Index - 1, 1), math.min(driver.Index, n - 1) do
			local a, b = wps[k], wps[k + 1]
			local ab = b - a
			local t = math.clamp((pos - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
			best = math.min(best, (pos - (a + ab * t)).Magnitude)
		end
		return best
	end

	function commitStat()
		if pending > 0 then
			-- AddSpeed rejects anything above MAX_ADD; carry the rest so a big multi is never lost
			local added = math.min(pending, PlayerData.MAX_ADD)
			pending -= added
			local newStat = PlayerData.AddSpeed(player, added)
			if newStat then
				run.Gained += added
			end
		end
		stat = PlayerData.SpeedStat(player) -- the source of truth (also picks up a load finishing)
		run.TargetSpeed = RaceConfig.SpeedFor(stat, GachaService.CruiseMultis(player))
		driver.TargetSpeed = run.TargetSpeed
	end

	-- The equipped character changed mid-run (CarService.ApplyCharacter): its cruise applies at once, clients hear now
	function run:Refresh()
		commitStat()
		publish()
	end

	if staminaMode then
		refill() -- every run starts with full stamina at slot 1
	end
	if npcMode and startIndex == 1 then
		startRace(1)
	end

	-- Admin /tp: puts the car at the start of track `number` (START_AHEAD in, in the lane, upright, facing along the
	-- path). Pads of earlier tracks count as paid for this pass, so a jump never pays; in NPC mode the race in
	-- progress is dropped (no Result) and that track's race starts. Returns false (nothing changes) for a bad number.
	function run:JumpToTrack(number)
		if not alive or type(number) ~= "number" or type(raceRoute.Tracks) ~= "table" then
			return false
		end
		local index = nil
		for i, track in raceRoute.Tracks do
			if track.Number == number then
				index = i
				break
			end
		end
		if not index then
			return false
		end
		local s = math.clamp(raceRoute.Tracks[index].StartIndex, 1, n - 1)
		run.Finished = false
		moveTo(s, RaceService.START_AHEAD)
		paid = {}
		for _, entry in raceRoute.Pads do
			if entry.Index < s then
				paid[entry] = true
			end
		end
		if npcMode then
			race = nil
			startRace(index)
		end
		return true
	end

	if duel then
		for i, track in raceRoute.Tracks or {} do
			if track.Number == duel.Track then
				duelIndex = i
			end
		end
		run:JumpToTrack(duel.Track)
	end
	if npcMode and startIndex > 1 then
		run:JumpToTrack(raceRoute.Tracks[startIndex].Number)
	end

	local lastTick = os.clock()
	run.Connection = RunService.PreSimulation:Connect(function()
		if not car.Parent then
			run:Destroy()
			return
		end
		-- Rail, race clock and gain run on wall-clock time: after a server hitch the engine's step dt is capped
		local now = os.clock()
		local railDt = now - lastTick
		lastTick = now
		-- The rail: a test or admin that set driver.Index moves the runner there; then exactly cruise x time along it
		if driver.Index ~= lastIndex then
			dist = arc[math.clamp(driver.Index, 1, n)]
		end
		if not run.Finished then
			dist = math.min(dist + run.TargetSpeed * railDt, arc[n])
		end
		local k = place()
		driver.Done = dist >= arc[n]
		driver.Index = driver.Done and n or nearestIndex(k)
		lastIndex = driver.Index
		run.MinUpY = math.min(run.MinUpY, car.PrimaryPart.CFrame.UpVector.Y)
		runTime += railDt
		if npcMode then
			if race then
				local track = raceRoute.Tracks[race.Index]
				local last = race.Index == #raceRoute.Tracks
				if driver.Index >= track.FinishIndex or (last and driver.Done) then
					finishRace() -- decided before this tick's drain: a loss on the same tick wins (spec)
				end
			end
			if staminaMode and not run.Finished then
				local slot = run.Slot
				run.Stamina[slot] -= 100 / seconds[slot] * railDt
				sinceStamina += railDt
				if run.Stamina[slot] <= 0 then
					run.Stamina[slot] = 0
					if slot < #team then
						setSlot(slot + 1)
						publishStamina()
						runEvent({ Kind = "Swap", From = team[slot], To = team[slot + 1], Slot = slot + 1 })
					else
						publishStamina()
						local banked = run:CashOut()
						runEvent({ Kind = "Exhausted", Banked = banked })
						run:Destroy()
						if isPlayer(player) then
							task.defer(function()
								local CarService = require(script.Parent.CarService)
								if CarService.GetRun(player) == run then
									CarService.SetAutoRace(player, false) -- back on foot at the walk spawn
								end
							end)
						end
						return
					end
				elseif sinceStamina >= RaceService.PUBLISH_INTERVAL then
					publishStamina()
				end
			end
		elseif duel then
			local track = duelIndex and raceRoute.Tracks[duelIndex]
			local last = duelIndex == #raceRoute.Tracks -- the driver stops just before the route's last waypoint
			if track and not run.Finished and (driver.Index >= track.FinishIndex or (last and driver.Done)) then
				run.Finished = true
				if duel.OnFinish then
					local ok, err = pcall(duel.OnFinish, run, runTime)
					if not ok then
						warn("Duel OnFinish: " .. tostring(err))
					end
				end
			end
		else
			payPads()
		end
		if (runTime > DEVIATION_GRACE or runTime * run.TargetSpeed > DEVIATION_GRACE_STUDS) and not run.Finished then -- past the last finish there is no path to follow
			run.MaxPathDeviation = math.max(run.MaxPathDeviation, pathDeviation())
		end

		-- Passive gain is a flat rate x permanent Speed-gain upgrades and rebirths; neither the car,
		-- cruise speed, Speed stat, nor temporary boosts changes it.
		local gainMulti = GachaService.SpeedMulti(player)
		pending += RaceConfig.GainPerSecond(stat, run.Finished and 0 or run.TargetSpeed) * gainMulti * railDt
		LevelService.Tick(player, railDt, gainMulti)
		sinceCommit += railDt
		if sinceCommit >= RaceService.COMMIT_INTERVAL then
			sinceCommit = 0
			commitStat()
		end

		if not npcMode and not duel and driver.Done and not run.Finished then
			run.Finished = true
			run.Laps += 1
			if options.Loop then
				run.Finished = false
				backToStart()
			end
		end

		sincePublish += railDt
		if sincePublish >= RaceService.PUBLISH_INTERVAL or run.Finished ~= (car:GetAttribute("RunSpeed") == 0) then
			publish()
		end
	end)

	-- Pays the bank into leaderstats.Money and empties it. Returns the amount paid (0 if none).
	function run:CashOut()
		local amount = run.Unbanked
		if amount <= 0 then
			return 0
		end
		setUnbanked(0)
		if MoneyService.Award(player, amount) == nil then
			return 0
		end
		run.Payouts += 1
		run.PaidTotal += amount
		return amount
	end

	-- Stops the run. The Speed gained since the last commit is committed first, so stopping never loses stat, and
	-- the bank is paid out, so stopping (or dying, or leaving) never loses won money.
	function run:Destroy()
		if alive then
			alive = false
			self:CashOut()
			if npcMode then
				emit({ Type = "Stop" })
			end
		end
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
			commitStat()
		end
	end
	return run
end

RaceService.SetCarGroup = setCarGroup

-- Where a runner (its Torso) starts track `number` of the live route (START_AHEAD in, in the lane, facing along the path), or nil.
function RaceService.TrackStartCFrame(number)
	for _, track in route and route.Tracks or {} do
		if track.Number == number then
			local wps = route.Path.WorldWaypoints
			local arc = arcOf(route.Path)
			local s = math.clamp(track.StartIndex, 1, #wps - 1)
			return rigCFrame((PathDriver.PoseAt(wps, arc, arc[s] + RaceService.START_AHEAD, s)))
		end
	end
	return nil
end

-- Called by CarService once the player's car exists. Returns the run, or nil if there is no route
-- (then the car is driven manually).
function RaceService.Attach(player, car)
	if not route then
		return nil
	end
	setCarGroup(car)
	return RaceService.NewRun(
		car,
		route,
		player,
		{ Loop = true, Npc = true, StartTrack = RaceService.StartTrackFor(player) }
	)
end

-- The track `player`'s next NPC run starts on: the saved Checkpoint, clamped to the beaten tracks.
function RaceService.StartTrackFor(player)
	local count = route and route.Tracks and #route.Tracks or 0
	return CheckpointConfig.Effective(player:GetAttribute("Checkpoint"), player:GetAttribute("BestTrack"), count)
end

function RaceService.Start(newRoute)
	route = newRoute
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	runRemote = remotes:FindFirstChild("RunEvent")
	if not runRemote then
		runRemote = Instance.new("RemoteEvent")
		runRemote.Name = "RunEvent"
		runRemote.Parent = remotes
	end
	npcRemote = remotes:FindFirstChild("NpcRace")
	if not npcRemote then
		npcRemote = Instance.new("RemoteEvent")
		npcRemote.Name = "NpcRace"
		npcRemote.Parent = remotes
	end
	pcall(function()
		PhysicsService:RegisterCollisionGroup(RUNNER_GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(RUNNER_GROUP, RUNNER_GROUP, false) -- players pass through each other
	end)
end

return RaceService
