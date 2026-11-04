# Roll animation

Owner 2026-11-04. Design doc 4.31 is the rule; this page holds the detail. Display only: the server decides every roll, and the client never changes a result. All values marked placeholder are tunable.

## Accuracy
- The landed result always shows the rolled character's own drawn portrait, or its own model from `RunnerFactory.build(spec.Id)` while it has no portrait. `spec.Model = nil` means "wears its own model", as in `RunnerFactory`. It does not mean "no model". The "?" shows only when `RunnerFactory.HasModel(spec.Id)` is false, which no rollable character is.
- Every shown frame of the cycle and the landed result use the same view rectangle, camera framing and lighting, so nothing jumps or changes colour on landing.
- The name, odds and rarity shown always belong to the character shown.
- **Bust framing (owner 2026-11-04)**: every roll view, in the cycle, the landing and the fly icon, shows the character's drawn portrait (CHARACTER_GACHA_SPEC "Digital art portrait"): head to upper torso. Until a character's portrait is in `CharacterPortraits`, the live model is framed the same way, with a short soft fade at the bottom edge.
- The body attribute `ShownId` holds the character on screen in every phase after PopIn. It equals the server's result from Land onward.

## Phases (names unchanged: PopIn, Spin, Land, Hold, Exit)
Base times in seconds (placeholders): POP 0.12, SPIN 1.5, LAND 0.2, EXIT 0.2, SWITCH 0.3.
HOLD (placeholders): Common 0.5, Uncommon 0.5, Rare 0.6, Epic 0.75, Legendary 1.5, Mythic 2.5, Secret 4.

- **Fit to the roll interval**: `TimeScale(interval) = min(1, interval / FIT_INTERVAL)`, with `FIT_INTERVAL` 2.8 (placeholder). It multiplies POP, SPIN, LAND, HOLD and EXIT; SWITCH is not scaled. Non-emphasized Common to Epic therefore finish inside the player's roll interval at every Roll Speed tier (3 s down to 2 s), so roll rate and upgrades do not change for them. An emphasized roll adds 2 x SWITCH, and a longer roll (for example Legendary, 0.52 s at 3 s) waits that much more before the next roll.
- The server sends the player's interval as a new last argument of `RollResult`, and uses the same interval in `RollAnimConfig.Duration` and `ExtraPause`. With no interval given, the base `ROLL_INTERVAL` applies.
- **PopIn**: the figure area scales in with Back easing.
- **Spin**: characters swap in place in one fixed centre spot. Each swap pops (scale about 0.85 to 1, Back easing) and is fully framed and visible at rest. Swaps slow down: each slot lasts longer than the one before it, and the filler slots sum to SPIN. A TURBO badge shows from PopIn. Odds show "?" and the name shows "???" until Land; all other result text waits for Land. No sliding, no edge fade, no speed streaks.
- **Land**: the result pops in with a larger pop (`LAND_POP`), then the odds and name appear. A thin rarity-coloured ring spreads behind it (`LandWave`, replacing the old smoke puffs).
- **Hold**: the result stays still and readable, with rarity effects.
- **Exit**: the figure shrinks and a small icon of the rolled character flies to the Index button.
- Under reduced motion (`UiMotion.Reduced()`): no swap pops, shake, pulses or loops. The cycle does not swap and the result appears at the end of Spin, keeping the same phase timing.

## Cycle characters
- `REEL_CARS` 16 slots (placeholder, owner 2026-11-04: triple the earlier 6): 15 fillers shown during Spin, then the server's result, shown at Land. Slots run from about 0.04 s to about 0.2 s (`SLOT_GROWTH` 1.12, placeholder).
- Each filler starts as a real roll at luck 1. A draw equal to the previous slot, or the last filler equal to the result, is redrawn from Common and Uncommon only, weighted by their odds (owner 2026-11-04). The catch-all takes about 81 % of luck-1 rolls, so this keeps the cycle visible, and Rare and above never appear above their true odds as a fake near-miss.

## Views
- **Normal roll (top centre, no card)**: bare figure, odds, name and the landing ring at the very top centre of the screen (`COMPACT_TOP` 8 px, placeholder; owner 2026-11-04), above the world view rather than over the player. If the top-right row would overlap it (small phones), it sits just under that row. Figure height 110 px (placeholder, owner 2026-11-04: smaller), capped at 30 % of screen height on small screens. It still hides while a panel is open (design doc 4.20 rulings stay), and a click still opens the enlarged view.
- **Emphasized roll (screen centre)**: `GachaConfig.IsEmphasized`, unchanged. Dim and blur stay. No visible card body: large figure, gradient odds above it, outlined name below it, a rarity-coloured crystal shape behind it, smaller rarity and cruise text, and NEW, +1 COPY and TURBO badges. "Tap anywhere to close" and the AUTO toggle stay.
- The odds gradient colours come from the rarity; Secret and Mythic use a slowly moving multi-colour gradient. The crystal is built from our own rotated frames and gradients, with no uploaded or copied art.
- Secret takeover stays, and tap to skip stays. Its dark screen and title last about 1 s (placeholder), then clear so the figure shows for the rest of the hold; the rainbow border stays.

## Performance
- No hitch at Spin start: rigs are built before they are shown, reused between rolls, and only the visible view draws the cycle. Viewports that are not visible do not rebuild rigs.
- Character meshes are preloaded before their first frame, so a frame never shows an empty or untextured figure.

## Technique
- Every tween goes through `Client/UiMotion` (design doc 4.20). No new dependency. Twinkle and Xocoatl are not used in game (owner 2026-11-04).
- The references (owner's images of other games) guide layout only; no art, names or look from them are copied (design doc 5).

## Auto toggle (owner 2026-11-04)
- The top-centre Auto Race button moves to the top-right row as a pill immediately left of Daily, with the same pill shape and height, labelled "Auto". `HudChrome/TopRight/Auto`.
- It is a toggle: green while auto race is on, the dark pill colour while off, greyed for the 1 s pending lock. The label stays "Auto" in every state. It only asks: the server decides (`Remotes.SetAutoRace`), and its state follows the `AutoRacing` attribute.
- The old `RacerHud/Race` stays hidden as the layout anchor that `PanelBand` reads, so panel bands do not move.

## Quests button (owner 2026-11-04)
- Quests leaves the top-right row and becomes an icon button directly above Shop (`HudChrome/ShopColumn/Quests`), same tile as Shop, opening the same panel. The top-right row is Auto, Daily, Market, Settings.
