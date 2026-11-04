# Agent handoff

## State — 2026-10-28
- Specs written (no code yet): `docs/GAME_DESIGN_REQUIREMENTS.md`, `TEAM_AND_STAMINA_SPEC.md`,
  `CHARACTER_GACHA_SPEC.md`, `NPC_RIVAL_SPEC.md`, `RESEARCH.md`.
- Owner decisions: tweaked-name real anime characters (was original, changed 2026-10-28), stamina refills every run, exhaustion cashes out the bank.
- Owner 2026-10-28 (later): Stamina stat point, Stamina potions, runner categories, Series + preset team bonus.
  Written into design doc 4.5-4.8, `TEAM_AND_STAMINA_SPEC.md`, `CHARACTER_GACHA_SPEC.md` (6 tweaked-name real-anime series).

- Orchestrator 2026-10-28: config `.claude/orchestrator.md`, goal `fork-ivs` (docs/ORCHESTRATOR_GOALS.md), integration
  branch `feature/alex/fork-ivs`. f1 landed (IVS 29f3fab copied in; rojo build OK, stylua clean, selene 0 errors with 4
  inherited warnings in CarTest test files; audit PASS). Repo moved to ~/Documents/Github/personal-projects/AnimeRun.

- Studio: Anime Run experience placeId 102957063656302 (universe 10773557968). AnimeRun Rojo = `rojo serve --port 34873`
  from this folder; IVS keeps 34872. Every Studio MCP call names the Anime Run studio id, never Racer RNG.

- f2 LANDED 2026-10-28 (merge 9a652dd on feature/alex/fork-ivs, pushed). Full harness in Anime Run Studio:
  pass=47 fail=2; fixed: data.unknown_ids_preserved (test expected an unsorted id list, fixed by test-writer) and
  spawn_area.spawn_only_spawn_location (default Workspace.SpawnLocation deleted in Edit; owner must save the place).
  Re-run data,spawn_area pass=2 fail=0. Audit PASS. Worktree ../AnimeRun-orch/f2 and branch removed. Rojo 34873 now
  serves this folder.
- Owner 2026-10-28: Anime Run keeps only IVS gameplay logic and concepts; every visual and asset is new.
- Dashboard: `/dashboard` -> http://127.0.0.1:8766 (tools/dashboard, uncommitted; 8765 is IVS).
- 2026-10-28 17:15: Roblox_Studio MCP added to this project (local scope); needs a session restart to load. Resume:
  restart `rojo serve --port 34873` from ../AnimeRun-orch/f2 if not listening, owner connects Anime Run Studio,
  Studio MCP health check (list studios, pick Anime Run, never Racer RNG), run harness for f2.
  Owner wants every relevant skill/plugin used for the redesign (anime-world goal, w1-w5 deliverables still
  "proposed, owner to confirm"): roblox-game-development-lifecycle, roblox-game-skill, roblox-ui(-implementation),
  roblox-vfx, world-builder agent. Blender MCP added (local scope).

- f3 DONE 2026-10-28: full harness `[CARTEST] END pass=49 fail=0` in Anime Run Studio on feature/alex/fork-ivs
  (89c0e81), audit PASS. oq2 answered: Anime Run private experience, no IVS visual content copied. First f3 run was
  lost to a Wi-Fi drop (Team Create disconnect 276); rerun green. All fork-ivs deliverables done.

- Owner 2026-10-30: tracks very long (984 x F x 1.25^(n-1), F proposed 3, Track 1 gets a new layout) and biomes
  researched from public info on each anime, matched closely, section 5 safeguards kept. Written into design doc
  4.9 / section 8, TRACKS_AND_BIOMES_SPEC (References section), TEAM_AND_STAMINA_SPEC, goals w3/w4. Open: F (stamina retune done below).

- Owner 2026-10-30 (later): speed over stamina. Base stamina 20/22/24/27/30 (placeholder), Mythic 36, Secret 43;
  Legendary trio clears 10 tracks in ~90 s using its stamina; Marathoner cruise x0.8, stamina x2.0 (proposed),
  Sprinter stamina x0.8 (proposed). NPC speeds unchanged. Owner same day: category speed
  after damping, F = 3 confirmed, Speed stat x(1e15 / 3e5) so 1 Qd = 300K old (design doc 4.11; code not done:
  RaceConfig HALF_STAT / GAIN_PER_SECOND / MAX_STAT, WorkshopConfig.BASE_RATE, 4 CarTest files). Open: old saves.

- 2026-10-30 w1 LANDED (merge d5e851b on feature/alex/anime-world, pushed): full harness pass=45 fail=0, audit PASS.
  Also landed: Speed rescale 4.11 (5bcad37, 97bc576, 9d6ce42, 3344c99) and log-scaled Speed board LB_Speed_v3
  (b92e777). Owner rulings 2026-10-30 in WORLD_REDESIGN_SPEC 2 and design doc 4.11 / change log.
  Studio: 3 IVS leftovers (ReplicatedStorage.RacingGarage, RaceStartPavilion, CarModels) deleted in Edit; OWNER
  MUST SAVE THE PLACE. Owner's /givespeed 1e22 reverted (it lives in Players.<name>.BaseSpeed, not leaderstats).
  Rojo 34873 serves this folder again; the Studio plugin needs Connect after each Rojo restart.
  Harness polling: execute_luau waits of >~2 min time out; poll in <=115 s calls. Play must restart to pick up
  Rojo-synced code.

## Next
1. DONE 2026-10-28: fork-ivs merged into main (PR #1, 039ad28), goal closed. Integration branch for anime-world:
   feature/alex/anime-world.
2. Owner: confirm anime-world deliverables w1-w5 (docs/ORCHESTRATOR_GOALS.md, "proposed, owner to confirm").
3. DONE w1, DONE w2 (merge cca9d50, pushed). Next: anime-world w3 (track tests + layouts 1-10), then w4. Old w2 note: (world layout + plaza hub + 7 Dojo plots), task branch orch/anime-world/w2, tests first
   (`world_layout`, `dojo`, `spawn_area`), WORLD_REDESIGN_SPEC sections 3-5.

- 2026-10-30 w2 LANDED (merge cca9d50 on feature/alex/anime-world, pushed): full harness `[CARTEST] END pass=47
  fail=0`, spawn_area green at the restored tight tolerances. Owner 2026-10-30: plaza centre = world origin, track
  chain moved to TrackBuilder.CHAIN_ORIGIN (-118, TRACK_LIFT, 80); WORLD_REDESIGN_SPEC 3 values are the owner's;
  IVS hub-check retirements approved. Studio id is now 6ea5e972; harness attributes live on ReplicatedStorage and
  the run starts only when CarTestRun changes to true. Startup warning rbxassetid://203785492 = "Pop Close Sound"
  (audio), not referenced by the game; probably a Studio plugin. Rojo 34873 restarted from this folder (Studio
  plugin needs Connect). Worktree ../AnimeRun-orch/w3-research holds 77151e7 (biome References) not yet merged.

- 2026-10-30 w3 PAUSED by owner (tests paused). Worktree ../AnimeRun-orch/w3 (orch/anime-world/w3): tests committed
  49b1ca0; implementer code UNCOMMITTED (10 spiral layouts, TrackValidator TARGET_LENGTH, Ground tiling in
  TrackBuilder/BiomeDressing, per-track yield in Main, VfxArea x=2800). Owner 2026-10-30: track ids kept, full drives
  in full harness, spiral = mean distance, sector = ring band (all in specs, uncommitted in w3 doc edit for ring band).
  Partial harness (Studio af833537): chain PASS, npc PASS (~12 min now), auto_toggle PASS; track:Oval FAIL
  race_path_curvature_shifted=-1 (no sample, Scenarios.luau:391-397, not diagnosed); track:Hill FAIL
  race_path_spacing=17.075>15 (TrackBuilder.Layout 6 deg per turn waypoint; fix: step = max(ceil(|a|/6),
  ceil(arc/12))); world_layout + spawn_area TIME OUT (non-yielding overlap loops WorldTests.luau:129-253, 279-310,
  Scenarios.luau:8577-8597; test-writer fix: broad phase + yields). Not run: track:DragRace..Space, environment.
  Rojo 34873 serves the w3 worktree. Owner wants w4 started after w3 lands.
- 2026-10-30 later: w3 fixes done (uncommitted in ../AnimeRun-orch/w3): TrackBuilder turn step by arc (<=12 studs) +
  S-bend inflection curvature 0 (fixes Hill spacing, Oval -1); test-writer broad-phase + yields in overlap loops
  (TrackChainTests.footprintOverlaps); owner 2026-10-30 ruling: wider bends on Tracks 7-10 so NPC times match the
  spec table (sim within +0.7%); world now spans about +-4150 studs; VfxArea x=5000. Audit: NEEDS OWNER on NPC
  times, answered (wider bends); otherwise clean. Full harness started on the PRE-widening code, then PAUSED by owner.
  Next on resume: full harness on current w3 code, re-audit Tracks 7-10 diff, land w3, start w4 (owner asked).
- Paused full-harness attempt (Studio id now 67a61451-caee-40ec-ada9-80adcbcec7c9): no scenario finished. Only
  START + WARMUP printed; Play stopped by itself ~17 min in (cause unknown; Team Create collaborator present). First
  scenario `runner` drives the whole ~98k-stud route at normal (~88 studs/s, ~18.5 min) and max speed, so it may be slow,
  not hung. On resume: run CarTestOnly="runner" alone and time it; consider a local (non-Team-Create) place copy.

- 2026-10-30 w3 LANDED (2751d36) and w4 LANDED (1de11ce) on feature/alex/anime-world, pushed. Owner 2026-10-30: test
  only as a dev tool; one full compatibility check (c3) at the end. New goal `core` (c1-c3) in ORCHESTRATOR_GOALS.
  c1 in progress in ../AnimeRun-orch/c1 (orch/core/c1): tests f947f51 + 31a4ff7, owner rulings ab3fccc (run bank
  restored; loss reset refills stamina). Rojo 34873 now serves the c1 worktree. Open: w4 horizon built at offset 55
  (far edge ~100); IVS textures still uploaded on Roblox (owner may delete); Track 10 ~8.8k dressing parts, client perf
  unmeasured; ShowcaseTests SPEC.VERSION 12 -> 13 needs the test-writer when c1 bumps PlayerData.

- 2026-10-30 (orchestrator, biomes priority 1): owner rulings: free Creator Store assets of every kind allowed (Lane
  D: free only, no anime IP, scripts stripped, id + creator in ledger; design doc 5 + BIOME_ENVIRONMENT_SPEC 4.1/4.4/6
  amended); b0 approved and merged (19ad0bf, pushed); b2 built one track at a time with a 3-view screenshot set shown
  to the owner after each track; c1 PAUSED (committed on orch/core/c1, unverified). b1 started in
  ../AnimeRun-orch/b1 (orch/biomes/b1): test-writer (src/server/CarTest only) + implementer (rest of src) running in
  parallel, uncommitted. Rojo 34873 serves the b1 worktree. Studio id fc533734-a2a5-4b22-baf0-f95aad5edbb6.
  Next: verify b1 (stylua, selene, scenarios terrain_built, zone_switch, server_lighting_unchanged, assets_ip),
  audit, land; then b2 Track 1 (Speedway, Leafwind Village) -> screenshots to owner.
- 2026-10-30 b1 LANDED (merge b289cb8, pushed): 4 b1 scenarios pass in Studio fc533734 (terrain 27.0 s, 1600 chunks);
  audit FAIL (2 ledger bypasses in BiomeEnvironment.client) fixed. Owner: skybox ledger rows one Id or 6 Faces;
  optional `Craters` terrain field (spec 3.3). Running: Track 1 builder in ../AnimeRun-orch/t1 (orch/biomes/t1,
  holds Studio; Rojo 34873 serves t1); Craters framework in ../AnimeRun-orch/craters (no Studio). Next: IP review
  of Track 1 screenshots, land t1, show owner 3 screenshots, then Track 2 (needs craters landed).
- 2026-10-30 Track 1 (t1): Speedway data done (11 Lane A meshes + textures, Lane D skybox + 3 sounds, leaf particle);
  terrain_built, assets_ip, server_lighting_unchanged pass=3 fail=0 after a framework fix (runtime cannot write
  LevelOfDetail; pcalled, b41053d on orch/biomes/craters, merged into t1). Play screenshot recipe: on Client set
  settings().Rendering.QualityLevel = Level21 (Automatic draws only a few hundred studs; atmosphere paints the void
  blue), anchor the character at the shot (streaming), RenderStep "Shot" forcing Scriptable camera + ScreenGuis off,
  screen_capture with no camera args. Rojo: after a rojo restart the owner must click Connect; sync can land after
  Play starts - check Source in Edit before Play. Framework fixes running on orch/biomes/craters: Sections, hero At
  pin, mesh = 1 budget part, road z-fight (terrain top == road top), SnapToTerrain buries props (lowest of 5).
- 2026-10-31: Track 1 OWNER APPROVED (screenshots). Track 2 LANDED (cdf69e3): pass=3 fail=0, 18 ledger rows signed by
  the rules auditor (new rule: builder saves close-ups to assets/biomes/<Key>/review/, auditor signs Reviewed, then
  Play + shots). Rojo serves the FIXED worktree ../AnimeRun-orch/studio (switch its branch per track; no reconnect).
  Running: Track 3 builder (studio, orch/biomes/t3, holds Studio), fw2 framework fixes (../AnimeRun-orch/fw2),
  Track 1 re-review sign-off (../AnimeRun-orch/t1review). Open: rock colour #7C8C99 reads blue (retune), Track 2
  shots awaiting owner review.
- 2026-10-31 (session resumed after /clear): Track 1 fully landed and pushed (d058e8f). Owner: Track 2 road
  palette sand/stone (Hill.luau, committed 120b023 on orch/biomes/fw2, with fw2 embank WIP); land Track 2 once fully
  finished (fw2 fixes + Embank/BiomeBob back on), push; continue Track 3, then Tracks 4-10 one at a time.
  Agents afdb62cd8fe80c98a / ad4b45bd5034895b3 still running fw2 (../AnimeRun-orch/fw2) and t3 (studio worktree,
  holds Studio fc533734; Rojo 34873 serves studio). Open: rock colour #7C8C99 (Rock material, global) still blue.
- 2026-10-31 LANDED d6b1402 (pushed): Track 3 Pirate Harbor Isle (owner approved visuals) + fw2 framework fixes +
  Track 2 finish (sand road, Embank, BiomeBob). Owner rulings 2026-10-31 in BIOME_ENVIRONMENT_SPEC 3.2/3.4: props
  slide/delete past the gap midline, 2-hero floor, pinned (At) heroes never deleted and sit on a natural-height pad,
  house-like props (Pad = true) get small pads, Rock 8A6E52. Scenarios pass=3 fail=0, terrain 27.1 s.
  PAUSED by owner after Track 3; resume only on "continue". On resume, fw2 follow-ups first:
  (1) 25 Docks houses + Track 1 VillageHouse 3.6 / ElderHouse 7.0 still float >1 stud with Pad;
  (2) TileRing max gap 11.4; (3) warnings "pinned hero reaches into a road corridor" for Landmark_259/_263/_315/_49;
  (4) retake final Track 1-3 shots; then Track 4 (Wisteria Night Mountain, Suburb).
  Worktrees ../AnimeRun-orch/fw2 (orch/biomes/fw2) and studio (orch/biomes/t3) kept; Rojo 34873 serves studio.
  Studio fc533734 in Edit, clean.
- RESUME PLAN (owner 2026-10-31): fw3 framework follow-ups are remembered and go first (docs/BOARD.md Next, state
  file resume_step). Track 4 non-Studio prep may run asynchronously alongside fw3, but t4 merges fw3 before any Studio
  verification. Studio + Rojo 34873 = one agent at a time (serves ../AnimeRun-orch/studio; switch its branch per task).
- 2026-10-31 night (owner, asleep until morning): CONTINUE without approval, finish Tracks 4-10 end to end. Any
  question: take the recommended / most optimal option, record it as "orchestrator default 2026-10-31 (owner
  delegated)" in the spec, and list every such decision in docs/OWNER_QUESTIONS.md for the morning review. Running:
  fw3 in ../AnimeRun-orch/fw3 (orch/biomes/fw3, code only); t4 builder in ../AnimeRun-orch/studio (orch/biomes/t4,
  holds Studio). Loop per track: build -> auditor signs ledger -> merge fw3/framework -> Studio verify + shots ->
  land + push -> next track (Track 5 PirateCoast = Neon Cursed City ... Track 10).
- 2026-10-31 LANDED 4d1b112 (pushed): Track 4 + fw3. Next: t5 Studio phase (switch ../AnimeRun-orch/studio to
  orch/biomes/t5), cam feature in ../AnimeRun-orch/cam (needs one Studio check), fw4 shoulder-band hall floats.
  Studio id 5846836b-1bf9-487a-9411-11346220b296. CarTestOnly left set in Edit (harmless).
- 2026-10-31 LANDED 0962287: Track 5 + track camera. Studio -> Track 6 next.
- 2026-10-31 night progress: landed Tracks 4, 5 + fw3 + track camera (pushed a5d9a32). fw4 99171b3 (pad margin 4,
  Lune harness tools/lune/biome_harness.luau) merged into t6/t9/t10, lands with t6. Phase 1 committed on branches
  t7 53d4f64, t8 714b8fc, t9 f61e03b, t10 5e3bb17 (worktrees ../AnimeRun-orch/t7..t10). Studio queue t6 (verifying)
  -> t7 -> t8 -> t9 -> t10; loop per resume_step in .agents/orchestrator.json. Morning list: docs/OWNER_QUESTIONS.md.
- LANDED 9858032: Track 6 + fw4. Studio -> Track 7.
- 2026-10-31 OWNER: finish Track 5 redesign (Jogo vs Sukuna burning city, night) and Track 7 (Shibuya Incident subway,
  full tunnel + platforms), then PAUSE. Tracks 8-10 resume 2026-11-03 (Track 8 = Skypeia, rival Enelu [Enel]).
  Doc rulings on orch/biomes/redesign (uncommitted until the research agent finishes the spec rewrite).
- t9 mesh ids generated before the pause (not yet in Volcano.luau; mesh / texture): PalaceTower 119149403207359 /
  76635598272222; BoneArch 110904618566239 / 75741383222967; CrystalGrove 130820802100278 / 92159538463265; DomePalace
  124094406088392 / 119854563443296 (squat); DeadWhiteTree 105854949421877 / 109452863592933; CrystalTree
  130960597807577 / 78285130678274; WhiteOutcrop 115443145387024 / 120675993065195; BrokenPillar 92998731248487 /
  75950047585759. No close-ups yet; nothing uploaded.
- 2026-10-31 PAUSED by owner. State:
  - Landed + pushed: Tracks 1-6, fw2-fw4, track camera, redesign specs (e8728f3).
  - orch/biomes/fw5 (../AnimeRun-orch/fw5): Tunnel framework 3181c1c + 26ecc52 + tests eb49bff, NOT landed (Studio check
    comes with Track 7).
  - Track 5 rebuild "Burning Cursed City": orch/biomes/t5r in ../AnimeRun-orch/studio (Rojo-served), uncommitted, mid
    step A; see the t5r pause report below for mesh ids.
  - Track 7 rebuild "Shibuyo Underground": orch/biomes/t7r in ../AnimeRun-orch/t7r (has fw5), phase 1 uncommitted.
  - Tracks 8-10 paused until 2026-11-03 (t8 Skypeia redo; t9 mesh ids above; t10 phase 1 done).
  Resume order: t5r (Studio) -> audit -> verify -> land (replaces old Track 5); t7r phase 2 -> land with fw5; then Nov 3.
- t7r pause report: phase 1 not started (reading only). Framework gaps found, to fix before/with t7r (fw6):
  (1) src/shared/Tracks/Desert.luau header + Description still say Blossom Shrine; (2) BiomeDressing ignores the tunnel:
  props sit at edge+Offset on both sides, never lifted onto bay platforms (road +4); pinned heroes choose their side by
  corners/alternation, not by the bay's Side; (3) gate: use Gate.Index on a waypoint before s=16 (in front of the start
  portal) or Gate.Skip. Unchecked: beside() side sign vs Tunnel Left.
- t5r pause report (branch orch/biomes/t5r, close-ups committed): meshes generated, NOT yet in PirateCoast.luau
  (mesh / texture, size): BurningTower 110026199515917 / 111995406996497 (15.9x35.9x16); Meteor 129629428349458 /
  127234806169781 (16x6.4x16); CollapsedViaduct 104055839246591 / 105638459114043 (22.2x15.3x10); SlicedTower
  118384879998435 / 79499249668457 (16x31.7x15.6, top half floats above the cut - auditor to judge); BurningCar
  75112982054894 / 137060689993765 (nose -Z); RubblePile 90775659169182 / 135149187378761; BurntBillboard
  99613692659503 / 124515013244308 (blank); BrokenStorefront 90903812309143 / 122708716943483 (front -Z). Keep signed
  TrafficLight, RailOverpass, ConcreteBlock (11 unique). Left: module rewrite, ember/smoke PNGs, sounds, palette,
  harness, step B. Also for fw6: EnvironmentTests:35 expects "Neon Cursed City" (test-writer), Serpentine header text,
  landmark ParticleEmitters ignore REDUCED EFFECTS.
- LANDED Track 5 rebuild (Burning Cursed City). Next: fw6 -> t7r Studio; then t8 (Skypeia), t9, t10. Open: T5 live floats LavaCrack patch 6.5, debris 2.2.
- LANDED Track 8 Skypeia. Next: t7r Studio (move ../AnimeRun-orch/t7r into studio), land with fw5+fw6; then t9, t10.
- 2026-10-31 STOPPED by owner ("will continue later"). Landed + pushed: Tracks 1-6, Track 5 rebuild (Burning Cursed
  City), Track 8 Skypeia, fw2-fw4, track camera, redesign specs.
  In progress (NOT landed), Rojo-served ../AnimeRun-orch/studio on orch/biomes/t7r (includes fw5 tunnel + fw6 +
  tests): Track 7 Shibuyo Underground step A partly done (14 close-ups, some mesh ids in Desert.luau; see the t7r
  stop report). Uncommitted docs: owner fight-scene ruling (Gojio vs Joggo/Hanamy/Mahitto/Chosu, Gojio mid domain
  expansion) in the design doc change log; research agent was writing the scene spec into BIOME_ENVIRONMENT_SPEC 7.
  Resume: commit t7r WIP; finish the fight-scene spec; t7r step A + fight figures/VFX; audit; verify incl tunnel_clear,
  camera clamp, flicker; land t7r with fw5/fw6. Then t9 (mesh ids in this file), t10 (phase 1 on orch/biomes/t10).
  Morning/owner review list: docs/OWNER_QUESTIONS.md.
- Fight-scene research (stopped, nothing written to specs): refs sportskeeda S2 ep8 (Gojo lands on B5F Fukutoshin
  platform; Hanami's branches seal the entrance), animecorner ep8 preview, animehunch "how did Gojo kill Hanami"
  (blindfold off, horns torn out, crushed into a wall), bamsmackpow ep9 review (train of transfigured humans),
  animehunch Unlimited Void explainer. Fandom wiki returns HTTP 402 (not bypassed) - figure looks unconfirmed.
  Plan: scene in the deep main platform hall bay 0.82-0.90 (At ~0.84, Left), concourse 0.37 fallback; stylised blood
  only; every prompt through realNameIn.
- t7r WIP committed 14abf92 (12 mesh ids in Desert.luau, dust 77443196483447, sky faces Bk 126814177699454 Dn
  90423288718397 Ft 91385232590200 Lf 119320290687932 Rt 98579734251070 Up 89593505205012). All work branches pushed
  to origin (orch/biomes/fw5, fw6, t7r, t9, t10, t7 superseded) for safety; only feature/alex/anime-world is integrated.
- 2026-11-01 RESUMED (owner): Tracks 9-10 + Track 7 completion. Owner asks: Track 7 brighter (not pure darkness);
  Track 4 more neon purple lights + ambient air particles (twilight). Running: t9 in Studio (b78475e0), t7r
  brightness + NOMESH in ../AnimeRun-orch/t7r, fight-scene spec in t7r docs, t4 tweak in ../AnimeRun-orch/t4b.
  Studio queue: t9 -> t7r (fight figures + verify) -> t10 -> t4b check + shots.
- t4b (Track 4 twilight tweak) paused before any edit. Spec 5.2 caps zone emitters at 2 per profile, Rate <= 40;
  Track 4 uses both (petals 14, fireflies 8). Plan: retune those two (no new textures) + neon purple accents/Glow +
  twilight atmosphere nudge + spec 7 update.
- t7r WIP pushed: brighter tunnel (Ambient #6A7470, OutdoorAmbient #3A4442, Exposure 0.35, EnvDiffuse 0.4, Density
  0.2, Haze 0.5, tint #FFF6EA, Contrast 0.12, LightEvery 16; Tunnel.LIGHT brightness is framework). Harness not rerun;
  NOMESH 23 props outside (Scatter fallbacks ~7.2x3.6x5.2, untraced).
- Fight-scene spec: nothing written. Extra source: en.wikipedia.org/wiki/List_of_Jujutsu_Kaisen_characters (Hanami's
  shoulder flower, Jogo fire, Choso blood, Mahito reshaping); animecorner + bamsmackpow ep8. Gojo/Jogo/Mahito looks
  not confirmed by a public source. Write as a new Track 7 subsection; note the owner override of the IP line there.
- t9 paused: no uploads, no ledger ids, files unchanged (f61e03b + merge d446f36, studio worktree on orch/biomes/t9).
  Left: close-ups (DomePalace squat -> regenerate), uploads (sand, moon, 6 sky faces), ids, harness/lint, verify.
- 2026-11-01 PAUSED by owner. Studio b78475e0 clean in Edit. Resume order: t9 (Studio) -> t7r (NOMESH + fight spec +
  figures + verify, land with fw5/fw6) -> t10 -> t4b twilight tweak (retune 2 emitters, neon purple) + shots.
- LANDED Track 9 Spirit Realm Desert. Next: t7r Studio (fight figures + verify), then t10, then t4b check.
- 2026-11-01 OWNER: after Track 7 lands (fw9 -> 4 checks green), PAUSE ALL TESTS. Then land Track 10 (audit PASS,
  9bf594a) and the Track 4 twilight tweak (t4b 020dfa9) without scenario runs (screenshots only). Full compatibility
  check c3 (full harness + rules audit) runs ONLY when the owner says so.
- LANDED Track 7 + fw5-fw9 (a96717a). TESTS PAUSED (owner). Now: land t10 + t4b with screenshots only; c3 on owner's word.
- LANDED Track 10 (dbb84e1, no scenarios - owner pause). Track 4 twilight shots in progress on orch/biomes/t4b-shots (studio worktree). Then: all 10 tracks done; c3 full compatibility check waits for the owner.
- LANDED Track 4 twilight tweak. ALL 10 TRACKS LANDED on feature/alex/anime-world. Waiting for owner to start c3 (full compatibility check). Open review list: docs/OWNER_QUESTIONS.md (+ T4 MoonPeak backdrop reads as a flat pale box).
- 2026-11-01 OWNER URGENT list, written into design doc 4.13-4.18 + TEAM_AND_STAMINA_SPEC Speed/Balance:
  fixed cruise per rarity x category (proposed Common 20 .. Secret 700), no Speed stat/gain; speed multi = Speed
  stat points, Speed potions, preset x1.1, per-slot aura + trail; rebirth = luck, XP, +1 stat point; sensei is an
  info-only track overview (no checkpoints, runs start on Track 1); leaderboards removed; biome welcome popup;
  faster mesh/texture/sky loading at high speed. Open (owner): workshop/Dojo idle gain after Speed retired.
  Tasks u1 (speed/rebirth/sensei), u2 (leaderboards/popup/sky), u3 (mesh/texture loading). Tests still paused.
- 2026-11-01 LANDED u1 (c448a79), u2 (4d50953), u3 (936d266), hero SLIM template (f197432), popup/sky fix (58190ae);
  not pushed. Studio 9db12bba: popup works at y 0.22, HeroLodTemplate syncs as SLIM, Cruise=20 for a Common, 0 errors.
  Workspace.StreamingTargetRadius/MinRadius are not valid members in this Studio (Rojo may skip them; radius unset).
  Studio worktree ../AnimeRun-orch/studio is DETACHED at feature/alex/anime-world (Rojo 34873 serves it).
  Open (owner): Best Roll pedestal keep/remove; Speed Doubler passes + upgrade "Speed Gain" branch now do nothing;
  stamina vs fixed-speed balance (Common can't finish Track 1 on 20 s stamina once c1 lands). Next: u4 per-slot aura/trail.
- 2026-11-01 LANDED u4 (98fdad5): SlotItems save (3 slots, old EquippedAura/Trail -> slot 1), Slot<n>Aura/Trail attrs,
  SlotPicker UI, Speed Doubler passes gone, Best Roll fed (LeaderboardService.Start({"RarestCar"})), upgrade Speed
  branch +10%/tier cruise. Studio id now 942e6c51 (Anime Run). Owner's Studio test save (PlayerStats_v2,
  Player_232682736) was reset between 11-01 20:01 and 11-02 00:39 UTC by pre-u1 code (Money 3.68b -> 0, Cars 10 -> 5,
  BestTrack 9 -> 0); version 11-01 20:01 still exists if the owner wants it restored. Next: c1 (team/stamina +
  per-distance exhaustion pay), test retarget, then c3 on owner's word.

- 2026-11-01 (UNCOMMITTED on feature/alex/anime-world): owner removed player Level / XP; rebirth needs Money
  (RebirthConfig.BASE_MONEY 1e5 x MONEY_GROWTH 10 ^ level, placeholder; design doc 4.14). LevelService / LevelConfig
  deleted, /givexp gone, saves keep old Level / XP via RETIRED_KEYS. HUD Level bar hidden (not deleted: HudChrome
  positions Items / Upgrade from it; needs a HUD layout pass). Tests updated (Phase2 rebirth, UiTestSetup,
  ShopPurchase, UiBoostsRebirth, UiSpec, UiScenarios). Pre-existing: Phase2 Tests.rebirth calls removed
  RebirthConfig.SpeedGainMulti outside pcall (whole suite may error).
- Same day: biome while racing comes from server `RunTrack` on the runner rig (RaceService.publish, cleared on
  run:Destroy); client BiomeEnvironment uses it with no hold, ZoneAt only while walking; look-ahead removed (switched
  ~280 studs early at 800 studs/s). Design doc 4.18. New checks runner_*_publishes_track / track_cleared_on_stop
  (RunnerTests). Nothing run in Studio yet.
- 2026-11-02 (UNCOMMITTED on feature/alex/anime-world): owner brought sensei checkpoints back (design doc 4.15
  rewritten + change log). Track 1 always open, track n opens at BestTrack >= n-1; saved `Checkpoint` (no longer a
  RETIRED_KEY); run starts / loss restarts / loop returns to the checkpoint track. Checkpoint bonus: tracks won past
  the checkpoint in one run pay pad cash x min(2, 1 + 0.1 k) (placeholders, CheckpointConfig). CheckpointService
  restored (SetCheckpoint). Owner also asked for a more detailed, accurate Tracks panel: biome DisplayName on cards and
  title, status chip, length, NPC rival speed + time, your runner speed + time (green / red), payout, bonus line,
  START HERE; previews use theme Sky colour, a theme ground plate (Terrain is not baked) and drop the Track 7 tunnel
  roof. UiContracts / UiSpec checkpoint checks retargeted; new pure test `checkpoints` (Phase2Tests). stylua clean,
  selene 0 errors, rojo build OK, config logic checked in lune. Nothing run in Studio (tests paused by owner).
  Bonus popup: Client/CheckpointBonusPopup (placeholder, y 0.3). Exhaustion share gets no bonus (c1).
- 2026-11-02 (UNCOMMITTED): owner "stamina still not implemented": c1 ported onto current code (orch/core/c1 was
  never merged). Team of 3 (save VERSION 13 `Team`), SetTeam remote, Backpack Characters tab picks a character then
  slot 1-3 (SlotPicker kind "Character", swaps / removes), single equip puts on slot 1. Stamina per run (RunSlot,
  Stamina1..3), swap at 0 with RunEvent toast, exhaustion banks the per-distance share then cashes out and stops the
  run; run bank restored (wins bank, loss empties, stop cashes out); loss refills at the checkpoint. Owner stamina
  13.5 .. 30 s (Common 12-15, Secret 30), category stamina x0.9 / x1.1 proposed. Vertical blue bar right of every
  visible runner (Client/StaminaBar). Runner aura / trail and cruise follow the active slot. StaminaTests ported.
  Studio smoke (studio worktree detached at 8b681de + this patch): drain, bar, swap 1-2-3, exhaustion cash-out OK.
  Fixed a TrackPreviews crash (SurfaceLight .Position). Balance: a Common (24 studs/s, 13.5 s) covers ~324 of
  Track 1's ~2,950 studs, so it can never win Track 1; owner must retune. c2 (stat point, potion, team bonus) open.
- 2026-11-03 (UNCOMMITTED on feature/alex/anime-world, owner request): Track 1 balance kept (owner). c2 built: Stamina
  stat point (GachaConfig.STATS + PER_POINT 0.05), upgrade tree Stamina branch (new, owner; stamina_1..5, +10%/tier,
  hex {1,0}), Stamina potions StaminaI-III (orchestrator default: same tier pattern as the other potions; Robux pack
  potion_stamina_pack ProductId 0, bundle, daily day 3, code RELEASE), Series / Preset team bonus
  (SeriesCatalog.TeamBonus, StaminaConfig.Multi, preset cruise x1.1 now on). Stamina multi fixed at run start
  (RaceService). Server publishes TeamBonus, TeamCruise1..3, TeamStamina1..3 (GachaService.RefreshTeam). TeamHud
  rewritten: head-only portraits (body + rarity belt removed), neutral ring, stamina liquid level, active gold pulse +
  bobbing marker, tag-in pop, tired grey + shrink, team bonus badge, hover / tap info card (name, category + effect,
  cruise, stamina; no rarity). StaminaBar: tweened drain, "just lost" trail, blue/amber/red (StaminaConfig.Color),
  low pulse, refill flash on swap. Docs: design doc 4.3/4.5/4.6 + change log, TEAM_AND_STAMINA_SPEC. stylua clean,
  selene 0 errors, rojo build OK, lune check of TeamBonus / Multi / Seconds OK. NOT checked in Studio (no Studio
  connected); changed files copied into ../AnimeRun-orch/studio/src. Placeholders: Stamina bottle + stat/tree icons
  reuse Speed art; Shop potion packs now 4 per row. Tests (StaminaTests team_bonus etc.) not written (tests paused).

- 2026-11-03 char-art a1-a3 LANDED locally (merge 4ae6d23 on feature/alex/anime-world), NOT PUSHED: `git push` fails
  3x with "remote unpack failed: index-pack failed / inflate returned -5" (local objects check clean, 242 objects,
  37 MB incl. 30 .blend + 121 PNG). Retry the push; if it keeps failing, consider Git LFS for assets/characters.
  Owner 2026-11-03: draft + renders only, shared chibi base, ALTERED signature marks (design doc 5 + change log).
  Build: `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/build_character.py -- [<id>...|--sheet]`
  (headless, no Blender MCP; the MCP addon was not running). Data tools/blender/characters.json (Reviewed signed for
  all 30 by the rules auditor, PASS after 1 doc-sync round). Contact sheet assets/characters/contact_sheet.png.
  1,248-2,444 tris each. Reference facts are unverified (wiki 402). Next: owner visual review of the contact sheet;
  then a later deliverable: FBX export, Studio import + R15 rig, `Model` field (needs a new goal deliverable).
- 2026-11-03 LANDED on feature/alex/anime-world (pushed b860845): c2 (stamina stat / tree / potions / team bonus, team
  row + bar polish), c4 workshop stat boost (design doc 4.19; audit PASS after cruise-snapshot fix), UI animations
  4.20 (audit PASS) + panel close motion (fc8b099), tests retargeted to current rules + team_bonus / stamina multi /
  workshop_boost checks. Owner rulings 2026-11-03: workshop stats Money/Luck/Speed/Stamina, rarity points x 5%, always
  active, levels scale the boost (Workshop stat refunded); upgrade tree Money +10%/tier. c3 (owner asked 2026-11-03,
  "loop fixes"): full harness started in Studio 684395a0 (Rojo 34873 serves ../AnimeRun-orch/studio, detached at
  b860845; its old copy stashed). First scenario `runner` ~18 min. Then UI harness (UiTestRun). Known expected reds:
  Market subtitle format, HudPair.Stacked rects. Poll in <=112 s execute_luau calls.
- 2026-11-03 c3 loop (owner: run full compat check, loop fixes). Integration f4c2db7 (pushed). Results so far:
  server round 1 `[CARTEST] END pass=38 fail=12`, round 2 pass=46 fail=4 (all 4 fixed since in 37725fd, not yet
  re-run); UI round 1 pass=25 fail=14, round 2 pass=32 fail=7, round 3 pass=37 fail=2 (ui_layout phone HUD-pair
  overlaps = BUGS ui-layout-phone-overlaps; ui_reduced_motion roll viewport). UI agent fixing both live in
  ../AnimeRun-orch/studio on branch orch/core/c3ui (Rojo-served, holds Studio 684395a0). Owner rulings 2026-11-03:
  palette finish pads, Track 6 one row, late tire = exhaustion, Money tree +10%. Next: land c3ui, final full server
  harness + UI harness to fail=0, rules audit, then PR feature/alex/anime-world -> main (fresh reviewer).
  Test-writer worktree ../AnimeRun-orch/c3fix (orch/core/c3fix, merged).
- 2026-11-03 char-art a4 pilot (UNCOMMITTED, owner): chibi retired for Roblox avatar proportions + rendering (Anime
  Adventures-style inspiration, no copied art), distinct resemblance; marks may closely resemble the original (owner
  chose this over "altered", accepts the risk; official logos / ripped art stay banned). Docs updated: design doc 5 +
  change log, CHARACTER_GACHA_SPEC Avatar pipeline, goals a4/a5, CHARACTER_ART_REFERENCES, WORLD_REDESIGN_SPEC 2.
  New: tools/blender/avatar_base.py, build_avatar.py, avatar_characters.json; pilot leaf_hero, leaf_avenger, leaf_medic
  in assets/characters_avatar/ (2,219-2,638 tris). Next: owner approves the look, rules auditor signs, then a5 (other
  27, remove chibi_base + assets/characters). c3 is still open (see c3 loop above).
- 2026-11-03 char-art a5/a6 LANDED on feature/alex/anime-world (owner): all 30 avatar models in game. Data
  tools/blender/avatar_chars/, merge + look tools/blender/avatar_merge.py (ink hull, cel bands), auto folds and small
  sharp faces in avatar_base.py (owner reference shots: close to the source design, DMCA risk accepted). Uploaded under
  the owner's account (tools/blender/avatar_assets.json, generated Shared/CharacterModelAssets; the two earlier upload
  rounds are orphaned on the account). Server/CharacterModelService loads them, RunnerFactory clones / swaps. Rollable =
  30; 3 event-only stay as Index tiles. Starter popup Client/StarterPick + PickStarter (design doc 4.21; stats + name
  mapping PROPOSED, ask owner). Studio: run + mid-run Restyle OK, popup OK, previews OK; scenarios catalog, gacha,
  weather pass. Not done: rules-auditor sign-off, c3 rerun, other UiSpec contracts for the new gui, TeamHud portraits
  still placeholder heads (animerun-b7 is rebuilding the team row). Owner's Studio test save now has starter_leaf
  (a popup forced for the check was clicked). Studio worktree ../AnimeRun-orch/studio detached with these files copied in.
- 2026-11-03 painted-texture pilot (UNCOMMITTED, owner asked for the 3 starters first): tools/blender/paint/ (atlas.py,
  char_sea_captain, char_leaf_hero, char_db_hero), tools/blender/avatar_paint.py, avatar_merge atlas mode. Renders
  assets/characters_avatar/painted_pilot_{front,back}.png. NOT uploaded: the game still shows the pushed generated look.
  Next: owner verdict; then export + re-upload these 3 (delete their rows in avatar_assets.json first), then the other 27.
- 2026-11-03 uipolish (owner): rebirth now gives +5% cruise per level (placeholder, design doc 4.13 / 4.14, reverses "no speed gain"), speed tile shown on the Rebirth panel. Stamina bar: trail fix, rounded fills with no CanvasGroup, minimum size, `AlwaysOnTop` must stay off (bar does not draw with it). Team row: UiMotion, info card layout + screen clamp, badge pill. Commits on orch/core/uipolish (../AnimeRun-orch/uipolish), audit PASS, Studio desktop check OK; phone, reduced motion, badge pill, harness not run. NOT MERGED: the main checkout holds another session's uncommitted character-art work (overlap: GachaService, Phase2Tests, design doc). The place's saved StarterGui RacerRebirth has stale text; `RacerRebirth.luau` is generated (spec in ~/Documents/RobloxGames/ui) and hand-edited, so regenerating may undo the tile. Test runs banked money into the owner's Studio save (at least $66.5m, was $30.3m). Next: merge when clear, then c3.
- 2026-11-03 uipolish merged into feature/alex/anime-world. Team row rebuilt after the owner's reference: model heads (`HEAD_FIT`), arc of overlapping circles (`ARC_DOTS`, no image asset), server `RunSeconds<n>` on stamina runs only, potion expiry refreshes team numbers. Audit PASS; Studio desktop only. Not run: phone layout, reduced motion, full harness (c3 still open, its 2 UI failures unfixed; the team row layout changed since those rounds).
- 2026-11-03 a7 unique painted look (UNCOMMITTED, owner wants to see it first): all 30 have tools/blender/paint/char_<id>.py with
  own hair and atlas (series helpers <series>_common.py); contact sheet assets/characters_avatar/contact_sheet.png. Uploaded
  (avatar_assets.json + Shared/CharacterModelAssets regenerated; earlier rounds orphaned); server load check 30/30 with 6 parts and
  1 texture. CharacterModelAssets copied into ../AnimeRun-orch/studio for Rojo. NOT seen in game or in motion (Play was running,
  likely owner's). Open: concave `blade` outlines break the ink hull (black band, agents worked around it, not fixed); limb
  clipping of coats, capes, swords in motion untested; decisions for owner: jk_king bare chest, sea_cook no cigarette,
  sea_navigator crop top. Next: owner verdict, then commit + push, progress-tracker, then c3.
- 2026-11-03 collection cards (owner, design doc 4.22): Index and Backpack Characters share `Components.CardFace` (rarity tint + rim, Secret rainbow rim, head-anchored portrait, gold cruise, category badge). Backpack Characters: Sort (Rarity default / Speed / Stamina) and Search in the header, TEAM <n> or copies badge. Index gallery rebakes on `DesignVersion` 2, cell height 168 (UiResponsive updated), new `Odds` label, swaps placeholder rigs when `CharacterModels` is Ready (real models were never shown when the gallery built before they loaded). Slots row no longer overlaps the grid. Checked in Studio at 1271x605 only. Not run: UI harness, phone, gamepad, reduced motion. Owner: every droppable character has a number: catch-all Common Nammi is Chance 1 ("1 in 1", proposed), GachaConfig.Roll takes the last rollable without a draw; tests retargeted (nil -> 1), harness not run. Starters and Kami stay nil (never dropped). Files also copied into ../AnimeRun-orch/studio for Rojo.
- 2026-11-03 style2 pilot (UNCOMMITTED, owner approval pending; owner reference shots 3-4): leaf_medic, sea_captain, db_hero, leaf_hero rebuilt on tools/blender/paint/style2.py: layered 3D cloth, smooth hair mass, soft shading, plain limbs, small faces. Renders assets/characters_avatar/style2_pilot_{front,back}.png; uploaded (the other 26 stay on the a7 look). Old a7 scripts of these 4 backed up in ../AnimeRun-orch/art-backup/orig. If approved: design doc 5 "drawn clothing and muscle lines" must change, then 26 full char rewrites (125-180 lines each).
- 2026-11-03 style2 second pass (UNCOMMITTED): leaf_medic hair + band and all 4 faces redone in style2.py, re-uploaded. leaf_medic still reads hooded at 3/4 (owner to judge). Not seen in game.
- 2026-11-03 4-pilot redo from anime references (UNCOMMITTED, owner verdict pending; the other 26 wait): tools/blender/paint/char_{leaf_medic,sea_captain,db_hero,leaf_hero}.py rewritten by hand against wiki images (look-only, ../AnimeRun-orch/art-backup/anime_refs, never in the repo). Owner rejected slim limbs: true R15 blocks, likeness through hair, face, paint, thin clothes. Tris 8,856 / 11,548 / 7,504 / 7,640. NOT exported or uploaded: the game and the `.glb`s still show older looks. Anima: ComfyUI install was blocked by the auto-mode classifier; ../AnimeRun-orch/art-backup/anima/{setup.sh,refs.py} are for the owner to run. Backups of the earlier pass: art-backup/pass3, orig, orig2. Open: leaf_hero nape and long headband tails; docs/CHARACTER_ART_REFERENCES db_hero boot trim line is stale (red now); running animation and Studio unchecked; Face.taper draws nothing for vertical strokes. Next: owner verdict, then export + upload these 4 (delete their rows in avatar_assets.json first), then the other 26.
- 2026-11-03 later: owner gave a target image of the 4 pilots (../AnimeRun-orch/art-backup/anime_refs/owner_target.png, look-only) and chose "match it fully": no ink outline, soft 3D shading, big head, faceted hair, 3D clothes, block fists (design doc 5 + change log). tools/blender/paint/style3.py (big_head, finish); char_{sea_captain,db_hero,leaf_medic,leaf_hero}.py rewritten, plain block hands (owner); tris 8,156 / 4,226 / 6,464 / 6,610. Supersedes the entry above. Still UNCOMMITTED, not exported or uploaded. CHARACTER_GACHA_SPEC pipeline lines still describe outlines and cel bands: update on approval. Next: owner verdict; export + upload; then the other 26.
- 2026-11-03 skill: global ~/.claude/skills/design-roblox-anime-character. Evidence + validation for the 4 pilots: docs/CHARACTER_EVIDENCE_PILOTS.md. Downsize 0.8 (proposed) shown in Blender only: RunnerFactory rig offsets and HIP_HEIGHT are fixed, so the game side needs a uniform scale there when models are uploaded. Soles dip 0.10-0.22 studs under the feet line. Open owner questions: Lufy vest vs coat (mixed form); skill's IP boundary vs design doc 5.
- 2026-11-03 pilots in game: owner: vest stays, designs match the source, only the name differs (design doc 5). Uploaded sea_captain 92259398998895, db_hero 139186488737019, leaf_medic 99203486532029, leaf_hero 99496724338450 (tris 7,980 / 4,324 / 5,538 / 6,730); earlier uploads orphaned. RunnerFactory.SCALE 0.8 applies to every rig. Studio c2a3f28c: all 4 load, feet on the ground, one frozen run pose clean; files copied into ../AnimeRun-orch/studio for Rojo. Not run: real race, harness (c3 open), UI portraits at the new scale. Owner approved: audit, commit, then the other 26.
- 2026-11-03 ninja run (owner, design doc 4.23, commit c6cbdbf, not pushed): `RunStyle = "NinjaRun"` on leaf_hero and starter_leaf. Pose in Client/RunnerVisual (`poseNinja`), streaks and dust in Client/RunStyleFx on the drawn copy; `STRIDE` and `BOB` now follow RunnerFactory.SCALE for all runners. All values placeholders. NOT seen in a live run: only stills of a block stand-in in Edit, effect never seen, rebuilt leaf_hero model unchecked, `runner` scenario not run. Rojo 34873 (pid 68666) still served ../AnimeRun-orch/studio when last checked, so the owner must restart it from this checkout, Connect, Play with Narito or Karate Kid active. Copying files into that worktree was denied by auto mode. Next: owner verdict, then RunStyle on leaf_copycat, leaf_medic, leaf_crow, leaf_avenger (and update 4.23).
- 2026-11-03 pilots LANDED c26d9ae, pushed. Owner: commit, then HOLD the other 26. Rulings: hard facets everywhere, series initials allowed (design doc 5). Also fixed: Restyle honours ScaleTo (Best Roll rig was broken), Best Roll stats height 26, Market ribbon and emitter mounts scale. Unverified: Market effect rendering, real race, harness (c3 open); orbit, ring, box effect radii unscaled, cosmetic. Next: owner's go on the 26.
- 2026-11-03 ninja run on all Leaf (owner, design doc 4.23): `RunStyle = "NinjaRun"` added to leaf_copycat, leaf_medic, leaf_crow, leaf_avenger after the 26 models landed (7423686). Still NOT seen in a live run. Rojo 34873 now serves this checkout, started by the ninja-run session, and stops with it.
- 2026-11-03 all 30 models LIVE on the owner's account (owner approved the look as shown): 26 uploaded, avatar_assets.json + CharacterModelAssets regenerated, earlier uploads orphaned. Studio c2a3f28c: 30 of 30 load with 6 meshes, plaza lineup renders. Rojo 34873 now serves the main checkout. Not run: real race, harness (c3 open), animation clipping on capes, tails, panels. Known weak spots the owner accepted: db_green arm bands, db_tyrant head corners through the dome, jk_ row similar uniforms. Owner-accepted departures: sea_cook, sea_navigator, leaf_avenger, mha_blast, jk_king covered or no cigarette; sea_swords red sash from the old doc; leaf_crow dark eyes. Evidence docs: docs/CHARACTER_EVIDENCE_*.md, mostly inferred. Next: c3, then PR to main.
