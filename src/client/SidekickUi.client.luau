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
local SummonAltarFx = require(script.Parent:WaitForChild("SummonAltarFx"))
local SummonPanels = require(script.Parent:WaitForChild("SummonPanels"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local SummonScroll = require(script.Parent:WaitForChild("SummonScroll"))
local TouchTarget = require(script.Parent:WaitForChild("TouchTarget"))
local SummonHybrid = require(script.Parent:WaitForChild("SummonHybrid"))
local assets = ReplicatedStorage:WaitForChild("SummonScreenAssets")
local LegendaryAuraStyle = require(assets:WaitForChild("LegendaryAuraStyle"))
local featuredRows = {}
local busy, revealing = false, false
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
-- The authored page and stage: a missing part warns instead of waiting forever with no message.
local function need(parent, name)
	local child = parent and parent:WaitForChild(name, 30)
	if not child then
		warn("SidekickUi: " .. (parent and parent:GetFullName() or "?") .. "." .. name .. " is missing")
	end
	return child
end
local gui = need(player:WaitForChild("PlayerGui"), "RacerSidekicks")
local canvas = need(gui, "Canvas")
local savedStage = need(assets, "SummoningStage")
if not (canvas and savedStage) then
	return
end
for i = 1, 3 do
	local unit = need(need(savedStage, "Units"), "Unit" .. i)
	need(unit, "Root")
	need(need(unit, "ImportedAura"), "RightArm")
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
local page -- SummonScroll, the R3 hanging-scroll layout (design doc 4.45); made below
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
			if y >= 650 and not obj:GetAttribute("ScrollItem") then -- the scroll's content stays on the scroll
				y += height - 900
			end
			obj.Position = UDim2.fromOffset(x, y)
			obj:SetAttribute("DojoHome", obj.Position)
		end
	end
	if page then
		page.Scroll.SetHome(page.Scroll.Root.Position)
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
-- The world's BillboardGuis, kept up to date from one scan at start, so opening never walks the whole workspace.
local worldLabels = setmetatable({}, { __mode = "k" })
task.defer(function()
	workspace.DescendantAdded:Connect(function(label)
		if label:IsA("BillboardGui") then
			worldLabels[label] = true
		end
	end)
	workspace.DescendantRemoving:Connect(function(label)
		worldLabels[label] = nil
	end)
	for _, label in workspace:GetDescendants() do
		if label:IsA("BillboardGui") then
			worldLabels[label] = true
		end
	end
end)
local function open()
	if opened then
		return
	end
	previousCamera =
		{ kind = camera.CameraType, cf = camera.CFrame, fov = camera.FieldOfView, subject = camera.CameraSubject }
	opened = true
	for label in worldLabels do
		if label.Parent and not (stage and label:IsDescendantOf(stage)) then
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
page = SummonScroll.Apply(canvas)
for _, button in gui:GetDescendants() do
	if button:IsA("TextButton") then
		local caption = button:FindFirstChild("Caption")
		if caption then
			button:GetPropertyChangedSignal("Text"):Connect(function()
				caption.Text = button.Text:gsub("%s*" .. utf8.char(0x25C6), "")
			end)
		end
	end
end
-- Hanging tags sway a little on hover (R1 tags, design doc 4.45).
for i = 1, 2 do
	local offer = canvas["Offer" .. i]
	local function sway(on)
		UiMotion.Create(offer, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Rotation = on and -3 or 0 }):Play()
	end
	offer.MouseEnter:Connect(function()
		sway(true)
	end)
	offer.MouseLeave:Connect(function()
		sway(false)
	end)
	offer.Buy.SelectionGained:Connect(function()
		sway(true)
	end)
	offer.Buy.SelectionLost:Connect(function()
		sway(false)
	end)
end
-- Bind the imported presentation to existing Anime Run services.
canvas.Visible = false
gui.Reopen.Visible = false
PanelSwitch.Register("Sidekicks", canvas, require(shared:WaitForChild("UiTheme")).Dojo.Sakura) -- the Sakura transition (design doc 4.45)

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

local rotation = {}
local panels -- SummonPanels, the reference sheet's panels (design doc 4.45); made below
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
	canvas.Timer.Text = string.format("%02d:%02d", seconds // 60, seconds % 60)
	local sums = {}
	for id, odds in rotation.Odds or {} do
		local row = Config.Get(id)
		if row and (table.find(rotation.Ids or {}, id) or id == rotation.SecretId) then
			sums[row.Rarity] = (sums[row.Rarity] or 0) + odds
		end
	end
	page.Refresh({
		Featured = featuredRows[2],
		FeaturedOdds = featuredRows[2] and (rotation.Odds or {})[featuredRows[2].Id],
		Sums = sums,
		Unlocked = unlocked,
		UnlockRebirth = Config.UnlockRebirth,
		OnceCost = player:GetAttribute("SidekickCost1") or Config.SummonCost,
		ManyCost = player:GetAttribute("SidekickCost10") or Config.TenCost,
		Auto = auto,
		Busy = busy, -- a summon request is on its way: the tiles lock and the tagline says so
	})
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
	-- Presentation order only (4.45 "Summon 1:1 reference": Beroo left, Ryuuk right); the rotation itself is untouched.
	table.sort(legendaries, function(a, b)
		return a.Name < b.Name
	end)
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
	if panels then
		panels.Refresh() -- an open Details follows the live banner (SIDEKICK_SPEC "Panels", owner 2026-11-20)
	end
end

local function setAuto(on)
	auto = on
	canvas.Auto.Text = on and "Stop Auto" or "Auto"
	refresh()
end
local closedMidRequest = false -- the player closed the page while a summon was on its way: it stays closed after
local function requestSummon(count, free)
	if busy or revealing or not opened or canvas.Modal.Visible or (panels and panels.IsOpen()) then
		return
	end
	if (player:GetAttribute("RebirthLevel") or 0) < Config.UnlockRebirth then
		setAuto(false)
		UiFeedback.Play("Denied")
		toast(string.format("Unlocks at rebirth %d", Config.UnlockRebirth))
		return
	end
	busy = true
	closedMidRequest = false
	gui:SetAttribute("Summoning", true) -- SidekickTutorial waits on it from the request to the reveal's end
	lastAuto = os.clock()
	UiFeedback.Play("Toggle")
	refresh()
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
		UiFeedback.Play("Denied")
		toast(ok and tostring(results or "Summon unavailable") or "Connection error. Please try again.")
		return
	end
	local continueAuto = auto
	revealing = true
	panels.Record(results)
	-- The altar activation in the best result's colour (design doc 4.45), then the reveal as before.
	local centre = stage and stage.Units:FindFirstChild("Unit2")
	local root = centre and centre:FindFirstChild("Root")
	if root and workspace.CurrentCamera then
		local point = workspace.CurrentCamera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0))
		local rarity = SummonAltarFx.Best(results, function(result)
			return Config.Get(result.Id)
		end)
		local landed = false
		local fxOk = pcall(SummonAltarFx.Play, Vector2.new(point.X, point.Y), rarity, function()
			landed = true
		end)
		local waited = 0
		while fxOk and not landed and waited < 2 do -- never stuck on the effect
			waited += task.wait()
		end
	end
	close()
	gui.Enabled = false
	local function revealed()
		revealing, busy = false, false
		gui.Enabled = true
		lastAuto = os.clock() -- the page shows a moment before the next Auto summon, so Stop can be pressed
		if not PanelSwitch.AnyOpen() and not closedMidRequest then
			canvas:SetAttribute("SkipTransition", true) -- back from a reveal: no page transition (design doc 4.45)
			PanelSwitch.Action("Sidekicks")
			canvas:SetAttribute("SkipTransition", nil)
			setAuto(continueAuto)
			-- One summon by hand: the "You Obtained!" panel (reference sheet panel 8). Auto runs on without it.
			if #results == 1 and not continueAuto then
				task.defer(panels.Result, results[1])
			end
		end
		gui:SetAttribute("Summoning", nil)
		refresh()
	end
	-- Auto runs on without a click: its reveal closes itself (owner approved the audit fixes 2026-11-20).
	local played, problem = pcall(SidekickReveal.Play, results, revealed, nil, continueAuto)
	if not played then
		warn("SidekickUi: reveal failed: " .. tostring(problem))
		local left = player.PlayerGui:FindFirstChild("RacerSidekickReveal")
		if left then
			left:Destroy()
		end
		continueAuto = false
		revealed()
		toast("Summoned! Your Sidekicks are in your Bag.")
	end
	refresh()
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
panels = SummonPanels.new(canvas, {
	Rotation = function()
		return rotation
	end,
	Toast = toast,
	BuyPack = buyPack,
	Packs = Monetization.GemPacks,
	Remotes = remotes,
	-- Equip from the result: the new Sidekick goes on the Team's first runner (SidekickEquip; the server checks it).
	Equip = function(id)
		if busy then
			return
		end
		local entry
		for _, item in SidekickView.Bag(player) do
			if item.Id == id then
				entry = item.Entry
			end
		end
		local leader = string.split(player:GetAttribute("Team") or "", ",")[1]
		busy = true
		local ok, done, message = pcall(function()
			return remotes:WaitForChild("SidekickEquip"):InvokeServer(leader, entry)
		end)
		busy = false
		UiFeedback.Play(ok and done and "Equip" or "Denied")
		toast(ok and done and "Equipped on your first runner" or tostring(ok and message or "Connection error"))
	end,
})
for i = 1, 2 do
	local offer = canvas["Offer" .. i]
	local pack = Monetization.GemPacks[i]
	offer.Title.Text = pack.Name .. " Gems"
	offer.Luck.Text = "+" .. string.upper(HudFormat.Short(pack.Gems)) .. " Gems" -- "+1K Gems" as the reference
	offer.Price.Text = "R$" .. tostring(pack.RobuxPrice)
	offer.PotionIcon.Image = "rbxassetid://136720019410378"
	offer.Buy.Activated:Connect(function()
		panels.BuyGems(pack) -- the Buy Gems focus state first (reference sheet panel 9)
	end)
end
canvas.More.Activated:Connect(function()
	panels.More()
end)
for _, name in { "Pity3", "PityCount3", "PityCard3", "Banner2", "Banner3", "Banner4" } do
	canvas[name].Visible = false
end
canvas.Title.Text = "Summon"
canvas.Subtitle.Text = "Sidekick Banner"
canvas.Banner1.Text = "Featured"
canvas.Banner1.Caption.Text = "Featured"
canvas.Banner1.Activated:Connect(function()
	panels.Featured()
end)
-- The small controls also get a 44 px tap area on phones (audit 2026-11-20, U1); the page's look stays as drawn.
for name, fn in
	{
		Close = function()
			PanelSwitch.Close("Sidekicks")
		end,
		Chances = function()
			panels.Chances()
		end,
		Info = function()
			panels.Info()
		end,
		AutoSell = function()
			panels.AutoSell()
		end,
		AutoFuse = function()
			requestSummon(nil, true)
		end,
	}
do
	canvas[name].Activated:Connect(fn)
	TouchTarget.Add(canvas[name], fn)
end
-- Back (gamepad B, Escape): an open panel or dialog closes first, then the page (U6, audit 2026-11-20).
PanelSwitch.SetBack("Sidekicks", function()
	if panels.IsOpen() then
		panels.Hide()
		return true
	end
	if canvas.Modal.Visible then
		canvas.Modal.Visible = false
		return true
	end
	return false
end)
canvas.Once.Activated:Connect(function()
	requestSummon(1, false)
end)
canvas.Many.Activated:Connect(function()
	-- The Many confirmation first (reference sheet panel 7); the server still checks Gems and spends them.
	local cost = player:GetAttribute("SidekickCost10") or Config.TenCost
	panels.ConfirmMany(10, cost, function()
		requestSummon(10, false)
	end)
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
		page.Open()
	else
		if busy and not revealing then
			closedMidRequest = true
		end
		panels.Hide()
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
			and not panels.IsOpen()
			and os.clock() - lastAuto >= 3
		then
			requestSummon(1, false)
		end
	end
end)
-- Any close runs under the Sakura wash: the scroll rolls up as the wash starts (design doc 4.45).
task.spawn(function()
	local wash = player:WaitForChild("PlayerGui"):WaitForChild("UiTransition")
	wash:GetAttributeChangedSignal("Playing"):Connect(function()
		if wash:GetAttribute("Playing") and opened and canvas.Visible then
			page.Close()
		end
	end)
end)
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
