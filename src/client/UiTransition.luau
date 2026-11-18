--!nonstrict
-- The Sakura Dojo page transition (design doc 4.45, docs/UI_FEEDBACK_SPEC.md section 5; owner reference 2026-11-17
-- "Close / return transition": page, then a full-screen wash of sakura petals, then the next view). A soft pink wash
-- fills the screen with large petals drifting through it while the page opens or closes behind, then clears. One reused
-- ScreenGui; never takes input. Reduced motion: a short pink fade, no petals. A call while one runs is ignored.
-- About 0.65 s in all (proposed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local D = UiTheme.Dojo
local IN, HOLD, OUT = 0.22, 0.12, 0.3
local FADE = 0.15
local PETALS = 22
local WASH_TOP = Color3.fromRGB(255, 196, 214)
local WASH_BOTTOM = Color3.fromRGB(226, 120, 158)

local UiTransition = {}
UiTransition.COVER = IN -- s from Play until the wash covers the screen: pages switch then, unseen
-- The wait before a page switches: COVER, or none under reduced motion (the fade is shorter than COVER).
function UiTransition.Cover()
	return UiMotion.Reduced() and 0 or UiTransition.COVER
end

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local root, paper, gradient
local petals = {}

local function build()
	if root and root.Parent then
		return
	end
	root = make("ScreenGui", "UiTransition", Players.LocalPlayer:WaitForChild("PlayerGui"), {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40, -- above the pages
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	root:SetAttribute("Playing", false)
	-- "Paper": the pink wash (kept under its first name for the UI tests).
	paper = make("Frame", "Paper", root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Active = false,
		ZIndex = 1,
	})
	gradient = make("UIGradient", "Wash", paper, { Rotation = 70, Color = ColorSequence.new(WASH_TOP, WASH_BOTTOM) })
	for i = 1, PETALS do
		petals[i] = make("ImageLabel", "Petal" .. i, root, {
			BackgroundTransparency = 1,
			Image = D.Petal,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Visible = false,
			Active = false,
			ZIndex = i % 3 == 0 and 0 or 2, -- a few behind the wash, softer
		})
	end
end

-- Plays the wash once; `accent` (a Color3, the page's colour) tints its lower edge a little. Returns false when one is
-- already running (the call is ignored).
function UiTransition.Play(accent)
	build()
	if root:GetAttribute("Playing") then
		return false
	end
	root:SetAttribute("Playing", true)
	gradient.Color = ColorSequence.new(WASH_TOP, accent and WASH_BOTTOM:Lerp(accent, 0.15) or WASH_BOTTOM)
	paper.Visible, paper.BackgroundTransparency = true, 1
	local function done()
		paper.Visible = false
		for _, petal in petals do
			petal.Visible = false
		end
		root:SetAttribute("Playing", false)
	end
	if UiMotion.Reduced() then
		paper.BackgroundTransparency = 0.3
		UiMotion.Create(paper, TweenInfo.new(FADE), { BackgroundTransparency = 1 }):Play()
		task.delay(FADE, done)
		return true
	end
	local total = IN + HOLD + OUT
	UiMotion.Create(paper, TweenInfo.new(IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.04,
	}):Play()
	-- Large petals drift down and across the whole screen, turning, over the full transition.
	for i, petal in petals do
		local size = math.random(46, 128)
		local x, y = math.random() * 1.2 - 0.1, math.random() * 1.1 - 0.35
		petal.Size = UDim2.fromOffset(size, size)
		petal.Position = UDim2.fromScale(x, y)
		petal.Rotation = math.random(0, 360)
		petal.ImageColor3 = (i % 3 == 0) and Color3.fromRGB(255, 220, 232) or Color3.fromRGB(255, 168, 196)
		petal.ImageTransparency = 1
		petal.Visible = true
		UiMotion.Create(petal, TweenInfo.new(IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			ImageTransparency = i % 3 == 0 and 0.35 or 0.05,
		}):Play()
		UiMotion.Create(petal, TweenInfo.new(total, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(x - 0.12 - math.random() * 0.1, y + 0.25 + math.random() * 0.15),
			Rotation = petal.Rotation + math.random(-160, 220),
		}):Play()
	end
	task.delay(IN + HOLD, function()
		local outInfo = TweenInfo.new(OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UiMotion.Create(paper, outInfo, { BackgroundTransparency = 1 }):Play()
		for _, petal in petals do
			UiMotion.Create(petal, outInfo, { ImageTransparency = 1 }):Play()
		end
		task.delay(OUT, done)
	end)
	return true
end

-- Built at require, so PlayerGui.UiTransition exists before the first page opens.
task.spawn(build)

function UiTransition.Playing()
	return root ~= nil and root:GetAttribute("Playing") == true
end

return UiTransition
