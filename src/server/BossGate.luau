--!nonstrict
-- The boss gate's state (WORLD_REDESIGN_SPEC 4.2): open while a boss event is active, read from the attribute the Bosses
-- panel reads. The gate changes no boss rule; Client/BossGateView draws it and Client/BossEventUi answers its prompt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").BossGateConfig)

local BossGate = {}

function BossGate.Start()
	if not Config.LIVE then
		return
	end
	local function update()
		ReplicatedStorage:SetAttribute(Config.OPEN_ATTRIBUTE, ReplicatedStorage:GetAttribute("BossEventPhase") ~= nil)
	end
	ReplicatedStorage:GetAttributeChangedSignal("BossEventPhase"):Connect(update)
	update()
end

return BossGate
