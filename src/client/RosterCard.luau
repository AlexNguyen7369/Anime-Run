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
local RelicConfig = require(shared:WaitForChild("RelicConfig"))
local SidekickArt = require(shared:WaitForChild("SidekickArt"))
local SidekickConfig = require(shared:WaitForChild("SidekickConfig"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local UiTooltip = require(script.Parent:WaitForChild("UiTooltip"))

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

-- The bag row's catalog row for character `id`'s worn relic or Sidekick (nil when it wears none).
local function worn(bag, gear, id, get)
	local entry = gear[id]
	for _, row in entry and bag or {} do
		if row.Entry == entry then
			return get(row.Id)
		end
	end
	return nil
end

local function bonusText(bonuses)
	local parts = {}
	for stat, value in bonuses or {} do
		table.insert(parts, string.format("+%d%% %s", math.round(value * 100), stat))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

-- Design doc 4.45 (owner 2026-11-17): the relic emblem (a diamond with a rarity rim) and the Sidekick icon (a circle with
-- a cream rim, its drawn portrait) character `id` wears, in a Gear frame at `parent`'s top-right (y px down, icon
-- `size` px); a tooltip names each. Replaces an existing Gear. Returns the frame.
function RosterCard.Gear(parent, id, player, y, size)
	local old = parent:FindFirstChild("Gear")
	if old then
		old:Destroy()
	end
	size = size or 20
	local relic = worn(SidekickView.RelicBag(player), SidekickView.RelicGear(player), id, RelicConfig.Get)
	local sidekick = worn(SidekickView.Bag(player), SidekickView.Gear(player), id, SidekickConfig.Get)
	local frame = Instance.new("Frame")
	frame.Name = "Gear"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -6, 0, y or 34)
	frame.Size = UDim2.fromOffset(2 * size + 6, size)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 8
	frame.Parent = parent
	local function icon(name, row, image, x, round, rim)
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.BackgroundColor3 = UiTheme.Dojo.Ink
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.new(0, x + size / 2, 0.5, 0)
		holder.Size = UDim2.fromOffset(round and size or size * 0.78, round and size or size * 0.78)
		holder.Rotation = round and 0 or 45 -- a diamond for relics
		holder.ZIndex = 8
		holder.Active = true
		holder.Selectable = true
		holder:SetAttribute("ItemName", row.Name)
		holder:SetAttribute("Rarity", row.Rarity)
		holder.Parent = frame
		local edge = Instance.new("UIStroke")
		edge.Thickness, edge.Color = UiTheme.Dojo.Stroke, rim
		edge.Parent = holder
		if round then
			UiTheme.Corner(holder, 999)
		end
		local art = Instance.new("ImageLabel")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.Image = image or ""
		art.ScaleType = Enum.ScaleType.Fit
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.fromScale(0.5, 0.5)
		art.Size = UDim2.fromScale(round and 1 or 1.2, round and 1 or 1.2)
		art.Rotation = round and 0 or -45
		art.ZIndex = 9
		art.Parent = holder
		if round then
			UiTheme.Corner(art, 999)
		end
		return holder
	end
	if relic then
		local h = icon("Relic", relic, relic.Image, 0, false, GachaConfig.RARITY_COLORS[relic.Rarity] or GOLD)
		UiTooltip.Bind(h, function()
			return { Title = relic.Name, Rarity = relic.Rarity, Body = "Relic: " .. bonusText(relic.Bonuses) }
		end)
	end
	if sidekick then
		local art = SidekickArt[sidekick.Id]
		local h = icon("Sidekick", sidekick, art and art.Portrait, size + 6, true, UiTheme.Dojo.Cream)
		UiTooltip.Bind(h, function()
			return {
				Title = sidekick.Name,
				Rarity = sidekick.Rarity,
				Body = "Sidekick: " .. SidekickView.GainText(sidekick),
			}
		end)
	end
	return frame
end

return RosterCard
