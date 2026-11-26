# UI Designer — Overview

UI Designer is a visual layout editor for Roblox ScreenGuis, built into the Xocoatl plugin. Open it from the UI Designer toolbar button.

If you have used Figma or similar tools, the layout should feel familiar: a canvas you pan and zoom, a layer hierarchy, and property controls on the side. Edits apply to real instances in your place (Frame, TextLabel, UIStroke, and so on) — there is no separate export step.

Public beta — there will be bugs

UI Designer is beta. There will be bugs, missing tools, and behaviour that may change. Do not treat it as production-finished. If you find a bug, please tell me on the Developer Forum plugin thread or Discord. A short beta notice appears the first time you open the widget (Help ? on the side rail shows it again).

## Opening

- Click UI Designer on the Xocoatl toolbar.

- You land on the Projects home: cards for every ScreenGui Xocoatl can find in StarterGui, ReplicatedStorage, ServerStorage, and Workspace.

- Click a card to open that screen on the canvas, or use the logo menu → New Project to create a new ScreenGui.

The first-open beta card can be dismissed with Don't show again. Re-open it anytime from the ? button on the left rail.

## Layout

Area
Where
Purpose

Side rail
Far left
Logo menu (New Project / Back to Projects), Variables, Help, plugin update check, Preferences, Themes (same pack chooser as the Timeline Animator)

Hierarchy
Left
Layer tree for the open ScreenGui. Inline rename, multi-select, drag to reparent

Canvas
Centre
Artboard + pan/zoom. Draw frames, select, move, resize

Properties
Right
Inspector for the selection (fill, stroke, layout, text, and more)

Bottom toolbar
Over the canvas
Select and Frame tools

Tool strip
Top of the canvas
Zoom in / out / fit, and the viewport size preset (phone / tablet / computer / custom)

## Workflow

### 1. Open or create a project

Pick an existing ScreenGui from the home gallery, or New Project. Projects are real ScreenGuis in the place — renaming them in Explorer is the same object.

### 2. Draw and select

Choose Frame on the bottom toolbar and drag on the artboard. If a frame is already selected, new frames nest inside it. Switch back to Select to move and resize.

Change the class later in the inspector (Frame, CanvasGroup, ScrollingFrame, TextLabel, TextButton, TextBox, ImageLabel, ImageButton) — shared properties and children are kept.

### 3. Edit properties

Use the Properties panel for fill, stroke, shadow, layout, text, images, and scrolling. Colour and number fields can link to design variables.

### 4. Arrange

Right-click on the canvas or in the hierarchy for Copy / Paste / Duplicate / Delete / Rename, plus Group, Ungroup, Tidy up, Distribute, Align, and Match size. Ctrl+Z / Ctrl+Y undo and redo designer edits only. Opening a ScreenGui — or starting a new one from the canvas — sets an undo floor so undo cannot walk back through the import/paste that created the tree, or delete layers that were already there.

## What this is not

- It does not replace the Timeline Animator. Layout here; animate there.

- Components (reusable linked masters) are not in this beta. Do not look for a Components button on the rail.

## Next

Goal
Page

Pan, zoom, snap, spacing, handles
Canvas & tools

Inspector sections and type convert
Inspector

Reusable colours, numbers, gradients
Variables

Play animations in-game
Install Runtime
