--!nonstrict
-- BRIEF: per team slot aura / trail save (design doc 4.13, u4): MarketConfig.CleanSlotItems migrates the old single
-- EquippedAura / EquippedTrail to slot 1, drops unknown / unowned ids, and keeps each id on one slot only.
local H = require(script.Parent.AcceptanceSupport)
local Shared = game:GetService("ReplicatedStorage").Shared
local Tests = {}

function Tests.slot_items()
	local r, flag = H.report("slot_items")
	local Market = require(Shared.MarketConfig)
	local owned = { azure_aura = true, rainbow_trail = true, void_trail = true }
	local function owns(_, id)
		return owned[id] == true
	end
	local old = Market.CleanSlotItems({ EquippedAura = "azure_aura", EquippedTrail = "rainbow_trail" }, owns)
	flag("slot_items_migrate_to_slot1", old[1].Aura == "azure_aura" and old[1].Trail == "rainbow_trail")
	flag("slot_items_migrate_others_empty", next(old[2]) == nil and next(old[3]) == nil and #old == Market.SLOTS)
	local new = Market.CleanSlotItems({
		EquippedAura = "azure_aura", -- ignored once SlotItems exists
		SlotItems = {
			{ Trail = "void_trail" },
			{ Aura = "galaxy_aura", Trail = "void_trail" }, -- not owned; duplicate
			{ Aura = "nope", Trail = "rainbow_trail" },
		},
	}, owns)
	flag("slot_items_old_fields_ignored", new[1].Aura == nil and new[1].Trail == "void_trail")
	flag("slot_items_unowned_dropped", new[2].Aura == nil)
	flag("slot_items_one_slot_per_id", new[2].Trail == nil)
	flag("slot_items_unknown_dropped", new[3].Aura == nil and new[3].Trail == "rainbow_trail")
	local bad = Market.CleanSlotItems({ SlotItems = "junk" }, owns)
	flag("slot_items_junk_safe", #bad == Market.SLOTS and next(bad[1]) == nil)
	flag("slot_items_nil_save_safe", #Market.CleanSlotItems(nil, owns) == Market.SLOTS)
	return r
end
return Tests
