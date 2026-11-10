if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
_G.MSC = MSC 

-- [[ SPEED OPTIMIZATION: LOCALIZED FUNCTIONS ]]
local _G = _G
local type, pairs, ipairs, unpack, pcall, select = type, pairs, ipairs, unpack, pcall, select
local tonumber, tostring, next = tonumber, tostring, next
local math_floor, math_abs, math_max, math_min, math_sqrt = math.floor, math.abs, math.max, math.min, math.sqrt
local string_find, string_match, string_lower, string_upper, string_gsub, string_format, string_sub = string.find, string.match, string.lower, string.upper, string.gsub, string.format, string.sub
local table_insert, table_concat, table_remove, table_sort = table.insert, table.concat, table.remove, table.sort
local wipe = wipe or table.wipe
local strsplit = strsplit

-- WoW APIs
local CreateFrame = CreateFrame
local WorldFrame = WorldFrame
local GetItemInfo = GetItemInfo
local UnitClass = UnitClass
local UnitLevel = UnitLevel
local UnitRace = UnitRace
local UnitStat = UnitStat
local UnitDefense = UnitDefense
local GetInventoryItemLink = GetInventoryItemLink
local GetItemStats = GetItemStats

-- Era/Classic Specifics
local GetHitModifier = GetHitModifier
local GetSpellHitModifier = GetSpellHitModifier
local GetCritChance = GetCritChance
local GetSpellCritChance = GetSpellCritChance
local GetSpellBonusHealing = GetSpellBonusHealing
local GetSpellBonusDamage = GetSpellBonusDamage

-- TBC/Retail Specifics
local GetCombatRating = GetCombatRating
local C_Container = C_Container
local GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo

-- =============================================================
-- 1. UTILITY FUNCTIONS
-- =============================================================
function MSC:SafeCopy(orig)
    local original_type = type(orig)
    local copy
    if original_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else
        copy = orig
    end
    return copy
end

-- [[ OPTIMIZATION: CACHE USABILITY ]]
MSC.UsableCache = {} 

function MSC.IsItemUsable(itemLink)
    if not itemLink then return false end
    
    -- Check Cache First
    if MSC.UsableCache[itemLink] ~= nil then return MSC.UsableCache[itemLink] end
    
    local _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemLink)
    local localizedClass, playerClass = UnitClass("player")
    local result = true -- Default to true, prove false
    local scanIncomplete = false

    -- 1. WEAPON CHECK
    if classID == 2 then 
        if MSC.CurrentClass and MSC.CurrentClass.ValidWeapons then
            if not MSC.CurrentClass.ValidWeapons[subClassID] then result = false end
        end
    end

    -- 2. ARMOR CHECK
    if result and classID == 4 then 
        local level = UnitLevel("player")
        local maxArmor = 1 -- Cloth
        
        if playerClass == "WARRIOR" or playerClass == "PALADIN" then 
            maxArmor = (level >= 40) and 4 or 3
        elseif playerClass == "SHAMAN" or playerClass == "HUNTER" then 
            maxArmor = (level >= 40) and 3 or 2
        elseif playerClass == "ROGUE" or playerClass == "DRUID" then 
            maxArmor = 2 
        end
        
        if subClassID == 6 then -- Shield
            if playerClass ~= "WARRIOR" and playerClass ~= "PALADIN" and playerClass ~= "SHAMAN" then result = false end
        elseif subClassID == 7 or subClassID == 8 or subClassID == 9 then
            -- Relics: Libram (Paladin), Idol (Druid), Totem (Shaman). Many carry
            -- no "Classes:" line, so the tooltip scan below can't catch them.
            local relicClass = (subClassID == 7 and "PALADIN") or (subClassID == 8 and "DRUID") or "SHAMAN"
            if playerClass ~= relicClass then result = false end
        elseif subClassID > 0 and subClassID <= 4 then
             if subClassID > maxArmor then result = false end
        end
    end

    -- 3. RESTRICTION SCAN (Only runs if passed previous checks)
    if result then
        local tip = _G["MSC_ScannerTooltip"] or CreateFrame("GameTooltip", "MSC_ScannerTooltip", nil, "GameTooltipTemplate")
        tip:SetOwner(WorldFrame, "ANCHOR_NONE"); tip:ClearLines()
        local status = pcall(function() tip:SetHyperlink(itemLink) end)

        if not status then scanIncomplete = true end
        if status then
            for i = 2, tip:NumLines() do
                local line = _G["MSC_ScannerTooltipTextLeft"..i]
                local text = line and line:GetText()
                -- Secret values error on string_find; skip the line and don't
                -- cache a verdict built without it.
                if text and MSC_IsSecret(text) then text = nil; scanIncomplete = true end
                if text then
                    if string_find(text, "Classes:") or (ITEM_CLASSES_ALLOWED and string_find(text, string_gsub(ITEM_CLASSES_ALLOWED, "%%s", ""))) then
                        if not string_find(text, localizedClass) then result = false; break end
                    end
                    if string_find(text, "Races:") or (ITEM_RACES_ALLOWED and string_find(text, string_gsub(ITEM_RACES_ALLOWED, "%%s", ""))) then
                          local localizedRace = UnitRace("player")
                          if not string_find(text, localizedRace) then result = false; break end
                    end
                end
            end
        end
    end
    
    -- Save to Cache (not while the item is still loading: classID is nil then, so
    -- the checks above defaulted to usable and the tooltip scan read nothing)
    if classID and not scanIncomplete then MSC.UsableCache[itemLink] = result end
    return result
end

function MSC:IsJewelcrafter()
    -- Allow the user to force this on via settings
    if RXP_SGJ_Settings and type(RXP_SGJ_Settings.IsJC) == "boolean" then
        return RXP_SGJ_Settings.IsJC
    end
    -- Fallback: Scan Professions
    if GetNumSkillLines then
        for i = 1, GetNumSkillLines() do
            local skillName = GetSkillLineInfo(i)
            local localizedJC = MSC.L["Jewelcrafting"] or "Jewelcrafting"
			if skillName and (skillName == localizedJC or string.find(skillName, localizedJC)) then
                return true
            end
        end
    end
    return false
end

-- =============================================================
-- 2. API SHIMS
-- =============================================================
function MSC.getItemID(bagID, slotID)
    if not bagID or not slotID then return nil end
    local itemInfo = GetContainerItemInfo(bagID, slotID)
    if itemInfo then return itemInfo.itemID end
    return nil
end

-- Safely strips WoW 11.5 "secret numbers" (secure variables) from API returns
function MSC.SanitizeStat(val)
    if not val then return 0 end
    if type(val) ~= "number" then return 0 end
    local succ, s = pcall(tostring, val)
    return (succ and tonumber(s)) or 0
end

function MSC:GetPlayerStat(statType)
    local val = 0
    -- Forever gear has Hit Rating, which GetHitModifier() doesn't include.
    if MSC.IsForever and (statType == "HIT" or statType == "SPELL_HIT") and MSC.GetForeverHitPercent then
        return (MSC:GetForeverHitPercent(statType == "HIT" and "MELEE" or "SPELL"))
    end
    if MSC.IsVanillaRules then
        -- gear + talents: hit % from live buffs comes off, assumed buffs add theirs
        if statType == "HIT" then local j = MSC.GetJudgingStats(); val = math_max(0, MSC.SanitizeStat(GetHitModifier()) - j.buffHitPct) + j.assumedHitPct
        elseif statType == "SPELL_HIT" then local j = MSC.GetJudgingStats(); val = math_max(0, MSC.SanitizeStat(GetSpellHitModifier()) - j.buffSpellHitPct) + j.assumedSpellHitPct
        elseif statType == "CRIT" then val = MSC.SanitizeStat(GetCritChance())
        elseif statType == "SPELL_CRIT" then val = MSC.SanitizeStat(GetSpellCritChance(2))
        elseif statType == "DEFENSE" then local b, m = UnitDefense("player"); val = MSC.SanitizeStat(b) + MSC.SanitizeStat(m)
        elseif statType == "HEALING" then val = MSC.SanitizeStat(GetSpellBonusHealing())
        elseif statType == "SPELL_POWER" then val = MSC.SanitizeStat(GetSpellBonusDamage(2))
        end
    else
        -- Hit Rating from the gear (unbuffed), live rating until it's scanned
        if statType == "HIT" then val = MSC.GetGearHitRating("MELEE") or GetCombatRating(6)
        elseif statType == "SPELL_HIT" then val = MSC.GetGearHitRating("SPELL") or MSC.SanitizeStat(GetCombatRating(8))
        elseif statType == "CRIT" then val = MSC.SanitizeStat(GetCombatRating(9))
        elseif statType == "SPELL_CRIT" then val = MSC.SanitizeStat(GetCombatRating(11))
        elseif statType == "DEFENSE" then local b, m = UnitDefense("player"); val = MSC.SanitizeStat(b) + MSC.SanitizeStat(m)
        elseif statType == "HEALING" then val = MSC.SanitizeStat(GetSpellBonusHealing())
        elseif statType == "SPELL_POWER" then val = MSC.SanitizeStat(GetSpellBonusDamage(2))
        end
    end
    
    return MSC.SanitizeStat(val)
end

-- Returns MP5 gained from `spiritPoints` on gear (pass 1 for per-stat weighting).
function MSC:GetSpiritValueInMP5(level, spiritPoints)
    if not MSC.BaseRegenTable then return 0 end
    local points = spiritPoints or 1
    if points > 50 then points = 1 end -- guard against passing total Intellect by mistake
    local _, class = UnitClass("player")
    if MSC.IsVanillaRules then
        if class == "PRIEST" or class == "MAGE" then return (points / 4) + 12.5 end
        return (points / 5) + 15
    else
        if not level or level > 70 then level = 70 end
        local base = MSC.BaseRegenTable[level] or 0.009327
        -- Intellect with gear, without live buffs, with assumed ones
        local intel = MSC.GetJudgingStats().int
        if intel <= 0 then intel = 100 end
        return 5 * (0.001 + base * math_sqrt(intel) * points)
    end
end

-- =============================================================
-- 3. COMPARISON MATH
-- =============================================================
function MSC.GetStatDifferences(newStats, oldStats, outTable)
    if not outTable then outTable = {} end
    wipe(outTable)
    
    local ignoreKeys = {
        ["IS_PROJECTED"] = true, ["GEMS_PROJECTED"] = true, ["BONUS_PROJECTED"] = true,
        ["GEM_TEXT"] = true, ["ENCHANT_TEXT"] = true, ["PROJECTED_GEM_IDS"] = true,
        ["META_ID"] = true, ["COLORS"] = true, ["_BONUS_STATS"] = true, ["_AUTO_PROC"] = true
    }

    local processed = {}
    for k, valNew in pairs(newStats) do
        if not ignoreKeys[k] and type(valNew) == "number" then
            local valOld = oldStats[k]
            if type(valOld) ~= "number" then valOld = 0 end
            local diff = valNew - valOld
            if math_abs(diff) > 0.01 then
                table_insert(outTable, { key = k, val = diff })
            end
            processed[k] = true
        end
    end
    for k, valOld in pairs(oldStats) do
        if not processed[k] and not ignoreKeys[k] and type(valOld) == "number" then
            local diff = 0 - valOld
            if math_abs(diff) > 0.01 then
                table_insert(outTable, { key = k, val = diff })
            end
        end
    end
    return outTable
end

function MSC.SortStatDiffs(diffs)
    table_sort(diffs, function(a,b) return a.val > b.val end)
    return diffs
end

function MSC.GetCleanStatName(key)
    if MSC.ShortNames and MSC.ShortNames[key] then return MSC.ShortNames[key] end
    if MSC.StatShortNames and MSC.StatShortNames[key] then return MSC.StatShortNames[key] end
    local s = string_gsub(string_gsub(string_gsub(key, "ITEM_MOD_", ""), "_SHORT", ""), "_", " ")
    return string_gsub(string_lower(s), "^%l", string_upper)
end

function MSC.NormalizeStatKey(key)
    if not key or not MSC.StatAliases then return key end
    return MSC.StatAliases[key] or key
end

-- =============================================================
-- 4. CACHE & CONSTANTS
-- =============================================================
MSC.StatCache = {}
-- When each StatCache entry was scanned. An item's Equip:/Use: text comes from
-- its spells, which load separately from the item: a quest reward scanned the
-- moment the quest frame opens can be missing "Equip: +8 Spell Power" even
-- though GetItemInfo already answers. MSC.DropRecentScans (called on
-- SPELL_DATA_LOAD_RESULT) forgets the scans from just before the spell arrived.
local statCacheTime = {}
local RECENT_SCAN_WINDOW = 5
-- When each link was first read this session (kept by DropRecentScans, cleared by DropAllScans). A hover reread that
-- matches the cached read only proves the read complete once LOCK_AFTER seconds have passed since then: two reads
-- taken before an item's Equip: text loaded agree with each other too (2026-11-09: Heavy Woolen Gloves' spell power).
local firstReadTime = {}
local LOCK_AFTER = 10
-- Scores already built from dropped scans go too.
local function WipeScoresFromScans()
    if MSC.ProcessedStatCache then wipe(MSC.ProcessedStatCache) end
    if MSC.EvaluationCache then wipe(MSC.EvaluationCache) end
    if MSC.EquippedSlotScoreCache then wipe(MSC.EquippedSlotScoreCache) end
    MSC.EquippedScoreCache = nil
end
function MSC.DropRecentScans()
    local cutoff = GetTime() - RECENT_SCAN_WINDOW
    local dropped = false
    for link, t in pairs(statCacheTime) do
        if t >= cutoff then
            MSC.StatCache[link] = nil
            dropped = true
        end
        statCacheTime[link] = nil
    end
    if dropped then WipeScoresFromScans() end
    return dropped
end

local function SameScan(a, b)
    for k, v in pairs(a) do
        if type(v) == "number" and b[k] ~= v then return false end
    end
    for k, v in pairs(b) do
        if type(v) == "number" and a[k] ~= v then return false end
    end
    return true
end

-- Hovering an item reads it again (at most once a second per link), in case
-- the cached read came before its Equip: text loaded. True when the stats
-- changed: the caller redraws the tooltip. A reread that matches the cached
-- one proves the text was there, so that link is never reread again.
local lastRecheck = {}
function MSC.RecheckItemScan(link)
    local old = link and MSC.StatCache[link]
    if not old then return false end
    local now = GetTime()
    local last = lastRecheck[link]
    if last == true or (last and now - last < 1) then return false end
    lastRecheck[link] = now

    MSC.StatCache[link] = nil
    local fresh = MSC.GetRawItemStats(link)
    if not MSC.StatCache[link] then
        -- The new read was incomplete: keep the old one.
        MSC.StatCache[link] = old
        return false
    end
    if SameScan(old, fresh) then
        -- only a match well after the first read proves the text was all there; earlier, keep rereading (once a second)
        if now - (firstReadTime[link] or now) >= LOCK_AFTER then lastRecheck[link] = true end
        return false
    end
    WipeScoresFromScans()
    return true
end

-- Era/TBC read every worn and bag item at login, often before their Equip:
-- text (healing, spell power, Mp5) has loaded, and the reads were kept: a
-- healer's worn gear scored on its base stats only. Hovering an item rereads
-- it and the worn item(s) it's compared against before the tooltip is scored.
local RECHECK_SLOTS = {
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16, 17 },
    INVTYPE_WEAPONOFFHAND = { 16, 17 }, INVTYPE_SHIELD = { 16, 17 }, INVTYPE_HOLDABLE = { 16, 17 },
}
function MSC.RecheckForTooltip(link)
    if not link then return false end
    local changed = MSC.RecheckItemScan(link)
    local getInstant = GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
    local equipLoc = getInstant and select(4, getInstant(link))
    local slots = equipLoc and (RECHECK_SLOTS[equipLoc] or (MSC.SlotMap and MSC.SlotMap[equipLoc] and { MSC.SlotMap[equipLoc] }))
    if slots then
        for _, slot in ipairs(slots) do
            local worn = GetInventoryItemLink("player", slot)
            if worn and worn ~= link and MSC.RecheckItemScan(worn) then changed = true end
        end
    end
    return changed
end

-- Forget every read (and the scores built from them) so items are read again:
-- run a few seconds after login, once the Equip: text of the items read during
-- the login burst has had time to load.
function MSC.DropAllScans()
    wipe(MSC.StatCache)
    wipe(statCacheTime)
    wipe(lastRecheck)
    wipe(firstReadTime)
    WipeScoresFromScans()
end
local Scratch_MatchGems = {}
local Scratch_PureGems = {}
local Scratch_GemTextParts = {}
local Scratch_ProjectedIDs = {}
local Scratch_GemCounts = {}
local Scratch_GemOrder = {}
local Scratch_GemStats = {}
local Scratch_GemColors = {}
local Scratch_ProjectedColors = { RED=0, YELLOW=0, BLUE=0 }

MSC.StatShortNames = {
    ["MSC_WAND_DPS"] = MSC.L["Wand DPS"], ["MSC_WEAPON_DPS"] = MSC.L["Weapon DPS"], ["MSC_WEAPON_DPS_MELEE"] = MSC.L["Melee Weapon DPS"], ["MSC_WEAPON_DPS_OH"] = MSC.L["Off-Hand Weapon DPS"], ["MSC_WEAPON_SPEED"] = MSC.L["Speed"], ["MSC_OH_WEAPON_SPEED"] = MSC.L["OH Speed"],
    ["ITEM_MOD_STAMINA_SHORT"] = MSC.L["Stam"], ["ITEM_MOD_INTELLECT_SHORT"] = MSC.L["Int"],
    ["ITEM_MOD_AGILITY_SHORT"] = MSC.L["Agi"], ["ITEM_MOD_STRENGTH_SHORT"] = MSC.L["Str"],
    ["ITEM_MOD_SPIRIT_SHORT"] = MSC.L["Spt"], ["ITEM_MOD_SPELL_POWER_SHORT"] = MSC.L["SP"],
    ["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"] = MSC.L["Spell Dmg"], ["ITEM_MOD_HEALTH_REGENERATION_SHORT"] = MSC.L["Hp5"],
    ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] = MSC.L["Heal"], ["ITEM_MOD_MANA_REGENERATION_SHORT"] = MSC.L["Mp5"],
    ["ITEM_MOD_ATTACK_POWER_SHORT"] = MSC.L["AP"], ["ITEM_MOD_CRIT_RATING_SHORT"] = MSC.L["Crit"],
    ["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] = MSC.L["Spell Crit"], ["ITEM_MOD_HIT_RATING_SHORT"] = MSC.L["Hit"],
    ["ITEM_MOD_HIT_SPELL_RATING_SHORT"] = MSC.L["Spell Hit"], ["ITEM_MOD_HASTE_RATING_SHORT"] = MSC.L["Haste"],
    ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = MSC.L["Exp"], ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] = MSC.L["Def"],
    ["ITEM_MOD_RESILIENCE_RATING_SHORT"] = MSC.L["Resil"], ["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] = MSC.L["ArP"],
    ["ITEM_MOD_BLOCK_VALUE_SHORT"] = MSC.L["BlockVal"], ["ITEM_MOD_BLOCK_RATING_SHORT"] = MSC.L["Block"],
    ["ITEM_MOD_DODGE_RATING_SHORT"] = MSC.L["Dodge"], ["ITEM_MOD_PARRY_RATING_SHORT"] = MSC.L["Parry"],
    ["ITEM_MOD_SHADOW_DAMAGE_SHORT"] = MSC.L["Shadow"], ["ITEM_MOD_FIRE_DAMAGE_SHORT"] = MSC.L["Fire"],
    ["ITEM_MOD_FROST_DAMAGE_SHORT"] = MSC.L["Frost"], ["ITEM_MOD_ARCANE_DAMAGE_SHORT"] = MSC.L["Arcane"],
    ["ITEM_MOD_NATURE_DAMAGE_SHORT"] = MSC.L["Nature"], ["ITEM_MOD_HOLY_DAMAGE_SHORT"] = MSC.L["Holy"],
    ["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"] = MSC.L["Dmg"], ["ITEM_MOD_ARMOR_SHORT"] = MSC.L["Armor"],
    ["ITEM_MOD_ALL_RESISTANCE_SHORT"] = MSC.L["All Res"],
    ["ITEM_MOD_FERAL_ATTACK_POWER_SHORT"] = MSC.L["Feral AP"],
    ["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] = MSC.L["Ranged AP"],
}

function MSC.Round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math_floor(num * mult + 0.5) / mult
end

-- =============================================================
-- 5. RATING CONVERTER
-- =============================================================
function MSC:GetRatingPercent(statKey, ratingVal, level)
    if not MSC.CombatRatingScalars or not MSC.RatingIndexMap then return nil end
    local idx = MSC.RatingIndexMap[statKey]
    if not idx then return nil end
    local levelData = MSC.CombatRatingScalars[level]
    if not levelData then 
        if level < 60 then levelData = MSC.CombatRatingScalars[60] 
        elseif level > 70 then levelData = MSC.CombatRatingScalars[70] end
    end
    if not levelData or not levelData[idx] then return nil end
    return ratingVal / levelData[idx]
end

-- =============================================================
-- 5.5 FOREVER WEAPON RACIALS
-- =============================================================
-- WoW: Forever's weapon racials (Human Sword, Dwarf Mace, Orc Axe Specialization: crit
-- with that weapon type) were removed in the 2026-10-15 beta patch (client 1.60.1.70425).
-- Blizzard ruled them out for good in the launch racial pass (dev notes of October 26):
-- the remaining racials don't depend on the weapon (Human Ruthless +1% crit, Dwarf
-- Artisan's Precision +1% hit), so no weapon scores higher for a race and the table
-- is empty; the functions below then add nothing. Kept so a
-- weapon racial can come back with one line: { critPct, subclasses = { [itemSubClassID] = true }, name }.
MSC.ForeverWeaponRacials = {}

-- Racial crit change from equipping itemLink in slotId (16 or 17), against the
-- weapons worn now: returns racial name and +critPct (gained), -critPct (lost),
-- or nil when nothing changes. A two-hander in the main hand clears the off hand;
-- an off-hand item next to a worn two-hander replaces it.
function MSC.GetForeverRacialSwapChange(itemLink, slotId)
    if not MSC.IsForever or not itemLink or (slotId ~= 16 and slotId ~= 17) then return nil end
    local _, race = UnitRace("player")
    local racial = race and MSC.ForeverWeaponRacials[race]
    if not racial then return nil end

    local function Qualifies(link)
        if not link then return false end
        local _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(link)
        return classID == 2 and subClassID ~= nil and racial.subclasses[subClassID] == true
    end
    local function Is2H(link)
        local loc = link and select(9, GetItemInfo(link))
        return loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_STAFF" or loc == "INVTYPE_POLEARM"
    end

    local mh, oh = GetInventoryItemLink("player", 16), GetInventoryItemLink("player", 17)
    local had = Qualifies(mh) or Qualifies(oh)
    local newMH, newOH = mh, oh
    if slotId == 16 then
        newMH = itemLink
        if Is2H(itemLink) then newOH = nil end
    else
        newOH = itemLink
        if Is2H(mh) then newMH = nil end
    end
    local has = Qualifies(newMH) or Qualifies(newOH)
    if has == had then return nil end
    return racial.name, has and racial.critPct or -racial.critPct
end

-- otherHandLink: the weapon in the other hand. The racial applies once while
-- either hand holds that weapon type, so when the other hand already
-- qualifies this item adds nothing (dual wielders with two swords, or an
-- off-hand sword next to a main-hand sword).
function MSC.GetForeverWeaponRacialBonus(itemLink, weights, otherHandLink)
    if not itemLink or not weights then return 0 end
    local race = MSC.CtxRace()
    local racial = race and MSC.ForeverWeaponRacials[race]
    if not racial then return 0 end

    local _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(itemLink)
    if classID ~= 2 or not subClassID or not racial.subclasses[subClassID] then return 0 end
    if otherHandLink then
        local _, _, _, _, _, _, _, _, _, _, _, otherClass, otherSub = GetItemInfo(otherHandLink)
        if otherClass == 2 and otherSub and racial.subclasses[otherSub] then return 0 end
    end

    -- Crit weights are "per 1%" (GetItemScore converts rating to percent
    -- before weighting), so +N% crit is worth N x the weight -- exactly what
    -- the equivalent Critical Strike Rating on an item scores. Uses the larger
    -- of the two crit weights, matching GetItemScore's Forever crit unification.
    local critWeight = math_max(weights["ITEM_MOD_CRIT_RATING_SHORT"] or 0, weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] or 0)

    return racial.critPct * critWeight
end

-- =============================================================
-- 5.6 FOREVER DUAL-WIELD HIT TAPER
-- =============================================================
-- Dual-wield melee (Rogue, Enhancement Shaman, DW Fury Warrior) don't fall off
-- a cliff at the 9% yellow-hit cap the way single-wield/2H specs do. Per the
-- confirmed Forever formula, White Crit Cap = 100% - (28% - Hit) - 5.6% dodge
-- - 40% glancing: at 0 gear Hit that's a 26.4% base crit cap, and every point
-- of Hit raises it 1:1, topping out at 54.4% once Hit reaches 28% (the same
-- ceiling 2H specs sit at, since 28 Hit fully cancels the DW miss penalty).
-- Between the 9% yellow cap and the 28% white cap, Hit no longer helps yellow
-- abilities (already at 0% miss there) but keeps cutting white-swing misses
-- 1:1 the whole way to 28%, so its marginal value doesn't keep decaying in
-- that band -- it's a plateau, not a fade. Past 28% both the white miss and
-- the crit ceiling are maxed out, so Hit provides essentially nothing.
-- =============================================================
-- 5.7 FOREVER CAPS (hit, spell hit, tank defense)
-- =============================================================
-- Two targets per cap: what's useful against level-appropriate mobs while
-- leveling, and what raiding at 60 needs (level-63 bosses). From level 50 the
-- target slides linearly toward the raid one, so players gearing for raids
-- keep valuing hit and defense past the leveling target. "Gear for raiding"
-- (Protocol, on by default) can turn the slide off for pure levelers.
MSC.ForeverCaps = {
    RAID_BLEND_START = 50,
    MELEE = { leveling = 5, raid = 9 },   -- yellow/2H miss vs same level / vs +3 boss
    -- Spells: 4% miss vs your level / 17% vs +3. No 1% that can't be removed (2026-10-23, user: the client's hit panel and
    -- players read it that way, and the client sim has no floor; Blizzard hasn't confirmed it -- check at 60)
    SPELL = { leveling = 4, raid = 17 },
    -- Dungeon rows (2026-10-23, Warlock deep dive D6): dungeon mobs are +1/+2 (5-6% miss)
    SPELL_DUNGEON = { leveling = 5.5, raid = 17 },
    DW_WHITE = { leveling = 24, raid = 28 }, -- dual-wield white swings
    DEFENSE_RAID = 440,                   -- crit immunity vs level-63 bosses
    UNCRUSHABLE = 102.4,                  -- miss + dodge + parry + block vs +3
}

function MSC.IsGearingForRaids()
    return not (RXP_SGJ_Settings and RXP_SGJ_Settings.GearForRaiding == false)
end

-- 0 below 50 (or when not gearing for raids), 1 at 60+. Always 0 while
-- PvP weights are active: other players are your level, so hit and defense
-- keep the leveling targets.
function MSC.GetRaidBlend(level)
    if MSC.IsPvPWeightsActive() then return 0 end
    level = level or UnitLevel("player") or 1
    if level >= 60 then return 1 end
    if not MSC.IsGearingForRaids() then return 0 end
    local start = MSC.ForeverCaps.RAID_BLEND_START
    if level <= start then return 0 end
    return (level - start) / (60 - start)
end

function MSC.GetForeverCapTarget(kind, level)
    local c = MSC.ForeverCaps[kind]
    if not c then return nil end
    local t = MSC.GetRaidBlend(level)
    return c.leveling + (c.raid - c.leveling) * t
end

-- Defense skill a tank should aim for: none below 50 (returns nil), then a
-- slide from the level's base defense (5 x level) to 440 at 60.
function MSC.GetForeverDefenseTarget(level)
    level = level or UnitLevel("player") or 1
    local t = MSC.GetRaidBlend(level)
    if t <= 0 then return nil end
    local base = 5 * math_min(level, 60)
    return base + (MSC.ForeverCaps.DEFENSE_RAID - base) * t
end

-- Gear is judged unbuffed: caps read the stats on the equipped gear (with
-- its real enchants and gems) plus active set bonuses, not the live numbers,
-- which move with food, elixirs and party buffs. Cached per equipment set.
-- Returns nil while an equipped item isn't scanned yet (callers then use
-- the live value).
local GEAR_TOTAL_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local gearTotals, gearTotalsKey = nil, nil
function MSC.GetGearStatTotals()
    local links = {}
    for i, slot in ipairs(GEAR_TOTAL_SLOTS) do links[i] = GetInventoryItemLink("player", slot) or "-" end
    local key = table.concat(links, ";")
    if gearTotals and gearTotalsKey == key then return gearTotals end
    local totals, setCounts = {}, {}
    for i, slot in ipairs(GEAR_TOTAL_SLOTS) do
        local link = links[i]
        if link ~= "-" then
            local stats = MSC.GetRawItemStats(link)
            if not MSC.StatCache[link] then return nil end -- not scanned yet
            for k, v in pairs(stats) do
                if type(v) == "number" then totals[k] = (totals[k] or 0) + v end
            end
            local itemID = tonumber(string_match(link, "item:(%d+)"))
            local setID = itemID and MSC.ItemSetMap and MSC.ItemSetMap[itemID]
            if setID then setCounts[setID] = (setCounts[setID] or 0) + 1 end
        end
    end
    for setID, count in pairs(setCounts) do
        for reqCount, bonus in pairs((MSC.SetBonusScores and MSC.SetBonusScores[setID]) or {}) do
            if count >= reqCount and type(bonus) == "table" and bonus.stats then
                for k, v in pairs(bonus.stats) do totals[k] = (totals[k] or 0) + v end
            end
        end
    end
    gearTotals, gearTotalsKey = totals, key
    return totals
end

-- =============================================================
-- GEAR POINTS (WoW Forever, level-60 raid profiles)
-- =============================================================
-- Stat weights depend on the gear they were measured on. Each raid profile
-- was measured on two sets (Classes/Forever/GearPoints.lua, generated by
-- SimStudio sgjstudio/export/gearpoints.py): pre-raid best in slot (the
-- shipped weights) and Tier 1. Where the character sits between them is its
-- gear power: the worn items' stats priced with the profile's shipped
-- weights. The export prices the two sets the same way, so the two must
-- match: item stats only (no enchants, set bonuses, use effects or procs),
-- ratings per 1% at the flat Forever ratings, Spell Power also at the
-- Healing weight, shield block value, weapon DPS from the main and off hand
-- (Hunters: the ranged one; Warriors and Rogues: no ranged slot).
local GP_RATING = {
    ITEM_MOD_DODGE_RATING_SHORT = 12, ITEM_MOD_PARRY_RATING_SHORT = 20, ITEM_MOD_BLOCK_RATING_SHORT = 5,
}
local GP_HIT = { ITEM_MOD_HIT_RATING_SHORT = true, ITEM_MOD_HIT_SPELL_RATING_SHORT = true,
    ITEM_MOD_HIT_MELEE_RATING_SHORT = true, ITEM_MOD_HIT_RANGED_RATING_SHORT = true }
local GP_CRIT = { ITEM_MOD_CRIT_RATING_SHORT = true, ITEM_MOD_SPELL_CRIT_RATING_SHORT = true,
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = true, ITEM_MOD_CRIT_RANGED_RATING_SHORT = true }
local GP_PLAIN = {
    ITEM_MOD_AGILITY_SHORT = true, ITEM_MOD_STRENGTH_SHORT = true, ITEM_MOD_INTELLECT_SHORT = true, ITEM_MOD_SPIRIT_SHORT = true,
    ITEM_MOD_STAMINA_SHORT = true, ITEM_MOD_ATTACK_POWER_SHORT = true, ITEM_MOD_RANGED_ATTACK_POWER_SHORT = true,
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = true, ITEM_MOD_MANA_REGENERATION_SHORT = true, ITEM_MOD_HEALTH_REGENERATION_SHORT = true,
    ITEM_MOD_BLOCK_VALUE_SHORT = true, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = true, ITEM_MOD_ARMOR_SHORT = true,
    ITEM_MOD_HOLY_DAMAGE_SHORT = true, ITEM_MOD_FIRE_DAMAGE_SHORT = true, ITEM_MOD_NATURE_DAMAGE_SHORT = true,
    ITEM_MOD_FROST_DAMAGE_SHORT = true, ITEM_MOD_SHADOW_DAMAGE_SHORT = true, ITEM_MOD_ARCANE_DAMAGE_SHORT = true,
}

-- The gear power of the worn items under weights w, or nil while a worn
-- item isn't scanned yet. leveling: the weights are a leveling row (export
-- curves.py kit_power): main hand at the melee weapon DPS weight
-- (MSC_WEAPON_DPS_MELEE, else the DPS key), off hand at MSC_WEAPON_DPS_OH
-- (else half of it), the ranged slot (bows, guns, wands) at the DPS key, for
-- every class but Warriors and Rogues.
function MSC.GetGearPower(w, leveling)
    if not w then return nil end
    local function W(k) return tonumber(w[k]) or 0 end
    -- Forever ratings per 1%; Era items show hit, crit, dodge, parry and block as percentages
    -- (export era_gearpoints.py prices them the same way)
    local era = not MSC.IsForever
    local hitW = math_max(W("ITEM_MOD_HIT_RATING_SHORT"), W("ITEM_MOD_HIT_SPELL_RATING_SHORT")) / (era and 1 or 10)
    local critW = math_max(W("ITEM_MOD_CRIT_RATING_SHORT"), W("ITEM_MOD_SPELL_CRIT_RATING_SHORT")) / (era and 1 or 14)
    local spW = W("ITEM_MOD_SPELL_POWER_SHORT") + W("ITEM_MOD_SPELL_HEALING_DONE_SHORT")
    local spDmgW = math_max(W("ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"), W("ITEM_MOD_SPELL_POWER_SHORT"))
    local dpsW = W("ITEM_MOD_DAMAGE_PER_SECOND_SHORT")
    local ohW = w["MSC_WEAPON_DPS_OH"] and W("MSC_WEAPON_DPS_OH") or 0.5 * dpsW
    local _, class = UnitClass("player")
    local hunter = class == "HUNTER"
    -- the measured Warrior and Rogue sets carry no ranged item
    local noRanged = class == "WARRIOR" or class == "ROGUE"
    local power = 0
    for _, slot in ipairs(GEAR_TOTAL_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link and not (noRanged and slot == 18) then
            -- without its enchant: the measured sets have none
            if (tonumber(string_match(link, "item:%-?%d+:(%-?%d*)") or "") or 0) ~= 0 then
                link = string_gsub(link, "(item:%-?%d+:)%-?%d*", "%10", 1)
            end
            local stats = MSC.GetRawItemStats(link)
            if not MSC.StatCache[link] then return nil end -- not scanned yet
            -- use effects, curated procs and estimated damage procs aren't gear power
            local proc = type(stats._AUTO_PROC) == "table" and stats._AUTO_PROC or nil
            local est = type(stats._PROC_ESTIMATE) == "table" and stats._PROC_ESTIMATE.ap or 0
            local estKey = (slot == 18) and "ITEM_MOD_RANGED_ATTACK_POWER_SHORT" or "ITEM_MOD_ATTACK_POWER_SHORT"
            for k, v in pairs(stats) do
                if type(v) == "number" then
                    if proc and proc.stat == k then v = v - (proc.val or 0) end
                    if k == estKey then v = v - est end
                    if GP_HIT[k] then power = power + v * hitW
                    elseif GP_CRIT[k] then power = power + v * critW
                    elseif GP_RATING[k] then power = power + v * W(k) / (era and 1 or GP_RATING[k])
                    elseif k == "ITEM_MOD_SPELL_POWER_SHORT" then power = power + v * spW
                    elseif k == "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" then power = power + v * spDmgW
                    elseif GP_PLAIN[k] then power = power + v * W(k) end
                end
            end
            -- the weapon's own DPS: the tooltip's "(N damage per second)" line; the item-mod
            -- key also holds "+N Weapon Damage" lines and folded procs
            local dps = tonumber(stats.MSC_WEAPON_DPS)
            if not dps then
                dps = (tonumber(stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT) or 0)
                    - ((proc and proc.stat == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT") and (proc.val or 0) or 0)
            end
            if leveling then
                -- Leveling gear point: armor and stats set it, not weapon DPS. One dungeon-blue weapon was a third to
                -- half of the quest-to-best kit gap at some levels and moved every weight; the weapon is scored on its own.
            elseif hunter then
                if slot == 18 then power = power + dps * dpsW end
            elseif slot == 16 then power = power + dps * dpsW
            elseif slot == 17 then power = power + dps * ohW end
        end
    end
    return power
end

-- Leveling rows at two gear points (WoW Forever; the Leveling tables in
-- Classes/Forever/Curves/<Class>_Curves.lua, generated by SimStudio
-- sgjstudio/export/curves.py): the shipped rows are measured on the best gear
-- a character can have at its level, the low rows on quest rewards. Each kit's
-- gear power under the shipped row is stored per level; a weight slides from
-- the low row at the quest kit's power to the shipped row at the best kit's.
-- row: the shipped row at level. Returns weights, fraction (1 = shipped row),
-- gear power, the quest and best kits' power at level.
local function LerpLevels(list, level)
    local n = #list
    local a, b = list[1], list[n]
    if level <= a[1] then return a[2], a[3] end
    if level >= b[1] then return b[2], b[3] end
    for i = 1, n - 1 do
        local x, y = list[i], list[i + 1]
        if level >= x[1] and level <= y[1] then
            local t = (y[1] > x[1]) and ((level - x[1]) / (y[1] - x[1])) or 0
            return x[2] + (y[2] - x[2]) * t, x[3] + (y[3] - x[3]) * t
        end
    end
end
function MSC.LevelingGearBlend(gear, level, row)
    if not (gear and gear.low and gear.power and row) then return row end
    local lo, hi = LerpLevels(gear.power, level)
    -- the two kits too close to tell apart: keep the shipped row
    if not (lo and hi and hi > lo * 1.02) then return row end
    local power = MSC.GetGearPower(row, true)
    if not power then
        MSC.GearPointPending = true -- re-read once the items load (Evaluator CacheCleaner)
        return row, 1
    end
    local f = (power - lo) / (hi - lo)
    if f >= 1 then return row, 1, power, lo, hi end
    if f < 0 then f = 0 end
    -- a stat missing from one row counts as 0 there (as between keyframes)
    local low = MSC.EvaluateLevelingCurve(gear.low, level)
    local out = {}
    local function put(k)
        if out[k] ~= nil then return end
        local a, v = tonumber(row[k]) or 0, tonumber(low[k]) or 0
        local b = v + (a - v) * f
        if b > 0 and b < 0.02 then b = 0 end
        out[k] = b
    end
    for k in pairs(row) do put(k) end
    for k in pairs(low) do put(k) end
    return out, f, power, lo, hi
end

-- The gear point entry for a raw weights table (by table, so a retired
-- alias that points at a raid profile finds it too), or nil.
-- Each entry becomes { lo, hi, steps = { { power, weights, tier }, ... } }
-- in rising power; the first step's weights are the raw table itself.
-- Forever: two steps (pre-raid, Tier 1). Classic Era (Classes/ERA/
-- GearPoints_Era.lua, from SimStudio era_gearpoints.py): every raid tier
-- wowsims classic has a usable set for; not on Season of Discovery, whose
-- gear doesn't follow the Era tiers.
local gpByTable, gpClassTable = nil, nil
function MSC.GetGearPoint(raw)
    local cls = MSC.CurrentClass
    local src = MSC.IsForever and MSC.ForeverGearPoints or (MSC.IsEra and not MSC.IsSoD and MSC.EraGearPoints)
    if not (raw and cls and cls.Weights and src) then return nil end
    if gpClassTable ~= cls then
        gpByTable, gpClassTable = setmetatable({}, { __mode = "k" }), cls
        for pid, gp in pairs(src[cls.Name or ""] or {}) do
            local t = cls.Weights[pid]
            local steps
            if gp.t1 then
                if gp.hi and gp.lo and gp.hi > gp.lo then
                    steps = { { power = gp.lo, tier = "pre" }, { power = gp.hi, weights = gp.t1, tier = "T1" } }
                end
            elseif #gp >= 2 then
                steps = {}
                for i, p in ipairs(gp) do
                    steps[i] = { power = p.power, weights = (i > 1) and p.weights or nil, tier = p.tier }
                end
            end
            if t and steps then
                gpByTable[t] = { lo = steps[1].power, hi = steps[#steps].power, steps = steps, t1 = gp.t1 }
            end
        end
    end
    return gpByTable[raw]
end

-- Raw weights slid along the profile's gear points by the character's gear
-- power: the raw table itself at or below the first set's power (or when the
-- gear isn't read yet), the last set's weights at or above its power, in
-- between a straight line between the two sets around the power. Returns
-- weights, fraction of the way from the first set to the last (0..1, nil
-- when the profile has no gear points), gear power, and the two steps the
-- power sits between.
function MSC.GearPointBlend(raw)
    if not (MSC.IsForever or MSC.IsEra) then return raw end
    local gp = MSC.GetGearPoint(raw)
    if not gp then return raw end
    local power = MSC.GetGearPower(raw)
    if not power then
        MSC.GearPointPending = true -- re-read once the items load (Evaluator CacheCleaner)
        return raw, 0
    end
    local steps, n = gp.steps, #gp.steps
    if power <= steps[1].power then return raw, 0, power, steps[1], steps[1] end
    local a, b = steps[n - 1], steps[n]
    if power >= b.power then
        a = b -- past the last set: hold its weights
    else
        for i = 1, n - 1 do
            if power < steps[i + 1].power then a, b = steps[i], steps[i + 1]; break end
        end
    end
    local t = (b.power > a.power) and math.min(1, (power - a.power) / (b.power - a.power)) or 0
    local f = math.min(1, (power - gp.lo) / (gp.hi - gp.lo))
    local wa, wb = a.weights or raw, b.weights or raw
    local out = {}
    for k, v in pairs(raw) do out[k] = v end
    for k, v in pairs(wb) do
        local x = tonumber(wa[k] or raw[k]) or 0
        out[k] = x + (v - x) * t
    end
    for k, v in pairs(wa) do
        if wb[k] == nil then out[k] = v end
    end
    return out, f, power, a, b
end

-- Hit Rating on the gear for a kind of attack ("MELEE", "RANGED", "SPELL"),
-- or nil when the gear isn't scanned yet. Forever's hit rating counts for
-- every kind (one unified stat); TBC keeps spell hit apart.
function MSC.GetGearHitRating(kind)
    local t = MSC.GetGearStatTotals()
    if not t then return nil end
    local hit, melee, ranged, spell = t["ITEM_MOD_HIT_RATING_SHORT"] or 0, t["ITEM_MOD_HIT_MELEE_RATING_SHORT"] or 0,
        t["ITEM_MOD_HIT_RANGED_RATING_SHORT"] or 0, t["ITEM_MOD_HIT_SPELL_RATING_SHORT"] or 0
    if MSC.IsForever then return hit + melee + ranged + spell end
    if kind == "SPELL" then return spell end
    return hit + ((kind == "RANGED") and ranged or melee)
end

-- The character's stats without buffs: the live numbers minus what the
-- active buffs add (MSC.BuffAuras, per game version in Buffs_<version>.lua:
-- spell id -> flat STR/AGI/STA/INT/SPI/ALL, <stat>_PCT, AP, RAP, AP_PCT,
-- RAP_PCT, SP (every school), SP_<SCHOOL>, HEAL, ARMOR, MANA, HIT/SPELL_HIT %).
-- A % buff multiplies the stat, a flat one adds; Strength/Agility/Intellect
-- lost this way also come off Attack Power, armor and mana. Fields: str,
-- agi, sta, int, spi, ap, rap, sp, heal, armor, mana, spSchool[school],
-- buffHitPct, buffSpellHitPct (hit % the live buffs give).
-- Talents that multiply a stat aren't divided out of a flat buff's share,
-- which is close enough for the thresholds this feeds.
local AP_PER = { -- AttackPowerPerStrength, AttackPowerPerAgility, RangedAttackPowerPerAgility (ChrClasses)
    WARRIOR = { 2, 0, 1 }, PALADIN = { 2, 0, 0 }, SHAMAN = { 2, 0, 0 }, DRUID = { 2, 0, 0 },
    ROGUE = { 1, 1, 2 }, HUNTER = { 1, 1, 2 },
}
local STAT_INDEX = { str = 1, agi = 2, sta = 3, int = 4, spi = 5 }
local STAT_KEY = { str = "STR", agi = "AGI", sta = "STA", int = "INT", spi = "SPI" }
local SCHOOL_KEY = { [2] = "SP_HOLY", [3] = "SP_FIRE", [4] = "SP_NATURE", [5] = "SP_FROST", [6] = "SP_SHADOW", [7] = "SP_ARCANE" }

-- Sum of buff effects: flat[s], mult[s], ap, rap, apMult, rapMult, sp,
-- spSchool[school], heal, armor, mana, hit, spellHit.
function MSC.NewBuffSum()
    return { flat = { str = 0, agi = 0, sta = 0, int = 0, spi = 0 }, mult = { str = 1, agi = 1, sta = 1, int = 1, spi = 1 },
        ap = 0, rap = 0, apMult = 1, rapMult = 1, sp = 0, spSchool = { 0, 0, 0, 0, 0, 0, 0 },
        heal = 0, armor = 0, mana = 0, hit = 0, spellHit = 0 }
end

-- Adds one buff (a MSC.BuffAuras entry) to a sum. pointsValue: the live
-- value of an entry with P (read from the aura's points).
function MSC.AddBuffEffects(sum, b, pointsValue)
    local function V(k)
        if b.P == k and pointsValue then return pointsValue end
        return b[k] or 0
    end
    for s, K in pairs(STAT_KEY) do
        sum.flat[s] = sum.flat[s] + V(K) + V("ALL")
        local pct = V(K .. "_PCT") + V("ALL_PCT")
        if pct ~= 0 then sum.mult[s] = sum.mult[s] * (1 + pct / 100) end
    end
    sum.ap, sum.rap = sum.ap + V("AP"), sum.rap + V("RAP")
    if V("AP_PCT") ~= 0 then sum.apMult = sum.apMult * (1 + V("AP_PCT") / 100) end
    if V("RAP_PCT") ~= 0 then sum.rapMult = sum.rapMult * (1 + V("RAP_PCT") / 100) end
    sum.sp, sum.heal = sum.sp + V("SP"), sum.heal + V("HEAL")
    for school, K in pairs(SCHOOL_KEY) do sum.spSchool[school] = sum.spSchool[school] + V(K) end
    sum.armor, sum.mana = sum.armor + V("ARMOR"), sum.mana + V("MANA")
    sum.hit, sum.spellHit = sum.hit + V("HIT"), sum.spellHit + V("SPELL_HIT")
end

-- The live value of a shared aura (a MSC.BuffAuras entry with P): the first
-- non-zero of the aura's points, or nil when the client doesn't give them.
local function AuraPointsValue(auraData)
    local pts = auraData and auraData.points
    if type(pts) ~= "table" then return nil end
    for _, v in ipairs(pts) do
        v = MSC.SanitizeStat(v)
        if v ~= 0 then return v end
    end
    return nil
end

local unbuffed, unbuffedTime = nil, nil
function MSC.GetUnbuffedStats()
    local now = GetTime and GetTime() or 0
    if unbuffed and unbuffedTime == now then return unbuffed end
    local sum = MSC.NewBuffSum()
    local db = MSC.BuffAuras
    if db then
        MSC.ForEachPlayerBuff(function(spellId, auraData)
            local b = db[spellId]
            if b then MSC.AddBuffEffects(sum, b, b.P and AuraPointsValue(auraData)) end
        end)
    end
    local u, delta = {}, {}
    for s, i in pairs(STAT_INDEX) do
        local live = MSC.SanitizeStat(select(2, UnitStat("player", i)))
        u[s] = math_max(0, live / sum.mult[s] - sum.flat[s])
        delta[s] = live - u[s]
    end
    local _, class = UnitClass("player")
    local per = AP_PER[class] or { 1, 0, 0 }
    local liveAP, liveRAP = 0, 0
    if UnitAttackPower then
        local b, p, n = UnitAttackPower("player")
        liveAP = MSC.SanitizeStat(b) + MSC.SanitizeStat(p) + MSC.SanitizeStat(n)
    end
    if UnitRangedAttackPower then
        local b, p, n = UnitRangedAttackPower("player")
        liveRAP = MSC.SanitizeStat(b) + MSC.SanitizeStat(p) + MSC.SanitizeStat(n)
    end
    u.ap = math_max(0, liveAP / sum.apMult - sum.ap - delta.str * per[1] - delta.agi * per[2])
    u.rap = math_max(0, liveRAP / sum.rapMult - sum.rap - delta.agi * per[3])
    u.spSchool = {}
    u.sp = 0
    for school = 2, 7 do
        local live = GetSpellBonusDamage and MSC.SanitizeStat(GetSpellBonusDamage(school)) or 0
        u.spSchool[school] = math_max(0, live - sum.sp - sum.spSchool[school])
        u.sp = math_max(u.sp, u.spSchool[school])
    end
    u.heal = math_max(0, (GetSpellBonusHealing and MSC.SanitizeStat(GetSpellBonusHealing()) or 0) - sum.heal)
    local liveArmor = UnitArmor and MSC.SanitizeStat(select(2, UnitArmor("player"))) or 0
    u.armor = math_max(0, liveArmor - sum.armor - 2 * delta.agi)
    local liveMana = UnitPowerMax and MSC.SanitizeStat(UnitPowerMax("player", 0)) or 0
    u.mana = math_max(0, liveMana - sum.mana - 15 * delta.int)
    u.buffHitPct, u.buffSpellHitPct = sum.hit, sum.spellHit
    unbuffed, unbuffedTime = u, now
    return u
end

-- The stats gear is judged with: unbuffed, plus the buffs Buff Assumptions
-- assume (MSC.BuffEngine:GetAssumedBuffSum). Same fields as
-- MSC.GetUnbuffedStats, plus assumedHitPct / assumedSpellHitPct.
local judging, judgingTime, judgingRev = nil, nil, nil
function MSC.GetJudgingStats()
    local now, rev = GetTime and GetTime() or 0, MSC.ScoringRevision or 0
    if judging and judgingTime == now and judgingRev == rev then return judging end
    local u = MSC.GetUnbuffedStats()
    local a = MSC.BuffEngine and MSC.BuffEngine.GetAssumedBuffSum and MSC.BuffEngine:GetAssumedBuffSum()
    local j = {}
    for k, v in pairs(u) do j[k] = v end
    j.assumedHitPct, j.assumedSpellHitPct = 0, 0
    if a then
        local d = {}
        for s in pairs(STAT_INDEX) do
            j[s] = (u[s] + a.flat[s]) * a.mult[s]
            d[s] = j[s] - u[s]
        end
        local _, class = UnitClass("player")
        local per = AP_PER[class] or { 1, 0, 0 }
        j.ap = (u.ap + a.ap + d.str * per[1] + d.agi * per[2]) * a.apMult
        j.rap = (u.rap + a.rap + d.agi * per[3]) * a.rapMult
        j.spSchool, j.sp = {}, 0
        for school = 2, 7 do
            j.spSchool[school] = (u.spSchool[school] or 0) + a.sp + a.spSchool[school]
            j.sp = math_max(j.sp, j.spSchool[school])
        end
        j.heal = u.heal + a.heal
        j.armor = u.armor + a.armor + 2 * d.agi
        j.mana = u.mana + a.mana + 15 * d.int
        j.assumedHitPct, j.assumedSpellHitPct = a.hit, a.spellHit
    end
    judging, judgingTime, judgingRev = j, now, rev
    return j
end

-- Spell damage of one school (2 Holy, 3 Fire, 4 Nature, 5 Frost, 6 Shadow,
-- 7 Arcane) that gear is judged with: GetSpellBonusDamage(school) without
-- live buffs, with assumed ones.
function MSC.GetJudgingSpellDamage(school)
    return MSC.GetJudgingStats().spSchool[school] or 0
end

-- Current hit % in one place, talents included once. Forever gear carries
-- Hit Rating (10 = 1%), which the old GetHitModifier() path didn't see.
-- kind: "MELEE", "RANGED" or "SPELL". /sgj hitcheck prints the parts.
-- The rating part is the gear's (unbuffed); the live rating is the fallback.
local CR_HIT = { MELEE = 6, RANGED = 7, SPELL = 8 }
function MSC:GetForeverHitPercent(kind)
    kind = kind or "MELEE"
    local cr = CR_HIT[kind] or 6
    local fromRating
    local gear = MSC.GetGearHitRating(kind)
    if gear then
        fromRating = gear / 10
    elseif GetCombatRatingBonus then
        fromRating = MSC.SanitizeStat(GetCombatRatingBonus(cr))
    else
        fromRating = MSC.SanitizeStat(GetCombatRating and GetCombatRating(cr) or 0) / 10
    end
    local modifier
    if kind == "SPELL" then
        modifier = MSC.SanitizeStat(GetSpellHitModifier and GetSpellHitModifier() or 0)
    else
        modifier = MSC.SanitizeStat(GetHitModifier and GetHitModifier() or 0)
    end
    -- talents and racials: hit % from live buffs comes off, assumed buffs add theirs
    local j = MSC.GetJudgingStats()
    if kind == "SPELL" then
        modifier = math_max(0, modifier - j.buffSpellHitPct) + j.assumedSpellHitPct
    else
        modifier = math_max(0, modifier - j.buffHitPct) + j.assumedHitPct
    end
    return fromRating + modifier, fromRating, modifier
end

-- Scales a hit weight for the current hit % against the level's target:
-- full value below the target, overcapMult of it above. extraHit is for
-- school-only talents (Shadow Focus, Elemental Precision, Suppression) that
-- the game's general spell-hit number doesn't include.
-- capKind: a different cap target than kind's (SPELL_DUNGEON); the player's hit is still read as kind
function MSC.ApplyForeverHitCap(weights, key, kind, overcapMult, label, activeCaps, extraHit, capKind)
    local cap = MSC.GetForeverCapTarget(capKind or (kind == "RANGED" and "MELEE" or kind))
    MSC.ApplyForeverHitKnees(weights, key, kind, { { cap = cap, mult = overcapMult or 0.1 } }, label, activeCaps, extraHit)
end

-- Suppression (+2% hit per point, Era/TBC) covers Affliction spells only, so it counts toward
-- the spell-hit cap for DoT profiles (Affliction, leveling) but not for the raid builds whose
-- main nuke is Shadow Bolt (DS/Ruin, SM/Ruin).
function MSC.SuppressionCounts(spec)
    spec = tostring(spec or "")
    return (spec:find("AFFLICTION") or spec:find("Leveling")) and not spec:find("Fire") and true or false
end

-- Thorns damage ("When struck") is priced at a tank's hits taken (Parse ProcRate.struck), so it
-- counts only for profiles that are the ones getting hit: tanks, and solo leveling (you tank your
-- own pulls). Group DPS and healers are rarely struck.
function MSC.ThornsCount(spec)
    local s = tostring(spec or "")
    if s:find("Leveling") and not s:find("Dungeon") then return true end
    local class = MSC.CurrentClass and MSC.CurrentClass.Name
    return MSC.GetRingRole ~= nil and MSC.GetRingRole(class, s) == "tank"
end

-- The spell-hit cap target for a weights row: dungeon leveling rows ("...Dungeon...") use SPELL_DUNGEON.
function MSC.ForeverSpellCapKind(spec)
    if type(spec) == "string" and spec:find("Dungeon") then return "SPELL_DUNGEON" end
    return nil
end

-- General form: knees = { { cap = pct, mult = m }, ... } in rising order.
-- Hit is worth the full weight below the first cap, then each knee's mult
-- of it. Sets the weight for the player's current hit and records the curve
-- in MSC.ForeverHitCapState so the upgrade check can value an item that
-- crosses a cap (see MSC.ForeverHitCapCorrection).
function MSC.ApplyForeverHitKnees(weights, key, kind, knees, label, activeCaps, extraHit)
    local full = weights[key]
    if not full or full <= 0 then return end
    local hit = MSC:GetForeverHitPercent(kind) + (extraHit or 0)
    local mult, reached = 1, nil
    for _, k in ipairs(knees) do
        if hit >= k.cap then mult, reached = k.mult, k.cap end
    end
    weights[key] = full * mult
    -- Kept per weights table (weak keys), so each profile's curve stays with
    -- the weights it produced.
    MSC.ForeverHitCapState = MSC.ForeverHitCapState or setmetatable({}, { __mode = "k" })
    local byKey = MSC.ForeverHitCapState[weights] or {}
    byKey[key] = { kind = kind, extra = extraHit or 0, knees = knees, mult = mult }
    MSC.ForeverHitCapState[weights] = byKey
    if reached and activeCaps then table.insert(activeCaps, string_format("%s (%.1f%%)", label or MSC.L["Hit"], reached)) end
end

-- Value of `hit` percent points under a knee curve, in units of the full weight.
local function KneeValue(knees, hit)
    local value, prevCap, prevMult = 0, 0, 1
    for _, k in ipairs(knees) do
        if hit <= k.cap then return value + (hit - prevCap) * prevMult end
        value = value + (k.cap - prevCap) * prevMult
        prevCap, prevMult = k.cap, k.mult
    end
    return value + (hit - prevCap) * prevMult
end

-- Score correction for swapping gear from oldRating to newRating total Hit
-- Rating (Forever: 10 rating = 1%). The weights charge every point at the
-- current slope; this replaces that with the true curve, so hit that goes
-- past a cap is discounted and hit that drops back below one is charged in
-- full. Returns the correction and the cap crossed downward, if any.
-- fromBaseline: oldRating is a saved set's own total (off-spec best gear),
-- not the worn gear's. Otherwise the swap starts from the worn gear's real
-- Hit Rating (enchants and set bonuses in, as the knee slope reads it) and
-- moves by the difference the scorer's totals give.
function MSC.ForeverHitCapCorrection(weights, oldRating, newRating, fromBaseline)
    if oldRating == newRating then return 0 end
    if not fromBaseline then
        local real = MSC.GetGearHitRating and MSC.GetGearHitRating("MELEE")
        if real then oldRating, newRating = real, real + (newRating - oldRating) end
    end
    return MSC.ForeverHitCapCorrectionFor(MSC.ForeverHitCapSnapshot(weights), oldRating, newRating)
end

-- The hit curve behind a weights table as plain data, for scoring later
-- without the live character (Roster saves it with each alt's weights):
-- { w = the hit weight the scorer charges, full = its value below the first
-- cap, knees, base = hit % that isn't from gear (talents, racials, assumed
-- buffs) }. nil when the weights have no hit curve.
function MSC.ForeverHitCapSnapshot(weights)
    local state = MSC.ForeverHitCapState and MSC.ForeverHitCapState[weights]
    if not state then return nil end
    -- Use the hit key the scorer uses (the largest hit weight)
    local key, w = nil, 0
    for k in pairs(state) do
        local kw = weights[k] or 0
        if kw > w then key, w = k, kw end
    end
    if not key then return nil end
    local st = state[key]
    if st.mult <= 0 then return nil end
    local _, _, modifier = MSC:GetForeverHitPercent(st.kind)
    return { w = w, full = w / st.mult, knees = st.knees, base = modifier + st.extra }
end

-- Correction for a swap from oldRating to newRating total Hit Rating on a
-- snapshot from MSC.ForeverHitCapSnapshot. Also returns how far under a cap
-- the swap leaves the character when it drops below one it had reached
-- (the lowest such cap), or nil.
function MSC.ForeverHitCapCorrectionFor(snap, oldRating, newRating)
    if not snap or oldRating == newRating then return 0 end
    local cur, fut = snap.base + oldRating / 10, snap.base + newRating / 10
    local trueDelta = snap.full * (KneeValue(snap.knees, fut) - KneeValue(snap.knees, cur))
    local charged = snap.w * (fut - cur)
    local droppedBelow
    for _, k in ipairs(snap.knees) do
        if cur >= k.cap and fut < k.cap then droppedBelow = fut - k.cap; break end
    end
    return trueDelta - charged, droppedBelow
end

-- Total Hit Rating in a stats table (Forever has one hit rating for every
-- kind of attack; older keys are summed in case an item still carries them).
function MSC.HitRatingOf(t)
    if not t then return 0 end
    return (t["ITEM_MOD_HIT_RATING_SHORT"] or 0) + (t["ITEM_MOD_HIT_SPELL_RATING_SHORT"] or 0)
        + (t["ITEM_MOD_HIT_MELEE_RATING_SHORT"] or 0) + (t["ITEM_MOD_HIT_RANGED_RATING_SHORT"] or 0)
end

-- Tank defense toward the raid target: past the target, Defense is worth
-- much less (Stamina and armor take over).
function MSC.ApplyForeverDefenseTarget(weights, activeCaps)
    local w = weights["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"]
    if not w or w <= 0 then return end
    local target = MSC.GetForeverDefenseTarget()
    if not target then return end
    local def = MSC:GetPlayerStat("DEFENSE")
    if def >= target then
        weights["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] = w * 0.3
        if activeCaps then table.insert(activeCaps, string_format("%s (%d)", MSC.L["Defense"], target)) end
    end
end

-- Shield tanks: once miss + dodge + parry + block (+ the shield's active
-- block ability) reaches 102.4%, crushing blows can't land, so more
-- avoidance/block is worth less and effective health takes over. From 50
-- when gearing for raids (dungeon and raid bosses are +2/+3), always at 60.
-- Calls fn(spellId, auraData) for each of the player's buffs; stops when fn
-- returns true. Auras can be secret (e.g. while logging in), and then
-- GetAuraDataByIndex throws for tainted callers, so read them protected and
-- treat that as no readable buffs.
function MSC.ForEachPlayerBuff(fn)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or not a then break end
            if fn(MSC.SanitizeStat(a.spellId), a) then return end
        end
    elseif UnitBuff then
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
            if not name then break end
            if fn(MSC.SanitizeStat(spellId), { name = name, spellId = spellId }) then return end
        end
    end
end

-- Active block abilities (spell id -> block %): while one is up it is part
-- of GetBlockChance(), but the uncrushable check adds the ability itself.
MSC.ActiveBlockAuras = {
    [2565] = 75, [12169] = 75, [467891] = 30,                -- Shield Block
    [20925] = 30, [20927] = 30, [20928] = 30, [27179] = 30,  -- Holy Shield
}

-- Block chance without an active Shield Block / Holy Shield.
function MSC.GetPassiveBlockChance()
    local block = GetBlockChance and MSC.SanitizeStat(GetBlockChance()) or 0
    MSC.ForEachPlayerBuff(function(spellId)
        local pct = MSC.ActiveBlockAuras[spellId]
        if pct then block = block - pct end
    end)
    return math_max(0, block)
end

-- Spell ids of the active block abilities by the % a class passes in, for the tooltip reminder
local ACTIVE_BLOCK_SPELL = { [30] = 20925, [75] = 2565 }   -- Holy Shield, Shield Block

function MSC.ApplyForeverUncrushable(weights, activeBlockPct, activeCaps)
    MSC.UncrushableNeedsActive = nil
    if MSC.GetRaidBlend() <= 0 then return end
    local dodge = GetDodgeChance and MSC.SanitizeStat(GetDodgeChance()) or 0
    local parry = GetParryChance and MSC.SanitizeStat(GetParryChance()) or 0
    local block = MSC.GetPassiveBlockChance()
    local total = 5 + dodge + parry + block + (activeBlockPct or 0)
    -- uncrushable only with the active block ability (Holy Shield / Shield Block) up: the tooltip reminds the player
    -- (Judge.lua); the value is that ability's name. The gear is judged as if it is up on bosses (correct play).
    if (activeBlockPct or 0) > 0 and total >= MSC.ForeverCaps.UNCRUSHABLE and total - activeBlockPct < MSC.ForeverCaps.UNCRUSHABLE then
        local id = ACTIVE_BLOCK_SPELL[activeBlockPct]
        local name = id and ((C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or (GetSpellInfo and GetSpellInfo(id)))
        MSC.UncrushableNeedsActive = name or true
    end
    if total >= MSC.ForeverCaps.UNCRUSHABLE then
        for _, k in ipairs({ "ITEM_MOD_BLOCK_RATING_SHORT", "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_PARRY_RATING_SHORT" }) do
            if weights[k] then weights[k] = weights[k] * 0.8 end
        end
        if weights["ITEM_MOD_STAMINA_SHORT"] then weights["ITEM_MOD_STAMINA_SHORT"] = weights["ITEM_MOD_STAMINA_SHORT"] * 1.2 end
        if weights["ITEM_MOD_ARMOR_SHORT"] then weights["ITEM_MOD_ARMOR_SHORT"] = weights["ITEM_MOD_ARMOR_SHORT"] * 1.2 end
        if activeCaps then table.insert(activeCaps, MSC.L["Uncrushable"]) end
    end
end

-- =============================================================
-- 5.8 FOREVER RELICS
-- =============================================================
-- Relic effects are mostly percentages and cooldowns the parser can't read,
-- so each class's Relics table turns them into equivalent stats for the
-- player's spec (see Classes/Forever/Paladin|Druid|Shaman.lua). This is the
-- live character data those conversions use.
function MSC.GetRelicContext()
    local _, class = UnitClass("player")
    local level = UnitLevel("player") or 1
    -- Without live buffs, with assumed ones (MSC.GetJudgingStats)
    local u = MSC.GetJudgingStats()
    local spirit, agi, ap = u.spi, u.agi, u.ap
    local baseArmor = UnitArmor and MSC.SanitizeStat((UnitArmor("player"))) or 0
    -- Classic mana regen from Spirit, per 5 sec outside the five-second rule
    local regenPerTick = (class == "SHAMAN") and (17 + spirit / 5) or (15 + spirit / 5)
    return {
        level = level, spirit = spirit, ap = ap,
        itemArmor = math_max(0, baseArmor - 2 * agi),
        spiritRegen5 = regenPerTick * 2.5,
        shieldBlock = GetShieldBlock and MSC.SanitizeStat(GetShieldBlock()) or 0,
    }
end

-- Which kind of spec a relic is being valued for.
function MSC.RelicRole(spec)
    local s = (spec or ""):upper()
    -- SHOCKADIN is Holy: Raid with Holy Shock's damage counted (a healer for its Librams)
    if s:find("HEAL") or s:find("RESTO") or s:find("HOLY") or s:find("SHOCKADIN") then return "healer" end
    if s:find("TANK") or s:find("BEAR") or s:find("PROT") then return "tank" end
    if s:find("CASTER") or s:find("BALANCE") or s:find("BOOMKIN") or s:find("ELE") then return "caster" end
    return "melee"
end

-- Classic Era racial weapon skill (+5 with a weapon type, e.g. Human swords):
-- worth `skill` points of the profile's own Weapon Skill weight, read from the
-- class module's unscaled row (ApplyScalers cuts that weight once a racial
-- already gives the +5, which is the value of skill beyond the racial, not of
-- the racial itself). Profiles without a Weapon Skill weight (leveling rows)
-- use a tenth of the Hit weight per point: against mobs of your level each
-- point is about 0.1% fewer misses. `module` is the class module (Roster
-- scores other characters' classes), weights the profile's final weights.
function MSC.EraWeaponSkillBonus(module, weights, specName, skill)
    local K = "ITEM_MOD_WEAPON_SKILL_RATING_SHORT"
    local raw = module and specName and ((module.Weights and module.Weights[specName]) or (module.LevelingWeights and module.LevelingWeights[specName]))
    local per = (type(raw) == "table" and raw[K]) or (weights and weights[K])
    if not per or per <= 0 then per = 0.1 * ((weights and weights["ITEM_MOD_HIT_RATING_SHORT"]) or 0) end
    return skill * per
end

-- Shared GetRelicBonus body: Relics entries are either a stat table or a
-- function(role, ctx, spec) returning one.
function MSC.GetForeverRelicBonus(relics, itemID, spec)
    local entry = relics and relics[itemID]
    if not entry then return {} end
    if type(entry) == "function" then
        local ok, res = pcall(entry, MSC.RelicRole(spec), MSC.GetRelicContext(), spec or "")
        return (ok and type(res) == "table") and res or {}
    end
    local bonus = {}
    for k, v in pairs(entry) do bonus[k] = v end
    return bonus
end

function MSC.ApplyForeverDualWieldHitTaper(hitWeight, totalHitPct, softCap, hardCap)
    softCap = softCap or 9
    hardCap = hardCap or 28
    if not hitWeight or totalHitPct < softCap then return hitWeight, false end
    if totalHitPct >= hardCap then return hitWeight * 0.05, true end
    return hitWeight * 0.6, true -- retains most of its value across the 9%-28% band
end

-- =============================================================
-- 5.9 FOREVER TALENT HOOK HELPERS
-- =============================================================
-- Shared pieces for the per-class ApplyScalers talent hooks so every class
-- applies the same rules:
--   * a crit multiplier must also move the primary stat that carries crit
--     (Agility for melee, Intellect for spells), because primary stats are
--     scored only through their own weight;
--   * a flat "+X% damage" talent scales every damage-derived weight
--     together, so it is applied by dividing the safety stats instead of
--     multiplying Spell Power or Attack Power alone.
-- Stat-per-1%-crit tables come from the client's PlayerExpectedStat
-- (build 1.60.1.70009), index = level 1..60.
MSC.ForeverCritPerStat = {
    WARRIOR = {
        agi = { 4, 4.20, 4.20, 4.40, 4.60, 4.80, 4.80, 5, 5.20, 5.20, 5.40, 5.60, 6, 6.20, 6.40, 6.60, 6.80, 7.20, 7.40, 7.80, 7.80, 8, 8.40, 8.60, 9, 9.20, 9.40, 9.80, 10, 10.40, 10.60, 10.80, 11.20, 11.40, 11.81, 12, 12.20, 12.59, 12.80, 13.19, 13.61, 13.79, 14.20, 14.41, 14.79, 14.99, 15.41, 15.80, 16, 16.39, 16.81, 17.01, 17.39, 17.79, 18.21, 18.42, 18.80, 19.19, 19.61, 20 },
        int = nil,
    },
    PALADIN = {
        agi = { 4.65, 4.88, 4.88, 5.12, 5.12, 5.35, 5.35, 5.58, 5.58, 5.81, 5.81, 6.05, 6.51, 6.51, 6.98, 6.98, 7.21, 7.67, 7.67, 8.14, 8.38, 8.38, 8.83, 9.07, 9.30, 9.53, 9.77, 10, 10.24, 10.70, 10.93, 10.93, 11.39, 11.63, 12.09, 12.33, 12.33, 12.79, 13.02, 13.50, 13.72, 13.72, 14.18, 14.41, 14.88, 15.11, 15.34, 15.82, 16.05, 16.50, 16.75, 16.98, 17.45, 17.67, 18.15, 18.38, 18.59, 19.08, 19.31, 19.76 },
        int = { 13.33, 14.01, 14.01, 14.66, 14.66, 15.34, 16, 16, 16.67, 16.67, 17.33, 17.99, 18.66, 19.34, 20.66, 20.66, 21.32, 22.68, 22.68, 23.98, 24.69, 25.32, 25.97, 26.67, 28.01, 28.65, 28.65, 30.03, 30.67, 31.95, 32.68, 33.33, 34.01, 34.72, 35.97, 36.63, 37.31, 38.61, 39.37, 40.65, 41.32, 42.02, 43.29, 43.29, 44.64, 45.25, 46.73, 48.08, 48.78, 50, 50.76, 51.28, 52.63, 53.19, 54.64, 55.25, 55.87, 58.14, 58.82, 59.88 },
    },
    HUNTER = {
        agi = { 4.60, 4.80, 5, 5.40, 5.60, 5.80, 6, 6.20, 6.60, 6.80, 7.40, 8.40, 9.20, 10, 11, 11.60, 12.41, 13.40, 14.20, 15.20, 15.80, 16.81, 17.61, 18.59, 19.42, 20.20, 21.19, 21.98, 22.99, 23.98, 24.57, 25.58, 26.60, 27.40, 28.41, 29.24, 30.21, 31.15, 32.15, 33, 33.78, 34.84, 35.84, 36.76, 37.74, 38.61, 39.53, 40.82, 41.84, 42.74, 43.67, 44.64, 45.66, 46.73, 47.85, 48.54, 49.75, 50.76, 52.08, 52.91 },
        int = { 14.29, 14.99, 14.99, 15.72, 15.72, 16.42, 16.42, 17.15, 17.15, 17.86, 17.86, 18.59, 20, 20, 21.41, 21.41, 22.12, 23.58, 23.58, 25, 25.71, 25.71, 27.17, 27.86, 28.57, 29.33, 30.03, 30.67, 31.45, 32.89, 33.56, 33.56, 34.97, 35.71, 37.17, 37.88, 37.88, 39.22, 40, 41.49, 42.19, 42.19, 43.48, 44.25, 45.66, 46.51, 47.17, 48.54, 49.26, 50.76, 51.55, 52.08, 53.48, 54.35, 55.87, 56.50, 57.14, 58.48, 59.17, 60.61 },
    },
    ROGUE = {
        agi = { 2.30, 2.40, 2.50, 2.70, 2.80, 2.90, 3.10, 3.20, 3.30, 3.50, 3.90, 4.30, 4.80, 5.20, 5.80, 6.20, 6.60, 7.10, 7.60, 8.10, 8.60, 9, 9.50, 9.90, 10.50, 11, 11.40, 11.90, 12.41, 13, 13.40, 13.91, 14.41, 14.90, 15.50, 16, 16.39, 16.89, 17.39, 17.99, 18.48, 19.01, 19.49, 20.08, 20.70, 21.19, 21.69, 22.22, 22.68, 23.42, 23.92, 24.39, 25, 25.51, 26.11, 26.67, 27.17, 27.78, 28.33, 28.99 },
        int = nil,
    },
    PRIEST = {
        agi = { 10, 10, 10, 10.50, 10.50, 10.50, 10.50, 11, 11, 11, 11, 11.49, 11.49, 11.49, 11.49, 12, 12, 12, 12.50, 12.50, 12.50, 12.50, 13, 13, 13, 13.50, 13.50, 13.50, 14.01, 14.01, 14.01, 14.49, 14.49, 14.49, 14.99, 14.99, 14.99, 15.50, 15.50, 15.50, 16, 16, 16.50, 16.50, 16.50, 17.01, 17.01, 17.51, 17.51, 17.51, 17.99, 17.99, 18.48, 18.48, 19.01, 19.01, 19.49, 19.49, 20, 20 },
        int = { 5.24, 5.48, 5.71, 5.95, 6.43, 6.67, 6.91, 7.14, 7.38, 7.86, 8.57, 9.52, 10.24, 11.43, 12.38, 13.09, 14.29, 14.99, 15.95, 17.15, 17.86, 19.05, 19.76, 20.96, 21.88, 22.83, 23.81, 24.75, 25.71, 26.88, 27.86, 28.82, 29.76, 30.96, 31.95, 32.89, 34.01, 34.97, 35.97, 37.17, 38.02, 39.22, 40.16, 41.49, 42.55, 43.48, 44.84, 45.66, 46.95, 48.08, 49.02, 50.25, 51.28, 52.36, 53.76, 54.64, 55.87, 56.82, 58.48, 59.52 },
    },
    SHAMAN = {
        agi = { 6.06, 6.06, 6.37, 6.37, 6.67, 6.67, 6.67, 6.97, 6.97, 7.27, 7.27, 7.58, 7.58, 7.88, 8.18, 8.48, 8.48, 8.79, 8.79, 9.39, 9.39, 9.70, 9.70, 10, 10.30, 10.60, 10.60, 10.91, 10.91, 11.52, 11.52, 11.82, 12.12, 12.12, 12.72, 13.04, 13.04, 13.33, 13.33, 13.95, 14.25, 14.25, 14.53, 14.86, 15.15, 15.46, 15.75, 16.05, 16.05, 16.67, 16.98, 17.27, 17.27, 17.57, 18.18, 18.48, 18.80, 18.80, 19.08, 19.69 },
        int = { 7.78, 8.15, 8.52, 8.52, 8.89, 9.26, 9.63, 10, 10.37, 10.37, 11.11, 11.85, 12.97, 13.70, 14.81, 15.55, 16.29, 17.42, 18.15, 19.27, 20, 20.75, 21.83, 22.57, 23.70, 24.45, 25.19, 26.32, 27.03, 28.17, 29.24, 30.03, 31.15, 31.85, 33, 34.13, 34.84, 35.97, 36.63, 38.17, 38.91, 39.68, 40.82, 41.84, 42.92, 44.05, 44.84, 45.87, 46.95, 48.08, 49.26, 50, 51.55, 52.36, 53.76, 54.35, 55.56, 57.14, 57.80, 59.17 },
    },
    MAGE = {
        agi = { 11.11, 11.11, 11.11, 11.67, 11.67, 11.67, 11.67, 11.67, 11.67, 12.22, 12.22, 12.22, 12.22, 12.22, 12.77, 12.77, 12.77, 12.77, 12.77, 13.33, 13.33, 13.33, 13.33, 13.89, 13.89, 13.89, 13.89, 13.89, 14.45, 14.45, 14.45, 14.45, 14.99, 14.99, 14.99, 15.55, 15.55, 15.55, 15.55, 16.10, 16.10, 16.10, 16.10, 16.67, 16.67, 16.67, 17.21, 17.21, 17.21, 17.76, 17.76, 17.76, 18.35, 18.35, 18.35, 18.90, 18.90, 18.90, 19.46, 19.46 },
        int = { 5.21, 5.42, 5.62, 6.04, 6.25, 6.46, 6.67, 6.87, 7.29, 7.50, 8.12, 9.17, 9.79, 11.67, 12.71, 13.33, 14.16, 14.99, 15.82, 16.86, 17.51, 18.55, 19.16, 20.20, 21.05, 21.88, 22.94, 25.19, 26.25, 27.32, 27.93, 28.99, 29.76, 30.58, 31.65, 32.47, 33.56, 34.36, 35.46, 36.23, 37.04, 39.53, 40.49, 41.49, 42.55, 43.29, 44.44, 45.45, 46.51, 47.39, 48.31, 49.26, 50.25, 51.55, 52.63, 55.25, 56.50, 57.14, 58.48, 59.52 },
    },
    WARLOCK = {
        agi = { 6.67, 6.67, 7, 7, 7, 7.33, 7.33, 7.33, 7.67, 7.67, 8, 8, 8, 8.33, 8.67, 9, 9, 9, 9.34, 9.67, 10, 10, 10.33, 10.33, 11, 11, 11, 11.34, 11.34, 12, 12, 12.33, 12.33, 12.67, 13, 13.33, 13.66, 13.66, 14.01, 14.33, 14.66, 14.66, 14.99, 14.99, 15.67, 16, 16, 16.34, 16.67, 17.01, 17.33, 17.33, 17.67, 17.99, 18.35, 18.66, 19.01, 19.34, 19.34, 20 },
        int = { 6.67, 6.97, 7.27, 7.58, 7.88, 8.18, 8.48, 8.79, 9.09, 9.39, 10.30, 11.21, 12.12, 13.04, 13.95, 14.53, 15.75, 16.67, 17.57, 18.48, 19.38, 20.28, 21.23, 22.42, 23.31, 23.92, 25.13, 26.04, 27.25, 28.17, 28.82, 30.03, 30.86, 32.15, 33, 33.90, 35.21, 36.10, 37.31, 38.17, 39.06, 40.32, 41.15, 42.37, 43.67, 44.64, 45.45, 46.73, 47.85, 49.02, 50, 51.28, 52.36, 53.76, 54.95, 55.87, 56.82, 58.14, 59.52, 60.61 },
    },
    DRUID = {
        agi = { 4.88, 4.88, 5.12, 5.12, 5.36, 5.36, 5.61, 5.61, 5.85, 6.34, 6.58, 6.58, 6.83, 6.83, 7.32, 7.32, 7.56, 7.81, 7.81, 8.78, 8.78, 9.03, 9.27, 9.27, 9.76, 9.76, 10, 10.25, 10.25, 11.22, 11.47, 11.47, 11.71, 11.95, 12.20, 12.44, 12.69, 12.69, 12.92, 13.91, 14.14, 14.14, 14.39, 14.64, 15.13, 15.36, 15.36, 15.60, 15.85, 16.84, 17.06, 17.33, 17.57, 17.57, 18.05, 18.28, 18.55, 18.80, 19.01, 20 },
        int = { 6.87, 7.19, 7.50, 7.81, 8.12, 8.44, 8.75, 8.75, 9.07, 10, 10.63, 11.56, 12.18, 13.12, 14.37, 14.99, 15.95, 16.56, 17.51, 19.05, 19.69, 20.62, 21.23, 22.52, 23.42, 24.04, 25, 25.64, 26.88, 28.41, 29.07, 30.30, 30.96, 31.85, 33.11, 33.78, 34.72, 35.59, 36.50, 38.46, 39.06, 40.32, 40.98, 42.19, 43.10, 44.05, 45.05, 45.87, 47.17, 48.78, 49.75, 51.02, 51.55, 52.91, 54.05, 54.95, 55.87, 56.82, 58.14, 59.88 },
    },
}

function MSC.GetForeverLevel()
    return (UnitLevel and UnitLevel("player")) or 60
end

-- Agility points per 1% melee crit / Intellect points per 1% spell crit for
-- the player's class at a level (defaults: current level).
function MSC.GetForeverAgiPerCrit(level)
    local _, cls = UnitClass("player")
    local t = MSC.ForeverCritPerStat[cls or ""]
    local L = math.max(1, math.min(60, math.floor(level or MSC.GetForeverLevel())))
    return (t and t.agi and t.agi[L]) or 20
end

function MSC.GetForeverIntPerSpellCrit(level)
    local _, cls = UnitClass("player")
    local t = MSC.ForeverCritPerStat[cls or ""]
    local L = math.max(1, math.min(60, math.floor(level or MSC.GetForeverLevel())))
    return (t and t.int and t.int[L]) or 60
end

-- Linear interpolation through { {level, value}, ... } (sorted by level);
-- clamps outside the first/last point.
function MSC.ForeverLevelLerp(points, level)
    level = level or MSC.GetForeverLevel()
    if not points or #points == 0 then return 0 end
    if level <= points[1][1] then return points[1][2] end
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        if level <= b[1] then
            local t = (level - a[1]) / (b[1] - a[1])
            return a[2] + (b[2] - a[2]) * t
        end
    end
    return points[#points][2]
end

-- Multiply every listed key that exists in the row.
function MSC.ScaleForeverKeys(weights, keys, mult)
    if not weights or not mult or mult == 1 then return end
    for _, k in ipairs(keys) do
        if weights[k] then weights[k] = weights[k] * mult end
    end
end

-- Melee crit multiplier: scales the crit weight and adds the same gain to
-- Agility through the class's agi-per-crit at this level. Feral crit
-- (ITEM_MOD_CRIT_RATING_SHORT) uses the same key.
function MSC.ScaleForeverMeleeCrit(weights, mult, level)
    local key = "ITEM_MOD_CRIT_RATING_SHORT"
    if not weights or not weights[key] or not mult or mult == 1 then return end
    local old = weights[key]
    weights[key] = old * mult
    if weights["ITEM_MOD_AGILITY_SHORT"] then
        weights["ITEM_MOD_AGILITY_SHORT"] = weights["ITEM_MOD_AGILITY_SHORT"] + (weights[key] - old) / MSC.GetForeverAgiPerCrit(level)
    end
end

-- Spell crit multiplier: scales the spell crit weight and moves Intellect's
-- crit share by the same gain (int-per-spell-crit at this level).
function MSC.ScaleForeverSpellCrit(weights, mult, level)
    local key = "ITEM_MOD_SPELL_CRIT_RATING_SHORT"
    if not weights or not weights[key] or not mult or mult == 1 then return end
    local old = weights[key]
    weights[key] = old * mult
    if weights["ITEM_MOD_INTELLECT_SHORT"] then
        weights["ITEM_MOD_INTELLECT_SHORT"] = weights["ITEM_MOD_INTELLECT_SHORT"] + (weights[key] - old) / MSC.GetForeverIntPerSpellCrit(level)
    end
end

-- Keys that are NOT damage/healing-derived: a flat "+X% damage" talent
-- leaves these alone while everything else gains, so the talent is applied
-- as a division of this set (the AP / Spell Power unit stays fixed).
MSC.ForeverSafetyKeys = {
    "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_HEALTH_SHORT", "ITEM_MOD_ARMOR_SHORT",
    "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_BLOCK_RATING_SHORT",
    "ITEM_MOD_BLOCK_VALUE_SHORT", "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    "ITEM_MOD_HEALTH_REGENERATION_SHORT", "ITEM_MOD_RESILIENCE_RATING_SHORT",
    "ITEM_MOD_FIRE_RESISTANCE_SHORT", "ITEM_MOD_FROST_RESISTANCE_SHORT", "ITEM_MOD_NATURE_RESISTANCE_SHORT",
    "ITEM_MOD_SHADOW_RESISTANCE_SHORT", "ITEM_MOD_ARCANE_RESISTANCE_SHORT",
}

-- Flat damage (or healing) multiplier `mult` for the whole row: divides the
-- safety keys plus any `alsoKeep` keys (e.g. the wand for casters, since a
-- spell-damage talent does not touch it) by mult, so the damage family
-- rises relative to them without changing the unit.
function MSC.ApplyForeverDamageMult(weights, mult, alsoKeep)
    if not weights or not mult or mult == 1 or mult <= 0 then return end
    local inv = 1 / mult
    MSC.ScaleForeverKeys(weights, MSC.ForeverSafetyKeys, inv)
    if alsoKeep then MSC.ScaleForeverKeys(weights, alsoKeep, inv) end
end

-- The physical damage family, for talents that only boost melee/ranged
-- damage (e.g. a one-handed weapon specialization on a hybrid row).
MSC.ForeverMeleeDamageKeys = {
    "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
    "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "MSC_WEAPON_DPS_MELEE", "MSC_WEAPON_DPS_OH",
    "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HIT_RATING_SHORT",
    "MSC_WEAPON_SPEED", "MSC_OH_WEAPON_SPEED", "MSC_RANGED_WEAPON_SPEED", "ITEM_MOD_AGILITY_SHORT",
}

-- The spell damage family (school keys included), for a school-limited
-- damage talent applied at its school share.
MSC.ForeverSpellDamageKeys = {
    "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
    "ITEM_MOD_FIRE_DAMAGE_SHORT", "ITEM_MOD_FROST_DAMAGE_SHORT", "ITEM_MOD_ARCANE_DAMAGE_SHORT",
    "ITEM_MOD_NATURE_DAMAGE_SHORT", "ITEM_MOD_SHADOW_DAMAGE_SHORT", "ITEM_MOD_HOLY_DAMAGE_SHORT",
    "ITEM_MOD_HIT_SPELL_RATING_SHORT", "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
}

-- Mana-derived keys (the value of "more casts").
MSC.ForeverManaKeys = {
    "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_MANA_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT",
}

-- =============================================================
-- 5.10 FOREVER PVP
-- =============================================================
-- PvP can't be simmed like a raid boss, so this is a model laid over the
-- PvE weights (Research/study/pvp has the reasoning and a print-out of every
-- row). A fight between two players is roughly a race of time-to-kill: 1%
-- more health buys about as much as 1% more damage. Each row keeps its
-- damage stats and gets:
--   * Stamina priced from the row's own damage unit: what +1% output is
--     worth in that row, times SURVIVAL (0.5: winning needs the kill as well
--     as staying up), divided by the Stamina that adds 1% health at the
--     level. The unit is healing for healer rows, Attack Power for any row
--     with a real AP weight (Ret, Enhancement, Feral and tanks too: their
--     spell share is small and its base damage isn't a nuke's), otherwise
--     Spell Power. Healers come out Stamina-heavy: at high level a point of
--     healing is a small share of a big base heal.
--   * Armor, Defense and Dodge priced from that Stamina value, by how much
--     they cut incoming damage (half of it physical, 40% melee swings).
--   * Crit a little higher (burst decides fights), Spirit and Mp5 lower for
--     damage rows (fights are short).
-- Survival stats only ever go up (the row's own value stays if it's
-- higher), and hit stays at the player-vs-player targets because
-- GetRaidBlend returns 0 while PvP weights are active.
-- Level tables (keyframes, blended by level):
--   HP: the client's ExpectedStat PlayerHealth (naked) x 1.35 for gear
--       (x1.25 at 10, x1.4 at 60).
--   AP_EQ: attack power + 14 x weapon DPS of an average leveler.
--   SP_EQ: the main nuke's base damage over its coefficient + spell power
--       from gear; HEAL_EQ the same for heals (base about 2.5x).
MSC.ForeverPvP = {
    SURVIVAL = 0.5,
    PHYSICAL_SHARE = 0.5, -- of incoming damage, for armor
    MELEE_SHARE = 0.4,    -- of incoming damage that can be dodged
    DEFENSE_EHP = 0.0007, -- health fraction one Defense point is worth (crit taken + avoidance)
    CRIT_MULT = 1.1,
    REGEN_MULT = 0.6,
    LEVELS  = { 10,  20,  30,   40,   50,   60 },
    HP      = { 238, 679, 1185, 1827, 2603, 3644 },
    AP_EQ   = { 138, 330, 572,  834,  1140, 1500 },
    SP_EQ   = { 31,  94,  224,  421,  650,  911 },
    HEAL_EQ = { 78,  235, 615,  1160, 1690, 2050 },
    -- Average armor from gear per level, by what the class wears
    -- (cloth 13 x level, leather 26, mail 45 from 40, plate 75 from 40).
    ARMOR_PER_LEVEL = {
        MAGE = { 13, 13 }, PRIEST = { 13, 13 }, WARLOCK = { 13, 13 },
        ROGUE = { 26, 26 }, DRUID = { 26, 26 },
        HUNTER = { 26, 45 }, SHAMAN = { 26, 45 },
        WARRIOR = { 45, 75 }, PALADIN = { 45, 75 },
    },
}

-- A level-60 PvP profile: a copy of the PvE profile it plays like (the PvP
-- model goes on top at runtime), with optional overrides.
function MSC.ForeverPvPFrom(base, overrides)
    local w = {}
    for k, v in pairs(base or {}) do w[k] = v end
    for k, v in pairs(overrides or {}) do w[k] = v end
    return w
end

-- Profiles that are PvP by design get the PvP model even with the option off.
-- A class can list extra keys in its PvPProfiles set (e.g. Shockadin).
function MSC.IsPvPProfile(specKey)
    if type(specKey) ~= "string" then return false end
    if string_find(string_upper(specKey), "PVP", 1, true) then return true end
    local cls = MSC.CurrentClass
    return (cls and cls.PvPProfiles and cls.PvPProfiles[specKey]) and true or false
end

-- Per spec (MSC.GetSpecSetting): group defaults to the spec being scored.
function MSC.IsGearingForPvP(group)
    do return false end -- vendor patch: PvP only via the build (MSC.IsPvPTalentBuild)
    return MSC.IsForever and RXP_SGJ_Settings and MSC.GetSpecSetting("GearForPvP", group) == true or false
end

-- Turns the option on or off from anywhere (options page, main window,
-- PvP realm prompt, /sgj pvp) and tells every toggle to redraw.
MSC.PvPToggleListeners = MSC.PvPToggleListeners or {}
-- Sets it for the active spec only.
function MSC.SetGearForPvP(on)
    if not RXP_SGJ_Settings then return end
    MSC.SetSpecSetting("GearForPvP", on and true or false)
    if MSC.OnScoringSettingsChanged then MSC.OnScoringSettingsChanged()
    elseif MSC.BumpScoringRevision then MSC:BumpScoringRevision() end
    MSC.NotifyPvPToggle()
end

-- Redraws every Gear for PvP toggle (also after a spec switch).
function MSC.NotifyPvPToggle()
    local on = MSC.IsGearingForPvP(MSC.GetActiveSpecGroup())
    for _, fn in ipairs(MSC.PvPToggleListeners) do pcall(fn, on) end
end

-- PvP weights for the active profile: the option, a PvP talent build, or a
-- PvP profile in use (or being built by the weight pipeline).
function MSC.IsPvPWeightsActive()
    if not MSC.IsForever then return false end
    if MSC.IsGearingForPvP() or MSC.PvPPipelineSpec or MSC.IsPvPTalentBuild() then return true end
    -- The other spec (MSC.WithSpecGroup) is judged by its own profile.
    return MSC.IsPvPProfile(MSC.EvalSpecGroup and MSC.EvalSpecKey or MSC.CachedSpecKey)
end

-- A PvP build picked in the Talents plugin (MSC.SetTalentBuildRole).
function MSC.IsPvPTalentBuild()
    return (MSC.TalentBuildRole and MSC.TalentBuildRole.pvp) and true or false
end

local function PvPLevelValue(tbl, level)
    local P = MSC.ForeverPvP
    local lv = P.LEVELS
    if level <= lv[1] then return tbl[1] * level / lv[1] end
    for i = 1, #lv - 1 do
        if level <= lv[i + 1] then
            local t = (level - lv[i]) / (lv[i + 1] - lv[i])
            return tbl[i] + (tbl[i + 1] - tbl[i]) * t
        end
    end
    return tbl[#lv]
end
MSC.PvPLevelValue = PvPLevelValue

local PVP_PHYS_KEYS = { "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "ITEM_MOD_FERAL_ATTACK_POWER_SHORT" }
local PVP_SPELL_KEYS = {
    "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_FIRE_DAMAGE_SHORT", "ITEM_MOD_FROST_DAMAGE_SHORT",
    "ITEM_MOD_ARCANE_DAMAGE_SHORT", "ITEM_MOD_NATURE_DAMAGE_SHORT", "ITEM_MOD_SHADOW_DAMAGE_SHORT", "ITEM_MOD_HOLY_DAMAGE_SHORT",
}
local function MaxWeight(weights, keys)
    local m = 0
    for _, k in ipairs(keys) do
        local w = weights[k]
        if type(w) == "number" and w > m then m = w end
    end
    return m
end

-- Applies the PvP model to a finished weights table in place. level and
-- class default to the player's. Returns a short label for the caps line.
function MSC.ApplyForeverPvP(weights, level, class)
    if not weights then return end
    local P = MSC.ForeverPvP
    level = math_max(1, math_min(60, level or UnitLevel("player") or 1))
    if not class then class = select(2, UnitClass("player")) end

    -- The row's value of +1% output, per damage family; the largest decides.
    local apW = MaxWeight(weights, PVP_PHYS_KEYS)
    local physical = apW * PvPLevelValue(P.AP_EQ, level) / 100
    local spell = MaxWeight(weights, PVP_SPELL_KEYS) * PvPLevelValue(P.SP_EQ, level) / 100
    local healing = (weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or 0) * PvPLevelValue(P.HEAL_EQ, level) / 100
    local family, perPct = "damage", (apW >= 0.5) and physical or spell
    if healing > math_max(physical, spell) then family, perPct = "healing", healing end
    if perPct <= 0 then return end

    local hp = PvPLevelValue(P.HP, level)
    local staminaPerPct = hp / 1000 -- 10 health per Stamina
    local stam = P.SURVIVAL * perPct / staminaPerPct
    local function raise(key, v)
        if v > (weights[key] or 0) then weights[key] = v end
    end
    raise("ITEM_MOD_STAMINA_SHORT", stam)
    raise("ITEM_MOD_HEALTH_SHORT", stam / 10)

    -- One point of each, as a fraction of health, converted to Stamina.
    local stamFrac = 10 / hp
    local apl = P.ARMOR_PER_LEVEL[class] or { 26, 26 }
    local armor = (level >= 40 and apl[2] or apl[1]) * level
    local armorFrac = P.PHYSICAL_SHARE / (400 + 85 * level + armor)
    raise("ITEM_MOD_ARMOR_SHORT", stam * armorFrac / stamFrac)
    raise("ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", stam * P.DEFENSE_EHP / stamFrac)
    raise("ITEM_MOD_DODGE_RATING_SHORT", stam * (P.MELEE_SHARE / 100) / stamFrac)

    for _, k in ipairs({ "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_SPELL_CRIT_RATING_SHORT" }) do
        if weights[k] then weights[k] = weights[k] * P.CRIT_MULT end
    end
    if family == "damage" then
        for _, k in ipairs({ "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT" }) do
            if weights[k] then weights[k] = weights[k] * P.REGEN_MULT end
        end
    end
    return MSC.L["PvP"]
end

-- =============================================================
-- 5.11 SPEC GROUPS (Dual Specialization)
-- =============================================================
-- WoW Forever unlocks Dual Specialization at 40. Each spec group keeps its
-- own manual profile choice and Gear for PvP setting (per character); until a
-- group has its own value it uses the account-wide one, so nothing changes
-- for a character with one spec. MSC.EvalSpecGroup is set while the other
-- group's weights are being built (MSC.WithSpecGroup), so everything that
-- asks "which spec" during that build gets the other one.
function MSC.GetNumSpecGroups()
    local f = GetNumSpecGroups or GetNumTalentGroups
    if not f then return 1 end
    local ok, n = pcall(f)
    n = ok and tonumber(n) or 1
    return (n and n > 1) and n or 1
end

function MSC.HasDualSpec() return MSC.GetNumSpecGroups() > 1 end

function MSC.GetActiveSpecGroup()
    local s = C_SpecializationInfo
    local f = (s and s.GetActiveSpecGroup) or GetActiveSpecGroup or GetActiveTalentGroup
    if not f then return 1 end
    local ok, g = pcall(f)
    g = ok and tonumber(g)
    return (g and g >= 1) and g or 1
end

-- The spec being scored: the active one, or the other while its weights are built.
function MSC.GetScoringSpecGroup() return MSC.EvalSpecGroup or MSC.GetActiveSpecGroup() end

-- Cache-key tag for results scored for the inactive spec ("" otherwise), so
-- the two specs never share cached scores (same profile name, other weights).
function MSC.SpecGroupTag()
    return MSC.EvalSpecGroup and ("|g" .. MSC.EvalSpecGroup) or ""
end

local function SpecSettingsFor(create)
    if not RXP_SGJ_Settings or not MSC.GetPlayerKey then return nil end
    local pk = MSC:GetPlayerKey()
    if create then
        RXP_SGJ_Settings.SpecSettings = RXP_SGJ_Settings.SpecSettings or {}
        RXP_SGJ_Settings.SpecSettings[pk] = RXP_SGJ_Settings.SpecSettings[pk] or {}
    end
    return RXP_SGJ_Settings.SpecSettings and RXP_SGJ_Settings.SpecSettings[pk]
end

-- A per-spec setting (Mode, GearForPvP): this character's value for the group,
-- else the account-wide one.
function MSC.GetSpecSetting(key, group)
    if not RXP_SGJ_Settings then return nil end
    group = group or MSC.GetScoringSpecGroup()
    local mine = SpecSettingsFor(false)
    local g = mine and mine[group]
    if g and g[key] ~= nil then return g[key] end
    return RXP_SGJ_Settings[key]
end

function MSC.SetSpecSetting(key, value, group)
    local mine = SpecSettingsFor(true)
    if not mine then return end
    group = group or MSC.GetActiveSpecGroup()
    mine[group] = mine[group] or {}
    mine[group][key] = value
end

-- The manual profile choice for a spec ("AUTO" = auto-detect). The old
-- account-wide choice is only used if it is a profile of this character's
-- class (it used to follow you onto every character).
function MSC.GetManualSpec(group)
    do return "AUTO" end -- vendor patch: the build chosen in RestedXP decides (MSC.TalentBuildRole)
    local mine = SpecSettingsFor(false)
    local g = mine and mine[group or MSC.GetScoringSpecGroup()]
    if g and g.Mode ~= nil then return g.Mode end
    local mode = RXP_SGJ_Settings and RXP_SGJ_Settings.Mode
    if not mode or mode == "AUTO" then return "AUTO" end
    local cls = MSC.CurrentClass
    if not cls then return mode end -- class not known yet (early load): re-checked at login
    local custom = RXP_SGJ_DB and RXP_SGJ_DB.customWeights
    if (custom and custom[mode]) or (cls and ((cls.Weights and cls.Weights[mode]) or (cls.LevelingWeights and cls.LevelingWeights[mode]))) then
        return mode
    end
    return "AUTO"
end

function MSC.SetManualSpec(mode)
    MSC.SetSpecSetting("Mode", mode or "AUTO")
    MSC.ManualSpec = mode or "AUTO"
end

-- Display name of a spec group ("Primary" / "Secondary", the game's own words).
function MSC.SpecGroupName(group)
    if group == 2 then return _G.DUAL_SPEC_SECONDARY or MSC.L["Secondary"] end
    return _G.DUAL_SPEC_PRIMARY or MSC.L["Primary"]
end

-- =============================================================
-- 5.12 OFF-SPECS (tracked profiles)
-- =============================================================
-- Profiles a character also plays (a healing or tank set for dungeons...),
-- ticked in Settings > Off-Specs and shown as extra tooltip lines. Saved per
-- character: profile keys repeat across classes (RESTO_RAID, Leveling_21_40),
-- so account-wide ticks leaked onto other classes. The old account-wide ticks
-- seed a character's own list the first time, keeping only its class's profiles.
MSC.OffSpecListeners = MSC.OffSpecListeners or {}

local function IsClassProfile(key)
    local cls = MSC.CurrentClass
    local custom = RXP_SGJ_DB and RXP_SGJ_DB.customWeights
    return ((custom and custom[key]) or (cls.Weights and cls.Weights[key]) or (cls.LevelingWeights and cls.LevelingWeights[key])
        or (cls.Profiles and cls.Profiles[key]) or (cls.LevelingBrackets and cls.LevelingBrackets[key])) and true or false
end

-- This character's ticked profiles ({ [key] = true }).
function MSC.GetTrackedSpecs()
    if not RXP_SGJ_Settings or not MSC.GetPlayerKey then return {} end
    local pk = MSC:GetPlayerKey()
    local all = RXP_SGJ_Settings.CharTrackedSpecs
    if all and all[pk] then return all[pk] end
    if not MSC.CurrentClass then return {} end -- class not known yet: seed later
    local mine = {}
    for k, on in pairs(RXP_SGJ_Settings.TrackedSpecs or {}) do
        if on and IsClassProfile(k) then mine[k] = true end
    end
    RXP_SGJ_Settings.CharTrackedSpecs = all or {}
    RXP_SGJ_Settings.CharTrackedSpecs[pk] = mine
    return mine
end

function MSC.SetTrackedSpec(key, on)
    if not RXP_SGJ_Settings or not MSC.GetPlayerKey then return end
    local mine = MSC.GetTrackedSpecs()
    RXP_SGJ_Settings.CharTrackedSpecs = RXP_SGJ_Settings.CharTrackedSpecs or {}
    RXP_SGJ_Settings.CharTrackedSpecs[MSC:GetPlayerKey()] = mine
    mine[key] = on and true or nil
    for _, fn in ipairs(MSC.OffSpecListeners) do pcall(fn) end
end

-- "Leveling_Healer_21_40" -> "Leveling_Healer", 21, 40 (nil for other profiles).
local function LevelingBand(key)
    local role, lo, hi = string.match(key or "", "^(Leveling.-)_(%d+)_(%d+)$")
    return role, tonumber(lo), tonumber(hi)
end

-- A ticked leveling profile follows the character's level: Leveling_Healer_21_40
-- ticked at 30 reads Leveling_Healer_41_51 from 41 (or the class's LevelingNext
-- row where the chain changes name). A band above your level stays as ticked.
function MSC.ResolveTrackedProfile(key, level)
    local cls = MSC.CurrentClass
    local role, lo, hi = LevelingBand(key)
    if not (role and cls) then return key end
    level = level or UnitLevel("player") or 0
    local rows = {}
    for _, t in ipairs({ cls.LevelingWeights or {}, cls.LevelingBrackets or {} }) do
        for k in pairs(t) do rows[k] = true end
    end
    local cur = key
    for _ = 1, 10 do
        if level <= hi then break end
        local nextKey = cls.LevelingNext and cls.LevelingNext[cur]
        if not (nextKey and rows[nextKey]) then
            nextKey = nil
            local nextLo
            for k in pairs(rows) do
                local r, l = LevelingBand(k)
                if r == role and l > lo and (not nextLo or l < nextLo) then nextKey, nextLo = k, l end
            end
        end
        if not nextKey then break end
        local r, l, h = LevelingBand(nextKey)
        if level < l then break end
        cur, role, lo, hi = nextKey, r, l, h
    end
    return cur
end

-- Talents saved for a profile (MSC.SaveSpecTalents, whenever you play in it):
-- the band you're at, else the one ticked, else that role's highest saved band.
-- nil = never played in it (scored with your current talents).
function MSC.GetSavedTalents(pick, resolved)
    local all = RXP_SGJ_Settings and RXP_SGJ_Settings.TalentProfiles
    local mine = all and MSC.GetPlayerKey and all[MSC:GetPlayerKey()]
    if not mine then return nil end
    if mine[resolved] then return mine[resolved] end
    if mine[pick] then return mine[pick] end
    local role = LevelingBand(resolved)
    if not role then return nil end
    local best, bestLo
    for k, t in pairs(mine) do
        local r, lo = LevelingBand(k)
        if r == role and (not bestLo or lo > bestLo) then best, bestLo = t, lo end
    end
    return best
end

-- =============================================================
-- 6. SCANNING
-- =============================================================
-- Plain stats whose GetItemStats value is in the same units the tooltip scan uses (no ratings or percents: Forever's
-- rating lines are read as percents and converted elsewhere). See step 2b below.
MSC.FOREVER_API_STATS = {
    "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT",
    "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    "ITEM_MOD_MANA_REGENERATION_SHORT",
}

function MSC.GetRawItemStats(itemLink)
    if not itemLink then return {} end
    if MSC.StatCache[itemLink] then return MSC.StatCache[itemLink] end

    -- 1. EXECUTE SCANNER
    local scanData = nil
    if MSC.Scanner and MSC.Scanner.Scan then
        local status, result = pcall(MSC.Scanner.Scan, itemLink)
        if status and result then scanData = result end
    end
    -- A failed or partial scan (error, empty tooltip, secret text) isn't cached.
    local scanIncomplete = not scanData or (scanData.Meta and scanData.Meta.Incomplete)
    if not scanData then scanData = { Stats = {}, UseEffects = {}, Procs = {}, Meta = {} } end
    
    -- 2. FLATTEN STATS
    local finalStats = scanData.Stats or {}
    local bonusStats = {}

    -- 2b. WoW Forever: the item's own stat data as a floor (2026-11-09, player report: Heavy Woolen Gloves' "+2 spell power"
    -- scored nothing). Forever shows some plain item stats (spell power, stat 45) as an Equip: line whose text loads with
    -- its spell, after the item: a tooltip read taken before that misses the line, and a hover reread that misses it too
    -- keeps the miss. GetItemStats reads the item record itself (what the game's own "If you replace this item" lines
    -- use), so for these plain stats the higher of the two reads counts. A max, never a sum: nothing is counted twice.
    if MSC.IsForever then
        local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
        local ok, api = pcall(getStats, itemLink)
        if ok and type(api) == "table" then
            for _, key in ipairs(MSC.FOREVER_API_STATS) do
                local v = api[key]
                if type(v) == "number" and not MSC_IsSecret(v) and v > (finalStats[key] or 0) then finalStats[key] = v end
            end
        end
    end

    -- 3. INTEGRATE USE EFFECTS (skip when ProcDB/trinket entry owns the item)
    local itemID = tonumber(string_match(itemLink, "item:(%d+)"))
    local hasProcEntry = itemID and (
        (MSC.ProcDB and MSC.ProcDB[itemID]) or
        (MSC.WeaponDB and MSC.WeaponDB[itemID]) or
        (MSC.TrinketDB and MSC.TrinketDB[itemID])
    )
    if not hasProcEntry and scanData.UseEffects then
        for _, effect in ipairs(scanData.UseEffects) do
            if effect.statKey and effect.averageVal and effect.averageVal > 0 then
                 local sk = MSC.NormalizeStatKey and MSC.NormalizeStatKey(effect.statKey) or effect.statKey
                 finalStats[sk] = (finalStats[sk] or 0) + effect.averageVal
                 if not finalStats._AUTO_PROC then finalStats._AUTO_PROC = { stat=sk, val=effect.averageVal } end
            end
        end
    end

    -- 4. OVERRIDES
    if itemID then
        if MSC.CurrentClass then
            -- Classes with GetRelicBonus score relics per spec in SafeGetItemStats
            -- (their entries can be role functions), so only ItemOverrides here.
            local cc = MSC.CurrentClass
            -- (Explicit if/else: "a and b or c" fell through to cc.Relics when
            -- ItemOverrides was nil, adding relic stats here AND in SafeGetItemStats.)
            local classDB
            if cc.GetRelicBonus then
                classDB = cc.ItemOverrides
            else
                classDB = cc.Relics or cc.Totems or cc.Idols or cc.ItemOverrides
            end
            if classDB and type(classDB[itemID]) == "table" then
                for statKey, val in pairs(classDB[itemID]) do
                    if type(val) == "number" and statKey ~= "note" then
                        finalStats[statKey] = (finalStats[statKey] or 0) + val
                    end
                end
            end
        end
        local entry = nil
        if MSC.ProcDB and MSC.ProcDB[itemID] then entry = MSC.ProcDB[itemID]
        elseif MSC.WeaponDB and MSC.WeaponDB[itemID] then entry = MSC.WeaponDB[itemID]
        elseif MSC.TrinketDB and MSC.TrinketDB[itemID] then entry = MSC.TrinketDB[itemID]
        end

        if entry then
            -- [[ PROC MATH CALCULATION ]]
            local entryStat, entryVal = entry.stat, entry.val
            -- ItemOverrides entries (Database.lua AddOverrides, also filed in
            -- TrinketDB) carry their averaged value as _AUTO_PROC = { stat, val }
            -- with no stat/val of their own, so it never reached the score.
            -- Fold it in here, once (the Evaluator no longer adds _AUTO_PROC).
            if (not entryStat or not entryVal) and type(entry._AUTO_PROC) == "table" then
                entryStat, entryVal = entry._AUTO_PROC.stat, entry._AUTO_PROC.val
            end
            local calcVal = entryVal
            if entry.ppm and entry.val then
                if entry.dur then
                    calcVal = (entry.val * entry.ppm * entry.dur) / 60
                else
                    if entry.stat and (string.find(entry.stat, "REGENERATION") or string.find(entry.stat, "MANA") or string.find(entry.stat, "HEALTH")) then
                         calcVal = (entry.val * entry.ppm * 5) / 60
                    else
                         calcVal = (entry.val * entry.ppm) / 60
                    end
                end
            end

            if calcVal and entryStat then
                local sk = MSC.NormalizeStatKey(entryStat)
                finalStats[sk] = (finalStats[sk] or 0) + calcVal
                if not finalStats._AUTO_PROC then finalStats._AUTO_PROC = { stat=sk, val=calcVal } end
            end
            if entry.score then finalStats._MANUAL_SCORE = entry.score end
        end
    end

    -- 4b. DAMAGE PROCS WITH NO CURATED ENTRY: an estimate. Average damage per
    -- trigger x triggers per minute (Parse.lua ProcRate) = extra DPS, worth
    -- AP_PER_DPS Attack Power each (Ranged Attack Power on a ranged weapon).
    -- Casters' Attack Power weight is 0, so melee procs stay worthless to them.
    local unmodeled = scanData.Procs
    if not hasProcEntry and scanData.Procs and #scanData.Procs > 0 and MSC.Scanner then
        local apKey = "ITEM_MOD_ATTACK_POWER_SHORT"
        local getInstant = GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
        local equipLoc = getInstant and select(4, getInstant(itemLink))
        if equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN" then
            apKey = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT"
        end
        unmodeled = {}
        for _, p in ipairs(scanData.Procs) do
            if p.type == "Damage" and p.perMin and (p.val or 0) > 0 then
                local ap = p.val * p.perMin / 60 * (MSC.Scanner.AP_PER_DPS or 14)
                -- Thorns ("When struck") assume a tank's hits taken: kept apart so
                -- GetItemScore counts it only for profiles that get hit (MSC.ThornsCount).
                local key = p.struck and "MSC_THORNS_AP" or apKey
                finalStats[key] = (finalStats[key] or 0) + ap
                -- A table, so stat loops (type == "number") skip it.
                finalStats._PROC_ESTIMATE = finalStats._PROC_ESTIMATE or { ap = 0, thorns = 0 }
                local part = p.struck and "thorns" or "ap"
                finalStats._PROC_ESTIMATE[part] = finalStats._PROC_ESTIMATE[part] + ap
            else
                unmodeled[#unmodeled + 1] = p
            end
        end
    end

    -- 5. SOCKET BONUSES
    if scanData.Meta and scanData.Meta.BonusStats then bonusStats = scanData.Meta.BonusStats end
    local normalized = {}
    for k, v in pairs(finalStats) do
        if type(v) == "number" and k ~= "_BONUS_STATS" then
            local nk = MSC.NormalizeStatKey(k)
            normalized[nk] = (normalized[nk] or 0) + v
        else
            normalized[k] = v
        end
    end
    finalStats = normalized
    finalStats._BONUS_STATS = bonusStats
    -- Raw "chance on hit" / temporary Equip: proc text the scanner found but
    -- couldn't score (no ProcDB/WeaponDB/TrinketDB/PvPDB entry exists yet).
    -- Rides along through SafeGetItemStats/EvaluateUpgrade so the tooltip can
    -- warn that the item's score is stats-only when this is non-empty and no
    -- curated entry was found.
    if unmodeled and #unmodeled > 0 then finalStats._RAW_PROCS = unmodeled end

    -- Don't cache a scan of an item whose data hasn't loaded (it would be
    -- incomplete); the next call after GET_ITEM_INFO_RECEIVED rescans it.
    if GetItemInfo(itemLink) and not scanIncomplete then
        MSC.StatCache[itemLink] = finalStats
        statCacheTime[itemLink] = GetTime()
        firstReadTime[itemLink] = firstReadTime[itemLink] or GetTime()
    end
    return finalStats
end

-- =============================================================
-- 7. ENCHANT & GEM ENGINE
-- =============================================================
function MSC:GetValidEnchantType(itemLink)
    if not itemLink then return nil end
    local _, _, _, _, _, _, _, _, equipLoc, _, _, classID, subClassID = GetItemInfo(itemLink)
    if not equipLoc then return nil end
    
    if classID == 2 then 
        if equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_STAFF" or equipLoc == "INVTYPE_POLEARM" then return "2H"
        elseif equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN" then
            if subClassID == 2 or subClassID == 3 or subClassID == 18 then return "Bow" end
            return "Relic"
        elseif equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" or equipLoc == "INVTYPE_WEAPONOFFHAND" then return "Weapon" end
    end
    if classID == 4 then
        if subClassID == 6 then return "Shield" end
        if subClassID == 0 then return "Relic" end
        return "Armor"
    end
    return "Armor"
end

-- An enchant's name in the player's language: the game's own name for its
-- Enchanting recipe (spell) or enchant item (item), falling back to the English
-- name in Enchants_<Edition>.lua. showStats adds "+8 Str"-style stats for items
-- that share a name (the Voracity arcanums).
function MSC.GetEnchantName(data)
    if not data then return "" end
    local name
    if data.spell then
        if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(data.spell)
        elseif GetSpellInfo then name = GetSpellInfo(data.spell) end
    elseif data.item then
        name = GetItemInfo(data.item)
    end
    if not name then return data.name or "" end
    if data.showStats and data.stats then
        local parts = {}
        for stat, val in pairs(data.stats) do
            parts[#parts + 1] = "+" .. val .. " " .. (MSC.GetCleanStatName(stat) or stat)
        end
        table.sort(parts)
        name = name .. " (" .. table.concat(parts, ", ") .. ")"
    end
    return name
end

function MSC.GetEnchantScore(enchantID, weights, slotId)
    if not enchantID or not MSC.EnchantDB[enchantID] then return 0 end
    local stats = MSC.EnchantDB[enchantID].stats
    if not stats then return 0 end
    -- Same scoring as item stats (Forever ratings converted to %, Spell Power's
    -- healing half counted for healers). The slot matters for weapon damage:
    -- in the weapon slots it uses the melee weapon's weight (0 for casters,
    -- whose Weapon DPS weight is their wand's), not the ranged one.
    return MSC.GetItemScore(stats, weights, nil, slotId)
end

function MSC.GetBestEnchantForSlot(slotId, level, specName, enchantType, weights)
    local candidates = MSC.EnchantCandidates and MSC.EnchantCandidates[slotId]
    if not candidates then return nil end

    local _, _, classID = UnitClass("player")
    local classBit = classID and 2 ^ (classID - 1)

    local bestID, bestScore = nil, -1
    for _, id in ipairs(candidates) do
        local data = MSC.EnchantDB[id]
        -- lvl: the level an enchant becomes a sensible suggestion; classMask: class-only
        -- enchant items such as the Zul'Gurub idols (Enchants_<Edition>.lua).
        if data and (not data.lvl or not level or data.lvl <= level)
            and (not data.classMask or not classBit or bit.band(data.classMask, classBit) ~= 0) then
            local allowed = true
            if data.requires2H and enchantType ~= "2H" then allowed = false end
            if slotId == 17 then
                if enchantType == "Shield" and not data.isShield then allowed = false end
                if enchantType ~= "Shield" and data.isShield then allowed = false end
                if enchantType ~= "Weapon" and not data.isShield and not data.isScope then allowed = false end
            end
            if slotId == 18 and ((enchantType == "Bow" and not data.isScope) or (enchantType == "Relic")) then allowed = false end
            if allowed then
                local score = MSC.GetEnchantScore(id, weights, slotId)
                if score > bestScore then bestScore = score; bestID = id end
            end
        end
    end
    return (bestScore > 0) and bestID or nil
end

local function InferCurrentEnchantFromDelta(slotId, rawStats, baseRaw)
    if not slotId or not rawStats or not baseRaw or not MSC.EnchantDB then return nil end

    local candidates = MSC.EnchantCandidates and MSC.EnchantCandidates[slotId]
    if not candidates then return nil end

    local bestMatch, bestTotal = nil, 0

    for _, enchantID in ipairs(candidates) do
        local data = MSC.EnchantDB[enchantID]
        if data and data.stats then
            local matched = true
            local total = 0

            for statKey, statVal in pairs(data.stats) do
                if type(statVal) == "number" then
                    local rawDelta = math_max(0, (rawStats[statKey] or 0) - (baseRaw[statKey] or 0))
                    if math_abs(rawDelta - statVal) > 0.01 then
                        matched = false
                        break
                    end
                    total = total + statVal
                end
            end

            if matched then
                for statKey, rawVal in pairs(rawStats) do
                    if type(rawVal) == "number" then
                        local rawDelta = math_max(0, rawVal - (baseRaw[statKey] or 0))
                        local enchantVal = data.stats[statKey] or 0
                        if math_abs(rawDelta - enchantVal) > 0.01 then
                            matched = false
                            break
                        end
                    end
                end
            end

            if matched and total > bestTotal then
                bestMatch, bestTotal = data, total
            end
        end
    end

    return bestMatch
end

function MSC.GetBestGemForSocket(socketColor, level, weights, excludeList, isJC)
    local bestGem, bestScore = nil, 0
    local db = (level >= 60 and MSC.GemOptions) and MSC.GemOptions or MSC.GemOptions_Leveling
    if not db or not weights then return nil, 0 end
    
    -- Fetch the player's selected quality budget (Defaults to 3 / Rare)
    local maxQual = RXP_SGJ_Settings and RXP_SGJ_Settings.GemQuality or 3

    local lists = {}
    if socketColor == "ANY" then
        if db["EMPTY_SOCKET_RED"] then table_insert(lists, db["EMPTY_SOCKET_RED"]) end
        if db["EMPTY_SOCKET_YELLOW"] then table_insert(lists, db["EMPTY_SOCKET_YELLOW"]) end
        if db["EMPTY_SOCKET_BLUE"] then table_insert(lists, db["EMPTY_SOCKET_BLUE"]) end
    elseif socketColor == "EMPTY_SOCKET_META" then
        if db["EMPTY_SOCKET_META"] then table_insert(lists, db["EMPTY_SOCKET_META"]) end
    else
        if socketColor == "EMPTY_SOCKET_PRISMATIC" then
            if db["EMPTY_SOCKET_RED"] then table_insert(lists, db["EMPTY_SOCKET_RED"]) end
            if db["EMPTY_SOCKET_YELLOW"] then table_insert(lists, db["EMPTY_SOCKET_YELLOW"]) end
            if db["EMPTY_SOCKET_BLUE"] then table_insert(lists, db["EMPTY_SOCKET_BLUE"]) end
        else
            if db[socketColor] then table_insert(lists, db[socketColor]) end
        end
    end

    for _, list in ipairs(lists) do
        for _, gem in ipairs(list) do
            local isUniqueBlocked = (gem.unique and excludeList and excludeList[gem.id])
            local isJCBlocked = (gem.isJC and not isJC)
            
            -- Verify if the gem exceeds the player's chosen budget
            local gemQual = gem.quality or 3
            local isQualityBlocked = (gemQual > maxQual)

            if not isUniqueBlocked and not isJCBlocked and not isQualityBlocked then
                local score = 0
                if gem.stat and weights[gem.stat] then score = score + (gem.val * weights[gem.stat]) end
                if gem.stat2 and weights[gem.stat2] then score = score + (gem.val2 * weights[gem.stat2]) end
                if score > bestScore then bestScore = score; bestGem = gem end
            end
        end
    end
    return bestGem, bestScore
end

-- =============================================================
-- 8. GEM CACHE & LOOKUP
-- =============================================================
MSC.GemIDCache = {}

function MSC:BuildGemCache()
    local dbs = { MSC.GemOptions, MSC.GemOptions_Leveling }
    for _, db in ipairs(dbs) do
        if db then
            for _, list in pairs(db) do
                for _, gem in ipairs(list) do MSC.GemIDCache[gem.id] = gem end
            end
        end
    end
end

function MSC.GetGemStatsByID(gemID)
    if not gemID then return nil end
    local id = tonumber(gemID)
    if MSC.GemIDCache[id] then return MSC.GemIDCache[id] end
    MSC:BuildGemCache()
    return MSC.GemIDCache[id]
end

function MSC.GetGemColor(gemID)
    local gem = MSC.GetGemStatsByID(gemID)
    if gem and gem.colorType then return gem.colorType end
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(gemID or 0)
    if icon then
        if string_find(icon, "Red") or string_find(icon, "Garnet") or string_find(icon, "Ruby") then return "RED"
        elseif string_find(icon, "Yellow") or string_find(icon, "Golden") or string_find(icon, "Dawnstone") then return "YELLOW"
        elseif string_find(icon, "Blue") or string_find(icon, "Azure") or string_find(icon, "Star") then return "BLUE"
        elseif string_find(icon, "Orange") or string_find(icon, "Topaz") then return "ORANGE"
        elseif string_find(icon, "Purple") or string_find(icon, "Nightseye") then return "PURPLE"
        elseif string_find(icon, "Green") or string_find(icon, "Talasite") then return "GREEN" end
    end
    return nil
end

function MSC.ApplyGemColorCount(gData, colors)
    if not gData or not gData.colorType or MSC.IsVanillaRules or not colors then return end
    local ct = gData.colorType
    if ct == "RED" then
        colors.RED = colors.RED + 1
    elseif ct == "BLUE" then
        colors.BLUE = colors.BLUE + 1
    elseif ct == "YELLOW" then
        colors.YELLOW = colors.YELLOW + 1
    elseif ct == "PURPLE" then
        colors.RED = colors.RED + 1
        colors.BLUE = colors.BLUE + 1
    elseif ct == "ORANGE" then
        colors.RED = colors.RED + 1
        colors.YELLOW = colors.YELLOW + 1
    elseif ct == "GREEN" then
        colors.BLUE = colors.BLUE + 1
        colors.YELLOW = colors.YELLOW + 1
    elseif ct == "PRISMATIC" then
        colors.RED = colors.RED + 1
        colors.BLUE = colors.BLUE + 1
        colors.YELLOW = colors.YELLOW + 1
    end
end

MSC.ColorMatchCache = MSC.ColorMatchCache or {}
MSC.ProcessedStatCache = MSC.ProcessedStatCache or {}

function MSC.SolveColorMatch(gemIDs, baseLink)
    local gemKey = table_concat(gemIDs, ",") .. "|" .. (baseLink or "")
    if MSC.ColorMatchCache[gemKey] ~= nil then
        return MSC.ColorMatchCache[gemKey]
    end

    local template = GetItemStats(baseLink) or {}
    local sockets = {}
    for i=1, (template["EMPTY_SOCKET_RED"] or 0) do table_insert(sockets, "RED") end
    for i=1, (template["EMPTY_SOCKET_YELLOW"] or 0) do table_insert(sockets, "YELLOW") end
    for i=1, (template["EMPTY_SOCKET_BLUE"] or 0) do table_insert(sockets, "BLUE") end
    if #sockets == 0 then return true end

    local function MatchRecursive(gemIdx, availableSockets)
        if gemIdx > #gemIDs then return #availableSockets == 0 end 
        if #availableSockets == 0 then return true end
        
        local gID = gemIDs[gemIdx]
        local gColor = MSC.GetGemColor(gID)
        
        if gColor then
            for i, sColor in ipairs(availableSockets) do
                local match = false
                if gColor == "PRISMATIC" then match = true
                elseif gColor == sColor then match = true
                elseif gColor == "ORANGE" and (sColor == "RED" or sColor == "YELLOW") then match = true
                elseif gColor == "PURPLE" and (sColor == "RED" or sColor == "BLUE") then match = true
                elseif gColor == "GREEN" and (sColor == "BLUE" or sColor == "YELLOW") then match = true
                end

                if match then
                    local nextSockets = { unpack(availableSockets) }
                    table_remove(nextSockets, i)
                    if MatchRecursive(gemIdx + 1, nextSockets) then return true end
                end
            end
        end
        return MatchRecursive(gemIdx + 1, availableSockets)
    end
    local matched = MatchRecursive(1, sockets)
    MSC.ColorMatchCache[gemKey] = matched
    return matched
end

function MSC.SafeGetItemStats(itemLink, slotId, weights, specName, globalUniques)
    if not itemLink then return {} end

    local enchantMode = RXP_SGJ_Settings and RXP_SGJ_Settings.EnchantMode or 1
    local gemMode = RXP_SGJ_Settings and RXP_SGJ_Settings.GemMode or 1
    local gemQuality = RXP_SGJ_Settings and RXP_SGJ_Settings.GemQuality or 3
    local uniqueKey = ""
    if globalUniques and next(globalUniques) ~= nil then
        local parts = {}
        for id, _ in pairs(globalUniques) do table_insert(parts, tostring(id)) end
        table_sort(parts)
        uniqueKey = table.concat(parts, ",")
    end
    local procKey = itemLink .. "|" .. tostring(slotId or 0) .. "|" .. tostring(specName or "") .. "|" .. enchantMode .. "|" .. gemMode .. "|" .. gemQuality .. "|" .. (MSC.ScoringRevision or 0) .. "|" .. uniqueKey .. MSC.SpecGroupTag()
    if globalUniques and next(globalUniques) then
        -- skip cache when tracking unique-equipped gems across character score
    elseif weights and MSC.ProcessedStatCache and MSC.ProcessedStatCache[procKey] then
        return MSC:SafeCopy(MSC.ProcessedStatCache[procKey], {})
    end
    
    local gemNameMissing = false
    local rawStats = MSC.GetRawItemStats(itemLink)
    local finalStats = {}
    for k,v in pairs(rawStats) do if k ~= "_BONUS_STATS" then finalStats[k] = v end end
    if MSC.IsForever and finalStats.MSC_WEAPON_DPS and not finalStats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT then finalStats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = finalStats.MSC_WEAPON_DPS end
    local bonusStats = rawStats._BONUS_STATS or {}
    -- Compare against the same item with only its enchant removed. Item
    -- strings on Era 1.15, TBC and Forever all read
    --   item:itemID:enchantID:gem1:gem2:gem3:gem4:suffixID:uniqueID:...
    -- and a random-suffix item's "of the Bear" stats live in suffixID (scaled
    -- by uniqueID), so those fields and the gems must stay. GetBaseLink zeroes
    -- everything: diffing against it read an unenchanted Bracers of Strength's
    -- +5 Str as enchant 856 and removed it. With the enchant field already 0
    -- there is nothing to compare (baseLink == itemLink), so no inference runs.
    local baseLink = itemLink
    local enchantField = tonumber(string_match(itemLink, "item:%-?%d+:(%-?%d*)") or "")
    if enchantField and enchantField ~= 0 then
        baseLink = string_gsub(itemLink, "(item:%-?%d+:)%-?%d*", "%10", 1)
    end
    local baseRaw = nil

    if baseLink and baseLink ~= itemLink then
        baseRaw = MSC.GetRawItemStats(baseLink)
        if not next(bonusStats) and baseRaw._BONUS_STATS and next(baseRaw._BONUS_STATS) then
            bonusStats = baseRaw._BONUS_STATS
        end
    end

    if not weights then return finalStats end
    
    local level = UnitLevel("player")
    
    local derivedSlotId = slotId
    if not derivedSlotId and MSC.SlotMap then
        local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
        if equipLoc then derivedSlotId = MSC.SlotMap[equipLoc] end
    end
    
    local physicalEnchantID = 0
    local currentEnchantData = nil
    local itemString = string_match(itemLink, "item[%-?%d:]+")
    if itemString then
        local _, _, eid = strsplit(":", itemString)
        physicalEnchantID = tonumber(eid) or 0
    end

    if physicalEnchantID > 0 and MSC.EnchantDB and MSC.EnchantDB[physicalEnchantID] then
        currentEnchantData = MSC.EnchantDB[physicalEnchantID]
    elseif baseRaw then
        currentEnchantData = InferCurrentEnchantFromDelta(derivedSlotId, rawStats, baseRaw)
    end

    if currentEnchantData and currentEnchantData.stats then
        for k, v in pairs(currentEnchantData.stats) do
            if type(v) == "number" then
                local removable = v
                if baseRaw then
                    removable = math_min(v, math_max(0, (rawStats[k] or 0) - (baseRaw[k] or 0)))
                elseif (finalStats[k] or 0) < v then
                    removable = 0
                end

                if removable > 0 then
                    finalStats[k] = math_max(0, (finalStats[k] or 0) - removable)
                end
            end
        end
    end

    if derivedSlotId and enchantMode ~= 1 then
        if enchantMode == 2 then
            local equippedLink = GetInventoryItemLink("player", derivedSlotId)
            if equippedLink then
                local eqEnchantID = 0
                local eqStr = string_match(equippedLink, "item[%-?%d:]+")
                if eqStr then
                    local _, _, eid = strsplit(":", eqStr)
                    eqEnchantID = tonumber(eid) or 0
                end
                
                if eqEnchantID > 0 and MSC.EnchantDB and MSC.EnchantDB[eqEnchantID] then
                    local eqData = MSC.EnchantDB[eqEnchantID]
                    if eqData.stats then
                        for k, v in pairs(eqData.stats) do
                            if type(v) == "number" then finalStats[k] = (finalStats[k] or 0) + v end
                        end
                    end
                    finalStats.IS_PROJECTED = true
                    finalStats.ENCHANT_TEXT = MSC.GetEnchantName(eqData) .. " " .. MSC.L["(Equipped)"]
                end
            end
            
        elseif enchantMode == 3 then
            local enchantType = MSC:GetValidEnchantType(itemLink)
            if not enchantType and derivedSlotId then
                  local s = derivedSlotId
                  if s==1 or s==3 or s==5 or s==6 or s==7 or s==8 or s==9 or s==10 then enchantType = "Armor"
                  elseif s==15 then enchantType = "Armor" 
                  elseif s==17 then enchantType = "Shield"
                  end
            end

            if enchantType then
                local bestID = MSC.GetBestEnchantForSlot(derivedSlotId, level, specName, enchantType, weights)
                if bestID and MSC.EnchantDB[bestID] then
                    local bestData = MSC.EnchantDB[bestID]
                    if bestData.stats then
                        for k, v in pairs(bestData.stats) do 
                            if type(v) == "number" then finalStats[k] = (finalStats[k] or 0) + v end
                        end
                    end
                    finalStats.IS_PROJECTED = true
                    finalStats.ENCHANT_TEXT = MSC.GetEnchantName(bestData)
                end
            end
        end
    end

    if not MSC.IsVanillaRules and gemMode ~= 1 then
        wipe(Scratch_GemTextParts); wipe(Scratch_ProjectedIDs); wipe(Scratch_GemCounts); wipe(Scratch_GemOrder)
        wipe(Scratch_GemStats); wipe(Scratch_GemColors); wipe(Scratch_ProjectedColors)
        Scratch_ProjectedColors.RED=0; Scratch_ProjectedColors.YELLOW=0; Scratch_ProjectedColors.BLUE=0
        local projectedMeta = nil
        local isJC = MSC:IsJewelcrafter() -- Grabbing JC Status

        if gemMode == 1 then
            for k, v in pairs(bonusStats) do finalStats[k] = (finalStats[k] or 0) + v end
        else
            local baseLink = MSC.GetBaseLink(itemLink)
            local socketsToFill = {}
            local existingGems = {}
            
            if gemMode == 3 then
                local currentGems = { string_match(itemLink, "item:%d+:%d+:(%d+):(%d+):(%d+):(%d+)") }
                for _, gID in ipairs(currentGems) do
                    local id = tonumber(gID)
                    if id and id > 0 and MSC.GetGemStatsByID then
                        local gData = MSC.GetGemStatsByID(id)
                        if gData then
                            if gData.stat then finalStats[gData.stat] = math_max(0, (finalStats[gData.stat] or 0) - (gData.val or 0)) end
                            if gData.stat2 then finalStats[gData.stat2] = math_max(0, (finalStats[gData.stat2] or 0) - (gData.val2 or 0)) end
                        end
                    end
                end
                socketsToFill = GetItemStats(baseLink) or {} 
                
            elseif gemMode == 2 then
                -- "The Casual": keep the gems already in the item (their stats
                -- are on the scanned tooltip, so they stay in finalStats) and
                -- only project gems for the empty sockets. Subtracting them
                -- here, as before, dropped their stats from the score entirely.
                socketsToFill = GetItemStats(itemLink) or {} 
                local _, _, ids = MSC:GetItemGems(itemLink)
                for _, id in ipairs(ids) do table_insert(existingGems, id) end
            end

            local totalSockets = 0
            for _, colorKey in ipairs({"EMPTY_SOCKET_RED", "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_BLUE", "EMPTY_SOCKET_META", "EMPTY_SOCKET_PRISMATIC"}) do
                totalSockets = totalSockets + (socketsToFill[colorKey] or 0)
            end
            local totalFilled = 0
            for _, gID in ipairs(existingGems) do
                if tonumber(gID) and tonumber(gID) > 0 then totalFilled = totalFilled + 1 end
            end
            local socketsLeftToProject = math_max(0, totalSockets - totalFilled)

            for _, gID in ipairs(existingGems) do
                MSC.ApplyGemColorCount(MSC.GetGemStatsByID(gID), Scratch_ProjectedColors)
            end

            if MSC.GetBaseLink and MSC.GetBestGemForSocket then
                wipe(Scratch_MatchGems); wipe(Scratch_PureGems)
                local matchScore = 0; local pureScore = 0
                local socketKeys = {"EMPTY_SOCKET_RED", "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_BLUE", "EMPTY_SOCKET_META", "EMPTY_SOCKET_PRISMATIC"}

                local uniqueTrackerMatch = globalUniques and MSC:SafeCopy(globalUniques) or {} 
                for _, colorKey in ipairs(socketKeys) do
                    local count = socketsToFill[colorKey] or 0
                    for i=1, count do
                        if gemMode == 2 and socketsLeftToProject <= 0 then break end
                        local bestGem, score = MSC.GetBestGemForSocket(colorKey, level, weights, uniqueTrackerMatch, isJC)
                        if bestGem then 
                            matchScore = matchScore + score
                            table_insert(Scratch_MatchGems, bestGem)
                            if bestGem.unique then uniqueTrackerMatch[bestGem.id] = true end
                            if gemMode == 2 then socketsLeftToProject = socketsLeftToProject - 1 end
                        end
                    end
                end
                local matchCandidateIDs = { unpack(existingGems) }
                for _, g in ipairs(Scratch_MatchGems) do table_insert(matchCandidateIDs, g.id) end
                local matchBonusActive = MSC.SolveColorMatch(matchCandidateIDs, baseLink)
                if matchBonusActive and next(bonusStats) then
                      for k,v in pairs(bonusStats) do if weights[k] then matchScore = matchScore + (v * weights[k]) end end
                end

                if gemMode == 3 then
                    local uniqueTrackerPure = globalUniques and MSC:SafeCopy(globalUniques) or {}
                    for _, colorKey in ipairs(socketKeys) do
                        local count = socketsToFill[colorKey] or 0
                        for i=1, count do
                            local searchKey = (colorKey == "EMPTY_SOCKET_META") and "EMPTY_SOCKET_META" or "ANY"
                            local bestGem, score = MSC.GetBestGemForSocket(searchKey, level, weights, uniqueTrackerPure, isJC)
                            if bestGem then 
                                pureScore = pureScore + score
                                table_insert(Scratch_PureGems, bestGem)
                                if bestGem.unique then uniqueTrackerPure[bestGem.id] = true end
                            end
                        end
                    end
                    local pureCandidateIDs = { unpack(existingGems) }
                    for _, g in ipairs(Scratch_PureGems) do table_insert(pureCandidateIDs, g.id) end
                    local pureBonusActive = MSC.SolveColorMatch(pureCandidateIDs, baseLink)
                    if pureBonusActive and next(bonusStats) then
                         for k,v in pairs(bonusStats) do if weights[k] then pureScore = pureScore + (v * weights[k]) end end
                    end
                end

                local usePure = (gemMode == 3) and (pureScore > matchScore)
                local chosenGems = usePure and Scratch_PureGems or Scratch_MatchGems
                local bonusActive = usePure and (MSC.SolveColorMatch(MSC:SafeCopy(existingGems), baseLink)) or matchBonusActive 
                
                if globalUniques then
                    for _, gem in ipairs(chosenGems) do
                        if gem.unique then globalUniques[gem.id] = true end
                    end
                end 
                if usePure then
                    local allGems = { unpack(existingGems) }
                    for _, g in ipairs(Scratch_PureGems) do table_insert(allGems, g.id) end
                    bonusActive = MSC.SolveColorMatch(allGems, baseLink)
                end
                
                for _, gem in ipairs(chosenGems) do
                    if gem.stat then 
                        finalStats[gem.stat] = (finalStats[gem.stat] or 0) + gem.val 
                        Scratch_GemStats[gem.stat] = (Scratch_GemStats[gem.stat] or 0) + gem.val 
                    end
                    if gem.stat2 then 
                        finalStats[gem.stat2] = (finalStats[gem.stat2] or 0) + gem.val2 
                        Scratch_GemStats[gem.stat2] = (Scratch_GemStats[gem.stat2] or 0) + gem.val2 
                    end
                    if gem.isMeta then projectedMeta = gem.id end
                    MSC.ApplyGemColorCount(gem.colorType and gem or MSC.GetGemStatsByID(gem.id), Scratch_ProjectedColors)
                    table_insert(Scratch_ProjectedIDs, gem.id)
                end
                
                if bonusActive and next(bonusStats) then
                    for k, v in pairs(bonusStats) do 
                        finalStats[k] = (finalStats[k] or 0) + v 
                        Scratch_GemStats[k] = (Scratch_GemStats[k] or 0) + v
                    end
                    finalStats.BONUS_PROJECTED = true
                end
                
                local function AddToDisplay(id)
                    local gName = GetItemInfo(id)
                    local cType = MSC.GetGemColor(id) or "Unknown"
                    if type(cType) == "string" then cType = cType:sub(1,1)..cType:sub(2):lower() end
                    if not gName then
                        gemNameMissing = true
                        local g = MSC.GetGemStatsByID(id)
                        gName = g and (MSC.StatShortNames[g.stat] or MSC.L["Gem"]) or MSC.L["Gem"]
                    end
                    if not Scratch_GemCounts[gName] then
                        Scratch_GemCounts[gName] = 0; Scratch_GemColors[gName] = cType; table_insert(Scratch_GemOrder, gName)
                    end
                    Scratch_GemCounts[gName] = Scratch_GemCounts[gName] + 1
                end
                for _, id in ipairs(existingGems) do AddToDisplay(id) end
                for _, gem in ipairs(chosenGems) do AddToDisplay(gem.id) end
                
                finalStats.PROJECTION_DATA = { Gems = {}, Bonus = nil, Stats = "" }
                for _, gName in ipairs(Scratch_GemOrder) do
                    table_insert(finalStats.PROJECTION_DATA.Gems, { text = Scratch_GemCounts[gName] .. "x " .. gName, color = Scratch_GemColors[gName] })
                end
                if bonusActive and next(bonusStats) then
                    local bParts = {}
                    for k, v in pairs(bonusStats) do table_insert(bParts, "+" .. v .. " " .. ((MSC.StatShortNames and MSC.StatShortNames[k]) or MSC.L["Stat"])) end
                    finalStats.PROJECTION_DATA.Bonus = MSC.L["Socket Bonus: "] .. table_concat(bParts, ", ")
                end
                local statParts = {}
                for k, v in pairs(Scratch_GemStats) do
                    local short = (MSC.StatShortNames and MSC.StatShortNames[k]) or MSC.L["Stat"]
                    table_insert(statParts, "+" .. v .. " " .. short)
                end
                if #statParts > 0 then finalStats.PROJECTION_DATA.Stats = "(" .. table_concat(statParts, ", ") .. ")" end

                finalStats.GEMS_PROJECTED = #finalStats.PROJECTION_DATA.Gems
                finalStats.META_ID = projectedMeta
                finalStats.COLORS = MSC:SafeCopy(Scratch_ProjectedColors)
            end
        end
    end
    -- Relics (Libram 7, Idol 8, Totem 9): their effects are text the parser
    -- can't read, so add the class's equivalent stats for this spec. (Before
    -- this, GetRelicBonus only fed a tooltip note and relics scored ~0.)
    if MSC.CurrentClass and MSC.CurrentClass.GetRelicBonus and GetItemInfoInstant then
        local relicID, _, _, _, _, relicClassID, relicSubClassID = GetItemInfoInstant(itemLink)
        if relicClassID == 4 and (relicSubClassID == 7 or relicSubClassID == 8 or relicSubClassID == 9) then
            local ok, bonus = pcall(MSC.CurrentClass.GetRelicBonus, MSC.CurrentClass, relicID, specName or MSC.CachedSpecKey or "")
            if ok and type(bonus) == "table" then
                for k, v in pairs(bonus) do
                    if type(v) == "number" and v > 0 then finalStats[k] = (finalStats[k] or 0) + v end
                end
            end
        end
    end
    -- Weapon types a class can equip but not attack with (Forever Hunters
    -- and thrown weapons: Auto Shot and shots need a bow, gun or crossbow)
    -- are scored on their stats only, so their DPS can't beat a real bow.
    local statsOnly = MSC.CurrentClass and MSC.CurrentClass.StatsOnlyWeapons
    if statsOnly and GetItemInfoInstant then
        local _, _, _, _, _, itemClassID, itemSubClassID = GetItemInfoInstant(itemLink)
        if itemClassID == 2 and statsOnly[itemSubClassID] then
            finalStats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = nil
            finalStats.MSC_WEAPON_DPS = nil
            finalStats.MSC_WEAPON_SPEED = nil
        end
    end
    -- Skip the cache while item or projected-gem data is still loading
    -- (StatCache[itemLink] is only set for a complete, loaded scan.)
    if weights and MSC.ProcessedStatCache and not (globalUniques and next(globalUniques))
        and not gemNameMissing and GetItemInfo(itemLink) and MSC.StatCache[itemLink] then
        MSC.ProcessedStatCache[procKey] = MSC:SafeCopy(finalStats, {})
    end
    return finalStats
end

-- =============================================================
-- 9. MISC HELPERS
-- =============================================================
function MSC.GetInterpolatedRatio(table, level)
    if not table then return nil end
    if level <= table[1][1] then return table[1][2] end
    local count = #table
    if level >= table[count][1] then return table[count][2] end
    for i = 1, count - 1 do
        local lowNode, highNode = table[i], table[i+1]
        if level >= lowNode[1] and level <= highNode[1] then
            return lowNode[2] + ((level - lowNode[1]) / (highNode[1] - lowNode[1])) * (highNode[2] - lowNode[2])
        end
    end
    return table[count][2]
end

function MSC.ExpandDerivedStats(stats, itemLink, dest)
    if not dest then dest = {} end
    wipe(dest)
    if not stats then return dest end
    for k, v in pairs(stats) do dest[k] = v end
    return dest
end

function MSC.GetBaseLink(itemLink)
    if not itemLink then return nil end
    local id = string_match(itemLink, "item:(%d+)")
    if id then return "item:" .. id .. ":0:0:0:0:0:0:0:0" end
    return itemLink
end

-- =============================================================
-- 10. SCORING ENGINE
-- =============================================================
-- A negative weight on a weapon speed means "prefer fast weapons" (a Rogue's
-- poison off hand, a Shaman's Rockbiter/Frostbrand weapon). It scores
-- |weight| x (FAST_SPEED_REF - speed), floored at 0: faster weapons score higher,
-- by exactly the old weight per second of speed, and no score goes below 0.
local FAST_SPEED_REF = 4.0

function MSC.GetItemScore(stats, weights, specName, slotId)
    if not stats or not weights then return 0 end
    if stats._MANUAL_SCORE and stats._MANUAL_SCORE > 0 then
        return math_max(0, MSC.Round(stats._MANUAL_SCORE, 1))
    end
    local score = 0
    local usefulRaw = 0
    local uselessRaw = 0
    -- Forever items carry raw Combat Ratings (e.g. "+10 Hit Rating"), confirmed
    -- against real datamined items (foreverchanges.pro) and this file's own
    -- CombatRatingScalars table -- 10 rating = 1% Hit at level 60, etc. Every
    -- class's Hit/Crit/Weapon Skill/Defense/Dodge/Parry weight was calibrated
    -- as "points per 1% (or per 1 skill point)", so the raw rating value must
    -- be converted through that same table before being multiplied by weight,
    -- or it overvalues those stats by the rating-per-percent factor (10x-22x
    -- depending on stat/level). GetRatingPercent already does this exact
    -- conversion for the tooltip's cosmetic display text; reusing it here
    -- fixes every class/profile's rating stats in one place.
    local foreverLevel = MSC.IsForever and UnitLevel("player")

    for stat, val in pairs(stats) do
        if stat == "_MANUAL_SCORE" or stat == "_AUTO_PROC" or stat == "IS_PROJECTED" or stat == "GEMS_PROJECTED" or stat == "BONUS_PROJECTED" then
            -- metadata keys
        elseif type(val) == "number" then
            local weightKey = stat
            local isWeaponDps = (stat == "MSC_WEAPON_DPS" or stat == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT")
            -- Warrior / Rogue ranged slot (bow, gun, thrown): their profiles' weapon DPS weight is the melee one, so with no
            -- melee/ranged split (the level-60 profiles) a ranged weapon got the melee value, ~33x too much (2026-10-22).
            -- Use MSC_RANGED_WEAPON_DPS when a profile sets it, else the leveling rows' ranged value (0.5).
            if isWeaponDps and slotId == 18 and not weights["MSC_WEAPON_DPS_MELEE"] and MSC.CurrentClass
                and (MSC.CurrentClass.Name == "WARRIOR" or MSC.CurrentClass.Name == "ROGUE") then
                weightKey = "MSC_RANGED_WEAPON_DPS"
            end
            if isWeaponDps and (slotId == 16 or slotId == 17) then
                -- MSC_WEAPON_DPS_MELEE: a class module can set this in ApplyScalers
                -- when its Weapon DPS weight is anchored to the ranged slot (e.g. a
                -- ranged Hunter, whose melee weapon is mostly a stat stick).
                if slotId == 17 and weights["MSC_WEAPON_DPS_OH"] then weightKey = "MSC_WEAPON_DPS_OH"
                elseif weights["MSC_WEAPON_DPS_MELEE"] then weightKey = "MSC_WEAPON_DPS_MELEE" end
            end
            if slotId == 17 and stat == "MSC_WEAPON_SPEED" then
                if weights["MSC_OH_WEAPON_SPEED"] then weightKey = "MSC_OH_WEAPON_SPEED" end
            end
            -- Forever's speed weights model melee swings; a bow/gun/wand's
            -- speed in the ranged slot shouldn't inherit them. (TBC Hunter
            -- profiles weight ranged speed on purpose, so Forever only.)
            if MSC.IsForever and slotId == 18 and stat == "MSC_WEAPON_SPEED" then weightKey = "MSC_RANGED_WEAPON_SPEED" end
            
            local w = weights[weightKey] or 0
            if weightKey == "MSC_RANGED_WEAPON_DPS" and not weights[weightKey] then w = 0.5 end   -- melee class ranged slot (above)
            if stat == "MSC_THORNS_AP" then w = MSC.ThornsCount(specName) and (weights["ITEM_MOD_ATTACK_POWER_SHORT"] or 0) or 0 end

            -- [[ WoW Forever Stat Unifications ]]
            if MSC.IsForever then
                if stat == "ITEM_MOD_HIT_RATING_SHORT" or stat == "ITEM_MOD_HIT_SPELL_RATING_SHORT" or stat == "ITEM_MOD_HIT_MELEE_RATING_SHORT" or stat == "ITEM_MOD_HIT_RANGED_RATING_SHORT" then
                    w = math_max(w, weights["ITEM_MOD_HIT_RATING_SHORT"] or 0, weights["ITEM_MOD_HIT_SPELL_RATING_SHORT"] or 0, weights["ITEM_MOD_HIT_MELEE_RATING_SHORT"] or 0, weights["ITEM_MOD_HIT_RANGED_RATING_SHORT"] or 0)
                elseif stat == "ITEM_MOD_CRIT_RATING_SHORT" or stat == "ITEM_MOD_SPELL_CRIT_RATING_SHORT" or stat == "ITEM_MOD_CRIT_MELEE_RATING_SHORT" or stat == "ITEM_MOD_CRIT_RANGED_RATING_SHORT" then
                    w = math_max(w, weights["ITEM_MOD_CRIT_RATING_SHORT"] or 0, weights["ITEM_MOD_SPELL_CRIT_RATING_SHORT"] or 0, weights["ITEM_MOD_CRIT_MELEE_RATING_SHORT"] or 0, weights["ITEM_MOD_CRIT_RANGED_RATING_SHORT"] or 0)
                elseif stat == "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" and w == 0 then
                    -- "+X Spell Damage" is damage-only (Parse.lua keeps it apart
                    -- from Spell Power), so it's worth the profile's Spell Power
                    -- weight -- but unlike Spell Power it is never folded into
                    -- healing (Evaluator only folds ITEM_MOD_SPELL_POWER_SHORT).
                    w = weights["ITEM_MOD_SPELL_POWER_SHORT"] or 0
                end
            end

            if w < 0 and (weightKey == "MSC_WEAPON_SPEED" or weightKey == "MSC_OH_WEAPON_SPEED") then
                local fast = -w * math_max(0, FAST_SPEED_REF - val)
                score = score + fast
                if fast > 0 then usefulRaw = usefulRaw + val end
            end
            if w > 0 then
                local finalVal = val
                if foreverLevel and MSC.RatingIndexMap[stat] then
                    local converted = MSC:GetRatingPercent(stat, val, foreverLevel)
                    if converted then finalVal = converted end
                end
                if slotId == 17 and isWeaponDps and weightKey ~= "MSC_WEAPON_DPS_OH" then finalVal = val * 0.5 end
                score = score + (finalVal * w)
                if w >= 0.02 then usefulRaw = usefulRaw + val else uselessRaw = uselessRaw + val end
            end
            -- Spell Power also heals, so its healing half scores at the
            -- Healing weight. This used to happen only on the full-character
            -- path (Evaluator folded SP into Healing there), so tooltips and
            -- upgrade arrows under-scored Spell Power for healer profiles.
            if stat == "ITEM_MOD_SPELL_POWER_SHORT" then
                local hw = weights["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] or 0
                if hw > 0 then
                    score = score + (val * hw)
                    if w < 0.02 then usefulRaw = usefulRaw + val end
                end
            end
            -- (No implicit "+Healing grants 1/3 as Spell Power" bonus on Forever:
            -- its items print that third explicitly as a separate "+X Spell
            -- Damage" line -- e.g. Holy Shroud is +33 Healing / +11 Spell
            -- Damage -- and 77 healing items carry no damage at all, so
            -- inferring one double-counted it.)
        end
    end
    
    local bonusScore = 0
    if RXP_SGJ_Settings and RXP_SGJ_Settings.AssumeCampingBuffs and MSC.IsForever then
        if (slotId == 16 or slotId == 17) and stats["MSC_WEAPON_SPEED"] and stats["MSC_WEAPON_SPEED"] > 0 then
            local bonusDamage = 2 -- Placeholder for early game Rough Sharpening/Weightstone
            local bonusDps = bonusDamage / stats["MSC_WEAPON_SPEED"]
            local w = weights["MSC_WEAPON_DPS"] or 0
            if slotId == 17 and weights["MSC_WEAPON_DPS_OH"] then
                w = weights["MSC_WEAPON_DPS_OH"]
            elseif slotId == 17 then
                bonusDps = bonusDps * 0.5 -- native OH penalty if OH weight not distinct
            end
            bonusScore = bonusScore + (bonusDps * w)
        end
    end
    score = score + bonusScore

    
    if not MSC.IsVanillaRules and stats["ITEM_MOD_RESILIENCE_RATING_SHORT"] then
        local resVal = stats["ITEM_MOD_RESILIENCE_RATING_SHORT"]
        local resWeight = weights["ITEM_MOD_RESILIENCE_RATING_SHORT"] or 0
        if resVal > 0 and resWeight <= 0.05 then score = score - (resVal * 1.5) end
    end

    if uselessRaw > (usefulRaw * 2) then return 0 end
    return math_max(0, MSC.Round(score, 1))
end

function MSC.ApplyElvUISkin(frame) end

-- =============================================================
-- 11. EXTERNAL HELPERS
-- =============================================================
function MSC:GetItemSetID(itemIDOrLink)
    if not itemIDOrLink then return nil end
    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = GetItemInfo(itemIDOrLink)
    if setID then return setID end
    local tipName = "MSC_ScannerTooltip"
    local tip = _G[tipName] or CreateFrame("GameTooltip", tipName, nil, "GameTooltipTemplate")
    tip:SetOwner(WorldFrame, "ANCHOR_NONE"); tip:ClearLines()
    local status = pcall(function() tip:SetHyperlink(itemIDOrLink) end)
    if status then
        for i = 2, tip:NumLines() do
            local line = _G[tipName.."TextLeft"..i]
            local text = line and line:GetText()
            local setPattern = MSC.L["^Set: (.*) %("] or "^Set: (.*) %("
				if string_find(text, MSC.L["Set: "] or "Set: ") then
					local setName = string_match(text, setPattern)
					return setName
				end
            end
        end
    return nil
end

local Scratch_ItemColors = { RED=0, YELLOW=0, BLUE=0 }
local Scratch_ItemGemIDs = {}

function MSC:GetItemGems(itemLink)
    Scratch_ItemColors.RED = 0; Scratch_ItemColors.YELLOW = 0; Scratch_ItemColors.BLUE = 0; wipe(Scratch_ItemGemIDs)
    local metaID = nil
    if not itemLink then return MSC:SafeCopy(Scratch_ItemColors), nil, MSC:SafeCopy(Scratch_ItemGemIDs) end
    
    local g1, g2, g3, g4 = string_match(itemLink, "item:%d+:%d+:(%d+):(%d+):(%d+):(%d+)")
    local foundGems = { tonumber(g1), tonumber(g2), tonumber(g3), tonumber(g4) }
    
    for _, id in ipairs(foundGems) do
        if id and id > 0 then
            table_insert(Scratch_ItemGemIDs, id)
            if MSC.GemOptions and MSC.GemOptions["EMPTY_SOCKET_META"] then
                for _, g in ipairs(MSC.GemOptions["EMPTY_SOCKET_META"]) do if g.id == id then metaID = id; break end end
            end
            local cType = MSC.GetGemColor and MSC.GetGemColor(id)
            if cType then
                if cType == "RED" then Scratch_ItemColors.RED = Scratch_ItemColors.RED + 1
                elseif cType == "YELLOW" then Scratch_ItemColors.YELLOW = Scratch_ItemColors.YELLOW + 1
                elseif cType == "BLUE" then Scratch_ItemColors.BLUE = Scratch_ItemColors.BLUE + 1
                elseif cType == "ORANGE" then Scratch_ItemColors.RED = Scratch_ItemColors.RED + 1; Scratch_ItemColors.YELLOW = Scratch_ItemColors.YELLOW + 1
                elseif cType == "PURPLE" then Scratch_ItemColors.RED = Scratch_ItemColors.RED + 1; Scratch_ItemColors.BLUE = Scratch_ItemColors.BLUE + 1
                elseif cType == "GREEN" then Scratch_ItemColors.YELLOW = Scratch_ItemColors.YELLOW + 1; Scratch_ItemColors.BLUE = Scratch_ItemColors.BLUE + 1
                elseif cType == "PRISMATIC" then Scratch_ItemColors.RED = Scratch_ItemColors.RED + 1; Scratch_ItemColors.YELLOW = Scratch_ItemColors.YELLOW + 1; Scratch_ItemColors.BLUE = Scratch_ItemColors.BLUE + 1 end
            end
        end
    end
    return MSC:SafeCopy(Scratch_ItemColors), metaID, MSC:SafeCopy(Scratch_ItemGemIDs)
end

-- =============================================================
-- 12. DEBUG
-- =============================================================
function MSC:DebugItem()
    local tip = GameTooltip
    local _, link = tip:GetItem()
    if not link then print(MSC.L["|cffff0000SGJ: Please hover over an item to debug.|r"]) return end
    local weights, specName = MSC.GetCurrentWeights()
    if not weights then print(MSC.L["|cffff0000SGJ: No weights loaded.|r"]) return end
    local stats = MSC.SafeGetItemStats(link, nil, weights, specName)
    local score = 0
    print(" ")
    print(MSC.L["|cff00ccff--- SGJ DEBUG REPORT ---|r"])
	print(MSC.L["Item: "] .. link)
	print(MSC.L["Profile: "] .. "|cffffd100" .. (specName or MSC.L["Unknown"]) .. "|r")
    for stat, val in pairs(stats) do
        if type(val) == "number" then
            local w = weights[stat]
            if w then
                local lineScore = val * w
                score = score + lineScore
                local statName = string_gsub(string_gsub(stat, "ITEM_MOD_", ""), "_SHORT", "")
                print(string_format(MSC.L["|cffffffff%s:|r %.1f x %.2f = |cff00ff00%.1f|r"], statName, val, w, lineScore))
            else
                local statName = string_gsub(string_gsub(stat, "ITEM_MOD_", ""), "_SHORT", "")
                print(string_format(MSC.L["|cff888888%s: %.1f (Weight: 0)|r"], statName, val))
            end
        end
    end
    local useful, useless = 0, 0
    for stat, val in pairs(stats) do
        if type(val) == "number" then
            if (weights[stat] or 0) >= 0.1 then useful = useful + val else useless = useless + val end
        end
    end
		print(MSC.L["Ratio Check: "] .. string_format(MSC.L["Useful: %.1f / Useless: %.1f"], useful, useless))
		if useless > (useful * 2) then 
			print(MSC.L["|cffff0000[FAIL] Item rejected by Bouncer (Mostly Junk)|r"])
		else 
			print(MSC.L["|cff00ff00[PASS] Item accepted|r"]) 
		end
		print(MSC.L["Final Score: "] .. "|cff00ccff" .. MSC.Round(score, 1) .. "|r")
end

function MSC:GetDefenseFloor(rule)
    -- Forever: the same target the tank scalers use (none below 50, then
    -- sliding to 440 by 60), so the "don't drop below" check agrees with them.
    if MSC.IsForever and rule and rule.dynamic and MSC.GetForeverDefenseTarget then
        return MSC.GetForeverDefenseTarget() or math.huge
    end
    if rule and rule.dynamic then
        return UnitLevel("player") * 5 + 140
    end
    return rule and rule.base or 0
end

-- =============================================================
-- 13. LOAD SAVED WEIGHTS (Startup Race Condition Handler)
-- =============================================================
local dbLoader = CreateFrame("Frame")
dbLoader:RegisterEvent("PLAYER_LOGIN")
dbLoader:SetScript("OnEvent", function()
    C_Timer.After(0.5, function()
        if RXP_SGJ_DB and RXP_SGJ_DB.customWeights and RXP_SGJ_Settings then
            local mode = MSC.GetManualSpec(MSC.GetActiveSpecGroup())
            if mode and mode ~= "AUTO" and RXP_SGJ_DB.customWeights[mode] then
                MSC.CachedWeights = nil
                MSC.CachedWeightsBySpec = MSC.CachedWeightsBySpec or {}
                wipe(MSC.CachedWeightsBySpec)
                if MSC.BumpScoringRevision then MSC:BumpScoringRevision() end
            end
        end
        if MSC.InitSettingsView and MSC.MainFrame and MSC.MainFrame:IsShown() then
            MSC.InitSettingsView(MSC.MainFrame.Content)
        end
    end)
end)

-- =============================================================
-- 14. COMBAT LAB: ON-USE TRINKET DETECTION
-- =============================================================
function MSC.IsValuableOnUseTrinket(itemID)
    if not itemID then return false end

    -- Search the three primary databases where you store trinket data
    local data = MSC.TrinketDB[itemID] or MSC.ItemOverrides[itemID] or MSC.ProcDB[itemID]

    if data and data.note then
        local noteStr = tostring(data.note)
        
        -- We only care about trinkets that have an active "Use:" effect
        if string.find(noteStr, "Use:") then
            -- We want to pop throughput stats during Burn Phases. 
            -- This filters out Defensive/Health/Utility trinkets.
            if string.find(noteStr, "AP") or 
               string.find(noteStr, "SP") or 
               string.find(noteStr, "Haste") or 
               string.find(noteStr, "Heal") or 
               string.find(noteStr, "Damage") or
               string.find(noteStr, "Crit") then
                return true
            end
        end
    end
    
    return false
end
