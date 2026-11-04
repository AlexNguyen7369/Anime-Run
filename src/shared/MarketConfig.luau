--!strict
-- Money purchases described by the design document's "What Money buys" section.
local MarketConfig = {}
local BoostConfig = require(script.Parent.BoostConfig)
local PayoutCurve = require(script.Parent.PayoutCurve)

MarketConfig.Items = {
	Aura = {
		{
			Id = "azure_aura",
			Name = "Azure Aura",
			Price = PayoutCurve.Cost(2500, 1),
			SpeedMulti = 1.2,
			Color = Color3.fromRGB(80, 190, 255),
			Accent = Color3.fromRGB(180, 245, 255),
			Description = "A cool, charged glow that lifts your cruise speed.",
		},
		{
			Id = "ember_aura",
			Name = "Ember Aura",
			Price = PayoutCurve.Cost(2500, 2),
			SpeedMulti = 2,
			Color = Color3.fromRGB(255, 92, 38),
			Accent = Color3.fromRGB(255, 220, 75),
			Description = "A hot orbit of sparks for high-energy racers.",
		},
		{
			Id = "galaxy_aura",
			Name = "Galaxy Aura",
			Price = PayoutCurve.Cost(2500, 3),
			SpeedMulti = 3,
			Color = Color3.fromRGB(137, 80, 255),
			Accent = Color3.fromRGB(255, 91, 220),
			Description = "A swirling cosmic field with a rare speed boost.",
		},
	},
	Trail = {
		{
			Id = "rainbow_trail",
			Name = "Rainbow Trail",
			Price = PayoutCurve.Cost(500, 1),
			SpeedMulti = 1.5,
			Color = Color3.fromRGB(255, 120, 235),
			Accent = Color3.fromRGB(90, 220, 255),
			Description = "A shifting rainbow ribbon behind your ride.",
		},
		{
			Id = "solar_trail",
			Name = "Solar Trail",
			Price = PayoutCurve.Cost(500, 2),
			SpeedMulti = 2,
			Color = Color3.fromRGB(255, 188, 48),
			Accent = Color3.fromRGB(255, 245, 145),
			Description = "A bright comet tail made of golden plasma.",
		},
		{
			Id = "void_trail",
			Name = "Void Trail",
			Price = PayoutCurve.Cost(500, 3),
			SpeedMulti = 3,
			Color = Color3.fromRGB(104, 52, 220),
			Accent = Color3.fromRGB(34, 230, 210),
			Description = "A dark neon wake that flickers at the edges.",
		},
		{
			Id = "frost_trail",
			Name = "Frost Trail",
			Price = PayoutCurve.Cost(500, 4),
			SpeedMulti = 4,
			Color = Color3.fromRGB(80, 190, 255),
			Accent = Color3.fromRGB(180, 245, 255),
			Description = "An icy band that sheds frost shards.",
		},
		{
			Id = "prism_trail",
			Name = "Prism Trail",
			Price = PayoutCurve.Cost(500, 5),
			SpeedMulti = 5,
			Color = Color3.fromRGB(186, 140, 255),
			Accent = Color3.fromRGB(255, 255, 255),
			Description = "A wide plasma band split into every colour.",
		},
	},
	Potion = {},
}

for _, category in BoostConfig.Order do
	for _, boost in BoostConfig.ItemsFor(category) do
		table.insert(MarketConfig.Items.Potion, {
			Id = boost.Id,
			Name = boost.Name,
			Price = boost.Price,
			Color = category == "Luck" and Color3.fromRGB(190, 105, 255)
				or category == "Money" and Color3.fromRGB(255, 205, 65)
				or Color3.fromRGB(70, 190, 255),
			Accent = Color3.fromRGB(255, 255, 255),
			Description = string.format("%s multiplier for %d seconds. Added to your Bag.", category, boost.Duration),
			Category = category,
			Tier = boost.Tier,
		})
	end
end

local byId = {}
for kind, items in MarketConfig.Items do
	for _, item in items do
		item.Kind = kind
		if kind == "Aura" or kind == "Trail" then
			item.Icon = "vector:" .. item.Id
		end
		byId[item.Id] = item
	end
end

function MarketConfig.Get(kind, id)
	local item = byId[id]
	return item and item.Kind == kind and item or nil
end

-- Per team slot aura and trail (design doc 4.13): one of each per slot, server attributes Slot<n>Aura / Slot<n>Trail.
MarketConfig.SLOTS = 3
MarketConfig.SLOT_KINDS = { "Aura", "Trail" }
MarketConfig.MAX_COPIES = 3 -- copies of one aura / trail a player can own (design doc 4.13, owner 2026-11-04)

function MarketConfig.SlotAttribute(slot: number, kind: string): string
	return "Slot" .. slot .. kind
end

-- Copies of aura / trail `id` the player owns (server attribute Own<Kind>_<id>, nil at 0).
function MarketConfig.Copies(player: any, kind: string, id: string): number
	return player:GetAttribute("Own" .. kind .. "_" .. id) or 0
end

-- Validated per-slot items from a save: { [1] = { Aura = id?, Trail = id? }, [2] = ..., [3] = ... }. A save with no
-- SlotItems migrates its old single EquippedAura / EquippedTrail to slot 1. An item is kept only if it exists and
-- the player has a copy free: an id sits on at most `copies(kind, id)` slots, the lowest slots win.
function MarketConfig.CleanSlotItems(saved: any, copies: (string, string) -> number): { [number]: { [string]: string } }
	local source = type(saved) == "table" and saved or {}
	local slots = source.SlotItems
	if type(slots) ~= "table" then
		slots = { { Aura = source.EquippedAura, Trail = source.EquippedTrail } }
	end
	local clean, used = {}, {}
	for slot = 1, MarketConfig.SLOTS do
		local entry = type(slots[slot]) == "table" and slots[slot] or {}
		clean[slot] = {}
		for _, kind in MarketConfig.SLOT_KINDS do
			local id = entry[kind]
			if type(id) == "string" and MarketConfig.Get(kind, id) and (used[id] or 0) < copies(kind, id) then
				used[id] = (used[id] or 0) + 1
				clean[slot][kind] = id
			end
		end
	end
	return clean
end

local function slotMulti(player: any, slot: number?, kind: string): number
	local id = typeof(player) == "Instance" and player:GetAttribute(MarketConfig.SlotAttribute(slot or 1, kind)) or nil
	local item = MarketConfig.Get(kind, id)
	return item and item.SpeedMulti or 1
end

-- Slot `slot`'s (default 1) aura raw multi (damped into cruise by RaceConfig.ItemCruiseMulti).
function MarketConfig.SpeedMulti(player, slot)
	return slotMulti(player, slot, "Aura")
end

-- Slot `slot`'s (default 1) trail raw multi (damped into cruise by RaceConfig.ItemCruiseMulti; owner 2026-10-28).
function MarketConfig.TrailMulti(player, slot)
	return slotMulti(player, slot, "Trail")
end

return MarketConfig
