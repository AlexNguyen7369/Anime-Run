--!nonstrict
-- The summon altar activation before a reveal (design doc 4.45, SIDEKICK_SPEC "Sakura Dojo entry and transition", owner
-- 2026-11-17): over the stage's centre unit an energy ring spreads, a vertical beam rises and petals spiral in, tinted by
-- the best result's rarity. Common: ring only; Rare: + short beam; Epic: + petals; Legendary: + a light screen flash;
-- Mythic and Secret: + a second ring pulse. Reduced effects: the ring colour only, briefly. One reused ScreenGui; never
-- takes input. Timings proposed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaConfig = require(Shared:WaitForChild("GachaConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local LENGTH = 0.8
local REDUCED_LENGTH = 0.2
local PETALS = 8
local TIER = { Common = 1, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5, Secret = 5 }

local SummonAltarFx = {}
local root, ring, ring2, beam, flash
local petals = {}

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function ringFrame(name)
	local f = make("Frame", name, root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
	})
	make("UICorner", "Round", f, { CornerRadius = UDim.new(1, 0) })
	make("UIStroke", "Edge", f, { Thickness = 6 })
	make("UIAspectRatioConstraint", "Flat", f, { AspectRatio = 3 }) -- a floor ring seen from the stage camera
	return f
end

local function build()
	if root and root.Parent then
		return
	end
	root = make("ScreenGui", "SummonFx", Players.LocalPlayer:WaitForChild("PlayerGui"), {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
	})
	ring, ring2 = ringFrame("Ring"), ringFrame("Ring2")
	beam = make("Frame", "Beam", root, {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = false,
	})
	make("UIGradient", "Fade", beam, {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 0),
		}),
	})
	flash = make("Frame", "Flash", root, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	})
	for i = 1, PETALS do
		petals[i] = make("ImageLabel", "Petal" .. i, root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Image = UiTheme.Dojo.Petal,
			Visible = false,
		})
	end
end

local function hideAll()
	for _, g in { ring, ring2, beam, flash } do
		g.Visible = false
	end
	for _, p in petals do
		p.Visible = false
	end
end

local function pulse(r, at, color, delay)
	task.delay(delay, function()
		r.Position, r.Size, r.Visible = at, UDim2.fromOffset(40, 0), true
		r.Edge.Color, r.Edge.Transparency = color, 0
		UiMotion.Create(r, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(420, 0),
		}):Play()
		UiMotion.Create(r.Edge, TweenInfo.new(0.55), { Transparency = 1 }):Play()
	end)
end

-- The best rarity among summon results (rows from SidekickConfig via `rowOf(result)`).
function SummonAltarFx.Best(results, rowOf)
	local best, rank = "Common", 0
	for _, result in results do
		local row = rowOf(result)
		local r = row and table.find(GachaConfig.RARITY_ORDER, row.Rarity) or 0
		if r > rank then
			best, rank = row.Rarity, r
		end
	end
	return best
end

-- Plays over the screen point `at` (a Vector2 in pixels, the centre unit's feet) and calls `done` when it ends.
function SummonAltarFx.Play(at, rarity, done)
	build()
	hideAll()
	local color = GachaConfig.RARITY_COLORS[rarity] or UiTheme.Dojo.Sakura
	local tier = TIER[rarity] or 1
	local spot = UDim2.fromOffset(at.X, at.Y)
	if UiMotion.Reduced() then
		ring.Position, ring.Size, ring.Visible = spot, UDim2.fromOffset(300, 0), true
		ring.Edge.Color, ring.Edge.Transparency = color, 0.2
		task.delay(REDUCED_LENGTH, function()
			hideAll()
			done()
		end)
		return
	end
	pulse(ring, spot, color, 0)
	if tier >= 5 then
		pulse(ring2, spot, color, 0.25)
	end
	if tier >= 2 then
		beam.Position, beam.BackgroundColor3, beam.Visible = spot, color, true
		beam.Size = UDim2.fromOffset(tier >= 4 and 60 or 36, 0)
		beam.BackgroundTransparency = 0
		UiMotion.Create(beam, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(beam.Size.X.Offset, tier >= 4 and at.Y or at.Y * 0.6),
		}):Play()
		task.delay(0.45, function()
			UiMotion.Create(beam, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end)
	end
	if tier >= 3 then
		for i, p in petals do
			local angle = (i / PETALS) * math.pi * 2
			p.ImageColor3, p.ImageTransparency, p.Visible = UiTheme.Dojo.Sakura, 0.1, true
			p.Position = UDim2.fromOffset(at.X + math.cos(angle) * 220, at.Y - 60 + math.sin(angle) * 120)
			UiMotion.Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(at.X, at.Y - 80),
				Rotation = 360,
				ImageTransparency = 1,
			}):Play()
		end
	end
	if tier >= 4 then
		task.delay(0.35, function()
			flash.Visible, flash.BackgroundTransparency = true, 0.75 -- a light flash: 0.25 alpha
			UiMotion.Create(flash, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
		end)
	end
	task.delay(LENGTH, function()
		hideAll()
		done()
	end)
end

return SummonAltarFx
