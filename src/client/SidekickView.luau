--!nonstrict
-- What the Sidekick screens share (design doc 4.36): the server's published state, decoded, and the one art function.
-- Display only; nothing here decides a number.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))

local SidekickView = {}

-- Same landing cues as the character roll (Client/RollToast).
SidekickView.LAND_CUES = {
	Common = "RollLand1",
	Uncommon = "RollLand1",
	Rare = "RollLand2",
	Epic = "RollLand3",
	Legendary = "RollLand4",
	Mythic = "RollLand5",
	Secret = "RollSecret",
}

local function decode(player, attribute)
	local text = player:GetAttribute(attribute)
	local ok, value = pcall(HttpService.JSONDecode, HttpService, type(text) == "string" and text or "{}")
	return ok and type(value) == "table" and value or {}
end

function SidekickView.Bag(player)
	return decode(player, "SidekickBag") -- array of { Id, Entry }
end

function SidekickView.Gear(player)
	return decode(player, "SidekickGear") -- character id -> entry
end

function SidekickView.AutoSell(player)
	return decode(player, "SidekickAutoSell") -- rarity -> true
end

-- The Bag row of `entry`, or nil.
function SidekickView.Row(player, entry)
	for _, row in SidekickView.Bag(player) do
		if row.Entry == entry then
			return row
		end
	end
	return nil
end

function SidekickView.RarityColor(rarity)
	return GachaConfig.RARITY_COLORS[rarity] or UiTheme.Palette.Muted
end

-- "+8% cruise", "+3% cruise, +3% stamina".
function SidekickView.GainText(row)
	local parts = {}
	if row.Cruise > 0 then
		table.insert(parts, string.format("+%d%% cruise", math.round(row.Cruise * 100)))
	end
	if row.Stamina > 0 then
		table.insert(parts, string.format("+%d%% stamina", math.round(row.Stamina * 100)))
	end
	return table.concat(parts, ", ")
end

-- shortcut: a plain rarity tile with the name, because the portraits are not uploaded; when they are, draw the portrait here
-- and every Sidekick screen follows.
-- row nil: an id this version does not know. Centred on `position`. Returns the tile, with its name in .Label.
function SidekickView.Art(parent, row, position, size)
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = position
	art.Size = size
	art.ZIndex = 3
	art.BorderSizePixel = 0
	art.BackgroundColor3 = Color3.new(1, 1, 1)
	UiTheme.Corner(art, "S")
	UiTheme.Gradient(art, SidekickView.RarityColor(row and row.Rarity), UiTheme.Palette.PanelDeep)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.06, 0.25)
	label.Size = UDim2.fromScale(0.88, 0.5)
	label.Font = UiTheme.Font
	label.Text = row and row.Name or "?"
	label.TextColor3 = UiTheme.Palette.White
	label.TextScaled = true
	label.ZIndex = 4
	UiTheme.Stroke(label, 2, UiTheme.Outline)
	label.Parent = art
	art.Parent = parent
	return art
end

return SidekickView
