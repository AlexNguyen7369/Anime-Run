--!nonstrict
-- Server-owned prestige reset. Cars and upgrades survive;
-- Money resets (design doc 4.14; there is no Speed stat), and the permanent rebirth level increases.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.RebirthConfig)
local HudFormat = require(Shared.HudFormat)

local RebirthService = {}
local lastRequest = setmetatable({}, { __mode = "k" })
RebirthService.REMOTE_COOLDOWN = 0.5

local function stats(player)
	local folder = player:FindFirstChild("leaderstats")
	return folder, folder and folder:FindFirstChild("Money")
end

-- GachaService owns StatPoints; required lazily because it is loaded after this module in some start orders
local function refreshStatPoints(player)
	require(script.Parent.GachaService).RefreshPoints(player)
end

function RebirthService.Setup(player)
	if player:GetAttribute("RebirthLevel") == nil then
		player:SetAttribute("RebirthLevel", Config.DEFAULT_LEVEL)
	end
	-- Player list shows leaderstats.Rebirth after Money (REBIRTH_SPEC "Player list"); wait for Money so the order
	-- holds. It follows the attribute, so admin commands and loads update it too.
	local folder = player:FindFirstChild("leaderstats")
	if not folder or not folder:FindFirstChild("Money") or folder:FindFirstChild("Rebirth") then
		return
	end
	local shown = Instance.new("IntValue")
	shown.Name = "Rebirth"
	local function refresh()
		shown.Value = Config.CleanLevel(player:GetAttribute("RebirthLevel"))
	end
	refresh()
	player:GetAttributeChangedSignal("RebirthLevel"):Connect(refresh)
	shown.Parent = folder
end

function RebirthService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	local level = Config.CleanLevel(saved.RebirthLevel)
	player:SetAttribute("RebirthLevel", level)
	RebirthService.Setup(player)
	refreshStatPoints(player)
end

function RebirthService.Requirements(player)
	return Config.Requirements(player:GetAttribute("RebirthLevel"))
end

function RebirthService.Rebirth(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < RebirthService.REMOTE_COOLDOWN then
		return false, "Please wait"
	end
	lastRequest[player] = now
	if player:GetAttribute("DataFailed") or not player:GetAttribute("DataLoaded") then
		return false, "Data not loaded"
	end
	if player:GetAttribute("AutoRacing") == true then
		return false, "Stop Auto before rebirthing"
	end
	local folder, money = stats(player)
	if not folder or not money then
		return false, "Stats not ready"
	end
	local level = Config.CleanLevel(player:GetAttribute("RebirthLevel"))
	if level >= Config.MAX_LEVEL then
		return false, "Max rebirth"
	end
	if not Config.CanRebirth(level, money.Value) then
		return false, "Reach " .. HudFormat.MoneyText(Config.Requirements(level).Money)
	end
	local nextLevel = level + 1
	money.Value = 0
	player:SetAttribute("RebirthLevel", nextLevel)
	refreshStatPoints(player) -- each rebirth adds RebirthConfig.POINTS_PER_REBIRTH free stat points
	local gacha = require(script.Parent.GachaService)
	if type(gacha.RefreshMultipliers) == "function" then
		gacha.RefreshMultipliers(player)
	end
	return true, nextLevel
end

function RebirthService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local remote = remotes:FindFirstChild("Rebirth") or Instance.new("RemoteFunction")
	remote.Name = "Rebirth"
	remote.Parent = remotes
	remote.OnServerInvoke = RebirthService.Rebirth
	Players.PlayerAdded:Connect(RebirthService.Setup)
	for _, player in Players:GetPlayers() do
		RebirthService.Setup(player)
	end
end

return RebirthService
