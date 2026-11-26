---
name: design-roblox-anime-character
description: Create evidence-backed Roblox references and production specs for anime characters, preserving canonical identity while adapting to a Roblox format and gameplay role. Use for designing, redesigning, turnaround sheets, modeling briefs, Blender assets, rigs, animation sets, or Roblox import packages of a named anime character, and when checking such a model for likeness, technical limits or IP status.
---

# Design Roblox Anime Characters

Create evidence-backed Roblox character references and production specifications. Preserve a requested character's canonical identity while making only the changes needed for the selected Roblox format and gameplay role.

## Core workflow

1. Define the character, franchise, canonical version, outfit or form.
2. Define the deliverable: concept render, turnaround, modeling brief, Blender asset, rig, animation set, or Roblox import package.
3. Define usage: private prototype, public experience, Marketplace item, or commercial release.
4. Define the rig target: tower-defense NPC, custom Humanoid, R15 avatar, or static display.
5. Research canonical attributes from current public sources.
6. Produce an evidence table and resolve contradictions.
7. Generate or specify the character using the canonical evidence.
8. Validate identity, model readability, technical constraints, and IP status.
9. Package requested outputs with one-to-one filenames and a manifest when producing multiple characters.

## Research canonical identity

Browse the web whenever the character, current appearance, official licensing status, or Roblox requirements could have changed. Read [references/ip-research.md](references/ip-research.md) before researching.

Record the full name, franchise, continuity, version, proportions, silhouette, hair, face, markings, clothing layers, color relationships, footwear, weapons, accessories, symbols, and unusual features. Include powers or effects only when requested.

Do not use fan art as the sole authority. Separate supported canon facts from visual inference. Ask one focused question when multiple canonical versions would materially change the model.

## Choose the output path

### Concept render

Use image generation for a polished 3D visual reference. State that the result is a raster concept, not an importable mesh. Follow [references/character-design.md](references/character-design.md).

### Modeling turnaround

Generate each character separately with front, side, back, and three-quarter views. Require a neutral A-pose or T-pose, orthographic framing, identical proportions, flat readable lighting, and no effects, bases, weapons crossing the body, or perspective distortion.

### Blender-ready specification

Produce a proportion guide, mesh-object list, topology target, UV and texture plan, materials, rig hierarchy, naming convention, animation list, event markers, and Roblox export checklist. Read [references/character-design.md](references/character-design.md) and [references/roblox-pipeline.md](references/roblox-pipeline.md).

### Importable 3D asset

Do not claim that a generated image is a 3D model. Use Blender or another real modeling application to create geometry, UVs, textures, rigging, weights, and animations. If Blender automation is requested, generate a Blender Python blockout only after defining measurements and object names, then render and inspect it. Treat automation output as a starting point requiring artist review.

## Roblox design rules

- Optimize silhouettes for the actual camera distance.
- Prefer chunky readable hair clumps and accessories over microdetail.
- Model important outlines; texture small facial and clothing details.
- Keep materials and draw calls low.
- Keep each vertex at no more than four bone influences.
- Keep the root at the origin and apply clean transforms before export.
- Use an AnimationController with an Animator for non-Humanoid tower-defense units.
- Use R15 or Avatar Setup when the character must behave as a player avatar.
- Keep tower-defense roots stationary; synchronize attacks with animation markers.
- Use server-authoritative gameplay and client-side cosmetic effects.

Read [references/roblox-pipeline.md](references/roblox-pipeline.md) for detailed export, import, animation, and optimization guidance.

## Identity validation

Before delivery, verify that the version is unambiguous, defining attributes are present, views agree, colors remain consistent, and the model is readable from the intended camera. Reject mixed forms, swapped accessories, missing markings, fused hands, contradictory views, or extra characters. Never label concept art as a mesh.

## IP and publishing boundary

Public information can support research, but public availability does not grant permission to publish or monetize an exact copy.

- Label exact-IP private work as an unlicensed reference unless the user provides evidence of rights.
- For public Roblox experiences, Marketplace assets, or commercial releases, verify a Roblox-supported license or explicit permission.
- If licensing is absent or uncertain, continue only with private reference work or offer an original anime-inspired redesign that changes protected names, symbols, outfits, silhouettes, powers, and other distinctive expression.
- Never state that credit, non-monetization, or public availability makes exact use legally safe.

## Deliverables

When asked for a package, use [references/output-templates.md](references/output-templates.md). Include source citations near supported attributes. Keep filenames stable and avoid merging multiple characters unless the user requests a lineup.
