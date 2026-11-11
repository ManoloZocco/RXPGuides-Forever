if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local Warrior = {}
Warrior.Name = "WARRIOR"

-- =============================================================
-- LEVEL-60 WEIGHTS
-- =============================================================
-- Hit, Crit, Dodge, Parry and Block weights are per 1%; Defense per skill
-- point; the rest per point. Warriors get 2 Attack Power per Strength and none
-- from Agility. The profiles come from the wowsims Forever sim run from the
-- Research folder (study/warrior2, 2026-10-03; NOTES.md there has the numbers
-- behind each one), re-run on 2026-10-09 for client 70291 (resim_70291.py,
-- prot_weights.py): Precision and Toughness gone, Dual Wield Specialization
-- without hit, Furious Precision for off-hand hit, Bloodthirst 45% AP. The sim runs each profile's own talents, so their effects
-- are already in these weights; ApplyScalers' talent hooks are for the leveling
-- rows only.
Warrior.Weights = {
    -- Fallback before a spec is known.

    -- Arms: Raid (Arms 34 / Fury 17, two-hander, level-63 boss, raid buffs, pre-raid gear). AP sits at 1.5.
    -- Hit is worth more than Crit: a miss costs rage as well as the swing, and Overpower procs need hits.
    -- Weapon DPS is above 14x AP because Mortal Strike and Overpower add weapon damage on top of the swing.
    ["ARMS_RAID"] = { ["ITEM_MOD_STRENGTH_SHORT"]=3.3, ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=23.3, ["ITEM_MOD_AGILITY_SHORT"]=2.82, ["ITEM_MOD_HIT_RATING_SHORT"]=64.7, ["ITEM_MOD_CRIT_RATING_SHORT"]=50.4, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=2.0 },

    -- Fury profiles (no Talents plugin build: Arms out-damages them in Forever, 493 / 438 DPS against 553).
    -- Dual wield: the off-hand's weapon DPS is worth about a third of the main hand's (MSC_WEAPON_DPS_OH).
    -- Hit is worth much more than before 70291: Dual Wield Specialization lost its off-hand hit, so more
    -- white swings miss (Furious Precision gives some back, off-hand only).
    ["FURY_DW"] = { ["ITEM_MOD_STRENGTH_SHORT"]=3.3, ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=16.7, ["MSC_WEAPON_DPS_OH"]=4.8, ["ITEM_MOD_AGILITY_SHORT"]=3.06, ["ITEM_MOD_HIT_RATING_SHORT"]=30.6, ["ITEM_MOD_CRIT_RATING_SHORT"]=54.2, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=2.0 },
    -- Two-hander: the sim's own Hit below the cap (it used to copy Arms, when the sim's gear was
    -- capped with Precision).
    ["FURY_2H"] = { ["ITEM_MOD_STRENGTH_SHORT"]=3.3, ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=18.5, ["ITEM_MOD_AGILITY_SHORT"]=2.88, ["ITEM_MOD_HIT_RATING_SHORT"]=55.9, ["ITEM_MOD_CRIT_RATING_SHORT"]=50.5, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=2.0 },

    -- Protection: Raid (Shield Slam build with Improved Thunder Clap, level-63 boss; threat 35%, damage
    -- taken 35%, effective health 30%). Boss hits are large, so dodge, parry, Defense and armor lead; Hit
    -- and Crit carry the threat. Stamina 3.0 here; the leveling tank rows use 2.5.
    ["PROT_RAID"] = { ["ITEM_MOD_STAMINA_SHORT"]=3.0, ["ITEM_MOD_DODGE_RATING_SHORT"]=23.4, ["ITEM_MOD_PARRY_RATING_SHORT"]=23.4, ["ITEM_MOD_BLOCK_RATING_SHORT"]=0.2, ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"]=2.74, ["ITEM_MOD_ARMOR_SHORT"]=0.18, ["ITEM_MOD_BLOCK_VALUE_SHORT"]=1.56, ["ITEM_MOD_HIT_RATING_SHORT"]=18.0, ["ITEM_MOD_CRIT_RATING_SHORT"]=11.8, ["ITEM_MOD_AGILITY_SHORT"]=2.15, ["ITEM_MOD_STRENGTH_SHORT"]=1.23, ["ITEM_MOD_ATTACK_POWER_SHORT"]=0.52, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=2.7, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=1.0 },

    -- PROT_AOE: from the farm model (SimStudio models/shared/farm_profiles.py, data/farm_weights.json: the WARRIOR_PROT_FARM build's
    -- talents at the main farm spot, mobs 3 levels below you, the farm gear set), 2026-10-25, re-run 2026-11-01.
    ["PROT_AOE"] = { ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.0, ["ITEM_MOD_STRENGTH_SHORT"]=2.0, ["ITEM_MOD_AGILITY_SHORT"]=2.08, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=5.6, ["ITEM_MOD_STAMINA_SHORT"]=0.84, ["ITEM_MOD_SPIRIT_SHORT"]=1.68, ["ITEM_MOD_HEALTH_REGENERATION_SHORT"]=4.85, ["ITEM_MOD_ARMOR_SHORT"]=0.11, ["ITEM_MOD_BLOCK_VALUE_SHORT"]=13.15, ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"]=3.47, ["ITEM_MOD_DODGE_RATING_SHORT"]=18.9, ["ITEM_MOD_PARRY_RATING_SHORT"]=18.9, ["ITEM_MOD_BLOCK_RATING_SHORT"]=12.5, ["ITEM_MOD_HIT_RATING_SHORT"]=14.9, ["ITEM_MOD_CRIT_RATING_SHORT"]=17.0, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=1.0 },

    -- ARMS_FARM: from the farm model (SimStudio models/shared/farm_profiles.py, data/farm_weights.json: the WARRIOR_2H_FARM build's
    -- talents at the main farm spot, mobs 3 levels below you, the farm gear set), 2026-10-25, re-run 2026-11-01.
    ["ARMS_FARM"] = { ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_STRENGTH_SHORT"]=3.0, ["ITEM_MOD_AGILITY_SHORT"]=2.1, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=19.5, ["ITEM_MOD_STAMINA_SHORT"]=2.15, ["ITEM_MOD_SPIRIT_SHORT"]=1.46, ["ITEM_MOD_HEALTH_REGENERATION_SHORT"]=5.22, ["ITEM_MOD_ARMOR_SHORT"]=0.14, ["ITEM_MOD_HIT_RATING_SHORT"]=23.3, ["ITEM_MOD_CRIT_RATING_SHORT"]=35.4 },
}
-- PvP profile: a copy of Arms: Raid; the PvP model (Helpers 5.10) adds Stamina, armor and burst on top
-- and keeps hit at the player-vs-player caps. Picked by the Talents plugin's PvP build or by hand.
Warrior.Weights["ARMS_PVP"] = MSC.ForeverPvPFrom(Warrior.Weights["ARMS_RAID"])
-- With Gear for PvP on, auto-detect shows the PvP profile in place of the raid one
-- (same weights plus the PvP model; MSC:ApplyDynamicAdjustments).
Warrior.PvPCounterpart = { ARMS_RAID = "ARMS_PVP", ARMS_MS = "ARMS_PVP" }
-- Old names, kept so a saved profile choice still works.
Warrior.Weights["ARMS_MS"] = Warrior.Weights["ARMS_RAID"]
Warrior.Weights["DEEP_PROT"] = Warrior.Weights["PROT_RAID"]

-- =============================================================
-- LEVELING WEIGHTS
-- =============================================================
-- Filled at load from Classes/Forever/Curves/Warrior_Curves.lua (generated from
-- the study; don't edit it by hand) by Curves_Attach.lua: one row per role and level band,
-- blended by level in MSC:GetLevelingRow. Roles:
--   Leveling              Arms: Solo Leveling (the default; two-hander)
--   Leveling_ArmsDungeon  Arms: Dungeon Leveling
--   Leveling_DW           Fury: Dual Wield Leveling (a weapon in the off-hand, or Fury's dual-wield talents)
--   Leveling_Tank         Protection: Solo Leveling
--   Leveling_TankDungeon  Protection: Dungeon Leveling
Warrior.LevelingWeights = {}

-- =============================================================
-- DISPLAY NAMES (match the Talents plugin's builds; translated in Locales/*.lua)
-- =============================================================
local L = MSC.L
local function Band(label, lo, hi) return L[label] .. " (" .. lo .. "-" .. hi .. ")" end
Warrior.PrettyNames = {
    ["ARMS_RAID"] = L["Arms: Raid"],
    ["ARMS_MS"]   = L["Arms: Raid (old profile)"],
    ["FURY_DW"]   = L["Fury: Raid (Dual Wield)"],
    ["FURY_2H"]   = L["Fury: Raid (Two-Hander)"],
    ["PROT_RAID"] = L["Protection: Raid"],
    ["DEEP_PROT"] = L["Protection: Raid (old profile)"],
    ["PROT_AOE"]  = L["Protection: AoE Farming"],
    ["ARMS_PVP"]  = L["PvP: Arms (Mortal Strike)"],
    ["ARMS_FARM"] = L["Arms: Two-Hander AoE Farming"],

    ["Leveling_1_10"] = Band("Leveling", 1, 10),
}
-- One name per leveling role; each level band gets "(lo-hi)" added.
local ROLE_NAMES = {
    { "Leveling",             "Arms: Solo Leveling" },
    { "Leveling_ArmsDungeon", "Arms: Dungeon Leveling" },
    { "Leveling_DW",          "Fury: Dual Wield Leveling" },
    { "Leveling_Tank",        "Protection: Solo Leveling" },
    { "Leveling_TankDungeon", "Protection: Dungeon Leveling" },
}
for _, r in ipairs(ROLE_NAMES) do
    for _, b in ipairs({ { 11, 20 }, { 21, 40 }, { 41, 51 }, { 52, 59 } }) do
        Warrior.PrettyNames[r[1] .. "_" .. b[1] .. "_" .. b[2]] = Band(r[2], b[1], b[2])
    end
end

-- =============================================================
-- TALENTS (keys used by GetSpec and ApplyScalers -> Forever talent names)
-- =============================================================
Warrior.Talents = {
    -- Arms
    ["DEFLECTION"]       = MSC.L["Deflection"],               -- t1, +1%/rank parry
    ["DEEP_WOUNDS"]      = MSC.L["Deep Wounds"],              -- t3, bleed of 20%/rank of average weapon damage on crits
    ["SPEARING_STRIKE"]  = MSC.L["Spearing Strike"],          -- t4, 40% weapon damage every 20 s
    ["TWOH_SPEC"]        = MSC.L["Two-Handed Weapon Specialization"], -- t4, +1%/rank two-handed damage
    ["IMPALE"]           = MSC.L["Impale"],                   -- t4, +10%/rank ability crit bonus
    ["BLOODTHRILL"]      = MSC.L["Bloodthrill"],              -- t5, 4%/rank Overpower on main-hand hits while Rend is up
    ["WEAPONMASTER"]     = MSC.L["Weaponmaster"],             -- t5, per-weapon-type bonus (see GetWeaponmasterBonus)
    ["IMP_SLAM"]         = MSC.L["Improved Slam"],            -- t6
    ["MORTAL_STRIKE"]    = MSC.L["Mortal Strike"],            -- t7 (level 40)
    ["ANGER_MANAGEMENT"] = MSC.L["Anger Management"],         -- t3, +1 rage per 3 s in combat
    -- Fury
    ["CRUELTY"]          = MSC.L["Cruelty"],                  -- t1, +1%/rank crit
    ["UNBRIDLED_WRATH"]  = MSC.L["Unbridled Wrath"],          -- t2, 12%/rank +1 rage on a landed white hit (any weapon)
    ["BLOOD_CRAZE"]      = MSC.L["Blood Craze"],              -- t3, health back after a crit taken
    ["DW_SPEC"]          = MSC.L["Dual Wield Specialization"], -- t4, +5%/rank off-hand damage (no hit since 70291)
    ["RAGING_BLOWS"]     = MSC.L["Raging Blows"],             -- t4, Whirlwind strikes with the off-hand too
    ["ENRAGE"]           = MSC.L["Enrage"],                   -- t4, +2%/rank Physical damage after being hit
    ["FLURRY"]           = MSC.L["Flurry"],                   -- t6, +5%/rank attack speed after a crit
    ["BLOODTHIRST"]      = MSC.L["Bloodthirst"],              -- t7 (level 40)
    -- Protection
    ["SHIELD_SPEC"]      = MSC.L["Shield Specialization"],    -- t1, +1%/rank block, rage on block
    ["ANTICIPATION"]     = MSC.L["Anticipation"],             -- t2, +4/rank Defense
    ["LAST_STAND"]       = MSC.L["Last Stand"],               -- t3
    ["MASTER_OF_DEFENSE"] = MSC.L["Master of Defense"],       -- t3, rage on dodge/parry with a shield
    ["IMP_REVENGE"]      = MSC.L["Improved Revenge"],         -- t3
    ["DEFIANCE"]         = MSC.L["Defiance"],                 -- t3, +5%/rank threat in Defensive Stance with a shield
    ["BASTION"]          = MSC.L["Bastion"],                  -- t6, +2%/rank damage with a shield
    ["SHIELD_SLAM"]      = MSC.L["Shield Slam"],              -- t7 (level 40)
}

-- =============================================================
-- LOGIC
-- =============================================================
Warrior.ValidWeapons = {
    [0]=true, [1]=true,   -- 1H/2H Axes
    [4]=true, [5]=true,   -- 1H/2H Maces
    [7]=true, [8]=true,   -- 1H/2H Swords
    [6]=true,             -- Polearms
    [10]=true,            -- Staves
    [13]=true, [15]=true, -- Fists, Daggers
    [2]=true, [3]=true, [18]=true, [16]=true -- Bow, Gun, Crossbow, Thrown
}

-- Leveling roles picked from talents (MSC:GetLowLevelRole). The Dungeon roles
-- have no markers (talents can't tell solo from group play), so they apply
-- only when chosen, e.g. by a Talents plugin build.
Warrior.LowLevelRoles = {
    Leveling_Tank        = { "SHIELD_SPEC", "ANTICIPATION", "MASTER_OF_DEFENSE", "IMP_REVENGE", "DEFIANCE", "LAST_STAND", "SHIELD_SLAM" },
    Leveling_ArmsDungeon = {},
    Leveling_TankDungeon = {},
}

-- A weapon in the off-hand (equipment changes clear the cached spec)
local function DualWielding()
    local offhand = GetInventoryItemLink("player", 17)
    return offhand and select(6, GetItemInfoInstant(offhand)) == 2
end

function Warrior:GetSpec()
    local function Rank(k) return MSC:GetTalentRank(k) end
    local level = UnitLevel("player")

    if level < 60 then
        -- Level 10 has its first talent point, so let roles apply from 10.
        if level < 10 then return "Leveling_1_10" end
        local suffix = (level <= 20 and "_11_20") or (level <= 40 and "_21_40") or (level <= 51 and "_41_51") or "_52_59"

        local role = MSC:GetLowLevelRole(Warrior.LowLevelRoles)
        if role and Warrior.LevelingWeights[role .. suffix] then return role .. suffix end
        if level == 10 then return "Leveling_1_10" end
        -- Fury's dual-wield talents, or no other role and a weapon in the off-hand
        -- (no low-tier talent marks dual wield; a Talents plugin Arms build keeps Arms)
        local forced = (MSC.GetBuildRole() or {}).leveling
        -- A build naming plain "Leveling" (the Fury DW raid build's leveling phase) still dual-wields
        -- when it has Dual Wield Specialization and an off-hand weapon.
        if (forced ~= "Leveling" and (Rank("DW_SPEC") > 0 or Rank("RAGING_BLOWS") > 0 or DualWielding()))
            or (Rank("DW_SPEC") > 0 and DualWielding()) then
            return "Leveling_DW" .. suffix
        end
        return "Leveling" .. suffix
    end

    -- Endgame: Shield Slam or a Protection-heavy build tanks; otherwise the
    -- signature talent, then the tree with the most points, decides.
    if Rank("SHIELD_SLAM") > 0 then return "PROT_RAID" end
    local arms, fury, prot = MSC.GetTabPointsSpent(1), MSC.GetTabPointsSpent(2), MSC.GetTabPointsSpent(3)
    if prot > arms and prot > fury then return "PROT_RAID" end
    if Rank("MORTAL_STRIKE") > 0 then return "ARMS_RAID" end
    if Rank("BLOODTHIRST") > 0 or fury > arms then return DualWielding() and "FURY_DW" or "FURY_2H" end
    return "ARMS_RAID"
end

function Warrior:ApplyScalers(weights, currentSpec)
    local function Rank(k) return MSC:GetTalentRank(k) end
    local activeCaps = {}

    local level = UnitLevel("player")
    local isLeveling = currentSpec:find("^Leveling") ~= nil
    local isDW = currentSpec:find("DW") ~= nil
    local isTank = (currentSpec:find("PROT") or currentSpec:find("Tank")) ~= nil
    local isLevelingTwoH = isLeveling and not isDW and not isTank
    -- Dungeon rows come from the group models with the build's talents in, so the
    -- hooks those models already cover are skipped for them.
    local tankModel = currentSpec:find("^Leveling_TankDungeon") ~= nil
    local groupDPS = currentSpec:find("^Leveling_ArmsDungeon") ~= nil
    local touched = {}
    local function Touch(k) if weights[k] then touched[k] = true end end
    local function Mul(k, m) if weights[k] then weights[k] = weights[k] * m; touched[k] = true end end
    local function Add(k, v) if weights[k] then weights[k] = weights[k] + v; touched[k] = true end end

    -- Deep Wounds (Arms t3, minLevel 20, 3 ranks): the bleed is 0.2 x rank of
    -- average WEAPON damage (no AP), so crit gets x(1 + 0.12 x rank) at all
    -- levels (Agility's crit share follows) and weapon DPS x(1 + 0.013 x rank).
    local rDeepWounds = Rank("DEEP_WOUNDS")
    if rDeepWounds > 0 and isLeveling and not tankModel then
        Touch("ITEM_MOD_CRIT_RATING_SHORT")
        MSC.ScaleForeverMeleeCrit(weights, 1 + 0.12 * rDeepWounds, level)
        Mul("MSC_WEAPON_DPS_MELEE", 1 + 0.013 * rDeepWounds)
    end

    -- Impale (Arms t4, 2 ranks): raises the crit bonus of yellow attacks only.
    -- x(1 + c x rank), c = 0.025 at 25-37, 0.035 at 38-47, 0.04 at 48+
    -- (Agility's crit share follows).
    local rImpale = Rank("IMPALE")
    if rImpale > 0 and isLeveling and not tankModel and weights["ITEM_MOD_CRIT_RATING_SHORT"] then
        Touch("ITEM_MOD_CRIT_RATING_SHORT")
        local c = (level >= 48 and 0.04) or (level >= 38 and 0.035) or 0.025
        MSC.ScaleForeverMeleeCrit(weights, 1 + c * rImpale, level)
    end

    -- Bastion (Prot t6, 5 ranks): +2%/rank damage while a shield is equipped
    -- (every Protection row assumes one). A flat damage multiplier: the safety
    -- keys divide by it so the whole damage family rises together.
    local armorBefore = weights["ITEM_MOD_ARMOR_SHORT"] -- for the useless-band floor below
    local rBastion = Rank("BASTION")
    if rBastion > 0 and isLeveling and isTank and not tankModel then
        MSC.ApplyForeverDamageMult(weights, 1 + rBastion * 0.02)
    end

    -- Two-Handed Weapon Specialization (Arms t4, 3 ranks): +1%/rank 2H melee
    -- damage, a flat multiplier for the two-hander leveling rows.
    local rTwoH = Rank("TWOH_SPEC")
    if rTwoH > 0 and isLevelingTwoH then
        MSC.ApplyForeverDamageMult(weights, 1 + rTwoH * 0.01)
    end

    -- Enrage (Fury t4, 5 ranks): 2% Physical damage per rank for 12 s after
    -- being hit (30% chance per hit; ~70% uptime on a pull) = a flat damage
    -- multiplier of 1 + 0.014 x rank. Solo DPS rows only (in a group the tank is hit).
    local rEnrage = Rank("ENRAGE")
    if rEnrage > 0 and isLeveling and not isTank and not groupDPS then
        MSC.ApplyForeverDamageMult(weights, 1 + 0.014 * rEnrage)
    end

    -- Damage-taken talents (solo DPS rows). Deflection (Arms t1, 5 ranks): +1%
    -- Parry removes ~1.25% of the hits that would land. Blood Craze (Fury t3,
    -- 3 ranks): 1% max HP over 6 s per crit taken, ~1.5% of the HP lost per
    -- kill per rank. Both cut the net HP lost per kill, so the keys that save or
    -- recover it shrink together. Stamina and Agility stay.
    local survive = 1
    if isLeveling and not isTank and not groupDPS then
        survive = (1 - 0.0125 * Rank("DEFLECTION")) * (1 - 0.015 * Rank("BLOOD_CRAZE"))
    end
    if survive < 1 then
        MSC.ScaleForeverKeys(weights, {
            "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_HEALTH_REGENERATION_SHORT", "ITEM_MOD_ARMOR_SHORT",
            "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_PARRY_RATING_SHORT",
        }, survive)
        -- Defense is a cap key the core fade (50-59) leaves alone, so this talent effect fades here
        MSC.ScaleForeverKeys(weights, { "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" }, 1 - (1 - survive) * MSC.LevelingHookShare(level))
    end

    -- Armor is kept just above the 0.02 "useless" band by the curve; the
    -- survival and damage multipliers must not push it under (it would score 0).
    if isLeveling and not isTank and armorBefore and armorBefore >= 0.02
        and weights["ITEM_MOD_ARMOR_SHORT"] and weights["ITEM_MOD_ARMOR_SHORT"] < 0.0201 then
        weights["ITEM_MOD_ARMOR_SHORT"] = 0.0201
    end

    -- Rage talents on a Mortal Strike build (the row's ability rate is
    -- rage-limited: Mortal Strike about 1 per 8 s = 0.125 of the 0.18/s).
    -- Total rage income ~6.9/s, so each +1 rage/s adds 14% rage and 0.7 x that
    -- to the speed weight.
    --   Anger Management (Arms t3, 1 rank): +1 rage per 3 s = +0.33/s.
    --   Unbridled Wrath (Fury t2, 5 ranks): 12%/rank on landed white hits,
    --   1 rage for every weapon (the 2H bonus was dropped; forever-bugs #105)
    --   (0.6 / 3.5 s = 0.17/s at 5/5).
    -- Below 40 abilities are cooldown-limited, so no change there.
    if isLevelingTwoH and level >= 40 and Rank("MORTAL_STRIKE") > 0 and weights["MSC_WEAPON_SPEED"] then
        local extra = 0.33 * Rank("ANGER_MANAGEMENT") + 0.17 * math.min(1, 0.2 * Rank("UNBRIDLED_WRATH"))
        if extra > 0 then Mul("MSC_WEAPON_SPEED", 1 + 0.7 * extra / 6.9) end
    end

    -- Mortal Strike speed gate (Arms t7, level 40, 1 rank): the 40-59 anchors
    -- assume Mortal Strike. Without it weapon speed is worth ~1/3 (Overpower +
    -- Slam 0.06/s against 0.18/s with MS). Leveling 2H rows only.
    local noMS2H = isLevelingTwoH and Rank("MORTAL_STRIKE") == 0
    if noMS2H and level >= 40 then
        Mul("MSC_WEAPON_SPEED", 0.33)
    end

    -- Speed hooks below only apply while Mortal Strike is missing (with it the
    -- anchors already cover them). D = typical 2H weapon DPS by level (0 below 25).
    if noMS2H and weights["MSC_WEAPON_SPEED"] then
        local D = 0
        if level >= 25 then
            D = MSC.ForeverLevelLerp({ {25, 19}, {30, 22.8}, {35, 27.3}, {39, 31.7} }, level)
        end

        -- Spearing Strike (Arms t4, level 25, 1 rank): 40% weapon damage about
        -- every 20 s, +0.22 x D.
        if Rank("SPEARING_STRIKE") > 0 then Add("MSC_WEAPON_SPEED", 0.22 * D) end

        -- Bloodthrill (Arms t5, level 30, 5 ranks): +4%/rank Overpower chance
        -- on hit, +0.09 x D per rank.
        local rBT = Rank("BLOODTHRILL")
        if rBT > 0 then Add("MSC_WEAPON_SPEED", 0.09 * D * rBT) end

        -- Improved Slam (Arms t6, level 35, 2 ranks): shorter Slam cooldown,
        -- +0.05 x D per rank.
        local rIS = Rank("IMP_SLAM")
        if rIS > 0 then Add("MSC_WEAPON_SPEED", 0.05 * D * rIS) end
    end

    -- Bloodthirst (Fury t7, level 40): the dual-wield rows from 40 assume it,
    -- and its damage (45% of attack power, nothing from the weapon) lowers
    -- what weapon DPS is worth. A dual-wielder without it keeps the pre-40
    -- value: the model's 10.6 AP per main-hand DPS against the rows' 6.2 at
    -- 40 and 5.5 from 45 (SimStudio wmodel, 2026-10-13).
    if isLeveling and isDW and level >= 40 and Rank("BLOODTHIRST") == 0 then
        local noBT = MSC.ForeverLevelLerp({ { 40, 1.71 }, { 45, 1.93 }, { 59, 1.93 } }, level)
        Mul("MSC_WEAPON_DPS_MELEE", noBT)
        Mul("MSC_WEAPON_DPS_OH", noBT)
    end

    -- Dual Wield Specialization (Fury t4, minLevel 25, 5 ranks): +5%/rank
    -- off-hand damage. Dual-wield leveling rows only.
    local rDWSpec = Rank("DW_SPEC")
    if rDWSpec > 0 and isLeveling and isDW then
        Mul("MSC_WEAPON_DPS_OH", 1 + 0.05 * rDWSpec)
    end

    -- Flurry (Fury t6, 5 ranks): the DW rows bake 5/5 as melee crit x1.25,
    -- ramped one rank per level from 35 to 40. Undo the baked part a player
    -- does not have. Scaling crit also moves Agility's crit share.
    local rFlurry = Rank("FLURRY")
    if isLeveling and isDW and level >= 36 and rFlurry < 5 then
        local baked = 1 + 0.05 * math.min(5, math.max(0, level - 35))
        MSC.ScaleForeverMeleeCrit(weights, (1 + 0.05 * rFlurry) / baked, level)
    end

    -- Raging Blows (Fury t4, level 25, 1 rank; effective from 36): Whirlwind
    -- strikes with the off-hand, so off-hand speed is worth something:
    -- 0 at 36, 3 at 40, 5.5 at 45-50, 6.5 at 59. DW leveling rows only.
    if Rank("RAGING_BLOWS") > 0 and isLeveling and isDW and level >= 36 and weights["MSC_OH_WEAPON_SPEED"] ~= nil then
        weights["MSC_OH_WEAPON_SPEED"] = MSC.ForeverLevelLerp({ {36, 0}, {40, 3}, {45, 5.5}, {50, 5.5}, {59, 6.5} }, level)
        touched["MSC_OH_WEAPON_SPEED"] = true
    end

    -- Shield Slam (Prot t7, level 40, 1 rank): each Block Value point adds 1
    -- damage to a Slam about every 7 s = +2.2 AP (Strength +0.11), and Slam
    -- is ~half of tank damage so crit and hit are worth x1.6 against AP.
    -- Solo tank rows only (the dungeon tank model and the raid profile include it).
    if Rank("SHIELD_SLAM") > 0 and isLeveling and isTank and not tankModel then
        Add("ITEM_MOD_BLOCK_VALUE_SHORT", 2.2)
        Add("ITEM_MOD_STRENGTH_SHORT", 0.11)
        Touch("ITEM_MOD_CRIT_RATING_SHORT")
        MSC.ScaleForeverMeleeCrit(weights, 1.6, level)
        -- a talent multiplier on hit, not a cap: fades 50-59 like the other hooks (MSC.LevelingHookShare)
        Mul("ITEM_MOD_HIT_RATING_SHORT", 1 + 0.6 * MSC.LevelingHookShare(level))
    end

    -- Keep talent-touched weights out of the (0, 0.02) "useless" band.
    for k in pairs(touched) do
        local v = weights[k]
        if v and v > 0 and v < 0.02 then weights[k] = 0 end
    end

    -- [[ 1. HIT CAP ]]
    -- Hit % comes from MSC:GetForeverHitPercent (gear rating + any hit talent
    -- in the game's number; Warriors have none since client 70291, when
    -- Precision was removed and Dual Wield Specialization lost its hit). The
    -- target is the level's cap, sliding to the raid cap from 50 (MSC.ForeverCaps).
    if weights["ITEM_MOD_HIT_RATING_SHORT"] then
        if currentSpec:find("DW") then
            -- Dual wield: past the yellow cap Hit keeps cutting white-swing
            -- misses (60% value) up to the DW white cap, then 5%
            MSC.ApplyForeverHitKnees(weights, "ITEM_MOD_HIT_RATING_SHORT", "MELEE", {
                { cap = MSC.GetForeverCapTarget("MELEE"), mult = 0.6 },
                { cap = MSC.GetForeverCapTarget("DW_WHITE"), mult = 0.05 },
            }, "Yellow Hit", activeCaps)
        else
            -- 2H/tank: single-wield white swings see no benefit past the yellow cap
            MSC.ApplyForeverHitCap(weights, "ITEM_MOD_HIT_RATING_SHORT", "MELEE", 0.1, "Yellow Hit", activeCaps)
        end
    end

    -- [[ 1b. TANK CAPS: defense toward 440, uncrushable (from 50) ]]
    -- Not for AoE farming: normal mobs can't crush, and the pack sets its own needs.
    if isTank and currentSpec ~= "PROT_AOE" then
        MSC.ApplyForeverDefenseTarget(weights, activeCaps)
        -- Shield Block (learned at 16): +75% block chance for 2 attacks. Crushing blows come from mobs
        -- 3+ levels above you (dungeon bosses, raids), not from questing, so solo tank rows skip it.
        if currentSpec == "PROT_RAID" or currentSpec == "DEEP_PROT" or currentSpec:find("^Leveling_TankDungeon") then
            MSC.ApplyForeverUncrushable(weights, 75, activeCaps)
        end
    end
    -- Tanks hold a shield, so an off-hand weapon's DPS is worth nothing
    -- (without this it counted at half the main-hand weight).
    if isTank then weights["MSC_WEAPON_DPS_OH"] = 0 end

    return weights, (#activeCaps > 0 and table.concat(activeCaps, ", ") or nil)
end

-- Weaponmaster (New in Forever, Arms t5, 5 ranks): per-weapon-type bonus.
--   Axe/Polearm: +1%/rank Crit (same math as the racial weapon-crit bonuses).
--   Mace/Staff: 3%/rank armor ignored = rank x 0.011 x damage base.
--   Sword: rank x 0.007 x damage base (extra-attack proc chance).
-- Damage base is (AP + Battle Shout + 14 x weapon DPS) in AP equivalents; the
-- total-damage figure isn't available here, so it is approximated from the
-- item's own DPS and the player's unbuffed Attack Power (gear is judged
-- without buffs, Battle Shout included).
local function GetWeaponmasterBonus(itemLink, weights)
    local rWM = MSC:GetTalentRank("WEAPONMASTER")
    if rWM <= 0 or not itemLink or not weights then return 0 end

    local _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemLink)
    if classID ~= 2 or not subClassID then return 0 end

    if subClassID == 0 or subClassID == 1 or subClassID == 6 then -- Axes (0/1), Polearms (6)
        -- Crit weight is already "per 1%" (see MSC.GetForeverWeaponRacialBonus)
        return rWM * (weights["ITEM_MOD_CRIT_RATING_SHORT"] or 0) -- +1%/rank Crit
    end

    local perRank
    if subClassID == 4 or subClassID == 5 or subClassID == 10 then perRank = 0.011 -- Maces, Staves
    elseif subClassID == 7 or subClassID == 8 then perRank = 0.007 -- Swords
    else return 0 end

    local dps = 0
    local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    if getStats then
        local stats = getStats(itemLink)
        dps = (stats and stats["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]) or 0
    end
    local ap = MSC.CtxAttackPower()
    local apWeight = weights["ITEM_MOD_ATTACK_POWER_SHORT"] or 1
    return rWM * perRank * (ap + 14 * dps) * apWeight
end

function Warrior:GetWeaponBonus(itemLink, weights, slotId, specName, otherHandLink)
    return MSC.GetForeverWeaponRacialBonus(itemLink, weights, otherHandLink) + GetWeaponmasterBonus(itemLink, weights)
end

-- =============================================================
-- REGISTER
-- =============================================================
-- Retired hand-made profiles (2026-10-27 weight check): the old names point at sim profiles so a saved choice or an
-- alt's profile still works; MSC lists skip them (RetiredProfiles).
Warrior.Weights["Default"] = Warrior.Weights["ARMS_RAID"]
Warrior.RetiredProfiles = { Default = true }

Warrior.Profiles = {}
for k, v in pairs(Warrior.Weights) do Warrior.Profiles[k] = v end
for k, v in pairs(Warrior.LevelingWeights) do Warrior.Profiles[k] = v end

MSC.RegisterModule("WARRIOR", Warrior)
