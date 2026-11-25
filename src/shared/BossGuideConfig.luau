--!nonstrict
-- The boss gate guide (WORLD_REDESIGN_SPEC 4.2, docs/BOSS_GUIDE_SPEC.md): where Gojio stands and what he says. Words and
-- positions are proposed. Numbers in the lines come from the configs that rule them, so a line never drifts from the game.
local BossEventConfig = require(script.Parent.BossEventConfig)
local CharacterCatalog = require(script.Parent.CharacterCatalog)
local SidekickConfig = require(script.Parent.SidekickConfig)

local BossGuideConfig = {}

BossGuideConfig.LIVE = false -- he is built only once the boss gate and its owner-chosen spot are in the game
BossGuideConfig.ID = "jk_strongest" -- owner 2026-11-25
-- The boss gate's world (x, z): the one value to change when the owner picks a spot (proposed: draft spot S4).
BossGuideConfig.GATE_POS = Vector2.new(2.5, 94.8)
-- Beside the gate as it faces the spawn: studs to its right (the side away from the Team altar) and toward the spawn. The draft
-- gate is 35.3 wide, so he stands outside its frame and outside its prompt (proposed).
BossGuideConfig.OFFSET = Vector2.new(21, 6)
BossGuideConfig.PROMPT_DISTANCE = 8 -- proposed; the stalls' is 10
BossGuideConfig.HOLD = 0 -- as every plaza prompt
BossGuideConfig.PROMPT = "TalkBossGuide"

function BossGuideConfig.Name()
	return CharacterCatalog.Get(BossGuideConfig.ID).Name
end

-- The conversation, in order: { Id, Text }. gateOpen: a boss event is active. rebirth: the player's RebirthLevel; below
-- SidekickConfig.HudFromRebirth the Bosses button is hidden and the gate stays closed (WORLD_REDESIGN_SPEC 4.2, proposed).
function BossGuideConfig.Pages(gateOpen, rebirth)
	local gate
	if rebirth < SidekickConfig.HudFromRebirth then
		gate = ("The Bosses button shows from Rebirth %d, and Sidekicks unlock at Rebirth %d. Come back then."):format(
			SidekickConfig.HudFromRebirth,
			SidekickConfig.UnlockRebirth
		)
	elseif gateOpen then
		gate = "The gate is open: a boss event is running. Walk up to the gate, or press Bosses."
	else
		gate = "The gate is closed for now. The Bosses popup shows the time to the next event."
	end
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
