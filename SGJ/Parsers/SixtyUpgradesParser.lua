if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local L = MSC.L
local string_gsub, string_match = string.gsub, string.match
local string_find, string_sub = string.find, string.sub
local string_gmatch = string.gmatch 

-- =============================================================
-- 1. SIXTY UPGRADES STAT MAPS
-- =============================================================

-- Text Keys
local suStatMap = {
    ["stamina"] = "ITEM_MOD_STAMINA_SHORT",
    ["intellect"] = "ITEM_MOD_INTELLECT_SHORT",
    ["strength"] = "ITEM_MOD_STRENGTH_SHORT",
    ["agility"] = "ITEM_MOD_AGILITY_SHORT",
    ["spirit"] = "ITEM_MOD_SPIRIT_SHORT",
    
    ["dodgeRating"] = "ITEM_MOD_DODGE_RATING_SHORT",
    ["parryRating"] = "ITEM_MOD_PARRY_RATING_SHORT",
    ["defenseRating"] = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    ["blockRating"] = "ITEM_MOD_BLOCK_RATING_SHORT",
    ["blockValue"] = "ITEM_MOD_BLOCK_VALUE_SHORT",
    ["blockValueBonus"] = "ITEM_MOD_BLOCK_VALUE_SHORT", -- Stacks with Block Value
    
    ["hitRating"] = "ITEM_MOD_HIT_RATING_SHORT",
    ["expertiseRating"] = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    ["spellDamage"] = "ITEM_MOD_SPELL_POWER_SHORT",
    ["healing"] = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    ["spellHitRating"] = "ITEM_MOD_HIT_SPELL_RATING_SHORT",
    
    ["health"] = "ITEM_MOD_HEALTH_SHORT",
    ["resilienceRating"] = "ITEM_MOD_RESILIENCE_RATING_SHORT",
    ["armor"] = "ITEM_MOD_ARMOR_SHORT",
    
    ["hasteRating"] = "ITEM_MOD_HASTE_RATING_SHORT",
    ["spellHasteRating"] = "ITEM_MOD_SPELL_HASTE_RATING_SHORT",
    ["critRating"] = "ITEM_MOD_CRIT_RATING_SHORT",
    ["spellCritRating"] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
    ["armorPenetration"] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    ["attackPower"] = "ITEM_MOD_ATTACK_POWER_SHORT",
    ["feralAttackPower"] = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
    ["rangedAttackPower"] = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    ["mp5"] = "ITEM_MOD_MANA_REGENERATION_SHORT",
    ["spellPenetration"] = "ITEM_MOD_SPELL_PENETRATION_SHORT",
    
    -- Sockets
    ["metaSockets"] = "EMPTY_SOCKET_META",
    ["redSockets"] = "EMPTY_SOCKET_RED",
    ["yellowSockets"] = "EMPTY_SOCKET_YELLOW",
    ["blueSockets"] = "EMPTY_SOCKET_BLUE",
    
    -- Weapon Damage
    ["dps"] = "MSC_WEAPON_DPS",
    ["speed"] = "MSC_WEAPON_SPEED",
    ["meleeDps"] = "MSC_WEAPON_DPS",
    ["rangedDps"] = "MSC_WEAPON_DPS",
}

-- Numeric Keys (Short URL Format)
local suNumericMap = {
    ["3"] = "ITEM_MOD_STAMINA_SHORT",
    ["1"] = "ITEM_MOD_INTELLECT_SHORT",
    ["4"] = "ITEM_MOD_STRENGTH_SHORT",
    ["0"] = "ITEM_MOD_AGILITY_SHORT",
    ["2"] = "ITEM_MOD_SPIRIT_SHORT",
    
    ["22"] = "ITEM_MOD_DODGE_RATING_SHORT",
    ["24"] = "ITEM_MOD_PARRY_RATING_SHORT",
    ["20"] = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    ["26"] = "ITEM_MOD_BLOCK_RATING_SHORT",
    ["27"] = "ITEM_MOD_BLOCK_VALUE_SHORT",
    ["28"] = "ITEM_MOD_BLOCK_VALUE_SHORT",
    
    ["35"] = "ITEM_MOD_HIT_RATING_SHORT",
    ["46"] = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    ["5"] = "ITEM_MOD_SPELL_POWER_SHORT",
    ["8"] = "ITEM_MOD_HIT_SPELL_RATING_SHORT",
    
    ["16"] = "ITEM_MOD_HEALTH_SHORT",
    ["30"] = "ITEM_MOD_RESILIENCE_RATING_SHORT",
    ["17"] = "ITEM_MOD_ARMOR_SHORT",
    
    ["73"] = "EMPTY_SOCKET_META",
    ["75"] = "EMPTY_SOCKET_RED",
    ["76"] = "EMPTY_SOCKET_YELLOW",
    ["74"] = "EMPTY_SOCKET_BLUE",
    
    -- Extra numeric assumptions
    ["6"] = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    ["7"] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
    ["36"] = "ITEM_MOD_CRIT_RATING_SHORT",
    ["14"] = "ITEM_MOD_ATTACK_POWER_SHORT",
    ["15"] = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    ["44"] = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
    ["37"] = "ITEM_MOD_HASTE_RATING_SHORT",
    ["10"] = "ITEM_MOD_SPELL_HASTE_RATING_SHORT",
    ["47"] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    ["11"] = "ITEM_MOD_MANA_REGENERATION_SHORT",
    ["12"] = "ITEM_MOD_SPELL_PENETRATION_SHORT",
}

-- =============================================================
-- 2. SIXTY UPGRADES PARSER LOGIC
-- =============================================================

-- Store weights under the key items carry on this game version (e.g. Forever
-- weapon DPS is ITEM_MOD_DAMAGE_PER_SECOND_SHORT, not MSC_WEAPON_DPS).
-- Socket keys (EMPTY_SOCKET_*) have no alias and pass through.
local function Normalize(key)
    if key and MSC.NormalizeStatKey then return MSC.NormalizeStatKey(key) end
    return key
end

function MSC:ParseSixtyUpgradesString(inputString)
    if not inputString or type(inputString) ~= "string" then return nil end
    local weights = {}
    local profileName = "Sixty Upgrades Profile"
    local foundAny = false

    -- Try 1: JSON Format
    if string_find(inputString, "^{") or string_find(inputString, "\"stamina\"") then
        for key, val in string_gmatch(inputString, "\"([%w_]+)\"%s*:%s*([%-%d%.]+)") do
            local internalKey = Normalize(suStatMap[key])
            local numberVal = tonumber(val)
            if internalKey and numberVal and numberVal ~= 0 then
                weights[internalKey] = (weights[internalKey] or 0) + numberVal
                foundAny = true
            end
        end

    -- Try 2: URL Format
    elseif string_find(inputString, "?") and string_find(inputString, "=") then
        local nameMatch = string_match(inputString, "name=([^&]+)")
        if nameMatch then
            -- Convert %20 to space
            profileName = string_gsub(nameMatch, "%%20", " ")
        end
        
        -- Need to handle text keys and numeric keys
        for key, val in string_gmatch(inputString, "([%w]+)=([%-%d%.]+)") do
            if key ~= "name" then
                local internalKey = Normalize(suStatMap[key] or suNumericMap[key])
                local numberVal = tonumber(val)
                if internalKey and numberVal and numberVal ~= 0 then
                    weights[internalKey] = (weights[internalKey] or 0) + numberVal
                    foundAny = true
                end
            end
        end

    -- Try 3: CSV Format
    elseif string_find(inputString, "Stat,Value") or string_find(inputString, "\n") then
        for key, val in string_gmatch(inputString, "([%w_]+),([%-%d%.]+)") do
            if key ~= "Stat" then
                local internalKey = Normalize(suStatMap[key])
                local numberVal = tonumber(val)
                if internalKey and numberVal and numberVal ~= 0 then
                    weights[internalKey] = (weights[internalKey] or 0) + numberVal
                    foundAny = true
                end
            end
        end
    end

    if not foundAny then return nil end
    return weights, profileName
end
