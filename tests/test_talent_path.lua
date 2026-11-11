local Stubs = require("wow_stubs")
local T = {}

local INDEX = {
    [16934] = { name = "Ferocity", tab = 2, nodeID = 101, maxRank = 5, rank = 0 },
    [17056] = { name = "Furor", tab = 3, nodeID = 102, maxRank = 5, rank = 0 },
}
local function resolve(id) return INDEX[id] end

local function load()
    RXP_FB = {}
    Stubs.install({ spells = { [99999] = "Mystery Talent" } })
    Stubs.loadAddonFile("ForeverBuilds/TalentResolver.lua", {})
    Stubs.loadAddonFile("ForeverBuilds/TalentPath.lua", {})
    return RXP_FB.TalentPath
end

local function build(order)
    local points = 0
    for i = 2, #order, 2 do points = points + order[i] end
    return { id = "test", order = order, points = points, class = "DRUID" }
end

function T.test_path_levels_start_at_10()
    local P = load()
    local steps = P.Build(build({ 16934, 5, 17056, 5 }), resolve)
    assert_eq(#steps, 10)
    assert_eq(steps[1].level, 10)
    assert_eq(steps[10].level, 19)
    assert_eq(steps[1], { level = 10, spellID = 16934, name = "Ferocity", rank = 1, maxRank = 5, tab = 2, nodeID = 101, resolved = true })
end

function T.test_rank_accumulates_across_blocks()
    local P = load()
    local steps = P.Build(build({ 17056, 3, 16934, 1, 17056, 1 }), resolve)
    local got = {}
    for i, s in ipairs(steps) do got[i] = s.spellID .. ":" .. s.rank end
    assert_eq(got, { "17056:1", "17056:2", "17056:3", "16934:1", "17056:4" })
end

function T.test_unresolved_keeps_alignment()
    local P = load()
    local steps, warnings = P.Build(build({ 16934, 1, 99999, 1, 17056, 1 }), resolve)
    assert_eq(#steps, 3)
    assert_eq(steps[2].resolved, false)
    assert_eq(steps[2].name, "Mystery Talent")
    assert_eq(steps[2].level, 11)
    assert_eq(steps[3].level, 12)
    assert_eq(steps[3].resolved, true)
    assert_eq(warnings, { "UNRESOLVED 99999 at level 11" })
    local steps2 = P.Build(build({ 88888, 1 }), resolve)
    assert_eq(steps2[1].name, "spell 88888")
end

function T.test_pending_available_and_upcoming()
    local P = load()
    local steps = P.Build(build({ 16934, 5, 17056, 5 }), resolve)
    local ranks = { [16934] = 3 }
    local available, upcoming = P.Pending(steps, 14, function(id) return ranks[id] or 0 end)
    assert_eq(#available, 2)
    assert_eq(available[1].level, 13)
    assert_eq(available[2].level, 14)
    assert_eq(#upcoming, 3)
    assert_eq(upcoming[1].level, 15)
    assert_eq(upcoming[3].level, 17)
end

function T.test_pending_below_10_is_empty()
    local P = load()
    local steps = P.Build(build({ 16934, 5 }), resolve)
    local available, upcoming = P.Pending(steps, 5, function() return 0 end)
    assert_eq(#available, 0)
    assert_eq(#upcoming, 3)
    assert_eq(upcoming[1].level, 10)
end

function T.test_format_step()
    local P = load()
    local steps = P.Build(build({ 16934, 4, 99999, 1 }), resolve)
    assert_eq(P.FormatStep(steps[4], "DRUID"), "Lv 13: Ferocity (4/5) – Feral Combat")
    assert_eq(P.FormatStep(steps[5], "DRUID"), "Lv 14: Mystery Talent (1) [not found]")
end

return T
