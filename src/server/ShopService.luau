--!nonstrict
-- Robux developer-product receipts and redeem codes (docs/SHOP_PURCHASES_SPEC.md). Both grant potions only, through
-- BoostService; neither ever touches Money. The offline-reward double (docs/OFFLINE_DOUBLE_SPEC.md) doubled offline
-- Speed; there is no Speed stat since 2026-11-01 (design doc 4.13), so it never grants anything.
-- Also the paid boss spawn (docs/BOSS_EVENT_SPEC.md "Paid spawn") and gem packs (docs/SIDEKICK_SPEC.md). Contract: Server/CarTest/BossPaidTests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")

local Monetization = require(ReplicatedStorage.Shared.MonetizationConfig)
local CodeConfig = require(script.Parent.CodeConfig)
local BoostService = require(script.Parent.BoostService)
local MoneyService = require(script.Parent.MoneyService)

local ShopService = {}
ShopService.MAX_RECEIPTS = 100
ShopService.CODE_COOLDOWN = 2
ShopService.MAX_CODE_LENGTH = 32

local PAID_COOLDOWN = 0.25 -- s between presses of the paid remotes
local COMING_SOON = "Coming soon"
local RESTRICTED = "Not available on your account"

local state = {} -- [player] = { Receipts = { id, ... }, Codes = { [CODE] = true } }
local processing = {} -- [purchaseId] = true while a receipt is being granted
local lastRedeem = {}
local saveFn = nil
local playerSource, promptFn, policyFn = nil, nil, nil
local creditsInFlight = setmetatable({}, { __mode = "k" }) -- [player] = boss receipts whose save has not finished
local lastPaidPress = setmetatable({}, { __mode = "k" })

local function stateFor(player)
	local s = state[player]
	if not s then
		s = { Receipts = {}, Codes = {} }
		state[player] = s
	end
	return s
end

local function loaded(player)
	return player:GetAttribute("DataLoaded") == true and not player:GetAttribute("DataFailed")
end

local function playerData()
	return require(script.Parent.PlayerData) -- lazy: PlayerData requires this module
end

local function save(player)
	if saveFn then
		return saveFn(player)
	end
	return playerData().Save(player)
end

local function grant(player, grants, sign)
	for id, count in grants do
		BoostService.Add(player, id, sign * count)
	end
end

function ShopService.SetSave(fn)
	saveFn = fn
end

function ShopService.SetPlayers(source)
	playerSource = source
end

function ShopService.SetPrompt(fn)
	promptFn = fn
end

function ShopService.SetPolicy(fn)
	policyFn = fn
end

local function bossEvents()
	return require(script.Parent.BossEventService) -- lazy: it requires PlayerData, which requires this module
end

function ShopService.Product(productId)
	if type(productId) ~= "number" or productId <= 0 then
		return nil
	end
	for _, product in Monetization.Products do
		if product.ProductId == productId then
			return product
		end
	end
	return nil
end

function ShopService.Apply(player, data)
	data = type(data) == "table" and data or {}
	local s = stateFor(player)
	s.Receipts, s.Codes = {}, {}
	if type(data.Receipts) == "table" then
		for _, id in data.Receipts do
			if type(id) == "string" and id ~= "" then
				table.insert(s.Receipts, id)
			end
		end
		while #s.Receipts > ShopService.MAX_RECEIPTS do
			table.remove(s.Receipts, 1)
		end
	end
	if type(data.Codes) == "table" then
		for _, code in data.Codes do
			if type(code) == "string" and code ~= "" then
				s.Codes[string.upper(code)] = true
			end
		end
	end
end

function ShopService.Snapshot(player)
	local s = stateFor(player)
	local codes = {}
	for code in s.Codes do
		table.insert(codes, code)
	end
	table.sort(codes)
	return { Receipts = table.clone(s.Receipts), Codes = codes }
end

-- Applies a receipt once: the purchase id is recorded, give() grants (false = can not grant now), then both are saved.
-- A refusal or a failed save drops the id and undoes the grant, so Roblox's retry grants it exactly once later.
local function commit(player, purchaseId, give, undo)
	processing[purchaseId] = true
	local s = stateFor(player)
	table.insert(s.Receipts, purchaseId)
	local dropped = nil
	if #s.Receipts > ShopService.MAX_RECEIPTS then
		dropped = table.remove(s.Receipts, 1)
	end
	local function forget()
		processing[purchaseId] = nil
		local at = table.find(s.Receipts, purchaseId)
		if at then
			table.remove(s.Receipts, at)
		end
		if dropped then
			table.insert(s.Receipts, 1, dropped)
		end
	end
	local called, given = pcall(give)
	if not (called and given) then
		forget()
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, saved = pcall(save, player)
	if ok and saved then
		processing[purchaseId] = nil
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	forget()
	undo()
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Offline double receipt: there is no offline Speed to double since 2026-11-01 (design doc 4.13) and no offline
-- workshop credit since 2026-11-03 (4.19), so the grant always refuses (NotProcessedYet). The product is not on sale (ProductId 0).
local function processOfflineDouble(player, purchaseId)
	return commit(player, purchaseId, function()
		return false
	end, function() end)
end

-- Takes one saved credit and starts the event. A failed save of the use is not undone: the event runs, and at worst a crash before the
-- next save gives the credit back, so a paid start is never lost.
function ShopService.UseBossCredit(player)
	if not loaded(player) then
		return false, "Data not loaded"
	end
	if creditsInFlight[player] then
		return false, "Please wait" -- a credit whose save may still fail can not be spent
	end
	local credit = player:GetAttribute("BossCredit") or 0
	if credit < 1 then
		return false, "No boss credit"
	end
	if #bossEvents().AutoTeam(player) == 0 then
		return false, "Needs a Sidekick" -- locked out of the event (design doc 4.37), so the credit stays saved
	end
	local started, reason = bossEvents().Start("Paid")
	if not started then
		return false, reason
	end
	player:SetAttribute("BossCredit", credit - 1)
	pcall(save, player)
	return true
end

-- The credit is saved with its purchase id first; only then may it start an event. A busy server keeps it as "Boss ready".
local function processBoss(player, purchaseId)
	creditsInFlight[player] = (creditsInFlight[player] or 0) + 1
	local decision = commit(player, purchaseId, function()
		player:SetAttribute("BossCredit", (player:GetAttribute("BossCredit") or 0) + 1)
		return true
	end, function()
		player:SetAttribute("BossCredit", math.max(0, (player:GetAttribute("BossCredit") or 0) - 1))
	end)
	creditsInFlight[player] = creditsInFlight[player] > 1 and creditsInFlight[player] - 1 or nil
	if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
		ShopService.UseBossCredit(player)
	end
	return decision
end

-- shortcut: Gems spent during a save that then fails leave the undo clamped at 0, so the retry pays them again; upgrade with a saved debt if that window ever matters.
local function processGems(player, purchaseId, pack)
	return commit(player, purchaseId, function()
		return MoneyService.AddGems(player, pack.Gems) ~= nil
	end, function()
		player:SetAttribute("Gems", math.max(0, (player:GetAttribute("Gems") or 0) - pack.Gems))
	end)
end

function ShopService.ProcessReceipt(info)
	local giftDecision = require(script.Parent.GiftService).ProcessReceipt(info)
	if giftDecision then
		return giftDecision
	end
	local doubleId = Monetization.OfflineDouble.ProductId
	local isDouble = doubleId > 0 and info.ProductId == doubleId
	local bossId = Monetization.BossSpawn.ProductId
	local isBoss = bossId > 0 and info.ProductId == bossId
	local pack = nil
	for _, candidate in Monetization.GemPacks do
		if candidate.ProductId > 0 and candidate.ProductId == info.ProductId then
			pack = candidate
		end
	end
	local product = ShopService.Product(info.ProductId)
	local player = (playerSource or Players):GetPlayerByUserId(info.PlayerId)
	if not (isDouble or isBoss or pack or (product and product.Grants)) or not player or not loaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	-- In flight first: the id is recorded before its save finishes, and that save may still fail.
	if processing[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local s = stateFor(player)
	if table.find(s.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if isDouble then
		return processOfflineDouble(player, purchaseId)
	end
	-- A receipt is honoured whatever the policy or the Sidekicks say now: Roblox has taken the Robux.
	if isBoss then
		return processBoss(player, purchaseId)
	end
	if pack then
		return processGems(player, purchaseId, pack)
	end
	return commit(player, purchaseId, function()
		grant(player, product.Grants, 1)
		return true
	end, function()
		grant(player, product.Grants, -1)
	end)
end

-- Publishes PaidRandomRestricted. An error or an unclear answer counts as restricted: design doc section 6.
local function isRestricted(player)
	local ok, policy = pcall(function()
		if policyFn then
			return policyFn(player)
		end
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local restricted = not (ok and type(policy) == "table" and policy.ArePaidRandomItemsRestricted == false)
	player:SetAttribute("PaidRandomRestricted", restricted)
	return restricted
end

local function prompt(player, productId)
	if promptFn then
		promptFn(player, productId)
	else
		MarketplaceService:PromptProductPurchase(player, productId)
	end
	return true
end

function ShopService.PromptBoss(player)
	if not loaded(player) then
		return false, "Data not loaded"
	end
	if isRestricted(player) then
		return false, RESTRICTED
	end
	local productId = Monetization.BossSpawn.ProductId
	if productId <= 0 then
		return false, COMING_SOON
	end
	local boss = bossEvents()
	if boss.State().Phase ~= "Idle" then
		return false, "An event is active"
	end
	if #boss.AutoTeam(player) == 0 then
		return false, "Needs a Sidekick"
	end
	return prompt(player, productId)
end

function ShopService.PromptGems(player, packId)
	if not loaded(player) then
		return false, "Data not loaded"
	end
	if isRestricted(player) then
		return false, RESTRICTED
	end
	for _, pack in Monetization.GemPacks do
		if pack.Id == packId then
			if pack.ProductId <= 0 then
				return false, COMING_SOON
			end
			return prompt(player, pack.ProductId)
		end
	end
	return false, "Unknown pack"
end

function ShopService.Redeem(player, text)
	if type(text) ~= "string" then
		return false, "Invalid code"
	end
	local code = string.upper((string.gsub(text, "^%s*(.-)%s*$", "%1")))
	if code == "" or #code > ShopService.MAX_CODE_LENGTH then
		return false, "Invalid code"
	end
	if not loaded(player) then
		return false, "Data not loaded"
	end
	local at = os.clock()
	if lastRedeem[player] and at - lastRedeem[player] < ShopService.CODE_COOLDOWN then
		return false, "Please wait"
	end
	lastRedeem[player] = at
	local entry = CodeConfig.Codes[code]
	if not entry then
		return false, "Invalid code"
	end
	local s = stateFor(player)
	if s.Codes[code] then
		return false, "Already redeemed"
	end
	grant(player, entry.Grants, 1)
	s.Codes[code] = true
	return true, "Code redeemed!"
end

function ShopService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local redeem = remotes:FindFirstChild("RedeemCode") or Instance.new("RemoteFunction")
	redeem.Name = "RedeemCode"
	redeem.Parent = remotes
	redeem.OnServerInvoke = ShopService.Redeem
	for name, fn in
		{
			BossBuy = ShopService.PromptBoss,
			GemPackBuy = ShopService.PromptGems,
			BossUseCredit = ShopService.UseBossCredit,
		}
	do
		local remote = remotes:FindFirstChild(name) or Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = remotes
		remote.OnServerInvoke = function(player, ...)
			local at = os.clock()
			if lastPaidPress[player] and at - lastPaidPress[player] < PAID_COOLDOWN then
				return false, "Please wait"
			end
			lastPaidPress[player] = at
			return fn(player, ...)
		end
	end
	-- shortcut: a policy call failing at join reads as restricted until the player rejoins; the client asks no further. Upgrade with a retry if live logs show failures.
	Players.PlayerAdded:Connect(isRestricted)
	for _, player in Players:GetPlayers() do
		task.spawn(isRestricted, player)
	end
	MarketplaceService.ProcessReceipt = ShopService.ProcessReceipt
	require(script.Parent.GiftService).Start(remotes)
	Players.PlayerRemoving:Connect(function(player)
		lastRedeem[player] = nil
		-- shortcut: the leave save reads this state, so drop it later instead of racing PlayerData's handler.
		task.delay(60, function()
			if not player.Parent then
				state[player] = nil
			end
		end)
	end)
end

return ShopService
