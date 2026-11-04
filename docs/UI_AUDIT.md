# UI audit (goal ui-juice, u0)

Date 2026-11-04. Branch code at 2a8f08e, checked current in Studio Edit (`MarketUi` Source has market copies, same length as the file).
Test save `uiaudit1`. Desktop view 1271 x 601 logical px. Paths are relative to `src/client` unless they start with `src/`.
"Seen" means in a live capture or a measured Play state. "Inferred" means from code only.

How moments were driven:
- Panels, purchases, Rebirth, Daily and Quest claims, the run, the Team row: real mouse clicks.
- VS, DEFEATED, loser recap, emphasized Mythic and Secret: the real client code, driven by firing `NpcRace` / `RollResult` from the server, because a capture takes longer than these moments last. VS, DEFEATED and the loser recap were held on screen by a temporary script, so their layout was seen, not their timing.

## Findings

| id | surface | what is wrong | seen / inferred | sev | file:line | fix |
|---|---|---|---|---|---|---|
| A1 | Rebirth | One tap took $500m to $0: no confirm, no celebration in the capture. Rewards silently change to the next tier. The biggest moment in the game feels like a form submit. | seen | high | `RollToast/RacerUiController.luau:489` | Add a second step (owner ruling, it is flow), then a full-screen Slam + Burst + Boom. |
| A2 | Market | Buying the first copy moves BUY up and adds SLOT buttons. The cursor that pressed BUY now sits on SLOT 2, so a double tap equips by accident. | seen (geometry); the double tap itself inferred | high | `MarketUi.client.luau:400` | Reserve the slot band before the first buy, so BUY never moves. |
| A3 | Roll / panels | An emphasized roll closes Index, Stats, Settings and Rebirth. Every new character in a fresh save's first 5 discoveries is emphasized, so these panels get closed mid-use. Shop, Market, Backpack, Daily and Quests stay open behind the dim. Index vanished once in my session, but stray clicks were also landing then (see Not checked). | inferred; seen once, unproven | high | `RollToast/init.client.luau:929-932`, `:1141`, `src/shared/GachaConfig.luau:82` | Hold the emphasized view until the panel closes, or use the compact roll (owner ruling, roll spec). |
| A4 | Upgrades | Detail card is unreadable: navy text with a navy stroke, heavy at this size, on a white plate ("SELECT AN UPGRADE", "+10% Money"). | seen | high | `RollToast/Ui/UpgradeTreeView.luau` | Dark text, no stroke; or a dark plate with white text. |
| A5 | Upgrades | HUD bleeds through. `$500m` prints over the Turbo bar ("TUR$500m3/10"), zoom +/- sit on the Stats tile, EXIT sits on Rebirth, hexes cover the Team row, title collides with a hex. | seen | high | `ProgressionUi.client.luau:281`, `RollToast/Ui/UpgradeTreeView.luau` | Hide HudChrome and RacerHud while the tree is open; keep one money read-out placed clear of the hexes. |
| A6 | Daily, Quests | Status text is never cleared. "Claimed Day 1" stayed for the rest of the session (over 2 min, through a run and under the roll blur). 13 px, no plate, no stroke, next to the weather tile. | seen, code agrees | high | `BoostDailyUi.client.luau:227`, `:241-245` | Fade after 2 s; move it inside the panel and on to the shared toast. |
| A7 | HUD, Quests | No badge on Quests with 2 CLAIMs ready. Daily, Stats and Upgrade have one; claimable quests are invisible from the HUD. | seen, code agrees | high | `HudChrome.client.luau:338-339` | Add a claimable count badge to the Quests tile. |
| A8 | Daily, Quests | CLAIM labels are pale on green with no stroke, the lowest contrast on the most wanted button. | seen | med | `BoostDailyUi.client.luau:449`, `:573` | White text + `UiTheme.Stroke`, same as BUY. |
| A9 | Shop | Every price button is bright green and reads as buyable, but says "Coming soon" and a press does nothing. Pale Gift buttons are also dead. | seen; no-prompt from code comment | med | `ShopUi.client.luau:176`, `:204` | Grey the button while id is 0; give a Denied cue on press. |
| A10 | Shop | Price row cuts off the bottom of potion art. Body is light lilac and pastel, the only light panel. Stroked 13 px captions fill in ("VIP title,perks..."). 1816 px of content in a 262 px window, so 3 cards at a time; no section jump. | seen | med | `ShopUi.client.luau:29` onward | Move art up or shrink it; dark body as other panels; drop strokes under 16 px; add section tabs. |
| A11 | Daily | Day 7, the top prize, opens clipped by the panel edge and Days 4-6 are cut. No highlight on today's tile. | seen | med | `BoostDailyUi.client.luau:446-453` | Fit 7 days without scroll on desktop; mark today with `UiMotion.Mark` and Pulse. |
| A12 | Backpack | Slot row covers the grid: 1.3 rows of tiles show, second row cut. Slot row is left-aligned and shorter than the grid. Team members are not pinned first. | seen | med | `BackpackUi.client.luau:221`, `SlotPicker.luau:82` | Grid ends above the slots, slots span the grid width, Team first. |
| A13 | Backpack | Opens on Misc, usually empty, with no route to fill it. Characters is the common job and needs a second tap. | seen | med | `BackpackUi.client.luau:483` | Open on Characters; add a Daily or Market button to the empty state. |
| A14 | Index | Team members still show green EQUIP (Nammi, Sanjy were in Team). Only `EquippedCar` counts. Pressing EQUIP looks like it replaces a Team member; not confirmed. | seen; effect inferred | med | `RollToast/RacerUiController.luau:640-641`, `:656` | Show "IN TEAM" for all 3 slots, or send equip to the Backpack slot picker. |
| A15 | Enemies page | Still shows "7 / 47 DISCOVERED · NEXT POINT IN 2", the character count. Locked tiles show a small "?" high in the tile with no track number. Active tab is the same cyan as its bar. | seen | med | `RollToast/RacerUiController.luau:646`, `RollToast/Ui/InventoryTabs.luau:17` | "n / 10 DEFEATED"; show "TRACK n" on locked tiles; active tab white. |
| A16 | VS, DEFEATED | Flat for the moment it marks. Same plate for both, DEFEATED keeps the red edge, right third is empty, plate crosses the runner's feet, title is 24 px, the smallest line but one. | seen | med | `EnemyShowdown.client.luau:19-21`, `:77-84`, `:145-146` | Slam, large title; green edge and greyed portrait on DEFEATED; shrink plate to its content. Must stay non-blocking (4.28). |
| A17 | VS, loser, map | One track, two names: "Leafwind Village" on VS, "OVAL" on the loser card and map. | seen | med | `EnemyShowdown.client.luau:30`, `NpcRacerView.client.luau:284` | Use the BiomeThemes name everywhere. |
| A18 | Market | BUY is full green at $11 against a $500 price. Answer appears at the far bottom-left, away from BUY. "SLOT 1 - / -" is cryptic. "x1.09 cruise for its slot" is jargon. Text says "your ride", an IVS leftover. Preview is a tiny smudge in a large dark box. | seen | med | `MarketUi.client.luau:262`, `:290-295`, `:489` | Grey BUY when short (server still decides), reply under BUY, plain words, larger preview. |
| A19 | Auto | Auto goes back off when the team is exhausted, with no message; the pill just turns dark. An idle game then needs a tap per run. Intent unclear. | seen, code agrees | med | `src/server/RaceService.luau:632` | Owner ruling; if it stays, add "Auto stopped" to the exhausted toast. |
| A20 | HUD in run | Race map sits on the Quests tile; "PB --" hides under its label. TIME, PAINE, YOU are about 10 px over bright world. Track title is detached from the map. | seen | med | `RaceProgressMap.luau:351-363` | Move the map or tile; put a plate behind map text. |
| A21 | Turbo | "TURBO x10!" shows on an empty grey bar: the fill reset while the label celebrates. Only a label Pop and a Shine on an empty fill. | seen | med | `RollToast/RacerUiController.luau:759-763` | Hold the fill full during the 1.2 s; gold pulse + Fill. |
| A22 | Secret | Rainbow border is not visible: a `UIStroke` on a full-screen frame draws outside the screen (spec says it stays). Title sits on the figure; italic "Gojio" reads badly. | seen; cause inferred | med | `RollToast/init.client.luau:549-558` | Inset the frame by the stroke width; move the title clear of the figure. |
| A23 | Top-right pills | Pills are translucent, and the world signs behind (MARKET, UPGRADE) use the same look, so they read as HUD. Daily's countdown widens its pill and pushes Auto left. | seen | low | `HudChrome.client.luau:214-215` | Lower pill transparency; fixed Daily width. |
| A24 | Settings | Fourth header style: grey band, tabs touching the close button, tiny "PLAYER PROFILE". Empty band under the rows. Red OFF on Reduced Effects reads as an error. | seen | low | `RollToast/RacerUiController.luau:224-270`, `:295-314` | Use the PanelFrame header; muted OFF; gap before close. |
| A25 | Rebirth | "REWARDS UNLOCKED" lists next rewards, not unlocked ones. Title centred on the bar minus close, not on the panel. "REQUIREMENTS" centred on the bar only. | seen | low | `RollToast/RacerUiController.luau:465-487` | "NEXT REBIRTH"; centre on the panel. |
| A26 | Quests | Raw ids in rewards: `SpeedI` and `LuckI` read as "Speedl", "Luckl". Detail repeats the title as its goal. | seen | low | `BoostDailyUi.client.luau:497-504` | Display names ("Speed Potion I"); drop the repeat. |
| A27 | Roll | "1 in 1qd" and "360 studs/s" mean little to a player; Rarity is smaller than its stat. Otherwise the emphasized view reads well. | seen | low | `RollToast/init.client.luau:888-893` | Bigger rarity word; spell large odds out on Mythic and Secret. |
| A28 | Panels | 4.20 asks fade in on open; only scale runs. | inferred | low | `PanelSwitch.luau:198` | Add fade, or owner drops it from 4.20. |
| A29 | Panels | Racer panels with a layout UIScale slide on open and close at once; others scale both ways. Two motions for one action. | inferred | low | `PanelSwitch.luau:188-191`, `:216-218` | Same preset for all panels. |
| A30 | Panels | Close on outside click only on Shop and Market. Others need X. Upgrades has both X and EXIT. | inferred (from `CloseOnOutsideClick` callers) | low | `PanelFrame.luau:120`, `ShopUi.client.luau:585`, `MarketUi.client.luau:603`, `ProgressionUi.client.luau:284` | Attach for all panels; drop EXIT. |
| A31 | Bars, toggles | Snaps: Rebirth fill, Quest fill, Settings knob. | inferred | low | `RollToast/RacerUiController.luau:483`, `BoostDailyUi.client.luau:497`, `RollToast/RacerUiController.luau:254` | `Fill` for bars, `UiMotion.Mark` for the knob. |
| A32 | Starter pick | Cards are plain: unstroked title, no pick motion on the card, CHOOSE is a different green. First impression is flatter than the art deserves. | seen; no card motion inferred | low | `StarterPick.client.luau:137`, `:148` | Slam on the chosen card; UiTheme button. |
| A33 | Phone, Backpack | Solver: Title rect crosses Sort at 844 x 390 and 667 x 375. Same rect red at all 5 larger sizes; the desktop capture shows no visible overlap, so it may be rect size only. | solver, not seen | low | `BackpackUi.client.luau:107` | Size the title to its text. |
| A34 | Phone, Market | Solver: Status text crosses the first grid tile at both phone sizes. | solver, not seen | med | `MarketUi.client.luau:290` | Same fix as A18: reply under BUY. |

Known items checked:
- Confirmed: three outline colours; `fromRGB` counts in Shop (29) and BoostDaily (28); `TeamHud` has no UiTheme and its own italic font (`:32`); `ArrivalFlow:114-131` own hover; `AutoButtonColor = true` on all named surfaces; the three snaps.
- Not a bug: `MarketUi:166` and `BackpackUi:161` are per-tab UIScales, deliberate and commented. `PanelBand` adds no UIScale, so nothing stacks there.

## Consistency

| token | what each surface does | standardise on |
|---|---|---|
| colour: panel body | Market, Backpack, Quests, Daily near-black; Index, Rebirth, Settings navy; Shop light lilac; Upgrades no body; Starter `fromRGB(44,50,72)` cards | `Palette.Panel` to `Palette.PanelDeep` (`UiTheme.Plate`) |
| colour: confirm green | `TILE_GREEN` (60,220,90) Market; (70,170,90) Starter; `GREEN` in Daily and Racer; `AUTO_ON` (60,255,60) | `Palette.Money`; `MoneyDeep` for the gradient base |
| colour: slots, sort | Slot and Sort buttons use the same green as BUY, so equip and pay look alike | a non-money tone, `Palette.Row` with a white edge |
| stroke colour | (18,22,43) `UiTheme:7`; (12,16,30) `HudButtonStyle:5`; (17,19,31) `PanelFrame:30` | `UiTheme.Outline` |
| text stroke | HUD labels 2 to 2.5; Market captions heavy; Claim, Starter, Daily none; Shop strokes small captions | `UiTheme.Stroke` 2 at 18 px and up; none below 16 px |
| font | Fredoka almost everywhere; `Enum.Font.FredokaOne` direct in HudChrome and PanelFrame; TeamHud Heavy italic | `UiTheme.Font`; TeamHud italic only as an owner-approved exception |
| radius | Tokens 8, 12, 16; panel 16, header 14; Market and Backpack close 0; Starter 16, 12, 8 by literal | `UiTheme.Radius` S, M, L; never 0 |
| button | Racer `HudButtonStyle` lift + shadow + 1.035 / 0.97; Shop, Market, Backpack, Checkpoint, Duel, SlotPicker, pills `AutoButtonColor` darken; ArrivalFlow own | `RacerMotion` values, `AutoButtonColor = false` |
| panel header | PanelFrame gradient with icon (Shop, Market, Backpack, Daily, Quests); Index tabs in a cyan bar, no title; Rebirth magenta bar with centred title; Settings grey band; Upgrades floating text; Starter none | `PanelFrame.Attach` for all; Index and Settings keep tabs below it |
| panel width | Shop, Market 900; Backpack, Quests, Daily 760; Index, Rebirth, Settings narrower | keep content-based, on `PanelBand` |
| close button | 5 styles. Market, Backpack: square red, no edge, 72 x 64. Shop: rounded, dark edge. Index, Rebirth: pink-red, small, dark edge. Quests, Daily: dark red `fromRGB(210,75,90)`, unstroked X. Upgrades: pink, plus EXIT. | one PanelFrame close: `Palette.Danger`, radius M, `Outline` edge, stroked X, top right |

## SFX audit

All volumes are placeholders. Roll rows use no Burst and no speed streaks (ROLL_ANIMATION_SPEC). Press tick = existing `HudPressSound`, plays on every button already. "None" for sound means fatigue risk, on purpose.

| moment | trigger file:line | current motion | proposed motion | cue | sound slot | vol | frequency |
|---|---|---|---|---|---|---|---|
| panel open | `PanelSwitch.luau:180` | scale or slide, list Cascade | keep + Fade | `PanelOpen` | Whoosh | 0.15 | often |
| panel close | `PanelSwitch.luau:212` | scale 0.95 or instant | Fade | `PanelClose` | none (press tick) | - | often |
| tab switch | `InventoryTabs.luau:17`, `MarketUi:520`, `BackpackUi:483`, `BoostDailyUi:522` | Mark | Mark | `TabSwitch` | Tap | 0.2 | often |
| purchase Shop | `ShopUi:216` prompt; no success handler found | none | Pop on the card | `ShopBought` | Chime | 0.5 | rare |
| purchase Market | `MarketUi:482-493` | status slide | Impact on BUY + Fly of the cost | `MarketBought` | Coin | 0.45 | often |
| equip | `BackpackUi:448`, `:457`, `MarketUi:503`, `RacerUiController:656` | tile Pop on select; no answer motion | Pop on slot | `Equip` | Thunk | 0.3 | often |
| upgrade node | `ProgressionUi:312` | label size change | Impact on the node | `UpgradeBought` | Coin (replaces `electronicpingshort`, existing, at 0.3) | 0.4 | often |
| denied | `ProgressionUi:313-316`, `MarketUi:489`, `BoostDailyUi:474` | rotate -3 on node; red text elsewhere | Shake | `Denied` | Denied | 0.35 | often |
| Daily claim | `BoostDailyUi:463-471` | status slide | Slam on the day tile + Fly | `DailyClaim` | Chime | 0.6 | rare |
| Quest claim | `BoostDailyUi:589-596` | status slide | Pop on row + Shine | `QuestClaim` | Chime | 0.45 | often |
| Rebirth | `RacerUiController:489-496` | button text only | Slam + Burst + Shake | `Rebirth` | Boom | 0.8 | rare |
| toggle | `RacerUiController:254` | snap | Mark on the knob | `Toggle` | Tap | 0.2 | often |
| roll slot tick | `RollToast/init:1165-1173` | swap Pop | keep | `RollTick` | none by default; Tap at 0.05 only on emphasized rolls | 0.05 | constant, FLAG |
| roll land Common, Uncommon | `init:1180-1187`, `landEffects:1000` | Pop + thin ring | keep | `RollLand1` | none | - | constant, FLAG |
| roll land Rare | same | thicker ring | keep | `RollLand2` | Tap | 0.15 | often |
| roll land Epic | `init:1017` | + pulsing ring | Pop | `RollLand3` | Thunk | 0.35 | often |
| roll land Legendary | `init:1029-1037` | + gold swell, Shake | Impact (no shards) | `RollLand4` | Crack | 0.6 | rare |
| roll land Mythic | `init:1038` | + light sweep | Shine + Shake | `RollLand5` | Boom | 0.7 | rare |
| Secret takeover | `init:1044-1058` | dark screen + title + fade | Slam on the title + Shake | `RollSecret` | Boom + Chime | 0.9 | rare |
| VS banner | `EnemyShowdown:133-146` | Fade + SlideIn | Slam | `EnemyVs` | Slash | 0.5 | often |
| DEFEATED | `EnemyShowdown:133-146` (won) | same as VS | Slam + Burst + Mark portrait | `EnemyDefeated` | Crack | 0.7 | often |
| enemy passes | `RaceProgressMap:278` | pill recolours; no moment exists | Pop on the pill | `EnemyPass` | none for behind; Tap for you pass | 0.15 | often |
| loser recap ribbon | `NpcRacerView:277`, `:302` | SlideIn + Shake | Impact | `LoseRibbon` | Thunk | 0.6 | often |
| loser recap rows | `NpcRacerView:309-315` | staggered SlideIn | keep | `LoseRow` | none on rows; Tap at 0.1 on Gap only | 0.1 | often |
| money gain small | `RacerUiController:823` | Pop + Float | keep; no threshold today | `MoneySmall` | none | - | constant, FLAG |
| money gain big | `RacerUiController:823` (new threshold) | same | Fly | `MoneyBig` | Coin | 0.4 | often |
| turbo | `RacerUiController:759-763` | label Pop + Shine | Pop + Fill + Shine (no Burst, it lands inside a roll) | `Turbo` | Crack | 0.35 | often |
| team tag-in | `TeamToast:54`, `TeamHud:448` | toast slide + circle scale | Pop on circle | `TagIn` | Whoosh | 0.25 | often |
| team exhausted (added) | `TeamToast:56` | toast slide | Shake on the Team row | `Exhausted` | Thunk | 0.4 | often |
| badge new | `HudChrome:327-331`, `:344` | Pop, ring pulse | keep | `BadgeNew` | Tap only when count grows from 0; else none | 0.1 | often |
| toast low (status, code answers) | `BoostDailyUi:241`, `ShopUi:500` | SlideIn | Fade | `ToastLow` | none | - | often |
| toast medium (biome welcome) | `BiomeWelcome:44` | fade + Back | keep | `ToastMid` | Whoosh | 0.2 | often |
| toast high (duel result) | `DuelUi:279-290` | Fade + SlideIn + Pop | Slam | `ToastHigh` | Thunk | 0.5 | rare |
| checkpoint bonus | `CheckpointBonusPopup:42`, `:72` | fade + Back | Pop + Fly if it pays | `CheckpointBonus` | Chime | 0.4 | often |
| starter pick | `StarterPick:148`, `ArrivalFlow:226` | panel Pop; in-world reveal | Slam on card | `StarterPick` | Crack | 0.6 | rare |
| duel countdown | `DuelUi:241` | not read in detail | Pop per number | `DuelTick` | Tap | 0.3 | rare |
| duel invite | `DuelUi:223` | panel open | Pop | `DuelInvite` | Chime | 0.4 | rare |
| duel result win / lose | `DuelUi:353` via `:279` | toast | Slam + Burst on win, Shake on lose | `DuelWin`, `DuelLose` | Boom, Thunk | 0.7, 0.5 | rare |

Existing sound found outside this table: biome ambience (`BiomeEnvironment`, `BiomeAmbience`), left as it is. No sound exists today for any other moment above.

## Not checked

- Real phone view: not possible. MCP has no viewport tool and the harness requires the real game view resized by hand (`UiSpec.LegacyControls.ResizeProtocol`). Device emulation needs the Studio UI. Phone results are solver only, from one `ui_layout` run: 962 checks, 9 fails, 4 at phone sizes (A33, A34). The solver cannot judge readability, so every "seen" row above is desktop only.
- Stray clicks: during one window about 8 mouse presses landed in the game view that I did not send, and my Team's slot 1 changed. The first presses may also explain my first starter click (Ruffy's button produced Sayan, cause not proven) and one Items click that did nothing. They stopped after about 25 s. Findings that fell in that window are marked (A3).
- `user_mouse_input` with `instance_path` moved the mouse off target here, so I used x, y in AbsolutePosition space.
- Normal roll Land and Hold, the fly icon landing: glimpsed in stills only. Exact motion, snaps, pops and flicker cannot be judged from stills; capture latency is about 10 s. Jank notes are from code.
- Real-timing VS and DEFEATED, a real win, a real lost race (a run ended by exhaustion, not a loss). Loser recap used fake times.
- Tag-in toast, checkpoint bonus popup, biome welcome, Team info card, Stats panel, Codes and Server Luck sections of Shop, Player Profile tab, Auras tab, Checkpoint picker, Duel (needs a second player), Rebirth "REBIRTH COMPLETE" reply (capture came after it cleared), Reduced Effects on, SOUND off.
- Audio: nothing heard. Volumes and pairings are proposals from code only.
- `AutoRollTutorial` (in-progress work, not landed): not in the place during this audit, not seen. My save had AutoRoll true at start.
