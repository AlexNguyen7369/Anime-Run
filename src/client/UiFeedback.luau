--!nonstrict
-- One table of UI moments: cue name to sound and motion (design doc 4.33, docs/UI_FEEDBACK_SPEC.md section 2; the pairing
-- is the SFX audit in docs/UI_AUDIT.md, every value a placeholder). Display only.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local UiFeedback = {}

local RATE_LIMIT = 0.05

-- Slot, Volume: its Sound (no Slot: silent on purpose). Also: a second slot at the same volume. Pitch: PlaybackSpeed.
-- OptIn: the audit's "only sometimes" sounds; they play only with opts.Sound = true.
-- Motion: UiMotion presets run in order. No Motion: the call site keeps its own (Mark, Fade, SlideIn, a roll's Pop).
UiFeedback.Cues = {
	PanelOpen = { Slot = "Whoosh", Volume = 0.15 },
	PanelClose = {},
	TabSwitch = { Slot = "Tap", Volume = 0.2 },
	ShopBought = { Slot = "Chime", Volume = 0.5, Motion = { "Pop" } },
	MarketBought = { Slot = "Coin", Volume = 0.45, Motion = { "Impact", "Fly" } },
	Equip = { Slot = "Thunk", Volume = 0.3, Motion = { "Pop" } },
	UpgradeBought = { Slot = "Coin", Volume = 0.4, Motion = { "Impact" } },
	Denied = { Slot = "Denied", Volume = 0.35, Motion = { "Shake" } },
	DailyClaim = { Slot = "Chime", Volume = 0.6, Motion = { "Slam", "Burst" } },
	QuestClaim = { Slot = "Chime", Volume = 0.45, Motion = { "Pop", "Shine", "Burst" } },
	Rebirth = { Slot = "Boom", Volume = 0.8, Motion = { "Slam", "Burst", "Shake" } },
	RebirthBar = { Motion = { "Fill" } }, -- the requirement bar following Money; not a moment, so silent
	Toggle = { Slot = "Tap", Volume = 0.2 },
	-- Roll rows: no Burst (ROLL_ANIMATION_SPEC bans speed streaks).
	RollTick = { Slot = "Tap", Volume = 0.05, OptIn = true },
	RollLand1 = {},
	RollLand2 = { Slot = "Tap", Volume = 0.15 },
	RollLand3 = { Slot = "Thunk", Volume = 0.35, Motion = { "Pop" } },
	RollLand4 = { Slot = "Crack", Volume = 0.6, Motion = { "Impact" } },
	RollLand5 = { Slot = "Boom", Volume = 0.7, Motion = { "Shine", "Shake" } },
	RollSecret = { Slot = "Boom", Also = "Chime", Volume = 0.9, Motion = { "Slam", "Shake" } },
	EnemyVs = { Slot = "Slash", Volume = 0.5, Motion = { "Slam" } },
	EnemyDefeated = { Slot = "Crack", Volume = 0.7, Motion = { "Slam", "Burst" } },
	EnemyPass = { Slot = "Tap", Volume = 0.15, OptIn = true, Motion = { "Pop" } },
	LoseRibbon = { Slot = "Thunk", Volume = 0.6, Motion = { "Impact" } },
	LoseRow = { Slot = "Tap", Volume = 0.1, OptIn = true },
	MoneySmall = {},
	MoneyBig = { Slot = "Coin", Volume = 0.4, Motion = { "Fly" } },
	Turbo = { Slot = "Crack", Volume = 0.35, Motion = { "Pop", "Fill", "Shine" } },
	TagIn = { Slot = "Whoosh", Volume = 0.25, Motion = { "Pop" } },
	Exhausted = { Slot = "Thunk", Volume = 0.4, Motion = { "Shake" } },
	BadgeNew = { Slot = "Tap", Volume = 0.1, OptIn = true },
	ToastLow = {},
	ToastMid = { Slot = "Whoosh", Volume = 0.2 },
	ToastHigh = { Slot = "Thunk", Volume = 0.5, Motion = { "Slam" } },
	CheckpointBonus = { Slot = "Chime", Volume = 0.4, Motion = { "Pop", "Fly" } },
	StarterPick = { Slot = "Crack", Volume = 0.6, Motion = { "Slam" } },
	DuelTick = { Slot = "Tap", Volume = 0.3, Motion = { "Pop" } },
	DuelInvite = { Slot = "Chime", Volume = 0.4, Motion = { "Pop" } },
	DuelWin = { Slot = "Boom", Volume = 0.7, Motion = { "Slam", "Burst" } },
	DuelLose = { Slot = "Thunk", Volume = 0.5, Motion = { "Shake" } },
}

local sounds = {} -- cue -> its Sounds, filled when the copied folder has arrived; until then cues only run motion
local lastPlayed = {}
local warned = {}

local function warnOnce(message)
	if not warned[message] then
		warned[message] = true
		warn("[UiFeedback] " .. message)
	end
end

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("ImpactSounds", 30)
	if not folder then
		warnOnce("ReplicatedStorage.ImpactSounds is missing: cues stay silent")
		return
	end
	local UiSounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiSounds"))
	local templates = {}
	for slot in UiSounds.Assets do
		templates[slot] = folder:WaitForChild(slot, 5)
		if not templates[slot] then
			warnOnce("no Sound for slot " .. slot)
		end
	end
	local group = Instance.new("SoundGroup")
	group.Name = "UiSfx"
	group.Parent = SoundService
	local all = {}
	for cue, row in UiFeedback.Cues do
		local list = {}
		for _, slot in { row.Slot, row.Also } do
			if templates[slot] then
				local sound = templates[slot]:Clone()
				sound.Name = #list == 0 and cue or cue .. slot
				-- Before parenting: the SOUND toggle (RacerUiController applySound) zeroes the template too, and on
				-- DescendantAdded while muted it remembers the Volume it reads, then zeroes this one.
				sound.Volume = row.Volume
				sound.SoundGroup = group
				sound.Parent = group
				table.insert(list, sound)
				table.insert(all, sound)
			end
		end
		sounds[cue] = list
	end
	ContentProvider:PreloadAsync(all)
end)

local function playSound(cue, row, opts)
	if row.OptIn and not opts.Sound then
		return
	end
	local now = os.clock()
	if lastPlayed[cue] and now - lastPlayed[cue] < RATE_LIMIT then
		return
	end
	lastPlayed[cue] = now
	for _, sound in sounds[cue] or {} do
		sound.PlaybackSpeed = opts.Pitch or row.Pitch or 1
		-- Restarts a sound still playing, like HudPressSound.
		sound:Stop()
		sound:Play()
	end
end

-- opts (all optional): Origin (gui or Vector2 for Burst and Fly, default gui), Target (Fly's gui; none: no coins), Count,
-- OnLanded (Fly), Color (shards, coins, flash), Pitch, Sound (see OptIn), Bar and Goal (Fill's bar and its goal Size).
-- Never yields. The rate limit covers the sound only: dropping motion would drop a gui's Pop and a Fly's OnLanded.
function UiFeedback.Play(cue, gui, opts)
	local row = UiFeedback.Cues[cue]
	if not row then
		warnOnce("unknown cue " .. tostring(cue))
		return
	end
	opts = opts or {}
	playSound(cue, row, opts)
	for _, preset in row.Motion or {} do
		if preset == "Fly" then
			UiMotion.Fly(opts.Origin or gui, opts.Target, opts.Count or 8, opts.Color, opts.OnLanded)
		elseif preset == "Fill" then
			if opts.Bar and opts.Goal then
				UiMotion.Fill(opts.Bar, opts.Goal)
			end
		elseif preset == "Burst" then
			if opts.Origin or gui then
				UiMotion.Burst(opts.Origin or gui, opts)
			end
		elseif gui then
			if preset == "Impact" then
				UiMotion.Impact(gui, opts)
			else
				UiMotion[preset](gui)
			end
		end
	end
end

-- The HUD's Money number, the far end of a Fly; nil before the HUD exists.
function UiFeedback.MoneyCounter()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("RacerHud")
	local money = hud and hud:FindFirstChild("Money")
	return money and money:FindFirstChild("MoneyValue")
end

-- Denied, sound only, for a press on a disabled button (Active = false fires no Activated, and it does not move, design
-- doc 4.20). A drag (a scroll or a pan starting on the button) is no press. denies(), optional, can rule a press out.
function UiFeedback.DeniedPress(button, denies)
	local down
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			down = input.Position
		end
	end)
	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local pressed = down and (input.Position - down).Magnitude < 12
			down = nil
			if pressed and not button.Active and (not denies or denies()) then
				UiFeedback.Play("Denied")
			end
		end
	end)
end

return UiFeedback
