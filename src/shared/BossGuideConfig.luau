--!nonstrict
-- The boss gate guide (WORLD_REDESIGN_SPEC 4.2, docs/BOSS_GUIDE_SPEC.md): what Gojio says (words proposed). Where he
-- stands and his prompt's reach are Shared/BossGateConfig's. Numbers in the lines come from the configs that rule them, so a
-- line never drifts from the game.
local BossEventConfig = require(script.Parent.BossEventConfig)
local BossGateConfig = require(script.Parent.BossGateConfig)
local CharacterCatalog = require(script.Parent.CharacterCatalog)
local SidekickConfig = require(script.Parent.SidekickConfig)
local WorldConfig = require(script.Parent.WorldConfig)

local BossGuideConfig = {}

-- His own switch, per world, the gate's table (BOSS_GUIDE_SPEC): on in World 2 (owner 2026-11-26, "Approve 1-4", item 4),
-- off in World 1. He is in the game only with the gate's on too (IsLive).
BossGuideConfig.LIVE_IN = { [1] = false, [2] = true }
BossGuideConfig.LIVE = BossGuideConfig.LIVE_IN[WorldConfig.Id] == true
BossGuideConfig.ID = "jk_strongest" -- owner 2026-11-25
BossGuideConfig.HOLD = 0 -- as every plaza prompt

function BossGuideConfig.IsLive()
	return BossGuideConfig.LIVE and BossGateConfig.LIVE
end

function BossGuideConfig.Name()
	return CharacterCatalog.Get(BossGuideConfig.ID).Name
end

-- He talks from the rebirth that shows the Bosses button (owner 2026-11-25: not below rebirth 1).
function BossGuideConfig.Talks(rebirth)
	return (rebirth or 0) >= SidekickConfig.HudFromRebirth
end

-- The conversation, in order: { Id, Text }. gateOpen: a boss event is active.
function BossGuideConfig.Pages(gateOpen)
	local gate = gateOpen and "The gate is open: a boss event is running. Walk up to the gate, or press Bosses."
		or "The gate is closed for now. The Bosses popup shows the time to the next event."
	return {
		{
			Id = "Intro",
			Text = "I'm " .. BossGuideConfig.Name() .. ". Curious about the boss gate? I'll keep it short.",
		},
		{
			Id = "What",
			Text = "A boss is one huge enemy for the whole server. Your runners circle it while their Sidekicks attack.",
		},
		{
			Id = "When",
			Text = ("A boss event starts every %d minutes, with one boss picked at random. The gate is open while one runs."):format(
				BossEventConfig.IntervalSeconds / 60
			),
		},
		{
			Id = "Join",
			Text = "To join, press Go on the live boss in the Bosses popup before teleporting closes. You need a character wearing a Sidekick.",
		},
		{
			Id = "Rewards",
			Text = ("Only a defeat pays, if you dealt at least %d%% of that phase's HP. A chest holds one Relic and a tiny chance of the boss's Sidekick. Odds are in Details."):format(
				BossEventConfig.MinDamageShare * 100
			),
		},
		{ Id = "Gate", Text = gate },
	}
end

return BossGuideConfig
