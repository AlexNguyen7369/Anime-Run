# Nightly report

## Nightly run 2026-11-17 → 01:21

### Blocked (needs you)
- Studio verify of the new pages: stopped before any Studio run. Question: will you connect the Rojo plugin to port 34874 (it serves `../AnimeRun-orch/dojo-pages`), or tell me when the power-up session has committed so its checkout can be switched? Studio's Rojo on 34873 serves the main checkout, which holds another session's uncommitted power-up files. My attempt to copy this branch's files into that checkout was refused by the permission classifier. One TeamHud patch had already applied there; I reverted it, and that checkout is back to its prior state. State: branch `feature/alex/dojo-pages` pushed, draft PR #21. Left to do: scenarios `team`, `ui_team`, `ui_entry_points`, `ui_sidekicks`, `ui_panels`, `ui_hud`, `spawn_area`, `sidekicks` (plus the rename's `runner`, `race`, `duel`, `runner_effects`, `data`, `gacha`), Flow A and Flow B live, captures for you.
- Owner calls (logged as open, code unchanged):
  - Should opening another panel over Team Setup ask Deploy/Discard first? Today it discards the draft silently, and the saved Team is kept.
  - Do characters need a level? None exists, so the altars show rarity and cruise.

### Done
- **Rules first.** Design doc 4.45, TEAM_AND_STAMINA_SPEC "Team Setup page", SIDEKICK_SPEC "Sakura Dojo entry and transition", UI_FEEDBACK_SPEC section 5, and the WORLD_REDESIGN_SPEC ring, all from your 2026-11-17 brief and answers. Commits b9edeab, 0d53f97.
- **Team Setup page.**
  - Three octagonal altars in ViewportFrames, built by a new `SpawnArea.Octagon`.
  - A draft you can place into, swap and remove, with Quick Setup (server `TeamQuickPick`) and Deploy (`SetTeam`).
  - Deploy/Discard on close, a Team Bonus popover, and a Characters/Sidekicks tray (Sidekick equip through `SidekickEquip`).
  - Relic diamonds and Sidekick circles with tooltips.
  - Commits 1267f95, fa0d6eb.
- **Entry points.**
  - Summon button in the right column (key G).
  - The minibar opens Team.
  - A plaza `TeamAltar` at (-3.1, 83.9) with the prompt "Team".
  - The Sidekick altar prompt now says "Summon".
- **Shared layer and summon effect.**
  - `UiTransition` (paper and petals), `InputLock`, `UiTooltip`.
  - In `PanelSwitch`: the accent, a close guard, `ForceClose`, and ButtonB now goes through Close.
  - `SummonAltarFx` plays a rarity ring, beam and flash before the reveal.
- **Tests.** Written red first by a test agent: `ui_team`, `ui_entry_points`, `team_quick_pick_*`, `TeamAltar` in the spawn ring. Commits 1ff09dd, d5d6e7b and the follow-up commit.
- **Review.** A fresh reviewer found 22 issues and I fixed the code ones. They included:
  - the altar deselecting after a placement;
  - draft gaps breaking `table.find`;
  - gear icons that were not ImageLabels;
  - transition and tooltip GUIs built late;
  - the delayed close from an earlier open;
  - the roster rebuilding on every tap;
  - phone tray overlaps.
- **Checks.** stylua clean, selene 0 errors (22 warnings, same as main), `rojo build` OK. Not run in Studio.
- **Bookkeeping.** handoff.md, current_progress.md (entry 197), draft PR https://github.com/AlexNguyen7369/Anime-Run/pull/21.

### Decisions I made for you
- **Summon backdrop.** You picked "Sakura Dojo". Main already had your approved blossom-shrine backdrop (844aa92, 2026-11-14), so I kept it and built no new stage. Revert: n/a.
- **Rename merged into this branch.** `feature/alex/car-vocab-refactor` (4554c9d, local, not on main) is merged so the tree matches what Studio runs. PR #21 shows that rename until it lands. Revert: rebase PR #21 onto main after the rename merges.
- **Summon icon.** It uses the existing Gem icon; uploading a new icon needs your word. Revert: change `HudIcons.Summon`.
- **Altars use no uploaded art.** I built them as live 3D octagons in ViewportFrames, which needs no upload. Revert: swap them for sprites after you approve art.
- **Relics are inspect-only on Team Setup.** Equipping relics stays in Items, as the approved walkthrough says.
- **Quick Setup pool.** It includes the starter and starter picks (every owned character, as the Team roster lists them), not only Index characters.
- **Double-press guard.** It only applies while the transition is playing, so fast test clicks still toggle.
- **Movement lock.** It uses PlayerModule `Controls:Disable()` (input only, so runs keep going). I did not swap SidekickUi's own WalkSpeed freeze.

### Skipped
- A floating header over the Team altar, and a world header rule: not in the brief's acceptance list.
- Real phone and controller hardware checks: no device available.
