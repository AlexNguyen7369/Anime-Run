--!nonstrict
-- The VIP pass's title (design doc 4.35): a label over the head on foot and a chat tag. Display only. Hidden while the
-- player runs (auto race or a boss event): the avatar is hidden then, so the tag would float alone (owner 2026-11-09).
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local GOLD = Color3.fromRGB(255, 196, 70)
local PASS = "Pass_vip"

local function title(head)
	local board = Instance.new("BillboardGui")
	board.Name = "VipTitle"
	board.Size = UDim2.fromOffset(80, 28)
	board.StudsOffset = Vector3.new(0, 2.5, 0)
	board.MaxDistance = 60 -- placeholder
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.Text = "VIP"
	text.TextColor3 = GOLD
	text.TextScaled = true
	text.TextStrokeTransparency = 0.2
	text.Parent = board
	board.Parent = head
end

local function refresh(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head and player:GetAttribute(PASS) == true and not head:FindFirstChild("VipTitle") then
		title(head)
	end
	local board = head and head:FindFirstChild("VipTitle")
	if board then
		board.Enabled = player:GetAttribute("AutoRacing") ~= true and player:GetAttribute("BossEvent") ~= true
	end
end

local function watch(player)
	for _, name in { PASS, "AutoRacing", "BossEvent" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			refresh(player)
		end)
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		refresh(player)
	end)
	refresh(player)
end

Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	task.spawn(watch, player)
end

TextChatService.OnIncomingMessage = function(message)
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if sender and sender:GetAttribute(PASS) == true then
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = '<font color="#FFC446">[VIP]</font> ' .. message.PrefixText
		return properties
	end
	return nil
end
