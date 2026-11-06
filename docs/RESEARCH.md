# Research notes (public sources, 2026-10-28)

## 1. Genre: Roblox anime gacha simulators

- Anime Champions Simulator and Anime Astral Simulator are anime gacha simulators built on collecting characters and
  team building; winning depends on a team whose strengths cover each other's weaknesses, and their gacha uses a gem
  currency (some players call this pay-to-win).
  - https://www.sportskeeda.com/roblox-news/everything-you-should-know-before-playing-roblox-anime-champions-simulator
  - https://earnaldo.com/blog/anime-astral-simulator-free-robux-guide
- No public source found for a 3-character team with a stamina relay.
- Takeaways: team building is expected by the audience; keep the free auto-spin as the main source so the game does
  not read as pay-to-win.

## 2. Intellectual property

- Roblox: infringing someone's IP violates the Terms of Use and the law; only the rightsholder (or their agent) files
  a takedown, under penalty of perjury.
  - https://create.roblox.com/docs/en-us/production/publishing/dmca-guidelines
  - https://create.roblox.com/docs/en-us/marketplace/intellectual-property
- Fan games and parodies of franchises have been removed after DMCA notices.
  - https://roblox.fandom.com/wiki/Copyright_and_trademark_infringement
- Decision (owner 2026-10-28): real anime characters with tweaked names, risk accepted (design doc section 5).

## 3. Paid random items (spins)

- Roblox policy (updated 2026-08-19): odds for every outcome as percentages summing to 100%, visible before purchase,
  behind an "Info"/"Details" label (a bare (i) icon is not enough). Luck boosts, pity and rate-ups must show updated
  odds while active. Users flagged by PolicyService need a free earnable path or fixed disclosed outcomes, and cannot
  trade those items.
  - https://create.roblox.com/docs/en-us/production/monetization/paid-random-items
  - https://devforum.roblox.com/t/policyservice-guidelines/773321 (older; superseded where it differs)

## 4. Stamina and rarity

- Gacha games commonly use stamina/energy as a resource consumed to play stages; our stamina is per run, not an
  energy gate (owner 2026-10-28).
  - https://r.datuan.dev/r/gachagaming/wiki/index/what_are_gacha/
- Balance risk: when rarity drives power, a strong low-rarity unit can outshine higher rarities; role-based design
  (sprinter vs marathoner) keeps more characters useful.
  - https://game-wisdom.com/?p=25009

## Boss events, Relics, Gems, Sidekicks (2026-11-04)
Source quality is weak: revenue figures are third-party estimates and most mechanics come from fan guides that sometimes disagree. Only the Roblox policy page is authoritative.
- Recurring bosses are common in anime games. Sailor Piece timers about 7-15 min, one boss about 30; Arise Crossover about 12-30, sources conflict.
  - https://progameguides.com/roblox/sailor-piece-boss-locations-drops-how-to-spawn/
  - https://deltiasgaming.com/?p=183848
- Anime Vanguards: gate bosses reportedly drop Relics (search snippet only; page returned 403). Familiars equip to one unit, not tradable, one raid listed at 1% per boss.
  - https://robolibrary.org/wikis/anime-vanguards
  - https://ofzenandcomputing.com/anime-vanguards-all-familiars-guide/
- Legends of Speed: gems buy crystals, and pets multiply progress.
  - https://deltiasgaming.com/?p=365835
- Pokemon GO raids: lobby, time limit, tiers, loss if the timer ends.
  - https://bulbapedia.bulbagarden.net/wiki/Raid_Battle_(GO)
- Timed events and layered monetization among top earners (estimates). Grow a Garden drew monetization criticism; one article puts about 40% of players under 13.
  - https://rowatcher.com/news/the-10-highest-earning-roblox-games-in-2026-and-what-they-mean-for-the-platform
  - https://en.wikipedia.org/wiki/Grow_a_Garden
  - https://www.gamepressure.com/newsroom/what-is-admin-abuse-in-grow-a-garden-gag-we-explain-what-to-expec/z58490
- No source shows a game selling a server boss spawn for Robux: an untested idea, so measure it.
- Roblox paid random items: currency bought with Robux counts as paid; rewards earned free are exempt. Disclosure must be percentages behind "Info" or "Details" before purchase; a bare (i) icon is not enough. Server-wide paid boss drops are not addressed.
  - https://create.roblox.com/docs/production/monetization/paid-random-items
- Roblox analytics gives genre benchmarks for retention, session time and payer conversion. Its D1 range of 12.4%-24.1% is an illustration only.
  - https://create.roblox.com/docs/production/analytics
