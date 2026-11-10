-- Load the whole embedded engine (SGJ\sgj.xml order) plus the fork modules in a permissive fake
-- WoW environment: unknown globals are callable no-op objects. Catches load-time errors from the
-- vendor transforms (namespace, renames, patches) and from the fork's load order.
local Stubs = require("wow_stubs")
local T = {}

local function dummy()
    local d = {}
    return setmetatable(d, {
        __index = function() return dummy() end,
        __call = function() return nil end,
        __concat = function(a, b) return tostring(a) .. tostring(b) end,
    })
end

local function permissive()
    setmetatable(_G, { __index = function(_, k)
        if type(k) == "string" and k:match("^[A-Z]") then
            local v = dummy(); rawset(_G, k, v); return v
        end
        return nil
    end })
end

local function scripts(xml)
    local list = {}
    for f in io.open(xml):read("*a"):gmatch('<Script file="([^"]+)"/>') do list[#list + 1] = (f:gsub("\\", "/")) end
    return list
end

function T.test_engine_and_fork_load_without_errors()
    local ctx = Stubs.install({ class = "DRUID", level = 20, addonEnableState = 0 })
    _G.GetBuildInfo = function() return "1.60.1", "70862", "Nov 1 2026", 16001 end
    _G.GetLocale = function() return "enUS" end
    _G.C_AddOns.GetAddOnMetadata = function() return "" end
    _G.GetAddOnMetadata = function() return "" end
    _G.hooksecurefunc = function() end
    _G.UIParent = Stubs.newFrame("UIParent")
    _G.GameTooltip = Stubs.newFrame("GameTooltip")
    _G.ItemRefTooltip = Stubs.newFrame("ItemRefTooltip")
    _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    _G.strsplit = function(sep, s) local out = {} for p in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = p end return unpack(out) end
    _G.SlashCmdList = {}
    _G.Minimap = Stubs.newFrame("Minimap")
    _G.StaticPopupDialogs = {}
    _G.GetRealmName = function() return "Realm" end
    _G.GetInventoryItemLink = function() return nil end
    _G.GetInventoryItemID = function() return nil end
    _G.GetContainerNumSlots = function() return 0 end
    _G.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemLink = function() return nil end }
    _G.InCombatLockdown = function() return false end
    _G.GetTime = function() return 0 end
    _G.IsLoggedIn = function() return true end
    for _, n in ipairs({ "UnitStat", "UnitAttackPower", "UnitRangedAttackPower", "UnitArmor", "UnitDefense", "UnitAttackSpeed", "UnitDamage", "UnitRangedDamage", "GetCritChance", "GetRangedCritChance", "GetSpellCritChance", "GetSpellBonusDamage", "GetSpellBonusHealing", "GetHitModifier", "GetSpellHitModifier", "GetDodgeChance", "GetParryChance", "GetBlockChance", "UnitHealthMax", "UnitPowerMax", "GetCombatRating", "GetCombatRatingBonus", "GetManaRegen", "UnitRace", "UnitSex", "GetShapeshiftForm", "GetNumShapeshiftForms", "UnitBuff", "UnitAura", "GetWeaponEnchantInfo", "GetSpellCritChanceFromIntellect", "GetExpertise" }) do
        if not _G[n] then _G[n] = function() return 0, 0, 0, 0 end end
    end
    _G.C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end, NewTimer = function() return { Cancel = function() end } end }
    RXPCData = {}
    local addon = { game = "FOREVER" }
    local files = { "ForeverBuilds/Bootstrap.lua" }
    for _, f in ipairs(scripts("SGJ/sgj.xml")) do files[#files + 1] = f end
    for _, f in ipairs(scripts("ForeverBuilds/ForeverBuilds.xml")) do files[#files + 1] = f end
    local failures = {}
    for _, f in ipairs(files) do
        local ok, err = pcall(Stubs.loadAddonFile, f, addon)
        if not ok then failures[#failures + 1] = f .. ": " .. tostring(err) end
    end
    assert(#failures == 0, "load errors:\n" .. table.concat(failures, "\n"))
    assert_eq(type(RXP_SGJ_NS.SetTalentBuildRole), "function", "engine loaded into RXP_SGJ_NS")
    assert_eq(type(RXP_SGJ_NS.BuildMatch.DRUID), "table")
    assert(_G.RXPGuides == nil or type(_G.RXPGuides) ~= "table" or _G.RXPGuides ~= RXP_SGJ_NS, "_G.RXPGuides not replaced by the engine")
    assert_eq(type(SlashCmdList.RXPFB), "function")
    assert_eq(SlashCmdList.SHARPIESGEARJUDGE, nil, "engine slash command not registered")

    -- first events of a session: engine init (class module, settings) and the fork's Apply()
    local eventErrors = {}
    for _, ev in ipairs({ { "ADDON_LOADED", "RXPGuides" }, { "PLAYER_LOGIN" } }) do
        for _, f in ipairs(ctx.frames) do
            if f.events[ev[1]] and f.scripts.OnEvent then
                local ok, err = pcall(f.scripts.OnEvent, f, ev[1], ev[2])
                if not ok then eventErrors[#eventErrors + 1] = ev[1] .. ": " .. tostring(err) end
            end
        end
    end
    assert(#eventErrors == 0, "event errors:\n" .. table.concat(eventErrors, "\n"))
    assert_eq(RXP_SGJ_NS.CurrentClass and RXP_SGJ_NS.CurrentClass.Name, "DRUID", "engine class module loaded")
end

return T
