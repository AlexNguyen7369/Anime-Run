--!nonstrict
-- HUD entry points (docs/HUD_LAYOUT_SPEC.md, design doc 4.40 "split L/R"): the left and right icon columns, the bottom
-- Auto / Upgrade pair and the top-right Daily pill with the round Settings button. Each entry only opens a panel (the panels' scripts own
-- everything else), but Auto, which asks the server to toggle auto race (docs/ROLL_ANIMATION_SPEC.md "Auto toggle").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local client = script.Parent
local PanelSwitch = require(client:WaitForChild("PanelSwitch"))
local Icons = require(client:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
local UiTheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UiTheme"))
local UiFeedback = require(client:WaitForChild("UiFeedback"))
local UiMotion = require(client:WaitForChild("UiMotion"))
local QuestConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("QuestConfig"))
local HttpService = game:GetService("HttpService")

-- Owner 2026-10-28 (docs/HUD_LAYOUT_SPEC.md section 6): the Roblox chat window starts collapsed so it never covers
-- the left icon tiles; the chat button opens it. The chat CoreScript opens itself after it loads (an early SetCore
-- is undone), so on join keep collapsing it until it has stayed collapsed for 3 s (at most 30 s).
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	local closedFor = 0
	for _ = 1, 30 do
		local ok, active = pcall(StarterGui.GetCore, StarterGui, "ChatActive")
		if ok and active == false then
			closedFor += 1
			if closedFor >= 3 then
				return
			end
		else
			closedFor = 0
			pcall(StarterGui.SetCore, StarterGui, "ChatActive", false)
		end
		task.wait(1)
	end
end)

local RED = UiTheme.Palette.Danger
-- Design doc 4.40: no tile frame, the Tab tilt icon with its label under it. Sizes are proposed.
local ICON = 72 -- px, square
local LABEL = 22 -- px, the label band under the icon
local GAP = 8 -- px between buttons in a column
local CELL = Vector2.new(ICON + 12, ICON + LABEL) -- one button

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function outlined(label, thickness)
	make(
		"UIStroke",
		"Outline",
		label,
		{ Color = UiTheme.Outline, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Round }
	)
	return label
end

local function icon(name, parent, props)
	local art = Icons[name]
	props.Image = art.Image -- 4.40 Tab tilt set for every button, Index included (owner 2026-11-10)
	props.BackgroundTransparency = 1
	props.ScaleType = Enum.ScaleType.Fit
	if art.Offset then
		props.ImageRectOffset, props.ImageRectSize = art.Offset, art.Size
	end
	return make("ImageLabel", "Icon", parent, props)
end

local function badge(parent)
	local b = make("TextLabel", "Badge", parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(12, 8), -- the icon's top-left corner (design doc 4.40)
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = RED,
		Font = UiTheme.Font,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Visible = false,
		ZIndex = 4,
	})
	make("UICorner", "Corner", b, { CornerRadius = UDim.new(1, 0) })
	make(
		"UIStroke",
		"Ring",
		b,
		{ Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
	)
	return b
end

local root = make("ScreenGui", "HudChrome", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 1,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
-- Owner 2026-10-20 (HUD_LAYOUT_SPEC section 6): an open panel dims only the world. The dim layer sits below
-- every HUD ScreenGui (DisplayOrder 0), so the HUD entries stay bright and clickable over it.
local worldDim = make("ScreenGui", "PanelDim", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 0,
	Enabled = false,
})
make("Frame", "Dim", worldDim, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 10, 18),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Active = false,
	Selectable = false,
})

local function setHudDimmed(dimmed)
	worldDim.Enabled = dimmed
end

-- Icon tiles -----------------------------------------------------------------------------------------------------
local PANEL = {
	Quests = "Quests",
	Shop = "Shop",
	Market = "Market",
	Items = "Backpack",
	Index = "Index",
	Upgrade = "Upgrades",
	Rebirth = "Rebirth",
}
local scales = {}
-- A transparent holder with a vertical list of buttons; its UIScale shrinks it on phones (design doc 4.27).
local function holder(name, count, props)
	props.Size = UDim2.fromOffset(CELL.X, count * CELL.Y + (count - 1) * GAP)
	props.BackgroundTransparency = 1
	local frame = make("Frame", name, root, props)
	table.insert(scales, make("UIScale", "Scale", frame, {}))
	make("UIListLayout", "Layout", frame, { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder })
	return frame
end
-- Split L/R: Index, Items, Rebirth on the left edge; Quests, Shop, Market on the right edge, top to bottom.
local grid = holder("Grid", 3, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, -24) })
local shopColumn =
	holder("ShopColumn", 3, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, -24) })
-- Auto and Upgrade flank the LEVEL / TURBO LUCK bars at the bottom centre; placed every refresh.
-- The anchor sits on the icon's centre (not the icon + label), so the icon lines up with the gap.
local ICON_MID = ICON / 2 / CELL.Y
local autoSlot = holder("AutoSlot", 1, { AnchorPoint = Vector2.new(1, ICON_MID) })
local upgradeSlot = holder("UpgradeSlot", 1, { AnchorPoint = Vector2.new(0, ICON_MID) })
local BOTTOM_SCALE = 0.75 -- the bottom pair is smaller than the edge tiles (owner, 2026-10-15)
local STACK_MAX_HEIGHT = 400 -- phone_small: the pair stacks above the bars (owner, 2026-10-28)
local SLOTS = {
	{ "Index", grid },
	{ "Items", grid },
	{ "Rebirth", grid },
	{ "Quests", shopColumn },
	{ "Shop", shopColumn },
	{ "Market", shopColumn },
	{ "Auto", autoSlot },
	{ "Upgrade", upgradeSlot },
}
-- Shop and Index are not S and I: S walks backward and I zooms the camera (owner 2026-11-10).
local KEYS = {
	Index = Enum.KeyCode.X,
	Items = Enum.KeyCode.B,
	Rebirth = Enum.KeyCode.R,
	Quests = Enum.KeyCode.Q,
	Shop = Enum.KeyCode.P,
	Market = Enum.KeyCode.M,
}
local tiles = {}
for order, slot in SLOTS do
	local name = slot[1]
	-- A transparent button: the Tab tilt icon, the label under it (design doc 4.40).
	local tile = make("ImageButton", name, slot[2], {
		LayoutOrder = order,
		Size = UDim2.fromOffset(CELL.X, CELL.Y),
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
	})
	tile:SetAttribute("Panel", PANEL[name])
	icon(name, tile, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(ICON, ICON),
		ZIndex = 2,
	})
	outlined(
		make("TextLabel", "Label", tile, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.new(1, 8, 0, LABEL + 4),
			BackgroundTransparency = 1,
			Font = UiTheme.Font,
			TextSize = 19,
			TextColor3 = Color3.new(1, 1, 1),
			Text = name,
			ZIndex = 3,
		}),
		2.5
	)
	if PANEL[name] then
		tile.Activated:Connect(function()
			PanelSwitch.Action(PANEL[name])
		end)
	end
	if KEYS[name] then
		outlined(
			make("TextLabel", "Key", tile, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -2, 0, 2),
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
				Font = UiTheme.Font,
				TextSize = 16,
				TextColor3 = Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = KEYS[name].Name,
				ZIndex = 3,
			}),
			2
		)
	end
	tiles[name] = { Button = tile, Badge = badge(tile) }
end

-- Keybind letters (design doc 4.40): keyboard only; the key does exactly what a click on the tile does.
local function keyboardInUse()
	local last = UserInputService:GetLastInputType()
	return UserInputService.KeyboardEnabled
		and last ~= Enum.UserInputType.Touch
		and string.sub(last.Name, 1, 7) ~= "Gamepad"
end
local function refreshKeys()
	local shown = keyboardInUse()
	for name in KEYS do
		tiles[name].Button.Key.Visible = shown
	end
end
UserInputService.LastInputTypeChanged:Connect(refreshKeys)
refreshKeys()
UserInputService.InputBegan:Connect(function(input, processed)
	-- a key does only what a click could: not while the HUD or the columns are hidden (showcase, Upgrades tree)
	if processed or UserInputService:GetFocusedTextBox() or not (root.Enabled and grid.Visible) then
		return
	end
	for name, key in KEYS do
		if input.KeyCode == key then
			PanelSwitch.Action(PANEL[name])
			return
		end
	end
end)

-- Top-right pills (Roblox top-bar style) -------------------------------------------------------------------------
local bar = make("Frame", "TopRight", root, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 7),
	Size = UDim2.fromOffset(0, 44),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
})
local barScale = make("UIScale", "Scale", bar, {})
make("UIListLayout", "Layout", bar, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
})
local PILL_COLOR = Color3.fromRGB(18, 18, 21)
local PILL_TRANSPARENCY = 0.12 -- placeholder: nearly solid, so the see-through world signs do not read as HUD
local DAILY_WIDTH = 146 -- px, placeholder: fits "23:59:59", so the countdown never resizes the row
local function pill(name, order, caption)
	local b = make("TextButton", name, bar, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(caption and 0 or 44, 44),
		AutomaticSize = caption and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
		BackgroundColor3 = PILL_COLOR,
		BackgroundTransparency = PILL_TRANSPARENCY,
		Text = "",
		AutoButtonColor = false,
	})
	make("UICorner", "Corner", b, { CornerRadius = UDim.new(1, 0) })
	icon(name, b, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = caption and UDim2.new(0, 12, 0.5, 0) or UDim2.new(0.5, -13, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
	})
	local text
	if caption then
		make("UIPadding", "Padding", b, { PaddingRight = UDim.new(0, 16) })
		text = make("TextLabel", "Caption", b, {
			Position = UDim2.fromOffset(46, 0),
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = UiTheme.Font,
			TextSize = 19,
			TextColor3 = Color3.new(1, 1, 1),
			Text = caption,
		})
		outlined(text, 1.5)
	end
	b.Activated:Connect(function()
		PanelSwitch.Action(name)
	end)
	return b, text
end
local daily, dailyText = pill("Daily", 1, "Daily")
daily.AutomaticSize = Enum.AutomaticSize.None
daily.Size = UDim2.fromOffset(DAILY_WIDTH, 44)
local dailyBadge = badge(daily)
dailyBadge.Text = "!"
-- On the calendar's corner, clear of the caption.
dailyBadge.Position = UDim2.fromOffset(38, 9)
dailyBadge.Size = UDim2.fromOffset(18, 18)
dailyBadge.TextSize = 13
pill("Settings", 4)

-- Live state -----------------------------------------------------------------------------------------------------
-- Design doc 4.20: a shown badge (something claimable) pulses its ring until it hides.
local pulses = {}
local function pulse(b)
	if b.Visible and not pulses[b] then
		pulses[b] = UiMotion.Pulse(b.Ring, { Transparency = 0.75 }, 0.7)
	elseif not b.Visible and pulses[b] then
		pulses[b]()
		pulses[b] = nil
	end
end
-- Reduced Motion / REDUCED EFFECTS can flip while a badge shows: restart every pulse so it stops or starts at once.
local function restartPulses()
	local shown = {}
	for b, stop in pulses do
		stop()
		table.insert(shown, b)
	end
	table.clear(pulses)
	for _, b in shown do
		pulse(b)
	end
end
game:GetService("GuiService"):GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(restartPulses)
player:GetAttributeChangedSignal("ReduceEffects"):Connect(restartPulses)

-- Auto race toggle: it only asks; the AutoRacing attribute the server sets decides its look (design doc 4.40).
local AUTO_LOCK = 1 -- s a press stays locked, with no spin
local autoTile = tiles.Auto.Button
local autoIcon = autoTile.Icon
-- The arrows go over the still triangle (design doc 4.40). Green in both states; on Reduced Motion a ring replaces the spin.
autoIcon.Image = Icons.AutoPlay.Image
local autoArrows = autoIcon:Clone()
autoArrows.Name = "Arrows"
autoArrows.Image = Icons.AutoArrows.Image
-- The arrows art is centred on its image; the triangle stands 10/120 of the icon above centre, on the tab.
autoArrows.Position -= UDim2.fromOffset(0, ICON * 10 / 120)
autoArrows.Parent = autoTile
local autoRing = make("Frame", "OnRing", autoTile, {
	AnchorPoint = autoIcon.AnchorPoint,
	Position = autoArrows.Position,
	Size = autoIcon.Size,
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = autoIcon.ZIndex - 1,
})
make("UICorner", "Corner", autoRing, { CornerRadius = UDim.new(1, 0) })
make("UIStroke", "Ring", autoRing, { Color = UiTheme.Palette.Money, Thickness = 2 })
local autoBeat = make("UIScale", "Beat", autoIcon, {})
-- Placeholders.
local AUTO_SPIN = 200 -- degrees a second at full speed
local AUTO_EASE = 3.5 -- per second: spins up and winds down instead of snapping
local AUTO_BEAT, AUTO_BEAT_RATE = 0.08, 4 -- the triangle's breathing while on: size, radians a second
local autoSpeed, autoClock = 0, 0
local autoPending = false
local autoWasOn = false
local function refreshAuto()
	local on = player:GetAttribute("AutoRacing") == true and not autoPending
	autoTile.Active = not autoPending
	if on ~= autoWasOn then
		autoWasOn = on
		UiMotion.Pop(autoTile, 0.1)
	end
	autoTile:SetAttribute("Spinning", on and not UiMotion.Reduced())
	if UiMotion.Reduced() then
		autoSpeed = 0
		autoBeat.Scale = 1
	end
	autoRing.Visible = on and UiMotion.Reduced()
end
RunService.RenderStepped:Connect(function(dt)
	local goal = autoTile:GetAttribute("Spinning") and AUTO_SPIN or 0
	if autoSpeed == goal then
		return
	end
	autoSpeed += (goal - autoSpeed) * (1 - math.exp(-AUTO_EASE * dt))
	if math.abs(goal - autoSpeed) < 1 then
		autoSpeed = goal
	end
end)
RunService.RenderStepped:Connect(function(dt)
	if autoSpeed > 0 then
		autoClock += dt
		autoArrows.Rotation = (autoArrows.Rotation + autoSpeed * dt) % 360
		autoBeat.Scale = 1 + AUTO_BEAT * math.sin(autoClock * AUTO_BEAT_RATE) * autoSpeed / AUTO_SPIN
	end
end)
autoTile.Activated:Connect(function()
	if autoPending then
		return
	end
	autoPending = true
	refreshAuto()
	game:GetService("ReplicatedStorage")
		:WaitForChild("Remotes")
		:WaitForChild("SetAutoRace")
		:FireServer(player:GetAttribute("AutoRacing") ~= true)
	task.delay(AUTO_LOCK, function()
		autoPending = false
		refreshAuto()
	end)
end)
player:GetAttributeChangedSignal("AutoRacing"):Connect(refreshAuto)
game:GetService("GuiService"):GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(refreshAuto)
player:GetAttributeChangedSignal("ReduceEffects"):Connect(refreshAuto)
refreshAuto()

-- Section 10: a red badge pops when its count changes (never every refresh).
local function setBadge(b, count)
	local text = tostring(count)
	if count > 0 and b.Text ~= text then
		UiMotion.Pop(b)
	end
	if count > 0 and not b.Visible then
		UiFeedback.Play("BadgeNew", nil, { Sound = true }) -- only growing from 0, never every change
	end
	b.Visible = count > 0
	b.Text = text
	pulse(b)
end

-- Quests a press can claim right now (Remotes.QuestClaim still decides). Same attributes the Quests panel reads.
local function decoded(name)
	local raw = player:GetAttribute(name)
	local ok, value = pcall(HttpService.JSONDecode, HttpService, type(raw) == "string" and raw or "{}")
	return ok and type(value) == "table" and value or {}
end
local QUEST_LISTS = { { QuestConfig.Daily, "QuestDaily" }, { QuestConfig.Weekly, "QuestWeekly" } }
local claimableQuests = 0
local function countQuests()
	claimableQuests = 0
	for _, list in QUEST_LISTS do
		local progress, claimed = decoded(list[2] .. "Progress"), decoded(list[2] .. "Claimed")
		for _, quest in list[1] do
			if claimed[quest.Id] ~= 1 and (progress[quest.Id] or 0) >= quest.Target then
				claimableQuests += 1
			end
		end
	end
end

local function refresh()
	setBadge(tiles.Upgrade.Badge, player:GetAttribute("UpgradesBuyable") or 0)
	setBadge(tiles.Quests.Badge, claimableQuests)
	setBadge(tiles.Rebirth.Badge, player:GetAttribute("StatPoints") or 0)
	-- Same UTC day key the daily reward panel and DailyLoginService use.
	local now = os.time()
	local claimed = (player:GetAttribute("DailyLast") or -1) == math.floor(now / 86400)
	if not claimed and not dailyBadge.Visible then
		UiMotion.Pop(dailyBadge)
		UiFeedback.Play("BadgeNew", nil, { Sound = true })
	end
	dailyBadge.Visible = not claimed
	pulse(dailyBadge)
	if claimed then
		local left = 86400 - now % 86400
		dailyText.Text = string.format("%d:%02d:%02d", left // 3600, left // 60 % 60, left % 60)
	else
		dailyText.Text = "Daily"
	end
	local camera = workspace.CurrentCamera
	local phone = camera and camera.ViewportSize.Y <= 500
	for _, scale in scales do
		local bottomPair = scale.Parent == autoSlot or scale.Parent == upgradeSlot
		scale.Scale = (phone and 0.68 or 1) * (bottomPair and BOTTOM_SCALE or 1)
	end
	local pairScale = (phone and 0.68 or 1) * BOTTOM_SCALE
	barScale.Scale = phone and 0.8 or 1
	grid.Position = phone and UDim2.new(0, 8, 0.5, -20) or UDim2.new(0, 14, 0.5, -24)
	shopColumn.Position = phone and UDim2.new(1, -8, 0.5, -20) or UDim2.new(1, -14, 0.5, -24)
	-- Bottom pair: right beside the LEVEL / TURBO LUCK bars, each icon centred on the gap between the bars. That
	-- is below the Speed readout, so the wider Speed group never touches them. Where the pair stacks above the bars
	-- (height <= STACK_MAX_HEIGHT) an open panel fills its place, so there it hides while any panel is open (the
	-- panel's X and Escape close it); everywhere else it stays drawn.
	local hud = gui:FindFirstChild("RacerHud")
	local level = hud and hud:FindFirstChild("Level")
	local turbo = hud and hud:FindFirstChild("Turbo")
	local stacked = camera ~= nil and camera.ViewportSize.Y <= STACK_MAX_HEIGHT
	autoSlot.Visible = level ~= nil and turbo ~= nil and not (stacked and PanelSwitch.AnyOpen())
	upgradeSlot.Visible = autoSlot.Visible
	if autoSlot.Visible then
		-- AbsolutePosition starts below the top bar; these ScreenGuis ignore the inset, so add it back.
		local inset = GuiService:GetGuiInset().Y
		local left = math.min(level.AbsolutePosition.X, turbo.AbsolutePosition.X)
		local right =
			math.max(level.AbsolutePosition.X + level.AbsoluteSize.X, turbo.AbsolutePosition.X + turbo.AbsoluteSize.X)
		local gap = (level.AbsolutePosition.Y + level.AbsoluteSize.Y + turbo.AbsolutePosition.Y) / 2 + inset
		local function rect(name)
			local o = hud:FindFirstChild(name)
			if o and o:IsA("GuiObject") and o.Visible then
				local p = o.AbsolutePosition + Vector2.new(0, inset)
				return { p.X, p.Y, p.X + o.AbsoluteSize.X, p.Y + o.AbsoluteSize.Y }
			end
			return nil
		end
		local blockers = {}
		for _, name in { "Money", "Gems", "Speed" } do
			table.insert(blockers, rect(name))
		end
		if stacked then
			-- Owner 2026-10-28 (section 6): on the smallest phones the pair sits ABOVE the bars (bottom edge over the
			-- LEVEL bar and the Money read-out), just outside the Speed read-out on each side.
			local speed = rect("Speed")
			local money = rect("Money")
			local y = math.min(level.AbsolutePosition.Y + inset, money and money[2] or math.huge) - 6
			autoSlot.AnchorPoint = Vector2.new(1, 1)
			upgradeSlot.AnchorPoint = Vector2.new(0, 1)
			autoSlot.Position = UDim2.fromOffset(math.min(left, speed and speed[1] or left) - 6, y)
			upgradeSlot.Position = UDim2.fromOffset(math.max(right, speed and speed[3] or right) + 6, y)
		else
			autoSlot.AnchorPoint = Vector2.new(1, ICON_MID)
			upgradeSlot.AnchorPoint = Vector2.new(0, ICON_MID)
			autoSlot.Position = UDim2.fromOffset(left - 10, gap)
			upgradeSlot.Position = UDim2.fromOffset(right + 10, gap)
		end
		-- Owner 2026-10-28 (section 6): on narrow screens the pair shrinks (about its anchor) until it clears the
		-- Money and Speed read-outs; where they are already clear (desktop) the scale is unchanged.
		local function clear(k)
			local w, h = CELL.X * k, CELL.Y * k
			for _, slot in { autoSlot, upgradeSlot } do
				local x = slot.Position.X.Offset - slot.AnchorPoint.X * w
				local y = slot.Position.Y.Offset - slot.AnchorPoint.Y * h
				for _, b in blockers do
					if x < b[3] and x + w > b[1] and y < b[4] and y + h > b[2] then
						return false
					end
				end
			end
			return true
		end
		local k = pairScale
		-- shortcut: floor at 30%; if the read-outs still cover the anchor point the pair stays at the floor.
		while k > pairScale * 0.3 and not clear(k) do
			k -= pairScale * 0.02
		end
		autoSlot.Scale.Scale = k
		upgradeSlot.Scale.Scale = k
	end
	-- The roll showcase takes the whole screen; every HUD entry hides with the rest of the HUD.
	local showcase = gui:FindFirstChild("RollShowcase")
	root.Enabled = not (showcase and showcase.Enabled)
	-- The full-screen Upgrades tree shows no HUD through it. The Auto / Upgrade pair stays: design doc 4.27 keeps it
	-- drawn while a panel is open, and it hides by itself where it stacks.
	local inTree = PanelSwitch.IsOpen("Upgrades")
	-- Owner 2026-11-10 (design doc 4.40): in a boss event both columns hide; the pills, the pair and the event UI stay.
	local columns = not inTree and player:GetAttribute("BossEvent") ~= true
	grid.Visible, shopColumn.Visible, bar.Visible = columns, columns, not inTree
	setHudDimmed(PanelSwitch.AnyOpen())
end

for _, attr in { "UpgradesBuyable", "StatPoints", "DailyLast", "BossEvent" } do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
for _, attr in { "QuestDailyProgress", "QuestDailyClaimed", "QuestWeeklyProgress", "QuestWeeklyClaimed" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		countQuests()
		refresh()
	end)
end
countQuests()
PanelSwitch.OnChange(refresh)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= 0.25 then
		elapsed = 0
		refresh()
	end
end)
refresh()
UiTheme.Apply(root)
