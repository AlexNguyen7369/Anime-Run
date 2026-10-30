--!nonstrict
-- The placeholder anime runner (docs/WORLD_REDESIGN_SPEC.md section 2): a blocky humanoid rig (Head, Torso, 2 arms,
-- 2 legs, chibi head 1:3) coloured from the character's series palette with a rarity trim and a name label. Every
-- part is anchored and non-colliding: RaceService moves the rig along the race path, clients only redraw it.
-- The Torso is the PrimaryPart (auras and trails attach to it). Sizes and colours are placeholders.

local CharacterCatalog = require(script.Parent.CharacterCatalog)
local GachaConfig = require(script.Parent.GachaConfig)

local RunnerFactory = {}

RunnerFactory.HIP_HEIGHT = 3 -- studs from the feet (rig bottom) up to the Torso centre, the rig's pivot
RunnerFactory.NAME_DISTANCE = 120 -- studs: the name label shows within this distance (placeholder)

-- Series palettes (placeholder): Body = Torso, Legs, Skin = Head and arms
local SKIN = Color3.fromRGB(255, 214, 170)
RunnerFactory.PALETTES = {
	leaf = { Body = Color3.fromRGB(255, 128, 20), Legs = Color3.fromRGB(40, 50, 90) },
	db = { Body = Color3.fromRGB(240, 100, 30), Legs = Color3.fromRGB(30, 60, 160) },
	sea = { Body = Color3.fromRGB(200, 30, 40), Legs = Color3.fromRGB(70, 110, 190) },
	ds = { Body = Color3.fromRGB(20, 110, 90), Legs = Color3.fromRGB(25, 25, 35) },
	jk = { Body = Color3.fromRGB(30, 35, 70), Legs = Color3.fromRGB(30, 35, 70) },
	mha = { Body = Color3.fromRGB(30, 140, 110), Legs = Color3.fromRGB(200, 40, 40) },
}
RunnerFactory.DEFAULT_PALETTE = { Body = Color3.fromRGB(110, 170, 230), Legs = Color3.fromRGB(50, 60, 80) }

-- name, size, offset from the Torso centre (x right, y up)
local PARTS = {
	{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) },
	{ "Head", Vector3.new(2, 2, 2), Vector3.new(0, 2, 0) },
	{ "LeftArm", Vector3.new(0.8, 2, 0.8), Vector3.new(-1.4, 0, 0) },
	{ "RightArm", Vector3.new(0.8, 2, 0.8), Vector3.new(1.4, 0, 0) },
	{ "LeftLeg", Vector3.new(0.95, 2, 1), Vector3.new(-0.5, -2, 0) },
	{ "RightLeg", Vector3.new(0.95, 2, 1), Vector3.new(0.5, -2, 0) },
	{ "Trim", Vector3.new(2.1, 0.35, 1.1), Vector3.new(0, -0.8, 0) }, -- rarity belt
}
RunnerFactory.PARTS = PARTS

-- The rig's colours: { Body, Legs, Skin, Trim }. options.Color overrides the body (NPC rivals).
function RunnerFactory.Colors(characterId, options)
	local spec = CharacterCatalog.Get(characterId)
	local palette = spec and RunnerFactory.PALETTES[spec.Series] or RunnerFactory.DEFAULT_PALETTE
	local trim = spec and GachaConfig.RARITY_COLORS[spec.Rarity] or GachaConfig.RARITY_COLORS.Common
	return {
		Body = options and options.Color or palette.Body,
		Legs = palette.Legs,
		Skin = SKIN,
		Trim = trim,
	}
end

local function part(model, name, size, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.Parent = model
	return p
end

-- Builds the rig for `characterId` (any string; unknown ids get the default palette), standing with its feet at the
-- origin, facing -Z. options: { Color = Color3 (body), Label = string (name text) }. Not parented.
function RunnerFactory.build(characterId, options)
	local spec = CharacterCatalog.Get(characterId)
	local colors = RunnerFactory.Colors(characterId, options)
	local model = Instance.new("Model")
	model.Name = "Runner"
	model:SetAttribute("CharacterId", characterId)
	local byPart = {
		Torso = colors.Body,
		Head = colors.Skin,
		LeftArm = colors.Skin,
		RightArm = colors.Skin,
		LeftLeg = colors.Legs,
		RightLeg = colors.Legs,
		Trim = colors.Trim,
	}
	local root = CFrame.new(0, RunnerFactory.HIP_HEIGHT, 0)
	for _, p in PARTS do
		local inst = part(model, p[1], p[2], byPart[p[1]])
		inst.CFrame = root * CFrame.new(p[3])
	end
	local torso = model.Torso
	model.PrimaryPart = torso

	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = model.Head

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameLabel"
	billboard.Adornee = model.Head
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.MaxDistance = RunnerFactory.NAME_DISTANCE
	billboard.LightInfluence = 0
	billboard.Parent = model
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = options and options.Label or spec and spec.Name or tostring(characterId)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = colors.Trim:Lerp(Color3.new(0, 0, 0), 0.5)
	label.Parent = billboard
	return model
end

-- Re-colours an existing rig as `characterId` in place (same parts, so attachments and effects on the Torso stay).
function RunnerFactory.Restyle(model, characterId)
	local spec = CharacterCatalog.Get(characterId)
	local colors = RunnerFactory.Colors(characterId)
	local byPart = {
		Torso = colors.Body,
		Head = colors.Skin,
		LeftArm = colors.Skin,
		RightArm = colors.Skin,
		LeftLeg = colors.Legs,
		RightLeg = colors.Legs,
		Trim = colors.Trim,
	}
	for name, color in byPart do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color = color
		end
	end
	local label = model:FindFirstChild("NameLabel")
	label = label and label:FindFirstChild("Name")
	if label then
		label.Text = spec and spec.Name or tostring(characterId)
	end
	model:SetAttribute("CharacterId", characterId)
end

return RunnerFactory
