--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BiomeDressing = require(Shared.BiomeDressing)
local TrackBuilder = require(Shared.TrackBuilder)
local TrackRegistry = require(Shared.TrackRegistry)
local SpawnArea = require(Shared.SpawnArea)
local VfxArea = require(Shared.VfxArea)
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
local LevelService = require(script.Parent.LevelService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local DuelService = require(script.Parent.DuelService)
local CheckpointService = require(script.Parent.CheckpointService)
local QuestService = require(script.Parent.QuestService)
local ShopService = require(script.Parent.ShopService)

-- Tracks are chained in Number order: each one starts where the previous one's finish checkpoint is.
local chain = TrackRegistry.Chain()
assert(#chain > 0, "no numbered tracks found")

local folder = Instance.new("Folder")
folder.Name = "Track"
folder.Parent = Workspace

local entries = {}
local origin = TrackBuilder.CHAIN_ORIGIN
for _, spec in chain do
	local model, layout = TrackBuilder.Build(spec, origin)
	model.Name = spec.Name
	model.Parent = folder
	table.insert(entries, { Layout = layout, Origin = origin, Model = model, Number = spec.Number })
	origin = TrackBuilder.EndCFrame(layout, origin)
end

-- The plaza hub beside Track 1's start: players join, respawn and stop here, and walk through its torii to race
local track1Start = entries[1].Model:FindFirstChild("Start", true).CFrame
local spawnArea = SpawnArea.Build(track1Start)
spawnArea.Parent = Workspace
local trackModels = {}
for _, entry in entries do
	table.insert(trackModels, entry.Model)
end
VfxArea.Build().Parent = Workspace -- the admin-only VFX showcase floor (/tp vfxarea)

-- The lighting baseline goes in before WeatherService snapshots it (docs/RENDERING_SPEC.md)
require(Shared.LightingConfig).Apply()
-- The player's car auto-races the whole chain at the speed from their saved stats
RaceService.Start(RaceService.BuildRoute(entries))
WeatherService.Start()
PlayerData.Start()
UpgradeService.SetTrackCount(#chain) -- the tree's tier gate (docs/UPGRADE_TREE_DESIGN.md)
UpgradeService.Start() -- the money upgrade tree: Remotes.BuyUpgrade and the UPGRADES badge
GachaService.Start() -- free auto-rolls (after each save loads), the car index and stat points
MoneyService.Start()
CarService.Start()
WorkshopService.Start(track1Start) -- the 7 Dojo plots round the plaza, one per player, idle Speed in the zone
-- scenery keeps clear of every road, the plaza and the Dojos
BiomeDressing.Prune(trackModels, { spawnArea, Workspace:WaitForChild("Workshops") })
require(Shared.TrackPreviews).Bake(trackModels) -- checkpoint card previews (docs/CHECKPOINT_SPEC.md section 4)

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
	lo -= Vector2.one * MARGIN
	hi += Vector2.one * MARGIN
	local authored = Workspace:FindFirstChild("Baseplate")
	local template = authored and authored:IsA("BasePart") and authored or Instance.new("Part")
	local plate = Instance.new("Model")
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
MarketService.Start() -- the spawn-area aura and trail market (physical prompt + client button)
RebirthService.Start()
BoostService.Start()
DailyLoginService.Start()
LevelService.Start()
LeaderboardService.Start() -- global boards on the spawn-area signs (docs/LEADERBOARD_SPEC.md)
DuelService.Start() -- player vs player duels, no stake (docs/DUEL_SPEC.md)
CheckpointService.Start() -- pick the starting track at the hub's Checkpoints NPC (docs/CHECKPOINT_SPEC.md)
QuestService.Start() -- UTC daily and weekly quest tracking (docs/QUESTS_SPEC.md)
ShopService.Start() -- Robux potion receipts and redeem codes (docs/SHOP_PURCHASES_SPEC.md)
AdminService.Start() -- chat admin commands (docs/ADMIN_COMMANDS_SPEC.md)
