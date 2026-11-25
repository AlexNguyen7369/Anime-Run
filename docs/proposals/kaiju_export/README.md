# Track 5 kaiju-only export: PROPOSAL (agent-2, 2026-11-25; not for merge, no ledger id, no upload)
`tools/blender/world2/kaiju_export.py` (`--self-test`, `--measure`, `--filter`) wrote `src/shared/BiomeThemes/World2/KaijuBaseDraft.luau` from the
committed file and a scratch `export_props.py -- 5 --no-glb`: only the GiantCorpse prop data, its 2 placements and the 12 fill rows (9 Apartment,
3 Office) are new. DefenseHQ stays unplaced, Railgun, the 21 Piers, the vans and every other row keep their text and their Placed_<n>.
- Dropped, standing inside a body (`measure.json`, share of vertices under the body >= 0.5): Rubble rows 184, 249, 264, 287 (0.81, 0.92, 0.89,
  1.00). Their slots hold the 2 GiantCorpses, one Office and one Apartment; the other 10 new rows are 589 to 598.
- The ledger row (`KaijuBase.luau` W2_KaijuBase_GiantCorpse) still names the OLD mesh id: this file must not ship before the new upload.
- The new GiantCorpse parts fallback is 24 parts of colour 010203 (KaijuBase.STANDIN): near-black blobs while the mesh loads. The old one was brown.
