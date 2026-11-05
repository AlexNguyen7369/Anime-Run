--!nonstrict
-- The Sidekicks summon page (design doc 4.36, docs/SIDEKICK_SPEC.md "Summon page"), opened at the plaza stall. Left: gem pack
-- tiles (no products yet: "Coming soon"), Details (every outcome's odds, before any spend, section 6) and Settings (auto-sell
-- per rarity). Right: the banner, the Gem balance, Summon 1x and 10x, and the reveal. The server decides every result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(shared:WaitForChild("SidekickConfig"))
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local Monetization = require(shared:WaitForChild("MonetizationConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local Ui = script.Parent:WaitForChild("RollToast"):WaitForChild("Ui")
local Icons = require(Ui.HudIcons)

local PALETTE = UiTheme.Palette
local OUTLINE = UiTheme.Outline
local GEM, GEM_DEEP = Color3.fromRGB(150, 235, 255), Color3.fromRGB(50, 130, 255) -- as the HUD's Gems plate
local MODEL_VIEW_DIR = Vector3.new(0.45, 0.15, -1).Unit -- from the model to the camera, as Client/StarterPick
local MODEL_LIGHT_DIR = Vector3.new(-1, -2, -1)
local TURN_SPEED = math.rad(30) -- radians per second (placeholder)
local MODEL_SWAY = math.rad(30) -- how far the view swings either way from the front (placeholder)

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
local function button(name, parent, props, text, top, deep)
	props.BackgroundColor3 = PALETTE.White
	props.Text = ""
	props.AutoButtonColor = false
	local b = make("TextButton", name, parent, props)
	UiTheme.Corner(b, "M")
	UiTheme.Gradient(b, top or PALETTE.Row, deep or PALETTE.PanelDeep)
	make("UIStroke", "Stroke", b, { Color = OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	caption("Label", b, {
		Position = UDim2.fromScale(0.05, 0.12),
		Size = UDim2.fromScale(0.9, 0.76),
		Text = text,
	})
	return b
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
	Icon = Icons.Items.Image,
	MaxWidth = 760,
})
chrome.Close.Activated:Connect(function()
	PanelSwitch.Close("Sidekicks")
end)
PanelFrame.CloseOnOutsideClick(panel, function()
	PanelSwitch.Close("Sidekicks")
end)

local body = make("Frame", "Body", panel, { BackgroundTransparency = 1 })
-- Below the header, which is 48 tall on short screens and 64 otherwise (PanelFrame).
local function fitBody()
	local top = chrome.Header.AbsoluteSize.Y + 8
	body.Position = UDim2.fromOffset(12, top)
	body.Size = UDim2.new(1, -24, 1, -top - 10)
end
chrome.Header:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBody)
fitBody()

-- Left: the packs scroll; Details and Settings stay reachable on the shortest screen.
local left = make("Frame", "Left", body, { Size = UDim2.fromScale(0.34, 1), BackgroundTransparency = 1 })
local packs = make("ScrollingFrame", "Packs", left, {
	Size = UDim2.new(1, 0, 1, -48),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
})
make("UIGridLayout", "Layout", packs, {
	CellSize = UDim2.new(0.5, -5, 0, 72),
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
for order, pack in Monetization.GemPacks do
	-- shortcut: greyed Frames while every ProductId is 0, buttons and the receipt path come with the real product ids.
	local tile = make("Frame", pack.Id, packs, { LayoutOrder = order, BackgroundColor3 = PALETTE.Disabled })
	UiTheme.Corner(tile, "S")
	caption("Gems", tile, {
		Position = UDim2.fromScale(0.05, 0.08),
		Size = UDim2.fromScale(0.9, 0.42),
		Text = HudFormat.Short(pack.Gems) .. " Gems",
		TextColor3 = GEM,
	})
	caption("Soon", tile, {
		Position = UDim2.fromScale(0.05, 0.55),
		Size = UDim2.fromScale(0.9, 0.35),
		Text = "Coming soon",
		TextColor3 = PALETTE.SoftText,
	})
end
local detailsButton = button("Details", left, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(0.5, -3, 0, 42),
}, "Details")
local settingsButton = button("Settings", left, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromScale(1, 1),
	Size = UDim2.new(0.5, -3, 0, 42),
}, "Settings")

-- Right: the banner takes what the balance, status and buttons leave.
local right = make("Frame", "Right", body, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.66, -10, 1, 0),
	BackgroundTransparency = 1,
})
local banner = make("Frame", "Banner", right, {
	Size = UDim2.new(1, 0, 1, -104),
	BackgroundColor3 = PALETTE.TileDeep,
})
UiTheme.Corner(banner, "M")
make("UIListLayout", "Layout", banner, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0.015, 0),
	SortOrder = Enum.SortOrder.LayoutOrder,
})

-- The actual 3D models (owner 2026-11-05). Every view on screen, up to 13 with a 10x reveal: one Heartbeat turns them all.
local views = {} -- ViewportFrame -> { Row, Focus, Distance }
local turnAngle = 0
local turning = nil

-- The camera sways around the front, so the model always faces the player, and the light follows it.
local function aimView(view, spot)
	local turn = CFrame.Angles(0, math.sin(turnAngle) * MODEL_SWAY, 0)
	view.CurrentCamera.CFrame = CFrame.lookAt(spot.Focus + turn * MODEL_VIEW_DIR * spot.Distance, spot.Focus)
	view.LightDirection = turn * MODEL_LIGHT_DIR
end
local function turnViews(dt)
	local reduced = UiMotion.Reduced()
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
		local source = spot.Row and models:FindFirstChild(spot.Row.Id)
		if source and not view:FindFirstChildOfClass("Model") then
			local model = source:Clone()
			model.Parent = view
			local box, extents = model:GetBoundingBox()
			spot.Focus = box.Position
			spot.Distance = 0.72 * extents.Magnitude / 2 / math.sin(math.rad(15))
			aimView(view, spot)
		end
	end
end
-- A cell's rarity tile with its name and model, and the rarity below it. row nil: an id this version does not know.
local function modelCell(cell, row)
	local tile = make("Frame", "Tile", cell, {
		Size = UDim2.fromScale(1, 0.78),
		BackgroundColor3 = PALETTE.White,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	UiTheme.Corner(tile, "S")
	UiTheme.Gradient(tile, SidekickView.RarityColor(row and row.Rarity), PALETTE.PanelDeep)
	caption("Label", tile, {
		Position = UDim2.fromScale(0.04, 0.02),
		Size = UDim2.fromScale(0.92, 0.16),
		Text = row and row.Name or "?",
		ZIndex = 4,
	})
	local view = make("ViewportFrame", "Model", tile, {
		Position = UDim2.fromScale(0, 0.16),
		Size = UDim2.fromScale(1, 0.84),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(235, 235, 240), -- 3D light, not UI
		LightColor = Color3.new(1, 1, 1),
		LightDirection = MODEL_LIGHT_DIR,
		ZIndex = 3,
	})
	view.CurrentCamera = make("Camera", "Camera", view, { FieldOfView = 30 })
	caption("Rarity", cell, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.2),
		Text = row and row.Rarity or "",
		TextColor3 = SidekickView.RarityColor(row and row.Rarity),
	})
	views[view] = { Row = row }
	return tile
end

for order, row in Config.List do
	modelCell(
		make("Frame", row.Id, banner, {
			LayoutOrder = order,
			Size = UDim2.fromScale(0.31, 0.92),
			BackgroundTransparency = 1,
		}),
		row
	)
end

local balance = make("Frame", "Balance", right, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -72),
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
})
make("ImageLabel", "GemIcon", balance, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(24, 24),
	BackgroundTransparency = 1,
	Image = Icons.Gem.Image,
})
local gemsValue = caption("GemsValue", balance, {
	Position = UDim2.fromOffset(30, 0),
	Size = UDim2.new(1, -30, 1, 0),
	Text = "0",
	TextXAlignment = Enum.TextXAlignment.Left,
})
local status = caption("Status", right, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, -48),
	Size = UDim2.new(1, 0, 0, 20),
	Text = "",
	TextColor3 = PALETTE.Gold,
	TextSize = 16,
})
local summon1 = button("Summon1", right, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(0.5, -4, 0, 44),
}, string.format("Summon 1x: %d Gems", Config.SummonCost), GEM_DEEP, PALETTE.ShopIndigo)
local summon10 = button("Summon10", right, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromScale(1, 1),
	Size = UDim2.new(0.5, -4, 0, 44),
}, string.format("Summon 10x: %d Gems", Config.TenCost), GEM_DEEP, PALETTE.ShopIndigo)

-- The reveal covers the banner only, so the Summon buttons and the balance stay live (design doc 4.20).
local reveal = make("Frame", "Reveal", right, {
	Size = banner.Size,
	Visible = false,
	Active = true,
	ZIndex = 6,
})
UiTheme.Body(reveal)
UiTheme.Corner(reveal, "M")
local revealGrid = make("Frame", "Grid", reveal, {
	Position = UDim2.fromOffset(6, 38), -- below the OK button, which sat on the top row's last card
	Size = UDim2.new(1, -12, 1, -44),
	BackgroundTransparency = 1,
})
local revealLayout = make("UIGridLayout", "Layout", revealGrid, {
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	CellPadding = UDim2.fromScale(0.01, 0.02),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local revealOk = button("Ok", reveal, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(52, 30),
	ZIndex = 8,
}, "OK")

local function clearReveal()
	for _, child in revealGrid:GetChildren() do
		if child:IsA("GuiObject") then
			views[child.Tile.Model] = nil
			child:Destroy()
		end
	end
end

local function showReveal(results)
	clearReveal()
	turnAngle = 0 -- faces the player first
	revealLayout.CellSize = #results > 1 and UDim2.fromScale(0.19, 0.47) or UDim2.fromScale(0.5, 0.96)
	local arts, best, bestRank = {}, nil, 0
	for order, result in results do
		local row = Config.Get(result.Id)
		local cell = make("Frame", "Result" .. order, revealGrid, { LayoutOrder = order, BackgroundTransparency = 1 })
		local art = modelCell(cell, row)
		table.insert(arts, art)
		if result.Sold and row then
			caption("Sold", art, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.98),
				Size = UDim2.fromScale(0.94, 0.26),
				Text = string.format("SOLD +%d", row.SellGems),
				TextColor3 = PALETTE.Gold,
				ZIndex = 5,
			})
		end
		local rank = row and table.find(GachaConfig.RARITY_ORDER, row.Rarity) or 0
		if rank > bestRank then
			best, bestRank = art, rank
		end
	end
	fillViews()
	reveal.Visible = true
	UiMotion.Cascade(arts)
	UiFeedback.Play(SidekickView.LAND_CUES[GachaConfig.RARITY_ORDER[bestRank]] or "RollLand1", best)
end
revealOk.Activated:Connect(function()
	reveal.Visible = false
	clearReveal()
end)

-- A full-body sheet with its Back button: Details and Settings.
local function sheet(name, heading)
	local frame =
		make("Frame", name, body, { Size = UDim2.fromScale(1, 1), Visible = false, Active = true, ZIndex = 10 })
	UiTheme.Body(frame)
	UiTheme.Corner(frame, "M")
	caption("Heading", frame, {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -96, 0, 34),
		Text = heading,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local back = button("Back", frame, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(76, 36),
	}, "Back")
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
local detailsSheet, detailsList = sheet("DetailsSheet", "Details: summon odds")
local total = 0
for order, row in Config.List do
	total += row.Odds
	local line = make("Frame", row.Id, detailsList, {
		LayoutOrder = order,
		Size = UDim2.new(1, -6, 0, 34),
		BackgroundColor3 = PALETTE.Row,
	})
	UiTheme.Corner(line, "S")
	local function column(key, text, x, width, color)
		caption(key, line, {
			Position = UDim2.new(x, 6, 0.12, 0),
			Size = UDim2.new(width, -12, 0.76, 0),
			Text = text,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	column("Name", row.Name, 0, 0.26)
	column("Rarity", row.Rarity, 0.26, 0.22, SidekickView.RarityColor(row.Rarity))
	column("Odds", string.format("%g%%", row.Odds), 0.48, 0.14, PALETTE.Gold)
	column("Gain", SidekickView.GainText(row), 0.62, 0.38)
end
caption("Total", detailsList, {
	LayoutOrder = #Config.List + 1,
	Size = UDim2.new(1, -6, 0, 24),
	Text = string.format("Total: %g%%", total),
	TextColor3 = PALETTE.Gold,
})
caption("Note", detailsList, {
	LayoutOrder = #Config.List + 2,
	Size = UDim2.new(1, -6, 0, 22),
	Text = "Each roll is independent. Luck and potions never change these odds.",
	TextColor3 = PALETTE.SoftText,
	TextSize = 16,
})

-- Settings: the auto-sell filter, one toggle per rarity in the catalog.
local settingsSheet, settingsList = sheet("SettingsSheet", "Settings: auto-sell")
caption("Note", settingsList, {
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
		local line = make("Frame", row.Rarity, settingsList, {
			LayoutOrder = order,
			Size = UDim2.new(1, -6, 0, 44),
			BackgroundColor3 = PALETTE.Row,
		})
		UiTheme.Corner(line, "S")
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

local function refresh()
	gemsValue.Text = HudFormat.Short(player:GetAttribute("Gems") or 0)
	local locked = (player:GetAttribute("RebirthLevel") or 0) < Config.UnlockRebirth
	for _, summonButton in { summon1, summon10 } do
		summonButton.Active = not locked
		summonButton.BackgroundTransparency = locked and 0.5 or 0
		summonButton.Label.TextTransparency = locked and 0.5 or 0
	end
	if locked then
		status.Text = string.format("Summons unlock at rebirth %d", Config.UnlockRebirth)
	elseif string.find(status.Text, "unlock", 1, true) then
		status.Text = ""
	end
	local on = SidekickView.AutoSell(player)
	for rarity, toggle in toggles do
		toggle.Label.Text = on[rarity] == true and "On" or "Off"
		toggle.Stroke.Color = on[rarity] == true and PALETTE.Money or OUTLINE
	end
end

local function summon(count, source)
	if busy or not source.Active then
		return
	end
	busy = true
	local ok, done, results = pcall(function()
		return remotes:WaitForChild("SidekickSummon"):InvokeServer(count)
	end)
	busy = false
	if ok and done == true then
		status.Text = ""
		showReveal(results)
	else
		status.Text = ok and tostring(results or "Try again") or "Connection error"
		UiFeedback.Play("Denied", source)
	end
	refresh()
end
summon1.Activated:Connect(function()
	summon(1, summon1)
end)
summon10.Activated:Connect(function()
	summon(10, summon10)
end)
UiFeedback.DeniedPress(summon1)
UiFeedback.DeniedPress(summon10)
detailsButton.Activated:Connect(function()
	settingsSheet.Visible = false
	detailsSheet.Visible = true
	UiMotion.Pop(detailsSheet, 0.02)
end)
settingsButton.Activated:Connect(function()
	detailsSheet.Visible = false
	settingsSheet.Visible = true
	UiMotion.Pop(settingsSheet, 0.02)
end)

player.AttributeChanged:Connect(function(attribute)
	if attribute == "Gems" or attribute == "RebirthLevel" or attribute == "SidekickAutoSell" then
		refresh()
	end
end)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	clearReveal()
	if turning then
		turning:Disconnect()
		turning = nil
	end
	if panel.Visible then
		reveal.Visible = false
		detailsSheet.Visible = false
		settingsSheet.Visible = false
		status.Text = ""
		refresh()
		turnAngle = 0
		fillViews()
		turning = RunService.Heartbeat:Connect(turnViews)
	else
		for view in views do
			local model = view:FindFirstChildOfClass("Model")
			if model then
				model:Destroy()
			end
		end
	end
end)
task.spawn(function()
	local models = ReplicatedStorage:WaitForChild("SidekickModels")
	if models:GetAttribute("Ready") ~= true then
		models:GetAttributeChangedSignal("Ready"):Wait()
	end
	fillViews()
end)
refresh()
UiTheme.Apply(root)
