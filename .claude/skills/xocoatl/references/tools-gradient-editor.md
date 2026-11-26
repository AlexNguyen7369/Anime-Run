# Gradient Editor

The Gradient Editor is a separate dock window opened from the Color Picker. The button reads Gradient editor… by default, or Edit selected gradient when a UIGradient (or a GuiObject that already has a UIGradient child) is selected in Studio — then edits preview live on that instance.

## What it does

- Edit a ColorSequence with multiple colour stops, and per-stop alpha mapped to UIGradient.Transparency as a NumberSequence (value 0 = opaque, 1 = clear; envelope 0).

- Endpoints are fixed at t = 0 and t = 1 (first and last stop); only middle stops can be moved on the bar.

- Multi-select — Rubber-band drag on the track background (not on a handle) selects stops in the rectangle; Shift+click toggles stops in the selection. Drag a selected middle stop to move all selected middle stops together. Remove deletes every selected middle stop (endpoints are never removed).

- Time for the primary selected stop (first in time order among the selection) can be typed in the Time field (0–1) for middle stops; endpoints show 0 / 1 and are read-only. Use the toolbar icons beside it to save as preset, add a stop at t = 0.5, or remove selected middle stop(s).

- Colour for the selection is edited in the main Color Picker: click a stop so the picker matches the primary stop; changes in the picker update every selected stop live (no separate “pick colour” step). If you close the Color Picker while the gradient window stays open, click a stop again (or start dragging it) to reopen the picker and keep editing.

- Rotation, offset, Type, TileMode, and Scale are not edited in this window. Confirm and live preview pass them from the initial payload (current UIGradient when the editor opened) so timeline tracks for those properties are not reset. Edit Type / TileMode / Scale on the timeline (when Studio exposes Upgraded UIGradients) or in the UI Designer fill gradient editor.

- Save the gradient as a preset into the active palette — same list as solid colours (ReplicatedStorage → XocoatlSaves → ColorPresets by default, found by the XocoatlPersistenceRoot tag). Preset JSON stores colour stops, per-stop transparency (same times as the colour stops), rotation, offset, and the upgraded Type / TileMode / Scale when present, so Apply gradient and the Color Presets tool keep the same look.

## Opening it

- Open the Color Picker (from the Tools dock top bar, or from a swatch in the Timeline Animator).

- Click Gradient editor… or Edit selected gradient above Cancel / Confirm.

In the picker’s top apply row (with Apply BG / Text / Image), the Apply gradient icon appears only when a gradient preset chip is selected. It writes that gradient to the Studio selection (updates an existing UIGradient or creates one on the selected GuiObject).

Using solid presets while editing: select a stop in the gradient editor, then click a solid preset — the selected stop takes that colour (the solid preset becomes selected, not a gradient preset). Clicking a gradient preset selects it for Apply gradient and does not open the editor; use Gradient editor… or Edit preset to edit that sequence.

Confirm applies the GradientPayload (color, transparency, rotation, offset, plus optional gradientType / tileMode / scale) to any callback your tool supplies via onGradientConfirm.

## Presets

Load from the Color Picker’s preset grid: click a gradient swatch to select it (then use Apply gradient or open the editor). Right-click and choose Edit preset to change that saved preset (use Confirm edit / Cancel edit on the main Color Picker — see Color Picker). Rename/delete from the context menu like solid swatches.

## Sharing / backup

Preset data is JSON in StringValues. See Saves & Folders for export patterns.
