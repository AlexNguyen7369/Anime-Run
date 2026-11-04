--!nonstrict
-- The one look of the floating plaza headers (design doc 4.24 Service headers): a bold white italic word with a dark
-- outline over a coloured emblem behind it. Plain GUI Instances, so no image upload. Display only. Sizes and colours
-- are proposed placeholders.
local PlazaHeader = {}

local OUTLINE = Color3.fromRGB(16, 20, 54)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local SQUARE_SIDE = 0.7 -- of the box height: a square turned 45 degrees then just fills the box, top to bottom
local TEXT_HEIGHT = 0.52 -- of the box height: the emblem pokes out above and below the word
local ANGLES = { Gem = { 45 }, Star = { 0, 45 } }

-- shape is "Gem" or "Star". Text and frames stay unthemed: nothing calls UiTheme.Apply on a world billboard.
function PlazaHeader.Build(adornee, name, text, shape, color, size, distance)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.Size = size
	gui.MaxDistance = distance -- AlwaysOnTop stays off: these billboards do not draw with it
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local rim = color:Lerp(Color3.new(), 0.3)
	-- The outline pass sits under a stroke-free rim pass, or a star's second square would draw its outline across the first.
	local layers = {
		{ Scale = 1, Color = rim, Outline = true },
		{ Scale = 1, Color = rim },
		{ Scale = 0.62, Color = Color3.new(1, 1, 1), Facet = true },
	}
	for z, layer in layers do
		for _, angle in ANGLES[shape] do
			local side = SQUARE_SIDE * layer.Scale
			local square = Instance.new("Frame")
			square.Name = "Emblem"
			square.SizeConstraint = Enum.SizeConstraint.RelativeYY
			square.Size = UDim2.fromScale(side, side)
			square.AnchorPoint = Vector2.new(0.5, 0.5)
			square.Position = UDim2.fromScale(0.5, 0.5)
			square.Rotation = angle
			square.BackgroundColor3 = layer.Color
			square.BorderSizePixel = 0
			square.ZIndex = z
			square.Parent = gui
			Instance.new("UICorner", square).CornerRadius = UDim.new(0.08, 0)
			if layer.Outline then
				local stroke = Instance.new("UIStroke")
				stroke.Color = OUTLINE
				stroke.Thickness = 3
				stroke.Parent = square
			end
			if layer.Facet then
				local gradient = Instance.new("UIGradient")
				gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.55), color)
				gradient.Rotation = 90 - angle -- light from the top of the screen, whatever the square's turn
				gradient.Parent = square
			end
		end
	end

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, TEXT_HEIGHT)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.ZIndex = #layers + 1
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = 3
	stroke.Parent = label

	gui.Parent = adornee
	return gui
end

return PlazaHeader
