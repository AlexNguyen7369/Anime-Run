# Concepts & terms

A short reference for the main terms used in the Timeline Animator and the runtime API. Sorted by subject.

## Editor & timeline

Term
What it is
What it does

Node / Element
A single instance in the animated UI tree (e.g. a Frame, TextLabel, or CanvasGroup).
In the Hierarchy panel, each node is one instance you can add to the Track List. Nodes must be explicitly added before their properties can be animated.

Hierarchy panel
The left panel in the Timeline Animator.
Shows the full tree of the animation target (the preview clone). Click the + button next to any element to add it to the Track List. Elements already on tracks are highlighted with a blue accent. Collapse or hide this panel using the Show Hierarchy toggle in the Track List header.

Track List
The centre panel in the Timeline Animator.
One element header row per added element, and one property track row per animated property under that element. Scrolls vertically in sync with the Timeline. Hidden on the landing screen (docked and Pop-Out). Drag the Tracks

Element header row
A row in the Track List representing one added element.
Has a collapse arrow (▶), class icon, element name, [⋮] options button, and [+] add property button. Collapse it to hide its property rows; [⋮] or right-click the row (menu at the pointer) includes Copy / Paste Properties (playhead), Show in Hierarchy, and Delete From Track.

Property track row
A row in the Track List representing one animated property of one element.
Has a property name (clickable for selection), a value text field, a delta (△) toggle, and [⋮] options. Right-click the row for the same menu at the pointer (e.g. Remove Property). Keyframe diamonds appear on the matching Timeline row.

Property
A single animatable attribute of a UI instance (e.g. Position, BackgroundColor3, GroupTransparency).
Once added as a track to an element, you set values at specific times to create keyframes. The plugin interpolates between keyframes. See Animatable properties for the full list.

Track
One property track row and its matching timeline row, tied to one property on one element.
Displays that property's keyframes as diamonds. Click the property name to select the track (for copy/paste).

Keyframe
A value stored at a specific time for one property on one element.
The plugin tweens between consecutive keyframes. Move the scrubber to a time, change the value, and a keyframe is created. Drag diamonds to reposition; right-click for easing.

Scrubber / Playhead
The vertical red line in the Timeline.
Marks the current time. Moving it updates the preview. Use , / . or the arrow buttons to step; drag the scrubber head to jump. New keyframes are placed at the scrubber time.

Timeline
The right-hand panel: ruler, keyframe tracks, and playback controls.
Shows time left-to-right. Each row matches one property track. Keyframes appear as diamonds. Play (▶) runs the animation; Stop (■) resets to the start. In Pop-Out, the playback bar spans the full host width. Scroll wheel pans time; Shift+scroll pans tracks (synced with the Track List); Ctrl+scroll zooms toward the pointer; middle-mouse drag pans time and tracks together. In Pop-Out, middle-mouse over the host pans the timeline instead of the Studio camera.

Ruler
The dark bar at the top of the Timeline showing time (0s, 0.5s, 1s…).
Lets you see and set the scrubber position. Right-click the ruler to Place Event (add an event marker). Ctrl+Z undoes place, rename, set-time, and delete.

Duration
The total length of the animation in seconds.
From 0 to the last keyframe (or the duration you set). Shortening past existing keyframes asks first, then deletes those keyframes (and event markers) after the new end. Ctrl+Z restores the previous duration and the deleted markers. The runtime uses duration to clamp scrub(t) and to know when a clip has finished.

Easing
The curve used between two keyframes (style + direction).
Style: Linear, Quad, Sine, Back, Bounce, Elastic. Direction: In, Out, InOut. Set per keyframe via the Keyframe Context Menu. Default is Quad Out.

Keyframe Context Menu
The menu that opens when you right-click a keyframe diamond or empty timeline space, or click an already-selected diamond again without dragging.
Easing opens the Animator floating widget (drag, close; scrolls if the dock is short) for style + direction + curve preview. While Popped-Out, the widget can be dragged anywhere on the Studio viewport. Also Copy, Paste, and Delete. When multiple keyframes are selected, easing can apply to all.

Guided tours
The picker opened from Options → Guided tours.
Same floating widget as Preferences and Easing (drag the header, close with ×). Search or click a walkthrough to start it. In Pop-Out, the walkthrough chrome sits on the viewport overlay (outside the widget’s rounded clip) and is laid out against the host; a compact host grows if the tour does not fit (never shrinks). Minimize hides it until restore.

Pop-Out / Pop-In
Options toggle that moves the whole Timeline Animator between the bottom dock and a viewport widget.
Pop-Out places the editor over the Studio game view (move; pull-tabs on the left, right, and bottom, corner grabs). Both modes use the same title bar (Animation / File / Edit / Options, Themes, Status). Hover tooltips work in both hosts (Pop-Out parents them to the viewport ScreenGui and places them in screen space). Docked chrome is Pop-Out only (close with Studio's dock widget ×) and does not drag the Studio widget. Popped-out chrome is Minimize + Pop-In + ×; drag the empty title-bar strip between the menus and Themes to move the host (screen-space mouse, not the docked PluginGui path). Double-click that strip to shrink the host to a compact top-left timeline (about 40% × 28% of the viewport) or grow it back — widget size only. Starting a guided tour grows the host if the walkthrough does not fit (never shrinks). × closes the Animator (same unsaved-changes prompt as the docked widget X). Hover just outside the left, right, or bottom edge to slide out a full-length pull-tab and drag it to resize. Tabs match the host height or width and sit behind the title bar. The title bar has no pull-tab; top resize uses the on-widget corner grabs. That does not rubber-band or grab keyframes. A keyframe or scrubber drag that leaves the host does not resize it; the diamond stops at the visible edge. Clicks on the host stay in the editor (including moving several selected keyframes); the preview pose box only works around the widget. While the pointer is over the host, middle-mouse pans the timeline instead of the Studio camera. If the open clip is dirty, Pop-Out and Pop-In ask you to Save / Save As first, or Cancel (no switch-anyway). Child widgets (Preferences, Easing, tours) can roam the viewport while popped out. They stay inside the docked widget. Help, Report, Import, Export, and Rename stay on the host.

Mini player
The small bar the popped-out editor collapses into via Minimize (title-bar button or G). Pop-Out only; disabled on the landing screen until a save is open.
Time / duration and restore on the title row; play / pause on the left of a scrubbable playhead timeline. Drag the title row to move it; double-click it to restore. G or restore brings the full editor back. Minimize / restore also closes hover tooltips, context tips, menus, and dropdowns so they do not stay on screen.

Delta (relative) mode
A per-track toggle (△ button on the property row).
When on (lit blue), keyframe values are stored as offsets from the element's original value rather than absolute values. Useful for animations that need to work regardless of where the element starts.

Preview clone
A copy of your UI created when you set an animation target.
Lives in StarterGui/_UIAnimPreview. All editing and preview playback happen on this clone; your real UI is never changed. Use Animation → Close Animation before testing so the clone is removed and the real UI is restored.

Animation target
The root the clip is tied to: a UI element (ScreenGui, Frame, CanvasGroup, etc.).
Set via Animation → Set Target…. The editor clones into the preview and auto-creates a working clip. Character / Motor6D rig targeting is off in this build.

Clip
A saved animation: name, duration, target link, and all keyframe data (tracks, values, easing).
What you edit in the editor and what you play at runtime with Anim.play("ClipName"). One clip can animate many elements and properties.

Event marker
A named point in time on the ruler.
Placed by right-clicking the ruler → Place Event. Right-click a marker to rename, set its time to the scrubber, or delete it. Ctrl+Z / Ctrl+Y restore those edits. At runtime, when the playhead passes that time, onEvent or handle.MarkerReached fires with the name. Use for sounds, showing text, or other logic.

## Saving & storage

Term
What it is
What it does

Save / Save As
File menu actions to persist the current clip.
Save updates the existing save. Save As lets you name the clip and choose a folder. UI clips stay under ReplicatedStorage/XocoatlSaves/SavedUIAnimations (JSON). Rig clips live in the AnimSaves container on the character as KeyframeSequence instances — no JSON, and shared with Moon Animator / the built-in editor.

Saves Browser
The panel opened by Animation → Open Animation….
Two-panel explorer: sidebar (search, hover preview, actions) and a full-height save tree. The list is locked to the current target: UI clips, or that Model’s AnimSaves (Moon saves included) after you select a rig and open saves. In Pop-Out the UI dialog shrinks with the host (tight widths hide row dates). A short or narrow host removes the preview column and moves search above the list with New Folder / Open / Cancel under it. Docked UI mode keeps the full chrome. Open, rename, move, preview on hover or click (selecting a save pins its preview), or delete clips and create folders. UI saves preview on a 2D canvas; rig saves preview on a live 3D viewport — a clone of the real rig plays the clip from the KeyframeSequence (same Pose sampling as Moon). Drag inside the preview to orbit. Opening a rig save aims the Studio camera and opens the timeline editor (Keyframe + Pose tree, not JSON).

targetId / GUID (_UIAID / _XocRigId)
A unique id on the animation target (_UIAID on UI, _XocRigId plus the XocoatlRig tag on a rig).
Saved with each clip so the plugin can find the same UI or Model after you rename or reparent it.

Folder
A container in the Saves Browser (marked with _IsFolder).
Purely for organisation. The runtime still finds all clips inside folders. Use for grouping by screen, character, or feature.

## Runtime

Term
What it is
What it does

Runtime
The scripts injected into your game when you click Install Runtime in the plugin.
Lives in StarterPlayerScripts/Xocoatl. Loads saved clips from ReplicatedStorage and applies keyframe data to your UI each frame. Required for animations to play in-game.

UIAnimController
The main module you require in a LocalScript to play animations.
Exposes play, stop, pause, reset, scrub, playBatch, sequence, clearInstance, etc. See UIAnimController.

Handle
The object returned by Anim.play("ClipName").
Lets you control that run: stop(), pause(), resume(), scrub(t), setSpeed(n), setLoop(…). Also exposes signals: Completed, Looped, Cancelled, MarkerReached.

BatchHandle
The object returned by Anim.playBatch(instances, "ClipName", opts).
Lets you stop(), pause(), or resume() all instances at once. There is no name-based control for batches — keep the handle to stop early.

SequenceHandle
The object returned by Anim.sequence(steps).
Lets you stop(), pause(), or resume() the whole sequence. Useful to chain several clips one after another without nested onComplete callbacks.

playBatch
Anim.playBatch(instances, name, opts).
Plays the same clip on multiple UI roots with an optional stagger delay between each. Typical use: list or grid reveals (e.g. cards fading in one after another).

sequence
Anim.sequence(steps, opts).
Plays a list of clips in order; each starts when the previous finishes. Steps are { name = "ClipName", opts = { … } }.

clearInstance
Anim.clearInstance(inst).
Stops every animation whose target root is inst. Call before hiding or destroying that UI so no handles keep running and the next time you show it there's no conflict.
