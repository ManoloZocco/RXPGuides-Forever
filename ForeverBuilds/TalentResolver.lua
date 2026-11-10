-- RestedXP Forever fork: find a build's talents on the Forever talent tree.
-- Forever has no Classic talent API; talents are C_Traits nodes, read through the
-- embedded engine's MSC.ForEachTraitTalent(fn, group) -> fn(name, rank, tab, node, spellID).
RXP_FB = RXP_FB or {}
local R = {}
RXP_FB.TalentResolver = R

-- Classic tree names in Classic tab order (Forever keeps that order for its node groups).
R.TREE_NAMES = {
    WARRIOR = { "Arms", "Fury", "Protection" },
    PALADIN = { "Holy", "Protection", "Retribution" },
    HUNTER = { "Beast Mastery", "Marksmanship", "Survival" },
    ROGUE = { "Assassination", "Combat", "Subtlety" },
    PRIEST = { "Discipline", "Holy", "Shadow" },
    SHAMAN = { "Elemental", "Enhancement", "Restoration" },
    MAGE = { "Arcane", "Fire", "Frost" },
    WARLOCK = { "Affliction", "Demonology", "Destruction" },
    DRUID = { "Balance", "Feral Combat", "Restoration" },
}

function R.TreeName(class, tab)
    local names = R.TREE_NAMES[class]
    return (names and names[tab]) or ("Tree " .. tostring(tab))
end

function R.SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name and name ~= "" then return name end
    end
    if GetSpellInfo then
        local name = GetSpellInfo(spellID)
        if name and name ~= "" then return name end
    end
    return nil
end

-- index.bySpell[spellID] / index.byName[lowercase name] = { name, tab, nodeID, maxRank, rank }
function R.BuildIndex(forEach)
    if type(forEach) ~= "function" then return nil end
    local index = { bySpell = {}, byName = {} }
    local ok = forEach(function(name, rank, tab, node, spellID)
        local entry = {
            name = name,
            tab = tab,
            nodeID = node and node.ID,
            maxRank = node and node.maxRanks,
            rank = tonumber(rank) or 0,
        }
        if spellID then index.bySpell[spellID] = entry end
        if name then index.byName[name:lower()] = entry end
    end)
    if ok == false then return nil end
    return index
end

function R.Resolve(index, spellID)
    if not index or not spellID then return nil end
    local entry = index.bySpell[spellID]
    if entry then return entry end
    local name = R.SpellName(spellID)
    return name and index.byName[name:lower()] or nil
end
