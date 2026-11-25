# World 2 visual bugs: findings and patch drafts (2026-11-25, offline only)

Pictures: `assets/world2_draft/audit/lighting_2026-11-25`. Nothing here has been seen in Studio after the patch.

## Note for the owner
| Fix | What it does | Before | After | Upload | Risk |
|---|---|---|---|---|---|
| Grass | bare ground under roads and slabs | blades through Track 6 and 7 roads (Track 1 after the swap) | none by the offline check | no | brown strip of about 2 to 4 studs by the walls, 8 round finish slabs |
| White meshes | stops the default grey darkening World 2 props | door 1C0A04 | door 2D1106 | no | pale props (hands, walls) are 56% brighter than you have seen them; dark ones stay near black |
| Colour export | ships the approved colours | door 2D1106 | door 74482C, as approved | up to 115 meshes, saved in both places | the cause is a strong inference: compare one mesh first |

The colour export needs the white fix under it, or it lands at 64%. World 1 is untouched by all three. None is seen in Studio yet.

## w2-grass-through-road
- Cause: ElvenPlains and AntIsland set `Materials.Corridor = M.Grass`, and the corridor runs under the road. `TerrainBuilder`
  draws its top 2 studs under the road top; the engine grows decoration blades on Grass that are taller (seen in the pictures;
  blade height is not readable offline). The road is 2 studs thick, so the blades come out of it. No code or project file sets
  Decoration or GrassLength. Not the terrain height: heights are right.
- World 1: not affected. No World 1 theme has a Grass corridor; 103,077 road and slab columns checked, 0 Grass.
- After the Track 1/6 swap Track 1 has the same fault, and the plaza floor and finish slabs near Grass (80 sampled columns).
- Patch: in `TerrainShape.Column`, a Grass corridor column within `BARE` (24 studs, proposed: W/2 + wall 2 + half a voxel) of
  a road, or inside a clear box, is Ground. Heights, props and World 1 are identical (harness hashes); only the material
  hash of World 2 changes. Cost: a brown (`Ground` A07B52) strip of about 2 to 4 studs outside each wall, and an 8-stud collar
  round finish slabs (and the plaza after the swap).
- Not chosen: LeafyGrass (no blades, but its global colour is teal), Corridor = Ground for the whole biome (44 studs a side:
  changes the approved look), turning Decoration off (a place setting, all worlds).

## w2-dark-props
- Cause: `export_props.bake_glb` writes Blender's linear base colour to COLOR_0. glTF defines that as linear, but the pictures
  match Roblox reading the numbers as sRGB, so every colour is darkened by the 2.4 curve, dark ones most. Measured:

| Prop colour | Approved | Shipped COLOR_0 | Brightest channel |
|---|---|---|---|
| T9 city wall | E6AE3E | CA6C0C | 88% |
| T7 thatch | 9A8050 | 522F14 | 53% |
| T10 door | 74482C | 2D1106 | 39% |
| T7 brush | 2E4A26 | 071105 | 23% |
| T4 cedar | 1C3326 | 030805 | 16% |

  Pale colours barely change (hand E8EEF8 to CEDAEF), which is why some props look right, and mid colours get
  over-saturated (the orange city).
- Ruled out: normals are in the GLBs; meshes have no textures; the floors only scale light, so they cannot undo a per-colour
  curve. Parts-only props and parts fallbacks use the hex colour and are right.
- Strong, not proved: one re-uploaded mesh side by side in Studio proves it.
- Second cause, seen in Studio by the lead (2026-11-25): all 10,360 placed World 2 meshes have no texture and the default
  grey Color (0.639, 0.635, 0.647), and the same mesh in white is clearly lighter. It tints on top of the curve above.
- Grey patch (on this branch, code only): `BiomeAssets` makes a textureless template white in World 2. World 1 and textured
  meshes keep the colour they were loaded with (`biome_mesh_color`, offline 13/0 in each world, was 11/2).
- Numbers, per channel as drawn (grey 0.64 multiplies): white is +56% on every mesh.

| Prop colour | Approved | Today (grey, linear) | White only | Re-export only (grey) | Both |
|---|---|---|---|---|---|
| T9 city wall | E6AE3E | 814508 | CA6C0C | 936F28 | E6AE3E |
| T10 door | 74482C | 1C0A04 | 2D1106 | 4A2E1C | 74482C |
| T7 brush | 2E4A26 | 040B03 | 071105 | 1D2F19 | 2E4A26 |
| T4 cedar | 1C3326 | 020503 | 030805 | 122019 | 1C3326 |
| T10 hand | E8EEF8 | 848B9B | CEDAEF | 9497A0 | E8EEF8 |

  White alone never passes the approved colour (the linear number is at or below the sRGB one on every channel), so it
  cannot overshoot; dark props stay near black. The two fixes together give the approved colour exactly. The re-export
  assumes white: without the grey patch it lands at 64%, and it must not brighten the colours to make up for the grey.
- Colour patch (branch feature/alex/w2-color-export, off until the uploads): `bake_glb` writes sRGB numbers; `color_test.py` was 2/9, now 9/9 (within 2 of 255). Mesh shapes are untouched.
- Cost: the look changes only when meshes are exported and uploaded again: 115 ledger rows, all of them change hash
  (colours are in it), plus a saved copy of each in each place's BakedModels, a rules review per new row, and the
  re-export hold lifted. No code-only fix: a part's Color can only darken. EditableMesh at runtime would work per client but needs mesh
  permissions and the mesh budget World 1 already uses.
- Night tracks (4, 6, 8) stay dim afterwards: their approved colours are dark by design. Judge after the re-upload.

## Order proposed
1. Grass and grey patches (no upload), seen in Studio. 2. One mesh re-uploaded beside the old one. 3. Owner: re-export and upload.
