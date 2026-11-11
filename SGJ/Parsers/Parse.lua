if RXP_SGJ_DISABLED then return end
local GetItemInfoInstant = GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local _G = _G 

-- [[ SPEED OPTIMIZATION: LOCALIZED FUNCTIONS ]]
local pairs, ipairs = pairs, ipairs
local tonumber, type = tonumber, type
local string_find, string_match, string_format, string_gsub, string_lower = string.find, string.match, string.format, string.gsub, string.lower
local table_insert = table.insert
local math_floor = math.floor
local pcall = pcall

local CreateFrame = CreateFrame
local WorldFrame = WorldFrame

-- Tooltip numbers: some languages write decimals with a comma ("1,5"), so
-- convert that to a dot before tonumber.
local function ScanNum(x)
    if type(x) == "string" then x = x:gsub(",", ".") end
    return tonumber(x)
end

MSC.Scanner = {}

-- Value and stat name from a pattern's captures. A translated pattern may capture
-- them in the other order (Korean and Chinese tooltips often put the number after
-- the stat name), so when the capture meant as the value isn't a number but the
-- other one is, they are swapped.
function MSC.Scanner.OrderCaptures(pat, m1, m2)
    local v = (pat.valIdx == 1) and m1 or m2
    local n
    if pat.nameIdx then n = (pat.nameIdx == 1) and m1 or m2 else n = (pat.valIdx == 1) and m2 or m1 end
    if n and not ScanNum(v) and ScanNum(n) then v, n = n, v end
    return ScanNum(v), n
end

-- =============================================================
-- 1. DATA MAPS (Shared Dictionaries)
-- =============================================================

MSC.Scanner.BaseStatMap = {
    -- Primary
    [MSC.L["strength"]] = "ITEM_MOD_STRENGTH_SHORT",
    [MSC.L["agility"]]  = "ITEM_MOD_AGILITY_SHORT",
    [MSC.L["stamina"]]  = "ITEM_MOD_STAMINA_SHORT",
    [MSC.L["intellect"]]= "ITEM_MOD_INTELLECT_SHORT",
    [MSC.L["spirit"]]   = "ITEM_MOD_SPIRIT_SHORT",
    
    -- Defensive / Weapon
    [MSC.L["armor"]] = "ITEM_MOD_ARMOR_SHORT",
    [MSC.L["block"]] = "ITEM_MOD_BLOCK_VALUE_SHORT",
    [MSC.L["block value"]] = "ITEM_MOD_BLOCK_VALUE_SHORT",
    [MSC.L["speed"]] = "MSC_WEAPON_SPEED",
    [MSC.L["damage per second"]] = "MSC_WEAPON_DPS",
    [MSC.L["dps"]] = "MSC_WEAPON_DPS",
    
    -- Resistances
    [MSC.L["shadow resistance"]] = "ITEM_MOD_SHADOW_RESISTANCE_SHORT",
    [MSC.L["fire resistance"]]    = "ITEM_MOD_FIRE_RESISTANCE_SHORT",
    [MSC.L["frost resistance"]]   = "ITEM_MOD_FROST_RESISTANCE_SHORT",
    [MSC.L["arcane resistance"]] = "ITEM_MOD_ARCANE_RESISTANCE_SHORT",
    [MSC.L["nature resistance"]] = "ITEM_MOD_NATURE_RESISTANCE_SHORT",
    
    -- Random Suffixes
    [MSC.L["attack power"]]    = "ITEM_MOD_ATTACK_POWER_SHORT", 
    [MSC.L["healing spells"]] = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    [MSC.L["healing"]]        = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    [MSC.L["spell damage"]]    = "ITEM_MOD_SPELL_POWER_SHORT",
    [MSC.L["spell power"]]     = "ITEM_MOD_SPELL_POWER_SHORT",
    [MSC.L["shadow damage"]]   = "ITEM_MOD_SHADOW_DAMAGE_SHORT",
    [MSC.L["fire damage"]]     = "ITEM_MOD_FIRE_DAMAGE_SHORT",
    [MSC.L["frost damage"]]    = "ITEM_MOD_FROST_DAMAGE_SHORT",
    [MSC.L["arcane damage"]]   = "ITEM_MOD_ARCANE_DAMAGE_SHORT",
    [MSC.L["nature damage"]]   = "ITEM_MOD_NATURE_DAMAGE_SHORT",
    [MSC.L["holy damage"]]     = "ITEM_MOD_HOLY_DAMAGE_SHORT",
    [MSC.L["shadow spell damage"]] = "ITEM_MOD_SHADOW_DAMAGE_SHORT",
    [MSC.L["fire spell damage"]]    = "ITEM_MOD_FIRE_DAMAGE_SHORT",
    [MSC.L["frost spell damage"]]   = "ITEM_MOD_FROST_DAMAGE_SHORT",
    [MSC.L["arcane spell damage"]] = "ITEM_MOD_ARCANE_DAMAGE_SHORT",
    [MSC.L["nature spell damage"]] = "ITEM_MOD_NATURE_DAMAGE_SHORT",
    [MSC.L["holy spell damage"]]    = "ITEM_MOD_HOLY_DAMAGE_SHORT",
    [MSC.L["spell damage and healing"]] = "ITEM_MOD_SPELL_POWER_SHORT",  -- Fixes "of the Crusade", "of the Sorcerer"
    [MSC.L["damage and healing spells"]] = "ITEM_MOD_SPELL_POWER_SHORT", -- rare variation    
    
    -- Hunter / Range missing entries
    [MSC.L["ranged attack power"]] = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", -- Critical for "of the Falcon" variants if they split stats
    [MSC.L["spell penetration"]] = "ITEM_MOD_SPELL_PENETRATION_SHORT",
    [MSC.L["all stats"]] = "ITEM_MOD_ALL_STATS_SHORT", -- "of the Ancestors" or generic buffs
    [MSC.L["magic resistance"]] = "ITEM_MOD_ALL_RESISTANCE_SHORT", -- "of Resistance" (rare white text)
    
	-- Resources
    [MSC.L["mana per 5 sec."]] = "ITEM_MOD_MANA_REGENERATION_SHORT",
    [MSC.L["mana per 5 sec"]] = "ITEM_MOD_MANA_REGENERATION_SHORT",
    [MSC.L["health per 5 sec."]] = "ITEM_MOD_HEALTH_REGENERATION_SHORT",
    [MSC.L["health per 5 sec"]] = "ITEM_MOD_HEALTH_REGENERATION_SHORT",
    [MSC.L["mana regeneration"]] = "ITEM_MOD_MANA_REGENERATION_SHORT", -- Forever: "Equip: +5 Mana Regeneration" (= Classic "Restores 5 mana per 5 sec.")
    [MSC.L["health regeneration"]] = "ITEM_MOD_HEALTH_REGENERATION_SHORT", -- Forever
    [MSC.L["mana"]]            = "ITEM_MOD_MANA_SHORT",
    [MSC.L["health"]]          = "ITEM_MOD_HEALTH_SHORT",
    [MSC.L["hp"]]              = "ITEM_MOD_HEALTH_SHORT",
    [MSC.L["mp"]]              = "ITEM_MOD_MANA_SHORT",
    
    -- TBC Ratings
    [MSC.L["dodge rating"]]       = "ITEM_MOD_DODGE_RATING_SHORT",
    [MSC.L["parry rating"]]       = "ITEM_MOD_PARRY_RATING_SHORT",
    [MSC.L["block rating"]]       = "ITEM_MOD_BLOCK_RATING_SHORT",
    [MSC.L["hit rating"]]         = "ITEM_MOD_HIT_RATING_SHORT",
    [MSC.L["hit chance"]]         = "ITEM_MOD_HIT_RATING_SHORT",
    [MSC.L["critical strike chance"]] = "ITEM_MOD_CRIT_RATING_SHORT",
    [MSC.L["weapon damage"]]      = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",

    [MSC.L["crit rating"]]        = "ITEM_MOD_CRIT_RATING_SHORT",
    [MSC.L["critical strike rating"]] = "ITEM_MOD_CRIT_RATING_SHORT",
    [MSC.L["haste rating"]]       = "ITEM_MOD_HASTE_RATING_SHORT",
    [MSC.L["resilience rating"]] = "ITEM_MOD_RESILIENCE_RATING_SHORT",
    [MSC.L["defense rating"]]     = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    [MSC.L["expertise rating"]]   = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    [MSC.L["armor penetration rating"]] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
	[MSC.L["spell hit rating"]]   = "ITEM_MOD_HIT_SPELL_RATING_SHORT",
    [MSC.L["spell crit rating"]]  = "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
    [MSC.L["spell haste rating"]] = "ITEM_MOD_SPELL_HASTE_RATING_SHORT"
}

-- [[ B. GREEN TEXT MAP (Equip / Use / Proc Effects) ]]
MSC.Scanner.TermMap = {
    -- [[ 1. OFFENSIVE RATINGS ]]
    [MSC.L["hit rating"]]         = "ITEM_MOD_HIT_RATING_SHORT",
    [MSC.L["hit chance"]]         = "ITEM_MOD_HIT_RATING_SHORT",
    [MSC.L["critical strike chance"]] = "ITEM_MOD_CRIT_RATING_SHORT",
    [MSC.L["weapon damage"]]      = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",

    [MSC.L["chance to hit"]]      = "ITEM_MOD_HIT_RATING_SHORT", -- Era
    [MSC.L["spell hit rating"]]   = "ITEM_MOD_HIT_SPELL_RATING_SHORT",	
    [MSC.L["chance to hit with spells"]] = "ITEM_MOD_HIT_SPELL_RATING_SHORT", -- Era Long	
    [MSC.L["critical hit with spells"]] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
    [MSC.L["spell critical hit rating"]] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
    [MSC.L["chance to get a critical hit with spells"]] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT",	
    [MSC.L["critical strike rating"]] = "ITEM_MOD_CRIT_RATING_SHORT",
    [MSC.L["chance to get a critical strike"]] = "ITEM_MOD_CRIT_RATING_SHORT", -- Era
	[MSC.L["spell critical strike rating"]] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
    [MSC.L["critical strike with spells"]] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
    [MSC.L["chance to get a critical strike with spells"]] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT", 
    [MSC.L["haste rating"]]        = "ITEM_MOD_HASTE_RATING_SHORT",
    [MSC.L["spell haste rating"]] = "ITEM_MOD_SPELL_HASTE_RATING_SHORT",
    [MSC.L["spell penetration"]]   = "ITEM_MOD_SPELL_PENETRATION_SHORT",
    [MSC.L["magical resistances"]] = "ITEM_MOD_SPELL_PENETRATION_SHORT", -- Key for "Decreases" pattern
    [MSC.L["magical resistances of your spell targets"]] = "ITEM_MOD_SPELL_PENETRATION_SHORT", -- Era Long
    [MSC.L["armor penetration rating"]] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    [MSC.L["expertise rating"]]    = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    [MSC.L["dodged or parried"]] = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    [MSC.L["ranged attack power"]] = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",

    -- [[ 2. DEFENSIVE RATINGS ]]
    [MSC.L["defense rating"]]     = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    [MSC.L["increased defense"]] = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", -- Era
    [MSC.L["defense"]]            = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    [MSC.L["dodge rating"]]       = "ITEM_MOD_DODGE_RATING_SHORT",
    [MSC.L["chance to dodge"]]    = "ITEM_MOD_DODGE_RATING_SHORT", -- Era
    [MSC.L["parry rating"]]       = "ITEM_MOD_PARRY_RATING_SHORT",
    [MSC.L["chance to parry"]]    = "ITEM_MOD_PARRY_RATING_SHORT", -- Era
    [MSC.L["block rating"]]       = "ITEM_MOD_BLOCK_RATING_SHORT",
    [MSC.L["chance to block"]]    = "ITEM_MOD_BLOCK_RATING_SHORT", -- Era
    [MSC.L["shield block value"]] = "ITEM_MOD_BLOCK_VALUE_SHORT",
    [MSC.L["the block value of your shield"]] = "ITEM_MOD_BLOCK_VALUE_SHORT", -- Era Long
    [MSC.L["resilience rating"]] = "ITEM_MOD_RESILIENCE_RATING_SHORT",

    -- [[ 3. RESISTANCES ]]
    [MSC.L["shadow resistance"]] = "ITEM_MOD_SHADOW_RESISTANCE_SHORT",
    [MSC.L["fire resistance"]]    = "ITEM_MOD_FIRE_RESISTANCE_SHORT",
    [MSC.L["frost resistance"]]   = "ITEM_MOD_FROST_RESISTANCE_SHORT",
    [MSC.L["arcane resistance"]] = "ITEM_MOD_ARCANE_RESISTANCE_SHORT",
    [MSC.L["nature resistance"]] = "ITEM_MOD_NATURE_RESISTANCE_SHORT",
    [MSC.L["all resistances"]]    = "ITEM_MOD_ALL_RESISTANCE_SHORT",
    [MSC.L["resistance to all schools of magic"]] = "ITEM_MOD_ALL_RESISTANCE_SHORT", 

    -- [[ 4. POWER STATS ]]
    [MSC.L["attack power"]]       = "ITEM_MOD_ATTACK_POWER_SHORT",
    [MSC.L["attack power in cat"]] = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
    [MSC.L["feral attack power"]]   = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
    -- Forever: "Equip: +140 Attack Power in Cat, Bear, and Dire Bear forms only."
    [MSC.L["attack power in cat, bear, and dire bear forms only"]] = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
    [MSC.L["spell power"]]        = "ITEM_MOD_SPELL_POWER_SHORT",
    [MSC.L["healing"]]            = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    [MSC.L["mana per 5 sec"]]     = "ITEM_MOD_MANA_REGENERATION_SHORT",
    [MSC.L["health per 5 sec"]]   = "ITEM_MOD_HEALTH_REGENERATION_SHORT",
    [MSC.L["mana regeneration"]]  = "ITEM_MOD_MANA_REGENERATION_SHORT", -- Forever
    [MSC.L["health regeneration"]] = "ITEM_MOD_HEALTH_REGENERATION_SHORT", -- Forever

    -- [[ 5. ERA & TBC SPELL DAMAGE ]]
    [MSC.L["healing done by spells and effects"]] = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    [MSC.L["healing done by magical spells and effects"]] = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    
    [MSC.L["spell damage rating"]]            = "ITEM_MOD_SPELL_POWER_SHORT",
    [MSC.L["spell damage and healing"]]       = "ITEM_MOD_SPELL_POWER_SHORT",
	[MSC.L["spell dmg, heal"]] = "ITEM_MOD_SPELL_POWER_SHORT",
    [MSC.L["damage done by magical spells and effects"]] = "ITEM_MOD_SPELL_POWER_SHORT",
    [MSC.L["damage and healing done by magical spells and effects"]] = "ITEM_MOD_SPELL_POWER_SHORT",
    [MSC.L["damage and healing done by magical spells and effects by up to"]] = "ITEM_MOD_SPELL_POWER_SHORT", 
    
    [MSC.L["damage done by shadow spells and effects"]] = "ITEM_MOD_SHADOW_DAMAGE_SHORT",
    [MSC.L["damage done by fire spells and effects"]]   = "ITEM_MOD_FIRE_DAMAGE_SHORT",
    [MSC.L["damage done by frost spells and effects"]]  = "ITEM_MOD_FROST_DAMAGE_SHORT",
    [MSC.L["damage done by arcane spells and effects"]] = "ITEM_MOD_ARCANE_DAMAGE_SHORT",
    [MSC.L["damage done by nature spells and effects"]] = "ITEM_MOD_NATURE_DAMAGE_SHORT",
    [MSC.L["damage done by holy spells and effects"]]   = "ITEM_MOD_HOLY_DAMAGE_SHORT",
    [MSC.L["holy damage"]]     = "ITEM_MOD_HOLY_DAMAGE_SHORT",
    
    -- TBC Short Forms
    [MSC.L["shadow damage"]] = "ITEM_MOD_SHADOW_DAMAGE_SHORT",
    [MSC.L["fire damage"]]    = "ITEM_MOD_FIRE_DAMAGE_SHORT",
    [MSC.L["frost damage"]]   = "ITEM_MOD_FROST_DAMAGE_SHORT",
    [MSC.L["arcane damage"]] = "ITEM_MOD_ARCANE_DAMAGE_SHORT",
    [MSC.L["nature damage"]] = "ITEM_MOD_NATURE_DAMAGE_SHORT",
    [MSC.L["holy damage"]]    = "ITEM_MOD_HOLY_DAMAGE_SHORT",
    
    -- [[ 6. BASE STATS ]]
    [MSC.L["strength"]] = "ITEM_MOD_STRENGTH_SHORT",
    [MSC.L["agility"]]  = "ITEM_MOD_AGILITY_SHORT",
    [MSC.L["stamina"]]  = "ITEM_MOD_STAMINA_SHORT",
    [MSC.L["intellect"]]= "ITEM_MOD_INTELLECT_SHORT",
    [MSC.L["spirit"]]   = "ITEM_MOD_SPIRIT_SHORT",
    [MSC.L["armor"]]    = "ITEM_MOD_ARMOR_SHORT",
    [MSC.L["mana"]]     = "ITEM_MOD_MANA_SHORT",
    [MSC.L["health"]]   = "ITEM_MOD_HEALTH_SHORT",
    
    -- [[ 7. WEAPON SKILLS ]]
    [MSC.L["swords"]]    = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["axes"]]      = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["maces"]]     = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["daggers"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["bows"]]      = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["crossbows"]]= "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["guns"]]      = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["staves"]]    = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["polearms"]]    = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["two-handed swords"]] = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["two-handed axes"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["two-handed maces"]]  = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["skill with swords"]] = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["skill with axes"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["skill with maces"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["skill with bows"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["skill with guns"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["skill with daggers"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["skill with crossbows"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["skill with staves"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["skill with polearms"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["skill with fist weapons"]] = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    -- Forever's short form: "Equip: +3 Daggers Skill".
    [MSC.L["swords skill"]]            = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["axes skill"]]              = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["maces skill"]]             = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["daggers skill"]]           = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["fist weapons skill"]]      = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["polearms skill"]]          = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["staves skill"]]            = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["bows skill"]]              = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["guns skill"]]              = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["crossbows skill"]]         = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["two-handed swords skill"]] = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["two-handed axes skill"]]   = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",
    [MSC.L["two-handed maces skill"]]  = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT",

    -- [[ TBC: THE "RANGED" & "SHIELD" VARIANTS ]]
    [MSC.L["ranged critical strike rating"]] = "ITEM_MOD_CRIT_RATING_SHORT",
    [MSC.L["ranged hit rating"]]              = "ITEM_MOD_HIT_RATING_SHORT",
    [MSC.L["ranged haste rating"]]            = "ITEM_MOD_HASTE_RATING_SHORT",
    [MSC.L["shield block rating"]]            = "ITEM_MOD_BLOCK_RATING_SHORT",
    [MSC.L["shield block value"]]             = "ITEM_MOD_BLOCK_VALUE_SHORT",
    
    -- [[ TBC: PET STATS (Warlock/Hunter Trinkets & Set Bonuses) ]]
    [MSC.L["your pet's armor"]]               = "ITEM_MOD_ARMOR_SHORT", -- Handled loosely, but good to catch
    [MSC.L["your pet's attack power"]]        = "ITEM_MOD_ATTACK_POWER_SHORT",
    [MSC.L["your pet's damage"]]              = "ITEM_MOD_ATTACK_POWER_SHORT",
        
    -- [[ WEIRD / EDGE CASE CATCHERS ]]
    [MSC.L["all stats"]]                      = "ITEM_MOD_ALL_STATS_SHORT",
    [MSC.L["magic resistance"]]               = "ITEM_MOD_ALL_RESISTANCE_SHORT",
    [MSC.L["chance to resist mechanic mechanics"]] = "ITEM_MOD_RESILIENCE_RATING_SHORT",
}

-- Forever prints three separate spell stats: "+X Spell Power" (damage AND
-- healing), "+X Healing", and "+X Spell Damage" (damage only -- Classic
-- healing gear was split into +Healing plus a third as +Spell Damage, e.g.
-- Holy Shroud: +33 Healing / +11 Spell Damage). Keep Spell Damage out of
-- ITEM_MOD_SPELL_POWER_SHORT so the Evaluator doesn't fold it into healing.
if MSC.IsForever then
    MSC.Scanner.BaseStatMap[MSC.L["spell damage"]] = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"
    MSC.Scanner.TermMap[MSC.L["spell damage"]] = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"
end

-- =============================================================
-- 2. PATTERN DATABASE (Merged)
-- =============================================================

MSC.Scanner.StatPatterns = {
    -- [[ 1. STANDARD PREFIX]]
    -- Catches: "+14 Spell Damage", "14 Strength", "+ 14 Intellect"
    { p = MSC.L["^[%+]?%s*(%d+%.?%d*)%s+(.-)[%s%.]*$"], valIdx = 1, nameIdx = 2 },

    -- [[ 2. STANDARD SUFFIX]]
    -- Catches: "Strength +14", "Agility 14", "Speed 2.80"
    { p = MSC.L["^(.-)%s+[%+:]?%s*(%d+%.?%d*)[%s%.]*$"], valIdx = 2, nameIdx = 1 },
    
    -- [[ 3. SHORT STATS ]]
    -- These specific strings don't need dictionary lookups
    { p = MSC.L["^(%d+) armor$"], valIdx = 1, fixedStat = "ITEM_MOD_ARMOR_SHORT" },
    { p = MSC.L["^(%d+) block$"], valIdx = 1, fixedStat = "ITEM_MOD_BLOCK_VALUE_SHORT" },

    -- [[ 4. WEAPON & DPS ]]
    -- (Translations capture "2,60" too: German, French, Spanish, Portuguese
    -- and Russian tooltips write the decimal with a comma; ScanNum reads it.)
    { p = MSC.L["speed (%d+%.?%d*)"], valIdx = 1, fixedStat = "MSC_WEAPON_SPEED" },
    { p = MSC.L["^%((%d+%.?%d*) damage per second%)$"], valIdx = 1, fixedStat = "MSC_WEAPON_DPS" },
    { p = MSC.L["^%((%d+%.?%d*) dps%)$"], valIdx = 1, fixedStat = "MSC_WEAPON_DPS" },
    
    -- Range: Covers "100 - 200 Damage" and "100-200 Damage"
    { p = MSC.L["^(%d+)%s?[-~]%s?(%d+) damage$"], type="RANGE" },
    
    -- [[ 5. ENCHANT/SCOPE FORMATS ]]
    { p = MSC.L["scope %([%+:]*(%d+) (.*)%)"], valIdx = 1, nameIdx = 2 },
    { p = MSC.L["enchant:? [%+:]*(%d+) (.*)"], valIdx = 1, nameIdx = 2 },
	
	-- [[ 6. SPLIT ENCHANTS ]]
    { p = MSC.L["(%d+) hit rating and .*snare"], valIdx = 1, fixedStat = "ITEM_MOD_HIT_RATING_SHORT" },
}

-- [[ BONUSES AGAINST ONE CREATURE TYPE ]]
-- "+9 Attack Power Vs Humanoids", "+81 Attack Power when fighting Undead",
-- "+3 Spell Damage Vs Undead". Counted at the share of the mobs you fight
-- while leveling that are of that type: the hostile open-world mobs of the
-- Classic world database weighted by spawns (2026-10-21; was a rough guess of
-- Humanoids 35%, Beasts 30%, Undead 15%). Below 50 Beasts and Humanoids are
-- about 45% / 42% each with little else; from 50 (Plaguelands, Burning
-- Steppes, Felwood) Undead rise to 17% and Demons / Elementals to 6%.
local CREATURE_SHARE = {
    low = {
        humanoids = 0.42, humanoid = 0.42, beasts = 0.45, beast = 0.45, undead = 0.03,
        demons = 0.02, demon = 0.02, elementals = 0.04, elemental = 0.04,
        mechanical = 0.01, dragonkin = 0.02, giants = 0.01, giant = 0.01,
    },
    high = {
        humanoids = 0.28, humanoid = 0.28, beasts = 0.33, beast = 0.33, undead = 0.17,
        demons = 0.06, demon = 0.06, elementals = 0.06, elemental = 0.06,
        mechanical = 0.01, dragonkin = 0.01, giants = 0.01, giant = 0.01,
    },
}
MSC.Scanner.CreatureShare = CREATURE_SHARE.low
local creatureLookup, creatureBand
local function CreatureShare(name)
    local band = ((UnitLevel and UnitLevel("player")) or 1) >= 50 and "high" or "low"
    if band ~= creatureBand then
        creatureBand = band; creatureLookup = nil
        MSC.Scanner.CreatureShare = CREATURE_SHARE[band]
    end
    if not creatureLookup then
        creatureLookup = {}
        for k, v in pairs(MSC.Scanner.CreatureShare) do creatureLookup[#creatureLookup + 1] = { string_lower(MSC.L[k]), v } end
        -- Longest names first, so "demons" is found before "demon".
        table.sort(creatureLookup, function(a, b) return #a[1] > #b[1] end)
    end
    name = string_gsub(string_lower(name or ""), "[%s%.]+$", "")
    for _, c in ipairs(creatureLookup) do
        if name == c[1] then return c[2] end
    end
    -- "Undead and Demons": add up every type named, each once.
    local share = 0
    for _, c in ipairs(creatureLookup) do
        local a, b = string_find(name, c[1], 1, true)
        if a then
            share = share + c[2]
            name = string.sub(name, 1, a - 1) .. "|" .. string.sub(name, b + 1)
        end
    end
    return share > 0 and share or nil
end
local function AddVsCreature(stat)
    return function(val, creature, _, outputStats)
        -- Some languages put the creature first ("언데드에 대한 전투력 +9").
        if not ScanNum(val) and ScanNum(creature) then val, creature = creature, val end
        if not outputStats then return false end
        -- A creature type we don't know: the line is still this kind of bonus,
        -- so it's used up here (scoring 0) instead of reaching other patterns.
        local share = CreatureShare(creature)
        if not share then return end
        outputStats[stat] = (outputStats[stat] or 0) + (ScanNum(val) or 0) * share
    end
end
local function AddSpellVsCreature(creature, val, _, outputStats)
    if ScanNum(creature) and not ScanNum(val) then creature, val = val, creature end
    -- "Increases damage done to Undead by magical spells and effects by up to 48."
    return AddVsCreature(MSC.IsForever and "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" or "ITEM_MOD_SPELL_POWER_SHORT")(val, creature, nil, outputStats)
end

MSC.Scanner.EquipPatterns = {
    -- ========================================================================
    -- [[ 0. BONUSES AGAINST ONE CREATURE TYPE (see CreatureShare above) ]]
    -- ========================================================================
    { p = MSC.L["^%+(%d+) attack power vs (.+)$"], func = AddVsCreature("ITEM_MOD_ATTACK_POWER_SHORT") },
    { p = MSC.L["^%+(%d+) attack power when fighting (.+)$"], func = AddVsCreature("ITEM_MOD_ATTACK_POWER_SHORT") },
    { p = MSC.L["^%+(%d+) spell damage vs (.+)$"], func = function(v, c, _, o) return AddVsCreature(MSC.IsForever and "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" or "ITEM_MOD_SPELL_POWER_SHORT")(v, c, nil, o) end },
    { p = MSC.L["damage done to (.-) by magical spells and effects by up to (%d+)"], func = AddSpellVsCreature },

    -- ========================================================================
    -- [[ 1. SPECIALIZED OVERRIDES (Higher Priority / Lazy Matching) ]]
    -- ========================================================================

    -- [[ MANA / HEALTH PER 5 ]]
    -- Era/TBC print Mp5/Hp5 as "Equip: Restores 5 mana per 5 sec." (TBC's
    -- ITEM_MOD_MANA_REGENERATION / _HEALTH_REGENERATION). Without these the
    -- line fell through to "Proc not yet modeled" and scored 0. Forever's
    -- "+5 Mana Regeneration" is read by the short form at the bottom.
    { p = MSC.L["restores (%d+) mana per 5"], valIdx = 1, fixedStat = "ITEM_MOD_MANA_REGENERATION_SHORT" },
    { p = MSC.L["restores (%d+) health per 5"], valIdx = 1, fixedStat = "ITEM_MOD_HEALTH_REGENERATION_SHORT" },
    -- Some items word it "Restores 10 health every 5 sec." (Lifestone)
    { p = MSC.L["restores (%d+) mana every 5"], valIdx = 1, fixedStat = "ITEM_MOD_MANA_REGENERATION_SHORT" },
    { p = MSC.L["restores (%d+) health every 5"], valIdx = 1, fixedStat = "ITEM_MOD_HEALTH_REGENERATION_SHORT" },

    -- [[ FERAL ATTACK POWER (TBC) ]]
    -- "Increases attack power by 140 in Cat, Bear, Dire Bear, and Moonkin forms
    -- only." (ITEM_MOD_FERAL_ATTACK_POWER) -- must beat the generic
    -- "increases (.*) by (%d+)" below, which read it as normal Attack Power.
    { p = MSC.L["attack power by (%d+) in cat"], valIdx = 1, fixedStat = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT" },

    -- [[ HYBRID HEAL/DAMAGE SPLIT ]]
    { p = MSC.L["healing.-(%d+).-damage.-(%d+)"], 
      func = function(heal, dmg, _, outputStats) 
          if outputStats then
              local h = ScanNum(heal) or 0
              local d = ScanNum(dmg) or 0
              outputStats["ITEM_MOD_SPELL_POWER_SHORT"] = (outputStats["ITEM_MOD_SPELL_POWER_SHORT"] or 0) + d
              local bonus = h - d
              if bonus > 0 then
                  outputStats["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = (outputStats["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or 0) + bonus
              end
          end
      end 
    },
    
    -- [[ ELEMENTAL DAMAGE (Must be checked BEFORE generic spell damage) ]]
    -- upTo: the lazy ".-(%d+)" takes the first number on the line, which on a
    -- party aura ("...of all party members within 30 yards by up to 62") is
    -- the range; the "by up to N" amount wins when the line has one.
    { p = MSC.L["shadow damage.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_SHADOW_DAMAGE_SHORT", upTo = true },
    { p = MSC.L["fire damage.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_FIRE_DAMAGE_SHORT", upTo = true },
    { p = MSC.L["frost damage.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_FROST_DAMAGE_SHORT", upTo = true },
    { p = MSC.L["arcane damage.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_ARCANE_DAMAGE_SHORT", upTo = true },
    { p = MSC.L["nature damage.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_NATURE_DAMAGE_SHORT", upTo = true },
    { p = MSC.L["holy damage.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_HOLY_DAMAGE_SHORT", upTo = true },

    -- [[ CASTING STATS ]]
    { p = MSC.L["damage and healing.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_SPELL_POWER_SHORT", upTo = true },
    { p = MSC.L["damage done by magical.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_SPELL_POWER_SHORT", upTo = true },
    { p = MSC.L["damage done by spells.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_SPELL_POWER_SHORT", upTo = true },
    { p = MSC.L["spell damage.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_SPELL_POWER_SHORT", upTo = true },
    { p = MSC.L["spell power.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_SPELL_POWER_SHORT", upTo = true },
    { p = MSC.L["healing done.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", upTo = true },
    { p = MSC.L["healing.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", upTo = true },
    { p = MSC.L["spell penetration.-(%d+)"], valIdx = 1, fixedStat = "ITEM_MOD_SPELL_PENETRATION_SHORT" },

    -- ========================================================================
    -- [[ 2. COMPLEX / LOGIC PATTERNS (Cannot be Lazy) ]]
    -- ========================================================================

    -- [[ HYBRID HEAL/DAMAGE SPLIT ]]
    { p = MSC.L["healing.-(%d+).-damage.-(%d+)"], 
      func = function(heal, dmg, _, outputStats) 
          if outputStats then
              local h = ScanNum(heal) or 0
              local d = ScanNum(dmg) or 0
              outputStats["ITEM_MOD_SPELL_POWER_SHORT"] = (outputStats["ITEM_MOD_SPELL_POWER_SHORT"] or 0) + d
              local bonus = h - d
              if bonus > 0 then
                  outputStats["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = (outputStats["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or 0) + bonus
              end
          end
      end 
    },

    -- [[ WEAPON DAMAGE (Scopes, Rings) ]]
    { p = MSC.L["adds (%d+) weapon damage"], valIdx = 1, fixedStat = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" },
    { p = MSC.L["adds (%d+) damage"], valIdx = 1, fixedStat = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" },

    -- [[ PERCENTAGE MODS (e.g. "1% Hit") ]]
    -- Caught here to prevent "1 Hit" being read as Rating
    { p = MSC.L["improves your (.*) by ([%d%.]+)%%%.?"], valIdx = 2, nameIdx = 1, isPercent = true }, 
    { p = MSC.L["increases your (.*) by ([%d%.]+)%%%.?"], valIdx = 2, nameIdx = 1, isPercent = true }, 
    { p = MSC.L["increases (.*) by ([%d%.]+)%%%.?"], valIdx = 2, nameIdx = 1, isPercent = true },
    { p = MSC.L["reduces chance for attacks to be (.*) by ([%d%.]+)%%%.?"], valIdx = 2, nameIdx = 1, isPercent = true },

    -- [[ WEAPON SKILLS (Forever) ]]
    { p = MSC.L["%+([%d%.]+)%s+to%s+(.*)"], valIdx = 1, fixedStat = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT" },

    -- [[ GENERIC FALLBACKS (The "Standard" Parser) ]]
    -- Catches standard strings: "Increases Strength by 10"
    { p = MSC.L["improves your (.*) by (%d+)%.?"], valIdx = 2, nameIdx = 1 }, 
    { p = MSC.L["improves (.*) by (%d+)%.?"], valIdx = 2, nameIdx = 1 }, 
    { p = MSC.L["increases your (.*) by (%d+)%.?"], valIdx = 2, nameIdx = 1 }, 
    { p = MSC.L["increases (.*) by up to (%d+)%.?"], valIdx = 2, nameIdx = 1 },
    { p = MSC.L["increases (.*) by (%d+)%.?"], valIdx = 2, nameIdx = 1 },

    -- [[ SHORT FORM (Green Text) ]]
    -- Catches: "+10 Strength" or "Strength +10"
    { p = MSC.L["^%+?%s*([%d%.]+)%%? (.*)$"], valIdx = 1, nameIdx = 2 },
    { p = MSC.L["^(.-) %+([%d%.]+)%%?$"], valIdx = 2, nameIdx = 1 },
}

MSC.Scanner.ProcPatterns = {
    -- Buffs
    { p = MSC.L["^%+(%d+) (.*) for (%d+) sec"], valIdx=1, nameIdx=2, durIdx=3, type="BUFF" },
    { p = MSC.L["grants (%d+) (.*) for (%d+) sec"], valIdx=1, nameIdx=2, durIdx=3, type="BUFF" },
    { p = MSC.L["gain (%d+) (.*) for (%d+) sec"], valIdx=1, nameIdx=2, durIdx=3, type="BUFF" },
    { p = MSC.L["increases (.*) by (%d+) for (%d+) sec"], valIdx=2, nameIdx=1, durIdx=3, type="BUFF" },
    { p = MSC.L["increases your (.*) by (%d+)$"], valIdx=2, nameIdx=1, type="BUFF", defaultDur=10 },
    { p = MSC.L["chance on melee or ranged hit to gain (%d+) (.*) for (%d+) sec"], valIdx=1, nameIdx=2, durIdx=3, type="BUFF" },
    { p = MSC.L["chance on spell critical hit to gain (%d+) (.*) for (%d+) sec"], valIdx=1, nameIdx=2, durIdx=3, type="BUFF" },
    { p = MSC.L["chance on spell cast to gain (%d+) (.*) for (%d+) sec"], valIdx=1, nameIdx=2, durIdx=3, type="BUFF" },    

    -- Damage Procs
    { p = MSC.L["for (%d+) to (%d+) .*damage"], type="DAMAGE" },
    { p = MSC.L["inflicts (%d+) to (%d+) .*damage"], type="DAMAGE" },
    { p = MSC.L["for (%d+) .*damage"], type="DAMAGE" },
    { p = MSC.L["inflicts (%d+) .*damage"], type="DAMAGE" },
    { p = MSC.L["deals (%d+) .*damage"], type="DAMAGE" },
    { p = MSC.L["blasts (.*) for (%d+)"], valIdx=2, type="DAMAGE" },
    { p = MSC.L["chance to strike your enemy for (%d+) to (%d+) .*damage"], type="DAMAGE" },
    { p = MSC.L["chance to blast your target for (%d+) to (%d+) .*damage"], type="DAMAGE" },

    -- Resources
    { p = MSC.L["steals (%d+) life"], type="HEAL" },
    { p = MSC.L["restores (%d+) mana"], type="MANA" },
    { p = MSC.L["restores (%d+) health"], type="HEAL" },
    
    -- Catch All
    { p = MSC.L["blasts your enemy"], type="GENERIC" }
}

MSC.Scanner.UsePatterns = {
    -- Short Forms
    { p = MSC.L["^%+(%d+) (.*) for (%d+) sec"], valIdx=1, nameIdx=2, durIdx=3, type="BUFF" },
    { p = MSC.L["^%+(%d+) (.*)$"], valIdx=1, nameIdx=2, type="BUFF", defaultDur=15 },

    -- Verbs
    { p = MSC.L["grants (%d+) (.*) for (%d+) sec"], valIdx=1, nameIdx=2, durIdx=3, type="BUFF" },
    { p = MSC.L["gain (%d+) (.*) for (%d+) sec"], valIdx=1, nameIdx=2, durIdx=3, type="BUFF" },
    { p = MSC.L["increases (.*) by up to (%d+) for (%d+) sec"], valIdx=2, nameIdx=1, durIdx=3, type="BUFF" },
    { p = MSC.L["increases (.*) by (%d+) for (%d+) sec"], valIdx=2, nameIdx=1, durIdx=3, type="BUFF" },

    -- Resources
    -- "Restores 30 mana every 1 sec for 10 sec." is 300 mana, not 30 (Second Wind)
    { p = MSC.L["restores (%d+) mana every (%d+) sec for (%d+) sec"], type="MANA_TICK" },
    { p = MSC.L["restores (%d+) health every (%d+) sec for (%d+) sec"], type="HEALTH_TICK" },
    { p = MSC.L["restores (%d+) to (%d+) mana"], type="MANA_RANGE" },
    { p = MSC.L["restores (%d+) to (%d+) health"], type="HEALTH_RANGE" },
    { p = MSC.L["restores (%d+) mana"], valIdx=1, type="MANA" },
    { p = MSC.L["restores (%d+) health"], valIdx=1, type="HEALTH" },

    -- Misc
    { p = MSC.L["adds (%d+) damage"], valIdx=1, fixedStat="ITEM_MOD_DAMAGE_PER_SECOND_SHORT", type="BUFF", defaultDur=15 }
}

-- =============================================================
-- 3. UTILITIES
-- =============================================================

local function CreateItemObject()
    return { 
        Stats = {}, UseEffects = {}, Procs = {}, 
        Meta = { 
            SetName=nil, SetCount=0, SetTotal=0, Sockets={}, SocketBonusActive=false, BonusStats={} 
        } 
    }
end

-- [[ DAMAGE PROCS WITHOUT A CURATED ENTRY ]]
-- Average damage of one trigger, or nil when the effect isn't plain damage
-- (heals, shields, mana, debuffs). The first damage number in the line wins,
-- so later conditions ("Deals 2 times as much damage to Naga.") are ignored.
-- Helpers turns it into Attack Power with ProcRate and AP_PER_DPS.
MSC.Scanner.ProcRate = {
    onHit = 1.0,     -- "Chance on hit:": the classic 1 proc per minute
    struck = 20,     -- "When struck": hits taken per minute (about one every 3 sec)
    swing = 24,      -- "Your melee attacks deal X": one per swing at 2.5 speed
}
MSC.Scanner.AP_PER_DPS = 14

-- Which capture of the damage-over-time pattern is which. Languages that word
-- it in another order ("fügt 12 sek. lang alle 3 sek. 7 punkt(e) schaden zu")
-- translate this key to list the captures in their own order.
local dotOrder
local function DotOrder()
    if not dotOrder then
        dotOrder = {}
        local v = string_match(MSC.L["dot captures: damage every duration"], ":%s*(.*)$") or ""
        local i = 0
        for w in string.gmatch(v, "%a+") do i = i + 1; dotOrder[w] = i end
        if not (dotOrder.damage and dotOrder.every and dotOrder.duration) then
            dotOrder = { damage = 1, every = 2, duration = 3 }
        end
    end
    return dotOrder
end

function MSC.Scanner.ProcDamage(cleanText)
    local s = cleanText
    for _, w in ipairs({ "heal", "absorb", "shield", "restor", "mana", "life", "sleep", "invulnerab" }) do
        if string_find(s, string_lower(MSC.L[w]), 1, true) then return nil end
    end
    -- Damage over time ("7 Nature damage every 3 sec for 12 sec"); any direct
    -- damage is looked for only before it ("Inflict 42 Fire and 14 Frost
    -- damage, ..., and inflict 7 Nature damage every 3 sec for 12 sec").
    local dmg
    local at, _, c1, c2, c3 = string_find(s, MSC.L["(%d+) [^%d]-damage every (%d+) sec for (%d+) sec"])
    if at then
        local c, o = { ScanNum(c1), ScanNum(c2), ScanNum(c3) }, DotOrder()
        local n, every, dur = c[o.damage], c[o.every], c[o.duration]
        if n and every and dur then
            dmg = n * math_floor(dur / math.max(1, every))
            s = string.sub(s, 1, at - 1)
        end
    end
    local direct
    local lo, hi = string_match(s, MSC.L["(%d+) to (%d+) [^%d]-damage"])
    if lo then direct = (ScanNum(lo) + ScanNum(hi)) / 2
    else
        local a, b = string_match(s, MSC.L["(%d+) [^%d]- and (%d+) [^%d]-damage"])
        if a then direct = ScanNum(a) + ScanNum(b)
        else direct = ScanNum(string_match(s, MSC.L["(%d+) [^%d]-damage"])) end
    end
    if direct then dmg = (dmg or 0) + direct end
    if not dmg then return nil end
    local extra = ScanNum(string_match(s, MSC.L["additional (%d+) damage"]))
    return dmg + (extra or 0)
end

local function ParseCooldown(text)
    local lowerText = string_lower(text)
    local min = string_match(lowerText, MSC.L["%((%d+)%s*min[s%a]*%s*cooldown%)"] or "%((%d+)%s*min[s%a]*%s*cooldown%)")
	if min then return ScanNum(min) * 60 end
	local sec = string_match(lowerText, MSC.L["%((%d+)%s*sec[s%a]*%s*cooldown%)"] or "%((%d+)%s*sec[s%a]*%s*cooldown%)")
    if sec then return ScanNum(sec) end
    return 120 
end

-- Stat key for the name part of an Equip/Use line ("strength", "chance to
-- dodge an attack", "the block value of your shield").
local function EscapePattern(s) return (string_gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
local yourPrefix, termFragments
function MSC.Scanner.LookupTerm(name, allowFragments)
    if not name then return nil end
    local TermMap, BaseStatMap = MSC.Scanner.TermMap, MSC.Scanner.BaseStatMap
    if not yourPrefix then
        yourPrefix = "^" .. EscapePattern(string_lower(MSC.L["your "]))
        -- Era avoidance lines name more than the stat: "chance to dodge an
        -- attack", "chance to parry an attack", "chance to block attacks with
        -- a shield". Matched by the stat's own phrase inside the name.
        termFragments = {
            { string_lower(MSC.L["chance to dodge"]), "ITEM_MOD_DODGE_RATING_SHORT" },
            { string_lower(MSC.L["chance to parry"]), "ITEM_MOD_PARRY_RATING_SHORT" },
            { string_lower(MSC.L["chance to block"]), "ITEM_MOD_BLOCK_RATING_SHORT" },
        }
    end
    -- Strip a LEADING "your " only: stripping it anywhere broke names that
    -- contain it ("the block value of your shield" became "the block value
    -- of shield" and matched nothing).
    local raw = string_gsub(name, "[%s%.]+$", "")
    local cleanName = string_gsub(string_gsub(raw, "^your ", ""), yourPrefix, "")
    local key = TermMap[cleanName] or BaseStatMap[cleanName] or TermMap[raw] or BaseStatMap[raw]
    if key or not allowFragments then return key end
    for _, f in ipairs(termFragments) do
        if f[1] ~= "" and string_find(cleanName, f[1], 1, true) then return f[2] end
    end
    return nil
end

-- "Unique-Equipped" (and TBC's "Unique-Equipped: <category> (n)") contain the
-- word "equip" but aren't effects.
local function IsUniqueEquippedLine(text)
    if ITEM_UNIQUE_EQUIPPABLE and ITEM_UNIQUE_EQUIPPABLE ~= "" and string_find(text, ITEM_UNIQUE_EQUIPPABLE, 1, true) == 1 then return true end
    for _, fmt in ipairs({ ITEM_LIMIT_CATEGORY_MULTIPLE, ITEM_LIMIT_CATEGORY }) do
        if type(fmt) == "string" then
            local prefix = string_match(fmt, "^([^%%]+)")
            if prefix and #prefix > 3 and string_find(text, prefix, 1, true) == 1 then return true end
        end
    end
    return false
end

function MSC.Scanner.ClassifyLine(text)
    if not text or MSC_IsSecret(text) or text == "" then return "SKIP" end
    local lower = string_lower(text)

    -- Binding lines ("Binds when equipped" contains "equip") aren't effects;
    -- without this they fell through as unmodeled procs on every BoE item.
    if text == ITEM_BIND_ON_EQUIP or text == ITEM_BIND_ON_PICKUP or text == ITEM_BIND_ON_USE
        or text == ITEM_SOULBOUND or string_find(lower, "^binds ") then
        return "FLUFF"
    end
    if IsUniqueEquippedLine(text) then return "FLUFF" end

    -- [[ OPTIMIZATION: SIMPLE CHECKS FIRST ]]
    -- Set bonuses first: "(4) Set: Chance on damaging spell..." is a set bonus
    -- (scored from the set tables), not a proc of this item.
    if string_find(lower, MSC.L["set:"]) then return "SET" end
	if string_find(lower, MSC.L["chance on"]) then return "PROC" end
    if string_find(lower, MSC.L["equip"]) then return "EQUIP" end
    if string_find(lower, MSC.L["use:"]) then return "USE" end
    local cleanForSet = string_gsub(string_gsub(lower, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
    if string_match(cleanForSet, "%((%d+)/(%d+)%)") then return "SET" end
    if string_find(lower, MSC.L["socket"]) then 
        if string_find(lower, MSC.L["bonus"]) then return "SOCKET_BONUS" else return "SOCKET_INFO" end
    end
    
    -- Clean text for Stat Checks
    local cleanText = string_gsub(string_gsub(lower, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
    if string_find(cleanText, "%d") then return "STAT" end
    
    return "FLUFF"
end

-- =============================================================
-- 4. SUB-PARSERS
-- =============================================================

function MSC.Scanner.ParseSetHeader(text, metaTable)
    local cleanText = string_gsub(string_gsub(text, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
    local setName, current, total = string_match(cleanText, MSC.L["^(.*)%s+%(?(%d+)/(%d+)%)?$"])
    if setName then 
        metaTable.SetName = string_gsub(setName, "^%s*(.-)%s*$", "%1")
        metaTable.SetCount = ScanNum(current)
        metaTable.SetTotal = ScanNum(total)
        return true
    end
end

-- Negative stat lines (2026-11-09, checked over every Forever item: cursed gear like Cursed Eye of Paleth "-3 Stamina" or
-- Fletcher's Gloves "Equip: -15 Parry Rating" read as nothing): parse the line with its minus turned into a plus into a
-- scratch table, then take those stats off. Returns true when the line was one.
local function ParseNegated(cleanText, parse, outputTable)
    local rest = string_match(cleanText, "^%-%s*(%d.*)$")
    if not rest then return false end
    local tmp = {}
    parse("+" .. rest, tmp)
    for k, v in pairs(tmp) do
        if type(v) == "number" then outputTable[k] = (outputTable[k] or 0) - v end
    end
    return true
end

function MSC.Scanner.ParseEquipLine(text, outputStats, outputProcs)
    local cleanText = string_gsub(string_gsub(string_gsub(string_gsub(string_lower(text), "|c%x%x%x%x%x%x%x%x", ""), "|r", ""), "\n", " "), MSC.L["^equip: "], "")
    cleanText = string_gsub(string_gsub(cleanText, "%s+", " "), MSC.L["^%s*equip:%s*"], "")
    if ParseNegated(cleanText, function(t, o) MSC.Scanner.ParseEquipLine(t, o, nil) end, outputStats) then return end

    -- [[ PROCS & BUFFS ESCAPE HATCH ]]
    -- Prevents temporary buffs from being read as permanent passive stats.
    local isTemporary = false
    -- Matched against the lower-cased line (Lua lower-cases ASCII only).
    local durationMarkers = {
        " for %d+ sec",          -- English
        " für %d+ sek",          -- German
        " pendant %d+ s",        -- French
        " durante %d+ s",        -- Spanish
        " por %d+ s",            -- Portuguese
        " на %d+ сек",           -- Russian
        "%d+초 동안",             -- Korean
        "持續%s*%d+%s*秒",        -- Traditional Chinese
    }
    for _, marker in ipairs(durationMarkers) do
        if string_match(cleanText, marker) then
            isTemporary = true
            break
        end
    end
    
    if isTemporary then
        if outputProcs then table_insert(outputProcs, { type = "Equip Proc", desc = text }) end
        return
    end

    -- [[ DAMAGE WHEN STRUCK / ON EVERY SWING ]]
    -- "When struck in combat, inflicts 2 Nature damage to the attacker",
    -- "...has a 5% chance of inflicting 35 to 65 Nature damage...", "Your melee
    -- weapon attacks deal 2 Nature damage to both you and your target".
    if outputProcs then
        local perMin, struck
        if string_find(cleanText, string_lower(MSC.L["when struck"]), 1, true) then
            struck = true -- thorns: only worth something to whoever gets hit (Helpers MSC_THORNS_AP)
            local chance = ScanNum(string_match(cleanText, MSC.L["(%d+)%% chance"]))
            perMin = MSC.Scanner.ProcRate.struck * (chance or 100) / 100
        elseif string_find(cleanText, MSC.L["^chance to "]) and not string_match(cleanText, MSC.L["(%d+)%% chance"]) then
            perMin = MSC.Scanner.ProcRate.onHit -- worded without "Chance on hit:" (Heart of Wyrmthalak)
        elseif string_find(cleanText, string_lower(MSC.L["attacks deal"]), 1, true) and not string_find(cleanText, string_lower(MSC.L["against"]), 1, true)
            and not string_match(cleanText, MSC.L["(%d+)%% chance"]) then
            perMin = MSC.Scanner.ProcRate.swing
            -- It hurts you as much as the target: count half.
            if string_find(cleanText, string_lower(MSC.L["both you and"]), 1, true) then perMin = perMin / 2 end
        end
        local dmg = perMin and MSC.Scanner.ProcDamage(cleanText)
        if dmg then
            table_insert(outputProcs, { type = "Damage", val = dmg, perMin = perMin, struck = struck, description = text })
            return
        end
    end

    for _, pat in ipairs(MSC.Scanner.EquipPatterns) do
        local match1, match2, match3 = string_match(cleanText, pat.p)
        -- A func returning false didn't recognize the line; try the next pattern.
        if match1 and pat.func then
            if pat.func(match1, match2, match3, outputStats) ~= false then return end
        elseif match1 then
            local val, name = MSC.Scanner.OrderCaptures(pat, match1, match2)
            if not pat.nameIdx then name = nil end
            if pat.upTo then
                local upTo = ScanNum(string_match(cleanText, MSC.L["by up to (%d+)"]))
                if upTo then val = upTo end
            end

            if val and pat.isPercent and MSC.IsTBC then
                local mult = 15.8 
                if name then
                    if string_find(name, MSC.L["spell"]) then 
                        mult = (string_find(name, MSC.L["hit"]) and 12.6 or 22.1)
                    elseif string_find(name, MSC.L["crit"]) then 
                        mult = 22.1
                    elseif string_find(name, MSC.L["speed"]) or string_find(name, MSC.L["haste"]) then 
                        mult = 15.8
                    end
                end
                val = val * mult
            end

            if pat.fixedStat then
                outputStats[pat.fixedStat] = (outputStats[pat.fixedStat] or 0) + (val or 1)
                return
            elseif val and name then
                local key = MSC.Scanner.LookupTerm(name, true)
                -- Forever prints weapon skill as points ("+3 Daggers Skill"), but its
                -- stat is Weapon Skill Rating (2.5 per point, CombatRatingScalars[1]),
                -- which the scorer converts back to points.
                if key == "ITEM_MOD_WEAPON_SKILL_RATING_SHORT" and MSC.IsForever
                    and not string_find(name, string_lower(MSC.L["rating"]), 1, true) then
                    local s = MSC.CombatRatingScalars and MSC.CombatRatingScalars[60]
                    val = val * ((s and s[1]) or 2.5)
                end
                if key then outputStats[key] = (outputStats[key] or 0) + val; return end
            end
        end
    end
    if outputProcs then table_insert(outputProcs, { type = "Equip", desc = text }) end
end

function MSC.Scanner.ParseStatLine(text, outputTable)
    if not text then return end

    local cleanText = string_lower(text)
    cleanText = string_gsub(cleanText, "|c%x%x%x%x%x%x%x%x", "")
    cleanText = string_gsub(cleanText, "|r", "")
    
    -- [[ STRIP SOCKET BONUS PREFIX ]]
    -- This allows the scanner to read "+4 Strength" instead of "Socket Bonus: +4 Strength"
    cleanText = string_gsub(cleanText, MSC.L["^socket bonus:%s*"] or "^socket bonus:%s*", "")

    -- [[ NEGATIVE STATS ]] "-3 Stamina" (cursed items): see ParseNegated above
    if ParseNegated(cleanText, MSC.Scanner.ParseStatLine, outputTable) then return end

    -- [[ 1. INTERCEPT NAMED, PROC & HYBRID ENCHANTS ]]
    if string_find(cleanText, "^enchant: ") then
        
        -- A. Proc Averages (Uptime Math)
        if string_find(cleanText, "mongoose") then
            outputTable["ITEM_MOD_AGILITY_SHORT"] = (outputTable["ITEM_MOD_AGILITY_SHORT"] or 0) + 30
            outputTable["ITEM_MOD_HASTE_RATING_SHORT"] = (outputTable["ITEM_MOD_HASTE_RATING_SHORT"] or 0) + 30
            return
        elseif string_find(cleanText, "executioner") then
            outputTable["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] = (outputTable["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] or 0) + 210
            return
        elseif string_find(cleanText, "crusader") then
            outputTable["ITEM_MOD_STRENGTH_SHORT"] = (outputTable["ITEM_MOD_STRENGTH_SHORT"] or 0) + 25
            return
        elseif string_find(cleanText, "spellsurge") then
            outputTable["ITEM_MOD_MANA_REGENERATION_SHORT"] = (outputTable["ITEM_MOD_MANA_REGENERATION_SHORT"] or 0) + 15
            return
            
        -- B. Flat Named Enchants
        elseif string_find(cleanText, "sunfire") then
            outputTable["ITEM_MOD_FIRE_DAMAGE_SHORT"] = (outputTable["ITEM_MOD_FIRE_DAMAGE_SHORT"] or 0) + 50
            outputTable["ITEM_MOD_ARCANE_DAMAGE_SHORT"] = (outputTable["ITEM_MOD_ARCANE_DAMAGE_SHORT"] or 0) + 50
            return
        elseif string_find(cleanText, "soulfrost") then
            outputTable["ITEM_MOD_SHADOW_DAMAGE_SHORT"] = (outputTable["ITEM_MOD_SHADOW_DAMAGE_SHORT"] or 0) + 54
            outputTable["ITEM_MOD_FROST_DAMAGE_SHORT"] = (outputTable["ITEM_MOD_FROST_DAMAGE_SHORT"] or 0) + 54
            return
        elseif string_find(cleanText, "savagery") then
            outputTable["ITEM_MOD_ATTACK_POWER_SHORT"] = (outputTable["ITEM_MOD_ATTACK_POWER_SHORT"] or 0) + 70
            return
            
        -- C. Weird Word-Only Enchants
        elseif string_find(cleanText, "speed and") then
            local val, stat = string_match(cleanText, "speed and %+(%d+) (.*)")
            if val and stat then
                local cleanName = string_gsub(stat, "[%s%.]+$", "")
                local key = MSC.Scanner.BaseStatMap[cleanName]
                if key then 
                    outputTable[key] = (outputTable[key] or 0) + ScanNum(val)
                    return 
                end
            end
        end
    end

    -- [[ THE DUAL-STAT SPLITTER ]]
    -- If a line has "and" (but isn't standard spell damage), split it into two lines and process both!
    if string_find(cleanText, " and ") and not string_find(cleanText, "damage and healing") then
        local part1, part2 = string_match(cleanText, "^(.-) and (.*)$")
        if part1 and part2 then
            -- Recursively pass both halves back through the scanner individually!
            MSC.Scanner.ParseStatLine(part1, outputTable)
            MSC.Scanner.ParseStatLine(part2, outputTable)
            return
        end
    end
	
    -- [[ ALL STATS EXPLODER ]]
    -- Instantly breaks "+X All Stats" into the big 5 attributes
    if string_find(cleanText, "all stats") then
        local val = ScanNum(string_match(cleanText, "%d+"))
        if val then
            outputTable["ITEM_MOD_STRENGTH_SHORT"]  = (outputTable["ITEM_MOD_STRENGTH_SHORT"] or 0) + val
            outputTable["ITEM_MOD_AGILITY_SHORT"]   = (outputTable["ITEM_MOD_AGILITY_SHORT"] or 0) + val
            outputTable["ITEM_MOD_STAMINA_SHORT"]   = (outputTable["ITEM_MOD_STAMINA_SHORT"] or 0) + val
            outputTable["ITEM_MOD_INTELLECT_SHORT"] = (outputTable["ITEM_MOD_INTELLECT_SHORT"] or 0) + val
            outputTable["ITEM_MOD_SPIRIT_SHORT"]    = (outputTable["ITEM_MOD_SPIRIT_SHORT"] or 0) + val
            return
        end
    end

    -- [[ OPTIMIZATION: DIGIT CHECK ]]
    if not string_find(text, "%d") then return end
    
    cleanText = string_gsub(cleanText, "|t.-|t", "") 
    cleanText = string_gsub(cleanText, "\194\160", " ") 
    cleanText = string_gsub(cleanText, "\160", " ") 
    cleanText = string_gsub(cleanText, "%s+", " ")
    cleanText = string_match(cleanText, "^%s*(.-)%s*$")
    
    for _, pat in ipairs(MSC.Scanner.StatPatterns) do
        local m1, m2, m3 = string_match(cleanText, pat.p)
        if m1 then
            if pat.type == "RANGE" then
                outputTable["MSC_DAMAGE_RANGE_MIN"] = ScanNum(m1)
                outputTable["MSC_DAMAGE_RANGE_MAX"] = ScanNum(m2)
                return
            elseif pat.fixedStat then
                local val = ScanNum(m1)
                if val then 
                    outputTable[pat.fixedStat] = (outputTable[pat.fixedStat] or 0) + val; 
                    return 
                end
            else
                local val, name = MSC.Scanner.OrderCaptures(pat, m1, m2)
                if val and name then
                    local cleanName = string_gsub(string_gsub(name, MSC.L["^to "], ""), "[%s%.]+$", "")
                    local key = MSC.Scanner.BaseStatMap[cleanName]
                    if not key and cleanName == MSC.L["armor"] then key = "ITEM_MOD_ARMOR_SHORT" end
                    
                    if key then 
                        outputTable[key] = (outputTable[key] or 0) + val; 
                        return 
                    end
                end
            end
        end
    end
end

function MSC.Scanner.ParseProcLine(text, outputProcs)
    local cleanText = string_gsub(string_gsub(string_gsub(string_gsub(string_lower(text), "|c%x%x%x%x%x%x%x%x", ""), "|r", ""), "\n", " "), "%s+", " ")
    cleanText = string_gsub(string_gsub(cleanText, MSC.L["^chance on hit: "], ""), MSC.L["^equip: chance on hit: "], "")

    local dmg = MSC.Scanner.ProcDamage(cleanText)
    if dmg then
        table_insert(outputProcs, { type = "Damage", val = dmg, perMin = MSC.Scanner.ProcRate.onHit, description = text })
        return
    end

    for _, pat in ipairs(MSC.Scanner.ProcPatterns) do
        local m1, m2, m3 = string_match(cleanText, pat.p)
        if m1 then
            local procObj = { description = text }
            if pat.type == "DAMAGE" then
                procObj.type = "Damage"
                local valStr = (pat.valIdx == 2) and m2 or m1
                procObj.val = ScanNum(valStr) or 0
                if m2 and not pat.valIdx then 
                    local maxVal = ScanNum(m2) or 0
                    procObj.val = (procObj.val + maxVal) / 2 
                end
            elseif pat.type == "HEAL" or pat.type == "MANA" then
                procObj.type = pat.type
                procObj.val = ScanNum(m1)
            elseif pat.valIdx then
                procObj.type = "Stat"
                procObj.val = ScanNum(pat.valIdx == 1 and m1 or m2)
                procObj.duration = ScanNum(pat.valIdx == 1 and m2 or m3)
                procObj.statName = pat.nameIdx and (pat.nameIdx == 1 and m1 or m2) or m1
            else 
                procObj.type = "Generic" 
            end
            table_insert(outputProcs, procObj)
            return
        end
    end
    table_insert(outputProcs, { type = "Unknown", description = text })
end

function MSC.Scanner.ParseUseLine(text, outputUseTable)
    local cleanText = string_gsub(string_gsub(string_gsub(string_gsub(string_gsub(string_lower(text), "|c%x%x%x%x%x%x%x%x", ""), "|r", ""), "\n", " "), "%s+", " "), MSC.L["^use: "], "")
    local cooldown = ParseCooldown(text)
    
    for _, pat in ipairs(MSC.Scanner.UsePatterns) do
        local m1, m2, m3 = string_match(cleanText, pat.p)
        if m1 then
            local effect = { raw = text, cooldown = cooldown }
            if pat.type == "BUFF" then
                local val, name = MSC.Scanner.OrderCaptures(pat, m1, m2)
                if not pat.nameIdx then name = nil end
                
                if not val then return end

                local duration = ScanNum(m3) or pat.defaultDur or 15
                effect.averageVal = val * (duration / cooldown)
                effect.duration = duration
                
                if pat.fixedStat then 
                    effect.statKey = pat.fixedStat
                elseif name then
                    effect.statKey = MSC.Scanner.LookupTerm(name)
                end
                effect.type = "Stat"
            elseif pat.type == "MANA" or pat.type == "HEALTH" or pat.type == "MANA_RANGE" or pat.type == "HEALTH_RANGE"
                or pat.type == "MANA_TICK" or pat.type == "HEALTH_TICK" then
                local val = ScanNum(m1)
                if string_find(pat.type, "TICK") then
                    val = val * (ScanNum(m3) or 0) / math.max(1, ScanNum(m2) or 1) -- per tick x ticks
                elseif m2 then val = (val + ScanNum(m2)) / 2 end
                effect.statKey = string_find(pat.type, "MANA") and "ITEM_MOD_MANA_REGENERATION_SHORT" or "ITEM_MOD_HEALTH_REGENERATION_SHORT"
                effect.averageVal = (val / cooldown) * 5
                effect.type = "Resource"
            end
            table_insert(outputUseTable, effect)
            return
        end
    end
    -- "Use: Inflicts 393 to 531 Fire damage..." (Goblin Mortar): average damage per
    -- cooldown as Attack Power, the same estimate as damage procs (AP_PER_DPS).
    local dmg = MSC.Scanner.ProcDamage(cleanText)
    if dmg then
        table_insert(outputUseTable, { raw = text, cooldown = cooldown, type = "Damage",
            statKey = "ITEM_MOD_ATTACK_POWER_SHORT", averageVal = dmg / cooldown * (MSC.Scanner.AP_PER_DPS or 14) })
    end
end

-- =============================================================
-- 5. MAIN PIPELINE
-- =============================================================

function MSC.Scanner.Scan(itemLink)
    local result = CreateItemObject()
    if not itemLink then return result end
	
    local itemID, _, _, equipLoc, _, classID, subClassID = GetItemInfoInstant(itemLink)
    local isRelic = (equipLoc == "INVTYPE_RELIC") or (classID == 4 and (subClassID == 7 or subClassID == 8 or subClassID == 9 or subClassID == 11))

    local tip = _G["MSC_NewScannerTooltip"] or CreateFrame("GameTooltip", "MSC_NewScannerTooltip", nil, "GameTooltipTemplate")
    tip:SetOwner(WorldFrame, "ANCHOR_NONE"); tip:ClearLines()
    local setOK = pcall(function() tip:SetHyperlink(itemLink) end)
    local numLines = tip:NumLines() or 0
    -- Incomplete: the tooltip didn't load (or some text was a secret value we
    -- can't read); GetRawItemStats doesn't cache such a scan.
    if not setOK or numLines < 2 then result.Meta.Incomplete = true end

    for i = 2, numLines do
        local leftLine = _G["MSC_NewScannerTooltipTextLeft"..i]
        local leftText = leftLine and leftLine:GetText()
        local r, g, b = 1, 1, 1
        if leftLine then r, g, b = leftLine:GetTextColor() end

        local rightLine = _G["MSC_NewScannerTooltipTextRight"..i]
        local rightText = rightLine and rightLine:GetText()

        -- Secret values error on compare/concatenate, so check before either.
        if MSC_IsSecret(leftText) then leftText = nil; result.Meta.Incomplete = true end
        if MSC_IsSecret(rightText) then rightText = nil; result.Meta.Incomplete = true end
        if MSC_IsSecret(r) or MSC_IsSecret(g) or MSC_IsSecret(b) then r, g, b = 1, 1, 1 end

        local fullText = (leftText or "")
        if rightText and rightText ~= "" then
            fullText = fullText .. " " .. rightText
        end

        if fullText ~= "" then
            local type = MSC.Scanner.ClassifyLine(fullText)
            
            if type == "SET_HEADER" or type == "SET" then 
                MSC.Scanner.ParseSetHeader(fullText, result.Meta)
            elseif type == "STAT" and not isRelic then 
                MSC.Scanner.ParseStatLine(fullText, result.Stats)
            elseif type == "EQUIP" and not isRelic then 
                MSC.Scanner.ParseEquipLine(fullText, result.Stats, result.Procs)
            elseif type == "USE" and not isRelic then 
                MSC.Scanner.ParseUseLine(fullText, result.UseEffects)
            elseif type == "SOCKET_BONUS" then 
                if g > 0.9 and r < 0.2 then result.Meta.SocketBonusActive = true end
                if not result.Meta.BonusStats then result.Meta.BonusStats = {} end
                MSC.Scanner.ParseStatLine(fullText, result.Meta.BonusStats)
            elseif type == "PROC" and not isRelic then 
                MSC.Scanner.ParseProcLine(fullText, result.Procs)
            end
        end
    end

if not result.Stats["MSC_WEAPON_DPS"] and result.Stats["MSC_WEAPON_SPEED"] and result.Stats["MSC_DAMAGE_RANGE_MIN"] and result.Stats["MSC_DAMAGE_RANGE_MAX"] then
        local avg = (result.Stats["MSC_DAMAGE_RANGE_MIN"] + result.Stats["MSC_DAMAGE_RANGE_MAX"]) / 2
        result.Stats["MSC_WEAPON_DPS"] = math_floor((avg / result.Stats["MSC_WEAPON_SPEED"]) * 10 + 0.5) / 10
    end
    
    -- (No Forever "1/3 of Healing is Spell Damage" inference here: Forever
    -- items print that third as their own "+X Spell Damage" line -- see the
    -- Spell Damage remap above the pattern database.)

    local itemID = tonumber(string_match(itemLink, "item:(%d+)"))
    if itemID and MSC.ItemOverrides and MSC.ItemOverrides[itemID] then
        local override = MSC.ItemOverrides[itemID]
        if override._AUTO_PROC or override.UseEffects then
            result.UseEffects = {}
            result.Procs = {}
            if override._AUTO_PROC then result.Stats._AUTO_PROC = override._AUTO_PROC end
        end
    end

    return result
end
