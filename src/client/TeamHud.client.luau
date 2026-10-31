--!nonstrict
-- Team HUD (docs/TEAM_AND_STAMINA_SPEC.md "HUD"), display only: one stamina bar per Team slot while running (active
-- slot outlined), a tag-in toast and the "TEAM EXHAUSTED" result from Remotes.RunEvent, and a small Team picker
-- (up to 3 owned characters, Dojo squad members left out) that calls Remotes.SetTeam. The server checks everything.
-- shortcut: plain bars and a list picker, no portraits / drag; upgrade to the spec's portrait cards with the art pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(shared.CharacterCatalog)
local HudFormat = require(shared.HudFormat)
local UiTheme = require(shared.UiTheme)
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local SLOTS = 3
local ACTIVE = Color3.fromRGB(255, 214, 64)
local BLUE = Color3.fromRGB(61, 151, 219)
local GREEN = Color3.fromRGB(89, 225, 138)
local DARK = Color3.fromRGB(29, 32, 53)

local function make(class, name, parent, props)
	local o = Instance.new(class)
	o.Name = name
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function label(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = UiTheme.Font
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	local l = make("TextLabel", name, parent, props)
	UiTheme.Stroke(l, 1.5)
	return l
end

local gui = make("ScreenGui", "TeamHud", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	DisplayOrder = 4,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
})

local function teamIds()
	local ids = {}
	for id in string.gmatch(player:GetAttribute("Team") or "", "[^,]+") do
		table.insert(ids, id)
	end
	return ids
end
local function nameOf(id)
	local spec = CharacterCatalog.Get(id)
	return spec and spec.Name or tostring(id)
end

-- Stamina bars (bottom centre, above the Speed read-out)
local bars = make("Frame", "Stamina", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -150),
	Size = UDim2.fromOffset(SLOTS * 128, 36),
	BackgroundTransparency = 1,
	Visible = false,
})
make("UIListLayout", "Layout", bars, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local cards = {}
for slot = 1, SLOTS do
	local card = make("Frame", "Slot" .. slot, bars, {
		Size = UDim2.fromOffset(120, 32),
		BackgroundColor3 = DARK,
		LayoutOrder = slot,
	})
	UiTheme.Corner(card, UiTheme.Radius.S)
	local stroke = make("UIStroke", "Active", card, { Color = ACTIVE, Thickness = 0 })
	local fill = make("Frame", "Fill", card, {
		Position = UDim2.fromOffset(2, 20),
		Size = UDim2.new(1, -4, 0, 10),
		BackgroundColor3 = GREEN,
	})
	UiTheme.Corner(fill, 4)
	local name = label("Name", card, {
		Position = UDim2.fromOffset(6, 1),
		Size = UDim2.new(1, -12, 0, 18),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	cards[slot] = { Card = card, Stroke = stroke, Fill = fill, Name = name }
end

local function refreshBars()
	local ids = teamIds()
	bars.Visible = player:GetAttribute("AutoRacing") == true
	local active = player:GetAttribute("RunSlot") or 1
	for slot, c in cards do
		c.Card.Visible = ids[slot] ~= nil
		if ids[slot] then
			local v = math.clamp(player:GetAttribute("Stamina" .. slot) or 100, 0, 100)
			c.Name.Text = nameOf(ids[slot])
			c.Fill.Size = UDim2.new((1 - 4 / 120) * v / 100, 0, 0, 10)
			c.Fill.BackgroundColor3 = v > 25 and GREEN or Color3.fromRGB(238, 87, 107)
			c.Stroke.Thickness = slot == active and 3 or 0
			c.Card.BackgroundTransparency = slot == active and 0 or 0.35
		end
	end
end
for _, attr in { "Team", "AutoRacing", "RunSlot", "Stamina1", "Stamina2", "Stamina3" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshBars)
end
refreshBars()

-- Toast: tag-in and the short exhaustion result
local toast = label("Toast", gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(420, 48),
	TextSize = 34,
	TextColor3 = ACTIVE,
	Visible = false,
})
local toastId = 0
local function showToast(text, seconds)
	toastId += 1
	local mine = toastId
	toast.Text = text
	toast.Visible = true
	task.delay(seconds, function()
		if toastId == mine then
			toast.Visible = false
		end
	end)
end
remotes:WaitForChild("RunEvent").OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" then
		return
	end
	if ev.Kind == "Swap" then
		showToast(nameOf(ev.To) .. " TAG IN!", 1.5)
	elseif ev.Kind == "Exhausted" then
		showToast("TEAM EXHAUSTED  +" .. HudFormat.MoneyText(ev.Banked or 0), 3)
	end
end)

-- Team picker
local open = make("TextButton", "TeamButton", gui, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -210),
	Size = UDim2.fromOffset(96, 36),
	Text = "TEAM",
	Font = UiTheme.Font,
	TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = BLUE,
})
UiTheme.Corner(open, UiTheme.Radius.S)
local panel = make("Frame", "TeamPicker", gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(320, 380),
	BackgroundColor3 = DARK,
	Visible = false,
})
UiTheme.Plate(panel, BLUE)
panel.BackgroundTransparency = 0
local title = label("Title", panel, {
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -24, 0, 26),
	TextSize = 20,
	Text = "TEAM (pick up to 3)",
})
local list = make("ScrollingFrame", "List", panel, {
	Position = UDim2.fromOffset(12, 40),
	Size = UDim2.new(1, -24, 1, -110),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
local result = label("Result", panel, {
	Position = UDim2.new(0, 12, 1, -66),
	Size = UDim2.new(1, -24, 0, 18),
	TextSize = 13,
	Text = "",
})
local save = make("TextButton", "Save", panel, {
	Position = UDim2.new(0, 12, 1, -44),
	Size = UDim2.new(0.5, -18, 0, 34),
	Text = "SAVE",
	Font = UiTheme.Font,
	TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = GREEN,
})
local close = make("TextButton", "Close", panel, {
	Position = UDim2.new(0.5, 6, 1, -44),
	Size = UDim2.new(0.5, -18, 0, 34),
	Text = "CLOSE",
	Font = UiTheme.Font,
	TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = BLUE,
})
for _, b in { save, close } do
	UiTheme.Corner(b, UiTheme.Radius.S)
end

local picked = {}
local function candidates()
	local squad = {}
	for id in string.gmatch(player:GetAttribute("Showcase") or "", "[^,]+") do
		squad[id] = true
	end
	local specs = { CharacterCatalog.Get(CharacterCatalog.STARTER_ID) }
	local data = player:FindFirstChild("GachaData")
	for _, entry in data and data:GetChildren() or {} do
		local spec = CharacterCatalog.Get(entry.Name)
		if spec and not squad[spec.Id] then
			table.insert(specs, spec)
		end
	end
	table.sort(specs, function(a, b)
		return (a.SpeedMulti or 1) > (b.SpeedMulti or 1)
	end)
	return specs
end
local function refreshPicker()
	for _, row in list:GetChildren() do
		if row:IsA("TextButton") then
			row:Destroy()
		end
	end
	local running = player:GetAttribute("AutoRacing") == true
	title.Text = running and "TEAM (stop running to edit)" or "TEAM (pick up to 3)"
	for order, spec in candidates() do
		local at = table.find(picked, spec.Id)
		local row = make("TextButton", "Character_" .. spec.Id, list, {
			Size = UDim2.new(1, -6, 0, 30),
			LayoutOrder = order,
			Text = (at and ("[" .. at .. "]  ") or "") .. spec.Name .. "  (" .. tostring(spec.Rarity) .. ")",
			Font = UiTheme.Font,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = at and GREEN or Color3.fromRGB(42, 46, 74),
		})
		UiTheme.Corner(row, UiTheme.Radius.S)
		row.Activated:Connect(function()
			if running then
				return
			end
			local i = table.find(picked, spec.Id)
			if i then
				table.remove(picked, i)
			elseif #picked < SLOTS then
				table.insert(picked, spec.Id)
			end
			refreshPicker()
		end)
	end
	save.Active = not running and #picked > 0
	save.AutoButtonColor = save.Active
	save.BackgroundTransparency = save.Active and 0 or 0.5
end

open.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		picked = teamIds()
		result.Text = ""
		refreshPicker()
	end
end)
close.Activated:Connect(function()
	panel.Visible = false
end)
local busy = false
save.Activated:Connect(function()
	if busy or not save.Active then
		return
	end
	busy = true
	local ok, applied, reason = pcall(function()
		return remotes:WaitForChild("SetTeam"):InvokeServer(picked)
	end)
	result.Text = ok and tostring(reason or (applied and "Team updated" or "Try again"))
		or "Connection error; try again"
	busy = false
end)
for _, attr in { "AutoRacing", "Showcase" } do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if panel.Visible then
			refreshPicker()
		end
	end)
end
