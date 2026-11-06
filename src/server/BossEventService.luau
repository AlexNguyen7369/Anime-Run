--!nonstrict
-- Boss events (design doc 4.37, docs/BOSS_EVENT_SPEC.md): one event per server, every 30 minutes on a fixed grid (the
-- WeatherService shape), or at once for a paid start. The server decides every hit; no remote reaches the damage. Contract:
-- Server/CarTest/BossEventTests.
-- Clients read ReplicatedStorage attributes BossEventPhase ("Prep" or "Fight", nil when idle), BossEventStart (server time),
-- BossEventHp, BossEventMaxHp and BossStatus (JSON list of { Id, EndsAt in server time }, nil when empty), and the player attributes
-- BossEvent (true while in the event), BossTeamDamage (TeamDamage, nil outside the event) and BossWaitEndsAt (server time the
-- exhausted team revives, nil otherwise). They call the RemoteFunctions
-- Remotes.BossEventTeleport(), Remotes.BossEventSetTeam(ids) and Remotes.BossEventLeave(); each returns ok, reason.
-- Remotes.BossEventChat carries the server-wide spawn message and each member's move lines to Client/BossEventChat.
-- Remotes.BossHits carries each hit, batched, to the players in the event: { UserId, SidekickId, Damage }, for Client/SidekickAttackView.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.BossArenaConfig)
local CharacterCatalog = require(Shared.CharacterCatalog)
local Cfg = require(Shared.BossEventConfig)
local Poses = require(Shared.BossRagaPoses)
local StaminaConfig = require(Shared.StaminaConfig)
local CarService = require(script.Parent.CarService)
local DuelService = require(script.Parent.DuelService)
local GachaService = require(script.Parent.GachaService)
local PlayerData = require(script.Parent.PlayerData)
local RaceService = require(script.Parent.RaceService)
local RelicService = require(script.Parent.RelicService)
local SidekickService = require(script.Parent.SidekickService)

local BossEventService = {}

local REMOTE_COOLDOWN = 0.25
local HIT_BATCH_SECONDS = 0.25 -- at most 4 batches of hits a second to a player (docs/BOSS_EVENT_SPEC.md)
local DAMAGE_EPSILON = 1e-6 -- exactly the minimum share still earns the reward, whatever the float sum
local TIME_EPSILON = 1e-6 -- s: a clock a float's hair before a schedule moment is on it
local SCAN_STEP = 0.01 -- s: shorter than any row of the schedule
local STATUSES = {
	{ Id = "Shouted", Event = "Roar", Seconds = Cfg.ShoutSeconds, Cut = Cfg.ShoutDamageCut },
	{ Id = "Adapted", Event = "WheelClick", Seconds = Cfg.AdaptedSeconds, Cut = Cfg.AdaptedCut },
}

local clock = nil
local event = nil -- { StartAt, Source, Phase, Hp, MaxHp, Spawned, IntroDone, Members = { [player] = member } }
local nextAt = math.huge
local lastEnd = nil
local chatRemote = nil
local hitsRemote = nil
local started = false
local lastRequest = setmetatable({}, { __mode = "k" })
local rewardRng = Random.new()

local function now()
	return clock and clock() or workspace:GetServerTimeNow()
end

local function safely(fn, ...)
	local ok, result = pcall(fn, ...)
	if not ok then
		warn("BossEventService: " .. tostring(result))
	end
	return ok, result
end

local function publish()
	ReplicatedStorage:SetAttribute("BossEventPhase", event and event.Phase or nil)
	ReplicatedStorage:SetAttribute("BossEventStart", event and event.StartAt or nil)
	ReplicatedStorage:SetAttribute("BossEventHp", event and event.Hp or nil)
	ReplicatedStorage:SetAttribute("BossEventMaxHp", event and event.MaxHp or nil)
	if not event then
		ReplicatedStorage:SetAttribute("BossStatus", nil)
	end
end

-- Event name -> its moments in one schedule cycle, seconds after the intro's end. Read off the shared schedule, so every client's
-- animation and the server agree. Rounded to the 3 places the schedule's times are written in.
local moments = {}
do
	for _, move in Poses.Moves do
		for _, moveEvent in move.Events do
			moments[moveEvent.Name] = {}
		end
	end
	local lastMove, lastLocal = nil, 0
	for k = 0, math.ceil(Poses.CycleSeconds / SCAN_STEP) - 1 do
		local since = k * SCAN_STEP
		local move, localTime = Poses.Schedule(-Cfg.IntroSeconds, since)
		if move ~= lastMove or localTime < lastLocal then
			for _, moveEvent in Poses.Moves[move].Events do
				local at = since - localTime + moveEvent.Time
				table.insert(moments[moveEvent.Name], math.round(at * 1000) / 1000)
			end
		end
		lastMove, lastLocal = move, localTime
	end
end

-- t in seconds since the spawn -> whole cycles past the intro's end, and seconds into this cycle. Nil before the intro's end.
local function cycleAt(t)
	local since = t + TIME_EPSILON - Cfg.IntroSeconds
	if since < 0 then
		return nil
	end
	local cycles = math.floor(since / Poses.CycleSeconds)
	return cycles, since - cycles * Poses.CycleSeconds
end

local function countUpTo(name, t)
	local cycles, inCycle = cycleAt(t)
	if not cycles then
		return 0
	end
	local count = cycles * #moments[name]
	for _, at in moments[name] do
		count += at <= inCycle and 1 or 0
	end
	return count
end

-- How many attack Impacts fall in fromT < t <= toT, in seconds since the spawn. Pure.
function BossEventService.AttackImpactsBetween(fromT, toT)
	return math.max(0, countUpTo("Impact", toT) - countUpTo("Impact", fromT))
end

-- When a status running at t ends, in seconds since the spawn, or nil. A new moment refreshes it: statuses never stack.
local function statusEnd(status, t)
	local cycles, inCycle = cycleAt(t)
	if not cycles then
		return nil
	end
	local list = moments[status.Event]
	local at = nil
	for i = #list, 1, -1 do
		if list[i] <= inCycle then
			at = cycles * Poses.CycleSeconds + list[i]
			break
		end
	end
	if not at and cycles > 0 then
		at = (cycles - 1) * Poses.CycleSeconds + list[#list]
	end
	local ends = at and Cfg.IntroSeconds + at + status.Seconds
	return ends and t + TIME_EPSILON < ends and ends or nil
end

local function statusJson(t)
	local rows = {}
	for _, status in STATUSES do
		local ends = statusEnd(status, t)
		if ends then
			table.insert(rows, { Id = status.Id, EndsAt = event.StartAt + Cfg.PrepSeconds + ends })
		end
	end
	return #rows > 0 and HttpService:JSONEncode(rows) or nil
end

BossEventService.Hooks = {
	-- What the running statuses leave of a hit, t in seconds since the spawn. Pure.
	DamageMulti = function(t)
		local multi = 1
		for _, status in STATUSES do
			if statusEnd(status, t) then
				multi *= 1 - status.Cut
			end
		end
		return multi
	end,
	Arrive = function(player, lane)
		local cf = RaceService.RouteStartCFrame(Arena.LaneRoute(lane))
		assert(CarService.HoldAt(player, cf), "no living avatar")
		CarService.GetCharacter(player):FindFirstChildOfClass("Humanoid").Died:Once(function()
			BossEventService.Leave(player, "Death")
		end)
	end,
	StartRun = function(player, team, lane)
		local route = { Path = Arena.LaneRoute(lane), Pads = {}, Tracks = {} }
		return CarService.RunHeld(player, route, {
			Boss = true,
			Team = team,
			OnRunEvent = function(event)
				if event.Kind == "BossWait" then
					player:SetAttribute("BossWaitEndsAt", workspace:GetServerTimeNow() + Cfg.RefillWaitSeconds)
				elseif event.Kind == "BossRefill" then
					player:SetAttribute("BossWaitEndsAt", nil)
				end
			end,
		})
	end,
	Depart = function(player)
		CarService.SetAutoRace(player, false) -- back on foot at the walk spawn
	end,
	Chat = function(text)
		if chatRemote then
			chatRemote:FireAllClients(text)
		end
	end,
	MoveChat = function(player, text)
		if chatRemote and player:IsA("Player") then
			chatRemote:FireClient(player, text)
		end
	end,
	BossHits = function(player, entries)
		if hitsRemote and player:IsA("Player") then
			hitsRemote:FireClient(player, entries)
		end
	end,
	-- One Relic each; one player's failure never costs another's. The toast goes through Remotes.RunEvent (Client/TeamToast).
	Rewards = function(players)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local toast = remotes and remotes:FindFirstChild("RunEvent")
		for _, player in players do
			safely(function()
				local ok, relic, raga = RelicService.GrantDefeat(player, "big_raga", rewardRng)
				if ok and toast and player:IsA("Player") then
					toast:FireClient(player, { Kind = "BossReward", Relic = relic.Id, Raga = raga })
				end
			end)
		end
	end,
}

function BossEventService.SetClock(fn)
	clock = fn
end

function BossEventService.PhaseAt(elapsed)
	if elapsed == nil or elapsed < 0 then
		return "Idle"
	elseif elapsed < Cfg.PrepSeconds then
		return "Prep"
	elseif elapsed < Cfg.TotalSeconds then
		return "Fight"
	end
	return "End"
end

function BossEventService.State()
	local players = 0
	for _ in event and event.Members or {} do
		players += 1
	end
	return {
		Phase = event and event.Phase or "Idle",
		Elapsed = event and now() - event.StartAt or nil,
		Source = event and event.Source or nil,
		Hp = event and event.Hp or 0,
		MaxHp = event and event.MaxHp or 0,
		Players = players,
		NextAt = nextAt,
		LastEnd = lastEnd,
	}
end

function BossEventService.IsIn(player)
	return event ~= nil and event.Members[player] ~= nil
end

function BossEventService.LaneOf(player)
	local member = event and event.Members[player]
	return member and member.Lane or nil
end

function BossEventService.TeamOf(player)
	local member = event and event.Members[player]
	return member and member.Team or nil
end

function BossEventService.DamageOf(player)
	local member = event and event.Members[player]
	return member and member.Damage or 0
end

-- The characters with the hardest-hitting Sidekicks, ties by cruise (then id, so it is stable). Pure.
function BossEventService.AutoTeam(player)
	local rows = {}
	for _, id in SidekickService.GearedCharacters(player) do
		local damage = SidekickService.Worn(player, id).Damage
		table.insert(rows, { Id = id, Damage = damage, Cruise = GachaService.CruiseFor(player, id) })
	end
	table.sort(rows, function(a, b)
		if a.Damage ~= b.Damage then
			return a.Damage > b.Damage
		elseif a.Cruise ~= b.Cruise then
			return a.Cruise > b.Cruise
		end
		return a.Id < b.Id
	end)
	local team = {}
	for i = 1, math.min(#rows, StaminaConfig.TEAM_SIZE) do
		team[i] = rows[i].Id
	end
	return team
end

-- True for a non-empty list of owned characters, each once, each wearing a Sidekick. `ids` comes from a client.
local function validTeam(player, ids)
	if type(ids) ~= "table" or #ids < 1 or #ids > StaminaConfig.TEAM_SIZE then
		return false
	end
	local count, seen = 0, {}
	for _, id in ids do
		count += 1
		if type(id) ~= "string" or seen[id] or not CharacterCatalog.Get(id) then
			return false
		end
		if not (GachaService.Owns(player, id) and SidekickService.Worn(player, id)) then
			return false
		end
		seen[id] = true
	end
	return count == #ids -- no keys beside the list
end

function BossEventService.SetTeam(player, ids)
	local member = event and event.Members[player]
	if not member then
		return false, "Not in the event"
	end
	if now() - event.StartAt >= Cfg.PrepSeconds then
		return false, "Preparation is over"
	end
	if not validTeam(player, ids) then
		return false, "Invalid team"
	end
	member.Team = table.clone(ids)
	player:SetAttribute("BossTeamDamage", BossEventService.TeamDamage(player))
	return true
end

-- The live number: the average of the team's Sidekicks, each scaled by its wearer's Relic, times the speed scale of the running character's cruise.
function BossEventService.TeamDamage(player)
	local member = event and event.Members[player]
	if not member then
		return 0
	end
	local team = member.Team or BossEventService.AutoTeam(player)
	local damages = {}
	for _, id in team do
		local spec = SidekickService.Worn(player, id)
		if spec then
			table.insert(damages, spec.Damage * RelicService.Multi(player, id, "Damage"))
		end
	end
	local cruise = member.Run and member.Run.TargetSpeed
		or (team[1] and GachaService.CruiseFor(player, team[1], 1) or 0)
	return Cfg.TeamDamage(damages, cruise)
end

local function userIdOf(player)
	return player:IsA("Player") and player.UserId or player:GetAttribute("UserId")
end

-- Sends what each member has waiting, at most every HIT_BATCH_SECONDS unless `final`: the last hits of an event are not held back.
local function sendHits(members, at, final)
	for player, member in members do
		if #member.Hits > 0 and (final or at - member.HitsSentAt >= HIT_BATCH_SECONDS) then
			local hits = member.Hits
			member.Hits, member.HitsSentAt = {}, at
			safely(BossEventService.Hooks.BossHits, player, hits)
		end
	end
end

-- One hit, of the server's own number: this reads nothing from a client.
function BossEventService.RecordHit(player)
	local member = event and event.Members[player]
	if not (member and member.Run) or member.Run.Waiting then
		return 0
	end
	local sidekick = member.Team[member.Run.Slot]
	local spec = sidekick and SidekickService.Worn(player, sidekick)
	if not spec then
		return 0 -- design doc 4.36: the Sidekick deals the damage
	end
	local multi = BossEventService.Hooks.DamageMulti(now() - event.StartAt - Cfg.PrepSeconds)
	local dealt = math.min(BossEventService.TeamDamage(player) * multi, event.Hp)
	member.Damage += dealt
	event.Hp -= dealt
	local entry = { UserId = userIdOf(player), SidekickId = spec.Id, Damage = dealt }
	for _, other in event.Members do
		table.insert(other.Hits, entry)
	end
	if event.Hp <= 0 then
		BossEventService.End("Defeated")
	else
		publish()
	end
	return dealt
end

-- Seconds between hits. The team hits as one (design doc 4.37), so Relic attack speed counts as the team's average.
local function hitSpacing(player, member)
	local total, count = 0, 0
	for _, id in member.Team do
		if SidekickService.Worn(player, id) then
			total += RelicService.Multi(player, id, "AttackSpeed")
			count += 1
		end
	end
	return count > 0 and Cfg.HitEverySeconds / (total / count) or Cfg.HitEverySeconds
end

-- The attacks since this member's last charge, on the character running now. At 0 the run's own next frame swaps or starts the
-- wait, exactly as for a drain to 0. Impacts during the wait are passed over, never owed.
local function chargeAttacks(member, t)
	local impacts = BossEventService.AttackImpactsBetween(member.ChargedTo, t)
	member.ChargedTo = math.max(member.ChargedTo, t)
	local run = member.Run
	if impacts > 0 and run and not run.Waiting then
		run.Stamina[run.Slot] = math.max(0, run.Stamina[run.Slot] - impacts * Cfg.AttackStaminaCost)
	end
end

local function startRun(player, member)
	local introEnd = event.StartAt + Cfg.PrepSeconds + Cfg.IntroSeconds
	member.NextHit = math.max(introEnd, member.JoinedAt) + Cfg.HitEverySeconds
	local ok, run = safely(BossEventService.Hooks.StartRun, player, member.Team, member.Lane)
	member.Run = ok and run or nil
end

-- Takes a member, already out of the Members table, out of the game's event state. The run stops first; EquippedCar goes
-- back last so a failed return cannot keep the event's character.
local function release(player, member, depart)
	player:SetAttribute("BossEvent", nil)
	player:SetAttribute("BossTeamDamage", nil)
	player:SetAttribute("BossWaitEndsAt", nil)
	if member.Run then
		safely(member.Run.Destroy, member.Run)
	end
	if depart then
		safely(BossEventService.Hooks.Depart, player)
	end
	if player:GetAttribute("EquippedCar") ~= member.Equipped then
		player:SetAttribute("EquippedCar", member.Equipped)
	end
end

function BossEventService.Join(player)
	if not event then
		return false, "No event"
	end
	local joinedAt = now()
	local elapsed = joinedAt - event.StartAt
	if elapsed >= Cfg.JoinSeconds then
		return false, "Teleporting has closed"
	end
	if event.Members[player] then
		return false, "Already in the event"
	end
	local auto = BossEventService.AutoTeam(player)
	if #auto == 0 then
		return false, "Needs a Sidekick"
	end
	local lane = nil
	local taken = {}
	for _, other in event.Members do
		taken[other.Lane] = true
	end
	for candidate = 1, Arena.Lanes do
		if not taken[candidate] then
			lane = candidate
			break
		end
	end
	if not lane then
		return false, "The arena is full"
	end
	local duelState = DuelService.StateOf(player)
	if duelState == "Countdown" or duelState == "Racing" then
		DuelService.PlayerLeft(player) -- a forfeit, only once nothing above can refuse the join
	end
	local current = event
	local member = {
		Lane = lane,
		Team = elapsed >= Cfg.PrepSeconds and auto or nil, -- after preparation the team is chosen for the joiner
		Damage = 0,
		Hits = {}, -- waiting for the next batch
		HitsSentAt = -math.huge,
		JoinedAt = joinedAt,
		ChargedTo = elapsed - Cfg.PrepSeconds, -- nothing at or before the join is owed
		Equipped = player:GetAttribute("EquippedCar"),
	}
	current.Members[player] = member
	player:SetAttribute("BossEvent", true)
	current.MaxHp += Cfg.HpPerPlayer
	current.Hp += Cfg.HpPerPlayer
	publish()
	if not safely(BossEventService.Hooks.Arrive, player, lane) then
		BossEventService.Leave(player, "Left")
		return false, "Could not teleport"
	end
	if event == current and current.IntroDone and current.Members[player] == member then
		startRun(player, member)
	end
	if BossEventService.IsIn(player) then
		player:SetAttribute("BossTeamDamage", BossEventService.TeamDamage(player))
	end
	return true
end

-- A leave before 3:00 takes the player's HP back; it never defeats the boss. A death returns through the respawn.
function BossEventService.Leave(player, reason)
	local member = event and event.Members[player]
	if not member then
		return
	end
	event.Members[player] = nil
	if now() - event.StartAt < Cfg.JoinSeconds then
		event.MaxHp -= Cfg.HpPerPlayer
		event.Hp = math.min(event.Hp, event.MaxHp)
	end
	publish()
	release(player, member, reason ~= "Death")
end

local function begin(source, at)
	event = { StartAt = at, Source = source, Phase = "Prep", Hp = 0, MaxHp = 0, Members = {} }
	publish()
end

function BossEventService.Start(source)
	if event then
		return false, "An event is active"
	end
	begin(source, now())
	return true
end

function BossEventService.End(reason)
	local ending = event
	if not ending then
		return false
	end
	event = nil
	lastEnd = reason
	publish()
	sendHits(ending.Members, now(), true)
	local winners = {}
	local need = Cfg.MinDamageShare * ending.MaxHp - DAMAGE_EPSILON
	for player, member in ending.Members do
		if member.Damage >= need and member.Damage > 0 then
			table.insert(winners, player)
		end
		release(player, member, true)
	end
	if reason == "Defeated" then
		safely(BossEventService.Hooks.Rewards, winners)
	end
	return true
end

function BossEventService.Reset(at)
	BossEventService.End("Reset")
	lastEnd = nil
	nextAt = (at or now()) + Cfg.IntervalSeconds
	publish()
end

-- One chat line per move whose moment passed since the last tick, to the players in the event now.
local function announceMoves(current, t)
	local from = current.ChattedTo or 0
	current.ChattedTo = math.max(from, t)
	for name, text in Cfg.MoveChat do
		if countUpTo(name, t) > countUpTo(name, from) then
			for player in current.Members do
				safely(BossEventService.Hooks.MoveChat, player, text)
			end
		end
	end
end

-- One event's clock at `at`: the spawn, the end of the intro, every hit due, the ends.
local function tick(at)
	local current = event
	local elapsed = at - current.StartAt
	local phase = BossEventService.PhaseAt(elapsed)
	if phase == "Fight" and current.Phase ~= phase then
		current.Phase = phase
		publish()
	end
	if elapsed >= Cfg.PrepSeconds and not current.Spawned then
		current.Spawned = true
		for player, member in table.clone(current.Members) do
			member.Team = member.Team or BossEventService.AutoTeam(player)
			if #member.Team == 0 then -- took every Sidekick off during preparation
				BossEventService.Leave(player, "Left")
			end
		end
		safely(BossEventService.Hooks.Chat, Cfg.ChatMessage)
	end
	if elapsed >= Cfg.PrepSeconds + Cfg.IntroSeconds and not current.IntroDone then
		current.IntroDone = true
		for player, member in table.clone(current.Members) do
			startRun(player, member)
		end
	end
	local t = elapsed - Cfg.PrepSeconds
	ReplicatedStorage:SetAttribute("BossStatus", statusJson(t))
	announceMoves(current, t)
	for player, member in table.clone(current.Members) do
		chargeAttacks(member, t)
		if not player.Parent then
			BossEventService.Leave(player, "Left")
		elseif member.Run and member.Run.Waiting then
			member.NextHit = at + hitSpacing(player, member) -- the wait owes nothing afterward
		elseif member.Run then
			while event == current and current.Members[player] == member and member.NextHit <= at do
				BossEventService.RecordHit(player)
				member.NextHit += hitSpacing(player, member)
			end
		end
	end
	if event ~= current then
		return
	end
	sendHits(current.Members, at)
	for player in current.Members do
		player:SetAttribute("BossTeamDamage", BossEventService.TeamDamage(player)) -- the running character and refills change it
	end
	if elapsed >= Cfg.JoinSeconds and next(current.Members) == nil then
		BossEventService.End("NoPlayers") -- nobody came, or nobody is left and nobody can come
	elseif elapsed >= Cfg.TotalSeconds then
		BossEventService.End("Timeout")
	end
end

-- The scheduler tick. An event moves first, so one ending on a mark does not skip that mark.
function BossEventService.Advance(at)
	at = at or now()
	if type(at) ~= "number" or at ~= at or math.abs(at) == math.huge then
		return
	end
	if event then
		tick(at)
	end
	if at >= nextAt then
		nextAt += Cfg.IntervalSeconds * (math.floor((at - nextAt) / Cfg.IntervalSeconds) + 1)
		if not event then
			begin("Timer", at)
		end
	end
end

local function bind(remotes, name, fn)
	local remote = remotes:FindFirstChild(name) or Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotes
	remote.OnServerInvoke = function(player, ...)
		if player:GetAttribute("DataLoaded") ~= true then
			return false, "Data not loaded"
		end
		local at = os.clock()
		if lastRequest[player] and at - lastRequest[player] < REMOTE_COOLDOWN then
			return false, "Please wait"
		end
		lastRequest[player] = at
		return fn(player, ...)
	end
end

function BossEventService.Init()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	chatRemote = remotes:FindFirstChild("BossEventChat") or Instance.new("RemoteEvent")
	chatRemote.Name = "BossEventChat"
	chatRemote.Parent = remotes
	hitsRemote = remotes:FindFirstChild("BossHits") or Instance.new("RemoteEvent")
	hitsRemote.Name = "BossHits"
	hitsRemote.Parent = remotes
	bind(remotes, "BossEventTeleport", function(player)
		return BossEventService.Join(player)
	end)
	bind(remotes, "BossEventSetTeam", BossEventService.SetTeam)
	local function left(player)
		BossEventService.Leave(player, "Left")
	end
	bind(remotes, "BossEventLeave", function(player)
		left(player)
		return true
	end)
	PlayerData.OnLeaving(left) -- before the leave save: it must hold the player's own EquippedCar
	Players.PlayerRemoving:Connect(left)
	nextAt = now() + Cfg.IntervalSeconds
	task.spawn(function()
		while true do
			task.wait(1)
			if ReplicatedStorage:GetAttribute("CarTestRunning") ~= true then
				safely(BossEventService.Advance)
			end
		end
	end)
end

return BossEventService
