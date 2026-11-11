local Stubs = require("wow_stubs")
local T = {}

local INDEX = {
    [16934] = { name = "Ferocity", tab = 2, nodeID = 101, maxRank = 5 },
    [17056] = { name = "Furor", tab = 3, nodeID = 102, maxRank = 5 },
}

local function setup(opts)
    opts = opts or {}
    RXP_FB = {}
    PlayerSpellsFrame, ClassTalentFrame = nil, nil
    local ctx = Stubs.install({ class = "DRUID", level = opts.level or 14 })
    if opts.talentFrame then
        local button = Stubs.newFrame("NodeButton")
        local f = Stubs.newFrame("PlayerSpellsFrame")
        f.TalentsFrame = {
            asked = {},
            GetTalentButtonByNodeID = function(self, nodeID)
                self.asked[#self.asked + 1] = nodeID
                return button
            end,
        }
        f.button = button
        PlayerSpellsFrame = f
    end
    for _, m in ipairs({ "TalentResolver", "TalentPath", "TalentGuideUI" }) do
        Stubs.loadAddonFile("ForeverBuilds/" .. m .. ".lua", {})
    end
    return RXP_FB.TalentGuideUI, ctx
end

local function cat(points)
    local order = { 16934, 5, 17056, 5 }
    local b = { id = "Leveling|CAT_RAID|10", label = "Feral Cat: Solo Leveling – Feral Combat", order = order,
        points = points or 10, complete = (points or 51) == 51, class = "DRUID" }
    local steps, warnings = RXP_FB.TalentPath.Build(b, function(id) return INDEX[id] end)
    return b, steps, warnings
end

local ranks = { [16934] = 3 }
local function currentRank(id) return ranks[id] or 0 end

function T.test_lines_auto()
    local UI = setup()
    UI.Update(nil, nil, {}, nil, nil)
    assert_eq(UI.Lines(), {
        "Forever Build: Automatic (no talent guide)",
        "Choose a build in RestedXP settings > Forever Build.",
    })
end

function T.test_lines_now_and_next()
    local UI = setup({ level = 14 })
    local b, steps, warnings = cat(51)
    UI.Update(b, steps, warnings, nil, currentRank)
    assert_eq(UI.Lines(), {
        "Forever Build: Feral Cat: Solo Leveling – Feral Combat",
        "Now:",
        "  Lv 13: Ferocity (4/5) – Feral Combat",
        "  Lv 14: Ferocity (5/5) – Feral Combat",
        "Next:",
        "  Lv 15: Furor (1/5) – Restoration",
        "  Lv 16: Furor (2/5) – Restoration",
        "  Lv 17: Furor (3/5) – Restoration",
    })
end

function T.test_lines_unknown_ranks()
    local UI = setup()
    local b, steps, warnings = cat(51)
    UI.Update(b, steps, warnings, nil, nil)
    assert_eq(UI.Lines()[2], "Talent data not loaded yet.")
end

function T.test_lines_incomplete_and_unresolved()
    local UI = setup({ level = 9 })
    local b, steps = cat(39)
    b.complete = false
    UI.Update(b, steps, { "UNRESOLVED 1 at level 12", "UNRESOLVED 2 at level 13" }, nil, currentRank)
    local lines = UI.Lines()
    assert_eq(lines[2], "Now: nothing to spend")
    assert_eq(lines[#lines - 1], "Incomplete talent order (39/51): some levels may not match the build.")
    assert_eq(lines[#lines], "2 talents could not be matched.")
end

function T.test_levelup_prints_next_talent()
    local UI, ctx = setup({ level = 14 })
    local b, steps, warnings = cat(51)
    UI.Update(b, steps, warnings, "levelup", currentRank)
    assert_eq(ctx.printed, { "RestedXP Forever: level 14 talent: Lv 13: Ferocity (4/5) – Feral Combat" })
end

function T.test_login_hint_waits_for_rank_data()
    local UI, ctx = setup({ level = 14 })
    local b, steps, warnings = cat(51)
    UI.Update(b, steps, warnings, "login", nil)
    assert_eq(ctx.printed, nil, "no hint while ranks are unknown")
    UI.Update(b, steps, warnings, nil, currentRank)
    assert_eq(#ctx.printed, 1, "deferred login hint")
    UI.Update(b, steps, warnings, nil, currentRank)
    assert_eq(#ctx.printed, 1, "login hint only once")
end

function T.test_no_print_when_nothing_available()
    local UI, ctx = setup({ level = 9 })
    local b, steps, warnings = cat(51)
    UI.Update(b, steps, warnings, "levelup", currentRank)
    assert_eq(ctx.printed, nil)
end

function T.test_highlight_uses_node_button()
    local UI = setup({ level = 14, talentFrame = true })
    UI.Attach()
    local b, steps, warnings = cat(51)
    UI.Update(b, steps, warnings, nil, currentRank)
    assert_eq(UI.HighlightAvailable(), true)
    assert_eq(PlayerSpellsFrame.TalentsFrame.asked[#PlayerSpellsFrame.TalentsFrame.asked], 101)
    local glow = PlayerSpellsFrame.button.RXPFBGlow
    assert(glow and glow.shown, "glow shown on the node button")
    ranks[16934] = 5 -- everything up to level 14 taken: nothing to highlight
    UI.Update(b, steps, warnings, nil, currentRank)
    ranks[16934] = 3
    assert_eq(glow.shown, false, "glow hidden when nothing is available")
end

function T.test_highlight_absent_frame_is_silent()
    local UI = setup({ level = 14 })
    local b, steps, warnings = cat(51)
    UI.Update(b, steps, warnings, nil, currentRank)
    assert_eq(UI.HighlightAvailable(), false)
end

function T.test_panel_follows_talent_frame_visibility()
    local UI = setup({ talentFrame = true })
    UI.Attach()
    local panel = UI.panel
    assert(panel, "panel created")
    PlayerSpellsFrame.scripts.OnHide(PlayerSpellsFrame)
    assert_eq(panel.shown, false)
    PlayerSpellsFrame.scripts.OnShow(PlayerSpellsFrame)
    assert_eq(panel.shown, true)
end

function T.test_attach_waits_for_talent_ui_addon()
    local UI, ctx = setup()
    UI.Attach()
    assert_eq(UI.panel, nil)
    PlayerSpellsFrame = Stubs.newFrame("PlayerSpellsFrame")
    ctx.fire("ADDON_LOADED", "Blizzard_PlayerSpells")
    assert(UI.panel, "panel created after the talent UI loads")
end

function T.test_levelup_uses_event_level()
    local UI, ctx = setup({ level = 13 }) -- UnitLevel still reports the old level
    local b, steps, warnings = cat(51)
    UI.Update(b, steps, warnings, "levelup", currentRank, 14)
    assert_eq(ctx.printed, { "RestedXP Forever: level 14 talent: Lv 13: Ferocity (4/5) – Feral Combat" })
    assert_eq(UI.Lines()[4], "  Lv 14: Ferocity (5/5) – Feral Combat", "level 14 step is available now")
end

return T
