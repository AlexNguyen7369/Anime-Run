# Current Progress

## Completed
1. 2026-10-28 — Alex Nguyen — Wrote the Anime Run design doc and specs (team of 3, stamina, character gacha, NPC rivals, research notes).
2. 2026-10-28 — Alex Nguyen — Added owner decisions to the specs: Stamina stat point, Stamina potions, Sprinter/Balanced/Marathoner categories, Series and preset team bonus.
3. 2026-10-28 — Alex Nguyen — Switched the cast to tweaked-name real anime characters (6 series, preset trios = famous teams, parody NPC rivals) with IP safeguards.

## What's next
**Owner approves the 30-character parody cast, the 6 series, preset trios, NPC rivals and the design doc section 5 safeguards; then fork the IVS code and write the red `team`, `team_bonus` and `stamina` tests.**

**Why this is next:** catalog files, `SeriesCatalog` and `StaminaConfig` are built from these names and numbers, and every test checks them.
