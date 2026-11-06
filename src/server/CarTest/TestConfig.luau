--!nonstrict
-- Flip Enabled to true (or set ReplicatedStorage attribute "CarTestRun" = true during play) and press Play.
-- Results are printed as "[CARTEST] {json}" lines and a final "[CARTEST] END pass=N fail=N".
--
-- Scenarios listed here are the always-on checks. The car physics scenarios (static_settle, accel, brake, skidpad,
-- car_size, flip_recovery, car lap bots) are retired with the car body (docs/WORLD_REDESIGN_SPEC.md section 2).
-- Every file in CarTest/TrackTests/ is added automatically as `track:<Name>` by the harness (those files are
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
		"balance",
		"data",
		"hud",
		"auto_toggle",
		"spawn_area",
		"gacha",
		"catalog",
		"rarest_board",
		"index",
		"npc",
		"bank",
		"multiplayer",
		"admin",
		"roll_anim",
		"upgrades",
		"workshop",
		"workshop_phase2",
		"workshop_boost",
		"weather",
		"rebirth",
		"daily_login",
		"checkpoints",
		"team",
		"stamina",
		"team_bonus",
		"duel",
		"shop_purchases",
		"environment",
		"gifting",
		"gift_mailbox",
		"slot_items",
		"vehicle_effects",
		"race_progress_map",
		"showcase",
		"world_layout",
		"dojo",
	},
	-- Not in the full suite (each takes minutes). Run on demand during play:
	--   ReplicatedStorage:SetAttribute("CarTestOnly", "speed_probe"); ReplicatedStorage:SetAttribute("CarTestRun", true)
	-- CarTestOnly (comma-separated names) runs only those scenarios; clear it (nil) for the full suite again.
	OnDemand = {
		"speed_probe", -- docs/WORLDS_SPEC.md section 1: highest green cruise speed for RaceConfig.MAX_CRUISE
		-- docs/BIOME_ENVIRONMENT_SPEC.md section 10 (dev tool, no full-harness gate; each waits for TerrainReady):
		--   CarTestOnly = "terrain_built,zone_switch,server_lighting_unchanged,assets_ip"
		"terrain_built",
		"zone_switch",
		"server_lighting_unchanged",
		"assets_ip",
		"tunnel_clear", -- spec 3.5: tunnel roof >= 12 over the road, clear of checkpoints
	},
}
