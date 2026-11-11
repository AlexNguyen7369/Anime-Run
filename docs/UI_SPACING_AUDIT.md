# UI spacing and consistency audit (2026-11-10)

Owner did not approve the first game-wide anime pass (commit 5541c3f): "focus on margining and spacing. UI consistency and
cleanliness check". This audit is the base for the redraft. Rule source: design doc 4.42.

Method: every panel opened in Play at 1271 x 601 (desktop). Geometry measured in Studio (panel px; Racer panels are drawn
at about 0.56 scale, numbers below are on-screen px). Screenshots read side by side. Popups that need a live event or flow
(boss Invite, Team picker, Reward popup, StarterPick, Item menu, Gift picker, Loser screen) are judged from code only.

## 1. Cross-panel findings

| # | Finding | Where | Effect |
|---|---|---|---|
| G1 | Three different header systems: Index/Quests (overhanging logo, title above the strip, tabs in their own row, footer bar); PanelFrame panels (logo plus full-width strip, close inside the strip); Racer panels (Rebirth, Stats, Settings: tabs inside the strip, no logo or title); plus Workshop (panel removed 2026-11-11), Duel, Bosses and Upgrades with no strip or logo at all | every panel | The game does not read as one UI |
| G2 | Header-to-content gap varies: 2 (Sidekicks), 6 (Tracks hint), 12 (Shop, Market, Backpack), 24 (Daily), about 38 (Index, Quests) | all | Uneven top rhythm |
| G3 | Side margins vary: 10 (Rebirth), 11 (Settings), 12 (Shop, Backpack, Stats), 14 (Daily), 16 (Tracks), 32 (Index, Quests) | all | Content does not line up with the frame art the same way twice |
| G4 | Content runs into or past the bottom: Daily cards cut off (bottom margin -10), Backpack second row hidden under the slot bar, Sidekicks gem column cut, Shop/Tracks rows cut mid-card at the scroll edge | Daily, Backpack, Sidekicks, Shop, Tracks | Looks broken, not scrolled |
| G5 | No type scale: 7 to 17 different text heights per panel (Shop 17, Index 10, Backpack 10, Sidekicks 11) | all | Busy, inconsistent hierarchy |
| G6 | Title casing mixed: "Shop", "Market", "Backpack", "Tracks", "Settings" vs "INDEX", "QUESTS", "BOSSES", "DAILY REWARDS", "WORKSHOP UPGRADE" (panel removed 2026-11-11) | all | Inconsistent |
| G7 | Close button: 52 px inside the strip (PanelFrame), 42 px overhanging the top edge (Index, Quests), small inside the strip (Racer), plain red square (Duel, Bosses, Workshop (panel removed 2026-11-11)) | all | Four close styles |
| G8 | The body art's baked diagonal stripes (bottom-left) cross content: Market Potions tab, Backpack Relics tab, Rebirth requirements bar, Bosses spawn button | Market, Backpack, Rebirth, Bosses | Art collides with controls |
| G9 | Button shapes mixed: 4 px Index buttons, 8 px snapped corners (Sidekicks, Tracks chip), pills (Sort, Search, Settings knob, Workshop BEST 3 (panel removed 2026-11-11)), rounded light Upgrades zoom buttons | all | Inconsistent |
| G10 | Header toolbars squeezed into the strip: Backpack (Sort, Mass sell, Search), Sidekicks (gems, rotation, pity bars), Settings (tabs), Rebirth (tabs), Stats (free points) | 5 panels | Cramped, unequal heights |
| G11 | Heading colours differ for the same role: WARNING red, NEXT REBIRTH yellow, REQUIREMENTS purple, Daily green, Bosses "Details" gold | Rebirth, Daily, Bosses | No single section-heading style |
| G12 | Small outlined text turns to blobs: Stats value "0 pts x1 > x1.02", Shop "Account-bound", Backpack rail labels at 6-8 px ("Charac", "Sidekic" truncated) | Stats, Shop, Backpack | Unreadable |

## 2. Per panel

**Shop** (900 x 350). Card row edges 16 px from the frame on the left but the scrollbar sits 4 px from the right card. In each card: title 14 px from the top, "Details" pill floats over the icon area, OWNED/Gift buttons 4 px above the caption, caption 2 px from the card edge. "Gift" text does not fit its button (measured). 17 text sizes.

**Market** (900 x 350). Rail tabs flush with the frame (4 px) while the grid is 40 px from the rail; the rail uses big filled cards, not art tabs. Grid fills 3 of 4 columns, leaving a 100 px dead gap before the detail card. Detail: heading touches the card's top edge, BUY touches its right edge, slot buttons sit on the card's bottom border. Potions tab under the stripe art.

**Backpack** (760 x 350). Strip holds title plus three controls of three heights. Rail tabs 6-8 px text, truncated. Rail top 30 px lower than the grid top. Slot bar overlays the grid (second row hidden) instead of sitting under it. "Bag 180/180" floats 4 px above the frame bottom. Relics tab under the stripe art.

**Quests** (approved look). Tab row narrower than the list plus detail; footer good. Keep as the model.

**Daily** (760 x 350). Claim button full width at the top, then the 7 cards overflow the bottom by 10 px: Days 4-6 and Day 7's caption are cut. Content top gap 24 vs 12 elsewhere.

**Index** (reference). Margins 56 design px (32 on screen), tab row, footer. Keep as the model.

**Rebirth** (Racer). No logo or title; tabs inside the strip. Margins 10. Three heading colours. Requirements bar runs into the stripe art.

**Stats** (Racer). Rows good after plates, but value text blobs; "5 FREE POINTS" sits on the strip at a different size than the tabs.

**Settings** (Racer). "PLAYER PROFILE" tab text wraps to two tiny lines; "SETTINGS" tab text tiny. Toggle tracks stick out past the plate's slant. Title in mixed case.

**Upgrades** (full screen). Title in a plain dark pill, not the strip; close far top-right; zoom +/- light rounded buttons; Balance pill overlaps the TURBO LUCK bar.

**Bosses**. Title 16 px from the left with no logo; drop list is plain centred text in 4 font treatments; spawn button full width, 2 px from the body bottom, under the stripe art.

**Sidekicks** (760 x 350). No title or logo; header holds gems and three bars. Body 2 px under the header. "FEATURED!!!" overlaps the poster's top edge. Summon buttons: dark outline on green, "Summon 10x: 500 Gems" wraps to 2 lines; three button widths. Gem column cut at the bottom.

**Tracks** (760 x 350). Hint 6 px under the header; flag logo overhangs 28 px; number diamond sticks out past the plate's left end; description reaches the plate's right edge.

**Workshop** (panel removed 2026-11-11). No strip or logo, centred title; plain text rows; four button styles (pill BEST 3, outline EMPTY slots, flat SHOW, full-width BUY); stat tabs squeezed at the bottom-left.

**Duel pick / invite**. No strip or logo, plain title, small close; subtitle 10 px; empty space (needs an opponent to fill).

**Code only**: boss Invite and Team picker (plain header, no logo, own close), Reward popup (body hung from the header), StarterPick (body, no header strip), Item menu / confirm / picker (body, no header), Gift picker, Loser screen. All lack the shared header and spacing.

## 3. Proposed standard for the redraft (owner to approve)

Desktop design px on a 4 px grid. Phones scale the same tokens.

- **One frame for every panel and popup:** Index's chrome (body art, overhanging logo, slanted title strip, art close), as `AnimeSkin.Frame`. Index and Quests already match it.
- **Header:** 64 tall. Logo 90 px, overhanging up-left. Title ALL CAPS, 38 px, heavy italic, starting after the logo. Close 52 px, 6 px from the top and right.
- **Toolbar row:** tabs, sort, search, counters go in one 40 px row under the header, never in the strip. Art tabs, all the same height; text 14 px minimum.
- **Insets:** 16 px left and right, 12 px header to toolbar, 12 px toolbar to content, 16 px bottom. Content keeps clear of the bottom-left stripe art (bottom inset 24 where a control sits at the left).
- **Spacing:** 12 px between cards and rows, 8 px inside a card, 12 px card padding. Buttons 40 px tall (32 small), 4 px corners, no pills.
- **Type scale (5 sizes):** 38 title, 26 section heading, 20 item name, 16 body, 13 caption. Section headings one colour (gold); white for item names and body; captions soft white. Nothing under 13 px; no outline under 16 px.
- **Footer:** list panels get Index's footer bar for their count line (Backpack bag count, Tracks, Shop codes), instead of floating text.
- **Scroll lists:** end on a whole row or show a 16 px fade, never cut a card in half at the frame; scrollbar 8 px inside the frame.

## 4. Redraft order

1. `AnimeSkin.Frame` (header, toolbar row, insets, footer) and the type tokens in `AnimeSkin`.
2. Panels on PanelFrame: Shop, Market, Backpack, Daily, Sidekicks, Tracks.
3. Racer panels: Rebirth, Stats, Settings (header rebuilt to the standard; UI tests pin these rects, so tests move with them).
4. Own-built panels: Workshop (panel removed 2026-11-11), Upgrades title bar, Duel, Bosses, boss Invite and Team picker, Reward popup, StarterPick, Item menu, Gift picker, Loser screen.
5. Screenshots of every panel, desktop and phone, to the owner.
