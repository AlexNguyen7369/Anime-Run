--!nonstrict
-- The boss gate and its guide share one layout (WORLD_REDESIGN_SPEC 4.2, owner 2026-11-25): where the gate stands, and where
-- the gate's prompt and the guide's (Gojio, Server/BossGuide) stand so one never shows over the other. Positions are world
-- (x, z); a gate-local offset is (right, toward the spawn) in studs with the gate facing the spawn. Every number but the
-- approved spot is proposed.
local PlazaLayout = require(script.Parent.PlazaLayout)
local SidekickConfig = require(script.Parent.SidekickConfig)
local WorldConfig = require(script.Parent.WorldConfig)

local BossGateConfig = {}

-- The gate's switch, per world. While false nothing of the gate is built: no model, prompt or attribute. The moved Index, Team
-- altar and statue do not depend on it. The guide needs this one and his own (BossGuideConfig.IsLive). On in World 2 (owner
-- 2026-11-26: "Ensure boss gate added to world 2 location, gate A of approved gate blends"); World 1 keeps it off.
BossGateConfig.LIVE_IN = { [1] = false, [2] = true }
BossGateConfig.LIVE = BossGateConfig.LIVE_IN[WorldConfig.Id] == true

BossGateConfig.SPOT = Vector2.new(2.5, 94.8) -- S4, owner 2026-11-25, approved (spawn at (0, 0))
-- Studs toward the spawn: at the approved spot on the approved floor the base was 0.2 from the floor's south edge; up to 2.5 is
-- allowed
BossGateConfig.SHIFT = 1.5
-- From the spawn: the spot as Shared/PlazaLayout scales it (1.2x plaza, WORLD_REDESIGN_SPEC 4 "Plaza size"), SHIFT toward the spawn
local scaled = PlazaLayout.Offset(BossGateConfig.SPOT)
BossGateConfig.POS = scaled * (1 - BossGateConfig.SHIFT / scaled.Magnitude)
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

-- Open for a player: the gate is on, an event is active and their Bosses button is past the rebirth that hides it.
function BossGateConfig.IsOpen(active, rebirth)
	return BossGateConfig.LIVE and active == true and (rebirth or 0) >= SidekickConfig.HudFromRebirth
end

-- The gate's prompt does what the Bosses button does, where the button shows and no panel covers the popup; a closed gate's
-- does nothing (WORLD_REDESIGN_SPEC 4.2, proposed).
function BossGateConfig.PromptOpens(prompt, buttonVisible, panelOpen, active, rebirth)
	return prompt.Name == BossGateConfig.PROMPT
		and prompt:IsDescendantOf(workspace)
		and buttonVisible
		and not panelOpen
		and BossGateConfig.IsOpen(active, rebirth)
end

return BossGateConfig
