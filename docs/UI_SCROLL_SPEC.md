# UI Scroll Dojo spec (design doc 4.46)

Status: owner approved the references 2026-11-20. Sizes, timings and colours stay **proposed** (tunable).

## Kit (`Client/DojoHandscroll`, built from `Client/DojoScroll` parts and `UiTheme.Scroll.Skins.Parchment`)
- Paper: parchment #EFE3C8, shade #E6D6B6; ink #2E1E16; accent vermilion #C8302C.
- Rollers: brown wood (#805430 to #52321A) at the left and right ends, about 26 px wide, caps 6 px past the paper.
- Edge strips: leather, 10 px, top and bottom of the paper.
- Title: brush wordmark (Permanent Marker), vertical vermilion kanji beside it. Close: a vermilion seal with an X.
- Tabs: paper tabs, the active one a red brush pill with cream text.
- Actions: cream wood tiles (TileTop/TileBottom/TileRim) for primary, outlined paper buttons for secondary.
- Cards: paper cards with a brown rim; rarity shows as a coloured strip and a hanko seal; drawn portrait art.
- Paid offers: burgundy cards with pink rims, gold Robux price, cream Buy pill.

## Motion
- Open 0.45 s, Quad out: both rollers from the centre to the edges; the paper is a clipping frame whose width follows
  the rollers; content inks in over 0.15 s as the paper passes it; controls are live once shown.
- Close 0.25 s, Quad in, the reverse.
- Reduced effects: 0.15 s fade.
- Summon and Team Select keep their own motion.

## Per-GUI layouts
Design doc 4.46 lists each layout. Reference frame per GUI (`assets/ui/scroll_redesign/drafts/<name>.html`, shots in
`drafts/shots/`): index, phone_index, backpack, shop, market, quests, daily, rebirth, stats, settings, settings_profile,
tracks, duel, starter, itemmenu, pickers, rolloptions, toasts, bosses, bossreward, bossinvite, bosshud, hud_a.
Reverted: hud_a (owner 2026-11-23, "too blocky and cluttered"; the HUD keeps the 4.40 look). Not built: hud_b (option B rejected), upgrades (the Upgrades tree stays as it is).

## Hookup
- Panels opt in with the `Handscroll` attribute; `PanelSwitch` then runs the unroll in place of `openMotion` /
  `closeMotion`. Summon, Team Select and Upgrades do not carry it.
- The shared skin changes at `AnimeSkin` and `PanelFrame`, keeping the instance names tests use (`PanelFrame`
  attribute, `Header`, `Title`, `Icon`, `Close`, `Face`).

## UI test rules (owner 2026-11-22)
- The per-panel header colour gradient check is removed: 4.46 headers have no fill.
- The panel "rounded" and "outline" checks are replaced by a handscroll check: each redesigned panel has a Handscroll
  with Paper and both rollers, and the paper shows at rest.
- The generated panel chrome model (Stats, Settings, Rebirth) in UiResponsive is updated with t3, when those headers
  move to the 4.46 layout.
- Roll result (owner 2026-11-22): stays without a card, as ROLL_ANIMATION_SPEC decision 4 says; only the NEW, +1 COPY
  and TURBO badges take the 4.46 look (the toasts frame's paper card is not built).
