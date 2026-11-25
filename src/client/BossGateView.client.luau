--!nonstrict
-- The boss gate's look for this player (WORLD_REDESIGN_SPEC 4.2), display only: the stand-in's doors while it is closed, its
-- fire while it is open (Shared/BossGateConfig.IsOpen). Parts are found by tag: the hub streams out during a race and back
-- in as new instances. With the gate off (Config.LIVE) no part has the tags.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("BossGateConfig"))
local BossGateLook = require(Shared:WaitForChild("BossGateLook"))
local player = Players.LocalPlayer

local function refresh()
	BossGateLook.Apply(
		Config.IsOpen(ReplicatedStorage:GetAttribute(Config.OPEN_ATTRIBUTE), player:GetAttribute("RebirthLevel"))
	)
end

ReplicatedStorage:GetAttributeChangedSignal(Config.OPEN_ATTRIBUTE):Connect(refresh)
player:GetAttributeChangedSignal("RebirthLevel"):Connect(refresh)
CollectionService:GetInstanceAddedSignal(Config.CLOSED_TAG):Connect(refresh)
CollectionService:GetInstanceAddedSignal(Config.OPEN_TAG):Connect(refresh)
refresh()
