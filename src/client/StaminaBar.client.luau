--!nonstrict
-- Runner stamina bar (owner 2026-11-02, docs/TEAM_AND_STAMINA_SPEC.md "HUD"): a vertical blue bar fixed to the right
-- of every visible runner (tag VisibleRunner, Client/RunnerView) while it runs. It shows the owner's active slot
-- stamina, the server's player attributes Stamina<RunSlot> (0-100). Display only. StudsOffset is camera-relative,
-- so the bar stays on the runner's screen-right whichever way it runs.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))

local BLUE = Color3.fromRGB(60, 150, 255)
local EMPTY = Color3.fromRGB(20, 26, 48)
local SIZE = UDim2.fromScale(0.5, 4) -- studs (placeholder): thin and about as tall as the rig
local OFFSET = Vector3.new(2.4, 0, 0) -- studs right of the Torso, in camera space (placeholder)
local MAX_DISTANCE = 200 -- studs (placeholder)

local function attach(copy)
	local owner = Players:GetPlayerByUserId(tonumber(copy:GetAttribute("Owner")) or 0)
	local torso = copy:FindFirstChild("Torso") or copy.PrimaryPart
	if not (owner and torso) then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "StaminaBar"
	gui.Adornee = torso
	gui.Size = SIZE
	gui.StudsOffset = OFFSET
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = EMPTY
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = BLUE
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)

	local function render()
		local value = owner:GetAttribute("Stamina" .. (owner:GetAttribute("RunSlot") or 1))
		gui.Enabled = type(value) == "number"
		fill.Size = UDim2.fromScale(1, math.clamp((tonumber(value) or 0) / 100, 0, 1))
	end
	local conn = owner.AttributeChanged:Connect(function(name)
		if name == "RunSlot" or string.sub(name, 1, 7) == "Stamina" then
			render()
		end
	end)
	render()
	-- PlayerGui keeps it out of the world and on top of the rig; it follows the Adornee
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	copy.Destroying:Connect(function()
		conn:Disconnect()
		gui:Destroy()
	end)
end

CollectionService:GetInstanceAddedSignal(RunnerVisual.TAG):Connect(attach)
for _, copy in CollectionService:GetTagged(RunnerVisual.TAG) do
	task.spawn(attach, copy)
end
