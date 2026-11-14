--!nonstrict
-- Imported summon presentation; Anime Run's existing server remotes decide all outcomes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(shared:WaitForChild("SidekickConfig"))
local Monetization = require(shared:WaitForChild("MonetizationConfig"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local SidekickArt = require(shared:WaitForChild("SidekickArt"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local SidekickReveal = require(script.Parent:WaitForChild("SidekickReveal"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local SummonShrineTheme = require(script.Parent:WaitForChild("SummonShrineTheme"))
local SummonHybrid = require(script.Parent:WaitForChild("SummonHybrid"))
local assets = ReplicatedStorage:WaitForChild("SummonScreenAssets")
local LegendaryAuraStyle = require(assets:WaitForChild("LegendaryAuraStyle"))
local featuredRows = {}
local busy, revealing = false, false
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("RacerSidekicks")
local canvas = gui:WaitForChild("Canvas")
local savedStage = assets:WaitForChild("SummoningStage")
for i = 1, 3 do
	local unit = savedStage:WaitForChild("Units"):WaitForChild("Unit" .. i)
	unit:WaitForChild("Root")
	unit:WaitForChild("ImportedAura"):WaitForChild("RightArm")
end
local template = savedStage:Clone()
template.Parent = nil
-- The authored stage remains in ReplicatedStorage, outside streaming.
local stage = nil
local hybrid = nil
local motion = {}
local opened = false
local auto = false
local elapsed = 0
local cameraDrift = Vector2.zero
local lastAuto = 0
local toastVersion = 0
local previousCamera = nil
local lightingState = nil
local previousSpeed = nil
local previousJump = nil
local hiddenHud = {}
local hiddenWorldLabels = {}
local hudGuards = {}
local HUD_NAMES = {
	RacerSecondColumn = true,
	RacerTeam = true,
	HudChrome = true,
	RacerHud = true,
	RollExtras = true,
	RollToast = true,
	TeamToast = true,
	RacerProgression = true,
	NpcIndicator = true,
	CheckpointUi = true,
	CheckpointBonusPopup = true,
	BiomeWelcome = true,
	DailyBoosts = true,
	ProximityPrompts = true,
	EnemyShowdown = true,
}
local camera = workspace.CurrentCamera
local function fit()
	local view = camera.ViewportSize
	canvas.ResponsiveScale.Scale = math.min(view.X / 1600, view.Y / 900)
	local width = view.X / canvas.ResponsiveScale.Scale
	local height = view.Y / canvas.ResponsiveScale.Scale
	canvas.Size = UDim2.fromOffset(width, height)
	for _, obj in canvas:GetChildren() do
		local pos = obj:GetAttribute("DesignPosition")
		if obj:IsA("GuiObject") and pos then
			local x = pos.X
			local y = pos.Y
			if obj.Name:match("^Unit") or obj.Name:match("^Rarity") or obj.Name == "Featured" then
				x += (width - 1600) * 0.5
			elseif x >= 1060 then
				x += width - 1600
			end
			if y >= 650 then
				y += height - 900
			end
			obj.Position = UDim2.fromOffset(x, y)
		end
	end
	local aspect = view.X / math.max(view.Y, 1)
	local distance = 18 * math.max(1, (16 / 9) / aspect)
	if opened then
		if hybrid then
			camera.CFrame, camera.FieldOfView = hybrid:Frame(view, cameraDrift, elapsed, UiMotion.Reduced())
		else
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 10001, -distance), Vector3.new(0, 10000, 0))
		end
		camera.Focus = CFrame.new(0, 10000, 0)
	end
end
local function toast(text)
	toastVersion += 1
	local version = toastVersion
	canvas.Toast.Text = text
	canvas.Toast.Visible = true
	task.delay(2.8, function()
		if version == toastVersion and gui.Parent then
			canvas.Toast.Visible = false
		end
	end)
end
local function dialog(title, text)
	canvas.Modal.Panel.Heading.Text = title
	canvas.Modal.Panel.DetailsScroll.Body.Text = text
	canvas.Modal.Visible = true
end
-- Pose the independent mesh groups together, including blade and emissive armor pieces.
local function poseFeatured(model, id)
	local torso = model:FindFirstChild("Torso", true)
	if not torso then
		return
	end
	local knight = id == "side_knight"
	local ant = id == "side_ant"
	local rotations = knight
			and {
				LeftArm = Vector3.new(-18, 0, -28),
				RightArm = Vector3.new(-32, -5, -28),
				LeftLeg = Vector3.new(-14, 0, -10),
				RightLeg = Vector3.new(12, 0, 10),
			}
		or ant and {
			LeftArm = Vector3.new(-58, -12, -32),
			RightArm = Vector3.new(-20, 10, 28),
			LeftLeg = Vector3.new(-18, 0, -14),
			RightLeg = Vector3.new(16, 0, 12),
		}
		or {
			LeftArm = Vector3.new(-28, -8, -36),
			RightArm = Vector3.new(-42, 8, 32),
			LeftLeg = Vector3.new(-20, 0, -12),
			RightLeg = Vector3.new(12, 0, 14),
		}
	local changes = {}
	for name, angles in rotations do
		local part = model:FindFirstChild(name, true)
		if part then
			local pivot = part.Position + Vector3.new(0, part.Size.Y * 0.28, 0)
			changes[name] = CFrame.new(pivot)
				* CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
				* CFrame.new(-pivot)
		end
	end
	local origin = torso.Position
	local lean = CFrame.new(origin)
		* CFrame.Angles(math.rad(-5), math.rad(knight and -12 or ant and 12 or -8), math.rad(knight and -5 or 6))
		* CFrame.new(-origin)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local delta = CFrame.identity
			for group, change in changes do
				if part.Name:sub(1, #group) == group or (part.Name == "Sword" and group == "RightArm") then
					delta = change
					break
				end
			end
			part.CFrame = lean * delta * part.CFrame
		end
	end
	model:SetAttribute("SummonPose", knight and "SwordGuard" or ant and "ClawStrike" or "AirborneGuard")
end
local function refreshAuraMotion(record)
	record.parts, record.supports = {}, {}
	local unit = record.model
	for _, part in unit:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("LocalPose") then
			table.insert(record.parts, { part = part, pose = part:GetAttribute("LocalPose") })
		end
		if part:IsA("BasePart") and part:GetAttribute("AuraBody") then
			table.insert(record.supports, {
				part = part,
				body = unit.ImportedAura[part:GetAttribute("AuraBody")],
				offset = part:GetAttribute("AuraOffset"),
			})
		end
	end
end
local function dressStage()
	if not stage then
		return
	end
	local models = ReplicatedStorage:FindFirstChild("SidekickModels")
	for _, unit in stage.Units:GetChildren() do
		local index = unit:GetAttribute("Index")
		local row = featuredRows[index]
		if row and LegendaryAuraStyle.Apply(unit, row.Id) then
			for _, record in motion do
				if record.model == unit then
					refreshAuraMotion(record)
				end
			end
		end
		for _, d in unit.ImportedAura:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			end
		end
		local old = unit:FindFirstChild("ActualSidekick")
		if old then
			old:Destroy()
		end
		local source = models and row and models:FindFirstChild(row.Id)
		if source then
			local model = source:Clone()
			model.Name = "ActualSidekick"
			for _, d in model:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
				end
			end
			poseFeatured(model, row.Id)
			local _, size = model:GetBoundingBox()
			local height = index == 2 and 7.5 or 6.3
			model:ScaleTo(model:GetScale() * height / math.max(size.Y, size.X * 0.7, 0.01))
			model:PivotTo(
				CFrame.new(unit.PrimaryPart.Position)
					* CFrame.Angles(0, math.rad(index == 1 and -12 or index == 3 and 12 or 0), 0)
			)
			local box = model:GetBoundingBox()
			local target = unit.PrimaryPart.Position + Vector3.new(0, height * 0.52, 0)
			model:PivotTo(model:GetPivot() + target - box.Position)
			model.Parent = unit
		end
	end
end
local function populate()
	stage = template:Clone()
	stage.Name = "SummoningStageLocal"
	stage.Parent = workspace
	hybrid = SummonHybrid.Attach(stage, assets)
	dressStage()
	local stars = stage:FindFirstChild("BackgroundStars")
	if stars then
		for _, emitter in stars:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter:Emit(math.ceil(emitter.Rate * 2))
			end
		end
	end
	motion = {}
	for _, unit in stage.Units:GetChildren() do
		local root = unit.PrimaryPart
		local record = {
			model = unit,
			base = root.CFrame,
			index = unit:GetAttribute("Index"),
			parts = {},
			supports = {},
		}
		for _, part in unit:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("LocalPose") then
				table.insert(record.parts, { part = part, pose = part:GetAttribute("LocalPose") })
			end
		end
		for _, part in unit:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("AuraBody") then
				table.insert(record.supports, {
					part = part,
					body = unit.ImportedAura[part:GetAttribute("AuraBody")],
					offset = part:GetAttribute("AuraOffset"),
				})
			end
		end
		table.insert(motion, record)
	end
end
local function freezePlayer(freeze)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if freeze then
		previousSpeed = hum.WalkSpeed
		previousJump = hum.JumpPower
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	else
		if previousSpeed then
			hum.WalkSpeed = previousSpeed
		end
		if previousJump then
			hum.JumpPower = previousJump
		end
	end
end
local function open()
	if opened then
		return
	end
	previousCamera =
		{ kind = camera.CameraType, cf = camera.CFrame, fov = camera.FieldOfView, subject = camera.CameraSubject }
	opened = true
	for _, label in workspace:GetDescendants() do
		if label:IsA("BillboardGui") then
			hiddenWorldLabels[label] = label.Enabled
			label.Enabled = false
		end
	end
	for _, other in player.PlayerGui:GetChildren() do
		if other:IsA("ScreenGui") and HUD_NAMES[other.Name] then
			hiddenHud[other] = other.Enabled
			other.Enabled = false
			hudGuards[other] = other:GetPropertyChangedSignal("Enabled"):Connect(function()
				if opened and other.Enabled then
					other.Enabled = false
				end
			end)
		end
	end
	local lighting = game:GetService("Lighting")
	lightingState = {
		Brightness = lighting.Brightness,
		Ambient = lighting.Ambient,
		OutdoorAmbient = lighting.OutdoorAmbient,
		ExposureCompensation = lighting.ExposureCompensation,
		GlobalShadows = lighting.GlobalShadows,
		effects = {},
	}
	lighting:SetAttribute("SummonPreviewActive", true)
	-- Neutral portrait lighting keeps the actual Sidekick textures readable over the VFX.
	lighting.Brightness = 1.6
	lighting.Ambient = Color3.fromRGB(140, 140, 150)
	lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	lighting.ExposureCompensation = -0.15
	lighting.GlobalShadows = false
	for _, effect in lighting:GetChildren() do
		if effect:IsA("PostEffect") then
			lightingState.effects[effect] = effect.Enabled
			effect.Enabled = false
		end
	end
	populate()
	canvas.Visible = true
	gui.Reopen.Visible = false
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 40
	freezePlayer(true)
	fit()
end
local function close()
	if not opened then
		return
	end
	opened = false
	for label, enabled in hiddenWorldLabels do
		if label.Parent then
			label.Enabled = enabled
		end
	end
	table.clear(hiddenWorldLabels)
	for _, connection in hudGuards do
		connection:Disconnect()
	end
	table.clear(hudGuards)
	for other, enabled in hiddenHud do
		if other.Parent then
			other.Enabled = enabled
		end
	end
	table.clear(hiddenHud)
	if lightingState then
		local lighting = game:GetService("Lighting")
		for key, value in pairs(lightingState) do
			if key ~= "effects" then
				lighting[key] = value
			end
		end
		for effect, enabled in pairs(lightingState.effects) do
			if effect.Parent then
				effect.Enabled = enabled
			end
		end
	end
	game:GetService("Lighting"):SetAttribute("SummonPreviewActive", nil)
	auto = false
	canvas.Auto.Text = "Auto"
	canvas.Visible = false
	canvas.Modal.Visible = false
	gui.Reopen.Visible = false
	if stage then
		stage:Destroy()
		stage = nil
	end
	hybrid = nil
	motion = {}
	freezePlayer(false)
	if previousCamera then
		camera.CameraType = previousCamera.kind
		camera.CFrame = previousCamera.cf
		camera.FieldOfView = previousCamera.fov
		camera.CameraSubject = previousCamera.subject
	end
end
SummonShrineTheme.Apply(gui)
for _, button in gui:GetDescendants() do
	if button:IsA("TextButton") then
		local caption = button:FindFirstChild("Caption")
		if caption then
			button:GetPropertyChangedSignal("Text"):Connect(function()
				caption.Text = button.Text:gsub("%s*" .. utf8.char(0x25C6), "")
			end)
			button:GetPropertyChangedSignal("TextColor3"):Connect(function()
				caption.TextColor3 = button.TextColor3
			end)
		end
		if button:GetAttribute("PopButton") then
			local scale = button.HoverScale
			local glow = button.HoverGlow.Light
			local hovering = false
			local basePosition = UDim2.fromOffset(
				button:GetAttribute("DesignPosition").X + canvas.Size.X.Offset - 1600,
				button:GetAttribute("DesignPosition").Y + canvas.Size.Y.Offset - 900
			)
			local scaleTween, positionTween, glowTween
			local function animate(size, lift, light, pressed)
				if scaleTween then
					scaleTween:Cancel()
				end
				if positionTween then
					positionTween:Cancel()
				end
				if glowTween then
					glowTween:Cancel()
				end
				local info = TweenInfo.new(
					pressed and 0.08 or 0.16,
					pressed and Enum.EasingStyle.Quad or Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				)
				scaleTween = TweenService:Create(scale, info, { Scale = size })
				positionTween =
					TweenService:Create(button, info, { Position = basePosition + UDim2.fromOffset(0, lift) })
				glowTween = TweenService:Create(glow, TweenInfo.new(0.12), { Transparency = light })
				scaleTween:Play()
				positionTween:Play()
				glowTween:Play()
				button.ZIndex = hovering and 6 or 3
			end
			button.MouseEnter:Connect(function()
				hovering = true
				basePosition = UDim2.fromOffset(
					button:GetAttribute("DesignPosition").X + canvas.Size.X.Offset - 1600,
					button:GetAttribute("DesignPosition").Y + canvas.Size.Y.Offset - 900
				)
				animate(1.055, -4, 0.45, false)
			end)
			button.MouseLeave:Connect(function()
				hovering = false
				animate(1, 0, 1, false)
			end)
			button.MouseButton1Down:Connect(function()
				animate(0.97, 2, 0.65, true)
			end)
			button.MouseButton1Up:Connect(function()
				animate(hovering and 1.055 or 1, hovering and -4 or 0, hovering and 0.45 or 1, false)
			end)
			button.SelectionGained:Connect(function()
				hovering = true
				basePosition = UDim2.fromOffset(
					button:GetAttribute("DesignPosition").X + canvas.Size.X.Offset - 1600,
					button:GetAttribute("DesignPosition").Y + canvas.Size.Y.Offset - 900
				)
				animate(1.055, -4, 0.45, false)
			end)
			button.SelectionLost:Connect(function()
				hovering = false
				animate(1, 0, 1, false)
			end)
		else
			local original = button.BackgroundColor3
			button.MouseEnter:Connect(function()
				TweenService
					:Create(
						button,
						TweenInfo.new(0.12),
						{ BackgroundColor3 = original:Lerp(Color3.new(1, 1, 1), 0.17) }
					)
					:Play()
			end)
			button.MouseLeave:Connect(function()
				TweenService:Create(button, TweenInfo.new(0.18), { BackgroundColor3 = original }):Play()
			end)
		end
	end
end

require(assets.SummonFooter).Bind(canvas)
require(assets.SummonHover).Bind(gui)
local potionCards = {}
for i = 1, 2 do
	local offer = canvas["Offer" .. i]
	local record = { card = offer, index = i, hover = false, tweens = {} }
	table.insert(potionCards, record)
	local function hover(on)
		record.hover = on
		for _, tw in record.tweens do
			tw:Cancel()
		end
		local t = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		record.tweens = {
			TweenService:Create(offer.CardScale, t, { Scale = on and 1.07 or 1 }),
			TweenService:Create(offer.Glow.Light, TweenInfo.new(0.15), { Transparency = on and 0.5 or 1 }),
			TweenService:Create(offer.PotionIcon, t, { Rotation = on and (i == 1 and -8 or 8) or 0 }),
		}
		for _, tw in record.tweens do
			tw:Play()
		end
		offer.ZIndex = on and 6 or 3
	end
	offer.MouseEnter:Connect(function()
		hover(true)
	end)
	offer.MouseLeave:Connect(function()
		hover(false)
	end)
	offer.Buy.SelectionGained:Connect(function()
		hover(true)
	end)
	offer.Buy.SelectionLost:Connect(function()
		hover(false)
	end)
end
-- Bind the imported presentation to existing Anime Run services.
canvas.Visible = false
gui.Reopen.Visible = false
PanelSwitch.Register("Sidekicks", canvas)

local modal = canvas.Modal.Panel
local modalBody = modal:WaitForChild("Body")
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(620, 620)
modal.Heading.Size = UDim2.fromOffset(560, 50)
modal.Dismiss.Position = UDim2.fromOffset(30, 555)
modal.Dismiss.AnchorPoint = Vector2.zero
modal.Dismiss.Size = UDim2.fromOffset(560, 43)
modal.Dismiss.Caption.Size = UDim2.fromScale(1, 1)
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "DetailsScroll"
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromOffset(30, 85)
scroll.Size = UDim2.fromOffset(560, 450)
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 6
scroll.ZIndex = modalBody.ZIndex
scroll.Parent = modal
modalBody.Parent = scroll
modalBody.Position = UDim2.new()
modalBody.Size = UDim2.new(1, -12, 0, 0)
modalBody.AutomaticSize = Enum.AutomaticSize.Y
modalBody.TextScaled = false
modalBody.TextSize = 20
modalBody.TextXAlignment = Enum.TextXAlignment.Left
modalBody.TextYAlignment = Enum.TextYAlignment.Top
modalBody.TextWrapped = true
local modalRows = Instance.new("Frame")
modalRows.Name = "Actions"
modalRows.BackgroundTransparency = 1
modalRows.Size = UDim2.new(1, -12, 0, 0)
modalRows.AutomaticSize = Enum.AutomaticSize.Y
modalRows.ZIndex = modalBody.ZIndex
modalRows.Parent = scroll
local rowLayout = Instance.new("UIListLayout")
rowLayout.Padding = UDim.new(0, 12)
rowLayout.Parent = modalRows

local baseDialog = dialog
dialog = function(title, text)
	for _, child in modalRows:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	modalRows.Visible = false
	modalBody.Visible = true
	scroll.CanvasPosition = Vector2.zero
	baseDialog(title, text)
end
local function actionRow(text, callback)
	local button = canvas.AutoSell:Clone()
	button.Name = "Option"
	button:SetAttribute("PopButton", false)
	button:SetAttribute("DesignPosition", nil)
	button.AnchorPoint = Vector2.zero
	button.Position = UDim2.new()
	button.Size = UDim2.new(1, 0, 0, 48)
	button.Visible = true
	button.ZIndex = modalRows.ZIndex + 1
	button.Text = text
	button.Caption.Text = text
	button.Caption.Size = UDim2.fromScale(1, 1)
	button.Parent = modalRows
	button.Activated:Connect(callback)
	return button
end

local rotation = {}
local showChances
local function refresh()
	canvas.Balance.Text = HudFormat.Short(player:GetAttribute("Gems") or 0)
	canvas.Once.Text = "Once   " .. tostring(player:GetAttribute("SidekickCost1") or Config.SummonCost)
	canvas.Many.Text = "Many   " .. tostring(player:GetAttribute("SidekickCost10") or Config.TenCost)
	canvas.PityCount1.Text =
		string.format("%d / %d", player:GetAttribute("SidekickLegendaryPity") or 0, Config.LegendaryPityCount)
	canvas.PityCount2.Text = string.format("%d / %d", player:GetAttribute("SidekickPity") or 0, Config.PityCount)
	canvas.PityCard1.Track.Progress.Size = UDim2.fromScale(
		math.clamp((player:GetAttribute("SidekickLegendaryPity") or 0) / Config.LegendaryPityCount, 0, 1),
		1
	)
	canvas.PityCard2.Track.Progress.Size =
		UDim2.fromScale(math.clamp((player:GetAttribute("SidekickPity") or 0) / Config.PityCount, 0, 1), 1)
	local unlocked = (player:GetAttribute("RebirthLevel") or 0) >= Config.UnlockRebirth
	canvas.Once.Active, canvas.Many.Active = unlocked, unlocked
	canvas.AutoFuse.Visible = unlocked and player:GetAttribute("SidekickFreeUsed") == false
	canvas.AutoFuseDepth.Visible = canvas.AutoFuse.Visible
	canvas.AutoFuse.Text = "Free summon"
	canvas.AutoFuse.Caption.Text = "Free summon"
	canvas.Tagline.Text = unlocked and "Featured Sidekicks • view all summon chances before spending"
		or string.format("Sidekick summoning unlocks at rebirth %d", Config.UnlockRebirth)
	local seconds =
		math.max(0, math.floor((rotation.EndsAt or workspace:GetServerTimeNow()) - workspace:GetServerTimeNow()))
	canvas.Timer.Text = string.format("⌛  %02d:%02d", seconds // 60, seconds % 60)
end
local function renderRotation()
	rotation = SidekickView.Rotation()
	local mythics, legendaries = {}, {}
	for _, id in rotation.Ids or {} do
		local row = Config.Get(id)
		if row then
			if row.Rarity == "Mythic" then
				table.insert(mythics, row)
			elseif row.Rarity == "Legendary" then
				table.insert(legendaries, row)
			end
		end
	end
	featuredRows = { legendaries[1], mythics[1], legendaries[2] }
	local art = featuredRows[2] and SidekickArt[featuredRows[2].Id]
	canvas.Banner1.UnitArtwork.Image = art and art.Portrait or ""
	for i = 1, 3 do
		local row = featuredRows[i]
		canvas["Unit" .. i].Text = row and row.Name or "Loading rotation…"
		canvas["Rarity" .. i].Text = row and row.Rarity or ""
		canvas["Rarity" .. i].TextColor3 = SidekickView.RarityColor(row and row.Rarity)
	end
	dressStage()
	refresh()
end
showChances = function()
	local tier
	if (player:GetAttribute("SidekickPity") or 0) >= Config.PityCount - 1 then
		tier = "Mythic"
	elseif (player:GetAttribute("SidekickLegendaryPity") or 0) >= Config.LegendaryPityCount - 1 then
		tier = "Legendary"
	end
	local lines = {}
	local count = 0
	for _, id in rotation.Ids or {} do
		if Config.Get(id).Rarity == tier then
			count += 1
		end
	end
	for _, id in rotation.Ids or {} do
		local row = Config.Get(id)
		local odds = tier and (row.Rarity == tier and 100 / math.max(1, count) or 0) or (rotation.Odds or {})[id] or 0
		table.insert(lines, string.format("%s • %s — %.3f%%", row.Name, row.Rarity, odds))
	end
	table.insert(
		lines,
		string.format("Secret — %.3f%%", tier and 0 or ((rotation.Odds or {})[rotation.SecretId] or 0))
	)
	table.insert(lines, "\nLuck and potions do not change Sidekick odds.")
	table.insert(
		lines,
		string.format("Mythic pity: %d. Legendary pity: %d.", Config.PityCount, Config.LegendaryPityCount)
	)
	if tier then
		table.insert(lines, "\n" .. tier .. " guaranteed on the next summon; later results in a 10x roll normally.")
	end
	dialog("SUMMON CHANCES", #lines > 3 and table.concat(lines, "\n") or "Waiting for the server's rotation…")
end

local function setAuto(on)
	auto = on
	canvas.Auto.Text = on and "Stop Auto" or "Auto"
end
local function requestSummon(count, free)
	if busy or revealing or not opened or canvas.Modal.Visible then
		return
	end
	if (player:GetAttribute("RebirthLevel") or 0) < Config.UnlockRebirth then
		setAuto(false)
		toast(string.format("Unlocks at rebirth %d", Config.UnlockRebirth))
		return
	end
	busy = true
	gui:SetAttribute("Summoning", true) -- SidekickTutorial waits on it from the request to the reveal's end
	lastAuto = os.clock()
	local ok, done, results = pcall(function()
		if free then
			return remotes:WaitForChild("SidekickFreeSummon"):InvokeServer()
		end
		return remotes:WaitForChild("SidekickSummon"):InvokeServer(count)
	end)
	if not (ok and done == true and type(results) == "table") then
		busy = false
		gui:SetAttribute("Summoning", nil)
		setAuto(false)
		toast(ok and tostring(results or "Summon unavailable") or "Connection error. Please try again.")
		return
	end
	local continueAuto = auto
	close()
	gui.Enabled = false
	revealing = true
	SidekickReveal.Play(results, function()
		revealing, busy = false, false
		gui.Enabled = true
		if not PanelSwitch.AnyOpen() then
			PanelSwitch.Action("Sidekicks")
			setAuto(continueAuto)
		end
		gui:SetAttribute("Summoning", nil)
		refresh()
	end)
	refresh()
end

local showAutoSell
showAutoSell = function()
	dialog("AUTO SELL", "")
	modalBody.Visible = false
	modalRows.Visible = true
	for _, rarity in { "Common", "Rare", "Legendary", "Mythic", "Secret" } do
		local on = SidekickView.AutoSell(player)[rarity] == true
		actionRow(rarity .. (on and "  •  ON" or "  •  OFF"), function()
			if busy then
				return
			end
			busy = true
			local ok, done = pcall(function()
				return remotes:WaitForChild("SidekickAutoSell"):InvokeServer(rarity, not on)
			end)
			busy = false
			if ok and done == true then
				task.defer(showAutoSell)
			else
				toast("Could not update Auto Sell")
			end
		end)
	end
end
local function buyPack(pack)
	if busy then
		return
	end
	if pack.ProductId <= 0 then
		toast("Coming soon")
		return
	end
	busy = true
	local ok, done, message = pcall(function()
		return remotes:WaitForChild("GemPackBuy"):InvokeServer(pack.Id)
	end)
	busy = false
	if not (ok and done == true) then
		toast(ok and tostring(message or "Purchase unavailable") or "Connection error")
	end
end
for i = 1, 2 do
	local offer = canvas["Offer" .. i]
	local pack = Monetization.GemPacks[i]
	offer.Title.Text = pack.Name .. " Gems"
	offer.Luck.Text = "+" .. HudFormat.Short(pack.Gems) .. " Gems"
	offer.Price.Text = "R$" .. tostring(pack.RobuxPrice)
	offer.PotionIcon.Image = "rbxassetid://136720019410378"
	offer.Buy.Activated:Connect(function()
		buyPack(pack)
	end)
end
canvas.More.Activated:Connect(function()
	dialog("MORE GEMS", "")
	modalBody.Visible = false
	modalRows.Visible = true
	for _, pack in Monetization.GemPacks do
		actionRow(
			string.format("%s  •  %s Gems  •  R$%d", pack.Name, HudFormat.Short(pack.Gems), pack.RobuxPrice),
			function()
				buyPack(pack)
			end
		)
	end
end)
for _, name in { "Pity3", "PityCount3", "PityCard3", "Banner2", "Banner3", "Banner4" } do
	canvas[name].Visible = false
end
canvas.Title.Text = "Summon"
canvas.Subtitle.Text = "Sidekick Banner"
canvas.Banner1.Text = "Featured"
canvas.Banner1.Caption.Text = "Featured"
canvas.Banner1.Activated:Connect(showChances)
canvas.Close.Activated:Connect(function()
	PanelSwitch.Close("Sidekicks")
end)
canvas.Chances.Activated:Connect(showChances)
canvas.Info.Activated:Connect(function()
	dialog(
		"SIDEKICK SUMMONING",
		string.format(
			"The featured rotation changes every 30 minutes.\n\nView Show Chances for every outcome and its odds. Mythic pity is %d; Legendary pity is %d.\n\nSidekicks can be equipped from your Backpack. The server validates every summon and purchase.",
			Config.PityCount,
			Config.LegendaryPityCount
		)
	)
end)
canvas.AutoSell.Activated:Connect(showAutoSell)
canvas.AutoFuse.Activated:Connect(function()
	requestSummon(nil, true)
end)
canvas.Once.Activated:Connect(function()
	requestSummon(1, false)
end)
canvas.Many.Activated:Connect(function()
	requestSummon(10, false)
end)
canvas.Auto.Activated:Connect(function()
	setAuto(not auto)
	if auto then
		requestSummon(1, false)
	end
end)
modal.Dismiss.Activated:Connect(function()
	canvas.Modal.Visible = false
end)
canvas:GetPropertyChangedSignal("Visible"):Connect(function()
	if canvas.Visible then
		renderRotation()
		open()
	else
		close()
	end
end)
ReplicatedStorage:GetAttributeChangedSignal("SidekickRotation"):Connect(renderRotation)
player.AttributeChanged:Connect(function(name)
	if name == "Gems" or name == "RebirthLevel" or name:sub(1, 8) == "Sidekick" then
		refresh()
	end
end)
task.spawn(function()
	local models = ReplicatedStorage:WaitForChild("SidekickModels")
	models.ChildAdded:Connect(function()
		if opened then
			dressStage()
		end
	end)
	if opened then
		dressStage()
	end
end)
task.spawn(function()
	while gui.Parent do
		task.wait(1)
		if opened then
			refresh()
		end
		if
			auto
			and not busy
			and not revealing
			and opened
			and not canvas.Modal.Visible
			and os.clock() - lastAuto >= 3
		then
			requestSummon(1, false)
		end
	end
end)
SummonShrineTheme.Apply(gui)
renderRotation()
fit()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
player.CharacterAdded:Connect(function(character)
	local hum = character:WaitForChild("Humanoid")
	if opened then
		previousSpeed = hum.WalkSpeed
		previousJump = hum.JumpPower
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end
end)
RunService:BindToRenderStep("SummonDisplay", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not opened then
		return
	end
	camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 40
	local aspect = camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1)
	local distance = 18 * math.max(1, (16 / 9) / aspect)
	local mouse = UserInputService:GetMouseLocation()
	local view = camera.ViewportSize
	local targetDrift = UserInputService.MouseEnabled
			and Vector2.new(
				math.clamp(mouse.X / math.max(view.X, 1) * 2 - 1, -1, 1),
				math.clamp(mouse.Y / math.max(view.Y, 1) * 2 - 1, -1, 1)
			)
		or Vector2.zero
	cameraDrift = cameraDrift:Lerp(targetDrift, 1 - math.exp(-dt * 5))
	local offset = Vector3.new(cameraDrift.X * 1.05, -cameraDrift.Y * 0.675, 0)
	if hybrid then
		camera.CFrame, camera.FieldOfView = hybrid:Frame(view, cameraDrift, elapsed, UiMotion.Reduced())
	else
		camera.CFrame = CFrame.lookAt(
			Vector3.new(0, 10001, -distance) + offset,
			Vector3.new(0, 10000, 0) + offset * 0.35
		) * CFrame.Angles(0, 0, -cameraDrift.X * 0.011)
	end

	camera.Focus = CFrame.new(0, 10000, 0)
	elapsed += math.min(dt, 0.1)
	for _, record in potionCards do
		local offer = record.card
		offer.Border.Prism.Rotation = (elapsed * 38 + record.index * 90) % 360
		offer.Gradient.Rotation = 35 + math.sin(elapsed * 0.65 + record.index) * 22
		offer.Sheen.Sweep.Offset = Vector2.new(((elapsed * 0.25 + record.index * 0.5) % 1) * 2.6 - 1.3, 0)
	end
	for _, record in motion do
		local phase = UiMotion.Reduced() and record.index * 1.5 or elapsed * 0.75 + record.index * 1.5
		local cf = record.base
			* CFrame.new(0, math.sin(phase) * 0.09, 0)
			* CFrame.Angles(0, math.sin(phase * 0.65) * 0.055, math.sin(phase) * 0.014)
		record.model:SetPrimaryPartCFrame(cf)
		for _, entry in record.parts do
			local extra = entry.part.Name:find("Arm") and CFrame.Angles(0, 0, math.sin(phase) * 0.022) or CFrame.new()
			entry.part.CFrame = cf * entry.pose * extra
		end
		if false then -- Display names stay in their authored columns.
			local point = camera:WorldToViewportPoint(record.model.ImportedAura.Torso.Position)
			local center = point.X / canvas.ResponsiveScale.Scale
			for _, label in { canvas.Unit3, canvas.Rarity3 } do
				label.Position = UDim2.fromOffset(center - label.Size.X.Offset * 0.5, label.Position.Y.Offset)
			end
		end
		for _, entry in record.supports do
			entry.part.CFrame = entry.body.CFrame * entry.offset
		end
	end
	-- Auto summon is scheduled by the server-backed binding below.
end)
gui.Destroying:Connect(function()
	close()
	RunService:UnbindFromRenderStep("SummonDisplay")
	template:Destroy()
end)
-- Opened only through Anime Run PanelSwitch.

-- Center the side labels on their actual models, including responsive camera framing.
RunService.RenderStepped:Connect(function()
	if not opened or not stage then
		return
	end
	local k = canvas.ResponsiveScale.Scale
	for _, index in { 1, 3 } do
		local unit = stage.Units:FindFirstChild("Unit" .. index)
		local model = unit and unit:FindFirstChild("ActualSidekick")
		if model then
			local box = model:GetBoundingBox()
			local projected = camera:WorldToViewportPoint(box.Position)
			local x = (projected.X - canvas.AbsolutePosition.X) / k
			for _, prefix in { "Unit", "Rarity" } do
				local label = canvas[prefix .. index]
				label.TextXAlignment = Enum.TextXAlignment.Center
				label.Position =
					UDim2.fromOffset(x - label.Size.X.Offset * (0.5 - label.AnchorPoint.X), label.Position.Y.Offset)
			end
		end
	end
end)
