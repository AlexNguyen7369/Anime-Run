--!nonstrict
-- Band-edge fog, World 2 only (owner 2026-11-27 "1a", then "Dense fog band (Recommended)"; docs/BIOME_ENVIRONMENT_SPEC.md
-- 5.4, docs/WORLD2_SPEC.md "Band-edge haze"): a near-solid soft fog band just inside the current zone's land edge, in
-- its horizon colour, so the next track's skyline does not show from the run camera. Shared/EdgeHaze finds the panels from
-- the published BiomeZone_<n> polylines; only the current zone's (Shared/BiomeEnvironment.CurrentZone) are built. Thin
-- Parts, nested full-height layers per panel (EdgeHaze.Layers): Beams do not draw past about 500 studs. Client only: nothing
-- replicates.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

if not game:IsLoaded() then
	game.Loaded:Wait() -- WorldConfig reads ReplicatedStorage.WorldId (docs/BUGS.md w2-worldid-race)
end
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared:WaitForChild("WorldConfig"))
local EdgeHaze = require(Shared:WaitForChild("EdgeHaze"))
if not EdgeHaze.Enabled(WorldConfig.Id) then
	return
end
local Env = require(Shared:WaitForChild("BiomeEnvironment"))
local TrackRegistry = require(Shared:WaitForChild("TrackRegistry"))

local numbers = {}
for _, spec in TrackRegistry.Chain() do
	table.insert(numbers, spec.Number)
end

-- every track's published centre line (Main sets them before the join)
local polys = {}
for _, n in numbers do
	local text = ReplicatedStorage:GetAttribute("BiomeZone_" .. n)
	while type(text) ~= "string" do
		ReplicatedStorage:GetAttributeChangedSignal("BiomeZone_" .. n):Wait()
		text = ReplicatedStorage:GetAttribute("BiomeZone_" .. n)
	end
	local list = {}
	for x, z in string.gmatch(text, "([^,;]+),([^;]+)") do
		table.insert(list, Vector2.new(tonumber(x), tonumber(z)))
	end
	polys[n] = list
end
local plaza = ReplicatedStorage:GetAttribute("PlazaRadius") or 0

local holder = Instance.new("Folder")
holder.Name = "EdgeHaze"
holder.Parent = Workspace

local GROUND = -1 -- the ground (TerrainShape.GROUND_TOP)
local THICK = 0.2
local OVERLAP = 0.5 -- studs added to a panel's length, so bends leave no slit
local LAYERS = EdgeHaze.Layers()

local function build(zone)
	local parts = {}
	-- the Atmosphere's Decay: where the track's own sky shows, Kit sets it to the drawn sky about 2 degrees up, so the
	-- band meets the horizon in its colour (elsewhere it is Kit's lifted mid colour)
	-- (Atmosphere.Color stood out as an orange wall against Track 7's dark sky in Studio)
	local color = Env.Profile(zone).Atmosphere.Decay
	for i, panel in EdgeHaze.Panels(EdgeHaze.EdgesFor(polys, zone, plaza)) do
		local mid = (panel.A + panel.B) / 2
		local d = panel.B - panel.A
		local along = Vector3.new(d.X, 0, d.Y).Unit
		local normal = Vector3.new(along.Z, 0, -along.X)
		for k, layer in LAYERS do
			local h = layer[1] - EdgeHaze.BASE
			local p = Instance.new("Part")
			p.Name = "Fog" .. i
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Color = color
			p.Transparency = layer[2]
			p.Size = Vector3.new(d.Magnitude + OVERLAP, h, THICK)
			local at = Vector3.new(mid.X, GROUND + EdgeHaze.BASE + h / 2, mid.Y)
				+ normal * ((k - 1) * EdgeHaze.LAYER_GAP)
			p.CFrame = CFrame.fromMatrix(at, along, Vector3.yAxis)
			p.Parent = holder
			table.insert(parts, p)
		end
		if i % 20 == 0 then
			task.wait()
		end
	end
	return parts
end

local shown, parts = nil, {}
local function show(zone)
	if zone == shown then
		return
	end
	shown = zone
	for _, p in parts do
		p:Destroy()
	end
	parts = {}
	if type(zone) ~= "number" or zone <= 0 or not polys[zone] then
		return
	end
	local made = build(zone)
	if shown == zone then
		parts = made
	else
		for _, p in made do
			p:Destroy()
		end
	end
end

while true do
	show(Env.CurrentZone)
	task.wait(0.5)
end
