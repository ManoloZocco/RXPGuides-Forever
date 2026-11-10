# RXPGuides-Forever (RestedXP + motore Sharpie's) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un fork privato di RestedXP per WoW Forever in cui una sola scelta di build, fatta nelle impostazioni di RestedXP, guida i talenti livello per livello e la valutazione degli oggetti fatta dal motore di Sharpie's Gear Judge, incorporato nell'addon.

**Architecture:** Il repo è RestedXP (`RestedXP/RXPGuides` dal tag `v4.11.34`).
- `SGJ/` contiene una copia **generata** dei file di Sharpie's, prodotta da uno script Python che applica trasformazioni meccaniche e patch.
- `ForeverBuilds/` contiene tutto il codice nuovo: bootstrap, catalogo build, risoluzione talenti, generatore guide, stato, opzioni, avvisi.
- I file originali di RestedXP vengono toccati solo con righe marcate `-- FORK:`.
- La logica pura (catalogo, generatore, stato) si testa fuori dal gioco con LuaJIT, che ha la stessa semantica Lua 5.1 di WoW.

**Tech Stack:** Lua 5.1 (WoW), Ace3 (AceConfig, già in RestedXP), Python 3 per lo script di vendoring, LuaJIT per i test, git + GitHub (`gh`).

**Spec:** `docs/superpowers/specs/2026-11-11-rxp-forever-sgj-design.md`. L'originale è nello scratchpad della sessione, in `design/`, e il Task 1 lo copia nel repo.

## Global Constraints

- Il gioco è solo **WoW Forever**: Interface `16001`, game type `camelot`, `addon.game == "FOREVER"`. Tutti i file nuovi si caricano con `[AllowLoadGameType camelot]`.
- Base RestedXP: tag `v4.11.34` (commit `b4a0f99a2ceac856f75a11594bcaa19886236a01`). Base Sharpie's: `Supersharpie/SharpiesGearJudge` commit `f285a2b51a2d0a79a58f61ead60af9c2270f76f5` (v3.3.2-Forever).
- Repo GitHub **privato** `ManoloZocco/RXPGuides-Forever`. Remote: `upstream-rxp` = `https://github.com/RestedXP/RXPGuides.git`. Sharpie's non è un remote: viene clonato dallo script in una cartella temporanea.
- **Vietato** usare qualsiasi contenuto di `Supersharpie/SharpiesGearJudge_Talents` (repo senza licenza). Gli ordini dei talenti vengono solo da `Data/BuildMatch_Forever.lua`.
- Licenze: il fork resta **CC BY-NC-SA 4.0**. `SGJ/LICENSE` contiene il testo MIT di Sharpie's. `NOTICE.md` alla radice attribuisce entrambi.
- Ogni modifica a un file originale di RestedXP sta su righe che contengono `-- FORK:`. `grep -rn "FORK:"` elenca tutte le modifiche.
- I commit **non** contengono righe `Co-Authored-By`, link di sessione o altre attribuzioni a Claude: è un'istruzione dell'utente.
- Testi visibili in gioco in inglese, come il resto di RestedXP.
- SavedVariables del motore rinominate: `SGJ_Settings` → `RXP_SGJ_Settings`, `SharpiesGearJudgeDB` → `RXP_SGJ_DB`.
- Namespace privato del motore: la tabella globale `RXP_SGJ_NS`, che è anche l'`MSC` di tutti i file in `SGJ/`. Interruttore globale: `RXP_SGJ_DISABLED`, `true` se l'addon standalone Sharpie's è abilitato.
- Build salvate in `RXPCData.foreverBuilds[group]` (`group` = 1 o 2, gruppo di specializzazione) con valore `buildId` (string) o `"AUTO"`. Il default è `"AUTO"`.
- **Item Upgrades di RestedXP resta spento su Forever:** la v4.11.34 originale esclude già `FOREVER` in `ItemUpgrades.lua:6`, e la patch locale installata finora **non** va riportata nel fork.
- Una build "completa" ha esattamente **51** punti. Il primo punto talento si prende al livello **10**.

## Review Focus

1. **Personaggio sotto il livello 10 o senza punti spesi:** nessun errore Lua. La guida si registra comunque e l'evidenziazione parte al 10. Test: Task 6, `test_guide_levels_start_at_10`.
2. **Stesso talento in più blocchi** (es. `17056, 3` poi `17056, 1`): il grado deve proseguire, cioè 4 e non 1. Test: Task 6, `test_rank_accumulates_across_blocks`.
3. **Talento non risolto** (spellID che non corrisponde a nessun talento dell'albero): passo vuoto con commento `UNRESOLVED`, livelli successivi non spostati, avviso. Test: Task 6, `test_unresolved_keeps_alignment`.
4. **Addon standalone Sharpie's installato:** il motore incorporato non parte, si vede un solo avviso in chat e non compare nessun errore su nomi globali in conflitto. Test: Task 3, `test_disabled_when_standalone_enabled`. Verifica in gioco: checklist punto 8.
5. **Build salvata non più esistente dopo un aggiornamento di Sharpie's:** `BuildState` torna a `"AUTO"` senza errori. Test: Task 7, `test_unknown_build_falls_back_to_auto`.

---

### Task 1: Repo, licenze, ambiente di test

**Files:**
- Create: `NOTICE.md`, `tests/run.lua`, `tests/wow_stubs.lua`, `tests/test_smoke.lua`, `docs/superpowers/specs/2026-11-11-rxp-forever-sgj-design.md` (copia), `docs/superpowers/plans/2026-11-11-rxp-forever-sgj-plan.md` (copia di questo file), `.gitattributes` (`*.lua text eol=lf`)
- Modify: nessun file di RestedXP

**Interfaces:**
- Produces: `luajit tests/run.lua` esegue tutti i `tests/test_*.lua`. Ogni file di test restituisce una tabella `{ [nome] = function() ... end }`. La funzione globale `assert_eq(actual, expected, msg)` confronta in profondità le tabelle. `tests/wow_stubs.lua` espone `Stubs.install(opts)`, che definisce globali WoW fittizi (`GetSpellInfo`, `GetNumTalentTabs`, `GetNumTalents`, `GetTalentInfo`, `GetTalentTabInfo`, `UnitClass`, `UnitLevel`, `C_AddOns`, `GetAddOnEnableState`, `UnitName`, `CreateFrame` minimale) a partire da `opts.talents = { [tab] = { {name=, tier=, column=, maxRank=}, ... } }` e `opts.spells = { [spellID] = name }`.

- [ ] **Step 1:** Chiedi conferma all'utente prima di creare il repo GitHub. Poi `brew install luajit` e verifica: `luajit -v` stampa `LuaJIT 2.1`.
- [ ] **Step 2:** Clona la base: `git clone https://github.com/RestedXP/RXPGuides.git ~/Developer/RXPGuides-Forever && cd ~/Developer/RXPGuides-Forever && git checkout -b main v4.11.34 && git remote rename origin upstream-rxp`.
- [ ] **Step 3:** `gh repo create ManoloZocco/RXPGuides-Forever --private --source . --remote origin`. Verifica: `gh repo view ManoloZocco/RXPGuides-Forever --json visibility` restituisce `PRIVATE`.
- [ ] **Step 4:** Scrivi `tests/test_smoke.lua` con il test `test_harness_works`, che verifica `assert_eq({a={1,2}}, {a={1,2}})` e che `pcall(assert_eq, 1, 2)` restituisca `false`. Esegui `luajit tests/run.lua`: deve fallire perché `run.lua` non esiste.
- [ ] **Step 5:** Implementa `tests/run.lua`, cioè l'elenco dei file `tests/test_*.lua` tramite `io.popen("ls tests/test_*.lua")`, con esecuzione e conteggio. Il codice di uscita è 1 se un test fallisce. Implementa anche `tests/wow_stubs.lua`. Esegui `luajit tests/run.lua`: stampa `1 passed, 0 failed`.
- [ ] **Step 6:** Scrivi `NOTICE.md`, con fork di RestedXP (CC BY-NC-SA 4.0, link upstream), Sharpie's Gear Judge (MIT, © 2025 Supersharpie, vedi `SGJ/LICENSE`) e la nota "nessun contenuto di SharpiesGearJudge_Talents". Copia spec e piano in `docs/superpowers/`.
- [ ] **Step 7:** Commit `chore: bootstrap fork, notice, test harness` e `git push -u origin main`.

### Task 2: Script di vendoring di Sharpie's

**Files:**
- Create: `tools/vendor_sgj.py`, `tools/sgj_patches/0001-no-minimap.patch`, `tools/sgj_patches/0002-no-slash-commands.patch`, `tools/sgj_patches/0003-pin-mode-and-pvp.patch`, `tools/sgj_files.txt`, `tests/test_vendor.py`
- Generated (committed): `SGJ/**`, `SGJ/sgj.xml`, `SGJ/UPSTREAM`, `SGJ/LICENSE`

**Interfaces:**
- Produces:
  - `python3 -I tools/vendor_sgj.py --ref <commit> [--src <path>]` rigenera `SGJ/` da zero. Se manca `--src`, lo script clona `https://github.com/Supersharpie/SharpiesGearJudge.git` in una directory temporanea.
  - `SGJ/sgj.xml` carica i file nell'ordine di `tools/sgj_files.txt`.
  - Ogni file `.lua` generato inizia con `if RXP_SGJ_DISABLED then return end`. Fanno eccezione i file in `Libs/`, che restano invariati.
- `tools/sgj_files.txt` è l'elenco dei file di `SharpiesGearJudge_Forever.toc` nello stesso ordine, **senza** `WhatsNew.lua` e `AddonPanel.lua`, e con i `Locales/*` inclusi così come sono.

- [ ] **Step 1:** Scrivi `tests/test_vendor.py`, eseguibile con `python3 -I -m unittest tests/test_vendor.py`, su un piccolo albero sorgente finto in una directory temporanea. I test sono:
  - `test_vararg_header_rewritten`: `local addonName, MSC = ...` diventa `local addonName, MSC = "RXPGuides", RXP_SGJ_NS`. `local _, MSC = ...` diventa `local _, MSC = "RXPGuides", RXP_SGJ_NS`.
  - `test_unknown_vararg_form_fails`: una riga con `= ...` in una forma diversa fa terminare lo script con un codice diverso da 0 e un messaggio che riporta file e riga.
  - `test_savedvariables_renamed`: `SGJ_Settings.Mode` diventa `RXP_SGJ_Settings.Mode`. `SharpiesGearJudgeDB = SharpiesGearJudgeDB or {}` diventa `RXP_SGJ_DB = RXP_SGJ_DB or {}`. `MySGJ_SettingsX` resta invariato, perché si sostituisce solo la parola intera.
  - `test_guard_prepended_except_libs`.
  - `test_global_addon_table_not_overwritten`: `_G[addonName] = MSC` (in `Init.lua`) diventa `-- vendor: removed _G[addonName] = MSC`. Senza questa sostituzione `_G.RXPGuides`, l'API pubblica di RestedXP usata in `Talents.lua:1415`, verrebbe sovrascritta.
  - `test_excluded_files_absent`: niente `WhatsNew.lua` e niente `AddonPanel.lua`.
  - `test_patch_failure_aborts`: se una patch non si applica, lo script esce con un codice diverso da 0 e lascia `SGJ/` com'era.
  - `test_upstream_file`: `SGJ/UPSTREAM` contiene `commit=<ref>` e `version=3.3.2-Forever`.
- [ ] **Step 2:** Esegui i test: devono fallire perché `vendor_sgj.py` non esiste.
- [ ] **Step 3:** Implementa `tools/vendor_sgj.py`, in questo ordine:
  1. copia in una directory di staging;
  2. applica le trasformazioni regex;
  3. applica le patch con `git apply --directory=SGJ` nello staging;
  4. genera `sgj.xml` (`<Script file="SGJ\...">` in ordine);
  5. sostituisci `SGJ/` in modo atomico.
  Lo script legge la versione dal campo `## Version` del toc sorgente.
- [ ] **Step 4:** Scrivi le tre patch sui sorgenti reali al commit `f285a2b`:
  - **0001** fa uscire subito `RegisterMinimapIcon` in `Interface.lua` (`return` come prima istruzione).
  - **0002** rimuove le assegnazioni `SLASH_*` e `SlashCmdList[...]` in `Interface.lua` e in `Judge.lua`.
  - **0003** fa in modo che `MSC.GetManualSpec` restituisca sempre `"AUTO"` e `MSC.IsGearingForPvP` restituisca solo `(MSC.TalentBuildRole and MSC.TalentBuildRole.pvp) and true or false`, entrambi in `Helpers.lua`. Imposta poi `HideMinimap = true` e `GearForPvP = false` nei default di `MSC.ApplySettingsDefaults`.
- [ ] **Step 5:** Esegui i test, che devono passare. Poi `python3 -I tools/vendor_sgj.py --ref f285a2b51a2d0a79a58f61ead60af9c2270f76f5` e verifica la sintassi: `for f in $(git ls-files -o SGJ | grep '\.lua$'); do luajit -bl "$f" >/dev/null || echo BAD $f; done` non deve stampare niente.
- [ ] **Step 6:** Commit `feat: vendor Sharpie's Gear Judge engine (f285a2b)`.

### Task 3: Bootstrap e caricamento nel .toc

**Files:**
- Create: `ForeverBuilds/Bootstrap.lua`, `ForeverBuilds/ForeverBuilds.xml`, `tests/test_bootstrap.lua`
- Modify: `RXPGuides.toc`, due righe `-- FORK:`. In un `.toc` i commenti si scrivono `# FORK:`, quindi su quel file si usa `# FORK:`.

**Interfaces:**
- Produces: `Bootstrap.lua` definisce `RXP_SGJ_NS = RXP_SGJ_NS or {}` e la funzione globale `RXP_SGJ_StandaloneEnabled() -> boolean`. La funzione usa `C_AddOns.GetAddOnEnableState("SharpiesGearJudge", UnitName("player"))` se esiste, altrimenti `GetAddOnEnableState(UnitName("player"), "SharpiesGearJudge")`. Un valore maggiore di 0 significa abilitato. Lo script imposta `RXP_SGJ_DISABLED = RXP_SGJ_StandaloneEnabled()`. Se il risultato è `true`, al `PLAYER_LOGIN` stampa una volta: `RestedXP Forever: Sharpie's Gear Judge standalone is enabled; disable it to use the built-in gear engine.`

- [ ] **Step 1:** Scrivi `tests/test_bootstrap.lua` con questi test:
  - `test_disabled_when_standalone_enabled`: lo stub di `C_AddOns.GetAddOnEnableState` restituisce 2, quindi `RXP_SGJ_DISABLED == true`.
  - `test_enabled_when_absent`: lo stub restituisce 0, quindi `false`.
  - `test_legacy_api_arg_order`: senza `C_AddOns`, la funzione globale riceve `(player, addon)`.
  Esegui `luajit tests/run.lua`: i test devono fallire.
- [ ] **Step 2:** Implementa `Bootstrap.lua`. Esegui i test, che devono passare.
- [ ] **Step 3:** Nel `.toc`, accoda a `## SavedVariables:` le voci `RXP_SGJ_Settings, RXP_SGJ_DB`. Dopo la riga `ItemUpgrades.lua [...]` aggiungi:
  - `ForeverBuilds\Bootstrap.lua [AllowLoadGameType camelot]`
  - `SGJ\sgj.xml [AllowLoadGameType camelot]`
  - `ForeverBuilds\ForeverBuilds.xml [AllowLoadGameType camelot]`
  La riga `# FORK:` che spiega il blocco va subito sopra.
- [ ] **Step 4:** Commit `feat: load embedded SGJ engine on Forever`.

### Task 4: Risoluzione talenti (spellID → posizione)

**Files:**
- Create: `ForeverBuilds/TalentResolver.lua`, `tests/test_talent_resolver.lua`

**Interfaces:**
- Produces: modulo `RXP_FB.TalentResolver`, dove `RXP_FB` è la tabella globale del codice nuovo, creata in `Bootstrap.lua` come `RXP_FB = RXP_FB or {}`.
  - `TalentResolver.BuildIndex() -> index`: `index[name] = { tab=int, row=int, col=int, maxRank=int, talentIndex=int }`. Si costruisce da `GetTalentInfo(tab, i)` (name, icon, tier, column, rank, maxRank).
  - `TalentResolver.Resolve(index, spellID) -> pos|nil, name|nil`: il nome viene da `GetSpellInfo(spellID)`.
  - `TalentResolver.TreeName(tab) -> string`: viene da `GetTalentTabInfo(tab)`. Su Classic il nome è il primo valore restituito.

- [ ] **Step 1:** Test con `Stubs.install` (2 tab, 3 talenti):
  - `test_index_by_name`;
  - `test_resolve_known_spell` restituisce `{tab=2,row=1,col=2,maxRank=5,...}`;
  - `test_resolve_unknown_spell_returns_nil`, sia per uno spellID senza nome sia per un nome non presente nell'albero.
  Esegui i test: devono fallire.
- [ ] **Step 2:** Implementa. Esegui i test, che devono passare.
- [ ] **Step 3:** Commit `feat: resolve talent spell IDs to tree positions`.

### Task 5: Catalogo build

**Files:**
- Create: `ForeverBuilds/BuildCatalog.lua`, `tests/test_build_catalog.lua`, `tests/fixtures/buildmatch_druid.lua` (le prime righe DRUID reali di `BuildMatch_Forever.lua`, comprese una riga di fase 0 e una LVLPVP con priorità 51)

**Interfaces:**
- Consumes: `MSC.BuildMatch[CLASS]`, cioè righe `{ stage, role, endgame, priority, { spellID, ranks, ... } }`, e `MSC.PrettyNames[role]`. Se un ruolo manca in `PrettyNames`, l'etichetta è il ruolo stesso.
- Produces: `RXP_FB.BuildCatalog.List(classToken, buildMatch, prettyNames, treeOf) -> builds`. `treeOf(spellID) -> tabIndex|nil` viene da Task 4 e nei test è uno stub. Ogni `build` è `{ id=string, role=string, endgame=string, pvp=bool, priority=int, order=table (la lista piatta originale), points=int, complete=bool, mainTab=int|nil, label=string }`. Il catalogo contiene **solo righe con stage == 1**, nell'ordine originale del file.
  - `id = role .. "|" .. endgame .. "|" .. priority`. Se due righe hanno lo stesso id si aggiunge `"|2"`, `"|3"` …
  - `pvp = endgame:find("PVP") ~= nil`
  - `points` = somma dei gradi
  - `complete = points == 51`
  - `mainTab` = il tab con più punti (in parità vince il primo)
  - `label = prettyName .. " – " .. treeNameOf(mainTab)`, più `" (variant N)"` se un'altra build ha la stessa etichetta, più `" (incomplete: P/51)"` se la build non è completa. `treeNameOf` è un parametro opzionale: senza, l'etichetta usa `"Tree " .. mainTab`.
- `RXP_FB.BuildCatalog.Find(builds, id) -> build|nil`.

- [ ] **Step 1:** Test sulla fixture:
  - `test_only_leveling_stage_rows`: le righe con stage 0 sono escluse.
  - `test_points_and_complete`: la riga cat solo vale 51 ed è completa. Una riga finta da 39 punti produce `complete=false` e un'etichetta che termina con `(incomplete: 39/51)`.
  - `test_pvp_flag_from_endgame`: `FERAL_PVP` dà `true`, `CAT_RAID` dà `false`.
  - `test_duplicate_labels_get_variant_suffix`.
  - `test_ids_unique`.
  - `test_find_by_id`.
  Esegui i test: devono fallire.
- [ ] **Step 2:** Implementa. Esegui i test, che devono passare.
- [ ] **Step 3:** Aggiungi il test di dati `test_all_classes_structurally_valid`. Il test carica il vero `SGJ/Data/BuildMatch_Forever.lua` con stub di `MSC = {IsForever=true}` e verifica per ogni classe e ogni riga di stage 1:
  - la lista ha lunghezza pari;
  - ogni grado è compreso tra 1 e 5;
  - `points <= 51`;
  - la somma cumulativa dei gradi per spellID è `<= 5`.
  Il test stampa l'elenco delle build incomplete per classe, senza farle fallire. Esegui i test, che devono passare.
- [ ] **Step 4:** Commit `feat: build catalog from SGJ BuildMatch`.

### Task 6: Generatore di guide talenti

**Files:**
- Create: `ForeverBuilds/TalentGuideGen.lua`, `tests/test_talent_guide_gen.lua`

**Interfaces:**
- Consumes: `build` (Task 5), `resolve(spellID) -> pos|nil, name|nil` (Task 4, parzialmente applicato all'indice).
- Produces: `RXP_FB.TalentGuideGen.Build(build, resolve) -> text, warnings`.
  - `text` è una guida nel formato RestedXP, con le intestazioni:
    - `#key FOREVER - <build.id>`
    - `#name <build.label>`
    - `#minLevel 10`
    - `#maxLevel <9 + build.points>`
  - Ogni passo è una coppia di righe: `level -- <name> (Rank r)` e poi `    .talent tab,row,col,r`.
  - Un talento non risolto produce solo la riga `level -- UNRESOLVED <name or spellID> (Rank r)`, senza `.talent`.
  - `warnings` è una lista di stringhe del tipo `"UNRESOLVED <spellID> at level <L>"`.
  - Il grado `r` è il grado cumulativo di quel talento.

- [ ] **Step 1:** Test con un `resolve` stub:
  - `test_guide_levels_start_at_10`: il primo passo è il livello 10, e il numero di righe `level` è uguale a `points`.
  - `test_rank_accumulates_across_blocks`: con `{17056,3, 16934,1, 17056,1}` i passi sono 17056 r1, r2, r3, poi 16934 r1, poi 17056 r4.
  - `test_unresolved_keeps_alignment`: lo spellID nel mezzo non viene risolto. Il passo resta, senza `.talent`, e i livelli successivi non si spostano. `warnings` ha una voce con il livello giusto.
  - `test_header_tags`: `#key`, `#name`, `#minLevel 10`, `#maxLevel`.
  - `test_parses_with_rxp_parser`: carica `Talents.lua` di RestedXP con gli stub (`addon.talents.functions.talent` reale) e verifica che `addon.talents:ParseGuide(text)` restituisca una guida con `#steps == points`. Se caricare `Talents.lua` sotto stub è troppo costoso, lo si sostituisce con un controllo regex sul formato di ogni riga, e la scelta va scritta nel commit.
  Esegui i test: devono fallire.
- [ ] **Step 2:** Implementa. Esegui i test, che devono passare.
- [ ] **Step 3:** Commit `feat: generate per-level talent guides from builds`.

### Task 7: Stato build, collegamento al motore e alle guide

**Files:**
- Create: `ForeverBuilds/BuildState.lua`, `tests/test_build_state.lua`

**Interfaces:**
- Consumes: Task 4, 5 e 6. Dal motore usa `RXP_SGJ_NS.SetTalentBuildRole(leveling, endgame, pvp)` (con tutti `nil` cancella la scelta), `RXP_SGJ_NS.GetActiveSpecGroup() -> 1|2` e `RXP_SGJ_NS.BuildMatch`, `RXP_SGJ_NS.PrettyNames`. Da RestedXP usa `addon.talents.RegisterGuide(text)` e `addon.talents:UpdateSelectedGuide(key)`.
- Produces: `RXP_FB.BuildState` con:
  - `Get(group) -> id|"AUTO"`. Se l'id non esiste nel catalogo restituisce `"AUTO"` e ripulisce il valore salvato.
  - `Set(group, id)`: salva e chiama `Apply()`.
  - `Builds() -> builds`: catalogo della classe del giocatore, memorizzato in cache.
  - `RoleFor(group) -> {leveling=,endgame=,pvp=}|nil`.
  - `Apply()`: per il gruppo attivo chiama `SetTalentBuildRole`. Se la build non è `"AUTO"`, genera e registra la guida (una sola volta per id) e la seleziona. Infine richiama `RXP_FB.TalentWarning.Update(build, warnings)` (Task 9).
  - `Init()`: definisce `RXP_SGJ_NS.GetTalentBuildRoleForGroup = function(g) return RXP_FB.BuildState.RoleFor(g) end` e registra `PLAYER_LOGIN` (dopo `ForceInit` del motore), `ACTIVE_TALENT_GROUP_CHANGED` e `PLAYER_LEVEL_UP`, che chiamano `Apply()`.
  - Se `RXP_SGJ_DISABLED` è vero, `Init()` non fa nulla.

- [ ] **Step 1:** Test con stub di `RXPCData`, `RXP_SGJ_NS` (con `SetTalentBuildRole` spia) e `addon.talents` spia:
  - `test_default_is_auto`.
  - `test_set_persists_per_group`.
  - `test_unknown_build_falls_back_to_auto`.
  - `test_apply_auto_clears_role`: la spia riceve `(nil, nil, nil)` e nessuna guida viene registrata.
  - `test_apply_build_sets_role_and_selects_guide`: la spia riceve `("Leveling","CAT_RAID",false)`. `UpdateSelectedGuide` riceve `"FOREVER - Leveling|CAT_RAID|10"`.
  - `test_other_group_role_for_tooltip`: con il gruppo 2 impostato su bear, `RoleFor(2).leveling == "Leveling_Bear"`.
  - `test_guide_registered_once`.
  Esegui i test: devono fallire.
- [ ] **Step 2:** Implementa. Esegui i test, che devono passare.
- [ ] **Step 3:** Commit `feat: per-spec build state driving engine and talent guide`.

### Task 8: Opzioni nel pannello RestedXP

**Files:**
- Create: `ForeverBuilds/Options.lua`, `tests/test_options.lua`
- Modify: `SettingsPanel.lua`, una riga `-- FORK:` subito prima di `AceConfig:RegisterOptionsTable(addon.title, optionsTable)`, alla riga 3576 nella v4.11.34: `if RXP_FB and RXP_FB.Options then RXP_FB.Options.Inject(optionsTable) end -- FORK: Forever Build options`.

**Interfaces:**
- Consumes: `RXP_FB.BuildState` (Task 7) e `RXP_SGJ_Settings`.
- Produces: `RXP_FB.Options.Inject(optionsTable)` aggiunge `optionsTable.args.foreverBuild`, un gruppo AceConfig dal nome `"Forever Build"`. Non aggiunge nulla se `addon.game ~= "FOREVER"` o se `RXP_SGJ_DISABLED`. Il gruppo contiene:
  - `activeBuild` (select): valori `{AUTO="Automatic (gear only)", [id]=label...}`. Viene scritto con `BuildState.Set(activeGroup, v)`.
  - `otherBuild` (select): uguale, per l'altro gruppo. È nascosto se il personaggio non ha la doppia specializzazione (`GetNumTalentGroups() < 2`).
  - Un toggle per ogni opzione di **visualizzazione** che il pannello originale di Sharpie's espone tramite `CreateCheck` in `Interface.lua`. L'implementatore elenca le chiavi nel commit. Tra queste ci sono almeno `ShowBagArrows`, `FastBagArrows`, `ShowLootArrows`, `ShowLootToast`, `ShowOtherSpec`, e `HideTooltips` mostrato invertito come "Show gear verdict in tooltips". `get` e `set` leggono e scrivono `RXP_SGJ_Settings[key]`. Dopo la scrittura viene chiamata `RXP_SGJ_NS:BumpScoringRevision()` se esiste.
  - **Non** si espongono `Mode`, `GearForPvP` né `HideMinimap`. Le opzioni di Sharpie's che non riguardano la visualizzazione, come buff da raid, fase dei contenuti e gemme, restano ai default di Sharpie's e non vengono esposte.

- [ ] **Step 1:** Test con un `optionsTable` vuoto e gli stub:
  - `test_injects_group_on_forever`.
  - `test_no_group_when_disabled`.
  - `test_select_values_include_auto_and_builds`.
  - `test_toggle_writes_sgj_setting`.
  - `test_hide_tooltips_inverted`.
  - `test_mode_and_pvp_not_exposed`.
  Esegui i test: devono fallire.
- [ ] **Step 2:** Implementa e aggiungi la riga `-- FORK:`. Esegui i test, che devono passare.
- [ ] **Step 3:** Commit `feat: Forever Build options in RestedXP settings`.

### Task 9: Guide talenti di RestedXP su Forever e avviso nel pannello talenti

**Files:**
- Create: `ForeverBuilds/TalentWarning.lua`, `tests/test_talent_warning.lua`
- Modify: `Talents.lua`, con righe `-- FORK:`. Il ramo `elseif addon.game == "CLASSIC" then` per la posizione del pulsante (riga 264 nella v4.11.34) diventa `elseif addon.game == "CLASSIC" or addon.game == "FOREVER" then`. Vanno controllati anche gli altri confronti `addon.game == "CLASSIC"` in `Talents.lua` (righe 144 e 2459/2486 di `RXPGuides.lua` sono fuori scopo): si estende solo dove serve a mostrare ed evidenziare la guida, e la scelta per ogni riga si documenta nel commit.

**Interfaces:**
- Produces: `RXP_FB.TalentWarning.Update(build|nil, warnings)` crea, se non esiste ancora, un FontString ancorato in cima a `PlayerTalentFrame`, che si carica su richiesta: la creazione aspetta `ADDON_LOADED` di `Blizzard_TalentUI`. Testi:
  - build `"AUTO"` o `nil`: `"Forever Build: choose a build in RestedXP settings for a talent guide."`;
  - build incompleta: `"Incomplete talent order (P/51): some levels may not match the build."`;
  - con `warnings`, si aggiunge `"N talents could not be matched."`;
  - build completa senza warnings: nascosto.

- [ ] **Step 1:** Test con stub di `CreateFrame` e FontString: `test_auto_message`, `test_incomplete_message`, `test_unresolved_appended`, `test_hidden_when_complete`, `test_deferred_until_talent_ui_loaded`. Esegui i test: devono fallire.
- [ ] **Step 2:** Implementa e applica le righe `-- FORK:` a `Talents.lua`. Esegui i test, che devono passare. Verifica la sintassi di `Talents.lua` con `luajit -bl Talents.lua >/dev/null`.
- [ ] **Step 3:** Commit `feat: talent guide UI on Forever with incomplete/unresolved warning`.

### Task 10: Diagnostica, documentazione, installazione

**Files:**
- Create: `ForeverBuilds/Diagnostics.lua`, `docs/UPDATING.md`, `README-FORK.md`
- Modify: `ForeverBuilds/ForeverBuilds.xml`, che deve caricare nell'ordine `TalentResolver`, `BuildCatalog`, `TalentGuideGen`, `TalentWarning`, `BuildState`, `Options`, `Diagnostics`, più una riga finale che chiama `RXP_FB.BuildState.Init()`.

**Interfaces:**
- Produces:
  - comando `/rxpfb`: stampa la build attiva per entrambi i gruppi, l'esito di `MSC.MatchTalentBuild` e la versione del motore (`RXP_SGJ_NS.API.GetVersion()`);
  - `/rxpfb check`: per ogni build della classe del personaggio genera la guida e stampa `OK <label>` oppure `<label>: N unresolved (<spellIDs>)`.
  Per le altre classi la verifica completa si fa solo entrando con un personaggio di quella classe, perché l'albero talenti è leggibile solo per la propria. Lo dice la documentazione.

- [ ] **Step 1:** Implementa `Diagnostics.lua`. Esegui l'intera suite: `luajit tests/run.lua` e `python3 -I -m unittest tests/test_vendor.py` devono passare tutti.
- [ ] **Step 2:** Scrivi `docs/UPDATING.md` con queste procedure:
  - aggiornare RestedXP: `git fetch upstream-rxp --tags && git merge vX.Y.Z`, risolvere i conflitti, poi `grep -rn "FORK:"` per verificare che tutte le righe ci siano ancora;
  - aggiornare Sharpie's: `python3 -I tools/vendor_sgj.py --ref <commit>`; se una patch non si applica va riscritta sul nuovo sorgente; poi i test.
  Scrivi `README-FORK.md` con lo scopo e la checklist in gioco del §8 dello spec, punti 1-8 compreso il 4b, e i comandi `/rxpfb`.
- [ ] **Step 3:** Installazione, previa conferma dell'utente:
  1. sposta l'attuale `_forever_/Interface/AddOns/RXPGuides` in `RXPGuides.bak-2026-11-11`, **fuori** dalla cartella `AddOns` (in `_forever_/Interface/`), così il gioco non lo carica;
  2. `git clone git@github.com:ManoloZocco/RXPGuides-Forever.git` nella cartella `AddOns` con nome `RXPGuides`;
  3. verifica che `RXPGuides/RXPGuides.toc` esista.
  Ricorda all'utente di disattivare gli aggiornamenti automatici di RestedXP nell'app CurseForge, se la usa.
- [ ] **Step 4:** Commit `docs: updating guide, fork readme, diagnostics` e push.
- [ ] **Step 5:** Consegna all'utente la checklist in gioco e chiedi l'esito di `/reload` e `/rxpfb check` sul druido.
