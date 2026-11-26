# Roblox pipeline

Limits read from create.roblox.com on 2026-11-03; re-check when they matter.

- Any mesh: at most 20,000 triangles; quads where possible, no n-gons ([modeling specs](https://create.roblox.com/docs/art/modeling/specifications)).
- Rigs: at most 4 bone influences per vertex; joints frozen at scale 1 and rotation 0; root at 0,0,0 with no influences (same page).
- Avatar bodies ([character specs](https://create.roblox.com/docs/art/characters/specifications)): 15 mesh objects; tris: head 4,000, torso 1,750, each arm and each leg 1,248, total 10,742. Whole-body bounds in studs: length 4-10, width 1-8, depth 0.5-4. Marketplace textures up to 2048x2048.
- These avatar budgets bind player avatars and Marketplace items, not custom in-experience rigs. Project budgets are separate.

Export: apply transforms, root at origin, one material with an atlas where possible, stable part names, glTF or FBX. Verify after import: sizes, pivots, texture, then animation.

Rig choice: AnimationController with Animator for non-Humanoid units; R15 or Avatar Setup for player avatars; anchored rigid-part rigs when the server moves the model. Keep tower-defense roots stationary and time attacks with animation markers. The server decides gameplay; effects are client-side.

Optimization: reuse one atlas, few materials, drop hidden geometry, check the worst camera case with many units on screen.
