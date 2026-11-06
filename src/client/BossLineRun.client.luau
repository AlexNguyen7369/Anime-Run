--!nonstrict
-- The boss event's line run (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Line run"). Display only, drawn from replicated attributes: the
-- front of each line is that player's own held runner (Client/RunnerView); this draws the slots behind it as local rigs with Sidekicks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
local PathDriver = require(Shared:WaitForChild("PathDriver"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))
local BossTeamRig = require(script.Parent:WaitForChild("BossTeamRig"))
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))

-- RunnerView's smoothing and dash, so a rig keeps its place behind the drawn body.
local CORRECT_RATE = 2
local SNAP_STUDS = 40
local SNAP_SECONDS = 0.5
local LANE_SLIDE_SECONDS = 0.35
local CLOSE_RATE = 6 -- 1/s, placeholder: how fast the line closes up when a place opens

local lines = {} -- player -> { Rigs, Back, Hints = { [slot] }, Slots, Key, Phase, Dist, Route, Rd, ChangedAt, At, Slide, SlideLeft, SlideSide }

local function dropLine(who)
	local line = lines[who]
	if line then
		lines[who] = nil
		for _, rig in line.Rigs do
			rig:Destroy()
		end
	end
end

local function smokeAt(model, small)
	local torso = model and model:FindFirstChild("Torso")
	if torso then
		BossTeamRig.Smoke(torso.Position, small)
	end
end

-- Brings the rigs to BossLine. Returns the rigs that came back from the wait: they smoke once posed.
local function syncRigs(who, line)
	local key = who:GetAttribute("BossLine")
	if key == line.Key then
		return nil
	end
	local slots = {}
	for text in string.gmatch(key, "%d+") do
		table.insert(slots, tonumber(text))
	end
	local before = line.Slots
	for _, slot in before or {} do
		if not table.find(slots, slot) then
			smokeAt(slot == before[1] and BossTeamRig.HeldCopy(who) or line.Rigs[slot])
		end
	end
	-- A rig that became the front goes too: the held body now wears it.
	for slot, rig in line.Rigs do
		if slot == slots[1] or not table.find(slots, slot) then
			rig:Destroy()
			line.Rigs[slot] = nil
		end
	end
	local ids = string.split(who:GetAttribute("BossTeam") or "", ",")
	local fresh = {}
	for i = 2, #slots do
		local slot = slots[i]
		local id = ids[slot]
		if not line.Rigs[slot] and id and CharacterCatalog.Get(id) then
			line.Rigs[slot] = BossTeamRig.New(who, slot, id)
			line.Back[slot] = BossTeamRig.TEAM_GAP * (i - 1)
			table.insert(fresh, line.Rigs[slot])
		end
	end
	line.Key, line.Slots = key, slots
	return before and fresh or nil -- the first sight of a line is the hand-over from BossPrepRun, with no smoke
end

-- RunnerView's step for the drawn distance: the same numbers, so the line stays behind the body it draws.
local function smooth(line, server, route, now)
	local dt = math.max(0, now - (line.At or now))
	line.At = now
	local rd, rs = server:GetAttribute("RunDistance"), server:GetAttribute("RunSpeed")
	if rd ~= line.Rd then
		line.Rd, line.ChangedAt = rd, now
	end
	if line.Route and line.Route ~= route and line.Dist then -- a dodge: same lap angle, sliding over from the old lane
		local scaled = line.Dist * route.Arc[#route.Arc] / line.Route.Arc[#line.Route.Arc]
		local old = PathDriver.PoseAt(line.Route.Wps, line.Route.Arc, line.Dist, nil, line.Route.Closed)
		local new = PathDriver.PoseAt(route.Wps, route.Arc, scaled, nil, route.Closed)
		line.Dist, line.Hints = scaled, {}
		line.Slide, line.SlideLeft = old.Position - new.Position, LANE_SLIDE_SECONDS
		line.SlideSide = new.RightVector:Dot(new.Position - old.Position) >= 0 and 1 or -1
	end
	line.Route = route
	local target = rd + rs * (now - line.ChangedAt)
	if not line.Dist or math.abs(target - line.Dist) > math.max(SNAP_STUDS, rs * SNAP_SECONDS) then
		line.Dist = target
	else
		line.Dist += rs * dt
		line.Dist += (target - line.Dist) * math.min(1, CORRECT_RATE * dt)
	end
	line.Phase = RunnerVisual.Advance(line.Phase, rs, dt)
	return rs, dt
end

local function stepPlayer(who, now)
	local server, route = BossTeamRig.RunOf(who)
	if not server then
		dropLine(who)
		return
	end
	local line = lines[who]
	if not line then
		line = { Rigs = {}, Back = {}, Hints = {}, Phase = 0 }
		lines[who] = line
	end
	local fresh = syncRigs(who, line)
	local rs, dt = smooth(line, server, route, now)
	local dashAt = nil
	local offset = Vector3.zero
	if line.Slide then
		line.SlideLeft -= dt
		if line.SlideLeft > 0 then
			offset = line.Slide * (line.SlideLeft / LANE_SLIDE_SECONDS) ^ 2
			dashAt = 1 - line.SlideLeft / LANE_SLIDE_SECONDS
		else
			line.Slide = nil
		end
	end
	for i, slot in line.Slots do
		local rig = line.Rigs[slot]
		if rig then
			local gap = BossTeamRig.TEAM_GAP * (i - 1)
			line.Back[slot] += (gap - line.Back[slot]) * math.min(1, CLOSE_RATE * dt)
			local feet, k =
				PathDriver.PoseAt(route.Wps, route.Arc, line.Dist - line.Back[slot], line.Hints[slot], route.Closed)
			line.Hints[slot] = k
			local root = (feet + offset) * CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0)
			RunnerVisual.Pose(rig, root, line.Phase, rs > 0 and 1 or 0)
			if dashAt then
				RunnerVisual.PoseDash(rig, root, dashAt, line.SlideSide)
			end
		end
	end
	for _, rig in fresh or {} do
		smokeAt(rig, true)
	end
end

RunService:BindToRenderStep("BossLineRun", Enum.RenderPriority.Camera.Value - 2, function()
	if player:GetAttribute("BossEvent") ~= true then
		for who in lines do
			dropLine(who)
		end
		return
	end
	local now = os.clock()
	for _, who in Players:GetPlayers() do
		stepPlayer(who, now)
	end
end)
Players.PlayerRemoving:Connect(dropLine)
