# Install the Runtime

The runtime is a small set of scripts that makes your saved animations actually play when the game runs. It is separate from the editor plugin and needs to be installed once per place.

## How to install

- Open the Timeline Animator (toolbar → Timeline Animator).

- If the runtime is missing, a prompt appears when you open the widget — click Install Runtime, or use Status in the title bar.

- If an animation is already open, go to the landing screen via File → Close Animation and use Status in the title bar (install / reinstall and plugin version).

The runtime is placed at:

StarterPlayerScripts
└── Xocoatl           ← folder
    ├── RuntimeMain            ← LocalScript
    ├── UIAnimController       ← ModuleScript (your API)
    ├── UIAnimPlayer           ← ModuleScript (internal)
    ├── Animator               ← ModuleScript (internal)
    ├── Scanner                ← ModuleScript (internal)
    └── ConfigReader           ← ModuleScript (internal)

{% hint style="success" %}
You do not need to touch any of these files. Only UIAnimController is public — require it from your own LocalScripts.

## {% endhint %}

## Updating the runtime

When the plugin updates it bumps an internal version number. Status in the title bar shows the installed runtime version (and the new one when an update is waiting). Click it to reinstall — it is always available, even when the runtime is already up to date. Opening the Timeline Animator also shows an update prompt; Not now stays locked for a few seconds so Update Runtime is the easy first click. Skipping asks once more — only skip if you edited the runtime scripts yourself and need to keep those changes. An outdated or missing runtime can break in-game playback.

If a runtime is already installed, clicking the button asks for confirmation first. Reinstalling removes and replaces the StarterPlayerScripts/Xocoatl folder only — saved animations are not affected, but any custom scripts you added inside that folder are lost.

Plugin updates (new semver or patch build) must be installed from Plugin Manager in Studio; the plugin shows a prompt with the full identity (v0.2.1 - B41 - P13 → newer B / P / semver as appropriate).

Update replaces whatever runtime folder is already in StarterPlayerScripts — including older names like PizzaUIAnimator or a leftover RuntimeSource folder — and reinstalls the current Xocoatl folder. You do not need to delete the old folder manually.

{% hint style="warning" %}
Always keep the runtime in sync

Animations may not play correctly with an outdated runtime. The runtime version is checked every time the editor opens.

## {% endhint %}

## Where plugin data lives

All data is stored under a single folder in ReplicatedStorage:

ReplicatedStorage
└── XocoatlSaves              ← tagged XocoatlPersistenceRoot
    ├── SavedUIAnimations   ← UI animation clips (JSON)
    ├── SavedUIAssets       ← saved UI asset storage (reserved)
    ├── ColorPresets
    ├── GradientPresets
    ├── Keybinds
    ├── PreviewSettings
    ├── DesignerVariables   ← UI Designer colour / number / gradient tokens
    ├── DesignerViewportSizes
    ├── DesignerPreferences
    └── RT                    ← runtime version marker (used by plugin checks)

The runtime finds this folder by the XocoatlPersistenceRoot tag first, then falls back to ReplicatedStorage/XocoatlSaves and older ReplicatedStorage/ChocosToolsSaves projects. You can move or rename the saves folder if the tag stays with it.

The runtime scans SavedUIAnimations at startup and builds a name → clip lookup table. Folders inside it are supported at any nesting depth.

Rig clips are not in this folder. The plugin stores them in the AnimSaves container on the character (shared with Moon Animator). The UI runtime does not play those sequences.
