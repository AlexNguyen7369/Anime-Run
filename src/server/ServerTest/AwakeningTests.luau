--!nonstrict
-- BRIEF: design doc 4.47 "Awakening" (World 2 only: duplicate Copies buy up to 5 stars per character; +3% cruise and
-- +3% stamina per star; costs 1, 2, 4, 8, 16 placeholders) and docs/WORLD2_SPEC.md "Awakening" (proposed details).
-- Runs in either place and checks that place's rule. Offline: lune run tools/lune/server_scenarios <1|2> AwakeningTests.awakening
-- On demand in Studio: ReplicatedStorage attributes ServerTestOnly = "awakening", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990249000

function Tests.awakening()
	local r, flag = H.report("awakening")
	local W2 = require(Shared.WorldConfig).Id == 2
	local catalog = require(Shared.CharacterCatalog)
	local WorldSave = require(Shared.WorldSave)
	local GachaService = require(Server.GachaService)
	local okConfig, A = pcall(require, Shared:FindFirstChild("AwakeningConfig"))
	local cleanup = {}
	local function section(name, fn)
		local ok, err = xpcall(fn, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end
	local function close(a, b)
		return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b))
	end
	-- a loaded player owning a slow rollable character (cruise far under the cap) with `copies` duplicates
	local slow
	for _, spec in catalog.Rollable() do
		if spec.Rarity == "Rare" and not slow then
			slow = spec.Id
		end
	end
	local n = 0
	local function newPlayer(copies)
		n += 1
		local p = H.player(cleanup, UID + n)
		GachaService.Setup(p)
		GachaService.Grant(p, slow)
		for _ = 1, copies or 0 do
			GachaService.Grant(p, slow)
		end
		GachaService.SetTeam(p, { slow })
		p:SetAttribute("DataLoaded", true)
		return p
	end

	section("config", function()
		flag("config_module", okConfig and type(A) == "table")
		flag("max_stars_5", A.MAX_STARS == 5)
		flag("costs", H.same(A.COSTS, { 1, 2, 4, 8, 16 }))
		flag("next_cost_0", A.NextCost(0) == 1 and A.NextCost(4) == 16 and A.NextCost(5) == nil)
		flag("multi_0_exact", A.CruiseMulti(0) == 1 and A.StaminaMulti(0) == 1)
		flag("multi_5", close(A.CruiseMulti(5), 1.15) and close(A.StaminaMulti(5), 1.15))
		flag("multi_capped", A.CruiseMulti(9) == A.CruiseMulti(5) and A.CruiseMulti(-1) == 1)
	end)

	section("awaken", function()
		local p = newPlayer(31) -- 1 + 2 + 4 + 8 + 16 = 31: exactly five stars
		local cruise0, stamina0 = GachaService.CruiseFor(p, slow), GachaService.AwakenStamina(p, slow)
		local ok = GachaService.Awaken(p, slow)
		if not W2 then
			flag("w1_refused", ok == false and GachaService.Copies(p, slow) == 31 and GachaService.Stars(p, slow) == 0)
			flag("w1_cruise_same", GachaService.CruiseFor(p, slow) == cruise0 and stamina0 == 1)
			return
		end
		flag("w2_first_star", ok == true and GachaService.Stars(p, slow) == 1 and GachaService.Copies(p, slow) == 30)
		for _ = 2, 5 do
			GachaService.Awaken(p, slow)
		end
		flag("w2_five_stars_spend_31", GachaService.Stars(p, slow) == 5 and GachaService.Copies(p, slow) == 0)
		flag("w2_capped_at_5", GachaService.Awaken(p, slow) == false and GachaService.Stars(p, slow) == 5)
		flag(
			"w2_cruise_scaled",
			close(GachaService.CruiseFor(p, slow), cruise0 * 1.15),
			GachaService.CruiseFor(p, slow),
			cruise0 * 1.15
		)
		flag("w2_stamina_scaled", close(GachaService.AwakenStamina(p, slow), 1.15))
		GachaService.RefreshTeam(p)
		local spec = catalog.Get(slow)
		local seconds = require(Shared.StaminaConfig).Seconds(spec, GachaService.StaminaMulti(p) * 1.15)
		flag(
			"w2_team_row_stamina",
			close(p:GetAttribute("TeamStamina1"), math.round(seconds * 10) / 10),
			p:GetAttribute("TeamStamina1")
		)
	end)

	section("refusals", function()
		if not W2 then
			return
		end
		local p = newPlayer(2) -- star 1 costs 1, star 2 costs 2: one Copy short
		GachaService.Awaken(p, slow)
		flag("w2_no_copies_refused", GachaService.Awaken(p, slow) == false and GachaService.Copies(p, slow) == 1)
		flag("w2_no_copies_star_kept", GachaService.Stars(p, slow) == 1)
		local q = newPlayer(5)
		q:SetAttribute("Travelling", true)
		flag("w2_travelling_refused", GachaService.Awaken(q, slow) == false and GachaService.Copies(q, slow) == 5)
		q:SetAttribute("Travelling", nil)
		q:SetAttribute("DataLoaded", nil)
		flag("w2_not_loaded_refused", GachaService.Awaken(q, slow) == false and GachaService.Stars(q, slow) == 0)
		q:SetAttribute("DataLoaded", true)
		flag("w2_unowned_refused", GachaService.Awaken(q, "no_such_id") == false)
		flag("w2_bad_arg_refused", GachaService.Awaken(q, { slow }) == false)
	end)

	section("save", function()
		local old = { Cars = { slow }, Copies = { [slow] = 9 }, Team = { slow } } -- an old save: no Awakening
		local p = newPlayer(0)
		GachaService.Apply(p, WorldSave.View(old, W2 and 2 or 1))
		flag("old_save_0_stars", GachaService.Stars(p, slow) == 0 and GachaService.Snapshot(p).Awakening == nil)
		if not W2 then
			-- a save holding World 2 stars: World 1 neither applies nor drops them
			local stored = table.clone(old)
			stored.Worlds = { W2 = { Awakening = { [slow] = 3 } } }
			local before = GachaService.CruiseFor(p, slow)
			GachaService.Apply(p, WorldSave.View(stored, 1))
			flag("w1_stars_not_applied", GachaService.Stars(p, slow) == 0 and GachaService.CruiseFor(p, slow) == before)
			flag("w1_stamina_unchanged", GachaService.AwakenStamina(p, slow) == 1)
			local folded = WorldSave.Fold(GachaService.Snapshot(p), stored, 1)
			local merged = table.clone(stored)
			for key, value in folded do
				merged[key] = value
			end
			flag("w1_keeps_w2_stars", merged.Worlds.W2.Awakening[slow] == 3 and merged.Awakening == nil)
			return
		end
		GachaService.Awaken(p, slow)
		GachaService.Awaken(p, slow)
		local folded = WorldSave.Fold(GachaService.Snapshot(p), old, 2)
		flag("w2_saved_under_w2", folded.Worlds.W2.Awakening and folded.Worlds.W2.Awakening[slow] == 2)
		flag("w2_not_top_level", folded.Awakening == nil)
		flag("w2_copies_saved_spent", folded.Copies[slow] == 6)
		local stored = table.clone(old)
		for key, value in folded do
			stored[key] = value
		end
		local p2 = newPlayer(0)
		GachaService.Apply(p2, WorldSave.View(stored, 2))
		flag("w2_survives_load", GachaService.Stars(p2, slow) == 2 and GachaService.Copies(p2, slow) == 6)
		-- a bad saved value loads clamped; an unowned id is ignored
		stored.Worlds.W2.Awakening = { [slow] = 99, ghost = 3 }
		GachaService.Apply(p2, WorldSave.View(stored, 2))
		flag("w2_bad_value_clamped", GachaService.Stars(p2, slow) == 5 and GachaService.Stars(p2, "ghost") == 0)
	end)

	-- Review 2026-11-24: an unknown Worlds.W2 key and the stars survive a View / Fold / save round trip in either world
	section("unknown_keys", function()
		local world = W2 and 2 or 1
		local stored = {
			Cars = { slow },
			Copies = { [slow] = 4 },
			Team = { slow },
			Worlds = { W2 = { Awakening = { [slow] = 2 }, FutureKey = { x = 1 }, Team = { slow } } },
		}
		local p = newPlayer(0)
		GachaService.Apply(p, WorldSave.View(stored, world))
		local merged = table.clone(stored) -- PlayerData.Save: the stored record overlaid with the folded payload
		for key, value in WorldSave.Fold(GachaService.Snapshot(p), stored, world) do
			merged[key] = value
		end
		local w2 = merged.Worlds and merged.Worlds.W2
		flag("round_trip_unknown_key_kept", w2 and type(w2.FutureKey) == "table" and w2.FutureKey.x == 1)
		flag("round_trip_stars_kept", w2 and w2.Awakening and w2.Awakening[slow] == 2)
		flag("round_trip_copies_kept", merged.Copies[slow] == 4)
	end)

	-- Review 2026-11-24: Copies and the star change in one step; World 1's uses of Copies are not weakened
	section("one_step_and_w1_uses", function()
		if not W2 then
			return
		end
		local p = newPlayer(3)
		local points, unique, bag = GachaService.FreePoints(p), GachaService.UniqueCount(p), GachaService.BagUsed(p)
		local thread = coroutine.create(GachaService.Awaken)
		local resumed, ok = coroutine.resume(thread, p, slow)
		flag("no_yield", resumed and ok == true and coroutine.status(thread) == "dead")
		flag("both_changed", GachaService.Copies(p, slow) == 2 and GachaService.Stars(p, slow) == 1)
		-- the owned copy, the Index and stat points stay; the bag frees the spent space
		flag("still_owned", GachaService.Owns(p, slow) == true and GachaService.UniqueCount(p) == unique)
		flag("stat_points_same", GachaService.FreePoints(p) == points, GachaService.FreePoints(p), points)
		flag("bag_frees_cost", GachaService.BagUsed(p) == bag - 1, GachaService.BagUsed(p), bag - 1)
		-- selling spares counts only the Copies left; the last copy is never sold
		flag("sell_over_left_refused", GachaService.SellSpares(p, slow, 3) == false)
		flag("copies_never_negative", GachaService.Copies(p, slow) == 2)
	end)

	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
