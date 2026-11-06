--!nonstrict
-- BRIEF: docs/BOSS_EVENT_SPEC.md "Paid spawn", docs/SIDEKICK_SPEC.md "Paid random item rules", design doc section 6 (task b9).
-- Written before the code: red by design. Fake receipts on Folder players and an isolated PlayerData clone.
-- On demand: ReplicatedStorage attributes CarTestOnly = "boss_paid", then CarTestRun = true.
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   MonetizationConfig.BossSpawn = { Id = "boss_spawn", Robux = 149, ProductId = 3728728633 }, not in Products.
--   Player attribute BossCredit, saved as the record's BossCredit, cleaned to a whole number >= 0, reset by /wipe.
--   ShopService seams, nil restores the real one:
--     SetPlayers(obj): obj:GetPlayerByUserId(id), as GiftService.SetPlayers. SetPrompt(fn): fn(player, productId) in place of
--     MarketplaceService:PromptProductPurchase. SetPolicy(fn): fn(player) returns the policy table, in place of
--     PolicyService:GetPolicyInfoForPlayerAsync; an error or a non-table refuses (fail closed).
--   ShopService.PromptBoss(player) and PromptGems(player, packId) return ok, message. A refusal has a non-empty message, and no prompt.
--     ProductId 0 refuses with "Coming soon". Restricted is judged first and sets player attribute PaidRandomRestricted = true.
--   ShopService.UseBossCredit(player) returns ok, message.
--   RemoteFunctions in ReplicatedStorage.Remotes: BossBuy(), GemPackBuy(packId), BossUseCredit().
--   A receipt already paid is always honoured, for a restricted player or with no Sidekick too: Roblox has taken the Robux.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990139000
local T0 = 2000000
local BOSS_PRODUCT = 990139901
local PACK_PRODUCT_BASE = 990139910
local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
local RETRY = Enum.ProductPurchaseDecision.NotProcessedYet
local REAL_BOSS_ID = 3728728633
local REAL_PACK_IDS =
	{ gems_1000 = 3728728637, gems_2500 = 3728728638, gems_10000 = 3728728641, gems_30000 = 3728728643 }

function Tests.boss_paid()
	local r, flag = H.report("boss_paid")
	local Shop, S = require(Server.ShopService), require(Server.BossEventService)
	local Monetization = require(Shared.MonetizationConfig)
	local Admin = require(Server.AdminService)
	local cleanup = {}
	local packIds = {}
	for i, pack in Monetization.GemPacks do
		packIds[i] = pack.ProductId
	end
	local bossId = Monetization.BossSpawn.ProductId
	local oldStudio = Admin.AllowStudio

	local function eq(name, actual, expected)
		flag(name, actual == expected, actual, expected)
	end
	local function section(name, body)
		local ok, err = xpcall(body, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end

	local ok, err = xpcall(function()
		local spawnProduct = Monetization.BossSpawn
		flag("config_exists", type(spawnProduct) == "table")
		eq("config_id", spawnProduct.Id, "boss_spawn")
		eq("config_robux", spawnProduct.Robux, 149)
		eq("config_product_id", spawnProduct.ProductId, REAL_BOSS_ID)
		for _, pack in Monetization.GemPacks do
			eq("config_product_id_" .. pack.Id, pack.ProductId, REAL_PACK_IDS[pack.Id])
		end
		for _, product in Monetization.Products do
			flag("config_not_in_products_" .. tostring(product.Id), product.Id ~= "boss_spawn")
		end

		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestBossPaidData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local store = H.store()
		data.SetStore(store)
		local gacha, sidekick = require(Server.GachaService), require(Server.SidekickService)
		local money = require(Server.MoneyService)
		local rollable = require(Shared.CharacterCatalog).Rollable()

		local online, ids = {}, {}
		local nextId, nextPurchase = UID, 0
		local failSave, holdSave, saves, lastSaved = false, false, 0, {}
		local prompts, restricted, policyBroken = {}, {}, false

		local function credit(p)
			return p:GetAttribute("BossCredit") or 0
		end
		local function gems(p)
			return p:GetAttribute("Gems") or 0
		end
		local function active()
			return ReplicatedStorage:GetAttribute("BossEventPhase") ~= nil
		end
		local function join(id, saved)
			if saved then
				store.data[data.KeyFor(id)] = saved
			end
			local p = H.player(cleanup, id)
			ids[p] = id
			online[id] = p
			data.Load(p, id)
			return p
		end
		local function buyer(armed)
			nextId += 1
			local p = join(nextId, { Version = 18 })
			if armed ~= false then
				gacha.Grant(p, rollable[1].Id)
				local _, entry = sidekick.Grant(p, "side_knight")
				assert(sidekick.Equip(p, rollable[1].Id, entry))
			end
			return p
		end
		local function purchase()
			nextPurchase += 1
			return "boss-paid-" .. nextPurchase
		end
		local function receipt(p, productId, purchaseId)
			return Shop.ProcessReceipt({ PlayerId = ids[p], ProductId = productId, PurchaseId = purchaseId })
		end
		local function idle()
			S.SetClock(function()
				return T0
			end)
			S.Reset(T0)
			prompts = {}
			failSave, holdSave = false, false
		end

		Shop.SetPlayers({
			GetPlayerByUserId = function(_, id)
				return online[id]
			end,
		})
		Shop.SetSave(function(p)
			saves += 1
			while holdSave do
				task.wait()
			end
			if failSave then
				return false
			end
			lastSaved[p] = credit(p)
			return data.Save(p, ids[p], false)
		end)
		Shop.SetPrompt(function(p, productId)
			table.insert(prompts, { p, productId })
		end)
		Shop.SetPolicy(function(p)
			if policyBroken then
				error("policy down")
			end
			return { ArePaidRandomItemsRestricted = restricted[p] == true }
		end)

		section("remotes", function()
			local remotes = ReplicatedStorage:WaitForChild("Remotes")
			for _, name in { "BossBuy", "GemPackBuy", "BossUseCredit" } do
				local remote = remotes:FindFirstChild(name)
				flag("remote_" .. name, remote ~= nil and remote:IsA("RemoteFunction"))
			end
		end)

		-- ProductId 0: nothing is on sale, and a forged receipt pays nothing. The ids are put to 0 here only: the fake ids follow, the end of this test restores the real ones.
		section("product_id_zero", function()
			idle()
			spawnProduct.ProductId = 0
			for _, pack in Monetization.GemPacks do
				pack.ProductId = 0
			end
			local p = buyer()
			local bought, message = Shop.PromptBoss(p)
			eq("zero_boss_refused", bought, false)
			eq("zero_boss_message", message, "Coming soon")
			local pack = Monetization.GemPacks[1]
			local gemsBought, gemsMessage = Shop.PromptGems(p, pack.Id)
			eq("zero_gems_refused", gemsBought, false)
			eq("zero_gems_message", gemsMessage, "Coming soon")
			eq("zero_no_prompt", #prompts, 0)
			eq("zero_receipt_retries", receipt(p, 0, purchase()), RETRY)
			eq("zero_receipt_no_credit", credit(p), 0)
			eq("zero_receipt_no_gems", gems(p), 0)
			eq("zero_no_event", active(), false)
		end)

		spawnProduct.ProductId = BOSS_PRODUCT
		for i, pack in Monetization.GemPacks do
			pack.ProductId = PACK_PRODUCT_BASE + i
		end

		section("prompt_gates", function()
			idle()
			local armed, bare = buyer(), buyer(false)
			eq("prompt_able", (Shop.PromptBoss(armed)), true)
			eq("prompt_able_fires", #prompts, 1)
			eq("prompt_able_product", prompts[1] and prompts[1][2], BOSS_PRODUCT)
			prompts = {}
			local noSidekick, noSidekickMessage = Shop.PromptBoss(bare)
			eq("prompt_no_sidekick_refused", noSidekick, false)
			flag("prompt_no_sidekick_message", type(noSidekickMessage) == "string" and noSidekickMessage ~= "")
			eq("prompt_no_sidekick_silent", #prompts, 0)
			S.Start("timer")
			local during, duringMessage = Shop.PromptBoss(armed)
			eq("prompt_during_event_refused", during, false)
			flag("prompt_during_event_message", type(duringMessage) == "string" and duringMessage ~= "")
			eq("prompt_during_event_silent", #prompts, 0)
			S.End("test")
			eq("prompt_gems_junk_refused", (Shop.PromptGems(armed, "no_such_pack")), false)
			eq("prompt_gems_table_refused", (Shop.PromptGems(armed, {})), false)
			eq("prompt_gems_junk_silent", #prompts, 0)
			eq("prompt_gems_able", (Shop.PromptGems(bare, Monetization.GemPacks[1].Id)), true)
			eq("prompt_gems_able_product", prompts[1] and prompts[1][2], PACK_PRODUCT_BASE + 1)
		end)

		section("receipt_starts_when_idle", function()
			idle()
			local p = buyer()
			local id = purchase()
			eq("idle_granted", receipt(p, BOSS_PRODUCT, id), GRANTED)
			eq("idle_started", active(), true)
			eq("idle_credit_used", credit(p), 0)
			eq("idle_used_credit_is_saved", lastSaved[p], 0)
			-- The retry of a used credit can not start a second event, nor credit again.
			S.End("test")
			eq("idle_retry_granted", receipt(p, BOSS_PRODUCT, id), GRANTED)
			eq("idle_retry_no_event", active(), false)
			eq("idle_retry_no_credit", credit(p), 0)
		end)

		section("receipt_during_event_keeps_credit", function()
			idle()
			local p = buyer()
			S.Start("timer")
			local start = ReplicatedStorage:GetAttribute("BossEventStart")
			local id = purchase()
			eq("active_granted", receipt(p, BOSS_PRODUCT, id), GRANTED)
			eq("active_credit", credit(p), 1)
			eq("active_credit_saved_first", lastSaved[p], 1)
			eq("active_same_event", ReplicatedStorage:GetAttribute("BossEventStart"), start)
			eq("active_retry_granted", receipt(p, BOSS_PRODUCT, id), GRANTED)
			eq("active_retry_no_double", credit(p), 1)
			eq("active_use_refused", (Shop.UseBossCredit(p)), false)
			eq("active_use_keeps_credit", credit(p), 1)
			S.End("test")
			eq("after_use_ok", (Shop.UseBossCredit(p)), true)
			eq("after_use_started", active(), true)
			eq("after_use_exactly_one", credit(p), 0)
			eq("after_use_saved", lastSaved[p], 0)
			S.End("test")
			eq("use_empty_refused", (Shop.UseBossCredit(p)), false)
			eq("use_empty_no_event", active(), false)
		end)

		section("use_takes_exactly_one", function()
			idle()
			local p = buyer()
			S.Start("timer")
			receipt(p, BOSS_PRODUCT, purchase())
			receipt(p, BOSS_PRODUCT, purchase())
			eq("two_credits", credit(p), 2)
			S.End("test")
			eq("two_first_use", (Shop.UseBossCredit(p)), true)
			eq("two_second_use_refused_active", (Shop.UseBossCredit(p)), false)
			eq("two_one_left", credit(p), 1)
		end)

		section("two_buyers", function()
			idle()
			local a, b = buyer(), buyer()
			local idA, idB = purchase(), purchase()
			eq("buyers_a_granted", receipt(a, BOSS_PRODUCT, idA), GRANTED)
			eq("buyers_b_granted", receipt(b, BOSS_PRODUCT, idB), GRANTED)
			eq("buyers_a_used", credit(a), 0)
			eq("buyers_b_keeps", credit(b), 1)
			eq("buyers_b_ready_saved", lastSaved[b], 1)
			S.End("test")
			eq("buyers_a_has_nothing", (Shop.UseBossCredit(a)), false)
			eq("buyers_b_starts", (Shop.UseBossCredit(b)), true)
			eq("buyers_b_used", credit(b), 0)
		end)

		section("save_failure", function()
			idle()
			local p = buyer()
			local id = purchase()
			failSave = true
			eq("fail_retry", receipt(p, BOSS_PRODUCT, id), RETRY)
			eq("fail_no_credit", credit(p), 0)
			eq("fail_no_event", active(), false)
			flag("fail_receipt_dropped", table.find(Shop.Snapshot(p).Receipts, id) == nil)
			failSave = false
			eq("fail_later_granted", receipt(p, BOSS_PRODUCT, id), GRANTED)
			eq("fail_later_started", active(), true)
			eq("fail_later_credit", credit(p), 0)
			-- The event is running; only the save of the use failed. The player paid and got it: the receipt stands.
			idle()
			local q = buyer()
			local before = saves
			Shop.SetSave(function(player)
				saves += 1
				if saves == before + 2 then
					return false
				end
				lastSaved[player] = credit(player)
				return data.Save(player, ids[player], false)
			end)
			eq("use_save_fails_granted", receipt(q, BOSS_PRODUCT, purchase()), GRANTED)
			eq("use_save_fails_started", active(), true)
			eq("use_save_fails_credit", credit(q), 0)
			Shop.SetSave(function(player)
				saves += 1
				while holdSave do
					task.wait()
				end
				if failSave then
					return false
				end
				lastSaved[player] = credit(player)
				return data.Save(player, ids[player], false)
			end)
		end)

		section("retry_in_flight", function()
			idle()
			local p = buyer()
			local id = purchase()
			holdSave = true
			local first
			task.spawn(function()
				first = receipt(p, BOSS_PRODUCT, id)
			end)
			eq("flight_second_retries", receipt(p, BOSS_PRODUCT, id), RETRY)
			holdSave = false
			local deadline = os.clock() + 3
			while first == nil and os.clock() < deadline do
				task.wait()
			end
			eq("flight_first_granted", first, GRANTED)
			eq("flight_credit_once", credit(p), 0)
			flag("flight_one_event", active())
		end)

		section("offline_credit_rejoin", function()
			idle()
			local p = buyer()
			local id = ids[p]
			S.Start("timer")
			local purchaseId = purchase()
			eq("rejoin_granted", receipt(p, BOSS_PRODUCT, purchaseId), GRANTED)
			eq("rejoin_record_credit", store.data[data.KeyFor(id)].BossCredit, 1)
			eq("rejoin_record_version", store.data[data.KeyFor(id)].Version, 18)
			data.Save(p, id, true)
			S.End("test")
			online[id] = nil
			local back = join(id)
			eq("rejoin_credit_kept", credit(back), 1)
			eq("rejoin_retry_granted", receipt(back, BOSS_PRODUCT, purchaseId), GRANTED)
			eq("rejoin_retry_no_double", credit(back), 1)
			eq("rejoin_use", (Shop.UseBossCredit(back)), true)
			eq("rejoin_used", credit(back), 0)
			S.End("test")
			data.Save(back, id, true)
			online[id] = nil
			eq("rejoin_again_empty", credit(join(id)), 0)
		end)

		section("old_and_junk_saves", function()
			nextId += 1
			eq("old_v17_zero", credit(join(nextId, { Version = 17, Money = 5 })), 0)
			for name, junk in { negative = -1, text = "3", nan = 0 / 0, fraction = 1.5, table = {} } do
				nextId += 1
				local value = credit(join(nextId, { Version = 18, BossCredit = junk }))
				flag("junk_" .. name, value == math.floor(value) and value >= 0 and value <= 1, value, "0 or 1")
			end
			nextId += 1
			Admin.AllowStudio = true
			local p = join(nextId, { Version = 18, BossCredit = 3 })
			eq("whole_kept", credit(p), 3)
			flag("wipe_ok", Admin.Run(p, "/wipe") == true)
			eq("wipe_resets", credit(p), 0)
		end)

		section("gem_packs", function()
			idle()
			local recorded
			local realAdd = money.AddGems
			local adds = 0
			for i, pack in Monetization.GemPacks do
				local p = buyer()
				local id = purchase()
				local productId = PACK_PRODUCT_BASE + i
				money.AddGems = function(player, amount)
					adds += 1
					recorded = table.find(Shop.Snapshot(player).Receipts, id) ~= nil
					return realAdd(player, amount)
				end
				eq("pack_granted_" .. pack.Id, receipt(p, productId, id), GRANTED)
				flag("pack_recorded_before_gems_" .. pack.Id, recorded == true)
				eq("pack_exact_" .. pack.Id, gems(p), pack.Gems)
				eq("pack_retry_" .. pack.Id, receipt(p, productId, id), GRANTED)
				eq("pack_retry_once_" .. pack.Id, gems(p), pack.Gems)
				eq("pack_no_credit_" .. pack.Id, credit(p), 0)
			end
			eq("pack_one_add_each", adds, #Monetization.GemPacks)
			money.AddGems = realAdd

			local p = buyer()
			local id = purchase()
			local pack = Monetization.GemPacks[1]
			failSave = true
			eq("pack_fail_retry", receipt(p, PACK_PRODUCT_BASE + 1, id), RETRY)
			eq("pack_fail_no_gems", gems(p), 0)
			flag("pack_fail_receipt_dropped", table.find(Shop.Snapshot(p).Receipts, id) == nil)
			failSave = false
			eq("pack_fail_later", receipt(p, PACK_PRODUCT_BASE + 1, id), GRANTED)
			eq("pack_fail_later_once", gems(p), pack.Gems)
			data.Save(p, ids[p], true)
			eq("pack_saved_gems", store.data[data.KeyFor(ids[p])].Gems, pack.Gems)
			local other = buyer()
			online[ids[other]] = nil
			eq("pack_absent_player_retries", receipt(other, PACK_PRODUCT_BASE + 1, purchase()), RETRY)
			online[ids[other]] = other
			eq("pack_absent_no_gems", gems(other), 0)
			local unloaded = buyer()
			unloaded:SetAttribute("DataLoaded", false)
			eq("pack_unloaded_retries", receipt(unloaded, PACK_PRODUCT_BASE + 1, purchase()), RETRY)
			eq("pack_unloaded_no_gems", gems(unloaded), 0)
		end)

		section("restricted", function()
			idle()
			local p = buyer()
			restricted[p] = true
			local boss, bossMessage = Shop.PromptBoss(p)
			eq("restricted_boss_refused", boss, false)
			flag("restricted_boss_error", type(bossMessage) == "string" and bossMessage ~= "")
			local pack, packMessage = Shop.PromptGems(p, Monetization.GemPacks[1].Id)
			eq("restricted_gems_refused", pack, false)
			flag("restricted_gems_error", type(packMessage) == "string" and packMessage ~= "")
			eq("restricted_no_prompt", #prompts, 0)
			eq("restricted_attribute", p:GetAttribute("PaidRandomRestricted"), true)
			-- Tracks and tasks stay: the free path pays through the same balance.
			money.AddGems(p, 25)
			eq("restricted_still_earns", gems(p), 25)
			-- A receipt already paid (policy changed, or bought elsewhere) is never lost.
			eq("restricted_paid_receipt_honoured", receipt(p, PACK_PRODUCT_BASE + 1, purchase()), GRANTED)
			eq("restricted_paid_receipt_gems", gems(p), 25 + Monetization.GemPacks[1].Gems)
			policyBroken = true
			local q = buyer()
			eq("policy_error_fails_closed", (Shop.PromptBoss(q)), false)
			eq("policy_error_no_prompt", #prompts, 0)
			policyBroken = false
		end)
	end, debug.traceback)
	flag("completed", ok, ok and 1 or tostring(err))

	for i, pack in Monetization.GemPacks do
		pack.ProductId = packIds[i]
	end
	Monetization.BossSpawn.ProductId = bossId
	Admin.AllowStudio = oldStudio
	for _, restore in { "SetPlayers", "SetSave", "SetPrompt", "SetPolicy" } do
		if Shop[restore] then
			Shop[restore](nil)
		end
	end
	S.SetClock(nil)
	S.Reset(workspace:GetServerTimeNow())
	for _, item in cleanup do
		item:Destroy()
	end
	return r
end

return Tests
