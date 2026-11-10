local Stubs = require("wow_stubs")
local T = {}

local CAT = "Leveling|CAT_RAID|10"
local BEAR = "Leveling_Bear|BEAR_RAID|31"

local function setup(opts)
    opts = opts or {}
    RXP_FB = {}
    RXP_SGJ_DISABLED = false
    RXP_SGJ_NS = { IsForever = true }
    local ctx = Stubs.install({ class = "DRUID", level = opts.level or 20 })
    Stubs.loadAddonFile("SGJ/Data/BuildMatch_Forever.lua", {})
    local engine = RXP_SGJ_NS
    engine.PrettyNames = {}
    engine.roleCalls = {}
    engine.SetTalentBuildRole = function(l, e, p) engine.roleCalls[#engine.roleCalls + 1] = { l, e, p } end
    engine.GetActiveSpecGroup = function() return opts.group or 1 end
    engine.ForEachTraitTalent = function(fn) return true end
    RXPCData = opts.saved and { foreverBuilds = opts.saved } or {}
    for _, f in ipairs({ "TalentResolver", "BuildCatalog", "TalentPath", "BuildState" }) do
        Stubs.loadAddonFile("ForeverBuilds/" .. f .. ".lua", {})
    end
    local ui = { calls = {} }
    ui.Update = function(build, steps, warnings, reason, currentRank)
        ui.calls[#ui.calls + 1] = { build = build, steps = steps, warnings = warnings, reason = reason, currentRank = currentRank }
    end
    RXP_FB.TalentGuideUI = ui
    return RXP_FB.BuildState, engine, ui, ctx
end

function T.test_default_is_auto()
    local S = setup()
    assert_eq(S.Get(1), "AUTO")
    assert_eq(S.Get(2), "AUTO")
end

function T.test_set_persists_per_group()
    local S = setup()
    S.Set(1, CAT)
    S.Set(2, BEAR)
    assert_eq(S.Get(1), CAT)
    assert_eq(S.Get(2), BEAR)
    assert_eq(RXPCData.foreverBuilds, { [1] = CAT, [2] = BEAR })
end

function T.test_unknown_build_falls_back_to_auto()
    local S = setup({ saved = { [1] = "Gone|OLD_RAID|10" } })
    assert_eq(S.Get(1), "AUTO")
    assert_eq(RXPCData.foreverBuilds[1], nil)
end

function T.test_apply_auto_clears_role()
    local S, engine, ui = setup()
    S.Apply()
    assert_eq(engine.roleCalls, { {} }, "SetTalentBuildRole(nil, nil, nil)")
    assert_eq(#ui.calls, 1)
    assert_eq(ui.calls[1].build, nil)
end

function T.test_apply_build_sets_role_and_updates_ui()
    local S, engine, ui = setup()
    S.Set(1, CAT)
    local last = engine.roleCalls[#engine.roleCalls]
    assert_eq(last, { "Leveling", "CAT_RAID", false })
    local call = ui.calls[#ui.calls]
    assert_eq(call.build.id, CAT)
    assert_eq(#call.steps, 51)
    assert_eq(type(call.currentRank), "function")
end

function T.test_apply_passes_reason()
    local S, _, ui = setup()
    S.Set(1, CAT)
    S.Apply("levelup")
    assert_eq(ui.calls[#ui.calls].reason, "levelup")
end

function T.test_other_group_role_for_tooltip()
    local S = setup()
    S.Set(2, BEAR)
    assert_eq(S.RoleFor(2), { leveling = "Leveling_Bear", endgame = "BEAR_RAID" })
    assert_eq(S.RoleFor(1), nil)
end

function T.test_active_group_two_uses_its_build()
    local S, engine = setup({ group = 2 })
    S.Set(1, CAT)
    S.Set(2, BEAR)
    S.Apply()
    assert_eq(engine.roleCalls[#engine.roleCalls], { "Leveling_Bear", "BEAR_RAID", false })
end

function T.test_init_hooks_engine_and_events()
    local S, engine, ui, ctx = setup()
    S.Init()
    assert_eq(type(engine.GetTalentBuildRoleForGroup), "function")
    S.Set(2, BEAR)
    assert_eq(engine.GetTalentBuildRoleForGroup(2).leveling, "Leveling_Bear")
    local before = #ui.calls
    ctx.fire("PLAYER_LEVEL_UP", 21)
    assert_eq(#ui.calls, before + 1)
    assert_eq(ui.calls[#ui.calls].reason, "levelup")
end

function T.test_init_noop_when_disabled()
    local S, engine = setup()
    RXP_SGJ_DISABLED = true
    S.Init()
    assert_eq(engine.GetTalentBuildRoleForGroup, nil)
end

return T
