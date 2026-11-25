--!nonstrict
-- The boss gate's look for this player (WORLD_REDESIGN_SPEC 4.2), display only: the stand-in's doors while it is closed, its
-- fire while it is open (Shared/BossGateConfig.IsOpen). Parts are found by tag: the hub streams out during a race and back
-- in as new instances.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BossGateConfig"))
local player = Players.LocalPlayer

local function refresh()
	local open =
		Config.IsOpen(ReplicatedStorage:GetAttribute(Config.OPEN_ATTRIBUTE), player:GetAttribute("RebirthLevel"))
	for tag, shown in { [Config.CLOSED_TAG] = not open, [Config.OPEN_TAG] = open } do
		for _, part in CollectionService:GetTagged(tag) do
			part.Transparency = shown and 0 or 1
			part.CastShadow = shown and tag == Config.CLOSED_TAG
		end
	end
end

ReplicatedStorage:GetAttributeChangedSignal(Config.OPEN_ATTRIBUTE):Connect(refresh)
player:GetAttributeChangedSignal("RebirthLevel"):Connect(refresh)
CollectionService:GetInstanceAddedSignal(Config.CLOSED_TAG):Connect(refresh)
CollectionService:GetInstanceAddedSignal(Config.OPEN_TAG):Connect(refresh)
refresh()
