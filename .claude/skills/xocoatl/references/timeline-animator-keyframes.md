# Keyframes & Easing

## What is a keyframe?

A keyframe is a value locked to a specific time on a specific property track. The plugin automatically interpolates (tweens) between consecutive keyframes using the easing you set.

For example, if you keyframe Position at 0s as 0.5, 0, -0.2, 0 and at 0.5s as 0.5, 0, 0.5, 0, the element slides in from off-screen over half a second.

## Creating keyframes

Method 1 — Edit the value field on the track row:

- Move the scrubber to the time you want.

- Click the value text field on the property track row.

- Type the new value and press Enter.

- A keyframe is placed automatically at the scrubber time.

For compound properties (Position, Size, AnchorPoint, etc.) the field uses comma-separated values. For example, Position uses xScale, xOffset, yScale, yOffset — e.g. 0.5, 0, 0.5, 0.

Shorthand for compound values: If you type a single number (e.g. 0 or 1) into a compound field, that value is applied to all components at once. For example, typing 0 into a Position field sets all four components to 0. This makes it quick to zero out or set uniform values.

Method 2 — Pose the live preview:

Click the preview UI in the Studio viewport. Move and scale handles appear on the selected element (Designer-style corners and outline). Drag a handle to write Position or Size — a keyframe is created at the current scrubber time. Explorer stays empty while the Animator has focus.

Method 3 — Studio Selection:

Select one or more preview clones (under StarterGui/_UIAnimPreview) or the original UI in Explorer. The Animator pose overlay stays off so you can drag those objects in the viewport with Studio’s tools, or change values in Studio’s Properties panel. A viewport or Properties drag is captured as start → end at the playhead (not every frame), using the same auto-key preference as the track fields. Click back into the Timeline window to clear Explorer and use Animator shortcuts or the pose overlay again.

For colour, text, image, and other non-spatial properties, use the track value field (Method 1) or Method 3.

## Moving keyframes

- Drag a single keyframe — click and drag the diamond left or right on the timeline. A small time tag under the ruler shows the exact time.

- Drag multiple keyframes — use the selection box: click and drag on an empty area of the timeline to draw a selection rectangle. All keyframes inside it are selected (highlighted in amber). Then drag any of them — the whole group moves while keeping relative positions.

## Selecting keyframes

Action
Result

Click a diamond
Select one keyframe on that specific property track (clears other keyframe picks)

Ctrl + click a diamond
Add that keyframe to the selection (same as most apps’ multi-select; works in the docked timeline without clicking the 3D viewport first)

Drag on empty space
Draw a selection box — selects all diamonds it touches

Click empty space
Deselect all

Ctrl + click empty space
Keep the current keyframe selection (e.g. before an additive box drag)

{% hint style="info" %}
Per-track selection

Keyframes on different property tracks are selected independently, even if they are at the same time. Clicking a keyframe on Position does not select the BackgroundTransparency keyframe at the same timestamp.

{% endhint %}
With multiple keyframes selected:

- Drag to move them all together

- Delete button removes all selected keyframes

- Right-click → Easing applies the chosen easing to all of them at once

## Deleting keyframes

- Select one or more keyframe diamonds and press the delete keyframe button (toolbar).

- Or right-click a diamond (or empty timeline space at a time) → Delete in the keyframe menu.

- Or press X (keyboard shortcut).

Delete uses one shared path for the toolbar, menu, and keyboard — including multi-select, playhead-at-time delete, and UI, effect, and particle tracks.

{% hint style="info" %}
Ghost animations

When you delete the last keyframe of a property, the plugin automatically resets that property on the preview clone back to its original value. This prevents "ghost" animations where an element appears frozen at a stale animated value.

## {% endhint %}

## Easing styles

Right-click a keyframe diamond or empty timeline space to open the keyframe menu — Easing, Copy, Paste, and Delete (with shortcuts where relevant). You can also click an already-selected diamond a second time (no drag) to open the same menu. Choose Easing to open the Animator floating widget (same chrome as Preferences and UI Designer: drag the header, close with ×). Clicks on the widget stay on the widget — they do not rubber-band or select keyframes behind it. If the Timeline dock is too short, the widget shrinks and scrolls. While the editor is Popped-Out, you can drag Easing anywhere on the Studio viewport. Style and direction use Designer fields, with a curve preview.

Style
Feel

Linear
Constant speed — robotic and mechanical

Quad
Gentle acceleration/deceleration — default choice for most UI

Sine
Smooth, slightly softer than Quad

Back
Overshoots slightly before settling — great for "pop" feels

Bounce
Bounces at the end — energetic/playful

Elastic
Springy overshoot — use sparingly for personality

Each style also has a direction:

Direction
Meaning

In
Starts slow, ends fast

Out
Starts fast, ends slow ← most common for entrance animations

InOut
Slow at both ends, fast in the middle

{% hint style="success" %}
Best practice

For UI entrance animations use Out (slow landing feels polished). For exit animations use In (accelerates away quickly). For looping effects use InOut or Linear.

## {% endhint %}

## Time tag

While dragging a keyframe or scrubbing the playhead, a small tag under the ruler follows along and shows the exact time.

## Multi-track editing

The timeline shows one row per property per element. Keyframe multi-select and track multi-select are separate:

- Ctrl+click diamonds to add keyframes to the keyframe selection, or use the selection box across rows.

- Move selected keyframes together.

- Apply easing to selected keyframes via the right-click menu.

- Click a property row name to make it the active track for copy/paste.

- Ctrl-click another compatible property row name to add it to the track selection.

- Right-click a compatible property row name to toggle it in or out of the track selection without replacing the current selection.

Track multi-select only groups rows that can share edits safely. Normal UI property tracks must have the same edit format, or be in a compatible group such as the transparency tracks (BackgroundTransparency, ImageTransparency, TextTransparency, GroupTransparency). Particle tracks are selected separately from normal UI property tracks.

With multiple compatible tracks selected, value edits, relative-mode changes, and paste operations can apply to every selected track where that operation is valid.

## Copy & Paste track keyframes

Copy a track (Edit → Copy Keyframes or Ctrl+C by default):
Click the property name on a track row to select that track, then copy. All keyframes on that track are copied.

Copying keyframes at the playhead (with no track row selected) replaces any previous full-track copy, and the reverse is also true — only the last copy mode is kept for paste.

Paste keyframes (Edit → Paste Keyframes or Ctrl+V by default):
Pastes copied keyframes onto the currently selected track. After a keyframe copy, Ctrl+V stays on those keys even if you click the 3D view — Studio will not paste the last Explorer instance into Workspace. Copy or cut in Explorer when you want Studio paste back. The paste only succeeds if the target track is the same property type, or belongs to the same "transparency group" — for example, BackgroundTransparency, ImageTransparency, TextTransparency, and GroupTransparency can all be pasted to each other.

Effect tracks — Edit → Copy / Paste Keyframes applies to keyframes on effect property rows the same way as on regular UI instance tracks.

You can also select multiple compatible tracks and paste to all of them at once. If the selected tracks are incompatible, the plugin keeps the selection from mixing them and shows a warning instead of pasting unsafe data.

Duplicate (Keyframe → Duplicate): copies the same set as Copy (selected diamonds, or keys at the playhead) and pastes them immediately. If the paste would land on the same times, the copies are offset by one frame (1/30 s). One Ctrl+Z removes the duplicates. The existing Copy clipboard is left unchanged.
