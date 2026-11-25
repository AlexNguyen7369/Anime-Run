# Boss gate guide: spec (draft)

Relies on `docs/WORLD_REDESIGN_SPEC.md` 4.2 (owner 2026-11-25), design doc 4.37, 4.36, 4.20, 4.42, 4.46, 4.47 and section 5, and
`docs/BOSS_EVENT_SPEC.md`. Owner rules: Gojio (`jk_strongest`) stands at the boss gate; a player who walks up presses E to start a
conversation that gives info about the boss gate. The gate's spot and the fuller layout
are the owner's too. Owner 2026-11-25 "yes to all": the lines below and popup layout B are approved. Everything else here is **proposed**.

## Where he stands
- `Shared/BossGateConfig` is the one source (gate spot S4, approved by the owner 2026-11-25 with the fuller layout; moved 1.5 studs toward the spawn, **proposed**; guide offset 21 right and 6 toward the spawn, his
  prompt's reach 8). He faces the spawn beside the gate, outside its 35.3-stud frame, on the side away from the Team altar, which moves to (-35.0, 76.4).
- Static model, no collision, name label. World 2 loads his model because the rig wears it (4.47 "Models").
- Off in the game: the gate stand-in is in the code behind `BossGateConfig.LIVE` and he behind `BossGuideConfig.LIVE`, both false until
  the lead turns them on. He is built only while both are true; with the gate off, nothing of the gate is built either.

## How it shows
- One ProximityPrompt `TalkBossGuide`: E, "Talk", "Gojio", `HoldDuration` 0 like every plaza prompt, 8 studs, gamepad X and touch by the
  engine's default. On whether the gate is open or closed. `OnePerButton`: the engine shows one E prompt at a time. His prompt
  and the gate's are 21.4 studs apart, more than their reaches together (8 + 10).
- The prompt opens one handscroll (4.46), the game's popup style: his portrait, one line, Next (Done on the last), the page count in the footer.
  Closed by Done, its X, a click outside, gamepad B or Escape. A press while it is open does nothing.
- It is a `PanelSwitch` panel: one at a time with every panel, gamepad focus on Next. A teleport into the event closes it. Text is set when
  it opens; an event starting meanwhile shows on the next talk.
- Text only: no remote, nothing granted, no boss rule, timing or reward touched.
- Layout B (owner 2026-11-25; `Shared/BossGuideLayout`, mock-ups `layout_b_*.jpg`): the handscroll, header, seal close and footer stay; frame 520 units
  tall instead of 620 (`IndexFrame` H), content from 120 instead of 164 (`IndexFrame` Top), no tabs row; the portrait in a framed art card as tall as the content,
  the line on a paper slip at 48 units (text role `Speech`), Next inside the slip at the right. Phones keep their frame (650 x 420, content from 144), with a 110 unit
  portrait card, no slip, the line at 34 units and Next centred below. Title kanji 案内 and sub line "Boss gate guide" (dropped where they do not fit, as in every header).
- Text fit, worked out from the real font file (Kalam Bold), not measured in Roblox: the line is 33 px on desktop, at most 3 lines; 22 px at 667 x 375 and 19 px at
  568 x 320, at most 4 lines. If Roblox draws the font at a full em, the longest line shrinks to 14 and 11 px on those phones.
- Next draws 24 to 31 px tall, so it and the X take a 44 px hit area on touch (`Client/TouchTarget`).
- Mock-ups, drawn in Blender, not game captures: `assets/ui/boss_guide_draft` (all eight lines on desktop, the longest on two phones; layout A was not chosen).

## Below rebirth 1
Open question: the Join, Rewards and When pages still name the popup and the open gate to a player who sees neither.
The Bosses button is hidden (4.36) and the gate stays closed (4.2, proposed). He still talks; only the last line differs.

## Lines
Approved (owner 2026-11-25). Numbers come from `BossEventConfig` and `SidekickConfig`; the 30 minutes and 5% are owner rules. No odds, prices or placeholder numbers.

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

Left out on purpose (the approved lines name neither): Money and Gems (amounts and which boss pays what are part **proposed**), the paid spawn, how long an event lasts.

## Open questions (owner)
- The talk below rebirth 1 (above).

## Tests
ServerTest `boss_guide` (`BossGuideTests`); UI `ui_boss_guide`, clicks `boss_guide_close` and `boss_guide_next` (`UiBossGuide`).
