if RXP_SGJ_DISABLED then return end
RXP_SGJ_DB = RXP_SGJ_DB or {}
RXP_SGJ_Settings = RXP_SGJ_Settings or {}

-- Secret values (protected tooltip text etc.) error on compare/concat while tainted.
-- issecretvalue isn't guaranteed to exist on every client build that has secrets,
-- so fall back to canaccessvalue, then to a protected compare as a last resort.
local _issecretvalue, _canaccessvalue = issecretvalue, canaccessvalue
local function _probeCompare(v) return v == "" end
function MSC_IsSecret(v)
    if v == nil then return false end
    if _issecretvalue and _issecretvalue(v) then return true end
    if _canaccessvalue and not _canaccessvalue(v) then return true end
    return not pcall(_probeCompare, v)
end

local function IsItemLink(link)
    return type(link) == "string" and not MSC_IsSecret(link) and string.find(link, "item:", 1, true) ~= nil
end

function MSC_GetTooltipItem(tooltip)
    if not tooltip then return nil, nil end
    -- Prefer the modern API: on the 11.x-derived engine, tooltip:GetItem() can still
    -- exist as a method (inherited generically) while silently returning nothing,
    -- since the actual item data now lives in tooltip.processingInfo.tooltipData
    -- rather than wherever GetItem() used to read from. Checking "does the method
    -- exist" isn't enough to know it still works, so try the known-good modern path
    -- first and only fall back to the legacy method for clients where it's absent.
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local name, link = TooltipUtil.GetDisplayedItem(tooltip)
        if IsItemLink(link) then return name, link end
    end
    -- tooltipData.hyperlink is set for spell/stance tooltips too; only accept item links.
    local data = tooltip.processingInfo and tooltip.processingInfo.tooltipData
    if data and IsItemLink(data.hyperlink) then
        return nil, data.hyperlink
    end
    if tooltip.GetItem then
        local name, link = tooltip:GetItem()
        if IsItemLink(link) then return name, link end
    end
    return nil, nil
end
-- Polyfill for WoW 11.0+ engine API removals
if C_Item then
    if not GetItemInfoInstant and C_Item.GetItemInfoInstant then _G.GetItemInfoInstant = function(id) return C_Item.GetItemInfoInstant(id) end end
    if not IsEquippableItem and C_Item.IsEquippableItem then _G.IsEquippableItem = function(id) return C_Item.IsEquippableItem(id) end end
    if not GetItemInfo and C_Item.GetItemInfo then _G.GetItemInfo = function(id) return C_Item.GetItemInfo(id) end end
    if not GetItemIcon and C_Item.GetItemIconByID then _G.GetItemIcon = function(id) return C_Item.GetItemIconByID(id) end end
    if not GetItemStats and C_Item.GetItemStats then _G.GetItemStats = function(link) return C_Item.GetItemStats(link) end end
    if not EquipItemByName and C_Item.EquipItemByName then _G.EquipItemByName = function(item, slot) return C_Item.EquipItemByName(item, slot) end end
end

if not UnitDefense then
    _G.UnitDefense = function(unit)
        local lvl = UnitLevel(unit or "player") or 1
        return (lvl * 5), 0
    end
end

local addonName, MSC = "RXPGuides", RXP_SGJ_NS
-- vendor: removed _G[addonName] = MSC

-- =============================================================
-- 0. GAME VERSION DETECTION
-- =============================================================
local _, _, _, interfaceVersion = GetBuildInfo()
local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local addonTitle = GetMetadata(addonName, "Title") or ""
local version = GetBuildInfo(); MSC.IsForever = (string.find(addonTitle, "Forever Edition") ~= nil) or (interfaceVersion == 16001) or (version and string.find(version, "1.60.1") ~= nil)
MSC.IsEra   = (interfaceVersion < 20000) and not MSC.IsForever
-- Season of Discovery runs on the Era client; its gear doesn't follow the Era raid tiers
MSC.IsSoD   = MSC.IsEra and C_Seasons ~= nil and C_Seasons.GetActiveSeason ~= nil
    and C_Seasons.GetActiveSeason() == ((Enum and Enum.SeasonID and Enum.SeasonID.SeasonOfDiscovery) or 2)
MSC.IsVanillaRules = MSC.IsEra or MSC.IsForever
MSC.IsTBC   = (interfaceVersion >= 20000 and interfaceVersion < 30000)
MSC.IsWrath = (interfaceVersion >= 30000)

-- =============================================================
-- 1. Initialize the Namespace
-- =============================================================
MSC.CurrentClass = nil
MSC.ClassProfiles = {}
MSC.PrettyNames = {} 
MSC.PendingModules = {} -- Storage for modules waiting for player login

-- =============================================================
-- 2. Define the Module Registration Function
-- =============================================================
function MSC.RegisterModule(className, classTable)
    -- Store them all. We don't know who we are yet.
    MSC.PendingModules[className] = classTable
    -- Every class's weapon bonus stays reachable after login (the modules
    -- themselves are dropped), so plugins can score weapons for other
    -- characters. These functions don't use self or their module table.
    if classTable.GetWeaponBonus then
        MSC.ClassWeaponBonus[className:upper()] = classTable.GetWeaponBonus
    end
    -- Same for relics (librams, idols, totems), but only the relic table is
    -- kept: the classes' GetRelicBonus methods reach their whole module
    -- through an upvalue, so keeping them would keep every module alive.
    -- MSC.GetClassRelicBonus rebuilds their result from the table (below).
    local relics = classTable.Relics or classTable.Totems or classTable.Idols
    if type(relics) == "table" then
        MSC.ClassRelics[className:upper()] = relics
    end
end

-- =============================================================
-- 2b. WHO A WEAPON BONUS IS FOR
-- =============================================================
-- Weapon bonuses (racials, weapon talents) read the character through these.
-- A plugin scoring for another character sets MSC.BonusContext to
-- { race = "Human", level = 20, ap = 300, talentRanks = { WEAPONMASTER = 2 } }
-- for the length of the call; nil means the logged-in player.
MSC.ClassWeaponBonus = MSC.ClassWeaponBonus or {}
MSC.BonusContext = nil

-- Some languages name a talent tree differently per class while the English
-- profile/build name is shared (Korean: Warrior Protection 방어, Paladin 보호).
-- MSC.ClassL(class, key) returns the "key|CLASS" translation when the locale has
-- one, else MSC.L[key]. rawget: MSC.L caches every key it is asked for.
function MSC.ClassL(class, key)
    local L = MSC.L
    return (class and key and rawget(L, key .. "|" .. class)) or L[key]
end

function MSC.CtxRace()
    local ctx = MSC.BonusContext
    if ctx and ctx.race then return ctx.race end
    local _, race = UnitRace("player")
    return race
end

function MSC.CtxLevel()
    local ctx = MSC.BonusContext
    if ctx and ctx.level then return ctx.level end
    return UnitLevel("player")
end

function MSC.CtxAttackPower()
    local ctx = MSC.BonusContext
    if ctx and ctx.ap then return ctx.ap end
    if MSC.GetJudgingStats then return MSC.GetJudgingStats().ap end -- unbuffed, plus assumed buffs
    if not UnitAttackPower then return 0 end
    local base, pos, neg = UnitAttackPower("player")
    return (base or 0) + (pos or 0) + (neg or 0)
end

-- =============================================================
-- 2c. RELICS FOR ANY CLASS
-- =============================================================
-- MSC.GetClassRelicBonus(className, relicID, specName) -> stat table or nil
-- The equivalent stats a relic gives a class/spec, for any class (plugins
-- scoring other characters). Same result as that class's own GetRelicBonus:
--   * a relic entry that is a stat table -> a copy of it (Era, TBC, Forever;
--     may carry non-number keys such as note/estimate: use the numbers);
--   * an entry that is a function(role, ctx, spec) (Forever) -> its result,
--     as MSC.GetForeverRelicBonus does;
--   * TBC Idol of the Raven Goddess (32387) -> its per-spec bonus, mirrored
--     from Classes/TBC/Druid.lua (the only relic handled in code there).
-- For the logged-in class it calls the class's own GetRelicBonus.
-- nil: unknown class, not one of that class's relics, or an error.
-- With MSC.BonusContext set (another character), relic effects that read
-- character stats use its level/ap (and spirit/itemArmor/shieldBlock when
-- given) and talent checks use its talentRanks; otherwise the logged-in
-- character's live stats are used.
MSC.ClassRelics = MSC.ClassRelics or {}

local function CopyStats(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function RavenGoddessTBC(spec)
    local bonus = {}
    if spec:find("RESTO") or spec:find("Healer") then
        bonus.ITEM_MOD_SPELL_HEALING_DONE_SHORT = 44
    elseif spec:find("FERAL") or spec:find("Cat") or spec:find("Bear") then
        bonus.ITEM_MOD_CRIT_RATING_SHORT = 20
    elseif spec:find("BALANCE") or spec:find("Caster") then
        bonus.ITEM_MOD_SPELL_CRIT_RATING_SHORT = 20
    end
    return bonus
end

local function RelicBonusFromTable(classKey, relicID, spec)
    if MSC.IsTBC and classKey == "DRUID" and relicID == 32387 then return RavenGoddessTBC(spec) end
    local relics = MSC.ClassRelics[classKey]
    local entry = relics and relics[relicID]
    if entry == nil then return nil end
    -- The shared body in Helpers (function or stat-table entries)
    if MSC.GetForeverRelicBonus then return MSC.GetForeverRelicBonus(relics, relicID, spec) end
    if type(entry) == "table" then return CopyStats(entry) end
    return nil
end

function MSC.GetClassRelicBonus(className, relicID, specName)
    if type(className) ~= "string" or type(relicID) ~= "number" then return nil end
    local classKey = className:upper()
    local spec = specName or ""
    local _, playerClass = UnitClass("player")
    local isPlayerClass = (playerClass == classKey)

    -- Relic effects read the character through MSC.GetRelicContext. For
    -- another class or character, swap in a context with its values for
    -- this call only (restored below, even after an error).
    local liveContext = MSC.GetRelicContext
    local swapped = false
    if liveContext and (type(MSC.BonusContext) == "table" or not isPlayerClass) then
        MSC.GetRelicContext = function()
            local c = liveContext()
            local bc = MSC.BonusContext
            if type(bc) == "table" then
                if bc.level then c.level = bc.level end
                if bc.ap then c.ap = bc.ap end
                if bc.spirit then c.spirit = bc.spirit end
                if bc.itemArmor then c.itemArmor = bc.itemArmor end
                if bc.shieldBlock then c.shieldBlock = bc.shieldBlock end
            end
            -- Classic regen from Spirit (Shamans have a higher base), as in GetRelicContext
            c.spiritRegen5 = ((classKey == "SHAMAN") and (17 + (c.spirit or 0) / 5) or (15 + (c.spirit or 0) / 5)) * 2.5
            return c
        end
        swapped = true
    end

    local ok, result = pcall(function()
        local cc = MSC.CurrentClass
        if isPlayerClass and cc and cc.GetRelicBonus then
            local res = cc:GetRelicBonus(relicID, spec)
            if type(res) ~= "table" then return nil end
            -- {} for an item that isn't one of the class's relics -> nil
            if next(res) == nil and RelicBonusFromTable(classKey, relicID, spec) == nil then return nil end
            return res
        end
        return RelicBonusFromTable(classKey, relicID, spec)
    end)

    if swapped then MSC.GetRelicContext = liveContext end
    if ok then return result end
    return nil
end

-- =============================================================
-- 3. THE FORCE INIT FUNCTION
-- =============================================================
function MSC:ForceInit()
    if MSC.CurrentClass then return end
    
    local _, playerClass = UnitClass("player")
    if not playerClass then return end

    -- Find the correct module
    for className, classTable in pairs(MSC.PendingModules) do
        if className:upper() == playerClass:upper() then
            MSC.CurrentClass = classTable
            
            if classTable.Profiles then
                for name, weights in pairs(classTable.Profiles) do
                    MSC.ClassProfiles[name] = weights
                end
            end

            if classTable.PrettyNames and MSC.PrettyNames then
                for key, niceName in pairs(classTable.PrettyNames) do
                    MSC.PrettyNames[key] = niceName
                end
            end
            
            -- vendor patch (quiet login): print(string.format(MSC.L["|cff00ff00Sharpie's Gear Judge:|r Loaded %s"], className))
            break 
        end
    end
    
    -- If we found it, clear the pending list to save RAM
    if MSC.CurrentClass then
        MSC.PendingModules = nil 
    end
end

-- =============================================================
-- 4. Auto-Loader (Safe Fallback)
-- =============================================================
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    -- The dataminer was removed in 3.2.1; drop what it recorded from saved data.
    if RXP_SGJ_DB then
        RXP_SGJ_DB.DropDatabase = nil
        RXP_SGJ_DB.QuestDatabase = nil
        RXP_SGJ_DB.EnableDataminer = nil
    end
    if RXP_SGJ_Settings then RXP_SGJ_Settings.MinerEnabled = nil end
    MSC:ForceInit()
end)
