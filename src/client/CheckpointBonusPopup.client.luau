--!nonstrict
-- Checkpoint bonus popup (design doc 4.15, placeholder art and timing): when a won track paid the checkpoint bonus
-- (NpcRace Result with Bonus > 1), "CHECKPOINT BONUS x1.2 · $X" fades in below the biome welcome popup, holds and
-- fades out. Client-only display; the server decided the amount.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudFormat = require(Shared.HudFormat)
local UiTheme = require(Shared.UiTheme)
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local FADE_IN, HOLD, FADE_OUT = 0.25, 1.5, 0.5 -- placeholder

local root = Instance.new("ScreenGui")
root.Name = "CheckpointBonusPopup"
root.ResetOnSpawn = false
root.DisplayOrder = 2
local group = Instance.new("CanvasGroup") -- one GroupTransparency fades the text and its stroke together
group.Name = "Popup"
group.AnchorPoint = Vector2.new(0.5, 0)
local HOME = UDim2.fromScale(0.5, 0.3) -- below BiomeWelcome (y 0.22)
group.Position = HOME
group.Size = UDim2.fromOffset(640, 44)
group.BackgroundTransparency = 1
group.GroupTransparency = 1
group.Visible = false
group.Parent = root
local label = Instance.new("TextLabel")
label.Name = "Bonus"
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.FontFace = AnimeSkin.Font -- design doc 4.42: heavy italic, dark outline; the text stays gold
label.TextSize = 30
label.TextColor3 = Color3.fromRGB(255, 215, 90)
label.Text = ""
UiTheme.Stroke(label, 2.5, AnimeSkin.Ink)
label.Parent = group
root.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local shown = 0 -- bumps per popup, so an older popup's fade-out never hides a newer one
local function show(text, pays)
	shown += 1
	local mine = shown
	label.Text = text
	group.GroupTransparency = 1
	group.Visible = true
	UiMotion.Create(group, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 0,
	}):Play()
	-- Design doc 4.20: it also slides down into place while it fades in.
	group.Position = HOME - UDim2.fromOffset(0, 12)
	UiMotion.Create(group, TweenInfo.new(FADE_IN, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = HOME,
	}):Play()
	-- The pay goes straight into Money at the finish (owner 2026-11-10: no run bank).
	UiFeedback.Play("CheckpointBonus", group, { Target = pays and UiFeedback.MoneyCounter() or nil })
	task.delay(FADE_IN + HOLD, function()
		if shown ~= mine then
			return
		end
		local out = UiMotion.Create(group, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			GroupTransparency = 1,
		})
		out.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and shown == mine then
				group.Visible = false
			end
		end)
		out:Play()
	end)
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace").OnClientEvent:Connect(function(event)
	if type(event) == "table" and event.Type == "Result" and event.Result == "Win" then
		local bonus = tonumber(event.Bonus) or 1
		if bonus > 1 then
			local banked = tonumber(event.Banked) or 0
			show(
				string.format("CHECKPOINT BONUS %s · %s", HudFormat.Multi(bonus), HudFormat.MoneyText(banked)),
				banked > 0
			)
		end
	end
end)
