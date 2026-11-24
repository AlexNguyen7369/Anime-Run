--!nonstrict
-- Which world this place is (design doc 4.47, docs/WORLD2_SPEC.md). World 1 and World 2 are separate places in one
-- universe, built from the same source tree: world2.project.json adds ReplicatedStorage.WorldId (IntValue 2); the
-- World 1 place has none and is world 1.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = {}

WorldConfig.COUNT = 2

-- Place id of each world in universe 10773557968. World 2's place was created by the owner 2026-11-23 ("World 2").
WorldConfig.PLACES = {
	[1] = 102957063656302,
	[2] = 79352569024576,
}

-- Per-world keys (design doc 4.47): track progress and the team. World 1 keeps them at the top of the save, World 2
-- under Worlds.W2 (a fresh World 2 team falls back to the starter, GachaService.Apply).
WorldConfig.PROGRESS_KEYS = { "BestTrack", "Checkpoint", "RaceBestTimes", "Team", "Equipped" }

-- The World 2 gate in the World 1 plaza (design doc 4.47): locked for everyone until the owner opens it; admins travel
-- with /world2 (Server/AdminService).
WorldConfig.GATE_OPEN = false
-- The opening rule once the gate is open (design doc 4.47, owner 2026-11-24): World 1 Track GATE_TRACK beaten and
-- rebirth >= GATE_REBIRTH; no Money cost, nothing resets (Server/WorldTravel.CanEnter).
WorldConfig.GATE_TRACK = 10
WorldConfig.GATE_REBIRTH = 5

local value = ReplicatedStorage:FindFirstChild("WorldId")
WorldConfig.Id = value and value:IsA("IntValue") and math.clamp(value.Value, 1, WorldConfig.COUNT) or 1

-- The save sub-table holding world `id`'s progress, or nil for World 1 (top level).
function WorldConfig.SaveKey(id)
	return id ~= 1 and ("W" .. tostring(id)) or nil
end

return WorldConfig
