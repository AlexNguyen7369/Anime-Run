# Timeline Animator — Particles (experimental)

{% hint style="warning" %}
Experimental

2D UI particles are new and may change in behaviour, defaults, or save format. Prefer them for prototyping and non-critical UI until you have tested your shipped build. Report issues via Options → Report in the plugin.

{% endhint %}
Particles let you drive Roblox-style 2D particle behaviour on a GuiObject host (for example a Frame) from the same timeline you use for layout and colour. They are not a replacement for world-space ParticleEmitter in the 3D workspace — they are for ScreenGui / LayerCollector UI.

## What you need

- An animation open in the Timeline Animator (same as for any other tracks).

- A supported host — typically a Frame (or other GuiObject the plugin lists). Use the element header ⋮ menu → Make Particle Frame to attach a particle system to that row.

- The in-game runtime installed and updated so playback matches the editor. See Install Runtime.

## Workflow (short)

- Make Particle Frame on the element you want to emit from.

- The Particles section appears under that element. Core particle rows are added automatically. Expand the Physics folder for motion / velocity / locked-to-frame settings; optional rows show an Add pill until you enable them (or use the Particles [+] picker).

- Keyframe properties that support the diamond (◆) like other tracks — scrub the playhead, edit the value, or press your Add Keyframe shortcut.

- Number sequences (Size / Transparency over each particle’s life): when the row shows Seq, open the sequence editor. Edits can preview live on the clip; Confirm keeps them, Cancel restores the state from when you opened the editor.

- Preview in the plugin while scrubbing or playing, then test in Play mode with the runtime.

## Keep particles after the clip ends (runtime)

When you want sparks (or any 2D timeline particles) to keep spawning after the clip has finished playing forward — for example a button intro that ends on a steady sparkle — enable Keep emitting after clip ends on the clip:

- In the Track list, expand a Particles section: the clip-wide rows Keep emitting after clip ends and No particle emit on reverse appear at the bottom of that section (not on the timeline).

The flag is stored on the clip JSON (keepEmittingWhenStopped). Older clips default to off until you turn it on and save.

### No particle emit on reverse

When No particle emit on reverse is on (noParticleEmitOnReverse in JSON), reversed playback (e.g. hover-out) does not spawn new particles; existing particles still run out their lifetimes. Forward playback is unchanged. Enable it from the same Track list block (bottom). The runtime also avoids viewport-culling those tails during drain / no-new-spawn steps (so a layout jump on hover-out does not delete them), and if the emitter is briefly missing from the tree, tails age out in screen space instead of being wiped in one frame.

At runtime:

- Applies only when the clip completes naturally at end time (t = duration), not when you reverse out of a hover or call stop().

- Requires Enabled to be on (not false) for at least one emitter when sampled at the last frame; if every emitter is off at the end, particles drain as usual.

- Enabled keyframes during the clip still turn emission off on those segments as today.

- Emission stops when the same playback key runs again, or you call Anim.stopOn, Anim.clearInstance on that UI root, Anim.stopAll, or Anim.refresh.

See UIAnimController — 2D particles.

## Core vs optional rows

Most particle rows are core rows. When you choose Make Particle Frame, these rows stay with the particle system so the runtime has a complete emitter definition.

Only the physics rows below are optional (add them from the Physics folder or the Particles [+] picker):

- Motion — constant acceleration in screen pixels per second squared.

- Velocity Inheritance — how much of the host frame’s movement is added to newly spawned particles.

Locked To Frame lives in the same Physics folder (always available; not removable).

The Particles row [+] picker lists the optional physics rows. The [⋮] menu on the Particles header removes the whole particle system from that frame.

## Value types

- Timeline-keyframed values show a diamond (◆). Edit the value at the playhead to create or update a keyframe.

- Clip-wide values do not use timeline diamonds. They apply to the whole particle system for the clip.

- Sequences describe a value over each particle’s own lifetime. Size and Transparency use the Seq editor. Colour can use a gradient-style lifetime colour sequence.

- Random ranges can be typed as min,max on supported number rows. For example, -180,180 on Emit Rotation lets each spawned particle pick a different start rotation.

## Particle properties

Property
Type
Timeline?
Notes

Colour
Color3 or ColorSequence
Sometimes
Solid colours can be keyframed. A ColorSequence is clip-wide and controls colour over each particle’s lifetime.

Timeline Active
Boolean
No
Forces Colour to behave as a clip-wide lifetime value instead of timeline colour keyframes. Turning it on clears existing Colour keyframes after confirmation.

Texture
String
No
Image id used by spawned ImageLabel particles, such as rbxassetid://....

Transparency
Number or NumberSequence
Sometimes
Single numbers can be keyframed. NumberSequence values are clip-wide lifetime fade curves edited with Seq. 0 is opaque, 1 is invisible.

Size
Number or NumberSequence
Sometimes
Single numbers can be keyframed. NumberSequence values are clip-wide lifetime size curves edited with Seq.

ZIndex
Number
Yes
Draw order for spawned particle images.

Frame Rotation
Number
Yes
Rotates the emitter basis in degrees. Spawn direction follows this basis.

Emit Container
ScreenGui / Emitter
No
ScreenGui uses a full-screen layer. Emitter parents particles under the host frame so they stack with or clip inside it.

Emission Direction
Top / Right / Bottom / Left
Yes
Chooses which edge of the host rectangle particles spawn from.

Enabled
Boolean
Yes
Master switch for spawning new particles.

Life Time
Vector2
Yes
Random lifetime range in seconds. X is minimum, Y is maximum.

Rate
Number or min,max
Yes
Particles per second while enabled. min,max creates an uneven random rate. Clamped to 0–500.

Emit Rotation
Number or min,max
Yes
Extra spawn rotation in degrees. Supports random ranges such as -180,180.

Rotation Speed
Number or min,max
Yes
Spin speed in degrees per second. Each particle picks its own value when a range is used.

Speed
Number or min,max
Yes
Initial launch speed in pixels per second. Supports random ranges.

Spread Angle
Vector2
Yes
Motion cone around the emission direction. X is minimum spread, Y is maximum spread.

Motion
Vector2
Yes
Optional. Constant acceleration in screen pixels per second squared. Add from the Physics folder.

Locked To Frame
Boolean
Yes
When enabled, spawned particles follow the host as it moves or resizes. In the Physics folder.

Velocity Inheritance
Number
Yes
Optional. How much host movement is added to new particles. 0 means none, 1 means full carry. Add from the Physics folder.

## Tips

- Transparency uses Roblox’s convention: 0 = opaque, 1 = invisible (in sequences and single numbers).

- Emit Container defaults to ScreenGui, which uses a full-screen particle layer. Switch to Emitter when particles should stay under, stack with, or be clipped by the host frame.

- Emission can be pinned to edges (for example Right). Locked to frame and velocity inheritance follow the host’s motion (including resize) where supported — see property tooltips in the Track List for details.

For general editor layout, see Overview. For property categories on normal UI rows, see Properties.
