--!nonstrict
-- Join size (design doc 7): big client-only data (src/late) sits in ServerStorage.LateData, so it does not replicate at join.
-- The server copies a module to ReplicatedStorage.LateData on its first need (Deliver); a client's Get waits for it there.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LateData = {}

-- The module's result. Yields on a client until the server has delivered it.
function LateData.Get(name)
	if RunService:IsServer() then
		return require(game:GetService("ServerStorage").LateData[name])
	end
	return require(ReplicatedStorage:WaitForChild("LateData"):WaitForChild(name))
end

-- The module's result if it has arrived, else nil. Never yields: for per-frame callers.
function LateData.Peek(name)
	if RunService:IsServer() then
		return LateData.Get(name)
	end
	local folder = ReplicatedStorage:FindFirstChild("LateData")
	local module = folder and folder:FindFirstChild(name)
	return module and require(module)
end

-- Server only: copies each named module to ReplicatedStorage.LateData, once. Later joiners get the copies at join.
function LateData.Deliver(...)
	local folder = ReplicatedStorage:FindFirstChild("LateData")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LateData"
		folder.Parent = ReplicatedStorage
	end
	for _, name in { ... } do
		if not folder:FindFirstChild(name) then
			game:GetService("ServerStorage").LateData[name]:Clone().Parent = folder
		end
	end
end

-- Server only: destroys each named copy in ReplicatedStorage.LateData. Clients that required it keep their table;
-- a later Deliver copies it again.
function LateData.Remove(...)
	local folder = ReplicatedStorage:FindFirstChild("LateData")
	for _, name in { ... } do
		local copy = folder and folder:FindFirstChild(name)
		if copy then
			copy:Destroy()
		end
	end
end

return LateData
