--!nonstrict
-- The boss rewards popup (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Rewards"). Contract: Client/UiTest/UiBossPhase2. Display only: the
-- server already paid; this shows RunEvent's BossRewards once the player is out of the event, and leaves the way for any open panel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local BossCatalog = require(shared:WaitForChild("BossCatalog"))
local Cfg = require(shared:WaitForChild("BossEventConfig"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local RelicConfig = require(shared:WaitForChild("RelicConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local Palette = UiTheme.Palette
local Icons = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

-- R1 "Victory banner" (BOSS_EVENT_SPEC "Rewards", owner 2026-11-10). Proposed: sizes in the Index frame's units, rows
-- for its 374 unit tall content area (scaled to the area it gets), and the count-up time.
local WIDTH = 640 * AnimeSkin.Units.W / 920 -- px at most: the old 640 at 920 units wide, so the height stays as before
local COUNT_SECONDS = 1.2
local ROWS = { Caption = 40, Damage = 72, Bar = 24, Note = 28 } -- with 8 under the caption and 12 between the others
local CARD_W = 200
local RAGA_CHEST, ADAPTED_CHEST = "relic_chest_raga", "relic_chest_adapted"
local SHARE_MARK = Color3.fromRGB(235, 20, 30)

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
	props.TextColor3 = props.TextColor3 or Palette.White
	return make("TextLabel", name, parent, props)
end

local root = make("ScreenGui", "RacerBossRewards", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	DisplayOrder = 62, -- above every panel and popup the return may open
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1,
	Active = true,
	Visible = false,
})
local header = make("Frame", "Header", panel, { BackgroundTransparency = 1, BorderSizePixel = 0 })
-- Title keeps the server's words for the UI tests (UiBossPhase2 reads them exactly); Heading shows them in the standard
-- header's ALL CAPS, as AnimeSkin.Tab's caption does.
local title = make("TextLabel", "Title", header, {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(0, 0),
	Text = "",
	TextTransparency = 1,
})
local heading = make("TextLabel", "Heading", header, { Text = "" })
title:GetPropertyChangedSignal("Text"):Connect(function()
	heading.Text = title.Text
end)
local logo = make("ImageLabel", "Logo", header, {})
local closeButton = make("TextButton", "CloseButton", header, { Text = "" })
-- Design doc 4.42 and 4.40: the Index frame with the Boss icon as its logo, the ALL CAPS title and the art close.
local g = AnimeSkin.IndexFrame(
	panel,
	{ Header = header, Title = heading, Icon = logo, Logo = Icons.Boss.Image, Close = closeButton }
)
local caption = label("DamageCaption", panel, { Text = "TOTAL DAMAGE" })
local damage = label("Damage", panel, { Text = "" })
local shareBar =
	make("Frame", "ShareBar", panel, { BackgroundColor3 = Color3.fromRGB(20, 24, 44), BorderSizePixel = 0 })
make("UICorner", "Round", shareBar, { CornerRadius = UDim.new(0.5, 0) })
make("UIStroke", "Edge", shareBar, { Color = AnimeSkin.Ink, Thickness = 2 })
local shareFill = make("Frame", "Fill", shareBar, {
	BackgroundColor3 = AnimeSkin.Tint.Gold,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(0, 1),
})
make("UICorner", "Round", shareFill, { CornerRadius = UDim.new(0.5, 0) })
make("Frame", "Mark", shareBar, { -- the share that pays (BossEventConfig.MinDamageShare)
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(Cfg.MinDamageShare, 0.5),
	Size = UDim2.new(0, 4, 1, 8),
	BackgroundColor3 = SHARE_MARK,
	BorderSizePixel = 0,
	ZIndex = 2,
})
local shareText = label("Share", panel, { Text = "", TextXAlignment = Enum.TextXAlignment.Right })
local rewards = make("Frame", "Rewards", panel, { BackgroundTransparency = 1 })
-- One angular card per reward; each part stays directly in Rewards (UiBossPhase2 reads Rewards/<part>), above its card.
local function card(order)
	local frame = make("Frame", "Card" .. order, rewards, { BackgroundTransparency = 1, ZIndex = 1 })
	AnimeSkin.Card(frame, order % 2 == 1 and AnimeSkin.Tint.Gold or AnimeSkin.Tint.Default)
	return frame
end
local function chestArt(id)
	return make("ImageLabel", "Chest_" .. id, rewards, {
		BackgroundTransparency = 1,
		Image = RelicConfig.Chests[id].Image,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	})
end
local money = label("Money", rewards, { Text = "$" .. HudFormat.Commas(Cfg.Phase1Money), ZIndex = 3 })
local gems = label("Gems", rewards, { Text = HudFormat.Commas(Cfg.Phase2Gems), ZIndex = 3 })
local gemPad = make("UIPadding", "Padding", gems, {})
local gemIcon = make("ImageLabel", "Icon", gems, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	BackgroundTransparency = 1,
	Image = Icons.Gem.Image,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 3,
})
local cards = { -- in order: the part on the card, and whether it is art (square) or an amount
	{ Card = card(1), Part = chestArt(RAGA_CHEST), Art = true },
	{ Card = card(2), Part = money },
	{ Card = card(3), Part = chestArt(ADAPTED_CHEST), Art = true },
	{ Card = card(4), Part = gems },
}
local note = label("Note", panel, { Text = "Deal 5% for rewards" })

-- The popup's px size keeps the frame's aspect and its chrome on screen; k follows from it.
local function size()
	local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local U = AnimeSkin.Units
	local w, h = AnimeSkin.Compact() and U.PhoneW or U.W, AnimeSkin.Compact() and U.PhoneH or U.H
	local width = math.min(WIDTH, (view.X - 32) * w / (w + 80), (view.Y - 32) * w / (h + 100))
	panel.Size = UDim2.fromOffset(math.floor(width), math.floor(width * h / w))
end
size()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(size)
end
-- Top down in the content area: TOTAL DAMAGE (Section), the count (Title), the share bar with the share right of it,
-- the shown cards centred in a row, the note (Body) at the bottom.
local function layout()
	local c, U = g.Content, AnimeSkin.Units
	local s = c.H / 374
	local y = c.Y
	g.Place(caption, c.X, y, c.W, ROWS.Caption * s)
	y += (ROWS.Caption + 8) * s
	g.Place(damage, c.X, y, c.W, ROWS.Damage * s)
	y += (ROWS.Damage + U.Gap) * s
	local shareW = 160
	g.Place(shareBar, c.X, y, c.W - shareW - U.Gap, ROWS.Bar * s)
	g.Place(shareText, c.X + c.W - shareW, y - 4, shareW, ROWS.Bar * s + 8)
	y += (ROWS.Bar + U.Gap) * s
	local noteH = ROWS.Note * s
	local cardsH = c.Y + c.H - noteH - U.Gap * s - y
	g.Place(rewards, c.X, y, c.W, cardsH)
	g.Place(note, c.X, c.Y + c.H - noteH, c.W, noteH)
	local shown = {}
	for _, entry in cards do
		if entry.Part.Visible then
			table.insert(shown, entry)
		end
	end
	local n = math.max(1, #shown)
	local w = math.min(CARD_W, (c.W - (n - 1) * U.Gap) / n)
	local x = (c.W - n * w - (n - 1) * U.Gap) / 2
	for _, entry in cards do
		entry.Card.Visible = entry.Part.Visible
	end
	for _, entry in shown do
		g.Place(entry.Card, x, 0, w, cardsH)
		local side = math.min(w, cardsH) - 2 * U.Pad
		if entry.Art then
			g.Place(entry.Part, x + (w - side) / 2, (cardsH - side) / 2, side, side)
		else
			g.Place(
				entry.Part,
				x + U.Pad,
				(cardsH - AnimeSkin.UnitSize.Item) / 2,
				w - 2 * U.Pad,
				AnimeSkin.UnitSize.Item
			)
		end
		x += w + U.Gap
	end
	local item = AnimeSkin.UnitSize.Item
	gemPad.PaddingLeft = UDim.new(0, g.px(item))
	gemIcon.Size = g.at(item, item)
	g.Role(caption, "Section")
	g.Role(damage, "Title")
	g.Role(shareText, "Item")
	g.Role(money, "Item")
	g.Role(gems, "Item")
	g.Role(note, "Body")
	money.TextColor3 = Palette.Money -- the game's cash green over the Item white
end
g.OnLayout(layout)

local message = nil -- what waits to show, or shows
local seen = false -- it has been on screen: the next event takes it away

local function close()
	message, seen = nil, false
end
closeButton.Activated:Connect(close)
PanelFrame.CloseOnOutsideClick(panel, close)

local total, share = 0, nil -- the message's damage, and its share of the phase's HP (0..1) when it holds one
local countAt = nil -- os.clock() the count-up started, while it runs
local function count(f)
	damage.Text = HudFormat.Commas(math.floor(total * f + 0.5))
	shareFill.Size = UDim2.fromScale(math.clamp((share or 0) * f, 0, 1), 1)
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RunEvent").OnClientEvent:Connect(function(ev)
	if type(ev) ~= "table" or ev.Kind ~= "BossRewards" then
		return
	end
	message, seen = ev, false
	title.Text = ev.Outcome == "Survived" and "Fully Adapted Raga survived" or BossCatalog.Get(ev.Boss).DefeatedTitle
	total, share, countAt = tonumber(ev.Damage) or 0, tonumber(ev.Share), nil
	count(1)
	-- Share: of the phase this popup reports (owner 2026-11-10); a message without one hides the bar
	shareBar.Visible, shareText.Visible = share ~= nil, share ~= nil
	shareText.Text = share and string.format("%.1f%%", share * 100) or ""
	cards[1].Part.Visible, money.Visible = ev.Stage1 == true, ev.Stage1 == true
	cards[3].Part.Visible, gems.Visible = ev.Stage2 == true, ev.Stage2 == true
	rewards.Visible = ev.Stage1 == true or ev.Stage2 == true
	note.Visible = ev.Short == true
	layout()
end)

RunService.Heartbeat:Connect(function()
	local inEvent = player:GetAttribute("BossEvent") == true
	if inEvent and seen then
		close()
	end
	local show = message ~= nil and not inEvent -- above any panel the return opens, such as Daily
	seen = seen or show
	if show and not panel.Visible then
		UiMotion.Pop(panel)
		UiFeedback.Play("ToastHigh")
		countAt = os.clock()
	end
	if countAt then
		local f = math.min(1, (os.clock() - countAt) / COUNT_SECONDS)
		count(f)
		countAt = f < 1 and countAt or nil
	end
	panel.Visible = show
	root.Enabled = show -- never above the showcase or loser screens while closed
end)
