--!nonstrict
-- Checkpoints (design doc 4.15, owner 2026-11-02): the plaza sensei picks the track a player's runs start on.
-- Track 1 is always open; track n opens once track n-1 is beaten (BestTrack >= n - 1). Tracks won past the
-- checkpoint in the same run pay a bonus. The server decides; the client only shows it.

local CheckpointConfig = {}

CheckpointConfig.PICK_COOLDOWN = 0.5 -- seconds between accepted SetCheckpoint calls per player
CheckpointConfig.NPC_POS = Vector2.new(46, -35) -- hub-local (x, z): the sensei ends the service row (WORLD_REDESIGN_SPEC 7)
CheckpointConfig.NPC_FACE = Vector2.new(118, -35) -- hub-local point the NPC faces (+x, as the rest of the row)
CheckpointConfig.PROMPT_DISTANCE = 10
CheckpointConfig.TEXT_DISTANCE = 80
CheckpointConfig.BONUS_PER_TRACK = 0.1 -- placeholder: +10% pad cash per track past the checkpoint in one run
CheckpointConfig.BONUS_CAP = 2 -- placeholder: the bonus never pays more than x2

local function count(n)
	return type(n) == "number" and n == n and math.floor(n) or 0
end

-- The highest track that can be picked: the first unbeaten one (BestTrack + 1), at most the last track.
function CheckpointConfig.Max(bestTrack, trackCount)
	return math.max(1, math.min(count(bestTrack) + 1, count(trackCount)))
end

function CheckpointConfig.IsOpen(number, bestTrack, trackCount)
	return type(number) == "number"
		and number == math.floor(number)
		and number >= 1
		and number <= CheckpointConfig.Max(bestTrack, trackCount)
end

-- The track a run really starts on: the saved pick, clamped to what is open now.
function CheckpointConfig.Effective(checkpoint, bestTrack, trackCount)
	return math.clamp(math.max(1, count(checkpoint)), 1, CheckpointConfig.Max(bestTrack, trackCount))
end

-- Pad cash multi for a track won `past` tracks after the checkpoint track in the same run (0 = the checkpoint itself).
function CheckpointConfig.Bonus(past)
	return math.min(CheckpointConfig.BONUS_CAP, 1 + CheckpointConfig.BONUS_PER_TRACK * math.max(0, count(past)))
end

return CheckpointConfig
