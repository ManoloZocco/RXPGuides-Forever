if RXP_SGJ_DISABLED then return end
local _, MSC = "RXPGuides", RXP_SGJ_NS

StaticPopupDialogs["SGJ_DISABLE_RXP_GEAR"] = {
    text = MSC.L["|cff00FF00Sharpie's Gear Judge|r\n\nI see RestedXP is active.\n\nIt is currently showing its own gear tips.\n\nDo you want me to disable their **Item Upgrade** setting?"],
    button1 = MSC.L["Yes, Disable & Reload"], 
    button2 = MSC.L["No, Keep Both"],
    
    OnAccept = function()
        local myKey = UnitName("player") .. " - " .. GetRealmName()
        if RXPSettings and RXPSettings.profileKeys then
            local profileName = RXPSettings.profileKeys[myKey]
            if profileName and RXPSettings.profiles and RXPSettings.profiles[profileName] then
                RXPSettings.profiles[profileName].enableItemUpgrades = false; ReloadUI()
            end
        end
    end, timeout = 0, whileDead = true, hideOnEscape = false, preferredIndex = 3,
}

StaticPopupDialogs["SGJ_DISABLE_ZYGOR_GEAR"] = {
    text = MSC.L["|cff00FF00Sharpie's Gear Judge|r\n\nI see Zygor Guides is active.\n\nIt adds its own 'Gear Score' to tooltips.\n\nDo you want me to disable their **Auto Gear** system?"],
    button1 = MSC.L["Yes, Disable & Reload"], 
    button2 = MSC.L["No, Keep Both"],
    
    OnAccept = function()
        local Zygor = ZGV or ZygorGuidesViewer
        if Zygor and Zygor.db and Zygor.db.profile then
            Zygor.db.profile.autogear = false; Zygor.db.profile.itemscore_tooltips = false; ReloadUI()
        end
    end, timeout = 0, whileDead = true, hideOnEscape = false, preferredIndex = 3,
}

StaticPopupDialogs["SGJ_DISABLE_PAWN_TIPS"] = {
    text = MSC.L["|cff00FF00Sharpie's Gear Judge|r\n\nI see Pawn is active.\n\nFor conflict-free use, we recommend disabling **Pawn's Tooltip Upgrades** so they don't overlap with our Verdict.\n\nDisable Pawn tooltip info?"],
    button1 = MSC.L["Yes, Disable & Reload"], 
    button2 = MSC.L["No, Keep Both"],
    
    OnAccept = function()
        if PawnCommon then 
            PawnCommon.ShowUpgradesOnTooltips = false; ReloadUI() 
        else 
            print(MSC.L["|cff00FF00[SGJ]|r: Pawn settings not found yet."]) 
        end
    end, timeout = 0, whileDead = true, hideOnEscape = false, preferredIndex = 3,
}

local function CheckForConflicts()
    if RXP_SGJ_Settings and RXP_SGJ_Settings.DisableConflictCheck then return end

    if C_AddOns.IsAddOnLoaded("RestedXP") or C_AddOns.IsAddOnLoaded("RXPGuides") then
        if RXPSettings and RXPSettings.profileKeys then
            local myKey = UnitName("player") .. " - " .. GetRealmName()
            local profileName = RXPSettings.profileKeys[myKey]
            if profileName and RXPSettings.profiles and RXPSettings.profiles[profileName] and RXPSettings.profiles[profileName].enableItemUpgrades ~= false then
                StaticPopup_Show("SGJ_DISABLE_RXP_GEAR"); return
            end
        end
    end
    local Zygor = ZGV or ZygorGuidesViewer
    if Zygor and Zygor.db and Zygor.db.profile and (Zygor.db.profile.autogear ~= false or Zygor.db.profile.itemscore_tooltips ~= false) then
         StaticPopup_Show("SGJ_DISABLE_ZYGOR_GEAR"); return
    end
    if C_AddOns.IsAddOnLoaded("Pawn") and PawnCommon and PawnCommon.ShowUpgradesOnTooltips ~= false then
        StaticPopup_Show("SGJ_DISABLE_PAWN_TIPS")
    end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function(self, event) 
    C_Timer.After(4, CheckForConflicts)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD") 
end)