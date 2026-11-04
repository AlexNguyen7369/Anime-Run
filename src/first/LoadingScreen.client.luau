--!nonstrict
-- The loading screen (owner 2026-11-03, design doc 4.24): the logo and a bar on every join. It opens when what a player sees
-- first has loaded on this client, and not before 8 seconds; the rest loads behind the game. The bar shows real progress. Runs from ReplicatedFirst, so Shared and
-- the client modules are read only once the game has loaded.
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MIN_SECONDS = 8 -- owner
local MAX_SECONDS = 90 -- proposed: a stuck asset or server must never trap a player here for good
local QUEUE_QUIET = 1 -- proposed: seconds the content queue stays empty before it counts as done
local QUEUE_GRACE = 4 -- proposed: most seconds to wait for the queue once everything wanted is preloaded
local WORKERS = 4 -- proposed: PreloadAsync calls running at once
local CHUNK = 16 -- assets per PreloadAsync call, so the bar moves as they land
local LOGO = "rbxassetid://127883918864517" -- assets/logo/AnimeRunLogo.png, owner's art

local root = Instance.new("ScreenGui")
root.Name = "LoadingScreen"
root.ResetOnSpawn = false
root.IgnoreGuiInset = true
root.DisplayOrder = 1000 -- over everything, the starter popup included
root.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local back = Instance.new("Frame")
back.Name = "Back"
back.Size = UDim2.fromScale(1, 1)
back.BorderSizePixel = 0
back.BackgroundColor3 = Color3.new(1, 1, 1)
back.Active = true -- swallows clicks to the HUD behind it
back.Parent = root
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new(Color3.fromRGB(10, 14, 34), Color3.fromRGB(28, 22, 54))
gradient.Parent = back

local logo = Instance.new("ImageLabel")
logo.Name = "Logo"
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.42)
logo.Size = UDim2.fromScale(0.72, 0.6)
logo.BackgroundTransparency = 1
logo.Image = LOGO
logo.ScaleType = Enum.ScaleType.Fit
logo.Parent = back
task.spawn(function()
	ContentProvider:PreloadAsync({ logo }) -- first thing on screen
end)

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, 0.78)
track.Size = UDim2.new(0.5, 0, 0, 20)
track.BackgroundColor3 = Color3.fromRGB(38, 42, 72)
track.BorderSizePixel = 0
track.Parent = back
Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
local trackLimit = Instance.new("UISizeConstraint")
trackLimit.MaxSize = Vector2.new(640, 20)
trackLimit.MinSize = Vector2.new(220, 20)
trackLimit.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.BorderSizePixel = 0
fill.Parent = track
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
local fillColor = Instance.new("UIGradient")
fillColor.Color = ColorSequence.new({ -- the logo's blue to orange
	ColorSequenceKeypoint.new(0, Color3.fromRGB(57, 200, 255)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(235, 245, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 138, 30)),
})
fillColor.Parent = fill

local label = Instance.new("TextLabel")
label.Name = "Status"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0.78, 18)
label.Size = UDim2.new(0.6, 0, 0, 26)
label.BackgroundTransparency = 1
label.Font = Enum.Font.FredokaOne
label.TextSize = 20
label.TextColor3 = Color3.fromRGB(220, 226, 245)
label.Text = "Loading 0%"
label.Parent = back

-- What this client must have before the screen opens: the plaza and Track 1 world, then every unique mesh, texture and
-- image around the plaza, on the HUD and on the characters on screen, then the content queue (with a short grace).
local preloadTotal, preloadDone, preloadFinished = 0, 0, false
local preloadEndedAt = nil

local function collect(found, seen, source)
	for _, d in source:GetDescendants() do
		local key = nil
		if d:IsA("MeshPart") then
			key = d.MeshId .. "|" .. d.TextureID
		elseif d:IsA("Sky") or d:IsA("Decal") or d:IsA("Texture") then
			key = d
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			key = d.Image
		end
		if key and key ~= "" and key ~= "|" and not seen[key] then
			seen[key] = true
			table.insert(found, d)
		end
	end
end

local function serverReady()
	local models = ReplicatedStorage:FindFirstChild("CharacterModels")
	return ReplicatedStorage:GetAttribute("TerrainNearReady") == true
		and models ~= nil
		and models:GetAttribute("Ready") == true
		and ReplicatedStorage:GetAttribute("PlazaReady") == true
end

task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	while not serverReady() do
		task.wait(0.1)
	end
	-- StreamingEnabled: the plaza's parts reach this client only once it asks for them.
	pcall(function()
		Players.LocalPlayer:RequestStreamAroundAsync(Vector3.zero)
	end)
	local found, seen = {}, {}
	-- Character models: only those on screen at once (the Legends, the sky-loop runners, this player's team). Their folder
	-- names are character ids; a new player's team is empty until the starter pick.
	local later = {}
	local wanted = {}
	for _, id in string.split(Players.LocalPlayer:GetAttribute("Team") or "", ",") do
		wanted[id] = true
	end
	pcall(function()
		local Layout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlazaAssets"))
		for _, row in Layout.Legends do
			wanted[row.Id] = true
		end
	end)
	for _, id in { "leaf_hero", "sea_captain", "db_hero" } do -- starters' models: the pick and the sky loop show them
		wanted[id] = true
	end
	for _, character in ReplicatedStorage:WaitForChild("CharacterModels"):GetChildren() do
		if wanted[character.Name] then
			collect(found, seen, character)
		else
			table.insert(later, character)
		end
	end
	-- The plaza's sky faces: the client may not have swapped them into Lighting yet (image ids preload as strings)
	pcall(function()
		local sky =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BiomeEnvironment")).Asset(0, "SkyGolden")
		local faces = {}
		for _, id in sky.Faces do
			faces[id] = true
		end
		for id in faces do
			table.insert(found, id)
		end
	end)
	for _, source in
		{
			Workspace:FindFirstChild("PlazaDressing"),
			Workspace:FindFirstChild("Workshops"),
			Workspace:FindFirstChild("SpawnArea"),
			Lighting,
			Players.LocalPlayer:FindFirstChild("PlayerGui"),
		}
	do
		collect(found, seen, source)
	end
	preloadTotal = #found
	-- Several calls at once: one after another took most of the wait on a slow connection
	local cursor = 1
	local workers = 0
	for _ = 1, WORKERS do
		workers += 1
		task.spawn(function()
			while cursor <= #found do
				local first = cursor
				cursor += CHUNK
				local last = math.min(first + CHUNK - 1, #found)
				pcall(function() -- a failed asset reports failure and still counts as tried
					ContentProvider:PreloadAsync(table.move(found, first, last, 1, {}))
				end)
				preloadDone += last - first + 1
			end
			workers -= 1
		end)
	end
	while workers > 0 do
		task.wait()
	end
	preloadEndedAt = os.clock()
	preloadFinished = true
	-- Characters nobody on screen wears and the other Dojo tiers load behind the game
	task.spawn(function()
		pcall(function()
			table.insert(later, ReplicatedStorage:FindFirstChild("PlazaTierMeshes"))
			ContentProvider:PreloadAsync(later)
		end)
	end)
end)

-- Real progress, 0..1, and whether everything is done.
local peak = 1
local queueEmptySince = nil
local function realProgress(now)
	local queue = ContentProvider.RequestQueueSize
	peak = math.max(peak, queue)
	queueEmptySince = queue == 0 and (queueEmptySince or now) or nil
	local models = ReplicatedStorage:FindFirstChild("CharacterModels")
	local server = (
		(ReplicatedStorage:GetAttribute("TerrainNearReady") == true and 1 or 0)
		+ (models and models:GetAttribute("Ready") == true and 1 or 0)
		+ (ReplicatedStorage:GetAttribute("PlazaReady") == true and 1 or 0)
	) / 3
	local preload = preloadFinished and 1 or (preloadTotal > 0 and preloadDone / preloadTotal or 0)
	local real = server * 0.45 + preload * 0.45 + (1 - queue / peak) * 0.1
	-- The queue also holds streamed far-away assets, so it gets a short grace, not an open-ended wait
	local quiet = queueEmptySince ~= nil and now - queueEmptySince >= QUEUE_QUIET
	local done = preloadFinished and (quiet or now - preloadEndedAt >= QUEUE_GRACE)
	return real, done
end

local started = os.clock()
local shown = 0
while true do
	local now = os.clock()
	local elapsed = now - started
	local real, done = realProgress(now)
	if (done and elapsed >= MIN_SECONDS) or elapsed >= MAX_SECONDS then
		if not done then
			warn("[LoadingScreen] opened at the time limit with assets still loading")
		end
		break
	end
	-- Follows the real value, and stays under 100% until the screen really opens
	shown = math.max(shown, math.min(real, elapsed / MIN_SECONDS, 0.99))
	fill.Size = UDim2.fromScale(shown, 1)
	label.Text = string.format("Loading %d%%", math.floor(shown * 100))
	RunService.RenderStepped:Wait()
end
fill.Size = UDim2.fromScale(1, 1)
label.Text = "Loading 100%"
print(string.format("[LoadingScreen] opened after %.1f s, %d assets preloaded", os.clock() - started, preloadTotal))

-- Design doc 4.20: through Client/UiMotion, which exists by now; without it (a failed load) the plain tween service.
local fade = TweenInfo.new(0.4)
local function fadeOut(instance, goal)
	TweenService:Create(instance, fade, goal):Play()
end
pcall(function()
	local UiMotion = require(Players.LocalPlayer.PlayerScripts:FindFirstChild("Client"):FindFirstChild("UiMotion"))
	fadeOut = function(instance, goal)
		UiMotion.Create(instance, fade, goal):Play()
	end
end)
fadeOut(back, { BackgroundTransparency = 1 })
fadeOut(logo, { ImageTransparency = 1 })
fadeOut(track, { BackgroundTransparency = 1 })
fadeOut(fill, { BackgroundTransparency = 1 })
fadeOut(label, { TextTransparency = 1 })
task.wait(0.4)
root:Destroy()
