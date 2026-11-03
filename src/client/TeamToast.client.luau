--!nonstrict
-- Team toasts (docs/TEAM_AND_STAMINA_SPEC.md "Swap" / "Run end by exhaustion"), display only: "<Name> TAG IN!" when
-- the next slot takes over and "TEAM EXHAUSTED +$X" with the cashed-out bank, from Remotes.RunEvent.
-- shortcut: plain text toast, no swap VFX; upgrade with the art pass.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(shared.CharacterCatalog)
local HudFormat = require(shared.HudFormat)
local UiTheme = require(shared.UiTheme)
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local gui = Instance.new("ScreenGui")
gui.Name = "TeamToast"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0.5)
local HOME = UDim2.fromScale(0.5, 0.38) -- below the biome and bonus popups (0.22, 0.3)
toast.Position = HOME
toast.Size = UDim2.fromOffset(520, 48)
toast.BackgroundTransparency = 1
toast.Font = UiTheme.Font
toast.TextSize = 34
toast.TextColor3 = Color3.fromRGB(255, 214, 64)
toast.Visible = false
UiTheme.Stroke(toast, 2)
toast.Parent = gui
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local shown = 0
local function show(text, seconds)
	shown += 1
	local mine = shown
	toast.Text = text
	toast.Position = HOME
	-- Design doc 4.20: slides and fades in, holds, fades out.
	UiMotion.Fade(toast, true)
	UiMotion.SlideIn(toast, Vector2.new(0, 12), 0.2)
	task.delay(seconds, function()
		if shown == mine then
			UiMotion.Fade(toast, false)
		end
	end)
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RunEvent").OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then
		return
	end
	if ev.Kind == "Swap" then
		local spec = CharacterCatalog.Get(ev.To)
		show((spec and spec.Name or "Next runner") .. " TAG IN!", 1.5)
	elseif ev.Kind == "Exhausted" then
		show("TEAM EXHAUSTED  +" .. HudFormat.MoneyText(tonumber(ev.Banked) or 0), 3)
	end
end)
