-- RestedXP Forever fork: a build's talent order as one step per level (first point at 10).
RXP_FB = RXP_FB or {}
local P = {}
RXP_FB.TalentPath = P

local FIRST_TALENT_LEVEL = 10
local UPCOMING = 3

-- steps[i] = { level, spellID, name, rank (cumulative for that spell), maxRank, tab, nodeID, resolved }
function P.Build(build, resolve)
    local steps, warnings, cum = {}, {}, {}
    local order = build and build.order or {}
    for i = 1, #order, 2 do
        local spellID, ranks = order[i], order[i + 1]
        local entry = resolve and resolve(spellID)
        for _ = 1, ranks do
            cum[spellID] = (cum[spellID] or 0) + 1
            local level = FIRST_TALENT_LEVEL + #steps
            local name = entry and entry.name
                or (RXP_FB.TalentResolver and RXP_FB.TalentResolver.SpellName(spellID))
                or ("spell " .. spellID)
            steps[#steps + 1] = {
                level = level, spellID = spellID, name = name, rank = cum[spellID],
                maxRank = entry and entry.maxRank, tab = entry and entry.tab,
                nodeID = entry and entry.nodeID, resolved = entry ~= nil,
            }
            if not entry then warnings[#warnings + 1] = "UNRESOLVED " .. spellID .. " at level " .. level end
        end
    end
    return steps, warnings
end

-- available: not-yet-taken steps up to playerLevel; upcoming: the next few after it.
function P.Pending(steps, playerLevel, currentRank)
    local available, upcoming = {}, {}
    for _, step in ipairs(steps or {}) do
        if (currentRank(step.spellID) or 0) < step.rank then
            if step.level <= playerLevel then
                available[#available + 1] = step
            elseif #upcoming < UPCOMING then
                upcoming[#upcoming + 1] = step
            end
        end
    end
    return available, upcoming
end

function P.FormatStep(step, class)
    local ranks = step.maxRank and (step.rank .. "/" .. step.maxRank) or tostring(step.rank)
    local text = "Lv " .. step.level .. ": " .. step.name .. " (" .. ranks .. ")"
    if step.tab and RXP_FB.TalentResolver then
        text = text .. " – " .. RXP_FB.TalentResolver.TreeName(class, step.tab)
    end
    if not step.resolved then text = text .. " [not found]" end
    return text
end
