--!nonstrict
-- Draws this player's NPC racer and the loser screen. The server decides the race (Server/RaceService) and sends
-- the events to this player only; the NPC runner is created here, in this client's Workspace, so no other player
-- ever sees it. Its position is pure maths (Shared/NpcRacer), driven by the server clock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcConfig = require(Shared.NpcConfig)
local NpcRacer = require(Shared.NpcRacer)
local RouteMath = require(Shared.RaceProgressMap)
local TrackRegistry = require(Shared.TrackRegistry)
local UiTheme = require(Shared.UiTheme)
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NpcRace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Lanes per track number, built once from the same chain the server builds
local lanes = {}
for _, entry in NpcRacer.ChainEntries() do
	lanes[entry.Number] = NpcRacer.LanePath(entry)
end

local current = nil -- { Model, Path, Profile, ServerStart }

-- The enemy's indicator (design doc 4.26): the arrow tip follows the top of its head at a fixed pixel size. A ScreenGui
-- because it must show through walls, fog and any distance; AlwaysOnTop BillboardGuis did not draw in Studio.
local INDICATOR_SIZE = UDim2.fromOffset(340, 96) -- px (placeholder)
local INDICATOR_GAP = 0.4 -- studs between the head and the arrow tip

local indicatorGui = Instance.new("ScreenGui")
indicatorGui.Name = "NpcIndicator"
indicatorGui.DisplayOrder = -1 -- under the HUD
indicatorGui.ResetOnSpawn = false
indicatorGui.ScreenInsets = Enum.ScreenInsets.None -- the whole window, as WorldToViewportPoint counts it
indicatorGui.Parent = playerGui
local indicator = Instance.new("Frame")
indicator.Name = "Indicator"
indicator.AnchorPoint = Vector2.new(0.5, 1)
indicator.Size = INDICATOR_SIZE
indicator.BackgroundTransparency = 1
indicator.Visible = false
indicator.Parent = indicatorGui

-- Off screen a smaller pointer takes over (design doc 4.26). Margins clear the HUD: side columns, top bar, team row.
local POINTER_SIZE = UDim2.fromOffset(150, 84) -- px (placeholder)
local POINTER_MARGIN = { Side = 175, Top = 60, Bottom = 175 } -- px from the screen edge to its centre (placeholder)

local pointer = Instance.new("Frame")
pointer.Name = "Pointer"
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Size = POINTER_SIZE
pointer.BackgroundTransparency = 1
pointer.Visible = false
pointer.Parent = indicatorGui

local function indicatorLine(parent, name, text, y, height, color)
	local line = Instance.new("TextLabel")
	line.Name = name
	line.Position = UDim2.fromScale(0, y)
	line.Size = UDim2.fromScale(1, height)
	line.BackgroundTransparency = 1
	line.Text = text
	line.TextScaled = true
	line.Font = UiTheme.Font
	line.TextColor3 = color
	UiTheme.Stroke(line, 3)
	line.Parent = parent
	return line
end
local indicatorName = indicatorLine(indicator, "Text", "", 0, 0.55, Color3.new(1, 1, 1))
indicatorLine(indicator, "Arrow", "\u{25BC}", 0.55, 0.45, UiTheme.Palette.Danger)
local pointerName = indicatorLine(pointer, "Text", "", 0, 0.4, Color3.new(1, 1, 1))
local pointerArrow = indicatorLine(pointer, "Arrow", "\u{25BC}", 0.4, 0.6, UiTheme.Palette.Danger)

-- Where the pointer sits for a screen direction: from the screen centre along it to the margin rectangle.
local function pointerSpot(viewport, direction)
	local centre = viewport / 2
	local toX = direction.X > 0 and viewport.X - POINTER_MARGIN.Side - centre.X or POINTER_MARGIN.Side - centre.X
	local toY = direction.Y > 0 and viewport.Y - POINTER_MARGIN.Bottom - centre.Y or POINTER_MARGIN.Top - centre.Y
	local scale = math.min(
		direction.X ~= 0 and toX / direction.X or math.huge,
		direction.Y ~= 0 and toY / direction.Y or math.huge
	)
	return centre + direction * math.max(scale, 0)
end

local function placeIndicator()
	local head = current.Model:FindFirstChild("Head") or current.Model.PrimaryPart
	local top = head.Position + Vector3.new(0, head.Size.Y / 2 + INDICATOR_GAP, 0)
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local point = camera:WorldToViewportPoint(top)
	local onScreen = point.Z > 0 and point.X >= 0 and point.X <= viewport.X and point.Y >= 0 and point.Y <= viewport.Y
	if indicator.Visible ~= onScreen or pointer.Visible == onScreen then
		indicator.Visible = onScreen
		pointer.Visible = not onScreen
		UiMotion.Pop(onScreen and indicator or pointer) -- design doc 4.20: on the swap only, never every frame
	end
	if onScreen then
		indicator.Position = UDim2.fromOffset(point.X, point.Y)
		return
	end
	-- Camera space, not the viewport point: that point mirrors once the enemy is behind the camera.
	local relative = camera.CFrame:PointToObjectSpace(top)
	local direction = Vector2.new(relative.X, -relative.Y)
	direction = direction.Magnitude > 0.01 and direction.Unit or Vector2.new(0, 1) -- dead behind: point down
	local spot = pointerSpot(viewport, direction)
	pointer.Position = UDim2.fromOffset(spot.X, spot.Y)
	pointerArrow.Rotation = math.deg(math.atan2(direction.Y, direction.X)) - 90 -- the glyph points down at 0
end

local function clearNpc()
	if current then
		current.Model:Destroy()
		current = nil
	end
	indicator.Visible = false
	pointer.Visible = false
end

local function startNpc(event)
	clearNpc()
	local path = lanes[event.Track]
	if not path then
		return
	end
	local info = NpcConfig.For(event.Track)
	info.Color = typeof(event.Color) == "Color3" and event.Color or info.Color
	info.Label = type(event.Label) == "string" and event.Label or info.Label
	info.Model = type(event.Model) == "string" and event.Model or info.Model
	local profile = NpcRacer.Profile(path, type(event.Speed) == "number" and event.Speed or info.Speed)
	local model = NpcRacer.BuildModel(info)
	model:PivotTo(NpcRacer.PoseAt(path, profile, 0))
	model.Parent = Workspace -- client-side only: never replicated
	current = { Model = model, Path = path, Profile = profile, ServerStart = event.ServerStart }
	indicatorName.Text = info.Label
	pointerName.Text = info.Label
end

-- Loser screen (docs/NPC_RACER_SPEC.md "Loser screen", docs/HUD_LAYOUT_SPEC.md sections 8 and 10): built once,
-- only its texts change per loss. Non-interactive; the shade is the first GuiObject child and covers the screen.
local Palette = UiTheme.Palette
local CARD_W, CARD_H, OVERHANG = 460, 330, 14
local ROW_STAGGER = 0.06

local Themes = require(Shared.BiomeThemes)
local trackNames = {}
for _, spec in TrackRegistry.Chain() do
	local theme = Themes[spec.Biome]
	trackNames[spec.Number] = theme and theme.DisplayName or spec.Name -- one name per track, as EnemyShowdown shows
end

local gui = Instance.new("ScreenGui")
gui.Name = "LoserScreen"
gui.DisplayOrder = 61 -- the overlay draws above every other game GUI, including DuelUi and RollOptions (60)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = playerGui
UiTheme.Apply(gui) -- FredokaOne on every recap label, rows added later included (HUD_LAYOUT_SPEC section 8)
local shade = Instance.new("Frame")
shade.Name = "Shade"
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(40, 6, 16)
shade.BackgroundTransparency = 0.3
shade.BorderSizePixel = 0
shade.Parent = gui

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.new(0.5, 0, 0.5, OVERHANG // 2)
card.Size = UDim2.fromOffset(CARD_W, CARD_H)
UiTheme.Plate(card, Palette.Danger)
AnimeSkin.Body(card) -- design doc 4.42: the framed body art
card.Parent = shade
-- Layout scale (not MotionScale): the card keeps 16 px margins down to a 600 x 390 phone viewport.
local fit = Instance.new("UIScale")
fit.Name = "FitScale"
fit.Parent = card
local function refit()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		fit.Scale = math.min(1, (size.X - 32) / CARD_W, (size.Y - 32) / (CARD_H + OVERHANG))
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
refit()

local function label(name, parent, y, height, textSize, color)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, y)
	text.Size = UDim2.new(1, -40, 0, height)
	text.BackgroundTransparency = 1
	text.Font = UiTheme.Font
	text.TextSize = textSize
	text.TextColor3 = color or Palette.White
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Text = ""
	UiTheme.Stroke(text, 2)
	text.Parent = parent
	return text
end

local ribbon = Instance.new("Frame")
ribbon.Name = "BannerRibbon"
ribbon.AnchorPoint = Vector2.new(0.5, 0)
ribbon.Position = UDim2.new(0.5, 0, 0, -OVERHANG)
ribbon.Size = UDim2.fromOffset(CARD_W - 60, 64)
ribbon.BackgroundColor3 = Palette.White
ribbon.BorderSizePixel = 0
UiTheme.Corner(ribbon, "M")
UiTheme.Gradient(ribbon, Palette.Danger, Palette.DangerDeep)
UiTheme.Stroke(ribbon, 3, nil, true)
ribbon.Parent = card
local banner = label("Banner", ribbon, 0, 64, 44)
banner.Size = UDim2.fromScale(1, 1)
banner.Text = "YOU LOST"
UiTheme.Stroke(banner, 3)
AnimeSkin.Title(banner, 44)

local rows = {
	label("NpcName", card, 62, 30, 26),
	label("TrackTitle", card, 94, 22, 18, Palette.Unbanked),
	label("YourTime", card, 128, 30, 26, Palette.Behind),
	label("NpcTime", card, 160, 30, 26),
	label("Gap", card, 194, 34, 32, Palette.Danger),
	label("Pb", card, 234, 24, 20, Palette.Speed),
	label("BackTo", card, 264, 24, 20),
}
local npcName, trackTitle, yourTime, npcTime, gap, pb, backTo = table.unpack(rows)

local countdown = Instance.new("Frame")
countdown.Name = "Countdown"
countdown.AnchorPoint = Vector2.new(0.5, 0)
countdown.Position = UDim2.new(0.5, 0, 0, 298)
countdown.Size = UDim2.new(1, -60, 0, 12)
countdown.BackgroundColor3 = Palette.PanelDeep
countdown.BorderSizePixel = 0
UiTheme.Corner(countdown, "S")
UiTheme.Stroke(countdown, 2, nil, true)
countdown.Parent = card
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = Palette.White
fill.BorderSizePixel = 0
UiTheme.Corner(fill, "S")
UiTheme.Gradient(fill, Palette.Danger, Palette.DangerDeep)
fill.Parent = countdown

local homes = { [ribbon] = ribbon.Position }
for _, row in rows do
	homes[row] = row.Position
end

local runStart = nil -- the run's start track: the Reset's Track, else the run's first Start
local lastBest = {} -- track -> best time from the Start event
local function backToText(s)
	s = math.max(1, math.floor(tonumber(s) or 1))
	return s == 1 and "Back to the start" or ("Back to checkpoint %d"):format(s)
end

local loseToken = 0
local shownAt = 0
local drain = nil
local function hideLoser()
	loseToken += 1
	gui.Enabled = false
end

local function showLoser(event)
	loseToken += 1
	local token = loseToken
	local track = tonumber(event.Track) or 1
	local mine, theirs = tonumber(event.PlayerTime), tonumber(event.NpcTime)
	local best = tonumber(event.BestTime) or lastBest[track]
	npcName.Text = NpcConfig.For(track).Label
	trackTitle.Text = ("TRACK %d · %s"):format(track, string.upper(trackNames[track] or "RACE"))
	yourTime.Text = "YOUR TIME " .. (mine and RouteMath.FormatTime(mine) or "--")
	npcTime.Text = "ENEMY TIME " .. (theirs and RouteMath.FormatTime(theirs) or "--")
	gap.Text = (mine and theirs) and ("+%.2fs"):format(math.max(0, mine - theirs)) or ""
	pb.Text = best and "PB " .. RouteMath.FormatTime(best) or "PB --"
	backTo.Text = backToText(runStart or 1)

	for gui_, home in homes do
		gui_.Position = home
	end
	if drain then
		drain:Cancel()
	end
	fill.Size = UDim2.fromScale(1, 1)
	shownAt = os.clock()
	gui.Enabled = true
	refit()

	UiMotion.SlideIn(ribbon, Vector2.new(0, -80), 0.25)
	task.delay(0.25, function()
		if loseToken == token then
			UiFeedback.Play("LoseRibbon", ribbon, { Color = Palette.Danger })
		end
	end)
	local reduced = UiMotion.Reduced()
	for i, row in rows do
		row.Visible = reduced
		if not reduced then
			task.delay(0.12 + (i - 1) * ROW_STAGGER, function()
				if loseToken == token then
					row.Visible = true
					UiMotion.SlideIn(row, Vector2.new(0, 18), 0.22)
					UiFeedback.Play("LoseRow", row, { Sound = row == gap })
				end
			end)
		else
			UiFeedback.Play("LoseRow", row, { Sound = row == gap })
		end
	end
	-- Not Fill: this bar is the recap's countdown, draining over LOSE_SCREEN_SECONDS; Fill always takes 0.2 s.
	drain = UiMotion.Create(
		fill,
		TweenInfo.new(NpcConfig.LOSE_SCREEN_SECONDS, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(0, 1) }
	)
	drain:Play()

	task.delay(NpcConfig.LOSE_SCREEN_SECONDS, function()
		if loseToken == token then
			gui.Enabled = false
		end
	end)
end

-- Start / Reset never cut the recap short; once its time is up they hide it at once.
local function hideIfDone()
	if gui.Enabled and os.clock() - shownAt >= NpcConfig.LOSE_SCREEN_SECONDS then
		hideLoser()
	end
end

remote.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then
		return
	end
	if event.Type == "Start" then
		startNpc(event)
		if runStart == nil then
			runStart = event.Track
		end
		if type(event.Track) == "number" then
			lastBest[event.Track] = tonumber(event.BestTime)
		end
		-- A loss is followed immediately by Reset + Start. Keep the presentation
		-- overlay alive for its configured duration while the new NPC is rebuilt.
		hideIfDone()
	elseif event.Type == "Result" and event.Result == "Lose" then
		showLoser(event)
	elseif event.Type == "Reset" then
		clearNpc()
		-- Reset is authoritative and immediate, but must not cancel the loser
		-- presentation: RaceService sends it in the same frame as Result/Lose.
		if type(event.Track) == "number" then
			runStart = event.Track
			if gui.Enabled then
				backTo.Text = backToText(runStart)
			end
		end
		hideIfDone()
	elseif event.Type == "Stop" then
		clearNpc()
		runStart = nil
		hideLoser()
	end
end)

local npcPhase = 0
-- After the camera moves, or the indicator trails the head by one frame of camera motion.
RunService:BindToRenderStep("NpcRacer", Enum.RenderPriority.Last.Value, function(dt)
	if current and current.Model.Parent then
		local t = Workspace:GetServerTimeNow() - current.ServerStart
		local running = t < current.Profile.TotalTime
		npcPhase = RunnerVisual.Advance(npcPhase, running and current.Profile.Speed or 0, dt)
		RunnerVisual.Pose(
			current.Model,
			NpcRacer.PoseAt(current.Path, current.Profile, t),
			npcPhase,
			running and 1 or 0
		)
		placeIndicator()
	end
end)
