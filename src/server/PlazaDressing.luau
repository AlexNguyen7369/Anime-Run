--!nonstrict
-- The plaza and Dojo meshes (design doc 4.24, WORLD_REDESIGN_SPEC 7), drafted in tools/blender/plaza/build_plaza.py.
-- Runs in the background after the world is built. SpawnArea and WorkshopBuilder still build the gameplay parts:
-- prompts, pads, zones and collision stay on them. A loaded mesh only turns its stand-in invisible, so a failed
-- load leaves the plain stand-in working. ReplicatedStorage attribute PlazaReady turns true when done.
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.PlazaAssets)
local UiTheme = require(Shared.UiTheme)
local WorkshopConfig = require(Shared.WorkshopConfig)

local PlazaDressing = {}

local TOP = 1 -- SpawnArea.TOP_Y
local SIGN_HEIGHT = { [1] = 24, [4] = 32, [7] = 38, [10] = 44 } -- owner's sign above each tier's roof (studs)
-- Stand-ins a mesh replaces: SpawnArea child -> mesh key
local REPLACES = {
	StartGate = "HeroTorii",
	ShopStall = "SHOPStall",
	PotionsStall = "POTIONSStall",
	RebirthShrine = "RebirthShrine",
	IndexBoard = "IndexBoard",
	Spawn = "SpawnMosaic",
}

local IMPORT_TURN = CFrame.Angles(0, math.pi, 0) -- the glTF import turns a mesh 180 degrees, as it does the runner rigs

local templates = {} -- key -> { part name -> { Part, Center } }

local function loadAsset(key, row)
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(row.Asset)
	end)
	if not ok then
		warn("[PlazaDressing] " .. key .. " failed to load, keeping the stand-in: " .. tostring(asset))
		return
	end
	local parts = {}
	for _, d in asset:GetDescendants() do
		local spec = d:IsA("MeshPart") and row.Parts[d.Name]
		if spec then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Size = spec.Size
			if spec.Glow then
				d.Material = Enum.Material.Neon
				d.TextureID = ""
				d.Color = Color3.fromHex(spec.Glow)
				d.CastShadow = false
			else
				d.Material = Enum.Material.SmoothPlastic
			end
			d.Parent = nil
			parts[d.Name] = { Part = d, Center = spec.Center }
		end
	end
	asset:Destroy()
	if next(parts) then
		templates[key] = parts
	end
end

-- Clones mesh `key` so its local frame is at `frame`. Returns the model, or nil when it failed to load.
local function place(key, frame, parent, name)
	local parts = templates[key]
	if not parts then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name or key
	for _, t in parts do
		local clone = t.Part:Clone()
		clone.CFrame = frame * CFrame.new(t.Center) * IMPORT_TURN
		clone.Parent = model
	end
	model.Parent = parent
	return model
end

-- An asset's front is its local +Z (Blender -Y through the glTF export).
local function frameOf(position, face)
	return CFrame.lookAt(position, position - face)
end

local function hide(root)
	for _, d in (root:IsA("BasePart") and { root } or root:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CastShadow = false
		elseif d:IsA("SurfaceGui") or (d:IsA("BillboardGui") and d.Name == "Title") then
			d.Enabled = false -- the mesh has its own sign
		end
	end
end

-- Text on a board: a thin invisible part facing `face`, carrying a SurfaceGui.
local function sign(text, position, face, size, color, parent)
	local holder = Instance.new("Part")
	holder.Name = "Sign"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(math.max(#text * size * 0.72, 2), size * 1.3, 0.1)
	holder.CFrame = CFrame.lookAt(position, position + face)
	holder.Parent = parent
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = UiTheme.Font
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = gui
end

-- The Dojo look of a plot follows its Workshop's level; a free plot gets the closed shell.
local function tierOf(level)
	local best = 1
	for tier in Layout.Tiers do
		if tier > 0 and tier <= level and tier > best then
			best = tier
		end
	end
	return best
end

local function dressPlot(plot)
	local base = plot:FindFirstChild("Base")
	if not base then
		return
	end
	local workshop = plot:FindFirstChild("Workshop")
	local tier = workshop and tierOf(workshop:GetAttribute("Level") or 1) or 0
	local old = plot:FindFirstChild("DojoMesh")
	if old then
		old:Destroy()
	end
	local position = Vector3.new(base.Position.X, TOP, base.Position.Z)
	local look = base.CFrame.LookVector
	local model = place(Layout.Tiers[tier], frameOf(position, look), plot, "DojoMesh")
	if not model then
		return -- keep the plain stand-in
	end
	hide(base)
	if workshop then
		for _, d in workshop:GetDescendants() do
			-- The Workshop's own parts only: the Dojo squad's rigs on the pedestals stay visible
			if d:IsA("BasePart") and d:FindFirstAncestorOfClass("Model") == workshop then
				d.Transparency = 1
				d.CastShadow = false
			end
		end
	else
		sign(
			WorkshopConfig.EMPTY_TEXT,
			position + look * 18.4 + Vector3.new(0, 8.6, 0),
			look,
			1,
			Color3.fromRGB(76, 48, 34),
			model
		)
	end
	local billboard = base:FindFirstChild("Sign")
	if billboard then
		billboard.Enabled = workshop ~= nil -- a free plot's text is on its board
		billboard.StudsOffsetWorldSpace = Vector3.new(0, SIGN_HEIGHT[tier] or 24, 0) -- clears that tier's roof
	end
end

local function watchPlot(plot)
	dressPlot(plot)
	local function changed(child)
		if child.Name == "Workshop" then
			task.defer(dressPlot, plot) -- an upgrade swaps the Workshop model: read the state after it settled
		end
	end
	plot.ChildAdded:Connect(changed)
	plot.ChildRemoved:Connect(changed)
end

function PlazaDressing.Start(spawnArea)
	task.spawn(function()
		local ok, err = pcall(function()
			local pending = 0
			for key, row in Layout.Assets do
				pending += 1
				task.spawn(function()
					local loaded, problem = pcall(loadAsset, key, row)
					if not loaded then
						warn("[PlazaDressing] " .. key .. ": " .. tostring(problem))
					end
					pending -= 1
				end)
			end
			while pending > 0 do
				task.wait()
			end

			local folder = Instance.new("Folder")
			folder.Name = "PlazaDressing"
			for _, row in Layout.Placed do
				place(row.Key, frameOf(row.Pos, row.Face), folder)
			end
			for _, row in Layout.Signs do
				sign(row.Text, row.Pos, row.Face, row.Size, Color3.fromHex(row.Color), folder)
			end
			folder.Parent = Workspace

			for name, key in REPLACES do
				local standIn = spawnArea:FindFirstChild(name)
				if standIn and templates[key] then
					hide(standIn)
				end
			end
			for _, plot in CollectionService:GetTagged(WorkshopConfig.TAG) do
				watchPlot(plot)
			end
		end)
		if not ok then
			warn("[PlazaDressing] failed, keeping what is built: " .. tostring(err))
		end
		ReplicatedStorage:SetAttribute("PlazaReady", true)
	end)
end

return PlazaDressing
