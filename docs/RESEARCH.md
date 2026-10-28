# Research notes (public sources, 2026-10-28)

## 1. Genre: Roblox anime gacha simulators

- Anime Champions Simulator and Anime Astral Simulator are anime gacha simulators built on collecting characters and
  team building; winning depends on a team whose strengths cover each other's weaknesses, and their gacha uses a gem
  currency (some players call this pay-to-win).
  - https://www.sportskeeda.com/roblox-news/everything-you-should-know-before-playing-roblox-anime-champions-simulator
  - https://earnaldo.com/blog/anime-astral-simulator-free-robux-guide
- No public source found for a 3-character team with a stamina relay. The mechanic looks new in the genre.
- Takeaways: team building is expected by the audience; keep the free auto-spin as the main source so the game does
  not read as pay-to-win.

## 2. Intellectual property

- Roblox: infringing someone's IP violates the Terms of Use and the law; only the rightsholder (or their agent) files
  a takedown, under penalty of perjury.
  - https://create.roblox.com/docs/en-us/production/publishing/dmca-guidelines
  - https://create.roblox.com/docs/en-us/marketplace/intellectual-property
- Fan games and parodies of franchises have been removed after DMCA notices.
  - https://roblox.fandom.com/wiki/Copyright_and_trademark_infringement
- Decision (owner 2026-10-28): original characters only (design doc section 5).

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
  (sprinter vs marathoner) keeps more characters useful (design doc open question 3).
  - https://game-wisdom.com/?p=25009
