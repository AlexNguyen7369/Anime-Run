--!nonstrict
-- A character's card as the Backpack Characters tab and the Team panel's roster draw it (design doc 4.22 collection
-- card, 4.42 anime look): the card face and art, a Badge line ("TEAM n" in green on a Team member), its cruise and its
-- name, sized in an AnimeSkin.IndexFrame's units (g). Display only: the caller wires the press. Owned() lists the owned
-- characters in the chosen sort.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(shared:WaitForChild("CharacterCatalog"))
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local RaceConfig = require(shared:WaitForChild("RaceConfig"))
local StaminaConfig = require(shared:WaitForChild("StaminaConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local Components = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("RacerComponents"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local SlotPicker = require(script.Parent:WaitForChild("SlotPicker"))

local GREEN = UiTheme.Palette.Money
local GOLD = UiTheme.Palette.Unbanked
local OUTLINE = UiTheme.Outline
local U = AnimeSkin.Units
local DOT_CLEAR = 8 + 24 + 6 -- px from the card's right edge: the category dot's inset and size, then a gap

local RosterCard = {}
RosterCard.Sorts = { "Rarity", "Speed", "Stamina" }
RosterCard.Line = 28 -- a Body line in a card
RosterCard.SmallLine = 22 -- a Caption line in a card

local function caption(name, parent, props)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	for key, value in props do
		label[key] = value
	end
	label.Parent = parent
	return label
end

local rarityRank = {}
for i, rarity in GachaConfig.RARITY_ORDER do
	rarityRank[rarity] = i
end
-- The owned characters: by `sortMode` (one of Sorts) highest first, else least rare first, then catalog order.
-- `everyOwned` (the Team panel) also lists owned ids outside the Index (starter picks, the exclusive): SetTeam takes them.
function RosterCard.Owned(player, sortMode, everyOwned)
	local data = player:FindFirstChild("GachaData")
	local list = {}
	for _, spec in CharacterCatalog.All() do
		if data and data:FindFirstChild(spec.Id) then
			table.insert(list, spec)
		end
	end
	for _, entry in everyOwned and data and data:GetChildren() or {} do
		local spec = CharacterCatalog.Get(entry.Name)
		if spec and not table.find(list, spec) then
			table.insert(list, spec)
		end
	end
	local function value(spec)
		return sortMode == "Speed" and RaceConfig.Cruise(spec)
			or sortMode == "Stamina" and StaminaConfig.Seconds(spec)
			or 0
	end
	table.sort(list, function(a, b)
		local va, vb = value(a), value(b)
		if va ~= vb then
			return va > vb
		end
		local ra, rb = rarityRank[a.Rarity] or 99, rarityRank[b.Rarity] or 99
		if ra ~= rb then
			return ra < rb
		end
		if (a.Order or 0) ~= (b.Order or 0) then
			return (a.Order or 0) < (b.Order or 0)
		end
		return a.Id < b.Id
	end)
	return list
end

-- A card's art tint (design doc 4.42): white when picked, else its rarity (Secret's black would not read: white, as the Index).
function RosterCard.Tint(spec, picked)
	if picked or spec.Rarity == "Secret" then
		return Color3.new(1, 1, 1)
	end
	return GachaConfig.RARITY_COLORS[spec.Rarity] or AnimeSkin.Tint.Default
end

-- The card for `spec` in `parent` at LayoutOrder `order`, named its id; `picked` draws it white, `note` fills the Badge
-- line of a character off the Team. Returns the card and its Team slot (nil off the Team).
function RosterCard.new(parent, spec, order, g, picked, note)
	local b = Instance.new("TextButton")
	b.Name = spec.Id
	b.LayoutOrder = order
	b.Text = ""
	b.AutoButtonColor = false
	b.Parent = parent
	Components.CardFace(b, spec, GachaConfig)
	local slot = table.find(SlotPicker.Team(), spec.Id)
	local edge = Instance.new("UIStroke")
	edge.Name = "Stroke"
	edge.Color = picked and Color3.new(1, 1, 1) or slot and GREEN or OUTLINE
	edge.Thickness = 3
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = b
	AnimeSkin.Card(b, RosterCard.Tint(spec, picked))
	b.Rim.Visible = false -- the card art carries the rarity, as in the Index
	b:SetAttribute("SearchName", spec.Name)
	Components.CardArt(b, spec)
	local badge = g.Role(
		caption("Badge", b, {
			Position = g.at(U.Pad, U.Inner),
			-- Clear of the category dot (CardFace: 24 px, 8 px in from the top-right, in px at every scale) by 6 px
			Size = UDim2.new(1, -(g.px(U.Pad) + DOT_CLEAR), 0, g.px(RosterCard.Line)),
			Text = slot and ("TEAM " .. slot) or note or "",
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
		}),
		"Body"
	)
	badge.TextColor3 = slot and GREEN or GOLD
	g.Role(
		caption("Multi", b, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -g.px(U.Pad), 1, -g.px(U.Inner + 30)),
			Size = UDim2.new(0.4, -g.px(U.Pad), 0, g.px(RosterCard.SmallLine)),
			Text = HudFormat.RateText(RaceConfig.Cruise(spec)),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 7,
		}),
		"Caption"
	).TextColor3 =
		GOLD
	g.Role(
		caption("Name", b, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -g.px(U.Pad), 1, -g.px(U.Inner)),
			Size = UDim2.new(1, -g.px(2 * U.Pad), 0, g.px(30)),
			Text = spec.Name,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 7,
		}),
		"Item"
	)
	return b, slot
end

return RosterCard
