local Stubs = require("wow_stubs")
local T = {}

local CAT = "Leveling|CAT_RAID|10"

local function setup(opts)
    opts = opts or {}
    RXP_FB = {}
    RXP_SGJ_DISABLED = opts.disabled or false
    RXP_SGJ_NS = { IsForever = true }
    RXP_SGJ_VERSION, RXP_SGJ_COMMIT = "3.3.2-Forever", "f285a2b51a2d0a79a58f61ead60af9c2270f76f5"
    PlayerSpellsFrame = nil
    SlashCmdList, SLASH_RXPFB1 = {}, nil
    local ctx = Stubs.install({ class = "DRUID", level = 20, spells = { [16934] = "Ferocity" } })
    UIParent = Stubs.newFrame("UIParent")
    Stubs.loadAddonFile("SGJ/Data/BuildMatch_Forever.lua", {})
    local engine = RXP_SGJ_NS
    engine.PrettyNames = {}
    engine.SetTalentBuildRole = function() end
    engine.GetActiveSpecGroup = function() return 1 end
    engine.HasDualSpec = function() return false end
    engine.MatchTalentBuild = function() return { leveling = "Leveling" } end
    -- only Ferocity exists on the fake tree: every other talent of a build is unresolved
    engine.ForEachTraitTalent = function(fn) fn("Ferocity", 0, 2, { ID = 101, maxRanks = 5 }, 16934); return true end
    RXPCData = { foreverBuilds = opts.saved }
    for _, f in ipairs({ "TalentResolver", "BuildCatalog", "TalentPath", "TalentGuideUI", "BuildState", "Options", "Diagnostics", "Init" }) do
        Stubs.loadAddonFile("ForeverBuilds/" .. f .. ".lua", { game = "FOREVER" })
    end
    ctx.printed = nil
    return ctx, engine
end

function T.test_slash_command_registered()
    setup()
    assert_eq(SLASH_RXPFB1, "/rxpfb")
    assert_eq(type(SlashCmdList.RXPFB), "function")
end

function T.test_status_prints_builds_and_engine_version()
    local ctx = setup({ saved = { [1] = CAT } })
    SlashCmdList.RXPFB("")
    local out = table.concat(ctx.printed, "\n")
    assert(out:find("engine 3.3.2%-Forever %(f285a2b%)"), out)
    assert(out:find("spec 1: Leveling|CAT_RAID|10", 1, true), out)
    assert(out:find("spec 2: AUTO", 1, true), out)
    assert(out:find("matched from talents: Leveling", 1, true), out)
end

function T.test_check_reports_unresolved_and_highlight()
    local ctx = setup()
    SlashCmdList.RXPFB("check")
    local out = table.concat(ctx.printed, "\n")
    assert(out:find("unresolved", 1, true), out)
    assert(out:find("highlight: unavailable", 1, true), out)
end

function T.test_talents_toggles_panel()
    setup()
    SlashCmdList.RXPFB("talents")
    assert(RXP_FB.TalentGuideUI.panel, "panel created")
    assert_eq(RXP_FB.TalentGuideUI.panel.shown, true)
    SlashCmdList.RXPFB("talents")
    assert_eq(RXP_FB.TalentGuideUI.panel.shown, false)
end

function T.test_init_skips_when_disabled()
    local _, engine = setup({ disabled = true })
    assert_eq(engine.GetTalentBuildRoleForGroup, nil)
    assert_eq(RXP_FB.TalentGuideUI.waiter, nil)
end

function T.test_init_wires_modules()
    local _, engine = setup()
    assert_eq(type(engine.GetTalentBuildRoleForGroup), "function")
    assert(RXP_FB.TalentGuideUI.waiter, "talent UI waits for Blizzard_PlayerSpells")
end

return T
