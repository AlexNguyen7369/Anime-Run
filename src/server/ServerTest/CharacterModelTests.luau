--!nonstrict
-- BRIEF: docs/WORLD2_SPEC.md "Cast in game" (Server/CharacterModelService): a world's server loads its own cast at start; another
-- world's character or Sidekick loads once, when a player in the server owns it or a rig wears it.
-- The load rules run where the service has not started (tools/lune): models come from ServerStorage.BakedModels, InsertService,
-- Players and RunnerFactory.Restyle are stubbed. In a live server only the state the real Start left is checked.
-- On demand: ReplicatedStorage attributes ServerTestOnly = "character_models", then ServerTestRun = true.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990257000
local READY_WAIT = 12 -- seconds: a failing asset is retried after 1, 2 and 3 s
local LIVE_WAIT = 60
local POLL = 0.05
local TRIES = 3

local function waitUntil(fn, seconds)
	local deadline = os.clock() + seconds
	while not fn() and os.clock() < deadline do
		task.wait(POLL)
	end
	return fn() == true
end

local function count(root, name)
	local n = 0
	for _, child in root:GetChildren() do
		n += child.Name == name and 1 or 0
	end
	return n
end

-- Ids whose folder is not there exactly once, or is there unwanted.
local function wrongFolders(root, want)
	local bad = {}
	for id in want do
		if count(root, id) ~= 1 then
			table.insert(bad, id .. "x" .. count(root, id))
		end
	end
	for _, child in root:GetChildren() do
		if not want[child.Name] then
			table.insert(bad, "extra " .. child.Name)
		end
	end
	return table.concat(bad, ",")
end

-- The runner models every world shows (docs/WORLD2_SPEC.md "Cast in game"): the starter picks', and the exclusive's.
local EVERY_WORLD = { leaf_hero = true, sea_captain = true, db_hero = true, punch_hero = true }

-- What a server nobody has brought another world's model into holds, from the catalogs alone.
local function ownSets()
	local Catalog, Cfg = require(Shared.CharacterCatalog), require(Shared.SidekickConfig)
	local other = 3 - require(Shared.WorldConfig).Id
	local characters, sidekicks = {}, {}
	for id in require(Shared.CharacterModelAssets) do
		local spec = Catalog.Get(id)
		characters[id] = (EVERY_WORLD[id] or spec == nil or spec.World ~= other) or nil
	end
	for id, art in require(Shared.SidekickArt) do
		sidekicks[id] = art.Model and true or nil
	end
	for _, row in Cfg.Lists[other] do
		sidekicks[row.Id] = nil
	end
	return characters, sidekicks
end

local function modelOf(id)
	local spec = require(Shared.CharacterCatalog).Get(id)
	return spec and spec.Model or id
end

-- A server already running the service: Ready, its own cast loaded, no folder twice. Which others
-- are here depends on every player and rig so far, so that is judged in the mocked run only.
local function live(flag, root)
	local Assets = require(Shared.CharacterModelAssets)
	local sideRoot = ReplicatedStorage:FindFirstChild("SidekickModels")
	flag(
		"live_ready",
		waitUntil(function()
			return root:GetAttribute("Ready") == true and sideRoot ~= nil and sideRoot:GetAttribute("Ready") == true
		end, LIVE_WAIT)
	)
	local characters, sidekicks = ownSets()
	local missing, twice, parts = {}, {}, {}
	for id in characters do
		if count(root, id) ~= 1 or root:GetAttribute("Loaded_" .. id) ~= true then
			table.insert(missing, id)
		end
	end
	for id in sidekicks do
		if sideRoot == nil or count(sideRoot, id) ~= 1 then
			table.insert(missing, id)
		end
	end
	for _, folder in root:GetChildren() do
		if count(root, folder.Name) > 1 then
			table.insert(twice, folder.Name)
		end
		local sizes = 0
		for _ in Assets[folder.Name].Sizes do
			sizes += 1
		end
		if folder:GetAttribute("Parts") ~= #folder:GetChildren() or #folder:GetChildren() ~= sizes then
			table.insert(parts, folder.Name)
		end
	end
	for _, model in sideRoot and sideRoot:GetChildren() or {} do
		if count(sideRoot, model.Name) > 1 then
			table.insert(twice, model.Name)
		end
	end
	flag("live_own_cast_loaded", #missing == 0, table.concat(missing, ","), "")
	flag("live_no_model_twice", #twice == 0, table.concat(twice, ","), "")
	flag("live_parts_attribute", #parts == 0, table.concat(parts, ","), "")
end

local function mocked(flag, cleanup)
	local Service, Assets = require(Server.CharacterModelService), require(Shared.CharacterModelAssets)
	local Art, Cfg = require(Shared.SidekickArt), require(Shared.SidekickConfig)
	local Catalog, RunnerFactory = require(Shared.CharacterCatalog), require(Shared.RunnerFactory)
	local other = 3 - require(Shared.WorldConfig).Id

	local lazy = {}
	for _, spec in Catalog.Rollable(other) do
		if Assets[spec.Id] and not Service.Eager(spec.Id) then
			table.insert(lazy, spec.Id)
		end
	end
	local lazySides = {}
	for _, row in Cfg.Lists[other] do
		if Art[row.Id] and Art[row.Id].Model then
			table.insert(lazySides, row.Id)
		end
	end
	flag("test_has_other_world_ids", #lazy >= 9 and #lazySides >= 4, #lazy .. "/" .. #lazySides, "9/4")
	local early, earlyWorn, owned, gained, worn, lateData, failing, flaky, quiet = table.unpack(lazy, 1, 9)
	local eagerFail
	for id in Assets do
		if Service.Eager(id) and Catalog.Get(id) and Catalog.Get(id).Rollable then
			eagerFail = id
			break
		end
	end

	-- BakedModels, the seam fetch reads before InsertService
	local baked = Instance.new("Folder")
	baked.Name, baked.Parent = "BakedModels", ServerStorage
	table.insert(cleanup, baked)
	local function bake(assetId, names, parent)
		local model = Instance.new("Model")
		model.Name, model.Parent = tostring(assetId), parent
		local inner = Instance.new("Model")
		inner.Name, inner.Parent = "Inner", model
		for _, name in names do
			local part = Instance.new("MeshPart")
			part.Name, part.Parent = name, inner
		end
		local junk = Instance.new("MeshPart")
		junk.Name, junk.Parent = "NotInSizes", inner
		return model
	end
	local function partNames(id)
		local names = {}
		for name in Assets[id].Sizes do
			table.insert(names, name)
		end
		return names
	end
	local unbaked = { [failing] = true, [flaky] = true, [eagerFail] = true }
	for id, row in Assets do
		if not unbaked[id] then
			bake(row.Asset, partNames(id), baked)
		end
	end
	for _, art in Art do
		for _, assetId in { art.Model or false, art.BossModel or false } do
			if assetId and not baked:FindFirstChild(tostring(assetId)) then
				bake(assetId, { "Body" }, baked)
			end
		end
	end
	local tries, flakyAsset = {}, Assets[flaky].Asset
	InsertService.LoadAsset = function(_, assetId)
		tries[assetId] = (tries[assetId] or 0) + 1
		if assetId == flakyAsset and tries[assetId] == TRIES then
			return bake(assetId, partNames(flaky), nil)
		end
		error("no network")
	end

	local nextUid = UID
	local function newPlayer(ids, bag)
		nextUid += 1
		local p = H.player(cleanup, nextUid)
		if bag then
			p:SetAttribute("SidekickBag", bag)
		end
		if ids then
			local data = Instance.new("Folder")
			data.Name = "GachaData"
			for _, id in ids do
				local entry = Instance.new("StringValue")
				entry.Name, entry.Parent = id, data
			end
			data.Parent = p
		end
		return p
	end
	local function gain(p, id)
		local entry = Instance.new("StringValue")
		entry.Name, entry.Parent = id, p:FindFirstChild("GachaData")
	end
	local function newRig(id)
		local rig = Instance.new("Model")
		rig:SetAttribute("CharacterId", id)
		CollectionService:AddTag(rig, RunnerFactory.RIG_TAG)
		rig.Parent = workspace
		table.insert(cleanup, rig)
		return rig
	end
	local restyled = {}
	RunnerFactory.Restyle = function(rig, id)
		restyled[rig] = restyled[rig] or {}
		restyled[rig][id] = (restyled[rig][id] or 0) + 1
	end
	local function bagOf(...)
		local rows = {}
		for i, id in { ... } do
			rows[i] = { Id = id, Entry = "e" .. i }
		end
		return HttpService:JSONEncode(rows)
	end

	-- Here before Start: a player and a rig of another world, and an own-world rig
	local earlyPlayer = newPlayer({ early }, bagOf(lazySides[1]))
	local slow = newPlayer(nil) -- its GachaData comes later; not through PlayerAdded, where GachaService would add it at once
	Players.GetPlayers = function()
		return { earlyPlayer, slow }
	end
	local earlyRig = newRig(earlyWorn)
	local ownId = Catalog.Rollable()[2].Id == eagerFail and Catalog.Rollable()[3].Id or Catalog.Rollable()[2].Id
	local ownRig = newRig(ownId)
	local eagerCharacters, eagerSides = ownSets()
	local want, wantSides = table.clone(eagerCharacters), table.clone(eagerSides)
	want[eagerFail], want[early], want[earlyWorn] = nil, true, true
	wantSides[lazySides[1]] = true

	Service.Start()
	local root, sideRoot =
		ReplicatedStorage:FindFirstChild("CharacterModels"), ReplicatedStorage:FindFirstChild("SidekickModels")
	for _, folder in { root, sideRoot, ReplicatedStorage:FindFirstChild("BossModels") } do
		table.insert(cleanup, folder)
	end
	flag("not_ready_while_loading", root:GetAttribute("Ready") ~= true)
	flag(
		"ready_after_a_failed_model",
		waitUntil(function()
			return root:GetAttribute("Ready") == true and sideRoot:GetAttribute("Ready") == true
		end, READY_WAIT)
	)
	flag("start_loads_only_its_cast_and_the_early", wrongFolders(root, want) == "", wrongFolders(root, want), "")
	flag(
		"start_loads_only_its_sidekicks_and_the_early",
		wrongFolders(sideRoot, wantSides) == "",
		wrongFolders(sideRoot, wantSides),
		""
	)
	local loadedOk = true
	for id in Assets do
		loadedOk = loadedOk and (root:GetAttribute("Loaded_" .. id) == true) == (want[id] == true or id == eagerFail)
	end
	flag("loaded_attribute_per_finished_id", loadedOk)
	flag(
		"failed_eager_load_sets_loaded",
		root:GetAttribute("Loaded_" .. eagerFail) == true and root:FindFirstChild(eagerFail) == nil
	)
	flag("failed_load_tried_3_times", tries[Assets[eagerFail].Asset] == TRIES, tries[Assets[eagerFail].Asset], TRIES)
	flag("own_rig_restyled_at_ready", restyled[ownRig] ~= nil and restyled[ownRig][ownId] == 1)
	flag("early_rig_restyled", restyled[earlyRig] ~= nil and (restyled[earlyRig][earlyWorn] or 0) >= 1)
	local partsOk = true
	for id in want do
		local folder, n = root:FindFirstChild(id), 0
		for name, size in Assets[id].Sizes do
			n += 1
			local part = folder and folder:FindFirstChild(name)
			partsOk = partsOk and part ~= nil and part.Size == size * RunnerFactory.SCALE and part.Anchored == true
		end
		partsOk = partsOk and folder ~= nil and #folder:GetChildren() == n and folder:GetAttribute("Parts") == n
	end
	flag("parts_attribute_and_sizes", partsOk)

	local function arrives(name, id)
		local model = modelOf(id)
		flag(
			name,
			waitUntil(function()
				return root:GetAttribute("Loaded_" .. model) == true and count(root, model) == 1
			end, 2),
			count(root, model),
			1
		)
	end
	-- owned on joining, and gained while playing
	local p = newPlayer({ owned, "future_hero" })
	Players.PlayerAdded:Fire(p)
	arrives("owned_on_join_loads", owned)
	flag("not_loaded_before_gained", root:FindFirstChild(gained) == nil)
	local wearer = newRig(gained) -- a rig of it is here too: both triggers, one load
	gain(p, gained)
	arrives("gained_loads", gained)
	flag("gained_rig_restyled", restyled[wearer] ~= nil and restyled[wearer][gained] == 1)
	flag("other_rigs_not_restyled", restyled[ownRig][ownId] == 1)
	-- worn by a rig nobody here owns; the parts attribute of a late folder
	local wornRig = newRig(worn)
	arrives("worn_loads", worn)
	flag("worn_rig_restyled", restyled[wornRig] ~= nil and restyled[wornRig][worn] == 1)
	local wornFolder = root:FindFirstChild(worn)
	flag(
		"late_parts_attribute",
		wornFolder ~= nil
			and wornFolder:GetAttribute("Parts") == #partNames(worn)
			and #wornFolder:GetChildren() == #partNames(worn)
	)
	CollectionService:AddTag(Instance.new("Model"), RunnerFactory.RIG_TAG)
	local nameless = Instance.new("Model")
	CollectionService:AddTag(nameless, RunnerFactory.RIG_TAG)
	nameless.Parent = workspace -- no CharacterId: nothing to load, no error
	table.insert(cleanup, nameless)
	newRig("starter")
	-- not twice: a second owner, a second rig, the entry again
	Players.PlayerAdded:Fire(newPlayer({ owned, gained, worn, early }))
	newRig(owned)
	newRig(worn)
	gain(p, gained)
	gain(p, worn)
	task.wait(0.2)
	local once = {}
	for _, id in { early, earlyWorn, owned, gained, worn } do
		if count(root, id) ~= 1 then
			table.insert(once, id)
		end
	end
	flag("never_loaded_twice", #once == 0, table.concat(once, ","), "")
	-- no GachaData yet
	flag("no_data_yet_loads_nothing", slow:FindFirstChild("GachaData") == nil and root:FindFirstChild(lateData) == nil)
	local data = Instance.new("Folder")
	data.Name, data.Parent = "GachaData", slow
	gain(slow, lateData)
	arrives("data_after_join_loads", lateData)
	-- an own-world id that is already here
	gain(p, ownId)
	-- failing and flaky uploads, each asked for twice while the first load is still running
	gain(p, failing)
	newRig(failing)
	gain(p, flaky)
	newRig(flaky)
	flag("failed_not_loaded_at_once", root:GetAttribute("Loaded_" .. failing) ~= true)
	flag("failed_load_sets_loaded", waitUntil(function()
		return root:GetAttribute("Loaded_" .. failing) == true
	end, READY_WAIT) and root:FindFirstChild(failing) == nil)
	flag("failed_load_one_set_of_tries", tries[Assets[failing].Asset] == TRIES, tries[Assets[failing].Asset], TRIES)
	arrives("retried_load_arrives", flaky)
	flag("retried_load_one_set_of_tries", tries[flakyAsset] == TRIES, tries[flakyAsset], TRIES)
	flag("own_world_id_not_loaded_again", count(root, ownId) == 1, count(root, ownId), 1)
	flag("untouched_id_never_loaded", root:FindFirstChild(quiet) == nil)

	-- Sidekicks: the bag's JSON
	local function sideArrives(name, id)
		flag(
			name,
			waitUntil(function()
				return count(sideRoot, id) == 1
			end, 2),
			count(sideRoot, id),
			1
		)
	end
	local sp = newPlayer({})
	Players.PlayerAdded:Fire(sp)
	for _, bad in { "{oops", "", "5", '"text"', "null", "{}", "[]" } do
		sp:SetAttribute("SidekickBag", bad)
	end
	task.wait(0.1)
	flag("bad_bags_load_nothing", wrongFolders(sideRoot, wantSides) == "", wrongFolders(sideRoot, wantSides), "")
	sp:SetAttribute("SidekickBag", bagOf("side_future", lazySides[2], "side_raga"))
	sideArrives("sidekick_gained_loads", lazySides[2])
	sp:SetAttribute("SidekickBag", bagOf(lazySides[2], lazySides[2], lazySides[3]))
	sideArrives("second_sidekick_gained_loads", lazySides[3])
	local other2 = newPlayer({}, bagOf(lazySides[1], lazySides[2], lazySides[3]))
	Players.PlayerAdded:Fire(other2)
	local badJoin = newPlayer({ quiet }, "{oops")
	Players.PlayerAdded:Fire(badJoin)
	arrives("bad_bag_still_loads_characters", quiet)
	task.wait(0.1)
	wantSides[lazySides[2]], wantSides[lazySides[3]] = true, true
	flag("sidekicks_once_and_no_others", wrongFolders(sideRoot, wantSides) == "", wrongFolders(sideRoot, wantSides), "")
	for _, id in { owned, gained, worn, lateData, flaky, quiet } do
		want[id] = true
	end
	flag("characters_once_and_no_others", wrongFolders(root, want) == "", wrongFolders(root, want), "")
end

function Tests.character_models()
	local r, flag = H.report("character_models")
	local cleanup = {}
	local RunnerFactory = require(Shared.RunnerFactory)
	local root = ReplicatedStorage:FindFirstChild("CharacterModels")
	local restyle = RunnerFactory.Restyle
	local getPlayers, loadAsset = Players.GetPlayers, not root and InsertService.LoadAsset or nil
	local ok, err = xpcall(function()
		if root then
			live(flag, root)
		else
			mocked(flag, cleanup)
			Players.GetPlayers, InsertService.LoadAsset = getPlayers, loadAsset
		end
	end, debug.traceback)
	flag("character_models_completed", ok, ok and 1 or tostring(err))
	RunnerFactory.Restyle = restyle
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
