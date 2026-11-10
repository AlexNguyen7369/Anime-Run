--!nonstrict
-- Team slot picker (design doc 4.13: one aura and one trail per team slot; 4.2: 3 character slots). Three slot
-- buttons; tapping one puts the shown item on that slot, or takes it off when it is already there. Kind "Aura" /
-- "Trail" shows each slot's Slot<n>Aura / Slot<n>Trail (Remotes.MarketEquip(kind, id or nil, slot)); kind
-- "Character" shows each slot's Team member (the caller sends Remotes.SetTeam). The server decides. Shared by the
-- Market detail pane and the Backpack.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local Market = require(shared:WaitForChild("MarketConfig"))
local CharacterCatalog = require(shared:WaitForChild("CharacterCatalog"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))

local FREE = UiTheme.Palette.Row -- the slot takes the item; not the money green, so equip and pay look different
local HERE = UiTheme.Palette.SlotHere -- the item is on this slot: tapping removes it

local SlotPicker = {}

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

-- A one-line label in one of AnimeSkin's text roles (design doc 4.42).
local function caption(name, parent, props, role)
	props.BackgroundTransparency = 1
	props.TextTruncate = Enum.TextTruncate.AtEnd
	return AnimeSkin.Label(make("TextLabel", name, parent, props), role)
end

-- The Team ids in slot order (the player attribute Team).
function SlotPicker.Team()
	return string.split(player:GetAttribute("Team") or "", ",")
end

-- True when `id` sits on team slot `slot` for `kind`.
local function isHere(kind, slot, id)
	if kind == "Character" then
		return SlotPicker.Team()[slot] == id
	end
	return player:GetAttribute(Market.SlotAttribute(slot, kind)) == id
end

-- Short item name for the slot line ("Azure Aura" -> "Azure"), nil for nothing there.
local function short(kind, id)
	local item = Market.Get(kind, id)
	return item and (string.gsub(item.Name, "%s+" .. kind .. "$", ""))
end

-- What a slot wears, in plain words.
local function wearing(aura, trail)
	if aura and trail then
		return aura .. " + " .. trail
	end
	return aura or trail or "Empty"
end

-- A Frame named `name` under `parent` with `props`; onPick(slot, id) gets the tapped slot and the id to send (nil =
-- take it off). Call :Update(kind, id) with the item the screen shows (id nil: nothing picked yet).
function SlotPicker.new(name, parent, props, onPick)
	local frame = make("Frame", name, parent, props)
	frame.BackgroundTransparency = 1
	-- Buttons 40 tall, 12 apart (design doc 4.42), centred in whatever row the caller gives.
	local gap, height = AnimeSkin.Px(AnimeSkin.Space.Gap), AnimeSkin.Px(AnimeSkin.Space.Button)
	make("UIListLayout", "Layout", frame, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local picker = { Frame = frame, Buttons = {}, Kind = nil, Id = nil }
	for slot = 1, Market.SLOTS do
		local b = make("TextButton", "Slot" .. slot, frame, {
			LayoutOrder = slot,
			Size = UDim2.new(1 / Market.SLOTS, -math.ceil(gap * (Market.SLOTS - 1) / Market.SLOTS), 0, height),
			BackgroundColor3 = FREE,
			Text = "",
			AutoButtonColor = false,
		})
		UiTheme.Corner(b, "S")
		AnimeSkin.Button(b, "Idle") -- the anime look (design doc 4.42); Update keeps its own free / here fills
		local title = caption("Title", b, {
			Position = UDim2.fromOffset(8, 2),
			Size = UDim2.new(1, -16, 0.5, -2),
			Text = "SLOT " .. slot,
		}, "Body")
		local items = caption("Items", b, {
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.new(1, -16, 0.5, -2),
			Text = "",
		}, "Caption")
		picker.Buttons[slot] = { Button = b, Title = title, Items = items }
		b.Activated:Connect(function()
			if not (picker.Kind and picker.Id) then
				onPick(slot, nil, false)
				return
			end
			local here = isHere(picker.Kind, slot, picker.Id)
			onPick(slot, if here then nil else picker.Id, true)
		end)
	end
	function picker:Update(kind, id)
		self.Kind, self.Id = kind, id
		for slot, refs in self.Buttons do
			if kind == "Character" then
				local here = id ~= nil and isHere(kind, slot, id)
				local spec = CharacterCatalog.Get(SlotPicker.Team()[slot])
				refs.Items.Text = spec and spec.Name or "-"
				refs.Title.Text = (here and "REMOVE " or "SLOT ") .. slot
				refs.Button.BackgroundColor3 = here and HERE or FREE
				continue
			end
			local aura = player:GetAttribute(Market.SlotAttribute(slot, "Aura"))
			local trail = player:GetAttribute(Market.SlotAttribute(slot, "Trail"))
			local here = id ~= nil and player:GetAttribute(Market.SlotAttribute(slot, kind)) == id
			refs.Items.Text = wearing(short("Aura", aura), short("Trail", trail))
			refs.Title.Text = (here and "REMOVE " or "SLOT ") .. slot
			refs.Button.BackgroundColor3 = here and HERE or FREE
		end
	end
	return picker
end

-- True when `id` is on any team slot.
function SlotPicker.Equipped(kind, id)
	for slot = 1, Market.SLOTS do
		if isHere(kind, slot, id) then
			return true
		end
	end
	return false
end

-- The Team after putting character `id` on `slot` (nil id: take that slot's character off). A character already on
-- another slot swaps places with the one there; gaps close up; an empty Team gives nil (nothing to send).
function SlotPicker.TeamWith(slot, id)
	local team = SlotPicker.Team()
	local list = {}
	for i = 1, Market.SLOTS do
		list[i] = team[i] ~= "" and team[i] or nil
	end
	if id == nil then
		list[slot] = nil
	else
		for i = 1, Market.SLOTS do -- not table.find: list may have holes
			if list[i] == id then
				list[i] = list[slot]
			end
		end
		list[slot] = id
	end
	local out = {}
	for i = 1, Market.SLOTS do
		if list[i] then
			table.insert(out, list[i])
		end
	end
	return #out > 0 and out or nil
end

return SlotPicker
