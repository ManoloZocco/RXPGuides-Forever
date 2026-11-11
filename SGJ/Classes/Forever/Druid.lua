if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local Druid = {}
Druid.Name = "DRUID"

-- =============================================================
-- WOW FOREVER STAT WEIGHTS (Beta Baseline)
-- =============================================================
Druid.Weights = {
    -- The level-60 profiles (study/druid2, 2026-10-03; Cat, Balance and Bear re-run 2026-10-08 from
    -- SharpiesGearJudge-SimStudio), each worked out with its build's own talents, so ApplyScalers' talent hooks skip them.
    -- Hit and Crit per 1%.
    -- Cat: Raid (Balance 9 / Feral 35 / Restoration 7, no Furor) from the wowsims Forever simulator, Attack Power 1.5 like the
    -- other melee profiles. Agility (Attack Power and crit) edges Strength. Forever's Furor refunds no extra energy, so the
    -- cat no longer powershifts and Intellect, Spirit and Mp5 are worth almost nothing. Hit was measured below the cap
    -- (5% gear + Nature's Reach already reach it); the hit cap logic below takes it down past that. Forms swing the
    -- equipped weapon's DPS at the form's speed (devs on the Forever bug tracker, #208/#220), so Weapon DPS is worth
    -- about 9.6 Attack Power per point: everything but Rip, Ferocious Bite and Rake, which scale off Attack Power only
    -- (Rake +5% of attack power on its hit and each tick, from beta logs; re-run 2026-10-13 on the merged upstream sim).
    ["CAT_RAID"] = { ["ITEM_MOD_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_FERAL_ATTACK_POWER_SHORT"]=1.5, ["ITEM_MOD_AGILITY_SHORT"]=4.03, ["ITEM_MOD_STRENGTH_SHORT"]=3.6, ["ITEM_MOD_INTELLECT_SHORT"]=0.17, ["ITEM_MOD_SPIRIT_SHORT"]=0.07, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=0.25, ["ITEM_MOD_HIT_RATING_SHORT"]=29.6, ["ITEM_MOD_CRIT_RATING_SHORT"]=43.1, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=14.0 },
    -- Balance: Raid (Balance 33 / Feral 3 / Restoration 15) from the simulator, Spell Power 2.0. Starfire carries the damage,
    -- so Arcane damage takes most of the Spell Power value.
    ["BALANCE_RAID"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_ARCANE_DAMAGE_SHORT"]=1.61, ["ITEM_MOD_NATURE_DAMAGE_SHORT"]=0.39, ["ITEM_MOD_INTELLECT_SHORT"]=0.25, ["ITEM_MOD_STAMINA_SHORT"]=0.1, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=15.2, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=14.1 },
    -- Restoration: Raid (Balance 11 / Feral 5 / Restoration 35) from our healing model (the simulator can't heal), Healing 2.0.
    -- Most Druid healing is over time and HoTs can't crit, so Crit is worth little; Spirit and Mp5 lead the mana stats.
    -- Spell Power is the damage value only: an item's Spell Power also heals, and MSC.GetItemScore adds that at the
    -- Healing weight, so a raid healer's Spell Power weight is 0 (it was 2.0, which counted Spell Power twice).
    ["RESTO_RAID"] = { ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"]=2.0, ["ITEM_MOD_SPELL_POWER_SHORT"]=0.0, ["ITEM_MOD_INTELLECT_SHORT"]=1.03, ["ITEM_MOD_SPIRIT_SHORT"]=4.72, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=2.14, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=14.3, ["ITEM_MOD_STAMINA_SHORT"]=0.5 },
    -- Bear: Raid (Balance 9 / Feral 42 with Heart of the Wild, Rend and Tear and Shredding Attacks; talents re-searched
    -- 2026-10-10) from the simulator's tank mode, as the Warrior's Protection: Raid: threat 35% / damage taken 35% /
    -- effective health 30% (health counts Heart of the Wild's Stamina), Stamina 3.0. Armor is item armor (Dire Bear Form
    -- multiplies it by 4.6); the simulator stops counting more armor past about 5,000 in form, which a geared Bear reaches.
    -- Weapon DPS is 14x Attack Power: Dire Bear swings the equipped weapon's DPS every 2.5 s.
    ["BEAR_RAID"] = { ["ITEM_MOD_STAMINA_SHORT"]=3.0, ["ITEM_MOD_ARMOR_SHORT"]=0.55, ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"]=2.55, ["ITEM_MOD_DODGE_RATING_SHORT"]=13.8, ["ITEM_MOD_AGILITY_SHORT"]=1.55, ["ITEM_MOD_STRENGTH_SHORT"]=1.03, ["ITEM_MOD_ATTACK_POWER_SHORT"]=0.47, ["ITEM_MOD_FERAL_ATTACK_POWER_SHORT"]=0.47, ["ITEM_MOD_HIT_RATING_SHORT"]=16.9, ["ITEM_MOD_CRIT_RATING_SHORT"]=10.5, ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]=6.5 },

    -- Hybrid (not modelled): its healing stats moved to the Healing 20 scale (Healing 0.8 -> 20, x25), so the feral and
    -- defensive weights get the same x25 to keep the old balance: Strength 2.0 -> 50, Stamina 1.0 -> 25,
    -- Armor 0.2 -> 5, Weapon Skill 5.0 -> 125 (Strength is still 2.5x Healing, as before the rescale).
    -- Spell Power 0, as on the raid healers: MSC.GetItemScore already scores it at the Healing weight.

    -- BALANCE_FARM: from the farm model (SimStudio models/shared/farm_profiles.py, data/farm_weights.json: the DRUID_HURRICANE_FARM build's
    -- talents at the main farm spot, mobs 3 levels below you, the farm gear set), 2026-10-25, re-run 2026-11-01.
    ["BALANCE_FARM"] = { ["ITEM_MOD_SPELL_POWER_SHORT"]=2.0, ["ITEM_MOD_NATURE_DAMAGE_SHORT"]=1.92, ["ITEM_MOD_STAMINA_SHORT"]=0.08, ["ITEM_MOD_INTELLECT_SHORT"]=0.54, ["ITEM_MOD_SPIRIT_SHORT"]=2.08, ["ITEM_MOD_MANA_REGENERATION_SHORT"]=2.33, ["ITEM_MOD_HEALTH_REGENERATION_SHORT"]=0.9, ["ITEM_MOD_HIT_SPELL_RATING_SHORT"]=0.9, ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"]=6.4 },
}
-- Old names, kept so a saved profile choice still works.
Druid.Weights["BALANCE_BOOMKIN"] = Druid.Weights["BALANCE_RAID"]
Druid.Weights["FERAL_CAT_DPS"] = Druid.Weights["CAT_RAID"]
Druid.Weights["RESTO_DEEP"] = Druid.Weights["RESTO_RAID"]
-- The old Moonglow and Regrowth healer tables (not modelled, and they counted Spell Power twice) now use the
-- healing model: a Restoration Druid at 60 heals the same way whichever of those talents it took.
Druid.Weights["RESTO_MOONGLOW"] = Druid.Weights["RESTO_RAID"]
Druid.Weights["RESTO_REGROWTH"] = Druid.Weights["RESTO_RAID"]
Druid.Weights["FERAL_BEAR_TANK"] = Druid.Weights["BEAR_RAID"]
-- PvP profiles: copies of the PvE profile each build plays like; the PvP model (Helpers 5.10) adds
-- Stamina, armor and burst on top and keeps hit at the player-vs-player caps.
-- Picked by the Talents plugin's PvP builds or by hand.
Druid.Weights["FERAL_PVP"] = MSC.ForeverPvPFrom(Druid.Weights["CAT_RAID"])
Druid.Weights["BALANCE_PVP"] = MSC.ForeverPvPFrom(Druid.Weights["BALANCE_RAID"])
Druid.Weights["RESTO_PVP"] = MSC.ForeverPvPFrom(Druid.Weights["RESTO_RAID"])
-- The study-built level-60 profiles (talents already in): ApplyScalers' talent hooks skip these.
local SIM_PROFILES = { BALANCE_FARM = true, CAT_RAID = true, BALANCE_RAID = true, RESTO_RAID = true, BEAR_RAID = true,
    BALANCE_BOOMKIN = true, FERAL_CAT_DPS = true, RESTO_DEEP = true, FERAL_BEAR_TANK = true, FERAL_PVP = true, BALANCE_PVP = true, RESTO_PVP = true,
    RESTO_MOONGLOW = true, RESTO_REGROWTH = true }
-- With Gear for PvP on, auto-detect shows the PvP profile in place of the raid one
-- (same weights plus the PvP model; MSC:ApplyDynamicAdjustments).
Druid.PvPCounterpart = { CAT_RAID = "FERAL_PVP", FERAL_CAT_DPS = "FERAL_PVP", BALANCE_RAID = "BALANCE_PVP", BALANCE_BOOMKIN = "BALANCE_PVP",
    RESTO_RAID = "RESTO_PVP", RESTO_DEEP = "RESTO_PVP", RESTO_MOONGLOW = "RESTO_PVP", RESTO_REGROWTH = "RESTO_PVP" }

-- =============================================================
-- LEVELING WEIGHTS
-- =============================================================
-- Filled at load from Classes/Forever/Curves/Druid_Curves.lua (generated by
-- SimStudio from cmodel / bmodel / dheal; don't edit it by hand) by Curves_Attach.lua: one row per role and level band,
-- blended by level in MSC:GetLevelingRow. The default line changes form by level: caster
-- form to 9, Bear Form 10-19, Cat Form from 20. Roles:
--   Leveling                Feral Cat: Solo Leveling (the default)
--   Leveling_Dungeon        Cat: Dungeon Leveling
--   Leveling_Bear           Bear: Dungeon Leveling (also the Bear raid build's leveling)
--   Leveling_Caster         Balance: Solo Leveling
--   Leveling_CasterDungeon  Balance: Dungeon Leveling (2026-10-23)
--   Leveling_Healer         Restoration: Solo Leveling
--   Leveling_HealerDungeon  Restoration: Dungeon Leveling
Druid.LevelingWeights = {}

-- =============================================================
-- DISPLAY NAMES (match the Talents plugin's builds; translated in Locales/*.lua)
-- =============================================================
local L = MSC.L
local function Band(label, lo, hi) return L[label] .. " (" .. lo .. "-" .. hi .. ")" end
Druid.PrettyNames = {
    ["CAT_RAID"]        = L["Cat: Raid"],
    ["BALANCE_RAID"]    = L["Balance: Raid"],
    ["RESTO_RAID"]      = L["Restoration: Raid"],
    ["BEAR_RAID"]       = L["Bear: Raid"],
    ["FERAL_CAT_DPS"]   = L["Cat: Raid (old profile)"],
    ["BALANCE_BOOMKIN"] = L["Balance: Raid (old profile)"],
    ["RESTO_DEEP"]      = L["Restoration: Raid (old profile)"],
    ["FERAL_BEAR_TANK"] = L["Bear: Raid (old profile)"],
    ["RESTO_MOONGLOW"]     = "Healer: Moonglow",
    ["RESTO_REGROWTH"]     = "Healer: Regrowth (Crit)",
    ["FERAL_PVP"]          = L["PvP: Feral (Cat)"],
    ["BALANCE_PVP"]        = L["PvP: Balance"],
    ["RESTO_PVP"]          = L["PvP: Restoration"],
    ["BALANCE_FARM"] = L["Balance: Hurricane Farming"],

    ["Leveling_1_10"] = Band("Leveling", 1, 10),
}
-- One name per leveling role; each level band gets "(lo-hi)" added.
local ROLE_NAMES = {
    { "Leveling",               "Feral Cat: Solo Leveling" },
    { "Leveling_Dungeon",       "Cat: Dungeon Leveling" },
    { "Leveling_Bear",          "Bear: Dungeon Leveling" },
    { "Leveling_Caster",        "Balance: Solo Leveling" },
    { "Leveling_CasterDungeon", "Balance: Dungeon Leveling" },
    { "Leveling_Healer",        "Restoration: Solo Leveling" },
    { "Leveling_HealerDungeon", "Restoration: Dungeon Leveling" },
}
for _, r in ipairs(ROLE_NAMES) do
    for _, b in ipairs({ { 11, 20 }, { 21, 40 }, { 41, 51 }, { 52, 59 } }) do
        Druid.PrettyNames[r[1] .. "_" .. b[1] .. "_" .. b[2]] = Band(r[2], b[1], b[2])
    end
end

-- =============================================================
-- WOW FOREVER TALENTS
-- =============================================================
Druid.Talents = { 
    ["MOONKIN_FORM"]    = MSC.L["Moonkin Form"],
    ["MOONGLOW"]        = MSC.L["Moonglow"],
    ["NATURES_GRACE"]   = MSC.L["Nature's Grace"],
    ["LEADER_OF_PACK"]  = MSC.L["Leader of the Pack"],
    ["HEART_WILD"]      = MSC.L["Heart of the Wild"],
    ["THICK_HIDE"]      = MSC.L["Thick Hide"],
    ["FUROR"]           = MSC.L["Furor"],
    ["SWIFTMEND"]       = MSC.L["Swiftmend"],
    ["NATURES_SWIFT"]   = MSC.L["Nature's Swiftness"],
    ["IMP_REGROWTH"]    = MSC.L["Improved Regrowth"],
    ["REFLECTION"]      = MSC.L["Reflection"],
    ["WILD_GROWTH"]     = MSC.L["Wild Growth"],
    ["LIVING_SPIRIT"]   = MSC.L["Living Spirit"],
    ["NATURES_REACH"]   = MSC.L["Nature's Reach"],
    ["VENGEANCE"]       = MSC.L["Vengeance"], -- Balance t4, 5 ranks, +20%/rank crit damage bonus on Arcane/Nature spells
    ["MOONFURY"]        = MSC.L["Moonfury"], -- Balance t6, 5 ranks, +2%/rank Arcane/Nature spell damage
    ["GENESIS"]         = MSC.L["Genesis"], -- New in Forever, Balance t1, 5 ranks, +2%/rank periodic damage AND healing (2026-10-30 hotfix; was 1%)
    ["GIFT_OF_NATURE"]  = MSC.L["Gift of Nature"], -- Restoration t3, 5 ranks, +2%/rank universal healing (Same as Classic)
    ["NATURAL_INSTINCT"] = MSC.L["Natural Instinct"], -- Feral t5, 2 ranks (Predatory Instincts until client 70291): +10%/rank melee crit damage bonus, spell healing +12.5%/rank of Intellect
    ["SAVAGE_FURY"]     = MSC.L["Savage Fury"], -- Feral t3, 2 ranks, +5%/rank Claw/Rake/Shred/Maul/Swipe damage
    ["NATURALIST"]      = MSC.L["Naturalist"], -- Restoration t2, 5 ranks, +2%/rank all damage dealt (2026-10-30 hotfix; was 1%)
    ["NATURES_FOCUS"]   = MSC.L["Nature's Focus"], -- Restoration t1, 5 ranks, pushback protection on Nature/Arcane casts
    ["SUBTLETY"]        = MSC.L["Subtlety"], -- Restoration t2, 3 ranks, Nature/Arcane threat reduction
    ["BLOOM"]           = MSC.L["Bloom"], -- Restoration t3, 1 rank (2026-10-30 hotfix, where Gift of the Earthmother was)
    ["IMP_WRATH"]       = MSC.L["Improved Wrath"], -- Balance t1, 5 ranks
    ["IMP_MOONFIRE"]    = MSC.L["Improved Moonfire"], -- Balance t2, 2 ranks
    ["NATURAL_SHAPESHIFTER"] = MSC.L["Natural Shapeshifter"], -- Restoration t2, 3 ranks, -10%/rank shapeshift mana cost
    ["SHIFTING_POWER"]  = MSC.L["Shifting Power"], -- Feral t7, 1 rank: 55% base mana -> 40 Energy, 8 s cd (2026-10-30 hotfix; was t4, 16 s)
    ["LACERATE"]        = MSC.L["Lacerate"], -- Feral t4, 1 rank (2026-10-30 hotfix: a Bear-only talent, was trained at 42)
    ["PREDATORY_STRIKES"] = MSC.L["Predatory Strikes"], -- Feral t4 (minLevel 25), 3 ranks, +0.5 x level AP per rank in Cat/Bear
    ["SHARPENED_CLAWS"] = MSC.L["Sharpened Claws"], -- Feral t3, 2 ranks, +3% crit per rank in Cat/Bear
    ["NATURES_MAJESTY"] = MSC.L["Nature's Majesty"], -- Balance t2, 2 ranks, +2% spell AND melee crit per rank
    ["SHREDDING_ATTACKS"] = MSC.L["Shredding Attacks"], -- Feral t3 (2 Oct patch), 3 ranks, -6 Shred energy per rank
    ["REND_AND_TEAR"]   = MSC.L["Rend and Tear"], -- Feral t6, 5 ranks, +2%/rank melee ability damage on bleeding targets
}

-- Leveling role marker talents (see MSC:GetLowLevelRole). Furor is
-- deliberately not a Restoration marker -- nearly every leveling Druid takes
-- it -- and Genesis / Nature's Majesty aren't Balance markers because they
-- help Restoration and Feral too. Balance was otherwise only detected by
-- Moonkin Form (40+).
Druid.LowLevelRoles = {
    Leveling_Bear   = { "THICK_HIDE", "LACERATE" },
    Leveling_Healer = { "NATURES_FOCUS", "SUBTLETY", "REFLECTION", "GIFT_OF_NATURE", "BLOOM" },
    -- (Nature's Reach is hit for every form, so Feral builds take it too: not a Balance marker)
    Leveling_Caster = { "IMP_WRATH", "MOONGLOW", "IMP_MOONFIRE", "VENGEANCE", "MOONFURY" },
    -- No markers (talents can't tell solo from group play): applies only when chosen, e.g. by a Talents plugin build.
    Leveling_Dungeon = {},
    Leveling_CasterDungeon = {},
    Leveling_HealerDungeon = {},
}

-- =============================================================
-- LOGIC
-- =============================================================
Druid.ValidWeapons = {
    [4]=true, [5]=true,   -- 1H/2H Maces
    [6]=true,             -- Polearms (Forever: learned at 20)
    [10]=true,            -- Staves
    [13]=true,            -- Fist Weapons
    [15]=true             -- Daggers
}

function Druid:GetSpec()
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
        if forced and (forced == "Leveling" or Druid.LowLevelRoles[forced]) and level >= 10 then
            local fs = (level == 10 and forced ~= "Leveling") and "_11_20" or suffix
            if Druid.LevelingWeights[forced .. fs] then return forced .. fs end
        end

        local role = "Leveling" -- Default to Cat
        if Rank("MOONKIN_FORM") > 0 then role = "Leveling_Caster"
        elseif Rank("SWIFTMEND") > 0 then role = "Leveling_Healer"
        elseif Rank("THICK_HIDE") >= 3 then role = "Leveling_Bear"
        -- Shifting Power is Cat-only: keeps Cat builds that fill tiers with Nature's Focus / Genesis off the healer and caster weights
        elseif Rank("SHIFTING_POWER") > 0 then role = "Leveling"
        elseif level >= 10 then role = MSC:GetLowLevelRole(Druid.LowLevelRoles) or role
        end
        if role == "Leveling_Dungeon" then role = "Leveling" end
        if role == "Leveling_HealerDungeon" then role = "Leveling_Healer" end
        if role == "Leveling_CasterDungeon" then role = "Leveling_Caster" end

        -- Not every role has every bracket (e.g. no Leveling_Caster_21_40);
        -- returning a missing key would leave the profile with no weights
        -- and silence every verdict, so fall back like the other classes do.
        -- Level 10 brings the first talent point: a role it marks uses that
        -- role's 11-20 row (the 1-10 band only has the default row).
        if level == 10 and role ~= "Leveling" then suffix = "_11_20" end
        local key = role .. suffix
        if Druid.LevelingWeights[key] then return key end
        return "Leveling" .. suffix
    end

    -- Endgame Spec Detection
    if Rank("MOONKIN_FORM") > 0 then return "BALANCE_RAID" end
    if Rank("WILD_GROWTH") > 0 then return "RESTO_RAID" end
    if Rank("SWIFTMEND") > 0 and Rank("LEADER_OF_PACK") == 0 then return "RESTO_RAID" end
    if Rank("MOONGLOW") > 0 and Rank("NATURES_SWIFT") > 0 then return "RESTO_MOONGLOW" end
    if Rank("IMP_REGROWTH") >= 3 then return "RESTO_REGROWTH" end

    -- Feral Split: Bear vs Cat
    if Rank("THICK_HIDE") >= 3 then return "BEAR_RAID" end
    return "CAT_RAID"
end

function Druid:ApplyScalers(weights, currentSpec)
    local function Rank(k) return MSC:GetTalentRank(k) end
    local activeCaps = {}
    -- The default leveling line changes form by level, not by band: caster
    -- form to 9, Bear Form 10-19, Cat Form (learned at 20) from 20 on.
    local level = UnitLevel("player")
    -- The study-built level-60 profiles already carry their talents: the talent hooks skip them (the caps still apply).
    local hooks = not SIM_PROFILES[currentSpec or ""]
    -- (Leveling_Dungeon is the Cat dungeon line: Bear Form before 20 like the default line)
    local isCat = currentSpec:find("CAT") or currentSpec:match("^Leveling_[245]%d_%d%d$") or currentSpec:match("^Leveling_Dungeon_[245]%d_%d%d$")
        or ((currentSpec == "Leveling_11_20" or currentSpec == "Leveling_Dungeon_11_20") and level >= 20)
    local isDefaultBear = (currentSpec == "Leveling_1_10" and level == 10)
        or ((currentSpec == "Leveling_11_20" or currentSpec == "Leveling_Dungeon_11_20") and level < 20)
    
    -- 1. Heart of the Wild
    local rHotW = Rank("HEART_WILD")
    if hooks and rHotW > 0 then
        if weights["ITEM_MOD_INTELLECT_SHORT"] then 
            weights["ITEM_MOD_INTELLECT_SHORT"] = weights["ITEM_MOD_INTELLECT_SHORT"] * (1 + (rHotW * 0.02)) 
        end
        -- upper(): the leveling profiles are "Leveling_Bear_*", not "BEAR".
        if (currentSpec:upper():find("BEAR") or isDefaultBear) and weights["ITEM_MOD_STAMINA_SHORT"] then
            weights["ITEM_MOD_STAMINA_SHORT"] = weights["ITEM_MOD_STAMINA_SHORT"] * (1 + (rHotW * 0.04))
        end
        if (isCat or currentSpec:find("DPS")) and weights["ITEM_MOD_STRENGTH_SHORT"] then
            weights["ITEM_MOD_STRENGTH_SHORT"] = weights["ITEM_MOD_STRENGTH_SHORT"] * (1 + (rHotW * 0.02))
        end
    end
    
    local rLS = Rank("LIVING_SPIRIT")
    if hooks and rLS > 0 and weights["ITEM_MOD_SPIRIT_SHORT"] then
        weights["ITEM_MOD_SPIRIT_SHORT"] = weights["ITEM_MOD_SPIRIT_SHORT"] * (1 + (rLS * 0.05))
    end

    -- Vengeance (Balance t4, 5 ranks): "Increases the critical strike damage
    -- bonus of your Arcane and Nature spells by 20%" -- same phrasing/math as
    -- Mage's Arcane Mind/Ice Shards -- 1+rank*0.20, reaching 2.0x at 5/5
    local rVengeance = Rank("VENGEANCE")
    -- (damage spells only: not on the healer rows, where spell crit is heal crit)
    if hooks and rVengeance > 0 and not currentSpec:find("^Leveling_Healer") and weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] then
        weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] = weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] * (1 + (rVengeance * 0.20))
    end

    -- Row families the talent hooks below route by. isBear is the leveling
    -- Bear rows plus the 10-19 default line (isDefaultBear above).
    local isBear = currentSpec:find("^Leveling_Bear") or isDefaultBear
    local isCasterRow = currentSpec:find("^Leveling_Caster")
    local isHealerRow = currentSpec:find("^Leveling_Healer")
    local isLevelingRow = currentSpec:find("^Leveling")
    local Keys = MSC.ScaleForeverKeys
    local touched = {}
    local function Touch(list) for _, k in ipairs(list) do touched[k] = true end end
    -- Melee offense keys a Cat/Bear damage talent scales together. Forms
    -- swing the equipped weapon's DPS, so weapon DPS is offense too.
    local FERAL_OFFENSE = { "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", "ITEM_MOD_STRENGTH_SHORT",
        "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HIT_RATING_SHORT", "MSC_WEAPON_DPS_MELEE" }
    local BEAR_STRIKES_KEYS = { "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_STAMINA_SHORT",
        "ITEM_MOD_HEALTH_SHORT", "ITEM_MOD_ARMOR_SHORT", "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_AGILITY_SHORT" }

    -- Natural Shapeshifter (Restoration t2, 3 ranks): -10% shapeshift mana
    -- cost per rank. The shift is ~55% of a Cat leveler's mana per kill, so
    -- every mana stat loses 5.5% of its value per rank.
    local rNatShift = Rank("NATURAL_SHAPESHIFTER")
    if rNatShift > 0 and isCat and isLevelingRow then
        Keys(weights, MSC.ForeverManaKeys, 1 - 0.055 * rNatShift)
        Touch(MSC.ForeverManaKeys)
    end

    -- Shifting Power (Feral t7, minLevel 40 since the 2026-10-30 hotfix, 8 s
    -- cooldown): turns 55% of base mana into 40 Energy, so a Cat's spare mana
    -- becomes damage. Using it is mana-limited, not cooldown-limited, so each
    -- mana point is worth 40 / cost Energy: about 1.2 AP per Intellect at 30
    -- falling to 0.6 at 59, and Mp5 about 0.6 (the study's kill times, paw
    -- damage and special-attack damage per Energy), hedged x0.6 for players
    -- who don't spend every cooldown. Natural Shapeshifter makes it cheaper,
    -- so more Energy per mana. Spirit is left out: casting it starts the
    -- five-second rule.
    if Rank("SHIFTING_POWER") > 0 and isCat and isLevelingRow and level >= 25 then
        local cheaper = 1 / (1 - 0.1 * rNatShift)
        local addInt = MSC.ForeverLevelLerp({ { 30, 0.70 }, { 40, 0.52 }, { 50, 0.41 }, { 59, 0.38 } }, level) * cheaper
        local addMp5 = MSC.ForeverLevelLerp({ { 30, 0.39 }, { 59, 0.32 } }, level) * cheaper
        weights["ITEM_MOD_INTELLECT_SHORT"] = (weights["ITEM_MOD_INTELLECT_SHORT"] or 0) + addInt
        weights["ITEM_MOD_MANA_REGENERATION_SHORT"] = (weights["ITEM_MOD_MANA_REGENERATION_SHORT"] or 0) + addMp5
        Touch({ "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT" })
    end

    -- Predatory Strikes (Feral t4, minLevel 25, 3 ranks): +0.5 x level attack
    -- power per rank in Cat/Bear -- about +2.2% Cat damage (+1.5% Bear) per
    -- rank at every level.
    local rPredStrikes = Rank("PREDATORY_STRIKES")
    if rPredStrikes > 0 and level >= 25 and isLevelingRow then
        if isCat then
            -- Crit goes through the helper so Agility's crit share follows.
            MSC.ScaleForeverMeleeCrit(weights, 1 + 0.022 * rPredStrikes, level)
            Keys(weights, { "ITEM_MOD_HIT_RATING_SHORT" }, 1 + 0.022 * rPredStrikes)
            Touch({ "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_AGILITY_SHORT" })
        elseif isBear then
            -- Bigger damage makes every safety stat worth more against it;
            -- Strength/AP/Feral AP stay the unit.
            Keys(weights, BEAR_STRIKES_KEYS, 1 + 0.015 * rPredStrikes)
            Touch(BEAR_STRIKES_KEYS)
        end
    end

    -- Moonfury (Balance t6, 5 ranks): +2%/rank Arcane/Nature spell damage.
    -- Genesis (New in Forever, Balance t1, 5 ranks): +2%/rank periodic damage
    -- AND healing. Naturalist (Restoration t2, 5 ranks): +2%/rank all damage
    -- (both doubled by the 2026-10-30 hotfix).
    -- Gift of Nature (Restoration t3, 5 ranks): +2%/rank universal healing.
    -- A flat damage/healing multiplier lifts every damage-derived stat
    -- equally, so the caster/healer leveling rows take it by dividing the
    -- safety stats (Agility included) instead of scaling Spell Power or
    -- Healing; endgame specs keep the plain scaling.
    local rMoonfury = Rank("MOONFURY")
    local rGenesis = Rank("GENESIS")
    local rGoN = Rank("GIFT_OF_NATURE")
    local rNaturalist = Rank("NATURALIST")
    if isCasterRow then
        -- Genesis at 0.3 of nominal: DoTs are ~25-35% of modelled damage.
        local m = (1 + 0.02 * rMoonfury) * (1 + 0.02 * rNaturalist) * (1 + 0.006 * rGenesis)
        MSC.ApplyForeverDamageMult(weights, m, { "ITEM_MOD_AGILITY_SHORT" })
        Touch(MSC.ForeverSafetyKeys)
        Touch({ "ITEM_MOD_AGILITY_SHORT" })
    elseif isHealerRow then
        -- Genesis at 0.4 of nominal: HoTs and Wild Growth are ~40% of healing.
        local m = (1 + 0.02 * rGoN) * (1 + 0.008 * rGenesis) * (1 + 0.02 * rNaturalist)
        MSC.ApplyForeverDamageMult(weights, m, { "ITEM_MOD_AGILITY_SHORT" })
        Touch(MSC.ForeverSafetyKeys)
        Touch({ "ITEM_MOD_AGILITY_SHORT" })
    elseif hooks then
        if rMoonfury > 0 and weights["ITEM_MOD_SPELL_POWER_SHORT"] then
            weights["ITEM_MOD_SPELL_POWER_SHORT"] = weights["ITEM_MOD_SPELL_POWER_SHORT"] * (1 + (rMoonfury * 0.02))
        end
        if rGenesis > 0 then
            if weights["ITEM_MOD_SPELL_POWER_SHORT"] then
                weights["ITEM_MOD_SPELL_POWER_SHORT"] = weights["ITEM_MOD_SPELL_POWER_SHORT"] * (1 + (rGenesis * 0.02))
            end
            if weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] then
                weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] * (1 + (rGenesis * 0.02))
            end
        end
        if rGoN > 0 and weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] then
            weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] * (1 + (rGoN * 0.02))
        end
        if rNaturalist > 0 then
            if (isCat or isBear) and isLevelingRow then
                -- Feral rows: the melee offense keys plus Spell Power.
                local f = 1 + 0.02 * rNaturalist
                Keys(weights, FERAL_OFFENSE, f)
                Keys(weights, { "ITEM_MOD_SPELL_POWER_SHORT" }, f)
                Touch(FERAL_OFFENSE)
            else
                if weights["ITEM_MOD_SPELL_POWER_SHORT"] then
                    weights["ITEM_MOD_SPELL_POWER_SHORT"] = weights["ITEM_MOD_SPELL_POWER_SHORT"] * (1 + (rNaturalist * 0.02))
                end
                if weights["ITEM_MOD_ATTACK_POWER_SHORT"] then
                    weights["ITEM_MOD_ATTACK_POWER_SHORT"] = weights["ITEM_MOD_ATTACK_POWER_SHORT"] * (1 + (rNaturalist * 0.02))
                end
            end
        end
    end

    -- Reflection (Restoration t3, 3 ranks, minLevel 20): 17% of mana regen
    -- continues while casting per rank. The Healer anchors bake rb(L): 0 to
    -- 15, 1 at 20, 3 from 25; Spirit and Intellect move with the gap.
    if isHealerRow then
        local rReflection = Rank("REFLECTION")
        local rb = MSC.ForeverLevelLerp({ {15, 0}, {20, 1}, {25, 3} }, level)
        if rReflection ~= rb then
            Keys(weights, { "ITEM_MOD_SPIRIT_SHORT" }, (0.70 + 0.10 * rReflection) / (0.70 + 0.10 * rb))
            Keys(weights, { "ITEM_MOD_INTELLECT_SHORT" }, 1 + 0.04 * (rb - rReflection))
            Touch({ "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_INTELLECT_SHORT" })
        end
    end

    -- Natural Instinct (Feral t5, 2 ranks; Predatory Instincts before client
    -- 70291): +10%/rank melee crit damage bonus -- Cat and Bear leveling rows
    -- both carry Crit. The helper also moves Agility's crit share.
    local rNatInstinct = Rank("NATURAL_INSTINCT")
    if hooks and rNatInstinct > 0 and (isCat or isBear) then
        MSC.ScaleForeverMeleeCrit(weights, 1 + 0.10 * rNatInstinct, level)
        Touch({ "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_AGILITY_SHORT" })
    end
    -- Its new healing part: spell healing +12.5%/rank of Intellect, so each
    -- Intellect also heals for that much (any row that values healing).
    if rNatInstinct > 0 and (weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or 0) > 0 and weights["ITEM_MOD_INTELLECT_SHORT"] then
        weights["ITEM_MOD_INTELLECT_SHORT"] = weights["ITEM_MOD_INTELLECT_SHORT"]
            + 0.125 * rNatInstinct * weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"]
    end

    -- Savage Fury (Feral t3, 2 ranks): +5%/rank Claw/Rake/Shred/Maul/Swipe
    -- damage, ~40% of Cat damage (Maul in Bear) -- +2% per rank on the
    -- offense keys, Bear Agility at half that.
    local rSavageFury = Rank("SAVAGE_FURY")
    if hooks and rSavageFury > 0 and (isCat or isBear) then
        Keys(weights, FERAL_OFFENSE, 1 + 0.02 * rSavageFury)
        if isBear and not isCat then
            -- FERAL_OFFENSE took Agility at the full +2%: pull it back to +1%.
            Keys(weights, { "ITEM_MOD_AGILITY_SHORT" }, (1 + 0.01 * rSavageFury) / (1 + 0.02 * rSavageFury))
        end
        Touch(FERAL_OFFENSE)
    end

    -- Cat crit chance talents: Sharpened Claws (+3%/rank, Feral t3), Nature's
    -- Majesty (+2%/rank melee and spell crit) and Leader of the Pack (+3%,
    -- self included). The curve bakes none of them (SimStudio's builders take
    -- them out of the builds before cmodel runs, 2026-10-23). A crit chance point
    -- doesn't change what 1% of crit rating is worth (that's the damage per
    -- hit x the crit bonus), but every other point of offense (Attack Power,
    -- Strength, Feral AP, Hit, Agility's own Attack Power) is worth more
    -- because it now feeds more crits: x(1 + extra crit x crit bonus) over a
    -- base crit chance of about 9% at 22 to 22% at 59. Crit itself stays put.
    local rSharp, rNatMaj, rLotP = Rank("SHARPENED_CLAWS"), Rank("NATURES_MAJESTY"), Rank("LEADER_OF_PACK")
    local extraCrit = 0.03 * rSharp + 0.02 * rNatMaj + 0.03 * rLotP
    if extraCrit > 0 and isCat and isLevelingRow then
        local bonus = 1 + 0.10 * rNatInstinct
        local baseCrit = MSC.ForeverLevelLerp({ { 22, 0.09 }, { 40, 0.15 }, { 59, 0.22 } }, level)
        local m = 1 + extraCrit * bonus / (1 + baseCrit * bonus)
        local agi = weights["ITEM_MOD_AGILITY_SHORT"]
        if agi then
            -- Only Agility's Attack Power part grows, not its crit share.
            local critShare = (weights["ITEM_MOD_CRIT_RATING_SHORT"] or 0) / MSC.GetForeverAgiPerCrit(level)
            weights["ITEM_MOD_AGILITY_SHORT"] = agi + math.max(agi - critShare, 0) * (m - 1)
        end
        Keys(weights, { "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
            "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_HIT_RATING_SHORT", "MSC_WEAPON_DPS_MELEE" }, m)
        Touch({ "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", "ITEM_MOD_STRENGTH_SHORT",
            "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_AGILITY_SHORT", "MSC_WEAPON_DPS_MELEE" })
    end

    -- Shredding Attacks (Feral t3, 3 ranks, -6 Shred energy per rank: 60 to 42
    -- at 3/3, about +40% Shred per Energy) and Rend and Tear (Feral t6, 5
    -- ranks, +2%/rank melee ability damage on bleeding targets). Neither is
    -- baked: the builders take both out before cmodel (which has an Energy
    -- model) runs, so the hooks add them (2026-10-23). Shred needs the target's back and a Cat is only part Energy-
    -- limited, so Shredding Attacks counts about +3.5% damage per rank; Rend
    -- and Tear is 50% bleed uptime on 80% of damage, +0.8% per rank. Both
    -- lift the whole offense family together, like Savage Fury above.
    local rShredAtk, rRendTear = Rank("SHREDDING_ATTACKS"), Rank("REND_AND_TEAR")
    if (rShredAtk > 0 or rRendTear > 0) and isCat and isLevelingRow then
        Keys(weights, FERAL_OFFENSE, (1 + 0.035 * rShredAtk) * (1 + 0.008 * rRendTear))
        Touch(FERAL_OFFENSE)
    end

    -- Weights under 0.02 are noise to the scorer: zero what the talent
    -- hooks shrank into that band.
    for k in pairs(touched) do
        local v = weights[k]
        if v and v > 0 and v < 0.02 then weights[k] = 0 end
    end

    -- (The old "Spirit grows with healing power" scaler is gone, 2026-10-28: it never ran on a
    -- level-60 profile, and the healer weights move with gear through the profile's gear points.)

    -- 3. Caps
    -- Nature's Reach (+2% hit per rank, all attacks) is already in the game's
    -- hit numbers read by MSC:GetForeverHitPercent. Targets are the level's
    -- caps, sliding to the raid caps from 50; past a cap Hit keeps 10% of
    -- its value (the same for every class).
    MSC.ApplyForeverHitCap(weights, "ITEM_MOD_HIT_RATING_SHORT", "MELEE", 0.1, "Hit", activeCaps)
    MSC.ApplyForeverHitCap(weights, "ITEM_MOD_HIT_SPELL_RATING_SHORT", "SPELL", 0.1, "Spell Hit", activeCaps, nil, MSC.ForeverSpellCapKind(currentSpec))
    -- Bear: defense toward 440 from 50 (bears can't block, so no uncrushable)
    if currentSpec:upper():find("BEAR") then MSC.ApplyForeverDefenseTarget(weights, activeCaps) end

    return weights, (#activeCaps > 0 and table.concat(activeCaps, ", ") or nil)
end

function Druid:GetWeaponBonus(itemLink, weights, slotId, specName, otherHandLink)
    return MSC.GetForeverWeaponRacialBonus(itemLink, weights, otherHandLink)
end

function Druid:GetRelicBonus(itemID, currentSpec)
    return MSC.GetForeverRelicBonus(Druid.Relics, itemID, currentSpec)
end

-- =============================================================
-- IDOLS
-- Wiped for the beta (2026-09-21): these were real TBC Idol item IDs. TBC
-- content isn't part of Forever, so this starts blank and repopulates
-- organically with confirmed Forever Idol IDs, same as the ProcDB/TrinketDB
-- cleanup above.
-- =============================================================
-- Forever idols as equivalent stats per spec (MSC.GetForeverRelicBonus).
-- role: "melee" (Cat/default feral line), "tank" (Bear), "caster", "healer".
-- Mana savings become Mp5; small cooldown/duration effects get a hand-set
-- equivalent for the spec that uses them (estimates, not modeled).
Druid.Relics = {
    -- Windcharged Leaf: shapeshift cost -40. Feral levelers shift about once
    -- a minute (40 mana/min = 3.3 Mp5); casters rarely.
    [263411] = function(role) return { ITEM_MOD_MANA_REGENERATION_SHORT = (role == "melee" or role == "tank") and 3.3 or 1 } end,
    -- Mark of Urs'endris: +4% armor from items
    [263435] = function(role, ctx) return { ITEM_MOD_ARMOR_SHORT = 0.04 * ctx.itemArmor } end,
    -- Mystic Mushroom: +5% Spirit
    [249396] = function(role, ctx) return { ITEM_MOD_SPIRIT_SHORT = 0.05 * ctx.spirit } end,
    -- Talons of Wrath: Wrath 50% chance to restore 35 mana. A Balance leveler
    -- casts Wrath about a quarter of the time it's fighting: ~13 Mp5.
    [249441] = function(role) return { ITEM_MOD_MANA_REGENERATION_SHORT = (role == "caster") and 13 or 1 } end,
    -- Howling Idol: Tiger's Fury cooldown -3 sec. Tiger's Fury was removed
    -- from Forever in the 2 Oct patch, so the idol does nothing now.
    [272427] = {},
    -- Enraged Idol: Enrage +10 rage (Bear)
    [272428] = function(role) return (role == "tank") and { ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 15 } or {} end,
    -- Idol of Synthesis: Swiftmend cooldown -1 sec per HoT on the target
    [272429] = function(role) return (role == "healer") and { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 20 } or {} end,
    -- Swarming Idol: Insect Swarm +2 sec
    [272430] = function(role) return (role == "caster") and { ITEM_MOD_SPELL_POWER_SHORT = 5 } or {} end,
    -- Idol of Swiftness: Swiftmend cooldown -3 sec
    [279250] = function(role) return (role == "healer") and { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 30 } or {} end,
    -- Idol of the Ursine Twins: Lacerate 10% chance to reset Mangle (Bear)
    [279251] = function(role) return (role == "tank") and { ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 30 } or {} end,

    -- Unchanged Classic idols (Wowhead Classic data). Single-spell bonuses
    -- count at that spell's share of the spec's healing/damage/mana use.
    -- Idol of Ferocity: Claw and Rake cost 3 less energy (~4% more Cat damage)
    [22397] = function(role, ctx) return (role == "melee") and { ITEM_MOD_FERAL_ATTACK_POWER_SHORT = math.max(15, 0.03 * ctx.ap) } or {} end,
    -- Idol of Rejuvenation: Rejuvenation heals up to 50 more (~35% of healing)
    [22398] = function(role) return (role == "healer") and { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 17.5 } or {} end,
    -- Idol of Health: Healing Touch cast time -0.15 sec (~2% more healing)
    [22399] = function(role) return (role == "healer") and { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 25 } or {} end,
    -- Idol of Longevity: up to 25 mana back per Healing Touch
    [23004] = function(role) return (role == "healer") and { ITEM_MOD_MANA_REGENERATION_SHORT = 8 } or {} end,
    -- Idol of the Moon: Moonfire deals up to 33 more (~25% of a Balance
    -- Druid's damage)
    [23197] = function(role) return (role == "caster") and { ITEM_MOD_SPELL_POWER_SHORT = 8 } or {} end,
    -- Idol of Brutality: Maul and Swipe cost 3 less rage (Bear)
    [23198] = function(role) return (role == "tank") and { ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 20 } or {} end,
}

-- Register Profiles
-- Retired hand-made profiles (2026-10-27 weight check): the old names point at sim profiles so a saved choice or an
-- alt's profile still works; MSC lists skip them (RetiredProfiles).
Druid.Weights["Default"] = Druid.Weights["CAT_RAID"]
Druid.Weights["HYBRID_HOTW"] = Druid.Weights["CAT_RAID"]
Druid.RetiredProfiles = { Default = true, HYBRID_HOTW = true }
-- A saved retired name scores as the sim profile it points at, so the talent hooks skip it too.
for k in pairs(Druid.RetiredProfiles) do SIM_PROFILES[k] = true end

Druid.Profiles = {}
for k, v in pairs(Druid.Weights) do Druid.Profiles[k] = v end
for k, v in pairs(Druid.LevelingWeights) do Druid.Profiles[k] = v end

MSC.RegisterModule("DRUID", Druid)



