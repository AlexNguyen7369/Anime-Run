--!nonstrict
-- Bag full tip (design doc 4.41, owner 2026-11-20): the first BAG FULL of a session points a 4.21 style spotlight at the
-- HUD's Items tile, where spares are sold. Nothing is dimmed or blocked; it closes by itself after SHOW_SECONDS or when the
-- Bag opens. Display only; the server decides the bag.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArrivalState = require(script.Parent:WaitForChild("ArrivalState"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local TutorialSpotlight = require(script.Parent:WaitForChild("TutorialSpotlight"))

local SHOW_SECONDS = 6 -- proposed
local STEP = { Step = "BAG FULL", Text = "Sell spares in your Bag, or turn on Auto Sell in Settings" }

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BagFullHit")

ArrivalState.WaitForLoading()

local spot = TutorialSpotlight.new("BagFullTip", 17) -- under the other tutorials (18) and the starter popup (19)
local done = false
local stepper, hit = nil, nil

local function finish()
	if stepper then
		stepper:Disconnect()
	end
	if hit then
		hit:Disconnect()
	end
	spot.Root:Destroy()
end

local function blocked()
	local tutorial = playerGui:FindFirstChild("AutoRollTutorial")
	return player:GetAttribute("DuelActive") == true
		or player:GetAttribute("ShowdownActive") == true
		or player:GetAttribute("BossEvent") == true
		or (tutorial ~= nil and tutorial.Enabled)
end

local closeAt = nil
hit = remote.OnClientEvent:Connect(function()
	if done or blocked() then
		return
	end
	done = true -- once per session: nothing is saved for it
	closeAt = os.clock() + SHOW_SECONDS
	spot.Root.Enabled = true
	spot.SetStripsVisible(false)
	spot.FadeShade(1, 0)
	spot.RefreshHead()
	spot.SetStep("Bag", STEP)
	stepper = RunService.RenderStepped:Connect(function(dt)
		local hud = playerGui:FindFirstChild("HudChrome")
		local grid = hud and hud.Enabled and hud:FindFirstChild("Grid")
		local tile = grid and grid:FindFirstChild("Items")
		if os.clock() >= closeAt or PanelSwitch.IsOpen("Backpack") or blocked() then
			finish()
			return
		end
		local target = tile and tile.Visible and tile or spot.Card
		spot.Arrow.Visible = target == tile
		spot.Aim(target, dt, { Quiet = true, FixedCard = target == spot.Card })
	end)
end)
