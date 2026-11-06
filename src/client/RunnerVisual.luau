--!nonstrict
-- Client-side drawing helpers for the runner rig (docs/WORLD_REDESIGN_SPEC.md section 2): the procedural run
-- animation (limb swing and head bob from speed; it never touches the server's rig) and the lookup of the local
-- player's visible runner (tag VisibleRunner, attribute Owner = UserId; made by Client/RunnerView).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))

local RunnerVisual = {}

RunnerVisual.TAG = "VisibleRunner"
RunnerVisual.STRIDE = 7 * RunnerFactory.SCALE -- studs per full stride cycle (placeholder)
RunnerVisual.MAX_CADENCE = 4 -- stride cycles per second at most, so a very fast runner does not blur (placeholder)
RunnerVisual.BOB = 0.15 * RunnerFactory.SCALE -- studs of head bob (placeholder)

local OFFSETS = {}
for _, p in RunnerFactory.PARTS do
	OFFSETS[p[1]] = { Offset = p[3], Size = p[2] }
end
-- limbs swing about the top of the part (shoulder / hip); arms opposite their leg
local SWINGS = { LeftArm = 1, RightArm = -1, LeftLeg = -1, RightLeg = 1 }

-- Run poses, all placeholders. Forward is -Z, so a negative X angle leans forward / sends arms back.
-- NinjaRun: design doc 4.23.
local NINJA = {
	LEAN = math.rad(45), -- torso forward, about the hips
	ARM_BACK = math.rad(35), -- arms behind the torso
	ARM_SPLAY = math.rad(12), -- each arm outward
	ARM_SWAY = math.rad(3),
	HEAD_UP = math.rad(36), -- head back from the torso, so the eyes look ahead
	LEG_SWING = math.rad(55),
}
-- Universal run for every character without a RunStyle: design doc 4.34.
local SPEED = {
	LEAN = math.rad(30),
	ARM_BACK = math.rad(10),
	ARM_SPLAY = math.rad(6),
	ARM_SWAY = math.rad(50),
	HEAD_UP = math.rad(24),
	LEG_SWING = math.rad(65),
}
local STYLES = { NinjaRun = NINJA }
local SIDES = { LeftArm = -1, RightArm = 1 }
local roots = setmetatable({}, { __mode = "k" }) -- model -> the root last posed at

-- The character's RunStyle (docs/CHARACTER_GACHA_SPEC.md), or nil.
function RunnerVisual.StyleOf(model)
	local spec = CharacterCatalog.Get(model:GetAttribute("CharacterId"))
	return spec and spec.RunStyle
end

local function poseOf(model)
	return STYLES[RunnerVisual.StyleOf(model)] or SPEED
end

-- The torso's forward lean while running, in degrees.
function RunnerVisual.LeanOf(model)
	return math.deg(poseOf(model).LEAN)
end

local function poseRun(model, root, phase, amount, style)
	local sine = math.sin(phase)
	local bob = math.abs(sine) * RunnerVisual.BOB * amount
	local hip = OFFSETS.Torso.Size.Y / 2
	local upper = root * CFrame.new(0, -hip, 0) * CFrame.Angles(-style.LEAN * amount, 0, 0) * CFrame.new(0, hip, 0)
	model.Torso.CFrame = upper
	for name, o in OFFSETS do
		local part = name ~= "Torso" and model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local half = Vector3.new(0, o.Size.Y / 2, 0)
			if SIDES[name] then
				local back = (-style.ARM_BACK + style.ARM_SWAY * sine * SWINGS[name]) * amount
				local splay = style.ARM_SPLAY * SIDES[name] * amount
				part.CFrame = upper * CFrame.new(o.Offset + half) * CFrame.Angles(back, 0, splay) * CFrame.new(-half)
			elseif SWINGS[name] then
				local swing = sine * style.LEG_SWING * SWINGS[name] * amount
				part.CFrame = root * CFrame.new(o.Offset + half) * CFrame.Angles(swing, 0, 0) * CFrame.new(-half)
			elseif name == "Head" then
				part.CFrame = upper
					* CFrame.new(o.Offset - half)
					* CFrame.Angles(style.HEAD_UP * amount, 0, 0)
					* CFrame.new(half + Vector3.new(0, bob, 0))
			else
				part.CFrame = upper * CFrame.new(o.Offset)
			end
		end
	end
end

-- Standing hero pose (design doc 4.24, proposed): right arm raised, left arm and both legs out. Limbs only rotate.
local HERO = {
	RightArm = CFrame.Angles(math.rad(165), 0, math.rad(10)),
	LeftArm = CFrame.Angles(0, 0, math.rad(-30)),
	RightLeg = CFrame.Angles(0, 0, math.rad(10)),
	LeftLeg = CFrame.Angles(0, 0, math.rad(-10)),
}

-- Places the rig with its Torso at `root` in the hero pose. Call before any ScaleTo: OFFSETS are at the built size.
function RunnerVisual.Hero(model, root)
	RunnerVisual.Pose(model, root, 0, 0)
	for name, turn in HERO do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local half = Vector3.new(0, OFFSETS[name].Size.Y / 2, 0)
			part.CFrame = root * CFrame.new(OFFSETS[name].Offset + half) * turn * CFrame.new(-half)
		end
	end
end

-- Advances a stride phase by `speed` studs/s over dt; returns the new phase (radians).
function RunnerVisual.Advance(phase, speed, dt)
	local cadence = math.min(math.abs(speed) / RunnerVisual.STRIDE, RunnerVisual.MAX_CADENCE)
	return (phase + 2 * math.pi * cadence * dt) % (2 * math.pi)
end

-- The `root` last given to Pose: the runner's unleaned frame, as the Torso leans while running. Nil before the first Pose.
function RunnerVisual.RootOf(model)
	return roots[model]
end

-- Places the rig with its Torso at `root` and its limbs at stride phase `phase` (amount 0 = standing still).
-- Models without a Torso (custom NPC models) are pivoted as a whole.
function RunnerVisual.Pose(model, root, phase, amount)
	roots[model] = root
	local torso = model:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		model:PivotTo(root)
		return
	end
	poseRun(model, root, phase, amount or 1, poseOf(model))
end

-- The local player's visible runner, or nil.
function RunnerVisual.LocalRunner()
	local userId = Players.LocalPlayer and Players.LocalPlayer.UserId
	for _, m in CollectionService:GetTagged(RunnerVisual.TAG) do
		if m:IsA("Model") and m:GetAttribute("Owner") == userId and m:IsDescendantOf(Workspace) then
			return m
		end
	end
	return nil
end

return RunnerVisual
