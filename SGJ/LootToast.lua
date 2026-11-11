if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
local L = MSC.L

-- =============================================================
-- LOOT UPGRADE ALERT (3.2.10)
-- =============================================================
-- An item you loot, receive (quest reward, vendor, mail push) or create that
-- is an upgrade goes straight into your bags, where it's easy to miss. This
-- shows a small alert near the top of the screen: the item, the gain, and a
-- click to equip it (out of combat; right-click closes it). It uses the
-- tooltip's own judgement (MSC:EvaluateUpgrade, the same threshold as the
-- tooltip and bag arrows), so any upgrade counts. Items you can't equip yet
-- (class, armor type or level) are skipped. Setting: RXP_SGJ_Settings.ShowLootToast
-- (on by default).

local SHOW_SECONDS = 8      -- then it fades (held while the mouse is over it)
local MAX_SHOWN = 3         -- alerts on screen at once; older ones close first
local TEX_UP = "Interface\\AddOns\\RXPGuides\\SGJ\\Textures\\Upgrade.png"

-- A Lua pattern from a Blizzard format string, so the loot messages match in
-- every language (the same conversion as the XP plugin's).
local function FormatToPattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%%d%%%$s", "(.-)"):gsub("%%%%%d%%%$d", "(%%d+)")
    p = p:gsub("%%%%s", "(.-)"):gsub("%%%%d", "(%%d+)")
    p = p:gsub("%(%.%-%)|%d[^;:|]*;[^;|]*;", "(.-)"):gsub("%(%.%-%)|%d[^;|]*;", "(.-)")
    p = p:gsub("|%d[^;:|]*;[^;|]*;", ".-"):gsub("|%d[^;|]*;", ".-")
    return "^" .. p
end

-- Your own loot, quest rewards and pushed items, and things you make
local SELF_PATTERNS = {}
for _, fmt in ipairs({ LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_PUSHED_SELF, LOOT_ITEM_PUSHED_SELF_MULTIPLE,
                       LOOT_ITEM_CREATED_SELF, LOOT_ITEM_CREATED_SELF_MULTIPLE, LOOT_ITEM_BONUS_ROLL_SELF }) do
    local p = FormatToPattern(fmt)
    if p then SELF_PATTERNS[#SELF_PATTERNS + 1] = p end
end

local function IsOwnLoot(msg)
    for _, p in ipairs(SELF_PATTERNS) do
        if msg:match(p) then return true end
    end
    return false
end

-- The upgrade, or nil: { link, slot, gain (score), pct (nil = an empty slot) }
local function Judge(link)
    local weights, specName = MSC.GetCurrentWeights()
    if not weights then return nil end
    local itemName, _, _, _, minLevel, _, _, _, equipLoc = GetItemInfo(link)
    if not itemName or not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return nil end
    if minLevel and minLevel > (UnitLevel("player") or 0) then return nil end
    if not MSC.IsItemUsable(link) then return nil end
    local slot = MSC.GetComparisonSlot(link, equipLoc, weights, specName)
    if not slot then return nil end
    local newScore, oldScore = MSC:EvaluateUpgrade(link, slot, weights, specName)
    if not newScore or not oldScore or newScore <= oldScore + MSC.VERDICT_EPS then return nil end
    return { link = link, slot = slot, gain = newScore - oldScore,
             pct = oldScore > 0 and (newScore - oldScore) / oldScore * 100 or nil }
end

-- ---------------------------------------------------------------------
-- The alert frames
-- ---------------------------------------------------------------------
local shown, pool = {}, {}

local function Layout()
    for i, f in ipairs(shown) do
        f:ClearAllPoints()
        f:SetPoint("TOP", UIParent, "TOP", 0, -140 - (i - 1) * 62)
    end
end

local function Close(f)
    f:Hide()
    for i, g in ipairs(shown) do
        if g == f then table.remove(shown, i) break end
    end
    pool[#pool + 1] = f
    Layout()
end

local function Build()
    local f = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    f:SetSize(300, 56)
    f:SetFrameStrata("HIGH")
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.05, 0.06, 0.92)
    f:SetBackdropBorderColor(0.15, 0.85, 0.3, 0.9)

    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetSize(40, 40)
    f.Icon:SetPoint("LEFT", 8, 0)
    f.Arrow = f:CreateTexture(nil, "OVERLAY")
    f.Arrow:SetSize(16, 16)
    f.Arrow:SetPoint("TOPRIGHT", f.Icon, "TOPRIGHT", 4, 4)
    f.Arrow:SetTexture(TEX_UP)

    f.Name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Name:SetPoint("TOPLEFT", f.Icon, "TOPRIGHT", 8, -1)
    f.Name:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    f.Name:SetJustifyH("LEFT")
    f.Name:SetWordWrap(false)
    f.Gain = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.Gain:SetPoint("TOPLEFT", f.Name, "BOTTOMLEFT", 0, -3)
    f.Gain:SetTextColor(0.2, 1, 0.2)
    f.Hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.Hint:SetPoint("TOPLEFT", f.Gain, "BOTTOMLEFT", 0, -2)
    f.Hint:SetText(L["Click to equip, right-click to close"])

    f:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() then self:SetAlpha(1) return end
        self.left = self.left - elapsed
        if self.left <= 0 then Close(self)
        elseif self.left < 1 then self:SetAlpha(self.left) end
    end)
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetHyperlink(self.data.link)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnClick", function(self, button)
        if button == "RightButton" then Close(self) return end
        if InCombatLockdown() then
            if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
            return
        end
        -- the comparison slot keeps a ring or trinket off the one it shouldn't replace
        EquipItemByName(self.data.link, self.data.slot)
        GameTooltip:Hide()
        Close(self)
    end)
    return f
end

local function Show(data)
    -- the same item again (a second copy): refresh its alert instead of adding one
    for _, f in ipairs(shown) do
        if f.data.link == data.link then f.data = data; f.left = SHOW_SECONDS; f:SetAlpha(1) return end
    end
    while #shown >= MAX_SHOWN do Close(shown[1]) end
    local f = table.remove(pool) or Build()
    f.data = data
    local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(data.link)
    f.Icon:SetTexture(texture)
    f.Name:SetText(data.link)
    local r, g, b = 1, 1, 1
    if quality and GetItemQualityColor then r, g, b = GetItemQualityColor(quality) end
    f.Name:SetTextColor(r, g, b)
    f.Gain:SetText(data.pct and string.format(L["+%.1f%% upgrade"], data.pct) or L["Fills an empty slot"])
    f.left = SHOW_SECONDS
    f:SetAlpha(1)
    shown[#shown + 1] = f
    Layout()
    f:Show()
end

-- ---------------------------------------------------------------------
-- Loot messages
-- ---------------------------------------------------------------------
-- Waits for the item to be in the bags (judging pairs it with what you wear)
-- and for its info to load, a few tries at most.
local function TryJudge(link, tries)
    C_Timer.After(0.3, function()
        if not GetItemInfo(link) then
            if tries < 6 then TryJudge(link, tries + 1) end
            return
        end
        local ok, data = pcall(Judge, link)
        if ok and data then Show(data) end
    end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("CHAT_MSG_LOOT")
watcher:SetScript("OnEvent", function(_, _, msg)
    if not (RXP_SGJ_Settings and RXP_SGJ_Settings.ShowLootToast ~= false) then return end
    if type(msg) ~= "string" or (MSC_IsSecret and MSC_IsSecret(msg)) then return end
    if not IsOwnLoot(msg) then return end
    local link = msg:match("|c%x+|Hitem:.-|h.-|h|r") or msg:match("|Hitem:.-|h.-|h")
    if link then TryJudge(link, 0) end
end)

-- /sgj toasttest: shows the alert for an item you're wearing, to check how it looks (clicking it re-equips the same item)
function MSC.TestLootToast()
    for _, slot in ipairs({ 5, 7, 1, 16, 10, 8 }) do
        local link = GetInventoryItemLink("player", slot)
        if link then Show({ link = link, slot = slot, gain = 1, pct = 2.5 }) return end
    end
end
