--!nonstrict
-- Three 3D team previews, attached only to the Backpack's existing SlotPicker instance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(shared:WaitForChild("CharacterCatalog"))
local Factory = require(shared:WaitForChild("RunnerFactory"))
local Config = require(shared:WaitForChild("GachaConfig"))
local Skin = require(script.Parent:WaitForChild("AnimeSkin"))
local TeamSlots = {}
local function make(class, name, parent, props)
	local instance = Instance.new(class)
	instance.Name = name
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end
-- A single purpose-drawn wide card; Fit keeps dots and corner cuts proportional.
local function landscapeCard(card)
	card.Image = "rbxassetid://107913096286813"
	card.ScaleType = Enum.ScaleType.Fit
	card.ImageTransparency = 0
end
function TeamSlots.Attach(picker)
	local previews = {}
	local lastLayout
	local baseLayout, baseUpdate = picker.Layout, picker.Update
	-- These models are anchored six-part meshes, so pose their local parts directly.
	local function pose(preview, rig, slot)
		local root = rig:GetPivot()
		local styles = {
			{ LeftArm = Vector3.new(-25, 0, -28), RightArm = Vector3.new(-55, 0, 24) },
			{ LeftArm = Vector3.new(-48, 0, -20), RightArm = Vector3.new(12, 0, 18) },
			{ LeftArm = Vector3.new(-35, 0, -32), RightArm = Vector3.new(-35, 0, 32) },
		}
		for _, row in Factory.PARTS do
			local part = rig:FindFirstChild(row[1])
			if part and part:IsA("BasePart") then
				local base = root:ToObjectSpace(part.CFrame)
				local angles = styles[slot][row[1]]
				if angles then
					local joint = CFrame.new(0, row[2].Y / 2, 0)
					part.CFrame = root
						* base
						* joint
						* CFrame.Angles(math.rad(angles.X), 0, math.rad(angles.Z))
						* joint:Inverse()
				elseif row[1] == "Head" then
					part.CFrame = root * base * CFrame.Angles(0, math.rad((slot - 2) * 9), math.rad((slot - 2) * 4))
				elseif row[1] == "LeftLeg" or row[1] == "RightLeg" then
					local sign = row[1] == "LeftLeg" and -1 or 1
					local joint = CFrame.new(0, row[2].Y / 2, 0)
					part.CFrame = root
						* base
						* joint
						* CFrame.Angles(math.rad(sign * 5), 0, math.rad(sign * 7))
						* joint:Inverse()
				end
			end
		end
		preview.Rig, preview.Base = rig, rig:GetPivot()
	end
	local function fit(preview)
		local rig = preview.Scene:FindFirstChild("Runner")
		if not rig then
			return
		end
		local box, size = rig:GetBoundingBox()
		local aspect = math.max(0.2, preview.View.AbsoluteSize.X / math.max(1, preview.View.AbsoluteSize.Y))
		local tangent = math.tan(math.rad(preview.Camera.FieldOfView / 2))
		-- Portrait crop: fill the slot with the head and upper torso, allowing the legs offscreen.
		local portraitHeight = size.Y * 0.56
		local distance = math.max(portraitHeight / 2 / tangent, size.X / 2 / tangent / aspect) * 1.05 + size.Z / 2
		local focus = box.Position + Vector3.new(0, size.Y * 0.24, 0)
		-- A longer, straight-on lens keeps the head and shoulders in natural proportion.
		preview.Camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0, -distance), focus)
	end
	local function updateModels(force)
		local characterMode = picker.Kind == "Character"
		local team = string.split(player:GetAttribute("Team") or "", ",")
		for slot, preview in previews do
			local refs = picker.Buttons[slot]
			preview.View.Visible = characterMode
			preview.Empty.Visible = characterMode
			if not characterMode then
				local card = refs.Button:FindFirstChild("AnimeCard")
				if card then
					card.Visible = false
				end
				refs.Button.BackgroundTransparency = 0
				continue
			end
			local spec = Catalog.Get(team[slot])
			preview.Empty.Visible = spec == nil
			preview.Empty.Text = "EMPTY SLOT"
			local tint = spec and Config.RARITY_COLORS[spec.Rarity] or Color3.fromRGB(45, 145, 210)
			local card = Skin.Card(refs.Button, tint)
			landscapeCard(card)
			card.Visible = true
			local id = spec and spec.Id or ""
			local loaded = spec and Factory.HasModel(id) or false
			if force or preview.Id ~= id or preview.Loaded ~= loaded then
				preview.Rig = nil
				preview.Scene:ClearAllChildren()
				preview.Id, preview.Loaded = id, loaded
				preview.View:SetAttribute("CharacterId", id)
				if spec then
					local ok, rig = pcall(Factory.build, id)
					if ok and rig then
						rig.Name = "Runner"
						local name = rig:FindFirstChild("NameLabel")
						if name then
							name:Destroy()
						end
						for _, part in rig:GetDescendants() do
							if part:IsA("BasePart") then
								part.Anchored = true
								part.CanCollide = false
								part.CanTouch = false
								part.CanQuery = false
							end
						end
						rig.Parent = preview.Scene
						pose(preview, rig, slot)
						fit(preview)
					else
						preview.Empty.Visible = true
						preview.Empty.Text = "LOADING MODEL"
						warn("[BackpackTeamSlots] Preview failed for " .. id .. ": " .. tostring(rig))
					end
				end
			end
		end
	end
	for slot, refs in picker.Buttons do
		local button = refs.Button
		button.ClipsDescendants = false
		refs.Title.ZIndex, refs.Items.ZIndex = 5, 5
		local view = make("ViewportFrame", "CharacterPreview", button, {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 3,
			Active = false,
			Ambient = Color3.fromRGB(190, 190, 210),
			LightColor = Color3.fromRGB(255, 247, 237),
			LightDirection = Vector3.new(-1, -2, -3),
			Visible = false,
		})
		local scene = make("WorldModel", "Scene", view, {})
		local camera = make("Camera", "PreviewCamera", view, {
			FieldOfView = 18,
			FieldOfViewMode = Enum.FieldOfViewMode.Vertical,
		})
		view.CurrentCamera = camera
		local empty = make("TextLabel", "EmptySlot", button, {
			BackgroundTransparency = 1,
			Text = "EMPTY SLOT",
			TextColor3 = Color3.fromRGB(145, 170, 200),
			ZIndex = 4,
			Visible = false,
			TextScaled = true,
		})
		local preview = { View = view, Scene = scene, Camera = camera, Empty = empty }
		previews[slot] = preview
		view:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			fit(preview)
		end)
	end
	function picker:Layout(g)
		lastLayout = g
		baseLayout(self, g)
		for slot, preview in previews do
			if self.Kind == "Character" then
				local refs = self.Buttons[slot]
				refs.Title.Position = g.at(12, 5)
				refs.Title.Size = UDim2.new(1, -g.px(24), 0, g.px(24))
				refs.Title.TextXAlignment = Enum.TextXAlignment.Left
				refs.Items.Position = UDim2.new(0, g.px(10), 1, -g.px(29))
				refs.Items.Size = UDim2.new(1, -g.px(20), 0, g.px(24))
				refs.Items.TextXAlignment = Enum.TextXAlignment.Center
				g.Role(refs.Title, "Body")
				g.Role(refs.Items, "Item")
				-- Render behind both labels: the name overlays the model instead of cropping it.
				preview.View.Position = g.at(6, 6)
				preview.View.Size = UDim2.new(1, -g.px(12), 1, -g.px(12))
				preview.Empty.Position = g.at(10, 36)
				preview.Empty.Size = UDim2.new(1, -g.px(20), 1, -g.px(70))
				g.Role(preview.Empty, "Caption")
				self.Height = self.Frame.Size.Y.Offset
				fit(preview)
			else
				preview.View.Visible = false
				preview.Empty.Visible = false
			end
		end
	end
	function picker:Update(kind, id)
		baseUpdate(self, kind, id)
		updateModels(false)
		if lastLayout then
			self:Layout(lastLayout)
		end
	end
	-- Replace placeholders when uploaded models finish loading; only the three visible models are rendered.
	task.spawn(function()
		local models = ReplicatedStorage:WaitForChild("CharacterModels")
		local queued = false
		local function refresh()
			if queued or not picker.Frame.Parent.Visible or picker.Kind ~= "Character" then
				return
			end
			queued = true
			task.defer(function()
				queued = false
				updateModels(true)
			end)
		end
		models:GetAttributeChangedSignal("Ready"):Connect(refresh)
		models.ChildAdded:Connect(function()
			updateModels(false)
		end)
		models.AttributeChanged:Connect(function(name)
			if name:sub(1, 7) == "Loaded_" then
				refresh()
			end
		end)
	end)
	-- One throttled connection for all slots; never accumulate transforms frame to frame.
	local elapsed = 0
	local motion
	motion = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 30 then
			return
		end
		elapsed = 0
		if picker.Kind ~= "Character" or not picker.Frame.Visible or not picker.Frame.Parent.Visible then
			return
		end
		local time = os.clock()
		for slot, preview in previews do
			if preview.Rig and preview.Rig.Parent then
				local phase = time * 1.8 + slot * 2.1
				preview.Rig:PivotTo(
					preview.Base
						* CFrame.new(0, math.sin(phase) * 0.1, 0)
						* CFrame.Angles(
							math.rad(math.sin(phase * 0.7) * 2),
							math.rad((slot - 2) * -6 + math.sin(phase * 0.6) * 3),
							math.rad(math.sin(phase) * 2)
						)
				)
			end
		end
	end)
	picker.Frame.Destroying:Once(function()
		motion:Disconnect()
	end)
	return picker
end
return TeamSlots
