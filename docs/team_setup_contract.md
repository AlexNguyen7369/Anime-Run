# Team Setup and entry points: UI contract (design doc 4.45, owner 2026-11-17)

Implementer and test writer both follow this. Temporary build note; folded into the test headers at merge.

## Team Setup page: `PlayerGui.RacerTeam.Panel` (PanelSwitch "Team", PanelFrame.Attach as before)
- `Header/Title` text "Team Setup"; `Header/Close` (X); `Header/BonusButton` (TextButton "Team Bonus").
- `BonusPopover` (Frame, hidden until BonusButton is pressed, a second press or Close hides it): `Name` (bonus name or
  "No team bonus"), `Effect`, `Total` ("Total <n> s" summed stamina of the deployed Team).
- `Dots/Dot1..3` (Frame): `BackgroundTransparency` < 0.5 when that draft slot is filled, else >= 0.5.
- `Altars/Altar1..3` (TextButton, left to right, same Y, not overlapping each other):
  - `SlotLabel` "Slot n"; `Pedestal` (ViewportFrame holding a Model "Altar" of octagonal tiers built by
    `SpawnArea.Octagon`, the same 4-bar octagon the Sidekick altar uses);
  - member: `Portrait` (ImageLabel, shown, its CharacterPortraits image when it has one), `Name` (character name),
    `Info` (rarity and cruise, "Legendary · 120 studs/s"), `Gear` (see icons below);
  - empty: `Plus` "+" and `Add` "Add Character" shown, Portrait/Name/Info hidden;
  - `Remove` (TextButton "Remove"), shown only while that altar is selected and holds a member.
  - attribute `Selected` (bool) on the selected altar.
- `Footer/TeamName` "Team 1"; `Footer/Status` "Ready" when draft == saved Team, else "Unsaved changes";
  `Footer/Count` "<n> / 3 Slots Filled"; `Footer/Progress/Fill` (Size.X.Scale = n/3).
- `Tray/Tabs/Characters`, `Tray/Tabs/Sidekicks` (TextButtons; attribute `Active` true on the shown tab);
  `Tray/Sort` (GuiButton), `Tray/Search` (TextBox), `Tray/Roster` (ScrollingFrame):
  - Characters tab: one card per owned character (RosterCard), named by its id; `Badge` "TEAM n" on draft members.
  - Sidekicks tab: one card per Sidekick bag entry, named by its Entry id, attribute `SidekickId`.
- `QuickSetup` (TextButton "Quick Setup"), `Deploy` (TextButton "Deploy"; attribute `Enabled` false while draft == saved
  Team or the draft is empty).
- `ConfirmClose` (Frame, hidden): `Deploy`, `Discard` TextButtons. Shown when Close / X / T / outside click is used while
  the draft differs from the saved Team; the panel stays open until one is chosen. Discard closes and keeps the saved Team.
  Deploy deploys then closes.
- No `BestTeam` anywhere (still), no `Slots`, `Bonus` at Panel level any more.

## Interaction (client draft; the server decides)
- Open: draft = saved `Team` attribute. Nothing is sent.
- Tap an altar: it becomes selected. Tap a character card while an altar is selected: the card goes to that slot in the
  draft (a member already on another slot swaps). Card first, then altar, works too. Tapping the selected member's own
  card again on its own altar removes it (as before). `Remove` takes the member off the draft. The draft never sends.
- `QuickSetup`: invokes `Remotes.TeamQuickPick(draftIds)` and fills the empty draft slots in order with the answer.
- `Deploy`: invokes `Remotes.SetTeam(draft)` (unchanged). On success the panel plays the altar activation and closes
  (about 1 s). On refusal it stays open, the draft is kept and `Footer/Status` shows the server's message
  ("Stop running to change your Team").
- Sidekicks tab: tap a Sidekick card, then an occupied altar: invokes `Remotes.SidekickEquip(characterId, entry)` at once.

## Gear icons (`Shared`-free, client `RosterCard.Gear(card, characterId)`)
- On every character card in Roster and in each occupied altar: `Gear` Frame anchored top-right inside its parent, with
  `Relic` (ImageLabel, diamond: Rotation 45 holder, the relic's `Image`) shown when `RelicGear[characterId]` is set, and
  `Sidekick` (ImageLabel, round UICorner 1, the sidekick's drawn portrait) shown when `SidekickGear[characterId]` is set.
  Attributes `ItemName`, `Rarity` on each icon. The Gear frame lies in the parent's top-right quarter.
- Tooltip: `PlayerGui.UiTooltip.Tip` (Frame) with `Title`, `Rarity`, `Body` labels; shown on MouseEnter /
  SelectionGained / Activated of an icon, with Title == the icon's ItemName; hidden on MouseLeave / SelectionLost.

## Server: `Remotes.TeamQuickPick` (RemoteFunction) -> `GachaService.QuickPick(player, draftIds)`
- Returns `true, ids` where ids = draftIds' members (kept in place) with the empty slots filled by owned characters not
  already in the draft, highest `RaceConfig.Cruise(spec)` first, ties to the higher rarity (`GachaConfig.RARITY_ORDER`),
  then catalog order. Never more than 3 ids, never a duplicate, never an unowned id. Never changes `Team` or saved data.
- Bad input (non-table, >3, non-strings, unowned or duplicate ids in the draft) returns `false, "Invalid team"`.
  0.5 s cooldown like SetTeam.

## Entry points
- `HudChrome/ShopColumn/Summon` (ImageButton like Shop, label "Summon", key letter "G", attribute `Panel` "Sidekicks"):
  press or G calls `PanelSwitch.Action("Sidekicks")`.
- `RacerHud` team minibar: `TeamHud` adds a TextButton `OpenTeam` covering the team row; press calls
  `PanelSwitch.Action("Team")`.
- Plaza: a Model `TeamAltar` inside the plaza model that holds `SidekickAltar` (octagonal tiers via `SpawnArea.Octagon`) at about (-3.1, 83.9) with a
  ProximityPrompt named `OpenTeam` (ActionText "Team"); `PlazaPrompts` maps `OpenTeam` to `PanelSwitch.Action("Team")`.
  The Sidekick altar prompt `OpenSidekicks` ActionText becomes "Summon".
- Transition: `PlayerGui.UiTransition` (ScreenGui) with `Paper` frame; plays when the Team or Sidekicks panel opens and
  closes; attribute `Playing` true while it runs; under reduced motion it only fades. Opening a panel twice while the
  transition runs leaves exactly one panel open.
- Input lock: while Team or Sidekicks is open, `Players.LocalPlayer:GetAttribute("PageInputLocked") == true`; false
  after close.
