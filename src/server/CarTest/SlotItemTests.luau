--!nonstrict
-- BRIEF: per team slot aura / trail save (design doc 4.13, u4): MarketConfig.CleanSlotItems migrates the old single
-- EquippedAura / EquippedTrail to slot 1, drops unknown / unowned ids, and keeps each id on as many slots as it has
-- copies. MarketService: buying up to MAX_COPIES, equipping across slots, the saved form of copies (owner 2026-11-04).
local H = require(script.Parent.AcceptanceSupport)
local Shared = game:GetService("ReplicatedStorage").Shared
local Server = script.Parent.Parent
local Tests = {}

function Tests.slot_items()
	local r, flag = H.report("slot_items")
	local Market = require(Shared.MarketConfig)
	local owned = { azure_aura = 1, rainbow_trail = 1, void_trail = 1, solar_trail = 2 }
	local function copies(_, id)
		return owned[id] or 0
	end
	local old = Market.CleanSlotItems({ EquippedAura = "azure_aura", EquippedTrail = "rainbow_trail" }, copies)
	flag("slot_items_migrate_to_slot1", old[1].Aura == "azure_aura" and old[1].Trail == "rainbow_trail")
	flag("slot_items_migrate_others_empty", next(old[2]) == nil and next(old[3]) == nil and #old == Market.SLOTS)
	local new = Market.CleanSlotItems({
		EquippedAura = "azure_aura", -- ignored once SlotItems exists
		SlotItems = {
			{ Trail = "void_trail" },
			{ Aura = "galaxy_aura", Trail = "void_trail" }, -- not owned; no copy left
			{ Aura = "nope", Trail = "rainbow_trail" },
		},
	}, copies)
	flag("slot_items_old_fields_ignored", new[1].Aura == nil and new[1].Trail == "void_trail")
	flag("slot_items_unowned_dropped", new[2].Aura == nil)
	flag("slot_items_one_slot_per_copy", new[2].Trail == nil)
	flag("slot_items_unknown_dropped", new[3].Aura == nil and new[3].Trail == "rainbow_trail")
	local two = Market.CleanSlotItems({
		SlotItems = { { Trail = "solar_trail" }, { Trail = "solar_trail" }, { Trail = "solar_trail" } },
	}, copies)
	flag("slot_items_two_copies_two_slots", two[1].Trail == "solar_trail" and two[2].Trail == "solar_trail")
	flag("slot_items_third_slot_no_copy", two[3].Trail == nil)
	local bad = Market.CleanSlotItems({ SlotItems = "junk" }, copies)
	flag("slot_items_junk_safe", #bad == Market.SLOTS and next(bad[1]) == nil)
	flag("slot_items_nil_save_safe", #Market.CleanSlotItems(nil, copies) == Market.SLOTS)

	-- A Folder stands in for the player: the service only uses attributes and leaderstats.
	local MarketService = require(Server.MarketService)
	local MoneyService = require(Server.MoneyService)
	local id = "azure_aura"
	local price = Market.Get("Aura", id).Price
	local p = Instance.new("Folder")
	local money = MoneyService.Setup(p)
	money.Value = price * (Market.MAX_COPIES + 1)
	for _ = 1, Market.MAX_COPIES do
		MarketService.Purchase(p, "Aura", id)
	end
	flag("copies_buy_to_cap", Market.Copies(p, "Aura", id) == Market.MAX_COPIES and money.Value == price)
	flag("copies_refused_at_cap", MarketService.Purchase(p, "Aura", id) == false)
	flag("copies_refused_no_charge", money.Value == price and Market.Copies(p, "Aura", id) == Market.MAX_COPIES)

	local function worn(slot)
		return p:GetAttribute(Market.SlotAttribute(slot, "Aura"))
	end
	MarketService.Apply(p, { OwnedAuras = { id, id } })
	flag("copies_load_count", Market.Copies(p, "Aura", id) == 2)
	MarketService.Equip(p, "Aura", id, 1)
	MarketService.Equip(p, "Aura", id, 2)
	flag("copies_wear_two_slots", worn(1) == id and worn(2) == id)
	MarketService.Equip(p, "Aura", id, 2)
	flag("copies_same_slot_no_change", worn(1) == id and worn(2) == id)
	MarketService.Equip(p, "Aura", id, 3)
	flag("copies_full_wear_moves_lowest", worn(1) == nil and worn(2) == id and worn(3) == id)
	local snap = MarketService.Snapshot(p)
	flag("copies_snapshot_repeats", #snap.OwnedAuras == 2)
	MarketService.Apply(p, snap)
	flag("copies_round_trip", Market.Copies(p, "Aura", id) == 2 and worn(2) == id and worn(3) == id)
	MarketService.Apply(p, { OwnedAuras = { id }, SlotItems = { { Aura = id }, { Aura = id } } })
	flag("copies_old_save_one", Market.Copies(p, "Aura", id) == 1 and worn(1) == id and worn(2) == nil)
	MarketService.Apply(p, { OwnedAuras = { id, id, id, id, id } })
	flag("copies_load_clamped", Market.Copies(p, "Aura", id) == Market.MAX_COPIES)
	p:Destroy()
	return r
end
return Tests
