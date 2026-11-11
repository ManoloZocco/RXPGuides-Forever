if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS

-- =============================================================
-- FOREVER LEVELING CURVES: ATTACH
-- =============================================================
-- Hand-written (not generated). Loads after every class file and every
-- <Class>_Curves.lua: hands each class its curves and rebuilds its level-band
-- rows (weights at the band's first level), so GetSpec's row checks, the
-- profile list and the XP plugin keep working. Band keys follow each class's
-- existing naming. A class's own PrettyNames win; SPEC_LABEL only names a
-- band the class file doesn't.
local BANDS = { {1, 10}, {11, 20}, {21, 40}, {41, 51}, {52, 59} }
MSC.LevelingCurveAlias = { Leveling_Ret = "Leveling" } -- Paladin's 52-59 default row

local SPEC_LABEL = {
    Leveling_DW = "Dual Wield", Leveling_Tank = "Tank", Leveling_Dagger = "Daggers", Leveling_Hemo = "Hemo",
    Leveling_Fire = "Fire", Leveling_AoE = "AoE Grinding", Leveling_Demo = "Demonology", Leveling_Healer = "Healer",
    Leveling_HealerDungeon = "Dungeon Healer", Leveling_TankDungeon = "Dungeon Tank", Leveling_RetDungeon = "Dungeon DPS", Leveling_ArmsDungeon = "Dungeon DPS",
    Leveling_Melee = "Melee/Survival", Leveling_Smite = "Discipline/Holy", Leveling_Caster = "Caster", Leveling_Bear = "Bear",
}

for className, curves in pairs(MSC.ForeverLevelingCurves or {}) do
    local module = MSC.PendingModules and MSC.PendingModules[className]
    if module then
        module.LevelingCurves = curves
        module.LevelingGear = MSC.ForeverLevelingGear and MSC.ForeverLevelingGear[className] -- quest-gear rows (MSC.LevelingGearBlend)
        module.LevelingWeights = module.LevelingWeights or {}
        module.PrettyNames = module.PrettyNames or {}
        for role, curve in pairs(curves) do
            local firstLevel = curve[1] and curve[1][1] or 1
            for _, b in ipairs(BANDS) do
                local lo, hi = b[1], b[2]
                if hi >= firstLevel and (role == "Leveling" or lo > 10) then
                    local keyRole = role
                    if className == "PALADIN" and role == "Leveling" and lo == 52 then keyRole = "Leveling_Ret" end
                    local key = keyRole .. "_" .. lo .. "_" .. hi
                    module.LevelingWeights[key] = MSC.EvaluateLevelingCurve(curve, lo)
                    if not module.PrettyNames[key] then
                        module.PrettyNames[key] = "Leveling: " .. (SPEC_LABEL[role] or "Default") .. " (" .. lo .. "-" .. hi .. ")"
                    end
                end
            end
        end
    end
end
