--!nonstrict
-- Clients cannot read ServerStorage, so they get a copy of the UI sounds (docs/UI_FEEDBACK_SPEC.md section 1).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local folder = ServerStorage:FindFirstChild("ImpactSounds")
if folder then
	folder:Clone().Parent = ReplicatedStorage
else
	warn("[ImpactSounds] ServerStorage.ImpactSounds is missing: UI cues stay silent")
end
