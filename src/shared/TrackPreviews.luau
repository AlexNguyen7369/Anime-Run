--!nonstrict
-- Tracks panel card previews (design doc 4.15): the server copies the real scenery around each
-- track's start gate into ReplicatedStorage.TrackPreviews, so every client can show it in a ViewportFrame even
-- while streaming has the track itself unloaded. Presentation only: nothing here collides, touches or moves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackPreviews = {}

TrackPreviews.RADIUS = 90 -- studs around the gate that make the shot (placeholder)
TrackPreviews.MAX_PARTS = 350 -- per track, nearest first: bounds what every client downloads (placeholder)

local KEEP = { "SpecialMesh", "Decal", "Texture", "SurfaceAppearance", "UICorner" }

local function strip(part)
	for _, child in part:GetChildren() do
		if not table.find(KEEP, child.ClassName) then
			child:Destroy()
		end
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- Copies the start-gate surroundings of every track model ({ Model, Name }) into ReplicatedStorage.TrackPreviews.
-- Each copy is a Model named after its track with attributes Focus (CFrame of the gate) and GroundY (the road's
-- underside: Terrain is not copied, so clients lay a ground plate there). A tunnel's roof is left out so the camera
-- sees down into it.
function TrackPreviews.Bake(trackModels)
	local folder = ReplicatedStorage:FindFirstChild("TrackPreviews") or Instance.new("Folder")
	folder.Name = "TrackPreviews"
	folder:ClearAllChildren()
	for _, model in trackModels do
		local gate = model:FindFirstChild("Gate", true) or model:FindFirstChild("Start", true)
		if gate then
			local focus = gate:IsA("Model") and gate:GetPivot() or gate.CFrame
			local start = model:FindFirstChild("Start", true)
			local tunnel = model:FindFirstChild("Tunnel")
			local near = {}
			for _, part in model:GetDescendants() do
				local roof = tunnel and part:IsDescendantOf(tunnel) and part.Position.Y > focus.Position.Y + 10
				if part:IsA("BasePart") and part.Transparency < 1 and not roof then
					local reach = (part.Position - focus.Position).Magnitude - part.Size.Magnitude / 2
					if reach <= TrackPreviews.RADIUS then
						table.insert(near, { Part = part, Reach = reach })
					end
				end
			end
			table.sort(near, function(a, b)
				return a.Reach < b.Reach
			end)
			local copy = Instance.new("Model")
			copy.Name = model.Name
			copy:SetAttribute("Focus", focus)
			if start and start:IsA("BasePart") then
				copy:SetAttribute("GroundY", start.Position.Y - start.Size.Y / 2 - 0.05)
			end
			for i = 1, math.min(#near, TrackPreviews.MAX_PARTS) do
				local ok, clone = pcall(function()
					return near[i].Part:Clone()
				end)
				if ok and clone then
					strip(clone)
					clone.Parent = copy
				end
			end
			copy.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
	return folder
end

return TrackPreviews
