if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local Priest = {}
Priest.Name = "PRIEST"

-- =============================================================
-- WOW FOREVER STAT WEIGHTS (Beta Baseline)
-- =============================================================
Priest.Weights = {
    -- Fallback before a spec is known (healer). Spell Power 0: MSC.GetItemScore already scores an item's
    -- Spell Power at the Healing weight, so 20 here counted it twice.
    -- The level-60 profiles (study/priest2, 2026-10-03; NOTES.md there has the numbers). Spell Power / Healing sit at
    -- 2.0; Hit and Crit per 1%. Each was worked out with its build's own talents, so ApplyScalers' talent hooks skip them.
    -- Shadow: Raid comes from the wowsims Forever sim (Shadow 538 DPS against Smite's 315-375; re-run 2026-10-13 with
    -- Twin Disciplines on Mind Flay and Shadow Word: Death and Shadowform's crit bonus on Shadow Word: Death, the
    -- forever-bugs #322/#328 fixes). Spirit and Mp5 come out at almost nothing there (the fight never runs a Shadow
    -- priest dry); Intellect is its crit and a little mana.
    ["SHADOW_RAID"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_SHADOW_DAMAGE_SHORT"]=2.0, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=21.1, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=23.0, ["ITEM_MOD_INTELLECT_SHORT"]=0.46, ["ITEM_MOD_STAMINA_SHORT"]=0.1 },
    -- The healer profiles come from our healing model (the sim can't heal): a raid fight's healing done with the mana you
    -- have, casting lower ranks where they save mana. Holy: Raid (Spiritual Guidance and Prayer of Mending) leans on Spirit
    -- and Mp5; its crit came out at ~2.5 in the model, which misses Inspiration and Holy's crit talents, so it is set at 7.
    -- Spell Power is the damage value only: an item's Spell Power also heals, and MSC.GetItemScore adds that at the
    -- Healing weight, so a raid healer's Spell Power weight is 0 (it was 2.0, which counted Spell Power twice).
    ["HOLY_RAID"] = { ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"]=2.0, ["ITEM_MOD_SPELL_POWER_SHORT"]=0.0, ["ITEM_MOD_INTELLECT_SHORT"]=2.34, ["ITEM_MOD_SPIRIT_SHORT"]=2.73, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=3.16, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=7.0, ["ITEM_MOD_STAMINA_SHORT"]=0.5 },
    -- Discipline: Raid (Penance, Divine Aegis and Power Infusion, 32/19): crits shield through Divine Aegis, so Crit leads.
    -- Client 70291 cut Penance (spell power coefficient .285 -> .19, higher mana costs): the mana stats count a little
    -- more (study/priest2/penance_70291.js).
    ["DISC_RAID"] = { ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"]=2.0, ["ITEM_MOD_SPELL_POWER_SHORT"]=0.0, ["ITEM_MOD_INTELLECT_SHORT"]=2.79, ["ITEM_MOD_SPIRIT_SHORT"]=2.4, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=3.49, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=14.7, ["ITEM_MOD_STAMINA_SHORT"]=0.5 },
    -- SHADOW_FARM: from the farm model (SimStudio models/shared/farm_profiles.py, data/farm_weights.json: the PRIEST_SHADOW_FARM build's
    -- talents at the main farm spot, mobs 3 levels below you, the farm gear set), 2026-10-25, re-run 2026-11-01.
    -- Tempered (user): Intellect / Spirit / Mp5 / Stamina at most 3x Spell Power, Stamina at least 1x, Hit / Crit at most 25.
    ["SHADOW_FARM"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_SHADOW_DAMAGE_SHORT"]=2.0, ["ITEM_MOD_STAMINA_SHORT"]=2.0, ["ITEM_MOD_INTELLECT_SHORT"]=0.67, ["ITEM_MOD_SPIRIT_SHORT"]=2.91, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=1.46, ["ITEM_MOD_HEALTH_REGENERATION_SHORT"]=0.05, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=5.6, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=16.7 },

    -- Hybrid profiles (not modelled).
}
-- Old names, kept so a saved profile choice still works.
Priest.Weights["SHADOW_PVE"] = Priest.Weights["SHADOW_RAID"]
Priest.Weights["HOLY_DEEP"] = Priest.Weights["HOLY_RAID"]
Priest.Weights["DISC_PI_SUPPORT"] = Priest.Weights["DISC_RAID"]
-- PvP profiles: copies of the PvE profile each build plays like; the PvP model (Helpers 5.10) adds
-- Stamina, armor and burst on top and keeps hit at the player-vs-player caps.
Priest.Weights["SHADOW_PVP"] = MSC.ForeverPvPFrom(Priest.Weights["SHADOW_RAID"])
Priest.Weights["DISC_PVP"] = MSC.ForeverPvPFrom(Priest.Weights["DISC_RAID"])
-- The study-built level-60 profiles (talents already in): ApplyScalers' talent hooks skip these.
local SIM_PROFILES = { SHADOW_FARM = true, SHADOW_RAID = true, HOLY_RAID = true, DISC_RAID = true, SHADOW_PVE = true, HOLY_DEEP = true, DISC_PI_SUPPORT = true, SHADOW_PVP = true, DISC_PVP = true }
-- With Gear for PvP on, auto-detect shows the PvP profile in place of the raid one
-- (same weights plus the PvP model; MSC:ApplyDynamicAdjustments).
Priest.PvPCounterpart = { SHADOW_RAID = "SHADOW_PVP", SHADOW_PVE = "SHADOW_PVP", DISC_RAID = "DISC_PVP", DISC_PI_SUPPORT = "DISC_PVP" }

-- =============================================================
-- LEVELING WEIGHTS
-- =============================================================
-- Filled at load from Classes/Forever/Curves/Priest_Curves.lua (generated from
-- the study; don't edit it by hand) by Curves_Attach.lua: one row per role and level band,
-- blended by level in MSC:GetLevelingRow. Roles:
--   Leveling                Shadow: Solo Leveling (wand, then Mind Flay and Shadowform; the default)
--   Leveling_ShadowDungeon  Shadow: Dungeon Leveling
--   Leveling_Healer         Healer: Leveling (the Holy and Discipline raid builds)
--   Leveling_HealerDungeon  Healer: Dungeon Leveling
--   Leveling_Smite          Discipline / Holy: Solo Leveling (Shadow Word: Pain, Mind Blast and the wand: Smite never wins)
Priest.LevelingWeights = {}

-- =============================================================
-- DISPLAY NAMES (match the Talents plugin's builds; translated in Locales/*.lua)
-- =============================================================
local L = MSC.L
local function Band(label, lo, hi) return L[label] .. " (" .. lo .. "-" .. hi .. ")" end
Priest.PrettyNames = {
    ["SHADOW_RAID"]     = L["Shadow: Raid"],
    ["HOLY_RAID"]       = L["Holy: Raid"],
    ["DISC_RAID"]       = L["Discipline: Raid"],
    ["SHADOW_FARM"]     = L["Shadow: Multi-DoT Farming"],
    ["SHADOW_PVE"]      = L["Shadow: Raid (old profile)"],
    ["HOLY_DEEP"]       = L["Holy: Raid (old profile)"],
    ["DISC_PI_SUPPORT"] = L["Discipline: Raid (old profile)"],
    ["SHADOW_PVP"]           = L["PvP: Shadow (Blackout)"],
    ["DISC_PVP"]             = L["PvP: Discipline Healer"],

    ["Leveling_1_10"] = Band("Leveling", 1, 10),
}
-- One name per leveling role; each level band gets "(lo-hi)" added.
local ROLE_NAMES = {
    { "Leveling",               "Shadow: Solo Leveling" },
    { "Leveling_ShadowDungeon", "Shadow: Dungeon Leveling" },
    { "Leveling_Healer",        "Healer: Leveling" },
    { "Leveling_HealerDungeon", "Healer: Dungeon Leveling" },
    { "Leveling_Smite",         "Discipline / Holy: Solo Leveling" },
}
for _, r in ipairs(ROLE_NAMES) do
    for _, b in ipairs({ { 11, 20 }, { 21, 40 }, { 41, 51 }, { 52, 59 } }) do
        Priest.PrettyNames[r[1] .. "_" .. b[1] .. "_" .. b[2]] = Band(r[2], b[1], b[2])
    end
end

-- =============================================================
-- WOW FOREVER TALENTS
-- =============================================================
Priest.Talents = { 
    ["SHADOWFORM"]      = MSC.L["Shadowform"],
    ["POWER_INFUSION"]  = MSC.L["Power Infusion"],
    ["SPIRIT_GUIDANCE"] = MSC.L["Spiritual Guidance"],
    ["SHADOW_WEAVING"]  = MSC.L["Shadow Weaving"],
    ["BLACKOUT"]        = MSC.L["Blackout"],
    ["WAND_SPEC"]       = MSC.L["Wand Specialization"],
    ["SPIRIT_TAP"]      = MSC.L["Spirit Tap"],
    ["MENTAL_STRENGTH"] = MSC.L["Mental Strength"],
    ["DIVINE_FURY"]     = MSC.L["Divine Fury"],
    ["SHADOW_FOCUS"]    = MSC.L["Shadow Focus"],
    ["HOLY_PRECISION"]  = MSC.L["Holy Precision"], -- Discipline t2, 3 ranks, +6%/rank hit with Holy spells (client: 18 at 3/3)
    ["SPIRITUAL_HEALING"] = MSC.L["Spiritual Healing"], -- Holy t6, 3 ranks, +3%/rank universal healing done
    ["DARKNESS"]        = MSC.L["Darkness"], -- Shadow t6, 5 ranks, +2%/rank Shadow damage (Same as Classic)
    ["IMP_RENEW"]       = MSC.L["Improved Renew"], -- Holy t1, 3 ranks
    ["IMP_PWS"]         = MSC.L["Improved Power Word: Shield"], -- Discipline t2, 3 ranks
    ["MARTYRDOM"]       = MSC.L["Martyrdom"], -- Discipline t2, 2 ranks
    ["SILENT_RESOLVE"]  = MSC.L["Silent Resolve"], -- Discipline t2, 3 ranks, Holy threat reduction
    ["MEDITATION"]      = MSC.L["Meditation"], -- Discipline t3, 3 ranks, mana regen while casting
    ["INSPIRATION"]     = MSC.L["Inspiration"], -- Holy t3, 3 ranks
    ["MIND_FLAY"]       = MSC.L["Mind Flay"], -- Shadow t3 (L20), 1 rank
    ["DIVINE_AEGIS"]    = MSC.L["Divine Aegis"], -- Discipline t6, 3 ranks, crit heals shield
    ["PENANCE"]         = MSC.L["Penance"], -- Discipline t5 (L30), 1 rank
    ["PRAYER_OF_MENDING"] = MSC.L["Prayer of Mending"], -- Holy t7 (L40), 1 rank
    ["IMP_MIND_BLAST"]  = MSC.L["Improved Mind Blast"], -- Shadow t3, 5 ranks, -0.5 s Mind Blast cooldown each
    ["IMP_SWP"]         = MSC.L["Improved Shadow Word: Pain"], -- Shadow t2, 2 ranks, +3 s duration each
    ["DEVOURING_CONTAGION"] = MSC.L["Devouring Contagion"], -- Shadow; the farming build's signature (Devouring Plague spreads on a kill)
}

-- Leveling role marker talents (see MSC:GetLowLevelRole). Wand Specialization
-- (common Shadow leveling pick) and the Smite talents are deliberately not
-- markers. Discipline's Meditation, Improved Power Word: Shield, Martyrdom and
-- Silent Resolve were dropped as markers: Discipline wand levelers take them
-- too, and one point flipped them to the healer profile (no wand DPS, no hit).
Priest.LowLevelRoles = {
    Leveling_Healer = { "IMP_RENEW", "INSPIRATION", "DIVINE_AEGIS", "PRAYER_OF_MENDING" }, -- the last two only heal
    -- No markers (talents can't tell solo from group play): applies only when chosen, e.g. by a Talents plugin build.
    Leveling_Smite = {},
    Leveling_ShadowDungeon = {},
    Leveling_HealerDungeon = {},
}

-- =============================================================
-- LOGIC
-- =============================================================
Priest.ValidWeapons = {
    [4]=true,             -- 1H Maces
    [15]=true,            -- Daggers
    [10]=true,            -- Staves
    [19]=true             -- Wands
}

function Priest:GetSpec()
    local function Rank(k) return MSC:GetTalentRank(k) end
    local level = UnitLevel("player")
    
    -- Leveling Bracket Logic
    if level < 60 then
        -- Find Level Range Suffix
        local suffix = ""
        if level <= 10 then suffix = "_1_10"
        elseif level <= 20 then suffix = "_11_20"
        elseif level <= 40 then suffix = "_21_40"
        elseif level <= 51 then suffix = "_41_51"
        else suffix = "_52_59" end

        -- Determine Role
        local role = "Leveling" -- Default Shadow/Wand
        -- Healer markers are checked before Smite: Divine Fury also speeds up
        -- Heal/Greater Heal, so healers take it too
        local lowRole = (level >= 10) and MSC:GetLowLevelRole(Priest.LowLevelRoles)
        if lowRole then
            role = lowRole
        elseif Rank("SHADOWFORM") == 0 and Rank("DIVINE_FURY") > 0 then
            role = "Leveling_Smite" -- Smite
        elseif Rank("SPIRIT_GUIDANCE") > 0 then
            role = "Leveling_Healer" -- Holy
        end
        
        -- Build Key
        -- Level 10 brings the first talent point: a role it marks uses that
        -- role's 11-20 row (the 1-10 band only has the default row).
        if level == 10 and role ~= "Leveling" then suffix = "_11_20" end
        local key = role .. suffix
        
        -- Fallback: If Smite/Healer key doesn't exist for this level, revert to default
        if Priest.LevelingWeights[key] then return key end
        return "Leveling" .. suffix
    end

    -- Endgame: the farming build (Devouring Contagion), Shadowform, then the healers: Prayer of Mending is Holy's,
    -- Penance / Power Infusion Discipline's, otherwise the tree with more points.
    if Rank("DEVOURING_CONTAGION") > 0 then return "SHADOW_FARM" end
    if Rank("SHADOWFORM") > 0 then return "SHADOW_RAID" end
    if Rank("PRAYER_OF_MENDING") > 0 then return "HOLY_RAID" end
    if Rank("PENANCE") > 0 or Rank("POWER_INFUSION") > 0 then return "DISC_RAID" end
    local disc, holy, shadow = MSC.GetTabPointsSpent(1), MSC.GetTabPointsSpent(2), MSC.GetTabPointsSpent(3)
    if shadow > disc and shadow > holy then return "SHADOW_RAID" end
    if disc > holy then return "DISC_RAID" end
    return "HOLY_RAID"
end

function Priest:ApplyScalers(weights, currentSpec)
    local function Rank(k) return MSC:GetTalentRank(k) end
    local activeCaps = {}
    -- The study-built level-60 profiles already carry their talents: the talent hooks skip them (the hit cap still applies).
    -- Leveling_HealerDungeon too: the healer model builds it with every talent in, so its hooks would count twice.
    local hooks = not SIM_PROFILES[currentSpec or ""] and not (currentSpec or ""):find("^Leveling_HealerDungeon")

    local level = UnitLevel("player")
    local isLeveling = currentSpec:match("^Leveling") ~= nil
    -- the solo healer row only: Leveling_HealerDungeon is built by the healer model with every talent in (2026-10-23; its hooks
    -- applied twice before)
    local isHealerRow = currentSpec:match("^Leveling_Healer_%d") ~= nil
    local isSmiteRow = currentSpec:match("^Leveling_Smite") ~= nil
    local isDefaultRow = (currentSpec:match("^Leveling_%d") or currentSpec:match("^Leveling_ShadowDungeon")) ~= nil -- Shadow/Wand (solo and dungeon)
    local function Scale(key, mult)
        if weights[key] and mult ~= 1 then weights[key] = weights[key] * mult end
    end

    -- [[ Default Leveling (Shadow/Wand) talent hooks ]]
    if isDefaultRow then
        local rMF = Rank("MIND_FLAY")
        local rSF = Rank("SHADOWFORM")
        local mfRamp = rMF > 0 and level >= 28 and level < 40

        -- No-Shadowform restore: the 40+ rows bake Shadowform in, so a Disc/wand
        -- build without it gets the factors back (ramped in from 35 to 40)
        if level >= 36 and rSF == 0 then
            local p = (level >= 40) and 1 or ((level - 35) / 5)
            local function F(f) return f ^ p end
            -- A Mind Flay owner (28-39, Shadowform still ahead) is already moved
            -- to the filler rotation by the Mind Flay ramp below, so the wand and
            -- Spirit factors are left out for them (restoring them as well would
            -- put the wand weight at ~60 at 39 where the study path gives ~25)
            -- factors from the leveling model, the Shadow build's talents with and without Shadowform at 42-59 (SimStudio
            -- models/priest/pmodel.js, 2026-10-23; the old ones pointed the wrong way): crit loses Shadowform's x2.0 crit
            -- damage, Mp5 the half-cost spells, Stamina gains (more is healed back without Vampiric Embrace's form)
            if not mfRamp then
                Scale("ITEM_MOD_DAMAGE_PER_SECOND_SHORT", F(3.3))
            end
            Scale("ITEM_MOD_INTELLECT_SHORT", F(1.1))
            Scale("ITEM_MOD_MANA_SHORT", F(1.1))
            Scale("ITEM_MOD_MANA_REGENERATION_SHORT", F(0.68))
            Scale("ITEM_MOD_STAMINA_SHORT", F(1.5))
            Scale("ITEM_MOD_HEALTH_SHORT", F(1.5))
            MSC.ScaleForeverSpellCrit(weights, F(0.5), level)
        end

        -- Mind Flay ramp (28-39): the wand gives way to Mind Flay. Applied once,
        -- never stacked with Wand Specialization
        local mindFlayFired = false
        if mfRamp then
            mindFlayFired = true
            -- the model casts Mind Flay over the wand once it's trained (2026-10-23: wand ~0; was x0.6 at 35)
            Scale("ITEM_MOD_DAMAGE_PER_SECOND_SHORT", MSC.ForeverLevelLerp({ {39, 0.1}, {40, 1.0} }, level))
            Scale("ITEM_MOD_SPIRIT_SHORT", MSC.ForeverLevelLerp({ {35, 0.75}, {40, 1.0} }, level))
        end

        -- Wand Specialization (Discipline t1, 2 ranks): wand damage 13% / 25%
        local rWand = Rank("WAND_SPEC")
        -- (also with Shadowform + Mind Flay: the 40+ rows bake the wand as a short
        -- fight tail, and the talent still adds its % to that tail)
        if rWand > 0 and not mindFlayFired then
            Scale("ITEM_MOD_DAMAGE_PER_SECOND_SHORT", ({ 1.13, 1.25 })[math.min(rWand, 2)])
        end

        -- Spirit Tap (Shadow t1, 5 ranks) and Meditation (Discipline t3, 3 ranks)
        -- both add casting regen to the same Spirit pool, so their gains add
        -- (a Shadow build with Meditation, as the solo build has from 51, took
        -- only the larger one before: 1.8 instead of 2.34)
        local tapGain = 0.16 * Rank("SPIRIT_TAP")
        local medGain = ((rMF > 0) and 0.18 or 0.12) * Rank("MEDITATION")
        Scale("ITEM_MOD_SPIRIT_SHORT", 1 + tapGain + medGain)

        -- Improved Mind Blast (-0.5 s cooldown/rank, 5 ranks) and Improved Shadow
        -- Word: Pain (+3 s/rank, 2 ranks) raise Shadow's share of the kill (about
        -- +0.6% / +2.5% per rank); the gain moves from the Arcane key (Starshards)
        -- so the school shares still sum to the Spell Power unit
        local shMult = 1 + 0.006 * Rank("IMP_MIND_BLAST") + 0.025 * Rank("IMP_SWP")
        local shKey, arKey = weights["ITEM_MOD_SHADOW_DAMAGE_SHORT"], weights["ITEM_MOD_ARCANE_DAMAGE_SHORT"]
        if shMult ~= 1 and shKey and arKey then
            weights["ITEM_MOD_SHADOW_DAMAGE_SHORT"] = shKey * shMult
            weights["ITEM_MOD_ARCANE_DAMAGE_SHORT"] = math.max(0, arKey - shKey * (shMult - 1))
        end

        -- Shadow Weaving (Shadow t4, 3 ranks): 5 stacks of +2% Shadow damage, and
        -- since 1.60.1.70170 it can no longer fail to apply; ~70% of the 10% is up
        -- over a kill. Same Shadow/hit-crit split as Darkness. Not baked in the rows
        if Rank("SHADOW_WEAVING") > 0 then
            local dmSW = 1 + 0.07 * 0.65
            Scale("ITEM_MOD_SPELL_POWER_SHORT", dmSW)
            Scale("ITEM_MOD_SHADOW_DAMAGE_SHORT", dmSW)
            local cmSW = 1 + 0.07 * 0.35
            Scale("ITEM_MOD_SPELL_CRIT_RATING_SHORT", cmSW)
            Scale("ITEM_MOD_HIT_SPELL_RATING_SHORT", 1 + (cmSW - 1) * MSC.LevelingHookShare())   -- hit: fades 50-59 here, not in the core
        end
    end

    -- [[ Healer: Meditation, Divine Aegis, Penance, Prayer of Mending ]]
    if isHealerRow then
        -- Meditation (Discipline t3, 3 ranks): Spirit regen while casting, so Spirit
        -- gains and Intellect/Mana lose value
        local rMedH = Rank("MEDITATION")
        if rMedH > 0 and level >= 20 then
            Scale("ITEM_MOD_SPIRIT_SHORT", 1 + 0.144 * rMedH)
            local k = MSC.ForeverLevelLerp({ {25, 0}, {30, 0.032}, {40, 0.051}, {50, 0.078}, {59, 0.085} }, level)
            local m = 1 - k * rMedH
            Scale("ITEM_MOD_INTELLECT_SHORT", m)
            Scale("ITEM_MOD_MANA_SHORT", m)
        end

        -- Divine Aegis (Discipline t6, 3 ranks): crit heals shield
        local rAegis = Rank("DIVINE_AEGIS")
        if rAegis > 0 then
            MSC.ScaleForeverSpellCrit(weights, 1 + 0.10 * rAegis, level)
        end

        -- Penance (Discipline t5, L30) and Prayer of Mending (Holy t7, L40) cover
        -- part of the mana demand at a fraction of the cost
        local manaMult = 1
        if Rank("PENANCE") > 0 and level >= 30 then manaMult = manaMult * ((level >= 40) and 0.85 or 0.90) end
        if Rank("PRAYER_OF_MENDING") > 0 and level >= 40 then manaMult = manaMult * 0.90 end
        Scale("ITEM_MOD_INTELLECT_SHORT", manaMult)
        Scale("ITEM_MOD_MANA_SHORT", manaMult)

        -- Wand Specialization (Discipline t1, 2 ranks, 12.5% per rank)
        Scale("ITEM_MOD_DAMAGE_PER_SECOND_SHORT", 1 + 0.125 * Rank("WAND_SPEC"))
    end

    -- [[ Smite: Meditation, Wand Specialization ]]
    if isSmiteRow then
        Scale("ITEM_MOD_SPIRIT_SHORT", 1 + 0.11 * Rank("MEDITATION"))
        Scale("ITEM_MOD_DAMAGE_PER_SECOND_SHORT", 1 + 0.13 * Rank("WAND_SPEC"))
    end

    -- [[ 1. Spiritual Guidance (Spirit -> Spell Power) ]]
    -- Holy t5, 5 ranks: the text (healing up to 5% of Spirit, damage up to 1%) is
    -- the rank-1 value, so per rank it is 5% healing / 1.6% damage (Smite rows:
    -- damage 1% of Spirit, healing only when the row carries a healing weight)
    local rSG = Rank("SPIRIT_GUIDANCE")
    if hooks and rSG > 0 and weights["ITEM_MOD_SPIRIT_SHORT"] then
        local spWeight = weights["ITEM_MOD_SPELL_POWER_SHORT"] or 0
        if isSmiteRow then
            local healWeight = weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or 0
            weights["ITEM_MOD_SPIRIT_SHORT"] = weights["ITEM_MOD_SPIRIT_SHORT"] + (healWeight * (rSG * 0.05)) + (spWeight * (rSG * 0.01))
        else
            local healWeight = weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or spWeight
            local dmgWeight = weights["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"] or spWeight
            weights["ITEM_MOD_SPIRIT_SHORT"] = weights["ITEM_MOD_SPIRIT_SHORT"] + (healWeight * (rSG * 0.05)) + (dmgWeight * (rSG * 0.016))
        end
    end

    local rMent = Rank("MENTAL_STRENGTH")
    if hooks and rMent > 0 and weights["ITEM_MOD_INTELLECT_SHORT"] then
        weights["ITEM_MOD_INTELLECT_SHORT"] = weights["ITEM_MOD_INTELLECT_SHORT"] * (1 + (rMent * 0.02))
    end

    -- Shadowform (Shadow t7, 1 rank): doubles the crit damage bonus of Shadow
    -- spells (+100% crit damage bonus, i.e. 50% -> 100%, a flat 2x on Crit's value)
    -- Leveling rows already build Shadowform's crit bonus into their 40-59
    -- keyframes (Curves/Priest_Curves.lua), so only the endgame profiles get it here.
    if hooks and Rank("SHADOWFORM") > 0 and not currentSpec:match("^Leveling") and weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] then
        weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] = weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] * 2.0
    end

    -- Spiritual Healing (Holy t6, 3 ranks): +3%/rank universal healing done
    local rSpiritHeal = Rank("SPIRITUAL_HEALING")
    if hooks and rSpiritHeal > 0 then
        if isHealerRow then
            -- A healing multiplier also scales Int/Mp5/Spirit/crit per mana, so the
            -- row keeps Healing and the solo-only stats are divided instead
            local inv = 1 / (1 + 0.03 * rSpiritHeal * 0.6)
            Scale("ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", inv)
            Scale("ITEM_MOD_SPELL_POWER_SHORT", inv)
            Scale("ITEM_MOD_DAMAGE_PER_SECOND_SHORT", inv)
            Scale("ITEM_MOD_HIT_SPELL_RATING_SHORT", inv)
            Scale("ITEM_MOD_SHADOW_DAMAGE_SHORT", inv)
            Scale("ITEM_MOD_ARCANE_DAMAGE_SHORT", inv)
        elseif weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] then
            weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] * (1 + (rSpiritHeal * 0.03))
        end
    end

    -- Darkness (Shadow t6, 5 ranks, Same as Classic): +2%/rank Shadow damage
    local rDark = Rank("DARKNESS")
    if hooks and rDark > 0 then
        if isDefaultRow then
            -- (the default Leveling_<band> profiles are the Shadow/Wand leveling weights)
            -- Shadow damage is ~0.65 of the kill, the rest of the gain is hit/crit value
            local dm = 1 + (rDark * 0.02 * 0.65)
            Scale("ITEM_MOD_SPELL_POWER_SHORT", dm)
            Scale("ITEM_MOD_SHADOW_DAMAGE_SHORT", dm)
            local cm = 1 + (rDark * 0.02 * 0.35)
            Scale("ITEM_MOD_SPELL_CRIT_RATING_SHORT", cm)
            Scale("ITEM_MOD_HIT_SPELL_RATING_SHORT", 1 + (cm - 1) * MSC.LevelingHookShare())   -- hit: fades 50-59 here, not in the core
        elseif currentSpec:find("SHADOW") and weights["ITEM_MOD_SPELL_POWER_SHORT"] then
            weights["ITEM_MOD_SPELL_POWER_SHORT"] = weights["ITEM_MOD_SPELL_POWER_SHORT"] * (1 + (rDark * 0.02))
        end
    end

    -- Leveling rows: no weight lingers in (0, 0.02)
    if isLeveling then
        for k, v in pairs(weights) do
            if type(v) == "number" and v > 0 and v < 0.02 then weights[k] = 0 end
        end
    end

    -- (The old "Spirit grows with healing power" scaler is gone, 2026-10-28: it never ran on a
    -- level-60 profile, and the healer weights move with gear through the profile's gear points.)

    -- [[ 3. Spell Hit Cap ]]
    -- Every damage profile (Shadow and Smite leveling included, not only the
    -- endgame SHADOW ones). Target is the level's cap, sliding to the raid
    -- cap from 50. Shadow Focus (1%/rank, Shadow only) is added for Shadow
    -- profiles, since the game's general spell-hit number doesn't include it.
    -- Holy Precision is not counted on the Smite rows any more: the 2026-10-16
    -- leveling model (SimStudio pmodel.js) has those builds casting no Holy
    -- spell (Shadow Word: Pain, Starshards, Shadow Word: Death and the wand).
    local isShadow = currentSpec:find("SHADOW") or isDefaultRow
    local talentHit = (isShadow and Rank("SHADOW_FOCUS")) or 0
    local rSFocus = Rank("SHADOW_FOCUS")
    if (isDefaultRow or isSmiteRow) and rSFocus > 0 and weights["ITEM_MOD_HIT_SPELL_RATING_SHORT"] then
        -- Shadow Focus only covers Shadow spells; the wand and Smite still miss at
        -- the level's cap. Hit is worth full below (cap - Shadow Focus) of gear hit,
        -- then only the non-Shadow share (1 - s) until the cap, then the usual 0.1.
        -- s = the Shadow share of the hit value in the leveling model (SimStudio
        -- models/priest/priest_solo_curves_build.js, 2026-10-23; Starshards is a
        -- Night Elf racial, so the race-neutral Priest doesn't cast it): the wand
        -- carries the rest early, Shadow spells everything from 25
        local s = MSC.ForeverLevelLerp({ {10, 0.61}, {15, 0.65}, {20, 0.87}, {25, 1.0} }, level)
        local cap = MSC.GetForeverCapTarget(MSC.ForeverSpellCapKind(currentSpec) or "SPELL")   -- dungeon rows: 5.5%
        MSC.ApplyForeverHitKnees(weights, "ITEM_MOD_HIT_SPELL_RATING_SHORT", "SPELL", {
            { cap = math.max(0, cap - rSFocus), mult = (1 - s) + s * 0.1 },
            { cap = cap, mult = 0.1 },
        }, "Spell Hit", activeCaps, 0)
    else
        MSC.ApplyForeverHitCap(weights, "ITEM_MOD_HIT_SPELL_RATING_SHORT", "SPELL", 0.1, "Spell Hit", activeCaps, talentHit, MSC.ForeverSpellCapKind(currentSpec))
    end

    return weights, (#activeCaps > 0 and table.concat(activeCaps, ", ") or nil)
end

function Priest:GetWeaponBonus(itemLink, weights, slotId, specName, otherHandLink)
    return MSC.GetForeverWeaponRacialBonus(itemLink, weights, otherHandLink)
end

-- =============================================================
-- REGISTER
-- =============================================================
-- Retired hand-made profiles (2026-10-27 weight check): the old names point at sim profiles so a saved choice or an
-- alt's profile still works; MSC lists skip them (RetiredProfiles).
Priest.Weights["Default"] = Priest.Weights["HOLY_RAID"]
Priest.Weights["HYBRID_POWER_WEAVING"] = Priest.Weights["DISC_RAID"]
Priest.RetiredProfiles = { Default = true, HYBRID_POWER_WEAVING = true }
-- A saved retired name scores as the sim profile it points at, so the talent hooks skip it too.
for k in pairs(Priest.RetiredProfiles) do SIM_PROFILES[k] = true end

Priest.Profiles = {}
for k, v in pairs(Priest.Weights) do Priest.Profiles[k] = v end
for k, v in pairs(Priest.LevelingWeights) do Priest.Profiles[k] = v end

MSC.RegisterModule("PRIEST", Priest)




