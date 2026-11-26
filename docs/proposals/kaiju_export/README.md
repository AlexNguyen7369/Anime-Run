# Track 5 kaiju-only export: PROPOSAL (agent-2, 2026-11-25; not for merge, no ledger id, no upload)
`tools/blender/world2/kaiju_export.py` (`--self-test`, `--measure`, `--filter`) wrote `src/shared/BiomeThemes/World2/KaijuBaseDraft.luau` from the
committed file and a scratch `export_props.py -- 5 --no-glb`: only the GiantCorpse prop data, its 2 placements and the 12 fill rows (9 Apartment,
3 Office) are new. DefenseHQ stays unplaced, Railgun, the 31 Piers (21 of them lowered by a later exporter rule, which this export does not take), the vans and every other row keep their text and their Placed_<n>.
- Dropped, standing inside a body (`measure.json`, share of vertices under the body >= 0.5): Rubble rows 184, 249, 264, 287 (0.81, 0.92, 0.89,
  1.00). Owner 2026-11-25 (question 32): the game vans in rows 226 and 228 are dropped too (`OWNER_DROP`), the frozen Rubble under the fill stays.
  The 6 freed slots (184, 226, 228, 249, 264, 287) hold the 2 GiantCorpses, 2 Offices and 2 Apartments; the other 8 new rows are 589 to 596.
- The ledger row (`KaijuBase.luau` W2_KaijuBase_GiantCorpse) still names the OLD mesh id: this file must not ship before the new upload.
- Parts fallback: the exporter gives KaijuBase's stand-in parts (STANDIN 010203) its approved HIDE 86402F (`export_props.stand_in_colours`, fallback only):
  all 24 GiantCorpse fallback parts are 86402F. The GLB is unchanged: geometry hash 7f2f942a...1c651137, 19,889 tris, 33,294 vertices, 1,185,820 bytes, before and after.
- Landed 2026-11-25 on orch/world2/kaiju-land after the upload and review: the ledger row and `uploaded_assets.tsv` row 39 now carry the new ids (Model 130671695538312, MeshId 120871855895739), so the note above about the old id no longer applies.
