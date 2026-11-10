local Stubs = require("wow_stubs")
local T = {}

local function load()
    RXP_FB = {}
    Stubs.install({})
    Stubs.loadAddonFile("ForeverBuilds/BuildCatalog.lua", {})
    return RXP_FB.BuildCatalog
end

local function realBuildMatch()
    RXP_SGJ_DISABLED = false
    RXP_SGJ_NS = { IsForever = true }
    Stubs.loadAddonFile("SGJ/Data/BuildMatch_Forever.lua", {})
    return RXP_SGJ_NS.BuildMatch
end

-- 51 points spread over 3 tabs: tab of a spell = spellID // 100
local function order51(first)
    local o = {}
    for i = 1, 10 do o[#o + 1] = first + i; o[#o + 1] = 5 end -- 50 points
    o[#o + 1] = first + 50; o[#o + 1] = 1
    return o
end
local function treeOf(id) return math.floor(id / 100) end
local PRETTY = {
    Leveling_1_10 = "Leveling (1-10)",
    Leveling_11_20 = "Feral Cat: Solo Leveling (11-20)",
    Leveling_52_59 = "Feral Cat: Solo Leveling (52-59)",
    Leveling_Bear_11_20 = "Bear: Dungeon Leveling (11-20)",
}
local NAMES = { "Balance", "Feral Combat", "Restoration" }
local function treeNameOf(tab) return NAMES[tab] end

local ROWS = {
    { 1, "Leveling", "CAT_RAID", 10, order51(200) },
    { 0, "Leveling", "CAT_RAID", 61, order51(200) },
    { 1, "Leveling_Bear", "BEAR_RAID", 31, order51(200) },
    { 1, "Leveling_Bear", "BEAR_RAID", 51, order51(200) },
    { 1, "Leveling_Caster", "BALANCE_RAID", 11, { 101, 5, 102, 5, 103, 5, 104, 5, 105, 5, 106, 5, 107, 5, 108, 4 } },
    { 1, "Leveling_Unnamed", "X_RAID", 12, order51(300) },
    { 1, "Leveling_Unnamed", "X_RAID", 13, order51(300) },
}

function T.test_only_leveling_stage_rows()
    local C = load()
    local builds = C.List("DRUID", ROWS, PRETTY, treeOf, treeNameOf)
    assert_eq(#builds, 6)
    for _, b in ipairs(builds) do assert(b.priority ~= 61, "stage 0 row excluded") end
end

function T.test_points_and_complete()
    local C = load()
    local builds = C.List("DRUID", ROWS, PRETTY, treeOf, treeNameOf)
    assert_eq(builds[1].points, 51)
    assert_eq(builds[1].complete, true)
    assert_eq(builds[1].label, "Feral Cat: Solo Leveling – Feral Combat")
    local caster = C.Find(builds, "Leveling_Caster|BALANCE_RAID|11")
    assert_eq(caster.points, 39)
    assert_eq(caster.complete, false)
    assert_eq(caster.label, "Leveling_Caster – Balance (incomplete: 39/51)")
end

function T.test_pvp_flag_from_endgame()
    local C = load()
    local rows = { { 1, "Leveling", "FERAL_PVP", 12, order51(200) }, ROWS[1], ROWS[4] }
    local builds = C.List("DRUID", rows, PRETTY, treeOf, treeNameOf)
    assert_eq(builds[1].pvp, true)
    assert_eq(builds[2].pvp, false)
    assert_eq(builds[3].pvp, true, "priority 51 = leveling PvP")
    assert_eq(builds[3].label, "Bear: Dungeon Leveling – Feral Combat (PvP)")
end

function T.test_duplicate_labels_get_variant_suffix()
    local C = load()
    local builds = C.List("DRUID", ROWS, PRETTY, treeOf, treeNameOf)
    assert_eq(builds[5].label, "Leveling_Unnamed – Restoration")
    assert_eq(builds[6].label, "Leveling_Unnamed – Restoration (variant 2)")
end

function T.test_ids_unique()
    local C = load()
    local rows = { ROWS[1], ROWS[1], ROWS[3] }
    local builds = C.List("DRUID", rows, PRETTY, treeOf, treeNameOf)
    assert_eq(builds[1].id, "Leveling|CAT_RAID|10")
    assert_eq(builds[2].id, "Leveling|CAT_RAID|10|2")
    assert_eq(builds[3].id, "Leveling_Bear|BEAR_RAID|31")
end

function T.test_find_by_id()
    local C = load()
    local builds = C.List("DRUID", ROWS, PRETTY, treeOf, treeNameOf)
    assert_eq(C.Find(builds, "Leveling_Bear|BEAR_RAID|31").role, "Leveling_Bear")
    assert_eq(C.Find(builds, "nope"), nil)
end

function T.test_without_tree_resolution()
    local C = load()
    local builds = C.List("DRUID", { ROWS[1] }, {}, function() return nil end)
    assert_eq(builds[1].mainTab, nil)
    assert_eq(builds[1].label, "Leveling")
end

function T.test_real_druid_rows()
    local C = load()
    local bm = realBuildMatch()
    local builds = C.List("DRUID", bm.DRUID, {}, function() return nil end)
    local cat = C.Find(builds, "Leveling|CAT_RAID|10")
    assert(cat, "druid solo cat build present")
    assert_eq(cat.points, 51)
    assert_eq(cat.complete, true)
    assert_eq(#builds, 10, "druid stage-1 rows")
end

function T.test_all_classes_structurally_valid()
    local C = load()
    local bm = realBuildMatch()
    local incomplete = {}
    for class, rows in pairs(bm) do
        for _, row in ipairs(rows) do
            if row[1] == 1 then
                local order = row[5]
                assert(#order % 2 == 0, class .. " odd order length")
                local cum, points = {}, 0
                for i = 1, #order, 2 do
                    local id, r = order[i], order[i + 1]
                    assert(r >= 1 and r <= 5, class .. " rank out of range " .. tostring(r))
                    cum[id] = (cum[id] or 0) + r
                    assert(cum[id] <= 5, class .. " cumulative rank > 5 for " .. id)
                    points = points + r
                end
                assert(points <= 51, class .. " more than 51 points")
            end
        end
        for _, b in ipairs(C.List(class, rows, {}, function() return nil end)) do
            if not b.complete then incomplete[#incomplete + 1] = class .. " " .. b.id .. " " .. b.points end
        end
    end
    table.sort(incomplete)
    io.stdout:write("  incomplete builds: " .. #incomplete .. "\n")
    for _, line in ipairs(incomplete) do io.stdout:write("    " .. line .. "\n") end
end

return T
