--!nonstrict
-- Starter choice popup (design doc 4.21): a new player (attribute NeedsStarter) picks one of the 3 starters. The server
-- decides (Remotes.PickStarter); this only displays and asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared.CharacterCatalog)
local RunnerFactory = require(Shared.RunnerFactory)
local UiTheme = require(Shared.UiTheme)
local ArrivalState = require(script.Parent:WaitForChild("ArrivalState"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

-- Client/ArrivalFlow's reveal opens the popup by ArrivalRevealDone; if it never does, this many seconds after loading the
-- popup opens anyway (a player who cannot pick has no team).
local REVEAL_WATCHDOG_SECONDS = 10

local player = Players.LocalPlayer
local pick = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PickStarter")

local root = Instance.new("ScreenGui")
root.Name = "StarterPick"
root.ResetOnSpawn = false
root.DisplayOrder = 50 -- above every panel: this comes first
root.IgnoreGuiInset = true
root.Enabled = false

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.6 -- the plaza shows behind the popup (design doc 4.24, proposed)
dim.Active = true -- swallows clicks to the HUD behind it
dim.Parent = root

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.92, 0.84)
panel.BackgroundColor3 = Color3.fromRGB(28, 32, 48)
panel.Parent = dim
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(860, 520)
limit.Parent = panel

local function text(parent, name, value, size, pos, height)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = pos
	l.Size = UDim2.new(1, -16, height, 0)
	l.Font = UiTheme.Font
	l.Text = value
	l.TextColor3 = UiTheme.Palette.White
	l.TextScaled = true
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.Parent = l
	l.Parent = parent
	return l
end

text(panel, "Title", "CHOOSE YOUR STARTER", 34, UDim2.fromScale(0.5, 0.03), 0.11)
text(panel, "Subtitle", "Roll the next two to fill your team", 20, UDim2.fromScale(0.5, 0.14), 0.07)

local row = Instance.new("Frame")
row.Name = "Cards"
row.BackgroundTransparency = 1
row.Position = UDim2.fromScale(0.02, 0.23)
row.Size = UDim2.fromScale(0.96, 0.74)
row.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0.015, 0)
layout.Parent = row

local views = {}

local function fill(view, id)
	view:ClearAllChildren()
	local rig = RunnerFactory.build(id)
	local label = rig:FindFirstChild("NameLabel")
	if label then
		label:Destroy() -- the card shows the name
	end
	rig.Parent = view
	local box, extents = rig:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local distance = 0.8 * extents.Magnitude / 2 / math.sin(math.rad(15))
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0.45, 0.15, -1).Unit * distance, box.Position)
	camera.Parent = view
	view.CurrentCamera = camera
end

for i, id in CharacterCatalog.STARTER_PICKS do
	local spec = CharacterCatalog.Get(id)
	local card = Instance.new("Frame")
	card.Name = id
	card.LayoutOrder = i
	card.Size = UDim2.fromScale(0.32, 1)
	card.BackgroundColor3 = Color3.fromRGB(44, 50, 72)
	card.Parent = row
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local view = Instance.new("ViewportFrame")
	view.Name = "Art"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 0.68)
	view.Ambient = Color3.fromRGB(175, 175, 185)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -2, -1)
	view.Parent = card
	views[id] = view

	text(card, "CharacterName", spec.Name, 24, UDim2.fromScale(0.5, 0.68), 0.12)

	local button = Instance.new("TextButton")
	button.Name = "Choose"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -8)
	button.Size = UDim2.new(1, -16, 0.15, 0)
	button.BackgroundColor3 = Color3.fromRGB(70, 170, 90)
	button.Font = UiTheme.Font
	button.Text = "CHOOSE"
	button.TextColor3 = UiTheme.Palette.White
	button.TextScaled = true
	local buttonText = Instance.new("UITextSizeConstraint")
	buttonText.MaxTextSize = 24
	buttonText.Parent = button
	button.Parent = card
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	local busy = false
	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local ok, taken = pcall(function()
			return pick:InvokeServer(id)
		end)
		if ok and taken then
			player:SetAttribute("StarterPicked", id) -- local only: Client/ArrivalFlow plays the in-world reveal
		end
		busy = false
	end)
end

local function refill()
	for id, view in views do
		fill(view, id)
	end
end

local function update()
	local show = player:GetAttribute("NeedsStarter") == true and player:GetAttribute("ArrivalRevealDone") == true
	if show and not root.Enabled then
		refill()
		UiMotion.Pop(panel)
	end
	root.Enabled = show
end

local function armWatchdog()
	if player:GetAttribute("NeedsStarter") == true then
		task.spawn(function()
			ArrivalState.WaitForLoading()
			task.wait(REVEAL_WATCHDOG_SECONDS)
			player:SetAttribute("ArrivalRevealDone", true)
		end)
	end
end

root.Parent = player:WaitForChild("PlayerGui")
player:GetAttributeChangedSignal("NeedsStarter"):Connect(function()
	armWatchdog()
	update()
end)
player:GetAttributeChangedSignal("ArrivalRevealDone"):Connect(update)
armWatchdog()
update()

-- The models load in the background: show them once they arrive.
task.spawn(function()
	local models = ReplicatedStorage:WaitForChild("CharacterModels")
	if models:GetAttribute("Ready") ~= true then
		models:GetAttributeChangedSignal("Ready"):Wait()
	end
	if root.Enabled then
		refill()
	end
end)
