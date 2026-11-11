if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
_G.MSC = MSC 

-- [[ SPEED OPTIMIZATION: LOCALIZED FUNCTIONS ]]
local pairs, next = pairs, next
local tonumber = tonumber

local GetNumTalentTabs = GetNumTalentTabs
local GetNumTalents = GetNumTalents
local GetTalentInfo = GetTalentInfo
local GetTalentTabInfo = GetTalentTabInfo
local C_SpecializationInfo = C_SpecializationInfo
local UnitClass = UnitClass
local CreateFrame = CreateFrame
local C_Timer = C_Timer

-- =========================================================================
-- 1. TALENT CACHING SYSTEM 
-- =========================================================================
MSC.TalentCache = {}
MSC.TalentCacheLoaded = false

MSC.CachedWeights = nil
MSC.CachedSpecKey = nil
MSC.CachedWeightsBySpec = {}
MSC.ScoringRevision = 0
MSC.EquippedSlotScoreCache = {}

function MSC:BumpScoringRevision()
    MSC.ScoringRevision = (MSC.ScoringRevision or 0) + 1
    MSC.CachedWeights = nil
    MSC.CachedSpecKey = nil
    MSC.CachedCapText = nil
    if MSC.CachedWeightsBySpec then wipe(MSC.CachedWeightsBySpec) end
    if MSC.EquippedSlotScoreCache then wipe(MSC.EquippedSlotScoreCache) end
    if MSC.ProcessedStatCache then wipe(MSC.ProcessedStatCache) end
    if MSC.ColorMatchCache then wipe(MSC.ColorMatchCache) end
    if MSC.EvaluationCache then wipe(MSC.EvaluationCache) end
    if MSC.UsableCache then wipe(MSC.UsableCache) end
    -- Weights (and set bonus scores) are rebuilt lazily by GetCurrentWeights.
end

-- Imported (Pawn / Sixty Upgrades) weights saved before 3.2.1 kept the
-- importer's stat keys, e.g. MSC_WEAPON_DPS, which Forever items never carry
-- (their DPS is ITEM_MOD_DAMAGE_PER_SECOND_SHORT), so that weight scored
-- nothing. Add each alias's weight under the key items use, keeping the
-- original too. Memoized per saved table (weak keys).
local normalizedCustom = setmetatable({}, { __mode = "k" })
local function NormalizeCustomWeights(raw)
    if type(raw) ~= "table" or not MSC.NormalizeStatKey then return raw end
    local cached = normalizedCustom[raw]
    if cached then return cached end
    local out, changed = {}, false
    for k, v in pairs(raw) do
        if out[k] == nil then out[k] = v end
        local nk = MSC.NormalizeStatKey(k)
        if nk ~= k and type(v) == "number" then
            changed = true
            if raw[nk] == nil and (type(out[nk]) ~= "number" or math.abs(v) > math.abs(out[nk])) then out[nk] = v end
        end
    end
    local result = changed and out or raw
    normalizedCustom[raw] = result
    return result
end

-- WoW Forever leveling rows blend toward the level-60 profile from 50 (90% profile at 59), and the 60 profiles carry
-- their talents already, so the class modules' leveling talent hooks fade out with the blend (2026-10-23, Mage deep dive
-- D5): from 50 each weight keeps only the leveling share of what the hooks changed, 1 at 50 down to 0 at 60. The cap
-- keys (hit, defense, expertise) keep the hooked value: the caps belong to the player's stats, not to the talents.
-- A class hook that scales hit as a talent multiplier (not a cap) fades it itself with MSC.LevelingHookShare.
function MSC.LevelingHookShare(level)
    level = level or UnitLevel("player") or 1
    if level <= 50 then return 1 end
    return math.max(0, (60 - level) / 10)
end

function MSC.FadeLevelingHooks(hooked, raw, specKey)
    if not (MSC.IsForever and raw and type(specKey) == "string" and specKey:find("^Leveling")) then return end
    local share = MSC.LevelingHookShare()
    if share >= 1 then return end
    for k, v in pairs(hooked) do
        local r = raw[k]
        if type(v) == "number" and type(r) == "number" and not (k:find("HIT") or k:find("DEFENSE") or k:find("EXPERTISE")) then
            hooked[k] = r + share * (v - r)
        end
    end
end

function MSC:ApplyWeightPipeline(rawWeights, specKey)
    -- Level-60 raid profiles slide toward their Tier 1 weights as the character's gear
    -- grows (WoW Forever, MSC.GearPointBlend); everything below runs on the result.
    if rawWeights and MSC.GearPointBlend then rawWeights = MSC.GearPointBlend(rawWeights) end
    local finalWeights = {}
    if rawWeights then
        for k, v in pairs(rawWeights) do finalWeights[k] = v end
    end
    local capText = nil
    -- PvP (the option, or a PvP profile): caps use the player-vs-player
    -- targets while the class hooks run, then the PvP model goes on top.
    local pvp = MSC.IsForever and (MSC.IsGearingForPvP() or MSC.IsPvPTalentBuild() or MSC.IsPvPProfile(specKey))
    if pvp then MSC.PvPPipelineSpec = specKey or true end
    if MSC.CurrentClass and MSC.CurrentClass.ApplyScalers then
        local ok, w, t = pcall(MSC.CurrentClass.ApplyScalers, MSC.CurrentClass, finalWeights, specKey)
        if not ok then MSC.PvPPipelineSpec = nil; error(w, 0) end
        finalWeights, capText = w, t
        MSC.FadeLevelingHooks(finalWeights, rawWeights, specKey)
    end
    if pvp then
        MSC.PvPPipelineSpec = nil
        local label = MSC.ApplyForeverPvP(finalWeights)
        if label then capText = capText and capText ~= "" and (capText .. ", " .. label) or label end
    end
    if MSC.BuffEngine and MSC.BuffEngine.ApplyStatSynergy then
        MSC.BuffEngine:ApplyStatSynergy(finalWeights, specKey)
    end
    return finalWeights, capText
end

function MSC:LookupRawWeights(profileName)
    if not profileName or not MSC.CurrentClass then return nil, profileName end
    local rawWeights, specKey, mathSpec = nil, profileName, nil

    if RXP_SGJ_DB and RXP_SGJ_DB.customWeights and RXP_SGJ_DB.customWeights[profileName] then
        local data = RXP_SGJ_DB.customWeights[profileName]
        if type(data) == "table" and data.weights then
            rawWeights = NormalizeCustomWeights(data.weights)
            if data.BaseSpec then mathSpec = data.BaseSpec end
        else
            rawWeights = NormalizeCustomWeights(data)
        end
    end

    if not rawWeights and MSC.CurrentClass.GetDynamicWeights then
        local dynWeights, dynKey = MSC.CurrentClass:GetDynamicWeights(profileName)
        if dynWeights then rawWeights = dynWeights; specKey = dynKey end
    end

    if not rawWeights then
        if MSC.CurrentClass.Weights and MSC.CurrentClass.Weights[profileName] then
            rawWeights = MSC.CurrentClass.Weights[profileName]
        elseif MSC.CurrentClass.LevelingWeights and MSC.CurrentClass.LevelingWeights[profileName] then
            rawWeights = MSC:GetLevelingRow(MSC.CurrentClass, profileName)
        elseif MSC.CurrentClass.Profiles and MSC.CurrentClass.Profiles[profileName] then
            rawWeights = MSC.CurrentClass.Profiles[profileName]
        elseif MSC.CurrentClass.LevelingBrackets and MSC.CurrentClass.LevelingBrackets[profileName] then
            rawWeights = MSC.CurrentClass.LevelingBrackets[profileName]
        end
        if not mathSpec and RXP_SGJ_DB and RXP_SGJ_DB.customWeights and RXP_SGJ_DB.customWeights[profileName] then
            local data = RXP_SGJ_DB.customWeights[profileName]
            if type(data) == "table" and data.BaseSpec then mathSpec = data.BaseSpec end
        end
    end

    return rawWeights, specKey, mathSpec
end

function MSC:GetProfileWeights(profileName)
    if not profileName then
        return MSC.GetCurrentWeights()
    end

    if MSC.CachedWeightsBySpec[profileName] then
        return MSC.CachedWeightsBySpec[profileName]
    end

    local rawWeights, specKey, mathSpec = MSC:LookupRawWeights(profileName)
    if not rawWeights then return nil end

    local finalWeights = select(1, MSC:ApplyWeightPipeline(rawWeights, mathSpec or specKey))
    MSC.CachedWeightsBySpec[profileName] = finalWeights
    return finalWeights, specKey
end

-- Talent names are matched ignoring case and spaces: Forever's patch notes and
-- data sites don't always agree on spacing ("Rage of the Farseer" vs "Rage of
-- the Far Seer"), and one exact-match miss silently breaks spec detection.
local function TalentKey(name)
    return (name:lower():gsub("%s+", ""))
end

-- Forever's client removed the Classic talent globals (GetNumTalents,
-- GetTalentInfo, and the tab/index form of GetTalentTabInfo) in favour of
-- C_SpecializationInfo, which exposes each talent tree as a "specialization".
-- Its GetTalentInfo has no talentIndex lookup there ("query.tier must be
-- specified"), so the tree is walked by tier/column grid position instead.
-- The grid bounds cover Classic/TBC trees (9 tiers x 4 columns) with room to
-- spare. Each call is pcall'd so an empty or invalid cell is skipped rather
-- than raising an error on every tooltip.
local MAX_TALENT_TIERS, MAX_TALENT_COLUMNS = 11, 4

-- Forever's talent window is the modern trait system (Blizzard_PlayerSpells,
-- Camelot overrides): one trait tree per class whose node groups are the
-- three Classic trees, in Classic tab order. Talents are trait nodes, read
-- from a spec group's config (the active one unless group is given). Returns
-- configID, treeID or nil (Classic Era / TBC have no class-talent trait
-- config and use the globals; a group never set up has no config).
local function GetTraitTalentConfig(forGroup)
    if not (C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then return nil end
    local configID
    local spec = C_SpecializationInfo
    if spec and spec.GetActiveSpecGroup and spec.GetCombatConfigIDForSpecGroup then
        local ok, group = true, forGroup
        if not group then ok, group = pcall(spec.GetActiveSpecGroup) end
        if ok and group then
            local ok2, id = pcall(spec.GetCombatConfigIDForSpecGroup, group)
            if ok2 then configID = id end
        end
    end
    if not configID and not forGroup and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
        if ok then configID = id end
    end
    if not configID then return nil end
    local ok, info = pcall(C_Traits.GetConfigInfo, configID)
    local treeID = ok and info and info.treeIDs and info.treeIDs[1]
    if not treeID then return nil end
    return configID, treeID
end

local function GetTraitNodeName(configID, node)
    local entryID = (node.activeEntry and node.activeEntry.entryID) or (node.entryIDs and node.entryIDs[1])
    if not entryID then return nil end
    local ok, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
    if not ok or not entry or not entry.definitionID then return nil end
    local okDef, def = pcall(C_Traits.GetDefinitionInfo, entry.definitionID)
    if not okDef or not def then return nil end
    local name = def.overrideName
    if (not name or name == "") and def.spellID then
        if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(def.spellID)
        elseif GetSpellInfo then name = GetSpellInfo(def.spellID) end
    end
    if name == "" then return nil end
    return name, def.spellID
end

-- Calls fn(name, rank, tab, node) for every named talent node in the trait
-- tree (node is the C_Traits node info: .ID, .maxRanks, ...). Returns false
-- when this client has no class-talent trait config. group: a spec group
-- (default: the active one).
function MSC.ForEachTraitTalent(fn, group)
    local configID, treeID = GetTraitTalentConfig(group)
    if not configID then return false end

    local tabOfGroup = {}
    local okD, displays = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    if okD and type(displays) == "table" then
        for i, d in ipairs(displays) do
            if d.groupID then tabOfGroup[d.groupID] = i end
        end
    end

    local okN, nodes = pcall(C_Traits.GetTreeNodes, treeID)
    if not okN or type(nodes) ~= "table" then return false end
    for _, nodeID in ipairs(nodes) do
        local okI, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if okI and type(node) == "table" and node.ID and node.ID ~= 0 then
            local name, spellID = GetTraitNodeName(configID, node)
            if name then
                local tab
                for _, groupID in ipairs(node.groupIDs or {}) do
                    if tabOfGroup[groupID] then tab = tabOfGroup[groupID]; break end
                end
                fn(name, tonumber(node.activeRank) or tonumber(node.ranksPurchased) or 0, tab, node, spellID)
            end
        end
    end
    return true
end

-- Calls fn(name, rank) for each talent in the tab; stops early if fn returns true.
function MSC.ForEachTalent(tab, fn)
    if MSC.TraitTalentData then
        for _, t in ipairs(MSC.TraitTalentData) do
            if t.tab == tab and fn(t.name, t.rank) then return end
        end
        return
    end
    if GetNumTalents then
        for i = 1, GetNumTalents(tab) or 0 do
            local name, _, _, _, rank = GetTalentInfo(tab, i)
            if name and fn(name, tonumber(rank) or 0) then return end
        end
        return
    end
    local getTalent = C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo
    if not getTalent then return end
    for tier = 1, MAX_TALENT_TIERS do
        for column = 1, MAX_TALENT_COLUMNS do
            local ok, info = pcall(getTalent, { specializationIndex = tab, tier = tier, column = column })
            if ok and type(info) == "table" and info.name
                and fn(info.name, tonumber(info.rank) or 0) then
                return
            end
        end
    end
end

function MSC.GetTabPointsSpent(tab)
    if not MSC.TalentCacheLoaded then MSC:BuildTalentCache() end
    if MSC.TraitTalentData then
        local total = 0
        for _, t in ipairs(MSC.TraitTalentData) do
            if t.tab == tab then total = total + t.rank end
        end
        return total
    end
    if GetNumTalents and GetTalentTabInfo then
        local _, _, _, _, pointsSpent = GetTalentTabInfo(tab)
        return tonumber(pointsSpent) or 0
    end
    local total = 0
    MSC.ForEachTalent(tab, function(_, rank) total = total + rank end)
    return total
end

function MSC:BuildTalentCache()
    MSC.TalentCache = {}
    MSC.TraitTalentData = nil

    -- Forever: read the trait tree (see GetTraitTalentConfig). Only used when
    -- it actually yields talents; otherwise fall through to the Classic path.
    local traitData = {}
    if MSC.ForEachTraitTalent(function(name, rank, tab, _, spellID)
        table.insert(traitData, { name = name, rank = rank, tab = tab, spellID = spellID })
    end) and #traitData > 0 then
        for _, t in ipairs(traitData) do
            local k = TalentKey(t.name)
            MSC.TalentCache[k] = math.max(MSC.TalentCache[k] or 0, t.rank)
        end
        MSC.TraitTalentData = traitData
        MSC.TalentCacheLoaded = true
        return
    end

    if not GetNumTalentTabs then
        MSC.TalentCacheLoaded = true
        return
    end

    local tabs = GetNumTalentTabs() or 0
    if tabs == 0 then return end

    for t = 1, tabs do
        MSC.ForEachTalent(t, function(name, rank)
            MSC.TalentCache[TalentKey(name)] = rank
        end)
    end
    MSC.TalentCacheLoaded = true
end

-- =========================================================================
-- 1b. DUAL SPECIALIZATION (the inactive spec group)
-- =========================================================================
-- A spec group's talents without touching the live cache: returns
-- talentCache, traitData (like MSC.TalentCache / MSC.TraitTalentData) or nil
-- when the group has no talents (never set up). Forever reads the group's
-- trait config; SoD and TBC Anniversary pass the group to GetTalentInfo.
local function ForEachClassicGroupTalent(fn, group)
    if MSC.IsForever or not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then return false end
    local spent = 0
    for tab = 1, GetNumTalentTabs() or 0 do
        for i = 1, GetNumTalents(tab) or 0 do
            local ok, name, _, _, _, rank = pcall(GetTalentInfo, tab, i, false, false, group)
            rank = ok and tonumber(rank) or 0
            if ok and name then fn(name, rank, tab); spent = spent + rank end
        end
    end
    return spent > 0
end

function MSC.ReadTalentsForGroup(group)
    local cache, data = {}, {}
    local function Add(name, rank, tab, _, spellID) table.insert(data, { name = name, rank = rank, tab = tab, spellID = spellID }) end
    if not MSC.ForEachTraitTalent(Add, group) or #data == 0 then
        wipe(data)
        if not ForEachClassicGroupTalent(Add, group) then return nil end
    end
    for _, t in ipairs(data) do
        local k = TalentKey(t.name)
        cache[k] = math.max(cache[k] or 0, t.rank)
    end
    return cache, data
end

-- Runs fn(...) as if spec group `group` were active: its talents, its manual
-- profile choice, its Talents-plugin build (MSC.GetTalentBuildRoleForGroup,
-- filled by the plugin) and its Gear for PvP (MSC.EvalSpecGroup). Everything
-- is restored afterwards, also on error. For the active group it just calls fn.
-- Returns nil when the other group's talents can't be read.
function MSC.WithSpecGroup(group, fn, ...)
    if not group or group == MSC.GetActiveSpecGroup() or MSC.EvalSpecGroup then return fn(...) end
    local cache, data = MSC.ReadTalentsForGroup(group)
    if not cache then return nil end
    local saved = {
        TalentCache = MSC.TalentCache, TraitTalentData = MSC.TraitTalentData, TalentCacheLoaded = MSC.TalentCacheLoaded,
        ManualSpec = MSC.ManualSpec, TalentBuildRole = MSC.TalentBuildRole, CachedSpecConfidence = MSC.CachedSpecConfidence,
    }
    MSC.TalentCache, MSC.TraitTalentData, MSC.TalentCacheLoaded = cache, data, true
    MSC.EvalSpecGroup = group
    MSC.ManualSpec = MSC.GetManualSpec(group)
    MSC.TalentBuildRole = MSC.GetTalentBuildRoleForGroup and MSC.GetTalentBuildRoleForGroup(group) or nil
    local res = { pcall(fn, ...) }
    MSC.TalentCache, MSC.TraitTalentData, MSC.TalentCacheLoaded = saved.TalentCache, saved.TraitTalentData, saved.TalentCacheLoaded
    MSC.ManualSpec, MSC.TalentBuildRole, MSC.CachedSpecConfidence = saved.ManualSpec, saved.TalentBuildRole, saved.CachedSpecConfidence
    MSC.EvalSpecGroup = nil
    if not res[1] then
        if MSC.Debug then print("|cff00ccffSGJ|r other-spec error:", res[2]) end
        return nil
    end
    return unpack(res, 2)
end

-- Weights and profile key for a spec group (the active one = GetCurrentWeights).
-- The other group's are rebuilt when scoring settings change or you level.
MSC.GroupWeightsCache = {}
function MSC:GetWeightsForGroup(group)
    if not group or group == MSC.GetActiveSpecGroup() then
        local w, key = MSC.GetCurrentWeights()
        return w, key
    end
    local stamp = (MSC.ScoringRevision or 0) .. "|" .. (UnitLevel("player") or 0)
    local c = MSC.GroupWeightsCache[group]
    if c and c.stamp == stamp then return c.weights, c.key end
    local w, key = MSC.WithSpecGroup(group, function() return MSC:ApplyDynamicAdjustments() end)
    if not w then return nil end
    MSC.GroupWeightsCache[group] = { stamp = stamp, weights = w, key = key }
    return w, key
end

-- Ranks by trait spell ID, rebuilt when the talent data changes (a spec group's data swaps in too).
local spellRanks, spellRanksFor = {}, nil

function MSC:GetTalentRank(talentKey)
    -- Scoring for another character (MSC.BonusContext): its saved ranks by key.
    local ctx = MSC.BonusContext
    if ctx and ctx.talentRanks then return ctx.talentRanks[talentKey] or 0 end
    if not MSC.CurrentClass or not MSC.CurrentClass.Talents then return 0 end

    if not MSC.TalentCacheLoaded then 
        self:BuildTalentCache() 
        if not MSC.TalentCacheLoaded then return 0 end
    end

    -- Forever: by the talent's spell ID first (Data/TalentSpellIDs_Forever.lua), so a talent Blizzard renames
    -- (Elemental Precision -> Precision at launch) or a client translates differently still reads.
    local ids = MSC.TalentSpellIDs and MSC.TalentSpellIDs[MSC.CurrentClass.Name]
    local sid = ids and ids[talentKey]
    local data = MSC.TraitTalentData
    if sid and data then
        if spellRanksFor ~= data then
            spellRanksFor = data
            wipe(spellRanks)
            for _, t in ipairs(data) do
                if t.spellID then spellRanks[t.spellID] = math.max(spellRanks[t.spellID] or 0, t.rank or 0) end
            end
        end
        local r = spellRanks[sid]
        if r then return r end
    end

    local localizedName = MSC.CurrentClass.Talents[talentKey]
    if not localizedName then return 0 end

    return MSC.TalentCache[TalentKey(localizedName)] or 0
end

-- Returns spec key from dominant talent tree when capstones are ambiguous.
-- tabMap: { [tabIndex] = "SPEC_KEY", ... }; margin = minimum point lead required.
function MSC:GetDominantTalentTree(tabMap, margin)
    if not tabMap then return nil, "ambiguous" end
    margin = margin or 5
    local maxPts, secondPts = 0, 0
    local maxTab = nil
    for tab, _ in pairs(tabMap) do
        local p = MSC.GetTabPointsSpent(tab)
        if p > maxPts then
            secondPts = maxPts
            maxPts = p
            maxTab = tab
        elseif p > secondPts then
            secondPts = p
        end
    end
    if maxTab and maxPts > 0 then
        if (maxPts - secondPts) >= margin then
            return tabMap[maxTab], "low"
        end
        return tabMap[maxTab], "ambiguous"
    end
    return nil, "ambiguous"
end

-- Leveling role detection (levels 11-59). Early levels only reach talent
-- tiers 1-3, and several common DPS leveling picks sit inside the tank/
-- healer trees (Paladin Divine Strength in Holy, Druid Furor in Restoration,
-- Priest Wand Specialization in Discipline), so raw tree points can't tell
-- the roles apart. Each class instead lists the "marker" talents only that
-- role would take (checked against Forever's talent data on
-- wowforevertools.com); a class's GetSpec falls back to its DPS bracket when
-- the matching role profile doesn't exist for the player's level:
--   roleMarkers = { [profilePrefix] = { "TALENT_KEY", ... }, ... }
-- Returns the prefix whose markers hold the most points, or nil if none/tied.
-- A build chosen in the Talents plugin names the leveling role and endgame
-- profile it is built for, so the weights follow the build even before its
-- marker talents are taken. leveling is a LowLevelRoles key (e.g.
-- "Leveling_Tank") or "Leveling" for the class's default chain; endgame is a
-- Weights key used at 60. pvp (optional) marks a PvP build: its weights get
-- the PvP model at every level, as with Gear for PvP. nil, nil clears it.
function MSC.SetTalentBuildRole(leveling, endgame, pvp)
    local cur = MSC.TalentBuildRole
    pvp = pvp and true or nil
    if (cur and cur.leveling) == leveling and (cur and cur.endgame) == endgame and (cur and cur.pvp) == pvp then return end
    MSC.TalentBuildRole = (leveling or endgame) and { leveling = leveling, endgame = endgame, pvp = pvp } or nil
    MSC.CachedWeights = nil
    if MSC.CachedWeightsBySpec then wipe(MSC.CachedWeightsBySpec) end
    -- A PvP build can share its profile key with the PvE one, so a PvP change
    -- wouldn't clear the cached item scores by itself: drop them all.
    if (cur and cur.pvp) ~= pvp and MSC.BumpScoringRevision then MSC:BumpScoringRevision() end
end

-- =========================================================================
-- 1c. NEAREST SHIPPED BUILD (WoW Forever)
-- =========================================================================
-- Single "marker" talents misread real builds (a Ret Paladin takes Healing
-- Light, a Cat Druid Thick Hide, a ranged Survival Hunter Deflection), so the
-- character's talents are matched to the shipped Talents builds instead
-- (Data/BuildMatch_Forever.lua, by spell ID): each build's first N points,
-- N = the points the character has spent, against the character's ranks.
-- The closest build names the leveling role and the level-60 profile, the
-- same way a build picked in the Talents plugin does. Below MATCH_MIN, or
-- when equally close builds disagree, nothing is forced and the class's own
-- detection decides. Talents can't tell solo from group play, so a dungeon
-- build's role counts as its solo role (dungeon rows are chosen by hand).
local MATCH_MIN = 0.6
local matchMemo, matchMemoKey = nil, nil

local function SoloRole(module, role)
    if role == "" or not role:find("Dungeon") then return role end
    local solo = role:gsub("Dungeon", ""):gsub("_$", "")
    -- only a role the class detects (Paladin's Leveling_Ret is the 52-59 tail of Leveling)
    if module.LowLevelRoles and module.LowLevelRoles[solo] then return solo end
    return "Leveling"
end

function MSC.MatchTalentBuild(level)
    local module, data = MSC.CurrentClass, MSC.TraitTalentData
    local list = module and MSC.BuildMatch and MSC.BuildMatch[module.Name]
    if not list or not data then return nil end
    local have, spent, sig = {}, 0, {}
    for _, t in ipairs(data) do
        if t.spellID and (t.rank or 0) > 0 then
            have[t.spellID] = (have[t.spellID] or 0) + t.rank
            spent = spent + t.rank
            sig[#sig + 1] = t.spellID .. ":" .. t.rank
        end
    end
    if spent == 0 then return nil end
    local endgame = level >= 60
    table.sort(sig)
    local memoKey = (endgame and "E" or "L") .. table.concat(sig, ",")
    if memoKey == matchMemoKey then return matchMemo end

    local bestSim, best = 0, {}
    for _, b in ipairs(list) do
        if endgame or b[1] == 1 then
            -- the build's first `spent` points (all of them at 60)
            local ranks, left, order = {}, endgame and math.huge or spent, b[5]
            for i = 1, #order, 2 do
                if left <= 0 then break end
                local n = math.min(order[i + 1], left)
                ranks[order[i]] = (ranks[order[i]] or 0) + n
                left = left - n
            end
            local overlap, total = 0, 0
            for id, r in pairs(ranks) do
                total = total + r
                overlap = overlap + math.min(r, have[id] or 0)
            end
            local sim = overlap / math.max(spent, total)
            if sim > bestSim + 1e-6 then bestSim, best = sim, { b }
            elseif sim > bestSim - 1e-6 then best[#best + 1] = b end
        end
    end
    local result
    if bestSim >= MATCH_MIN then
        -- a variant build (tie priority 100+, another weapon or play style of a tree) tied with a main build: the main
        -- build's role wins (they share their first points)
        local main = {}
        for _, b in ipairs(best) do
            if b[4] < 100 then main[#main + 1] = b end
        end
        if #main > 0 then best = main end
        local value
        for _, b in ipairs(best) do
            local v = endgame and b[3] or SoloRole(module, b[2])
            if value and v ~= value then value = nil; break end
            value = v
        end
        if value and value ~= "" then
            result = endgame and { endgame = value } or { leveling = value }
        end
    end
    matchMemo, matchMemoKey = result, memoKey
    return result
end

-- The build roles in force: a build picked in the Talents plugin, else the
-- nearest shipped build (WoW Forever).
function MSC.GetBuildRole()
    if MSC.TalentBuildRole then return MSC.TalentBuildRole end
    if not MSC.IsForever then return nil end
    return MSC.MatchTalentBuild(UnitLevel("player") or 0)
end

function MSC:GetLowLevelRole(roleMarkers)
    if not roleMarkers then return nil end
    local forced = (MSC.GetBuildRole() or {}).leveling
    if forced then
        if roleMarkers[forced] then return forced end
        if forced == "Leveling" then return nil end
    end
    local bestRole, bestPts, tied = nil, 0, false
    for role, keys in pairs(roleMarkers) do
        local pts = 0
        for _, key in ipairs(keys) do pts = pts + self:GetTalentRank(key) end
        if pts > bestPts then
            bestRole, bestPts, tied = role, pts, false
        elseif pts > 0 and pts == bestPts then
            tied = true
        end
    end
    if tied then return nil end
    return bestRole
end

-- Forever leveling blend (TBC-style smooth weights). Each LevelingWeights row
-- "<role>_<lo>_<hi>" holds the weights at level <lo>; between <lo> and the
-- next band's start the weights slide linearly toward that band's row (same
-- role, or the module's LevelingNext[key] when the chain changes name, e.g.
-- Paladin Leveling_41_51 -> Leveling_Ret_52_59). A role's last band holds
-- flat. Levels outside the band clamp, so previewing another band's profile
-- shows its start (below) or end (above) weights. Era/TBC rows pass through.
local function ParseLevelingBand(key)
    local role, lo, hi = string.match(key, "^(Leveling.-)_(%d+)_(%d+)$")
    return role, tonumber(lo), tonumber(hi)
end

-- Forever per-spec curves (Classes/Forever/Curves/<Class>_Curves.lua): an ordered
-- list of { level, weights } keyframes. Linear between keyframes, flat
-- outside them. A stat missing from one keyframe counts as 0 there; explicit
-- 0s are kept in the result (MSC_WEAPON_DPS_MELEE = 0 is an override), and a
-- blended value that lands in the scorer's 0-0.02 "useless" band becomes 0.
function MSC.EvaluateLevelingCurve(curve, level)
    local n = #curve
    if n == 0 then return {} end
    local a, b = curve[1], curve[n]
    if level <= a[1] then b = a
    elseif level >= b[1] then a = b
    else
        for i = 1, n - 1 do
            if level >= curve[i][1] and level <= curve[i + 1][1] then a, b = curve[i], curve[i + 1]; break end
        end
    end
    local t = (b[1] > a[1]) and ((level - a[1]) / (b[1] - a[1])) or 0
    local out = {}
    local function put(stat)
        if out[stat] ~= nil then return end
        local va, vb = a[2][stat] or 0, b[2][stat] or 0
        local v = va + (vb - va) * t
        if v > 0 and v < 0.02 then v = 0 end
        out[stat] = v
    end
    for stat in pairs(a[2]) do put(stat) end
    for stat in pairs(b[2]) do put(stat) end
    return out
end

function MSC:GetLevelingRow(module, key)
    local rows = module and module.LevelingWeights
    local row = rows and rows[key]
    if not row or not MSC.IsForever then return row end

    local role, lo, hi = ParseLevelingBand(key)
    if not role then return row end

    -- Per-spec curve: weights at the player's level, held inside the chosen
    -- band so previewing another band's profile shows that band's weights.
    local curves = module.LevelingCurves
    local curveRole = (curves and curves[role]) and role or (MSC.LevelingCurveAlias and MSC.LevelingCurveAlias[role])
    local curve = curves and curveRole and curves[curveRole]
    if curve then
        local level = UnitLevel("player")
        if level < lo then level = lo elseif level > hi then level = hi end
        -- then slid toward the role's quest-gear row by the worn gear (MSC.LevelingGearBlend)
        local gear = module.LevelingGear and module.LevelingGear[curveRole]
        return (MSC.LevelingGearBlend(gear, level, MSC.EvaluateLevelingCurve(curve, level)))
    end

    local nextKey = module.LevelingNext and module.LevelingNext[key]
    local nextLo = nextKey and rows[nextKey] and select(2, ParseLevelingBand(nextKey))
    if not nextLo then
        nextKey = nil
        for k in pairs(rows) do
            local r, l = ParseLevelingBand(k)
            if r == role and l and l > lo and (not nextLo or l < nextLo) then nextKey, nextLo = k, l end
        end
    end
    if not nextKey then return row end

    local t = (UnitLevel("player") - lo) / (nextLo - lo)
    if t <= 0 then return row end
    local nextRow = rows[nextKey]
    if t >= 1 then return nextRow end

    local blended = {}
    for stat, v in pairs(row) do blended[stat] = v + ((nextRow[stat] or 0) - v) * t end
    for stat, v in pairs(nextRow) do
        if row[stat] == nil then blended[stat] = v * t end
    end
    return blended
end

-- =========================================================================
-- 2. WEIGHT DISPATCHER
-- =========================================================================

function MSC:ApplyDynamicAdjustments()
    local _, class = UnitClass("player")
    local specKey = "Default"
    local rawWeights = {}
    local mathSpec = nil
    MSC.CachedSpecConfidence = "high"

    -- 1. CHECK FOR MANUAL OVERRIDE 
    if MSC.ManualSpec and MSC.ManualSpec ~= "AUTO" then
        specKey = MSC.ManualSpec
        local found = false
        
        -- [[ A. PRIORITY 1: CHECK CUSTOM DATABASE (Pawn Imports) ]]
        if RXP_SGJ_DB and RXP_SGJ_DB.customWeights and RXP_SGJ_DB.customWeights[specKey] then
             local data = RXP_SGJ_DB.customWeights[specKey]
             
             if type(data) == "table" and data.weights then
                 rawWeights = NormalizeCustomWeights(data.weights)
                 if data.BaseSpec then mathSpec = data.BaseSpec end -- Only set mathSpec, leave specKey alone!
             else
                 rawWeights = NormalizeCustomWeights(data)
             end
             found = true
        end
        
        -- [[ B. PRIORITY 2: FORCE DYNAMIC CALCULATION ]]
        if not found and MSC.CurrentClass and MSC.CurrentClass.GetDynamicWeights then
            local dynWeights, dynKey = MSC.CurrentClass:GetDynamicWeights(specKey)
            if dynWeights then
                rawWeights = dynWeights
                specKey = dynKey
                found = true
            end
        end
        
        -- [[ C. PRIORITY 3: FALLBACK TO STATIC ]]
        if not found then
            if MSC.CurrentClass and MSC.CurrentClass.Weights and MSC.CurrentClass.Weights[specKey] then
                rawWeights = MSC.CurrentClass.Weights[specKey]
            elseif MSC.CurrentClass and MSC.CurrentClass.LevelingWeights and MSC.CurrentClass.LevelingWeights[specKey] then
                rawWeights = MSC:GetLevelingRow(MSC.CurrentClass, specKey)
            end
        end
        
    else
        -- 2. AUTO-DETECT MODE
        -- 2a. A Talents-plugin build names its level-60 profile (see
        -- MSC.SetTalentBuildRole); leveling roles are handled in GetLowLevelRole.
        local forcedEnd = (MSC.GetBuildRole() or {}).endgame
        local cls = MSC.CurrentClass
        if forcedEnd and (UnitLevel("player") or 0) >= 60 and cls and cls.Weights and cls.Weights[forcedEnd] then
            specKey = forcedEnd
            rawWeights = cls.Weights[forcedEnd]
        elseif MSC.CurrentClass and MSC.CurrentClass.GetDynamicWeights then
            local dynWeights, dynKey = MSC.CurrentClass:GetDynamicWeights()
            if dynWeights then
                rawWeights = dynWeights
                specKey = dynKey
            end
        end

        -- 3. FALLBACK: STATIC LOOKUP
        if (not rawWeights or not next(rawWeights)) and MSC.CurrentClass and MSC.CurrentClass.GetSpec then
            local conf
            specKey, conf = MSC.CurrentClass:GetSpec()
            MSC.CachedSpecConfidence = conf or "high"
            
            if MSC.CurrentClass.Weights and MSC.CurrentClass.Weights[specKey] then
                rawWeights = MSC.CurrentClass.Weights[specKey]
            elseif MSC.CurrentClass.LevelingWeights and MSC.CurrentClass.LevelingWeights[specKey] then
                rawWeights = MSC:GetLevelingRow(MSC.CurrentClass, specKey)
            end
        end
    end

    -- 3b. Gear for PvP: auto-detect names the class's PvP profile for a raid
    -- spec that has one (same weights; the PvP model is added either way).
    if (not MSC.ManualSpec or MSC.ManualSpec == "AUTO") and MSC.IsForever and MSC.IsGearingForPvP() then
        local cls = MSC.CurrentClass
        local pvpKey = cls and cls.PvPCounterpart and cls.PvPCounterpart[specKey]
        if pvpKey and cls.Weights and cls.Weights[pvpKey] then
            specKey, rawWeights = pvpKey, cls.Weights[pvpKey]
        end
    end

    -- 4. COPY WEIGHTS (Don't edit the originals!)
    local finalWeights, capText = MSC:ApplyWeightPipeline(rawWeights, mathSpec or specKey)

    return finalWeights, specKey, capText 
end

-- [[ THE MASTER WRAPPER ]] --
local lastWeightsSig = nil
function MSC.GetCurrentWeights()
    if MSC.CachedWeights then
        return MSC.CachedWeights, MSC.CachedSpecKey, MSC.CachedCapText, MSC.CachedSpecConfidence
    end

    local w, key, capText = MSC:ApplyDynamicAdjustments()
    
    MSC.CachedWeights = w
    MSC.CachedSpecKey = key
    MSC.CachedCapText = capText
    MSC.CachedSpecConfidence = MSC.CachedSpecConfidence or "high"

    if w and MSC.UpdateSetBonusScores then MSC:UpdateSetBonusScores(w) end

    -- [[ NUKE TOOLTIP CACHE WHEN PROFILE CHANGES ]]
    -- Only when the profile actually changed; weights are also rebuilt after
    -- plain cache clears that leave every cached result valid.
    local sig = tostring(key) .. "|" .. (MSC.ScoringRevision or 0) .. "|" .. tostring(MSC.ManualSpec) .. "|" .. (UnitLevel("player") or 0)
    if sig ~= lastWeightsSig then
        lastWeightsSig = sig
        if MSC.EvaluationCache then wipe(MSC.EvaluationCache) end
        if MSC.SlotCache then wipe(MSC.SlotCache) end
    end

    return w, key, capText, MSC.CachedSpecConfidence
end

-- =========================================================================
-- 3. WEAPON SPEC BONUS (Delegated)
-- =========================================================================
function MSC:GetWeaponSpecBonus(itemLink, class, specKey)
    if MSC.CurrentClass and MSC.CurrentClass.GetWeaponBonus then
        return MSC.CurrentClass:GetWeaponBonus(itemLink)
    end
    return 0
end

-- =========================================================================
-- 4. EVENT LISTENER (Cache Invalidation)
-- =========================================================================

-- [[ THE EVENT LISTENER ]]
local talentTracker = CreateFrame("Frame")
talentTracker:RegisterEvent("CHARACTER_POINTS_CHANGED")
talentTracker:RegisterEvent("PLAYER_TALENT_UPDATE")
talentTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
-- PLAYER_EQUIPMENT_CHANGED: CacheManager bumps the scoring revision.
-- UNIT_INVENTORY_CHANGED is not used: it fires for bags/ammo/durability and
-- party members, and gear changes already arrive as PLAYER_EQUIPMENT_CHANGED.
talentTracker:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
talentTracker:RegisterEvent("PLAYER_LEVEL_UP") -- Forever leveling weights blend by level
-- Forever's trait-based talent window commits through the trait config
-- (unknown events raise an error on Classic clients, hence the pcall)
pcall(talentTracker.RegisterEvent, talentTracker, "TRAIT_CONFIG_UPDATED")

talentTracker:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED" then
        MSC.TalentCache = {} 
        MSC.TalentCacheLoaded = false
        MSC:BumpScoringRevision()
    elseif event == "PLAYER_LEVEL_UP" then
        -- Weights blend by level (Forever curves), rating values and enchant/gem
        -- suggestions depend on level, and mail/plate become wearable at 40:
        -- bumping the revision drops the weights, the equipped-slot scores,
        -- the processed item stats and the usable cache together. (Clearing
        -- only the weights left bag arrows comparing against old scores.)
        MSC:BumpScoringRevision()
    else
        MSC.CachedWeights = nil
        MSC.CachedSpecKey = nil
        if MSC.CachedWeightsBySpec then wipe(MSC.CachedWeightsBySpec) end
    end
end)

-- =========================================================================
-- 5. SET BONUS CALCULATOR
-- =========================================================================
function MSC:UpdateSetBonusScores(weights)
    if not MSC.SetBonusScores or not weights then return end

    local count = 0
    for setID, setStages in pairs(MSC.SetBonusScores) do
        for reqCount, data in pairs(setStages) do
            if data.stats then
                local score = 0
                for stat, val in pairs(data.stats) do
                    local w = weights[stat] or 0
                    if w > 0 then
                        score = score + (val * w)
                    end
                end
                data.score = MSC.Round(score, 1)
                count = count + 1
            end
        end
    end
end

-- [[ AUTO-CALCULATE ON LOAD ]]
local setCalcFrame = CreateFrame("Frame")
setCalcFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
setCalcFrame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(2, function()
        if MSC.GetCurrentWeights then
            local weights = MSC.GetCurrentWeights()
            if weights then
                MSC:UpdateSetBonusScores(weights)
            end
        end
    end)
end)

-- =========================================================================
-- BASELINE PROFILE MANAGER
-- =========================================================================

-- The character's full name. WoW Forever characters have a first and a last
-- name, and UnitName returns only the first ("Super" for "Super Sharpie"), so
-- characters sharing a first name used to share one key. GetUnitName(unit, true)
-- returns the full name (it appends "-Realm" only for other realms; stripped just
-- in case). On Classic Era and TBC this is the same as UnitName.
function MSC.GetCharacterName()
    local full = GetUnitName and GetUnitName("player", true)
    if type(full) == "string" and full ~= "" then
        return full:match("^(.-)%-[^%-]+$") or full
    end
    return UnitName("player") or "Unknown"
end

-- The key from before the full-name fix (first name only), for one-time copies.
function MSC.GetLegacyPlayerKey()
    return (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Local")
end

-- Generates a unique key for the current character
function MSC:GetPlayerKey()
    return MSC.GetCharacterName() .. "-" .. (GetRealmName() or "Local")
end

-- Copies per-character data saved under the old first-name key to the full-name
-- key, once. Copied, not moved: several characters may share the old key.
function MSC.MigrateCharacterKey(tbl)
    if type(tbl) ~= "table" then return end
    local new, old = MSC:GetPlayerKey(), MSC.GetLegacyPlayerKey()
    if new ~= old and tbl[new] == nil and tbl[old] ~= nil then
        local function Copy(v)
            if type(v) ~= "table" then return v end
            local c = {}
            for k, x in pairs(v) do c[k] = Copy(x) end
            return c
        end
        tbl[new] = Copy(tbl[old])
    end
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        if RXP_SGJ_Settings then
            MSC.MigrateCharacterKey(RXP_SGJ_Settings.GearProfiles)
            MSC.MigrateCharacterKey(RXP_SGJ_Settings.TalentProfiles)
        end
    end)
end

-- The talents you play a profile with, so an off-spec line for it is scored
-- with them later (MSC.GetSavedTalents). Saved on gear, talent and level changes.
function MSC.SaveSpecTalents(specName)
    if not (RXP_SGJ_Settings and specName) then return end
    local pk = MSC:GetPlayerKey()
    RXP_SGJ_Settings.TalentProfiles = RXP_SGJ_Settings.TalentProfiles or {}
    RXP_SGJ_Settings.TalentProfiles[pk] = RXP_SGJ_Settings.TalentProfiles[pk] or {}
    if not MSC.TalentCacheLoaded then MSC:BuildTalentCache() end
    RXP_SGJ_Settings.TalentProfiles[pk][specName] = MSC:SafeCopy(MSC.TalentCache)
end

-- Called per PLAYER_EQUIPMENT_CHANGED (once per slot, so up to ~17 times on a
-- gear-set swap), and on talent and level changes: runs once 0.5 s after the last call, and after combat ends
-- when called in combat.
local baselinePending, baselineCallId = false, 0
local baselineRegenFrame = CreateFrame("Frame")
baselineRegenFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    MSC:RunAutoUpdateBaseline()
end)

function MSC:AutoUpdateBaseline()
    baselineCallId = baselineCallId + 1
    if baselinePending then return end
    baselinePending = true
    local function Fire(id)
        if id ~= baselineCallId then
            local latest = baselineCallId
            C_Timer.After(0.5, function() Fire(latest) end)
            return
        end
        baselinePending = false
        if InCombatLockdown and InCombatLockdown() then
            baselineRegenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            MSC:RunAutoUpdateBaseline()
        end
    end
    local id = baselineCallId
    C_Timer.After(0.5, function() Fire(id) end)
end

-- The gear a spec group was last used with (Roster's fallback when the core
-- can't list your owned gear). Saved on every gear change while the group is active,
-- except just after a spec switch, while the old spec's gear may still be on.
function MSC.SaveSpecGear(group)
    if not RXP_SGJ_Settings or not MSC.GetPlayerKey then return end
    local pk = MSC:GetPlayerKey()
    RXP_SGJ_Settings.SpecGear = RXP_SGJ_Settings.SpecGear or {}
    RXP_SGJ_Settings.SpecGear[pk] = RXP_SGJ_Settings.SpecGear[pk] or {}
    RXP_SGJ_Settings.SpecGear[pk][group or MSC.GetActiveSpecGroup()] = MSC:GetEquippedGear()
end

function MSC.GetSpecGear(group)
    local all = RXP_SGJ_Settings and RXP_SGJ_Settings.SpecGear
    local mine = all and MSC.GetPlayerKey and all[MSC:GetPlayerKey()]
    return mine and mine[group] or nil
end

local SPEC_SWITCH_SETTLE = 5 -- seconds for an equipment-manager swap to finish

function MSC:RunAutoUpdateBaseline()
    if not RXP_SGJ_Settings then return end
    if not (MSC.LastSpecSwitch and GetTime() - MSC.LastSpecSwitch < SPEC_SWITCH_SETTLE) then
        MSC.SaveSpecGear(MSC.GetActiveSpecGroup())
    end
    local _, specName = self.GetCurrentWeights()
    MSC.SaveSpecTalents(specName)
end

-- Spec switches: load the new spec's profile choice and Gear for PvP, redraw
-- their controls, and save its gear once a gear-set swap has settled.
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    f:SetScript("OnEvent", function(self, event, curr)
        if not RXP_SGJ_Settings then return end
        MSC.ManualSpec = MSC.GetManualSpec(MSC.GetActiveSpecGroup())
        if MSC.GroupWeightsCache then wipe(MSC.GroupWeightsCache) end
        if MSC.NotifyPvPToggle then MSC.NotifyPvPToggle() end
        if MSC.ProfileDropdown and MSC.ProfileDropdown.RefreshText then MSC.ProfileDropdown.RefreshText() end
        if event == "ACTIVE_TALENT_GROUP_CHANGED" then
            MSC.LastSpecSwitch = GetTime()
            MSC.CachedWeights = nil
            if MSC.BumpScoringRevision then MSC:BumpScoringRevision() end
            local group = tonumber(curr) or MSC.GetActiveSpecGroup()
            C_Timer.After(SPEC_SWITCH_SETTLE + 0.5, function()
                if MSC.GetActiveSpecGroup() == group and not InCombatLockdown() then MSC.SaveSpecGear(group) end
            end)
        end
    end)
end
