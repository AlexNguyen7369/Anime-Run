--!nonstrict
-- Gojio at the boss gate (WORLD_REDESIGN_SPEC 4.2, docs/BOSS_GUIDE_SPEC.md): a static rig and one E prompt. The conversation is
-- Client/BossGuideUi, text only: no remote, nothing granted, no boss rule touched. Another world loads his model because
-- this rig wears it (design doc 4.47 "Models").
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.BossGuideConfig)
local RunnerFactory = require(Shared.RunnerFactory)
local SpawnArea = require(Shared.SpawnArea)

local BossGuide = {}

-- His feet, facing the spawn like the gate.
function BossGuide.CFrame(startCFrame)
	local centre = SpawnArea.CENTRE
	local gate = Vector3.new(Config.GATE_POS.X + centre.X, SpawnArea.TOP_Y, Config.GATE_POS.Y + centre.Y)
	local frame = CFrame.lookAt(gate, Vector3.new(centre.X, gate.Y, centre.Y))
	return SpawnArea.Base(startCFrame) * frame * CFrame.new(Config.OFFSET.X, 0, -Config.OFFSET.Y)
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
	prompt.Name = Config.PROMPT
	prompt.ActionText = "Talk"
	prompt.ObjectText = Config.Name()
	prompt.KeyboardKeyCode = Enum.KeyCode.E -- gamepad X and touch are the engine's defaults
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton -- never beside another E prompt
	prompt.HoldDuration = Config.HOLD
	prompt.MaxActivationDistance = Config.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	model.PrimaryPart = anchor
	return model
end

function BossGuide.Start(startCFrame)
	BossGuide.Build(startCFrame).Parent = Workspace
end

return BossGuide
