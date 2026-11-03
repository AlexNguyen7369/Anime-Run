--!nonstrict
-- Mechanical Workshop, server side (docs/WORKSHOP_SPEC.md). Owns the 7 plots in the spawn area: assigns one to each
-- joining player, builds their workshop and frees it when they leave. No passive gain since 2026-11-03 (design doc
-- 4.19): the workshop boosts the player's chosen stat instead (GachaService.WorkshopBoost, Remotes.SetWorkshopStat).
-- Clients only see: Workspace.Workshops.Plot_N (Owner attribute, signs) and player attributes Plot, WorkshopLevel,
-- WorkshopStat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared.CharacterCatalog)
local RunnerFactory = require(Shared.RunnerFactory)
local Workshop = require(Shared.Workshop)
local WorkshopBuilder = require(Shared.WorkshopBuilder)
local WorkshopConfig = require(Shared.WorkshopConfig)
local CarService = require(script.Parent.CarService)
local GachaService = require(script.Parent.GachaService)

local WorkshopService = {}

local startCFrame = nil -- Track 1's Start CFrame, set by BuildPlots
local plots = {} -- index -> Plot_N model
local owners = {} -- index -> player
local plotOf = setmetatable({}, { __mode = "k" }) -- player -> index

local function userIdOf(player)
	if player:IsA("Player") then
		return player.UserId
	end
	local id = player:GetAttribute("UserId")
	return type(id) == "number" and id ~= 0 and id or -1 -- fakes (tests): never 0, which means "free"
end

local function nameOf(player)
	if player:IsA("Player") then
		return player.DisplayName
	end
	local name = player:GetAttribute("DisplayName")
	return type(name) == "string" and name or player.Name
end

local liveFolder = nil -- Workspace.Workshops, built by Start
local lastBuy = setmetatable({}, { __mode = "k" })
local openRemote = nil

local function nearUpgrade(player)
	local index = plotOf[player]
	local plot = index and plots[index]
	if not plot or owners[index] ~= player or plot:GetAttribute("Owner") ~= userIdOf(player) then
		return false
	end
	local workshop = plot and plot:FindFirstChild("Workshop")
	local pad = workshop and workshop:FindFirstChild("UpgradePad")
	local character = CarService.GetCharacter(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return pad
		and root
		and humanoid
		and humanoid.Health > 0
		and not CarService.IsAutoRacing(player)
		and player:GetAttribute("AutoRacing") ~= true
		and (root.Position - pad.Position).Magnitude <= WorkshopConfig.UPGRADE_DISTANCE
end

local function bindUpgrade(player, workshop)
	local pad = workshop:FindFirstChild("UpgradePad")
	if not pad then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Upgrade"
	prompt.ObjectText = nameOf(player) .. "'s Workshop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = WorkshopConfig.UPGRADE_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(function(who)
		if who == player and nearUpgrade(player) and openRemote then
			openRemote:FireClient(player)
		end
	end)
end

local function buildFolder(newStartCFrame, parent)
	local folder = Instance.new("Folder")
	folder.Name = "Workshops"
	local built = {}
	for i = 1, WorkshopConfig.PLOT_COUNT do
		local plot = WorkshopBuilder.BuildPlot(i, Workshop.PlotCFrame(newStartCFrame, i))
		plot.Parent = folder
		built[i] = plot
	end
	folder.Parent = parent
	return folder, built
end

-- Builds a "Workshops" folder with PLOT_COUNT empty plots for Track 1's Start CFrame under `parent` (default
-- Workspace) and returns it. Only the plots Start builds are assigned: building elsewhere never moves the live ones.
function WorkshopService.BuildPlots(newStartCFrame, parent)
	parent = parent or Workspace
	local old = parent:FindFirstChild("Workshops")
	if old and old ~= liveFolder then
		old:Destroy()
	end
	local folder = buildFolder(newStartCFrame, parent)
	return folder
end

-- A static runner rig of `spec` (docs/WORLD_REDESIGN_SPEC.md section 1: no car models), named "Runner", feet on
-- `cframe`, at `scale`; every part anchored and out of the physics (RunnerFactory builds it that way).
local function displayRunner(spec, cframe, scale)
	local rig = RunnerFactory.build(spec.Id)
	rig.Name = "Runner"
	local label = rig:FindFirstChild("NameLabel")
	if label then
		label:Destroy() -- the pedestal has its own label
	end
	rig:ScaleTo(scale)
	rig:PivotTo(cframe * CFrame.new(0, RunnerFactory.HIP_HEIGHT * scale, 0))
	return rig
end

-- Puts a static copy of each showcased character on the workshop's pedestals, with a name / rarity label.
local function placeShowcase(player, workshop)
	local ids = GachaService.ShowcaseList(player)
	for i = 1, 3 do
		local pedestal = workshop:FindFirstChild("ShowcasePedestal_" .. i)
		if pedestal then
			for _, child in pedestal:GetChildren() do
				child:Destroy()
			end
			local spec = ids[i] and CharacterCatalog.Get(ids[i])
			if spec then
				displayRunner(
					spec,
					pedestal.CFrame * CFrame.new(0, pedestal.Size.Y / 2, 0),
					WorkshopConfig.SHOWCASE_CAR_SCALE
				).Parent =
					pedestal
			end
			if spec then
				local gui = Instance.new("BillboardGui")
				gui.Name = "ShowcaseLabel"
				gui.Size = UDim2.fromOffset(160, 40)
				gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
				gui.MaxDistance = WorkshopConfig.SHOWCASE_LABEL_DISTANCE
				gui.Parent = pedestal
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBlack
				label.TextScaled = true
				label.TextColor3 = Color3.new(1, 1, 1)
				label.TextStrokeTransparency = 0.3
				label.Text = spec.Name .. "\n" .. spec.Rarity
				label.Parent = gui
			end
		end
	end
end

local showcaseWatch = setmetatable({}, { __mode = "k" }) -- player -> connection

local function watchShowcase(player)
	if showcaseWatch[player] then
		return
	end
	showcaseWatch[player] = player.AttributeChanged:Connect(function(name)
		if name ~= "Showcase" then
			return
		end
		local index = plotOf[player]
		local workshop = index and plots[index] and plots[index]:FindFirstChild("Workshop")
		if workshop then
			placeShowcase(player, workshop)
		end
	end)
end

-- Gives the player the lowest free plot and builds their workshop. Returns the plot index (0 = none free).
function WorkshopService.Assign(player)
	if plotOf[player] then
		return plotOf[player]
	end
	if player:GetAttribute("WorkshopLevel") == nil then
		player:SetAttribute("WorkshopLevel", 1)
	end
	local taken = {}
	for i, owner in owners do
		if owner.Parent then
			taken[i] = true
		else
			WorkshopService.Release(owner) -- the owner left without a release: free the plot
		end
	end
	local index = plots[1] and Workshop.FreePlot(taken) or 0
	player:SetAttribute("Plot", index)
	if index == 0 then
		warn(
			"[Workshop] no free plot for "
				.. player.Name
				.. " (Max Players must be "
				.. WorkshopConfig.PLOT_COUNT
				.. ")"
		)
		return 0
	end
	owners[index] = player
	plotOf[player] = index
	local plot = plots[index]
	plot:SetAttribute("Owner", userIdOf(player))
	WorkshopBuilder.SetSign(plot, nameOf(player))
	local workshop = WorkshopBuilder.BuildWorkshop(
		Workshop.CleanLevel(player:GetAttribute("WorkshopLevel")),
		Workshop.PlotCFrame(startCFrame, index)
	)
	workshop.Parent = plot
	bindUpgrade(player, workshop)
	placeShowcase(player, workshop)
	watchShowcase(player)
	return index
end

-- Removes the player's workshop and frees their plot.
function WorkshopService.Release(player)
	local index = plotOf[player]
	plotOf[player] = nil
	if showcaseWatch[player] then
		showcaseWatch[player]:Disconnect()
		showcaseWatch[player] = nil
	end
	player:SetAttribute("Plot", 0)
	if not index then
		return
	end
	if owners[index] == player then
		owners[index] = nil
	end
	local plot = plots[index]
	if plot then
		local workshop = plot:FindFirstChild("Workshop")
		if workshop then
			workshop:Destroy()
		end
		plot:SetAttribute("Owner", 0)
		WorkshopBuilder.SetSign(plot, nil)
	end
end

-- The player's plot index (0 = none).
function WorkshopService.PlotOf(player)
	return plotOf[player] or 0
end

-- Client supplies no price or level. Every guard and the debit run without yielding.
function WorkshopService.BuyUpgrade(player)
	if player:GetAttribute("DataFailed") or not player:GetAttribute("DataLoaded") then
		return false, "Data not loaded"
	end
	if not nearUpgrade(player) then
		return false, "Approach your workshop upgrade slab"
	end
	local level = Workshop.CleanLevel(player:GetAttribute("WorkshopLevel"))
	local nextLevel = WorkshopConfig.Levels[level + 1]
	if not nextLevel then
		return false, "Maximum level"
	end
	local stats = player:FindFirstChild("leaderstats")
	local money = stats and stats:FindFirstChild("Money")
	if not money or money.Value < nextLevel.Price then
		return false, "Not enough Money"
	end
	local index = plotOf[player]
	local replacement = WorkshopBuilder.BuildWorkshop(level + 1, Workshop.PlotCFrame(startCFrame, index))
	money.Value -= nextLevel.Price
	player:SetAttribute("WorkshopLevel", level + 1)
	local old = plots[index]:FindFirstChild("Workshop")
	if old then
		old:Destroy()
	end
	replacement.Parent = plots[index]
	bindUpgrade(player, replacement)
	placeShowcase(player, replacement)
	return true, "Upgraded to level " .. (level + 1)
end

-- Sets the stat the workshop boosts (design doc 4.19): one of WorkshopConfig.STATS, anything else changes nothing.
-- Allowed at any time; a run in progress keeps the Speed / Stamina it started with. Returns ok, reason.
function WorkshopService.SetStat(player, stat)
	if type(stat) ~= "string" or not table.find(WorkshopConfig.STATS, stat) then
		return false, "Not a workshop stat"
	end
	player:SetAttribute("WorkshopStat", stat) -- GachaService refreshes WorkshopBoost and the team on this change
	return true, "Workshop boosts " .. stat
end

-- Save fields (PlayerData VERSION 4 saves WorkshopLevel itself, WorkshopStat since 2026-11-03):
-- { WorkshopLevel = n, WorkshopStat = stat }.
function WorkshopService.Snapshot(player)
	return {
		WorkshopLevel = Workshop.CleanLevel(player:GetAttribute("WorkshopLevel")),
		WorkshopStat = Workshop.CleanStat(player:GetAttribute("WorkshopStat")),
	}
end

-- Loads saved fields (missing level = 1, clamped to 1 .. MAX_LEVEL; missing or unknown stat = Money).
function WorkshopService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	player:SetAttribute("WorkshopLevel", Workshop.CleanLevel(saved.WorkshopLevel))
	player:SetAttribute("WorkshopStat", Workshop.CleanStat(saved.WorkshopStat))
end

-- Builds the plots, assigns plots on join (after the save loads, so the saved level is built), frees them on leave.
function WorkshopService.Start(newStartCFrame)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	openRemote = remotes:FindFirstChild("WorkshopOpen") or Instance.new("RemoteEvent")
	openRemote.Name = "WorkshopOpen"
	openRemote.Parent = remotes
	local buyRemote = remotes:FindFirstChild("WorkshopUpgrade") or Instance.new("RemoteFunction")
	buyRemote.Name = "WorkshopUpgrade"
	buyRemote.Parent = remotes
	buyRemote.OnServerInvoke = function(player)
		local at = os.clock()
		if lastBuy[player] and at - lastBuy[player] < WorkshopConfig.REMOTE_COOLDOWN then
			return false, "Please wait"
		end
		lastBuy[player] = at
		return WorkshopService.BuyUpgrade(player)
	end
	local statRemote = remotes:FindFirstChild("SetWorkshopStat") or Instance.new("RemoteFunction")
	statRemote.Name = "SetWorkshopStat"
	statRemote.Parent = remotes
	local lastStat = setmetatable({}, { __mode = "k" })
	statRemote.OnServerInvoke = function(player, stat)
		local at = os.clock()
		if lastStat[player] and at - lastStat[player] < WorkshopConfig.REMOTE_COOLDOWN then
			return false, "Please wait"
		end
		lastStat[player] = at
		return WorkshopService.SetStat(player, stat)
	end
	local old = Workspace:FindFirstChild("Workshops")
	if old then
		old:Destroy()
	end
	startCFrame = newStartCFrame
	plots, owners = {}, {}
	table.clear(plotOf)
	liveFolder, plots = buildFolder(newStartCFrame, Workspace)
	local function onPlayer(player)
		while player.Parent and not player:GetAttribute("DataLoaded") and not player:GetAttribute("DataFailed") do
			task.wait(0.2)
		end
		if player.Parent then
			WorkshopService.Assign(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(WorkshopService.Release)
end

return WorkshopService
