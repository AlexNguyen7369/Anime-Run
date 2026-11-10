--!nonstrict
-- The Sidekicks summon page (design doc 4.36, docs/SIDEKICK_SPEC.md "Summon page"), opened at the plaza stall. Header: Gem
-- balance, rotation timer, Mythic Pity. Main: the poster (Mythic, Legendaries and Rares in one view, with rates), the cost,
-- Auto-Sell, Summon 1x and 10x. GemColumn: gem bundles (ProductId 0: "Coming soon"; otherwise a press invokes GemPackBuy). Details shows every outcome's odds before
-- any spend (section 6) and the Secrets' silhouettes. Client/SidekickReveal plays results. The gacha look is this page's alone
-- (owner 2026-11-05). The server decides every result.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(shared:WaitForChild("SidekickConfig"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local Monetization = require(shared:WaitForChild("MonetizationConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local SidekickReveal = require(script.Parent:WaitForChild("SidekickReveal"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local Ui = script.Parent:WaitForChild("RollToast"):WaitForChild("Ui")
local Icons = require(Ui.HudIcons)

local PALETTE = UiTheme.Palette
local OUTLINE = UiTheme.Outline
local BLACK = Color3.new(0, 0, 0)
local NEAR_BLACK = Color3.fromRGB(10, 10, 18)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 110)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 90)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 255, 150)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(100, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 120, 255)),
})
local MODEL_VIEW_DIR = Vector3.new(0.45, 0.15, -1).Unit -- from the model to the camera, as Client/StarterPick
local MODEL_LIGHT_DIR = Vector3.new(-1, -2, -1)
local TURN_SPEED = math.rad(30) -- radians per second (placeholder)
local MODEL_SWAY = math.rad(12) -- how far the view swings either way from the front (placeholder)
local RAY_SPEED, EDGE_SPEED = 6, 50 -- degrees per second (placeholders)
local ROTATION_SECONDS = 1800 -- design doc 4.36: only the timer bar's fill reads this; EndsAt comes from the server
-- shortcut: 300 and 100 are shown here until SidekickService and SidekickConfig land them (the boss event session is building pity).
local PITY_COUNT = Config.PityCount or 300
local LEGENDARY_PITY_COUNT = Config.LegendaryPityCount or 100
-- Poster: Mythic centred, Legendaries beside it, Rares at the ends, each further back. Side and Back in model heights, Height a
-- share of POSTER_HEIGHT, X and Width the name column in the poster. Rows come Mythic, Legendaries, Rares.
local POSTER_HEIGHT = 4
local POSTER_SLOTS = {
	{ Side = 0, Back = 0, Height = 1, X = 0.385, Width = 0.23, NameSize = 32, RateSize = 20 },
	{ Side = -0.62, Back = 0.25, Height = 0.76, X = 0.19, Width = 0.195, NameSize = 24, RateSize = 16 },
	{ Side = 0.62, Back = 0.25, Height = 0.76, X = 0.615, Width = 0.195, NameSize = 24, RateSize = 16 },
	{ Side = -1.2, Back = 0.5, Height = 0.6, X = 0, Width = 0.19, NameSize = 20, RateSize = 14 },
	{ Side = 1.2, Back = 0.5, Height = 0.6, X = 0.81, Width = 0.19, NameSize = 20, RateSize = 14 },
}

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
	props.TextColor3 = props.TextColor3 or PALETTE.White
	props.TextScaled = true
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round })
	make("UITextSizeConstraint", "Max", label, { MaxTextSize = props.TextSize or 20 })
	return label
end
-- The Index frame (design doc 4.42) that PanelFrame.Attach gives the panel, below: every size is in its units.
local g
-- Labels by text role (design doc 4.42); OnLayout sizes them again at the frame's scale. color: a rarity or gold
-- caption. Weak keys: rows come and go.
local roles = setmetatable({}, { __mode = "k" })
local function role(label, name, color)
	roles[label] = { name, color }
	label.TextWrapped = false
	g.Role(label, name)
	if color then
		label.TextColor3 = color
	end
	return label
end
-- Design doc 4.42: the Index's action button (AnimeSkin tone, default Idle): flat fill, 4 px corners, white Item words
-- on one line, no dark edge. The Stroke stays (disabled) for the Auto-Sell toggles' state colour.
local function button(name, parent, props, text, tone)
	props.Text = ""
	props.AutoButtonColor = false
	local b = make("TextButton", name, parent, props)
	AnimeSkin.Button(b, tone or "Idle")
	make("UIStroke", "Stroke", b, {
		Color = OUTLINE,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Enabled = false,
	})
	local label = caption("Label", b, {
		Position = UDim2.fromScale(0.06, 0),
		Size = UDim2.fromScale(0.88, 1),
		Text = text,
	})
	role(label, "Item")
	return b
end
-- Rainbow rarity text is for Mythic and Secret; every other rarity keeps its one colour.
local function paintRarity(label, rarity)
	local rainbow = rarity == "Mythic" or rarity == "Secret"
	label.TextColor3 = rainbow and PALETTE.White or SidekickView.RarityColor(rarity)
	if rainbow then
		make("UIGradient", "Rainbow", label, { Color = RAINBOW })
	end
end
-- A slanted plate in the tabs row (design doc 4.42) with its Tab label; `fillColor` set: a thin bar of that colour
-- along its foot, inside the plate.
local function statusBar(name, parent, text, fillColor)
	local bar = make("Frame", name, parent, { BackgroundTransparency = 1 })
	AnimeSkin.Plate(bar, AnimeSkin.Tint.Default)
	local fill = fillColor
		and make("Frame", "Fill", bar, {
			BackgroundColor3 = fillColor,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
	role(
		caption("Label", bar, {
			Text = text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		}),
		"Tab"
	)
	return bar, fill
end

local root = make("ScreenGui", "RacerSidekicks", gui, {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(720, 420),
	Visible = false,
	Active = true,
})
PanelSwitch.Register("Sidekicks", panel)
local chrome = PanelFrame.Attach(panel, {
	Theme = "Sidekicks",
	Title = "Sidekicks",
	Icon = Icons.Gem.Image, -- HudIcons has no Sidekicks icon: the Gem is the logo
	MaxWidth = 760,
})
g = chrome.Frame
chrome.Close.Activated:Connect(function()
	PanelSwitch.Close("Sidekicks")
end)
PanelFrame.CloseOnOutsideClick(panel, function()
	PanelSwitch.Close("Sidekicks")
end)

local blur = make("BlurEffect", "SidekickSummonBlur", Lighting, { Size = 14, Enabled = false }) -- placeholder size

-- The tabs row (design doc 4.42): four 40 tall plates, Gems, the rotation timer and both pity counts. It stays a child
-- of the Header (the UI tests pin Header/StatusBlock); the Index frame collapses the Header to the panel's origin, so
-- the plates are placed in panel units.
local status = make("Frame", "StatusBlock", chrome.Header, { BackgroundTransparency = 1, Size = UDim2.new() })
local balance = statusBar("Balance", status, "GEMS")
make("ImageLabel", "GemIcon", balance, {
	BackgroundTransparency = 1,
	Image = Icons.Gem.Image,
	ScaleType = Enum.ScaleType.Fit,
	ZIndex = 2,
})
local gemsValue = role(
	caption("GemsValue", balance, {
		Text = "0",
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
	}),
	"Tab"
)
make("UIGradient", "Rainbow", gemsValue, { Color = RAINBOW })
local bars = make("Frame", "Bars", status, { BackgroundTransparency = 1, Size = UDim2.new() })
local function barValue(name, bar)
	return role(
		caption(name, bar, {
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 2,
		}),
		"Tab"
	)
end
local timerBar, timerFill = statusBar("TimerBar", bars, "ROTATION", Color3.fromRGB(60, 150, 240))
local rotationTimer = barValue("RotationTimer", timerBar)
local pityBar, pityFill = statusBar("PityBar", bars, "MYTHIC", SidekickView.RarityColor("Mythic"))
local pityValue = barValue("Value", pityBar)
local legendaryBar, legendaryFill =
	statusBar("LegendaryPityBar", bars, "LEGENDARY", SidekickView.RarityColor("Legendary"))
local legendaryPityValue = barValue("Value", legendaryBar)
-- Each plate's share of the row and its label's share of the plate, from the longest words at the Tab size, so all
-- four plates scale their text alike. Fill: the bar's share, set by refresh / showTimer.
local plates = {
	{ Frame = balance, Row = 0.22, Label = 0.42, Value = gemsValue, Icon = balance.GemIcon },
	{ Frame = timerBar, Row = 0.26, Label = 0.55, Value = rotationTimer, Fill = timerFill, Share = 1 },
	{ Frame = pityBar, Row = 0.24, Label = 0.5, Value = pityValue, Fill = pityFill, Share = 0 },
	{ Frame = legendaryBar, Row = 0.28, Label = 0.58, Value = legendaryPityValue, Fill = legendaryFill, Share = 0 },
}
local function placeFill(entry)
	local w = entry.W or 0
	g.Place(entry.Fill, 24, 32, math.max(0, (w - 48) * math.clamp(entry.Share, 0, 1)), 4)
end

-- The content area (design doc 4.42): Main on the left 56%, the gem packs on the right, 12 apart.
local body = make("Frame", "Body", panel, { BackgroundTransparency = 1 })

-- More Gems: whole bundle cards, biggest first.
local gemColumn = make("Frame", "GemColumn", body, { BackgroundTransparency = 1 })
local gemHeading = role(
	caption("Heading", gemColumn, {
		Text = "MORE GEMS",
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
	"Section"
)
-- 4 px padding keeps the cards' art edge (3 px) inside the clip.
local PACK_PAD = 4
local packs = make("ScrollingFrame", "Packs", gemColumn, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
local packLayout = make("UIListLayout", "Layout", packs, {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
})
make("UIPadding", "Padding", packs, {
	PaddingTop = UDim.new(0, PACK_PAD),
	PaddingBottom = UDim.new(0, PACK_PAD),
})
local smallest = Monetization.GemPacks[1]
for order, pack in Monetization.GemPacks do
	local tile = make("Frame", pack.Id, packs, {
		LayoutOrder = -order,
		BackgroundColor3 = PALETTE.White,
	})
	AnimeSkin.Card(tile, AnimeSkin.Tint.Default)
	make("ImageLabel", "GemArt", tile, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		Image = Icons.Gem.Image,
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Fit,
	})
	-- Three lines, 12 in from the card's edges: name and ribbon, the Gems, then "Coming soon" and the price.
	role(caption("Name", tile, { Text = pack.Name, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }), "Item")
	local gems = role(caption("Gems", tile, { Text = "+" .. HudFormat.Short(pack.Gems), ZIndex = 2 }), "Item")
	make("UIGradient", "Rainbow", gems, { Color = RAINBOW })
	role(
		caption("Soon", tile, { Text = "Coming soon", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }),
		"Caption"
	)
	role(
		caption("Price", tile, {
			Text = pack.RobuxPrice .. " R$",
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 2,
		}),
		"Body"
	)
	-- Rounded down, so a badge never overstates: computed from the listed prices.
	local bonus = math.floor(((pack.Gems / pack.RobuxPrice) / (smallest.Gems / smallest.RobuxPrice) - 1) * 100)
	if bonus > 0 then
		role(
			caption("Ribbon", tile, {
				Text = string.format("+%d%% More!", bonus),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 3,
			}),
			"Caption",
			AnimeSkin.Color.Section
		)
	end
end
-- One pack card's parts, 12 padding, 8 between lines; w, h in units.
local function placePack(tile, w, h)
	local inner = w - 24
	g.Place(tile:FindFirstChild("Name"), 12, 12, inner * 0.55, 34) -- tile.Name is the property
	if tile:FindFirstChild("Ribbon") then
		g.Place(tile.Ribbon, 12 + inner * 0.55 + 8, 12, inner * 0.45 - 8, 22)
	end
	g.Place(tile.Gems, 12, (h - 34) / 2, inner, 34)
	g.Place(tile.Soon, 12, h - 12 - 22, inner * 0.5, 22)
	g.Place(tile.Price, 12 + inner * 0.5, h - 12 - 28, inner * 0.5, 28)
end

-- Main, top down: the poster, 12, the cost line (Caption), 8, the summon row (44), 12 above the content's foot.
local main = make("Frame", "Main", body, {
	BackgroundTransparency = 1,
})
local banner = make("Frame", "Banner", main, {
	BackgroundTransparency = 1,
})

-- The actual 3D models (owner 2026-11-05). The poster and the Secrets in Details: one Heartbeat turns them all.
local views = {} -- ViewportFrame -> { Row or Rows, Focus, Distance }
local turnAngle = 0
local edgeTurn = 0 -- the poster edge's rainbow, in degrees
local turning = nil

-- The camera sways around the front, so the model always faces the player, and the light follows it.
local function aimView(view, spot)
	local turn = CFrame.Angles(0, math.sin(turnAngle) * MODEL_SWAY, 0)
	view.CurrentCamera.CFrame = CFrame.lookAt(spot.Focus + turn * MODEL_VIEW_DIR * spot.Distance, spot.Focus)
	view.LightDirection = turn * MODEL_LIGHT_DIR
end

-- All of a poster's models share one view, standing across the camera's width, so they overlap and share the light.
local function placePoster(view, spot, models)
	local across = CFrame.lookAt(MODEL_VIEW_DIR, Vector3.zero).RightVector
	for index, row in spot.Rows do
		local source = models:FindFirstChild(row.Id)
		local slot = POSTER_SLOTS[index]
		if source and slot then
			local model = source:Clone()
			local _, extents = model:GetBoundingBox()
			local wanted = POSTER_HEIGHT * slot.Height
			-- A wide flyer is sized by its span, so its wings do not fill the poster.
			model:ScaleTo(model:GetScale() * wanted / math.max(extents.Y, extents.X * 0.7, 0.01))
			local box, size = model:GetBoundingBox()
			local spot3 = across * slot.Side * POSTER_HEIGHT
				- MODEL_VIEW_DIR * slot.Back * POSTER_HEIGHT
				+ Vector3.new(0, size.Y / 2, 0)
			model:PivotTo(model:GetPivot() + spot3 - box.Position)
			model.Parent = view
		end
	end
	spot.Focus = Vector3.new(0, POSTER_HEIGHT * 0.42, 0)
	spot.Distance = POSTER_HEIGHT * 2.05
	aimView(view, spot)
end

local function turnViews(dt)
	local reduced = UiMotion.Reduced()
	if not reduced then
		edgeTurn = (edgeTurn + dt * EDGE_SPEED) % 360
		local posterEdge = banner:FindFirstChild("PosterEdge", true)
		if posterEdge then
			posterEdge.Rotation = edgeTurn
		end
		local rays = banner:FindFirstChild("Rays", true)
		if rays then
			rays.Rotation = (rays.Rotation + dt * RAY_SPEED) % 360
		end
	end
	if reduced and turnAngle == 0 then
		return
	end
	turnAngle = reduced and 0 or (turnAngle + dt * TURN_SPEED) % (2 * math.pi)
	for view, spot in views do
		if view:FindFirstChildOfClass("Model") then
			aimView(view, spot)
		end
	end
end
-- No model yet (not loaded, or panel closed): the tile keeps its name and stays empty.
local function fillViews()
	local models = ReplicatedStorage:FindFirstChild("SidekickModels")
	if not panel.Visible or not models or models:GetAttribute("Ready") ~= true then
		return
	end
	for view, spot in views do
		if not view:FindFirstChildOfClass("Model") then
			if spot.Rows then
				placePoster(view, spot, models)
			else
				local source = spot.Row and models:FindFirstChild(spot.Row.Id)
				if source then
					local model = source:Clone()
					model.Parent = view
					local box, extents = model:GetBoundingBox()
					spot.Focus = box.Position
					spot.Distance = 0.72 * extents.Magnitude / 2 / math.sin(math.rad(15))
					aimView(view, spot)
				end
			end
		end
	end
end

local function modelView(parent, props)
	props.BackgroundTransparency = 1
	props.Ambient = Color3.fromRGB(235, 235, 240) -- 3D light, not UI
	props.LightColor = Color3.new(1, 1, 1)
	props.LightDirection = MODEL_LIGHT_DIR
	local view = make("ViewportFrame", "Model", parent, props)
	view.CurrentCamera = make("Camera", "Camera", view, { FieldOfView = 30 })
	return view
end

local detailsSheet -- set below: the poster's tap opens it
local function openDetails() end

local function forgetViews(under)
	for _, object in under:GetDescendants() do
		if object:IsA("ViewportFrame") then
			views[object] = nil
		end
	end
end

-- The poster is one view; each featured Sidekick still has its own named caption, with its rate (owner 2026-11-05).
local function buildPoster(featured)
	local poster = make("Frame", "Poster", banner, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = PALETTE.White,
		ClipsDescendants = true,
	})
	UiTheme.Corner(poster, "M")
	local mythicColor = SidekickView.RarityColor(featured[1] and featured[1].Rarity)
	UiTheme.Gradient(poster, mythicColor:Lerp(BLACK, 0.5), NEAR_BLACK)
	local edge = make("UIStroke", "Edge", poster, {
		Thickness = 3,
		Color = PALETTE.White,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	make("UIGradient", "PosterEdge", edge, { Color = RAINBOW })
	local rays = make("Frame", "Rays", poster, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(1.5, 1.5),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundTransparency = 1,
	})
	for i = 1, 8 do
		local ray = make("Frame", "Ray" .. i, rays, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.05),
			Rotation = i * 180 / 8,
			BackgroundColor3 = mythicColor:Lerp(PALETTE.White, 0.35),
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
		})
		make("UIGradient", "Fade", ray, {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
	end
	local view = modelView(poster, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	views[view] = { Rows = featured }
	-- The dark foot of the poster keeps the names readable over the models.
	local foot = make("Frame", "Foot", poster, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	make("UIGradient", "Fade", foot, {
		Rotation = 90,
		Transparency = NumberSequence.new(1, 0.15),
	})
	local names = make("Frame", "Names", poster, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -4),
		Size = UDim2.new(1, -8, 0.42, 0),
		BackgroundTransparency = 1,
		ZIndex = 4,
	})
	for index, row in featured do
		local slot = POSTER_SLOTS[index]
		if slot then
			local cell = make("Frame", row.Id, names, {
				Position = UDim2.fromScale(slot.X, 0),
				Size = UDim2.fromScale(slot.Width, 1),
				BackgroundTransparency = 1,
				ZIndex = 4,
			})
			local name = caption("Name", cell, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 0.48),
				Size = UDim2.fromScale(1, 0.46),
				Text = row.Name,
				TextSize = slot.NameSize,
				ZIndex = 4,
			})
			name.Outline.Thickness = 3
			paintRarity(
				caption("Rarity", cell, {
					Position = UDim2.fromScale(0, 0.48),
					Size = UDim2.fromScale(1, 0.26),
					Text = row.Rarity,
					TextSize = slot.RateSize + 2,
					ZIndex = 4,
				}),
				row.Rarity
			)
			caption("Rate", cell, {
				Position = UDim2.fromScale(0, 0.74),
				Size = UDim2.fromScale(1, 0.24),
				Text = string.format("%g%%", row.Odds),
				TextColor3 = PALETTE.Gold,
				TextSize = slot.RateSize,
				ZIndex = 4,
			})
		end
	end
	local tap = make("TextButton", "Tap", poster, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
	})
	tap.Activated:Connect(function()
		openDetails()
	end)
	local details = button("Details", poster, { ZIndex = 6 }, "Details") -- placed by the layout, 32 tall
	details.Activated:Connect(function()
		openDetails()
	end)
	-- Text only, tilted, inside the poster's top-left corner (the layout keeps the turned box inside the poster).
	local sticker = role(
		caption("Sticker", banner, {
			Rotation = -5,
			Text = "FEATURED!!!",
			ZIndex = 7,
		}),
		"Item"
	)
	make("UIGradient", "Gold", sticker, {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 130), Color3.fromRGB(255, 150, 30)),
	})
end

-- The server's public rotation. Rares share the poster; Commons and the Secrets are in Details (owner 2026-11-05).
local function renderBanner(rotation)
	forgetViews(banner)
	banner:ClearAllChildren()
	local featured = {}
	for _, tier in { "Mythic", "Legendary", "Rare" } do
		for _, id in rotation.Ids do
			local row = Config.Get(id)
			if row and row.Rarity == tier then
				table.insert(featured, row)
			end
		end
	end
	buildPoster(featured)
end

-- The cost line under the poster, one Caption: the price, its gem, then the hint or the status.
local costRow = make("Frame", "Cost", main, { BackgroundTransparency = 1 })
make("ImageLabel", "GemIcon", costRow, {
	BackgroundTransparency = 1,
	Image = Icons.Gem.Image,
	ScaleType = Enum.ScaleType.Fit,
})
make(
	"UIGradient",
	"Rainbow",
	role(
		caption("Value", costRow, {
			Text = tostring(Config.SummonCost),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		"Caption"
	),
	{ Color = RAINBOW }
)
role(
	caption("Hint", costRow, {
		Text = "Spend Gems for new Sidekicks. Tap the banner for Details!",
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
	"Caption"
)

-- Status takes the hint's place in the cost line, so it never covers the rates.
local statusText = role(
	caption("Status", costRow, {
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
	}),
	"Caption"
)
statusText:GetPropertyChangedSignal("Text"):Connect(function()
	costRow.Hint.Visible = statusText.Text == ""
end)

-- The summon row: 44 tall, 12 apart; Auto-Sell takes 20% of the width and the two summons 40% each.
local autoSellButton = button("AutoSell", main, {}, "Auto-Sell")
local summon1 = button("Summon1", main, {}, string.format("Summon 1x: %d Gems", Config.SummonCost), "Go")
local summon10 = button("Summon10", main, {}, string.format("Summon 10x: %d Gems", Config.TenCost), "Go")
-- VIP pays less (design doc 4.36); the server publishes what this player pays.
local function showCosts()
	local one = player:GetAttribute("SidekickCost1") or Config.SummonCost
	local ten = player:GetAttribute("SidekickCost10") or Config.TenCost
	costRow.Value.Text = tostring(one)
	summon1.Label.Text = string.format("Summon 1x: %d Gems", one)
	summon10.Label.Text = string.format("Summon 10x: %d Gems", ten)
end
player:GetAttributeChangedSignal("SidekickCost1"):Connect(showCosts)
player:GetAttributeChangedSignal("SidekickCost10"):Connect(showCosts)
showCosts()
-- Client/SidekickTutorial's spotlight lands here. On the poster, above the names and rates, so it covers no rate.
local freeSummon = button("FreeSummon", main, {
	Visible = false,
	ZIndex = 2,
}, "FREE SUMMON", "Go")

-- A full-body sheet with its Back button: Details and Auto-Sell.
local function sheet(name, heading)
	local frame =
		make("Frame", name, body, { Size = UDim2.fromScale(1, 1), Visible = false, Active = true, ZIndex = 10 })
	UiTheme.Gradient(frame, Color3.fromRGB(26, 26, 40), NEAR_BLACK)
	frame.BackgroundColor3 = PALETTE.White
	UiTheme.Corner(frame, "M")
	AnimeSkin.Body(frame) -- design doc 4.42: the framed body, outlined heading, art Back
	AnimeSkin.Title(
		caption("Heading", frame, {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -96, 0, 34),
			Text = heading,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		24
	)
	local back = button("Back", frame, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(76, 36),
	}, "Back")
	AnimeSkin.Close(back, back.Label)
	back.Activated:Connect(function()
		frame.Visible = false
	end)
	local list = make("ScrollingFrame", "List", frame, {
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(1, -16, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	make("UIListLayout", "Layout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	return frame, list
end

-- Details: section 6's odds, shown and open before any spend.
local detailsList
detailsSheet, detailsList = sheet("DetailsSheet", "Details: summon odds")
local detailsTotal = caption("Total", detailsList, {
	LayoutOrder = 100,
	Size = UDim2.new(1, -6, 0, 24),
	Text = "",
	TextColor3 = PALETTE.Gold,
})
local function detailsLine(name, order, columns)
	local line = make("Frame", name, detailsList, {
		LayoutOrder = order,
		Size = UDim2.new(1, -6, 0, 30),
		BackgroundColor3 = PALETTE.Row,
	})
	UiTheme.Corner(line, "S")
	AnimeSkin.Plate(line, AnimeSkin.Tint.Default)
	for _, column in columns do
		local label = caption(column.Key, line, {
			Position = UDim2.new(column.X, 6, 0.12, 0),
			Size = UDim2.new(column.Width, -12, 0.76, 0),
			Text = column.Text,
			TextColor3 = column.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		if column.Rarity then
			paintRarity(label, column.Rarity)
		end
	end
end
-- Above every row (the Secret's order is 0). Hidden until a pity guarantee is due.
local guaranteedNote = caption("GuaranteedNote", detailsList, {
	LayoutOrder = -1,
	Size = UDim2.new(1, -6, 0, 44),
	Text = "",
	TextColor3 = PALETTE.Gold,
	TextSize = 16,
	TextWrapped = true,
	Visible = false,
})
local detailsRotation = nil
-- The rarity the next single summon must pay, Mythic first (design doc 4.36), or nil.
local function dueTier()
	if (player:GetAttribute("SidekickPity") or 0) >= PITY_COUNT - 1 then
		return "Mythic"
	elseif (player:GetAttribute("SidekickLegendaryPity") or 0) >= LEGENDARY_PITY_COUNT - 1 then
		return "Legendary"
	end
	return nil
end
-- The server's percents to 3 decimals by largest remainder, so the rows sum to exactly 100.000. Row name -> percent.
local function roundedOdds(rotation)
	local rows, spare = {}, 100000
	local function add(name, id)
		local exact = rotation.Odds[id] * 1000 + 1e-6 -- 24.166 * 1000 lands just under 24166
		local whole = math.floor(exact)
		spare -= whole
		table.insert(rows, { Name = name, Whole = whole, Remainder = exact - whole })
	end
	for _, id in rotation.Ids do
		add(id, id)
	end
	add("Secret", rotation.SecretId)
	table.sort(rows, function(a, b)
		if a.Remainder ~= b.Remainder then
			return a.Remainder > b.Remainder
		end
		return a.Name < b.Name
	end)
	local rounded = {}
	for index, row in rows do
		rounded[row.Name] = (row.Whole + (index <= spare and 1 or 0)) / 1000
	end
	return rounded
end
-- The server's Odds, or a due tier sharing 100%.
local function showOdds()
	local rotation = detailsRotation
	if not rotation then
		return
	end
	local tier = dueTier()
	local odds = {}
	if tier then
		local inTier = 0
		for _, id in rotation.Ids do
			inTier += Config.Get(id).Rarity == tier and 1 or 0
		end
		for _, id in rotation.Ids do
			odds[id] = Config.Get(id).Rarity == tier and 100 / inTier or 0
		end
		odds.Secret = 0
	else
		odds = roundedOdds(rotation)
	end
	local total = 0
	for name, percent in odds do
		total += percent
		detailsList[name].Odds.Text = string.format("%.3f%%", percent)
	end
	detailsTotal.Text = string.format("Total: %g%%", total)
	guaranteedNote.Visible = tier ~= nil
	if tier then
		guaranteedNote.Text = string.format(
			"%s guaranteed on your next summon. These odds are for that one summon: in a 10x it is the first, and the rest roll normally.",
			tier
		)
	end
end
local function renderDetails(rotation)
	forgetViews(detailsList)
	for _, child in detailsList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for order, id in rotation.Ids do
		local row = Config.Get(id)
		detailsLine(id, order, {
			{ Key = "Name", Text = row.Name, X = 0, Width = 0.45 },
			{ Key = "Rarity", Text = row.Rarity, X = 0.45, Width = 0.3, Rarity = row.Rarity },
			{ Key = "Odds", Text = "", X = 0.75, Width = 0.25, Color = PALETTE.Gold },
		})
	end
	-- This rotation's one Secret: its black shape, the rarity and the rate (owner 2026-11-05).
	detailsLine("Secret", 0, {
		{ Key = "Rarity", Text = "Secret", X = 0.45, Width = 0.3, Rarity = "Secret" },
		{ Key = "Odds", Text = "", X = 0.75, Width = 0.25, Color = PALETTE.Gold },
	})
	local line = detailsList.Secret
	line.Size = UDim2.new(1, -6, 0, 66)
	-- A plain light field: black would not read on the dark row.
	local tile = make("Frame", "Shape", line, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.new(0, 58, 1, -8),
		BackgroundColor3 = PALETTE.SoftText,
	})
	UiTheme.Corner(tile, "S")
	local shape = modelView(tile, { Size = UDim2.fromScale(1, 1), ImageColor3 = BLACK })
	views[shape] = { Row = Config.Get(rotation.SecretId) }
	detailsRotation = rotation
	showOdds()
end
caption("Note", detailsList, {
	LayoutOrder = 101,
	Size = UDim2.new(1, -6, 0, 40),
	Text = string.format(
		"Luck and potions never change these odds. Pity: summon %d without a Mythic gives the featured Mythic; summon %d without a Legendary gives a featured Legendary.",
		PITY_COUNT,
		LEGENDARY_PITY_COUNT
	),
	TextColor3 = PALETTE.SoftText,
	TextSize = 15,
	TextWrapped = true,
})

-- Auto-Sell: one toggle per rarity in the catalog.
local autoSellSheet, autoSellList = sheet("AutoSellSheet", "Auto-Sell")
-- The page hides under an open sheet: its sticker and edges stand outside the sheet's rect.
local function fitSheets()
	local open = detailsSheet.Visible or autoSellSheet.Visible
	main.Visible = not open
	gemColumn.Visible = not open
end
detailsSheet:GetPropertyChangedSignal("Visible"):Connect(fitSheets)
autoSellSheet:GetPropertyChangedSignal("Visible"):Connect(fitSheets)
caption("Note", autoSellList, {
	LayoutOrder = 0,
	Size = UDim2.new(1, -6, 0, 22),
	Text = "A summon of a rarity that is on sells at once for its Gems. Worn Sidekicks never sell.",
	TextColor3 = PALETTE.SoftText,
	TextSize = 16,
})
local toggles = {}
local busy = false
for order, row in Config.List do
	if not toggles[row.Rarity] then
		local line = make("Frame", row.Rarity, autoSellList, {
			LayoutOrder = order,
			Size = UDim2.new(1, -6, 0, 44),
			BackgroundColor3 = PALETTE.Row,
		})
		UiTheme.Corner(line, "S")
		AnimeSkin.Plate(line, AnimeSkin.Tint.Default)
		caption("Rarity", line, {
			Position = UDim2.new(0, 10, 0.15, 0),
			Size = UDim2.new(0.6, -10, 0.7, 0),
			Text = string.format("%s: sells for %d Gems", row.Rarity, row.SellGems),
			TextColor3 = SidekickView.RarityColor(row.Rarity),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local toggle = button("Toggle", line, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(84, 36),
		}, "Off")
		toggles[row.Rarity] = toggle
		toggle.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local on = SidekickView.AutoSell(player)[row.Rarity] ~= true
			local ok, done = pcall(function()
				return remotes:WaitForChild("SidekickAutoSell"):InvokeServer(row.Rarity, on)
			end)
			busy = false
			UiFeedback.Play(ok and done == true and "Toggle" or "Denied", toggle)
		end)
	end
end

function openDetails()
	autoSellSheet.Visible = false
	detailsSheet.Visible = true
	UiMotion.Pop(detailsSheet, 0.02)
end

local function refresh()
	gemsValue.Text = HudFormat.Short(player:GetAttribute("Gems") or 0)
	pityValue.Text = string.format("%d/%d", player:GetAttribute("SidekickPity") or 0, PITY_COUNT)
	legendaryPityValue.Text =
		string.format("%d/%d", player:GetAttribute("SidekickLegendaryPity") or 0, LEGENDARY_PITY_COUNT)
	plates[3].Share = (player:GetAttribute("SidekickPity") or 0) / PITY_COUNT
	plates[4].Share = (player:GetAttribute("SidekickLegendaryPity") or 0) / LEGENDARY_PITY_COUNT
	placeFill(plates[3])
	placeFill(plates[4])
	showOdds()
	local locked = (player:GetAttribute("RebirthLevel") or 0) < Config.UnlockRebirth
	for _, summonButton in { summon1, summon10 } do
		summonButton.Active = not locked
		summonButton.BackgroundTransparency = locked and 0.5 or 0
		summonButton.Label.TextTransparency = locked and 0.5 or 0
	end
	if locked then
		statusText.Text = string.format("Summons unlock at rebirth %d", Config.UnlockRebirth)
	elseif string.find(statusText.Text, "unlock", 1, true) then
		statusText.Text = ""
	end
	freeSummon.Visible = not locked and player:GetAttribute("SidekickFreeUsed") == false
	local on = SidekickView.AutoSell(player)
	for rarity, toggle in toggles do
		toggle.Label.Text = on[rarity] == true and "On" or "Off"
		toggle.Stroke.Color = on[rarity] == true and PALETTE.Money or OUTLINE
		AnimeSkin.Button(toggle, on[rarity] == true and "Go" or "Idle")
	end
end

local function summon(remoteName, count, source)
	if busy or not source.Active then
		return
	end
	busy = true
	local ok, done, results = pcall(function()
		return remotes:WaitForChild(remoteName):InvokeServer(count)
	end)
	busy = false
	if ok and done == true then
		statusText.Text = ""
		-- The page steps aside so the reveal plays over the world; a click brings it back.
		root.Enabled = false
		blur.Enabled = false
		SidekickReveal.Play(results, function()
			root.Enabled = true
			blur.Enabled = panel.Visible
		end)
	else
		statusText.Text = ok and tostring(results or "Try again") or "Connection error"
		UiFeedback.Play("Denied", source)
	end
	refresh()
end
summon1.Activated:Connect(function()
	summon("SidekickSummon", 1, summon1)
end)
summon10.Activated:Connect(function()
	summon("SidekickSummon", 10, summon10)
end)
freeSummon.Activated:Connect(function()
	summon("SidekickFreeSummon", nil, freeSummon)
end)
-- A Buy press area only on a pack with a product: until then a tile is the greyed Frame above and nothing can be pressed.
for _, pack in Monetization.GemPacks do
	if pack.ProductId > 0 then
		local tile = packs[pack.Id]
		tile.Soon.Visible = false
		local buy = make("TextButton", "Buy", tile, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 4,
		})
		buy.Activated:Connect(function()
			local ok, done, message = pcall(function()
				return remotes:WaitForChild("GemPackBuy"):InvokeServer(pack.Id)
			end)
			if not (ok and done == true) then
				statusText.Text = ok and tostring(message or "Try again") or "Connection error"
				UiFeedback.Play("Denied", buy)
			end
		end)
	end
end
UiFeedback.DeniedPress(summon1)
UiFeedback.DeniedPress(summon10)
autoSellButton.Activated:Connect(function()
	detailsSheet.Visible = false
	autoSellSheet.Visible = true
	UiMotion.Pop(autoSellSheet, 0.02)
end)

player.AttributeChanged:Connect(function(attribute)
	if
		attribute == "Gems"
		or attribute == "RebirthLevel"
		or attribute == "SidekickAutoSell"
		or attribute == "SidekickFreeUsed"
		or attribute == "SidekickPity"
		or attribute == "SidekickLegendaryPity"
	then
		refresh()
	end
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	blur.Enabled = panel.Visible
	if turning then
		turning:Disconnect()
		turning = nil
	end
	if panel.Visible then
		detailsSheet.Visible = false
		autoSellSheet.Visible = false
		statusText.Text = ""
		refresh()
		turnAngle = 0
		fillViews()
		turning = RunService.Heartbeat:Connect(turnViews)
	else
		for view in views do
			for _, child in view:GetChildren() do
				if child:IsA("Model") then
					child:Destroy()
				end
			end
		end
	end
end)
-- The client only displays the server's rotation; slot changes redraw in place, leaving the page open.
local rotationEndsAt = 0
local function showTimer()
	local seconds = math.floor(math.max(0, rotationEndsAt - workspace:GetServerTimeNow()))
	local text = string.format("%d:%02d", seconds // 60, seconds % 60)
	rotationTimer.Text = text
	plates[2].Share = seconds / ROTATION_SECONDS
	placeFill(plates[2])
	detailsSheet.Heading.Text = "Details: summon odds. Next rotation " .. text
end
local function renderRotation()
	local rotation = SidekickView.Rotation()
	if not rotation.Ids then
		return
	end
	rotationEndsAt = rotation.EndsAt
	renderBanner(rotation)
	renderDetails(rotation)
	g.Relayout() -- the new poster's sticker and Details button
	fillViews()
	showTimer()
end
ReplicatedStorage:GetAttributeChangedSignal("SidekickRotation"):Connect(renderRotation)
renderRotation()
task.spawn(function()
	while true do
		task.wait(1)
		showTimer()
	end
end)
task.spawn(function()
	local models = ReplicatedStorage:WaitForChild("SidekickModels")
	if models:GetAttribute("Ready") ~= true then
		models:GetAttributeChangedSignal("Ready"):Wait()
	end
	fillViews()
end)
-- Every rect in the Index frame's units (design doc 4.42): the plates in the tabs row, Body on the content area.
g.OnLayout(function()
	local c = g.Content
	for label, entry in roles do
		g.Role(label, entry[1])
		if entry[2] then
			label.TextColor3 = entry[2]
		end
	end
	-- The tabs row: four plates, 8 apart as the Index's tabs; text 24 clear of each plate's slanted ends.
	local x, room = c.X, c.W - 3 * 8
	for _, entry in plates do
		local w = room * entry.Row
		entry.W = w
		g.Place(entry.Frame, x, c.TabsY, w, 40)
		local left = entry.Icon and 24 + 28 + 8 or 24
		if entry.Icon then
			g.Place(entry.Icon, 24, 6, 28, 28)
		end
		local inner = w - 24 - left
		g.Place(entry.Frame.Label, left, 0, inner * entry.Label - 4, 40)
		g.Place(entry.Value, left + inner * entry.Label + 4, 0, inner * (1 - entry.Label) - 4, 40)
		if entry.Fill then
			placeFill(entry)
		end
		x += w + 8
	end
	g.Place(body, c.X, c.Y, c.W, c.H)
	-- Main: the left 56%. Top down: the poster, 12, the cost line, 8, the summon row, 12 above the area's foot.
	local mainW = math.floor(c.W * 0.56)
	g.Place(main, 0, 0, mainW, c.H)
	local rowY = c.H - 12 - 44
	local costY = rowY - 8 - 22
	local posterH = costY - 12
	g.Place(banner, 0, 0, mainW, posterH)
	g.Place(costRow, 0, costY, mainW, 22)
	g.Place(costRow.Value, 0, 0, 48, 22)
	g.Place(costRow.GemIcon, 52, 1, 20, 20)
	g.Place(costRow.Hint, 80, 0, mainW - 80, 22)
	g.Place(statusText, 80, 0, mainW - 80, 22)
	local share = (mainW - 24) / 5 -- Auto-Sell 1 share, each summon 2
	g.Place(autoSellButton, 0, rowY, share, 44)
	g.Place(summon1, share + 12, rowY, 2 * share, 44)
	g.Place(summon10, 3 * share + 24, rowY, 2 * share, 44)
	-- On the poster, 12 above its names (the poster's lower 42%).
	g.Place(freeSummon, mainW / 4, math.max(12, posterH * 0.58 - 12 - 44), mainW / 2, 44)
	local poster = banner:FindFirstChild("Poster")
	local details = poster and poster:FindFirstChild("Details")
	if details then
		g.Place(details, mainW - 12 - 100, 12, 100, 32)
	end
	local sticker = banner:FindFirstChild("Sticker")
	if sticker then
		g.Place(sticker, 16, 22, 190, 40) -- a -5 degree turn lifts a corner about 8: still 12 inside the top
	end
	-- The gem column: the right 44%, MORE GEMS then as many whole pack cards as fit, 12 apart.
	local colX = mainW + 12
	local colW = c.W - colX
	g.Place(gemColumn, colX, 0, colW, c.H)
	g.Place(gemHeading, 0, 0, colW, 40)
	local listY = 52
	g.Place(packs, 0, listY, colW, c.H - listY)
	packLayout.Padding = UDim.new(0, g.px(12))
	local roomH = c.H - listY - 2 * PACK_PAD / g.k
	local count = math.max(1, math.floor((roomH + 12) / (136 + 12))) -- 136: three lines and the padding
	local tall = (roomH - (count - 1) * 12) / count
	local tileW = colW - 8 / g.k - 2 * PACK_PAD / g.k -- the scrollbar's 6 px and the clip pad, in units
	for _, tile in packs:GetChildren() do
		if tile:IsA("Frame") then
			tile.Size = UDim2.fromOffset(g.px(tileW), g.px(tall))
			placePack(tile, tileW, tall)
		end
	end
end)
refresh()
UiTheme.Apply(root)
