# Timeline Animator -- Overview

The Timeline Animator is a keyframe-based UI animation editor built into Roblox Studio. You add the elements you want to animate to your tracks, choose which properties to animate, set values at specific times, and the plugin smoothly interpolates between them.

## Opening the editor

Click Timeline Animator in the plugin toolbar. If no animation is loaded you will see the landing screen — a center card. When you select a UI target that already has saves, the card lists them and grows with the list (capped to the widget height, scrolling past that). The timeline playback bar and Track List stay hidden until a save is open. The title bar (docked or Pop-Out) holds Animation / File / Edit / Options, plus Themes, Status, and Pop-Out (docked) or Minimize / Pop-In / × (Pop-Out). Docked close is the Studio widget ×. Character / Motor6D rig targeting is off in this build.

Area
Purpose

Center card
Idle setup steps; Open Saves; Set Target / Use Template when a UI target needs them; compact list of animations linked to the selected UI

Themes (title bar)
Browse and apply theme packs

Status (title bar)
Runtime and plugin versions on chips (v0.084, v0.2.1 - B41 - P13), status, Install / Update / Reinstall, and a plugin update Check.

From the center card you can also Open Saves, start a New Animation, or open an animation already linked to your Studio selection.

Pop-Out — Options → Pop-Out (or the title-bar icon) moves the whole editor onto the Studio viewport as a floating widget (Moon-style). The title bar matches the dock — Animation / File / Edit / Options, Themes, Status — then Minimize, Pop-In, and × (the docked bar has Pop-Out only; Studio's widget × closes it). There is no second menu bar. Hover tooltips work here too — they live on the viewport ScreenGui and use screen-space placement, not the docked PluginGui. With a save open, the playback bar runs the full width under the title bar. Drag the empty title-bar strip between the menus and Themes to move the host (the docked title bar does not move the Studio widget; Pop-Out uses screen-space mouse, not the docked PluginGui path). Hover just outside the left, right, or bottom edge to slide out a full-length rounded pull-tab (three-line grip) and drag that tab to resize. Tabs match the host height or width and sit behind the title bar. The title bar has no pull-tab; resize from the top with the on-widget corner grabs (down to a compact 400×200). Resize only resizes — it does not start a rubber-band, grab a keyframe, or scrub. Dragging a keyframe or the scrubber out of the host does not resize it; the diamond stays against the visible left or right edge instead of sliding into the chrome. Clicks on the host stay in the editor — rubber-band, keyframes (including moving a multi-select), and the scrubber work there; the preview move/scale box only responds around the widget, not through it. Open Easing, Preferences, and other floating widgets also swallow those timeline gestures — you cannot rubber-band or pick keyframes through the panel. While the pointer is over the host, middle-mouse pans the timeline instead of the Studio camera (plugin exclusive mouse; Studio has no separate “disable camera pan” API). Easing, Preferences and Guided tours can then be dragged anywhere on the viewport, not only inside the host. Double-click the empty title-bar strip to shrink the host to a compact timeline in the top-left (about 40% × 28% of the viewport); double-click again to grow it back. That only changes the widget size — it does not minimize to the mini player. Starting a guided tour grows the host if it is too small for the walkthrough (it never shrinks the size you chose). Pop-In (Options or the title-bar icon) returns the editor to the bottom dock. If the open clip has unsaved changes, Pop-Out and Pop-In ask you to Save (or Save As) first, or Cancel — there is no switch-anyway. × on the popped-out host closes the Animator (same unsaved-changes prompt as the Studio dock widget ×). The last mode and viewport size are remembered.

Minimize (mini player) — Pop-Out only, and only while a save is open (the button is greyed out on the landing screen). The Minimize title-bar button (left of Pop-In, or press G) quickly shrinks the whole editor into a compact player: current time / duration and restore on the title row, play / pause on the left of a scrubbable playhead timeline. Drag the title row to move it; double-click it to restore the full editor. Keyboard shortcuts (Space, comma/period, etc.) keep working while the mini player is up. The restore button or G grows the editor back to its previous spot. The bar position is remembered for the session. Toggling minimize or restore clears hover tooltips, context tips, open menus, and dropdowns so they do not stay stuck over the mini player or the restored host.

## Layout

The editor is split into three panels side by side:

Panel
Location
Purpose

Hierarchy
Left
Shows the full UI tree of the animation target. Has a built-in search bar and click-to-select. Use it to add elements to your tracks.

Track List
Centre
One row per element header and one row per animated property. Scroll vertically together with the Timeline. Drag the divider on its right edge to resize it.

Timeline
Right
Keyframe diamonds, ruler, and playback controls. Scrolls vertically in sync with the Track List, and horizontally independently. With a save open, the playback bar spans the full width (Hierarchy and Tracks sit under it).

The Hierarchy panel can be hidden with the Show Hierarchy toggle in the Track List header to give the tracks more horizontal room.

Hierarchy search bar -- type in the search box (inside the Hierarchy header, to the right of the title) to filter the tree by name. Only matching elements and their ancestors stay visible. Clear the box to see the full tree again.

Add From Selected -- the cursor-plus icon button to the right of the search box lets you add multiple elements at once. Select any elements under the animation target in the Studio Explorer, then click the button. Every selected element that has animatable properties and is not yet in the Track List is added in one go.

Collapse/expand children -- click any element in the Hierarchy to select it, then press L to toggle its children open or closed.

## Workflow

### 1. Set an Animation Target

Select a ScreenGui, Frame, CanvasGroup, or any GuiObject for UI, then click Animation > Set Target... in the menu bar. Character / Motor6D rig targeting is off in this build — selecting a dummy does nothing.

A preview clone of your UI is created in StarterGui/_UIAnimPreview. All editing happens on this clone -- your real UI is never modified while you are working.

The preview clone

The clone is only for editing. When you press Play in Studio the runtime reads the saved animation data and applies it to the real UI, not the clone.

### 2. Open an Animation

Either create a new animation (Animation > New Animation) or open an existing save (Animation > Open Animation...). The animation must be open before you can add tracks or keyframes.

### 3. Add elements to your tracks

In the Hierarchy panel on the left, browse the full tree of the animation target. Click the + button to the right of any element to add it to the Track List. The element header row will appear in the centre panel.

2D particles (experimental) — for a supported GuiObject (Frame, labels, buttons, CanvasGroup), use the element header ⋮ menu → Make Particle Frame, then use the Particles row [+] (searchable picker, like Add property) and [⋮] to remove the whole particle system. They keyframe like other tracks and play in preview and in the shipped runtime. See Particles (experimental) for setup, sequence editing, and caveats.

You can also track the animation target itself (the root) by clicking its + button at the top of the Hierarchy tree.

Adding multiple elements at once — select the elements you want in the Studio Explorer, then click the Add From Selected button (cursor-plus icon, right of the search bar) to add all of them to the Track List in one click.

Multi-select editing — keyframes, compatible property tracks, and saved animations each support multi-select workflows. See Keyframes & Easing for keyframe and track selection, and Saves & Folders for selecting and moving multiple saved animations.

Only add what you need

Only elements you explicitly add will appear in the Track List. This keeps the view clean -- you work on what matters.

Extremely large animations load Track List rows progressively so the editor stays responsive while all tracked elements are still available.

### 4. Add property tracks

Each element in the Track List has a collapse arrow (>) on the far left and an [+] add property button on the right side of its header row. Click [+] to open the property picker for that element. Browse by category or search by name, then click a property to add it as a track.

Each property becomes its own row -- one row for Position, one for BackgroundTransparency, etc. On a UIGradient, Type, TileMode, and Scale show in the picker when Studio has Upgraded UIGradients enabled (File → Beta Features).

Property picker toggles — properties already on the track are highlighted. Click one again to remove that track (with confirmation).

ScreenGui Enabled — if your target is a ScreenGui, Xocoatl may prompt you to track the ScreenGui and keyframe Enabled = true at 0s so the UI shows in-game. See Animatable properties — ScreenGui Enabled.

Element order: drag on the class icon or name area of an element header (not the collapse arrow, +, ⋮, or particle indicators) to reorder tracked elements. A semi-transparent ghost follows the pointer (with a short ease), and an accent drop line shows where the row will land. On release, the ghost stays at the pointer and fades out (background, stroke, and label ease from their current values to fully transparent). Order is saved in the clip JSON as elementDisplayOrder (older clips without this field keep their previous discovery order). Keyframe data stays keyed by instance GUID — reordering is display-only and does not change animation behaviour.

Selection: clicking a row in the Animator Hierarchy or Track List uses the Animator selection — accent wash on those rows, a thin outline on the preview, and move / scale handles. That also clears Studio Explorer so Ctrl+C / Ctrl+V copy keyframes, not instances. Click one or more preview clones (or the original UI) in Studio Explorer to keep Roblox’s own viewport selection — the Animator overlay does not start, so you can drag with Studio’s tools and edit Properties. Those writes still auto-key at the playhead (when Auto-key from property edits is on). Click back into the Timeline window (or popped-out host) to clear Explorer and use Animator shortcuts or the pose overlay. After you copy keyframes, Ctrl+V pastes those keys even if the 3D view is focused — it does not dump the last Explorer copy into Workspace. Copy or cut in Explorer again to give Ctrl+V back to Studio. Set Target and Add from Explorer still read your last Explorer pick.

### 5. Set values and create keyframes

- Move the scrubber (the vertical red line in the Timeline) to the time you want.

- While dragging on the ruler scrub band, a small time tag under the ruler follows the playhead and shows the exact time (same tag as dragging a keyframe). Any keyframe diamond at the current scrub time scales up slightly (same motion as hovering a diamond) and does a small rotation wiggle (counter‑clockwise, then clockwise, then settle) the first moment you land on that time — so stacked keyframes are easier to spot. If you scrub away (or release) before the wiggle finishes, scale and rotation ease back smoothly to the normal diamond pose; scaling also returns when you release the scrubber.

- Edit the value directly in the text field on the property track row (click the field, type a value, press Enter). A keyframe is created at the scrubber time automatically.

- For compound properties like Position or Size, the text field uses comma-separated values in xScale, xOffset, yScale, yOffset order.

- Shorthand: typing a single number into a compound field (e.g. 0) applies that value to all components at once.

- Colour properties (BackgroundColor3, TextColor3, ImageColor3, etc.) show a clickable colour swatch instead of a text box. Click the swatch to open the Color Picker, choose a colour, and confirm — a keyframe is created at the current scrubber time. Expand the track (arrow on the left) to get individual R / G / B numeric fields for precise input.

You can also click a track header and drag the Animator move / scale handles on the live preview (same look as UI Designer). That writes Position or Size on the preview and creates a keyframe at the scrubber time. Or select one or more items in Explorer and drag them in the viewport with Studio’s tools, or edit Studio Properties — those writes auto-key the same way, once you release the drag (start → end), not while the pointer is still moving. Colour, text, rotation, and other properties still use the track value fields or Properties.

Edges and centres snap to siblings, the parent, and the preview frame, with the same sticky alignment guides as UI Designer. Hold Shift while moving to lock to one axis. Studio’s 3D rubber-band selection is blocked for the drag so it does not fight the pose.

### 6. Set easing

Right-click a keyframe diamond to open the Keyframe Context Menu, then Easing. If right-click does not fire (common in Pop-Out), click a diamond once to select it, then click it again without dragging. That opens the same floating widget as UI Designer — drag the header to move it, close with × — with style (Linear, Quad, Sine, Back, Bounce, Elastic), direction (In, Out, InOut), and a curve preview. If the dock is short enough that the widget scrolls, top and bottom edge fades appear and hide like the timeline toolbar. While the editor is Popped-Out, you can drag Easing anywhere on the Studio viewport.

### 7. Preview

Press Play in the timeline header. Press Stop to return to the start. Use the arrow buttons to step frame-by-frame (hold for acceleration).

Enable the Loop toggle in the toolbar to repeat the animation during preview -- this only affects the editor preview, not in-game playback.

### 8. Save

Click File > Save (or Save As to name it and choose a folder). A new animation that has never been saved opens Save As so you can pick a name and folder. Animations are stored under ReplicatedStorage/XocoatlSaves/SavedUIAnimations by default; Xocoatl finds the saves root by the XocoatlPersistenceRoot tag if you move or rename it.

### 9. Close before testing or switching away

Before you test your game (Play) or do other work in Studio, use Animation > Close Animation. That removes the preview clone and restores your real UI. If the clip has unsaved changes, a confirm asks Cancel, Save & Close (or Save As & Close), or Discard & Close. The same confirm style is used for other destructive or unsaved-work prompts in the animator.

Don't leave the animation open when pressing Play

If you leave an animation open and press Play, the preview clone can appear in the running game and your real UI may stay hidden.

## Track List -- header controls

The Track List header row contains:

Control
What it does

Show Hierarchy toggle
Shows or hides the Hierarchy panel

Animation name field
Shows the current animation name; click to rename

Each element header row contains:

Control
What it does

> collapse arrow (left)
Collapses or expands all property tracks for that element

Class icon
Visual indicator of the element's class (Frame, TextLabel, etc.)

Element name (clickable)
Click to select that element in the Studio viewport for direct manipulation

[...] options button
Opens a dropdown: Copy Properties and Paste Properties first (values at the playhead), then a divider, then Show in Hierarchy and Delete From Track. Copy/Paste Properties writes keyframes at the playhead (only properties that exist on the target type). Effect headers use the same copy/paste pair, a divider, then Remove Effect. Separate from Edit ▸ Copy / Paste Keyframes (time-based diamond copy).

[+] add property button
Opens the property picker for this element

Each property track row contains:

Control
What it does

> collapse arrow (left, compound properties only)
Expands or collapses sub-rows showing individual components (e.g. X Scale, X Offset, Y Scale, Y Offset for a UDim2 property; R, G, B for a Color3 property). Collapsed by default.

Property name (clickable)
Click to select this track (for copy/paste). The row lifts with a quiet fill and a thin bar — not a theme-color wash.

Value field
Thin Designer-style input showing the current value at the scrubber (one combined box for UDim2 / UDim — no side icons, text centered). Hover uses the same shine stroke and shadow as UI Designer fields. Click to focus: the field scales up from the row. Press Enter to confirm and create a keyframe. Color3 properties show a colour swatch instead — click it to open the Color Picker.

delta toggle
Switches the track between absolute and relative (delta) mode. Lit up in bright blue when active.

[...] options button
Opens a dropdown: Delete From Track (removes this property track and all its keyframes).

The element collapse arrow (left of each element header row) only hides that element's own property rows. All other elements in the Track List remain visible regardless of any parent/child relationship.

## Menu bar reference

Menu
Items

Animation
New Animation, Open Animation..., Close Animation, Set Target..., Template Animation, Preview in Container, Add Effects

File
Save, Save As..., Rename Animation..., Export UI + Animation..., Import UI + Animation...

Edit
Copy Keyframes, Paste Keyframes (clipboard) — then Undo, Redo (history), separated by a divider line

Keyframe
Add Keyframe, Delete Keyframe, Duplicate (copies selected keys, or keys at the playhead, and pastes them; offsets by one frame when that would overwrite the source times)

Options
Preferences... (draggable floating widget — Keybinds, UI); Pop-Out / Pop-In (viewport host); Guided tours... (same chrome — pick a walkthrough)

Options > Help
Opens the built-in help & docs panel

Options > Report
Opens the Developer Forum plugin thread (bugs and feature requests; Discord link is in the first post)

Options > Xocoatl vX.X.XX
Current plugin semver — compact label at the bottom of the Options dropdown. The title-bar Status menu shows the full identity (v0.2.1 - B41 - P13).

The title bar also has Notifications. It opens a history of recent toasts from the right. In Pop-Out the drawer stays on the floating host (it does not cover the rest of Studio). Each item shows the animation it belonged to. Dismiss one with ×, or Clear them all. Actions that need that animation open (for example Track + Enabled at 0s) stay dimmed after you close it.

### Plugin version labels

The plugin tracks three parts:

Part
Example
Meaning

Semver
v0.2.1
Human-readable release name (menus, changelog)

B
B41
Patch build — bumps on Creator Store patches within the same release

P
P13
Version code — bumps when a named Update available release ships

Compact UI shows semver + status (for example v0.2.1 · Up to date). Full identity (v0.2.1 - B41 - P13) is computed automatically from the three fields above — status-card hover, update/patch prompts, and the docs header all use the same format.

## Toolbar buttons (in the timeline header)

Button
Action

Zoom Out / Zoom In
Change the time scale of the timeline

Fit to View (P)
Zoom and scroll so the entire animation duration is visible

Left / Right arrows
Step backward / forward (hold for faster stepping)

Stop
Go to frame 0

Current time / Animation Duration
Jump the playhead or set clip length. Same field chrome as track values: shine on hover, scale on focus.

Play / Pause
Start or pause playback

Loop
Toggle preview looping -- the animation repeats while previewing in the editor. Has no effect on in-game playback.

Undo / Redo
Step through the undo history

Add keyframe / Delete keyframe
Add or remove a keyframe at the playhead for the selected property track

Animation Name
Rename the current animation

Toolbar disabled with no animation open

All toolbar buttons are non-interactive when no animation is loaded. Open or create an animation to enable them.

## Keyboard shortcuts

Shortcuts apply when the Timeline Animator window has focus (Studio Selection is cleared then). While Explorer or Properties has a selection, Studio owns the keyboard — click back into the Animator to use these binds. Defaults stay off Studio camera keys (WASD, Q / E, arrows) so you can still fly the viewport. View and edit bindings in Options > Preferences > Keybinds (click a key badge to record a new chord). While Open Animation is already open, the shortcut does not open a second copy.

Default
Action

Space
Play / Pause

, (Comma)
Step backward (scrubber)

. (Period)
Step forward (scrubber)

P
Fit to view (zoom to fit the full animation)

9
Open Animation (saves browser)

0
Save animation (change in Preferences → Keybinds)

L
Toggle collapse/expand children of the selected Hierarchy element

- (Minus)
Zoom out

= (Equals)
Zoom in

Scroll wheel
Pan the timeline left / right

Shift + scroll
Pan tracks up / down (stays in sync with the Track List)

Ctrl + scroll
Zoom in / out toward the pointer

Middle-mouse drag
Pan time and tracks together (grab-pan). In Pop-Out, this stays on the timeline while the pointer is over the host instead of orbiting the Studio camera.

K
Add keyframe at playhead

G
Minimize / restore the popped-out editor (mini player; Pop-Out only)

X
Delete keyframe(s) at playhead or selected

Ctrl+Z / Ctrl+Y
Undo / Redo

Ctrl+C / Ctrl+V
Copy / Paste keyframes (same as toolbar / Edit menu; change in Preferences → Keybinds)

## Preferences

Open Options > Preferences to open a draggable floating widget (same chrome as Easing, Guided tours, and the UI Designer popups). Drag the header to move it. Categories (Keybinds, UI) sit on the left; the settings list is on the right. If the Timeline window is too short, the widget shrinks and the settings list scrolls so every dock size stays usable. Overflow shows the same top/bottom edge fades as the timeline toolbar (they hide at the ends). While Popped-Out, Preferences can leave the host and sit anywhere on the Studio viewport. Esc or the close button dismisses it.

Category
What it controls

Keybinds
Lists timeline shortcuts by section; click a key badge to rebind (hold Ctrl, Alt, Shift, or Meta and press the main key). If the chord is already in use, a second dialog offers Unbind other & use here (when that action can give up the shortcut) or Go back / backdrop click to keep listening; some conflicts are only the other action’s built-in default—in that case choose another key or reset plugin data for that action. Reset all restores defaults.

UI
Toolbar menu icons; Check for updates regularly (default on). Auto-key from property edits — when on, pose-overlay drags, typing in UI timeline property values, and Studio Properties edits on the selected preview or original write a keyframe at the playhead (default on). When off, those UI edits only change the preview until you use ◆ or K; editing the original still mirrors to the preview. Particle row values still save to the clip. Show preview frame reminder and Show new animation tour (default on). Timeline keyframe size — slider (60%–160%) scales track diamonds only; live preview while dragging; saved per Studio. Each checkbox row has Show more for a longer explanation.

## Guided tours

Open Options > Guided tours for a draggable floating widget (same chrome as Preferences and Easing). Search or click a walkthrough to start it. If the list scrolls, top and bottom edge fades appear and hide like the timeline toolbar. While Popped-Out, the picker can leave the host and sit anywhere on the Studio viewport. Esc or the close button dismisses it.

In Pop-Out, the walkthrough itself is hosted on the viewport overlay (not inside the rounded widget clip), so the dim, spotlight, and Next / Skip buttons stay on top of the host. Intro cards sit over the widget; spotlight steps still point at Hierarchy / Tracks controls. Minimizing hides the tour until you restore.

## Undo / Redo

The editor has a full undo stack. Press Edit > Undo (or the Undo button in the header, or Ctrl+Z) to step back through any change: added, moved, deleted, or duplicated keyframes, changed values, added or removed property tracks, added or removed elements, changed easing, event markers (place, rename, set time, delete), particle clip settings (keep emitting / no emit on reverse), Template Animation, Rename Animation, Preview in Container, duration changes, and more. Undo always reverts the most recent edit — a keyframe drag is not skipped in favour of an older pose or duration step. If Studio eats Ctrl+Z, the Animator still applies that same step so the clip and diamonds stay in sync. Undoing past the first edit of this session does not remove elements that were already on the clip when you opened it.

Shortening the clip duration past existing keyframes (or event markers) shows a confirm dialog first. Confirming deletes those markers; Ctrl+Z restores the previous duration and the deleted markers. Lengthening, or shortening with nothing past the new end, applies immediately. Event-marker edits on their own are also undoable.

After a preview pose-overlay drag, Ctrl+Z belongs to the Animator even if the mouse is still over the viewport. That step reverts the keyframe values and Track List fields, not only the on-screen pose. Studio undo is not used for those drags — the preview is not a Studio selection.

After you move a Studio-selected preview object in the viewport, Ctrl+Z undoes only that Studio move. It does not also step the Animator undo stack. Use Edit > Undo (or click the Timeline first) to undo Animator edits.
