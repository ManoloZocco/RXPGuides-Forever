if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local Shaman = {}
Shaman.Name = "SHAMAN"

-- =============================================================
-- WOW FOREVER STAT WEIGHTS (Beta Baseline)
-- =============================================================
-- Strength/Attack Power/Weapon DPS/Agility calibrated to real conversion
-- math (see Paladin.lua for the base derivation). Enhancement Shaman uses
-- the same 1x Strength + 1x Agility melee-AP formula as Rogue/Hunter (not
-- Warrior/Paladin's Strength-only 2:1), so both are weighted near AP's own
-- value, with Agility carrying an added Crit/Dodge premium. Weapon DPS =
-- 14x AP's weight.
Shaman.Weights = {
    -- The level-60 profiles (study/shaman2, 2026-10-03; Enhancement and Elemental re-run 2026-10-08 from SharpiesGearJudge-SimStudio),
    -- each worked out with its build's own talents, so ApplyScalers' talent hooks skip them. Hit and Crit per 1%.
    -- Enhancement: Raid (Enhancement 33 / Restoration 16 / Elemental 2, two-hander, Windfury; talents re-searched 2026-10-10)
    -- from the wowsims Forever simulator, at Attack Power 1.5 like the other melee profiles. The rotation casts Fire Nova
    -- as well as the shocks; Mana Tide Totem and Mindfulness ease the mana, so Mp5 counts less than before, while
    -- Intellect (Mental Dexterity) still counts a lot. Tidal Focus gives 5% melee hit, so with 5% from gear you sit over
    -- the 9% raid cap; Hit is the value below the cap (the hit cap logic takes it down past that). Spell Power counts
    -- through Flame Shock, Earth Shock, Fire Nova and Lightning Shield; Spell Hit / Crit are the spells'.
    ["ENH_RAID"] = { ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_STRENGTH_SHORT"]=3.3, ["ITEM_MOD_AGILITY_SHORT"]=1.86, ["ITEM_MOD_INTELLECT_SHORT"]=2.58, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=0.22, ["ITEM_MOD_SPELL_POWER_SHORT"]=1.55, ["ITEM_MOD_HIT_RATING_SHORT"]=42.2, ["ITEM_MOD_CRIT_RATING_SHORT"]=33.9, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=12.1, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=5.7, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=20.1, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=2.0 },
    -- Elemental: Raid (Elemental 31 / Enhancement 11 / Restoration 9) from the simulator, Spell Power 2.0. Elemental runs out
    -- of mana in Forever and drops to a lower Lightning Bolt rank, which is why Crit and Hit are worth far less than for the
    -- other casters. Nature and Fire damage split the Spell Power value by how much of the damage each school does.
    ["ELE_RAID"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_NATURE_DAMAGE_SHORT"]=1.37, ["ITEM_MOD_FIRE_DAMAGE_SHORT"]=0.61, ["ITEM_MOD_INTELLECT_SHORT"]=1.12, ["ITEM_MOD_SPIRIT_SHORT"]=0.56, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=1.58, ["ITEM_MOD_STAMINA_SHORT"]=0.1, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=17.2, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=12.4 },
    -- Restoration: Raid (Restoration 40 / Enhancement 11) from our healing model (the simulator can't heal), Healing 2.0.
    -- Water Shield gives 2% of your mana back on heal crits, so Crit is worth more than for other healers. Client 70291
    -- removed the shield's 15 s cooldown (a globe every 3.5 s, recast after 3): each extra globe now also costs recast
    -- time, so Crit comes down a little and the mana stats go up (study/shaman2/sheal.js, WS_MODE).
    -- Spell Power is the damage value only: an item's Spell Power also heals, and MSC.GetItemScore adds that at the
    -- Healing weight, so a raid healer's Spell Power weight is 0 (it was 2.0, which counted Spell Power twice).
    ["RESTO_RAID"] = { ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"]=2.0, ["ITEM_MOD_SPELL_POWER_SHORT"]=0.0, ["ITEM_MOD_INTELLECT_SHORT"]=2.4, ["ITEM_MOD_SPIRIT_SHORT"]=1.95, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=2.83, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=13.6, ["ITEM_MOD_STAMINA_SHORT"]=0.5 },

    -- TANK_FARM: from the farm model (SimStudio models/shared/farm_profiles.py, data/farm_weights.json: the SHAMAN_TANK_FARM build's
    -- talents at the main farm spot, mobs 3 levels below you, the farm gear set), 2026-10-25, re-run 2026-11-01. Also the level-60 weights
    -- for the Tank: Dungeon Leveling build (there is no raid tank profile).
    ["TANK_FARM"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_NATURE_DAMAGE_SHORT"]=2.0, ["ITEM_MOD_STRENGTH_SHORT"]=0.23, ["ITEM_MOD_AGILITY_SHORT"]=2.91, ["ITEM_MOD_ATTACK_POWER_SHORT"]=0.12, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=1.6, ["ITEM_MOD_STAMINA_SHORT"]=2.58, ["ITEM_MOD_INTELLECT_SHORT"]=3.38, ["ITEM_MOD_SPIRIT_SHORT"]=3.55, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=3.45, ["ITEM_MOD_HEALTH_REGENERATION_SHORT"]=2.14, ["ITEM_MOD_ARMOR_SHORT"]=0.51, ["ITEM_MOD_BLOCK_VALUE_SHORT"]=2.8, ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"]=6.4, ["ITEM_MOD_DODGE_RATING_SHORT"]=32.6, ["ITEM_MOD_PARRY_RATING_SHORT"]=32.6, ["ITEM_MOD_BLOCK_RATING_SHORT"]=31.1, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=4.0, ["ITEM_MOD_CRIT_RATING_SHORT"]=4.0 },

    -- Totem-support and hybrid profiles (not modelled).
    -- Healer Spell Crit 48 at Healing 20: 1% crit is worth ~2.4 Healing.

    -- ELE_FARM: from the farm model (SimStudio models/shared/farm_profiles.py, data/farm_weights.json: the SHAMAN_ELE_FARM build's
    -- talents at the main farm spot, mobs 3 levels below you, the farm gear set), 2026-10-25, re-run 2026-11-01.
    ["ELE_FARM"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_FIRE_DAMAGE_SHORT"]=1.51, ["ITEM_MOD_NATURE_DAMAGE_SHORT"]=0.49, ["ITEM_MOD_STAMINA_SHORT"]=1.76, ["ITEM_MOD_INTELLECT_SHORT"]=1.69, ["ITEM_MOD_SPIRIT_SHORT"]=2.33, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=1.75, ["ITEM_MOD_HEALTH_REGENERATION_SHORT"]=1.65, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=8.2 },
}
-- Old names, kept so a saved profile choice still works.
Shaman.Weights["ELE_PVE"] = Shaman.Weights["ELE_RAID"]
Shaman.Weights["ENH_STORMSTRIKE"] = Shaman.Weights["ENH_RAID"]
Shaman.Weights["RESTO_DEEP"] = Shaman.Weights["RESTO_RAID"]
-- PvP profiles: copies of the PvE profile each build plays like; the PvP model (Helpers 5.10) adds
-- Stamina, armor and burst on top and keeps hit at the player-vs-player caps.
Shaman.Weights["ELE_PVP"] = MSC.ForeverPvPFrom(Shaman.Weights["ELE_RAID"])
Shaman.Weights["RESTO_PVP"] = MSC.ForeverPvPFrom(Shaman.Weights["RESTO_RAID"])
-- The study-built level-60 profiles (talents already in): ApplyScalers' talent hooks skip these.
local SIM_PROFILES = { ELE_FARM = true, TANK_FARM = true, ENH_RAID = true, ELE_RAID = true, RESTO_RAID = true, ELE_PVE = true, ENH_STORMSTRIKE = true, RESTO_DEEP = true, ELE_PVP = true, RESTO_PVP = true }
-- With Gear for PvP on, auto-detect shows the PvP profile in place of the raid one
-- (same weights plus the PvP model; MSC:ApplyDynamicAdjustments).
Shaman.PvPCounterpart = { ELE_RAID = "ELE_PVP", ELE_PVE = "ELE_PVP", RESTO_RAID = "RESTO_PVP", RESTO_DEEP = "RESTO_PVP" }

-- =============================================================
-- LEVELING WEIGHTS
-- =============================================================
-- Filled at load from Classes/Forever/Curves/Shaman_Curves.lua (generated by
-- SimStudio from smodel / emodel / sheal; don't edit it by hand) by Curves_Attach.lua: one row per role and level band,
-- blended by level in MSC:GetLevelingRow. Roles:
--   Leveling                Enhancement: Solo Leveling (two-hander, Rockbiter; the default)
--   Leveling_Dungeon        Enhancement: Dungeon Leveling
--   Leveling_Caster         Elemental: Leveling
--   Leveling_CasterDungeon  Elemental: Dungeon Leveling (2026-10-23)
--   Leveling_Healer         Restoration: Leveling
--   Leveling_HealerDungeon  Restoration: Dungeon Leveling
--   Leveling_Tank           Tank: Dungeon Leveling (one-hander and shield, Rockbiter with Spirit Weapons; also the farming build's leveling)
Shaman.LevelingWeights = {}

-- =============================================================
-- DISPLAY NAMES (match the Talents plugin's builds; translated in Locales/*.lua)
-- =============================================================
local L = MSC.L
local function Band(label, lo, hi) return L[label] .. " (" .. lo .. "-" .. hi .. ")" end
Shaman.PrettyNames = {
    ["ENH_RAID"]        = L["Enhancement: Raid"],
    ["ELE_RAID"]        = L["Elemental: Raid"],
    ["RESTO_RAID"]      = L["Restoration: Raid"],
    ["TANK_FARM"]       = L["Tank: AoE Farming"],
    ["ENH_STORMSTRIKE"] = L["Enhancement: Raid (old profile)"],
    ["ELE_PVE"]         = L["Elemental: Raid (old profile)"],
    ["RESTO_DEEP"]      = L["Restoration: Raid (old profile)"],
    ["ELE_PVP"]             = L["PvP: Elemental (Burst)"],
    ["RESTO_PVP"]           = L["PvP: Restoration Healer"],
    ["ELE_FARM"] = L["Elemental: AoE Farming"],

    ["Leveling_1_10"] = Band("Leveling", 1, 10),
}
-- One name per leveling role; each level band gets "(lo-hi)" added.
local ROLE_NAMES = {
    { "Leveling",               "Enhancement: Solo Leveling" },
    { "Leveling_Dungeon",       "Enhancement: Dungeon Leveling" },
    { "Leveling_Caster",        "Elemental: Leveling" },
    { "Leveling_CasterDungeon", "Elemental: Dungeon Leveling" },
    { "Leveling_Healer",        "Restoration: Leveling" },
    { "Leveling_HealerDungeon", "Restoration: Dungeon Leveling" },
    { "Leveling_Tank",          "Tank: Dungeon Leveling" },
}
for _, r in ipairs(ROLE_NAMES) do
    for _, b in ipairs({ { 11, 20 }, { 21, 40 }, { 41, 51 }, { 52, 59 } }) do
        Shaman.PrettyNames[r[1] .. "_" .. b[1] .. "_" .. b[2]] = Band(r[2], b[1], b[2])
    end
end

-- =============================================================
-- WOW FOREVER TALENTS
-- =============================================================
Shaman.Talents = { 
    ["LAVA_BURST"]        = MSC.L["Lava Burst"],
    ["STORMSTRIKE"]       = MSC.L["Stormstrike"],
    ["RIPTIDE"]           = MSC.L["Riptide"],
    ["NATURES_SWIFTNESS"] = MSC.L["Nature's Swiftness"],
    ["ELEMENTAL_ALACRITY"]= MSC.L["Elemental Alacrity"], -- Elemental t2 (2026-10-15 reshuffle)
    ["TRIAL_BY_FIRE"]     = MSC.L["Trial by Fire"], -- Elemental (was Improved Fire Nova)
    ["LIGHTNING_OVERLOAD"]= MSC.L["Lightning Overload"], -- Elemental
    ["ELEMENTAL_MASTERY"] = MSC.L["Elemental Mastery"], -- Elemental t7 (31 points, 2026-10-15)
    ["FLURRY"]            = MSC.L["Flurry"],
    ["RESTORATIVE_TOTEMS"]= MSC.L["Restorative Totems"],
    ["EYE_OF_STORM"]      = MSC.L["Eye of the Storm"],
    ["ANCESTRAL_KNOW"]    = MSC.L["Ancestral Knowledge"],
    ["TIDAL_FOCUS"]       = MSC.L["Tidal Focus"],
    ["ELEMENTAL_FURY"]    = MSC.L["Elemental Fury"], -- Elemental t6 (was t3 before the 2026-09-24 beta build)
    ["SPIRIT_WEAPONS"]    = MSC.L["Spirit Weapons"],
    ["ANTICIPATION"]      = MSC.L["Anticipation"],
    ["TIDAL_MASTERY"]     = MSC.L["Tidal Mastery"],
    ["TOUGHNESS"]         = MSC.L["Toughness"],
    ["MENTAL_DEXTERITY"]  = MSC.L["Mental Dexterity"],
    ["MENTAL_QUICKNESS"]  = MSC.L["Mental Quickness"],
    ["RAGE_FARSEER"]      = MSC.L["Rage of the Farseer"],
    ["WATER_SHIELD"]      = MSC.L["Water Shield"],
    ["CONCUSSION"]        = MSC.L["Concussion"], -- Elemental t1, 5 ranks, +1%/rank Lightning Bolt/Chain Lightning/Earth Shock damage
    ["PURIFICATION"]      = MSC.L["Purification"], -- Restoration t6, 5 ranks, +2%/rank universal healing (Same as Classic)
    ["HEALING_WAY"]       = MSC.L["Healing Way"], -- Restoration t5, 3 ranks, +8%/rank Healing Wave healing
    ["IMP_HEALING_WAVE"]  = MSC.L["Improved Healing Wave"], -- Restoration t1, 5 ranks
    ["MINDFULNESS"]       = MSC.L["Mindfulness"], -- New in Forever, Restoration t2, 3 ranks, mana regen while casting
    ["ANCESTRAL_HEALING"] = MSC.L["Ancestral Healing"], -- Restoration t3, 3 ranks
    ["HEALING_FOCUS"]     = MSC.L["Healing Focus"], -- Restoration t3, 3 ranks
    ["CONVECTION"]        = MSC.L["Convection"], -- Elemental t1, 5 ranks
    ["CALL_OF_FLAME"]     = MSC.L["Call of Flame"], -- Elemental t2, 3 ranks
    ["REVERBERATION"]     = MSC.L["Reverberation"], -- Elemental t2, 5 ranks
    ["ELEMENTAL_FOCUS"]   = MSC.L["Elemental Focus"], -- Elemental t3, 1 rank
    ["SHAMANISTIC_FOCUS"] = MSC.L["Shamanistic Focus"], -- Enhancement t3, 1 rank, shock and Lightning Shield mana -45%
    ["IMPROVED_STORMSTRIKE"] = MSC.L["Improved Stormstrike"], -- Enhancement t5, 2 ranks (minLevel 30), new in Forever
}

-- Leveling role marker talents (see MSC:GetLowLevelRole). Anticipation (Enh
-- t3, +6% Dodge) is the only unambiguous tank talent (Toughness and Spirit
-- Weapons are Enhancement DPS picks too), so a tank Shaman is auto-detected
-- from level 20 (tier 3) -- pick the profile manually before that. Tank
-- detection lives in GetSpec (Anticipation plus a guard against a single
-- filler point), so the marker list here is empty.
Shaman.LowLevelRoles = {
    Leveling_Tank   = {},
    -- (Tidal Focus is left out: the Enhancement solo build takes it at 11, which made it read as a healer at 11-26)
    Leveling_Healer = { "IMP_HEALING_WAVE", "TIDAL_MASTERY", "MINDFULNESS", "ANCESTRAL_HEALING", "HEALING_FOCUS", "WATER_SHIELD" },
    Leveling_Caster = { "CONVECTION", "CONCUSSION", "CALL_OF_FLAME", "REVERBERATION", "ELEMENTAL_FOCUS", "ELEMENTAL_ALACRITY", "ELEMENTAL_FURY",
        "LAVA_BURST", "TRIAL_BY_FIRE", "EYE_OF_STORM", "LIGHTNING_OVERLOAD", "ELEMENTAL_MASTERY" },
    Leveling_CasterDungeon = {},
    -- No markers (talents can't tell solo from group play): applies only when chosen, e.g. by a Talents plugin build.
    Leveling_Dungeon = {},
    Leveling_HealerDungeon = {},
}

-- =============================================================
-- LOGIC
-- =============================================================
Shaman.ValidWeapons = {
    -- Per the Forever client's SkillRaceClassInfo table: 2H axes and maces
    -- are Shaman skills (the old talent is gone, the skills are not);
    -- polearms are not. Shields are armor, so they never pass through this
    -- list (weapon subclass 6 is Polearms).
    [0]=true, [1]=true,   -- 1H/2H Axes
    [4]=true, [5]=true,   -- 1H/2H Maces
    [10]=true,            -- Staves
    [13]=true, [15]=true, -- Fists, Daggers
}

function Shaman:GetSpec()
    local function Rank(k) return MSC:GetTalentRank(k) end
    local level = UnitLevel("player")
    
    -- Leveling Bracket Logic
    if level < 60 then
        local suffix = ""
        if level <= 10 then suffix = "_1_10"
        elseif level <= 20 then suffix = "_11_20"
        elseif level <= 40 then suffix = "_21_40"
        elseif level <= 51 then suffix = "_41_51"
        else suffix = "_52_59" end
        
        -- A Talents plugin build names its role; it wins over the talent checks below.
        local forced = (MSC.GetBuildRole() or {}).leveling
        if forced and (forced == "Leveling" or Shaman.LowLevelRoles[forced]) and level >= 10 then
            local fs = (level == 10 and forced ~= "Leveling") and "_11_20" or suffix
            if Shaman.LevelingWeights[forced .. fs] then return forced .. fs end
        end

        -- Detect Roles
        local role = "Leveling" -- Default Enh
        -- Tank needs Anticipation (a lone filler point is only believable
        -- below 25), backed by a second point, Toughness 3+ or Spirit Weapons.
        local rAnti = Rank("ANTICIPATION")
        local isTank = rAnti >= 1 and (level <= 24 or rAnti >= 2 or Rank("TOUGHNESS") >= 3 or Rank("SPIRIT_WEAPONS") > 0)
        if isTank then role = "Leveling_Tank"
        elseif Rank("ELEMENTAL_FURY") > 0 or Rank("LAVA_BURST") > 0 then role = "Leveling_Caster"   -- Lava Burst is tier 5 (30) since the 10-15 reshuffle
        -- Stormstrike keeps Enhancement builds that take the Elemental shock talents (Convection, Call of Flame,
        -- Reverberation) on the Enhancement weights
        elseif Rank("STORMSTRIKE") > 0 then role = "Leveling"
        elseif Rank("WATER_SHIELD") > 0 then role = "Leveling_Healer"
        elseif level >= 10 then role = MSC:GetLowLevelRole(Shaman.LowLevelRoles) or role
        end
        if role == "Leveling_Dungeon" then role = "Leveling" end
        if role == "Leveling_HealerDungeon" then role = "Leveling_Healer" end
        if role == "Leveling_CasterDungeon" then role = "Leveling_Caster" end
        
        -- Level 10 brings the first talent point: a role it marks uses that
        -- role's 11-20 row (the 1-10 band only has the default row).
        if level == 10 and role ~= "Leveling" then suffix = "_11_20" end
        local key = role .. suffix
        if Shaman.LevelingWeights[key] then return key end
        return "Leveling" .. suffix
    end

    -- Endgame: Lava Burst (Elemental; full Eye of the Storm is the PvP build, the raid build takes 2 as filler), Riptide
    -- (Restoration), Rage of the Farseer (Enhancement), a shield tank, the hybrids, Stormstrike, then the tree with the most points.
    if Rank("LAVA_BURST") > 0 then
        if Rank("EYE_OF_STORM") >= 3 then return "ELE_PVP" end
        return "ELE_RAID"
    end
    if Rank("RIPTIDE") > 0 then return "RESTO_RAID" end
    -- shield tank (Anticipation with Spirit Weapons): the farming weights (no raid tank profile); before Rage of the Farseer,
    -- which the tank build takes too (2026-10-23: it returned ENH_RAID)
    if Rank("ANTICIPATION") >= 2 and Rank("SPIRIT_WEAPONS") > 0 then return "TANK_FARM" end
    if Rank("RAGE_FARSEER") > 0 then return "ENH_RAID" end
    if Rank("STORMSTRIKE") > 0 then return "ENH_RAID" end
    local ele, enh, resto = MSC.GetTabPointsSpent(1), MSC.GetTabPointsSpent(2), MSC.GetTabPointsSpent(3)
    if ele > enh and ele >= resto then return "ELE_RAID" end
    if enh > resto then return "ENH_RAID" end
    return "RESTO_RAID"
end

function Shaman:ApplyScalers(weights, currentSpec)
    local function Rank(k) return MSC:GetTalentRank(k) end
    local activeCaps = {}
    -- The study-built level-60 profiles already carry their talents: the talent hooks skip them (the hit cap still applies).
    local hooks = not SIM_PROFILES[currentSpec or ""]
    local level = UnitLevel("player") or 1
    local isTank   = currentSpec:find("Leveling_Tank") ~= nil
    local isCaster = currentSpec:find("Leveling_Caster") ~= nil
    local isHealer = currentSpec:find("Leveling_Healer") ~= nil
    local isEnh    = currentSpec:find("^Leveling") ~= nil and not (isTank or isCaster or isHealer)
    local Lerp = MSC.ForeverLevelLerp
    local Scale = MSC.ScaleForeverKeys
    local INT, SPI, MP5 = "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT"
    local SPELLDMG = { "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_NATURE_DAMAGE_SHORT", "ITEM_MOD_FIRE_DAMAGE_SHORT" }

    -- [[ 0. Enhancement/Tank rows bake Stormstrike, Shamanistic Focus and Flurry ]]
    -- Rows assume the talents that the anchors were built with; these undo them
    -- when the point is missing (factors from the per-level model).
    if isEnh or isTank then
        if Rank("STORMSTRIKE") == 0 then
            if isEnh and level >= 25 then
                Scale(weights, { INT }, Lerp({ {25,0.53}, {30,0.56}, {35,0.56}, {40,0.60}, {45,0.63}, {50,0.64}, {55,0.62}, {59,0.61} }, level))
                Scale(weights, { SPI }, 0.77)
                Scale(weights, { MP5 }, 0.85)
                Scale(weights, SPELLDMG, 1.22)
                MSC.ScaleForeverMeleeCrit(weights, 1.13, level)
                Scale(weights, { "ITEM_MOD_HIT_RATING_SHORT" }, 1.07)
                if weights["MSC_WEAPON_SPEED"] then weights["MSC_WEAPON_SPEED"] = 0 end
            elseif isTank and level >= 25 then
                if weights["MSC_WEAPON_SPEED"] then weights["MSC_WEAPON_SPEED"] = 0 end
                Scale(weights, { "ITEM_MOD_SPELL_POWER_SHORT" }, 1.18)
                MSC.ScaleForeverMeleeCrit(weights, 1.06, level)
                Scale(weights, { "ITEM_MOD_HIT_RATING_SHORT" }, 1.07)
                Scale(weights, { INT }, Lerp({ {25,0.45}, {35,0.48}, {40,0.76}, {59,0.83} }, level))
                Scale(weights, { SPI }, Lerp({ {25,0.70}, {35,0.72}, {40,0.86}, {59,0.88} }, level))
                Scale(weights, { MP5 }, Lerp({ {35,0.80}, {40,1.07} }, level))
            end
        end

        if Rank("SHAMANISTIC_FOCUS") == 0 then
            if isEnh and level >= 20 then
                Scale(weights, { INT }, Lerp({ {20,1.31}, {25,1.20}, {30,1.23}, {59,1.31} }, level))
                Scale(weights, { SPI }, Lerp({ {20,1.07}, {59,1.14} }, level))
            elseif isTank and level >= 23 then
                Scale(weights, { INT }, Lerp({ {25,1.22}, {40,1.25}, {45,1.27}, {59,1.30} }, level))
                Scale(weights, { SPI }, Lerp({ {25,1.10}, {59,1.15} }, level))
                Scale(weights, { MP5 }, 0.97)
            end
        end

        -- Flurry: rows bake 5/5 (generic crit x1.40 at 30 easing to x1.37
        -- at 59 as geared crit rises; ramped one rank per level 26-30; from
        -- SimStudio smodel, 2026-10-13 -- the study had x1.29 to x1.24).
        -- Undo the baked part the player lacks. Scaling melee crit also
        -- moves Agility's crit share, so no separate Agility factor.
        local rFlurry = Rank("FLURRY")
        if isEnh and level >= 26 and rFlurry < 5 then
            local full = Lerp({ {30, 1.40}, {35, 1.41}, {40, 1.39}, {50, 1.38}, {59, 1.37} }, level)
            local baked = 1 + (full - 1) * math.min(1, math.max(0, (level - 25) / 5))
            MSC.ScaleForeverMeleeCrit(weights, (1 + 0.05 * rFlurry) / baked, level)
            if rFlurry == 0 and weights["MSC_WEAPON_SPEED"] then
                weights["MSC_WEAPON_SPEED"] = weights["MSC_WEAPON_SPEED"] * 0.95
            end
        end

        -- Improved Stormstrike (Enhancement t5), Enhancement rows: the rows do
        -- not bake it. Its 50% mana regen while casting (15 sec after each
        -- Stormstrike, about every 8 sec, so full uptime at 2/2) lifts Spirit
        -- only, since Mp5 already works in combat -- the same factor as the
        -- tank hook below (x1.62 at 2/2, x1.31 at 1/2). The dodge/parry reset
        -- is worth under 1% damage per 1% dodge for a DPS Shaman, so it is skipped.
        local rImpSSEnh = Rank("IMPROVED_STORMSTRIKE")
        if isEnh and rImpSSEnh > 0 and level >= 30 then
            local uptime = 1 - (1 - 0.5 * math.min(rImpSSEnh, 2)) ^ 1.9
            Scale(weights, { SPI }, 1 + 0.62 * uptime)
        end

        for _, k in ipairs({ INT, SPI, MP5, "MSC_WEAPON_SPEED" }) do
            if weights[k] and weights[k] > 0 and weights[k] < 0.02 then weights[k] = 0 end
        end
    end

    local rAK = Rank("ANCESTRAL_KNOW")
    if hooks and rAK > 0 and weights["ITEM_MOD_INTELLECT_SHORT"] then
        weights["ITEM_MOD_INTELLECT_SHORT"] = weights["ITEM_MOD_INTELLECT_SHORT"] * (1 + (rAK * 0.02))
    end

    local rTough = Rank("TOUGHNESS")
    if hooks and rTough > 0 then
        Scale(weights, { "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_HEALTH_SHORT" }, 1 + (rTough * 0.02))
    end

    local rMD = Rank("MENTAL_DEXTERITY")
    if hooks and rMD > 0 and weights["ITEM_MOD_INTELLECT_SHORT"] and (weights["ITEM_MOD_ATTACK_POWER_SHORT"] or 0) > 0 then
        -- 33/67/100% of Intellect as attack power (client curve; the leveling rows' model leaves it out for this hook)
        weights["ITEM_MOD_INTELLECT_SHORT"] = weights["ITEM_MOD_INTELLECT_SHORT"] + (weights["ITEM_MOD_ATTACK_POWER_SHORT"] * ({ 0.33, 0.67, 1.0 })[math.min(3, rMD)])
    end

    -- Mental Quickness: the Forever text is the rank-1 value (15% of Intellect
    -- per rank). Healer rows count healing plus the damage half.
    local rMQ = Rank("MENTAL_QUICKNESS")
    if hooks and rMQ > 0 and weights["ITEM_MOD_INTELLECT_SHORT"] then
        local spWeight
        if isHealer then
            spWeight = (weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or 0) + (weights["ITEM_MOD_SPELL_POWER_SHORT"] or 0)
        else
            spWeight = weights["ITEM_MOD_SPELL_POWER_SHORT"] or weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or weights["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"] or 0
        end
        if spWeight > 0 then
            weights["ITEM_MOD_INTELLECT_SHORT"] = weights["ITEM_MOD_INTELLECT_SHORT"] + (spWeight * (rMQ * 0.15))
        end
    end

    -- Elemental Fury (Elemental t6 since the 2026-09-24 beta build, 5 ranks): same phrasing/math as Mage's
    -- Arcane Mind -- relative growth of the crit damage bonus, 1+rank*0.20,
    -- reaching 2.0x at 5/5 (matches real Classic Elemental Fury exactly)
    local rEleFury = Rank("ELEMENTAL_FURY")
    if hooks and rEleFury > 0 and (currentSpec:find("ELE") or currentSpec:find("Caster")) and weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] then
        weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] = weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] * (1 + (rEleFury * 0.20))
    end

    -- Concussion (Elemental t1, 5 ranks): +1%/rank Lightning Bolt/Chain
    -- Lightning/Earth Shock damage -- the core Elemental rotation
    -- Leveling_Caster rows skip it: a flat x1.05 on SP wrongly devalues the
    -- mana stats and hit/crit next to Spell Power (the modelled shift is <1%).
    local rConcussion = Rank("CONCUSSION")
    if hooks and rConcussion > 0 and not isCaster and (currentSpec:find("ELE") or currentSpec:find("Caster")) and weights["ITEM_MOD_SPELL_POWER_SHORT"] then
        weights["ITEM_MOD_SPELL_POWER_SHORT"] = weights["ITEM_MOD_SPELL_POWER_SHORT"] * (1 + (rConcussion * 0.01))
    end

    -- Mindfulness (Restoration t2, 3 ranks): 17% of mana regen continues
    -- while casting per rank, which lifts Spirit only (Mp5 already works in
    -- combat): x1.63 at 3/3.
    local rMind = Rank("MINDFULNESS")
    if isCaster and rMind > 0 and weights["ITEM_MOD_SPIRIT_SHORT"] then
        weights["ITEM_MOD_SPIRIT_SHORT"] = weights["ITEM_MOD_SPIRIT_SHORT"] * (1 + (0.21 * rMind))
    end
    -- Healer rows bake Mindfulness into Spirit (1 rank at 15, 3/3 from 20,
    -- x1.143 per rank). Rescale to the rank actually held, so a healer
    -- without it is not credited the baked regen (same relative form as
    -- the Druid Reflection and Paladin Reverence hooks).
    if isHealer and weights["ITEM_MOD_SPIRIT_SHORT"] then
        local bMind = Lerp({ {10, 0}, {15, 1}, {20, 3} }, level)
        if rMind ~= bMind then
            Scale(weights, { "ITEM_MOD_SPIRIT_SHORT" }, (1 + 0.143 * rMind) / (1 + 0.143 * bMind))
        end
    end

    -- Lava Burst (Elemental t5 since the 10-15 reshuffle, learnable at 30): rows from 40 assume it; without it the
    -- school split falls back to the level-35 one.
    if isCaster and level >= 40 and Rank("LAVA_BURST") == 0 then
        Scale(weights, { "ITEM_MOD_NATURE_DAMAGE_SHORT" }, 1.36)
        Scale(weights, { "ITEM_MOD_FIRE_DAMAGE_SHORT" }, 0.44)
    end

    -- Purification (Restoration t6, 5 ranks, Same as Classic): +2%/rank
    -- universal healing done
    local rPurify = Rank("PURIFICATION")
    -- Healing Way (Restoration t5, 3 ranks): +8%/rank Healing Wave healing --
    -- the dominant Resto heal, so treated like a broad healing-done scaler
    local rHealWay = Rank("HEALING_WAY")
    if isHealer then
        -- Leveling healer rows: one group-side factor m. Healing Way only
        -- lifts Healing Wave (share sHW of healing done), so healing power
        -- gains the full m while Int, Spirit, Mp5 and crit gain their shares.
        if rPurify > 0 or rHealWay > 0 then
            local sHW = (level < 20) and 1.0 or ((level <= 35) and 0.68 or 0.33)
            local m = (1 + 0.02 * rPurify) * (1 + 0.08 * rHealWay * sHW)
            Scale(weights, { "ITEM_MOD_SPELL_HEALING_DONE_SHORT" }, m)
            Scale(weights, { INT }, 1 + 0.40 * (m - 1))
            Scale(weights, { SPI }, 1 + 0.85 * (m - 1))
            Scale(weights, { MP5 }, 1 + 0.82 * (m - 1))
            MSC.ScaleForeverSpellCrit(weights, 1 + 0.65 * (m - 1), level)
        end
    elseif hooks then
        if rPurify > 0 and currentSpec:find("RESTO") and weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] then
            weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] * (1 + (rPurify * 0.02))
        end
        if rHealWay > 0 and currentSpec:find("RESTO") and weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] then
            weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] * (1 + (rHealWay * 0.08))
        end
    end

    -- [[ 1. Hit Caps ]]
    -- Forever Shamans have no Dual Wield, so melee uses the single-weapon cap.
    -- Tidal Focus (+1% hit, all attacks) is already in the game's hit numbers
    -- read by MSC:GetForeverHitPercent, so it isn't added again. Targets are
    -- the level's caps, sliding to the raid caps from 50.
    MSC.ApplyForeverHitCap(weights, "ITEM_MOD_HIT_RATING_SHORT", "MELEE", 0.1, "Phys Hit", activeCaps)
    MSC.ApplyForeverHitCap(weights, "ITEM_MOD_HIT_SPELL_RATING_SHORT", "SPELL", 0.1, "Spell Hit", activeCaps, nil, MSC.ForeverSpellCapKind(currentSpec))

    -- [[ 1a. Healer: spell hit (rows carry no Hit weight) ]]
    -- Full value while 1% or more short of the spell cap, fractional inside
    -- the last 1%. Total hit already counts Tidal Focus through the game's
    -- spell hit modifier; the rank is only added if the modifier reads 0.
    -- Solo healers only: they nuke while questing; a dungeon healer row is healing-only (pheal model).
    if isHealer and not currentSpec:find("Dungeon") then
        local total, _, mod = MSC:GetForeverHitPercent("SPELL")
        if (mod or 0) == 0 then total = total + Rank("TIDAL_FOCUS") end
        local cap = MSC.GetForeverCapTarget(MSC.ForeverSpellCapKind(currentSpec) or "SPELL", level) or 4   -- dungeon rows: 5.5%
        local hitBase = Lerp({ {10,1.8}, {15,2.9}, {20,5.1}, {30,5.2}, {35,6.5}, {40,8.7}, {45,8.9}, {50,11.7}, {55,13.5}, {59,14.9} }, level)
        local hitW = hitBase * math.min(1, math.max(0, cap - total))
        if hitW < 0.02 then hitW = 0 end
        weights["ITEM_MOD_HIT_SPELL_RATING_SHORT"] = hitW
    end

    -- [[ 1b. Tank: defense toward 440, uncrushable (from 50) ]]
    -- Shield tanks like Warriors and Paladins, but with no active block
    -- ability, so only passive block counts toward uncrushable.
    -- (upper-cased: the level-60 farm profile is TANK_FARM, the leveling rows Leveling_Tank)
    local specU = currentSpec:upper()
    if specU:find("TANK") then
        -- AoE farming has no defense target (normal mobs can't crush), as for Warriors and Paladins
        if not specU:find("FARM") then
            MSC.ApplyForeverDefenseTarget(weights, activeCaps)
            MSC.ApplyForeverUncrushable(weights, 0, activeCaps)
        end

        -- Spirit Weapons (Enhancement t5): without it a Shaman cannot parry.
        if Rank("SPIRIT_WEAPONS") == 0 and weights["ITEM_MOD_PARRY_RATING_SHORT"] then
            weights["ITEM_MOD_PARRY_RATING_SHORT"] = 0
        end

        -- Improved Stormstrike (Enhancement t5, 2 ranks): 50% per rank (the
        -- client spell holds the max-rank 100%) that Stormstrike's cooldown
        -- resets on a dodge or parry, and that Stormstrike grants 50% mana
        -- regen while casting for 15 sec. The table is the value of a 50%
        -- reset chance per 1% avoidance; at 2/2 the chance doubles.
        local rImpSS = Rank("IMPROVED_STORMSTRIKE")
        if rImpSS > 0 and level >= 30 then
            -- Stormstrike about every 8 sec against a 15 sec buff.
            local uptime = 1 - (1 - 0.5 * math.min(rImpSS, 2)) ^ 1.9
            Scale(weights, { "ITEM_MOD_SPIRIT_SHORT" }, 1 + 0.62 * uptime)
            local add = math.min(rImpSS, 2) * Lerp({ {30,1.9}, {35,2.3}, {40,2.5}, {45,3.2}, {50,3.3}, {55,3.7}, {59,4.0} }, level)
            for _, k in ipairs({ "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_PARRY_RATING_SHORT" }) do
                if weights[k] and (k ~= "ITEM_MOD_PARRY_RATING_SHORT" or Rank("SPIRIT_WEAPONS") > 0) then
                    weights[k] = weights[k] + add
                end
            end
        end
    end

    -- [[ 2. Weapon Skill Cap (Removed in Forever) ]]
    return weights, (#activeCaps > 0 and table.concat(activeCaps, ", ") or nil)
end

function Shaman:GetWeaponBonus(itemLink, weights, slotId, specName, otherHandLink)
    return MSC.GetForeverWeaponRacialBonus(itemLink, weights, otherHandLink)
end

function Shaman:GetRelicBonus(itemID, currentSpec)
    return MSC.GetForeverRelicBonus(Shaman.Relics, itemID, currentSpec)
end

-- =============================================================
-- TOTEMS
-- Wiped for the beta (2026-09-21): these were real TBC Totem item IDs. TBC
-- content isn't part of Forever, so this starts blank and repopulates
-- organically with confirmed Forever Totem IDs, same as the ProcDB/TrinketDB
-- cleanup above.
-- =============================================================
-- Forever totems as equivalent stats per spec (MSC.GetForeverRelicBonus).
-- role: "melee" (Enhancement), "tank", "caster" (Elemental), "healer".
-- castShare = the part of a fight spent casting (Elemental/Resto ~0.7,
-- Enhancement/tank ~0.3). Small effects are estimates.
local function ShamanCastShare(role) return (role == "caster" or role == "healer") and 0.7 or 0.3 end
Shaman.Relics = {
    -- Windcarved Effigy: Lightning Bolt costs 5 less. An Elemental leveler
    -- casts about one Lightning Bolt every 6 sec of play: ~4 Mp5.
    [263412] = function(role) return { ITEM_MOD_MANA_REGENERATION_SHORT = (role == "caster") and 4 or 0.8 } end,
    -- Firestorm Totem: totem mana cost -5%
    [263436] = function() return { ITEM_MOD_MANA_REGENERATION_SHORT = 0.5 } end,
    -- Polished Driftwood Icon: 8% of mana regen continues while casting
    [249398] = function(role, ctx)
        return { ITEM_MOD_MANA_REGENERATION_SHORT = 0.08 * ctx.spiritRegen5 * ShamanCastShare(role) }
    end,
    -- Totem of Ancestral Protection: Grounding Totem cooldown -1 sec (PvP)
    [249443] = function() return {} end,
    -- Tidal Totem: Healing Wave mana cost -5%
    [272431] = function(role) return (role == "healer") and { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } or {} end,
    -- Totem of the Storm: Lightning Bolt can trigger Maelstrom Weapon (50% chance)
    [272432] = function(role)
        if role == "caster" then return { ITEM_MOD_SPELL_POWER_SHORT = 8 } end
        if role == "melee" then return { ITEM_MOD_ATTACK_POWER_SHORT = 8 } end
        return {}
    end,
    -- Burning Totem: Flame Shock +3 sec
    [272433] = function(role)
        if role == "caster" then return { ITEM_MOD_SPELL_POWER_SHORT = 5 } end
        if role == "melee" or role == "tank" then return { ITEM_MOD_ATTACK_POWER_SHORT = 5 } end
        return {}
    end,
    -- Totem of Urgency: Lesser Healing Wave crit +4%
    [279249] = function(role) return (role == "healer") and { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } or {} end,

    -- Unchanged Classic totems (Wowhead Classic data). Single-spell bonuses
    -- count at that spell's share of the spec's healing/damage/mana use.
    -- Totem of Rebirth: Reincarnation cooldown -10 min (no score value)
    [22345] = function() return {} end,
    -- Totem of Rage: Earth/Flame/Frost Shock deal up to 30 more (~25% of an
    -- Enhancement Shaman's spell damage, ~20% of an Elemental's)
    [22395] = function(role)
        if role == "caster" then return { ITEM_MOD_SPELL_POWER_SHORT = 6 } end
        if role == "melee" or role == "tank" then return { ITEM_MOD_SPELL_POWER_SHORT = 7.5 } end
        return {}
    end,
    -- Totem of Life: Lesser Healing Wave heals up to 80 more (~50% of healing)
    [22396] = function(role) return (role == "healer") and { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 40 } or {} end,
    -- Totem of Flowing Water: up to 10 mana back per Lesser Healing Wave
    [23005] = function(role) return (role == "healer") and { ITEM_MOD_MANA_REGENERATION_SHORT = 4 } or {} end,
    -- Totem of the Storm (Classic): Lightning Bolt and Chain Lightning deal up
    -- to 33 more (~60% of Elemental damage)
    [23199] = function(role)
        if role == "caster" then return { ITEM_MOD_SPELL_POWER_SHORT = 20 } end
        if role == "melee" then return { ITEM_MOD_SPELL_POWER_SHORT = 5 } end
        return {}
    end,
    -- Totem of Sustaining: Lesser Healing Wave heals up to 53 more
    [23200] = function(role) return (role == "healer") and { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 26 } or {} end,
}

-- Retired hand-made profiles (2026-10-27 weight check): the old names point at sim profiles so a saved choice or an
-- alt's profile still works; MSC lists skip them (RetiredProfiles).
Shaman.Weights["Default"] = Shaman.Weights["ENH_RAID"]
Shaman.Weights["RESTO_TOTEM_SUPPORT"] = Shaman.Weights["RESTO_RAID"]
Shaman.Weights["HYBRID_ELE_RESTO"] = Shaman.Weights["ELE_RAID"]
Shaman.Weights["HYBRID_ENH_RESTO"] = Shaman.Weights["ENH_RAID"]
Shaman.RetiredProfiles = { Default = true, RESTO_TOTEM_SUPPORT = true, HYBRID_ELE_RESTO = true, HYBRID_ENH_RESTO = true }
-- A saved retired name scores as the sim profile it points at, so the talent hooks skip it too.
for k in pairs(Shaman.RetiredProfiles) do SIM_PROFILES[k] = true end

MSC.RegisterModule("SHAMAN", Shaman)


