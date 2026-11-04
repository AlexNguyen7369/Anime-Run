--!nonstrict
-- The NPC racer is a numbers game: it does not use physics. It runs the LEFT lane of a track (centre line
-- shifted LANE_OFFSET to the left) at its NpcConfig speed, slowing only where corner grip requires it (the same
-- limit the IVS car driver used), so its time for a track is known the moment the race starts. The server decides the
-- race from that time (Server/RaceService); the owning client only draws the runner rig (Client/NpcRacerView), so other
-- players never see it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunnerFactory = require(script.Parent.RunnerFactory)
local TrackBuilder = require(script.Parent.TrackBuilder)
local TrackRegistry = require(script.Parent.TrackRegistry)
local UiTheme = require(script.Parent.UiTheme)

local NpcRacer = {}

local INDICATOR_SIZE = UDim2.fromOffset(340, 96) -- px, the same at any distance (placeholder, design doc 4.25)

-- Corner limit kept from IVS so NPC track times are unchanged (design doc section 3): lateral accel = MU x g x share
local GRIP_MU = 1.2 -- the IVS car's tyre Mu
local GRIP_FRACTION = 0.55 -- the share of that budget used in corners

-- The chain of tracks as Main builds it, without instances: { { Layout, Origin, Number }, ... } in Number order.
function NpcRacer.ChainEntries()
	local entries = {}
	local origin = TrackBuilder.CHAIN_ORIGIN
	for _, spec in TrackRegistry.Chain() do
		local layout = TrackBuilder.Layout(spec)
		table.insert(entries, { Layout = layout, Origin = origin, Number = spec.Number })
		origin = TrackBuilder.EndCFrame(layout, origin)
	end
	return entries
end

-- The NPC's lane on one chain entry { Layout, Origin }, in world space: { Waypoints, Curvature, Length }.
function NpcRacer.LanePath(entry)
	local lane = TrackBuilder.RacePath(entry.Layout, -TrackBuilder.LANE_OFFSET)
	local waypoints = table.create(#lane.Waypoints)
	local length = 0
	for i, p in lane.Waypoints do
		waypoints[i] = entry.Origin:PointToWorldSpace(p)
		if i > 1 then
			length += (waypoints[i] - waypoints[i - 1]).Magnitude
		end
	end
	return { Waypoints = waypoints, Curvature = lane.Curvature, Length = length }
end

-- When the NPC passes each waypoint at cruise `speed`: { Times, TotalTime, Length }.
function NpcRacer.Profile(path, speed)
	local wps, curv = path.Waypoints, path.Curvature
	local latAccel = GRIP_MU * workspace.Gravity * GRIP_FRACTION
	local function limit(i)
		local k = curv[i] or 0
		return k > 0 and math.min(speed, math.sqrt(latAccel / k)) or speed
	end
	local times = table.create(#wps)
	times[1] = 0
	local t = 0
	for i = 2, #wps do
		local v = math.max(math.min(limit(i - 1), limit(i)), 1e-3)
		t += (wps[i] - wps[i - 1]).Magnitude / v
		times[i] = t
	end
	return { Times = times, TotalTime = t, Length = path.Length, Speed = speed }
end

-- Where the NPC is `t` seconds after the start: the rig's pivot (Torso) above the lane, upright, facing along it.
function NpcRacer.PoseAt(path, profile, t)
	local wps, times = path.Waypoints, profile.Times
	local n = #wps
	t = math.clamp(t, 0, profile.TotalTime)
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if times[mid] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local a, b = wps[lo], wps[hi]
	local span = times[hi] - times[lo]
	local alpha = span > 1e-6 and math.clamp((t - times[lo]) / span, 0, 1) or 0
	local up = Vector3.new(0, RunnerFactory.HIP_HEIGHT, 0)
	local pos = a:Lerp(b, alpha) + up
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if dir.Magnitude < 1e-6 then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, pos + dir.Unit)
end

local function setupParts(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
end

-- The NPC rival for `info` (NpcConfig.For(n)): the same runner rig as a player's (docs/WORLD_REDESIGN_SPEC.md
-- section 2) with its body in info.Color (info.Model, a character id, picks the rig's palette), or a clone of
-- ReplicatedStorage.NpcModels[info.Model]. Not parented: the owning client puts it in its own Workspace.
function NpcRacer.BuildModel(info)
	local model
	local folder = info.Model and ReplicatedStorage:FindFirstChild("NpcModels")
	local custom = folder and folder:FindFirstChild(info.Model)
	if custom and custom:IsA("Model") then
		model = custom:Clone()
		if not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		end
	else
		model = RunnerFactory.build(info.Model, { Color = info.Color })
		local nameLabel = model:FindFirstChild("NameLabel")
		if nameLabel then
			nameLabel:Destroy() -- the NPC label below names it
		end
	end
	model.Name = "NPC_" .. info.Label
	model:SetAttribute("IsNpc", true)
	model:SetAttribute("TrackNumber", info.Number)
	setupParts(model)

	-- The indicator (design doc 4.25): the arrow tip stays on top of the head, at any distance and through walls.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NpcLabel"
	billboard.Adornee = model:FindFirstChild("Head") or model.PrimaryPart
	billboard.Size = INDICATOR_SIZE
	billboard.SizeOffset = Vector2.new(0, 0.5)
	billboard.ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = model
	local function line(name, text, y, height, color)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, height)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextScaled = true
		l.Font = UiTheme.Font
		l.TextColor3 = color
		UiTheme.Stroke(l, 3)
		l.Parent = billboard
	end
	line("Text", info.Label, 0, 0.55, Color3.new(1, 1, 1))
	line("Arrow", "\u{25BC}", 0.55, 0.45, UiTheme.Palette.Danger)
	return model
end

return NpcRacer
