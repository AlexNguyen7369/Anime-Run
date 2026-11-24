# Template Animations

## The problem they solve

A normal Xocoatl animation is tied to one specific UI element via a saved target GUID. That works well for unique screens (shop panels, menus, intros) but breaks down when you have many copies of the same element — an inventory system with 40 slots, a friend list that refills every time you open it, a grid of product cards.

You cannot author 40 separate animations. You need one animation that can be applied to any instance at runtime.

That is what template animations are for.

## How it works

A template animation has no fixed target. Instead of stamping a GUID onto one specific element, the animation data describes paths relative to whatever instance you pass in at runtime. You feed it an instance at runtime using Anim.playOn(instance, "ClipName").

## Creating a template animation in the plugin

- Select any representative instance of your repeated element in the Studio Explorer (e.g. one inventory slot).

- Click Animation → Set Target… to set it as the animation target.

- Create a new animation: Animation → New Animation.

- Before saving, open File → Save As, name the animation, and check the "Template Animation" checkbox.

- Build your keyframes as normal. Use delta mode on position and size tracks so the animation works regardless of where each instance starts.

- Save.

{% hint style="info" %}
Template clips in the Saves Browser

Template animations are shown with a distinct icon in the Saves Browser and are hidden from the regular Open Animation list. To open one for editing, select any compatible instance in the Explorer and click "Use Template" on the empty-state screen.

## {% endhint %}

## Applying a template at runtime

Use Anim.playOn(instance, clipName, opts?) instead of Anim.play. Pass the root of the instance you want to animate as the first argument.

local Anim = require(
    game.Players.LocalPlayer.PlayerScripts.Xocoatl.UIAnimController
)

-- Play the template on a specific instance
Anim.playOn(inventorySlot, "SlotReveal")

-- Play reversed (e.g. hide animation)
Anim.playOn(inventorySlot, "SlotReveal", { reverse = true })

The runtime resolves all property paths relative to inventorySlot — the same relative paths that were set up against the representative element you used when authoring.

## Common pattern: dynamically populated UI

This is the most common use case. You have a container that gets filled with cloned frames at runtime (inventory, friend list, card grid).

local Anim = require(
    game.Players.LocalPlayer.PlayerScripts.Xocoatl.UIAnimController
)

local template = ReplicatedStorage.Assets.SlotTemplate
local container = playerGui.ScreenGui.ItemContainer

local function populateSlots(items)
    -- Clear old slots
    for _, child in container:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end

    for i, itemData in items do
        local slot = template:Clone()
        slot.Name   = "Slot_" .. i
        slot.Parent = container

        -- Populate slot content
        slot.Icon.Image = itemData.icon
        slot.Label.Text = itemData.name

        -- Play reveal animation on each slot
        Anim.playOn(slot, "SlotReveal", { delay = (i - 1) * 0.04 })
    end
end

## Stopping a template animation

Use Anim.stopOn(instance, clipName) to stop a specific clip on a specific instance, or Anim.clearInstance(instance) to stop everything on that instance.

-- Stop one clip on one instance
Anim.stopOn(mySlot, "SlotReveal")

-- Stop all clips on one instance
Anim.clearInstance(mySlot)

## Naming note

Template animations resolve element paths from the root you pass in. If you created the template using a frame named SlotFrame with a child named Icon, then at runtime the instance you pass to playOn must also have a child named Icon. The names must match.

If you clone from the same template frame each time, the names always match automatically.

## Preview in Container

When authoring a template animation, the preview clone is sometimes placed in a generic preview wrapper, which gives it a different parent and size context than it will have in your real game. This can make scale-based sizing look wrong in the editor.

Enable Animation → Preview in Container to place the preview clone directly into the real parent of the target element. That way the clone sits in the same layout as your actual game UI so scale and size resolve correctly. This setting is saved with the animation clip.

{% hint style="info" %}
Layout engines

If the target's parent has a UIListLayout, UIGridLayout, or similar, the clone is placed directly in that parent (so the layout engine sizes it correctly) and renamed to _Preview_Name. If there is no layout engine, a _UIAnimPreview folder is created inside the parent to keep things tidy.
