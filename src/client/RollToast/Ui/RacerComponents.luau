--!nonstrict
-- Saved, data-driven gallery and stat rows. Bake in Edit, Bind in Play.
local Components = {}
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CharacterCatalog = require(Shared.CharacterCatalog)
local CharacterPortraits = require(Shared.CharacterPortraits)
local HudFormat = require(Shared.HudFormat)
local NpcConfig = require(Shared.NpcConfig)
local RaceProgressMap = require(Shared.RaceProgressMap)
local UiTheme = require(Shared.UiTheme)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(12, 16, 30)
local DARK = Color3.fromRGB(32, 43, 71)
local GREEN = Color3.fromRGB(60, 255, 60)
local ATLAS = "rbxassetid://121915283083474"
-- Collection card (design doc 4.22; all placeholders).
local CARD_DARK = Color3.fromRGB(14, 14, 20)
local GOLD = Color3.fromRGB(255, 214, 72)
local SECRET_TINT = Color3.fromRGB(96, 56, 170)
local SECRET_RIM = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 220, 90)),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(90, 230, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 110, 255)),
})
local CATEGORY_COLORS = {
	Sprinter = Color3.fromRGB(255, 110, 70),
	Balanced = Color3.fromRGB(70, 180, 100),
	Marathoner = Color3.fromRGB(80, 160, 255),
}
local PORTRAIT_FIT = 0.72 -- view height, as a share of feet-to-head height
local PORTRAIT_DROP = 0.2 -- camera aim below the head, same share
local CARD_PORTRAIT_HEIGHT = 0.75 -- drawn portrait's height on a card (placeholder): keeps the face above the card's text
local INDEX_COLUMNS = { Desktop = 4, Phone = 3 }
local INDEX_GAP = 12
local INDEX_CELL_HEIGHT = 168
local ICONS = {
	cash = 0,
	speed = 1,
	luck = 2,
	workshop = 3,
	rebirth = 11,
}

local function make(class, props, parent)
	local instance = Instance.new(class)
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(parent)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, parent)
end

local function edge(parent, color)
	return make(
		"UIStroke",
		{ Color = color or BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		parent
	)
end

function Components.Tint(button, color)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	button.BackgroundColor3 = WHITE
	if not gradient then
		gradient = make("UIGradient", { Rotation = 90 }, button)
	end
	gradient.Color = ColorSequence.new(color:Lerp(WHITE, 0.12), color:Lerp(BLACK, 0.12))
end

local function face(class, name, pos, size, color, parent)
	local props =
		{ Name = name, Position = pos, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3 }
	if class == "TextButton" then
		props.Text = ""
		props.AutoButtonColor = false
	end
	local object = make(class, props, parent)
	round(object)
	edge(object)
	Components.Tint(object, color)
	local lift = make("Frame", {
		Name = "Lift",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 6),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, object)
	round(lift)
	return object
end

local function label(parent, name, value, pos, size, textSize, color)
	local result = make("TextLabel", {
		Name = name,
		Text = value,
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		Font = Enum.Font.FredokaOne,
		TextSize = textSize,
		TextColor3 = color or WHITE,
		ZIndex = 5,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	make("UIStroke", { Color = BLACK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, result)
	return result
end

local function picture(parent, name, icon, pos, size)
	local i = ICONS[icon] or ICONS.speed
	return make("ImageLabel", {
		Name = name,
		Image = ATLAS,
		BackgroundTransparency = 1,
		ImageRectOffset = Vector2.new(i % 4 * 256, math.floor(i / 4) * 256),
		ImageRectSize = Vector2.new(256, 256),
		Position = pos,
		Size = size,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
	}, parent)
end

-- A stat icon from the atlas (cash, speed, luck, workshop, rebirth).
function Components.IconArt(parent, name, icon, pos, size)
	return picture(parent, name, icon, pos, size)
end

-- The character's placeholder runner rig (docs/WORLD_REDESIGN_SPEC.md sections 1-2), front three-quarter view.
-- Idempotent. Rigs face -Z.
-- `portrait`: the collection card's framing, upper body filling the view (design doc 4.22).
function Components.FillRunner(view, spec, name, portrait)
	name = name or "Runner"
	if view:FindFirstChild(name) then
		return true
	end
	local RunnerFactory = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").RunnerFactory)
	local rig = RunnerFactory.build(spec.Id)
	rig.Name = name
	local nameLabel = rig:FindFirstChild("NameLabel")
	if nameLabel then
		nameLabel:Destroy() -- the tile shows the name itself
	end
	rig.Parent = view
	local box, extents = rig:GetBoundingBox()
	local camera = view.CurrentCamera or make("Camera", { Name = "Camera", FieldOfView = 30 }, view)
	view.CurrentCamera = camera
	if portrait then
		-- From the head, not the bounding box: a tall weapon or hat must not push the face down the card.
		local head = rig:FindFirstChild("Head")
		local top = head and head.Position.Y or box.Position.Y + extents.Y / 2
		local height = top - (box.Position.Y - extents.Y / 2)
		local focus = Vector3.new(box.Position.X, top - height * PORTRAIT_DROP, box.Position.Z)
		local distance = PORTRAIT_FIT * height / 2 / math.tan(math.rad(15))
		camera.CFrame = CFrame.lookAt(focus + Vector3.new(-0.35, 0.08, -1).Unit * distance, focus)
		return true
	end
	local distance = 0.62 * extents.Magnitude / 2 / math.sin(math.rad(15))
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(-0.6, 0.35, -1).Unit * distance, box.Position)
	return true
end

function Components.RunnerArt(parent, name, spec, pos, size, portrait)
	local view = make("ViewportFrame", {
		Name = name,
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		Ambient = Color3.fromRGB(175, 175, 185),
		LightColor = WHITE,
		LightDirection = Vector3.new(-1, -2, -1),
		ZIndex = 4,
	}, parent)
	Components.FillRunner(view, spec, nil, portrait)
	return view
end

-- The drawn portrait for a spec (CHARACTER_GACHA_SPEC "Digital art portrait"), or nil with none yet: its own, the one of
-- the model it wears, or for an enemy (Id = a model name) the portrait of the character who wears that model.
local wearerPortrait = nil
function Components.PortraitImage(spec)
	if not wearerPortrait then
		wearerPortrait = {}
		for _, character in CharacterCatalog.All() do
			if character.Model and CharacterPortraits[character.Id] then
				wearerPortrait[character.Model] = CharacterPortraits[character.Id]
			end
		end
	end
	return CharacterPortraits[spec.Id] or CharacterPortraits[spec.Model or spec.Id] or wearerPortrait[spec.Id]
end

local function portraitLabel(parent, name, image, pos, size)
	return make("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Image = image,
		ImageColor3 = WHITE,
		ScaleType = Enum.ScaleType.Fit,
		Position = pos,
		Size = size,
		ZIndex = 4,
	}, parent)
end

-- The drawn portrait as an ImageLabel, or with none yet the live model (RunnerArt) in the same rect.
function Components.PortraitArt(parent, name, spec, pos, size, framing)
	local image = Components.PortraitImage(spec)
	if image then
		return portraitLabel(parent, name, image, pos, size)
	end
	return Components.RunnerArt(parent, name, spec, pos, size, framing)
end

-- A collection card's Art. A drawn portrait stops above the card's bottom text; the live model fills the card.
function Components.CardArt(tile, spec)
	local image = Components.PortraitImage(spec)
	if image then
		return portraitLabel(tile, "Art", image, UDim2.new(), UDim2.fromScale(1, CARD_PORTRAIT_HEIGHT))
	end
	return Components.RunnerArt(tile, "Art", spec, UDim2.new(), UDim2.fromScale(1, 1), true)
end

-- The collection card shared by the Index and the Backpack (design doc 4.22). `lit` false = undiscovered.
function Components.TintCard(tile, spec, config, lit)
	local color = spec.Rarity == "Secret" and SECRET_TINT or config.RARITY_COLORS[spec.Rarity] or WHITE
	tile.Tint.Color =
		ColorSequence.new(color:Lerp(CARD_DARK, lit and 0.45 or 0.75), color:Lerp(CARD_DARK, lit and 0.85 or 0.95))
end

function Components.CardFace(tile, spec, config)
	tile.BackgroundColor3 = WHITE
	tile.BorderSizePixel = 0
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, tile)
	make("UIGradient", { Name = "Tint", Rotation = 90 }, tile)
	Components.TintCard(tile, spec, config, true)
	local shade = make("Frame", {
		Name = "Shade",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.6),
		BackgroundColor3 = CARD_DARK,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, tile)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, shade)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(1, 0.05),
	}, shade)
	local rim = make("Frame", {
		Name = "Rim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, tile)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, rim)
	local rimEdge = make("UIStroke", {
		Color = spec.Rarity == "Secret" and WHITE or config.RARITY_COLORS[spec.Rarity] or WHITE,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, rim)
	if spec.Rarity == "Secret" then
		make("UIGradient", { Color = SECRET_RIM, Rotation = 45 }, rimEdge)
	end
	local category = make("TextLabel", {
		Name = "Category",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = CATEGORY_COLORS[spec.Category] or CATEGORY_COLORS.Balanced,
		BorderSizePixel = 0,
		Text = string.sub(spec.Category or "Balanced", 1, 1),
		Font = Enum.Font.FredokaOne,
		TextSize = 16,
		TextColor3 = WHITE,
		ZIndex = 7,
	}, tile)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, category)
	make("UIStroke", { Color = BLACK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, category)
	return category
end

local function scroll(host, name)
	local grid = make("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Color3.fromRGB(30, 216, 255),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		ZIndex = 3,
	}, host)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 10),
	}, grid)
	return grid
end

function Components.BakeIndex(refs, catalog, config)
	local grid = scroll(refs.GridHost, "Gallery")
	grid:SetAttribute("DesignVersion", 2)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, INDEX_CELL_HEIGHT),
		CellPadding = UDim2.fromOffset(INDEX_GAP, INDEX_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, grid)
	for _, spec in ipairs(catalog.All()) do
		local tile = make("Frame", { Name = spec.Id, LayoutOrder = spec.Order, ZIndex = 3 }, grid)
		Components.CardFace(tile, spec, config)
		edge(tile).Name = "Stroke"
		local art = Components.CardArt(tile, spec)
		art.ImageColor3 = Color3.new(0, 0, 0)
		local locked = label(tile, "Locked", "?", UDim2.new(0.5, -20, 0.5, -38), UDim2.fromOffset(40, 40), 34)
		locked.ZIndex = 7
		local odds =
			label(tile, "Odds", HudFormat.Odds(spec.Chance), UDim2.fromOffset(9, 8), UDim2.new(1, -40, 0, 20), 14, GOLD)
		odds.ZIndex = 7
		odds.TextXAlignment = Enum.TextXAlignment.Left
		local info = label(tile, "Info", spec.Rarity, UDim2.fromOffset(8, 90), UDim2.new(1, -16, 0, 18), 15, GOLD)
		info.ZIndex = 7
		info.TextXAlignment = Enum.TextXAlignment.Right
		local name = label(tile, "CharacterName", "???", UDim2.fromOffset(8, 106), UDim2.new(1, -16, 0, 24), 20)
		name.ZIndex = 7
		name.TextXAlignment = Enum.TextXAlignment.Right
		local equip = face("TextButton", "Equip", UDim2.new(0, 8, 1, -38), UDim2.new(1, -16, 0, 30), GREEN, tile)
		equip.ZIndex = 7
		label(equip, "Label", "EQUIP", UDim2.new(), UDim2.fromScale(1, 1), 15)
		equip.Visible = false
		tile:SetAttribute("CharacterId", spec.Id)
	end
end

-- Sizes a card grid to its host's columns, now and on every resize.
local function fitCells(host, layout)
	local function fit()
		local phone = workspace.CurrentCamera.ViewportSize.Y <= 500
		local columns = phone and INDEX_COLUMNS.Phone or INDEX_COLUMNS.Desktop
		-- UIScale is inherited from the generated host; its Size is in design pixels.
		local width = host.Size.X.Offset - 14
		layout.CellSize = UDim2.fromOffset(math.floor((width - (columns - 1) * INDEX_GAP) / columns), INDEX_CELL_HEIGHT)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	host:GetPropertyChangedSignal("Size"):Connect(fit)
	fit()
end

function Components.BindIndex(refs, catalog)
	local grid = refs.GridHost:WaitForChild("Gallery")
	local tiles = {}
	for _, spec in ipairs(catalog.All()) do
		local tile = grid:WaitForChild(spec.Id)
		tiles[spec.Id] = {
			Frame = tile,
			Art = tile.Art,
			Name = tile.CharacterName,
			Info = tile.Info,
			Locked = tile.Locked,
			Equip = tile.Equip,
			Category = tile.Category,
			Stroke = tile.Stroke,
			Spec = spec,
		}
	end
	for _, tile in tiles do
		if tile.Art:IsA("ViewportFrame") then
			Components.FillRunner(tile.Art, tile.Spec, nil, true)
		end
	end
	-- The models load in the background: swap the placeholder rigs once they arrive.
	task.spawn(function()
		local models = game:GetService("ReplicatedStorage"):WaitForChild("CharacterModels")
		if models:GetAttribute("Ready") ~= true then
			models:GetAttributeChangedSignal("Ready"):Wait()
		end
		for _, tile in tiles do
			if tile.Art:IsA("ViewportFrame") then
				local old = tile.Art:FindFirstChild("Runner")
				if old then
					old:Destroy()
				end
				Components.FillRunner(tile.Art, tile.Spec, nil, true)
			end
		end
	end)
	fitCells(refs.GridHost, grid:FindFirstChildOfClass("UIGridLayout"))
	return tiles
end

-- The Defeated Enemies page (design doc 4.29), inside GridHost so it follows the panel's desktop and phone layouts.
-- A locked tile has no Portrait and an empty EnemyName: nothing about the enemy reaches the screen. Returns the page
-- and its tiles in track order.
local ENEMY_CARD = { RARITY_COLORS = { Enemy = UiTheme.Palette.Danger } }
function Components.EnemiesPage(refs, player)
	local page = scroll(refs.GridHost, "EnemiesPage")
	page.Visible = false
	local layout = make("UIGridLayout", {
		CellPadding = UDim2.fromOffset(INDEX_GAP, INDEX_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, page)
	fitCells(refs.GridHost, layout)
	local frames, rows = {}, {}
	for n, enemy in ipairs(NpcConfig.Tracks) do
		local spec = { Id = enemy.Model, Rarity = "Enemy" }
		local tile = make("Frame", { Name = "Enemy" .. n, LayoutOrder = n, ZIndex = 3 }, page)
		Components.CardFace(tile, spec, ENEMY_CARD):Destroy() -- enemies have no category
		edge(tile).Name = "Stroke"
		local locked = label(tile, "Locked", "?", UDim2.new(0.5, -20, 0.5, -28), UDim2.fromOffset(40, 40), 34)
		locked.ZIndex = 7
		local lockedTrack =
			label(tile, "LockedTrack", "TRACK " .. n, UDim2.new(0, 8, 1, -30), UDim2.new(1, -16, 0, 20), 16)
		lockedTrack.ZIndex = 7
		local name = label(tile, "EnemyName", "", UDim2.new(0, 8, 1, -54), UDim2.new(1, -16, 0, 24), 20)
		name.ZIndex = 7
		name.TextXAlignment = Enum.TextXAlignment.Right
		local best = label(tile, "BestTime", "", UDim2.new(0, 8, 1, -30), UDim2.new(1, -16, 0, 20), 16, GOLD)
		best.ZIndex = 7
		best.TextXAlignment = Enum.TextXAlignment.Right
		frames[n] = tile
		rows[n] = {
			Frame = tile,
			Spec = spec,
			Label = enemy.Label,
			Locked = locked,
			LockedTrack = lockedTrack,
			Name = name,
			Best = best,
		}
	end
	local function refresh()
		local reached = player:GetAttribute("BestTrack") or 0
		for n, row in rows do
			local beaten = reached >= n
			local seconds = player:GetAttribute("RaceBest" .. n)
			row.Frame:SetAttribute("Beaten", beaten)
			Components.TintCard(row.Frame, row.Spec, ENEMY_CARD, beaten)
			row.Locked.Visible = not beaten
			row.LockedTrack.Visible = not beaten
			row.Name.Text = beaten and row.Label or ""
			-- A win saved before best times existed has no time to show.
			row.Best.Text = not beaten and "" or seconds and RaceProgressMap.FormatTime(seconds) or "--:--.--"
			local portrait = row.Frame:FindFirstChild("Portrait")
			if beaten and not portrait then
				Components.PortraitArt(row.Frame, "Portrait", row.Spec, UDim2.new(), UDim2.fromScale(1, 1), true)
			elseif portrait and not beaten then
				portrait:Destroy()
			end
		end
	end
	player.AttributeChanged:Connect(function(attribute)
		if attribute == "BestTrack" or string.sub(attribute, 1, 8) == "RaceBest" then
			refresh()
		end
	end)
	refresh()
	-- The models load in the background: rebuild any placeholder portraits once they arrive.
	task.spawn(function()
		local models = game:GetService("ReplicatedStorage"):WaitForChild("CharacterModels")
		if models:GetAttribute("Ready") ~= true then
			models:GetAttributeChangedSignal("Ready"):Wait()
		end
		for _, tile in frames do
			local portrait = tile:FindFirstChild("Portrait")
			if portrait then
				portrait:Destroy()
			end
		end
		refresh()
	end)
	return page, frames
end

function Components.BakeStats(refs, config)
	local list = scroll(refs.StatsHost, "Rows")
	list:SetAttribute("DesignVersion", 2)
	list.ScrollBarImageColor3 = Color3.fromRGB(172, 99, 238)
	local padding = list:FindFirstChildOfClass("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	make("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, list)
	local names = {
		Speed = "CRUISE MULTIPLIER",
		Money = "MONEY MULTIPLIER",
		Luck = "LUCK MULTIPLIER",
		Stamina = "STAMINA MULTIPLIER",
	}
	local arts = { Speed = "speed", Money = "cash", Luck = "luck", Stamina = "speed" } -- shortcut: no stamina atlas art yet
	local colours = {
		Speed = Color3.fromRGB(24, 202, 239),
		Money = Color3.fromRGB(255, 194, 18),
		Luck = Color3.fromRGB(88, 225, 80),
		Stamina = Color3.fromRGB(70, 120, 255),
	}
	for i, stat in ipairs(config.STATS) do
		local colour = colours[stat]
		local row = face("Frame", stat, UDim2.new(), UDim2.new(1, -16, 0, 82), Color3.fromRGB(235, 238, 244), list)
		row.LayoutOrder = i
		row:SetAttribute("AccentColor", colour)
		row:FindFirstChildOfClass("UIStroke").Color = colour
		row:FindFirstChildOfClass("UIGradient"):Destroy()
		row.BackgroundColor3 = Color3.fromRGB(242, 244, 247)
		picture(row, "Art", arts[stat], UDim2.fromOffset(6, 7), UDim2.fromOffset(66, 66))
		local statName = label(row, "StatName", names[stat], UDim2.fromOffset(80, 5), UDim2.new(1, -238, 0, 25), 21)
		statName.TextColor3 = Color3.fromRGB(43, 45, 54)
		statName.TextXAlignment = Enum.TextXAlignment.Left
		statName:FindFirstChildOfClass("UIStroke").Transparency = 1
		local description = label(
			row,
			"Description",
			string.format("+%d%% %s per point", math.floor(config.PER_POINT[stat] * 100 + 0.5), stat),
			UDim2.fromOffset(80, 31),
			UDim2.new(1, -238, 0, 20),
			15,
			Color3.fromRGB(111, 114, 123)
		)
		description.TextXAlignment = Enum.TextXAlignment.Left
		description:FindFirstChildOfClass("UIStroke").Transparency = 1
		local accent = make("Frame", {
			Name = "Accent",
			Position = UDim2.fromOffset(80, 58),
			Size = UDim2.new(1, -244, 0, 11),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, row)
		round(accent)
		local value = label(
			row,
			"Value",
			"0 pts  x1.00  >  x1.00",
			UDim2.new(1, -230, 0, 27),
			UDim2.fromOffset(150, 24),
			15,
			colour
		)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value:FindFirstChildOfClass("UIStroke").Color = WHITE
		local plus = face("TextButton", "Plus", UDim2.new(1, -72, 0, 10), UDim2.fromOffset(60, 60), colour, row)
		label(plus, "Label", "+", UDim2.new(), UDim2.fromScale(1, 1), 34)
	end
end

function Components.BakeHud(refs)
	round(refs.TurboFill)
	-- StarterGui contains a baked HUD from before the Level/XP meter was added.
	-- Add the meter at runtime as well, so an asset/Rojo resync is not required
	-- for the progression HUD to appear in an existing place.
	if not refs.LevelFill or not refs.LevelLabel then
		local level = face("Frame", "Level", UDim2.new(0.5, 0, 1, -60), UDim2.fromOffset(250, 32), DARK, refs.Gui)
		level.AnchorPoint = Vector2.new(0.5, 1)
		level.BackgroundTransparency = 0
		local fill = make("Frame", {
			Name = "LevelFill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.fromRGB(30, 216, 255),
			BorderSizePixel = 0,
			ZIndex = 4,
		}, level)
		round(fill)
		local text = label(level, "LevelLabel", "LEVEL 1  0/100 XP", UDim2.new(), UDim2.fromScale(1, 1), 18)
		text.TextXAlignment = Enum.TextXAlignment.Center
		refs.Level = level
		refs.LevelFill = fill
		refs.LevelLabel = text
	end
	local badge = make("TextLabel", {
		Name = "PointsBadge",
		Position = UDim2.new(1, -16, 0, -10),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(255, 77, 94),
		BorderSizePixel = 0,
		Text = "1",
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 5,
	}, refs.Stats)
	round(badge)
	edge(badge)
	badge.Visible = false
end

function Components.BindStats(refs, config)
	local list = refs.StatsHost:WaitForChild("Rows")
	local rows = {}
	for _, stat in ipairs(config.STATS) do
		local row = list:WaitForChild(stat)
		rows[stat] = { Frame = row, Value = row.Value, Plus = row.Plus }
	end
	local function fit()
		local phone = workspace.CurrentCamera.ViewportSize.Y <= 500
		for _, row in pairs(rows) do
			row.Frame.StatName.TextSize = phone and 17 or 21
			row.Value.TextSize = phone and 13 or 15
			local description = row.Frame:FindFirstChild("Description")
			if description then
				description.TextSize = phone and 12 or 15
			end
		end
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	return rows
end

return Components
