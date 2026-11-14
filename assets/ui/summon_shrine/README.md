# Blossom-shrine hybrid background

Owner approved the generated blossom-shrine v2 composition on 2026-11-14. `Backdrop.png` is the corresponding clean plate with the painted platform, front props and baked petals removed. The real local stage/foreground props and the existing character models render in front of it.

Client integration: `src/client/SummonHybrid.luau`, attached by `SidekickUi.client.luau`. It deliberately falls back to the existing galaxy presentation until `ReplicatedStorage.SummonScreenAssets` has a valid `HybridBackdropImage` attribute containing the actual uploaded image URI. No invented asset ID is registered.

Installed 2026-11-14 in Anime Run, place 102957063656302. Backdrop image: `rbxassetid://119528763151983`. Registered in Studio and the saved native `SummonScreenAssets.rbxm`. SurfaceGui orientation and stage framing were visually checked in the 1024x499 edit viewport; front/back native foreground geometry was inspected. The scripts were read back after installation. File > Save to Roblox completed, confirmed by Studio Output; the experience was not published to live players.

Live Play verification is still pending because auto-playtest is disabled and approval was requested. Actual server-delivered characters/auras, summon controls, mobile landscape UI, animation phases, and close/reopen restoration must be checked in Play. Sidekick models are delivered at runtime; the edit-context preview could not load the existing private model asset, so no in-game character result is claimed.

The existing plaza petal image is reused: image 130260166899982, recorded in `tools/blender/plaza/plaza_assets.json`. Character aura source remains Anime auras pack 18515382827; no new pack was added.

The generated clean plate is a static image. Lantern and shrine-crystal glow in that image is baked; the foreground stage ring, petals, character models and their existing auras are independent live elements.

## Shrine controls and stationary floor (2026-11-14)

`SummonShrineTheme` applies the warm wood/burgundy/gold palette to the native template and runtime controls. `SummonHybrid` translates its foreground and clean backdrop with the camera so the floor has no mouse-driven screen drift; only character parallax and background petals animate independently.

Reproducible tooling (pass the absolute repository path as the last argument):
- `lune run tools/summon/apply_shrine_theme.luau <repo>` verifies theme idempotence, action captions and button layout while updating the native UI model.
- `lune run tools/summon/check_hybrid.luau <repo>` checks fallback, unit preservation, geometry, reduced motion, cleanup and floor projection across 24 viewport/mouse cases.
- `lune run tools/summon/register_hybrid_backdrop.luau <repo> 119528763151983` updates the saved native asset registration.

Selene reports zero errors/warnings for the three changed client scripts; the full Rojo project builds successfully. No new automatic Play session was started.
Latest theme/floor installation saved to Roblox as place version 759 (Save only). Offline projection checks across all foreground parts and the backdrop measured a maximum drift of 0.0018 pixels, within floating-point precision tolerance.
