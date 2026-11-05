--!nonstrict
-- Two popups used from several places: Auto Sell (Settings, roll view, full bag banner; docs/BAG_AND_AUTOSELL_SPEC.md)
-- and Details, every roll outcome as a percentage at the player's current luck (roll view, luck Shop cards; design doc
-- 6). Display only: the server decides every number.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local BagConfig = require(shared:WaitForChild("BagConfig"))
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local PALETTE = UiTheme.Palette
local REFRESH_SECONDS = 2 -- how often an open Details list rereads the player's luck

local RollOptions = {}

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function label(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = UiTheme.Font
	props.TextColor3 = props.TextColor3 or PALETTE.White
	return make("TextLabel", name, parent, props)
end

local function button(name, parent, text, props)
	props.Font = UiTheme.Font
	props.Text = text
	props.TextColor3 = PALETTE.White
	props.TextSize = props.TextSize or 18
	props.BackgroundColor3 = props.BackgroundColor3 or PALETTE.Muted
	props.AutoButtonColor = true
	local b = make("TextButton", name, parent, props)
	UiTheme.Corner(b, "S")
	UiTheme.Stroke(b, 2, PALETTE.PanelDeep, true)
	return b
end

local root = make("ScreenGui", "RollOptions", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 60, -- above the roll view and every panel it is opened from
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local function popup(name, size)
	local frame = make("Frame", name, root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		Visible = false,
		Active = true,
	})
	UiTheme.Body(frame)
	make("UISizeConstraint", "Limit", frame, { MaxSize = Vector2.new(560, 620) })
	local close = button("Close", frame, "X", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = PALETTE.DangerDeep,
		TextSize = 22,
	})
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	return frame
end

function RollOptions.IsOpen()
	for _, child in root:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then
			return true
		end
	end
	return false
end

local function show(frame)
	for _, child in root:GetChildren() do
		if child:IsA("GuiObject") then
			child.Visible = child == frame
		end
	end
	UiMotion.Pop(frame, 0.04)
end

-- Auto Sell ------------------------------------------------------------------------------------------------------
local sell = popup("AutoSell", UDim2.new(0.8, 0, 0, 270))
label("Title", sell, {
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -70, 0, 36),
	Text = "Auto Sell",
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local sellToggle = button("Toggle", sell, "OFF", {
	Position = UDim2.fromOffset(16, 58),
	Size = UDim2.fromOffset(100, 44),
	TextSize = 22,
})
label("Prefix", sell, {
	Position = UDim2.fromOffset(130, 58),
	Size = UDim2.fromOffset(60, 44),
	Text = "1 in",
	TextSize = 24,
})
local sellInput = make("TextBox", "Chance", sell, {
	Position = UDim2.fromOffset(194, 58),
	Size = UDim2.new(1, -210, 0, 44),
	BackgroundColor3 = PALETTE.PanelDeep,
	ClearTextOnFocus = false,
	Font = UiTheme.Font,
	PlaceholderText = "1000",
	PlaceholderColor3 = PALETTE.SoftText,
	Text = "",
	TextColor3 = PALETTE.White,
	TextSize = 22,
})
UiTheme.Corner(sellInput, "S")
local sellNote = label("Note", sell, {
	Position = UDim2.fromOffset(16, 112),
	Size = UDim2.new(1, -32, 0, 90),
	Text = "",
	TextSize = 16,
	TextWrapped = true,
	TextColor3 = PALETTE.SoftText,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})
local sellSave = button("Save", sell, "SAVE", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(160, 44),
	BackgroundColor3 = PALETTE.MoneyDeep,
	TextSize = 22,
})

local NOTE = "Sells rolled duplicates with odds of 1 in N or more common, for Money. Your last copy and new "
	.. "characters are always kept."
local wantOn = false

local function paintToggle()
	sellToggle.Text = wantOn and "ON" or "OFF"
	sellToggle.BackgroundColor3 = wantOn and PALETTE.MoneyDeep or PALETTE.Muted
end

local function readSell()
	wantOn = player:GetAttribute("AutoSell") == true
	local chance = player:GetAttribute("AutoSellChance")
	sellInput.Text = type(chance) == "number" and string.format("%.0f", chance) or ""
	sellNote.Text = NOTE
	sellNote.TextColor3 = PALETTE.SoftText
	paintToggle()
end

sellToggle.Activated:Connect(function()
	wantOn = not wantOn
	paintToggle()
	UiFeedback.Play("Toggle")
end)

sellSave.Activated:Connect(function()
	local typed = string.gsub(sellInput.Text, "[,%s]", "")
	local chance = BagConfig.CleanChance(tonumber(typed))
	if wantOn and not chance then
		sellNote.Text = "Enter a whole number for N, such as 1000."
		sellNote.TextColor3 = PALETTE.DangerDeep
		UiFeedback.Play("Denied", sellSave)
		return
	end
	remotes:WaitForChild("SetAutoSell"):FireServer(wantOn, chance)
	sell.Visible = false
	UiFeedback.Play("Toggle")
end)

function RollOptions.OpenAutoSell()
	readSell()
	show(sell)
end

-- Details --------------------------------------------------------------------------------------------------------
local details = popup("Details", UDim2.fromScale(0.86, 0.86))
label("Title", details, {
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -70, 0, 36),
	Text = "Roll odds",
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local luckLine = label("Luck", details, {
	Position = UDim2.fromOffset(16, 46),
	Size = UDim2.new(1, -32, 0, 22),
	Text = "",
	TextSize = 16,
	TextColor3 = PALETTE.SoftText,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local normalTab = button("Normal", details, "NORMAL ROLL", {
	Position = UDim2.fromOffset(16, 72),
	Size = UDim2.fromOffset(150, 34),
	TextSize = 15,
})
local turboTab = button("Turbo", details, "TURBO ROLL", {
	Position = UDim2.fromOffset(174, 72),
	Size = UDim2.fromOffset(150, 34),
	TextSize = 15,
})
local oddsList = make("ScrollingFrame", "List", details, {
	Position = UDim2.fromOffset(12, 112),
	Size = UDim2.new(1, -24, 1, -158),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIListLayout", "Layout", oddsList, { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
label("Rounding", details, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -8),
	Size = UDim2.new(1, -32, 0, 32),
	Text = "Rounded to 3 digits. The most likely outcome takes the difference, so the list adds up to 100%.",
	TextSize = 13,
	TextWrapped = true,
	TextColor3 = PALETTE.SoftText,
	TextXAlignment = Enum.TextXAlignment.Left,
})

-- 3 significant digits in plain decimals, however small: 0.0000000301
local function percentText(percent)
	if percent <= 0 then
		return "0%"
	end
	local decimals = math.max(0, 2 - math.floor(math.log10(percent)))
	return string.format("%." .. decimals .. "f%%", percent)
end

local shownLuck, shownTurbo, showTurbo = nil, 1, false

local function paintOdds()
	for _, child in oddsList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local luck = (shownLuck or 1) * (showTurbo and shownTurbo or 1)
	luckLine.Text = string.format("Your luck: x%.2f   Turbo roll: x%d", shownLuck or 1, shownTurbo)
	normalTab.BackgroundColor3 = showTurbo and PALETTE.Muted or PALETTE.MoneyDeep
	turboTab.BackgroundColor3 = showTurbo and PALETTE.MoneyDeep or PALETTE.Muted
	for order, row in GachaConfig.OddsPercents(luck) do
		local line = make("Frame", row.Spec.Id, oddsList, {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 26),
			BackgroundTransparency = 1,
		})
		label("Name", line, {
			Size = UDim2.fromScale(0.62, 1),
			Text = row.Spec.Name .. "  (" .. row.Spec.Rarity .. ")",
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		label("Percent", line, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.38, 1),
			Text = percentText(row.Percent),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
end

local function readLuck()
	local ok, luck, turbo = pcall(function()
		return remotes:WaitForChild("GetRollLuck"):InvokeServer()
	end)
	if ok and type(luck) == "number" and (luck ~= shownLuck or turbo ~= shownTurbo) then
		shownLuck, shownTurbo = luck, type(turbo) == "number" and turbo or 1
		return true
	end
	return false
end

normalTab.Activated:Connect(function()
	showTurbo = false
	paintOdds()
end)
turboTab.Activated:Connect(function()
	showTurbo = true
	paintOdds()
end)

function RollOptions.OpenDetails()
	show(details)
	readLuck()
	paintOdds()
end

-- Paid luck boosts must show updated odds while active (design doc 6).
task.spawn(function()
	while true do
		task.wait(REFRESH_SECONDS)
		if details.Visible and readLuck() then
			paintOdds()
		end
	end
end)

UiTheme.Apply(root)

return RollOptions
