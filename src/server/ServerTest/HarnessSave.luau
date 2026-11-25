--!nonstrict
-- Design doc 4.24 "Harness saves": every test harness calls Isolate() before it changes a player, so nothing a
-- test does reaches the live save, the gift routes or the leaderboards. Publishes ReplicatedStorage attribute
-- SaveIsolated = true, which the client UI harness waits for. Errors when the session could not be isolated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = script.Parent.Parent

local HarnessSave = {}

HarnessSave.ATTRIBUTE = "SaveIsolated"

function HarnessSave.Isolate()
	local PlayerData = require(Server:WaitForChild("PlayerData"))
	if PlayerData.IsolateForTests() ~= true then
		error("harness refused: the save could not be isolated")
	end
	require(Server:WaitForChild("GiftService")).IsolateForTests(require(Server:WaitForChild("ShadowStore")).new(nil))
	if ReplicatedStorage:GetAttribute(HarnessSave.ATTRIBUTE) ~= true then
		ReplicatedStorage:SetAttribute(HarnessSave.ATTRIBUTE, true)
		print("[HARNESS] save isolated: this session writes to memory only")
	end
	return true
end

return HarnessSave
