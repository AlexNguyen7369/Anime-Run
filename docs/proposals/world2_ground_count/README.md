# World 2 ground-ownership count (agent-1, 2026-11-25, swap round 5 at 5747dda6, read-only)
Rule: the owner's "nearest road owns the ground" (WORLD2_SPEC "Ground ownership"). Scripts and outputs in this folder;
they were run from a scratch archive of 5747dda6 and are not run by any test. (a) = base centre, (b) = any footprint point.
- 10,684 built props: 1,293 (12%) on another track's ground by (a), 1,790 (17%) by (b).
- Share of own built props lost, (a) / (b): T1 14/24, T2 14/17, T3 25/30, T4 30/35, T5 7/22, T6 13/19, T7 17/23, T8 11/16, T9 22/25, T10 0.5/3 percent.
- Heroes (planner unmodified, --zone=2, 47): 28 stay, 5 move, 14 no spot. Moves: Wyvern 10, BrickFlat 30, Hospital 1987, Coliseum 457, DarkGate 90 studs. No spot: T1 RuinedCastle, Town; T2 ChainTower; T3 Crater, HeroHQ; T4 OldWoodHouse, School; T5 DefenseHQ, GiantCorpse, Railgun; T6 HQ; T7 IslandVolcano, Nest; T8 LairTower.
- Props touching another track's prop: before 2,746 pairs; (a) all offenders out 107; (a) non-heroes only 305; (b) all out 0; (b) non-heroes only 204. (T1's 15 props does not match round 5's 21: that script is gone.)
- Worst run views, share lost (a) / (b): T3 0.62 58/58, T7 0.62 50/57, T7 0.33 38/54, T8 0.62 36/43, T4 0.90 30/55, T1 under (b) 47/65/40 at 0.33/0.62/0.90.
- Not covered: replacement spots for non-heroes (removal only, so an upper bound on cost), hero moves in the contact table, same-track contacts, lamps, terrain, real visibility.
Owner questions: OWNER_QUESTIONS.md 2026-11-25 items 13, 16.
