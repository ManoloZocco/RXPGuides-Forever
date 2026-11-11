-- RestedXP Forever fork: /rxpfb diagnostics.
--   /rxpfb          builds per spec, talent-matched role, engine version
--   /rxpfb check    resolve every build of your class on your talent tree; highlight support
--   /rxpfb talents  show/hide the talent guide panel without the talent window
RXP_FB = RXP_FB or {}
local D = {}
RXP_FB.Diagnostics = D

local PREFIX = "RestedXP Forever: "
local function out(text) print(PREFIX .. text) end

local function Index(group)
    local engine = RXP_SGJ_NS
    if not (engine and engine.ForEachTraitTalent) then return nil end
    return RXP_FB.TalentResolver.BuildIndex(function(fn) return engine.ForEachTraitTalent(fn, group) end)
end

local function Status()
    local commit = RXP_SGJ_COMMIT and RXP_SGJ_COMMIT:sub(1, 7) or "?"
    out("engine " .. tostring(RXP_SGJ_VERSION or "?") .. " (" .. commit .. ")")
    if RXP_SGJ_DISABLED then
        out("embedded engine disabled: the standalone Sharpie's Gear Judge addon is enabled")
        return
    end
    local S = RXP_FB.BuildState
    for group = 1, 2 do
        local id = S.Get(group)
        local b = id ~= "AUTO" and RXP_FB.BuildCatalog.Find(S.Builds(), id)
        out("spec " .. group .. ": " .. id .. (b and (" = " .. b.label) or ""))
    end
    local engine = RXP_SGJ_NS
    local matched = engine and engine.MatchTalentBuild and engine.MatchTalentBuild(UnitLevel("player") or 1)
    out("matched from talents: " .. ((matched and (matched.leveling or matched.endgame)) or "none"))
end

local function Check()
    if RXP_SGJ_DISABLED then return Status() end
    local index = Index()
    if not index then
        out("talent tree not readable yet; open the talent window once and retry")
    end
    local R = RXP_FB.TalentResolver
    for _, b in ipairs(RXP_FB.BuildState.Builds()) do
        local _, warnings = RXP_FB.TalentPath.Build(b, function(id) return R.Resolve(index, id) end)
        if #warnings == 0 then
            out("OK " .. b.label)
        else
            local ids, seen = {}, {}
            for _, w in ipairs(warnings) do
                local id = w:match("^UNRESOLVED (%d+)")
                if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
            end
            out(b.label .. ": " .. #ids .. " unresolved (" .. table.concat(ids, ", ") .. ")")
        end
    end
    local UI = RXP_FB.TalentGuideUI
    if UI and UI.HighlightAvailable() then
        out("highlight: available (" .. (PlayerSpellsFrame and "PlayerSpellsFrame.TalentsFrame" or "ClassTalentFrame.TalentsTab") .. ")")
    else
        out("highlight: unavailable (talent window not loaded yet, or it has no GetTalentButtonByNodeID)")
    end
end

function D.Run(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "" or cmd == "status" then
        Status()
    elseif cmd == "check" then
        Check()
    elseif cmd == "talents" then
        if RXP_FB.TalentGuideUI then RXP_FB.TalentGuideUI.Toggle() end
    else
        out("usage: /rxpfb [status | check | talents]")
    end
end
