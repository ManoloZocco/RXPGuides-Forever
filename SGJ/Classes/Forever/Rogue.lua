if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local Rogue = {}
Rogue.Name = "ROGUE"

-- =============================================================
-- LEVEL-60 WEIGHTS
-- =============================================================
-- Hit and Crit are per 1%; the rest per point. Rogues get 1 Attack Power from
-- each point of Strength and Agility, and Agility also gives crit. The raid
-- profiles come from the wowsims Forever sim run from the Research folder
-- (study/rogue2, 2026-10-03; re-run 2026-10-08 from SharpiesGearJudge-SimStudio). The sim runs
-- each build's own talents (Lethality, Hack and Slash, Dual Wield
-- Specialization...), so ApplyScalers' talent hooks are for the leveling rows.
-- AP sits at 1.5 in the raid profiles. Re-run 2026-10-13 with poisons scaling off attack power (0.5% on
-- Instant, 0.45% on each Deadly tick per stack, per the devs on forever-bugs #100; the per-tick reading is
-- unconfirmed in game), which makes Attack Power itself worth a little more than the other stats.
Rogue.Weights = {

    -- Combat: Raid (Combat swords with Sinister Strike, level-63 boss, raid buffs). Agility is worth about
    -- twice Attack Power (its crit), and Hit and Crit are close. Off-hand weapon DPS is worth a quarter of the main hand's.
    ["COMBAT_RAID"] = { ["ITEM_MOD_AGILITY_SHORT"]=2.83, ["ITEM_MOD_STRENGTH_SHORT"]=1.65, ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_HIT_RATING_SHORT"]=30.8, ["ITEM_MOD_CRIT_RATING_SHORT"]=30.5, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=15.4, ["MSC_WEAPON_DPS_OH"]=4.6, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=2.0 },
    -- Combat: Raid (Daggers) (Backstab from behind). About 4% behind swords in the sim.
    ["COMBAT_DAGGERS"] = { ["ITEM_MOD_AGILITY_SHORT"]=2.78, ["ITEM_MOD_STRENGTH_SHORT"]=1.65, ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_HIT_RATING_SHORT"]=23.8, ["ITEM_MOD_CRIT_RATING_SHORT"]=29.3, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=14.4, ["MSC_WEAPON_DPS_OH"]=4.9, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=2.0 },
    -- Assassination: Raid (Mutilate) (Assassination 31 / Combat 20, daggers). Mutilate hits with both hands, so the
    -- off-hand counts for more; Hit and Crit higher (Seal Fate combo points). About 10% behind Combat swords.
    ["ASSN_MUTILATE"] = { ["ITEM_MOD_AGILITY_SHORT"]=3.05, ["ITEM_MOD_STRENGTH_SHORT"]=1.65, ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_HIT_RATING_SHORT"]=25.6, ["ITEM_MOD_CRIT_RATING_SHORT"]=36.1, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=12.2, ["MSC_WEAPON_DPS_OH"]=6.5, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=2.0 },

}
-- PvP profiles: copies of the PvE profile each build plays like; the PvP model (Helpers 5.10) adds
-- Stamina, armor and burst on top and keeps hit at the player-vs-player caps.
Rogue.Weights["PVP_HEMO"] = MSC.ForeverPvPFrom(Rogue.Weights["COMBAT_RAID"])        -- Hemorrhage with a sword or mace
Rogue.Weights["PVP_MACE"] = MSC.ForeverPvPFrom(Rogue.Weights["COMBAT_RAID"])        -- Mace Specialization stuns
Rogue.Weights["PVP_CB_DAGGER"] = MSC.ForeverPvPFrom(Rogue.Weights["COMBAT_DAGGERS"]) -- Cold Blood / Ambush daggers
-- Old names, kept so a saved profile choice still works.
Rogue.Weights["RAID_COMBAT_SWORDS"] = Rogue.Weights["COMBAT_RAID"]
Rogue.Weights["RAID_COMBAT_DAGGERS"] = Rogue.Weights["COMBAT_DAGGERS"]
Rogue.Weights["RAID_SEAL_FATE"] = Rogue.Weights["ASSN_MUTILATE"]

-- =============================================================
-- LEVELING WEIGHTS
-- =============================================================
-- Filled at load from Classes/Forever/Curves/Rogue_Curves.lua (generated from
-- the study; don't edit it by hand) by Curves_Attach.lua: one row per role and level band,
-- blended by level in MSC:GetLevelingRow. Roles:
--   Leveling                Combat: Solo Leveling (swords/maces, the default)
--   Leveling_Dagger         Assassination: Solo Leveling (daggers, Mutilate)
--   Leveling_DaggerDungeon  Daggers: Dungeon Leveling (Backstab from behind; the Combat, Assassination and Subtlety dungeon builds)
--   Leveling_Hemo           Subtlety: Solo Leveling (Hemorrhage / Ghostly Strike)
Rogue.LevelingWeights = {}

-- =============================================================
-- DISPLAY NAMES (match the Talents plugin's builds; translated in Locales/*.lua)
-- =============================================================
local L = MSC.L
local function Band(label, lo, hi) return L[label] .. " (" .. lo .. "-" .. hi .. ")" end
Rogue.PrettyNames = {
    ["COMBAT_RAID"]         = L["Combat: Raid"],
    ["COMBAT_DAGGERS"]      = L["Combat: Raid (Daggers)"],
    ["ASSN_MUTILATE"]       = L["Assassination: Raid (Mutilate)"],
    ["RAID_COMBAT_SWORDS"]  = L["Combat: Raid (old profile)"],
    ["RAID_COMBAT_DAGGERS"] = L["Combat: Raid (Daggers, old profile)"],
    ["RAID_SEAL_FATE"]      = L["Assassination: Raid (old profile)"],
    ["PVP_MACE"]            = L["PvP: Mace Specialization"],
    ["PVP_HEMO"]            = L["PvP: Hemo Control"],
    ["PVP_CB_DAGGER"]       = L["PvP: Cold Blood Burst"],

    ["Leveling_1_10"] = Band("Leveling", 1, 10),
}
-- One name per leveling role; each level band gets "(lo-hi)" added.
local ROLE_NAMES = {
    { "Leveling",               "Combat: Solo Leveling" },
    { "Leveling_Dagger",        "Assassination: Solo Leveling" },
    { "Leveling_DaggerDungeon", "Daggers: Dungeon Leveling" },
    { "Leveling_Hemo",          "Subtlety: Solo Leveling" },
}
for _, r in ipairs(ROLE_NAMES) do
    for _, b in ipairs({ { 11, 20 }, { 21, 40 }, { 41, 51 }, { 52, 59 } }) do
        Rogue.PrettyNames[r[1] .. "_" .. b[1] .. "_" .. b[2]] = Band(r[2], b[1], b[2])
    end
end

-- =============================================================
-- WOW FOREVER TALENTS
-- =============================================================
Rogue.Talents = { 
    ["SEAL_FATE"]       = MSC.L["Seal Fate"],
    ["COLD_BLOOD"]      = MSC.L["Cold Blood"],
    ["ADRENALINE_RUSH"] = MSC.L["Adrenaline Rush"],
    ["HACK_AND_SLASH"]  = MSC.L["Hack and Slash"],
    ["PUNCTURING_WOUNDS"]= MSC.L["Puncturing Wounds"],
    ["RIPOSTE"]         = MSC.L["Riposte"],
    ["HEMORRHAGE"]      = MSC.L["Hemorrhage"],
    ["PREPARATION"]     = MSC.L["Preparation"],
    ["LETHALITY"]       = MSC.L["Lethality"],
    ["PRECISION"]       = MSC.L["Precision"],
    ["WEAP_EXPERTISE"]  = MSC.L["Weapon Expertise"],
    ["MUTILATE"]        = MSC.L["Mutilate"],
    ["VENOM"]           = MSC.L["Venom"],
    ["THOUSAND_CUTS"]   = MSC.L["Thousand Cuts"],
    -- Leveling role markers (tiers 1-3, see Rogue.LowLevelRoles)
    ["IMP_SINISTER_STRIKE"] = MSC.L["Improved Sinister Strike"], -- Combat t1
    ["LIGHTNING_REFLEXES"]  = MSC.L["Lightning Reflexes"], -- Combat t1
    ["DEFLECTION"]          = MSC.L["Deflection"], -- Combat t2
    ["OPPORTUNITY"]         = MSC.L["Opportunity"], -- Subtlety t1, Backstab damage
    ["IMP_AMBUSH"]          = MSC.L["Improved Ambush"], -- Subtlety t2
    ["CAMOUFLAGE"]          = MSC.L["Camouflage"], -- Subtlety t1
    ["MASTER_OF_DECEPTION"] = MSC.L["Master of Deception"], -- Subtlety t1
    ["SETUP"]               = MSC.L["Setup"], -- Subtlety t2
    ["ELUSIVENESS"]         = MSC.L["Elusiveness"], -- Subtlety t2
    ["DIRTY_TRICKS"]        = MSC.L["Dirty Tricks"], -- Subtlety t2
    ["INITIATIVE"]          = MSC.L["Initiative"], -- Subtlety t3
    ["GHOSTLY_STRIKE"]      = MSC.L["Ghostly Strike"], -- Subtlety t3
    ["DW_SPEC"]             = MSC.L["Dual Wield Specialization"], -- Combat t4
    ["MALICE"]              = MSC.L["Malice"], -- Assassination t1
    ["RUTHLESSNESS"]        = MSC.L["Ruthlessness"], -- Assassination t2
    ["RELENTLESS_STRIKES"]  = MSC.L["Relentless Strikes"], -- Assassination t3
    ["MURDER"]              = MSC.L["Murder"], -- Assassination t2
    ["IMP_EVISCERATE"]      = MSC.L["Improved Eviscerate"], -- Combat t1
}

-- =============================================================
-- LOGIC
-- =============================================================
Rogue.ValidWeapons = {
    [0]=true,             -- 1H Axes (Forever: SkillRaceClassInfo gives Rogues Axes)
    [4]=true,             -- 1H Maces
    [7]=true,             -- 1H Swords
    [13]=true, [15]=true, -- Fists, Daggers
    [2]=true, [3]=true, [18]=true, [16]=true -- Bow, Gun, Crossbow, Thrown
}

-- Leveling role marker talents (see MSC:GetLowLevelRole). "Leveling" is the
-- Combat (Swords/Maces) default. Assassination picks and generic Combat picks
-- (Improved Eviscerate, Precision, Endurance, Improved Sprint) mark nothing.
Rogue.LowLevelRoles = {
    Leveling        = { "IMP_SINISTER_STRIKE", "LIGHTNING_REFLEXES", "DEFLECTION", "RIPOSTE" },
    -- (Opportunity and Improved Ambush aren't markers: every Subtlety rogue
    -- takes them, which tied pure-Subtlety builds 3-3 and sent them to Combat.)
    -- Malice (2026-10-22): the Assassination solo build opens with it, and before Mutilate its Improved Sinister Strike
    -- read as Combat; the Combat build out-marks its 5 ranks with Improved Sinister Strike, Deflection and Riposte.
    Leveling_Dagger = { "PUNCTURING_WOUNDS", "MUTILATE", "MALICE" },
    Leveling_Hemo   = { "CAMOUFLAGE", "MASTER_OF_DECEPTION", "SETUP", "ELUSIVENESS", "DIRTY_TRICKS", "INITIATIVE", "GHOSTLY_STRIKE" },
    -- No markers (talents can't tell solo from group play): applies only when chosen, e.g. by a Talents plugin build.
    Leveling_DaggerDungeon = {},
}

function Rogue:GetSpec()
    local function Rank(k) return MSC:GetTalentRank(k) end
    local level = UnitLevel("player")

    if level < 60 then
        if level < 10 then return "Leveling_1_10" end
        local suffix = (level <= 20 and "_11_20") or (level <= 40 and "_21_40") or (level <= 51 and "_41_51") or "_52_59"

        -- A Talents plugin build names its role; it wins over the talent markers below.
        local forced = (MSC.GetBuildRole() or {}).leveling
        if forced and (forced == "Leveling" or Rogue.LowLevelRoles[forced]) and Rogue.LevelingWeights[forced .. suffix] then
            return forced .. suffix
        end

        local role = "Leveling" -- Combat swords/maces
        local subPts = MSC.GetTabPointsSpent(3)
        local otherPts = MSC.GetTabPointsSpent(1) + MSC.GetTabPointsSpent(2)
        if Rank("HEMORRHAGE") > 0 then role = "Leveling_Hemo"
        elseif Rank("PUNCTURING_WOUNDS") > 0 or Rank("MUTILATE") > 0 then role = "Leveling_Dagger"
        -- Ghostly Strike, or mostly-Subtlety points, is a Hemo leveler
        elseif Rank("GHOSTLY_STRIKE") > 0 or (subPts >= 5 and subPts > otherPts) then role = "Leveling_Hemo"
        else role = MSC:GetLowLevelRole(Rogue.LowLevelRoles) or role
        end
        if Rogue.LevelingWeights[role .. suffix] then return role .. suffix end
        if level == 10 then return "Leveling_1_10" end
        return "Leveling" .. suffix
    end

    -- Endgame: the PvP signatures first, then the tree with the most points.
    if Rank("HEMORRHAGE") > 0 and Rank("PREPARATION") > 0 then return "PVP_HEMO" end
    if Rank("COLD_BLOOD") > 0 and Rank("PREPARATION") > 0 then return "PVP_CB_DAGGER" end
    local assn, combat = MSC.GetTabPointsSpent(1), MSC.GetTabPointsSpent(2)
    if Rank("MUTILATE") > 0 or Rank("SEAL_FATE") > 0 or assn > combat then return "ASSN_MUTILATE" end
    -- Combat: a dagger in the main hand (Backstab), otherwise swords/maces/fists
    local mh = GetInventoryItemLink("player", 16)
    if mh and select(7, GetItemInfoInstant(mh)) == 15 then return "COMBAT_DAGGERS" end
    return "COMBAT_RAID"
end

function Rogue:ApplyScalers(weights, currentSpec)
    local function Rank(k) return MSC:GetTalentRank(k) end
    local activeCaps = {}

    local spec = currentSpec or ""
    local isLeveling = spec:find("^Leveling") ~= nil
    local level = UnitLevel("player")

    -- Lethality (Assassination t3, 5 ranks): +4%/rank crit damage bonus on
    -- Sinister Strike/Gouge/Backstab/Mutilate/Ghostly Strike/Hemorrhage only.
    -- Melee crits already deal 2.0x, so 5/5 lifts that bonus from 1.00 to 1.20
    -- on those yellow hits alone (not white hits, Ambush, Eviscerate or
    -- poison). The leveling rows are built without it (rogue_curves_build.js);
    -- per rank, rmodel's crit weight with 5/5 against none (2026-10-22). The
    -- level-60 profiles come from the sim with Lethality in.
    local isDaggerSolo = spec:find("^Leveling_Dagger_") ~= nil
    local isDungeon = spec:find("^Leveling_DaggerDungeon") ~= nil
    local rLethal = Rank("LETHALITY")
    if rLethal > 0 and isLeveling then
        local perRank = 0.012
        if isDaggerSolo then perRank = 0.008
        elseif isDungeon then perRank = 0.0067
        elseif spec:find("^Leveling_Hemo") then perRank = 0.0065 end
        MSC.ScaleForeverMeleeCrit(weights, 1 + (rLethal * perRank), level)
    end

    if isLeveling then
        -- Dual Wield Specialization (Combat t4, 5 ranks): +5% off-hand damage
        -- per rank; only the white part scales, poison does not (0.045/rank)
        local rDW = Rank("DW_SPEC")
        if rDW > 0 then
            MSC.ScaleForeverKeys(weights, { "MSC_WEAPON_DPS_OH" }, 1 + (rDW * 0.045))
        end

        -- Damage talents the Combat curve is built without (rogue_curves_build.js,
        -- 2026-10-22). Each is a share-weighted damage gain; the
        -- net factor lowers the survival keys the same way a flat damage
        -- talent does (fights end sooner), and a player without the talents
        -- gets 1.0. Skipped for the Dagger/Hemo rows. Dual Wield
        -- Specialization's off-hand key is the hook above; this is only its
        -- overall damage gain (5%/rank on ~19% white off-hand damage, poison
        -- excluded = 0.009/rank). Malice: +1% crit/rank over ~1.2 crit-
        -- adjusted = 0.0085/rank. Ruthlessness: 20%/rank extra combo point
        -- is ~10% shorter cycle at 3/3 on the ~55% yellow share, scaled for
        -- short solo fights = 0.010/rank. Relentless Strikes: 25 energy per
        -- finisher (~90% at 4.5 CP), same scaling = 0.025. Murder: 2%/rank on
        -- ~35% Humanoid mobs = 0.007/rank. Improved Eviscerate: 7%/rank on ~18%
        -- of damage = 0.0125/rank.
        if not spec:find("^Leveling_Dagger") and not spec:find("^Leveling_Hemo") then
            local dmg = 1 + 0.0125 * Rank("IMP_EVISCERATE")
            dmg = dmg * (1 + 0.009 * Rank("DW_SPEC") + 0.0085 * Rank("MALICE")
                + 0.010 * Rank("RUTHLESSNESS") + 0.025 * Rank("RELENTLESS_STRIKES")
                + 0.007 * Rank("MURDER"))
            local armor = weights["ITEM_MOD_ARMOR_SHORT"]
            MSC.ApplyForeverDamageMult(weights, dmg)
            -- keep Armor out of the 0-0.02 band the engine treats as unscored
            if armor and armor >= 0.02 and weights["ITEM_MOD_ARMOR_SHORT"] < 0.02 then
                weights["ITEM_MOD_ARMOR_SHORT"] = 0.02
            end
        end

        -- (Mutilate's weapon weights are in the Assassination row itself since 2026-10-22: no hook.)
    end

    -- [[ 1. Yellow Hit Cap, tapered to the DW white cap ]]
    -- Hit % in percent with Precision counted once (MSC:GetForeverHitPercent);
    -- caps follow the level and slide to the raid caps from 50.
    MSC.ApplyForeverHitKnees(weights, "ITEM_MOD_HIT_RATING_SHORT", "MELEE", {
        { cap = MSC.GetForeverCapTarget("MELEE"), mult = 0.6 },
        { cap = MSC.GetForeverCapTarget("DW_WHITE"), mult = 0.05 },
    }, "Yellow Hit", activeCaps)

    -- [[ 2. Weapon Skill Cap (Removed in Forever) ]]

    return weights, (#activeCaps > 0 and table.concat(activeCaps, ", ") or nil)
end

-- Hack and Slash (New in Forever, Combat t5, 5 ranks): per-weapon-type bonus.
-- The Dagger/Fist branch (+1%/rank Crit) is scored here, the same math as the
-- racial weapon-crit bonuses; the Axe/Sword (extra attacks) and Mace (armor
-- ignore) branches are GetHackAndSlashProcBonus below.
-- The +1%/rank crit only helps that hand's swings: the main hand carries all
-- yellow hits plus its white swings (~75% of damage), the off hand only its
-- own white swings (~20%); 0.5 when the hand isn't known.
local function GetHackAndSlashCritBonus(itemLink, weights, slotId, specName)
    local rHS = MSC:GetTalentRank("HACK_AND_SLASH")
    if rHS <= 0 or not itemLink or not weights then return 0 end
    -- Leveling rows only, like the proc branch: each level-60 profile is simmed for one
    -- weapon type with the talent in (a sword raid Rogue saw every fist weapon get it)
    local spec = specName or MSC.CachedSpecKey or ""
    if not spec:find("^Leveling") then return 0 end

    local _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemLink)
    if classID ~= 2 or not subClassID then return 0 end
    if subClassID ~= 13 and subClassID ~= 15 then return 0 end -- Fist (13), Dagger (15)

    local slotFactor = (slotId == 16 and 0.75) or (slotId == 17 and 0.2) or 0.5
    -- Crit weight is already "per 1%" (see MSC.GetForeverWeaponRacialBonus)
    return rHS * (weights["ITEM_MOD_CRIT_RATING_SHORT"] or 0) * slotFactor -- +1%/rank Crit
end

-- Backstab, Ambush and Mutilate need a dagger in the main hand, and Ghostly
-- Strike (180%) and Hemorrhage (145%) hit much harder with one, but the
-- weights have no weapon-type term: without this a slightly faster sword
-- outscores the dagger. Flat AP-equivalent bonus for a main-hand dagger, by
-- level: rmodel's score with the dagger against the same weapon as a sword
-- (the rows' shipped builds, 2026-10-22; was 26-48 AP). Below 30 solo a
-- Garrote opener does as well as Ambush, so a dagger adds nothing there.
local DAGGER_MAIN_HAND = {
    ["Leveling_Dagger_"]       = { { 25, 0 }, { 30, 47 }, { 35, 53 }, { 40, 105 }, { 45, 157 }, { 50, 230 }, { 59, 260 } },
    ["Leveling_Hemo"]          = { { 25, 0 }, { 30, 122 }, { 35, 170 }, { 45, 168 }, { 50, 190 }, { 55, 196 }, { 59, 215 } },
    ["Leveling_DaggerDungeon"] = { { 25, 60 }, { 30, 183 }, { 35, 212 }, { 40, 251 }, { 45, 315 }, { 50, 315 }, { 55, 362 }, { 59, 384 } },
}
local function GetDaggerMainHandBonus(itemLink, weights, slotId, specName)
    if slotId ~= 16 or not itemLink or not weights then return 0 end
    local spec = specName or MSC.CachedSpecKey or ""
    local points
    for prefix, pts in pairs(DAGGER_MAIN_HAND) do
        if spec:find("^" .. prefix) then points = pts end
    end
    if not points then return 0 end
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemLink)
    if classID ~= 2 or subClassID ~= 15 then return 0 end
    local level = MSC.CtxLevel()
    local ap = points[#points][2]
    if level <= points[1][1] then ap = points[1][2]
    else
        for i = 1, #points - 1 do
            local a, b = points[i], points[i + 1]
            if level <= b[1] then ap = a[2] + (b[2] - a[2]) * (level - a[1]) / (b[1] - a[1]); break end
        end
    end
    return ap * (weights["ITEM_MOD_ATTACK_POWER_SHORT"] or 1)
end

-- Hack and Slash sword/axe (extra-attack chance) and mace (armor ignore)
-- branches, Leveling rows only: rmodel's AP worth of 5/5 on the Combat row
-- (built without the talent; 2026-10-22, was ~1.7x this), x rank/5. The off
-- hand gets half of either.
local HS_SWORD = { { 30, 34.5 }, { 35, 41 }, { 40, 49 }, { 45, 57 }, { 50, 63 }, { 55, 69 }, { 59, 75 } }
local HS_MACE = { { 30, 30 }, { 35, 36 }, { 40, 51 }, { 45, 65 }, { 50, 77 }, { 55, 85 }, { 59, 94.5 } }
local function GetHackAndSlashProcBonus(itemLink, weights, slotId, specName)
    local rHS = MSC:GetTalentRank("HACK_AND_SLASH")
    if rHS <= 0 or not itemLink or not weights then return 0 end
    local spec = specName or MSC.CachedSpecKey or ""
    if not spec:find("^Leveling") then return 0 end
    if slotId ~= 16 and slotId ~= 17 then return 0 end

    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemLink)
    if classID ~= 2 or (subClassID ~= 7 and subClassID ~= 4 and subClassID ~= 0) then return 0 end -- 1H Sword, Mace, Axe

    local level = MSC.CtxLevel()
    if level < 30 then return 0 end
    local ap = MSC.ForeverLevelLerp(subClassID == 4 and HS_MACE or HS_SWORD, level) * rHS / 5
    if slotId == 17 then ap = ap * 0.5 end
    return ap * (weights["ITEM_MOD_ATTACK_POWER_SHORT"] or 1)
end

function Rogue:GetWeaponBonus(itemLink, weights, slotId, specName, otherHandLink)
    return MSC.GetForeverWeaponRacialBonus(itemLink, weights, otherHandLink)
        + GetHackAndSlashCritBonus(itemLink, weights, slotId, specName)
        + GetHackAndSlashProcBonus(itemLink, weights, slotId, specName)
        + GetDaggerMainHandBonus(itemLink, weights, slotId, specName)
end

-- Retired hand-made profiles (2026-10-27 weight check): the old names point at sim profiles so a saved choice or an
-- alt's profile still works; MSC lists skip them (RetiredProfiles).
Rogue.Weights["Default"] = Rogue.Weights["COMBAT_RAID"]
Rogue.RetiredProfiles = { Default = true }

MSC.RegisterModule("ROGUE", Rogue)


