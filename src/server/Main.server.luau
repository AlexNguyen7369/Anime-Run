--!nonstrict
-- Test code never reaches a live server or phone: it is about a third of the client's script bytes and samples GUI every frame.
if not game:GetService("RunService"):IsStudio() then
	local tests = script.Parent:FindFirstChild("CarTest")
	local uiTests = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Client")
	uiTests = uiTests and uiTests:FindFirstChild("UiTest")
	if tests then
		tests:Destroy()
	end
	if uiTests then
		uiTests:Destroy()
	end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BiomeDressing = require(Shared.BiomeDressing)
local TrackBuilder = require(Shared.TrackBuilder)
local TrackRegistry = require(Shared.TrackRegistry)
local SpawnArea = require(Shared.SpawnArea)
local VfxArea = require(Shared.VfxArea)
local TerrainShape = require(Shared.TerrainShape)
local Tunnel = require(Shared.Tunnel)
local BiomeThemes = require(Shared.BiomeThemes)
local TerrainBuilder = require(script.Parent.TerrainBuilder)
local AdminService = require(script.Parent.AdminService)
local CarService = require(script.Parent.CarService)
local GachaService = require(script.Parent.GachaService)
local MoneyService = require(script.Parent.MoneyService)
local PlayerData = require(script.Parent.PlayerData)
local RaceService = require(script.Parent.RaceService)
local UpgradeService = require(script.Parent.UpgradeService)
local WorkshopService = require(script.Parent.WorkshopService)
local WeatherService = require(script.Parent.WeatherService)
local MarketService = require(script.Parent.MarketService)
local RebirthService = require(script.Parent.RebirthService)
local BoostService = require(script.Parent.BoostService)
local DailyLoginService = require(script.Parent.DailyLoginService)
local DuelService = require(script.Parent.DuelService)
local CheckpointService = require(script.Parent.CheckpointService)
local QuestService = require(script.Parent.QuestService)
local ShopService = require(script.Parent.ShopService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local TrackBuild = require(script.Parent.TrackBuild)

-- Props with a Mesh def load it from the asset ledger, or fall back to parts (docs/BIOME_ENVIRONMENT_SPEC.md 4.2)
BiomeDressing.Assets = require(script.Parent.BiomeAssets)

-- Tracks are chained in Number order: each one starts where the previous one's finish checkpoint is.
local chain = TrackRegistry.Chain()
assert(#chain > 0, "no numbered tracks found")

local folder = Instance.new("Folder")
folder.Name = "Track"
folder.Parent = Workspace

-- Build after join (design doc 4.25): every track's layout now (pure maths: the route, terrain shape and baseplate
-- span the whole chain), the models of Tracks 1-5 before the join and the rest behind the game (end of this script).
local JOIN_TRACKS = 5
local entries = {}
local origin = TrackBuilder.CHAIN_ORIGIN
for _, spec in chain do
	local layout = TrackBuilder.Layout(spec)
	table.insert(entries, { Layout = layout, Origin = origin, Number = spec.Number, Biome = spec.Biome, Spec = spec })
	TrackBuild.SetPending(spec.Number, true)
	origin = TrackBuilder.EndCFrame(layout, origin)
end

local function buildTrack(entry)
	local spec = entry.Spec
	local model, layout = TrackBuilder.Build(spec, entry.Origin)
	model.Name = spec.Name
	-- an enclosed tunnel over the road when the biome has one (docs/BIOME_ENVIRONMENT_SPEC.md 3.5), before Prune
	local tunnel, tunnelParts = Tunnel.Build(model, layout, BiomeThemes[spec.Biome], entry.Origin)
	if tunnel then
		print(string.format("[TUNNEL] %s: %d parts", spec.Name, tunnelParts))
	end
	model.Parent = folder
	entry.Layout, entry.Model = layout, model
end

for i = 1, math.min(JOIN_TRACKS, #entries) do
	buildTrack(entries[i])
	task.wait() -- ~98k studs of road: one track per frame keeps Studio under its unyielding-script limit
end

-- The plaza hub beside Track 1's start: players join, respawn and stop here, and walk through its torii to race
local track1Start = entries[1].Model:FindFirstChild("Start", true).CFrame
local spawnArea = SpawnArea.Build(track1Start)
spawnArea.Parent = Workspace
local trackModels = {} -- the built models; late tracks join it, so TerrainBuilder's final pass reaches them too
for _, entry in entries do
	if entry.Model then
		table.insert(trackModels, entry.Model)
	end
end

-- The lighting baseline goes in before WeatherService snapshots it (docs/RENDERING_SPEC.md)
require(Shared.LightingConfig).Apply()
-- The player's car auto-races the whole chain at the speed from their saved stats
RaceService.Start(RaceService.BuildRoute(entries))
WeatherService.Start()
require(script.Parent.CharacterModelService).Start() -- loads the uploaded runner models in the background
PlayerData.Start()
UpgradeService.SetTrackCount(#chain) -- the tree's tier gate (docs/UPGRADE_TREE_DESIGN.md)
UpgradeService.Start() -- the money upgrade tree: Remotes.BuyUpgrade and the UPGRADES badge
GachaService.Start() -- free auto-rolls (after each save loads), the car index and stat points
MoneyService.Start()
CarService.Start()
WorkshopService.Start(track1Start) -- the 7 Dojo plots round the plaza, one per player, workshop stat boost
require(script.Parent.PlazaDressing).Start(spawnArea) -- the plaza and Dojo meshes, in the background (design doc 4.24)
do -- cyber accents on top of the plaza (4.24 "Dojo with cyber accents"); a failure only warns
	local ok, err = pcall(function()
		require(script.Parent.PlazaAccents).Build()
	end)
	if not ok then
		warn("[PlazaAccents] skipped: " .. tostring(err))
	end
end
-- scenery keeps clear of every road, the plaza and the Dojos
BiomeDressing.Prune(trackModels, { spawnArea, Workspace:WaitForChild("Workshops") })
-- Terrain shape (docs/BIOME_ENVIRONMENT_SPEC.md 3.1): flat at the plaza, Dojos, checkpoints, WinPads and the VFX floor
do
	-- the VFX floor is built on the first `/tp vfxarea` (AdminService), so its ground is cleared as an XZ box
	local half = Vector2.new(VfxArea.FLOOR_SIZE.X, VfxArea.FLOOR_SIZE.Z) / 2
	local centre = Vector2.new(VfxArea.CENTER.X, VfxArea.CENTER.Z)
	local clear = { { Min = centre - half, Max = centre + half } }
	for _, entry in entries do
		if entry.Model then
			table.insert(clear, entry.Model:FindFirstChild("Checkpoint"))
			table.insert(clear, entry.Model:FindFirstChild("WinPad", true))
		else
			table.insert(clear, TrackBuilder.CheckpointBox(entry.Layout, entry.Origin)) -- not built yet
		end
	end
	TerrainShape.Prepare(entries, clear, { spawnArea, Workspace.Workshops })
	for _, entry in entries do
		ReplicatedStorage:SetAttribute("BiomeZone_" .. entry.Number, TerrainShape.ZonePolyline(entry.Number))
	end
	ReplicatedStorage:SetAttribute("PlazaRadius", TerrainShape.PlazaRadius())
end
BiomeDressing.SnapToTerrain(trackModels)
for _, model in trackModels do
	model:SetAttribute("BuiltAt", os.clock())
	TrackBuild.SetPending(model:GetAttribute("Number"), nil)
end

local plate
-- Safety baseplate (docs/WORLD_REDESIGN_SPEC.md section 3): tiles of the authored Workspace.Baseplate under the
-- tracks, the plaza and the Dojos plus a margin (a part can be at most 2048 studs wide).
do
	local MARGIN, TILE = 64, 2048
	local lo, hi = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	for _, root in { folder, spawnArea, Workspace.Workshops } do
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				local cf, size = d.CFrame, d.Size
				local half = (cf.RightVector * size.X):Abs() / 2
					+ (cf.UpVector * size.Y):Abs() / 2
					+ (cf.LookVector * size.Z):Abs() / 2
				lo = Vector2.new(math.min(lo.X, d.Position.X - half.X), math.min(lo.Y, d.Position.Z - half.Z))
				hi = Vector2.new(math.max(hi.X, d.Position.X + half.X), math.max(hi.Y, d.Position.Z + half.Z))
			end
		end
	end
	local box = TerrainShape.Box() -- the late tracks' centre lines and skirt: they have no parts yet
	if box then
		lo, hi = lo:Min(box.Min), hi:Max(box.Max)
	end
	lo -= Vector2.one * MARGIN
	hi += Vector2.one * MARGIN
	local authored = Workspace:FindFirstChild("Baseplate")
	local template = authored and authored:IsA("BasePart") and authored or Instance.new("Part")
	plate = Instance.new("Model")
	plate.Name = "Baseplate"
	local nx, nz = math.ceil((hi.X - lo.X) / TILE), math.ceil((hi.Y - lo.Y) / TILE)
	local sx, sz = (hi.X - lo.X) / nx, (hi.Y - lo.Y) / nz
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local tile = template:Clone()
			tile.Name = "Tile_" .. i .. "_" .. j
			tile.Anchored = true
			tile.Size = Vector3.new(sx, template.Size.Y, sz)
			tile.CFrame = CFrame.new(lo.X + sx * (i + 0.5), template.Position.Y, lo.Y + sz * (j + 0.5))
			tile.Parent = plate
		end
	end
	if authored then
		authored:Destroy()
	end
	plate.Parent = Workspace
end
-- The services start while the terrain writes; it then lowers and hides the baseplate (spec 2.4)
task.spawn(TerrainBuilder.Build, trackModels, plate)
MarketService.Start() -- the spawn-area aura and trail market (physical prompt + client button)
RebirthService.Start()
BoostService.Start()
DailyLoginService.Start()
DuelService.Start() -- player vs player duels, no stake (docs/DUEL_SPEC.md)
CheckpointService.Start() -- pick the starting track at the plaza sensei (design doc 4.15)
require(script.Parent.SidekickService).Start() -- summons, bag and equip remotes (design doc 4.36)
require(script.Parent.RelicService).Start() -- the Relic equip remote (design doc 4.38)
require(script.Parent.BossEventService).Init() -- the 30 minute boss event (design doc 4.37)
QuestService.Start() -- UTC daily and weekly quest tracking (docs/QUESTS_SPEC.md)
require(script.Parent.PassService).Start() -- gamepass ownership and the paid random items policy
ShopService.Start() -- Robux potion receipts and redeem codes (docs/MONETIZATION_SPEC.md)
AdminService.Start() -- chat admin commands (docs/ADMIN_COMMANDS_SPEC.md)
LeaderboardService.Start({ "RarestCar" }) -- feeds the Best Roll pedestal only; the boards stay removed (design doc 4.16)

-- Tracks 6-10 behind the game (design doc 4.25), one per frame, a track a player is on or headed to first. Each is
-- pruned against every built road both ways, then snapped against every built road, pinned hero and pad;
-- TerrainBuilder writes its far zones well after this.
local function playerTracks()
	local list = {}
	for _, player in game:GetService("Players"):GetPlayers() do
		local run = CarService.GetRun(player)
		local car = run and run.Car
		table.insert(list, car and (car:GetAttribute("RunHold") or car:GetAttribute("RunTrack")) or 1) -- on foot: plaza
	end
	return list
end
local remaining, byNumber = {}, {}
for i = JOIN_TRACKS + 1, #entries do
	table.insert(remaining, entries[i].Number)
	byNumber[entries[i].Number] = entries[i]
end
while #remaining > 0 do
	local number = TrackBuild.Order(remaining, playerTracks())[1]
	table.remove(remaining, table.find(remaining, number))
	local entry = byNumber[number]
	buildTrack(entry)
	local others = table.clone(trackModels)
	table.insert(trackModels, entry.Model)
	BiomeDressing.Prune(trackModels, { spawnArea, Workspace.Workshops }, { entry.Model })
	BiomeDressing.Prune({ entry.Model }, nil, others)
	BiomeDressing.SnapToTerrain(trackModels, { entry.Model })
	for _, list in { RaceService.GetRoute().Tracks, RaceService.GetRoute().Pads } do
		for _, track in list do
			if track.Number == number then
				track.Pad = entry.Model:FindFirstChild("WinPad", true) -- a late track still pays
			end
		end
	end
	entry.Model:SetAttribute("BuiltAt", os.clock())
	TrackBuild.SetPending(number, nil)
	task.wait()
end
