--!nonstrict
-- Sidekick spotlight tutorial (design doc 4.36, 4.21; docs/SIDEKICK_SPEC.md): from rebirth 2 until the one free summon is used.
-- Step 1 points at the card's own GoButton, which opens the galaxy summon screen; step 2 at its free-summon button (Canvas/AutoFuse).
-- The result then plays with the tutorial waiting; after it, step 3 closes the summon screen as its Close does and points at the
-- HUD's Items tile to equip the result in the Bag, as only a worn Sidekick unlocks boss events, then closes by itself.
-- The step comes from attributes, the open panel and the reveal alone, so a rejoin starts at step 1.
-- The server decides the free summon; this only points at the buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("SidekickConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local ArrivalState = require(script.Parent:WaitForChild("ArrivalState"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local TutorialSpotlight = require(script.Parent:WaitForChild("TutorialSpotlight"))

-- All proposed
local SHADE_TRANSPARENCY = 0.3
local STEP3_SECONDS = 6
local GO_ROOM = 48 -- px of the card's foot for GoButton
local STEPS = {
	Go = { Step = "STEP 1 OF 3", Text = "A free Sidekick is waiting for you!" },
	Free = { Step = "STEP 2 OF 3", Text = "Tap FREE SUMMON" },
	Equip = { Step = "STEP 3 OF 3", Text = "Equip it in your Bag to join boss events!" },
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local page = playerGui:WaitForChild("RacerSidekicks")
local main = page:WaitForChild("Canvas")
local free = main:WaitForChild("AutoFuse")

local spot = TutorialSpotlight.new("SidekickTutorial", 18) -- above the summon reveal (15), below the starter popup (19)
spot.Ring.ZIndex = 6 -- step 1's ring sits on the card
spot.Ripple.ZIndex = 6

local goButton = Instance.new("TextButton")
goButton.Name = "GoButton"
goButton.AnchorPoint = Vector2.new(0.5, 1)
goButton.Position = UDim2.new(0.5, 0, 1, -8)
goButton.Size = UDim2.new(0.62, 0, 0, GO_ROOM - 12)
goButton.BackgroundColor3 = UiTheme.Palette.White
goButton.Font = UiTheme.Font
goButton.Text = "Sidekicks"
goButton.TextColor3 = UiTheme.Palette.White
goButton.TextSize = 22
goButton.AutoButtonColor = false
goButton.ZIndex = 6
goButton.Visible = false
goButton.Parent = spot.Card
UiTheme.Corner(goButton, "M")
UiTheme.Gradient(goButton, UiTheme.Palette.Row, UiTheme.Palette.PanelDeep)
UiTheme.Stroke(goButton, 2)
goButton.Activated:Connect(function()
	PanelSwitch.Action("Sidekicks")
end)

ArrivalState.WaitForLoading()

-- A tutorial that takes the clicks must never trap a player who cannot finish it.
local function bagFull()
	return #SidekickView.Bag(player) >= Config.BagSize
end

local function blocked()
	local rollTutorial = playerGui:FindFirstChild("AutoRollTutorial")
	local raceEvent = player:GetAttribute("RaceEvent")
	return player:GetAttribute("DuelActive") == true
		or player:GetAttribute("ShowdownActive") == true
		or player:GetAttribute("BossEvent") == true
		or player:GetAttribute("NeedsStarter") == true
		or (rollTutorial ~= nil and rollTutorial.Enabled)
		-- The transitions: a teleport, and a run starting with the runner not placed yet.
		or raceEvent == "Teleporting"
		or (player:GetAttribute("AutoRacing") == true and raceEvent == "Off")
		or bagFull()
end

local showing = false
local closing = false -- step 3
local screenClosed = false -- step 3 closed the summon screen once
local closeAt = nil

local function hide()
	spot.Reset()
	showing, closing, screenClosed, closeAt = false, false, false, nil
end

-- The result first: the summon request and its reveal (SidekickUi sets Summoning until the reveal's end reopened the screen).
local function resultPlaying()
	return page:GetAttribute("Summoning") == true or playerGui:FindFirstChild("RacerSidekickReveal") ~= nil
end

-- After the result the summon screen closes, as its own Close does, then the Items tile with nothing dimmed or blocked.
-- The card itself when the HUD has no tile.
local function stepThree(dt)
	if resultPlaying() then
		spot.Root.Enabled = false -- waits, taking no click, with no timer running
		return
	end
	if not screenClosed then
		screenClosed = true
		PanelSwitch.Close("Sidekicks")
	end
	if main.Visible then
		spot.Root.Enabled = false -- the screen's close motion, or the player opened it again: the HUD is hidden
		return
	end
	spot.Root.Enabled = true
	closeAt = closeAt or os.clock() + STEP3_SECONDS
	local hud = playerGui:FindFirstChild("HudChrome")
	local slot = hud and hud.Enabled and hud:FindFirstChild("Grid")
	local tile = slot and slot:FindFirstChild("Items")
	local target = tile and tile.Visible and tile or spot.Card
	spot.Arrow.Visible = target == tile
	spot.SetStep("Equip", STEPS.Equip)
	spot.Aim(target, dt, { Quiet = true, FixedCard = target == spot.Card })
	if os.clock() >= closeAt then
		hide()
	end
end

RunService.RenderStepped:Connect(function(dt)
	if player:GetAttribute("DataLoaded") ~= true then
		return
	end
	if closing then
		stepThree(dt)
		return
	end
	local used = player:GetAttribute("SidekickFreeUsed") ~= false
	if showing and used then
		closing = true
		goButton.Visible = false
		spot.SetStripsVisible(false)
		spot.FadeShade(1, 0.25)
		stepThree(dt)
		return
	end
	local open = PanelSwitch.IsOpen("Sidekicks")
	-- The page open with a sheet over FreeSummon, or the reveal playing: nothing to point at.
	local pointless = open and not (free.Visible and main.Visible and page.Enabled and not main.Modal.Visible)
	if used or (player:GetAttribute("RebirthLevel") or 0) < Config.UnlockRebirth or blocked() or pointless then
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
	goButton.Visible = not open
	if open then
		spot.SetStep("Free", STEPS.Free)
		spot.Aim(free, dt)
	else
		spot.SetStep("Go", STEPS.Go)
		spot.Aim(goButton, dt, { FixedCard = true, CardExtra = GO_ROOM })
	end
end)
