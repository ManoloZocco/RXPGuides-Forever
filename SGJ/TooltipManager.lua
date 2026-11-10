if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
_G.MSC = MSC

-- ============================================================================
-- TOOLTIP MANAGER & ASYNC CACHE FIX
-- Solves the "0-Score Downgrade" bug caused by server cache misses on Quest Items.
-- Modernizes tooltip hooks for the TBC Anniversary Client (11.x architecture).
-- ============================================================================

local TooltipManager = CreateFrame("Frame")
TooltipManager:RegisterEvent("PLAYER_LOGIN")

TooltipManager:SetScript("OnEvent", function(self, event)
    -- 1. Store the original evaluation function from Judge.lua
    local original_Evaluate = MSC.EvaluateAndDrawTooltip

    -- 2. Wrap the evaluation function with Cache Protection
    MSC.EvaluateAndDrawTooltip = function(tooltip)
        if not tooltip then return end
        -- Comparison tooltips are never scored (Judge.lua skips them): don't reread items or
        -- add "Fetching" lines there, the client redraws them with every main tooltip refresh.
        if tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2 then return end

        local name, link = MSC_GetTooltipItem(tooltip)
        
        -- Handle quest rewards where MSC_GetTooltipItem(tooltip) might initially return nil
        if MSC.IsQuestHook and not link then 
            link = MSC.HoveredQuestLink 
        end
        
        if link then
            -- GetItemInfo returns nil if the item is not locally cached yet.
            -- If we let Evaluator.lua scan it now, it will return 0 stats.
            if not GetItemInfo(link) then
                
                -- Create a listener to wait for the server to send the item data
                if not MSC.CacheRetryFrame then
                    MSC.CacheRetryFrame = CreateFrame("Frame")
                    MSC.CacheRetryFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
                    MSC.CacheRetryFrame:SetScript("OnEvent", function(self, event, itemID, success)
                        if success and MSC.PendingTooltipLink and MSC.PendingTooltip then
                            
                            -- Verify the item the server just sent is the one we are hovering over
                            -- (full id only: "item:123" must not match "item:1234")
                            local idStr = "item:" .. tostring(itemID)
                            local pLink = MSC.PendingTooltipLink
                            local idMatch = string.find(pLink, idStr .. ":", 1, true) or pLink:sub(-#idStr) == idStr
                            if MSC.PendingTooltip:IsVisible() and idMatch then
                                local tip = MSC.PendingTooltip
                                local pendingLink = MSC.PendingTooltipLink
                                MSC.PendingTooltipLink = nil

                                -- Refresh the tooltip natively to clear the "Fetching" text. SetHyperlink
                                -- fires the tooltip hooks, which evaluate it now the item is cached.
                                tip:SetHyperlink(pendingLink)
                            end
                        end
                    end)
                end
                
                -- Store the active tooltip data
                MSC.PendingTooltipLink = link
                MSC.PendingTooltip = tooltip
                
                -- Add a loading message and STOP the evaluation to prevent the 0-score bug
                tooltip:AddLine(" ")
                local fetchText = (MSC.L and MSC.L["Fetching item data..."]) or "Fetching item data..."
                tooltip:AddLine("|cff888888SGJ: " .. fetchText .. "|r")
                tooltip:Show()
                return 
            end
        end
        
        -- Reread the item and the worn item(s) it's compared against when their
        -- cached reads may predate their Equip: text (Helpers.lua RecheckForTooltip).
        if link and MSC.RecheckForTooltip then MSC.RecheckForTooltip(link) end

        original_Evaluate(tooltip)
    end

    -- ============================================================================
    -- 3. HOOKS & EVENT HIJACKING (Modernized)
    -- ============================================================================
    
    -- Quest Window Hooks
    local function TriggerQuestTooltip(tooltip, link)
        MSC.HoveredQuestLink = link
        MSC.IsQuestHook = true
        MSC.EvaluateAndDrawTooltip(tooltip)
        MSC.IsQuestHook = false    
        tooltip:Show()
    end

    -- Hovering a reward reads it again: the cached read may predate its Equip:
    -- text (quest frames scan rewards the moment they open). When the stats
    -- changed, the tooltip is set again so it's drawn from the new read (the
    -- duplicate guard in Judge.lua skips a second score on the same tooltip).
    local redrawing = false
    local function RecheckQuestTooltip(tooltip, method, link, itemType, index)
        if redrawing or not MSC.RecheckItemScan or not MSC.RecheckItemScan(link) then return end
        redrawing = true
        pcall(tooltip[method], tooltip, itemType, index)
        redrawing = false
        if MSC.UpdateAllQuestOverlays then MSC.UpdateAllQuestOverlays() end
    end

    if GameTooltip.SetQuestItem then
        hooksecurefunc(GameTooltip, "SetQuestItem", function(self, itemType, index)
            local link = GetQuestItemLink(itemType, index)
            TriggerQuestTooltip(self, link)
            RecheckQuestTooltip(self, "SetQuestItem", link, itemType, index)
        end)
    end

    if GameTooltip.SetQuestLogItem then
        hooksecurefunc(GameTooltip, "SetQuestLogItem", function(self, itemType, index)
            local link = GetQuestLogItemLink(itemType, index)
            TriggerQuestTooltip(self, link)
            RecheckQuestTooltip(self, "SetQuestLogItem", link, itemType, index)
        end)
    end

    -- Global Tooltip API (TBC Anniversary / 11.x Client)
    -- Registered under AllTypes rather than Enum.TooltipDataType.Item: on this
    -- client build, that enum value doesn't line up with what the dispatcher
    -- actually tags item tooltips with, so a callback registered for it alone
    -- never fires. AllTypes sidesteps the enum entirely; the tooltip==GameTooltip
    -- (etc.) check below already scopes this to the tooltips we care about.
    if TooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
            if tooltip == GameTooltip or tooltip == ItemRefTooltip or tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2 then
                MSC.EvaluateAndDrawTooltip(tooltip)
            end
        end)
    end
    -- ShoppingTooltip hooks registered unconditionally too, same reasoning as
    -- above: TooltipDataProcessor existing doesn't guarantee it actually fires
    -- on every client build. GameTooltip/ItemRefTooltip's OnTooltipSetItem
    -- hooks live in Judge.lua and are likewise unconditional now.
    do
        if ShoppingTooltip1 and ShoppingTooltip1:HasScript("OnTooltipSetItem") then
            ShoppingTooltip1:HookScript("OnTooltipSetItem", function(self)
                if MSC.EvaluateAndDrawTooltip then
                    MSC.EvaluateAndDrawTooltip(self)
                end
            end)
        end
        if ShoppingTooltip2 and ShoppingTooltip2:HasScript("OnTooltipSetItem") then
            ShoppingTooltip2:HookScript("OnTooltipSetItem", function(self)
                if MSC.EvaluateAndDrawTooltip then
                    MSC.EvaluateAndDrawTooltip(self)
                end
            end)
        end
    end
end)

GameTooltip:HookScript("OnTooltipCleared", function()
    MSC.HoveredQuestLink = nil
    MSC.PendingTooltipLink = nil
    MSC.PendingTooltip = nil
end)
