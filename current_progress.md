# Current Progress

## Completed
1. 2026-10-28 — Alex Nguyen — Wrote the Anime Run design doc and specs (team of 3, stamina, character gacha, NPC rivals, research notes).
2. 2026-10-28 — Alex Nguyen — Added owner decisions to the specs: Stamina stat point, Stamina potions, Sprinter/Balanced/Marathoner categories, Series and preset team bonus.

## What's next
**Owner approves the 30-character cast, the 6 series with their preset trios and the placeholder numbers; then fork the IVS code and write the red `team`, `team_bonus` and `stamina` tests.**

**Why this is next:** the catalog files, `SeriesCatalog` and `StaminaConfig` are built from these names and numbers, and every test checks them.
