local Stubs = require("wow_stubs")
local T = {}

local CAT = "Leveling|CAT_RAID|10"

local function setup(opts)
    opts = opts or {}
    RXP_FB = {}
    RXP_SGJ_DISABLED = opts.disabled or false
    RXP_SGJ_NS = { IsForever = true }
    Stubs.install({ class = "DRUID" })
    Stubs.loadAddonFile("SGJ/Data/BuildMatch_Forever.lua", {})
    local engine = RXP_SGJ_NS
    engine.PrettyNames = {}
    engine.SetTalentBuildRole = function() end
    engine.GetActiveSpecGroup = function() return 1 end
    engine.ForEachTraitTalent = function() return true end
    engine.HasDualSpec = function() return opts.dual or false end
    engine.bumps = 0
    engine.BumpScoringRevision = function(self) self.bumps = self.bumps + 1 end
    engine.QueueBagOverlayRefresh = function() engine.bagRefresh = true end
    RXP_SGJ_Settings = { HideTooltips = false, ShowBagArrows = true }
    RXPCData = {}
    for _, f in ipairs({ "TalentResolver", "BuildCatalog", "TalentPath", "BuildState", "Options" }) do
        Stubs.loadAddonFile("ForeverBuilds/" .. f .. ".lua", { game = opts.game or "FOREVER" })
    end
    local optionsTable = { type = "group", args = {} }
    RXP_FB.Options.Inject(optionsTable)
    return optionsTable, engine
end

function T.test_injects_group_on_forever()
    local ot = setup()
    local g = ot.args.foreverBuild
    assert_eq(g.type, "group")
    assert_eq(g.name, "Forever Build")
    assert(g.args.activeBuild and g.args.otherBuild, "build selectors present")
end

function T.test_no_group_when_disabled()
    local ot = setup({ disabled = true })
    assert_eq(ot.args.foreverBuild, nil)
    local ot2 = setup({ game = "CLASSIC" })
    assert_eq(ot2.args.foreverBuild, nil)
end

function T.test_select_values_include_auto_and_builds()
    local ot = setup()
    local sel = ot.args.foreverBuild.args.activeBuild
    local values = sel.values()
    assert_eq(values.AUTO, "Automatic (gear only)")
    assert(values[CAT], "cat build listed")
    assert_eq(sel.sorting()[1], "AUTO")
    sel.set(nil, CAT)
    assert_eq(sel.get(), CAT)
    assert_eq(RXPCData.foreverBuilds[1], CAT)
end

function T.test_other_spec_selector_hidden_without_dual_spec()
    local ot = setup()
    assert_eq(ot.args.foreverBuild.args.otherBuild.hidden(), true)
    local ot2 = setup({ dual = true })
    assert_eq(ot2.args.foreverBuild.args.otherBuild.hidden(), false)
    ot2.args.foreverBuild.args.otherBuild.set(nil, CAT)
    assert_eq(RXPCData.foreverBuilds[2], CAT)
end

function T.test_toggle_writes_sgj_setting()
    local ot, engine = setup()
    local t = ot.args.foreverBuild.args.ShowBagArrows
    assert_eq(t.type, "toggle")
    assert_eq(t.get(), true)
    t.set(nil, false)
    assert_eq(RXP_SGJ_Settings.ShowBagArrows, false)
    assert_eq(engine.bumps, 1)
    assert_eq(engine.bagRefresh, true)
end

function T.test_hide_tooltips_inverted()
    local ot = setup()
    local t = ot.args.foreverBuild.args.HideTooltips
    assert_eq(t.name, "Show gear verdict in tooltips")
    assert_eq(t.get(), true)
    t.set(nil, false)
    assert_eq(RXP_SGJ_Settings.HideTooltips, true)
end

function T.test_mode_and_pvp_not_exposed()
    local ot = setup()
    local args = ot.args.foreverBuild.args
    assert_eq(args.Mode, nil)
    assert_eq(args.GearForPvP, nil)
    assert_eq(args.HideMinimap, nil)
end

return T
