--!nonstrict
-- What the Sidekick screens share (design doc 4.36): the server's published state, decoded, and the one art function.
-- Display only; nothing here decides a number.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local SidekickArt = require(shared:WaitForChild("SidekickArt"))
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

function SidekickView.RelicBag(player)
	return decode(player, "RelicBag") -- array of { Id, Entry }
end

function SidekickView.RelicGear(player)
	return decode(player, "RelicGear") -- character id -> entry
end

function SidekickView.Rotation()
	return decode(ReplicatedStorage, "SidekickRotation") -- { Ids, SecretChoices, SecretId, EndsAt }; {} before the server publishes
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

-- The drawn portrait on its rarity colour, for the Bag (design doc 4.36). row nil: an id this version does not know; it and a
-- row with no portrait show the name in .Label instead. Centred on `position`. Returns the ImageLabel.
function SidekickView.Art(parent, row, position, size)
	local portrait = row and (row.Image or (SidekickArt[row.Id] and SidekickArt[row.Id].Portrait))
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.Image = portrait or ""
	art.ScaleType = Enum.ScaleType.Fit
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = position
	art.Size = size
	art.ZIndex = 3
	art.BorderSizePixel = 0
	UiTheme.Corner(art, "S")
	if portrait then
		-- A plain fill: a UIGradient would tint the image too.
		art.BackgroundColor3 = SidekickView.RarityColor(row.Rarity):Lerp(UiTheme.Palette.PanelDeep, 0.4)
	else
		art.BackgroundColor3 = Color3.new(1, 1, 1)
		UiTheme.Gradient(art, SidekickView.RarityColor(row and row.Rarity), UiTheme.Palette.PanelDeep)
	end
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.06, 0.25)
	label.Size = UDim2.fromScale(0.88, 0.5)
	label.Font = UiTheme.Font
	label.Text = row and row.Name or "?"
	label.Visible = not portrait
	label.TextColor3 = UiTheme.Palette.White
	label.TextScaled = true
	label.ZIndex = 4
	UiTheme.Stroke(label, 2, UiTheme.Outline)
	label.Parent = art
	art.Parent = parent
	return art
end

return SidekickView
