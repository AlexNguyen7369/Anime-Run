--!nonstrict
-- Gojio at the boss gate (WORLD_REDESIGN_SPEC 4.2, docs/BOSS_GUIDE_SPEC.md): a static rig and one E prompt. The conversation is
-- Client/BossGuideUi, text only: no remote, nothing granted, no boss rule touched. Another world loads his model because
-- this rig wears it (design doc 4.47 "Models").
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.BossGuideConfig)
local Gate = require(Shared.BossGateConfig)
local RunnerFactory = require(Shared.RunnerFactory)
local SpawnArea = require(Shared.SpawnArea)

local BossGuide = {}

-- His feet, facing the way the gate does.
function BossGuide.CFrame(startCFrame)
	local centre = SpawnArea.CENTRE
	local at = Gate.At(Gate.GUIDE_OFFSET) + centre
	local feet = Vector3.new(at.X, SpawnArea.TOP_Y, at.Y)
	local toSpawn = -Gate.POS.Unit
	return SpawnArea.Base(startCFrame) * CFrame.lookAt(feet, feet + Vector3.new(toSpawn.X, 0, toSpawn.Y))
end

function BossGuide.Build(startCFrame)
	local model = Instance.new("Model")
	model.Name = "BossGuide"
	local feet = BossGuide.CFrame(startCFrame)
	local rig = RunnerFactory.build(Config.ID)
	rig.Name = "Rig"
	rig:PivotTo(feet * CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0))
	rig.Parent = model
	-- Its own anchor: the rig's parts are swapped when the model arrives.
	local anchor = Instance.new("Part")
	anchor.Name = "PromptAnchor"
	anchor.Size = Vector3.one
	anchor.CFrame = feet * CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Gate.GUIDE_PROMPT
	prompt.ActionText = "Talk"
	prompt.ObjectText = Config.Name()
	prompt.KeyboardKeyCode = Enum.KeyCode.E -- gamepad X and touch are the engine's defaults
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton -- never beside another E prompt
	prompt.HoldDuration = Config.HOLD
	prompt.MaxActivationDistance = Gate.GUIDE_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	model.PrimaryPart = anchor
	return model
end

function BossGuide.Start(startCFrame)
	if Config.IsLive() then
		BossGuide.Build(startCFrame).Parent = Workspace
	end
end

return BossGuide
