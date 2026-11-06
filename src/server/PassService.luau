--!nonstrict
-- Gamepass ownership and the paid random items policy (docs/MONETIZATION_SPEC.md). Attributes, read by every service
-- and the client: Pass_<id> = true while owned; PaidRandomRestricted = true unless Roblox's policy says otherwise.
-- Ownership is never saved: Roblox owns it.
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.Shared.MonetizationConfig)

local PassService = {}
PassService.RETRY_SECONDS = 30

local function realOwnerCheck(player, gamepassId)
	return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
end

local function realPolicy(player)
	return PolicyService:GetPolicyInfoForPlayerAsync(player)
end

local ownerCheck = realOwnerCheck
local policyRead = realPolicy

-- Test hooks, like ShopService.SetSave. nil puts the real one back.
function PassService.SetOwnerCheck(fn)
	ownerCheck = fn or realOwnerCheck
end

function PassService.SetPolicyRead(fn)
	policyRead = fn or realPolicy
end

function PassService.Owns(player, id)
	return player:GetAttribute("Pass_" .. id) == true
end

-- Paid luck is off until the policy says it is allowed: a failed read counts as restricted.
function PassService.PaidLuckAllowed(player)
	return player:GetAttribute("PaidRandomRestricted") == false
end

function PassService.ById(gamepassId)
	if type(gamepassId) ~= "number" or gamepassId <= 0 then
		return nil
	end
	for _, pass in Monetization.Gamepasses do
		if pass.GamepassId == gamepassId then
			return pass
		end
	end
	return nil
end

-- One lookup pass over the catalogue. A failed lookup changes nothing. Returns true when every lookup answered.
function PassService.Refresh(player)
	local answered = true
	for _, pass in Monetization.Gamepasses do
		if pass.GamepassId > 0 and not PassService.Owns(player, pass.Id) then
			local ok, owned = pcall(ownerCheck, player, pass.GamepassId)
			if not ok then
				answered = false
			elseif owned == true then
				player:SetAttribute("Pass_" .. pass.Id, true)
			end
		end
	end
	return answered
end

function PassService.RefreshPolicy(player)
	local ok, info = pcall(policyRead, player)
	if ok and type(info) == "table" and type(info.ArePaidRandomItemsRestricted) == "boolean" then
		player:SetAttribute("PaidRandomRestricted", info.ArePaidRandomItemsRestricted)
		return true
	end
	return false
end

function PassService.Setup(player)
	if player:GetAttribute("PaidRandomRestricted") == nil then
		player:SetAttribute("PaidRandomRestricted", true)
	end
end

local function onPlayer(player)
	PassService.Setup(player)
	task.spawn(function()
		-- Wait for the save: the exclusive runner's grant must land after GachaService.Apply clears GachaData.
		while player.Parent and not player:GetAttribute("DataLoaded") and not player:GetAttribute("DataFailed") do
			task.wait(0.2)
		end
		local passes, policy = false, false
		while player.Parent and not (passes and policy) do
			passes = passes or PassService.Refresh(player)
			policy = policy or PassService.RefreshPolicy(player)
			if not (passes and policy) then
				task.wait(PassService.RETRY_SECONDS)
			end
		end
	end)
end

function PassService.Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, purchased)
		local pass = purchased and PassService.ById(gamepassId)
		if pass then
			player:SetAttribute("Pass_" .. pass.Id, true)
		end
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return PassService
