--!nonstrict
-- The game-wide anime look (design doc 4.42): Client/IndexAnimeStyle's art and text treatment as parts any panel,
-- popup, tab or button can wear. Display only: each screen keeps its own layout, names and remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IndexStyle = require(script.Parent:WaitForChild("IndexAnimeStyle"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local ART, INK, image, text = IndexStyle.Art, IndexStyle.Ink, IndexStyle.Image, IndexStyle.Text
local Skin = { Art = ART, Ink = INK, Text = text }
Skin.Font = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
-- Card and plate tints (placeholders); Default is the Index's card blue.
Skin.Tint = {
	Default = Color3.fromRGB(70, 205, 255),
	Ready = Color3.fromRGB(60, 230, 120),
	Muted = Color3.fromRGB(120, 125, 140),
	Gold = Color3.fromRGB(255, 205, 60),
	Danger = Color3.fromRGB(255, 80, 90),
}
-- Action button fills: Go is the Index's EQUIP green.
local FILL = {
	Go = UiTheme.Palette.MoneyDeep,
	Idle = Color3.fromRGB(34, 40, 66),
	Danger = Color3.fromRGB(215, 50, 70),
	Gold = Color3.fromRGB(235, 160, 20),
}

local function child(parent, class, name)
	local found = parent:FindFirstChild(name)
	if not found then
		found = Instance.new(class)
		found.Name = name
		found.Parent = parent
	end
	return found
end

-- The object's own fill and edge give way to art. Fades tween BackgroundTransparency, so the fill hides through a
-- fully clear gradient instead, which no fade touches.
local function clear(gui)
	local gradient = gui:FindFirstChildOfClass("UIGradient") or child(gui, "UIGradient", "AnimeClear")
	gradient.Transparency = NumberSequence.new(1)
	for _, d in gui:GetChildren() do
		if d:IsA("UIStroke") and d.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			d.Enabled = false
		end
	end
end
Skin.Clear = clear

-- The plain framed body (magenta and cyan edges, cut corners) behind a panel or popup.
function Skin.Body(panel, inset)
	clear(panel)
	local pad = inset or 8
	local body = panel:FindFirstChild("AnimeBody") or image(panel, "AnimeBody", ART.Body, UDim2.new(), UDim2.new(), 0)
	body.Position, body.Size = UDim2.fromOffset(-pad, -pad), UDim2.new(1, 2 * pad, 1, 2 * pad)
	body.ZIndex = 0
	return body
end

-- The slanted cyan-to-violet strip under a header's title. `left` is where it starts (after the logo).
function Skin.Strip(header, left)
	clear(header)
	header.ClipsDescendants = false
	local strip = header:FindFirstChild("AnimeStrip")
		or image(header, "AnimeStrip", ART.Header, UDim2.new(), UDim2.new(), 0) -- under the header's own parts
	strip.Position, strip.Size = UDim2.new(0, left or 0, 0, 4), UDim2.new(1, -(left or 0), 1, -8)
	return strip
end

-- Heavy italic white with the dark outline, sized to fit (at most `max` px). Again next frame: UiTheme.Apply's
-- deferred DescendantAdded puts new text back on Fredoka.
local function title(label, max)
	text(label, max or 30)
	task.defer(function()
		if label.Parent then
			text(label, max or 30)
		end
	end)
end
Skin.Title = title

-- The art close: the button stays (and keeps its name and size) under the art.
function Skin.Close(button, label)
	clear(button)
	button.BackgroundTransparency = 1
	if button:IsA("TextButton") then
		button.TextTransparency = 1
	end
	if button:IsA("GuiButton") then
		button.AutoButtonColor = false
	end
	local caption = label or button:FindFirstChild("X")
	if caption then
		caption.Visible = false
	end
	local art = button:FindFirstChild("AnimeCloseArt")
		or image(
			button,
			"AnimeCloseArt",
			ART.Close,
			UDim2.fromScale(0.5, 0.5),
			UDim2.fromScale(1.3, 1.3),
			button.ZIndex + 1
		)
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.ScaleType = Enum.ScaleType.Fit
	return art
end

-- An art tab. `index` picks the Index's tab art (1 cyan, 2 gold, 3 and 4 violet). The button keeps its Text for
-- the UI tests; a caption on top shows it. Returns a function that marks the tab lit or not.
function Skin.Tab(button, index)
	clear(button)
	button.BackgroundTransparency = 1
	if not button:FindFirstChild("AnimeTabArt") then
		local art = image(
			button,
			"AnimeTabArt",
			ART.Tabs[((index or 1) - 1) % #ART.Tabs + 1],
			UDim2.new(0, -5, 0, -4),
			UDim2.new(1, 10, 1, 8),
			button.ZIndex + 1
		)
		art.ZIndex = 1
	end
	-- A tab whose words are a child label keeps it, raised over the art; a TextButton's own Text gets a caption.
	local caption = button:FindFirstChild("AnimeCaption")
	if not caption then
		for _, d in button:GetChildren() do
			if d:IsA("TextLabel") then
				caption = d
			end
		end
	end
	if not caption and button:IsA("TextButton") then
		caption = Instance.new("TextLabel")
		caption.Name = "AnimeCaption"
		caption.BackgroundTransparency = 1
		caption.Position, caption.Size = UDim2.fromOffset(6, 0), UDim2.new(1, -12, 1, 0)
		caption.Parent = button
		local function sync()
			caption.Text = button.Text
			button.TextTransparency = 1
		end
		sync()
		button:GetPropertyChangedSignal("Text"):Connect(sync)
	end
	if caption then
		caption.ZIndex = 3
		-- Narrow tabs (the Backpack's side rail) need smaller text than Issac's 10 px floor.
		local function fit()
			text(caption, 20)
			caption:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize = 6
		end
		fit()
		task.defer(function()
			if caption.Parent then
				fit()
			end
		end)
	end
	return function(lit)
		button.AnimeTabArt.ImageColor3 = lit and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 170)
	end
end

-- An Index-style action button: flat fill, small corners, heavy italic outlined text. tone: Go, Idle, Danger, Gold.
function Skin.Button(button, tone)
	for _, gradient in button:GetChildren() do
		if gradient:IsA("UIGradient") then
			gradient.Enabled = false
		end
	end
	button.BackgroundColor3 = FILL[tone or "Go"] or FILL.Go
	local corner = button:FindFirstChildOfClass("UICorner") or child(button, "UICorner", "Corner")
	corner.CornerRadius = UDim.new(0, 4)
	if button:IsA("TextButton") then
		button.FontFace = Skin.Font
		button.TextColor3 = Color3.new(1, 1, 1)
	end
end

-- The angular card art behind a tile, tinted (rarity colour, state, or the Index's blue).
function Skin.Card(frame, tint)
	clear(frame)
	local card = frame:FindFirstChild("AnimeCard")
		or image(frame, "AnimeCard", ART.Card, UDim2.fromOffset(-3, -3), UDim2.new(1, 6, 1, 6), 0)
	card.ImageColor3 = tint or Skin.Tint.Default
	return card
end

-- The slanted name plate behind a wide row, tinted.
function Skin.Plate(frame, tint)
	clear(frame)
	local plate = frame:FindFirstChild("AnimePlate")
		or image(frame, "AnimePlate", ART.Plate, UDim2.new(), UDim2.fromScale(1, 1), 0)
	plate.ImageColor3 = tint or Skin.Tint.Default
	return plate
end

return Skin
