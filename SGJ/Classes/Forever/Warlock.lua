if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local Warlock = {}
Warlock.Name = "WARLOCK"

-- =============================================================
-- WOW FOREVER STAT WEIGHTS (Beta Baseline)
-- =============================================================
-- Hit and crit weights are per 1% (Forever ratings are flat: 10 hit / 14 crit rating = 1%).
-- We use standard keys so the Evaluator can match them.

Warlock.Weights = {
    -- The raid profiles come from the wowsims Forever sim (study/warlock2, 2026-10-03; NOTES.md there has the numbers),
    -- run with each build's own talents and demon, so ApplyScalers' talent hooks skip them. Spell Power sits at 2.0;
    -- Hit and Crit per 1%. Most of the damage is Shadow. Stamina is a small Life Tap / safety term (the sim's three-
    -- minute fight never runs a warlock dry).
    -- Demonology: Raid (Demonic Pact 5/31/15: Succubus out with a sacrificed Imp's buff kept). About 19% ahead of Affliction.
    ["DEMO_PACT_RAID"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_SHADOW_DAMAGE_SHORT"]=1.46, ["ITEM_MOD_FIRE_DAMAGE_SHORT"]=0.54, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=28.9, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=19.7, ["ITEM_MOD_INTELLECT_SHORT"]=0.58, ["ITEM_MOD_SPIRIT_SHORT"]=0.14, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=0.34, ["ITEM_MOD_STAMINA_SHORT"]=0.3 },
    -- Affliction: Raid (Affliction 35 / Destruction 16, Succubus).
    ["AFF_RAID"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_SHADOW_DAMAGE_SHORT"]=1.77, ["ITEM_MOD_FIRE_DAMAGE_SHORT"]=0.23, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=19.7, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=23.1, ["ITEM_MOD_INTELLECT_SHORT"]=0.56, ["ITEM_MOD_SPIRIT_SHORT"]=0.12, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=0.2, ["ITEM_MOD_STAMINA_SHORT"]=0.3 },
    -- Destruction: Raid (DS/Ruin with Pandemic: the Imp sacrificed). About 28% behind Demonology.
    ["DESTRO_RAID"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_SHADOW_DAMAGE_SHORT"]=1.79, ["ITEM_MOD_FIRE_DAMAGE_SHORT"]=0.21, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=19.4, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=19.2, ["ITEM_MOD_INTELLECT_SHORT"]=0.49, ["ITEM_MOD_SPIRIT_SHORT"]=0.07, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=0.15, ["ITEM_MOD_STAMINA_SHORT"]=0.3 },
    -- DEMO_FARM: from the farm model (SimStudio models/shared/farm_profiles.py, data/farm_weights.json: the WARLOCK_DEMO_FARM build's
    -- talents at the main farm spot, mobs 3 levels below you, the farm gear set), 2026-10-25, re-run 2026-11-01.
    -- Tempered (user): Intellect / Spirit / Mp5 / Stamina at most 3x Spell Power, Stamina at least 1x, Hit / Crit at most 25.
    ["DEMO_FARM"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_FIRE_DAMAGE_SHORT"]=2.0, ["ITEM_MOD_STAMINA_SHORT"]=4.48, ["ITEM_MOD_INTELLECT_SHORT"]=3.48, ["ITEM_MOD_SPIRIT_SHORT"]=4.45, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=1.53, ["ITEM_MOD_HEALTH_REGENERATION_SHORT"]=1.73, ["ITEM_MOD_ARMOR_SHORT"]=0.42, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=25.0, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=25.0 },

}
-- PvP profiles: copies of the PvE profile each build plays like; the PvP model (Helpers 5.10) adds
-- Stamina, armor and burst on top and keeps hit at the player-vs-player caps.
-- Nightfall/Conflagrate mixes Shadow Bolt procs with Conflagrate, so Fire takes a bigger share than in the raid build;
-- Deep Destruction is mostly Fire (Searing Pain, Conflagrate, Shadowburn). Soul Link moves part of the damage you take
-- to the demon and Life Tap pays for spells in health, so its Stamina floor is the farming build's.
Warlock.Weights["PVP_NF_CONFLAG"] = MSC.ForeverPvPFrom(Warlock.Weights["AFF_RAID"], { ["ITEM_MOD_SHADOW_DAMAGE_SHORT"]=1.3, ["ITEM_MOD_FIRE_DAMAGE_SHORT"]=0.7 })
Warlock.Weights["PVP_DEEP_DESTRO"] = MSC.ForeverPvPFrom(Warlock.Weights["DESTRO_RAID"], { ["ITEM_MOD_SHADOW_DAMAGE_SHORT"]=0.6, ["ITEM_MOD_FIRE_DAMAGE_SHORT"]=1.4 })
Warlock.Weights["PVP_SOUL_LINK"] = MSC.ForeverPvPFrom(Warlock.Weights["DEMO_PACT_RAID"], { ["ITEM_MOD_STAMINA_SHORT"]=3.0 })
-- Old names, kept so a saved profile choice still works.
Warlock.Weights["PVE_MD_RUIN"] = Warlock.Weights["DEMO_PACT_RAID"]
Warlock.Weights["RAID_SM_RUIN"] = Warlock.Weights["AFF_RAID"]
Warlock.Weights["RAID_DS_RUIN"] = Warlock.Weights["DESTRO_RAID"]
-- Fallback before a spec is known: the Affliction raid weights. The old Spell Power 15 table valued 1% hit
-- at about 1.3 Spell Power, roughly a tenth of what the sim gives.
Warlock.Weights["Default"] = Warlock.Weights["AFF_RAID"]
-- The sim-built raid profiles (talents already in): ApplyScalers' talent hooks skip these.
local SIM_PROFILES = { DEMO_FARM = true, DEMO_PACT_RAID = true, AFF_RAID = true, DESTRO_RAID = true, PVE_MD_RUIN = true, RAID_SM_RUIN = true, RAID_DS_RUIN = true,
    PVP_NF_CONFLAG = true, PVP_DEEP_DESTRO = true, PVP_SOUL_LINK = true, Default = true }

-- =============================================================
-- LEVELING WEIGHTS
-- =============================================================
-- Filled at load from Classes/Forever/Curves/Warlock_Curves.lua (generated by
-- SimStudio; don't edit it by hand) by Curves_Attach.lua: one row per role and level band,
-- blended by level in MSC:GetLevelingRow. Roles:
--   Leveling          Affliction: Solo Leveling (DoTs + Voidwalker, the default)
--   Leveling_Dungeon  Affliction: Dungeon Leveling
--   Leveling_Demo     Demonology: Solo Leveling (Soul Link; also the AoE farming build's leveling)
--   Leveling_Fire     Destruction: Solo Leveling
Warlock.LevelingWeights = {}

-- =============================================================
-- DISPLAY NAMES (translated in Locales/*.lua; the Talents plugin has Affliction solo and dungeon builds, the
-- Demonology / Destruction rows serve their raid, farming and PvP builds' leveling)
-- =============================================================
local L = MSC.L
local function Band(label, lo, hi) return L[label] .. " (" .. lo .. "-" .. hi .. ")" end
Warlock.PrettyNames = {
    ["DEMO_PACT_RAID"] = L["Demonology: Raid"],
    ["AFF_RAID"]       = L["Affliction: Raid"],
    ["DESTRO_RAID"]    = L["Destruction: Raid"],
    ["DEMO_FARM"]      = L["Demonology: AoE Farming"],
    ["PVE_MD_RUIN"]    = L["Demonology: Raid (old profile)"],
    ["RAID_SM_RUIN"]   = L["Affliction: Raid (old profile)"],
    ["RAID_DS_RUIN"]   = L["Destruction: Raid (old profile)"],
    ["PVP_NF_CONFLAG"]  = L["PvP: Nightfall / Conflagrate"],
    ["PVP_SOUL_LINK"]   = L["PvP: Soul Link (Tank)"],
    ["PVP_DEEP_DESTRO"] = L["PvP: Destruction (Conflag)"],

    ["Leveling_1_10"] = Band("Leveling", 1, 10),
}
-- One name per leveling role; each level band gets "(lo-hi)" added.
local ROLE_NAMES = {
    { "Leveling",         "Affliction: Solo Leveling" },
    { "Leveling_Dungeon", "Affliction: Dungeon Leveling" },
    { "Leveling_Demo",    "Demonology: Solo Leveling" },
    { "Leveling_Fire",    "Destruction: Solo Leveling" },
}
for _, r in ipairs(ROLE_NAMES) do
    for _, b in ipairs({ { 11, 20 }, { 21, 40 }, { 41, 51 }, { 52, 59 } }) do
        Warlock.PrettyNames[r[1] .. "_" .. b[1] .. "_" .. b[2]] = Band(r[2], b[1], b[2])
    end
end

-- =============================================================
-- WOW FOREVER TALENTS
-- =============================================================
Warlock.Talents = { 
    ["DEMONIC_SACRIFICE"] = MSC.L["Demonic Sacrifice"],
    ["SHADOW_MASTERY"]    = MSC.L["Shadow Mastery"],
    ["RUIN"]              = MSC.L["Ruin"],
    ["SOUL_LINK"]         = MSC.L["Soul Link"],
    ["CONFLAGRATE"]       = MSC.L["Conflagrate"],
    ["INCINERATE"]        = MSC.L["Incinerate"],
    ["DEMONIC_PACT"]      = MSC.L["Demonic Pact"],
    ["FEL_CONCENTRATION"] = MSC.L["Fel Concentration"],
    ["NIGHTFALL"]         = MSC.L["Nightfall"],
    ["INTENSITY"]         = MSC.L["Intensity"],
    ["MASTER_DEMON"]      = MSC.L["Master Demonologist"],
    ["SUPPRESSION"]       = MSC.L["Suppression"],
    ["DEMONIC_EMBRACE"]   = MSC.L["Demonic Embrace"],
    ["GRIM_REACH"]        = MSC.L["Grim Reach"], -- Affliction t2, 2 ranks, +10%/rank Affliction range (replaced Malediction in 70425)
    ["PANDEMIC"]          = MSC.L["Pandemic"], -- New in Forever, Affliction t3, 3 ranks, +33%/rank crit damage bonus on DoTs (now that DoTs crit)
    ["AGONIZING_FLAMES"]  = MSC.L["Agonizing Flames"], -- New in Forever, Destruction t4, 3 ranks, +3%/rank Destruction spell damage
    -- Leveling role markers (tiers 1-3, see Warlock.LowLevelRoles)
    ["IMP_CORRUPTION"]    = MSC.L["Improved Corruption"], -- Affliction t1
    ["SOUL_HARVESTING"]   = MSC.L["Soul Harvest"], -- Affliction t2 (renamed from Soul Harvesting in the 2 Oct patch)
    ["IMP_LIFE_TAP"]      = MSC.L["Improved Life Tap"], -- Affliction t1, 2 ranks, +10% mana per Life Tap per rank
    ["DEMONIC_KNOWLEDGE"] = MSC.L["Demonic Knowledge"], -- Demonology t5, 3 ranks, spell damage from the demon
    ["IMP_DRAINS"]        = MSC.L["Improved Drains"], -- Affliction t2
    ["IMP_BANE_AGONY"]    = MSC.L["Improved Bane of Agony"], -- Affliction t3
    ["AMPLIFY_CURSE"]     = MSC.L["Amplify Curse"], -- Affliction t3
    ["IMP_HEALTH_FUNNEL"] = MSC.L["Improved Health Funnel"], -- Demonology t1
    ["IMP_IMP"]           = MSC.L["Improved Imp"], -- Demonology t1
    ["UNHOLY_POWER"]      = MSC.L["Unholy Power"], -- Demonology t1
    ["DEMONIC_AEGIS"]     = MSC.L["Demonic Aegis"], -- Demonology t2
    ["IMP_VOIDWALKER"]    = MSC.L["Improved Voidwalker"], -- Demonology t2
    ["FEL_VITALITY"]      = MSC.L["Fel Vitality"], -- Demonology t2
    ["DEMONIC_ENERGIES"]  = MSC.L["Demonic Energies"], -- Demonology t2
    ["IMP_SAYAAD"]        = MSC.L["Improved Sayaad"], -- Demonology t3
    ["MASTER_SUMMONER"]   = MSC.L["Master Summoner"], -- Demonology t3
    ["DESTRUCTIVE_REACH"] = MSC.L["Destructive Reach"], -- Destruction t1
    ["IMP_SHADOW_BOLT"]   = MSC.L["Improved Shadow Bolt"], -- Destruction t1
    ["BANE"]              = MSC.L["Bane"], -- Destruction t1
    ["MOLTEN_SKIN"]       = MSC.L["Molten Skin"], -- Destruction t2
    ["CATACLYSM"]         = MSC.L["Cataclysm"], -- Destruction t2
    ["AFTERMATH"]         = MSC.L["Aftermath"], -- Destruction t2
    ["SHADOWBURN"]        = MSC.L["Shadowburn"], -- Destruction t3
}

-- =============================================================
-- LOGIC
-- =============================================================
Warlock.ValidWeapons = {
    [7]=true,             -- 1H Swords
    [15]=true,            -- Daggers
    [10]=true,            -- Staves
    [19]=true             -- Wands
}

-- Leveling role marker talents (see MSC:GetLowLevelRole): each tree's
-- tier 1-3 picks, so the tree with the most points wins. "Leveling" is the
-- Affliction default. Improved Life Tap marks nothing (every tree takes it).
Warlock.LowLevelRoles = {
    Leveling      = { "SUPPRESSION", "IMP_CORRUPTION", "GRIM_REACH", "SOUL_HARVESTING", "IMP_DRAINS", "IMP_BANE_AGONY", "FEL_CONCENTRATION", "AMPLIFY_CURSE", "PANDEMIC" },
    Leveling_Demo = { "IMP_HEALTH_FUNNEL", "IMP_IMP", "DEMONIC_EMBRACE", "UNHOLY_POWER", "DEMONIC_AEGIS", "IMP_VOIDWALKER", "FEL_VITALITY", "DEMONIC_ENERGIES", "IMP_SAYAAD", "DEMONIC_SACRIFICE", "MASTER_SUMMONER" },
    Leveling_Fire = { "DESTRUCTIVE_REACH", "IMP_SHADOW_BOLT", "BANE", "MOLTEN_SKIN", "CATACLYSM", "AFTERMATH", "RUIN", "SHADOWBURN" },
    -- No markers (talents can't tell solo from group play): applies only when chosen, e.g. by a Talents plugin build.
    Leveling_Dungeon = {},
}

function Warlock:GetSpec()
    local function Rank(k) return MSC:GetTalentRank(k) end
    local level = UnitLevel("player")

    if level < 60 then
        if level < 10 then return "Leveling_1_10" end
        local suffix = (level <= 20 and "_11_20") or (level <= 40 and "_21_40") or (level <= 51 and "_41_51") or "_52_59"

        -- A Talents plugin build names its role; it wins over the talent checks below.
        local forced = (MSC.GetBuildRole() or {}).leveling
        if forced and (forced == "Leveling" or Warlock.LowLevelRoles[forced]) and Warlock.LevelingWeights[forced .. suffix] then
            return forced .. suffix
        end

        local prefix = "Leveling" -- Affliction
        if Rank("INCINERATE") > 0 or Rank("CONFLAGRATE") > 0 then prefix = "Leveling_Fire"
        elseif Rank("SOUL_LINK") > 0 or Rank("MASTER_DEMON") > 0 then prefix = "Leveling_Demo"
        else
            prefix = MSC:GetLowLevelRole(Warlock.LowLevelRoles) or prefix
            if prefix == "Leveling_Dungeon" then prefix = "Leveling" end
        end
        if Warlock.LevelingWeights[prefix .. suffix] then return prefix .. suffix end
        if level == 10 then return "Leveling_1_10" end
        return "Leveling" .. suffix
    end

    -- Endgame: the AoE farming build (Soul Link with Molten Skin), Demonic Pact, then the tree with the most points.
    if Rank("SOUL_LINK") > 0 and Rank("MOLTEN_SKIN") >= 3 and Rank("DEMONIC_PACT") == 0 then return "DEMO_FARM" end
    if Rank("DEMONIC_PACT") > 0 then return "DEMO_PACT_RAID" end
    local aff, demo, destro = MSC.GetTabPointsSpent(1), MSC.GetTabPointsSpent(2), MSC.GetTabPointsSpent(3)
    if demo > aff and demo >= destro then return "DEMO_PACT_RAID" end
    if destro > aff then return "DESTRO_RAID" end
    return "AFF_RAID"
end

function Warlock:ApplyScalers(weights, currentSpec)
    local function Rank(k) return MSC:GetTalentRank(k) end
    local activeCaps = {}
    -- The sim-built raid profiles already carry their talents: the talent hooks skip them (the hit cap still applies).
    local hooks = not SIM_PROFILES[currentSpec or ""]

    -- [[ 1. Demonic Embrace (Stamina) ]]
    -- The lmodel-built rows (Leveling, Leveling_Dungeon) already carry it: their builders play the shipped Affliction builds,
    -- which take it (2026-10-23 deep dive).
    local rEmb = Rank("DEMONIC_EMBRACE")
    local isModelRow = type(currentSpec) == "string" and (currentSpec:find("^Leveling_%d") or currentSpec:find("^Leveling_Dungeon")) ~= nil
    if hooks and not isModelRow and rEmb > 0 and weights["ITEM_MOD_STAMINA_SHORT"] then
        weights["ITEM_MOD_STAMINA_SHORT"] = weights["ITEM_MOD_STAMINA_SHORT"] * (1 + (rEmb * 0.03))
    end

    -- Ruin (Destruction t3, 5 ranks): "Increases the critical strike damage
    -- bonus of your Destruction spells by 20%" -- same phrasing/math as Mage's
    -- Arcane Mind/Ice Shards -- 1+rank*0.20, reaching 2.0x at 5/5 (matches
    -- real Classic Ruin's known doubling effect exactly). Shadow Bolt itself
    -- is a Destruction spell, so this applies by rank on the hand-set rows
    -- (the sim-built raid profiles skip it; leveling rows are below).
    local isLeveling = type(currentSpec) == "string" and currentSpec:find("^Leveling") ~= nil
    local rRuin = Rank("RUIN")
    if hooks and not isLeveling and rRuin > 0 and weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] then
        weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] = weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] * (1 + (rRuin * 0.20))
    end

    -- Pandemic (New in Forever, Affliction t3, 3 ranks): same crit-damage-bonus
    -- phrasing, now extended to DoTs since Forever lets periodic damage crit --
    -- 1+rank*0.33, reaching ~2.0x at 3/3, consistent with every other
    -- crit-damage-bonus talent converging on a 2x cap at its own max rank
    local rPandemic = Rank("PANDEMIC")
    local rShadowMastery = Rank("SHADOW_MASTERY")
    local rAgonizing = Rank("AGONIZING_FLAMES")

    if isLeveling then
        local level = UnitLevel("player")

        -- Leveling rows: Pandemic only touches DoT crits and Ruin only
        -- Destruction crits, so each applies to its share of the rotation's
        -- crit-able damage (Pandemic's dotShare rises with level as Corruption/
        -- Agony/Immolate ticks grow; Ruin's destroShare depends on the spec),
        -- and the two add into ONE multiplier instead of stacking to x2-4.
        local destroShare = 0.5 -- Leveling (Affliction)
        if currentSpec:find("^Leveling_Fire") then destroShare = 0.85
        elseif currentSpec:find("^Leveling_Demo") then destroShare = 0.3 end
        local dotShare = MSC.ForeverLevelLerp({ {15, 0.45}, {20, 0.50}, {25, 0.50}, {30, 0.55}, {35, 0.60}, {40, 0.60}, {45, 0.65}, {50, 0.70}, {59, 0.70} }, level)
        local critMult = 1 + (0.20 * rRuin * destroShare) + (0.33 * rPandemic * dotShare)
        MSC.ScaleForeverSpellCrit(weights, critMult, level)

        -- Shadow Mastery (+2%/rank Shadow) and Agonizing Flames (+3% Destruction,
        -- Fire rows) raise everything expressed in spell damage -- Spell Power,
        -- school damage, hit and crit -- but not wand, Int, Spirit, Mp5 or Stamina.
        local dmgMult = 1 + 0.02 * rShadowMastery
        -- Hit isn't in the list: it's a cap key the core fade (50-59) leaves alone, so it gets
        -- the same multipliers faded by MSC.LevelingHookShare (FadeHit).
        local dmgKeys = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SHADOW_DAMAGE_SHORT", "ITEM_MOD_SPELL_CRIT_RATING_SHORT" }
        local function FadeHit(m) MSC.ScaleForeverKeys(weights, { "ITEM_MOD_HIT_SPELL_RATING_SHORT" }, 1 + (m - 1) * MSC.LevelingHookShare(level)) end
        if currentSpec:find("^Leveling_Fire") and rAgonizing > 0 then
            dmgMult = dmgMult * (1 + ({ 0.03, 0.07, 0.10 })[math.min(3, rAgonizing)])   -- client 3/7/10%
            dmgKeys[#dmgKeys + 1] = "ITEM_MOD_FIRE_DAMAGE_SHORT"
        end
        MSC.ScaleForeverKeys(weights, dmgKeys, dmgMult)
        FadeHit(dmgMult)

        -- Soul Harvest (Affliction t2, 2 ranks): the regen buff is
        -- conditional on a Drain Soul kill (level 10+), so about +6%/rank.
        local rSoulHarvest = Rank("SOUL_HARVESTING")
        if rSoulHarvest > 0 and level >= 10 then
            MSC.ScaleForeverKeys(weights, { "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT" }, 1 + 0.06 * rSoulHarvest)
        end

        -- Improved Life Tap (Affliction t1, 2 ranks, +10% mana per Life Tap per
        -- rank): baked into the lmodel-built rows (their rest rows play the
        -- shipped builds, which take it; it was counted twice there before
        -- 2026-10-23), not into the Demonology / Destruction study rows. Each HP
        -- tapped returns more mana, so HP is better fuel (Stamina, Health, Hp5
        -- about +3.5%/rank) and mana is cheaper (Int and flat +Mana about -4%/rank).
        local rLifeTap = Rank("IMP_LIFE_TAP")
        if rLifeTap > 0 and not isModelRow then
            MSC.ScaleForeverKeys(weights, { "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_HEALTH_SHORT", "ITEM_MOD_HEALTH_REGENERATION_SHORT" }, 1 + 0.035 * rLifeTap)
            MSC.ScaleForeverKeys(weights, { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_MANA_SHORT" }, 1 - 0.04 * rLifeTap)
        end

        -- Soul Link (Demonology t5, 1 rank: 30% of damage taken goes to the
        -- demon, +3% damage) and Demonic Knowledge (3 ranks): the Leveling_Demo
        -- keyframes bake in a mild Soul Link (Stamina/Health x0.95, Armor x0.93)
        -- and Demonic Knowledge as hit/crit x1.05, all reached at 30 and eased
        -- in from 25, so these use the un-bake pattern against what each
        -- keyframe baked: real / baked. Rows without those keyframes (Fire)
        -- bake nothing. Soul Link also lifts every damage-derived weight 3%.
        local rSoulLink = Rank("SOUL_LINK")
        local demoBake = 0
        if currentSpec:find("^Leveling_Demo") then
            demoBake = math.max(0, math.min(1, (level - 25) / 5))
        end
        if rSoulLink > 0 or demoBake > 0 then
            -- Soul Link takes 30% of the damage the HP/armor would have stopped:
            -- the safety share of Stamina (about 0.3 of its weight) falls 30%,
            -- armor (all safety) falls 30%.
            local stamFix = (1 - 0.09 * math.min(rSoulLink, 1)) / (1 - 0.05 * demoBake)
            MSC.ScaleForeverKeys(weights, { "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_HEALTH_SHORT" }, stamFix)
            local armorOld = weights["ITEM_MOD_ARMOR_SHORT"]
            if armorOld then
                -- never push a weight that sat above 0.02 into the useless band
                local armorNew = armorOld * (1 - 0.30 * math.min(rSoulLink, 1)) / (1 - 0.07 * demoBake)
                if armorOld >= 0.02 and armorNew < 0.02 then armorNew = 0.02 end
                weights["ITEM_MOD_ARMOR_SHORT"] = armorNew
            end
        end
        if rSoulLink > 0 then
            MSC.ScaleForeverKeys(weights, dmgKeys, 1.03)
            FadeHit(1.03)
        end
        local rDK = Rank("DEMONIC_KNOWLEDGE")
        if demoBake > 0 or rDK > 0 then
            -- 3 ranks give the baked x1.05 (+1.67% per rank)
            local dkFix = (1 + (0.05 / 3) * rDK) / (1 + 0.05 * demoBake)
            FadeHit(dkFix)
            MSC.ScaleForeverSpellCrit(weights, dkFix, level)
        end

        -- Fel Vitality (Demonology t2, 3 ranks, +5% max mana/rank): scales the
        -- mana part of Int (about 0.85 of it) and flat +Mana.
        if currentSpec:find("^Leveling_Demo") then
            local rFelVit = Rank("FEL_VITALITY")
            if rFelVit > 0 then
                MSC.ScaleForeverKeys(weights, { "ITEM_MOD_MANA_SHORT" }, 1 + 0.05 * rFelVit)
                MSC.ScaleForeverKeys(weights, { "ITEM_MOD_INTELLECT_SHORT" }, 1 + 0.04 * rFelVit)
            end
        end
    elseif hooks then
        if rPandemic > 0 and weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] then
            weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] = weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] * (1 + (rPandemic * 0.33))
        end

        -- Shadow Mastery (Affliction t6, 5 ranks): +2%/rank Shadow spell damage/drain (1%/rank before the 15 Oct patch)
        if rShadowMastery > 0 and weights["ITEM_MOD_SPELL_POWER_SHORT"] then
            weights["ITEM_MOD_SPELL_POWER_SHORT"] = weights["ITEM_MOD_SPELL_POWER_SHORT"] * (1 + (rShadowMastery * 0.02))
        end

        -- Agonizing Flames (New in Forever, Destruction t4, 3 ranks): +3/7/10%
        -- damage on all Destruction spells (includes Shadow Bolt): Spell Power and
        -- Fire damage (the farming build's Hellfire / Rain of Fire)
        if rAgonizing > 0 then
            local af = 1 + ({ 0.03, 0.07, 0.10 })[math.min(3, rAgonizing)]
            MSC.ScaleForeverKeys(weights, { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_FIRE_DAMAGE_SHORT" }, af)
        end
    end

    -- [[ 2. Hit Cap ]]
    -- Suppression is +1% hit on all spells in Forever, so it's already in the
    -- game's spell-hit number (MSC:GetForeverHitPercent). Target is the
    -- level's cap, sliding to the raid cap from 50.
    MSC.ApplyForeverHitCap(weights, "ITEM_MOD_HIT_SPELL_RATING_SHORT", "SPELL", 0.1, "Spell Hit", activeCaps, nil, MSC.ForeverSpellCapKind(currentSpec))

    return weights, (#activeCaps > 0 and table.concat(activeCaps, ", ") or nil)
end

function Warlock:GetWeaponBonus(itemLink, weights, slotId, specName, otherHandLink)
    return MSC.GetForeverWeaponRacialBonus(itemLink, weights, otherHandLink)
end

-- Retired hand-made profiles (2026-10-27 weight check): the old names point at sim profiles so a saved choice or an
-- alt's profile still works; MSC lists skip them (RetiredProfiles).
Warlock.RetiredProfiles = { Default = true }

MSC.RegisterModule("WARLOCK", Warlock)



