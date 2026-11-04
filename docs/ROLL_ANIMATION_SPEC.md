# Roll animation

Owner 2026-11-04. Design doc 4.31 is the rule; this page holds the detail. Display only: the server decides every roll, and the client never changes a result. All values marked placeholder are tunable.

## Accuracy
- The landed result always shows the rolled character's own model, drawn by `RunnerFactory.build(spec.Id)`. `spec.Model = nil` means "wears its own model", as in `RunnerFactory`. It does not mean "no model". The "?" shows only when `RunnerFactory.HasModel(spec.Id)` is false, which no rollable character is.
- Every shown frame of the cycle and the landed result use the same view rectangle, camera framing and lighting, so nothing jumps or changes colour on landing.
- The name, odds and rarity shown always belong to the character shown.
- The whole figure fits the view: hair, weapons and capes are not cut off.
- The body attribute `ShownId` holds the character on screen in every phase after PopIn. It equals the server's result from Land onward.

## Phases (names unchanged: PopIn, Spin, Land, Hold, Exit)
Base times in seconds (placeholders): POP 0.12, SPIN 1.5, LAND 0.2, EXIT 0.2, SWITCH 0.3.
HOLD (placeholders): Common 0.5, Uncommon 0.5, Rare 0.6, Epic 0.75, Legendary 1.5, Mythic 2.5, Secret 4.

- **Fit to the roll interval**: `TimeScale(interval) = min(1, interval / FIT_INTERVAL)`, with `FIT_INTERVAL` 2.8 (placeholder). It multiplies POP, SPIN, LAND, HOLD and EXIT; SWITCH is not scaled. Non-emphasized Common to Epic therefore finish inside the player's roll interval at every Roll Speed tier (3 s down to 2 s), so roll rate and upgrades do not change for them. An emphasized roll adds 2 x SWITCH, and a longer roll (for example Legendary, 0.52 s at 3 s) waits that much more before the next roll.
- The server sends the player's interval as a new last argument of `RollResult`, and uses the same interval in `RollAnimConfig.Duration` and `ExtraPause`. With no interval given, the base `ROLL_INTERVAL` applies.
- **PopIn**: the figure area scales in with Back easing.
- **Spin**: characters swap in place in one fixed centre spot. Each swap pops (scale about 0.85 to 1, Back easing) and is fully framed and visible at rest. Swaps slow down: each slot lasts longer than the one before it, and the 5 filler slots sum to SPIN. A TURBO badge shows from PopIn; all other result text waits for Land. No sliding, no edge fade, no speed streaks.
- **Land**: the result pops in with a larger pop (`LAND_POP`), then the odds and name appear.
- **Hold**: the result stays still and readable, with rarity effects.
- **Exit**: the figure shrinks and a small icon of the rolled character flies to the Index button.
- Under reduced motion (`UiMotion.Reduced()`): no swap pops, shake, pulses or loops. The cycle does not swap and the result appears at the end of Spin, keeping the same phase timing.

## Cycle characters
- `REEL_CARS` 6 slots (placeholder): 5 fillers shown during Spin, then the server's result, shown at Land.
- Fillers are real rolls at luck 1, so a rare character is never planted as a fake near-miss.
- A draw equal to the previous slot is drawn again, and the last filler also differs from the result (orchestrator default, owner to confirm): the catch-all takes about 81 % of luck-1 rolls, so plain draws would mostly show one character and no visible cycling.

## Views
- **Normal roll (top centre, no card)**: bare figure, odds and name in the existing Toast place under the Auto Race button. Figure height 180 px (placeholder), capped at 30 % of screen height on small screens. It still hides while a panel is open (design doc 4.20 rulings stay), and a click still opens the enlarged view.
- **Emphasized roll (screen centre)**: `GachaConfig.IsEmphasized`, unchanged. Dim and blur stay. No visible card body: large figure, gradient odds above it, outlined name below it, a rarity-coloured crystal shape behind it, smaller rarity and cruise text, and NEW, +1 COPY and TURBO badges. "Tap anywhere to close" and the AUTO toggle stay.
- The odds gradient colours come from the rarity; Secret and Mythic use a slowly moving multi-colour gradient. The crystal is built from our own rotated frames and gradients, with no uploaded or copied art.
- Secret takeover stays, and tap to skip stays.

## Performance
- No hitch at Spin start: rigs are built before they are shown, reused between rolls, and only the visible view draws the cycle. Viewports that are not visible do not rebuild rigs.
- Character meshes are preloaded before their first frame, so a frame never shows an empty or untextured figure.

## Technique
- Every tween goes through `Client/UiMotion` (design doc 4.20). No new dependency. Twinkle and Xocoatl are not used in game (owner 2026-11-04).
- The references (owner's images of other games) guide layout only; no art, names or look from them are copied (design doc 5).
