# Reuse & Batch

## Playing on many instances at once

Anim.playBatch(instances, clipName, opts?) plays the same clip on a list of instances simultaneously. An optional stagger delay cascades the start time across each instance, creating the typical "items falling in one after another" reveal effect.

local Anim = require(
    game.Players.LocalPlayer.PlayerScripts.Xocoatl.UIAnimController
)

local slots = container:GetChildren()

-- Play on all slots, each starting 60ms after the previous
local batch = Anim.playBatch(slots, "CardReveal", { stagger = 0.06 })

-- Stop all at once if needed
batch.stop()

The batch handle exposes stop(), pause(), and resume() which apply to every instance in the batch.

## Sequences

Anim.sequence(steps, opts?) plays a list of clips one after another. Each step starts when the previous one finishes.

local handle = Anim.sequence({
    { name = "PanelSlideIn" },
    { name = "PanelFadeContent", opts = { delay = 0.1 } },
    { name = "PanelIdlePulse",   opts = { loop = true } },
})

-- Stop the whole sequence
handle.stop()

Steps are played in order. Each step accepts its own opts table with the same options as Anim.play.

## Stopping everything on an instance

Anim.clearInstance(inst) stops every active animation whose root is inst.

-- Before hiding or destroying
Anim.clearInstance(myPanel)
myPanel.Visible = false

Call this before:

- Setting a UI element's Visible to false

- Destroying a cloned element

- Swapping out a screen

This prevents handles from outliving the UI they target and avoids conflicts when the same element is shown again later.

## Refresh after saving new animations during Play

The runtime scans for saved animations when the game starts. If you save a new animation while in Play mode, it will not be visible until you call:

Anim.refresh()

Then you can Anim.play("NewClipName") as usual.

## Stopping by clip name vs. by instance

Method
What it stops

handle.stop()
The specific run returned by play or playOn

Anim.stopOn(inst, name)
The run of name on the specific instance inst

Anim.clearInstance(inst)
Every animation on inst, regardless of name

Use clearInstance when you want a clean slate (e.g. before destroying UI). Use stopOn when you only want to cancel one specific clip while letting others continue.

## Design pattern: list or grid reveal

local function showGrid(items)
    -- Clear previous content
    for _, child in container:GetChildren() do
        if child:IsA("Frame") then
            Anim.clearInstance(child)
            child:Destroy()
        end
    end

    -- Populate and animate
    local newSlots = {}
    for i, data in items do
        local slot = slotTemplate:Clone()
        slot.Name   = "Slot_" .. i
        slot.Parent = container
        -- populate slot...
        table.insert(newSlots, slot)
    end

    Anim.playBatch(newSlots, "SlotReveal", { stagger = 0.04 })
end

## Design pattern: open/close with one clip

Author a single "open" animation. Use reverse = true for close. No second clip needed.

local isOpen = false

openButton.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    Anim.play("PanelOpen", { reverse = not isOpen })
end)

Or with resetToStart if you want the element to snap back to its initial state when stopped:

Anim.play("ButtonPress", { reset = true })

reset = true restores all animated properties to the values they had before the animation started, once the clip finishes or is stopped.
