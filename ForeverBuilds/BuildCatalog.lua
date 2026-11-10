-- RestedXP Forever fork: the leveling builds of a class, from the embedded engine's
-- MSC.BuildMatch rows { stage, role, endgame, priority, { spellID, ranks, ... } }.
-- Only stage-1 (leveling) rows are builds; stage-0 rows are level-60 builds.
RXP_FB = RXP_FB or {}
local C = {}
RXP_FB.BuildCatalog = C

local FULL_POINTS = 51
local LEVELING_PVP_PRIORITY = 51 -- every stage-1 row with this priority is a leveling-PvP build

-- Name of a leveling role from the engine's PrettyNames band keys ("<role>_<lo>_<hi>").
local function RoleLabel(prettyNames, role)
    local bestLo, label = -1, nil
    for key, name in pairs(prettyNames or {}) do
        local r, lo = key:match("^(.-)_(%d+)_%d+$")
        if r == role and tonumber(lo) > bestLo and type(name) == "string" then
            bestLo, label = tonumber(lo), name
        end
    end
    if not label then return role end
    return (label:gsub("%s*%(%d+%-%d+%)%s*$", ""))
end

local function MainTab(order, treeOf)
    local perTab, best, bestPts = {}, nil, 0
    for i = 1, #order, 2 do
        local tab = treeOf and treeOf(order[i])
        if tab then
            perTab[tab] = (perTab[tab] or 0) + order[i + 1]
            if perTab[tab] > bestPts or (perTab[tab] == bestPts and tab < best) then
                best, bestPts = tab, perTab[tab]
            end
        end
    end
    return best
end

function C.List(classToken, buildMatch, prettyNames, treeOf, treeNameOf)
    local builds, seenId, seenLabel = {}, {}, {}
    for _, row in ipairs(buildMatch or {}) do
        if row[1] == 1 then
            local role, endgame, priority, order = row[2], row[3], row[4], row[5]
            local points = 0
            for i = 2, #order, 2 do points = points + order[i] end

            local id = role .. "|" .. endgame .. "|" .. priority
            seenId[id] = (seenId[id] or 0) + 1
            if seenId[id] > 1 then id = id .. "|" .. seenId[id] end

            local mainTab = MainTab(order, treeOf)
            local base = RoleLabel(prettyNames, role)
            if mainTab then
                base = base .. " – " .. ((treeNameOf and treeNameOf(mainTab)) or ("Tree " .. mainTab))
            end
            local pvp = (endgame:find("PVP") ~= nil) or priority == LEVELING_PVP_PRIORITY
            if pvp and not endgame:find("PVP") then base = base .. " (PvP)" end
            seenLabel[base] = (seenLabel[base] or 0) + 1
            local label = base
            if seenLabel[base] > 1 then label = label .. " (variant " .. seenLabel[base] .. ")" end
            local complete = points == FULL_POINTS
            if not complete then label = label .. " (incomplete: " .. points .. "/" .. FULL_POINTS .. ")" end

            builds[#builds + 1] = {
                id = id, role = role, endgame = endgame, pvp = pvp, priority = priority,
                order = order, points = points, complete = complete, mainTab = mainTab, label = label,
                class = classToken,
            }
        end
    end
    return builds
end

function C.Find(builds, id)
    for _, b in ipairs(builds or {}) do
        if b.id == id then return b end
    end
    return nil
end
