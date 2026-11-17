--!nonstrict
-- The Sakura Dojo page transition (design doc 4.45, docs/UI_FEEDBACK_SPEC.md section 5, owner 2026-11-17): cream shoji
-- paper panels sweep across the screen right to left with sakura petals blowing ahead of them, while the page opens or
-- closes behind. One reused ScreenGui; never takes input. Reduced motion: a short cream fade, no petals. A call while
-- one runs is ignored. Timings proposed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local D = UiTheme.Dojo
local SWEEP_IN, SWEEP_OUT = 0.25, 0.25
local FADE = 0.15
local PETALS = 12
local PANELS = 4

local UiTransition = {}

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local root, paper, accentStrip, fade
local petals = {}

local function build()
	if root and root.Parent then
		return
	end
	root = make("ScreenGui", "UiTransition", Players.LocalPlayer:WaitForChild("PlayerGui"), {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40, -- above the panels, under popups' confirm dialogs
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	root:SetAttribute("Playing", false)
	paper = make("Frame", "Paper", root, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(1.05, 0.5),
		Size = UDim2.fromScale(1.2, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Active = false,
	})
	make("UIListLayout", "Layout", paper, { FillDirection = Enum.FillDirection.Horizontal })
	for i = 1, PANELS do
		-- A shoji panel: cream paper in a dark wood frame, with a thin lattice.
		local panel = make("Frame", "Panel" .. i, paper, {
			LayoutOrder = i,
			Size = UDim2.fromScale(1 / PANELS, 1),
			BackgroundColor3 = D.Cream,
			BorderSizePixel = 0,
		})
		make("UIStroke", "Frame", panel, { Color = D.WoodDark, Thickness = 4 })
		for k = 1, 2 do
			make("Frame", "Mullion" .. k, panel, {
				Position = UDim2.fromScale(k / 3, 0),
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = D.Wood,
				BorderSizePixel = 0,
			})
		end
		for k = 1, 4 do
			make("Frame", "Rail" .. k, panel, {
				Position = UDim2.fromScale(0, k / 5),
				Size = UDim2.new(1, 0, 0, 2),
				BackgroundColor3 = D.Wood,
				BorderSizePixel = 0,
			})
		end
	end
	accentStrip = make("Frame", "Accent", paper, {
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = D.Sakura,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	accentStrip.Parent = root -- outside the list layout; follows the paper's leading edge
	fade = make("Frame", "Fade", root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = D.Cream,
		BackgroundTransparency = 1,
		Visible = false,
	})
	for i = 1, PETALS do
		petals[i] = make("ImageLabel", "Petal" .. i, root, {
			BackgroundTransparency = 1,
			Image = D.Petal,
			ImageColor3 = D.Sakura,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(26, 26),
			Visible = false,
			ZIndex = 3,
		})
	end
end

-- Plays the sweep once with `accent` (a Color3, the page's colour) on the paper's leading edge. Returns false when one
-- is already running (the call is ignored).
function UiTransition.Play(accent)
	build()
	if root:GetAttribute("Playing") then
		return false
	end
	root:SetAttribute("Playing", true)
	local function done()
		paper.Visible, accentStrip.Visible, fade.Visible = false, false, false
		for _, petal in petals do
			petal.Visible = false
		end
		root:SetAttribute("Playing", false)
	end
	if UiMotion.Reduced() then
		fade.Visible, fade.BackgroundTransparency = true, 0.4
		local t = UiMotion.Create(fade, TweenInfo.new(FADE), { BackgroundTransparency = 1 })
		t:Play()
		task.delay(FADE, done)
		return true
	end
	accentStrip.BackgroundColor3 = accent or D.Sakura
	paper.Position, paper.Visible, accentStrip.Visible = UDim2.fromScale(1.05, 0.5), true, true
	local function edge(x)
		return UDim2.new(x, -6, 0, 0)
	end
	accentStrip.Position = edge(1.05)
	accentStrip.Size = UDim2.new(0, 6, 1, 0)
	local inInfo = TweenInfo.new(SWEEP_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local outInfo = TweenInfo.new(SWEEP_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UiMotion.Create(paper, inInfo, { Position = UDim2.fromScale(-0.1, 0.5) }):Play()
	UiMotion.Create(accentStrip, inInfo, { Position = edge(-0.1) }):Play()
	-- Petals ride just ahead of the paper and drift on past it.
	for _, petal in petals do
		local y = math.random()
		petal.Position = UDim2.fromScale(1.05 + math.random() * 0.1, y)
		petal.Rotation = math.random(0, 360)
		petal.ImageTransparency = 0.1
		petal.Visible = true
		UiMotion.Create(petal, TweenInfo.new(SWEEP_IN + SWEEP_OUT, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(-0.15 - math.random() * 0.1, y + (math.random() - 0.5) * 0.2),
			Rotation = petal.Rotation + math.random(180, 420),
			ImageTransparency = 0.6,
		}):Play()
	end
	task.delay(SWEEP_IN + 0.05, function()
		UiMotion.Create(paper, outInfo, { Position = UDim2.fromScale(-1.3, 0.5) }):Play()
		UiMotion.Create(accentStrip, outInfo, { Position = edge(-1.3) }):Play()
		task.delay(SWEEP_OUT, done)
	end)
	return true
end

function UiTransition.Playing()
	return root ~= nil and root:GetAttribute("Playing") == true
end

return UiTransition
