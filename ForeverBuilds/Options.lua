-- RestedXP Forever fork: "Forever Build" tab in the RestedXP settings (AceConfig).
-- One place to choose the build per spec group and the embedded engine's display options.
local _, addon = ...
RXP_FB = RXP_FB or {}
local O = {}
RXP_FB.Options = O

local AUTO = "AUTO"

-- Display options of Sharpie's Gear Judge's own settings page (Interface.lua CreateCheck),
-- in its order. Scoring options (buffs, raid/PvP gearing, two-handers) keep the engine defaults.
O.DISPLAY_TOGGLES = {
    { key = "HideTooltips", name = "Show gear verdict in tooltips", inverted = true },
    { key = "ShiftOnlyTooltip", name = "Show verdict only while holding Shift" },
    { key = "ShowBagArrows", name = "Show upgrade arrows in bags" },
    { key = "FastBagArrows", name = "Fast bag arrows (single-slot scoring)" },
    { key = "ShowLootArrows", name = "Show upgrade arrows on group loot rolls" },
    { key = "ShowLootToast", name = "Alert when you loot an upgrade" },
    { key = "ShowOtherSpec", name = "Show the other spec on tooltips" },
    { key = "CompactEquip", name = "Compact equip text" },
    { key = "SimplifyStats", name = "Shorten stat names" },
    { key = "ColorizeStats", name = "Colorize stats" },
    { key = "MuteSounds", name = "Mute error sounds" },
    { key = "DisableConflictCheck", name = "Disable the Pawn/Zygor conflict warning" },
}

local function Engine() return RXP_SGJ_NS end

local function ActiveGroup()
    local e = Engine()
    local ok, g = false, nil
    if e and e.GetActiveSpecGroup then ok, g = pcall(e.GetActiveSpecGroup) end
    return (ok and tonumber(g)) or 1
end

local function BuildValues()
    local values = { [AUTO] = "Automatic (gear only)" }
    for _, b in ipairs(RXP_FB.BuildState.Builds()) do values[b.id] = b.label end
    return values
end

local function BuildSorting()
    local keys = { AUTO }
    for _, b in ipairs(RXP_FB.BuildState.Builds()) do keys[#keys + 1] = b.id end
    return keys
end

local function BuildSelect(order, name, desc, groupOf, hidden)
    return {
        type = "select", order = order, width = "full", name = name, desc = desc,
        values = BuildValues, sorting = BuildSorting, hidden = hidden,
        get = function() return RXP_FB.BuildState.Get(groupOf()) end,
        set = function(_, v) RXP_FB.BuildState.Set(groupOf(), v) end,
    }
end

local function AfterToggle(key)
    local e = Engine()
    if not e then return end
    if (key == "ShowBagArrows" or key == "FastBagArrows") and e.QueueBagOverlayRefresh then e.QueueBagOverlayRefresh() end
    if key == "FastBagArrows" and e.RequestBaganatorRefresh then e.RequestBaganatorRefresh() end
    if e.BumpScoringRevision then e:BumpScoringRevision() end
end

function O.Inject(optionsTable)
    if not (optionsTable and optionsTable.args) then return end
    if RXP_SGJ_DISABLED or not addon or addon.game ~= "FOREVER" then return end

    local args = {
        buildHeader = { type = "header", order = 1, name = "Build" },
        buildDesc = {
            type = "description", order = 2, fontSize = "medium",
            name = "The build drives both the talent guide (talent window panel and chat hints) and the gear verdict. "
                .. "Automatic recognises your build from spent talents for gear only, without a talent guide.",
        },
        activeBuild = BuildSelect(3, "Build (active spec)", "Build for the spec you are using now.", ActiveGroup),
        otherBuild = BuildSelect(4, "Build (other spec)", "Build for your second talent specialization.",
            function() return 3 - ActiveGroup() end,
            function()
                local e = Engine()
                return not (e and e.HasDualSpec and e.HasDualSpec())
            end),
        displayHeader = { type = "header", order = 10, name = "Gear display (Sharpie's Gear Judge)" },
    }
    for i, t in ipairs(O.DISPLAY_TOGGLES) do
        args[t.key] = {
            type = "toggle", order = 10 + i, width = "full", name = t.name,
            get = function()
                local v = RXP_SGJ_Settings and RXP_SGJ_Settings[t.key] == true
                if t.inverted then return not v end
                return v
            end,
            set = function(_, value)
                if not RXP_SGJ_Settings then return end
                if t.inverted then value = not value end
                RXP_SGJ_Settings[t.key] = value and true or false
                AfterToggle(t.key)
            end,
        }
    end

    optionsTable.args.foreverBuild = { type = "group", name = "Forever Build", order = 2.5, args = args }
end
