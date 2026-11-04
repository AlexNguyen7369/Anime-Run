--!nonstrict
-- What the first-join flow (design doc 4.24) needs in more than one client script. Display only.
local Players = game:GetService("Players")

local ArrivalState = {}

local GRACE_SECONDS = 3 -- the loading screen opens first thing and stays at least 8 s: not there by now = never
local LIMIT_SECONDS = 100 -- its own safety limit is 90 s
local loadingOver = false

-- True for a player who has not finished a run yet. Survives a rejoin: only runs add to MoneyEarned (MoneyService.Award)
-- and BestTrack; a claimed Daily rules out older saves that predate MoneyEarned. Rolls is not used: rolling comes first.
function ArrivalState.IsNew(player)
	return player:GetAttribute("NeedsStarter") == true
		or (
			player:GetAttribute("DataLoaded") == true
			and (player:GetAttribute("MoneyEarned") or 0) == 0
			and (player:GetAttribute("BestTrack") or 0) == 0
			and (player:GetAttribute("DailyLast") or -1) < 0
		)
end

-- Yields until the ScreenGui LoadingScreen has closed, or it never appeared, or the limit passed.
function ArrivalState.WaitForLoading()
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local started = os.clock()
	while
		not loadingOver
		and os.clock() - started < LIMIT_SECONDS
		and (os.clock() - started < GRACE_SECONDS or gui:FindFirstChild("LoadingScreen"))
	do
		task.wait(0.1)
	end
	loadingOver = true
end

return ArrivalState
