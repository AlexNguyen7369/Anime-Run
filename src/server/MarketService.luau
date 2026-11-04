--!nonstrict
-- Server-owned Market purchases and equipment. The client never supplies a price or effect.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MarketConfig = require(Shared.MarketConfig)
local MoneyService = require(script.Parent.MoneyService)
local BoostService = require(script.Parent.BoostService)

local MarketService = {}
MarketService.REMOTE_COOLDOWN = 0.25
local lastRequest = setmetatable({}, { __mode = "k" })

local function setCopies(player, kind, id, count)
	player:SetAttribute("Own" .. kind .. "_" .. id, count > 0 and count or nil)
end

-- The saved form of a kind's copies: each id once per copy.
local function ownedList(player, kind)
	local list = {}
	for _, item in MarketConfig.Items[kind] do
		for _ = 1, MarketConfig.Copies(player, kind, item.Id) do
			table.insert(list, item.Id)
		end
	end
	return list
end

function MarketService.Snapshot(player)
	local slotItems = {}
	for slot = 1, MarketConfig.SLOTS do
		slotItems[slot] = {
			Aura = player:GetAttribute(MarketConfig.SlotAttribute(slot, "Aura")),
			Trail = player:GetAttribute(MarketConfig.SlotAttribute(slot, "Trail")),
		}
	end
	return {
		OwnedAuras = ownedList(player, "Aura"),
		OwnedTrails = ownedList(player, "Trail"),
		SlotItems = slotItems,
	}
end

function MarketService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	for _, kind in MarketConfig.SLOT_KINDS do
		for _, item in MarketConfig.Items[kind] do
			setCopies(player, kind, item.Id, 0)
		end
		local list = saved["Owned" .. kind .. "s"]
		for _, id in type(list) == "table" and list or {} do
			if MarketConfig.Get(kind, id) then
				local count = math.min(MarketConfig.Copies(player, kind, id) + 1, MarketConfig.MAX_COPIES)
				setCopies(player, kind, id, count)
			end
		end
	end
	local slotItems = MarketConfig.CleanSlotItems(saved, function(kind, id)
		return MarketConfig.Copies(player, kind, id)
	end)
	for slot, entry in slotItems do
		for _, kind in MarketConfig.SLOT_KINDS do
			player:SetAttribute(MarketConfig.SlotAttribute(slot, kind), entry[kind])
		end
	end
end

function MarketService.Purchase(player, kind, id)
	local item = MarketConfig.Get(kind, id)
	if not item then
		return false, "Already owned or unavailable"
	end
	if kind == "Potion" then
		local ok, result = BoostService.Purchase(player, id)
		return ok, ok and ("Purchased " .. item.Name .. " • Bag x" .. tostring(result)) or result
	end
	local copies = MarketConfig.Copies(player, kind, id)
	if copies >= MarketConfig.MAX_COPIES then
		return false, "Max copies owned"
	end
	local money = MoneyService.Setup(player)
	if money.Value < item.Price then
		return false, "Not enough money"
	end
	money.Value -= item.Price
	setCopies(player, kind, id, copies + 1)
	return true, string.format("Purchased %s • Owned x%d", item.Name, copies + 1)
end

-- Puts aura / trail `id` on team slot `slot` (1..SLOTS, default 1); `id` nil takes that slot's one off. One copy wears
-- on one slot: with every copy already worn elsewhere, the lowest other slot wearing it gives up its copy.
function MarketService.Equip(player, kind, id, slot)
	slot = slot or 1
	if
		(kind ~= "Aura" and kind ~= "Trail")
		or type(slot) ~= "number"
		or slot % 1 ~= 0
		or slot < 1
		or slot > MarketConfig.SLOTS
	then
		return false, "Pick a slot"
	end
	local attribute = MarketConfig.SlotAttribute(slot, kind)
	if id == nil then
		player:SetAttribute(attribute, nil)
		return true, string.format("Slot %d %s removed", slot, string.lower(kind))
	end
	local item = MarketConfig.Get(kind, id)
	local copies = item and MarketConfig.Copies(player, kind, id) or 0
	if copies < 1 then
		return false, "Buy it first"
	end
	if player:GetAttribute(attribute) ~= id then
		local wearing = {}
		for other = 1, MarketConfig.SLOTS do
			if player:GetAttribute(MarketConfig.SlotAttribute(other, kind)) == id then
				table.insert(wearing, other)
			end
		end
		if #wearing >= copies then
			player:SetAttribute(MarketConfig.SlotAttribute(wearing[1], kind), nil)
		end
		player:SetAttribute(attribute, id)
	end
	return true, string.format("Equipped %s on slot %d", item.Name, slot)
end

local function allowed(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < MarketService.REMOTE_COOLDOWN then
		return false
	end
	lastRequest[player] = now
	return true
end

function MarketService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local open = remotes:FindFirstChild("MarketOpen") or Instance.new("RemoteEvent")
	open.Name = "MarketOpen"
	open.Parent = remotes
	local purchase = remotes:FindFirstChild("MarketPurchase") or Instance.new("RemoteFunction")
	purchase.Name = "MarketPurchase"
	purchase.Parent = remotes
	purchase.OnServerInvoke = function(player, kind, id)
		if not allowed(player) then
			return false, "Please wait"
		end
		return MarketService.Purchase(player, kind, id)
	end
	local equip = remotes:FindFirstChild("MarketEquip") or Instance.new("RemoteFunction")
	equip.Name = "MarketEquip"
	equip.Parent = remotes
	equip.OnServerInvoke = function(player, kind, id, slot)
		if not allowed(player) then
			return false, "Please wait"
		end
		if slot == nil then
			return false, "Pick a slot" -- clients always name the slot
		end
		return MarketService.Equip(player, kind, id, slot)
	end
	local function watch(part)
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				open:FireClient(player)
			end)
		end
	end
	CollectionService:GetInstanceAddedSignal("MarketPad"):Connect(watch)
	for _, part in CollectionService:GetTagged("MarketPad") do
		watch(part)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return MarketService
