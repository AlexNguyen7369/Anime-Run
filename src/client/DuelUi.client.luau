--!nonstrict
-- Client presentation for the server-authoritative duel flow (docs/DUEL_SPEC.md section 3).
-- This script owns no duel state: it only renders Remotes.Duel messages and sends the two
-- explicitly allowed responses back to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local duelRemote = remotes:WaitForChild("Duel")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local Palette = UiTheme.Palette
local DuelConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DuelConfig"))

local function make(className, name, parent, properties)
	local object = Instance.new(className)
	object.Name = name
	for key, value in properties do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local old = playerGui:FindFirstChild("DuelUi")
if old then
	old:Destroy()
end

local root = make("ScreenGui", "DuelUi", playerGui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 12,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local function panel(name, title, close)
	local frame = make("Frame", name, root, {
		AnchorPoint = Vector2.new(0.5, 0),
		-- Leave a fixed lower band for the responsive Race control. The desktop HUD
		-- scales taller than the compact phone variant, so 146 is the shared safe top.
		Position = UDim2.new(0.5, 0, 0, 146),
		Size = UDim2.fromScale(0.58, 0.43),
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
	})
	-- Navy gradient card with a blue glow edge (Backpack look); opaque so it covers what is behind it.
	UiTheme.Plate(frame, Color3.fromRGB(108, 132, 204))
	frame.BackgroundTransparency = 0
	UiTheme.Corner(frame, "L")
	local heading = make("TextLabel", "Title", frame, { Text = title, BackgroundTransparency = 1 })
	-- Design doc 4.42: the Index frame (chrome, ALL CAPS title, art close if any). There is no Duel HUD icon, so the
	-- frame has no logo. Returns the frame and its units (g).
	local header = make("Frame", "Header", frame, { BackgroundTransparency = 1 })
	return frame, AnimeSkin.IndexFrame(frame, { Header = header, Title = heading, Close = close })
end

local function button(name, parent, text, properties)
	properties = properties or {}
	properties.Text = text
	properties.Font = properties.Font or Enum.Font.GothamBold
	properties.TextSize = properties.TextSize or 15
	properties.TextColor3 = properties.TextColor3 or Color3.new(1, 1, 1)
	properties.BackgroundColor3 = properties.BackgroundColor3 or Palette.SlotHere
	properties.AutoButtonColor = false
	properties.BorderSizePixel = 0
	local object = make("TextButton", name, parent, properties)
	make("UICorner", "Corner", object, { CornerRadius = UDim.new(0, UiTheme.Radius.S) })
	UiTheme.Stroke(object, 1.5)
	return object
end

-- Design doc 4.42, in each frame's units: the pick's opponent line at the content top, the tracks under it three
-- across; the invite's line at the top and its two 44 tall buttons at the content's foot, 12 apart.
local pickClose = button("Close", root, "X")
local pickPanel, pickFrame = panel("PickPanel", "PICK A TRACK", pickClose)
pickClose.Parent = pickPanel
local pickOpponent = make("TextLabel", "Opponent", pickPanel, {
	Text = "vs opponent",
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local pickTracks = make("Frame", "Tracks", pickPanel, { BackgroundTransparency = 1 })
local pickGrid = make("UIGridLayout", "Layout", pickTracks, { SortOrder = Enum.SortOrder.Name })
pickFrame.OnLayout(function(g)
	local c = g.Content
	g.Place(pickOpponent, c.X, c.Y, c.W, 28)
	g.Role(pickOpponent, "Body")
	g.Place(pickTracks, c.X, c.Y + 28 + 12, c.W, c.H - 28 - 12)
	pickGrid.CellSize = UDim2.new(1 / 3, -g.px(8), 0, g.px(44)) -- three across, 12 apart
	pickGrid.CellPadding = g.at(12, 12)
	for _, child in pickTracks:GetChildren() do
		if child:IsA("TextButton") then
			g.Role(child, "Item")
		end
	end
end)

local invitePanel, inviteFrame = panel("InvitePanel", "DUEL REQUEST")
local inviteText = make("TextLabel", "Text", invitePanel, {
	Text = "A racer challenges you.",
	BackgroundTransparency = 1,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})
local inviteAccept = button("Accept", invitePanel, "ACCEPT")
local inviteDecline = button("Decline", invitePanel, "DECLINE")
inviteFrame.OnLayout(function(g)
	local c = g.Content
	g.Place(inviteText, c.X, c.Y, c.W, 56) -- two Body lines
	g.Role(inviteText, "Body")
	local w, y = (c.W - 12) / 2, c.Y + c.H - 44
	g.Place(inviteAccept, c.X, y, w, 44)
	g.Place(inviteDecline, c.X + w + 12, y, w, 44)
	g.Button(inviteAccept, "Go")
	g.Button(inviteDecline, "Danger")
end)

local countdown = make("TextLabel", "Countdown", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(220, 104),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextSize = 64,
	TextColor3 = Palette.Gold,
	BackgroundTransparency = 1,
	Active = false,
	Visible = false,
})
UiTheme.Stroke(countdown, 4)
-- Right edge at 92% - 20 px: left of HudChrome's Shop column (desktop: 98 px from the edge, phone: 65 px) and right of
-- the top-centre compact roll at every tested viewport, from 667 px phones to 1920 px desktops.
local TOAST_HOME = UDim2.new(0.92, -20, 0.22, 48)
local toast = make("TextLabel", "Toast", root, {
	-- Reserve the right notification band below Auto Race: the compact roll owns the top
	-- centre, while Speed owns the lower centre on narrow landscape phones.
	AnchorPoint = Vector2.new(1, 0),
	Position = TOAST_HOME,
	Size = UDim2.fromOffset(200, 62),
	Text = "",
	Font = Enum.Font.GothamBlack,
	TextSize = 25,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = Color3.fromRGB(40, 48, 78),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Active = false,
	Visible = false,
})
-- A mini banner (docs/HUD_LAYOUT_SPEC.md sections 8 and 10): green on a win, red on a loss, navy otherwise; the
-- white-to-grey gradient shades the background colour from top to bottom.
UiTheme.Corner(toast, "M")
UiTheme.Stroke(toast, 2.5)
UiTheme.Gradient(toast, Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185))
local TOAST_COLOR = { ["YOU WIN!"] = Palette.MoneyDeep, ["YOU LOSE"] = Palette.DangerDeep }

PanelSwitch.Register("DuelPick", pickPanel)
PanelSwitch.Register("DuelInvite", invitePanel)

local messageToken = 0
local function closePanels()
	PanelSwitch.Close("DuelPick")
	PanelSwitch.Close("DuelInvite")
end

local function showPanel(name)
	if not (name == "DuelPick" or name == "DuelInvite") then
		return
	end
	closePanels()
	PanelSwitch.Toggle(name)
end

local function clearTracks()
	for _, child in pickTracks:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
end

local function showPick(message)
	clearTracks()
	pickOpponent.Text = "vs " .. tostring(message.Opponent or "opponent")
	for _, trackNumber in message.Tracks or {} do
		if type(trackNumber) == "number" then
			local n = math.floor(trackNumber)
			local trackButton = button("Track" .. n, pickTracks, "TRACK " .. n)
			pickFrame.Button(trackButton, "Go")
			trackButton.Activated:Connect(function()
				duelRemote:FireServer("Pick", n)
				PanelSwitch.Close("DuelPick")
			end)
		end
	end
	toast.Visible = false
	showPanel("DuelPick")
end

local inviteToken = 0
local function showInvite(message)
	inviteText.Text = ("%s challenges you on Track %d"):format(
		tostring(message.Opponent or "opponent"),
		tonumber(message.Track) or 0
	)
	toast.Visible = false
	showPanel("DuelInvite")
	UiFeedback.Play("DuelInvite", invitePanel)
	-- An unanswered invite is a decline after INVITE_TIMEOUT (docs/DUEL_SPEC.md): if the server's Cancelled never
	-- arrives, the modal still closes instead of blocking the HUD.
	inviteToken += 1
	local token = inviteToken
	task.delay(DuelConfig.INVITE_TIMEOUT + 1, function()
		if token == inviteToken then
			PanelSwitch.Close("DuelInvite")
		end
	end)
end

local function showCountdown(message)
	closePanels()
	messageToken += 1
	local token = messageToken
	countdown.Visible = true
	local lastTick = nil
	local function tick(text)
		countdown.Text = text
		if text ~= lastTick then
			lastTick = text
			UiFeedback.Play("DuelTick", countdown)
		end
	end
	task.spawn(function()
		local serverStart = tonumber(message.ServerStart)
		if not serverStart then
			countdown.Visible = false
			return
		end
		while token == messageToken do
			local remaining = serverStart - workspace:GetServerTimeNow()
			if remaining > 0 then
				tick(tostring(math.clamp(math.ceil(remaining), 1, 3)))
			elseif remaining > -1 then
				tick("GO!")
			else
				countdown.Visible = false
				return
			end
			task.wait(0.05)
		end
	end)
end

local resultText = { Win = "YOU WIN!", Lose = "YOU LOSE", Draw = "DRAW" }
local resultCue = { Win = "DuelWin", Lose = "DuelLose", Draw = "ToastHigh" }
local TOAST_SLIDE = 0.25
local cancelText = {
	Declined = "DUEL DECLINED",
	InviteTimeout = "NO ANSWER",
	PickTimeout = "DUEL CANCELLED",
	Left = "OPPONENT LEFT",
	NotOnFoot = "PLAYER IS RACING",
	Busy = "PLAYER IS BUSY",
	Cooldown = "WAIT A MOMENT",
	NotLoaded = "PLAYER NOT READY",
}

local function showToast(text, cue)
	closePanels()
	messageToken += 1
	local token = messageToken
	countdown.Visible = false
	toast.Text = text
	toast.BackgroundColor3 = TOAST_COLOR[text] or Palette.Panel
	toast.Position = TOAST_HOME
	toast.Visible = true
	UiMotion.Fade(toast, true)
	UiMotion.SlideIn(toast, Vector2.new(48, 0), TOAST_SLIDE)
	-- Shake takes the Position it finds for the toast's home, so DuelLose waits for the slide. Slam is scale only.
	if cue == "DuelLose" then
		task.delay(TOAST_SLIDE, function()
			if token == messageToken then
				UiFeedback.Play(cue, toast)
			end
		end)
	else
		UiFeedback.Play(cue, toast)
	end
	task.delay(3, function()
		if token == messageToken then
			UiMotion.Fade(toast, false)
		end
	end)
end

pickClose.Activated:Connect(function()
	PanelSwitch.Close("DuelPick")
end)
inviteAccept.Activated:Connect(function()
	duelRemote:FireServer("Respond", true)
	PanelSwitch.Close("DuelInvite")
end)
inviteDecline.Activated:Connect(function()
	duelRemote:FireServer("Respond", false)
	PanelSwitch.Close("DuelInvite")
end)

PanelSwitch.OnChange(function()
	if PanelSwitch.AnyOpen() then
		toast.Visible = false
	end
end)

-- The server puts the "Duel" prompt on every on-foot character, the player's own included, and nobody duels
-- themselves (DuelService refuses "Self"). The own prompt is switched off here only; the server turns it on again
-- at every Stop Auto, hence the listener.
local function hideOwnPrompt(character)
	local function hide(prompt)
		if prompt.Name == "DuelPrompt" and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = false
			prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
				if prompt.Enabled then
					prompt.Enabled = false
				end
			end)
		end
	end
	character.DescendantAdded:Connect(hide)
	for _, descendant in character:GetDescendants() do
		hide(descendant)
	end
end
player.CharacterAdded:Connect(hideOwnPrompt)
if player.Character then
	hideOwnPrompt(player.Character)
end

UiTheme.Apply(root)

duelRemote.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" then
		return
	end
	if message.Type == "PickTrack" then
		showPick(message)
	elseif message.Type == "Invite" then
		showInvite(message)
	elseif message.Type == "Countdown" then
		showCountdown(message)
	elseif message.Type == "Result" then
		showToast(resultText[message.Result] or "DRAW", resultCue[message.Result] or "ToastHigh")
	elseif message.Type == "Cancelled" then
		showToast(cancelText[message.Reason] or "DUEL CANCELLED", "ToastLow")
	end
end)
