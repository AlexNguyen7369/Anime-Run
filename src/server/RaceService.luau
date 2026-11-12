--!nonstrict
-- Auto race. The server moves every player's runner (the anchored rig from Shared/RunnerFactory) along the chain of
-- tracks on a rail: its arc distance grows by exactly the cruise speed every frame (no acceleration, no corner
-- slowing; design doc, owner 2026-10-20), and the rig is put at that point of the path, upright and facing along it
-- (docs/WORLD_REDESIGN_SPEC.md section 2). No physics forces. The rig is the authoritative pose; for smooth drawing
-- the run publishes RunRoute / RunDistance / RunSpeed on the model and every client interpolates the visible runner
-- (Client/RunnerView; contract in Server/CarTest/RunnerTests). The cruise speed is the character's fixed cruise
-- (GachaService.Cruise, design doc 4.13), set at run start and when the character changes; there is no Speed stat.
-- When the runner passes a winnings pad the pad pays the player (MoneyService.Collect); the rig never has to touch
-- the pad. After the last finish the runner is put back at the start of Track 1 and keeps running.
--
-- NPC races (options.Npc, on for players): every track is a race against that track's NPC (Shared/NpcConfig,
-- Shared/NpcRacer). If the NPC reaches a checkpoint first, the player loses at that checkpoint and is immediately
-- teleported back to the start of the run's checkpoint track (design doc 4.15); the client is told which track was
-- lost. Tracks won past the checkpoint track in the same run pay the checkpoint bonus (CheckpointConfig.Bonus).
-- Checkpoint payouts (owner 2026-11-10, design doc 3 steps 4-5; no run bank): winning a track pays its pad's value
-- (MoneyService.Quote x checkpoint bonus) straight into Money at that track's finish, and RunEvent
-- { Kind = "CashOut", Amount, Track } tells the owner for the "Cashed out +$X" notice. A loss keeps earlier payouts;
-- stop, death and leaving pay nothing more. Team and stamina (docs/TEAM_AND_STAMINA_SPEC.md): an NPC run reads the
-- player's Team at start. The active runner's stamina drains 100 / seconds percent per second; at 0 the next slot tags
-- in at its own cruise; when the last one is empty the current track's per-distance share is paid into Money, the run
-- stops and the player goes back on foot. A loss reset refills stamina from slot 1 at the checkpoint.
-- Race events go to the owning player only (Remotes.NpcRace:FireClient), whose client draws the NPC.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestService = require(script.Parent.QuestService)
local PathDriver = require(Shared.PathDriver)
local RunnerFactory = require(Shared.RunnerFactory)
local NpcConfig = require(Shared.NpcConfig)
local NpcRacer = require(Shared.NpcRacer)
local CheckpointConfig = require(Shared.CheckpointConfig)
local GemConfig = require(Shared.GemConfig)
local CharacterCatalog = require(Shared.CharacterCatalog)
local StaminaConfig = require(Shared.StaminaConfig)
local BossEventConfig = require(Shared.BossEventConfig)
local PowerUpConfig = require(Shared.PowerUpConfig)
local MoneyService = require(script.Parent.MoneyService)
local PlayerData = require(script.Parent.PlayerData)
local GachaService = require(script.Parent.GachaService)
local SidekickService = require(script.Parent.SidekickService)
local RelicService = require(script.Parent.RelicService)
local UpgradeService = require(script.Parent.UpgradeService)
local BoostConfig = require(Shared.BoostConfig)
local BoostService = require(script.Parent.BoostService)
local RaceTimeService = require(script.Parent.RaceTimeService)
local TrackBuild = require(script.Parent.TrackBuild)

local RaceService = {}

RaceService.START_AHEAD = 5 -- studs along the path from the road's first edge where a run starts
RaceService.PUBLISH_INTERVAL = 0.1 -- s between RunDistance / RunSpeed updates (contract: at most 0.25 s)
local DEVIATION_GRACE = 3 -- seconds after the start before path deviation is measured
local DEVIATION_GRACE_STUDS = 30 -- ...or this far along it: a MAX_CRUISE runner covers that in a frame or two

local RUNNER_GROUP = "Runners"

local route = nil
local npcRemote = nil -- Remotes.NpcRace, created by Start
local SHOWDOWN_SECONDS = 2 -- proposed: a little over Client/EnemyShowdown's VS banner
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
	folder:SetAttribute("Closed", path.Closed == true or nil) -- a lap route: RunnerView lets its distance keep growing
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

-- Builds the route's folder now, so a later SwitchRoute never names one a client has not received.
RaceService.PrepareRoute = routeName

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
--          on track n, pays no pad or checkpoint, and is Finished (OnFinish called once) at that track's finish.
--          { Boss = true, Team = { ids } } is a boss event run (design doc 4.37, docs/BOSS_EVENT_SPEC.md): real stamina on the
--          closed lane route, no NPC, no pads, no checkpoint payout. run.Line: slots still running, all draining at once.
--          At an empty line: run.Waiting, then the full team refills.
--          { PowerUps = true } (NPC mode; Attach sets it) rolls each track's power-ups (design doc 4.44): run.PowerUps.
function RaceService.NewRun(car, raceRoute, player, options)
	options = options or {}
	car:SetAttribute("AutoRace", true)

	PlayerData.Setup(player)
	local wps = raceRoute.Path.WorldWaypoints
	local n = #wps
	local arc = arcOf(raceRoute.Path)
	-- Index: the waypoint nearest the runner along the path (n once past the last one); Done past the end.
	-- Tests may set Index; the rail then moves the runner to that waypoint.
	local driver = { Index = 1, Done = false, TargetSpeed = GachaService.Cruise(player) }
	local run = {
		Car = car,
		TargetSpeed = driver.TargetSpeed,
		Finished = false,
		Payouts = 0,
		PaidTotal = 0,
		Gained = 0, -- kept for old callers: there is no Speed stat to gain
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
		Waiting = false, -- boss run: the exhausted team's wait before its refill
		Holding = nil, -- the unbuilt track the runner waits on (design doc 4.25), nil when free
	}

	run.PowerUps = {} -- the current track's set: { { Id, Kind, Dist, Taken } }
	run.SpeedLeft = 0 -- seconds of the Speed power-up's boost left

	local function rewardTrackWin(trackNumber)
		local id = BoostConfig.WinReward(trackNumber)
		BoostService.Add(player, id, 1)
		player:SetAttribute("LastWinBoost", id)
	end
	local npcMode = options.Npc == true and type(raceRoute.Tracks) == "table" and #raceRoute.Tracks > 0
	local duel = not npcMode and type(options.Duel) == "table" and options.Duel or nil
	local boss = options.Boss == true
	local closed = raceRoute.Path.Closed == true -- dist keeps growing and wraps around the route
	local waitLeft = 0 -- boss run: seconds of run.Waiting left
	-- options.StartTrack (design doc 4.15): the NPC run starts here, restarts here after a loss and loops here
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
	local runTime = 0
	local dist, lastIndex, sincePublish = 0, 1, 0 -- arc position of the rig, Index it was put at, publish clock
	local routeId = routeName(raceRoute.Path)

	-- The nearer end of segment k to the runner (the IVS driver's nearest-waypoint Index)
	local function nearestIndex(k)
		local at = closed and dist % arc[n] or dist
		return at - arc[k] < arc[k + 1] - at and k or k + 1
	end
	-- Puts the rig at its arc position, upright and facing along the path. Returns the segment index.
	local function place()
		local feet, k = PathDriver.PoseAt(wps, arc, dist, driver.Index, closed)
		car:PivotTo(rigCFrame(feet))
		return k
	end
	-- Track the runner is on: the first track whose finish pad is still ahead (the last past the end). Clients pick the
	-- biome from it while racing (design doc 4.18), never from the nearest centre line.
	local function trackAt()
		local number, best = nil, math.huge
		local pads = raceRoute.Pads or {}
		for _, entry in pads do
			local at = arc[entry.Index] or 0
			if at > dist and at < best then
				number, best = entry.Number, at
			end
		end
		return number or (pads[#pads] and pads[#pads].Number) -- a route without pads (test fixtures) has no track
	end
	-- What clients interpolate the visible runner from (contract in Server/CarTest/RunnerTests)
	local function publish()
		sincePublish = 0
		car:SetAttribute("RunRoute", routeId)
		car:SetAttribute("RunSpeed", (run.Finished or run.Waiting or run.Holding ~= nil) and 0 or run.TargetSpeed)
		car:SetAttribute("RunDistance", dist)
		car:SetAttribute("RunTrack", trackAt())
	end
	-- Design doc 4.25: wait for unbuilt track `number` (nil releases); `resume` runs once it is built. The rail, stamina
	-- and race clock stand still meanwhile; RunHold drives the client's "Loading next track" label.
	local holdResume = nil
	local function hold(number, resume)
		run.Holding, holdResume = number, resume
		car:SetAttribute("RunHold", number)
		publish()
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

	-- Team and stamina (NPC and boss runs). Server state; replicated as RunSlot and Stamina1..3.
	local staminaMode = npcMode or boss
	local team = boss and options.Team or GachaService.TeamList(player) -- an event's team never touches the Team attribute
	local seconds = {}
	-- fixed for the whole run (a potion that expires mid-run changes nothing); a loss reset (new run) reads it again
	local function snapshotStamina()
		local staminaMulti = typeof(player) == "Instance" and GachaService.StaminaMulti(player, boss and team or nil)
			or 1
		for slot, id in team do
			local given = options.StaminaSeconds and options.StaminaSeconds[slot]
			seconds[slot] = type(given) == "number" and given > 0 and given
				or StaminaConfig.Seconds(
					CharacterCatalog.Get(id),
					staminaMulti
						* (
							typeof(player) == "Instance"
								and SidekickService.StaminaMulti(player, id) * RelicService.Multi(player, id, "Stamina")
							or 1
						)
				)
			if staminaMode and typeof(player) == "Instance" then -- cleared with the other stamina attributes at run end
				player:SetAttribute("RunSeconds" .. slot, seconds[slot]) -- the team row's seconds left
			end
		end
	end
	snapshotStamina()
	run.Team = team
	run.Slot = 1
	run.Stamina = {}
	local sinceStamina = 0
	local function publishStamina()
		sinceStamina = 0
		if typeof(player) ~= "Instance" then
			return
		end
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
	-- Pays `amount` straight into Money (owner 2026-11-10: no run bank) and tells the owner for the "Cashed out +$X"
	-- notice by the Money counter. Returns what was paid (0 if nothing).
	local function payOut(amount, trackNumber)
		if amount <= 0 or MoneyService.Award(player, amount) == nil then
			return 0
		end
		amount = math.floor(amount)
		run.Payouts += 1
		run.PaidTotal += amount
		runEvent({ Kind = "CashOut", Amount = amount, Track = trackNumber })
		return amount
	end
	local showdownToken = 0
	local setCruise, payShare, snapshotCruise -- forward declarations (defined below)
	-- Makes `slot` the active runner: EquippedCar follows (CarService re-skins the runner) and its cruise applies at once
	local function setSlot(slot)
		run.Slot = slot
		if typeof(player) == "Instance" then
			player:SetAttribute("RunSlot", slot)
			if player:GetAttribute("EquippedCar") ~= team[slot] then
				player:SetAttribute("EquippedCar", team[slot])
			end
		end
		if setCruise then
			setCruise()
			publish()
		end
	end
	local function publishLine()
		if typeof(player) == "Instance" then
			player:SetAttribute("BossLine", table.concat(run.Line, ","))
		end
	end
	local function refill()
		if snapshotCruise then
			snapshotCruise() -- a loss reset starts a new run
			snapshotStamina()
		end
		for slot in team do
			run.Stamina[slot] = 100
		end
		run.SpeedLeft = 0
		if typeof(player) == "Instance" then
			player:SetAttribute("PowerSpeedUntil", nil)
		end
		if boss then
			run.Line = {}
			for slot in team do
				table.insert(run.Line, slot)
			end
			publishLine()
		end
		setSlot(1)
		publishStamina()
	end

	local function startRace(i)
		local track = raceRoute.Tracks[i]
		if not TrackBuild.IsBuilt(track.Number) then
			hold(track.Number, function()
				startRace(i)
			end)
			return
		end
		local cfg = track.Npc.Config
		local speed = options.NpcSpeeds and options.NpcSpeeds[track.Number] or cfg.Speed
		speed *= require(script.Parent.WeatherService).Multipliers().NpcSpeed
		local profile = track.Npc.Profile
		if speed ~= profile.Speed then
			profile = NpcRacer.Profile(track.Npc.Path, speed)
		end
		race = { Index = i, Number = track.Number, Started = runTime, NpcTime = profile.TotalTime }
		run.RaceTrack = track.Number
		if options.PowerUps then
			local from = arc[math.clamp(track.StartIndex, 1, n)]
			-- fresh per player and per track start: nobody else sees this set (design doc 4.44)
			run.PowerUps = PowerUpConfig.Roll(from, arc[math.clamp(track.FinishIndex, 1, n)] - from)
			runEvent({ Kind = "PowerUps", Track = track.Number, Route = routeId, List = run.PowerUps })
		end
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
		if isPlayer(player) then
			-- The VS banner's moment (design doc 4.28), not the race: Client/SidekickTutorial may show during a normal run.
			showdownToken += 1
			local mine = showdownToken
			player:SetAttribute("ShowdownActive", true)
			task.delay(SHOWDOWN_SECONDS, function()
				if showdownToken == mine then
					player:SetAttribute("ShowdownActive", nil)
				end
			end)
		end
	end

	local function backToStart()
		paid = {}
		moveTo(1, RaceService.START_AHEAD)
	end

	-- Starts the run's start track again (Track 1 in place, a checkpoint by a jump that also resets the runner).
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
		local amount, bonus = 0, 1
		local bestTime, newBest = RaceTimeService.Best(player, track.Number), false
		if win then
			bestTime, newBest = RaceTimeService.Record(player, track.Number, playerTime)
			QuestService.Progress(player, "Races")
			bonus = CheckpointConfig.Bonus(race.Index - startIndex) -- tracks past the checkpoint (design doc 4.15)
			amount = payOut(track.Pad and math.floor(MoneyService.Quote(player, track.Pad) * bonus) or 0, track.Number)
			-- Gems are paid here, not in rewardTrackWin: payPads shares it and beats no NPC (design doc 4.35).
			local firstClear = track.Number > (player:GetAttribute("BestTrack") or 0)
			reachTrack(player, track.Number)
			rewardTrackWin(track.Number)
			MoneyService.AddGems(
				player,
				GemConfig.TrackWin(track.Number) + (firstClear and GemConfig.FirstClear(track.Number) or 0)
			)
		end -- a loss pays nothing and keeps earlier payouts (owner 2026-11-10)
		local event = {
			Type = "Result",
			Track = track.Number,
			Result = win and "Win" or "Lose",
			PlayerTime = playerTime,
			NpcTime = race.NpcTime,
			Bonus = bonus,
			Banked = amount, -- paid into Money at this finish (name kept for old readers)
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

	-- Each team slot's cruise is fixed when the run starts (design doc 4.13 / 4.19): swaps read this snapshot, so a
	-- potion or item change mid-run never reaches later slots. A loss reset (new run) snapshots again.
	local fixedCruise = {}
	function snapshotCruise()
		table.clear(fixedCruise)
		if staminaMode and typeof(player) == "Instance" then
			for slot, id in team do
				fixedCruise[slot] = GachaService.CruiseFor(player, id, slot, boss and team or nil)
			end
		end
	end
	snapshotCruise()

	-- The run's fixed cruise (design doc 4.13), shown on the HUD as the player attribute Cruise
	function setCruise()
		local id = typeof(player) == "Instance" and player:GetAttribute("EquippedCar")
		-- a character equipped outside the team mid-run (admin /kami) runs at its own cruise
		local cruise = (id == team[run.Slot] and fixedCruise[run.Slot]) or GachaService.Cruise(player, run.Slot)
		-- options.MaxSpeed caps the travel only (The Elf Mage's small ring, BOSS_EVENT_SPEC "Run speed cap"); the HUD keeps the cruise.
		-- The Speed power-up is applied after the MAX_CRUISE cap: it may pass it (owner 2026-11-11); boss runs roll none.
		run.TargetSpeed = math.min(cruise, options.MaxSpeed or math.huge)
			* ((run.SpeedLeft or 0) > 0 and PowerUpConfig.SPEED_MULTI or 1)
		driver.TargetSpeed = run.TargetSpeed
		if typeof(player) == "Instance" then
			player:SetAttribute("Cruise", cruise) -- the character's own cruise; the boost shows on the team row
		end
	end
	setCruise()

	-- The equipped character changed mid-run (CarService.ApplyCharacter): its cruise applies at once, clients hear now
	function run:Refresh()
		setCruise()
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
		if run.Holding then
			hold(nil) -- a jump replaces the wait; an unbuilt target holds again below
		end
		moveTo(s, RaceService.START_AHEAD)
		paid = {}
		for _, entry in raceRoute.Pads do
			if entry.Index < s then
				paid[entry] = true
			end
		end
		if npcMode then
			race = nil
			startRace(index) -- holds at this gate while the track is unbuilt
		elseif not TrackBuild.IsBuilt(number) then
			hold(number, function() end)
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

	-- Exhaustion share (owner 2026-11-01, design doc 4.3): the track being raced when the team tires pays its pad cash
	-- x covered / track length (x the checkpoint bonus, design doc 4.15) straight into Money (owner 2026-11-10).
	function payShare()
		local track = race and raceRoute.Tracks[race.Index]
		if not (track and track.Pad) then
			return 0
		end
		local from, to = arc[math.clamp(track.StartIndex, 1, n)], arc[math.clamp(track.FinishIndex, 1, n)]
		local length = to - from
		if length <= 0 then
			return 0
		end
		local share = math.clamp((dist - from) / length, 0, 1) * StaminaConfig.EXHAUSTION_SHARE
		local amount =
			math.floor(MoneyService.Quote(player, track.Pad) * share * CheckpointConfig.Bonus(race.Index - startIndex))
		return payOut(amount, track.Number)
	end

	local lastTick = os.clock()
	run.Connection = RunService.PreSimulation:Connect(function()
		if not car.Parent then
			run:Destroy()
			return
		end
		-- Rail and race clock run on wall-clock time: after a server hitch the engine's step dt is capped
		local now = os.clock()
		local railDt = now - lastTick
		lastTick = now
		if run.Holding and TrackBuild.IsBuilt(run.Holding) then
			local resume = holdResume
			hold(nil)
			resume()
		end
		-- The rail: a test or admin that set driver.Index moves the runner there; then exactly cruise x time along it
		if driver.Index ~= lastIndex then
			dist = arc[math.clamp(driver.Index, 1, n)]
		end
		if not run.Finished and not run.Waiting and not run.Holding then
			local moved = dist + run.TargetSpeed * railDt
			dist = closed and moved or math.min(moved, arc[n])
		end
		local k = place()
		if run.SpeedLeft > 0 and not run.Holding then
			run.SpeedLeft -= railDt
			if run.SpeedLeft <= 0 then
				run.SpeedLeft = 0
				if typeof(player) == "Instance" then
					player:SetAttribute("PowerSpeedUntil", nil)
				end
				setCruise()
				publish()
			end
		end
		if race and not run.Holding then
			for _, p in run.PowerUps do
				if not p.Taken and dist >= p.Dist then
					p.Taken = true
					if p.Kind == "Speed" then
						run.SpeedLeft = PowerUpConfig.SPEED_SECONDS -- a second one resets the timer, no stacking
						if typeof(player) == "Instance" then
							-- shortcut: a track-loading hold pauses the boost but not this clock, fine while holds stay rare
							player:SetAttribute("PowerSpeedUntil", workspace:GetServerTimeNow() + run.SpeedLeft)
						end
						setCruise()
						publish()
					elseif staminaMode and seconds[run.Slot] then
						-- no clamp at 100: the extra seconds drain first, the bar stays full (owner 2026-11-11)
						run.Stamina[run.Slot] += PowerUpConfig.StaminaSeconds(race.Number) * 100 / seconds[run.Slot]
						publishStamina()
					end
					runEvent({ Kind = "PowerUpTaken", Id = p.Id, Type = p.Kind, Track = race.Number })
				end
			end
		end
		driver.Done = not closed and dist >= arc[n]
		driver.Index = driver.Done and n or nearestIndex(k)
		lastIndex = driver.Index
		run.MinUpY = math.min(run.MinUpY, car.PrimaryPart.CFrame.UpVector.Y)
		if not run.Holding then
			runTime += railDt -- a duel's or race's time never counts the wait
		end
		if npcMode and race then
			local track = raceRoute.Tracks[race.Index]
			local last = race.Index == #raceRoute.Tracks
			if driver.Index >= track.FinishIndex or (last and driver.Done) then
				finishRace() -- decided before this tick's drain: a loss on the same tick wins (spec)
			end
		end
		if run.Waiting then
			waitLeft -= railDt
			if waitLeft <= 0 then
				run.Waiting = false
				refill()
				runEvent({ Kind = "BossRefill" })
			end
		elseif boss and not run.Finished then
			sinceStamina += railDt
			-- Every slot, each frame: a charge from BossEventService can empty any of them between frames.
			local gone = {}
			for i = #run.Line, 1, -1 do
				local slot = run.Line[i]
				run.Stamina[slot] -= 100 / seconds[slot] * railDt
				if run.Stamina[slot] <= 0 then
					run.Stamina[slot] = 0
					table.remove(run.Line, i)
					table.insert(gone, 1, slot)
				end
			end
			if #gone > 0 then
				local front = run.Line[1]
				if front and front ~= run.Slot then
					setSlot(front)
				end
				publishLine()
				publishStamina()
				if not front then
					run.Waiting, waitLeft = true, BossEventConfig.RefillWaitSeconds
					publish()
				end
				for _, slot in gone do
					runEvent({ Kind = "BossGone", Slot = slot })
				end
				if not front then
					runEvent({ Kind = "BossWait" })
				end
			elseif sinceStamina >= RaceService.PUBLISH_INTERVAL then
				publishStamina()
			end
		elseif staminaMode and not run.Finished and not run.Holding then
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
					runEvent({ Kind = "Exhausted", Banked = payShare() }) -- Banked: the share just paid
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
		if duel then
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
		elseif not npcMode and not boss then
			payPads()
		end
		if (runTime > DEVIATION_GRACE or runTime * run.TargetSpeed > DEVIATION_GRACE_STUDS) and not run.Finished then -- past the last finish there is no path to follow
			run.MaxPathDeviation = math.max(run.MaxPathDeviation, pathDeviation())
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
		if
			sincePublish >= RaceService.PUBLISH_INTERVAL
			or (run.Finished or run.Waiting or run.Holding ~= nil) ~= (car:GetAttribute("RunSpeed") == 0)
		then
			publish()
		end
	end)

	-- Boss run: moves to another lane of the ring at the same lap angle (design doc 4.37). Lanes have the same waypoint count, so
	-- driver.Index holds.
	function run:SwitchRoute(path)
		local newArc = arcOf(path)
		dist *= newArc[n] / arc[n]
		wps, arc, routeId = path.WorldWaypoints, newArc, routeName(path)
		place()
		publish()
	end

	-- Boss run: ends the wait `seconds` from now, whatever was left of it (BOSS_EVENT_SPEC "Phase 2"). Its refill is the wait's own.
	function run:ReviveAt(seconds)
		if run.Waiting then
			waitLeft = seconds
		end
	end

	-- Stops the run. Nothing is left to pay: every checkpoint paid at its finish (owner 2026-11-10).
	function run:Destroy()
		if alive then
			alive = false
			car:SetAttribute("RunTrack", nil) -- walking again: clients go back to ZoneAt
			car:SetAttribute("RunHold", nil)
			if staminaMode and typeof(player) == "Instance" then
				player:SetAttribute("RunSlot", nil) -- walking: the stamina bar hides, effects go back to slot 1
				player:SetAttribute("PowerSpeedUntil", nil)
				player:SetAttribute("BossLine", nil)
				for slot = 1, StaminaConfig.TEAM_SIZE do
					player:SetAttribute("Stamina" .. slot, nil)
					player:SetAttribute("RunSeconds" .. slot, nil)
				end
			end
			if npcMode then
				emit({ Type = "Stop" })
			end
		end
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
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

-- Where a runner (its Torso) starts a route of its own, such as a boss lane.
function RaceService.RouteStartCFrame(path)
	local closed = path.Closed == true
	return rigCFrame((PathDriver.PoseAt(path.WorldWaypoints, arcOf(path), RaceService.START_AHEAD, 1, closed)))
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
		{ Loop = true, Npc = true, PowerUps = true, StartTrack = RaceService.StartTrackFor(player) }
	)
end

-- The track `player`'s next NPC run starts on: the saved Checkpoint, clamped to the open tracks (design doc 4.15).
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
