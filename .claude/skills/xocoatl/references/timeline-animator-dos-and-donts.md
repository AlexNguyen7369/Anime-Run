# Do's & Don'ts

Simple guidelines to avoid common mistakes and get the most out of the Timeline Animator.

## Your UI and the preview

When you set an animation target, the plugin creates a preview — a copy of your UI used only in the editor. You work on that copy to build your animation; when you save and run the game, the animation plays on your real UI. The preview lives in StarterGui until you close the animation, so close the animation (Animation → Close Animation) before testing your game or switching to other tasks — that removes the preview and restores your real UI.

{% hint style="success" %}
Do — Use the preview for animation

The preview is for animation work: moving the playhead, setting keyframes, scrubbing, and hitting Play to preview. All of that happens on the preview. When you save, the animation is stored and will run on your real UI in-game.

{% endhint %}Don't — Leave the animation open when you test the game or switch away

If you press Play in Studio or switch to another tool while an animation is open, the preview clone stays in place and your real UI may stay hidden. Always use Animation → Close Animation first so the preview is cleaned up.

{% endhint %}Don't — Use the preview to change the design of your UI

The preview is for animating, not for redesigning. If you want to change the layout, add or remove elements, change colors or text for design reasons, or adjust the structure of your UI, edit the original in the Explorer. The preview is a temporary copy; design changes there are lost when you close or reopen the animation. Do design on the real UI, then set the animation target again if needed.

{% endhint %}Do — Change values in the track value field, the preview pose overlay, or Studio Properties

To add keyframes, move the playhead to a time, then change the value in the property track row's text field, click a track and drag the Animator move / scale handles, or select one or more items in Explorer and drag them in the viewport (or edit Studio Properties). Studio viewport / Properties drags write the keyframe when you release (start → end), not every frame. Animator handles use the same edge/center snap guides as UI Designer. Click back into the Timeline window before using Ctrl+C / X so those keys copy or delete keyframes, not Explorer instances. Ctrl+Z after a pose drag reverts those keyframe values and the Track List fields, not only the on-screen pose.

{% endhint %}Don't — Put scripts or tweens on the preview

The plugin drives the preview during scrubbing and playback. If you add your own scripts or tweens to the preview, they will conflict. Put your game logic on the original UI in the Explorer, not on the preview.

## {% endhint %}

## Tracks and elements

{% hint style="success" %}
Do — Only add elements you need to animate

The Track List only shows elements you explicitly add from the Hierarchy panel. Keep it focused — only add the elements whose properties you actually need to keyframe.

{% endhint %}Do — Remove property tracks you are not using

If you added a property track but never added keyframes (or you removed them all), remove it using the hover-reveal trash icon on the track row. Empty tracks add clutter and can cause unexpected reset behaviour.

{% endhint %}Don't — Delete a node and add a new one with the same name

If you delete an instance that had keyframes and then create a new instance with the same name, the old keyframes no longer match the new instance. Either re-add the properties and keyframes on the new instance, or use Undo to bring the original back.

{% endhint %}Don't — Move a node out of the thing you're animating

Your animation target is usually one ScreenGui or Frame. If you drag a child into a different ScreenGui or another root, it's no longer part of that animation. The keyframes for that node won't apply. Keep everything you're animating under the same target.

## {% endhint %}

## Keyframes and easing

{% hint style="success" %}
Do — Keyframe ScreenGui Enabled at 0s when the UI must start visible

If your animation target is a ScreenGui (or you animate a ScreenGui inside the clip), keyframe Enabled = true at 0s unless you intentionally fade the whole UI in later. Xocoatl can set this up for you via the ScreenGui Enabled toast (Track + Enabled at 0s). This matters when the ScreenGui is disabled in Studio for editing — without the keyframe, the UI can stay hidden in-game.

{% endhint %}Do — Add a keyframe at 0 seconds when you care about the start

If your first keyframe is at 0.5s, the animation doesn't have a defined value from 0 to 0.5s. To make the element start in a specific position or opacity, add a keyframe at 0s with that value.

{% endhint %}Do — Use event markers for sounds or logic

Right-click the dark ruler bar → Place Event and type a name. In code, use onEvent or handle.MarkerReached to run logic (e.g. play a sound, show text) at that exact time in the animation.

{% endhint %}Do — Use delta mode for position-agnostic animations

Turn on the △ delta toggle on a track to store values as offsets rather than absolutes. Useful if you want the animation to work regardless of where the element starts — for example, a "slide up by 20px" animation that can be applied to any element.

## {% endhint %}

## Naming and structure

{% hint style="success" %}
Do — Give siblings different names

If you have several labels or images under the same parent, name them so you can tell them apart (e.g. Title, Subtitle, Icon). The plugin tracks each one correctly by name path. If two siblings have the same name, the plugin may animate the wrong one.

## {% endhint %}

## Saving

{% hint style="success" %}
Do — Save before you close

Hit File → Save before closing the animation or switching away from the editor. Animation → Close Animation asks you to Save & Close, Discard & Close, or Cancel when there are unsaved changes.

## {% endhint %}

## Running animations in your game

{% hint style="success" %}
Do — Use the runtime from a LocalScript

Animations run on the player's device, so the runtime must run on the client. In your game, require the UIAnimController from a LocalScript under StarterPlayerScripts (or from another client-side script). It will not work from a ServerScript.

{% endhint %}Do — Call Anim.clearInstance(inst) before hiding or destroying UI

Before you set Visible = false or destroy a GuiObject that might have animations on it, call Anim.clearInstance(inst). That stops every animation targeting that element so you don't leave handles running on UI that's gone, and avoids conflicts when you show the element again.

{% endhint %}Do — Know when Anim.refresh() is needed

Saved clips load automatically when the game starts. If a clip is missing at first (replication timing), play() re-scans once before warning. New clips saved during Play are picked up via folder watchers — Anim.refresh() is only needed if something still looks stale (e.g. after editing clip JSON by hand).

{% endhint %}Do — Keep the handle if you need to stop or pause later

Anim.play("MyAnim") returns a handle. If you might need to stop, pause, or scrub that animation later, store it: local h = Anim.play("MyAnim", { loop = true }) and then use h.stop(), h.pause(), or h.scrub(0.5) when you need to.

{% endhint %}Don't — Rely on two different clips animating the same element at once

Playing the same clip name again stops the previous run. But if you play clip A on a Frame and then clip B on the same Frame, both can run and drive the same properties — they will conflict. Use one clip per element at a time, or call Anim.clearInstance(frame) before playing the new clip.
