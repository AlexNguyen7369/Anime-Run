--!nonstrict
-- World 2's first-arrival welcome (docs/WORLD2_SPEC.md "Welcome", design doc 4.47). The server decides: the first time a
-- loaded player stays in World 2 it sets World2Welcomed (saved in Worlds.W2.Welcomed through PlayerData and
-- Shared/WorldSave) and World2WelcomeShow (this session only), which Client/World2Welcome shows once.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldConfig"))

local WorldWelcome = {}

WorldWelcome.WorldId = WorldConfig.Id -- test seam
WorldWelcome.InStudio = function() -- test seam
	return RunService:IsStudio()
end
-- Test seam: may the player stay in World 2? The arrival check's own rule (Server/WorldTravel.CanEnter: admins, or the
-- gate open and the opening rule met).
WorldWelcome.CanEnter = function(player)
	return (require(script.Parent.WorldTravel).CanEnter(player, 2))
end

-- Returns true when it gave the welcome now. A player Server/WorldTravel.Arrived sends back (CanEnter refuses them,
-- outside Studio) never stayed, so they are not welcomed.
function WorldWelcome.Check(player)
	if WorldWelcome.WorldId ~= 2 or player:GetAttribute("DataLoaded") ~= true then
		return false
	end
	if player:GetAttribute("World2Welcomed") == true or player:GetAttribute("Travelling") then
		return false
	end
	if not WorldWelcome.InStudio() and not WorldWelcome.CanEnter(player) then
		return false
	end
	player:SetAttribute("World2Welcomed", true)
	player:SetAttribute("World2WelcomeShow", true)
	return true
end

function WorldWelcome.Start()
	if WorldWelcome.WorldId ~= 2 then
		return
	end
	local Players = game:GetService("Players")
	local function watch(player)
		player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			WorldWelcome.Check(player)
		end)
		WorldWelcome.Check(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return WorldWelcome
