# Updating the fork

## RestedXP (upstream)

```bash
git fetch upstream-rxp --tags
git switch main
git merge vX.Y.Z            # the new RestedXP tag
```

Resolve conflicts, keeping every line marked `FORK:`. Then check they are all still there:

```bash
grep -rn "FORK:" --include="*.lua" --include="*.toc" .
```

Expected: 3 lines. Two are comments in `RXPGuides.toc`: one above `## SavedVariables`, one above the `ForeverBuilds\…` / `SGJ\…` block. The third is in `SettingsPanel.lua`, before `RegisterOptionsTable`. Also check that the SavedVariables line still lists `RXP_SGJ_Settings, RXP_SGJ_DB` and that the three `[AllowLoadGameType camelot]` lines are still there.

Then run the tests (below) and the in-game checklist in `README-FORK.md`.

## Sharpie's Gear Judge (embedded engine in `SGJ/`)

```bash
python3 -I tools/vendor_sgj.py --ref <new upstream commit>
```

The script clones `Supersharpie/SharpiesGearJudge`, rebuilds `SGJ/` and replaces it only if everything succeeds:

- **"unsupported top-level vararg form"**: a new upstream file declares its namespace differently. Teach `transform_lua` the new form.
- **"listed file missing upstream"**: upstream renamed or removed a file. Update `tools/sgj_files.txt` from the new `SharpiesGearJudge_Forever.toc` (always without `WhatsNew.lua` and `AddonPanel.lua`).
- **"patch … does not apply"**: rewrite that patch in `tools/sgj_patches/` against the new source. Vendor once without the patch (move it aside), edit the copy, and regenerate it with `diff -u` (paths `a/<file>` / `b/<file>`).

The patches (in order):
1. `0001-no-minimap.patch`: no minimap button.
2. `0002-no-slash-commands.patch`: no `/sgj` and similar commands.
3. `0003-pin-mode-and-pvp.patch`: the build chosen in RestedXP decides the profile and PvP.

Never take anything from `SharpiesGearJudge_Talents` (no license).

## Tests

```bash
brew install luajit   # once
luajit tests/run.lua
python3 -I tests/test_vendor.py
```
