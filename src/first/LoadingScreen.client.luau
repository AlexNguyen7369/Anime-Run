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
local LATER_CHUNK = 4 -- placeholder: character folders per PreloadAsync call once the screen has opened
local LATER_PAUSE = 0.5 -- placeholder: seconds between those calls, so they do not crowd Track 1 streaming on phones
local LOGO = "rbxassetid://127883918864517" -- assets/logo/AnimeRunLogo.png, owner's art
-- assets/ui/loading/SakuraGateBackdrop.png, intro draft B3 "Distant crowd" (owner 2026-11-11). Decal 77191663094973.
local BACKDROP = "rbxassetid://81384921997104" -- resolved in Studio 2026-11-11
local CYAN = Color3.fromRGB(0, 240, 255) -- the draft's bar
local PINK = Color3.fromRGB(255, 110, 180)

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

-- Behind the logo and bar (ZIndex 0); Crop fills any aspect. Preloaded before anything else so it shows at once.
local backdrop = Instance.new("ImageLabel")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundTransparency = 1
backdrop.ScaleType = Enum.ScaleType.Crop
backdrop.ZIndex = 0
backdrop.Parent = back
if BACKDROP ~= "rbxassetid://0" then
	backdrop.Image = BACKDROP
	task.spawn(function() -- queued first; not awaited, so a slow fetch never holds up the bar or the 90 s limit
		pcall(function()
			ContentProvider:PreloadAsync({ backdrop })
		end)
	end)
end

local logo = Instance.new("ImageLabel")
logo.Name = "Logo"
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.3) -- proposed, as in the draft
logo.Size = UDim2.fromScale(0.5, 0.36)
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
track.Position = UDim2.fromScale(0.5, 0.86) -- proposed, as in the draft
track.Size = UDim2.new(0.38, 0, 0, 22)
track.BackgroundColor3 = Color3.fromRGB(28, 20, 26) -- dark track
track.BorderSizePixel = 0
track.Parent = back
local outline = Instance.new("UIStroke")
outline.Color = PINK
outline.Thickness = 2
outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
outline.Parent = track
local trackLimit = Instance.new("UISizeConstraint")
trackLimit.MaxSize = Vector2.new(640, 22)
trackLimit.MinSize = Vector2.new(220, 22)
trackLimit.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = CYAN
fill.BorderSizePixel = 0
fill.Parent = track

local label = Instance.new("TextLabel")
label.Name = "Status"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0.86, 16) -- under the bar
label.Size = UDim2.new(0.6, 0, 0, 26)
label.BackgroundTransparency = 1
label.Font = Enum.Font.FredokaOne
label.TextSize = 20
label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeTransparency = 0.6
label.Text = "Loading 0%"
label.Parent = back

-- What this client must have before the screen opens: the plaza and Track 1 world, then every unique mesh, texture and
-- image around the plaza, on the HUD and on the characters on screen, then the content queue (with a short grace).
local preloadTotal, preloadDone, preloadFinished = 0, 0, false
local preloadEndedAt = nil
local modelsReady = false -- the on-screen characters' models are in place (CharacterModelService Loaded_<id>)
local wanted = {} -- character ids on screen at once; the others load once the screen has opened

-- Client/PanelSwitch's test: a closed panel is a hidden GuiObject above it; a ScreenGui can also be switched off.
-- Hidden panels load behind the game.
local function onScreen(inst)
	while inst do
		if (inst:IsA("GuiObject") and not inst.Visible) or (inst:IsA("LayerCollector") and not inst.Enabled) then
			return false
		end
		inst = inst.Parent
	end
	return true
end

local function collect(found, seen, source)
	for _, d in source:GetDescendants() do
		local key = nil
		if d:IsA("MeshPart") then
			key = d.MeshId .. "|" .. d.TextureID
		elseif d:IsA("Sky") or d:IsA("Decal") or d:IsA("Texture") then
			key = d
		elseif (d:IsA("ImageLabel") or d:IsA("ImageButton")) and not d:FindFirstAncestor("Gallery") then
			key = onScreen(d) and d.Image -- the Index's portraits load behind the game (RollToast)
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
	-- Character models: only those on screen at once (the exclusive pedestal, the sky-loop runners, this player's team).
	-- Their folder names are character ids; a new player's team is empty until the starter pick.
	for _, id in string.split(Players.LocalPlayer:GetAttribute("Team") or "", ",") do
		wanted[id] = true
	end
	pcall(function()
		local Layout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlazaAssets"))
		wanted[Layout.Exclusive.Id] = true
	end)
	for _, id in { "leaf_hero", "sea_captain", "db_hero" } do -- starters' models: the pick and the sky loop show them
		wanted[id] = true
	end
	-- Wait only for these models, not all of them (a failed one still turns Loaded_<id> true)
	local models = ReplicatedStorage:WaitForChild("CharacterModels")
	local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterModelAssets"))
	for id in wanted do
		while Assets[id] and models:GetAttribute("Loaded_" .. id) ~= true and models:GetAttribute("Ready") ~= true do
			task.wait(0.1)
		end
		local character = models:FindFirstChild(id)
		if character then
			collect(found, seen, character)
		end
	end
	modelsReady = true
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
end)

-- Real progress, 0..1, and whether everything is done.
local peak = 1
local queueEmptySince = nil
local function realProgress(now)
	local queue = ContentProvider.RequestQueueSize
	peak = math.max(peak, queue)
	queueEmptySince = queue == 0 and (queueEmptySince or now) or nil
	local server = (
		(ReplicatedStorage:GetAttribute("TerrainNearReady") == true and 1 or 0)
		+ (modelsReady and 1 or 0)
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
fadeOut(backdrop, { ImageTransparency = 1 })
fadeOut(logo, { ImageTransparency = 1 })
fadeOut(track, { BackgroundTransparency = 1 })
fadeOut(outline, { Transparency = 1 })
fadeOut(fill, { BackgroundTransparency = 1 })
fadeOut(label, { TextTransparency = 1, TextStrokeTransparency = 1 })
task.wait(0.4)
root:Destroy()

-- Characters nobody on screen wears and the other Dojo tiers load behind the game, a few at a time
local models = ReplicatedStorage:WaitForChild("CharacterModels")
while models:GetAttribute("Ready") ~= true do
	task.wait(1)
end
local later = {}
for _, character in models:GetChildren() do
	if not wanted[character.Name] then
		table.insert(later, character)
	end
end
table.insert(later, ReplicatedStorage:FindFirstChild("PlazaTierMeshes"))
for first = 1, #later, LATER_CHUNK do
	pcall(function()
		ContentProvider:PreloadAsync(table.move(later, first, math.min(first + LATER_CHUNK - 1, #later), 1, {}))
	end)
	task.wait(LATER_PAUSE)
end
