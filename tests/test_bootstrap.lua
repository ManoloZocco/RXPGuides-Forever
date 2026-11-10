local Stubs = require("wow_stubs")
local T = {}

local function load(opts)
    RXP_SGJ_NS, RXP_FB, RXP_SGJ_DISABLED = nil, nil, nil
    local ctx = Stubs.install(opts)
    Stubs.loadAddonFile("ForeverBuilds/Bootstrap.lua", {})
    return ctx
end

function T.test_disabled_when_standalone_enabled()
    local ctx = load({ addonEnableState = 2, playerName = "Giorgia" })
    assert_eq(RXP_SGJ_DISABLED, true)
    assert_eq(ctx.modernArgs, { "SharpiesGearJudge", "Giorgia" })
    ctx.fire("PLAYER_LOGIN")
    assert_eq(ctx.printed, { "RestedXP Forever: Sharpie's Gear Judge standalone is enabled; disable it to use the built-in gear engine." })
    ctx.fire("PLAYER_LOGIN")
    assert_eq(#ctx.printed, 1, "warning printed once")
end

function T.test_enabled_when_absent()
    local ctx = load({ addonEnableState = 0 })
    assert_eq(RXP_SGJ_DISABLED, false)
    ctx.fire("PLAYER_LOGIN")
    assert_eq(ctx.printed, nil, "no warning")
end

function T.test_legacy_api_arg_order()
    local ctx = load({ legacyAddonApi = true, addonEnableState = 1, playerName = "Giorgia" })
    assert_eq(ctx.legacyArgs, { "Giorgia", "SharpiesGearJudge" })
    assert_eq(RXP_SGJ_DISABLED, true)
end

function T.test_namespaces_created()
    load({})
    assert_eq(type(RXP_SGJ_NS), "table")
    assert_eq(type(RXP_FB), "table")
end

return T
