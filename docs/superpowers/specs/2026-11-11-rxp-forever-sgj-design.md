# RestedXP personale per WoW Forever con il motore di Sharpie's Gear Judge — Design

Data: 2026-11-11 · Stato: bozza per approvazione

## 1. Scopo e motivazione

L'utente gioca a **WoW Forever** (client 1.60.1, Interface `16001`, game type `camelot`, `addon.game == "FOREVER"` in RestedXP). Livella **soprattutto in solo**, con un druido, e in futuro potrebbe fare dungeon con la gilda. Usa **RestedXP (RXPGuides)** per le guide di leveling e vuoi restare su **un unico addon**.

Vuole che una sola scelta, **la build** (per esempio "Druido – Feral gatto, solo"), adatti tutto:
1. **Talenti:** quale talento prendere a ogni livello, secondo la build.
2. **Equipaggiamento:** se un oggetto è un upgrade, valutato dal **motore completo di Sharpie's Gear Judge** (pesi per livello, talenti, cap, confronto con quanto indossato).

Oggi RestedXP su Forever non fa né l'uno né l'altro. Item Upgrades è disattivato da un controllo di gioco (una patch locale di una riga ora lo accende), e le guide talenti sono solo per Classic. Il druido su Forever ha però talenti rielaborati, quindi quelle guide qui non vanno bene.

## 2. Obiettivi

- O1. Un **fork personale di RestedXP** in un **repo GitHub privato** sull'account `ManoloZocco`, installabile in `_forever_/Interface/AddOns/RXPGuides`.
- O2. **Tutte le classi e tutti i profili di leveling** di Sharpie's su Forever: solo e dungeon, compresi orso, tank e healer.
- O3. **Scelta della build** nelle impostazioni di RestedXP, unico punto di controllo.
- O4. **Guida talenti per livello** su Forever, generata dall'ordine dei punti della build scelta. Viene mostrata con un **riquadro dei prossimi talenti** accanto alla finestra talenti, un **messaggio in chat** a ogni livello e l'**evidenziazione del nodo** da prendere nella finestra talenti moderna (best effort). Vedi §7.4, revisione 2026-11-11.
- O5. **Valutazione oggetti con il motore di Sharpie's**, incorporato nel fork, che segue la build scelta.
- O6. **Visualizzazione oggetti come in Sharpie's, completa:**
  - verdetto nel tooltip (con dettaglio tenendo premuto Shift);
  - frecce sugli upgrade nelle borse, compresi gli hook per Bagnon, Baganator e gli altri addon borse supportati;
  - avviso quando si raccoglie un upgrade (LootToast);
  - **tutti** gli altri segnalini di Sharpie's sulle finestre di gioco: ricompense quest (compreso l'hook a DialogueUI), mercanti, tiri loot di gruppo, finestra professioni, scheda personaggio ("Better item in bags!", incantamenti mancanti).
  - Le relative opzioni on/off vanno esposte nel pannello di RestedXP.
- O7. **Aggiornabile:** si devono poter importare le nuove versioni di RestedXP e di Sharpie's con una procedura documentata.

## 3. Non-obiettivi

- Versioni del gioco diverse da Forever: Classic Era, TBC, retail. Il fork può romperle, non vanno mantenute.
- Pubblicazione su CurseForge, Wago o qualsiasi distribuzione pubblica.
- Riscrivere il motore di Sharpie's dentro il codice di RestedXP: si incorpora, non si riscrive.
- Funzioni di Sharpie's non legate a leveling ed equipaggiamento personale: richieste di punteggio al raid (`RequestScores`), plugin Laboratory/Roster/Roadmap/XP/CombatLab, profili PvP/raid a 60 come scelta principale.
- Localizzazioni oltre all'inglese. Il client dell'utente è `enUS`, e le altre lingue possono restare come sono, senza essere verificate.

## 4. Anti-obiettivi (fallimento anche se "funziona")

- **Due punteggi diversi** nello stesso tooltip (la riga "EP" di RestedXP accanto al verdetto di Sharpie's).
- **Due posti per scegliere la build**: la build deve stare solo nelle impostazioni di RestedXP.
- **Elementi di interfaccia separati** di Sharpie's: pulsante minimappa, finestra opzioni propria, popup "What's New".
- Guida talenti che suggerisce **talenti inesistenti** su Forever, o che non corrisponde all'ordine della build **senza dirlo**. Una build con ordine incompleto è accettata solo se segnalata chiaramente (vedi C2).
- Fork che **non si riesce più ad aggiornare** perché le modifiche sono sparse ovunque nel codice di RestedXP.
- Uso di contenuti senza licenza (vedi §6).
- Errori Lua all'avvio, o impatto evidente sulle prestazioni quando si aprono le borse o si passa il mouse sugli oggetti.

## 5. Vincoli

- **Licenze:**
  - RestedXP è **CC BY-NC-SA 4.0**: non commerciale, con attribuzione, e il fork resta sotto la stessa licenza.
  - Sharpie's Gear Judge (repo principale `Supersharpie/SharpiesGearJudge`) è **MIT**: va conservata la nota di copyright.
  - Il repo deve contenere un file `NOTICE`, o una sezione del README, con le due attribuzioni e i testi delle licenze.
- **Plugin `SharpiesGearJudge_Talents`: nessuna licenza, quindi tutti i diritti riservati. Non si usa niente di quel repo.** L'ordine dei talenti viene **solo** da `Data/BuildMatch_Forever.lua` del repo principale (MIT), che è generato a partire da quel plugin ma è distribuito sotto MIT.
- **GitHub:** non si può rendere privato il fork di un repo pubblico. Si crea quindi un **repo privato nuovo**, con il codice di RestedXP e i remote `upstream-rxp` (`RestedXP/RXPGuides`) e la fonte di Sharpie's (`Supersharpie/SharpiesGearJudge`).
- **Client:** Forever 1.60.1, Lua 5.1 dell'ambiente WoW, API stile Classic (`GetTalentInfo`, `GetTalentTabInfo`, `OnTooltipSetItem`).
- **Coesistenza:** l'addon **Sharpie's Gear Judge** standalone **non** va installato insieme al fork, perché registra gli stessi globali (`SharpiesGearJudgeAPI`, `MSC_*`, SavedVariables `SGJ_Settings`, `SharpiesGearJudgeDB`). Il fork deve accorgersi della sua presenza e avvisare l'utente invece di caricare due motori.
- **Base di partenza:**
  - RestedXP **v4.11.34**, già installato. Contiene la patch locale in `ItemUpgrades.lua:6`, che aggiunge `"FOREVER"` al controllo di gioco. Il fork la include o la rende superflua.
  - Sharpie's Gear Judge **v3.3.2-Forever**, al commit corrente di `main`.

## 6. Decisioni prese (dall'utente)

- D1. Fork personale di RestedXP, **repo privato**.
- D2. **Tutte le classi.**
- D3. **Tutti i profili**, solo e dungeon.
- D4. **La build scelta governa tutto**: talenti e valutazione oggetti.
- D5. **Motore di Sharpie's incorporato** nel fork, non riscritto, non portato soltanto come dati.
- D6. **Visualizzazione di Sharpie's** per gli oggetti (tooltip, frecce borse, avviso upgrade). Nessuna riga EP di RestedXP. Nessuna UI separata di Sharpie's. Tutte le impostazioni dentro RestedXP.

## 7. Architettura (proposta di Claude, da validare nel piano)

### 7.1 Struttura del repo
- Radice = addon `RXPGuides` (il fork di RestedXP), così `git pull` sul clone dentro `AddOns` aggiorna l'addon.
- `SGJ/`: copia vendorizzata dei file di Sharpie's necessari, con la stessa struttura di cartelle dell'originale, più il file `SGJ/UPSTREAM` con commit e versione di origine e la sua `LICENSE`.
- `ForeverBuilds/`: codice nuovo del fork (integrazione, guide talenti generate, impostazioni). **Tutto il codice nuovo sta qui.** Le modifiche ai file originali di RestedXP devono essere minime e marcate con un commento `-- FORK:`.
- `tools/`: script per aggiornare `SGJ/` da una nuova versione di Sharpie's (eventuali generatori, vedi 7.4).
- `docs/`: questo documento, la procedura di aggiornamento e `NOTICE`.

### 7.2 Motore di Sharpie's incorporato
- Si caricano dal `.toc` del fork, solo su Forever (`[AllowLoadGameType camelot]`), i file del motore nell'ordine del `SharpiesGearJudge_Forever.toc` originale: Init, CacheManager, Data/*_Forever, Parsers, Helpers, RaidBuffs, Dynamic_Engine, Evaluator, Classes/Forever/* con Curves e GearPoints, Judge, SGJ_API.
- Il namespace privato `MSC` (il secondo valore di `...` nei file di Sharpie's) va fornito come tabella separata da quella di RestedXP, per non mescolare i due namespace. Il modo concreto è lasciato al builder: wrapper, file di bootstrap o sostituzione meccanica tramite script in `tools/`.
- **UI di Sharpie's da escludere o neutralizzare:** pulsante minimappa (LibDBIcon), finestra opzioni, `WhatsNew`, `AddonPanel`, comandi slash. Da **tenere**: tutto ciò che elenca O6 (tooltip, borse, LootToast e tutti i segnalini sulle finestre di gioco).
  - **Rischio noto:** `Interface.lua` (circa 4.500 righe) contiene sia l'interfaccia delle opzioni sia, probabilmente, le frecce nelle borse e parte dell'inizializzazione, e `SGJ_Settings` è letto in molti file. Il builder deve mappare cosa serve davvero. Se separarlo è troppo costoso, è accettabile caricare `Interface.lua` e **nascondere o disattivare** le parti visibili non volute, a patto che l'utente non le veda.
- **Impostazioni:**
  - Le opzioni di Sharpie's necessarie (attivazione frecce, attivazione avviso upgrade, profilo) vengono **esposte nel pannello impostazioni di RestedXP** (AceConfig, `SettingsPanel.lua`) e scritte nella tabella impostazioni che il motore si aspetta.
  - Le SavedVariables del motore diventano dichiarate dal fork, rinominate se serve a evitare conflitti con l'addon standalone (scelta del builder).
- **Item Upgrades di RestedXP:** su Forever va **disattivato**. Niente riga EP e niente hook del tooltip di RestedXP, mentre la valutazione all'asta di RestedXP (AH) resta fuori, salvo che ricevere i punteggi dal motore di Sharpie's sia banale.

### 7.3 Scelta della build
- Una nuova sezione **"Forever Build"** nelle impostazioni di RestedXP, con un menu a tendina delle build disponibili per la classe del personaggio. I nomi sono quelli di Sharpie's (`PrettyNames` delle classi, per esempio "Feral Cat: Solo Leveling", "Bear: Dungeon Leveling"), ricavati dalle voci di leveling di `MSC.BuildMatch[CLASSE]`.
- Opzione **"Automatica"**: il motore riconosce la build dai talenti già spesi (`MSC.MatchTalentBuild`, comportamento predefinito di Sharpie's). Le altre opzioni fissano la build.
- Collegamento al motore: impostare `MSC.TalentBuildRole`, che `MSC.GetBuildRole()` (`Dynamic_Engine.lua:610`) restituisce per primo, con la struttura che ritorna da `MSC.MatchTalentBuild`. Va verificato nel codice che è il meccanismo giusto e completo.
- La scelta viene salvata **per personaggio**.

### 7.4 Guida talenti per livello (rivista il 2026-11-11 dopo una scoperta in esecuzione)

**Scoperta:** il client di Forever **non ha** l'API talenti Classic (`GetTalentInfo`, `GetNumTalents` e la forma tab/index di `GetTalentTabInfo` sono stati rimossi). La finestra talenti è quella moderna a nodi (`Blizzard_PlayerSpells`, sistema `C_Traits`), con i tre alberi Classic come gruppi di nodi, nell'ordine Classic. Fonte: `SGJ/Dynamic_Engine.lua`, righe 183-200. Il sistema guide talenti di RestedXP (`Talents.lua`, `PlayerTalentFrame`) quindi **non può funzionare su Forever** e non viene usato né modificato.

**Decisione dell'utente:** lista più evidenziazione.

- **Fonte dell'ordine:** `MSC.BuildMatch[CLASSE]` (righe di stage 1, vedi C1). Si prende un punto per livello a partire dal 10, e il grado di un talento prosegue tra blocchi diversi della lista.
- **Risoluzione dei talenti:** in gioco si usa `RXP_SGJ_NS.ForEachTraitTalent(fn, group)` del motore, che restituisce `name, rank, tab, node, spellID` per ogni nodo. L'abbinamento si fa per spellID, con un fallback sul nome (`C_Spell.GetSpellName`). Si ricavano nodo, albero, grado massimo e grado attuale.
- **Riquadro "prossimi talenti":** si aggancia accanto alla finestra talenti quando è aperta. Mostra il nome della build, i passi già disponibili (livello ≤ livello del personaggio, non ancora presi) e i 3 passi successivi, ciascuno come "Lv N: Talento (grado r/max) – Albero". Mostra anche gli avvisi: "AUTO, nessuna guida", ordine incompleto (C2), talenti non abbinati.
- **Messaggio in chat:** si stampa a ogni salita di livello e al login quando ci sono punti disponibili non spesi, con il prossimo talento da prendere.
- **Evidenziazione (best effort):** a finestra aperta, al nodo del prossimo passo disponibile si aggiunge un bordo luminoso. Il pulsante del nodo si trova tramite `GetTalentButtonByNodeID` sul frame talenti moderno (`PlayerSpellsFrame.TalentsFrame`, con alternativa `ClassTalentFrame.TalentsTab`). Se il frame o il metodo non esistono, niente evidenziazione e nessun errore. Il comando di diagnostica dice se l'evidenziazione è disponibile.
- Si aggiorna su: cambio build, `PLAYER_LEVEL_UP`, `PLAYER_TALENT_UPDATE`, `CHARACTER_POINTS_CHANGED`, `TRAIT_CONFIG_UPDATED` (registrato con `pcall`) e `ACTIVE_TALENT_GROUP_CHANGED`.
- Il tutto segue il gruppo di specializzazione attivo.

### 7.5 Aggiornamenti
- **RestedXP:** merge o rebase da `upstream-rxp`. Le modifiche ai file di RestedXP sono poche e marcate `-- FORK:`, così i conflitti restano contenuti.
- **Sharpie's:** uno script in `tools/` riallinea `SGJ/` a un nuovo commit, riapplica le trasformazioni meccaniche (namespace, esclusioni UI) e aggiorna `SGJ/UPSTREAM`.
- Procedura scritta in `docs/UPDATING.md`.

## 7.6 Scelte di Claude dopo la revisione (sostituiscono le parti di 7.3/7.4 in conflitto)

- **C1 – Cosa è una "build":** **una riga** di `MSC.BuildMatch[CLASSE]` con fase leveling = 1, comprese le varianti dungeon, leveling-PvP (priorità 51) e arma/stile (111/131). Le righe di fase 0 (build a 60: raid, farm, PvP) sono escluse.
  - **Etichetta generata a runtime**, nel formato `<nome del ruolo da PrettyNames/ROLE_NAMES> – <albero principale>`. L'albero principale è quello con più punti nella riga, risolto in gioco con `GetTalentTabInfo`. Le righe dello stesso ruolo che restano uguali vengono distinte con un suffisso numerico ("variante 2").
  - **Non si usano** gli ID nei commenti (`HUNTER_MM_SOLO` ecc.) come etichette.
  - Una build si traduce in `MSC.TalentBuildRole = { leveling = <ruolo>, endgame = <profilo 60>, pvp = <true se profilo 60 PvP> }`, più l'ordine dei talenti della riga.
- **C2 – Ordini talenti incompleti** (meno di 51 punti; riguarda tutto il ladro e alcune righe di guerriero, sciamano e paladino). **Decisione dell'utente:** si tengono tutte, con la guida, e si segnalano.
  - **Scelta di Claude sul come:** la guida assegna i punti disponibili in ordine dal livello 10.
  - Il menu mostra "(incomplete: N/51)" accanto al nome.
  - Il pannello talenti mostra un avviso permanente: "Ordine incompleto: alcuni livelli potrebbero non corrispondere alla build".
  - Se un passo non si può applicare, per esempio perché richiede un tier non ancora sbloccato, viene evidenziato come tale e non si salta in silenzio.
- **C3 – Profilo proprio di Sharpie's** ("Mode"/`ManualSpec`, "Gear for PvP"): **nascosti e bloccati**. Mode = AUTO, così decide `TalentBuildRole`. La PvP è determinata solo dal flag della build. Non c'è un secondo punto di scelta.
- **C4 – Modalità "Automatica":** vale **solo per l'equipaggiamento** (`MatchTalentBuild` come in Sharpie's). Non mostra guida talenti, e il pannello talenti invita a scegliere una build. Nessun nuovo componente di abbinamento.
- **C5 – Salvataggio:** la build si salva **per personaggio e per gruppo di specializzazione**. `MSC.GetTalentBuildRoleForGroup(group)` restituisce la build dell'altro gruppo, così la riga "altra spec" del tooltip (`ShowOtherSpec`) resta corretta. La guida talenti segue il gruppo attivo.

## 8. Verifica

- **Fuori dal gioco:** caricamento sintattico di tutti i file Lua (per esempio `luac -p` o `luacheck` con i globali WoW), test unitari per la conversione dell'ordine talenti e per la logica di selezione build, eseguibili con un interprete Lua 5.1 e stub delle API WoW.
- **In gioco, eseguita dall'utente con una checklist nel README:**
  1. `/reload` senza errori Lua, con e senza build scelta.
  2. Tooltip di un oggetto: c'è solo il verdetto di Sharpie's, non la riga EP.
  3. Le frecce nelle borse compaiono sugli upgrade.
  4. All'arrivo di un upgrade da loot o quest compare l'avviso.
  4b. I segnalini compaiono su ricompense quest, mercante, tiro loot, professioni e scheda personaggio.
  5. Cambiando build cambiano subito sia il verdetto sia la guida talenti.
  6. Con la finestra talenti aperta compare il riquadro dei prossimi talenti, giusto per livello e build, e il nodo da prendere è evidenziato (se `/rxpfb` dice che l'evidenziazione è disponibile). A ogni livello arriva il messaggio in chat.
  7. Nessun pulsante minimappa o finestra di Sharpie's.
  8. Con l'addon Sharpie's standalone installato compare un avviso chiaro.
- Il personaggio di prova è il druido dell'utente. Le altre classi si verificano almeno sul piano dei dati: ogni build ha i talenti abbinati senza avvisi, controllato con un comando di diagnostica in gioco.

## 9. Lasciato al builder

- Come isolare il namespace `MSC` e caricare i file di Sharpie's (wrapper, bootstrap o trasformazione con script).
- Quanto di `Interface.lua` e `Helpers.lua` serve, e come neutralizzare il resto.
- Nomi delle SavedVariables e struttura delle impostazioni.
- Formato e posizione dei test, scelta di `luacheck` o altro.
- Nomi esatti delle voci nel pannello impostazioni (in inglese, come il resto di RestedXP).
