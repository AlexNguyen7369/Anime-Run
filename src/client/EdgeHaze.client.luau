--!nonstrict
-- Band-edge fog, World 2 only (owner 2026-11-27 "1a", then "Dense fog band (Recommended)"; docs/BIOME_ENVIRONMENT_SPEC.md
-- 5.4, docs/WORLD2_SPEC.md "Band-edge haze"): a near-solid soft fog band just inside the current zone's land edge, in
-- its horizon colour, so the next track's skyline does not show from the run camera. Shared/EdgeHaze finds the panels from
-- the published BiomeZone_<n> polylines; only the current zone's (Shared/BiomeEnvironment.CurrentZone) are built. Thin
-- Parts, one per panel and layer (EdgeHaze.BANDS): Beams do not draw past about 500 studs. Client only: nothing
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

local Y = -1 -- the ground (TerrainShape.GROUND_TOP)
local OVERLAP = 0.5 -- studs added to a panel's length, so bends leave no slit
local THICK = 0.2

local function build(zone)
	local parts = {}
	-- the Atmosphere's Decay: Kit sets it to the drawn sky about 2 degrees up, so the band meets the horizon in its colour
	-- (Atmosphere.Color stood out as an orange wall against Track 7's dark sky in Studio)
	local color = Env.Profile(zone).Atmosphere.Decay
	for i, panel in EdgeHaze.Panels(EdgeHaze.EdgesFor(polys, zone, plaza)) do
		local mid = (panel.A + panel.B) / 2
		local d = panel.B - panel.A
		local along = Vector3.new(d.X, 0, d.Y).Unit
		for _, band in EdgeHaze.BANDS do
			local p = Instance.new("Part")
			p.Name = "Fog" .. i
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			p.Color = color
			p.Transparency = band[3]
			p.Size = Vector3.new(d.Magnitude + OVERLAP, band[2] - band[1], THICK)
			p.CFrame = CFrame.fromMatrix(Vector3.new(mid.X, Y + (band[1] + band[2]) / 2, mid.Y), along, Vector3.yAxis)
			p.Parent = holder
			table.insert(parts, p)
		end
		if i % 50 == 0 then
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
