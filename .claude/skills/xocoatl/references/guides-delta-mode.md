# Delta Mode

## What it is

Every property track has a delta toggle (the triangle button on the right of the track row). When it is off, keyframe values are stored as absolute values — the exact property value at that time. When delta mode is on, values are stored as offsets from where the element starts.

The toggle is grey when off. When on, it lights up in bright blue.

## Why it matters

Imagine you want a "slide up by 20 pixels" effect. Without delta mode you would need to know where the element is positioned and bake that into the keyframes. Move the element later and the animation breaks.

With delta mode, the keyframes say "start at 0 offset, end at -20px offset". The animation works regardless of where the element is placed — the 20px shift is always relative to whatever the element's position is when the animation starts.

## When to use it

Use absolute values (delta off)
Use delta mode (on)

Intro/outro animations tied to fixed screen positions
Reusable "nudge", "bounce", or "shake" effects

Any animation where the start position is always the same
Animations that need to work on elements in different positions

Clip is only ever applied to one element
Clip applied to many different elements

## How to enable it

- Add the property track as normal.

- Click the triangle (△) button on the right side of the track row. It turns bright blue when active.

- Add your keyframes. Value 0 means "same as where the element started". Positive or negative numbers are offsets.

## Delta and template animations

Delta mode pairs naturally with Template Animations. When you create a clip that can be applied to any element, delta mode ensures the values are relative so the animation works regardless of where each instance starts.

For example, a "button press" animation might shrink the element slightly and bounce back:

- Size track with delta on: keyframe at 0s = 0, 0, 0, 0, at 0.08s = -0.05, 0, -0.05, 0, at 0.18s = 0, 0, 0, 0

Any button of any size gets scaled down by the same relative amount and bounces back.

## Technical note

Delta values are stored as offsets from the snapshot taken when the animation starts. If the element's property changes between sessions (e.g. repositioned in the editor) and the animation plays again, the runtime takes a fresh snapshot. The animation still shifts the element by the authored offsets.
