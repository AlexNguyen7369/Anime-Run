--!nonstrict
-- BRIEF: design doc 4.35, docs/SIDEKICK_SPEC.md "Gems" (owner 2026-11-04): only track wins and daily / weekly tasks pay
-- here (gem packs and selling come later). Amounts are placeholders, so they are always read from Shared/GemConfig:
-- TrackWin(n), FirstClear(n), Daily, Weekly. The balance is the player attribute Gems, saved as the record's Gems field
-- (PlayerData VERSION 14). Runs on Folder players and an isolated PlayerData clone, like RaceProgressTests.
-- On demand: ReplicatedStorage attributes CarTestOnly = "gems", then CarTestRun = true.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local H = require(script.Parent.AcceptanceSupport)
local Shared = game:GetService("ReplicatedStorage").Shared
local Server = script.Parent.Parent
local Tests = {}
local UID = 990135000

local function gems(p)
	return tonumber(p:GetAttribute("Gems")) or 0
end

function Tests.gems()
	local r, flag = H.report("gems")
	local Quest, Admin = require(Server.QuestService), require(Server.AdminService)
	local oldCooldown, oldStudio = Quest.REMOTE_COOLDOWN, Admin.AllowStudio
	local cleanup, runs = {}, {}
	local ok, err = xpcall(function()
		local GemConfig = require(Shared.GemConfig)
		local QuestConfig = require(Shared.QuestConfig)
		local RaceService, gacha = require(Server.RaceService), require(Server.GachaService)
		local rebirth, money = require(Server.RebirthService), require(Server.MoneyService)
		local factory, catalog = require(Shared.RunnerFactory), require(Shared.CharacterCatalog)
		local npc, npcConfig = require(Shared.NpcRacer), require(Shared.NpcConfig)
		Quest.REMOTE_COOLDOWN = 0
		Admin.AllowStudio = true

		-- With a zero amount every "pays 0" and "pays n only" check below would prove nothing.
		flag(
			"config_amounts_positive",
			GemConfig.TrackWin(1) > 0 and GemConfig.FirstClear(1) > 0 and GemConfig.Daily > 0 and GemConfig.Weekly > 0
		)

		-- Clone only PlayerData so SetStore never redirects the live player's autosaves.
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestGemData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local store = H.store()
		data.SetStore(store)

		local nextId = UID
		local function newPlayer()
			nextId += 1
			local p = H.player(cleanup, nextId)
			data.Setup(p)
			gacha.Setup(p)
			return p
		end
		local function loaded(saved)
			nextId += 1
			store.data[data.KeyFor(nextId)] = saved
			local p = H.player(cleanup, nextId)
			return p, nextId, data.Load(p, nextId)
		end

		-- A synthetic route of 4 tracks; only 1 to 3 are raced, so a win never takes the last-track path.
		local points = {}
		for i = 0, 8 do
			table.insert(points, Vector3.new(0, 2000, -i * 20))
		end
		local route = {
			Path = { WorldWaypoints = points, Curvature = table.create(9, 0), Width = 40, Closed = false },
			Pads = {},
			Tracks = {},
		}
		for number = 1, 4 do
			local start = (number - 1) * 2 + 1
			local path = {
				Waypoints = { points[start], points[start + 1], points[start + 2] },
				Curvature = { 0, 0, 0 },
				Length = 40,
			}
			table.insert(route.Tracks, {
				Number = number,
				StartIndex = start,
				FinishIndex = start + 2,
				Npc = { Config = npcConfig.For(number), Path = path, Profile = npc.Profile(path, 1) },
			})
		end

		local function startRun(p, options, onRoute)
			local car = factory.build(catalog.All()[1].Id)
			car.Name, car.Parent = "CarTestGemRunner", p
			local run
			options.OnRaceEvent = function(event)
				if event.Type == "Result" and run then -- no second frame: the next track must not start racing
					run.Connection:Disconnect()
					if run.RailConnection then
						run.RailConnection:Disconnect()
					end
				end
			end
			run = RaceService.NewRun(car, onRoute or route, p, options)
			table.insert(runs, run)
			return run
		end
		local function reach(run, index)
			run.Driver.Index = index
			RunService.PreSimulation:Wait()
			RunService.PostSimulation:Wait()
		end
		-- Races track `number` against an NPC of the given speed. Returns the Gems it paid and the Result.
		local function raceTrack(p, number, npcSpeed)
			local before = gems(p)
			local run = startRun(p, { Npc = true, StartTrack = number, NpcSpeeds = { [number] = npcSpeed } })
			reach(run, route.Tracks[number].FinishIndex)
			local result = run.Results[1]
			run:Destroy()
			return gems(p) - before, result and result.Result
		end
		local SLOW, FAST = 0.001, 1e12

		-- Track wins: n Gems, plus 10 x n when the win raises BestTrack (design doc 4.35, spec "Gems").
		local winner = newPlayer()
		local paid, outcome = raceTrack(winner, 1, SLOW)
		local want = GemConfig.TrackWin(1) + GemConfig.FirstClear(1)
		flag("win_first_clear_pays_both", outcome == "Win" and paid == want, paid, want)
		flag("win_raises_best_track", winner:GetAttribute("BestTrack") == 1)
		paid, outcome = raceTrack(winner, 1, SLOW)
		flag(
			"win_repeat_pays_track_only",
			outcome == "Win" and paid == GemConfig.TrackWin(1),
			paid,
			GemConfig.TrackWin(1)
		)
		paid, outcome = raceTrack(winner, 2, SLOW)
		want = GemConfig.TrackWin(2) + GemConfig.FirstClear(2)
		flag("win_next_track_first_clear", outcome == "Win" and paid == want, paid, want)

		local jumper = newPlayer()
		paid, outcome = raceTrack(jumper, 3, SLOW)
		want = GemConfig.TrackWin(3) + GemConfig.FirstClear(3)
		flag("win_scales_with_track", outcome == "Win" and paid == want, paid, want)
		paid, outcome = raceTrack(jumper, 2, SLOW) -- never won Track 2, but BestTrack 3 already passed it
		flag(
			"win_below_best_track_only",
			outcome == "Win" and paid == GemConfig.TrackWin(2),
			paid,
			GemConfig.TrackWin(2)
		)

		-- A losing finish pays nothing, not even on a track that would be a first clear.
		local loser = newPlayer()
		paid, outcome = raceTrack(loser, 1, FAST)
		flag("loss_pays_zero", outcome == "Lose" and paid == 0, paid, 0)
		flag("loss_keeps_first_clear", (loser:GetAttribute("BestTrack") or 0) == 0)

		-- A duel finish pays nothing (it has no NPC to beat).
		local duelist, finishes = newPlayer(), 0
		local duelRun = startRun(duelist, {
			Duel = {
				Track = 1,
				OnFinish = function()
					finishes += 1
				end,
			},
		})
		reach(duelRun, route.Tracks[1].FinishIndex)
		flag("duel_finish_pays_zero", finishes == 1 and gems(duelist) == 0, gems(duelist), 0)
		duelRun:Destroy()

		-- A run with no NPC collects its pad through payPads, which shares rewardTrackWin with a win but beats nobody.
		local pad = Instance.new("Part")
		pad:SetAttribute("Cash", 10)
		CollectionService:AddTag(pad, "WinPad")
		table.insert(cleanup, pad)
		local padRoute = table.clone(route)
		padRoute.Pads = { { Pad = pad, Index = 3, Number = 1 } }
		local walker = newPlayer()
		local padRun = startRun(walker, { Npc = false }, padRoute)
		reach(padRun, 3)
		flag("pad_payout_pays_zero", padRun.Payouts == 1 and gems(walker) == 0, gems(walker), 0)
		padRun:Destroy()

		-- Exhaustion pays nothing (it pays a share of Money only).
		local tired, exhausted = newPlayer(), false
		startRun(tired, {
			Npc = true,
			NpcSpeeds = { [1] = SLOW },
			StaminaSeconds = { 0.1, 0.1, 0.1 },
			OnRunEvent = function(event)
				exhausted = exhausted or event.Kind == "Exhausted"
			end,
		})
		local deadline = os.clock() + 5
		while not exhausted and os.clock() < deadline do
			RunService.Heartbeat:Wait()
		end
		flag("exhaustion_pays_zero", exhausted and gems(tired) == 0, gems(tired), 0)

		-- Tasks: every row pays by its kind, once, as a field on the QuestConfig row (spec "Gems").
		local tasker = newPlayer()
		for _, kind in { { false, QuestConfig.Daily, GemConfig.Daily }, { true, QuestConfig.Weekly, GemConfig.Weekly } } do
			local weekly, rows, amount = kind[1], kind[2], kind[3]
			for _, quest in rows do
				local fresh = newPlayer()
				local claimed = Quest.Claim(fresh, weekly, quest.Id)
				flag("task_incomplete_pays_zero_" .. quest.Id, claimed == false and gems(fresh) == 0)
				flag("task_row_field_" .. quest.Id, quest.Gems == amount, quest.Gems, amount)
				Quest.Progress(tasker, quest.Metric, quest.Target)
				local before = gems(tasker)
				claimed = Quest.Claim(tasker, weekly, quest.Id)
				flag("task_claim_pays_" .. quest.Id, claimed == true and gems(tasker) - before == amount)
				before = gems(tasker)
				claimed = Quest.Claim(tasker, weekly, quest.Id)
				flag("task_claim_once_" .. quest.Id, claimed == false and gems(tasker) == before)
			end
		end

		-- /gems sets the balance; /wipe resets it (both reached through the real command path).
		local admin = newPlayer()
		flag("admin_gems_sets", Admin.Run(admin, "/gems 500") == true and admin:GetAttribute("Gems") == 500)
		flag("admin_gems_rejects_negative", Admin.Run(admin, "/gems -5") == false and gems(admin) == 500)
		flag("admin_gems_rejects_word", Admin.Run(admin, "/gems lots") == false and gems(admin) == 500)
		local _, help = Admin.Run(admin, "/help") -- ORDER is also what registers the chat command in AdminService.Start
		flag("admin_gems_listed", string.find(help, "/gems", 1, true) ~= nil)
		flag("admin_wipe_resets", Admin.Run(admin, "/wipe") == true and admin:GetAttribute("Gems") == 0)

		-- Save: missing or junk fields load as 0; the balance survives a round trip and a rebirth.
		local missing, _, missingOk = loaded({ Version = 13, Money = 5 })
		flag("load_missing_field_zero", missingOk == true and missing:GetAttribute("Gems") == 0)
		local new, _, newOk = loaded(nil)
		flag("load_new_save_zero", newOk == true and new:GetAttribute("Gems") == 0)
		for name, junk in { word = "lots", negative = -5, nan = 0 / 0 } do
			local bad, _, badOk = loaded({ Version = 14, Gems = junk })
			flag("load_junk_zero_" .. name, badOk == true and bad:GetAttribute("Gems") == 0)
		end

		local saver, saverId = loaded({ Version = 14, Gems = 123 })
		flag("load_reads_field", saver:GetAttribute("Gems") == 123)
		saver:SetAttribute("Gems", 456)
		local key = data.KeyFor(saverId)
		flag("save_ok", data.Save(saver, saverId, true) == true)
		flag(
			"save_writes_field",
			store.data[key].Gems == 456 and store.data[key].Version == 18,
			store.data[key].Gems,
			456
		)
		local again, _, againOk = loaded(H.copy(store.data[key]))
		flag("round_trip_keeps", againOk == true and again:GetAttribute("Gems") == 456)

		local reborn, rebornId = loaded({ Version = 14, Gems = 77 })
		money.Setup(reborn).Value = rebirth.Requirements(reborn).Money
		flag("rebirth_succeeds", rebirth.Rebirth(reborn) == true and reborn:GetAttribute("RebirthLevel") == 1)
		flag("rebirth_keeps_gems", reborn:GetAttribute("Gems") == 77, gems(reborn), 77)
		data.Save(reborn, rebornId, true)
		flag("rebirth_saves_gems", store.data[data.KeyFor(rebornId)].Gems == 77)
	end, debug.traceback)
	flag("gems_completed", ok, ok and 1 or tostring(err))
	Quest.REMOTE_COOLDOWN, Admin.AllowStudio = oldCooldown, oldStudio
	for _, run in runs do
		pcall(run.Destroy, run)
	end
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end
return Tests
