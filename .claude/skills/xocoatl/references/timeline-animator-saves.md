# Saves & Folders

## Where animations are stored

Animations are saved to:

ReplicatedStorage
+-- XocoatlSaves              (tagged XocoatlPersistenceRoot)
    +-- SavedUIAnimations
    |   +-- Imports               (Folder — reserved; paste-import clips)
    |   +-- Built-in presets      (Folder — reserved; plugin-shipped bundles)
    |   +-- MyAnimation          (Folder)
    |   |   +-- Name             (StringValue)
    |   |   +-- Data             (StringValue -- JSON)
    |   +-- My Folder            (Folder, marked with _IsFolder)
    |       +-- AnotherAnimation (Folder)
    |           +-- Name
    |           +-- Data

Character / Motor6D rig clips are off in this build (selecting a dummy does nothing). When that surface ships again, those clips live on the Model itself, in the same AnimSaves container Moon Animator and the built-in Roblox editor use:

Dummy (Model)
+-- AnimSaves                (Model — shared with Moon Animator / Roblox editor)
    +-- Walk                 (KeyframeSequence — attributes _XocClipId, _XocTargetId)
    +-- Idle                 (KeyframeSequence — saved by Moon; adopted on sight)
    +-- Combat               (Folder — Xocoatl organisation only)
        +-- Punch            (KeyframeSequence)

The runtime finds the saves root by the XocoatlPersistenceRoot tag first. That means you can move or rename the saves folder as long as the tag stays on the folder.

The same root also holds UI Designer data (DesignerVariables, DesignerViewportSizes, DesignerPreferences) next to SavedUIAnimations. Rig clips are not JSON — they are Roblox KeyframeSequence instances inside the rig's AnimSaves Model (Moon will not see a Folder with that name). Each sequence uses the same on-disk shape as Moon's export and the built-in editor: Keyframe children with a full nested Pose tree (Pose.CFrame is Motor6D.Transform), rooted at the Motor6D root (HumanoidRootPart / Torso), not a sparse list of only the bones you keyed. Joints that are not keyed at that time still exist in the tree so Moon can parent limbs; they are marked with an IntValue named Null so they do not come back as extra keys. Because the container and that pose tree are shared, interop is two-way: animations saved by Moon appear in Xocoatl, and clips you save in Xocoatl show up in Moon on the same rig (add the rig / look under AnimSaves). Foreign clips are adopted the first time the rig is browsed — Xocoatl stamps its _XocClipId / _XocTargetId attributes on them (invisible to Moon) so they preview and open like native saves. Older projects with an XSaves container are migrated into AnimSaves automatically. Rigs are linked by _XocRigId (and the XocoatlRig tag). Select the rig first, then browse / search only that model's saves. Folders inside AnimSaves only group files — Moon lists AnimSaves flat, so File → Save keeps the clip at the top level unless you pick a folder on purpose. The AnimSaves container itself is never deleted. Opening a save aims the Studio camera and opens the timeline. The rig must still exist in the place. See UI Designer — Variables.

Older projects that still have ChocosToolsSaves are supported. On first open, Xocoatl tags the legacy folder and renames it to XocoatlSaves when there is no name collision.

If both ChocosToolsSaves and XocoatlSaves exist, or more than one folder has the XocoatlPersistenceRoot tag, Xocoatl warns instead of guessing. Use Tools → Xocoatl features → Locate Xocoatl Saves Folder to repair the tag on the correct folder.

{% hint style="warning" %}
Rojo users

If Xocoatl renames an old ChocosToolsSaves folder to XocoatlSaves, update your Rojo project map so Studio and Rojo agree.

## {% endhint %}

## Saving an animation

File > Save -- saves the current animation in place. If the clip has never been saved, this opens Save As so you can pick a name and folder.

File > Save As... — opens the same explorer-style browser as Open Animation, but folders only:

- Pick Root (top level) or a folder, then click Save As.

- Use New Folder (sidebar, or under the list in a compact Pop-Out) to create and name a folder before saving.

- After you confirm the destination, enter the animation name and save.

The folder step uses the same search, row styling, and sidebar layout as Open Animation (without the animation preview).

## Saves Browser

Animation > Open Animation... opens a tall two-panel explorer: a sidebar card on the left (search, preview stage, and actions) and a full-height folder tree on the right (same card styling as the landing screen). The list matches how you opened it — UI clips from SavedUIAnimations, or that Model’s AnimSaves (including clips saved by Moon Animator or the built-in editor) after you select a rig and open saves from there. The rig browser uses the same full explorer as UI: hovering or selecting a rig save plays it on a live 3D preview in the sidebar — a clone of the real rig in a viewport, with the same play bar as UI previews. Clicking a save pins its preview (it keeps playing until you select or hover something else); hover always previews the row under the pointer. The camera starts on a framed 3/4 view (Studio FOV); drag inside the preview to orbit it (drag up/down to tilt). Playback samples the KeyframeSequence the same way Moon does (60fps times, Pose easing). The preview finds the rig by its stable id (_XocRigId + XocoatlRig tag), so it keeps working after the Model is renamed or moved anywhere in the place. It plays classic Motor6D rigs and Rig Builder R15 (AnimationConstraint) rigs alike — the preview clone converts constraint joints internally so the pose shows without a physics step. Rig saves support the same folders, drag-and-drop, rename, and delete as UI saves. In Pop-Out, the UI dialog shrinks to fit a short or narrow host. When the tree is tight, duration and last-updated hide from rows (they stay on the name tooltip). If the window is smaller still, the preview column is removed and the dialog becomes a single list: search above the tree, New Folder / Open / Cancel under it. The docked UI browser keeps the full explorer (preview and dates).

From here you can:

- Open an animation -- double-click it, or single-click to select and confirm

- Rename an animation or folder -- right-click > Rename

- Delete an animation or folder -- right-click > Delete

- Move into a folder -- drag and drop the animation or folder onto any other folder

- Rearrange folders -- drag and drop folders up or down within the same level

- Create Folder -- click the Add Folder button in the bottom bar to organise by character, screen, or feature

The sidebar header has a search bar — type to filter animations by name.

Folder rows show how many animations they contain on the right (e.g. 3 Animations, including nested subfolders). Animation rows show duration and last updated on the right (e.g. 2.50s — May 26 14:30), or - when no timestamp is saved yet.

### Sidebar preview

The left panel is the only preview area — the list on the right does not change layout or icons for preview.

- Hover an animation row → the sidebar plays that clip on loop inside a 16:9 stage, zoomed to fit the animated content with padding (not the full 1280×720 canvas). Uses the same interpolation + ParticleSim path as the Timeline preview.

- Very large animations skip the hover preview and show a short message instead, so the saves browser stays responsive. Open the animation normally to edit or play it.

- While a row is hovered, a compact play bar and time readout (in 0.01s steps) appear in the sidebar header next to the title.

- Search ↔ preview swap — while previewing, the search box fades out and the play bar takes its place; search returns shortly after you move off the row. Search is disabled while hidden so you cannot type into it by accident.

- Select a row only for opening, moving, or multi-select — it does not change the sidebar preview.

- The preview area uses a transparent background so only the UI content is visible over the sidebar.

- Move the mouse off the list → the preview clears.

Previews use the saved UI snapshot on the clip (or a matching target in StarterGui). Clips with no snapshot show a short message in the preview frame.

Hover the timestamp or name on a clip row for Made and Last updated details. Timestamps are stored inside the clip JSON: they are set the first time you Save or open an animation, and Save refreshes the last-updated time.

### Multi-select

Use multi-select when you want to move several saved animations at once:

- Ctrl-click animation rows to add or remove them from the current selection.

- Shift-click another visible animation row to select a range.

- Drag any selected animation to move the whole selected group into or out of folders.

Folders can still be dragged and reordered, but multi-select is intended for animation rows. Protected folders such as Imports and Built-in presets cannot be used as drop targets.

### Drag and drop

Click and hold on any animation or folder, then drag it. A semi-transparent ghost card eases toward the cursor while you move, then stays at the pointer and fades out (background, stroke, and label ease from their current values to transparent). Drop it onto a folder to move it inside, or drop it between rows to reorder at the same level. While you drag, other rows shift aside and an accent gap opens at the drop position so you can see the final order before you release. Dropping onto the middle of a folder row moves the item into that folder (the row highlights). If you drag near the top or bottom edge of the tree, the list auto-scrolls so you can drop into folders that are off-screen.

## Folders

Folders are purely organisational. The runtime scans the full tree recursively so animations inside folders are found automatically.

If you move the saves folder and Xocoatl cannot find it, open Tools → Xocoatl features, select the correct Folder in Explorer, then click Locate Xocoatl Saves Folder. Xocoatl will move the tag and create any missing child folders.

## Linking an animation to a UI target

Every animation stores the _UIAID attribute of the root UI element it was created for (targetId). When you open an animation, the plugin searches your scene for an element with that GUID:

- If found -- opens with that element as the target automatically.

- If neither -- shows a prompt to set the target manually.

## Export & Import

Use File → Export and File → Import from JSON… to share animations between Roblox places or team members.

### Export to JSON

- Open the animation you want to share and set its target.

- Click File → Export → Export to JSON…

- A centered alert opens with the JSON bundle — click Copy (or the field) then Ctrl+C. In Pop-Out it stays on the editor host.

- Press Done.

The bundle contains the full animation clip data and a snapshot of the UI structure. Scripts and other non-UI children are excluded from the snapshot and listed in the dialog as a warning.

### Export to Module (commission kit)

{% hint style="info" %}
Not in the menu yet

Export to Module is in development and is not shown under File → Export in the current plugin build. Use Export to JSON for sharing clips today.

{% endhint %}
When it ships, File → Export → Export to Module… will create a standalone module kit in your place — no runtime install required for the buyer. Choose Commission package to export a {Name}_Export folder with a UI clone plus scripts, or turn commission package off to add modules under your existing UI.

In the export dialog, pick a Playback mode:

Mode
What ships
Best for

Runtime slice (default)
{Name}Config, {Name}Anim (keyframe data), {Name}Runtime, {Name}Player
Matches Timeline preview — loop, easing, relative tracks

TweenService
{Name}Config, {Name}Anim (generated TweenService:Create chains), {Name}Player
Easy to read/edit plain Roblox tweens

Edit {Name}Config to change speed, loop, ping-pong, delay, or autoplay without touching generated animation code.

Particle and timeline-event tracks are warned in the export dialog and omitted from the module kit — they still work in preview, JSON export, and the installed runtime.

Snapshots preserve supported UI modifier properties, including UIShadow and beta UICorner per-corner radii when the current Studio build supports Roblox's New UI Capabilities API.

Newly written JSON (export, File → Save, and stored UI snapshots) rounds floats such as UDim2 scales and Color3 components to three decimal places so bundles are shorter and easier to copy; bundles you saved earlier are unchanged until you save or export again.

### Importing

- Click File → Import from JSON…

- Paste the JSON bundle into the centered alert (same split-footer style as Help / Report and confirms). In Pop-Out it stays on the editor host.

- Press Import.

The plugin will:

- Recreate the exported UI inside StarterGui > Imports (the folder is created automatically if it does not exist yet).

- Save the animation clip into your Imports folder in the saves browser.

- Assign the clip a fresh unique ID so it is completely independent from the original -- importing the same bundle twice creates two separate animations with no ID conflicts.

After importing, open the animation manually via Animation > Open Animation... and select it from the Imports folder. Set the animation target to the recreated UI (or your own UI if you already have a compatible one).

### Built-in presets

The plugin may ship timeline bundles (same JSON format as Export UI + Animation) into the reserved Built-in presets folder under SavedUIAnimations. They are applied the same way as a manual import: UI is recreated under StarterGui → Imports, and each clip gets a new id and name prefixed with [Built-in].

Shipped Built-in presets appear in Animation → Open Animation as rows under Built-in presets (or as a one-time virtual folder until you expand it). Only the preset you open is installed: it creates the save, optional StarterGui → Imports UI, and snapshots — other shipped presets stay unloaded until opened.

- The saves browser treats Imports and Built-in presets like protected folders (lock icon, special ordering: Imports first, then Built-in presets). You cannot delete those folders or drop items onto them; clips inside can still be deleted or moved like any other save.

- Plugin authors: add entries in BuiltinTimelinePresets.luau (see the plugin source under Modules/Core/). Each entry has a name label and a bundle string (use [=[ ... ]=] for the JSON). Bump VERSION when you add or change shipped bundles (for documentation consistency).

### Renaming animations

File > Rename Animation... opens the same centered alert as Import — type a name, then Confirm (or Enter).

{% hint style="warning" %}
Renaming may break game code

If your game scripts reference an animation by name (e.g. Anim.play("MyAnimation")), renaming it here will break those calls. Update any references in your scripts after renaming.

You also cannot rename an animation to a name that is already taken by another animation.
