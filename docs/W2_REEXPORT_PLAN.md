# World 2 colour re-export (owner 2026-11-25: hold lifted after the colour test, which passed)

A plan, not a rule. Why: docs/W2_VISUAL_BUGS.md w2-dark-props. Nothing is uploaded, and no ledger, Draft, pin or hero_moves changed.
The white-mesh fix must be in the game first: without it the new meshes land at 64% of the approved colours.

## What was built
`reexport_props.py` bakes all 119 ledger meshes against the merged drafts into `build/world2/reexport` (manifest.json: hashes, sizes, old ids).
- Shapes: every mesh is the same with and without the fix but for its vertex colours (compared without colours), and its tris are its
  ledger row's. Hashes: the same over two bakes of the 119.
- 96 of the 102 meshes with a recorded upload hash: re-made the old way they equal the uploaded file, so only colours change.
- 6 do not: Mountain_p1 and _p2 (Track 1), Hound, Wyvern (2), Nest, Ant (7). Same tris, sources unchanged since the upload, and stable here;
  probably float rounding between the Mac that exported them and this Linux box, not proved. Look at these six closely.
- 17 have no recorded hash (12 uploaded but unplaced, 5 never uploaded).

## Uploads: 100, and 12 that can wait
| Batch | Track | Meshes | Tris | KB |
|---|---|---|---|---|
| 1 | 1 Elven Ruin Plains | 11 | 27,622 | 1,077 |
| 2 | 2 | 10 | 16,186 | 1,033 |
| 3 | 3 | 10 | 26,782 | 1,797 |
| 4 | 4 | 8 | 22,326 | 1,782 |
| 5 | 5 | 9 | 27,466 | 1,933 |
| 6 | 6 Devil Hunter City | 9 | 21,248 | 1,444 |
| 7 | 7 | 10 | 24,232 | 1,423 |
| 8 | 8 | 12 | 38,698 | 2,268 |
| 9 | 9 | 11 | 26,990 | 1,637 |
| 10 | 10 | 10 | 13,896 | 513 |
| 11 (optional) | unplaced, not in the game, HQ included | 12 | 57,942 | 3,862 |
A batch is one track (8 to 12), so a batch is checked on one road. Left out: ChainTower_p1 to p4 and Barrier (no id, not in the game), Abyss
(black: unchanged), GiantCorpse (Track 5's kaiju is reopened: its rework exports it). Largest file 1.2 MB (Portal), 15.3 MB for the 100.

## Steps per batch (`upload_reexport.py`)
1. `dry N`, then `upload N` (owner's key). One model per mesh hash; each operation is logged, so a crash resumes it.
2. Moderation: wait until every Model of the batch loads. A refused one stops the batch; the game still has the old ids.
3. Studio: InsertService:LoadAsset each Model, read the MeshPart's MeshId, `mesh <key> <MeshId>`.
4. Review (BIOME_ENVIRONMENT_SPEC 4.1 step 3): the auditor looks at a screenshot of each loaded Model beside the old one, `review N "date who"`.
5. Studio check, old and new side by side on the track, all white: the new ones match a SmoothPlastic part in the kit's colour; same size and shape; no
   missing or inside-out faces; the six listed above closely. Night tracks (4, 6, 8): the road and runner still read. `check N "date who"`.
6. `apply N` writes the ledger rows and uploaded_assets.tsv for the whole batch, and refuses while one key lacks a Model, MeshId, review or check or a row
   holds another id. Then the harness (LEDGER=1, full WORLD=2), commit.
7. BakedModels: a copy of each new MeshPart named by its MeshId (the digits of the row's Id) in both places' ServerStorage.BakedModels, if the old
   ones are kept there; save both places (owner's word given 2026-11-25). Old copies stay until the batch has been played.
8. Wrong after all: `rollback N` puts the old ids, reviews and tsv lines back to the byte (self-test). The old assets are never deleted.

Batch order proposed: 10 (smallest, the colour test's doors), then 7, 1, 6, 2, 3, 4, 5, 9, 8. Batch 11 when a hero is placed again.

## Not covered
Whether Roblox moderation treats 100 near-identical re-uploads as spam is unknown: send one batch, wait, then the next. Draft fallback parts and parts-only
props already have the right colours. Lighting floors were set with the dark meshes in view: judge them again after batch 1.
