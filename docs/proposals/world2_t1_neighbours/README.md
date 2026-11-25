# Other tracks' pieces on Track 1's ground: PROPOSAL (2026-11-25, not approved, not merged)
Owner's "Go ahead" (design doc change log 2026-11-25 (b); WORLD2_SPEC "Ground ownership": nearest road, base centre).
Planner: tools/blender/world2/t1_neighbours.py (rows in cross_track.json under each biome, `fix`, yaw null = moved only;
the exported drafts patched in place with `--patch`, no re-export). Sheets here: before | after, only views that changed.
Full after renders: assets/world2_draft/trackNN_<Biome>/game and context.

World x, z of the base centre. Move rule (fix round, 2026-11-25): nearest spot within 120 studs (heroes 600, the smoke
column 2000) on the piece's own track's ground (by more than 1 stud), every vertex 24+ studs from its own road, its
triangles off every corridor, off the plaza and checkpoints, not standing in nor touching any built prop of any track
(Flowers excepted), and in no run-view frame of Track 1 or of its own track that it was not in before (frame test, no
occlusion); a hero or the smoke column first tries spots out of every Track 1 view. Otherwise out. Turn, height, scale
and mesh unchanged.

| Track | Piece | From | Result |
|---|---|---|---|
| 2 | Wyvern (hero, flying) | (-309, -364) | moved 6 studs to (-315, -364); Track 1 view 0.06 and Track 2 view 0.33 as before |
| 2 | Crag | (-281, 213) | moved 54 to (-335, 207) |
| 2 | Crag | (218, 221) | moved 51 to (236, 269) |
| 2 | Hound (hero, 1 of its 4 placements; the purple plinth at Track 1's 0.33) | (133, 276) | out: no spot within 600 passes (round 1 moved it behind Track 1's finish statue, the "hat") |
| 2 | RuinB x12, Crag x4 | RuinB (-299, 262) (236, 250) (409, -330) (264, 223) (-334, 196) (-326, -120) (-321, 70) (-33, -423) (42, -425) (165, -425) (281, -401); Crag (274, -225) (2, 172) (102, -316) (-231, 141) | out (round 1 put a RuinB in front of Track 2's own gate at 0.62: the pink sliver) |
| 3 | HighRise (blue-white tower at 0.90) | (295, -121) | out |
| 4 | Cedar x8 | (58, 176) (-332, -185) (207, -196) (-339, -37) (-226, 100) (291, -100) (89, -157) (-308, 102) | out (own ground 1000+ studs off) |
| 5 | Smoke column (6% sightline) | (-68, -263) | out: no spot passes (round 1's spot at (-772, 599), 25.0 studs from Track 5's road at its nearest vertex, touched two Track 4 Cedars) |
| 5 | Apartment x4 (cream towers) | (427, -145) (-183, -73) (-342, 87) (-336, -222) | out |
| 8 | LavaChasm | (237, -247) | out |

Kept on Track 1's ground: Track 8 FleshWall (the one-eyed monster, accepted unchanged); 16 pieces the game already
prunes (plaza ground, an open question): T2 RuinA, Chunk x2; T4 Cedar x5; T5 CityBlock x2, Office x2; T8 LavaChasm
(115, -47); T9 CityBlock x2. They still show in the context renders (the render does not prune).
Totals: 34 pieces changed (3 moved, 31 out), 17 left; built props lost: Track 2 17 (of 474), Track 3 1, Track 4 8,
Track 5 5, Track 8 1. Heroes: Wyvern moved whole; one of the 4 Hounds out (owner's call: keep it at its old spot on
Track 1's ground, or accept a spot in a new Track 2 view).

Notes for the reviewer (fix round):
- Track 2 context 03 pale road patches: render only. Same geometry before and after (the sun is blocked by the same
  Rampart at both probed road points); EEVEE logs "Shadow buffer full (2281 / 2048)" on these renders before and after,
  so shadow tiles drop by chance. With a 2048 shadow pool the before and after renders of that view are identical
  (context_03_run_62_shadowpool2048.jpg, 0.0% changed pixels).
- Track 2 context 01 pale blade at about (1250, 65-210): a Track 8 RockPillar at (-94, 307), on its own ground, 175 tall,
  that the removed Hound used to hide. Not stray.
- Track 1 context 04 (finish): the statue is free (that was round 1's moved Hound). The torches and purple wall are
  Track 2 Ramparts, the smoke a Track 5 Smoke at (364, 555), the white tower a Track 5 Office at (441, 339); all stand on
  their own ground, so the ground rule moves none of them. The smallest change that would clear the finish view is
  removing that Office and that Smoke (the Ramparts line Track 2's road); that needs the owner's word, not proposed here.
