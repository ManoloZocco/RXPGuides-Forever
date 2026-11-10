if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS

-- =============================================================
-- PUBLIC API (v1, core 3.2.7)
-- =============================================================
-- A small, stable interface for other addons (loot council, loot distribution, bag and UI addons). Everything else in MSC
-- is internal and may change between releases; this table keeps its names and return values within an API version.
-- Documentation: SGJ_API_Info.md in this folder.
--
--   local SGJ = _G.SharpiesGearJudgeAPI            -- or _G.MSC.API; nil when the addon isn't loaded
--   if SGJ and SGJ.IsReady() then
--       local r = SGJ.ScoreItem(link)               -- for the logged-in player
--       if r then print(r.upgradePct) end
--   end
--
-- Raid requests: SGJ.RequestScores(links, "RAID", nil, function(sender, r) ... end) asks every group member who runs
-- Sharpie's Gear Judge to score the items for their own character and send the result back (addon prefix "SGJ").

local API = { version = 1 }
MSC.API = API
_G.SharpiesGearJudgeAPI = API

local PREFIX = "SGJ"
local PROTO = 1
local string_format, string_match, tonumber, tostring = string.format, string.match, tonumber, tostring
local TWIN_SLOT = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }

-- -------------------------------------------------------------
-- Version and readiness
-- -------------------------------------------------------------
local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

-- Returns the API version (integer, raised only on breaking changes) and the addon version ("3.2.7").
function API.GetVersion()
    return API.version, (GetMetadata and GetMetadata(addonName, "Version")) or "?"
end

-- True once the player's class module is loaded and weights can be built (after PLAYER_LOGIN).
function API.IsReady()
    return MSC.CurrentClass ~= nil and MSC.GetCurrentWeights ~= nil and MSC.EvaluateUpgrade ~= nil
end

-- The profile the player is judged by: spec key (e.g. "RET_STANDARD"), display name ("Retribution: Raid").
function API.GetSpec()
    if not API.IsReady() then return nil end
    local ok, weights, specKey = pcall(MSC.GetCurrentWeights)
    if not ok or not weights then return nil end
    local names = MSC.CurrentClass and MSC.CurrentClass.PrettyNames
    return specKey, (names and names[specKey]) or specKey
end

-- -------------------------------------------------------------
-- Scoring for the logged-in player
-- -------------------------------------------------------------
-- The same numbers the tooltip shows. Returns a result table, or nil and a reason:
--   "NOT_READY"      the addon hasn't finished loading (try again after PLAYER_LOGIN)
--   "BAD_LINK"       not an item link / item string
--   "NOT_CACHED"     the client has no item data yet (GetItemInfo is nil; ask again shortly)
--   "NOT_EQUIPPABLE" not a piece of gear
--   "NOT_USABLE"     this class can't use it (armor type, weapon skill, class restriction)
--   "ERROR"          scoring failed (a bug: please report it)
-- Result fields:
--   itemLink, itemID
--   itemScore          the item's own score in that slot (stats, projected enchant and gems, weapon bonus)
--   equippedScore      the same for the item it would replace (nil for an empty slot)
--   characterScore     Judge's Score of the whole character now
--   newCharacterScore  Judge's Score wearing the item
--   upgrade            newCharacterScore - characterScore
--   upgradePct         upgrade as % of characterScore (nil when characterScore is 0); negative = downgrade
--   slot               inventory slot compared (the weaker ring / trinket, the right hand ...)
--   equippedLink       the item in that slot now (nil when empty)
--   equipped           true when this exact item is the one worn
--   spec, specName     the profile used
-- Scores are points on this character's own scale: compare players by upgradePct, not by raw scores.
function API.ScoreItem(link)
    if not API.IsReady() then return nil, "NOT_READY" end
    if type(link) ~= "string" or not string_match(link, "item:%-?%d+") then return nil, "BAD_LINK" end
    local name, fullLink, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    if not name then return nil, "NOT_CACHED" end
    link = fullLink or link
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" or equipLoc == "INVTYPE_BAG" then return nil, "NOT_EQUIPPABLE" end
    if MSC.IsItemUsable and not MSC.IsItemUsable(link) then return nil, "NOT_USABLE" end

    local ok, result = pcall(function()
        local weights, specKey = MSC.GetCurrentWeights()
        if not weights or not next(weights) then return nil end
        local slot = MSC.GetComparisonSlot(link, equipLoc, weights, specKey)
        if not slot then return false end
        -- this exact item worn (in the compared slot or its twin): score it in its own slot
        local equipped = false
        if GetInventoryItemLink("player", slot) == link then equipped = true
        elseif TWIN_SLOT[slot] and GetInventoryItemLink("player", TWIN_SLOT[slot]) == link then slot, equipped = TWIN_SLOT[slot], true end

        local newScore, oldScore, newStats, oldStats = MSC:EvaluateUpgrade(link, slot, weights, specKey)
        local wornLink = GetInventoryItemLink("player", slot)
        local function SlotScore(stats, itemLink)
            if not stats or not next(stats) then return nil end
            local s = MSC.GetItemScore(stats, weights, specKey, slot)
            if itemLink and (slot == 16 or slot == 17) and MSC.GetWeaponSpecBonus then
                s = s + (MSC:GetWeaponSpecBonus(itemLink, MSC.CurrentClass, specKey, weights, slot, GetInventoryItemLink("player", slot == 16 and 17 or 16)) or 0)
            end
            return s
        end
        local names = MSC.CurrentClass and MSC.CurrentClass.PrettyNames
        local r = {
            itemLink = link, itemID = tonumber(string_match(link, "item:(%-?%d+)")),
            itemScore = SlotScore(newStats, link),
            equippedScore = (not equipped and wornLink) and SlotScore(oldStats, wornLink) or nil,
            characterScore = oldScore, newCharacterScore = newScore,
            upgrade = (newScore or 0) - (oldScore or 0),
            slot = slot, equippedLink = wornLink, equipped = equipped,
            spec = specKey, specName = (names and names[specKey]) or specKey,
        }
        if equipped then r.equippedScore, r.upgrade = r.itemScore, 0 end
        if oldScore and oldScore > 0 then r.upgradePct = r.upgrade / oldScore * 100 end
        return r
    end)
    if not ok then return nil, "ERROR" end
    if result == false then return nil, "NOT_EQUIPPABLE" end
    if not result then return nil, "NOT_READY" end
    return result
end

-- -------------------------------------------------------------
-- Callbacks
-- -------------------------------------------------------------
-- API.RegisterCallback("SCORES_CHANGED", fn): fn() runs (once per frame at most) when anything that changes the
-- player's scores changes: gear, talents, level, spec or profile choice, settings. Cached results are stale after it.
-- API.RegisterCallback("SCORES_RECEIVED", fn): fn(sender, result) for each raid reply (see RequestScores).
local callbacks = { SCORES_CHANGED = {}, SCORES_RECEIVED = {} }
function API.RegisterCallback(event, fn)
    if callbacks[event] and type(fn) == "function" then callbacks[event][fn] = true return true end
    return false
end
function API.UnregisterCallback(event, fn)
    if callbacks[event] then callbacks[event][fn] = nil end
end
local function Fire(event, ...)
    for fn in pairs(callbacks[event]) do pcall(fn, ...) end
end
local changePending = false
if MSC.BumpScoringRevision then
    hooksecurefunc(MSC, "BumpScoringRevision", function()
        if changePending or not next(callbacks.SCORES_CHANGED) then return end
        changePending = true
        C_Timer.After(0, function() changePending = false; Fire("SCORES_CHANGED") end)
    end)
end

-- -------------------------------------------------------------
-- Raid requests (addon messages, prefix "SGJ", protocol 1)
-- -------------------------------------------------------------
-- Request:  Q~1~<id>~<itemString>^<itemString>...    (sent to RAID / PARTY / INSTANCE_CHAT / GUILD or a WHISPER)
-- Reply:    A~1~<id>~<itemID>~<status>~<upgradePct>~<itemScore>~<equippedScore>~<slot>~<equippedItemID>~<spec>
--           whispered back to the requester, one per item; status OK, NC (not cached), NU (not usable),
--           NE (not equippable), NR (not ready), ER (error); empty fields for unknown values.
-- Players answer only while the "share scores" setting is on (RXP_SGJ_Settings.ShareScores, default on). Replies are spread
-- out (a random start within 1.5 s, then 0.25 s apart) so a whole raid answering doesn't flood the channel.
local ChatInfo = C_ChatInfo or {}
local SendAddon = ChatInfo.SendAddonMessage or SendAddonMessage
local RegisterPrefix = ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
if RegisterPrefix then RegisterPrefix(PREFIX) end

local function ItemString(link)
    return string_match(link, "|H(item:[^|]+)|h") or string_match(link, "^(item:[%-%d:]+)") or (tonumber(link) and ("item:" .. link))
end
local function fmt(x) return x and string_format("%.2f", x) or "" end

local requestSeq, myRequests = 0, {}
local STATUS = { NOT_CACHED = "NC", NOT_USABLE = "NU", NOT_EQUIPPABLE = "NE", NOT_READY = "NR", ERROR = "ER", BAD_LINK = "NE" }
local REASON = { NC = "NOT_CACHED", NU = "NOT_USABLE", NE = "NOT_EQUIPPABLE", NR = "NOT_READY", ER = "ERROR" }

-- Asks the group to score items. links: one link or a list. channel: "RAID", "PARTY", "INSTANCE_CHAT", "GUILD" or
-- "WHISPER" (target = player name). callback(sender, result) runs for each reply, and once for the player straight away;
-- result has sender, itemID, itemString, status ("OK" or a reason as in ScoreItem), upgradePct, itemScore,
-- equippedScore, slot, equippedItemID, spec. Returns the request id, or nil and a reason.
function API.RequestScores(links, channel, target, callback)
    if not SendAddon then return nil, "NO_ADDON_MESSAGES" end
    if type(links) == "string" then links = { links } end
    local strings = {}
    for _, l in ipairs(links or {}) do local s = ItemString(l); if s then strings[#strings + 1] = s end end
    if #strings == 0 then return nil, "BAD_LINK" end
    requestSeq = requestSeq + 1
    local id = tostring(requestSeq) .. string_format("%03d", math.random(0, 999))
    myRequests[id] = { callback = callback, items = {}, time = GetTime() }
    for _, s in ipairs(strings) do myRequests[id].items[tonumber(string_match(s, "item:(%-?%d+)")) or 0] = s end
    -- pack as many item strings per message as fit in 255 bytes
    local head, msg = "Q~" .. PROTO .. "~" .. id .. "~", nil
    for _, s in ipairs(strings) do
        if msg and #msg + 1 + #s > 250 then SendAddon(PREFIX, msg, channel, target); msg = nil end
        msg = msg and (msg .. "^" .. s) or (head .. s)
    end
    if msg then SendAddon(PREFIX, msg, channel, target) end
    -- the player's own answer, without a round trip
    local me = UnitName("player")
    for _, s in ipairs(strings) do
        local r, why = API.ScoreItem(s)
        local res = { sender = me, itemString = s, itemID = tonumber(string_match(s, "item:(%-?%d+)")), status = r and "OK" or why }
        if r then res.upgradePct, res.itemScore, res.equippedScore, res.slot, res.spec = r.upgradePct, r.itemScore, r.equippedScore, r.slot, r.spec
            res.equippedItemID = r.equippedLink and tonumber(string_match(r.equippedLink, "item:(%-?%d+)")) end
        if callback then pcall(callback, me, res) end
        Fire("SCORES_RECEIVED", me, res)
    end
    return id
end

-- replies waiting to go out, spaced so a raid's answers don't arrive in one burst
local outbox, sending = {}, false
local function Pump()
    local m = table.remove(outbox, 1)
    if not m then sending = false return end
    SendAddon(PREFIX, m[1], "WHISPER", m[2])
    C_Timer.After(0.25, Pump)
end
local function Queue(text, to)
    outbox[#outbox + 1] = { text, to }
    if not sending then sending = true; C_Timer.After(math.random() * 1.5, Pump) end
end

local function Answer(id, s, sender, tries)
    local itemID = tonumber(string_match(s, "item:(%-?%d+)"))
    local r, why = API.ScoreItem(s)
    if not r and why == "NOT_CACHED" and (tries or 0) < 3 then   -- ask the server for the item, then try again
        if C_Item and C_Item.RequestLoadItemDataByID and itemID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        C_Timer.After(1, function() Answer(id, s, sender, (tries or 0) + 1) end)
        return
    end
    local eq = r and r.equippedLink and string_match(r.equippedLink, "item:(%-?%d+)") or ""
    local fields = { "A", PROTO, id, itemID or "", r and "OK" or (STATUS[why] or "ER"),
        r and fmt(r.upgradePct) or "", r and fmt(r.itemScore) or "", r and fmt(r.equippedScore) or "",
        r and r.slot or "", eq, r and r.spec or "" }
    Queue(table.concat(fields, "~"), sender)
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
    if prefix ~= PREFIX or type(text) ~= "string" then return end
    local kind, proto, id, rest = string_match(text, "^(%a)~(%d+)~([^~]+)~(.*)$")
    if not kind or tonumber(proto) ~= PROTO then return end
    local short = Ambiguate and Ambiguate(sender, "none") or sender
    if kind == "Q" then
        -- our own request echoed back (matched by id: Forever's two-part names make name checks unreliable)
        if myRequests[id] then return end
        if RXP_SGJ_Settings and RXP_SGJ_Settings.ShareScores == false then return end
        for s in string.gmatch(rest, "[^%^]+") do Answer(id, s, sender) end
    elseif kind == "A" then
        local req = myRequests[id]
        if not req then return end
        local itemID, status, pct, score, eqScore, slot, eqID, spec = string_match(rest, "^([^~]*)~([^~]*)~([^~]*)~([^~]*)~([^~]*)~([^~]*)~([^~]*)~(.*)$")
        if not itemID then return end
        local res = { sender = short, itemID = tonumber(itemID), itemString = req.items[tonumber(itemID) or 0],
            status = status == "OK" and "OK" or (REASON[status] or "ERROR"), upgradePct = tonumber(pct), itemScore = tonumber(score),
            equippedScore = tonumber(eqScore), slot = tonumber(slot), equippedItemID = tonumber(eqID), spec = spec ~= "" and spec or nil }
        if req.callback then pcall(req.callback, short, res) end
        Fire("SCORES_RECEIVED", short, res)
    end
end)

-- forget requests after 10 minutes
C_Timer.NewTicker(60, function()
    local now = GetTime()
    for id, req in pairs(myRequests) do if now - req.time > 600 then myRequests[id] = nil end end
end)
