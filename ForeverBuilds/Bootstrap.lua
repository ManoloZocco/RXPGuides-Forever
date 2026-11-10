-- RestedXP Forever fork: runs before the embedded Sharpie's Gear Judge engine (SGJ\sgj.xml).
-- Creates the engine's private namespace and the fork's own table, and turns the
-- embedded engine off when the standalone Sharpie's Gear Judge addon is enabled
-- (both would register the same globals).
RXP_SGJ_NS = RXP_SGJ_NS or {}
RXP_FB = RXP_FB or {}

local STANDALONE = "SharpiesGearJudge"

function RXP_SGJ_StandaloneEnabled()
    local who = UnitName("player")
    local state
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        state = C_AddOns.GetAddOnEnableState(STANDALONE, who)
    elseif GetAddOnEnableState then
        state = GetAddOnEnableState(who, STANDALONE)
    end
    return (tonumber(state) or 0) > 0
end

RXP_SGJ_DISABLED = RXP_SGJ_StandaloneEnabled()

if RXP_SGJ_DISABLED then
    local warned = false
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        if warned then return end
        warned = true
        print("RestedXP Forever: Sharpie's Gear Judge standalone is enabled; disable it to use the built-in gear engine.")
    end)
end
