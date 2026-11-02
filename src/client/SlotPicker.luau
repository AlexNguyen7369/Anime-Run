--!nonstrict
-- Team slot picker for auras and trails (design doc 4.13: one aura and one trail per team slot). Three slot buttons,
-- each showing that slot's aura and trail; tapping one puts the shown item on that slot, or takes it off when it is
-- already there (Remotes.MarketEquip(kind, id or nil, slot)). The server decides; this only shows Slot<n>Aura /
-- Slot<n>Trail. Shared by the Market detail pane and the Backpack.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local Market = require(shared:WaitForChild("MarketConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))

local OUTLINE = UiTheme.Outline
local FREE = Color3.fromRGB(60, 220, 90) -- the slot takes the item (the Market's EQUIP green)
local HERE = Color3.fromRGB(55, 110, 180) -- the item is on this slot: tapping removes it

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

local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = UiTheme.Font
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextScaled = true
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round })
	return label
end

-- Short item name for the slot line ("Azure Aura" -> "Azure"), "-" for an empty slot.
local function short(kind, id)
	local item = Market.Get(kind, id)
	if not item then
		return "-"
	end
	return (string.gsub(item.Name, "%s+" .. kind .. "$", ""))
end

-- A Frame named `name` under `parent` with `props`; onPick(slot, id) gets the tapped slot and the id to send (nil =
-- take it off). Call :Update(kind, id) with the item the screen shows (id nil: nothing picked yet).
function SlotPicker.new(name, parent, props, onPick)
	local frame = make("Frame", name, parent, props)
	frame.BackgroundTransparency = 1
	make("UIListLayout", "Layout", frame, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local picker = { Frame = frame, Buttons = {}, Kind = nil, Id = nil }
	for slot = 1, Market.SLOTS do
		local b = make("TextButton", "Slot" .. slot, frame, {
			LayoutOrder = slot,
			Size = UDim2.new(1 / Market.SLOTS, -4, 1, 0),
			BackgroundColor3 = FREE,
			Text = "",
			AutoButtonColor = true,
		})
		UiTheme.Corner(b, "S")
		make("UIStroke", "Stroke", b, { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		UiTheme.Gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185))
		local title = caption("Title", b, {
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.new(1, -8, 0.5, -2),
			Text = "SLOT " .. slot,
		})
		local items = caption("Items", b, {
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.new(1, -8, 0.5, -3),
			Text = "",
			TextColor3 = Color3.fromRGB(235, 240, 255),
		})
		picker.Buttons[slot] = { Button = b, Title = title, Items = items }
		b.Activated:Connect(function()
			if not (picker.Kind and picker.Id) then
				onPick(slot, nil, false)
				return
			end
			local here = player:GetAttribute(Market.SlotAttribute(slot, picker.Kind)) == picker.Id
			onPick(slot, if here then nil else picker.Id, true)
		end)
	end
	function picker:Update(kind, id)
		self.Kind, self.Id = kind, id
		for slot, refs in self.Buttons do
			local aura = player:GetAttribute(Market.SlotAttribute(slot, "Aura"))
			local trail = player:GetAttribute(Market.SlotAttribute(slot, "Trail"))
			local here = id ~= nil and player:GetAttribute(Market.SlotAttribute(slot, kind)) == id
			refs.Items.Text = short("Aura", aura) .. " / " .. short("Trail", trail)
			refs.Title.Text = (here and "REMOVE " or "SLOT ") .. slot
			refs.Button.BackgroundColor3 = here and HERE or FREE
		end
	end
	return picker
end

-- True when `id` is on any team slot.
function SlotPicker.Equipped(kind, id)
	for slot = 1, Market.SLOTS do
		if player:GetAttribute(Market.SlotAttribute(slot, kind)) == id then
			return true
		end
	end
	return false
end

return SlotPicker
