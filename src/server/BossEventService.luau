--!nonstrict
-- Boss events (design doc 4.37, docs/BOSS_EVENT_SPEC.md): one event per server, every 30 minutes on a fixed grid (the
-- WeatherService shape), or at once for a paid start. The server decides every hit; no remote reaches the damage. Contract:
-- Server/CarTest/BossEventTests.
-- Clients read ReplicatedStorage attributes BossEventPhase ("Prep" or "Fight", nil when idle), BossEventStart (server time),
-- BossEventHp and BossEventMaxHp, and the player attributes BossEvent (true while in the event), BossTeamDamage (TeamDamage, nil
-- outside the event), BossWaitEndsAt (server time the exhausted team revives, nil otherwise) and BossStatus (JSON list of { Id,
-- EndsAt in server time }, nil when empty; each player's own, since a dodge spares that player alone). They call the
-- RemoteFunctions Remotes.BossEventTeleport(), Remotes.BossEventSetTeam(ids), Remotes.BossEventLeave() and
-- Remotes.BossDodge(index, stamp); each returns ok, reason.
-- Remotes.BossEventChat carries the server-wide spawn message and each member's move lines to Client/BossEventChat.
-- Remotes.BossHits carries each hit, batched, to the players in the event: { UserId, SidekickId, Damage }, for Client/SidekickAttackView.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.BossArenaConfig)
local BossDodge = require(Shared.BossDodge)
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
local TICK_SECONDS = 0.25 -- a player's status icon appears this soon after the move that hit them
local HIT_BATCH_SECONDS = 0.25 -- at most 4 batches of hits a second to a player (docs/BOSS_EVENT_SPEC.md)
local DAMAGE_EPSILON = 1e-6 -- exactly the minimum share still earns the reward, whatever the float sum
local TIME_EPSILON = 1e-6 -- s: a clock a float's hair before a schedule moment is on it
local DODGE_STAMP_SLACK = 0.03 -- s: a press stamped on the spot's edge, on a client clock a hair off the server's
local DODGE_MAX_AGE = 0.5 -- s: a stamp older than this on arrival is refused
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
	ReplicatedStorage:SetAttribute("BossEventNextAt", nextAt < math.huge and nextAt or nil)
end

-- The index of the last moment at or before t, in seconds since the spawn.
local function indexAt(t)
	return BossDodge.IndexAtOrBefore(t + TIME_EPSILON - Cfg.IntroSeconds)
end

-- How many attack Impacts fall in fromT < t <= toT, in seconds since the spawn. Pure.
function BossEventService.AttackImpactsBetween(fromT, toT)
	local count = 0
	for index = indexAt(fromT) + 1, indexAt(toT) do
		count += select(2, BossDodge.Moment(index)) == "Impact" and 1 or 0
	end
	return count
end

-- When a status running at t ends, in seconds since the spawn, or nil. The latest moment that was not spared counts: statuses
-- never stack. `spared` is a member's moment index -> true, nil for a player every move hits.
local function statusEnd(status, t, spared)
	for index = indexAt(t), 1, -1 do
		local at, name = BossDodge.Moment(index)
		local ends = Cfg.IntroSeconds + at + status.Seconds
		if t + TIME_EPSILON >= ends then
			return nil
		elseif name == status.Event and not (spared and spared[index]) then
			return ends
		end
	end
	return nil
end

local function statusJson(t, spared)
	local rows = {}
	for _, status in STATUSES do
		local ends = statusEnd(status, t, spared)
		if ends then
			table.insert(rows, { Id = status.Id, EndsAt = event.StartAt + Cfg.PrepSeconds + ends })
		end
	end
	return #rows > 0 and HttpService:JSONEncode(rows) or nil
end

BossEventService.Hooks = {
	-- What the running statuses leave of a hit, t in seconds since the spawn, `spared` the member's dodged moments. Pure.
	DamageMulti = function(t, spared)
		local multi = 1
		for _, status in STATUSES do
			if statusEnd(status, t, spared) then
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
	SwitchLane = function(run, lane)
		run:SwitchRoute(Arena.LaneRoute(lane))
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

-- The minibar's event roster (design doc 4.37): the Team attribute is never touched. Display only, except EquippedCar: the first
-- on the team wears the held runner, for the preparation run. release() puts the player's own back.
local function publishTeam(player, team)
	player:SetAttribute("BossTeam", table.concat(team, ","))
	if team[1] and player:GetAttribute("EquippedCar") ~= team[1] then
		player:SetAttribute("EquippedCar", team[1])
	end
	local kind, series = GachaService.TeamBonus(player, team)
	player:SetAttribute("BossTeamBonus", kind and (kind .. ":" .. series.Id) or "")
	local staminaMulti = #team > 0 and GachaService.StaminaMulti(player, team)
	for slot = 1, StaminaConfig.TEAM_SIZE do
		local id = team[slot]
		local spec = id and CharacterCatalog.Get(id)
		player:SetAttribute("BossTeamCruise" .. slot, spec and GachaService.CruiseFor(player, id, slot, team) or nil)
		player:SetAttribute(
			"BossTeamStamina" .. slot,
			spec
					and math.round(
						StaminaConfig.Seconds(
							spec,
							staminaMulti
								* SidekickService.StaminaMulti(player, id)
								* RelicService.Multi(player, id, "Stamina")
						) * 10
					) / 10
				or nil
		)
	end
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

-- The saved team's ids that can still fight (design doc 4.37), in order.
local function savedTeam(player)
	local team, seen = {}, {}
	for _, id in string.split(player:GetAttribute("LastBossTeam") or "", ",") do
		if
			not seen[id]
			and #team < StaminaConfig.TEAM_SIZE
			and GachaService.Owns(player, id)
			and SidekickService.Worn(player, id)
		then
			table.insert(team, id)
			seen[id] = true
		end
	end
	return team
end

-- The player closed the team HUD: their team starts its display-only run (design doc 4.37).
function BossEventService.StartPrepRun(player)
	if not (event and event.Members[player]) then
		return false, "Not in the event"
	end
	player:SetAttribute("BossPrepRun", true)
	return true
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
	player:SetAttribute("LastBossTeam", table.concat(ids, ","))
	publishTeam(player, member.Team)
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
		or (team[1] and GachaService.CruiseFor(player, team[1], 1, team) or 0)
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
	local multi = BossEventService.Hooks.DamageMulti(now() - event.StartAt - Cfg.PrepSeconds, member.Spared)
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

-- Each move since this member's last charge that hit: the attack's cost on the character running now and the move's chat line. At
-- 0 the run's own next frame swaps or starts the wait, exactly as for a drain to 0. A move during the wait is passed over, never
-- owed; a dodged one is already spared.
local function chargeMoves(player, member, t)
	local from = indexAt(member.ChargedTo)
	member.ChargedTo = math.max(member.ChargedTo, t)
	local run = member.Run
	for index = from + 1, indexAt(t) do
		if run and run.Waiting then
			member.Spared[index] = true
		end
		if not member.Spared[index] then
			local _, name = BossDodge.Moment(index)
			if name == "Impact" and run then
				run.Stamina[run.Slot] = math.max(0, run.Stamina[run.Slot] - Cfg.AttackStaminaCost)
			end
			safely(BossEventService.Hooks.MoveChat, player, Cfg.MoveChat[name])
		end
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
	publishTeam(player, {})
	player:SetAttribute("BossTeam", nil)
	player:SetAttribute("BossTeamBonus", nil)
	player:SetAttribute("BossLane", nil)
	player:SetAttribute("BossPrepRun", nil)
	player:SetAttribute("BossTeamDamage", nil)
	player:SetAttribute("BossWaitEndsAt", nil)
	player:SetAttribute("BossStatus", nil)
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
	local saved = savedTeam(player)
	local member = {
		Lane = lane,
		-- The saved team if it can fight; after preparation, with none, the team is chosen for the joiner.
		Team = #saved > 0 and saved or (elapsed >= Cfg.PrepSeconds and auto or nil),
		Damage = 0,
		Hits = {}, -- waiting for the next batch
		HitsSentAt = -math.huge,
		JoinedAt = joinedAt,
		ChargedTo = elapsed - Cfg.PrepSeconds, -- nothing at or before the join is owed
		Spared = {}, -- moment index -> true: dodged, or passed in the wait
		Pressed = {}, -- moment index -> true: the one press a prompt allows was used
		Equipped = player:GetAttribute("EquippedCar"),
	}
	current.Members[player] = member
	player:SetAttribute("BossLane", lane)
	publishTeam(player, member.Team or auto) -- before BossEvent, so the minibar never reads a stale team
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

-- The neighbouring lane to dodge into: a free one, at random if both are; a taken one if neither is.
local function dodgeLane(player, lane)
	local free, near = {}, {}
	for _, candidate in { lane - 1, lane + 1 } do
		if candidate >= 1 and candidate <= Arena.Lanes then
			table.insert(near, candidate)
			local taken = false
			for other, member in event.Members do
				taken = taken or (other ~= player and member.Lane == candidate)
			end
			if not taken then
				table.insert(free, candidate)
			end
		end
	end
	local from = #free > 0 and free or near
	return from[rewardRng:NextInteger(1, #from)]
end

-- One press of the Dodge bar. `index` and `stamp` (the press, in server time) come from a client: the window and the moment are
-- the server's. docs/BOSS_EVENT_SPEC.md "Dodge bar" covers why the stamp is trusted this far. Returns ok, reason.
function BossEventService.Dodge(player, index, stamp)
	local member = event and event.Members[player]
	if not member then
		return false, "Not in the event"
	end
	if not (member.Run and not member.Run.Waiting) then
		return false, "Not running"
	end
	if type(index) ~= "number" or index < 1 or index % 1 ~= 0 or index == math.huge then
		return false, "Invalid press"
	end
	if type(stamp) ~= "number" or stamp ~= stamp or math.abs(stamp) == math.huge then
		return false, "Invalid press"
	end
	local at = now()
	local moment = event.StartAt + Cfg.PrepSeconds + Cfg.IntroSeconds + BossDodge.Moment(index)
	if at > moment or at < moment - BossDodge.SweepSeconds - DODGE_STAMP_SLACK then
		return false, "No bar"
	end
	if member.Pressed[index] then
		return false, "Already pressed"
	end
	member.Pressed[index] = true
	local from, to = BossDodge.Window(BossDodge.Spot(userIdOf(player) or 0, event.StartAt, index), moment)
	if
		stamp < from - DODGE_STAMP_SLACK
		or stamp > to + DODGE_STAMP_SLACK
		or stamp > at + DODGE_STAMP_SLACK
		or at - stamp > DODGE_MAX_AGE
	then
		return false, "Missed"
	end
	member.Spared[index] = true
	member.Lane = dodgeLane(player, member.Lane)
	player:SetAttribute("BossLane", member.Lane)
	safely(BossEventService.Hooks.SwitchLane, member.Run, member.Lane)
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
		-- An emptied arena has MaxHp 0, so Hp is 0 too: the next joiner starts from exactly one player's HP.
		event.Hp = math.min(math.max(event.Hp - Cfg.HpPerPlayer, 1), event.MaxHp)
	end
	publish()
	release(player, member, reason ~= "Death")
end

local function begin(source, at)
	event = { StartAt = at, Source = source, Phase = "Prep", Hp = 0, MaxHp = 0, Members = {} }
	for lane = 1, Arena.Lanes do
		RaceService.PrepareRoute(Arena.LaneRoute(lane)) -- a dodge never sends a client to a route it does not have yet
	end
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
			else
				player:SetAttribute("LastBossTeam", table.concat(member.Team, ","))
				publishTeam(player, member.Team)
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
	for player, member in table.clone(current.Members) do
		chargeMoves(player, member, t)
		player:SetAttribute("BossStatus", statusJson(t, member.Spared))
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
		else
			publish()
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
	bind(remotes, "BossEventPrepRun", BossEventService.StartPrepRun)
	bind(remotes, "BossDodge", BossEventService.Dodge)
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
	publish()
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			if ReplicatedStorage:GetAttribute("CarTestRunning") ~= true then
				safely(BossEventService.Advance)
			end
		end
	end)
end

return BossEventService
