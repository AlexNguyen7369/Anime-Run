# UI Tools — Overview

The UI Tools widget gives you a set of utility tools for editing UI elements faster. Open it by clicking Tools in the plugin toolbar.

The widget has 6 slots — two tall slots on the left and four smaller slots on the right. Drag tools between slots to arrange them however you like.

When you pick a tool for a slot, the chooser is a scrollable list of tools (icon + name). Optional plugin overlays (viewport breadcrumbs, etc.) are not slot tools — they are configured under Xocoatl features (below).

## Xocoatl features

Xocoatl features is a small dialog for optional Studio-only conveniences (things that sit on top of the editor, like a selection breadcrumb). It is separate from slot tools and separate from Xocoatl → Preferences (menu-bar preferences).

Defaults — These features are off until you turn them on. Your choices are saved with the plugin.

### How to open it

- Click Tools on the Xocoatl plugin toolbar to open the Tools widget (the tools dock).

- Open Xocoatl features in either way:

- From the list — Click the row labelled Xocoatl features (preferences-style icon + title), in the same list area as Align, Rich Text, etc.

- From the top bar — Use the Xocoatl features icon in the top bar of the Tools dock (shown when that shortcut is enabled in Preferences).

### Viewport: selection path

- In the dialog, find the VIEWPORT section.

- Enable Selection path in viewport.

- A breadcrumb appears at the top-left of the Studio viewport. It shows the Explorer path to whatever you currently have selected (any instance: Workspace, services, StarterGui, models, scripts, etc.).

- If the path is long, segments on the left collapse to icon-only chips. Hover the icon on a collapsed chip to expand that segment briefly; moving away collapses it again.

### Saves: locate persistence root

If Xocoatl cannot find your saves folder, or more than one folder is tagged XocoatlPersistenceRoot:

- Select exactly one Folder in Explorer (your intended saves root).

- In Xocoatl features, click Locate Xocoatl Saves Folder.

Xocoatl moves the persistence tag to that folder and creates any missing child folders (SavedUIAnimations, SavedUIAssets, etc.). Rig clips are stored on the character (AnimSaves container, shared with Moon Animator), not in this root. See Saves & Folders.

Undo / Redo — Edits to the place file go through Studio’s Edit → Undo and Edit → Redo. Tools that change instances (Align, Simple Move, Conversion, UI Converter, Color Presets apply, Rich Text toolbar / color / Enable) each use ChangeHistoryService recordings (TryBeginRecording / FinishRecording) so one button action is usually one undo step. In Rich Text, plain typing in the editor is not split per keystroke. If recording cannot start (rare), the plugin falls back to a waypoint. Changes made only inside the plugin UI are not part of that stack.

## Available tools

### Align

Snaps the AnchorPoint and Position of selected GuiObjects to one of 9 positions on a 3×3 grid:

Top-Left     Top-Centre     Top-Right
Middle-Left  Centre         Middle-Right
Bot-Left     Bot-Centre     Bot-Right

Click any cell to apply. Works on multiple selected instances at once.

### Simple Move

Nudges selected GuiObjects by a fixed step.

- Toggle between Scale and Offset mode.

- Adjust the step size.

- Click the directional arrows (↑ ↓ ← →) to nudge.

### Color Presets

Browse and apply your saved colour presets to selected elements. Presets are organised into palettes (folders), matching the same palette system in the Color Picker widget.

Palette navigation — the tool opens in the preset grid view for the last-used palette. Click the folder icon in the top-left of the nav bar to switch to the palette browser, which shows all your palettes as a scrollable list with colour pill previews and a preset count. Click any palette row to open it.

Applying a preset — with one or more GuiObjects selected in Studio, click a preset swatch. Use the Apply to buttons at the bottom of the panel to choose whether the colour is applied to the element's Background, Text, or Image colour property. When a gradient preset is selected, an Apply gradient icon appears (same idea as in the Color Picker): it updates or creates a UIGradient on each applicable selected instance, including Type / TileMode / Scale when the preset stored them.

{% hint style="info" %}
The Color Presets tool is read-only — you can browse and apply presets but you cannot create, rename, or delete them here. Manage palettes and presets from the standalone Color Picker widget.

## {% endhint %}

### Conversion

Converts UI measurements between Scale and Offset, or adds constraints:

- Size Scale → Offset — convert a Size in scale to the equivalent pixel offset at the current screen size.

- Size Offset → Scale — reverse conversion.

- Position Scale → Offset / Offset → Scale — same for Position.

- Add Aspect Ratio Constraint — wraps the selected element in a UIAspectRatioConstraint sized to its current aspect ratio.

### Rich Text

A WYSIWYG rich text editor for TextLabel / TextButton / TextBox elements.

Formatting options:

Button
Effect

B
Bold

I
Italic

U
Underline

S
Strikethrough

Color
Text colour (opens Color Picker)

Highlight
Background highlight colour

Size
Font size override

Weight
Font weight

Alpha
Text transparency

Stroke
Text stroke

Changes sync live to the selected element in the viewport. Toolbar icons show a short label on hover (Bold, Underline, etc.).

{% hint style="info" %}
RichText must be enabled on the element for rich text tags to render in-game.

## {% endhint %}

### UI Converter

Converts a UI instance from one class to another while preserving all shared properties and reparenting all children.

Supported conversions:

- Frame ↔ CanvasGroup

- Frame ↔ ImageLabel

- Frame ↔ ImageButton

- Frame ↔ TextLabel

- Frame ↔ TextButton

- (and most other combinations)

Select the element, choose the target class, click Convert. Non-applicable properties (e.g. Text when converting to a Frame) are silently ignored.

### Copy Path

Shows the dot-separated Explorer path of the selected instance.

- Toggle whether to include or exclude the top-level container.

- Click inside the text area and press Ctrl+A → Ctrl+C to copy.

Useful for referencing specific UI elements in scripts.
