--!nonstrict
-- BRIEF: docs/WORKSHOP_SPEC.md "5b. Showcase" (owner, 2026-10-22), docs/SAVE_SPEC.md VERSION 12, design doc
-- owner 2026-10-22 entries: "players show 3 cars of their choice in their workshop; duplicate rolls of those cars
-- raise workshop Speed gain ... duplicates are never sold (kept as copies), the player picks the 3 cars, and the
-- bonus comes from the car's SpeedMulti x its copies."
--   * Copies: a roll / grant of an already-owned rollable car adds 1 to GachaData.<id> attribute Copies, pays $0
--     (Roll's 5th return, scrapMoney, is 0; leaderstats.Money unchanged). GachaConfig.SCRAP_MONEY / ScrapMoney and
--     GachaService.ScrapValue are removed.
--   * retired: SlotBonus / ShowcaseMulti / WorkshopMulti, the copy bonus and the offline credit (design doc 4.19,
--     owner 2026-11-03: the squad gives a stat boost by rarity, copies no longer count, no passive / offline gain).
--   * SetShowcase(player, ids): array of <= 3 distinct owned rollable ids (never starter / gamepass); anything else
--     returns false and changes nothing. Attribute Showcase ("a,b,c"). Remotes.SetShowcase is a RemoteFunction.
--   * Save: Snapshot/Apply carry Copies { [id] = n >= 1 } and Showcase { id, ... }; old saves load 0 / empty;
--     PlayerData VERSION 14 (13: Team; 14: Gems). A rebirth keeps both (checked in the rebirth scenario).
--   * World: the owner's Plot_N.Workshop has ShowcasePedestal_1..3 (anchored, non-colliding); k showcased characters
--     = k pedestals holding that character's runner rig (H.isRig, child "Runner" or "Car"; CarModels is scrapped,
--     docs/WORLD_REDESIGN_SPEC.md section 2, owner 2026-10-29); labels have a finite MaxDistance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent
local H = require(script.Parent.AcceptanceSupport)
local Tests = {}

-- The spec's numbers (docs/WORKSHOP_SPEC.md 5b). Independent oracle: never read from GachaConfig.
local SPEC = { SLOTS = 3, VERSION = 14 }
local UID = 990122000

function Tests.showcase()
	local r, flag = H.report("showcase")
	local catalog = H.module(Shared, "CharacterCatalog")
	local config = H.module(Shared, "GachaConfig")
	local workshop = H.module(Shared, "Workshop")
	local wconfig = H.module(Shared, "WorkshopConfig")
	local gacha = H.module(Server, "GachaService")
	local data = H.module(Server, "PlayerData")
	local wservice = H.module(Server, "WorkshopService")
	local api = catalog
		and config
		and workshop
		and wconfig
		and gacha
		and data
		and wservice
		and type(gacha.Copies) == "function"
		and type(gacha.SetShowcase) == "function"
		and type(gacha.Snapshot) == "function"
		and type(gacha.Apply) == "function"
		and type(wservice.Assign) == "function"
		and type(wservice.Release) == "function"
	flag("showcase_api_exists", api == true)
	if not api then
		return r
	end

	local cleanup, assigned = {}, {}
	local function fake(name)
		UID += 1
		local p = H.player(cleanup, UID)
		p.Name = "CarTestShowcase" .. name
		p:SetAttribute("DisplayName", "SC " .. name)
		data.Setup(p)
		gacha.Setup(p)
		return p, UID
	end

	local ok, err = pcall(function()
		-- 1. Config: the spec's numbers; scrap removed
		flag("showcase_config_matches_spec", config.SHOWCASE_SLOTS == SPEC.SLOTS)
		local cap = config.MAX_SAVED_COPIES
		flag(
			"showcase_max_saved_copies_large_integer",
			type(cap) == "number" and cap == math.floor(cap) and cap >= 1e6 and cap < math.huge,
			type(cap) == "number" and cap or -1,
			1e6
		)
		local cd = config.SHOWCASE_COOLDOWN
		flag(
			"showcase_cooldown_seconds",
			type(cd) == "number" and cd > 0 and cd < math.huge,
			type(cd) == "number" and cd or -1,
			">0"
		)
		flag(
			"duplicate_scrap_money_removed",
			config.SCRAP_MONEY == nil and config.ScrapMoney == nil and gacha.ScrapValue == nil
		)
		-- design doc 4.19 (owner 2026-11-03): the showcase multi of idle gain and the copy bonus are gone
		flag(
			"showcase_multi_removed",
			config.SlotBonus == nil
				and config.ShowcaseMulti == nil
				and config.COPY_BONUS == nil
				and config.MAX_COPIES == nil
				and gacha.ShowcaseMulti == nil
				and gacha.WorkshopMulti == nil
				and wservice.Rate == nil
		)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local remote = remotes and remotes:FindFirstChild("SetShowcase")
		flag("showcase_remote_is_remote_function", remote ~= nil and remote:IsA("RemoteFunction"))

		-- 2. retired: SlotBonus / ShowcaseMulti formula (design doc 4.19, owner 2026-11-03)

		-- 3. Copies: a duplicate grant adds 1 copy and pays nothing
		local p = fake("Copies")
		local money = p.leaderstats.Money
		money.Value = 777
		local earned0 = p:GetAttribute("MoneyEarned") or 0
		flag("copies_new_grant_true", gacha.Grant(p, "leaf_copycat") == true)
		local entry = p.GachaData:FindFirstChild("leaf_copycat")
		flag(
			"copies_fresh_car_zero",
			gacha.Copies(p, "leaf_copycat") == 0 and entry ~= nil and (entry:GetAttribute("Copies") or 0) == 0
		)
		local dupe = gacha.Grant(p, "leaf_copycat")
		flag(
			"copies_duplicate_grant_false_plus_one",
			dupe == false and gacha.Copies(p, "leaf_copycat") == 1 and entry:GetAttribute("Copies") == 1,
			gacha.Copies(p, "leaf_copycat"),
			1
		)
		gacha.Grant(p, "leaf_copycat")
		gacha.Grant(p, "leaf_copycat")
		flag("copies_count_each_duplicate", gacha.Copies(p, "leaf_copycat") == 3, gacha.Copies(p, "leaf_copycat"), 3)
		flag("copies_one_entry_only", #p.GachaData:GetChildren() == 1)
		flag(
			"copies_duplicate_grant_no_money",
			money.Value == 777 and (p:GetAttribute("MoneyEarned") or 0) == earned0,
			money.Value,
			777
		)
		flag(
			"copies_unowned_or_bad_id_zero",
			gacha.Copies(p, "db_tyrant") == 0 and gacha.Copies(p, "no_such_car") == 0 and gacha.Copies(p, nil) == 0
		)

		-- 4. Rolls: an owner of every rollable car rolls only duplicates: copies +1 each, scrapMoney 0, Money unchanged
		local q = fake("Rolls")
		for _, spec in catalog.Rollable() do
			gacha.Grant(q, spec.Id)
		end
		local function totalCopies()
			local n = 0
			for _, e in q.GachaData:GetChildren() do
				n += gacha.Copies(q, e.Name)
			end
			return n
		end
		q.leaderstats.Money.Value = 4321
		local qEarned = q:GetAttribute("MoneyEarned") or 0
		local before, rollBad, scrapBad = totalCopies(), 0, 0
		local rng = Random.new(2210)
		local ROLLS = 25
		for _ = 1, ROLLS do
			local okR, _, isNew, _, _, scrap = pcall(gacha.Roll, q, rng)
			if not okR or isNew ~= false then
				rollBad += 1
			end
			if scrap ~= 0 then
				scrapBad += 1
			end
		end
		flag("roll_duplicate_not_new", rollBad == 0, rollBad, 0)
		flag("roll_duplicate_scrap_money_zero", scrapBad == 0, scrapBad, 0)
		flag("roll_duplicates_add_copies", totalCopies() == before + ROLLS, totalCopies() - before, ROLLS)
		flag(
			"roll_duplicate_money_unchanged",
			q.leaderstats.Money.Value == 4321 and (q:GetAttribute("MoneyEarned") or 0) == qEarned,
			q.leaderstats.Money.Value,
			4321
		)

		-- 5. SetShowcase: validation; a rejected request changes nothing
		local s = fake("Set")
		for _, id in { "leaf_copycat", "leaf_medic", "db_tyrant", "leaf_hero" } do
			gacha.Grant(s, id)
		end
		gacha.Grant(s, "leaf_copycat") -- 1 copy
		gacha.Grant(s, "leaf_copycat") -- 2 copies
		local okBase, reasonBase = gacha.SetShowcase(s, { "leaf_copycat" })
		flag("set_showcase_one_car", okBase == true and s:GetAttribute("Showcase") == "leaf_copycat", reasonBase)
		local bad = {
			{ "nil_ids", nil },
			{ "string_ids", "leaf_copycat" },
			{ "number_ids", 5 },
			{ "four_cars", { "leaf_copycat", "leaf_medic", "db_tyrant", "leaf_hero" } },
			{ "duplicates", { "leaf_copycat", "leaf_copycat" } },
			{ "non_string", { "leaf_copycat", 5 } },
			{ "unowned", { "sea_navigator" } },
			{ "unknown", { "no_such_car" } },
			{ "starter", { "starter" } },
			{ "sparse", { [1] = "leaf_copycat", [3] = "leaf_medic" } },
			{ "dictionary", { a = "leaf_copycat" } },
			{ "mixed", { "leaf_medic", x = "db_tyrant" } },
		}
		local rejectBad = {}
		for _, case in bad do
			local okC, accepted = pcall(gacha.SetShowcase, s, case[2])
			if not okC or accepted ~= false or s:GetAttribute("Showcase") ~= "leaf_copycat" then
				table.insert(rejectBad, case[1])
				gacha.SetShowcase(s, { "leaf_copycat" })
			end
		end
		flag("set_showcase_rejects_invalid", #rejectBad == 0, table.concat(rejectBad, ","), "")
		local three = { "leaf_copycat", "db_tyrant", "leaf_hero" }
		local okThree = gacha.SetShowcase(s, three)
		flag(
			"set_showcase_three_cars",
			okThree == true and s:GetAttribute("Showcase") == "leaf_copycat,db_tyrant,leaf_hero"
		)
		-- retired: showcase_multi_formula / uses_copies / follows_new_copy, workshop_multi_includes_showcase,
		-- workshop_rate_includes_showcase (design doc 4.19, owner 2026-11-03: no showcase multi, no passive gain)
		gacha.Grant(s, "db_tyrant") -- 1 copy (the snapshot below expects it)
		local okEmpty = gacha.SetShowcase(s, {})
		flag("set_showcase_empty_clears", okEmpty == true and s:GetAttribute("Showcase") == "")

		-- 6. Snapshot / Apply cleaning
		gacha.SetShowcase(s, { "leaf_hero", "leaf_copycat" })
		local snap = gacha.Snapshot(s)
		flag(
			"snapshot_copies_only_positive",
			type(snap.Copies) == "table" and H.same(snap.Copies, { leaf_copycat = 2, db_tyrant = 1 })
		)
		flag(
			"snapshot_showcase_in_order",
			type(snap.Showcase) == "table" and H.same(snap.Showcase, { "leaf_hero", "leaf_copycat" })
		)
		local a = fake("Apply")
		gacha.Apply(a, {
			Cars = { "leaf_copycat", "leaf_medic", "db_tyrant" },
			Copies = { leaf_copycat = 3.9, leaf_medic = -2, db_tyrant = 1e15, leaf_hero = 7, starter = 4 },
			Showcase = {
				"leaf_copycat",
				"leaf_copycat",
				"leaf_hero",
				"starter",
				"no_such_car",
				7,
				"x",
				"leaf_medic",
			},
		})
		flag(
			"apply_copies_cleaned",
			gacha.Copies(a, "leaf_copycat") == 3
				and gacha.Copies(a, "leaf_medic") == 0
				and gacha.Copies(a, "db_tyrant") == config.MAX_SAVED_COPIES
				and gacha.Copies(a, "leaf_hero") == 0
				and a.GachaData:FindFirstChild("leaf_hero") == nil
		)
		local snapA = gacha.Snapshot(a)
		flag(
			"apply_snapshot_drops_unowned_copies",
			type(snapA.Copies) == "table"
				and snapA.Copies.leaf_hero == nil
				and snapA.Copies.starter == nil
				and snapA.Copies.leaf_medic == nil
		)
		local shown = string.split(a:GetAttribute("Showcase") or "", ",")
		local seen, showOk = {}, #shown >= 1 and #shown <= SPEC.SLOTS and shown[1] == "leaf_copycat"
		for _, id in shown do
			showOk = showOk and not seen[id] and (id == "leaf_copycat" or id == "leaf_medic")
			seen[id] = true
		end
		flag("apply_showcase_cleaned", showOk, a:GetAttribute("Showcase"), "leaf_copycat[,leaf_medic]")
		local b = fake("ApplyFour")
		gacha.Apply(b, {
			Cars = { "leaf_copycat", "leaf_medic", "db_tyrant", "leaf_hero" },
			Showcase = { "leaf_copycat", "leaf_medic", "db_tyrant", "leaf_hero" },
		})
		local four = string.split(b:GetAttribute("Showcase") or "", ",")
		flag("apply_showcase_at_most_3", #four == SPEC.SLOTS, #four, SPEC.SLOTS)
		local junkBad = 0
		for _, junk in
			{
				{ Cars = { "leaf_copycat" }, Copies = "junk", Showcase = "junk" },
				{ Cars = { "leaf_copycat" }, Copies = { leaf_copycat = 0 / 0 }, Showcase = { leaf_copycat = true } },
				{ Cars = { "leaf_copycat" }, Copies = { leaf_copycat = "9" } },
			}
		do
			local j = fake("Junk")
			local okJ = pcall(gacha.Apply, j, junk)
			if not okJ or gacha.Copies(j, "leaf_copycat") ~= 0 or (j:GetAttribute("Showcase") or "") ~= "" then
				junkBad += 1
			end
		end
		flag("apply_junk_fields_safe", junkBad == 0, junkBad, 0)
		local old = fake("OldSave")
		gacha.Apply(old, { Cars = { "leaf_copycat", "db_tyrant" }, Equipped = "leaf_copycat", Rolls = 4 })
		local snapOld = gacha.Snapshot(old)
		flag(
			"apply_old_save_zero_copies_empty_showcase",
			gacha.Copies(old, "leaf_copycat") == 0
				and (old:GetAttribute("Showcase") or "") == ""
				and type(snapOld.Copies) == "table"
				and next(snapOld.Copies) == nil
				and type(snapOld.Showcase) == "table"
				and #snapOld.Showcase == 0
		)

		-- 7. PlayerData VERSION 14: save round trip, old save upgraded (offline credit retired, design doc 4.19)
		local function record(showcase)
			return {
				Version = SPEC.VERSION,
				Money = 10,
				WorkshopLevel = 1,
				Cars = { "leaf_copycat", "db_tyrant" },
				Copies = { leaf_copycat = 4 },
				Showcase = showcase,
			}
		end
		local uidShown, uidBare, uidOld = UID + 101, UID + 102, UID + 103
		local store = H.store({
			[data.KeyFor(uidShown)] = record({ "leaf_copycat", "db_tyrant" }),
			[data.KeyFor(uidBare)] = record({}),
			[data.KeyFor(uidOld)] = { Version = 11, Money = 5, Speed = 1, Cars = { "leaf_copycat" } },
		})
		data.SetStore(store)
		local pShown = H.player(cleanup, uidShown)
		local pBare = H.player(cleanup, uidBare)
		flag("data_load_showcase_save", data.Load(pShown, uidShown) == true and data.Load(pBare, uidBare) == true)
		flag(
			"data_load_applies_copies_and_showcase",
			gacha.Copies(pShown, "leaf_copycat") == 4 and pShown:GetAttribute("Showcase") == "leaf_copycat,db_tyrant"
		)
		gacha.Grant(pShown, "leaf_copycat") -- 5 copies
		flag("data_save_ok", data.Save(pShown, uidShown, true) == true)
		local rec = store.data[data.KeyFor(uidShown)]
		flag(
			"data_saved_version_13",
			type(rec) == "table" and rec.Version == SPEC.VERSION,
			type(rec) == "table" and rec.Version or -1,
			SPEC.VERSION
		)
		flag(
			"data_saved_copies_and_showcase",
			type(rec) == "table"
				and H.same(rec.Copies, { leaf_copycat = 5 })
				and H.same(rec.Showcase, { "leaf_copycat", "db_tyrant" })
		)
		local back = H.player(cleanup, uidShown)
		flag("data_reload", data.Load(back, uidShown) == true)
		flag(
			"data_round_trip_copies_and_showcase",
			gacha.Copies(back, "leaf_copycat") == 5
				and gacha.Copies(back, "db_tyrant") == 0
				and back:GetAttribute("Showcase") == "leaf_copycat,db_tyrant"
		)
		local pOld = H.player(cleanup, uidOld)
		flag("data_old_save_loads", data.Load(pOld, uidOld) == true)
		flag(
			"data_old_save_zero_copies_empty_showcase",
			gacha.Copies(pOld, "leaf_copycat") == 0 and (pOld:GetAttribute("Showcase") or "") == ""
		)
		data.Save(pOld, uidOld, true)
		local recOld = store.data[data.KeyFor(uidOld)]
		flag(
			"data_old_save_upgraded_to_13",
			type(recOld) == "table"
				and recOld.Version == SPEC.VERSION
				and (recOld.Copies == nil or next(recOld.Copies) == nil)
				and (recOld.Showcase == nil or #recOld.Showcase == 0)
		)
		data.SetStore(nil)

		-- 8. World: pedestals on the owner's plot; every showcased character's runner rig stands on one
		local w = fake("World")
		for _, id in { "leaf_copycat", "db_tyrant", "leaf_hero" } do
			gacha.Grant(w, id)
		end
		gacha.SetShowcase(w, { "leaf_copycat", "db_tyrant" }) -- set before the plot exists, as on join
		local index = wservice.Assign(w)
		table.insert(assigned, w)
		local folder = Workspace:FindFirstChild("Workshops")
		local plot = folder and type(index) == "number" and folder:FindFirstChild("Plot_" .. index)
		local model = plot and plot:FindFirstChild("Workshop")
		flag("world_owner_has_workshop", model ~= nil, index, ">0")
		local pedestals, pedOk = {}, model ~= nil
		for i = 1, SPEC.SLOTS do
			local ped = model and model:FindFirstChild("ShowcasePedestal_" .. i, true)
			pedOk = pedOk and ped ~= nil and ped:IsA("BasePart") and ped.Anchored and not ped.CanCollide
			pedestals[i] = ped
		end
		flag("world_three_pedestals_anchored_non_colliding", pedOk)
		local function carsShown()
			local n, labels, labelsOk, anchored = 0, 0, true, true
			for _, ped in pedestals do
				local car = H.shown(ped)
				if H.isRig(car) then
					n += 1
					for _, d in car:GetDescendants() do
						if d:IsA("BasePart") and not d.Anchored then
							anchored = false
						end
					end
				end
				for _, d in (ped and ped:GetDescendants() or {}) do
					if d:IsA("BillboardGui") then
						labels += 1
						labelsOk = labelsOk and d.MaxDistance > 0 and d.MaxDistance < math.huge
					end
				end
			end
			return n, labels, labelsOk, anchored
		end
		local function waitShown(want)
			local deadline = os.clock() + 3
			repeat
				local n = carsShown()
				if n == want then
					break
				end
				task.wait(0.1)
			until os.clock() > deadline
			return carsShown()
		end
		if pedOk then
			local want2 = 2
			local n2, labels2, labelsOk2, anchored2 = waitShown(want2)
			flag("world_showcase_on_assign", n2 == want2, n2, want2)
			flag("world_showcase_labels_finite", labels2 >= n2 and labelsOk2, labels2, n2)
			flag("world_showcase_cars_static", anchored2)
			gacha.SetShowcase(w, { "leaf_copycat", "db_tyrant", "leaf_hero" })
			local want3 = 3
			local n3 = waitShown(want3)
			flag("world_showcase_follows_set", n3 == want3, n3, want3)
			gacha.SetShowcase(w, {})
			local n0 = waitShown(0)
			flag("world_showcase_cleared", n0 == 0, n0, 0)
		end
	end)
	for _, p in assigned do
		pcall(wservice.Release, p)
	end
	pcall(data.SetStore, nil)
	for _, object in cleanup do
		object:Destroy()
	end
	flag("showcase_no_error", ok, ok and 1 or tostring(err))
	return r
end

return Tests
