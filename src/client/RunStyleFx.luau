--!nonstrict
-- Client-side run particles (design doc 4.23, 4.34), on the drawn copy only (Client/RunnerView). They
-- go away with the copy, so a tag-in or re-skin swaps them. Values are placeholders; textures are the uploaded set.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))
local VehicleEffects = require(Shared:WaitForChild("VehicleEffects"))
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
		Speed = NumberRange.new(10, 18),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(20, 20),
		LockedToPart = true, -- at 700 studs/s, 10 world-space puffs a second land 70 studs apart and never read
		Rotation = NumberRange.new(0, 360),
		Size = seq(1.2, 3.5),
		Transparency = seq(0.1, 1),
	}
end

-- Adds the emitters to a freshly drawn copy.
function RunStyleFx.Attach(copy)
	local torso = copy:FindFirstChild("Torso")
	if not torso then
		return
	end
	local lean = RunnerVisual.LeanOf(copy)
	-- the Torso leans while running; this keeps the streaks level with the ground
	local level = Instance.new("Attachment")
	level.Name = "RunStyleLevel"
	level.Position = Vector3.new(0, 0, torso.Size.Z / 2)
	level.Orientation = Vector3.new(lean, 0, 0)
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
	-- dust host: just above the ground behind the feet, given in the unleaned root's frame
	local hip = torso.Size.Y / 2
	local upper = CFrame.new(0, -hip, 0) * CFrame.Angles(math.rad(-lean), 0, 0) * CFrame.new(0, hip, 0)
	local feet = Instance.new("Attachment")
	feet.Name = "RunStyleFeet"
	feet.Position = upper:PointToObjectSpace(Vector3.new(0, 0.2 - RunnerFactory.HIP_HEIGHT, 0.8))
	feet.Orientation = level.Orientation
	feet.Parent = torso
	emitter(feet, true, dustProps(TAN, 20))
	emitter(feet, true, dustProps(BROWN, 4))
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
