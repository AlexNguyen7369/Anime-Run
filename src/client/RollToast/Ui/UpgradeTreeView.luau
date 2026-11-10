--!nonstrict
-- Presentation only: authoritative prices, locks and purchases stay in ProgressionUi/UpgradeTree.
local View = {}
local Components = require(script.Parent.RacerComponents)
local UiTheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UiTheme"))
local PanelFrame = require(script.Parent.Parent.Parent:WaitForChild("PanelFrame"))
local AnimeSkin = require(script.Parent.Parent.Parent:WaitForChild("AnimeSkin"))
local UserInputService = game:GetService("UserInputService")
local WORLD, MIN_ZOOM, MAX_ZOOM, ZOOM_STEP = 1800, 0.15, 1.6, 0.16
-- The click box is one row step tall so neighbouring tiles never overlap; the hex art is sized from the width.
local NODE_WIDTH, NODE_HEIGHT, STEP_X, STEP_Y = 100, 106, 122, 106
local CYAN, DARK, WHITE = Color3.fromRGB(30, 216, 255), Color3.fromRGB(27, 33, 46), Color3.new(1, 1, 1)
local ICONS = {
	money = "cash",
	luck = "luck",
	speed = "speed",
	rollspeed = "luck",
	turbo = "luck",
	walkspeed = "speed",
	stamina = "speed",
}
local function make(class, name, props, parent)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function label(parent, name, text, pos, size, textSize)
	local object = make("TextLabel", name, {
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		Text = text,
		Font = UiTheme.Font,
		TextSize = textSize,
		TextColor3 = WHITE,
		TextWrapped = true,
		ZIndex = 7,
	}, parent)
	make(
		"UIStroke",
		"GlyphOutline",
		{ Color = UiTheme.Outline, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
		object
	)
	return object
end
local function hex(parent, name, width, color, z, yOffset)
	local pieces = {}
	for i, rotation in { 0, 60, -60 } do
		pieces[i] = make("Frame", name .. i, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, yOffset or 0),
			Size = UDim2.fromOffset(width, width / math.sqrt(3)),
			Rotation = rotation,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, parent)
	end
	return pieces
end
local function paint(pieces, color)
	for _, piece in pieces do
		piece.BackgroundColor3 = color
	end
end

function View.Create(gui, Tree, Format)
	local chromeModule = script.Parent.Parent.Parent:WaitForChild("Ui"):WaitForChild("RacerUpgrades")
	local chrome = require(chromeModule)
	-- Roblox clones StarterGui asynchronously. Wait for the authored shell rather
	-- than building a second GUI before that clone arrives.
	local refs = chrome.Bind(gui)
	local screen = refs.Gui
	screen.DisplayOrder = 8
	-- Design doc 4.42: the detail card is the angular card art (its white plate, lift and shadow go), the text the
	-- outlined white title.
	AnimeSkin.Card(refs.Details)
	for _, name in { "Lift", "Shadow" } do
		local part = refs.Details:FindFirstChild(name) or refs.Details.Parent:FindFirstChild(name)
		if part then
			part.Visible = false
		end
	end
	for _, line in { refs.DetailTitle, refs.DetailBonus, refs.DetailStatus } do
		AnimeSkin.Title(line, line.TextSize)
	end
	-- The title and Balance sit on the header strip now, not on their own dark pills.
	for _, line in { refs.TreeTitle, refs.Balance } do
		line.BackgroundTransparency = 1
	end
	PanelFrame.PaintClose(refs.Close, refs.CloseLabel)
	-- Zoom - / +: Index-style Idle buttons (flat fill, 4 px corners) without the generated shadow and lift.
	for _, zoomButton in { refs.ZoomIn, refs.ZoomOut } do
		AnimeSkin.Button(zoomButton, "Idle")
	end
	for _, line in { refs.ZoomInLabel, refs.ZoomOutLabel } do
		AnimeSkin.Label(line, "Item")
	end
	for _, face in { refs.Close, refs.ZoomIn, refs.ZoomOut } do
		for _, part in { face.Parent:FindFirstChild("Shadow") or false, face:FindFirstChild("Lift") or false } do
			if part then
				part.Visible = false
			end
		end
	end
	-- One way out (UI audit A30): X. The generated fit re-applies Exit's authored Visible, so hold it hidden.
	local exit = refs.Exit.Parent
	exit.Visible = false
	exit:GetPropertyChangedSignal("Visible"):Connect(function()
		if exit.Visible then
			exit.Visible = false
		end
	end)
	local panel = make("Frame", "Panel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(7, 15, 24),
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 0,
		Active = true,
	}, screen)
	-- The canvas starts under the toolbar row (layout below), so a panned node is clipped there instead of sliding
	-- under the header or the + / - buttons.
	local canvas = make("ScrollingFrame", "Canvas", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ClipsDescendants = true,
		ScrollingEnabled = false,
		CanvasSize = UDim2.fromOffset(WORLD, WORLD),
		ZIndex = 1,
	}, panel)
	local world = make(
		"Frame",
		"TreeWorld",
		{ Size = UDim2.fromOffset(WORLD, WORLD), BackgroundTransparency = 1, ZIndex = 2 },
		canvas
	)
	local scale = make("UIScale", "TreeZoom", { Scale = 0.8 }, world)
	-- Design doc 4.42 spacing standard (Client/AnimeSkin tokens): the standard header strip across the top (Upgrade
	-- logo, ALL CAPS title, Balance on its right, the art close at 6 / 6), the zoom buttons in the toolbar row under it,
	-- the tree below both. Balance left the bottom edge, where it covered the TURBO LUCK bar. The generated fit()
	-- re-applies the authored rects and scales on every resize; those writes queue this layout again.
	local titleBar = make("Frame", "TitleBar", { BackgroundTransparency = 1, ZIndex = 2 }, screen)
	local strip = AnimeSkin.Strip(titleBar)
	local logo = make("ImageLabel", "Logo", {
		BackgroundTransparency = 1,
		Image = require(script.Parent.HudIcons).Upgrade.Image,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
	}, titleBar)
	local closeBox = refs.Close.Parent
	for object, z in { [refs.TreeTitle] = 3, [refs.Balance] = 3, [closeBox] = 4, [refs.ZoomTools] = 3 } do
		object.ZIndex = z
	end
	local function layout()
		local px, space = AnimeSkin.Px, AnimeSkin.Space
		local inset, gap, inner, h = px(space.Inset), px(space.Gap), px(space.Inner), px(space.Header)
		local closeGap, logoSize, button = px(space.CloseGap), px(space.Logo), px(space.Button)
		local closeSize = h - 2 * closeGap
		-- The logo overhangs the strip by 45 % of its height: the strip starts that far below the top-bar inset.
		local top = game:GetService("GuiService"):GetGuiInset().Y + math.floor(h * 0.45)
		titleBar.Position, titleBar.Size = UDim2.fromOffset(inset, top), UDim2.new(1, -2 * inset, 0, h)
		local stripLeft = math.floor(h * 0.5)
		strip.Position, strip.Size = UDim2.fromOffset(stripLeft, 4), UDim2.new(1, -stripLeft, 1, -8)
		logo.Position = UDim2.fromOffset(-math.floor(h * 0.2), -math.floor(h * 0.45))
		logo.Size = UDim2.fromOffset(logoSize, logoSize)
		for _, object in { refs.TreeTitle, closeBox, refs.Balance, refs.ZoomTools } do
			local fit = object:FindFirstChildOfClass("UIScale")
			if fit then
				fit.Scale = 1 -- px tokens, not the generated zoom
			end
		end
		local title = refs.TreeTitle
		title.AnchorPoint = Vector2.zero
		title.Position = UDim2.fromOffset(inset + logoSize - math.floor(h * 0.15), top + 4)
		title.Size = UDim2.fromOffset(px(320), h - 8)
		title.TextXAlignment = Enum.TextXAlignment.Left
		AnimeSkin.Label(title, "Title")
		closeBox.AnchorPoint = Vector2.new(1, 0)
		closeBox.Position = UDim2.new(1, -inset - closeGap, 0, top + closeGap)
		closeBox.Size = UDim2.fromOffset(closeSize, closeSize)
		local balance = refs.Balance
		balance.AnchorPoint = Vector2.new(1, 0)
		balance.Position = UDim2.new(1, -inset - closeSize - 2 * closeGap - gap, 0, top + 4)
		balance.Size = UDim2.fromOffset(px(260), h - 8)
		balance.TextXAlignment = Enum.TextXAlignment.Right
		AnimeSkin.Label(balance, "Item")
		local zoomTop = top + h + gap
		local tools = refs.ZoomTools
		tools.AnchorPoint = Vector2.zero
		tools.Position, tools.Size = UDim2.fromOffset(inset, zoomTop), UDim2.fromOffset(2 * button + inner, button)
		for i, zoomButton in { refs.ZoomOut, refs.ZoomIn } do
			local box = zoomButton.Parent
			box.Position, box.Size = UDim2.fromOffset((i - 1) * (button + inner), 0), UDim2.fromOffset(button, button)
		end
		local contentTop = zoomTop + button + gap
		canvas.Position, canvas.Size = UDim2.fromOffset(0, contentTop), UDim2.new(1, 0, 1, -contentTop)
	end
	local queued = false
	local function queue()
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				layout()
			end)
		end
	end
	for _, object in { refs.TreeTitle, closeBox, refs.Balance, refs.ZoomTools } do
		object:GetPropertyChangedSignal("Position"):Connect(queue)
		object:GetPropertyChangedSignal("Size"):Connect(queue)
		local fit = object:FindFirstChildOfClass("UIScale")
		if fit then
			fit:GetPropertyChangedSignal("Scale"):Connect(queue)
		end
	end
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(queue)
	end
	layout()
	queue() -- after the generated fit's own deferred pass
	local feedback = make("TextLabel", "Result", { BackgroundTransparency = 1, Visible = false, Text = "" }, panel)
	local tiles = {}
	local view = { Panel = panel, Canvas = canvas, Tiles = tiles, Feedback = feedback, Refs = refs }
	local selected
	local function description(tile)
		for _, branch in Tree.Config.Branches do
			if branch.Id == tile.Branch then
				if branch.Effect == "Inventory" then
					return "+" .. branch.Bonus[tile.Tier] .. " bag spaces"
				end
				if branch.Bonus then
					local effect = branch.Effect == "Speed" and "cruise speed" or branch.Effect
					return "+" .. math.floor(branch.Bonus[tile.Tier] * 100 + 0.5) .. "% " .. effect
				end
				if branch.WalkSpeed then
					return branch.WalkSpeed[tile.Tier] .. " WalkSpeed"
				end
				if branch.Tiers then
					local tier = branch.Tiers[tile.Tier]
					return "Turbo x" .. tier.Multi .. " / " .. tier.Every .. " rolls"
				end
			end
		end
		return ""
	end
	local function inspect(entry)
		selected = entry
		refs.DetailTitle.Text = entry.Tile.Name
		refs.DetailBonus.Text = description(entry.Tile)
		refs.DetailStatus.Text = entry.Status or "Select a tile"
	end
	local function node(id, name, q, r, icon)
		local button = make("TextButton", id, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(WORLD / 2 + STEP_X * (q + r / 2), WORLD / 2 + STEP_Y * r),
			Size = UDim2.fromOffset(NODE_WIDTH, NODE_HEIGHT),
			Text = "",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			ZIndex = 3,
		}, world)
		hex(button, "Shadow", NODE_WIDTH + 5, Color3.fromRGB(10, 19, 38), 3, 5)
		local outline = hex(button, "HexEdge", NODE_WIDTH + 3, WHITE, 4)
		local fills = hex(button, "HexFace", NODE_WIDTH - 3, CYAN, 5)
		local art = Components.IconArt(button, "Art", icon, UDim2.new(0.5, -32, 0.5, -36), UDim2.fromOffset(64, 64))
		art.ZIndex = 6
		local title = label(button, "Text", name, UDim2.fromOffset(2, 12), UDim2.new(1, -4, 0, 46), 19)
		local price = label(button, "Price", "", UDim2.new(0, 2, 1, -36), UDim2.new(1, -4, 0, 28), 16)
		return { Button = button, Label = title, Price = price, Art = art, Fills = fills, Outline = outline }
	end
	local start = node("Start", "START", 0, 0, "speed")
	start.Price.Text = "UPGRADES"
	for _, tile in Tree.Tiles() do
		local entry = node(tile.Id, tile.Name, tile.Q, tile.R, ICONS[tile.Branch])
		entry.Tile = tile
		tiles[tile.Id] = entry
		entry.Button.MouseEnter:Connect(function()
			inspect(entry)
		end)
		entry.Button.Activated:Connect(function()
			inspect(entry)
		end)
	end
	function view.Paint(entry, owned, canBuy, reason, trackCount)
		local locked = reason == "locked"
		entry.Label.Text = locked and "?" or entry.Tile.Name
		entry.Label.TextSize = locked and 42 or 19
		-- A locked "?" fills the whole node (centred as before), so the drawn content spans the hitbox.
		entry.Label.Position = locked and UDim2.new() or UDim2.fromOffset(2, 12)
		entry.Label.Size = locked and UDim2.fromScale(1, 1) or UDim2.new(1, -4, 0, 46)
		entry.Art.Visible = not locked
		local gate = reason == "gated" and ("Reach Track " .. Tree.RequiredTrack(entry.Tile.Id, trackCount)) or nil
		entry.Price.Text = locked and "" or owned and "OWNED" or gate or Format.MoneyText(Tree.Price(entry.Tile.Id))
		entry.Price.TextColor3 = owned and Color3.fromRGB(60, 255, 60)
			or canBuy and Color3.fromRGB(60, 255, 60)
			or Color3.fromRGB(255, 105, 105)
		paint(entry.Fills, owned and CYAN or DARK)
		paint(entry.Outline, owned and WHITE or canBuy and CYAN or Color3.fromRGB(82, 90, 100))
		entry.Status = owned and "OWNED"
			or locked and "Previous upgrade required"
			or gate
			or canBuy and ("BUY • " .. Format.MoneyText(Tree.Price(entry.Tile.Id)))
			or "Not enough Money"
		if selected == entry then
			inspect(entry)
		end
	end
	function view.Balance(value)
		refs.Balance.Text = Format.MoneyText(value)
	end
	feedback:GetPropertyChangedSignal("Text"):Connect(function()
		refs.DetailStatus.Text = feedback.Text
	end)
	local function clampPan(position)
		return Vector2.new(
			math.clamp(position.X, 0, math.max(0, WORLD * scale.Scale - canvas.AbsoluteSize.X)),
			math.clamp(position.Y, 0, math.max(0, WORLD * scale.Scale - canvas.AbsoluteSize.Y))
		)
	end
	local function zoom(value, anchor)
		local old = scale.Scale
		value = math.clamp(value, MIN_ZOOM, MAX_ZOOM)
		anchor = anchor or canvas.AbsoluteSize / 2
		local worldPoint = (canvas.CanvasPosition + anchor) / old
		scale.Scale = value
		canvas.CanvasSize = UDim2.fromOffset(WORLD * value, WORLD * value)
		canvas.CanvasPosition = clampPan(worldPoint * value - anchor)
		screen:SetAttribute("TreeZoom", value)
	end
	refs.ZoomIn.Activated:Connect(function()
		zoom(scale.Scale + ZOOM_STEP)
	end)
	refs.ZoomOut.Activated:Connect(function()
		zoom(scale.Scale - ZOOM_STEP)
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not panel.Visible or input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local origin = canvas.AbsolutePosition + game:GetService("GuiService"):GetGuiInset()
		local point = mouse - origin
		if point.X >= 0 and point.Y >= 0 and point.X <= canvas.AbsoluteSize.X and point.Y <= canvas.AbsoluteSize.Y then
			zoom(scale.Scale + input.Position.Z * ZOOM_STEP, point)
		end
	end)
	local dragStart, panStart
	canvas.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			panStart = canvas.CanvasPosition
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragStart
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			canvas.CanvasPosition = clampPan(panStart - (Vector2.new(input.Position.X, input.Position.Y) - dragStart))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragStart = nil
		end
	end)
	local blur = Instance.new("BlurEffect")
	blur.Name, blur.Size, blur.Enabled, blur.Parent = "UpgradeTreeBlur", 12, false, game:GetService("Lighting")
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		screen.Enabled = panel.Visible
		blur.Enabled = panel.Visible
		if panel.Visible then
			zoom(scale.Scale)
			canvas.CanvasPosition = clampPan(Vector2.new(WORLD / 2, WORLD / 2) * scale.Scale - canvas.AbsoluteSize / 2)
		end
	end)
	screen.Enabled = false
	zoom(0.8)
	return view
end

return View
