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
	-- Scenarios whose every expectation is World 1's: in another world the harness reports them as SKIP with this
	-- reason, counted apart from pass and fail. A SKIP is missing World 2 coverage, never a pass: the open list is
	-- docs/OWNER_QUESTIONS.md "World 2 test coverage gaps".
	World1Only = {
		environment = "names World 1's ten biomes; World 2's are checked offline only (tools/lune/biome_harness.luau, WORLD=2), no Studio scenario yet",
	},
	-- Every TrackTests file is the brief of one World 1 track (owner limits per track).
	World1TrackTests = "briefs of World 1's ten tracks; World 2's tracks have no briefs yet (the runner scenario runs all ten, world_layout places them)",
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
		"plaza_build", -- WORLD_REDESIGN_SPEC 4.2: the guards; what waits is plaza_build_pending (OnDemand)
		"gacha",
		"catalog",
		"index",
		"npc",
		"bank",
		"multiplayer",
		"admin",
		"roll_anim", -- both worlds: the reel and the 4.40 bar are held to the place's own cast (World 2: World2CastTests)
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
		"world2_welcome", -- WORLD2_SPEC "Welcome": Worlds.W2.Welcomed, once, old saves and World 1 keep it
		"boss_guide", -- docs/BOSS_GUIDE_SPEC.md: Gojio at the boss gate, text only
		"world2_team",
		"awakening", -- design doc 4.47: World 2 stars from Copies, World 1 unchanged
		"world2_rewards", -- WORLD2_SPEC "Rewards": World 2 pad Cash, first-clear Gems per world
		"world2_summon", -- design doc 4.47 "Pity counts stay shared", SIDEKICK_SPEC "World 2 set": Summon gives this place's set
		"boss_models_placed", -- the four boss models startBoss loads are in this place's ServerStorage.BakedModels
		"harness_save", -- design doc 4.24 "Harness saves": a harness run never writes the live save
		"powerups", -- PowerUpTests: registered in Scenarios but missing here until 2026-11-24
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
		"biome_mesh_color", -- docs/BUGS.md w2-dark-props: World 2 textureless meshes are white, World 1 as loaded
		"biome_runtime", -- World 2 runtime review: BiomeAssets timeout / retry / CastShadow, build yield, draft lamps
		"world_arrival", -- design doc 4.47: a non-admin who arrives in World 2 while the gate is locked goes back
		"world_travel_review", -- review of 3258513: arrival save carry, hung trip, InitFailed, Depart, rank "unknown"
		"world_gate_rule", -- design doc 4.47: one opening rule for the gate, Go and the arrival check (GATE_OPEN stays false)
		"track_loading",
		"team_fill", -- audit fixes 2026-11-20 (commit c80e4de): kept rolls fill empty Team slots
		"auto_restart", -- audit fixes 2026-11-20 (commit c80e4de): Auto restarts 3 s after an exhausted run
	},
	-- Not in the full suite (each takes minutes). Run on demand during play:
	--   ReplicatedStorage:SetAttribute("ServerTestOnly", "speed_probe"); ReplicatedStorage:SetAttribute("ServerTestRun", true)
	-- ServerTestOnly (comma-separated names) runs only those scenarios; clear it (nil) for the full suite again.
	OnDemand = {
		-- 23 checks of WORLD_REDESIGN_SPEC 4.2 PENDING, red by design (PlazaBuildTests.PENDING; owner 2026-11-25): 13 wait for the
		-- uploads, 8 for the world gate's build, 1 for the altar's build, 1 for the merchants (passes offline). As work lands,
		-- rows leave PENDING and this count; at 0 the entry goes.
		"plaza_build_pending",
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
