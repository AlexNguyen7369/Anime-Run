--!nonstrict
-- BRIEF: design doc 4.36 "A tutorial then gives one free summon", 4.21, docs/SIDEKICK_SPEC.md "Saves already past rebirth 2 get it too".
-- Owner ruling, relayed 2026-11-05: auto-sell is off until a player turns it on. A free summon's result is never auto-sold, because
-- the free Sidekick is what unlocks events. SidekickTests holds the other free summon rules.
-- Contract these tests assume beyond the brief (implementer: report a change, do not loosen):
--   Remotes.SidekickFreeSummon is a RemoteFunction that calls GrantFreeSummon.
--   A free summon on a full bag is refused and stays unused, even with its rarity on auto-sell: it can only be kept.
--   The free summon's result has Sold falsy and an Entry. It leaves the player's auto-sell choices as they were.
-- On demand: ReplicatedStorage attributes CarTestOnly = "sidekick_tutorial", then CarTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990139000
local UNLOCK = 2 -- design doc 4.36

function Tests.sidekick_tutorial()
	local r, flag = H.report("sidekick_tutorial")
	local Cfg = require(Shared.SidekickConfig)
	local S = require(Server.SidekickService)
	local oldRoll = Cfg.Roll
	local cleanup = {}
	local ok, err = xpcall(function()
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestSidekickTutorialData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local store = H.store()
		data.SetStore(store)
		local nextId = UID
		local function loaded(saved, rebirth)
			nextId += 1
			store.data[data.KeyFor(nextId)] = saved
			local p = H.player(cleanup, nextId)
			data.Load(p, nextId)
			if rebirth then
				p:SetAttribute("RebirthLevel", rebirth)
			end
			return p
		end
		local function used(p)
			return S.Snapshot(p).SidekickFreeUsed == true
		end
		local function bagCount(p)
			return #(S.Snapshot(p).Sidekicks or {})
		end
		local rarities = {}
		for _, row in Cfg.List do
			rarities[row.Rarity] = true
		end

		flag("config_unlock_rebirth_2", Cfg.UnlockRebirth == UNLOCK, Cfg.UnlockRebirth, UNLOCK)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local remote = remotes and remotes:FindFirstChild("SidekickFreeSummon")
		flag("remote_exists", remote ~= nil and remote:IsA("RemoteFunction"))

		-- Works once at rebirth 2 or later; refused below, and a refusal leaves it unused.
		for _, rebirth in { 0, UNLOCK - 1 } do
			local low = loaded(nil, rebirth)
			flag("refused_below_" .. rebirth, (S.GrantFreeSummon(low)) == false)
			flag("below_nothing_added_" .. rebirth, bagCount(low) == 0 and not used(low))
			low:SetAttribute("RebirthLevel", UNLOCK)
			flag("works_after_reaching_unlock_" .. rebirth, (S.GrantFreeSummon(low)) == true)
		end
		for _, rebirth in { UNLOCK, UNLOCK + 3 } do
			local fine = loaded(nil, rebirth)
			local good, results = S.GrantFreeSummon(fine)
			flag("works_at_" .. rebirth, good == true and type(results) == "table" and #results == 1)
			flag("adds_one_at_" .. rebirth, bagCount(fine) == 1 and used(fine))
			flag("second_refused_at_" .. rebirth, (S.GrantFreeSummon(fine)) == false and bagCount(fine) == 1)
		end

		-- A save from before Sidekicks, already past rebirth 2, still has it.
		local veteran = loaded({ Version = 14, RebirthLevel = UNLOCK + 3 })
		flag("old_save_past_unlock_unused", not used(veteran))
		flag("old_save_past_unlock_works", (S.GrantFreeSummon(veteran)) == true)

		-- Used stays used over a rejoin.
		local rejoin = loaded(nil, UNLOCK)
		S.GrantFreeSummon(rejoin)
		local rejoinId = nextId
		flag("rejoin_save_ok", data.Save(rejoin, rejoinId, true) == true)
		local back = H.player(cleanup, rejoinId + 500)
		S.Apply(back, store.data[data.KeyFor(rejoinId)])
		back:SetAttribute("RebirthLevel", UNLOCK)
		flag("rejoin_second_refused", used(back) and (S.GrantFreeSummon(back)) == false)

		-- Kept despite auto-sell: every rarity on auto-sell, each rarity rolled in turn.
		for rarity in rarities do
			Cfg.Roll = function(rng, rows)
				for _, row in rows do
					if row.Rarity == rarity then
						return row
					end
				end
				return oldRoll(rng, rows)
			end
			local keeper = loaded(nil, UNLOCK)
			for each in rarities do
				S.SetAutoSell(keeper, each, true)
			end
			keeper:SetAttribute("Gems", 0)
			local good, results = S.GrantFreeSummon(keeper)
			local result = type(results) == "table" and results[1] or {}
			flag("auto_sell_works_" .. rarity, good == true)
			flag(
				"auto_sell_result_not_sold_" .. rarity,
				result.Sold ~= true and result.Entry ~= nil,
				tostring(result.Sold)
			)
			flag("auto_sell_kept_in_bag_" .. rarity, bagCount(keeper) == 1)
			flag(
				"auto_sell_no_gems_" .. rarity,
				(keeper:GetAttribute("Gems") or 0) == 0,
				keeper:GetAttribute("Gems"),
				0
			)
			flag("auto_sell_choice_stays_" .. rarity, S.Snapshot(keeper).SidekickAutoSell[rarity] == true)
			Cfg.Roll = oldRoll
			-- A paid summon still sells: the exception is the free one only.
			keeper:SetAttribute("Gems", Cfg.SummonCost)
			local paid, paidResults = S.Summon(keeper, 1)
			flag("paid_still_auto_sold_" .. rarity, paid == true and paidResults[1].Sold == true)
		end

		-- Full bag, auto-sell on: refused and unused, never sold.
		local full = loaded(nil, UNLOCK)
		for i = 1, Cfg.BagSize do
			S.Grant(full, Cfg.List[(i - 1) % #Cfg.List + 1].Id)
		end
		for each in rarities do
			S.SetAutoSell(full, each, true)
		end
		full:SetAttribute("Gems", 0)
		flag("full_bag_refused", (S.GrantFreeSummon(full)) == false and not used(full))
		flag("full_bag_no_gems", (full:GetAttribute("Gems") or 0) == 0)

		-- Pity counts it, and the guarantee pays through it.
		Cfg.Roll = function(rng, rows)
			for _, row in rows do
				if row.Rarity == "Common" then
					return row
				end
			end
			return oldRoll(rng, rows)
		end
		local counted = loaded(nil, UNLOCK)
		local before = S.Snapshot(counted)
		S.GrantFreeSummon(counted)
		local after = S.Snapshot(counted)
		flag("pity_mythic_counts", after.SidekickPity == (before.SidekickPity or 0) + 1, after.SidekickPity)
		flag(
			"pity_legendary_counts",
			after.SidekickLegendaryPity == (before.SidekickLegendaryPity or 0) + 1,
			after.SidekickLegendaryPity
		)
		local guaranteed = loaded({ Version = 17, SidekickPity = Cfg.PityCount - 1 }, UNLOCK)
		for each in rarities do
			S.SetAutoSell(guaranteed, each, true)
		end
		local good, results = S.GrantFreeSummon(guaranteed)
		local result = type(results) == "table" and results[1] or {}
		flag("pity_pays_on_free", good == true and result.Pity == true and result.Sold ~= true and result.Entry ~= nil)
	end, debug.traceback)
	flag("completed", ok, ok and 1 or tostring(err))
	Cfg.Roll = oldRoll
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
