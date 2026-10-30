--!nonstrict
-- Client-side drawing helpers for the runner rig (docs/WORLD_REDESIGN_SPEC.md section 2): the procedural run
-- animation (limb swing and head bob from speed; it never touches the server's rig) and the lookup of the local
-- player's visible runner (tag VisibleRunner, attribute Owner = UserId; made by Client/RunnerView).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RunnerFactory = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RunnerFactory"))

local RunnerVisual = {}

RunnerVisual.TAG = "VisibleRunner"
RunnerVisual.STRIDE = 7 -- studs per full stride cycle (placeholder)
RunnerVisual.MAX_CADENCE = 4 -- stride cycles per second at most, so a very fast runner does not blur (placeholder)
RunnerVisual.SWING = math.rad(40) -- limb swing amplitude (placeholder)
RunnerVisual.BOB = 0.15 -- studs of head bob (placeholder)

local OFFSETS = {}
for _, p in RunnerFactory.PARTS do
	OFFSETS[p[1]] = { Offset = p[3], Size = p[2] }
end
-- limbs swing about the top of the part (shoulder / hip); arms opposite their leg
local SWINGS = { LeftArm = 1, RightArm = -1, LeftLeg = -1, RightLeg = 1 }

-- Advances a stride phase by `speed` studs/s over dt; returns the new phase (radians).
function RunnerVisual.Advance(phase, speed, dt)
	local cadence = math.min(math.abs(speed) / RunnerVisual.STRIDE, RunnerVisual.MAX_CADENCE)
	return (phase + 2 * math.pi * cadence * dt) % (2 * math.pi)
end

-- Places the rig with its Torso at `root` and its limbs at stride phase `phase` (amount 0 = standing still).
-- Models without a Torso (custom NPC models) are pivoted as a whole.
function RunnerVisual.Pose(model, root, phase, amount)
	local torso = model:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		model:PivotTo(root)
		return
	end
	local swing = math.sin(phase) * RunnerVisual.SWING * (amount or 1)
	local bob = math.abs(math.sin(phase)) * RunnerVisual.BOB * (amount or 1)
	torso.CFrame = root
	for name, o in OFFSETS do
		local part = name ~= "Torso" and model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local s = SWINGS[name]
			if s then
				local pivot = root * CFrame.new(o.Offset + Vector3.new(0, o.Size.Y / 2, 0))
				part.CFrame = pivot * CFrame.Angles(swing * s, 0, 0) * CFrame.new(0, -o.Size.Y / 2, 0)
			elseif name == "Head" then
				part.CFrame = root * CFrame.new(o.Offset + Vector3.new(0, bob, 0))
			else
				part.CFrame = root * CFrame.new(o.Offset)
			end
		end
	end
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
