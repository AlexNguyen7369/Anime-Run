# Hover Animations

## Overview

A hover animation plays when the mouse enters a UI element and reverses when the mouse leaves. You author one clip (the "hovered" state), and the runtime handles playing it forward on enter and backward on leave.

## Authoring the clip

- Set the animated element as the animation target.

- Author the animation as normal — keyframe 0s is the default state, the end frame is the hovered state. For example, a button hover might scale up slightly and brighten.

- Use delta mode on any tracks that should work regardless of the element's starting position or size.

- Save the clip.

{% hint style="success" %}
Keep hover animations short

Hover animations typically run 0.1–0.25 seconds. The reversed exit animation plays at the same speed, so a short clip snaps back quickly and feels responsive.

## {% endhint %}

## Wiring hover in code

### Anim.bindHover — the simple way

local Anim = require(
    game.Players.LocalPlayer.PlayerScripts.Xocoatl.UIAnimController
)

-- Wire hover automatically on a button
-- Returns a handle so you can disconnect later
local binding = Anim.bindHover(myButton, "ButtonHover")

-- To disconnect (e.g. when the button is destroyed)
binding.disconnect()
-- disconnect() unwinds hover like MouseLeave: it runs the reverse clip when needed so the UI does not stay stuck “hovered”.

bindHover wires MouseEnter and MouseLeave for you:

- On enter: plays the clip forward.

- On leave: plays the same clip reversed back to frame 0.

By default, bindHover passes snapOnInterrupt = "start" on enter and leave, but the runtime only snaps to frame 0 when stopping a reverse (quick re-hover on the same control). It does not snap when stopping forward to begin reverse, so moving the pointer to another button still plays the leave reverse normally. MouseLeave is deferred one frame and cancelled if the pointer re-enters the same control before the defer runs. After that defer, leave is also ignored if the cursor is still over that control — Roblox can fire a false Leave on the destination when you jump from one button to another. Each bindHover call also gets its own internal playback key (unlike playOn), so one button’s hover never stops another’s just because they share the same clip name. Pass snapOnInterrupt = "none" in the optional third argument if you want the older interrupt behaviour.

The reversed clip lands at frame 0 and stays there. The element does not snap back to the hovered state.

### Manual wiring — for template animations

If the clip was authored against a parent frame (not the button itself), you need to wire events on the button but play the animation on the root frame:

local slot = -- the parent frame (root of the animation)
local btn  = slot.InnerFrame.ImageButton

btn.MouseEnter:Connect(function()
    Anim.playOn(slot, "SlotHover")
end)

btn.MouseLeave:Connect(function()
    Anim.playOn(slot, "SlotHover", { reverse = true })
end)

This is the correct pattern when the animated clip is a template applied to a cloned frame — the button detects the hover, but the animation root is the slot frame.

## Applying hover to many buttons at once

When you have a list or grid of cloned UI elements:

local Anim = require(
    game.Players.LocalPlayer.PlayerScripts.Xocoatl.UIAnimController
)

local template = ReplicatedStorage.Assets.InventorySlot
local container = playerGui.ScreenGui.Inventory

local function populate(items)
    for i, data in items do
        local slot = template:Clone()
        slot.Name   = "Slot_" .. i
        slot.Parent = container

        local btn = slot.InnerFrame.ActionButton

        local enterConn = btn.MouseEnter:Connect(function()
            Anim.playOn(slot, "SlotHover")
        end)

        local leaveConn = btn.MouseLeave:Connect(function()
            Anim.playOn(slot, "SlotHover", { reverse = true })
        end)

        -- Clean up when the slot is destroyed
        btn.AncestryChanged:Connect(function()
            if not btn.Parent then
                enterConn:Disconnect()
                leaveConn:Disconnect()
                Anim.stopOn(slot, "SlotHover")
            end
        end)
    end
end

## Common issues

The element snaps back to the hovered state after the mouse leaves.

Do not pass reset = true in the leave options. The reset option snapshots the current (hovered) state before the reverse animation starts and restores it at completion — which is the opposite of what you want.

The hover animation plays but the element does not return to the default state.

Make sure your clip has a keyframe at 0s defining the default state. If the first keyframe is at 0.1s, the runtime has no defined "start" and the element may stay at whatever value it was tweening from.

Moving quickly from one hovered button to another pauses the second hover.

Each hover binding plays on its own key. If the second clip still reversed immediately, that was a false MouseLeave on the destination button. Runtime v0.080 ignores that leave when the pointer is still over the control, so both hovers run independently.

bindHover is passed the button but the animation does not play.

If the clip was authored with the parent frame as the animation root (not the button), bindHover will try to resolve paths from the button and fail. Use manual MouseEnter/MouseLeave wiring as shown above and pass the parent frame to playOn.
