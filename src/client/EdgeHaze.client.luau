--!nonstrict
-- Band-edge haze, World 2 only (owner 2026-11-27 "1a"; docs/BIOME_ENVIRONMENT_SPEC.md 5.4, docs/WORLD2_SPEC.md "Band-edge
-- haze"): low soft curtains just inside the current zone's land edge, in its fog colour, so the next track's skyline
-- does not show from the run camera. Shared/EdgeHaze finds them from the published BiomeZone_<n> polylines; only the
-- current zone's (Shared/BiomeEnvironment.CurrentZone) draw. Client only: nothing replicates.
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

-- proposed, to confirm in Studio: a Beam with FaceCamera off lies in the plane of its run and its attachments' Axis;
-- the attachments' Axis runs along the edge so the curtain stands across the line of sight
local ALONG_AXIS = true

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

local holder = Instance.new("Part") -- the attachments' parent, never drawn
holder.Name = "EdgeHaze"
holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
holder.Transparency = 1
holder.Size = Vector3.one
holder.CFrame = CFrame.identity
holder.Parent = Workspace

local Y = -1 -- the ground (TerrainShape.GROUND_TOP)
local built = {} -- zone -> { Beam }

local function attachment(at, along)
	local a = Instance.new("Attachment")
	local x = ALONG_AXIS and along or Vector3.new(along.Z, 0, -along.X) -- else across it, square to the edge
	a.WorldCFrame = CFrame.fromMatrix(at, x, Vector3.yAxis)
	a.Parent = holder
	return a
end

local function build(zone)
	local beams = {}
	local color = Env.Profile(zone).Atmosphere.Color
	for i, sg in EdgeHaze.EdgesFor(polys, zone, plaza) do
		local mid = (sg.A + sg.B) / 2
		local d = sg.B - sg.A
		local along = Vector3.new(d.X, 0, d.Y).Unit
		local beam = Instance.new("Beam")
		beam.Name = "Curtain" .. i
		beam.Attachment0 = attachment(Vector3.new(mid.X, Y, mid.Y), along)
		beam.Attachment1 = attachment(Vector3.new(mid.X, Y + EdgeHaze.HEIGHT, mid.Y), along)
		beam.Width0, beam.Width1 = d.Magnitude + 2, d.Magnitude + 2 -- a little overlap with the next
		beam.FaceCamera = false
		beam.Segments = 1
		beam.Texture = ""
		beam.Color = ColorSequence.new(color)
		beam.Transparency = NumberSequence.new(EdgeHaze.BOTTOM, 1)
		beam.LightInfluence = 1
		beam.LightEmission = 0
		beam.Enabled = false
		beam.Parent = holder
		table.insert(beams, beam)
		if i % 50 == 0 then
			task.wait()
		end
	end
	return beams
end

local shown = nil
local function show(zone)
	if zone == shown then
		return
	end
	if shown and built[shown] then
		for _, b in built[shown] do
			b.Enabled = false
		end
	end
	shown = zone
	if type(zone) ~= "number" or zone <= 0 or not polys[zone] then
		return
	end
	built[zone] = built[zone] or build(zone)
	if shown == zone then
		local color = ColorSequence.new(Env.Profile(zone).Atmosphere.Color)
		for _, b in built[zone] do
			b.Color = color
			b.Enabled = true
		end
	end
end

while true do
	show(Env.CurrentZone)
	task.wait(0.5)
end
