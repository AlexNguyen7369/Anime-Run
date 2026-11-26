# UIAnimController

The UIAnimController module is the main API for playing animations at runtime in your game.

It is automatically injected into PlayerScripts.Xocoatl when you use Install Runtime in the plugin.

## ColorSequence / NumberSequence (e.g. UIGradient)

Between keyframes, the runtime interpolates ColorSequence and NumberSequence pairwise by stop index (matching keypoint counts). Times and colours / values blend with the segment easing; NumberSequence envelope is treated as 0. If stop counts differ, the value snaps to the end keyframe for that segment.

## 2D particles (particleTracks)

If a clip contains particle keyframes (author Make Particle Frame in the Timeline Animator), playback still uses Anim.play the same way. The runtime interpolates particle properties over animation time t, samples Colour / Size / Transparency sequences over each particle’s normalized lifetime, and spawns lightweight ImageLabel particles according to rate, edge emission, and Emit Container — default ScreenGui (a full-screen runtime layer); Emitter parents particles under the host frame when you want them clipped/stacked with that UI. Interrupting playback (stop(), starting another run on the same key, etc.) drains live particles (they age out) instead of deleting them instantly. Natural forward completion still drains unless the clip has keep emitting when stopped enabled — see below.

Keep emitting when stopped — When this clip flag is on in the plugin (Track list → Particles section → Keep emitting after clip ends), and the clip finishes naturally at its end time (forward completion at t = duration), and at least one emitter has Enabled ≠ false at that time, the runtime keeps stepping particle simulation at frozen t = duration until the same playback key runs again (play / playOn / bindHover for that binding), Anim.stopOn, Anim.clearInstance, Anim.stopAll, or Anim.refresh. Keyframed Enabled during the clip still behaves as before; landing at the last frame with Enabled off does not start post-clip emission. Reverse completion (e.g. hover out) does not keep emitting.

No particle emit on reverse — Optional clip flag (Track list → Particles → No particle emit on reverse). While the clip plays reversed, the runtime does not spawn new particles; particles already in flight still update until their lifetime ends.

## Require it

local Anim = require(
    game.Players.LocalPlayer
        .PlayerScripts.Xocoatl.UIAnimController
)

Place this at the top of any LocalScript.

## How playback behaves (interruption rules)

- Same playback key — By default the key is the clip name. Anim.playOn uses name .. "\0" .. tostring(instance). Each Anim.bindHover call uses that prefix plus "\0bind\0" and a unique id so one hover binding never stops another on the same GuiObject + clip name. Anim.bindButton uses its own internal keys. A new play for the same key stops the previous run (if any). Any post-completion particle loop from keepEmittingWhenStopped for that key stops spawning new particles and drains existing ones (same as stop()), rather than deleting them in one frame.

- Different clips, same target — If clip A is playing on a Frame and you play clip B on the same Frame, both can run at once. They will both drive properties on that Frame and can conflict. To avoid that: call Anim.clearInstance(frame) before playing B, or design your flow so only one clip runs on that element at a time.

- Stopping by target — Anim.clearInstance(inst) stops every animation whose target root is inst, no matter the clip name. Use this before hiding or destroying UI.

## Anim.play(name, opts?)

Plays a saved animation by its exact name.

Returns a Handle you can use to control it.

local handle = Anim.play("ButtonPop")

### Options

All options are optional.

Option
Type
Default
Description

loop
boolean \| number
false
true = repeat forever. A number plays the clip exactly that many times then fires Completed. false/nil = play once.

pingpong
boolean
false
Loop forward → backward alternately. Works with loop = true or loop = N.

speed
number
1
Playback speed multiplier. 2 = double speed, 0.5 = half speed.

delay
number
0
Seconds to wait before the animation starts.

reverse
boolean
false
Play the clip backwards (end → start). Use this for "close" from a single "open" clip — no need to author a separate close animation.

target
GuiObject
(saved target)
Override which UI root to animate. Useful when many copies share the same animation name.

onComplete
function
—
Fires when a non-looping clip finishes naturally.

onEvent
function(name)
—
Fires for each named event marker placed in the plugin editor. See Clip Events.

events
{ AnimEvent }
—
Scripted callbacks fired at specific times. See Scripted Events.

reset
boolean
false
When true, all properties touched by the animation are restored to the values they had before the animation started when the clip ends or is stopped. Useful for one-shot effects (e.g. click pops) where you want the element to snap back automatically.

deleteOnComplete
boolean
false
When true, the handle is automatically removed from the active table when the animation ends naturally. Useful for fire-and-forget animations where you don't keep the handle.

resetToStart
boolean
false
When true, calling stop() snaps all animated properties back to their frame-0 state. When false (default), stop() freezes the instance at whatever frame it was on — unless snapOnInterrupt is set.

snapOnInterrupt
"start" \| "end" \| "none"
nil
On stop(): "start" snaps to frame 0 only when stopping a reverse playback; "end" snaps to duration only when stopping a forward playback. Omit or "none" for legacy freeze-at-current-frame. bindHover / bindButton hover default "start" on both directions so re-hover can snap after a partial reverse without snapping when forward hands off to reverse.

### Examples

-- Simple play
Anim.play("ButtonPop")

-- Loop at double speed
Anim.play("LoadingPulse", { loop = true, speed = 2 })

-- Play exactly 3 times, then fire Completed automatically
Anim.play("Pulse", { loop = 3 })

-- Ping-pong loop (forward → backward → forward …)
Anim.play("Breathe", { loop = true, pingpong = true })

-- Ping-pong exactly 2 full round trips then stop
Anim.play("Breathe", { loop = 2, pingpong = true })

-- Play reversed, then hide the frame
Anim.play("SlideIn", {
    reverse    = true,
    onComplete = function()
        frame.Visible = false
    end,
})

-- Delayed start (waits 0.3s before the clip begins)
Anim.play("IntroCard", { delay = 0.3 })

-- Animate a specific GuiObject
-- (useful when you have multiple copies of the same UI)
Anim.play("CardReveal", { target = myCard })

-- One-shot effect that auto-restores the element to its pre-animation state
Anim.play("ClickPop", { reset = true, deleteOnComplete = true })

-- onComplete callback
Anim.play("IntroSlide", {
    onComplete = function()
        print("Intro done!")
        mainMenu.Visible = true
    end,
})

## Clip Events

Named events are placed directly on the timeline ruler in the plugin editor.

Right-click the dark ruler bar → Place Event → type a name → confirm.

The marker appears as an amber triangle on the ruler and is saved with the animation.

At runtime, use onEvent to respond to them:

Anim.play("Intro", {
    onEvent = function(eventName: string)
        if eventName == "showTitle" then
            titleLabel.Visible = true
        elseif eventName == "playSound" then
            SoundService.Pop:Play()
        end
    end,
})

- Events fire once per forward or backward pass.

- Events reset and re-fire on each loop.

- The eventName string matches exactly what you typed in the editor.

## Scripted Events

Fire callbacks at specific times during playback (defined in code, not the editor).

Anim.play("CutsceneA", {
    events = {
        { time = 0.5, callback = function()
            SoundService.BoomSFX:Play()
        end },
        { time = 1.2, callback = function()
            showSubtitle("Hello there!")
        end },
    },
})

- time — the animation time (in seconds) at which the callback fires.

- callback — a function with no arguments.

- Events fire once per loop pass and reset when the animation loops.

## Handle methods

Anim.play() returns a Handle with these methods:

local handle = Anim.play("ButtonPop")

handle.pause()          -- freeze in place
handle.resume()         -- continue from where it paused
handle.stop()           -- cancel; freezes at current frame unless snapOnInterrupt / resetToStart opts apply
handle.reset()          -- snap to frame 0 and pause; handle stays alive
handle.scrub(t)         -- seek to time t (0 to duration); updates frame immediately
handle.isPlaying()      -- true if the animation is running (not stopped)
handle.isPaused()       -- true if paused (but not stopped)
handle.setSpeed(n)      -- change playback speed mid-animation (1 = normal, 0.5 = half, 2 = double)
handle.setLoop(loop)    -- change loop behaviour mid-animation; same values as the loop option

- scrub(t) — Jumps the playhead to time t (clamped to the clip duration), updates the UI immediately, and resets which event markers have fired so they can fire again when you play past them.

- setSpeed(n) — Changes speed without resetting the current position. Negative values play in reverse. 0 is not recommended; use pause() instead.

- setLoop(loop) — Pass true to loop forever, false to stop after the current pass, or a number to run that many more full passes then stop. Resets the internal pass counter.

## Handle signals

Handles expose signal objects you can connect to (instead of or in addition to onComplete / onEvent in options):

Signal
When it fires

handle.Completed
When a non-looping animation finishes naturally.

handle.Looped
On each loop restart, or when ping-pong flips direction.

handle.Cancelled
When you call handle.stop().

handle.MarkerReached
For each named clip event; arguments are (eventName, eventData).

local handle = Anim.play("Intro", { loop = false })

handle.Completed:Connect(function()
    print("Intro finished!")
end)

handle.MarkerReached:Connect(function(name, data)
    if name == "showTitle" then
        titleLabel.Visible = true
    end
end)

- onComplete in options still works; it is equivalent to handle.Completed:Connect(onComplete).

- onEvent in options still works; it is equivalent to handle.MarkerReached:Connect(function(name) onEvent(name) end).

## Name-based control (no handle needed)

If you don't keep the handle, you can control by name:

Anim.play("LoadingPulse", { loop = true })

-- later…
Anim.pause("LoadingPulse")
Anim.resume("LoadingPulse")
Anim.stop("LoadingPulse")
Anim.reset("LoadingPulse")
Anim.scrub("LoadingPulse", 0.5)  -- seek to 0.5s

## Anim.playBatch(instances, name, opts?)

Plays the same saved animation on multiple instances at once, with an optional stagger delay between each one. Returns a BatchHandle you can use to stop, pause, or resume all instances together.

local bh = Anim.playBatch({ card1, card2, card3 }, "FadeIn", {
    stagger = 0.06,  -- 60 ms between each card
})

### Batch options

All options are optional.

Option
Type
Default
Description

stagger
number
0
Seconds between each instance's start. The first instance starts immediately (plus delay), the second starts at 1 × stagger, the third at 2 × stagger, and so on.

delay
number
0
Base delay applied before the stagger offset. Added to every instance's individual start time.

loop
boolean \| number
false
Same as play(). Applies to every instance.

pingpong
boolean
false
Same as play(). Applies to every instance.

speed
number
1
Same as play(). Applies to every instance.

reverse
boolean
false
Same as play(). Applies to every instance.

reset
boolean
false
When true, all touched properties are restored to their pre-animation values when each instance finishes.

onComplete
function
—
Fires once when the last instance finishes naturally.

onEvent
function(name)
—
Fired for each named clip event, for every instance.

events
{ AnimEvent }
—
Scripted callbacks fired at specific times, forwarded to every instance.

### BatchHandle methods

local bh = Anim.playBatch(instances, "FadeIn", { stagger = 0.05 })

bh.stop()    -- stop all instances immediately
bh.pause()   -- pause all instances
bh.resume()  -- resume all paused instances

{% hint style="info" %}
No name-based control for batches

Anim.stop("FadeIn") will stop a normal play() of that name but not a batch. Always keep the BatchHandle if you need to stop a batch early. To stop by instance instead, use Anim.clearInstance(inst) or Anim.stopBatch(instances).

{% endhint %}

### Examples

-- Staggered list reveal — items cascade in 60 ms apart
Anim.playBatch(listItems, "FadeIn", { stagger = 0.06 })

-- Staggered reveal, then restore all items to their original state
Anim.playBatch(listItems, "SlideIn", {
    stagger    = 0.05,
    reset      = true,
    onComplete = function()
        print("All items revealed!")
    end,
})

-- Play at double speed with a 0.2 s base delay, then loop forever on each
local bh = Anim.playBatch(panels, "Pulse", {
    speed  = 2,
    delay  = 0.2,
    loop   = true,
})
-- Later, stop them all:
bh.stop()

-- Stagger with ping-pong loop (breathing effect on many elements)
Anim.playBatch(icons, "Breathe", {
    stagger  = 0.1,
    loop     = true,
    pingpong = true,
})

## Anim.sequence(steps, opts?)

Plays a list of clips one after another, each starting when the previous one finishes naturally. Returns a SequenceHandle to stop, pause, or resume the whole sequence.

Anim.sequence({
    { name = "SlideIn" },
    { name = "Pulse",    opts = { loop = 3 } },
    { name = "SlideOut" },
})

### Step format

Each entry in the steps table is:

{ name = "ClipName", opts = { ... } }

- name — the animation name, exactly as it is saved.

- opts — the same options as play() (loop, speed, reverse, reset, delay, etc.). Setting onComplete inside a step's opts is ignored — use the top-level onComplete instead.

### Sequence options

Option
Type
Default
Description

loop
boolean
false
When true, the whole sequence restarts from step 1 after the last clip finishes.

onComplete
function
—
Fires once when the last clip finishes (only on non-looping sequences).

### SequenceHandle methods

local seq = Anim.sequence(steps)

seq.stop()    -- cancel the current clip and prevent future steps
seq.pause()   -- pause whichever clip is currently running
seq.resume()  -- resume the paused clip

### Examples

-- Chain three clips: slide in → pulse 3 times → slide out
Anim.sequence({
    { name = "WindowSlideIn" },
    { name = "WindowPulse",   opts = { loop = 3 } },
    { name = "WindowSlideOut" },
}, {
    onComplete = function()
        window.Visible = false
    end,
})

-- Loop the whole sequence forever (e.g. an idle animation cycle)
Anim.sequence({
    { name = "IdleFloat" },
    { name = "IdleBob" },
}, { loop = true })

-- Use step-level options (different speed per clip)
Anim.sequence({
    { name = "Intro",   opts = { speed = 1.5 } },
    { name = "Content", opts = { delay = 0.1 } },
    { name = "Outro",   opts = { reverse = true } },
})

-- Keep handle to cancel mid-sequence
local seq = Anim.sequence({
    { name = "CutsceneA" },
    { name = "CutsceneB" },
    { name = "CutsceneC" },
})
-- Later, if the player skips:
seq.stop()

## Template animations

A template animation has no fixed target. Instead of being locked to the specific UI element you built it on, it can be applied to any structurally-compatible clone at runtime via Anim.playOn().

This is the right approach for reusable effects such as:

- Hover effects on many buttons that are created dynamically (e.g. an inventory grid)

- Card reveal animations applied to every card as it spawns

- Any animation you want to reuse across elements that share the same structure

### How to mark a clip as a template

- Open the animation in the plugin.

- Go to Animation → Template Animation. A ✓ badge appears next to the item when active.

- Save the clip. The targetId is removed from the save so the runtime knows it needs a target override.

### Calling Anim.play() on a template

If you call Anim.play("SlotHover") on a template clip without providing a target, the runtime prints a clear warning and returns a null handle (no animation plays). You must use Anim.playOn().

## Anim.playOn(instance, name, opts?)

Play a (template or normal) animation on a specific UI instance — typically a clone.

lua
Anim.playOn(slotFrame, "SlotHover")

Compared to Anim.play("SlotHover", { target = slotFrame }), playOn additionally:

- Assigns a unique key per (instance, name) pair so that playing the same animation on 50 clones simultaneously never stops each other.

- Keeps the delta base cache isolated per clone — so relative/delta animations ("offset by N from current value") read each clone's own starting value, not the first clone's.

All standard play() options work the same way.

### Example — inventory hover

lua
for _, slot in inventoryFrame:GetChildren() do
    slot.MouseEnter:Connect(function()
        Anim.playOn(slot, "SlotHover")
    end)
    slot.MouseLeave:Connect(function()
        Anim.playOn(slot, "SlotHover", { reverse = true, reset = true })
    end)
end

## Anim.stopOn(instance, name)

Stops playback for this instance + clip name: the run started by Anim.playOn(instance, name), and any active Anim.bindHover(instance, name, …) binding (each hover binding uses its own internal key, but stopOn clears all of them for that pair).

Anim.stopOn(slotFrame, "SlotHover")

## Anim.bindHover(instance, name, opts?)

Wire MouseEnter / MouseLeave on instance to play / reverse name in one call.

- Enter → plays the animation forward.

- Leave → plays it backwards, returning the element to its default (frame 0) state.

- Interrupt snap — bindHover defaults snapOnInterrupt = "start" on enter and leave. At stop() time, only a reverse run applies the frame-0 snap, so leaving a button still stops forward cleanly and runs reverse; a new forward on the same control can still interrupt a partial reverse and snap to rest first.

- False leave — MouseLeave is deferred one frame and ignored if the pointer is still over that control (Roblox can fire Leave on the destination when you jump between adjacent buttons). See Hover animations.

Returns a handle with a disconnect() method that tears down both event connections. If a forward hover is running (or finished on the hovered end pose), the runtime plays the same clip in reverse so the element returns to its default (frame 0) state—same as a normal MouseLeave. If a leave reverse is already playing, disconnect only stops that run (with the usual reverse snap to rest).

lua
local hover = Anim.bindHover(slotFrame, "SlotHover")

### Cleanup on destroy

``lua
local hover = Anim.bindHover(slotFrame, "SlotHover")

slotFrame.AncestryChanged:Connect(function()
    if not slotFrame.Parent then
        hover.disconnect()
    end
end)
``

### Example — mass button hover for a dynamically populated inventory

``lua
local activeHovers: { { disconnect: () -> () } } = {}

local function wireInventoryHovers(slots: { Frame })
    for _, h in activeHovers do h.disconnect() end
    table.clear(activeHovers)

for _, slot in slots do
    local h = Anim.bindHover(slot, "SlotHover")

    slot.AncestryChanged:Connect(function()
        if not slot.Parent then h.disconnect() end
    end)

    table.insert(activeHovers, h)
end

end

wireInventoryHovers(inventoryFrame:GetChildren())

inventoryFrame.ChildAdded:Connect(function()
    wireInventoryHovers(inventoryFrame:GetChildren())
end)
``

## Anim.bindButton(button, hoverAnim?, clickAnim?, opts?)

Combines hover + click clips on one GuiObject (e.g. ImageButton).

- Hover — MouseEnter plays the hover clip forward; MouseLeave plays it reversed. Hover defaults snapOnInterrupt = "start"; only stopping a reverse snaps to frame 0, so forward→reverse on leave is unchanged. Re-hover on the same button can still interrupt a partial reverse cleanly. Override with hoverOpts.snapOnInterrupt = "none" if needed.

- Pointer down — Records the hover playhead time. The hover clip is not stopped on press. If you have a click clip, it plays forward immediately in parallel with hover (both use RunService.Heartbeat; hover is registered first, then click, so on overlapping properties the click pose wins for that frame).

- Pointer up — If the click clip had started forward this press, plays it reversed; when that finishes, if the pointer is still over the button, starts the hover clip again. If there is no click clip, only the hover resume runs. By default (hoverResumeAfterClick omitted or "end") hover scrubs to the end of its timeline (full hover pose). Duration comes from the active handle when possible, otherwise from the saved clip JSON so it still works if hover already finished before you pressed (non-looping hover).

- hoverResumeAfterClick = "continue" — Resume from the playhead time when you pressed instead of the end.

Optional opts = { hoverOpts = PlayOpts?, clickOpts = PlayOpts?, hoverResumeAfterClick = "end" | "continue"? } ("end" is the default).

## Global helpers

Function
Description

Anim.stopAll()
Stop every currently running animation.

Anim.isPlaying(name)
Returns true if the animation is active.

Anim.getHandle(name)
Returns the Handle for a running animation, or nil.

Anim.clearInstance(inst)
Stop all animations whose target root is inst. Useful for cleaning up a UI element before destroying or hiding it.

Anim.stopBatch(instances)
Stop all animations on a list of instances. Equivalent to calling clearInstance() on each.

Anim.refresh()
Force a full re-scan of SavedUIAnimations (also clears delta-base caches). Usually unnecessary — the runtime auto-rescans on a missed clip and watches for new saves while Play is running.

Anim.getClipNames()
Returns a sorted list of clip names currently loaded from SavedUIAnimations. Use in Output to verify names.

Anim.sequence(steps, opts?)
Chain multiple clips one after another. Returns a SequenceHandle. See Sequence above.

## Troubleshooting (nothing moves / silent failures)

The runtime prints [UIAnimController] warnings to Output when something is wrong. Typical causes:

Symptom
What to check

Missing ReplicatedStorage/.../SavedUIAnimations
Use Install Runtime / Update Runtime in the plugin so the folder and JSON clips exist in the place.

“No animation named …”
Name must match the StringValue / folder name in the save. Case-sensitive. The runtime re-scans once automatically; if it still fails, call Anim.refresh() or use Anim.getClipNames() to list what loaded.

Template clip
Use Anim.playOn(instance, name) or Anim.play(name, { target = instance }).

Timeout finding UI
UI loads after play() — delay the call, or pass { target = rootFrame }. Re-link with Set Target in the plugin if you duplicated UI (_UIAID).

Clip loads, hover fires, no visible motion
Keyframes may be on a parent (e.g. CanvasGroup) while target is a child (ImageButton). The runtime resolves _UIAID on ancestors and path fallbacks from ancestor roots; use Update Runtime, or pass { target = theGuiObjectYouKeyframed }.

Clip “runs” but nothing changes (general)
Paths/GUIDs no longer match your hierarchy — re-open the clip with the correct UI selected and save again.

## stop() vs reset()

stop()
stop() + resetToStart
reset()

Freezes at current frame
✓ (default)
✗
✗

Snaps to frame 0
✗
✓
✓

Handle alive after
✗ (dead)
✗ (dead)
✓ (alive)

Can resume() after
✗
✗
✓

Removes from active table
✓
✓
✗

Use stop() when you are completely done with the animation.

Use stop() with resetToStart = true when you want the UI to snap back to its original position on stop.

Use reset() when you want to restart it later without calling play() again.

## Best practices & lifecycle

Practice
What to do

Open/close with one clip
Author a single clip (e.g. "PanelOpen"). Play it normally for open; for close use Anim.play("PanelOpen", { reverse = true, onComplete = function() panel.Visible = false end }).

Staggered list or grid
Use one clip (e.g. "FadeIn") and Anim.playBatch(items, "FadeIn", { stagger = 0.05 }). Keep the handle if you need to stop early; otherwise use clearInstance per item when tearing down.

Clean up before hide/destroy
Before setting Visible = false or destroying a GuiObject that might have animations on it, call Anim.clearInstance(inst). Stops all animations targeting that root so no handles outlive the UI.

Batch: keep the handle to stop
Anim.stop("FadeIn") stops a normal play("FadeIn") but not a batch. To stop a batch early, keep the return value and call batchHandle.stop(), or use Anim.stopBatch(instances).

## Tips

- Animation names are case-sensitive — "ButtonPop" ≠ "buttonpop".

- Playing the same animation name twice stops the first automatically.

- loop = true animations run forever — always pair with a stop() call when done.

- loop = N (a number) plays the clip exactly N times, then fires Completed automatically. No stop() needed.

- pingpong works with loop = true (bounce forever) or loop = N (N full round trips). Without loop, pingpong plays one round trip then stops.

- reset = true is useful for one-shot effects (e.g. click pops, notification slides) where the element should silently snap back to its original state after the clip finishes or is stopped — no manual restore code needed.

- deleteOnComplete = true is useful for fire-and-forget animations (e.g. click effects) where you never intend to call stop() manually.

- resetToStart = true is useful when you want the UI to visually "undo" when an animation is stopped (e.g. a slide-in that should slide back when cancelled).

- handle.setSpeed(n) can be used to slow, speed up, or reverse an animation mid-flight. It takes effect on the very next frame.

- handle.setLoop(false) is the clean way to stop a looping animation gracefully — it finishes the current pass before stopping, rather than cutting off mid-animation.

- Anim.clearInstance(inst) is the safest way to stop everything on a UI element before hiding or destroying it — you don't need to track individual handles.

- Anim.stopBatch(instances) is the companion to playBatch() when you need to stop a staggered group early.

- speed does not affect delay — the delay is always real-time seconds.

- If your UI was moved or renamed after saving, use { target = myGuiObject } to re-link.

- Anim.sequence() is the clean alternative to deeply nested onComplete callbacks when you need to chain clips. It handles the step logic for you and gives back a single handle to cancel the whole chain.
