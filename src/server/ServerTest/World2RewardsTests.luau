--!nonstrict
-- BRIEF: design doc 4.47 "World 2 rewards" (owner 2026-11-24), docs/WORLD2_SPEC.md "Rewards": World 2 Track N's pad pays
-- World 1 Track 10's Cash x 2^N (x2 a placeholder); World 1's pay is unchanged; first-clear Gems pay once per track in
-- each world (BestTrack is per world) and one world's clear never touches the other's; nothing pays while Travelling.
-- Golden numbers are literals from the spec, never computed from the implementation.
-- Runs in either place and checks that place's rule. Offline: lune run tools/lune/server_scenarios <1|2> World2RewardsTests.world2_rewards
-- On demand in Studio: ReplicatedStorage attributes ServerTestOnly = "world2_rewards", then ServerTestRun = true.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local H = require(script.Parent.AcceptanceSupport)
local Shared = game:GetService("ReplicatedStorage").Shared
local Server = script.Parent.Parent
local Tests = {}

local UID = 990249000

-- World 1 pad Cash at HEAD 2895923 (PayoutCurve.Cash), and World 2's from the spec table.
local W1_CASH = { 100, 1000, 7500, 75000, 562500, 5625000, 42187500, 421875000, 3164062500, 31640625000 }
local W2_CASH = {
	63281250000,
	126562500000,
	253125000000,
	506250000000,
	1012500000000,
	2025000000000,
	4050000000000,
	8100000000000,
	16200000000000,
	32400000000000,
}

local function gems(p)
	return tonumber(p:GetAttribute("Gems")) or 0
end

function Tests.world2_rewards()
	local r, flag = H.report("world2_rewards")
	local WORLD = require(Shared.WorldConfig).Id
	local OTHER = WORLD == 2 and 1 or 2
	local cleanup, runs = {}, {}
	local function section(name, fn)
		local ok, err = xpcall(fn, debug.traceback)
		flag(name .. "_completed", ok, ok and 1 or tostring(err))
	end

	section("cash", function()
		local PayoutCurve, TrackBuilder = require(Shared.PayoutCurve), require(Shared.TrackBuilder)
		local here = WORLD == 2 and W2_CASH or W1_CASH
		local w1Bad, w2Bad, hereBad = 0, 0, 0
		for n = 1, 10 do
			w1Bad += (PayoutCurve.Cash(n) == W1_CASH[n] and TrackBuilder.CashFor(n, 1) == W1_CASH[n]) and 0 or 1
			w2Bad += TrackBuilder.CashFor(n, 2) == W2_CASH[n] and 0 or 1
			hereBad += TrackBuilder.CashFor(n) == here[n] and 0 or 1
		end
		flag("world1_cash_unchanged", w1Bad == 0, w1Bad)
		flag("world2_cash_formula", w2Bad == 0, w2Bad)
		flag("this_world_cash", hereBad == 0, hereBad)
		flag("world2_track1_above_world1_track10", TrackBuilder.CashFor(1, 2) > TrackBuilder.CashFor(10, 1))
		local chainBad = 0
		for _, spec in require(Shared.TrackRegistry).Chain() do
			chainBad += TrackBuilder.CashFor(spec.Number) == here[spec.Number] and 0 or 1
		end
		flag("registry_tracks_pay_this_world", chainBad == 0, chainBad)
		-- review 2026-11-24: the built winnings pad carries this world's Cash
		-- Offline the mock stops Build at the ground tiles, after the pad is made: the pad is caught as it is tagged
		-- (the offline CollectionService is a table; in Studio the hook is refused and Build returns the model).
		local spec = require(Shared.TrackRegistry).Chain()[1]
		local pad
		local realAdd = CollectionService.AddTag
		local hooked = pcall(function()
			CollectionService.AddTag = function(self, instance, tag)
				if tag == "WinPad" then
					pad = pad or instance
				end
				return realAdd(self, instance, tag)
			end
		end)
		local built, model = pcall(TrackBuilder.Build, spec, CFrame.new(0, 5000, 0))
		if hooked then
			CollectionService.AddTag = realAdd
		end
		if built and model then
			table.insert(cleanup, model)
			pad = pad or model:FindFirstChild("WinPad", true)
		end
		local cash = pad and pad:GetAttribute("Cash")
		flag("built_pad_this_world_cash", cash == here[spec.Number], cash, here[spec.Number])
	end)

	section("race", function()
		local GemConfig = require(Shared.GemConfig)
		local TrackBuilder = require(Shared.TrackBuilder)
		local RaceService, gacha, money =
			require(Server.RaceService), require(Server.GachaService), require(Server.MoneyService)
		local factory, catalog = require(Shared.RunnerFactory), require(Shared.CharacterCatalog)
		local npc, npcConfig = require(Shared.NpcRacer), require(Shared.NpcConfig)

		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "ServerTestWorld2RewardsData", Server
		table.insert(cleanup, module)
		local data = require(module)
		local store = H.store()
		data.SetStore(store)

		-- A synthetic route of 3 tracks with this world's pads; only 1 and 2 are raced.
		local points = {}
		for i = 0, 6 do
			table.insert(points, Vector3.new(0, 2000, -i * 20))
		end
		local route = {
			Path = { WorldWaypoints = points, Curvature = table.create(7, 0), Width = 40, Closed = false },
			Pads = {},
			Tracks = {},
		}
		for number = 1, 3 do
			local start = (number - 1) * 2 + 1
			local path = {
				Waypoints = { points[start], points[start + 1], points[start + 2] },
				Curvature = { 0, 0, 0 },
				Length = 40,
			}
			local pad = Instance.new("Part")
			pad:SetAttribute("Cash", TrackBuilder.CashFor(number))
			CollectionService:AddTag(pad, "WinPad")
			table.insert(cleanup, pad)
			table.insert(route.Tracks, {
				Number = number,
				StartIndex = start,
				FinishIndex = start + 2,
				Pad = pad,
				Npc = { Config = npcConfig.For(number), Path = path, Profile = npc.Profile(path, 1) },
			})
		end
		-- One frame. Offline (tools/lune mock signals are tables) nothing fires frames, so the test fires one itself.
		local function step()
			if type(RunService.PreSimulation) == "table" then
				RunService.PreSimulation:Fire(1 / 60) -- RaceService steps on PreSimulation only
			else
				RunService.PreSimulation:Wait()
				RunService.PostSimulation:Wait()
			end
		end
		-- Wins `number` against a crawling NPC. Returns Money and Gems paid and the Result event.
		local function win(p, number)
			local m0, g0 = p.leaderstats.Money.Value, gems(p)
			local runner = factory.build(catalog.All()[1].Id)
			runner.Name, runner.Parent = "ServerTestRewardsRunner", p
			local run
			run = RaceService.NewRun(runner, route, p, {
				Npc = true,
				StartTrack = number,
				NpcSpeeds = { [number] = 0.001 },
				OnRaceEvent = function(event)
					if event.Type == "Result" and run then -- no second frame: the next track must not start racing
						run.Connection:Disconnect()
						if run.RailConnection then
							run.RailConnection:Disconnect()
						end
					end
				end,
			})
			table.insert(runs, run)
			run.Driver.Index = route.Tracks[number].FinishIndex
			step()
			local result = run.Results[1]
			run:Destroy()
			return p.leaderstats.Money.Value - m0, gems(p) - g0, result
		end

		-- The other world has every track cleared; this world has none.
		local otherKey = OTHER == 2 and "W2" or nil
		local saved = { Version = 19, Money = 0, Gems = 0, Worlds = { W2 = { BestTrack = 0 } }, BestTrack = 0 }
		if otherKey then
			saved.Worlds.W2.BestTrack = 10
		else
			saved.BestTrack = 10
		end
		local id = UID + 1
		local key = data.KeyFor(id)
		store.data[key] = H.copy(saved)
		local p = H.player(cleanup, id)
		flag("loads", data.Load(p, id) == true)
		gacha.Setup(p)
		money.Setup(p)
		flag("this_world_starts_uncleared", (p:GetAttribute("BestTrack") or 0) == 0, p:GetAttribute("BestTrack"))

		local paid, gemsPaid, result = win(p, 1)
		local want = math.floor(TrackBuilder.CashFor(1) * gacha.MoneyMulti(p))
		flag("finish_pays_this_world_cash", result and result.Result == "Win" and paid == want, paid, want)
		want = GemConfig.TrackWin(1) + GemConfig.FirstClear(1)
		flag("first_clear_gems_paid", gemsPaid == want, gemsPaid, want)
		paid, gemsPaid = win(p, 1)
		flag("first_clear_gems_once", gemsPaid == GemConfig.TrackWin(1), gemsPaid, GemConfig.TrackWin(1))
		paid, gemsPaid = win(p, 2)
		want = GemConfig.TrackWin(2) + GemConfig.FirstClear(2)
		flag("next_track_first_clear", gemsPaid == want, gemsPaid, want)

		flag("saves", data.Save(p, id) == true)
		local stored = store.data[key]
		local hereBest = WORLD == 2 and stored.Worlds.W2.BestTrack or stored.BestTrack
		local otherBest = otherKey and stored.Worlds.W2.BestTrack or stored.BestTrack
		flag("this_world_best_saved", hereBest == 2, hereBest)
		flag("other_world_best_untouched", otherBest == 10, otherBest)

		-- Travelling (Server/WorldTravel): a win pays neither Money nor Gems.
		local q = H.player(cleanup, UID + 2)
		data.Setup(q)
		gacha.Setup(q)
		money.Setup(q)
		q:SetAttribute("Travelling", true)
		paid, gemsPaid, result = win(q, 1)
		flag(
			"travelling_pays_nothing",
			result and result.Result == "Win" and paid == 0 and gemsPaid == 0,
			paid,
			gemsPaid
		)
		-- review 2026-11-24: nor does it raise BestTrack (its first-clear Gems were not paid)
		flag("travelling_best_track_unchanged", (q:GetAttribute("BestTrack") or 0) == 0, q:GetAttribute("BestTrack"))
	end)

	for _, run in runs do
		pcall(run.Destroy, run)
	end
	for _, instance in cleanup do
		instance:Destroy()
	end
	return r
end

return Tests
