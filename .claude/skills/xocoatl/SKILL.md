---
name: xocoatl
description: "Use Xocoatl, a Roblox Studio plugin and runtime for keyframed UI animation (Timeline Animator, UI Designer, Gradient Editor) with UIAnimController playback: Anim.play, playOn, playBatch, bindHover, delta mode, template animations. Use when a Roblox project wants authored timeline UI clips, or when the owner names Xocoatl."
---

# Xocoatl

Docs: https://chocobasta.github.io/Xocoatl/ (saved copy in `references/`, taken 2026-11-04; early access, so check the live changelog when a detail matters).

## What an agent can and cannot do
- The plugin is installed by the owner from Studio's Plugin Manager. Timeline clips are authored in its widget, by a person.
- The runtime goes in once per place, from the plugin's Status button, at `StarterPlayerScripts/Xocoatl`. Keep plugin and runtime versions in sync.
- An agent can write the LocalScript calls to `UIAnimController`. Those need clips that exist in the place. Clip saves live in the place, not in Rojo source, so check how a project syncs them: read `references/timeline-animator-saves.md`.
- If no owner is available to author clips or install the plugin, say so, and use TweenService instead.

## Which page to read
- API, options, signals, interruption rules: `references/runtime-uianimcontroller.md`
- Install and first clip: `references/getting-started.md`, `references/runtime-install.md`
- One clip on many elements: `references/guides-delta-mode.md`, `references/guides-template-animations.md`, `references/guides-reuse-and-batch.md`
- Hover: `references/guides-hover-animations.md`
- Authoring rules: `references/timeline-animator-dos-and-donts.md`, `-concepts.md`, `-keyframes.md`, `-properties.md`, `-particles.md`, `-overview.md`
- UI layout and gradients: `references/ui-designer-overview.md`, `references/ui-tools-overview.md`, `references/tools-gradient-editor.md`

## Before using it in a project
- It is a new dependency. Check the project's rules allow one, and ask first.
- If rules route all motion through one module (for reduced-motion handling, for example), clips bypass it unless the caller skips or scrubs them under that setting.
- Display only: the client plays clips, and the server still decides results.
