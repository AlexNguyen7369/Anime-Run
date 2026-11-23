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
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local DojoHandscroll = require(script.Parent:WaitForChild("DojoHandscroll"))

local D = AnimeSkin.Dojo
local C = D.Colors
local REFRESH_SECONDS = 2 -- how often an open Details list rereads the player's luck
-- Design units (AnimeSkin.IndexFrame; design doc 4.46 rolloptions frame, placeholders).
local U = AnimeSkin.Units
local ROW_H, LINE_H, ROUNDING_H, PREFIX_W, INPUT_W, TOGGLE_W = 40, 34, 40, 90, 260, 180

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
	return make("TextLabel", name, parent, props)
end

local function button(name, parent, text)
	return make("TextButton", name, parent, { Text = text, AutoButtonColor = false, BorderSizePixel = 0 })
end

local root = make("ScreenGui", "RollOptions", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 60, -- above the roll view and every panel it is opened from
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Design doc 4.46: a small handscroll with the standard header (brush title, kanji, seal close). Returns the frame and
-- its units (g).
local function popup(name, title, size, maxSize)
	local frame = make("Frame", name, root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		Visible = false,
		Active = true,
	})
	make("UISizeConstraint", "Limit", frame, { MaxSize = maxSize })
	local heading = label("Title", frame, { Text = title })
	local close = button("Close", frame, "X")
	local g = AnimeSkin.IndexFrame(frame, { Title = heading, Close = close })
	close.Activated:Connect(function()
		RollOptions.Shut(frame)
	end)
	return frame, g
end

-- Rolls `frame` up to its centre, then hides it (design doc 4.46); a reopen meanwhile stops the roll.
function RollOptions.Shut(frame)
	DojoHandscroll.Close(frame, function()
		frame.Visible = false
	end)
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
		if child:IsA("GuiObject") and child ~= frame then
			local scroll = DojoHandscroll.Get(child)
			if scroll then
				scroll.Stop()
			end
			child.Visible = false
		end
	end
	frame.Visible = true
	DojoHandscroll.Open(frame) -- design doc 4.46: unrolls from its centre, every control live as it shows
end

-- Auto Sell ------------------------------------------------------------------------------------------------------
local sell, sg = popup("AutoSell", "Auto Sell", UDim2.new(0.8, 0, 0, 360), Vector2.new(700, 620))
local prefix = label("Prefix", sell, { Text = "1 in" })
local sellInput = make("TextBox", "Chance", sell, {
	ClearTextOnFocus = false,
	PlaceholderText = "1000",
	PlaceholderColor3 = C.Muted,
	Text = "",
})
D.Fill(sellInput, C.Field)
D.Rim(sellInput, C.Rim, 2)
D.Corner(sellInput, 4)
local sellToggle = button("Toggle", sell, "OFF")
local sellNote = label("Note", sell, {
	Text = "",
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})
local sellSave = button("Save", sell, "SAVE")
local noteColor = C.InkSoft
local wantOn = false

-- Its switch (kit.css .sw): a vermilion tile while ON, the paper button while OFF.
local function paintToggle()
	sellToggle.Text = wantOn and "ON" or "OFF"
	sg.Button(sellToggle, wantOn and "Go" or "Idle")
end

-- The row "1 in [N] ... [switch]" at the content top, the note under it, Save centred at the bottom.
sg.OnLayout(function(g)
	local c = g.Content
	g.Place(prefix, c.X, c.Y, PREFIX_W, U.Button)
	g.Place(sellInput, c.X + PREFIX_W + U.Gap, c.Y, INPUT_W, U.Button)
	g.Place(sellToggle, c.X + c.W - TOGGLE_W, c.Y, TOGGLE_W, U.Button)
	local noteY = c.Y + U.Button + U.Gap
	g.Place(sellNote, c.X, noteY, c.W, c.Y + c.H - U.Button - U.Gap - noteY)
	g.Place(sellSave, c.X + (c.W - 240) / 2, c.Y + c.H - U.Button, 240, U.Button)
	g.Role(prefix, "Item")
	g.Role(sellInput, "Body")
	g.Role(sellNote, "Body")
	sellNote.TextColor3 = noteColor
	sellInput.TextColor3 = C.Ink
	paintToggle()
	g.Button(sellSave, "Go")
end)

local NOTE =
	"Sells every roll with odds of 1 in N or more common, for Money, new characters too. Copies you already own stay."

local function setNote(text, color)
	sellNote.Text, noteColor = text, color
	sellNote.TextColor3 = color
end

local function readSell()
	wantOn = player:GetAttribute("AutoSell") == true
	local chance = player:GetAttribute("AutoSellChance")
	sellInput.Text = type(chance) == "number" and string.format("%.0f", chance) or ""
	setNote(NOTE, C.InkSoft)
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
		setNote("Enter a whole number for N, such as 1000.", C.Verm)
		UiFeedback.Play("Denied", sellSave)
		return
	end
	remotes:WaitForChild("SetAutoSell"):FireServer(wantOn, chance)
	RollOptions.Shut(sell)
	UiFeedback.Play("Toggle")
end)

function RollOptions.OpenAutoSell()
	readSell()
	show(sell)
end

-- Details --------------------------------------------------------------------------------------------------------
local details, dg = popup("Details", "Roll odds", UDim2.fromScale(0.86, 0.86), Vector2.new(1000, 620))
local luckLine = label("Luck", details, { Text = "", TextXAlignment = Enum.TextXAlignment.Left })
local normalTab = button("Normal", details, "NORMAL ROLL")
local turboTab = button("Turbo", details, "TURBO ROLL")
local lit = dg.Tabs({ normalTab, turboTab }) -- paper tabs; the shown one a red brush pill
local oddsList = make("ScrollingFrame", "List", details, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarImageColor3 = C.Rim,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, -- the bar sits beside the rows, not on them
})
local oddsLayout = make("UIListLayout", "Layout", oddsList, { SortOrder = Enum.SortOrder.LayoutOrder })
local rounding = label("Rounding", details, {
	Text = "Rounded to 3 digits. The most likely outcome takes the difference, so the list adds up to 100%.",
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
})

-- One odds row (kit.css .or): a paper slip with the rarity's strip, the name and rarity left, the percent right.
local function layRow(g, line)
	line.Size = UDim2.new(1, 0, 0, g.px(ROW_H))
	local name, percent = line:FindFirstChild("Name"), line:FindFirstChild("Percent") -- line.Name is its own name
	name.Position, name.Size = UDim2.fromOffset(g.px(20), 0), UDim2.new(0.68, -g.px(20), 1, 0)
	percent.Position, percent.Size = UDim2.fromScale(0.68, 0), UDim2.new(0.32, -g.px(14), 1, 0)
	g.Role(name, "Item")
	g.Role(percent, "Body")
end

-- The luck line at the content top, the list under it, the rounding note on the content's last line.
dg.OnLayout(function(g)
	local c = g.Content
	g.Place(luckLine, c.X, c.Y, c.W, LINE_H)
	local listY = c.Y + LINE_H + U.Inner
	g.Place(oddsList, c.X, listY, c.W, c.Y + c.H - ROUNDING_H - U.Inner - listY)
	g.Place(rounding, c.X, c.Y + c.H - ROUNDING_H, c.W, ROUNDING_H)
	oddsList.ScrollBarThickness = g.px(8)
	oddsLayout.Padding = UDim.new(0, g.px(4))
	g.Role(luckLine, "Body")
	luckLine.TextColor3 = C.InkSoft
	g.Role(rounding, "Caption")
	for _, line in oddsList:GetChildren() do
		if line:IsA("Frame") then
			layRow(g, line)
		end
	end
end)

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
	lit[1](not showTurbo)
	lit[2](showTurbo)
	for order, row in GachaConfig.OddsPercents(luck) do
		local line = make("Frame", row.Spec.Id, oddsList, { LayoutOrder = order })
		AnimeSkin.Plate(line, GachaConfig.RARITY_COLORS[row.Spec.Rarity] or AnimeSkin.Tint.Default)
		label("Name", line, {
			Text = row.Spec.Name .. "  (" .. row.Spec.Rarity .. ")",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		label("Percent", line, { Text = percentText(row.Percent), TextXAlignment = Enum.TextXAlignment.Right })
		layRow(dg, line)
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
