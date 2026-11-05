--!nonstrict
-- The NPC racer of every track: one per track number, racing each player on their own (see Shared/NpcRacer and
-- Server/RaceService). Change speeds, colours, labels and models here.
--
-- Tracks[n] overrides the defaults for track n:
--   Color  Color3 of the starter car body
--   Speed  the enemy's Speed, the game's whole number (docs/SPEED_BALANCE_SPEC.md); For() adds Cruise, its studs/s
--   Label  the enemy's name, shown in the indicator above its head (design doc 4.26)
--   Model  name of a Model under ReplicatedStorage.NpcModels, or a model id in Shared/CharacterModelAssets (catalog or foe_)

local RaceConfig = require(script.Parent.RaceConfig)

local NpcConfig = {}

NpcConfig.LOSE_SCREEN_SECONDS = 3 -- loser screen time before the player is sent back to the spawn
NpcConfig.LABEL_FORMAT = "track%02d_NPC"

-- Default colours by track number, used when Tracks[n].Color is not set (wraps around after the last).
NpcConfig.PALETTE = {
	Color3.fromRGB(230, 45, 45), -- red
	Color3.fromRGB(255, 150, 30), -- orange
	Color3.fromRGB(60, 190, 80), -- green
	Color3.fromRGB(150, 70, 220), -- purple
	Color3.fromRGB(250, 215, 40), -- yellow
	Color3.fromRGB(240, 90, 180), -- pink
	Color3.fromRGB(40, 40, 50), -- black
	Color3.fromRGB(245, 245, 245), -- white
}

-- One enemy per track (docs/NPC_RIVAL_SPEC.md). Model: an id in Shared/CharacterModelAssets; rollable characters share them (design doc 4.32).
NpcConfig.Tracks = {
	[1] = { Speed = 1e3, Label = "Paine", Color = Color3.fromRGB(230, 45, 45), Model = "foe_leaf" },
	[2] = { Speed = 1e5, Label = "Selle", Model = "foe_db" },
	[3] = { Speed = 1e7, Label = "Arlon", Model = "foe_sea" },
	[4] = { Speed = 3e9, Label = "Akazo", Model = "foe_ds" },
	[5] = { Speed = 3e12, Label = "Jogoh", Model = "foe_jk" },
	[6] = { Speed = 3e15, Label = "Shigaraky", Model = "foe_mha" },
	[7] = { Speed = 3e18, Label = "Mahitoh", Model = "foe_jk2" },
	[8] = { Speed = 1e22, Label = "Enelu", Model = "foe_sea2" },
	[9] = { Speed = 1e27, Label = "Ulquiorro", Model = "foe_soul" },
	[10] = { Speed = 5e29, Label = "Freezo", Model = "db_tyrant" },
}

-- Everything about track `number`'s NPC: { Number, Speed, Cruise, Color, Label, Model }. A track past the table has the last enemy's Speed.
function NpcConfig.For(number)
	number = math.max(1, math.floor(tonumber(number) or 1))
	local o = NpcConfig.Tracks[number] or {}
	local palette = NpcConfig.PALETTE
	local speed = o.Speed or NpcConfig.Tracks[#NpcConfig.Tracks].Speed
	return {
		Number = number,
		Speed = speed,
		Cruise = RaceConfig.CruiseOf(speed),
		Color = o.Color or palette[(number - 1) % #palette + 1],
		Label = o.Label or string.format(NpcConfig.LABEL_FORMAT, number),
		Model = o.Model,
	}
end

-- Enemy Speed x 1.01, rounded up (proposed 2026-11-05, design doc 4.15). A flat +1 does nothing at 1e27, and a tie loses.
function NpcConfig.RecommendedSpeed(number)
	return math.ceil(NpcConfig.For(number).Speed * 1.01)
end

return NpcConfig
