--!nonstrict
-- Boss events (design doc 4.37, docs/BOSS_EVENT_SPEC.md): one event per server, every 30 minutes on a fixed grid (the
-- WeatherService shape), or at once for a paid start. The server decides every hit; no remote reaches the damage. Contract:
-- Server/CarTest/BossEventTests.
-- Clients read ReplicatedStorage attributes BossEventPhase ("Prep" or "Fight", nil when idle), BossEventStart (server time),
-- BossEventHp and BossEventMaxHp, and the player attributes BossEvent (true while in the event) and BossTeamDamage (TeamDamage,
-- nil outside the event). They call the RemoteFunctions
-- Remotes.BossEventTeleport(), Remotes.BossEventSetTeam(ids) and Remotes.BossEventLeave(); each returns ok, reason.
-- Remotes.BossEventChat carries the server-wide spawn message to Client/BossEventChat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.BossArenaConfig)
local CharacterCatalog = require(Shared.CharacterCatalog)
local Cfg = require(Shared.BossEventConfig)
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
local DAMAGE_EPSILON = 1e-6 -- exactly the minimum share still earns the reward, whatever the float sum

local clock = nil
local event = nil -- { StartAt, Source, Phase, Hp, MaxHp, Spawned, IntroDone, Members = { [player] = member } }
local nextAt = math.huge
local lastEnd = nil
local chatRemote = nil
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
end

BossEventService.Hooks = {
	Arrive = function(player, lane)
		local cf = RaceService.RouteStartCFrame(Arena.LaneRoute(lane))
		assert(CarService.HoldAt(player, cf), "no living avatar")
		CarService.GetCharacter(player):FindFirstChildOfClass("Humanoid").Died:Once(function()
			BossEventService.Leave(player, "Death")
		end)
	end,
	StartRun = function(player, team, lane)
		local route = { Path = Arena.LaneRoute(lane), Pads = {}, Tracks = {} }
		return CarService.RunHeld(player, route, { Boss = true, Team = team })
	end,
	Depart = function(player)
		CarService.SetAutoRace(player, false) -- back on foot at the walk spawn
	end,
	Chat = function(text)
		if chatRemote then
			chatRemote:FireAllClients(text)
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

-- One hit, of the server's own number: this reads nothing from a client.
function BossEventService.RecordHit(player)
	local member = event and event.Members[player]
	if not (member and member.Run) or member.Run.Waiting then
		return 0
	end
	local dealt = math.min(BossEventService.TeamDamage(player), event.Hp)
	member.Damage += dealt
	event.Hp -= dealt
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
		JoinedAt = joinedAt,
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
	for player, member in table.clone(current.Members) do
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
