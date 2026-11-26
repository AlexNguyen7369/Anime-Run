# Getting Started

## 1. Install the plugin

Get Xocoatl from the Roblox Creator Store and install it into Roblox Studio. A toolbar called Xocoatl will appear with Tools, Timeline Animator, and UI Designer. Open Tools to use the dock; the Color Picker and Xocoatl features shortcuts live in the top bar of that dock when they are enabled. Open UI Designer for layout (beta) — see UI Designer — Overview.

Optional theme packs (separate Creator Store plugins) recolour the editor — see Theme packs.

Optional overlays (for example a breadcrumb of your Explorer selection in the viewport) are off by default. Turn them on under Tools → Xocoatl features — see UI Tools — Overview.

## 2. Install the Runtime

The runtime is a small script that lets your game actually play animations. It is separate from the editor plugin and needs to be installed once per place.

- Open the Timeline Animator from the toolbar.

- If the runtime is not installed yet, a prompt appears when you open the widget — click Install Runtime. Not now asks you to confirm; only skip if you edited the runtime yourself. You can also use Status in the title bar anytime.

- The runtime is placed at StarterPlayerScripts > Xocoatl. Done.

Keeping the runtime up to date

When the plugin updates, Status in the title bar shows when the runtime is behind. Click it to install or reinstall. A confirmation appears if a runtime is already installed (saved animations are kept; custom scripts inside StarterPlayerScripts/Xocoatl only are reset).

## Plugin vs runtime version

These are separate numbers:

Plugin
Runtime

What
Editor in Studio
Scripts in StarterPlayerScripts/Xocoatl

Example
v0.2.1 - B41 - P13
v0.084

Where shown
Status in the title bar (full identity; latest if an update is waiting), Options menu (semver only)
Status in the title bar (installed runtime version)

Keep both in sync after plugin updates — reinstall/update the runtime from Status in the title bar when prompted.

v0.2.1 Patch 1 adds Pop-Out, a notification history, and Timeline polish. See v0.2.1 Patch 1 changelog. Runtime is v0.083.

## 3. Create your first animation

### Set a target

Select a ScreenGui, Frame, CanvasGroup, or any GuiObject in the Studio Explorer, then click Animation → Set Target…. Use Options → Pop-Out if you want the editor over the Studio viewport (menus live in the host title bar with Themes and Status on the right; Minimize — or G — collapses it to a small play/scrub bar, Pop-In docks it again — dirty clips must Save or Cancel before Pop-Out / Pop-In; Pop-Out × or the Studio dock × closes the Animator).

Character / Motor6D rig targeting is off in this build — selecting a dummy does nothing. The Timeline Animator is UI-only until that surface ships again.

A preview clone of your UI appears in StarterGui/_UIAnimPreview. All editing happens on this clone — your real UI is never touched.

While a preview is open, Xocoatl shows a preview reminder card in the top-right notification stack (below any short toasts). Hover any toast or the reminder to keep the stack on screen; new toasts can still arrive. Close the animation before Play-testing so the preview clone is removed and your real UI is restored. You can turn the reminder off in Options → Preferences → UI → Show preview frame reminder, or check Don't show again on the card.

When you start a new unsaved animation, a short onboarding tour walks you through adding elements, properties, keyframes, preview, saving (File → Save As → folder → name), closing the animation, and playing it in-game — including an optional Add script button that inserts a ready-to-run LocalScript. If your target is a ScreenGui, the tour also covers tracking Enabled and keyframing it at 0s so the UI is not hidden in-game. Use Skip tour or Don't show again anytime; re-enable the tour in Options → Preferences → UI → Show new animation tour. You can also start any walkthrough from Options → Guided tours (same floating widget as Preferences).

### Open or create an animation

- New animation: Animation → New Animation (name it when you Save As).

- Existing animation: Animation → Open Animation… and pick one from the browser.

### Add elements and properties

In the Hierarchy panel (left side), find the element you want to animate and add it to the Track List, then click [+] on that header row and pick a property (e.g. Position, BackgroundTransparency).

### Set keyframes

- Move the scrubber to the time you want (e.g. 0s).

- Click the value field on the track row, type a value, press Enter. A keyframe is created. You can also select the preview or original in Explorer, then drag it in the viewport or change the property in Studio Properties.

- Move the scrubber to the end time (e.g. 0.5s) and type the ending value.

For compound properties like Position or Size, the field accepts comma-separated values: xScale, xOffset, yScale, yOffset.

### Preview and save

- Press Play to preview the animation.

- Press File → Save to save it.

- Before testing your game: Animation → Close Animation removes the preview clone and restores your real UI.

Close before pressing Play in Studio

Leaving an animation open when you press Play in Studio causes the preview clone to appear in the running game and your real UI may stay hidden.

## 4. Play it in your game

-- In a LocalScript under StarterPlayerScripts
local Anim = require(
    game.Players.LocalPlayer.PlayerScripts.Xocoatl.UIAnimController
)

-- Play once
Anim.play("MyAnimation")

-- Play and loop
Anim.play("MyAnimation", { loop = true })

-- Play reversed (same clip, backwards — useful for close/hide)
Anim.play("MyAnimation", { reverse = true })

-- Do something when the animation finishes
Anim.play("MyAnimation", {
    onComplete = function()
        frame.Visible = false
    end
})

Full API reference: UIAnimController

## 5. Best practices

Do this
Why

Use one clip with reverse = true for open/close
Design "PanelOpen" once; play it reversed for close. No duplicate clips.

Call Anim.clearInstance(inst) before hiding or destroying UI
Stops every animation targeting that element. Prevents handles from outliving the UI and avoids conflicts when you show it again.

Close the animation before pressing Play in Studio
The preview clone stays visible in the running game if you forget.

Give siblings different names
The plugin tracks instances by name path. Siblings with the same name may animate the wrong element.

Save before closing
Unsaved changes are lost when you close the animation or switch away from the editor.

Remove empty property tracks
Tracks with no keyframes add clutter and can cause unexpected reset behaviour.

## 6. UI Designer (beta)

UI Designer is a Figma-style layout editor for ScreenGuis. Open UI Designer on the toolbar.

- Pick a project card (any ScreenGui in the place) or New Project.

- Draw Frames on the artboard, select and resize, edit Properties on the right.

- Use Variables on the left rail for shared colours, numbers, and gradients.

Edits are live instances in your place — no export step. This is a public beta: there will be bugs and missing tools. If you find any, please report them on the DevForum plugin thread or Discord.

Full guide: UI Designer — Overview

## What to explore next

Once you have the basics working, these guides cover the more powerful features:

- Delta Mode — Animate relative to where an element starts, not a fixed position.

- Template Animations — One clip, many instances. Useful for inventory slots, buttons, cards.

- Hover Animations — Wire hover in/out with one line of code.

- Reuse & Batch — Staggered list reveals, sequences, and teardown patterns.

- UI Designer — Visual layout editor for ScreenGuis (public beta — there will be bugs; please report them).
