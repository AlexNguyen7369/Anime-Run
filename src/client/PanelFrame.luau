--!nonstrict
-- Shared Backpack-style chrome; adopts existing controls so fixtures/remotes keep their paths.
local Band = require(script.Parent.PanelBand)
local UiTheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UiTheme"))
local Skin = require(script.Parent:WaitForChild("AnimeSkin"))
local Frame = {}
-- Header gradients (placeholders).
Frame.Themes = {
	Daily = { Color3.fromRGB(160, 15, 32), Color3.fromRGB(244, 55, 69) },
	Quests = { Color3.fromRGB(55, 80, 190), Color3.fromRGB(75, 180, 240) },
	Shop = { Color3.fromRGB(121, 65, 200), Color3.fromRGB(212, 110, 230) },
	Market = { Color3.fromRGB(255, 160, 60), Color3.fromRGB(250, 90, 170) },
	Backpack = { Color3.fromRGB(104, 104, 245), Color3.fromRGB(80, 170, 250) },
	Checkpoints = { Color3.fromRGB(150, 80, 240), Color3.fromRGB(90, 120, 250) },
	Index = { Color3.fromRGB(20, 130, 200), Color3.fromRGB(30, 216, 255) },
	Rebirth = { Color3.fromRGB(190, 50, 170), Color3.fromRGB(240, 90, 200) },
	Settings = { Color3.fromRGB(70, 80, 110), Color3.fromRGB(110, 125, 160) },
	Stats = { Color3.fromRGB(90, 60, 200), Color3.fromRGB(172, 99, 238) },
	Sidekicks = { Color3.fromRGB(20, 110, 130), Color3.fromRGB(60, 200, 190) },
}
local function child(parent, class, name)
	local value = parent:FindFirstChild(name)
	if not value then
		value = Instance.new(class)
		value.Name = name
		value.Parent = parent
	end
	return value
end

-- The one close button: the Index's art close (design doc 4.42). Geometry stays with the caller.
function Frame.PaintClose(close, labelObject)
	Frame.PaintFlatClose(close, labelObject)
	Skin.Close(close, labelObject or close:FindFirstChild("X"))
end

-- The older flat close (Danger, radius M, Outline edge, stroked X), under the art.
function Frame.PaintFlatClose(close, labelObject)
	local gradient = close:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient:Destroy()
	end
	close.BackgroundColor3 = UiTheme.Palette.Danger
	close.BackgroundTransparency = 0
	close.BorderSizePixel = 0
	close.AutoButtonColor = false
	close.Text = ""
	UiTheme.Corner(close, "M")
	local edge = close:FindFirstChildOfClass("UIStroke") or child(close, "UIStroke", "Stroke")
	edge.Color, edge.Thickness = UiTheme.Outline, 3
	edge.Transparency = 0
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local label = labelObject or close:FindFirstChild("X") or child(close, "TextLabel", "X")
	label.BackgroundTransparency = 1
	label.Font = UiTheme.Font
	label.Text = "X"
	label.TextColor3 = UiTheme.Palette.White
	label.ZIndex = close.ZIndex + 1
	if not labelObject then -- a generated label keeps its pinned rect and size
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		child(label, "UITextSizeConstraint", "Max").MaxTextSize = 30
	end
	local glyph = label:FindFirstChildOfClass("UIStroke") or child(label, "UIStroke", "Outline")
	glyph.Color, glyph.Thickness = UiTheme.Outline, 2
	glyph.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
end

-- The same look for the generated Racer panels. UiResponsive pins every rect and path of those screens, so this
-- paints their parts and leaves the geometry (their tabs stay in the header row).
-- parts: Panel, Header, Close (Face objects), CloseLabel, Theme.
function Frame.PaintGenerated(parts)
	UiTheme.Body(parts.Panel)
	parts.Panel.Active = true
	local colors = Frame.Themes[parts.Theme] or Frame.Themes.Backpack
	local header = parts.Header
	header.BackgroundColor3 = UiTheme.Palette.White
	local gradient = header:FindFirstChildOfClass("UIGradient") or child(header, "UIGradient", "Gradient")
	gradient.Color, gradient.Rotation = ColorSequence.new(colors[1], colors[2]), 0
	for _, face in { parts.Panel, header } do
		local edge = face:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Color, edge.Transparency = UiTheme.Outline, 0
		end
	end
	local wrapper = parts.Close.Parent
	local shadow = wrapper:FindFirstChild("Shadow")
	if shadow then
		shadow.Visible = false
	end
	local lift = parts.Close:FindFirstChild("Lift")
	if lift then
		lift.Visible = false
	end
	Frame.PaintClose(parts.Close, parts.CloseLabel)
	if parts.Theme == "Index" then
		return -- Client/IndexAnimeStyle dresses the Index in its own layout
	end
	-- Design doc 4.42: the framed body and the header strip; the generated shadows and lifts go.
	Skin.Body(parts.Panel)
	Skin.Strip(header)
	for _, face in { parts.Panel, header } do
		for _, name in { "Shadow", "Lift" } do
			local part = face:FindFirstChild(name) or (face.Parent and face.Parent:FindFirstChild(name))
			if part and part:IsA("GuiObject") then
				part.Visible = false
			end
		end
	end
	local heading = header:FindFirstChild("Title")
	if heading and heading:IsA("TextLabel") then
		Skin.Title(heading, 30)
	end
end

function Frame.Attach(panel, options)
	panel:SetAttribute("PanelFrame", true)
	panel.BorderSizePixel = 0
	panel.Active = true
	local rounding = panel:FindFirstChildOfClass("UICorner") or child(panel, "UICorner", "Corner")
	rounding.CornerRadius = UDim.new(0, UiTheme.Radius.L)
	UiTheme.Body(panel)
	local edge = panel:FindFirstChildOfClass("UIStroke") or child(panel, "UIStroke", "FrameOutline")
	edge.Color = UiTheme.Outline
	edge.Thickness = 3
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local header = child(panel, "Frame", "Header")
	header.Position = UDim2.new()
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	header.ClipsDescendants = true
	header.ZIndex = 2
	child(header, "UICorner", "Corner").CornerRadius = UDim.new(0, UiTheme.Radius.L)
	local gradient = header:FindFirstChildOfClass("UIGradient") or child(header, "UIGradient", "Gradient")
	local title = options.TitleObject or child(header, "TextLabel", "Title")
	title.BackgroundTransparency = 1
	title.Font = UiTheme.Font
	title.TextColor3 = UiTheme.Palette.White
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Rotation = 0
	title.TextScaled = true
	title.ZIndex = 4
	local sizeLimit = title:FindFirstChildOfClass("UITextSizeConstraint") or child(title, "UITextSizeConstraint", "Max")
	sizeLimit.MaxTextSize = 32
	local icon = options.IconObject or child(header, "ImageLabel", "Icon")
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 3
	local close = options.Close or child(header, "TextButton", "Close")
	close.AnchorPoint = Vector2.new(1, 0)
	close.ZIndex = 5
	Frame.PaintClose(close)
	-- Design doc 4.42: the framed body, the slanted strip, the HUD icon as an overhanging logo, the outlined title.
	Skin.Body(panel)
	local strip = Skin.Strip(header)
	panel.ClipsDescendants = false
	local function layout()
		local compact = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y <= 500
		local h = compact and 48 or 64
		header.Size = UDim2.new(1, 0, 0, h)
		close.Position = UDim2.new(1, -6, 0, 6)
		close.Size = UDim2.fromOffset(h - 12, h - 12)
		local logo = math.floor(h * 1.4)
		icon.Position = UDim2.fromOffset(-math.floor(h * 0.2), -math.floor(h * 0.45))
		icon.Size = UDim2.fromOffset(logo, logo)
		local left = logo - math.floor(h * 0.15)
		strip.Position, strip.Size = UDim2.fromOffset(math.floor(h * 0.5), 4), UDim2.new(1, -math.floor(h * 0.5), 1, -8)
		title.Position = UDim2.fromOffset(left, 4)
		-- A header toolbar (options.TitleEnd: where it starts) keeps the title's whole rect clear of its buttons.
		local stop = options.TitleEnd or UDim.new(1, -h - 12)
		title.Size = UDim2.new(stop.Scale, stop.Offset - left, 0, h - 8)
		Skin.Title(title, math.floor(h * 0.6))
	end
	local controller = {}
	function controller:SetTheme(theme, text, image)
		local colors = Frame.Themes[theme] or Frame.Themes.Backpack
		gradient.Color = ColorSequence.new(colors[1], colors[2])
		if text then
			title.Text = text
		end
		if image then
			icon.Image = image
		end
		panel:SetAttribute("PanelTheme", theme)
	end
	controller:SetTheme(options.Theme, options.Title, options.Icon)
	layout()
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	Band.Fit(panel, options.MaxWidth or 760)
	controller.Header, controller.Close = header, close
	return controller
end

-- Owner 2026-10-20 (HUD_LAYOUT_SPEC section 6): a panel's dim backdrop is a non-interactive Frame so the HUD
-- tiles behind it stay clickable; a click that no GUI handled (empty screen) closes the panel instead.
-- "Handled" is judged from the PlayerGui objects under the pointer (a GuiButton, TextBox or Active GuiObject takes
-- the click), not only from gameProcessedEvent, which can report true for a click on empty screen.
local function shown(object)
	while object do
		if
			(object:IsA("GuiObject") and not object.Visible) or (object:IsA("LayerCollector") and not object.Enabled)
		then
			return false
		end
		object = object.Parent
	end
	return true
end

local function takesClick(playerGui, position)
	for _, hit in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if (hit:IsA("GuiButton") or hit:IsA("TextBox") or hit.Active) and shown(hit) then
			return true
		end
	end
	return false
end

function Frame.CloseOnOutsideClick(backdrop, close)
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	game:GetService("UserInputService").InputBegan:Connect(function(input)
		local click = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		if click and backdrop.Visible and not takesClick(playerGui, input.Position) then
			close()
		end
	end)
end

return Frame
