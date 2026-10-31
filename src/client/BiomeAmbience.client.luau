--!nonstrict
-- Local-only motion for biome props (docs/BIOME_DRESSING_SPEC.md "Ambient motion"):
-- models tagged BiomeSpin turn about their vertical axis, BiomeBob ones rock like a moored ship.
-- Only props near the camera move; the server's copies never change.
-- The rest pivot is the server's "BasePivot" attribute (BiomeDressing sets it after snapping), not the client's
-- GetPivot: with streaming the tag can arrive before the model's parts (a mesh hero's MeshPart streams in later).
-- Parts that stream in later arrive at the rest pose and are moved to the current pose.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AMBIENCE_DISTANCE = 300 -- studs from the camera
local SPIN_SPEED = 0.6 -- radians per second
local BOB_HEIGHT = 1.2 -- studs
local BOB_RATE = 1.4 -- radians per second

local bases = {} -- model -> { Pivot, Kind, Current (pose last applied, nil at rest), Conn }

local function track(kind)
	local function add(model)
		if not model:IsA("Model") or bases[model] then
			return
		end
		local base = { Kind = kind }
		base.Pivot = model:GetAttribute("BasePivot") or model:GetPivot()
		base.Conn = model.DescendantAdded:Connect(function(part)
			if not part:IsA("BasePart") then
				return
			end
			if base.Current then
				part.CFrame = base.Current * base.Pivot:ToObjectSpace(part.CFrame)
			elseif not model:GetAttribute("BasePivot") then
				base.Pivot = model:GetPivot() -- no server pivot: take it once parts are in
			end
		end)
		bases[model] = base
	end
	for _, model in CollectionService:GetTagged(kind) do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal(kind):Connect(add)
	CollectionService:GetInstanceRemovedSignal(kind):Connect(function(model)
		local base = bases[model]
		if base then
			base.Conn:Disconnect()
			bases[model] = nil
		end
	end)
end
track("BiomeSpin")
track("BiomeBob")

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local t = os.clock()
	for model, base in bases do
		if (base.Pivot.Position - eye).Magnitude < AMBIENCE_DISTANCE then
			local target
			if base.Kind == "BiomeSpin" then
				target = base.Pivot * CFrame.Angles(0, t * SPIN_SPEED, 0)
			else
				local phase = t * BOB_RATE + base.Pivot.Position.X * 0.01
				target = base.Pivot
					* CFrame.new(0, math.sin(phase) * BOB_HEIGHT, 0)
					* CFrame.Angles(0, 0, math.sin(phase * 0.7) * 0.05)
			end
			-- PivotTo moves parts by target * pivot^-1: pin the pivot to the pose the parts are really in
			model.WorldPivot = base.Current or base.Pivot
			model:PivotTo(target)
			base.Current = target
		end
	end
end)
