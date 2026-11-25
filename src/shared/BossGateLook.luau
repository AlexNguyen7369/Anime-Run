--!nonstrict
-- The boss gate's look (WORLD_REDESIGN_SPEC 4.2), display only: the stand-in's doors while it is closed, its fire while it is
-- open. Client/BossGateView applies it for its own player.
local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent.BossGateConfig)

local BossGateLook = {}

function BossGateLook.Apply(open)
	for tag, shown in { [Config.CLOSED_TAG] = not open, [Config.OPEN_TAG] = open } do
		for _, part in CollectionService:GetTagged(tag) do
			part.Transparency = shown and 0 or 1
			part.CastShadow = shown and tag == Config.CLOSED_TAG
		end
	end
end

return BossGateLook
