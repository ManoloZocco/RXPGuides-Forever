# RestedXP – WoW Forever personal edition

A personal, non-commercial fork of [RestedXP Guides](https://github.com/RestedXP/RXPGuides) for **World of Warcraft: Forever**,
with the gear engine of [Sharpie's Gear Judge](https://github.com/Supersharpie/SharpiesGearJudge) built in.
See `NOTICE.md` for licenses and attributions.

## What it adds (Forever only)

- **Forever Build** tab in the RestedXP settings: choose a build for each talent spec, for example
  "Feral Cat: Solo Leveling – Feral Combat" or "Bear: Dungeon Leveling – Feral Combat".
  *Automatic* recognises the build from your talents for gear only.
- **Gear verdicts by Sharpie's engine**, following the chosen build:
  - tooltip verdict;
  - bag arrows;
  - loot alert;
  - markers on quest rewards, merchants, loot rolls, professions and the character sheet.
- **Talent guide**: a panel next to the talent window ("Now" / "Next" talents), a chat line on each level-up
  and a highlight on the next node in the talent window (when the client allows it).
- Builds with an incomplete talent order are marked "(incomplete: N/51)": their levels may not match.

Do **not** enable the standalone *Sharpie's Gear Judge* addon at the same time: the built-in engine turns itself off and says so in chat.

## Install

1. Download `RXPGuides-<version>.zip` from the [Releases](../../releases) page.
2. Close the game. In `World of Warcraft/_forever_/Interface/AddOns/`, move the existing `RXPGuides` folder somewhere else as a backup.
3. Extract the zip there: you get a new `RXPGuides` folder. RestedXP settings and guide progress are kept.
4. If an addon manager (CurseForge app, WowUp…) handles RestedXP, turn off its updates for RestedXP, or it will overwrite this version.
5. In game: `/rxp` opens the settings, tab **Forever Build**.

## Commands

- `/rxpfb`: build of each spec, build recognised from your talents, engine version.
- `/rxpfb check`: checks every build of your class against your talent tree and says whether the highlight works.
- `/rxpfb talents`: show or hide the talent panel without the talent window.

## In-game checklist

1. `/reload` gives no Lua errors, both with *Automatic* and with a chosen build.
2. An item tooltip shows only Sharpie's verdict (no RestedXP "EP" line).
3. Bag arrows appear on upgrades.
4. Looting or receiving an upgrade shows the alert.
   - 4b. Markers appear on quest rewards, merchant, loot roll, professions and the character sheet.
5. Changing the build changes both the verdict and the talent panel at once.
6. With the talent window open, the panel lists the right talents for your level and build, and the next node is highlighted (if `/rxpfb check` says `highlight: available`). Each level-up prints the next talent in chat.
7. No Sharpie's minimap button or window.
8. With the standalone Sharpie's Gear Judge enabled, a clear chat warning appears.
9. The talent panel is fully on screen next to the talent window (not cut off at the right edge).
10. Learning talents with the highlight active gives no "action blocked" / "interface action failed" message. If it does, report it: the highlight can be switched off without losing the panel.

## Updating

See `docs/UPDATING.md`.
