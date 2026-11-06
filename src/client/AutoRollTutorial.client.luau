--!nonstrict
-- New player spotlight tutorial (design doc 4.21): a save with no rolls starts with auto-roll off, and this dims the screen
-- around one control until the player turns it on: the compact roll card, then the roll view's AUTO button. The server
-- decides AutoRoll; this only points at the buttons Client/RollToast already has, and a click in the hole lands on them.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ArrivalState = require(script.Parent:WaitForChild("ArrivalState"))
local TutorialSpotlight = require(script.Parent:WaitForChild("TutorialSpotlight"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

-- All proposed (design doc 4.21)
local REVEAL_SECONDS = 4 -- lets the starter pick's in-world reveal play first
local SHADE_TRANSPARENCY = 0.3
local DONE_SECONDS = 1.4
local CLOSE_SECONDS = 0.25
local CLOSE_TWEEN = TweenInfo.new(CLOSE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local STEPS = {
	Open = { Step = "STEP 1 OF 2", Text = "Tap your roll card" },
	Auto = { Step = "STEP 2 OF 2", Text = "Turn AUTO on to roll for your team" },
	Done = { Step = "NICE!", Text = "AUTO ON! Your team is rolling" },
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local toast = playerGui:WaitForChild("RollToast"):WaitForChild("Toast")
local showcase = playerGui:WaitForChild("RollShowcase")
local autoButton = showcase:WaitForChild("AutoButton")

local spot = TutorialSpotlight.new("AutoRollTutorial", 18) -- above the roll view (14), below the starter popup (19)

local doneUntil = nil -- while set: AUTO is on and the closing animation plays

local startAt = 0
player:GetAttributeChangedSignal("StarterPicked"):Connect(function()
	startAt = os.clock() + REVEAL_SECONDS
end)

ArrivalState.WaitForLoading()

local showing = false
local lastTarget = toast
local stepper

local function hide()
	spot.Reset()
	showing = false
end

stepper = RunService.RenderStepped:Connect(function(dt)
	if doneUntil then
		spot.Aim(lastTarget, dt, { Quiet = true })
		if os.clock() >= doneUntil then
			doneUntil = nil
			hide()
		end
		return
	end
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end
	if (player:GetAttribute("Rolls") or 0) > 0 then
		spot.Root:Destroy() -- rolled: this player never needs it again
		stepper:Disconnect()
		return
	end
	if showing and player:GetAttribute("AutoRoll") == true then
		-- Turned on: the strips let go at once, and the rest plays out over the roll view
		spot.SetStripsVisible(false)
		doneUntil = os.clock() + DONE_SECONDS
		spot.Arrow.Visible = false
		spot.SetStep("Done", STEPS.Done)
		UiFeedback.Play("AutoOn", lastTarget)
		spot.FadeShade(1, DONE_SECONDS)
		task.delay(DONE_SECONDS - CLOSE_SECONDS, function()
			UiMotion.Create(spot.CardScale, CLOSE_TWEEN, { Scale = 0 }):Play()
			UiMotion.Create(spot.RingStroke, CLOSE_TWEEN, { Transparency = 1 }):Play()
		end)
		return
	end
	local waiting = player:GetAttribute("NeedsStarter") == true
		or player:GetAttribute("AutoRoll") ~= false
		or os.clock() < startAt
	-- An open panel hides the roll card, and the card comes back with the panel shut
	local enlarged = showcase.Enabled and autoButton.Visible
	local target = enlarged and autoButton or toast
	if waiting or not target.Visible then
		if showing then
			hide()
		end
		return
	end
	if not showing then
		showing = true
		spot.Root.Enabled = true
		spot.RefreshHead()
		spot.FadeShade(SHADE_TRANSPARENCY, 0.35)
	end
	lastTarget = target
	local name = enlarged and "Auto" or "Open"
	spot.SetStep(name, STEPS[name])
	spot.Aim(target, dt)
end)
