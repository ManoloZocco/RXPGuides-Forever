-- RestedXP Forever fork: wire the Forever Build modules (loaded last by ForeverBuilds.xml).
RXP_FB = RXP_FB or {}

SLASH_RXPFB1 = "/rxpfb"
SlashCmdList["RXPFB"] = function(msg) RXP_FB.Diagnostics.Run(msg) end

if not RXP_SGJ_DISABLED then
    RXP_FB.BuildState.Init()
    RXP_FB.TalentGuideUI.Attach()
end
