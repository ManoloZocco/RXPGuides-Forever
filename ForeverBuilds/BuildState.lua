-- RestedXP Forever fork: the build chosen per spec group (RXPCData.foreverBuilds[group]),
-- pushed into the embedded engine (MSC.SetTalentBuildRole) and the talent guide UI.
RXP_FB = RXP_FB or {}
local S = {}
RXP_FB.BuildState = S

local AUTO = "AUTO"
local cache = { builds = nil, withTrees = false }

local function Engine() return RXP_SGJ_NS end

local function PlayerClass()
    local _, token = UnitClass("player")
    return token
end

local function Saved()
    if type(RXPCData) ~= "table" then return nil end
    RXPCData.foreverBuilds = RXPCData.foreverBuilds or {}
    return RXPCData.foreverBuilds
end

local function ActiveGroup()
    local engine = Engine()
    local ok, group = false, nil
    if engine and engine.GetActiveSpecGroup then ok, group = pcall(engine.GetActiveSpecGroup) end
    return (ok and tonumber(group)) or 1
end

-- Trait-tree index for a spec group (nil when the client has no talent config yet).
local function Index(group)
    local engine = Engine()
    if not (engine and engine.ForEachTraitTalent) then return nil end
    return RXP_FB.TalentResolver.BuildIndex(function(fn) return engine.ForEachTraitTalent(fn, group) end)
end

function S.Builds()
    if cache.builds and cache.withTrees then return cache.builds end
    local engine, class = Engine(), PlayerClass()
    local rows = engine and engine.BuildMatch and engine.BuildMatch[class]
    local index = Index()
    local R = RXP_FB.TalentResolver
    local treeOf = index and function(spellID)
        local e = R.Resolve(index, spellID)
        return e and e.tab
    end or function() return nil end
    cache.builds = RXP_FB.BuildCatalog.List(class, rows, engine and engine.PrettyNames, treeOf,
        function(tab) return R.TreeName(class, tab) end)
    cache.withTrees = index ~= nil
    return cache.builds
end

function S.Get(group)
    local saved = Saved()
    local id = saved and saved[group]
    if not id or id == AUTO then return AUTO end
    local builds = S.Builds()
    if #builds > 0 and not RXP_FB.BuildCatalog.Find(builds, id) then
        saved[group] = nil
        return AUTO
    end
    return id
end

function S.Set(group, id)
    local saved = Saved()
    if saved then saved[group] = (id ~= AUTO) and id or nil end
    S.Apply()
    -- Same refresh as Sharpie's own profile picker: cached scores, bag arrows and the
    -- other-spec tooltip line (SetTalentBuildRole alone only clears the active weights).
    local engine = Engine()
    if engine and engine.OnScoringSettingsChanged then engine.OnScoringSettingsChanged() end
end

local function BuildFor(group)
    local id = S.Get(group)
    if id == AUTO then return nil end
    return RXP_FB.BuildCatalog.Find(S.Builds(), id)
end

function S.RoleFor(group)
    local b = BuildFor(group)
    if not b then return nil end
    return { leveling = b.role, endgame = b.endgame, pvp = b.pvp or nil }
end

function S.Apply(reason, level)
    local engine = Engine()
    local group = ActiveGroup()
    local build = BuildFor(group)
    if engine and engine.SetTalentBuildRole then
        if build then
            engine.SetTalentBuildRole(build.role, build.endgame, build.pvp)
        else
            engine.SetTalentBuildRole(nil, nil, nil)
        end
    end
    local steps, warnings, currentRank
    if build then
        local index = Index(group)
        local R = RXP_FB.TalentResolver
        steps, warnings = RXP_FB.TalentPath.Build(build, function(id) return R.Resolve(index, id) end)
        -- nil while the trait tree is not readable yet (early login): ranks are unknown, not zero
        currentRank = index and function(spellID)
            local e = R.Resolve(index, spellID)
            return e and e.rank or 0
        end or nil
    end
    local UI = RXP_FB.TalentGuideUI
    if UI and UI.Update then UI.Update(build, steps, warnings or {}, reason, currentRank, level) end
end

local EVENTS = {
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_LEVEL_UP",
    "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED",
}
-- events after which the trait tree may have become readable: rebuild labels with tree names
local TREE_EVENTS = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, TRAIT_CONFIG_UPDATED = true, TRAIT_CONFIG_LIST_UPDATED = true }

function S.Init()
    if RXP_SGJ_DISABLED then return end
    local engine = Engine()
    if engine then
        engine.GetTalentBuildRoleForGroup = function(g) return RXP_FB.BuildState.RoleFor(g) end
    end
    local f = CreateFrame("Frame")
    for _, event in ipairs(EVENTS) do pcall(f.RegisterEvent, f, event) end
    f:SetScript("OnEvent", function(_, event, arg1)
        if TREE_EVENTS[event] then cache.withTrees = false end
        if event == "PLAYER_LEVEL_UP" then
            -- the new level comes with the event; UnitLevel can still report the old one here
            S.Apply("levelup", tonumber(arg1))
        else
            S.Apply(event == "PLAYER_LOGIN" and "login" or nil)
        end
    end)
end
