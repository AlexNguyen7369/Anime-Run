# UI Scroll Dojo spec (design doc 4.46)

Status: DRAFT, 2026-11-20. Every value is **proposed** until the owner approves the references.

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
Pending the owner's pick from `assets/ui/scroll_redesign/drafts/`.
