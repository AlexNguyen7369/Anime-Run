--!nonstrict
-- The boss gate and its guide share one layout (WORLD_REDESIGN_SPEC 4.2, owner 2026-11-25): where the gate stands, and where
-- the gate's prompt and the guide's (Gojio, Server/BossGuide) stand so one never shows over the other. Positions are world
-- (x, z); a gate-local offset is (right, toward the spawn) in studs with the gate facing the spawn. Every number but the
-- approved spot is proposed.
local SidekickConfig = require(script.Parent.SidekickConfig)

local BossGateConfig = {}

BossGateConfig.SPOT = Vector2.new(2.5, 94.8) -- S4, owner 2026-11-25
-- Studs toward the spawn: at the exact spot the base is 0.2 from the floor's south edge; up to 2.5 is allowed
BossGateConfig.SHIFT = 1.5
BossGateConfig.POS = BossGateConfig.SPOT * (1 - BossGateConfig.SHIFT / BossGateConfig.SPOT.Magnitude)
BossGateConfig.SIZE = Vector3.new(35.3, 37, 29.6) -- draft A's box, full size (draft_boss_gate.py report)

BossGateConfig.PROMPT = "OpenBosses"
BossGateConfig.PROMPT_OFFSET = Vector2.new(0, 10)
BossGateConfig.PROMPT_DISTANCE = 10
-- The guide stands outside the gate's frame; its prompt and the gate's are further apart than both reaches together
BossGateConfig.GUIDE_PROMPT = "TalkBossGuide"
BossGateConfig.GUIDE_OFFSET = Vector2.new(21, 6)
BossGateConfig.GUIDE_PROMPT_DISTANCE = 8

-- The mesh slots: Shared/PlazaAssets keys of the later upload. Until both are there the Parts stand-in shows.
BossGateConfig.MESH = { Closed = "BossGateClosed", Open = "BossGateOpen" }

-- ReplicatedStorage attribute (Server/BossGate): true while a boss event is active
BossGateConfig.OPEN_ATTRIBUTE = "BossGateOpen"
-- CollectionService tags of the stand-in's parts, shown while the gate is closed / open for this player (Client/BossGateView)
BossGateConfig.CLOSED_TAG = "BossGateClosedPart"
BossGateConfig.OPEN_TAG = "BossGateOpenPart"

-- A gate-local offset in world (x, z).
function BossGateConfig.At(offset)
	local toSpawn = -BossGateConfig.POS.Unit
	local right = Vector2.new(-toSpawn.Y, toSpawn.X)
	return BossGateConfig.POS + right * offset.X + toSpawn * offset.Y
end

-- Open for a player: an event is active and their Bosses button is past the rebirth that hides it.
function BossGateConfig.IsOpen(active, rebirth)
	return active == true and (rebirth or 0) >= SidekickConfig.HudFromRebirth
end

return BossGateConfig
