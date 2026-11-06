--!nonstrict
-- Mechanical Workshop numbers (docs/WORKSHOP_SPEC.md, drafted 2026-10-06). Data only: the rules that read it live in
-- Shared/Workshop. Plot rects are local (x, z) of Track 1's flattened Start, like Shared/SpawnArea.

local PayoutCurve = require(script.Parent.PayoutCurve)

local WorkshopConfig = {}

WorkshopConfig.PLOT_COUNT = 7 -- one plot per player; the server's Max Players must be 7 (Game Settings, by hand)
WorkshopConfig.PLOT_SIZE = 48 -- studs, square

-- Assignment order: a joining player gets the lowest free index. `Front` = the local direction the open side faces
-- (toward the hub), as a unit (x, z).
-- The Dojos (docs/WORLD_REDESIGN_SPEC.md sections 3 and 5): an arc round the plaza centre (Shared/SpawnArea.CENTRE,
-- local (118, -80)) from -115 to 115 degrees, one every 38.3 degrees at radius 110 (100 at the two ends, clear of the
-- Track 1 / Track 2 biome gates), leaving the 130-degree side toward the start gate and Track 1 open. Each front is
-- the axis closest to the plaza centre (all within 39 degrees of it).
WorkshopConfig.Plots = {
	{ Min = Vector2.new(52, -195), Max = Vector2.new(100, -147), Front = Vector2.new(0, 1) },
	{ Min = Vector2.new(119, -211), Max = Vector2.new(167, -163), Front = Vector2.new(0, 1) },
	{ Min = Vector2.new(180, -172), Max = Vector2.new(228, -124), Front = Vector2.new(-1, 0) },
	{ Min = Vector2.new(204, -104), Max = Vector2.new(252, -56), Front = Vector2.new(-1, 0) },
	{ Min = Vector2.new(180, -36), Max = Vector2.new(228, 12), Front = Vector2.new(-1, 0) },
	{ Min = Vector2.new(119, 3), Max = Vector2.new(167, 51), Front = Vector2.new(0, -1) },
	{ Min = Vector2.new(52, -13), Max = Vector2.new(100, 35), Front = Vector2.new(0, -1) },
}

-- The training zone, centred in the plot: (x, height, z) studs. Shown on the plot only: it earns nothing since
-- 2026-11-03 (design doc 4.19, no passive gain).
WorkshopConfig.ZONE_SIZE = Vector3.new(32, 12, 32)

-- Workshop stat boost (design doc 4.19, WORLD_REDESIGN_SPEC section 5; numbers placeholders, owner 2026-11-03):
-- boost = sum of the Dojo squad's RARITY_POINTS x POINT_BONUS x (1 + LEVEL_SCALE x (level - 1)), added to STATS' pick.
WorkshopConfig.STATS = { "Money", "Luck", "Speed", "Stamina" } -- the first one is the default
WorkshopConfig.RARITY_POINTS =
	{ Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7, Eternal = 8 }
WorkshopConfig.POINT_BONUS = 0.05
WorkshopConfig.LEVEL_SCALE = 0.1

-- Configurable progression defaults: prices follow PayoutCurve.Cost from $500 (owner 2026-10-27).
WorkshopConfig.Levels = {
	{ Price = 0 }, -- the starter workshop
}
for level = 2, 10 do
	WorkshopConfig.Levels[level] = { Price = PayoutCurve.Cost(500, level - 1) }
end
WorkshopConfig.MAX_LEVEL = #WorkshopConfig.Levels
WorkshopConfig.UPGRADE_DISTANCE = 12
WorkshopConfig.REMOTE_COOLDOWN = 0.5 -- seconds between accepted WorkshopUpgrade / SetWorkshopStat requests

-- Showcase pedestals (docs/WORKSHOP_SPEC.md "Showcase"): plot-local z of their centres and the display car scale.
WorkshopConfig.SHOWCASE_Z = 11
WorkshopConfig.SHOWCASE_CAR_SCALE = 1
WorkshopConfig.SHOWCASE_LABEL_DISTANCE = 60 -- MaxDistance of the name / rarity label over each showcased car

WorkshopConfig.SIGN_DISTANCE = 120 -- MaxDistance of the plot signs
WorkshopConfig.EMPTY_TEXT = "FREE DOJO"
WorkshopConfig.TAG = "WorkshopPlot"

return WorkshopConfig
