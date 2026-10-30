# Bugs

Format: name | kind (fault/failure) | file:line | found-by | summary

- ui-layout-phone-overlaps | failure | src/client/UiTest (ui_layout) | w1 implementer, 2026-10-30 | ~45 ui_layout checks red: phone-landscape HudChrome ItemsSlot/UpgradeSlot overlap every modal; RacerHud speed text over Upgrades nodes; Settings Title over ProfileTab; Backpack CharactersTab outside small-landscape viewport; hud_pair rect/beside-bars/unshrunk checks. Not yet known whether these fail before w1 (no pre-w1 UI baseline).
- ui-reduced-motion-reveal | failure | ui_reduced_motion | w1 implementer, 2026-10-30 | reduced_reveal_at_normal_time 1.201 s, limit 1.10 +- 0.10 s.
- ui-theme-welcome-font | failure | ui_theme | w1 implementer, 2026-10-30 | theme_fonts_fredoka: RacerWelcome/Panel/Title uses Bangers.
- ui-roll-serial | failure | ui_roll_anim | w1 implementer, 2026-10-30 | roll_serial_counts_roll_results: compact roll/serial counts drift (roll 98 serial 98 after roll 97 serial 96).
- ui-shop-featured | failure | ui_shop | w1 implementer, 2026-10-30 | shop_sections_present: Featured has 0 direct children of Items, want 1.
- ui-full-run-missing-states | fault | src/client/UiTest | w1 implementer, 2026-10-30 | A full UI run does not set up auto_racing, lose_event or emphasized_next, so ui_runner_smooth, ui_camera_follows_runner, ui_loser and ui_roll_emphasized report state_missing; each passes once its UiTestSetup state is set.
- internal-car-names | fault | src/shared/SpawnArea.luau:374,406; src/client/ProgressionUi.client.luau:437; src/client/RollToast/RacerUiController.luau:297 | w1 implementer, 2026-10-30 | Internal instance names still say car (CarMount, billboard label Car, row prefix Car_, CarsDiscovered). Not player-facing text; saved key Cars and CarService are out of w1 scope.
