-- RestedXP Forever fork: talent guide on Forever's modern talent window.
-- A panel next to the talent window lists the talents to take now and next for the
-- chosen build, a chat line names the next talent on level-up (and once after login),
-- and the next node is highlighted in the talent window when its button can be found.
RXP_FB = RXP_FB or {}
local UI = {}
RXP_FB.TalentGuideUI = UI

local PREFIX = "RestedXP Forever: "
local MAX_NOW_LINES = 5
local TALENT_UI_ADDONS = { Blizzard_PlayerSpells = true, Blizzard_ClassTalentUI = true }

local state = { build = nil, steps = nil, warnings = {}, currentRank = nil, available = {}, upcoming = {}, level = nil }
local loginHintPending = false

local function PlayerClass()
    local _, token = UnitClass("player")
    return token
end

-- The modern talent window and its talent tree frame (11.x name first, 10.x as fallback).
local function TalentWindow()
    if PlayerSpellsFrame then return PlayerSpellsFrame, PlayerSpellsFrame.TalentsFrame end
    if ClassTalentFrame then return ClassTalentFrame, ClassTalentFrame.TalentsTab end
    return nil, nil
end

-- PLAYER_LEVEL_UP passes the new level, which UnitLevel may not report yet.
local function PlayerLevel()
    return math.max(UnitLevel("player") or 1, state.level or 0)
end

local function Recompute()
    state.available, state.upcoming = {}, {}
    if state.build and state.steps and state.currentRank then
        state.available, state.upcoming = RXP_FB.TalentPath.Pending(state.steps, PlayerLevel(), state.currentRank)
    end
end

function UI.Lines()
    local P, class = RXP_FB.TalentPath, PlayerClass()
    local lines = {}
    local b = state.build
    if not b then
        lines[1] = "Forever Build: Automatic (no talent guide)"
        lines[2] = "Choose a build in RestedXP settings > Forever Build."
        return lines
    end
    lines[1] = "Forever Build: " .. b.label
    if not state.currentRank then
        lines[#lines + 1] = "Talent data not loaded yet."
    else
        if #state.available == 0 then
            lines[#lines + 1] = "Now: nothing to spend"
        else
            lines[#lines + 1] = "Now:"
            for i, step in ipairs(state.available) do
                if i > MAX_NOW_LINES then
                    lines[#lines + 1] = "  +" .. (#state.available - MAX_NOW_LINES) .. " more"
                    break
                end
                lines[#lines + 1] = "  " .. P.FormatStep(step, class)
            end
        end
        if #state.upcoming > 0 then
            lines[#lines + 1] = "Next:"
            for _, step in ipairs(state.upcoming) do lines[#lines + 1] = "  " .. P.FormatStep(step, class) end
        end
    end
    if not b.complete then
        lines[#lines + 1] = "Incomplete talent order (" .. b.points .. "/51): some levels may not match the build."
    end
    if state.warnings and #state.warnings > 0 then
        lines[#lines + 1] = #state.warnings .. " talents could not be matched."
    end
    return lines
end

-- ---------------------------------------------------------------- highlight
local glowOn = nil

local function HideGlow()
    if glowOn and glowOn.RXPFBGlow then glowOn.RXPFBGlow:Hide() end
    glowOn = nil
end

function UI.HighlightTarget()
    local step = state.available[1]
    local _, tree = TalentWindow()
    if not (step and step.nodeID and tree and tree.GetTalentButtonByNodeID) then return nil end
    local ok, button = pcall(tree.GetTalentButtonByNodeID, tree, step.nodeID)
    if ok and type(button) == "table" and button.CreateTexture then return button end
    return nil
end

function UI.HighlightAvailable()
    local _, tree = TalentWindow()
    return (tree and tree.GetTalentButtonByNodeID) and true or false
end

local function ApplyHighlight()
    HideGlow()
    local button = UI.HighlightTarget()
    if not button then return end
    local glow = button.RXPFBGlow
    if not glow then
        local ok, tx = pcall(button.CreateTexture, button, nil, "OVERLAY")
        if not ok or not tx then return end
        glow = tx
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(0.2, 1, 0.2)
        glow:SetPoint("CENTER", button, "CENTER", 0, 0)
        local w = (button.GetWidth and button:GetWidth()) or 40
        glow:SetSize(w * 1.8, w * 1.8)
        button.RXPFBGlow = glow
    end
    glow:Show()
    glowOn = button
end

-- ---------------------------------------------------------------- panel
local function Redraw()
    local panel = UI.panel
    if panel and panel.text then panel.text:SetText(table.concat(UI.Lines(), "\n")) end
    local window = TalentWindow()
    if window and window.IsShown and window:IsShown() then ApplyHighlight() else HideGlow() end
end

local function CreatePanel(parent, anchor)
    local panel = CreateFrame("Frame", "RXPForeverTalentPanel", parent)
    panel:SetSize(300, 200)
    if anchor then
        panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    else
        panel:SetPoint("CENTER", parent, "CENTER", 0, 0)
    end
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(panel)
    bg:SetColorTexture(0, 0, 0, 0.75)
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    text:SetWidth(284)
    text:SetJustifyH("LEFT")
    panel.text = text
    UI.panel = panel
    return panel
end

local function AttachTo(window)
    if UI.panel and UI.panelAttached then return end
    local panel = UI.panel or CreatePanel(window, window)
    if panel.SetParent then panel:SetParent(window) end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", window, "TOPRIGHT", 4, 0)
    UI.panelAttached = true
    window:HookScript("OnShow", function() panel:Show(); Redraw() end)
    window:HookScript("OnHide", function() panel:Hide(); HideGlow() end)
    if window.IsShown and window:IsShown() then panel:Show() else panel:Hide() end
    Redraw()
end

function UI.Attach()
    local window = TalentWindow()
    if window then
        AttachTo(window)
        return
    end
    if UI.waiter then return end
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if not TALENT_UI_ADDONS[name] then return end
        local w = TalentWindow()
        if w then
            self:UnregisterEvent("ADDON_LOADED")
            AttachTo(w)
        end
    end)
    UI.waiter = f
end

-- /rxpfb talents: show or hide the panel without the talent window.
function UI.Toggle()
    if not UI.panel then
        CreatePanel(UIParent, nil)
        UI.panel:Hide() -- new frames start shown; the toggle below shows it
    end
    if UI.panel:IsShown() then UI.panel:Hide() else UI.panel:Show(); Redraw() end
end

-- ---------------------------------------------------------------- update
function UI.Update(build, steps, warnings, reason, currentRank, level)
    state.build, state.steps, state.warnings, state.currentRank = build, steps, warnings or {}, currentRank
    if level then state.level = level end
    Recompute()
    if reason == "login" then loginHintPending = true end
    local hint = (reason == "levelup") or (loginHintPending and currentRank ~= nil)
    if hint and currentRank then
        loginHintPending = false
        local step = state.available[1]
        if step then
            print(PREFIX .. "level " .. PlayerLevel() .. " talent: "
                .. RXP_FB.TalentPath.FormatStep(step, PlayerClass()))
        end
    end
    Redraw()
end
