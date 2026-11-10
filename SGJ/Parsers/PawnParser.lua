if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local L = MSC.L
local string_gsub, string_match = string.gsub, string.match
local string_find, string_sub = string.find, string.sub
local string_gmatch = string.gmatch 

-- =============================================================
-- 1. PAWN KEYWORDS
-- =============================================================
MSC.PawnStatMap = {
    -- Base Stats
    ["Strength"] = "ITEM_MOD_STRENGTH_SHORT", 
    ["Agility"] = "ITEM_MOD_AGILITY_SHORT",
    ["Stamina"] = "ITEM_MOD_STAMINA_SHORT", 
    ["Intellect"] = "ITEM_MOD_INTELLECT_SHORT",
    ["Spirit"] = "ITEM_MOD_SPIRIT_SHORT", 
    
    -- Ratings (Modern & Classic Syntax)
    ["CritRating"] = "ITEM_MOD_CRIT_RATING_SHORT",
    ["Crit"] = "ITEM_MOD_CRIT_RATING_SHORT", -- Classic
    ["HitRating"] = "ITEM_MOD_HIT_RATING_SHORT", 
    ["Hit"] = "ITEM_MOD_HIT_RATING_SHORT", -- Classic
    ["HasteRating"] = "ITEM_MOD_HASTE_RATING_SHORT",
    ["Haste"] = "ITEM_MOD_HASTE_RATING_SHORT", -- Classic
    ["ResilienceRating"] = "ITEM_MOD_RESILIENCE_RATING_SHORT", 
    ["Resilience"] = "ITEM_MOD_RESILIENCE_RATING_SHORT",
    ["ArmorPenetration"] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    
    -- Attack Power
    ["AttackPower"] = "ITEM_MOD_ATTACK_POWER_SHORT",
    ["Ap"] = "ITEM_MOD_ATTACK_POWER_SHORT",
    ["RangedAttackPower"] = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    ["Rap"] = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    ["FeralAttackPower"] = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", 
	["FeralAp"] = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", 
    
    -- Spell
    ["SpellPower"] = "ITEM_MOD_SPELL_POWER_SHORT", 
    ["Healing"] = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    ["SpellCritRating"] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT", 
    ["SpellHitRating"] = "ITEM_MOD_HIT_SPELL_RATING_SHORT",
    ["SpellHasteRating"] = "ITEM_MOD_SPELL_HASTE_RATING_SHORT", 
    ["Mp5"] = "ITEM_MOD_MANA_REGENERATION_SHORT",
    ["Hp5"] = "ITEM_MOD_HEALTH_REGENERATION_SHORT",
    -- Pawn's Classic spell keys (Era/TBC scales export these, not SpellPower)
    ["SpellDamage"] = "ITEM_MOD_SPELL_POWER_SHORT",
    ["SpellHit"] = "ITEM_MOD_HIT_SPELL_RATING_SHORT",
    ["SpellCrit"] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
    ["SpellHaste"] = "ITEM_MOD_SPELL_HASTE_RATING_SHORT",
    ["FireSpellDamage"] = "ITEM_MOD_FIRE_DAMAGE_SHORT",
    ["FrostSpellDamage"] = "ITEM_MOD_FROST_DAMAGE_SHORT",
    ["ShadowSpellDamage"] = "ITEM_MOD_SHADOW_DAMAGE_SHORT",
    ["ArcaneSpellDamage"] = "ITEM_MOD_ARCANE_DAMAGE_SHORT",
    ["NatureSpellDamage"] = "ITEM_MOD_NATURE_DAMAGE_SHORT",
    ["HolySpellDamage"] = "ITEM_MOD_HOLY_DAMAGE_SHORT",
	["SpellPenetration"] = "ITEM_MOD_SPELL_PENETRATION_SHORT",
    
    -- Tank
    ["DefenseRating"] = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", 
    ["Defense"] = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    ["DodgeRating"] = "ITEM_MOD_DODGE_RATING_SHORT",
    ["Dodge"] = "ITEM_MOD_DODGE_RATING_SHORT",
    ["ParryRating"] = "ITEM_MOD_PARRY_RATING_SHORT", 
    ["Parry"] = "ITEM_MOD_PARRY_RATING_SHORT",
    ["BlockRating"] = "ITEM_MOD_BLOCK_RATING_SHORT",
    ["Block"] = "ITEM_MOD_BLOCK_RATING_SHORT",
    ["BlockValue"] = "ITEM_MOD_BLOCK_VALUE_SHORT", 
    ["ExpertiseRating"] = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    ["Expertise"] = "ITEM_MOD_EXPERTISE_RATING_SHORT",
	["Armor"] = "ITEM_MOD_ARMOR_SHORT",
    ["SpellPenetration"] = "ITEM_MOD_SPELL_PENETRATION_SHORT",

    -- Weapon
    ["Dps"] = "MSC_WEAPON_DPS", 
    ["Speed"] = "MSC_WEAPON_SPEED",
	["MeleeDps"] = "MSC_WEAPON_DPS",
    ["RangedDps"] = "MSC_WEAPON_DPS",
    ["MeleeSpeed"] = "MSC_WEAPON_SPEED",
    ["RangedSpeed"] = "MSC_WEAPON_SPEED",

-- =============================================================
-- 2. GERMAN PAWN KEYWORDS
-- =============================================================

	["Stärke"] = "ITEM_MOD_STRENGTH_SHORT",
	["Beweglichkeit"] = "ITEM_MOD_AGILITY_SHORT",
	["Ausdauer"] = "ITEM_MOD_STAMINA_SHORT",
	["Intelligenz"] = "ITEM_MOD_INTELLECT_SHORT",
	["Willenskraft"] = "ITEM_MOD_SPIRIT_SHORT",

	-- Ratings
	["KritischeTrefferwertung"] = "ITEM_MOD_CRIT_RATING_SHORT",
	["Trefferwertung"] = "ITEM_MOD_HIT_RATING_SHORT",
	["Tempowertung"] = "ITEM_MOD_HASTE_RATING_SHORT",
	["Abhärtungswertung"] = "ITEM_MOD_RESILIENCE_RATING_SHORT",
	["Rüstungsumgehungswertung"] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",

	-- Attack Power
	["Angriffskraft"] = "ITEM_MOD_ATTACK_POWER_SHORT",
	["Distanzangriffskraft"] = "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
	["FeralAngriffskraft"] = "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",

	-- Spell
	["Zaubermacht"] = "ITEM_MOD_SPELL_POWER_SHORT",
	["Heilung"] = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
	["ZauberkritischeTrefferwertung"] = "ITEM_MOD_SPELL_CRIT_RATING_SHORT",
	["Zaubertempowertung"] = "ITEM_MOD_SPELL_HASTE_RATING_SHORT",
	["ManaAlle5Sek"] = "ITEM_MOD_MANA_REGENERATION_SHORT",

	-- Tank
	["Verteidigungswertung"] = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
	["Ausweichwertung"] = "ITEM_MOD_DODGE_RATING_SHORT",
	["Parrierwertung"] = "ITEM_MOD_PARRY_RATING_SHORT",
	["Blockwertung"] = "ITEM_MOD_BLOCK_RATING_SHORT",
	["Blockwert"] = "ITEM_MOD_BLOCK_VALUE_SHORT",
	["Waffenkundewertung"] = "ITEM_MOD_EXPERTISE_RATING_SHORT",
}

-- =============================================================
--  PAWN PARSER
-- =============================================================

function MSC:ParsePawnString(pawnString)
    if not pawnString or type(pawnString) ~= "string" then return nil end
     
    -- 1. CLEANUP
    local clean = string_gsub(string_gsub(pawnString, "%)", ""), "%(", "")
    
    -- 2. EXTRACT PROFILE NAME
    local namePattern = "v1:%s*\"([^\"]+)\""
    local profileName = string_match(clean, namePattern)
    
    if not profileName then 
        profileName = string_match(clean, "v1:%s*([^%s:,]+):") 
    end
    if not profileName then return nil end

    -- 3. EXTRACT STATS
    local weights = {}
    local _, endPos = string_find(clean, namePattern)
    if not endPos then _, endPos = string_find(clean, "v1:") end
    
    if endPos then
        local statBlock = string_sub(clean, endPos + 1)
        for stat, val in string_gmatch(statBlock, "([^%s=,]+)%s*=%s*([%-%d%.]+)") do
            local internalKey = MSC.PawnStatMap[stat]
            -- Store under the key items actually carry on this game version
            -- (Forever weapon DPS is ITEM_MOD_DAMAGE_PER_SECOND_SHORT, not
            -- MSC_WEAPON_DPS), or the imported weight scores nothing.
            if internalKey and MSC.NormalizeStatKey then internalKey = MSC.NormalizeStatKey(internalKey) end
            local numberVal = tonumber(val)
            
            if internalKey and numberVal and numberVal ~= 0 then
                weights[internalKey] = numberVal
            end
        end
    end

    if not next(weights) then return nil end
    
    return weights, profileName
end

function MSC:ImportAndSavePawnString(pawnString)
    local weights, name = self:ParsePawnString(pawnString)
    
    if not weights and self.ParseSixtyUpgradesString then
        weights, name = self:ParseSixtyUpgradesString(pawnString)
    end
    
    if not weights then 
        print(MSC.L["|cffff0000SGJ: Invalid Pawn or Sixty Upgrades string format.|r"])
        return false 
    end

    -- Hand over to the UI for Spec Selection (Tagging)
    self:ShowSpecSelectionUI(name, weights)
    
    return true
end

function MSC:SavePawnProfile(profileName, rawWeights, baseSpec)
    -- Ensure the old DB exists
    RXP_SGJ_DB = RXP_SGJ_DB or {}
    RXP_SGJ_DB.customWeights = RXP_SGJ_DB.customWeights or {}
    
    -- Add the prefix to prevent overwriting hardcoded spec names
    local uniqueName = "Pawn: " .. profileName
    
    -- Save weights AND the spec tag into the original DB
    RXP_SGJ_DB.customWeights[uniqueName] = {
        weights = rawWeights,
        BaseSpec = baseSpec 
    }
    
    print(string.format(MSC.L["|cff00ff00SGJ:|r Successfully imported %s"], uniqueName))
    StaticPopup_Show("SGJ_RELOAD_REQUIRED")
end

function MSC:ShowSpecSelectionUI(profileName, weights)
    if not MSC.CurrentClass and MSC.ForceInit then
        MSC:ForceInit()
    end

    local specs = MSC.CurrentClass and MSC.CurrentClass.PrettyNames or {}
    if not next(specs) then
        print(MSC.L["|cffff0000SGJ Error: Class profiles not loaded yet. Try again in a few seconds.|r"])
        return
    end

    if not SGJ_SpecSelectFrame then
        local f = CreateFrame("Frame", "SGJ_SpecSelectFrame", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(260, 200)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f.TitleText:SetText(MSC.L["Select Base Spec"])
        f.Buttons = {} -- Button pool to prevent memory leaks
        SGJ_SpecSelectFrame = f
    end

    local f = SGJ_SpecSelectFrame
    f:Show()

    local yOffset = -40
    local buttonIndex = 1
    local specs = MSC.CurrentClass and MSC.CurrentClass.PrettyNames or {}

    for _, btn in ipairs(f.Buttons) do btn:Hide() end

    for specKey, displayName in pairs(specs) do
        if not string.find(specKey, "Leveling") then
            local btn = f.Buttons[buttonIndex]
            if not btn then
                btn = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
                btn:SetSize(220, 25)
                f.Buttons[buttonIndex] = btn
            end

            btn:SetPoint("TOP", 0, yOffset)
            btn:SetText(displayName)
            btn:Show()

            btn:SetScript("OnClick", function()
                self:SavePawnProfile(profileName, weights, specKey)
                f:Hide()
            end)
            
            yOffset = yOffset - 30
            buttonIndex = buttonIndex + 1
        end
    end
    f:SetHeight(math.abs(yOffset) + 20)
end
