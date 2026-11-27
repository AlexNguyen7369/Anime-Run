--!nonstrict
-- BRIEF: the 2026-11-20 audit fixes (owner approved; commit c80e4de), design doc 4.2 and 4.3, docs/TEAM_AND_STAMINA_SPEC.md.
-- Scenarios `team_fill` and `auto_restart`. Numbers are the docs' values, written here as literals. Never loosen a limit.
-- API the tests read:
--   GachaService.FillTeam(player, id?): a kept roll fills an empty Team slot, never a filled one; while AutoRacing is true
--     the id waits (session only) and joins when AutoRacing turns off. GachaService.Roll calls it for every kept roll.
--   RunnerService.RestartAfterExhausted(player): on foot at once, then Auto starts again after RESTART_DELAY (3 s) unless
--     the state changed first (toggle, respawn, boss event) or the player left. Yields.
-- Fake players are Folders; the avatar is newFakeCharacter (Scenarios.luau, passed in).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Tests = {}

local function waitFor(seconds, done)
	local deadline = os.clock() + seconds
	while not done() and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	return done()
end

function Tests.make(helpers)
	local out = {}

	function out.team_fill()
		local r, flag = H.report("team_fill")
		local gacha = H.module(Server, "GachaService")
		local catalog = H.module(Shared, "CharacterCatalog")
		local money = H.module(Server, "MoneyService")
		local api = gacha ~= nil
			and catalog ~= nil
			and money ~= nil
			and type(gacha.FillTeam) == "function"
			and type(gacha.TeamList) == "function"
		flag("team_fill_api_exists", api == true)
		if not api then
			return r
		end
		local STARTER = catalog.STARTER_ID
		local rollable = catalog.Rollable()
		local rarest = { -- hits the first (rarest) check: never a Common, so never auto sold at N = 1
			NextNumber = function()
				return 0
			end,
		}
		local catchAll = {
			NextNumber = function()
				return 0.999999
			end,
		}
		local cleanup = {}
		local function player(name, saved)
			local p = Instance.new("Folder")
			p.Name = "ServerTestTeamFill_" .. name
			p.Parent = Workspace
			table.insert(cleanup, p)
			money.Setup(p)
			gacha.Setup(p)
			gacha.Apply(p, saved or { Version = 19 }) -- a written save: auto sell off
			return p
		end
		local ok, err = pcall(function()
			-- An empty slot is filled by a kept roll, through the real roll path
			local a = player("Empty")
			flag("fill_fixture_team_starter", a:GetAttribute("Team") == STARTER, a:GetAttribute("Team"), STARTER)
			local okRoll, id = pcall(gacha.Roll, a, rarest)
			local first = okRoll and id or nil
			local want = STARTER .. "," .. tostring(first)
			flag(
				"fill_kept_roll_fills_empty_slot",
				first ~= nil and a:GetAttribute("Team") == want,
				a:GetAttribute("Team"),
				want
			)
			pcall(gacha.Roll, a, rarest) -- a second copy: already in the Team, nothing added
			flag("fill_duplicate_not_added_twice", a:GetAttribute("Team") == want, a:GetAttribute("Team"), want)
			local second = rollable[2].Id ~= first and rollable[2].Id or rollable[3].Id
			gacha.Grant(a, second)
			gacha.FillTeam(a, second)
			local full = want .. "," .. second
			flag("fill_third_slot", a:GetAttribute("Team") == full, a:GetAttribute("Team"), full)
			-- 3 slots in both worlds (design doc 4.47, owner 2026-11-26): the third filled the Team
			local used = { [STARTER] = true, [tostring(first)] = true, [second] = true }
			local function spare()
				for _, spec in rollable do
					if not used[spec.Id] then
						used[spec.Id] = true
						return spec.Id
					end
				end
			end
			flag("fill_every_slot", a:GetAttribute("Team") == full, a:GetAttribute("Team"), full)
			-- A full Team never changes
			local third = spare()
			gacha.Grant(a, third)
			gacha.FillTeam(a, third)
			flag("fill_full_team_kept", a:GetAttribute("Team") == full, a:GetAttribute("Team"), full)
			-- A filled slot is never replaced: slot 1 stays the starter
			flag("fill_slot_1_kept", gacha.TeamList(a)[1] == STARTER, gacha.TeamList(a)[1], STARTER)
			-- An unowned id never joins
			local b = player("Unowned")
			gacha.FillTeam(b, rollable[5].Id)
			flag("fill_unowned_not_added", b:GetAttribute("Team") == STARTER, b:GetAttribute("Team"), STARTER)

			-- A sold roll (brand new save: auto sell on at N = 1) adds no copy, so it fills nothing
			local s = player("Sold", {})
			local okSold, _, _, _, _, sold = pcall(gacha.Roll, s, catchAll)
			flag("fill_sold_roll_sold", okSold and sold ~= nil and sold > 0, sold, "> 0")
			flag("fill_sold_roll_no_slot", s:GetAttribute("Team") == STARTER, s:GetAttribute("Team"), STARTER)

			-- While racing the Team is fixed: the kept roll waits, and joins once AutoRacing turns off
			local c = player("Racing")
			c:SetAttribute("AutoRacing", true)
			local okC, idC = pcall(gacha.Roll, c, rarest)
			RunService.Heartbeat:Wait()
			flag("fill_waits_while_racing", okC and c:GetAttribute("Team") == STARTER, c:GetAttribute("Team"), STARTER)
			c:SetAttribute("AutoRacing", false)
			local wantC = STARTER .. "," .. tostring(okC and idC)
			flag(
				"fill_joins_when_on_foot",
				waitFor(1, function()
					return c:GetAttribute("Team") == wantC
				end),
				c:GetAttribute("Team"),
				wantC
			)
			local d = player("RacingNil")
			d:SetAttribute("AutoRacing", true)
			gacha.Grant(d, rollable[2].Id)
			gacha.FillTeam(d, rollable[2].Id)
			gacha.FillTeam(d) -- nil id: only applies the wait, still racing
			flag("fill_nil_id_still_waits", d:GetAttribute("Team") == STARTER, d:GetAttribute("Team"), STARTER)
			d:SetAttribute("AutoRacing", nil)
			gacha.FillTeam(d)
			local wantD = STARTER .. "," .. rollable[2].Id
			flag("fill_nil_id_applies_wait", d:GetAttribute("Team") == wantD, d:GetAttribute("Team"), wantD)
		end)
		for _, p in cleanup do
			p:Destroy()
		end
		flag("team_fill_no_error", ok, ok and 1 or tostring(err))
		return r
	end

	function out.auto_restart()
		local r, flag = H.report("auto_restart")
		local RunnerService = H.module(Server, "RunnerService")
		local PlayerData = H.module(Server, "PlayerData")
		local Money = H.module(Server, "MoneyService")
		local api = RunnerService ~= nil
			and PlayerData ~= nil
			and Money ~= nil
			and type(RunnerService.RestartAfterExhausted) == "function"
			and type(RunnerService.SetAutoRace) == "function"
		flag("restart_api_exists", api == true)
		if not api then
			return r
		end
		local delay = RunnerService.RESTART_DELAY
		flag("restart_delay_3_s", delay == 3, delay, 3)

		local walkCF = RunnerService.WalkSpawnCFrame()
		local release = helpers.clearSpawnOfRealPlayers(walkCF.Position)
		local player = Instance.new("Folder")
		player.Name = "ServerTestAutoRestart"
		player.Parent = Workspace
		local character = helpers.newFakeCharacter(CFrame.new(walkCF.Position + Vector3.new(0, 3, 0)))
		local function racing()
			return RunnerService.IsAutoRacing(player) == true and player:GetAttribute("AutoRacing") == true
		end
		local function onFoot()
			return RunnerService.IsAutoRacing(player) ~= true and player:GetAttribute("AutoRacing") == false
		end
		local function start()
			RunnerService.SetAutoRace(player, true)
			return waitFor(3, racing)
		end
		local ok, err = pcall(function()
			Money.Setup(player)
			PlayerData.Setup(player)
			RunnerService.OnCharacter(player, character)
			flag("restart_fixture_on_foot", waitFor(2, onFoot))

			-- The restart, at the real 3 s
			flag("restart_fixture_racing", start())
			local t0 = os.clock()
			task.spawn(RunnerService.RestartAfterExhausted, player)
			flag("restart_on_foot_at_once", waitFor(0.5, onFoot))
			task.wait(delay - 0.5)
			flag("restart_waits_the_delay", onFoot())
			local back = waitFor(1.5, racing)
			local took = os.clock() - t0
			flag("restart_after_delay", back and took >= delay - 0.1, took, delay)

			-- The cancels: a short delay keeps them quick (read at call time); 3 s is checked above
			RunnerService.RESTART_DELAY = 0.4
			local function cancelled(name, change, undo)
				if not racing() then
					start()
				end
				task.spawn(RunnerService.RestartAfterExhausted, player)
				waitFor(0.3, onFoot)
				change()
				task.wait(RunnerService.RESTART_DELAY + 0.6)
				flag("restart_cancelled_by_" .. name, not racing(), player:GetAttribute("AutoRacing"), false)
				if undo then
					undo()
				end
			end
			cancelled("toggle", function()
				RunnerService.SetAutoRace(player, true)
				waitFor(1, racing)
				RunnerService.SetAutoRace(player, false)
			end)
			cancelled("respawn", function()
				RunnerService.OnCharacter(player, character)
			end)
			cancelled("boss_event", function()
				player:SetAttribute("BossEvent", true)
			end, function()
				player:SetAttribute("BossEvent", nil)
			end)
			cancelled("leave", function()
				player.Parent = nil
			end, function()
				player.Parent = Workspace
			end)
			-- Nothing changed: the short delay restarts (the cancels above are not just a slow restart)
			start()
			task.spawn(RunnerService.RestartAfterExhausted, player)
			flag("restart_short_delay_restarts", waitFor(0.3, onFoot) and waitFor(1.5, racing))
		end)
		RunnerService.RESTART_DELAY = delay
		flag("auto_restart_no_error", ok, ok and 1 or tostring(err))
		pcall(RunnerService.SetAutoRace, player, false)
		task.wait(0.1)
		character:Destroy()
		player:Destroy()
		release()
		return r
	end

	return out
end

return Tests
