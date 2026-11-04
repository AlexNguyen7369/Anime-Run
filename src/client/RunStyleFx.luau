--!nonstrict
-- Client-side particles of a character's RunStyle (design doc 4.23), on the drawn copy only (Client/RunnerView). They
-- go away with the copy, so a tag-in or re-skin swaps them. Values are placeholders; textures are the uploaded set.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleEffects = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VehicleEffects"))
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local RunStyleFx = {}

local FX_NAME = "RunStyleFx"
local TEX = VehicleEffects.TEXTURES
local TAN, BROWN = Color3.fromRGB(214, 190, 150), Color3.fromRGB(110, 88, 66)

local function seq(a, b)
	return NumberSequence.new(a, b)
end

local function emitter(host, dust, props)
	local p = Instance.new("ParticleEmitter")
	p.Name = FX_NAME
	p:SetAttribute("Dust", dust)
	p.Enabled = false
	for key, value in props do
		p[key] = value
	end
	p.Parent = host
end

local function dustProps(color, rate)
	return {
		Texture = TEX.Nebula,
		Color = ColorSequence.new(color),
		Rate = rate,
		Lifetime = NumberRange.new(0.4, 0.6),
		Speed = NumberRange.new(1, 3),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(30, 30),
		Rotation = NumberRange.new(0, 360),
		Size = seq(0.8, 3),
		Transparency = seq(0.35, 1),
	}
end

-- Adds the style's emitters to a freshly drawn copy (nothing for the default swing).
function RunStyleFx.Attach(copy)
	if RunnerVisual.StyleOf(copy) ~= "NinjaRun" then
		return
	end
	local torso, left, right =
		copy:FindFirstChild("Torso"), copy:FindFirstChild("LeftLeg"), copy:FindFirstChild("RightLeg")
	if not (torso and left and right) then
		return
	end
	-- the Torso leans 45 deg (RunnerVisual NINJA.LEAN); this keeps the streaks level with the ground
	local level = Instance.new("Attachment")
	level.Name = "RunStyleLevel"
	level.Position = Vector3.new(0, 0, torso.Size.Z / 2)
	level.Orientation = Vector3.new(45, 0, 0)
	level.Parent = torso
	emitter(level, false, {
		Texture = TEX.CoreStreak,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		LightEmission = 0.5,
		Rate = 12,
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(30, 45),
		EmissionDirection = Enum.NormalId.Back, -- forward is -Z (Front), so Back is the way the air goes
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(12, 12),
		LockedToPart = true,
		Size = seq(0.5, 0.15),
		Transparency = seq(0.3, 1),
	})
	emitter(left, true, dustProps(TAN, 10))
	emitter(right, true, dustProps(TAN, 10))
	emitter(left, true, dustProps(BROWN, 4))
end

-- Turns the copy's emitters on while it moves; dust stays off under Reduced Motion / REDUCED EFFECTS. Writes only on a change.
function RunStyleFx.SetMoving(copy, moving)
	local reduced = UiMotion.Reduced()
	local state = moving and (reduced and "streaks" or "all") or "off"
	if copy:GetAttribute("RunFxState") == state then
		return
	end
	copy:SetAttribute("RunFxState", state)
	for _, d in copy:GetDescendants() do
		if d.Name == FX_NAME then
			d.Enabled = state == "all" or (state == "streaks" and not d:GetAttribute("Dust"))
		end
	end
end

return RunStyleFx
