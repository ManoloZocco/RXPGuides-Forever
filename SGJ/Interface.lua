if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
_G.MSC = MSC 

-- [[ SPEED OPTIMIZATION: LOCALIZED FUNCTIONS ]]
local pairs, ipairs, next, type, tostring, unpack, select = pairs, ipairs, next, type, tostring, unpack, select
local table_insert, table_sort = table.insert, table.sort
local math_floor, math_ceil, math_max, math_min, math_abs = math.floor, math.ceil, math.max, math.min, math.abs
local string_format, string_find = string.format, string.find
local GetTime = GetTime

-- WoW APIs (UI & Data)
local CreateFrame = CreateFrame
local UIParent = UIParent
local GameTooltip = GameTooltip
local GetItemInfo = GetItemInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemTexture = GetInventoryItemTexture
local GetItemIcon = GetItemIcon or (C_Item and C_Item.GetItemIconByID)
local SetItemButtonTexture = function(btn, tex) if not btn.icon then btn.icon = btn:CreateTexture(nil, "BACKGROUND"); btn.icon:SetAllPoints() end btn.icon:SetTexture(tex) end
local UnitClass = UnitClass
local UnitRace = UnitRace
local UnitLevel = UnitLevel
local UnitName = UnitName
local GetRealmName = GetRealmName
local GetCursorInfo = GetCursorInfo
local ClearCursor = ClearCursor
local IsShiftKeyDown = IsShiftKeyDown
local CreateColor = CreateColor
local GetItemInfoInstant = GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)

-- Container API Wrapper
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetContainerItemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink


local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local version = (GetMetadata and GetMetadata(addonName, "Version")) or "2.x"

MSC.Version = version


-- =============================================================
-- 1. THEME, COLORS & HELPERS
-- =============================================================
MSC.Colors = { 
    BgSidebar = {0.05, 0.05, 0.05, 1.00}, 
    BgPanel   = {0.00, 0.00, 0.00, 0.50},
    BarHigh   = {0.0, 0.8, 1.0, 1.0}
}

-- [[ THEME ]]
-- One accent colour, section titles in their own colour with a thin line under
-- them, plain labels on the left and accent values on the right, flat dark panels.
MSC.Theme = {
    Accent = {0.93, 0.45, 0.68},
    Value  = {0.96, 0.64, 0.80},
    Text   = {0.92, 0.92, 0.92},
    Muted  = {0.55, 0.55, 0.58},
    Window = {0.06, 0.06, 0.08, 0.93},
    Panel  = {0.10, 0.10, 0.12, 0.80},
    Edge   = {1, 1, 1, 0.08},
    Section = {
        Gold   = {1.00, 0.80, 0.30},
        Red    = {1.00, 0.45, 0.42},
        Green  = {0.45, 0.88, 0.45},
        Purple = {0.72, 0.56, 1.00},
        Blue   = {0.42, 0.68, 1.00},
        Teal   = {0.35, 0.88, 0.82},
    },
}
-- The accent is the player's class colour; values are a lighter mix of it.
do
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then
        MSC.Theme.Accent = { c.r, c.g, c.b }
        MSC.Theme.Value = { c.r + (1 - c.r) * 0.4, c.g + (1 - c.g) * 0.4, c.b + (1 - c.b) * 0.4 }
    end
end

-- Section title: upper case in its section colour, with an accent line under it
-- `width` wide (no line when width is nil).
function MSC.StyleHeading(fs, color, width)
    local c = MSC.Theme.Section[color or "Gold"] or MSC.Theme.Section.Gold
    fs:SetText((fs:GetText() or ""):upper())
    fs:SetTextColor(c[1], c[2], c[3])
    if width and width > 0 then
        local a = MSC.Theme.Accent
        local line = fs:GetParent():CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(a[1], a[2], a[3], 0.5); line:SetHeight(1); line:SetWidth(width)
        line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -4)
        fs.Underline = line
    end
    return fs
end

-- [[ STAT COLORS ]]
MSC.StatColors = {
    -- [[ MAGIC STATS ]]
    SPELL_HIT   = {0.0, 1.0, 0.8},   -- Teal/Cyan (Distinct from Melee Green)
    SPELL_CRIT  = {0.8, 0.2, 1.0},   -- Bright Purple/Pink (Distinct from Melee Red)
    SPELL_POWER = {0.6, 0.4, 1.0},   -- Deep Purple
    MANA        = {0.0, 0.5, 1.0},   -- Mana Blue
    INTELLECT   = {0.2, 0.6, 1.0},   -- Cyan
    SPIRIT      = {0.6, 0.6, 1.0},   -- Lavender
    -- [[ PHYSICAL STATS ]]
    STAMINA = {0.6, 0.2, 0.2},       -- Dark Red
    AGILITY = {0.2, 1.0, 0.6},       -- Mint Green
    STRENGTH = {1.0, 0.2, 0.2},      -- Bright Red
    ATTACK_POWER = {1.0, 0.2, 0.2}, -- Red
    HIT = {0.2, 1.0, 0.2},           -- Green
    CRIT = {1.0, 0.2, 0.4},          -- Red/Pink
    HASTE = {1.0, 0.8, 0.0},         -- Gold
    DEFENSE = {0.2, 0.4, 0.8},       -- Tank Blue
    DODGE = {0.4, 0.4, 0.8},         -- Tank Blue
    PARRY = {0.4, 0.4, 0.8},         -- Tank Blue
    BLOCK = {0.5, 0.3, 0.1},         -- Shield Brown
    RESILIENCE = {0.5, 0.5, 0.5},    -- Grey
    ARMOR = {0.8, 0.6, 0.4},         -- Leather/Tan
}

-- [[ ROLE COLORS (NEON BRIGHT) ]]
MSC.RoleColors = {
    TANK   = {r=0.0, g=0.8, b=1.0}, -- Neon Blue
    HEALER = {r=0.0, g=1.0, b=0.4}, -- Neon Green
    CASTER = {r=0.8, g=0.4, b=1.0}, -- Neon Purple
    MELEE  = {r=1.0, g=0.3, b=0.1}, -- Neon Orange
    DEFAULT= {r=0.0, g=0.9, b=1.0}  -- Cyan
}

MSC.ReceiptSlots = {} 
MSC.BagCache = {}
MSC.BagCacheDirty = true
MSC.SummaryRows = {} 
MSC.LabBlocks = {} 
-- [[ FRAME POOL REGISTRY ]]
MSC.Pools = {
    Bars = {},
    Rings = {},
    Headers = {}
}

-- [[ NEW THROTTLE SYSTEM (C_Timer based) ]]
-- C_Timer.After returns nothing, so a flag coalesces each 0.5s burst into one update.
local updatePending = false
local function TriggerFullUpdate()
    updatePending = false
    if MSC.FlushEvaluationCacheWipe then MSC.FlushEvaluationCacheWipe() end
    if MSC.UpdateReceipt then MSC.UpdateReceipt() end
    if MSC.UpdateLogic then MSC.UpdateLogic() end
    if MSC.UpdateMainFooter then MSC.UpdateMainFooter() end
end

local function RequestUpdate()
    if not updatePending then
        updatePending = true
        C_Timer.After(0.5, TriggerFullUpdate)
    end
end

-- A Protocol option that changes scores (profile, enchant/gem modes, buff
-- assumptions, shield-tank 2H rule, Gear for Raiding) was changed: drop the
-- cached scores and redraw every bag arrow, Baganator's included. Only called
-- from those settings handlers, never from the per-BAG_UPDATE path.
function MSC.OnScoringSettingsChanged()
    if MSC.BumpScoringRevision then MSC:BumpScoringRevision()
    elseif MSC.EvaluationCache then wipe(MSC.EvaluationCache) end
    MSC.BagCacheDirty = true
    RequestUpdate()
    if MSC.QueueBagOverlayRefresh then MSC.QueueBagOverlayRefresh() end
    if MSC.RequestBaganatorRefresh then MSC.RequestBaganatorRefresh() end
end

-- Quest events and the QuestInfo/QuestLog hooks share one pending refresh.
local questRefreshPending = false
local function RunQuestRefresh()
    questRefreshPending = false
    if MSC.UpdateAllQuestOverlays then MSC.UpdateAllQuestOverlays() end
end
local function QueueQuestRefresh()
    if questRefreshPending then return end
    questRefreshPending = true
    -- 0.15s lets the server populate the item links in the UI
    C_Timer.After(0.15, RunQuestRefresh)
end

-- GET_ITEM_INFO_RECEIVED arrives in storms (e.g. TRADE_SKILL_SHOW queries every
-- recipe), so one coalesced job refreshes the visible windows per burst.
local itemInfoRefreshPending = false
local function RunItemInfoRefresh()
    itemInfoRefreshPending = false
    if MSC.FlushEvaluationCacheWipe then MSC.FlushEvaluationCacheWipe() end

    -- NPC Windows
    if QuestInfoFrame and QuestInfoFrame:IsVisible() then
        if MSC.UpdateQuestOverlays then MSC.UpdateQuestOverlays() end
        if MSC.UpdateQuestAcceptOverlays then MSC.UpdateQuestAcceptOverlays() end
    end
    -- Quest Log Window
    if QuestLogFrame and QuestLogFrame:IsVisible() then
        if MSC.UpdateQuestLogOverlays then MSC.UpdateQuestLogOverlays() end
    end
    -- Merchant Window
    if MerchantFrame and MerchantFrame:IsVisible() then
        if MSC.UpdateMerchantOverlays then MSC.UpdateMerchantOverlays() end
    end
    -- Crafting / Trade Skill
    if TradeSkillFrame and TradeSkillFrame:IsShown() then
        if MSC.UpdateTradeSkillOverlays then MSC.UpdateTradeSkillOverlays() end
    end
    if CraftFrame and CraftFrame:IsShown() and MSC.UpdateCraftOverlays then
        MSC.UpdateCraftOverlays()
    end
    -- TSM compatibility
    if TSM_API and TSM_API.IsWindowVisible and TSM_API.IsWindowVisible("CRAFTING") then
        if MSC.UpdateTSMOverlays then MSC.UpdateTSMOverlays() end
    end

    if MSC.QueueBagOverlayRefresh then MSC.QueueBagOverlayRefresh() end
end
local function QueueItemInfoRefresh()
    if itemInfoRefreshPending then return end
    itemInfoRefreshPending = true
    C_Timer.After(0.15, RunItemInfoRefresh)
end

function MSC.GetFromPool(poolType, parent, creatorFunc)
    if not MSC.Pools[poolType] then MSC.Pools[poolType] = {} end
    for _, frame in ipairs(MSC.Pools[poolType]) do
        if not frame:IsShown() then
            frame:SetParent(parent)
            frame:Show()
            return frame
        end
    end
    local newFrame = creatorFunc(parent)
    table_insert(MSC.Pools[poolType], newFrame)
    return newFrame
end

MSC.RegisteredTabs = {
    { id=1, icon="Interface\\Icons\\INV_Sword_04", name=MSC.L["Weapon Thunderdome"], funcName="InitLabView", view="ViewLab", update="UpdateLabCalc" },
    { id=2, icon="Interface\\Icons\\INV_Misc_Note_02", name=MSC.L["Receipt"], funcName="InitReceiptView", view="ViewReceipt", update="UpdateReceipt" },
    { id=3, icon="Interface\\Icons\\Spell_Holy_MindVision", name=MSC.L["Stat Logic"], funcName="InitLogicView", view="ViewLogic", update="UpdateLogic" },
    { id=4, icon="Interface\\Icons\\INV_Gizmo_02", name=MSC.L["Protocol"], funcName="InitSettingsView", view="ViewSettings" }
}

if not MSC.GetInspectSpec then function MSC.GetInspectSpec(unit) return "Default" end end

local function CopyTable(src)
    if not src then return {} end
    local dest = {}
    for k, v in pairs(src) do dest[k] = v end
    return dest
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("QUEST_COMPLETE")         
eventFrame:RegisterEvent("QUEST_DETAIL")         
eventFrame:RegisterEvent("QUEST_PROGRESS")         
eventFrame:RegisterEvent("QUEST_ITEM_UPDATE")
eventFrame:RegisterEvent("START_LOOT_ROLL")         
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
-- Classic Enchanting window only; Forever has no Craft frame or CRAFT_SHOW,
-- and registering an unknown event raises an error there.
pcall(eventFrame.RegisterEvent, eventFrame, "CRAFT_SHOW")
-- An item's Equip:/Use: text loads with its spell, after the item itself.
pcall(eventFrame.RegisterEvent, eventFrame, "SPELL_DATA_LOAD_RESULT")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2) 
    if event == "BAG_UPDATE" then 
        -- The Receipt reads MSC.BagCacheDirty (BagCache.Dirty was never read).
        MSC.BagCacheDirty = true
        if RequestUpdate then RequestUpdate() end

    elseif event == "QUEST_COMPLETE" or event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_ITEM_UPDATE" then
        QueueQuestRefresh()

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Login and /reload read every worn and bag item at once, mostly before
        -- their Equip: text has loaded. Read them all again once it has.
        -- arg1 = initial login, arg2 = /reload; zoning needs no reread.
        if arg1 or arg2 then
            for _, delay in ipairs({ 8, 25 }) do
                C_Timer.After(delay, function()
                    if MSC.DropAllScans then MSC.DropAllScans() end
                    MSC.BagCacheDirty = true
                    QueueItemInfoRefresh()
                end)
            end
        end

    elseif event == "SPELL_DATA_LOAD_RESULT" then
        -- Rescan items scanned just before their Equip: text arrived (quest
        -- rewards read as soon as the quest frame opens), then redraw.
        if MSC.DropRecentScans and MSC.DropRecentScans() then QueueItemInfoRefresh() end

	elseif event == "START_LOOT_ROLL" then
        -- A tiny 0.1s delay ensures the Blizzard UI has finished creating the frame and assigning the rollID
        C_Timer.After(0.1, function()
            if MSC.UpdateLootRollOverlays then MSC.UpdateLootRollOverlays() end
        end)
        
    elseif event == "ADDON_LOADED" and (arg1 == "Blizzard_TradeSkillUI" or arg1 == "Blizzard_CraftUI" or arg1 == "Blizzard_Professions") then
        MSC.HookProfessionWindows()

    elseif event == "CRAFT_SHOW" then
        C_Timer.After(0.05, MSC.UpdateCraftOverlays)

		elseif event == "TRADE_SKILL_SHOW" then
            if MSC.UpdateTradeSkillOverlays then MSC.UpdateTradeSkillOverlays() end
            
            -- Fetch Cache
            if not GetNumTradeSkills then return end
            local numRecipes = GetNumTradeSkills()
            if numRecipes and numRecipes > 0 then
                for i = 1, numRecipes do
                    local link = GetTradeSkillItemLink(i)
                    if link then GetItemInfo(link) end
                end
            end
        
		elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = tonumber(arg1)

        -- Window overlays, TSM and bag arrows refresh once per burst
        -- (the EvaluationCache wipe is coalesced in Evaluator.lua).
        QueueItemInfoRefresh()

        if itemID and GameTooltip:IsVisible() then
            local _, link = MSC_GetTooltipItem(GameTooltip)
            if not link and MSC.HoveredQuestLink then link = MSC.HoveredQuestLink end

            -- Exact id match: "item:123" must not match "item:1234"
            if link and tonumber(link:match("item:(%d+)")) == itemID then
                 if RequestUpdate then RequestUpdate() end
                 if MSC.FlushEvaluationCacheWipe then MSC.FlushEvaluationCacheWipe() end
                 if MSC.EvaluateAndDrawTooltip then
                     MSC.EvaluateAndDrawTooltip(GameTooltip) 
                 end
            end
        end
	end	
end)

function MSC.GetClassColor()
    local _, class = UnitClass("player")
    local c = (class and RAID_CLASS_COLORS[class]) or {r=1, g=0.82, b=0}
    return c.r, c.g, c.b, 1
end

function MSC.CreateModernBorder(f, thickness)
    if not f.border then
        f.border = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.border:SetPoint("TOPLEFT", -1, 1); f.border:SetPoint("BOTTOMRIGHT", 1, -1)
        f.border:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = thickness or 1, bgFile = "Interface\\Buttons\\WHITE8X8"})
        f.border:SetBackdropBorderColor(0,0,0,1); f.border:SetBackdropColor(0,0,0,0)
        f.border:SetFrameLevel(f:GetFrameLevel() + 10)
    end
end

-- [[ CLIENT-SAFE PANEL SKIN ]]
-- Flat theme panel on any BackdropTemplate frame. Without SetBackdrop, fall back
-- to the modern NineSlice skin (retail/Forever only: Era and TBC Anniversary lack
-- NineSliceUtil, and an unguarded call blanks the whole /sgj window).
function MSC.ApplyPanelSkin(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        frame:SetBackdropColor(unpack(MSC.Theme.Panel))
        frame:SetBackdropBorderColor(unpack(MSC.Theme.Edge))
    elseif NineSliceUtil and NineSliceUtil.ApplyLayoutByName then
        pcall(NineSliceUtil.ApplyLayoutByName, frame, "TooltipDefaultDarkLayout")
    end
end

-- =============================================================
-- 2. VIEW DEFINITIONS
-- =============================================================

-- Layout: how to use + clear (left) | the six weapon setups, set 1 and set 2 side by side (centre) | result and ranking (right)
local LAB_LEFT_W, LAB_RIGHT_W = 200, 220

function MSC.InitLabView(parent)
    local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()

    -- ==========================================
    -- COLUMNS
    -- ==========================================
    local L = CreateFrame("Frame", nil, f)
    L:SetPoint("TOPLEFT"); L:SetPoint("BOTTOMLEFT"); L:SetWidth(LAB_LEFT_W)
    local R = CreateFrame("Frame", nil, f)
    R:SetPoint("TOPRIGHT"); R:SetPoint("BOTTOMRIGHT"); R:SetWidth(LAB_RIGHT_W)
    local C = CreateFrame("Frame", nil, f)
    C:SetPoint("TOPLEFT", L, "TOPRIGHT"); C:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT")
    for _, col in ipairs({ L, R }) do
        local shade = col:CreateTexture(nil, "BACKGROUND"); shade:SetAllPoints(); shade:SetColorTexture(0, 0, 0, 0.25)
    end
    local function Divider(col, side)
        local t = col:CreateTexture(nil, "BORDER"); t:SetColorTexture(1, 1, 1, 0.08); t:SetWidth(1)
        t:SetPoint("TOP" .. side, 0, 0); t:SetPoint("BOTTOM" .. side, 0, 0)
    end
    Divider(L, "RIGHT"); Divider(R, "LEFT")

    -- ==========================================
    -- LEFT: PROFILE, HOW TO USE, CLEAR
    -- ==========================================
    local innerW = LAB_LEFT_W - 28
    local title = L:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12); title:SetText(MSC.L["Weapon Thunderdome"]); MSC.StyleHeading(title, "Gold", innerW)

    local profLbl = L:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profLbl:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14); profLbl:SetText(MSC.L["Scoring Profile"]); profLbl:SetTextColor(0.6, 0.6, 0.6)
    f.Profile = L:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Profile:SetPoint("TOPLEFT", profLbl, "BOTTOMLEFT", 0, -3); f.Profile:SetWidth(innerW); f.Profile:SetJustifyH("LEFT")

    local howLbl = L:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    howLbl:SetPoint("TOPLEFT", f.Profile, "BOTTOMLEFT", 0, -20); howLbl:SetText(MSC.L["How to Use"]); MSC.StyleHeading(howLbl, "Teal", innerW)
    local help = L:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", howLbl, "BOTTOMLEFT", 0, -11); help:SetWidth(innerW); help:SetJustifyH("LEFT")
    help:SetText(MSC.L["Drag (Shift/Ctrl+Click) items to compare. 6 Sets Enter, 1 Set Wins!"]); help:SetTextColor(0.75, 0.75, 0.75)
    local help2 = L:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help2:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -8); help2:SetWidth(innerW); help2:SetJustifyH("LEFT")
    help2:SetText(MSC.L["Shift-click a filled slot to empty it."]); help2:SetTextColor(0.75, 0.75, 0.75)

    local bClear = CreateFrame("Button", nil, L, "UIPanelButtonTemplate")
    bClear:SetSize(LAB_LEFT_W - 24, 26); bClear:SetPoint("BOTTOMLEFT", 12, 14)
    bClear:SetText(MSC.L["Clear All"])
    bClear:SetScript("OnClick", function()
        for _, block in pairs(MSC.LabBlocks) do
            for _, btn in ipairs(block.Slots) do
                btn.link = nil
                SetItemButtonTexture(btn, nil)
            end
        end
        MSC.UpdateLabCalc()
    end)

    -- ==========================================
    -- CENTRE: SIX WEAPON SETUPS (set 1 left, set 2 right)
    -- ==========================================
    MSC.LabBlocks = {}
    local GAP = 12
    local blockW = (830 - LAB_LEFT_W - LAB_RIGHT_W - GAP * 3) / 2
    local blockH = 110

    for i, setName in ipairs({ MSC.L["Set 1"], MSC.L["Set 2"] }) do
        local h = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", GAP + (i - 1) * (blockW + GAP), -12); h:SetText(setName); MSC.StyleHeading(h, "Gold", blockW)
    end

    local function CreateBlock(id, title, numSlots, col, row)
        local frame = CreateFrame("Frame", nil, C, "BackdropTemplate")
        frame:SetSize(blockW, blockH)
        frame:SetPoint("TOPLEFT", GAP + (col - 1) * (blockW + GAP), -36 - (row - 1) * (blockH + GAP))
        MSC.ApplyPanelSkin(frame)

        -- Title on its own line; the score sits beside the slots so the two never overlap
        frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal"); frame.Title:SetPoint("TOPLEFT", 10, -9)
        frame.Title:SetPoint("RIGHT", -10, 0); frame.Title:SetJustifyH("LEFT"); frame.Title:SetWordWrap(false); frame.Title:SetText(title); frame.Title:SetTextColor(unpack(MSC.Theme.Text))
        frame.Score = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); frame.Score:SetPoint("BOTTOMRIGHT", -12, 14); frame.Score:SetText("")

        frame.Slots = {}
        for i=1, numSlots do
            local btn = CreateFrame("Button", nil, frame, nil)
            btn:SetSize(40, 40)
            btn:SetPoint("BOTTOMLEFT", 12 + (i - 1) * 48, 12)
            btn.Empty = btn:CreateTexture(nil, "BACKGROUND", nil, -1); btn.Empty:SetAllPoints()
            local dualWield = (id == 3 or id == 6)
            btn.Empty:SetTexture("Interface\\Paperdoll\\UI-PaperDoll-Slot-" .. ((i == 1 or dualWield) and "MainHand" or "SecondaryHand"))

            btn:RegisterForClicks("AnyUp")
            btn:SetScript("OnClick", function(self)
                local type, _, link = GetCursorInfo()
                if type == "item" then
                    self.link = link; SetItemButtonTexture(self, GetItemIcon(link)); ClearCursor()
                elseif IsShiftKeyDown() then
                    self.link = nil; SetItemButtonTexture(self, nil)
                end
                MSC.UpdateLabCalc()
            end)
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.link then
                    GameTooltip:SetHyperlink(self.link)
                else
                    GameTooltip:SetText(title, 1, 1, 1)
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", GameTooltip_Hide)
            table_insert(frame.Slots, btn)
        end
        MSC.LabBlocks[id] = frame
    end

    CreateBlock(1, MSC.L["Option A1: Two-Hander"], 1, 1, 1)
    CreateBlock(2, MSC.L["Option B1: 1H + Shield/OH"], 2, 1, 2)
    CreateBlock(3, MSC.L["Option C1: Dual Wield"], 2, 1, 3)
    CreateBlock(4, MSC.L["Option A2: Two-Hander"], 1, 2, 1)
    CreateBlock(5, MSC.L["Option B2: 1H + Shield/OH"], 2, 2, 2)
    CreateBlock(6, MSC.L["Option C2: Dual Wield"], 2, 2, 3)

    -- ==========================================
    -- RIGHT: RESULT AND RANKING
    -- ==========================================
    local resLbl = R:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resLbl:SetPoint("TOPLEFT", 14, -12); resLbl:SetText(MSC.L["Result"]); MSC.StyleHeading(resLbl, "Green", LAB_RIGHT_W - 28)

    f.ResultText = R:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.ResultText:SetPoint("TOPLEFT", resLbl, "BOTTOMLEFT", 0, -14)
    f.ResultText:SetWidth(LAB_RIGHT_W - 28); f.ResultText:SetJustifyH("LEFT"); f.ResultText:SetText(MSC.L["Waiting for Items..."])
    f.ResultTextAnim = f.ResultText:CreateAnimationGroup()
    local scale = f.ResultTextAnim:CreateAnimation("Scale")
    scale:SetScaleFrom(0.5, 0.5); scale:SetScaleTo(1.2, 1.2); scale:SetDuration(0.2); scale:SetSmoothing("OUT"); scale:SetOrder(1)
    local scale2 = f.ResultTextAnim:CreateAnimation("Scale")
    scale2:SetScaleFrom(1.2, 1.2); scale2:SetScaleTo(1.0, 1.0); scale2:SetDuration(0.15); scale2:SetSmoothing("IN_OUT"); scale2:SetOrder(2)
    local alpha = f.ResultTextAnim:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0); alpha:SetToAlpha(1); alpha:SetDuration(0.2); alpha:SetOrder(1)

    local rankLbl = R:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankLbl:SetPoint("TOPLEFT", 14, -110); rankLbl:SetText(MSC.L["Ranking"]); MSC.StyleHeading(rankLbl, "Blue", LAB_RIGHT_W - 28)
    f.NoRank = R:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.NoRank:SetPoint("TOPLEFT", rankLbl, "BOTTOMLEFT", 0, -12); f.NoRank:SetText(MSC.L["Add weapons to a setup to rank it."]); f.NoRank:SetTextColor(0.6, 0.6, 0.6)
    f.NoRank:SetWidth(LAB_RIGHT_W - 28); f.NoRank:SetJustifyH("LEFT")

    f.RankRows = {}
    for i = 1, 6 do
        local row = CreateFrame("Frame", nil, R); row:SetSize(LAB_RIGHT_W - 28, 20)
        row:SetPoint("TOPLEFT", rankLbl, "BOTTOMLEFT", 0, -12 - (i - 1) * 22)
        local line = row:CreateTexture(nil, "BACKGROUND"); line:SetColorTexture(1, 1, 1, 0.05); line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
        row.Score = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.Score:SetPoint("RIGHT")
        row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.Name:SetPoint("LEFT")
        row.Name:SetPoint("RIGHT", row.Score, "LEFT", -6, 0); row.Name:SetJustifyH("LEFT"); row.Name:SetWordWrap(false)
        row:Hide()
        f.RankRows[i] = row
    end

    f:SetScript("OnShow", function() MSC.UpdateLabCalc() end)
    MSC.ViewLab = f
end

function MSC.UpdateLabCalc()
    if not MSC.ViewLab or not MSC.ViewLab:IsShown() then return end
    
    local weights, profileName = MSC.GetCurrentWeights()
    if not weights then return end 
    
    local bestScore = -1
    local winnerIndex = 0
    local hasItems = false

    local names = {
        MSC.L["Option A1 (2H)"], MSC.L["Option B1 (1H+OH)"], MSC.L["Option C1 (DW)"],
        MSC.L["Option A2 (2H)"], MSC.L["Option B2 (1H+OH)"], MSC.L["Option C2 (DW)"]
    }

    for id, block in pairs(MSC.LabBlocks) do
        local blockScore = 0
        local itemsFound = false
        
        for i, btn in ipairs(block.Slots) do
            if btn.link then
                itemsFound = true
                local slotID = (i == 1) and 16 or 17
                local stats = MSC.SafeGetItemStats(btn.link, slotID, weights, profileName)
                local score = MSC.GetItemScore(stats, weights, profileName, slotID)
                blockScore = blockScore + score
            end
        end
        
        if itemsFound then
            hasItems = true
            block.Score:SetText(string_format("%.1f", blockScore))
            block.finalScore = blockScore
            if blockScore > bestScore then
                bestScore = blockScore
                winnerIndex = id
            end
        else
            block.Score:SetText("")
            block.finalScore = -1
        end
    end
    
    for id, block in pairs(MSC.LabBlocks) do
        if not hasItems then
            block:SetAlpha(1)
            MSC.ViewLab.ResultText:SetText(MSC.L["Waiting for Items..."])
            MSC.ViewLab.ResultText:SetTextColor(1, 0.82, 0)
        elseif id == winnerIndex then
            block:SetAlpha(1)
            block.Score:SetTextColor(0, 1, 0)
        else
            block:SetAlpha(0.4)
            block.Score:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    
    if hasItems then
        local delta = bestScore
        local runnerUpScore = 0
        for id, block in pairs(MSC.LabBlocks) do
            if id ~= winnerIndex and block.finalScore > runnerUpScore then runnerUpScore = block.finalScore end
        end
        if runnerUpScore > 0 then delta = bestScore - runnerUpScore end
        
        MSC.ViewLab.ResultText:SetText(string_format(MSC.L["%s Wins! (+%s)"], names[winnerIndex], string_format("%.1f", delta)))
        MSC.ViewLab.ResultText:SetTextColor(0, 1, 0)
        
        if MSC.ViewLab.lastWinner ~= winnerIndex then
            if MSC.ViewLab.ResultTextAnim then MSC.ViewLab.ResultTextAnim:Play() end
            MSC.ViewLab.lastWinner = winnerIndex
        end
    else
        MSC.ViewLab.lastWinner = nil
    end

    -- [[ PROFILE AND RANKING (side columns) ]]
    local view = MSC.ViewLab
    if view.Profile then view.Profile:SetText((MSC.PrettyNames and MSC.PrettyNames[profileName]) or profileName or "") end
    if view.RankRows then
        local ranked = {}
        for id, block in pairs(MSC.LabBlocks) do
            if block.finalScore and block.finalScore >= 0 then table_insert(ranked, { id = id, score = block.finalScore }) end
        end
        table_sort(ranked, function(x, y) return x.score > y.score end)
        for i, row in ipairs(view.RankRows) do
            local r = ranked[i]
            if r then
                local won = (r.id == winnerIndex)
                row.Name:SetText(names[r.id]); row.Score:SetText(string_format("%.1f", r.score))
                if won then row.Name:SetTextColor(0, 1, 0); row.Score:SetTextColor(0, 1, 0)
                else row.Name:SetTextColor(0.8, 0.8, 0.8); row.Score:SetTextColor(0.6, 0.6, 0.6) end
                row:Show()
            else
                row:Hide()
            end
        end
        view.NoRank:SetShown(#ranked == 0)
    end
end

-- Layout: your gear summary (left) | character and slots (centre) | stat totals (right)
local RECEIPT_LEFT_W, RECEIPT_RIGHT_W = 200, 220
local RECEIPT_SLOT, RECEIPT_SLOT_TOP, RECEIPT_SLOT_STEP = 37, -40, 54
local RECEIPT_STAT_ROWS = 24

-- col: L/R = columns beside the model (row 1 at top), W = weapon row under the feet
local RECEIPT_SLOTS = {
    { id=1,  name="Head",      col="L", row=1, tex="Head" },
    { id=2,  name="Neck",      col="L", row=2, tex="Neck" },
    { id=3,  name="Shoulder",  col="L", row=3, tex="Shoulder" },
    { id=15, name="Back",      col="L", row=4, tex="Chest" },
    { id=5,  name="Chest",     col="L", row=5, tex="Chest" },
    { id=9,  name="Wrist",     col="L", row=6, tex="Wrists" },
    { id=10, name="Hands",     col="L", row=7, tex="Hands" },
    { id=6,  name="Waist",     col="R", row=1, tex="Waist" },
    { id=7,  name="Legs",      col="R", row=2, tex="Legs" },
    { id=8,  name="Feet",      col="R", row=3, tex="Feet" },
    { id=11, name="Ring 1",    col="R", row=4, tex="Finger" },
    { id=12, name="Ring 2",    col="R", row=5, tex="Finger" },
    { id=13, name="Trinket 1", col="R", row=6, tex="Trinket" },
    { id=14, name="Trinket 2", col="R", row=7, tex="Trinket" },
    { id=16, name="Main Hand", col="W", row=1, tex="MainHand" },
    { id=17, name="Off Hand",  col="W", row=2, tex="SecondaryHand" },
    { id=18, name="Ranged",    col="W", row=3, tex="Ranged" },
}

-- Briefly pulse every Receipt slot that carries the given alert ("Enchant" or "Upgrade")
local function FlashReceiptSlots(kind)
    for _, btn in ipairs(MSC.ReceiptSlots) do
        if (kind == "Enchant" and btn.MissingEnchant) or (kind == "Upgrade" and btn.BagUpgrade) then
            btn.Flash:Stop(); btn.Glow:Show(); btn.Flash:Play()
        end
    end
end

function MSC.InitReceiptView(parent)
    local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()

    -- ==========================================
    -- COLUMNS
    -- ==========================================
    f.LeftCol = CreateFrame("Frame", nil, f)
    f.LeftCol:SetPoint("TOPLEFT"); f.LeftCol:SetPoint("BOTTOMLEFT"); f.LeftCol:SetWidth(RECEIPT_LEFT_W)
    f.RightCol = CreateFrame("Frame", nil, f)
    f.RightCol:SetPoint("TOPRIGHT"); f.RightCol:SetPoint("BOTTOMRIGHT"); f.RightCol:SetWidth(RECEIPT_RIGHT_W)
    f.Center = CreateFrame("Frame", nil, f)
    f.Center:SetPoint("TOPLEFT", f.LeftCol, "TOPRIGHT"); f.Center:SetPoint("BOTTOMRIGHT", f.RightCol, "BOTTOMLEFT")

    for _, col in ipairs({ f.LeftCol, f.RightCol }) do
        local shade = col:CreateTexture(nil, "BACKGROUND"); shade:SetAllPoints(); shade:SetColorTexture(0, 0, 0, 0.25)
    end
    local function Divider(col, side)
        local t = col:CreateTexture(nil, "BORDER"); t:SetColorTexture(1, 1, 1, 0.08); t:SetWidth(1)
        t:SetPoint("TOP" .. side, 0, 0); t:SetPoint("BOTTOM" .. side, 0, 0)
    end
    Divider(f.LeftCol, "RIGHT"); Divider(f.RightCol, "LEFT")

    -- ==========================================
    -- LEFT: PROFILE, TOTAL SCORE, ALERTS
    -- ==========================================
    local L = f.LeftCol
    local innerW = RECEIPT_LEFT_W - 28

    local header = L:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 14, -12); header:SetText(MSC.L["Your Gear"]); MSC.StyleHeading(header, "Gold", innerW)

    local profLbl = L:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profLbl:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -14); profLbl:SetText(MSC.L["Profile"]); profLbl:SetTextColor(0.6, 0.6, 0.6)
    f.Info = L:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.Info:SetPoint("TOPLEFT", profLbl, "BOTTOMLEFT", 0, -3); f.Info:SetWidth(innerW); f.Info:SetJustifyH("LEFT")

    local scoreLbl = L:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scoreLbl:SetPoint("TOPLEFT", f.Info, "BOTTOMLEFT", 0, -14); scoreLbl:SetText(MSC.L["Total Score"]); scoreLbl:SetTextColor(0.6, 0.6, 0.6)
    f.Score = L:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.Score:SetPoint("TOPLEFT", scoreLbl, "BOTTOMLEFT", 0, -4)
    f.Score:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE"); f.Score:SetTextColor(0, 1, 0)

    local alertHdr = L:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alertHdr:SetPoint("TOPLEFT", f.Score, "BOTTOMLEFT", 0, -22); alertHdr:SetText(MSC.L["Alerts"]); MSC.StyleHeading(alertHdr, "Red", innerW)

    local function AlertLine(anchor, icon, kind)
        local b = CreateFrame("Button", nil, L)
        b:SetSize(innerW, 18); b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, anchor == alertHdr and -11 or -6)
        b.Icon = b:CreateTexture(nil, "ARTWORK"); b.Icon:SetSize(16, 16); b.Icon:SetPoint("LEFT"); b.Icon:SetTexture(icon)
        b.Text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.Text:SetPoint("LEFT", b.Icon, "RIGHT", 4, 0); b.Text:SetTextColor(1, 0.65, 0.2)
        b:SetScript("OnClick", function() FlashReceiptSlots(kind) end)
        b:SetScript("OnEnter", function(self) self.Text:SetTextColor(1, 0.85, 0.4) end)
        b:SetScript("OnLeave", function(self) self.Text:SetTextColor(1, 0.65, 0.2) end)
        return b
    end
    f.EnchantAlert = AlertLine(alertHdr, "Interface\\DialogFrame\\UI-Dialog-Icon-AlertOther", "Enchant")
    f.UpgradeAlert = AlertLine(f.EnchantAlert, "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew", "Upgrade")

    f.NoAlerts = L:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.NoAlerts:SetPoint("TOPLEFT", alertHdr, "BOTTOMLEFT", 0, -11); f.NoAlerts:SetText(MSC.L["No alerts"]); f.NoAlerts:SetTextColor(0.6, 0.6, 0.6)

    f.AlertHint = L:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.AlertHint:SetPoint("TOPLEFT", f.UpgradeAlert, "BOTTOMLEFT", 0, -8); f.AlertHint:SetWidth(innerW); f.AlertHint:SetJustifyH("LEFT")
    f.AlertHint:SetText(MSC.L["Click an alert to highlight its slots."]); f.AlertHint:SetTextColor(0.5, 0.5, 0.5)

    -- ==========================================
    -- CENTRE: CHARACTER MODEL AND SLOTS
    -- ==========================================
    local C = f.Center
    local SIDE_W = RECEIPT_SLOT + 2 + 40 + 2 + 16 -- slot, score badge, alert icon

    -- Mouse-wheel zoom: some clients' DressUpModel has no Get/SetPortraitZoom (a wheel turn
    -- errored in the Roadmap's copy of this); then the camera distance is scaled instead.
    local function ZoomModel(m, delta)
        if m.GetPortraitZoom and m.SetPortraitZoom then
            local z = (m:GetPortraitZoom() or 0) + (delta > 0 and 0.1 or -0.1)
            m:SetPortraitZoom(math.max(m.minZoom or 0, math.min(m.maxZoom or 1, z)))
        elseif m.SetCamDistanceScale then
            m.sgjZoom = math.max(0.4, math.min(1.6, (m.sgjZoom or 1) - delta * 0.1))
            m:SetCamDistanceScale(m.sgjZoom)
        end
    end
    local function ResetZoom(m)
        if m.SetPortraitZoom then m:SetPortraitZoom(0) end
        if m.SetCamDistanceScale then m.sgjZoom = 1; m:SetCamDistanceScale(1) end
    end
    pcall(function()
        f.Model = CreateFrame("DressUpModel", nil, C, "ModelWithControlsTemplate")
        f.Model:SetPoint("TOPLEFT", C, "TOPLEFT", SIDE_W + 8, -30)
        f.Model:SetPoint("BOTTOMRIGHT", C, "BOTTOMRIGHT", -(SIDE_W + 8), 90)
        f.Model:SetUnit("player")
        f.Model:SetScript("OnMouseWheel", ZoomModel)
        f.Model:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self.prevX = GetCursorPosition()
                self:SetScript("OnUpdate", function(m) local cx = GetCursorPosition(); m:SetFacing(m:GetFacing() + (cx - m.prevX) * 0.01); m.prevX = cx end)
            elseif button == "RightButton" then self:SetUnit("player"); ResetZoom(self) end
        end)
        f.Model:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    end)

    local title = C:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -12); title:SetText(MSC.L["Equipped"]); MSC.StyleHeading(title, "Gold")

    local hint = C:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOM", 0, 10); hint:SetText(MSC.L["Click a slot for its score breakdown"]); hint:SetTextColor(0.5, 0.5, 0.5)

    local _, playerClass = UnitClass("player")
    local relicClass = (playerClass == "PALADIN" or playerClass == "SHAMAN" or playerClass == "DRUID")

    for _, s in ipairs(RECEIPT_SLOTS) do
        local label = MSC.L[s.name]
        local btn = CreateFrame("Button", nil, C); btn:SetSize(RECEIPT_SLOT, RECEIPT_SLOT)
        local y = RECEIPT_SLOT_TOP - (s.row - 1) * RECEIPT_SLOT_STEP
        if s.col == "L" then btn:SetPoint("TOPLEFT", C, "TOPLEFT", 8, y)
        elseif s.col == "R" then btn:SetPoint("TOPRIGHT", C, "TOPRIGHT", -8, y)
        else btn:SetPoint("BOTTOM", C, "BOTTOM", (s.row - 2) * 70, 50) end

        local tex = (s.id == 18 and relicClass) and "Relic" or s.tex
        btn.EmptyTexture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-" .. tex

        -- Score badge: right of the slot on the left column, left of it on the right column, under it for weapons
        btn.ScoreFrame = CreateFrame("Frame", nil, btn, "BackdropTemplate"); btn.ScoreFrame:SetSize(40, 20)
        MSC.ApplyPanelSkin(btn.ScoreFrame)
        btn.ScoreText = btn.ScoreFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); btn.ScoreText:SetPoint("CENTER"); btn.ScoreText:SetTextColor(1, 0.9, 0)
        btn.Alert = btn:CreateTexture(nil, "OVERLAY"); btn.Alert:SetSize(16, 16); btn.Alert:Hide()
        if s.col == "L" then
            btn.ScoreFrame:SetPoint("LEFT", btn, "RIGHT", 2, 0); btn.Alert:SetPoint("LEFT", btn.ScoreFrame, "RIGHT", 2, 0)
        elseif s.col == "R" then
            btn.ScoreFrame:SetPoint("RIGHT", btn, "LEFT", -2, 0); btn.Alert:SetPoint("RIGHT", btn.ScoreFrame, "LEFT", -2, 0)
        else
            btn.ScoreFrame:SetPoint("TOP", btn, "BOTTOM", 0, -2); btn.Alert:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 6, 6)
        end

        -- Highlight used when an alert line is clicked
        btn.Glow = btn:CreateTexture(nil, "OVERLAY", nil, 2)
        btn.Glow:SetSize(RECEIPT_SLOT * 1.8, RECEIPT_SLOT * 1.8); btn.Glow:SetPoint("CENTER")
        btn.Glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); btn.Glow:SetBlendMode("ADD"); btn.Glow:SetVertexColor(1, 0.7, 0.1); btn.Glow:Hide()
        btn.Flash = btn.Glow:CreateAnimationGroup()
        local fa = btn.Flash:CreateAnimation("Alpha"); fa:SetFromAlpha(1); fa:SetToAlpha(0.15); fa:SetDuration(0.35); fa:SetSmoothing("IN_OUT")
        btn.Flash:SetLooping("BOUNCE")
        btn.Flash:SetScript("OnLoop", function(self) self.loops = (self.loops or 0) + 1; if self.loops >= 6 then self.loops = 0; self:Stop(); btn.Glow:Hide() end end)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.link then GameTooltip:SetHyperlink(self.link) else GameTooltip:SetText(label, 1, 1, 1) end
            if self.MissingEnchant or self.BagUpgrade then GameTooltip:AddLine(" ") end
            if self.MissingEnchant then GameTooltip:AddLine(MSC.L["Missing Enchant!"], 1, 0, 0) end
            if self.BagUpgrade then GameTooltip:AddLine(MSC.L["Better item in bags!"], 1, 0, 0) end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)

        btn:RegisterForClicks("AnyUp")
        btn:SetScript("OnClick", function(self) if self.link then MSC:ShowScoreBreakdown(self.link, self.SlotID) end end)

        btn.SlotID = s.id; table_insert(MSC.ReceiptSlots, btn)
    end

    -- ==========================================
    -- RIGHT: STAT TOTALS
    -- ==========================================
    local R = f.RightCol
    local statHdr = R:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statHdr:SetPoint("TOPLEFT", 14, -12); statHdr:SetText(MSC.L["Stat Totals"]); MSC.StyleHeading(statHdr, "Blue", RECEIPT_RIGHT_W - 28)
    local statSub = R:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statSub:SetPoint("TOPLEFT", statHdr, "BOTTOMLEFT", 0, -9); statSub:SetText(MSC.L["Weighted stats from all your gear"]); statSub:SetTextColor(0.6, 0.6, 0.6)

    MSC.SummaryRows = {}
    local rowW = RECEIPT_RIGHT_W - 28
    for i = 1, RECEIPT_STAT_ROWS do
        local row = CreateFrame("Frame", nil, R); row:SetSize(rowW, 18)
        row:SetPoint("TOPLEFT", statSub, "BOTTOMLEFT", 0, -10 - (i - 1) * 20)
        local line = row:CreateTexture(nil, "BACKGROUND"); line:SetColorTexture(1, 1, 1, 0.05); line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
        row.Value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.Value:SetPoint("RIGHT", 0, 0); row.Value:SetJustifyH("RIGHT"); row.Value:SetTextColor(unpack(MSC.Theme.Value))
        row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); row.Label:SetPoint("LEFT", 0, 0)
        row.Label:SetPoint("RIGHT", row.Value, "LEFT", -6, 0); row.Label:SetJustifyH("LEFT"); row.Label:SetWordWrap(false); row.Label:SetTextColor(unpack(MSC.Theme.Text))
        table_insert(MSC.SummaryRows, row)
    end

    f:SetScript("OnShow", function() if f.Model then f.Model:SetUnit("player") end; MSC.UpdateReceipt() end)
    MSC.ViewReceipt = f
end

function MSC.UpdateReceipt()
    -- [[ LAZY LOADING OPTIMIZATION ]]
    if not MSC.ViewReceipt or not MSC.ViewReceipt:IsShown() then 
        MSC.BagCacheDirty = true 
        return 
    end

    local unit = "player"; local weights, specName = MSC.GetCurrentWeights()
    if not weights and MSC.CurrentClass and MSC.CurrentClass.Weights then specName, weights = next(MSC.CurrentClass.Weights) end
    if not weights then return end

    local displayName = (MSC.PrettyNames and MSC.PrettyNames[specName]) or specName
    MSC.ViewReceipt.Info:SetText(displayName)
    
    local gearTable = {}
    for i=1, 18 do 
        local link = GetInventoryItemLink(unit, i)
        if link then gearTable[i] = link end
    end
    local totalScore, combinedStats = MSC:GetTotalCharacterScore(gearTable, weights, specName)
    combinedStats = combinedStats or {}
    MSC.ViewReceipt.Score:SetText(string_format("%.1f", totalScore))
    
    if MSC.BagCacheDirty then
        MSC.BagCache = {}
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local link = GetContainerItemLink(bag, slot)
                if link and MSC.IsItemUsable(link) then
                      local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
                      local slotId = MSC.SlotMap and MSC.SlotMap[equipLoc]
                      if slotId then
                            table_insert(MSC.BagCache, { link = link, slotId = slotId, equipLoc = equipLoc })
                      end
                end
            end
        end
        MSC.BagCacheDirty = false 
    end

    local useFast = (not RXP_SGJ_Settings or RXP_SGJ_Settings.FastBagArrows ~= false)
    local enchantCount, upgradeCount = 0, 0

    for _, btn in ipairs(MSC.ReceiptSlots) do
        local link = GetInventoryItemLink(unit, btn.SlotID)
        btn.link = link; btn.Alert:Hide(); btn.MissingEnchant = nil; btn.BagUpgrade = nil
        if link then
            SetItemButtonTexture(btn, GetInventoryItemTexture(unit, btn.SlotID))
            local stats = MSC.SafeGetItemStats(link, btn.SlotID, weights, specName)
            local score = MSC.GetItemScore(stats, weights, specName, btn.SlotID)
            local whole = math_floor(score)
            if whole > 0 then btn.ScoreText:SetText(whole); btn.ScoreFrame:Show() else btn.ScoreText:SetText(""); btn.ScoreFrame:Hide() end
            
            local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
            if equipLoc ~= "INVTYPE_HOLDABLE" and equipLoc ~= "INVTYPE_TABARD" and equipLoc ~= "INVTYPE_BODY" then
                 local _, enchantID = link:match("item:(%d+):(%d+)")
                 enchantID = tonumber(enchantID) or 0
                 local validSlots = {[1]=true,[3]=true,[5]=true,[7]=true,[8]=true,[9]=true,[10]=true,[15]=true,[16]=true,[17]=true}
                 if validSlots[btn.SlotID] and enchantID == 0 then 
                    btn.Alert:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertOther"); btn.Alert:Show()
                    btn.MissingEnchant = true; enchantCount = enchantCount + 1 
                 end
            end
            local foundUpgrade = false
            for _, cachedItem in ipairs(MSC.BagCache) do
               local isMatch = (cachedItem.slotId == btn.SlotID)
               if btn.SlotID == 11 or btn.SlotID == 12 then if cachedItem.slotId == 11 then isMatch = true end end
               if btn.SlotID == 13 or btn.SlotID == 14 then if cachedItem.slotId == 13 then isMatch = true end end
               if isMatch then
                    local compSlot = MSC.GetComparisonSlot(cachedItem.link, cachedItem.equipLoc, weights, specName) or btn.SlotID
                    if compSlot == btn.SlotID or (btn.SlotID >= 11 and btn.SlotID <= 14) then
                        local newScore, oldScore
                        if useFast and MSC.EvaluateUpgradeFast and MSC.ShouldUseFastEval and MSC:ShouldUseFastEval(cachedItem.link, compSlot) then
                            newScore, oldScore = MSC:EvaluateUpgradeFast(cachedItem.link, compSlot, weights, specName)
                        else
                            newScore, oldScore = MSC:EvaluateUpgrade(cachedItem.link, compSlot, weights, specName)
                        end
                        if newScore and oldScore and newScore > oldScore + MSC.VERDICT_EPS then foundUpgrade = true end
                    end
               end
            end
            if foundUpgrade then 
                btn.Alert:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"); btn.Alert:Show()
                btn.BagUpgrade = true; upgradeCount = upgradeCount + 1 
            end
        else
            SetItemButtonTexture(btn, btn.EmptyTexture or "Interface\\PaperDoll\\UI-Backpack-EmptySlot"); btn.ScoreText:SetText(""); btn.ScoreFrame:Hide()
        end
    end
    
    local sortedStats = {}
    for k, v in pairs(combinedStats) do
        if k ~= "IS_PROJECTED" and k ~= "GEMS_PROJECTED" and k ~= "BONUS_PROJECTED" and v > 0 then
            local weight = weights[k] or 0; if weight > 0 then table_insert(sortedStats, { key=k, val=v, weight=weight }) end
        end
    end
    table_sort(sortedStats, function(a,b) return a.weight > b.weight end)
    for i, row in ipairs(MSC.SummaryRows) do
        if sortedStats[i] then
            row:Show(); local clean = MSC.GetCleanStatName(sortedStats[i].key)
            row.Label:SetText(clean); row.Value:SetText((string_format("%.1f", sortedStats[i].val):gsub("%.0$", "")))
        else row:Hide() end
    end

    -- [[ ALERT SUMMARY (left column) ]]
    local v = MSC.ViewReceipt
    v.EnchantAlert:SetShown(enchantCount > 0)
    v.EnchantAlert.Text:SetText(string_format(enchantCount == 1 and MSC.L["%d missing enchant"] or MSC.L["%d missing enchants"], enchantCount))
    v.UpgradeAlert:ClearAllPoints()
    if enchantCount > 0 then v.UpgradeAlert:SetPoint("TOPLEFT", v.EnchantAlert, "BOTTOMLEFT", 0, -6)
    else v.UpgradeAlert:SetPoint("TOPLEFT", v.EnchantAlert, "TOPLEFT", 0, 0) end
    v.UpgradeAlert:SetShown(upgradeCount > 0)
    v.UpgradeAlert.Text:SetText(string_format(upgradeCount == 1 and MSC.L["%d better item in your bags"] or MSC.L["%d better items in your bags"], upgradeCount))
    v.NoAlerts:SetShown(enchantCount == 0 and upgradeCount == 0)
    v.AlertHint:SetShown(enchantCount > 0 or upgradeCount > 0)
end

-- =============================================================
-- UNIFIED QUEST OVERLAYS (Log, Accept, and Turn-In)
-- =============================================================
function MSC.UpdateAllQuestOverlays()
    local weights, specName = MSC.GetCurrentWeights()
    if not weights then return end

    local buttonsToScan = {}
    local seenButtons = {} -- FIX 1: Local tracking prevents permanent button lockouts

    -- Aggressive grab function that checks every possible WoW link type
    local function AddButton(btn)
        if not btn or not btn:IsVisible() then return end
        if seenButtons[btn] then return end 
        seenButtons[btn] = true

        -- SILENCE ELVUI & BLIZZARD NATIVE ARROWS
        if btn.UpgradeIcon then btn.UpgradeIcon:SetAlpha(0); btn.UpgradeIcon:Hide() end
        if btn.IconOverlay then btn.IconOverlay:SetAlpha(0); btn.IconOverlay:Hide() end

        local id = btn:GetID()
        local name = btn:GetName()
        if not id or id == 0 then
            if name then id = tonumber(name:match("%d+")) end
        end
        if not id then return end

        local bType = btn.type
        if not bType and name then
            if name:find("Choice") then bType = "choice"
            else bType = "reward" end
        end

        local link = nil
        
        -- The foolproof way to know if the UI is looking at the Log or an NPC
        if QuestInfoFrame and QuestInfoFrame.questLog then
            link = GetQuestLogItemLink(bType, id)
        else
            link = GetQuestItemLink(bType, id)
        end
        
        -- Fallback safety net
        if not link then
            link = GetQuestItemLink(bType, id) or GetQuestLogItemLink(bType, id)
        end
        
        if link then table_insert(buttonsToScan, {btn = btn, link = link}) end
    end

    -- 1. Scan global named buttons
    for i = 1, 15 do
        AddButton(_G["QuestLogItem"..i])
        AddButton(_G["QuestRewardItem"..i])
        AddButton(_G["QuestChoiceItem"..i])
        AddButton(_G["QuestDetailItem"..i])
        AddButton(_G["QuestProgressItem"..i])
        AddButton(_G["QuestInfoItem"..i])
    end

    -- 2. Scan dynamically pooled buttons safely WITHOUT triggering Blizzard's frame creation
    if QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons then
        for i = 1, #QuestInfoRewardsFrame.RewardButtons do
            -- rawget prevents the UI from accidentally generating missing buttons
            local rewardBtn = rawget(QuestInfoRewardsFrame.RewardButtons, i)
            
            -- STRICT CHECK: Ensure the button exists, is shown, AND has its Blizzard item link populated
            if rewardBtn and rewardBtn:IsVisible() and rewardBtn.type then
                AddButton(rewardBtn)
            end
        end
    end

    -- 3. Evaluate and Draw
    for _, data in ipairs(buttonsToScan) do
        local btn = data.btn
        local link = data.link
        
        if btn.SGJ_OverlayFrame then btn.SGJ_OverlayFrame:Hide() end
        
        local overlayType = nil
        local itemName, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
        
        if itemName and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" then
            if MSC.IsItemUsable(link) then
                local slotID = MSC.GetComparisonSlot(link, equipLoc, weights, specName)
                if slotID then
                    local newScore, oldScore = MSC:EvaluateUpgrade(link, slotID, weights, specName)
                    if newScore and oldScore then
                        if (newScore > (oldScore + MSC.VERDICT_EPS)) then overlayType = "UP"
                        elseif (oldScore > (newScore + MSC.VERDICT_EPS)) then overlayType = "DOWN" end
                    end
                end
            end
        end

        if overlayType then
            if not btn.SGJ_OverlayFrame then
                btn.SGJ_OverlayFrame = CreateFrame("Frame", nil, btn)
                
                -- Anchor safely to the Icon bounds to prevent ElvUI clipping later
                local icon = (btn.GetName and btn:GetName() and _G[btn:GetName() .. "IconTexture"]) or btn.Icon or btn.icon
                if icon then
                    btn.SGJ_OverlayFrame:SetAllPoints(icon)
                else
                    btn.SGJ_OverlayFrame:SetAllPoints(btn)
                end
                
                btn.SGJ_Overlay = btn.SGJ_OverlayFrame:CreateTexture(nil, "OVERLAY")
                btn.SGJ_Overlay:SetSize(22, 22)
                btn.SGJ_Overlay:SetPoint("TOPRIGHT", btn.SGJ_OverlayFrame, "TOPRIGHT", 2, 2)
            end
            
            -- Set Z-Index high enough to sit safely above backgrounds
            btn.SGJ_OverlayFrame:SetFrameLevel(btn:GetFrameLevel() + 10)
            btn.SGJ_Overlay:SetTexture("Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\" .. (overlayType == "UP" and "Upgrade.png" or "Downgrade.png"))
            btn.SGJ_OverlayFrame:Show()
        end
    end
end

MSC.UpdateQuestAcceptOverlays = MSC.UpdateAllQuestOverlays
MSC.UpdateQuestOverlays       = MSC.UpdateAllQuestOverlays
MSC.UpdateQuestLogOverlays    = MSC.UpdateAllQuestOverlays
-- =============================================================
-- MERCHANT REWARD OVERLAYS
-- =============================================================
function MSC.UpdateMerchantOverlays()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end

    local weights, specName = MSC.GetCurrentWeights()
    if not weights then return end

    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local index = (((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i)
        local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
        
        if itemButton then
            if itemButton.SGJ_Overlay then itemButton.SGJ_Overlay:Hide() end
            
            if itemButton:IsShown() and index <= GetMerchantNumItems() then
                local link = GetMerchantItemLink(index)
                local overlayType = nil

                if link then
                    -- GATEKEEPER: Ensure item is fully cached
                    local itemName, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
                    
                    if not itemName then
                        -- Await GET_ITEM_INFO_RECEIVED
                    elseif equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" then
                        if MSC.IsItemUsable(link) then 
                            local slotID = MSC.GetComparisonSlot(link, equipLoc, weights, specName)
                            if slotID then
                                 local newScore, oldScore = MSC:EvaluateUpgrade(link, slotID, weights, specName)
                                 if newScore and oldScore then
                                     if (newScore > (oldScore + MSC.VERDICT_EPS)) then
                                         overlayType = "UP"
                                     elseif (oldScore > (newScore + MSC.VERDICT_EPS)) then
                                         overlayType = "DOWN"
                                     end
                                 end
                            end
                        end
                    end
                end

                if overlayType then
                    if not itemButton.SGJ_Overlay then
                        itemButton.SGJ_Overlay = itemButton:CreateTexture(nil, "OVERLAY", nil, 7)
                        itemButton.SGJ_Overlay:SetSize(22, 22) 
                        itemButton.SGJ_Overlay:SetPoint("TOPRIGHT", 2, 2)
                    end
                    itemButton.SGJ_Overlay:SetTexture("Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\" .. (overlayType == "UP" and "Upgrade.png" or "Downgrade.png"))
                    itemButton.SGJ_Overlay:Show()
                end
            end
        end
    end
end

-- =============================================================
-- GROUP LOOT / ROLL OVERLAYS
-- =============================================================
function MSC.UpdateLootRollOverlays()
    if RXP_SGJ_Settings and RXP_SGJ_Settings.ShowLootArrows == false then 
        for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
            local iconFrame = _G["GroupLootFrame" .. i .. "IconFrame"]
            if iconFrame and iconFrame.SGJ_OverlayFrame then iconFrame.SGJ_OverlayFrame:Hide() end
        end
        return 
    end

    local weights, specName = MSC.GetCurrentWeights()
    if not weights then return end

    -- WoW Classic defaults to a maximum of 4 concurrent loot roll frames
    for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
        local frame = _G["GroupLootFrame" .. i]
        
        if frame and frame:IsShown() then
            local rollID = frame.rollID
            local iconFrame = _G["GroupLootFrame" .. i .. "IconFrame"]

            if rollID and iconFrame then
                if iconFrame.SGJ_OverlayFrame then iconFrame.SGJ_OverlayFrame:Hide() end

                local link = GetLootRollItemLink(rollID)
                if link then
                    local overlayType = nil
                    local itemName, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
                    
                    if itemName and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" then
                        if MSC.IsItemUsable(link) then
                            local slotID = MSC.GetComparisonSlot(link, equipLoc, weights, specName)
                            if slotID then
                                local newScore, oldScore = MSC:EvaluateUpgrade(link, slotID, weights, specName)
                                if newScore and oldScore then
                                    if (newScore > (oldScore + MSC.VERDICT_EPS)) then
                                        overlayType = "UP"
                                    elseif (oldScore > (newScore + MSC.VERDICT_EPS)) then
                                        overlayType = "DOWN"
                                    end
                                end
                            end
                        end
                    end

                    if overlayType then
                        if not iconFrame.SGJ_OverlayFrame then
                            iconFrame.SGJ_OverlayFrame = CreateFrame("Frame", nil, iconFrame)
                            iconFrame.SGJ_OverlayFrame:SetAllPoints(iconFrame)
                            iconFrame.SGJ_OverlayFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 5)
                            
                            iconFrame.SGJ_Overlay = iconFrame.SGJ_OverlayFrame:CreateTexture(nil, "OVERLAY")
                            iconFrame.SGJ_Overlay:SetSize(20, 20)
                            iconFrame.SGJ_Overlay:SetPoint("TOPRIGHT", iconFrame.SGJ_OverlayFrame, "TOPRIGHT", 4, 4)
                        end
                        
                        iconFrame.SGJ_Overlay:SetTexture("Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\" .. (overlayType == "UP" and "Upgrade.png" or "Downgrade.png"))
                        iconFrame.SGJ_OverlayFrame:Show()
                    end
                end
            end
        end
    end
end

-- =============================================================
-- TRADE SKILL / CRAFTING OVERLAYS
-- =============================================================
-- Profession windows only flag upgrades (a recipe you'd never craft for
-- yourself doesn't need a red arrow). Uncached items are requested and the
-- window redraws on GET_ITEM_INFO_RECEIVED.
function MSC.IsCraftUpgrade(link, weights, specName)
    if not link or not weights then return false end
    if not GetItemInfo(link) then
        -- Enchant/spell links (Enchanting, Beast Training) never resolve to an item
        if link:find("|Hitem:") and MSC_ScannerTooltip then pcall(MSC_ScannerTooltip.SetHyperlink, MSC_ScannerTooltip, link) end
        return false
    end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return false end
    if not MSC.IsItemUsable(link) then return false end
    local compSlot = MSC.GetComparisonSlot(link, equipLoc, weights, specName)
    if not compSlot then return false end
    local newScore, oldScore = MSC:EvaluateUpgrade(link, compSlot, weights, specName)
    return newScore and oldScore and newScore > (oldScore + MSC.VERDICT_EPS) or false
end

-- Shows or hides the green arrow on a recipe row or the selected-recipe icon.
local function SetCraftArrow(frame, show, size, point, x, y)
    if not frame then return end
    if not show then
        if frame.SGJ_Overlay then frame.SGJ_Overlay:Hide() end
        return
    end
    if not frame.SGJ_Overlay then
        frame.SGJ_Overlay = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        frame.SGJ_Overlay:SetSize(size, size)
        frame.SGJ_Overlay:SetPoint(point, frame, point, x, y)
        frame.SGJ_Overlay:SetTexture("Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\Upgrade.png")
    end
    frame.SGJ_Overlay:Show()
end

-- One routine for both Classic profession windows: the TradeSkill frame
-- (every profession but Enchanting) and the Craft frame (Enchanting; Beast
-- Training also uses it, but its links are spells and are skipped).
local function UpdateProfessionList(ui)
    local frame = _G[ui.frame]
    if not frame or not frame:IsShown() or not ui.getNum then return end

    local weights, specName = MSC.GetCurrentWeights()
    if not weights then return end

    local total = ui.getNum() or 0
    local scroll = _G[ui.scroll]
    local offset = (scroll and FauxScrollFrame_GetOffset) and FauxScrollFrame_GetOffset(scroll) or 0

    -- 1. List rows
    for i = 1, ui.shown or 8 do
        local index = i + offset
        local row = _G[ui.row .. i]
        if row then
            local show = false
            if index <= total and row:IsShown() then
                local _, _, kind = ui.getInfo(index)
                if ui.rowTypeIsSecond then kind = select(2, ui.getInfo(index)) end
                if kind ~= "header" then
                    show = MSC.IsCraftUpgrade(ui.getLink(index), weights, specName)
                end
            end
            SetCraftArrow(row, show, 16, "RIGHT", -2, 0)
        end
    end

    -- 2. Selected recipe icon
    local icon = _G[ui.icon]
    if icon then
        local index = ui.getSelected and ui.getSelected()
        local show = icon:IsShown() and index and index > 0
            and MSC.IsCraftUpgrade(ui.getLink(index), weights, specName) or false
        SetCraftArrow(icon, show, 22, "TOPRIGHT", 4, 4)
    end
end

local TRADESKILL_UI = {
    frame = "TradeSkillFrame", scroll = "TradeSkillListScrollFrame", row = "TradeSkillSkill",
    icon = "TradeSkillSkillIcon", rowTypeIsSecond = true,
}
local CRAFT_UI = {
    frame = "CraftFrame", scroll = "CraftListScrollFrame", row = "Craft", icon = "CraftIcon",
}

function MSC.UpdateTradeSkillOverlays()
    if not GetNumTradeSkills then return end
    TRADESKILL_UI.shown = TRADE_SKILLS_DISPLAYED or 8
    TRADESKILL_UI.getNum, TRADESKILL_UI.getInfo = GetNumTradeSkills, GetTradeSkillInfo
    TRADESKILL_UI.getLink, TRADESKILL_UI.getSelected = GetTradeSkillItemLink, GetTradeSkillSelectionIndex
    UpdateProfessionList(TRADESKILL_UI)
end

-- GetCraftInfo returns name, subSpellName, type, ...
function MSC.UpdateCraftOverlays()
    if not GetNumCrafts or not GetCraftItemLink then return end
    CRAFT_UI.shown = CRAFTS_DISPLAYED or 8
    CRAFT_UI.getNum, CRAFT_UI.getInfo = GetNumCrafts, GetCraftInfo
    CRAFT_UI.getLink, CRAFT_UI.getSelected = GetCraftItemLink, GetCraftSelectionIndex
    UpdateProfessionList(CRAFT_UI)
end

-- Modern profession window (Blizzard_Professions). WoW Forever ships this one
-- instead of the Classic TradeSkill/Craft frames, for every profession
-- including Enchanting. Recipe rows live in a ScrollBox; the result comes
-- from C_TradeSkillUI.GetRecipeOutputItemData (no hyperlink for enchants).
local function GetRecipeOutputLink(recipeID)
    if not recipeID or not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData) then return nil end
    local ok, info = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
    return ok and info and info.hyperlink or nil
end

local function GetRowRecipeID(elementData)
    local data = elementData and elementData.GetData and elementData:GetData()
    return data and data.recipeInfo and data.recipeInfo.recipeID
end

local function DrawProfessionsRow(frame, elementData)
    if not frame then return end
    local recipeID = GetRowRecipeID(elementData or (frame.GetElementData and frame:GetElementData()))
    local show = false
    if recipeID then
        local weights, specName = MSC.GetCurrentWeights()
        show = MSC.IsCraftUpgrade(GetRecipeOutputLink(recipeID), weights, specName)
    end
    SetCraftArrow(frame, show, 16, "RIGHT", -4, 0)
end

local function DrawProfessionsOutput(form)
    if not form or not form.OutputIcon then return end
    local recipeID = form.transaction and form.transaction.GetRecipeID and form.transaction:GetRecipeID()
    local show = false
    if recipeID and form.OutputIcon:IsShown() then
        local weights, specName = MSC.GetCurrentWeights()
        show = MSC.IsCraftUpgrade(GetRecipeOutputLink(recipeID), weights, specName)
    end
    SetCraftArrow(form.OutputIcon, show, 22, "TOPRIGHT", 4, 4)
end

function MSC.UpdateProfessionsOverlays()
    local page = ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame.CraftingPage
    if not page then return end
    local scrollBox = page.RecipeList and page.RecipeList.ScrollBox
    if scrollBox and scrollBox.ForEachFrame then
        pcall(scrollBox.ForEachFrame, scrollBox, DrawProfessionsRow)
    end
    DrawProfessionsOutput(page.SchematicForm)
end

local function HookModernProfessions()
    if MSC.ProfessionsHooked then return end
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local scrollBox = page and page.RecipeList and page.RecipeList.ScrollBox
    if not scrollBox or not ScrollUtil or not ScrollUtil.AddInitializedFrameCallback then return end
    MSC.ProfessionsHooked = true

    -- Every time a recipe row is (re)used for a recipe
    ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, frame, elementData)
        DrawProfessionsRow(frame, elementData)
    end, MSC)

    -- The selected recipe's output icon
    local form = page.SchematicForm
    if form and type(form.UpdateOutputItem) == "function" then
        hooksecurefunc(form, "UpdateOutputItem", DrawProfessionsOutput)
    end

    ProfessionsFrame:HookScript("OnShow", function() C_Timer.After(0.05, MSC.UpdateProfessionsOverlays) end)

    -- Gear, level or talents changed, or a result item finished loading
    local refresh = CreateFrame("Frame")
    refresh:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    refresh:RegisterEvent("PLAYER_LEVEL_UP")
    refresh:RegisterEvent("PLAYER_TALENT_UPDATE")
    refresh:RegisterEvent("CHARACTER_POINTS_CHANGED")
    refresh:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    local queued = false
    refresh:SetScript("OnEvent", function()
        if queued or not ProfessionsFrame:IsShown() then return end
        queued = true
        C_Timer.After(0.2, function() queued = false; MSC.UpdateProfessionsOverlays() end)
    end)
end

-- Hooks each profession window once its Blizzard addon has loaded
-- (called on ADDON_LOADED and again at file load for /reload).
function MSC.HookProfessionWindows()
    HookModernProfessions()
    if not MSC.TradeSkillHooked and TradeSkillFrame_Update then
        hooksecurefunc("TradeSkillFrame_Update", MSC.UpdateTradeSkillOverlays)
        if TradeSkillFrame_SetSelection then
            hooksecurefunc("TradeSkillFrame_SetSelection", function()
                C_Timer.After(0.05, MSC.UpdateTradeSkillOverlays)
            end)
        end
        MSC.TradeSkillHooked = true
    end
    if not MSC.CraftHooked and CraftFrame_Update then
        hooksecurefunc("CraftFrame_Update", MSC.UpdateCraftOverlays)
        if CraftFrame_SetSelection then
            hooksecurefunc("CraftFrame_SetSelection", function()
                C_Timer.After(0.05, MSC.UpdateCraftOverlays)
            end)
        end
        MSC.CraftHooked = true
    end
end

-- =============================================================
-- BAG / INVENTORY UPGRADE OVERLAYS
-- =============================================================
-- Shared by the Blizzard bags and every third-party bag integration below.
-- Returns "UP", "DOWN" or nil for a bag item link.
-- The smallest score change that counts as an upgrade or downgrade: the tooltip's own (Judge.lua, delta > 0.01), so a
-- bag arrow shows for every item the tooltip calls an upgrade (2026-11-04: the bags used 0.1, so small upgrades had none).
MSC.VERDICT_EPS = 0.01

function MSC.GetBagArrowVerdict(link, weights, specName)
    if not link or not weights then return nil end
    local itemName, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    if not itemName or not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return nil end
    if not MSC.IsItemUsable(link) then return nil end

    local compSlot = MSC.GetComparisonSlot(link, equipLoc, weights, specName)
    if not compSlot then return nil end

    local useFast = (not RXP_SGJ_Settings or RXP_SGJ_Settings.FastBagArrows ~= false)
    local newScore, oldScore
    if useFast and MSC.EvaluateUpgradeFast and MSC.ShouldUseFastEval and MSC:ShouldUseFastEval(link, compSlot) then
        newScore, oldScore = MSC:EvaluateUpgradeFast(link, compSlot, weights, specName)
    else
        newScore, oldScore = MSC:EvaluateUpgrade(link, compSlot, weights, specName)
    end
    if not newScore or not oldScore then return nil end

    if newScore > (oldScore + MSC.VERDICT_EPS) then return "UP"
    elseif oldScore > (newScore + MSC.VERDICT_EPS) then return "DOWN" end
    return nil
end

-- Draws (or hides, when overlayType is nil) the arrow on a bag button. The
-- texture lives on a child frame raised above the button, so the button's own
-- child frames and bag-addon refreshes can't cover it.
-- `place` (optional, used when the arrow is first created) moves it off the
-- default top-right corner: { point = "TOPLEFT", x = 2, y = -2, size = 14 }.
function MSC.SetBagArrow(button, overlayType, place)
    if not button then return end
    if not overlayType then
        if button.SGJ_OverlayFrame then button.SGJ_OverlayFrame:Hide() end
        return
    end

    if not button.SGJ_OverlayFrame then
        -- Older builds put a bare texture directly on the button; retire it
        if button.SGJ_Overlay then button.SGJ_Overlay:Hide() end
        local holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints(button)
        button.SGJ_Overlay = holder:CreateTexture(nil, "OVERLAY", nil, 7)
        local point = (place and place.point) or "TOPRIGHT"
        local size = (place and place.size) or 18
        button.SGJ_Overlay:SetSize(size, size)
        button.SGJ_Overlay:SetPoint(point, holder, point, (place and place.x) or -2, (place and place.y) or -2)
        button.SGJ_OverlayFrame = holder
    end

    button.SGJ_OverlayFrame:SetFrameLevel(button:GetFrameLevel() + 10)
    button.SGJ_Overlay:SetTexture("Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\" .. (overlayType == "UP" and "Upgrade.png" or "Downgrade.png"))
    button.SGJ_Overlay:Show()
    button.SGJ_OverlayFrame:Show()
end

-- Every Blizzard bag frame this client has: the modern container list, the
-- legacy ContainerFrame<N> globals, and the combined backpack.
function MSC.ForEachBlizzardBagFrame(fn)
    local seen = {}
    local function visit(frame)
        if frame and not seen[frame] then
            seen[frame] = true
            fn(frame)
        end
    end
    if ContainerFrameContainer and type(ContainerFrameContainer.ContainerFrames) == "table" then
        for _, frame in pairs(ContainerFrameContainer.ContainerFrames) do visit(frame) end
    end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do visit(_G["ContainerFrame" .. i]) end
    visit(ContainerFrameCombinedBags)
end

function MSC.UpdateBagOverlays(frame)
    if not frame or not frame:IsShown() then return end

    local weights, specName
    if not (RXP_SGJ_Settings and RXP_SGJ_Settings.ShowBagArrows == false) then
        weights, specName = MSC.GetCurrentWeights()
    end

    -- Modern buttons know their own bag (the combined backpack spans several);
    -- legacy buttons inherit it from the frame.
    local frameBag = frame.GetID and frame:GetID()
    local function draw(button)
        local verdict
        if weights then
            local bagID = (button.GetBagID and button:GetBagID()) or frameBag
            local slotID = button:GetID()
            if bagID and slotID and slotID > 0 then
                verdict = MSC.GetBagArrowVerdict(GetContainerItemLink(bagID, slotID), weights, specName)
            end
        end
        MSC.SetBagArrow(button, verdict)
    end

    if frame.EnumerateValidItems then
        for _, button in frame:EnumerateValidItems() do draw(button) end
    else
        local name = frame:GetName()
        for i = 1, 36 do
            local button = (name and _G[name .. "Item" .. i]) or (frame.Items and frame.Items[i])
            if button and button:IsShown() then draw(button) end
        end
    end
end

-- The default bank's main slots (BankFrameItem1..N, bag BANK_CONTAINER). Bank
-- bags open as container frames, which MSC.UpdateBagOverlays already covers.
function MSC.UpdateBankOverlays()
    if not (BankFrame and BankFrame:IsShown() and _G["BankFrameItem1"]) then return end
    local weights, specName
    if not (RXP_SGJ_Settings and RXP_SGJ_Settings.ShowBagArrows == false) then
        weights, specName = MSC.GetCurrentWeights()
    end
    local bankID = BANK_CONTAINER or -1
    for i = 1, (NUM_BANKGENERIC_SLOTS or 24) do
        local button = _G["BankFrameItem" .. i]
        if button then
            local verdict
            if weights and button:IsShown() then
                verdict = MSC.GetBagArrowVerdict(GetContainerItemLink(bankID, button:GetID()), weights, specName)
            end
            MSC.SetBagArrow(button, verdict)
        end
    end
end

-- =============================================================
-- THIRD-PARTY BAG INTEGRATION (ElvUI, Bagnon, Baganator)
-- =============================================================
local BagHookFrame = CreateFrame("Frame")
BagHookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
BagHookFrame:SetScript("OnEvent", function(self, event)
    if self.Loaded then return end
    self.Loaded = true
    
    local CheckAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

-- [[ HELPER: THE DRAWING ENGINE ]]
    local function EvaluateAndDraw(button, link)
        local verdict
        if link and not (RXP_SGJ_Settings and RXP_SGJ_Settings.ShowBagArrows == false) then
            local weights, specName = MSC.GetCurrentWeights()
            verdict = MSC.GetBagArrowVerdict(link, weights, specName)
        end
        MSC.SetBagArrow(button, verdict)
    end


    -- [[ 1. ELVUI SUPPORT ]]
    -- Bypass ElvUI/Eltruism internals entirely by looking up slot frames by their
    -- known global names: "ElvUIMainBag{bagID}Slot{slotID}"
    if CheckAddOnLoaded("ElvUI") then
        local elvScanner = CreateFrame("Frame")
        elvScanner:RegisterEvent("BAG_UPDATE_DELAYED")
        elvScanner:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        elvScanner:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
        -- The bank window (main slots and bank bags), 2026-10-25
        pcall(elvScanner.RegisterEvent, elvScanner, "BANKFRAME_OPENED")
        pcall(elvScanner.RegisterEvent, elvScanner, "PLAYERBANKSLOTS_CHANGED")

        -- Bag IDs each ElvUI window holds: the bags, and the bank's main slots
        -- (BANK_CONTAINER, -1) plus its bank bags (5 and up).
        local BAG_IDS = { 0, 1, 2, 3, 4 }
        local BANK_IDS = { BANK_CONTAINER or -1 }
        for i = 1, (NUM_BANKBAGSLOTS or 6) do BANK_IDS[#BANK_IDS + 1] = 4 + i end

        local scanPending = false
        local hookedShow = {}
        local arrowsCleared = false -- arrows already hidden while Show Bag Arrows is off
        local ScanElvUIBags
        -- One ElvUI window. Slots report IsShown() while the window is closed, so
        -- a closed window is skipped and opening it triggers a scan.
        local function ScanElvUIFrame(f, ids)
            if not f or not f.Bags then return end
            if f.IsVisible and not f:IsVisible() then
                if not hookedShow[f] and f.HookScript then
                    hookedShow[f] = true
                    f:HookScript("OnShow", function() C_Timer.After(0.2, ScanElvUIBags) end)
                end
                return
            end
            for _, bagID in ipairs(ids) do
                local bag = f.Bags[bagID]
                if bag then
                    local numSlots = GetContainerNumSlots(bagID)
                    for slotID = 1, numSlots do
                        local slot = bag[slotID]
                        if slot and slot.IsShown and slot:IsShown() then
                            local link = slot.itemLink or GetContainerItemLink(bagID, slotID)
                            EvaluateAndDraw(slot, link)
                        end
                    end
                end
            end
        end
        function ScanElvUIBags()
            scanPending = false
            -- With Show Bag Arrows off the scan still runs once to hide the
            -- arrows already drawn (EvaluateAndDraw draws nothing then).
            local arrowsOff = RXP_SGJ_Settings and RXP_SGJ_Settings.ShowBagArrows == false
            if arrowsOff and arrowsCleared then return end

            local E = ElvUI and unpack(ElvUI)
            if not E then return end
            local B = E:GetModule('Bags')
            if not B then return end
            ScanElvUIFrame(B.BagFrame, BAG_IDS)
            ScanElvUIFrame(B.BankFrame, BANK_IDS)
            arrowsCleared = arrowsOff
        end

        -- One scan per burst, shared by ElvUI's own events and
        -- MSC.RefreshAllBagOverlays (both fire on BAG_UPDATE_DELAYED).
        local function QueueElvUIScan()
            if not scanPending then
                scanPending = true
                C_Timer.After(0.15, ScanElvUIBags)
            end
        end
        MSC.RefreshElvUIBagOverlays = QueueElvUIScan
        elvScanner:SetScript("OnEvent", QueueElvUIScan)

        -- Also scan when the bag frame is shown/toggled
        local bagFrame = _G["ElvUI_ContainerFrame"]
        if bagFrame then
            hookedShow[bagFrame] = true
            bagFrame:HookScript("OnShow", function()
                C_Timer.After(0.2, ScanElvUIBags)
            end)
        end

        -- Hook the ElvUI module's UpdateSlot
        local E = ElvUI and unpack(ElvUI)
        if E then
            local B = E:GetModule('Bags')
            if B and B.UpdateSlot then
                -- UpdateSlot fires many times per refresh; batch and evaluate next frame
                -- (same pattern as Bagnon below).
                local pendingBag, pendingSlot, flushQueued = {}, {}, false
                local function FlushElvSlots()
                    flushQueued = false
                    for slot, bagID in pairs(pendingBag) do
                        local slotID = pendingSlot[slot]
                        pendingBag[slot] = nil
                        pendingSlot[slot] = nil
                        EvaluateAndDraw(slot, slot.itemLink or GetContainerItemLink(bagID, slotID))
                    end
                end
                hooksecurefunc(B, "UpdateSlot", function(self, frame, bagID, slotID)
                    -- Signature is: B:UpdateSlot(frame, bagID, slotID)
                    -- When hooked via hooksecurefunc, the first arg passed is self (B), second is frame, third is bagID, fourth is slotID
                    local slot = frame and frame.Bags and frame.Bags[bagID] and frame.Bags[bagID][slotID]
                    if slot then
                        pendingBag[slot] = bagID
                        pendingSlot[slot] = slotID
                        if not flushQueued then
                            flushQueued = true
                            C_Timer.After(0, FlushElvSlots)
                        end
                    end
                end)
            end

            -- Loot Roll Hook
            local M = E:GetModule('Misc')
            if M and M.START_LOOT_ROLL then
                hooksecurefunc(M, "START_LOOT_ROLL", function(self, event, rollID, rollTime)
                    C_Timer.After(0.05, function()
                        if self.RollBars then
                            for _, bar in ipairs(self.RollBars) do
                                if bar:IsShown() and bar.rollID == rollID and bar.button and bar.button.link then
                                    if RXP_SGJ_Settings and RXP_SGJ_Settings.ShowLootArrows == false then
                                        MSC.SetBagArrow(bar.button, nil)
                                        return
                                    end
                                    EvaluateAndDraw(bar.button, bar.button.link)
                                end
                            end
                        end
                    end)
                end)
            end
        end
    end
	
	-- [[ 2. XLOOT GROUP SUPPORT ]]
    if CheckAddOnLoaded("XLoot_Group") and _G.XLootGroup then
        local XLG = _G.XLootGroup
        if XLG.START_LOOT_ROLL then
            hooksecurefunc(XLG, "START_LOOT_ROLL", function(self, id)
                -- Wait 0.05s to ensure XLoot has fully built the frame and assigned the link
                C_Timer.After(0.05, function()
                    -- XLoot stores active roll frames inside its anchor's children table
                    if self.anchor and self.anchor.children then
                        for _, frame in pairs(self.anchor.children) do
                            -- Match the frame to the roll ID that triggered the event
                            if frame:IsShown() and frame.rollid == id and frame.link and frame.icon_frame then
                                -- frame.icon_frame is the square icon container
                                EvaluateAndDraw(frame.icon_frame, frame.link)
                            end
                        end
                    end
                end)
            end)
        end
    end

    -- [[ 3. BAGNON SUPPORT ]]
    -- Bagnon 10+ (BagBrother core) replaced ItemSlot with Item/ContainerItem and
    -- keeps the link in button.info.hyperlink. Old ItemSlot is still hooked for
    -- legacy installs.
    if CheckAddOnLoaded("Bagnon") and type(Bagnon) == "table" then
        local function GetBagnonLink(button)
            local link = button.info and button.info.hyperlink
            if not link and button.GetItem then link = button:GetItem() end
            if not link then
                local bagID = (button.GetBag and button:GetBag()) or button.bag
                local slotID = button:GetID()
                if bagID and slotID and slotID > 0 then link = GetContainerItemLink(bagID, slotID) end
            end
            return link
        end

        -- Bagnon calls Update many times per refresh; batch them and evaluate
        -- on the next frame, once the button has finished updating.
        local pending, flushQueued = {}, false
        local function Flush()
            flushQueued = false
            for button in pairs(pending) do
                pending[button] = nil
                -- Cached (offline/other character) items aren't ours to judge
                if button:IsShown() and not (button.IsCached and button:IsCached()) then
                    EvaluateAndDraw(button, GetBagnonLink(button))
                else
                    MSC.SetBagArrow(button, nil)
                end
            end
        end
        local function Queue(button)
            if not button then return end
            pending[button] = true
            if not flushQueued then
                flushQueued = true
                C_Timer.After(0, Flush)
            end
        end

        for _, className in ipairs({ "ItemSlot", "Item", "ContainerItem" }) do
            local class = Bagnon[className]
            if type(class) == "table" and type(class.Update) == "function" then
                pcall(hooksecurefunc, class, "Update", Queue)
            end
        end

        -- Backup for button paths the class hooks miss: walk the live inventory grid
        function MSC.RefreshBagnonOverlays()
            local frames = Bagnon.Frames
            if type(frames) ~= "table" or not frames.Get then return end
            local ok, frame = pcall(frames.Get, frames, "inventory")
            if not ok or type(frame) ~= "table" or not frame.IsShown or not frame:IsShown() then return end
            local group = rawget(frame, "ItemGroup")
            if type(group) ~= "table" or type(group.buttons) ~= "table" then return end
            for _, button in ipairs(group.buttons) do Queue(button) end
        end

        if type(Bagnon.Frames) == "table" and type(Bagnon.Frames.Show) == "function" then
            hooksecurefunc(Bagnon.Frames, "Show", function() C_Timer.After(0, MSC.RefreshBagnonOverlays) end)
        end
        MSC.RefreshBagnonOverlays()
    end

    -- [[ 4. BAGANATOR SUPPORT ]]
    -- Baganator owns its item buttons, so SGJ plugs in through its public API:
    --  * Corner widget ("Icons" tab): draws SGJ's up/down arrow on the item.
    --  * Upgrade plugin ("Upgrade detection" dropdown): feeds the `upgrade`
    --    search keyword / categories. It does not draw anything by itself.
    -- Both callbacks return true/false, or nil for "ask again soon" (item not cached).
    -- Baganator's own settings are the opt-in, so ShowBagArrows doesn't gate this path.
    if CheckAddOnLoaded("Baganator") and Baganator and Baganator.API and Baganator.API.RegisterUpgradePlugin then
        local PLUGIN_ID = "sharpies_gear_judge"
        local verdictCache = {} -- link -> "UP" / "DOWN" / false

        local function GetVerdict(itemLink)
            if not itemLink then return false end
            local cached = verdictCache[itemLink]
            if cached ~= nil then return cached end
            if not GetItemInfo(itemLink) then return nil end
            local weights, specName = MSC.GetCurrentWeights()
            if not weights then return nil end
            local verdict = MSC.GetBagArrowVerdict(itemLink, weights, specName) or false
            verdictCache[itemLink] = verdict
            return verdict
        end

        if Baganator.API.RegisterCornerWidget then
            Baganator.API.RegisterCornerWidget("Sharpie's Gear Judge", PLUGIN_ID, function(arrow, details)
                local verdict = GetVerdict(details.itemLink)
                if verdict == nil then return nil end
                if not verdict then return false end
                arrow:SetTexture("Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\" .. (verdict == "UP" and "Upgrade.png" or "Downgrade.png"))
                return true
            end, function(itemButton)
                local arrow = itemButton:CreateTexture(nil, "OVERLAY")
                arrow:SetSize(16, 16)
                return arrow
            end, {corner = "top_right", priority = 1})
        end

        Baganator.API.RegisterUpgradePlugin("Sharpie's Gear Judge", PLUGIN_ID, function(itemLink)
            local verdict = GetVerdict(itemLink)
            if verdict == nil then return nil end
            return verdict == "UP"
        end)

        function MSC.RequestBaganatorRefresh()
            wipe(verdictCache)
            local api = Baganator.API
            local widgetActive = api.IsCornerWidgetActive and api.IsCornerWidgetActive(PLUGIN_ID)
            local pluginActive = api.IsUpgradePluginActive and api.IsUpgradePluginActive(PLUGIN_ID)
            if (widgetActive or pluginActive) and api.RequestItemButtonsRefresh then api.RequestItemButtonsRefresh() end
        end

        -- Baganator also refreshes on equip changes itself (via Syndicator), but that can
        -- run before SGJ's own caches update, so every trigger re-asks once things settle.
        local baganatorEvents = CreateFrame("Frame")
        baganatorEvents:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        baganatorEvents:RegisterEvent("PLAYER_LEVEL_UP")
        baganatorEvents:RegisterEvent("PLAYER_TALENT_UPDATE")
        baganatorEvents:RegisterEvent("CHARACTER_POINTS_CHANGED")
        baganatorEvents:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        -- One refresh per 0.5s burst of events.
        local baganatorRefreshPending = false
        local function RunBaganatorRefresh()
            baganatorRefreshPending = false
            MSC.RequestBaganatorRefresh()
        end
        baganatorEvents:SetScript("OnEvent", function()
            wipe(verdictCache)
            if not baganatorRefreshPending then
                baganatorRefreshPending = true
                C_Timer.After(0.5, RunBaganatorRefresh)
            end
        end)
    end

    -- [[ 5. GUDABAGS SUPPORT ]]
    -- GudaBags.API.OnItemButtonUpdate(callback(button, bagID, slot)) fires
    -- after each real-item update on its item buttons (bags, bank, mail; not
    -- cached-character or read-only views). It doesn't fire when a pooled
    -- button is reused for an empty or drop-target slot, but every one of
    -- those paths hides GudaBags' own upgradeArrow texture, so hooking that
    -- Hide clears SGJ's arrow too. The arrow sits top-left where GudaBags
    -- puts its Pawn arrow (item level text owns the top-right corner).
    if CheckAddOnLoaded("GudaBags") and GudaBags and GudaBags.API and type(GudaBags.API.OnItemButtonUpdate) == "function" then
        local PLACE = { point = "TOPLEFT", x = 1, y = -1, size = 15 }
        local known = setmetatable({}, { __mode = "k" })

        local function GetGudaLink(button)
            local data = button.itemData
            local link = data and (data.link or data.itemLink)
            if not link and data and data.bagID and data.slot then
                link = GetContainerItemLink(data.bagID, data.slot)
            end
            return link
        end

        -- A real, live item (not an empty/drop-target pseudo slot or a cached view)
        local function HasRealItem(button)
            local data = button.itemData
            return data and not button.isReadOnly and not data.isEmptySlots
                and not data.isDropTarget and not data.isGuildBank
        end

        -- SetItem runs many times per refresh; judge once, on the next frame.
        local pending, flushQueued = {}, false
        local function Flush()
            flushQueued = false
            for button in pairs(pending) do
                pending[button] = nil
                if button:IsShown() and HasRealItem(button) then
                    local link = GetGudaLink(button)
                    local verdict
                    if link and not (RXP_SGJ_Settings and RXP_SGJ_Settings.ShowBagArrows == false) then
                        local weights, specName = MSC.GetCurrentWeights()
                        verdict = MSC.GetBagArrowVerdict(link, weights, specName)
                    end
                    MSC.SetBagArrow(button, verdict, PLACE)
                else
                    MSC.SetBagArrow(button, nil)
                end
            end
        end
        local function Queue(button)
            pending[button] = true
            if not flushQueued then
                flushQueued = true
                C_Timer.After(0, Flush)
            end
        end

        GudaBags.API.OnItemButtonUpdate(function(button)
            if not button then return end
            if not known[button] then
                known[button] = true
                if button.upgradeArrow and button.upgradeArrow.Hide then
                    -- Also hidden on GudaBags' own Pawn-arrow repaints, so a
                    -- button that still holds a real item is re-judged instead.
                    hooksecurefunc(button.upgradeArrow, "Hide", function()
                        if HasRealItem(button) then Queue(button)
                        else
                            pending[button] = nil
                            MSC.SetBagArrow(button, nil)
                        end
                    end)
                end
                button:HookScript("OnHide", function() MSC.SetBagArrow(button, nil) end)
            end
            Queue(button)
        end)

        -- Re-judge every visible GudaBags button (gear, level, talents or the
        -- SGJ arrow settings changed; GudaBags won't redraw for those).
        function MSC.RefreshGudaBagsOverlays()
            for button in pairs(known) do
                if button:IsShown() and HasRealItem(button) then Queue(button) end
            end
        end

        local gudaEvents = CreateFrame("Frame")
        gudaEvents:RegisterEvent("PLAYER_LEVEL_UP")
        gudaEvents:RegisterEvent("PLAYER_TALENT_UPDATE")
        gudaEvents:RegisterEvent("CHARACTER_POINTS_CHANGED")
        gudaEvents:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        gudaEvents:SetScript("OnEvent", function()
            C_Timer.After(0.5, MSC.RefreshGudaBagsOverlays)
        end)
    end

    -- [[ 6. DAYLIGHTUI SUPPORT ]]
    -- DaylightUI_Bags (WoW Forever) draws bags and bank in one window from the
    -- game's own ContainerFrameItemButtonTemplate buttons: the slot is the
    -- button's ID, the bag its parent holder's ID. Every repaint (bag, bank,
    -- search, layout) goes through the module's Items.Fill(btn), reachable
    -- through DaylightUI:GetModule("Bags").ns. Its corners are taken (bind type
    -- top-left, equipment set top-right, count bottom-right): the arrow sits
    -- bottom-left.
    local duiMod = CheckAddOnLoaded("DaylightUI_Bags") and DaylightUI and type(DaylightUI.GetModule) == "function"
        and DaylightUI:GetModule("Bags")
    local duiItems = duiMod and duiMod.ns and duiMod.ns.Items
    if duiItems and type(duiItems.Fill) == "function" then
        local PLACE = { point = "BOTTOMLEFT", x = 1, y = 1, size = 15 }
        local known = setmetatable({}, { __mode = "k" })

        local function GetDuiLink(button)
            local holder = button:GetParent()
            local bag, slot = holder and holder:GetID(), button:GetID()
            if not bag or not slot or slot < 1 then return nil end
            return GetContainerItemLink(bag, slot)
        end

        -- Fill runs for every slot on each refresh; judge once, on the next frame.
        local pending, flushQueued = {}, false
        local function Flush()
            flushQueued = false
            for button in pairs(pending) do
                pending[button] = nil
                local verdict
                if button:IsShown() and not (RXP_SGJ_Settings and RXP_SGJ_Settings.ShowBagArrows == false) then
                    local link = GetDuiLink(button)
                    if link then
                        local weights, specName = MSC.GetCurrentWeights()
                        verdict = MSC.GetBagArrowVerdict(link, weights, specName)
                    end
                end
                MSC.SetBagArrow(button, verdict, PLACE)
            end
        end
        local function Queue(button)
            pending[button] = true
            if not flushQueued then
                flushQueued = true
                C_Timer.After(0, Flush)
            end
        end

        hooksecurefunc(duiItems, "Fill", function(button)
            if not button then return end
            if not known[button] then
                known[button] = true
                button:HookScript("OnHide", function() MSC.SetBagArrow(button, nil) end)
            end
            Queue(button)
        end)

        -- Re-judge every visible DaylightUI button (gear, level, talents or the
        -- SGJ arrow settings changed; DaylightUI won't repaint for those).
        function MSC.RefreshDaylightUIOverlays()
            for button in pairs(known) do
                if button:IsShown() then Queue(button) end
            end
        end

        local duiEvents = CreateFrame("Frame")
        duiEvents:RegisterEvent("PLAYER_LEVEL_UP")
        duiEvents:RegisterEvent("PLAYER_TALENT_UPDATE")
        duiEvents:RegisterEvent("CHARACTER_POINTS_CHANGED")
        duiEvents:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        duiEvents:SetScript("OnEvent", function()
            C_Timer.After(0.5, MSC.RefreshDaylightUIOverlays)
        end)
    end

    -- [[ 7. DAYLIGHTUI NPC WINDOW (quest rewards) ]]
    -- DaylightUI's own NPC window (core addon, module "NPC", on by default)
    -- replaces the quest frame, so the game's reward buttons that
    -- MSC.UpdateAllQuestOverlays marks never show. Its page is redrawn by
    -- ns.Window.Fill(page); the reward tiles are pooled in
    -- page.stack.pools.tile, each with its spec (spec.link() = the quest item
    -- link). After each fill, every tile with a link gets the same green/red
    -- arrow as the game's reward buttons (full evaluation, always on), at the
    -- icon's top-right corner (the count sits bottom-right). (2026-11-04)
    local npcMod = DaylightUI and type(DaylightUI.GetModule) == "function" and DaylightUI:GetModule("NPC")
    local npcWin = npcMod and npcMod.ns and npcMod.ns.Window
    if npcWin and type(npcWin.Fill) == "function" then
        local function MarkTile(b, overlayType)
            if not overlayType then
                if b.SGJ_NpcArrow then b.SGJ_NpcArrow:Hide() end
                return
            end
            if not b.SGJ_NpcArrow then
                local holder = CreateFrame("Frame", nil, b)
                holder:SetAllPoints(b.edge or b.icon or b)
                local tex = holder:CreateTexture(nil, "OVERLAY", nil, 7)
                tex:SetSize(16, 16)
                tex:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 3, 3)
                holder.tex = tex
                b.SGJ_NpcArrow = holder
            end
            local holder = b.SGJ_NpcArrow
            holder:SetFrameLevel(b:GetFrameLevel() + 10)
            holder.tex:SetTexture("Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\" .. (overlayType == "UP" and "Upgrade.png" or "Downgrade.png"))
            holder:Show()
        end

        local function MarkPage(page)
            local pool = page and page.stack and page.stack.pools and page.stack.pools.tile
            if not pool then return end
            local weights, specName = MSC.GetCurrentWeights()
            for i = 1, (pool.n or 0) do
                local b = pool[i]
                local spec = b and b.spec
                local overlayType
                if weights and spec and type(spec.link) == "function" then
                    local ok, link = pcall(spec.link)
                    if ok and type(link) == "string" then
                        local itemName, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
                        if itemName and equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" and MSC.IsItemUsable(link) then
                            local slotID = MSC.GetComparisonSlot(link, equipLoc, weights, specName)
                            if slotID then
                                local newScore, oldScore = MSC:EvaluateUpgrade(link, slotID, weights, specName)
                                if newScore and oldScore then
                                    if newScore > oldScore + MSC.VERDICT_EPS then overlayType = "UP"
                                    elseif oldScore > newScore + MSC.VERDICT_EPS then overlayType = "DOWN" end
                                end
                            end
                        end
                    end
                end
                if b then MarkTile(b, overlayType) end
            end
            -- tiles past this fill's count are hidden by DaylightUI; clear their arrows for the next reuse
            for i = (pool.n or 0) + 1, #pool do if pool[i] then MarkTile(pool[i], nil) end end
        end

        -- Npc.Fill is called directly on refills; the page tables (TALK, and SCENE_TALK for
        -- the immersive look) hold their own copy of it, which the window calls when a page
        -- opens. Each is hooked (marking twice is harmless). The item info can arrive a
        -- moment later; DaylightUI refills then too.
        hooksecurefunc(npcWin, "Fill", MarkPage)
        for _, def in ipairs({ npcWin.TALK, npcWin.SCENE_TALK }) do
            if type(def) == "table" and type(def.Fill) == "function" then hooksecurefunc(def, "Fill", MarkPage) end
        end
    end

    -- [[ 8. DAYLIGHTUI PROFESSION WINDOW ]]
    -- DaylightUI's own profession window (core addon, module "Professions")
    -- replaces TradeSkillFrame, so MSC.UpdateTradeSkillOverlays has no rows to
    -- mark. Every refill (search, chip, fold, skill-up) goes through
    -- ns.List.Render; its rows are in List.lines by recipe ID, and pooled in
    -- pane.stack.pools.line. Upgrades only, as the game's window (MSC.IsCraftUpgrade),
    -- on the icon's top-right corner (the count sits at the row's right). Verdicts
    -- are remembered per link until gear, level or talents change, so typing in
    -- the search box doesn't judge every recipe again. (2026-11-05)
    local craftMod = DaylightUI and type(DaylightUI.GetModule) == "function" and DaylightUI:GetModule("Professions")
    local craftList = craftMod and craftMod.ns and craftMod.ns.List
    if craftList and type(craftList.Render) == "function" then
        local verdicts, queued = {}, false

        local function SetRowArrow(b, show)
            if not show then
                if b.SGJ_CraftArrow then b.SGJ_CraftArrow:Hide() end
                return
            end
            if not b.SGJ_CraftArrow then
                local holder = CreateFrame("Frame", nil, b)
                holder:SetAllPoints(b.icon or b)
                local tex = holder:CreateTexture(nil, "OVERLAY", nil, 7)
                tex:SetSize(14, 14)
                tex:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 4, 4)
                tex:SetTexture("Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\Upgrade.png")
                b.SGJ_CraftArrow = holder
            end
            b.SGJ_CraftArrow:SetFrameLevel(b:GetFrameLevel() + 10)
            b.SGJ_CraftArrow:Show()
        end

        local function RecipeLink(r)
            local link = r.link
            if (not link or not link:find("|Hitem:")) and C_TradeSkillUI and C_TradeSkillUI.GetRecipeItemLink then
                local ok, l = pcall(C_TradeSkillUI.GetRecipeItemLink, r.id)
                if ok and type(l) == "string" then link = l end
            end
            return link
        end

        local function MarkRows()
            queued = false
            local pane = craftList.pane
            local pool = pane and pane.stack and pane.stack.pools and pane.stack.pools.line
            if pool then for i = 1, #pool do if pool[i] then SetRowArrow(pool[i], false) end end end
            local weights, specName = MSC.GetCurrentWeights()
            if not weights then return end
            for _, b in pairs(craftList.lines or {}) do
                local r = b.lineSpec and b.lineSpec.recipe
                local link = r and RecipeLink(r)
                if link then
                    local v = verdicts[link]
                    if v == nil then
                        v = MSC.IsCraftUpgrade(link, weights, specName) or false
                        -- not loaded yet: judged again when the item's data arrives
                        if GetItemInfo(link) then verdicts[link] = v end
                    end
                    SetRowArrow(b, v)
                end
            end
        end

        local function QueueRows()
            if queued then return end
            queued = true
            C_Timer.After(0, MarkRows)
        end
        hooksecurefunc(craftList, "Render", QueueRows)

        local craftEvents = CreateFrame("Frame")
        for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
            craftEvents:RegisterEvent(e)
        end
        craftEvents:SetScript("OnEvent", function(_, event)
            if event ~= "GET_ITEM_INFO_RECEIVED" then wipe(verdicts) end
            if craftList.pane and craftList.pane:IsVisible() then QueueRows() end
        end)
    end
end)

local function GetStatReason(stat, class, profileName)
    if not profileName then profileName = "" end
    if string_find(stat, "STRENGTH") then return MSC.L["Increases Attack Power and Block Value"] end
    if string_find(stat, "AGILITY") then return MSC.L["Increases Crit Chance, Dodge, and Armor"] end
    if string_find(stat, "STAMINA") then return MSC.L["Increases total Health Pool"] end
    if string_find(stat, "INTELLECT") then return MSC.L["Increases Mana Pool and Spell Crit"] end
    if string_find(stat, "SPIRIT") then return MSC.L["Increases Out-of-Combat and Spell5 Regen"] end
    if string_find(stat, "ATTACK_POWER") then return MSC.L["Increases Raw Physical Damage Output"] end
    if string_find(stat, "DAMAGE_PER_SECOND") then return MSC.L["Increases Baseline Weapon Damage"] end
    if string_find(stat, "EXPERTISE") then return MSC.L["Reduces chance Target Parries or Dodges"] end
    if string_find(stat, "ARMOR_PENETRATION") then return MSC.L["Ignores a portion of Target's Armor"] end
    if string_find(stat, "MELEE_HIT") or string_find(stat, "RANGED_HIT") or (string_find(stat, "HIT") and not string_find(stat, "SPELL")) then return MSC.L["Reduces chance to Miss Physical attacks"] end
    if string_find(stat, "SPELL_POWER") then return MSC.L["Increases Scaling Damage of Spells"] end
    if string_find(stat, "HEALING") then return MSC.L["Increases Potency of Healing spells"] end
    if string_find(stat, "SPELL_HIT") or string_find(stat, "HIT_SPELL") then return MSC.L["Reduces chance for Spells to Resist/Miss"] end
    if string_find(stat, "MANA_REG") or string_find(stat, "MP5") then return MSC.L["Constant Mana Sustain (Mp5)"] end
    if string_find(stat, "CRIT") and not string_find(stat, "FROM_STATS") then return MSC.L["Chance for Extra Critical Damage/Healing"] end
    if string_find(stat, "HASTE") then return MSC.L["Increases Attack/Casting Speed"] end
    if string_find(stat, "DEFENSE") then return MSC.L["Reduces chance to be Crit and Hit"] end
    if string_find(stat, "DODGE") then return MSC.L["Chance to completely Avoid Physical attacks"] end
    if string_find(stat, "PARRY") then return MSC.L["Chance to Deflect front-facing attacks"] end
    if string_find(stat, "BLOCK_VALUE") then return MSC.L["Increases Damage mitigated by Shield"] end
    if string_find(stat, "BLOCK_RATING") then return MSC.L["Chance to Mitigate damage with Shield"] end
    if string_find(stat, "RESILIENCE") then return MSC.L["Reduces Crit Damage and Chance (PvP)"] end
    if string_find(stat, "ARMOR") and not string_find(stat, "PENETRATION") then return MSC.L["Reduces Incoming Physical Damage"] end
    return nil
end

local function GetProgressColor(percent, roleColor)
    if percent >= 100 then return 0, 1, 1 
    else 
        if roleColor then return roleColor.r, roleColor.g, roleColor.b 
        else local p = percent / 100; return 1, p, 0 end
    end
end

MSC_StatRingMixin = {}

function MSC_StatRingMixin:OnLoad(size, label)
    self.bg = self:CreateTexture(nil, "BACKGROUND", nil, -1)
    self.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    self.bg:SetAllPoints(); self.bg:SetVertexColor(0.1, 0.1, 0.1, 0.6)

    self.SpinFrame = CreateFrame("Frame", nil, self)
    self.SpinFrame:SetAllPoints(self)
    
    self.Energy = self.SpinFrame:CreateTexture(nil, "ARTWORK")
    self.Energy:SetAllPoints()
    self.Energy:SetBlendMode("ADD")
    self.Energy:SetAlpha(1.0)
    self.Energy:SetTexCoord(0.1, 0.9, 0.1, 0.9) 

    local mask = self.SpinFrame:CreateMaskTexture()
    mask:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    mask:SetSize(size * 0.9, size * 0.9) 
    mask:SetPoint("CENTER")
    self.Energy:AddMaskTexture(mask)

    self.AnimGroup = self.SpinFrame:CreateAnimationGroup()
    self.AnimGroup:SetLooping("REPEAT")
    
    self.Spin = self.AnimGroup:CreateAnimation("Rotation")
    self.Spin:SetOrder(1)

    self.Pulse = self.AnimGroup:CreateAnimation("Scale")
    self.Pulse:SetOrder(1)
    
    self.TextFrame = CreateFrame("Frame", nil, self)
    self.TextFrame:SetAllPoints()
    self.TextFrame:SetFrameLevel(self.SpinFrame:GetFrameLevel() + 10) 

    self.val = self.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); self.val:SetPoint("CENTER", 0, 0); self.val:SetTextColor(1, 1, 1)
    self.lbl = self.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); self.lbl:SetPoint("TOP", self, "BOTTOM", 0, -5); self.lbl:SetText(label:upper()); self.lbl:SetTextColor(0.6, 0.6, 0.6)
    
    self.cooldown = CreateFrame("Cooldown", nil, self.TextFrame, "CooldownFrameTemplate")
    self.cooldown:SetAllPoints(self)
    self.cooldown:SetSwipeTexture("Interface\\Minimap\\UI-Minimap-Background")
    self.cooldown:SetHideCountdownNumbers(true); self.cooldown:SetDrawEdge(false); self.cooldown:SetReverse(true)
    self.cooldown:SetUseCircularEdge(true)
    self.cooldown:SetAlpha(0.2) 
    self.cooldown.noCooldownCount = true
    self.cooldown.noOCC = true
    self.cooldown:SetHideCountdownNumbers(true)
end

function MSC_StatRingMixin:ApplyArt(statType)
    local targetTexture
    if statType == "Current Defense" or statType == "Crush Cap" or statType == "Defense"
        or statType == "Dodge" or statType == "Parry" or statType == "Block" then
        targetTexture = "Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\Ring_Rune.tga"
    elseif string_find(statType, "Hit") or string_find(statType, "Haste") or string_find(statType, "Power") or statType == "Healing" then
        targetTexture = "Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\Ring_Swirl.tga"
    elseif string_find(statType, "Crit") or statType == "Expertise" then
        targetTexture = "Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\Ring_Sun.tga"
    else
        targetTexture = "Interface\\Common\\RingBorder"
    end

    if self.CurrentStat == statType then return end
    self.CurrentStat = statType; self.CurrentArt = targetTexture
    self.Energy:SetVertexColor(1, 1, 1, 1)

    if self.AnimGroup:IsPlaying() then self.AnimGroup:Stop() end
    self.Spin:SetDuration(0)
    self.Pulse:SetDuration(0)
    self.Energy:SetRotation(0)
    self.Energy:SetTexture(targetTexture)

    if targetTexture:find("Ring_Rune") then
        self.Spin:SetDegrees(360); self.Spin:SetDuration(60)
        if statType == "Crush Cap" then self.Energy:SetVertexColor(1.0, 0.8, 0.2, 1)
        elseif statType == "Dodge" then self.Energy:SetVertexColor(0.4, 1.0, 0.6, 1)
        elseif statType == "Parry" then self.Energy:SetVertexColor(1.0, 0.55, 0.3, 1)
        elseif statType == "Block" then self.Energy:SetVertexColor(0.5, 0.75, 1.0, 1) end
    elseif targetTexture:find("Ring_Swirl") then
        self.Spin:SetDegrees(-360); self.Spin:SetDuration(30)
        if statType == "Spell Power" then self.Energy:SetVertexColor(0.2, 0.7, 1.0, 1)
        elseif statType == "Healing" then self.Energy:SetVertexColor(0.3, 1.0, 0.5, 1)
        elseif statType:find("Haste") then self.Energy:SetVertexColor(1.0, 0.8, 0.0, 1)
        elseif statType == "Spell Hit" then self.Energy:SetVertexColor(0.2, 1.0, 0.8, 1)
        else self.Energy:SetVertexColor(0.2, 1.0, 0.2, 1) end
    elseif targetTexture:find("Ring_Sun") then
        self.Pulse:SetScaleFrom(1, 1); self.Pulse:SetScaleTo(1.1, 1.1)
        self.Pulse:SetDuration(0.5); self.Pulse:SetSmoothing("IN_OUT")
        if statType:find("Spell") then self.Energy:SetVertexColor(0.8, 0.2, 1.0, 1)
        elseif statType:find("Crit") then self.Energy:SetVertexColor(1.0, 0.0, 0.0, 1)
        else self.Energy:SetVertexColor(1.0, 0.5, 0.0, 1) end
    end

    if (self.Spin:GetDuration() > 0 or self.Pulse:GetDuration() > 0) then
        self.AnimGroup:Play()
    end
end

local function CreateStatRing(parent, x, y, size, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size); f:SetPoint("TOPLEFT", x, y)
    Mixin(f, MSC_StatRingMixin)
    f:OnLoad(size, label)
    return f
end

-- Which set of Stat Logic rings a profile gets: "tank", "healer", "caster", "hunter" or "melee".
-- Read from the profile's key and display name, which always say the role ("PROT_DEEP",
-- "Protection: Solo Leveling", "Healer: Deep Holy", "Leveling_HOLY_DUNGEON_21_40").
function MSC.GetRingRole(class, profileKey)
    if class == "HUNTER" then return "hunter" end        -- includes "PvP: Survival Tank"
    if class == "MAGE" or class == "WARLOCK" then return "caster" end -- includes "Soul Link (Tank)"
    local key = tostring(profileKey or "")
    local pretty = (MSC.CurrentClass and MSC.CurrentClass.PrettyNames and MSC.CurrentClass.PrettyNames[key]) or ""
    local s = (key .. " " .. pretty):upper()
    if s:find("PROT") or s:find("TANK") or s:find("BEAR") or s:find("WARDEN") then return "tank" end
    -- Priest-only words ("Shadowstep" is a Rogue PvP build)
    if class == "PRIEST" and (s:find("SMITE") or s:find("SHADOW") or s:find("WEAVING")) then return "caster" end
    if s:find("HYBRID_ELE") or s:find("ELE /") then return "caster" end -- Ele / Resto (Nature's Swiftness)
    if s:find("HYBRID_ENH") or s:find("ENH /") then return "melee" end  -- Enh / Resto
    if s:find("HOLY") or s:find("RESTO") or s:find("DISC") or s:find("HEAL") or s:find("MOONGLOW")
        or s:find("REGROWTH") or s:find("TREE") or s:find("HOTW") or s:find("HEART OF THE WILD") then
        return "healer"
    end
    if s:find("BALANCE") or s:find("BOOMKIN") or s:find("CASTER") or s:find("ELE_") or s:find("ELEMENTAL")
        or s:find("SHOCK") or s:find("RECK") then
        return "caster"
    end
    if class == "PRIEST" then return "caster" end
    return "melee"
end

local function GetClassRings(class, stats, weights, profileKey)
    local playerLevel = UnitLevel("player")
	local rings = {}
    local CAP_HIT_MELEE = 9
    local CAP_HIT_SPELL = 16
    local CAP_EXP = 26
	local maxBaseDef = playerLevel * 5
	local CAP_DEF = maxBaseDef + 140
    local spellHitBonus = 0
    local meleeHitBonus = 0
    local expertBonus = 0
    local critBonus = 0
    local spellCritBonus = 0
    local isTBC = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
    local _, playerRace = UnitRace("player")

    local function GetTalentRank(tab, talentName)
        local found = 0
        MSC.ForEachTalent(tab, function(name, rank)
            if name == MSC.L[talentName] then found = rank; return true end
        end)
        return found
    end

    -- NEW: Tracking table for Tooltips
    local modifiers = {}
    local function AddMod(ringLabel, sourceName, value, isPercent)
        if value and (type(value) == "string" or value > 0) then
            if not modifiers[ringLabel] then modifiers[ringLabel] = {} end
            table_insert(modifiers[ringLabel], { source = sourceName, val = value, isPct = isPercent })
        end
    end

    if class == "MAGE" then
        local arcane = GetTalentRank(1, "Arcane Focus") * 2
        local frost = GetTalentRank(3, "Elemental Precision") * (isTBC and 1 or 2)
        spellHitBonus = math_max(arcane, frost)
        if arcane >= frost and arcane > 0 then AddMod("Spell Hit", "Arcane Focus", arcane, true)
        elseif frost > arcane then AddMod("Spell Hit", "Elemental Precision", frost, true) end
    elseif class == "WARLOCK" then
        -- Affliction spells only: not counted for the Shadow Bolt raid builds
        spellHitBonus = MSC.SuppressionCounts(profileKey) and GetTalentRank(1, "Suppression") * 2 or 0
        AddMod("Spell Hit", "Suppression", spellHitBonus, true)
    elseif class == "PRIEST" then
        spellHitBonus = GetTalentRank(3, "Shadow Focus") * 2
        AddMod("Spell Hit", "Shadow Focus", spellHitBonus, true)
    elseif class == "SHAMAN" then
        local elePrec = GetTalentRank(1, "Elemental Precision") * 2
        local natGuid = GetTalentRank(3, "Nature's Guidance") * 1
        local totemOfWrath = isTBC and (GetTalentRank(1, "Totem of Wrath") > 0 and 3 or 0) or 0
        local dwSpec = isTBC and (GetTalentRank(2, "Dual Wield Specialization") * 2) or 0
        spellHitBonus = elePrec + natGuid + totemOfWrath
        spellCritBonus = totemOfWrath
        meleeHitBonus = natGuid + dwSpec
        AddMod("Spell Hit", "Elemental Precision", elePrec, true)
        AddMod("Spell Hit", "Nature's Guidance", natGuid, true)
        if totemOfWrath > 0 then
            AddMod("Spell Hit", "Totem of Wrath", totemOfWrath, true)
            AddMod("Spell Crit", "Totem of Wrath", totemOfWrath, true)
        end
        AddMod("Hit Cap", "Nature's Guidance", natGuid, true)
        if dwSpec > 0 then
            AddMod("Hit Cap", "Dual Wield Specialization", dwSpec, true)
        end
    elseif class == "DRUID" then
        if isTBC then 
            spellHitBonus = GetTalentRank(1, "Balance of Power") * 2 
            AddMod("Spell Hit", "Balance of Power", spellHitBonus, true)
            local sotf = GetTalentRank(2, "Survival of the Fittest")
            if sotf > 0 then
                local reduction = (sotf == 3 and 75) or (sotf == 2 and 50) or (sotf == 1 and 25) or 0
                AddMod("Current Defense", "Survival of the Fittest", string.format(MSC.L["Cap reduced by %d"], reduction), false)
            end
            if sotf == 3 then CAP_DEF = maxBaseDef + 65
            elseif sotf == 2 then CAP_DEF = maxBaseDef + 90
            elseif sotf == 1 then CAP_DEF = maxBaseDef + 115 
            end
        end
    elseif class == "ROGUE" then
        meleeHitBonus = GetTalentRank(2, "Precision") * 1
        AddMod("Hit Cap", "Precision", meleeHitBonus, true)
        local wepExp = GetTalentRank(2, "Weapon Expertise")
        expertBonus = expertBonus + (wepExp * 5)
        AddMod("Expertise", "Weapon Expertise", wepExp * 5, false)
    elseif class == "HUNTER" then
        meleeHitBonus = GetTalentRank(3, "Surefooted") * 1
        AddMod("Hit Cap", "Surefooted", meleeHitBonus, true)
    elseif class == "PALADIN" or class == "WARRIOR" then
        meleeHitBonus = GetTalentRank(2, "Precision") * 1
        AddMod("Hit Cap", "Precision", meleeHitBonus, true)
        if class == "PALADIN" then 
            spellHitBonus = meleeHitBonus 
            AddMod("Spell Hit", "Precision", spellHitBonus, true)
            if isTBC then 
                local cbExp = GetTalentRank(2, "Combat Expertise")
                expertBonus = expertBonus + cbExp 
                AddMod("Expertise", "Combat Expertise", cbExp, false)
            end
        end
        if class == "WARRIOR" and isTBC then 
            local def = GetTalentRank(3, "Defiance") * 2
            expertBonus = expertBonus + def
            AddMod("Expertise", "Defiance", def, false)
        end
    end

    local mhLink = GetInventoryItemLink("player", 16)
    if mhLink then
        local _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(mhLink)
        if MSC.IsForever then
            -- no weapon racials on Forever; Human Ruthless is +1% crit with any weapon (launch racial pass, dev notes
            -- of October 26; Orc Savage and Dwarf Earth Fury are gone)
            if playerRace == "Human" then
                critBonus = critBonus + 1
                spellCritBonus = spellCritBonus + 1
                AddMod("Crit", "Ruthless (Human)", 1, true)
                AddMod("Spell Crit", "Ruthless (Human)", 1, true)
            end
        else
            if playerRace == "Human" then
                if subClassID == 7 or subClassID == 8 or subClassID == 4 or subClassID == 5 then
                    expertBonus = expertBonus + 5
                    AddMod("Expertise", "Mace/Sword Spec (Human)", 5, false)
                end
            elseif playerRace == "Orc" then
                if subClassID == 0 or subClassID == 1 then
                    expertBonus = expertBonus + 5
                    AddMod("Expertise", "Axe Spec (Orc)", 5, false)
                end
            end
        end
    end

    local rangedLink = GetInventoryItemLink("player", 18)
    if rangedLink and not MSC.IsForever then
        local _, _, _, _, _, _, _, _, _, _, _, classID, subClassID = GetItemInfo(rangedLink)
        if playerRace == "Dwarf" then
            if subClassID == 3 then 
                critBonus = critBonus + 1 
                AddMod("Crit", "Gun Spec (Dwarf)", 1, true)
            end 
        elseif playerRace == "Troll" then
            if subClassID == 2 then 
                critBonus = critBonus + 1 
                AddMod("Crit", "Bow Spec (Troll)", 1, true)
            end 
        end
    end
    
    -- Forever: Dwarf Artisan's Precision, +1% hit with spells and attacks (Tauren Endurance lost its hit at launch)
    if MSC.IsForever and playerRace == "Dwarf" then
        meleeHitBonus = meleeHitBonus + 1
        spellHitBonus = spellHitBonus + 1
        AddMod("Hit Cap", "Artisan's Precision (Dwarf)", 1, true)
        AddMod("Spell Hit", "Artisan's Precision (Dwarf)", 1, true)
    end

    if isTBC and playerRace == "Draenei" then
        spellHitBonus = spellHitBonus + 1
        meleeHitBonus = meleeHitBonus + 1
        AddMod("Hit Cap", "Heroic Presence (Draenei)", 1, true)
        AddMod("Spell Hit", "Inspiring Presence (Draenei)", 1, true)
    end

    if isTBC and MSC.BuffEngine and RXP_SGJ_Settings and RXP_SGJ_Settings.AssumeRaidBuffs then
        local _, specKey = MSC.GetCurrentWeights()
        local raidSpell = MSC.BuffEngine:GetRaidHitCreditPct("SPELL", specKey)
        local raidMelee = MSC.BuffEngine:GetRaidHitCreditPct("MELEE", specKey)
        if raidSpell > 0 then
            spellHitBonus = spellHitBonus + raidSpell
            for _, mod in ipairs(MSC.BuffEngine:GetCapModifiersForUI(specKey, "SPELL")) do
                if mod.isPct and mod.source ~= "Heroic Presence (Racial)" then
                    AddMod("Spell Hit", mod.source, mod.val, true)
                end
            end
        end
        if raidMelee > 0 then
            meleeHitBonus = meleeHitBonus + raidMelee
            if MSC.BuffEngine:IsRaidBuffOn("IMPROVED_FAERIE_FIRE") then
                AddMod("Hit Cap", "Improved Faerie Fire", 3, true)
            end
        end
    end

    -- Era: general hit talents are already in the game's hit % (GetHitModifier)
    if MSC.IsEra then modifiers["Hit Cap"] = nil end
    local foreverSchoolHit = 0
    if MSC.IsForever then
        modifiers["Hit Cap"] = nil; modifiers["Spell Hit"] = nil
        local function FRank(k) return MSC.GetTalentRank and (MSC:GetTalentRank(k) or 0) or 0 end
        local pretty = (MSC.CurrentClass and MSC.CurrentClass.PrettyNames and MSC.CurrentClass.PrettyNames[profileKey or ""]) or ""
        local spec = (tostring(profileKey or "") .. " " .. pretty):upper()
        if class == "MAGE" then
            -- the same talent hit the weights use (Mage:SchoolHit: only what the game's number doesn't hold)
            local cc = MSC.CurrentClass
            foreverSchoolHit = (cc and cc.SchoolHit and cc:SchoolHit(profileKey)) or 0
            AddMod("Spell Hit", "Elemental Precision", foreverSchoolHit, true)
        elseif class == "PRIEST" then
            if spec:find("SHADOW") then
                foreverSchoolHit = FRank("SHADOW_FOCUS"); AddMod("Spell Hit", "Shadow Focus", foreverSchoolHit, true)
            elseif spec:find("SMITE") then
                foreverSchoolHit = FRank("HOLY_PRECISION") * 6; AddMod("Spell Hit", "Holy Precision", foreverSchoolHit, true)
            end
        end
    end

    local function AddRing(label, statKey, capTarget, formatStr, isSkill)
        local val = stats[statKey] or 0
        local currentDisplay = 0; local capRating = 0; local scalar = 0
        local isCustomCap = false
        local isRating = false

        if statKey == "CRUSH_CAP" then
			isCustomCap = true
			local buffBonus = 0
			
			local hasHolyShield = MSC.IsForever and ((MSC.GetTalentRank and MSC:GetTalentRank("HOLY_SHIELD") or 0) > 0)
				or (not MSC.IsForever and GetTalentRank(2, "Holy Shield") > 0)
			if class == "PALADIN" and hasHolyShield then
				buffBonus = 30.0
                AddMod("Crush Cap", "Holy Shield", 30.0, true)
			elseif class == "WARRIOR" and UnitLevel("player") >= 16 then -- Shield Block is learned at 16
				buffBonus = 75.0
                AddMod("Crush Cap", "Shield Block", 75.0, true)
			end
			
			-- 5% Base Miss + Avoidance Stats + Active Buff
			val = 5.0 + MSC.SanitizeStat(GetDodgeChance()) + MSC.SanitizeStat(GetParryChance()) + MSC.GetPassiveBlockChance() + buffBonus
			currentDisplay = val
			capRating = capTarget
            
        elseif statKey == "ITEM_MOD_HIT_RATING_SHORT" then val = MSC.SanitizeStat(GetCombatRating(6)); isRating = true
        elseif statKey == "ITEM_MOD_HIT_SPELL_RATING_SHORT" then val = MSC.SanitizeStat(GetCombatRating(8)); isRating = true
        elseif statKey == "ITEM_MOD_EXPERTISE_RATING_SHORT" then val = MSC.SanitizeStat(GetCombatRating(24)); isRating = true
        elseif statKey == "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT" then val = MSC.SanitizeStat(GetCombatRating(2)); isRating = true
        elseif statKey == "ITEM_MOD_CRIT_RATING_SHORT" then val = MSC.SanitizeStat(GetCombatRating(9)); isRating = true
        elseif statKey == "ITEM_MOD_SPELL_CRIT_RATING_SHORT" then val = MSC.SanitizeStat(GetCombatRating(11)); isRating = true
        elseif statKey == "ITEM_MOD_HASTE_RATING_SHORT" then val = MSC.SanitizeStat(GetCombatRating(18)); isRating = true
        elseif statKey == "ITEM_MOD_SPELL_HASTE_RATING_SHORT" then val = MSC.SanitizeStat(GetCombatRating(20)); isRating = true
        elseif statKey == "ITEM_MOD_DODGE_RATING_SHORT" then val = MSC.SanitizeStat(GetCombatRating(3)); isRating = true
        elseif statKey == "ITEM_MOD_SPELL_HEALING_DONE_SHORT" then
            val = GetSpellBonusHealing and MSC.SanitizeStat(GetSpellBonusHealing()) or 0
            currentDisplay = val
            capRating = capTarget
        elseif statKey == "ITEM_MOD_SPELL_POWER_SHORT" then 
            local maxSP = 0
            for i=2, 7 do maxSP = math_max(maxSP, MSC.SanitizeStat(GetSpellBonusDamage(i))) end
            val = maxSP
            currentDisplay = val
            capRating = capTarget
        end
        local isFlatValue = (statKey == "ITEM_MOD_SPELL_POWER_SHORT" or statKey == "ITEM_MOD_SPELL_HEALING_DONE_SHORT")

        if not isCustomCap and not isFlatValue then
            local level = UnitLevel("player"); if level > 70 then level = 70 end
            if label == "Expertise" then
                scalar = (MSC.CombatRatingScalars and MSC.CombatRatingScalars[level]) and MSC.CombatRatingScalars[level][1] or 3.94
            elseif label == "Current Defense" then
                scalar = (MSC.CombatRatingScalars and MSC.CombatRatingScalars[level]) and MSC.CombatRatingScalars[level][2] or 2.37
            else
                local idx = MSC.RatingIndexMap and MSC.RatingIndexMap[statKey]
                if idx and MSC.CombatRatingScalars and MSC.CombatRatingScalars[level] then scalar = MSC.CombatRatingScalars[level][idx] else scalar = 15.8 end
            end
    
            if isSkill then
				if label == "Current Defense" then
					-- 1. Safely grab ONLY the base leveled skill
					local baseDefRaw, defBonus = UnitDefense("player")
					local baseDef = MSC.SanitizeStat(baseDefRaw)
					
					-- Fallback in case the API fires before the player is fully loaded
					if not baseDef or baseDef == 0 then
						baseDef = UnitLevel("player") * 5
					end
					
					-- 2. Add your true base skill to the addon's evaluated gear skill
					local skillAdded = math_floor(val / scalar)
					-- Era gear gives +Defense skill, not rating: the game's bonus already holds it
					if MSC.IsEra then skillAdded = MSC.SanitizeStat(defBonus) end
					currentDisplay = baseDef + skillAdded
					
					-- 3. Calculate the shortfall gap based on your true total
					local skillShortfall = math_max(0, capTarget - currentDisplay)
					
					-- 4. Set the visual target cap
					capRating = val + (skillShortfall * scalar)
				else
					local skillAdded = math_floor(val / scalar)
					currentDisplay = skillAdded + expertBonus
					local skillShortfall = math_max(0, capTarget - currentDisplay)
					capRating = capTarget > 0 and (val + (skillShortfall * scalar)) or 0
				end
            elseif isRating then
                if label == "Dodge" then
                    currentDisplay = MSC.SanitizeStat(GetDodgeChance())
                elseif string_find(label, "Spell Crit") then
                    local maxCrit = 0
                    for s=2, 7 do maxCrit = math_max(maxCrit, MSC.SanitizeStat(GetSpellCritChance(s)) or 0) end
                    local hasTotemOfWrathBuff = false
                    local totemName = MSC.L["Totem of Wrath"]
                    MSC.ForEachPlayerBuff(function(_, auraData)
                        local name = auraData and auraData.name
                        if name and not MSC_IsSecret(name) and name == totemName then
                            hasTotemOfWrathBuff = true
                            return true
                        end
                    end)
                    if hasTotemOfWrathBuff and (isTBC and class == "SHAMAN" and GetTalentRank(1, "Totem of Wrath") > 0) then
                        currentDisplay = maxCrit + math_max(0, spellCritBonus - 3)
                    else
                        currentDisplay = maxCrit + spellCritBonus
                    end
                elseif string_find(label, "Crit") then
                    if class == "HUNTER" and GetRangedCritChance then
                        currentDisplay = GetRangedCritChance() + critBonus
                    else
                        currentDisplay = MSC.SanitizeStat(GetCritChance()) + critBonus
                    end
                else
                    currentDisplay = val / scalar
                    if label == "Hit Cap" then
                        currentDisplay = currentDisplay + meleeHitBonus
                    elseif label == "Spell Hit" then
                        currentDisplay = currentDisplay + spellHitBonus
                    end
                end
                
                -- Safely map out Rating shortfalls for tooltips 
                local shortfall = math_max(0, capTarget - currentDisplay)
                capRating = capTarget > 0 and (val + (shortfall * scalar)) or 0
            end
        end

        if MSC.IsEra and not isCustomCap and not isFlatValue then
            -- Era gear gives a flat "+1% hit", not rating: read the game's hit % (gear and talents)
            if label == "Hit Cap" then
                currentDisplay = MSC.SanitizeStat(GetHitModifier and GetHitModifier() or 0)
                capRating = 0
            elseif label == "Spell Hit" then
                currentDisplay = MSC.SanitizeStat(GetSpellHitModifier and GetSpellHitModifier() or 0) + spellHitBonus
                capRating = 0
            end
        end
        if MSC.IsForever and not isCustomCap and not isFlatValue then
            if label == "Hit Cap" then
                capTarget = MSC.GetForeverCapTarget("MELEE") or capTarget
                local meleeHunter = tostring(profileKey or ""):upper():find("MELEE") ~= nil
                currentDisplay = MSC:GetForeverHitPercent((class == "HUNTER" and not meleeHunter) and "RANGED" or "MELEE")
                scalar = 10 -- Forever: 10 Hit Rating = 1% at every level
                capRating = val + math_max(0, capTarget - currentDisplay) * scalar
            elseif label == "Spell Hit" then
                capTarget = MSC.GetForeverCapTarget("SPELL") or capTarget
                currentDisplay = MSC:GetForeverHitPercent("SPELL") + foreverSchoolHit
                scalar = 10
                capRating = val + math_max(0, capTarget - currentDisplay) * scalar
            elseif label == "Current Defense" then
                -- No defense target below 50: the ring shows your defense without one
                capTarget = MSC.GetForeverDefenseTarget() or 0
                capRating = capTarget > 0 and (val + math_max(0, capTarget - currentDisplay) * scalar) or 0
            end
        end

        table_insert(rings, { l=label, v=currentDisplay, m=capTarget, fmt=formatStr, rawVal = val, rawCap = capRating, scalar = scalar, isCustom = isCustomCap, mods = modifiers[label] })
    end

    -- Avoidance chance as a ring with no target (Forever tanks): dodge, parry or block %.
    local function AddAvoidRing(label, getter, ratingIndex)
        local pct = getter and MSC.SanitizeStat(getter()) or 0
        local rating = GetCombatRating and MSC.SanitizeStat(GetCombatRating(ratingIndex)) or 0
        table_insert(rings, { l=label, v=pct, m=0, fmt="%.1f%%", rawVal = rating, rawCap = 0, scalar = 0, mods = modifiers[label] })
    end

   -- [[ ROLE SELECTOR ]]
    -- The role comes from the profile (its key and name), not from its weights: Forever's
    -- Retribution and Protection weight Spell Power above Attack Power, and healers weight
    -- neither, so the weights alone handed them caster or melee rings.
    local role = MSC.GetRingRole(class, profileKey)
    local noRatings = MSC.IsVanillaRules -- Era and Forever have no Haste or Expertise ratings
    local blocks = (class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN")

    if role == "tank" then
        AddRing("Current Defense", "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", CAP_DEF, "%d", true)
        if blocks then AddRing("Crush Cap", "CRUSH_CAP", 102.4, "%.2f%%") end
        if MSC.IsForever then
            -- Forever: show each avoidance stat too (the window has room for six rings)
            AddAvoidRing("Dodge", GetDodgeChance, 3)
            if blocks then
                AddAvoidRing("Parry", GetParryChance, 4)
                AddAvoidRing("Block", GetBlockChance, 5)
            end
        elseif class == "DRUID" then
            -- Druids can't block or parry: Dodge instead of a Crush Cap
            AddRing("Dodge", "ITEM_MOD_DODGE_RATING_SHORT", 40, "%.1f%%")
        end
        AddRing("Hit Cap", "ITEM_MOD_HIT_RATING_SHORT", CAP_HIT_MELEE, "%.1f%%")
        if not noRatings then AddRing("Expertise", "ITEM_MOD_EXPERTISE_RATING_SHORT", CAP_EXP, "%d", true) end
    elseif role == "healer" then
        AddRing("Spell Crit", "ITEM_MOD_SPELL_CRIT_RATING_SHORT", 30, "%.1f%%")
        if not noRatings then AddRing("Haste", "ITEM_MOD_SPELL_HASTE_RATING_SHORT", 20, "%.1f%%") end
        AddRing("Healing", "ITEM_MOD_SPELL_HEALING_DONE_SHORT", 0, "%d")
    elseif role == "caster" then
        AddRing("Spell Hit", "ITEM_MOD_HIT_SPELL_RATING_SHORT", CAP_HIT_SPELL, "%.1f%%")
        AddRing("Spell Crit", "ITEM_MOD_SPELL_CRIT_RATING_SHORT", 30, "%.1f%%")
        if not noRatings then AddRing("Haste", "ITEM_MOD_SPELL_HASTE_RATING_SHORT", 20, "%.1f%%") end
        AddRing("Spell Power", "ITEM_MOD_SPELL_POWER_SHORT", 0, "%d")
    else -- melee and hunter
        AddRing("Hit Cap", "ITEM_MOD_HIT_RATING_SHORT", CAP_HIT_MELEE, "%.1f%%")
        AddRing("Crit", "ITEM_MOD_CRIT_RATING_SHORT", 35, "%.1f%%")
        if not noRatings then AddRing("Haste", "ITEM_MOD_HASTE_RATING_SHORT", 20, "%.1f%%") end
        -- Hunters don't use Expertise
        if not noRatings and role ~= "hunter" then AddRing("Expertise", "ITEM_MOD_EXPERTISE_RATING_SHORT", CAP_EXP, "%d", true) end
    end
    return rings
end

-- Layout: profile and cap rings (left) | stat weight bars, full width (right, scrolls)
local LOGIC_LEFT_W = 220

function MSC.InitLogicView(parent)
    local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()

    -- ==========================================
    -- LEFT: PROFILE AND CAP RINGS
    -- ==========================================
    local L = CreateFrame("Frame", nil, f)
    L:SetPoint("TOPLEFT"); L:SetPoint("BOTTOMLEFT"); L:SetWidth(LOGIC_LEFT_W)
    local shade = L:CreateTexture(nil, "BACKGROUND"); shade:SetAllPoints(); shade:SetColorTexture(0, 0, 0, 0.25)
    local line = L:CreateTexture(nil, "BORDER"); line:SetColorTexture(1, 1, 1, 0.08); line:SetWidth(1)
    line:SetPoint("TOPRIGHT"); line:SetPoint("BOTTOMRIGHT")
    f.LeftCol = L

    local profLbl = L:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profLbl:SetPoint("TOPLEFT", 14, -12); profLbl:SetText(MSC.L["Scoring Profile"]); MSC.StyleHeading(profLbl, "Gold", LOGIC_LEFT_W - 28)
    f.ProfileName = L:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.ProfileName:SetPoint("TOPLEFT", profLbl, "BOTTOMLEFT", 0, -11); f.ProfileName:SetWidth(LOGIC_LEFT_W - 28); f.ProfileName:SetJustifyH("LEFT")
    f.ProfileNote = L:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.ProfileNote:SetPoint("TOPLEFT", f.ProfileName, "BOTTOMLEFT", 0, -4); f.ProfileNote:SetWidth(LOGIC_LEFT_W - 28); f.ProfileNote:SetJustifyH("LEFT")
    f.ProfileNote:SetTextColor(1, 0.6, 0.2)

    local capLbl = L:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capLbl:SetPoint("TOPLEFT", 14, -110); capLbl:SetText(MSC.L["Caps and Key Stats"]); MSC.StyleHeading(capLbl, "Teal", LOGIC_LEFT_W - 28)
    f.RingArea = CreateFrame("Frame", nil, L)
    f.RingArea:SetPoint("TOPLEFT", capLbl, "BOTTOMLEFT", -14, -14); f.RingArea:SetSize(LOGIC_LEFT_W, 260)
    f.NoRings = L:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.NoRings:SetPoint("TOPLEFT", capLbl, "BOTTOMLEFT", 0, -12); f.NoRings:SetWidth(LOGIC_LEFT_W - 28); f.NoRings:SetJustifyH("LEFT")
    f.NoRings:SetText(MSC.L["No caps to track for this profile."]); f.NoRings:SetTextColor(0.6, 0.6, 0.6); f.NoRings:Hide()

    local hint = L:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 14, 14); hint:SetWidth(LOGIC_LEFT_W - 28); hint:SetJustifyH("LEFT")
    hint:SetText(MSC.L["Hover a ring or a bar to see the math behind it."]); hint:SetTextColor(0.5, 0.5, 0.5)

    -- ==========================================
    -- RIGHT: STAT WEIGHTS
    -- ==========================================
    local wLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wLbl:SetPoint("TOPLEFT", L, "TOPRIGHT", 16, -12); wLbl:SetText(MSC.L["Stat Weights"]); MSC.StyleHeading(wLbl, "Purple", 830 - LOGIC_LEFT_W - 46)
    local wSub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wSub:SetPoint("LEFT", wLbl, "RIGHT", 10, 0); wSub:SetText(MSC.L["Score per point of each stat, highest first"]); wSub:SetTextColor(0.6, 0.6, 0.6)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", L, "TOPRIGHT", 12, -36); scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(560, 800); scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w) if w and w > 100 then content:SetWidth(w) end end)
    f.Scroll = scroll
    f.Content = content
    f:SetScript("OnShow", function() MSC.UpdateLogic() end)
    MSC.ViewLogic = f
end

function MSC.UpdateLogic()
    if not MSC.ViewLogic or not MSC.ViewLogic:IsShown() then return end
    local content = MSC.ViewLogic.Content
    
    if content.children then for _, c in ipairs(content.children) do c:Hide() end end
    content.children = {}

    local weights, detectedKey, capText, specConfidence = MSC.GetCurrentWeights()
    if not weights and MSC.CurrentClass then detectedKey, weights = next(MSC.CurrentClass.Weights) end
    if not weights then return end

    local uncertainNote
    local profileLabel = (MSC.CurrentClass and MSC.CurrentClass.PrettyNames and MSC.CurrentClass.PrettyNames[detectedKey]) or detectedKey or ""
    if RXP_SGJ_Settings and MSC.ManualSpec == "AUTO" and specConfidence and specConfidence ~= "high" then
        uncertainNote = MSC.L[" (uncertain — pick profile manually if wrong)"]:gsub("^%s*%((.-)%)%s*$", "%1")
    end
    local view = MSC.ViewLogic
    if MSC.HasDualSpec() then profileLabel = profileLabel .. " |cff888888(" .. MSC.SpecGroupName(MSC.GetActiveSpecGroup()) .. ")|r" end
    view.ProfileName:SetText(profileLabel)
    if specConfidence == "ambiguous" then view.ProfileName:SetTextColor(1, 0.6, 0.2) else view.ProfileName:SetTextColor(1, 1, 1) end
    view.ProfileNote:SetText(uncertainNote or "")
    
    local currentGear = {}
    for i=1, 18 do currentGear[i] = GetInventoryItemLink("player", i) end
    
    local _, stats = MSC:GetTotalCharacterScore(currentGear, weights, detectedKey)
    local rings = GetClassRings(select(2, UnitClass("player")), stats, weights, detectedKey)
    
    for i, ring in ipairs(rings) do
        if i <= 6 then -- up to six (Forever tanks: defense, crush, dodge, parry, block, hit)
            local col, row = (i - 1) % 2, math_floor((i - 1) / 2)
            local f = MSC.GetFromPool("Rings", view.RingArea, function(p) return CreateStatRing(p, 0, 0, 80, "TEMP") end)
            f:ClearAllPoints(); f:SetPoint("TOPLEFT", view.RingArea, "TOPLEFT", 20 + col * 100, -(row * 130))
            f.lbl:SetWidth(100)
            local locLabel = MSC.L[ring.l] or ring.l
            f.lbl:SetText(locLabel:upper())
            f.val:SetText(string_format(ring.fmt, ring.v))
            f:ApplyArt(ring.l) 
            local fillPct = 0
            if ring.m > 0 then fillPct = math_min(100, (ring.v / ring.m) * 100) end
            local r,g,b = 0, 0, 0
            if string_find(ring.l, "Cap") or string_find(ring.l, "Hit") or string_find(ring.l, "Expertise") or string_find(ring.l, "Def") then
                if fillPct >= 100 then r,g,b = 0, 1, 0 end
            end
            f.cooldown:SetSwipeColor(r,g,b)
            local dur = 100000
            f.cooldown:SetCooldown(GetTime() - (dur * (fillPct/100)), dur)
            f.cooldown:Pause()
            f:EnableMouse(true)
            f:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local locLabel = MSC.L[ring.l] or ring.l
                GameTooltip:SetText(locLabel, 1, 1, 1)
                GameTooltip:AddLine(" ")
                
                -- Custom Tooltip logic for Crush Cap
                if ring.isCustom and ring.l == "Crush Cap" then
                    GameTooltip:AddDoubleLine(MSC.L["Current Avoidance:"], string_format("%.2f%%", ring.v), 1, 0.82, 0, 1, 1, 1)
                    local diff = ring.m - ring.v
                    if diff > 0 then 
                        GameTooltip:AddLine(string_format(MSC.L["Need %.2f%% more to cap."], diff), 1, 0.5, 0.5) 
                    else 
                        GameTooltip:AddLine(MSC.L["Uncrushable!"], 0, 1, 0) 
                    end
                elseif ring.rawVal and ring.rawCap and ring.rawCap > 0 then
                    GameTooltip:AddDoubleLine(MSC.L["Rating:"], string_format("%d / %d", ring.rawVal, ring.rawCap), 1, 0.82, 0, 1, 1, 1)
                    local diff = ring.rawCap - ring.rawVal
                    if diff > 0 then 
                        GameTooltip:AddLine(string_format(MSC.L["Need %d more rating to cap."], diff), 1, 0.5, 0.5) 
                    else 
                        GameTooltip:AddLine(MSC.L["Cap reached!"], 0, 1, 0) 
                    end
                else
                    GameTooltip:AddDoubleLine(MSC.L["Current Rating:"], string_format("%d", ring.rawVal), 1, 0.82, 0, 1, 1, 1)
                end
                if ring.scalar and ring.scalar > 1 then 
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(string_format(MSC.L["1%% requires %.2f Rating"], ring.scalar), 0.6, 0.6, 0.6) 
                end

                -- NEW: Draw Modifiers if they exist
                if ring.mods and #ring.mods > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(MSC.L["Active Modifiers:"], 0.2, 1, 0.8) -- Distinct Teal Color
                    for _, mod in ipairs(ring.mods) do
                        local modValStr = ""
                        if type(mod.val) == "string" then
                            modValStr = mod.val
                        else
                            modValStr = string_format(mod.isPct and "+%.0f%%" or "+%d", mod.val)
                        end
                        GameTooltip:AddDoubleLine(mod.source and MSC.L[mod.source] or "", modValStr, 0.8, 0.8, 0.8, 0, 1, 0)
                    end
                end

                GameTooltip:Show(); self:SetAlpha(1)
            end)

            f:SetScript("OnLeave", function(self) GameTooltip:Hide(); self:SetAlpha(1) end)
            table_insert(content.children, f)
        end
    end

    view.NoRings:SetShown(#rings == 0)

    local barW = content:GetWidth() - 10
    local yOff = -2
    local sorted = {}
    local maxW = 0
    for k, v in pairs(weights) do 
        if type(v) == "number" and v > 0 then 
            table_insert(sorted, {k=k, v=v})
            if v > maxW then maxW = v end 
        end 
    end
    table_sort(sorted, function(a,b) return a.v > b.v end)

    for _, s in ipairs(sorted) do
        local bar = MSC.GetFromPool("WeightRows", content, function(p)
             -- Stat name left, weight right, the reason under the name, a thin bar along the bottom
             local b = CreateFrame("Frame", nil, p)
             b:EnableMouse(true)
             b.Hover = b:CreateTexture(nil, "BACKGROUND"); b.Hover:SetAllPoints(); b.Hover:SetColorTexture(1, 1, 1, 0.04); b.Hover:Hide()
             b.Track = b:CreateTexture(nil, "BORDER"); b.Track:SetColorTexture(1, 1, 1, 0.06); b.Track:SetHeight(3)
             b.Track:SetPoint("BOTTOMLEFT", 4, 2); b.Track:SetPoint("BOTTOMRIGHT", -4, 2)
             b.Fill = CreateFrame("StatusBar", nil, b); b.Fill:SetAllPoints(b.Track)
             b.Fill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
             b:SetScript("OnEnter", function(self)
                 GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                 GameTooltip:SetText(self.StatName, 1, 1, 1)
                 if self.CurrentVal and self.CurrentVal > 0 then
                     GameTooltip:AddLine(" ")
                     local scoreContrib = (self.Weight or 0) * self.CurrentVal
                     GameTooltip:AddDoubleLine(MSC.L["Gear Contribution:"], string_format("%.1f", self.CurrentVal), 1, 1, 1, 1, 1, 1)
                     if self.RealTotal and self.RealTotal > 0 then
                         if math_abs(self.RealTotal - self.CurrentVal) > 1 then
                             GameTooltip:AddDoubleLine(MSC.L["Character Sheet:"], string_format(MSC.L["%d (Includes Base/Enchants)"], self.RealTotal), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
                         end
                     end
                     GameTooltip:AddLine(" ")
                     GameTooltip:AddDoubleLine(MSC.L["Score Calculation:"], " ", 1, 0.82, 0)
                     GameTooltip:AddLine(string_format(MSC.L["%.2f (Weight) x %.1f (Gear)"], self.Weight, self.CurrentVal), 1, 1, 1)
                     GameTooltip:AddDoubleLine(MSC.L["= Score:"], string_format("%.1f", scoreContrib), nil, nil, nil, 0, 1, 0)
                 else
                     GameTooltip:AddDoubleLine(MSC.L["Stat Weight:"], string_format("%.2f", self.Weight or 0), nil,nil,nil, 0, 1, 0)
                     GameTooltip:AddLine(MSC.L["You currently have 0 of this stat from gear."], 0.6, 0.6, 0.6)
                 end
                 if self.Reason then 
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(self.Reason, 0.6, 0.6, 0.6, true) 
                 end
                 GameTooltip:Show()
                 self.Hover:Show()
             end)
             b:SetScript("OnLeave", function(self) GameTooltip:Hide(); self.Hover:Hide() end)
             b.leftT = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); b.leftT:SetPoint("TOPLEFT", 4, -3)
             b.rightT = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); b.rightT:SetPoint("TOPRIGHT", -4, -3)
             b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.sub:SetPoint("TOPLEFT", b.leftT, "BOTTOMLEFT", 0, -2)
             return b
        end)
        
        local name = (MSC.GetCleanStatName and MSC.GetCleanStatName(s.k)) or s.k
        local reason = GetStatReason(tostring(s.k):upper(), class, detectedKey)
        local currentVal = stats[s.k] or 0
        local realTotal = 0 

        bar.StatName = name; bar.Weight = s.v; bar.Reason = reason; bar.CurrentVal = currentVal

        bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", 0, yOff); bar:SetSize(barW, 36)
        bar.sub:SetWidth(barW - 8); bar.sub:SetJustifyH("LEFT"); bar.sub:SetWordWrap(false)
        bar.Fill:SetMinMaxValues(0, maxW); bar.Fill:SetValue(s.v)
        
        local statKey = s.k:upper()
        local r, g, b = 0.5, 0.5, 0.5 
        
        if string_find(statKey, "SPELL_HIT") then r,g,b = unpack(MSC.StatColors.SPELL_HIT)
        elseif string_find(statKey, "SPELL_CRIT") then r,g,b = unpack(MSC.StatColors.SPELL_CRIT)
        elseif string_find(statKey, "SPELL_POWER") then r,g,b = unpack(MSC.StatColors.SPELL_POWER)
        else
            for key, color in pairs(MSC.StatColors) do
                if string_find(statKey, key) and not string_find(key, "SPELL") then 
                    r,g,b = unpack(color); break 
                end
            end
        end
        bar.Fill:GetStatusBarTexture():SetGradient("HORIZONTAL", CreateColor(r*0.4, g*0.4, b*0.4, 1), CreateColor(r, g, b, 1))
        bar.leftT:SetText(name:gsub("Rating", "")); bar.rightT:SetText(string_format("%.2f", s.v))
        bar.rightT:SetTextColor(math_min(1, r + 0.3), math_min(1, g + 0.3), math_min(1, b + 0.3))
        if reason then bar.sub:SetText(reason); bar.sub:SetTextColor(unpack(MSC.Theme.Muted)); bar.sub:Show() else bar.sub:Hide() end
        yOff = yOff - 40
        table_insert(content.children, bar)
    end
    content:SetHeight(math_abs(yOff) + 50)
end

-- Layout: section list (left) | option cards in two columns, with the spec list across the bottom (right, scrolls)
local SETTINGS_NAV_W, SETTINGS_GAP, SETTINGS_PAD = 190, 12, 12
local SETTINGS_CONTENT_W = 600 -- 830 content - nav - scroll bar and margins
local SETTINGS_COL_W = (SETTINGS_CONTENT_W - SETTINGS_GAP) / 2

function MSC.InitSettingsView(parent)
    -- Helpers.lua rebuilds this view once saved custom profiles load. Retire the old copy so two don't stack.
    local old = MSC.ViewSettings
    local wasShown = old and old:IsShown()
    if old then old:Hide(); old:SetScript("OnShow", nil) end

    local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()

    -- ==========================================
    -- LEFT: SECTION LIST AND ACTIONS
    -- ==========================================
    local nav = CreateFrame("Frame", nil, f)
    nav:SetPoint("TOPLEFT"); nav:SetPoint("BOTTOMLEFT"); nav:SetWidth(SETTINGS_NAV_W)
    local navShade = nav:CreateTexture(nil, "BACKGROUND"); navShade:SetAllPoints(); navShade:SetColorTexture(0, 0, 0, 0.25)
    local navLine = nav:CreateTexture(nil, "BORDER"); navLine:SetColorTexture(1, 1, 1, 0.08); navLine:SetWidth(1)
    navLine:SetPoint("TOPRIGHT"); navLine:SetPoint("BOTTOMRIGHT")

    local navTitle = nav:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    navTitle:SetPoint("TOPLEFT", 14, -12); navTitle:SetText(MSC.L["Protocol"]); MSC.StyleHeading(navTitle, "Gold", SETTINGS_NAV_W - 28)
    local navSub = nav:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    navSub:SetPoint("TOPLEFT", navTitle, "BOTTOMLEFT", 0, -9); navSub:SetText(MSC.L["Jump to a section"]); navSub:SetTextColor(0.6, 0.6, 0.6)

    -- [[ ACTION BUTTONS (pinned to the bottom of the list) ]]
    local bExport = CreateFrame("Button", nil, nav, "UIPanelButtonTemplate")
    bExport:SetSize(SETTINGS_NAV_W - 24, 26); bExport:SetPoint("BOTTOMLEFT", 12, 14)
    bExport:SetText(MSC.L["Export Data"])
    bExport:SetScript("OnClick", function() MSC.ShowHistory() end)

    local bImp = CreateFrame("Button", nil, nav, "UIPanelButtonTemplate")
    bImp:SetSize(SETTINGS_NAV_W - 24, 26); bImp:SetPoint("BOTTOMLEFT", bExport, "TOPLEFT", 0, 6)
    bImp:SetText(MSC.L["Import Pawn String"])
    bImp:SetScript("OnClick", function() MSC.ShowImportWindow() end)

    -- [[ MASTER SCROLL FRAME ]]
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", nav, "TOPRIGHT", 12, -10)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)

    local sChild = CreateFrame("Frame", nil, scroll)
    sChild:SetSize(SETTINGS_CONTENT_W, 1000) -- Height is set once the cards are measured
    scroll:SetScrollChild(sChild)

    -- [[ CARDS ]]
    local cards = {}
    local curCard
    local function CreateCard(width)
        local c = CreateFrame("Frame", nil, sChild)
        c:SetWidth(width or SETTINGS_COL_W); c:SetHeight(60)
        local edge = c:CreateTexture(nil, "BACKGROUND", nil, -1); edge:SetAllPoints(); edge:SetColorTexture(1, 1, 1, 0.08)
        local fill = c:CreateTexture(nil, "BACKGROUND"); fill:SetPoint("TOPLEFT", 1, -1); fill:SetPoint("BOTTOMRIGHT", -1, 1); fill:SetColorTexture(unpack(MSC.Theme.Panel))
        table_insert(cards, c); curCard = c
        return c
    end

    -- [[ UI HELPERS (parented to the current card) ]]
    -- Each card's title gets its own colour (in card order); the section list uses it too.
    local SECTION_COLORS = { "Gold", "Purple", "Blue", "Green", "Red", "Teal" }
    local function CreateHeader(text, tooltip)
        local h = curCard:CreateFontString(nil, "OVERLAY", "GameFontNormal"); h:SetText(text)
        h:SetPoint("TOPLEFT", SETTINGS_PAD, -SETTINGS_PAD)
        curCard.Color = SECTION_COLORS[(#cards - 1) % #SECTION_COLORS + 1]
        MSC.StyleHeading(h, curCard.Color, curCard:GetWidth() - SETTINGS_PAD * 2)
        if tooltip then
            local hitRect = CreateFrame("Frame", nil, curCard)
            hitRect:SetPoint("TOPLEFT", h, "TOPLEFT", -10, 10); hitRect:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 50, -10)
            hitRect:EnableMouse(true)
            hitRect:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(text, 1, 1, 1); GameTooltip:AddLine(tooltip, nil, nil, nil, true); GameTooltip:Show() end)
            hitRect:SetScript("OnLeave", GameTooltip_Hide)
        end
        curCard.Title = text; curCard.Last = h
        return h
    end

    -- onChange (optional) runs after the setting is stored, e.g. to sync a paired checkbox.
    local function CreateDropdown(label, key, options, relTo, yOff, tooltip, onChange)
        local frame = CreateFrame("Frame", nil, curCard); frame:SetSize(200, 50); frame:SetPoint("TOPLEFT", relTo, "BOTTOMLEFT", 0, yOff); frame:EnableMouse(true)
        if tooltip then
            frame:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(label, 1, 1, 1); GameTooltip:AddLine(tooltip, nil, nil, nil, true); GameTooltip:Show() end)
            frame:SetScript("OnLeave", GameTooltip_Hide)
        end
        local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); lbl:SetPoint("TOPLEFT", 0, 0); lbl:SetText(label); lbl:SetTextColor(0.6, 0.6, 0.6)
        local dd = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate"); dd:SetPoint("TOPLEFT", -15, -15); UIDropDownMenu_SetWidth(dd, 180)
        -- The profile choice ("Mode") is kept per spec (MSC.GetManualSpec); the rest are account settings.
        local function Get() if key == "Mode" then return MSC.GetManualSpec(MSC.GetActiveSpecGroup()) end return RXP_SGJ_Settings[key] end
        -- Shows the text of the option matching the saved setting (it can change outside this dropdown).
        local function RefreshText()
            local currentText = MSC.L["Select..."]
            local cur = Get()
            for _, opt in ipairs(options) do if cur == opt.val then currentText = opt.text end end
            UIDropDownMenu_SetText(dd, currentText)
        end
        local function OnClick(self)
            UIDropDownMenu_SetSelectedID(dd, self:GetID())
            if key == "Mode" then MSC.SetManualSpec(self.value) else RXP_SGJ_Settings[key] = self.value end
            if key == "RaidBuffPreset" and MSC.BuffEngine then MSC.BuffEngine:ApplyRaidPreset(self.value) end
            if key == "WorldBuffPreset" and MSC.BuffEngine then MSC.BuffEngine:ApplyWorldPreset(self.value) end
            RefreshText()
            if onChange then onChange(self.value) end
            MSC.OnScoringSettingsChanged()
        end
        local function Init(self, level) for _, opt in ipairs(options) do local info = UIDropDownMenu_CreateInfo(); info.text = opt.text; info.value = opt.val; info.func = OnClick; info.checked = (Get() == opt.val); UIDropDownMenu_AddButton(info, level) end end
        UIDropDownMenu_Initialize(dd, Init)
        RefreshText(); if key == "Mode" then f.ProfileDD = dd; MSC.ProfileDropdown = frame end
        frame:SetScript("OnShow", RefreshText)
        frame.RefreshText = RefreshText
        curCard.Last = frame
        return frame
    end

    -- getter (optional): where the box reads its state (e.g. a per-spec setting);
    -- then a click doesn't write RXP_SGJ_Settings[key] and the caller's hook saves it.
    local function CreateCheck(label, key, tooltip, relTo, xOff, yOff, getter)
        local cb = CreateFrame("CheckButton", nil, curCard, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", relTo, "BOTTOMLEFT", xOff, yOff)

        if not cb.Text then
            cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            cb.Text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        end
        cb.Text:SetText(label)
        cb.Text:SetTextColor(0.9, 0.9, 0.9)
        cb.Text:SetWidth(SETTINGS_COL_W - 70); cb.Text:SetJustifyH("LEFT")

        -- Force visual update when the menu opens to bypass hidden-frame template bugs
        local function Read() if getter then return getter() == true end return RXP_SGJ_Settings[key] == true end
        cb:HookScript("OnShow", function(self)
            self:SetChecked(Read())
        end)
        cb:SetChecked(Read())

        cb:HookScript("OnClick", function(self)
            if not getter then RXP_SGJ_Settings[key] = self:GetChecked() end
            if key == "HideMinimap" then MSC.UpdateMinimapPosition() end
            if (key == "ShowBagArrows" or key == "FastBagArrows") and MSC.QueueBagOverlayRefresh then MSC.QueueBagOverlayRefresh() end
            if key == "FastBagArrows" and MSC.RequestBaganatorRefresh then MSC.RequestBaganatorRefresh() end
        end)

        if tooltip then
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", GameTooltip_Hide)
        end
        curCard.Last = cb
        return cb
    end

    -- ==========================================
    -- SECTION 1: INTERFACE OPTIONS (left column)
    -- ==========================================
    local cInterface = CreateCard()
    local hInterface = CreateHeader(MSC.L["Interface Options"])
    local cb1 = CreateCheck(MSC.L["Hide Minimap Button"], "HideMinimap", MSC.L["Hides the circular button on your minimap."], hInterface, 0, -10)
    local cb2 = CreateCheck(MSC.L["Hide Tooltip Verdict"], "HideTooltips", MSC.L["Stops the addon from adding scores to item tooltips."], cb1, 0, -5)
    local cbShift = CreateCheck(MSC.L["Show Only via Shift Key"], "ShiftOnlyTooltip", MSC.L["Only shows the Judge score in tooltips while holding the SHIFT key."], cb2, 20, -5)
    -- Shift-only does nothing while tooltip verdicts are hidden: grey it out then
    -- (on build, whenever the panel opens, and when Hide Tooltip Verdict is clicked).
    local function SyncShiftCheck()
        if RXP_SGJ_Settings.HideTooltips then cbShift:SetAlpha(0.5); cbShift:Disable() else cbShift:SetAlpha(1); cbShift:Enable() end
    end
    cb2:HookScript("OnClick", SyncShiftCheck)
    cbShift:HookScript("OnShow", SyncShiftCheck)
    SyncShiftCheck()
    local cb3 = CreateCheck(MSC.L["Mute Error Sounds"], "MuteSounds", MSC.L["Stops the error sound when clicking invalid items."], cbShift, -20, -5)
    local cb4 = CreateCheck(MSC.L["Disable Conflict Check"], "DisableConflictCheck", MSC.L["Stops the chat warning about Pawn/Zygor."], cb3, 0, -5)
    local cbBagArrows = CreateCheck(MSC.L["Show Bag Upgrade Arrows"], "ShowBagArrows", MSC.L["Shows green upgrade arrows on items in your bags."], cb4, 0, -5)
    cbBagArrows:HookScript("OnClick", function() MSC.BagCacheDirty = true; if RequestUpdate then RequestUpdate() end end)
    local cbFastBag = CreateCheck(MSC.L["Fast Bag Arrows"], "FastBagArrows", MSC.L["Single-slot scoring for bag arrows (full eval for sets/weapons)."], cbBagArrows, 20, -5)
    local cbLootArrows = CreateCheck(MSC.L["Show Loot Roll Arrows"], "ShowLootArrows", MSC.L["Shows green upgrade arrows on group loot popups."], cbFastBag, -20, -5)
    local cbLootToast = CreateCheck(MSC.L["Show Loot Upgrade Alerts"], "ShowLootToast", MSC.L["Shows a small alert when an item you loot or receive is an upgrade. Click it to equip the item."], cbLootArrows, 0, -5)
    -- SGJ_API.lua: answer loot council / loot distribution addons' score requests (addon prefix "SGJ")
    CreateCheck(MSC.L["Share Scores With Group Addons"], "ShareScores", MSC.L["Lets loot council and loot distribution addons in your group ask Sharpie's Gear Judge how much an item would upgrade you. Only your upgrade % and scores are sent."], cbLootToast, 0, -5)

    -- ==========================================
    -- SECTION 2: TOOLTIP VISUALS (left column)
    -- ==========================================
    local cVisuals = CreateCard()
    local hVisuals = CreateHeader(MSC.L["Tooltip Visuals"])
    local cbCompact = CreateCheck(MSC.L["Compact Equip Text"], "CompactEquip", MSC.L["Makes the text smaller and cleaner."], hVisuals, 0, -10)
    local cbSimple = CreateCheck(MSC.L["Shorten Stat Names"], "SimplifyStats", MSC.L["Changes 'Spell Power' to 'SP', etc."], cbCompact, 0, -5)
    CreateCheck(MSC.L["Colorize Stats"], "ColorizeStats", MSC.L["Applies class/role colors to text."], cbSimple, 0, -5)

    -- ==========================================
    -- SECTION 3: COMPARISON LOGIC (right column)
    -- ==========================================
    local cLogic = CreateCard()
    local hLogic = CreateHeader(MSC.L["Comparison Logic"])
    local enchantTip = MSC.L["Controls how item enchantments affect the score.\n\n|cffffffffOff:|r Scores items based on base stats only.\n|cffffffffCurrent:|r Includes the value of the enchant currently on the item.\n|cffffffffProject:|r Simulates the best possible enchant for that item level."]
    local ddEnchant = CreateDropdown(MSC.L["Enchant Mode"], "EnchantMode", {{ text = MSC.L["Off (Raw Stats)"], val = 1 }, { text = MSC.L["Current Only"], val = 2 }, { text = MSC.L["Project Best"], val = 3 }}, hLogic, -10, enchantTip)
    if not MSC.IsVanillaRules then
        local gemTip = MSC.L["Controls how empty sockets are scored.\n\n|cffffffffThe Skeptic:|r Empty sockets are worth 0. Socket bonuses are ignored unless fully met.\n|cffffffffThe Casual:|r Simple gemming logic, usually respects socket colors.\n|cffffffffThe Pro:|r Min-max gemming logic, prioritizes absolute highest score."]
        local ddGem = CreateDropdown(MSC.L["Gemming Logic"], "GemMode", {{ text = MSC.L["The Skeptic"], val = 1 }, { text = MSC.L["The Casual"], val = 2 }, { text = MSC.L["The Pro"], val = 3 }}, ddEnchant, -5, gemTip)
        local gemQualTip = MSC.L["Selects the quality tier of gems the Judge will use when projecting empty sockets."]
        CreateDropdown(MSC.L["Gem Quality"], "GemQuality", {{ text = MSC.L["Common (White/Vendor)"], val = 1 }, { text = MSC.L["Uncommon (Green)"], val = 2 }, { text = MSC.L["Rare (Blue)"], val = 3 }, { text = MSC.L["Epic (Purple)"], val = 4 }}, ddGem, -5, gemQualTip)
    end
    local cbTank2H = CreateCheck(MSC.L["Shield Tanks: No Two-Handers"], "ShieldTankNo2H", MSC.L["With a Protection Warrior or Paladin profile, or a Shaman tank profile, two-handers are never shown as upgrades, even while you hold one, and the Roadmap builds a one-hander and shield set. Turn off to compare two-handers normally while you aren't using a shield."], cLogic.Last, 0, -5)
    cbTank2H:HookScript("OnClick", MSC.OnScoringSettingsChanged)

    -- ==========================================
    -- SECTION 4: BUFF ASSUMPTIONS (right column)
    -- ==========================================
    local cBuffs = CreateCard()
    local hBuffs = CreateHeader(MSC.L["Buff Assumptions"])
    local function InvalidateBuffCaches()
        if MSC.BuffEngine then MSC.BuffEngine:InvalidateCaches() end
        MSC.OnScoringSettingsChanged()
    end
    -- Each Assume checkbox and its preset dropdown mirror one another: picking
    -- a preset ticks/unticks the box, and clicking the box updates the preset.
    local ddRaidPreset, ddWorldPreset
    -- Gear is always judged without the buffs you happen to have; these add
    -- the ones you'd have in a group or raid (presets per game version).
    local raidTip, worldTip
    if MSC.IsTBC then
        raidTip = MSC.L["Assume raid buffs and debuffs when scoring gear (ToW, IFF, Kings, Draenei in raid, etc.)."]
        worldTip = MSC.L["Assume classic world buffs (Ony, ZG, Songflower, DM Tribute). Usually off at 70 in Outland raids."]
    else
        raidTip = MSC.L["Assume group buffs when scoring gear (Kings, Mark of the Wild, Fortitude, Battle Shout, totems, etc.). Blessings are assumed for the Alliance and totems for the Horde. Without this, gear is judged without buffs, whatever you have on right now."]
        worldTip = MSC.L["Assume world buffs (Rallying Cry of the Dragonslayer, Spirit of Zandalar, Songflower Serenade, Dire Maul Tribute)."]
    end
    local defaultRaidPreset = MSC.IsTBC and "full25" or "raid"
    local cbRaid = CreateCheck(MSC.L["Assume Raid Buffed"], "AssumeRaidBuffs", raidTip, hBuffs, 0, -10)
    cbRaid:HookScript("OnClick", function(self)
        if self:GetChecked() and RXP_SGJ_Settings.RaidBuffPreset == "off" then
            if MSC.BuffEngine then MSC.BuffEngine:ApplyRaidPreset(defaultRaidPreset) end
        elseif not self:GetChecked() and MSC.BuffEngine then
            MSC.BuffEngine:ApplyRaidPreset("off")
        end
        self:SetChecked(RXP_SGJ_Settings.AssumeRaidBuffs == true)
        if ddRaidPreset then ddRaidPreset.RefreshText() end
        InvalidateBuffCaches()
    end)
    local raidPresetOpts = {}
    for _, o in ipairs(MSC.BuffEngine and MSC.BuffEngine:GetRaidPresetOptions() or { { "off", "Off" } }) do
        table.insert(raidPresetOpts, { text = MSC.L[o[2]], val = o[1] })
    end
    ddRaidPreset = CreateDropdown(MSC.L["Raid Buff Preset"], "RaidBuffPreset", raidPresetOpts, cbRaid, -5, nil, function()
        cbRaid:SetChecked(RXP_SGJ_Settings.AssumeRaidBuffs == true)
    end)
    local cbWorld = CreateCheck(MSC.L["Assume World Buffed"], "AssumeWorldBuffs", worldTip, ddRaidPreset, 0, -5)
    cbWorld:HookScript("OnClick", function(self)
        if self:GetChecked() and RXP_SGJ_Settings.WorldBuffPreset == "off" then
            if MSC.BuffEngine then MSC.BuffEngine:ApplyWorldPreset("full") end
        elseif not self:GetChecked() and MSC.BuffEngine then
            MSC.BuffEngine:ApplyWorldPreset("off")
        end
        self:SetChecked(RXP_SGJ_Settings.AssumeWorldBuffs == true)
        if ddWorldPreset then ddWorldPreset.RefreshText() end
        InvalidateBuffCaches()
    end)
    local worldPresetOpts = {
        { text = MSC.L["Off"], val = "off" },
        { text = MSC.L["Full World Buffed"], val = "full" },
        { text = MSC.L["DM Tribute Only"], val = "dmTribute" },
    }
    ddWorldPreset = CreateDropdown(MSC.L["World Buff Preset"], "WorldBuffPreset", worldPresetOpts, cbWorld, -5, nil, function()
        cbWorld:SetChecked(RXP_SGJ_Settings.AssumeWorldBuffs == true)
    end)

    local cbCamping = CreateCheck(MSC.L["Assume Consumables"], "AssumeCampingBuffs", MSC.L["Assumes temporary weapon buffs like Sharpening Stones or Weightstones."], ddWorldPreset, 0, -5)
    cbCamping:HookScript("OnClick", InvalidateBuffCaches)

    -- Forever: from 50, hit and defense targets slide toward raid caps
    -- (MSC.ForeverCaps); turn off to keep leveling targets until 60.
    local otherSpecAnchor = cbCamping
    if MSC.IsForever then
        local cbRaidPrep = CreateCheck(MSC.L["Gear for Raiding"], "GearForRaiding", MSC.L["From level 50, values hit and tank defense toward raid caps (9% hit, 17% spell hit, 440 defense, uncrushable) instead of what leveling needs. Turn off if you won't raid."], cbCamping, 0, -5)
        cbRaidPrep:HookScript("OnClick", function()
            MSC.CachedWeights = nil
            if MSC.CachedWeightsBySpec then wipe(MSC.CachedWeightsBySpec) end
            if MSC.BumpScoringRevision then MSC:BumpScoringRevision() end
            InvalidateBuffCaches()
        end)
        -- PvP model over every profile (MSC.ApplyForeverPvP); also on the
        -- main window and offered on PvP realms.
        local cbPvP = CreateCheck(MSC.L["Gear for PvP"], "GearForPvP", MSC.L["Scores gear for fighting other players at every level: Stamina, armor and burst count for more, hit stays at the player-vs-player caps (5% melee, 3% spell). PvP profiles always use this."], cbRaidPrep, 0, -5,
            function() return MSC.IsGearingForPvP(MSC.GetActiveSpecGroup()) end)
        cbPvP:HookScript("OnClick", function(self)
            MSC.SetGearForPvP(self:GetChecked())
            InvalidateBuffCaches()
        end)
        cbPvP:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(MSC.L["Scores gear for fighting other players at every level: Stamina, armor and burst count for more, hit stays at the player-vs-player caps (5% melee, 3% spell). PvP profiles always use this."], nil, nil, nil, nil, true)
            if MSC.HasDualSpec() then
                GameTooltip:AddLine(string.format(MSC.L["Saved for each spec; this sets it for your %s spec."], MSC.SpecGroupName(MSC.GetActiveSpecGroup())), 0.6, 0.8, 1, true)
            end
            GameTooltip:Show()
        end)
        -- Gear for PvP keeps hit and defense at the player-vs-player targets, so
        -- Gear for Raiding does nothing while it's on: grey it out (its saved
        -- choice is kept for when PvP is turned off).
        local raidTip = MSC.L["From level 50, values hit and tank defense toward raid caps (9% hit, 17% spell hit, 440 defense, uncrushable) instead of what leveling needs. Turn off if you won't raid."]
        local function PaintRaidPrep(pvpOn)
            if pvpOn then
                cbRaidPrep:Disable(); cbRaidPrep.Text:SetTextColor(0.5, 0.5, 0.5)
            else
                cbRaidPrep:Enable(); cbRaidPrep.Text:SetTextColor(0.9, 0.9, 0.9)
            end
        end
        cbRaidPrep:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(raidTip, nil, nil, nil, nil, true)
            if MSC.IsGearingForPvP() then
                GameTooltip:AddLine(MSC.L["Not used while Gear for PvP is on: hit and defense stay at the player-vs-player targets."], 1, 0.4, 0.4, true)
            end
            GameTooltip:Show()
        end)
        cbRaidPrep:HookScript("OnShow", function() PaintRaidPrep(MSC.IsGearingForPvP()) end)
        PaintRaidPrep(MSC.IsGearingForPvP())
        table_insert(MSC.PvPToggleListeners, function(on) cbPvP:SetChecked(on); PaintRaidPrep(on) end)
        otherSpecAnchor = cbPvP
    end
    -- Dual Specialization (Forever, SoD, TBC Anniversary): a line on item
    -- tooltips for the spec you're not in.
    local otherSpecTip = MSC.L["With Dual Specialization, item tooltips also show if an item is an upgrade for your other spec, scored with that spec's talents and profile against the best gear you own for it (worn, bags and bank). The scoring profile is saved separately for each spec."]
    if MSC.IsForever then otherSpecTip = otherSpecTip .. " " .. MSC.L["Gear for PvP is saved separately for each spec too."] end
    CreateCheck(MSC.L["Show Other Spec on Tooltips"], "ShowOtherSpec", otherSpecTip, otherSpecAnchor, 0, -5)

    -- ==========================================
    -- SECTION 5: CHARACTER PROFILE (right column)
    -- ==========================================
    local cProfile = CreateCard()
    local hProfile = CreateHeader(MSC.L["Character Profile"])
    local specOptions = { { text = MSC.L["Auto-Detect"], val = "AUTO" } }; local seen = { ["AUTO"] = true }; local profileList = {}
    if MSC.CurrentClass then
        local function AddList(listSource)
            if not listSource then return end
            local sorted = {}; for k in pairs(listSource) do table_insert(sorted, k) end; table_sort(sorted)
            local retired = MSC.CurrentClass.RetiredProfiles or {}   -- old names kept only as aliases
            for _, k in ipairs(sorted) do
                if not seen[k] and not retired[k] then
                    local name = (MSC.CurrentClass.PrettyNames and MSC.CurrentClass.PrettyNames[k]) or k;
                    table_insert(specOptions, { text = name, val = k })
                    table_insert(profileList, { text = name, val = k })
                    seen[k] = true
                end
            end
        end
        if RXP_SGJ_DB and RXP_SGJ_DB.customWeights then AddList(RXP_SGJ_DB.customWeights) end
        AddList(MSC.CurrentClass.Weights); AddList(MSC.CurrentClass.LevelingWeights); AddList(MSC.CurrentClass.Profiles)
    end
    local profileTip = MSC.L["Manually override the scoring profile.\n\n|cffffffffAuto-Detect:|r Automatically selects a profile based on your talents (capstone + point-scan). Hybrid builds with points spread across trees may need manual selection.\n\nSelecting a specific profile forces the addon to judge all gear for that spec, regardless of your current talents."]
    local ddProfile = CreateDropdown(MSC.L["Active Scoring Profile"], "Mode", specOptions, hProfile, -10, profileTip)

    local bDeleteProfile = CreateFrame("Button", nil, cProfile, "UIPanelButtonTemplate")
    bDeleteProfile:SetSize(170, 22); bDeleteProfile:SetPoint("TOPLEFT", ddProfile, "BOTTOMLEFT", 0, -2); bDeleteProfile:SetText(MSC.L["Delete Custom Profile"])
    bDeleteProfile:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(MSC.L["Delete Custom Profile"], 1, 1, 1); GameTooltip:AddLine(MSC.L["Deletes the selected profile if it is one you imported. Built-in profiles can't be deleted."], nil, nil, nil, true); GameTooltip:Show() end)
    bDeleteProfile:SetScript("OnLeave", GameTooltip_Hide)
    bDeleteProfile:SetScript("OnClick", function()
        local selected = MSC.GetManualSpec(MSC.GetActiveSpecGroup())
        if selected and RXP_SGJ_DB and RXP_SGJ_DB.customWeights and RXP_SGJ_DB.customWeights[selected] then
            RXP_SGJ_DB.customWeights[selected] = nil
            MSC.SetManualSpec("AUTO"); MSC.CachedWeights = nil
            ddProfile.RefreshText() -- back to "Auto-Detect"
            MSC.OnScoringSettingsChanged()
            print(string.format(MSC.L["|cff00ff00SGJ:|r Deleted custom profile: %s"], selected))
            StaticPopup_Show("SGJ_PROFILE_DELETED")
        else print(MSC.L["|cffff0000SGJ:|r You can only delete custom imported profiles."]) end
    end)
    cProfile.Last = bDeleteProfile

    -- ==========================================
    -- SECTION 6: OFF-SPECS (full width, below both columns)
    -- ==========================================
    -- Ticks are saved for this character (MSC.SetTrackedSpec). Items are judged
    -- for them against the best gear you own (worn, bags, bank).
    local cSpecs = CreateCard(SETTINGS_CONTENT_W)
    local specTip = MSC.L["Tick the profiles this character also plays, such as a healing or tank set for dungeons. Item tooltips then show when an item is an upgrade for them, compared against the best gear you own for that profile: what you wear, your bags, and your bank as seen on your last visit. Leveling profiles follow your level. Saved for each character; the Roster plugin shows them for your alts too (log in on the alt once after ticking)."]
    local hSpec = CreateHeader(MSC.L["Off-Specs"], specTip)
    local specNote = cSpecs:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    specNote:SetPoint("TOPLEFT", hSpec, "BOTTOMLEFT", 0, -6)
    specNote:SetWidth(SETTINGS_CONTENT_W - 2 * SETTINGS_PAD); specNote:SetJustifyH("LEFT")
    specNote:SetText("|cff888888" .. MSC.L["Off-spec upgrades are judged against the best gear you own for them (worn, bags and bank)."] .. "|r")

    -- Two columns of checkboxes.
    local SPEC_COL_W = math.floor((SETTINGS_CONTENT_W - 2 * SETTINGS_PAD) / 2)
    local perCol = math.ceil(#profileList / 2)
    local prev = {}
    cSpecs.Last = specNote
    for i, p in ipairs(profileList) do
        local col = (i <= perCol) and 1 or 2
        local cb = CreateFrame("CheckButton", nil, cSpecs, "UICheckButtonTemplate")
        if not prev[col] then
            cb:SetPoint("TOPLEFT", specNote, "BOTTOMLEFT", (col - 1) * SPEC_COL_W, -6)
        else
            cb:SetPoint("TOPLEFT", prev[col], "BOTTOMLEFT", 0, 2)
        end
        prev[col] = cb
        cb.Text:SetText(p.text); cb.Text:SetTextColor(0.8, 0.8, 0.8)
        cb.Text:SetWidth(SPEC_COL_W - 34); cb.Text:SetJustifyH("LEFT"); cb.Text:SetWordWrap(false)
        local function Sync(self) self:SetChecked(MSC.GetTrackedSpecs()[p.val] and true or false) end
        cb:HookScript("OnShow", Sync); Sync(cb)
        cb:HookScript("OnClick", function(self) MSC.SetTrackedSpec(p.val, self:GetChecked()) end)
        if col == 1 then cSpecs.Last = cb end
    end

    -- ==========================================
    -- CARD PLACEMENT: two columns, then the spec list across the bottom
    -- ==========================================
    local leftCol = { cInterface, cVisuals }
    local rightCol = { cLogic, cBuffs, cProfile }
    local function Stack(col, x)
        local y = 0
        for i, c in ipairs(col) do
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", sChild, "TOPLEFT", x, -y)
            y = y + c:GetHeight() + SETTINGS_GAP
        end
        return y
    end
    local function Place()
        local yL = Stack(leftCol, 0)
        local yR = Stack(rightCol, SETTINGS_COL_W + SETTINGS_GAP)
        local top = math.max(yL, yR)
        cSpecs:ClearAllPoints(); cSpecs:SetPoint("TOPLEFT", sChild, "TOPLEFT", 0, -top)
        sChild:SetHeight(top + cSpecs:GetHeight() + 10)
    end
    Place()

    -- Card heights come from their contents, which only have positions once shown: measure on the first frame, then re-stack.
    sChild:SetScript("OnUpdate", function(self)
        for _, c in ipairs(cards) do
            local t, b = c:GetTop(), c.Last and c.Last:GetBottom()
            if not (t and b) then return end
        end
        for _, c in ipairs(cards) do c:SetHeight(c:GetTop() - c.Last:GetBottom() + SETTINGS_PAD) end
        Place()
        self:SetScript("OnUpdate", nil)
    end)

    -- ==========================================
    -- SECTION LIST BUTTONS
    -- ==========================================
    local navOrder = { cInterface, cVisuals, cLogic, cBuffs, cProfile, cSpecs }
    local navButtons = {}
    local function CardOffset(c) local ct, st = c:GetTop(), sChild:GetTop(); return (ct and st) and (st - ct) or 0 end
    local function HighlightNav(active)
        for _, b in ipairs(navButtons) do
            local on = (b.Card == active)
            local c = MSC.Theme.Section[b.Card.Color or "Gold"] or MSC.Theme.Section.Gold
            local k = on and 1 or 0.7
            b.Sel:SetShown(on); b.Bar:SetShown(on); b.Text:SetTextColor(c[1] * k, c[2] * k, c[3] * k)
        end
    end
    local prev = navSub
    for i, c in ipairs(navOrder) do
        local b = CreateFrame("Button", nil, nav)
        b:SetSize(SETTINGS_NAV_W - 20, 24); b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", (i == 1) and -4 or 0, (i == 1) and -12 or -2)
        b.Sel = b:CreateTexture(nil, "BACKGROUND"); b.Sel:SetAllPoints(); b.Sel:SetColorTexture(1, 1, 1, 0.06); b.Sel:Hide()
        b.Bar = b:CreateTexture(nil, "ARTWORK"); b.Bar:SetColorTexture(unpack(MSC.Theme.Accent)); b.Bar:SetWidth(2)
        b.Bar:SetPoint("TOPLEFT"); b.Bar:SetPoint("BOTTOMLEFT"); b.Bar:Hide()
        b.Hover = b:CreateTexture(nil, "HIGHLIGHT"); b.Hover:SetAllPoints(); b.Hover:SetColorTexture(1, 1, 1, 0.05)
        b.Text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.Text:SetPoint("LEFT", 8, 0); b.Text:SetPoint("RIGHT", -4, 0); b.Text:SetJustifyH("LEFT"); b.Text:SetWordWrap(false)
        b.Text:SetText(c.Title)
        b.Card = c
        b:SetScript("OnClick", function(self)
            scroll:SetVerticalScroll(math.min(CardOffset(self.Card), scroll:GetVerticalScrollRange()))
            HighlightNav(self.Card)
        end)
        navButtons[i] = b; prev = b
    end
    -- Follow the scroll position: highlight the last section whose top has scrolled past
    scroll:HookScript("OnVerticalScroll", function(self, offset)
        local best, bestOff = navOrder[1], -1
        for _, c in ipairs(navOrder) do
            local o = CardOffset(c)
            if o <= offset + 5 and o > bestOff then best, bestOff = c, o end
        end
        if offset >= self:GetVerticalScrollRange() - 1 and offset > 0 then best = cSpecs end
        HighlightNav(best)
    end)
    HighlightNav(cInterface)

    MSC.ViewSettings = f
    if wasShown then f:Show() end
end

function MSC.RegisterPluginTab(name, icon, initFunc, viewKey, updateFuncKey)
    local newID = #MSC.RegisteredTabs + 1
    table_insert(MSC.RegisteredTabs, {
        id = newID, name = name, icon = icon,
        directFunc = initFunc, view = viewKey, update = updateFuncKey
    })
    if MSC.MainFrame and MSC.MainFrame:IsShown() then MSC.RenderSidebarButtons() end
    return newID
end

-- Main window: title row, a flat text tab row with an accent underline on the
-- open tab, the 830x640 content area (every view is laid out for that size) and
-- a footer with the profile and total score.
local MAIN_PAD, MAIN_TITLE_H, MAIN_TABS_H, MAIN_FOOTER_H = 12, 46, 26, 28
local MAIN_CONTENT_W, MAIN_CONTENT_H = 830, 640

-- Tab buttons are reused when a plugin registers its tab after the window exists.
function MSC.RenderSidebarButtons()
    local f = MSC.MainFrame
    if not f then return end
    MSC.NavButtons = MSC.NavButtons or {}
    local T = MSC.Theme

    -- Smaller text and padding when every tab name won't fit on one row
    local function Measure(font, pad)
        local total = 0
        for idx, tab in ipairs(MSC.RegisteredTabs) do
            local btn = MSC.NavButtons[idx]
            if not btn then
                btn = CreateFrame("Button", nil, f.TabBar)
                btn.Text = btn:CreateFontString(nil, "OVERLAY")
                btn.Text:SetPoint("CENTER", 0, 1)
                btn.Line = btn:CreateTexture(nil, "OVERLAY"); btn.Line:SetColorTexture(unpack(T.Accent)); btn.Line:SetHeight(2)
                btn.Line:SetPoint("BOTTOMLEFT", 6, 0); btn.Line:SetPoint("BOTTOMRIGHT", -6, 0); btn.Line:Hide()
                btn:SetScript("OnEnter", function(self) if self.ID ~= MSC.ActiveTab then self.Text:SetTextColor(1, 1, 1) end end)
                btn:SetScript("OnLeave", function(self) if self.ID ~= MSC.ActiveTab then self.Text:SetTextColor(0.65, 0.65, 0.68) end end)
                btn:SetScript("OnClick", function(self) MSC.SwitchTab(self.ID) end)
                MSC.NavButtons[idx] = btn
            end
            btn.ID = idx
            btn.Text:SetFontObject(font); btn.Text:SetText(tab.name or "")
            btn:SetSize(btn.Text:GetStringWidth() + pad, MAIN_TABS_H)
            total = total + btn:GetWidth()
        end
        return total
    end
    if Measure("GameFontHighlight", 24) > MAIN_CONTENT_W then Measure("GameFontHighlightSmall", 14) end

    local prev
    for idx = 1, #MSC.NavButtons do
        local btn = MSC.NavButtons[idx]
        if MSC.RegisteredTabs[idx] then
            btn:ClearAllPoints()
            if prev then btn:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 0, 0) else btn:SetPoint("BOTTOMLEFT", f.TabBar, "BOTTOMLEFT", 0, 0) end
            btn:Show(); prev = btn
        else
            btn:Hide()
        end
    end
    if MSC.ActiveTab then MSC.SwitchTab(MSC.ActiveTab) end
end

-- Footer: the profile in use and the total score of what you're wearing.
function MSC.UpdateMainFooter()
    local f = MSC.MainFrame
    if not (f and f.FooterProfile and f:IsShown() and MSC.GetCurrentWeights) then return end
    local ok, weights, key = pcall(MSC.GetCurrentWeights)
    if not (ok and weights) then f.FooterProfile:SetText(""); f.FooterScore:SetText(""); return end
    local name = (MSC.CurrentClass and MSC.CurrentClass.PrettyNames and MSC.CurrentClass.PrettyNames[key]) or key or ""
    f.FooterProfile:SetText(name)
    local gear = {}
    for i = 1, 18 do gear[i] = GetInventoryItemLink("player", i) end
    local okScore, score = pcall(MSC.GetTotalCharacterScore, MSC, gear, weights, key)
    f.FooterScore:SetText((okScore and type(score) == "number") and string.format("%.1f", score) or "")
end

function MSC.ToggleMainMenu()
    if MSC.MainFrame then
        if MSC.MainFrame:IsShown() then MSC.MainFrame:Hide() else MSC.MainFrame:Show() end
        return
    end
    local T = MSC.Theme

    local f = CreateFrame("Frame", "SGJ_MainFrame", UIParent, "BackdropTemplate")
    f:SetSize(MAIN_CONTENT_W + MAIN_PAD * 2, MAIN_TITLE_H + MAIN_TABS_H + MAIN_CONTENT_H + MAIN_FOOTER_H + 4)
    f:SetPoint("CENTER"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")

    f:SetScript("OnHide", function()
        if MSC.BreakdownFrame then MSC.BreakdownFrame:Hide() end
    end)
    f:SetScript("OnShow", function() MSC.UpdateMainFooter() end)

    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing); f:SetFrameStrata("HIGH")
    MSC.CreateModernBorder(f, 1)
    f.border:SetBackdropBorderColor(unpack(T.Edge))

    -- Class art faintly behind a dark see-through fill, an accent stripe along the top
    f.Bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    local _, class = UnitClass("player")
    local fixedClass = class:sub(1,1):upper() .. class:sub(2):lower()
    f.Bg:SetTexture("Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\" .. fixedClass .. ".tga")
    f.Bg:SetPoint("CENTER", f, "CENTER", 0, 0); f.Bg:SetSize(640, 640); f.Bg:SetAlpha(0.7)
    f.Overlay = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    f.Overlay:SetAllPoints(); f.Overlay:SetColorTexture(unpack(T.Window))
    f.Stripe = f:CreateTexture(nil, "ARTWORK")
    f.Stripe:SetColorTexture(unpack(T.Accent)); f.Stripe:SetHeight(2)
    f.Stripe:SetPoint("TOPLEFT"); f.Stripe:SetPoint("TOPRIGHT")

    -- Title row: name in the accent colour, version and open tab under it, PvP toggle and close on the right
    f.Header = CreateFrame("Frame", nil, f); f.Header:SetPoint("TOPLEFT", 0, 0); f.Header:SetPoint("TOPRIGHT", 0, 0)
    f.Header:SetHeight(MAIN_TITLE_H + MAIN_TABS_H); f.Header:EnableMouse(true); f.Header:RegisterForDrag("LeftButton")
    f.Header:SetScript("OnDragStart", function() f:StartMoving() end); f.Header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f.Header:SetScript("OnMouseWheel", function(self, delta)
        local cur = f:GetScale(); if delta > 0 then cur = cur + 0.05 else cur = cur - 0.05 end
        if cur < 0.6 then cur = 0.6 end; if cur > 1.4 then cur = 1.4 end; f:SetScale(cur)
    end)

    f.Title = f.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.Title:SetPoint("TOPLEFT", MAIN_PAD + 4, -10)
    f.Title:SetText("Sharpie's Gear Judge"); f.Title:SetTextColor(unpack(T.Accent))
    f.SubTitle = f.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.SubTitle:SetPoint("TOPLEFT", f.Title, "BOTTOMLEFT", 0, -3)
    f.SubTitle:SetTextColor(unpack(T.Muted))

    f.Close = CreateFrame("Button", nil, f.Header); f.Close:SetSize(24, 24); f.Close:SetPoint("TOPRIGHT", -MAIN_PAD + 2, -8)
    f.Close.Text = f.Close:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge"); f.Close.Text:SetPoint("CENTER"); f.Close.Text:SetText("×")
    f.Close.Text:SetTextColor(0.65, 0.65, 0.68)
    f.Close:SetScript("OnEnter", function(self) self.Text:SetTextColor(unpack(T.Accent)) end)
    f.Close:SetScript("OnLeave", function(self) self.Text:SetTextColor(0.65, 0.65, 0.68) end)
    f.Close:SetScript("OnClick", function() f:Hide() end)
    -- Forever: Gear for PvP in the header, so open-world PvP players see it
    -- without opening the options (same setting as the options checkbox).
    if MSC.IsForever then
        local pvp = CreateFrame("CheckButton", nil, f.Header, "UICheckButtonTemplate")
        pvp:SetSize(24, 24)
        local lbl = pvp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("RIGHT", pvp, "LEFT", -2, 0); lbl:SetText(MSC.L["Gear for PvP"])
        pvp:SetPoint("RIGHT", f.Close, "LEFT", -16, 0)
        local function Paint(on)
            pvp:SetChecked(on)
            if on then lbl:SetTextColor(1, 0.3, 0.3) else lbl:SetTextColor(0.7, 0.7, 0.7) end
        end
        Paint(MSC.IsGearingForPvP(MSC.GetActiveSpecGroup()))
        pvp:SetScript("OnClick", function(self) MSC.SetGearForPvP(self:GetChecked()) end)
        pvp:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(MSC.L["Gear for PvP"], 1, 1, 1)
            GameTooltip:AddLine(MSC.L["Scores gear for fighting other players at every level: Stamina, armor and burst count for more, hit stays at the player-vs-player caps (5% melee, 3% spell). PvP profiles always use this."], nil, nil, nil, true)
            if MSC.HasDualSpec() then
                GameTooltip:AddLine(string.format(MSC.L["Saved for each spec; this sets it for your %s spec."], MSC.SpecGroupName(MSC.GetActiveSpecGroup())), 0.6, 0.8, 1, true)
            end
            GameTooltip:Show()
        end)
        pvp:SetScript("OnLeave", GameTooltip_Hide)
        table_insert(MSC.PvPToggleListeners, Paint)
        f.PvPToggle = pvp
    end

    -- Tab row with a hairline under it
    f.TabBar = CreateFrame("Frame", nil, f.Header)
    f.TabBar:SetPoint("BOTTOMLEFT", MAIN_PAD, 0); f.TabBar:SetPoint("BOTTOMRIGHT", -MAIN_PAD, 0); f.TabBar:SetHeight(MAIN_TABS_H)
    f.TabBar.Line = f.TabBar:CreateTexture(nil, "BORDER"); f.TabBar.Line:SetColorTexture(unpack(T.Edge)); f.TabBar.Line:SetHeight(1)
    f.TabBar.Line:SetPoint("BOTTOMLEFT"); f.TabBar.Line:SetPoint("BOTTOMRIGHT")

    f.Content = CreateFrame("Frame", nil, f); f.Content:SetSize(MAIN_CONTENT_W, MAIN_CONTENT_H)
    f.Content:SetPoint("TOPLEFT", f.Header, "BOTTOMLEFT", MAIN_PAD, -2)

    -- Footer: move/scale hint on the left, profile and total score on the right
    f.Footer = CreateFrame("Frame", nil, f)
    f.Footer:SetPoint("BOTTOMLEFT", MAIN_PAD, 0); f.Footer:SetPoint("BOTTOMRIGHT", -MAIN_PAD, 0); f.Footer:SetHeight(MAIN_FOOTER_H)
    f.Footer.Line = f.Footer:CreateTexture(nil, "BORDER"); f.Footer.Line:SetColorTexture(unpack(T.Edge)); f.Footer.Line:SetHeight(1)
    f.Footer.Line:SetPoint("TOPLEFT"); f.Footer.Line:SetPoint("TOPRIGHT")
    f.MoveHint = f.Footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.MoveHint:SetPoint("LEFT", 4, 0)
    f.MoveHint:SetText((MSC.L["Hold\nto Move"]:gsub("\n", " ")) .. "  ·  " .. MSC.L["Scroll to Scale"]); f.MoveHint:SetTextColor(0.4, 0.4, 0.42)
    f.FooterScore = f.Footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.FooterScore:SetPoint("RIGHT", -4, 0)
    f.FooterScore:SetTextColor(unpack(T.Value))
    local scoreLbl = f.Footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); scoreLbl:SetPoint("RIGHT", f.FooterScore, "LEFT", -8, 0)
    scoreLbl:SetText(MSC.L["Total Score"]); scoreLbl:SetTextColor(unpack(T.Text))
    f.FooterProfile = f.Footer:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.FooterProfile:SetPoint("RIGHT", scoreLbl, "LEFT", -24, 0)
    f.FooterProfile:SetTextColor(unpack(T.Value))
    local profLbl = f.Footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); profLbl:SetPoint("RIGHT", f.FooterProfile, "LEFT", -8, 0)
    profLbl:SetText(MSC.L["Profile"]); profLbl:SetTextColor(unpack(T.Text))
    MSC.MainFrame = f

    MSC.InitLabView(f.Content)
    MSC.InitReceiptView(f.Content)
    MSC.InitLogicView(f.Content)
    MSC.InitSettingsView(f.Content)
    MSC.RenderSidebarButtons()
    MSC.SwitchTab(MSC.SavedTabIndex())
    f:Show()
end

-- The window reopens on the tab used last, kept between logins (RXP_SGJ_Settings.LastTab holds the tab's view key,
-- which stays the same whatever order the plugins register their tabs in).
function MSC.SavedTabIndex()
    local key = RXP_SGJ_Settings and RXP_SGJ_Settings.LastTab
    for i, tab in ipairs(MSC.RegisteredTabs) do if key and tab.view == key then return i end end
    return 1
end

function MSC.SwitchTab(id)
    MSC.ActiveTab = id
    if RXP_SGJ_Settings and MSC.RegisteredTabs[id] then RXP_SGJ_Settings.LastTab = MSC.RegisteredTabs[id].view end
    if MSC.BreakdownFrame then MSC.BreakdownFrame:Hide() end
    if MSC.NavButtons then
        for i, btn in ipairs(MSC.NavButtons) do
            if i == id then btn.Text:SetTextColor(unpack(MSC.Theme.Accent)); btn.Line:Show()
            else btn.Text:SetTextColor(0.65, 0.65, 0.68); btn.Line:Hide() end
        end
    end
    for _, tab in ipairs(MSC.RegisteredTabs) do if MSC[tab.view] then MSC[tab.view]:Hide() end end
    local tab = MSC.RegisteredTabs[id]
    -- The header shows the open tab's name next to the version.
    if tab and MSC.MainFrame and MSC.MainFrame.SubTitle then
        MSC.MainFrame.SubTitle:SetText(string.format("v%s  ·  %s", MSC.Version or "", tab.name or ""))
    end
    if tab then
        local init = tab.directFunc or (tab.funcName and MSC[tab.funcName])
        if not MSC[tab.view] and init then init(MSC.MainFrame.Content) end
        if MSC[tab.view] then
            MSC[tab.view]:Show()
            if tab.update and MSC[tab.update] then MSC[tab.update]() end
        end
    end
    MSC.UpdateMainFooter()
end

-- =============================================================
-- MINIMAP BUTTON (LibDataBroker launcher + LibDBIcon)
-- =============================================================
-- Built through LibDBIcon (embedded in Libs\) so minimap managers that
-- collect LibDBIcon buttons -- Leatrix Plus "Combine addon buttons",
-- MinimapButtonButton, SexyMap, etc. -- pick it up, and it follows the
-- minimap shape. The same LDB object also feeds Titan Panel/Bazooka.
local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
local dbIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
local MINIMAP_ICON_NAME = "SharpiesGearJudge"

local ldbObject = false and ldb and ldb:NewDataObject(MINIMAP_ICON_NAME, { -- vendor patch: no LDB launcher (it opens the SGJ window)
    type = "launcher",
    text = "Gear Judge",
    icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
    -- Left-click opens or closes the window (on the last used tab); right-click lists the pages to jump straight to one.
    OnClick = function(self, button)
        if button == "RightButton" then MSC.ShowPageMenu(self) else MSC.ToggleMainMenu() end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("|cffffd100Sharpie's Gear Judge|r")
        tooltip:AddLine(MSC.L["Click to open the interface."], 1, 1, 1)
        tooltip:AddLine(MSC.L["Right-click to choose a page."], 1, 1, 1)
    end,
})

local pageMenu
function MSC.ShowPageMenu(anchor)
    if not pageMenu then
        pageMenu = CreateFrame("Frame", "SGJ_PageMenu", UIParent, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(pageMenu, function(_, level)
            local title = UIDropDownMenu_CreateInfo()
            title.text = "Sharpie's Gear Judge"; title.isTitle = true; title.notCheckable = true
            UIDropDownMenu_AddButton(title, level)
            local open = MSC.MainFrame and MSC.MainFrame:IsShown()
            for i, tab in ipairs(MSC.RegisteredTabs) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = tab.name or ""; info.icon = tab.icon
                info.checked = open and MSC.ActiveTab == i or nil
                info.func = function() MSC.OpenMainWindow(i); CloseDropDownMenus() end
                UIDropDownMenu_AddButton(info, level)
            end
        end, "MENU")
    end
    ToggleDropDownMenu(1, nil, pageMenu, anchor or "cursor", 0, 0)
end

function MSC.UpdateMinimapPosition()
    if not (dbIcon and dbIcon:IsRegistered(MINIMAP_ICON_NAME)) then return end
    local hide = RXP_SGJ_Settings and RXP_SGJ_Settings.HideMinimap
    -- MinimapIcon can be gone mid-session after /sgjwipe (until /reload)
    if RXP_SGJ_Settings and RXP_SGJ_Settings.MinimapIcon then RXP_SGJ_Settings.MinimapIcon.hide = hide and true or false end
    if hide then dbIcon:Hide(MINIMAP_ICON_NAME) else dbIcon:Show(MINIMAP_ICON_NAME) end
end

local function RegisterMinimapIcon()
    do return end -- vendor patch: no minimap button; settings live in RestedXP
    if not (dbIcon and ldbObject) or dbIcon:IsRegistered(MINIMAP_ICON_NAME) then return end
    if not RXP_SGJ_Settings then RXP_SGJ_Settings = {} end
    if type(RXP_SGJ_Settings.MinimapIcon) ~= "table" then
        -- Migrate the old hand-built button's CENTER offset to a LibDBIcon
        -- angle (degrees, same cos/sin convention); anything else starts at
        -- the old default spot (bottom-left, 225).
        local angle = 225
        local p = RXP_SGJ_Settings.MinimapPos
        if type(p) == "table" and p[1] == "CENTER" and p[2] == "CENTER" and tonumber(p[3]) and tonumber(p[4]) and (p[3] ~= 0 or p[4] ~= 0) then
            angle = math.deg(math.atan2(p[4], p[3])) % 360
        end
        RXP_SGJ_Settings.MinimapIcon = { minimapPos = angle }
    end
    RXP_SGJ_Settings.MinimapPos = nil
    RXP_SGJ_Settings.MinimapIcon.hide = RXP_SGJ_Settings.HideMinimap and true or false
    dbIcon:Register(MINIMAP_ICON_NAME, ldbObject, RXP_SGJ_Settings.MinimapIcon)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")

f:SetScript("OnEvent", function(self, event, arg1) 
    if event == "PLAYER_LOGIN" then 
        RXP_SGJ_DB = RXP_SGJ_DB or { customWeights = {} }
        RegisterMinimapIcon()
        if MSC.WeightDB then
            for name, weights in pairs(RXP_SGJ_DB.customWeights) do
                MSC.WeightDB[name] = weights
            end
        end
        MSC.UpdateMinimapPosition() 
    elseif event == "PLAYER_ENTERING_WORLD" then
        RequestUpdate()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        MSC.BagCacheDirty = true
        RequestUpdate()      
    else
        RequestUpdate()
    end
end)

function MSC.OnItemLinkClick(link)
    if not MSC.ViewLab or not MSC.ViewLab:IsShown() then return end
    
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    if equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_STAFF" or equipLoc == "INVTYPE_POLEARM" then
        local btn1 = MSC.LabBlocks[1].Slots[1]; local btn2 = MSC.LabBlocks[4].Slots[1]
        if not btn1.link then btn1.link = link; SetItemButtonTexture(btn1, GetItemIcon(link))
        else btn2.link = link; SetItemButtonTexture(btn2, GetItemIcon(link)) end
    elseif equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_WEAPONOFFHAND" then
        local btn1 = MSC.LabBlocks[2].Slots[2]; local btn2 = MSC.LabBlocks[5].Slots[2]
        if not btn1.link then btn1.link = link; SetItemButtonTexture(btn1, GetItemIcon(link))
        else btn2.link = link; SetItemButtonTexture(btn2, GetItemIcon(link)) end
    elseif equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" then
        local targets = { MSC.LabBlocks[2].Slots[1], MSC.LabBlocks[3].Slots[1], MSC.LabBlocks[3].Slots[2], MSC.LabBlocks[5].Slots[1], MSC.LabBlocks[6].Slots[1], MSC.LabBlocks[6].Slots[2] }
        for i, btn in ipairs(targets) do
            local isOHSlot = (i == 3 or i == 6); local canEquip = true
            if isOHSlot and equipLoc == "INVTYPE_WEAPONMAINHAND" then canEquip = false end
            if canEquip and not btn.link then btn.link = link; SetItemButtonTexture(btn, GetItemIcon(link)); break end
        end
    end
    MSC.UpdateLabCalc()
end

-- hooksecurefunc errors on a missing global, which at file scope would abort
-- the rest of this file, so each Blizzard function is checked first.
-- One shift-click runs both hooks below (Blizzard's HandleModifiedItemClick
-- calls ChatEdit_InsertLink), so the same link seen again within the same
-- frame (same GetTime()) is the same click and is skipped.
local lastLabLink, lastLabLinkTime
local function LabLinkClickOnce(link)
    local now = GetTime()
    if link == lastLabLink and now == lastLabLinkTime then return end
    lastLabLink, lastLabLinkTime = link, now
    MSC.OnItemLinkClick(link)
end
if HandleModifiedItemClick then hooksecurefunc("HandleModifiedItemClick", function(link) if link and IsShiftKeyDown() and MSC.ViewLab and MSC.ViewLab:IsShown() then LabLinkClickOnce(link) end end) end
if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", function(link) if link and MSC.ViewLab and MSC.ViewLab:IsShown() then LabLinkClickOnce(link) end end) end
if DressUpItemLink then hooksecurefunc("DressUpItemLink", function(link) if link and MSC.ViewLab and MSC.ViewLab:IsShown() then MSC.OnItemLinkClick(link) end end) end

if hooksecurefunc then
    -- Shares one pending refresh with the QUEST_* events (QueueQuestRefresh).
    -- Wrapped so hook arguments are not passed through.
    local function TriggerQuestUpdate() QueueQuestRefresh() end

    if QuestInfo_Display then hooksecurefunc("QuestInfo_Display", TriggerQuestUpdate) end
    if QuestLog_Update then hooksecurefunc("QuestLog_Update", TriggerQuestUpdate) end
    if QuestFrameItems_Update then hooksecurefunc("QuestFrameItems_Update", TriggerQuestUpdate) end
    
    if MerchantFrame_UpdateMerchantInfo then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
            C_Timer.After(0.05, function()
                if MSC.UpdateMerchantOverlays then MSC.UpdateMerchantOverlays() end
            end)
        end)
    end

    if ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", function()
            if MSC.QueueBagOverlayRefresh then MSC.QueueBagOverlayRefresh() end
        end)
    end
end

-- [[ CLIENT-SAFE BAG ARROW REFRESH ]]
-- ContainerFrame_Update no longer exists on the modern 11.x-derived engine that
-- TBC Anniversary / Forever now share (same removal category as UnitBuff,
-- GetNumSkillLines, MouseIsOver elsewhere in this addon). The hooksecurefunc
-- above then silently never attaches, so bag-slot arrows never got a trigger
-- there at all even though tooltip verdicts (a separate hook path) kept working.
-- BAG_UPDATE_DELAYED fires on every client family, so use it as the reliable
-- fallback regardless of whether the old global still exists.
-- Opening a bag doesn't fire BAG_UPDATE_DELAYED, so each Blizzard bag frame's
-- own OnShow / UpdateItems is hooked too; otherwise arrows only appeared after
-- the bag contents changed while it was open.
local bagRefreshQueued = false
function MSC.RefreshAllBagOverlays()
    bagRefreshQueued = false
    MSC.ForEachBlizzardBagFrame(function(frame)
        if frame:IsShown() then MSC.UpdateBagOverlays(frame) end
    end)
    MSC.UpdateBankOverlays()
    if MSC.RefreshBagnonOverlays then MSC.RefreshBagnonOverlays() end
    if MSC.RefreshGudaBagsOverlays then MSC.RefreshGudaBagsOverlays() end
    if MSC.RefreshDaylightUIOverlays then MSC.RefreshDaylightUIOverlays() end
    if MSC.RefreshElvUIBagOverlays then MSC.RefreshElvUIBagOverlays() end
end

function MSC.QueueBagOverlayRefresh()
    if bagRefreshQueued then return end
    bagRefreshQueued = true
    C_Timer.After(0, MSC.RefreshAllBagOverlays)
end

local hookedBagFrames = {}
local function HookBlizzardBagFrames()
    MSC.ForEachBlizzardBagFrame(function(frame)
        if hookedBagFrames[frame] then return end
        hookedBagFrames[frame] = true
        frame:HookScript("OnShow", MSC.QueueBagOverlayRefresh)
        if type(frame.UpdateItems) == "function" then
            hooksecurefunc(frame, "UpdateItems", MSC.QueueBagOverlayRefresh)
        end
    end)
    if BankFrame and not hookedBagFrames[BankFrame] then
        hookedBagFrames[BankFrame] = true
        BankFrame:HookScript("OnShow", MSC.QueueBagOverlayRefresh)
    end
end
HookBlizzardBagFrames()

local bagRefreshFrame = CreateFrame("Frame")
bagRefreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
bagRefreshFrame:RegisterEvent("BAG_UPDATE_DELAYED")
bagRefreshFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
-- The bank: opening it and its main slots changing don't fire BAG_UPDATE_DELAYED
pcall(bagRefreshFrame.RegisterEvent, bagRefreshFrame, "BANKFRAME_OPENED")
pcall(bagRefreshFrame.RegisterEvent, bagRefreshFrame, "PLAYERBANKSLOTS_CHANGED")
bagRefreshFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then HookBlizzardBagFrames() end
    MSC.QueueBagOverlayRefresh()
end)


if GroupLootFrame_OpenNewFrame then
        hooksecurefunc("GroupLootFrame_OpenNewFrame", function()
            C_Timer.After(0.1, function()
                if MSC.UpdateLootRollOverlays then MSC.UpdateLootRollOverlays() end
            end)
        end)
    end

function MSC.CreatePopupFrame(title)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(500, 400); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Title:SetPoint("TOP", 0, -15); f.Title:SetText(title)
    
    f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.Close:SetPoint("TOPRIGHT", -5, -5)
    
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 20, -40); sf:SetPoint("BOTTOMRIGHT", -40, 50)
    
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetSize(440, 350); eb:SetFontObject("ChatFontNormal")
    eb:SetAutoFocus(false)
    
    -- [ FIX FOR STATIC WINDOW ] --
    eb:EnableMouse(true)
    eb:SetScript("OnMouseDown", function(self) self:SetFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() f:Hide() end) 
    
    -- Let clicking the empty space in the ScrollFrame also focus the EditBox
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function() eb:SetFocus() end)
    -------------------------------
    
    sf:SetScrollChild(eb)
    
    f.EditBox = eb
    return f
end

function MSC.ShowImportWindow()
    if MSC.ImportFrame then MSC.ImportFrame:Show(); return end
    local f = MSC.CreatePopupFrame(MSC.L["Import Pawn/Sixty Upgrades String"])
    f.EditBox:SetText(MSC.L["Paste Pawn or Sixty Upgrades string here..."])
    f.EditBox:HighlightText()
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(120, 25); b:SetPoint("BOTTOM", 0, 15); b:SetText(MSC.L["Import"])
	b:SetScript("OnClick", function()
		local text = f.EditBox:GetText()
		if MSC.ImportAndSavePawnString then
			-- We only call the function; the messages are handled in SavePawnProfile
			MSC:ImportAndSavePawnString(text)
		else 
			print(MSC.L["|cffff0000SGJ Error:|r ImportAndSavePawnString missing."]) 
		end
		f:Hide() -- Hide the paste window immediately
	end)
    MSC.ImportFrame = f
end

function MSC.ShowHistory()
    if MSC.ExportFrame then MSC.ExportFrame:Show(); MSC.ExportFrame.EditBox:HighlightText(); return end
    local f = MSC.CreatePopupFrame(MSC.L["Export Data (Discord Ready)"])
    local unit = "player"
    local name = UnitName(unit)
    local realm = GetRealmName()
    local lvl = UnitLevel(unit)
    local _, class = UnitClass(unit)
    
    local weights, specName = MSC.GetCurrentWeights()
    if not weights and MSC.CurrentClass and MSC.CurrentClass.Weights then 
        specName, weights = next(MSC.CurrentClass.Weights) 
    end
    local profileName = (MSC.PrettyNames and MSC.PrettyNames[specName]) or specName or MSC.L["Unknown"]

    local gearTable = {}
    for i=1, 18 do gearTable[i] = GetInventoryItemLink(unit, i) end
    local totalScore = MSC:GetTotalCharacterScore(gearTable, weights, specName)

    local exportStr = string_format("```ini\n[ %s - %s (Lvl %d %s) ]\n", name, realm, lvl, class)
    exportStr = exportStr .. string_format("Profile    = %s\n", profileName)
    exportStr = exportStr .. string_format("TotalScore = %.1f\n\n", totalScore)
    exportStr = exportStr .. "[ Equipment ]\n"

    local slots = {
        {1, "Head"}, {2, "Neck"}, {3, "Shoulder"}, {15, "Back"}, {5, "Chest"}, 
        {9, "Wrist"}, {10, "Hands"}, {6, "Waist"}, {7, "Legs"}, {8, "Feet"}, 
        {11, "Ring1"}, {12, "Ring2"}, {13, "Trinket1"}, {14, "Trinket2"}, 
        {16, "MainHand"}, {17, "OffHand"}, {18, "Ranged"}
    }
    
    for _, info in ipairs(slots) do
        local slotID, label = unpack(info)
        local link = gearTable[slotID]
        if link then
            local itemName = GetItemInfo(link) or MSC.L["Unknown Item"]
            local stats = MSC.SafeGetItemStats(link, slotID, weights, specName)
            local score = MSC.GetItemScore(stats, weights, specName, slotID)
            exportStr = exportStr .. string_format("%-10s = %s (%.1f)\n", label, itemName, score)
        else
            exportStr = exportStr .. string_format("%-10s = %s\n", label, MSC.L["(Empty)"])
        end
    end
    exportStr = exportStr .. "```"
    f.EditBox:SetText(exportStr)
    f.EditBox:HighlightText()
    f.EditBox:SetScript("OnEscapePressed", function() f:Hide() end)
    MSC.ExportFrame = f
end

-- Fills every missing setting with its default, keeping existing choices.
-- Used on load and again by /sgjwipe. The defaults table is rebuilt each call
-- so no two wipes share the same nested tables.
function MSC.ApplySettingsDefaults()
    RXP_SGJ_Settings = RXP_SGJ_Settings or {}

    -- DEFINE DEFAULTS (These only apply if the setting doesn't exist yet)
    local defaults = {
        EnchantMode = 1,       -- Off
        GemMode = 1,           -- Skeptic
        GemQuality = 3,        -- NEW: Rare (Blue) Default
        Mode = "AUTO",         -- Auto-Detect
        HideMinimap = true, -- vendor patch: no minimap button
        HideTooltips = false,
        MuteSounds = false,
        CompactEquip = false,
        ColorizeStats = true,
        SimplifyStats = false,
        TrackedSpecs = {},
        GearProfiles = {},
        ShowBagArrows = true,  -- on by default since 3.2.10 (see the one-time switch below)
        FastBagArrows = true,
        ShowLootArrows = false,
        ShowLootToast = true,  -- LootToast.lua: an alert when an item you loot or receive is an upgrade (3.2.10)
        ShareScores = true,    -- SGJ_API.lua: answer group addons' score requests
        AssumeRaidBuffs = false,
        AssumeWorldBuffs = false,
        AssumeCampingBuffs = false,
        GearForRaiding = true, -- Forever: hit/defense targets slide to raid caps from 50
        GearForPvP = false,    -- Forever: PvP model over every profile (MSC.ApplyForeverPvP); per spec in SpecSettings
        ShowOtherSpec = true,  -- Dual Specialization: tooltip line for the inactive spec
        ShieldTankNo2H = true, -- shield tanks never see a two-hander as an upgrade
        RaidBuffPreset = "off",
        WorldBuffPreset = "off",
        RaidBuffToggles = {},
        WorldBuffToggles = {},
        ContentPhase = 1,
    }

    -- FILL MISSING SETTINGS ONLY
    -- This loop preserves existing user choices during updates
    for key, value in pairs(defaults) do
        if RXP_SGJ_Settings[key] == nil then
            RXP_SGJ_Settings[key] = value
        end
    end
    -- 3.2.10: bag arrows are on by default. Until now the old default (off) was saved for everyone, so a saved "off"
    -- can't tell a choice from the old default: turn them on once for every account; unticking it afterwards sticks.
    if not RXP_SGJ_Settings.BagArrowsDefaultOn then
        RXP_SGJ_Settings.ShowBagArrows = true
        RXP_SGJ_Settings.BagArrowsDefaultOn = true
    end
    if MSC.BuffEngine and MSC.BuffEngine.InitSettings then MSC.BuffEngine:InitSettings() end

    -- Ensure the manual spec override is actually loaded into the engine!
    MSC.ManualSpec = MSC.GetManualSpec(MSC.GetActiveSpecGroup())
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name == addonName then
        -- 1. INITIALIZE SAVED VARIABLES
        RXP_SGJ_DB = RXP_SGJ_DB or { customWeights = {} }

        -- 2. DEFAULTS FOR ANY MISSING SETTING
        MSC.ApplySettingsDefaults()

        if not MSC.IsVanillaRules and MSC.BuildGemOptionsForPhase then
            MSC:BuildGemOptionsForPhase(RXP_SGJ_Settings.ContentPhase or 1)
        end

        -- Clean up the loader
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

function MSC:ShowScoreBreakdown(itemLink, slotID)
    if not itemLink then return end
    if not MSC.BreakdownFrame then
        local f = CreateFrame("Frame", "SGJ_BreakdownFrame", UIParent, "BackdropTemplate")
        f:SetSize(300, 300)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.Title:SetPoint("TOP", 0, -15)
        f.Title:SetTextColor(1, 0.82, 0)
        f.Close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.Close:SetPoint("TOPRIGHT", -5, -5)
        f.Content = CreateFrame("Frame", nil, f)
        f.Content:SetPoint("TOPLEFT", 25, -50)
        f.Content:SetPoint("BOTTOMRIGHT", -25, 25)
        -- Positioned once: after a drag it stays where the player put it
        f:SetPoint("CENTER")
        MSC.BreakdownFrame = f
    end

    local f = MSC.BreakdownFrame
    f:Show()
    
    local weights, specName = MSC.GetCurrentWeights()
    if not weights and MSC.CurrentClass then 
        specName, weights = next(MSC.CurrentClass.Weights) 
    end
    if not weights then f.Title:SetText(MSC.L["No Weights Loaded"]) return end

    local stats = MSC.SafeGetItemStats(itemLink, slotID, weights, specName)
    local sorted = {}
    local totalScore = 0
    
    for k, v in pairs(stats) do
        if type(v) == "number" then
            local w = weights[k] or 0
            if w > 0 then
                local subScore = v * w
                totalScore = totalScore + subScore
                table_insert(sorted, { k=k, v=v, w=w, s=subScore })
            end
        end
    end
    -- (An item's _AUTO_PROC value is already folded into its stats by
    -- SafeGetItemStats, so it isn't added again here.)

    table_sort(sorted, function(a,b) return a.s > b.s end)
    
    if f.lines then for _, l in ipairs(f.lines) do l:Hide() end end
    f.lines = f.lines or {}
    
    local itemName = GetItemInfo(itemLink) or MSC.L["Unknown Item"]
    f.Title:SetText(itemName)
    
    local yOff = 0
    for i, data in ipairs(sorted) do
        local line = f.lines[i]
        if not line then
            line = f.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            line:SetJustifyH("LEFT")
            f.lines[i] = line
        end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", 0, yOff)
        local cleanName = MSC.GetCleanStatName(data.k)
        line:SetText(string_format("|cffffffff%.1f %s|r  x %.2f  =  |cff00ff00%.1f|r", data.v, cleanName, data.w, data.s))
        line:Show()
        yOff = yOff - 20
    end
    
    local totalIdx = #sorted + 1
    local totalLine = f.lines[totalIdx]
    if not totalLine then
        totalLine = f.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        totalLine:SetJustifyH("RIGHT")
        f.lines[totalIdx] = totalLine
    end
    totalLine:ClearAllPoints()
    totalLine:SetPoint("TOPRIGHT", 0, yOff - 10)
    totalLine:SetText(MSC.L["Total Score: "] .. string_format("|cff00ff00%.1f|r", totalScore))
    totalLine:Show()
    f:SetHeight(math_abs(yOff) + 100)
end

-- [[ CATCH-ALL FOR UI RELOADS ]]
-- The profession addons may already be loaded (e.g. after /reload).
MSC.HookProfessionWindows()

-- =============================================================
-- BLIZZARD UI HOTFIX
-- PREVENTS 3RD PARTY ADDONS FROM CRASHING THE QUEST REWARD FRAME (MAINLY WEAKAURAS)
-- =============================================================
if QuestInfo_ShowRewards then
    local original_QuestInfo_ShowRewards = QuestInfo_ShowRewards
    
    QuestInfo_ShowRewards = function(...)
        local rewardsFrame = QuestInfoFrame.rewardsFrame or QuestInfoRewardsFrame
        
        if rewardsFrame and rewardsFrame.RewardButtons then
            -- 1. Prevent the "Button Height" crash by ensuring Button 1 always exists
            if not rewardsFrame.RewardButtons[1] then
                QuestInfo_GetRewardButton(rewardsFrame, 1)
            end
            
            -- 2. Find if the mystery addon left any "holes" in the table
            local maxIndex = 0
            for k, v in pairs(rewardsFrame.RewardButtons) do
                if type(k) == "number" and k > maxIndex then
                    maxIndex = k
                end
            end
            
            -- 3. Fill the holes with real buttons so Blizzard's loop doesn't hit a nil value
            for i = 1, maxIndex do
                if not rewardsFrame.RewardButtons[i] then
                    QuestInfo_GetRewardButton(rewardsFrame, i)
                end
            end
        end
        
        -- Safely resume the original Blizzard function
        return original_QuestInfo_ShowRewards(...)
    end
end

local function DumpBadSettings()
    if not RXP_SGJ_Settings then return end
    for k, v in pairs(RXP_SGJ_Settings) do
        if type(v) == "function" or type(v) == "userdata" then
            print("|cffff0000SGJ ERROR:|r Bad setting type in key: ", k)
        elseif type(v) == "table" then
            for k2, v2 in pairs(v) do
                if type(v2) == "function" or type(v2) == "userdata" then
                    print("|cffff0000SGJ ERROR:|r Bad setting type in subkey: ", k, k2)
                end
            end
        end
    end
end
local badScanner = CreateFrame("Frame")
-- badScanner:RegisterEvent("PLAYER_LEAVING_WORLD")
badScanner:SetScript("OnEvent", DumpBadSettings)

local function SGJWipeSettings()
    RXP_SGJ_Settings = {}
    -- Put every default back at once (buff toggles included) so nothing that
    -- reads the settings meets a missing table before the next /reload.
    MSC.ApplySettingsDefaults()
    MSC.OnScoringSettingsChanged()
    print(MSC.L["|cff00ff00SGJ:|r Settings reset to defaults. /reload to refresh any open windows."])
end
-- vendor patch (no slash command): SLASH_SGJ_WIPE1 = "/sgjwipe"
-- vendor patch (no slash command): SlashCmdList["SGJ_WIPE"] = SGJWipeSettings

local function SGJCheckCorrupt()
    local bads = {}
    local function checkLevel(t, path)
        for k, v in pairs(t) do
            local currentPath = path .. "." .. tostring(k)
            local tv = type(v)
            if tv == "function" or tv == "userdata" or (tv == "table" and v.GetObjectType) then
                table.insert(bads, currentPath .. " is " .. tv)
            elseif tv == "table" then
                checkLevel(v, currentPath)
            end
        end
    end
    checkLevel(RXP_SGJ_Settings, "RXP_SGJ_Settings")
    if #bads > 0 then
        for _, msg in ipairs(bads) do print("|cffff0000CORRUPT:|r", msg) end
    else
        print("|cff00ff00SGJ:|r No corruption found in RXP_SGJ_Settings!")
    end
end
-- vendor patch (no slash command): SLASH_SGJ_CORRUPT1 = "/sgjcheck"
-- vendor patch (no slash command): SlashCmdList["SGJ_CORRUPT"] = SGJCheckCorrupt

local function SGJCheckCorrupt2()
    local bads = {}
    local function checkLevel(t, path)
        for k, v in pairs(t) do
            local currentPath = path .. "." .. tostring(k)
            local tv = type(v)
            if tv == "function" or tv == "userdata" or (tv == "table" and v.GetObjectType) then
                table.insert(bads, currentPath .. " is " .. tv)
            elseif tv == "table" then
                checkLevel(v, currentPath)
            end
        end
    end
    if RXP_SGJ_DB then checkLevel(RXP_SGJ_DB, "RXP_SGJ_DB") end
    
    if #bads > 0 then
        for _, msg in ipairs(bads) do print("|cffff0000CORRUPT:|r", msg) end
    else
        print("|cff00ff00SGJ:|r No corruption found in other DBs either!")
    end
end
-- vendor patch (no slash command): SLASH_SGJ_CORRUPT_TWO1 = "/sgjcheck2"
-- vendor patch (no slash command): SlashCmdList["SGJ_CORRUPT_TWO"] = SGJCheckCorrupt2

local function ForceWriteSGJ()
    print("|cff00ff00SGJ:|r Forcing save...")
    -- Dirty the variable explicitly
    RXP_SGJ_Settings._forceSave = GetTime()
    
    print("ShowBagArrows is:", RXP_SGJ_Settings.ShowBagArrows)
end
-- vendor patch (no slash command): SLASH_SGJ_FORCE1 = "/sgjforce"
-- vendor patch (no slash command): SlashCmdList["SGJ_FORCE"] = ForceWriteSGJ

-- ============================================================================
-- QUICK SAVE WORKAROUND (PTR/BETA SAVEDVARIABLES BUG FIX)
-- ============================================================================

-- Shown after "Delete Custom Profile" (SGJ_RELOAD_REQUIRED's text is about imports).
StaticPopupDialogs["SGJ_PROFILE_DELETED"] = {
    text = MSC.L["|cff00ccffSharpie's Gear Judge|r\n\nCustom profile deleted.\n\nReload your UI to remove it from the profile lists."],
    button1 = MSC.L["Reload Now"],
    button2 = MSC.L["Later"],
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["SGJ_QUICK_SAVE"] = {
    text = MSC.L["Save addon data to disk?\n\nThis will trigger a UI Reload to forcefully write all SavedVariables into your WTF folder. (This bypasses the Beta client crash bug)."],
    button1 = MSC.L["Save (Reload UI)"],
    button2 = MSC.L["Cancel"],
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3, 
}

local function QuickSaveSGJ()
    if InCombatLockdown() then
        print(MSC.L["|cffff0000SGJ:|r Cannot quick-save while in combat!"])
        return
    end
    StaticPopup_Show("SGJ_QUICK_SAVE")
end

-- vendor patch (no slash command): SLASH_SGJ_SAVE1 = "/sgjsave"
-- vendor patch (no slash command): SlashCmdList["SGJ_SAVE"] = QuickSaveSGJ

-- Slot order/labels match Laboratory.lua's OrderedSlots so scalar dumps and
-- Lab imports read the same way.
local SGJ_ScalarGearSlots = {
    { slot = "HeadSlot", label = "Head" }, { slot = "NeckSlot", label = "Neck" },
    { slot = "ShoulderSlot", label = "Shoulder" }, { slot = "BackSlot", label = "Back" },
    { slot = "ChestSlot", label = "Chest" }, { slot = "WristSlot", label = "Wrist" },
    { slot = "HandsSlot", label = "Hands" }, { slot = "WaistSlot", label = "Waist" },
    { slot = "LegsSlot", label = "Legs" }, { slot = "FeetSlot", label = "Feet" },
    { slot = "Finger0Slot", label = "Ring 1" }, { slot = "Finger1Slot", label = "Ring 2" },
    { slot = "Trinket0Slot", label = "Trinket 1" }, { slot = "Trinket1Slot", label = "Trinket 2" },
    { slot = "MainHandSlot", label = "Main Hand" }, { slot = "SecondaryHandSlot", label = "Off Hand" },
    { slot = "RangedSlot", label = "Ranged" },
}

-- vendor patch (no slash command): SLASH_SGJ_SCALAR1 = "/sgjscalar"
local _ = function() -- vendor patch: not registered
    local ratings = {
        {id=2, name="Defense"}, {id=3, name="Dodge"}, {id=4, name="Parry"}, {id=5, name="Block"},
        {id=6, name="Melee Hit"}, {id=7, name="Ranged Hit"}, {id=8, name="Spell Hit"},
        {id=9, name="Melee Crit"}, {id=10, name="Ranged Crit"}, {id=11, name="Spell Crit"},
        {id=15, name="Resilience"}, {id=18, name="Melee Haste"}, {id=19, name="Ranged Haste"},
        {id=20, name="Spell Haste"}, {id=24, name="Expertise"}, {id=29, name="Mastery"}
    }

    local _, classStr = UnitClass("player")
    local _, raceStr = UnitRace("player")

    local out = {}
    table.insert(out, "[SGJ Scalar Test] - Level " .. UnitLevel("player") .. " " .. raceStr .. " " .. classStr)
    table.insert(out, "--------------------------------------------------")

    local foundAny = false
    for _, r in ipairs(ratings) do
        local cr = GetCombatRating(r.id) or 0
        local cb = GetCombatRatingBonus(r.id) or 0
        if cr > 0 and cb > 0 then
            table.insert(out, r.name .. ": " .. string.format("%.2f", cr / cb) .. " rating = 1%")
            foundAny = true
        end
    end

    if not foundAny then
        table.insert(out, "[!] No Combat Ratings found on your current gear.")
        table.insert(out, "Equip gear with any Combat Rating to test!")
    end

    -- [[ EQUIPPED GEAR ]]
    table.insert(out, "")
    table.insert(out, "Equipped Gear:")
    local anyGear = false
    for _, s in ipairs(SGJ_ScalarGearSlots) do
        local slotID = GetInventorySlotInfo(s.slot)
        local link = slotID and GetInventoryItemLink("player", slotID)
        if link then
            anyGear = true
            local itemID = link:match("item:(%d+)")
            if itemID then
                table.insert(out, string.format("  %s: %s (ID: %s)", s.label, link, itemID))
            else
                table.insert(out, string.format("  %s: %s", s.label, link))
            end
        end
    end
    if not anyGear then
        table.insert(out, "  (nothing equipped)")
    end

    local strTotal = select(2, UnitStat("player", 1))
    local agiTotal = select(2, UnitStat("player", 2))
    local staTotal = select(2, UnitStat("player", 3))
    local intTotal = select(2, UnitStat("player", 4))
    local spiTotal = select(2, UnitStat("player", 5))

    local rawB, rawP, rawN = UnitAttackPower("player")
    local baseAP = MSC.SanitizeStat(rawB)
    local posAP = MSC.SanitizeStat(rawP)
    local negAP = MSC.SanitizeStat(rawN)
    local totalAP = baseAP + posAP + negAP

    local rawRB, rawRP, rawRN = UnitRangedAttackPower("player")
    local totalRangedAP = MSC.SanitizeStat(rawRB) + MSC.SanitizeStat(rawRP) + MSC.SanitizeStat(rawRN)

    local defBase, defModifier = UnitDefense("player")
    local totalDefense = MSC.SanitizeStat(defBase) + MSC.SanitizeStat(defModifier)

    local _armorBase, _armorEffectiveBase, armorTotal = UnitArmor("player")
    local totalArmor = MSC.SanitizeStat(armorTotal)

    local baseRegen, castingRegen = GetManaRegen()
    local pRegen = GetPowerRegen()

    table.insert(out, "")
    table.insert(out, "(Primary Stat conversions below are specific to " .. classStr .. "s)")
    table.insert(out, "Total Str: " .. strTotal .. " | Total Agi: " .. agiTotal)
    table.insert(out, "Total Sta: " .. staTotal .. " | Total Int: " .. intTotal)
    table.insert(out, "Total Spi: " .. spiTotal)
    table.insert(out, "---")
    table.insert(out, "Total Max Health: " .. UnitHealthMax("player"))
    table.insert(out, "Total Armor: " .. totalArmor)
    table.insert(out, "Total Attack Power: " .. totalAP .. " | Total Ranged AP: " .. totalRangedAP)
    table.insert(out, "Total Defense Skill: " .. totalDefense)
    table.insert(out, string.format("Total Dodge: %.2f%% | Total Parry: %.2f%% | Total Block: %.2f%%", GetDodgeChance() or 0, GetParryChance() or 0, GetBlockChance() or 0))
    table.insert(out, "Total Melee Crit: " .. string.format("%.2f%%", GetCritChance()))
    table.insert(out, "Total Spell Crit: " .. string.format("%.2f%%", GetSpellCritChance(2)))
    table.insert(out, "Total Spell Power: " .. MSC.SanitizeStat(GetSpellBonusDamage(2)) .. " | Total Healing Power: " .. MSC.SanitizeStat(GetSpellBonusHealing()))
    table.insert(out, string.format("Mana Regen (per 5s): %.1f Not Casting | %.1f Casting", (baseRegen or 0)*5, (castingRegen or 0)*5))
    table.insert(out, string.format("Power Regen (per 1s): %.1f", pRegen or 0))

    if not MSC.ScalarExportFrame then
        MSC.ScalarExportFrame = MSC.CreatePopupFrame("SGJ Scalar Export")
    end

    MSC.ScalarExportFrame.EditBox:SetText(table.concat(out, "\n"))
    MSC.ScalarExportFrame:Show()
    MSC.ScalarExportFrame.EditBox:HighlightText()
end




