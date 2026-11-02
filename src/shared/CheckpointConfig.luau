--!nonstrict
-- The plaza sensei (was the checkpoint NPC). It is informational only (owner 2026-11-01, design doc 4.15): its
-- prompt opens the track overview (Client/CheckpointUi); every run starts on Track 1.

local CheckpointConfig = {}

CheckpointConfig.NPC_POS = Vector2.new(76, -62) -- hub-local (x, z): the sensei, beside the path to the start gate
CheckpointConfig.NPC_FACE = Vector2.new(118, -80) -- hub-local point the NPC faces (the plaza centre)
CheckpointConfig.PROMPT_DISTANCE = 10
CheckpointConfig.TEXT_DISTANCE = 80

return CheckpointConfig
