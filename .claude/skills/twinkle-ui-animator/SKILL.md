---
name: twinkle-ui-animator
description: "Use Twinkle (UIAnimator), a client-side Roblox Luau UI animation module, in any Roblox project: Fade, FrameSlide, FrameZoom, FrameBounce, Sequence, ShowText effects, button hover and press presets, Shake, ripple, blur, and tag-driven behaviours. Use when a Roblox project wants ready-made UI motion without writing tween boilerplate, or when the owner names Twinkle."
---

# Twinkle UIAnimator

Source: https://github.com/leo-prad/Twinkle-UIAnimator- (wally `caioband/twinkle@0.0.9`, MIT per `wally.toml`). A local copy of the source is here: `init.lua`, `Presets/`.

Read `README.md` for the topic table, then only the `docs/` page the task needs. `docs/reference/` lists every attribute, tag and type.

## Before using it in a project
- It is a new dependency: it needs `sleitnick/trove` and `arxkdev/ezvisualz`. Check the project's rules allow one, and ask before adding it.
- Check the project's own motion layer first. If rules route all motion through one module (for reduced-motion handling, for example), a direct Twinkle call bypasses it. Twinkle's own effects must honour the same setting.
- It is client only: it reads `Players.LocalPlayer`. Never decide gameplay in it.
- Tag and attribute behaviours wire up on load, including later instances. Check that no tag name collides with the project's tags.

## Choosing
- One-off frame, text or button motion: the scripting API.
- Designer-wired effects from Studio: tags and attributes.
- Keyframed clips with per-key easing: use the `xocoatl` skill instead.
- A frame-accurate sequence synced to server data: plain TweenService may be simpler and is easier to test.
