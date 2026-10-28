# Anime Run (Roblox)

Idle running simulator: spin tweaked-name anime characters, run a team of 3 with stamina against NPC rivals.
Derived from Idle Vehicle Simulator (`~/Documents/RobloxGames`); its code is the source for the fork.

## Session handoff (required)
Read `handoff.md` at the start of every session. Update it before pausing or handing off.

## Design docs are hard rules (required)
- `docs/GAME_DESIGN_REQUIREMENTS.md` is the top rule. Feature specs `docs/*_SPEC.md` never contradict it.
- Read the design doc and the feature's spec before planning or editing gameplay, economy, saved data or UI.
- Values marked "placeholder", "proposed" or "open question" are tunable; everything else is fixed.
- On a conflict: stop, report it, ask the owner. Never choose silently.
- A new feature is written into the design doc (and its spec) before any code. Only the owner changes a rule; record
  the change with its date.
- Characters are real anime characters with tweaked names; follow the safeguards in design doc section 5.

## Conventions
- Rojo, `.luau`, tabs, `--!nonstrict`. Server decides every number; the client only displays.
- `stylua src`, `selene src`.

## Progress tracking (required after every commit or push)
After making a commit or push in this repo, invoke the global
`progress-tracker` skill before touching `current_progress.md` — it is
the authoritative, strict spec for how that file is created (if
missing) and updated (Completed appends, What's Next replacement,
formatting, attribution). Do not improvise the update from memory or
from this summary; invoke the skill every time this rule fires.
