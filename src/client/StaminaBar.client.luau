--!nonstrict
-- Runner stamina bar (owner 2026-11-02 / 2026-11-03, docs/TEAM_AND_STAMINA_SPEC.md "HUD"): a vertical bar fixed to the
-- right of every visible runner (tag VisibleRunner, Client/RunnerView) while it runs. It shows the owner's active slot
-- stamina, the server's player attributes Stamina<RunSlot> (0-100). The fill tweens between server updates, a pale
-- "just lost" trail follows it down, the colour steps blue / amber / red (StaminaConfig.Color), it pulses when low and
-- refills with a flash on a tag-in. Display only. StudsOffset is camera-relative, so the bar stays on the runner's
-- screen-right whichever way it runs.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))
local StaminaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StaminaConfig"))

local EMPTY = Color3.fromRGB(20, 26, 48)
local TRAIL = Color3.fromRGB(235, 240, 255)
local SIZE = UDim2.fromScale(0.6, 4) -- studs (placeholder): thin and about as tall as the rig
local OFFSET = Vector3.new(2.4, 0, 0) -- studs right of the Torso, in camera space (placeholder)
local MAX_DISTANCE = 200 -- studs (placeholder)
local STEP = 0.12 -- s, fill tween per server update (updates come at most every 0.1 s)
local TRAIL_DELAY = 0.35 -- s before the "just lost" trail catches up (placeholder)

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function attach(copy)
	local owner = Players:GetPlayerByUserId(tonumber(copy:GetAttribute("Owner")) or 0)
	local torso = copy:FindFirstChild("Torso") or copy.PrimaryPart
	if not (owner and torso) then
		return
	end
	local gui = make("BillboardGui", {
		Name = "StaminaBar",
		Adornee = torso,
		Size = SIZE,
		StudsOffset = OFFSET,
		MaxDistance = MAX_DISTANCE,
		LightInfluence = 0,
		ResetOnSpawn = false,
	}, nil)
	local back = make("Frame", {
		Name = "Back",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = EMPTY,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, back)
	local stroke = make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5 }, back)
	local inner = make("CanvasGroup", { -- clips the fills to the rounded bar
		Name = "Inner",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, back)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, inner)
	local function bar(name, color, z)
		return make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, inner)
	end
	local trail = bar("Trail", TRAIL, 1)
	trail.BackgroundTransparency = 0.35
	local fill = bar("Fill", StaminaConfig.COLORS.Full, 2)
	make("UIGradient", { -- sheen across the fill
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		Rotation = 0,
	}, fill)
	for _, at in { 0.25, 0.5, 0.75 } do -- quarter ticks
		make("Frame", {
			Name = "Tick",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 1 - at),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, inner)
	end
	local flash = make("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, inner)

	local shown, slot, trailTween, trailThread = nil, nil, nil, nil
	local function render()
		local s = owner:GetAttribute("RunSlot") or 1
		local value = owner:GetAttribute("Stamina" .. s)
		gui.Enabled = type(value) == "number"
		local pct = math.clamp((tonumber(value) or 0) / 100, 0, 1)
		local size = UDim2.fromScale(1, pct)
		TweenService:Create(fill, TweenInfo.new(0.2), { BackgroundColor3 = StaminaConfig.Color(pct * 100) }):Play()
		if slot ~= nil and s ~= slot then
			-- tag-in: the new runner's full bar rises with a flash, the trail resets
			fill.Size = UDim2.fromScale(1, 0)
			trail.Size = size
			TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = size }):Play()
			flash.BackgroundTransparency = 0.1
			TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		elseif shown == nil or pct > shown then
			fill.Size = size
			trail.Size = size
		else
			TweenService:Create(fill, TweenInfo.new(STEP, Enum.EasingStyle.Linear), { Size = size }):Play()
			-- the trail holds, then drains to the fill
			if trailThread then
				task.cancel(trailThread)
			end
			trailThread = task.delay(TRAIL_DELAY, function()
				trailThread = nil
				if trailTween then
					trailTween:Cancel()
				end
				trailTween = TweenService:Create(trail, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = fill.Size })
				trailTween:Play()
			end)
		end
		shown, slot = pct, s
	end
	local conn = owner.AttributeChanged:Connect(function(name)
		if name == "RunSlot" or string.sub(name, 1, 7) == "Stamina" then
			render()
		end
	end)
	-- low pulse
	local clock = 0
	local pulse = RunService.RenderStepped:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		clock += dt
		local low = (shown or 1) * 100 <= StaminaConfig.LOW and (shown or 0) > 0
		local wave = low and (0.5 + 0.5 * math.sin(clock * 10)) or 0
		stroke.Color = low and StaminaConfig.COLORS.Low:Lerp(Color3.new(1, 1, 1), wave * 0.5) or Color3.new(0, 0, 0)
		stroke.Thickness = low and 1.5 + wave * 1.5 or 1.5
		fill.BackgroundTransparency = low and wave * 0.35 or 0
	end)
	render()
	-- PlayerGui keeps it out of the world and on top of the rig; it follows the Adornee
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	copy.Destroying:Connect(function()
		conn:Disconnect()
		pulse:Disconnect()
		if trailThread then
			task.cancel(trailThread)
		end
		gui:Destroy()
	end)
end

CollectionService:GetInstanceAddedSignal(RunnerVisual.TAG):Connect(attach)
for _, copy in CollectionService:GetTagged(RunnerVisual.TAG) do
	task.spawn(attach, copy)
end
