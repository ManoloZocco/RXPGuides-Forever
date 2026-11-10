local Stubs = require("wow_stubs")
local T = {}

local NODES = {
    { "Ferocity", 2, 2, { ID = 101, maxRanks = 5 }, 16934 },
    { "Furor", 0, 3, { ID = 102, maxRanks = 5 }, 17056 },
    { "Improved Wrath", 1, 1, { ID = 103, maxRanks = 5 }, 16814 },
}

local function forEach(fn)
    for _, n in ipairs(NODES) do fn(n[1], n[2], n[3], n[4], n[5]) end
    return true
end

local function load(opts)
    RXP_FB = {}
    Stubs.install(opts or {})
    Stubs.loadAddonFile("ForeverBuilds/TalentResolver.lua", {})
    return RXP_FB.TalentResolver
end

function T.test_index_by_spell_and_name()
    local R = load()
    local index = R.BuildIndex(forEach)
    assert_eq(index.bySpell[16934], { name = "Ferocity", tab = 2, nodeID = 101, maxRank = 5, rank = 2 })
    assert_eq(index.byName["furor"].nodeID, 102)
end

function T.test_resolve_by_spell_id()
    local R = load()
    local index = R.BuildIndex(forEach)
    assert_eq(R.Resolve(index, 16814).name, "Improved Wrath")
end

function T.test_resolve_falls_back_to_name()
    -- 999 is another rank/spell ID of Ferocity: found by its name
    local R = load({ spells = { [999] = "Ferocity" }, noGetSpellInfo = true })
    local index = R.BuildIndex(forEach)
    assert_eq(R.Resolve(index, 999).nodeID, 101)
end

function T.test_resolve_unknown_returns_nil()
    local R = load({ spells = { [555] = "Not A Talent" } })
    local index = R.BuildIndex(forEach)
    assert_eq(R.Resolve(index, 555), nil)
    assert_eq(R.Resolve(index, 777), nil)
end

function T.test_no_trait_config_returns_nil()
    local R = load()
    assert_eq(R.BuildIndex(function() return false end), nil)
    assert_eq(R.BuildIndex(nil), nil)
end

function T.test_tree_names_all_classes()
    local R = load()
    local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
    for _, c in ipairs(classes) do
        assert_eq(#R.TREE_NAMES[c], 3, c)
    end
    assert_eq(R.TreeName("DRUID", 2), "Feral Combat")
    assert_eq(R.TreeName("DRUID", 9), "Tree 9")
    assert_eq(R.TreeName("NOPE", 1), "Tree 1")
end

return T
