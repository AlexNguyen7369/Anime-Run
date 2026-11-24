--!nonstrict
-- Flip Enabled to true (or set ReplicatedStorage attribute "ServerTestRun" = true during play) and press Play.
-- Results are printed as "[SERVERTEST] {json}" lines and a final "[SERVERTEST] END pass=N fail=N".
--
-- Scenarios listed here are the always-on checks. The car physics scenarios (static_settle, accel, brake, skidpad,
-- car_size, flip_recovery, car lap bots) are retired with the car body (docs/WORLD_REDESIGN_SPEC.md section 2).
-- Every file in ServerTest/TrackTests/ is added automatically as `track:<Name>` by the harness (those files are
-- written by test-writer, before the track exists).

return {
	Enabled = false,
	Scenarios = {
		"runner",
		"scrap",
		"chain",
		"money",
		"race",
		"economy",
		"data",
		"hud",
		"auto_toggle",
		"spawn_area",
		"gacha",
		"catalog",
		"index",
		"npc",
		"bank",
		"multiplayer",
		"admin",
		"roll_anim",
		"upgrades",
		"weather",
		"rebirth",
		"daily_login",
		"checkpoints",
		"team",
		"stamina",
		"team_bonus",
		"duel",
		"shop_purchases",
		"passes",
		"odds",
		"bag",
		"environment",
		"gifting",
		"gift_mailbox",
		"slot_items",
		"gems",
		"sidekicks",
		"sidekick_rotation",
		"world2_cast",
		"character_models",
		"sidekick_follow",
		"sidekick_pity",
		"sidekick_tutorial",
		"relics",
		"boss_arena",
		"boss_event",
		"boss_anim",
		"boss_paid",
		"boss_mage_event",
		"boss_mage_arena",
		"boss_mage_anim",
		"boss_king_event",
		"boss_king_arena",
		"boss_king_anim",
		"sidekick_attacks",
		"late_data",
		"runner_effects",
		"race_progress_map",
		"world_layout",
		"world_travel", -- design doc 4.47: one trip at a time, frozen until departure, restored on failure
		"world_travel_freeze", -- review of 8557dcf: Depart before the release save, freeze, lock retake, hung teleport
		"biome_runtime", -- World 2 runtime review: BiomeAssets timeout / retry / CastShadow, build yield, draft lamps
		"world_arrival", -- design doc 4.47: a non-admin who arrives in World 2 while the gate is locked goes back
		"world_gate_rule", -- design doc 4.47: one opening rule for the gate, Go and the arrival check (GATE_OPEN stays false)
		"track_loading",
		"team_fill", -- audit fixes 2026-11-20 (commit c80e4de): kept rolls fill empty Team slots
		"auto_restart", -- audit fixes 2026-11-20 (commit c80e4de): Auto restarts 3 s after an exhausted run
	},
	-- Not in the full suite (each takes minutes). Run on demand during play:
	--   ReplicatedStorage:SetAttribute("ServerTestOnly", "speed_probe"); ReplicatedStorage:SetAttribute("ServerTestRun", true)
	-- ServerTestOnly (comma-separated names) runs only those scenarios; clear it (nil) for the full suite again.
	OnDemand = {
		"speed_probe", -- docs/WORLDS_SPEC.md section 1: highest green cruise speed for RaceConfig.MAX_CRUISE
		-- docs/BIOME_ENVIRONMENT_SPEC.md section 10 (dev tool, no full-harness gate; each waits for TerrainReady):
		--   ServerTestOnly = "terrain_built,zone_switch,server_lighting_unchanged,assets_ip"
		"terrain_built",
		"zone_switch",
		"server_lighting_unchanged",
		"assets_ip",
		"tunnel_clear", -- spec 3.5: tunnel roof >= 12 over the road, clear of checkpoints
	},
}
