--!nonstrict
-- Replaces each player's avatar with their runner (Shared/RunnerFactory, docs/WORLD_REDESIGN_SPEC.md section 2) while
-- racing. The Humanoid character still exists (Roblox needs it for camera, respawn and input) but it is hidden and
-- carried with the runner (welded to its Torso), so the runner is the only thing anyone sees.
-- Players join and respawn ON FOOT in the spawn area (Shared/SpawnArea, docs/SPAWN_AND_ROLLS_SPEC.md). The
-- "Auto Race" button (Client/AutoRaceButton, Remotes.SetAutoRace) or walking onto the StartPad spawns a fresh runner at
-- the start; "Stop Auto" ends the run, removes the runner and puts the visible avatar back in
-- the spawn area (WalkSpawnCFrame). The player attribute AutoRacing is the state the button shows. The Speed stat
-- lives in leaderstats, so it is kept across both.

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared.CharacterCatalog)
local RunnerFactory = require(Shared.RunnerFactory)
local SpawnArea = require(Shared.SpawnArea)
local PlayerData = require(script.Parent.PlayerData)
local RaceService = require(script.Parent.RaceService)
local UpgradeService = require(script.Parent.UpgradeService)
local VehicleEffects = require(Shared.VehicleEffects)

local CarService = {}

CarService.TOGGLE_COOLDOWN = 0.75 -- seconds between toggle requests from one player (remote only)
CarService.RUNNER_TAG = "RunnerRig" -- every player's server runner (Client/RunnerView draws it smoothly)

local HIDDEN_GROUP = "HiddenAvatar" -- the hidden avatar while it rides: collides with nothing
local PLACE_HOLD = 2 -- seconds the server keeps putting a real player's avatar back at the walk spawn after a teleport
local PLACE_SLACK = 8 -- studs (horizontal) the avatar may be from the walk spawn before it is put back

local cars = {} -- player -> runner model
local carryWelds = {} -- player -> Weld holding the hidden avatar to its runner
local runs = {} -- player -> RaceService run
local characters = {} -- player -> character the car belongs to
local racing = {} -- player -> true / false (nil = never attached)
local generation = {} -- player -> number, bumped by every state change so stale attaches give up
local hidden = {} -- character -> { Parts = { [part] = props }, Added = connection }
local watched = setmetatable({}, { __mode = "k" }) -- character -> true once its death is handled
local lastToggle = {} -- player -> os.clock() of the last accepted remote request
local lastPadStart = {} -- player -> os.clock() of the last stop or StartPad start (StartPad cooldown)

local DUEL_SLOT_GAP = 8 -- studs between the two held duel runners (the road is 40 wide)

local function userIdOf(player)
	local ok, id = pcall(function()
		return player.UserId
	end)
	return ok and id or nil
end

local function hidePart(state, d)
	if d:IsA("BasePart") then
		if not state.Parts[d] then
			state.Parts[d] = {
				Transparency = d.Transparency,
				CanCollide = d.CanCollide,
				Massless = d.Massless,
				CollisionGroup = d.CollisionGroup,
			}
		end
		d.Transparency = 1
		d.CanCollide = false
		d.Massless = true
		-- A seated Humanoid turns its torso collision back on: its own group, collidable with nothing, keeps the
		-- hidden avatar from ever touching a car or the track
		d.CollisionGroup = HIDDEN_GROUP
	elseif d:IsA("Decal") then
		if not state.Parts[d] then
			state.Parts[d] = { Transparency = d.Transparency }
		end
		d.Transparency = 1
	end
end

local hiddenGroupReady = false
local function ensureHiddenGroup()
	if hiddenGroupReady then
		return
	end
	hiddenGroupReady = true
	pcall(function()
		PhysicsService:RegisterCollisionGroup(HIDDEN_GROUP)
	end)
	for _, other in PhysicsService:GetRegisteredCollisionGroups() do
		pcall(function()
			PhysicsService:CollisionGroupSetCollidable(HIDDEN_GROUP, other.name, false)
		end)
	end
end

local function hideCharacter(character)
	ensureHiddenGroup()
	local state = hidden[character]
	if not state then
		state = { Parts = {} }
		hidden[character] = state
		-- Accessories that load after the character spawns are hidden too
		state.Added = character.DescendantAdded:Connect(function(d)
			hidePart(state, d)
		end)
	end
	for _, d in character:GetDescendants() do
		hidePart(state, d)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
	end
end

-- On-foot WalkSpeed: the player's Walkspeed upgrade tier (UpgradeService), the StarterPlayer default for fakes.
local function walkSpeedOf(player)
	if typeof(player) == "Instance" then
		return UpgradeService.WalkSpeed(player)
	end
	return StarterPlayer.CharacterWalkSpeed
end

local function showCharacter(character, player)
	local state = hidden[character]
	if state then
		hidden[character] = nil
		state.Added:Disconnect()
		for d, props in state.Parts do
			if d.Parent then
				for k, v in props do
					d[k] = v
				end
			end
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.WalkSpeed = walkSpeedOf(player)
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
		humanoid.JumpPower = StarterPlayer.CharacterJumpPower
	end
end

-- Where an avatar stands on foot (join, respawn, after Stop): the middle of the spawn area beside Track 1.
function CarService.WalkSpawnCFrame()
	local track = Workspace:FindFirstChild("Track")
	local start = track and track:FindFirstChild("Start", true) -- first track in the chain
	return SpawnArea.WalkCFrame(start and start.CFrame or CFrame.new(0, 0, 0))
end

-- Puts the avatar at the walk spawn. A real player's client owns its character's physics and, right after it leaves
-- the car, can send back its old position (beside where the car was) and undo a single server teleport: for
-- PLACE_HOLD seconds the avatar is put back whenever it is far from the spot (unless a newer request arrived).
local function placeAtWalkSpawn(player, character, gen, target)
	target = target or CarService.WalkSpawnCFrame()
	character:PivotTo(target)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
		end
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return -- fake players (tests) have no client to undo the teleport
	end
	task.spawn(function()
		local deadline = os.clock() + PLACE_HOLD
		while os.clock() < deadline and generation[player] == gen and character.Parent do
			RunService.Heartbeat:Wait()
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				local off = root.Position - target.Position
				if Vector2.new(off.X, off.Z).Magnitude > PLACE_SLACK then
					character:PivotTo(target)
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
end

local function removeCar(player)
	local run = runs[player]
	runs[player] = nil
	if run then
		run:Destroy() -- commits the Speed gained since the last commit
	end
	local weld = carryWelds[player]
	carryWelds[player] = nil
	if weld then
		weld:Destroy()
	end
	local car = cars[player]
	cars[player] = nil
	if car then
		car:Destroy()
	end
end

-- The character the player races as: the equipped one (attribute EquippedCar), else the starter.
local function characterIdOf(player)
	local id = typeof(player) == "Instance" and player:GetAttribute("EquippedCar")
	return type(id) == "string" and CharacterCatalog.Get(id) and id or CharacterCatalog.STARTER_ID
end

local function setState(player, enabled)
	racing[player] = enabled
	generation[player] = (generation[player] or 0) + 1
	player:SetAttribute("AutoRacing", enabled)
	if not enabled then
		player:SetAttribute("RaceEvent", "Off")
	end
	return generation[player]
end

local standUp -- forward declaration (defined below)

-- A start is one step (the runner has no seat to wait for): the runner is built at the start line (held there for a
-- duel), the hidden avatar is welded to its Torso, and RaceService starts the run. RaceEvent goes "Racing".
-- Duel mode (duel = { Track, Slot, OnSeated }, docs/DUEL_SPEC.md): the runner waits at the picked track's start;
-- OnSeated() is called and CarService.ReleaseDuel starts the race. Slot 2 waits DUEL_SLOT_GAP studs to the left.
local function spawnCar(player, character, gen, duel)
	removeCar(player)
	character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")
	if generation[player] ~= gen then
		return
	end
	hideCharacter(character)

	local start = RaceService.TrackStartCFrame(RaceService.StartTrackFor(player)) or CarService.WalkSpawnCFrame()
	if duel then
		start = RaceService.TrackStartCFrame(duel.Track) * CFrame.new(-DUEL_SLOT_GAP * ((duel.Slot or 1) - 1), 0, 0)
	end
	local car = RunnerFactory.build(characterIdOf(player))
	car.Name = "Runner_" .. tostring(player.Name)
	RaceService.SetCarGroup(car)
	car:SetAttribute("AutoRace", true)
	VehicleEffects.Apply(car, player)
	car:PivotTo(start)
	car:SetAttribute("Owner", userIdOf(player) or 0) -- 0: a test's fake player (no client draws it)
	CollectionService:AddTag(car, CarService.RUNNER_TAG)
	car.Parent = Workspace
	cars[player] = car

	-- The hidden avatar rides inside the Torso: the camera and respawn keep working, nothing can push it
	character:PivotTo(car.PrimaryPart.CFrame)
	local weld = Instance.new("Weld")
	weld.Name = "RunnerCarry"
	weld.Part0 = car.PrimaryPart
	weld.Part1 = root
	weld.Parent = root
	carryWelds[player] = weld

	if duel then
		player:SetAttribute("RaceEvent", "Teleporting")
		duel.OnSeated()
		return
	end
	local run = RaceService.Attach(player, car)
	runs[player] = run
	player:SetAttribute("RaceEvent", "Racing")
end

-- Puts the avatar back on its feet at the walk spawn, visible and able to walk.
function standUp(player, gen)
	local character = characters[player]
	removeCar(player)
	if not character or not character.Parent then
		return
	end
	showCharacter(character, player)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) -- it was carried, not standing: stand up at once
	end
	placeAtWalkSpawn(player, character, gen)
end

local function isAlive(character)
	local humanoid = character and character.Parent and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Makes `character` the player's current avatar, dropping what was kept for the previous one.
local function adopt(player, character)
	local old = characters[player]
	if old and old ~= character and hidden[old] then
		hidden[old].Added:Disconnect()
		hidden[old] = nil
	end
	characters[player] = character
	-- The car goes when the avatar dies, however it got the car (joined racing, or resumed after walking)
	if not watched[character] then
		watched[character] = true
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Once(function()
			if characters[player] == character then
				removeCar(player)
			end
		end)
	end
end

-- Gives `character` a car and starts auto racing it.
function CarService.Attach(player, character)
	adopt(player, character)
	local gen = setState(player, true)
	spawnCar(player, character, gen)
end

function CarService.IsAutoRacing(player)
	return racing[player] == true
end

function CarService.GetCar(player)
	return cars[player]
end

-- The avatar CarService knows for this player (Attach / OnCharacter), else a real player's Character.
function CarService.GetCharacter(player)
	local character = characters[player]
	if character and character.Parent then
		return character
	end
	if typeof(player) == "Instance" and player:IsA("Player") then
		return player.Character
	end
	return nil
end

function CarService.GetRun(player)
	return runs[player]
end

-- Turns auto race on (fresh car at the start) or off (avatar on foot beside the track). Returns the state.
-- Anything but a boolean is ignored. The last request wins, even while an earlier one is still seating.
-- `duel` (server only, DuelService): see spawnCar.
function CarService.SetAutoRace(player, enabled, duel)
	if type(enabled) ~= "boolean" or enabled == CarService.IsAutoRacing(player) then
		return CarService.IsAutoRacing(player)
	end
	local character = characters[player]
	if enabled and not isAlive(character) then
		return CarService.IsAutoRacing(player) -- no avatar to seat (dead or not spawned yet)
	end
	local gen = setState(player, enabled)
	lastPadStart[player] = os.clock() -- the StartPad waits START_COOLDOWN after any start or stop
	if enabled then
		spawnCar(player, character, gen, duel)
	else
		standUp(player, gen) -- removing the car destroys its run; the run cashes its bank out
	end
	return CarService.IsAutoRacing(player)
end

-- Puts the avatar on foot at cf (admin /tp vfxarea and /tp home, ADMIN_COMMANDS_SPEC): stops auto racing first,
-- then holds it there like the walk spawn. False when there is no live avatar.
function CarService.Teleport(player, cf)
	local character = CarService.GetCharacter(player)
	if not isAlive(character) then
		return false
	end
	if CarService.IsAutoRacing(player) then
		CarService.SetAutoRace(player, false)
	end
	local gen = setState(player, false) -- a new generation ends the walk-spawn hold of that Stop
	lastPadStart[player] = os.clock()
	placeAtWalkSpawn(player, character, gen, cf)
	return true
end

-- The equipped character changed (attribute EquippedCar): the live runner is re-skinned as that character in place
-- (same model and distance, aura and trail kept) and its run takes the new cruise speed at once.
function CarService.ApplyCharacter(player)
	local car = cars[player]
	if not (car and car.Parent) then
		return
	end
	RunnerFactory.Restyle(car, characterIdOf(player))
	VehicleEffects.Apply(car, player)
	local run = runs[player]
	if run and run.Refresh then
		run:Refresh()
	end
end

-- Releases a held duel car and starts its duel run (duel = { Track, OnFinish }). Returns the run, or nil.
function CarService.ReleaseDuel(player, duel)
	local car = cars[player]
	local route = RaceService.GetRoute()
	if not (car and car.PrimaryPart and route and racing[player] == true) or runs[player] then
		return nil
	end
	local run = RaceService.NewRun(car, route, player, { Duel = duel })
	runs[player] = run
	player:SetAttribute("RaceEvent", "Racing")
	return run
end

-- A part touched the StartPad: if it belongs to `player`'s living, visible avatar that is on foot, auto racing
-- starts (unless the player stopped or started less than SpawnArea.START_COOLDOWN ago). Returns true if it started.
function CarService.PadTouched(player, hit)
	if player == nil or racing[player] == true or typeof(hit) ~= "Instance" then
		return false
	end
	local character = characters[player]
	if not isAlive(character) or hidden[character] or not hit:IsDescendantOf(character) then
		return false
	end
	local last = lastPadStart[player]
	if last and os.clock() - last < SpawnArea.START_COOLDOWN then
		return false
	end
	return CarService.SetAutoRace(player, true)
end

-- A new avatar (join or respawn) is always on foot in the spawn area: any car left is removed (its run cashes out).
function CarService.OnCharacter(player, character)
	adopt(player, character)
	local gen = setState(player, false)
	removeCar(player)
	if player:GetAttribute("Unbanked") == nil then
		player:SetAttribute("Unbanked", 0) -- the HUD's UNBANKED row reads it from the start
	end
	character:WaitForChild("HumanoidRootPart")
	if generation[player] ~= gen then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = walkSpeedOf(player)
	end
	placeAtWalkSpawn(player, character, gen)
end

local function forget(player)
	removeCar(player)
	local character = characters[player]
	if character and hidden[character] then
		hidden[character].Added:Disconnect()
		hidden[character] = nil
	end
	characters[player] = nil
	racing[player] = nil
	generation[player] = nil
	lastToggle[player] = nil
	lastPadStart[player] = nil
end

function CarService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	local remote = remotes:FindFirstChild("SetAutoRace")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "SetAutoRace"
		remote.Parent = remotes
	end
	remote.OnServerEvent:Connect(function(player, enabled)
		if type(enabled) ~= "boolean" then
			return
		end
		local now = os.clock()
		if lastToggle[player] and now - lastToggle[player] < CarService.TOGGLE_COOLDOWN then
			return
		end
		lastToggle[player] = now
		CarService.SetAutoRace(player, enabled)
	end)

	local function onCharacter(player, character)
		CarService.OnCharacter(player, character)
	end

	local function watchPad(pad)
		pad.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local player = model and Players:GetPlayerFromCharacter(model)
			if player then
				CarService.PadTouched(player, hit)
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal(SpawnArea.TAG):Connect(watchPad)
	for _, pad in CollectionService:GetTagged(SpawnArea.TAG) do
		watchPad(pad)
	end
	local function onPlayer(player)
		player:GetAttributeChangedSignal("EquippedCar"):Connect(function()
			CarService.ApplyCharacter(player)
		end)
		for _, attribute in { "EquippedAura", "EquippedTrail" } do
			player:GetAttributeChangedSignal(attribute):Connect(function()
				local car = cars[player]
				if car and car.Parent then
					VehicleEffects.Apply(car, player)
				end
			end)
		end
		player.CameraMinZoomDistance = 10
		player.CameraMaxZoomDistance = 40
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	-- A Walkspeed purchase applies at once to an avatar on foot (a hidden, riding avatar keeps WalkSpeed 0)
	UpgradeService.OnChanged(function(player)
		local character = characters[player]
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and not hidden[character] then
			humanoid.WalkSpeed = walkSpeedOf(player)
		end
	end)
	PlayerData.OnLeaving(forget) -- before the leave save, so the run's last Speed gain is saved
	Players.PlayerRemoving:Connect(forget)
end

return CarService
