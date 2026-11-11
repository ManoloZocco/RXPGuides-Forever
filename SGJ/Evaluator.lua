if RXP_SGJ_DISABLED then return end
local addonName, MSC = "RXPGuides", RXP_SGJ_NS
_G.MSC = MSC 

-- [[ SPEED OPTIMIZATION ]]
local pairs, ipairs = pairs, ipairs
local type, tonumber = type, tonumber
local math_floor, math_max, math_abs = math.floor, math.max, math.abs
local table_insert = table.insert
local string_format, string_find = string.format, string.find 
local wipe = wipe or table.wipe
local unpack = unpack or table.unpack

-- WoW API Localizations
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = GetItemInfo
local GetItemInfoInstant = GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
local IsEquippableItem = IsEquippableItem
local UnitClass = UnitClass

-- =============================================================
-- 0. API COMPATIBILITY WRAPPERS
-- =============================================================
local GetBagSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetBagLink  = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink

MSC.SAFETY_CAPS = {}

if MSC.IsTBC or MSC.IsWrath then
    MSC.SAFETY_CAPS = {
        WARRIOR = { { stat="ITEM_MOD_HIT_RATING_SHORT", base=142, talent="PRECISION", tVal=15.8, penalty=100 }, { stat="DEFENSE_FLOOR", base=490, penalty=1000 } },
        PALADIN = { { stat="DEFENSE_FLOOR", base=490, penalty=1000 }, { stat="ITEM_MOD_HIT_RATING_SHORT", base=142, talent="PRECISION", tVal=15.8, penalty=100 }, { stat="ITEM_MOD_HIT_SPELL_RATING_SHORT", base=202, talent="PRECISION", tVal=12.6, penalty=100 } },
        ROGUE = { { stat="ITEM_MOD_HIT_RATING_SHORT", base=142, talent="PRECISION", tVal=15.8, penalty=100 } },
        HUNTER = { { stat="ITEM_MOD_HIT_RATING_SHORT", base=142, talent="SUREFOOTED", tVal=15.8, penalty=100, crOverride=7 } },
        SHAMAN = { { stat="ITEM_MOD_HIT_RATING_SHORT", base=142, talent="NATURE_GUIDANCE", tVal=15.8, penalty=100 }, { stat="ITEM_MOD_HIT_SPELL_RATING_SHORT", base=202, talent="ELEMENTAL_PRECISION", tVal=12.6, penalty=100 }, { stat="DEFENSE_FLOOR", base=490, penalty=1000 } },
        DRUID = { { stat="ITEM_MOD_HIT_RATING_SHORT", base=142, penalty=100 }, { stat="ITEM_MOD_HIT_SPELL_RATING_SHORT", base=202, talent="BALANCE_OF_POWER", tVal=25.2, penalty=100 }, { stat="DEFENSE_FLOOR", base=490, penalty=1000 } },
        MAGE = { { stat="ITEM_MOD_HIT_SPELL_RATING_SHORT", base=202, talent="ELEMENTAL_PRECISION", tVal=12.6, penalty=100 } },
        WARLOCK = { { stat="ITEM_MOD_HIT_SPELL_RATING_SHORT", base=202, talent="SUPPRESSION", tVal=25.2, penalty=100 } },
        PRIEST = { { stat="ITEM_MOD_HIT_SPELL_RATING_SHORT", base=202, talent="SHADOW_FOCUS", tVal=25.2, penalty=100 } },
    }
else
    MSC.SAFETY_CAPS = {
        WARRIOR = {
            { stat="ITEM_MOD_HIT_RATING_SHORT", base=9, talent="PRECISION", tVal=1, penalty=100 },
            { stat="DEFENSE_FLOOR", base=0, dynamic=true, penalty=1000 },
        },
        PALADIN = {
            { stat="DEFENSE_FLOOR", base=0, dynamic=true, penalty=1000 },
            { stat="ITEM_MOD_HIT_RATING_SHORT", base=9, penalty=100 },
        },
        DRUID = {
            { stat="ITEM_MOD_HIT_RATING_SHORT", base=9, penalty=100 },
            { stat="DEFENSE_FLOOR", base=0, dynamic=true, penalty=1000 },
        },
        ROGUE = { { stat="ITEM_MOD_HIT_RATING_SHORT", base=9, talent="PRECISION", tVal=1, penalty=100 } },
        HUNTER = { { stat="ITEM_MOD_HIT_RATING_SHORT", base=9, talent="SUREFOOTED", tVal=1, penalty=100 } },
        MAGE = { { stat="ITEM_MOD_HIT_SPELL_RATING_SHORT", base=16, talent="ELEMENTAL_PRECISION", tVal=2, penalty=100 } },
        -- Forever Shamans can shield-tank: the same defense floor as the other tanks
        SHAMAN = MSC.IsForever and { { stat="DEFENSE_FLOOR", base=0, dynamic=true, penalty=1000 } } or nil,
        WARLOCK = { { stat="ITEM_MOD_HIT_SPELL_RATING_SHORT", base=16, talent="SUPPRESSION", tVal=2, penalty=100 } },
    }
end

-- =============================================================
-- 1. UTILITIES & RECYCLING BIN
-- =============================================================
local Scratch_Gear = {}
local Scratch_FastGear = {}
local Scratch_Stats = {}
local Scratch_Accumulator = {}
local Scratch_SetCounts = {}
local Scratch_EquivStat = {}
local Scratch_Colors = { RED = 0, YELLOW = 0, BLUE = 0 }
local Scratch_Stats_Old = {} 

function MSC:SafeCopy(orig, dest)
    wipe(dest or {})
    local copy = dest or {}
    if not orig then return copy end
    for k,v in pairs(orig) do copy[k] = v end
    return copy
end

-- slotId (16 main hand / 17 off hand) and specName let class bonuses depend
-- on the hand and profile (e.g. a Rogue's dagger main-hand requirement).
-- otherHandLink: the weapon in the other hand (for bonuses that apply once
-- per character, like the weapon racials).
function MSC:GetWeaponSpecBonus(itemLink, class, specName, weights, slotId, otherHandLink)
    if MSC.CurrentClass and MSC.CurrentClass.GetWeaponBonus then
        return MSC.CurrentClass:GetWeaponBonus(itemLink, weights, slotId, specName, otherHandLink)
    end
    return 0
end

function MSC:CheckMetaRequirements(metaID, counts)
    if MSC.IsVanillaRules then return true end -- Era has no metas, always pass
    if not metaID then return false end
    if metaID == 32409 then return (counts.RED >= 2 and counts.BLUE >= 2 and counts.YELLOW >= 2) -- Relentless
    elseif metaID == 34220 then return (counts.BLUE >= 2) -- Chaotic
    elseif metaID == 25893 then return (counts.BLUE > counts.YELLOW) -- Mystical
    elseif metaID == 25896 or metaID == 25899 then return (counts.BLUE >= 3) -- Powerful/Brutal
    end
    return true
end

-- =============================================================
-- 2. GEAR SNAPSHOT
-- =============================================================
local GEAR_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

function MSC:BuildGearFingerprint(gearTable)
    local parts = {}
    for _, slotID in ipairs(GEAR_SLOTS) do
        local link = gearTable[slotID]
        if link then
            parts[#parts + 1] = slotID .. ":" .. (GetItemInfoInstant(link) or 0)
        end
    end
    return table.concat(parts, ";")
end

function MSC:BuildEvalCacheKey(newItemLink, targetSlotID, specName, baselineGear)
    local cacheType = baselineGear and "S" or "L"
    local rev = MSC.ScoringRevision or 0
    local fp = baselineGear and MSC:BuildGearFingerprint(baselineGear) or "live"
    -- Full item string so random-suffix / enchanted / gemmed copies don't share an entry.
    local itemId = newItemLink:match("item:[%-?%d:]+") or GetItemInfoInstant(newItemLink) or 0
    return itemId .. "|" .. (targetSlotID or 0) .. "|" .. (specName or "Default") .. "|" .. cacheType .. "|" .. rev .. "|" .. fp .. MSC.SpecGroupTag()
end

function MSC:GetCachedCharacterScore(gearTable, weights, specName, baselineGear)
    local rev = MSC.ScoringRevision or 0
    local fp = MSC:BuildGearFingerprint(gearTable)
    local tag = baselineGear and "saved" or "live"
    local key = (specName or "Default") .. "|" .. rev .. "|" .. tag .. "|" .. fp .. MSC.SpecGroupTag()

    if not baselineGear and MSC.EquippedScoreCache and MSC.EquippedScoreCache.key == key then
        return MSC.EquippedScoreCache.score, MSC.EquippedScoreCache.stats, MSC.EquippedScoreCache.colors, MSC.EquippedScoreCache.sets
    end

    local score, stats, colors, sets = MSC:GetTotalCharacterScore(gearTable, weights, specName)
    if not baselineGear and not MSC.EvalSpecGroup then -- the one-entry cache is the active spec's
        MSC.EquippedScoreCache = { key = key, score = score, stats = stats, colors = colors, sets = sets }
    end
    return score, stats, colors, sets
end

function MSC:ShouldUseFastEval(itemLink, compSlot)
    if compSlot == 16 or compSlot == 17 then return false end
    if MSC.ItemSetMap then
        -- A set piece on either side can gain or break a set bonus, which only the full check scores.
        local itemID = itemLink and GetItemInfoInstant(itemLink)
        if itemID and MSC.ItemSetMap[itemID] then return false end
        local worn = compSlot and GetInventoryItemLink("player", compSlot)
        local wornID = worn and GetItemInfoInstant(worn)
        if wornID and MSC.ItemSetMap[wornID] then return false end
    end
    return true
end

function MSC:EvaluateUpgradeFast(newItemLink, targetSlotID, weights, specName)
    if not newItemLink then return 0, 0 end
    if not weights then weights, specName = MSC.GetCurrentWeights() end

    local compSlot = targetSlotID
    if not compSlot then
        local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(newItemLink)
        if MSC.GetComparisonSlot then
            compSlot = MSC.GetComparisonSlot(newItemLink, equipLoc, weights, specName)
        end
    end
    if not compSlot then return 0, 0 end

    MSC.EquippedSlotScoreCache = MSC.EquippedSlotScoreCache or {}
    local rev = MSC.ScoringRevision or 0
    local eqKey = compSlot .. "|" .. (specName or "") .. "|" .. rev
    local equipped = GetInventoryItemLink("player", compSlot)

    -- { score, hit rating, defense rating } of the worn item in the slot
    local old = MSC.EquippedSlotScoreCache[eqKey]
    if old == nil then
        if equipped then
            local stats = MSC.SafeGetItemStats(equipped, compSlot, weights, specName)
            local score = MSC.GetItemScore(stats, weights, specName, compSlot)
            if compSlot == 16 or compSlot == 17 then
                score = score + (MSC:GetWeaponSpecBonus(equipped, MSC.CurrentClass, specName, weights, compSlot, GetInventoryItemLink("player", compSlot == 16 and 17 or 16)) or 0)
            end
            old = { score, MSC.HitRatingOf(stats), stats["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] or 0 }
        else
            old = { 0, 0, 0 }
        end
        MSC.EquippedSlotScoreCache[eqKey] = old
    end
    local oldScore = old[1]

    local newStats = MSC.SafeGetItemStats(newItemLink, compSlot, weights, specName)
    local newHit = MSC.HitRatingOf(newStats)

    -- Swaps the full check prices with a cap rule (Evaluator section 7) go
    -- there: a tank swap that changes Defense (the defense floor), and on
    -- Era / TBC a swap that changes hit (the hit cap penalty).
    local newDef = newStats["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] or 0
    local defMoves = newDef ~= old[3] and (weights["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] or 0) > 0
    local hitMoves = not MSC.IsForever and newHit ~= old[2]
    if defMoves or hitMoves then
        local _, playerClass = UnitClass("player")
        for _, rule in ipairs(MSC.SAFETY_CAPS[playerClass] or {}) do
            if (defMoves and rule.stat == "DEFENSE_FLOOR") or (hitMoves and rule.stat ~= "DEFENSE_FLOOR") then
                return MSC:EvaluateUpgrade(newItemLink, compSlot, weights, specName)
            end
        end
    end

    local newScore = MSC.GetItemScore(newStats, weights, specName, compSlot)
    if compSlot == 16 or compSlot == 17 then
        newScore = newScore + (MSC:GetWeaponSpecBonus(newItemLink, MSC.CurrentClass, specName, weights, compSlot, GetInventoryItemLink("player", compSlot == 16 and 17 or 16)) or 0)
    end

    -- Forever: hit on its true curve from the character's own hit, as the
    -- tooltip prices it (hit past a cap discounted, hit lost below one charged).
    if MSC.IsForever and MSC.ForeverHitCapCorrection and newHit ~= old[2] then
        local cur = MSC.GetGearHitRating and MSC.GetGearHitRating("MELEE")
        if not cur then -- worn gear not scanned yet: the scorer's own total
            local _, totals = MSC:GetCachedCharacterScore(MSC:GetEquippedGear(Scratch_FastGear), weights, specName)
            cur = MSC.HitRatingOf(totals)
        end
        newScore = newScore + MSC.ForeverHitCapCorrection(weights, cur, cur - old[2] + newHit)
    end

    return newScore, oldScore
end

function MSC:GetEquippedGear(outputTable)
    local gear = outputTable or {}
    wipe(gear)
    for _, slotID in ipairs(GEAR_SLOTS) do
        gear[slotID] = GetInventoryItemLink("player", slotID)
    end
    return gear
end

-- =============================================================
-- 3. THE SCORING ENGINE (The Brain)
-- =============================================================
function MSC:GetTotalCharacterScore(gearTable, weights, specName)
    local totalScore = 0
    local globalUniques = {} -- Tracking Table
    
    wipe(Scratch_SetCounts)
    wipe(Scratch_Accumulator)
    Scratch_Colors.RED = 0; Scratch_Colors.YELLOW = 0; Scratch_Colors.BLUE = 0;
    
    local metaGemID = nil 

    -- Use ipairs(GEAR_SLOTS) instead of pairs(gearTable) so unique distribution is deterministic!
    for _, slotID in ipairs(GEAR_SLOTS) do
        local itemLink = gearTable[slotID]
        if itemLink then
            -- [[ 1. GET BASE STATS ]] 
            local cachedStats = MSC.SafeGetItemStats(itemLink, slotID, weights, specName, globalUniques)

            wipe(Scratch_Stats)
            for k, v in pairs(cachedStats) do
                Scratch_Stats[k] = v
            end
            local stats = Scratch_Stats
            
            -- [[ 2. GEM DATA & COLORS ]]
            local gemMode = RXP_SGJ_Settings and RXP_SGJ_Settings.GemMode or 1
            local gemsProjected = (cachedStats.GEMS_PROJECTED and cachedStats.GEMS_PROJECTED > 0) or cachedStats.BONUS_PROJECTED
            local useProjectedGems = gemsProjected or (gemMode ~= 1)

            if useProjectedGems then
                if cachedStats.META_ID and not metaGemID then metaGemID = cachedStats.META_ID end
                if cachedStats.COLORS then
                    Scratch_Colors.RED = Scratch_Colors.RED + (cachedStats.COLORS.RED or 0)
                    Scratch_Colors.YELLOW = Scratch_Colors.YELLOW + (cachedStats.COLORS.YELLOW or 0)
                    Scratch_Colors.BLUE = Scratch_Colors.BLUE + (cachedStats.COLORS.BLUE or 0)
                end
            elseif MSC.GetItemGems then
                local itemGemIDs = {}
                local rMeta, rGemIDs = nil, nil
                _, rMeta, rGemIDs = MSC:GetItemGems(itemLink)
                if rMeta and not metaGemID then metaGemID = rMeta end
                if rGemIDs then itemGemIDs = rGemIDs end

                if #itemGemIDs > 0 and MSC.GetGemStatsByID then
                    for _, gID in ipairs(itemGemIDs) do
                        local gData = MSC.GetGemStatsByID(gID)
                        if gData then
                            if gData.stat then stats[gData.stat] = (stats[gData.stat] or 0) + gData.val end
                            if gData.stat2 then stats[gData.stat2] = (stats[gData.stat2] or 0) + gData.val2 end
                            MSC.ApplyGemColorCount(gData, Scratch_Colors)
                        end
                    end
                end
            end
            -- (Spell Power's healing half is scored inside MSC.GetItemScore.)
            local itemScore = MSC.GetItemScore(stats, weights, specName, slotID)
            totalScore = totalScore + itemScore

            -- [[ 5. ACCUMULATE TOTALS ]]
            for k,v in pairs(stats) do 
                if type(v) == "number" and k ~= "IS_PROJECTED" and k ~= "GEMS_PROJECTED" and k ~= "BONUS_PROJECTED" then 
                    Scratch_Accumulator[k] = (Scratch_Accumulator[k] or 0) + v 
                end
            end
            
            -- [[ 6. HANDLE PROCS & SETS ]]
            local itemID = GetItemInfoInstant(itemLink)
            if itemID and MSC.ItemSetMap and MSC.ItemSetMap[itemID] then
                local setID = MSC.ItemSetMap[itemID]
                Scratch_SetCounts[setID] = (Scratch_SetCounts[setID] or 0) + 1 
            end
		end
	end

    -- [[ 7. CALCULATE SET BONUSES ]]
    if MSC.SetBonusScores then
        for setID, count in pairs(Scratch_SetCounts) do
             local scoreData = MSC.SetBonusScores[setID]
             if scoreData then
                 for reqCount, bonusData in pairs(scoreData) do
                     if count >= reqCount then
                         -- Bonus stats score like item stats (GetItemScore converts
                         -- Forever ratings to % and folds Spell Power into healing).
                         -- equiv is an estimate for a proc or class bonus: it counts
                         -- toward the score but not toward the character's stat totals.
                         if bonusData.stats then
                             for stat, val in pairs(bonusData.stats) do
                                 Scratch_Accumulator[stat] = (Scratch_Accumulator[stat] or 0) + val
                             end
                             totalScore = totalScore + MSC.GetItemScore(bonusData.stats, weights, specName)
                         end
                         if bonusData.equiv then
                             -- Each equiv stat is an alternative (Spell Power for casters,
                             -- Attack Power for melee), so a hybrid takes the best one.
                             local best = 0
                             for stat, val in pairs(bonusData.equiv) do
                                 Scratch_EquivStat[stat] = val
                                 local s = MSC.GetItemScore(Scratch_EquivStat, weights, specName)
                                 Scratch_EquivStat[stat] = nil
                                 if s > best then best = s end
                             end
                             totalScore = totalScore + best
                         end
                         if not bonusData.stats and not bonusData.equiv and bonusData.score then
                             totalScore = totalScore + bonusData.score
                         end
                     end
                 end
             end
        end
    end

    -- [[ 8. WEAPON SPECIALIZATION BONUS ]]
    local mh = gearTable[16]; local oh = gearTable[17]
    if mh then totalScore = totalScore + MSC:GetWeaponSpecBonus(mh, MSC.CurrentClass, specName, weights, 16) end
    if oh then totalScore = totalScore + MSC:GetWeaponSpecBonus(oh, MSC.CurrentClass, specName, weights, 17, mh) end

    -- [[ 9. META GEM ACTIVATION CHECK (TBC Only) ]]
    if not MSC.IsVanillaRules and metaGemID and MSC.CheckMetaRequirements then
        local isActive = MSC:CheckMetaRequirements(metaGemID, Scratch_Colors)
        if not isActive then
             local metaStats = MSC.GetGemStatsByID and MSC.GetGemStatsByID(metaGemID)
             if metaStats then
                 local lostScore = 0
                 if metaStats.stat and weights[metaStats.stat] then lostScore = lostScore + (metaStats.val * weights[metaStats.stat]) end
                 if metaStats.stat2 and weights[metaStats.stat2] then lostScore = lostScore + (metaStats.val2 * weights[metaStats.stat2]) end
                 totalScore = totalScore - lostScore
             end
        end
    end

    return totalScore, MSC:SafeCopy(Scratch_Accumulator), MSC:SafeCopy(Scratch_Colors), MSC:SafeCopy(Scratch_SetCounts)
end

-- =============================================================
-- 4. BAG SCANNERS (Cached & Optimized)
-- =============================================================

	-- [[ A. CACHE STORAGE (Namespace Fixed) ]]
	MSC.WeaponBagCache = {
		MainHand = nil,
		OffHand = nil,
		Dirty = true,  
		LastSpec = nil 
	}

	-- [[ B. EVENT LISTENER ]] Dirty flag is set by CacheCleaner (section 5).

	-- [[ C. INTERNAL SCANNERS (The heavy lifting) ]]
	function MSC:Internal_ScanBestMainHand(weights, specName)
		local bestLink = nil
		local bestScore = -1

		for bag = 0, 4 do
			local numSlots = GetBagSlots(bag) 
			for slot = 1, numSlots do
				local link = GetBagLink(bag, slot)
				-- Slot filter first so non-weapons skip the usability tooltip scan.
				local iLoc = link and select(4, GetItemInfoInstant(link))
				if (iLoc == "INVTYPE_WEAPON" or iLoc == "INVTYPE_WEAPONMAINHAND") and MSC.IsItemUsable(link) then
					local _, _, _, _, _, _, _, _, loc = GetItemInfo(link)
					if (loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONMAINHAND") and IsEquippableItem(link) then
						local stats = MSC.SafeGetItemStats(link, 16, weights, specName)
						local score = MSC.GetItemScore(stats, weights, specName, 16)
						if score > bestScore then
							bestScore = score
							bestLink = link
						end
					end
				end
			end
		end
		return bestLink
	end

	function MSC:Internal_ScanBestOffHand(weights, specName)
		local bestLink = nil
		local bestScore = -1
		local _, playerClass = UnitClass("player")
		local playerLevel = UnitLevel("player")
		
		-- Check Dual Wield capabilities
		local canDualWield = false
		if playerClass == "ROGUE" or playerClass == "WARRIOR" then
			if playerLevel >= 10 then canDualWield = true end
		elseif playerClass == "HUNTER" then
			if playerLevel >= 20 then canDualWield = true end
		elseif playerClass == "SHAMAN" and MSC.GetTalentRank then
			if MSC:GetTalentRank("DUAL_WIELD") > 0 then canDualWield = true end
		end

		for bag = 0, 4 do
			local numSlots = GetBagSlots(bag) 
			for slot = 1, numSlots do
				local link = GetBagLink(bag, slot)
				-- Slot filter first so non-offhand items skip the usability tooltip scan.
				local iLoc = link and select(4, GetItemInfoInstant(link))
				if (iLoc == "INVTYPE_WEAPON" or iLoc == "INVTYPE_WEAPONOFFHAND" or iLoc == "INVTYPE_SHIELD" or iLoc == "INVTYPE_HOLDABLE")
					and MSC.IsItemUsable(link) then
					local _, _, _, _, _, _, _, _, loc = GetItemInfo(link)

					local isWeapon   = (loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND")
					local isStandard = (loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE")
					
					local allowed = false
					if isStandard then
						allowed = true
					elseif isWeapon and canDualWield then
						allowed = true
					end

					if allowed and IsEquippableItem(link) then
						local stats = MSC.SafeGetItemStats(link, 17, weights, specName)
						local score = MSC.GetItemScore(stats, weights, specName, 17)
						if score > bestScore then
							bestScore = score
							bestLink = link
						end
					end
				end
			end
		end
		return bestLink
	end

	-- [[ D. PUBLIC GETTERS  ]]
	function MSC:GetBestMainHandInBags(weights, specName)
		if MSC.WeaponBagCache.Dirty or MSC.WeaponBagCache.LastSpec ~= specName then
			MSC.WeaponBagCache.MainHand = MSC:Internal_ScanBestMainHand(weights, specName)
			MSC.WeaponBagCache.OffHand  = MSC:Internal_ScanBestOffHand(weights, specName)
			MSC.WeaponBagCache.Dirty = false
			MSC.WeaponBagCache.LastSpec = specName
		end
		return MSC.WeaponBagCache.MainHand
	end

	function MSC:GetBestOffHandInBags(weights, specName)
		if MSC.WeaponBagCache.Dirty or MSC.WeaponBagCache.LastSpec ~= specName then
			MSC.WeaponBagCache.MainHand = MSC:Internal_ScanBestMainHand(weights, specName)
			MSC.WeaponBagCache.OffHand  = MSC:Internal_ScanBestOffHand(weights, specName)
			MSC.WeaponBagCache.Dirty = false
			MSC.WeaponBagCache.LastSpec = specName
		end
		return MSC.WeaponBagCache.OffHand
	end
	

-- =============================================================
-- 5. EVALUATE UPGRADE (CACHED)
-- =============================================================

-- [[ PERFORMANCE CACHE ]]
MSC.EvaluationCache = {}
local CacheCleaner = CreateFrame("Frame")
CacheCleaner:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
CacheCleaner:RegisterEvent("PLAYER_TALENT_UPDATE")
CacheCleaner:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
CacheCleaner:RegisterEvent("PLAYER_LEVEL_UP")
CacheCleaner:RegisterEvent("BAG_UPDATE")
CacheCleaner:RegisterEvent("BAG_UPDATE_DELAYED")
CacheCleaner:RegisterEvent("PLAYER_ENTERING_WORLD")
CacheCleaner:RegisterEvent("GET_ITEM_INFO_RECEIVED")

-- C_Timer.After returns nothing, so coalesce with a flag (one wipe per 0.5s burst).
-- Stat caches are not wiped here: Helpers no longer caches stats for unloaded items.
local wipePending = false
local function WipeEvaluationCache()
    if not wipePending then return end
    wipePending = false
    if MSC.EvaluationCache then wipe(MSC.EvaluationCache) end
end
-- Lets UI refreshes that run before the timer drop entries scored before the item loaded.
MSC.FlushEvaluationCacheWipe = WipeEvaluationCache

CacheCleaner:SetScript("OnEvent", function(self, event)
    if event == "GET_ITEM_INFO_RECEIVED" then
        -- Weights built before a worn item could be read used the pre-raid gear point: rebuild them.
        if MSC.GearPointPending then
            MSC.GearPointPending = nil
            if MSC.BumpScoringRevision then MSC:BumpScoringRevision() end -- weights and every score built on them
        end
        if not wipePending then
            wipePending = true
            C_Timer.After(0.5, WipeEvaluationCache)
        end
    elseif event == "BAG_UPDATE" then
        if MSC.WeaponBagCache then MSC.WeaponBagCache.Dirty = true end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Only main/off-hand results depend on bag contents (best weapon pairing).
        -- Key layout: itemString|slot|spec|type|rev|fp
        if MSC.WeaponBagCache then MSC.WeaponBagCache.Dirty = true end
        local cache = MSC.EvaluationCache
        if cache then
            for key in pairs(cache) do
                local slot = key:match("^[^|]*|(%d+)|")
                if slot == "16" or slot == "17" then cache[key] = nil end
            end
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if MSC.EquippedSlotScoreCache then wipe(MSC.EquippedSlotScoreCache) end
        MSC.EquippedScoreCache = nil
        if MSC.EvaluationCache then wipe(MSC.EvaluationCache) end
    else
        if MSC.EvaluationCache then wipe(MSC.EvaluationCache) end
        MSC.EquippedScoreCache = nil
    end
end)


function MSC:EvaluateUpgrade(newItemLink, targetSlotID, weights, specName, baselineGear)
    -- Returns: newScore, oldScore, newItemStats, oldItemStats, newStatsTotal,
    -- oldStatsTotal, newTotalColors, oldSetCounts, newSetCounts, contextMsg,
    -- pairedFromBags (true when the other hand was filled from the bags to
    -- complete the weapon set; added last so existing callers are unaffected).
    if not newItemLink then return 0, 0, {}, {}, {} end
    if not weights then weights, specName = MSC.GetCurrentWeights() end

    -- [[ 1. CACHE CHECK ]]
    local cacheKey = MSC:BuildEvalCacheKey(newItemLink, targetSlotID, specName, baselineGear)
    
    if MSC.EvaluationCache[cacheKey] then
        return unpack(MSC.EvaluationCache[cacheKey], 1, 11)
    end

    -- [[ 2. SETUP & CURRENT SCORE ]]
    -- Use the saved gear if provided, otherwise fallback to the live paper doll
    if baselineGear then
        MSC:SafeCopy(baselineGear, Scratch_Gear)
    else
        MSC:GetEquippedGear(Scratch_Gear)
    end
    
    local currentScore, currentStatsTotal, _, oldSetCounts = MSC:GetCachedCharacterScore(Scratch_Gear, weights, specName, baselineGear)

    local originalItem = Scratch_Gear[targetSlotID]
    local originalMH   = Scratch_Gear[16]
    local originalOH   = Scratch_Gear[17]
    local contextMsg   = nil
    local pairedFromBags = false

    -- [[ 3. PRE-CALCULATE ITEM STATS ]]
    local parsedNewStats = MSC.SafeGetItemStats(newItemLink, targetSlotID, weights, specName)
    local finalNewStats = {}
    for k, v in pairs(parsedNewStats) do finalNewStats[k] = v end

    local finalOldStats = {}
    
    -- Pull the old item from the baseline if it exists, otherwise the live paper doll
    local oldItemLink = baselineGear and baselineGear[targetSlotID] or GetInventoryItemLink("player", targetSlotID)
    
    if oldItemLink then 
        local fs = MSC.SafeGetItemStats(oldItemLink, targetSlotID, weights, specName) 
        -- (A Use/proc effect's stat is already folded into these stats by
        -- SafeGetItemStats; _AUTO_PROC only records which one it was.)
        for k,v in pairs(fs) do finalOldStats[k] = v end
    end

    -- [[ 4. SWAP GEAR & HANDLE MH/OH LOGIC ]]
    Scratch_Gear[targetSlotID] = newItemLink
    
    local _,_,_,_,_,_,_,_, newLoc = GetItemInfo(newItemLink)
    local isNew2H = (newLoc == "INVTYPE_2HWEAPON" or newLoc == "INVTYPE_STAFF" or newLoc == "INVTYPE_POLEARM")
    local is2HSpec = (specName and (string_find(specName, "ARMS") or string_find(specName, "RET") or string_find(specName, "2H")))

    -- Shield tanks (Protection Warriors and Paladins, Shaman tank profiles)
    -- need the shield for Shield Block, Shield Slam, Holy Shield and their
    -- block stats, so a two-hander is never shown as an upgrade for them.
    -- With "Shield Tanks: No Two-Handers" off, skipped when a two-hander is
    -- already equipped (no shield to lose).
    local blocks2HForTank = false
    if isNew2H and targetSlotID == 16 and specName then
        local _, cls = UnitClass("player")
        local upSpec = string.upper(specName)
        if (cls == "WARRIOR" or cls == "PALADIN" or cls == "SHAMAN")
            and (string_find(upSpec, "TANK") or string_find(upSpec, "PROT")) then
            local currLoc = originalMH and select(9, GetItemInfo(originalMH))
            local isCurrent2H = (currLoc == "INVTYPE_2HWEAPON" or currLoc == "INVTYPE_STAFF" or currLoc == "INVTYPE_POLEARM")
            blocks2HForTank = not isCurrent2H or not (RXP_SGJ_Settings and RXP_SGJ_Settings.ShieldTankNo2H == false)
        end
    end

    if targetSlotID == 16 then
        if isNew2H then
            Scratch_Gear[17] = nil 
        else
            local needsOH = false
            local currentMH = originalMH
            if currentMH then
                local _,_,_,_,_,_,_,_, currLoc = GetItemInfo(currentMH)
                local isCurrent2H = (currLoc == "INVTYPE_2HWEAPON" or currLoc == "INVTYPE_STAFF" or currLoc == "INVTYPE_POLEARM")
                if isCurrent2H then needsOH = true end
            else
                needsOH = true
            end

            if not Scratch_Gear[17] then needsOH = true end

			if needsOH then
				if is2HSpec then
					Scratch_Gear[17] = nil
					contextMsg = MSC.L["|cffff0000(Not 2Hander)|r"]
				else
					local bestBagOH = MSC:GetBestOffHandInBags(weights, specName)
					if bestBagOH then
						Scratch_Gear[17] = bestBagOH
						pairedFromBags = true
						local bagName = GetItemInfo(bestBagOH)
						contextMsg = string_format(MSC.L["|cff00ff00(w/ %s)|r"], (bagName or MSC.L["Bag Item"]))
					else
						if not Scratch_Gear[17] then
							contextMsg = MSC.L["|cffff0000(No OH found)|r"]
						end
					end
				end
			end
		end
	elseif targetSlotID == 17 then
		local currentMH = originalMH
		if currentMH then
			local _,_,_,_,_,_,_,_, currLoc = GetItemInfo(currentMH)
			local isCurrent2H = (currLoc == "INVTYPE_2HWEAPON" or currLoc == "INVTYPE_STAFF" or currLoc == "INVTYPE_POLEARM")
			
			if isCurrent2H then
				local bestBagMH = MSC:GetBestMainHandInBags(weights, specName)
				if bestBagMH then
					Scratch_Gear[16] = bestBagMH
					pairedFromBags = true
					local bagName = GetItemInfo(bestBagMH)
					contextMsg = string_format(MSC.L["|cff00ff00(w/ %s)|r"], (bagName or MSC.L["Bag Item"]))
				else
					Scratch_Gear[16] = nil
					contextMsg = MSC.L["|cffff0000(No MH found)|r"]
				end
			end
		end
	end

    -- [[ 5. CALCULATE FUTURE SCORE ]]
    local newScore, newStatsTotal, newTotalColors, newSetCounts = MSC:GetTotalCharacterScore(Scratch_Gear, weights, specName)

	-- [[ 6. CONTEXT: DETECT SET COMPLETION ]]
    -- A set can only gain pieces if it is in newSetCounts, so walk that instead of every set.
    if MSC.SetBonusScores and newSetCounts then
        for setID, nC in pairs(newSetCounts) do
             local scores = MSC.SetBonusScores[setID]
             local oC = (oldSetCounts and oldSetCounts[setID]) or 0

             if scores and nC > oC then
                 for req, _ in pairs(scores) do
                     local rN = tonumber(req)
                     if rN and nC >= rN and oC < rN then
						 local msg = string_format(MSC.L["|cff00ff00(Set Bonus %s)|r"], rN)
						 contextMsg = (contextMsg or "") .. " " .. msg
					 end
                 end
             end
        end
    end

    -- [[ 7. CAP GUARDIAN (Hit/Def Caps) ]]
    local _, playerClass = UnitClass("player")
    local function Rank(k) return MSC:GetTalentRank(k) end 

    local STAT_DISPLAY = { 
        ["ITEM_MOD_HIT_RATING_SHORT"]       = MSC.L["Hit"], 
        ["ITEM_MOD_HIT_SPELL_RATING_SHORT"] = MSC.L["Spell Hit"], 
        ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = MSC.L["Exp"], 
        ["DEFENSE_FLOOR"]                   = MSC.L["Def"] 
    }
    
    -- Forever: hit is valued on its true curve against the post-swap total
    -- (Hit Rating, 10 = 1%), so hit past a cap is discounted and hit that
    -- drops back below one is charged in full (MSC.ForeverHitCapCorrection).
    if MSC.IsForever and MSC.ForeverHitCapCorrection then
        local correction, droppedBy = MSC.ForeverHitCapCorrection(weights, MSC.HitRatingOf(currentStatsTotal), MSC.HitRatingOf(newStatsTotal), baselineGear ~= nil)
        newScore = newScore + correction
        if droppedBy then
            contextMsg = (contextMsg or "") .. string_format(MSC.L[" |cffff0000(Cap %.1f %s)|r"], droppedBy, MSC.L["Hit"])
        end
    end

    if MSC.SAFETY_CAPS[playerClass] then
        for _, rule in ipairs(MSC.SAFETY_CAPS[playerClass]) do
            if MSC.IsForever and rule.stat ~= "DEFENSE_FLOOR" then
                -- handled above
            elseif rule.stat ~= "DEFENSE_FLOOR" then
                local trueCap = rule.base
                -- (Era: the game's melee hit % already includes hit talents; school
                -- talents such as Elemental Precision aren't in its spell hit %)
                if rule.talent and not (MSC.IsEra and rule.stat == "ITEM_MOD_HIT_RATING_SHORT")
                    and not (rule.talent == "SUPPRESSION" and not MSC.SuppressionCounts(specName)) then
                    trueCap = trueCap - (Rank(rule.talent) * (rule.tVal or 0))
                end
                if MSC.IsTBC and MSC.BuffEngine and (rule.stat == "ITEM_MOD_HIT_SPELL_RATING_SHORT" or rule.stat == "ITEM_MOD_HIT_RATING_SHORT") then
                    local talent = not (rule.talent == "SUPPRESSION" and not MSC.SuppressionCounts(specName)) and rule.talent or nil
                    trueCap = MSC.BuffEngine:GetEffectiveHitRatingBase(rule.stat, talent, rule.tVal, specName)
                end
                
                local currentVal = 0
                if baselineGear then
                    currentVal = currentStatsTotal[rule.stat] or 0
                else
                    currentVal = MSC:GetPlayerStat(rule.stat == "ITEM_MOD_HIT_RATING_SHORT" and "HIT" or "SPELL_HIT")
                end
                
                local succ, s = pcall(tostring, currentVal)
                currentVal = (succ and tonumber(s)) or 0
                
                local oldGearVal = currentStatsTotal[rule.stat] or 0
                local newGearVal = newStatsTotal[rule.stat] or 0
                local diff = newGearVal - oldGearVal
                local futureVal = currentVal + diff
                
                if currentVal >= trueCap and futureVal < (trueCap - 0.1) then
                    newScore = newScore - rule.penalty
                    local deficit = futureVal - trueCap
                    local name = STAT_DISPLAY[rule.stat] or MSC.L["Cap"]
                    local msg = string_format(MSC.L[" |cffff0000(Cap %.1f %s)|r"], deficit, name)
                    contextMsg = (contextMsg or "") .. msg
                end
            
            elseif rule.stat == "DEFENSE_FLOOR" then
                local defWeight = weights["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] or 0
                -- AoE farming tanks have no defense target (normal mobs can't crush): no floor either
                local spec = tostring(specName or ""):upper()
                if MSC.IsForever and (spec:find("_AOE") or spec:find("FARM")) then defWeight = 0 end
                if defWeight > 0 then
                    local floor = MSC.GetDefenseFloor and MSC:GetDefenseFloor(rule) or rule.base
                    local currentDef = 0
                    if baselineGear then
                        local defFromGear = currentStatsTotal["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] or 0
                        local baseDef = UnitLevel("player") * 5
                        if MSC.IsVanillaRules then
                            currentDef = baseDef + defFromGear
                        else
                            currentDef = baseDef + math_floor(defFromGear / 2.36)
                        end
                    else
                        currentDef = MSC:GetPlayerStat("DEFENSE")
                    end

                    local oldDefRating = currentStatsTotal["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] or 0
                    local newDefRating = newStatsTotal["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"] or 0
                    local diffSkill
                    if MSC.IsVanillaRules then
                        diffSkill = newDefRating - oldDefRating
                    else
                        diffSkill = (newDefRating - oldDefRating) / 2.36
                    end
                    local futureDef = currentDef + diffSkill

                    if currentDef >= floor and futureDef < (floor - 0.1) then
                         newScore = newScore - rule.penalty
                         local deficit = futureDef - floor
                         local msg = string_format(MSC.L[" |cffff0000(Cap %.1f Def)|r"], deficit)
                         contextMsg = (contextMsg or "") .. msg
                    end
                end
            end
        end
    end

    -- A shield tank losing the shield for a two-hander: never an upgrade.
    if blocks2HForTank then
        if newScore > currentScore then newScore = currentScore end
        contextMsg = (contextMsg or "") .. MSC.L[" |cffff0000(Tank: needs a shield)|r"]
    end

    -- [[ 8. FINALIZE & STORE CACHE ]]
    Scratch_Gear[targetSlotID] = originalItem
    Scratch_Gear[16] = originalMH
    Scratch_Gear[17] = originalOH
    
    local result = { newScore, currentScore, finalNewStats, finalOldStats, newStatsTotal, currentStatsTotal, newTotalColors, oldSetCounts, newSetCounts, contextMsg, pairedFromBags }
    MSC.EvaluationCache[cacheKey] = result
    
    -- Explicit length: contextMsg can be nil, which leaves a hole in the table.
    return unpack(result, 1, 11)
end

-- =============================================================
-- 6. BEST OWNED GEAR (off-spec baselines)
-- =============================================================
-- An off-spec (a ticked profile, or the other Dual Specialization spec) is
-- compared against the best set you own for it, not what you wear, which is
-- usually main-spec gear: worn items, bags, and the bank as seen on your last
-- visit (links saved per character in RXP_SGJ_Settings.BankGear). Rings and
-- trinkets take the best two, weapons the better of the best two-hander and the
-- best main hand + off hand pair. Set bonuses aren't counted when picking.
local OWNED_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
local OWNED_2H = { INVTYPE_2HWEAPON = true, INVTYPE_STAFF = true, INVTYPE_POLEARM = true }
local OWNED_MH = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local OWNED_OH = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
MSC.OwnedRevision = 0
local ownedCache = {}
local bankOpen = false

-- Bank containers: Forever's character bank tabs, else the Classic bank and
-- its bags after the backpack bags (as the Roster plugin reads them).
local function BankIds()
    local function Classic(skip)
        local ids = { BANK_CONTAINER or -1 }
        local first = (NUM_BAG_SLOTS or 4) + 1
        for b = first, first + (NUM_BANKBAGSLOTS or 6) - 1 do
            if b ~= skip then ids[#ids + 1] = b end
        end
        return ids
    end
    local E = Enum and Enum.BagIndex
    if E and E.CharacterBankTab_1 then
        local ids, slots = {}, 0
        for i = 1, 12 do
            local id = E["CharacterBankTab_" .. i]
            if not id then break end
            ids[#ids + 1] = id
            local ok, n = pcall(GetBagSlots, id)
            slots = slots + ((ok and tonumber(n)) or 0)
        end
        if slots > 0 then return ids end
        return Classic(E.ReagentBag)
    end
    return Classic()
end

local function ContainerLinks(ids, out)
    for _, bag in ipairs(ids) do
        local ok, n = pcall(GetBagSlots, bag)
        for slot = 1, ((ok and tonumber(n)) or 0) do
            local link = GetBagLink(bag, slot)
            if link and IsEquippableItem(link) then out[#out + 1] = link end
        end
    end
    return out
end

local function SaveBank()
    if not (bankOpen and RXP_SGJ_Settings and MSC.GetPlayerKey) then return end
    RXP_SGJ_Settings.BankGear = RXP_SGJ_Settings.BankGear or {}
    RXP_SGJ_Settings.BankGear[MSC:GetPlayerKey()] = ContainerLinks(BankIds(), {})
end

do
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED" }) do
        pcall(f.RegisterEvent, f, e)
    end
    f:SetScript("OnEvent", function(_, event)
        if event == "BANKFRAME_OPENED" then
            bankOpen = true
            C_Timer.After(0.5, function() SaveBank(); MSC.OwnedRevision = MSC.OwnedRevision + 1 end)
        elseif event == "BANKFRAME_CLOSED" then
            bankOpen = false
        elseif event ~= "PLAYER_EQUIPMENT_CHANGED" and event ~= "PLAYER_LEVEL_UP" then
            SaveBank()
        end
        MSC.OwnedRevision = MSC.OwnedRevision + 1
        if MSC.SlotCache then wipe(MSC.SlotCache) end -- the worse ring / weapon hand can change
    end)
end

local function OwnedLinks()
    local out = {}
    for _, s in ipairs(OWNED_SLOTS) do
        local link = GetInventoryItemLink("player", s)
        if link then out[#out + 1] = link end
    end
    local bags = {}
    for b = 0, (NUM_BAG_SLOTS or 4) do bags[#bags + 1] = b end
    ContainerLinks(bags, out)
    local bank = RXP_SGJ_Settings and RXP_SGJ_Settings.BankGear and RXP_SGJ_Settings.BankGear[MSC:GetPlayerKey()]
    for _, link in ipairs(bank or {}) do out[#out + 1] = link end
    return out
end

local function OwnedScore(link, slotId, weights, specName)
    local ok, s = pcall(function()
        local v = MSC.GetItemScore(MSC.SafeGetItemStats(link, slotId, weights, specName), weights, specName, slotId) or 0
        if slotId == 16 or slotId == 17 then
            v = v + ((MSC.GetWeaponSpecBonus and MSC:GetWeaponSpecBonus(link, MSC.CurrentClass, specName, weights, slotId)) or 0)
        end
        return v
    end)
    return ok and s or 0
end

-- Every owned item this character can wear now, scored per slot for the profile.
local function ScoredOwned(weights, specName)
    local key = (MSC.ScoringRevision or 0) .. "|" .. MSC.OwnedRevision .. "|" .. (UnitLevel("player") or 0)
    local hit = ownedCache[specName]
    if hit and hit.key == key and hit.weights == weights then return hit.list end
    local level, canDW = UnitLevel("player") or 0, MSC.CanDualWield()
    local list, complete = {}, true
    for _, link in ipairs(OwnedLinks()) do
        local _, _, _, _, reqLevel, _, _, _, loc = GetItemInfo(link)
        if not loc then
            complete = false
        elseif (reqLevel or 0) <= level and MSC.IsItemUsable(link) then
            local e = { link = link }
            if loc == "INVTYPE_FINGER" then e.ring = OwnedScore(link, 11, weights, specName)
            elseif loc == "INVTYPE_TRINKET" then e.trinket = OwnedScore(link, 13, weights, specName)
            elseif OWNED_2H[loc] then e.twoHand = OwnedScore(link, 16, weights, specName)
            elseif OWNED_MH[loc] or OWNED_OH[loc] then
                if OWNED_MH[loc] then e.mh = OwnedScore(link, 16, weights, specName) end
                -- a one-hander only goes in the off hand for a dual-wielder
                local offHand = (loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE")
                    or ((loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND") and canDW)
                if offHand then e.oh = OwnedScore(link, 17, weights, specName) end
            else
                local slotId = MSC.SlotMap and MSC.SlotMap[loc]
                if slotId and slotId ~= 4 then e.slot, e.score = slotId, OwnedScore(link, slotId, weights, specName) end
            end
            list[#list + 1] = e
        end
    end
    if complete then ownedCache[specName] = { key = key, weights = weights, list = list } end
    return list
end

-- Shield tanks keep a shield (same rule as EvaluateUpgrade).
local function NoTwoHanders(specName)
    if RXP_SGJ_Settings and RXP_SGJ_Settings.ShieldTankNo2H == false then return false end
    local _, cls = UnitClass("player")
    local up = string.upper(specName or "")
    return (cls == "WARRIOR" or cls == "PALADIN" or cls == "SHAMAN") and (string_find(up, "TANK") or string_find(up, "PROT")) and true or false
end

-- The best owned gear for a profile as { [slotId] = link }, for EvaluateUpgrade's
-- baselineGear. exclude: the item being judged (one copy is left out, so an item
-- in your bags shows what it adds over the next best thing you own).
function MSC.GetBestOwnedGear(weights, specName, exclude)
    if not (weights and specName) then return nil end
    local gear, best, skipped = {}, {}, false
    local rings, trinkets, mhs, ohs, twoHand = {}, {}, {}, {}, nil
    for _, e in ipairs(ScoredOwned(weights, specName)) do
        if not skipped and exclude and e.link == exclude then
            skipped = true
        elseif e.ring then rings[#rings + 1] = e
        elseif e.trinket then trinkets[#trinkets + 1] = e
        elseif e.twoHand then
            if not twoHand or e.twoHand > twoHand.twoHand then twoHand = e end
        elseif e.mh or e.oh then
            if e.mh then mhs[#mhs + 1] = e end
            if e.oh then ohs[#ohs + 1] = e end
        elseif e.slot and (not best[e.slot] or e.score > best[e.slot].score) then
            best[e.slot] = e
        end
    end
    for slotId, e in pairs(best) do gear[slotId] = e.link end
    -- Best first, so the weaker of a pair is always in the second slot
    -- (GetComparisonSlot caches which slot is the worse one).
    table.sort(rings, function(a, b) return a.ring > b.ring end)
    table.sort(trinkets, function(a, b) return a.trinket > b.trinket end)
    gear[11], gear[12] = rings[1] and rings[1].link, rings[2] and rings[2].link
    gear[13], gear[14] = trinkets[1] and trinkets[1].link, trinkets[2] and trinkets[2].link
    -- Weapons: best main hand + off hand (two different items) vs best two-hander.
    local pair, pairMH, pairOH = 0, nil, nil
    for i = 0, #mhs do
        local mh = mhs[i]
        for j = 0, #ohs do
            local oh = ohs[j]
            if not (mh and oh and mh == oh) then
                local s = (mh and mh.mh or 0) + (oh and oh.oh or 0)
                if s > pair then pair, pairMH, pairOH = s, mh, oh end
            end
        end
    end
    if twoHand and twoHand.twoHand > pair and not NoTwoHanders(specName) then
        gear[16] = twoHand.link
    else
        gear[16], gear[17] = pairMH and pairMH.link, pairOH and pairOH.link
    end
    return gear
end
