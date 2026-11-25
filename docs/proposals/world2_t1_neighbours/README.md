# Other tracks' pieces on Track 1's ground: PROPOSAL (2026-11-25, not approved, not merged)
Owner's "Go ahead" (design doc change log 2026-11-25 (b); WORLD2_SPEC "Ground ownership": nearest road, base centre).
Planner: tools/blender/world2/t1_neighbours.py (rows in cross_track.json under each biome, `fix`, yaw null = moved only;
the exported drafts patched in place with `--patch`, no re-export). Sheets here: before | after, only views that changed.
Full after renders: assets/world2_draft/trackNN_<Biome>/game and context.

World x, z of the base centre. Move rule: nearest spot within 120 studs (heroes 600, the smoke column 2000) on the
piece's own track's ground (by more than 1 stud), every vertex 24+ studs from its own road, its triangles off every
corridor, off the plaza and checkpoints, not standing in any built prop of any track, not touching a Track 1 or 6 prop
(Flowers excepted); otherwise out. Turn, height, scale and mesh unchanged.

| Track | Piece | From | Result | Track 1 views before -> after |
|---|---|---|---|---|
| 2 | Wyvern (hero, flying) | (-309, -364) | moved 6 studs to (-315, -364) | 0.06 -> 0.06 |
| 2 | Hound (hero, the purple plinth at 0.33) | (133, 276) | moved 115 to (247, 264) | 0.33, 0.90 -> 0.90 |
| 2 | RuinB | (236, 250) | moved 42 to (236, 292) | 0.90 -> 0.90 |
| 2 | RuinB | (409, -330) | moved 101 to (379, -426) | none |
| 2 | RuinB | (281, -401) | moved 68 to (329, -449) | 0.06 -> 0.06 |
| 2 | Crag | (-281, 213) | moved 54 to (-335, 207) | 0.33 -> 0.33 |
| 2 | Crag | (218, 221) | moved 54 to (272, 227) | 0.90 -> 0.90 |
| 2 | RuinB x9, Crag x4 | (-299, 262) (264, 223) (-334, 196) (-326, -120) (-321, 70) (-33, -423) (42, -425) (165, -425); Crag (274, -225) (2, 172) (102, -316) (-231, 141) | out (no legal spot within 120) | various |
| 3 | HighRise (blue-white tower at 0.90) | (295, -121) | out | 0.90 -> gone |
| 4 | Cedar x8 | (58, 176) (-332, -185) (207, -196) (-339, -37) (-226, 100) (291, -100) (89, -157) (-308, 102) | out (own ground 1000+ studs off) | 0.33 / 0.90 |
| 5 | Smoke column (6% sightline) | (-68, -263) | moved 1113 to (-772, 599), on Track 5's ground | 0.06 -> in the 0.33 frame, far |
| 5 | Apartment x4 (cream towers) | (427, -145) (-183, -73) (-342, 87) (-336, -222) | out | 0.06 / 0.33 |
| 8 | LavaChasm | (237, -247) | out | none |

Kept on Track 1's ground: Track 8 FleshWall (the one-eyed monster, owner's reviewer: accepted unchanged); 15 pieces the
game already prunes (plaza ground, an open question): T2 RuinA, Chunk x2; T4 Cedar x5; T5 CityBlock x2, Office x2; T8
LavaChasm (115, -47); T9 CityBlock x2. They still show in the context renders (the render does not prune).
Totals: 34 pieces changed (7 moved, 27 out), 16 left; Track 2 loses 12 built props (of 474), Track 3 1, Track 4 8,
Track 5 4, Track 8 1. Heroes: none removed; Wyvern and Hound moved whole (approved mesh, turn and scale).
