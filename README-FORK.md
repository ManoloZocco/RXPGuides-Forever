# RestedXP – WoW Forever personal edition

A private, personal fork of [RestedXP Guides](https://github.com/RestedXP/RXPGuides) for **World of Warcraft: Forever**,
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

## Updating

See `docs/UPDATING.md`.
