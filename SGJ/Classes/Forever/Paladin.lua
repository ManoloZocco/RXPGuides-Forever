if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local Paladin = {}
Paladin.Name = "PALADIN"

-- =============================================================
-- LEVEL-60 WEIGHTS
-- =============================================================
-- Hit, Crit, Dodge, Parry and Block weights are per 1%; Defense per skill
-- point; the rest per point. Within a profile, Strength = 2x Attack Power and
-- Weapon DPS = 14x Attack Power (bonus damage per swing is AP / 14 x speed).
-- The model-built profiles come from the Research folder (study/ret_build,
-- 2026-10-03; NOTES.md there has the numbers behind each one).
Paladin.Weights = {
    -- Fallback before a spec is known. Stamina, Hit, Crit and Weapon Skill on the same scale as the
    -- other Forever Defaults (Stamina 0.5, Hit 20 / Crit 12 per 1%, Weapon Skill 13).

    -- Retribution: Raid (Ret 33 / Holy 18 with Twist of Light, pre-raid gear) from the wowsims Forever simulator (study/paladin3,
    -- 2026-10-03), 70% raid boss / 30% dungeon boss, Attack Power 1.5. The rotation seal-twists: Seal of Righteousness up before
    -- each swing, then Seal of Command, so every swing carries both seals (Twist of Light's Echo). That makes white hits count
    -- double, so Hit and Crit lead. Built with the build's talents (Divine Strength, Divine Intellect, Champion of the Light):
    -- ApplyScalers' talent hooks skip this profile.
    ["RET_STANDARD"] = { ["ITEM_MOD_HIT_RATING_SHORT"]=52.4, ["ITEM_MOD_CRIT_RATING_SHORT"]=43.1, ["ITEM_MOD_STRENGTH_SHORT"]=3.51, ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_AGILITY_SHORT"]=2.42, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=20.7, ["ITEM_MOD_SPELL_POWER_SHORT"]=2.93, ["ITEM_MOD_HOLY_DAMAGE_SHORT"]=2.93, ["ITEM_MOD_INTELLECT_SHORT"]=2.13, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=0.1, ["ITEM_MOD_SPIRIT_SHORT"]=0.0, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=4.3, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=2.4, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=2.0 },

    -- Holy: Raid (pre-raid healer, raid buffs, long / potion / burst fights). Downranking allowed: Forever
    -- gives every rank the full coefficient (a mild cut is assumed for ranks 10+ levels below you). A
    -- Paladin healer runs short of mana before casting time, so Intellect and Mp5 rank above +healing.
    -- Spell Power is the damage value only: an item's Spell Power also heals, and MSC.GetItemScore adds that at the
    -- Healing weight, so a raid healer's Spell Power weight is 0 (it was 2.0, which counted Spell Power twice).
    ["HOLY_RAID"] = { ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=25.6, ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"]=2.0, ["ITEM_MOD_SPELL_POWER_SHORT"]=0.0, ["ITEM_MOD_INTELLECT_SHORT"]=2.7, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=3.7, ["ITEM_MOD_SPIRIT_SHORT"]=1.5, ["ITEM_MOD_STAMINA_SHORT"]=0.5 },

    -- Protection: Raid (Vanguard talents, level-63 boss) from the wowsims Forever simulator's tank mode (study/paladin3,
    -- 2026-10-04; re-run 2026-10-10 after the Reckoning fix), as the Warrior's and Druid's raid tanks: threat 35% / damage
    -- taken 35% / effective health 30%, Stamina 3.0. Dodge and Parry lead; Block only takes Block Value off each big boss hit,
    -- so it and Block Value count for less, though each block can also give Reckoning's free extra swing (an instant attack
    -- that leaves the swing timer alone and procs seals; since the 15 Oct patch up to 4 are stored and released on the next
    -- melee hit, at most one trigger every 1.5 s).
    -- Threat is half Holy (Spell Power) and half melee (Hit, Crit). A 3-minute boss never runs a tank dry, so Intellect and
    -- Mp5 keep only a small floor for longer fights.
    ["PROT_DEEP"] = { ["ITEM_MOD_STAMINA_SHORT"]=3.0, ["ITEM_MOD_DODGE_RATING_SHORT"]=18.1, ["ITEM_MOD_PARRY_RATING_SHORT"]=19.1, ["ITEM_MOD_BLOCK_RATING_SHORT"]=7.4, ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"]=3.03, ["ITEM_MOD_ARMOR_SHORT"]=0.19, ["ITEM_MOD_BLOCK_VALUE_SHORT"]=1.0, ["ITEM_MOD_AGILITY_SHORT"]=1.76, ["ITEM_MOD_STRENGTH_SHORT"]=0.55, ["ITEM_MOD_ATTACK_POWER_SHORT"]=0.23, ["ITEM_MOD_SPELL_POWER_SHORT"]=1.19, ["ITEM_MOD_HOLY_DAMAGE_SHORT"]=1.19, ["ITEM_MOD_HIT_RATING_SHORT"]=16.0, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=5.8, ["ITEM_MOD_CRIT_RATING_SHORT"]=9.3, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=3.0, ["ITEM_MOD_INTELLECT_SHORT"]=1.33, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=1.15, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=1.0 },

    -- PROT_AOE: from the farm model (SimStudio models/shared/farm_profiles.py, data/farm_weights.json: the PALADIN_PROT_CONSECRATOR build's
    -- talents at the main farm spot, mobs 3 levels below you, the farm gear set), 2026-10-25, re-run 2026-11-01.
    ["PROT_AOE"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=3.0, ["ITEM_MOD_HOLY_DAMAGE_SHORT"]=3.0, ["ITEM_MOD_STRENGTH_SHORT"]=0.93, ["ITEM_MOD_AGILITY_SHORT"]=0.59, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=4.4, ["ITEM_MOD_STAMINA_SHORT"]=0.47, ["ITEM_MOD_INTELLECT_SHORT"]=3.94, ["ITEM_MOD_SPIRIT_SHORT"]=2.51, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=3.37, ["ITEM_MOD_ARMOR_SHORT"]=0.05, ["ITEM_MOD_BLOCK_VALUE_SHORT"]=8.5, ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"]=0.71, ["ITEM_MOD_DODGE_RATING_SHORT"]=3.0, ["ITEM_MOD_PARRY_RATING_SHORT"]=3.0, ["ITEM_MOD_BLOCK_RATING_SHORT"]=2.0, ["ITEM_MOD_HIT_RATING_SHORT"]=9.3, ["ITEM_MOD_CRIT_RATING_SHORT"]=8.0, ["ITEM_MOD_WEAPON_SKILL_RATING_SHORT"]=0.5 },


    -- RET_FARM: from the farm model (SimStudio models/shared/farm_profiles.py, data/farm_weights.json: the PALADIN_RET_FARM build's
    -- talents at the main farm spot, mobs 3 levels below you, the farm gear set), 2026-10-25, re-run 2026-11-01.
    ["RET_FARM"] = { ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_SPELL_POWER_SHORT"]=6.71, ["ITEM_MOD_HOLY_DAMAGE_SHORT"]=6.71, ["ITEM_MOD_STRENGTH_SHORT"]=3.0, ["ITEM_MOD_AGILITY_SHORT"]=3.31, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=19.1, ["ITEM_MOD_STAMINA_SHORT"]=2.76, ["ITEM_MOD_INTELLECT_SHORT"]=5.81, ["ITEM_MOD_SPIRIT_SHORT"]=8.32, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=9.1, ["ITEM_MOD_HEALTH_REGENERATION_SHORT"]=6.01, ["ITEM_MOD_HIT_RATING_SHORT"]=44.5, ["ITEM_MOD_CRIT_RATING_SHORT"]=37.4 },
}
-- PvP profiles: copies of the PvE profile each build plays like; the PvP model (Helpers 5.10) adds
-- Stamina, armor and burst on top and keeps hit at the player-vs-player caps.
-- Shockadin: Holy: Raid with Holy Shock's damage half counted (Spell Power and Holy damage as well as healing, Hit
-- for the damage). Retribution and Reck-Bomb: Ret: Raid (Reck-Bomb for builds with Reckoning and Vengeance: Forever's
-- Reckoning stores up to 4 extra attacks and releases them all on the next melee hit).
Paladin.Weights["SHOCKADIN"] = MSC.ForeverPvPFrom(Paladin.Weights["HOLY_RAID"], {
    ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"]=1.0, ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_HOLY_DAMAGE_SHORT"]=1.0,
    ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=12.0, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=20.0 })
Paladin.Weights["RECK_BOMB"] = MSC.ForeverPvPFrom(Paladin.Weights["RET_STANDARD"])
Paladin.Weights["RET_PVP"] = MSC.ForeverPvPFrom(Paladin.Weights["RET_STANDARD"])
-- PvP builds whose key doesn't say PvP (MSC.IsPvPProfile).
Paladin.PvPProfiles = { SHOCKADIN = true, RECK_BOMB = true }
-- Old name for Holy: Raid, kept so a saved profile choice still works.
Paladin.Weights["HOLY_DEEP"] = Paladin.Weights["HOLY_RAID"]
-- The simulator-built level-60 profiles (talents already in): ApplyScalers' talent hooks skip these.
local SIM_PROFILES = { RET_FARM = true, PROT_AOE = true, RET_STANDARD = true, PROT_DEEP = true, SHOCKADIN = true, RECK_BOMB = true, RET_PVP = true }
-- With Gear for PvP on, auto-detect shows the PvP profile in place of the raid one
-- (same weights plus the PvP model; MSC:ApplyDynamicAdjustments).
Paladin.PvPCounterpart = { RET_STANDARD = "RET_PVP" }

-- =============================================================
-- LEVELING WEIGHTS
-- =============================================================
-- Filled at load from Classes/Forever/Curves/Paladin_Curves.lua (generated from
-- the study; don't edit it by hand) by Curves_Attach.lua: one row per role and level band,
-- blended by level in MSC:GetLevelingRow. Roles:
--   Leveling                Retribution: Solo Leveling (the default)
--   Leveling_RetDungeon     Retribution: Dungeon Leveling
--   Leveling_Tank           Protection: Solo Leveling
--   Leveling_TankDungeon    Protection: Dungeon Leveling
--   Leveling_Healer         Shockadin: Solo Leveling
--   Leveling_HealerDungeon  Holy: Dungeon Leveling
Paladin.LevelingWeights = {}

-- The Retribution chain is named Leveling_Ret at 52-59 (see MSC:GetLevelingRow's blend).
Paladin.LevelingNext = { ["Leveling_41_51"] = "Leveling_Ret_52_59" }

-- =============================================================
-- DISPLAY NAMES (match the Talents plugin's builds; translated in Locales/*.lua)
-- =============================================================
local L = MSC.L
local function Band(label, lo, hi) return MSC.ClassL("PALADIN", label) .. " (" .. lo .. "-" .. hi .. ")" end
Paladin.PrettyNames = {
    ["RET_STANDARD"] = L["Retribution: Raid"],
    ["HOLY_RAID"]    = L["Holy: Raid"],
    ["HOLY_DEEP"]    = L["Holy: Raid (old profile)"],
    ["PROT_DEEP"]    = MSC.ClassL("PALADIN", "Protection: Raid"),
    ["PROT_AOE"]     = MSC.ClassL("PALADIN", "Protection: AoE Farming"),
    ["SHOCKADIN"]    = L["PvP: Shockadin (Burst)"],
    ["RECK_BOMB"]    = L["PvP: Reck-Bomb (One-Shot)"],
    ["RET_PVP"]      = L["PvP: Retribution"],
    ["RET_FARM"] = L["Retribution: AoE Farming"],

    ["Leveling_1_10"] = Band("Leveling", 1, 10),
}
-- One name per leveling role; each level band gets "(lo-hi)" added.
local ROLE_NAMES = {
    { "Leveling",               "Retribution: Solo Leveling" },
    { "Leveling_RetDungeon",    "Retribution: Dungeon Leveling" },
    { "Leveling_Tank",          "Protection: Solo Leveling" },
    { "Leveling_TankDungeon",   "Protection: Dungeon Leveling" },
    { "Leveling_Healer",        "Shockadin: Solo Leveling" },
    { "Leveling_HealerDungeon", "Holy: Dungeon Leveling" },
}
for _, r in ipairs(ROLE_NAMES) do
    for _, b in ipairs({ { 11, 20 }, { 21, 40 }, { 41, 51 }, { 52, 59 } }) do
        -- The Retribution chain's 52-59 row is named Leveling_Ret (see LevelingNext above)
        local role = (r[1] == "Leveling" and b[1] == 52) and "Leveling_Ret" or r[1]
        Paladin.PrettyNames[role .. "_" .. b[1] .. "_" .. b[2]] = Band(r[2], b[1], b[2])
    end
end

-- =============================================================
-- TALENTS (keys used by GetSpec and ApplyScalers -> Forever talent names)
-- =============================================================
Paladin.Talents = {
    -- Holy
    ["DIVINE_STR"]         = MSC.L["Divine Strength"],         -- t1, +2%/rank Strength
    ["DIVINE_INT"]         = MSC.L["Divine Intellect"],        -- t1, +2%/rank Intellect
    ["HEALING_LIGHT"]      = MSC.L["Healing Light"],           -- t2, +4%/rank Holy Light / Flash of Light / Holy Shock healing
    ["SPIRITUAL_FOCUS"]    = MSC.L["Spiritual Focus"],         -- t2, pushback protection
    ["REVERENCE"]          = MSC.L["Reverence"],               -- t2, 15%/rank mana regeneration while casting (2 ranks since the 2026-10-30 hotfix)
    ["ILLUMINATION"]       = MSC.L["Illumination"],            -- t4, mana back on heal crits
    ["DIVINE_FAVOR"]       = MSC.L["Divine Favor"],            -- t4
    ["INFUSION_LIGHT"]     = MSC.L["Infusion of Light"],       -- t4
    ["HOLY_SHOCK"]         = MSC.L["Holy Shock"],              -- t5
    ["LIGHTS_VIGIL"]       = MSC.L["Light's Vigil"],           -- t7 (level 40)
    -- Protection
    ["TOUGHNESS"]          = MSC.L["Toughness"],               -- t1, +2%/rank armor from items
    ["REDOUBT"]            = MSC.L["Redoubt"],                 -- t1, block chance after being hit
    ["PRECISION"]          = MSC.L["Precision"],               -- t2, +1%/rank hit
    ["ANTICIPATION"]       = MSC.L["Anticipation"],            -- t2, +4/rank Defense
    ["IMP_RIGHTEOUS_FURY"] = MSC.L["Improved Righteous Fury"], -- t4, -3%/rank damage taken (2026-10-30 hotfix; was 2%)
    ["SHIELD_SPEC"]        = MSC.L["Shield Specialization"],   -- t3, 2 ranks: Block Value +15%/rank and mana on block (50%/rank)
    ["SACRED_DUTY"]        = MSC.L["Sacred Duty"],             -- t2, cooldowns only (its Stamina went in the 2026-10-30 hotfix)
    ["RECKONING"]          = MSC.L["Reckoning"],               -- t5, extra attacks after blocks
    ["IRON_CREED"]         = MSC.L["Iron Creed"],              -- t6, 3 ranks: -2%/rank damage taken for 6 s after Holy Strike
    ["HOLY_SHIELD"]        = MSC.L["Holy Shield"],             -- t5 (level 30 since the 2026-10-30 hotfix; was t7, 40)
    -- Retribution
    ["BENEDICTION"]        = MSC.L["Benediction"],             -- t1, -2%/rank mana on instant spells
    ["HOLY_CONDUIT"]       = MSC.L["Holy Conduit"],            -- t2, -20%/rank Consecration / Holy Wrath / Exorcism / Hammer of Wrath mana
    ["SEAL_OF_COMMAND"]    = MSC.L["Seal of Command"],         -- t3 (level 20)
    ["REPENTANCE"]         = MSC.L["Repentance"],              -- t5
    ["TWOH_SPEC"]          = MSC.L["Two-Handed Weapon Specialization"], -- t5, +2%/rank two-handed damage
    ["VENGEANCE"]          = MSC.L["Vengeance"],               -- t5
    ["CHAMPION_LIGHT"]     = MSC.L["Champion of the Light"],   -- t6, 5 ranks: spell damage from 12%/rank of Intellect
}

-- =============================================================
-- LOGIC
-- =============================================================
Paladin.ValidWeapons = {
    [0]=true, [1]=true,   -- 1H/2H Axes
    [4]=true, [5]=true,   -- 1H/2H Maces
    [7]=true, [8]=true,   -- 1H/2H Swords
    [6]=true              -- Polearms
}

-- Leveling roles picked from talents (MSC:GetLowLevelRole). Divine Strength,
-- Divine Intellect and Reverence aren't Holy markers: Retribution builds take
-- them too. The Dungeon roles have no markers (talents can't tell solo from
-- group play), so they apply only when chosen, e.g. by a Talents plugin build.
Paladin.LowLevelRoles = {
    Leveling_Tank          = { "TOUGHNESS", "REDOUBT", "ANTICIPATION", "IMP_RIGHTEOUS_FURY", "SHIELD_SPEC", "SACRED_DUTY" },
    Leveling_Healer        = { "HEALING_LIGHT", "SPIRITUAL_FOCUS", "ILLUMINATION", "DIVINE_FAVOR", "INFUSION_LIGHT", "LIGHTS_VIGIL" },
    Leveling_RetDungeon    = {},
    Leveling_TankDungeon   = {},
    Leveling_HealerDungeon = {},
}

function Paladin:GetSpec()
    local function Rank(k) return MSC:GetTalentRank(k) end
    local level = UnitLevel("player")

    -- Leveling Check First
    if level < 60 then
        -- Level 10 has its first talent point, so let roles apply from 10.
        if level < 10 then return "Leveling_1_10" end
        local suffix = (level <= 20 and "_11_20") or (level <= 40 and "_21_40") or (level <= 51 and "_41_51") or "_52_59"

        local role = MSC:GetLowLevelRole(Paladin.LowLevelRoles)
        if role and Paladin.LevelingWeights[role .. suffix] then return role .. suffix end
        if level == 10 then return "Leveling_1_10" end
        if suffix == "_52_59" then return "Leveling_Ret_52_59" end
        return "Leveling" .. suffix
    end

    -- Endgame Spec Detection. Forever builds mix trees (a Ret 30 / Holy 21
    -- takes Holy Shock; Holy healers often skip Sacred Duty), so after the two
    -- signature talents the tree with the most points decides.
    if Rank("RECKONING") > 0 and Rank("VENGEANCE") > 0 then return "RECK_BOMB" end
    if Rank("HOLY_SHIELD") > 0 then return "PROT_DEEP" end
    local holy, prot, ret = MSC.GetTabPointsSpent(1), MSC.GetTabPointsSpent(2), MSC.GetTabPointsSpent(3)
    if ret > holy and ret >= prot then return "RET_STANDARD" end
    if prot > holy and prot > ret then return "PROT_DEEP" end
    -- Holy: a healer with any healing talent; Holy Shock without them is the PvP Shockadin.
    -- With Gear for PvP on, any Holy Shock build is the Shockadin (it takes Divine Favor and
    -- Light's Vigil for burst).
    if Rank("HOLY_SHOCK") > 0 and (MSC.IsGearingForPvP() or (Rank("ILLUMINATION") == 0 and Rank("LIGHTS_VIGIL") == 0
        and Rank("HEALING_LIGHT") == 0 and Rank("DIVINE_FAVOR") == 0)) then return "SHOCKADIN" end
    return "HOLY_RAID"
end

function Paladin:ApplyScalers(weights, currentSpec)
    local function Rank(k) return MSC:GetTalentRank(k) end
    local activeCaps = {}
    -- The simulator-built profiles already carry their talents: the talent hooks skip them (the hit cap still applies).
    local hooks = not SIM_PROFILES[currentSpec or ""]

    -- [[ 1. Divine Strength (+10% Str) ]]
    local rStr = Rank("DIVINE_STR")
    if hooks and rStr > 0 and weights["ITEM_MOD_STRENGTH_SHORT"] then
        weights["ITEM_MOD_STRENGTH_SHORT"] = weights["ITEM_MOD_STRENGTH_SHORT"] * (1 + (rStr * 0.02))
    end

    local rInt = Rank("DIVINE_INT")
    if hooks and rInt > 0 and weights["ITEM_MOD_INTELLECT_SHORT"] then
        weights["ITEM_MOD_INTELLECT_SHORT"] = weights["ITEM_MOD_INTELLECT_SHORT"] * (1 + (rInt * 0.02))
    end

    local rTough = Rank("TOUGHNESS")
    if hooks and rTough > 0 and weights["ITEM_MOD_ARMOR_SHORT"] then
        weights["ITEM_MOD_ARMOR_SHORT"] = weights["ITEM_MOD_ARMOR_SHORT"] * (1 + (rTough * 0.02))
    end

    -- Champion of the Light (Ret t6, 5 ranks since the 2026-10-30 hotfix): spell damage from 12% of Intellect a rank,
    -- 60% at the top as before (was 3 ranks of 20%), damage only.
    local rChamp = Rank("CHAMPION_LIGHT")
    if hooks and rChamp > 0 and weights["ITEM_MOD_INTELLECT_SHORT"] and (weights["ITEM_MOD_SPELL_POWER_SHORT"] or 0) > 0 then
        local spWeight = weights["ITEM_MOD_SPELL_POWER_SHORT"]
        weights["ITEM_MOD_INTELLECT_SHORT"] = weights["ITEM_MOD_INTELLECT_SHORT"] + (spWeight * (rChamp * 0.12))
    end

    -- Healing Light (Holy t2, 3 ranks): +4%/rank healing from Holy Light /
    -- Flash of Light / Holy Shock -- raises Spell Healing's value for Holy specs
    -- (endgame HOLY_* and the Leveling_Healer_* brackets)
    local rHealLight = Rank("HEALING_LIGHT")
    if rHealLight > 0 and (currentSpec:find("HOLY") or currentSpec:find("Healer")) and weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] then
        weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] * (1 + (rHealLight * 0.04))
    end

    -- [[ 1b. Leveling talent hooks ]]
    -- The study curves (Solo Leveling rows) bake few talents, so these hooks add
    -- the ones the player has. The Retribution and Protection Dungeon Leveling
    -- curves come from models run with their build's talents, so the hooks for
    -- talents those models already include are skipped there (modelRow).
    -- (The Holy Dungeon curve was built for these hooks, so they apply to it.)
    local level = UnitLevel("player")
    local isLeveling = currentSpec:find("^Leveling") ~= nil
    local isHealerRow = currentSpec:find("^Leveling_Healer") ~= nil
    local isTankRow = currentSpec:find("^Leveling_Tank") ~= nil
    local isRetRow = isLeveling and not isHealerRow and not isTankRow
    local modelRow = currentSpec:find("^Leveling_TankDungeon") ~= nil or currentSpec:find("^Leveling_RetDungeon") ~= nil

    -- Multiply a key when present; a weight left in (0, 0.02) is zeroed.
    local function Mul(k, m)
        local v = weights[k]
        if not v or m == 1 then return end
        v = v * m
        if v > 0 and v < 0.02 then v = 0 end
        weights[k] = v
    end
    local function MulAll(keys, m) for _, k in ipairs(keys) do Mul(k, m) end end

    if isRetRow then
        -- Seal of Command (Ret t3, level 20): without it the player stays on
        -- Seal of Righteousness, whose Holy damage is worth more than the
        -- anchor's Seal of Command model, and procs no longer crit.
        if level >= 20 and Rank("SEAL_OF_COMMAND") == 0 then
            MulAll({ "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_HOLY_DAMAGE_SHORT" }, 1.25)
            Mul("ITEM_MOD_CRIT_RATING_SHORT", 0.95)
            Mul("ITEM_MOD_AGILITY_SHORT", 0.96)
            Mul("ITEM_MOD_HIT_RATING_SHORT", 0.98)
        end

        -- Vengeance (Ret t5, level 30): +1%/rank damage per stack for 30 s after
        -- a crit, about +2.25% average per rank. A crit also starts the buff, so
        -- crit gains a further 2%/rank; Agility gets the crit part by its share.
        local rVeng = Rank("VENGEANCE")
        if rVeng > 0 and level >= 30 and not modelRow then
            local dmg = 1 + 0.0225 * rVeng
            MulAll({ "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
                     "MSC_WEAPON_DPS_MELEE", "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
                     "ITEM_MOD_HOLY_DAMAGE_SHORT", "MSC_WEAPON_SPEED" }, dmg)
            Mul("ITEM_MOD_CRIT_RATING_SHORT", dmg * (1 + 0.02 * rVeng))
            local critShare = (level >= 45) and 0.90 or 0.85
            Mul("ITEM_MOD_AGILITY_SHORT", 1 + 0.0225 * rVeng + 0.02 * rVeng * critShare)
        end

        -- Two-Handed Weapon Specialization (Ret t5, level 30): +2%/rank damage
        -- with a two-hander, about 1.3%/rank of total damage.
        local rTwoH = Rank("TWOH_SPEC")
        if rTwoH > 0 and not modelRow then
            local link = GetInventoryItemLink("player", 16)
            local equipLoc = link and select(9, GetItemInfo(link))
            if equipLoc == "INVTYPE_2HWEAPON" then
                MulAll({ "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
                         "MSC_WEAPON_DPS_MELEE", "MSC_WEAPON_SPEED" }, 1 + 0.013 * rTwoH)
            end
        end
    end

    if isHealerRow then
        -- Healing Light also raises the value of mana, regen and crit equally
        -- with healing power: scale their group-side share to match.
        local rHL = Rank("HEALING_LIGHT")
        if rHL > 0 then
            MulAll({ "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT",
                     "ITEM_MOD_SPELL_CRIT_RATING_SHORT" }, 1 + 0.032 * rHL)
        end

        -- Illumination (Holy t4, 5 ranks), relative to the ranks baked into the
        -- anchors: 0 at 20, 1 at 25, 5 from 30.
        local bIll = MSC.ForeverLevelLerp({ {20, 0}, {25, 1}, {30, 5} }, level)
        local rIll = Rank("ILLUMINATION")
        Mul("ITEM_MOD_SPELL_CRIT_RATING_SHORT", (0.61 + 0.39 * rIll / 5) / (0.61 + 0.39 * bIll / 5))
        Mul("ITEM_MOD_INTELLECT_SHORT", (0.91 + 0.09 * rIll / 5) / (0.91 + 0.09 * bIll / 5))

        -- Reverence (Holy t2): Spirit regenerates in combat only through it. In
        -- shares of regen kept while casting: baked 0 at 15, 10% at 20, 30% from
        -- 25; the player's 15% a rank (2 ranks since the 2026-10-30 hotfix, was 3
        -- of 10%). Intellect's mana part is worth about 4% more per missing 10% from 40.
        local bRev = MSC.ForeverLevelLerp({ {15, 0}, {20, 0.10}, {25, 0.30} }, level)
        local rRev = 0.15 * Rank("REVERENCE")
        Mul("ITEM_MOD_SPIRIT_SHORT", (0.30 + 0.7 * rRev) / (0.30 + 0.7 * bRev))
        if level >= 40 then Mul("ITEM_MOD_INTELLECT_SHORT", 1 + 0.4 * (bRev - rRev)) end
    end

    if isTankRow then
        -- Shield Specialization (Prot t3): anchors bake the full talent from 25
        -- (+30% Block Value, every block restoring mana); scale by the real rank,
        -- 2 ranks of 15% and a 50% chance since the 2026-10-30 hotfix (was 3 of
        -- 10% and 33%), so one rank now does what 1.5 old ranks did. Block Value is
        -- the absorb part, Intellect and Mp5 the mana-proc part. The block-rating
        -- part is handled in section 2b.
        local rSS = Rank("SHIELD_SPEC")
        if level >= 20 then
            Mul("ITEM_MOD_BLOCK_VALUE_SHORT", (1 + 0.15 * rSS) / 1.3)
            local intLow, intHigh = 0.74 + 0.129 * rSS, 0.66 + 0.17 * rSS
            Mul("ITEM_MOD_INTELLECT_SHORT", MSC.ForeverLevelLerp({ {35, intLow}, {40, intHigh} }, level))
            if level >= 25 and level <= 35 then
                Mul("ITEM_MOD_MANA_REGENERATION_SHORT", 1.2 - 0.1 * rSS)
            end
        end

        -- Holy Shield (Prot t5, level 30 since the 2026-10-30 hotfix; was 40):
        -- without it Block Value is worth far less and mana use is lower. The rows
        -- bake its +30% block (average block 0.05 -> 0.14), so without it BV
        -- x0.05/0.14 (with a little BV kept for Redoubt/gear block) and Int x0.55.
        if level >= 30 and Rank("HOLY_SHIELD") == 0 then
            Mul("ITEM_MOD_BLOCK_VALUE_SHORT", 0.33)
            Mul("ITEM_MOD_INTELLECT_SHORT", 0.55)
            MulAll({ "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
                     "ITEM_MOD_BLOCK_RATING_SHORT" }, 0.94)
        end

        -- Redoubt (Prot t1, 5 ranks): +2.34% block chance per rank on average
        -- (its proc gives 6%/rank since the 2026-10-30 hotfix, was 4%), against a
        -- baked average block of 0.05 below 30 and 0.14 from 30 (Holy Shield).
        local rRed = Rank("REDOUBT")
        if rRed > 0 and not modelRow then
            Mul("ITEM_MOD_BLOCK_VALUE_SHORT", 1 + ((level >= 30) and 0.165 or 0.465) * rRed)
        end

        -- Benediction (Ret t1, 5 ranks, -2%/rank mana on instant spells) and
        -- Holy Conduit (Ret t2, 2 ranks, -20%/rank on Consecration/Hammer of
        -- Wrath): the rows bake neither. Re-running the study model, 5 ranks of
        -- Benediction cut Intellect and Spirit by 6% (1.2%/rank) and Holy
        -- Conduit's 2 ranks by a further ~2.5% (1.2%/rank); Mp5 is unchanged,
        -- since rest time is paid per mana either way.
        local rMana = Rank("BENEDICTION") + Rank("HOLY_CONDUIT")
        if rMana > 0 and level >= 15 and not modelRow then
            MulAll({ "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT" }, 1 - 0.012 * rMana)
        end

        -- Reckoning (Prot t5, 5 ranks, not baked): 8%/rank chance of an extra
        -- attack after a block (the 20%-after-crit part is rare on a tank).
        -- Extra swings per swing = rank x 0.08 x blocks per mob hit x 1.5; at
        -- ~0.6 of damage from swings and Seal of Fury procs, the physical
        -- family gains about 0.07 x rank x block chance. Average block chance:
        -- 5% base, +9% Holy Shield uptime (from 30, 30% patch value), +2.34%
        -- per Redoubt rank (matching that hook).
        local rRk = Rank("RECKONING")
        if rRk > 0 and not modelRow then
            local avgBlock = 0.05 + ((level >= 30 and Rank("HOLY_SHIELD") > 0) and 0.09 or 0) + 0.0234 * Rank("REDOUBT")
            local rk = 1 + 0.07 * rRk * avgBlock
            MulAll({ "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
                     "MSC_WEAPON_DPS_MELEE", "ITEM_MOD_HIT_RATING_SHORT" }, rk)
            MSC.ScaleForeverMeleeCrit(weights, rk, level)
        end

        -- Improved Righteous Fury (Prot t4, 3 ranks): -3%/rank damage taken
        -- while Righteous Fury is up (2026-10-30 hotfix; was 2%); Iron Creed (Prot t6, 3 ranks): -2%/rank
        -- for 6 s after Holy Strike (10 s cooldown, 60% uptime = 1.2%/rank).
        -- The rows price no damage reduction, so the safety stats (Stamina,
        -- armor, avoidance, Block Value, Defense) rise by 1/(1 - reduction),
        -- done through the shared damage-multiplier helper.
        local dmgTaken = (1 - 0.03 * Rank("IMP_RIGHTEOUS_FURY")) * (1 - 0.012 * Rank("IRON_CREED"))
        if dmgTaken < 1 and not modelRow then MSC.ApplyForeverDamageMult(weights, dmgTaken) end
    end

    -- [[ 2. Hit Cap ]]
    -- Hit % includes Precision once (MSC:GetForeverHitPercent); the target is
    -- the level's cap, sliding to the raid cap from 50. Past it Hit keeps 10%
    -- of its value, the same as every other class.
    MSC.ApplyForeverHitCap(weights, "ITEM_MOD_HIT_RATING_SHORT", "MELEE", 0.1, "Hit", activeCaps)
    MSC.ApplyForeverHitCap(weights, "ITEM_MOD_HIT_SPELL_RATING_SHORT", "SPELL", 0.1, "Spell Hit", activeCaps, nil, MSC.ForeverSpellCapKind(currentSpec))

    -- [[ 2b. Block for leveling tanks: Shield Specialization ]]
    -- Shield Specialization makes blocks restore 4% of max mana (once per 3 sec)
    -- at 50% a rank since the 2026-10-30 hotfix (2 ranks; was 33% of 3). The
    -- leveling tank rows priced block as its survival value (about 0.6 x Dodge,
    -- like other tanks) plus a mana part hedged to two-thirds. So with 2/2 the
    -- mana part counts in full (x1.5), with 1/2 at half that, and without the
    -- talent block is worth its survival value only.
    if currentSpec:find("^Leveling_Tank") and not currentSpec:find("^Leveling_TankDungeon") then
        local block = weights["ITEM_MOD_BLOCK_RATING_SHORT"]
        local dodge = weights["ITEM_MOD_DODGE_RATING_SHORT"] or 0
        if block and block > 0 and dodge > 0 then
            local survival = math.min(block, 0.6 * dodge)
            local rSS2 = Rank("SHIELD_SPEC")
            if rSS2 > 0 then
                weights["ITEM_MOD_BLOCK_RATING_SHORT"] = survival + (block - survival) * 0.75 * math.min(2, rSS2)
            else
                weights["ITEM_MOD_BLOCK_RATING_SHORT"] = survival
            end
        end
    end

    -- [[ 3. Tank caps: defense toward 440, uncrushable (from 50) ]]
    -- Not for PROT_AOE: farming normal mobs at or below your level has no Defense target or crushing blows.
    if (currentSpec:find("PROT") and currentSpec ~= "PROT_AOE") or currentSpec:find("Tank") then
        MSC.ApplyForeverDefenseTarget(weights, activeCaps)
        -- Holy Shield (talent): +30% block chance while active (2 Oct patch, was 20%)
        MSC.ApplyForeverUncrushable(weights, (Rank("HOLY_SHIELD") > 0) and 30 or 0, activeCaps)
    end

    return weights, (#activeCaps > 0 and table.concat(activeCaps, ", ") or nil)
end

function Paladin:GetWeaponBonus(itemLink, weights, slotId, specName, otherHandLink)
    return MSC.GetForeverWeaponRacialBonus(itemLink, weights, otherHandLink)
end

function Paladin:GetRelicBonus(itemID, currentSpec)
    return MSC.GetForeverRelicBonus(Paladin.Relics, itemID, currentSpec)
end

-- =============================================================
-- LIBRAMS
-- =============================================================
-- Forever and unchanged Classic librams as equivalent stats per spec
-- (MSC.GetForeverRelicBonus). role: "melee" (Retribution), "tank", "healer".
-- Small cooldown/damage effects are estimates for the spec that uses them.
Paladin.Relics = {
    -- Tenets of the Silver Hand: +1% damage vs Undead. About a quarter of
    -- leveling kills are Undead, and weapon damage is about 2x AP-worth for
    -- a leveling Ret: ~0.25% of damage = 0.0075 x AP.
    [249397] = function(role, ctx) return (role ~= "healer") and { ITEM_MOD_ATTACK_POWER_SHORT = 0.0075 * ctx.ap } or {} end,
    -- Libram of Invocation: Seal mana cost -5% (a Seal every ~30 sec)
    [249442] = function(role) return { ITEM_MOD_MANA_REGENERATION_SHORT = (role == "healer") and 0.3 or 0.7 } end,
    -- Sentinel's Libram: Swift Judgement cooldown -10 sec
    [272434] = function(role) return (role == "melee") and { ITEM_MOD_ATTACK_POWER_SHORT = 6 } or {} end,
    -- Libram of Law: Judgement damage +4% (~10% of a Ret's damage; half
    -- that value as threat for a tank)
    [272435] = function(role, ctx)
        if role == "melee" then return { ITEM_MOD_ATTACK_POWER_SHORT = 0.012 * ctx.ap } end
        if role == "tank" then return { ITEM_MOD_ATTACK_POWER_SHORT = 0.006 * ctx.ap } end
        return {}
    end,
    -- Libram of Economy: Holy Light mana cost -5%
    [272436] = function(role) return { ITEM_MOD_MANA_REGENERATION_SHORT = (role == "healer") and 10 or 1 } end,
    -- Steadfast Libram: shield Block Value +30% while Holy Shield is up (~80%)
    [279247] = function(role, ctx)
        if role ~= "tank" or MSC:GetTalentRank("HOLY_SHIELD") <= 0 then return {} end
        return { ITEM_MOD_BLOCK_VALUE_SHORT = 0.24 * ctx.shieldBlock }
    end,
    -- Libram of Infusion: Holy Shock crit +6%
    [279248] = function(role)
        if MSC:GetTalentRank("HOLY_SHOCK") <= 0 then return {} end
        if role == "healer" then return { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12 } end
        return { ITEM_MOD_SPELL_POWER_SHORT = 10 }
    end,

    -- Unchanged Classic librams (Wowhead Classic data). Single-spell bonuses
    -- count at that spell's share of the spec's healing/damage/mana use.
    -- Libram of Truth: Devotion Aura +55 armor (tanks run it; others often don't)
    [22400] = function(role) return { ITEM_MOD_ARMOR_SHORT = (role == "tank") and 55 or 25 } end,
    -- Libram of Hope: Seal spells cost 20 less (a Seal every ~30 sec)
    [22401] = function(role) return { ITEM_MOD_MANA_REGENERATION_SHORT = (role == "healer") and 1 or 3.3 } end,
    -- Libram of Grace: Cleanse costs 25 less
    [22402] = function(role) return { ITEM_MOD_MANA_REGENERATION_SHORT = (role == "healer") and 1 or 0.3 } end,
    -- Libram of Light: Flash of Light heals up to 83 more (~60% of healing)
    [23006] = function(role) return (role == "healer") and { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 50 } or {} end,
    -- Libram of Divinity (both IDs): Flash of Light heals up to 53 more
    [23201] = function(role) return (role == "healer") and { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 32 } or {} end,
    [23202] = function(role) return (role == "healer") and { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 32 } or {} end,
    -- Libram of Fervor: Seal of the Crusader +48 AP and Judgement of the
    -- Crusader +33 Holy damage (only while running that Seal)
    [23203] = function(role)
        if role == "melee" then return { ITEM_MOD_ATTACK_POWER_SHORT = 30 } end
        if role == "tank" then return { ITEM_MOD_ATTACK_POWER_SHORT = 10 } end
        return {}
    end,
}

-- Profiles for the UI (leveling rows are listed from LevelingWeights once the curves load)
-- Retired hand-made profiles (2026-10-27 weight check): the old names point at sim profiles so a saved choice or an
-- alt's profile still works; MSC lists skip them (RetiredProfiles).
Paladin.Weights["Default"] = Paladin.Weights["RET_STANDARD"]
Paladin.RetiredProfiles = { Default = true }
-- A saved retired name scores as the sim profile it points at, so the talent hooks skip it too.
for k in pairs(Paladin.RetiredProfiles) do SIM_PROFILES[k] = true end

Paladin.Profiles = {}
for k, v in pairs(Paladin.Weights) do Paladin.Profiles[k] = v end

MSC.RegisterModule("PALADIN", Paladin)
