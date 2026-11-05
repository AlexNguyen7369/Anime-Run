--!nonstrict
-- The bright red server-wide message when Big Raga spawns (design doc 4.37, Server/BossEventService). Display only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BossEventChat")

remote.OnClientEvent:Connect(function(message)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local system = channels and channels:FindFirstChild("RBXSystem")
	if type(message) == "string" and system then
		system:DisplaySystemMessage('<font color="#FF1E1E"><b>' .. message .. "</b></font>")
	end
end)
