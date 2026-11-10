--!nonstrict
-- Starter choice popup (design doc 4.21): a new player (attribute NeedsStarter) picks one of the 3 starters. The server
-- decides (Remotes.PickStarter); this only displays and asks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared.CharacterCatalog)
local GachaConfig = require(Shared.GachaConfig)
local RunnerFactory = require(Shared.RunnerFactory)
local UiTheme = require(Shared.UiTheme)
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local ArrivalState = require(script.Parent:WaitForChild("ArrivalState"))
local Components = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("RacerComponents"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

-- Client/ArrivalFlow's reveal opens the popup by ArrivalRevealDone; if it never does, this many seconds after loading the
-- popup opens anyway (a player who cannot pick has no team).
local REVEAL_WATCHDOG_SECONDS = 10
local SLAM_HOLD = 0.2 -- placeholder: the popup stays this long after the server's yes, so the chosen card's Slam shows

local player = Players.LocalPlayer
local pick = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PickStarter")

local root = Instance.new("ScreenGui")
root.Name = "StarterPick"
root.ResetOnSpawn = false
root.DisplayOrder = 19 -- above every panel and the roll view (14): this comes first; below LoserScreen (20)
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
-- Room around the frame for its chrome and logo, which stand out past the panel's top and sides.
panel.Size = UDim2.fromScale(0.8, 0.72)
UiTheme.Body(panel)
panel.Parent = dim
UiTheme.Corner(panel, "L")
UiTheme.Stroke(panel, 3, UiTheme.Outline, true)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(920, 620) -- the Index's size
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
	if size >= 18 then
		UiTheme.Stroke(l, 2)
	end
	l.Parent = parent
	return l
end

-- Design doc 4.42: the Index frame, its logo the Index icon. No close: a new player must pick.
local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Parent = panel
local title = text(header, "Title", "CHOOSE YOUR STARTER", 38, UDim2.new(), 1)
local g = AnimeSkin.IndexFrame(panel, {
	Header = header,
	Title = title,
	Logo = require(script.Parent.RollToast.Ui.HudIcons).Index.Image,
})
local subtitle = text(panel, "Subtitle", "Roll the next two to fill your team", 16, UDim2.new(), 0)

local row = Instance.new("Frame")
row.Name = "Cards"
row.BackgroundTransparency = 1
row.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = row

local views = {}
local picking = false -- a pick is out, or its card is slamming: the popup stays even though NeedsStarter is gone
local update

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
	UiTheme.Plate(card, UiTheme.Palette.Tile).BackgroundTransparency = 0
	AnimeSkin.Card(card, GachaConfig.RARITY_COLORS[spec.Rarity] or AnimeSkin.Tint.Default)
	card.Parent = row

	-- Inside the card, 12 padding: the art, 8, the name, 8, Choose (44). The drawn portrait; with none yet, the live
	-- model (refill keeps it current). Placed by the layout below.
	local image = Components.PortraitImage(spec)
	local view = Instance.new(image and "ImageLabel" or "ViewportFrame")
	view.Name = "Art"
	view.BackgroundTransparency = 1
	if image then
		view.Image = image
		view.ImageColor3 = Color3.new(1, 1, 1)
		view.ScaleType = Enum.ScaleType.Fit
	else
		view.Ambient = Color3.fromRGB(175, 175, 185) -- 3D light, not UI
		view.LightColor = Color3.new(1, 1, 1)
		view.LightDirection = Vector3.new(-1, -2, -1)
		views[id] = view
	end
	view.Parent = card

	text(card, "CharacterName", spec.Name, 20, UDim2.new(), 0)

	local button = Instance.new("TextButton")
	button.Name = "Choose"
	button.BackgroundColor3 = UiTheme.Palette.MoneyDeep
	button.AutoButtonColor = false
	button.Text = "CHOOSE"
	button.Parent = card
	UiTheme.Corner(button, "S")
	local busy = false
	button.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		picking = true
		local ok, taken = pcall(function()
			return pick:InvokeServer(id)
		end)
		if ok and taken then
			player:SetAttribute("StarterPicked", id) -- local only: Client/ArrivalFlow plays the in-world reveal
			UiFeedback.Play("StarterPick", card)
			if not UiMotion.Reduced() then
				task.wait(SLAM_HOLD)
			end
		else
			UiFeedback.Play("Denied", button)
		end
		picking = false
		update()
		busy = false
	end)
end

-- In the frame's units: the subtitle at the content top, the three cards under it, 12 apart.
g.OnLayout(function()
	local c = g.Content
	g.Place(subtitle, c.X, c.Y, c.W, 28)
	g.Role(subtitle, "Body")
	local top = c.Y + 28 + 12
	local w, h = (c.W - 2 * 12) / 3, c.Y + c.H - top
	g.Place(row, c.X, top, c.W, h)
	layout.Padding = UDim.new(0, g.px(12))
	for _, card in row:GetChildren() do
		if card:IsA("Frame") then
			card.Size = g.at(w, h)
			g.Place(card.Art, 12, 12, w - 24, h - 12 - 34 - 8 - 44 - 8 - 12)
			g.Place(card.CharacterName, 12, h - 12 - 44 - 8 - 34, w - 24, 34)
			g.Role(card.CharacterName, "Item")
			g.Place(card.Choose, 12, h - 12 - 44, w - 24, 44)
			g.Button(card.Choose, "Go")
		end
	end
end)

local function refill()
	for id, view in views do
		fill(view, id)
	end
end

function update()
	local show = picking
		or (player:GetAttribute("NeedsStarter") == true and player:GetAttribute("ArrivalRevealDone") == true)
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
	-- only the starters' models (CharacterModelService Loaded_<id>), not all of them
	local function starters()
		for _, id in CharacterCatalog.STARTER_PICKS do
			if models:GetAttribute("Loaded_" .. id) ~= true then
				return false
			end
		end
		return true
	end
	while not starters() and models:GetAttribute("Ready") ~= true do
		models.AttributeChanged:Wait()
	end
	if root.Enabled then
		refill()
	end
end)
