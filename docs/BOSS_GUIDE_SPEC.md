# Boss gate guide: spec (draft)

Relies on `docs/WORLD_REDESIGN_SPEC.md` 4.2 (owner 2026-11-25), design doc 4.37, 4.36, 4.20, 4.42, 4.46, 4.47 and section 5, and
`docs/BOSS_EVENT_SPEC.md`. Owner rules: Gojio (`jk_strongest`) stands at the boss gate; a player who walks up presses E to start a
conversation that gives info about the boss gate. Everything else here is **proposed**.

## Where he stands
- One value, `Shared/BossGuideConfig.GATE_POS`, the gate's world (x, z): (2.5, 94.8), draft spot S4, not chosen by the owner yet.
- He stands 21 studs to the gate's right and 6 toward the spawn (`OFFSET`), facing the spawn: about (23.3, 88.2). The draft gate is 35.3
  wide, so he is outside its frame, on the side away from the Team altar.
- Static model, no collision, name label. World 2 loads his model because the rig wears it (4.47 "Models").
- The gate itself is not built here. At S4 the draft gate overlaps today's Team altar (-3.1, 83.9), which only the fuller layout moves.
- Off in the game (`BossGuideConfig.LIVE` = false) until the gate is built and the owner picks its spot: his lines speak of the gate.

## How it shows
- One ProximityPrompt `TalkBossGuide`: E, "Talk", "Gojio", `HoldDuration` 0 like every plaza prompt, 8 studs, gamepad X and touch by the
  engine's default. On whether the gate is open or closed. `OnePerButton`: the engine shows one E prompt at a time. He is 21.8 studs
  from the gate's centre, so keep the gate's prompt range under 13.8 or the two ranges overlap.
- The prompt opens one handscroll (4.46), the game's popup style: his portrait, one line, Next (Done on the last), the page count in the footer.
  Closed by Done, its X, a click outside, gamepad B or Escape. A press while it is open does nothing.
- It is a `PanelSwitch` panel: one at a time with every panel, gamepad focus on Next. A teleport into the event closes it. Text is set when
  it opens; an event starting meanwhile shows on the next talk.
- Text only: no remote, nothing granted, no boss rule, timing or reward touched.

- Text fit, worked out from the real font file (Kalam Bold), not measured in Roblox: the line is 24 px in a 527 x 221 px box at 1024 x 768 and up, at
  most 2 lines; 22 px at 667 x 375 and 19 px at 568 x 320, at most 4 lines. If Roblox draws the font at a full em, the longest line shrinks to 14 and 11 px on those phones.
- Next draws 24 to 31 px tall, so it and the X take a 44 px hit area on touch (`Client/TouchTarget`).
- Mock-up, drawn in Blender, not a game capture: `assets/ui/boss_guide_draft` (all eight lines on desktop, the longest on two phones).

## Below rebirth 1
Open question: the Join, Rewards and When pages still name the popup and the open gate to a player who sees neither.
The Bosses button is hidden (4.36) and the gate stays closed (4.2, proposed). He still talks; only the last line differs.

## Lines
Numbers come from `BossEventConfig` and `SidekickConfig`; the 30 minutes and 5% are owner rules. No odds, prices or placeholder numbers.

| Page | Line |
|---|---|
| Intro | I'm Gojio. Curious about the boss gate? I'll keep it short. |
| What | A boss is one huge enemy for the whole server. Your runners circle it while their Sidekicks attack. |
| When | A boss event starts every 30 minutes, with one boss picked at random. The gate is open while one runs. |
| Join | To join, press Go on the live boss in the Bosses popup before teleporting closes. You need a character wearing a Sidekick. |
| Rewards | Only a defeat pays, if you dealt at least 5% of that phase's HP. A chest holds one Relic and a tiny chance of the boss's Sidekick. Odds are in Details. |
| Gate, closed | The gate is closed for now. The Bosses popup shows the time to the next event. |
| Gate, open | The gate is open: a boss event is running. Walk up to the gate, or press Bosses. |
| Gate, below rebirth 1 | The Bosses button shows from Rebirth 1, and Sidekicks unlock at Rebirth 2. Come back then. |

Left out on purpose: Money and Gems (amounts and which boss pays what are part **proposed**), the paid spawn, how long an event lasts.

## Tests
ServerTest `boss_guide` (`BossGuideTests`); UI `ui_boss_guide`, clicks `boss_guide_close` and `boss_guide_next` (`UiBossGuide`).
