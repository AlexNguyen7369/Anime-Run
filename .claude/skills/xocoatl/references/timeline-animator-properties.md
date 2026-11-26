# Animatable Properties

## Adding a property track

- Make sure the element is already added to the Track List (use the + button in the Hierarchy panel).

- On the element's header row in the Track List, click the [+] add property button (far right of the row).

- The property picker opens — browse by category or type in the search bar to filter.

- Click a property name to add it as a track, or click again on an already-tracked property to remove it.

Once added, the property track row appears under the element header, and a matching row appears in the Timeline.

{% hint style="success" %}
Already-added properties

Properties that are already on a track are highlighted in the picker. Click an already-tracked row again to remove that property track (with confirmation).

{% endhint %}ScreenGui Enabled (in-game visibility)

If your animation target is a ScreenGui, Xocoatl may show a ScreenGui Enabled toast while you work. Use Track + Enabled at 0s to track the ScreenGui, add Enabled, and keyframe true at 0s — so playback does not start with the UI hidden (common when the ScreenGui is disabled in Studio for editing).

If you add Enabled manually from the picker, the same toast offers Enabled at 0s for a one-click keyframe.

If your target is a Frame (or other child) inside a disabled ScreenGui, the toast explains that you should set the ScreenGui as the animation target to animate Enabled.

## {% endhint %}

## 2D particle tracks (Timeline)

{% hint style="warning" %}
Experimental

Particle tracks are experimental: defaults and behaviour may change. Use the dedicated guide for setup, sequence editing, and runtime notes: Particles (experimental).

{% endhint %}
Supported hosts: Frame, ImageButton, ImageLabel, TextLabel, TextButton, CanvasGroup.

- Add the element to the Track List (same as normal UI tracks).

- On the element header row, open the ⋮ menu and choose Make Particle Frame.

- A Particles header row appears under that element (same [⋮] / [+] layout as other track headers). Core particle rows are added automatically. [+] opens the particle property picker for optional physics rows such as Motion and Velocity Inheritance. [⋮] removes the entire particle system from this frame (confirm dialog).

- Keyframe particle properties on the same timeline as UI properties for that instance. Particle data is stored separately in the clip as particleTracks (not mixed with Roblox instance property tracks).

- Size and Transparency support NumberSequence over each particle’s lifetime: click Seq to open the graph editor (Time / Value only; no envelope). The editor can preview live on the clip; Cancel restores values from when you opened it, Confirm keeps your edits.

- Emit Container — ScreenGui (default) parents spawned ImageLabel particles under a full-screen layer. Emitter parents them under the host frame when you want them drawn/stacked with that UI and clipped by it.

Preview: press Play in the Timeline; particles simulate while preview playback is running (Studio PlayerGui). Runtime: injected UIAnimController / UIAnimPlayer read particleTracks and run the shared simulator alongside UI interpolation.

For the complete particle property list, value types, and min,max random range inputs, see Particles (experimental).

## Removing a property track

Click the [⋮] options button on the right side of the property track row, or right-click the row, and choose Remove Property. A confirmation dialog will appear before anything is deleted. The right-click menu opens at the pointer — same items as ⋮.

Removing a property track deletes all its keyframes and resets the preview clone back to the original value for that property.

## Value fields

Each property track row has an editable text field showing the current value at the scrubber time.

- Single-value properties (e.g. Rotation, BackgroundTransparency): type a number and press Enter.

- Compound properties (e.g. Position, Size): enter comma-separated values in xScale, xOffset, yScale, yOffset order. Shorthand: type a single number to apply it to all components at once (e.g. 0 zeroes out everything).

- Boolean properties (e.g. Visible, Enabled): shown as a checkbox — click to toggle.

- Color3 properties: shown as a colour swatch — click to open the Color Picker.

Pressing Enter after editing a value creates or updates a keyframe at the current scrubber time automatically.

### Compound property sub-rows

For compound properties like Position and Size, the track row has a collapse arrow on the left. Click it to expand the row into individual sub-rows — one per component (e.g. X Scale, X Offset, Y Scale, Y Offset). Sub-rows are collapsed by default. This is useful for inspecting or keyframing only one component at a time.

## Delta (relative) mode

The △ toggle button on each track row switches between absolute and relative mode:

- Absolute (off, grey): keyframe values are stored as exact property values.

- Relative / Delta (on, blue): keyframe values are stored as offsets from the element's original value at animation start. Useful when you want the animation to work regardless of where the element starts.

## Supported properties by class

### All GuiObjects (Frame, CanvasGroup, TextLabel, ImageLabel, etc.)

Property
Type

Position
UDim2

Size
UDim2

AnchorPoint
Vector2

Rotation
number

Visible
boolean

BackgroundColor3
Color3

BackgroundTransparency
number

BorderColor3
Color3

BorderSizePixel
number

LayoutOrder
number

ZIndex
number

ClipsDescendants
boolean

AutomaticSize
Enum

Active
boolean

Interactable
boolean

SizeConstraint
Enum

### TextLabel / TextButton / TextBox (adds)

Property
Type

Text
string

TextColor3
Color3

TextTransparency
number

TextSize
number

TextScaled
boolean

TextWrapped
boolean

TextXAlignment
Enum

TextYAlignment
Enum

Font / FontFace
Enum / Font

RichText
boolean

TextStrokeColor3
Color3

TextStrokeTransparency
number

LineHeight
number

TextDirection
Enum

TextTruncate
Enum

### ImageLabel / ImageButton (adds)

Property
Type

Image
Content

ImageColor3
Color3

ImageTransparency
number

ScaleType
Enum

ImageRectOffset
Vector2

ImageRectSize
Vector2

SliceCenter
Rect

SliceScale
number

TileSize
UDim2

ResampleMode
Enum

### CanvasGroup (adds)

Property
Type

GroupTransparency
number

GroupColor3
Color3

Recommended for panel fade — Wrap a section (e.g. modal, card) in a CanvasGroup and animate GroupTransparency to fade the whole block. One property, efficient, no need to keyframe every child.

### ScrollingFrame (adds)

Property
Type

CanvasSize
UDim2

CanvasPosition
Vector2

ScrollBarThickness
number

ScrollingDirection
Enum

ScrollingEnabled
boolean

ScrollBarImageColor3
Color3

ScrollBarImageTransparency
number

### UIScale

Property
Type

Scale
number

### UIStroke (Stroke)

Property
Type

Color
Color3

Thickness
number

Transparency
number

Enabled
boolean

BorderOffset
UDim

### UICorner (Corner)

Property
Type

CornerRadius
UDim

Property
Type

TopLeftRadius
UDim

TopRightRadius
UDim

BottomRightRadius
UDim

BottomLeftRadius
UDim

Per-corner radii are always available when this Studio build supports them (fully released by Roblox). See Roblox's UICorner reference.

CornerRadius is a shorthand: writing it sets all four individual radii, and reading it returns TopLeftRadius. Avoid animating CornerRadius and individual corner radii at the same time unless you intentionally want the shorthand track to overwrite the corners.

### UIShadow

Property
Type

Enabled
boolean

BlurRadius
UDim

Color
Color3

Offset
UDim2

Spread
UDim2

Transparency
number

ZIndex
number

UIShadow is fully released. Tracks appear when this Studio build exposes the API. See Roblox's UIShadow reference for current limitations.

UIShadow renders below its parent UI instance. Roblox notes that ZIndex controls ordering between multiple shadows and is typically negative because shadows render under the parent.

### UIGradient (Gradient)

Property
Type

Color
ColorSequence

Transparency
NumberSequence

Type
Enum.GradientType (Linear, Radial, Conical)

TileMode
Enum.GradientTileMode (Clamp, Repeat, Mirror)

Scale
number

Rotation
number

Offset
Vector2

Enabled
boolean

Type, TileMode, and Scale appear when this Studio build exposes Upgraded UIGradients (File → Beta Features). See Roblox’s UIGradient reference. Enum tracks hold until the next key; Scale interpolates like other numbers. While the feature is still a Studio Beta, published clients may not draw Radial / Conical / tile / scale yet — preview in Studio until Roblox ships it to the client.

Authoring

- Color — Click the gradient swatch on the track row to open the Gradient Editor. Per-stop alpha in the colour picker is split into Color (RGB only) and Transparency (NumberSequence values; envelope is always 0). Keyframe pairwise interpolation matches stop indices between keyframes. Saved gradient presets store both sequences, so picking a preset in the Color Picker and applying it matches alpha as well as colour.

- Transparency — The track row is read-only (summary text). Do not animate transparency separately from the colour bar; add a Transparency track only when you need per-stop alpha in the clip. When both Color and Transparency tracks exist, the plugin keeps their keyframe times aligned (paste, drag, Studio property sync, gradient confirm).

- Type — Linear is the classic left-to-right sweep. Radial radiates from Offset. Conical sweeps clockwise around Offset; Rotation is the start angle. The track row has a dropdown (these properties are not in Studio’s Properties list while the beta is NotBrowsable).

- TileMode — Clamp holds the end colours (today’s default). Repeat loops the sequence. Mirror flips each tile. Same dropdown on the track row.

- Scale — How far the gradient extends (Linear: distance between keypoint edges; Radial: outer radius; Conical: angular sweep). Default is 1. Typed on the track like other numbers.

- Relative (Δ) mode is disabled for all UIGradient properties listed above.

### UIPadding (Padding)

Property
Type

PaddingTop
UDim

PaddingBottom
UDim

PaddingLeft
UDim

PaddingRight
UDim

## Effects (Camera & Post-processing)

Effects let you animate properties that live on the local player's Camera rather than inside the UI hierarchy. They are added separately from regular elements.

### How to add an effect

- In the menu bar, go to Animation → Add Effects.

- A searchable dropdown opens — browse or type to filter (e.g. "blur", "color"), then click the effect to add it.

- The effect appears in a blue EFFECTS section at the bottom of the Track List.

- Click the [+] add property button on the effect's header row to add property tracks, exactly like a regular element.

The entire EFFECTS section can be collapsed by clicking its collapse arrow.

### Managing effects

- Click the ▶ collapse arrow on an individual effect row to hide its property tracks.

- Click [⋮] options → Remove Effect to remove an effect and all its property tracks.

### Notes

- Effects are local-player-only — they are parented to workspace.CurrentCamera (or Lighting for post-processing effects) at runtime.

- The runtime creates the effect instance when the animation starts and removes it when the animation stops or completes. No instance needs to exist in the place beforehand.

- Timeline preview — while you scrub or play in the editor, effect values apply to live preview instances (e.g. blur on CurrentCamera, color correction in Lighting). Keyframe diamonds and add/remove/drag behave like normal property tracks.

- UI + effects in one clip — add your UI element tracks and effect tracks in the same animation, then play it once with Anim.play("ClipName"). You do not need separate tweens for UI and color correction.

### Supported effects and properties

#### Camera

Property
Type
Notes

FieldOfView
number
Camera field of view in degrees

#### BlurEffect

Property
Type
Notes

Size
number
Blur radius (0–56)

Enabled
boolean
Toggle blur on/off

#### ColorCorrectionEffect

Property
Type
Notes

Brightness
number
Brightness offset (–1 to 1)

Contrast
number
Contrast adjustment (–1 to 1)

Saturation
number
Saturation adjustment (–1 to 1)

TintColor
Color3
Colour tint applied to the scene

Enabled
boolean
Toggle correction on/off

#### BloomEffect

Property
Type
Notes

Intensity
number
Bloom additive blending intensity

Size
number
Bloom radius in pixels

Threshold
number
Minimum brightness to bloom

Enabled
boolean
Toggle bloom on/off

#### SunRaysEffect

Property
Type
Notes

Intensity
number
Strength of sun rays (0–1)

Spread
number
Angular spread of rays (0–1)

Enabled
boolean
Toggle sun rays on/off

#### DepthOfFieldEffect

Property
Type
Notes

FocusDistance
number
Distance to the in-focus plane

InFocusRadius
number
Radius of the sharp zone

NearIntensity
number
Blur strength for near objects (0–1)

FarIntensity
number
Blur strength for far objects (0–1)

Enabled
boolean
Toggle depth of field on/off

## Rig joints (Transform)

Character / Motor6D rig targeting is off in this build. Selecting a dummy does nothing, and Transform joint tracks are not offered. When that surface ships again, Set Target on a character Model will list Motor6D joints on the left as Transform tracks.
