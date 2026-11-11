--!nonstrict
-- The enclosed cyber dojo on this client (design doc 4.24, owner 2026-11-10), display only. The blast door opens while
-- this player races and shuts once they are back on foot; the city skyline beyond the wall shows only on foot (it
-- stands over the track chain, which the wall hides from inside). The server decides the race start: CarService sets
-- the player attribute AutoRacing from the StartPad touch or Remotes.SetAutoRace. Timings and sizes are proposed.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CyberPlaza = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CyberPlaza"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local OPEN_TIME = 1.2 -- seconds
local CLOSE_DELAY = 1 -- seconds back on foot before the door shuts
local SKYLINE_COUNT = 140
local SKYLINE_NEAR, SKYLINE_FAR = 300, 680 -- studs from the compound's centre
local SKYLINE_HEIGHT = NumberRange.new(90, 300)
local SKYLINE_WIDTH = NumberRange.new(20, 55)

local C = CyberPlaza.Colors
local player = Players.LocalPlayer

-- Door ---------------------------------------------------------------------------------------------------------------

local leaves = {} -- leaf Model -> { Closed = CFrame, Slide = Vector3 }
local amount = Instance.new("NumberValue") -- 0 shut .. 1 open
local tween

local function apply()
	for model, leaf in leaves do
		model:PivotTo(leaf.Closed + leaf.Slide * amount.Value)
	end
end
amount.Changed:Connect(apply)

local function addLeaf(model)
	local slide = model:GetAttribute("Slide")
	if leaves[model] or not model:IsA("Model") or typeof(slide) ~= "Vector3" then
		return
	end
	leaves[model] = { Closed = model:GetPivot(), Slide = slide } -- the server's pose is the shut one
	apply()
end
CollectionService:GetInstanceAddedSignal(CyberPlaza.TAG):Connect(addLeaf)
CollectionService:GetInstanceRemovedSignal(CyberPlaza.TAG):Connect(function(model)
	leaves[model] = nil
end)
for _, model in CollectionService:GetTagged(CyberPlaza.TAG) do
	addLeaf(model)
end

local function setOpen(open)
	if tween then
		tween:Cancel()
	end
	local goal = open and 1 or 0
	if UiMotion.Reduced() then
		amount.Value = goal
		return
	end
	tween = TweenService:Create(
		amount,
		TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Value = goal }
	)
	tween:Play()
end

-- Skyline ------------------------------------------------------------------------------------------------------------

local skyline = Instance.new("Folder")
skyline.Name = "CyberSkyline"

local function buildSkyline()
	local rng = Random.new(11)
	local centre = (CyberPlaza.CORNER_MIN + CyberPlaza.CORNER_MAX) / 2
	local bands = { C.Cyan, C.Magenta, C.Panel }
	for i = 1, SKYLINE_COUNT do
		local a = rng:NextNumber(0, 2 * math.pi)
		local d = rng:NextNumber(SKYLINE_NEAR, SKYLINE_FAR)
		local w = rng:NextNumber(SKYLINE_WIDTH.Min, SKYLINE_WIDTH.Max)
		local h = rng:NextNumber(SKYLINE_HEIGHT.Min, SKYLINE_HEIGHT.Max)
		local base = CFrame.new(centre.X + d * math.cos(a), CyberPlaza.TOP, centre.Y + d * math.sin(a))
			* CFrame.Angles(0, -a, 0)
		local tower = CyberPlaza.Part(skyline, "Tower", Vector3.new(w, h, w), base * CFrame.new(0, h / 2, 0), C.City)
		tower.CastShadow = false
		for _ = 1, rng:NextInteger(1, 4) do
			CyberPlaza.Neon(
				skyline,
				"Band",
				Vector3.new(w + 0.4, 0.8, w + 0.4),
				base * CFrame.new(0, rng:NextNumber(10, h - 4), 0),
				bands[rng:NextInteger(1, #bands)]
			)
		end
		if i % 20 == 0 then
			task.wait() -- chunks: no hitch while the game loads
		end
	end
end

-- State --------------------------------------------------------------------------------------------------------------

local closing = 0 -- bumps on every change, so a stale close never runs
local function onRacing()
	closing += 1
	local racing = player:GetAttribute("AutoRacing") == true
	skyline.Parent = (not racing) and Workspace or nil
	if racing then
		setOpen(true)
	else
		local mine = closing
		task.delay(CLOSE_DELAY, function()
			if mine == closing then
				setOpen(false)
			end
		end)
	end
end
player:GetAttributeChangedSignal("AutoRacing"):Connect(onRacing)

buildSkyline()
onRacing()
